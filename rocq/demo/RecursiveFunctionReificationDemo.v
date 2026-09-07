From impboot.functional Require Import FunSyntax FunValues FunSemantics.
From impboot.imperative Require Import ImpSyntax Printing.
From impboot.automation Require Import Ltac2Utils UnfoldFix RelCompiler RelCompilerCommons AutomationLemmas.
From impboot Require Import fp2imp.FpToImpCodegen.
From impboot Require Import assembly.ASMToString.
From impboot Require Import parsing.Parser.
From Stdlib Require Import List Bool NArith ZArith String Lia.
From coqutil.Word Require Import Interface Properties.
Import ListNotations.
From Stdlib Require Import Derive.
From Ltac2 Require Import Ltac2.
From impboot.demo Require Import DemoUtils.

Fixpoint len (l: list nat): nat :=
  match l with
  | nil => 0%nat
  | _ :: l1 => 1 + len l1
  end.

Theorem len_equation: ltac:(with_strategy opaque [Nat.add] ltac2:(unfold_fix_type '@len)).
Proof. unfold_fix_proof '@len. Qed.

Print len.

Derive len_prog
  in ltac2:(relcompile_tpe 'len_prog 'len [])
  as len_prog_proof.
Proof.
  relcompile_setup ().
  revert l. ltac1:(fix IH 1); intros.
  eapply trans_app.
  3: eauto. 2: reflexivity.

  rewrite len_equation.
  eapply auto_list_case with (n1 := "h") (n2 := "t").
  3: ltac1:(shelve).
  1: eapply trans_Var; unfold make_env; eauto with fenvDb.
  destruct l.
  1: eapply auto_nat_const.
  eapply auto_nat_add.
  1: eapply auto_nat_const.
  eapply trans_Call; eauto.
  eapply trans_Var.
  unfold make_env; eauto with fenvDb.
  Unshelve.
  all: crush_side_conditions (); unfold name_enc in *; simpl in *; ltac1:(lia).
Qed.
Print len_prog.
