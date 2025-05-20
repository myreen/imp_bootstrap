Require Import impboot.utils.Core.
Require Import impboot.utils.Env.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.imperative.ImpSemantics.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMSemantics.

(* Definitions of invariants and relations *)

(* Checks that the sequence xs appears at index n in the code list. *)
Fixpoint code_in (n : nat) (xs : list instr) (code : list instr) : Prop :=
  match xs with
  | [] => True
  | x :: xs' => nth_error code n = Some x /\ code_in (n + 1) xs' code
  end.

(* Declares that there exists a starting position where the initial code fragment appears in instructions. *)
Definition init_code_in (instructions : list instr) : Prop :=
  exists start, code_in 0 (init start) instructions.

(* Looks up the function with identifier n in a list of funcs and returns its parameters and body if found. *)
Fixpoint lookup_fun (n : nat) (ds : list func) : option (list name * cmd) :=
  match ds with
  | [] => None
  | (Func fname params body) :: ds =>
    if eqb fname n then Some (params, body)
    else lookup_fun n ds
  end.

(* Finds the position of function n in f_lookup if it exists. *)
Fixpoint lookup_f (n : nat) (fs : f_lookup) : option nat :=
  match fs with
  | [] => None
  | (fname, pos) :: fs =>
    if eqb fname n then Some pos
    else lookup_f n fs
  end.

(* Ensures initial instructions are present and that each function in ds has its compiled form in instructions. *)
Definition code_rel (fs : f_lookup) (ds : list func) (instructions : list instr) : Prop :=
  init_code_in instructions /\
  forall n params body,
    lookup_fun n ds = Some (params, body) ->
    exists pos,
      lookup_f n fs = Some pos /\
      code_in pos (flatten (fst (c_fundef (Func n params body) pos fs))) instructions.

(* Establishes a relation between an imperative state and an ASM state, including code alignment and register setup. *)
Definition state_rel (fs : f_lookup) (s : ImpSemantics.state) (t : ASMSemantics.state) : Prop :=
  s.(ImpSemantics.input) = t.(input) /\
  s.(ImpSemantics.output) = t.(output) /\
  code_rel fs s.(funs) t.(instructions) /\
  exists r14 r15,
    t.(regs) R12 = Some (word.of_Z 16%Z) /\
    t.(regs) R13 = Some (word.of_Z 0x7FFFFFFFFFFFFFFF%Z) /\
    t.(regs) R14 = Some r14 /\
    t.(regs) R15 = Some r15 /\
    memory_writable r14 r15 t.(memory).

(* Asserts that the given list of words matches the current stack content and RAX register in state t. *)
Definition has_stack (t : ASMSemantics.state) (xs : list word_or_ret) : Prop :=
  exists w ws,
    xs = Word w :: ws /\
    t.(regs) RAX = Some w /\
    t.(stack) = ws.

Definition v_arr_inv (asmm: word64 -> option (option word64))
  (block: list (option Value)) (vasm: option word64): Prop :=
  forall i v,
    List.nth_error block i = Some v ->
    exists w,
      v = Some (ImpSyntax.Word w) /\
      match vasm with
      | Some base =>
          asmm (word.add base (word.of_Z (Z.of_nat i * 8))) = Some (Some w)
      | None => False
      end.

(* Constrains v to valid ranges and equates it with w in the context of ASM state t. *)
Definition v_inv (asmm: word64 -> option (option word64)) (impm: list (list (option Value)))
  (v: Value) (w: word64): Prop :=
  match v with
  | ImpSyntax.Word v => word.ltu v (word.of_Z (2 ^ 63)) = true /\ w = v
  | Pointer p =>
    match List.nth_error impm p, asmm w with
    | Some block, Some asmv =>
      v_arr_inv asmm block asmv
    | _, _ => False
    end
  end.

(* Checks that environment variables map to valid locations and values on the stack in the ASM state. *)
Definition env_ok (env : IEnv.env) (vs : list (option nat)) (curr : list word_or_ret)
  (asmm : word64 -> option (option word64))
  (impm: list (list (option Value))): Prop :=
  List.length vs = List.length curr /\
  forall n v,
    IEnv.lookup env n = Some v ->
    index_of n 0 vs < List.length curr /\
    exists w,
      nth_error curr (index_of n 0 vs) = Some (Word w) /\
      v_inv asmm impm v w.

