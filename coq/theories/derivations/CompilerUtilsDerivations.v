From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.commons.CompilerUtils.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import commons.CompilerUtils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
Require Import impboot.automation.RelCompiler.
Require Import impboot.automation.ltac2.UnfoldFix.
Require Import impboot.automation.AutomationLemmas.
From impboot Require Import fp2imp.FpToImpCodegen.
Require Import coqutil.Word.Interface.
Require Import ZArith.
From Stdlib Require Import FunInd.
From Stdlib Require Import derive.Derive.
From Stdlib Require Import Lia.
From Ltac2 Require Import Ltac2.

Derive nat_modulo_prog
  in ltac2:(relcompile_tpe 'nat_modulo_prog 'nat_modulo ['mul_nat]) 
  as nat_modulo_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [nat_modulo_prog].

Derive N_modulo_prog
  in ltac2:(relcompile_tpe 'N_modulo_prog 'N_modulo ['mul_N]) 
  as N_modulo_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [nat_modulo_prog].

Theorem string_append_equation: ltac2:(unfold_fix_type '@string_append).
Proof. unfold_fix_proof '@string_append. Qed.
Derive string_append_prog
  in ltac2:(relcompile_tpe 'string_append_prog 'string_append [])
  as string_append_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [nat_modulo_prog].

Theorem num2str_f_equation: ltac2:(unfold_fix_type '@num2str_f).
Proof. unfold_fix_proof '@num2str_f. Qed.

Derive num2str_f_prog
  in ltac2:(relcompile_tpe 'num2str_f_prog 'num2str_f ['nat_modulo])
  as num2str_f_prog_proof.
Proof.
  time relcompile.
  all: ltac1:(try lia).
  all: subst; specialize nat_modulo_le with (n := n) (m := 10); ltac1:(lia).
Qed.
Time Compute to_funs [num2str_f_prog].

Derive num2str_prog
  in ltac2:(relcompile_tpe 'num2str_prog 'num2str ['num2str_f])
  as num2str_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [num2str_prog].

Theorem N2str_f_equation: ltac2:(unfold_fix_type '@N2str_f).
Proof. unfold_fix_proof '@N2str_f. Qed.

Derive N2str_f_prog
  in ltac2:(relcompile_tpe 'N2str_f_prog 'N2str_f ['N_modulo])
  as N2str_f_prog_proof.
Proof.
  time relcompile.
  all: ltac1:(try lia).
  all: rewrite ?N.ltb_lt in *; ltac1:(try lia).
  all: subst; specialize N_modulo_le with (n := n) (m := 10%N) as ?; ltac1:(try lia).
Qed.
Time Compute to_funs [N2str_f_prog].

Derive N2str_prog
  in ltac2:(relcompile_tpe 'N2str_prog 'N2str ['N2str_f])
  as N2str_prog_proof.
Proof.
  time relcompile.
  ltac1:(try lia).
Qed.
Time Compute to_funs [N2str_prog].

Theorem list_length_equation: ltac2:(unfold_fix_type '@list_length).
Proof. unfold_fix_proof '@list_length. Qed.

Derive list_length_prog
  in ltac2:(relcompile_tpe 'list_length_prog '@list_length [])
  as list_length_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [list_length_prog].

Theorem list_append_equation: ltac2:(unfold_fix_type '@list_append).
Proof. unfold_fix_proof '@list_append. Qed.

Derive list_append_prog
  in ltac2:(relcompile_tpe 'list_append_prog '@list_append [])
  as list_append_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [list_append_prog].

Theorem flatten_equation: ltac2:(unfold_fix_type '@flatten).
Proof. unfold_fix_proof '@flatten. Qed.

Derive flatten_prog
  in ltac2:(relcompile_tpe 'flatten_prog '@flatten ['@list_append])
  as flatten_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [flatten_prog].

Theorem app_list_length_equation: ltac2:(unfold_fix_type '@app_list_length).
Proof. unfold_fix_proof '@app_list_length. Qed.

Derive app_list_length_prog
  in ltac2:(relcompile_tpe 'app_list_length_prog '@app_list_length ['@list_length])
  as app_list_length_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [app_list_length_prog].

Theorem mul_nat_equation: ltac2:(unfold_fix_type '@mul_nat).
Proof. unfold_fix_proof '@mul_nat. Qed.
Derive mul_nat_prog
  in ltac2:(relcompile_tpe 'mul_nat_prog 'mul_nat [])
  as mul_nat_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mul_nat_prog].

Theorem mul_N_f_equation: ltac2:(unfold_fix_type '@mul_N_f).
Proof. unfold_fix_proof '@mul_N_f. Qed.
Derive mul_N_f_prog
  in ltac2:(relcompile_tpe 'mul_N_f_prog 'mul_N_f [])
  as mul_N_f_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mul_N_f_prog].

Derive mul_N_prog
  in ltac2:(relcompile_tpe 'mul_N_prog 'mul_N ['mul_N_f])
  as mul_N_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mul_N_prog].

Definition CompilerUtils_funs := [
  mul_nat_prog;
  mul_N_f_prog;
  mul_N_prog;
  nat_modulo_prog;
  N_modulo_prog;
  num2str_f_prog;
  num2str_prog;
  N2str_f_prog;
  N2str_prog;
  list_length_prog;
  list_append_prog;
  flatten_prog;
  app_list_length_prog;
  string_append_prog
].
