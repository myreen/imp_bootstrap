From impboot.functional Require Import FunSyntax FunValues FunSemantics.
From impboot.imperative Require Import ImpSyntax Printing.
From Stdlib Require Import NArith ZArith Lists.List Bool String.
From coqutil.Word Require Import Interface Properties.
From coqutil Require Import Datatypes.List.
Import ListNotations.
From impboot.imp2asm Require Import ImpToASMCodegen.
From impboot.commons Require Import CompilerUtils.
From Stdlib Require Import Derive.
From Ltac2 Require Import Ltac2.
From impboot.automation Require Import RelCompiler AutomationLemmas.
From impboot.automation.ltac2 Require Import UnfoldFix.
From impboot.automation Require Import Ltac2Utils.
From impboot.fp2imp Require Import FpToImpCodegen.
From impboot.assembly Require Import ASMToString.
From impboot.parsing Require Import Parser.

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
  all: repeat f_equal.
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
    is2str 0 asm
  )
  | _ => None
  end
).
