From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.parsing.Parser.
Require Import impboot.imp2asm.ImpToASMCodegen.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import commons.CompilerUtils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
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

(* lexing *)

Derive read_num_prog
  in ltac2:(relcompile_tpe 'read_num_prog 'read_num ['mul_N])
  as read_num_prog_proof.
Proof.
  time relcompile.
Qed.

Derive end_line_prog
  in ltac2:(relcompile_tpe 'end_line_prog 'end_line [])
  as end_line_prog_proof.
Proof.
  time relcompile.
Qed.

Derive q_from_nat_prog
  in ltac2:(relcompile_tpe 'q_from_nat_prog 'q_from_nat [])
  as q_from_nat_prog_proof.
Proof.
  time relcompile.
Qed.

Derive lex_prog
  in ltac2:(relcompile_tpe 'lex_prog 'lex ['end_line; 'read_num; 'q_from_nat; '@list_length])
  as lex_prog_proof.
Proof.
  time relcompile.
Qed.

Derive lexer_i_prog
  in ltac2:(relcompile_tpe 'lexer_i_prog 'lexer_i ['@lex; '@list_length])
  as lexer_i_prog_proof.
Proof.
  time relcompile.
Qed.

Derive lexer_prog
  in ltac2:(relcompile_tpe 'lexer_prog 'lexer ['lexer_i])
  as lexer_prog_proof.
Proof.
  time relcompile.
Qed.

(* FunValues *)

Derive vcons_prog
  in ltac2:(relcompile_tpe 'vcons_prog 'vcons [])
  as vcons_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vhead_prog
  in ltac2:(relcompile_tpe 'vhead_prog 'vhead [])
  as vhead_prog_proof.
Proof.
  time relcompile.
Qed.

Theorem vlist_equation: ltac2:(unfold_fix_type '@vlist).
Proof. unfold_fix_proof '@vlist. Qed.
Derive vlist_prog
  in ltac2:(relcompile_tpe 'vlist_prog 'vlist ['vcons])
  as vlist_prog_proof.
Proof.
  time relcompile.
Qed.

Theorem vis_upper_f_equation: ltac2:(unfold_fix_type '@vis_upper_f).
Proof. unfold_fix_proof '@vis_upper_f. Qed.
Derive vis_upper_f_prog
  in ltac2:(relcompile_tpe 'vis_upper_f_prog 'vis_upper_f [])
  as vis_upper_f_prog_proof.
Proof.
  time relcompile.
  ltac1:(lia).
Qed.

Derive vis_upper_prog
  in ltac2:(relcompile_tpe 'vis_upper_prog 'vis_upper ['vis_upper_f])
  as vis_upper_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vgetNum_prog
  in ltac2:(relcompile_tpe 'vgetNum_prog 'vgetNum [])
  as vgetNum_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vel0_prog
  in ltac2:(relcompile_tpe 'vel0_prog 'vel0 ['vhead])
  as vel0_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vel1_prog
  in ltac2:(relcompile_tpe 'vel1_prog 'vel1 ['vhead; 'vtail])
  as vel1_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vel2_prog
  in ltac2:(relcompile_tpe 'vel2_prog 'vel2 ['vel1; 'vtail])
  as vel2_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vel3_prog
  in ltac2:(relcompile_tpe 'vel3_prog 'vel3 ['vel2; 'vtail])
  as vel3_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vtail_prog
  in ltac2:(relcompile_tpe 'vtail_prog 'vtail [])
  as vtail_prog_proof.
Proof.
  time relcompile.
Qed.

Derive visNum_prog
  in ltac2:(relcompile_tpe 'visNum_prog 'visNum [])
  as visNum_prog_proof.
Proof.
  time relcompile.
Qed.

Derive visPair_prog
  in ltac2:(relcompile_tpe 'visPair_prog 'visPair [])
  as visPair_prog_proof.
Proof.
  time relcompile.
Qed.

(* parsing *)

Derive quote_prog
  in ltac2:(relcompile_tpe 'quote_prog 'quote ['vlist])
  as quote_prog_proof.
Proof.
  time relcompile.
Qed.

Derive parse_prog
  in ltac2:(relcompile_tpe 'parse_prog 'parse ['vhead; 'quote])
  as parse_prog_proof.
Proof.
  time relcompile.
Qed.

(* converting from v to prog *)

Derive v2list_prog
  in ltac2:(relcompile_tpe 'v2list_prog 'v2list [])
  as v2list_prog_proof.
Proof.
  time relcompile.
Qed.

Derive num2exp_prog
  in ltac2:(relcompile_tpe 'num2exp_prog 'num2exp ['vis_upper; 'N_modulo])
  as num2exp_prog_proof.
Proof.
  time relcompile.
  subst; specialize N_modulo_lt with (n := n) (m := (2 ^ 64 - 1)%N) as Hlt.
  assert (18446744073709551615 = 2 ^ 64 - 1)%N as -> by ltac1:(lia).
  ltac1:(lia).
Qed.

Derive v2exp_prog
  in ltac2:(relcompile_tpe 'v2exp_prog 'v2exp ['vgetNum; 'vel0; 'num2exp; 'N_modulo])
  as v2exp_prog_proof.
Proof.
  time relcompile.
  subst; specialize N_modulo_lt with (n := (vgetNum v0_3)) (m := (2 ^ 64 - 1)%N) as Hlt.
  assert (18446744073709551615 = 2 ^ 64 - 1)%N as -> by ltac1:(lia).
  ltac1:(lia).
Qed.

Derive vs2exps_prog
  in ltac2:(relcompile_tpe 'vs2exps_prog 'vs2exps ['v2exp])
  as vs2exps_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2cmp_prog
  in ltac2:(relcompile_tpe 'v2cmp_prog 'v2cmp ['vgetNum])
  as v2cmp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2test_prog
  in ltac2:(relcompile_tpe 'v2test_prog 'v2test ['vgetNum; 'v2cmp; 'v2exp])
  as v2test_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2cmd_prog
  in ltac2:(relcompile_tpe 'v2cmd_prog 'v2cmd ['vgetNum; 'v2exp; 'v2test; 'v2list; 'vs2exps; 'visNum; 'visPair])
  as v2cmd_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vs2args_prog
  in ltac2:(relcompile_tpe 'vs2args_prog 'vs2args ['vgetNum])
  as vs2args_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2func_prog
  in ltac2:(relcompile_tpe 'v2func_prog 'v2func ['vel1; 'vel2; 'vel3; 'vgetNum; 'v2list; 'vs2args; 'v2cmd])
  as v2func_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2funcs_prog
  in ltac2:(relcompile_tpe 'v2funcs_prog 'v2funcs ['v2func])
  as v2funcs_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vs2prog_prog
  in ltac2:(relcompile_tpe 'vs2prog_prog 'vs2prog ['v2funcs])
  as vs2prog_prog_proof.
Proof.
  time relcompile.
Qed.

(* entire parser *)

Derive parser_prog
  in ltac2:(relcompile_tpe 'parser_prog 'parser ['parse; 'v2list; 'vs2prog])
  as parser_prog_proof.
Proof.
  time relcompile.
Qed.

Derive str2imp_prog
  in ltac2:(relcompile_tpe 'str2imp_prog 'str2imp ['lexer; 'parser])
  as str2imp_prog_proof.
Proof.
  time relcompile.
Qed.

Definition ParserDerivations_funs := [
  read_num_prog;
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

  assert_eval_app_by 'read_num 'read_num_prog_proof 'Hlookup_fun 0.
  assert_eval_app_by 'end_line 'end_line_prog_proof 'Hlookup_fun 1.
  assert_eval_app_by 'q_from_nat 'q_from_nat_prog_proof 'Hlookup_fun 2.
  assert_eval_app_by 'lex 'lex_prog_proof 'Hlookup_fun 3.
  assert_eval_app_by 'lexer_i 'lexer_i_prog_proof 'Hlookup_fun 4.
  assert_eval_app_by 'lexer 'lexer_prog_proof 'Hlookup_fun 5.
  assert_eval_app_by 'vcons 'vcons_prog_proof 'Hlookup_fun 6.
  assert_eval_app_by 'vhead 'vhead_prog_proof 'Hlookup_fun 7.
  assert_eval_app_by 'vlist 'vlist_prog_proof 'Hlookup_fun 8.
  assert_eval_app_by 'vis_upper_f 'vis_upper_f_prog_proof 'Hlookup_fun 9.
  assert_eval_app_by 'vis_upper 'vis_upper_prog_proof 'Hlookup_fun 10.
  assert_eval_app_by 'vgetNum 'vgetNum_prog_proof 'Hlookup_fun 11.
  assert_eval_app_by 'vtail 'vtail_prog_proof 'Hlookup_fun 12.
  assert_eval_app_by 'vel0 'vel0_prog_proof 'Hlookup_fun 13.
  assert_eval_app_by 'vel1 'vel1_prog_proof 'Hlookup_fun 14.
  assert_eval_app_by 'vel2 'vel2_prog_proof 'Hlookup_fun 15.
  assert_eval_app_by 'vel3 'vel3_prog_proof 'Hlookup_fun 16.
  assert_eval_app_by 'visNum 'visNum_prog_proof 'Hlookup_fun 17.
  assert_eval_app_by 'visPair 'visPair_prog_proof 'Hlookup_fun 18.
  assert_eval_app_by 'quote 'quote_prog_proof 'Hlookup_fun 19.
  assert_eval_app_by 'parse 'parse_prog_proof 'Hlookup_fun 20.
  assert_eval_app_by 'v2list 'v2list_prog_proof 'Hlookup_fun 21.
  assert_eval_app_by 'num2exp 'num2exp_prog_proof 'Hlookup_fun 22.
  assert_eval_app_by 'v2exp 'v2exp_prog_proof 'Hlookup_fun 23.
  assert_eval_app_by 'vs2exps 'vs2exps_prog_proof 'Hlookup_fun 24.
  assert_eval_app_by 'v2cmp 'v2cmp_prog_proof 'Hlookup_fun 25.
  assert_eval_app_by 'v2test 'v2test_prog_proof 'Hlookup_fun 26.
  assert_eval_app_by 'v2cmd 'v2cmd_prog_proof 'Hlookup_fun 27.
  assert_eval_app_by 'vs2args 'vs2args_prog_proof 'Hlookup_fun 28.
  assert_eval_app_by 'v2func 'v2func_prog_proof 'Hlookup_fun 29.
  assert_eval_app_by 'v2funcs 'v2funcs_prog_proof 'Hlookup_fun 30.
  assert_eval_app_by 'vs2prog 'vs2prog_prog_proof 'Hlookup_fun 31.
  assert_eval_app_by 'parser 'parser_prog_proof 'Hlookup_fun 32.
  assert_eval_app_by 'str2imp 'str2imp_prog_proof 'Hlookup_fun 33.
  eauto.
Qed.
