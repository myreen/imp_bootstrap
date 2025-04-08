Require Import Coq.Logic.FunctionalExtensionality.
From impboot Require Import utils.Core.
Require Import impboot.functional.FunValues.

Module Type FunEnvT.
  Parameter env : Type.
  Parameter empty : env.
  Parameter lookup : env -> name -> option Value.
  Parameter insert_some : name * Value -> env -> env.
  Parameter insert : name * option Value -> env -> env.
  Parameter remove : name -> env -> env.

  Axiom lookup_insert_eq : forall v x n,
      lookup (insert (x, n) v) x = n.

  Axiom lookup_insert_neq : forall v x1 x2 n,
      x1 <> x2 ->
      lookup (insert (x1, n) v) x2 = lookup v x2.

  Axiom insert_insert_eq : forall v x n1 n2,
      insert (x, n1) (insert (x, n2) v) = insert (x, n1) v.

  Axiom insert_insert_neq : forall v x1 x2 n1 n2,
      x1 <> x2 ->
      insert (x1, n1) (insert (x2, n2) v) = insert (x2, n2) (insert (x1, n1) v).

  Axiom insert_remove : forall v x n,
      insert (x, n) (remove x v) = insert (x, n) v.

  Axiom lookup_empty : forall x,
      lookup empty x = None.

  Axiom insert_lookup_self : forall n env,
    insert (n, lookup env n) env = env.

End FunEnvT.

Module FunEnv : FunEnvT.
  Definition env := name -> option Value.
  Definition empty : env := fun _ => None.
  Definition lookup (v : env) (x : name) : option Value := v x.
  Definition insert_some (p : name * Value) (v : env) : env :=
    fun x => if x =? fst p then Some (snd p) else v x.
  Definition insert (p : name * option Value) (v : env) : env :=
    fun x => if x =? fst p then (snd p) else v x.
  Definition remove (x : name) (v : env) : env :=
    fun y => if x =? y then None else v y.

  Theorem lookup_insert_eq : forall v x n,
      lookup (insert (x, n) v) x = n.
  Proof.
    intros; unfold lookup, insert, fst; rewrite Nat.eqb_refl; reflexivity.
  Qed.

  Theorem lookup_insert_neq : forall v x1 x2 n,
      x1 <> x2 ->
      lookup (insert (x1, n) v) x2 = lookup v x2.
  Proof.
    intros; unfold lookup, insert, fst.
    rewrite <- Nat.eqb_neq in H; rewrite Nat.eqb_sym in H; rewrite H.
    reflexivity.
  Qed.

  Theorem insert_insert_eq : forall v x n1 n2,
      insert (x, n1) (insert (x, n2) v) = insert (x, n1) v.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert; destruct (_ =? _); reflexivity.
  Qed.

  Theorem insert_insert_neq : forall v x1 x2 n1 n2,
      x1 <> x2 ->
      insert (x1, n1) (insert (x2, n2) v) = insert (x2, n2) (insert (x1, n1) v).
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert; destruct (_ =? _) eqn:?; destruct (x =? fst (x2, n2)) eqn:?; try reflexivity.
    rewrite Nat.eqb_eq in *; unfold fst in *; subst.
    contradiction.
  Qed.

  Theorem insert_remove : forall v x n,
      insert (x, n) (remove x v) = insert (x, n) v.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, remove, fst; destruct (_ =? _) eqn:?; [reflexivity|].
    rewrite Nat.eqb_sym in Heqb; rewrite Heqb; reflexivity.
  Qed.

  Theorem lookup_empty : forall x,
      lookup empty x = None.
  Proof. reflexivity. Qed.

  Theorem insert_lookup_self : forall n env,
    insert (n, lookup env n) env = env.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, lookup, fst; destruct (_ =? _) eqn:?; [|reflexivity].
    unfold snd; rewrite Nat.eqb_eq in Heqb; unfold fst in Heqb; subst.
    reflexivity.
  Qed.
End FunEnv.
