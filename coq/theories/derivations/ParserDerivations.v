From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.parsing.Parser.
Require Import impboot.imp2asm.ImpToASMCodegen.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import automation.ltac2.Stdlib2.
From impboot Require Import commons.CompilerUtils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
Require Import impboot.automation.RelCompiler.
Require Import impboot.automation.ltac2.UnfoldFix.
Require Import impboot.automation.AutomationLemmas.
From impboot.fp2imp Require Import FpToImpCodegen.
Require Import coqutil.Word.Interface.
Require Import ZArith.
From Stdlib Require Import FunInd.
From Stdlib Require Import derive.Derive.
From Stdlib Require Import Lia.
From Ltac2 Require Import Ltac2.

From impboot Require Import derivations.CompilerUtilsDerivations.

(* lexing *)

Derive read_num_numeric_prog
  in ltac2:(relcompile_tpe 'read_num_numeric_prog 'read_num_numeric ['mul_N_10])
  as read_num_numeric_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [read_num_numeric_prog].
Ltac2 Eval assert_Some constr:(to_funs [read_num_numeric_prog]).

Derive read_num_alpha_prog
  in ltac2:(relcompile_tpe 'read_num_alpha_prog 'read_num_alpha ['mul_N_256])
  as read_num_alpha_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [read_num_alpha_prog].
Ltac2 Eval assert_Some constr:(to_funs [read_num_alpha_prog]).

Derive end_line_prog
  in ltac2:(relcompile_tpe 'end_line_prog 'end_line [])
  as end_line_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [end_line_prog].
Ltac2 Eval assert_Some constr:(to_funs [end_line_prog]).

Derive q_from_nat_prog
  in ltac2:(relcompile_tpe 'q_from_nat_prog 'q_from_nat [])
  as q_from_nat_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [q_from_nat_prog].
Ltac2 Eval assert_Some constr:(to_funs [q_from_nat_prog]).

Derive lex_prog
  in ltac2:(relcompile_tpe 'lex_prog 'lex ['end_line; 'read_num_numeric; 'read_num_alpha; 'q_from_nat; '@list_length])
  as lex_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [lex_prog].
Ltac2 Eval assert_Some constr:(to_funs [lex_prog]).

Derive lexer_i_prog
  in ltac2:(relcompile_tpe 'lexer_i_prog 'lexer_i ['@lex; '@list_length])
  as lexer_i_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [lexer_i_prog].
Ltac2 Eval assert_Some constr:(to_funs [lexer_i_prog]).

Derive lexer_prog
  in ltac2:(relcompile_tpe 'lexer_prog 'lexer ['lexer_i])
  as lexer_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [lexer_prog].
Ltac2 Eval assert_Some constr:(to_funs [lexer_prog]).

(* FunValues *)

Derive vcons_prog
  in ltac2:(relcompile_tpe 'vcons_prog 'vcons [])
  as vcons_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vcons_prog].
Ltac2 Eval assert_Some constr:(to_funs [vcons_prog]).

Derive vhead_prog
  in ltac2:(relcompile_tpe 'vhead_prog 'vhead [])
  as vhead_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vhead_prog].
Ltac2 Eval assert_Some constr:(to_funs [vhead_prog]).

Theorem vlist_equation: ltac2:(unfold_fix_type '@vlist).
Proof. unfold_fix_proof '@vlist. Qed.
Derive vlist_prog
  in ltac2:(relcompile_tpe 'vlist_prog 'vlist ['vcons])
  as vlist_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vlist_prog].
Ltac2 Eval assert_Some constr:(to_funs [vlist_prog]).

Theorem vis_upper_f_equation: ltac2:(unfold_fix_type '@vis_upper_f).
Proof. unfold_fix_proof '@vis_upper_f. Qed.
Derive vis_upper_f_prog
  in ltac2:(relcompile_tpe 'vis_upper_f_prog 'vis_upper_f [])
  as vis_upper_f_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.
Time Compute to_funs [vis_upper_f_prog].
Ltac2 Eval assert_Some constr:(to_funs [vis_upper_f_prog]).

Derive vis_upper_prog
  in ltac2:(relcompile_tpe 'vis_upper_prog 'vis_upper ['vis_upper_f])
  as vis_upper_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vis_upper_prog].
Ltac2 Eval assert_Some constr:(to_funs [vis_upper_prog]).

Derive vgetNum_prog
  in ltac2:(relcompile_tpe 'vgetNum_prog 'vgetNum [])
  as vgetNum_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vgetNum_prog].
Ltac2 Eval assert_Some constr:(to_funs [vgetNum_prog]).

Derive vel0_prog
  in ltac2:(relcompile_tpe 'vel0_prog 'vel0 ['vhead])
  as vel0_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vel0_prog].
Ltac2 Eval assert_Some constr:(to_funs [vel0_prog]).

Derive vel1_prog
  in ltac2:(relcompile_tpe 'vel1_prog 'vel1 ['vhead; 'vtail])
  as vel1_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vel1_prog].
Ltac2 Eval assert_Some constr:(to_funs [vel1_prog]).

Derive vel2_prog
  in ltac2:(relcompile_tpe 'vel2_prog 'vel2 ['vel1; 'vtail])
  as vel2_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vel2_prog].
Ltac2 Eval assert_Some constr:(to_funs [vel2_prog]).

Derive vel3_prog
  in ltac2:(relcompile_tpe 'vel3_prog 'vel3 ['vel2; 'vtail])
  as vel3_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vel3_prog].
Ltac2 Eval assert_Some constr:(to_funs [vel3_prog]).

Derive vtail_prog
  in ltac2:(relcompile_tpe 'vtail_prog 'vtail [])
  as vtail_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vtail_prog].
Ltac2 Eval assert_Some constr:(to_funs [vtail_prog]).

Derive visNum_prog
  in ltac2:(relcompile_tpe 'visNum_prog 'visNum [])
  as visNum_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [visNum_prog].
Ltac2 Eval assert_Some constr:(to_funs [visNum_prog]).

Derive visPair_prog
  in ltac2:(relcompile_tpe 'visPair_prog 'visPair [])
  as visPair_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [visPair_prog].
Ltac2 Eval assert_Some constr:(to_funs [visPair_prog]).

(* parsing *)

Derive quote_prog
  in ltac2:(relcompile_tpe 'quote_prog 'quote ['vlist])
  as quote_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [quote_prog].
Ltac2 Eval assert_Some constr:(to_funs [quote_prog]).

Derive parse_prog
  in ltac2:(relcompile_tpe 'parse_prog 'parse ['vhead; 'quote])
  as parse_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [parse_prog].
Ltac2 Eval assert_Some constr:(to_funs [parse_prog]).

(* converting from v to prog *)

Derive v2list_prog
  in ltac2:(relcompile_tpe 'v2list_prog 'v2list [])
  as v2list_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [v2list_prog].
Ltac2 Eval assert_Some constr:(to_funs [v2list_prog]).

Derive num2exp_prog
  in ltac2:(relcompile_tpe 'num2exp_prog 'num2exp ['vis_upper])
  as num2exp_prog_proof.
Proof.
  time relcompile.
  rewrite N.ltb_ge in *; ltac1:(lia).
Qed.
Time Compute to_funs [num2exp_prog].
Ltac2 Eval assert_Some constr:(to_funs [num2exp_prog]).

Derive v2exp_prog
  in ltac2:(relcompile_tpe 'v2exp_prog 'v2exp ['vgetNum; 'vel0; 'num2exp])
  as v2exp_prog_proof.
Proof.
  time relcompile.
  rewrite N.ltb_ge in *; ltac1:(lia).
Qed.
Time Compute to_funs [v2exp_prog].
Ltac2 Eval assert_Some constr:(to_funs [v2exp_prog]).

Derive vs2exps_prog
  in ltac2:(relcompile_tpe 'vs2exps_prog 'vs2exps ['v2exp])
  as vs2exps_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vs2exps_prog].
Ltac2 Eval assert_Some constr:(to_funs [vs2exps_prog]).

Derive v2cmp_prog
  in ltac2:(relcompile_tpe 'v2cmp_prog 'v2cmp ['vgetNum])
  as v2cmp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [v2cmp_prog].
Ltac2 Eval assert_Some constr:(to_funs [v2cmp_prog]).

Derive v2test_prog
  in ltac2:(relcompile_tpe 'v2test_prog 'v2test ['vgetNum; 'v2cmp; 'v2exp])
  as v2test_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [v2test_prog].
Ltac2 Eval assert_Some constr:(to_funs [v2test_prog]).

Derive v2cmd_prog
  in ltac2:(relcompile_tpe 'v2cmd_prog 'v2cmd ['vgetNum; 'v2exp; 'v2test; 'v2list; 'vs2exps; 'visNum; 'visPair])
  as v2cmd_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [v2cmd_prog].
Ltac2 Eval assert_Some constr:(to_funs [v2cmd_prog]).

Derive vs2args_prog
  in ltac2:(relcompile_tpe 'vs2args_prog 'vs2args ['vgetNum])
  as vs2args_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vs2args_prog].
Ltac2 Eval assert_Some constr:(to_funs [vs2args_prog]).

Derive v2func_prog
  in ltac2:(relcompile_tpe 'v2func_prog 'v2func ['vel1; 'vel2; 'vel3; 'vgetNum; 'v2list; 'vs2args; 'v2cmd])
  as v2func_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [v2func_prog].
Ltac2 Eval assert_Some constr:(to_funs [v2func_prog]).

Derive v2funcs_prog
  in ltac2:(relcompile_tpe 'v2funcs_prog 'v2funcs ['v2func])
  as v2funcs_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [v2funcs_prog].
Ltac2 Eval assert_Some constr:(to_funs [v2funcs_prog]).

Derive vs2prog_prog
  in ltac2:(relcompile_tpe 'vs2prog_prog 'vs2prog ['v2funcs])
  as vs2prog_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [vs2prog_prog].
Ltac2 Eval assert_Some constr:(to_funs [vs2prog_prog]).

(* entire parser *)

Derive parser_prog
  in ltac2:(relcompile_tpe 'parser_prog 'parser ['parse; 'v2list; 'vs2prog])
  as parser_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [parser_prog].
Ltac2 Eval assert_Some constr:(to_funs [parser_prog]).

Derive str2imp_prog
  in ltac2:(relcompile_tpe 'str2imp_prog 'str2imp ['lexer; 'parser])
  as str2imp_prog_proof.
Proof.
  time relcompile.
Qed.
Time Compute to_funs [str2imp_prog].
Ltac2 Eval assert_Some constr:(to_funs [str2imp_prog]).

Definition ParserDerivations_funs := [
  read_num_numeric_prog;
  read_num_alpha_prog;
  end_line_prog;
  q_from_nat_prog;
  lex_prog;
  lexer_i_prog;
  lexer_prog;
  vcons_prog;
  vhead_prog;
  vlist_prog;
  vis_upper_f_prog;
  vis_upper_prog;
  vgetNum_prog;
  vtail_prog;
  vel0_prog;
  vel1_prog;
  vel2_prog;
  vel3_prog;
  visNum_prog;
  visPair_prog;
  quote_prog;
  parse_prog;
  v2list_prog;
  num2exp_prog;
  v2exp_prog;
  vs2exps_prog;
  v2cmp_prog;
  v2test_prog;
  v2cmd_prog;
  vs2args_prog;
  v2func_prog;
  v2funcs_prog;
  vs2prog_prog;
  parser_prog;
  str2imp_prog
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

Theorem str2imp_thm:
  ∀ (s: state) (inp: list ascii),
    (∀ fname args fn,
      In (FunSyntax.Defun fname args fn) (CompilerUtils_funs) →
      lookup_fun fname (funs s) = Some (args, fn)) ->
    (∀ fname args fn,
      In (FunSyntax.Defun fname args fn) (ParserDerivations_funs) →
      lookup_fun fname (funs s) = Some (args, fn)) ->
    eval_app (name_enc "str2imp") [encode inp] s ((encode (str2imp inp)), s).
Proof.
  Opaque encode.
  intros * Hlookup_fun_utils Hlookup_fun.
  assert_eval_app_compiler_utils 'Hlookup_fun_utils.

  assert_eval_app_by 'read_num_numeric 'read_num_numeric_prog_proof 'Hlookup_fun 0.
  assert_eval_app_by 'read_num_alpha 'read_num_alpha_prog_proof 'Hlookup_fun 1.
  assert_eval_app_by 'end_line 'end_line_prog_proof 'Hlookup_fun 2.
  assert_eval_app_by 'q_from_nat 'q_from_nat_prog_proof 'Hlookup_fun 3.
  assert_eval_app_by 'lex 'lex_prog_proof 'Hlookup_fun 4.
  assert_eval_app_by 'lexer_i 'lexer_i_prog_proof 'Hlookup_fun 5.
  assert_eval_app_by 'lexer 'lexer_prog_proof 'Hlookup_fun 6.
  assert_eval_app_by 'vcons 'vcons_prog_proof 'Hlookup_fun 7.
  assert_eval_app_by 'vhead 'vhead_prog_proof 'Hlookup_fun 8.
  assert_eval_app_by 'vlist 'vlist_prog_proof 'Hlookup_fun 9.
  assert_eval_app_by 'vis_upper_f 'vis_upper_f_prog_proof 'Hlookup_fun 10.
  assert_eval_app_by 'vis_upper 'vis_upper_prog_proof 'Hlookup_fun 11.
  assert_eval_app_by 'vgetNum 'vgetNum_prog_proof 'Hlookup_fun 12.
  assert_eval_app_by 'vtail 'vtail_prog_proof 'Hlookup_fun 13.
  assert_eval_app_by 'vel0 'vel0_prog_proof 'Hlookup_fun 14.
  assert_eval_app_by 'vel1 'vel1_prog_proof 'Hlookup_fun 15.
  assert_eval_app_by 'vel2 'vel2_prog_proof 'Hlookup_fun 16.
  assert_eval_app_by 'vel3 'vel3_prog_proof 'Hlookup_fun 17.
  assert_eval_app_by 'visNum 'visNum_prog_proof 'Hlookup_fun 18.
  assert_eval_app_by 'visPair 'visPair_prog_proof 'Hlookup_fun 19.
  assert_eval_app_by 'quote 'quote_prog_proof 'Hlookup_fun 20.
  assert_eval_app_by 'parse 'parse_prog_proof 'Hlookup_fun 21.
  assert_eval_app_by 'v2list 'v2list_prog_proof 'Hlookup_fun 22.
  assert_eval_app_by 'num2exp 'num2exp_prog_proof 'Hlookup_fun 23.
  assert_eval_app_by 'v2exp 'v2exp_prog_proof 'Hlookup_fun 24.
  assert_eval_app_by 'vs2exps 'vs2exps_prog_proof 'Hlookup_fun 25.
  assert_eval_app_by 'v2cmp 'v2cmp_prog_proof 'Hlookup_fun 26.
  assert_eval_app_by 'v2test 'v2test_prog_proof 'Hlookup_fun 27.
  assert_eval_app_by 'v2cmd 'v2cmd_prog_proof 'Hlookup_fun 28.
  assert_eval_app_by 'vs2args 'vs2args_prog_proof 'Hlookup_fun 29.
  assert_eval_app_by 'v2func 'v2func_prog_proof 'Hlookup_fun 30.
  assert_eval_app_by 'v2funcs 'v2funcs_prog_proof 'Hlookup_fun 31.
  assert_eval_app_by 'vs2prog 'vs2prog_prog_proof 'Hlookup_fun 32.
  assert_eval_app_by 'parser 'parser_prog_proof 'Hlookup_fun 33.
  assert_eval_app_by 'str2imp 'str2imp_prog_proof 'Hlookup_fun 34.
  eauto.
Qed.
