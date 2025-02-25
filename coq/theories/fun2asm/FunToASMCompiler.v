From Coq Require Import String.
From ImpBootstrap Require Import ASMSyntax.

Module FunToASMCompiler.

Definition compiler (s : string) : string :=
  ASMSyntax.asm2str (codegen (parser (lexer s))).

End FunToASMCompiler.