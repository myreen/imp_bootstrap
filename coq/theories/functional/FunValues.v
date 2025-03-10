Module FunValues.

Inductive Value :=
  | Pair (v1 v2 : Value)
  | Num (n : nat).

End FunValues.
