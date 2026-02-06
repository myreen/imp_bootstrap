Require Import impboot.parsing.ParserData.
Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.functional.FunProperties.
Require Import impboot.functional.FunValues.
Require impboot.assembly.ASMSyntax.
Require impboot.imperative.ImpSyntax.
From impboot Require Import utils.Core utils.Env.
From coqutil Require Import dlet.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
Require Import impboot.utils.AppList.
Require Import Patat.Patat.

Create HintDb automation.

(* TODO: Reconsider how we switch between nat and N everywhere *)
(*       Can there be a conflict with with values vs names? *)
(*       Can we use N everywhere? *)
(*       Or can we just support both N and nat everywhere? or maybe Z? *)

(* TODO: sometimes we use (name_enc n) in automation lemmas and sometimes just (n) *)
(* This might be incorrect, when we pass the names explicitly in the automation *)

Theorem trans_app: forall n params vs body s s1 v,
  let env := make_env params vs FEnv.empty in
    (env |-- ([body], s) ---> ([v], s1)) ->
    List.length params = List.length vs ->
    lookup_fun (name_enc n) s.(funs) = Some (params, body) ->
    eval_app (name_enc n) vs s (v, s1).
Proof.
  intros; eapply App_intro; eauto.
  unfold env_and_body; simpl.
  pat `lookup_fun _ _ = _` at rewrite pat.
  pat `Datatypes.length _ = _` at rewrite <- Nat.eqb_eq in pat; rewrite pat.
  reflexivity.
Qed.

Theorem trans_Call: forall env xs s1 s2 s3 fname vs v,
  env |-- (xs, s1) ---> (vs, s2) ->
  eval_app fname vs s2 (v, s3) ->
  env |-- ([Call fname xs], s1) ---> ([v], s3).
Proof.
  intros.
  inversion H0; subst.
  eapply Eval_Call with (vs := vs) (s2 := s2); eauto.
Qed.

(* Wrap variables in some opaque definition (that is id) *)
(* then this would only compile (var _) *)
Theorem trans_Var : forall {A} `{ra: Refinable A} env s n (v: A),
  FEnv.lookup env (name_enc n) = Some (encode v) ->
  env |-- ([Var (name_enc n)], s) ---> ([encode v], s).
Proof.
  intros.
  apply Eval_Var; auto.
Qed.

Theorem trans_nil: forall env s,
  env |-- ([], s) ---> ([], s).
Proof.
  intros env s.
  apply Eval_Nil.
Qed.

Theorem trans_cons: forall env x xs v vs s s1 s2,
  env |-- ([x], s) ---> ([v], s1) ->
  env |-- (xs, s1) ---> (vs, s2) ->
  env |-- (x :: xs, s) ---> (v :: vs, s2).
Proof.
  intros * H1 H2.
  destruct xs; simpl in *.
  - inversion H2; subst; eauto.
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

Ltac crunch_NoDup :=
  repeat match goal with
  | [ H : NoDup (?t1 :: _) |- ¬ In ?t1 ?t2 ] =>
    rewrite NoDup_cons_iff in H; destruct H
  | [ H : NoDup (?h :: _) |- ¬ In ?t1 ?t2 ] =>
    apply NoDup_app_remove_l with (l := [h]) in H
  | [ H : ¬ In ?t1 (_ :: _) |- ¬ In ?t1 ?t2 ] =>
    eapply not_in_cons in H; destruct H
  | _ => assumption
  end.

Theorem auto_Prop: forall {A: Prop} s env (v: A),
  env |-- ([Const 0], s) ---> ([encode v], s).
Proof.
  intros.
  Eval_eq.
Qed.

(* Theorem auto_let : forall {A B} `{ra: Refinable A} `{rb: Refinable B} env x1 y1 s1 s2 s3 (v1: A) let_n f,
  env |-- ([x1], s1) ---> ([ra.(encode) v1], s2) ->
  (FEnv.insert ((name_enc let_n), Some (ra.(encode) v1)) env) |-- ([y1], s2) --->
      ([rb.(encode) (f v1)], s3) ->
  env |-- ([Let (name_enc let_n) x1 y1], s1) ---> ([rb.(encode) (dlet v1 f)], s3).
Proof.
  intros.
  eapply Eval_Let; eauto.
Qed. *)

Theorem auto_let : forall {A B} `{ra: Refinable A} `{rb: Refinable B} env x1 y1 s1 s2 s3 (v1: A) let_n f,
  env |-- ([x1], s1) ---> ([ra.(encode) v1], s2) ->
  (forall v2, v2 = v1 -> (FEnv.insert ((name_enc let_n), Some (ra.(encode) v2)) env) |-- ([y1], s2) --->
      ([rb.(encode) (f v2)], s3)) ->
  env |-- ([Let (name_enc let_n) x1 y1], s1) ---> ([rb.(encode) (dlet v1 f)], s3).
Proof.
  intros.
  eapply Eval_Let; eauto.
Qed.

(* bool *)

Theorem auto_bool_F : forall env s,
  env |-- ([Const 0], s) ---> ([encode false], s).
Proof.
  intros. apply Eval_Const.
Qed.

Theorem auto_bool_T : forall env s,
  env |-- ([Const 1], s) ---> ([encode true], s).
Proof.
  intros. apply Eval_Const.
Qed.

Theorem auto_bool_not : forall env s x1 b,
  env |-- ([x1], s) ---> ([encode b], s) ->
  env |-- ([Op Sub [Const 1; x1]], s) ---> ([encode (negb b)], s).
Proof.
  intros env s x1 b H.
  Eval_eq.
  destruct b; simpl; eauto with automation.
Qed.

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

Theorem last_bool_if: forall {A} `{ra: Refinable A} env s x_b x_t x_f (b: bool) (t f: A),
  env |-- ([x_b], s) ---> ([encode b], s) ->
  env |-- ([x_t], s) ---> ([encode t], s) ->
  env |-- ([x_f], s) ---> ([encode f], s) ->
  env |-- ([If Equal [x_b; Const 1] x_t x_f], s) ---> ([encode (if b then t else f)], s).
Proof.
  intros A Refinable_A env s x_b x_t x_f b t f H1 H2 H3.
  destruct (encode b) eqn:Hb; simpl in *.
  all: unfold encode in *; simpl in *; destruct b; inversion Hb; subst.
  all: Eval_eq.
Qed.

(* num *)

Theorem auto_nat_const_zero: forall env s,
  env |-- ([Const 0], s) ---> ([encode 0%nat], s).
Proof.
  intros. apply Eval_Const.
Qed.

Theorem auto_nat_const: forall env s (n: nat),
  env |-- ([Const (N.of_nat n)], s) ---> ([encode n], s).
Proof.
  intros. apply Eval_Const.
Qed.

Theorem auto_nat_succ: forall env s x1 (n: nat),
  env |-- ([x1], s) ---> ([encode n], s) ->
  env |-- ([Op FunSyntax.Add [Const 1; x1]], s) ---> ([encode (S n)], s).
Proof.
  intros.
  repeat econstructor; eauto.
  with_strategy opaque [N.add] simpl.
  rewrite N.add_1_l.
  unfold return_; simpl.
  repeat f_equal; lia.
Qed.

Theorem auto_N_const: forall env s (n: N),
  env |-- ([Const n], s) ---> ([encode n], s).
Proof.
  intros. apply Eval_Const.
Qed.

Theorem auto_N_to_nat: forall env s x1 (n: N),
  env |-- ([x1], s) ---> ([encode n], s) ->
  env |-- ([x1], s) ---> ([encode (N.to_nat n)], s).
Proof.
  intros.
  simpl.
  rewrite Nnat.N2Nat.id.
  repeat econstructor; eauto.
Qed.

Theorem auto_nat_add : forall env s0 s1 s2 x1 x2 (n1 n2: nat),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  env |-- ([Op FunSyntax.Add [x1; x2]], s0) ---> ([encode (n1 + n2)%nat], s2).
Proof.
  intros; simpl.
  repeat econstructor; eauto; simpl.
  rewrite Nnat.Nat2N.inj_add.
  reflexivity.
Qed.

Theorem auto_N_add : forall env s0 s1 s2 x1 x2 (n1 n2: N),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  env |-- ([Op FunSyntax.Add [x1; x2]], s0) ---> ([encode (n1 + n2)%N], s2).
Proof.
  intros; simpl.
  repeat econstructor; eauto; simpl.
Qed.

Theorem auto_nat_sub : forall env s0 s1 s2 x1 x2 (n1 n2: nat),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  env |-- ([Op FunSyntax.Sub [x1; x2]], s0) ---> ([encode (n1 - n2)%nat], s2).
Proof.
  intros.
  repeat econstructor; eauto; simpl.
  rewrite Nnat.Nat2N.inj_sub.
  reflexivity.
Qed.

Theorem auto_N_sub : forall env s0 s1 s2 x1 x2 (n1 n2: N),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  env |-- ([Op FunSyntax.Sub [x1; x2]], s0) ---> ([encode (n1 - n2)], s2).
Proof.
  intros.
  repeat econstructor; eauto; simpl.
Qed.

