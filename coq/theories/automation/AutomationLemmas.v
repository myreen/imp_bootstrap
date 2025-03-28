Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.functional.FunProperties.
Require Import impboot.functional.FunValues.
Require Import Coq.Lists.List.
Import ListNotations.
Require Import Lia Nat Arith.

Create HintDb automation.

Theorem trans_app: forall n params vs b body s s1 v,
  let env := make_env params vs Env.empty in
    (b -> (env |- ([body], s) ---> ([v], s1))) ->
    List.length params = List.length vs ->
    lookup_fun (value_name n) s.(funs) = Some (params,body) ->
    b -> eval_app (value_name n) vs s (v,s1).
Proof.
  intros; eapply App_intro; eauto.
  unfold env_and_body; simpl.
  rewrite H1.
  rewrite <- Nat.eqb_eq in H0; rewrite H0.
  reflexivity.
Qed.

Theorem trans_Call : forall b1 b2 env xs s1 s2 s3 fname vs v,
  (b1 -> env |- (xs, s1) ---> (vs, s2)) ->
  (b2 -> eval_app fname vs s2 (v, s3)) ->
  (b1 /\ b2 -> env |- ([Call fname xs], s1) ---> ([v], s3)).
Proof.
  intros b1 b2 env xs s1 s2 s3 fname vs v H1 H2 [Hb1 Hb2].
  apply H1 in Hb1; apply H2 in Hb2.
  inversion Hb2; subst.
  eapply Eval_Call with (vs := vs) (s2 := s2); eauto.
Qed.

Theorem trans_Var : forall n v env s,
  Env.lookup env (value_name n) = Some v ->
  env |- ([Var (value_name n)], s) ---> ([v], s).
Proof.
  intros n v env s H.
  apply Eval_Var; auto.
Qed.

Theorem trans_nil : forall env s,
  env |- ([], s) ---> ([], s).
Proof.
  intros env s.
  apply Eval_Nil.
Qed.

Theorem trans_cons : forall x xs v vs env s s1 s2,
  env |- ([x], s) ---> ([v], s1) ->
  env |- (xs, s1) ---> (vs, s2) ->
  env |- (x :: xs, s) ---> (v :: vs, s2).
Proof.
  intros x xs v vs env s s1 s2 H1 H2.
  destruct xs; simpl in *.
  - inversion H2; subst.
    assumption.
  - inversion H2; subst; econstructor; eauto.
Qed.

Theorem auto_let : forall {A : Type} {B : Type}
    b1 b2 (a : A -> Value) (b : B -> Value) env x1 y1 s1 s2 s3 v1 let_n f,
  (b1 -> env |- ([x1], s1) ---> ([a v1], s2)) ->
  (forall v1, b2 v1 -> (Env.insert ((value_name let_n), a v1) env) |- ([y1], s2) ---> ([b (f v1)], s3)) ->
  (b1 /\ b2 v1 ->
    env |- ([Let (value_name let_n) x1 y1], s1) ---> ([b (f v1)], s3)).
Proof.
  intros.
  destruct H1.
  eapply Eval_Let; eauto.
Qed.

Theorem auto_otherwise : forall {A : Type}
    b1 (a : A -> Value) env s x1 v1,
  (b1 -> env |- ([x1], s) ---> ([a v1], s)) ->
  (b1 ->
    env |- ([If Less [Const 0; Const 1] x1 (Const 0)], s) ---> ([a (value_otherwise v1)], s)).
Proof.
  intros.
  apply H in X.
  repeat econstructor; eauto.
Qed.

(* bool *)

