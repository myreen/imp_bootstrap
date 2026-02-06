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
  ltac1:(lia).
Qed.

Derive v2exp_prog
  in ltac2:(relcompile_tpe 'v2exp_prog 'v2exp ['vgetNum; 'vel0; 'num2exp; 'N_modulo])
  as v2exp_prog_proof.
Proof.
  time relcompile.
  subst; specialize N_modulo_lt with (n := (vgetNum v0_3)) (m := (2 ^ 64 - 1)%N) as Hlt.
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
  vel0_prog;
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
  str2imp_prog;
  vel1_prog;
  vel2_prog;
  vel3_prog;
  vtail_prog
].

Ltac2 assert_lookup_fun (prog: constr) :=
  let h := Fresh.in_goal (Option.get (Ident.of_string "Hlookup_fun_s")) in
  assert (match $prog with
  | FunSyntax.Defun fname args fn =>
      lookup_fun fname (funs &s) = Some (args, fn)
  end) as $h; try (simpl in $h).

Theorem str2imp_thm:
  ∀ (s: state) (inp: list ascii),
    (∀ fname args fn,
      In (FunSyntax.Defun fname args fn) (ParserDerivations_funs ++ CompilerUtils_funs) →
      lookup_fun fname (funs s) = Some (args, fn)) ->
    eval_app (name_enc "str2imp") [encode inp] s ((encode (str2imp inp)), s).
