Require Import Coq.ZArith.BinInt.
Require Import coqutil.Z.Lia.
Require Import coqutil.Word.Naive.
Require Import coqutil.Word.Properties.
Require Import coqutil.Word.Bitwidth.

Local Open Scope Z_scope.

#[global] Instance word4_instance: word.word 4 := Naive.word 4.

Definition word width: word.word width :=
  gen_word width (default_special_case_handlers width).
Definition ok width: 0 < width -> word.ok (word width) :=
  gen_ok width (default_special_case_handlers width).

Notation word4 := (word 4).
#[global] Instance word4_ok : word.ok word4 := ok 4 eq_refl.
Add Ring wring8 : (Properties.word.ring_theory (word := word4))
      (preprocess [autorewrite with rew_word_morphism],
       morphism (Properties.word.ring_morph (word := word4)),
       constants [Properties.word_cst]).
