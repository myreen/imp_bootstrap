From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.
From impboot Require Import Ltac2Utils ltac2.Constrs ltac2.Stdlib2 ltac2.Messages.

Ltac2 Type exn ::= [
  CannotUnfold (constr)
].

Ltac2 reference_to_string (r : reference) : string option :=
  Some (Ident.to_string (List.last (Env.path r))).

Ltac2 rec apply_to_hyps (c: constr) (hyps: ident list): constr :=
  match hyps with
  | [] => c
  | h :: hs =>
    let hyp := Control.hyp h in
    apply_to_hyps open_constr:($c $hyp) hs
  end.

Ltac2 rec unfold_fix_go (fconstr: constr) (c: constr): unit :=
  match Unsafe.kind c with
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
  | Lambda _ _ =>
    let bs := binders_of_lambda c in
    let res := Constrs.in_contexts bs (fun () =>
      let nms := List.map (fun b => Option.get (Binder.name b)) bs in
      open_constr:(ltac2:(unfold_fix_go (apply_to_hyps fconstr nms) (Std.eval_cbv beta (apply_to_hyps c nms))))
    ) in
    let res := fun () => Std.eval_cbv beta (res ()) in
    let res := fun () => lambda_to_prod (res ()) in
    Control.refine res
  | _ =>
    Control.throw (CannotUnfold c)
  end.

Ltac2 unfold_fix_impl (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let unfolded: constr := Std.eval_unfold [(fref, AllOccurrences)] fconstr in
  unfold_fix_go fconstr unfolded.

Ltac2 unfold_fix_gen (fconstr: constr): unit :=
  let _fref := reference_of_constr fconstr in
  let unfolded_fix_template := open_constr:(ltac2:(unfold_fix_impl fconstr)) in
  ltac1:(unfolded_fix_template |- instantiate(1 := unfolded_fix_template)) (Ltac1.of_constr unfolded_fix_template);
  let nms := prod_binder_names (Control.goal ()) in
  Std.intros false (List.map (fun nm => IntroNaming (IntroFresh nm)) nms);
  let struct_name := List.nth nms (Constrs.struct_of_fix fconstr) in
  let struct_hyp := Control.hyp struct_name in
  intros;
  destruct $struct_hyp;
  Control.enter (fun () =>
    Control.enter (fun () =>
      Control.plus (fun () => (ltac1:(congruence))) (fun _ =>
        simpl;
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
