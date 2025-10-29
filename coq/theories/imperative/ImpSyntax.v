From impboot Require Import utils.Core.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.

Notation name := nat (only parsing).

Definition name_enc_l (s : list ascii) : nat :=
  fold_right (fun c acc => (nat_of_ascii c) * 256 + acc) 0 s.

Definition name_of_string (s: string) : nat :=
  name_enc_l (list_ascii_of_string s).

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
| Skip
| Seq (c1 : cmd) (c2 : cmd)                   (*  c1; c2                  *)
| Assign (n: name) (e: exp)                   (*  n := e                  *)
| Update (a: exp) (e: exp) (e': exp)          (*  a[e] := e'              *)
| If (t: test) (c1: cmd) (c2: cmd)            (*  if (t) ... else ...     *)
| While (t: test) (c: cmd)                    (*  while (t) ...           *)
| Call (n: name) (f: name) (es: list exp)     (*  n := f(e1,e2,e3,...)    *)
| Return (e: exp)                             (*  return e                *)
| Alloc (n: name) (e: exp)                    (*  n := malloc(e)          *)
| GetChar (n: name)                           (*  n := getchar()          *)
| PutChar (e: exp)                            (*  putchar(e)              *)
| Abort.                                      (*  exit(1)                 *)

Inductive func : Type :=
| Func (n: name) (params: list name) (body: cmd). (* func name, formal params, body *)

Inductive prog : Type :=
| Program (funcs: list func). (* a complete program is a list of function definitions *)

(* Values *)

Inductive Value :=
| Word (w: word64)
| Pointer (i: nat).

Definition value_eqb (v1 v2 : Value): bool :=
  match v1, v2 with
  | Word w1, Word w2 => word.eqb w1 w2
  | Pointer p1, Pointer p2 => p1 =? p2
  | _, _ => false
  end.
