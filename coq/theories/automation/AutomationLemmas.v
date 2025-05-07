Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.functional.FunProperties.
Require Import impboot.functional.FunValues.
Require impboot.imperative.ImpSyntax.
From impboot Require Import utils.Core utils.Env.
From coqutil Require Import dlet.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.
Require Import impboot.utils.AppList.

Create HintDb automation.

Theorem trans_app: forall n params vs body s s1 v,
  let env := make_env params vs FEnv.empty in
    (env |-- ([body], s) ---> ([v], s1)) ->
    List.length params = List.length vs ->
    lookup_fun (name_enc n) s.(funs) = Some (params,body) ->
    eval_app (name_enc n) vs s (v,s1).
Proof.
  intros; eapply App_intro; eauto.
  unfold env_and_body; simpl.
  rewrite H1.
  rewrite <- Nat.eqb_eq in H0; rewrite H0.
  reflexivity.
Qed.

Definition summm : nat -> nat :=
  (fix summm n0 := nat_CASE n0 0 (fun n1 => n0 + summm n1)).
Print summm.

Fixpoint summmmmm (m : nat) (n : nat) : nat :=
  nat_CASE n 0 (fun n1 => n1 + summmmmm (m + 1) n1).
Print summmmmm.

Theorem trans_ap_fix_nat: forall {B} `{Refinable B} n params vs body s s1 fix_v arg,
  let env := make_env params vs FEnv.empty in
    (env |-- ([body], s) ---> ([encode fix_v], s1)) ->
    List.length params = List.length vs ->
    lookup_fun (name_enc n) s.(funs) = Some (params,body) ->
    eval_app (name_enc n) vs s (encode ((fix fix_name (fix_arg : nat) : B := fix_v) arg), s1).
Proof.
  intros; eapply App_intro; eauto.

Admitted.

Theorem trans_Call : forall env xs s1 s2 s3 fname vs v,
  env |-- (xs, s1) ---> (vs, s2) ->
  eval_app fname vs s2 (v, s3) ->
  env |-- ([Call fname xs], s1) ---> ([v], s3).
Proof.
  intros.
  inversion H0; subst.
  eapply Eval_Call with (vs := vs) (s2 := s2); eauto.
Qed.

Theorem trans_Var : forall {A} `{Refinable A} env s n (v : A),
  FEnv.lookup env (name_enc n) = Some (encode v) ->
  env |-- ([Var (name_enc n)], s) ---> ([encode v], s).
Proof.
  intros.
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

(* removed b1 to test if that works better with the automation *)
Theorem auto_let : forall {A B} `{ra : Refinable A} `{rb : Refinable B}
    env x1 y1 s1 s2 s3 v1 let_n f,
  env |-- ([x1], s1) ---> ([ra.(encode) v1], s2) ->
  (FEnv.insert ((name_enc let_n), Some (ra.(encode) v1)) env) |-- ([y1], s2) --->
      ([rb.(encode) (f v1)], s3) ->
  env |-- ([Let (name_enc let_n) x1 y1], s1) ---> ([rb.(encode) (dlet v1 f)], s3).
Proof.
  intros.
  (* destruct H1. *)
  eapply Eval_Let; eauto.
Qed.
Hint Resolve auto_let : automation.

