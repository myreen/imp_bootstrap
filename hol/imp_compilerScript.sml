Theory imp_compiler
Ancestors
  arithmetic list pair finite_map string words
  imp_sexp_parser imp_to_asm x64asm_syntax

(* Top-level IMP compiler:
   source text  →  IMP AST  →  x64 assembly  →  assembly string *)

Definition compiler_def:
  compiler inp = asm2str (codegen (str2imp inp))
End
