Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Require Import impboot.utils.Env.
Require Import impboot.imperative.ImpSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.
Require Import coqutil.Word.Properties.

Inductive err := TimeOut | Crash.

Inductive Result {A : Type} {B : Type} : Type :=
  | Res (a : A)
  | Ret (b : B)
  | Err (e: err).
Arguments Result : clear implicits.

Notation "'dolet' v <- r1 ; r2" := (match r1 with
  | Res v => r2
  | Ret v => Ret v
  | Err e => Err e
  end) (at level 200, right associativity).

Notation "'dolet' ( v1 , v2 ) <- r1 ; r2" := (match r1 with
  | Res (v1, v2) => r2
  | Ret v => Ret v
  | Err e => Err e
  end) (at level 200, right associativity).

Notation "'dolet' ( v1 , v2 , v3 ) <- r1 ; r2" := (match r1 with
  | Res (v1, v2, v3) => r2
  | Ret v => Ret v
  | Err e => Err e
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

Definition result A := Result A word64.

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
  Res {| funs := s.(funs);
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
      | Some v => Res v
      | None => Err Crash
      end
  | Const n => Res n
  | Add e1 e2 =>
      dolet v1 <- eval_exp s env e1 ;
      dolet v2 <- eval_exp s env e2 ;
      Res (word.add v1 v2)
  | Sub e1 e2 =>
      dolet v1 <- eval_exp s env e1 ;
      dolet v2 <- eval_exp s env e2 ;
      Res (word.sub v1 v2)
  | Div e1 e2 =>
      dolet v1 <- eval_exp s env e1 ;
      dolet v2 <- eval_exp s env e2 ;
      if word.eqb v2 (word.of_Z 0)
      then Err Crash
      else Res (word.divu v1 v2)
  | Read a b =>
      dolet va <- eval_exp s env a ;
      dolet vb <- eval_exp s env b ;
      (* convert index to byte offset *)
      let addr := word.add va (word.mul vb (word.of_Z 64)) in
      match read_mem addr s with
      | Some v => Res v
      | _ => Err Crash
      end
  end.

Fixpoint eval_exps (s : state) (env : IEnv.env) (es : list exp) : result (list word64) :=
  match es with
  | [] => Res []
  | e :: es =>
    dolet v <- eval_exp s env e ;
    dolet vs <- eval_exps s env es ;
    Res (v :: vs)
  end.

Fixpoint eval_test (s : state) (env : IEnv.env) (t : test) : result bool :=
  match t with
  | Test c e1 e2 =>
      dolet v1 <- eval_exp s env e1 ;
      dolet v2 <- eval_exp s env e2 ;
      match c with
      | Less => Res (word.ltu v1 v2)
      | Equal => Res (word.eqb v1 v2)
    end
  | And t1 t2 =>
    dolet v1 <- eval_test s env t1 ;
    dolet v2 <- eval_test s env t2 ;
    Res (andb v1 v2)
  | Or t1 t2 =>
    dolet v1 <- eval_test s env t1 ;
    dolet v2 <- eval_test s env t2 ;
    Res (orb v1 v2)
  | Not t =>
    dolet v <- eval_test s env t ;
    Res (negb v)
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
  ) idxs (Res s) ;
  Res (s.(alloc_addr), s1).

Fixpoint make_env (names : list name) (values : list word64) (acc : IEnv.env) : IEnv.env :=
  match names, values with
  | [], [] => acc
  | n :: names, v :: values =>
    make_env names values (IEnv.insert (n, Some v) acc)
  | _, _ => acc
  end.

Notation "'doolet' v <- r1 ; r2" := (match r1 with
  | (Res v, s) => r2
  | (Ret v, s) => (Ret v, s)
  | (Err e, s) => (Err e, s)
  end) (at level 200, right associativity).

Notation "'doolet' ( v , s ) <- r1 ; r2" := (match r1 with
| (Res v, s) => r2
| (Ret v, s) => (Ret v, s)
| (Err e, s) => (Err e, s)
  end) (at level 200, right associativity).

Fixpoint eval_cmd (s : state) (env : IEnv.env) (c : cmd)
  (EVAL_CMD : forall (s:state)(env:IEnv.env)(c:cmd), (result IEnv.env) * state)
  { struct c } : (result IEnv.env) * state :=
  let eval_cmd s env c := eval_cmd s env c EVAL_CMD in
  match c with
  | Seq c1 c2 =>
    doolet (env1, s1) <- eval_cmd s env c1 ;
    eval_cmd s1 env1 c2
  | Assign n e =>
    doolet v <- (eval_exp s env e, s) ;
    let env' := IEnv.insert (n, Some v) env in
    (Res env', s)
  | Update a e e' =>
    doolet va <- (eval_exp s env a, s) ;
    doolet ve <- (eval_exp s env e, s) ;
    doolet ve' <- (eval_exp s env e', s) ;
    match write_mem (word.add va ve) ve' s with
    | Some s' => (Res env, s')
    | None => (Err Crash, s)
    end
  | If t c1 c2 =>
    doolet cond <- (eval_test s env t, s) ;
    if cond
    then eval_cmd s env c1
    else eval_cmd s env c2
  | While t c =>
    doolet cond <- (eval_test s env t, s) ;
    if cond
    then
      doolet (env', s') <- eval_cmd s env c ;
      EVAL_CMD s' env' (While t c)
    else
      (Res env, s)
  | Call n fname es =>
    match find_func fname s with
    | Some (Func _ params body) =>
      if Nat.eqb (List.length params) (List.length es)
      then
        doolet args <- (eval_exps s env es, s) ;
        let call_env := make_env params args IEnv.empty in
        match EVAL_CMD s call_env body with
        | (Ret _, s') => (Res env, s')
        | _ => (Err Crash, s)
        end
      else (Err Crash, s)
    | None => (Err Crash, s)
    end
  | Return e =>
    doolet v <- (eval_exp s env e, s) ;
    (Ret v, s)
  | Alloc n e =>
    doolet size <- (eval_exp s env e, s) ;
    match allocate_memory size s with
    | Res (addr, s') =>
      let env' := IEnv.insert (n, Some addr) env in
      (Res env', s')
    | _ => (Err Crash, s)
    end
  | GetChar n =>
    let (next_word, new_inp) := read_ascii s.(input) in
    let env' := IEnv.insert (n, Some next_word) env in
    (Res env', set_input s new_inp)
  | PutChar e =>
    doolet v <- (eval_exp s env e, s) ;
    let c := word_to_ascii v in
    (Res env, set_output s (s.(output) ++ [c]))
  | Abort => (Err Crash, s)
  end.

Fixpoint EVAL_CMD (fuel : nat) (s : state) (env : IEnv.env) (c : cmd)
  { struct fuel } : (result IEnv.env) * state :=
  match fuel with
  | 0 => (Err TimeOut, s)
  | S fuel => eval_cmd s env c (EVAL_CMD fuel)
  end.

Definition eval_prog (inp : llist ascii) (fuel : nat) (p : prog) : result state :=
  match p with
  | Program funcs =>
    let call_main := Call 0 0 [] in
    let s := init_state inp fuel funcs in
    let env := IEnv.empty in
    let (r, s') := eval_cmd s env call_main (EVAL_CMD fuel) in
    match r with
    | Ret v => Res s'
    | _ => Err Crash
    end
  end.
