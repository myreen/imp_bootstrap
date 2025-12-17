From impboot Require Import utils.Core.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
From impboot Require Import imp2asm.ImpToASMCodegen.
From impboot Require Import commons.ProofUtils.

Theorem nat_modulo_le: forall (n m: nat),
  nat_modulo n m <= m.
Proof.
  intros.
  unfold nat_modulo, dlet.
  destruct m; try lia.
  (* rewrite mul_div_id. *)
  (* ltac1:(lia). *)
Admitted.

Fixpoint num2str_f (n: nat) (fuel: nat) (str: string): string :=
  if (n <? 10)%nat then
    let/d nd := nat_modulo n 10 in
    let/d n1 := 48 + nd in
    let/d a:= ascii_of_nat n1 in
    let/d res := String a str in
    res
  else match fuel with
  | 0 =>
    let/d res := ""%string in
    res
  | S fuel =>
    let/d nd := nat_modulo n 10 in
    let/d n1 := 48 + nd in
    let/d a := ascii_of_nat n1 in
    let/d str1 := String a str in
    let/d nrest := n / 10 in
    let/d res := num2str_f nrest fuel str1 in
    res
  end.

Theorem num2str_terminates_str: forall (n1: nat) (n: nat) (str: string),
  n <= n1 -> num2str_f n n1 str <> ""%string.
Proof.
  induction n1; intros; simpl; unfold dlet; simpl; [inversion H; simpl; congruence|].
  destruct (n <? 10)%nat; [congruence|].
  specialize Nat.divmod_spec with (x := n) (y := 9) (q := 0) (u := 9) as ?.
  destruct Nat.divmod eqn:?; simpl.
  eapply IHn1.
  lia.
Qed.

Definition num2str (n: nat) (str: string): string :=
  let/d res := num2str_f n n str in
  res.

Theorem num2str_terminates: forall (n: nat) (str: string),
  num2str n str <> ""%string.
Proof.
  intros; eapply num2str_terminates_str; lia.
Qed.

Fixpoint N2str_f (n: N) (fuel: nat) (str: string): string :=
  if (n <? 10)%N then
    let/d n1 := (48 + n)%N in
    let/d a:= ascii_of_N n1 in
    let/d res := String a str in
    res
  else match fuel with
  | 0%nat =>
    let/d res := EmptyString in
    res
  | S fuel =>
    let/d nd := N_modulo n 10 in
    let/d n1 := (48 + nd)%N in
    let/d a := ascii_of_N n1 in
    let/d str1 := String a str in
    let/d nrest := (n / 10)%N in
    let/d res := N2str_f nrest fuel str1 in
    res
  end.

Theorem N2str_terminates_str: forall (n1: nat) (n: N) (str: string),
  (n <= (N.of_nat n1 * 10) - 1)%N -> N2str_f n n1 str <> EmptyString.
Proof.
  Opaque N.add N.div N_modulo.
  induction n1; intros; simpl; unfold dlet; simpl.
  1: change (N.of_nat 0) with 0%N in H; destruct (n <? _)%N eqn:?; rewrite ?N.ltb_ge in *; try lia; congruence.
  destruct (n <? 10)%N eqn:?; [congruence|]; rewrite N.ltb_ge in *.
  eapply IHn1.
  assert (N.of_nat (S n1) = 1 + (N.of_nat n1))%N as Htmp by lia; rewrite Htmp in *; clear Htmp.
  assert (1 <= N.of_nat n1)%N by lia.
  eapply N.Div0.div_le_mono with (c := 10%N) in H.
  eapply N.le_trans; [eauto|].
  eapply N.le_trans with (m := (1 + N.of_nat n1)%N).
  1: apply N.Div0.div_le_upper_bound; lia.
  apply (N2Z.inj_le); lia.
Qed.

Definition N2str (n: N) (str: string): string :=
  let/d res := N2str_f n (N.to_nat (n / 10 + 1)) str in
  res.

Theorem N2str_terminates: forall (n: N) str,
  N2str n str <> EmptyString.
Proof.
  intros; eapply N2str_terminates_str; rewrite Nnat.N2Nat.id.
  rewrite (N.div_mod n 10) at 1 by discriminate.
  rewrite N.mul_comm, N.mul_add_distr_r, N.mul_1_l.
  assert (n mod 10 < 10)%N by (eapply N.mod_lt; lia).
  destruct (n mod 10)%N eqn:?; rewrite ?N.eqb_eq, ?N.eqb_neq in *; subst; try lia.
Qed.
