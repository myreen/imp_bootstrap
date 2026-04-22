From impboot.utils Require Import Core.

Inductive token :=
  | OPEN
  | CLOSE
  | DOT
  | NUM (n: N)
  | QUOTE (s: N).
