From Stdlib Require Import Logic.FunctionalExtensionality.
From impboot Require Import utils.Core.

Module Type EnvT.
  Parameter env : Type.
  Parameter empty : env.
  Parameter name : Type.
  Parameter Value : Type.
  Parameter lookup : env -> name -> option Value.
  Parameter insert : name * option Value -> env -> env.
  Parameter insert_all : list (name * option Value) -> env -> env.
  Definition insert_some (p : name * Value) (v : env) : env :=
    insert (fst p, Some (snd p)) v.
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
End EnvT.

Require impboot.functional.FunSyntax.
Require impboot.functional.FunValues.

Module FEnv <: EnvT.
  Definition name := FunSyntax.name.
  Definition Value := FunValues.Value.
  Definition eqb := Nat.eqb.
  Definition env := name -> option Value.
  Definition empty : env := fun _ => None.
  Definition lookup (v : env) (x : name) : option Value := v x.
  Definition insert (p : name * option Value) (v : env) : env :=
    fun x => if N.eq_dec x (fst p) then (snd p) else v x.
  Fixpoint insert_all (ps: list (name * option Value)) (v: env) :=
    match ps with
    | nil => v
    | p :: ps => insert p (insert_all ps v)
    end.
  Definition insert_some (p : name * Value) (v : env) : env :=
    insert (fst p, Some (snd p)) v.
  Definition remove (x : name) (v : env) : env :=
    fun y => if N.eq_dec x y then None else v y.

  Theorem lookup_insert_eq : forall v x n,
      lookup (insert (x, n) v) x = n.
  Proof.
    intros; unfold lookup, insert, fst. destruct N.eq_dec; try reflexivity; congruence.
  Qed.

  Theorem lookup_insert_neq : forall v x1 x2 n,
      x1 <> x2 ->
      lookup (insert (x1, n) v) x2 = lookup v x2.
  Proof.
    intros; unfold lookup, insert, fst.
    destruct N.eq_dec; try reflexivity.
    congruence.
  Qed.

  Theorem insert_insert_eq : forall v x n1 n2,
      insert (x, n1) (insert (x, n2) v) = insert (x, n1) v.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert; destruct N.eq_dec; reflexivity.
  Qed.

  Theorem insert_insert_neq : forall v x1 x2 n1 n2,
      x1 <> x2 ->
      insert (x1, n1) (insert (x2, n2) v) = insert (x2, n2) (insert (x1, n1) v).
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert; destruct N.eq_dec eqn:?; try reflexivity.
    unfold snd, fst in *.
    destruct (N.eq_dec x x2) eqn:?; try reflexivity.
    subst; congruence.
  Qed.

  Theorem insert_remove : forall v x n,
      insert (x, n) (remove x v) = insert (x, n) v.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, remove, fst; destruct N.eq_dec eqn:?; [reflexivity|].
    destruct (N.eq_dec x x0) eqn:?; [|reflexivity].
    subst; congruence.
  Qed.

  Theorem lookup_empty : forall x,
      lookup empty x = None.
  Proof. reflexivity. Qed.

  Theorem insert_lookup_self : forall n env,
    insert (n, lookup env n) env = env.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, lookup, fst; destruct N.eq_dec eqn:?; [|reflexivity].
    unfold snd; subst.
    reflexivity.
  Qed.
End FEnv.

Require impboot.imperative.ImpSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.

