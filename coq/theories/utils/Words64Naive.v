Require Import Coq.ZArith.BinInt.
Require Import coqutil.Z.Lia.
Require Import coqutil.Word.Naive.
Require Import coqutil.Word.Properties.
Require Import coqutil.Word.Bitwidth.

Local Open Scope Z_scope.

Notation word64 := (word 64).

#[global] Instance word64_instance: word.word 64 := Naive.word 64.