Theorem auto_otherwise : forall {A} `{ra : Refinable A}
    env s x1 v1,
  env |-- ([x1], s) ---> ([encode v1], s) ->
  env |-- ([If Less [Const 0; Const 1] x1 (Const 0)], s) ---> ([encode (value_otherwise v1)], s).
Proof.
  intros.
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

Theorem last_bool_if : forall env s x_b x_t x_f (b : bool) t f,
  env |-- ([x_b], s) ---> ([encode b], s) ->
  env |-- ([x_t], s) ---> ([t], s) ->
  env |-- ([x_f], s) ---> ([f], s) ->
  env |-- ([If Equal [x_b; Const 1] x_t x_f], s) ---> ([if b then t else f], s).
Proof.
  intros env s x_b x_t x_f b t f H1 H2 H3.
  destruct (encode b) eqn:Hb; simpl in *.
  all: unfold encode in *; simpl in *; destruct b; inversion Hb; subst.
  all: Eval_eq.
Qed.
Hint Resolve last_bool_if : automation.

(* num *)

Theorem auto_num_const_zero : forall env s,
  env |-- ([Const 0], s) ---> ([Num 0], s).
Proof.
  intros. apply Eval_Const.
Qed.
(* Hint Resolve auto_num_const_zero : automation. *)

Theorem auto_num_const : forall env s n,
  env |-- ([Const n], s) ---> ([encode n], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_num_const : automation.

Theorem auto_num_add : forall env s0 s1 s2 x1 x2 n1 n2,
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  env |-- ([Op FunSyntax.Add [x1; x2]], s0) ---> ([encode (n1 + n2)], s2).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_num_add : automation.

Theorem auto_num_sub : forall env s0 s1 s2 x1 x2 n1 n2,
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  env |-- ([Op FunSyntax.Sub [x1; x2]], s0) ---> ([encode (n1 - n2)], s2).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_num_sub : automation.

Theorem auto_num_div : forall env s0 s1 s2 x1 x2 n1 n2,
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  (n2 <> 0 -> env |-- ([Op FunSyntax.Div [x1; x2]], s0) ---> ([encode (n1 / n2)], s2)).
Proof.
  intros.
  repeat econstructor; eauto.
  rewrite <- Nat.eqb_neq in *; simpl; rewrite H1; reflexivity.
Qed.
Hint Resolve auto_num_div : automation.

Theorem auto_num_if_eq : forall {A} `{Refinable A}
    env s x1 x2 y z n1 n2 (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  env |-- ([y], s) ---> ([encode t], s) ->
  env |-- ([z], s) ---> ([encode f], s) ->
  env |-- ([If Equal [x1; x2] y z], s) ---> ([encode (if n1 =? n2 then t else f)], s).
Proof.
  intros.
  destruct (n1 =? n2) eqn:Heq.
  all: repeat econstructor; eauto.
  all: match goal with
  | [ |- take_branch _ _ _ = _ ] => unfold take_branch, return_; reflexivity
  | [ |- (_ |-- (_, _) ---> (_, _)) ] => rewrite Heq; assumption
  end.
Qed.
Hint Resolve auto_num_if_eq : automation.

Theorem auto_num_if_less : forall {A} `{Refinable A}
  env s x1 x2 y z n1 n2 (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  env |-- ([y], s) ---> ([encode t], s) ->
  env |-- ([z], s) ---> ([encode f], s) ->
  env |-- ([If Less [x1; x2] y z], s) ---> ([encode (if n1 <? n2 then t else f)], s).
Proof.
  intros.
  destruct (n1 <? n2) eqn:Heq.
  all: repeat econstructor; eauto.
  all: match goal with
  | [ |- take_branch _ _ _ = _ ] => unfold take_branch, return_; reflexivity
  | [ |- (_ |-- (_, _) ---> (_, _)) ] => rewrite Heq; assumption
  end.
Qed.
Hint Resolve auto_num_if_less : automation.

Theorem auto_nat_case : forall {A} `{Refinable A}
  env s x0 x1 x2 n (v0 : nat) (v1 : A) v2,
  env |-- ([x0], s) ---> ([encode v0], s) ->
  env |-- ([x1], s) ---> ([encode v1], s) ->
  ((FEnv.insert (name_enc n, Some (encode (v0 - 1))) env) |-- ([x2], s) --->
      ([encode (v2 (v0 - 1))], s)) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n)
        (Op Sub [x0; Const 1]) x2)], s) --->
     ([encode (nat_CASE v0 v1 v2)], s).
Proof.
  intros.
  destruct v0 eqn:?.
  1: Eval_eq.
  simpl in *.
  subst.
  Eval_eq.
  replace (n0 - 0) with n0 in *; eauto.
  lia.
Qed.

(* list *)

Theorem auto_list_nil : forall env s,
  env |-- ([Const 0], s) ---> ([encode []], s).
Proof.
  intros; econstructor.
