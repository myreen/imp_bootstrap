Theory bootstrapping
Ancestors
  arithmetic list pair finite_map string words
  source_values source_syntax x64asm_syntax
  imp_source_syntax imp_source_semantics
  x64asm_semantics imp_to_asm_proof
  imp_printing imp_parsing imp_to_asm imp_compiler
  source_to_imp imp_compiler_prog imp_compiler_cv
Libs
  wordsLib BasicProvers cv_transLib imp_automationLib

(* Bootstrapping definitions and theorems for the IMP compiler.       *)
(*                                                                    *)
(* The bootstrapping pipeline is:                                     *)
(*   compiler_prog  (functional language program)                     *)
(*     -- to_imp -->                                                  *)
(*   compiler_program_imp  (IMP program)                              *)
(*     -- codegen -->                                                 *)
(*   compiler_program_asm  (x64 assembly instructions)                *)
(*     -- asm2str -->                                                 *)
(*   compiler_asm_str  (assembly source string)                       *)

(* ------------------------------------------------------------------ *)
(* Definitions                                                        *)
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

val _ = cv_trans_deep_embedding EVAL imp_compiler_progTheory.compiler_prog_def;

Theorem compiler_program_imp_exists:
  ∃p. compiler_program_imp = SOME p
Proof
  simp [compiler_program_imp_def]
  \\ ‘to_imp compiler_prog ≠ NONE’ by CONV_TAC cv_eval
  \\ Cases_on ‘to_imp compiler_prog’ \\ fs []
QED

(* compiler_program_thm: the reflection theorem.  The compiler's IMP     *)
(* program computes the shallow `compiler` function on every input.      *)
(* Corresponds to compiler_program_thm in derivations/CompilerDerivations*)
(* .v lifted through to_imp_thm to the imperative level (it is the       *)
(* composition of the functional compiler_prog_correct with to_imp_thm). *)
Theorem compiler_program_thm:
  ∀input p.
    compiler_program_imp = SOME p ⇒
    (fromList input, p) imp_weak_termination (compiler input)
Proof
  rw [compiler_program_imp_def]
  \\ irule to_imp_thm
  \\ qexists_tac ‘compiler_prog’
  \\ conj_tac >- fs []
  \\ assume_tac (Q.SPEC ‘input’ compiler_prog_correct) \\ fs []
QED

(* ------------------------------------------------------------------ *)
(* Top-level bootstrapping results                                    *)
(* Correspond to the final theorems in imp2asm/CompilerProofs.v       *)
(* ------------------------------------------------------------------ *)

(* compiler_correct: running the compiled compiler binary on any input *)
(* produces exactly what the shallow compiler function computes.       *)
Theorem compiler_correct:
  ∀input output.
    (input, compiler_program_asm) asm_terminates output ⇒
    output = compiler input
Proof
  rpt strip_tac
  \\ ‘∃p. compiler_program_imp = SOME p’ by metis_tac [compiler_program_imp_exists]
  \\ ‘(fromList input,p) imp_weak_termination (compiler input)’
       by metis_tac [compiler_program_thm]
  \\ gvs [compiler_program_asm_def]
  \\ gvs [imp_weak_termination_def]
  \\ ‘outcome ≠ Stop Crash’ by (strip_tac \\ gvs [])
  \\ ‘outcome ≠ Stop Abort’ by metis_tac [codegen_no_abort]
  \\ gvs []
  \\ ‘imp_terminates (fromList input) p k (compiler input)’
       by (fs [imp_terminates_def] \\ metis_tac [])
  \\ metis_tac [codegen_terminates]
QED

(* print_parser_compiler_correct: printing the compiler's IMP program  *)
(* and parsing it back is the identity (a print/parse round-trip).     *)
Theorem print_parser_compiler_correct:
  case compiler_program_imp of
  | NONE => F
  | SOME p => p = str2imp (imp2str p)
Proof
  simp [compiler_program_imp_def] \\ CONV_TAC cv_eval
QED

Theorem compiler_compiler_imp_str:
  compiler compiler_imp_str = compiler_asm_str
Proof
  simp [compiler_def, compiler_imp_str_def, compiler_program_imp_def,
        compiler_asm_str_def, compiler_program_asm_def]
  \\ AP_TERM_TAC \\ CONV_TAC cv_eval
QED

(* compiler_asm_bootstrap: running the compiled compiler on its own    *)
(* printed IMP source reproduces the compiler's assembly string.       *)
Theorem compiler_asm_bootstrap:
  ∀output.
    ((fromList compiler_imp_str, compiler_program_asm) : char llist # asm)
      asm_terminates output ⇒
    output = compiler_asm_str
Proof
  rpt strip_tac
  \\ qspecl_then [‘compiler_imp_str’,‘output’] mp_tac compiler_correct
  \\ simp [compiler_compiler_imp_str]
QED


(* ------------------------------------------------------------------ *)
(* Write strings to file                                              *)
(* ------------------------------------------------------------------ *)

val _ = (max_print_depth := 10);

val _ = cv_trans compiler_program_imp_def;
val _ = cv_trans compiler_program_asm_def;
val _ = cv_trans compiler_imp_str_def;
val _ = cv_trans compiler_asm_str_def;

Theorem imp_thm = time cv_eval_raw “compiler_imp_str”;
Theorem asm_thm = time cv_eval_raw “compiler_asm_str”;

val _ = write_string_to_file "imp_compiler_prog.txt" (imp_thm |> concl |> rand);
val _ = write_string_to_file "imp_compiler_asm.s"    (asm_thm |> concl |> rand);
