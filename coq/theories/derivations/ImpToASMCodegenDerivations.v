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
Require Import impboot.automation.ltac2.Stdlib2.
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
  in ltac2:(relcompile_tpe 'init_prog 'init ['@list_app; 'str_app]) 
  as init_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [init_prog].
(* TODO: I use eval_cbv in assert_Some and it doesn't terminate (eval_lazy also didn't work) *)
(* Ltac2 Eval assert_Some constr:(to_funs [init_prog]). *)

Derive c_assign_prog 
  in ltac2:(relcompile_tpe 'c_assign_prog 'c_assign ['index_of]) 
  as c_assign_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_assign_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_assign_prog]). *)

Derive give_up_prog 
  in ltac2:(relcompile_tpe 'give_up_prog 'give_up []) 
  as give_up_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [give_up_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [give_up_prog]). *)

Derive abortLoc_prog
  in ltac2:(relcompile_tpe 'abortLoc_prog 'abortLoc []) 
  as abortLoc_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [abortLoc_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [abortLoc_prog]). *)

Derive c_const_prog
  in ltac2:(relcompile_tpe 'c_const_prog 'c_const []) 
  as c_const_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_const_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_const_prog]). *)

Derive even_len_prog 
  in ltac2:(relcompile_tpe 'even_len_prog '@even_len []) 
  as even_len_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [even_len_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [even_len_prog]). *)

Derive odd_len_prog 
  in ltac2:(relcompile_tpe 'odd_len_prog '@odd_len []) 
  as odd_len_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [odd_len_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [odd_len_prog]). *)

Derive index_of_prog 
  in ltac2:(relcompile_tpe 'index_of_prog 'index_of []) 
  as index_of_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [index_of_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [index_of_prog]). *)

Derive c_var_prog 
  in ltac2:(relcompile_tpe 'c_var_prog 'c_var ['index_of]) 
  as c_var_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_var_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_var_prog]). *)

Derive all_bdrs_prog 
  in ltac2:(relcompile_tpe 'all_bdrs_prog 'all_bdrs ['@list_app]) 
  as all_bdrs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [all_bdrs_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [all_bdrs_prog]). *)

Derive names_in_prog 
  in ltac2:(relcompile_tpe 'names_in_prog 'names_in []) 
  as names_in_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [names_in_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [names_in_prog]). *)

Derive nms_uniq_prog 
  in ltac2:(relcompile_tpe 'nms_uniq_prog 'nms_uniq ['names_in]) 
  as nms_uniq_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [nms_uniq_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [nms_uniq_prog]). *)

Derive bdrs_unq_prog 
  in ltac2:(relcompile_tpe 'bdrs_unq_prog 'bdrs_unq ['all_bdrs; 'nms_uniq]) 
  as bdrs_unq_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [bdrs_unq_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [bdrs_unq_prog]). *)

Derive bdrs_vs_prog 
  in ltac2:(relcompile_tpe 'bdrs_vs_prog 'bdrs_vs []) 
  as bdrs_vs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [bdrs_vs_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [bdrs_vs_prog]). *)

Derive fltr_nms_prog 
  in ltac2:(relcompile_tpe 'fltr_nms_prog 'fltr_nms []) 
  as fltr_nms_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [fltr_nms_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [fltr_nms_prog]). *)

Derive rm_nms_prog 
  in ltac2:(relcompile_tpe 'rm_nms_prog 'rm_nms ['fltr_nms]) 
  as rm_nms_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [rm_nms_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [rm_nms_prog]). *)

Derive call_vs_prog 
  in ltac2:(relcompile_tpe 'call_vs_prog 'call_vs []) 
  as call_vs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [call_vs_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [call_vs_prog]). *)

Derive push_vs_prog 
  in ltac2:(relcompile_tpe 'push_vs_prog 'push_vs ['@list_len; 'call_vs]) 
  as push_vs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [push_vs_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [push_vs_prog]). *)

Derive vs_bdrs_prog
  in ltac2:(relcompile_tpe 'vs_bdrs_prog 'vs_bdrs ['@even_len; '@list_app])
  as vs_bdrs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vs_bdrs_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [vs_bdrs_prog]). *)

Derive c_bdrs_prog 
  in ltac2:(relcompile_tpe 'c_bdrs_prog 'c_bdrs
    ['bdrs_unq; 'rm_nms; 'bdrs_vs; '@list_app; 'push_vs; '@even_len; '@list_len; 'vs_bdrs]) 
  as c_bdrs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_bdrs_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_bdrs_prog]). *)

Derive c_add_prog 
  in ltac2:(relcompile_tpe 'c_add_prog 'c_add []) 
  as c_add_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_add_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_add_prog]). *)

Derive c_sub_prog 
  in ltac2:(relcompile_tpe 'c_sub_prog 'c_sub []) 
  as c_sub_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_sub_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_sub_prog]). *)

