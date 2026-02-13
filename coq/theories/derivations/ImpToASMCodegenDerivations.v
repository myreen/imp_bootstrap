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
From impboot.automation Require Import RelCompiler Ltac2Utils AutomationLemmas ToANF RelCompilerCommons.
Require Import impboot.automation.ltac2.UnfoldFix.
Require Import impboot.commons.CompilerUtils.
From impboot Require Import fp2imp.FpToImpCodegen.
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
Time Compute to_funs [init_prog].

Derive c_assign_prog 
  in ltac2:(relcompile_tpe 'c_assign_prog 'c_assign ['index_of]) 
  as c_assign_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_assign_prog].

Derive give_up_prog 
  in ltac2:(relcompile_tpe 'give_up_prog 'give_up []) 
  as give_up_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [give_up_prog].

Derive abortLoc_prog
  in ltac2:(relcompile_tpe 'abortLoc_prog 'abortLoc []) 
  as abortLoc_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [abortLoc_prog].

Derive c_const_prog
  in ltac2:(relcompile_tpe 'c_const_prog 'c_const []) 
  as c_const_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_const_prog].

Derive even_len_prog 
  in ltac2:(relcompile_tpe 'even_len_prog '@even_len []) 
  as even_len_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [even_len_prog].

Derive odd_len_prog 
  in ltac2:(relcompile_tpe 'odd_len_prog '@odd_len []) 
  as odd_len_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [odd_len_prog].

Derive index_of_prog 
  in ltac2:(relcompile_tpe 'index_of_prog 'index_of []) 
  as index_of_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [index_of_prog].

Derive index_of_opt_prog 
  in ltac2:(relcompile_tpe 'index_of_opt_prog 'index_of_opt []) 
  as index_of_opt_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [index_of_opt_prog].

Derive c_var_prog 
  in ltac2:(relcompile_tpe 'c_var_prog 'c_var ['index_of]) 
  as c_var_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_var_prog].

Derive all_binders_prog 
  in ltac2:(relcompile_tpe 'all_binders_prog 'all_binders ['@list_append]) 
  as all_binders_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [all_binders_prog].

Derive names_contain_prog 
  in ltac2:(relcompile_tpe 'names_contain_prog 'names_contain []) 
  as names_contain_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [names_contain_prog].

Derive names_unique_prog 
  in ltac2:(relcompile_tpe 'names_unique_prog 'names_unique ['names_contain]) 
  as names_unique_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [names_unique_prog].

Derive unique_binders_prog 
  in ltac2:(relcompile_tpe 'unique_binders_prog 'unique_binders ['all_binders; 'names_unique]) 
  as unique_binders_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [unique_binders_prog].

Derive make_vs_from_binders_prog 
  in ltac2:(relcompile_tpe 'make_vs_from_binders_prog 'make_vs_from_binders []) 
  as make_vs_from_binders_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [make_vs_from_binders_prog].

Derive filter_name_prog 
  in ltac2:(relcompile_tpe 'filter_name_prog 'filter_name []) 
  as filter_name_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [filter_name_prog].

Derive remove_names_prog 
  in ltac2:(relcompile_tpe 'remove_names_prog 'remove_names ['filter_name]) 
  as remove_names_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [remove_names_prog].

Derive call_v_stack_prog 
  in ltac2:(relcompile_tpe 'call_v_stack_prog 'call_v_stack []) 
  as call_v_stack_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [call_v_stack_prog].

Derive c_pushes_vs_prog 
  in ltac2:(relcompile_tpe 'c_pushes_vs_prog 'c_pushes_vs ['@list_length; 'call_v_stack]) 
  as c_pushes_vs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_pushes_vs_prog].

Derive get_vs_binders_prog
  in ltac2:(relcompile_tpe 'get_vs_binders_prog 'get_vs_binders ['@even_len; '@list_append])
  as get_vs_binders_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [get_vs_binders_prog].

Derive c_declare_binders_prog 
  in ltac2:(relcompile_tpe 'c_declare_binders_prog 'c_declare_binders
    ['unique_binders; 'remove_names; 'make_vs_from_binders; '@list_append; 'c_pushes_vs; '@even_len; '@list_length; 'get_vs_binders]) 
  as c_declare_binders_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_declare_binders_prog].

Derive c_add_prog 
  in ltac2:(relcompile_tpe 'c_add_prog 'c_add []) 
  as c_add_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_add_prog].

Derive c_sub_prog 
  in ltac2:(relcompile_tpe 'c_sub_prog 'c_sub []) 
  as c_sub_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_sub_prog].

Derive c_div_prog 
  in ltac2:(relcompile_tpe 'c_div_prog 'c_div []) 
  as c_div_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_div_prog].

Derive c_alloc_prog
  in ltac2:(relcompile_tpe 'c_alloc_prog 'c_alloc ['@even_len]) 
  as c_alloc_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_alloc_prog].

Derive c_read_prog
  in ltac2:(relcompile_tpe 'c_read_prog 'c_read ['@even_len; '@app_list_length]) 
  as c_read_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_read_prog].

Derive c_write_prog 
  in ltac2:(relcompile_tpe 'c_write_prog 'c_write ['@even_len; '@app_list_length]) 
  as c_write_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_write_prog].

Derive c_load_prog 
  in ltac2:(relcompile_tpe 'c_load_prog 'c_load []) 
  as c_load_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_load_prog].

