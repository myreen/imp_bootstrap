(** Original source copied from:
    https://github.com/CertiCoq/certicoq/blob/59f110359ed57550a746124441f20b993774af78/tests/lib/Binom.v

    License terms: [../NOTICE].

    The adapted and reified implementation is in
    [rocq/binomial_heap/BinomialHeap.v]. *)

Require Import Coq.Arith.Arith List.
From coqutil Require Import dlet.

Import ListNotations.
Import Nat. (* For 8.5.0 *)
Definition key := nat.

Inductive tree : Type :=
|  Node: key -> tree -> tree -> tree
|  Leaf : tree.

Definition priqueue := list tree.

Definition empty : priqueue := nil.

Notation  "a >? b" := (ltb b a) (at level 70, only parsing) : nat_scope.

Definition smash (t u:  tree) : tree :=
  match t , u with
  |  Node x t1 Leaf, Node y u1 Leaf =>
                   if  x >? y then Node x (Node y u1 t1) Leaf
                                else Node y (Node x t1 u1) Leaf
  | _ , _ => Leaf  (* arbitrary bogus tree *)
  end.

Fixpoint carry (q: list tree) (t: tree) : list tree :=
  match q, t with
  | nil, Leaf        => nil
  | nil, _            => t :: nil
  | Leaf :: q', _  => t :: q'
  | u :: q', Leaf  => u :: q'
  | u :: q', _       => Leaf :: carry q' (smash t u)
 end.

Definition insert (x: key) (q: priqueue) : priqueue :=
     carry q (Node x Leaf Leaf).

Fixpoint join (p q: priqueue) (c: tree) : priqueue :=
  match p, q, c with
  | [], _ , _            => carry q c
  | _, [], _             => carry p c
  | Leaf::p', Leaf::q', _              => c :: join p' q' Leaf
  | Leaf::p', q1::q', Leaf            => q1 :: join p' q' Leaf
  | Leaf::p', q1::q', Node _ _ _  => Leaf :: join p' q' (smash c q1)
  | p1::p', Leaf::q', Leaf            => p1 :: join p' q' Leaf
  | p1::p', Leaf::q',Node _ _ _   => Leaf :: join p' q' (smash c p1)
  | p1::p', q1::q', _                   => c :: join p' q' (smash p1 q1)
  end.

Fixpoint unzip_acc (t: tree) (acc: priqueue) : priqueue :=
  match t with
  | Node x t1 t2 => unzip_acc t2 (Node x t1 Leaf :: acc)
  | Leaf => acc
  end.

Definition unzip (t: tree) : priqueue := unzip_acc t nil.

Definition heap_delete_max (t: tree) : priqueue :=
  match t with
    Node x t1 Leaf  => unzip t1
  | _ => nil   (* bogus value for ill-formed or empty trees *)
  end.

Fixpoint find_max' (current: key) (q: priqueue) : key :=
  match q with
  |  []         => current
  | Leaf::q' => find_max' current q'
  | Node x _ _ :: q' => if x >? current then find_max' x q' else find_max' current q'
  end.

Fixpoint find_max (q: priqueue) : option key :=
  match q with
  | [] => None
  | Leaf::q' => find_max q'
  | Node x _ _ :: q' => Some (find_max' x q')
 end.

Fixpoint delete_max_aux (m: key) (p: priqueue) : priqueue * priqueue :=
  match p with
  | Leaf :: p'   => dlet! tmp := delete_max_aux m p' in let (j,k) := tmp in (Leaf::j, k)
  | Node x t1 Leaf :: p' =>
       if m >? x
       then (dlet! tmp := delete_max_aux m p' in let (j,k) := tmp
             in (Node x t1 Leaf::j,k))
       else (Leaf::p', heap_delete_max (Node x t1 Leaf))
  | _ => (nil, nil) (* Bogus value *)
  end.

Definition delete_max (q: priqueue) : option (key * priqueue) :=
  dlet! mx := find_max q in
  match mx return option (key * priqueue) with
  | None => None
  | Some  m => dlet! tmp := delete_max_aux m q in let (p',q') := tmp
                            in Some (m, join p' q' Leaf)
  end.

Definition merge (p q: priqueue) := join p q Leaf.

Definition main_easy :=
 let a := insert 5 (insert 3 (insert 7 empty)) in
 let b := insert 3 (insert 6 (insert 9 empty)) in
 let c := merge a b in
 match delete_max c with
 | Some (k, _) => k
 | None => 0
 end.

Fixpoint insert_list (l : list nat) (q : priqueue) :=
    match l with
    | [] => q
    | x :: l => insert_list l (insert x q)
    end.

Fixpoint make_list (n : nat) (l : list nat) :=
  match n with
  | 0 => 0 :: l
  | S 0 => 1 :: l
  | S (S n) => make_list n (S (S n) :: l)
  end.

Definition benchmark_main :=
  let a := insert_list (make_list 2000 []) nil in
  let b := insert_list (make_list 2001 []) nil in
  let c := merge a b in
  dlet! deleted := delete_max c in
  match deleted return nat with
  | Some (k, _) => k
  | None => 0
  end.
