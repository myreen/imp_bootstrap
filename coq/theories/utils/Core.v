From Stdlib Require Export
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

(* FIX *)

Fixpoint fold_right {A B} (f : B -> A -> A) (acc : A) (l : list B) : A :=
  match l with
  | nil => acc
  | x :: xs =>
    f x (fold_right f acc xs)
  end.

(* TODO(kπ) check this *)
Definition fold_left {A B} (f : A -> B -> A) (acc : A) (l : list B) : A :=
  fold_right (fun x g => fun z => g (f z x)) (fun z => z) l acc.

Fixpoint nat_FIX {A C} (n : nat) (f0 : C -> A) (fS : (C -> A) -> nat -> C -> A) : C -> A :=
  match n with
  | 0 => f0
  | S n' =>
    fS (nat_FIX n' f0 fS) n'
  end.

(* Word *)

Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.

Declare Scope word.
Infix "*w" := word.mul (at level 40, left associativity): word.
Infix "/w" := word.divu (at level 40, left associativity): word.
Infix "/sw" := word.divs (at level 40, left associativity): word.
Infix "+w" := word.add (at level 50, left associativity): word.
Infix "-w" := word.sub (at level 50, left associativity): word.
Infix ">>w" := word.sru (at level 60, no associativity): word.
Infix ">>>w" := word.srs (at level 60, no associativity): word.
Infix "<<w" := word.slu (at level 60, no associativity): word.
Notation "w1 =w w2" := (word.eqb w1 w2) (at level 70, no associativity): word.
Notation "w1 <w w2" := (word.ltu w1 w2) (at level 70, no associativity): word.
Notation "w1 >w w2" := (word.gtu w1 w2) (at level 70, no associativity): word.
Notation "w1 <sw w2" := (word.lts w1 w2) (at level 70, no associativity): word.
Definition w2n (w: word64): nat :=
  Z.to_nat (word.unsigned w).
Open Scope word.

(* List *)

Fixpoint list_update {A : Type} (n : nat) (x : A) (l : list A) : list A :=
  match n, l with
  | O, _ :: xs => x :: xs
  | S n, y :: xs => y :: list_update n x xs
  | _, [] => []
  end.
