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

Example c_add_reparsed :=
  match c_add_imp_prog with
  | Some [p] => 
    let pretty := imp2str (Program [p]) in
    Some (str2imp (list_ascii_of_string pretty))
  | _ => None
  end.
Eval lazy in c_add_reparsed.
Goal (forall fs, c_add_imp_prog = Some fs -> c_add_reparsed = Some (Program fs)).
Proof.
  intros * H; inversion H; lazy.
  repeat f_equal.
Qed.

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