Proof.
  Opaque encode.
  intros * Hlookup_fun.
  assert_lookup_fun 'vel1_prog; simpl.
  1: eapply Hlookup_fun; do 30 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'vel2_prog; simpl.
  1: eapply Hlookup_fun; do 31 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'vel3_prog; simpl.
  1: eapply Hlookup_fun; do 32 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'list_length_prog; simpl.
  1: eapply Hlookup_fun; do 40 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'vhead_prog; simpl.
  1: eapply Hlookup_fun; do 7 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'vtail_prog; simpl.
  1: eapply Hlookup_fun; do 33 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'vgetNum_prog; simpl.
  1: eapply Hlookup_fun; do 11 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'vhead_prog; simpl.
  1: eapply Hlookup_fun; do 7 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'vel0_prog; simpl.
  1: eapply Hlookup_fun; do 12 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'N_modulo_prog; simpl.
  1: eapply Hlookup_fun; do 35 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'mul_N_prog; simpl.
  1: eapply Hlookup_fun; do 46 (eapply in_cons); eapply in_eq.
  assert_lookup_fun 'mul_N_f_prog; simpl.
  1: eapply Hlookup_fun; do 45 (eapply in_cons); eapply in_eq.
  eapply str2imp_prog_proof; eauto; try reflexivity.
  3: eapply Hlookup_fun; do 29 (eapply in_cons); eapply in_eq.
  1: {
    eapply lexer_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 5 (eapply in_cons); eapply in_eq.
    eapply lexer_i_prog_proof; eauto; try reflexivity.
    3: eapply Hlookup_fun; do 4 (eapply in_cons); eapply in_eq.
    2: eapply list_length_prog_proof; eauto; try reflexivity.
    eapply lex_prog_proof; eauto; try reflexivity.
    5: eapply Hlookup_fun; do 3 (eapply in_cons); eapply in_eq.
    1: eapply end_line_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 1 (eapply in_cons); eapply in_eq.
    1: eapply read_num_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 0 (eapply in_cons); eapply in_eq.
    1: eapply mul_N_prog_proof; eauto; try reflexivity.
    1: eapply mul_N_f_prog_proof; eauto; try reflexivity.
    1: eapply q_from_nat_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 2 (eapply in_cons); eapply in_eq.
    eapply list_length_prog_proof; eauto; try reflexivity.
  }
  eapply parser_prog_proof; eauto; try reflexivity.
  4: eapply Hlookup_fun; do 28 (eapply in_cons); eapply in_eq.
  1: {
    eapply parse_prog_proof; eauto; try reflexivity.
    3: eapply Hlookup_fun; do 16 (eapply in_cons); eapply in_eq.
    1: eapply vhead_prog_proof; eauto; try reflexivity.
    eapply quote_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 15 (eapply in_cons); eapply in_eq.
    eapply vlist_prog_proof; eauto; try reflexivity.
    2: eapply Hlookup_fun; do 8 (eapply in_cons); eapply in_eq.
    eapply vcons_prog_proof; eauto; try reflexivity.
    1: eapply Hlookup_fun; do 6 (eapply in_cons); eapply in_eq.
  }
  1: eapply v2list_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 17 (eapply in_cons); eapply in_eq.
  eapply vs2prog_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 27 (eapply in_cons); eapply in_eq.
  eapply v2funcs_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 26 (eapply in_cons); eapply in_eq.
  assert (∀ v : Value, eval_app (name_enc "v2exp") [encode v] s (encode (v2exp v), s)).
  1: eapply v2exp_prog_proof; eauto; try reflexivity.
  5: eapply Hlookup_fun; do 19 (eapply in_cons); eapply in_eq.
  1: eapply vgetNum_prog_proof; eauto; try reflexivity.
  1: eapply vel0_prog_proof; eauto; try reflexivity.
  1: eapply vhead_prog_proof; eauto; try reflexivity.  
  1: eapply num2exp_prog_proof; eauto; try reflexivity.
  3: eapply Hlookup_fun; do 18 (eapply in_cons); eapply in_eq.
  1: eapply vis_upper_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 10 (eapply in_cons); eapply in_eq.
  1: eapply vis_upper_f_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 9 (eapply in_cons); eapply in_eq.
  1: eapply N_modulo_prog_proof; eauto; try reflexivity.
  2: eapply N_modulo_prog_proof; eauto; try reflexivity.
  1: eapply mul_N_prog_proof; eauto; try reflexivity.
  1: eapply mul_N_f_prog_proof; eauto; try reflexivity.
  1: eapply mul_N_prog_proof; eauto; try reflexivity.
  1: eapply mul_N_f_prog_proof; eauto; try reflexivity.
  eapply v2func_prog_proof; eauto; try reflexivity.
  8: eapply Hlookup_fun; do 25 (eapply in_cons); eapply in_eq.
  1: eapply vel1_prog_proof; eauto; try reflexivity.
  1: eapply vhead_prog_proof; eauto; try reflexivity.
  1: eapply vtail_prog_proof; eauto; try reflexivity.
  1: eapply vel2_prog_proof; eauto; try reflexivity.
  1: eapply vel1_prog_proof; eauto; try reflexivity.
  1: eapply vhead_prog_proof; eauto; try reflexivity.
  1: eapply vtail_prog_proof; eauto; try reflexivity.
  1: eapply vtail_prog_proof; eauto; try reflexivity.
  1: eapply vel3_prog_proof; eauto; try reflexivity.
  1: eapply vel2_prog_proof; eauto; try reflexivity.
  1: eapply vel1_prog_proof; eauto; try reflexivity.
  1: eapply vhead_prog_proof; eauto; try reflexivity.
  1: eapply vtail_prog_proof; eauto; try reflexivity.
  1: eapply vtail_prog_proof; eauto; try reflexivity.
  1: eapply vtail_prog_proof; eauto; try reflexivity.
  1: eapply vgetNum_prog_proof; eauto; try reflexivity.
  1: eapply v2list_prog_proof; eauto; try reflexivity.
  1: eapply Hlookup_fun; do 17 (eapply in_cons); eapply in_eq.
  1: eapply vs2args_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 24 (eapply in_cons); eapply in_eq.
  1: eapply vgetNum_prog_proof; eauto; try reflexivity.
  1: eapply v2cmd_prog_proof; eauto; try reflexivity.
  7: eapply Hlookup_fun; do 23 (eapply in_cons); eapply in_eq.
  1: eapply vgetNum_prog_proof; eauto; try reflexivity.
  2: eapply v2list_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 17 (eapply in_cons); eapply in_eq.
  4: eapply visPair_prog_proof; eauto; try reflexivity.
  4: eapply Hlookup_fun; do 14 (eapply in_cons); eapply in_eq.
  3: eapply visNum_prog_proof; eauto; try reflexivity.
  3: eapply Hlookup_fun; do 13 (eapply in_cons); eapply in_eq.
  2: eapply vs2exps_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 20 (eapply in_cons); eapply in_eq.
  1: eapply v2test_prog_proof; eauto; try reflexivity.
  3: eapply Hlookup_fun; do 22 (eapply in_cons); eapply in_eq.
  1: eapply vgetNum_prog_proof; eauto; try reflexivity.
  1: eapply v2cmp_prog_proof; eauto; try reflexivity.
  2: eapply Hlookup_fun; do 21 (eapply in_cons); eapply in_eq.
  eapply vgetNum_prog_proof; eauto; try reflexivity.
Qed.
