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
  give_up_prog;                (* 0 *)
  abortLoc_prog;               (* 1 *)
  c_const_prog;                (* 2 *)
  even_len_prog;               (* 3 *)
  odd_len_prog;                (* 4 *)
  index_of_prog;               (* 5 *)
  index_of_opt_prog;           (* 6 *)
  c_var_prog;                  (* 7 *) (* depends on index_of *)
  c_assign_prog;               (* 8 *) (* depends on index_of *)
  all_binders_prog;            (* 9 *)
  names_contain_prog;          (* 10 *)
  names_unique_prog;           (* 11 *) (* depends on names_contain *)
  unique_binders_prog;         (* 12 *) (* depends on all_binders, names_unique *)
  make_vs_from_binders_prog;   (* 13 *)
  filter_name_prog;            (* 14 *)
  remove_names_prog;           (* 15 *) (* depends on filter_name *)
  call_v_stack_prog;           (* 16 *)
  c_pushes_vs_prog;            (* 17 *) (* depends on call_v_stack *)
  c_declare_binders_prog;      (* 18 *) (* depends on unique_binders, remove_names, make_vs_from_binders, c_pushes_vs, even_len *)
  c_add_prog;                  (* 19 *)
  c_sub_prog;                  (* 20 *)
  c_div_prog;                  (* 21 *)
  c_load_prog;                 (* 22 *)
  c_exp_prog;                  (* 23 *) (* depends on c_var, c_const, c_add, c_sub, c_div, c_load *)
  c_exps_prog;                 (* 24 *) (* depends on c_exp *)
  c_cmp_prog;                  (* 25 *)
  c_test_jump_prog;            (* 26 *) (* depends on c_exp, c_cmp *)
  c_alloc_prog;                (* 27 *) (* depends on even_len *)
  c_read_prog;                 (* 28 *) (* depends on even_len *)
  c_write_prog;                (* 29 *) (* depends on even_len *)
  c_store_prog;                (* 30 *)
  lookup_prog;                 (* 31 *)
  make_ret_prog;               (* 32 *)
  c_pops_prog;                 (* 33 *) (* depends on give_up, even_len *)
  c_pushes_prog;               (* 34 *) (* depends on call_v_stack, c_pushes_vs *)
  c_call_prog;                 (* 35 *) (* depends on c_pops, even_len *)
  c_cmd_prog;                  (* 36 *) (* depends on c_exp, c_assign, c_store, c_test_jump, c_exps, c_call, c_var, make_ret, c_alloc, c_read, c_write, abortLoc, lookup, odd_len *)
  c_fundef_prog;               (* 37 *) (* depends on c_pushes, unique_binders, make_vs_from_binders, c_cmd, even_len, c_declare_binders *)
  get_funcs_prog;              (* 38 *)
  name_of_func_prog;           (* 39 *)
  c_fundefs_prog;              (* 40 *) (* depends on c_fundef, name_of_func *)
  init_prog;                   (* 41 *)
  codegen_prog                 (* 42 *) (* depends on c_fundefs, lookup, init, get_funcs, flatten *)
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
  assert_eval_app_by 'c_declare_binders 'c_declare_binders_prog_proof 'Hlookup_fun 18.
  assert_eval_app_by 'c_add 'c_add_prog_proof 'Hlookup_fun 19.
  assert_eval_app_by 'c_sub 'c_sub_prog_proof 'Hlookup_fun 20.
  assert_eval_app_by 'c_div 'c_div_prog_proof 'Hlookup_fun 21.
  assert_eval_app_by 'c_load 'c_load_prog_proof 'Hlookup_fun 22.
  assert_eval_app_by 'c_exp 'c_exp_prog_proof 'Hlookup_fun 23.
  assert_eval_app_by 'c_exps 'c_exps_prog_proof 'Hlookup_fun 24.
  assert_eval_app_by 'c_cmp 'c_cmp_prog_proof 'Hlookup_fun 25.
  assert_eval_app_by 'c_test_jump 'c_test_jump_prog_proof 'Hlookup_fun 26.
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
  assert_eval_app_by 'get_funcs 'get_funcs_prog_proof 'Hlookup_fun 38.
  assert_eval_app_by 'name_of_func 'name_of_func_prog_proof 'Hlookup_fun 39.
  assert_eval_app_by 'c_fundefs 'c_fundefs_prog_proof 'Hlookup_fun 40.
  assert_eval_app_by 'init 'init_prog_proof 'Hlookup_fun 41.
  assert_eval_app_by 'codegen 'codegen_prog_proof 'Hlookup_fun 42.
  eauto.
Qed.