Qed.
Hint Resolve auto_list_nil : automation.

Theorem auto_list_cons : forall {A} `{Refinable A} env s x1 x2 x xs,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x2], s) ---> ([encode xs], s) ->
  env |-- ([Op Cons [x1; x2]], s) ---> ([encode (x :: xs)], s).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_list_cons : automation.

Theorem auto_list_case : forall {A B} `{ra : Refinable A} `{rb : Refinable B}
  env s x0 x1 x2 n1 n2 (v0 : list A) v1 v2 default_A,
  env |-- ([x0], s) ---> ([encode v0], s) ->
  env |-- ([x1], s) ---> ([rb.(encode) v1], s) ->
  ((FEnv.insert (name_enc n2, Some (encode (tl v0)))
    (FEnv.insert (name_enc n1, Some (ra.(encode) (hd default_A v0))) env)) |-- ([x2], s) --->
      ([rb.(encode) (v2 (hd default_A v0) (tl v0))], s)) ->
  NoDup ([name_enc n1] ++ free_vars x0) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n1) (Op Head [x0])
        (Let (name_enc n2) (Op Tail [x0]) x2))], s) --->
     ([rb.(encode) (list_CASE v0 v1 v2)], s).
Proof.
  intros.
  destruct v0 eqn:?.
  1: Eval_eq.
  simpl in *.
  subst.
  rewrite NoDup_cons_iff in *; destruct H2.
  Eval_eq.
  + rewrite remove_env_update; eauto.
  + simpl; reflexivity.
Qed.
Hint Resolve auto_list_case : automation.

Print fold_left.
Print list_CASE.
Print fold_right.

(* Fixpoint fold_right {A B} (f : B -> A -> A) (acc : A) (l : list B) : A :=
  match l with
  | nil => acc
  | x :: xs =>
    f x (fold_right f acc xs)
  end. *)

Definition suma (l : list nat) : nat :=
  fold_right (fun h acc => h + acc) 0 l.

Fixpoint suma1 (l : list nat) : nat :=
  match l with
  | nil => 0
  | x :: xs =>
    x + (suma1 xs)
  end.

Notation Var_enc n := (Var (name_enc n)).
Definition suma_exp (l : list nat) : dec :=
  Defun (name_enc "suma") [name_enc "l"] (
    If Equal [Var_enc "l"; Const 0]
      (Const 0)
      (
        Let (name_enc "h") (Op Head [Var_enc "l"])
          (Let (name_enc "t") (Op Tail [Var_enc "l"])
            (Let (name_enc "acc") (Call (name_enc "suma") [Var_enc "t"])
              (Op FunSyntax.Add [Var_enc "h"; Var_enc "acc"])
            )
          )
      )
  ).

(* TODO(kπ):
- param order is wrong (also wrong vs the implementation (fold_right))
- this whole thing is half way defined
*)
(* IMPORTANT: Assumption: first argument of the function is the list *)
Theorem auto_app_fold_right : forall {A B} `{ra : Refinable A} `{rb : Refinable B}
  params_enc nl_enc paramsRest_enc n (s s1 : state) x0 x1 x2 body nh nacc v vs (v0 : list A) v1 v2,
  let env := make_env params_enc vs FEnv.empty in
  (* env |-- ([body], s) ---> (, s) -> *)
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (* Do we need to realate x0 to nl_enc? *)
  env |-- ([x1], s) ---> ([rb.(encode) v1], s1) ->
  (forall xh xt acc, v0 = xh :: xt ->
    acc = fold_right v2 acc xt ->
    (FEnv.insert (name_enc nacc, Some (encode acc))
      (FEnv.insert (name_enc nh, Some (ra.(encode) xh)) env)) |-- ([x2], s) --->
      ([rb.(encode) (v2 xh acc)], s1)
  ) ->
  (* NoDup? *)
  List.length params_enc = List.length vs ->
  params_enc = nl_enc :: paramsRest_enc ->
  lookup_fun (name_enc n) (funs s) = Some (params_enc, body) ->
  body = (If Equal [x0; Const 0] x1
    (Let (name_enc nh) (Op Head [x0])
      (Let (name_enc nacc) (Call (name_enc n) ((Op Tail [x0]) :: List.map Var paramsRest_enc))
        x2))) ->
  (* after unfolding *)
  v = fold_right v2 v1 v0 ->
  eval_app (name_enc n) vs s (encode v, s1).
Proof.
  destruct v0 eqn:?.
  - intros; eapply App_intro; eauto.
    1: unfold env_and_body; simpl; rewrite H4.
    1: rewrite H2; rewrite Nat.eqb_refl; reflexivity.
    subst; simpl.
    destruct vs eqn:Heqvs; try inversion H2; subst.
    Eval_eq.
  - intros; eapply App_intro; eauto.
    1: unfold env_and_body; simpl; rewrite H4.
    1: rewrite H2; rewrite Nat.eqb_refl; reflexivity.
    subst; simpl.
    destruct vs eqn:Heqvs; try inversion H2; subst.
    eapply Eval_If; eauto; try unfold make_branch.
    1: eapply Eval_Cons; eauto.
    1: eapply Eval_Const; eauto.
    1: unfold take_branch, return_; simpl; eauto.
    simpl.
    eapply Eval_Let; try eapply Eval_Op; simpl; eauto.
    1: unfold return_; simpl; eauto.
    eapply Eval_Let.
    1: eapply Eval_Call; eauto.
    2: unfold env_and_body; rewrite H4.
    2: admit.
    (* 1: destruct paramsRest_enc eqn:?; simpl. *)
    (* 1: Eval_eq; eauto. *)
    1: admit.
    subst env; simpl in H1.
    (* eapply H1.
    Eval_eq; simpl in *.
    + admit.
    + unfold env_and_body.
      rewrite H4. *)

Abort.


(* option *)

Theorem auto_option_none : forall {A} `{Refinable A} env s,
  env |-- ([Const 0], s) ---> ([encode None], s).
