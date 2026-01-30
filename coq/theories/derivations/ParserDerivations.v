From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.parsing.Parser.
Require Import impboot.imp2asm.ImpToASMCodegen.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import commons.PrintingUtils.
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

(* lexing *)

Derive read_num_prog
  in ltac2:(relcompile_tpe 'read_num_prog 'read_num [])
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

(* parsing *)

Derive quote_prog
  in ltac2:(relcompile_tpe 'quote_prog 'quote [])
  as quote_prog_proof.
Proof.
  time relcompile.
Qed.

Derive parse_prog
  in ltac2:(relcompile_tpe 'parse_prog 'parse [])
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
  in ltac2:(relcompile_tpe 'num2exp_prog 'num2exp [])
  as num2exp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2exp_prog
  in ltac2:(relcompile_tpe 'v2exp_prog 'v2exp [])
  as v2exp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vs2exps_prog
  in ltac2:(relcompile_tpe 'vs2exps_prog 'vs2exps [])
  as vs2exps_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2cmp_prog
  in ltac2:(relcompile_tpe 'v2cmp_prog 'v2cmp [])
  as v2cmp_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2test_prog
  in ltac2:(relcompile_tpe 'v2test_prog 'v2test [])
  as v2test_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2cmd_prog
  in ltac2:(relcompile_tpe 'v2cmd_prog 'v2cmd [])
  as v2cmd_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vs2args_prog
  in ltac2:(relcompile_tpe 'vs2args_prog 'vs2args [])
  as vs2args_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2func_prog
  in ltac2:(relcompile_tpe 'v2func_prog 'v2func [])
  as v2func_prog_proof.
Proof.
  time relcompile.
Qed.

Derive v2funcs_prog
  in ltac2:(relcompile_tpe 'v2funcs_prog 'v2funcs [])
  as v2funcs_prog_proof.
Proof.
  time relcompile.
Qed.

Derive vs2prog_prog
  in ltac2:(relcompile_tpe 'vs2prog_prog 'vs2prog [])
  as vs2prog_prog_proof.
Proof.
  time relcompile.
Qed.

(* entire parser *)

Derive parser_prog
  in ltac2:(relcompile_tpe 'parser_prog 'parser [])
  as parser_prog_proof.
Proof.
  time relcompile.
Qed.

Derive str2imp_prog
  in ltac2:(relcompile_tpe 'str2imp_prog 'str2imp [])
  as str2imp_prog_proof.
Proof.
  time relcompile.
Qed.

