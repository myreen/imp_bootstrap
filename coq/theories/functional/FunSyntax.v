Require Import Coq.Lists.List.
Import ListNotations.

Module FunSyntax.

(* 
TODO(kπ)
- word64 in Coq?
*)

Notation name := nat.

Inductive op : Type :=
  | Add
  | Sub
  | Div
  | Cons
  | Head
  | Tail
  | Read
  | Write.

Inductive test : Type :=
  | Less
  | Equal.

Inductive exp : Type :=
  | Const (n : nat)                                (* constant number            *)
  | Var (n : name)                                 (* local variable             *)
  | Op (o : op) (args : list exp)                  (* primitive operations       *)
  | If (t : test) (conds : list exp) (e1 e2 : exp) (* if test .. then .. else .. *)
  | Let (n : name) (e1 e2 : exp)                   (* let name = .. in ..        *)
  | Call (f : name) (args : list exp).             (* call a function            *)

Inductive dec : Type :=
  | Defun (n : name) (params : list name) (body : exp). (* func name, formal params, body *)

(* a complete program is a list of function declarations followed by *)
(* an expression to evaluate *)
Inductive prog : Type :=
  | Program (defs : list dec) (main : exp).

End FunSyntax.
