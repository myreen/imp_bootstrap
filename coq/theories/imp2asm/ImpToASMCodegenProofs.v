Require Import impboot.utils.Core.
Require Import impboot.utils.Env.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.imperative.ImpSemantics.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMSemantics.

Require Import Patmycoq.Patmycoq.

(* Definitions of invariants and relations *)

(* Checks that the sequence xs appears at index n in the code list. *)
Fixpoint code_in (n : nat) (xs : list instr) (code : list instr) : Prop :=
  match xs with
  | [] => True
  | x :: xs' => nth_error code n = Some x /\ code_in (n + 1) xs' code
  end.

(* Declares that there exists a starting position where the initial code fragment appears in instructions. *)
Definition init_code_in (instructions : list instr) : Prop :=
  exists start, code_in 0 (init start) instructions.

(* Looks up the function with identifier n in a list of funcs and returns its parameters and body if found. *)
Fixpoint lookup_fun (n : nat) (ds : list func) : option (list name * cmd) :=
  match ds with
  | [] => None
  | (Func fname params body) :: ds =>
    if eqb fname n then Some (params, body)
    else lookup_fun n ds
  end.

(* Finds the position of function n in f_lookup if it exists. *)
Fixpoint lookup_f (n : nat) (fs : f_lookup) : option nat :=
  match fs with
  | [] => None
  | (fname, pos) :: fs =>
    if eqb fname n then Some pos
    else lookup_f n fs
  end.

(* Ensures initial instructions are present and that each function in ds has its compiled form in instructions. *)
Definition code_rel (fs : f_lookup) (ds : list func) (instructions : list instr) : Prop :=
  init_code_in instructions /\
  forall n params body,
    lookup_fun n ds = Some (params, body) ->
    exists pos,
      lookup_f n fs = Some pos /\
      code_in pos (flatten (fst (c_fundef (Func n params body) pos fs))) instructions.

(* Establishes a relation between an imperative state and an ASM state, including code alignment and register setup. *)
Definition state_rel (fs : f_lookup) (s : ImpSemantics.state) (t : ASMSemantics.state) : Prop :=
  s.(ImpSemantics.input) = t.(input) /\
  s.(ImpSemantics.output) = t.(output) /\
  code_rel fs s.(funs) t.(instructions) /\
  exists r14 r15,
    t.(regs) R12 = Some (word.of_Z 16%Z) /\
    t.(regs) R13 = Some (word.of_Z 0x7FFFFFFFFFFFFFFF%Z) /\
    t.(regs) R14 = Some r14 /\
    t.(regs) R15 = Some r15 /\
    memory_writable r14 r15 t.(memory).

(* Asserts that the given list of words matches the current stack content and RAX register in state t. *)
Definition has_stack (t : ASMSemantics.state) (xs : list word_or_ret) : Prop :=
  exists w ws,
    xs = Word w :: ws /\
    t.(regs) RAX = Some w /\
    t.(stack) = ws.

Definition opt_rel {A B} (P: A -> B -> Prop) (oa: option A) (ob: option B): Prop :=
  match oa, ob with
  | None, None => True
  | Some a, Some b => P a b
  | _, _ => False
  end.

Definition v_inv (pmap: nat -> option (word64 * nat))
  (v: Value) (w: word64): Prop :=
  match v with
  | ImpSyntax.Word v => w = v
  | Pointer p => exists length,
    pmap p = Some (w, length)
  end.

Definition mem_inv (pmap: nat -> option (word64 * nat))
  (asmm: word64 -> option (option word64))
  (impm: list (list (option Value))): Prop :=
  forall p v,
    List.nth_error impm p = Some v ->
    exists base,
      pmap p = Some (base, List.length v) /\
      forall off xopt,
        List.nth_error v off = Some xopt ->
        exists yopt,
          asmm (word.add base (word.of_Z (Z.of_nat (off * 8)))) = Some yopt /\
          opt_rel (v_inv pmap) xopt yopt.

(* Checks that environment variables map to valid locations and values on the stack in the ASM state. *)
Definition env_ok (env : IEnv.env) (vs : list (option nat)) (curr : list word_or_ret)
  (pmap: nat -> option (word64 * nat))
  (asmm : word64 -> option (option word64))
  (impm: list (list (option Value))): Prop :=
  List.length vs = List.length curr /\
  forall n v,
    IEnv.lookup env n = Some v ->
    index_of n 0 vs < List.length curr /\
    exists w,
      nth_error curr (index_of n 0 vs) = Some (Word w) /\
      v_inv pmap v w.

Definition cmd_res_rel (ri: result unit) (l1: nat)
  (curr: list word_or_ret) (rest: list word_or_ret) (vs: v_stack) (t1: ASMSemantics.state) (s1: ImpSemantics.state)
  (pmap: nat -> option (word64 * nat)) : Prop :=
  match ri with
  | Stop (Return v) => exists w,
    v_inv pmap v w /\
    mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
    has_stack t1 (Word w :: curr ++ rest) /\
    t1.(pc) = l1
  | Interm _ => exists curr1,
    has_stack t1 (curr1 ++ rest) /\
    env_ok s1.(vars) vs curr1 pmap t1.(memory) s1.(ImpSemantics.memory) /\
    t1.(pc) = l1
  | _ => True (* TODO(kπ) is this correct? *)
  end.

Definition exp_res_rel (ri: result Value) (l1: nat)
  (stck: list word_or_ret) (t1: ASMSemantics.state) (s1: ImpSemantics.state)
  (pmap: nat -> option (word64 * nat)) : Prop :=
  match ri with
  | Interm v => exists w,
    v_inv pmap v w /\
    mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
    has_stack t1 (Word w :: stck) /\
    t1.(pc) = l1
  | _ => False
  end.

Fixpoint addresses_of (base: word64) (length: nat): list word64 :=
  match length with
  | 0 => []
  | S n => base :: addresses_of (word.add base (word.of_Z 8)) (n)
  end.

Definition pmap_ok (pmap: nat -> option (word64 * nat)): Prop :=
  forall p1 p2 base1 len1 base2 len2,
    pmap p1 = Some (base1, len1) /\ pmap p2 = Some (base2, len2) ->
    forall addr,
      List.existsb (word.eqb addr) (addresses_of base1 len1) = true /\
      List.existsb (word.eqb addr) (addresses_of base2 len2) = true ->
      p1 = p2.

Definition pmap_subsume (pmap: nat -> option (word64 * nat))
  (pmap1: nat -> option (word64 * nat)): Prop :=
  forall p v,
    pmap p = Some v ->
    pmap1 p = Some v.

(* Goals *)

Definition goal_exp (e : exp): Prop :=
  forall (s s1 : ImpSemantics.state) (fuel fuel1: nat)
         (res : result Value) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret)
         (pmap: nat -> option (word64 * nat)),
    eval_exp e s = (res, s1) ->
    res <> Stop Crash ->
    c_exp e t.(pc) vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr pmap t.(memory) s.(ImpSemantics.memory) ->
    has_stack t (curr ++ rest) ->
    mem_inv pmap t.(memory) s.(ImpSemantics.memory) ->
    pmap_ok pmap ->
    odd (List.length rest) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome,
      steps (State t, fuel) outcome /\
      match outcome with
      | (Halt ec output, fuel) => False
      | (State t1, fuel1) =>
          state_rel fs s1 t1 /\
          fuel1 = fuel /\
          exp_res_rel res l1 (curr ++ rest) t1 s1 pmap
      end.

Definition goal_test (tst: test): Prop :=
  forall (s s1 : ImpSemantics.state) (fuel fuel1: nat)
         (b : bool) (t t1 : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 ltrue lfalse : nat)
         (curr rest : list word_or_ret)
         (pmap: nat -> option (word64 * nat)),
    eval_test tst s = (Interm b, s1) ->
    c_test_jump tst ltrue lfalse t.(pc) vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr pmap t.(memory) s.(ImpSemantics.memory) ->
    has_stack t (curr ++ rest) ->
    mem_inv pmap t.(memory) s.(ImpSemantics.memory) ->
    pmap_ok pmap ->
    odd (List.length rest) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome,
      steps (State t, fuel) outcome /\
      match outcome with
      | (Halt ec output, fuel) => False
      | (State t1, fuel1) =>
        state_rel fs s1 t1 /\
        fuel1 = fuel /\
        mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
        has_stack t1 (curr ++ rest) /\
        t1.(pc) = if b then ltrue else lfalse
      end.