Theorem auto_bool_F : forall env s,
  env |- ([Const 0], s) ---> ([value_bool false], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_bool_F : automation.

Theorem auto_bool_T : forall env s,
  env |- ([Const 1], s) ---> ([value_bool true], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_bool_T : automation.

Ltac Eval_eq :=
  repeat match goal with
  | _ => progress simpl in *
  | _ => lia
  | _ => congruence
  | _ => econstructor
  | _ => eauto
  end.

Theorem auto_bool_not : forall env s x1 b,
  env |- ([x1], s) ---> ([value_bool b], s) ->
  env |- ([Op Sub [Const 1; x1]], s) ---> ([value_bool (negb b)], s).
Proof.
  intros env s x1 b H.
  Eval_eq.
  destruct b; simpl; eauto with automation.
Qed.
Hint Resolve auto_bool_not : automation.

Theorem auto_bool_and : forall env s x1 x2 bA bB,
  env |- ([x1], s) ---> ([value_bool bA], s) ->
  env |- ([x2], s) ---> ([value_bool bB], s) ->
  env |- ([Op Sub [Op FunSyntax.Add [x1; x2]; Const 1]], s) ---> ([value_bool (andb bA bB)], s).
Proof.
  intros env s x1 x2 bA bB H1 H2.
  destruct (value_bool bA) eqn:HbA; destruct (value_bool bB) eqn:HbB; simpl in *.
  all: unfold value_bool in *; simpl in *; destruct bA; destruct bB; inversion HbA; inversion HbB; subst.
  all: Eval_eq.
Qed.
Hint Resolve auto_bool_and : automation.

Theorem auto_bool_iff : forall env s x1 x2 bA bB,
  env |- ([x1], s) ---> ([value_bool bA], s) ->
  env |- ([x2], s) ---> ([value_bool bB], s) ->
  env |- ([If Equal [x1; x2] (Const 1) (Const 0)], s) ---> ([value_bool (Bool.eqb bA bB)], s).
Proof.
  intros env s x1 x2 bA bB H1 H2.
  destruct (value_bool bA) eqn:HbA; destruct (value_bool bB) eqn:HbB; simpl in *.
  all: unfold value_bool in *; simpl in *; destruct bA; destruct bB; inversion HbA; inversion HbB; subst.
  all: Eval_eq.
Qed.
Hint Resolve auto_bool_iff : automation.

Theorem last_bool_if : forall env s x_g x_t x_f b t f,
  env |- ([x_g], s) ---> ([value_bool b], s) ->
  env |- ([x_t], s) ---> ([t], s) ->
  env |- ([x_f], s) ---> ([f], s) ->
  env |- ([If Equal [x_g; Const 1] x_t x_f], s) ---> ([if b then t else f], s).
Proof.
  intros env s x_g x_t x_f b t f H1 H2 H3.
  destruct (value_bool b) eqn:Hb; simpl in *.
  all: unfold value_bool in *; simpl in *; destruct b; inversion Hb; subst.
  all: Eval_eq.
Qed.
Hint Resolve last_bool_if : automation.

(* num *)

Theorem auto_num_const_zero : forall env s,
  env |- ([Const 0], s) ---> ([Num 0], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_num_const_zero : automation.

Theorem auto_num_const : forall env s n,
  env |- ([Const n], s) ---> ([Num n], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_num_const : automation.

Theorem auto_num_add : forall b0 b1 env s0 s1 s2 x1 x2 n1 n2,
  (b0 -> env |- ([x1], s0) ---> ([Num n1], s1)) ->
  (b1 -> env |- ([x2], s1) ---> ([Num n2], s2)) ->
  (b0 /\ b1 -> env |- ([Op FunSyntax.Add [x1; x2]], s0) ---> ([Num (n1 + n2)], s2)).
Proof.
  intros.
  destruct H1.
  repeat econstructor; eauto.
Qed.

Theorem auto_num_sub : forall b0 b1 env s0 s1 s2 x1 x2 n1 n2,
  (b0 -> env |- ([x1], s0) ---> ([Num n1], s1)) ->
  (b1 -> env |- ([x2], s1) ---> ([Num n2], s2)) ->
  (b0 /\ b1 -> env |- ([Op FunSyntax.Sub [x1; x2]], s0) ---> ([Num (n1 - n2)], s2)).
Proof.
  intros.
  destruct H1.
  repeat econstructor; eauto.
Qed.

Theorem auto_num_div : forall b0 b1 env s0 s1 s2 x1 x2 n1 n2,
  (b0 -> env |- ([x1], s0) ---> ([Num n1], s1)) ->
  (b1 -> env |- ([x2], s1) ---> ([Num n2], s2)) ->
  (b0 /\ b1 /\ n2 <> 0 -> env |- ([Op FunSyntax.Div [x1; x2]], s0) ---> ([Num (n1 / n2)], s2)).
Proof.
  intros.
  destruct H1; destruct H2.
  repeat econstructor; eauto.
  rewrite <- Nat.eqb_neq in *; simpl; rewrite H3; unfold return_; reflexivity.
Qed.

Theorem auto_num_if_eq : forall {A : Type}
    b0 b1 b2 b3 env s x1 x2 y z n1 n2 t f (a : A -> Value),
  (b0 -> env |- ([x1], s) ---> ([Num n1], s)) ->
  (b1 -> env |- ([x2], s) ---> ([Num n2], s)) ->
  (b2 -> env |- ([y], s) ---> ([a t], s)) ->
  (b3 -> env |- ([z], s) ---> ([a f], s)) ->
  b0 /\ b1 /\ (if n1 =? n2 then b2 else b3) ->
  env |- ([If Equal [x1; x2] y z], s) ---> ([a (if n1 =? n2 then t else f)], s).
Proof.
  intros.
  destruct H3 as [Hb0 [Hb1 HbCond]].
  apply H0 in Hb1.
  apply H in Hb0.
  destruct (n1 =? n2) eqn:Heq; [apply H1 in HbCond | apply H2 in HbCond].
  all: repeat econstructor; eauto.
  all: match goal with
  | [ |- take_branch _ _ _ = _ ] => unfold take_branch, return_; reflexivity
  | [ |- (_ |- (_, _) ---> (_, _)) ] => rewrite Heq; assumption
  end.
Qed.

Theorem auto_num_if_less : forall {A : Type}
    b0 b1 b2 b3 env s x1 x2 y z n1 n2 t f (a : A -> Value),
  (b0 -> env |- ([x1], s) ---> ([Num n1], s)) ->
  (b1 -> env |- ([x2], s) ---> ([Num n2], s)) ->
  (b2 -> env |- ([y], s) ---> ([a t], s)) ->
  (b3 -> env |- ([z], s) ---> ([a f], s)) ->
  b0 /\ b1 /\ (if n1 <? n2 then b2 else b3) ->
  env |- ([If Less [x1; x2] y z], s) ---> ([a (if n1 <? n2 then t else f)], s).
Proof.
  intros.
  destruct H3 as [Hb0 [Hb1 HbCond]].
  apply H0 in Hb1.
  apply H in Hb0.
  destruct (n1 <? n2) eqn:Heq; [apply H1 in HbCond | apply H2 in HbCond].
  all: repeat econstructor; eauto.
  all: match goal with
  | [ |- take_branch _ _ _ = _ ] => unfold take_branch, return_; reflexivity
  | [ |- (_ |- (_, _) ---> (_, _)) ] => rewrite Heq; assumption
  end.
Qed.

(* list *)


Theorem auto_list_nil : forall {A : Type} env s (a : A -> Value),
  env |- ([Const 0], s) ---> ([value_list a []], s).
Proof.
  intros; econstructor.
Qed.

Theorem auto_list_cons : forall {A : Type} b0 b1 env s x1 x2 (a : A -> Value) x xs,
  (b0 -> env |- ([x1], s) ---> ([a x], s)) ->
  (b1 -> env |- ([x2], s) ---> ([value_list a xs], s)) ->
  (b0 /\ b1 ->
    env |- ([Op Cons [x1; x2]], s) ---> ([value_list a (x :: xs)], s)).
Proof.
  intros; destruct H1.
  repeat econstructor; eauto.
Qed.

Definition list_CASE {A B : Type} (v0 : list A) (v1 : B) (v2 : A -> list A -> B) : B :=
  match v0 with
  | [] => v1
  | x :: xs => v2 x xs
  end.

(* Do we need this? We don't have list_CASE in Coq *)
(* Theorem auto_list_case : forall {A B : Type}
    b0 b1 b2 env s x0 x1 x2 n1 n2 v0 v1 v2 (a : A -> Value) (b : B -> Value),
  (b0 -> env |- ([x0], s) ---> ([value_list a v0], s)) ->
  (b1 -> env |- ([x1], s) ---> ([b v1], s)) ->
  (forall y1 y2,
      b2 y1 y2 ->
      (Env.insert (value_name n2, value_list a y2)
        (Env.insert (value_name n1, a y1) env)) |- ([x2], s) ---> ([b (v2 y1 y2)], s)) ->
  NoDup ([value_name n1] ++ free_vars x0) ->
  b0 /\ (v0 = [] -> b1) /\ (forall y1 y2, v0 = y1 :: y2 -> b2 y1 y2) ->
  env |- ([If Equal [x0; Const 0] x1
            (Let (value_name n1) (Op Head [x0])
              (Let (value_name n2) (Op Tail [x0]) x2))], s) ---> ([b (list_CASE v0 v1 v2)], s).
Proof.
  intros.
  destruct H3 as [Hb0 [Hb1 Hb2]].
  apply H in Hb0.
  destruct v0 as [|y1 y2].
  - apply H0 in Hb1.
    Eval_eq.
  - apply H1 in Hb2; eauto.
    Eval_eq.
Qed. *)

(* option *)

Theorem auto_option_none : forall {A : Type} env s (a : A -> Value),
  env |- ([Const 0], s) ---> ([value_option a None], s).
Proof.
  intros; econstructor.
Qed.

Theorem auto_option_some : forall {A : Type} b0 env s x1 (a : A -> Value) x,
  (b0 -> env |- ([x1], s) ---> ([a x], s)) ->
  (b0 ->
    env |- ([Op Cons [x1; Const 0]], s) ---> ([value_option a (Some x)], s)).
Proof.
  intros. apply H in X.
  repeat econstructor; eauto.
Qed.

(* Do we need option_CASE? *)

(* pair *)

Theorem auto_pair_fst : forall {A B : Type} b0 env s x1 (a : A -> Value) (b : B -> Value) x,
  (b0 -> env |- ([x1], s) ---> ([value_pair a b x], s)) ->
  (b0 -> env |- ([Op Head [x1]], s) ---> ([a (fst x)], s)).
Proof.
  intros. apply H in X.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.

Theorem auto_pair_snd : forall {A B : Type} b0 env s x1 (a : A -> Value) (b : B -> Value) x,
  (b0 -> env |- ([x1], s) ---> ([value_pair a b x], s)) ->
  (b0 -> env |- ([Op Tail [x1]], s) ---> ([b (snd x)], s)).
Proof.
  intros.
  apply H in X.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.

Theorem auto_pair_cons : forall {A B : Type} b0 b1 env s x1 x2 (a : A -> Value) (b : B -> Value) x y,
  (b0 -> env |- ([x1], s) ---> ([a x], s)) ->
  (b1 -> env |- ([x2], s) ---> ([b y], s)) ->
  (b0 /\ b1 ->
    env |- ([Op Cons [x1; x2]], s) ---> ([value_pair a b (x, y)], s)).
Proof.
  intros.
  destruct H1.
  repeat econstructor; eauto.
Qed.

(* Do we need pair_CASE? *)



(* TODO(kπ) continue *)

