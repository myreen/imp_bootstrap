From impboot Require Import
  Core
  derivations.AsmToStringDerivations
  derivations.ParserDerivations
  derivations.CompilerUtilsDerivations
  derivations.ImpToASMCodegenDerivations
  derivations.CompilerDerivations
  fp2imp.FpToImpCodegen
  imp2asm.ImpToASMCodegen
  assembly.ASMToString
  commons.CompilerUtils
  imperative.Printing.

Definition compiler_program_imp := to_imp compiler_program_prog.

Theorem compiler_program_imp_exists: exists p,
  compiler_program_imp = Some p.
Proof.
  eexists; unfold compiler_program_imp.
  lazy; reflexivity.
Qed.

Time Eval lazy in compiler_program_imp.

Definition compiler_imp_str := match compiler_program_imp with
| None => ""
| Some p => imp2str p
end.

Eval lazy in compiler_imp_str.

Definition compiler_program_asm := match compiler_program_imp with
| None => []
| Some p => codegen p
end.

Time Eval lazy in compiler_program_asm.

Definition compiler_asm_str := asm2str compiler_program_asm.

Time Eval lazy in compiler_asm_str.