Definition goal_cmd (c : cmd) (fuel: nat): Prop :=
  forall (s s1 : ImpSemantics.state) (fuel1: nat)
         (res : result unit) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret)
         (pmap: nat -> option (word64 * nat)),
    EVAL_CMD fuel c s = ((res, s1), fuel1) ->
    res <> Stop Crash ->
    c_cmd c t.(pc) fs vs = (asmc, l1, vs') ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr pmap t.(memory) s.(ImpSemantics.memory) ->
    has_stack t (curr ++ rest) ->
    mem_inv pmap t.(memory) s.(ImpSemantics.memory) ->
    pmap_ok pmap ->
    odd (List.length rest) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome pmap1,
      steps (State t, fuel) outcome /\
      pmap_ok pmap1 /\
      pmap_subsume pmap pmap1 /\
      match outcome with
      | (Halt ec output, ck) =>
        prefix output (string_of_list_ascii s1.(ImpSemantics.output)) = true /\
        (ec = (word.of_Z 1) \/ ec = (word.of_Z 4))
      | (State t1, ck) =>
        fuel1 = ck /\
        state_rel fs s1 t1 /\
        cmd_res_rel res l1 curr rest vs' t1 s1 pmap1
      end.

(* proofs *)

Ltac unfold_outcome :=
  unfold interm, contdf, crash, stop in *.

Ltac unfold_stack :=
  unfold inc, set_stack, set_input, set_memory, set_pc,
          set_vars, set_varsM, set_output, write_reg, write_mem in *; simpl.

Ltac cleanup :=
  repeat match goal with
  | [ H: _ /\ _ |- _ ] => destruct H
  | [ H: exists _, _ |- _ ] => destruct H
  | [ H: True |- _ ] => clear H
  | [ H: (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ H: _ :: _ = _ :: _ |- _ ] => inversion H; subst; clear H
  end.

Theorem rw_mod_2_even: forall (n: nat),
  (n mod 2 = 0) <-> (even n = true).
Proof.
  split.
  - revert n.
    fix IH 1.
    destruct n.
    + reflexivity.
    + intros.
      destruct n.
      * inversion H.
      * simpl.
        eapply IH.
        change ((1 * 2 + n) mod 2 = 0) in H.
        rewrite Nat.add_comm in H.
        rewrite Nat.Div0.mod_add in H.
        assumption.
  - revert n.
    fix IH 1.
    destruct n.
    + reflexivity.
    + intros.
      destruct n.
      * inversion H.
      * simpl in H.
        change ((1 * 2 + n) mod 2 = 0).
        rewrite Nat.add_comm.
        rewrite Nat.Div0.mod_add.
        eapply IH.
        simpl.
        assumption.
Qed.

Theorem give_up: forall fs ds t w n,
  code_rel fs ds t.(instructions) ->
  t.(regs) R15 = Some w ->
  t.(pc) = give_up (odd (List.length t.(stack))) ->
  steps (State t, n) (Halt (word.of_Z 4) (string_of_list_ascii t.(output)), n).
Proof.
  intros.
  unfold give_up in *.
  unfold code_rel in *.
  unfold init_code_in, init in *.
  unfold code_in in *.
  cleanup.
  destruct (odd (List.length (stack t))) eqn:?.
  1: {
    eapply steps_trans.
    - eapply steps_step_same.
      eapply step_push; eauto.
      unfold fetch; rewrite H1; eauto.
    - eapply steps_trans.
      + eapply steps_step_same.
        eapply step_const; eauto.
        unfold_stack.
        unfold fetch; rewrite H1; eauto.
      + eapply steps_step_same.
        eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 4)
        (inc (set_stack (Word w :: stack t) (inc t))))).
        1: unfold fetch; unfold_stack; simpl; rewrite H1; eauto.
        1: unfold_stack; simpl; eauto.
        rewrite rw_mod_2_even.
        simpl in *.
        destruct (List.length (stack t)); [tauto|].
        rewrite Nat.odd_succ in *.
        assumption.
  }
  eapply steps_trans.
  + eapply steps_step_same.
    eapply step_const; eauto.
    unfold_stack.
    unfold fetch; rewrite H1; eauto.
  + eapply steps_step_same.
    eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 4) (inc t))).
    1: unfold fetch; unfold_stack; simpl; rewrite H1; eauto.
    1: unfold_stack; simpl; eauto.
    rewrite rw_mod_2_even.
    simpl in *.
    rewrite <- Nat.negb_odd in *.
    rewrite Heqb.
    tauto.
Qed.

Theorem abort: forall fs ds t w n,
  code_rel fs ds t.(instructions) ->
  t.(regs) R15 = Some w ->
  t.(pc) = abort (odd (List.length t.(stack))) ->
  steps (State t, n) (Halt (word.of_Z 1) (string_of_list_ascii t.(output)), n).
Proof.
  intros.
  unfold abort in *.
  unfold code_rel in *.
  unfold init_code_in, init in *.
  unfold code_in in *.
  cleanup.
  destruct (odd (List.length (stack t))) eqn:?.
  1: {
    eapply steps_trans.
    - eapply steps_step_same.
      eapply step_push; eauto.
      unfold fetch; rewrite H1; eauto.
    - eapply steps_trans.
      + eapply steps_step_same.
        eapply step_const; eauto.
        unfold_stack.
        unfold fetch; rewrite H1; eauto.
      + eapply steps_step_same.
        eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 1)
        (inc (set_stack (Word w :: stack t) (inc t))))).
        1: unfold fetch; unfold_stack; simpl; rewrite H1; eauto.
        1: unfold_stack; simpl; eauto.
        rewrite rw_mod_2_even.
        simpl in *.
        destruct (List.length (stack t)); [tauto|].
        rewrite Nat.odd_succ in *.
        assumption.
  }
  eapply steps_trans.
  + eapply steps_step_same.
    eapply step_const; eauto.
    unfold_stack.
    unfold fetch; rewrite H1; eauto.
  + eapply steps_step_same.
    eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 1) (inc t))).
    1: unfold fetch; unfold_stack; simpl; rewrite H1; eauto.
    1: unfold_stack; simpl; eauto.
    rewrite rw_mod_2_even.
    simpl in *.
    rewrite <- Nat.negb_odd in *.
    rewrite Heqb.
    tauto.
Qed.

Theorem even_len_spec_str: forall {A} (l: list A),
  (forall x, even_len (x :: l) = even (List.length (x :: l))) ∧
  even_len l = even (List.length l).
Proof.
  induction l.
  - split; reflexivity.
  - simpl even_len.
    destruct l; try reflexivity; split.
    all: unfold list_CASE; cbv beta.
    all: cleanup; try reflexivity; intros.
    all: eapply eq_sym.
    all: rewrite length_cons.
    all: rewrite length_cons.
    all: rewrite Nat.even_succ.
    all: rewrite Nat.odd_succ.
    all: eapply eq_sym.
    1: assumption.
    eapply H with (x := a).
Qed.

Theorem even_len_spec: forall {A} (l: list A),
  even_len l = even (List.length l).
Proof.
  intros.
  eapply even_len_spec_str.
Qed.

Theorem odd_len_spec_str: forall {A} (l: list A),
  (forall x, odd_len (x :: l) = odd (List.length (x :: l))) ∧
  odd_len l = odd (List.length l).
Proof.
  induction l.
  - split; reflexivity.
  - simpl odd_len.
    destruct l; try reflexivity; split.
    all: unfold list_CASE; cbv beta.
    all: cleanup; try reflexivity; intros.
    all: eapply eq_sym.
    all: rewrite length_cons.
    all: rewrite length_cons.
    all: rewrite Nat.odd_succ.
    all: rewrite Nat.even_succ.
    all: eapply eq_sym.
    1: assumption.
    eapply H with (x := a).
Qed.

Theorem odd_len_spec: forall {A} (l: list A),
  odd_len l = odd (List.length l).
Proof.
  intros.
  eapply odd_len_spec_str.
Qed.

Theorem has_stack_even: forall t xs,
  has_stack t xs -> even (List.length t.(stack)) = odd (List.length xs).
Proof.
  intros.
  unfold has_stack in *; cleanup.
  subst.
  rewrite length_cons.
  rewrite <- Nat.odd_succ.
  reflexivity.
Qed.

Theorem substring_noop: forall s,
  substring 0 (length s) s = s.
Proof.
  induction s.
  - simpl; reflexivity.
  - simpl; f_equal; assumption.
Qed.

Ltac bound_crunch :=
  intros;
  try rewrite word.unsigned_ltu in *;
  try rewrite word.unsigned_of_Z in *;
  try unfold word.wrap in *;
  (* THIS IS HORRIBLY SLOW *)
  cbn in *;
  lia.

