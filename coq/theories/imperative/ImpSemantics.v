Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Require Import impboot.utils.Env.
From Stdlib Require Import ListDec.
Require Import impboot.imperative.ImpSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.

(* monadic *)

Inductive Monadic {M: Type -> Type} : Type -> Type :=
| Pure {A: Type} (a: A): Monadic A
| Bind {A B: Type} (ma: Monadic A) (f: A -> Monadic B): Monadic B
| Lift {A: Type} (ma: M A): Monadic A.
Arguments Monadic: clear implicits.

Definition bind {M: Type -> Type} {A B : Type} (ma: Monadic M A) (f: A -> Monadic M B): Monadic M B :=
  Bind ma f.

Definition map {M: Type -> Type} {A B : Type} (ma: Monadic M A) (f: A -> B): Monadic M B :=
  Bind ma (fun a => Pure (f a)).

Definition point {M: Type -> Type} {A : Type} (a : A) : Monadic M A :=
  Pure a.

Definition lift {M: Type -> Type} {A: Type} (ma: M A): Monadic M A :=
  Lift(ma).

Notation "'let+' v := r1 'in' r2" :=
  (bind r1 (fun v => r2))
  (at level 200, right associativity).

Notation "'let+' ( v1 , v2 ) := r1 'in' r2" :=
  (bind r1 (fun v => let (v1, v2) := v in r2))
  (at level 200, right associativity).

Notation "r1 ;; r2" := (let+ _ := r1 in r2)
  (at level 200, right associativity).

(* types *)

Notation mem_block := (list (option Value)) (only parsing).

Record state := mkState {
  vars : IEnv.env;
  memory : list mem_block;
  funs: list ImpSyntax.func;
  input: llist ascii;
  output: list ascii
}.

Inductive outV :=
| Return (v: Value)
| TimeOut
| Crash
| Abort.
Arguments outV : clear implicits.

Inductive result {A : Type} :=
| Interm (v: A)
| Stop (v: outV)
| ContDF (c: cmd) (cnt: Monadic (fun a => state -> (@result a * state)) A).
Arguments result : clear implicits.

(* monad syntax *)

Notation ResM A := (result A * state)%type (only parsing).
Notation StateResM A := (state -> (result A * state))%type (only parsing).

Definition bindM {A B : Type} (ma: StateResM A) (f: A -> StateResM B): StateResM B :=
  (fun s =>
    match ma s with
    | (Interm res, s1) => f res s1
    | (Stop e, s1) => (Stop e, s1)
    (* ContDF not allowed here *)
    | (ContDF c cnt, s1) => (Stop Crash, s1)
    end
  ).

Definition mapM {A B : Type} (ma: StateResM A) (f: A -> B): StateResM B :=
  (fun s =>
    match ma s with
    | (Interm res, s1) => (Interm (f res), s1)
    | (Stop e, s1) => (Stop e, s1)
    (* ContDF not allowed here *)
    | (ContDF c cnt, s1) => (Stop Crash, s1)
    end
  ).

Definition pointM {A : Type} (a : A) : StateResM A :=
  (fun s => (Interm a, s)).

Notation "'letM+' v := r1 'in' r2" :=
  (bindM r1 (fun v => r2))
  (at level 200, right associativity).

Notation "'letM+' ( v1 , v2 ) := r1 'in' r2" :=
  (bindM r1 (fun v => let (v1, v2) := v in r2))
  (at level 200, right associativity).

Notation SRM A := (Monadic (fun a => state -> (result a * state)) A) (only parsing).

Definition stop {B} (v : outV) (s : state) : (result B * state) :=
  (Stop v, s).
Arguments stop _ !v !s /.

Definition crash {B} (s : state) : (result B * state) :=
  stop Crash s.
Arguments crash _ !s /.

Definition interm {B} (v : B) (s : state) : (result B * state) :=
  (Interm v, s).
Arguments interm _ !v !s /.

