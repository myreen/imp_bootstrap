Theory imp_compiler_proofs
Ancestors
  arithmetic list pair finite_map string words
  imp_source_syntax imp_source_semantics
  x64asm_syntax x64asm_semantics
  imp_printing imp_sexp_parser imp_compiler
  imp_to_asm_proof source_to_imp
Libs
  wordsLib BasicProvers

(* Correctness proofs for the top-level IMP compiler.                *)
(* Corresponds to coq/theories/imp2asm/CompilerProofs.v              *)

(* ------------------------------------------------------------------ *)
(* compiler_correct: if the compiled ASM program terminates with some *)
(* output, that output equals compiler inp.                           *)
(* ------------------------------------------------------------------ *)

(*
Theorem compiler_correct:
  ∀input output.
    asm_terminates (fromList input) (codegen (str2imp input)) output ⇒
    output = compiler input
Proof
  cheat
QED
*)

(* ------------------------------------------------------------------ *)
(* print_parser_compiler_correct: printing and then parsing the       *)
(* compiler IMP program is an identity (round-trip).                  *)
(* This corresponds to the fact that imp2str and str2imp are inverses *)
(* on well-formed IMP programs produced by the compiler pipeline.     *)
(* ------------------------------------------------------------------ *)

Theorem print_parser_compiler_correct:
  ∀imp_prog.
    to_imp compiler_prog = SOME imp_prog ⇒
    imp_prog = str2imp (imp2str imp_prog)
Proof
  cheat
QED

(* ------------------------------------------------------------------ *)
(* compiler_asm_bootstrap: running the compiled ASM on the printed    *)
(* IMP source of the compiler produces the ASM string of the          *)
(* compiler itself.                                                    *)
(* ------------------------------------------------------------------ *)

(*
Theorem compiler_asm_bootstrap:
  ∀imp_prog output.
    to_imp compiler_prog = SOME imp_prog ⇒
    asm_terminates (fromList (imp2str imp_prog))
                   (codegen imp_prog) output ⇒
    output = asm2str (codegen imp_prog)
Proof
  cheat
QED
*)
