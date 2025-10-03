Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Import Llist.
Require Import impboot.utils.Env.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.imperative.ImpSemantics.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMSemantics.

Require Import Patat.Patat.

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

(* Finds the position of function n in f_lookup if it exists. *)
Fixpoint lookup_f (n : nat) (fs : f_lookup) : option nat :=
  match fs with
  | [] => None
  | (fname, pos) :: fs =>
    if fname =? n then Some pos
    else lookup_f n fs
  end.

(* Ensures initial instructions are present and that each function in ds has its compiled form in instructions. *)
Definition code_rel (fs : f_lookup) (ds : list func) (instructions : list instr) : Prop :=
  init_code_in instructions /\
  forall n params body,
    find_fun n ds = Some (params, body) ->
    exists pos,
      lookup n fs = pos /\
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

Definition v_inv (pmap: nat -> option (word64 * nat)) (v: Value) (w: word64): Prop :=
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
Definition env_ok (env : IEnv.env) (vs : list (option name)) (curr : list word_or_ret)
  (pmap: nat -> option (word64 * nat)): Prop :=
  List.length vs = List.length curr /\
  forall n v,
    IEnv.lookup env n = Some v ->
    In (Some n) vs /\
    exists w,
      nth_error curr (index_of n 0 vs) = Some (Word w) /\
      v_inv pmap v w.

Fixpoint binders_ok (c: cmd) (vs: list (option name)) :=
  match c with
  | Skip => True
  | Seq c1 c2 => binders_ok c1 vs /\ binders_ok c2 vs
  | Assign n e => In (Some n) vs
  | Update a e e' => True
  | If t c1 c2 => binders_ok c1 vs /\ binders_ok c2 vs
  | While tst body => binders_ok body vs
  | ImpSyntax.Call n f es => True
  | ImpSyntax.Return e => True
  | Alloc n e => In (Some n) vs
  | ImpSyntax.GetChar n => In (Some n) vs
  | ImpSyntax.PutChar e => True
  | ImpSyntax.Abort => True
  end.

Definition cmd_res_rel (ri: outcome unit) (l1: nat)
  (rest: list word_or_ret) (vs: v_stack) (t1: ASMSemantics.state) (s1: ImpSemantics.state)
  (pmap: nat -> option (word64 * nat)) : Prop :=
  match ri with
  | Stop (Return v) => exists w,
    v_inv pmap v w /\
    mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
    has_stack t1 (Word w :: rest) /\
    fetch t1 = Some Ret
  | Cont _ => exists curr1, (* value in Cont is always unit for commands *)
    has_stack t1 (curr1 ++ rest) /\
    mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
    env_ok s1.(vars) vs curr1 pmap /\
    t1.(pc) = l1
  | Stop (ImpSemantics.Abort) => False
  (* | Stop TimeOut =>  *)
  | _ => True (* TODO(kπ) is this correct? *)
  end.

Definition exp_res_rel (ri: outcome Value) (l1: nat)
  (stck: list word_or_ret) (t1: ASMSemantics.state) (s1: ImpSemantics.state)
  (pmap: nat -> option (word64 * nat)) : Prop :=
  match ri with
  | Cont v => exists w,
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
         (res : outcome Value) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret)
         (pmap: nat -> option (word64 * nat)),
    eval_exp e s = (res, s1) ->
    res <> Stop Crash ->
    c_exp e t.(pc) vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr pmap ->
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
    eval_test tst s = (Cont b, s1) ->
    c_test_jump tst ltrue lfalse t.(pc) vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr pmap ->
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
  forall (s s1 : ImpSemantics.state)
         (res : outcome unit) (t : ASMSemantics.state)
         (vs : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret)
         (pmap: nat -> option (word64 * nat)),
    eval_cmd c (EVAL_CMD fuel) s = (res, s1) ->
    res <> Stop Crash ->
    c_cmd c t.(pc) fs vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr pmap ->
    binders_ok c vs ->
    has_stack t (curr ++ rest) ->
    mem_inv pmap t.(memory) s.(ImpSemantics.memory) ->
    pmap_ok pmap ->
    odd (List.length rest) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome pmap1,
      steps (State t, s1.(steps_done) - s.(steps_done)) outcome /\
      pmap_ok pmap1 /\
      pmap_subsume pmap pmap1 /\
      match outcome with
      | (Halt ec output, ck) =>
        prefix (string_of_list_ascii output) (string_of_list_ascii s1.(ImpSemantics.output)) = true /\
        (ec = (word.of_Z 1) \/ ec = (word.of_Z 4))
        (* TODO(kπ) do we need this? *)
        (* ∧ res <> Stop TimeOut *)
      | (State t1, ck) =>
        ck = 0 /\
        state_rel fs s1 t1 /\
        cmd_res_rel res l1 rest vs t1 s1 pmap1
      end.

(* proofs *)

Ltac unfold_outcome :=
  unfold cont, crash, stop in *.

Ltac unfold_stack :=
  unfold inc, set_stack, set_input, set_memory, set_pc,
          set_vars, set_varsM, set_output, write_reg, write_mem,
          add_steps_done, set_steps_done in *; simpl.

Ltac cleanup :=
  repeat match goal with
  | [ H: _ /\ _ |- _ ] => destruct H
  | [ H: exists _, _ |- _ ] => destruct H
  | [ H: True |- _ ] => clear H
  | [ H: Some _ = Some _ |- _ ] => inversion H; subst; clear H
  | [ H: None = Some _ |- _ ] => inversion H; subst; clear H
  | [ H: Some _ = None |- _ ] => inversion H; subst; clear H
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
  steps (State t, n) (Halt (word.of_Z 4) t.(output), n).
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
  steps (State t, n) (Halt (word.of_Z 1) t.(output), n).
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

Theorem c_cmd_length: forall c l fs vs l1 asm1,
  c_cmd c l fs vs = (asm1, l1) -> l1 = l + List.length (flatten asm1).
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
  | [ H : c_cmd _ _ _ _ = (_, _) |- _ ] => eapply IHc2 in H; subst
  | [ H : c_cmd _ _ _ _ = (_, _) |- _ ] => eapply IHc1 in H; subst
  | [ H : c_cmd _ _ _ _ = (_, _) |- _ ] => eapply IHc in H; subst
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

(* Lemma code_in_append_2: forall n xs code1 code2,
  code_in n xs (code1 ++ code2) <->
    (code_in n xs code ∧ code_in (n + List.length xs) ys code). *)

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
  - destruct (eval_exp e1 s) eqn:?; destruct o eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; inversion H3; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct o0 eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; inversion H3; subst; eauto.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct o eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; inversion H3; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct o0 eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; inversion H3; subst; eauto.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct o eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; inversion H3; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct o0 eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; inversion H3; subst; eauto.
    destruct (value_eqb v1 (ImpSyntax.Word (Naive.wrap 0))) eqn:?.
    1: congruence.
    unfold combine_word in *.
    destruct v0; unfold_outcome.
    2: congruence.
    destruct v1; unfold_outcome.
    all: congruence.
  - destruct (eval_exp e1 s) eqn:?; destruct o eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe1 in Heqp; inversion H3; subst; eauto.
    destruct (eval_exp e2 s0) eqn:?; destruct o0 eqn:?.
    2: unfold not; intros; inversion H; subst; eapply IHe2 in Heqp0; inversion H3; subst; eauto.
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
    destruct o1 eqn:?.
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
  - destruct eval_exp eqn:?; destruct o eqn:?; cleanup.
    all: eapply eval_exp_not_stop in Heqp; eauto; try congruence.
    destruct eval_exp eqn:?; destruct o0 eqn:?; subst; cleanup.
    all: eapply eval_exp_not_stop in Heqp0; eauto; try congruence.
    destruct c eqn:?; simpl in *; cleanup.
    all: destruct v0 eqn:?; destruct v1 eqn:?; subst; cleanup.
    all: unfold_outcome; cleanup; try congruence.
  - destruct eval_test eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt1 in Heqp; eauto.
    destruct (eval_test t2) eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt2 in Heqp0; eauto.
    congruence.
  - destruct eval_test eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt1 in Heqp; eauto.
    destruct (eval_test t2) eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt2 in Heqp0; eauto.
    congruence.
  - destruct eval_test eqn:?; destruct o eqn:?; subst; cleanup.
    2: unfold not; intros; inversion H; subst; eapply IHt in Heqp; eauto.
    congruence.
  (* TODO(kπ) Does this imply some sort of error? *)
  Unshelve.
  + exact Abort.
  + exact Abort.
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
  eexists; split. *)

Theorem memory_set_pc: forall s p,
  memory (set_pc p s) = memory s.
Proof.
  intros; simpl; reflexivity.
Qed.

Theorem env_ok_pmap_subsume: forall vars vs curr pmap pmap1,
  env_ok vars vs curr pmap ->
  pmap_subsume pmap pmap1 ->
  env_ok vars vs curr pmap1.
Proof.
  intros.
  unfold env_ok, pmap_subsume in *; cleanup.
  split; eauto.
  intros.
  eapply H1 in H2; clear H1; cleanup.
  split; eauto; eexists; eauto.
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
  all: try inversion H5; try clear H5; subst.
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

Theorem index_of_spec_add: forall name vs k i,
  index_of name (k + i) vs = i + index_of name k vs.
Proof.
  intros.
  rewrite index_of_spec.
  symmetry.
  rewrite index_of_spec.
  lia.
Qed.

Theorem index_of_bounds: forall name vs k,
  index_of name k vs ≤ k + List.length vs.
Proof.
  induction vs; intros; simpl.
  1: rewrite Nat.add_0_r; constructor.
  simpl; destruct a.
  - destruct (_ =? _) eqn:?; simpl; try rewrite IHvs; lia.
  - try rewrite IHvs; lia.
Qed.

Theorem index_of_In: forall name vs k,
  index_of name k vs < k + List.length vs <-> In (Some name) vs.
