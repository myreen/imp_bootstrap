From Ltac2 Require Import Ltac2 Constr Std RedFlags.
From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
From coqutil Require Import dlet.
From coqutil Require Import Word.Interface.
From impboot Require Import
  commons.CompilerUtils
  automation.ToANF.

(* rewrite every N.mul to mul_N call and every Nat.mul to nat_mul call *)

Lemma dlet_spec: forall {A B: Type} (a: A) (f: A -> B),
  let/d x := a in f x = let x := a in f x.
Proof.
  intros; reflexivity ().
Qed.

Lemma split_string: forall {A} (c1 c2 c3 c4 c5: ascii) (s: string) (k: string -> A),
  (let/d str1 := String c1 (String c2 (String c3 (String c4 (String c5 s)))) in k str1) =
  let/d str_front := String c1 (String c2 (String c3 (String c4 EmptyString))) in
  let/d str_rest := String c5 s in
  let/d str1 := append str_front str_rest in
  k str1.
Proof.
  intros; reflexivity ().
Qed.

Lemma split_list: forall {A B} (e1 e2 e3 e4 e5: A) (l: list A) (k: list A -> B),
  (let/d l1 := e1 :: e2 :: e3 :: e4 :: e5 :: l in k l1) =
  let/d l_front := e1 :: e2 :: e3 :: e4 :: [] in
  let/d l_rest := e5 :: l in
  let/d l1 := l_front ++ l_rest in
  k l1.
Proof.
  intros; reflexivity ().
Qed.

Ltac2 rewrite_lowerable () :=
  repeat (match! goal with
  | [ |- context [ N.mul _ _ ] ] =>
    rewrite <- mul_N_spec
  | [ |- context [ Nat.mul _ _ ] ] =>
    rewrite <- mul_nat_spec
  | [ |- context [ append _ _ ] ] =>
    rewrite <- string_append_spec
  | [ |- context [ List.app _ _ ] ] =>
    rewrite <- list_append_spec
  | [ |- context [ List.length _ ] ] =>
    rewrite <- list_length_spec
  | [ |- context [
    let/d x := (String _ (String _ (String _ (String _ (String _ _))))) in _ ] ] =>
    rewrite split_string
  | [ |- context [
    let/d x := (_ :: _ :: _ :: _ :: _ :: _) in _ ] ] =>
    rewrite split_list
  end).

(* test *)

Definition test1 (a b: N): N :=
  a * b + N.mul b a.

Goal forall (a b: N), test1 a b = test1 a b.
  intros; unfold test1.
  rewrite_lowerable ().
  reflexivity ().
Qed.

Definition test2 (a b: N): N :=
  let/d d_div_a := N.mul b a in
  (a * b + d_div_a)%N.

Goal forall (a b: N), test2 a b = test2 a b.
  intros; unfold test2.
  rewrite_lowerable ().
  reflexivity ().
Qed.

Definition test_split_string (s1 s2: string): string :=
  let/d s := "abcdefg"%string in
  append s s2.

Goal forall (s1 s2: string), test_split_string s1 s2 = test_split_string s1 s2.
  intros; unfold test_split_string.
  rewrite_lowerable ().
  reflexivity ().
Qed.

Definition test_split_list (l1 l2: list nat): list nat :=
  let/d l := [1;2;3;4;5;6;7] in
  l ++ l2.

Goal forall (l1 l2: list nat), test_split_list l1 l2 = test_split_list l1 l2.
  intros; unfold test_split_list.
  rewrite_lowerable ().
  reflexivity ().
Qed.
