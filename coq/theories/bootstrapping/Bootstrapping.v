From impboot Require Import
  Core
  imperative.Printing
  derivations.AsmToStringDerivations
  derivations.ParserDerivations
  derivations.CompilerUtilsDerivations
  derivations.ImpToASMCodegenDerivations
  derivations.CompilerDerivations
  fp2imp.FpToImpCodegen
  imp2asm.ImpToASMCodegen
  assembly.ASMToString.

Definition compiler_program_imp := to_imp compiler_program_prog.

Time Eval lazy in compiler_program_imp.

Definition compiler_program_asm := match compiler_program_imp with
| None => []
| Some p => codegen p
end.

Time Eval lazy in compiler_program_asm.

Definition compiler_asm_str := asm2str compiler_program_asm.

Eval lazy in compiler_asm_str.

(* Definition get_fun_name (f: FunSyntax.defun): N :=
  match f with
  | FunSyntax.Defun n _ _ => n
  end.

Definition compiler_funs_imp :=
  List.map (fun f => (N2ascii (get_fun_name f), to_funs [f])) (read_inp_prog :: print_string_prog :: compiler_funs).

Definition compiler_funs_imp1 :=
  List.map (fun f => (N2ascii (get_fun_name f), to_funs [f])) (read_inp_prog :: print_string_prog :: firstn 5 compiler_funs).

(* Eval lazy in compiler_funs_imp1. *)

Print v2exp_prog.
Eval lazy in to_cmd (
  (FunSyntax.Call
  (FunValues.name_enc "vel0")
  [FunSyntax.Op
    FunSyntax.Cons
    [FunSyntax.Const
      (FunValues.name_enc "Pair");
      FunSyntax.Op
      FunSyntax.Cons
      [FunSyntax.Var
      (FunValues.name_enc "v1");
      FunSyntax.Op
      FunSyntax.Cons
      [FunSyntax.Op
      FunSyntax.Cons
      [FunSyntax.Const
      (FunValues.name_enc "Pair");
      FunSyntax.Op
      FunSyntax.Cons
      [FunSyntax.Var
      (FunValues.name_enc "v3");
      FunSyntax.Op
      FunSyntax.Cons
      [FunSyntax.Op
      FunSyntax.Cons
      [FunSyntax.Const
      (FunValues.name_enc "Pair");
      FunSyntax.Op
      FunSyntax.Cons
      [FunSyntax.Var
      (FunValues.name_enc "v5");
      FunSyntax.Op
      FunSyntax.Cons
      [FunSyntax.Var
      (FunValues.name_enc "v6");
      FunSyntax.Const 0]]];
      FunSyntax.Const 0]]];
    FunSyntax.Const 0]]]
  ]
  )
).

Eval lazy in compiler_funs_imp. *)

(* Eval lazy in to_imp compiler_program_prog. *)
