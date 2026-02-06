Require Import impboot.utils.Core.

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

Theorem mul_div_id: forall n m,
  n mod m = 0 ->
  n / m * m = n.
Proof.
  intros n m H.
  destruct m as [|m'].
  - simpl in H.
    destruct n.
    + simpl; reflexivity.
    + discriminate H.
  - assert (S m' <> 0) as Hnz by (intro; discriminate).
    pose proof (Nat.div_mod n (S m') Hnz) as Hdm.
    rewrite H in Hdm.
    rewrite Nat.add_0_r in Hdm.
    rewrite Nat.mul_comm in Hdm.
    exact (eq_sym Hdm).
Qed.

Lemma nth_error_list_update_eq: forall {A: Type} n (v: A) xs,
  (exists v0, nth_error xs n = Some v0) <->
  nth_error (list_update n v xs) n = Some v.
Proof.
  induction n; destruct xs; simpl; split; intros; eauto; cleanup.
  1: rewrite <- IHn; eauto.
  rewrite IHn; eauto.
Qed.

Lemma nth_error_list_update_eq1: forall {A: Type} n (v0 v: A) xs,
  nth_error (list_update n v xs) n = Some v0 -> nth_error (list_update n v xs) n = Some v.
Proof.
  induction n; destruct xs; simpl; intros; eauto; cleanup.
Qed.

Lemma string_app_r_nil: forall (s: string),
  (s ++ ""%string)%string = s.
Proof.
  induction s; simpl; intros; f_equal; eauto.
Qed.

Lemma string_app_assoc: forall (s1 s2 s3: string),
  (s1 ++ (s2 ++ s3))%string = ((s1 ++ s2) ++ s3)%string.
Proof.
  induction s1; simpl; intros; f_equal; eauto.
Qed.

Lemma string_cons_nil_app: forall (c: ascii) (s: string),
  (String c "" ++ s)%string = (String c s)%string.
Proof.
  simpl; intros; f_equal; eauto.
Qed.
