From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
From impboot.automation Require Import Ltac2Utils ToLowerable ToANF RelCompiler RelCompilerCommons ltac2.UnfoldFix.
From impboot.commons Require Import CompilerUtils.
From impboot.functional Require Import FunValues FunSemantics.
From impboot Require Import assembly.ASMSyntax.
From impboot Require Import fp2imp.FpToImpCodegen.
From Stdlib Require Import ZArith Lia.
From Stdlib Require Import FunInd.
From Stdlib Require Import derive.Derive.
From Ltac2 Require Import Ltac2.

From impboot Require Import derivations.CompilerUtilsDerivations.

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

Derive reg2str1_prog
  in ltac2:(relcompile_tpe 'reg2str1_prog 'reg2str1 ['string_append])
  as reg2str1_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [reg2str1_prog].

Derive lab_prog
  in ltac2:(relcompile_tpe 'lab_prog 'lab ['num2str])
  as lab_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [lab_prog].

Derive clean_prog
  in ltac2:(relcompile_tpe 'clean_prog 'clean [])
  as clean_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [clean_prog].

Derive inst2str_const_prog
  in ltac2:(relcompile_tpe 'inst2str_const_prog 'inst2str_const ['reg2str1; 'string_append; 'N2str])
  as inst2str_const_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_const_prog].

Derive inst2str_mov_prog
  in ltac2:(relcompile_tpe 'inst2str_mov_prog 'inst2str_mov ['reg2str1; 'string_append])
  as inst2str_mov_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_mov_prog].

Derive inst2str_add_prog
  in ltac2:(relcompile_tpe 'inst2str_add_prog 'inst2str_add ['reg2str1; 'string_append])
  as inst2str_add_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_add_prog].

Derive inst2str_sub_prog
  in ltac2:(relcompile_tpe 'inst2str_sub_prog 'inst2str_sub ['reg2str1; 'string_append])
  as inst2str_sub_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_sub_prog].

Derive inst2str_div_prog
  in ltac2:(relcompile_tpe 'inst2str_div_prog 'inst2str_div ['reg2str1; 'string_append])
  as inst2str_div_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_div_prog].

Derive inst2str_jump_prog
  in ltac2:(relcompile_tpe 'inst2str_jump_prog 'inst2str_jump ['reg2str1; 'string_append; 'lab])
  as inst2str_jump_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_jump_prog].

Derive inst2str_call_prog
  in ltac2:(relcompile_tpe 'inst2str_call_prog 'inst2str_call ['reg2str1; 'string_append; 'lab])
  as inst2str_call_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_call_prog].

Derive inst2str_ret_prog
  in ltac2:(relcompile_tpe 'inst2str_ret_prog 'inst2str_ret ['reg2str1; 'string_append; 'lab])
  as inst2str_ret_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_ret_prog].

Derive inst2str_pop_prog
  in ltac2:(relcompile_tpe 'inst2str_pop_prog 'inst2str_pop ['reg2str1; 'string_append; 'lab])
  as inst2str_pop_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_pop_prog].

Derive inst2str_push_prog
  in ltac2:(relcompile_tpe 'inst2str_push_prog 'inst2str_push ['reg2str1; 'string_append; 'lab])
  as inst2str_push_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_push_prog].

Derive inst2str_load_rsp_prog
  in ltac2:(relcompile_tpe 'inst2str_load_rsp_prog 'inst2str_load_rsp ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str])
  as inst2str_load_rsp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_load_rsp_prog].

Derive inst2str_store_rsp_prog
  in ltac2:(relcompile_tpe 'inst2str_store_rsp_prog 'inst2str_store_rsp ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str])
  as inst2str_store_rsp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_store_rsp_prog].

Derive inst2str_add_rsp_prog
  in ltac2:(relcompile_tpe 'inst2str_add_rsp_prog 'inst2str_add_rsp ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str])
  as inst2str_add_rsp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_add_rsp_prog].

Derive inst2str_sub_rsp_prog
  in ltac2:(relcompile_tpe 'inst2str_sub_rsp_prog 'inst2str_sub_rsp ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str])
  as inst2str_sub_rsp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_sub_rsp_prog].