Theorem auto_nat_div : forall env s0 s1 s2 x1 x2 (n1 n2: nat),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  (N.of_nat n2) <> 0 ->
  (* Clement: It isn't ideal that we have the preconditions *)
  (* TODO: can do this vvv and remove the precondition *)
  (* env |-- ([If Equal [Const 0; x2] (Const 0) (Op FunSyntax.Div [x1; x2])], s0) ---> ([encode (n1 / n2)%nat], s2). *)
  env |-- ([Op FunSyntax.Div [x1; x2]], s0) ---> ([encode (n1 / n2)%nat], s2).
Proof.
  intros.
  repeat econstructor; eauto; simpl.
  rewrite <- N.eqb_neq in *; simpl.
  pat `_ = false` at rewrite pat.
  rewrite Nnat.Nat2N.inj_div.
  reflexivity.
Qed.

Theorem auto_N_div : forall env s0 s1 s2 x1 x2 (n1 n2: N),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  n2 <> 0 ->
  env |-- ([Op FunSyntax.Div [x1; x2]], s0) ---> ([encode (n1 / n2)], s2).
Proof.
  intros.
  repeat econstructor; eauto; simpl.
  rewrite <- N.eqb_neq in *; simpl.
  pat `_ = false` at rewrite pat.
  reflexivity.
Qed.

Theorem auto_nat_mul : forall env s0 s1 s2 x1 x2 (n1 n2: nat),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  env |-- ([Op FunSyntax.Mul [x1; x2]], s0) ---> ([encode (n1 * n2)%nat], s2).
Proof.
  intros.
  repeat econstructor; eauto; simpl.
  rewrite Nnat.Nat2N.inj_mul.
  reflexivity.
Qed.

Theorem auto_N_mul : forall env s0 s1 s2 x1 x2 (n1 n2: N),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  env |-- ([Op FunSyntax.Mul [x1; x2]], s0) ---> ([encode (n1 * n2)], s2).
Proof.
  intros.
  repeat econstructor; eauto; simpl.
Qed.

Theorem auto_nat_if_eq : forall {A} `{ra: Refinable A} env s x1 x2 y z (n1 n2: nat) (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  env |-- ([y], s) ---> ([encode t], s) ->
  env |-- ([z], s) ---> ([encode f], s) ->
  env |-- ([If Equal [x1; x2] y z], s) ---> ([encode (if (n1 =? n2)%nat then t else f)], s).
Proof.
  intros.
  destruct (_ =? _)%nat eqn:Heq.
  all: repeat econstructor; eauto.
  all: unfold take_branch, return_; try reflexivity.
  all: destruct (_ =? _) eqn:?; try rewrite Nat.eqb_eq in *; try rewrite Nat.eqb_neq in *; subst.
  all: try rewrite N.eqb_eq in *; try rewrite N.eqb_neq in *; subst.
  all: eauto.
  all: lia.
Qed.

Theorem auto_nat_if_eq_dec: forall {A} `{ra: Refinable A} env s x1 x2 x_t x_f (n1 n2: nat) t f,
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  (match Nat.eq_dec n1 n2 with
  | left EQ => env |-- ([x_t], s) ---> ([encode (t EQ)], s)
  | right NE =>
    env |-- ([x_f], s) ---> ([encode (f NE)], s)
  end) ->
  env |-- ([If Equal [x1; x2] x_t x_f], s) --->
     ([encode (
        match Nat.eq_dec n1 n2 with
        | left EQ => t EQ
        | right NE => f NE
        end)], s).
Proof.
  intros.
  destruct Nat.eq_dec eqn:Heq.
  all: repeat econstructor; eauto.
  all: unfold take_branch, return_; try reflexivity.
  all: destruct (_ =? _) eqn:?; try rewrite Nat.eqb_eq in *; try rewrite Nat.eqb_neq in *; subst.
  all: try rewrite N.eqb_eq in *; try rewrite N.eqb_neq in *; subst.
  all: eauto.
  all: lia.
Qed.

Theorem auto_N_if_eq : forall {A} `{ra: Refinable A} env s x1 x2 y z (n1 n2: N) (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  env |-- ([y], s) ---> ([encode t], s) ->
  env |-- ([z], s) ---> ([encode f], s) ->
  env |-- ([If Equal [x1; x2] y z], s) ---> ([encode (if (n1 =? n2)%N then t else f)], s).
Proof.
  intros.
  destruct (_ =? _)%N eqn:Heq.
  all: repeat econstructor; eauto.
  all: unfold take_branch, return_; try reflexivity.
  all: destruct (_ =? _) eqn:?; try rewrite Nat.eqb_eq in *; try rewrite Nat.eqb_neq in *; subst.
  all: try rewrite N.eqb_eq in *; try rewrite N.eqb_neq in *; subst.
  all: eauto.
  all: lia.
Qed.

Theorem auto_nat_if_less : forall {A} `{ra: Refinable A} env s x1 x2 y z (n1 n2: nat) (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  env |-- ([y], s) ---> ([encode t], s) ->
  env |-- ([z], s) ---> ([encode f], s) ->
  env |-- ([If Less [x1; x2] y z], s) ---> ([encode (if (n1 <? n2)%nat then t else f)], s).
Proof.
  intros.
  destruct (_ <? _)%nat eqn:Heq.
  all: repeat econstructor; eauto.
  all: unfold take_branch, return_; try reflexivity.
  all: destruct (_ <? _) eqn:?; rewrite ?Nat.ltb_lt, ?Nat.ltb_nlt in *; subst.
  all: try rewrite N.ltb_lt in *; try rewrite N.ltb_nlt in *; subst.
  all: eauto.
  all: lia.
Qed.

Theorem auto_N_if_less : forall {A} `{ra: Refinable A} env s x1 x2 y z (n1 n2: N) (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  (n1 <? n2 = true -> env |-- ([y], s) ---> ([encode t], s)) ->
  (n1 <? n2 = false -> env |-- ([z], s) ---> ([encode f], s)) ->
  env |-- ([If Less [x1; x2] y z], s) ---> ([encode (if (n1 <? n2)%N then t else f)], s).
Proof.
  intros.
  destruct (_ <? _)%N eqn:Heq.
  all: repeat econstructor; eauto.
  all: unfold take_branch, return_; try reflexivity.
  all: rewrite Heq; eauto.
Qed.

(* TODO: change "nat -> N" *)
(*       does it work with fix? *)
(*       use differnet induction lemma? *)

(* match eq_dec v0 with ... *)

(* for nat/N use strong induction instead of fix *)

(* same precondition in the inductive principle vvvvvvvv *)
(* destruct on `{v = 0} + {v = (pred v) + 1}` sort of like eq_dec *)

Theorem auto_nat_case: forall {A} `{ra: Refinable A} env s x0 x1 x2 n (v0: nat) (v1: A) v2,
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (match v0 with
  | 0%nat => env |-- ([x1], s) ---> ([encode v1], s)
  | S v0' =>
    (FEnv.insert (name_enc n, Some (encode v0')) env) |-- ([x2], s) --->
      ([encode (v2 v0')], s)
  end) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n)
        (Op Sub [x0; Const 1]) x2)], s) --->
     ([encode (
        match v0 with
        | 0%nat => v1
        | S n => v2 n
        end)], s).

  (* env |-- ([x0], s) ---> ([encode v0], s) ->
  (if (v0 =? 0)%nat then
    env |-- ([x1], s) ---> ([encode v1], s)
  else (∀v0', (v0' < v0)%nat ->
    (FEnv.insert (name_enc n, Some (encode v0')) env) |-- ([x2], s) --->
      ([encode (v2 v0')], s))) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n)
        (Op Sub [x0; Const 1]) x2)], s) --->
     ([encode (
        match v0 with
        | 0%nat => v1
        | S n => v2 n
        end)], s). *)
Proof.
  intros.
  destruct v0 eqn:?.
  Opaque N.of_nat.
  1: Eval_eq.
  simpl in *.
  subst.
  Eval_eq.
  assert ((N.of_nat (S n0) - 1) = N.of_nat n0) as -> by lia.
  eauto.
Qed.

(* When matching on N, we don't bind the predecessor (we use this for checking that `v0 <> 0`) *)
Theorem auto_N_case : forall {A} `{ra: Refinable A} env s x0 x1 x2 (v0: N) (v1: A) v2,
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (match v0 with
  | 0%N => env |-- ([x1], s) ---> ([encode v1], s)
  | N.pos _ => env |-- ([x2], s) ---> ([encode v2], s)
  end) ->
  env |-- ([If Equal [x0; Const 0] x1 x2], s) --->
     ([encode (
        match v0 with
        | 0%N => v1
        | _ => v2
        end)], s).
Proof.
  intros.
  destruct v0 eqn:?.
  1: Eval_eq.
  simpl in *.
  subst.
  Eval_eq.
Qed.

(* list *)

Theorem auto_list_nil: forall {A} `{ra: Refinable A} env s,
  env |-- ([Const 0], s) ---> ([encode (@nil A)], s).
Proof.
  intros; econstructor.
Qed.

Theorem auto_list_cons : forall {A} `{ra: Refinable A} env s x1 x2 x xs,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x2], s) ---> ([encode xs], s) ->
  env |-- ([Op Cons [x1; x2]], s) ---> ([encode (x :: xs)], s).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.

Theorem auto_list_case: forall {A B} `{ra: Refinable A} `{rb : Refinable B} env s x0 x1 x2 n1 n2 (v0: list A) (v1: B) (v2: A -> list A -> B),
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (match v0 with
   | [] =>
     env |-- ([x1], s) ---> ([rb.(encode) v1], s)
   | h :: t =>
     (FEnv.insert (name_enc n2, Some (encode t))
      (FEnv.insert (name_enc n1, Some (ra.(encode) h)) env)) |-- ([x2], s) --->
        ([rb.(encode) (v2 h t)], s)
   end) ->
  NoDup ([name_enc n1] ++ free_vars x0) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n1) (Op Head [x0])
        (Let (name_enc n2) (Op Tail [x0]) x2))], s) --->
    ([rb.(encode) (
      match v0 with
      | [] => v1
      | h :: t => v2 h t
      end)], s).
Proof.
  intros.
  destruct v0 eqn:?.
  1: Eval_eq.
  simpl in *.
  subst.
  rewrite NoDup_cons_iff in *.
  pat `_ /\ _` at destruct pat.
  Eval_eq.
  + rewrite remove_env_update; eauto.
  + simpl; reflexivity.
Qed.

(* option *)

Theorem auto_option_none : forall {A} `{ra: Refinable A} env s,
  env |-- ([Const 0], s) ---> ([encode None], s).
Proof.
  intros; econstructor.
Qed.

Theorem auto_option_some : forall {A} `{ra: Refinable A} env s x1 x,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([Op Cons [x1; Const 0]], s) ---> ([encode (Some x)], s).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.

Theorem auto_option_case : forall {A B} `{ra: Refinable A} `{rb : Refinable B} (v0 : option A) env s x0 x1 x2 n v1 v2,
  env |-- ([x0],s) ---> ([encode v0],s) ->
  (match v0 with
   | None =>
     env |-- ([x1],s) ---> ([rb.(encode) v1],s)
   | Some inner =>
     (FEnv.insert (name_enc n, Some (encode inner)) env) |-- ([x2],s) --->
       ([rb.(encode) (v2 inner)],s)
   end) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n) (Op Head [x0]) x2)], s) --->
     ([rb.(encode) (
      match v0 with
      | None => v1
      | Some inner => v2 inner
      end)], s).
Proof.
  intros.
  destruct v0 as [y1|]; simpl in *.
  - Eval_eq.
  - Eval_eq.
Qed.

(* pair *)

Theorem auto_pair_fst : forall {A B} `{ra: Refinable A} `{rb: Refinable B} env s x1 (x: A * B),
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([Op Head [x1]], s) ---> ([encode (fst x)], s).
Proof.
  intros.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.

Theorem auto_pair_snd : forall {A B} `{ra: Refinable A} `{rb: Refinable B} env s x1 (x: A * B),
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([Op Tail [x1]], s) ---> ([encode (snd x)], s).
Proof.
  intros.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.

Theorem auto_pair_cons : forall {A B} `{ra: Refinable A} `{rb: Refinable B} env s x1 x2 (x: A) (y: B),
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x2], s) ---> ([encode y], s) ->
  env |-- ([Op Cons [x1; x2]], s) ---> ([encode (x, y)], s).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.

Theorem auto_pair_case : forall {A1 A2 B} `{ra1 : Refinable A1} `{ra2 : Refinable A2} `{rb : Refinable B}
    env s x0 x1 n1 n2 (v0 : A1 * A2) v1,
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (match v0 with
   | (y1, y2) =>
     (FEnv.insert (name_enc n2, Some (ra2.(encode) y2))
       (FEnv.insert (name_enc n1, Some (ra1.(encode) y1)) env)) |-- ([x1], s) --->
         ([rb.(encode) (v1 y1 y2)], s)
   end) ->
  NoDup ([name_enc n1] ++ free_vars x0) ->
  env |-- ([Let (name_enc n1) (Op Head [x0])
      (Let (name_enc n2) (Op Tail [x0]) x1)], s) --->
  ([rb.(encode) (match v0 with
                 | (y1, y2) => v1 y1 y2
                 end)], s).
Proof.
  intros.
  destruct v0 as [y1 y2]; simpl in *.
  Eval_eq.
  - repeat rewrite NoDup_cons_iff in *; destruct H1.
    rewrite remove_env_update; eauto.
  - simpl; reflexivity.
Qed.

(* char *)

(* TODO: this + the same pattern in word is a crime *)
Theorem auto_char_of_nat : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode x], s) ->
  ((N_of_nat x) < 256) ->
  env |-- ([x1], s) ---> ([encode (ascii_of_nat x)], s).
Proof.
  intros.
  simpl.
  unfold ascii_of_nat.
  rewrite N_ascii_embedding; auto.
Qed.

Theorem auto_char_of_N : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode x], s) ->
  (x < 256) ->
  env |-- ([x1], s) ---> ([encode (ascii_of_N x)], s).
Proof.
  intros.
  simpl.
  unfold ascii_of_nat.
  rewrite N_ascii_embedding; auto.
Qed.

Theorem auto_char_to_nat : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x1], s) ---> ([encode (nat_of_ascii x)], s).
Proof.
  intros.
  simpl in *.
  unfold nat_of_ascii.
  rewrite Nnat.N2Nat.id.
  assumption.
Qed.

Theorem auto_char_to_N : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x1], s) ---> ([encode (N_of_ascii x)], s).
Proof.
  intros.
  simpl in *.
  unfold nat_of_ascii.
  assumption.
Qed.

Theorem auto_char_const: forall env s (chr: ascii),
  env |-- ([Const (N_of_ascii chr)], s) ---> ([encode chr], s).
Proof.
  intros.
  simpl in *.
  Eval_eq.
Qed.

Theorem auto_char_if_eq : forall {A} `{ra: Refinable A} env s x1 x2 y z (n1 n2: ascii) (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  env |-- ([y], s) ---> ([encode t], s) ->
  env |-- ([z], s) ---> ([encode f], s) ->
  env |-- ([If Equal [x1; x2] y z], s) ---> ([encode (if Ascii.eqb n1 n2 then t else f)], s).
Proof.
  intros.
  destruct (Ascii.eqb _ _) eqn:Heq.
  all: repeat econstructor; eauto.
  all: unfold take_branch, return_; try reflexivity.
  all: destruct (_ =? _) eqn:?; try rewrite Nat.eqb_eq in *; try rewrite Nat.eqb_neq in *; subst.
  all: try rewrite N.eqb_eq in *; try rewrite N.eqb_neq in *; subst.
  all: eauto.
  all: rewrite ?Ascii.eqb_eq, ?Ascii.eqb_neq in *; subst.
  all: try congruence.
  all: unfold enc_char in *.
  assert (ascii_of_N (N_of_ascii n1) = ascii_of_N (N_of_ascii n2)).
  1: rewrite Heqb; reflexivity.
  do 2 rewrite ascii_N_embedding in *.
  congruence.
Qed.

(* string *)

Theorem auto_string_nil: forall env s,
  env |-- ([Const 0], s) ---> ([encode (EmptyString)], s).
Proof.
  intros; econstructor.
Qed.

Theorem auto_string_cons : forall env s x1 x2 x xs,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x2], s) ---> ([encode xs], s) ->
  env |-- ([Op Cons [x1; x2]], s) ---> ([encode (String x xs)], s).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.

Theorem auto_string_case: forall {B} `{rb : Refinable B} env s x0 x1 x2 n1 n2 (v0: string) (v1: B) (v2: ascii -> string -> B),
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (match v0 with
   | EmptyString =>
     env |-- ([x1], s) ---> ([rb.(encode) v1], s)
   | String h t =>
     (FEnv.insert (name_enc n2, Some (encode t))
      (FEnv.insert (name_enc n1, Some (encode h)) env)) |-- ([x2], s) --->
        ([rb.(encode) (v2 h t)], s)
   end) ->
  NoDup ([name_enc n1] ++ free_vars x0) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n1) (Op Head [x0])
        (Let (name_enc n2) (Op Tail [x0]) x2))], s) --->
    ([rb.(encode) (
      match v0 with
      | EmptyString => v1
      | String h t => v2 h t
      end)], s).
