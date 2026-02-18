From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
From impboot Require Import commons.ProofUtils.

Fixpoint mulnat (a b: nat): nat :=
  match b with
  | 0%nat => 0%nat
  | S b' => a + mulnat a b'
  end.

Definition nat_mod (n1 n2: nat): nat :=
  match n2 with
  | 0%nat => 0
  | S _ => n1  - (n2 * (n1 / n2))
  end.

Definition natmod10 (n: nat): nat :=
  n - (10 * (n / 10)).

Lemma natmod10_spec: forall n,
  natmod10 n = nat_mod n 10.
Proof. reflexivity. Qed.

Lemma mulN_f_oblig:
  forall (b_min_1 b: N) (NE: b <> 0%N) (BMIN1EQ: b_min_1 = (b - 1)%N), (b_min_1 < b)%N.
Proof.
  intros; subst.
  apply N.sub_lt; lia.
Qed.

Fixpoint mulN_f (a b: N) (fuel: nat): N :=
  match fuel with
  | 0%nat => 0%N
  | S fuel =>
    match b with
    | 0%N => 0%N
    | _ => a + mulN_f a (b - 1) fuel
    end
  end.

Definition mulN_10 (a: N): N :=
  (let/d a2 := a + a in
  let/d a4 := a2 + a2 in
  let/d a8 := a4 + a4 in
  let/d a10 := a8 + a2 in
  a10)%N.

Lemma mulN_10_spec_r: forall a,
  mulN_10 a = (a * 10)%N.
Proof.
  intros; unfold mulN_10, dlet; simpl; lia.
Qed.

Lemma mulN_10_spec_l: forall a,
  mulN_10 a = (10 * a)%N.
Proof.
  intros; unfold mulN_10, dlet; simpl; destruct a; simpl; lia.
Qed.

Definition mulN_256 (a: N): N :=
  (let/d a2 := a + a in
  let/d a4 := a2 + a2 in
  let/d a8 := a4 + a4 in
  let/d a16 := a8 + a8 in
  let/d a32 := a16 + a16 in
  let/d a64 := a32 + a32 in
  let/d a128 := a64 + a64 in
  let/d a256 := a128 + a128 in
  a256)%N.

Lemma mulN_256_spec_r: forall a,
  mulN_256 a = (a * 256)%N.
Proof.
  intros; unfold mulN_256, dlet; simpl; lia.
Qed.

Lemma mulN_256_spec_l: forall a,
  mulN_256 a = (256 * a)%N.
Proof.
  intros; unfold mulN_256, dlet; simpl; destruct a; simpl; lia.
Qed.

Definition mulnat_8 (a: nat): nat :=
  let/d a2 := a + a in
  let/d a4 := a2 + a2 in
  let/d a8 := a4 + a4 in
  a8.

Lemma mulnat_8_spec_r: forall a,
  mulnat_8 a = (a * 8)%nat.
Proof.
  intros; unfold mulnat_8, dlet; simpl; lia.
Qed.

Lemma mulnat_8_spec_l: forall a,
  mulnat_8 a = (8 * a)%nat.
Proof.
  intros; unfold mulnat_8, dlet; simpl; lia.
Qed.

Definition mulnat10 (a: nat): nat :=
  let/d a2 := a + a in
  let/d a4 := a2 + a2 in
  let/d a8 := a4 + a4 in
  let/d a10 := a8 + a2 in
  a10.

Lemma mulnat10_spec_r: forall a,
  mulnat10 a = (a * 10)%nat.
Proof.
  intros; unfold mulnat10, dlet; simpl; lia.
Qed.

Lemma mulnat10_spec_l: forall a,
  mulnat10 a = (10 * a)%nat.
Proof.
  intros; unfold mulnat10, dlet; simpl; lia.
Qed.

Definition mulN (a b: N): N :=
  mulN_f a b (1 + N.to_nat b).

Lemma mulN_f_terminates: forall (fuel: nat) (a b: N) ,
  a <> 0%N -> b <> 0%N ->
  fuel = S (N.to_nat b) ->
  mulN_f a b fuel <> 0%N.
Proof.
  intros fuel a b Ha Hb Hfuel.
  destruct fuel; [lia|].
  simpl; unfold dlet; simpl.
  destruct b; [lia|].
  lia.
Qed.

Lemma mulN_f_spec: forall (fuel: nat) (a b: N),
  fuel = S (N.to_nat b) ->
  mulN_f a b fuel = (a * b)%N.
