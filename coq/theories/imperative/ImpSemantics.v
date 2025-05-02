Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Require Import impboot.utils.Env.
Require Import impboot.imperative.ImpSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.
Require Import coqutil.Word.Properties.

Inductive rresult {A : Type} {B : Type} : Type :=
  | RRes (a : A)
  | RRet (b : B)
  | RErr
  | RTimeOut.
Arguments rresult : clear implicits.

Notation "'dolet' v <- r1 ; r2" := (match r1 with
  | RRes v => r2
  | RRet v => RRet v
  | RErr => RErr
  | RTimeOut => RTimeOut
  end) (at level 200, right associativity).

Notation "'dolet' ( v1 , v2 ) <- r1 ; r2" := (match r1 with
  | RRes (v1, v2) => r2
  | RRet v => RRet v
  | RErr => RErr
  | RTimeOut => RTimeOut
  end) (at level 200, right associativity).

Notation "'dolet' ( v1 , v2 , v3 ) <- r1 ; r2" := (match r1 with
  | RRes (v1, v2, v3) => r2
  | RRet v => RRet v
  | RErr => RErr
  | RTimeOut => RTimeOut
  end) (at level 200, right associativity).

Notation "r1 ;; r2" := (dolet _ <- r1 ; r2)
  (at level 200, right associativity).

(* memory keys are in bytes *)
Notation memory_t := (word64 -> option (option word64)) (only parsing).

Record state := mkState {
  funs : list ImpSyntax.func;
  fuel : nat;
  memory : memory_t;
  alloc_addr : word64;
  input : llist ascii;
  output : list ascii
}.

Definition result A := rresult A (state * word64).

Definition set_input (s : state) (inp : llist ascii) : state :=
  {| funs := s.(funs);
     fuel := s.(fuel);
     memory := s.(memory);
     alloc_addr := s.(alloc_addr);
     input := inp;
     output := s.(output) |}.

Definition set_output (s : state) (out : list ascii) : state :=
  {| funs := s.(funs);
     fuel := s.(fuel);
     memory := s.(memory);
     alloc_addr := s.(alloc_addr);
     input := s.(input);
     output := out |}.

Definition set_memory (s : state) (mem : memory_t) : state :=
  {| funs := s.(funs);
    fuel := s.(fuel);
    memory := mem;
    alloc_addr := s.(alloc_addr);
    input := s.(input);
    output := s.(output) |}.

Definition set_fuel (s : state) (fuel : nat) : state :=
  {| funs := s.(funs);
    fuel := fuel;
    memory := s.(memory);
    alloc_addr := s.(alloc_addr);
    input := s.(input);
    output := s.(output) |}.