Proof.
  intros.
  destruct v0 eqn:?.
  1: Eval_eq.
  simpl in *.
  subst.
  rewrite NoDup_cons_iff in *.
  pat `_ /\ _` at destruct pat.
  Eval_eq.
  + rewrite remove_env_update; eauto.
  + simpl; reflexivity.
Qed.

Theorem auto_string_to_list: forall env s x1 str,
  env |-- ([x1], s) ---> ([encode str], s) ->
  env |-- ([x1], s) ---> ([encode (list_ascii_of_string str)], s).
Proof.
  intros.
  simpl in *.
  assumption.
Qed.

(* word *)

Opaque word.of_Z.

Definition value_word {n} `{word_inst : word n} (w : @word.rep n word_inst) : Value :=
  Num (Z.to_N (word.unsigned w)).

Global Instance Refinable_word {n} `{word_inst : word n} : Refinable (@word.rep n word_inst) :=
{ encode w := value_word w }.

Theorem auto_word4_n2w : forall env s x1 (x: nat),
  env |-- ([x1], s) ---> ([encode x], s) ->
  ((N.of_nat x) < 16) ->
  env |-- ([x1], s) ---> ([encode ((word.of_Z (Z.of_nat x)) : word4)], s).
Proof.
  intros.
  unfold encode; simpl; unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  assert ((Z.to_N (Z.of_nat x mod 16)) = (N.of_nat x)).
  2: rewrite H1; eapply H.
  rewrite Z.mod_small; lia.
Qed.

Theorem auto_word64_N2w : forall env s x1 (x: N),
  env |-- ([x1], s) ---> ([encode x], s) ->
  (x < 2 ^ 64) ->
  env |-- ([x1], s) ---> ([encode ((word.of_Z (Z.of_N x)) : word64)], s).
Proof.
  intros.
  unfold encode; simpl; unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  rewrite Z.mod_small; try lia.
  rewrite N2Z.id; eauto.
Qed.

Theorem auto_word64_n2w : forall env s x1 x,
  (* TODO: can do this and remove the pre-condition *)
  (* env |-- ([x1], s) ---> ([encode (Nat.modulo x (2 ^ 64))], s) -> *)
  env |-- ([x1], s) ---> ([encode x], s) ->
  ((N.of_nat x) < 2 ^ 64) ->
  env |-- ([x1], s) ---> ([encode ((word.of_Z (Z.of_nat x)) : word64)], s).
Proof.
  intros.
  unfold encode; simpl; unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  assert ((Z.to_N (Z.of_nat x mod (2 ^ 64))) = (N.of_nat x)).
  2: cbn in H1; rewrite H1; eapply H.
  rewrite Z.mod_small; try lia.
  (* split; try lia.
  clear H.
  replace (2 ^ 64 : Z) with (Z.of_nat (2 ^ 64)%nat).
  - now apply Nat2Z.inj_lt.
  - rewrite Nat2Z.inj_pow; simpl; reflexivity. *)
Qed.

Theorem auto_word4_w2N : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode (x: word4)], s) ->
  env |-- ([x1], s) ---> ([encode (Z.to_N (word.unsigned x))], s).
Proof.
  intros.
  unfold encode; simpl; unfold value_word in *.
  assumption.
Qed.

Theorem auto_word64_w2N : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode (x: word64)], s) ->
  env |-- ([x1], s) ---> ([encode (Z.to_N (word.unsigned x))], s).
Proof.
  intros.
  unfold encode; simpl; unfold value_word in *.
  assumption.
Qed.

Theorem auto_word4_w2n : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode (x: word4)], s) ->
  env |-- ([x1], s) ---> ([encode (Z.to_nat (word.unsigned x))], s).
Proof.
  intros.
  unfold encode; simpl; unfold value_word in *.
  rewrite Z_nat_N.
  assumption.
Qed.

Theorem auto_word64_w2n : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode (x: word64)], s) ->
  env |-- ([x1], s) ---> ([encode (Z.to_nat (word.unsigned x))], s).
Proof.
  intros.
  unfold encode; simpl; unfold value_word in *.
  rewrite Z_nat_N.
  assumption.
Qed.

(* TODO(kπ) Skipped common definitions and some automation for cons and case *)

(* TODO(kπ) Token *)

(* cmp *)

Global Instance Refinable_cmp : Refinable ImpSyntax.cmp :=
{ encode cmp :=
  match cmp with
  | ImpSyntax.Equal => value_name "Equal"
  | ImpSyntax.Less => value_name "Less"
  end }.

Theorem auto_cmp_cons_Equal: forall env s,
  env |-- ([Const (name_enc "Equal")], s) ---> ([encode ImpSyntax.Equal], s).
Proof. Eval_eq. Qed.

Theorem auto_cmp_cons_Less: forall env s,
  env |-- ([Const (name_enc "Less")], s) ---> ([encode ImpSyntax.Less], s).
Proof. Eval_eq. Qed.

