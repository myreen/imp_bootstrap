Require Import impboot.utils.Core.

Inductive token :=
  | OPEN
  | CLOSE
  | DOT
  | NUM (n: N)
  | QUOTE (s: N).
