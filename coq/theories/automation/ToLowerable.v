From Ltac2 Require Import Ltac2 Constr Std RedFlags Printf.
From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
From coqutil Require Import dlet.
From coqutil Require Import Word.Interface.
From impboot Require Import commons.CompilerUtils.
From impboot.functional Require Import FunSemantics FunValues.

Open Scope list_scope.
Open Scope nat.

Lemma dlet_spec: forall {A B: Type} (a: A) (f: A -> B),
  let/d x := a in f x = let x := a in f x.
Proof.
  intros; reflexivity ().
Qed.

Ltac2 rewrite_lowerable (): unit :=
  repeat (match! goal with
  | [ |- context [ N.mul _ _ ] ] =>
    rewrite <- mul_N_spec
  | [ |- context [ Nat.mul _ _ ] ] =>
    rewrite <- mul_nat_spec
  | [ |- context [ (_ ++ _)%string ] ] =>
    rewrite <- string_append_spec
  | [ |- context [ (_ ++ _)%list ] ] =>
    rewrite <- list_append_spec
  | [ |- context [ List.length _ ] ] =>
    rewrite <- list_length_spec
  | [ |- context c [ dlet (String ?c1 (String ?c2 (String ?c3 (String ?c4 (String ?c5 ?str))))) ?f ] ] =>
    let new_constr := constr:(
      let/d sfx := String $c5 $str in
      dlet (String $c1 (String $c2 (String $c3 (String $c4 sfx)))) $f
    ) in
    let inst := Pattern.instantiate c new_constr in
    change $inst
  | [ |- context c [ dlet (?x1 :: ?x2 :: ?x3 :: ?x4 :: ?x5 :: ?rst) ?f ] ] =>
    let new_constr := constr:(
      let/d sfx := $x5 :: $rst in
      dlet ($x1 :: $x2 :: $x3 :: $x4 :: sfx) $f
    ) in
    let inst := Pattern.instantiate c new_constr in
    change $inst
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

Goal forall (reg2str1: string -> string -> string) r n str, (let/d anf_tmp := "movq "%string
in let/d anf_tmp0 := (8 * n)%nat
in let/d anf_tmp1 := "(%rsp), "%string
in let/d anf_tmp2 := reg2str1 r str
in let/d anf_tmp3 := (anf_tmp1 ++ anf_tmp2)%string
in let/d anf_tmp4 := num2str anf_tmp0 anf_tmp3 in let/d anf_tmp5 := (anf_tmp ++ anf_tmp4)%string in anf_tmp5) = ""%string.
  intros.
  rewrite_lowerable ().
Admitted.

Definition test_split_list (l1 l2: list nat): list nat :=
  let/d l := [1;2;3;4;5;6;7] in
  l ++ l2.

Goal forall (l1 l2: list nat), test_split_list l1 l2 = test_split_list l1 l2.
  intros; unfold test_split_list.
  rewrite_lowerable ().
  reflexivity ().
Qed.

Goal forall {A} l1 l2 l3 l4 l5 l6 l7 (f: nat -> Z -> list A) a,
  (let/d l := [l1; l2; l3; l4; l5; l6; l7]%string in l ++ f 0 a) = [].
  intros.
  rewrite_lowerable ().
Admitted.
