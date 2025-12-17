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

Derive c_add_prog 
  in ltac2:(relcompile_tpe 'c_add_prog 'c_add []) 
  as c_add_prog_proof.
Proof.
  time relcompile.
Qed.
Print c_add_prog.

Example c_add_imp_prog :=
  (to_funs [c_add_prog]).

Compute c_add_imp_prog.
Time Eval lazy in (
  match c_add_imp_prog with
  | Some [p] => Some (
    imp2str (Program [p])
  )
  | _ => None
  end
).

Compute (
  match c_add_imp_prog with
  | Some [p] => Some (
    flatten (fst (c_fundef p 0 []))
  )
  | _ => None
  end
).

Time Eval lazy in (
  match c_add_imp_prog with
  | Some [p] => Some (
    let asm := flatten (fst (c_fundef p 0 [])) in
    instrs2str 0 asm
  )
  | _ => None
  end
).
