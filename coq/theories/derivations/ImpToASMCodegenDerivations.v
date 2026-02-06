From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.commons.CompilerUtils.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
Require Import impboot.automation.RelCompiler.
Require Import impboot.automation.ltac2.UnfoldFix.
Require Import impboot.automation.Ltac2Utils.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.commons.CompilerUtils.
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

From impboot Require Import derivations.CompilerUtilsDerivations.

(* *********************************************** *)
(*       Derivations for Codegen Functions         *)
(* *********************************************** *)

Opaque encode.
Opaque name_enc.

Derive init_prog
  in ltac2:(relcompile_tpe 'init_prog 'init ['@list_append; 'string_append]) 
  as init_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_assign_prog 
  in ltac2:(relcompile_tpe 'c_assign_prog 'c_assign ['index_of]) 
  as c_assign_prog_proof.
Proof.
  time relcompile.
Qed.

(* Derive name2str_prog
  in ltac2:(relcompile_tpe 'name2str_prog 'name2str ['N_modulo]) 
  as name2str_prog_proof.
Proof.
  time relcompile.
  subst; eapply N_modulo_bounds; ltac1:(lia).
Qed. *)

Derive give_up_prog 
  in ltac2:(relcompile_tpe 'give_up_prog 'give_up []) 
  as give_up_prog_proof.
Proof.
  time relcompile.
Qed.

Derive abortLoc_prog
  in ltac2:(relcompile_tpe 'abortLoc_prog 'abortLoc []) 
  as abortLoc_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_const_prog
  in ltac2:(relcompile_tpe 'c_const_prog 'c_const []) 
  as c_const_prog_proof.
Proof.
  time relcompile.
Qed.

Derive even_len_prog 
  in ltac2:(relcompile_tpe 'even_len_prog '@even_len []) 
  as even_len_prog_proof.
Proof.
  time relcompile.
Qed.

Derive odd_len_prog 
  in ltac2:(relcompile_tpe 'odd_len_prog '@odd_len []) 
  as odd_len_prog_proof.
Proof.
  time relcompile.
Qed.

Derive index_of_prog 
  in ltac2:(relcompile_tpe 'index_of_prog 'index_of []) 
  as index_of_prog_proof.
Proof.
  time relcompile.
Qed.

Derive index_of_opt_prog 
  in ltac2:(relcompile_tpe 'index_of_opt_prog 'index_of_opt []) 
  as index_of_opt_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_var_prog 
  in ltac2:(relcompile_tpe 'c_var_prog 'c_var ['index_of]) 
  as c_var_prog_proof.
Proof.
  time relcompile.
Qed.

Derive all_binders_prog 
  in ltac2:(relcompile_tpe 'all_binders_prog 'all_binders ['@list_append]) 
  as all_binders_prog_proof.
Proof.
  time relcompile.
Qed.

Derive names_contain_prog 
  in ltac2:(relcompile_tpe 'names_contain_prog 'names_contain []) 
  as names_contain_prog_proof.
Proof.
  time relcompile.
Qed.

Derive names_unique_prog 
  in ltac2:(relcompile_tpe 'names_unique_prog 'names_unique ['names_contain]) 
  as names_unique_prog_proof.
Proof.
  time relcompile.
Qed.

Derive unique_binders_prog 
  in ltac2:(relcompile_tpe 'unique_binders_prog 'unique_binders ['all_binders; 'names_unique]) 
  as unique_binders_prog_proof.
Proof.
  time relcompile.
Qed.

Derive make_vs_from_binders_prog 
  in ltac2:(relcompile_tpe 'make_vs_from_binders_prog 'make_vs_from_binders []) 
  as make_vs_from_binders_prog_proof.
Proof.
  time relcompile.
Qed.

Derive filter_name_prog 
  in ltac2:(relcompile_tpe 'filter_name_prog 'filter_name []) 
  as filter_name_prog_proof.
Proof.
  time relcompile.
Qed.

Derive remove_names_prog 
  in ltac2:(relcompile_tpe 'remove_names_prog 'remove_names ['filter_name]) 
  as remove_names_prog_proof.
Proof.
  time relcompile.
Qed.

Derive call_v_stack_prog 
  in ltac2:(relcompile_tpe 'call_v_stack_prog 'call_v_stack []) 
  as call_v_stack_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_pushes_vs_prog 
  in ltac2:(relcompile_tpe 'c_pushes_vs_prog 'c_pushes_vs ['@list_length; 'call_v_stack]) 
  as c_pushes_vs_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_declare_binders_prog 
  in ltac2:(relcompile_tpe 'c_declare_binders_prog 'c_declare_binders
    ['unique_binders; 'remove_names; 'make_vs_from_binders; '@list_append; 'c_pushes_vs; '@even_len; '@list_length]) 
  as c_declare_binders_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_add_prog 
  in ltac2:(relcompile_tpe 'c_add_prog 'c_add []) 
  as c_add_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_sub_prog 
  in ltac2:(relcompile_tpe 'c_sub_prog 'c_sub []) 
  as c_sub_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_div_prog 
  in ltac2:(relcompile_tpe 'c_div_prog 'c_div []) 
  as c_div_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_alloc_prog
  in ltac2:(relcompile_tpe 'c_alloc_prog 'c_alloc ['@even_len]) 
  as c_alloc_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_read_prog
  in ltac2:(relcompile_tpe 'c_read_prog 'c_read ['@even_len; '@app_list_length]) 
  as c_read_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_write_prog 
  in ltac2:(relcompile_tpe 'c_write_prog 'c_write ['@even_len; '@app_list_length]) 
  as c_write_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_load_prog 
  in ltac2:(relcompile_tpe 'c_load_prog 'c_load []) 
  as c_load_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_store_prog 
  in ltac2:(relcompile_tpe 'c_store_prog 'c_store ['@list_append])
  as c_store_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_exp_prog 
  in ltac2:(relcompile_tpe 'c_exp_prog 'c_exp ['c_var; 'c_const; 'c_add; 'c_sub; 'c_div; 'c_load; '@app_list_length]) 
  as c_exp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_exps_prog 
  in ltac2:(relcompile_tpe 'c_exps_prog 'c_exps ['c_exp]) 
  as c_exps_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_cmp_prog 
  in ltac2:(relcompile_tpe 'c_cmp_prog 'c_cmp []) 
  as c_cmp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_test_jump_prog 
  in ltac2:(relcompile_tpe 'c_test_jump_prog 'c_test_jump ['c_exp; 'c_cmp; '@app_list_length; '@list_append]) 
  as c_test_jump_prog_proof.
Proof.
  time relcompile.
Qed.

Derive lookup_prog 
  in ltac2:(relcompile_tpe 'lookup_prog 'lookup []) 
  as lookup_prog_proof.
Proof.
  time relcompile.
Qed.

Derive make_ret_prog 
  in ltac2:(relcompile_tpe 'make_ret_prog 'make_ret ['@list_length]) 
  as make_ret_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_pops_prog 
  in ltac2:(relcompile_tpe 'c_pops_prog 'c_pops ['give_up; '@even_len; '@list_length]) 
  as c_pops_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_pushes_prog 
  in ltac2:(relcompile_tpe 'c_pushes_prog 'c_pushes ['call_v_stack; '@list_length; 'c_pushes_vs]) 
  as c_pushes_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_call_prog 
  in ltac2:(relcompile_tpe 'c_call_prog 'c_call ['c_pops; '@even_len; '@app_list_length]) 
  as c_call_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_cmd_prog 
  in ltac2:(relcompile_tpe 'c_cmd_prog 'c_cmd 
    ['c_exp; 'c_assign; 'c_store; 'c_test_jump; 'c_exps; 'c_call; 
     'c_var; 'make_ret; 'c_alloc; 'c_read; 'c_write; 'abortLoc; 'lookup;
     '@odd_len; '@app_list_length])
  as c_cmd_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_fundef_prog 
  in ltac2:(relcompile_tpe 'c_fundef_prog 'c_fundef 
    ['c_pushes; 'unique_binders; 'make_vs_from_binders; 'c_cmd; '@list_length; '@list_append; '@even_len; 'c_declare_binders; '@app_list_length]) 
  as c_fundef_prog_proof.
Proof.
  time relcompile.
Qed.

Derive get_funcs_prog 
  in ltac2:(relcompile_tpe 'get_funcs_prog 'get_funcs []) 
  as get_funcs_prog_proof.
Proof.
  time relcompile.
Qed.

Derive name_of_func_prog 
  in ltac2:(relcompile_tpe 'name_of_func_prog 'name_of_func []) 
  as name_of_func_prog_proof.
Proof.
  time relcompile.
Qed.

Derive c_fundefs_prog 
  in ltac2:(relcompile_tpe 'c_fundefs_prog 'c_fundefs ['c_fundef; 'name_of_func]) 
  as c_fundefs_prog_proof.
Proof.
  time relcompile.
Qed.

Derive codegen_prog 
  in ltac2:(relcompile_tpe 'codegen_prog 'codegen ['c_fundefs; 'lookup; 'init; 'get_funcs; '@app_list_length; '@flatten]) 
  as codegen_prog_proof.
Proof.
  time relcompile.
Qed.

Definition ImpToASMCodegen_funs := [
  init_prog;                    (* 0 *)
  c_assign_prog;               (* 1 *)
  list_append_prog;            (* 2 *)
  list_length_prog;            (* 3 *)
  flatten_prog;                (* 4 *)
  app_list_length_prog;        (* 5 *)
  give_up_prog;                (* 6 *)
  abortLoc_prog;               (* 7 *)
  c_const_prog;                (* 8 *)
  even_len_prog;               (* 9 *)
  odd_len_prog;                (* 10 *)
  index_of_prog;               (* 11 *)
  index_of_opt_prog;           (* 12 *)
  c_var_prog;                  (* 13 *)
  all_binders_prog;            (* 14 *)
  names_contain_prog;          (* 15 *)
  names_unique_prog;           (* 16 *)
  unique_binders_prog;         (* 17 *)
  make_vs_from_binders_prog;   (* 18 *)
  filter_name_prog;            (* 19 *)
  remove_names_prog;           (* 20 *)
  call_v_stack_prog;           (* 21 *)
  c_pushes_vs_prog;            (* 22 *)
  c_declare_binders_prog;      (* 23 *)
  c_add_prog;                  (* 24 *)
  c_sub_prog;                  (* 25 *)
  c_div_prog;                  (* 26 *)
  c_alloc_prog;                (* 27 *)
  c_read_prog;                 (* 28 *)
  c_write_prog;                (* 29 *)
  c_load_prog;                 (* 30 *)
  c_store_prog;                (* 31 *)
  c_exp_prog;                  (* 32 *)
  c_exps_prog;                 (* 33 *)
  c_cmp_prog;                  (* 34 *)
  c_test_jump_prog;            (* 35 *)
  lookup_prog;                 (* 36 *)
  make_ret_prog;               (* 37 *)
  c_pops_prog;                 (* 38 *)
  c_pushes_prog;               (* 39 *)
  c_call_prog;                 (* 40 *)
  c_cmd_prog;                  (* 41 *)
  c_fundef_prog;               (* 42 *)
  get_funcs_prog;              (* 43 *)
  name_of_func_prog;           (* 44 *)
  c_fundefs_prog;              (* 45 *)
  codegen_prog                 (* 46 *)
].

From impboot Require Import automation.ltac2.Messages.

Ltac2 assert_lookup_fun (prog: constr) :=
  let h := Fresh.in_goal (Option.get (Ident.of_string "Hlookup_fun_s")) in
  assert (match $prog with
  | FunSyntax.Defun fname args fn =>
      lookup_fun fname (funs &s) = Some (args, fn)
  end) as $h; try (simpl in $h).

Ltac2 assert_eval_app (fname: constr) :=
  let tpe := gen_eval_app fname () in
  assert ($tpe).

Ltac2 assert_eval_app_proof (prf: constr) (list_constr: constr) (n: int) :=
  eapply $prf; eauto; try (reflexivity);
  try (eapply $list_constr; do n (eapply in_cons); eapply in_eq).

Ltac2 assert_eval_app_by (fname: constr) (prf: constr) (list_constr_hyp: constr) (n: int) :=
  let tpe := gen_eval_app fname () in
  assert ($tpe) by (
    print_full_goal ();
    eapply $prf; eauto; try (reflexivity);
    print_full_goal ();
    eapply $list_constr_hyp; do n (eapply in_cons); eapply in_eq
  ).

Ltac2 int_to_constr_nat (n: int) : constr :=
  let rec go n acc :=
    if Int.equal n 0 then acc
    else go (Int.sub n 1) (constr:(S $acc))
  in
  go n (constr:(O)).

Require Import Ltac2.RedFlags.
Require Import Ltac2.Printf.
From Ltac2 Require Import Std.

From coqutil Require Import Tactics.reference_to_string.

Ltac2 loop_assert_eval_app_in_list (list_constr: constr) (size: int) :=
  let rec go n :=
    if Int.equal n size then ()
    else (
      let n_constr := int_to_constr_nat n in
      let prog := constr:(nth $n_constr $list_constr (FunSyntax.Defun (name_enc "dummy") [] (FunSyntax.Const 0))) in
      let prog := Std.eval_simpl all None prog in
      (* remove prog from the prog name *)
      let prog_ref := reference_of_constr prog in
      let prog_ref_str := Option.get (reference_to_string prog_ref) in
      let prf_str := String.app prog_ref_str "_proof" in
      let prf := Option.get (Ident.of_string prf_str) in
      let prf_constr := Env.instantiate (VarRef prf) in
      let fname_str := String.sub prog_ref_str 0 (Int.sub (String.length prog_ref_str) (String.length "_prog")) in
      let fname := Option.get (Ident.of_string fname_str) in
      let fname_constr := Env.instantiate (VarRef fname) in
      assert_eval_app_by fname_constr prf_constr list_constr n;
      go (Int.add n 1)
    )
  in
  go 0.

Theorem codegen_thm:
  ∀ (s: state) (p: prog),
    (∀ fname args fn,
      In (FunSyntax.Defun fname args fn) (CompilerUtils_funs) →
      lookup_fun fname (funs s) = Some (args, fn)) ->
    (∀ fname args fn,
      In (FunSyntax.Defun fname args fn) (ImpToASMCodegen_funs) →
      lookup_fun fname (funs s) = Some (args, fn)) ->
    eval_app (name_enc "codegen") [encode p] s ((encode (codegen p)), s).
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


  
  loop_assert_eval_app_in_list (constr:(CompilerUtils_funs)) 17.
  assert_eval_app '@list_length.
  1: {
    eapply list_length_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 53 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app '@list_append.
  1: {
    eapply list_append_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 54 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app '@app_list_length.
  1: {
    eapply app_list_length_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 56 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'call_v_stack.
  1: {
    eapply call_v_stack_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 21 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app '@even_len.
  1: {
    eapply even_len_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 9 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'c_pushes.
  1: {
    eapply c_pushes_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 39 (eapply in_cons); eapply in_eq.
    eapply c_pushes_vs_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 22 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'unique_binders.
  1: {
    eapply unique_binders_prog_proof; eauto; try reflexivity.  
    3: eapply Hlookup_fun; do 17 (eapply in_cons); eapply in_eq.
    1: eapply all_binders_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 14 (eapply in_cons); eapply in_eq.
    1: eapply names_unique_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 16 (eapply in_cons); eapply in_eq.
    eapply names_contain_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 15 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'string_append.
  1: {
    eapply string_append_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 60 (eapply in_cons); eapply in_eq.
  }
  eapply codegen_prog_proof; eauto; try reflexivity.
  6: eapply Hlookup_fun; do 46 (eapply in_cons); eapply in_eq.
  5: eapply flatten_prog_proof; eauto; try reflexivity.
  5: eapply Hlookup_fun; do 55 (eapply in_cons); eapply in_eq.
  1: eapply c_fundefs_prog_proof; eauto; try reflexivity.
  3: eapply Hlookup_fun; do 45 (eapply in_cons); eapply in_eq.
  1: eapply c_fundef_prog_proof; eauto; try reflexivity.
  4: eapply Hlookup_fun; do 42 (eapply in_cons); eapply in_eq.
  7: eapply get_funcs_prog_proof; eauto; try reflexivity.
  7: eapply Hlookup_fun; do 43 (eapply in_cons); eapply in_eq.
  6: eapply init_prog_proof; eauto; try reflexivity.
  6: eapply Hlookup_fun; do 0 (eapply in_cons); eapply in_eq.
  5: eapply lookup_prog_proof; eauto; try reflexivity.
  5: eapply Hlookup_fun; do 36 (eapply in_cons); eapply in_eq.
  4: eapply name_of_func_prog_proof; eauto; try reflexivity.
  4: eapply Hlookup_fun; do 44 (eapply in_cons); eapply in_eq.
  1: eapply make_vs_from_binders_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 18 (eapply in_cons); eapply in_eq.
  2: eapply c_declare_binders_prog_proof; eauto; try reflexivity.
  5: eapply Hlookup_fun; do 23 (eapply in_cons); eapply in_eq.
  4: eapply c_pushes_vs_prog_proof; eauto; try reflexivity.
  4: eapply Hlookup_fun; do 22 (eapply in_cons); eapply in_eq.
  3: eapply make_vs_from_binders_prog_proof; eauto; try reflexivity.
  3: eapply Hlookup_fun; do 18 (eapply in_cons); eapply in_eq.
  2: eapply remove_names_prog_proof; eauto; try reflexivity.
  3: eapply Hlookup_fun; do 20 (eapply in_cons); eapply in_eq.
  2: eapply filter_name_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 19 (eapply in_cons); eapply in_eq.
  assert_eval_app 'c_exp.
  1: {
    eapply c_exp_prog_proof; eauto; try reflexivity.
    7: eapply Hlookup_fun; do 32 (eapply in_cons); eapply in_eq.
    1: eapply c_var_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 13 (eapply in_cons); eapply in_eq.
    1: eapply index_of_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 11 (eapply in_cons); eapply in_eq.
    1: eapply c_const_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 8 (eapply in_cons); eapply in_eq.
    1: eapply c_add_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 24 (eapply in_cons); eapply in_eq.
    1: eapply c_sub_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 25 (eapply in_cons); eapply in_eq.
    1: eapply c_div_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 26 (eapply in_cons); eapply in_eq.
    1: eapply c_load_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 30 (eapply in_cons); eapply in_eq.
  }
  assert_eval_app 'c_assign.
  1: {
    eapply c_assign_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 1 (eapply in_cons); eapply in_eq.
    eapply index_of_prog_proof; eauto; try reflexivity.
    eapply Hlookup_fun; do 11 (eapply in_cons); eapply in_eq.
  }
  eapply c_cmd_prog_proof; eauto; try reflexivity.
  13: eapply Hlookup_fun; do 41 (eapply in_cons); eapply in_eq.
  1: eapply c_store_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 31 (eapply in_cons); eapply in_eq.
  1: eapply c_test_jump_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 35 (eapply in_cons); eapply in_eq.
  1: eapply c_cmp_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 34 (eapply in_cons); eapply in_eq.
  1: eapply c_exps_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 33 (eapply in_cons); eapply in_eq.
  1: eapply c_call_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 40 (eapply in_cons); eapply in_eq.
  1: eapply c_pops_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 38 (eapply in_cons); eapply in_eq.
  1: eapply give_up_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 6 (eapply in_cons); eapply in_eq.
  1: eapply c_var_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 13 (eapply in_cons); eapply in_eq.
  1: eapply index_of_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 11 (eapply in_cons); eapply in_eq.
  1: eapply make_ret_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 37 (eapply in_cons); eapply in_eq.
  1: eapply c_alloc_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 27 (eapply in_cons); eapply in_eq.
  1: eapply c_read_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 28 (eapply in_cons); eapply in_eq.
  1: eapply c_write_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 29 (eapply in_cons); eapply in_eq.
  1: eapply abortLoc_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 7 (eapply in_cons); eapply in_eq.
  1: eapply lookup_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 36 (eapply in_cons); eapply in_eq.
  eapply odd_len_prog_proof; eauto; try reflexivity.
  eapply Hlookup_fun; do 10 (eapply in_cons); eapply in_eq.
Qed.
