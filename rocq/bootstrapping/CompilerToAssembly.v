From impboot.bootstrapping Require Import BootstrappingDefinitions.
From impboot.imp2asm Require Import ImpToASMCodegen.
From Stdlib Require Import List.
From Ltac2 Require Import Ltac2.

Import ListNotations.

Time Compute
  match compiler_program_imp with
  | None => []
  | Some p => codegen p
  end.
