From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.imp2asm.ImpToASMCodegen.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
Require Import impboot.automation.AutomationHOLStyle.
Require Import impboot.automation.AutomationLemmas.
Require Import coqutil.Word.Interface.
Require Import ZArith.
From Coq Require Import FunInd.
From Coq Require Import derive.Derive.
From Coq Require Import Lia.
From Ltac2 Require Import Ltac2.

Require Import Patat.Patat.

Set Printing Goal Names.
Set Printing Existential Instances.

Open Scope app_list_scope.

(* *********************************************** *)
(*       Derivations for Codegen Functions         *)
(* *********************************************** *)

(* Equation lemmas for Function declarations *)

Theorem c_declare_binders_rec_equation: ltac2:(unfold_fix_type 'c_declare_binders_rec).
Proof. unfold_fix_proof 'c_declare_binders_rec. Qed.
Theorem c_exp_equation: ltac2:(unfold_fix_type 'c_exp).
Proof. unfold_fix_proof 'c_exp. Qed.
Theorem c_exps_equation: ltac2:(unfold_fix_type 'c_exps).
Proof. unfold_fix_proof 'c_exps. Qed.
Theorem c_test_jump_equation: ltac2:(unfold_fix_type 'c_test_jump).
Proof. unfold_fix_proof 'c_test_jump. Qed.
Theorem c_cmd_equation: ltac2:(unfold_fix_type 'c_cmd).
Proof. unfold_fix_proof 'c_cmd. Qed.
Theorem names_unique_equation: ltac2:(unfold_fix_type 'names_unique).
Proof. unfold_fix_proof 'names_unique. Qed.
Theorem c_fundefs_equation: ltac2:(unfold_fix_type 'c_fundefs).
Proof. unfold_fix_proof 'c_fundefs. Qed.

(* Derivations for simple definitions (no dependencies) *)

Opaque encode.
Opaque name_enc.

Derive init_prog
  in ltac2:(relcompile_tpe 'init_prog 'init []) 
  as init_prog_proof.
Proof.
  intros.
  subst init_prog.
  time relcompile.
  ltac1:(replace (N.of_nat (2 ^ 63 - 1)) with (2 ^ 63 - 1)%N).
  1: ltac1:(lia).
  rewrite Nnat.Nat2N.inj_sub.
  rewrite Nnat.Nat2N.inj_pow.
  ltac1:(lia).
Qed.

Derive list_append_prog
  in ltac2:(relcompile_tpe 'list_append_prog '@list_append []) 
  as list_append_prog_proof.
Proof.
  intros.
  subst list_append_prog.
  time relcompile.
Qed.

Derive list_length_prog
  in ltac2:(relcompile_tpe 'list_length_prog '@list_length []) 
  as list_length_prog_proof.
Proof.
  intros.
  subst list_length_prog.
  time relcompile.
Qed.

Derive flatten_prog
  in ltac2:(relcompile_tpe 'flatten_prog '@flatten ['@list_append]) 
  as flatten_prog_proof.
Proof.
  intros.
  subst flatten_prog.
  time relcompile.
Qed.

Derive app_list_length_prog
  in ltac2:(relcompile_tpe 'app_list_length_prog '@app_list_length ['@list_length]) 
  as app_list_length_prog_proof.
Proof.
  intros.
  subst app_list_length_prog.
  time relcompile.
Qed.

Derive give_up_prog 
  in ltac2:(relcompile_tpe 'give_up_prog 'give_up []) 
  as give_up_prog_proof.
Proof.
  intros.
  subst give_up_prog.
  time relcompile.
Qed.

Derive abort_prog 
  in ltac2:(relcompile_tpe 'abort_prog 'abort []) 
  as abort_prog_proof.
Proof.
  intros.
  subst abort_prog.
  time relcompile.
Qed.

Derive c_const_prog
  in ltac2:(relcompile_tpe 'c_const_prog 'c_const []) 
  as c_const_prog_proof.
Proof.
  intros.
  subst c_const_prog.
  time relcompile.
Qed.

(* Derivations with dependencies *)

Derive even_len_v_stack_prog 
  in ltac2:(relcompile_tpe 'even_len_v_stack_prog '@even_len []) 
  as even_len_v_stack_prog_proof.
Proof.
  intros.
  subst even_len_v_stack_prog.
  time relcompile.
Qed.

Derive odd_len_v_stack_prog 
  in ltac2:(relcompile_tpe 'odd_len_v_stack_prog '@odd_len []) 
  as odd_len_v_stack_prog_proof.
Proof.
  intros.
  subst odd_len_v_stack_prog.
  time relcompile.
Qed.

Derive index_of_prog 
  in ltac2:(relcompile_tpe 'index_of_prog 'index_of ['index_of]) 
  as index_of_prog_proof.
Proof.
  intros.
  subst index_of_prog.
  time relcompile.
Qed.

Derive index_of_opt_prog 
  in ltac2:(relcompile_tpe 'index_of_opt_prog 'index_of_opt []) 
  as index_of_opt_prog_proof.
Proof.
  intros.
  subst index_of_opt_prog.
  time relcompile.
Qed.

Derive c_var_prog 
  in ltac2:(relcompile_tpe 'c_var_prog 'c_var ['index_of]) 
  as c_var_prog_proof.
Proof.
  intros.
  subst c_var_prog.
  time relcompile.
Qed.

Derive c_declare_binders_rec_prog 
  in ltac2:(relcompile_tpe 'c_declare_binders_rec_prog 'c_declare_binders_rec []) 
  as c_declare_binders_rec_prog_proof.
Proof.
  intros.
  subst c_declare_binders_rec_prog.
  time relcompile.
Qed.

Derive c_declare_binders_prog 
  in ltac2:(relcompile_tpe 'c_declare_binders_prog 'c_declare_binders ['c_declare_binders_rec]) 
  as c_declare_binders_prog_proof.
Proof.
  intros.
  subst c_declare_binders_prog.
  time relcompile.
Qed.

Derive c_assign_prog 
  in ltac2:(relcompile_tpe 'c_assign_prog 'c_assign ['index_of]) 
  as c_assign_prog_proof.
Proof.
  intros.
  subst c_assign_prog.
  time relcompile.
Qed.

Derive c_add_prog 
  in ltac2:(relcompile_tpe 'c_add_prog 'c_add []) 
  as c_add_prog_proof.
Proof.
  intros.
  subst c_add_prog.
  time relcompile.
Qed.

Derive c_sub_prog 
  in ltac2:(relcompile_tpe 'c_sub_prog 'c_sub []) 
  as c_sub_prog_proof.
Proof.
  intros.
  subst c_sub_prog.
  time relcompile.
Qed.

Derive c_div_prog 
  in ltac2:(relcompile_tpe 'c_div_prog 'c_div []) 
  as c_div_prog_proof.
Proof.
  intros.
  subst c_div_prog.
  time relcompile.
Qed.

Derive c_alloc_prog
  in ltac2:(relcompile_tpe 'c_alloc_prog 'c_alloc ['@even_len]) 
  as c_alloc_prog_proof.
Proof.
  intros.
  subst c_alloc_prog.
  time relcompile.
Qed.

Derive align_prog 
  in ltac2:(relcompile_tpe 'align_prog 'align []) 
  as align_prog_proof.
Proof.
  intros.
  subst align_prog.
  time relcompile.
Qed.

Derive c_read_prog
  in ltac2:(relcompile_tpe 'c_read_prog 'c_read ['@even_len; 'align; '@app_list_length]) 
  as c_read_prog_proof.
Proof.
  intros.
  subst c_read_prog.
  time relcompile.
Qed.

Derive c_write_prog 
  in ltac2:(relcompile_tpe 'c_write_prog 'c_write ['@even_len; 'align; '@app_list_length]) 
  as c_write_prog_proof.
Proof.
  intros.
  subst c_write_prog.
  time relcompile.
Qed.

Derive c_load_prog 
  in ltac2:(relcompile_tpe 'c_load_prog 'c_load []) 
  as c_load_prog_proof.
Proof.
  intros.
  subst c_load_prog.
  time relcompile.
Qed.

Derive c_store_prog 
  in ltac2:(relcompile_tpe 'c_store_prog 'c_store []) 
  as c_store_prog_proof.
Proof.
  intros.
  subst c_store_prog.
  time relcompile.
Qed.

Derive c_exp_prog 
  in ltac2:(relcompile_tpe 'c_exp_prog 'c_exp ['c_var; 'c_const; 'c_add; 'c_sub; 'c_div; 'c_load; '@app_list_length]) 
  as c_exp_prog_proof.
Proof.
  intros.
  subst c_exp_prog.
  time relcompile.
Qed.

Derive c_exps_prog 
  in ltac2:(relcompile_tpe 'c_exps_prog 'c_exps ['c_exp]) 
  as c_exps_prog_proof.
Proof.
  intros.
  subst c_exps_prog.
  time relcompile.
Qed.

Derive c_cmp_prog 
  in ltac2:(relcompile_tpe 'c_cmp_prog 'c_cmp []) 
  as c_cmp_prog_proof.
Proof.
  intros.
  subst c_cmp_prog.
  time relcompile.
Qed.

Derive c_test_jump_prog 
  in ltac2:(relcompile_tpe 'c_test_jump_prog 'c_test_jump ['c_exp; 'c_cmp; '@app_list_length]) 
  as c_test_jump_prog_proof.
Proof.
  intros.
  subst c_test_jump_prog.
  time relcompile.
Qed.

Derive lookup_prog 
  in ltac2:(relcompile_tpe 'lookup_prog 'lookup []) 
  as lookup_prog_proof.
Proof.
  intros.
  subst lookup_prog.
  time relcompile.
Qed.

Derive make_ret_prog 
  in ltac2:(relcompile_tpe 'make_ret_prog 'make_ret ['@list_length]) 
  as make_ret_prog_proof.
Proof.
  intros.
  subst make_ret_prog.
  time relcompile.
Qed.

Derive c_pops_prog 
  in ltac2:(relcompile_tpe 'c_pops_prog 'c_pops ['give_up; '@even_len; '@list_length]) 
  as c_pops_prog_proof.
Proof.
  intros.
  subst c_pops_prog.
  time relcompile.
Qed.

Derive call_v_stack_prog 
  in ltac2:(relcompile_tpe 'call_v_stack_prog 'call_v_stack []) 
  as call_v_stack_prog_proof.
Proof.
  intros.
  subst call_v_stack_prog.
  time relcompile.
Qed.

Derive c_pushes_prog 
  in ltac2:(relcompile_tpe 'c_pushes_prog 'c_pushes ['call_v_stack; '@list_length]) 
  as c_pushes_prog_proof.
Proof.
  intros.
  subst c_pushes_prog.
  time relcompile.
Qed.

Derive c_call_prog 
  in ltac2:(relcompile_tpe 'c_call_prog 'c_call ['c_pops; 'align; '@even_len; '@app_list_length]) 
  as c_call_prog_proof.
Proof.
  intros.
  subst c_call_prog.
  time relcompile.
Qed.

Derive c_cmd_prog 
  in ltac2:(relcompile_tpe 'c_cmd_prog 'c_cmd 
    ['c_exp; 'c_assign; 'c_store; 'c_test_jump; 'c_exps; 'c_call; 
     'c_var; 'make_ret; 'c_alloc; 'c_read; 'c_write; 'abort; 'lookup;
     '@odd_len; '@app_list_length])
  as c_cmd_prog_proof.
Proof.
  intros.
  subst c_cmd_prog.
  time relcompile.
Qed.

Derive all_binders_prog 
  in ltac2:(relcompile_tpe 'all_binders_prog 'all_binders ['@list_append]) 
  as all_binders_prog_proof.
Proof.
  intros.
  subst all_binders_prog.
  time relcompile.
Qed.

Derive names_contain_prog 
  in ltac2:(relcompile_tpe 'names_contain_prog 'names_contain []) 
  as names_contain_prog_proof.
Proof.
  intros.
  subst names_contain_prog.
  time relcompile.
Qed.

Derive names_unique_prog 
  in ltac2:(relcompile_tpe 'names_unique_prog 'names_unique ['names_contain]) 
  as names_unique_prog_proof.
Proof.
  intros.
  subst names_unique_prog.
  time relcompile.
Qed.

Derive unique_binders_prog 
  in ltac2:(relcompile_tpe 'unique_binders_prog 'unique_binders ['all_binders; 'names_unique]) 
  as unique_binders_prog_proof.
Proof.
  intros.
  subst unique_binders_prog.
  time relcompile.
Qed.

Derive make_vs_from_binders_prog 
  in ltac2:(relcompile_tpe 'make_vs_from_binders_prog 'make_vs_from_binders []) 
  as make_vs_from_binders_prog_proof.
Proof.
  intros.
  subst make_vs_from_binders_prog.
  time relcompile.
Qed.

Derive c_fundef_prog 
  in ltac2:(relcompile_tpe 'c_fundef_prog 'c_fundef 
    ['c_pushes; 'unique_binders; 'make_vs_from_binders; 'c_cmd; '@list_length; '@list_append]) 
  as c_fundef_prog_proof.
Proof.
  intros.
  subst c_fundef_prog.
  time relcompile.
Qed.

(* TODO: need mod *)
(* Derive name2str_prog 
  in ltac2:(relcompile_tpe 'name2str_prog 'name2str []) 
  as name2str_prog_proof.
Proof.
  intros.
  subst name2str_prog.
  time relcompile.
Qed. *)

Derive get_funcs_prog 
  in ltac2:(relcompile_tpe 'get_funcs_prog 'get_funcs []) 
  as get_funcs_prog_proof.
Proof.
  intros.
  subst get_funcs_prog.
  time relcompile.
Qed.

Derive name_of_func_prog 
  in ltac2:(relcompile_tpe 'name_of_func_prog 'name_of_func []) 
  as name_of_func_prog_proof.
Proof.
  intros.
  subst name_of_func_prog.
  time relcompile.
Qed.

Derive c_fundefs_prog 
  in ltac2:(relcompile_tpe 'c_fundefs_prog 'c_fundefs ['c_fundef; 'name2str; 'name_of_func]) 
  as c_fundefs_prog_proof.
Proof.
  intros.
  subst c_fundefs_prog.
  time relcompile.
Qed.

(* TODO: (fun_name_of_string "main") taken as constant. Is that ok? *)
Derive codegen_prog 
  in ltac2:(relcompile_tpe 'codegen_prog 'codegen ['c_fundefs; 'lookup; 'init; 'get_funcs; '@app_list_length; '@flatten]) 
  as codegen_prog_proof.
Proof.
  intros.
  subst codegen_prog.
  time relcompile.
Qed.
