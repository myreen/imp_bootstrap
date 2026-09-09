From impboot.bootstrapping Require Import CompilerToAssemblyTiming.
From impboot.assembly Require Import ASMToString.
From impboot.utils Require Import Core.
From Corelib Require Import Byte.
From Ltac2 Require Import Ltac2.

Open Scope byte_string_scope.

Time Compute asm2bs timed_compiler_program_asm.
