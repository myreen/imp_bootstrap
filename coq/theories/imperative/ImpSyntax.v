Require Import Coq.Lists.List.
Import ListNotations.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.

Notation name := nat.

Inductive exp : Type :=
| Var (n: name)             (*  variable             *)
| Const (n: word64)         (*  word constant        *)
| Add (e1: exp) (e2: exp)   (*  word addition        *)
| Sub (e1: exp) (e2: exp)   (*  word subtraction     *)
| Div (e1: exp) (e2: exp)   (*  word division        *)
| Read (e1: exp) (e2: exp). (*  read memory:  e[e']  *)

Inductive cmp : Type :=
| Less
| Equal.

Inductive test : Type :=
| Test (c: cmp) (e1: exp) (e2: exp) (* e1 `cmp` e2 *)
| And (t1: test) (t2: test)         (* t1 && t2 *)
| Or (t1: test) (t2: test)          (* t1 || t2 *)
| Not (t: test).                    (* !t *)

Inductive cmd : Type :=
| Assign (n: name) (e: exp)                   (*  n := e                  *)
| Update (a: exp) (e: exp) (e': exp)          (*  a[e] := e'              *)
| If (t: test) (c1: list cmd) (c2: list cmd)  (*  if (t) ... else ...     *)
| While (t: test) (c: list cmd)               (*  while (t) ...           *)
| Call (n: name) (f: name) (es: list exp)     (*  n := f(e1,e2,e3,...)    *)
| Return (e: exp)                             (*  return from function    *)
| Alloc (n: name) (e: exp)                    (*  n := malloc(e)          *)
| GetChar (n: name)                           (*  n := getchar()          *)
| PutChar (e: exp)                            (*  putchar(e)              *)
| Abort.                                      (*  exit(1)                 *)

Inductive func : Type :=
| Func (n: name) (params: list name) (body: list cmd). (* func name, formal params, body *)

Inductive prog : Type :=
| Program (funcs: list func). (* a complete program is a list of function definitions *)

Definition get_funcs (p: prog) : list func :=
  match p with
  | Program funcs => funcs
  end.

Definition name_of_func (f: func) : name :=
  match f with
  | Func n _ _ => n
  end.