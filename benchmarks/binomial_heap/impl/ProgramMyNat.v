From impboot Require Import Core.
From impboot.functional Require Import FunSyntax FunValues.
From impboot.fp2imp Require Import FpToImpCodegen.
From impboot.imp2asm Require Import ImpToASMCodegen.
From impboot.assembly Require Import ASMToString.
From Stdlib Require Import List NArith String.
From Corelib Require Import Byte.
Require Import ReifyMyNat.

Import ListNotations.

Definition mynat_funs : list FunSyntax.defun := [
  my_ltb_prog;
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
  my_add_prog;
  my_mul_prog;
  make_my10_prog;
  benchmark_main_prog
].

Definition mynat_imp_funs := to_funs mynat_funs.

Definition mynat_main : FunSyntax.exp :=
  FunSyntax.Call (name_enc "benchmark_main") [].

Definition mynat_program : FunSyntax.prog :=
  FunSyntax.Program mynat_funs mynat_main.

Definition mynat_program_imp := to_imp mynat_program.

Definition mynat_program_asm :=
  match mynat_program_imp with
  | None => []
  | Some p => codegen p
  end.

Definition mynat_asm_bytes : bytestring :=
  asm2bs mynat_program_asm.

Open Scope byte_string_scope.

Compute mynat_asm_bytes.
