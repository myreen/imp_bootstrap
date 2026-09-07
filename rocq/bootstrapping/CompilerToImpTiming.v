From impboot.derivations Require Import CompilerDerivations.
From impboot.fp2imp Require Import FpToImpCodegen.
From Ltac2 Require Import Ltac2.

Ltac2 Eval Message.print
  (Message.of_string "TIMING compiler_stage functional_to_imperative").
Time Definition timed_compiler_program_imp :=
  Eval vm_compute in to_imp compiler_program_prog.
