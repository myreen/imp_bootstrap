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
From coqutil Require Export dlet.
From Coq.Unicode Require Export Utf8.

(* d/let *)

Notation "'let/d' x := val 'in' body" :=
  (dlet val (fun x => body))
  (at level 200, x name, body at level 200).

Notation
  "'let/d' ''(' x , y ')' := val 'in' body" :=
  (dlet val (fun v =>
      let x := fst v in
      let y := snd v in
      body))
  (at level 200, body at level 200, only parsing).

Notation
  "'let/d' ''(' x , y , z ')' := val 'in' body" :=
  (dlet val (fun v =>
      let x := fst (fst v) in
      let y := snd (fst v) in
      let z := snd v in
      body))
  (at level 200, body at level 200, only parsing).

(* CASE *)

Class Analyzable T :=
  { R: Type; analyze: T -> R }.

Definition list_CASE [A] (l : list A) [B] (fnil : B) (fcons : A -> list A -> B) : B :=
  match l with
  | [] => fnil
  | x :: xs => fcons x xs
  end.

Instance Analyzable_List A : Analyzable (list A) :=
  {
    R := forall B, B -> (A -> list A -> B) -> B;
    analyze l _ fnil fcons :=
      match l with
      | [] => fnil
      | x :: xs => fcons x xs
      end
  }.

Definition option_CASE [A] (o : option A) [B] (fnone : B) (fsome : A -> B) : B :=
  match o with
  | None => fnone
  | Some x => fsome x
  end.

Instance Analyzable_Option A : Analyzable (option A) :=
  {
    R := forall B, B -> (A -> B) -> B;
    analyze o _ fnone fsome :=
      match o with
      | None => fnone
      | Some x => fsome x
      end
  }.

Definition pair_CASE [A1 A2] (p : A1 * A2) [B] (f: A1 -> A2 -> B) : B :=
  match p with
  | (x, y) => f x y
  end.

Instance Analyzable_Pair A1 A2 : Analyzable (A1 * A2) :=
  {
    R := forall B, (A1 -> A2 -> B) -> B;
    analyze p _ f :=
      match p with
      | (x, y) => f x y
      end
  }.

Definition nat_CASE (n : nat) [A] (f0 : A) (fS : nat -> A) : A :=
  match n with
  | 0 => f0
  | S n' => fS n'
  end.

Instance Analyzable_Nat : Analyzable nat :=
  {
    R := forall A, A -> (nat -> A) -> A;
    analyze n _ f0 fS :=
      match n with
      | 0 => f0
      | S n' => fS n'
      end
  }.

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

Require Import coqutil.Word.Interface. Import word.
Require Import coqutil.Word.Properties.
Require coqutil.Word.Naive.
Require impboot.utils.Words4Naive.

Definition word64 := (@word.rep 64 Naive.word64).

Definition word4 := (@word.rep 4 Words4Naive.word4).

Declare Scope word.
Infix "*w" := word.mul (at level 40, left associativity, only parsing): word.
Infix "/w" := word.divu (at level 40, left associativity, only parsing): word.
Infix "/sw" := word.divs (at level 40, left associativity, only parsing): word.
Infix "+w" := word.add (at level 50, left associativity, only parsing): word.
Infix "-w" := word.sub (at level 50, left associativity, only parsing): word.
Infix ">>w" := word.sru (at level 60, no associativity, only parsing): word.
Infix ">>>w" := word.srs (at level 60, no associativity, only parsing): word.
Infix "<<w" := word.slu (at level 60, no associativity, only parsing): word.
Notation "w1 =w w2" := (word.eqb w1 w2) (at level 70, no associativity, only parsing): word.
Notation "w1 <w w2" := (word.ltu w1 w2) (at level 70, no associativity, only parsing): word.
Notation "w1 >w w2" := (word.gtu w1 w2) (at level 70, no associativity, only parsing): word.
Notation "w1 <sw w2" := (word.lts w1 w2) (at level 70, no associativity, only parsing): word.
Definition w2n (w: word64): nat :=
  Z.to_nat (word.unsigned w).
Definition w2n4 (w: word4): nat :=
  Z.to_nat (word.unsigned w).
Open Scope word.

(* List *)

Fixpoint list_update {A : Type} (n : nat) (x : A) (l : list A) : list A :=
  match n, l with
  | O, _ :: xs => x :: xs
  | S n, y :: xs => y :: list_update n x xs
  | _, [] => []
  end.
