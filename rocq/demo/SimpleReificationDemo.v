From impboot.functional Require Import FunSyntax FunValues FunSemantics.
From impboot.imperative Require Import ImpSyntax Printing.
From impboot.imp2asm Require Import ImpToASMCodegen.
From impboot.fp2imp Require Import FpToImpCodegen.
From impboot.assembly Require Import ASMToString.
From impboot.automation Require Import RelCompiler RelCompilerCommons AutomationLemmas ltac2.UnfoldFix Ltac2Utils.
From impboot.utils Require Import Core.
From impboot.parsing Require Import Parser.
From Stdlib Require Import NArith ZArith Lists.List Bool String Derive.
From coqutil Require Import Tactics Z.Lia Word.Interface Word.Properties Datatypes.List.
From Ltac2 Require Import Ltac2.
Import ListNotations.
From impboot.demo Require Import DemoUtils.

Definition f1: nat :=
  let/d n := 2%nat in
  (n + 1)%nat.

Derive f1_prog
  in ltac2:(relcompile_tpe 'f1_prog 'f1 [])
  as f1_prog_proof.
Proof.
  relcompile_setup ().
  eapply trans_app.
  3: eauto.
  2: reflexivity.
  unfold f1.
  eapply auto_let with (let_n := "n").
  1: eapply auto_nat_const.
  intros; cbv beta.
  eapply auto_nat_add.
  1: eapply trans_Var; eauto with fenvDb.
  eapply auto_nat_const.

Qed.
