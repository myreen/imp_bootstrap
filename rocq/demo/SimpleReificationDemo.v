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
  (* all: relcompile_start ().
  all: relcompile_step ().
  all: relcompile_step ().
  all: relcompile_step (). *)

  relcompile_setup ().
  unfold f1.
  eapply trans_app.
  3: eauto.
  2: reflexivity.
  refine open_constr:(auto_let
  (* env *) ltac2:(eauto)
  (* x1 y1 *) _ _
  (* s1 s2 s3 *) ltac2:(exact s) ltac2:(exact s) ltac2:(exact s)
  (* v1 *) 2%nat
  (* let_n *) "n"
  (* f *) (fun n => n + 1)%nat
  (* eval v1 *) _
  (* eval f *) _
  ).
  1: typeclasses_eauto.
  3,4: ltac1:(shelve).
  (* eapply auto_let with (let_n := "n"). *)
  1: eapply auto_nat_const.
  intros; cbv beta.
  eapply auto_nat_add.
  1: eapply trans_Var; eauto with fenvDb.
  eapply auto_nat_const.

  (* time relcompile. *)
Qed.