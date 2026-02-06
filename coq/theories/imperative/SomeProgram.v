From impboot Require Import utils.Core.
Require Import coqutil.Word.Interface.
From impboot Require Import functional.FunValues.
From impboot Require Import imperative.ImpSemantics.
From impboot Require Import imperative.ImpSyntax.
From impboot Require Import imperative.Printing.
From impboot Require Import parsing.Parser.
From impboot Require Import imp2asm.ImpToASMCodegen.

Definition some_program1 :=
  Program [
    Func (name_enc "main") [] (
      Seq (
        PutChar (Const (word.of_Z 48))
      ) (
        Return (Const (word.of_Z 0))
      )
    )
  ].

Eval lazy in imp2str some_program1.

Eval lazy in str2imp (list_ascii_of_string (imp2str some_program1)).

Eval lazy in codegen some_program1.

(* Eval lazy in eval_from *)


