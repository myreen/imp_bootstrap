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

CoInductive colist (A: Type): Type :=
| conil: colist A
| cocons: A -> colist A -> colist A.

CoFixpoint encode_colist {A: Type} (l: colist A): FunValues.Value :=
  match colist with
  | conil _ => FunValues.Num 0
  | cocons _ h t => FunValues.Pair (FunValues.Num 1) (FunValues.[h; encode_colist t])
  end.

(*  *)

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

(* all: relcompile_start ().
  all: relcompile_step ().
  all: relcompile_step ().
  all: relcompile_step ().
  all: relcompile_step ().
  Unshelve.
  all: crush_side_conditions (); unfold name_enc in *; simpl in *; ltac1:(lia). *)

























(* Fixpoint even (n: nat): bool :=
  match n with
  | 0%nat => true
  | S n => negb (odd n)
  end
with odd (n: nat): bool :=
  match n with
  | 0%nat => false
  | S n => negb (even n)
  end.

Theorem even_equation: ltac2:(unfold_fix_type '@even).
Proof. unfold_fix_proof '@even. Qed.

Theorem odd_equation: ltac2:(unfold_fix_type '@odd).
Proof. unfold_fix_proof '@odd. Qed.

Ltac2 Set relcompile_one_step := false.

Derive even_prog
  in ltac2:(relcompile_tpe 'even_prog 'even ['odd])
  as even_prog_proof.
Proof.
  time relcompile.
Qed.
Print even_prog.

Derive odd_prog
  in ltac2:(relcompile_tpe 'odd_prog 'odd ['even])
  as odd_prog_proof.
Proof.
  time relcompile.
Qed.
Print odd_prog. *)
