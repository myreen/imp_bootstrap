From impboot Require Import utils.Core utils.Env.
Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.functional.FunValues.
Require Import impboot.utils.Llist.

(* What do I induct on here? induction e just gives me IH for singleton lists *)
(* Lemma Eval_deterministic_single : forall e s env a1 a2,
  env |-- ([e], s) ---> a1 ->
  env |-- ([e], s) ---> a2 ->
  a1 = a2.
Proof.
  intros e s env a1 a2 H1 H2.
  induction e; try reflexivity; destruct a1, a2; simpl in *; subst.
  all: inversion H1; inversion H2; subst; eauto; try congruence.
  - unfold eval_op in *.
Admitted. *)

(*
TODO(kπ):
- for proofs use pa explicit tuples, instread of one variable that is a tuple
*)

Lemma Eval_deterministic : forall e s env a1v a1s,
  env |-- (e, s) ---> (a1v, a1s) ->
  forall a2v a2s,
    env |-- (e, s) ---> (a2v, a2s) ->
    (a1v, a1s) = (a2v, a2s).
Proof.
  induction 1; inversion 1; simpl in *; subst; try congruence.
  - apply IHeval1 in EVAL_HEAD; inversion EVAL_HEAD; subst.
    apply IHeval2 in EVAL_TAIL; inversion EVAL_TAIL; subst.
    reflexivity.
  - apply IHeval in EVAL_ARGS. congruence.
  - apply IHeval1 in EVAL_RHS; inversion EVAL_RHS; subst.
    apply IHeval2 in EVAL_RES; inversion EVAL_RES; subst.
    reflexivity.
  - apply IHeval1 in EVAL_COND; inversion EVAL_COND; subst.
    remember (take_branch test vs0 s4) as b1.
    destruct b1; destruct r; inversion TAKE_BRANCH; inversion TAKE_BRANCH0; subst.
    apply IHeval2 in EVAL_RES; inversion EVAL_RES; subst.
    reflexivity.
  - apply IHeval1 in EVAL_ARGS; inversion EVAL_ARGS; subst.
    remember (env_and_body fname vs0 s4) as b1.
    destruct b1; try destruct p; inversion ENV_BODY; inversion ENV_BODY0; subst.
    apply IHeval2 in EVAL_BODY; inversion EVAL_BODY; subst.
    reflexivity.
Qed.

Ltac cleanup :=
  repeat match goal with
  | [ H : context[fst ?x] |- _ ] => destruct x; simpl in *
  | [ |- exists _, _ ] => eexists
  | [ |- _ /\ _ ] => split
  | [ H : _ /\ _ |- _ ] => destruct H
  | [ H : exists _, _ |- _ ] => destruct H
  | _ => intros
  | _ => progress subst
  | _ => progress eauto
  | _ => progress simpl in *
  | _ => constructor
  | _ => congruence
  end.

Lemma Call_eq: forall fname xs s1 env a1v a1s,
  env |-- ([Call fname xs], s1) ---> (a1v, a1s) <->
  exists vs s2 v s3,
    env |-- (xs, s1) ---> (vs, s2) /\
    eval_app fname vs s2 (v, s3) /\ (a1v, a1s) = ([v],s3).
Proof.
  repeat split; intros; try inversion H; subst; try constructor.
  all: repeat match goal with
  | [ H : context[fst ?x] |- _ ] => destruct x; simpl in *
  | [ |- exists _, _ ] => eexists
  | [ |- _ /\ _ ] => split
  | [ H : _ /\ _ |- _ ] => destruct H
  | [ H : exists _, _ |- _ ] => destruct H
  | _ => progress subst
  | _ => progress eauto
  | _ => progress simpl in *
  | _ => constructor
  | _ => congruence
  end.
  - eapply App_intro; eauto.
  - inversion H2; inversion H3; inversion H1; subst.
    eapply Eval_Call; eauto.
Qed.

