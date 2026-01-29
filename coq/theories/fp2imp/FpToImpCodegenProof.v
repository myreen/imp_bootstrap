Require Import impboot.utils.Core.
Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunSemantics.
Require Import impboot.functional.FunValues.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.imperative.ImpSemantics.
Require Import impboot.imperative.ImpProperties.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
Require Import impboot.fp2imp.FpToImpCodegen.
Require Import impboot.commons.ProofUtils.
Require Import Stdlib.Program.Equality.

Require Import Patat.Patat.

Open Scope N.

Fixpoint list_rel {A} {B} (R: A -> B -> Prop) (al: list A) (bl: list B): Prop :=
  match al, bl with
  | nil, nil => True
  | a :: al, b :: bl => R a b /\ list_rel R al bl
  | _, _ => False
  end.

Inductive v_rel: list mem_block -> FunValues.Value -> ImpSyntax.Value -> Prop :=
| v_Num (n: N) (mem: list mem_block)
  (N_IN_BOUNDS: n < 2^64):
    v_rel mem (Num n) (Word (word.of_Z (Z.of_N n)))
| v_Pair (p: nat) (mem: list mem_block) (v1 v2: FunValues.Value) (w1 w2: Value)
  (MEM_AT_P: nth_error mem p = Some [Some w1; Some w2])
  (v1_rel: v_rel mem v1 w1) (v2_rel: v_rel mem v2 w2):
    v_rel mem (Pair v1 v2) (Pointer p).

Definition builtins_available (t: list func) : Prop :=
  (∀ n ps cs, In (n, ps, cs) builtin -> find_fun n t = Some (ps,cs)).

Definition func_rel (s: list defun) (t: list func) :=
  builtins_available t ∧
  ∀ fname params body,
    lookup_fun fname s = Some (params,body) ->
    ∃ cs, find_fun fname t = Some (params,cs) ∧
      to_cmd body = Some cs ∧ NoDup params.

Definition state_rel (s: FunSemantics.state) (t: ImpSemantics.state) :=
  t.(input) = s.(FunSemantics.input) ∧
  t.(output) = s.(FunSemantics.output) ∧
  func_rel s.(FunSemantics.funs) t.(funs).

Definition env_rel (mem: list mem_block) (s_env: FEnv.env) (t_env: IEnv.env) :=
  ∀n v,
    FEnv.lookup s_env n = Some v ->
    ∃w, IEnv.lookup t_env n = Some w ∧ v_rel mem v w.

Definition res_rel (mem: list mem_block) (v: FunValues.Value) (o: outcome unit) (s: FunSemantics.state) (t: ImpSemantics.state): Prop :=
  match o with
  | (Stop (Return w)) => 
    v_rel mem v w ∧
      state_rel s t
  | (Stop Abort) => True
  | _ => False
  end.

Fixpoint mem_prefix (m1 m2: list mem_block): Prop :=
  match m1, m2 with
  | [], _ => True
  | b1 :: m1', b2 :: m2' => b1 = b2 ∧ mem_prefix m1' m2'
  | _, _ => False
  end.

Lemma mem_prefix_refl: ∀m, mem_prefix m m.
Proof.
  induction m; simpl; eauto.
Qed.

Lemma mem_prefix_trans: ∀m1 m2 m3,
  mem_prefix m1 m2 -> mem_prefix m2 m3 -> mem_prefix m1 m3.
Proof.
  induction m1; intros * Hprefix1 Hprefix2; simpl in *; cleanup; eauto.
  destruct m2; simpl in *; try discriminate; cleanup.
  destruct m3; simpl in *; try discriminate; cleanup.
  subst; eauto.
Qed.

Opaque word.of_Z Nat.div Nat.modulo Z.to_nat.

Theorem to_exps_thm: ∀ (es: list FunSyntax.exp) (s: FunSemantics.state) (t: ImpSemantics.state)
  (env: FEnv.env) (vs: list FunValues.Value) (s1: FunSemantics.state)
  (Heval: env |-- (es, s) ---> (vs, s1)),
  ∀ (xs: list ImpSyntax.exp)
    (Hto_exp: to_exps es = Some xs)
    (Hstate_rel: state_rel s t)
    (Henv_rel: env_rel t.(memory) env t.(vars)),
    ∃ (ws: list ImpSyntax.Value),
      eval_exps xs t = ((Cont ws), t) ∧ s = s1 ∧ list_rel (v_rel t.(memory)) vs ws.
Proof.
  intros * Heval.
  induction Heval; intros; simpl in *; unfold option_bind in *; cleanup.
  - (* Nil *)
    exists []; split; [reflexivity|].
    eauto.
  - (* Cons *)
    repeat (pat `match ?vs with _ => _ end = _` at destruct vs eqn:?); simpl in *; unfold fail in *; unfold return_ in *; cleanup.
    assert (Some [e] = Some [e]) as HeqSome by congruence.
    eapply IHHeval1 in HeqSome; eauto; clear IHHeval1; cleanup; subst.
    assert (Some (e0 :: l0) = Some (e0 :: l0)) as HeqSome by congruence.
    eapply IHHeval2 in HeqSome; eauto; clear IHHeval2.
    simpl in *; unfold bind in *.
    repeat (spat `match ?vs with _ => _ end` at destruct vs eqn:?); simpl in *; cleanup; unfold_outcome; subst; cleanup.
    eexists.
    spat `eval_exp e0` at rewrite spat.
    spat `eval_exps l0` at rewrite spat.
    eauto.
  - (* Const *)
    destruct (_ <? _) eqn:Hlt; rewrite ?N.ltb_lt in *; inversion Hto_exp; subst.
    eexists.
    split; [reflexivity|].
    split; [reflexivity|].
    split; eauto.
    econstructor; simpl; eauto.
  - (* Var *)
    unfold env_rel in Henv_rel; specialize Henv_rel with (1:= ENV_LOOKUP); destruct Henv_rel as [w [Hlookup Hvr]].
    eexists; simpl; unfold lookup_var, bind; rewrite Hlookup; unfold_outcome.
    eauto.
  - (* Op *)
    destruct op; try solve [inversion Hto_exp]; destruct exps; try solve [inversion Hto_exp]; destruct exps; try solve [inversion Hto_exp].
    + (* Head *)
      inversion EVAL_OP; subst; simpl in *; unfold option_bind in *; cleanup.
      repeat (pat `match ?vs with _ => _ end = _` at destruct vs eqn:?); simpl in *; unfold fail in *; unfold return_ in *; cleanup.
      destruct to_exp eqn:Hto_expeq; try discriminate; simpl in *; cleanup.
      assert (Some [e1] = Some [e1]) as HSomeeq by reflexivity.
      eapply IHHeval in HSomeeq; eauto; clear IHHeval; cleanup; subst; simpl in *; unfold bind in *; cleanup.
      repeat (pat `match ?vs with _ => _ end = _` at destruct vs eqn:?); simpl in *; unfold fail in *; unfold return_ in *; unfold_outcome; cleanup.
      destruct mem_load eqn:Hmem_load.
      spat `v_rel` at inversion spat; subst.
      unfold_monadic; unfold w2n in *; rewrite Properties.word.unsigned_of_Z_0 in *; simpl in *; rewrite Nat.Div0.mod_0_l in *; simpl in *.
      spat `nth_error` at rewrite spat in *; rewrite Nat.Div0.div_0_l in *; simpl in *; unfold_outcome; cleanup.
      eexists; eauto.
    + (* Tail *)
      inversion EVAL_OP; subst; simpl in *; unfold option_bind in *; cleanup.
      repeat (pat `match ?vs with _ => _ end = _` at destruct vs eqn:?); simpl in *; unfold fail in *; unfold return_ in *; cleanup.
      destruct to_exp eqn:Hto_expeq; try discriminate; simpl in *; cleanup.
      assert (Some [e1] = Some [e1]) as HSomeeq by reflexivity.
      eapply IHHeval in HSomeeq; eauto; clear IHHeval; cleanup; subst; simpl in *; unfold bind in *; cleanup.
      repeat (pat `match ?vs with _ => _ end = _` at destruct vs eqn:?); simpl in *; unfold fail in *; unfold return_ in *; unfold_outcome; cleanup.
      destruct mem_load eqn:Hmem_load.
      spat `v_rel` at inversion spat; subst.
      unfold_monadic; unfold w2n in *; rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia; simpl in *; rewrite Nat.Div0.mod_same in *; simpl in *.
      assert (Z.to_nat 8 = 8%nat) as Htmp by lia; rewrite Htmp in *; clear Htmp.
      spat `nth_error` at rewrite spat in *; rewrite Nat.div_same in *; try lia; simpl in *; unfold_outcome; cleanup.
      eexists; eauto.
      Opaque Pos.compare. (* This is important for the Qed to not time out *)