Proof.
  induction vs; intros; simpl.
  1: rewrite Nat.add_0_r.
  1: split; intros H; [lia|inversion H].
  simpl; destruct a.
  - destruct (_ =? _) eqn:?; simpl; split; intros H.
    all: try rewrite Nat.eqb_eq in *; subst; eauto.
    all: try lia.
    1: right; rewrite <- IHvs.
    1: pat `index_of _ _ _ < _` at rewrite index_of_spec_add in pat.
    1: pat `_ < _ + S _` at rewrite Nat.add_succ_r in pat; rewrite Nat.add_1_l in pat; eapply PeanoNat.lt_S_n in pat.
    1: eauto.
    rewrite index_of_spec_add.
    rewrite Nat.add_succ_r.
    rewrite Nat.add_1_l.
    rewrite <- Nat.succ_lt_mono.
    rewrite IHvs.
    pat `_ \/ _` at destruct pat.
    1: pat `Some _ = Some _` at inversion pat; rewrite Nat.eqb_neq in *|-; congruence.
    eauto.
  - split; intros.
    1: right; rewrite <- IHvs.
    1: pat `index_of _ _ _ < _` at rewrite index_of_spec_add in pat.
    1: pat `_ < _ + S _` at rewrite Nat.add_succ_r in pat; rewrite Nat.add_1_l in pat; eapply PeanoNat.lt_S_n in pat.
    1: eauto.
    rewrite index_of_spec_add.
    rewrite Nat.add_succ_r.
    rewrite Nat.add_1_l.
    rewrite <- Nat.succ_lt_mono.
    rewrite IHvs.
    pat `_ \/ _` at destruct pat.
    1: pat `None = Some _` at inversion pat.
    eauto.
Qed.

Theorem index_of_app: forall name k vs1 vs2,
  index_of name k vs1 < (List.length vs1) ->
    index_of name k vs1 = index_of name k (vs1 ++ vs2).
Proof.
  intros.
  induction vs1; simpl in *.
  - inversion H.
  - destruct a.
    + destruct (_ =? _); try reflexivity.
      assert (index_of name k vs1 = index_of name k (vs1 ++ vs2)).
      2: {
        do 2 (rewrite index_of_spec; symmetry).
        pat `index_of name k vs1 = index_of name k (vs1 ++ vs2)` at do 2 (rewrite index_of_spec in pat; symmetry in pat).
        lia.
      }
      rewrite IHvs1; eauto.
      rewrite index_of_spec in *.
      lia.
    + assert (index_of name k vs1 = index_of name k (vs1 ++ vs2)).
      2: {
        do 2 (rewrite index_of_spec; symmetry).
        pat `index_of name k vs1 = index_of name k (vs1 ++ vs2)` at do 2 (rewrite index_of_spec in pat; symmetry in pat).
        lia.
      }
      rewrite IHvs1; eauto.
      rewrite index_of_spec in *.
      lia.
Qed.

Theorem index_of_lbound: forall name vs k,
  k ≤ index_of name k vs.
Proof.
  induction vs; intros; simpl.
  1: constructor.
  simpl; destruct a.
  - destruct (_ =? _) eqn:?; simpl; [constructor|].
    specialize (IHvs (k + 1)).
    lia.
  - specialize (IHvs (k + 1)).
    lia.
Qed.

Theorem index_of_bound_inj: forall vs nm1 nm2 k i,
  index_of nm1 k vs = i -> index_of nm2 k vs = i ->
  k + i < (List.length vs) ->
    nm1 = nm2.
Proof.
  induction vs; intros; cleanup.
  - simpl in *; cleanup.
    pat `_ < 0` at inversion pat.
  - simpl in *.
    destruct a.
    2: {
      assert (S (index_of nm1 k vs) = i) by (rewrite index_of_spec in *; lia).
      assert (S (index_of nm2 k vs) = i) by (rewrite index_of_spec in *; lia).
      destruct i; [rewrite index_of_spec in *; lia|].
      ring_simplify in H1.
      specialize (IHvs nm1 nm2 k i).
      pat `S _ = S _` at eapply eq_add_S in pat.
      pat `S _ = S _` at eapply eq_add_S in pat.
      eapply IHvs; eauto.
      lia.
    }
    destruct (n =? nm1) eqn:?; destruct (n =? nm2) eqn:?.
    all: try rewrite Nat.eqb_eq in *; eauto; try congruence; cleanup.
    all: try (spat `index_of` at rewrite index_of_spec in spat; lia).
    assert (S (index_of nm1 k vs) = i) by (rewrite index_of_spec in *; lia).
    assert (S (index_of nm2 k vs) = i) by (rewrite index_of_spec in *; lia).
    destruct i; [rewrite index_of_spec in *; lia|].
    ring_simplify in H1.
    specialize (IHvs nm1 nm2 k i).
    pat `S _ = S _` at eapply eq_add_S in pat.
    pat `S _ = S _` at eapply eq_add_S in pat.
    eapply IHvs; eauto.
    lia.
Qed.

(* Lemma index_of_opt_spec: forall name vs k,
  index_of_opt name k vs = Some  k + index_of name 0 vs. *)

Lemma index_of_opt_in_bounds_str: forall nm vs k i,
  index_of_opt nm k vs = Some i -> i < List.length vs + k.
Proof.
  induction vs; intros; simpl in *.
  1: pat `None = Some _` at inversion pat.
  destruct a; cleanup.
  - destruct (_ =? _) eqn:?; cleanup.
    + lia.
    + spat `index_of_opt` at eapply IHvs in spat.
      lia.
  - spat `index_of_opt` at eapply IHvs in spat.
    lia.
Qed.

Lemma index_of_opt_in_gt_k_str: forall nm vs k i,
  index_of_opt nm k vs = Some i -> i >= k.
Proof.
  induction vs; intros; simpl in *.
  1: pat `None = Some _` at inversion pat.
  destruct a; cleanup.
  - destruct (_ =? _) eqn:?; cleanup.
    + lia.
    + spat `index_of_opt` at eapply IHvs in spat.
      lia.
  - spat `index_of_opt` at eapply IHvs in spat.
    lia.
Qed.

Lemma index_of_opt_in_bounds: forall nm vs i,
  index_of_opt nm 0 vs = Some i -> i < List.length vs.
Proof.
  intros.
  spat `index_of_opt` at specialize (index_of_opt_in_bounds_str _ _ _ _ spat) as ?.
  lia.
Qed.

Lemma index_of_opt_Some_non_empty: forall nm vs k i,
  index_of_opt nm k vs = Some i -> List.length vs > 0.
Proof.
  induction vs; intros; simpl in *.
  1: pat `None = Some _` at inversion pat.
  destruct a; cleanup.
  - destruct (_ =? _) eqn:?; cleanup.
    + lia.
    + spat `index_of_opt` at eapply IHvs in spat.
      lia.
  - spat `index_of_opt` at eapply IHvs in spat.
    lia.
Qed.

Lemma index_of_opt_Some_index_of: forall nm vs k i,
  index_of_opt nm k vs = Some i -> index_of nm k vs = i.
Proof.
  induction vs; intros; simpl in *.
  1: pat `None = Some _` at inversion pat.
  destruct a; cleanup.
  - destruct (_ =? _) eqn:?; cleanup.
    + lia.
    + spat `index_of_opt` at eapply IHvs in spat.
      lia.
  - spat `index_of_opt` at eapply IHvs in spat.
    lia.
Qed.

Lemma index_of_opt_Some_any_k: forall nm vs k k1 i,
  index_of_opt nm k vs = Some i -> index_of_opt nm (k + k1) vs = Some (i + k1).
Proof.
  induction vs; intros; simpl in *.
  1: pat `None = Some _` at inversion pat.
  destruct a; cleanup.
  - destruct (_ =? _) eqn:?; cleanup.
    + reflexivity.
    + spat `index_of_opt` at eapply IHvs in spat.
      spat `index_of_opt` at rewrite <- spat.
      f_equal.
      lia.
  - spat `index_of_opt` at eapply IHvs in spat.
    spat `index_of_opt` at rewrite <- spat.
    f_equal.
    lia.
Qed.

Lemma index_of_opt_Some_0_k: forall nm vs k i,
  index_of_opt nm 0 vs = Some i -> index_of_opt nm k vs = Some (i + k).
Proof.
  intros * H.
  eapply index_of_opt_Some_any_k in H.
  eauto.
Qed.

Lemma index_of_opt_Some_inj: forall vs nm1 nm2 k i,
  index_of_opt nm1 k vs = Some i /\ index_of_opt nm2 k vs = Some i ->
    nm1 = nm2.
Proof.
  induction vs; intros; cleanup.
  - simpl in *; cleanup.
  - simpl in *.
    destruct a.
    2: specialize (IHvs _ _ _ _ (conj H H0)); assumption.
    destruct (n =? nm1) eqn:?; destruct (n =? nm2) eqn:?.
    all: try rewrite Nat.eqb_eq in *; eauto; try congruence; cleanup.
    all: spat `index_of_opt` at eapply index_of_opt_in_gt_k_str in spat.
    all: lia.
Qed.

(* Lemma index_of_opt_Some_nth_error: forall nm vs i,
  index_of_opt nm 0 vs = Some i -> nth_error vs i = Some (Some nm).
Proof.
  (* induction vs; intros; simpl in *.
  1: pat `None = Some _` at inversion pat.
  destruct a; cleanup.
  - destruct (_ =? _) eqn:?; cleanup.
    + rewrite Nat.eqb_eq in *; subst; simpl; reflexivity.
    + spat `index_of_opt` at eapply index_of_opt_Some_0_k in spat.
      spat `index_of_opt` at rewrite <- spat.
      f_equal.
      lia.
  - spat `index_of_opt` at eapply IHvs in spat.
    spat `index_of_opt` at rewrite <- spat.
    f_equal.
    lia. *)
Admitted. *)

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

Theorem env_ok_add_None: forall vars vs curr x pmap pmap1,
  env_ok vars vs curr pmap ->
  pmap_subsume pmap pmap1 ->
  env_ok vars (None :: vs) (Word x :: curr) pmap1.
