From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
From impboot.automation Require Import Ltac2Utils ToLowerable ToANF RelCompiler RelCompilerCommons ltac2.UnfoldFix.
From impboot.automation.ltac2 Require Import Stdlib2.
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

Theorem num2strf_equation: ltac2:(unfold_fix_type 'num2strf).
Proof. unfold_fix_proof 'num2strf. Qed.

Theorem clean_equation: ltac2:(unfold_fix_type 'clean).
Proof. unfold_fix_proof 'clean. Qed.

Theorem is2str_equation: ltac2:(unfold_fix_type 'is2str).
Proof. unfold_fix_proof 'is2str. Qed.

(* Set Printing Depth 100000. *)

Derive reg2s_prog
  in ltac2:(relcompile_tpe 'reg2s_prog 'reg2s ['str_app])
  as reg2s_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [reg2s_prog].
Ltac2 Eval assert_Some constr:(to_funs [reg2s_prog]).

Derive lab_prog
  in ltac2:(relcompile_tpe 'lab_prog 'lab ['num2str])
  as lab_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [lab_prog].
Ltac2 Eval assert_Some constr:(to_funs [lab_prog]).

Derive clean_prog
  in ltac2:(relcompile_tpe 'clean_prog 'clean [])
  as clean_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [clean_prog].
Ltac2 Eval assert_Some constr:(to_funs [clean_prog]).

Derive i2s_con_prog
  in ltac2:(relcompile_tpe 'i2s_con_prog 'i2s_con ['reg2s; 'str_app; 'N2str])
  as i2s_con_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_con_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_con_prog]).

Derive i2s_mov_prog
  in ltac2:(relcompile_tpe 'i2s_mov_prog 'i2s_mov ['reg2s; 'str_app])
  as i2s_mov_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_mov_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_mov_prog]).

Derive i2s_add_prog
  in ltac2:(relcompile_tpe 'i2s_add_prog 'i2s_add ['reg2s; 'str_app])
  as i2s_add_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_add_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_add_prog]).

Derive i2s_sub_prog
  in ltac2:(relcompile_tpe 'i2s_sub_prog 'i2s_sub ['reg2s; 'str_app])
  as i2s_sub_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_sub_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_sub_prog]).

Derive i2s_div_prog
  in ltac2:(relcompile_tpe 'i2s_div_prog 'i2s_div ['reg2s; 'str_app])
  as i2s_div_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_div_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_div_prog]).

Derive i2s_jump_prog
  in ltac2:(relcompile_tpe 'i2s_jump_prog 'i2s_jump ['reg2s; 'str_app; 'lab])
  as i2s_jump_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_jump_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_jump_prog]).

Derive i2s_call_prog
  in ltac2:(relcompile_tpe 'i2s_call_prog 'i2s_call ['reg2s; 'str_app; 'lab])
  as i2s_call_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_call_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_call_prog]).

Derive i2s_ret_prog
  in ltac2:(relcompile_tpe 'i2s_ret_prog 'i2s_ret ['reg2s; 'str_app; 'lab])
  as i2s_ret_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_ret_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_ret_prog]).

Derive i2s_pop_prog
  in ltac2:(relcompile_tpe 'i2s_pop_prog 'i2s_pop ['reg2s; 'str_app; 'lab])
  as i2s_pop_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_pop_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_pop_prog]).

Derive i2s_push_prog
  in ltac2:(relcompile_tpe 'i2s_push_prog 'i2s_push ['reg2s; 'str_app; 'lab])
  as i2s_push_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_push_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_push_prog]).

Derive i2s_lrsp_prog
  in ltac2:(relcompile_tpe 'i2s_lrsp_prog 'i2s_lrsp ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str])
  as i2s_lrsp_prog_proof.
Proof.
  time relcompile.
Qed.
Print i2s_lrsp_prog.
Time Compute to_funs [i2s_lrsp_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_lrsp_prog]).

