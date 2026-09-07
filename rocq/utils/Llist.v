From Stdlib Require Import Strings.String Strings.Ascii.
From Stdlib.Unicode Require Import Utf8.

Module Llist.

CoInductive llist {A : Type} : Type :=
| Lnil : llist
| Lcons : A -> llist -> llist.
Arguments llist : clear implicits.

Definition ltail {A : Type} (l : llist A) : llist A :=
  match l with
  | Lnil => Lnil
  | Lcons _ tl => tl
  end.

Fixpoint of_list {A: Type} (l: list A): llist A :=
  match l with
  | nil => Lnil
  | cons x xs => Lcons x (of_list xs)
  end.

Fixpoint of_string (l: string): llist ascii :=
  match l with
  | EmptyString => Lnil
  | String x xs => Lcons x (of_string xs)
  end.

Fixpoint nth {A: Type} (n: nat) (l: llist A): option A :=
  match l with
  | Lnil => None
  | Lcons h t =>
    match n with
    | 0 => Some h
    | S n => nth n t
    end
  end.

Definition defined_at {A: Type} (n: nat) (l: llist A): Prop :=
  nth n l <> None.

Inductive lprefix {A: Type} : llist A -> llist A -> Prop :=
| lprefix_empty (o: llist A): lprefix Lnil o
| lprefix_cons (c: A) (p: llist A) (o: llist A):
  lprefix p o -> lprefix (Lcons c p) (Lcons c o).

Definition is_upper_bound {A: Type} (eval: nat -> llist A) (output: llist A): Prop :=
  ∀k, lprefix (eval k) output.

Definition is_least_upper_bound {A: Type} (eval: nat -> llist A) (output: llist A): Prop :=
  is_upper_bound eval output ∧
  ∀other, is_upper_bound eval other -> lprefix output other.

CoFixpoint LUNFOLD {A: Type} (f: nat -> option (nat * A)) (n: nat): llist A :=
  match f n with
  | None => Lnil
  | Some (n, x) => Lcons x (LUNFOLD f n)
  end.

End Llist.
