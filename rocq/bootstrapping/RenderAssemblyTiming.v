From impboot.bootstrapping Require Import CompilerToAssemblyTiming.
From impboot.assembly Require Import ASMToString.
From Corelib Require Import Byte.
From Ltac2 Require Import Ltac2.

Open Scope byte_string_scope.

Ltac2 Eval Message.print
  (Message.of_string "TIMING compiler_stage render_assembly").
Time Definition timed_compiler_asm_bytes :=
  Eval vm_compute in asm2bs timed_compiler_program_asm.
