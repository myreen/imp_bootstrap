From impboot.bootstrapping Require Import CompilerToImpTiming.
From impboot.imperative Require Import Printing.
From Stdlib Require Import String.
From Ltac2 Require Import Ltac2.

Time Compute
  match timed_compiler_program_imp with
  | None => ""%string
  | Some p => imp2str p
  end.
