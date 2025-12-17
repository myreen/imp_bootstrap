Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Import Llist.
Require Import impboot.utils.Env.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.imperative.ImpSemantics.
Require Import impboot.commons.ProofUtils.

Require Import Stdlib.Program.Equality.

Require Import Patat.Patat.

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

Theorem eval_exps_not_stop: forall es s res s1 v,
  eval_exps es s = (res, s1) ->
  res ≠ Stop Crash ->
  res <> Stop v.
Proof.
  induction es; intros; simpl in *; unfold_outcome; cleanup; try congruence.
  unfold_monadic.
  destruct eval_exp eqn:?.
  destruct eval_exps eqn:?.
  pat `match ?o with _ => _ end = _` at destruct o; cleanup.
  2: pat `eval_exp _ _ = _` at eapply eval_exp_not_stop in pat; eauto; congruence.
  pat `eval_exps _ _ = _` at rename pat into Heval.
  pat `match ?o with _ => _ end = _` at destruct o; cleanup; try congruence.
  pat `forall _ _ _, _` at eapply pat in Heval; eauto.
Qed.

Theorem eval_test_not_stop: forall t s res s1 v,
  eval_test t s = (res, s1) ->
  res ≠ Stop Crash ->
  res <> Stop v.
Proof.
  Opaque word.eqb.
  Opaque word.of_Z.
  induction t; intros.
  all: simpl eval_test in *.
  all: unfold lookup_var, bind in *; unfold_outcome; simpl in *.
  - destruct eval_exp eqn:?; destruct o eqn:?; cleanup.
    all: eapply eval_exp_not_stop in Heqp; eauto; try congruence.
    destruct eval_exp eqn:?; destruct o0 eqn:?; subst; cleanup.
    all: eapply eval_exp_not_stop in Heqp0; eauto; try congruence.
    destruct c eqn:?; simpl in *; cleanup.
    all: destruct v0 eqn:?; destruct v1 eqn:?; subst; cleanup.
    all: unfold_outcome; cleanup; try congruence.
    destruct (word.eqb w _) eqn:?; cleanup.
    all: congruence.
  - destruct eval_test eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt1 in Heqp; eauto.
    destruct (eval_test t2) eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt2 in Heqp0; eauto.
    congruence.
  - destruct eval_test eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt1 in Heqp; eauto.
    destruct (eval_test t2) eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt2 in Heqp0; eauto.
    congruence.
  - destruct eval_test eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt in Heqp; eauto.
    congruence.
  (* TODO(kπ) Does this imply some sort of error? *)
  Unshelve.
  + exact Abort.
  + exact Abort.
Qed.

Theorem eval_cmd_steps_done_steps_up: forall (fuel: nat) (c: cmd) (s s1: state) (o: outcome unit),
  eval_cmd c (EVAL_CMD fuel) s = (o, s1) -> s.(steps_done) <= s1.(steps_done).
Proof.
  Opaque EVAL_CMD.
  induction fuel; induction c; simpl; intros; unfold_outcome; unfold_monadic; cleanup; simpl in *.
  Opaque eval_cmd.
  Transparent EVAL_CMD.
  all: repeat lazymatch goal with
  | IH: forall r s0 s1, eval_cmd ?c _ _ = _ -> _, H: context [ let (_, _) := eval_cmd ?c ?f ?s2 in _ ] |- _ =>
    let Hd := fresh "Hd" in
    destruct (eval_cmd c f s2) eqn:Hd; subst; cleanup; specialize IH with (1 := Hd); clear Hd
  | H: context [ match ?o with _ => _ end ] |- _ => destruct o eqn:?; subst; cleanup
  | H: eval_exp _ _ = _ |- _ => eapply eval_exp_pure in H; subst
  | H: eval_exps _ _ = _ |- _ => eapply eval_exps_pure in H; subst
  | H: eval_test _ _ = _ |- _ => eapply eval_test_pure in H; subst
  | H: EVAL_CMD 0 _ _ = _ |- _ => with_strategy transparent [EVAL_CMD] unfold EVAL_CMD in H
  | H: EVAL_CMD (S _) _ _ = _ |- _ => progress simpl in *
  | H: (_, _) = (_, _) |- _ => inversion H; clear H; subst
  | _ => solve [eapply Nat.le_refl] || (unfold assign, alloc, update, get_vars, get_body_and_set_vars, set_varsM,
    catch_return, set_vars, set_memory, dest_word, get_char, put_char, set_output, inc_steps_done, add_steps_done, set_steps_done in *)
        || unfold_outcome || unfold_monadic || (simpl in *)
  end.
  all: try solve [eauto 4 using Nat.le_trans].
  1: eapply Nat.le_trans; [eauto|].
  all: pat `eval_cmd _ _ _ = _` at specialize IHfuel with (1 := pat); simpl in *.
  all: lia.
Qed.

(* TODO(kπ) we need something like this, so that we know that:
  When we increase fuel for any diverging program ->
    We increase the number of steps done by the imperative evaluator ->
      The assembly also does more steps
*)
Theorem eval_cmd_steps_done_ge_fuel: forall (fuel: nat) (c: cmd) (s s1: state) (o: outcome unit),
  eval_cmd c (EVAL_CMD fuel) s = (o, s1) -> o = Stop TimeOut -> (fuel <= s1.(steps_done) - s.(steps_done)).