Definition cmd_res_rel (ri: outcome Value unit) (l1: nat) (stck: list word_or_ret) (t1: ASMSemantics.state) (s1: ImpSemantics.state) : Prop :=
  match ri with
  | Stop (Return v) => exists w,
    v_inv t1.(memory) s1.(ImpSemantics.memory) v w /\
    has_stack t1 (Word w :: stck) /\
    t1.(pc) = l1
  | Cont _ =>
    has_stack t1 stck /\
    t1.(pc) = l1
  | _ => False
  end.

Definition exp_res_rel (ri: outcome Value Value) (l1: nat) (stck: list word_or_ret) (t1: ASMSemantics.state) (s1: ImpSemantics.state) : Prop :=
  match ri with
  | Cont v => exists w,
    v_inv t1.(memory) s1.(ImpSemantics.memory) v w /\
    has_stack t1 (Word w :: stck) /\
    t1.(pc) = l1
  | _ => False
  end.

(* Goals *)

Definition goal_exp (e : exp): Prop :=
  forall (s s1 : ImpSemantics.state) (fuel: nat)
         (res : outcome Value Value) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret),
    eval_exp e s = (res, s1) ->
    res <> Stop Crash ->
    c_exp e t.(pc) vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr t.(memory) s.(ImpSemantics.memory) ->
    has_stack t (curr ++ rest) ->
    odd (List.length rest) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome,
      steps (State t, fuel) outcome /\
      match outcome with
      | (Halt ec output, ck) =>
        prefix output (string_of_list_ascii s1.(ImpSemantics.output)) = true /\
          ec = (word.of_Z 1)
      | (State t1, ck) =>
          state_rel fs s1 t1 /\
          ck = fuel /\
          exp_res_rel res l1 (curr ++ rest) t1 s1
      end.

Definition goal_cmd (c : cmd): Prop :=
  forall (s s1 : ImpSemantics.state) (fuel: nat)
         (res : outcome Value unit) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret),
    EVAL_CMD fuel c s = (res, s1) ->
    res <> Stop Crash ->
    c_cmd c t.(pc) fs vs = (asmc, l1, vs') ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr t.(memory) s.(ImpSemantics.memory) ->
    has_stack t (curr ++ rest) ->
    odd (List.length rest) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome,
      steps (State t, fuel) outcome /\
      match outcome with
      | (Halt ec output, ck) =>
          prefix output (string_of_list_ascii s1.(ImpSemantics.output)) = true /\
          ec = (word.of_Z 1)
      | (State t1, ck) =>
          state_rel fs s1 t1 /\
          ck = fuel /\
          cmd_res_rel res l1 (curr ++ rest) t1 s1
      end.

(* proofs *)

Ltac unfold_outcome :=
  unfold cont, crash, stop in *.

Ltac unfold_stack :=
  unfold inc, set_stack, set_input, set_memory, set_pc,
          set_vars, set_varsM, set_output, write_reg, write_mem in *; simpl.

Ltac cleanup :=
  repeat match goal with
  | [ H: _ /\ _ |- _ ] => destruct H
  | [ H: exists _, _ |- _ ] => destruct H
  | [ H : True |- _ ] => clear H
  end.

Theorem rw_mod_2_even: forall (n: nat),
  (n mod 2 = 0) <-> (even n = true).
Proof.
  split.
  - revert n.
    fix IH 1.
    destruct n.
    + reflexivity.
    + intros.
      destruct n.
      * inversion H.
      * simpl.
        eapply IH.
        change ((1 * 2 + n) mod 2 = 0) in H.
        rewrite Nat.add_comm in H.
        rewrite Nat.Div0.mod_add in H.
        assumption.
  - revert n.
    fix IH 1.
    destruct n.
    + reflexivity.
    + intros.
      destruct n.
      * inversion H.
      * simpl in H.
        change ((1 * 2 + n) mod 2 = 0).
        rewrite Nat.add_comm.
        rewrite Nat.Div0.mod_add.
        eapply IH.
        simpl.
        assumption.
Qed.

Theorem give_up: forall fs ds t w n,
  code_rel fs ds t.(instructions) ->
  t.(regs) R15 = Some w ->
  t.(pc) = give_up (odd (List.length t.(stack))) ->
  steps (State t, n) (Halt (word.of_Z 1) (string_of_list_ascii t.(output)), n).
Proof.
  intros.
  unfold give_up in *.
  unfold code_rel in *.
  unfold init_code_in, init in *.
  unfold code_in in *.
  cleanup.
  destruct (odd (List.length (stack t))) eqn:?.
  1: {
    eapply steps_trans.
    - eapply steps_step_same.
      eapply step_push; eauto.
      unfold fetch; rewrite H1; eauto.
    - eapply steps_trans.
      + eapply steps_step_same.
        eapply step_const; eauto.
        unfold_stack.
        unfold fetch; rewrite H1; eauto.
      + eapply steps_step_same.
        eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 1)
        (inc (set_stack (Word w :: stack t) (inc t))))).
        1: unfold fetch; unfold_stack; simpl; rewrite H1; eauto.
        1: unfold_stack; simpl; eauto.
        rewrite rw_mod_2_even.
        simpl in *.
        destruct (List.length (stack t)); [tauto|].
        rewrite Nat.odd_succ in *.
        assumption.
  }
  eapply steps_trans.
  + eapply steps_step_same.
    eapply step_const; eauto.
    unfold_stack.
    unfold fetch; rewrite H1; eauto.
  + eapply steps_step_same.
    eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 1) (inc t))).
    1: unfold fetch; unfold_stack; simpl; rewrite H1; eauto.
    1: unfold_stack; simpl; eauto.
    rewrite rw_mod_2_even.
    simpl in *.
    rewrite <- Nat.negb_odd in *.
    rewrite Heqb.
    tauto.
