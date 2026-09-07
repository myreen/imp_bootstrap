From Ltac2 Require Import Ltac2 Constr Std RedFlags FMap Message Printf.
From impboot.automation.ltac2 Require Import Messages Constrs Stdlib2.
From impboot.automation Require Import Ltac2Utils.
From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
From impboot.functional Require Import FunSemantics FunValues.
From coqutil Require Import dlet.
From coqutil Require Import Word.Interface.

Open Scope nat.

Ltac2 mutable debug_to_anf := false.

Ltac2 rec proper_const_f (c: constr): bool :=
  match Constr.Unsafe.kind c with
  | Unsafe.Constructor _ _ => true
  | Unsafe.App c cs => Bool.and (proper_const_f c) (Array.for_all proper_const_f cs)
  | _ => false
  end.

Ltac2 is_list_type (c: constr): bool :=
  match Constr.Unsafe.kind (Constr.type c) with
  | Unsafe.App f _ =>
    Constr.equal f (constr:(list))
  | _ => false
  end.

Ltac2 allowed_const_type (c: constr): bool :=
  let tpe := Constr.type c in
  Bool.or (Constr.equal tpe constr:(nat))
  (Bool.or (Constr.equal tpe constr:(N))
  (Bool.or (Constr.equal tpe constr:(Z))
  (Bool.or (Constr.equal tpe constr:(string))
  (Bool.or (Constr.equal tpe constr:(ascii))
  (is_list_type c))))).

Ltac2 proper_const (c: constr): bool :=
  let evaluated := eval_cbv beta c in
  let is_const := proper_const_f evaluated in
  Bool.and is_const (allowed_const_type evaluated).

Ltac2 is_list_like_const (c: constr) :=
  Bool.and (proper_const c) (Bool.or (Constr.equal (Constr.type c) constr:(string)) (is_list_type c)).

Ltac2 is_list_literal (c: constr) :=
  Bool.and (is_list_type c) (match! c with
  | _ :: _ => true
  | [] => true
  | _ => false
  end).

Ltac2 rec is_allowed (c: constr): bool :=
  Control.once (fun _ => Control.plus (fun _ =>
  match! c with
  | word.of_Z ?c1 => is_allowed c1
  | word.unsigned ?c1 => is_allowed c1
  | Z.of_nat ?c1 => is_allowed c1
  | Z.of_N ?c1 => is_allowed c1
  | Z.to_N ?c1 => is_allowed c1
  | N.to_nat ?c1 => is_allowed c1
  | N.of_nat ?c1 => is_allowed c1
  | name_enc ?c1 => is_allowed c1
  | N_of_ascii ?c1 => is_allowed c1
  | _ =>
    Bool.or (proper_const c)
    (Bool.or (is_var c)
    (Bool.or (Constrs.is_sort (Constr.type c))
    (is_in_Prop c)))
  end) (fun _ => false)).

