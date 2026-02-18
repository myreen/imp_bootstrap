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

Derive natmod10_prog
  in ltac2:(relcompile_tpe 'natmod10_prog 'natmod10 ['mulnat10])
  as natmod10_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [natmod10_prog].

Derive Nmod_10_prog
  in ltac2:(relcompile_tpe 'Nmod_10_prog 'Nmod_10 ['mulN_10])
  as Nmod_10_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [Nmod_10_prog].

Derive Nmod_256_prog
  in ltac2:(relcompile_tpe 'Nmod_256_prog 'Nmod_256 ['mulN_256])
  as Nmod_256_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [Nmod_256_prog].

Theorem str_app_equation: ltac2:(unfold_fix_type '@str_app).
Proof. unfold_fix_proof '@str_app. Qed.
Derive str_app_prog
  in ltac2:(relcompile_tpe 'str_app_prog 'str_app [])
  as str_app_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [str_app_prog].

Theorem num2strf_equation: ltac2:(unfold_fix_type '@num2strf).
Proof. unfold_fix_proof '@num2strf. Qed.

Derive num2strf_prog
  in ltac2:(relcompile_tpe 'num2strf_prog 'num2strf ['natmod10])
  as num2strf_prog_proof.
Proof.
  time relcompile.
  all: ltac1:(try lia).
  all: subst; rewrite natmod10_spec in *; specialize nat_mod_le with (n := n) (m := 10); ltac1:(lia).
Qed.
Time Compute to_funs [num2strf_prog].

Derive num2str_prog
  in ltac2:(relcompile_tpe 'num2str_prog 'num2str ['num2strf])
  as num2str_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [num2str_prog].

Theorem N2str_f_equation: ltac2:(unfold_fix_type '@N2str_f).
Proof. unfold_fix_proof '@N2str_f. Qed.

Derive N2str_f_prog
  in ltac2:(relcompile_tpe 'N2str_f_prog 'N2str_f ['Nmod_10])
  as N2str_f_prog_proof.
Proof.
  time relcompile.
  all: ltac1:(try lia).
  all: rewrite ?N.ltb_lt in *; ltac1:(try lia).
  all: subst; rewrite Nmod_10_spec in *; specialize N_modulo_le with (n := n) (m := 10%N) as ?; ltac1:(try lia).
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

Theorem list_len_equation: ltac2:(unfold_fix_type '@list_len).
Proof. unfold_fix_proof '@list_len. Qed.

Derive list_len_prog
  in ltac2:(relcompile_tpe 'list_len_prog '@list_len [])
  as list_len_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [list_len_prog].

Theorem list_app_equation: ltac2:(unfold_fix_type '@list_app).
Proof. unfold_fix_proof '@list_app. Qed.

Derive list_app_prog
  in ltac2:(relcompile_tpe 'list_app_prog '@list_app [])
  as list_app_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [list_app_prog].

Theorem flatten_equation: ltac2:(unfold_fix_type '@flatten).
Proof. unfold_fix_proof '@flatten. Qed.

Derive flatten_prog
  in ltac2:(relcompile_tpe 'flatten_prog '@flatten ['@list_app])
  as flatten_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [flatten_prog].

Theorem appl_len_equation: ltac2:(unfold_fix_type '@appl_len).
Proof. unfold_fix_proof '@appl_len. Qed.

Derive appl_len_prog
  in ltac2:(relcompile_tpe 'appl_len_prog '@appl_len ['@list_len])
  as appl_len_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [appl_len_prog].

Derive mulN_10_prog
  in ltac2:(relcompile_tpe 'mulN_10_prog 'mulN_10 [])
  as mulN_10_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mulN_10_prog].

Derive mulN_256_prog
  in ltac2:(relcompile_tpe 'mulN_256_prog 'mulN_256 [])
  as mulN_256_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mulN_256_prog].

Derive mulnat_8_prog
  in ltac2:(relcompile_tpe 'mulnat_8_prog 'mulnat_8 [])
  as mulnat_8_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mulnat_8_prog].

Derive mulnat10_prog
  in ltac2:(relcompile_tpe 'mulnat10_prog 'mulnat10 [])
  as mulnat10_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [mulnat10_prog].

Theorem N2asciif_equation: ltac2:(unfold_fix_type '@N2asciif).
Proof. unfold_fix_proof '@N2asciif. Qed.
Derive N2asciif_prog
  in ltac2:(relcompile_tpe 'N2asciif_prog 'N2asciif ['Nmod_256; 'str_app])
  as N2asciif_prog_proof.
Proof.
  time relcompile.
  all: ltac1:(try lia).
  all: subst; rewrite Nmod_256_spec in *; specialize N_modulo_lt with (n := n) (m := 256%N) as ?; ltac1:(try lia).
Qed.
Time Compute to_funs [N2asciif_prog].

Derive N2ascii_prog
  in ltac2:(relcompile_tpe 'N2ascii_prog 'N2ascii ['N2asciif])
  as N2ascii_prog_proof.
Proof.
  time relcompile.
  ltac1:(try lia).
Qed.
Time Compute to_funs [N2ascii_prog].

Derive N2asciid_prog
  in ltac2:(relcompile_tpe 'N2asciid_prog 'N2asciid ['N2ascii])
  as N2asciid_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [N2asciid_prog].

Definition CompilerUtils_funs := [
  mulnat_8_prog;
  mulnat10_prog;
  mulN_10_prog;
  mulN_256_prog;
  natmod10_prog;
  Nmod_10_prog;
  Nmod_256_prog;
  num2strf_prog;
  num2str_prog;
  N2str_f_prog;
  N2str_prog;
  list_len_prog;
  list_app_prog;
  flatten_prog;
  appl_len_prog;
  str_app_prog;
  N2asciif_prog;
  N2ascii_prog;
  N2asciid_prog
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
  assert_eval_app_by 'mulnat_8 'mulnat_8_prog_proof hlookup_constr 0;
  assert_eval_app_by 'mulnat10 'mulnat10_prog_proof hlookup_constr 1;
  assert_eval_app_by 'mulN_10 'mulN_10_prog_proof hlookup_constr 2;
  assert_eval_app_by 'mulN_256 'mulN_256_prog_proof hlookup_constr 3;
  assert_eval_app_by 'natmod10 'natmod10_prog_proof hlookup_constr 4;
  assert_eval_app_by 'Nmod_10 'Nmod_10_prog_proof hlookup_constr 5;
  assert_eval_app_by 'Nmod_256 'Nmod_256_prog_proof hlookup_constr 6;
  assert_eval_app_by 'num2strf 'num2strf_prog_proof hlookup_constr 7;
  assert_eval_app_by 'num2str 'num2str_prog_proof hlookup_constr 8;
  assert_eval_app_by 'N2str_f 'N2str_f_prog_proof hlookup_constr 9;
  assert_eval_app_by 'N2str 'N2str_prog_proof hlookup_constr 10;
  assert_eval_app_by '@list_len 'list_len_prog_proof hlookup_constr 11;
  assert_eval_app_by '@list_app 'list_app_prog_proof hlookup_constr 12;
  assert_eval_app_by '@flatten 'flatten_prog_proof hlookup_constr 13;
  assert_eval_app_by '@appl_len 'appl_len_prog_proof hlookup_constr 14;
  assert_eval_app_by 'str_app 'str_app_prog_proof hlookup_constr 15;
  assert_eval_app_by 'N2asciif 'N2asciif_prog_proof hlookup_constr 16;
  assert_eval_app_by 'N2ascii 'N2ascii_prog_proof hlookup_constr 17;
  assert_eval_app_by 'N2asciid 'N2asciid_prog_proof hlookup_constr 18.
