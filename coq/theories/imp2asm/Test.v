From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.imp2asm.ImpToASMCodegen.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
Require Import impboot.automation.RelCompiler.
Require Import impboot.automation.ltac2.UnfoldFix.
Require Import impboot.automation.AutomationLemmas.
Require Import coqutil.Word.Interface.
Require Import ZArith.
From Stdlib Require Import FunInd.
From Stdlib Require Import derive.Derive.
From Stdlib Require Import Lia.
From Ltac2 Require Import Ltac2.

Require Import Patat.Patat.

Set Printing Goal Names.
Set Printing Existential Instances.

Open Scope app_list_scope.

Theorem N_modulo_bounds: forall n b,
  (0 <> b)%N ->
  (N_modulo n b < b)%N.
Proof.
  intros; unfold N_modulo; rewrite <- N.Div0.mod_eq.
  destruct b eqn:?; try ltac1:(lia).
  eapply N.mod_upper_bound.
  ltac1:(lia).
Qed.

Derive name2str_prog
  in ltac2:(relcompile_tpe 'name2str_prog 'name2str ['N_modulo]) 
  as name2str_prog_proof.
Proof.
  time relcompile.
  eapply N_modulo_bounds; ltac1:(lia).
Qed.