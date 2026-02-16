From impboot.utils Require Import Core.
From impboot.imp2asm Require Import Compiler.
From impboot.parsing Require Import Parser.
From impboot.imperative Require Import Printing.
From impboot.bootstrapping Require Import Bootstrapping.

Theorem print_parser_compiler_correct:
  match compiler_program_imp with
  | None => False
  | Some compiler_imp =>
    compiler_imp = str2imp (list_ascii_of_string (imp2str compiler_imp))
  end.
Proof.
  lazy; reflexivity.
Qed.
