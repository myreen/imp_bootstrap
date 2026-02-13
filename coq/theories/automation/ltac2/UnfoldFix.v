From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.
From impboot Require Import Ltac2Utils ltac2.Constrs ltac2.Stdlib2 ltac2.Messages.

(* TODO: *)
(* - Currently it throws No_value, if a non polymorphic reference to a polymorphic function is passed *)

Ltac2 unfold_fix_impl (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let unfolded := Std.eval_unfold [(fref, AllOccurrences)] fconstr in
  match Unsafe.kind unfolded with
  | Fix structs _i bs cs =>
    let body := Array.get cs 0 in
    let struct := Array.get structs 0 in
    let fix_b := Array.get bs 0 in
    let _fix_name := Option.get (Binder.name fix_b) in
    let body_bs := Constrs.binders_of_lambda body in
    let body_bs_names := List.map (fun b => Option.get (Binder.name b)) body_bs in
    let struct_name := List.nth body_bs_names struct in
    let res := Constrs.in_contexts body_bs (fun () =>
      let outer_args := List.map Control.hyp body_bs_names in
      let fconstr_applied := Constrs.apply_to_args fconstr outer_args in
      let rhs := fun () => Control.enter (fun () =>
        let ind_clause := {
          indcl_arg := (ElimOnIdent struct_name);
          indcl_eqn := None;
          indcl_as := None;
          indcl_in := None;
        } in
        Std.destruct false [ind_clause] None;
        Control.refine (fun () => open_constr:(_))
      ) in
      open_constr:($fconstr_applied = ltac2:(rhs ()))
    ) in
    let res := fun () => Std.eval_cbv beta (res ()) in
    let res := fun () => lambda_to_prod (res ()) in
    Control.refine res
  | _ =>
    Control.throw (Oopsie (fprintf "Wrong definition passed to unfold_fix_tpe, namely %t" fconstr))
  end.

Ltac2 unfold_fix_gen (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let unfolded_fix_template := open_constr:(ltac2:(unfold_fix_impl fconstr)) in
  ltac1:(unfolded_fix_template |- instantiate(1 := unfolded_fix_template)) (Ltac1.of_constr unfolded_fix_template);
  let nms := prod_binder_names (Control.goal ()) in
  Std.intros false (List.map (fun nm => IntroNaming (IntroFresh nm)) nms);
  let struct_name := List.nth nms (Constrs.struct_of_fix fconstr) in
  let struct_hyp := Control.hyp struct_name in
  (* Std.case true (struct_hyp, NoBindings); *)
  destruct $struct_hyp eqn:Heqleft at 1;
  Control.enter (fun () =>
    destruct $struct_hyp eqn:Heqright at 1;
    Control.enter (fun () =>
      rewrite &Heqleft in Heqright; inversion Heqright; subst;
      Control.plus (fun () => (ltac1:(congruence))) (fun _ =>
        unfold $fref; fold $fconstr;
        reflexivity ()
      )
    )
  ).

Ltac2 unfold_fix_type fn :=
  let unfolded := open_constr:(ltac2:(Control.enter (fun () => unfold_fix_gen fn))) in
  let t := Constr.type unfolded in
  Control.refine (fun () => open_constr:($t)).

Ltac2 unfold_fix_proof (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let nms := prod_binder_names (Control.goal ()) in
  Std.intros false (List.map (fun nm => IntroNaming (IntroFresh nm)) nms);
  let struct_name := List.nth nms (Constrs.struct_of_fix fconstr) in
  let struct_hyp := Control.hyp struct_name in
  destruct $struct_hyp;
  Control.enter (fun () =>
    unfold $fref; fold $fconstr;
    reflexivity ()
  ).

(* Examples *)

(* Fixpoint sum_n (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 => (sum_n n1) + n
  end.
Lemma sum_n_equation : ltac2:(unfold_fix_type 'sum_n). *)

Fixpoint sum_n1 (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 => (sum_n1 n1) + (n1 + 1)
  end.
Lemma sum_n1_equation : ltac2:(unfold_fix_type 'sum_n1).
Proof. unfold_fix_proof 'sum_n1. Qed.

Fixpoint is_even (n: nat): bool :=
  match n with
  | 0 => true
  | S n1 => is_odd n1
  end
with is_odd (n: nat): bool :=
  match n with
  | 0 => false
  | S n1 => is_even n1  
  end.
Print is_even.
(* TODO: fix me *)
Lemma is_even_equation: ltac2:(unfold_fix_type 'is_even).
Proof. unfold_fix_proof 'is_even. Qed.
About is_even_equation.