Theorem sub_lt_bound: forall (a b: Z),
  (0 <= a)%Z ->
  (0 <= b)%Z ->
  (a <? b)%Z = true ->
  (a <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true ->
  (b <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true ->
  ((b - a) mod Z.pow_pos 2 64 <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true.
Proof.
  intros.
  rewrite Z.ltb_lt in *.
  (* THIS IS HORRIBLY SLOW *)
  cbn in *.
  assert ((b - a) < Z.pow_pos 2 63)%Z.
  2: rewrite Z.mod_small; eauto; try lia.
  unfold Z.pow_pos; simpl.
  apply Z.le_lt_trans with (m := b).
  - lia.
  - assumption.
Qed.

Theorem z_lt_bound: forall (z: Z),
  word.ltu (word.of_Z (2 ^ 63 - 1)) ((Naive.wrap z): word64) = false ->
  (z mod Z.pow_pos 2 64 <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true.
Proof.
  intros.
  rewrite word.unsigned_ltu in *.
  rewrite word.unsigned_of_Z in *.
  unfold word.wrap in *.
  (* THIS IS HORRIBLY SLOW *)
  cbn in *.
  lia.
Qed.

Theorem w_lt_bound: forall (w: word64),
  (word.ltu (word.of_Z (2 ^ 63 - 1)) w = false \/
    word.ltu w (word.of_Z (2 ^ 63)) = true) ->
  word.ltu w (word.of_Z (2 ^ 63)) = true /\
  (Naive.unsigned w <? Z.pow_pos 2 63 mod Z.pow_pos 2 64)%Z = true.
Proof.
  intros.
  rewrite word.unsigned_ltu in *.
  rewrite word.unsigned_of_Z in *.
  unfold word.wrap in *.
  (* THIS IS HORRIBLY SLOW *)
  cbn in *.
  lia.
Qed.

Theorem c_exp_length: forall e l vs c l1,
  c_exp e l vs = (c, l1) -> l1 = l + List.length (flatten c).
Proof.
  induction e.
  all: intros.
  all: simpl c_exp in *.
  all: repeat match goal with
  | [ H : context[(if ?x then _ else _)] |- _ ] => destruct x eqn:?
  | [ H : context [(match ?x with | _ => _ end)] |- _ ] => destruct x eqn:?
  | [ H : (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ |- context[ fst ?x ] ] => destruct x eqn:?; simpl in *
  | [ H : c_exp _ _ (None :: _) = (_, _) |- _ ] => eapply IHe2 in H; subst
  | [ H : c_exp _ _ ?_l = (_, _) |- _ ] => eapply IHe1 in H; subst
  | _ => progress unfold c_var, c_const, dlet in *
  | _ => progress simpl in *
  | _ => progress rewrite length_app
  | _ => lia
  end.
Qed.

Theorem c_exps_length: forall e l vs c l1,
  c_exps e l vs = (c, l1) -> l1 = l + List.length (flatten c).
Proof.
  induction e.
  all: intros.
  all: simpl c_exps in *.
  all: repeat match goal with
  | [ H : (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ |- context[ fst ?x ] ] => destruct x eqn:?; simpl in *
  | [ H : c_exps _ _ _ = (_, _) |- _ ] => eapply IHe in H; subst
  | [ H : c_exp _ _ _ = (_, _) |- _ ] =>
    eapply c_exp_length in H; subst
  | _ => progress unfold c_var, c_const, dlet in *
  | _ => progress simpl in *
  | _ => progress rewrite length_app
  | _ => lia
  end.
Qed.

Theorem c_test_length: forall tst lt lf l vs c l1,
  c_test_jump tst lt lf l vs = (c, l1) -> l1 = l + List.length (flatten c).
Proof.
  induction tst.
  all: intros.
  all: simpl c_test_jump in *.
  all: repeat match goal with
  | [ H : context[(if ?x then _ else _)] |- _ ] => destruct x eqn:?
  | [ H : context [(match ?x with | _ => _ end)] |- _ ] => destruct x eqn:?
  | [ H : (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ |- context[ fst ?x ] ] => destruct x eqn:?; simpl in *
  | [ H : c_test_jump _ _ _ _ _ = (_, _) |- _ ] => eapply IHtst2 in H; subst
  | [ H : c_test_jump _ _ _ _ _ = (_, _) |- _ ] => eapply IHtst1 in H; subst
  | [ H : c_test_jump _ _ _ _ _ = (_, _) |- _ ] => eapply IHtst in H; subst
  | [ H: c_exp _ _ _ = (_, _) |- _ ] =>
    eapply c_exp_length in H; subst
  | _ => progress unfold c_var, c_const, dlet in *
  | _ => progress simpl in *
  | _ => progress rewrite length_app
  | _ => lia
  end.
Qed.

Theorem app_list_length_spec: forall {A} (l: app_list A),
  app_list_length l = List.length (flatten l).
Proof.
  induction l; simpl; eauto.
  rewrite IHl1; rewrite IHl2.
  rewrite length_app.
  reflexivity.
Qed.

Theorem c_cmd_length: forall c l fs vs l1 asm1 vs1,
  c_cmd c l fs vs = (asm1, l1, vs1) -> l1 = l + List.length (flatten asm1).
Proof.
  induction c.
  all: intros.
  all: simpl c_cmd in *.
  all: repeat match goal with
  | [ H : context[(if ?x then _ else _)] |- _ ] => destruct x eqn:?
  | [ |- context[(if ?x then _ else _)] ] => destruct x eqn:?
  | [ H : context [(match ?x with | _ => _ end)] |- _ ] => destruct x eqn:?
  | [ H : (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ |- context[ fst ?x ] ] => destruct x eqn:?; simpl in *; subst
  | [ H: context[ fst ?x ] |- _ ] => destruct x eqn:?; simpl in *; subst
  | [ H : c_cmd _ _ _ _ = (_, _, _) |- _ ] => eapply IHc2 in H; subst
  | [ H : c_cmd _ _ _ _ = (_, _, _) |- _ ] => eapply IHc1 in H; subst
  | [ H : c_cmd _ _ _ _ = (_, _, _) |- _ ] => eapply IHc in H; subst
  | [ H: c_exp _ _ _ = (_, _) |- _ ] =>
    eapply c_exp_length in H; subst
  | [ H: c_exps _ _ _ = (_, _) |- _ ] =>
    eapply c_exps_length in H; subst
  | [ H: c_test_jump _ _ _ _ _ = (_, _) |- _ ] =>
    eapply c_test_length in H; subst
  | _ => progress unfold align, dlet, c_alloc, c_assign, c_var in *
  | _ => progress simpl in *
  | _ => progress rewrite length_app
  | _ => progress rewrite app_list_length_spec
  | _ => rewrite Nat.add_assoc
  | _ => lia
  end.
Qed.

Theorem code_in_append: forall xs ys n code,
    code_in n (xs ++ ys) code <->
    (code_in n xs code ∧ code_in (n + List.length xs) ys code).
Proof.
  induction xs; intros; simpl.
  - split; intros; cleanup; try split; eauto.
    all: rewrite Nat.add_0_r in *; eauto.
  - split; intros; cleanup.
    + repeat split; eauto.
      all: eapply IHxs in H0; cleanup; eauto.
      rewrite <- Nat.add_1_l.
      rewrite Nat.add_assoc.
      eauto.
    + repeat split; eauto.
      all: eapply IHxs; cleanup; eauto.
      repeat split; eauto.
      rewrite <- Nat.add_1_l in H0.
      rewrite Nat.add_assoc in H0.
      eauto.
Qed.

Theorem eval_exp_not_stop: forall e s res s1 v,
  eval_exp e s = (res, s1) ->
  res ≠ Stop Crash ->
  res <> Stop v.
Proof.
  induction e; intros.
  all: simpl eval_exp in *.
  all: unfold lookup_var, bind in *; unfold_outcome; simpl in *.
  - destruct (IEnv.lookup (vars s) n) eqn:?.
    all: inversion H; subst; congruence.
  - congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; subst; eauto.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; subst; eauto.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; subst; eauto.
    destruct (value_eqb v1 (ImpSyntax.Word (Naive.wrap 0))) eqn:?.
    1: congruence.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; subst; eauto.
    unfold mem_load in *.
    destruct v0; unfold_outcome.
    1: congruence.
    destruct v1; unfold_outcome.
    2: congruence.
    destruct (negb (w2n w mod 8 =? 0)) eqn:?.
    1: congruence.
    destruct (nth_error (ImpSemantics.memory s2) i) eqn:?.
    2: congruence.
    destruct (nth_error _ (w2n w / 8)) eqn:?.
    2: congruence.
    destruct o eqn:?.
    all: congruence.
Qed.

Theorem eval_exp_not_contdf: forall e s res s1 c cnt,
  eval_exp e s = (res, s1) ->
  res <> ContDF c cnt.
Proof.
  induction e; intros.
  all: simpl eval_exp in *.
  all: unfold lookup_var, bind in *; unfold_outcome; simpl in *.
  - destruct (IEnv.lookup _ _); unfold_outcome; cleanup; congruence.
  - congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; subst; eauto.
    unfold combine_word in *.
    destruct v; unfold_outcome.
    2: congruence.
    destruct v0; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; subst; eauto.
    unfold combine_word in *.
    destruct v; unfold_outcome.
    2: congruence.
    destruct v0; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; subst; eauto.
    destruct (value_eqb v0 (ImpSyntax.Word (Naive.wrap 0))) eqn:?.
    1: congruence.
    unfold combine_word in *.
    destruct v; unfold_outcome.
    2: congruence.
    destruct v0; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; subst; eauto.
    unfold mem_load in *.
    destruct v; unfold_outcome.
    1: congruence.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct (negb (w2n w mod 8 =? 0)) eqn:?.
    1: congruence.
    destruct (nth_error (ImpSemantics.memory s2) i) eqn:?.
    2: congruence.
    destruct (nth_error _ (w2n w / 8)) eqn:?.
    2: congruence.
    destruct o eqn:?.
    all: congruence.
Qed.

Theorem eval_test_not_stop: forall t s res s1 v,
  eval_test t s = (res, s1) ->
  res ≠ Stop Crash ->
  res <> Stop v.
Proof.
  induction t; intros.
  all: simpl eval_test in *.
  all: unfold lookup_var, bind in *; unfold_outcome; simpl in *.
  - destruct eval_exp eqn:?; destruct r eqn:?; cleanup.
    all: eapply eval_exp_not_stop in Heqp; eauto; try congruence.
    destruct eval_exp eqn:?; destruct r0 eqn:?; subst; cleanup.
    all: eapply eval_exp_not_stop in Heqp0; eauto; try congruence.
    destruct c eqn:?; simpl in *; cleanup.
    all: destruct v0 eqn:?; destruct v1 eqn:?; subst; cleanup.
    all: unfold_outcome; cleanup; try congruence.
  - destruct eval_test eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt1 in Heqp; eauto.
    destruct (eval_test t2) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt2 in Heqp0; eauto.
    congruence.
  - destruct eval_test eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt1 in Heqp; eauto.
    destruct (eval_test t2) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt2 in Heqp0; eauto.
    congruence.
  - destruct eval_test eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt in Heqp; eauto.
    congruence.
  (* TODO(kπ) Does this imply some sort of error? *)
  Unshelve.
  + exact Abort.
  + exact Abort.
  + exact Abort.
  + exact Abort.
Qed.

Theorem eval_test_not_contdf: forall t s res s1 c cnt,
  eval_test t s = (res, s1) ->
  res <> ContDF c cnt.
Proof.
  induction t; intros.
  all: simpl eval_test in *.
  all: unfold lookup_var, bind in *; unfold_outcome; simpl in *.
  - destruct eval_exp eqn:?; destruct r eqn:?; cleanup.
    all: eapply eval_exp_not_contdf in Heqp; eauto; try congruence.
    destruct eval_exp eqn:?; destruct r0 eqn:?; subst; cleanup.
    all: eapply eval_exp_not_contdf in Heqp0; eauto; try congruence.
    destruct c eqn:?; simpl in *; cleanup.
    all: destruct v0 eqn:?; destruct v eqn:?; subst; cleanup.
    all: unfold_outcome; cleanup; try congruence.
  - destruct eval_test eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt1 in Heqp; eauto.
    destruct (eval_test t2) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt2 in Heqp0; eauto.
    congruence.
  - destruct eval_test eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt1 in Heqp; eauto.
    destruct (eval_test t2) eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt2 in Heqp0; eauto.
    congruence.
  - destruct eval_test eqn:?; destruct r eqn:?; subst; cleanup.
    2,3: unfold not; intros; subst; eapply IHt in Heqp; eauto.
    congruence.
  (* TODO(kπ) Does this imply some sort of error? *)
  Unshelve.
  all: eauto.
Qed.

Theorem mem_inv_pmap_subsume: forall pmap pmap1 asmm impm,
  mem_inv pmap asmm impm ->
  pmap_subsume pmap pmap1 ->
  mem_inv pmap1 asmm impm.
Proof.
  intros.
  unfold mem_inv, pmap_subsume in *.
  intros.
  eapply H in H1; clear H.
  cleanup.
  eexists; eauto.
  split; eauto.
  intros.
  eapply H1 in H2; clear H1.
  cleanup.
  eexists; eauto.
  split; eauto.
  unfold opt_rel in *.
  destruct xopt eqn:?; destruct x0 eqn:?.
  1: unfold v_inv in *; simpl; destruct v0 eqn:?; cleanup; eauto.
  all: try assumption.
Qed.

(* Theorem mem_inv_asmm_IMP: forall pmap (impm : list mem_block) asmm asmm1,
  mem_inv pmap asmm impm ->
  mem_inv pmap asmm1 impm.
Proof.
  unfold mem_inv; intros; cleanup.
  eapply H in H0; clear H; cleanup.
  eexists; split; eauto; intros.
  eapply H0 in H1; clear H0; cleanup.
  eexists. *)


Theorem memory_set_memory: forall s p,
  memory (set_pc p s) = memory s.
Proof.
  intros; simpl; reflexivity.
Qed.

Theorem env_ok_pmap_subsume: forall vars vs curr pmap pmap1 asmm impm,
  env_ok vars vs curr pmap asmm impm ->
  pmap_subsume pmap pmap1 ->
  env_ok vars vs curr pmap1 asmm impm.
Proof.
  intros.
  unfold env_ok, pmap_subsume in *; cleanup.
  split; eauto.
  intros.
  eapply H1 in H2; clear H1; cleanup.
  split; eauto.
  eexists; eauto.
  split; eauto.
  unfold v_inv in *; simpl; destruct v eqn:?; cleanup; eauto.
Qed.

Theorem step_consts: forall s0 s1,
  step (State s0) (State s1) ->
  s1.(instructions) = s0.(instructions).
Proof.
  inversion 1; intros; eauto.
  simpl in *; subst.
  unfold write_mem in *; simpl in *; cleanup.
  destruct (memory _ _) eqn:?; try destruct o; cleanup.
  all: inversion H5; clear H5; subst.
  split; intros; eauto.
Qed.

Theorem steps_consts:
  ∀x y,
    steps x y ->
    (∀t1 m, y = (State t1,m) -> ∃t0 n, x = (State t0,n)) ∧
    ∀t0 n t1 m,
      x = (State t0,n) ∧ y = (State t1,m) ->
      t1.(instructions) = t0.(instructions).
Proof.
  intros x y H.
  induction H; split; intros; cleanup; try reflexivity.
  (* steps_refl case *)
  - eauto.
  - destruct s1 eqn:?; [eauto|inversion H].
  - eapply step_consts in H; assumption.
  - destruct s1 eqn:?; [eauto|inversion H].
  - eapply step_consts in H; assumption.
  - specialize (H2 t1 m eq_refl); cleanup.
    eapply H4.
    reflexivity.
  - specialize (H3 t1 m eq_refl); cleanup.
    specialize (H5 x x0 eq_refl); cleanup.
    eapply eq_trans.
    1: eapply H4; split; eauto.
    eapply H6; split; eauto.
Qed.

Theorem steps_instructions: forall s1 s2 f1 f2,
  steps (State s1, f1) (State s2, f2) -> s1.(instructions) = s2.(instructions).
Proof.
  intros.
  symmetry.
  eapply steps_consts; try split; eauto.
Qed.

Theorem index_of_spec: forall name vs k,
  index_of name k vs = k + index_of name 0 vs.
Proof.
  induction vs; intros; eauto.
  simpl; destruct a.
  - destruct (_ =? _) eqn:?; simpl; eauto.
    rewrite IHvs; eapply eq_sym; rewrite IHvs.
    rewrite Nat.add_assoc.
    reflexivity.
  - rewrite IHvs; eapply eq_sym; rewrite IHvs.
    rewrite Nat.add_assoc.
    reflexivity.
Qed.

Ltac crunch_give_up_even :=
  repeat match  goal with
  | |- (ImpToASMCodegen.give_up _) = (ImpToASMCodegen.give_up _) => f_equal
  | |- context[even_len _] => rewrite even_len_spec
  | |- context[odd_len _] => rewrite odd_len_spec
  | [ H: (List.length ?vs = _) |- context[List.length ?vs] ] => rewrite H
  | |- context[List.length (_ ++ _)] => rewrite length_app
  | |- context[odd (_ + _)] => rewrite Nat.odd_add
  | |- context[even (_ + _)] => rewrite Nat.even_add
  | [ H: odd ?x = _ |- context[odd ?x] ] => rewrite H
  | [ H: (even (List.length (stack ?t))) = _ |- context C [odd (List.length (stack ?t))]] =>
    repeat rewrite <- Nat.negb_even; rewrite H; clear H
  | [ H: (odd (List.length (stack ?t))) = _ |- context C [even (List.length (stack ?t))]] =>
    repeat rewrite <- Nat.negb_even; rewrite H; clear H
  | [ H: (even (List.length (stack ?t))) = _ |- context C [even (List.length (stack ?t))]] =>
    rewrite H; clear H
  | [ H: (odd (List.length (stack ?t))) = _ |- context C [odd (List.length (stack ?t))]] =>
    rewrite H; clear H
  | _ => rewrite xorb_true_r || rewrite Nat.negb_odd || rewrite Nat.negb_even
  | _ => tauto
end.

Theorem env_ok_add_None: forall vars vs curr x asmm impm pmap pmap1,
  env_ok vars vs curr pmap asmm impm ->
  pmap_subsume pmap pmap1 ->
  env_ok vars (None :: vs) (Word x :: curr) pmap1 asmm impm.
Proof.
  intros * H.
  unfold env_ok in *; cleanup.
  split.
  1: simpl; eauto.
  intros*; intro HLookup.
  eapply H0 in HLookup; cleanup.
  split; try eexists; try split.
  all: simpl.
  all: try rewrite index_of_spec; try lia.
  all: unfold v_inv in *.
  1: simpl; eapply H3.
  destruct v; [assumption|].
  cleanup.
  unfold pmap_subsume in *.
  eapply H1 in H4.
  eauto.
Qed.

Theorem pmap_subsume_refl: forall pmap,
  pmap_subsume pmap pmap.
Proof.
  unfold pmap_subsume; intros; assumption.
Qed.

Theorem pmap_subsume_trans: forall pmap1 pmap2 pmap3,
  pmap_subsume pmap1 pmap2 ->
  pmap_subsume pmap2 pmap3 ->
    pmap_subsume pmap1 pmap3.
Proof.
  unfold pmap_subsume; intros; eauto.
Qed.

Theorem mul_div_id: forall n m,
  n mod m = 0 ->
  n / m * m = n.
Proof.
  intros n m H.
  destruct m as [|m'].
  - simpl in H.
    destruct n.
    + simpl; reflexivity.
    + discriminate H.
  - assert (S m' <> 0) as Hnz by (intro; discriminate).
    pose proof (Nat.div_mod n (S m') Hnz) as Hdm.
    rewrite H in Hdm.
    rewrite Nat.add_0_r in Hdm.
    rewrite Nat.mul_comm in Hdm.
    exact (eq_sym Hdm).
Qed.

(* Theorem naive_unsigned_ge_0: forall (x: word64),
  (0 <= Naive.unsigned x)%Z.
Proof.
  intros.

Qed. *)

Ltac rw tac :=
  let n := fresh "H" in
  ltac:(tac); intros n; rewrite n in *; clear n.

Ltac rwr tac :=
  let n := fresh "H" in
  ltac:(tac); intros n; rewrite <- n in *; clear n.

Ltac apply_IEnv_lookup :=
  match goal with
  | [ H1 : IEnv.lookup _ _ = _, H2: context[IEnv.lookup _ _] |- _ ] =>
    eapply H2 in H1; cleanup
  end.

Ltac apply_lookup_fun :=
  match goal with
  | [ H1 : lookup_fun _ _ = _, H2: context[lookup_fun _ _] |- _ ] =>
    eapply H2 in H1; cleanup
  end.

Ltac eval_exp_contr_stop_tac :=
  lazymatch goal with
  | [ H: eval_exp _ _ = (Stop ?v, _) |- _ ] =>
    exfalso; destruct v eqn:?; eapply eval_exp_not_stop in H; eauto; try congruence
  end.

Theorem c_exp_Const : forall (w: word64),
  goal_exp (ImpSyntax.Const w).
Proof.
  unfold goal_exp.
  intros.
  specialize (has_stack_even t (curr ++ rest) H4); intros.
  unfold has_stack in *; cleanup.
  simpl eval_exp in *.
  unfold lookup_var in *.
  unfold state_rel in *; cleanup.
  unfold env_ok in *; cleanup.
  simpl c_exp in *; unfold c_const in *.
  cleanup.
  simpl flatten in *.
  eexists.
  split.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: simpl code_in in *; cleanup.
    1: eapply step_push in e; eauto.
    eapply steps_step_same.
    simpl code_in in *; cleanup.
    eapply step_const.
    eauto.
  }
  simpl.
  repeat split; unfold state_rel in *; cleanup; intros; repeat split; simpl.
  all: inversion H; subst; eauto.
  - unfold code_rel in *.
    cleanup.
    eauto.
  - unfold code_rel in *; cleanup.
    apply_lookup_fun.
    eexists.
    split; eauto.
  - eexists; eexists.
    eauto.
  - unfold exp_res_rel.
    eexists.
    repeat split.
    + simpl; assumption.
    + unfold has_stack.
      simpl; eauto.
    + simpl.
      lia.
Qed.

Theorem c_exp_Var : forall (n: name),
  goal_exp (ImpSyntax.Var n).
Proof.
  unfold goal_exp.
  intros.
  unfold has_stack in *; cleanup.
  simpl eval_exp in *.
  unfold lookup_var in *.
  unfold state_rel in *; cleanup.
  unfold env_ok in *; cleanup.
  unfold code_rel in *; cleanup.
  simpl c_exp in *; unfold c_var in *; unfold dlet in *.
  destruct (index_of n 0 vs =? 0) eqn:?.
  1: {
    eexists.
    cleanup.
    simpl flatten in *.
    split.
    - eapply steps_step_same.
      simpl code_in in *; cleanup.
      eapply step_push in e; eauto.
    - simpl.
      destruct (IEnv.lookup (vars s) n) eqn:?; unfold_outcome; inversion H; subst.
      2: unfold not in H0; contradiction.
      repeat split; simpl; eauto.
      1: eexists; eexists; eauto.
      unfold v_inv, has_stack.
      destruct v eqn:?; subst.
      1: {
        assert (x = w).
        1: {
          eapply H18 in Heqo; cleanup; subst.
          unfold v_inv in *; cleanup; subst.
          rewrite Nat.eqb_eq in *.
          rewrite Heqb in *.
          destruct curr; inversion H10; subst.
          inversion H4; subst.
          reflexivity.
        }
        subst.
        exists w; repeat split; eauto.
      }
      apply_IEnv_lookup; unfold v_inv in *; cleanup.
      eexists; repeat split.
      2: assumption.
      all: repeat eexists; repeat split.
      1: eauto.
      all: simpl; eauto.
      rewrite Nat.eqb_eq in *.
      rewrite Heqb in *.
      destruct curr; inversion H10; subst.
      inversion H4; subst.
      assumption.
  }
  unfold env_ok in *; cleanup.
  unfold lookup_var in *; cleanup.
  destruct (IEnv.lookup (vars s) n) eqn:?; unfold_outcome; inversion H; subst.
  2: unfold not in H0; contradiction.
  apply_IEnv_lookup; cleanup.
  eexists.
  simpl flatten in *.
  split.
  - eapply steps_trans.
    1: eapply steps_step_same.
    1: simpl code_in in *; cleanup.
    1: eapply step_push in e; eauto.
    eapply steps_step_same.
    rewrite Nat.eqb_neq in *.
    simpl code_in in *; cleanup.
    eapply step_load_rsp; eauto.
    all: unfold_stack; eauto.
    2: {
      rewrite <- H4 in *.
      rewrite nth_error_app.
      rewrite <- Nat.ltb_lt in *.
      rewrite H1.
      eauto.
    }
    eapply Nat.lt_trans; [eauto|].
    assert (List.length (curr ++ rest) = List.length (Word x :: stack t)); [rewrite H4; reflexivity|].
    rewrite length_app in *.
    rewrite length_cons in *.
    rewrite <- H.
    destruct rest; [inversion H7|].
    rewrite length_cons in *.
    lia.
  - simpl.
    unfold state_rel in *; cleanup.
    unfold code_rel in *; cleanup.
    repeat split; simpl; eauto.
    1: eexists; eexists; eauto.
    unfold v_inv, has_stack in *.
    destruct v eqn:?.
    1: {
      unfold v_inv in *; cleanup.
      eexists; repeat split.
      1: assumption.
      2: lia.
      repeat eexists; repeat split.
      all: simpl; eauto.
      subst; eauto.
    }
    cleanup.
    eexists; repeat split.
    2: assumption.
    3: lia.
    all: repeat eexists; repeat split.
    all: simpl; eauto.
Qed.

Ltac bin_exp_post_tac :=
  simpl;
  repeat split; eauto;
  unfold code_rel in *; cleanup; eauto;
  [try eapply pmap_subsume_trans; eauto|..];
  [eexists; eexists; eauto|..];
  eexists; repeat split; eauto; repeat eexists;
  try rewrite Z.add_comm; try reflexivity;
  try lia.

Theorem c_exp_Add : forall (e1 e2: exp),
  goal_exp e1 -> goal_exp e2 ->
  goal_exp (ImpSyntax.Add e1 e2).
Proof.
  intros.
  unfold goal_exp; intros.
  simpl eval_exp in *.
  simpl c_exp in *; unfold c_add, c_sub, c_div, c_load in *; unfold dlet in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp in *; subst.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  unfold combine_word in *.
  destruct v eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  destruct v0 eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H in Heqp; clear H; eauto.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  2: repeat eexists; repeat split; eauto; simpl; split; eauto.
  unfold exp_res_rel in *; cleanup; subst.
  unfold goal_exp in H0.
  rw ltac:(specialize (steps_instructions _ _ _ _ H10)).
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  2: repeat eexists; repeat split; [eapply steps_trans|..]; eauto; simpl; eauto.
  all: unfold exp_res_rel in *; cleanup.
  all: try rewrite <- H20 in *.
  all: unfold state_rel in *; cleanup.
  1: instantiate (1 := (Word w :: curr)) in H19.
  all: simpl in *; cleanup; subst.
  1: {
    specialize (has_stack_even t (curr ++ rest) H6) as ?.
    specialize (has_stack_even _ _ H14) as ?.
    specialize (has_stack_even _ _ H19) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
    eexists.
    split.
    1: {
      eapply steps_trans.
      1: eapply H10.
      eapply steps_trans.
      1: eapply H3.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_add; eauto.
      1: unfold_stack; eauto.
      eapply steps_refl.
    }
    bin_exp_post_tac.
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto.
  eapply pmap_subsume_refl.
Qed.

Theorem c_exp_Sub : forall (e1 e2: exp),
  goal_exp e1 -> goal_exp e2 ->
  goal_exp (ImpSyntax.Sub e1 e2).
Proof.
  intros.
  unfold goal_exp; intros.
  simpl eval_exp in *.
  simpl c_exp in *; unfold c_add, c_sub, c_div, c_load in *; unfold dlet in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp in *; subst.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  unfold combine_word in *.
  destruct v eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  destruct v0 eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H in Heqp; clear H; eauto.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  2: repeat eexists; repeat split; eauto; simpl; split; eauto.
  unfold exp_res_rel in *; cleanup; subst.
  unfold goal_exp in H0.
  rw ltac:(specialize (steps_instructions _ _ _ _ H10)).
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  2: repeat eexists; repeat split; [eapply steps_trans|..]; eauto; simpl; eauto.
  all: unfold exp_res_rel in *; cleanup.
  all: try rewrite <- H20 in *.
  all: unfold state_rel in *; cleanup.
  1: instantiate (1 := (Word w :: curr)) in H19.
  all: simpl in *; cleanup; subst.
  1: {
    specialize (has_stack_even t (curr ++ rest) H6) as ?.
    specialize (has_stack_even _ _ H14) as ?.
    specialize (has_stack_even _ _ H19) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
    eexists.
    split.
    1: {
      eapply steps_trans.
      1: eapply H10.
      eapply steps_trans.
      1: eapply H3.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_sub; eauto.
      1: simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      1: simpl; eauto.
      eapply steps_refl.
    }
    bin_exp_post_tac.
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto.
  eapply pmap_subsume_refl.
Qed.

Theorem c_exp_Div : forall (e1 e2: exp),
  goal_exp e1 -> goal_exp e2 ->
  goal_exp (ImpSyntax.Div e1 e2).
Proof.
  intros.
  unfold goal_exp; intros.
  simpl eval_exp in *.
  simpl c_exp in *; unfold c_add, c_sub, c_div, c_load in *; unfold dlet in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp in *; subst.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  unfold combine_word in *.
  destruct (value_eqb _ _) eqn:?; unfold_outcome; cleanup; subst.
  1: contradiction.
  destruct v eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  destruct v0 eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  unfold value_eqb in *.
  rewrite word.unsigned_eqb in *; simpl word.unsigned in *; rewrite Z.mod_0_l in *; [|lia].
  rewrite Heqb in *.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H in Heqp; clear H; eauto.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  2: repeat eexists; repeat split; eauto; simpl; split; eauto.
  unfold exp_res_rel in *; cleanup; subst.
  rw ltac:(specialize (steps_instructions _ _ _ _ H10)).
  unfold goal_exp in H0.
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  2: repeat eexists; repeat split; [eapply steps_trans|..]; eauto; simpl; eauto.
  all: unfold exp_res_rel in *; cleanup.
  all: try rewrite <- H20 in *.
  all: unfold state_rel in *; cleanup.
  1: instantiate (1 := (Word w :: curr)) in H19.
  all: simpl in *; cleanup; subst.
  1: {
    specialize (has_stack_even t (curr ++ rest) H6) as ?.
    specialize (has_stack_even _ _ H14) as ?.
    specialize (has_stack_even _ _ H19) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
    eexists.
    split.
    1: {
      eapply steps_trans.
      1: eapply H10.
      eapply steps_trans.
      1: eapply H3.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      1: simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_const; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_div; eauto.
      2: simpl; eauto.
      2: simpl; eauto.
      1: unfold not; intros ->; rewrite Z.eqb_neq in *; eapply Heqb.
      1: simpl; rewrite Z.mod_0_l; try reflexivity; lia.
      eapply steps_refl.
    }
    bin_exp_post_tac.
    rewrite Heqb; reflexivity.
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto.
  eapply pmap_subsume_refl.
Qed.

Opaque word.add word.unsigned word.of_Z.

Theorem c_exp_Read : forall (e1 e2: exp),
  goal_exp e1 -> goal_exp e2 ->
  goal_exp (ImpSyntax.Read e1 e2).
Proof.
  intros.
  unfold goal_exp; intros.
  simpl eval_exp in *; simpl mem_load in *.
  simpl c_exp in *; unfold c_add, c_sub, c_div, c_load in *; unfold dlet in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp in *; subst.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  unfold mem_load in *.
  destruct v eqn:?; unfold_outcome; cleanup; subst.
  1: contradiction.
  destruct v0 eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  destruct (negb (_)) eqn:?; unfold_outcome; cleanup; subst.
  1: contradiction.
  destruct (nth_error _ _) eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  destruct (nth_error l _) eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  destruct o eqn:?; unfold_outcome; cleanup; subst.
  2: contradiction.
  rewrite negb_false_iff in *; rewrite Nat.eqb_eq in *.
  Opaque Nat.modulo.
  Opaque Nat.div.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H in Heqp; clear H; eauto.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  2: repeat eexists; repeat split; eauto; simpl; split; eauto.
  unfold exp_res_rel in *; cleanup; subst.
  rw ltac:(specialize (steps_instructions _ _ _ _ H10)).
  unfold goal_exp in H0.
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  2: repeat eexists; repeat split; [eapply steps_trans|..]; eauto; simpl; eauto.
  all: unfold exp_res_rel in *; cleanup.
  all: try rewrite <- H20 in *.
  all: unfold state_rel in *; cleanup.
  1: instantiate (1 := (Word x :: curr)) in H19.
  all: simpl in *; cleanup; subst.
  1: {
    specialize (has_stack_even t (curr ++ rest) H6) as ?.
    specialize (has_stack_even _ _ H14) as ?.
    specialize (has_stack_even _ _ H19) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
    eapply H18 in Heqo; cleanup.
    eapply H30 in Heqo0; clear H30; cleanup.
    unfold opt_rel in *; destruct x8; try contradiction.
    eexists.
    split.
    1: {
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_add; eauto.
      1: simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_load; eauto.
      1: simpl; eauto.
      2: eapply steps_refl.
      simpl in *.
      unfold_stack; unfold read_mem; simpl.
      assert (
        (word.add (word.add x9 x0) (word.of_Z (word.unsigned (word.of_Z 0)))) =
        (word.add x (word.of_Z (Z.of_nat (w2n x0 / 8 * 8))))
      ) as ->.
      2: rewrite H30; eauto.
      rewrite H12 in *; cleanup.
      inversion H19; subst.
      unfold w2n; simpl.
      cbn.
      rewrite mul_div_id; eauto.
      rewrite Z2Nat.id.
      1: rewrite word.of_Z_unsigned.
      1: rewrite Properties.word.add_0_r.
      1: reflexivity.
      specialize (Properties.word.unsigned_range x0).
      intros; lia.
    }
    bin_exp_post_tac.
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto.
  eapply pmap_subsume_refl.
Qed.

Theorem c_exp_correct: forall e,
  goal_exp e.
Proof.
  induction e.
  - eapply c_exp_Var.
  - eapply c_exp_Const.
  - eapply c_exp_Add; eauto.
  - eapply c_exp_Sub; eauto.
  - eapply c_exp_Div; eauto.
  - eapply c_exp_Read; eauto.
Qed.

Ltac eval_exp_correct_tac :=
  lazymatch reverse goal with
  | [
    Heval: eval_exp _ _ = (?res, _) |- _
  ] =>
    let Hneq := fresh "H" in
    assert (res <> Stop Crash) as Hneq by congruence;
    eapply c_exp_correct in Heval; eauto;
    eapply Heval in Hneq; eauto; clear Heval; eauto; cleanup
  end.

Ltac eval_test_goal_tac :=
  lazymatch reverse goal with
  | [
    Hgoal: goal_test ?tst,
    Heval: eval_test ?tst _ = (?res, _) |- _
  ] =>
    unfold goal_test in Hgoal;
    eapply Hgoal in Heval; eauto; clear Hgoal; cleanup
  end.

Ltac steps_inst_tac :=
  lazymatch goal with
  | [ H: steps _ _ |- _ ] =>
    rw ltac:(specialize (steps_instructions _ _ _ _ H))
  end.

Ltac inst_has_stack c :=
  match reverse goal with
  | [ H: has_stack _ _ |- _ ] =>
    instantiate(1 := c) in H
  end.

Ltac has_stack_even_tac :=
  match goal with
  | [ H: has_stack _ _ |- _ ] =>
    specialize (has_stack_even _ _ H) as ?;
    unfold has_stack in H
  end.

Ltac mem_inv_pmap_subsume_tac p p1 :=
  lazymatch goal with
  | [
    Hmem: mem_inv p _ _,
    Hsub1: pmap_subsume p p1 |- _
  ] =>
    eapply mem_inv_pmap_subsume
      with (pmap1 := p1) (pmap := p) in Hmem; eauto
  | [
    Hmem: mem_inv p _ _,
    Hsub1: pmap_subsume p ?x,
    Hsub2: pmap_subsume ?x p1 |- _
  ] =>
    eapply pmap_subsume_trans with (pmap3 := p1) in Hsub1; eauto;
    eapply mem_inv_pmap_subsume
      with (pmap1 := p1) (pmap := p) in Hmem; eauto
  end.

Ltac env_ok_pmap_subsume_tac p p1 :=
  lazymatch goal with
  | [
    Hmem: env_ok _ _ _ p _ _,
    Hsub1: pmap_subsume p p1 |- _
  ] =>
    eapply env_ok_pmap_subsume
      with (pmap1 := p1) (pmap := p) in Hmem; eauto
  | [
    Hmem: env_ok _ _ _ p _ _,
    Hsub1: pmap_subsume p ?x,
    Hsub2: pmap_subsume ?x p1 |- _
  ] =>
    eapply pmap_subsume_trans with (pmap3 := p1) in Hsub1; eauto;
    eapply env_ok_pmap_subsume
      with (pmap1 := p1) (pmap := p) in Hmem; eauto
  end.

Theorem c_test_Test_Less: forall (cm : cmp) (e1 e2 : exp),
  cm = ImpSyntax.Less ->
  goal_test (Test cm e1 e2).
Proof.
  intros.
  unfold goal_test; intros.
  simpl eval_test in *.
  simpl c_exp in *; unfold c_test_jump in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  destruct (eval_exp e2 s0) eqn:?; simpl in *.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  unfold eval_cmp in *.
  destruct v eqn:?; unfold_outcome; cleanup; subst.
  destruct v0 eqn:?; unfold_outcome; cleanup; subst.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  repeat rewrite code_in_append in *; cleanup.
  eval_exp_correct_tac.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  2: eexists; split; eauto.
  unfold exp_res_rel in *; cleanup; subst.
  steps_inst_tac.
  eval_exp_correct_tac.
  1: destruct x0; destruct s0; cleanup; subst.
  2: contradiction.
  all: unfold exp_res_rel in *; cleanup.
  all: try rewrite <- H18 in *.
  all: unfold state_rel in *; cleanup.
  1: inst_has_stack (Word x :: curr).
  1: {
    repeat has_stack_even_tac; cleanup.
    unfold env_ok in *; cleanup.
    steps_inst_tac.
    simpl in *.
    cleanup; subst.
    destruct ((Naive.unsigned w) <? (Naive.unsigned w0))%Z eqn:?.
    1: {
      eexists.
      split.
      1: {
        eapply steps_trans.
        1: eauto.
        eapply steps_trans.
        1: eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_mov; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_pop; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_pop; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump; eauto.
        1: econstructor; simpl; eauto.
        eapply steps_refl.
      }
      simpl.
      unfold code_rel in *; cleanup; eauto.
      try rewrite Heqb.
      bin_exp_post_tac.
    }
    eexists.
    split.
    1: {
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; eauto.
      1: econstructor; simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; eauto.
      1: simpl; rewrite Heqb; eauto.
      1: econstructor; simpl; eauto.
      eapply steps_refl.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    try rewrite Heqb.
    bin_exp_post_tac.
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto.
  eapply pmap_subsume_refl.
Qed.

Theorem c_test_Test_Equal: forall (cm : cmp) (e1 e2 : exp),
  cm = ImpSyntax.Equal ->
  goal_test (Test cm e1 e2).
Proof.
  intros.
  unfold goal_test; intros.
  simpl eval_test in *.
  simpl c_exp in *; unfold c_test_jump in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  destruct (eval_exp e2 s0) eqn:?; simpl in *.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: pat `eval_exp _ _ = _` eapply eval_exp_not_contdf in pat; contradiction.
  unfold eval_cmp in *.
  destruct v eqn:?; unfold_outcome; cleanup; subst.
  destruct v0 eqn:?; unfold_outcome; cleanup; subst.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  repeat rewrite code_in_append in *; cleanup.
  eval_exp_correct_tac.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  2: eexists; split; eauto.
  unfold exp_res_rel in *; cleanup; subst.
  try steps_inst_tac.
  eval_exp_correct_tac.
  1: destruct x0; destruct s0; cleanup; subst.
  2: contradiction.
  all: unfold exp_res_rel in *; cleanup.
  all: try rewrite <- H18 in *.
  all: unfold state_rel in *; cleanup.
  1: inst_has_stack (Word x :: curr).
  1: {
    repeat has_stack_even_tac; cleanup.
    unfold env_ok in *; cleanup.
    steps_inst_tac.
    simpl in *.
    cleanup; subst.
    destruct ((Naive.unsigned w) =? (Naive.unsigned w0))%Z eqn:?.
    1: {
      eexists.
      split.
      1: {
        eapply steps_trans.
        1: eauto.
        eapply steps_trans.
        1: eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_mov; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_pop; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_pop; eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump; eauto.
        1: econstructor; simpl; eauto.
        eapply steps_refl.
      }
      simpl.
      unfold code_rel in *; cleanup; eauto.
      try rewrite Heqb.
      bin_exp_post_tac.
    }
    eexists.
    split.
    1: {
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; eauto.
      1: econstructor; simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; eauto.
      1: simpl; rewrite Heqb; eauto.
      1: econstructor; simpl; eauto.
      eapply steps_refl.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    try rewrite Heqb.
    bin_exp_post_tac.
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto.
  eapply pmap_subsume_refl.
Qed.

Theorem c_test_Test: forall (cm : cmp) (e1 e2 : exp),
  goal_test (Test cm e1 e2).
Proof.
  destruct cm; intros.
  - eapply c_test_Test_Less; reflexivity.
  - eapply c_test_Test_Equal; reflexivity.
Qed.

Theorem c_test_And: ∀ (tst1 tst2 : test),
  goal_test tst1 -> goal_test tst2 ->
  goal_test (ImpSyntax.And tst1 tst2).
Proof.
  intros.
  unfold goal_test; intros.
  simpl eval_test in *.
  simpl c_test_jump in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_test tst1 s) eqn:?; simpl in *.
  destruct r eqn:?; subst; cleanup.
  destruct (eval_test tst2 s0) eqn:?; simpl in *.
  destruct r eqn:?; subst; cleanup.
  unfold_outcome; cleanup.
  destruct (c_test_jump tst1) eqn:?; simpl in *.
  destruct (c_test_jump tst2) eqn:?; simpl in *.
  specialize (eval_test_pure tst1 _ _ _ Heqp).
  specialize (eval_test_pure tst2 _ _ _ Heqp0).
  intros; subst.
  repeat rewrite code_in_append in *; cleanup.
  assert (pc t + 1 + 1 = pc t + 2) as Htmp; [lia|]; rewrite Htmp in *; clear Htmp.
  rwr ltac:(specialize (c_test_length tst1 _ _ _ _ _ _ Heqp1)).
  assert (pc t + 2 = pc (set_pc (if true then pc t + 2 else pc t + 1) t)) as Htmp by (simpl; reflexivity).
  rewrite Htmp in *; clear Htmp.
  eval_test_goal_tac.
  destruct x; destruct s; cleanup; subst.
  2: contradiction.
  assert (n = pc (set_pc n s)) as Htmp by (simpl; reflexivity); rewrite Htmp in *; clear Htmp.
  unfold goal_test in H0; eapply H0 in Heqp0; clear H0; cleanup.
  all: eauto.
  1: destruct x; destruct s0; cleanup; subst.
  2: contradiction.
  2: simpl in *; unfold state_rel in *; cleanup; rwr ltac:(specialize (steps_instructions _ _ _ _ H)); eauto.
  unfold state_rel in *; cleanup.
  destruct v eqn:?; subst.
  1: {
    destruct v0 eqn:?; subst.
    - eexists; split. (* true && true *)
      all: rewrite <- H15 in *.
      all: specialize (steps_instructions _ _ _ _ H) as Htmp; simpl in Htmp; rewrite Htmp in H9; clear Htmp.
      1: {
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: simpl; eauto.
        1: constructor.
        eapply steps_trans.
        1: eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: simpl; eauto.
        1: constructor.
        simpl; eauto.
      }
      simpl.
      unfold code_rel in *; cleanup; eauto.
      bin_exp_post_tac.
    - eexists; split. (* true && false *)
      all: rewrite <- H15 in *.
      all: specialize (steps_instructions _ _ _ _ H) as Htmp; simpl in Htmp; rewrite Htmp in H9; clear Htmp.
      1: {
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: simpl; eauto.
        1: constructor.
        eapply steps_trans.
        1: eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: simpl; eauto.
        1: constructor.
        simpl; eauto.
      }
      simpl.
      unfold code_rel in *; cleanup; eauto.
      bin_exp_post_tac.
  }
  eexists; split. (* false && _ *)
  all: specialize (steps_instructions _ _ _ _ H) as Htmp; simpl in Htmp; rewrite Htmp in H9; clear Htmp.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump.
    1: simpl; eauto.
    1: constructor.
    eauto.
  }
  simpl.
  repeat split; eauto.
  all: unfold code_rel in *; cleanup; eauto.
  do 2 eexists; eauto.
Qed.

Theorem c_test_Or: ∀ (tst1 tst2 : test),
  goal_test tst1 -> goal_test tst2 ->
  goal_test (ImpSyntax.Or tst1 tst2).
Proof.
  intros.
  unfold goal_test; intros.
  simpl eval_test in *.
  simpl c_test_jump in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_test tst1 s) eqn:?; simpl in *.
  destruct r eqn:?; subst; cleanup.
  destruct (eval_test tst2 s0) eqn:?; simpl in *.
  destruct r eqn:?; subst; cleanup.
  unfold_outcome; cleanup.
  destruct (c_test_jump tst1) eqn:?; simpl in *.
  destruct (c_test_jump tst2) eqn:?; simpl in *.
  specialize (eval_test_pure tst1 _ _ _ Heqp).
  specialize (eval_test_pure tst2 _ _ _ Heqp0).
  intros; subst.
  repeat rewrite code_in_append in *; cleanup.
  assert (pc t + 1 + 1 = pc t + 2) as Htmp; [lia|]; rewrite Htmp in *; clear Htmp.
  rwr ltac:(specialize (c_test_length tst1 _ _ _ _ _ _ Heqp1)).
  assert (pc t + 2 = pc (set_pc (if true then pc t + 2 else pc t + 1) t)) as Htmp by (simpl; reflexivity).
  rewrite Htmp in *; clear Htmp.
  eval_test_goal_tac.
  destruct x; destruct s; cleanup; subst.
  2: contradiction.
  assert (n = pc (set_pc n s)) as Htmp by (simpl; reflexivity); rewrite Htmp in *; clear Htmp.
  unfold goal_test in H0; eapply H0 in Heqp0; clear H0; cleanup.
  all: eauto.
  1: destruct x; destruct s0; cleanup; subst.
  2: contradiction.
  2: simpl in *; unfold state_rel in *; cleanup; rwr ltac:(specialize (steps_instructions _ _ _ _ H)); eauto.
  unfold state_rel in *; cleanup.
  destruct v eqn:?; subst.
  1: { (* true || _ *)
    eexists; split.
    all: specialize (steps_instructions _ _ _ _ H) as Htmp; simpl in Htmp; rewrite Htmp in H9; clear Htmp.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      eauto.
    }
    simpl.
    repeat split; eauto.
    all: unfold code_rel in *; cleanup; eauto.
    do 2 eexists; eauto.
  }
  destruct v0 eqn:?; subst.
  - eexists; split. (* false || true *)
    all: rewrite <- H15 in *.
    all: specialize (steps_instructions _ _ _ _ H) as Htmp; simpl in Htmp; rewrite Htmp in H9; clear Htmp.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      simpl; eauto.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    bin_exp_post_tac.
  - eexists; split. (* false || false *)
    all: rewrite <- H15 in *.
    all: specialize (steps_instructions _ _ _ _ H) as Htmp; simpl in Htmp; rewrite Htmp in H9; clear Htmp.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      simpl; eauto.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    bin_exp_post_tac.
Qed.

Theorem c_test_Not: ∀ (tst : test),
  goal_test tst ->
  goal_test (ImpSyntax.Not tst).
Proof.
  intros.
  unfold goal_test; intros.
  simpl eval_test in *.
  simpl c_test_jump in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_test tst s) eqn:?; simpl in *.
  destruct r eqn:?; subst; cleanup.
  unfold_outcome; cleanup.
  destruct (c_test_jump tst) eqn:?; simpl in *.
  specialize (eval_test_pure tst _ _ _ Heqp).
  intros; subst.
  repeat rewrite code_in_append in *; cleanup.
  eval_test_goal_tac.
  destruct x eqn:?; destruct s eqn:?; cleanup.
  2: eexists; split; eauto.
  destruct v eqn:?; subst.
  1: {
    eexists; split.
    1: eauto.
    simpl.
    split; eauto.
  }
  eexists; split.
  1: eauto.
  simpl.
  split; eauto.
Qed.

Theorem c_test_correct: forall (tst: test),
  goal_test tst.
Proof.
  induction tst.
  - eapply c_test_Test.
  - eapply c_test_And; eauto.
  - eapply c_test_Or; eauto.
  - eapply c_test_Not; eauto.
Qed.

Theorem c_cmd_Abort: forall (fuel: nat),
  goal_cmd ImpSyntax.Abort (S fuel).
Proof.
  unfold goal_cmd; intros.
  simpl c_cmd in *; cleanup.
  pat `has_stack _ _` eapply has_stack_even in pat.
  unfold has_stack in *; cleanup.
  unfold state_rel in *; cleanup.
  unfold env_ok in *; cleanup.
  simpl flatten in *; simpl code_in in *; cleanup.
  do 2 eexists; split.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump.
    1: simpl; eauto.
    1: constructor.
    eapply abort; eauto.
    simpl; subst.
    crunch_give_up_even.
  }
  split; eauto.
  split; [eapply pmap_subsume_refl|].
  simpl; split; eauto.
  inversion H; subst.
  pat `_ = output _` rewrite <- pat.
  rewrite prefix_correct.
  apply substring_noop.
Qed.

(* Theorem c_cmd_Return: forall (e: exp),
  goal_cmd (ImpSyntax.Return e).
Proof.
  intros.
  unfold goal_cmd; intros.
  simpl eval_cmd in *; unfold bind in *.
  destruct (eval_exp) eqn:?; cleanup.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  simpl c_cmd in *; unfold dlet in *.
  destruct c_exp eqn:?; cleanup.
  unfold_outcome; cleanup.
  simpl flatten in *; cleanup.
  repeat rewrite code_in_append in *; cleanup.
  simpl code_in in*; cleanup.
  eval_exp_correct_tac; eauto.
  destruct x eqn:?; destruct s0 eqn:?; cleanup.
  2: eexists; eexists; split; eauto.
  unfold exp_res_rel in *; cleanup; subst.
  rwr ltac:(specialize (c_exp_length e _ _ _ _ Heqp0)).
  steps_inst_tac.
  unfold env_ok in *; cleanup.
  unfold has_stack in *; cleanup.
  eexists; eexists; split.
  1: {
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_add_rsp.
    1: instantiate(1 := curr).
    1: rewrite <- H3; eauto.
    1: rewrite <- H23; reflexivity.
    eapply steps_step_same.
    1: eapply step_ret.
    1: simpl; eauto.
    simpl.

  } *)

Theorem c_cmd_Assign: forall (n: name) (e: exp) (fuel: nat),
  goal_cmd (ImpSyntax.Assign n e) (S fuel).
Proof.
  intros.
  unfold goal_cmd; intros.
  simpl EVAL_CMD in *; unfold bind in *.
  destruct eval_exp eqn:?; cleanup.
  destruct r eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  2: {

  }
  2: eapply eval_exp_not_contdf.
  simpl c_cmd in *; unfold c_assign, dlet, assign in *.
  destruct c_exp eqn:?; cleanup.
  unfold_outcome; cleanup.
  simpl flatten in *; cleanup.
  repeat rewrite code_in_append in *; cleanup.
  simpl code_in in*; cleanup.
  specialize (eval_exp_pure e _ _ _ Heqp) as ?; subst.
  eval_exp_correct_tac.
  destruct x eqn:?; destruct s eqn:?; cleanup; subst.
  2: contradiction.
  unfold exp_res_rel in *; cleanup; subst.
  unfold env_ok in *; cleanup.
  (* TODO(kπ) destruct here *)
  (* do 3 eexists; split.
  1: eauto.
  simpl.
  split; eauto; split; [eapply pmap_subsume_refl|].
  split; eauto; eexists.
  rewrite app_comm_cons in *; split; eauto.
  unfold env_ok in *; cleanup.
  split; eauto; split.
  1: repeat rewrite length_cons; congruence.
  intros.
  destruct (n =? n1) eqn:?.
  - rewrite Nat.eqb_eq in *; rewrite Heqb in H3.
    rewrite IEnv.lookup_insert_eq in *.
    inversion H3; subst v; clear H3.
    split; simpl; cleanup.
    all: rewrite <- Nat.eqb_eq in *; rewrite Heqb.
    1: lia.
    eexists; simpl; split; eauto.
  - rewrite Nat.eqb_neq in *.
    rewrite IEnv.lookup_insert_neq in *; try assumption.
    eapply H14 in H3.
    split; simpl; cleanup.
    all: rewrite <- Nat.eqb_neq in *; rewrite Heqb.
    all: rewrite index_of_spec; try lia.
    eexists; simpl; split; eauto.
  Unshelve.
  exact 0.
Qed. *)
Abort.

(* Theorem c_cmd_While: forall (t: test) (c: cmd) (fuel: nat),
  goal_cmd c fuel ->
  forall fuel1, fuel1 < fuel -> goal_cmd (ImpSyntax.While t c) fuel1 ->
  goal_cmd (ImpSyntax.While t c) fuel.
Proof.
  intros.
  unfold goal_cmd; intros.
  simpl eval_cmd in *; unfold bind in *.
  destruct eval_test eqn:?; cleanup.
  destruct r eqn:?; subst; cleanup.
  2: exfalso; destruct v eqn:?; eapply eval_test_not_stop in Heqp; eauto; try congruence.
  simpl c_cmd in *; unfold dlet, assign in *.
  destruct c_test_jump eqn:?; cleanup.
  destruct c_cmd eqn:?; cleanup.
  unfold_outcome; cleanup.
  simpl flatten in *; cleanup.
  simpl code_in in *; cleanup.
  repeat rewrite code_in_append in *; cleanup.
  specialize (c_test_length t _ _ _ _ _ _ Heqp0) as ?; subst.
  assert (pc t0 + 3 = pc (set_pc (pc t0 + 3) t0)) as Htmp by reflexivity; rewrite Htmp in Heqp0; clear Htmp.
  assert (pc t0 + 3 + Datatypes.length (flatten a) = pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) t0)) as Htmp by reflexivity; rewrite Htmp in Heqp1; clear Htmp.
  specialize (eval_test_pure t _ _ _ Heqp) as ?; subst.
  destruct p eqn:?; subst.
  destruct v eqn:?; cleanup; subst.
  2: {
    eapply c_test_correct in Heqp.
    2: shelve.
    all: eauto.
    eauto; eapply Heqp in Heqp0; clear Heqp; eauto; cleanup.
    all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
    destruct x eqn:?; destruct s eqn:?; subst.
    2: contradiction.
    pose proof H5 as state_rel_t0.
    unfold state_rel in H5, H16; cleanup; subst.
    do 2 eexists; exists 0; split.
    all: try rewrite Nat.add_0_r.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: eauto.
      1: constructor.
      simpl.
      eapply steps_trans.
      1: eauto.
      eapply steps_step_same.
      eapply step_jump.
      1: unfold fetch; rewrite H20.
      1: rwr ltac:(specialize (steps_instructions _ _ _ _ H2)).
      1: simpl; rewrite Nat.add_comm; eauto.
      constructor.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    repeat split; eauto; [eapply pmap_subsume_refl|..].
    1: eexists; eexists; eauto.
  }
  all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
(*
  eapply c_test_correct in Heqp.
  2: shelve. (* shelve fuel1 *)
  all: eauto.
  eauto; eapply Heqp in Heqp0; clear Heqp; eauto; cleanup.
  all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
  (* rewrite Nat.add_comm. *)
  destruct x eqn:?; destruct s eqn:?; cleanup; subst.
  2: contradiction.
  cleanup; subst.
   *)
  destruct eval_cmd eqn:?; destruct r eqn:?; subst; cleanup.
  2: { (* eval_cmd body = Stop v *)
    (* assert ((pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) t0)) = (pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) s2))) as Htmp by reflexivity; rewrite Htmp in *; clear Htmp. *)
    unfold goal_cmd in Heqp2; eapply H in Heqp2; eapply Heqp2 in H3; clear Heqp2; cleanup; eauto.
    2: simpl; assert (pc t0 + 3 = S ( S ( S (pc t0)))) as -> by lia(* ; rwr ltac:(specialize (steps_instructions _ _ _ _ H16)) *); simpl in *; eauto.

    eapply c_test_correct in Heqp.
    2: shelve. (* shelve fuel1 *)
    all: eauto.
    eauto; eapply Heqp in Heqp0; clear Heqp; eauto; cleanup.
    2: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
    (* rewrite Nat.add_comm. *)
    destruct x2 eqn:?; destruct s eqn:?; cleanup; subst.
    2: contradiction.
    cleanup; subst.

    destruct x eqn:?; destruct s eqn:?; subst; cleanup.
    1: { (* steps (body) ~~> State *)
      do 3 eexists; split.
      1: {
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: eauto.
        1: econstructor.
        simpl.
        eapply steps_trans.
        1: eapply H18.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: rewrite <- H23 in *.
        1: unfold fetch; simpl; rwr ltac:(specialize (steps_instructions _ _ _ _ H18)); eauto.
        1: econstructor.
        simpl.
        eapply H2.

      }
    }
    (* steps (body) ~~> Halt *)

    2: {
      unfold c_cmd.
    }
    (* early return *)
    do 3 eexists.

    admit.
  }
  (* do 2 eexists; exists 0; split.
  all: try rewrite Nat.add_0_r.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump.
    1: eauto.
    1: constructor.
    simpl.
    eapply steps_trans.
    1: eauto.
    eapply steps_step_same.
    eapply step_jump.
    1: unfold fetch; rewrite H20.
    1: rwr ltac:(specialize (steps_instructions _ _ _ _ H16)).
    1: simpl; rewrite Nat.add_comm; eauto.
    constructor.
  }
  simpl.
  unfold code_rel in *; cleanup; eauto.
  repeat split; eauto; [eapply pmap_subsume_refl|..].
  1: eexists; eexists; eauto. *)

Abort. *)

Theorem c_cmd_Seq: forall (fuel: nat) (c1 c2: cmd),
  goal_cmd c1 fuel -> goal_cmd c2 fuel ->
  goal_cmd (ImpSyntax.Seq c1 c2) fuel.
Proof.
  intros.
  unfold goal_cmd; intros.
  simpl c_cmd in *; unfold dlet in *.
  simpl eval_cmd in *; unfold bind in *; simpl in *; inversion H1; subst.
  destruct (eval_cmd c1 _) eqn:?; simpl in *.
  destruct r eqn:?; subst; cleanup.
  2: do 3 eexists; split; [eapply steps_refl|]; split; eauto; split; [eapply pmap_subsume_refl|]; eauto.
  2: admit.
  destruct (eval_cmd c2 _) eqn:?; simpl in *; inversion H1; clear H1; clear H12; subst.
  destruct (c_cmd c1 _ _ _) eqn:?; simpl in *; destruct p eqn:?; subst; cleanup.
  destruct (c_cmd c2 _ _ _) eqn:?; simpl in *; destruct p eqn:?; subst; cleanup.
  unfold goal_cmd in H; eapply H in Heqp; clear H; eauto.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_cmd_length c1 _ _ _ _ _ _ Heqp1)).
  specialize (c_cmd_length c2 _ _ _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s2; cleanup; subst.
  2: repeat eexists; repeat split; eauto; simpl; split; eauto.
  2: admit. (* prefix s2 (string_of_list_ascii (ImpSemantics.output s1)) = true *)
  unfold cmd_res_rel in *; cleanup; subst.
  unfold goal_cmd in H0.
  rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
  eapply H0 in Heqp0; clear H0.
  2,3,4,9: eauto.
  3: eauto.
  (* 4: eapply mem_inv_asmm_IMP.
  2: congruence.
  1: destruct x1; destruct s0; cleanup; subst.
  2: repeat eexists; repeat split; [eapply steps_trans|..]; eauto; simpl; eauto.
  2: eapply pmap_subsume_trans; eauto.
  all: unfold cmd_res_rel in *; cleanup.
  all: try rewrite <- H24 in *.
  all: unfold state_rel in *; cleanup.
  1: instantiate (1 := (Word w :: curr)) in H23.
  all: simpl in *; cleanup; subst.
  1: {
    specialize (has_stack_even t (curr ++ rest) H6) as ?.
    specialize (has_stack_even _ _ H16) as ?.
    specialize (has_stack_even _ _ H23) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
    eexists; eexists.
    split.
    1: {
      eapply steps_trans.
      1: eapply H10.
      eapply steps_trans.
      1: eapply H3.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_add; eauto.
      1: unfold_stack; eauto.
      eapply steps_refl.
    }
    bin_exp_post_tac.
  }
  all: eauto.
  unfold state_rel in *; cleanup.
  eapply env_ok_add_None; eauto. *)
Abort.

Theorem c_cmd_correct : forall (c: cmd) (fuel: nat),
  goal_cmd c fuel.
Proof.
  induction c.
  all: induction fuel.
Abort.