Theorem Eval_eq :
  (forall s env a1vs a1s, env |-- ([], s) ---> (a1vs, a1s) <-> (a1vs, a1s) = ([], s)) /\
  (forall y xs x s1 env a1vs a1s,
     env |-- (x :: y :: xs, s1) ---> (a1vs, a1s) <->
     exists v vs s2 s3,
       (a1vs, a1s) = (v::vs, s3) /\
       (env |-- ([x], s1) ---> ([v], s2)) /\
       (env |-- (y :: xs, s2) ---> (vs, s3))) /\
  (forall v s env a1vs a1s, env |-- ([Const v], s) ---> (a1vs, a1s) <-> (a1vs, a1s) = ([Num v], s)) /\
  (forall s n env a1vs a1s,
     env |-- ([Var n], s) ---> (a1vs, a1s) <->
     exists v, (a1vs, a1s) = ([v], s) /\ FEnv.lookup env n = Some v) /\
  (forall xs s1 f env a1vs a1s,
     env |-- ([Op f xs], s1) ---> (a1vs, a1s) <->
     exists vs s2 s3 v,
       (a1vs, a1s) = ([v], s3) /\
       env |-- (xs, s1) ---> (vs, s2) /\
       eval_op f vs s2 = (Res v, s3)) /\
  (forall y x s1 n env a1vs a1s,
     env |-- ([Let n x y], s1) ---> (a1vs, a1s) <->
     exists v1 s2 s3 v2,
       (a1vs, a1s) = ([v2], s3) /\
       env |-- ([x], s1) ---> ([v1], s2) /\
       (FEnv.insert (n, Some v1) env) |-- ([y], s2) ---> ([v2], s3)) /\
  (forall z y xs test s1 env a1vs a1s,
     env |-- ([If test xs y z], s1) ---> (a1vs, a1s) <->
     exists vs s2 b v s3,
       (a1vs, a1s) = ([v], s3) /\
       env |-- (xs, s1) ---> (vs, s2) /\
       take_branch test vs s2 = (Res b, s2) /\
       env |-- ([if b then y else z], s2) ---> ([v], s3)) /\
  (forall xs s1 fname env a1vs a1s,
     env |-- ([Call fname xs], s1) ---> (a1vs, a1s) <->
     exists vs s2 v s3,
       env |-- (xs, s1) ---> (vs, s2) /\
       eval_app fname vs s2 (v, s3) /\
       (a1vs, a1s) = ([v], s3)).
Proof.
  repeat split; intros; try inversion H; subst; try constructor.
  all: repeat match goal with
  | [ H : context[fst ?x] |- _ ] => destruct x; simpl in *
  | [ |- exists _, _ ] => eexists
  | [ |- _ /\ _ ] => split
  | [ H : _ /\ _ |- _ ] => destruct H
  | [ H : exists _, _ |- _ ] => destruct H
  | [ H : (_, _) = _ |- _ ] => inversion H; subst
  | _ => progress subst
  | _ => progress eauto
  | _ => progress simpl in *
  | _ => constructor
  | _ => congruence
  end.
  - eapply Eval_Cons; eauto.
  - rewrite H1 in H2; inversion H2; subst.
    eapply Eval_Var; eauto.
  - eapply Eval_Op; inversion H0; eauto.
  - eapply Eval_Let; inversion H0; eauto.
  - eapply Eval_If; inversion H0; eauto.
  - eapply App_intro; eauto.
  - inversion H2; subst.
    eapply (Call_eq fname xs s1 env [x1] x2).
    eexists x, x0, x1, x2; eauto.
Qed.

Lemma Eval_eq_Nil : forall s env a1v a1s, env |-- ([], s) ---> (a1v, a1s) <-> (a1v, a1s) = ([], s).
Proof.
  destruct Eval_eq; eauto.
Qed.

Lemma Eval_eq_Cons : forall y xs x s1 env a1v a1s,
  env |-- (x :: y :: xs, s1) ---> (a1v, a1s) <->
  exists v vs s2 s3,
    (a1v, a1s) = (v::vs, s3) /\
    (env |-- ([x], s1) ---> ([v], s2)) /\
    (env |-- (y :: xs, s2) ---> (vs, s3)).
Proof.
  destruct Eval_eq; cleanup.
  eapply H0; eauto.
Qed.

Lemma Eval_eq_Const : forall v s env a1v a1s,
  env |-- ([Const v], s) ---> (a1v, a1s) <-> (a1v, a1s) = ([Num v], s).
Proof.
  destruct Eval_eq; cleanup.
  eapply H1; eauto.
Qed.

Lemma Eval_eq_Var : forall s n env a1v a1s,
  env |-- ([Var n], s) ---> (a1v, a1s) <->
  exists v, (a1v, a1s) = ([v], s) /\ FEnv.lookup env n = Some v.
Proof.
  destruct Eval_eq; cleanup.
  eapply H2; eauto.
Qed.

Lemma Eval_eq_Op : forall xs s1 f env a1v a1s,
  env |-- ([Op f xs], s1) ---> (a1v, a1s) <->
  exists vs s2 s3 v,
    (a1v, a1s) = ([v], s3) /\
    env |-- (xs, s1) ---> (vs, s2) /\
    eval_op f vs s2 = (Res v, s3).
Proof.
  destruct Eval_eq; cleanup.
  eapply H3; eauto.
Qed.

Lemma Eval_eq_Let : forall y x s1 n env a1v a1s,
  env |-- ([Let n x y], s1) ---> (a1v, a1s) <->
  exists v1 s2 s3 v2,
    (a1v, a1s) = ([v2], s3) /\
    env |-- ([x], s1) ---> ([v1], s2) /\
    (FEnv.insert (n, Some v1) env) |-- ([y], s2) ---> ([v2], s3).
