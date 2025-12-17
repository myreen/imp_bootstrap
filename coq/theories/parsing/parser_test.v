Require Import impboot.utils.Core.
Require Import impboot.parsing.parser.
Require Import impboot.imperative.ImpSyntax.

Example prog_string := 
"(Program
  (Func main ()
    (Seq
      (Call _ getchar ())
      (PutChar (Const 65))
    )
  )
)"%string.

(* Compute (parser.prog 50) prog_string. *)