Proof.
  intros * H.
  unfold env_ok in *; cleanup.
  split.
  1: simpl; eauto.
  intros*; intro HLookup.
  eapply H0 in HLookup; cleanup.
  spat `index_of` at pose proof spat as ?.
  split; eauto; try eexists; try split; try eexists; try split.
  all: simpl.
  all: try rewrite index_of_spec.
  all: unfold v_inv in *.
  1: eauto.
  1: simpl; eauto.
  destruct v; [assumption|].
  cleanup.
  unfold pmap_subsume in *.
  spat `∀ _, _` at pose proof spat as Hthm.
  pat `pmap _ = _` at eapply Hthm in pat.
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

Ltac apply_find_fun :=
  match goal with
  | [ H1 : find_fun _ _ = _, H2: context[find_fun _ _] |- _ ] =>
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
    apply_find_fun.
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
          spat `IEnv.lookup (vars s1) _ = Some _` at eapply spat in Heqo; cleanup.
          unfold v_inv in *; cleanup; subst.
          rewrite Nat.eqb_eq in *.
          rewrite Heqb in *.
          destruct curr; simpl in *; cleanup.
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
      destruct curr; simpl in *; subst; cleanup.
      simpl in *; cleanup.
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
    pat `In _ _` at rewrite <- index_of_In with (k := 0) in pat; rewrite Nat.add_0_l in pat.
    eapply step_load_rsp; eauto.
    all: unfold_stack; eauto.
    2: {
      rewrite <- H4 in *.
      rewrite nth_error_app.
      rewrite <- Nat.ltb_lt in *.
      pat `List.length vs = _` at rewrite <- pat.
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
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
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
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
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
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
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
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  destruct (eval_exp e2 s0) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp0 in H1; subst.
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
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
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  destruct (eval_exp e2 s0) eqn:?; simpl in *.
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
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
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  destruct (eval_exp e2 s0) eqn:?; simpl in *.
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
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
  destruct o eqn:?; subst; cleanup.
  destruct (eval_test tst2 s0) eqn:?; simpl in *.
  destruct o eqn:?; subst; cleanup.
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
  destruct o eqn:?; subst; cleanup.
  destruct (eval_test tst2 s0) eqn:?; simpl in *.
  destruct o eqn:?; subst; cleanup.
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
  destruct o eqn:?; subst; cleanup.
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

(* cmd *)

Ltac crunch_side_conditions_cmd :=
  repeat match goal with
  | [ |- _ ∧ _ ] => split
  | [ |- pmap_ok _ ] => progress eauto
  | [ |- pmap_subsume _ _ ] => eapply pmap_subsume_trans; progress eauto
  | [ |- state_rel _ _ _ ] => progress eauto
  | [ |- cmd_res_rel _ _ _ _ _ _ _ _ ] => progress eauto
  | _ => progress simpl
  | _ => assumption
  | _ => lia
  end.

Lemma steps_lift_fuel_from: forall s1 s2 n FromIState toIState newIState,
  steps (s1, toIState - FromIState) (s2, n) ->
  FromIState ≤ toIState ->
  toIState ≤ newIState ->
  steps (s1, newIState - FromIState) (s2, n + (newIState - toIState)).
Proof.
  intros * Hsteps **.
  eapply steps_add_fuel with (x := newIState - toIState) in Hsteps.
  assert (toIState - FromIState + (newIState - toIState) = newIState - FromIState) as ? by lia.
  spat `_ - _ + _ = _` at rewrite spat in *.
  assumption.
Qed.

Theorem c_cmd_Abort: forall (fuel: nat),
  goal_cmd ImpSyntax.Abort fuel.
Proof.
  unfold goal_cmd; intros.
  simpl c_cmd in *; cleanup.
  pat `has_stack _ _` at eapply has_stack_even in pat.
  simpl eval_cmd in *; unfold_outcome; cleanup.
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
  simpl; split; eauto; eauto.
  pat `ImpSemantics.output _ = _` at rewrite pat.
  rewrite prefix_correct.
  eapply substring_noop.
Qed.

(* Theorem c_cmd_Return: forall (e: exp),
  goal_cmd (ImpSyntax.Return e).
Proof.
  intros.
  unfold goal_cmd; intros.
  simpl eval_cmd in *; unfold bind in *.
  destruct (eval_exp) eqn:?; cleanup.
  destruct o eqn:?; subst.
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

Lemma env_ok_replace_head: forall vars vs curr xnew xold n v pmap,
  env_ok vars vs (Word xold :: curr) pmap →
  v_inv pmap v xnew →
  index_of n 0 vs = 0 →
  0 < List.length vs →
  index_of n 0 vs < (List.length vs) ->
  env_ok (IEnv.insert (n, Some v) vars) vs (Word xnew :: curr) pmap.
Proof.
  intros.
  unfold env_ok in *; cleanup.
  simpl in *.
  split; [assumption|].
  intros.
  destruct (n =? n0) eqn:?.
  - spat `IEnv.lookup` at rewrite Nat.eqb_eq in *; rewrite Heqb in spat.
    rewrite IEnv.lookup_insert_eq in *; cleanup.
    rewrite <- index_of_In with (k := 0); rewrite Nat.add_0_l.
    spat `_ = S _` at rewrite spat.
    split; try eexists; try split; simpl; cleanup; eauto.
    all: pat `index_of _ _ _ = 0` at rewrite pat; eauto.
    lia.
  - rewrite Nat.eqb_neq in *.
    rewrite IEnv.lookup_insert_neq in *; try assumption.
    spat `IEnv.lookup` at pose proof spat as Hlookup.
    pat `∀ _, _` as Hthm at eapply Hthm in Hlookup; cleanup.
    split; try eexists; try split; simpl; cleanup; eauto.
    destruct (index_of n0 0 vs) eqn:?.
    + spat `index_of n _ _ = _` at pose proof spat as Hidx_of_n.
      spat `index_of n0 _ _ = _` at pose proof spat as Hidx_of_n0.
      pat `0 < List.length vs` at pose proof pat as H0ltvs.
      specialize (index_of_bound_inj _ _ _ _ _ Hidx_of_n Hidx_of_n0 H0ltvs) as ?; subst.
      congruence.
    + simpl in *; assumption.
Qed.

Theorem list_update_append: forall {A: Type} (xs1 xs2 : list A) xnew n,
  n < List.length xs1 ->
  list_update n xnew (xs1 ++ xs2) = list_update n xnew xs1 ++ xs2.
Proof.
  intros *.
  revert n.
  induction xs1.
  - intros.
    destruct n; destruct xs2; simpl in *; eauto.
    all: pat `_ < 0` at inversion pat.
  - intros.
    destruct n; eauto.
    pat `forall _, _` at specialize (pat n).
    simpl in *; f_equal.
    eapply IHxs1.
    lia.
Qed.

Theorem list_update_size_same: forall {A: Type} (xs: list A) n x,
  List.length (list_update n x xs) = List.length xs.
Proof.
  induction xs; intros; simpl.
  all: destruct n; simpl; eauto.
Qed.

Lemma env_ok_replace_list_update: forall vars vs curr xnew x0 n n0 v pmap,
  env_ok vars vs (Word x0 :: curr) pmap →
  v_inv pmap v xnew →
  index_of n 0 vs = S n0 →
  S n0 < List.length vs →
  index_of n 0 vs < (List.length vs) ->
  env_ok (IEnv.insert (n, Some v) vars) vs (Word x0 :: list_update n0 (Word xnew) curr) pmap.
Proof.
  intros.
  unfold env_ok in *; cleanup.
  simpl in *.
  split.
  1: rewrite list_update_size_same; eauto.
  intros.
  rewrite <- index_of_In with (k := 0); rewrite Nat.add_0_l.
  destruct (n =? n1) eqn:?.
  - spat `IEnv.lookup` at rewrite Nat.eqb_eq in *; rewrite Heqb in spat.
    rewrite IEnv.lookup_insert_eq in *; cleanup.
    split; try eexists; try split; simpl; cleanup; eauto.
    all: pat `index_of _ _ _ = _` at rewrite pat; eauto.
    (* 1: rewrite list_update_size_same; eauto.
    1: spat `_ = S (List.length curr)` at rewrite <- spat.
    1: spat `index_of _ _ _ = _` at rewrite <- spat; eauto. *)
    admit.
  - rewrite Nat.eqb_neq in *.
    rewrite IEnv.lookup_insert_neq in *; try assumption.
    spat `IEnv.lookup` at pose proof spat as Hlookup.
    pat `∀ _, _` as Hthm at eapply Hthm in Hlookup; cleanup.
    admit.
    (* split; try eexists; try split; simpl; cleanup; eauto.
    destruct (index_of n0 0 vs) eqn:?.
    + spat `index_of n _ _ = _` at pose proof spat as Hidx_of_n.
      spat `index_of n0 _ _ = _` at pose proof spat as Hidx_of_n0.
      pat `0 < List.length vs` at pose proof pat as H0ltvs.
      specialize (index_of_bound_inj _ _ _ _ _ Hidx_of_n Hidx_of_n0 H0ltvs) as ?; subst.
      congruence.
    + simpl in *; assumption. *)
Admitted.

Theorem c_cmd_Assign: forall (n: name) (e: exp) (fuel: nat),
  goal_cmd (ImpSyntax.Assign n e) fuel.
Proof.
  intros.
  unfold goal_cmd; intros.
  simpl eval_cmd in *; unfold bind in *; simpl in *; subst.
  destruct eval_exp eqn:?; cleanup.
  simpl c_cmd in *; unfold c_assign, dlet, assign in *.
  destruct c_exp eqn:?; cleanup.
  simpl flatten in *; cleanup.
  repeat rewrite code_in_append in *; cleanup.
  destruct o; unfold_outcome; cleanup.
  2: eval_exp_contr_stop_tac.
  spat `eval_exp` at specialize (eval_exp_pure e _ _ _ Heqp) as ?; subst.
  eval_exp_correct_tac.
  destruct x eqn:?; destruct s eqn:?; cleanup; subst.
  2: contradiction.
  unfold exp_res_rel in *; cleanup; subst.
  spat `env_ok` at pose proof spat as Henv_ok; unfold env_ok in spat; cleanup.
  spat `c_exp` at rwr ltac:(specialize (c_exp_length _ _ _ _ _ spat)).
  spat `steps` at rw ltac:(specialize (steps_instructions _ _ _ _ spat)).
  unfold has_stack in *|-; cleanup.
  rewrite <- index_of_In with (k := 0) in *; rewrite Nat.add_0_l in *.
  destruct curr; cleanup.
  1: {
    pat `Datatypes.length _ = Datatypes.length []` at rewrite pat in *; simpl in *.
    pat `List.length _ = 0` at eapply length_zero_iff_nil in pat; subst; simpl in *.
    pat `0 < 0` at inversion pat.
  }
  destruct index_of eqn:?.
  1: {
    rewrite <- app_comm_cons in *.
    simpl in *; cleanup.
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eauto.
      eapply steps_step_same.
      eapply step_pop.
      1: eauto.
      pat `_ = stack s1` at rewrite <- pat.
      reflexivity.
    }
    simpl.
    unfold has_stack in *; cleanup.
    repeat match goal with
    | [ |- _ ∧ _ ] => split
    | [ |- ∃_, _ ] => eexists
    | [ |- pmap_subsume ?x ?x ] => eapply pmap_subsume_refl
    | [ |- _ - _ = _ ] => lia
    | _ => progress eauto
    end.
    1: pat `_ = stack t` at rewrite <- pat; rewrite app_comm_cons; reflexivity.
    eapply env_ok_replace_head; eauto.
    pat `index_of _ _ _ = _` at rewrite pat; assumption.
  }
  simpl flatten in *; repeat rewrite code_in_append in *; cleanup; simpl in *; cleanup.
  unfold has_stack in *|-; cleanup.
  pat `_ = S (List.length curr)` at rewrite pat in *.
  do 2 eexists; split.
  1: {
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_store_rsp.
    1: eauto.
    1: destruct rest; [spat `odd` at inversion spat|];
       pat `_ = stack s1` at rewrite <- pat in *; rewrite length_cons; rewrite length_app; lia.
    1: eauto.
    eapply steps_step_same.
    eapply step_pop.
    1: eauto.
    simpl.
    pat `_ = stack s1` at rewrite <- pat.
    reflexivity.
  }
  simpl.
  repeat match goal with
  | [ |- _ ∧ _ ] => split
  | [ |- ∃_, _ ] => eexists
  | [ |- pmap_subsume ?x ?x ] => eapply pmap_subsume_refl
  | [ |- _ - _ = _ ] => lia
  | _ => progress eauto
  end.
  3: lia.
  1: rewrite list_update_append; try lia.
  1: unfold has_stack; do 2 eexists; split; try split; simpl; try rewrite app_comm_cons; reflexivity.
  eapply env_ok_replace_list_update; eauto.
  all: pat `List.length vs = _` at rewrite pat; lia.
  Unshelve.
  eauto.
Qed.

Theorem c_cmd_Seq: forall (fuel: nat) (c1 c2: cmd),
  goal_cmd c1 fuel -> goal_cmd c2 fuel ->
  goal_cmd (ImpSyntax.Seq c1 c2) fuel.
Proof.
  intros.
  unfold goal_cmd; intros.
  simpl c_cmd in *; unfold dlet in *.
  simpl eval_cmd in *; unfold bind in *; simpl in *; subst.
  destruct (c_cmd c1 _ _ _) eqn:?; simpl in *; subst; cleanup.
  destruct (c_cmd c2 _ _ _) eqn:?; simpl in *; subst; cleanup.
  simpl flatten in *; repeat rewrite code_in_append in *; cleanup.
  pat `c_cmd c1 _ _ _ = _` at rwr ltac:(specialize (c_cmd_length c1 _ _ _ _ _ pat)).
  pat `c_cmd c2 _ _ _ = _` at specialize (c_cmd_length c2 _ _ _ _ _ pat) as ?; subst.
  destruct (eval_cmd c1 _) eqn:?; simpl in *; cleanup.
  assert (s0.(steps_done) <= s1.(steps_done)).
  1: destruct o; cleanup; repeat pat `eval_cmd _ _ _ = _` at eapply eval_cmd_steps_done_steps_up in pat; lia.
  assert (s.(steps_done) <= s0.(steps_done)).
  1: repeat pat `eval_cmd _ _ _ = _` at eapply eval_cmd_steps_done_steps_up in pat; lia.
  pat `goal_cmd c1 _` at unfold goal_cmd in pat; eapply pat in Heqp; clear pat; eauto; cleanup; [|destruct o; congruence].
  destruct x; destruct s2; cleanup.
  all: spat `steps` at pose proof spat.
  all: spat `steps` at eapply steps_add_fuel with (x := s1.(steps_done) - s0.(steps_done)) in spat.
  all: assert (steps_done s0 - steps_done s + (steps_done s1 - steps_done s0) = s1.(steps_done) - s.(steps_done)) as ? by lia.
  2: spat `_ = s1.(steps_done) - s.(steps_done)` at rewrite spat in *.
  2: do 2 eexists; split; eauto; split; eauto; split; eauto; split; eauto.
  2: admit. (* prefix s2 (string_of_list_ascii (ImpSemantics.output s1)) = true *)
  destruct o eqn:?; subst; cleanup.
  2: do 2 eexists; split; eauto.
  unfold cmd_res_rel in * |-; cleanup; subst.
  unfold goal_cmd in H0.
  pat `steps (State t, _) _` at rw ltac:(specialize (steps_instructions _ _ _ _ pat)).
  pat `eval_cmd c2 _ _ = _` at eapply H0 with (pmap := x0) in pat; clear H0; cleanup.
  2,3,4,8,9,10: eauto.
  2: instantiate (1 := x).
  all: eauto.
  spat `_ = s1.(steps_done) - s.(steps_done)` at rewrite spat in *.
  rewrite Nat.add_0_l in *.
  1: destruct x1; destruct s3; cleanup; subst.
  2: repeat eexists; repeat split; [eapply steps_trans|..]; eauto; simpl; eauto; eapply pmap_subsume_trans; eauto.
  all: simpl in *; cleanup; subst.
  1: {
    pat `has_stack t _` at specialize (has_stack_even _ _ pat) as ?.
    pat `has_stack s2 _` at specialize (has_stack_even _ _ pat) as ?.
    pat `steps (State s2, _) _` at rw ltac:(specialize (steps_instructions _ _ _ _ pat)).
    do 2 eexists.
    split.
    1: {
      eapply steps_trans.
      1: eauto.
      eauto.
    }
    crunch_side_conditions_cmd.
  }
Admitted.

Theorem c_cmd_While: forall (t: test) (c: cmd) (fuel: nat),
  goal_cmd c fuel ->
  (forall fuel1, fuel1 < fuel -> goal_cmd (ImpSyntax.While t c) fuel1) ->
  goal_cmd (ImpSyntax.While t c) fuel.
Proof.
  intros.
  unfold goal_cmd; intros.
  spat `c_cmd` at pose proof spat.
  spat `c_cmd` at simpl c_cmd in spat; unfold dlet in spat.
  Opaque c_cmd.
  simpl eval_cmd in *; unfold bind in *; simpl in *; subst.
  destruct (c_test_jump _ _ _ _ _) eqn:?; simpl in *; subst; cleanup.
  destruct (c_cmd c _ _ _) eqn:?; simpl in *; subst; cleanup.
  simpl flatten in *; repeat rewrite code_in_append in *; cleanup; simpl code_in in *.
  spat `c_test_jump` at rw ltac:(specialize (c_test_length _ _ _ _ _ _ _ spat)).
  spat `c_cmd c` at specialize (c_cmd_length c _ _ _ _ _ spat) as ?; subst.
  destruct eval_test eqn:?; cleanup.
  destruct o eqn:?; subst; cleanup.
  2: exfalso; destruct v eqn:?; spat `eval_test` at eapply eval_test_not_stop in spat; eauto; try congruence.
  unfold_outcome; cleanup.
  spat `c_test_jump` at
    assert (pc t0 + 3 = pc (set_pc (pc t0 + 3) t0)) as Htmp by reflexivity; rewrite Htmp in spat; clear Htmp.
  spat `c_cmd` at
    assert (pc t0 + 3 + Datatypes.length (flatten a) = pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) t0)) as Htmp by reflexivity; rewrite Htmp in spat; clear Htmp.
  spat `eval_test` at specialize (eval_test_pure t _ _ _ spat) as ?; subst.
  destruct v eqn:?; cleanup; subst.
  2: { (* test = false *)
    spat `eval_test` at eapply c_test_correct in spat.
    2: shelve.
    all: eauto.
    spat `_ -> _` at eauto; eapply spat in Heqp; clear spat; eauto; cleanup.
    all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
    destruct x eqn:?; destruct s eqn:?; subst; cleanup.
    2: contradiction.
    pat `state_rel _ _ t0` at pose proof pat.
    pat `state_rel _ _ t0` at unfold state_rel in pat; cleanup; subst.
    pat `state_rel _ _ s0` at unfold state_rel in pat; cleanup; subst.
    do 2 eexists; split.
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
      1: unfold fetch; pat `pc s0 = _` at rewrite pat.
      1: pat `steps _ _` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)).
      1: simpl; rewrite Nat.add_comm; eauto.
      constructor.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    repeat split; eauto; [eapply pmap_subsume_refl|..].
    1: lia.
    eexists; eexists; eauto.
  }
  (* test = true *)
  all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
  destruct eval_cmd eqn:?; destruct o eqn:?; subst; cleanup.
  2: { (* eval_cmd body = Stop v *)
    spat `eval_test` at eapply c_test_correct in spat.
    2: shelve.
    all: eauto.
    spat `_ -> _` at eauto; eapply spat in Heqp; clear spat; eauto; cleanup.
    all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
    destruct x eqn:?; destruct s eqn:?; cleanup; subst.
    2: contradiction.
    assert ((pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) t0)) = (pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) s2))) as Htmp by reflexivity; rewrite Htmp in *; clear Htmp.
    spat `eval_cmd c` at unfold goal_cmd in spat; eapply H in spat; eapply spat in H2; clear spat; cleanup; eauto.
    2: simpl; assert (pc t0 + 3 = S ( S ( S (pc t0)))) as -> by lia;
       pat `steps (State (set_pc _ t0), _) _` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); simpl; eauto.
    cleanup; subst.
    destruct x eqn:?;subst; cleanup; subst.
    pat `pc s2 = _` at rewrite <- pat in *.
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: eauto.
      1: econstructor.
      simpl.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: unfold fetch; simpl; pat `steps (State (set_pc _ t0), _) _` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); eauto.
      1: econstructor.
      simpl.
      eauto.
    }
    destruct s eqn:?.
    1: { (* steps (body) ~~> State *)
      simpl in *; cleanup.
      crunch_side_conditions_cmd.
    }
    (* steps (body) ~~> Halt *)
    simpl in *; cleanup.
    crunch_side_conditions_cmd.
  }
  (* eval_cmd body = Cont v *)
  spat `eval_test` at eapply c_test_correct in spat.
  2: shelve.
  all: eauto.
  spat `_ -> _` at eauto; eapply spat in Heqp; clear spat; eauto; cleanup.
  all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
  destruct x eqn:?; destruct s2 eqn:?; cleanup; subst.
  2: contradiction.
  assert ((pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) t0)) = (pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) s3))) as Htmp by reflexivity; rewrite Htmp in *; clear Htmp.
  assert (Cont v <> Stop Crash) by congruence.
  assert (s0.(steps_done) <= s.(steps_done)).
  1: pat `eval_cmd _ _ _ = _` at eapply eval_cmd_steps_done_steps_up in pat; lia.
  spat `eval_cmd c` at unfold goal_cmd in H; eapply H with (s1 := s) in spat; clear H; cleanup; eauto.
  2: simpl; assert (pc t0 + 3 = S ( S ( S (pc t0)))) as -> by lia;
      pat `steps (State (set_pc _ t0), _) _` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); simpl; eauto.
  cleanup; subst.
  destruct x eqn:?;subst; cleanup; subst.
  pat `pc s3 = _` at rewrite <- pat in *.
  Opaque eval_cmd.
  destruct fuel.
  1: spat `EVAL_CMD` at simpl in spat; unfold_outcome; cleanup.
  1: { (* fuel = 0 -> TimeOut *)
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: eauto.
      1: econstructor.
      simpl.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: unfold fetch; simpl; pat `steps (State (set_pc _ t0), _) _` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); eauto.
      1: econstructor.
      simpl.
      eauto.
    }
    destruct s2; cleanup.
    all: crunch_side_conditions_cmd.
  }
  (* fuel = S n *)
  spat `EVAL_CMD` at pose proof spat; eapply EVAL_CMD_steps_done_non_zero in spat; eauto.
  spat `EVAL_CMD` at simpl in spat; unfold_outcome; cleanup.
  spat `_ = (res, _)` at unfold bind in *; simpl in spat; subst.
  assert (s.(steps_done) <= s1.(steps_done)).
  1: pat `eval_cmd (While t c) _ _ = _` at eapply eval_cmd_steps_done_steps_up in pat; unfold_stack; simpl in *; lia.
  spat `steps (_, s.(steps_done) - s0.(steps_done)) (_, s.(steps_done) - s0.(steps_done))` at pose proof spat.
  spat `steps (_, s.(steps_done) - s0.(steps_done)) (_, s.(steps_done) - s0.(steps_done))` at apply steps_lift_fuel_from with (newIState := s1.(steps_done)) in spat; eauto.
  assert (s.(steps_done) - s0.(steps_done) + (s1.(steps_done) - s.(steps_done)) = s1.(steps_done) - s0.(steps_done)) as ? by lia.
  spat `_ = _ - _` at rewrite spat in *.
  spat `steps (_, s.(steps_done) - s0.(steps_done)) (_, _)` at pose proof spat.
  spat `steps (_, s.(steps_done) - s0.(steps_done)) (_, _)` at apply steps_lift_fuel_from with (newIState := s1.(steps_done)) in spat; eauto.
  destruct s2; cleanup; subst.
  2: { (* steps (body) ~~> Halt *)
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: eauto.
      1: econstructor.
      simpl.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: unfold fetch; simpl; pat `steps (State (set_pc _ t0), _) _` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); eauto.
      1: econstructor.
      simpl.
      eauto.
    }
    simpl in *; cleanup.
    crunch_side_conditions_cmd.
    admit. (* prefix s2 (string_of_list_ascii (ImpSemantics.output s1)) = true *)
  }
  (* steps (body) ~~> State *)
  all: pat `cmd_res_rel _ _ _ _ _ _ _` at unfold cmd_res_rel in pat; cleanup; eauto.
  spat `c_cmd _ (pc t0)` at assert (pc t0 = pc (set_pc (pc t0) s2)) as Hpceq by reflexivity; rewrite Hpceq in spat; clear Hpceq.
  assert (fuel < S fuel) as ? by lia.
  spat `_ < S _` at apply H0 in spat as Hgoal_While; clear H0.
  spat `eval_cmd (While t c)` at unfold goal_cmd in Hgoal_While; eapply Hgoal_While with (t := set_pc (pc t0) s2) in spat; clear Hgoal_While; cleanup.
  all: simpl; eauto.
  2: {
    simpl; repeat rewrite code_in_append; cleanup; repeat split.
    all: pat `steps (_, _) (State s2, _)` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); simpl.
    all: pat `steps (_, _) (State s3, _)` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); simpl.
    all: repeat rewrite Nat.add_1_r; eauto; pat `pc s3 = _` at try rewrite <- pat; eauto.
  }
  (* TODO(kπ): This is problematic. The body can declare new variables and then the stack contains new entries. *)
  (*           Should we drop the additional stuff from the stack after the body is executed? *)
  (* env_ok (vars s) vs' x x0 *)
  (* 2: admit. *)
  destruct x1.
  rewrite Nat.add_0_l in *.
  destruct (steps_done s1 - steps_done s) eqn:?.
  1: spat `0 < 0` at inversion spat.
  pat `steps _ (_, n0)` at simpl in pat.
  do 2 eexists; split.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump.
    1: eauto.
    1: econstructor.
    simpl.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump.
    1: unfold fetch; simpl; pat `steps (State (set_pc _ t0), _) _` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); eauto.
    1: econstructor.
    simpl.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_succ.
    1: eapply step_jump.
    1: {
      unfold fetch; simpl; pat `steps (_, _) (State s2, _)` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); simpl.
      pat `steps (_, _) (State s3, _)` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); simpl.
      pat `pc s2 = _` at rewrite pat; eauto.
      pat `pc s3 = _` at rewrite pat in *; eauto.
      assert (pc t0 + 3 + List.length (flatten a) = S (S (S (pc t0 + List.length (flatten a))))) as -> by lia; eauto.
    }
    1: econstructor.
    simpl.
    assert (n1 = s1.(steps_done) - s.(steps_done) - 1) as ? by lia.
    assert (s1.(steps_done) - (s.(steps_done) + 1) = s1.(steps_done) - s.(steps_done) - 1) as ? by lia.
    spat `_ = _ - _ - _` at rewrite spat in *; clear spat.
    spat `_ = _ - _ - _` at rewrite spat in *; clear spat.
    eauto.
  }
  destruct s4 eqn:?.
  1: { (* steps (body) ~~> State *)
    simpl in *; cleanup.
    crunch_side_conditions_cmd.
    assert ( (S (pc t0 + 3 + Datatypes.length (flatten a) + Datatypes.length (flatten a0))) =
      (S (Datatypes.length (flatten a0) + (pc t0 + 3 + Datatypes.length (flatten a))))) as <- by lia.
    eauto.
  }
  (* steps (body) ~~> Halt *)
  simpl in *; cleanup.
  crunch_side_conditions_cmd.
  Unshelve.
  all: eauto.
