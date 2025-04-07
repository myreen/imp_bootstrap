From impboot Require Import utils.Core.
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

Definition exp_CASE {A} (e: exp)
  (vcase: name -> A) (ccase: word64 -> A)
  (acase: exp -> exp -> A) (scase: exp -> exp -> A)
  (dcase: exp -> exp -> A) (rcase: exp -> exp -> A) : A :=
  match e with
  | Var n => vcase n
  | Const n => ccase n
  | Add e1 e2 => acase e1 e2
  | Sub e1 e2 => scase e1 e2
  | Div e1 e2 => dcase e1 e2
  | Read e1 e2 => rcase e1 e2
  end.

Inductive cmp : Type :=
| Less
| Equal.

Definition cmp_CASE {A} (c: cmp) (less: A) (equal: A) : A :=
  match c with
  | Less => less
  | Equal => equal
  end.

Inductive test : Type :=
| Test (c: cmp) (e1: exp) (e2: exp) (* e1 `cmp` e2 *)
| And (t1: test) (t2: test)         (* t1 && t2 *)
| Or (t1: test) (t2: test)          (* t1 || t2 *)
| Not (t: test).                    (* !t *)

Definition test_CASE {A} (t: test)
  (tcase: cmp -> exp -> exp -> A)
  (acase: test -> test -> A)
  (ocase: test -> test -> A)
  (ncase: test -> A) : A :=
  match t with
  | Test c e1 e2 => tcase c e1 e2
  | And t1 t2 => acase t1 t2
  | Or t1 t2 => ocase t1 t2
  | Not t => ncase t
  end.

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

Definition cmd_CASE {A} (c: cmd)
  (acase: name -> exp -> A)
  (ucase: exp -> exp -> exp -> A)
  (icase: test -> list cmd -> list cmd -> A)
  (wcase: test -> list cmd -> A)
  (ccase: name -> name -> list exp -> A)
  (rcase: exp -> A)
  (acase': name -> exp -> A)
  (gcase: name -> A)
  (pcase: exp -> A)
  (abcase: A) : A :=
  match c with
  | Assign n e => acase n e
  | Update a e e' => ucase a e e'
  | If t c1 c2 => icase t c1 c2
  | While t c => wcase t c
  | Call n f es => ccase n f es
  | Return e => rcase e
  | Alloc n e => acase' n e
  | GetChar n => gcase n
  | PutChar e => pcase e
  | Abort => abcase
  end.

Inductive func : Type :=
| Func (n: name) (params: list name) (body: list cmd). (* func name, formal params, body *)

Definition func_CASE {A} (f: func) (fcase: name -> list name -> list cmd -> A) : A :=
  match f with
  | Func n params body => fcase n params body
  end.

Inductive prog : Type :=
| Program (funcs: list func). (* a complete program is a list of function definitions *)

Definition prog_CASE {A} (p: prog) (fcase: list func -> A) : A :=
  match p with
  | Program funcs => fcase funcs
  end.

Definition get_funcs (p: prog) : list func :=
  match p with
  | Program funcs => funcs
  end.

Definition name_of_func (f: func) : name :=
  match f with
  | Func n _ _ => n
  end.
