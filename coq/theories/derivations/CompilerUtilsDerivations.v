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
From impboot.automation Require Import RelCompiler RelCompilerCommons AutomationLemmas ToANF.
From impboot.automation.ltac2 Require Import UnfoldFix.
From impboot Require Import fp2imp.FpToImpCodegen.
Require Import coqutil.Word.Interface.
Require Import ZArith.
From Stdlib Require Import FunInd.
From Stdlib Require Import derive.Derive.
From Stdlib Require Import Lia.
From Ltac2 Require Import Ltac2.

Derive nat_modulo_10_prog
  in ltac2:(relcompile_tpe 'nat_modulo_10_prog 'nat_modulo_10 ['mul_nat_10])
  as nat_modulo_10_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [nat_modulo_10_prog].

Derive N_modulo_10_prog
  in ltac2:(relcompile_tpe 'N_modulo_10_prog 'N_modulo_10 ['mul_N_10])
  as N_modulo_10_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [N_modulo_10_prog].

Derive N_modulo_256_prog
  in ltac2:(relcompile_tpe 'N_modulo_256_prog 'N_modulo_256 ['mul_N_256])
  as N_modulo_256_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [N_modulo_256_prog].

Theorem string_append_equation: ltac2:(unfold_fix_type '@string_append).
Proof. unfold_fix_proof '@string_append. Qed.
Derive string_append_prog
  in ltac2:(relcompile_tpe 'string_append_prog 'string_append [])
  as string_append_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [string_append_prog].

Theorem num2str_f_equation: ltac2:(unfold_fix_type '@num2str_f).
Proof. unfold_fix_proof '@num2str_f. Qed.

Derive num2str_f_prog
  in ltac2:(relcompile_tpe 'num2str_f_prog 'num2str_f ['nat_modulo_10])
  as num2str_f_prog_proof.
Proof.
  time relcompile.
  all: ltac1:(try lia).
  all: subst; rewrite nat_modulo_10_spec in *; specialize nat_modulo_le with (n := n) (m := 10); ltac1:(lia).
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
  in ltac2:(relcompile_tpe 'N2str_f_prog 'N2str_f ['N_modulo_10])
  as N2str_f_prog_proof.
Proof.
  time relcompile.
  all: ltac1:(try lia).
  all: rewrite ?N.ltb_lt in *; ltac1:(try lia).
  all: subst; rewrite N_modulo_10_spec in *; specialize N_modulo_le with (n := n) (m := 10%N) as ?; ltac1:(try lia).
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

Derive mul_N_10_prog
  in ltac2:(relcompile_tpe 'mul_N_10_prog 'mul_N_10 [])
  as mul_N_10_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mul_N_10_prog].

Derive mul_N_256_prog
  in ltac2:(relcompile_tpe 'mul_N_256_prog 'mul_N_256 [])
  as mul_N_256_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mul_N_256_prog].

Derive mul_nat_8_prog
  in ltac2:(relcompile_tpe 'mul_nat_8_prog 'mul_nat_8 [])
  as mul_nat_8_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mul_nat_8_prog].

Derive mul_nat_10_prog
  in ltac2:(relcompile_tpe 'mul_nat_10_prog 'mul_nat_10 [])
  as mul_nat_10_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mul_nat_10_prog].

Theorem N2ascii_f_equation: ltac2:(unfold_fix_type '@N2ascii_f).
Proof. unfold_fix_proof '@N2ascii_f. Qed.
Derive N2ascii_f_prog
  in ltac2:(relcompile_tpe 'N2ascii_f_prog 'N2ascii_f ['N_modulo_256; 'string_append])
  as N2ascii_f_prog_proof.
Proof.
  time relcompile.
  all: ltac1:(try lia).
  all: subst; rewrite N_modulo_256_spec in *; specialize N_modulo_lt with (n := n) (m := 256%N) as ?; ltac1:(try lia).
Qed.
Time Compute to_funs [N2ascii_f_prog].

Derive N2ascii_prog
  in ltac2:(relcompile_tpe 'N2ascii_prog 'N2ascii ['N2ascii_f])
  as N2ascii_prog_proof.
Proof.
  time relcompile.
  ltac1:(try lia).
Qed.
Time Compute to_funs [N2ascii_prog].

Derive N2ascii_default_prog
  in ltac2:(relcompile_tpe 'N2ascii_default_prog 'N2ascii_default ['N2ascii])
  as N2ascii_default_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [N2ascii_default_prog].

Definition CompilerUtils_funs := [
  mul_nat_8_prog;
  mul_nat_10_prog;
  mul_N_10_prog;
  mul_N_256_prog;
  nat_modulo_10_prog;
  N_modulo_10_prog;
  N_modulo_256_prog;
  num2str_f_prog;
  num2str_prog;
  N2str_f_prog;
  N2str_prog;
  list_length_prog;
  list_append_prog;
  flatten_prog;
  app_list_length_prog;
  string_append_prog;
  N2ascii_f_prog;
  N2ascii_prog;
  N2ascii_default_prog
].

Ltac2 assert_eval_app (fname: constr) :=
  let tpe := gen_eval_app fname () in
  assert ($tpe).

Ltac2 assert_eval_app_proof (prf: constr) (list_constr: constr) (n: int) :=
  eapply $prf; eauto; try (reflexivity);
  try (eapply $list_constr; do n (eapply in_cons); eapply in_eq).

Ltac2 assert_eval_app_by (fname: constr) (prf: constr) (list_constr_hyp: constr) (n: int) :=
  let tpe := gen_eval_app fname () in
  assert ($tpe) by (
    eapply $prf; eauto; try (reflexivity);
    eapply $list_constr_hyp; do n (eapply in_cons); eapply in_eq
  ).

Ltac2 assert_eval_app_compiler_utils (hlookup_constr: constr) :=
  assert_eval_app_by 'mul_nat_8 'mul_nat_8_prog_proof hlookup_constr 0;
  assert_eval_app_by 'mul_nat_10 'mul_nat_10_prog_proof hlookup_constr 1;
  assert_eval_app_by 'mul_N_10 'mul_N_10_prog_proof hlookup_constr 2;
  assert_eval_app_by 'mul_N_256 'mul_N_256_prog_proof hlookup_constr 3;
  assert_eval_app_by 'nat_modulo_10 'nat_modulo_10_prog_proof hlookup_constr 4;
  assert_eval_app_by 'N_modulo_10 'N_modulo_10_prog_proof hlookup_constr 5;
  assert_eval_app_by 'N_modulo_256 'N_modulo_256_prog_proof hlookup_constr 6;
  assert_eval_app_by 'num2str_f 'num2str_f_prog_proof hlookup_constr 7;
  assert_eval_app_by 'num2str 'num2str_prog_proof hlookup_constr 8;
  assert_eval_app_by 'N2str_f 'N2str_f_prog_proof hlookup_constr 9;
  assert_eval_app_by 'N2str 'N2str_prog_proof hlookup_constr 10;
  assert_eval_app_by '@list_length 'list_length_prog_proof hlookup_constr 11;
  assert_eval_app_by '@list_append 'list_append_prog_proof hlookup_constr 12;
  assert_eval_app_by '@flatten 'flatten_prog_proof hlookup_constr 13;
  assert_eval_app_by '@app_list_length 'app_list_length_prog_proof hlookup_constr 14;
  assert_eval_app_by 'string_append 'string_append_prog_proof hlookup_constr 15;
  assert_eval_app_by 'N2ascii_f 'N2ascii_f_prog_proof hlookup_constr 16;
  assert_eval_app_by 'N2ascii 'N2ascii_prog_proof hlookup_constr 17;
  assert_eval_app_by 'N2ascii_default 'N2ascii_default_prog_proof hlookup_constr 18.
