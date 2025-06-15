Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Require Import impboot.utils.Env.
From Stdlib Require Import ListDec.
Require Import impboot.imperative.ImpSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.

(* types *)

Notation mem_block := (list (option Value)) (only parsing).

Record state := mkState {
  vars : IEnv.env;
  memory : list mem_block;
  funs: list ImpSyntax.func;
  input: llist ascii;
  output: list ascii
}.

Inductive result {A : Type} :=
| Return (v: A)
| TimeOut
| Crash
| Abort.
Arguments result : clear implicits.

Inductive outcome {A B : Type} :=
| Cont (v: B)
| Stop (v: result A).
Arguments outcome : clear implicits.

(* monad syntax *)

Notation MRes A := (outcome Value A * state)%type (only parsing).
Notation M A := (state -> MRes A) (only parsing).

Definition bind {A B : Type} (ma: M A) (f: A -> M B): M B :=
  (fun s =>
    match ma s with
    | (Cont res, s1) => f res s1
    | (Stop e, s1) => (Stop e, s1)
    end
  ).

Definition bindMRes {A B : Type} (ma: MRes A) (f: A -> state -> MRes B): MRes B :=
  match ma with
  | (Cont res, s1) => f res s1
  | (Stop e, s1) => (Stop e, s1)
  end.

Definition point {A : Type} (a : A) : M A :=
  (fun s => (Cont a, s)).

Notation "'let+' v := r1 'in' r2" :=
  (bind r1 (fun v => r2))
  (at level 200, right associativity).

Notation "'let+' ( v1 , v2 ) := r1 'in' r2" :=
  (bind r1 (fun v => let (v1, v2) := v in r2))
  (at level 200, right associativity).

Notation "'let*' ( v , s ) := r1 'in' r2" :=
  (bindMRes r1 (fun v s => r2)) (at level 200, right associativity).

Notation "r1 ;; r2" := (let+ _ := r1 in r2)
  (at level 200, right associativity).

Definition stop {A B} (v : result A) (s : state) : (outcome A B * state) :=
  (Stop v, s).
Arguments stop _ _ !v !s /.

Definition crash {A B} (s : state) : (outcome A B * state) :=
  stop Crash s.
Arguments crash _ _ !s /.

Definition cont {A B} (v : B) (s : state) : (outcome A B * state) :=
  (Cont v, s).
Arguments cont _ _ !v !s /.

Definition next (input : llist ascii) : Value :=
  match input with
  | Lnil => Word (word.of_Z (2 ^ 32 - 1))
  | Lcons c cs => Word (word.of_Z (Z.of_nat (nat_of_ascii c)))
  end.

Definition lookup_var (n : name) (s : state) : MRes Value :=
  match IEnv.lookup s.(vars) n with
  | Some v => cont v s
  | None => crash s
  end.

Definition combine_word (f : word64 -> word64 -> word64) (x y : Value): M Value :=
  match x, y with
  | Word w1, Word w2 => cont (Word (f w1 w2))
  | _, _ => stop Crash
  end.

Definition mem_load (ptr val : Value) (s : state) : (outcome Value Value * state) :=
  match ptr, val with
  | Pointer p, Word w =>
    if negb (((w2n w) mod 8) =? 0) then crash s else
    match List.nth_error s.(memory) p with
    | None => crash s
    | Some block =>
      let idx := (w2n w) / 8 in
      match List.nth_error block idx with
      | Some (Some w) => cont w s
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

Fixpoint eval_exp (e : exp) : M Value :=
  match e with
  | Var n => lookup_var n
  | Const n => cont (Word n)
  | Add e1 e2 =>
      let+ v1 := eval_exp e1 in
      let+ v2 := eval_exp e2 in
      combine_word word.add v1 v2
  | Sub e1 e2 =>
      let+ v1 := eval_exp e1 in
      let+ v2 := eval_exp e2 in
      combine_word word.sub v1 v2
  | Div e1 e2 =>
      let+ v1 := eval_exp e1 in
      let+ v2 := eval_exp e2 in
      if value_eqb v2 (Word (word.of_Z 0))
      then crash
      else combine_word word.divu v1 v2
  | Read e1 e2 =>
      let+ addr := eval_exp e1 in
      let+ offset := eval_exp e2 in
      mem_load addr offset
  end.

