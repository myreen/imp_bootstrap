From impboot Require Import Core.
From impboot.binomial_heap Require Import BinomialHeap.
From impboot.functional Require Import FunSyntax FunValues.
From impboot.fp2imp Require Import FpToImpCodegen.
From impboot.imp2asm Require Import ImpToASMCodegen.
From impboot.assembly Require Import ASMToString.
From impboot.imperative Require Import Printing.
From Stdlib Require Import List NArith String.
From Corelib Require Import Byte.

Import ListNotations.

(** Print an error marker and a newline for EOF or non-digit input. *)
Definition invalid_main : FunSyntax.exp :=
  FunSyntax.Let (name_enc "ignored")
    (FunSyntax.Op FunSyntax.Write [FunSyntax.Const 63%N])
    (FunSyntax.Let (name_enc "done")
      (FunSyntax.Op FunSyntax.Write [FunSyntax.Const 10%N])
      (FunSyntax.Var (name_enc "done"))).

(** Run the benchmark for one validated ASCII digit and print its checksum. *)
Definition valid_main : FunSyntax.exp :=
  FunSyntax.Let (name_enc "n")
    (FunSyntax.Op FunSyntax.Sub
      [FunSyntax.Var (name_enc "c"); FunSyntax.Const 48%N])
    (FunSyntax.Let (name_enc "sum")
      (FunSyntax.Call (name_enc "bench") [FunSyntax.Var (name_enc "n")])
      (FunSyntax.Let (name_enc "out")
        (FunSyntax.Call (name_enc "digit")
          [FunSyntax.Var (name_enc "sum")])
        (FunSyntax.Let (name_enc "ignored")
          (FunSyntax.Op FunSyntax.Write [FunSyntax.Var (name_enc "out")])
          (FunSyntax.Let (name_enc "done")
            (FunSyntax.Op FunSyntax.Write [FunSyntax.Const 10%N])
            (FunSyntax.Var (name_enc "done")))))).

(** Read one byte.  Only ASCII ['0', '9'] reaches the benchmark. *)
Definition binomial_main : FunSyntax.exp :=
  FunSyntax.Let (name_enc "c") (FunSyntax.Op FunSyntax.Read [])
    (FunSyntax.If FunSyntax.Less
      [FunSyntax.Var (name_enc "c"); FunSyntax.Const 48%N]
      invalid_main
      (FunSyntax.If FunSyntax.Less
        [FunSyntax.Var (name_enc "c"); FunSyntax.Const 58%N]
        valid_main
        invalid_main)).

Definition binomial_program : FunSyntax.prog :=
  FunSyntax.Program binomial_funs binomial_main.

(** Complete IMP program: builtins, generated [main], heap, and benchmark. *)
Definition binomial_program_imp := to_imp binomial_program.

Lemma binomial_program_imp_ok :
  exists p, binomial_program_imp = Some p.
Proof.
  vm_compute.
  eauto.
Qed.

Definition binomial_imp_string : string :=
  match binomial_program_imp with
  | None => EmptyString
  | Some p => imp2str p
  end.

(** Whole-program x86-64 assembly, including runtime initialization. *)
Definition binomial_program_asm :=
  match binomial_program_imp with
  | None => []
  | Some p => codegen p
  end.

Lemma binomial_program_asm_nonempty :
  binomial_program_asm <> [].
Proof.
  vm_compute.
  discriminate.
Qed.

Definition binomial_asm_string : string :=
  asm2str binomial_program_asm.

Definition binomial_asm_bytes : list byte :=
  asm2bs binomial_program_asm.

Open Scope byte_string_scope.

Compute binomial_asm_bytes.