Definition contdf {B} (c : cmd) (cnt: SRM B) (s : state) : (result B * state) :=
  (ContDF c cnt, s).
Arguments contdf _ !c !cnt !s /.

Definition next (input : llist ascii) : Value :=
  match input with
  | Lnil => Word (word.of_Z (2 ^ 32 - 1))
  | Lcons c cs => Word (word.of_Z (Z.of_nat (nat_of_ascii c)))
  end.

Definition lookup_var (n : name) (s : state) : ResM Value :=
  match IEnv.lookup s.(vars) n with
  | Some v => interm v s
  | None => crash s
  end.

Definition combine_word (f : word64 -> word64 -> word64) (x y : Value): StateResM Value :=
  match x, y with
  | Word w1, Word w2 => interm (Word (f w1 w2))
  | _, _ => stop Crash
  end.

Definition mem_load (ptr val : Value) (s : state) : (result Value * state) :=
  match ptr, val with
  | Pointer p, Word w =>
    if negb (((w2n w) mod 8) =? 0) then crash s else
    match List.nth_error s.(memory) p with
    | None => crash s
    | Some block =>
      let idx := (w2n w) / 8 in
      match List.nth_error block idx with
      | Some (Some w) => interm w s
      | _ => crash s
      end
    end
  | _, _ => crash s
  end.

Definition set_input (inp : llist ascii) (s : state) : state :=
  {| vars := s.(vars);
     memory := s.(memory);
     funs := s.(funs);
     input := inp;
     output := s.(output) |}.

Definition set_output (out : list ascii) (s : state) : state :=
  {| vars := s.(vars);
     funs := s.(funs);
     memory := s.(memory);
     input := s.(input);
     output := out |}.

Definition set_memory (mem : list mem_block) (s : state) : state :=
  {| vars := s.(vars);
     funs := s.(funs);
     memory := mem;
     input := s.(input);
     output := s.(output) |}.

Definition set_vars (vars: IEnv.env) (s : state) : state :=
  {| vars := vars;
     funs := s.(funs);
     memory := s.(memory);
     input := s.(input);
     output := s.(output) |}.

Definition set_fuel (fuel: nat) (s: state) : state :=
  {| vars := s.(vars);
     funs := s.(funs);
     memory := s.(memory);
     input := s.(input);
     output := s.(output) |}.

Fixpoint eval_exp (e : exp) : StateResM Value :=
  match e with
  | Var n => lookup_var n
  | Const n => interm (Word n)
  | Add e1 e2 =>
      letM+ v1 := eval_exp e1 in
      letM+ v2 := eval_exp e2 in
      combine_word word.add v1 v2
  | Sub e1 e2 =>
      letM+ v1 := eval_exp e1 in
      letM+ v2 := eval_exp e2 in
      combine_word word.sub v1 v2
  | Div e1 e2 =>
      letM+ v1 := eval_exp e1 in
      letM+ v2 := eval_exp e2 in
      if value_eqb v2 (Word (word.of_Z 0))
      then crash
      else combine_word word.divu v1 v2
  | Read e1 e2 =>
      letM+ addr := eval_exp e1 in
      letM+ offset := eval_exp e2 in
      mem_load addr offset
  end.

Ltac unfold_monadic :=
  unfold interm, crash, stop, pointM, bindM, point, bind, combine_word, mem_load in *.

Ltac crunch_monadic :=
  repeat match goal with
  | [ |- context[match ?scr with _ => _ end] ] => destruct scr eqn:?
  | [ H : context[match ?scr with _ => _ end] |- _ ] => destruct scr eqn:?
  | _ => unfold_monadic
  | _ => progress simpl in *
  | _ => congruence
  | _ => subst
  end.

