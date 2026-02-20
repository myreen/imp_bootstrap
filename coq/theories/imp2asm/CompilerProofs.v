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

Theorem compiler_correct: forall input output,
  asm_terminates (Llist.of_list input) compiler_program_asm output ->
  output = compiler input.
Proof.
  intros * Hasm_terminates.
  specialize (compiler_program_thm input) as Hfp_compiler_thm.
  specialize compiler_program_imp_exists as [compiler_imp Hcompiler_program_imp]; subst.
  unfold compiler_program_imp in *.
  Opaque compiler FpToImpCodegen.to_imp ImpToASMCodegen.codegen.
  eapply to_imp_thm in Hfp_compiler_thm; eauto.
  unfold ImpSemantics.imp_weak_termination in *; cleanup.
  unfold compiler_program_asm, compiler_program_imp in *; rewrite Hcompiler_program_imp in *.
  symmetry; eapply codegen_terminates with (input := Llist.of_list input) (prog := compiler_imp).
  split; [|eauto].
  unfold ImpSemantics.prog_terminates; do 2 eexists.
  split; [eauto|].
  eapply H1.
  eapply codegen_no_abort; eauto.
Qed.

Transparent compiler FpToImpCodegen.to_imp ImpToASMCodegen.codegen.
Theorem print_parser_compiler_correct:
  match compiler_program_imp with
  | None => False
  | Some compiler_imp =>
    compiler_imp = str2imp (list_ascii_of_string (imp2str compiler_imp))
  end.
Proof.
  lazy; reflexivity.
Qed.

Theorem compiler_asm_bootstrap: forall output,
  asm_terminates (Llist.of_list (list_ascii_of_string compiler_imp_str)) compiler_program_asm output ->
  output = compiler_asm_str.
Proof.
  intros * Hasm_terminates.
  unfold compiler_imp_str in *.
  unfold compiler_asm_str, compiler_program_asm.
  specialize print_parser_compiler_correct as Hprint_parser_compiler_correct.
  specialize compiler_program_imp_exists as [compiler_imp Hcompiler_program_imp]; rewrite Hcompiler_program_imp in *.
  eapply compiler_correct in Hasm_terminates; eauto; rewrite Hasm_terminates.
  unfold compiler, dlet.
  rewrite <- Hprint_parser_compiler_correct in *.
  reflexivity.
  Opaque FpToImpCodegen.to_imp ImpToASMCodegen.codegen.
Qed.