Qed.

Theorem even_len_spec_str: forall {A} (l: list A),
  (forall x, even_len (x :: l) = even (List.length (x :: l))) ∧
  even_len l = even (List.length l).
Proof.
  induction l.
  - split; reflexivity.
  - simpl even_len.
    destruct l; try reflexivity; split.
    all: unfold list_CASE; cbv beta.
    all: cleanup; try reflexivity; intros.
    all: eapply eq_sym.
    all: rewrite length_cons.
    all: rewrite length_cons.
    all: rewrite Nat.even_succ.
    all: rewrite Nat.odd_succ.
    all: eapply eq_sym.
    1: assumption.
    eapply H with (x := a).
Qed.

Theorem even_len_spec: forall {A} (l: list A),
  even_len l = even (List.length l).
Proof.
  intros.
  eapply even_len_spec_str.
Qed.

Theorem odd_len_spec_str: forall {A} (l: list A),
  (forall x, odd_len (x :: l) = odd (List.length (x :: l))) ∧
  odd_len l = odd (List.length l).
Proof.
  induction l.
  - split; reflexivity.
  - simpl odd_len.
    destruct l; try reflexivity; split.
    all: unfold list_CASE; cbv beta.
    all: cleanup; try reflexivity; intros.
    all: eapply eq_sym.
    all: rewrite length_cons.
    all: rewrite length_cons.
    all: rewrite Nat.odd_succ.
    all: rewrite Nat.even_succ.
    all: eapply eq_sym.
    1: assumption.
    eapply H with (x := a).
Qed.

Theorem odd_len_spec: forall {A} (l: list A),
  odd_len l = odd (List.length l).
Proof.
  intros.
  eapply odd_len_spec_str.
Qed.

Theorem has_stack_even: forall t xs,
  has_stack t xs -> even (List.length t.(stack)) = odd (List.length xs).
Proof.
  intros.
  unfold has_stack in *; cleanup.
  subst.
  rewrite length_cons.
  rewrite <- Nat.odd_succ.
  reflexivity.
Qed.

Theorem substring_noop: forall s,
  substring 0 (length s) s = s.
Proof.
Admitted.

Ltac bound_crunch :=
  intros;
  try rewrite word.unsigned_ltu in *;
  try rewrite word.unsigned_of_Z in *;
  try unfold word.wrap in *;
  (* THIS IS HORRIBLY SLOW *)
  cbn in *;
  lia.

