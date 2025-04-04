From impboot Require Import utils.Core.
Require Import impboot.functional.FunSyntax.

Notation name := nat.

Inductive Value :=
  | Pair (v1 v2 : Value)
  | Num (n : nat).

Class Refinable (A : Type) :=
  { refine : A -> Value }.

Global Instance Refinable_nat : Refinable nat :=
  { refine := Num }.

Definition value_name (s : list ascii) : nat :=
  fold_right (fun c acc => (nat_of_ascii c) * 256 + acc) 0 s.

Definition value_list_of_values (xs : list Value) : Value :=
  fold_right (fun x acc => Pair x acc) (Num 0) xs.

Global Instance Refinable_list {A : Type} `{Refinable A} : Refinable (list A) :=
  { refine l := value_list_of_values (List.map refine l) }.

Definition value_less (v1 v2 : Value) : bool :=
  match v1, v2 with
  | Num n1, Num n2 => n1 <? n2
  | _, _ => false
  end.

Definition value_plus (v1 v2 : Value) : Value :=
  match v1, v2 with
  | Num n1, Num n2 => Num (n1 + n2)
  | _, _ => Num 0
  end.

Definition value_minus (v1 v2 : Value) : Value :=
  match v1, v2 with
  | Num n1, Num n2 => Num (n1 - n2)
  | _, _ => Num 0
  end.

Definition value_div (v1 v2 : Value) : Value :=
  match v1, v2 with
  | Num n1, Num n2 => if n2 =? 0 then Num 0 else Num (n1 / n2)
  | _, _ => Num 0
  end.

Definition value_head (v : Value) : Value :=
  match v with
  | Pair x _ => x
  | _ => v
  end.

Definition value_tail (v : Value) : Value :=
  match v with
  | Pair _ y => y
  | _ => v
  end.

Definition value_cons (x y : Value) : Value :=
  Pair x y.

Global Instance Refinable_bool : Refinable bool :=
  { refine b := if b then Num 1 else Num 0 }.

Global Instance Refinable_pair {A B : Type} `{Refinable A} `{Refinable B} : Refinable (A * B) :=
  { refine p := Pair (refine (fst p)) (refine (snd p)) }.

Global Instance Refinable_option {A : Type} `{Refinable (list A)} : Refinable (option A) :=
  { refine o :=
    match o with
    | None => refine []
    | Some x => refine [x]
    end }.

Global Instance Refinable_char : Refinable ascii :=
  { refine c := Num (nat_of_ascii c) }.

Definition value_isNum (v : Value) : bool :=
  match v with
  | Num _ => true
  | _ => false
  end.

Definition value_getNum (v : Value) : nat :=
  match v with
  | Num n => n
  | _ => 0
  end.

Definition value_el1 (v : Value) : Value :=
  value_head (value_tail v).

Definition value_el2 (v : Value) : Value :=
  value_el1 (value_tail v).

Definition value_el3 (v : Value) : Value :=
  value_el2 (value_tail v).

Theorem isNum_bool : forall b,
  value_isNum (refine b) = true.
Proof.
  intros. destruct b; reflexivity.
Qed.

(* TODO(kπ) again problem with termination of this almost exact function *)
Fail Fixpoint value_is_upper (n : nat) : bool :=
  if n <? 256 then
    if n <? 65 then false else
    if n <? 91 then true else false
  else value_is_upper (n / 256).

Definition value_otherwise {A: Type} (x : A) : A := x.
