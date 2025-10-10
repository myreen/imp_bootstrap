From impboot Require Import utils.Core.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.imp2asm.ImpToASMCodegen.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
Require Import impboot.automation.AutomationHOLStyle.
Require Import coqutil.Word.Interface.
Require Import ZArith.
From Coq Require Import FunInd.
From Coq Require Import derive.Derive.
From Coq Require Import Lia.
From Ltac2 Require Import Ltac2.

Open Scope app_list_scope.

(* *********************************************** *)
(*       Derivations for Codegen Functions         *)
(* *********************************************** *)

(* Equation lemmas for Function declarations *)

(* Lemma c_exp_equation : ltac:(unfold_tpe c_exp).
Proof. ltac1:(unfold_proof). Qed.

Lemma c_exps_equation : ltac:(unfold_tpe c_exps).
Proof. ltac1:(unfold_proof). Qed.

Lemma c_test_jump_equation : ltac:(unfold_tpe c_test_jump).
Proof. ltac1:(unfold_proof). Qed.

Lemma lookup_equation : ltac:(unfold_tpe lookup).
Proof. ltac1:(unfold_proof). Qed.

Lemma call_v_stack_equation : ltac:(unfold_tpe call_v_stack).
Proof. ltac1:(unfold_proof). Qed.

Lemma c_cmd_equation : ltac:(unfold_tpe c_cmd).
Proof. ltac1:(unfold_proof). Qed.

Lemma make_vs_from_binders_equation : ltac:(unfold_tpe make_vs_from_binders).
Proof. ltac1:(unfold_proof). Qed.

Lemma c_fundefs_equation : ltac:(unfold_tpe c_fundefs).
Proof. ltac1:(unfold_proof). Qed. *)

(* Equation lemmas for Fixpoint declarations *)

(* Lemma c_declare_binders_rec_equation : ltac:(unfold_tpe c_declare_binders_rec).
Proof. ltac1:(unfold_proof). Qed.

Lemma all_binders_equation : ltac:(unfold_tpe all_binders).
Proof. ltac1:(unfold_proof). Qed.

Lemma names_contain_equation : ltac:(unfold_tpe names_contain).
Proof. ltac1:(unfold_proof). Qed.

Lemma names_unique_equation : ltac:(unfold_tpe names_unique).
Proof. ltac1:(unfold_proof). Qed. *)

(* Derivations for simple definitions (no dependencies) *)

Opaque encode.
Opaque name_enc.

Derive init_prog 
  in ltac2:(relcompile_tpe 'init_prog 'init []) 
  as init_prog_proof.
Proof.
  intros.
  subst init_prog.
  relcompile.
  all: try ltac1:(lia).
  2: eapply FEnv.lookup_insert_eq.
  ltac1:(replace (N.of_nat (2 ^ 63 - 1)) with (2 ^ 63 - 1)%N).
  1: ltac1:(lia).
  rewrite Nnat.Nat2N.inj_sub.
  rewrite Nnat.Nat2N.inj_pow.
  ltac1:(lia).
Qed.

Derive give_up_prog 
  in ltac2:(relcompile_tpe 'give_up_prog 'give_up []) 
  as give_up_prog_proof.
Proof.
  intros.
  subst give_up_prog.
  relcompile.
  cbn; try ltac1:(congruence); try reflexivity.
Qed.

Derive abort_prog 
  in ltac2:(relcompile_tpe 'abort_prog 'abort []) 
  as abort_prog_proof.
Proof.
  intros.
  subst abort_prog.
  relcompile.
  cbn; try ltac1:(congruence); try reflexivity.
Qed.

Derive c_const_prog
  in ltac2:(relcompile_tpe 'c_const_prog 'c_const []) 
  as c_const_prog_proof.
Proof.
  intros.
  subst c_const_prog.
  relcompile.
  all: simpl.
  all: cbn; try ltac1:(congruence); try reflexivity.
Qed.

(* Derivations with dependencies *)

Derive even_len_prog 
  in ltac2:(relcompile_tpe 'even_len_prog 'even_len []) 
  as even_len_prog_proof.
Proof.
  intros.
  subst even_len_prog.
  relcompile.
  all: inversion H0.
Qed.

Derive odd_len_prog 
  in ltac2:(relcompile_tpe 'odd_len_prog 'odd_len []) 
  as odd_len_prog_proof.
Proof.
  intros.
  subst odd_len_prog.
  relcompile.
  all: inversion H0.
Qed.

