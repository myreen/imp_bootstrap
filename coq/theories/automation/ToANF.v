From Ltac2 Require Import Ltac2 Constr Std RedFlags.
From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
From coqutil Require Import dlet.
From coqutil Require Import Word.Interface.

Ltac2 rec proper_const_f (c: constr): bool :=
  match Constr.Unsafe.kind c with
  (* | Var _ => true *)
  (* TODO: probably should remove this (next) line – it allows too many undesirable things as consts *)
  | Unsafe.Constant _ _ => true
  | Unsafe.Constructor _ _ => true
  | Unsafe.App c cs => Bool.and (proper_const_f c) (Array.for_all proper_const_f cs)
  | _ => false
  end.
Ltac2 proper_const (c: constr): bool :=
  let evaluated := eval_cbv beta c in
  proper_const_f evaluated.

Ltac2 rec is_allowed (c: constr): bool :=
  match! c with
  | word.of_Z ?c1 => is_allowed c1
  | Z.of_nat ?c1 => is_allowed c1
  | Z.of_N ?c1 => is_allowed c1
  | N.to_nat ?c1 => is_allowed c1
  | N.of_nat ?c1 => is_allowed c1
  | _ => proper_const c
  end.

(* Converts an expression to ANF-like form, such that every function call,
constructor call, operation is let bound and never nested. The allowed top level
expressions are matches, ifs, let bindings, and simple expressions in return
positions. All if conditions can be assumed to be correct. *)
(* e.g.
  f (1 + 2) (g 3)
  ===>
  let a := 1 + 2 in
  let b := g 3 in
  let c := f a b in
  c

  if a <? b then
    h (a + 1)
  else
    h (b + 1)
  ===>
  if a <? b then
    let d := a + 1 in
    let e := h d in
    e
  else
    let d := b + 1 in
    let e := h d in
    e

  let x := f (1 + 2) (g 3) in
  x + 1
  ===>
  let a := 1 + 2 in
  let b := g 3 in
  let c := f a b in
  let d := c + 1 in
  d
*)
Ltac2 rec to_anf (e: constr): constr :=
  match! e with
  | let/d x := ?e1 in ?e2 =>
    let e1_anf := to_anf e1 in
    let e2_anf := to_anf e2 in
    constr:(let/d x := $e1_anf in $e2_anf)
  | if ?cond then ?then_branch else ?else_branch =>
    let cond_anf := to_anf cond in
    let then_anf := to_anf then_branch in
    let else_anf := to_anf else_branch in
    constr:(if $cond_anf then $then_anf else $else_anf)
  | match ?_scrut with _ => _ end =>
    e (* TODO *)
  | ?f ?arg1 ?arg2 =>
    let arg1_anf := to_anf arg1 in
    let arg2_anf := to_anf arg2 in
    let tmp1 := Fresh.in_goal (Option.get (Ident.of_string "anf_tmp")) in
    let tmp1_constr := Unsafe.make (Unsafe.Var tmp1) in
    let tmp2 := Fresh.in_goal (Option.get (Ident.of_string "anf_tmp")) in
    let tmp2_constr := Unsafe.make (Unsafe.Var tmp2) in
    let f_anf := to_anf constr:($f $tmp1_constr $tmp2_constr) in
    constr:(let/d tmp1 := $arg1_anf in
            let/d tmp2 := $arg2_anf in
            let res := $f_anf in
            res)
  | ?f ?arg =>
    let arg_anf := to_anf arg in
    let tmp := Fresh.in_goal (Option.get (Ident.of_string "anf_tmp")) in
    let tmp_constr := Unsafe.make (Unsafe.Var tmp) in
    let f_anf := to_anf constr:($f $tmp_constr) in
    constr:(let tmp := $arg_anf in
            let res := $f_anf in
            res)
  | _ =>
    e
  end.

(* split strings to intermediate lets *)
(* split lists to intermediate lets *)