Proof.
  Transparent eval_cmd.
  Opaque EVAL_CMD.
  induction fuel; induction c; simpl; intros; unfold_outcome; unfold_monadic; cleanup; simpl in *; try congruence.
  Opaque eval_cmd.
  all: assert (@Stop Value TimeOut <> Stop Crash) as HTimeOutneqCrash by congruence.
  all: assert (@Stop (list Value) TimeOut <> Stop Crash) as HTimeOutneqCrash1 by congruence.
  all: assert (@Stop bool TimeOut <> Stop Crash) as HTimeOutneqCrash2 by congruence.
  all: try eapply Nat.le_0_l.
  all: repeat match goal with
  | IH: forall s0 s1 o, eval_cmd ?c _ _ = _ -> _, H: context [ let (_, _) := eval_cmd ?c ?f ?s2 in _ ] |- _ =>
    let Hd := fresh "Hd" in
    destruct (eval_cmd c f s2) eqn:Hd; subst; cleanup; specialize IH with (1 := Hd);
    specialize eval_cmd_steps_done_steps_up with (1 := Hd) as ?(* ; clear Hd *)
  | H: context [ match ?o with _ => _ end ] |- _ => destruct o eqn:?; subst; cleanup
  | H: eval_exp _ _ = _ |- _ =>
    specialize eval_exp_pure with (1 := H) as ?; subst; eapply eval_exp_not_stop with (v := TimeOut) (2 := HTimeOutneqCrash) in H; eauto
  | H: eval_exp _ _ = (_, _) |- _ =>
    specialize eval_exp_pure with (1 := H) as ?; subst; clear H
  | H: eval_exps _ _ = _ |- _ =>
    specialize eval_exps_pure with (1 := H) as ?; subst; eapply eval_exps_not_stop with (v := TimeOut) (2 := HTimeOutneqCrash1) in H; eauto
  | H: eval_test _ _ = _ |- _ =>
    specialize eval_test_pure with (1 := H) as ?; subst; eapply eval_test_not_stop with (v := TimeOut) (2 := HTimeOutneqCrash2) in H; eauto
  | H: EVAL_CMD 0 _ _ = _ |- _ => with_strategy transparent [EVAL_CMD] unfold EVAL_CMD in H
  | H: Cont _ = Stop _ |- _ => inversion H; clear H; subst
  | H: Stop TimeOut <> Stop TimeOut |- _ => congruence
  | H: (_, _) = (_, _) |- _ => inversion H; clear H; subst
  | _ => (unfold assign, alloc, update, get_vars, get_body_and_set_vars, set_varsM,
    catch_return, set_vars, set_memory, dest_word, get_char, put_char, set_output, inc_steps_done, add_steps_done, set_steps_done in *)
        || unfold_outcome || unfold_monadic || (simpl in *)
  end.
  all: try solve [eauto 4 using Nat.le_trans].
  1: eapply IHc2 in H; eauto; lia.
  1: eapply IHc1 in H; eauto; specialize eval_test_pure with (1 := Heqp) as ?; subst; lia.
  1: eapply IHc2 in H; eauto; specialize eval_test_pure with (1 := Heqp) as ?; subst; lia.
  2: specialize IHc with (1 := eq_refl); specialize eval_test_pure with (1 := Heqp) as ?; subst; lia.
  Transparent EVAL_CMD.
  all: simpl in *; unfold inc_steps_done, add_steps_done, set_steps_done, bind in *; unfold_outcome.
  1: {
    specialize eval_test_pure with (1 := Heqp) as ?; subst.
    specialize eval_cmd_steps_done_steps_up with (1 := H) as ?; simpl in *.
    eapply IHfuel in H; eauto; simpl in *.
    simpl in *; rewrite Nat.sub_add_distr in *; rewrite Nat.add_le_mono_r with (p := 1) in H; rewrite Nat.add_1_r in *.
    eapply Nat.le_trans; [eauto|].
    lia.
  }
  simpl in *.
  specialize eval_exps_pure with (1 := Heqp) as ?; subst.
  specialize eval_cmd_steps_done_steps_up with (1 := Heqp2) as ?; simpl in *.
  eapply IHfuel in Heqp2; eauto; simpl in *.
  simpl in *; rewrite Nat.sub_add_distr in *; rewrite Nat.add_le_mono_r with (p := 1) in Heqp2; rewrite Nat.add_1_r in *.
  eapply Nat.le_trans; [eauto|].
  lia.
Qed.

Theorem catch_return_steps_done_ge_fuel: forall (c: cmd) (fuel: nat) (s s1: state) (o: outcome Value),
  catch_return (eval_cmd c (EVAL_CMD fuel)) s = (o, s1) -> o = Stop TimeOut -> (fuel <= s1.(steps_done) - s.(steps_done)).
Proof.
  intros * H Htime.
  unfold catch_return in *.
  destruct (eval_cmd c (EVAL_CMD fuel) s) eqn:?; subst; cleanup.
  destruct o0 eqn:?; subst; unfold_outcome; cleanup.
  destruct v eqn:?; subst; unfold_outcome; cleanup; try congruence.
  eapply eval_cmd_steps_done_ge_fuel in Heqp; eauto.
Qed.

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