Derive i2s_srsp_prog
  in ltac2:(relcompile_tpe 'i2s_srsp_prog 'i2s_srsp ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str])
  as i2s_srsp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_srsp_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_srsp_prog]).

Derive i2s_arsp_prog
  in ltac2:(relcompile_tpe 'i2s_arsp_prog 'i2s_arsp ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str])
  as i2s_arsp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_arsp_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_arsp_prog]).

Derive i2s_surs_prog
  in ltac2:(relcompile_tpe 'i2s_surs_prog 'i2s_surs ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str])
  as i2s_surs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_surs_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_surs_prog]).

Derive i2s_stor_prog
  in ltac2:(relcompile_tpe 'i2s_stor_prog 'i2s_stor ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str; 'N2str])
  as i2s_stor_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_stor_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_stor_prog]).

Derive i2s_load_prog
  in ltac2:(relcompile_tpe 'i2s_load_prog 'i2s_load ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str; 'N2str])
  as i2s_load_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_load_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_load_prog]).

Derive i2s_gch_prog
  in ltac2:(relcompile_tpe 'i2s_gch_prog 'i2s_gch ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str; 'N2str])
  as i2s_gch_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_gch_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_gch_prog]).

Derive i2s_pch_prog
  in ltac2:(relcompile_tpe 'i2s_pch_prog 'i2s_pch ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str; 'N2str])
  as i2s_pch_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_pch_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_pch_prog]).

Derive i2s_exit_prog
  in ltac2:(relcompile_tpe 'i2s_exit_prog 'i2s_exit ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str; 'N2str])
  as i2s_exit_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_exit_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_exit_prog]).

Derive i2s_comm_prog
  in ltac2:(relcompile_tpe 'i2s_comm_prog 'i2s_comm ['reg2s; 'str_app; 'lab; 'mulnat_8; 'num2str; 'N2str; 'clean])
  as i2s_comm_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [i2s_comm_prog].
Ltac2 Eval assert_Some constr:(to_funs [i2s_comm_prog]).

Derive inst2str_prog
  in ltac2:(relcompile_tpe 'inst2str_prog 'inst2str ['i2s_con; 'i2s_mov; 'i2s_add; 'i2s_sub; 'i2s_div; 'i2s_jump; 'i2s_call; 'i2s_ret; 'i2s_pop; 'i2s_push; 'i2s_lrsp; 'i2s_srsp; 'i2s_arsp; 'i2s_surs; 'i2s_stor; 'i2s_load; 'i2s_gch; 'i2s_pch; 'i2s_exit; 'i2s_comm])
  as inst2str_prog_proof.
Proof.
  (* ltac1:(timeout 28 ltac2:(relcompile)). *)
  time relcompile.
Qed.
Time Compute to_funs [inst2str_prog].
Ltac2 Eval assert_Some constr:(to_funs [inst2str_prog]).

Derive is2str_prog
  in ltac2:(relcompile_tpe 'is2str_prog 'is2str ['lab; 'inst2str])
  as is2str_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [is2str_prog].
Ltac2 Eval assert_Some constr:(to_funs [is2str_prog]).

Theorem ccat_str_equation: ltac2:(unfold_fix_type '@ccat_str).
Proof. unfold_fix_proof '@ccat_str. Qed.
Derive ccat_str_prog
  in ltac2:(relcompile_tpe 'ccat_str_prog 'ccat_str ['str_app])
  as ccat_str_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [ccat_str_prog].
Ltac2 Eval assert_Some constr:(to_funs [ccat_str_prog]).

Derive asm2str1_prog
  in ltac2:(relcompile_tpe 'asm2str1_prog 'asm2str1 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str1_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str1_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str1_prog]).

Derive asm2str2_prog
  in ltac2:(relcompile_tpe 'asm2str2_prog 'asm2str2 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str2_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str2_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str2_prog]).

Derive asm2str3_prog
  in ltac2:(relcompile_tpe 'asm2str3_prog 'asm2str3 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str3_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str3_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str3_prog]).

Derive asm2str4_prog
  in ltac2:(relcompile_tpe 'asm2str4_prog 'asm2str4 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str4_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str4_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str4_prog]).

Derive asm2str5_prog
  in ltac2:(relcompile_tpe 'asm2str5_prog 'asm2str5 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str5_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str5_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str5_prog]).

