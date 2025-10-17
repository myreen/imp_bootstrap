Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Import Llist.
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
  output: string;
  steps_done: nat
}.

Inductive result :=
| Return (v: Value)
| TimeOut
| Crash
| Abort.
Arguments result : clear implicits.

Inductive outcome {A : Type} :=
| Cont (v: A)
| Stop (v: result).
Arguments outcome : clear implicits.

(* monad syntax *)

Notation SRM A := (state -> (outcome A * state)) (only parsing).

Definition bind {A B : Type} (ma: SRM A) (f: A -> SRM B): SRM B :=
  (fun s =>
    match ma s with
    | (Cont res, s1) => f res s1
    | (Stop e, s1) => (Stop e, s1)
    end
  ).

Definition bindMRes {A B : Type} (ma: (outcome A * state)) (f: A -> SRM B): (outcome B * state) :=
  match ma with
  | (Cont res, s1) => f res s1
  | (Stop e, s1) => (Stop e, s1)
  end.

Definition point {A : Type} (a : A) : SRM A :=
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

Definition stop {B} (v : result) (s : state) : (outcome B * state) :=
  (Stop v, s).
Arguments stop _ !v !s /.

Definition crash {B} (s : state) : (outcome B * state) :=
  stop Crash s.
Arguments crash _ !s /.

Definition cont {B} (v : B) (s : state) : (outcome B * state) :=
  (Cont v, s).
Arguments cont _ !v !s /.

Definition next (input : llist ascii) : Value :=
  match input with
  | Lnil => Word (word.of_Z (2 ^ 32 - 1))
  | Lcons c cs => Word (word.of_Z (Z.of_nat (nat_of_ascii c)))
  end.

Definition lookup_var (n : name) (s : state) : (outcome Value * state) :=
  match IEnv.lookup s.(vars) n with
  | Some v => cont v s
  | None => crash s
  end.

Definition combine_word (f : word64 -> word64 -> word64) (x y : Value): SRM Value :=
  match x, y with
  | Word w1, Word w2 => cont (Word (f w1 w2))
  | _, _ => stop Crash
  end.

Definition mem_load (ptr val : Value) (s : state) : (outcome Value * state) :=
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
     output := s.(output);
     steps_done := s.(steps_done) |}.

Definition set_output (out : string) (s : state) : state :=
  {| vars := s.(vars);
     funs := s.(funs);
     memory := s.(memory);
     input := s.(input);
     output := out;
     steps_done := s.(steps_done) |}.

Definition set_memory (mem : list mem_block) (s : state) : state :=
  {| vars := s.(vars);
     funs := s.(funs);
     memory := mem;
     input := s.(input);
     output := s.(output);
     steps_done := s.(steps_done) |}.

Definition set_vars (vars: IEnv.env) (s : state) : state :=
  {| vars := vars;
     funs := s.(funs);
     memory := s.(memory);
     input := s.(input);
     output := s.(output);
     steps_done := s.(steps_done) |}.

Definition set_steps_done (new_steps_done: nat) (s: state) : state :=
  {| vars := s.(vars);
     funs := s.(funs);
     memory := s.(memory);
     input := s.(input);
     output := s.(output);
     steps_done := new_steps_done |}.

Definition add_steps_done (new_steps_done: nat) (s: state) : state :=
  set_steps_done (s.(steps_done) + new_steps_done) s.

Definition inc_steps_done : SRM unit := fun s =>
  cont tt (add_steps_done 1 s).

Fixpoint eval_exp (e : exp) : SRM Value :=
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

Fixpoint eval_exps (es : list exp) : SRM (list Value) :=
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

Definition dest_word (v: Value) : SRM word64 :=
  match v with
  | Word w => cont w
  | _ => crash
  end.

Definition eval_cmp (c: cmp) (v1 v2: Value): SRM bool :=
  match c, v1, v2 with
  | Less, Word w1, Word w2 =>
    cont (w1 <w w2)
  | Equal, Word w1, Word w2 =>
    cont (w1 =w w2)
  (* TODO(kπ) *)
  (* assume that every allocated address is greater than zero (we should know that) *)
  (* | Equal, Pointer p, Word w =>
    (if w =w (word.of_Z 0) then cont false else stop Crash) *)
  | _, _, _ => stop Crash
  end.

