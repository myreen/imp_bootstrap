Require Import impboot.functional.FunValues.
Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.
Require Import Coq.Bool.Bool.
Require Import Coq.Lists.List.
Import ListNotations.
Require Import Lia Nat Arith.

Definition empty_state : state := init_state lnil [].


(* TODO(kπ) figure out a good example, this one gets constant folded *)
Example arith_example : forall n m,
  exists prog, Env.empty |- (prog, empty_state) ---> ([Num (let x := 1 in x + n - m)], empty_state).
Proof.
  intros.
  eauto with automation.
Qed.