Theorem auto_cmp_CASE: forall {A} `{ra: Refinable A} env s x0 Less_exp Equal_exp v0 f_Less f_Equal,
  env |-- ([x0],s) ---> ([encode v0],s) ->
  (match v0 with
   | ImpSyntax.Less =>
     env |-- ([Less_exp],s) ---> ([encode f_Less],s)
   | ImpSyntax.Equal =>
     env |-- ([Equal_exp],s) ---> ([encode f_Equal],s)
   end) ->
  env |-- ([If Equal [x0; Const (name_enc "Less")] Less_exp
      (If Equal [x0; Const (name_enc "Equal")] Equal_exp (Const 0))],s) --->
  ([encode (match v0 with ImpSyntax.Less => f_Less | ImpSyntax.Equal => f_Equal end)],s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  1: Eval_eq.
  Eval_eq.
Qed.

(* exp *)

Fixpoint encode_exp (e : ImpSyntax.exp) : Value :=
  match e with
  | ImpSyntax.Var n => value_list_of_values [value_name "Var"; Num n]
  | ImpSyntax.Const n => value_list_of_values [value_name "Const"; encode n]
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

Theorem auto_exp_cons_Var: forall env s x_n n,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "Var"); Op Cons [x_n; Const 0]]], s) --->
       ([encode (ImpSyntax.Var n)], s).
Proof. Eval_eq. Qed.

Theorem auto_exp_cons_Const: forall env s x_n n,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "Const"); Op Cons [x_n; Const 0]]], s) --->
       ([encode (ImpSyntax.Const n)], s).
Proof. Eval_eq. Qed.

Theorem auto_exp_cons_Add: forall env s x_e1 x_e2 e1 e2,
  env |-- ([x_e1], s) ---> ([encode e1], s) ->
  env |-- ([x_e2], s) ---> ([encode e2], s) ->
  env |-- ([Op Cons [Const (name_enc "Add"); Op Cons [x_e1; Op Cons [x_e2; Const 0]]]], s) --->
       ([encode (ImpSyntax.Add e1 e2)], s).
Proof. Eval_eq. Qed.

Theorem auto_exp_cons_Sub: forall env s x_e1 x_e2 e1 e2,
  env |-- ([x_e1], s) ---> ([encode e1], s) ->
  env |-- ([x_e2], s) ---> ([encode e2], s) ->
  env |-- ([Op Cons [Const (name_enc "Sub"); Op Cons [x_e1; Op Cons [x_e2; Const 0]]]], s) --->
       ([encode (ImpSyntax.Sub e1 e2)], s).
Proof. Eval_eq. Qed.

Theorem auto_exp_cons_Div: forall env s x_e1 x_e2 e1 e2,
  env |-- ([x_e1], s) ---> ([encode e1], s) ->
  env |-- ([x_e2], s) ---> ([encode e2], s) ->
  env |-- ([Op Cons [Const (name_enc "Div"); Op Cons [x_e1; Op Cons [x_e2; Const 0]]]], s) --->
       ([encode (ImpSyntax.Div e1 e2)], s).
Proof. Eval_eq. Qed.

Theorem auto_exp_cons_Read: forall env s x_e1 x_e2 e1 e2,
  env |-- ([x_e1], s) ---> ([encode e1], s) ->
  env |-- ([x_e2], s) ---> ([encode e2], s) ->
  env |-- ([Op Cons [Const (name_enc "Read"); Op Cons [x_e1; Op Cons [x_e2; Const 0]]]], s) --->
       ([encode (ImpSyntax.Read e1 e2)], s).
Proof. Eval_eq. Qed.

Theorem auto_exp_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  Var_case Const_case Add_case Sub_case Div_case Read_case
  f_Var f_Const f_Add f_Sub f_Div f_Read
  (n1 n2 n3 n4 n5 n6 n7 n8 n9 n10: string),

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | ImpSyntax.Var n =>
     (FEnv.insert (name_enc n1, Some (encode n)) env) |-- ([Var_case], s) ---> ([encode (f_Var n)], s)
   | ImpSyntax.Const w =>
     (FEnv.insert (name_enc n2, Some (encode w)) env) |-- ([Const_case], s) ---> ([encode (f_Const w)], s)
   | ImpSyntax.Add e1 e2 =>
     (FEnv.insert (name_enc n4, Some (encode e2))
       (FEnv.insert (name_enc n3, Some (encode e1)) env)) |-- ([Add_case], s) ---> ([encode (f_Add e1 e2)], s)
   | ImpSyntax.Sub e1 e2 =>
     (FEnv.insert (name_enc n6, Some (encode e2))
       (FEnv.insert (name_enc n5, Some (encode e1)) env)) |-- ([Sub_case], s) ---> ([encode (f_Sub e1 e2)], s)
   | ImpSyntax.Div e1 e2 =>
     (FEnv.insert (name_enc n8, Some (encode e2))
       (FEnv.insert (name_enc n7, Some (encode e1)) env)) |-- ([Div_case], s) ---> ([encode (f_Div e1 e2)], s)
   | ImpSyntax.Read e1 e2 =>
     (FEnv.insert (name_enc n10, Some (encode e2))
       (FEnv.insert (name_enc n9, Some (encode e1)) env)) |-- ([Read_case], s) ---> ([encode (f_Read e1 e2)], s)
   end) ->

  NoDup ([name_enc n3] ++ free_vars x0) ->
  NoDup ([name_enc n5] ++ free_vars x0) ->
  NoDup ([name_enc n7] ++ free_vars x0) ->
  NoDup ([name_enc n9] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Var")]
            (Let (name_enc n1) (Op Head [Op Tail [x0]]) Var_case)
        (If Equal [Op Head [x0]; Const (name_enc "Const")]
            (Let (name_enc n2) (Op Head [Op Tail [x0]]) Const_case)
        (If Equal [Op Head [x0]; Const (name_enc "Add")]
            (Let (name_enc n3) (Op Head [Op Tail [x0]])
              (Let (name_enc n4) (Op Head [Op Tail [Op Tail [x0]]]) Add_case))
        (If Equal [Op Head [x0]; Const (name_enc "Sub")]
            (Let (name_enc n5) (Op Head [Op Tail [x0]])
              (Let (name_enc n6) (Op Head [Op Tail [Op Tail [x0]]]) Sub_case))
        (If Equal [Op Head [x0]; Const (name_enc "Div")]
            (Let (name_enc n7) (Op Head [Op Tail [x0]])
              (Let (name_enc n8) (Op Head [Op Tail [Op Tail [x0]]]) Div_case))
        (If Equal [Op Head [x0]; Const (name_enc "Read")]
            (Let (name_enc n9) (Op Head [Op Tail [x0]])
              (Let (name_enc n10) (Op Head [Op Tail [Op Tail [x0]]]) Read_case))
        (Const 0))))))], s) --->
     ([encode (
       match v0 with
       | ImpSyntax.Var n => f_Var n
       | ImpSyntax.Const w => f_Const w
       | ImpSyntax.Add e1 e2 => f_Add e1 e2
       | ImpSyntax.Sub e1 e2 => f_Sub e1 e2
       | ImpSyntax.Div e1 e2 => f_Div e1 e2
       | ImpSyntax.Read e1 e2 => f_Read e1 e2
       end)], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *.
  all: subst.
  all: Eval_eq.
  all: try rewrite remove_env_update; eauto; crunch_NoDup.
  all: simpl; reflexivity.
Qed.

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

Theorem auto_test_cons_Test: forall env s x_cmp x_e1 x_e2 c e1 e2,
  env |-- ([x_cmp], s) ---> ([encode c], s) ->
  env |-- ([x_e1], s) ---> ([encode e1], s) ->
  env |-- ([x_e2], s) ---> ([encode e2], s) ->
  env |-- ([Op Cons [Const (name_enc "Test");
                     Op Cons [x_cmp; Op Cons [x_e1; Op Cons [x_e2; Const 0]]]]], s) --->
        ([encode (ImpSyntax.Test c e1 e2)], s).
Proof. Eval_eq. Qed.

Theorem auto_test_cons_And: forall env s x_t1 x_t2 t1 t2,
  env |-- ([x_t1], s) ---> ([encode t1], s) ->
  env |-- ([x_t2], s) ---> ([encode t2], s) ->
  env |-- ([Op Cons [Const (name_enc "And");
                     Op Cons [x_t1; Op Cons [x_t2; Const 0]]]], s) --->
        ([encode (ImpSyntax.And t1 t2)], s).
Proof. Eval_eq. Qed.

Theorem auto_test_cons_Or: forall env s x_t1 x_t2 t1 t2,
  env |-- ([x_t1], s) ---> ([encode t1], s) ->
  env |-- ([x_t2], s) ---> ([encode t2], s) ->
  env |-- ([Op Cons [Const (name_enc "Or");
                     Op Cons [x_t1; Op Cons [x_t2; Const 0]]]], s) --->
        ([encode (ImpSyntax.Or t1 t2)], s).
Proof. Eval_eq. Qed.

Theorem auto_test_cons_Not: forall env s x_t t,
  env |-- ([x_t], s) ---> ([encode t], s) ->
  env |-- ([Op Cons [Const (name_enc "Not");
                     Op Cons [x_t; Const 0]]], s) --->
        ([encode (ImpSyntax.Not t)], s).
Proof. Eval_eq. Qed.

Theorem auto_test_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  Test_case And_case Or_case Not_case
  f_Test f_And f_Or f_Not
  n1 n2 n3 n4 n5 n6 n7 n8,
  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | ImpSyntax.Test c e1 e2 =>
     (FEnv.insert (name_enc n3, Some (encode e2))
       (FEnv.insert (name_enc n2, Some (encode e1))
         (FEnv.insert (name_enc n1, Some (encode c)) env))) |-- ([Test_case], s) ---> ([encode (f_Test c e1 e2)], s)
   | ImpSyntax.And t1 t2 =>
     (FEnv.insert (name_enc n5, Some (encode t2))
       (FEnv.insert (name_enc n4, Some (encode t1)) env)) |-- ([And_case], s) ---> ([encode (f_And t1 t2)], s)
   | ImpSyntax.Or t1 t2 =>
     (FEnv.insert (name_enc n7, Some (encode t2))
       (FEnv.insert (name_enc n6, Some (encode t1)) env)) |-- ([Or_case], s) ---> ([encode (f_Or t1 t2)], s)
   | ImpSyntax.Not t =>
     (FEnv.insert (name_enc n8, Some (encode t)) env) |-- ([Not_case], s) ---> ([encode (f_Not t)], s)
   end) ->

  NoDup ([name_enc n1; name_enc n2] ++ free_vars x0) ->
  NoDup ([name_enc n4] ++ free_vars x0) ->
  NoDup ([name_enc n6] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Test")]
            (Let (name_enc n1) (Op Head [Op Tail [x0]])
              (Let (name_enc n2) (Op Head [Op Tail [Op Tail [x0]]])
                (Let (name_enc n3) (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Test_case)))
       (If Equal [Op Head [x0]; Const (name_enc "And")]
            (Let (name_enc n4) (Op Head [Op Tail [x0]])
              (Let (name_enc n5) (Op Head [Op Tail [Op Tail [x0]]]) And_case))
       (If Equal [Op Head [x0]; Const (name_enc "Or")]
            (Let (name_enc n6) (Op Head [Op Tail [x0]])
              (Let (name_enc n7) (Op Head [Op Tail [Op Tail [x0]]]) Or_case))
       (If Equal [Op Head [x0]; Const (name_enc "Not")]
            (Let (name_enc n8) (Op Head [Op Tail [x0]]) Not_case)
       (Const 0))))], s) --->

     ([encode (
       match v0 with
       | ImpSyntax.Test c e1 e2 => f_Test c e1 e2
       | ImpSyntax.And t1 t2 => f_And t1 t2
       | ImpSyntax.Or t1 t2 => f_Or t1 t2
       | ImpSyntax.Not t => f_Not t
       end)], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *.
  all: subst.
  all: Eval_eq.
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
Qed.

(* cmd *)

Fixpoint encode_cmd (cmd : ImpSyntax.cmd) : Value :=
  match cmd with
  | ImpSyntax.Skip =>
    value_list_of_values [value_name "Skip"]
  | ImpSyntax.Seq c1 c2 =>
    value_list_of_values [value_name "Seq"; encode_cmd c1; encode_cmd c2]
  | ImpSyntax.Assign n e =>
    value_list_of_values [value_name "Assign"; encode n; encode_exp e]
  | ImpSyntax.Update a e e' =>
    value_list_of_values [value_name "Update"; encode a; encode e; encode e']
  | ImpSyntax.If t c1 c2 =>
    value_list_of_values [value_name "If"; encode t; encode_cmd c1; encode_cmd c2]
  | ImpSyntax.While t c =>
    value_list_of_values [value_name "While"; encode t; encode_cmd c]
  | ImpSyntax.Call n f es =>
    value_list_of_values [value_name "Call"; encode n; encode f; encode es]
  | ImpSyntax.Return e =>
    value_list_of_values [value_name "Return"; encode e]
  | ImpSyntax.Alloc n e =>
    value_list_of_values [value_name "Alloc"; encode n; encode e]
  | ImpSyntax.GetChar n =>
    value_list_of_values [value_name "GetChar"; encode n]
  | ImpSyntax.PutChar e =>
    value_list_of_values [value_name "PutChar"; encode e]
  | ImpSyntax.Abort =>
    value_list_of_values [value_name "Abort"]
  end.

Global Instance Refinable_cmd : Refinable ImpSyntax.cmd :=
  { encode := encode_cmd }.

Theorem auto_cmd_cons_Skip: forall env s,
  env |-- ([Op Cons [Const (name_enc "Skip"); Const 0]], s) --->
        ([encode ImpSyntax.Skip], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_Seq: forall env s x_c1 x_c2 c1 c2,
  env |-- ([x_c1], s) ---> ([encode c1], s) ->
  env |-- ([x_c2], s) ---> ([encode c2], s) ->
  env |-- ([Op Cons [Const (name_enc "Seq");
                     Op Cons [x_c1; Op Cons [x_c2; Const 0]]]], s) --->
        ([encode (ImpSyntax.Seq c1 c2)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_Assign: forall env s x_n x_e n e,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([x_e], s) ---> ([encode e], s) ->
  env |-- ([Op Cons [Const (name_enc "Assign");
                     Op Cons [x_n; Op Cons [x_e; Const 0]]]], s) --->
        ([encode (ImpSyntax.Assign n e)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_Update: forall env s x_a x_e1 x_e2 a e e',
  env |-- ([x_a], s) ---> ([encode a], s) ->
  env |-- ([x_e1], s) ---> ([encode e], s) ->
  env |-- ([x_e2], s) ---> ([encode e'], s) ->
  env |-- ([Op Cons [Const (name_enc "Update");
                     Op Cons [x_a; Op Cons [x_e1; Op Cons [x_e2; Const 0]]]]], s) --->
        ([encode (ImpSyntax.Update a e e')], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_If: forall env s x_t x_c1 x_c2 t c1 c2,
  env |-- ([x_t], s) ---> ([encode t], s) ->
  env |-- ([x_c1], s) ---> ([encode c1], s) ->
  env |-- ([x_c2], s) ---> ([encode c2], s) ->
  env |-- ([Op Cons [Const (name_enc "If");
                     Op Cons [x_t; Op Cons [x_c1; Op Cons [x_c2; Const 0]]]]], s) --->
        ([encode (ImpSyntax.If t c1 c2)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_While: forall env s x_t x_c t c,
  env |-- ([x_t], s) ---> ([encode t], s) ->
  env |-- ([x_c], s) ---> ([encode c], s) ->
  env |-- ([Op Cons [Const (name_enc "While");
                     Op Cons [x_t; Op Cons [x_c; Const 0]]]], s) --->
        ([encode (ImpSyntax.While t c)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_Call: forall env s x_n x_f x_es n f es,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([x_f], s) ---> ([encode f], s) ->
  env |-- ([x_es], s) ---> ([encode es], s) ->
  env |-- ([Op Cons [Const (name_enc "Call");
                     Op Cons [x_n; Op Cons [x_f; Op Cons [x_es; Const 0]]]]], s) --->
        ([encode (ImpSyntax.Call n f es)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_Return: forall env s x_e e,
  env |-- ([x_e], s) ---> ([encode e], s) ->
  env |-- ([Op Cons [Const (name_enc "Return");
                     Op Cons [x_e; Const 0]]], s) --->
        ([encode (ImpSyntax.Return e)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_Alloc: forall env s x_n x_e n e,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([x_e], s) ---> ([encode e], s) ->
  env |-- ([Op Cons [Const (name_enc "Alloc");
                     Op Cons [x_n; Op Cons [x_e; Const 0]]]], s) --->
        ([encode (ImpSyntax.Alloc n e)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_GetChar: forall env s x_n n,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "GetChar");
                     Op Cons [x_n; Const 0]]], s) --->
        ([encode (ImpSyntax.GetChar n)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_PutChar: forall env s x_e e,
  env |-- ([x_e], s) ---> ([encode e], s) ->
  env |-- ([Op Cons [Const (name_enc "PutChar");
                     Op Cons [x_e; Const 0]]], s) --->
        ([encode (ImpSyntax.PutChar e)], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_cons_Abort: forall env s,
  env |-- ([Op Cons [Const (name_enc "Abort"); Const 0]], s) --->
        ([encode ImpSyntax.Abort], s).
Proof. Eval_eq. Qed.

Theorem auto_cmd_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  Skip_case Seq_case Assign_case Update_case If_case While_case
  Call_case Return_case Alloc_case GetChar_case PutChar_case Abort_case
  f_Skip f_Seq f_Assign f_Update f_If f_While f_Call f_Return f_Alloc f_GetChar f_PutChar f_Abort
  n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | ImpSyntax.Skip => env |-- ([Skip_case], s) ---> ([encode (f_Skip)], s)
   | ImpSyntax.Seq c1 c2 =>
     (FEnv.insert (name_enc n2, Some (encode c2))
       (FEnv.insert (name_enc n1, Some (encode c1)) env)) |-- ([Seq_case], s) ---> ([encode (f_Seq c1 c2)], s)
   | ImpSyntax.Assign n e =>
     (FEnv.insert (name_enc n4, Some (encode e))
       (FEnv.insert (name_enc n3, Some (encode n)) env)) |-- ([Assign_case], s) ---> ([encode (f_Assign n e)], s)
   | ImpSyntax.Update a e e' =>
     (FEnv.insert (name_enc n7, Some (encode e'))
       (FEnv.insert (name_enc n6, Some (encode e))
         (FEnv.insert (name_enc n5, Some (encode a)) env))) |-- ([Update_case], s) ---> ([encode (f_Update a e e')], s)
   | ImpSyntax.If t c1 c2 =>
     (FEnv.insert (name_enc n10, Some (encode c2))
       (FEnv.insert (name_enc n9, Some (encode c1))
         (FEnv.insert (name_enc n8, Some (encode t)) env))) |-- ([If_case], s) ---> ([encode (f_If t c1 c2)], s)
   | ImpSyntax.While t c =>
     (FEnv.insert (name_enc n12, Some (encode c))
       (FEnv.insert (name_enc n11, Some (encode t)) env)) |-- ([While_case], s) ---> ([encode (f_While t c)], s)
   | ImpSyntax.Call n f es =>
     (FEnv.insert (name_enc n15, Some (encode es))
       (FEnv.insert (name_enc n14, Some (encode f))
         (FEnv.insert (name_enc n13, Some (encode n)) env))) |-- ([Call_case], s) ---> ([encode (f_Call n f es)], s)
   | ImpSyntax.Return e =>
     (FEnv.insert (name_enc n16, Some (encode e)) env) |-- ([Return_case], s) ---> ([encode (f_Return e)], s)
   | ImpSyntax.Alloc n e =>
     (FEnv.insert (name_enc n18, Some (encode e))
       (FEnv.insert (name_enc n17, Some (encode n)) env)) |-- ([Alloc_case], s) ---> ([encode (f_Alloc n e)], s)
   | ImpSyntax.GetChar n =>
     (FEnv.insert (name_enc n19, Some (encode n)) env) |-- ([GetChar_case], s) ---> ([encode (f_GetChar n)], s)
   | ImpSyntax.PutChar e =>
     (FEnv.insert (name_enc n20, Some (encode e)) env) |-- ([PutChar_case], s) ---> ([encode (f_PutChar e)], s)
   | ImpSyntax.Abort => env |-- ([Abort_case], s) ---> ([encode (f_Abort)], s)
   end) ->

  NoDup ([name_enc n1] ++ free_vars x0) ->
  NoDup ([name_enc n3] ++ free_vars x0) ->
  NoDup ([name_enc n5; name_enc n6] ++ free_vars x0) ->
  NoDup ([name_enc n8; name_enc n9] ++ free_vars x0) ->
  NoDup ([name_enc n11] ++ free_vars x0) ->
  NoDup ([name_enc n13; name_enc n14] ++ free_vars x0) ->
  NoDup ([name_enc n17] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Skip")] Skip_case
       (If Equal [Op Head [x0]; Const (name_enc "Seq")]
            (Let (name_enc n1) (Op Head [Op Tail [x0]])
              (Let (name_enc n2) (Op Head [Op Tail [Op Tail [x0]]]) Seq_case))
       (If Equal [Op Head [x0]; Const (name_enc "Assign")]
            (Let (name_enc n3) (Op Head [Op Tail [x0]])
              (Let (name_enc n4) (Op Head [Op Tail [Op Tail [x0]]]) Assign_case))
       (If Equal [Op Head [x0]; Const (name_enc "Update")]
            (Let (name_enc n5) (Op Head [Op Tail [x0]])
              (Let (name_enc n6) (Op Head [Op Tail [Op Tail [x0]]])
                (Let (name_enc n7) (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Update_case)))
       (If Equal [Op Head [x0]; Const (name_enc "If")]
            (Let (name_enc n8) (Op Head [Op Tail [x0]])
              (Let (name_enc n9) (Op Head [Op Tail [Op Tail [x0]]])
                (Let (name_enc n10) (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) If_case)))
       (If Equal [Op Head [x0]; Const (name_enc "While")]
            (Let (name_enc n11) (Op Head [Op Tail [x0]])
              (Let (name_enc n12) (Op Head [Op Tail [Op Tail [x0]]]) While_case))
       (If Equal [Op Head [x0]; Const (name_enc "Call")]
            (Let (name_enc n13) (Op Head [Op Tail [x0]])
              (Let (name_enc n14) (Op Head [Op Tail [Op Tail [x0]]])
                (Let (name_enc n15) (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Call_case)))
       (If Equal [Op Head [x0]; Const (name_enc "Return")]
            (Let (name_enc n16) (Op Head [Op Tail [x0]]) Return_case)
       (If Equal [Op Head [x0]; Const (name_enc "Alloc")]
            (Let (name_enc n17) (Op Head [Op Tail [x0]])
              (Let (name_enc n18) (Op Head [Op Tail [Op Tail [x0]]]) Alloc_case))
       (If Equal [Op Head [x0]; Const (name_enc "GetChar")]
            (Let (name_enc n19) (Op Head [Op Tail [x0]]) GetChar_case)
       (If Equal [Op Head [x0]; Const (name_enc "PutChar")]
            (Let (name_enc n20) (Op Head [Op Tail [x0]]) PutChar_case)
       (If Equal [Op Head [x0]; Const (name_enc "Abort")] Abort_case
       (Const 0))))))))))))], s) --->

      ([encode (
         match v0 with
         | ImpSyntax.Skip => f_Skip
         | ImpSyntax.Seq c1 c2 => f_Seq c1 c2
         | ImpSyntax.Assign n e => f_Assign n e
         | ImpSyntax.Update a e e' => f_Update a e e'
         | ImpSyntax.If t c1 c2 => f_If t c1 c2
         | ImpSyntax.While t c => f_While t c
         | ImpSyntax.Call n f es => f_Call n f es
         | ImpSyntax.Return e => f_Return e
         | ImpSyntax.Alloc n e => f_Alloc n e
         | ImpSyntax.GetChar n => f_GetChar n
         | ImpSyntax.PutChar e => f_PutChar e
         | ImpSyntax.Abort => f_Abort
         end
       )], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
Qed.

(* app_list *)

Fixpoint encode_app_list {A} `{ra: Refinable A} (l: app_list A): Value :=
  match l with
  | List xs =>
    value_list_of_values [value_name "List"; encode xs]
  | Append xs ys =>
    value_list_of_values [value_name "Append"; encode_app_list xs;
              encode_app_list ys]
  end.

