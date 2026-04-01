From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.
From impboot Require Import Ltac2Utils.

Ltac2 is_sort (c: constr): bool :=
  match Unsafe.kind c with
  | Unsafe.Sort _ => true
  | _ => false
  end.

Ltac2 rec struct_of_fix_impl (c: constr): int :=
  match Unsafe.kind c with
  | Fix structs _ _ _ =>
    Array.get structs 0
  | Lambda _ c =>
    Int.add 1 (struct_of_fix_impl c)
  | _ =>
    Control.throw (Oopsie (fprintf "not a fix; %t" c))
  end.
Ltac2 struct_of_fix (fconstr: constr): int :=
  let fref := reference_of_constr fconstr in
  let unfolded := Std.eval_unfold [(fref, AllOccurrences)] fconstr in
  struct_of_fix_impl unfolded.

Ltac2 rec in_contexts (bs: binder list) (c: unit -> constr) (): constr :=
  match bs with
  | [] => c ()
  | b :: bs =>
    (* let name := Option.default (Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "x"))) (Binder.name b) in *)
    let name := Option.get (Binder.name b) in
    (* it should ideally be (Binder.type b) instead of open_constr:(_), but it breaks the current procedure for dependent types *)
    Constr.in_context name open_constr:(_) (fun () =>
      (* let b_hyp := Control.hyp name in *)
      let r := in_contexts bs c in
      Control.refine r
    )
  end.

Ltac2 rec lambda_to_prod (c: constr): constr :=
  match Unsafe.kind c with
  | Lambda b body => make (Prod b (lambda_to_prod body))
  | _ => c
  end.

Ltac2 rec apply_to_args (fn: constr) (args: constr list) :=
  match args with
  | [] => fn
  | arg :: args =>
    apply_to_args open_constr:($fn $arg) args
  end.

Ltac2 rec binders_of_lambda (c: constr): binder list :=
  match Unsafe.kind c with
  | Lambda b c1 =>
    b :: binders_of_lambda c1
  | _ => []
  end.

Ltac2 rec prod_binder_names (c: constr): ident list :=
  match Unsafe.kind c with
  | Prod b c =>
    Fresh.in_goal (Option.get (Binder.name b)) :: prod_binder_names c
  | _ => []
  end.