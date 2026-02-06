From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.imp2asm.ImpToASMCodegen.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import commons.CompilerUtils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
From impboot Require Import assembly.ASMSyntax.
Require Import impboot.automation.RelCompiler.
Require Import impboot.automation.ltac2.UnfoldFix.
Require Import impboot.automation.AutomationLemmas.
Require Import coqutil.Word.Interface.
Require Import ZArith.
From Stdlib Require Import FunInd.
From Stdlib Require Import derive.Derive.
From Stdlib Require Import Lia.
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

Derive inst2str_const_prog
  in ltac2:(relcompile_tpe 'inst2str_const_prog 'inst2str_const ['reg2str1; 'string_append; 'N2str])
  as inst2str_const_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_mov_prog
  in ltac2:(relcompile_tpe 'inst2str_mov_prog 'inst2str_mov ['reg2str1; 'string_append])
  as inst2str_mov_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_add_prog
  in ltac2:(relcompile_tpe 'inst2str_add_prog 'inst2str_add ['reg2str1; 'string_append])
  as inst2str_add_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_sub_prog
  in ltac2:(relcompile_tpe 'inst2str_sub_prog 'inst2str_sub ['reg2str1; 'string_append])
  as inst2str_sub_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_div_prog
  in ltac2:(relcompile_tpe 'inst2str_div_prog 'inst2str_div ['reg2str1; 'string_append])
  as inst2str_div_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_jump_always_prog
  in ltac2:(relcompile_tpe 'inst2str_jump_always_prog 'inst2str_jump_always ['reg2str1; 'string_append; 'lab])
  as inst2str_jump_always_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_jump_equal_prog
  in ltac2:(relcompile_tpe 'inst2str_jump_equal_prog 'inst2str_jump_equal ['reg2str1; 'string_append; 'lab])
  as inst2str_jump_equal_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_jump_less_prog
  in ltac2:(relcompile_tpe 'inst2str_jump_less_prog 'inst2str_jump_less ['reg2str1; 'string_append; 'lab])
  as inst2str_jump_less_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_call_prog
  in ltac2:(relcompile_tpe 'inst2str_call_prog 'inst2str_call ['reg2str1; 'string_append; 'lab])
  as inst2str_call_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_ret_prog
  in ltac2:(relcompile_tpe 'inst2str_ret_prog 'inst2str_ret ['reg2str1; 'string_append; 'lab])
  as inst2str_ret_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_pop_prog
  in ltac2:(relcompile_tpe 'inst2str_pop_prog 'inst2str_pop ['reg2str1; 'string_append; 'lab])
  as inst2str_pop_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_push_prog
  in ltac2:(relcompile_tpe 'inst2str_push_prog 'inst2str_push ['reg2str1; 'string_append; 'lab])
  as inst2str_push_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_load_rsp_prog
  in ltac2:(relcompile_tpe 'inst2str_load_rsp_prog 'inst2str_load_rsp ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str])
  as inst2str_load_rsp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_store_rsp_prog
  in ltac2:(relcompile_tpe 'inst2str_store_rsp_prog 'inst2str_store_rsp ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str])
  as inst2str_store_rsp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_add_rsp_prog
  in ltac2:(relcompile_tpe 'inst2str_add_rsp_prog 'inst2str_add_rsp ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str])
  as inst2str_add_rsp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_sub_rsp_prog
  in ltac2:(relcompile_tpe 'inst2str_sub_rsp_prog 'inst2str_sub_rsp ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str])
  as inst2str_sub_rsp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_store_prog
  in ltac2:(relcompile_tpe 'inst2str_store_prog 'inst2str_store ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_store_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_load_prog
  in ltac2:(relcompile_tpe 'inst2str_load_prog 'inst2str_load ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_load_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_getchar1_prog
  in ltac2:(relcompile_tpe 'inst2str_getchar1_prog 'inst2str_getchar1 ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_getchar1_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_putchar_prog
  in ltac2:(relcompile_tpe 'inst2str_putchar_prog 'inst2str_putchar ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_putchar_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_exit_prog
  in ltac2:(relcompile_tpe 'inst2str_exit_prog 'inst2str_exit ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str])
  as inst2str_exit_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_comment_prog
  in ltac2:(relcompile_tpe 'inst2str_comment_prog 'inst2str_comment ['reg2str1; 'string_append; 'lab; 'mul_nat; 'num2str; 'N2str; 'clean])
  as inst2str_comment_prog_proof.
Proof.
  time relcompile.
Qed.

Derive inst2str_prog
  in ltac2:(relcompile_tpe 'inst2str_prog 'inst2str ['inst2str_const; 'inst2str_mov; 'inst2str_add; 'inst2str_sub; 'inst2str_div; 'inst2str_jump_always; 'inst2str_jump_equal; 'inst2str_jump_less; 'inst2str_call; 'inst2str_ret; 'inst2str_pop; 'inst2str_push; 'inst2str_load_rsp; 'inst2str_store_rsp; 'inst2str_add_rsp; 'inst2str_sub_rsp; 'inst2str_store; 'inst2str_load; 'inst2str_getchar1; 'inst2str_putchar; 'inst2str_exit; 'inst2str_comment])
  as inst2str_prog_proof.
Proof.
  (* ltac1:(timeout 28 ltac2:(relcompile)). *)
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
  in ltac2:(relcompile_tpe 'concat_strings_prog 'concat_strings ['string_append])
  as concat_strings_prog_proof.
Proof.
  time relcompile.
Qed.

Derive asm2str_header1_prog
  in ltac2:(relcompile_tpe 'asm2str_header1_prog 'asm2str_header1 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str_header1_prog_proof.
Proof.
  time relcompile.
Qed.

Derive asm2str_header2_prog
  in ltac2:(relcompile_tpe 'asm2str_header2_prog 'asm2str_header2 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str_header2_prog_proof.
Proof.
  time relcompile.
Qed.

Derive asm2str_header3_prog
  in ltac2:(relcompile_tpe 'asm2str_header3_prog 'asm2str_header3 ['instrs2str; 'concat_strings; '@list_append; 'string_append])
  as asm2str_header3_prog_proof.
Proof.
  time relcompile.
Qed.

Derive asm2str_prog
  in ltac2:(relcompile_tpe 'asm2str_prog 'asm2str ['instrs2str; 'concat_strings; '@list_append; 'string_append; 'asm2str_header1; 'asm2str_header2; 'asm2str_header3])
  as asm2str_prog_proof.
Proof.
  time relcompile.
Qed.

Definition ASMToString_funs := [
  reg2str1_prog;           (* 0 *)
  lab_prog;                (* 1 *)
  clean_prog;              (* 2 *)
  inst2str_prog;           (* 4 *)
  instrs2str_prog;         (* 5 *)
  concat_strings_prog;     (* 6 *)
  asm2str_prog;            (* 7 *)
  asm2str_header1_prog;    (* 8 *)
  asm2str_header2_prog;    (* 9 *)
  asm2str_header3_prog;    (* 10 *)
  inst2str_const_prog;     (* 11 *)
  inst2str_mov_prog;       (* 12 *)
  inst2str_add_prog;       (* 13 *)
  inst2str_sub_prog;       (* 14 *)
  inst2str_div_prog;       (* 15 *)
  inst2str_jump_always_prog; (* 16 *)
  inst2str_jump_equal_prog; (* 17 *)
  inst2str_jump_less_prog; (* 18 *)
  inst2str_call_prog;      (* 19 *)
  inst2str_ret_prog;       (* 20 *)
  inst2str_pop_prog;       (* 21 *)
  inst2str_push_prog;      (* 22 *)
  inst2str_load_rsp_prog;  (* 23 *)
  inst2str_store_rsp_prog; (* 24 *)
  inst2str_add_rsp_prog;   (* 25 *)
  inst2str_sub_rsp_prog;   (* 26 *)
  inst2str_store_prog;     (* 27 *)
  inst2str_load_prog;      (* 28 *)
  inst2str_getchar1_prog;  (* 29 *)
  inst2str_putchar_prog;   (* 30 *)
  inst2str_exit_prog;      (* 31 *)
  inst2str_comment_prog    (* 32 *)
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
  assert_eval_app_by 'list_length 'list_length_prog_proof 'Hlookup_fun_utils 9.
  assert_eval_app_by 'list_append 'list_append_prog_proof 'Hlookup_fun_utils 10.
  assert_eval_app_by 'flatten 'flatten_prog_proof 'Hlookup_fun_utils 11.
  assert_eval_app_by 'app_list_length 'app_list_length_prog_proof 'Hlookup_fun_utils 12.
  assert_eval_app_by 'string_append 'string_append_prog_proof 'Hlookup_fun_utils 13.
  assert_eval_app_by 'mul_nat 'mul_nat_prog_proof 'Hlookup_fun_utils 14.



  assert_eval_app 'reg2str1.
  1: {
    eapply reg2str1_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 0 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'lab.
  1: {
    eapply lab_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 1 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'clean.
  1: {
    eapply clean_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 2 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str.
  1: {
    eapply inst2str_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 4 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'instrs2str.
  1: {
    eapply instrs2str_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 5 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'concat_strings.
  1: {
    eapply concat_strings_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 6 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'asm2str.
  1: {
    eapply asm2str_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 7 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'asm2str_header1.
  1: {
    eapply asm2str_header1_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 8 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'asm2str_header2.
  1: {
    eapply asm2str_header2_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 9 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'asm2str_header3.
  1: {
    eapply asm2str_header3_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 10 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_const.
  1: {
    eapply inst2str_const_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 11 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_mov.
  1: {
    eapply inst2str_mov_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 12 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_add.
  1: {
    eapply inst2str_add_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 13 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_sub.
  1: {
    eapply inst2str_sub_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 14 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_div.
  1: {
    eapply inst2str_div_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 15 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_jump_always.
  1: {
    eapply inst2str_jump_always_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 16 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_jump_equal.
  1: {
    eapply inst2str_jump_equal_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 17 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_jump_less.
  1: {
    eapply inst2str_jump_less_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 18 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_call.
  1: {
    eapply inst2str_call_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 19 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_ret.
  1: {
    eapply inst2str_ret_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 20 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_pop.
  1: {
    eapply inst2str_pop_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 21 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_push.
  1: {
    eapply inst2str_push_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 22 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_load_rsp.
  1: {
    eapply inst2str_load_rsp_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 23 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_store_rsp.
  1: {
    eapply inst2str_store_rsp_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 24 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_add_rsp.
  1: {
    eapply inst2str_add_rsp_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 25 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_sub_rsp.
  1: {
    eapply inst2str_sub_rsp_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 26 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_store.
  1: {
    eapply inst2str_store_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 27 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_load.
  1: {
    eapply inst2str_load_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 28 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_getchar1.
  1: {
    eapply inst2str_getchar1_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 29 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_putchar.
  1: {
    eapply inst2str_putchar_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 30 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_exit.
  1: {
    eapply inst2str_exit_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 31 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'inst2str_comment.
  1: {
    eapply inst2str_comment_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 32 (eapply in_cons); eapply in_eq.
  }

  assert_eval_app '@list_append.
  1: {
    eapply list_append_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 40 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'string_append.
  1: {
    eapply string_append_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 3 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'mul_N.
  1: {
    eapply mul_N_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 45 (eapply in_cons); eapply in_eq.
    eapply mul_N_f_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 44 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'mul_nat.
  1: {
    eapply mul_nat_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 43 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'num2str.
  1: {
    eapply num2str_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 36 (eapply in_cons); eapply in_eq.
    eapply num2str_f_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 35 (eapply in_cons); eapply in_eq.
    eapply nat_modulo_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 33 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'concat_strings.
  1: {
    eapply concat_strings_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 6 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'string_append.
  1: {
    eapply string_append_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 3 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'reg2str1.
  1: {
    eapply reg2str1_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 0 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'N2str.
  1: {
    eapply N2str_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 38 (eapply in_cons); eapply in_eq.
    eapply N2str_f_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 37 (eapply in_cons); eapply in_eq.
    eapply N_modulo_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 34 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'lab.
  1: {
    eapply lab_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 1 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'instrs2str.
  1: {
    eapply instrs2str_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 5 (eapply in_cons); eapply in_eq.
    eapply inst2str_prog_proof; eauto; try reflexivity.
    23: eapply Hlookup_fun; do 4 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_const_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 11 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_mov_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 12 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_add_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 13 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_sub_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 14 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_div_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 15 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_jump_always_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 16 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_jump_equal_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 17 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_jump_less_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 18 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_call_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 19 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_ret_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 20 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_pop_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 21 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_push_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 22 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_load_rsp_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 23 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_store_rsp_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 24 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_add_rsp_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 25 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_sub_rsp_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 26 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_store_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 27 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_load_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 28 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_getchar1_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 29 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_putchar_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 30 (eapply in_cons); eapply in_eq.
    1: eapply inst2str_exit_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 31 (eapply in_cons); eapply in_eq.
    eapply inst2str_comment_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 32 (eapply in_cons); eapply in_eq.
    eapply clean_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 2 (eapply in_cons); eapply in_eq.
  }
  eapply asm2str_prog_proof; eauto; try reflexivity.
  4: eapply Hlookup_fun; do 7 (eapply in_cons); eapply in_eq.
  1: eapply asm2str_header1_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 8 (eapply in_cons); eapply in_eq.
  1: eapply asm2str_header2_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 9 (eapply in_cons); eapply in_eq.
  eapply asm2str_header3_prog_proof; eauto; try reflexivity.
  eapply Hlookup_fun; do 10 (eapply in_cons); eapply in_eq.
Qed.
