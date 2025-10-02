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

CoFixpoint LUNFOLD {A: Type} (f: nat -> option (nat * A)) (n: nat): llist A :=
  match f n with
  | None => Lnil
  | Some (n, x) => Lcons x (LUNFOLD f n)
  end.

(* ----------------------------------------------------------------------
    some (Hilbert choice "lifted" to the option type)

    some P = NONE, when P is everywhere false.
      otherwise
    some P = SOME x ensuring P x.

    This constant saves pain when confronted with the possibility of
    writing
      if ?x. P x then f (@x. P x) else ...

    Instead one can write
      case (some x. P x) of SOME x -> f x || NONE -> ...
    and avoid having to duplicate the P formula.
   ---------------------------------------------------------------------- *)
(* 
val some_def = new_definition(
  "some_def",
  ``some P = if ?x. P x then SOME (@x. P x) else NONE``); *)

(* Fixpoint build_lprefix_lub_f ls n :=
  option_map (fun x => (n+1, x)) (lprefix_chain_nth n ls). *)

(*
val build_lprefix_lub_def = Define `
  build_lprefix_lub ls =
    LUNFOLD (build_lprefix_lub_f ls) 0`;

val build_lprefix_lub_f_def = Define`
  build_lprefix_lub_f ls n =
    OPTION_MAP (λx. (n+1, x)) (lprefix_chain_nth n ls)`;

val lprefix_chain_nth_def = Define `
  lprefix_chain_nth n ls =
    some x. ?l. l ∈ ls ∧ LNTH n l = SOME x`;

val LUNFOLD = Q.store_thm (
  "LUNFOLD",
  `!f x.
     LUNFOLD f x =
       case f x of NONE => [||] | SOME (v1,v2) => v2 ::: LUNFOLD f v1`,
  ...) ;
*)

End Llist.
