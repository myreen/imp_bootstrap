Require Import impboot.utils.Core.
Require Import impboot.parsing.Parser.
Require Import Patat.Patat.

Ltac cleanup :=
  repeat match goal with
  | H: _ /\ _ |- _ => destruct H; clear H
  | H: (_, _) = (_, _) |- _ => inversion H; clear H; subst
  end.

Theorem read_num_length: ∀l h xs n ys f acc x,
  read_num l h f x acc xs = (n, ys) ->
    List.length ys ≤ List.length xs ∧ (xs ≠ ys -> List.length ys < List.length xs)%nat.
Proof.
  induction xs; intros; simpl in *; unfold dlet in *; cleanup; simpl.
  1: split; eauto; intros; congruence.
  destruct andb eqn:?; rewrite ?andb_true_iff, ?andb_false_iff, ?N.leb_le, ?N.leb_gt in *; cleanup; simpl in *.
  1: {
    pat `read_num _ _ _ _ _ _ = _` at rename pat into Hread_num.
    pat `forall n ys f acc x, _` at eapply pat in Hread_num.
    split; [lia|].
    intros; lia.
  }
  split; [lia|].
  intros; congruence.
Qed.

Theorem end_line_length: ∀cs,
  (List.length (end_line cs) <= List.length cs)%nat.
Proof.
  induction cs; simpl; unfold dlet in *; [lia|].
  destruct (_ =? _)%char eqn:?; lia.
Qed.

Theorem lex_terminates: forall fuel q cs acc,
  (List.length cs <= fuel)%nat -> lex q cs acc fuel <> None.
Proof.
  Opaque Ascii.eqb.
  induction fuel; intros; simpl; unfold dlet in *.
  1: inversion H; simpl; destruct cs eqn:?; simpl in *; try congruence.
  destruct cs eqn:?; try congruence; simpl in *.
  repeat match goal with
  | |- (if ?c then _ else _) <> _ => destruct c eqn:?
  | |- lex _ _ _ _ <> _ =>
    eapply IHfuel
  | |- (let (_, _) := if ?c then _ else _ in _) <> _ =>
    destruct c eqn:?
  | |- (let (_, _) := read_num _ _ _ _ _ cs in _) <> _ =>
    destruct read_num eqn:?
  | H: _ = _ :: ?l |- (let (_, _) := read_num ?a1 ?a2 ?a3 ?a4 ?a5 ?l in _) <> _ =>
    destruct (read_num a1 a2 a3 a4 a5 l) eqn:?
  | |- (List.length (end_line _) <= _)%nat =>
    eapply Nat.le_trans; [eapply end_line_length|]; lia
  | H: (S _ <= S _)%nat |- _ =>
    eapply le_S_n in H
  | H: cs = ?h :: ?t |- (List.length (?h :: ?t) <= _)%nat =>
    rewrite negb_true_iff, Nat.eqb_neq in *; simpl in *; congruence
  | H: read_num _ _ _ _ _ ?t = (_, _) |- _ =>
    eapply read_num_length in H
  | _ =>
    progress unfold dlet in *
  | _ => lia
  end.
Qed.

Theorem lexer_terminates: forall (inp: string),
  lexer_i inp <> None.
Proof.
  intros; unfold lexer_i, dlet.
  eapply lex_terminates.
  eapply Nat.le_refl.
Qed.
