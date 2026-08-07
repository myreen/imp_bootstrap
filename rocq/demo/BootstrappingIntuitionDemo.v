From impboot Require Import Core.
From coqutil Require Import Word.Interface Word.Properties.
From impboot.imperative Require Import ImpSyntax.
From impboot.functional Require Import FunValues.
From impboot.imp2asm Require Import ImpToASMCodegen Compiler.
Open Scope string.

Locate compiler.

Fail Compute (compiler compiler).

About compiler.

About codegen.

Fail Compute (codegen compiler).

Fail Definition compiler_magic: ImpSyntax.prog := compiler.

Definition e (y: nat): nat :=
  let x := 5 in
  x + y.

Definition e_imp: ImpSyntax.func :=
  Func (name_enc "e") [name_enc "y"]
    (Seq
      (Assign (name_enc "x") (Const (word.of_Z 5)))
      (Return (Add (Var (name_enc "x")) (Var (name_enc "y"))))).
