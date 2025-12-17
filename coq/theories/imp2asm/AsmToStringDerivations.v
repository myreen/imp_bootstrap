From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.imp2asm.ImpToASMCodegen.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import commons.PrintingUtils.
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

(* *********************************************** *)
(*  Derivations for ASM to String Conversion      *)
(* *********************************************** *)

Theorem num2str_f_equation: ltac2:(unfold_fix_type 'num2str_f).
Proof. unfold_fix_proof 'num2str_f. Qed.

Theorem clean_equation: ltac2:(unfold_fix_type 'clean).
Proof. unfold_fix_proof 'clean. Qed.

Theorem instrs2str_equation: ltac2:(unfold_fix_type 'instrs2str).
Proof. unfold_fix_proof 'instrs2str. Qed.

(* Set Printing Depth 100000. *)

Derive reg2str_prog
  in ltac2:(relcompile_tpe 'reg2str_prog 'reg2str ['String.append])
  as reg2str_prog_proof.
Proof.
  time relcompile.
Qed.

Print num2str_f.
Derive num2str_f_prog
  in ltac2:(relcompile_tpe 'num2str_f_prog 'num2str_f ['nat_modulo])
  as num2str_f_prog_proof.
Proof.
  (* when fuel := 0 it compiles `10` as `S (S (... fuel))` *)
  time relcompile.
  all: specialize nat_modulo_le with (n := n) (m := 10); ltac1:(lia). 
Qed.

Derive num2str_prog
  in ltac2:(relcompile_tpe 'num2str_prog 'num2str ['num2str_f])
  as num2str_prog_proof.
Proof.
  time relcompile.
Qed.

Derive lab_prog
  in ltac2:(relcompile_tpe 'lab_prog 'lab ['num2str])
  as lab_prog_proof.
Proof.
  time relcompile.
Qed.

Derive clean_prog
  in ltac2:(relcompile_tpe 'clean_prog 'clean [])
  as clean_prog_proof.
Proof.
  time relcompile.
Qed.

Theorem append_equation: ltac2:(unfold_fix_type '@append).
Proof. unfold_fix_proof '@append. Qed.
Derive append_prog
  in ltac2:(relcompile_tpe 'append_prog 'append [])
  as append_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_prog
  in ltac2:(relcompile_tpe 'inst2str_prog 'inst2str ['reg2str; 'num2str; 'N2str; 'lab; 'clean; 'append])
  as inst2str_prog_proof.
Proof.
  time relcompile.
Qed.

Derive instrs2str_prog
  in ltac2:(relcompile_tpe 'instrs2str_prog 'instrs2str ['lab; 'inst2str])
  as instrs2str_prog_proof.
Proof.
  time relcompile.
Qed.

Theorem concat_strings_equation: ltac2:(unfold_fix_type '@concat_strings).
Proof. unfold_fix_proof '@concat_strings. Qed.
Derive concat_strings_prog
  in ltac2:(relcompile_tpe 'concat_strings_prog 'concat_strings [])
  as concat_strings_prog_proof.
Proof.
  time relcompile.
Qed.
Derive asm2str_prog
  in ltac2:(relcompile_tpe 'asm2str_prog 'asm2str ['instrs2str; 'concat_strings; 'append])
  as asm2str_prog_proof.
Proof.
  time relcompile.
Qed.