Theorem eval_cmp_pure: forall (c: cmp) v1 v2 r (s s': state),
  eval_cmp c v1 v2 s = (r, s') -> s = s'.
Proof.
  destruct c; simpl; intros; crunch_monadic; try congruence.
Qed.

Fixpoint eval_test (t : test) : SRM bool :=
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

Definition assign (n: name) (v : Value) (s : state) : (outcome unit * state) :=
  cont tt (set_vars (IEnv.insert (n, Some v) s.(vars)) s).

Fixpoint find_fun (fname : name) (fs : list func): option (list name * cmd) :=
  match fs with
  | nil => None
  | (Func nm params body) :: rest =>
    if fname =? nm then Some (params, body) else find_fun fname rest
  end.

Definition update_block (vs:mem_block) offset v : option mem_block :=
  if offset <? List.length vs then Some (list_update offset (Some v) vs) else None.

Definition update (v1 v2 v : Value) (s: state): (outcome unit * state) :=
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

Definition alloc (len: word64) (s: state) : (outcome Value * state) :=
  if negb ((w2n len) mod 8 =? 0) then crash s else
    cont (Pointer (List.length s.(memory)))
      (set_memory (s.(memory) ++ [repeat None ((w2n len) / 8)]) s).

Definition put_char (v: Value) (s: state): (outcome unit * state) :=
  match v with
  | (Pointer p) => crash s
  | (Word w) =>
    if w2n w <? 256 then
      cont tt (set_output (String.append s.(output) (String (ascii_of_nat (w2n w)) EmptyString)) s)
    else crash s
  end.

Definition get_char (s: state) : (outcome Value * state) :=
  cont (next s.(input))
    (set_input (Llist.ltail s.(input)) s).

Definition get_vars (s: state): (outcome IEnv.env * state) :=
  cont s.(vars) s.

Definition set_varsM (vars: IEnv.env) (s: state): (outcome unit * state) :=
  cont tt (set_vars vars s).

Definition nodupb (l: list nat): bool :=
  if NoDup_dec Nat.eq_dec l then
    true
  else false.

Definition get_body_and_set_vars (nm: name) (vs: list Value) (s: state): (outcome cmd * state) :=
  match find_fun nm s.(funs) with
  | None => crash s
  | Some (params, body) =>
      if orb (negb (List.length params =? List.length vs)) (negb (nodupb params)) then
        crash s
      else
        cont body (set_vars (IEnv.insert_all (List.combine params (List.map Some vs)) IEnv.empty) s)
  end.

Definition catch_return {A} (f: SRM A) (s: state): (outcome Value * state) :=
    match f s with
    | (Cont _, s) => crash s
    | (Stop (Return v), s) => cont v s
    | (Stop TimeOut,s) => stop TimeOut s
    | (Stop Crash,s) => stop Crash s
    | (Stop Abort,s) => stop Abort s
  end.

Fixpoint eval_cmd (c: cmd) (EVAL_CMD: forall (c:cmd), SRM unit) { struct c }: SRM unit :=
  let eval_cmd c := eval_cmd c EVAL_CMD in
  match c with
  | Skip => cont tt
  | Seq c1 c2 =>
    let+ _ := eval_cmd c1 in
    eval_cmd c2
  | Assign n e =>
    let+ v := eval_exp e in
    assign n v
  | ImpSyntax.Abort => stop Abort
  | PutChar e =>
    (* Consider: tick on every IO output to have all traces, not just modulo clock increase *)
    (* let+ _ := inc_steps_done in *)
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

Fixpoint EVAL_CMD (fuel: nat) (c : cmd) {struct fuel} : SRM unit :=
  match fuel with
  | 0 => stop TimeOut
  | S fuel =>
    let+ _ := inc_steps_done in
    eval_cmd c (EVAL_CMD fuel)
  end.

(* TODO(kπ) we need something like this, so that we know that:
  When we increase fuel for any diverging program ->
    We increase the number of steps done by the imperative evaluator ->
      The assembly also does more steps
*)
Theorem eval_cmd_steps_done_ge_fuel: forall (c: cmd) (fuel: nat) (s s1: state) (o: outcome unit),
  eval_cmd c (EVAL_CMD fuel) s = (o, s1) -> o = Stop TimeOut -> (s1.(steps_done) - s.(steps_done) >= fuel).
Proof.
Admitted.

Theorem catch_return_steps_done_ge_fuel: forall (c: cmd) (fuel: nat) (s s1: state) (o: outcome Value),
  catch_return (eval_cmd c (EVAL_CMD fuel)) s = (o, s1) -> o = Stop TimeOut -> (s1.(steps_done) - s.(steps_done) >= fuel).
Proof.
Admitted.

Theorem eval_cmd_steps_done_steps_up: forall (c: cmd) (fuel: nat) (s s1: state) (o: outcome unit),
  eval_cmd c (EVAL_CMD fuel) s = (o, s1) -> s.(steps_done) <= s1.(steps_done).
Proof.
  induction c; induction fuel; intros.
  (* Opaque EVAL_CMD. *)
  all: repeat match goal with
  | [ H: (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ H: (let (_, _) := eval_cmd ?c _ _ in  _) = _ |- _ ] => destruct (eval_cmd c _ _) eqn:?; subst
  | [ H: (match ?o with _ => _ end) = _ |- _ ] => destruct o eqn:?; subst
  | [ H: (match ?o with _ => _ end) _ = _ |- _ ] => destruct o eqn:?; subst
  | [ H: (if ?v then _ else _) _ = _ |- _ ] => destruct v eqn:?; subst
  | [ H: find_fun _ _ = _ |- _ ] => destruct (fund_fun _ _)
  | [ H: eval_cmd _ _ _ = _ |- _ ] => eapply IHc1 in H || eapply IHc2 in H || eapply IHc in H
  | [ H: eval_exp _ _ = _ |- _ ] => eapply eval_exp_pure in H; subst
  | [ H: eval_exps _ _ = _ |- _ ] => eapply eval_exps_pure in H; subst
  | [ H: eval_test _ _ = _ |- _ ] => eapply eval_test_pure in H; subst
  | [ H: EVAL_CMD 0 _ _ = _ |- _ ] => unfold EVAL_CMD in H; fold EVAL_CMD in H
  | [ H: EVAL_CMD (S _) _ _ = _ |- _ ] => unfold EVAL_CMD in H; fold EVAL_CMD in H
  | [ H: eval_cmd _ _ _ = _ |- _ ] => unfold eval_cmd in H; fold eval_cmd in H
  (* | _ => progress simpl in * *)
  | _ => progress unfold stop, cont, crash, assign, update, catch_return, set_varsM, get_body_and_set_vars, dest_word, put_char, get_char, alloc, get_vars in *
  | _ => progress unfold inc_steps_done, add_steps_done, set_steps_done, bind in *
  | _ => eapply Nat.le_refl
  | _ => lia
  end.
Admitted.

Theorem EVAL_CMD_steps_done_steps_up: forall (c: cmd) (fuel: nat) (s s1: state) (o: outcome unit),
  EVAL_CMD fuel c s = (o, s1) -> s.(steps_done) <= s1.(steps_done).
Proof.
  intros * H.
  destruct fuel; simpl in *; unfold stop in *; inversion H; subst.
  - lia.
  - unfold bind in *; simpl in *.
    eapply eval_cmd_steps_done_steps_up in H.
    simpl in *.
    lia.
Qed.

Theorem EVAL_CMD_steps_done_non_zero: forall (c: cmd) (fuel: nat) (s s1: state) (o: outcome unit),
  EVAL_CMD fuel c s = (o, s1) ->
  fuel <> 0 ->
  0 < s1.(steps_done) - s.(steps_done).
Proof.
  intros * H.
  destruct fuel; simpl in *; unfold stop in *; inversion H; subst.
  - lia.
  - unfold bind in *; simpl in *.
    eapply eval_cmd_steps_done_steps_up in H.
    simpl in *.
    lia.
Qed.

Definition init_state (inp: llist ascii) (funs: list func): state :=
  {| vars   := IEnv.empty;
     memory := [];
     funs   := funs;
     input  := inp;
     output := EmptyString;
     steps_done := 0 |}.

Definition eval_from (fuel: nat) (input: llist ascii) (p: prog): (outcome Value * state) :=
  match p with
  | Program funcs =>
    let s0 := init_state input funcs in
    match find_fun (fun_name_of_string "main") funcs with
    | Some ([], main_c) =>
      catch_return (eval_cmd main_c (EVAL_CMD fuel)) s0
    | _ => crash s0
    end
  end.

Definition prog_terminates (input: llist ascii) (p: prog) (fuel: nat) (output: string) (steps_done: nat) :=
  exists s r,
    eval_from fuel input p = (r, s) /\
      r = Stop (ImpSemantics.Return (ImpSyntax.Word (word.of_Z 0))) /\ (* TODO: is this correct? *)
      s.(ImpSemantics.output) = output /\
      s.(ImpSemantics.steps_done) = steps_done.

Definition imp_avoids_crash (input: llist ascii) (p: prog) :=
  forall fuel res s, eval_from fuel input p = (res, s) -> res <> Stop Crash.

Definition imp_timesout (fuel: nat) (input: llist ascii) (p: prog) :=
  exists s, eval_from fuel input p = (Stop TimeOut, s).

Definition imp_output (fuel: nat) (input: llist ascii) (p: prog): string :=
  let (res, s) := eval_from fuel input p in
  s.(output).

Definition prog_avoids_crash (input: llist ascii) (p: prog): Prop :=
  ∀ fuel res s, eval_from fuel input p = (res, s) ->
    res ≠ Stop Crash.

Definition output_ok_imp (input: llist ascii) (p: prog) (output: llist ascii): Prop :=
  ∀ i,
    (∃ k, String.get i (imp_output k input p) <> None ∧ String.get i (imp_output k input p) = Llist.nth i output) ∨
    (not (Llist.defined_at i output) ∧ (∀k, String.get i (imp_output k input p) = None)).

(* lprefix *)
(* Definition is_upper_bound (input: llist ascii) (p: prog) (output: llist ascii): Prop :=
  ∀k, lprefix (imp_output k input p) output.

Definition is_least_upper_bound (input: llist ascii) (p: prog) (output: llist ascii): Prop :=
  is_upper_bound input p output ∧
  ∀other, is_upper_bound input p other -> lprefix output other. *)

Definition prog_diverges (input: llist ascii) (p: prog) (output: llist ascii) :=
  (forall fuel, imp_timesout fuel input p) ∧
  output_ok_imp input p output.
  (* is_least_upper_bound (fun k => Llist.of_string (imp_output k input p)) output. *)

Definition imp_weak_termination (input: llist ascii) (p: prog) (out: string) :=
  exists fuel outcome s,
    eval_from fuel input p = (outcome, s) /\
    (outcome <> Stop Abort -> exists v, outcome = Cont v /\ s.(output) = out).
