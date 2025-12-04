Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Import Llist.
Require Import impboot.utils.Env.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMSemantics.

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
  step x y ∧ step x z -> y = z.
Proof.
  destruct x; intros; destruct H as [Hstep1 Hstep2].
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

Theorem steps_determ_Halt: forall s fuel s1 s2 e1 e2 o1 o2,
  steps (s, fuel) (Halt e1 o1, s1) ->
  steps (s, fuel) (Halt e2 o2, s2) ->
  e1 = e2 /\ o1 = o2.
Proof.
Admitted.

(* TODO: share the following with ImpToAsmCodegenProof  *)
Theorem substring_noop: forall s,
  substring 0 (length s) s = s.
Proof.
  induction s.
  - simpl; reflexivity.
  - simpl; f_equal; assumption.
Qed.
Theorem prefix_refl: forall o,
  prefix o o = true.
Proof.
  intros; eapply prefix_correct; eapply substring_noop.
Qed.
Theorem prefix_trans: forall s1 s2 s3,
  prefix s1 s2 = true ->
  prefix s2 s3 = true ->
  prefix s1 s3 = true.
Proof.
  intros s1 s2. revert s1.
  induction s2 as [|b s2' IH]; intros s1 s3 H1 H2.
  - destruct s1 as [|a s1'].
    + simpl. assumption.
    + simpl in H1. discriminate H1.
  - destruct s1 as [|a s1'].
    + destruct s3 as [|c s3']; simpl; reflexivity.
    + simpl in H1.
      destruct (ascii_dec a b) as [Heq|Hneq].
      * subst b.
        destruct s3 as [|c s3'].
        -- simpl in H2.
           destruct (ascii_dec a a) as [_|Hcontr]; [discriminate H2|contradiction].
        -- simpl in H2.
           destruct (ascii_dec a c) as [Heq2|Hneq2].
           ++ subst c.
              simpl.
              destruct (ascii_dec a a) as [_|Hcontr]; [|contradiction].
              eapply IH; eassumption.
           ++ discriminate H2.
      * discriminate H1.
Qed.
Lemma substring_append: forall (s s1: string),
  substring 0 (length s) (s ++ s1) = s.
Proof.
  induction s; simpl; intros.
  - destruct s1; simpl; reflexivity.
  - f_equal; eauto.
Qed.

Theorem step_mono: forall s0 s1,
  step (State s0) (State s1) -> prefix s0.(output) s1.(output) = true.
Proof.
  inversion 1; intros; subst; simpl.
  all: try eapply prefix_refl.
  1: unfold write_mem in *; spat `match ?c with _ => _ end` at destruct c eqn:?; cleanup; simpl.
  1: eapply prefix_refl.
  eapply prefix_correct.
  rewrite substring_append; reflexivity.
Qed.
