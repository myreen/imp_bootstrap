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

Fixpoint sum (n: nat): nat :=
  match n with
  | 0%nat => 0%nat
  | S n' => n + sum n'
  end.

Theorem sum_equation: ltac2:(unfold_fix_type '@sum).
Proof. unfold_fix_proof '@sum. Qed.

Derive sum_prog
  in ltac2:(relcompile_tpe 'sum_prog 'sum [])
  as sum_prog_proof.
Proof.
  intros * prog_eq * Hlookup.
  subst sum_prog.
  ltac1:(match goal with
  | H: ?g = FunSyntax.Defun ?nm ?args ?body |- _ =>
    instantiate(1 := FunSyntax.Defun nm args _) in H; inversion H; clear H; subst body
  end).
  ltac1:(fix IH 1).
  intros.
  rewrite sum_equation.
  eapply trans_app.
  3: eauto.
  2: reflexivity.
  refine open_constr:(auto_nat_case
  (* env *) ltac2:(eauto)
  (* s *) s
  (* x0 x1 x2 *) _ _ _
  (* name *) "n1"
  (* v0 *) n
  (* v1 *) 0%nat
  (* v2 *) (fun n => (S n + sum n)%nat)
  (* eval v0 *) _
  (* eval v1 *) _
  ).
  3,4,5: ltac1:(shelve).
  1: eapply trans_Var.
  1: unfold make_env; eauto with fenvDb.
  destruct n.
  1: eapply auto_nat_const.
  eapply auto_nat_add.
  1: eapply auto_nat_succ.
  1: eapply trans_Var.
  1: unfold make_env; eauto with fenvDb.
  eapply trans_Call.
  2: eauto.
  eapply trans_Var.
  1: unfold make_env; eauto with fenvDb.
  (* time relcompile. *)
Qed.
