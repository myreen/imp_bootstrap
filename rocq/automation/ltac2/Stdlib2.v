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

Ltac2 rec dedup_go (acc: 'a list) (l: 'a list) (eq: 'a -> 'a -> bool): 'a list :=
  match l with
  | [] => acc
  | h :: l =>
    if List.exist (eq h) acc then dedup_go acc l eq
    else dedup_go (h :: acc) l eq
  end.
Ltac2 dedup (l: 'a list) (eq: 'a -> 'a -> bool): 'a list :=
  dedup_go [] l eq.

Ltac2 assert_Some (c: constr): unit :=
  let c' := eval_cbv all c in
  match! c' with
  | Some _ => ()
  | None => Control.throw (Oopsie (fprintf "Expected Some, got None"))
  end.