Derive c_store_prog 
  in ltac2:(relcompile_tpe 'c_store_prog 'c_store ['@list_append])
  as c_store_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_store_prog].

Derive c_exp_prog 
  in ltac2:(relcompile_tpe 'c_exp_prog 'c_exp ['c_var; 'c_const; 'c_add; 'c_sub; 'c_div; 'c_load; '@app_list_length]) 
  as c_exp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_exp_prog].

Derive c_exps_prog 
  in ltac2:(relcompile_tpe 'c_exps_prog 'c_exps ['c_exp]) 
  as c_exps_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_exps_prog].

Derive c_cmp_prog 
  in ltac2:(relcompile_tpe 'c_cmp_prog 'c_cmp []) 
  as c_cmp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_cmp_prog].

Derive c_test_jump_prog 
  in ltac2:(relcompile_tpe 'c_test_jump_prog 'c_test_jump ['c_exp; 'c_cmp; '@app_list_length; '@list_append]) 
  as c_test_jump_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_test_jump_prog].

Derive lookup_prog 
  in ltac2:(relcompile_tpe 'lookup_prog 'lookup []) 
  as lookup_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [lookup_prog].

Derive make_ret_prog 
  in ltac2:(relcompile_tpe 'make_ret_prog 'make_ret ['@list_length]) 
  as make_ret_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [make_ret_prog].

Derive c_pops_prog 
  in ltac2:(relcompile_tpe 'c_pops_prog 'c_pops ['give_up; '@even_len; '@list_length]) 
  as c_pops_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_pops_prog].

Derive c_pushes_prog 
  in ltac2:(relcompile_tpe 'c_pushes_prog 'c_pushes ['call_v_stack; '@list_length; 'c_pushes_vs]) 
  as c_pushes_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_pushes_prog].

Derive c_call_prog 
  in ltac2:(relcompile_tpe 'c_call_prog 'c_call ['c_pops; '@even_len; '@app_list_length]) 
  as c_call_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_call_prog].

Derive c_cmd_prog 
  in ltac2:(relcompile_tpe 'c_cmd_prog 'c_cmd 
    ['c_exp; 'c_assign; 'c_store; 'c_test_jump; 'c_exps; 'c_call; 
     'c_var; 'make_ret; 'c_alloc; 'c_read; 'c_write; 'abortLoc; 'lookup;
     '@odd_len; '@app_list_length])
  as c_cmd_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_cmd_prog].

Derive c_fundef_prog 
  in ltac2:(relcompile_tpe 'c_fundef_prog 'c_fundef 
    ['c_pushes; 'unique_binders; 'make_vs_from_binders; 'c_cmd; '@list_length; '@list_append; '@even_len; 'c_declare_binders; '@app_list_length]) 
  as c_fundef_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_fundef_prog].

Derive get_funcs_prog 
  in ltac2:(relcompile_tpe 'get_funcs_prog 'get_funcs []) 
  as get_funcs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [get_funcs_prog].

Derive name_of_func_prog 
  in ltac2:(relcompile_tpe 'name_of_func_prog 'name_of_func []) 
  as name_of_func_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [name_of_func_prog].

Derive c_fundefs_prog 
  in ltac2:(relcompile_tpe 'c_fundefs_prog 'c_fundefs ['c_fundef; 'name_of_func; 'N2ascii_default])
  as c_fundefs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_fundefs_prog].

Derive codegen_prog 
  in ltac2:(relcompile_tpe 'codegen_prog 'codegen ['c_fundefs; 'lookup; 'init; 'get_funcs; '@app_list_length; '@flatten]) 
  as codegen_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [codegen_prog].

Definition ImpToASMCodegen_funs := [
  give_up_prog;                
  abortLoc_prog;               
  c_const_prog;                
  even_len_prog;               
  odd_len_prog;                
  index_of_prog;               
  index_of_opt_prog;           
  c_var_prog;                  
  c_assign_prog;               
  all_binders_prog;            
  names_contain_prog;          
  names_unique_prog;           
  unique_binders_prog;         
  make_vs_from_binders_prog;   
  filter_name_prog;            
  remove_names_prog;           
  call_v_stack_prog;           
  c_pushes_vs_prog;            
  get_vs_binders_prog;
  c_declare_binders_prog;      
  c_add_prog;                  
  c_sub_prog;                  
  c_div_prog;                  
  c_load_prog;                 
  c_exp_prog;                  
  c_exps_prog;                 
  c_cmp_prog;                  
  c_test_jump_prog;            
  c_alloc_prog;                
  c_read_prog;                 
  c_write_prog;                
  c_store_prog;                
  lookup_prog;                 
  make_ret_prog;               
  c_pops_prog;                 
  c_pushes_prog;               
  c_call_prog;                 
  c_cmd_prog;                  
  c_fundef_prog;               
  get_funcs_prog;              
  name_of_func_prog;           
  c_fundefs_prog;              
  init_prog;                   
  codegen_prog                 
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
  assert ($tpe) as ? by (
    (* print_full_goal (); *)
    eapply $prf; eauto; try (reflexivity);
    (* print_full_goal (); *)
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
  assert_eval_app_compiler_utils 'Hlookup_fun_utils.

  assert_eval_app_by 'give_up 'give_up_prog_proof 'Hlookup_fun 0.
  assert_eval_app_by 'abortLoc 'abortLoc_prog_proof 'Hlookup_fun 1.
  assert_eval_app_by 'c_const 'c_const_prog_proof 'Hlookup_fun 2.
  assert_eval_app_by '@even_len 'even_len_prog_proof 'Hlookup_fun 3.
  assert_eval_app_by '@odd_len 'odd_len_prog_proof 'Hlookup_fun 4.
  assert_eval_app_by 'index_of 'index_of_prog_proof 'Hlookup_fun 5.
  assert_eval_app_by 'index_of_opt 'index_of_opt_prog_proof 'Hlookup_fun 6.
  assert_eval_app_by 'c_var 'c_var_prog_proof 'Hlookup_fun 7.
  assert_eval_app_by 'c_assign 'c_assign_prog_proof 'Hlookup_fun 8.
  assert_eval_app_by 'all_binders 'all_binders_prog_proof 'Hlookup_fun 9.
  assert_eval_app_by 'names_contain 'names_contain_prog_proof 'Hlookup_fun 10.
  assert_eval_app_by 'names_unique 'names_unique_prog_proof 'Hlookup_fun 11.
  assert_eval_app_by 'unique_binders 'unique_binders_prog_proof 'Hlookup_fun 12.
  assert_eval_app_by 'make_vs_from_binders 'make_vs_from_binders_prog_proof 'Hlookup_fun 13.
  assert_eval_app_by 'filter_name 'filter_name_prog_proof 'Hlookup_fun 14.
  assert_eval_app_by 'remove_names 'remove_names_prog_proof 'Hlookup_fun 15.
  assert_eval_app_by 'call_v_stack 'call_v_stack_prog_proof 'Hlookup_fun 16.
  assert_eval_app_by 'c_pushes_vs 'c_pushes_vs_prog_proof 'Hlookup_fun 17.
  assert_eval_app_by 'get_vs_binders 'get_vs_binders_prog_proof 'Hlookup_fun 18.
  assert_eval_app_by 'c_declare_binders 'c_declare_binders_prog_proof 'Hlookup_fun 19.
  assert_eval_app_by 'c_add 'c_add_prog_proof 'Hlookup_fun 20.
  assert_eval_app_by 'c_sub 'c_sub_prog_proof 'Hlookup_fun 21.
  assert_eval_app_by 'c_div 'c_div_prog_proof 'Hlookup_fun 22.
  assert_eval_app_by 'c_load 'c_load_prog_proof 'Hlookup_fun 23.
  assert_eval_app_by 'c_exp 'c_exp_prog_proof 'Hlookup_fun 24.
  assert_eval_app_by 'c_exps 'c_exps_prog_proof 'Hlookup_fun 25.
  assert_eval_app_by 'c_cmp 'c_cmp_prog_proof 'Hlookup_fun 26.
  assert_eval_app_by 'c_test_jump 'c_test_jump_prog_proof 'Hlookup_fun 27.
  assert_eval_app_by 'c_alloc 'c_alloc_prog_proof 'Hlookup_fun 28.
  assert_eval_app_by 'c_read 'c_read_prog_proof 'Hlookup_fun 29.
  assert_eval_app_by 'c_write 'c_write_prog_proof 'Hlookup_fun 30.
  assert_eval_app_by 'c_store 'c_store_prog_proof 'Hlookup_fun 31.
  assert_eval_app_by 'lookup 'lookup_prog_proof 'Hlookup_fun 32.
  assert_eval_app_by 'make_ret 'make_ret_prog_proof 'Hlookup_fun 33.
  assert_eval_app_by 'c_pops 'c_pops_prog_proof 'Hlookup_fun 34.
  assert_eval_app_by 'c_pushes 'c_pushes_prog_proof 'Hlookup_fun 35.
  assert_eval_app_by 'c_call 'c_call_prog_proof 'Hlookup_fun 36.
  assert_eval_app_by 'c_cmd 'c_cmd_prog_proof 'Hlookup_fun 37.
  assert_eval_app_by 'c_fundef 'c_fundef_prog_proof 'Hlookup_fun 38.
  assert_eval_app_by 'get_funcs 'get_funcs_prog_proof 'Hlookup_fun 39.
  assert_eval_app_by 'name_of_func 'name_of_func_prog_proof 'Hlookup_fun 40.
  assert_eval_app_by 'c_fundefs 'c_fundefs_prog_proof 'Hlookup_fun 41.
  assert_eval_app_by 'init 'init_prog_proof 'Hlookup_fun 42.
  assert_eval_app_by 'codegen 'codegen_prog_proof 'Hlookup_fun 43.
  eauto.
Qed.
