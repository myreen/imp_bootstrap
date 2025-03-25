Require Import Coq.Lists.List.
Require Import Coq.Strings.Ascii.
Require Import Coq.Arith.PeanoNat.
Require Import impboot.functional.FunSyntax.
Import ListNotations.

Notation name := nat.

Inductive Value :=
  | Pair (v1 v2 : Value)
  | Num (n : nat).

Definition value_name (s : list ascii) : nat :=
  fold_right (fun c acc => (nat_of_ascii c) * 256 + acc) 0 s.

Definition value_list (xs : list Value) : Value :=
  fold_right (fun x acc => Pair x acc) (Num 0) xs.

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

Definition value_bool (b : bool) : Value :=
  if b then Num 1 else Num 0.

Definition value_map (f : Value -> Value) (xs : list Value) : Value :=
  value_list (List.map f xs).

Definition value_pair (f g : Value -> Value) (p : Value * Value) : Value :=
  match p with
  | (x, y) => Pair (f x) (g y)
  end.

Definition value_option (f : Value -> Value) (o : option Value) : Value :=
  match o with
  | None => value_list []
  | Some x => value_list [f x]
  end.

Definition value_char (c : ascii) : Value :=
  Num (nat_of_ascii c).

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
  value_isNum (value_bool b) = true.
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
