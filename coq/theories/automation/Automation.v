From impboot Require Import utils.Core.
From coqutil Require Import dlet.
Require Import impboot.functional.FunValues.
(* Require Import impboot.functional.FunSyntax. *)
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.
From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.
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

(* HOL4-ish approach *)

(* TODO(kπ) track free variables to name let_n (use Ltac2.Free) *)
Ltac2 rec compile (e : constr) (cenv : constr list) : constr :=
  print (of_constr e);
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
  (* bool *)
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
  (* num *)
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
  (* list *)
  | [] =>
    open_constr:(auto_list_nil
    (* env *) _
    (* s *) _
    )
  | (?x :: ?xs) =>
    let compile_x := compile x cenv in
    let compile_xs := compile xs cenv in
    open_constr:(auto_list_cons
    (* env *) _
    (* s *) _
    (* x1 x2 *) _ _
    (* x *) $x
    (* xs *) $xs
    (* eval x1 *) $compile_x
    (* eval x2 *) $compile_xs
    )
  | (list_CASE ?v0 ?v1 ?v2) =>
    let compile_v0 := compile v0 cenv in
    let compile_v1 := compile v1 cenv in
    let compile_v2 := (fun (xh : constr) (xt : constr) => compile (eval_cbv beta open_constr:($v2 $xh $xt)) (xh :: xt :: cenv)) in
    open_constr:(auto_list_case
    (* env *) _
    (* s *) _
    (* x0 x1 x2 *) _ _ _
    (* n1 n2 *) _ _
    (* v0 v1 v2 *) $v0 $v1 $v2
    (* eval x0 *) $compile_v0
    (* eval x1 *) $compile_v1
    (* TODO(kπ) not sure if the &-references are correct *)
    (* eval x2 *) (fun xh xt _ => ltac2:(Control.refine (fun () => (compile_v2 &xh &xt))))
    (* NoDup *) _
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

Ltac2 rec constr_to_list (c : constr) : constr list :=
  match! c with
  | [] => []
  | ?x :: ?xs => x :: constr_to_list xs
  end.

(* TODO(kπ) this only works when fun is the top level App in the compiled
expression, otherwise we might have to have a funtion from a constr (that is a
string) to reference. So constr stirng to string? *)
Ltac2 rec fun_ident (c : constr) : reference :=
  match kind c with
  | App f _ => reference_of_constr f
  | _ => reference_of_constr c
  end.

Ltac2 doauto () :=
  match! goal with
  | [ |- _ |-- (_, _) ---> ([encode ?g], _) ] =>
    refine (compile g []);
    intros;
    eauto with fenvDb
  (* TODO(kπ) we need to know whether it is the currently compiled function at some point  *)
  | [ h : (lookup_fun ?fname _ = _) |- eval_app ?fname ?args _ (encode ?g, _) ] =>
    let argsl := constr_to_list args in
    let f_ident := fun_ident g in
    let g_norm := eval_unfold [(f_ident, AllOccurrences)] g in
    print (of_string "g_norm");
    print (of_constr g_norm);
    let compile_g := compile g_norm argsl in
    let h_ref := Control.hyp h in
    refine open_constr:(trans_app
    (* n *) _
    (* params *) _
    (* vs *) $args
    (* body *) _
    (* s *) _
    (* s1 *) _
    (* v *) _
    (* eval body *) $compile_g
    (* params length eq *) _
    (* lookup_fun *) $h_ref
    )
  end.

Lemma arith_example : forall n,
  exists prog,
    FEnv.empty |-- (prog, empty_state) --->
    ([encode
      (letd x := 1 in x + n)
    ], empty_state).
Proof.
  intros; eexists.
  doauto ().
  Show Proof.
  exact "a"%string.
Qed.

Lemma list_example : forall (n : nat),
  exists prog,
    FEnv.empty |-- (prog, empty_state) --->
    ([encode
      (letd l := [1; 2; 3] in
      letd fnil := n in
      list_CASE l fnil (fun (x : nat) _ => x + 1))
    ], empty_state).
Proof.
  intros; eexists.
  (* Set Ltac2 Backtrace. *)
  doauto ().
  Show Proof.
  (* TODO(kπ) Common crush tactic for these vvv (free_vars, NoDup, in_nil) *)
  all: unfold FunProperties.free_vars; simpl.
  all: try (eapply NoDup_cons); try (eapply in_nil); try (eapply NoDup_nil).
  (* TODO(kπ) Also a common crush tactic for picking variable names *)
  (* TODO(kπ): Slow vvv *)
  (* - exact ("a"%string).
  - exact ("b"%string).
  - exact ("a"%string).
  - inversion e; subst; rewrite FEnv.lookup_insert_neq; try (rewrite FEnv.lookup_insert_eq); auto.
    unfold name_enc, name_enc_l; simpl; ltac1:(lia).
  - exact ("c"%string).
  - exact ("d"%string). *)
Admitted.

Lemma list_example2 : forall (n : nat),
  exists prog,
    FEnv.empty |-- (prog, empty_state) --->
    ([encode
      (letd l := [1; 2; 3] in
      letd fnil := n in
      list_CASE l fnil (fun (x : nat) xs =>
        list_CASE xs (x + 99) (fun (y : nat) _ => y + 1)
      ))
    ], empty_state).
Proof.
  intros; eexists.
  (* Set Ltac2 Backtrace. *)
  doauto ().
  Show Proof.
  (* TODO(kπ) Common crush tactic for these vvv (free_vars, NoDup, in_nil) *)
  all: unfold FunProperties.free_vars; simpl.
  all: try (eapply NoDup_cons); try (eapply in_nil); try (eapply NoDup_nil).
  (* TODO(kπ) Also a common crush tactic for picking variable names *)
  (* TODO(kπ): Slow vvv *)
  (* - exact ("a"%string).
  - exact ("b"%string).
  - exact ("c"%string).
  - exact ("b"%string).
  - exact ("a"%string).
  - exact ("f"%string).
  - eapply not_in_cons; split; try (eapply in_nil); unfold name_enc, name_enc_l; simpl; ltac1:(lia).
  - eapply NoDup_cons; try (eapply in_nil); try (eapply NoDup_nil).
  - inversion e; subst; rewrite FEnv.lookup_insert_neq; try (rewrite FEnv.lookup_insert_eq); auto.
    unfold name_enc, name_enc_l; simpl; ltac1:(lia).
  - inversion e; subst; rewrite FEnv.lookup_insert_neq; try (rewrite FEnv.lookup_insert_eq); auto.
    unfold name_enc, name_enc_l; simpl; ltac1:(lia).
  - exact ("g"%string).
  - exact ("h"%string). *)
Admitted.

Definition foo (n : nat) : nat :=
  letd x := 1 in
  letd y := n + x in
  y.

Lemma function_example : forall (s : state) (n : nat),
  exists prog,
    lookup_fun (name_enc "foo") s.(funs) = Some ([name_enc "n"], prog) ->
      eval_app (name_enc "foo") [encode n] s (encode (foo n), s).
Proof.
  intros; eexists; intros.

  (* TODO(kπ) This inlined the `y` :thinking: *)
  doauto ().
  Show Proof.
  - simpl; ltac1:(reflexivity).
  - exact "a"%string.
  - exact "b"%string.
  - exact "a"%string.
  - exact "b"%string.
  Unshelve.
Admitted.

(*
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

  eauto with automation. *)

