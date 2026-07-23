Theory bootstrapping
Ancestors
  arithmetic list pair finite_map string words
  source_values source_syntax x64asm_syntax
  imp_source_syntax imp_source_semantics
  imp_printing imp_parsing imp_to_asm
  source_to_imp imp_compiler_prog
Libs
  wordsLib BasicProvers

(* Bootstrapping definitions and theorems for the IMP compiler.      *)
(* Corresponds to coq/theories/bootstrapping/Bootstrapping.v         *)
(*                                                                     *)
(* The bootstrapping pipeline is:                                     *)
(*   compiler_prog  (functional language program)                     *)
(*     -- to_imp -->                                                   *)
(*   compiler_program_imp  (IMP program)                              *)
(*     -- codegen -->                                                  *)
(*   compiler_program_asm  (x64 assembly instructions)                *)
(*     -- asm2str -->                                                  *)
(*   compiler_asm_str  (assembly source string)                       *)

(* ------------------------------------------------------------------ *)
(* Definitions                                                         *)
(* ------------------------------------------------------------------ *)

(* The compiler program translated to IMP. *)
Definition compiler_program_imp_def:
  compiler_program_imp = to_imp compiler_prog
End

(* The IMP source string of the compiler (printed via imp2str). *)
Definition compiler_imp_str_def:
  compiler_imp_str =
    case compiler_program_imp of
    | NONE => ""
    | SOME p => imp2str p
End

(* The x64 assembly instructions for the compiler. *)
Definition compiler_program_asm_def:
  compiler_program_asm =
    case compiler_program_imp of
    | NONE => []
    | SOME p => codegen p
End

(* The assembly source string of the compiler. *)
Definition compiler_asm_str_def:
  compiler_asm_str = asm2str compiler_program_asm
End

(* ------------------------------------------------------------------ *)
(* Existence: the compiler program can be translated to IMP.          *)
(* ------------------------------------------------------------------ *)

Theorem compiler_program_imp_exists:
  ∃p. compiler_program_imp = SOME p
Proof
  cheat
QED
