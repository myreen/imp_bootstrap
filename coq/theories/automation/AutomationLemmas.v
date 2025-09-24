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

Theorem trans_app: forall n params vs body s s1 v,
  let env := make_env params vs FEnv.empty in
    (env |-- ([body], s) ---> ([v], s1)) ->
    List.length params = List.length vs ->
    lookup_fun (name_enc n) s.(funs) = Some (params,body) ->
    eval_app (name_enc n) vs s (v,s1).
Proof.
  intros; eapply App_intro; eauto.
  unfold env_and_body; simpl.
  pat `lookup_fun _ _ = _` at rewrite pat.
  pat `Datatypes.length _ = _` at rewrite <- Nat.eqb_eq in pat; rewrite pat.
  reflexivity.
Qed.

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

Theorem trans_cons : forall env x xs v vs s s1 s2,
  env |-- ([x], s) ---> ([v], s1) ->
  env |-- (xs, s1) ---> (vs, s2) ->
  env |-- (x :: xs, s) ---> (v :: vs, s2).
Proof.
  intros env x xs v vs s s1 s2 H1 H2.
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

Theorem auto_let : forall {A B} `{ra : Refinable A} `{rb : Refinable B} env x1 y1 s1 s2 s3 v1 let_n f,
  env |-- ([x1], s1) ---> ([ra.(encode) v1], s2) ->
  (FEnv.insert ((name_enc let_n), Some (ra.(encode) v1)) env) |-- ([y1], s2) --->
      ([rb.(encode) (f v1)], s3) ->
  env |-- ([Let (name_enc let_n) x1 y1], s1) ---> ([rb.(encode) (dlet v1 f)], s3).
Proof.
  intros.
  eapply Eval_Let; eauto.
Qed.
Hint Resolve auto_let : automation.

Theorem auto_otherwise : forall {A} `{ra : Refinable A} env s x1 v1,
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

Theorem last_bool_if : forall {A} `{Refinable A} env s x_b x_t x_f (b : bool) (t f : A),
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
Hint Resolve last_bool_if : automation.

(* num *)

Theorem auto_nat_const_zero : forall env s,
  env |-- ([Const 0], s) ---> ([Num 0], s).
Proof.
  intros. apply Eval_Const.
Qed.
(* Hint Resolve auto_nat_const_zero : automation. *)

Theorem auto_nat_const : forall env s (n: nat),
  env |-- ([Const (N.of_nat n)], s) ---> ([encode n], s).
Proof.
  intros. apply Eval_Const.
Qed.
Hint Resolve auto_nat_const : automation.

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
Hint Resolve auto_nat_add : automation.

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
Hint Resolve auto_nat_sub : automation.

Theorem auto_nat_div : forall env s0 s1 s2 x1 x2 (n1 n2: nat),
  env |-- ([x1], s0) ---> ([encode n1], s1) ->
  env |-- ([x2], s1) ---> ([encode n2], s2) ->
  ((N.of_nat n2) <> 0 -> env |-- ([Op FunSyntax.Div [x1; x2]], s0) ---> ([encode (n1 / n2)%nat], s2)).
Proof.
  intros.
  repeat econstructor; eauto; simpl.
  rewrite <- N.eqb_neq in *; simpl.
  pat `_ = false` at rewrite pat.
  rewrite Nnat.Nat2N.inj_div.
  reflexivity.
Qed.
Hint Resolve auto_nat_div : automation.

Theorem auto_nat_if_eq : forall {A} `{Refinable A} env s x1 x2 y z (n1 n2: nat) (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  env |-- ([y], s) ---> ([encode t], s) ->
  env |-- ([z], s) ---> ([encode f], s) ->
  env |-- ([If Equal [x1; x2] y z], s) ---> ([encode (if (N.of_nat n1) =? (N.of_nat n2) then t else f)], s).
Proof.
  intros.
  destruct (_ =? _) eqn:Heq.
  all: repeat econstructor; eauto.
  all: match goal with
  | [ |- take_branch _ _ _ = _ ] => unfold take_branch, return_; reflexivity
  | [ |- (_ |-- (_, _) ---> (_, _)) ] => rewrite Heq; assumption
  end.
Qed.
Hint Resolve auto_nat_if_eq : automation.

Theorem auto_nat_if_less : forall {A} `{Refinable A} env s x1 x2 y z (n1 n2: nat) (t f : A),
  env |-- ([x1], s) ---> ([encode n1], s) ->
  env |-- ([x2], s) ---> ([encode n2], s) ->
  env |-- ([y], s) ---> ([encode t], s) ->
  env |-- ([z], s) ---> ([encode f], s) ->
  env |-- ([If Less [x1; x2] y z], s) ---> ([encode (if (N.of_nat n1) <? (N.of_nat n2) then t else f)], s).
Proof.
  intros.
  destruct (_ <? _) eqn:Heq.
  all: repeat econstructor; eauto.
  all: match goal with
  | [ |- take_branch _ _ _ = _ ] => unfold take_branch, return_; reflexivity
  | [ |- (_ |-- (_, _) ---> (_, _)) ] => rewrite Heq; assumption
  end.
Qed.
Hint Resolve auto_nat_if_less : automation.

