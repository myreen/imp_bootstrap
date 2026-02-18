Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Import Llist.
Require Import impboot.utils.Env.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMSemantics.
Require Import impboot.commons.ProofUtils.
From Stdlib Require Import Relations.Relation_Operators.

Require Import Stdlib.Program.Equality.

Require Import Patat.Patat.

Ltac cleanup :=
  repeat match goal with
  | [ H: _ /\ _ |- _ ] => destruct H
  | [ H: exists _, _ |- _ ] => destruct H
  | [ H: True |- _ ] => clear H
  | [ H: Some _ = Some _ |- _ ] => inversion H; subst; clear H
  | [ H: None = Some _ |- _ ] => inversion H; subst; clear H
  | [ H: Some _ = None |- _ ] => inversion H; subst; clear H
  | [ H: (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ H: _ :: _ = _ :: _ |- _ ] => inversion H; subst; clear H
  | [ H: False |- _ ] => inversion H
  end.

Lemma map_uninit_eq: forall {A B} (xs: list A) (ys: list B),
  List.length xs = List.length ys ->
  map (fun _ => Uninit) xs = map (fun _ => Uninit) ys.
Proof.
  induction xs; destruct ys; intros; simpl in *; try reflexivity; try congruence.
  f_equal; eauto.
Qed.

Theorem step_determ: forall x y z,
  step x y -> step x z -> y = z.
Proof.
  destruct x; intros * Hstep1 Hstep2.
  2: inversion Hstep1.
  inversion Hstep1; inversion Hstep2; subst; try reflexivity; try congruence.
  all: pat `fetch s = _` at rewrite pat in *; cleanup.
  - destruct yes; destruct yes0; eauto.
    all: do 2 spat `take_branch` at inversion spat; subst; cleanup.
    all: pat `regs s r1 = _` at rewrite pat in *; cleanup.
    all: pat `regs s r2 = _` at rewrite pat in *; cleanup.
    all: rewrite ?Z.ltb_lt, ?Z.ltb_ge in *.
    all: lia.
  - pat `stack s = _` at rewrite pat in *; cleanup.
    pat `?xs ++ _ = _ ++ _` at eapply f_equal with (f := (fun l => skipn (List.length xs) l)) in pat.
    rewrite skipn_app, Nat.sub_diag, skipn_all in *; simpl in *.
    pat `List.length _ = _` at rewrite pat in *; cleanup.
    rewrite skipn_app, Nat.sub_diag, skipn_all in *; simpl in *.
    subst; eauto.
  - assert (map (fun _ => Uninit) xs = map (fun _ => Uninit) xs0) as ->; eauto.
    eapply map_uninit_eq; eauto.
Qed.

Theorem steps_from_Halt_is_Halt: forall w o n s n1,
  steps (Halt w o, n) (s, n1) ->
    s = (Halt w o) ∧ n1 = n.
Proof.
  intros * H.
  dependent induction H; subst; eauto.
  all: try spat `step` at inversion spat.
  eapply IHsteps2; eauto.
  f_equal.
  all: specialize (IHsteps1 w o n s2 n2 eq_refl eq_refl) as ?; cleanup; subst.
  all: eauto.
Qed.

Theorem steps_when_step_to_Halt: forall s fuel fuel1 s1 e o,
  step s (Halt e o) ->
  steps (s, fuel) (s1, fuel1) ->
  (s1 = s /\ fuel1 = fuel) \/ s1 = (Halt e o).
Proof.
  intros * Hstep Hsteps.
  dependent induction Hsteps; intros; eauto.
  - right; eapply step_determ; eauto.
  - right; eapply step_determ; eauto.
  - specialize IHHsteps1 with (1 := Hstep) (2 := eq_refl) (3 := eq_refl) as ?.
    destruct H; cleanup; subst.
    + specialize IHHsteps2 with (1 := Hstep) (2 := eq_refl) (3 := eq_refl) as ?; cleanup; subst; eauto.
    + eapply steps_from_Halt_is_Halt in Hsteps2; cleanup; subst; eauto.
Qed.

Theorem steps_step_to_Halt_eq: forall s fuel fuel1 e1 o1 e2 o2,
  step s (Halt e1 o1) ->
  steps (s, fuel) (Halt e2 o2, fuel1) ->
  e1 = e2 /\ o1 = o2.
Proof.
  intros * Hstep Hsteps.
  dependent induction Hsteps; intros; eauto.
  - inversion Hstep.
  - eapply step_determ in H; eauto; subst.
    pat `Halt _ _ = Halt _ _` at inversion H; subst; cleanup; eauto.
  - eapply step_determ with (2 := Hstep) in H; eauto; subst.
    pat `Halt _ _ = Halt _ _` at inversion H; subst; cleanup; eauto.
  - pat `steps (s, fuel) _` at eapply steps_when_step_to_Halt in pat; eauto.
    destruct Hsteps1; cleanup; subst.
    2: eapply steps_from_Halt_is_Halt in Hsteps2; cleanup.
    2: pat `Halt _ _ = Halt _ _` at inversion pat; subst; cleanup; eauto.
    specialize IHHsteps2 with (1 := Hstep) (2 := eq_refl) (3 := eq_refl) as ?.
    eauto.
Qed.

Theorem RTC_trans: forall A (R: A -> A -> Prop) x y z,
  clos_refl_trans_1n A R x y ->
  clos_refl_trans_1n A R y z ->
  clos_refl_trans_1n A R x z.
Proof.
  intros A R x y z Hxy Hyz.
  induction Hxy; eauto.
  eapply rt1n_trans; eauto.
Qed.

Theorem steps_IMP_RTC: forall s1 s2 n1 n2,
  steps (s1, n1) (s2, n2) ->
  clos_refl_trans_1n s_or_h step s1 s2.
Proof.
  intros * H.
  dependent induction H; intros; eauto.
  - eapply rt1n_refl.
  - eapply rt1n_trans; eauto.
    eapply rt1n_refl.
  - eapply rt1n_trans; eauto.
    eapply rt1n_refl.
  - eapply RTC_trans; eauto.
Qed.

Theorem RTC_step_determ: forall x e1 o1 e2 o2,
  clos_refl_trans_1n s_or_h step x (Halt e1 o1) ->
  clos_refl_trans_1n s_or_h step x (Halt e2 o2) ->
  e1 = e2 /\ o1 = o2.
Proof.
  intros * Hrtc1 Hrtc2.
  dependent induction Hrtc1; intros; eauto.
  - inversion Hrtc2; subst; eauto.
    pat `step (Halt _ _) _` at inversion pat.
  - inversion Hrtc2; subst; eauto.
    + pat `step (Halt _ _) _` at inversion pat.
    + specialize IHHrtc1 with (1 := eq_refl).
      pat `step x y` at eapply step_determ in pat; eauto; subst; eauto.
Qed.

Theorem steps_determ_Halt: forall s n1 n2 n3 e1 o1 e2 o2,
  steps (s, n1) (Halt e1 o1, n2) ->
  steps (s, n1) (Halt e2 o2, n3) ->
  e1 = e2 /\ o1 = o2.
Proof.
  intros * Hsteps1 Hsteps2.
  eapply steps_IMP_RTC in Hsteps1.
  eapply steps_IMP_RTC in Hsteps2.
  eapply RTC_step_determ; eauto.
Qed.

(* TODO: share the following with ImpToAsmCodegenProof  *)


Theorem step_mono: forall s0 s1,
  step (State s0) (State s1) -> prefix s0.(output) s1.(output) = true.
Proof.
  inversion 1; intros; subst; simpl.
  all: try eapply prefix_refl.
  1: unfold write_mem in *; spat `match ?c with _ => _ end` at destruct c eqn:?; cleanup; simpl.
  1: eapply prefix_refl.
  eapply prefix_correct.
  rewrite substr_app; reflexivity.
Qed.
