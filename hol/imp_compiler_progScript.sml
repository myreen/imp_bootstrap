Theory imp_compiler_prog
Ancestors
  arithmetic list pair finite_map string words
  imp_compiler source_syntax

(* Top-level IMP compiler:
   source text  →  IMP AST  →  x64 assembly  →  assembly string *)

Definition compiler_prog_def:
  compiler_prog = Program [] ARB : source_syntax$prog
End
