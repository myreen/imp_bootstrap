Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.functional.FunProperties.
Require Import impboot.functional.FunValues.
Require impboot.imperative.ImpSyntax.
From impboot Require Import utils.Core.
From coqutil Require Import dlet.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.
Require Import impboot.utils.AppList.

Create HintDb automation.

Theorem trans_app: forall n params vs b body s s1 v,
  let env := make_env params vs Env.empty in
    (b -> (env |-- ([body], s) ---> ([v], s1))) ->
    List.length params = List.length vs ->
    lookup_fun (name_enc n) s.(funs) = Some (params,body) ->
    b -> eval_app (name_enc n) vs s (v,s1).
Proof.
  intros; eapply App_intro; eauto.
  unfold env_and_body; simpl.
  rewrite H1.
  rewrite <- Nat.eqb_eq in H0; rewrite H0.
  reflexivity.
Qed.

Theorem trans_Call : forall b1 b2 env xs s1 s2 s3 fname vs v,
  (b1 -> env |-- (xs, s1) ---> (vs, s2)) ->
  (b2 -> eval_app fname vs s2 (v, s3)) ->
  (b1 /\ b2 -> env |-- ([Call fname xs], s1) ---> ([v], s3)).
Proof.
  intros b1 b2 env xs s1 s2 s3 fname vs v H1 H2 [Hb1 Hb2].
  apply H1 in Hb1; apply H2 in Hb2.
  inversion Hb2; subst.
  eapply Eval_Call with (vs := vs) (s2 := s2); eauto.
Qed.

Theorem trans_Var : forall n v env s,
  Env.lookup env (name_enc n) = Some v ->
  env |-- ([Var (name_enc n)], s) ---> ([v], s).
Proof.
  intros n v env s H.
  apply Eval_Var; auto.
Qed.

Theorem trans_nil : forall env s,
  env |-- ([], s) ---> ([], s).
Proof.
  intros env s.
  apply Eval_Nil.
Qed.

Theorem trans_cons : forall x xs v vs env s s1 s2,
  env |-- ([x], s) ---> ([v], s1) ->
  env |-- (xs, s1) ---> (vs, s2) ->
  env |-- (x :: xs, s) ---> (v :: vs, s2).
Proof.
  intros x xs v vs env s s1 s2 H1 H2.
  destruct xs; simpl in *.
  - inversion H2; subst.
    assumption.
  - inversion H2; subst; econstructor; eauto.
Qed.

Ltac Eval_eq :=
  repeat match goal with
  | _ => progress simpl in *
  | _ => lia
  | _ => congruence
  | _ => econstructor
  | _ => eauto
  end.

Theorem auto_let : forall {A B} `{ra : Refinable A} `{rb : Refinable B}
    b1 b2 env x1 y1 s1 s2 s3 v1 let_n f,
  (b1 -> env |-- ([x1], s1) ---> ([ra.(encode) v1], s2)) ->
  (forall v1, b2 v1 -> (Env.insert ((name_enc let_n), Some (ra.(encode) v1)) env) |-- ([y1], s2) --->
                       ([rb.(encode) (f v1)], s3)) ->
  (b1 /\ b2 v1 ->
    env |-- ([Let (name_enc let_n) x1 y1], s1) ---> ([rb.(encode) (dlet v1 f)], s3)).
Proof.
  intros.
  destruct H1.
  eapply Eval_Let; eauto.
Qed.
Hint Resolve auto_let : automation.

