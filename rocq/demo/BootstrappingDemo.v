From impboot Require Import functional.FunSyntax functional.FunValues.
From impboot Require Import imperative.ImpSyntax.
From Stdlib Require Import NArith.
From Stdlib Require Import ZArith.
From Stdlib Require Import Lists.List.
From Stdlib Require Import Bool.
From Stdlib Require Import String.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
Require Import coqutil.Datatypes.List.
Import ListNotations.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.commons.CompilerUtils.
Require Import Derive.
Require Import Ltac2.Ltac2.
Require Import impboot.automation.RelCompiler.
Require Import impboot.automation.ltac2.UnfoldFix.
Require Import impboot.automation.AutomationLemmas.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
From impboot Require Import fp2imp.FpToImpCodegen.
From impboot Require Import assembly.ASMToString.
From impboot Require Import imperative.Printing.
From impboot Require Import parsing.Parser.

Print c_add.

Derive c_add_fp
  in ltac2:(relcompile_tpe 'c_add_fp 'c_add []) 
  as c_add_prog_proof.
Proof.
  time relcompile.
Qed.
About c_add_prog_proof.
Print c_add_fp.

Example c_add_imp :=
  (to_funs [c_add_fp]).

Check c_add_imp.
Compute c_add_imp.

Compute (
  match c_add_imp with
  | Some [p] => Some (
    flatten (fst (c_fundef p 0 []))
  )
  | _ => None
  end
).

Compute (
  match c_add_imp with
  | Some [p] => Some (
    let asm := flatten (fst (c_fundef p 0 [])) in
    asm2str asm
  )
  | _ => None
  end
).

Definition e (y: nat): nat :=
  let x := 5%nat in
  x + y.

Derive e_prog
  in ltac2:(relcompile_tpe 'e_prog 'e [])
  as e_prog_proof.
Proof.
  time relcompile.
Qed.