Admitted.

Theorem c_cmd_correct : forall (c: cmd) (fuel: nat),
  goal_cmd c fuel.
Proof.
  induction c.
  - intros; admit.
  - intros; eapply c_cmd_Seq; eauto.
  - intros; eapply c_cmd_Assign; eauto.
  - intros; admit.
  - intros; admit.
  - induction fuel; intros; eapply c_cmd_While; eauto; intros.
    + inversion H.
    + admit.
  - intros; admit.
  - intros; admit.
  - intros; admit.
  - intros; admit.
  - intros; admit.
  - intros; eapply c_cmd_Abort.
Admitted.

Definition init_state_ok_def (t: ASMSemantics.state) (input: llist ascii) (asm: asm) :=
  ∃r14 r15,
    t.(pc) = 0 ∧ t.(instructions) = asm ∧
    t.(ASMSemantics.input) = input ∧ t.(output) = [] ∧
    t.(stack) = [] ∧
    t.(regs) R14 = Some r14 ∧
    t.(regs) R15 = Some r15 ∧
    memory_writable r14 r15 t.(memory).

Definition asm_terminates (input: llist ascii) (asm: asm) (fuel: nat) (output: list ascii) :=
  exists t fuel_left,
    init_state_ok t input asm /\
      steps (State t, fuel) (Halt (word.of_Z 0) output, fuel_left).

