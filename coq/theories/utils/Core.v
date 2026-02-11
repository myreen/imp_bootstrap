From Stdlib Require Export
  Lists.List
  Bool.Bool
  Strings.Ascii
  Strings.String
  Numbers.DecimalString
  Arith.PeanoNat.
Export ListNotations.
From Stdlib Require Export
  Lia
  String
  Nat
  Arith
  ZArith.
From coqutil Require Export dlet.
From Stdlib.Unicode Require Export Utf8.

(* d/let *)

Notation "'let/d' x := val 'in' body" :=
  (dlet val (fun x => body))
  (at level 200, x name, body at level 200).

Notation
  "'let/d' ''(' x , y ')' := val 'in' body" :=
  (dlet val (fun v =>
      let/d x := fst v in
      let/d y := snd v in
      body))
  (at level 200, body at level 200, only parsing).

Notation
  "'let/d' ''(' x , y , z ')' := val 'in' body" :=
  (dlet val (fun v =>
      let/d fst_v := fst v in
      let/d x := fst fst_v in
      let/d y := snd fst_v in
      let/d z := snd v in
      body))
  (at level 200, body at level 200, only parsing).

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