Derive asm2str6_prog
  in ltac2:(relcompile_tpe 'asm2str6_prog 'asm2str6 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str6_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str6_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str6_prog]).

Derive asm2str7_prog
  in ltac2:(relcompile_tpe 'asm2str7_prog 'asm2str7 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str7_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str7_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str7_prog]).

Derive asm2str8_prog
  in ltac2:(relcompile_tpe 'asm2str8_prog 'asm2str8 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str8_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str8_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str8_prog]).

Derive asm2str9_prog
  in ltac2:(relcompile_tpe 'asm2str9_prog 'asm2str9 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str9_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str9_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str9_prog]).

Derive asm2str0_prog
  in ltac2:(relcompile_tpe 'asm2str0_prog 'asm2str0 ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2str0_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str0_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str0_prog]).

Derive asm2stra_prog
  in ltac2:(relcompile_tpe 'asm2stra_prog 'asm2stra ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2stra_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2stra_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2stra_prog]).

Derive asm2strb_prog
  in ltac2:(relcompile_tpe 'asm2strb_prog 'asm2strb ['is2str; 'ccat_str; '@list_app; 'str_app])
  as asm2strb_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2strb_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2strb_prog]).

(* TODO: ToANF lifts out list literals *)
Derive asm2str_prog
  in ltac2:(relcompile_tpe 'asm2str_prog 'asm2str
    ['is2str; 'ccat_str; '@list_app; 'str_app;
    'asm2str1; 'asm2str2; 'asm2str3; 'asm2str4; 'asm2str5; 'asm2str6; 'asm2str7; 'asm2str8; 'asm2str9; 'asm2str0; 'asm2stra; 'asm2strb])
  as asm2str_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [asm2str_prog].
Ltac2 Eval assert_Some constr:(to_funs [asm2str_prog]).

