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
  (* | Var _ => true *)
  (* TODO: probably should remove this (next) line – it allows too many undesirable things as consts *)
  (* | Unsafe.Constant _ _ => true *)
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
      (Constrs.is_sort (Constr.type c)))
  end.

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
  Ltac2 print (m: t): unit :=
    printf "ConstrMap contents:";
    List.iter (fun (kv: constr * constr) =>
      let (k, v) := kv in
      printf "  %t -> %t" k v
    ) m.
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

Ltac2 rec in_letd_definitions (dlet_rhss: constr list) (to_replace: constr list) (acc_lifts: ConstrMap.t) (continuation: (ConstrMap.t) -> constr) (): constr :=
  match dlet_rhss, to_replace with
  | ([], []) => continuation (acc_lifts)
  | (e :: dlet_rhss, re :: to_replace) =>
    let tmp_ident := Fresh.in_goal (Option.get (Ident.of_string "a")) in
    let fn := Constr.in_context tmp_ident (Constr.type e) (fun _ =>
      let tmp_constr := Unsafe.make (Unsafe.Var tmp_ident) in
      let new_lifts := ConstrMap.add e tmp_constr acc_lifts in
      let new_lifts := ConstrMap.add re tmp_constr new_lifts in
      let to_lift_new := List.map (fun constr => replace_with_lifts constr new_lifts) dlet_rhss in
      let lifted := in_letd_definitions to_lift_new to_replace new_lifts continuation in
      Control.refine lifted
    )
    in
    constr:(dlet $e $fn)
  | _, _ =>
    continuation (acc_lifts)
  end.

(* might want to run dedup on constrs to lift (but a different equality than Constr.equal might be nice – it is too precise) *)
Ltac2 rec to_anf_alt (level: int) (in_list: bool) (e: constr): (constr list * constr) :=
  if is_allowed e then
    if is_list_like_const e then ([e], e)
    else ([], e)
  else
  match! e with
  | dlet ?e1 ?e2 =>
    let (e1_lifts, e1_anf) := to_anf_alt 0 false e1 in
    let (_, e2_anf) := to_anf_alt 0 false e2 in
    let all_lifts := e1_lifts in
    let lifted_anf := in_letd_definitions all_lifts all_lifts ConstrMap.empty (fun lifts =>
      let e1_anf_replaced := replace_with_lifts e1_anf lifts in
      constr:(dlet $e1_anf_replaced $e2_anf)
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
    | _ => 
      let new_lifts := [e] in
      (new_lifts, e)
    end
  end.

Ltac2 to_anf_final (e: constr): constr :=
  let (lift_exps, e_anf) := to_anf_alt 1 false e in
  in_letd_definitions lift_exps lift_exps ConstrMap.empty (fun lifts =>
    let result := replace_with_lifts e_anf lifts in
    result
  ) ().

Ltac2 try_to_anf_relcompile () :=
  match! goal with
  | [ |- _ |-- (_, _) ---> ([encode ?c], _) ] =>
    match! c with
    | context _ctxt [ _ ] =>
      let anf := to_anf_final c in
      (if debug_to_anf then printf "ANF form: %t" anf else ());
      (* TODO: benchmark if rewrite is actually that much worse *)
      (* try (assert ( $c = $anf) as -> by (reflexivity ())) *)
      (* let inst := Pattern.instantiate ctxt anf in *)
      (* printf "Replacing %t with its ANF form %t in the goal" c anf; *)
      (* TODO: this doesn't work :/ *)
      (* try (change $inst) *)
      (* Control.plus (fun _ => change $inst) (fun _ =>
        printf "Failed to change %t with %t, trying rewrite instead" c anf;
        Control.plus (fun _ => assert ($c = $anf) as -> by (reflexivity ())) (fun _ =>
          (* can I throw something outside of a match? the match consumes the error *)
          printf "Failed to change %t into ANF form %t, even with rewrite" c anf;
          ()
        )
      ) *)
       (* TODO: this also sometimes doesn't work (e.g. for `[]` -> `let/d l := [] in l` ) *)
      try (ltac1:(c anf |- change c with anf) (Ltac1.of_constr c) (Ltac1.of_constr anf))
    end
  end.

(* TEST *)

Inductive Animal := Dog | Cat | Fish.

Definition foo1 (x y : nat) (l: list Animal): nat :=
  x + y.

Ltac2 toANF () :=
  Control.enter (fun () =>
    match! goal with
    | [ |- ?c = _ ] =>
      let anf := to_anf_final c in
      printf "ANF form: %t" anf;
      try (assert ( $c = $anf) as -> by (reflexivity ()))
    end
  ).

Goal forall x y, match x with
  | 0 => y
  | S x1 => foo1 x (y + (x * 2)) [Dog; Cat]
  end = 1.
  intros.
  destruct x.
  all: toANF ().
  Show Proof.
  (* ltac1:(replace (foo1 x (y + 1)) with (let/d a := x in
                             let/d b := y + 1 in
                             let/d c := foo1 a b in
                             c) by reflexivity). *)
Abort.

Open Scope string_scope.

(* Ltac2 Set debug_to_anf := true. *)

Goal (let/d s := "ab" ++ "cd" in
      List.length (list_ascii_of_string (s ++ ""))) = 8.
  toANF ().
Abort.

Definition l1: list nat := [1].
Definition l2: list nat := [2].
Definition l3: list nat := [3].
Definition l4: list nat := [4].
Definition l5: list nat := [5].
Definition l6: list nat := [6].
Definition l7: list nat := [7].

Goal forall f is (is2str: nat -> nat -> string),
  (f [l1; l2; l3; l4; l5; l6; l7] ++ is2str 0 is)%string = "".
  intros.
  toANF ().
Abort.

From impboot.assembly Require Import ASMSyntax.

Goal forall k (l: nat -> list instr),
  (([
    (*  0 *) ASMSyntax.Const RAX (word.of_Z (Z.of_nat 0));
    (*  1 *) ASMSyntax.Const R12 (word.of_Z (Z.of_nat 16));
    (*  2 *) ASMSyntax.Const R13 (word.of_Z (Z.of_N (9223372036854775807%N)));
    (* jump to main function *)
    (*  3 *) ASMSyntax.Call k;
    (* return to exit 0 *)
    (*  4 *) ASMSyntax.Const RDI (word.of_Z (Z.of_nat 0));
    (*  5 *) ASMSyntax.Exit
  ]%string ++ (l 1))%list = []).
  intros.
  toANF ().
Abort.

Goal forall x,
  (let/d s := (name_enc "x") + (x + 1) in s)%N = 2%N.
  intros.
  toANF ().
Abort.