Ltac destruct_pair :=
  pat `let (_, _) := ?x in _` at destruct x.

Lemma init_length_same: forall l1 l2,
  List.length (init l1) = List.length (init l2).
Proof.
  unfold init.
  reflexivity.
Qed.

Lemma binders_ok_append: forall c b1 b2,
  binders_ok c b1 ->
    binders_ok c (b1 ++ b2).
Proof.
  intros.
  induction c; simpl in *; cleanup; eauto.
  all: eapply in_or_app; eauto.
Qed.

Lemma binders_ok_append2: forall c b1 b2,
  binders_ok c b2 ->
    binders_ok c (b1 ++ b2).
Proof.
  intros.
  induction c; simpl in *; cleanup; eauto.
  all: eapply in_or_app; eauto.
Qed.

Lemma make_vs_from_binders_length: forall l,
  List.length (make_vs_from_binders l) = List.length l.
Proof.
  induction l; simpl in *; eauto.
Qed.

Lemma make_vs_from_binders_spec: forall ns,
  make_vs_from_binders ns = List.map (fun n => Some n) ns.
Proof.
  induction ns; eauto.
Qed.

Lemma binders_ok_all_binders: forall c,
  binders_ok c (make_vs_from_binders (all_binders c)).
Proof.
  induction c; simpl in *; eauto.
  all: split.
  all: rewrite make_vs_from_binders_spec.
  all: rewrite map_app.
  1,3: eapply binders_ok_append; eauto.
  all: eapply binders_ok_append2; eauto.