Ltac unfold_monadic :=
  unfold cont, crash, stop, point, bind, combine_word, mem_load in *.

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

Fixpoint eval_exps (es : list exp) : M (list Value) :=
  match es with
  | [] => cont []
  | e :: es =>
    let+ v := eval_exp e in
    let+ vs := eval_exps es in
    cont (v :: vs)
  end.

Theorem eval_exps_pure: forall (es: list exp) r (s s': state),
  eval_exps es s = (r, s') -> s = s'.
Proof.
  induction es; simpl; intros.
  - unfold_monadic; congruence.
  - crunch_monadic; try eapply eval_exp_pure in Heqp; try eapply IHes in Heqp0; congruence.
Qed.

Definition dest_word (v: Value) : M word64 :=
  match v with
  | Word w => cont w
  | _ => crash
  end.

Definition eval_cmp (c: cmp) (v1 v2: Value): M bool :=
  match c, v1, v2 with
  | Less, Word w1, Word w2 =>
    cont (w1 <w w2)
  | Equal, Word w1, Word w2 =>
    cont (w1 =w w2)
  (* TODO(kπ) Ask Magnus or Clement? I removed this. Dunno how to distinguish
  pointer vs word in asm. *)
  (* assume that every allocated address is greater than zero *)
  (* | Equal, Pointer p, Word w =>
    (if w =w (word.of_Z 0) then cont false else stop Crash) *)
  | _, _, _ => stop Crash
  end.

Theorem eval_cmp_pure: forall (c: cmp) v1 v2 r (s s': state),
  eval_cmp c v1 v2 s = (r, s') -> s = s'.
Proof.
  destruct c; simpl; intros; crunch_monadic; try congruence.
Qed.

Fixpoint eval_test (t : test) : M bool :=
  match t with
  | Test c e1 e2 =>
      let+ v1 := eval_exp e1 in
      let+ v2 := eval_exp e2 in
      eval_cmp c v1 v2
  | And t1 t2 =>
    let+ v1 := eval_test t1 in
    let+ v2 := eval_test t2 in
    cont (andb v1 v2)
  | Or t1 t2 =>
    let+ v1 := eval_test t1 in
    let+ v2 := eval_test t2 in
    cont (orb v1 v2)
  | Not t =>
    let+ v := eval_test t in
    cont (negb v)
  end.

Theorem eval_test_pure: forall (t: test) r (s s': state),
  eval_test t s = (r, s') -> s = s'.
Proof.
  induction t; simpl; intros.
  1: crunch_monadic; eapply eval_exp_pure in Heqp; try eapply eval_exp_pure in Heqp0; try eapply eval_cmp_pure in H; congruence.
  1-2:crunch_monadic; eapply IHt1 in Heqp; try eapply IHt2 in Heqp0; congruence.
  crunch_monadic; eapply IHt in Heqp; congruence.
Qed.

Definition assign (n: name) (v : Value) (s : state) : MRes unit :=
  cont tt (set_vars (IEnv.insert (n, Some v) s.(vars)) s).

Fixpoint find_fun (fname : name) (fs : list func): option (list name * cmd) :=
  match fs with
  | nil => None
  | (Func nm params body) :: rest =>
    if fname =? nm then Some (params, body) else find_fun fname rest
  end.

Definition update_block (vs:mem_block) offset v : option mem_block :=
  if offset <? List.length vs then Some (list_update offset (Some v) vs) else None.

Definition update (v1 v2 v : Value) (s: state): MRes unit :=
  match v1, v2 with
  | (Pointer p), (Word offset) =>
    if negb ((w2n offset) mod 8 =? 0) then crash s else
      match nth_error s.(memory) p with
      | None => crash s
      | Some vs =>
        match update_block vs ((w2n offset) / 8) v with
        | None => crash s
        | Some ws => cont tt (set_memory (list_update p ws s.(memory)) s)
        end
      end
  | _, _ => crash s
  end.

Definition alloc (len: word64) (s: state) : MRes Value :=
  if negb ((w2n len) mod 8 =? 0) then crash s else
    cont (Pointer (List.length s.(memory)))
      (set_memory (s.(memory) ++ [repeat None ((w2n len) / 8)]) s).

Definition put_char (v: Value) (s: state): MRes unit :=
  match v with
  | (Pointer p) => crash s
  | (Word w) =>
    if w2n w <? 256 then
      cont tt (set_output (s.(output) ++ [ascii_of_nat (w2n w)]) s)
    else crash s
  end.

Definition get_char (s: state) : MRes Value :=
  cont (next s.(input))
    (set_input (Llist.ltail s.(input)) s).

Definition get_vars (s: state): MRes IEnv.env :=
  cont s.(vars) s.

Definition set_varsM (vars: IEnv.env) (s: state): MRes unit :=
  cont tt (set_vars vars s).

Definition nodupb (l: list nat): bool :=
  if NoDup_dec Nat.eq_dec l then
    true
  else false.

Definition get_body_and_set_vars (nm: name) (vs: list Value) (s: state): MRes cmd :=
  match find_fun nm s.(funs) with
  | None => crash s
  | Some (params, body) =>
      if orb (negb (List.length params =? List.length vs)) (negb (nodupb params)) then
        crash s
      else
        cont body (set_vars (IEnv.insert_all (List.combine params (List.map Some vs)) IEnv.empty) s)
  end.

Definition catch_return {A} (f: M A) (s: state): MRes Value :=
    match f s with
    | (Cont _, s) => crash s
    | (Stop (Return v), s) => cont v s
    | (Stop TimeOut,s) => stop TimeOut s
    | (Stop Crash,s) => stop Crash s
    | (Stop Abort,s) => stop Abort s
  end.

Fixpoint eval_cmd (c : cmd)
  (EVAL_CMD : forall (c:cmd), M unit)
  { struct c } : M unit :=
  let eval_cmd c := eval_cmd c EVAL_CMD in
  match c with
  | Seq c1 c2 =>
    let+ _ := eval_cmd c1 in
    eval_cmd c2
  | Assign n e =>
    let+ v := eval_exp e in
    assign n v
  | ImpSyntax.Abort => stop Abort
  | PutChar e =>
    let+ v := eval_exp e in
    put_char v
  | GetChar n =>
    let+ v := get_char in
    assign n v
  | Alloc n e =>
    let+ val := eval_exp e in
    let+ len := dest_word val in
    let+ ptr := alloc len in
    assign n ptr
  | Update a e e' =>
    let+ ptr := eval_exp a in
    let+ off := eval_exp e in
    let+ val := eval_exp e' in
    update ptr off val
  | If t c1 c2 =>
    let+ cond := eval_test t in
    if cond
    then eval_cmd c1
    else eval_cmd c2
  | ImpSyntax.Return e =>
    let+ v := eval_exp e in
    stop (Return v)
  | While t c =>
    let+ cond := eval_test t in
    if cond then
      let+ _ := (eval_cmd c) in
      (EVAL_CMD (While t c))
    else
      cont tt
  | Call n fname es =>
    let+ vs := eval_exps es in
    let+ vars := get_vars in
    let+ body := get_body_and_set_vars fname vs in
    let+ v := catch_return (EVAL_CMD body) in
    let+ _ := assign n v in
    set_varsM vars
  end.

Fixpoint EVAL_CMD (fuel: nat) (c : cmd) {struct fuel} : M unit :=
  match fuel with
  | 0 => stop TimeOut
  | S fuel => eval_cmd c (EVAL_CMD (fuel - 1))
  end.

Definition init_state (inp: llist ascii) (funs: list func) (fuel: nat): state :=
  {| vars   := IEnv.empty;
     memory := [];
     funs   := funs;
     input  := inp;
     output := []; |}.

Definition eval_from (fuel: nat) (input: llist ascii) (p: prog): MRes unit :=
  match p with
  | Program funs =>
    let call_main_cmd: cmd := (Call 0 (name_of_string "main") []) in
    let init_s := init_state input funs fuel in
    eval_cmd call_main_cmd (EVAL_CMD fuel) init_s
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
  exists fuel outcome s,
    eval_from fuel input p = (outcome, s) /\
    (outcome <> Stop Abort -> outcome = Cont tt /\ s.(output) = out).
