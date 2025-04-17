From impboot Require Import utils.Core.
From coqutil Require Import dlet.
Require Import impboot.functional.FunValues.
Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.
From Ltac2 Require Import Ltac2.
From Ltac2 Require Import Message.
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
  exists prog, Env.empty |-- (prog, empty_state) ---> ([Num (let x := 1 in x + n - m)], empty_state).
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
      Env.empty |-- (prog, empty_state) --->
      ([encode (letd x := 1 in x + n - m)], empty_state))
  As f1_rpoof. *)

Ltac2 Type rec clist := [
  | Lnil
  | Lcons (constr, clist)
].

Ltac2 compile (e : constr) (env : clist) : constr :=
  match! e with
  | _ |-- (_, _) ---> ([encode (dlet ?val ?body)], _) =>
    open_constr:(auto_let
    (* b1 *) _
    (* b2 *) _
    (* env *) _
    (* x1 y1 *) _ _
    (* s1 s2 s3 *) _ _ _
    (* v1 *) ltac2:(val)
    (* let_n *) _
    (* f *) ltac2:(body)
    (* eval v1 *) _
    (* eval v2 *) _
    (* b1 /\ b2 *) _
    )
  | _ |-- (_, _) ---> ([encode true], _) =>
    open_constr:(auto_bool_T
    (* env *) _
    (* s *) _
    )
  | _ |-- (_, _) ---> ([encode false], _) =>
    open_constr:(auto_bool_F
    (* env *) _
    (* s *) _
    )
  | _ |-- (_, _) ---> ([encode (negb _)], _) =>
    open_constr:(auto_bool_not
    (* env *) _
    (* s *) _
    (* x1 *) _
    (* b *) _
    (* eval x1 *) _
    )
  | _ |-- (_, _) ---> ([encode (andb _ _)], _) =>
    open_constr:(auto_bool_and
    (* env *) _
    (* s *) _
    (* x1 x2 *) _ _
    (* bA bB *) _ _
    (* eval x1 *) _
    (* eval x2 *) _
    )
  | _ |-- (_, _) ---> ([encode (eqb _ _)], _) =>
    open_constr:(auto_bool_iff
    (* env *) _
    (* s *) _
    (* x1 x2 *) _ _
    (* bA bB *) _ _
    (* eval x1 *) _
    (* eval x2 *) _
    )
  | _ |-- (_, _) ---> ([encode (if _ then _ else _)], _) =>
    open_constr:(last_bool_if
    (* env *) _
    (* s *) _
    (* x_g x_t x_f *) _ _ _
    (* b t f *) _ _ _
    (* eval x_g *) _
    (* eval x_t *) _
    (* eval x_f *) _
    )
  | _ |-- (_, _) ---> ([encode (_ + _)], _) =>
    open_constr:(auto_num_add
    (* b0 b1 *) _ _
    (* env *) _
    (* s0 s1 s2 *) _ _ _
    (* x1 x2 *) _ _
    (* n1 n2 *) _ _
    (* eval x1 *) _
    (* eval x2 *) _
    (* b0 /\ b1 *) _
    )
  | _ |-- (_, _) ---> ([encode (_ - _)], _) =>
    open_constr:(auto_num_sub
    (* b0 b1 *) _ _
    (* env *) _
    (* s0 s1 s2 *) _ _ _
    (* x1 x2 *) _ _
    (* n1 n2 *) _ _
    (* eval x1 *) _
    (* eval x2 *) _
    (* b0 /\ b1 *) _
    )
  | _ |-- (_, _) ---> ([encode (_ / _)], _) =>
    open_constr:(auto_num_div
    (* b0 b1 *) _ _
    (* env *) _
    (* s0 s1 s2 *) _ _ _
    (* x1 x2 *) _ _
    (* n1 n2 *) _ _
    (* eval x1 *) _
    (* eval x2 *) _
    (* b0 /\ b1 /\ n2 <> 0 *) _
    )
  | _ |-- (_, _) ---> ([encode (if Nat.eqb _ _ then _ else _)], _) =>
    open_constr:(auto_num_if_eq
    (* A *) _
    (* b0 b1 b2 b3 *) _ _ _ _
    (* env *) _
    (* s *) _
    (* x1 x2 y z *) _ _ _ _
    (* n1 n2 t f *) _ _ _ _
    (* a *) _
    (* eval x1 *) _
    (* eval x2 *) _
    (* eval y *) _
    (* eval z *) _
    (* b0 /\ b1 /\ (if n1 =? n2 then b2 else b3) *) _
    )
  end.

Ltac2 doauto () :=
  match! goal with
  | [ |- ?g ] =>
    refine (compile g Lnil); intros
  end.

Lemma arith_example : forall n,
  exists prog,
    Env.empty |-- (prog, empty_state) --->
    ([encode (letd x := 1 in x + n)], empty_state).
Proof.
  intros; eexists.
  doauto ().

  (* repeat (doauto ()). *)



  eapply auto_let; intros.
  all: try (eapply auto_num_add); intros.
  all: try (eapply auto_num_const); intros.
  (* all: repeat (autostep; intros). *)
  all: try eapply trans_Var; try eapply Env.lookup_insert_eq.
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
