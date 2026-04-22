From impboot.utils Require Import Core.
From impboot.imp2asm Require Import ImpToASMCodegen.
From impboot.imperative Require Import Printing ImpSyntax.
From impboot.parsing Require Import Parser.
From impboot.assembly Require Import ASMToString.

Definition compiler (inp: list ascii): string :=
  let/d p := str2imp inp in
  let/d asm := codegen p in
  let/d str := asm2str asm in
  str.
