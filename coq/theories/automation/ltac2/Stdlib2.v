From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.
From impboot Require Import Ltac2Utils.

Ltac2 opt_is_empty (opt: 'a option): bool :=
  match opt with
  | None => true
  | _ => false
  end.

Ltac2 rec index_of (i: ident) (l: ident list): int option :=
  match l with
  | [] => None
  | j :: l =>
    if Ident.equal i j then Some 0
    else Option.map (Int.add 1) (index_of i l)
  end.

Ltac2 opt_to_list (o: 'a option): 'a list := match o with | Some x => [x] | None => [] end.
