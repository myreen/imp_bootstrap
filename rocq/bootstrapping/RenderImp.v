From impboot.bootstrapping Require Import BootstrappingDefinitions.
From impboot.imperative Require Import Printing.
From Stdlib Require Import String.
From Ltac2 Require Import Ltac2.

Time Compute
  match compiler_program_imp with
  | None => ""%string
  | Some p => imp2str p
  end.