Proof.
  induction fuel; intros.
  - lia.
  - simpl. destruct b as [|p].
    + simpl. lia.
    + unfold dlet; simpl.
      match goal with
      | |- context [mulN_f ?a ?x ?f] =>
        replace x with (N.pos p - 1)%N by reflexivity
      end.
      rewrite IHfuel.
      * rewrite N.mul_sub_distr_l, N.mul_1_r.
        assert (a <= a * N.pos p)%N by (rewrite <- N.mul_1_r at 1; apply N.mul_le_mono_l; lia).
        lia.
      * rewrite Nnat.N2Nat.inj_sub. simpl in *. lia.
Qed.

Theorem mulN_spec: forall (a b: N),
  mulN a b = (a * b)%N.
Proof.
  intros.
  unfold mulN, dlet.
  apply mulN_f_spec.
  lia.
Qed.

Theorem mulnat_spec: forall (a b: nat),
  mulnat a b = a * b.
Proof.
  induction b; intros; simpl; unfold dlet; simpl.
  - lia.
  - rewrite IHb.
    lia.
Qed.

Definition N_modulo (n1 n2: N): N :=
  match (N.to_nat n2) with
  | 0%nat => 0
  | _ => n1  - (n2 * (n1 / n2))
  end.

Definition Nmod_10 (n: N): N :=
  n - (10 * (n / 10)).

Lemma Nmod_10_spec: forall n,
  Nmod_10 n = N_modulo n 10.
Proof. reflexivity. Qed.

Definition Nmod_256 (n: N): N :=
  n - (256 * (n / 256)).

Lemma Nmod_256_spec: forall n,
  Nmod_256 n = N_modulo n 256.
Proof. reflexivity. Qed.

Theorem nat_mod_le: forall (n m: nat),
  nat_mod n m <= m.
Proof.
  intros.
  unfold nat_mod, dlet.
  destruct m; try lia.
  rewrite <- Nat.Div0.mod_eq.
  specialize Nat.mod_upper_bound with (a := n) (b := S m) as ?.
  lia.
Qed.

Theorem N_modulo_le: forall (n m: N),
  (N_modulo n m <= m)%N.
Proof.
  Opaque N.add N.div N.mul.
  intros.
  unfold N_modulo, dlet.
  destruct (N.to_nat m) eqn:?; simpl; try lia.
  rewrite <- N.Div0.mod_eq.
  specialize N.mod_lt with (a := n) (b := m) as ?.
  lia.
Qed.

Theorem N_modulo_lt: forall (n m: N),
  (m <> 0%N) -> (N_modulo n m < m)%N.
Proof.
  intros.
  specialize N_modulo_le with (n := n) (m := m) as ?.
  unfold N_modulo, dlet in *; simpl.
  destruct (N.to_nat m) eqn:?; simpl in *; try lia.
  destruct m as [|p]; simpl in *; try lia.
  rewrite <- N.Div0.mod_eq.
  eapply N.mod_lt; lia.
Qed.

Fixpoint num2strf (n: nat) (fuel: nat) (str: string): string :=
  if (n <? 10)%nat then
    let/d nd := nat_mod n 10 in
    let/d a:= ascii_of_nat (48 + nd) in
    String a str
  else match fuel with
  | 0 => ""
  | S fuel =>
    let/d nd := nat_mod n 10 in
    let/d a := ascii_of_nat (48 + nd) in
    num2strf (n / 10) fuel (String a str)
  end.

Theorem num2str_terminates_str: forall (n1: nat) (n: nat) (str: string),
  n <= n1 -> num2strf n n1 str <> ""%string.
Proof.
  induction n1; intros; simpl; unfold dlet; simpl; [inversion H; simpl; congruence|].
  destruct (n <? 10)%nat; [congruence|].
  specialize Nat.divmod_spec with (x := n) (y := 9) (q := 0) (u := 9) as ?.
  destruct Nat.divmod eqn:?; simpl.
  eapply IHn1.
  lia.
Qed.

Definition num2str (n: nat) (str: string): string :=
  num2strf n n str.

Theorem num2str_terminates: forall (n: nat) (str: string),
  num2str n str <> ""%string.
Proof.
  intros; eapply num2str_terminates_str; lia.
Qed.

