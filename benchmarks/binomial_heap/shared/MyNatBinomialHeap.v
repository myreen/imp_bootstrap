(** A version of the adjusted binomial-heap benchmark whose keys and workload
    counters use an explicit unary natural-number type.  This keeps the source
    shared by IMPL and CertiRocq while preventing IMPL's built-in [nat]
    encoding from turning heap keys into machine integers. *)

Require Import Coq.Arith.Arith List.
From coqutil Require Import dlet.

Import ListNotations.

Inductive MyNat : Type :=
| MyO : MyNat
| MyS : MyNat -> MyNat.

Fixpoint my_ltb (a b : MyNat) : bool :=
  match a with
  | MyO =>
      match b with
      | MyO => false
      | MyS _ => true
      end
  | MyS a' =>
      match b with
      | MyO => false
      | MyS b' => my_ltb a' b'
      end
  end.

Definition key := MyNat.

Inductive tree : Type :=
| Node : key -> tree -> tree -> tree
| Leaf : tree.

Definition priqueue := list tree.

Definition empty : priqueue := nil.

Notation "a >? b" := (my_ltb b a) (at level 70, only parsing).

Definition smash (t u : tree) : tree :=
  match t, u with
  | Node x t1 Leaf, Node y u1 Leaf =>
      dlet! greater := x >? y in
      if greater then Node x (Node y u1 t1) Leaf
      else Node y (Node x t1 u1) Leaf
  | _, _ => Leaf
  end.

Fixpoint carry (q : list tree) (t : tree) : list tree :=
  match q, t with
  | nil, Leaf => nil
  | nil, _ => t :: nil
  | Leaf :: q', _ => t :: q'
  | u :: q', Leaf => u :: q'
  | u :: q', _ => Leaf :: carry q' (smash t u)
  end.

Definition insert (x : key) (q : priqueue) : priqueue :=
  carry q (Node x Leaf Leaf).

Fixpoint join (p q : priqueue) (c : tree) : priqueue :=
  match p, q, c with
  | [], _, _ => carry q c
  | _, [], _ => carry p c
  | Leaf :: p', Leaf :: q', _ => c :: join p' q' Leaf
  | Leaf :: p', q1 :: q', Leaf => q1 :: join p' q' Leaf
  | Leaf :: p', q1 :: q', Node _ _ _ =>
      Leaf :: join p' q' (smash c q1)
  | p1 :: p', Leaf :: q', Leaf => p1 :: join p' q' Leaf
  | p1 :: p', Leaf :: q', Node _ _ _ =>
      Leaf :: join p' q' (smash c p1)
  | p1 :: p', q1 :: q', _ => c :: join p' q' (smash p1 q1)
  end.

Fixpoint unzip_acc (t : tree) (acc : priqueue) : priqueue :=
  match t with
  | Node x t1 t2 => unzip_acc t2 (Node x t1 Leaf :: acc)
  | Leaf => acc
  end.

Definition unzip (t : tree) : priqueue := unzip_acc t nil.

Definition heap_delete_max (t : tree) : priqueue :=
  match t with
  | Node x t1 Leaf => unzip t1
  | _ => nil
  end.

Fixpoint find_max' (current : key) (q : priqueue) : key :=
  match q with
  | [] => current
  | Leaf :: q' => find_max' current q'
  | Node x _ _ :: q' =>
      dlet! greater := x >? current in
      if greater then find_max' x q' else find_max' current q'
  end.

Fixpoint find_max (q : priqueue) : option key :=
  match q with
  | [] => None
  | Leaf :: q' => find_max q'
  | Node x _ _ :: q' => Some (find_max' x q')
  end.

Fixpoint delete_max_aux (m : key) (p : priqueue)
    : priqueue * priqueue :=
  match p with
  | Leaf :: p' =>
      dlet! tmp := delete_max_aux m p' in
      let (j, k) := tmp in (Leaf :: j, k)
  | Node x t1 Leaf :: p' =>
      dlet! greater := m >? x in
      if greater then
        (dlet! tmp := delete_max_aux m p' in
         let (j, k) := tmp in (Node x t1 Leaf :: j, k))
      else (Leaf :: p', heap_delete_max (Node x t1 Leaf))
  | _ => (nil, nil)
  end.

Definition delete_max (q : priqueue) : option (key * priqueue) :=
  dlet! mx := find_max q in
  match mx return option (key * priqueue) with
  | None => None
  | Some m =>
      dlet! tmp := delete_max_aux m q in
      let (p', q') := tmp in Some (m, join p' q' Leaf)
  end.

Definition merge (p q : priqueue) := join p q Leaf.

Fixpoint insert_list (l : list MyNat) (q : priqueue) :=
  match l with
  | [] => q
  | x :: l' => insert_list l' (insert x q)
  end.

Fixpoint make_list (n : MyNat) (l : list MyNat) :=
  match n with
  | MyO => MyO :: l
  | MyS MyO => MyS MyO :: l
  | MyS (MyS n') => make_list n' (MyS (MyS n') :: l)
  end.

Fixpoint my_add (a b : MyNat) : MyNat :=
  match a with
  | MyO => b
  | MyS a' => MyS (my_add a' b)
  end.

Fixpoint my_mul (a b : MyNat) : MyNat :=
  match a with
  | MyO => MyO
  | MyS a' => my_add b (my_mul a' b)
  end.

Definition make_my10 (_ : MyNat) : MyNat :=
  MyS (MyS (MyS (MyS (MyS (MyS (MyS (MyS (MyS (MyS MyO))))))))).

Definition benchmark_main :=
  let my10 := make_my10 MyO in
  let my100 := my_mul my10 my10 in
  let my20 := my_add my10 my10 in
  let my2000 := my_mul my20 my100 in
  let my2001 := MyS my2000 in
  let a := insert_list (make_list my2000 []) nil in
  let b := insert_list (make_list my2001 []) nil in
  let c := merge a b in
  dlet! deleted := delete_max c in
  match deleted return MyNat with
  | Some (k, _) => k
  | None => MyO
  end.
