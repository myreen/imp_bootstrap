From impboot.utils Require Import Core.
From coqutil Require Import Word.Interface.
From impboot.functional Require Import FunValues FunSemantics.
From impboot.imperative Require Import ImpSemantics ImpSyntax Printing.
From impboot.parsing Require Import Parser.
From impboot.imp2asm Require Import ImpToASMCodegen Compiler.
From impboot.fp2imp Require Import FpToImpCodegen.
From impboot.commons Require Import CompilerUtils.
From impboot.assembly Require Import ASMToString.
From impboot.automation Require Import RelCompiler RelCompilerCommons RelCompileUnfolding.
From impboot.automation.ltac2 Require Import UnfoldFix.
From Ltac2 Require Import Ltac2.

Definition some_program1 :=
  Program [
    Func (name_enc "main") [] (
      Seq (
        PutChar (Const (word.of_Z 65))
      ) (
        Return (Const (word.of_Z 0))
      )
    )
  ].

Eval lazy in imp2str some_program1.

Eval lazy in str2imp (list_ascii_of_string (imp2str some_program1)).

Eval lazy in codegen some_program1.

Eval lazy in asm2str (codegen some_program1).

Definition some_program1_str := imp2str some_program1.

Compute some_program1_str.

Eval lazy in compiler (list_ascii_of_string some_program1_str).

Fixpoint apnd (s1 s2: string): string :=
  match s1 with
  | EmptyString => s2
  | String c s1 =>
    String c (apnd s1 s2)
  end.

Theorem apnd_equation: ltac2:(unfold_fix_type '@apnd).
Proof. unfold_fix_proof '@apnd. Qed.
Derive apnd_prog
  in ltac2:(relcompile_tpe 'apnd_prog 'apnd [])
  as apnd_prog_proof.
Proof.
  time relcompile.
Qed.
Print apnd_prog.

Definition apnd_imp := to_funs [apnd_prog].

Compute apnd_imp.

Definition program_with_apnd := match apnd_imp with
  | Some [safi] =>
    Program [
      Func (name_enc "main") [] (
        Seq (
          PutChar (Const (word.of_Z 65))
        ) (
          Return (Const (word.of_Z 0))
        )
      );
      safi
    ]
  | _ => Program []
  end.

Eval lazy in program_with_apnd.

Eval lazy in imp2str program_with_apnd.

Eval lazy in str2imp (list_ascii_of_string (imp2str program_with_apnd)).

Eval lazy in codegen program_with_apnd.

Eval lazy in asm2str (codegen program_with_apnd).