Definition alloc_chunk (s : state) : result state :=
  (* TODO(kπ) Check if there is no overflow in word64 (alloc_addr) *)
  RRes {| funs := s.(funs);
    fuel := s.(fuel);
    memory := (fun a' => if word.eqb s.(alloc_addr) a' then Some None else s.(memory) a');
    alloc_addr := word.add s.(alloc_addr) (word.of_Z 64);
    input := s.(input);
    output := s.(output) |}.

Definition read_mem (a : word64) (s : state) : option word64 :=
  match s.(memory) a with
  | None => None
  | Some opt => opt
  end.

Definition write_mem (a : word64) (w : word64) (s : state) : option state :=
  match s.(memory) a with
  | Some _ =>
      Some (set_memory
        s
        (fun a' => if word.eqb a a' then Some (Some w) else s.(memory) a')
      )
  | _ => None
  end.

Definition init_state (inp : llist ascii) (fuel : nat) (funs : list ImpSyntax.func) : state :=
  {| funs := funs;
    memory := fun _ => None;
    alloc_addr := word.of_Z 0;
    fuel := fuel;
    input := inp;
    output := [] |}.

Definition EOF_CONST : word64 := word.of_Z (0xFFFFFFFF : Z).

Definition read_ascii (input : llist ascii) : (word64 * llist ascii) :=
  match input with
  | Lnil => (EOF_CONST, input)
  | Lcons c cs => (word.of_Z (Z.of_nat (nat_of_ascii c)), cs)
  end.

Definition word_to_ascii (w : word64) : ascii :=
  ascii_of_nat (Z.to_nat (word.unsigned w)).

Fixpoint eval_exp (s : state) (env : IEnv.env) (e : exp) : result word64 :=
  match e with
  | Var n =>
      match IEnv.lookup env n with
      | Some v => RRes v
      | None => RErr
      end
  | Const n => RRes n
  | Add e1 e2 =>
      dolet v1 <- eval_exp s env e1 ;
      dolet v2 <- eval_exp s env e2 ;
      RRes (word.add v1 v2)
  | Sub e1 e2 =>
      dolet v1 <- eval_exp s env e1 ;
      dolet v2 <- eval_exp s env e2 ;
      RRes (word.sub v1 v2)
  | Div e1 e2 =>
      dolet v1 <- eval_exp s env e1 ;
      dolet v2 <- eval_exp s env e2 ;
      if word.eqb v2 (word.of_Z 0)
      then RErr
      else RRes (word.divu v1 v2)
  | Read a b =>
      dolet va <- eval_exp s env a ;
      dolet vb <- eval_exp s env b ;
      (* convert index to byte offset *)
      let addr := word.add va (word.mul vb (word.of_Z 64)) in
      match read_mem addr s with
      | Some v => RRes v
      | _ => RErr
      end
  end.

Fixpoint eval_exps (s : state) (env : IEnv.env) (es : list exp) : result (list word64) :=
  match es with
  | [] => RRes []
  | e :: es =>
    dolet v <- eval_exp s env e ;
    dolet vs <- eval_exps s env es ;
    RRes (v :: vs)
  end.

Fixpoint eval_test (s : state) (env : IEnv.env) (t : test) : result bool :=
  match t with
  | Test c e1 e2 =>
      dolet v1 <- eval_exp s env e1 ;
      dolet v2 <- eval_exp s env e2 ;
      match c with
      | Less => RRes (word.ltu v1 v2)
      | Equal => RRes (word.eqb v1 v2)
    end
  | And t1 t2 =>
    dolet v1 <- eval_test s env t1 ;
    dolet v2 <- eval_test s env t2 ;
    RRes (andb v1 v2)
  | Or t1 t2 =>
    dolet v1 <- eval_test s env t1 ;
    dolet v2 <- eval_test s env t2 ;
    RRes (orb v1 v2)
  | Not t =>
    dolet v <- eval_test s env t ;
    RRes (negb v)
  end.

Definition find_func (fname : name) (s : state) :=
  List.find (fun func => name_of_func func =? fname) s.(funs).

(* size is in 64-byte chunks (size = 1 =:= 64 bytes) *)
Definition allocate_memory (size : word64) (s : state) : result (word64 * state) :=
  let number_of_chunks := Z.to_nat (word.unsigned size) in
  let idxs := (List.seq 0 number_of_chunks) in
  dolet s1 <- List.fold_left (fun acc_s _ =>
    dolet acc_s_v <- acc_s ;
    alloc_chunk acc_s_v
  ) idxs (RRes s) ;
  RRes (s.(alloc_addr), s1).

Fixpoint make_env (names : list name) (values : list word64) (acc : IEnv.env) : IEnv.env :=
  match names, values with
  | [], [] => acc
  | n :: names, v :: values =>
    make_env names values (IEnv.insert (n, Some v) acc)
  | _, _ => acc
  end.

(* TODO(kπ) Add fuel-based termination with the INTERP trick *)
Fixpoint eval_cmd (s : state) (env : IEnv.env) (c : cmd)
  (EVAL_CMD : forall (s:state)(env:IEnv.env)(c:cmd), result (IEnv.env*state))
  (EVAL_CMDS : forall (s:state)(env:IEnv.env)(cs:list cmd), result (IEnv.env*state))
  { struct c } : result (IEnv.env * state) :=
  let eval_cmd s env c := eval_cmd s env c EVAL_CMD EVAL_CMDS in
  let eval_cmds s env c := eval_cmds s env c EVAL_CMD EVAL_CMDS in
  match c with
  | Assign n e =>
    dolet v <- eval_exp s env e ;
    let env' := IEnv.insert (n, Some v) env in
    RRes (env', s)
  | Update a e e' =>
    dolet va <- eval_exp s env a ;
    dolet ve <- eval_exp s env e ;
    dolet ve' <- eval_exp s env e' ;
    match write_mem (word.add va ve) ve' s with
    | Some s' => RRes (env, s')
    | None => RErr
    end
  | If t c1 c2 =>
    dolet cond <- eval_test s env t ;
    if cond
    then eval_cmds s env c1
    else eval_cmds s env c2
  | While t c =>
    dolet cond <- eval_test s env t ;
    if cond
    then
      dolet (env', s') <- eval_cmds s env c ;
      EVAL_CMD s' env' (While t c)
    else
      RRes (env, s)
  | Call n fname es =>
    match find_func fname s with
    | Some (Func _ params body) =>
      if Nat.eqb (List.length params) (List.length es)
      then
        dolet args <- eval_exps s env es ;
        let call_env := make_env params args IEnv.empty in
        match EVAL_CMDS s call_env body with
        | RRet (s', rw) => RRes (env, s')
        | _ => RErr
        end
      else RErr
    | None => RErr
    end
  | Return e =>
  (* TODO(kπ) early return *)
    dolet v <- eval_exp s env e ;
    RRet (s, v)
  (* TODO(kπ) Correct-ish up to here *)
  | Alloc n e =>
    dolet size <- eval_exp s env e ;
    match allocate_memory size s with
    | RRes (addr, s') =>
      let env' := IEnv.insert (n, Some addr) env in
      RRes (env', s')
    | _ => RErr
    end
  | GetChar n =>
    let (next_word, new_inp) := read_ascii s.(input) in
    let env' := IEnv.insert (n, Some next_word) env in
    RRes (env', set_input s new_inp)
  | PutChar e =>
    dolet v <- eval_exp s env e ;
    let c := word_to_ascii v in
    RRes (env, set_output s (s.(output) ++ [c]))
  | Abort => RErr
  end
with eval_cmds (s : state) (env : IEnv.env) (cs : list cmd)
  (EVAL_CMD : forall (s:state)(env:IEnv.env)(c:cmd), result (IEnv.env*state))
  (EVAL_CMDS : forall (s:state)(env:IEnv.env)(cs:list cmd), result (IEnv.env*state))
  { struct cs } : result (IEnv.env * state) :=
  let eval_cmd s env c := eval_cmd s env c EVAL_CMD EVAL_CMDS in
  let eval_cmds s env cs := eval_cmds s env cs EVAL_CMD EVAL_CMDS in
  match cs with
  | [] => RRes (env, s)
  | c :: cs =>
    dolet (env1, s1) <- EVAL_CMD s env c ;
    eval_cmds s1 env1 cs
  end.

Fixpoint EVAL_CMD (fuel : nat) (s : state) (env : IEnv.env) (c : cmd)
  { struct fuel } : result (IEnv.env * state) :=
  match fuel with
  | 0 => RTimeOut
  | S fuel => eval_cmd s env c (EVAL_CMD fuel) (EVAL_CMDS fuel)
  end
with EVAL_CMDS (fuel : nat)  (s : state) (env : IEnv.env) (cs : list cmd)
  { struct fuel } : result (IEnv.env * state) :=
  match fuel with
  | 0 => RTimeOut
  | S fuel => eval_cmds s env cs (EVAL_CMD fuel) (EVAL_CMDS fuel)
  end.

Definition eval_prog (inp : llist ascii) (fuel : nat) (p : prog) : result state :=
  match p with
  | Program funcs =>
    let call_main := Call 0 0 [] in
    let s := init_state inp fuel funcs in
    let env := IEnv.empty in
    dolet (_, s') <- eval_cmd s env call_main (EVAL_CMD fuel) (EVAL_CMDS fuel) ;
    RRes s'
  end.