(* Consider making the "compilable" premises as one big match. e.g. *)
(*
(match v0 with
| 0 => env |-- ([x1], s) ---> ([encode v1], s)
| S n' =>
  (FEnv.insert (name_enc n, Some (encode n')) env) |-- ([x2], s) --->
    ([encode (v2 n')], s)
end) ->
*)
Theorem auto_nat_case : forall {A} `{Refinable A} env s x0 x1 x2 n (v0: nat) (v1: A) v2,
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (* env |-- ([x1], s) ---> ([encode v1], s) ->
  (forall n', S n' = v0 ->
    (FEnv.insert (name_enc n, Some (encode n')) env) |-- ([x2], s) --->
      ([encode (v2 n')], s)) -> *)
  (match v0 with
  | 0%nat => env |-- ([x1], s) ---> ([encode v1], s)
  | S n' =>
    (FEnv.insert (name_enc n, Some (encode n')) env) |-- ([x2], s) --->
      ([encode (v2 n')], s)
  end) ->
  env |-- ([If Equal [x0; Const 0] x1
      (Let (name_enc n)
        (Op Sub [x0; Const 1]) x2)], s) --->
     ([encode (
        match v0 with
        | 0%nat => v1
        | S n => v2 n
        end)], s).
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
Hint Resolve auto_nat_case : automation.

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

Theorem auto_list_case : forall {A B} `{ra : Refinable A} `{rb : Refinable B} env s x0 x1 x2 n1 n2 (v0 : list A) v1 v2,
  env |-- ([x0], s) ---> ([encode v0], s) ->
  (match v0 with
   | nil =>
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
Hint Resolve auto_list_case : automation.

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
  (forall inner, Some inner = v0 ->
  (FEnv.insert (name_enc n, Some (encode inner)) env) |-- ([x2],s) ---> ([rb.(encode) (v2 inner)],s)) ->
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
  (forall y1 y2, (y1, y2) = v0 ->
    (FEnv.insert (name_enc n2, Some (ra2.(encode) y2))
      (FEnv.insert (name_enc n1, Some (ra1.(encode) y1)) env)) |-- ([x1], s) --->
        ([rb.(encode) (v1 y1 y2)], s)) ->
  NoDup ([name_enc n1] ++ [name_enc n2] ++ free_vars x0) ->
  env |-- ([Let (name_enc n1) (Op Head [x0])
      (Let (name_enc n2) (Op Tail [x0]) x1)], s) --->
  ([rb.(encode) (match v0 with
                 | (y1, y2) => v1 y1 y2
                 end)], s).
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
  (x < 256)%N ->
  env |-- ([x1], s) ---> ([encode (ascii_of_N x)], s).
Proof.
  intros.
  simpl.
  rewrite N_ascii_embedding; auto.
Qed.
Hint Resolve auto_char_CHR : automation.

Theorem auto_char_ORD : forall env s x1 x,
  env |-- ([x1], s) ---> ([encode x], s) ->
  env |-- ([x1], s) ---> ([Num (N_of_ascii x)], s).
Proof.
  intros.
  simpl in *.
  assumption.
Qed.
Hint Resolve auto_char_ORD : automation.

(* word *)

Definition value_word {n} `{word_inst : word n} (w : @word.rep n word_inst) : Value :=
  Num (Z.to_N (word.unsigned w)).

Theorem auto_word4_n2w : forall env s x1 x,
  env |-- ([x1], s) ---> ([Num x], s) ->
  x < 16 ->
  env |-- ([x1], s) ---> ([value_word ((word.of_Z (Z.of_N x)) : word4)], s).
Proof.
  intros.
  unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  assert ((Z.to_N (Z.of_N x mod 16)) = x).
  2: { rewrite H1. eapply H. }
  rewrite Z.mod_small; lia.
Qed.
Hint Resolve auto_word4_n2w : automation.

Theorem auto_word64_n2w : forall env s x1 x,
  env |-- ([x1], s) ---> ([Num x], s) ->
  x < 2 ^ 64 ->
  env |-- ([x1], s) ---> ([value_word ((word.of_Z (Z.of_N x)) : word64)], s).
Proof.
  intros.
  unfold value_word.
  rewrite word.unsigned_of_Z.
  unfold word.wrap.
  cbn.
  assert ((Z.to_N (Z.of_N x mod (2 ^ 64))) = x).
  2: { cbn in H1. rewrite H1. eapply H. }
  rewrite Z.mod_small; try lia.
  (* apply inj_lt in H0.
  split; try lia.
  rewrite inj_pow in H0.
  simpl  Z.of_nat in H0.
  assumption. *)
Qed.
Hint Resolve auto_word64_n2w : automation.

Theorem auto_word4_w2n : forall env s x1 x,
  env |-- ([x1], s) ---> ([value_word (x : word4)], s) ->
  env |-- ([x1], s) ---> ([Num (Z.to_N (word.unsigned x))], s).
Proof.
  intros.
  unfold value_word in *.
  assumption.
Qed.
Hint Resolve auto_word4_w2n : automation.

Theorem auto_word64_w2n : forall env s x1 x,
  env |-- ([x1], s) ---> ([value_word (x : word64)], s) ->
  env |-- ([x1], s) ---> ([Num (Z.to_N (word.unsigned x))], s).
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

Theorem auto_cmp_cons_Equal: forall env s,
  env |-- ([Const (name_enc "Equal")], s) ---> ([encode ImpSyntax.Equal], s).
Proof. Eval_eq. Qed.

Theorem auto_cmp_cons_Less: forall env s,
  env |-- ([Const (name_enc "Less")], s) ---> ([encode ImpSyntax.Less], s).
Proof. Eval_eq. Qed.

Theorem auto_cmp_CASE: forall {A} `{Refinable A} env s x0 Less_exp Equal_exp v0 f_Less f_Equal,
  env |-- ([x0],s) ---> ([encode v0],s) ->
  (env |-- ([Less_exp],s) ---> ([encode f_Less],s)) ->
  (env |-- ([Equal_exp],s) ---> ([encode f_Equal],s)) ->
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
  | ImpSyntax.Var n => value_list_of_values [value_name "Var"; Num (N.of_nat n)]
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

Theorem auto_exp_cons_Var: forall env s x_n n,
  env |-- ([x_n], s) ---> ([Num (N.of_nat n)], s) ->
  env |-- ([Op Cons [Const (name_enc "Var"); Op Cons [x_n; Const 0]]], s) --->
       ([encode (ImpSyntax.Var n)], s).
Proof. Eval_eq. Qed.

Theorem auto_exp_cons_Const: forall env s x_n n,
  env |-- ([x_n], s) ---> ([value_word n], s) ->
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

Theorem auto_exp_CASE: forall {A} `{Refinable A} env s x0 v0
  Var_case Const_case Add_case Sub_case Div_case Read_case
  f_Var f_Const f_Add f_Sub f_Div f_Read
  (n1 n2 n3 n4 n5 n6 n7 n8 n9 n10: string),

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (forall n, ImpSyntax.Var n = v0 ->
    (FEnv.insert (name_enc n1, Some (encode n)) env) |-- ([Var_case], s) ---> ([encode (f_Var n)], s)) ->

  (forall w, ImpSyntax.Const w = v0 ->
    (FEnv.insert (name_enc n2, Some (value_word w)) env) |-- ([Const_case], s) ---> ([encode (f_Const w)], s)) ->

  (forall e1 e2, ImpSyntax.Add e1 e2 = v0 ->
    (FEnv.insert (name_enc n4, Some (encode e2))
      (FEnv.insert (name_enc n3, Some (encode e1)) env)) |-- ([Add_case], s) ---> ([encode (f_Add e1 e2)], s)) ->

  (forall e1 e2, ImpSyntax.Sub e1 e2 = v0 ->
    (FEnv.insert (name_enc n6, Some (encode e2))
      (FEnv.insert (name_enc n5, Some (encode e1)) env)) |-- ([Sub_case], s) ---> ([encode (f_Sub e1 e2)], s)) ->

  (forall e1 e2, ImpSyntax.Div e1 e2 = v0 ->
    (FEnv.insert (name_enc n8, Some (encode e2))
      (FEnv.insert (name_enc n7, Some (encode e1)) env)) |-- ([Div_case], s) ---> ([encode (f_Div e1 e2)], s)) ->

  (forall e1 e2, ImpSyntax.Read e1 e2 = v0 ->
    (FEnv.insert (name_enc n10, Some (encode e2))
      (FEnv.insert (name_enc n9, Some (encode e1)) env)) |-- ([Read_case], s) ---> ([encode (f_Read e1 e2)], s)) ->

  NoDup ([name_enc n1; name_enc n2; name_enc n3; name_enc n4; name_enc n5;
          name_enc n6; name_enc n7; name_enc n8; name_enc n9; name_enc n10] ++ free_vars x0) ->

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
  env |-- ([x_e1], s) ---> ([encode_exp e1], s) ->
  env |-- ([x_e2], s) ---> ([encode_exp e2], s) ->
  env |-- ([Op Cons [Const (name_enc "Test");
                     Op Cons [x_cmp; Op Cons [x_e1; Op Cons [x_e2; Const 0]]]]], s) --->
        ([encode (ImpSyntax.Test c e1 e2)], s).
Proof. Eval_eq. Qed.

Theorem auto_test_cons_And: forall env s x_t1 x_t2 t1 t2,
  env |-- ([x_t1], s) ---> ([encode_test t1], s) ->
  env |-- ([x_t2], s) ---> ([encode_test t2], s) ->
  env |-- ([Op Cons [Const (name_enc "And");
                     Op Cons [x_t1; Op Cons [x_t2; Const 0]]]], s) --->
        ([encode (ImpSyntax.And t1 t2)], s).
Proof. Eval_eq. Qed.

Theorem auto_test_cons_Or: forall env s x_t1 x_t2 t1 t2,
  env |-- ([x_t1], s) ---> ([encode_test t1], s) ->
  env |-- ([x_t2], s) ---> ([encode_test t2], s) ->
  env |-- ([Op Cons [Const (name_enc "Or");
                     Op Cons [x_t1; Op Cons [x_t2; Const 0]]]], s) --->
        ([encode (ImpSyntax.Or t1 t2)], s).
Proof. Eval_eq. Qed.

Theorem auto_test_cons_Not: forall env s x_t t,
  env |-- ([x_t], s) ---> ([encode_test t], s) ->
  env |-- ([Op Cons [Const (name_enc "Not");
                     Op Cons [x_t; Const 0]]], s) --->
        ([encode (ImpSyntax.Not t)], s).
Proof. Eval_eq. Qed.

Theorem auto_test_CASE: forall {A} `{Refinable A} env s x0 v0
  Test_case And_case Or_case Not_case
  f_Test f_And f_Or f_Not
  n1 n2 n3 n4 n5 n6 n7 n8,
  env |-- ([x0], s) ---> ([encode v0], s) ->

  (forall c e1 e2, ImpSyntax.Test c e1 e2 = v0 ->
    (FEnv.insert (n3, Some (encode e2))
      (FEnv.insert (n2, Some (encode e1))
        (FEnv.insert (n1, Some (encode c)) env))) |-- ([Test_case], s) ---> ([encode (f_Test c e1 e2)], s)) ->

  (forall t1 t2, ImpSyntax.And t1 t2 = v0 ->
    (FEnv.insert (n5, Some (encode t2))
      (FEnv.insert (n4, Some (encode t1)) env)) |-- ([And_case], s) ---> ([encode (f_And t1 t2)], s)) ->

  (forall t1 t2, ImpSyntax.Or t1 t2 = v0 ->
    (FEnv.insert (n7, Some (encode t2))
      (FEnv.insert (n6, Some (encode t1)) env)) |-- ([Or_case], s) ---> ([encode (f_Or t1 t2)], s)) ->

  (forall t, ImpSyntax.Not t = v0 ->
    (FEnv.insert (n8, Some (encode t)) env) |-- ([Not_case], s) ---> ([encode (f_Not t)], s)) ->

  NoDup ([n1; n2; n3; n4; n5; n6; n7; n8] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Test")]
            (Let n1 (Op Head [Op Tail [x0]])
              (Let n2 (Op Head [Op Tail [Op Tail [x0]]])
                (Let n3 (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Test_case)))
       (If Equal [Op Head [x0]; Const (name_enc "And")]
            (Let n4 (Op Head [Op Tail [x0]])
              (Let n5 (Op Head [Op Tail [Op Tail [x0]]]) And_case))
       (If Equal [Op Head [x0]; Const (name_enc "Or")]
            (Let n6 (Op Head [Op Tail [x0]])
              (Let n7 (Op Head [Op Tail [Op Tail [x0]]]) Or_case))
       (If Equal [Op Head [x0]; Const (name_enc "Not")]
            (Let n8 (Op Head [Op Tail [x0]]) Not_case)
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
  env |-- ([x_e], s) ---> ([encode_exp e], s) ->
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

Theorem auto_cmd_CASE: forall {A} `{Refinable A} env s x0 v0
  Skip_case Seq_case Assign_case Update_case If_case While_case
  Call_case Return_case Alloc_case GetChar_case PutChar_case Abort_case
  f_Skip f_Seq f_Assign f_Update f_If f_While f_Call f_Return f_Alloc f_GetChar f_PutChar f_Abort
  n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20 n21,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (env |-- ([Skip_case], s) ---> ([encode (f_Skip)], s)) ->

  (forall c1 c2, ImpSyntax.Seq c1 c2 = v0 ->
    (FEnv.insert (n2, Some (encode c2))
      (FEnv.insert (n1, Some (encode c1)) env)) |-- ([Seq_case], s) ---> ([encode (f_Seq c1 c2)], s)) ->

  (forall n e, ImpSyntax.Assign n e = v0 ->
    (FEnv.insert (n4, Some (encode e))
      (FEnv.insert (n3, Some (encode n)) env)) |-- ([Assign_case], s) ---> ([encode (f_Assign n e)], s)) ->

  (forall a e e', ImpSyntax.Update a e e' = v0 ->
    (FEnv.insert (n7, Some (encode e'))
      (FEnv.insert (n6, Some (encode e))
        (FEnv.insert (n5, Some (encode a)) env))) |-- ([Update_case], s) ---> ([encode (f_Update a e e')], s)) ->

  (forall t c1 c2, ImpSyntax.If t c1 c2 = v0 ->
    (FEnv.insert (n10, Some (encode c2))
      (FEnv.insert (n9, Some (encode c1))
        (FEnv.insert (n8, Some (encode t)) env))) |-- ([If_case], s) ---> ([encode (f_If t c1 c2)], s)) ->

  (forall t c, ImpSyntax.While t c = v0 ->
    (FEnv.insert (n12, Some (encode c))
      (FEnv.insert (n11, Some (encode t)) env)) |-- ([While_case], s) ---> ([encode (f_While t c)], s)) ->

  (forall n f es, ImpSyntax.Call n f es = v0 ->
    (FEnv.insert (n15, Some (encode es))
      (FEnv.insert (n14, Some (encode f))
        (FEnv.insert (n13, Some (encode n)) env))) |-- ([Call_case], s) ---> ([encode (f_Call n f es)], s)) ->

  (forall e, ImpSyntax.Return e = v0 ->
    (FEnv.insert (n16, Some (encode e)) env) |-- ([Return_case], s) ---> ([encode (f_Return e)], s)) ->

  (forall n e, ImpSyntax.Alloc n e = v0 ->
    (FEnv.insert (n18, Some (encode e))
      (FEnv.insert (n17, Some (encode n)) env)) |-- ([Alloc_case], s) ---> ([encode (f_Alloc n e)], s)) ->

  (forall n, ImpSyntax.GetChar n = v0 ->
    (FEnv.insert (n19, Some (encode n)) env) |-- ([GetChar_case], s) ---> ([encode (f_GetChar n)], s)) ->

  (forall e, ImpSyntax.PutChar e = v0 ->
    (FEnv.insert (n20, Some (encode e)) env) |-- ([PutChar_case], s) ---> ([encode (f_PutChar e)], s)) ->

  (env |-- ([Abort_case], s) ---> ([encode (f_Abort)], s)) ->

  NoDup ([n1; n2; n3; n4; n5; n6; n7; n8; n9; n10;
          n11; n12; n13; n14; n15; n16; n17; n18; n19; n20; n21] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Seq")]
            (Let n1 (Op Head [Op Tail [x0]])
              (Let n2 (Op Head [Op Tail [Op Tail [x0]]]) Seq_case))
       (If Equal [Op Head [x0]; Const (name_enc "Assign")]
            (Let n3 (Op Head [Op Tail [x0]])
              (Let n4 (Op Head [Op Tail [Op Tail [x0]]]) Assign_case))
       (If Equal [Op Head [x0]; Const (name_enc "Update")]
            (Let n5 (Op Head [Op Tail [x0]])
              (Let n6 (Op Head [Op Tail [Op Tail [x0]]])
                (Let n7 (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Update_case)))
       (If Equal [Op Head [x0]; Const (name_enc "If")]
            (Let n8 (Op Head [Op Tail [x0]])
              (Let n9 (Op Head [Op Tail [Op Tail [x0]]])
                (Let n10 (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) If_case)))
       (If Equal [Op Head [x0]; Const (name_enc "While")]
            (Let n11 (Op Head [Op Tail [x0]])
              (Let n12 (Op Head [Op Tail [Op Tail [x0]]]) While_case))
       (If Equal [Op Head [x0]; Const (name_enc "Call")]
            (Let n13 (Op Head [Op Tail [x0]])
              (Let n14 (Op Head [Op Tail [Op Tail [x0]]])
                (Let n15 (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Call_case)))
       (If Equal [Op Head [x0]; Const (name_enc "Return")]
            (Let n16 (Op Head [Op Tail [x0]]) Return_case)
       (If Equal [Op Head [x0]; Const (name_enc "Alloc")]
            (Let n17 (Op Head [Op Tail [x0]])
              (Let n18 (Op Head [Op Tail [Op Tail [x0]]]) Alloc_case))
       (If Equal [Op Head [x0]; Const (name_enc "GetChar")]
            (Let n19 (Op Head [Op Tail [x0]]) GetChar_case)
       (If Equal [Op Head [x0]; Const (name_enc "PutChar")]
            (Let n20 (Op Head [Op Tail [x0]]) PutChar_case)
       (If Equal [Op Head [x0]; Const (name_enc "Abort")] Abort_case
       (Const 0)))))))))))], s) --->

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
  (* ^^^ this probably picks the wrong constructor? *)
  all: repeat (rewrite remove_env_update; eauto; crunch_NoDup).
  all: simpl; try reflexivity.
  Transparent name_enc.
  all: cbn.
  Opaque name_enc.
  admit.
Admitted.

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

Theorem auto_app_list_cons_List: forall {A} `{Refinable A} env s x_xs xs,
  env |-- ([x_xs], s) ---> ([encode xs], s) ->
  env |-- ([Op Cons [Const (name_enc "List");
                     Op Cons [x_xs; Const 0]]], s) --->
        ([encode (List xs)], s).
Proof. Eval_eq. Qed.

Theorem auto_app_list_cons_Append: forall {A} `{Refinable A} env s x_l1 x_l2 l1 l2,
  env |-- ([x_l1], s) ---> ([encode l1], s) ->
  env |-- ([x_l2], s) ---> ([encode l2], s) ->
  env |-- ([Op Cons [Const (name_enc "Append");
                     Op Cons [x_l1; Op Cons [x_l2; Const 0]]]], s) --->
        ([encode (Append l1 l2)], s).
Proof. Eval_eq. Qed.

Theorem auto_app_list_CASE: forall {A} `{Refinable A} {R} `{Refinable R}
  env s x0 v0 List_case Append_case f_List f_Append n1 n2 n3,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (forall xs, List xs = v0 ->
    (FEnv.insert (n1, Some (encode xs)) env) |-- ([List_case], s) ---> ([encode (f_List xs)], s)) ->

  (forall l1 l2, Append l1 l2 = v0 ->
    (FEnv.insert (n3, Some (encode l2))
      (FEnv.insert (n2, Some (encode l1)) env)) |-- ([Append_case], s) ---> ([encode (f_Append l1 l2)], s)) ->

  NoDup ([n1; n2; n3] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "List")]
            (Let n1 (Op Head [Op Tail [x0]]) List_case)
         (If Equal [Op Head [x0]; Const (name_enc "Append")]
            (Let n2 (Op Head [Op Tail [x0]])
              (Let n3 (Op Head [Op Tail [Op Tail [x0]]]) Append_case))
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
Hint Resolve auto_func_cons_Func : automation.

Theorem auto_func_CASE: forall {A} `{Refinable A} env s x0 v0
  Func_case f_Func (n1 n2 n3 : name),

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (forall n params body, ImpSyntax.Func n params body = v0 ->
    (FEnv.insert (n3, Some (encode body))
      (FEnv.insert (n2, Some (encode params))
        (FEnv.insert (n1, Some (encode n)) env))) |-- ([Func_case], s) ---> ([encode (f_Func n params body)], s)) ->

  NoDup ([n1; n2; n3] ++ free_vars x0) ->

  env |-- ([Let n1 (Op Head [Op Tail [x0]])
            (Let n2 (Op Head [Op Tail [Op Tail [x0]]])
              (Let n3 (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Func_case))], s) --->
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
Hint Resolve auto_func_CASE : automation.

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
Hint Resolve auto_prog_cons_Program : automation.

Theorem auto_prog_CASE: forall {A} `{Refinable A} env s x0 v0
  Program_case f_Program (n1 : name),

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (forall funcs, ImpSyntax.Program funcs = v0 ->
    (FEnv.insert (n1, Some (encode funcs)) env) |-- ([Program_case], s) ---> ([encode (f_Program funcs)], s)) ->

  NoDup ([n1] ++ free_vars x0) ->

  env |-- ([Let n1 (Op Head [Op Tail [x0]]) Program_case], s) --->
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
Hint Resolve auto_prog_CASE : automation.

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

Theorem auto_reg_CASE: forall {A} `{Refinable A} env s x0 v0
  RAX_case RDI_case RBX_case RBP_case R12_case R13_case R14_case R15_case RDX_case
  f_RAX f_RDI f_RBX f_RBP f_R12 f_R13 f_R14 f_R15 f_RDX,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (env |-- ([RAX_case], s) ---> ([encode f_RAX], s)) ->
  (env |-- ([RDI_case], s) ---> ([encode f_RDI], s)) ->
  (env |-- ([RBX_case], s) ---> ([encode f_RBX], s)) ->
  (env |-- ([RBP_case], s) ---> ([encode f_RBP], s)) ->
  (env |-- ([R12_case], s) ---> ([encode f_R12], s)) ->
  (env |-- ([R13_case], s) ---> ([encode f_R13], s)) ->
  (env |-- ([R14_case], s) ---> ([encode f_R14], s)) ->
  (env |-- ([R15_case], s) ---> ([encode f_R15], s)) ->
  (env |-- ([RDX_case], s) ---> ([encode f_RDX], s)) ->

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
Hint Resolve auto_reg_CASE : automation.

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

Theorem auto_cond_CASE: forall {A} `{Refinable A} env s x0 v0
  Always_case Less_case Equal_case
  f_Always f_Less f_Equal
  n1 n2 n3 n4,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (env |-- ([Always_case], s) ---> ([encode f_Always], s)) ->

  (forall r1 r2, ASMSyntax.Less r1 r2 = v0 ->
    (FEnv.insert (n2, Some (encode r2))
      (FEnv.insert (n1, Some (encode r1)) env)) |-- ([Less_case], s) ---> ([encode (f_Less r1 r2)], s)) ->

  (forall r1 r2, ASMSyntax.Equal r1 r2 = v0 ->
    (FEnv.insert (n4, Some (encode r2))
      (FEnv.insert (n3, Some (encode r1)) env)) |-- ([Equal_case], s) ---> ([encode (f_Equal r1 r2)], s)) ->

  NoDup ([n1; n2; n3; n4] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Always")] Always_case
          (If Equal [Op Head [x0]; Const (name_enc "Less")]
            (Let n1 (Op Head [Op Tail [x0]])
              (Let n2 (Op Head [Op Tail [Op Tail [x0]]]) Less_case))
          (If Equal [Op Head [x0]; Const (name_enc "Equal")]
            (Let n3 (Op Head [Op Tail [x0]])
              (Let n4 (Op Head [Op Tail [Op Tail [x0]]]) Equal_case))
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
Hint Resolve auto_cond_CASE : automation.

(* instr *)

Definition encode_instr (i : ASMSyntax.instr) : Value :=
  match i with
  | ASMSyntax.Const r w =>
    value_list_of_values [value_name "Const"; encode r; value_word w]
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
  | ASMSyntax.Store_RSP r n =>
    value_list_of_values [value_name "Store_RSP"; encode r; Num (N.of_nat n)]
  | ASMSyntax.Load r1 r2 w =>
    value_list_of_values [value_name "Load"; encode r1; encode r2; value_word w]
  | ASMSyntax.Store r1 r2 w =>
    value_list_of_values [value_name "Store"; encode r1; encode r2; value_word w]
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
  env |-- ([x_w], s) ---> ([value_word w], s) ->
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
  env |-- ([x_n], s) ---> ([Num (N.of_nat n)], s) ->
  env |-- ([Op Cons [Const (name_enc "Jump");
                     Op Cons [x_c; Op Cons [x_n; Const 0]]]], s) --->
        ([encode (ASMSyntax.Jump c n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Call: forall env s x_n n,
  env |-- ([x_n], s) ---> ([Num (N.of_nat n)], s) ->
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
  env |-- ([x_n], s) ---> ([Num (N.of_nat n)], s) ->
  env |-- ([Op Cons [Const (name_enc "Add_RSP");
                     Op Cons [x_n; Const 0]]], s) --->
        ([encode (ASMSyntax.Add_RSP n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Sub_RSP: forall env s x_n n,
  env |-- ([x_n], s) ---> ([Num (N.of_nat n)], s) ->
  env |-- ([Op Cons [Const (name_enc "Sub_RSP");
                     Op Cons [x_n; Const 0]]], s) --->
        ([encode (ASMSyntax.Sub_RSP n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Load_RSP: forall env s x_r x_n r n,
  env |-- ([x_r], s) ---> ([encode r], s) ->
  env |-- ([x_n], s) ---> ([Num (N.of_nat n)], s) ->
  env |-- ([Op Cons [Const (name_enc "Load_RSP");
                     Op Cons [x_r; Op Cons [x_n; Const 0]]]], s) --->
        ([encode (ASMSyntax.Load_RSP r n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Store_RSP: forall env s x_r x_n r n,
  env |-- ([x_r], s) ---> ([encode r], s) ->
  env |-- ([x_n], s) ---> ([Num (N.of_nat n)], s) ->
  env |-- ([Op Cons [Const (name_enc "Store_RSP");
                     Op Cons [x_r; Op Cons [x_n; Const 0]]]], s) --->
        ([encode (ASMSyntax.Store_RSP r n)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Load: forall env s x_r1 x_r2 x_w r1 r2 w,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([x_w], s) ---> ([value_word w], s) ->
  env |-- ([Op Cons [Const (name_enc "Load");
                     Op Cons [x_r1; Op Cons [x_r2; Op Cons [x_w; Const 0]]]]], s) --->
        ([encode (ASMSyntax.Load r1 r2 w)], s).
Proof. Eval_eq. Qed.

Theorem auto_instr_cons_Store: forall env s x_r1 x_r2 x_w r1 r2 w,
  env |-- ([x_r1], s) ---> ([encode r1], s) ->
  env |-- ([x_r2], s) ---> ([encode r2], s) ->
  env |-- ([x_w], s) ---> ([value_word w], s) ->
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

Theorem auto_instr_CASE: forall {A} `{Refinable A} env s x0 v0
  Const_case Add_case Sub_case Div_case Jump_case Call_case
  Mov_case Ret_case Pop_case Push_case Add_RSP_case Sub_RSP_case Load_RSP_case Store_RSP_case
  Load_case Store_case GetChar_case PutChar_case Exit_case Comment_case
  f_Const f_Add f_Sub f_Div f_Jump f_Call f_Mov f_Ret f_Pop f_Push
  f_Add_RSP f_Sub_RSP f_Load_RSP f_Store_RSP f_Load f_Store f_GetChar f_PutChar f_Exit f_Comment
  n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20 n21,

  env |-- ([x0], s) ---> ([encode v0], s) ->

  (forall r w, ASMSyntax.Const r w = v0 ->
    (FEnv.insert (n2, Some (value_word w))
      (FEnv.insert (n1, Some (encode r)) env)) |-- ([Const_case], s) ---> ([encode (f_Const r w)], s)) ->

  (forall r1 r2, ASMSyntax.Add r1 r2 = v0 ->
    (FEnv.insert (n4, Some (encode r2))
      (FEnv.insert (n3, Some (encode r1)) env)) |-- ([Add_case], s) ---> ([encode (f_Add r1 r2)], s)) ->

  (forall r1 r2, ASMSyntax.Sub r1 r2 = v0 ->
    (FEnv.insert (n6, Some (encode r2))
      (FEnv.insert (n5, Some (encode r1)) env)) |-- ([Sub_case], s) ---> ([encode (f_Sub r1 r2)], s)) ->

  (forall r, ASMSyntax.Div r = v0 ->
    (FEnv.insert (n7, Some (encode r)) env) |-- ([Div_case], s) ---> ([encode (f_Div r)], s)) ->

  (forall c n, ASMSyntax.Jump c n = v0 ->
    (FEnv.insert (n9, Some (Num (N.of_nat n)))
      (FEnv.insert (n8, Some (encode c)) env)) |-- ([Jump_case], s) ---> ([encode (f_Jump c n)], s)) ->

  (forall n, ASMSyntax.Call n = v0 ->
    (FEnv.insert (n10, Some (Num (N.of_nat n))) env) |-- ([Call_case], s) ---> ([encode (f_Call n)], s)) ->

  (forall r1 r2, ASMSyntax.Mov r1 r2 = v0 ->
    (FEnv.insert (n12, Some (encode r2))
      (FEnv.insert (n11, Some (encode r1)) env)) |-- ([Mov_case], s) ---> ([encode (f_Mov r1 r2)], s)) ->

  (env |-- ([Ret_case], s) ---> ([encode f_Ret], s)) ->

  (forall r, ASMSyntax.Pop r = v0 ->
    (FEnv.insert (n13, Some (encode r)) env) |-- ([Pop_case], s) ---> ([encode (f_Pop r)], s)) ->

  (forall r, ASMSyntax.Push r = v0 ->
    (FEnv.insert (n14, Some (encode r)) env) |-- ([Push_case], s) ---> ([encode (f_Push r)], s)) ->

  (forall n, ASMSyntax.Add_RSP n = v0 ->
    (FEnv.insert (n15, Some (Num (N.of_nat n))) env) |-- ([Add_RSP_case], s) ---> ([encode (f_Add_RSP n)], s)) ->

  (forall n, ASMSyntax.Sub_RSP n = v0 ->
    (FEnv.insert (n16, Some (Num (N.of_nat n))) env) |-- ([Sub_RSP_case], s) ---> ([encode (f_Sub_RSP n)], s)) ->

  (forall r n, ASMSyntax.Load_RSP r n = v0 ->
    (FEnv.insert (n18, Some (Num (N.of_nat n)))
      (FEnv.insert (n17, Some (encode r)) env)) |-- ([Load_RSP_case], s) ---> ([encode (f_Load_RSP r n)], s)) ->

  (forall r n, ASMSyntax.Store_RSP r n = v0 ->
    (FEnv.insert (n20, Some (Num (N.of_nat n)))
      (FEnv.insert (n19, Some (encode r)) env)) |-- ([Store_RSP_case], s) ---> ([encode (f_Store_RSP r n)], s)) ->

  (forall r1 r2 w, ASMSyntax.Load r1 r2 w = v0 ->
    (FEnv.insert (n21, Some (value_word w))
      (FEnv.insert (name_enc "load_r2", Some (encode r2))
        (FEnv.insert (name_enc "load_r1", Some (encode r1)) env))) |-- ([Load_case], s) ---> ([encode (f_Load r1 r2 w)], s)) ->

  (forall r1 r2 w, ASMSyntax.Store r1 r2 w = v0 ->
    (FEnv.insert (name_enc "store_w", Some (value_word w))
      (FEnv.insert (name_enc "store_r2", Some (encode r2))
        (FEnv.insert (name_enc "store_r1", Some (encode r1)) env))) |-- ([Store_case], s) ---> ([encode (f_Store r1 r2 w)], s)) ->

  (env |-- ([GetChar_case], s) ---> ([encode f_GetChar], s)) ->

  (env |-- ([PutChar_case], s) ---> ([encode f_PutChar], s)) ->

  (env |-- ([Exit_case], s) ---> ([encode f_Exit], s)) ->

  (forall str, ASMSyntax.Comment str = v0 ->
    (FEnv.insert (name_enc "comment_str", Some (encode str)) env) |-- ([Comment_case], s) ---> ([encode (f_Comment str)], s)) ->

  NoDup ([n1; n2; n3; n4; n5; n6; n7; n8; n9; n10;
          n11; n12; n13; n14; n15; n16; n17; n18; n19; n20; n21;
          name_enc "load_r1"; name_enc "load_r2"; name_enc "store_r1";
          name_enc "store_r2"; name_enc "store_w"; name_enc "comment_str"] ++ free_vars x0) ->

  env |-- ([If Equal [Op Head [x0]; Const (name_enc "Const")]
            (Let n1 (Op Head [Op Tail [x0]])
              (Let n2 (Op Head [Op Tail [Op Tail [x0]]]) Const_case))
       (If Equal [Op Head [x0]; Const (name_enc "Add")]
            (Let n3 (Op Head [Op Tail [x0]])
              (Let n4 (Op Head [Op Tail [Op Tail [x0]]]) Add_case))
       (If Equal [Op Head [x0]; Const (name_enc "Sub")]
            (Let n5 (Op Head [Op Tail [x0]])
              (Let n6 (Op Head [Op Tail [Op Tail [x0]]]) Sub_case))
       (If Equal [Op Head [x0]; Const (name_enc "Div")]
            (Let n7 (Op Head [Op Tail [x0]]) Div_case)
       (If Equal [Op Head [x0]; Const (name_enc "Jump")]
            (Let n8 (Op Head [Op Tail [x0]])
              (Let n9 (Op Head [Op Tail [Op Tail [x0]]]) Jump_case))
       (If Equal [Op Head [x0]; Const (name_enc "Call")]
            (Let n10 (Op Head [Op Tail [x0]]) Call_case)
       (If Equal [Op Head [x0]; Const (name_enc "Mov")]
            (Let n11 (Op Head [Op Tail [x0]])
              (Let n12 (Op Head [Op Tail [Op Tail [x0]]]) Mov_case))
       (If Equal [Op Head [x0]; Const (name_enc "Ret")] Ret_case
       (If Equal [Op Head [x0]; Const (name_enc "Pop")]
            (Let n13 (Op Head [Op Tail [x0]]) Pop_case)
       (If Equal [Op Head [x0]; Const (name_enc "Push")]
            (Let n14 (Op Head [Op Tail [x0]]) Push_case)
       (If Equal [Op Head [x0]; Const (name_enc "Add_RSP")]
            (Let n15 (Op Head [Op Tail [x0]]) Add_RSP_case)
       (If Equal [Op Head [x0]; Const (name_enc "Sub_RSP")]
            (Let n16 (Op Head [Op Tail [x0]]) Sub_RSP_case)
       (If Equal [Op Head [x0]; Const (name_enc "Load_RSP")]
            (Let n17 (Op Head [Op Tail [x0]])
              (Let n18 (Op Head [Op Tail [Op Tail [x0]]]) Load_RSP_case))
       (If Equal [Op Head [x0]; Const (name_enc "Store_RSP")]
            (Let n19 (Op Head [Op Tail [x0]])
              (Let n20 (Op Head [Op Tail [Op Tail [x0]]]) Store_RSP_case))
       (If Equal [Op Head [x0]; Const (name_enc "Load")]
            (Let (name_enc "load_r1") (Op Head [Op Tail [x0]])
              (Let (name_enc "load_r2") (Op Head [Op Tail [Op Tail [x0]]])
                (Let n21 (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Load_case)))
       (If Equal [Op Head [x0]; Const (name_enc "Store")]
            (Let (name_enc "store_r1") (Op Head [Op Tail [x0]])
              (Let (name_enc "store_r2") (Op Head [Op Tail [Op Tail [x0]]])
                (Let (name_enc "store_w") (Op Head [Op Tail [Op Tail [Op Tail [x0]]]]) Store_case)))
       (If Equal [Op Head [x0]; Const (name_enc "GetChar")] GetChar_case
       (If Equal [Op Head [x0]; Const (name_enc "PutChar")] PutChar_case
       (If Equal [Op Head [x0]; Const (name_enc "Exit")] Exit_case
       (If Equal [Op Head [x0]; Const (name_enc "Comment")]
            (Let (name_enc "comment_str") (Op Head [Op Tail [x0]]) Comment_case)
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
         | ASMSyntax.Store_RSP r n => f_Store_RSP r n
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
Hint Resolve auto_instr_CASE : automation.

(* TODO(kπ) might need some more things for the parser *)