Theorem eval_exp_pure: forall (e: exp) r (s s': state),
  eval_exp e s = (r, s') -> s = s'.
Proof.
  induction e; simpl; intros.
  1: unfold lookup_var in *; destruct (IEnv.lookup (vars s) n) eqn:?; unfold_monadic; congruence.
  1: unfold_monadic; congruence.
  all: crunch_monadic; eapply IHe1 in Heqp; try eapply IHe2 in Heqp0; congruence.
Qed.

Fixpoint eval_exps (es : list exp) : StateResM (list Value) :=
  match es with
  | [] => interm []
  | e :: es =>
    letM+ v := eval_exp e in
    letM+ vs := eval_exps es in
    interm (v :: vs)
  end.

Theorem eval_exps_pure: forall (es: list exp) r (s s': state),
  eval_exps es s = (r, s') -> s = s'.
Proof.
  induction es; simpl; intros.
  - unfold_monadic; congruence.
  - crunch_monadic; try eapply eval_exp_pure in Heqp; try eapply IHes in Heqp0; congruence.
Qed.

Definition dest_word (v: Value) : StateResM word64 :=
  match v with
  | Word w => interm w
  | _ => crash
  end.

Definition eval_cmp (c: cmp) (v1 v2: Value): StateResM bool :=
  match c, v1, v2 with
  | Less, Word w1, Word w2 =>
    interm (w1 <w w2)
  | Equal, Word w1, Word w2 =>
    interm (w1 =w w2)
  (* TODO(kπ) Ask Magnus or Clement? I removed this. Dunno how to distinguish
  pointer vs word in asm. *)
  (* assume that every allocated address is greater than zero *)
  (* | Equal, Pointer p, Word w =>
    (if w =w (word.of_Z 0) then interm false else stop Crash) *)
  | _, _, _ => stop Crash
  end.

Theorem eval_cmp_pure: forall (c: cmp) v1 v2 r (s s': state),
  eval_cmp c v1 v2 s = (r, s') -> s = s'.
Proof.
  destruct c; simpl; intros; crunch_monadic; try congruence.
Qed.

Fixpoint eval_test (t : test) : StateResM bool :=
  match t with
  | Test c e1 e2 =>
      letM+ v1 := eval_exp e1 in
      letM+ v2 := eval_exp e2 in
      eval_cmp c v1 v2
  | And t1 t2 =>
    letM+ v1 := eval_test t1 in
    letM+ v2 := eval_test t2 in
    interm (andb v1 v2)
  | Or t1 t2 =>
    letM+ v1 := eval_test t1 in
    letM+ v2 := eval_test t2 in
    interm (orb v1 v2)
  | Not t =>
    letM+ v := eval_test t in
    interm (negb v)
  end.

Theorem eval_test_pure: forall (t: test) r (s s': state),
  eval_test t s = (r, s') -> s = s'.
Proof.
  induction t; simpl; intros.
  1: crunch_monadic; eapply eval_exp_pure in Heqp; try eapply eval_exp_pure in Heqp0; try eapply eval_cmp_pure in H; congruence.
  1-2:crunch_monadic; eapply IHt1 in Heqp; try eapply IHt2 in Heqp0; congruence.
  crunch_monadic; eapply IHt in Heqp; congruence.
Qed.

Definition assign (n: name) (v : Value) (s : state) : ResM unit :=
  interm tt (set_vars (IEnv.insert (n, Some v) s.(vars)) s).

Fixpoint find_fun (fname : name) (fs : list func): option (list name * cmd) :=
  match fs with
  | nil => None
  | (Func nm params body) :: rest =>
    if fname =? nm then Some (params, body) else find_fun fname rest
  end.

Definition update_block (vs:mem_block) offset v : option mem_block :=
  if offset <? List.length vs then Some (list_update offset (Some v) vs) else None.

Definition update (v1 v2 v : Value) (s: state): ResM unit :=
  match v1, v2 with
  | (Pointer p), (Word offset) =>
    if negb ((w2n offset) mod 8 =? 0) then crash s else
      match nth_error s.(memory) p with
      | None => crash s
      | Some vs =>
        match update_block vs ((w2n offset) / 8) v with
        | None => crash s
        | Some ws => interm tt (set_memory (list_update p ws s.(memory)) s)
        end
      end
  | _, _ => crash s
  end.

Definition alloc (len: word64) (s: state) : ResM Value :=
  if negb ((w2n len) mod 8 =? 0) then crash s else
    interm (Pointer (List.length s.(memory)))
      (set_memory (s.(memory) ++ [repeat None ((w2n len) / 8)]) s).

Definition put_char (v: Value) (s: state): ResM unit :=
  match v with
  | (Pointer p) => crash s
  | (Word w) =>
    if w2n w <? 256 then
      interm tt (set_output (s.(output) ++ [ascii_of_nat (w2n w)]) s)
    else crash s
  end.

Definition get_char (s: state) : ResM Value :=
  interm (next s.(input))
    (set_input (Llist.ltail s.(input)) s).

Definition get_vars (s: state): ResM IEnv.env :=
  interm s.(vars) s.

Definition set_varsM (vars: IEnv.env) (s: state): ResM unit :=
  interm tt (set_vars vars s).

Definition nodupb (l: list nat): bool :=
  if NoDup_dec Nat.eq_dec l then
    true
  else false.

Definition get_body_and_set_vars (nm: name) (vs: list Value) (s: state): ResM cmd :=
  match find_fun nm s.(funs) with
  | None => crash s
  | Some (params, body) =>
      if orb (negb (List.length params =? List.length vs)) (negb (nodupb params)) then
        crash s
      else
        interm body (set_vars (IEnv.insert_all (List.combine params (List.map Some vs)) IEnv.empty) s)
  end.

Definition catch_return {A} (f: StateResM A) (s: state): ResM Value :=
    match f s with
    | (Interm _, s) => crash s
    | (Stop (Return v), s) => interm v s
    | (Stop TimeOut,s) => stop TimeOut s
    | (Stop Crash,s) => stop Crash s
    | (Stop Abort,s) => stop Abort s
    (* TODO(kπ) *)
    | (ContDF c cnt, s) =>
      stop Crash s
      (* (ContDF c cnt, s) *)
  end.

Fixpoint eval_cmd (c: cmd) { struct c } : SRM unit :=
  match c with
  | Seq c1 c2 =>
    let+ _ := eval_cmd c1 in
    eval_cmd c2
  | Assign n e =>
    let+ v := lift (eval_exp e) in
    lift (assign n v)
  | ImpSyntax.Abort => lift (stop Abort)
  | PutChar e =>
    let+ v := lift (eval_exp e) in
    lift (put_char v)
  | GetChar n =>
    let+ v := lift get_char in
    lift (assign n v)
  | Alloc n e =>
    let+ val := lift (eval_exp e) in
    let+ len := lift (dest_word val) in
    let+ ptr := lift (alloc len) in
    lift (assign n ptr)
  | Update a e e' =>
    let+ ptr := lift (eval_exp a) in
    let+ off := lift (eval_exp e) in
    let+ val := lift (eval_exp e') in
    lift (update ptr off val)
  | If t c1 c2 =>
    let+ cond := lift (eval_test t) in
    if (cond: bool)
    then eval_cmd c1
    else eval_cmd c2
  | ImpSyntax.Return e =>
    let+ v := lift (eval_exp e) in
    lift (stop (Return v))
  | While t c =>
    let+ cond := lift (eval_test t) in
    if (cond: bool) then
      let+ _ := (eval_cmd c) in
      lift (contdf (While t c) (lift (interm tt)))
    else
      lift (interm tt)
  | Call n fname es =>
    lift (interm tt)
    (* TODO(kπ) *)
    (* let+ vs := lift (eval_exps es) in
    let+ vars := lift get_vars in
    let+ body := lift (get_body_and_set_vars fname vs) in
    let+ v := catch_return (contdf body) in
    let+ _ := lift (assign n v) in
    set_varsM vars *)
  end.

Fixpoint interp {A} (m : SRM A) (s : state) : (result A * state) :=
  match m with
  | Pure a => (Interm a, s)
  | Bind ma f =>
      match interp ma s with
      | (Interm a, s') => interp (f a) s'
      | (Stop v, s') => (Stop v, s')
      (* vvv This loses the info from upper calls *)
      | (ContDF c cnt, s') => (ContDF c (Bind cnt f), s')
      end
  | Lift ma => ma s
  end.

Program Fixpoint EVAL_CMD (fuel: nat) (c : SRM unit) {measure fuel} : state -> ((result unit * state) * nat)%type :=
  fun s =>
    match fuel with
    | 0 => (stop TimeOut s, 0)
    | S fuel =>
      match interp c s with
      | (Interm v, s1) => (interm v s1, S fuel)
      | (Stop out, s1) => (stop out s1, S fuel)
      | (ContDF c1 cnt, s1) =>
          let (r, fuel1) := EVAL_CMD fuel (eval_cmd c1) s1 in
          EVAL_CMD fuel1 cnt s1
      end
    end.

(* Fixpoint EVAL_CMD (fuel: nat) (c : cmd) {struct fuel} : state -> ((result unit * state) * nat)%type :=
  fun s =>
  match fuel with
  | 0 => (stop TimeOut s, 0)
  | S fuel =>
    match eval_cmd c s with
    | (Interm v, s) => (interm v s, S fuel)
    | (Stop out, s) => (stop out s, S fuel)
    | (ContDF c cnt, s) =>
      let r := EVAL_CMD fuel c s in (* might give smaller fuel as a result *)
      match r with
      | ((Stop (Return v), s1), fuel1) => (cnt (Some v) s1, fuel1)
      | ((_, s1), fuel1) => (cnt None s1, fuel1)
      end
    end
  end. *)

Definition init_state (inp: llist ascii) (funs: list func): state :=
  {| vars   := IEnv.empty;
     memory := [];
     funs   := funs;
     input  := inp;
     output := []; |}.

Definition example_program :=
  Seq
    (Seq
      (Assign 0 (Const (word.of_Z 0))) (* i := 0 *)
      (Seq
        (While (Test Less (Var 0) (Const (word.of_Z 5))) (* i < 5 *)
          (Assign 0 (Add (Var 0) (Const (word.of_Z 1))))) (* i = i + 1 *)
        (Assign 0 (Const (word.of_Z 42))) (* x := 42 *)
      ))
    (PutChar (Const (word.of_Z 65))). (* putchar 'A' *)

Compute (
  let (rs, f) := EVAL_CMD 10 example_program (init_state Lnil []) in
  let (r, s) := rs in
  s.(vars) 0
).

Definition eval_from (fuel: nat) (input: llist ascii) (p: prog): ResM unit :=
  match p with
  | Program funs =>
    let call_main_cmd: cmd := (Call 0 (name_of_string "main") []) in
    let init_s := init_state input funs in
    let (res, fuel1) := EVAL_CMD fuel call_main_cmd init_s in
    res
  end.

Definition imp_avoids_crash (input: llist ascii) (p: prog) :=
  forall fuel res s, eval_from fuel input p = (res, s) -> res <> Stop Crash.

Definition imp_timesout (fuel: nat) (input: llist ascii) (p: prog) :=
  exists s, eval_from fuel input p = (Stop TimeOut, s).

Definition imp_output (fuel: nat) (input: llist ascii) (p: prog) :=
    let (res, s) := eval_from fuel input p in
    llist_of_list s.(output).

(* TODO(kπ) for divergence proofs *)
(* Definition imp_diverges (input: llist ascii) (p: prog) (output: list ascii) :=
    (forall fuel, imp_timesout fuel input prog) /\
    output = build_lprefix_lub { imp_output fuel input p | k IN UNIV }. *)

Definition imp_weak_termination (input: llist ascii) (p: prog) (out: list ascii) :=
  exists fuel result s,
    eval_from fuel input p = (result, s) /\
    (result <> Stop Abort -> result = Interm tt /\ s.(output) = out).
