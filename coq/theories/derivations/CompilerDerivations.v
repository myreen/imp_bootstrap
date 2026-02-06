From impboot Require Import utils.Core.
From impboot Require Import utils.Llist.
Import Llist.
From impboot Require Import utils.AppList.
From impboot Require Import commons.ProofUtils.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMToString.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.parsing.Parser.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.imp2asm.Compiler.
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

From impboot Require Import derivations.AsmToStringDerivations.
From impboot Require Import derivations.ParserDerivations.
From impboot Require Import derivations.ImpToASMCodegenDerivations.
From impboot Require Import derivations.CompilerUtilsDerivations.

Derive compiler_prog
  in ltac2:(relcompile_tpe 'compiler_prog 'compiler ['str2imp; 'codegen; 'asm2str])
  as compiler_prog_proof.
Proof.
  time relcompile.
Qed.

Definition read_inp_prog: FunSyntax.defun :=
  FunSyntax.Defun (name_enc "read_inp") ([] : list N)
    (
      FunSyntax.Let (name_enc "curr") (FunSyntax.Op FunSyntax.Read []) (
        FunSyntax.If FunSyntax.Equal [FunSyntax.Var (name_enc "curr"); FunSyntax.Const (2 ^ 32 - 1)%N] 
          (FunSyntax.Const 0) (
            FunSyntax.Let (name_enc "rest") (FunSyntax.Call (name_enc "read_inp") ([] : list FunSyntax.exp)) (
              FunSyntax.Let (name_enc "result") (FunSyntax.Op FunSyntax.Cons [FunSyntax.Var (name_enc "curr"); FunSyntax.Var (name_enc "rest")])
                (FunSyntax.Var (name_enc "result"))
            )
          )
      )
    ).

Theorem read_inp_fn_thm:
  ∀ body : FunSyntax.exp,
    read_inp_prog = FunSyntax.Defun (name_enc "read_inp") ([] : list N) body →
  ∀ (inp: list ascii) (s: state),
    s.(input) = of_list inp →
    lookup_fun (name_enc "read_inp") (funs s) = Some ([] : list N, body) →
    eval_app (name_enc "read_inp") [] s (encode inp, set_input s Lnil).
Proof.
  intros * Hfneq.
  induction inp as [| a inp IH]; intros.
  all: eapply trans_app; eauto.
  2,4: reflexivity.
  all: inversion Hfneq; clear H1.
  all: unfold make_env.
  1: { (* empty input *)
    inversion H; subst; simpl.
    econstructor.
    1: repeat econstructor.
    1: simpl; unfold next; rewrite H3; reflexivity.
    destruct s; unfold set_input; simpl.
    repeat econstructor.
  }
  (* non-empty input *)
  inversion H; subst; simpl.
  econstructor.
  1: repeat econstructor.
  1: simpl; unfold next; rewrite H3; reflexivity.
  econstructor.
  1: repeat econstructor.
  1: econstructor.
  specialize N_ascii_bounded with (a := a) as Habounded.
  assert (N_of_ascii a <> (2 ^ 32 - 1)%N) as Hneq by ltac1:(lia); rewrite <- N.eqb_neq in Hneq; simpl in Hneq.
  rewrite Hneq.
  econstructor.
  1: {
    eapply trans_Call.
    1: repeat econstructor.
    eapply IH; eauto.
  }
  repeat econstructor.
Qed.

Definition print_string_prog: FunSyntax.defun :=
  FunSyntax.Defun (name_enc "print_string") [name_enc "str"] (
    FunSyntax.If FunSyntax.Equal [FunSyntax.Var (name_enc "str"); FunSyntax.Const 0]
      (FunSyntax.Const 0) (
        FunSyntax.Let (name_enc "head") (FunSyntax.Op FunSyntax.Head [FunSyntax.Var (name_enc "str")]) (
          FunSyntax.Let (name_enc "tail") (FunSyntax.Op FunSyntax.Tail [FunSyntax.Var (name_enc "str")]) (
            FunSyntax.Let (name_enc "write_res") (FunSyntax.Op FunSyntax.Write [FunSyntax.Var (name_enc "head")]) (
              FunSyntax.Call (name_enc "print_string") [FunSyntax.Var (name_enc "tail")]
            )
          )
        )
      )
  ).

Theorem print_string_thm:
  ∀ body : FunSyntax.exp,
    print_string_prog = FunSyntax.Defun (name_enc "print_string") [name_enc "str"] body →
  ∀ (str: string) (s: state),
    lookup_fun (name_enc "print_string") (funs s) = Some ([name_enc "str"], body) →
    eval_app (name_enc "print_string") [encode str] s (Num 0, set_output s (s.(output) ++ str)).
Proof.
  intros * Hfneq.
  induction str.
  (* TODO: fix didn't work *)
  (* ltac1:(fix IH 2). *)
  all: intros.
  all: eapply trans_app; eauto.
  2,4: reflexivity.
  all: inversion Hfneq; clear H1.
  all: unfold make_env.
  (* destruct str; simpl. *)
  1: { (* empty string *)
    econstructor.
    1: repeat econstructor.
    1: econstructor.
    simpl.
    destruct s; unfold set_output; rewrite string_app_r_nil; simpl.
    econstructor.
  }
  (* non-empty string *)
  econstructor.
  1: repeat econstructor.
  1: econstructor.
  simpl.
  econstructor.
  1: econstructor.
  1: econstructor; eauto with fenvDb.
  1: econstructor.
  econstructor.
  1: {
    econstructor.
    1: repeat econstructor.
    econstructor.
  }
  econstructor.
  1: {
    econstructor.
    1: repeat econstructor.
    ltac1:(with_strategy transparent [encode] simpl encode).
    simpl; unfold enc_char.
    specialize N_ascii_bounded with (a := a) as Habounded; rewrite <- N.ltb_lt in Habounded.
    rewrite Habounded.
    econstructor.
  }
  1: eapply trans_Call.
  1: repeat econstructor.
  set (s1 := set_output s (s.(output) ++ String a "")).
  unfold set_output in *; simpl in *.
  unfold enc_char in *; rewrite ascii_N_embedding in *.
  assert (s.(output) ++ String a EmptyString ++ str = s.(output) ++ String a str) as <-.
  1: rewrite string_cons_nil_app; reflexivity.
  rewrite string_app_assoc.
  destruct s; simpl in *.
  eapply IHstr; eauto.
  (* apply IH with (1 := Hstrlt) (2 := H0) (str := str) (s := s1). *)
Qed.

Theorem compiler_thm:
  ∀ (s: state) (inp: list ascii),
    (∀ fname args fn,
      In (FunSyntax.Defun fname args fn) ([compiler_prog] ++ ImpToASMCodegen_funs ++ ASMToString_funs ++ ParserDerivations_funs ++ CompilerUtils_funs) →
      lookup_fun fname (funs s) = Some (args, fn)) ->
    eval_app (name_enc "compiler") [encode inp] s ((encode (compiler inp)), s).
Proof.
  intros * Hlookup_fun.
  eapply compiler_prog_proof; eauto; try reflexivity.
  4: eapply Hlookup_fun; simpl; left; reflexivity.
  1: {
    intros; eapply str2imp_thm; eauto; try reflexivity.
    intros; eapply Hlookup_fun; eapply in_or_app; right; eapply in_or_app; right; eapply in_or_app; right; eauto.
  }
  1: {
    intros; eapply codegen_thm; eauto; try reflexivity.
    intros; eapply Hlookup_fun; eapply in_or_app; right; eapply in_app_or in H; destruct H; eauto.
    1: eapply in_or_app; left; eauto.
    1: eapply in_or_app; right; eapply in_or_app; right; eapply in_or_app; right; eauto.
  }
  intros; eapply asm2str_thm; eauto; try reflexivity.
  intros; eapply Hlookup_fun; eapply in_or_app; right; eapply in_or_app; right; eapply in_app_or in H; destruct H; eauto.
  1: eapply in_or_app; left; eauto.
  1: eapply in_or_app; right; eapply in_or_app; right; eauto.
Qed.

Definition compiler_main: FunSyntax.exp := (
  FunSyntax.Let (name_enc "inp") (FunSyntax.Call (name_enc "read_inp") ([] : list FunSyntax.exp)) (
    FunSyntax.Let (name_enc "out_str") (FunSyntax.Call (name_enc "compiler") [FunSyntax.Var (name_enc "inp")]) (
      FunSyntax.Call (name_enc "print_string") [FunSyntax.Var (name_enc "out_str")]
    )
  )
).

Definition compiler_funs: list FunSyntax.defun :=
  [compiler_prog] ++ ImpToASMCodegen_funs ++ ASMToString_funs ++ ParserDerivations_funs ++ CompilerUtils_funs.

Definition compiler_program_prog: FunSyntax.prog :=
  FunSyntax.Program (read_inp_prog :: print_string_prog :: compiler_funs) compiler_main.

Lemma In_IMP_lookup_fun:
  forall fname args fn fns,
    In (FunSyntax.Defun fname args fn) fns →
    NoDup (List.map (fun d => match d with FunSyntax.Defun name _ _ => name end) fns) ->
    lookup_fun fname fns = Some (args, fn).
Proof.
  intros * HIn HNoDup.
  induction fns; simpl in *; try ltac1:(try contradiction).
  destruct HIn; subst; simpl.
  1: rewrite N.eqb_refl; reflexivity.
  destruct a; inversion HNoDup; subst; clear HNoDup.
  destruct (_ =? _)%N eqn:?; simpl in *.
  2: eapply IHfns; eauto.
  1: rewrite N.eqb_eq in Heqb; subst; simpl.
  eapply in_map with (f := fun d => match d with FunSyntax.Defun name _ _ => name end) in H.
  ltac1:(contradiction).  
Qed.

Lemma noDup_all_funs:
  NoDup (List.map (λ d : FunSyntax.defun, match d with
    | FunSyntax.Defun name _ _ => name
    end) (read_inp_prog :: print_string_prog :: compiler_funs)).
Proof.
Admitted.

Theorem compiler_program_thm:
  ∀ inp,
    prog_terminates (of_list inp) compiler_program_prog (compiler inp).
Proof.
  intros.
  unfold prog_terminates, init_state, FunSyntax.get_defs, FunSyntax.get_main.
  do 2 eexists.
  split.
  2: ltac1:(shelve).
  Opaque compiler_funs.
  unfold compiler_program_prog.
  unfold compiler_main.
  econstructor.
  1: {
    eapply trans_Call.
    1: repeat econstructor.
    eapply read_inp_fn_thm; simpl; eauto; try reflexivity.
  }
  unfold set_input; simpl.
  econstructor.
  1: {
    eapply trans_Call.
    1: repeat econstructor.
    eapply compiler_thm; eauto; try reflexivity.
    intros; eapply In_IMP_lookup_fun.
    1: simpl; right; right; eauto.
    simpl.
    eapply noDup_all_funs.
  }
  eapply trans_Call.
  1: repeat econstructor.
  eapply print_string_thm; eauto; try reflexivity.
  Unshelve.
  simpl; reflexivity.
Qed.
