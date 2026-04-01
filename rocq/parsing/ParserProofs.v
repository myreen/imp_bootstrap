Require Import impboot.utils.Core.
Require Import impboot.parsing.Parser.
Require Import impboot.imp2asm.ImpToASMCodegenProofs.
Require Import impboot.commons.CompilerUtils.
Require Import Patat.Patat.

Ltac cleanup :=
  repeat match goal with
  | H: _ /\ _ |- _ => destruct H; clear H
  | H: (_, _) = (_, _) |- _ => inversion H; clear H; subst
  end.

Theorem read_nmc_length: ∀ xs n ys acc l l1,
  read_nmc acc xs l = (n, ys, l1) ->
    List.length ys ≤ List.length xs ∧ (xs ≠ ys -> List.length ys < List.length xs)%nat.
Proof.
  induction xs; intros; simpl in *; unfold dlet in *; cleanup; simpl.
  1: split; eauto; intros; congruence.
  destruct (_ <? _)%N eqn:?; simpl in *; cleanup; simpl in *.
  1: split; [lia|]; intros; congruence.
  destruct (_ <? N_of_ascii _)%N eqn:?; simpl in *; cleanup; simpl in *.
  1: split; [lia|]; intros; congruence.
  pat `read_nmc _ _ _ = _` at rename pat into Hread_num.
  pat `forall n ys acc, _` at eapply pat in Hread_num.
  split; [lia|].
  intros; lia.
Qed.

Theorem read_alp_length: ∀ xs n ys acc l l1,
  read_alp acc xs l = (n, ys, l1) ->
    List.length ys ≤ List.length xs ∧ (xs ≠ ys -> List.length ys < List.length xs)%nat.
Proof.
  induction xs; intros; simpl in *; unfold dlet in *; cleanup; simpl.
  1: split; eauto; intros; congruence.
  destruct (_ <? _)%N eqn:?; simpl in *; cleanup; simpl in *.
  1: split; [lia|]; intros; congruence.
  destruct (_ <? N_of_ascii _)%N eqn:?; simpl in *; cleanup; simpl in *.
  1: split; [lia|]; intros; congruence.
  pat `read_alp _ _ _ = _` at rename pat into Hread_num.
  pat `forall n ys acc, _` at eapply pat in Hread_num.
  split; [lia|].
  intros; lia.
Qed.

Theorem end_line_length: ∀cs l,
  (List.length (fst (end_line cs l)) <= List.length cs)%nat.
Proof.
  induction cs; simpl; unfold dlet in *; [lia|]; intros.
  destruct (_ =? _)%char eqn:?; simpl; try lia.
  specialize IHcs with (l := l + 1) as Hlen; simpl in *; lia.
Qed.

Theorem lex_terminates: forall fuel q cs acc l,
  (List.length cs <= fuel)%nat -> lex q cs l acc fuel <> None.
Proof.
  Opaque Ascii.eqb.
  induction fuel; intros; simpl; unfold dlet in *.
  1: inversion H; simpl; destruct cs eqn:?; simpl in *; try congruence.
  destruct cs eqn:?; try congruence; simpl in *.
  repeat match goal with
  | |- (if ?c then _ else _) <> _ => destruct c eqn:?
  | |- lex _ _ _ _ _ <> _ =>
    eapply IHfuel
  | |- (let (_, _) := if ?c then _ else _ in _) <> _ =>
    destruct c eqn:?
  | |- (let (_, _) := read_nmc _ cs _ in _) <> _ =>
    destruct read_nmc eqn:?
  | |- (let (_, _) := read_alp _ cs _ in _) <> _ =>
    destruct read_alp eqn:?
  | H: _ = _ :: ?l |- (let (_, _) := read_nmc ?a1 ?l ?len in _) <> _ =>
    destruct (read_nmc a1 l len) eqn:?
  | H: _ = _ :: ?l |- (let (_, _) := read_alp ?a1 ?l ?len in _) <> _ =>
    destruct (read_alp a1 l len) eqn:?
  | |- (List.length (fst (end_line _ _)) <= _)%nat =>
    eapply Nat.le_trans; [eapply end_line_length|]; lia
  | H: (S _ <= S _)%nat |- _ =>
    eapply le_S_n in H
  | H: cs = ?h :: ?t |- (List.length (?h :: ?t) <= _)%nat =>
    rewrite negb_true_iff, Nat.eqb_neq in *; simpl in *; congruence
  | H: read_nmc _ ?t _ = (_, _, _) |- _ =>
    eapply read_nmc_length in H
  | H: read_alp _ ?t _ = (_, _, _) |- _ =>
    eapply read_alp_length in H
  | H: context C [CompilerUtils.list_len _] |- _ =>
    rewrite list_len_spec in H; simpl in H
  | H: (_ =? _)%nat = false |- _ =>
    rewrite Nat.eqb_neq in H
  | |- context [ let (_, _) := ?p in _ ] =>
    destruct p eqn:?; subst
  | H: (if ?c then _ else _) = _ |- _ =>
    destruct c eqn:?
  | _ =>
    progress unfold dlet in *
  | H: (_, _, _) = (_, _, _) |- _ => inversion H; clear H; subst
  | H: (_ =? _)%N = _ |- _ => rewrite ?N.eqb_eq, ?N.eqb_neq in *
  | |- List.length (_ :: _) <= _ => progress simpl in *
  | _ => rewrite Nat.add_0_r in *
  | _ => lia
  end.
Qed.

Theorem lexer_terminates: forall (inp: string),
  lexer_i (list_ascii_of_string inp) <> None.
Proof.
  intros; unfold lexer_i, dlet.
  eapply lex_terminates.
  rewrite list_len_spec; simpl.
  eapply Nat.le_refl.
Qed.
