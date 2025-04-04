From impboot Require Import utils.Core.
Require Import impboot.functional.FunValues.
Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.

Ltac rewrite_let := match goal with
| [ |- context C [?subterm] ] =>
  match subterm with
  | let x := ?a in @?b x =>
    let C' := context C [b a] in
    change C'
  end
end.

Definition empty_state : state := init_state lnil [].

(* TODO(kπ) figure out a good example, this one gets constant folded *)
(* Example arith_example : forall n m,
  exists prog, Env.empty |- (prog, empty_state) ---> ([Num (let x := 1 in x + n - m)], empty_state).
Proof.
  intros.
  rewrite_let.
  eexists. (* TODO(kπ) this simplifies my function :/ Is this a problem with normal code?*)
  eapply auto_let; eauto; intros.
  repeat match goal with
  | |- context[_ + _] => eapply auto_num_add; eauto
  | |- context[_ - _] => eapply auto_num_sub; eauto
  end.
  (* TODO(kπ) *)
Qed. *)

(*
TODO(kπ) Problems:
- in HOL4 (let x = a in b) is encoded as ((fn x => b) a) Do we have to do the
  same? Add a preprocessing step or sth?
- in the HOL4 version (AFAIK) only limited matches on datatypes are supported,
  but the problem is that matches in HOL4 are represented using `CASE functions`
  e.g.
  list case [ ] f1 f2 = f1
  list case (x :: xs) f1 f2 = f2 x xs
*)
