From Coq Require Export
  Lists.List
  Bool.Bool
  Strings.Ascii
  Strings.String
  Numbers.DecimalString
  Arith.PeanoNat.
Export ListNotations.
Require Export
  Lia
  String
  Nat
  Arith
  ZArith.
From coqutil Require Import dlet.

(* d/let *)

Notation "'letd' x := val 'in' body" :=
  (dlet val (fun x => body))
  (at level 200, x name, body at level 200).

Notation
  "'letd' ''(' x , y ')' := val 'in' body" :=
  (dlet val (fun v =>
      let x := fst v in
      let y := snd v in
      body))
  (at level 200, body at level 200, only parsing).

Notation
  "'letd' ''(' x , y , z ')' := val 'in' body" :=
  (dlet val (fun v =>
      let x := fst (fst v) in
      let y := snd (fst v) in
      let z := snd v in
      body))
  (at level 200, body at level 200, only parsing).

(* CASE *)

Definition list_CASE {A B} (l : list A) (fnil : B) (fcons : A -> list A -> B) : B :=
  match l with
  | [] => fnil
  | x :: xs => fcons x xs
  end.

Definition option_CASE {A B} (o : option A) (fnone : B) (fsome : A -> B) : B :=
  match o with
  | None => fnone
  | Some x => fsome x
  end.

Definition pair_CASE {A1 A2 B} (p : A1 * A2) (f: A1 -> A2 -> B) : B :=
  match p with
  | (x, y) => f x y
  end.

Definition nat_CASE {A} (n : nat) (f0 : A) (fS : nat -> A) : A :=
  match n with
  | 0 => f0
  | S n' => fS n'
  end.
