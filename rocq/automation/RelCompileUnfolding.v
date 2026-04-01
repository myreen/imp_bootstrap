From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.
From impboot Require Import Ltac2Utils ltac2.Constrs ltac2.Stdlib2 RelCompilerCommons.

Ltac rewrite_let :=
  match goal with
  | [ |- context C [?subterm] ] =>
    match subterm with
    | let x := ?a in @?b x =>
      let C' := context C [b a] in
      change C'
    end
  end.

Ltac2 rec has_fix_inside (c: constr): bool :=
  match Unsafe.kind c with
  | Fix _ _ _ _ => true
  | Lambda _ c =>
    has_fix_inside c
  | _ => false
  end.

Ltac2 isFix (fconstr: constr): bool :=
  let fref := reference_of_constr fconstr in
  let unfolded := Std.eval_unfold [(fref, AllOccurrences)] fconstr in
  if debug_relcompile then printf "Unfolded %t is %t" fconstr unfolded else ();
  has_fix_inside unfolded.

Ltac2 rewrite_with_equation (fconstr: constr): unit :=
  let fref: reference option := reference_of_constr_opt fconstr in
  let f_str: string option := Option.bind fref reference_to_string in
  let f_equation_str: string option := Option.map (fun n => String.app n "_equation") f_str in
  let f_equation_ident: ident list option := Option.map (fun s => ident_of_fqn [s]) f_equation_str in
  (* print (messsage_of_option (Option.map (fun l => messsage_of_list (List.map Message.of_ident l)) f_equation_ident)); *)
  let f_equation_ref: reference list := List.flat_map (fun id => Env.expand id) (opt_to_list f_equation_ident) in
  match f_equation_ref with
  | [ref] =>
    let instance := Env.instantiate ref in
    let make_rw law := { Std.rew_orient := Some Std.LTR;
                       Std.rew_repeat := Std.RepeatPlus;
                       Std.rew_equatn := (fun () => (law, Std.NoBindings)) } in
    rewrite0 false [make_rw instance] None None;
    cbv beta
  | [] =>
    Control.throw (Oopsie (fprintf "No _equation lemmas found for definition %t" fconstr))
  | _ =>
    Control.throw (Oopsie (fprintf "Too many _equation lemmas found for definition %t" fconstr))
  end.

Ltac2 unfold_ref_everywhere (r: reference): unit :=
  let cl := default_on_concl None in
  Std.unfold [(r, AllOccurrences)] cl.

Ltac2 unfold_once (fconstr: constr) (fargs: constr list): unit :=
  let cname_ref := reference_of_constr_opt fconstr in
  (if opt_is_empty cname_ref then
    Control.throw (Oopsie (fprintf "Error: Expected a named function application, got: %t" fconstr))
  else ());
  let cname_ref := Option.get cname_ref in
  if isFix fconstr then
    let all_fargs_ids := List.map var_ident_of_constr fargs in
    let non_type_fargs_ids := List.map var_ident_of_constr (List.filter (fun c => Bool.neg (Constrs.is_sort (Constr.type c))) fargs) in
    Std.revert non_type_fargs_ids;
    let struct_idx := Constrs.struct_of_fix fconstr in
    let struct_id := List.nth all_fargs_ids struct_idx in
    let new_struct_idx := Option.get (index_of struct_id non_type_fargs_ids) in
    let hname := Fresh.in_goal (Option.get (Ident.of_string "IH")) in
    Std.fix_ hname (Int.add new_struct_idx 1);
    intros;
    rewrite_with_equation fconstr
  else
    unfold_ref_everywhere cname_ref.

(* TESTS: *)

(* Definition has_match (l: list nat) : nat :=
  1 +
  match l with
  | nil => 0
  | cons h t => h + 100
  end.

Lemma has_match_equation : ltac:(unfold_tpe has_match).
Proof. ltac1:(unfold_proof). Qed.

About has_match_equation.

Fixpoint sum_n (n : nat) : nat :=
  match n with
  | 0 => 1 + 1
  | S n1 => (sum_n n1)(*  + n *)
  end.

Lemma sum_n_equation : ltac:(unfold_tpe sum_n).
Proof. ltac1:(unfold_proof). Qed.

About sum_n_equation.

Goal forall n, sum_n n = 1.
Proof.
  intros.
  rewrite_with_equation constr:(sum_n).
  (* unfold_once constr:(sum_n) constr:(forall n, sum_n n = 1). *)
  (* rewrite sum_n_equation. *)
  (* ltac1:(unfold_fix sum_n). *)
Abort.

Goal forall l, has_match l = 1.
Proof.
  intros.
  (* rewrite has_match_equation. *)
  (* unfolded_def constr:(has_match). *)
  (* ltac1:(unfold_fix has_match). *)
Abort. *)