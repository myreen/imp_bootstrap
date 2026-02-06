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

Definition f1: nat :=
  let/d n := 2%nat in
  (n + 1)%nat.

Derive f1_prog
  in ltac2:(relcompile_tpe 'f1_prog 'f1 [])
  as f1_prog_proof.
Proof.
  intros.
  subst f1_prog.
  ltac1:(match goal with
  | H: ?g = FunSyntax.Defun ?nm ?args ?body |- _ =>
    instantiate(1 := FunSyntax.Defun nm args _) in H; inversion H; clear H; subst body
  end).
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