From impboot Require Import utils.Core.
From coqutil Require Import dlet.
Require Import impboot.functional.FunValues.
Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.
From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message.
Require Import Coq.derive.Derive.

Ltac rewrite_let := match goal with
| [ |- context C [?subterm] ] =>
  match subterm with
  | let x := ?a in @?b x =>
    let C' := context C [b a] in
    change C'
  end
end.

Definition empty_state : state := init_state lnil [].

(* TODO(kπ) figure out a good example, this one gets constant folded *)
(* Example arith_example : forall n m,
  exists prog, FEnv.empty |-- (prog, empty_state) ---> ([Num (let x := 1 in x + n - m)], empty_state).
Proof.
  intros.
  rewrite_let.
  eexists. (* TODO(kπ) this simplifies my function :/ Is this a problem with normal code?*)
  eapply auto_let; eauto; intros.
  repeat match goal with
  | |-- context[_ + _] => eapply auto_num_add; eauto
  | |-- context[_ - _] => eapply auto_num_sub; eauto
  end.
  (* TODO(kπ) *)
Qed. *)

(* Ltac2 compile (c : constr) := 1. *)

(* Rupicola approach *)

(* Ltac autostep :=
  (* eapply trans_app ||
  eapply trans_Var ||
  eapply trans_Call ||
  eapply trans_nil ||
  eapply trans_cons || *)
  (* eapply auto_otherwise || *)
  eapply auto_bool_F ||
  eapply auto_bool_T ||
  eapply auto_bool_not ||
  eapply auto_bool_and ||
  eapply auto_bool_iff ||
  eapply last_bool_if ||
  (* eapply auto_num_const_zero || *)
  eapply auto_num_const ||
  eapply auto_num_add ||
  eapply auto_num_sub ||
  eapply auto_num_div ||
  eapply auto_num_if_eq ||
  eapply auto_num_if_less ||
  eapply auto_list_nil ||
  eapply auto_list_cons ||
  eapply auto_list_case ||
  eapply auto_option_none ||
  eapply auto_option_some ||
  eapply auto_option_case ||
  eapply auto_pair_fst ||
  eapply auto_pair_snd ||
  eapply auto_pair_cons ||
  eapply auto_pair_case ||
  eapply auto_char_CHR ||
  eapply auto_char_ORD ||
  eapply auto_word4_n2w ||
  eapply auto_word64_n2w ||
  eapply auto_word4_w2n ||
  eapply auto_word64_w2n ||
  (* This gets applied to eagerly *)
  eapply auto_let. *)

(* Derive f1 SuchThat
  (forall n m,
    exists prog,
      FEnv.empty |-- (prog, empty_state) --->
      ([encode (letd x := 1 in x + n - m)], empty_state))
  As f1_rpoof. *)

