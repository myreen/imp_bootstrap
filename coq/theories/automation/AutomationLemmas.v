Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.functional.FunProperties.
Require Import impboot.functional.FunValues.
From impboot Require Import utils.Core.

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

(* TODO(kπ) letd? *)
Theorem auto_let : forall {A B} `{ra : Refinable A} `{rb : Refinable B}
    b1 b2 env x1 y1 s1 s2 s3 v1 let_n f,
  (b1 -> env |- ([x1], s1) ---> ([ra.(refine) v1], s2)) ->
  (forall v1, b2 v1 -> (Env.insert ((value_name let_n), Some (ra.(refine) v1)) env) |- ([y1], s2) ---> ([rb.(refine) (f v1)], s3)) ->
  (b1 /\ b2 v1 ->
    env |- ([Let (value_name let_n) x1 y1], s1) ---> ([rb.(refine) (f v1)], s3)).
Proof.
  intros.
  destruct H1.
  eapply Eval_Let; eauto.
Qed.

Theorem auto_otherwise : forall {A} `{ra : Refinable A}
    b1 env s x1 v1,
  (b1 -> env |- ([x1], s) ---> ([refine v1], s)) ->
  (b1 ->
    env |- ([If Less [Const 0; Const 1] x1 (Const 0)], s) ---> ([refine (value_otherwise v1)], s)).
Proof.
  intros.
  apply H in X.
  repeat econstructor; eauto.
Qed.

(* bool *)

Theorem auto_bool_F : forall env s,
  env |- ([Const 0], s) ---> ([refine false], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_bool_F : automation.

Theorem auto_bool_T : forall env s,
  env |- ([Const 1], s) ---> ([refine true], s).
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
  env |- ([x1], s) ---> ([refine b], s) ->
  env |- ([Op Sub [Const 1; x1]], s) ---> ([refine (negb b)], s).
Proof.
  intros env s x1 b H.
  Eval_eq.
  destruct b; simpl; eauto with automation.
Qed.
Hint Resolve auto_bool_not : automation.

Theorem auto_bool_and : forall env s x1 x2 bA bB,
  env |- ([x1], s) ---> ([refine bA], s) ->
  env |- ([x2], s) ---> ([refine bB], s) ->
  env |- ([Op Sub [Op FunSyntax.Add [x1; x2]; Const 1]], s) ---> ([refine (andb bA bB)], s).
Proof.
  intros env s x1 x2 bA bB H1 H2.
  destruct (refine bA) eqn:HbA; destruct (refine bB) eqn:HbB; simpl in *.
  all: unfold refine in *; simpl in *; destruct bA; destruct bB; inversion HbA; inversion HbB; subst.
  all: Eval_eq.
Qed.
Hint Resolve auto_bool_and : automation.

Theorem auto_bool_iff : forall env s x1 x2 bA bB,
  env |- ([x1], s) ---> ([refine bA], s) ->
  env |- ([x2], s) ---> ([refine bB], s) ->
  env |- ([If Equal [x1; x2] (Const 1) (Const 0)], s) ---> ([refine (Bool.eqb bA bB)], s).
Proof.
  intros env s x1 x2 bA bB H1 H2.
  destruct (refine bA) eqn:HbA; destruct (refine bB) eqn:HbB; simpl in *.
  all: unfold refine in *; simpl in *; destruct bA; destruct bB; inversion HbA; inversion HbB; subst.
  all: Eval_eq.
Qed.
Hint Resolve auto_bool_iff : automation.

Theorem last_bool_if : forall env s x_g x_t x_f (b : bool) t f,
  env |- ([x_g], s) ---> ([refine b], s) ->
  env |- ([x_t], s) ---> ([t], s) ->
  env |- ([x_f], s) ---> ([f], s) ->
  env |- ([If Equal [x_g; Const 1] x_t x_f], s) ---> ([if b then t else f], s).
Proof.
  intros env s x_g x_t x_f b t f H1 H2 H3.
  destruct (refine b) eqn:Hb; simpl in *.
  all: unfold refine in *; simpl in *; destruct b; inversion Hb; subst.
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

Theorem auto_num_if_eq : forall {A}
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

Theorem auto_num_if_less : forall {A}
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

Theorem auto_list_nil : forall env s,
  env |- ([Const 0], s) ---> ([refine []], s).
Proof.
  intros; econstructor.
Qed.

Theorem auto_list_cons : forall {A} `{Refinable A} b0 b1 env s x1 x2 x xs,
  (b0 -> env |- ([x1], s) ---> ([refine x], s)) ->
  (b1 -> env |- ([x2], s) ---> ([refine xs], s)) ->
  (b0 /\ b1 ->
    env |- ([Op Cons [x1; x2]], s) ---> ([refine (x :: xs)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 /\ ?b1 |- _ =>
    destruct H
  end.
  repeat econstructor; eauto.
Qed.

(* TODO(kπ) check this. *)
Theorem auto_list_case : forall {A B} `{ra : Refinable A} `{rb : Refinable B}
    b0 b1 b2 env s x0 x1 x2 n1 n2 (v0 : list A) v1 v2,
  (b0 -> env |- ([x0], s) ---> ([refine v0], s)) ->
  (b1 -> env |- ([x1], s) ---> ([rb.(refine) v1], s)) ->
  (forall y1 y2,
      b2 y1 y2 ->
      (Env.insert (value_name n2, Some (refine y2))
        (Env.insert (value_name n1, Some (ra.(refine) y1)) env)) |- ([x2], s) ---> ([rb.(refine) (v2 y1 y2)], s)) ->
  NoDup ([value_name n1] ++ free_vars x0) ->
  b0 /\ (v0 = [] -> b1) /\ (forall y1 y2, v0 = y1 :: y2 -> b2 y1 y2) ->
  env |- ([If Equal [x0; Const 0] x1
            (Let (value_name n1) (Op Head [x0])
              (Let (value_name n2) (Op Tail [x0]) x2))], s) --->
         ([rb.(refine) (list_CASE v0 v1 v2)], s).
Proof.
  intros.
  destruct H3 as [Hb0 [Hb1 Hb2]].
  destruct v0 as [|y1 y2].
  - apply H0 in Hb1; try reflexivity.
    Eval_eq.
  - eapply H1 in Hb2; eauto.
    simpl in *.
    rewrite NoDup_cons_iff in *; destruct H2.
    Eval_eq.
    + rewrite remove_env_update; eauto.
    + simpl; unfold return_; reflexivity.
Qed.

(* option *)

Theorem auto_option_none : forall {A} `{Refinable A} env s,
  env |- ([Const 0], s) ---> ([refine None], s).
Proof.
  intros; econstructor.
Qed.

Theorem auto_option_some : forall {A} `{Refinable A} b0 env s x1 x,
  (b0 -> env |- ([x1], s) ---> ([refine x], s)) ->
  (b0 ->
    env |- ([Op Cons [x1; Const 0]], s) ---> ([refine (Some x)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 -> _ , X : ?b0 |- _ =>
    apply H in X
  end.
  repeat econstructor; eauto.
Qed.

Theorem auto_option_case : forall {A B} `{Refinable A} `{rb : Refinable B} (v0 : option A) b0 b1 b2 env s x0 x1 x2 n v1 v2,
  (b0 -> env |- ([x0],s) ---> ([refine v0],s)) ->
  (b1 -> env |- ([x1],s) ---> ([rb.(refine) v1],s)) ->
  (forall y1, b2 y1 ->
    (Env.insert (value_name n, Some (refine y1)) env) |- ([x2],s) ---> ([rb.(refine) (v2 y1)],s)) ->
  b0 /\ (v0 = None -> b1) /\ (forall y1, v0 = Some y1 -> b2 y1) ->
  env |- ([If Equal [x0; Const 0] x1
            (Let (value_name n) (Op Head [x0]) x2)], s) --->
         ([rb.(refine) (option_CASE v0 v1 v2)], s).
Proof.
  intros.
  destruct H3 as [Hb0 [Hb1 Hb2]].
  destruct v0 as [y1|]; simpl in *.
  - specialize (Hb2 y1).
    apply H2 in Hb2; try reflexivity.
    Eval_eq.
  - apply H1 in Hb1; try reflexivity.
    Eval_eq.
Qed.

(* pair *)

Theorem auto_pair_fst : forall {A B} `{Refinable A} `{Refinable B} b0 env s x1 (x : A * B),
  (b0 -> env |- ([x1], s) ---> ([refine x], s)) ->
  (b0 -> env |- ([Op Head [x1]], s) ---> ([refine (fst x)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 -> _ , X : ?b0 |- _ =>
    apply H in X
  end.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.

Theorem auto_pair_snd : forall {A B} `{Refinable A} `{Refinable B} b0 env s x1 (x : A * B),
  (b0 -> env |- ([x1], s) ---> ([refine x], s)) ->
  (b0 -> env |- ([Op Tail [x1]], s) ---> ([refine (snd x)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 -> _ , X : ?b0 |- _ =>
    apply H in X
  end.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.

Theorem auto_pair_cons : forall {A B} `{Refinable A} `{Refinable B} b0 b1 env s x1 x2 (x : A) (y : B),
  (b0 -> env |- ([x1], s) ---> ([refine x], s)) ->
  (b1 -> env |- ([x2], s) ---> ([refine y], s)) ->
  (b0 /\ b1 ->
    env |- ([Op Cons [x1; x2]], s) ---> ([refine (x, y)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 /\ ?b1 |- _ =>
    destruct H
  end.
  repeat econstructor; eauto.
Qed.

Theorem auto_pair_case : forall {A1 A2 B} `{ra1 : Refinable A1} `{ra2 : Refinable A2} `{rb : Refinable B}
    b0 b1 env s x0 x1 n1 n2 (v0 : A1 * A2) v1,
  (b0 -> env |- ([x0], s) ---> ([refine v0], s)) ->
  (forall y1 y2,
      b1 y1 y2 ->
      (Env.insert (value_name n2, Some (ra2.(refine) y2))
        (Env.insert (value_name n1, Some (ra1.(refine) y1)) env)) |- ([x1], s) --->
      ([rb.(refine) (v1 y1 y2)], s)) ->
  NoDup ([value_name n1] ++ [value_name n2] ++ free_vars x0) ->
  b0 /\ (forall y1 y2, v0 = (y1, y2) -> b1 y1 y2) ->
  env |- ([Let (value_name n1) (Op Head [x0])
            (Let (value_name n2) (Op Tail [x0]) x1)], s) --->
  ([rb.(refine) (pair_CASE v0 v1)], s).
Proof.
  intros.
  destruct H2 as [Hb0 Hb1].
  destruct v0 as [y1 y2]; simpl in *.
  specialize (Hb1 y1 y2).
  apply H0 in Hb1; try reflexivity.
  Eval_eq.
  - eapply H in Hb0; try reflexivity.
    repeat rewrite NoDup_cons_iff in *; destruct H1; destruct H2.
    rewrite not_in_cons in *; destruct H1.
    rewrite remove_env_update; eauto.
  - simpl; unfold return_; reflexivity.
Qed.

(* TODO(kπ) continue *)

