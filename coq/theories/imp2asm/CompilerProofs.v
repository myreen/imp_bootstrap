From impboot.utils Require Import Core Llist.
From impboot.imp2asm Require Import Compiler.
From impboot.parsing Require Import Parser.
From impboot.imperative Require Import Printing.
From impboot.bootstrapping Require Import Bootstrapping.
From impboot.assembly Require Import ASMSemantics.
From impboot.imperative Require Import ImpSyntax.
From impboot.derivations Require Import CompilerDerivations.
From impboot.imp2asm Require Import ImpToASMCodegenProofs.
From impboot.fp2imp Require Import FpToImpCodegenProof.

(* forall input prog output1 output2,
    prog_terminates input prog fuel output1 sd /\
    asm_terminates input (codegen prog) sd output2 ->
      output1 = output2. *)

(* 
Theorem compiler_asm_correct:
  ∀input output.
    (input, compiler_asm) asm_terminates output ⇒
    output = compiler input
Proof
  metis_tac [compiler_asm_def,codegen_terminates,compiler_prog_correct]
QED

Theorem compiler_compiler_str:
  compiler compiler_str = compiler_asm_str
Proof
  fs [compiler_str_def,codegenTheory.compiler_def,
      parser_lexer_prog2str,compiler_asm_str_def,compiler_asm_def]
QED

Theorem compiler_asm_bootstrap:
  (compiler_str, compiler_asm) asm_terminates output ⇒
  output = compiler_asm_str
Proof
  metis_tac [compiler_asm_correct,compiler_compiler_str]
QED
*)

Theorem compiler_correct: forall input output sd,
  asm_terminates (Llist.of_list input) compiler_program_asm sd output ->
  output = compiler input.
Proof.
  intros * Hasm_terminates.
  specialize (compiler_program_thm input) as Hfp_compiler_thm.
  specialize compiler_program_imp_exists as [compiler_imp Hcompiler_program_imp]; subst.
  unfold compiler_program_imp in *.
  eapply to_imp_thm in Hfp_compiler_thm; eauto.
  unfold ImpSemantics.imp_weak_termination in *; cleanup.
  eapply codegen_terminates with (output2 := compiler input).
Admitted.

Theorem print_parser_compiler_correct:
  match compiler_program_imp with
  | None => False
  | Some compiler_imp =>
    compiler_imp = str2imp (list_ascii_of_string (imp2str compiler_imp))
  end.
Proof.
  lazy; reflexivity.
Qed.

(* TODO: move to Bootstrapping.v? *)
Eval lazy in (match compiler_program_imp with
  | None => ""
  | Some compiler_imp =>
    imp2str compiler_imp
  end).