(* TODO(kπ) track free variables to name let_n (use Ltac2.Free) *)
Ltac2 rec compile (e : constr) (cenv : constr list) : constr :=
  lazy_match! e with
  | (dlet ?val ?body) =>
    let compiled_val := compile val cenv in
    let applied_body := eval_cbv beta open_constr:($body $val) in
    let compiled_body := compile applied_body (val :: cenv) in
    open_constr:(auto_let
    (* env *) _
    (* x1 y1 *) _ _
    (* s1 s2 s3 *) _ _ _
    (* v1 *) $val
    (* let_n *) _
    (* f *) $body
    (* eval v1 *) $compiled_val
    (* eval f *) $compiled_body
    )
  | true =>
    open_constr:(auto_bool_T
    (* env *) _
    (* s *) _
    )
  | false =>
    open_constr:(auto_bool_F
    (* env *) _
    (* s *) _
    )
  | (negb ?b) =>
    let compile_b := compile b cenv in
    open_constr:(auto_bool_not
    (* env *) _
    (* s *) _
    (* x1 *) _
    (* b *) $b
    (* eval x1 *) $compile_b
    )
  | (andb ?bA ?bB) =>
    let compile_bA := compile bA cenv in
    let compile_bB := compile bB cenv in
    open_constr:(auto_bool_and
    (* env *) _
    (* s *) _
    (* x1 x2 *) _ _
    (* bA bB *) $bA $bB
    (* eval x1 *) $compile_bA
    (* eval x2 *) $compile_bB
    )
  | (eqb ?bA ?bB) =>
    let compile_bA := compile bA cenv in
    let compile_bB := compile bB cenv in
    open_constr:(auto_bool_iff
    (* env *) _
    (* s *) _
    (* x1 x2 *) _ _
    (* bA bB *) $bA $bB
    (* eval x1 *) $compile_bA
    (* eval x2 *) $compile_bB
    )
  | (if ?b then ?t else ?f) =>
    let compile_b := compile b cenv in
    let compile_t := compile t cenv in
    let compile_f := compile f cenv in
    open_constr:(last_bool_if
    (* env *) _
    (* s *) _
    (* x_b x_t x_f *) _ _ _
    (* b t f *) $b $t $f
    (* eval x_b *) $compile_b
    (* eval x_t *) $compile_t
    (* eval x_f *) $compile_f
    )
  | (?n1 + ?n2) =>
    let compile_n1 := compile n1 cenv in
    let compile_n2 := compile n2 cenv in
    open_constr:(auto_num_add
    (* env *) _
    (* s0 s1 s2 *) _ _ _
    (* x1 x2 *) _ _
    (* n1 n2 *) $n1 $n2
    (* eval x1 *) $compile_n1
    (* eval x2 *) $compile_n2
    )
  | (?n1 - ?n2) =>
    let compile_n1 := compile n1 cenv in
    let compile_n2 := compile n2 cenv in
    open_constr:(auto_num_sub
    (* env *) _
    (* s0 s1 s2 *) _ _ _
    (* x1 x2 *) _ _
    (* n1 n2 *) $n1 $n2
    (* eval x1 *) $compile_n1
    (* eval x2 *) $compile_n2
    )
  | (?n1 / ?n2) =>
    let compile_n1 := compile n1 cenv in
    let compile_n2 := compile n2 cenv in
    open_constr:(auto_num_div
    (* env *) _
    (* s0 s1 s2 *) _ _ _
    (* x1 x2 *) _ _
    (* n1 n2 *) $n1 $n2
    (* eval x1 *) $compile_n1
    (* eval x2 *) $compile_n2
    (* n2 <> 0 *) _
    )
  | (if Nat.eqb ?n1 ?n2 then ?t else ?f) =>
    let compile_n1 := compile n1 cenv in
    let compile_n2 := compile n2 cenv in
    let compile_t := compile t cenv in
    let compile_f := compile f cenv in
    open_constr:(auto_num_if_eq
    (* A *) _
    (* env *) _
    (* s *) _
    (* x1 x2 y z *) _ _ _ _
    (* n1 n2 t f *) $n1 $n2 $t $f
    (* eval x1 *) $compile_n1
    (* eval x2 *) $compile_n2
    (* eval y *) $compile_t
    (* eval z *) $compile_f
    )
  | (if ?n1 <? ?n2 then ?t else ?f) =>
    let compile_n1 := compile n1 cenv in
    let compile_n2 := compile n2 cenv in
    let compile_t := compile t cenv in
    let compile_f := compile f cenv in
    open_constr:(auto_num_if_less
    (* env *) _
    (* s *) _
    (* x1 x2 y z *) _ _ _ _
    (* n1 n2 t f *) $n1 $n2 $t $f
    (* eval x1 *) $compile_n1
    (* eval x2 *) $compile_n2
    (* eval y *) $compile_t
    (* eval z *) $compile_f
    )

    | ?x =>
    (* TODO(kπ) We should handle shadowing things (or avoid any type of shadowing in the implementation) *)
    match find_opt (equal x) cenv with
    | Some _ =>
      open_constr:(trans_Var
      (* env *) _
      (* s *) _
      (* n *) _
      (* v *) $x
      (* FEnv.lookup *) _
      )
    | None =>
      open_constr:(auto_num_const
      (* env *) _
      (* s *) _
      (* n *) $x
      )
    end
  end.

Ltac2 doauto () :=
  match! goal with
  | [ |- _ |-- (_, _) ---> ([encode ?g], _) ] =>
    refine (compile g []);
    intros;
    eauto with fenvDb
  end.

Lemma arith_example : forall n,
  exists prog,
    FEnv.empty |-- (prog, empty_state) --->
    ([encode (letd x := 1 in x + n)], empty_state).
Proof.
  intros; eexists.
  doauto ().
  Show Proof.
  all: simpl.
  all: try (eapply auto_num_const).
  all: try (doauto ()).

  (* repeat (doauto ()). *)



  eapply auto_let; intros.
  all: try (eapply auto_num_add); intros.
  all: try (eapply auto_num_const); intros.
  (* all: repeat (autostep; intros). *)
  all: try eapply trans_Var; try eapply FEnv.lookup_insert_eq.
  all: repeat split.
  all: eauto.
  - exact I.
  - exact (fun n : nat => I).
  Unshelve.
  exact [].
  Show Proof.
  intros; eexists.
  Opaque encode.
  repeat (autostep; intros).
  Show Proof.

  (* eauto with automation. *)