Theorem sub_lt_bound: forall (a b: Z),
  (a <? b)%Z = true ->
  (a <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true ->
  (b <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true ->
  ((b - a) mod Z.pow_pos 2 64 <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true.
Proof.
Admitted.

Theorem z_lt_bound: forall (z: Z),
  word.ltu (word.of_Z (2 ^ 63 - 1)) ((Naive.wrap z): word64) = false ->
  (z mod Z.pow_pos 2 64 <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true.
Proof.
  intros.
  rewrite word.unsigned_ltu in *.
  rewrite word.unsigned_of_Z in *.
  unfold word.wrap in *.
  (* THIS IS HORRIBLY SLOW *)
  cbn in *.
  lia.
Qed.

Theorem w_lt_bound: forall (w: word64),
  (word.ltu (word.of_Z (2 ^ 63 - 1)) w = false \/
    word.ltu w (word.of_Z (2 ^ 63)) = true) ->
  word.ltu w (word.of_Z (2 ^ 63)) = true /\
  (Naive.unsigned w <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true.
Proof.
  intros.
  rewrite word.unsigned_ltu in *.
  rewrite word.unsigned_of_Z in *.
  unfold word.wrap in *.
  (* THIS IS HORRIBLY SLOW *)
  cbn in *.
  lia.
Qed.

Theorem c_exp_length: forall e l vs c l1,
  c_exp e l vs = (c, l1) -> l1 = l + List.length (flatten c).
Proof.
  induction e.
  all: intros.
  all: simpl c_exp in *.
  all: repeat match goal with
  | [ H : context[(if ?x then _ else _)] |- _ ] => destruct x eqn:?
  | [ H : context [(match ?x with | _ => _ end)] |- _ ] => destruct x eqn:?
  | [ H : (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ |- context[ fst ?x ] ] => destruct x eqn:?; simpl in *
  | [ H : c_exp _ _ (None :: _) = (_, _) |- _ ] => eapply IHe2 in H; subst
  | [ H : c_exp _ _ ?_l = (_, _) |- _ ] => eapply IHe1 in H; subst
  | _ => progress unfold c_var, c_const, dlet in *
  | _ => progress simpl in *
  | _ => progress rewrite length_app
  | _ => lia
  end.
Qed.

Theorem code_in_append: forall xs ys n code,
    code_in n (xs ++ ys) code <->
    (code_in n xs code ∧ code_in (n + List.length xs) ys code).
Proof.
  induction xs; intros; simpl.
  - split; intros; cleanup; try split; eauto.
    all: rewrite Nat.add_0_r in *; eauto.
  - split; intros; cleanup.
    + repeat split; eauto.
      all: eapply IHxs in H0; cleanup; eauto.
      rewrite <- Nat.add_1_l.
      rewrite Nat.add_assoc.
      eauto.
    + repeat split; eauto.
      all: eapply IHxs; cleanup; eauto.
      repeat split; eauto.
      rewrite <- Nat.add_1_l in H0.
      rewrite Nat.add_assoc in H0.
      eauto.
Qed.

Theorem eval_exp_not_stop: forall e s res s1 v,
  eval_exp e s = (res, s1) ->
  res ≠ Stop Crash ->
  res <> Stop v.
Proof.
  induction e; intros.
  all: simpl eval_exp in *.
  all: unfold lookup_var, bind in *; unfold_outcome; simpl in *.
  - destruct (IEnv.lookup (vars s) n) eqn:?.
    all: inversion H; subst; congruence.
  - congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct o eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; inversion H3; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct o0 eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; inversion H3; subst; eauto.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct o eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; inversion H3; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct o0 eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; inversion H3; subst; eauto.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct o eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; inversion H3; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct o0 eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; inversion H3; subst; eauto.
    destruct (value_eqb v1 (ImpSyntax.Word (Naive.wrap 0))) eqn:?.
    1: congruence.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct o eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; inversion H3; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct o0 eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; inversion H3; subst; eauto.
    unfold mem_load in *.
    destruct v0; unfold_outcome.
    1: congruence.
    destruct v1; unfold_outcome.
    2: congruence.
    destruct (negb (w2n w mod 8 =? 0)) eqn:?.
    1: congruence.
    destruct (nth_error (ImpSemantics.memory s2) i) eqn:?.
    2: congruence.
    destruct (nth_error _ (w2n w / 8)) eqn:?.
    2: congruence.
    destruct o1 eqn:?.
    all: congruence.
Qed.

Theorem steps_instructions: forall s1 s2 f1 f2,
  steps (State s1, f1) (State s2, f2) -> s1.(instructions) = s2.(instructions).
Proof.
Admitted.

Theorem index_of_spec: forall name vs k,
  index_of name k vs = k + index_of name 0 vs.
Proof.
  induction vs; intros; eauto.
  simpl; destruct a.
  - destruct (_ =? _) eqn:?; simpl; eauto.
    rewrite IHvs; eapply eq_sym; rewrite IHvs.
    rewrite Nat.add_assoc.
    reflexivity.
  - rewrite IHvs; eapply eq_sym; rewrite IHvs.
    rewrite Nat.add_assoc.
    reflexivity.
Qed.

Ltac crunch_give_up_even :=
  repeat match  goal with
  | |- (ImpToASMCodegen.give_up _) = (ImpToASMCodegen.give_up _) => f_equal
  | |- context[even_len _] => rewrite even_len_spec
  | |- context[odd_len _] => rewrite odd_len_spec
  | [ H: (List.length ?vs = _) |- context[List.length ?vs] ] => rewrite H
  | |- context[List.length (_ ++ _)] => rewrite length_app
  | |- context[odd (_ + _)] => rewrite Nat.odd_add
  | |- context[even (_ + _)] => rewrite Nat.even_add
  | [ H: odd ?x = _ |- context[odd ?x] ] => rewrite H
  | [ H: (even (List.length (stack ?t))) = _ |- context C [odd (List.length (stack ?t))]] =>
    repeat rewrite <- Nat.negb_even; rewrite H; clear H
  | [ H: (odd (List.length (stack ?t))) = _ |- context C [even (List.length (stack ?t))]] =>
    repeat rewrite <- Nat.negb_even; rewrite H; clear H
  | [ H: (even (List.length (stack ?t))) = _ |- context C [even (List.length (stack ?t))]] =>
    rewrite H; clear H
  | [ H: (odd (List.length (stack ?t))) = _ |- context C [odd (List.length (stack ?t))]] =>
    rewrite H; clear H
  | _ => rewrite xorb_true_r || rewrite Nat.negb_odd || rewrite Nat.negb_even
  | _ => tauto
end.

Theorem env_ok_add_None: forall vars vs curr x asmm impm,
  env_ok vars vs curr asmm impm ->
  env_ok vars (None :: vs) (Word x :: curr) asmm impm.
Proof.
  intros * H.
  unfold env_ok in *; cleanup.
  split.
  1: simpl; eauto.
  intros*; intro HLookup.
  eapply H0 in HLookup; cleanup.
  split; try eexists; try split.
  all: simpl.
  all: try rewrite index_of_spec; try lia.
  all: unfold v_inv in *.
  1: simpl; eapply H2.
  destruct v; [assumption|].
  assumption.
Qed.

Ltac rw tac :=
  let n := fresh "H" in
  ltac:(tac); intros n; rewrite n in *; clear n.

Ltac rwr tac :=
  let n := fresh "H" in
  ltac:(tac); intros n; rewrite <- n in *; clear n.

Theorem c_exp_Const : forall (w: word64),
  goal_exp (ImpSyntax.Const w).
Proof.
  unfold goal_exp.
  intros.
  specialize (has_stack_even t (curr ++ rest) H4); intros.
  unfold has_stack in *; cleanup.
  simpl eval_exp in *.
  unfold lookup_var in *.
  unfold state_rel in *; cleanup.
  unfold env_ok in *; cleanup.
  simpl c_exp in *; unfold c_const in *.
  destruct (word.of_Z _ <w _) eqn:?.
  1: {
    eexists.
    inversion H1; subst; clear H1.
    simpl flatten in *.
    split.
    - eapply steps_trans.
      + eapply steps_step_same.
        simpl code_in in *; cleanup.
        eapply step_jump; eauto.
        constructor.
      + simpl.
        all: unfold state_rel in *; cleanup.
        eapply give_up.
        all: unfold_stack; eauto.
        unfold env_ok in *; cleanup.
        crunch_give_up_even.
    - simpl.
      split; try reflexivity.
      inversion H; subst.
      unfold state_rel in *; cleanup.
      rewrite <- H10.
      rewrite prefix_correct.
      apply substring_noop.
  }
  inversion H1; subst; clear H1.
  simpl flatten in *.
  eexists.
  split.
  1: {
    eapply steps_trans.
    + eapply steps_step_same.
      simpl code_in in *; cleanup.
      eapply step_push in e; eauto.
    + eapply steps_step_same.
      simpl code_in in *; cleanup.
      eapply step_const with (w := w).
      eauto.
  }
  simpl.
  repeat split; unfold state_rel in *; cleanup; intros; repeat split; simpl.
  all: inversion H; subst; eauto.
  - unfold code_rel in *.
    cleanup.
    eauto.
  - unfold code_rel in *; cleanup.
    eapply H11 in H1.
    cleanup.
    eexists.
    split; eauto.
  - eexists; eexists.
    eauto.
  - unfold exp_res_rel.
    eexists.
    repeat split.
    1: eapply w_lt_bound; eauto.
    + unfold has_stack.
      simpl.
      eauto.
    + simpl.
      lia.
Qed.

Theorem c_exp_Var : forall (n: name),
  goal_exp (ImpSyntax.Var n).
Proof.
  unfold goal_exp.
  intros.
  unfold has_stack in *; cleanup.
  simpl eval_exp in *.
  unfold lookup_var in *.
  unfold state_rel in *; cleanup.
  unfold env_ok in *; cleanup.
  unfold code_rel in *; cleanup.
  simpl c_exp in *; unfold c_var in *; unfold dlet in *.
  destruct (index_of n 0 vs =? 0) eqn:?.
  1: {
    eexists.
    inversion H1; subst; clear H1.
    simpl flatten in *.
    split.
    - eapply steps_step_same.
      simpl code_in in *; cleanup.
      eapply step_push in e; eauto.
    - simpl.
      destruct (IEnv.lookup (vars s) n) eqn:?; unfold_outcome; inversion H; subst.
      2: unfold not in H0; contradiction.
      repeat split; simpl; eauto.
      1: eexists; eexists; eauto.
      unfold v_inv, has_stack.
      destruct v eqn:?.
      1: {
        assert (x = w).
        1: {
          eapply H16 in Heqo; cleanup; subst.
          unfold v_inv in *; cleanup; subst.
          rewrite Nat.eqb_eq in *.
          rewrite Heqb in *.
          destruct curr; inversion H8; subst.
          inversion H4; subst.
          reflexivity.
        }
        subst.
        exists w; repeat split; try exists w.
        all: try eexists; repeat split.
        all: unfold_stack.
        all: eauto.
        unfold v_inv in *; cleanup; subst.
        unfold env_ok in *; cleanup.
        pose (H16 n (ImpSyntax.Word w) Heqo); cleanup.
        unfold v_inv in *; cleanup.
        eapply w_lt_bound; eauto.
      }
      eexists; repeat split.
      all: repeat eexists; repeat split.
      all: unfold_stack.
      all: eauto.
      unfold env_ok in *; cleanup.
      eapply H16 in Heqo; cleanup; subst.
      unfold v_inv in *; cleanup; subst.
      rewrite Nat.eqb_eq in *.
      rewrite Heqb in *.
      destruct curr; inversion H8; subst.
      inversion H4; subst.
      assumption.
  }
  unfold env_ok in *; cleanup.
  unfold lookup_var in *; cleanup.
  destruct (IEnv.lookup (vars s) n) eqn:?; unfold_outcome; inversion H; subst.
  2: unfold not in H0; contradiction.
  pose (H16 n v Heqo); cleanup.
  eexists.
  inversion H1; subst; clear H1.
  simpl flatten in *.
  split.
  - eapply steps_trans.
    + eapply steps_step_same.
      simpl code_in in *; cleanup.
      eapply step_push in e; eauto.
    + eapply steps_step_same.
      rewrite Nat.eqb_neq in *.
      simpl code_in in *; cleanup.
      eapply step_load_rsp; eauto.
      all: unfold_stack; eauto.
      2: {
        rewrite <- H4 in *.
        rewrite nth_error_app.
        rewrite <- Nat.ltb_lt in *.
        rewrite H8.
        rewrite H18.
        reflexivity.
      }
      eapply Nat.lt_trans; [eauto|].
      assert (List.length (curr ++ rest) = List.length (Word x :: stack t)); [rewrite H4; reflexivity|].
      rewrite length_app in *.
      rewrite length_cons in *.
      rewrite <- H1.
      destruct rest; [inversion H5|].
      rewrite length_cons in *.
      lia.
  - simpl.
    unfold state_rel in *; cleanup.
    unfold code_rel in *; cleanup.
    repeat split; simpl; eauto.
    1: eexists; eexists; eauto.
    unfold v_inv, has_stack.
    destruct v eqn:?.
    1: {
      eexists; repeat split; try eexists.
      all: try eexists; repeat split.
      all: unfold_stack.
      all: eauto; try lia.
      - unfold v_inv in *; cleanup; subst.
        eapply w_lt_bound; eauto.
      - eapply H16 in Heqo; cleanup; subst.
        unfold v_inv in *; cleanup; subst.
        reflexivity.
    }
    eexists; repeat split.
    all: repeat eexists; repeat split.
    all: unfold_stack.
    all: eauto.
    lia.
Qed.

Theorem c_exp_Add : forall (e1 e2: exp),
  goal_exp e1 -> goal_exp e2 ->
  goal_exp (ImpSyntax.Add e1 e2).
Proof.
  intros.
  unfold goal_exp; intros.
  simpl eval_exp in *.
  simpl c_exp in *; unfold c_add in *; unfold dlet in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp in *; subst.
  destruct o eqn:?; subst.
  2: {
    destruct v eqn:?; subst.
    all: inversion H1; subst.
    all: eapply eval_exp_not_stop in Heqp; unfold not in *; eauto; exfalso; apply Heqp; eauto.
  }
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct o eqn:?; subst.
  2: {
    destruct v eqn:?; subst.
    all: inversion H1; subst.
    all: eapply eval_exp_not_stop in Heqp0; unfold not in *; eauto; exfalso; apply Heqp0; eauto.
  }
  unfold combine_word in *.
  destruct v eqn:?.
  2: inversion H1; subst; contradiction.
  destruct v0 eqn:?.
  2: inversion H1; subst; contradiction.
  unfold_outcome; inversion H1; subst.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H in Heqp; clear H; eauto; inversion H3; subst.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup.
  2: eexists; split; eauto; simpl; split; eauto.
  unfold exp_res_rel in *; cleanup.
  unfold goal_exp in H0.
  rewrite <- H15 in *.
  rw ltac:(specialize (steps_instructions _ _ _ _ H10)).
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  2: eexists; split; [eapply steps_trans|]; eauto; simpl; split; eauto.
  all: unfold exp_res_rel in *; cleanup.
  1: instantiate (1 := (Word x :: curr)) in H15; simpl in *; cleanup.
  1: {
    unfold state_rel in *; cleanup.
    specialize (has_stack_even t (curr ++ rest) H6) as ?.
    specialize (has_stack_even _ _ H14) as ?.
    specialize (has_stack_even _ _ H15) as ?.
    unfold has_stack in *; cleanup; subst.
    unfold env_ok in *; cleanup.
    inversion H15; clear H15; subst.
    inversion H14; clear H14; subst.
    rw ltac:(specialize (steps_instructions _ _ _ _ H0)).
    destruct (word.ltu ((word.of_Z (2 ^ 63 - 1)): word64)
      (Naive.wrap ((Naive.unsigned x7) + (Naive.unsigned x9)))) eqn:?.
    1: {
      eexists.
      split.
      1: {
        eapply steps_trans.
        1: eapply H10.
        eapply steps_trans.
        1: eapply H0.
        rewrite <- H16 in *.
        unfold code_in in H9; cleanup; subst.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_pop; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_add; eauto.
        1: unfold_stack; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump; eauto.
        1: unfold_stack; constructor; eauto.
        1: simpl; eauto.
        simpl Z.pow in *; unfold Z.pow_pos in *; simpl PosDef.Pos.iter in *; simpl Z.sub in *.
        rewrite Heqb.
        unfold_stack.
        eapply give_up; unfold_stack; eauto.
        crunch_give_up_even.
      }
      simpl.
      repeat split; eauto.
      rewrite H21.
      rewrite prefix_correct.
      apply substring_noop.
    }
    eexists.
    split.
    1: {
      eapply steps_trans.
      1: eapply H10.
      eapply steps_trans.
      1: eapply H0.
      rewrite <- H16 in *.
      unfold code_in in H9; cleanup; subst.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; [eapply H9|]; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_add; eauto.
      1: unfold_stack; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; eauto.
      1: unfold_stack; constructor; eauto.
      1: simpl; eauto.
      simpl Z.pow in *; unfold Z.pow_pos in *; simpl PosDef.Pos.iter in *; simpl Z.sub in *.
      rewrite Heqb.
      eapply steps_refl.
    }
    simpl.
    repeat split; eauto.
    all: unfold code_rel in *; cleanup; eauto.
    1: eexists; eexists; eauto.
    eexists; repeat split; repeat eexists; eauto.
    3: rewrite H16; lia.
    2: rewrite Z.add_comm; reflexivity.
    unfold v_inv in *; cleanup; subst.
    eapply z_lt_bound.
    rewrite Z.add_comm; assumption.
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto.
  admit.
Admitted.

Theorem c_exp_Sub : forall (e1 e2: exp),
  goal_exp e1 -> goal_exp e2 ->
  goal_exp (ImpSyntax.Sub e1 e2).
Proof.
  intros.
  unfold goal_exp; intros.
  simpl eval_exp in *.
  simpl c_exp in *; unfold c_sub in *; unfold dlet in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp in *; subst.
  destruct o eqn:?; subst.
  2: {
    destruct v eqn:?; subst.
    all: inversion H1; subst.
    all: eapply eval_exp_not_stop in Heqp; unfold not in *; eauto; exfalso; apply Heqp; eauto.
  }
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct o eqn:?; subst.
  2: {
    destruct v eqn:?; subst.
    all: inversion H1; subst.
    all: eapply eval_exp_not_stop in Heqp0; unfold not in *; eauto; exfalso; apply Heqp0; eauto.
  }
  unfold combine_word in *.
  destruct v eqn:?.
  2: inversion H1; subst; contradiction.
  destruct v0 eqn:?.
  2: inversion H1; subst; contradiction.
  unfold_outcome; inversion H1; subst.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H in Heqp; clear H; eauto; inversion H3; subst.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup.
  2: eexists; split; eauto; simpl; split; eauto.
  unfold exp_res_rel in *; cleanup.
  unfold goal_exp in H0.
  rewrite <- H15 in *.
  rw ltac:(specialize (steps_instructions _ _ _ _ H10)).
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  2: eexists; split; [eapply steps_trans|]; eauto; simpl; split; eauto.
  all: unfold exp_res_rel in *; cleanup.
  1: instantiate (1 := (Word x :: curr)) in H15; simpl in *; cleanup.
  1: {
    unfold state_rel in *; cleanup.
    specialize (has_stack_even t (curr ++ rest) H6) as ?.
    specialize (has_stack_even _ _ H14) as ?.
    specialize (has_stack_even _ _ H15) as ?.
    unfold has_stack in *; cleanup; subst.
    unfold env_ok in *; cleanup.
    inversion H15; clear H15; subst.
    inversion H14; clear H14; subst.
    rw ltac:(specialize (steps_instructions _ _ _ _ H0)).
    destruct (word.ltu x7 x9) eqn:?.
    1: {
      eexists.
      split.
      1: {
        eapply steps_trans.
        1: eapply H10.
        eapply steps_trans.
        1: eapply H0.
        rewrite <- H16 in *.
        unfold code_in in H9; cleanup; subst.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_pop; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump; eauto.
        1: constructor; simpl; eauto.
        rewrite Heqb.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_sub; eauto.
        1: assert (pc s0 + 3 = pc s0 + 1 + 1 + 1) as -> by lia.
        1: unfold_stack; eauto.
        1-2: simpl; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_mov; eauto.
        1: assert (pc s0 + 3 = pc s0 + 1 + 1 + 1) as -> by lia.
        1: unfold_stack; eauto.
        1: simpl; eauto.
        eapply steps_refl.
      }
      simpl.
      repeat split; eauto.
      all: unfold code_rel in *; cleanup; eauto.
      1: eexists; eexists; eauto.
      eexists; repeat split; repeat eexists; eauto.
      2: lia.
      rewrite word.unsigned_ltu in *.
      eapply sub_lt_bound; eauto.
    }
    eexists.
    split.
    1: {
      eapply steps_trans.
      1: eapply H10.
      eapply steps_trans.
      1: eapply H0.
      rewrite <- H16 in *.
      unfold code_in in H9; cleanup; subst.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; eauto.
      1: constructor; simpl; eauto.
      rewrite Heqb.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      1: simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_sub; eauto.
      1: unfold_stack; eauto.
      1: simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      1: simpl; eauto.
      eapply steps_refl.
    }
    simpl.
    repeat split; eauto.
    all: unfold code_rel in *; cleanup; eauto.
    1: eexists; eexists; eauto.
    eexists; repeat split; repeat eexists; eauto.
    3: lia.
    1: admit. (* ((Naive.unsigned x9 - Naive.unsigned x7) mod Z.pow_pos 2 64 <?
Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true *)
    admit. (* Some (Naive.wrap (Naive.unsigned x9 - Naive.unsigned x9)) =
Some (Naive.wrap (Naive.unsigned x9 - Naive.unsigned x7)) *)
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto.
  admit.
Admitted.