Derive c_div_prog 
  in ltac2:(relcompile_tpe 'c_div_prog 'c_div []) 
  as c_div_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_div_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_div_prog]). *)

Derive c_alloc_prog
  in ltac2:(relcompile_tpe 'c_alloc_prog 'c_alloc ['@even_len]) 
  as c_alloc_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_alloc_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_alloc_prog]). *)

Derive c_read_prog
  in ltac2:(relcompile_tpe 'c_read_prog 'c_read ['@even_len; '@appl_len]) 
  as c_read_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_read_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_read_prog]). *)

Derive c_write_prog 
  in ltac2:(relcompile_tpe 'c_write_prog 'c_write ['@even_len; '@appl_len]) 
  as c_write_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_write_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_write_prog]). *)

Derive c_load_prog 
  in ltac2:(relcompile_tpe 'c_load_prog 'c_load []) 
  as c_load_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_load_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_load_prog]). *)

Derive c_store_prog 
  in ltac2:(relcompile_tpe 'c_store_prog 'c_store ['@list_app])
  as c_store_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_store_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_store_prog]). *)

Derive c_exp_prog 
  in ltac2:(relcompile_tpe 'c_exp_prog 'c_exp ['c_var; 'c_const; 'c_add; 'c_sub; 'c_div; 'c_load; '@appl_len]) 
  as c_exp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_exp_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_exp_prog]). *)

Derive c_exps_prog 
  in ltac2:(relcompile_tpe 'c_exps_prog 'c_exps ['c_exp]) 
  as c_exps_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_exps_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_exps_prog]). *)

Derive c_cmp_prog 
  in ltac2:(relcompile_tpe 'c_cmp_prog 'c_cmp []) 
  as c_cmp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_cmp_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_cmp_prog]). *)

Derive c_test_prog 
  in ltac2:(relcompile_tpe 'c_test_prog 'c_test ['c_exp; 'c_cmp; '@appl_len; '@list_app]) 
  as c_test_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_test_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_test_prog]). *)

Derive lookup_prog 
  in ltac2:(relcompile_tpe 'lookup_prog 'lookup []) 
  as lookup_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [lookup_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [lookup_prog]). *)

Derive make_ret_prog 
  in ltac2:(relcompile_tpe 'make_ret_prog 'make_ret ['@list_len]) 
  as make_ret_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [make_ret_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [make_ret_prog]). *)

Derive c_pops_prog 
  in ltac2:(relcompile_tpe 'c_pops_prog 'c_pops ['give_up; '@even_len; '@list_len]) 
  as c_pops_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_pops_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_pops_prog]). *)

Derive c_pushes_prog 
  in ltac2:(relcompile_tpe 'c_pushes_prog 'c_pushes ['call_vs; '@list_len; 'push_vs]) 
  as c_pushes_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_pushes_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_pushes_prog]). *)

Derive c_call_prog 
  in ltac2:(relcompile_tpe 'c_call_prog 'c_call ['c_pops; '@even_len; '@appl_len]) 
  as c_call_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_call_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_call_prog]). *)

Derive c_cmd_prog 
  in ltac2:(relcompile_tpe 'c_cmd_prog 'c_cmd 
    ['c_exp; 'c_assign; 'c_store; 'c_test; 'c_exps; 'c_call; 
     'c_var; 'make_ret; 'c_alloc; 'c_read; 'c_write; 'abortLoc; 'lookup;
     '@odd_len; '@appl_len])
  as c_cmd_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_cmd_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_cmd_prog]). *)

Derive c_fundef_prog 
  in ltac2:(relcompile_tpe 'c_fundef_prog 'c_fundef 
    ['c_pushes; 'bdrs_unq; 'bdrs_vs; 'c_cmd; '@list_len; '@list_app; '@even_len; 'c_bdrs; '@appl_len]) 
  as c_fundef_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_fundef_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_fundef_prog]). *)

Derive get_funs_prog 
  in ltac2:(relcompile_tpe 'get_funs_prog 'get_funs []) 
  as get_funs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [get_funs_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [get_funs_prog]). *)

Derive func_nm_prog 
  in ltac2:(relcompile_tpe 'func_nm_prog 'func_nm []) 
  as func_nm_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [func_nm_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [func_nm_prog]). *)