Definition ASMToString_funs := [
  reg2s_prog;
  lab_prog;
  clean_prog;
  i2s_con_prog;
  i2s_mov_prog;
  i2s_add_prog;
  i2s_sub_prog;
  i2s_div_prog;
  i2s_jump_prog;
  i2s_call_prog;
  i2s_ret_prog;
  i2s_pop_prog;
  i2s_push_prog;
  i2s_lrsp_prog;
  i2s_srsp_prog;
  i2s_arsp_prog;
  i2s_surs_prog;
  i2s_stor_prog;
  i2s_load_prog;
  i2s_gch_prog;
  i2s_pch_prog;
  i2s_exit_prog;
  i2s_comm_prog;
  inst2str_prog;
  is2str_prog;
  ccat_str_prog;
  asm2str1_prog;
  asm2str2_prog;
  asm2str3_prog;
  asm2str4_prog;
  asm2str5_prog;
  asm2str6_prog;
  asm2str7_prog;
  asm2str8_prog;
  asm2str9_prog;
  asm2str0_prog;
  asm2stra_prog;
  asm2strb_prog;
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
  assert_eval_app_compiler_utils 'Hlookup_fun_utils.

  assert_eval_app_by 'reg2s 'reg2s_prog_proof 'Hlookup_fun 0.
  assert_eval_app_by 'lab 'lab_prog_proof 'Hlookup_fun 1.
  assert_eval_app_by 'clean 'clean_prog_proof 'Hlookup_fun 2.
  assert_eval_app_by 'i2s_con 'i2s_con_prog_proof 'Hlookup_fun 3.
  assert_eval_app_by 'i2s_mov 'i2s_mov_prog_proof 'Hlookup_fun 4.
  assert_eval_app_by 'i2s_add 'i2s_add_prog_proof 'Hlookup_fun 5.
  assert_eval_app_by 'i2s_sub 'i2s_sub_prog_proof 'Hlookup_fun 6.
  assert_eval_app_by 'i2s_div 'i2s_div_prog_proof 'Hlookup_fun 7.
  assert_eval_app_by 'i2s_jump 'i2s_jump_prog_proof 'Hlookup_fun 8.
  assert_eval_app_by 'i2s_call 'i2s_call_prog_proof 'Hlookup_fun 9.
  assert_eval_app_by 'i2s_ret 'i2s_ret_prog_proof 'Hlookup_fun 10.
  assert_eval_app_by 'i2s_pop 'i2s_pop_prog_proof 'Hlookup_fun 11.
  assert_eval_app_by 'i2s_push 'i2s_push_prog_proof 'Hlookup_fun 12.
  assert_eval_app_by 'i2s_lrsp 'i2s_lrsp_prog_proof 'Hlookup_fun 13.
  assert_eval_app_by 'i2s_srsp 'i2s_srsp_prog_proof 'Hlookup_fun 14.
  assert_eval_app_by 'i2s_arsp 'i2s_arsp_prog_proof 'Hlookup_fun 15.
  assert_eval_app_by 'i2s_surs 'i2s_surs_prog_proof 'Hlookup_fun 16.
  assert_eval_app_by 'i2s_stor 'i2s_stor_prog_proof 'Hlookup_fun 17.
  assert_eval_app_by 'i2s_load 'i2s_load_prog_proof 'Hlookup_fun 18.
  assert_eval_app_by 'i2s_gch 'i2s_gch_prog_proof 'Hlookup_fun 19.
  assert_eval_app_by 'i2s_pch 'i2s_pch_prog_proof 'Hlookup_fun 20.
  assert_eval_app_by 'i2s_exit 'i2s_exit_prog_proof 'Hlookup_fun 21.
  assert_eval_app_by 'i2s_comm 'i2s_comm_prog_proof 'Hlookup_fun 22.
  assert_eval_app_by 'inst2str 'inst2str_prog_proof 'Hlookup_fun 23.
  assert_eval_app_by 'is2str 'is2str_prog_proof 'Hlookup_fun 24.
  assert_eval_app_by 'ccat_str 'ccat_str_prog_proof 'Hlookup_fun 25.
  assert_eval_app_by 'asm2str1 'asm2str1_prog_proof 'Hlookup_fun 26.
  assert_eval_app_by 'asm2str2 'asm2str2_prog_proof 'Hlookup_fun 27.
  assert_eval_app_by 'asm2str3 'asm2str3_prog_proof 'Hlookup_fun 28.
  assert_eval_app_by 'asm2str4 'asm2str4_prog_proof 'Hlookup_fun 29.
  assert_eval_app_by 'asm2str5 'asm2str5_prog_proof 'Hlookup_fun 30.
  assert_eval_app_by 'asm2str6 'asm2str6_prog_proof 'Hlookup_fun 31.
  assert_eval_app_by 'asm2str7 'asm2str7_prog_proof 'Hlookup_fun 32.
  assert_eval_app_by 'asm2str8 'asm2str8_prog_proof 'Hlookup_fun 33.
  assert_eval_app_by 'asm2str9 'asm2str9_prog_proof 'Hlookup_fun 34.
  assert_eval_app_by 'asm2str0 'asm2str0_prog_proof 'Hlookup_fun 35.
  assert_eval_app_by 'asm2stra 'asm2stra_prog_proof 'Hlookup_fun 36.
  assert_eval_app_by 'asm2strb 'asm2strb_prog_proof 'Hlookup_fun 37.
  assert_eval_app_by 'asm2str 'asm2str_prog_proof 'Hlookup_fun 38.
  eauto.
Qed.