Global Instance Refinable_app_list {A} `{ra: Refinable A}: Refinable (app_list A) :=
  { encode := encode_app_list }.

Theorem auto_app_list_cons_List: forall {A} `{ra: Refinable A} env s x_xs (xs: list A),
  env |-- ([x_xs], s) ---> ([encode xs], s) ->
  env |-- ([Op Cons [Const (name_enc "List");
                     Op Cons [x_xs; Const 0]]], s) --->
        ([encode (List xs)], s).
Proof. Eval_eq. Qed.

Theorem auto_app_list_cons_Append: forall {A} `{ra: Refinable A} env s x_l1 x_l2 (l1 l2: app_list A),
  env |-- ([x_l1], s) ---> ([encode l1], s) ->
  env |-- ([x_l2], s) ---> ([encode l2], s) ->
  env |-- ([Op Cons [Const (name_enc "Append");
                     Op Cons [x_l1; Op Cons [x_l2; Const 0]]]], s) --->
        ([encode (Append l1 l2)], s).
Proof. Eval_eq. Qed.

Theorem auto_app_list_CASE: forall {A} `{ra: Refinable A} {B} `{rb: Refinable B}
  env s x0 (v0: app_list A) List_case Append_case (f_List: list A -> B) (f_Append: app_list A -> app_list A -> B) n1 n2 n3,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | List xs =>
     (FEnv.insert (name_enc n1, Some (encode xs)) env) |-- ([List_case], s) ---> ([encode (f_List xs)], s)
   | Append l1 l2 =>
     (FEnv.insert (name_enc n3, Some (encode l2))
       (FEnv.insert (name_enc n2, Some (encode l1)) env)) |-- ([Append_case], s) ---> ([encode (f_Append l1 l2)], s)
   end) ->

  NoDup ([name_enc n2] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "List")]
            (Let (name_enc n1) (Op Head [Op Tail [x0]]) List_case)
         (If Equal [Op Head [x0]; Const (name_enc "Append")]
            (Let (name_enc n2) (Op Head [Op Tail [x0]])
              (Let (name_enc n3) (Op Head [Op Tail [Op Tail [x0]]]) Append_case))
         (Const 0))], s) --->
        ([encode (
           match v0 with
           | List xs => f_List xs
           | Append l1 l2 => f_Append l1 l2
         end)], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
Qed.

(* func *)

Definition encode_func (f: ImpSyntax.func) : Value :=
  match f with
  | ImpSyntax.Func n params body =>
    value_list_of_values [value_name "Func"; encode n; encode params; encode body]
  end.

Global Instance Refinable_func: Refinable ImpSyntax.func :=
  { encode := encode_func }.

Theorem auto_func_cons_Func: forall env s x_n x_params x_body n params body,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([x_params], s) ---> ([encode params], s) ->
  env |-- ([x_body], s) ---> ([encode body], s) ->
  env |-- ([Op Cons [Const (name_enc "Func");
                     Op Cons [x_n; Op Cons [x_params; Op Cons [x_body; Const 0]]]]], s) --->
        ([encode (ImpSyntax.Func n params body)], s).
Proof. Eval_eq. Qed.

Theorem auto_func_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  Func_case f_Func n1 n2 n3,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | ImpSyntax.Func n params body =>
     (FEnv.insert (name_enc n3, Some (encode body))
       (FEnv.insert (name_enc n2, Some (encode params))
         (FEnv.insert (name_enc n1, Some (encode n)) env))) |-- ([Func_case], s) ---> ([encode (f_Func n params body)], s)
   end) ->

  NoDup ([name_enc n1; name_enc n2] ++ free_vars x0) ->

  env |-- ([Let (name_enc n1) (Op Head [Op Tail [x0]])
            (Let (name_enc n2) (Op Head [Op Tail [Op Tail [x0]]])
              (Let (name_enc n3) (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Func_case))], s) --->
     ([encode (
       match v0 with
       | ImpSyntax.Func n params body => f_Func n params body
       end)], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
Qed.

(* prog *)

Definition encode_prog (p : ImpSyntax.prog) : Value :=
  match p with
  | ImpSyntax.Program funcs =>
    value_list_of_values [value_name "Program"; encode funcs]
  end.

Global Instance Refinable_prog : Refinable ImpSyntax.prog :=
  { encode := encode_prog }.

Theorem auto_prog_cons_Program: forall env s x_funcs funcs,
  env |-- ([x_funcs], s) ---> ([encode funcs], s) ->
  env |-- ([Op Cons [Const (name_enc "Program");
                     Op Cons [x_funcs; Const 0]]], s) --->
        ([encode (ImpSyntax.Program funcs)], s).
Proof. Eval_eq. Qed.

Theorem auto_prog_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  Program_case f_Program n1,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | ImpSyntax.Program funcs =>
     (FEnv.insert (name_enc n1, Some (encode funcs)) env) |-- ([Program_case], s) ---> ([encode (f_Program funcs)], s)
   end) ->

  env |-- ([Let (name_enc n1) (Op Head [Op Tail [x0]]) Program_case], s) --->
     ([encode (
       match v0 with
       | ImpSyntax.Program funcs => f_Program funcs
       end)], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
Qed.

(* reg *)

Global Instance Refinable_reg : Refinable ASMSyntax.reg :=
{ encode reg :=
  match reg with
  | ASMSyntax.RAX => value_name "RAX"
  | ASMSyntax.RDI => value_name "RDI"
  | ASMSyntax.RBX => value_name "RBX"
  | ASMSyntax.RBP => value_name "RBP"
  | ASMSyntax.R12 => value_name "R12"
  | ASMSyntax.R13 => value_name "R13"
  | ASMSyntax.R14 => value_name "R14"
  | ASMSyntax.R15 => value_name "R15"
  | ASMSyntax.RDX => value_name "RDX"
  end }.

Theorem auto_reg_cons_RAX: forall env s,
  env |-- ([Const (name_enc "RAX")], s) ---> ([encode ASMSyntax.RAX], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_cons_RDI: forall env s,
  env |-- ([Const (name_enc "RDI")], s) ---> ([encode ASMSyntax.RDI], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_cons_RBX: forall env s,
  env |-- ([Const (name_enc "RBX")], s) ---> ([encode ASMSyntax.RBX], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_cons_RBP: forall env s,
  env |-- ([Const (name_enc "RBP")], s) ---> ([encode ASMSyntax.RBP], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_cons_R12: forall env s,
  env |-- ([Const (name_enc "R12")], s) ---> ([encode ASMSyntax.R12], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_cons_R13: forall env s,
  env |-- ([Const (name_enc "R13")], s) ---> ([encode ASMSyntax.R13], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_cons_R14: forall env s,
  env |-- ([Const (name_enc "R14")], s) ---> ([encode ASMSyntax.R14], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_cons_R15: forall env s,
  env |-- ([Const (name_enc "R15")], s) ---> ([encode ASMSyntax.R15], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_cons_RDX: forall env s,
  env |-- ([Const (name_enc "RDX")], s) ---> ([encode ASMSyntax.RDX], s).
Proof. Eval_eq. Qed.

Theorem auto_reg_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  RAX_case RDI_case RBX_case RBP_case R12_case R13_case R14_case R15_case RDX_case
  f_RAX f_RDI f_RBX f_RBP f_R12 f_R13 f_R14 f_R15 f_RDX,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | ASMSyntax.RAX => env |-- ([RAX_case], s) ---> ([encode f_RAX], s)
   | ASMSyntax.RDI => env |-- ([RDI_case], s) ---> ([encode f_RDI], s)
   | ASMSyntax.RBX => env |-- ([RBX_case], s) ---> ([encode f_RBX], s)
   | ASMSyntax.RBP => env |-- ([RBP_case], s) ---> ([encode f_RBP], s)
   | ASMSyntax.R12 => env |-- ([R12_case], s) ---> ([encode f_R12], s)
   | ASMSyntax.R13 => env |-- ([R13_case], s) ---> ([encode f_R13], s)
   | ASMSyntax.R14 => env |-- ([R14_case], s) ---> ([encode f_R14], s)
   | ASMSyntax.R15 => env |-- ([R15_case], s) ---> ([encode f_R15], s)
   | ASMSyntax.RDX => env |-- ([RDX_case], s) ---> ([encode f_RDX], s)
   end) ->

  env |-- ([If Equal [x0; Const (name_enc "RAX")] RAX_case
          (If Equal [x0; Const (name_enc "RDI")] RDI_case
          (If Equal [x0; Const (name_enc "RBX")] RBX_case
          (If Equal [x0; Const (name_enc "RBP")] RBP_case
          (If Equal [x0; Const (name_enc "R12")] R12_case
          (If Equal [x0; Const (name_enc "R13")] R13_case
          (If Equal [x0; Const (name_enc "R14")] R14_case
          (If Equal [x0; Const (name_enc "R15")] R15_case
          (If Equal [x0; Const (name_enc "RDX")] RDX_case
          (Const 0)))))))))], s) --->
     ([encode (
       match v0 with
       | ASMSyntax.RAX => f_RAX
       | ASMSyntax.RDI => f_RDI
       | ASMSyntax.RBX => f_RBX
       | ASMSyntax.RBP => f_RBP
       | ASMSyntax.R12 => f_R12
       | ASMSyntax.R13 => f_R13
       | ASMSyntax.R14 => f_R14
       | ASMSyntax.R15 => f_R15
       | ASMSyntax.RDX => f_RDX
       end)], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
Qed.

(* cond *)

Definition encode_cond (c : ASMSyntax.cond) : Value :=
  match c with
  | ASMSyntax.Always =>
    value_list_of_values [value_name "Always"]
  | ASMSyntax.Less r1 r2 =>
    value_list_of_values [value_name "Less"; encode r1; encode r2]
  | ASMSyntax.Equal r1 r2 =>
    value_list_of_values [value_name "Equal"; encode r1; encode r2]
  end.

Global Instance Refinable_cond : Refinable ASMSyntax.cond :=
{ encode := encode_cond }.

Theorem auto_cond_cons_Always: forall env s,
  env |-- ([Op Cons [Const (name_enc "Always"); Const 0]], s) --->
        ([encode ASMSyntax.Always], s).
Proof. Eval_eq. Qed.

Theorem auto_cond_cons_Less: forall env s x_r1 x_r2 r1 r2,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([Op Cons [Const (name_enc "Less");
                     Op Cons [x_r1; Op Cons [x_r2; Const 0]]]], s) --->
        ([encode (ASMSyntax.Less r1 r2)], s).
Proof. Eval_eq. Qed.

Theorem auto_cond_cons_Equal: forall env s x_r1 x_r2 r1 r2,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([Op Cons [Const (name_enc "Equal");
                     Op Cons [x_r1; Op Cons [x_r2; Const 0]]]], s) --->
        ([encode (ASMSyntax.Equal r1 r2)], s).
Proof. Eval_eq. Qed.

Theorem auto_cond_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  Always_case Less_case Equal_case
  f_Always f_Less f_Equal
  n1 n2 n3 n4,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | ASMSyntax.Always => env |-- ([Always_case], s) ---> ([encode f_Always], s)
   | ASMSyntax.Less r1 r2 =>
     (FEnv.insert (name_enc n2, Some (encode r2))
       (FEnv.insert (name_enc n1, Some (encode r1)) env)) |-- ([Less_case], s) ---> ([encode (f_Less r1 r2)], s)
   | ASMSyntax.Equal r1 r2 =>
     (FEnv.insert (name_enc n4, Some (encode r2))
       (FEnv.insert (name_enc n3, Some (encode r1)) env)) |-- ([Equal_case], s) ---> ([encode (f_Equal r1 r2)], s)
   end) ->

  NoDup ([name_enc n1] ++ free_vars x0) ->
  NoDup ([name_enc n3] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Always")] Always_case
          (If Equal [Op Head [x0]; Const (name_enc "Less")]
            (Let (name_enc n1) (Op Head [Op Tail [x0]])
              (Let (name_enc n2) (Op Head [Op Tail [Op Tail [x0]]]) Less_case))
          (If Equal [Op Head [x0]; Const (name_enc "Equal")]
            (Let (name_enc n3) (Op Head [Op Tail [x0]])
              (Let (name_enc n4) (Op Head [Op Tail [Op Tail [x0]]]) Equal_case))
          (Const 0)))], s) --->
     ([encode (
       match v0 with
       | ASMSyntax.Always => f_Always
       | ASMSyntax.Less r1 r2 => f_Less r1 r2
       | ASMSyntax.Equal r1 r2 => f_Equal r1 r2
       end)], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
Qed.

(* instr *)

Definition encode_instr (i : ASMSyntax.instr) : Value :=
  match i with
  | ASMSyntax.Const r w =>
    value_list_of_values [value_name "Const"; encode r; encode w]
  | ASMSyntax.Add r1 r2 =>
    value_list_of_values [value_name "Add"; encode r1; encode r2]
  | ASMSyntax.Sub r1 r2 =>
    value_list_of_values [value_name "Sub"; encode r1; encode r2]
  | ASMSyntax.Div r =>
    value_list_of_values [value_name "Div"; encode r]
  | ASMSyntax.Jump c n =>
    value_list_of_values [value_name "Jump"; encode c; Num (N.of_nat n)]
  | ASMSyntax.Call n =>
    value_list_of_values [value_name "Call"; Num (N.of_nat n)]
  | ASMSyntax.Mov r1 r2 =>
    value_list_of_values [value_name "Mov"; encode r1; encode r2]
  | ASMSyntax.Ret =>
    value_list_of_values [value_name "Ret"]
  | ASMSyntax.Pop r =>
    value_list_of_values [value_name "Pop"; encode r]
  | ASMSyntax.Push r =>
    value_list_of_values [value_name "Push"; encode r]
  | ASMSyntax.Add_RSP n =>
    value_list_of_values [value_name "Add_RSP"; Num (N.of_nat n)]
  | ASMSyntax.Sub_RSP n =>
    value_list_of_values [value_name "Sub_RSP"; Num (N.of_nat n)]
  | ASMSyntax.Load_RSP r n =>
    value_list_of_values [value_name "Load_RSP"; encode r; Num (N.of_nat n)]
  | ASMSyntax.StoreRSP r n =>
    value_list_of_values [value_name "StoreRSP"; encode r; Num (N.of_nat n)]
  | ASMSyntax.Load r1 r2 w =>
    value_list_of_values [value_name "Load"; encode r1; encode r2; encode w]
  | ASMSyntax.Store r1 r2 w =>
    value_list_of_values [value_name "Store"; encode r1; encode r2; encode w]
  | ASMSyntax.GetChar =>
    value_list_of_values [value_name "GetChar"]
  | ASMSyntax.PutChar =>
    value_list_of_values [value_name "PutChar"]
  | ASMSyntax.Exit =>
    value_list_of_values [value_name "Exit"]
  | ASMSyntax.Comment s =>
    value_list_of_values [value_name "Comment"; encode s]
  end.

Global Instance Refinable_instr : Refinable ASMSyntax.instr :=
{ encode := encode_instr }.

Theorem auto_instr_cons_Const: forall env s x_r x_w r w,
  env |-- ([x_r], s) ---> ([encode r], s) ->
  env |-- ([x_w], s) ---> ([encode w], s) ->
  env |-- ([Op Cons [Const (name_enc "Const");
                     Op Cons [x_r; Op Cons [x_w; Const 0]]]], s) --->
        ([encode (ASMSyntax.Const r w)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Add: forall env s x_r1 x_r2 r1 r2,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([Op Cons [Const (name_enc "Add");
                     Op Cons [x_r1; Op Cons [x_r2; Const 0]]]], s) --->
        ([encode (ASMSyntax.Add r1 r2)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Sub: forall env s x_r1 x_r2 r1 r2,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([Op Cons [Const (name_enc "Sub");
                     Op Cons [x_r1; Op Cons [x_r2; Const 0]]]], s) --->
        ([encode (ASMSyntax.Sub r1 r2)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Div: forall env s x_r r,
  env |-- ([x_r], s) ---> ([encode r], s) ->
  env |-- ([Op Cons [Const (name_enc "Div");
                     Op Cons [x_r; Const 0]]], s) --->
        ([encode (ASMSyntax.Div r)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Jump: forall env s x_c x_n c n,
  env |-- ([x_c], s) ---> ([encode c], s) ->
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "Jump");
                     Op Cons [x_c; Op Cons [x_n; Const 0]]]], s) --->
        ([encode (ASMSyntax.Jump c n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Call: forall env s x_n n,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "Call");
                     Op Cons [x_n; Const 0]]], s) --->
        ([encode (ASMSyntax.Call n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Mov: forall env s x_r1 x_r2 r1 r2,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([Op Cons [Const (name_enc "Mov");
                     Op Cons [x_r1; Op Cons [x_r2; Const 0]]]], s) --->
        ([encode (ASMSyntax.Mov r1 r2)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Ret: forall env s,
  env |-- ([Op Cons [Const (name_enc "Ret"); Const 0]], s) --->
        ([encode ASMSyntax.Ret], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Pop: forall env s x_r r,
  env |-- ([x_r], s) ---> ([encode r], s) ->
  env |-- ([Op Cons [Const (name_enc "Pop");
                     Op Cons [x_r; Const 0]]], s) --->
        ([encode (ASMSyntax.Pop r)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Push: forall env s x_r r,
  env |-- ([x_r], s) ---> ([encode r], s) ->
  env |-- ([Op Cons [Const (name_enc "Push");
                     Op Cons [x_r; Const 0]]], s) --->
        ([encode (ASMSyntax.Push r)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Add_RSP: forall env s x_n n,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "Add_RSP");
                     Op Cons [x_n; Const 0]]], s) --->
        ([encode (ASMSyntax.Add_RSP n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Sub_RSP: forall env s x_n n,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "Sub_RSP");
                     Op Cons [x_n; Const 0]]], s) --->
        ([encode (ASMSyntax.Sub_RSP n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Load_RSP: forall env s x_r x_n r n,
  env |-- ([x_r], s) ---> ([encode r], s) ->
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "Load_RSP");
                     Op Cons [x_r; Op Cons [x_n; Const 0]]]], s) --->
        ([encode (ASMSyntax.Load_RSP r n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_StoreRSP: forall env s x_r x_n r n,
  env |-- ([x_r], s) ---> ([encode r], s) ->
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "StoreRSP");
                     Op Cons [x_r; Op Cons [x_n; Const 0]]]], s) --->
        ([encode (ASMSyntax.StoreRSP r n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Load: forall env s x_r1 x_r2 x_w r1 r2 w,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([x_w], s) ---> ([encode w], s) ->
  env |-- ([Op Cons [Const (name_enc "Load");
                     Op Cons [x_r1; Op Cons [x_r2; Op Cons [x_w; Const 0]]]]], s) --->
        ([encode (ASMSyntax.Load r1 r2 w)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Store: forall env s x_r1 x_r2 x_w r1 r2 w,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([x_w], s) ---> ([encode w], s) ->
  env |-- ([Op Cons [Const (name_enc "Store");
                     Op Cons [x_r1; Op Cons [x_r2; Op Cons [x_w; Const 0]]]]], s) --->
        ([encode (ASMSyntax.Store r1 r2 w)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_GetChar: forall env s,
  env |-- ([Op Cons [Const (name_enc "GetChar"); Const 0]], s) --->
        ([encode ASMSyntax.GetChar], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_PutChar: forall env s,
  env |-- ([Op Cons [Const (name_enc "PutChar"); Const 0]], s) --->
        ([encode ASMSyntax.PutChar], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Exit: forall env s,
  env |-- ([Op Cons [Const (name_enc "Exit"); Const 0]], s) --->
        ([encode ASMSyntax.Exit], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Comment: forall env s x_s str,
  env |-- ([x_s], s) ---> ([encode str], s) ->
  env |-- ([Op Cons [Const (name_enc "Comment");
                     Op Cons [x_s; Const 0]]], s) --->
        ([encode (ASMSyntax.Comment str)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  Const_case Add_case Sub_case Div_case Jump_case Call_case
  Mov_case Ret_case Pop_case Push_case Add_RSP_case Sub_RSP_case Load_RSP_case StoreRSP_case
  Load_case Store_case GetChar_case PutChar_case Exit_case Comment_case
  f_Const f_Add f_Sub f_Div f_Jump f_Call f_Mov f_Ret f_Pop f_Push
  f_Add_RSP f_Sub_RSP f_Load_RSP f_StoreRSP f_Load f_Store f_GetChar f_PutChar f_Exit f_Comment
  nConst1 nConst2 nAdd1 nAdd2 nSub1 nSub2 nDiv1
  nJump1 nJump2 nCall1 nMov1 nMov2 nPop1 nPush1 nAdd_RSP1 nSub_RSP1
  nLoad_RSP1 nLoad_RSP2 nStoreRSP1 nStoreRSP2
  nLoad1 nLoad2 nLoad3 nStore1 nStore2 nStore3 nComment1,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | ASMSyntax.Const r w =>
     (FEnv.insert (name_enc nConst2, Some (encode w))
       (FEnv.insert (name_enc nConst1, Some (encode r)) env)) |-- ([Const_case], s) ---> ([encode (f_Const r w)], s)
   | ASMSyntax.Add r1 r2 =>
     (FEnv.insert (name_enc nAdd2, Some (encode r2))
       (FEnv.insert (name_enc nAdd1, Some (encode r1)) env)) |-- ([Add_case], s) ---> ([encode (f_Add r1 r2)], s)
   | ASMSyntax.Sub r1 r2 =>
     (FEnv.insert (name_enc nSub2, Some (encode r2))
       (FEnv.insert (name_enc nSub1, Some (encode r1)) env)) |-- ([Sub_case], s) ---> ([encode (f_Sub r1 r2)], s)
   | ASMSyntax.Div r =>
     (FEnv.insert (name_enc nDiv1, Some (encode r)) env) |-- ([Div_case], s) ---> ([encode (f_Div r)], s)
   | ASMSyntax.Jump c n =>
     (FEnv.insert (name_enc nJump2, Some (encode n))
       (FEnv.insert (name_enc nJump1, Some (encode c)) env)) |-- ([Jump_case], s) ---> ([encode (f_Jump c n)], s)
   | ASMSyntax.Call n =>
     (FEnv.insert (name_enc nCall1, Some (encode n)) env) |-- ([Call_case], s) ---> ([encode (f_Call n)], s)
   | ASMSyntax.Mov r1 r2 =>
     (FEnv.insert (name_enc nMov2, Some (encode r2))
       (FEnv.insert (name_enc nMov1, Some (encode r1)) env)) |-- ([Mov_case], s) ---> ([encode (f_Mov r1 r2)], s)
   | ASMSyntax.Ret => env |-- ([Ret_case], s) ---> ([encode f_Ret], s)
   | ASMSyntax.Pop r =>
     (FEnv.insert (name_enc nPop1, Some (encode r)) env) |-- ([Pop_case], s) ---> ([encode (f_Pop r)], s)
   | ASMSyntax.Push r =>
     (FEnv.insert (name_enc nPush1, Some (encode r)) env) |-- ([Push_case], s) ---> ([encode (f_Push r)], s)
   | ASMSyntax.Add_RSP n =>
     (FEnv.insert (name_enc nAdd_RSP1, Some (encode n)) env) |-- ([Add_RSP_case], s) ---> ([encode (f_Add_RSP n)], s)
   | ASMSyntax.Sub_RSP n =>
     (FEnv.insert (name_enc nSub_RSP1, Some (encode n)) env) |-- ([Sub_RSP_case], s) ---> ([encode (f_Sub_RSP n)], s)
   | ASMSyntax.Load_RSP r n =>
     (FEnv.insert (name_enc nLoad_RSP2, Some (encode n))
       (FEnv.insert (name_enc nLoad_RSP1, Some (encode r)) env)) |-- ([Load_RSP_case], s) ---> ([encode (f_Load_RSP r n)], s)
   | ASMSyntax.StoreRSP r n =>
     (FEnv.insert (name_enc nStoreRSP2, Some (encode n))
       (FEnv.insert (name_enc nStoreRSP1, Some (encode r)) env)) |-- ([StoreRSP_case], s) ---> ([encode (f_StoreRSP r n)], s)
   | ASMSyntax.Load r1 r2 w =>
     (FEnv.insert (name_enc nLoad3, Some (encode w))
       (FEnv.insert (name_enc nLoad2, Some (encode r2))
         (FEnv.insert (name_enc nLoad1, Some (encode r1)) env))) |-- ([Load_case], s) ---> ([encode (f_Load r1 r2 w)], s)
   | ASMSyntax.Store r1 r2 w =>
     (FEnv.insert (name_enc nStore3, Some (encode w))
       (FEnv.insert (name_enc nStore2, Some (encode r2))
         (FEnv.insert (name_enc nStore1, Some (encode r1)) env))) |-- ([Store_case], s) ---> ([encode (f_Store r1 r2 w)], s)
   | ASMSyntax.GetChar => env |-- ([GetChar_case], s) ---> ([encode f_GetChar], s)
   | ASMSyntax.PutChar => env |-- ([PutChar_case], s) ---> ([encode f_PutChar], s)
   | ASMSyntax.Exit => env |-- ([Exit_case], s) ---> ([encode f_Exit], s)
   | ASMSyntax.Comment str =>
     (FEnv.insert (name_enc nComment1, Some (encode str)) env) |-- ([Comment_case], s) ---> ([encode (f_Comment str)], s)
   end) ->

  NoDup ([name_enc nConst1] ++ free_vars x0) ->
  NoDup ([name_enc nAdd1] ++ free_vars x0) ->
  NoDup ([name_enc nSub1] ++ free_vars x0) ->
  NoDup ([name_enc nJump1] ++ free_vars x0) ->
  NoDup ([name_enc nMov1] ++ free_vars x0) ->
  NoDup ([name_enc nLoad_RSP1] ++ free_vars x0) ->
  NoDup ([name_enc nStoreRSP1] ++ free_vars x0) ->
  NoDup ([name_enc nLoad1; name_enc nLoad2] ++ free_vars x0) ->
  NoDup ([name_enc nStore1; name_enc nStore2] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Const")]
            (Let (name_enc nConst1) (Op Head [Op Tail [x0]])
              (Let (name_enc nConst2) (Op Head [Op Tail [Op Tail [x0]]]) Const_case))
       (If Equal [Op Head [x0]; Const (name_enc "Add")]
            (Let (name_enc nAdd1) (Op Head [Op Tail [x0]])
              (Let (name_enc nAdd2) (Op Head [Op Tail [Op Tail [x0]]]) Add_case))
       (If Equal [Op Head [x0]; Const (name_enc "Sub")]
            (Let (name_enc nSub1) (Op Head [Op Tail [x0]])
              (Let (name_enc nSub2) (Op Head [Op Tail [Op Tail [x0]]]) Sub_case))
       (If Equal [Op Head [x0]; Const (name_enc "Div")]
            (Let (name_enc nDiv1) (Op Head [Op Tail [x0]]) Div_case)
       (If Equal [Op Head [x0]; Const (name_enc "Jump")]
            (Let (name_enc nJump1) (Op Head [Op Tail [x0]])
              (Let (name_enc nJump2) (Op Head [Op Tail [Op Tail [x0]]]) Jump_case))
       (If Equal [Op Head [x0]; Const (name_enc "Call")]
            (Let (name_enc nCall1) (Op Head [Op Tail [x0]]) Call_case)
       (If Equal [Op Head [x0]; Const (name_enc "Mov")]
            (Let (name_enc nMov1) (Op Head [Op Tail [x0]])
              (Let (name_enc nMov2) (Op Head [Op Tail [Op Tail [x0]]]) Mov_case))
       (If Equal [Op Head [x0]; Const (name_enc "Ret")] Ret_case
       (If Equal [Op Head [x0]; Const (name_enc "Pop")]
            (Let (name_enc nPop1) (Op Head [Op Tail [x0]]) Pop_case)
       (If Equal [Op Head [x0]; Const (name_enc "Push")]
            (Let (name_enc nPush1) (Op Head [Op Tail [x0]]) Push_case)
       (If Equal [Op Head [x0]; Const (name_enc "Add_RSP")]
            (Let (name_enc nAdd_RSP1) (Op Head [Op Tail [x0]]) Add_RSP_case)
       (If Equal [Op Head [x0]; Const (name_enc "Sub_RSP")]
            (Let (name_enc nSub_RSP1) (Op Head [Op Tail [x0]]) Sub_RSP_case)
       (If Equal [Op Head [x0]; Const (name_enc "Load_RSP")]
            (Let (name_enc nLoad_RSP1) (Op Head [Op Tail [x0]])
              (Let (name_enc nLoad_RSP2) (Op Head [Op Tail [Op Tail [x0]]]) Load_RSP_case))
       (If Equal [Op Head [x0]; Const (name_enc "StoreRSP")]
            (Let (name_enc nStoreRSP1) (Op Head [Op Tail [x0]])
              (Let (name_enc nStoreRSP2) (Op Head [Op Tail [Op Tail [x0]]]) StoreRSP_case))
       (If Equal [Op Head [x0]; Const (name_enc "Load")]
            (Let (name_enc nLoad1) (Op Head [Op Tail [x0]])
              (Let (name_enc nLoad2) (Op Head [Op Tail [Op Tail [x0]]])
                (Let (name_enc nLoad3) (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Load_case)))
       (If Equal [Op Head [x0]; Const (name_enc "Store")]
            (Let (name_enc nStore1) (Op Head [Op Tail [x0]])
              (Let (name_enc nStore2) (Op Head [Op Tail [Op Tail [x0]]])
                (Let (name_enc nStore3) (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Store_case)))
       (If Equal [Op Head [x0]; Const (name_enc "GetChar")] GetChar_case
       (If Equal [Op Head [x0]; Const (name_enc "PutChar")] PutChar_case
       (If Equal [Op Head [x0]; Const (name_enc "Exit")] Exit_case
       (If Equal [Op Head [x0]; Const (name_enc "Comment")]
            (Let (name_enc nComment1) (Op Head [Op Tail [x0]]) Comment_case)
       (Const 0))))))))))))))))))))], s) --->

      ([encode (
         match v0 with
         | ASMSyntax.Const r w => f_Const r w
         | ASMSyntax.Add r1 r2 => f_Add r1 r2
         | ASMSyntax.Sub r1 r2 => f_Sub r1 r2
         | ASMSyntax.Div r => f_Div r
         | ASMSyntax.Jump c n => f_Jump c n
         | ASMSyntax.Call n => f_Call n
         | ASMSyntax.Mov r1 r2 => f_Mov r1 r2
         | ASMSyntax.Ret => f_Ret
         | ASMSyntax.Pop r => f_Pop r
         | ASMSyntax.Push r => f_Push r
         | ASMSyntax.Add_RSP n => f_Add_RSP n
         | ASMSyntax.Sub_RSP n => f_Sub_RSP n
         | ASMSyntax.Load_RSP r n => f_Load_RSP r n
         | ASMSyntax.StoreRSP r n => f_StoreRSP r n
         | ASMSyntax.Load r1 r2 w => f_Load r1 r2 w
         | ASMSyntax.Store r1 r2 w => f_Store r1 r2 w
         | ASMSyntax.GetChar => f_GetChar
         | ASMSyntax.PutChar => f_PutChar
         | ASMSyntax.Exit => f_Exit
         | ASMSyntax.Comment str => f_Comment str
         end
       )], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
Qed.

(* TODO(kπ) might need some more things for the parser *)

(* 
Inductive token :=
  | OPEN
  | CLOSE
  | DOT
  | NUM (n: N)
  | QUOTE (s: N).
*)

Definition encode_token (t: token) : Value :=
  match t with
  | OPEN =>
    value_list_of_values [value_name "OPEN"]
  | CLOSE =>
    value_list_of_values [value_name "CLOSE"]
  | DOT =>
    value_list_of_values [value_name "DOT"]
  | NUM n =>
    value_list_of_values [value_name "NUM"; Num n]
  | QUOTE s =>
    value_list_of_values [value_name "QUOTE"; Num s]
  end.

Global Instance Refinable_token : Refinable token :=
  { encode := encode_token }.

Theorem auto_token_cons_OPEN: forall env s,
  env |-- ([Op Cons [Const (name_enc "OPEN"); Const 0]], s) --->
        ([encode OPEN], s).
Proof. Eval_eq. Qed.

Theorem auto_token_cons_CLOSE: forall env s,
  env |-- ([Op Cons [Const (name_enc "CLOSE"); Const 0]], s) --->
        ([encode CLOSE], s).
Proof. Eval_eq. Qed.

Theorem auto_token_cons_DOT: forall env s,
  env |-- ([Op Cons [Const (name_enc "DOT"); Const 0]], s) --->
        ([encode DOT], s).
Proof. Eval_eq. Qed.

Theorem auto_token_cons_NUM: forall env s x_n n,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "NUM");
                      Op Cons [x_n; Const 0]]], s) --->
        ([encode (NUM n)], s).
Proof. Eval_eq. Qed.

Theorem auto_token_cons_QUOTE: forall env s x_s str,
  env |-- ([x_s], s) ---> ([encode str], s) ->
  env |-- ([Op Cons [Const (name_enc "QUOTE");
                      Op Cons [x_s; Const 0]]], s) --->
        ([encode (QUOTE str)], s).
Proof. Eval_eq. Qed.

Theorem auto_token_CASE: forall {A} `{ra: Refinable A} env s x0 v0
  OPEN_case CLOSE_case DOT_case NUM_case QUOTE_case
  f_OPEN f_CLOSE f_DOT f_NUM f_QUOTE
  n1 n2,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | OPEN => env |-- ([OPEN_case], s) ---> ([encode f_OPEN], s)
   | CLOSE => env |-- ([CLOSE_case], s) ---> ([encode f_CLOSE], s)
   | DOT => env |-- ([DOT_case], s) ---> ([encode f_DOT], s)
   | NUM n =>
     (FEnv.insert (name_enc n1, Some (encode n)) env) |-- ([NUM_case], s) ---> ([encode (f_NUM n)], s)
   | QUOTE str =>
     (FEnv.insert (name_enc n2, Some (encode str)) env) |-- ([QUOTE_case], s) ---> ([encode (f_QUOTE str)], s)
   end) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "OPEN")] OPEN_case
          (If Equal [Op Head [x0]; Const (name_enc "CLOSE")] CLOSE_case
          (If Equal [Op Head [x0]; Const (name_enc "DOT")] DOT_case
          (If Equal [Op Head [x0]; Const (name_enc "NUM")]
            (Let (name_enc n1) (Op Head [Op Tail [x0]]) NUM_case)
          (If Equal [Op Head [x0]; Const (name_enc "QUOTE")]
            (Let (name_enc n2) (Op Head [Op Tail [x0]]) QUOTE_case)
          (Const 0)))))], s) --->
     ([encode (
       match v0 with
       | OPEN => f_OPEN
       | CLOSE => f_CLOSE
       | DOT => f_DOT
       | NUM n => f_NUM n
       | QUOTE str => f_QUOTE str
       end)], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
Qed.

(* FunValues.Value *)

Fixpoint encode_value (v: FunValues.Value) : Value :=
  match v with
  | FunValues.Pair v1 v2 =>
    value_list_of_values [value_name "Pair"; encode_value v1; encode_value v2]
  | FunValues.Num n =>
    value_list_of_values [value_name "Num"; Num n]
  end.

Global Instance Refinable_value : Refinable FunValues.Value :=
  { encode := encode_value }.

Theorem auto_value_cons_Pair: forall env s x_v1 x_v2 v1 v2,
  env |-- ([x_v1], s) ---> ([encode v1], s) ->
  env |-- ([x_v2], s) ---> ([encode v2], s) ->
  env |-- ([Op Cons [Const (name_enc "Pair");
                     Op Cons [x_v1; Op Cons [x_v2; Const 0]]]], s) --->
        ([encode (FunValues.Pair v1 v2)], s).
Proof. Eval_eq. Qed.

Theorem auto_value_cons_Num: forall env s x_n n,
  env |-- ([x_n], s) ---> ([encode n], s) ->
  env |-- ([Op Cons [Const (name_enc "Num");
                     Op Cons [x_n; Const 0]]], s) --->
        ([encode (FunValues.Num n)], s).
Proof. Eval_eq. Qed.

Theorem auto_value_case: forall {A} `{ra: Refinable A} env s x0 v0
  Pair_case Num_case
  f_Pair f_Num
  n1 n2 n3,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (match v0 with
   | FunValues.Pair v1 v2 =>
     (FEnv.insert (name_enc n2, Some (encode v2))
       (FEnv.insert (name_enc n1, Some (encode v1)) env)) |-- ([Pair_case], s) ---> ([encode (f_Pair v1 v2)], s)
   | FunValues.Num n =>
     (FEnv.insert (name_enc n3, Some (encode n)) env) |-- ([Num_case], s) ---> ([encode (f_Num n)], s)
   end) ->

  NoDup ([name_enc n1] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Pair")]
            (Let (name_enc n1) (Op Head [Op Tail [x0]])
              (Let (name_enc n2) (Op Head [Op Tail [Op Tail [x0]]]) Pair_case))
       (If Equal [Op Head [x0]; Const (name_enc "Num")]
            (Let (name_enc n3) (Op Head [Op Tail [x0]]) Num_case)
       (Const 0))], s) --->

      ([encode (
         match v0 with
         | FunValues.Pair v1 v2 => f_Pair v1 v2
         | FunValues.Num n => f_Num n
         end
       )], s).
Proof.
  Opaque name_enc.
  intros.
  destruct v0 eqn:?.
  all: simpl in *; unfold value_list_of_values in *; simpl in *; subst.
  all: Eval_eq.
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
Qed.