Derive inst2str_store_prog
  in ltac2:(relcompile_tpe 'inst2str_store_prog 'inst2str_store ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_store_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_store_prog].

Derive inst2str_load_prog
  in ltac2:(relcompile_tpe 'inst2str_load_prog 'inst2str_load ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_load_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_load_prog].

Derive inst2str_getchar1_prog
  in ltac2:(relcompile_tpe 'inst2str_getchar1_prog 'inst2str_getchar1 ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_getchar1_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_getchar1_prog].

Derive inst2str_putchar_prog
  in ltac2:(relcompile_tpe 'inst2str_putchar_prog 'inst2str_putchar ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_putchar_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_putchar_prog].

Derive inst2str_exit_prog
  in ltac2:(relcompile_tpe 'inst2str_exit_prog 'inst2str_exit ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_exit_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_exit_prog].

Derive inst2str_comment_prog
  in ltac2:(relcompile_tpe 'inst2str_comment_prog 'inst2str_comment ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str; 'clean])
  as inst2str_comment_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [inst2str_comment_prog].

Derive inst2str_prog
  in ltac2:(relcompile_tpe 'inst2str_prog 'inst2str ['inst2str_const; 'inst2str_mov; 'inst2str_add; 'inst2str_sub; 'inst2str_div; 'inst2str_jump; 'inst2str_call; 'inst2str_ret; 'inst2str_pop; 'inst2str_push; 'inst2str_load_rsp; 'inst2str_store_rsp; 'inst2str_add_rsp; 'inst2str_sub_rsp; 'inst2str_store; 'inst2str_load; 'inst2str_getchar1; 'inst2str_putchar; 'inst2str_exit; 'inst2str_comment])
  as inst2str_prog_proof.
Proof.
  (* ltac1:(timeout 28 ltac2:(relcompile)). *)
  time relcompile.
Qed.
Time Compute to_funs [inst2str_prog].

Derive instrs2str_prog
  in ltac2:(relcompile_tpe 'instrs2str_prog 'instrs2str ['lab; 'inst2str])
  as instrs2str_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [instrs2str_prog].

Theorem concat_strings_equation: ltac2:(unfold_fix_type '@concat_strings).
Proof. unfold_fix_proof '@concat_strings. Qed.
Derive concat_strings_prog
  in ltac2:(relcompile_tpe 'concat_strings_prog 'concat_strings ['string_append])
  as concat_strings_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [concat_strings_prog].

Derive asm2str1_prog
  in ltac2:(relcompile_tpe 'asm2str1_prog 'asm2str1 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str1_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str1_prog].

Derive asm2str2_prog
  in ltac2:(relcompile_tpe 'asm2str2_prog 'asm2str2 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str2_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str2_prog].

Derive asm2str3_prog
  in ltac2:(relcompile_tpe 'asm2str3_prog 'asm2str3 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str3_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str3_prog].

Derive asm2str4_prog
  in ltac2:(relcompile_tpe 'asm2str4_prog 'asm2str4 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str4_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str4_prog].

Derive asm2str5_prog
  in ltac2:(relcompile_tpe 'asm2str5_prog 'asm2str5 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str5_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str5_prog].

Derive asm2str6_prog
  in ltac2:(relcompile_tpe 'asm2str6_prog 'asm2str6 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str6_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str6_prog].

Derive asm2str7_prog
  in ltac2:(relcompile_tpe 'asm2str7_prog 'asm2str7 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str7_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str7_prog].

Derive asm2str8_prog
  in ltac2:(relcompile_tpe 'asm2str8_prog 'asm2str8 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str8_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str8_prog].

Derive asm2str9_prog
  in ltac2:(relcompile_tpe 'asm2str9_prog 'asm2str9 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str9_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str9_prog].

Derive asm2str10_prog
  in ltac2:(relcompile_tpe 'asm2str10_prog 'asm2str10 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str10_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str10_prog].

Derive asm2str11_prog
  in ltac2:(relcompile_tpe 'asm2str11_prog 'asm2str11 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str11_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str11_prog].

Derive asm2str12_prog
  in ltac2:(relcompile_tpe 'asm2str12_prog 'asm2str12 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str12_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str12_prog].

Derive asm2str_prog
  in ltac2:(relcompile_tpe 'asm2str_prog 'asm2str
    ['instrs2str; 'concat_strings; '@list_append; 'string_append;
    'asm2str1; 'asm2str2; 'asm2str3; 'asm2str4; 'asm2str5; 'asm2str6; 'asm2str7; 'asm2str8; 'asm2str9; 'asm2str10; 'asm2str11; 'asm2str12])
  as asm2str_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str_prog].

Definition ASMToString_funs := [
  reg2str1_prog;
  lab_prog;
  clean_prog;
  inst2str_const_prog;
  inst2str_mov_prog;
  inst2str_add_prog;
  inst2str_sub_prog;
  inst2str_div_prog;
  inst2str_jump_prog;
  inst2str_call_prog;
  inst2str_ret_prog;
  inst2str_pop_prog;
  inst2str_push_prog;
  inst2str_load_rsp_prog;
  inst2str_store_rsp_prog;
  inst2str_add_rsp_prog;
  inst2str_sub_rsp_prog;
  inst2str_store_prog;
  inst2str_load_prog;
  inst2str_getchar1_prog;
  inst2str_putchar_prog;
  inst2str_exit_prog;
  inst2str_comment_prog;
  inst2str_prog;
  instrs2str_prog;
  concat_strings_prog;
  asm2str1_prog;
  asm2str2_prog;
  asm2str3_prog;
  asm2str4_prog;
  asm2str5_prog;
  asm2str6_prog;
  asm2str7_prog;
  asm2str8_prog;
  asm2str9_prog;
  asm2str10_prog;
  asm2str11_prog;
  asm2str12_prog;
  asm2str_prog
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

Theorem asm2str_thm:
  ∀ (s: state) (p: asm),
    (∀ fname args fn,
      In (FunSyntax.Defun fname args fn) (CompilerUtils_funs) →
      lookup_fun fname (funs s) = Some (args, fn)) ->
    (∀ fname args fn,
      In (FunSyntax.Defun fname args fn) (ASMToString_funs) →
      lookup_fun fname (funs s) = Some (args, fn)) ->
    eval_app (name_enc "asm2str") [encode p] s ((encode (asm2str p)), s).
Proof.
  intros * Hlookup_fun_utils Hlookup_fun.
  assert_eval_app_by 'mul_nat 'mul_nat_prog_proof 'Hlookup_fun_utils 0.
  assert_eval_app_by 'mul_N_f 'mul_N_f_prog_proof 'Hlookup_fun_utils 1.
  assert_eval_app_by 'mul_N 'mul_N_prog_proof 'Hlookup_fun_utils 2.
  assert_eval_app_by 'nat_modulo 'nat_modulo_prog_proof 'Hlookup_fun_utils 3.
  assert_eval_app_by 'N_modulo 'N_modulo_prog_proof 'Hlookup_fun_utils 4.
  assert_eval_app_by 'num2str_f 'num2str_f_prog_proof 'Hlookup_fun_utils 5.
  assert_eval_app_by 'num2str 'num2str_prog_proof 'Hlookup_fun_utils 6.
  assert_eval_app_by 'N2str_f 'N2str_f_prog_proof 'Hlookup_fun_utils 7.
  assert_eval_app_by 'N2str 'N2str_prog_proof 'Hlookup_fun_utils 8.
  assert_eval_app_by '@list_length 'list_length_prog_proof 'Hlookup_fun_utils 9.
  assert_eval_app_by '@list_append 'list_append_prog_proof 'Hlookup_fun_utils 10.
  assert_eval_app_by '@flatten 'flatten_prog_proof 'Hlookup_fun_utils 11.
  assert_eval_app_by '@app_list_length 'app_list_length_prog_proof 'Hlookup_fun_utils 12.
  assert_eval_app_by 'string_append 'string_append_prog_proof 'Hlookup_fun_utils 13.

  assert_eval_app_by 'reg2str1 'reg2str1_prog_proof 'Hlookup_fun 0.
  assert_eval_app_by 'lab 'lab_prog_proof 'Hlookup_fun 1.
  assert_eval_app_by 'clean 'clean_prog_proof 'Hlookup_fun 2.
  assert_eval_app_by 'inst2str_const 'inst2str_const_prog_proof 'Hlookup_fun 3.
  assert_eval_app_by 'inst2str_mov 'inst2str_mov_prog_proof 'Hlookup_fun 4.
  assert_eval_app_by 'inst2str_add 'inst2str_add_prog_proof 'Hlookup_fun 5.
  assert_eval_app_by 'inst2str_sub 'inst2str_sub_prog_proof 'Hlookup_fun 6.
  assert_eval_app_by 'inst2str_div 'inst2str_div_prog_proof 'Hlookup_fun 7.
  assert_eval_app_by 'inst2str_jump 'inst2str_jump_prog_proof 'Hlookup_fun 8.
  assert_eval_app_by 'inst2str_call 'inst2str_call_prog_proof 'Hlookup_fun 9.
  assert_eval_app_by 'inst2str_ret 'inst2str_ret_prog_proof 'Hlookup_fun 10.
  assert_eval_app_by 'inst2str_pop 'inst2str_pop_prog_proof 'Hlookup_fun 11.
  assert_eval_app_by 'inst2str_push 'inst2str_push_prog_proof 'Hlookup_fun 12.
  assert_eval_app_by 'inst2str_load_rsp 'inst2str_load_rsp_prog_proof 'Hlookup_fun 13.
  assert_eval_app_by 'inst2str_store_rsp 'inst2str_store_rsp_prog_proof 'Hlookup_fun 14.
  assert_eval_app_by 'inst2str_add_rsp 'inst2str_add_rsp_prog_proof 'Hlookup_fun 15.
  assert_eval_app_by 'inst2str_sub_rsp 'inst2str_sub_rsp_prog_proof 'Hlookup_fun 16.
  assert_eval_app_by 'inst2str_store 'inst2str_store_prog_proof 'Hlookup_fun 17.
  assert_eval_app_by 'inst2str_load 'inst2str_load_prog_proof 'Hlookup_fun 18.
  assert_eval_app_by 'inst2str_getchar1 'inst2str_getchar1_prog_proof 'Hlookup_fun 19.
  assert_eval_app_by 'inst2str_putchar 'inst2str_putchar_prog_proof 'Hlookup_fun 20.
  assert_eval_app_by 'inst2str_exit 'inst2str_exit_prog_proof 'Hlookup_fun 21.
  assert_eval_app_by 'inst2str_comment 'inst2str_comment_prog_proof 'Hlookup_fun 22.
  assert_eval_app_by 'inst2str 'inst2str_prog_proof 'Hlookup_fun 23.
  assert_eval_app_by 'instrs2str 'instrs2str_prog_proof 'Hlookup_fun 24.
  assert_eval_app_by 'concat_strings 'concat_strings_prog_proof 'Hlookup_fun 25.
  assert_eval_app_by 'asm2str1 'asm2str1_prog_proof 'Hlookup_fun 26.
  assert_eval_app_by 'asm2str2 'asm2str2_prog_proof 'Hlookup_fun 27.
  assert_eval_app_by 'asm2str3 'asm2str3_prog_proof 'Hlookup_fun 28.
  assert_eval_app_by 'asm2str4 'asm2str4_prog_proof 'Hlookup_fun 29.
  assert_eval_app_by 'asm2str5 'asm2str5_prog_proof 'Hlookup_fun 30.
  assert_eval_app_by 'asm2str6 'asm2str6_prog_proof 'Hlookup_fun 31.
  assert_eval_app_by 'asm2str7 'asm2str7_prog_proof 'Hlookup_fun 32.
  assert_eval_app_by 'asm2str8 'asm2str8_prog_proof 'Hlookup_fun 33.
  assert_eval_app_by 'asm2str9 'asm2str9_prog_proof 'Hlookup_fun 34.
  assert_eval_app_by 'asm2str10 'asm2str10_prog_proof 'Hlookup_fun 35.
  assert_eval_app_by 'asm2str11 'asm2str11_prog_proof 'Hlookup_fun 36.
  assert_eval_app_by 'asm2str12 'asm2str12_prog_proof 'Hlookup_fun 37.
  assert_eval_app_by 'asm2str 'asm2str_prog_proof 'Hlookup_fun 38.
  eauto.
Qed.