Qed.

Theorem to_exp_thm: ∀ (e: FunSyntax.exp) (s: FunSemantics.state) (t: ImpSemantics.state)
  (env: FEnv.env) (v: FunValues.Value) (s1: FunSemantics.state)
  (Heval: env |-- ([e], s) ---> ([v], s1)),
  ∀ (x: ImpSyntax.exp)
    (Hto_exp: to_exp e = Some x)
    (Hstate_rel: state_rel s t)
    (Henv_rel: env_rel t.(memory) env t.(vars)),
    ∃ (w: ImpSyntax.Value),
      eval_exp x t = ((Cont w), t) ∧ s = s1 ∧ v_rel t.(memory) v w.
Proof.
  intros.
  specialize to_exps_thm with (Heval := Heval) (es := [e]) (xs := [x]) (Hstate_rel := Hstate_rel) (Henv_rel := Henv_rel) as Hto_exps.
  simpl to_exps in *; unfold option_bind in *; cleanup.
  rewrite Hto_exp in Hto_exps.
  specialize Hto_exps with (1 := eq_refl); cleanup; subst.
  simpl in *; unfold_monadic.
  destruct eval_exp eqn:?; destruct o eqn:?; cleanup.
  eauto.
Qed.

Lemma list_rel_length_same : forall [A B] (R: A -> B -> Prop) l l1,
  list_rel R l l1 -> List.length l = List.length l1.
Proof.
  induction l; intros; simpl in *; eauto; cleanup.
  all: destruct l1; simpl in *; cleanup; eauto.
Qed.

Theorem Eval_length:
  ∀env es s rs s1,
    env |-- (es, s) ---> (rs,s1) -> List.length es = List.length rs.
Proof.
  induction es; intros * Heval; simpl in *; inversion Heval; subst; simpl; eauto.
Qed.

Theorem env_rel_update: ∀ m env vars n v1 w,
  env_rel m env vars -> v_rel m v1 w ->
  env_rel m (FEnv.insert (n, Some v1) env) (IEnv.insert (n, Some w) vars).
Proof.
  intros * Henv_rel Hvr n0 v Hlookup.
  destruct (N.eq_dec n0 n); subst; simpl.
  - rewrite FEnv.lookup_insert_eq in *; cleanup.
    eexists; split; eauto.
    rewrite IEnv.lookup_insert_eq; reflexivity.
  - rewrite FEnv.lookup_insert_neq in *; eauto; cleanup.
    unfold env_rel in *; eauto; specialize Henv_rel with (1:= Hlookup); eauto; cleanup.
    eexists; rewrite IEnv.lookup_insert_neq; eauto.
Qed.

(* Theorem oEL_isPREFIX:
  ∀xs ys n, prefix xs ys = true -> (n < String.length xs)%nat -> substring 0 n xs = substring 0 n ys.
Proof.
Admitted.
  (* Induct \\ Cases_on ‘ys’ \\ fs [oEL_def] \\ rw [] *)
(* QED *)

Theorem v_rel_isPREFIX:
  ∀m v w, v_rel m v w -> ∀m', prefix m m' = true -> v_rel m' v w.
Proof.
  (* Induct_on ‘v_rel’ \\ rw []
  \\ simp [Once v_rel_cases] \\ gvs []
  \\ drule_all oEL_isPREFIX \\ rw [] *)
(* QED *)

Theorem env_rel_isPREFIX:
  env_rel m1 env vars ∧ prefix m1 m2 = true -> env_rel m2 env vars.
Proof.
  (* rw [env_rel_def] \\ res_tac \\ fs []
  \\ drule_all v_rel_isPREFIX \\ fs [] *)
(* QED *)
 *)

Theorem env_rel_make_env: forall (rs: list FunValues.Value) ws params m,
  list_rel (v_rel m) rs ws -> List.length params = List.length ws ->
  env_rel m (FunSemantics.make_env params rs FEnv.empty) (make_env params ws IEnv.empty).
