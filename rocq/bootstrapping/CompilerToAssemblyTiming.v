From impboot.bootstrapping Require Import CompilerToImpTiming.
From impboot.imp2asm Require Import ImpToASMCodegen.
From Stdlib Require Import List.
From Ltac2 Require Import Ltac2.

Import ListNotations.

Ltac2 Eval Message.print
  (Message.of_string "TIMING compiler_stage imperative_to_assembly").
Time Definition timed_compiler_program_asm :=
  Eval vm_compute in
    match timed_compiler_program_imp with
    | None => []
    | Some p => codegen p
    end.