Qed.

Theorem names_contain_spec: forall x ns,
  names_contain ns x = true <-> In x ns.
Proof.
  induction ns; simpl in *; eauto.
  - split; intros; [congruence|eauto].
  - destruct (_ =? _) eqn:?; simpl; eauto.
    + rewrite Nat.eqb_eq in *; split; eauto.
    + rewrite Nat.eqb_neq in *.
      split; intros; [rewrite <- IHns|rewrite IHns]; eauto.
      pat `_ \/ _` at destruct H; congruence.
Qed.

Lemma names_unique_In: forall ns x acc,
  (In x ns \/ In x acc) -> In x (names_unique ns acc).
Proof.
  induction ns; intros; simpl in *; eauto.
  1: pat `_ \/ _` at destruct pat; eauto.
  1: pat `False` at inversion pat.
  destruct (names_contain acc a) eqn:?.
  - rewrite names_contain_spec in *; cleanup.
    pat `_ \/ _` at destruct pat; eauto.
    pat `_ \/ _` at destruct pat; eauto.
    eapply IHns; subst; eauto.
  - subst.
    eapply IHns; subst; eauto; simpl in *; cleanup.
    pat `_ \/ _` at destruct pat; eauto.
    pat `_ \/ _` at destruct pat; eauto.
Qed.

Lemma binders_ok_names_unique: forall c ns,
  binders_ok c (make_vs_from_binders ns) ->
    binders_ok c (make_vs_from_binders (names_unique ns [])).
Proof.
  induction c; intros; simpl in *; cleanup; eauto.
  all: rewrite make_vs_from_binders_spec in *.
  all: rewrite in_map_iff in *; cleanup; eexists; split; eauto.
  all: eapply names_unique_In; eauto.
Qed.

Theorem binders_ok_unique_binders: forall c,
  binders_ok c (make_vs_from_binders (unique_binders c)).
Proof.
  induction c; simpl in *; eauto.
  all: try split.
  all: unfold unique_binders, dlet in *; simpl.
  all: eapply binders_ok_names_unique.
  all: rewrite make_vs_from_binders_spec; rewrite map_app.
  1,3: eapply binders_ok_append.
  3,4: eapply binders_ok_append2.
  all: rewrite <- make_vs_from_binders_spec.
  all: eapply binders_ok_all_binders.
Qed.

Lemma c_pushes_length: forall ps l asm1 vs1 l1,
  c_pushes ps l = (asm1, vs1, l1) -> l1 = List.length (flatten asm1) + l.
Proof.
  intros.
  unfold c_pushes, dlet in *; simpl in *.
  repeat pat ` (if ?c then _ else _) = _` at destruct c eqn:?; cleanup; simpl in *; [lia|].
  lia.
Qed.

Lemma c_fundef_length: forall f l fs c1 l1,
  c_fundef f l fs = (c1, l1) -> l1 = List.length (flatten c1) + l.
Proof.
  intros.
  unfold c_fundef, dlet in *.
  pat `match ?a with _ => _ end = _` at destruct a; simpl in *|-.
  destruct (c_pushes) eqn:?.
  pat `c_pushes _ _ = (?p, _)` at destruct p.
  destruct (c_cmd) eqn:?.
  spat `c_cmd` at eapply c_cmd_length in spat.
  spat `c_pushes` at eapply c_pushes_length in spat.
  simpl in *; cleanup.
  simpl.
  repeat (rewrite length_app; simpl).
  lia.
Qed.

Lemma c_cmd_l_same: forall c lstart f_lookup f_lookup0 a1 a2 vs l1 l2,
  c_cmd c lstart f_lookup vs = (a1, l1) ->
  c_cmd c lstart f_lookup0 vs = (a2, l2) ->
  l1 = l2.
Proof.
  induction c; intros.
  Transparent c_cmd.
  all: simpl in *; unfold dlet in *; cleanup; eauto.
  Opaque c_cmd.
  - destruct c_cmd eqn:?.
    destruct (c_cmd c1) eqn:?.
    destruct (c_cmd _ _ f_lookup0) eqn:?.
    destruct (c_cmd c1 _ f_lookup0) eqn:?.
    simpl in *.
    eapply IHc1 in Heqp0; eauto; subst.
    eapply IHc2; eauto.
  - destruct c_cmd eqn:?.
    destruct (c_cmd c1) eqn:?.
    destruct (c_cmd _ _ f_lookup0) eqn:?.
    destruct (c_cmd c1 _ f_lookup0) eqn:?.
    simpl in *.
    eapply IHc1 in Heqp0; eauto; subst.
    eapply IHc2; eauto.
  - destruct c_cmd eqn:?.
    destruct (c_test_jump) eqn:?.
    destruct (c_cmd _ _ f_lookup0) eqn:?.
    simpl in *.
    f_equal.
    eapply IHc; eauto.
  - destruct c_var eqn:?.
    destruct (c_var n (snd (c_exps es lstart vs) + app_list_length (c_pops es vs) + app_list_length (align (even_len vs) (List [Call (lookup f f_lookup0)])))) eqn:?.
    destruct c_exps eqn:?.
    simpl in *.
    destruct even_len eqn:?; simpl in *.
    all: spat `c_var` at rewrite spat in *; cleanup.
    all: reflexivity.
Qed.

Lemma c_fundef_l_same: forall f lstart f_lookup f_lookup0 a1 a2 l1 l2,
  c_fundef f lstart f_lookup = (a1, l1) ->
  c_fundef f lstart f_lookup0 = (a2, l2) ->
  l1 = l2.
Proof.
  intros.
  unfold c_fundef,dlet in *.
  pat `match ?f with _ => _ end = _` at destruct f.
  destruct c_pushes eqn:?.
  pat `c_pushes _ _ = (?p, _)` at destruct p.
  destruct c_cmd eqn:?.
  destruct (c_cmd _ _ f_lookup0) eqn:?.
  simpl in *; cleanup.
  eapply c_cmd_l_same; eauto.
Qed.

Lemma c_fundefs_l_same: forall funs lstart f_lookup f_lookup0 a1 a2 fs1 fs2 l1 l2,
  c_fundefs funs lstart f_lookup = (a1, fs1, l1) ->
  c_fundefs funs lstart f_lookup0 = (a2, fs2, l2) ->
  l1 = l2.
Proof.
  induction funs; intros; simpl in *; cleanup; eauto.
  unfold dlet in *.
  destruct c_fundef eqn:?.
  destruct (c_fundef _ _ f_lookup0) eqn:?.
  destruct c_fundefs eqn:?.
  pat `c_fundefs _ _ _ = (?p, _)` at destruct p.
  destruct (c_fundefs _ _ f_lookup0) eqn:?.
  pat `c_fundefs _ _ _ = (?p, _)` at destruct p.
  simpl in *; cleanup; subst.
  eapply c_fundef_l_same in Heqp; eauto; subst.
  eapply IHfuns; eauto.
Qed.

Theorem code_in_append_left: forall ys xs k,
  k = List.length xs -> code_in k ys (xs ++ ys).
