From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.
From impboot Require Import Ltac2Utils ltac2.Constrs ltac2.Stdlib2.

(* Plan:
- a tactic that rewrites a given constr, such that:
  - every expression except of variable references, constants, or lists of these is let-bound
  - so, every (arithmetic operation, function call, constructor call) is let-bound
  - top level commands are only lets, ifs, matches or a final expr (satisfying the above)
  - the tactic returns the new constr
*)

(* Examples:

1 + 2 + 3
-->
let x1 := 1 + 2 in
let x2 := x1 + 3 in
x2

f x (g y + 3)
-->
let x1 := g y in
let x2 := x1 + 3 in
let x3 := f x x2 in
x3

!The let's should be propagated to the level of the definition!

*)

(* 
Ltac2 Type kind := [
| Rel (int)
| Var (ident)
| Meta (meta)
| Evar (evar, constr array)
| Sort (sort)
| Cast (constr, cast, constr)
| Prod (binder, constr)
| Lambda (binder, constr)
| LetIn (binder, constr, constr)
| App (constr, constr array)
| Constant (constant, instance)
| Ind (inductive, instance)
| Constructor (constructor, instance)
| Case (case, (constr * Binder.relevance), case_invert, constr, constr array)
| Fix (int array, int, binder array, constr array)
| CoFix (int, binder array, constr array)
| Proj (projection, Binder.relevance, constr)
| Uint63 (uint63)
| Float (float)
| String (pstring)
| Array (instance, constr array, constr, constr)
].
*)

(* Ltac2 rec deinline (c: constr): constr :=
  match Unsafe.kind c with
  | Unsafe.Rel _ => c
  | Unsafe.Var v => c
  | Unsafe.Meta _ => c
  | Unsafe.Evar (evar, args) => c
  | Unsafe.Sort _ => c
   *)
