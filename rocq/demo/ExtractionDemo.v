From Stdlib Require Import Utf8 Lia.
From Coq Require Import Extraction.

Definition e (y: nat): nat :=
  let x := 5 in
  x + y.

Theorem e_correct: forall y, 5 ≤ e y.
Proof.
  intros; unfold e; lia.
Qed.

Compute e 3.

Extraction Language OCaml.
Extraction "e.ml" e.