Module ConstrMap.
  Ltac2 Type t := (constr * constr) list.
  Ltac2 empty: t := [].
  Ltac2 add (k: constr) (v: constr) (m: t): t := (k, v) :: m.
  Ltac2 rec find_opt (k: constr) (m: t): constr option :=
    match m with
    | [] => None
    | (k', v) :: m =>
      if Constr.equal k k' then Some v else find_opt k m
    end.
End ConstrMap.

Ltac2 rec replace_with_lifts (e: constr) (lifts: ConstrMap.t): constr :=
  match ConstrMap.find_opt e lifts with
  | Some lifted =>
    lifted
  | None =>
    if is_allowed e then e else (
    match! e with
    | let/d x := ?e1 in ?e2 =>
      let e1_replaced := replace_with_lifts e1 lifts in
      let e2_replaced := replace_with_lifts e2 lifts in
      let result := constr:(let/d x := $e1_replaced in $e2_replaced) in
      result
    | _ =>
      match Unsafe.kind e with
      | Unsafe.App f args =>
        let f_replaced := replace_with_lifts f lifts in
        let args_replaced := Array.map (fun arg => replace_with_lifts arg lifts) args in
        let unsf_app_new := Unsafe.App f_replaced args_replaced in
        let result := Unsafe.make unsf_app_new in
        result
      | Unsafe.Cast c k t =>
        let c_replaced := replace_with_lifts c lifts in
        let unsf_cast_new := Unsafe.Cast c_replaced k t in
        let result := Unsafe.make unsf_cast_new in
        result
      | _ => e
      end
    end)
  end.

Ltac2 constr_type_with_fallback (c: constr) (fallback: constr): constr :=
  Control.once (fun _ => Control.plus (fun _ => Constr.type c) (fun _ =>
    (if debug_to_anf then printf "constr_type_with_fallback: Failed to get type of %t, using fallback %t" c fallback else ());
    fallback
  )).

Ltac2 rec in_letd_definitions (dlet_rhss: constr list) (to_replace: constr list) (acc_lifts: ConstrMap.t) (continuation: (ConstrMap.t) -> constr) (): constr :=
  match dlet_rhss, to_replace with
  | ([], []) => continuation (acc_lifts)
  | (e :: dlet_rhss, re :: to_replace) =>
    let tmp_ident := Fresh.in_goal (Option.get (Ident.of_string "a")) in
    let fn := Constr.in_context tmp_ident (constr_type_with_fallback e constr:(string)) (fun _ =>
      let tmp_constr := Unsafe.make (Unsafe.Var tmp_ident) in
      let new_lifts := ConstrMap.add e tmp_constr acc_lifts in
      let new_lifts := ConstrMap.add re tmp_constr new_lifts in
      let to_lift_new := List.map (fun constr => replace_with_lifts constr new_lifts) dlet_rhss in
      let lifted := in_letd_definitions to_lift_new to_replace new_lifts continuation in
      Control.refine lifted
    ) in
    constr:(dlet $e $fn)
  | _, _ =>
    continuation (acc_lifts)
  end.

Ltac2 rec to_anf_alt (level: int) (in_list: bool) (e: constr): (constr list * constr) :=
  if is_allowed e then
    if is_list_like_const e then ([e], e)
    else ([], e)
  else
  match! e with
  | dlet ?e1 ?e2 =>
    let (e1_lifts, e1_anf) := to_anf_alt 0 false e1 in
    let all_lifts := e1_lifts in
    let lifted_anf := in_letd_definitions all_lifts all_lifts ConstrMap.empty (fun lifts =>
      let e1_anf_replaced := replace_with_lifts e1_anf lifts in
      constr:(dlet $e1_anf_replaced $e2)
    ) () in
    ([], lifted_anf)
  | _ =>
    match Unsafe.kind e with
    | Unsafe.App f args =>
      let args_lifts_and_anfs := Array.map (to_anf_alt (Int.add level 1) (is_list_literal e)) args in
      let args_lifts := Array.to_list (Array.map fst args_lifts_and_anfs) in
      let args_anfs := Array.map snd args_lifts_and_anfs in
      let all_lifts := List.concat args_lifts in
      (* do not lift here, just pass them *)
      let new_app := Unsafe.make (Unsafe.App f args_anfs) in
      let lifts_new := if Bool.or (Int.equal level 0) (Bool.and in_list (is_list_literal e)) then all_lifts else List.append all_lifts [new_app] in
      (lifts_new, new_app)
    | Unsafe.Cast c k t =>
      let (c_lifts, c_anf) := to_anf_alt level in_list c in
      let new_cast := Unsafe.make (Unsafe.Cast c_anf k t) in
      (c_lifts, new_cast)
    (* don't replace under binders *)
    | Unsafe.Case _ _ _ _ _ => ([], e)
    | Unsafe.Lambda _ _ => ([], e)
    | Unsafe.Var _ => ([], e)
    | _ => ([e], e)
    end
  end.

Ltac2 to_anf_final (e: constr): constr :=
  Control.once (fun _ => Control.plus (
    let (lift_exps, e_anf) := to_anf_alt 1 false e in
    let res := in_letd_definitions lift_exps lift_exps ConstrMap.empty (fun lifts =>
      replace_with_lifts e_anf lifts
    ) in
    res
  ) (fun _ => (if debug_to_anf then printf "to_anf_alt threw an exception, returning the original expression %t" e else ()); e)).

Ltac2 try_to_anf_relcompile () :=
  lazy_match! goal with
  | [ |- _ |-- (_, _) ---> ([encode ?c], _) ] =>
    lazy_match! c with
    | context _ctxt [ _ ] =>
      (if debug_to_anf then printf "Trying to convert %t into ANF form" c else ());
      let anf := to_anf_final c in
      (if debug_to_anf then printf "ANF form: %t" anf else ());
      try (ltac1:(c anf |- change c with anf) (Ltac1.of_constr c) (Ltac1.of_constr anf))
    end
  end.
