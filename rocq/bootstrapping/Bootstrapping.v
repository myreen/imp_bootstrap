From impboot Require Import Core.
From impboot.derivations Require Import AsmToStringDerivations ParserDerivations CompilerUtilsDerivations ImpToASMCodegenDerivations CompilerDerivations.
From impboot Require Import
  fp2imp.FpToImpCodegen
  imp2asm.ImpToASMCodegen
  assembly.ASMToString
  commons.CompilerUtils
  imperative.Printing.
From Corelib Require Import Byte.

Open Scope byte_string_scope.

Print compiler_program_prog.

Definition compiler_program_imp := to_imp compiler_program_prog.

Time Compute compiler_program_imp.

Definition compiler_imp_str := match compiler_program_imp with
| None => ""%string
| Some p => imp2str p
end.

Time Compute compiler_imp_str.

Definition compiler_program_asm := match compiler_program_imp with
| None => []
| Some p => codegen p
end.

Definition compiler_asm_str := asm2bs compiler_program_asm.

Time Compute compiler_asm_str.
