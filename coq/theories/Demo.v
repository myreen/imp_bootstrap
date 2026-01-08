From impboot Require Import functional.FunSyntax functional.FunValues.
From impboot Require Import imperative.ImpSyntax.
From Stdlib Require Import NArith.
From Stdlib Require Import ZArith.
From Stdlib Require Import Lists.List.
From Stdlib Require Import Bool.
From Stdlib Require Import String.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
Require Import coqutil.Datatypes.List.
Import ListNotations.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import Derive.
Require Import Ltac2.Ltac2.
Require Import impboot.automation.RelCompiler.
Require Import impboot.automation.ltac2.UnfoldFix.
Require Import impboot.automation.AutomationLemmas.
From impboot Require Import automation.Ltac2Utils.
From impboot Require Import functional.FunValues.
From impboot Require Import functional.FunSemantics.
From impboot Require Import fp2imp.FpToImpCodegen.
From impboot Require Import assembly.ASMToString.
From impboot Require Import imperative.Printing.
From impboot Require Import parsing.Parser.

Inductive MyNat : Type := 
| MyO : MyNat
| MyS : MyNat -> MyNat.

Definition getMyZero: MyNat := MyO.

Definition myNatInc (n: MyNat): MyNat :=
  MyS n.

Fixpoint addMyNat (x y: MyNat): MyNat :=
  match x with
  | MyO => y
  | MyS x' => MyS (addMyNat x' y)
  end.

Fixpoint encode_my_nat (n: MyNat): Value :=
  match n with
  | MyO => value_list_of_values [value_name "MyO"]
  | MyS n' => value_list_of_values [value_name "MyS"; encode_my_nat n']
  end.

Global Instance Refinable_MyNat : Refinable MyNat :=
  { encode := encode_my_nat }.

Lemma auto_my_nat_MyO: forall env s,
  env |-- ([Op Cons [FunSyntax.Const (name_enc "MyO"); FunSyntax.Const 0]], s) ---> ([encode MyO], s).
Proof.
  ltac1:(Eval_eq).
Qed.

Ltac2 auto_my_nat_MyO_tac (_r: unit -> unit) :=
  match! goal with
  | [ |- ?fenv |-- (_, _) ---> ([encode MyO], _) ] =>
    refine open_constr:(auto_my_nat_MyO
      (* env *) $fenv
      (* s *) _
    )
  end.

Lemma auto_my_nat_MyS: forall env s x0 n,
  env |-- ([x0], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [FunSyntax.Const (name_enc "MyS"); Op Cons [x0; FunSyntax.Const 0]]], s) ---> ([encode (MyS n)], s).
Proof.
  ltac1:(Eval_eq).
Qed.

Ltac2 auto_my_nat_MyS_tac (r: unit -> unit) :=
  match! goal with
  | [ |- ?fenv |-- (_, _) ---> ([encode (MyS ?n)], _) ] =>
    refine open_constr:(auto_my_nat_MyS
      (* env *) $fenv
      (* s *) _
      (* x0 *) _
      (* n *) $n
      (* compile n *) ltac2:(Control.enter r)
    )
  end.

Ltac2 Set relCompilerDB as olddb :=
  fun r => Control.plus (fun () => olddb r) (fun _ => auto_my_nat_MyO_tac r).

Derive getMyZero_prog
  in ltac2:(relcompile_tpe 'getMyZero_prog 'getMyZero [])
  as getMyZero_prog_proof.
Proof.
  time relcompile.
Qed.

Ltac2 Set relCompilerDB as olddb :=
  fun r => Control.plus (fun () => olddb r) (fun _ => auto_my_nat_MyS_tac r).

Derive myNatInc_prog
  in ltac2:(relcompile_tpe 'myNatInc_prog 'myNatInc [])
  as myNatInc_prog_proof.
Proof.
  time relcompile.
Qed.

Derive addMyNat_prog
  in ltac2:(relcompile_tpe 'addMyNat_prog 'addMyNat [])
  as addMyNat_prog_proof.
Proof.
  time relcompile.
Qed.