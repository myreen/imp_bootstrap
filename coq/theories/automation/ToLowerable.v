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

Ltac2 lower_match_constr (c: constr): unit :=
  try (match! c with
  | context [ N.mul _ _ ] =>
    rewrite <- mul_N_spec
  | context [ Nat.mul _ _ ] =>
    rewrite <- mul_nat_spec
  | context [ append _ _ ] =>
    rewrite <- string_append_spec
  | context [ List.app _ _ ] =>
    rewrite <- list_append_spec
  | context [ List.length _ ] =>
    rewrite <- list_length_spec
  | context [ dlet (String ?c1 (String ?c2 (String ?c3 (String ?c4 (String ?c5 ?str))))) ?f ] =>
    let prfx := constr:(String $c1 (String $c2 (String $c3 (String $c4 EmptyString)))) in
    let sfx := constr:(String $c5 $str) in
    let new_constr := constr:(
      let/d prfx := $prfx in
      let/d sfx := $sfx in
      dlet (append prfx sfx) $f
    ) in
    (* TODO: should use change (change old with new), but it doesn't sometimes work *)
    (* ltac1:(old new |- assert (old = new) as -> by reflexivity) (Ltac1.of_constr c) (Ltac1.of_constr new_constr) *)
    ltac1:(old new |- change old with new) (Ltac1.of_constr c) (Ltac1.of_constr new_constr)
  | context [ dlet (?x1 :: ?x2 :: ?x3 :: ?x4 :: ?x5 :: ?rst) ?f ] =>
    let prfx := constr:([$x1; $x2; $x3; $x4]) in
    let sfx := constr:($x5 :: $rst) in
    let new_constr := constr:(
      let/d prfx := $prfx in
      let/d sfx := $sfx in
      dlet (List.app prfx sfx) $f
    ) in
    ltac1:(old new |- assert (old = new) as -> by reflexivity) (Ltac1.of_constr c) (Ltac1.of_constr new_constr)
  end).

Ltac2 rewrite_lowerable () :=
  repeat (match! goal with
  | [|- _ |-- (_, _) ---> ([encode ?c], _) ] =>
    lower_match_constr c
  end).

(* test *)

Ltac2 rewrite_lowerable_test () :=
  repeat (match! goal with
  | [|- ?c = _ ] =>
    lower_match_constr c
  end).

Definition test1 (a b: N): N :=
  a * b + N.mul b a.

Goal forall (a b: N), test1 a b = test1 a b.
  intros; unfold test1.
  rewrite_lowerable_test ().
  reflexivity ().
Qed.

Definition test2 (a b: N): N :=
  let/d d_div_a := N.mul b a in
  (a * b + d_div_a)%N.

Goal forall (a b: N), test2 a b = test2 a b.
  intros; unfold test2.
  rewrite_lowerable_test ().
  reflexivity ().
Qed.

Definition test_split_string (s1 s2: string): string :=
  let/d s := "abcdefg"%string in
  append s s2.

Goal forall (s1 s2: string), test_split_string s1 s2 = test_split_string s1 s2.
  intros; unfold test_split_string.
  rewrite_lowerable_test ().
  reflexivity ().
Qed.

Goal forall (reg2str1: string -> string -> string) r n str, (let/d anf_tmp := "movq "%string
in let/d anf_tmp0 := mul_nat 8 n
in let/d anf_tmp1 := "(%rsp), "%string
in let/d anf_tmp2 := reg2str1 r str
in let/d anf_tmp3 := (anf_tmp1 ++ anf_tmp2)%string
in let/d anf_tmp4 := num2str anf_tmp0 anf_tmp3
in let/d anf_tmp5 := (anf_tmp ++ anf_tmp4)%string in anf_tmp5) = ""%string.
  intros.
  rewrite_lowerable_test ().
Admitted.

Definition test_split_list (l1 l2: list nat): list nat :=
  let/d l := [1;2;3;4;5;6;7] in
  l ++ l2.

Goal forall (l1 l2: list nat), test_split_list l1 l2 = test_split_list l1 l2.
  intros; unfold test_split_list.
  rewrite_lowerable_test ().
  reflexivity ().
Qed.
