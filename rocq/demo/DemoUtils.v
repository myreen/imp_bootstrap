From impboot.functional Require Import FunSemantics.
From impboot.automation Require Import RelCompiler RelCompilerCommons AutomationLemmas ltac2.UnfoldFix Ltac2Utils.
From Ltac2 Require Import Ltac2.

Ltac2 hide_non_compilation_goals () :=
  Control.enter (fun () => match! goal with
  | [ |- _ |-- (_, _) ---> (_, _)] => ()
  | [ |- _ ] => ltac1:(shelve)
  end).

Ltac2 relcompile_start () :=
  relcompile; hide_non_compilation_goals ().

Ltac2 relcompile_step () :=
  Control.enter (fun () => compile (); hide_non_compilation_goals ()).

Ltac2 Set relcompile_one_step := true.