Derive c_fndefs_prog 
  in ltac2:(relcompile_tpe 'c_fndefs_prog 'c_fndefs ['c_fundef; 'func_nm; 'N2asciid])
  as c_fndefs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [c_fndefs_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [c_fndefs_prog]). *)

Derive codegen_prog 
  in ltac2:(relcompile_tpe 'codegen_prog 'codegen ['c_fndefs; 'lookup; 'init; 'get_funs; '@appl_len; '@flatten]) 
  as codegen_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [codegen_prog].
(* Ltac2 Eval assert_Some constr:(to_funs [codegen_prog]). *)

Definition ImpToASMCodegen_funs := [
  give_up_prog;
  abortLoc_prog;
  c_const_prog;
  even_len_prog;
  odd_len_prog;
  index_of_prog;
  c_var_prog;
  c_assign_prog;
  all_bdrs_prog;
  names_in_prog;
  nms_uniq_prog;
  bdrs_unq_prog;
  bdrs_vs_prog;
  fltr_nms_prog;
  rm_nms_prog;
  call_vs_prog;
  push_vs_prog;
  vs_bdrs_prog;
  c_bdrs_prog;
  c_add_prog;
  c_sub_prog;
  c_div_prog;
  c_load_prog;
  c_exp_prog;
  c_exps_prog;
  c_cmp_prog;
  c_test_prog;
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
  get_funs_prog;
  func_nm_prog;
  c_fndefs_prog;
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
  assert_eval_app_by 'c_var 'c_var_prog_proof 'Hlookup_fun 6.
  assert_eval_app_by 'c_assign 'c_assign_prog_proof 'Hlookup_fun 7.
  assert_eval_app_by 'all_bdrs 'all_bdrs_prog_proof 'Hlookup_fun 8.
  assert_eval_app_by 'names_in 'names_in_prog_proof 'Hlookup_fun 9.
  assert_eval_app_by 'nms_uniq 'nms_uniq_prog_proof 'Hlookup_fun 10.
  assert_eval_app_by 'bdrs_unq 'bdrs_unq_prog_proof 'Hlookup_fun 11.
  assert_eval_app_by 'bdrs_vs 'bdrs_vs_prog_proof 'Hlookup_fun 12.
  assert_eval_app_by 'fltr_nms 'fltr_nms_prog_proof 'Hlookup_fun 13.
  assert_eval_app_by 'rm_nms 'rm_nms_prog_proof 'Hlookup_fun 14.
  assert_eval_app_by 'call_vs 'call_vs_prog_proof 'Hlookup_fun 15.
  assert_eval_app_by 'push_vs 'push_vs_prog_proof 'Hlookup_fun 16.
  assert_eval_app_by 'vs_bdrs 'vs_bdrs_prog_proof 'Hlookup_fun 17.
  assert_eval_app_by 'c_bdrs 'c_bdrs_prog_proof 'Hlookup_fun 18.
  assert_eval_app_by 'c_add 'c_add_prog_proof 'Hlookup_fun 19.
  assert_eval_app_by 'c_sub 'c_sub_prog_proof 'Hlookup_fun 20.
  assert_eval_app_by 'c_div 'c_div_prog_proof 'Hlookup_fun 21.
  assert_eval_app_by 'c_load 'c_load_prog_proof 'Hlookup_fun 22.
  assert_eval_app_by 'c_exp 'c_exp_prog_proof 'Hlookup_fun 23.
  assert_eval_app_by 'c_exps 'c_exps_prog_proof 'Hlookup_fun 24.
  assert_eval_app_by 'c_cmp 'c_cmp_prog_proof 'Hlookup_fun 25.
  assert_eval_app_by 'c_test 'c_test_prog_proof 'Hlookup_fun 26.
  assert_eval_app_by 'c_alloc 'c_alloc_prog_proof 'Hlookup_fun 27.
  assert_eval_app_by 'c_read 'c_read_prog_proof 'Hlookup_fun 28.
  assert_eval_app_by 'c_write 'c_write_prog_proof 'Hlookup_fun 29.
  assert_eval_app_by 'c_store 'c_store_prog_proof 'Hlookup_fun 30.
  assert_eval_app_by 'lookup 'lookup_prog_proof 'Hlookup_fun 31.
  assert_eval_app_by 'make_ret 'make_ret_prog_proof 'Hlookup_fun 32.
  assert_eval_app_by 'c_pops 'c_pops_prog_proof 'Hlookup_fun 33.
  assert_eval_app_by 'c_pushes 'c_pushes_prog_proof 'Hlookup_fun 34.
  assert_eval_app_by 'c_call 'c_call_prog_proof 'Hlookup_fun 35.
  assert_eval_app_by 'c_cmd 'c_cmd_prog_proof 'Hlookup_fun 36.
  assert_eval_app_by 'c_fundef 'c_fundef_prog_proof 'Hlookup_fun 37.
  assert_eval_app_by 'get_funs 'get_funs_prog_proof 'Hlookup_fun 38.
  assert_eval_app_by 'func_nm 'func_nm_prog_proof 'Hlookup_fun 39.
  assert_eval_app_by 'c_fndefs 'c_fndefs_prog_proof 'Hlookup_fun 40.
  assert_eval_app_by 'init 'init_prog_proof 'Hlookup_fun 41.
  assert_eval_app_by 'codegen 'codegen_prog_proof 'Hlookup_fun 42.
  eauto.
Qed.