Module IEnv <: EnvT.
  Definition name := ImpSyntax.name.
  Definition Value := ImpSyntax.Value.
  Definition env := name -> option Value.
  Definition empty : env := fun _ => None.
  Definition lookup (v : env) (x : name) : option Value := v x.
  Definition insert (p : name * option Value) (v : env) : env :=
    fun x => if N.eq_dec x (fst p) then (snd p) else v x.
  Fixpoint insert_all (ps: list (name * option Value)) (v: env) :=
    match ps with
    | nil => v
    | p :: ps => insert p (insert_all ps v)
    end.
  Definition insert_some (p : name * Value) (v : env) : env :=
    insert (fst p, Some (snd p)) v.
  Definition remove (x : name) (v : env) : env :=
    fun y => if N.eq_dec x y then None else v y.

  Theorem lookup_insert_eq : forall v x n,
      lookup (insert (x, n) v) x = n.
  Proof.
    intros; unfold lookup, insert, fst. destruct N.eq_dec; try reflexivity; congruence.
  Qed.

  Theorem lookup_insert_neq : forall v x1 x2 n,
      x1 <> x2 ->
      lookup (insert (x1, n) v) x2 = lookup v x2.
  Proof.
    intros; unfold lookup, insert, fst.
    destruct N.eq_dec; try reflexivity.
    congruence.
  Qed.

  Theorem insert_insert_eq : forall v x n1 n2,
      insert (x, n1) (insert (x, n2) v) = insert (x, n1) v.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert; destruct N.eq_dec; reflexivity.
  Qed.

  Theorem insert_insert_neq : forall v x1 x2 n1 n2,
      x1 <> x2 ->
      insert (x1, n1) (insert (x2, n2) v) = insert (x2, n2) (insert (x1, n1) v).
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert; destruct N.eq_dec eqn:?; try reflexivity.
    unfold snd, fst in *.
    destruct (N.eq_dec x x2) eqn:?; try reflexivity.
    subst; congruence.
  Qed.

  Theorem insert_remove : forall v x n,
      insert (x, n) (remove x v) = insert (x, n) v.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, remove, fst; destruct N.eq_dec eqn:?; [reflexivity|].
    destruct (N.eq_dec x x0) eqn:?; [|reflexivity].
    subst; congruence.
  Qed.

  Theorem lookup_empty : forall x,
      lookup empty x = None.
  Proof. reflexivity. Qed.

  Theorem insert_lookup_self : forall n env,
    insert (n, lookup env n) env = env.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, lookup, fst; destruct N.eq_dec eqn:?; [|reflexivity].
    unfold snd; subst.
    reflexivity.
  Qed.
End IEnv.

(* Module MemEnv <: EnvT.
  Definition name := @word.rep 64 word64.
  Definition Value := @word.rep 64 word64.
  Definition env := name -> option Value.
  Definition empty : env := fun _ => None.
  Definition lookup (v : env) (x : name) : option Value := v x.
  Definition insert (p : name * option Value) (v : env) : env :=
    fun x => if word.eqb x (fst p) then (snd p) else v x.
  Definition insert_some (p : name * Value) (v : env) : env :=
    insert (fst p, Some (snd p)) v.
  Definition remove (x : name) (v : env) : env :=
    fun y => if word.eqb x y then None else v y.

  Theorem lookup_insert_eq : forall v x n,
      lookup (insert (x, n) v) x = n.
  Proof.
    intros; unfold lookup, insert, fst.
    rewrite word.unsigned_eqb.
    destruct Z.eqb eqn:?; try reflexivity.
    rewrite Z.eqb_refl in Heqb.
    inversion Heqb.
  Qed.

  Theorem lookup_insert_neq : forall v x1 x2 n,
      x1 <> x2 ->
      lookup (insert (x1, n) v) x2 = lookup v x2.
  Proof.
    intros; unfold lookup, insert, fst.
    destruct (word.eqb x2 x1) eqn:?; try reflexivity.
    unfold snd.
    apply word.eqb_true in Heqb.
    congruence.
  Qed.

  Theorem insert_insert_eq : forall v x n1 n2,
      insert (x, n1) (insert (x, n2) v) = insert (x, n1) v.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, fst, snd.
    destruct (word.eqb x0 x) eqn:?; try reflexivity.
  Qed.

  Theorem insert_insert_neq : forall v x1 x2 n1 n2,
      x1 <> x2 ->
      insert (x1, n1) (insert (x2, n2) v) = insert (x2, n2) (insert (x1, n1) v).
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, fst, snd; destruct (word.eqb x x1) eqn:?; try reflexivity.
    destruct (word.eqb x x2) eqn:?; try reflexivity.
    apply word.eqb_true in Heqb.
    apply word.eqb_true in Heqb0.
    subst; congruence.
  Qed.

  Theorem insert_remove : forall v x n,
      insert (x, n) (remove x v) = insert (x, n) v.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, remove, fst, snd.
    destruct (word.eqb x0 x) eqn:?; try reflexivity.
    destruct (word.eqb x x0) eqn:?; try reflexivity.
    apply word.eqb_true in Heqb0.
    apply word.eqb_false in Heqb.
    subst; congruence.
  Qed.

  Theorem lookup_empty : forall x,
      lookup empty x = None.
  Proof. reflexivity. Qed.

  Theorem insert_lookup_self : forall n env,
    insert (n, lookup env n) env = env.
  Proof.
    intros; apply functional_extensionality; intros.
    unfold insert, lookup, fst, snd.
    destruct (word.eqb x n) eqn:?; try reflexivity.
    apply word.eqb_true in Heqb.
    subst; reflexivity.
  Qed.
End MemEnv. *)