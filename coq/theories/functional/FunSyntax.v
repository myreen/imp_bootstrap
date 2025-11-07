From impboot Require Import utils.Core.
From Stdlib Require Import NArith.
From Stdlib Require Import Lists.List.
Import ListNotations.

Open Scope N.

Notation name := N (only parsing).

Inductive op : Type :=
| Add
| Sub
| Div
| Mul
| Cons
| Head
| Tail
| Read
| Write.

Inductive test : Type :=
| Less
| Equal.

Inductive exp : Type :=
| Const (n: N)                                 (* constant number            *)
| Var (n: name)                                (* local variable             *)
| Op (o: op) (args: list exp)                  (* primitive operations       *)
| If (t: test) (conds: list exp) (e1 e2: exp)  (* if test .. then .. else .. *)
| Let (n: name) (e1 e2: exp)                   (* let name = .. in ..        *)
| Call (f: name) (args: list exp).             (* call a function            *)

Inductive defun: Type :=
| Defun (n: name) (params: list name) (body: exp). (* func name, formal params, body *)

(* a complete program is a list of function declarations followed by *)
(* an expression to evaluate *)
Inductive prog: Type :=
| Program (defs: list defun) (main: exp).

Definition get_main (p: prog): exp :=
  match p with
  | Program _ main => main
  end.

Definition get_defs (p: prog): list defun :=
  match p with
  | Program defs _ => defs
  end.
