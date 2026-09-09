From impboot.bootstrapping Require Import CompilerToImpTiming.
From impboot.imp2asm Require Import ImpToASMCodegen.
From Stdlib Require Import List.
From Ltac2 Require Import Ltac2.

Import ListNotations.

Time Compute
  match timed_compiler_program_imp with
  | None => []
  | Some p => codegen p
  end.
