From impboot Require Import Core.
From impboot.functional Require Import FunSyntax FunValues.
From impboot.fp2imp Require Import FpToImpCodegen.
From impboot.imp2asm Require Import ImpToASMCodegen.
From impboot.assembly Require Import ASMToString.
From Stdlib Require Import List NArith String.
From Corelib Require Import Byte.
Require Import ReifyAdjusted.

Import ListNotations.

Definition adjusted_funs : list FunSyntax.defun := [
  smash_prog;
  carry_prog;
  insert_prog;
  join_prog;
  merge_prog;
  unzip_acc_prog;
  unzip_prog;
  heap_delete_max_prog;
  find_max'_prog;
  find_max_prog;
  delete_max_aux_prog;
  delete_max_prog;
  insert_list_prog;
  make_list_prog;
  benchmark_main_prog
].

Definition adjusted_imp_funs := to_funs adjusted_funs.

Definition adjusted_main : FunSyntax.exp :=
  FunSyntax.Call (name_enc "benchmark_main") [].

Definition adjusted_program : FunSyntax.prog :=
  FunSyntax.Program adjusted_funs adjusted_main.

Definition adjusted_program_imp := to_imp adjusted_program.

Definition adjusted_program_asm :=
  match adjusted_program_imp with
  | None => []
  | Some p => codegen p
  end.

Definition adjusted_asm_bytes : bytestring :=
  asm2bs adjusted_program_asm.

Open Scope byte_string_scope.

Compute adjusted_asm_bytes.