Fixpoint N2str_f (n: N) (fuel: nat) (str: string): string :=
  if (n <? 10)%N then
    let/d nd := Nmod_10 n in
    let/d a:= ascii_of_N (48 + nd) in
    String a str
  else match fuel with
  | 0 => ""
  | S fuel =>
    let/d nd := Nmod_10 n in
    let/d a := ascii_of_N (48 + nd) in
    N2str_f (n / 10) fuel (String a str)
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
  let/d n1 := (n / 10)%N in
  let/d n2 := N.to_nat (n1 + 1) in
  let/d res := N2str_f n n2 str in
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

Fixpoint list_len {A: Type} (l: list A): nat :=
  match l with
  | x :: l => 1 + list_len l
  | [] => 0
  end.

Theorem list_len_spec: forall {A: Type} (l: list A),
  list_len l = List.length l.
Proof.
  induction l; simpl; unfold dlet; simpl; eauto.
Qed.

Fixpoint list_app {A: Type} (l1 l2: list A): list A :=
  match l1 with
  | x :: l1 => x :: list_app l1 l2
  | [] => l2
  end.

Theorem list_app_spec: ∀ {A: Type} (l1 l2: list A),
  list_app l1 l2 = l1 ++ l2.
Proof.
  induction l1; simpl; unfold dlet; simpl; eauto.
  intros; f_equal; eauto.
Qed.

Fixpoint flatten {A: Type} (xs: app_list A): list A :=
  match xs with
  | List l => l
  | Append l1 l2 =>
    list_app (flatten l1) (flatten l2)
  end.

Fixpoint appl_len {A: Type} (xs: app_list A): nat :=
  match xs with
  | List l => list_len l
  | Append l1 l2 =>
    appl_len l1 + appl_len l2
  end.

Fixpoint str_app (s1 s2: string): string :=
  match s1 with
  | EmptyString => s2
  | String c s1 =>
    String c (str_app s1 s2)
  end.

Lemma str_app_spec: forall s1 s2,
  str_app s1 s2 = (s1 ++ s2)%string.
Proof.
  induction s1; intros; simpl; unfold dlet; simpl.
  - reflexivity.
  - rewrite IHs1.
    reflexivity.
Qed.

Open Scope string_scope.

Fixpoint N2asciif (n: N) (fuel: nat): option string :=
  if (n =? 0)%N then None else
  let/d k := N_modulo n 256 in
  if (k <? N_of_ascii "*"%char)%N then None else
  if (N_of_ascii "z"%char <? k)%N then None else
  if (k =? N_of_ascii "."%char)%N then None else
  if (n <? 256)%N then Some (String (ascii_of_N k) EmptyString) else
  match fuel with
  | 0%nat => Some EmptyString
  | S fuel =>
    let/d r := N2asciif (n / 256) fuel in
    match r return option string with
    | None => None
    | Some s => Some (s ++ String (ascii_of_N k) EmptyString)
    end
  end.

Theorem N2asciif_terminates: forall (n1: nat) (n: N),
  (n <= ((N.of_nat n1 * 256) - 1))%N -> N2asciif n n1 <> Some EmptyString.
Proof.
  Opaque N.add N.div N_modulo N_of_ascii.
  induction n1; intros; simpl; unfold dlet; simpl.
  all: destruct (n =? 0)%N eqn:?; rewrite ?N.eqb_eq, ?N.eqb_neq in *; subst; try lia; try congruence.
  set (k := N_modulo n 256).
  destruct (_ <? _)%N eqn:?; try congruence.
  destruct (_ <? k)%N eqn:?; try congruence.
  destruct (_ =? _)%N eqn:?; try congruence.
  destruct (n <? _)%N eqn:?; [congruence|]; rewrite N.ltb_ge in *.
  destruct N2asciif; try congruence.
  destruct s; simpl; try congruence.
Qed.
Transparent N.add N.div N_modulo N_of_ascii.

Definition N2ascii (n: N): option string :=
  N2asciif n (N.to_nat (n / 256 + 1)).

Theorem N2ascii_terminates: forall (n: N),
  N2ascii n <> Some EmptyString.
Proof.
  intros; eapply N2asciif_terminates; rewrite Nnat.N2Nat.id.
  rewrite (N.div_mod n 256) at 1 by discriminate.
  rewrite N.mul_comm, N.mul_add_distr_r, N.mul_1_l.
  assert (n mod 256 < 256)%N by (eapply N.mod_lt; lia).
  destruct (n mod 256)%N eqn:?; rewrite ?N.eqb_eq, ?N.eqb_neq in *; subst; try lia.
Qed.

Definition N2asciid (n: N): string :=
  let/d s := N2ascii n in
  match s return string with
  | None => ""
  | Some sv => sv
  end.