Proof.
  intros rs ws params m Hlist_rel Hlen.
  assert (Hgen: forall fenv ienv,
    env_rel m fenv ienv ->
    env_rel m (FunSemantics.make_env params rs fenv) (make_env params ws ienv)).
  2: {
    apply Hgen. unfold env_rel. intros. rewrite FEnv.lookup_empty in H. discriminate.
  }
  generalize dependent ws.
  generalize dependent rs.
  induction params as [|p params' IHparams]; intros rs ws Hlist_rel Hlen fenv ienv Henv_rel.
  - (* [] *)
    destruct ws; simpl in Hlen; try discriminate.
    destruct rs; simpl in Hlist_rel; try contradiction.
    simpl. assumption.
  - (* p :: params' *)
    destruct ws as [|w ws']; simpl in Hlen; try discriminate.
    destruct rs as [|r rs']; simpl in Hlist_rel; try contradiction.
    destruct Hlist_rel as [Hvrel Hlist_rel'].
    simpl.
    apply IHparams.
    + exact Hlist_rel'.
    + simpl in Hlen. lia.
    + apply env_rel_update; assumption.
Qed.

Lemma state_rel_set_vars: ∀s t vars
  (Hstate_rel: state_rel s t),
  state_rel s (set_vars vars t).
Proof.
  unfold state_rel; intros; cleanup; eauto.
Qed.

Lemma state_rel_add_steps_done: ∀s t k
  (Hstate_rel: state_rel s t),
  state_rel s (add_steps_done k t).
Proof.
  unfold state_rel; intros; cleanup; eauto.
Qed.

Lemma func_rel_from_state_rel: ∀s t,
  state_rel s t -> func_rel s.(FunSemantics.funs) t.(funs).
Proof.
  unfold state_rel; intros; cleanup; eauto.
Qed.

Lemma mem_prefix_nth_error: ∀m1 m2 p b
  (Hmem_prefix: mem_prefix m1 m2)
  (Hnth: nth_error m1 p = Some b),
  nth_error m2 p = Some b.
Proof.
  induction m1; simpl; intros.
  - rewrite nth_error_nil in *; discriminate.
  - destruct m2; simpl in *; try discriminate; cleanup; subst.
    destruct p; simpl in *; eauto.
Qed.

Lemma v_rel_mem_prefix: ∀m1 m2 v w
  (Hv_rel: v_rel m1 v w)
  (Hmem_prefix: mem_prefix m1 m2),
  v_rel m2 v w.
Proof.
  intros * Hv_rel; induction Hv_rel; simpl; intros; subst.
  - econstructor; eauto.
  - econstructor; eauto.
    eapply mem_prefix_nth_error; eauto.
Qed.

Lemma env_rel_mem_prefix: ∀m1 m2 env vars
  (Henv_rel: env_rel m1 env vars)
  (Hmem_prefix: mem_prefix m1 m2),
  env_rel m2 env vars.
Proof.
  unfold env_rel; intros; cleanup.
  specialize Henv_rel with (1:= H); cleanup.
  eapply v_rel_mem_prefix in Hmem_prefix; eauto.
Qed.

(* Theorems about calling cons builtins - translated from HOL4 *)

Lemma nth_error_list_update_eq: forall {A: Type} n (v: A) xs,
  (exists v0, nth_error xs n = Some v0) <->
  nth_error (list_update n v xs) n = Some v.
Proof.
  induction n; destruct xs; simpl; split; intros; eauto; cleanup.
  1: rewrite <- IHn; eauto.
  rewrite IHn; eauto.
Qed.

Lemma nth_error_list_update_eq1: forall {A: Type} n (v0 v: A) xs,
  nth_error (list_update n v xs) n = Some v0 -> nth_error (list_update n v xs) n = Some v.
Proof.
  induction n; destruct xs; simpl; intros; eauto; cleanup.
Qed.

Open Scope list_scope.

Theorem list_update_append: forall {A: Type} (xs1 xs2 : list A) xnew n,
  (n < List.length xs1)%nat ->
  list_update n xnew (xs1 ++ xs2) = list_update n xnew xs1 ++ xs2.
Proof.
  intros *.
  revert n.
  induction xs1.
  - intros.
    destruct n; destruct xs2; simpl in *; eauto.
    all: pat ` (_ < 0)%nat` at inversion pat.
  - intros.
    destruct n; eauto.
    pat `forall _, _` at specialize (pat n).
    simpl in *; f_equal.
    eapply IHxs1.
    lia.
Qed.

Theorem list_update_append2: forall {A: Type} (xs1 xs2 : list A) xnew n,
  (n >= List.length xs1)%nat ->
  list_update n xnew (xs1 ++ xs2) = xs1 ++ list_update (n - List.length xs1) xnew xs2.
Proof.
  intros *.
  revert n.
  induction xs1.
  - intros; simpl.
    rewrite Nat.sub_0_r; reflexivity.
  - intros.
    simpl.
    destruct n; simpl in *; eauto; try lia.
    (* rewrite <- IHxs1; try lia. *)
    (* rewrite <- Nat.succ_le_mono in *. *)
    rewrite IHxs1; try lia.
    reflexivity.
Qed.

Theorem Call_cons:
  forall (t: state) (e1 e2: exp) (x y: FunValues.Value) (w w': Value) (n: name),
  v_rel t.(memory) y w' ->
  v_rel t.(memory) x w ->
  eval_exp e2 t = (Cont w', t) ->
  eval_exp e1 t = (Cont w, t) ->
  builtins_available t.(funs) ->
  exists m1 ptr,
    (forall (fuel: nat) (c2: cmd),
      eval_cmd (Seq (Call n (name_of_string "cons") [e1; e2]) c2) (EVAL_CMD (S fuel)) t =
      eval_cmd c2 (EVAL_CMD (S fuel))
        (set_vars (IEnv.insert (n, Some ptr) t.(vars))
          (set_memory (t.(memory) ++ m1) (add_steps_done 1 t)))) /\
    v_rel (t.(memory) ++ m1) (Pair x y) ptr.
Proof.
  Opaque EVAL_CMD.
  intros * Hvrel_y Hvrel_x Heval_e2 Heval_e1 Hbuiltin.
  exists [[Some w; Some w']].
  exists (Pointer (List.length t.(memory))).
  split.
  - intros fuel c2.
    simpl; unfold_outcome; unfold_monadic.
    rewrite Heval_e1, Heval_e2.
    unfold get_vars; unfold_outcome; simpl; unfold get_body_and_set_vars.
    unfold builtins_available in Hbuiltin.
    simpl in *.
    spat ` (name_of_string "cons", ?args, ?cs1)` at assert (find_fun (name_of_string "cons") (funs t) = Some (args, cs1)) as Hfind_fun by (eapply Hbuiltin; eauto); clear Hbuiltin.
    rewrite Hfind_fun.
    with_strategy transparent [EVAL_CMD] unfold EVAL_CMD at 1.
    simpl in *; unfold_monadic; unfold catch_return, bind, dest_word, alloc, w2n; unfold_outcome.
    rewrite word.unsigned_of_Z_nowrap; try lia.
    assert (Z.to_nat 16 = 16%nat) as -> by lia.
    with_strategy transparent [Nat.modulo] simpl.
    simpl; unfold w2n; rewrite word.unsigned_of_Z_nowrap; try lia.
    assert (Z.to_nat 0 = 0%nat) as -> by lia.
    with_strategy transparent [Nat.modulo] simpl.
    unfold update_block.
    rewrite nth_error_app2 by lia; rewrite Nat.sub_diag; simpl.
    rewrite Nat.Div0.div_0_l, repeat_length; simpl.
    with_strategy transparent [Nat.div] simpl.
    unfold w2n; rewrite word.unsigned_of_Z_nowrap; try lia.
    assert (Z.to_nat 8 = 8%nat) as -> by lia.
    with_strategy transparent [Nat.modulo] simpl.
    rewrite list_update_append2 by lia.
    rewrite nth_error_app2 by lia.
    rewrite Nat.sub_diag; simpl.
    unfold set_vars; simpl.
    rewrite list_update_append2 by lia.
    rewrite Nat.sub_diag; simpl.
    reflexivity.
  - econstructor.
    + rewrite nth_error_app2 by lia.
      rewrite Nat.sub_diag. simpl. reflexivity.
    + eapply v_rel_mem_prefix; eauto.
      clear. induction (memory t); simpl; eauto.
    + eapply v_rel_mem_prefix; eauto.
      clear. induction (memory t); simpl; eauto.
Qed.

Theorem Call_cons3:
  forall (t: state) (e1 e2 e3: exp) (x y z: FunValues.Value) (w w' w'': Value) (n: name),
  v_rel t.(memory) z w'' ->
  v_rel t.(memory) y w' ->
  v_rel t.(memory) x w ->
  eval_exp e3 t = (Cont w'', t) ->
  eval_exp e2 t = (Cont w', t) ->
  eval_exp e1 t = (Cont w, t) ->
  builtins_available t.(funs) ->
  exists m1 ptr,
    (forall (fuel: nat) (c2: cmd),
      eval_cmd (Seq (Call n (name_of_string "cons3") [e1; e2; e3]) c2) (EVAL_CMD (S (S (S fuel)))) t =
      eval_cmd c2 (EVAL_CMD (S (S (S fuel))))
        (set_vars (IEnv.insert (n, Some ptr) t.(vars))
          (set_memory (t.(memory) ++ m1) t))) /\
    v_rel (t.(memory) ++ m1) (Pair x (Pair y z)) ptr.
Proof.
  Opaque EVAL_CMD word.unsigned.
  intros * Hvrel_z Hvrel_y Hvrel_x Heval_e3 Heval_e2 Heval_e1 Hbuiltin.
  exists [[Some w; Some w'; Some w'']].
  exists (Pointer (List.length t.(memory))).
  split.
  - intros fuel c2.
    simpl; unfold_outcome; unfold_monadic.
    rewrite Heval_e1, Heval_e2, Heval_e3.
    unfold get_vars; unfold_outcome; simpl; unfold get_body_and_set_vars.
    pose proof Hbuiltin as Hbuiltin1.
    unfold builtins_available in Hbuiltin1.
    simpl in *.
    spat ` (name_of_string "cons3", ?args, ?cs1)` at assert (find_fun (name_of_string "cons3") (funs t) = Some (args, cs1)) as Hfind_fun by (eapply Hbuiltin1; eauto); clear Hbuiltin1.
    rewrite Hfind_fun; clear Hfind_fun.
    with_strategy transparent [EVAL_CMD] (once unfold EVAL_CMD at 1; fold EVAL_CMD).
    (* match goal with
    | |- context [Call ]
    end. *)
    unfold_monadic; simpl orb; cbv iota.
    set (Call _ _ _) as call_cons1.
    set (Call _ _ _) as call_cons2.
    once unfold eval_cmd; fold eval_cmd.
    Opaque eval_cmd.
    (* specialize Call_cons with (e1 := e2) (e2 := e3) (x := y) (y := z) (n := (name_of_string "ret")) as Hcall_cons_tail. *)

    simpl in *; unfold_monadic; unfold catch_return, bind, dest_word, alloc, w2n; unfold_outcome; simpl.
    unfold add_steps_done, set_steps_done; simpl.




    (*
    unfold builtins_available in Hbuiltin.
    simpl in *.
    spat ` (name_of_string "cons", ?args, ?cs1)` at assert (find_fun (name_of_string "cons") (funs t) = Some (args, cs1)) as Hfind_fun_cons by (eapply Hbuiltin; eauto); clear Hbuiltin.
    rewrite Hfind_fun_cons.
    with_strategy transparent [EVAL_CMD] unfold EVAL_CMD at 1.
    simpl in *; unfold_monadic; unfold catch_return, bind, dest_word, alloc, w2n, inc_steps_done, add_steps_done, set_steps_done, set_vars, lookup_var, get_body_and_set_vars; unfold_outcome; simpl.
    rewrite word.unsigned_of_Z_nowrap; try lia.
    assert (Z.to_nat 16 = 16%nat) as -> by lia.
    with_strategy transparent [Nat.modulo] simpl.
    simpl; unfold w2n; rewrite word.unsigned_of_Z_nowrap; try lia.
    assert (Z.to_nat 0 = 0%nat) as -> by lia.
    with_strategy transparent [Nat.modulo] simpl.
    unfold update_block.
    rewrite nth_error_app2 by lia; rewrite Nat.sub_diag; simpl.
    rewrite Nat.Div0.div_0_l, repeat_length; simpl.
    with_strategy transparent [Nat.div] simpl.
    unfold w2n; rewrite word.unsigned_of_Z_nowrap; try lia.
    assert (Z.to_nat 8 = 8%nat) as -> by lia.
    with_strategy transparent [Nat.modulo] simpl.
    rewrite list_update_append2 by lia.
    rewrite nth_error_app2 by lia.
    rewrite Nat.sub_diag; simpl.
    rewrite Hfind_fun_cons; simpl.
    simpl in *; unfold_monadic; unfold catch_return, bind, dest_word, alloc, w2n, inc_steps_done, add_steps_done, set_steps_done, set_vars, lookup_var, get_body_and_set_vars; unfold_outcome; simpl.
    rewrite word.unsigned_of_Z_nowrap; try lia.
    assert (Z.to_nat 16 = 16%nat) as -> by lia; simpl.
    assert (16 mod 8 = 0)%nat as -> by (with_strategy transparent [Nat.modulo] simpl; reflexivity).
    simpl; unfold w2n; rewrite word.unsigned_of_Z_nowrap; try lia.
    assert (Z.to_nat 0 = 0%nat) as -> by lia; simpl.
    with_strategy transparent [Nat.modulo] simpl.
    unfold update_block.
    rewrite nth_error_app2 by lia; rewrite Nat.sub_diag; simpl.
    rewrite Nat.Div0.div_0_l, repeat_length; simpl.
    *)

    admit.
    (* unfold set_vars; simpl.
    rewrite list_update_append2 by lia.
    rewrite Nat.sub_diag; simpl.
    reflexivity. *)
  - econstructor.
    + rewrite nth_error_app2 by lia.
      rewrite Nat.sub_diag. simpl.
      admit.
      (* reflexivity. *)
    + eapply v_rel_mem_prefix; eauto.
      clear. induction (memory t); simpl; eauto.
    + eapply v_rel_mem_prefix; eauto.
      all: admit.
      (* clear. induction (memory t); simpl; eauto. *)
Admitted.

Theorem Call_cons4:
  forall (t: state) (e1 e2 e3 e4: exp) (x y z q: FunValues.Value) (w w' w'' w''': Value) (n: name),
  v_rel t.(memory) q w''' ->
  v_rel t.(memory) z w'' ->
  v_rel t.(memory) y w' ->
  v_rel t.(memory) x w ->
  eval_exp e4 t = (Cont w''', t) ->
  eval_exp e3 t = (Cont w'', t) ->
  eval_exp e2 t = (Cont w', t) ->
  eval_exp e1 t = (Cont w, t) ->
  builtins_available t.(funs) ->
  exists m1 ptr,
    (forall (fuel: nat) (c2: cmd),
      eval_cmd (Seq (Call n (name_of_string "cons4") [e1; e2; e3; e4]) c2) (EVAL_CMD (S (S (S (S (S fuel)))))) t =
      eval_cmd c2 (EVAL_CMD fuel) 
        (set_vars (IEnv.insert (n, Some ptr) t.(vars)) 
          (set_memory (t.(memory) ++ m1) t))) /\
    v_rel (t.(memory) ++ m1) (Pair x (Pair y (Pair z q))) ptr.
Proof.
Admitted.

Theorem Call_cons5:
  forall (t: state) (e1 e2 e3 e4 e5: exp) (x y z q r: FunValues.Value) 
         (w w' w'' w''' w'''': Value) (n: name),
  v_rel t.(memory) r w'''' ->
  v_rel t.(memory) q w''' ->
  v_rel t.(memory) z w'' ->
  v_rel t.(memory) y w' ->
  v_rel t.(memory) x w ->
  eval_exp e5 t = (Cont w'''', t) ->
  eval_exp e4 t = (Cont w''', t) ->
  eval_exp e3 t = (Cont w'', t) ->
  eval_exp e2 t = (Cont w', t) ->
  eval_exp e1 t = (Cont w, t) ->
  builtins_available t.(funs) ->
  exists m1 ptr,
    (forall (fuel: nat) (c2: cmd),
      eval_cmd (Seq (Call n (name_of_string "cons5") [e1; e2; e3; e4; e5]) c2) 
               (EVAL_CMD (S (S (S (S (S (S (S fuel)))))))) t =
      eval_cmd c2 (EVAL_CMD fuel) 
        (set_vars (IEnv.insert (n, Some ptr) t.(vars)) 
          (set_memory (t.(memory) ++ m1) t))) /\
    v_rel (t.(memory) ++ m1) (Pair x (Pair y (Pair z (Pair q r)))) ptr.
Proof.
Admitted.

Theorem Z_div_between_1: ∀a b: Z,
  (a >= 0)%Z ->
  (0 < b)%Z ->
  (a >= b)%Z ->
  (a < 2 * b)%Z ->
  (a / b = 1)%Z.
Proof.
  intros.
  assert (b * 1 <= a)%Z as Hlt by lia.
  specialize Z.div_le_lower_bound with (a := a) (b := b) (q := 1%Z) (1 := H0) (2 := Hlt) as ?.
  specialize Z.div_lt_upper_bound with (a := a) (b := b) (q := 2%Z) (1 := H0) as ?.
  lia.
Qed.

Lemma no_overflow_addition: ∀ narg1 narg2,
  narg1 < N.pos (2 ^ 64) ->
  narg2 < N.pos (2 ^ 64) ->
  word.ltu (word.add (word.of_Z (Z.of_N narg1): word64) (word.of_Z (Z.of_N narg2))) (word.of_Z (Z.of_N narg1)) = false ->
  word.ltu (word.add (word.of_Z (Z.of_N narg1): word64) (word.of_Z (Z.of_N narg2))) (word.of_Z (Z.of_N narg2)) = false ->
  narg1 + narg2 < 2 ^ 64.
Proof.
  intros.
  assert (Z.of_N narg1 < 2 ^ 64)%Z as Harg1Z by lia.
  assert (Z.of_N narg2 < 2 ^ 64)%Z as Harg2Z by lia.
  assert (Z.of_N narg1 >= 0)%Z as Harg1ge0 by lia.
  assert (Z.of_N narg2 >= 0)%Z as Harg2ge0 by lia.
  with_strategy transparent [word.add] simpl word.add in *.
  unfold Naive.wrap in *; simpl in *.
  assert (word.unsigned (word.of_Z (Z.of_N narg1): word64) = (Z.of_N narg1)) as Harg1.
  1: rewrite Properties.word.unsigned_of_Z_nowrap; eauto; lia.
  assert (word.unsigned (word.of_Z (Z.of_N narg2): word64) = (Z.of_N narg2)) as Harg2.
  1: rewrite Properties.word.unsigned_of_Z_nowrap; eauto; lia.
  with_strategy transparent [word.unsigned] simpl word.unsigned in *.
  rewrite Harg1, Harg2 in *.
  clear Harg1 Harg2.
  rewrite Z.ltb_ge in *.
  destruct (N.lt_ge_cases (narg1 + narg2) (N.pos (2^64))) as [Hlt | Hge]; auto.
  exfalso.
  assert (Z.of_N narg1 + Z.of_N narg2 >= 2^64)%Z as HgeZ by lia.
  assert (Z.of_N narg1 + Z.of_N narg2 < 2 * 2^64)%Z as Hlt2 by lia.
  assert ((Z.of_N narg1 + Z.of_N narg2) / 2^64 = 1)%Z as Hdiv1.
  1: apply Z_div_between_1; lia.
  assert ((Z.of_N narg1 + Z.of_N narg2) mod 2^64 = Z.of_N narg1 + Z.of_N narg2 - 2^64)%Z as Hmod.
  1: rewrite Zmod_eq_full by lia; rewrite Hdiv1; lia.
  simpl in *.
  rewrite Hmod in H1, H2.
  lia.
Qed.

Theorem to_cmd_thm: ∀ es env s rs s1
  (Heval: env |-- (es, s) ---> (rs, s1)),
  ∀ e cs t r,
    es = [e] -> rs = [r] -> to_cmd e = Some cs -> state_rel s t ->
    env_rel t.(memory) env t.(vars) ->
    ∃ fuel r1 t1,
      eval_cmd cs (EVAL_CMD fuel) t = (r1,t1) ∧
      res_rel t1.(memory) r r1 s1 t1 ∧ mem_prefix t.(memory) t1.(memory).
Proof.
  Transparent eval_cmd EVAL_CMD.
  Opaque word.ltu word.eqb word.add word.sub word.divu.
  Opaque to_exp.
  fix IH 6.
  intros * Heval; destruct Heval; try discriminate; intros * Hes Hrs Hto_cmd Hstate_rel Henv_rel; simpl in *; subst; cleanup; simpl in *.
  - (* Const *)
    destruct to_exp eqn:Hto_exp; cleanup; simpl in *|-; unfold_monadic; unfold_outcome.
    eapply to_exp_thm in Hto_exp; eauto; cleanup; subst; [|econstructor; eauto]; subst.
    do 3 eexists.
    simpl in *; unfold_monadic; rewrite H.
    split; [reflexivity|].
    split; [|apply mem_prefix_refl].
    unfold res_rel; simpl; split; eauto.
  - (* Var *)
    destruct to_exp eqn:Hto_exp; try discriminate; cleanup.
    eapply to_exp_thm in Hto_exp; eauto; cleanup; subst; [|econstructor; eauto].
    eapply Henv_rel in ENV_LOOKUP; cleanup.
    do 3 eexists.
    simpl in *; unfold_monadic; unfold lookup_var; rewrite H; unfold_outcome.
    split; [reflexivity|].
    split; [|apply mem_prefix_refl].
    unfold res_rel; simpl; split; eauto.
  - (* Op *)
    destruct to_exp eqn:Hto_exp; try discriminate; cleanup.
    destruct op; try solve [inversion Hto_exp]; destruct exps; try solve [inversion Hto_exp]; destruct exps; try solve [inversion Hto_exp].
    all: eexists.
    all: inversion EVAL_OP; subst; simpl in *; unfold option_bind in *; cleanup.
    all: repeat (pat `match ?vs with _ => _ end = _` at destruct vs eqn:?); simpl in *; unfold fail in *; unfold return_ in *; cleanup.
    all: destruct to_exp eqn:Hto_expeq; try discriminate; simpl in *; cleanup.
    all: eapply to_exp_thm in Hto_expeq; eauto; cleanup; subst; [|econstructor; eauto; econstructor]; subst.
    all: simpl in *; unfold_monadic; unfold_outcome; rewrite H.
    all: do 2 eexists.
    all: split; [reflexivity|].
    all: split; [|apply mem_prefix_refl].
    all: unfold res_rel; simpl; split; eauto.
  - (* Let *)
    destruct to_exp eqn:Hto_exp; try discriminate; cleanup.
    unfold option_bind in *; cleanup.
    destruct to_assign eqn:Hto_assign; try discriminate; cleanup.
    unfold to_assign in Hto_assign; cleanup.
    destruct (to_exp exp1) eqn:Hto_exp1; cleanup.
    1: { (* assign expr *)
      eapply to_exp_thm in Hto_exp1; cleanup; eauto; simpl in *; cleanup; subst.
      destruct (to_cmd exp2) eqn:Hto_cmd2; try discriminate; cleanup.
      eapply IH with (t := set_vars _ t) in Hto_cmd2; cleanup; eauto; simpl in *; cleanup.
      2: eapply env_rel_update; eauto.
      unfold assign; unfold_monadic; unfold_outcome.
      do 3 eexists.
      rewrite H.
      split; [eauto|].
      split; [|assumption].
      eauto.
    }
    destruct to_cons eqn:Hto_cons; cleanup.
    1: { (* assign cons *)
      unfold to_cons in *; cleanup.
      admit.
    }
    destruct exp1; try discriminate; cleanup.
    2: { (* call *)
      destruct to_exps eqn:Hto_exps; try discriminate; cleanup.
      inversion Heval1; subst.
      eapply to_exps_thm in Hto_exps; eauto; cleanup; subst.
      specialize list_rel_length_same with (1:= H1) as Hlen.
      specialize Eval_length with (1 := EVAL_ARGS) as Hlen_eval.
      destruct (to_cmd exp2) eqn:Hto_cmd2; try discriminate; cleanup.
      unfold env_and_body in *; destruct lookup_fun as [ [fparams fbody] | ] eqn:Hlookup_fun; try discriminate; cleanup.
      destruct (_ =? _)%nat eqn:Hlen_params; rewrite ?Nat.eqb_eq in *; try discriminate; cleanup.
      simpl in *; cleanup; unfold_monadic; simpl; unfold_monadic; unfold_outcome.
      unfold get_vars, get_body_and_set_vars, set_varsM, assign, catch_return, set_vars; simpl; unfold_outcome.
      specialize func_rel_from_state_rel with (1:= Hstate_rel) as Hfunc_rel.
      eapply Hfunc_rel in Hlookup_fun; cleanup; clear Hfunc_rel.
      eapply IH with (t := set_vars _ (set_steps_done _ _)) in EVAL_BODY; eauto; cleanup; simpl in *; cleanup.
      3: eapply env_rel_make_env; eauto; congruence.
      2: eapply state_rel_set_vars; eauto.
      pat `eval_cmd _ (EVAL_CMD ?f) (set_vars _ _) = _` at rename f into fuel0.
      unfold res_rel in *|-; simpl in *; cleanup.
      eapply env_rel_mem_prefix in Henv_rel; eauto.
      destruct x2; cleanup; destruct v; cleanup; eauto.
      2: { (* Abort *)
        exists (S fuel0); do 2 eexists.
        rewrite H.
        rewrite H0.
        spat `NoDup` at eapply nodup_fixed_point in spat; rewrite spat.
        rewrite Hlen_params, Hlen; rewrite Nat.eqb_refl; simpl; unfold nodupb.
        unfold_monadic; unfold_outcome; unfold set_vars, inc_steps_done, add_steps_done, set_steps_done in *; simpl in *.
        rewrite H4; unfold res_rel in *|-; simpl in *; cleanup.
        split; eauto; split; eauto; simpl; eauto.
      }
      eapply IH with (t := set_vars _ _) in Heval2; eauto; simpl in *; cleanup.
      3: eapply env_rel_update; eauto.
      2: eapply state_rel_set_vars; eauto.
      exists (S (fuel0 + x1)); do 2 eexists.
      Opaque EVAL_CMD.
      rewrite H.
      rewrite H0.
      spat `NoDup` at eapply nodup_fixed_point in spat; rewrite spat.
      rewrite Hlen_params, Hlen; rewrite Nat.eqb_refl; simpl; unfold nodupb.
      with_strategy transparent [EVAL_CMD] simpl EVAL_CMD at 1.
      unfold_monadic; unfold_outcome; unfold set_vars, inc_steps_done, add_steps_done, set_steps_done in *; simpl in *.
      eapply eval_cmd_add_clock with (fuel1 := x1) in H4; try congruence.
      rewrite H4; unfold res_rel in *|-; simpl in *; cleanup.
      rewrite Nat.add_comm.
      destruct x2; cleanup; destruct v0; cleanup; eauto.
      all: eapply eval_cmd_add_clock with (fuel1 := (fuel0 + 1)%nat) in H8; try congruence.
      all: rewrite Nat.add_assoc, Nat.add_1_r in H8.
      all: split; eauto.
      all: split; eauto.
      all: unfold res_rel; simpl; eauto.
      all: eapply mem_prefix_trans; eauto.
    }
    (* Op *)
    destruct o eqn:?; cleanup.
    all: clear Hto_exp Hto_exp1 Hto_cons.
    all: inversion Heval1; cleanup; subst; simpl in *.
    all: destruct to_exps as [iargs|] eqn:Hto_exps; cleanup.
    all: destruct iargs as [|iarg1 iargs]; cleanup.
    all: try destruct iargs as [|iarg2 iargs]; cleanup.
    all: try destruct iargs; cleanup.
    all: destruct to_cmd eqn:?; cleanup.
    all: eapply to_exps_thm in Hto_exps; eauto; cleanup; subst.
    Opaque eval_exps.
    all: simpl in *; unfold_monadic; unfold fail in *.
    all: destruct vs as [|varg1 vs]; cleanup.
    all: try destruct varg1 as [|narg1]; cleanup.
    all: try destruct vs as [|varg2 vs]; cleanup.
    all: try destruct varg2 as [|narg2]; cleanup.
    all: try destruct vs; unfold return_ in *; cleanup.
    all: simpl in *; destruct x as [|warg1 x]; cleanup.
    all: try destruct x as [|warg2 x]; cleanup.
    all: try destruct x; cleanup.
    all: try inversion H0; try inversion H1; subst.
    all: simpl in *; unfold_monadic; try rewrite H.
    all: unfold get_body_and_set_vars.
    all: specialize func_rel_from_state_rel with (1:= Hstate_rel) as Hfunc_rel.
    all: unfold func_rel in Hfunc_rel; destruct Hfunc_rel as [Hbuiltin _].
    all: unfold builtins_available in *; simpl in *.
    1: { (* Add *)
      spat ` (name_of_string "add", ?args, ?cs1)` at assert (find_fun (name_of_string "add") (funs t) = Some (args, cs1)) as Hfind_fun by (eapply Hbuiltin; eauto); clear Hbuiltin.
      rewrite Hfind_fun.
      simpl in *; unfold_monadic; unfold catch_return; simpl; unfold_outcome.
      (* TODO(paper/post?): this is a pain point in Rocq *)
      (* 1. Reconstruct the evaluation of add body with some enough fuel *)
      match goal with
      | |- context C [EVAL_CMD _ ?c ?s] => remember (EVAL_CMD 1 c s) as eval_cmd_add_fun
      end.
      Opaque word.add.
      with_strategy transparent [EVAL_CMD] simpl EVAL_CMD at 1 in Heqeval_cmd_add_fun.
      unfold bind, inc_steps_done, add_steps_done, set_steps_done, combine_word in *; simpl in *.
      destruct (word.ltu _ _) eqn:?; simpl in *; unfold_outcome; cleanup.
      1: { (* Abort *)
        exists 1%nat; do 2 eexists.
        with_strategy transparent [EVAL_CMD] simpl EVAL_CMD at 1.
        unfold bind, inc_steps_done, add_steps_done, set_steps_done, combine_word in *; simpl in *.
        rewrite Heqb.
        split; [reflexivity|].
        split; [|apply mem_prefix_refl].
        unfold res_rel; simpl; eauto.
      }
      destruct (word.ltu _ (word.of_Z (Z.of_N narg2))) eqn:?; simpl in *; unfold_outcome; cleanup.
      1: { (* Abort *)
        exists 1%nat; do 2 eexists.
        simpl in *.
        with_strategy transparent [EVAL_CMD] simpl EVAL_CMD at 1.
        unfold bind, inc_steps_done, add_steps_done, set_steps_done, combine_word in *; simpl in *.
        rewrite Heqb.
        unfold_outcome; simpl in *.
        rewrite Heqb0.
        split; [reflexivity|].
        split; [|apply mem_prefix_refl].
        unfold res_rel; simpl; eauto.
      }
      clear Heqeval_cmd_add_fun.
      (* 2. Use IH and use info from 1. to prove its premises -> get fuel_ih from this *)
      assert (narg1 + narg2 < 2 ^ 64) as Hno_overflow by (eapply no_overflow_addition; eauto).
      eapply IH with (t := set_vars _ (add_steps_done 1 _)) in Heval2; eauto; simpl in *; cleanup.
      2: eapply state_rel_set_vars; eapply state_rel_add_steps_done; eauto.
      2: eapply env_rel_update; eauto.
      2: econstructor; try lia.
      (* 3. Instantiate fuel in goal with fuel_ih *)
      exists (S x); do 2 eexists.
      with_strategy transparent [EVAL_CMD] simpl EVAL_CMD at 1.
      unfold_monadic; unfold_outcome; unfold set_vars, inc_steps_done, add_steps_done, set_steps_done in *; simpl in *.
      rewrite Heqb.
      simpl in *.
      rewrite Heqb0.
      simpl in *; unfold set_vars; simpl.
      assert (x0 <> Stop TimeOut) as Hnotimeout by (unfold res_rel in *|-; destruct x0; simpl in *; try congruence; destruct v; congruence).
      spat `eval_cmd` at eapply eval_cmd_add_clock with (fuel1 := 1%nat) in spat; eauto.
      assert (
        word.of_Z (Z.of_N (narg1 + narg2)) = word.add (word.of_Z (Z.of_N narg1): word64) (word.of_Z (Z.of_N narg2))
      ) as <-.
      1: {
        rewrite N2Z.inj_add.
        rewrite word.ring_morph_add.
        reflexivity.
      }
      rewrite Nat.add_1_r in *|-.
      split; eauto.
    }
    1: { (* Sub *)
      spat ` (name_of_string "sub", ?args, ?cs1)` at assert (find_fun (name_of_string "sub") (funs t) = Some (args, cs1)) as Hfind_fun by (eapply Hbuiltin; eauto); clear Hbuiltin.
      rewrite Hfind_fun.
      simpl in *; unfold_monadic; unfold catch_return; simpl; unfold_outcome.
      eapply IH with (t := set_vars _ (add_steps_done 1 _)) in Heval2; eauto; simpl in *; cleanup.
      2: eapply state_rel_set_vars; eapply state_rel_add_steps_done; eauto.
      2: eapply env_rel_update; eauto; econstructor; try lia.
      exists (S x); do 2 eexists.
      with_strategy transparent [EVAL_CMD] simpl EVAL_CMD at 1.
      unfold_monadic; unfold_outcome; unfold set_vars, inc_steps_done, add_steps_done, set_steps_done in *; simpl in *.
      split; eauto.
      assert (x0 <> Stop TimeOut) as Hnotimeout by (unfold res_rel in *|-; destruct x0; simpl in *; try congruence; destruct v; congruence).
      destruct (word.ltu _ _) eqn:?; simpl in *; unfold_outcome; cleanup.
      1: { (* a1 < a2 *)
        rewrite word.unsigned_ltu, Z.ltb_lt in *.
        do 2 rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia.
        assert (Z.of_N 0 = 0%Z) as <- by lia.
        assert (narg1 - narg2 = 0)%N as <- by lia.
        spat `eval_cmd` at eapply eval_cmd_add_clock with (fuel1 := 1%nat) in spat; try congruence.
        unfold set_vars; simpl; rewrite Nat.add_1_r in *|-.
        eauto.
      }
      (* a1 >= a2 *)
      rewrite word.unsigned_ltu, Z.ltb_ge in *.
      do 2 rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia.
      assert (narg2 <= narg1)%N as Hge by lia.
      assert (
        word.of_Z (Z.of_N (narg1 - narg2)) = word.sub (word.of_Z (Z.of_N narg1): word64) (word.of_Z (Z.of_N narg2))
      ) as <-.
      1: {
        rewrite N2Z.inj_sub; eauto.
        rewrite word.ring_morph_sub.
        reflexivity.
      }
      spat `eval_cmd` at eapply eval_cmd_add_clock with (fuel1 := 1%nat) in spat; try congruence.
      unfold set_vars; simpl; rewrite Nat.add_1_r in *|-.
      eauto.
    }
    Transparent eval_exps.
    all: clear Hbuiltin.
    all: simpl in *; unfold bind in *.
    all: try destruct eval_exp eqn:?; try destruct o eqn:?; cleanup; subst.
    all: try destruct (eval_exp iarg2 _) eqn:?; try destruct o eqn:?; cleanup; subst.
    all: unfold_outcome; cleanup.
    1: { (* Div *)
      simpl in *; unfold_monadic; unfold catch_return; simpl; unfold_outcome.
      destruct (_ =? _)%N eqn:?; cleanup; rewrite N.eqb_neq in *.
      assert (narg1 / narg2 <= narg1) as Hdiv_le.
      1: {
        destruct (N.eq_dec narg2 0) as [Hz | Hnz]; subst.
        - rewrite N.div_0_r; lia.
        - apply N.Div0.div_le_upper_bound.
          eapply N.le_mul_l; eauto.
      }
      eapply IH with (t := set_vars _ _) in Heval2; eauto; simpl in *; cleanup.
      2: eapply state_rel_set_vars; eauto.
      2: eapply env_rel_update; eauto; econstructor; try lia.
      with_strategy transparent [EVAL_CMD] simpl EVAL_CMD at 1.
      unfold_monadic; unfold_outcome; unfold set_vars, inc_steps_done, add_steps_done, set_steps_done in *; simpl in *.
      assert (x0 <> Stop TimeOut) as Hnotimeout by (unfold res_rel in *|-; destruct x0; simpl in *; try congruence; destruct v; congruence).
      assert (word.eqb (word.of_Z (Z.of_N narg2): word64) (word.of_Z 0) = false) as Hneq.
      1: {
        rewrite word.unsigned_eqb, Z.eqb_neq, word.unsigned_of_Z_nowrap; try lia.
        rewrite word.unsigned_of_Z_0; lia.
      }
      rewrite Hneq.
      assert (
        word.of_Z (Z.of_N (narg1 / narg2)) = word.divu (word.of_Z (Z.of_N narg1): word64) (word.of_Z (Z.of_N narg2))
      ) as <-.
      1: {
        rewrite N2Z.inj_div; eauto.
        with_strategy transparent [word.divu] simpl word.divu at 1.
        rewrite word.unsigned_eqb, word.unsigned_of_Z_0 in *.
        with_strategy transparent [word.unsigned] simpl word.unsigned in Hneq.
        rewrite Hneq.
        assert (word.unsigned (word.of_Z (Z.of_N narg1): word64) = Z.of_N narg1) as Harg1 by (rewrite Properties.word.unsigned_of_Z_nowrap; try lia).
        assert (word.unsigned (word.of_Z (Z.of_N narg2): word64) = Z.of_N narg2) as Harg2 by (rewrite Properties.word.unsigned_of_Z_nowrap; try lia).
        with_strategy transparent [word.unsigned] simpl word.unsigned in Harg1, Harg2.
        rewrite Harg1, Harg2.
        reflexivity.
      }
      unfold assign, set_vars; unfold_outcome; simpl.
      exists x; do 2 eexists.
      split; eauto.
    }
    1: {
      destruct (FunSemantics.next _) eqn:?; cleanup.
      inversion EVAL_ARGS; subst; clear H3.
      unfold FunSemantics.next in *.
      assert (∃ n1, v1 = Num n1 ∧ n1 < 2^32); cleanup; subst.
      1: destruct (FunSemantics.input s4); cleanup; eexists; split; try reflexivity; eauto.
      1: specialize N_ascii_bounded with (a := a) as ?; lia.
      eapply IH with (t := set_vars _ (set_input _ _)) in Heval2; eauto; simpl in *; cleanup.
      2: eapply state_rel_set_vars; eauto.
      2: {
        unfold state_rel in *; cleanup.
        unfold set_input, FunSemantics.set_input in *; simpl in *.
        destruct (FunSemantics.input s4); simpl in *; eauto; cleanup; subst; eauto.
      }
      2: eapply env_rel_update; eauto.
      2: econstructor; try lia.
      exists x0; do 2 eexists.
      unfold set_vars, set_input in *; simpl in *.
      split; eauto.
      unfold state_rel in *; cleanup.
      spat `input _ = _` at rewrite spat.
      destruct (FunSemantics.input s4) eqn:Heqin; simpl in *; cleanup; subst; eauto; try rewrite Heqin in *; simpl in *; eauto.
    }
    (* Write *)
    Opaque word.unsigned.
    destruct (_ <? _)%N eqn:?; cleanup; rewrite N.ltb_lt in *.
    unfold put_char, w2n in *; unfold_outcome; simpl in *.
    assert (Z.to_nat (word.unsigned (word.of_Z (Z.of_N narg1): word64)) <? 256 = true)%nat as Hlt256.
    1: {
      rewrite Nat.ltb_lt in *.
      rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia.
    }
    eapply IH with (t := set_vars _ (set_output _ _)) in Heval2; eauto; simpl in *; cleanup.
    2: eapply state_rel_set_vars; eauto.
    2: {
      unfold state_rel in *; cleanup.
      unfold set_output, FunSemantics.set_output in *; simpl in *.
      eauto.
    }
    2: eapply env_rel_update; eauto.
    2: econstructor; try lia.
    exists x; do 2 eexists.
    rewrite Hlt256.
    unfold_monadic; unfold_outcome; unfold assign, set_vars in *; simpl in *.
    split; eauto.
    unfold state_rel in *; cleanup.
    spat `output _ = _` at rewrite spat.
    rewrite word.unsigned_of_Z_nowrap in *; try lia.
    rewrite N2Z.id in *; eauto.
  - (* If *)
    destruct to_exp eqn:Hto_exp; try discriminate; cleanup.
    unfold option_bind in *; cleanup.
    destruct to_guard eqn:Hto_guard; try discriminate; cleanup.
    destruct to_cmd eqn:Hto_cmd1; try discriminate; cleanup.
    destruct (to_cmd expf) eqn:Hto_cmd2; try discriminate; cleanup.
    unfold to_guard in Hto_guard; cleanup.
    destruct to_exps as [conds_vs|] eqn:Hto_exps; try discriminate; cleanup.
    destruct conds_vs as [|cond_v1 conds_vs1] eqn:?; try discriminate; simpl in *; cleanup.
    destruct conds_vs1 as [|cond_v2 conds_vs1]; try discriminate; simpl in *; cleanup.
    destruct conds_vs1; try discriminate; simpl in *; cleanup.
    eapply to_exps_thm in Hto_exps; eauto; cleanup; subst.
    specialize list_rel_length_same with (1:= H1) as Hlen.
    specialize Eval_length with (1 := Heval1) as Hlen_eval.
    Transparent eval_exps.
    simpl in *; unfold_monadic; unfold_outcome.
    destruct eval_exp eqn:?; destruct o eqn:?; cleanup; subst.
    destruct (eval_exp cond_v2) eqn:?; destruct o eqn:?; cleanup; subst.
    destruct vs as [|v1 vs]; try discriminate; cleanup.
    destruct vs as [|v2 vs]; try discriminate; cleanup.
    destruct vs; try discriminate; cleanup.
    destruct exps as [|e1 exps]; try discriminate; cleanup.
    destruct exps as [|e2 exps]; try discriminate; cleanup.
    destruct exps; try discriminate; cleanup.
    destruct b.
    + (* then branch *)
      eapply IH in Hto_cmd1; cleanup; eauto; simpl in *; cleanup.
      destruct eval_cmp eqn:?; unfold eval_cmp in *; simpl in *; unfold_monadic; unfold_outcome.
      destruct test eqn:?; simpl in *.
      1: { (* Less *)
        unfold take_branch in *; destruct v1; unfold_outcome; try discriminate; destruct v2; unfold_outcome; try discriminate; simpl in *; unfold return_ in *; cleanup; inversion H3; inversion H1; subst.
        assert (Z.of_N n <? Z.of_N n0 = true)%Z as Hlt by (rewrite N.ltb_lt, Z.ltb_lt in *; rewrite <- N2Z.inj_lt; eauto); cleanup.
        rewrite word.unsigned_ltu; try lia; do 2 (rewrite Properties.word.unsigned_of_Z_nowrap; try lia); rewrite Hlt.
        do 3 eexists.
        rewrite H.
        split; [reflexivity|].
        split; [|assumption].
        eauto.
      }
      unfold take_branch in *; destruct v1; unfold_outcome; try discriminate; destruct v2; unfold_outcome; try discriminate; simpl in *; unfold return_ in *; cleanup; inversion H3; inversion H1; subst.
      1: destruct n; try discriminate.
      cleanup.
      assert (Z.of_N n =? Z.of_N n0 = true)%Z as Hlt by (rewrite N.eqb_eq, Z.eqb_eq in *; subst; eauto).
      rewrite word.unsigned_eqb; try lia; do 2 (rewrite Properties.word.unsigned_of_Z_nowrap; try lia); rewrite Hlt.
      do 3 eexists.
      rewrite H.
      split; [reflexivity|].
      split; [|assumption].
      eauto.
    + (* else branch *)
      eapply IH in Hto_cmd2; cleanup; eauto; simpl in *; cleanup.
      destruct eval_cmp eqn:?; unfold eval_cmp in *; simpl in *; unfold_monadic; unfold_outcome.
      destruct test eqn:?; simpl in *.
      1: { (* Less *)
        unfold take_branch in *; destruct v1; unfold_outcome; try discriminate; destruct v2; unfold_outcome; try discriminate; simpl in *; unfold return_ in *; cleanup; inversion H3; inversion H1; subst.
        assert (Z.of_N n <? Z.of_N n0 = false)%Z as Hlt by (rewrite N.ltb_ge, Z.ltb_ge in *; rewrite <- N2Z.inj_le; eauto); cleanup.
        rewrite word.unsigned_ltu; try lia; do 2 (rewrite Properties.word.unsigned_of_Z_nowrap; try lia); rewrite Hlt.
        do 3 eexists.
        rewrite H.
        split; [reflexivity|].
        split; [|assumption].
        eauto.
      }
      unfold take_branch in *; destruct v1; unfold_outcome; try discriminate; destruct v2; unfold_outcome; try discriminate; simpl in *; unfold return_ in *; cleanup; inversion H3; inversion H1; subst.
      1: destruct n; try discriminate.
      all: cleanup.
      2: assert (Z.of_N n =? Z.of_N n0 = false)%Z as Hlt by (rewrite N.eqb_neq, Z.eqb_neq in *; rewrite N2Z.inj_iff; eauto).
      2: rewrite word.unsigned_eqb; try lia; do 2 (rewrite Properties.word.unsigned_of_Z_nowrap; try lia); rewrite Hlt.
      1: assert (Z.of_N 0 = 0%Z) as Htmp by lia; rewrite Htmp in *; clear Htmp.
      1: rewrite word.unsigned_eqb in *; try lia; rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia; simpl in *; cleanup.
      all: do 3 eexists.
      all: rewrite H.
      all: split; [reflexivity|].
      all: split; [|assumption].
      all: eauto.
    - (* Call *)
      destruct to_exp eqn:Hto_exp; try discriminate; cleanup.
      destruct to_exps eqn:Hto_exps; try discriminate; cleanup.
      simpl in *; cleanup.
      eapply to_exps_thm in Hto_exps; eauto; cleanup; subst.
      specialize list_rel_length_same with (1:= H1) as Hlen.
      unfold env_and_body in *; destruct lookup_fun as [ [fparams fbody] | ] eqn:Hlookup_fun; try discriminate; cleanup.
      destruct (_ =? _)%nat eqn:Hlen_params; rewrite ?Nat.eqb_eq in *; try discriminate; cleanup.
      simpl in *; cleanup; unfold_monadic; simpl; unfold_monadic; unfold_outcome.
      unfold get_vars, get_body_and_set_vars, set_varsM, assign, catch_return, set_vars; simpl; unfold_outcome.
      specialize func_rel_from_state_rel with (1:= Hstate_rel) as Hfunc_rel.
      eapply Hfunc_rel in Hlookup_fun; cleanup; clear Hfunc_rel.
      eapply IH with (t := set_vars _ (set_steps_done _ _)) in Heval2; eauto; cleanup; simpl in *; cleanup.
      3: eapply env_rel_make_env; eauto; congruence.
      2: eapply state_rel_set_vars; eauto.
      pat `eval_cmd _ (EVAL_CMD ?f) (set_vars _ _) = _` at rename f into fuel0.
      unfold res_rel in *|-; simpl in *; cleanup.
      eapply env_rel_mem_prefix in Henv_rel; eauto.
      destruct x2; cleanup; destruct v; cleanup; eauto.
      2: { (* Abort *)
        exists (S fuel0); do 2 eexists.
        rewrite H.
        rewrite H0.
        spat `NoDup` at eapply nodup_fixed_point in spat; rewrite spat.
        rewrite Hlen_params, Hlen; rewrite Nat.eqb_refl; simpl; unfold nodupb.
        with_strategy transparent [EVAL_CMD] simpl.
        unfold_monadic; unfold_outcome; unfold set_vars, inc_steps_done, add_steps_done, set_steps_done in *; simpl in *.
        rewrite H4; unfold res_rel in *|-; simpl in *; cleanup.
        split; eauto; split; eauto; simpl; eauto.
      }
      exists (S (fuel0)); do 2 eexists.
      Opaque EVAL_CMD.
      rewrite H.
      rewrite H0.
      spat `NoDup` at eapply nodup_fixed_point in spat; rewrite spat.
      rewrite Hlen_params, Hlen; rewrite Nat.eqb_refl; simpl; unfold nodupb.
      with_strategy transparent [EVAL_CMD] simpl EVAL_CMD at 1.
      unfold_monadic; unfold_outcome; unfold set_vars, inc_steps_done, add_steps_done, set_steps_done in *; simpl in *.
      rewrite H4; unfold res_rel in *|-; simpl in *; cleanup.
      split; eauto.
      split; eauto.
      unfold res_rel; simpl; eauto.
Admitted.

Theorem to_imp_thm: forall input prog output imp_prog,
  FunSemantics.prog_terminates input prog output ∧ to_imp prog = Some imp_prog ->
  imp_weak_termination input imp_prog output.
Proof.
Admitted.
