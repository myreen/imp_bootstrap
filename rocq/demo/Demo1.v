From Stdlib Require Import Utf8 Lia.
From Coq Require Import Extraction.

From Corelib Require Import Byte.

Definition e (x: nat) :=
  let y := 3 in
  x + y.

Lemma e_correct: forall x,
  3 <= e x.
Proof.
  intros; unfold e.
  lia.
Qed.

Compute e 2.

Extraction Language OCaml.
Extraction "e.ml" e.