Derive index_of_prog 
  in ltac2:(relcompile_tpe 'index_of_prog 'index_of ['index_of]) 
  as index_of_prog_proof.
Proof.
  intros.
  subst index_of_prog.
  relcompile.
  all: simpl; eauto.
  all: cbn; try ltac1:(congruence); try reflexivity.
  1: exact Refinable_nat.
  1: inversion H1.
  all: cbn; try ltac1:(congruence); try reflexivity.
Qed.

Derive index_of_opt_prog 
  in ltac2:(relcompile_tpe 'index_of_opt_prog 'index_of_opt []) 
  as index_of_opt_prog_proof.
Proof.
  intros.
  subst index_of_opt_prog.
  relcompile.
Qed.

Derive c_var_prog 
  in ltac2:(relcompile_tpe 'c_var_prog 'c_var ['index_of]) 
  as c_var_prog_proof.
Proof.
  intros.
  subst c_var_prog.
  relcompile.
Qed.

Derive c_declare_binders_rec_prog 
  in ltac2:(relcompile_tpe 'c_declare_binders_rec_prog 'c_declare_binders_rec []) 
  as c_declare_binders_rec_prog_proof.
Proof.
  intros.
  subst c_declare_binders_rec_prog.
  relcompile.
Qed.

Derive c_declare_binders_prog 
  in ltac2:(relcompile_tpe 'c_declare_binders_prog 'c_declare_binders ['c_declare_binders_rec]) 
  as c_declare_binders_prog_proof.
Proof.
  intros.
  subst c_declare_binders_prog.
  relcompile.
Qed.

Derive c_assign_prog 
  in ltac2:(relcompile_tpe 'c_assign_prog 'c_assign ['index_of]) 
  as c_assign_prog_proof.
Proof.
  intros.
  subst c_assign_prog.
  relcompile.
Qed.

Derive c_add_prog 
  in ltac2:(relcompile_tpe 'c_add_prog 'c_add []) 
  as c_add_prog_proof.
Proof.
  intros.
  subst c_add_prog.
  relcompile.
Qed.

Derive c_sub_prog 
  in ltac2:(relcompile_tpe 'c_sub_prog 'c_sub []) 
  as c_sub_prog_proof.
Proof.
  intros.
  subst c_sub_prog.
  relcompile.
Qed.

Derive c_div_prog 
  in ltac2:(relcompile_tpe 'c_div_prog 'c_div []) 
  as c_div_prog_proof.
Proof.
  intros.
  subst c_div_prog.
  relcompile.
Qed.

Derive c_alloc_prog 
  in ltac2:(relcompile_tpe 'c_alloc_prog 'c_alloc ['even_len]) 
  as c_alloc_prog_proof.
Proof.
  intros.
  subst c_alloc_prog.
  relcompile.
Qed.

Derive align_prog 
  in ltac2:(relcompile_tpe 'align_prog 'align []) 
  as align_prog_proof.
Proof.
  intros.
  subst align_prog.
  relcompile.
Qed.

Derive c_read_prog 
  in ltac2:(relcompile_tpe 'c_read_prog 'c_read ['even_len; 'align]) 
  as c_read_prog_proof.
Proof.
  intros.
  subst c_read_prog.
  relcompile.
Qed.

Derive c_write_prog 
  in ltac2:(relcompile_tpe 'c_write_prog 'c_write ['even_len; 'align]) 
  as c_write_prog_proof.
Proof.
  intros.
  subst c_write_prog.
  relcompile.
Qed.

Derive c_load_prog 
  in ltac2:(relcompile_tpe 'c_load_prog 'c_load []) 
  as c_load_prog_proof.
Proof.
  intros.
  subst c_load_prog.
  relcompile.
Qed.

Derive c_store_prog 
  in ltac2:(relcompile_tpe 'c_store_prog 'c_store []) 
  as c_store_prog_proof.
Proof.
  intros.
  subst c_store_prog.
  relcompile.
Qed.

Derive c_exp_prog 
  in ltac2:(relcompile_tpe 'c_exp_prog 'c_exp ['c_var; 'c_const; 'c_add; 'c_sub; 'c_div; 'c_load]) 
  as c_exp_prog_proof.
Proof.
  intros.
  subst c_exp_prog.
  relcompile.
Qed.

Derive c_exps_prog 
  in ltac2:(relcompile_tpe 'c_exps_prog 'c_exps ['c_exp]) 
  as c_exps_prog_proof.
Proof.
  intros.
  subst c_exps_prog.
  relcompile.
Qed.

Derive c_cmp_prog 
  in ltac2:(relcompile_tpe 'c_cmp_prog 'c_cmp []) 
  as c_cmp_prog_proof.
Proof.
  intros.
  subst c_cmp_prog.
  relcompile.
Qed.

Derive c_test_jump_prog 
  in ltac2:(relcompile_tpe 'c_test_jump_prog 'c_test_jump ['c_exp; 'c_cmp]) 
  as c_test_jump_prog_proof.
Proof.
  intros.
  subst c_test_jump_prog.
  relcompile.
Qed.

Derive lookup_prog 
  in ltac2:(relcompile_tpe 'lookup_prog 'lookup []) 
  as lookup_prog_proof.
Proof.
  intros.
  subst lookup_prog.
  relcompile.
Qed.

Derive make_ret_prog 
  in ltac2:(relcompile_tpe 'make_ret_prog 'make_ret []) 
  as make_ret_prog_proof.
Proof.
  intros.
  subst make_ret_prog.
  relcompile.
Qed.

Derive c_pops_prog 
  in ltac2:(relcompile_tpe 'c_pops_prog 'c_pops ['give_up; 'even_len]) 
  as c_pops_prog_proof.
Proof.
  intros.
  subst c_pops_prog.
  relcompile.
Qed.

Derive call_v_stack_prog 
  in ltac2:(relcompile_tpe 'call_v_stack_prog 'call_v_stack []) 
  as call_v_stack_prog_proof.
Proof.
  intros.
  subst call_v_stack_prog.
  relcompile.
Qed.

Derive c_pushes_prog 
  in ltac2:(relcompile_tpe 'c_pushes_prog 'c_pushes ['call_v_stack]) 
  as c_pushes_prog_proof.
Proof.
  intros.
  subst c_pushes_prog.
  relcompile.
Qed.

Derive c_call_prog 
  in ltac2:(relcompile_tpe 'c_call_prog 'c_call ['c_pops; 'align; 'even_len]) 
  as c_call_prog_proof.
Proof.
  intros.
  subst c_call_prog.
  relcompile.
Qed.

Derive c_cmd_prog 
  in ltac2:(relcompile_tpe 'c_cmd_prog 'c_cmd 
    ['c_exp; 'c_assign; 'c_store; 'c_test_jump; 'c_exps; 'c_call; 
     'c_var; 'make_ret; 'c_alloc; 'c_read; 'c_write; 'abort; 'lookup]) 
  as c_cmd_prog_proof.
Proof.
  intros.
  subst c_cmd_prog.
  relcompile.
Qed.

Derive all_binders_prog 
  in ltac2:(relcompile_tpe 'all_binders_prog 'all_binders []) 
  as all_binders_prog_proof.
Proof.
  intros.
  subst all_binders_prog.
  relcompile.
Qed.

Derive names_contain_prog 
  in ltac2:(relcompile_tpe 'names_contain_prog 'names_contain []) 
  as names_contain_prog_proof.
Proof.
  intros.
  subst names_contain_prog.
  relcompile.
Qed.

Derive names_unique_prog 
  in ltac2:(relcompile_tpe 'names_unique_prog 'names_unique ['names_contain]) 
  as names_unique_prog_proof.
Proof.
  intros.
  subst names_unique_prog.
  relcompile.
Qed.

Derive unique_binders_prog 
  in ltac2:(relcompile_tpe 'unique_binders_prog 'unique_binders ['all_binders; 'names_unique]) 
  as unique_binders_prog_proof.
Proof.
  intros.
  subst unique_binders_prog.
  relcompile.
Qed.

Derive make_vs_from_binders_prog 
  in ltac2:(relcompile_tpe 'make_vs_from_binders_prog 'make_vs_from_binders []) 
  as make_vs_from_binders_prog_proof.
Proof.
  intros.
  subst make_vs_from_binders_prog.
  relcompile.
Qed.

Derive c_fundef_prog 
  in ltac2:(relcompile_tpe 'c_fundef_prog 'c_fundef 
    ['c_pushes; 'unique_binders; 'make_vs_from_binders; 'c_cmd]) 
  as c_fundef_prog_proof.
Proof.
  intros.
  subst c_fundef_prog.
  relcompile.
Qed.

Derive name2str_prog 
  in ltac2:(relcompile_tpe 'name2str_prog 'name2str []) 
  as name2str_prog_proof.
Proof.
  intros.
  subst name2str_prog.
  relcompile.
Qed.

Derive c_fundefs_prog 
  in ltac2:(relcompile_tpe 'c_fundefs_prog 'c_fundefs ['c_fundef; 'name2str]) 
  as c_fundefs_prog_proof.
Proof.
  intros.
  subst c_fundefs_prog.
  relcompile.
Qed.

Derive codegen_prog 
  in ltac2:(relcompile_tpe 'codegen_prog 'codegen ['c_fundefs; 'lookup; 'init]) 
  as codegen_prog_proof.
Proof.
  intros.
  subst codegen_prog.
  relcompile.
Qed.