Proof.
  intros; econstructor.
Qed.
Hint Resolve auto_option_none : automation.

Theorem auto_option_some : forall {A} `{Refinable A} env s x1 x,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([Op Cons [x1; Const 0]], s) ---> ([encode (Some x)], s).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_option_some : automation.

Theorem auto_option_case : forall {A B} `{Refinable A} `{rb : Refinable B} (v0 : option A) env s x0 x1 x2 n v1 v2,
  env |-- ([x0],s) ---> ([encode v0],s) ->
  env |-- ([x1],s) ---> ([rb.(encode) v1],s) ->
  (forall y1,
  (FEnv.insert (name_enc n, Some (encode y1)) env) |-- ([x2],s) ---> ([rb.(encode) (v2 y1)],s)) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n) (Op Head [x0]) x2)], s) --->
     ([rb.(encode) (option_CASE v0 v1 v2)], s).
Proof.
  intros.
  destruct v0 as [y1|]; simpl in *.
  - Eval_eq.
  - Eval_eq.
Qed.
Hint Resolve auto_option_case : automation.

(* pair *)

Theorem auto_pair_fst : forall {A B} `{Refinable A} `{Refinable B} env s x1 (x : A * B),
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([Op Head [x1]], s) ---> ([encode (fst x)], s).
Proof.
  intros.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_pair_fst : automation.

Theorem auto_pair_snd : forall {A B} `{Refinable A} `{Refinable B} env s x1 (x : A * B),
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([Op Tail [x1]], s) ---> ([encode (snd x)], s).
Proof.
  intros.
  destruct x; simpl in *.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_pair_fst : automation.

Theorem auto_pair_cons : forall {A B} `{Refinable A} `{Refinable B} env s x1 x2 (x : A) (y : B),
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x2], s) ---> ([encode y], s) ->
  env |-- ([Op Cons [x1; x2]], s) ---> ([encode (x, y)], s).
Proof.
  intros.
  repeat econstructor; eauto.
Qed.
Hint Resolve auto_pair_cons : automation.

Theorem auto_pair_case : forall {A1 A2 B} `{ra1 : Refinable A1} `{ra2 : Refinable A2} `{rb : Refinable B}
  env s x0 x1 n1 n2 (v0 : A1 * A2) v1,
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (forall y1 y2,
    (FEnv.insert (name_enc n2, Some (ra2.(encode) y2))
    (FEnv.insert (name_enc n1, Some (ra1.(encode) y1)) env)) |-- ([x1], s) --->
    ([rb.(encode) (v1 y1 y2)], s)) ->
  NoDup ([name_enc n1] ++ [name_enc n2] ++ free_vars x0) ->
  env |-- ([Let (name_enc n1) (Op Head [x0])
      (Let (name_enc n2) (Op Tail [x0]) x1)], s) --->
  ([rb.(encode) (pair_CASE v0 v1)], s).
