From impboot.utils Require Import Core AppList Words4Naive.
From coqutil.Word Require Import Interface Properties.
From impboot.commons Require Import ProofUtils.
From impboot.automation.ltac2 Require Import UnfoldFix.

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

Lemma num2strf_oblig: forall (n: nat) (a: nat),
  a = n / 10 ->
  ~ (n < 10) -> (a < n).
Proof.
  intros; subst; apply Nat.div_lt; lia.
Qed.

Fixpoint num2strf (n: nat) (ACC: Acc Nat.lt n) (str: string): string :=
  match lt_dec n 10 with
  | left _ =>
    let/d nd := nat_mod n 10 in
    let/d a:= ascii_of_nat (48 + nd) in
    String a str
  | right NLT =>
    let/d nd := nat_mod n 10 in
    let/d a := ascii_of_nat (48 + nd) in
    let/t nrest := n / 10 in
    num2strf nrest (Acc_inv ACC (num2strf_oblig n nrest ltac:(abstract eauto) NLT)) (String a str)
  end.

Fixpoint unfold_Acc_n {A R} (len: nat) (n: A) (opaque_acc: Acc R n): Acc R n :=
  match len with
  | 0%nat => Acc_intro n (fun m mlt => Acc_inv opaque_acc m mlt)
  | S len =>
    Acc_intro n (fun m mlt =>
      unfold_Acc_n len m (Acc_inv opaque_acc m mlt))
  end.

Definition log10 (n: nat): nat :=
  match n with
  | 0 => 0%nat
  | _ => S (Nat.log2 n / 3)
  end.

Definition num2str (n: nat) (str: string): string :=
  num2strf n (unfold_Acc_n (log10 n) _ (lt_wf n)) str.

Lemma N2strf_oblig: forall (n: N) (a: N),
  a = (n / 10)%N ->
  ~ (n < 10)%N -> (a < n)%N.
Proof.
  intros; subst; apply N.div_lt; lia.
Qed.

Lemma N_lt_dec : forall (n m: N), {(n < m)%N} + {~ (n < m)%N}.
Proof.
  intros; destruct (N.compare n m) eqn:Heqe.
  - right; congruence.
  - left; congruence.
  - right; congruence.
Defined.

Fixpoint N2str_f (n: N) (ACC: Acc N.lt n) (str: string): string :=
  match N_lt_dec n 10 with
  | left _ =>
    let/d nd := Nmod_10 n in
    let/d a:= ascii_of_N (48 + nd)%N in
    String a str
  | right NLT =>
    let/d nd := Nmod_10 n in
    let/d a := ascii_of_N (48 + nd)%N in
    let/t nrest := (n / 10)%N in
    N2str_f nrest (Acc_inv ACC (N2strf_oblig n nrest ltac:(abstract eauto) NLT)) (String a str)
  end.

Definition Nlog10 (n: N): nat :=
  match n with
  | 0%N => 0%nat
  | _ => S (N.to_nat (N.log2 n / 3))
  end.

Definition N2str (n: N) (str: string): string :=
  N2str_f n (unfold_Acc_n (Nlog10 n) _ (N.lt_wf_0 n)) str.

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

Lemma N2asciif_oblig: forall (n: N) (a: N),
  a = (n / 256)%N ->
  ~ (n < 256)%N -> (a < n)%N.
Proof.
  intros; subst; apply N.div_lt; lia.
Qed.

Fixpoint N2asciif (n: N) (ACC: Acc N.lt n): string :=
  if (n =? 0)%N then EmptyString else
  let/d k := N_modulo n 256 in
  if (k <? N_of_ascii "*"%char)%N then EmptyString else
  if (N_of_ascii "z"%char <? k)%N then EmptyString else
  if (k =? N_of_ascii "."%char)%N then EmptyString else
  if (n <? 256)%N then (String (ascii_of_N k) EmptyString) else
  match N_lt_dec n 256 with
  | left _ => String (ascii_of_N k) EmptyString
  | right NLT =>
    let/t nrest := (n / 256)%N in
    let/d r := N2asciif nrest (Acc_inv ACC (N2asciif_oblig n nrest ltac:(abstract eauto) NLT)) in
    (r ++ String (ascii_of_N k) EmptyString)
  end.

Definition Nlog256 (n: N): nat :=
  match n with
  | 0%N => 0%nat
  | _ => S (N.to_nat (N.log2 n / 8))
  end.

Definition N2ascii (n: N): string :=
  N2asciif n (unfold_Acc_n (Nlog256 n) _ (N.lt_wf_0 n)).