Theorem auto_otherwise : forall {A} `{ra : Refinable A}
    b1 env s x1 v1,
  (b1 -> env |-- ([x1], s) ---> ([encode v1], s)) ->
  (b1 ->
    env |-- ([If Less [Const 0; Const 1] x1 (Const 0)], s) ---> ([encode (value_otherwise v1)], s)).
Proof.
  intros.
  apply H in X.
  repeat econstructor; eauto.
Qed.
(* Hint Resolve auto_otherwise : automation. *)

(* bool *)

Theorem auto_bool_F : forall env s,
  env |-- ([Const 0], s) ---> ([encode false], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_bool_F : automation.

Theorem auto_bool_T : forall env s,
  env |-- ([Const 1], s) ---> ([encode true], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_bool_T : automation.

Theorem auto_bool_not : forall env s x1 b,
  env |-- ([x1], s) ---> ([encode b], s) ->
  env |-- ([Op Sub [Const 1; x1]], s) ---> ([encode (negb b)], s).
Proof.
  intros env s x1 b H.
  Eval_eq.
  destruct b; simpl; eauto with automation.
Qed.
Hint Resolve auto_bool_not : automation.

Theorem auto_bool_and : forall env s x1 x2 bA bB,
  env |-- ([x1], s) ---> ([encode bA], s) ->
  env |-- ([x2], s) ---> ([encode bB], s) ->
  env |-- ([Op Sub [Op FunSyntax.Add [x1; x2]; Const 1]], s) ---> ([encode (andb bA bB)], s).
Proof.
  intros env s x1 x2 bA bB H1 H2.
  destruct (encode bA) eqn:HbA; destruct (encode bB) eqn:HbB; simpl in *.
  all: unfold encode in *; simpl in *; destruct bA; destruct bB; inversion HbA; inversion HbB; subst.
  all: Eval_eq.
Qed.
Hint Resolve auto_bool_and : automation.

Theorem auto_bool_iff : forall env s x1 x2 bA bB,
  env |-- ([x1], s) ---> ([encode bA], s) ->
  env |-- ([x2], s) ---> ([encode bB], s) ->
  env |-- ([If Equal [x1; x2] (Const 1) (Const 0)], s) ---> ([encode (Bool.eqb bA bB)], s).
Proof.
  intros env s x1 x2 bA bB H1 H2.
  destruct (encode bA) eqn:HbA; destruct (encode bB) eqn:HbB; simpl in *.
  all: unfold encode in *; simpl in *; destruct bA; destruct bB; inversion HbA; inversion HbB; subst.
  all: Eval_eq.
Qed.
Hint Resolve auto_bool_iff : automation.

Theorem last_bool_if : forall env s x_g x_t x_f (b : bool) t f,
  env |-- ([x_g], s) ---> ([encode b], s) ->
  env |-- ([x_t], s) ---> ([t], s) ->
  env |-- ([x_f], s) ---> ([f], s) ->
  env |-- ([If Equal [x_g; Const 1] x_t x_f], s) ---> ([if b then t else f], s).
Proof.
  intros env s x_g x_t x_f b t f H1 H2 H3.
  destruct (encode b) eqn:Hb; simpl in *.
  all: unfold encode in *; simpl in *; destruct b; inversion Hb; subst.
  all: Eval_eq.
Qed.
Hint Resolve last_bool_if : automation.

(* num *)

(* Theorem auto_num_const_zero : forall env s,
  env |-- ([Const 0], s) ---> ([Num 0], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_num_const_zero : automation. *)

Theorem auto_num_const : forall env s n,
  env |-- ([Const n], s) ---> ([Num n], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_num_const : automation.

Theorem auto_num_add : forall b0 b1 env s0 s1 s2 x1 x2 n1 n2,
  (b0 -> env |-- ([x1], s0) ---> ([encode n1], s1)) ->
  (b1 -> env |-- ([x2], s1) ---> ([encode n2], s2)) ->
  (b0 /\ b1 -> env |-- ([Op FunSyntax.Add [x1; x2]], s0) ---> ([encode (n1 + n2)], s2)).
Proof.
  intros.
  destruct H1.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_num_add : automation.

Theorem auto_num_sub : forall b0 b1 env s0 s1 s2 x1 x2 n1 n2,
  (b0 -> env |-- ([x1], s0) ---> ([encode n1], s1)) ->
  (b1 -> env |-- ([x2], s1) ---> ([encode n2], s2)) ->
  (b0 /\ b1 -> env |-- ([Op FunSyntax.Sub [x1; x2]], s0) ---> ([encode (n1 - n2)], s2)).
Proof.
  intros.
  destruct H1.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_num_sub : automation.

Theorem auto_num_div : forall b0 b1 env s0 s1 s2 x1 x2 n1 n2,
  (b0 -> env |-- ([x1], s0) ---> ([encode n1], s1)) ->
  (b1 -> env |-- ([x2], s1) ---> ([encode n2], s2)) ->
  (b0 /\ b1 /\ n2 <> 0 -> env |-- ([Op FunSyntax.Div [x1; x2]], s0) ---> ([encode (n1 / n2)], s2)).
Proof.
  intros.
  destruct H1; destruct H2.
  repeat econstructor; eauto.
  rewrite <- Nat.eqb_neq in *; simpl; rewrite H3; reflexivity.
Qed.
Hint Resolve auto_num_div : automation.

Theorem auto_num_if_eq : forall {A}
    b0 b1 b2 b3 env s x1 x2 y z n1 n2 t f (a : A -> Value),
  (b0 -> env |-- ([x1], s) ---> ([encode n1], s)) ->
  (b1 -> env |-- ([x2], s) ---> ([encode n2], s)) ->
  (b2 -> env |-- ([y], s) ---> ([a t], s)) ->
  (b3 -> env |-- ([z], s) ---> ([a f], s)) ->
  b0 /\ b1 /\ (if n1 =? n2 then b2 else b3) ->
  env |-- ([If Equal [x1; x2] y z], s) ---> ([a (if n1 =? n2 then t else f)], s).
Proof.
  intros.
  destruct H3 as [Hb0 [Hb1 HbCond]].
  apply H0 in Hb1.
  apply H in Hb0.
  destruct (n1 =? n2) eqn:Heq; [apply H1 in HbCond | apply H2 in HbCond].
  all: repeat econstructor; eauto.
  all: match goal with
  | [ |- take_branch _ _ _ = _ ] => unfold take_branch, return_; reflexivity
  | [ |- (_ |-- (_, _) ---> (_, _)) ] => rewrite Heq; assumption
  end.
Qed.
Hint Resolve auto_num_if_eq : automation.

Theorem auto_num_if_less : forall {A}
    b0 b1 b2 b3 env s x1 x2 y z n1 n2 t f (a : A -> Value),
  (b0 -> env |-- ([x1], s) ---> ([encode n1], s)) ->
  (b1 -> env |-- ([x2], s) ---> ([encode n2], s)) ->
  (b2 -> env |-- ([y], s) ---> ([a t], s)) ->
  (b3 -> env |-- ([z], s) ---> ([a f], s)) ->
  b0 /\ b1 /\ (if n1 <? n2 then b2 else b3) ->
  env |-- ([If Less [x1; x2] y z], s) ---> ([a (if n1 <? n2 then t else f)], s).
Proof.
  intros.
  destruct H3 as [Hb0 [Hb1 HbCond]].
  apply H0 in Hb1.
  apply H in Hb0.
  destruct (n1 <? n2) eqn:Heq; [apply H1 in HbCond | apply H2 in HbCond].
  all: repeat econstructor; eauto.
  all: match goal with
  | [ |- take_branch _ _ _ = _ ] => unfold take_branch, return_; reflexivity
  | [ |- (_ |-- (_, _) ---> (_, _)) ] => rewrite Heq; assumption
  end.
Qed.
Hint Resolve auto_num_if_less : automation.

(* list *)

Theorem auto_list_nil : forall env s,
  env |-- ([Const 0], s) ---> ([encode []], s).
Proof.
  intros; econstructor.
Qed.
Hint Resolve auto_list_nil : automation.

Theorem auto_list_cons : forall {A} `{Refinable A} b0 b1 env s x1 x2 x xs,
  (b0 -> env |-- ([x1], s) ---> ([encode x], s)) ->
  (b1 -> env |-- ([x2], s) ---> ([encode xs], s)) ->
  (b0 /\ b1 ->
    env |-- ([Op Cons [x1; x2]], s) ---> ([encode (x :: xs)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 /\ ?b1 |- _ =>
    destruct H
  end.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_list_cons : automation.

Theorem auto_list_case : forall {A B} `{ra : Refinable A} `{rb : Refinable B}
    b0 b1 b2 env s x0 x1 x2 n1 n2 (v0 : list A) v1 v2,
  (b0 -> env |-- ([x0], s) ---> ([encode v0], s)) ->
  (b1 -> env |-- ([x1], s) ---> ([rb.(encode) v1], s)) ->
  (forall y1 y2,
      b2 y1 y2 ->
      (Env.insert (name_enc n2, Some (encode y2))
        (Env.insert (name_enc n1, Some (ra.(encode) y1)) env)) |-- ([x2], s) --->
      ([rb.(encode) (v2 y1 y2)], s)) ->
  NoDup ([name_enc n1] ++ free_vars x0) ->
  b0 /\ (v0 = [] -> b1) /\ (forall y1 y2, v0 = y1 :: y2 -> b2 y1 y2) ->
  env |-- ([If Equal [x0; Const 0] x1
            (Let (name_enc n1) (Op Head [x0])
              (Let (name_enc n2) (Op Tail [x0]) x2))], s) --->
         ([rb.(encode) (list_CASE v0 v1 v2)], s).
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
    + simpl; reflexivity.
Qed.
Hint Resolve auto_list_case : automation.

(* option *)

Theorem auto_option_none : forall {A} `{Refinable A} env s,
  env |-- ([Const 0], s) ---> ([encode None], s).
Proof.
  intros; econstructor.
Qed.
Hint Resolve auto_option_none : automation.

Theorem auto_option_some : forall {A} `{Refinable A} b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([encode x], s)) ->
  (b0 ->
    env |-- ([Op Cons [x1; Const 0]], s) ---> ([encode (Some x)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 -> _ , X : ?b0 |- _ =>
    apply H in X
  end.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_option_some : automation.

Theorem auto_option_case : forall {A B} `{Refinable A} `{rb : Refinable B} (v0 : option A) b0 b1 b2 env s x0 x1 x2 n v1 v2,
  (b0 -> env |-- ([x0],s) ---> ([encode v0],s)) ->
  (b1 -> env |-- ([x1],s) ---> ([rb.(encode) v1],s)) ->
  (forall y1, b2 y1 ->
    (Env.insert (name_enc n, Some (encode y1)) env) |-- ([x2],s) ---> ([rb.(encode) (v2 y1)],s)) ->
  b0 /\ (v0 = None -> b1) /\ (forall y1, v0 = Some y1 -> b2 y1) ->
  env |-- ([If Equal [x0; Const 0] x1
            (Let (name_enc n) (Op Head [x0]) x2)], s) --->
         ([rb.(encode) (option_CASE v0 v1 v2)], s).
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
Hint Resolve auto_option_case : automation.

(* pair *)

Theorem auto_pair_fst : forall {A B} `{Refinable A} `{Refinable B} b0 env s x1 (x : A * B),
  (b0 -> env |-- ([x1], s) ---> ([encode x], s)) ->
  (b0 -> env |-- ([Op Head [x1]], s) ---> ([encode (fst x)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 -> _ , X : ?b0 |- _ =>
    apply H in X
  end.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_pair_fst : automation.

Theorem auto_pair_snd : forall {A B} `{Refinable A} `{Refinable B} b0 env s x1 (x : A * B),
  (b0 -> env |-- ([x1], s) ---> ([encode x], s)) ->
  (b0 -> env |-- ([Op Tail [x1]], s) ---> ([encode (snd x)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 -> _ , X : ?b0 |- _ =>
    apply H in X
  end.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_pair_fst : automation.

Theorem auto_pair_cons : forall {A B} `{Refinable A} `{Refinable B} b0 b1 env s x1 x2 (x : A) (y : B),
  (b0 -> env |-- ([x1], s) ---> ([encode x], s)) ->
  (b1 -> env |-- ([x2], s) ---> ([encode y], s)) ->
  (b0 /\ b1 ->
    env |-- ([Op Cons [x1; x2]], s) ---> ([encode (x, y)], s)).
Proof.
  intros.
  match goal with
  | H : ?b0 /\ ?b1 |- _ =>
    destruct H
  end.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_pair_cons : automation.

Theorem auto_pair_case : forall {A1 A2 B} `{ra1 : Refinable A1} `{ra2 : Refinable A2} `{rb : Refinable B}
    b0 b1 env s x0 x1 n1 n2 (v0 : A1 * A2) v1,
  (b0 -> env |-- ([x0], s) ---> ([encode v0], s)) ->
  (forall y1 y2,
      b1 y1 y2 ->
      (Env.insert (name_enc n2, Some (ra2.(encode) y2))
        (Env.insert (name_enc n1, Some (ra1.(encode) y1)) env)) |-- ([x1], s) --->
      ([rb.(encode) (v1 y1 y2)], s)) ->
  NoDup ([name_enc n1] ++ [name_enc n2] ++ free_vars x0) ->
  b0 /\ (forall y1 y2, v0 = (y1, y2) -> b1 y1 y2) ->
  env |-- ([Let (name_enc n1) (Op Head [x0])
            (Let (name_enc n2) (Op Tail [x0]) x1)], s) --->
  ([rb.(encode) (pair_CASE v0 v1)], s).
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
  - simpl; reflexivity.
Qed.
Hint Resolve auto_pair_case : automation.

(* Was only needed in th eoriginal implementation, because parsing goes through Values *)
(* Maybe we'll need it now *)
(*
(* deep *)

Fixpoint deep (v : Value) : Value :=
  match v with
  | Num n => value_cons (encode true) (encode n)
  | Pair x y => value_cons (encode false) (value_cons (deep x) (deep y))
  end.

Theorem auto_v_Num : forall b0 env s x1 n,
  (b0 -> env |-- ([x1], s) ---> ([Num n], s)) ->
  b0 ->
  env |-- ([Op Cons [Const 1; x1]], s) ---> ([deep (Num n)], s).
Proof.
  intros b0 env s x1 n H H0.
  apply H in H0.
  simpl.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_v_Num : automation.

Theorem auto_v_Pair : forall b0 b1 env s x1 x2 x y,
  (b0 -> env |-- ([x1], s) ---> ([deep x], s)) ->
  (b1 -> env |-- ([x2], s) ---> ([deep y], s)) ->
  b0 /\ b1 ->
  env |-- ([Op Cons [Const 0; Op Cons [x1; x2]]], s) ---> ([deep (Pair x y)], s).
Proof.
  intros b0 b1 env s x1 x2 x y H1 H2 [Hb0 Hb1].
  apply H1 in Hb0.
  apply H2 in Hb1.
  simpl.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_v_Pair : automation.

Theorem auto_v_isNum : forall b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([deep x], s)) ->
  b0 ->
  env |-- ([Op Head [x1]], s) ---> ([encode (value_isNum x)], s).
Proof.
  intros b0 env s x1 x H H0.
  apply H in H0.
  destruct x; simpl; repeat econstructor; eauto.
Qed.
Hint Resolve auto_v_isNum : automation.

Theorem auto_v_getNum : forall b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([deep x], s)) ->
  b0 ->
  env |-- ([If Equal [Op Head [x1]; Const 0] (Const 0) (Op Tail [x1])], s) --->
  ([Num (value_getNum x)], s).
Proof.
  intros b0 env s x1 x H H0.
  apply H in H0.
  destruct x; simpl; repeat econstructor; Eval_eq.
Qed.
Hint Resolve auto_v_getNum : automation.

Theorem auto_v_head : forall b0 env s x1 x,
  lookup_fun (name_enc_str "h"%string) s.(funs) =
    Some ([name_enc_str "x"%string],
          If Equal [Op Head [Var (name_enc_str "x"%string)]; Const 1]
            (Var (name_enc_str "x"%string)) (Op Head [Op Tail [Var (name_enc_str "x"%string)]])) ->
  (b0 -> env |-- ([x1], s) ---> ([deep x], s)) ->
  b0 ->
  env |-- ([Call (name_enc_str "h"%string) [x1]], s) ---> ([deep (value_head x)], s).
Proof.
  intros b0 env s x1 x Hlookup H H0.
  destruct x; simpl.
  all: eapply Eval_Call_thm.
  all: try match goal with
  | [ |- ?env |-- ([?x1], ?s) ---> (_, _) ] => eauto
  end.
  all: econstructor; unfold env_and_body; simpl in *.
  all: destruct (lookup_fun (name_enc_str "h") (funs s)) eqn:?; try destruct p.
  all: try inversion Hlookup; clear Hlookup; subst; simpl.
  all: f_equal; f_equal.
  all: Eval_eq.
  all: try rewrite Env.lookup_insert_eq; try reflexivity.
  all: simpl; unfold return_; try reflexivity.
  all: Eval_eq.
  all: try rewrite Env.lookup_insert_eq; try reflexivity.
Qed.
Hint Resolve auto_v_head : automation.

Theorem auto_v_tail : forall b0 env s x1 x,
  lookup_fun (name_enc_str "t") s.(funs) =
    Some ([name_enc_str "x"],
          If Equal [Op Head [Var (name_enc_str "x")]; Const 1]
            (Var (name_enc_str "x")) (Op Tail [Op Tail [Var (name_enc_str "x")]])) ->
  (b0 -> env |-- ([x1], s) ---> ([deep x], s)) ->
  b0 ->
  env |-- ([Call (name_enc_str "t") [x1]], s) ---> ([deep (value_tail x)], s).
Proof.
  intros b0 env s x1 x Hlookup H H0.
  destruct x; simpl.
  all: eapply Eval_Call_thm.
  all: try match goal with
  | [ |- ?env |-- ([?x1], ?s) ---> (_, _) ] => eauto
  end.
  all: econstructor; unfold env_and_body; simpl in *.
  all: destruct (lookup_fun (name_enc_str "t") (funs s)) eqn:?; try destruct p.
  all: try inversion Hlookup; clear Hlookup; subst; simpl.
  all: f_equal; f_equal.
  all: Eval_eq.
  all: try rewrite Env.lookup_insert_eq; try reflexivity.
  all: simpl; unfold return_; try reflexivity.
  all: Eval_eq.
  all: try rewrite Env.lookup_insert_eq; try reflexivity.
Qed.
Hint Resolve auto_v_tail : automation.
*)

(* char *)

Theorem auto_char_CHR : forall b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([Num x], s)) ->
  b0 /\ x < 256 ->
  env |-- ([x1], s) ---> ([encode (ascii_of_nat x)], s).
Proof.
  intros b0 env s x1 x H H0.
  destruct H0 as [Hb0 Hx].
  simpl.
  rewrite nat_ascii_embedding; auto.
Qed.
Hint Resolve auto_char_CHR : automation.

Theorem auto_char_ORD : forall b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([encode x], s)) ->
  b0 ->
  env |-- ([x1], s) ---> ([Num (nat_of_ascii x)], s).
Proof.
  intros b0 env s x1 x H H0.
  apply H in H0.
  simpl in *.
  assumption.
Qed.
Hint Resolve auto_char_ORD : automation.

(* word *)

Definition value_word {n} (w : word n) : Value :=
  Num (Z.to_nat (word.unsigned w)).

Theorem auto_word4_n2w : forall b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([Num x], s)) ->
  b0 /\ x < 16 ->
  env |-- ([x1], s) ---> ([value_word ((word.of_Z (Z.of_nat x)) : word4)], s).
Proof.
  intros b0 env s x1 x H H0.
  destruct H0 as [Hb0 Hx].
  apply H in Hb0.
  unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  assert ((Z.to_nat (Z.of_nat x mod 16)) = x).
  2: { rewrite H0. eapply Hb0. }
  rewrite Z.mod_small; lia.
Qed.
Hint Resolve auto_word4_n2w : automation.

Theorem auto_word64_n2w : forall b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([Num x], s)) ->
  b0 /\ x < 2 ^ 64 ->
  env |-- ([x1], s) ---> ([value_word ((word.of_Z (Z.of_nat x)) : word64)], s).
Proof.
  intros b0 env s x1 x H H0.
  destruct H0 as [Hb0 Hx].
  apply H in Hb0.
  unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  assert ((Z.to_nat (Z.of_nat x mod (2 ^ 64))) = x).
  2: { cbn in H0. rewrite H0. eapply Hb0. }
  rewrite Z.mod_small; try lia.
  apply inj_lt in Hx.
  split; try lia.
  rewrite inj_pow in Hx.
  simpl  Z.of_nat in Hx.
  assumption.
Qed.
Hint Resolve auto_word64_n2w : automation.

Theorem auto_word4_w2n : forall b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([value_word (x : word4)], s)) ->
  b0 ->
  env |-- ([x1], s) ---> ([Num (Z.to_nat (word.unsigned x))], s).
Proof.
  intros b0 env s x1 x H Hb0.
  apply H in Hb0.
  unfold value_word in *.
  assumption.
Qed.
Hint Resolve auto_word4_w2n : automation.

Theorem auto_word64_w2n : forall b0 env s x1 x,
  (b0 -> env |-- ([x1], s) ---> ([value_word (x : word64)], s)) ->
  b0 ->
  env |-- ([x1], s) ---> ([Num (Z.to_nat (word.unsigned x))], s).
Proof.
  intros b0 env s x1 x H Hb0.
  apply H in Hb0.
  unfold value_word in *.
  assumption.
Qed.
Hint Resolve auto_word64_w2n : automation.

(* TODO(kπ) Skipped common definitions and some automation for cons and case *)

(* TODO(kπ) Token *)

(* cmp *)

Global Instance Refinable_cmp : Refinable ImpSyntax.cmp :=
{ encode cmp :=
  match cmp with
  | ImpSyntax.Equal => value_name "Equal"
  | ImpSyntax.Less => value_name "Less"
  end }.

(* TODO(kπ) lammas *)

(* exp *)

Fixpoint encode_exp (e : ImpSyntax.exp) : Value :=
  match e with
  | ImpSyntax.Var n => value_list_of_values [value_name "Var"; Num n]
  | ImpSyntax.Const n => value_list_of_values [value_name "Const"; value_word n]
  | ImpSyntax.Add e1 e2 =>
      value_list_of_values [value_name "Add"; encode_exp e1; encode_exp e2]
  | ImpSyntax.Sub e1 e2 =>
      value_list_of_values [value_name "Sub"; encode_exp e1; encode_exp e2]
  | ImpSyntax.Div e1 e2 =>
      value_list_of_values [value_name "Div"; encode_exp e1; encode_exp e2]
  | ImpSyntax.Read e1 e2 =>
      value_list_of_values [value_name "Read"; encode_exp e1; encode_exp e2]
  end.

Global Instance Refinable_exp : Refinable ImpSyntax.exp :=
 { encode := encode_exp }.

(* TODO(kπ) lammas *)

(* test *)

Fixpoint encode_test (test : ImpSyntax.test) : Value :=
  match test with
  | ImpSyntax.Test c e1 e2 =>
      value_list_of_values [value_name "Test"; encode c; encode_exp e1; encode_exp e2]
  | ImpSyntax.And t1 t2 =>
      value_list_of_values [value_name "And"; encode_test t1; encode_test t2]
  | ImpSyntax.Or t1 t2 =>
      value_list_of_values [value_name "Or"; encode_test t1; encode_test t2]
  | ImpSyntax.Not t =>
      value_list_of_values [value_name "Not"; encode_test t]
  end.

Global Instance Refinable_test : Refinable ImpSyntax.test :=
{ encode := encode_test }.

(* TODO(kπ) lammas *)

(* list *)

(* TODO(kπ) lammas *)

(* app_list *)

Fixpoint encode_app_list {A} `{Refinable A} (l : app_list A) : Value :=
  match l with
  | List xs =>
      value_list_of_values [value_name "List"; encode xs]
  | Append xs ys =>
      value_list_of_values [value_name "Append"; encode_app_list xs;
                            encode_app_list ys]
  end.

Global Instance Refinable_app_list {A} `{Refinable A} : Refinable (app_list A) :=
{ encode := encode_app_list }.

(* TODO(kπ) lammas *)

(* TODO(kπ) continue *)


