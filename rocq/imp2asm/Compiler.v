Require Import impboot.utils.Core.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.imperative.Printing.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.parsing.Parser.
Require Import impboot.assembly.ASMToString.

Definition compiler (inp: list ascii): string :=
  let/d p := str2imp inp in
  let/d asm := codegen p in
  let/d str := asm2str asm in
  str.