Proof.
  intros.
  destruct v0 as [y1 y2]; simpl in *.
  Eval_eq.
  - repeat rewrite NoDup_cons_iff in *; destruct H1; destruct H2.
  rewrite not_in_cons in *; destruct H1.
  rewrite remove_env_update; eauto.
  - simpl; reflexivity.
Qed.
Hint Resolve auto_pair_case : automation.

(* char *)

Theorem auto_char_CHR : forall env s x1 x,
  env |-- ([x1], s) ---> ([Num x], s) ->
  x < 256 ->
  env |-- ([x1], s) ---> ([encode (ascii_of_nat x)], s).
Proof.
  intros.
  simpl.
  rewrite nat_ascii_embedding; auto.
Qed.
Hint Resolve auto_char_CHR : automation.

Theorem auto_char_ORD : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x1], s) ---> ([Num (nat_of_ascii x)], s).
Proof.
  intros.
  simpl in *.
  assumption.
Qed.
Hint Resolve auto_char_ORD : automation.

(* word *)

Definition value_word {n} (w : word n) : Value :=
  Num (Z.to_nat (word.unsigned w)).

Theorem auto_word4_n2w : forall env s x1 x,
  env |-- ([x1], s) ---> ([Num x], s) ->
  x < 16 ->
  env |-- ([x1], s) ---> ([value_word ((word.of_Z (Z.of_nat x)) : word4)], s).
Proof.
  intros.
  unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  assert ((Z.to_nat (Z.of_nat x mod 16)) = x).
  2: { rewrite H1. eapply H. }
  rewrite Z.mod_small; lia.
Qed.
Hint Resolve auto_word4_n2w : automation.

Theorem auto_word64_n2w : forall env s x1 x,
  env |-- ([x1], s) ---> ([Num x], s) ->
  x < 2 ^ 64 ->
  env |-- ([x1], s) ---> ([value_word ((word.of_Z (Z.of_nat x)) : word64)], s).
Proof.
  intros.
  unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  assert ((Z.to_nat (Z.of_nat x mod (2 ^ 64))) = x).
  2: { cbn in H1. rewrite H1. eapply H. }
  rewrite Z.mod_small; try lia.
  apply inj_lt in H0.
  split; try lia.
  rewrite inj_pow in H0.
  simpl  Z.of_nat in H0.
  assumption.
Qed.
Hint Resolve auto_word64_n2w : automation.

Theorem auto_word4_w2n : forall env s x1 x,
  env |-- ([x1], s) ---> ([value_word (x : word4)], s) ->
  env |-- ([x1], s) ---> ([Num (Z.to_nat (word.unsigned x))], s).
Proof.
  intros.
  unfold value_word in *.
  assumption.
Qed.
Hint Resolve auto_word4_w2n : automation.

Theorem auto_word64_w2n : forall env s x1 x,
  env |-- ([x1], s) ---> ([value_word (x : word64)], s) ->
  env |-- ([x1], s) ---> ([Num (Z.to_nat (word.unsigned x))], s).
Proof.
  intros.
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

(* TODO(kπ) lemmas *)

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

(* TODO(kπ) lemmas *)

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

(* TODO(kπ) lemmas *)

(* list *)

(* TODO(kπ) lemmas *)

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

(* TODO(kπ) lemmas *)

(* TODO(kπ) continue *)


