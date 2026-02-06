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

Compute compiler_program_imp.

Definition get_fun_name (f: FunSyntax.defun): N :=
  match f with
  | FunSyntax.Defun n _ _ => n
  end.

Definition compiler_funs_imp :=
  List.map (fun f => (N2ascii (get_fun_name f), to_funs [f])) (read_inp_prog :: print_string_prog :: compiler_funs).

Definition compiler_funs_imp1 :=
  List.map (fun f => (N2ascii (get_fun_name f), to_funs [f])) (read_inp_prog :: print_string_prog :: firstn 5 compiler_funs).

(* Eval lazy in compiler_funs_imp1. *)

Print asm2str_header1_prog.
Eval lazy in to_cmd (
  (FunSyntax.Let (FunValues.name_enc "dot_bss")
    (FunSyntax.Op FunSyntax.Cons
    [FunSyntax.Const (N_of_ascii "009");
    FunSyntax.Op FunSyntax.Cons
    [FunSyntax.Const (N_of_ascii ".");
    FunSyntax.Op FunSyntax.Cons
    [FunSyntax.Const (N_of_ascii "b");
    FunSyntax.Op FunSyntax.Cons
    [FunSyntax.Const (N_of_ascii "s");
    FunSyntax.Op FunSyntax.Cons
    [FunSyntax.Const (N_of_ascii "s");
    FunSyntax.Op FunSyntax.Cons
    [FunSyntax.Const (N_of_ascii "010");
    FunSyntax.Op FunSyntax.Cons
    [FunSyntax.Const (N_of_ascii " ");
    FunSyntax.Op FunSyntax.Cons
    [FunSyntax.Const (N_of_ascii " "); FunSyntax.Const 0]]]]]]]])
  (FunSyntax.Const 0))
).
Eval lazy in to_cmd (
  (FunSyntax.Let (FunValues.name_enc "dot_bss")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "009");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii ".");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "b");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "s");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "s");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "010");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " "); FunSyntax.Const 0]]]]]]]])
  (FunSyntax.Let (FunValues.name_enc "bss_str") (FunSyntax.Var (FunValues.name_enc "dot_bss"))
  (FunSyntax.Let (FunValues.name_enc "dot_p2a")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "009");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii ".");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "p");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "2");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "a");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "l");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "i");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "g"); FunSyntax.Const 0]]]]]]]])
  (FunSyntax.Let (FunValues.name_enc "n3_spc")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "n");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "3");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " "); FunSyntax.Const 0]]]]]]])
  (FunSyntax.Let (FunValues.name_enc "comment1")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " "); FunSyntax.Const 0]]]]]])
  (FunSyntax.Let (FunValues.name_enc "comment2")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "/");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "*");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "8");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "-"); FunSyntax.Const 0]]]]]]])
  (FunSyntax.Let (FunValues.name_enc "comment3")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "b");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "y");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "t");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "e");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "a");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "l"); FunSyntax.Const 0]]]]]]])
  (FunSyntax.Let (FunValues.name_enc "comment4")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "i");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "g");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "n");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Const 0]]]]]]])
  (FunSyntax.Let (FunValues.name_enc "comment5")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "*");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "/");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "010");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii " ");
  FunSyntax.Const 0]]]]]]]]])
  (FunSyntax.Let (FunValues.name_enc "p2align_temp2")
  (FunSyntax.Call (FunValues.name_enc "string_append")
  [FunSyntax.Var (FunValues.name_enc "dot_p2a");
  FunSyntax.Var (FunValues.name_enc "n3_spc")])
  (FunSyntax.Let (FunValues.name_enc "p2align_temp3")
  (FunSyntax.Call (FunValues.name_enc "string_append")
  [FunSyntax.Var (FunValues.name_enc "p2align_temp2");
  FunSyntax.Var (FunValues.name_enc "comment1")])
  (FunSyntax.Let (FunValues.name_enc "p2align_temp4")
  (FunSyntax.Call (FunValues.name_enc "string_append")
  [FunSyntax.Var (FunValues.name_enc "p2align_temp3");
  FunSyntax.Var (FunValues.name_enc "comment2")])
  (FunSyntax.Let (FunValues.name_enc "p2align_temp5")
  (FunSyntax.Call (FunValues.name_enc "string_append")
  [FunSyntax.Var (FunValues.name_enc "p2align_temp4");
  FunSyntax.Var (FunValues.name_enc "comment3")])
  (FunSyntax.Let (FunValues.name_enc "p2align_temp6")
  (FunSyntax.Call (FunValues.name_enc "string_append")
  [FunSyntax.Var
  (FunValues.name_enc "p2align_temp5");
  FunSyntax.Var (FunValues.name_enc "comment4")])
  (FunSyntax.Let (FunValues.name_enc "p2align_temp7")
  (FunSyntax.Call
  (FunValues.name_enc "string_append")
  [FunSyntax.Var
  (FunValues.name_enc "p2align_temp6");
  FunSyntax.Var (FunValues.name_enc "comment5")])
  (FunSyntax.Let (FunValues.name_enc "p2align1_str")
  (FunSyntax.Var
  (FunValues.name_enc "p2align_temp7"))
  (FunSyntax.Let (FunValues.name_enc "heaps_lbl")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "h");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "e");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "a");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "p");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "S");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii ":");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "010");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  " ");
  FunSyntax.Const
  0]]]]]]]]])
  (FunSyntax.Let
  (FunValues.name_enc "space_cmd")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "009");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii ".");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "s");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "p");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "a");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "c");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "e");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  " ");
  FunSyntax.Const
  0]]]]]]]])
  (FunSyntax.Let
  (FunValues.name_enc "size_str")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const (N_of_ascii "8");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "*");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "1");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "0");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "2");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "4");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "*");
  FunSyntax.Const
  0]]]]]]])
  (FunSyntax.Let
  (FunValues.name_enc "size_str2")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "1");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "0");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "2");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "4");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "/");
  FunSyntax.Const
  0]]]]]]])
  (FunSyntax.Let
  (FunValues.name_enc "comment6")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "*");
  FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "b");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "y");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "t");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "e");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "s");
  FunSyntax.Const
  0]]]]]]])
  (FunSyntax.Let
  (FunValues.name_enc
  "comment7")
  (FunSyntax.Op FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "o");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "f");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "h");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "e");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "a");
  FunSyntax.Const
  0]]]]]]])
  (FunSyntax.Let
  (FunValues.name_enc
  "comment8")
  (FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii "p");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "s");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "p");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "a");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "c");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "e");
  FunSyntax.Const
  0]]]]]]])
  (FunSyntax.Let
  (FunValues.name_enc
  "comment9")
  (FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "*");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "/");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  "010");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  " ");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Const
  (N_of_ascii
  " ");
  FunSyntax.Const
  0]]]]]])
  (FunSyntax.Let
  (FunValues.name_enc
  "space_temp2")
  (FunSyntax.Call
  (FunValues.name_enc
  "string_append")
  [FunSyntax.Var
  (FunValues.name_enc
  "space_cmd");
  FunSyntax.Var
  (FunValues.name_enc
  "size_str")])
  (FunSyntax.Let
  (FunValues.name_enc
  "space_temp3")
  (FunSyntax.Call
  (FunValues.name_enc
  "string_append")
  [FunSyntax.Var
  (FunValues.name_enc
  "space_temp2");
  FunSyntax.Var
  (FunValues.name_enc
  "size_str2")])
  (FunSyntax.Let
  (FunValues.name_enc
  "space_temp4")
  (FunSyntax.Call
  (FunValues.name_enc
  "string_append")
  [FunSyntax.Var
  (FunValues.name_enc
  "space_temp3");
  FunSyntax.Var
  (FunValues.name_enc
  "comment6")])
  (FunSyntax.Let
  (FunValues.name_enc
  "space_temp5")
  (FunSyntax.Call
  (FunValues.name_enc
  "string_append")
  [FunSyntax.Var
  (FunValues.name_enc
  "space_temp4");
  FunSyntax.Var
  (FunValues.name_enc
  "comment7")])
  (FunSyntax.Let
  (FunValues.name_enc
  "space_temp6")
  (FunSyntax.Call
  (FunValues.name_enc
  "string_append")
  [FunSyntax.Var
  (FunValues.name_enc
  "space_temp5");
  FunSyntax.Var
  (FunValues.name_enc
  "comment8")])
  (FunSyntax.Let
  (FunValues.name_enc
  "space_temp7")
  (FunSyntax.Call
  (FunValues.name_enc
  "string_append")
  [FunSyntax.Var
  (FunValues.name_enc
  "space_temp6");
  FunSyntax.Var
  (FunValues.name_enc
  "comment9")])
  (FunSyntax.Let
  (FunValues.name_enc
  "space_str")
  (FunSyntax.Var
  (FunValues.name_enc
  "space_temp7"))
  (FunSyntax.Let
  (FunValues.name_enc
  "list1")
  (FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Var
  (FunValues.name_enc
  "bss_str");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Var
  (FunValues.name_enc
  "p2align1_str");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Var
  (FunValues.name_enc
  "heaps_lbl");
  FunSyntax.Op
  FunSyntax.Cons
  [FunSyntax.Var
  (FunValues.name_enc
  "space_str");
  FunSyntax.Const
  0]]]])
  (FunSyntax.Var
  (FunValues.name_enc
  "list1"))))))))))))))))))))))))))))))))))
).

Eval lazy in compiler_funs_imp.

(* Eval lazy in to_imp compiler_program_prog. *)
