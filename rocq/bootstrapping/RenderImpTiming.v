From impboot.bootstrapping Require Import CompilerToImpTiming.
From impboot.imperative Require Import Printing.
From Stdlib Require Import String.
From Ltac2 Require Import Ltac2.

Ltac2 Eval Message.print
  (Message.of_string "TIMING compiler_stage render_imperative").
Time Definition timed_compiler_imp_string :=
  Eval vm_compute in
    match timed_compiler_program_imp with
    | None => ""%string
    | Some p => imp2str p
    end.