Proof.
  induction ys as [|h ys' IH]; intros xs k Hk; subst.
  - simpl; constructor.
  - simpl; split.
    + rewrite nth_error_app2.
      * rewrite Nat.sub_diag; simpl; reflexivity.
      * lia.
    + assert (xs ++ h :: ys' = (xs ++ [h]) ++ ys') as ->.
      1: induction xs; simpl; congruence.
      apply IH.
      rewrite length_app; simpl.
      lia.
Qed.

Theorem code_in_append_left2: forall ys xs zs k,
  k = List.length xs -> code_in k ys (xs ++ ys ++ zs).
Proof.
  induction ys as [|h ys' IH]; intros xs zs k Hk; subst.
  - simpl; constructor.
  - simpl; split.
    + rewrite nth_error_app2.
      * rewrite Nat.sub_diag; simpl; reflexivity.
      * lia.
    + assert (xs ++ h :: ys' ++ zs = (xs ++ [h]) ++ ys' ++ zs) as ->.
      1: induction xs; simpl; congruence.
      apply IH.
      rewrite length_app; simpl.
      lia.
Qed.

Lemma lookup_append: forall n fs1 fs0 l,
  exists pos,
    lookup n (fs1 ++ (n, l) :: fs0) = pos.
Proof.
  induction fs1; intros; simpl in *.
  - eexists.
    rewrite Nat.eqb_refl.
    reflexivity.
  - destruct a.
    destruct (_ =? _) eqn:?.
    + rewrite Nat.eqb_eq in *; subst; eauto.
    + eauto.
Qed.

Lemma c_fundefs_lookup_same: forall funcs fs0 fs1 fs2 fs3 asm1 asm2 l1 l2 n params body l,
  c_fundefs funcs l fs0 = (asm1, fs1, l1) ->
  c_fundefs funcs l fs2 = (asm2, fs3, l2) ->
  find_fun n funcs = Some (params, body) ->
  lookup n fs1 = lookup n fs3.
Proof.
  Opaque c_fundef.
  induction funcs; intros; simpl in *; eauto; cleanup.
  unfold dlet in *; cleanup.
  destruct (c_fundef _ _ _) eqn:?.
  destruct (c_fundefs _ _ _) eqn:?.
  pat `c_fundefs _ _ _ = (?p, _)` at destruct p.
  simpl in *; cleanup.
  destruct (c_fundef _ _ fs2) eqn:?.
  destruct (c_fundefs _ _ fs2) eqn:?.
  pat `c_fundefs _ _ _ = (?p, _)` at destruct p.
  (* set asm1 as Sasm1. *)
  (* set fs as Sfs. *)
  (* set l1 as Sl1. *)
  simpl in *|-; cleanup; subst.
  pat `match ?a with _ => _ end = _` at destruct a; simpl in *.
  rewrite Nat.eqb_sym.
  destruct (_ =? _) eqn:?.
  - reflexivity.
  - eapply IHfuncs; eauto.
    spat `c_fundef` at eapply c_fundef_l_same in spat; [|exact Heqp]; subst.
    pat `c_fundefs _ _ _ = (_, l0, _)` at eapply c_fundefs_l_same in pat; eauto.
Qed.

Lemma c_fundefs_code_in: forall funcs fs0 fs asm1 l1 n params body xs,
  c_fundefs funcs (List.length xs) fs0 = (asm1, fs, l1) ->
  find_fun n funcs = Some (params, body) ->
  exists pos,
    lookup n fs = pos ∧ (* No fail case here... (<> 0) ? *)
    code_in pos (flatten (fst (c_fundef (Func n params body) pos fs0)))
      (xs ++ flatten asm1).
Proof.
  Opaque c_fundef.
  induction funcs; intros; simpl in *|-; cleanup.
  unfold dlet in *.
  destruct (c_fundef _ _ _) eqn:?.
  destruct (c_fundefs _ _ _) eqn:?.
  pat `c_fundefs _ _ _ = (?p, _)` at destruct p.
  set asm1 as Sasm1.
  set fs as Sfs.
  set l1 as Sl1.
  simpl in *|-; cleanup.
  pat `match ?a with _ => _ end = _` at destruct a; simpl in *|-.
  destruct (_ =? _) eqn:?; cleanup.
  1: {
    eexists; simpl.
    rewrite Nat.eqb_eq in *; subst.
    rewrite Nat.eqb_refl.
    split.
    2: {
      spat `c_fundef` at rewrite spat; simpl.
      assert (xs ++ Comment (name2str n1 "") :: flatten a0 ++ flatten a1 = (xs ++ [Comment (name2str n1 "")]) ++ flatten a0 ++ flatten a1) as ->.
      1: induction xs; simpl; try rewrite <- app_assoc; eauto.
      eapply code_in_append_left2.
      rewrite length_app; simpl.
      lia.
    }
    reflexivity.
  }
  subst Sasm1 Sfs.
  pat `c_fundef _ _ _ = _` at eapply c_fundef_length in pat; subst.
  assert (Datatypes.length (flatten a0) + (Datatypes.length xs + 1) = List.length (xs ++ flatten (List [Comment (name2str n1 "")] +++ a0))) as Hrwlength.
  1: simpl; repeat rewrite length_app; simpl; lia.
  rewrite Hrwlength in *.
  spat `c_fundefs` at eapply IHfuncs in spat; eauto; cleanup.
  eexists; split; simpl.
  1: {
    destruct (n1 =? n) eqn:?; try rewrite Nat.eqb_neq in *; try rewrite Nat.eqb_eq in *.
    - congruence.
    - eauto.
  }
  simpl in *.
  rewrite app_comm_cons; rewrite app_assoc.
  eauto.
Qed.

(* TODO: use eval_from here? *)
Theorem codegen_thm: forall main_c fuel s s1 res r14 r15 t funcs,
  catch_return (eval_cmd main_c (EVAL_CMD fuel)) s = (res,s1) -> res ≠ Stop Crash ->
  s.(vars) = IEnv.empty ->
  s.(ImpSemantics.memory) = [] ->
  s.(funs) = funcs ->
  t.(pc) = 0 ->
  t.(instructions) = codegen (Program funcs) ->
  find_fun (fun_name_of_string "main") funcs = Some ([], main_c) ->
  t.(stack) = [] ->
  t.(input) = s.(ImpSemantics.input) ->
  t.(output) = s.(ImpSemantics.output) ->
  t.(regs) R14 = Some r14 ->
  t.(regs) R15 = Some r15 ->
  memory_writable r14 r15 t.(memory) ->
  exists outcome,
    steps (State t, s1.(steps_done) - s.(steps_done)) outcome ∧
    match outcome with
    | (State t1, ck) =>
      t1.(output) = s1.(ImpSemantics.output) ∧
      ck = 0 ∧ (* Is 0 correct here? *)
      res = Stop TimeOut
    | (Halt ec output, ck) =>
      if word.eqb ec (word.of_Z 0) then
        output = s1.(ImpSemantics.output) ∧
        exists v, res = Cont v
        (* exists v, res = Stop (Return v) *)
        (* should it be v = 0 ? *)
      else
        prefix (string_of_list_ascii output) (string_of_list_ascii s1.(ImpSemantics.output)) = true
    end.
Proof.
  intros.
  Opaque word.eqb.
  Opaque init.
  unfold codegen, dlet in *.
  Opaque fun_name_of_string.
  simpl in *.
  unfold catch_return in *.
  spat `let (_, _) := ?x in _` at destruct x eqn:?; unfold_outcome.
  destruct (c_fundefs funcs _ _) eqn:Heqcfuns0.
  spat `c_fundefs _ _ _ = (?p, _)` at destruct p.
  simpl in *.
  destruct (c_fundefs funcs _ l) eqn:Heqcfuns.
  spat `c_fundefs _ _ _ = (?p, _)` at destruct p.
  simpl in *.
  spat `eval_cmd` at rename spat into Heval_cmd.
  specialize c_fundefs_l_same with (1 := Heqcfuns) (2 := Heqcfuns0) as ?; subst.
  remember (lookup _ l) as lookup_main_l.
  spat `c_fundefs` at rewrite init_length_same with (l2 := lookup_main_l) in spat.
  pat `find_fun _ _ = _` at rename pat into Hfind_fun.
  pat `c_fundefs _ _ _ = (_, _, _)` at specialize c_fundefs_code_in with (1 := pat) (2 := Hfind_fun) as ?; cleanup.
  Transparent c_fundef.
  rewrite c_fundefs_lookup_same with (fs1 := l0) (fs3 := l) (n := fun_name_of_string "main") (1 := Heqcfuns) (2 := Heqcfuns0) (3 := Hfind_fun) in *.
  unfold c_fundef, dlet in *.
  destruct (c_pushes _ _) eqn:?.
  destruct (c_cmd _ _) eqn:?.
  simpl in *.
  repeat (rewrite code_in_append in *; simpl in * ); cleanup.
  assert (s0 = s1) by do 2 (spat `match ?o with _ => _ end` at destruct o; inversion spat; try congruence).
  (* pat ` (_, _) = (_, _)` at inversion pat; clear pat. *)
  pat `c_pushes _ _ = (?p, _)` at destruct p.
  unfold c_pushes, dlet in *; simpl in *.
  pat ` (_, _, _) = (_, _, _)` at inversion pat; subst; clear pat.
  remember (lookup _ l) as lookup_main_l.
  repeat (rewrite code_in_append in *; simpl in * ); cleanup.
  rewrite Nat.add_0_r in *.
  remember (make_vs_from_binders _) as vs_binders.
  pose proof c_cmd_correct as Hccorrect; unfold goal_cmd in Hccorrect.
  eapply Hccorrect with (curr := (Word (word.of_Z 0)) :: (List.map (fun _ => Uninit) vs_binders)) (rest := [RetAddr 4]) in Heval_cmd as Hmain; clear Hccorrect; cleanup.
  all: simpl in *.
  1: { (* main goal *)
    destruct_pair.
    pat `t.(instructions) = _` at rename pat into Htinstrfolded.
    pat `t.(pc) = _` at rename pat into Htpc.
    Transparent init.
    pat `_ = init _ ++ _` at pose proof pat as Htinstr.
    pat `_ = init _ ++ _` at unfold init in pat.
    Opaque init.
    simpl in *.
    remember (Comment "malloc" :: _) as init_rest; clear Heqinit_rest.
    unfold cmd_res_rel in * ; cleanup.
    pat `eval_cmd _ _ _ = (?res, _)` at destruct res; cleanup.
    1: congruence.
    (* res = Stop v *)
    pat `match ?s with _ => _ end` at destruct s; cleanup.
    1: { (* s0 = State *)
      pat `eval_cmd _ _ _ = (Stop ?v, _)` at destruct v; cleanup; [| |congruence|pat `False` at inversion pat].
      1: { (*res = Stop (Return v)*)
        eexists; split.
        1: {
          eapply steps_trans.
          1: eapply steps_step_same; eapply step_const.
          1: unfold fetch; rewrite Htinstr; rewrite Htpc; simpl; eauto.
          eapply steps_trans.
          1: eapply steps_step_same; eapply step_const.
          1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
          eapply steps_trans.
          1: eapply steps_step_same; eapply step_const.
          1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
          eapply steps_trans.
          1: eapply steps_step_same; eapply step_call.
          1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
          eapply steps_trans.
          1: simpl in *.
          1: eapply steps_step_same; eapply step_sub_rsp.
          1: unfold fetch; simpl; rewrite Htinstrfolded; simpl; eauto.
          1: reflexivity.
          eapply steps_trans.
          1: simpl in *; eauto.
          pat `steps _ _` at specialize (steps_instructions _ _ _ _ pat) as Hs0instr; simpl in Hs0instr; rewrite Htinstr in Hs0instr.
          eapply steps_trans.
          1: eapply steps_step_same; eapply step_ret.
          1: eauto.
          1: unfold has_stack in *; cleanup; eauto.
          subst; simpl.
          eapply steps_trans.
          1: eapply steps_step_same; eapply step_const.
          1: unfold fetch; simpl; rewrite <- Hs0instr; simpl; eauto.
          eapply steps_step_same; eapply step_exit.
          1: unfold fetch; simpl; rewrite <- Hs0instr; simpl; eauto.
          1: simpl; reflexivity.
          simpl; rewrite Nat.Div0.mod_0_l; reflexivity.
        }
        simpl.
        rewrite Properties.word.eqb_eq; [|simpl;reflexivity].
        unfold state_rel in *; cleanup.
        split; eauto.
      }
      (* res = Stop TimeOut *)
      eexists; split.
      1: {
        eapply steps_trans.
        1: eapply steps_step_same; eapply step_const.
        1: unfold fetch; rewrite Htinstr; rewrite Htpc; simpl; eauto.
        eapply steps_trans.
        1: eapply steps_step_same; eapply step_const.
        1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
        eapply steps_trans.
        1: eapply steps_step_same; eapply step_const.
        1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
        eapply steps_trans.
        1: eapply steps_step_same; eapply step_call.
        1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
        eapply steps_trans.
        1: simpl in *.
        1: eapply steps_step_same; eapply step_sub_rsp.
        1: unfold fetch; simpl; rewrite Htinstrfolded; simpl; eauto.
        1: reflexivity.
        eauto.
      }
      simpl.
      unfold state_rel in *; cleanup.
      split; eauto.
    }
    (* s0 = Halt *)
    eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same; eapply step_const.
      1: unfold fetch; rewrite Htinstr; rewrite Htpc; simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same; eapply step_const.
      1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same; eapply step_const.
      1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same; eapply step_call.
      1: unfold fetch; simpl; rewrite Htinstr; rewrite Htpc; simpl; eauto.
      eapply steps_trans.
      1: simpl in *.
      1: eapply steps_step_same; eapply step_sub_rsp.
      1: unfold fetch; simpl; rewrite Htinstrfolded; simpl; eauto.
      1: simpl in *; reflexivity.
      simpl in *.
      pat `vs_binders = _` at rewrite <- pat in *.
      pat `lookup_main_l = _` at rewrite <- pat in *.
      eauto.
    }
    simpl.
    destruct (word.eqb)%Z eqn:?; cleanup; eauto.
    pat `_ ∨ _` at destruct pat.
    all: spat `word.eqb` at eapply Properties.word.eqb_true in spat; subst.
    all: rewrite Properties.word.eq_of_Z_iff in *.
    all: do 2 rewrite Z.mod_small in *; [|lia|lia|lia].
    all: spat `_ = 0%Z` at inversion spat.
  }
  all: simpl in *.
  1: do 2 (spat `match ?o with _ => _ end` at destruct o; inversion spat; try congruence).
  5: { (* has_stack *)
    unfold has_stack.
    do 2 eexists.
    repeat split.
    pat `stack t = _` at rewrite pat.
    pat `pc t = _` at rewrite pat.
    simpl.
    pat `vs_binders = _` at rewrite pat.
    reflexivity.
  }
  1: { (* c_cmd main_c *)
    pat `lookup_main_l = _` at rewrite <- pat.
    eauto.
  }
  1: { (* state_rel *)
    unfold state_rel; simpl.
    repeat split; eauto.
    - unfold init_code_in.
      eexists.
      pat `instructions t = _` at rewrite pat.
      Transparent init.
      simpl; repeat (split; eauto).
    - intros.
      spat `find_fun` at pose proof spat as Hfind_fun_n0; eapply c_fundefs_code_in in spat; eauto.
      pat `instructions t = _` at rewrite pat.
      cleanup; eexists.
      split; eauto.
      rewrite c_fundefs_lookup_same with (1 := Heqcfuns) (2 := Heqcfuns0) (3 := Hfind_fun_n0) in *; subst.
      eauto.
    - spat `memory_writable` at pose proof memory_writable as ?.
      spat `memory_writable` at unfold memory_writable in spat; cleanup.
      do 2 eexists.
      repeat split; eauto.
  }
  2: { (* binders_ok *)
    pat `vs_binders = _` at rewrite pat.
    eapply binders_ok_append.
    eapply binders_ok_unique_binders.
  }
  4: unfold odd, even; simpl; reflexivity.
  4: { (* code_in *)
    pat `lookup_main_l = _` at rewrite <- pat.
    pat `instructions t = _` at rewrite pat.
    eauto.
  }
  3: { (* pmap_ok *)
    instantiate (1 := (fun _ => None)).
    unfold pmap_ok.
    intros; cleanup.
  }
  1: { (* env_ok *)
    pat `vars s = _` at rewrite pat.
    unfold env_ok; simpl.
    Opaque init.
    repeat split.
    1: pat `vs_binders = _` at rewrite pat.
    1: rewrite length_app; simpl in *; rewrite length_map; lia.
    all: rewrite IEnv.lookup_empty in *; cleanup.
  }
  (* mem_inv *)
  pat `ImpSemantics.memory s = _` at rewrite pat.
  unfold mem_inv; intros.
  rewrite nth_error_nil in *; cleanup.
Qed.

Theorem codegen_terminates: forall fuel sd,
  forall input prog output1 output2,
    prog_terminates input prog fuel output1 sd /\
    asm_terminates input (codegen prog) sd output2 ->
      output1 = output2.
Proof.
  intros.
  destruct prog; cleanup.
  simpl in *; unfold prog_terminates, eval_from, asm_terminates, init_state_ok in *; cleanup; subst.
  pat `match ?s with _ => _ end = _` at destruct s eqn:?; unfold_outcome; cleanup.
  pat ` (let (_, _) := ?x in _) = _` at destruct x.
  pat `match ?s with _ => _ end = _` at destruct s; unfold_outcome; cleanup.
  spat `eval_cmd` at eapply codegen_thm in spat; simpl; eauto; cleanup; [|congruence].
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s.
  all: cleanup; subst.
  1: congruence.
  pat `if ?cond then _ else _` at destruct cond eqn:?.
  all: cleanup; subst.
  all: unfold init_state in *; simpl in *.
  all: rewrite Nat.sub_0_r in *.
  all: spat `steps` at eapply steps_determ in spat; cleanup.
  2,4: pat`steps _ (Halt (word.of_Z 0) _, _)` at exact pat.
  all: subst.
  all: spat `Halt` at inversion spat; subst.
  2: spat `word.eqb` at eapply Properties.word.eqb_false in spat; congruence.
  reflexivity.
Qed.

Theorem codegen_diverges: forall input prog output,
  prog_avoids_crash input prog ->
  asm_diverges input (codegen prog) output ->
  prog_diverges input prog output.
Proof.
  intros.
  unfold prog_avoids_crash, prog_diverges, asm_diverges, init_state_ok in *; cleanup; split; intros.
  1: { (* imp_timesout *)
    unfold imp_timesout; cleanup.
    destruct eval_from eqn:?.
    spat `_ <> Stop Crash` at specialize spat with (fuel := fuel) (res := o) (s := s) as Hnocrash; clear spat.
    pat `eval_from _ _ _ = _` at specialize (Hnocrash pat).
    eexists; f_equal.
    destruct prog.
    unfold eval_from in *.
    destruct find_fun eqn:?; unfold_outcome; cleanup.
    2: congruence.
    pat ` (let (l, _) := ?p in _) = _` at destruct p; destruct l.
    2: congruence.
    spat `eval_cmd` at eapply codegen_thm in spat; eauto; cleanup.
    simpl in *; rewrite Nat.sub_0_r in *.
    assert (exists t1, steps (State x, steps_done s) (State t1, 0)).
    1: { (* NRC ==> steps *)
      pat `let (_, _) := ?x in _` at destruct x; clear pat.
      pat `forall _, _` at specialize pat with (k := s.(steps_done)); cleanup.
      induction s.(steps_done); simpl in *; cleanup.
      - intros; eexists; subst.
        spat `steps` at eapply steps_determ in spat; cleanup; eauto.
        eapply steps_refl.
      - eexists.
        eapply steps_trans.
        1: eapply steps_step_succ.
        1: eauto.
        
        pat `NRC _ _ ?x _` at destruct x.
        2: {
          destruct n0; try congruence.
          simpl in *; cleanup.
          pat `step (Halt _ _) _` at inversion pat.
        }
        
        eauto.
      admit.
    }
    cleanup.
    all: spat `steps` at eapply steps_determ in spat; cleanup.
    2: pat`steps _ (s0, _)` at exact pat.
    subst; cleanup.
    eauto.
    (* (CCONTR_TAC \\ fs [prog_timesout_def]
    \\ last_x_assum (qspec_then ‘k’ assume_tac)
    \\ Cases_on ‘eval_from k t.input prog’ \\ fs []
    \\ reverse (Cases_on ‘q’)
    THEN1 (Cases_on ‘e’ \\ fs [] \\ rw [] \\ fs []) \\ fs []
    \\ rw [] \\ Cases_on ‘prog’ \\ fs [eval_from_def]
    \\ drule codegen_thm \\ fs []
    \\ fs [init_state_def]
    \\ goal_assum (first_assum o mp_then Any mp_tac) \\ fs []
    \\ CCONTR_TAC \\ fs []
    \\ Cases_on ‘outcome’ \\ fs []
    \\ Cases_on ‘q’ \\ fs []
    \\ drule steps_IMP_NRC_step \\ strip_tac
    \\ rename [‘NRC _ kk’]
    \\ first_x_assum (qspec_then ‘kk’ mp_tac) \\ strip_tac
    \\ imp_res_tac NRC_step_determ \\ fs []) *)
  }
  (* output_ok_imp *)
  admit.
Qed.
