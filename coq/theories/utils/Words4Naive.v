Require Import Coq.ZArith.BinInt.
Require Import coqutil.Z.Lia.
Require Import coqutil.Word.Naive.
Require Import coqutil.Word.Properties.
Require Import coqutil.Word.Bitwidth.

Local Open Scope Z_scope.

Definition word4 := word 64.

#[global] Instance word4_instance: word.word 4 := Naive.word 4.

(* TODO(kπ) *)
(* #[global] Instance Words4Naive: Bitwidth 4 := {|
  width_cases := or_intror eq_refl;
|}. *)
