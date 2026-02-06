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
Require Import impboot.utils.Core.
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

Open Scope nat.

Definition nat_modulo1 (n1 n2: nat): nat :=
  match n2 with
  | 0%nat => 0
  | S _ => n1 - n2 * (n1 / n2)
  end.

Remark gcd_oblig:
  forall (a b: nat) (NE: b <> 0), nat_modulo1 a b < b.
Proof.
Admitted.

Function gcd (a b: nat) (ACC: Acc lt b) {struct ACC}: nat :=
  match Nat.eq_dec b 0 with
  | left EQ => a
  | right NE =>
    gcd b (nat_modulo1 a b) (Acc_inv ACC (gcd_oblig a b NE))
  end.

Derive gcd_prog
  in ltac2:(relcompile_tpe 'gcd_prog 'gcd ['nat_modulo1])
  as gcd_prog_proof.
Proof.
  time relcompile.
Qed.