Proof.
  destruct Eval_eq; cleanup.
  eapply H4; eauto.
Qed.

Lemma Eval_eq_If : forall z y xs test s1 env a1v a1s,
  env |-- ([If test xs y z], s1) ---> (a1v, a1s) <->
  exists vs s2 b v s3,
    (a1v, a1s) = ([v], s3) /\
    env |-- (xs, s1) ---> (vs, s2) /\
    take_branch test vs s2 = (Res b, s2) /\
    env |-- ([if b then y else z], s2) ---> ([v], s3).
Proof.
  destruct Eval_eq; cleanup.
  eapply H5; eauto.
Qed.

Lemma Eval_eq_Call : forall xs s1 fname env a1v a1s,
  env |-- ([Call fname xs], s1) ---> (a1v, a1s) <->
  exists vs s2 v s3,
    env |-- (xs, s1) ---> (vs, s2) /\
    eval_app fname vs s2 (v, s3) /\
    (a1v, a1s) = ([v], s3).
Proof.
  destruct Eval_eq; cleanup.
  eapply H6; eauto.
Qed.

Fixpoint free_vars (e : exp) : list name :=
  match e with
  | Const _ => []
  | Var n => [n]
  | Op _ xs => flat_map free_vars xs
  | Let n x y => free_vars x ++ remove Nat.eq_dec n (free_vars y)
  | If _ xs y z => flat_map free_vars xs ++ free_vars y ++ free_vars z
  | Call _ xs => flat_map free_vars xs
  end.

Lemma not_In_app :
  forall {A : Type} (n : A) (xs ys : list A),
    ~ In n (xs ++ ys) <-> ~ In n xs /\ ~ In n ys.
Proof.
  intros.
  rewrite in_app_iff.
  tauto.
Qed.

Lemma in_remove_rw :
  forall {A : Type} {eq_dec : forall (x y : A), {x = y} + {x <> y}}
    (n : A) (n0 : A) (xs : list A),
  In n (remove eq_dec n0 xs) <-> In n xs /\ n <> n0.
Proof.
  intros; split.
  - apply in_remove.
  - intros; destruct H.
    apply in_in_remove; auto.
Qed.

Theorem delete_env_update :
  forall env xs s vs t n x,
    env |-- (xs, s) ---> (vs, t) ->
    ~ In n (flat_map free_vars xs) ->
    (FEnv.insert (n, x) env) |-- (xs, s) ---> (vs, t).
Proof.
  intros env xs s vs t n x H Hnotin.
  induction H; subst; simpl flat_map in *.
  - constructor; auto.
  - econstructor; eauto.
    + eapply IHeval1; eauto.
      rewrite app_nil_r.
      repeat rewrite not_In_app in Hnotin; destruct Hnotin; auto.
    + eapply IHeval2; eauto.
      rewrite not_In_app in Hnotin; destruct Hnotin; auto.
  - econstructor; eauto.
  - econstructor; eauto.
    unfold In in Hnotin; simpl in Hnotin.
    destruct (Nat.eq_dec n n0); subst; [tauto|].
    rewrite FEnv.lookup_insert_neq; eauto.
  - econstructor; eauto.
    eapply IHeval; eauto.
    rewrite app_nil_r in Hnotin; assumption.
  - rewrite app_nil_r in *.
    rewrite not_In_app in *; destruct Hnotin.
    econstructor; eauto.
    rewrite in_remove_rw in H2.
    destruct (Nat.eq_dec n n0); subst.
    + rewrite FEnv.insert_insert_eq in *.
      assumption.
    + assert (~ In n (free_vars exp2)) by tauto.
      specialize IHeval2 with (1 := H3).
      rewrite FEnv.insert_insert_neq; auto.
  - rewrite app_nil_r in *.
    repeat rewrite not_In_app in *; destruct Hnotin; destruct H2.
    econstructor; eauto.
    eapply IHeval2; eauto.
    destruct b; eauto.
  - rewrite app_nil_r in *.
    econstructor; eauto.
Qed.

Theorem remove_env_update :
  forall n x0 env v res s s1,
  ~ In n (free_vars x0) ->
  (FEnv.insert (n, v) env) |-- ([x0], s) ---> (res, s1) <-> env |-- ([x0], s) ---> (res, s1).
Proof.
  intros n x0 env v res s s1 Hnotin.
  split; intros H.
  - eapply delete_env_update with (n := n) (x := FEnv.lookup env n) in H; eauto.
    2: unfold flat_map in *; rewrite app_nil_r; assumption.
    rewrite FEnv.insert_insert_eq in H.
    assert (FEnv.insert (n, FEnv.lookup env n) env = env).
    2: rewrite <- H0; assumption.
    apply FEnv.insert_lookup_self.
  - eapply delete_env_update; eauto.
    unfold flat_map.
    rewrite app_nil_r.
    assumption.
Qed.
