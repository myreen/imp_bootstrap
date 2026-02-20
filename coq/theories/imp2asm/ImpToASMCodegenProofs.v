Require Import impboot.utils.Core.
Require Import impboot.utils.Llist.
Import Llist.
Require Import impboot.utils.Env.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.commons.CompilerUtils.
Require Import impboot.commons.ProofUtils.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.imperative.ImpSemantics.
Require Import impboot.imperative.ImpProperties.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMSemantics.
Require Import impboot.assembly.ASMProperties.

Require Import Stdlib.Program.Equality.

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
Fixpoint lookup_f (n: name) (fs: f_lookup) : option nat :=
  match fs with
  | [] => None
  | (fname, pos) :: fs =>
    if (fname =? n)%N then Some pos
    else lookup_f n fs
  end.

(* Ensures initial instructions are present and that each function in ds has its compiled form in instructions. *)
Definition code_rel (fs : f_lookup) (ds : list func) (instructions : list instr) : Prop :=
  init_code_in instructions /\
  forall n params body,
    find_fun n ds = Some (params, body) ->
    exists pos,
      lookup fs n = pos /\
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

Definition pmap_in_memory (pmap: nat -> option (word64 * nat)) (impm: list (list (option Value))): Prop :=
  forall p l base, pmap p = Some (base, l) -> exists v, List.nth_error impm p = Some v.

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
      nth_error curr (index_of vs n 0) = Some (Word w) /\
      v_inv pmap v w.

Fixpoint binders_ok (c: cmd) (vs: list (option name)) :=
  match c with
  | Skip => True
  | Seq c1 c2 => binders_ok c1 vs /\ binders_ok c2 vs
  | Assign n e => In (Some n) vs
  | Update a e e' => True
  | If t c1 c2 => binders_ok c1 vs /\ binders_ok c2 vs
  | While tst body => binders_ok body vs
  | ImpSyntax.Call n f es => In (Some n) vs
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
    pmap_in_memory pmap s1.(ImpSemantics.memory) /\
    has_stack t1 (Word w :: rest) /\
    fetch t1 = Some Ret
  | Cont _ => exists curr1, (* value in Cont is always unit for commands *)
    has_stack t1 (curr1 ++ rest) /\
    mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
    pmap_in_memory pmap s1.(ImpSemantics.memory) /\
    env_ok s1.(vars) vs curr1 pmap /\
    t1.(pc) = l1
  | Stop (ImpSemantics.Abort) => False
  | Stop (ImpSemantics.TimeOut) => True
  | Stop (ImpSemantics.Crash) => True
  end.

Definition exp_res_rel (ri: outcome Value) (l1: nat)
  (stck: list word_or_ret) (t1: ASMSemantics.state) (s1: ImpSemantics.state)
  (pmap: nat -> option (word64 * nat)) : Prop :=
  match ri with
  | Cont v => exists w,
    v_inv pmap v w /\
    mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
    pmap_in_memory pmap s1.(ImpSemantics.memory) /\
    has_stack t1 (Word w :: stck) /\
    t1.(pc) = l1
  | _ => False
  end.

Fixpoint list_rel {A} {B} (R: A -> B -> Prop) (al: list A) (bl: list B): Prop :=
  match al, bl with
  | nil, nil => True
  | a :: al, b :: bl => R a b /\ list_rel R al bl
  | _, _ => False
  end.

Definition exps_res_rel (ri: outcome (list Value)) (l1: nat)
  (stck: list word_or_ret) (t1: ASMSemantics.state) (s1: ImpSemantics.state)
  (pmap: nat -> option (word64 * nat)) : Prop :=
  match ri with
  | Cont vs => exists ws,
    list_rel (v_inv pmap) vs ws /\
    mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
    pmap_in_memory pmap s1.(ImpSemantics.memory) /\
    has_stack t1 (List.map Word (rev ws) ++ stck) /\
    t1.(pc) = l1
  | _ => False
  end.

Fixpoint addresses_of (base: word64) (length: nat): list word64 :=
  match length with
  | 0 => []
  | S n => base :: addresses_of (word.add base (word.of_Z 8)) (n)
  end.

Definition pmap_in_bounds (pmap: nat -> option (word64 * nat)) (mr14: option word64): Prop :=
  forall p base len wr14,
    pmap p = Some (base, len) ->
    mr14 = Some wr14 ->
      (forall n, n < len -> word.ltu (word.add base (word.of_Z (Z.of_nat (n * 8)))) wr14 = true) ∧
      word.ltu (word.of_Z 0) base = true.

Definition r14_mono (old_r14: option word64) (new_r14: option word64): Prop :=
  forall old_wr14 new_wr14,
  old_r14 = Some old_wr14 ->
  new_r14 = Some new_wr14 ->
    (word.ltu old_wr14 new_wr14 = true \/ word.eqb old_wr14 new_wr14 = true).

Definition has_address (addr: word64) (base: word64) (length: nat): Prop :=
  exists n,
    n < length ∧ (word.add base (word.of_Z (Z.of_nat (n * 8)))) = addr.

Definition pmap_ok (pmap: nat -> option (word64 * nat)): Prop :=
  forall p1 p2 base1 len1 base2 len2,
    pmap p1 = Some (base1, len1) -> pmap p2 = Some (base2, len2) ->
    forall n1 n2, n1 < len1 -> n2 < len2 ->
      (word.add base1 (word.of_Z (Z.of_nat (n1 * 8)))) = (word.add base2 (word.of_Z (Z.of_nat (n2 * 8)))) ->
      (* TODO: also say that the offsets are the same? *)
      (* has_address addr base1 len1 ∧
      has_address addr base2 len2 → *)
      (* (exists n, n < len1 ∧ (word.add base1 (word.of_Z (Z.of_nat (n * 8)))) = addr) ∧
      (exists n, n < len2 ∧ (word.add base2 (word.of_Z (Z.of_nat (n * 8)))) = addr) → *)
      (* List.existsb (word.eqb addr) (addresses_of base1 len1) = true /\
      List.existsb (word.eqb addr) (addresses_of base2 len2) = true -> *)
      p1 = p2 /\ n1 = n2.

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
    pmap_in_memory pmap s.(ImpSemantics.memory) ->
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
        r14_mono (t.(regs) R14) (t1.(regs) R14) /\
        exp_res_rel res l1 (curr ++ rest) t1 s1 pmap
      end.

Definition goal_exps (es: list exp): Prop :=
  forall (s s1 : ImpSemantics.state) (fuel fuel1: nat)
         (res : outcome (list Value)) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret)
         (pmap: nat -> option (word64 * nat)),
    eval_exps es s = (res, s1) ->
    res <> Stop Crash ->
    c_exps es t.(pc) vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr pmap ->
    has_stack t (curr ++ rest) ->
    mem_inv pmap t.(memory) s.(ImpSemantics.memory) ->
    pmap_in_memory pmap s.(ImpSemantics.memory) ->
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
        r14_mono (t.(regs) R14) (t1.(regs) R14) /\
        exps_res_rel res l1 (curr ++ rest) t1 s1 pmap
      end.

Definition goal_test (tst: test): Prop :=
  forall (s s1 : ImpSemantics.state) (fuel fuel1: nat)
         (b : bool) (t t1 : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 ltrue lfalse : nat)
         (curr rest : list word_or_ret)
         (pmap: nat -> option (word64 * nat)),
    eval_test tst s = (Cont b, s1) ->
    c_test tst ltrue lfalse t.(pc) vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr pmap ->
    has_stack t (curr ++ rest) ->
    mem_inv pmap t.(memory) s.(ImpSemantics.memory) ->
    (exists r14, pmap_in_bounds pmap (Some r14)) ->
    pmap_in_memory pmap s.(ImpSemantics.memory) ->
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
        r14_mono (t.(regs) R14) (t1.(regs) R14) /\
        mem_inv pmap t1.(memory) s1.(ImpSemantics.memory) /\
        pmap_in_memory pmap s1.(ImpSemantics.memory) /\
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
    pmap_in_memory pmap s.(ImpSemantics.memory) ->
    pmap_ok pmap ->
    pmap_in_bounds pmap (t.(regs) R14) ->
    odd (List.length rest) = true ->
    odd (List.length curr) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome pmap1,
      steps (State t, s1.(steps_done) - s.(steps_done)) outcome /\
      pmap_ok pmap1 /\
      pmap_subsume pmap pmap1 /\
      match outcome with
      | (Halt ec output, ck) =>
        prefix output s1.(ImpSemantics.output) = true /\
        (ec = (word.of_Z 1) \/ ec = (word.of_Z 4))
        (* TODO(kπ) do we need this? *)
        (* ∧ res <> Stop TimeOut *)
      | (State t1, ck) =>
        ck = 0 /\
        state_rel fs s1 t1 /\
        r14_mono (t.(regs) R14) (t1.(regs) R14) /\
        pmap_in_bounds pmap1 (t1.(regs) R14) /\
        cmd_res_rel res l1 rest vs t1 s1 pmap1
      end.

(* proofs *)

Ltac unfold_outcome :=
  unfold cont, crash, stop in *.

Ltac unfold_asm_state :=
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
  | [ H: False |- _ ] => inversion H
  end.

Theorem prefix_trans: forall s1 s2 s3,
  prefix s1 s2 = true ->
  prefix s2 s3 = true ->
  prefix s1 s3 = true.
Proof.
  intros s1 s2. revert s1.
  induction s2 as [|b s2' IH]; intros s1 s3 H1 H2.
  - destruct s1 as [|a s1'].
    + simpl. assumption.
    + simpl in H1. discriminate H1.
  - destruct s1 as [|a s1'].
    + destruct s3 as [|c s3']; simpl; reflexivity.
    + simpl in H1.
      destruct (ascii_dec a b) as [Heq|Hneq].
      * subst b.
        destruct s3 as [|c s3'].
        -- simpl in H2.
           destruct (ascii_dec a a) as [_|Hcontr]; [discriminate H2|contradiction].
        -- simpl in H2.
           destruct (ascii_dec a c) as [Heq2|Hneq2].
           ++ subst c.
              simpl.
              destruct (ascii_dec a a) as [_|Hcontr]; [|contradiction].
              eapply IH; eassumption.
           ++ discriminate H2.
      * discriminate H1.
Qed.

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

Opaque Nat.pow.

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
  Opaque nth_error.
  cleanup; simpl in *.
  destruct (odd (List.length (stack t))) eqn:?.
  1: {
    eapply steps_trans.
    - eapply steps_step_same.
      eapply step_push; eauto.
      unfold fetch; rewrite H1; eauto.
    - eapply steps_trans.
      + eapply steps_step_same.
        eapply step_const; eauto.
        unfold_asm_state.
        unfold fetch; rewrite H1; eauto.
      + eapply steps_step_same.
        eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 4)
        (inc (set_stack (Word w :: stack t) (inc t))))).
        1: unfold fetch; unfold_asm_state; simpl; rewrite H1; eauto.
        1: unfold_asm_state; simpl; eauto.
        rewrite rw_mod_2_even.
        simpl in *.
        destruct (List.length (stack t)); [tauto|].
        rewrite Nat.odd_succ in *.
        assumption.
  }
  eapply steps_trans.
  + eapply steps_step_same.
    eapply step_const; eauto.
    unfold_asm_state.
    unfold fetch; rewrite H1; eauto.
  + eapply steps_step_same.
    eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 4) (inc t))).
    1: unfold fetch; unfold_asm_state; simpl; rewrite H1; eauto.
    1: unfold_asm_state; simpl; eauto.
    rewrite rw_mod_2_even.
    simpl in *.
    rewrite <- Nat.negb_odd in *.
    rewrite Heqb.
    tauto.
Qed.

Theorem abortLoc: forall fs ds t w n,
  code_rel fs ds t.(instructions) ->
  t.(regs) R15 = Some w ->
  odd (List.length (stack t)) = true ->
  t.(pc) = abortLoc ->
  steps (State t, n) (Halt (word.of_Z 1) t.(output), n).
Proof.
  intros.
  unfold abortLoc in *.
  unfold code_rel in *.
  unfold init_code_in, init in *.
  unfold code_in in *.
  cleanup; simpl in *.
  eapply steps_trans.
  1: eapply steps_step_same.
  1: eapply step_push; eauto.
  1: unfold fetch; pat `t.(pc) = _` at rewrite pat; eauto.
  eapply steps_trans.
  1: eapply steps_step_same.
  1: eapply step_const; eauto.
  1: unfold_asm_state.
  1: unfold fetch; pat `t.(pc) = _` at rewrite pat; eauto.
  eapply steps_step_same.
  eapply step_exit with (s := (write_reg ARG_REG (word.of_Z 1)
  (inc (set_stack (Word w :: stack t) (inc t))))).
  1: unfold fetch; unfold_asm_state; simpl; pat `t.(pc) = _` at rewrite pat; eauto.
  1: unfold_asm_state; simpl; eauto.
  rewrite rw_mod_2_even.
  simpl in *.
  destruct (List.length (stack t)); [tauto|].
  rewrite Nat.odd_succ in *.
  assumption.
Qed.

Theorem even_len_spec_str: forall {A} (l: list A),
  (forall x, even_len (x :: l) = even (List.length (x :: l))) ∧
  even_len l = even (List.length l).
Proof.
  induction l.
  - split; reflexivity.
  - simpl even_len.
    destruct l; try reflexivity; split.
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
  | _ => progress rewrite list_app_spec
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
  | _ => progress rewrite list_app_spec
  | _ => lia
  end.
Qed.

Theorem c_test_length: forall tst lt lf l vs c l1,
  c_test tst lt lf l vs = (c, l1) -> l1 = l + List.length (flatten c).
Proof.
  induction tst.
  all: intros.
  all: simpl c_test in *.
  all: repeat match goal with
  | [ H : context[(if ?x then _ else _)] |- _ ] => destruct x eqn:?
  | [ H : context [(match ?x with | _ => _ end)] |- _ ] => destruct x eqn:?
  | [ H : (_, _) = (_, _) |- _ ] => inversion H; subst; clear H
  | [ |- context[ fst ?x ] ] => destruct x eqn:?; simpl in *
  | [ H : c_test _ _ _ _ _ = (_, _) |- _ ] => eapply IHtst2 in H; subst
  | [ H : c_test _ _ _ _ _ = (_, _) |- _ ] => eapply IHtst1 in H; subst
  | [ H : c_test _ _ _ _ _ = (_, _) |- _ ] => eapply IHtst in H; subst
  | [ H: c_exp _ _ _ = (_, _) |- _ ] =>
    eapply c_exp_length in H; subst
  | _ => progress unfold c_var, c_const, dlet in *
  | _ => progress simpl in *
  | _ => progress rewrite length_app
  | _ => progress rewrite list_app_spec
  | _ => lia
  end.
Qed.

Theorem appl_len_spec: forall {A} (l: app_list A),
  appl_len l = List.length (flatten l).
Proof.
  induction l; simpl; unfold dlet; [rewrite list_len_spec|]; eauto.
  rewrite IHl1; rewrite IHl2.
  rewrite list_app_spec.
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
  | [ H: c_test _ _ _ _ _ = (_, _) |- _ ] =>
    eapply c_test_length in H; subst
  | _ => progress unfold dlet, c_alloc, c_assign, c_var in *
  | _ => progress simpl in *
  | _ => progress rewrite length_app
  | _ => progress rewrite appl_len_spec
  | _ => progress rewrite list_app_spec
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
  all: simpl; reflexivity.
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
  index_of vs name k = k + index_of vs name 0.
Proof.
  induction vs; intros; eauto.
  simpl; unfold dlet; simpl; destruct a.
  - destruct (_ =? _)%N eqn:?; simpl; eauto.
    rewrite IHvs; eapply eq_sym; rewrite IHvs.
    rewrite Nat.add_assoc.
    reflexivity.
  - rewrite IHvs; eapply eq_sym; rewrite IHvs.
    rewrite Nat.add_assoc.
    reflexivity.
Qed.

Theorem index_of_spec_add: forall name vs k i,
  index_of vs name (k + i) = i + index_of vs name k.
Proof.
  intros.
  rewrite index_of_spec.
  symmetry.
  rewrite index_of_spec.
  lia.
Qed.

Theorem index_of_bounds: forall name vs k,
  index_of vs name k ≤ k + List.length vs.
Proof.
  induction vs; intros; simpl; unfold dlet; simpl.
  1: rewrite Nat.add_0_r; constructor.
  simpl; destruct a.
  - destruct (_ =? _)%N eqn:?; simpl; try rewrite IHvs; lia.
  - try rewrite IHvs; lia.
Qed.

Theorem index_of_In: forall name vs k,
  index_of vs name k < k + List.length vs <-> In (Some name) vs.
Proof.
  induction vs; intros; simpl.
  1: rewrite Nat.add_0_r.
  1: split; intros H; [lia|inversion H].
  simpl; unfold dlet; simpl; destruct a.
  - destruct (_ =? _)%N eqn:?; simpl; split; intros H.
    all: rewrite ?N.eqb_eq in *; subst; eauto.
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
    1: pat `Some _ = Some _` at inversion pat; rewrite N.eqb_neq in *|-; congruence.
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
  index_of vs1 name k < (List.length vs1) ->
    index_of vs1 name k = index_of (vs1 ++ vs2) name k.
Proof.
  intros.
  induction vs1; simpl in *; unfold dlet in *; simpl in *.
  - inversion H.
  - destruct a.
    + destruct (_ =? _)%N; try reflexivity.
      assert (index_of vs1 name k = index_of (vs1 ++ vs2) name k).
      2: {
        do 2 (rewrite index_of_spec; symmetry).
        pat `index_of vs1 name k = index_of (vs1 ++ vs2) name k` at do 2 (rewrite index_of_spec in pat; symmetry in pat).
        lia.
      }
      rewrite IHvs1; eauto.
      rewrite index_of_spec in *.
      lia.
    + assert (index_of vs1 name k = index_of (vs1 ++ vs2) name k).
      2: {
        do 2 (rewrite index_of_spec; symmetry).
        pat `index_of vs1 name k = index_of (vs1 ++ vs2) name k` at do 2 (rewrite index_of_spec in pat; symmetry in pat).
        lia.
      }
      rewrite IHvs1; eauto.
      rewrite index_of_spec in *.
      lia.
Qed.

Theorem index_of_lbound: forall name vs k,
  k ≤ index_of vs name k.
Proof.
  induction vs; intros; simpl.
  1: constructor.
  simpl; unfold dlet; simpl; destruct a.
  - destruct (_ =? _)%N eqn:?; simpl; [constructor|].
    specialize (IHvs (k + 1)).
    lia.
  - specialize (IHvs (k + 1)).
    lia.
Qed.

Theorem index_of_bound_inj: forall vs nm1 nm2 k i,
  index_of vs nm1 k = i -> index_of vs nm2 k = i ->
  k + i < (List.length vs) ->
    nm1 = nm2.
Proof.
  induction vs; intros; cleanup.
  - simpl in *; cleanup.
    pat `_ < 0` at inversion pat.
  - simpl in *; unfold dlet in *; simpl in *.
    destruct a.
    2: {
      assert (S (index_of vs nm1 k) = i) by (rewrite index_of_spec in *; lia).
      assert (S (index_of vs nm2 k) = i) by (rewrite index_of_spec in *; lia).
      destruct i; [rewrite index_of_spec in *; lia|].
      ring_simplify in H1.
      specialize (IHvs nm1 nm2 k i).
      pat `S _ = S _` at eapply eq_add_S in pat.
      pat `S _ = S _` at eapply eq_add_S in pat.
      eapply IHvs; eauto.
      lia.
    }
    destruct (n =? nm1)%N eqn:?; destruct (n =? nm2)%N eqn:?.
    all: rewrite ?N.eqb_eq in *; try congruence; cleanup.
    all: try (spat `index_of` at rewrite index_of_spec in spat; lia).
    assert (S (index_of vs nm1 k) = i) by (rewrite index_of_spec in *; lia).
    assert (S (index_of vs nm2 k) = i) by (rewrite index_of_spec in *; lia).
    destruct i; [rewrite index_of_spec in *; lia|].
    ring_simplify in H1.
    specialize (IHvs nm1 nm2 k i).
    pat `S _ = S _` at eapply eq_add_S in pat.
    pat `S _ = S _` at eapply eq_add_S in pat.
    eapply IHvs; eauto.
    lia.
Qed.

Ltac crunch_give_up_even :=
  repeat match  goal with
  | |- (ImpToASMCodegen.give_up _) = (ImpToASMCodegen.give_up _) => f_equal
  | |- context[even_len _] => rewrite even_len_spec
  (* TODO *)
  (* | |- context[even_len _] => rewrite even_len_exp_spec *)
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
  all: simpl; unfold dlet in *; simpl in *.
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

Ltac eval_exps_contr_stop_tac :=
  lazymatch goal with
  | [ H: eval_exps _ _ = (Stop ?v, _) |- _ ] =>
    exfalso; destruct v eqn:?; eapply eval_exps_not_stop in H; eauto; try congruence
  end.

Opaque mem_inv.

Lemma r14_mono_refl: forall r14,
  r14_mono r14 r14.
Proof.
  unfold r14_mono; intros; subst; cleanup.
  rewrite word.unsigned_eqb.
  right; rewrite Z.eqb_eq.
  reflexivity.
Qed.

Lemma r14_mono_trans: forall r14a r14b r14c v,
  r14_mono r14a r14b ->
  r14_mono r14b r14c ->
  r14b = Some v ->
  r14_mono r14a r14c.
Proof.
  unfold r14_mono; intros; subst.
  spat `Some old_wr14 = _` at specialize spat with (old_wr14 := old_wr14) (new_wr14 := v) (1 := eq_refl) (2 := eq_refl) as ?.
  spat `Some v = _` at specialize spat with (old_wr14 := v) (new_wr14 := new_wr14) (1 := eq_refl) (2 := eq_refl) as ?.
  rewrite word.unsigned_ltu, word.unsigned_eqb in *.
  lia.
Qed.

Lemma r14_mono_IMP_pmap_in_bounds: forall pmap mr14old r14old r14new,
  pmap_in_bounds pmap mr14old ->
  r14_mono mr14old r14new ->
  mr14old = Some r14old ->
  pmap_in_bounds pmap r14new.
Proof.
  intros * Hbounds Hr14_mono ?.
  unfold pmap_in_bounds in *; intros; subst.
  pat `pmap p = _` at rename pat into Hpmap.
  specialize Hbounds with (wr14 := r14old) (1 := Hpmap) (2 := eq_refl); cleanup.
  split; eauto.
  intros.
  unfold r14_mono in Hr14_mono; specialize Hr14_mono with (old_wr14 := r14old) (new_wr14 := wr14) (1 := eq_refl) (2 := eq_refl).
  pat `n < _` at rename pat into Hlt.
  pat `forall n, _` at specialize pat with (n := n) (1 := Hlt).
  rewrite word.unsigned_ltu, Z.ltb_lt, word.unsigned_eqb, Z.eqb_eq in *.
  lia.
Qed.

Ltac crunch_side_conditions :=
  simpl;
  unfold state_rel in *; cleanup;
  repeat match goal with
  | |- _ /\ _ => split
  | _ => progress eauto
  | |- context[ pc _ ] => lia
  | |- exists _, _ => eexists
  | |- ?f _ = ?f _ => f_equal
  | |- (?x + ?y = ?y + ?x)%Z => rewrite Z.add_comm; reflexivity
  | |- has_stack _ _ => solve [unfold has_stack; do 2 eexists; repeat (split; eauto)]
  | |- r14_mono ?x ?x => eapply r14_mono_refl
  | |- r14_mono _ _ => solve [eapply r14_mono_trans; eauto]
  | |- _ => lia
  | |- pmap_subsume ?x ?x => eapply pmap_subsume_refl
  | H: r14_mono ?a ?b, H1: pmap_in_bounds ?pm ?a |- pmap_in_bounds ?pm ?b =>
    eapply r14_mono_IMP_pmap_in_bounds with (1 := H1) (2 := H); eauto
  | |- pmap_ok _ => progress eauto
  | |- pmap_subsume _ _ => eapply pmap_subsume_trans; progress eauto
  | |- state_rel _ _ _ => progress eauto
  | |- cmd_res_rel _ _ _ _ _ _ _ _ => progress eauto
  | H: r14_mono ?a ?b |- r14_mono ?a ?c =>
    unfold state_rel in *; cleanup; eapply r14_mono_trans; eauto
  | H: regs ?t1 R14 = regs ?t R14 |- context[regs ?t1 R14] =>
    rewrite H
  | H: memory ?t1 = memory ?t |- context[memory ?t1] =>
    rewrite H
  | _ => progress simpl
  | _ => assumption
  | _ => lia
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
  simpl c_exp in *; unfold c_const, dlet in *.
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
  simpl in *; unfold_outcome; cleanup.
  crunch_side_conditions.
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
  destruct (index_of vs n 0 =? 0) eqn:?.
  1: {
    eexists.
    cleanup.
    simpl flatten in *.
    split.
    - eapply steps_step_same.
      simpl code_in in *; cleanup.
      eapply step_push in e; eauto.
    - simpl; cleanup.
      destruct (IEnv.lookup (vars s) n) eqn:?; unfold_outcome; cleanup; [|congruence].
      crunch_side_conditions.
      Transparent nth_error.
      spat `IEnv.lookup (vars s1) _ = Some _` at eapply spat in Heqo; cleanup.
      rewrite Nat.eqb_eq in *; rewrite Heqb in *.
      destruct curr; simpl in *; cleanup.
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
    all: unfold_asm_state; eauto.
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
    destruct rest; [pat `odd (List.length []) = true` at inversion pat|].
    rewrite length_cons in *.
    lia.
  - simpl.
    crunch_side_conditions.
Qed.

Theorem c_exp_Add : forall (e1 e2: exp),
  goal_exp e1 -> goal_exp e2 ->
  goal_exp (ImpSyntax.Add e1 e2).
Proof.
  intros.
  unfold goal_exp; intros.
  simpl eval_exp in *.
  simpl c_exp in *; unfold c_add, c_sub, c_div, c_load, dlet in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *; unfold bind at 1 in H1; rewrite Heqp in *; subst.
  unfold dlet in *; simpl in *.
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
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H in Heqp; clear H; eauto.
  all: repeat rewrite list_app_spec in *.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  unfold exp_res_rel in *; cleanup; subst.
  unfold goal_exp in H0.
  pat `steps _ _` at rw ltac:(specialize (steps_instructions _ _ _ _ pat)).
  eapply H0 in Heqp0; clear H0; eauto; cleanup.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  all: unfold exp_res_rel in *; cleanup.
  all: try rewrite <- H20 in *.
  all: unfold state_rel in *; cleanup.
  1: pat `has_stack s0 _` at instantiate (1 := (Word w :: curr)) in pat.
  all: simpl in *; cleanup; subst.
  1: {
    specialize (has_stack_even t (curr ++ rest) H6) as ?.
    pat `has_stack s _` at specialize (has_stack_even _ _ pat) as ?.
    pat `has_stack s0 _` at specialize (has_stack_even _ _ pat) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    pat `steps (State s, _) _` at rw ltac:(specialize (steps_instructions _ _ _ _ pat)).
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
      all: pat `pc s0 = _` at rewrite <- pat in *; unfold fetch; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_add; eauto.
      1: unfold_asm_state; eauto.
      eapply steps_refl.
    }
    crunch_side_conditions.
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
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H with (fuel := fuel) in Heqp; clear H; eauto.
  all: repeat rewrite list_app_spec in *.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  unfold exp_res_rel in *; cleanup; subst.
  unfold goal_exp in H0.
  pat `steps _ _` at specialize steps_instructions with (1 := pat) as Htmp; rewrite Htmp in *; clear Htmp.
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  all: unfold exp_res_rel in *; cleanup.
  1: pat `pc s0 = _` at rewrite <- pat in *.
  all: unfold state_rel in *; cleanup.
  1: pat `has_stack _ _` at instantiate (1 := (Word w :: curr)) in pat.
  all: simpl in *; cleanup; subst.
  1: {
    pat `has_stack _ (_ ++ _)` at specialize has_stack_even with (1 := pat) as ?.
    pat `has_stack _ (_ :: _)` at specialize has_stack_even with (1 := pat) as ?.
    pat `has_stack _ (_ :: _ :: _)` at specialize has_stack_even with (1 := pat) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
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
      1: eapply step_sub; eauto.
      1: simpl; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      1: simpl; eauto.
      eapply steps_refl.
    }
    crunch_side_conditions.
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
  Opaque word.eqb.
  Opaque word.of_Z.
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
  rewrite word.unsigned_eqb in *; rewrite word.unsigned_of_Z in *; simpl word.unsigned in *; unfold word.wrap in *; rewrite Z.mod_0_l in *; [|lia].
  rewrite Heqb in *.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H with (fuel := fuel) in Heqp; clear H; eauto.
  all: repeat rewrite list_app_spec in *.
  all: simpl flatten in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  unfold exp_res_rel in *; cleanup; subst.
  pat `steps _ _` at specialize steps_instructions with (1 := pat) as Htmp; rewrite Htmp in *; clear Htmp.
  unfold goal_exp in H0.
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  all: unfold exp_res_rel in *; cleanup.
  1: pat `pc s0 = _` at rewrite <- pat in *.
  all: unfold state_rel in *; cleanup.
  1: pat `has_stack _ _` at instantiate (1 := (Word w :: curr)) in pat.
  all: simpl in *; cleanup; subst.
  1: {
    pat `has_stack _ (_ ++ _)` at specialize has_stack_even with (1 := pat) as ?.
    pat `has_stack _ (_ :: _)` at specialize has_stack_even with (1 := pat) as ?.
    pat `has_stack _ (_ :: _ :: _)` at specialize has_stack_even with (1 := pat) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
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
      Transparent word.of_Z.
      1: simpl; rewrite Z.mod_0_l; try reflexivity; lia.
      eapply steps_refl.
    }
    crunch_side_conditions.
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
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  unfold goal_exp in H; eapply H with (fuel := fuel) in Heqp; clear H; eauto.
  all: repeat rewrite list_app_spec in *.
  all: repeat rewrite code_in_append in *; cleanup.
  all: try congruence.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  unfold exp_res_rel in *; cleanup; subst.
  pat `steps _ _` at specialize steps_instructions with (1 := pat) as Htmp; rewrite Htmp in *; clear Htmp.
  unfold goal_exp in H0.
  eapply H0 in Heqp0; clear H0; eauto; inversion H3; clear H3; subst; cleanup; eauto.
  2: congruence.
  1: destruct x0; destruct s0; cleanup; subst.
  all: unfold exp_res_rel in *; cleanup.
  1: pat `pc s0 = _` at rewrite <- pat in *.
  all: unfold state_rel in *; cleanup.
  1: pat `has_stack _ _` at instantiate (1 := (Word x :: curr)) in pat.
  all: simpl in *; cleanup; subst.
  1: {
    pat `has_stack _ (_ ++ _)` at specialize has_stack_even with (1 := pat) as ?.
    pat `has_stack _ (_ :: _)` at specialize has_stack_even with (1 := pat) as ?.
    pat `has_stack _ (_ :: _ :: _)` at specialize has_stack_even with (1 := pat) as ?.
    unfold has_stack in *; cleanup.
    unfold env_ok in *; cleanup.
    rw ltac:(specialize (steps_instructions _ _ _ _ H3)).
    pat `mem_inv _ _ _` at eapply pat in Heqo; cleanup.
    pat `forall (_: nat) (_: option Value), _` at eapply pat in Heqo0; clear pat; cleanup.
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
      eapply steps_step_same.
      eapply step_load; eauto.
      all: simpl; eauto.
      simpl in *.
      unfold_asm_state; unfold read_mem; simpl.
      assert (
        (word.add (word.add x9 x0) (word.of_Z (word.unsigned (word.of_Z 0)))) =
        (word.add x (word.of_Z (Z.of_nat (w2n x0 / 8 * 8))))
      ) as ->.
      2: pat`memory s0 _ = _` at rewrite pat; eauto.
      pat `pmap i = _` at rewrite pat in *; cleanup.
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
    crunch_side_conditions.
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

Lemma has_stack_set_pc: forall s x st,
  has_stack s st ->
  has_stack (set_pc x s) st.
Proof.
  unfold has_stack; intros; cleanup; eauto.
Qed.

Theorem c_exps_correct: forall es,
  goal_exps es.
Proof.
  induction es; intros; unfold goal_exps; intros; simpl in *; unfold dlet in *; simpl in *; unfold_outcome; cleanup.
  1: { (* nil *)
    eexists; split.
    1: eapply steps_refl.
    simpl.
    crunch_side_conditions.
    1: instantiate(1 := []).
    all: simpl; eauto.
  }
  unfold_monadic.
  unfold dlet in *; cleanup.
  destruct c_exp eqn:?.
  destruct c_exps eqn:?.
  simpl in *; unfold dlet in *; simpl in *.
  destruct eval_exp eqn:?.
  destruct eval_exps eqn:?.
  pat `match ?o with _ => _ end = _` at destruct o; cleanup.
  2: eval_exp_contr_stop_tac.
  pat `match ?o with _ => _ end = _` at destruct o; cleanup.
  2: eval_exps_contr_stop_tac.
  rewrite list_app_spec in *; rewrite code_in_append in *.
  spat `eval_exp` at specialize eval_exp_pure with (1 := spat) as Htmp; rewrite Htmp in *; clear Htmp.
  spat `c_exp` at specialize c_exp_length with (1 := spat) as Htmp; rewrite Htmp in *; clear Htmp.
  spat `eval_exp` at specialize c_exp_correct as Htmp; unfold goal_exp in Htmp; eapply Htmp with (fuel := fuel) in spat; clear Htmp; cleanup; eauto; try congruence.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  unfold exp_res_rel in *; cleanup.
  spat `eval_exps` at rename spat into Heval.
  (* assert ((pc t + List.length (flatten a0)) = pc (set_pc (pc t + List.length (flatten a0)) s2)) as Htmp by reflexivity; spat `c_exps` at rewrite Htmp in spat; clear Htmp. *)
  pat `goal_exps _` at unfold goal_exps in pat; eapply pat with (fuel := fuel) (curr := (Word x :: curr)) in Heval; cleanup; clear pat; eauto; try congruence; simpl.
  2: pat `pc s2 = _` at rewrite <- pat in *; eauto.
  2: eapply env_ok_add_None; eauto; eapply pmap_subsume_refl.
  2: pat `pc s2 = _` at rewrite <- pat in *.
  2: spat `steps` at specialize steps_instructions with (1 := spat) as Htmp; rewrite Htmp in *; clear Htmp; eauto.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  unfold exps_res_rel in *; cleanup.
  simpl in *.
  eexists; split.
  1: {
    eapply steps_trans.
    1: eauto.
    eauto.
  }
  simpl.
  crunch_side_conditions.
  1: instantiate (1 := (x :: x0)); simpl; eauto.
  rewrite map_rev in *; simpl.
  rewrite <- app_assoc, <- app_comm_cons, app_nil_l; eauto.
  Unshelve.
  all: exact ImpSemantics.Abort.
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
  spat `exists _, pmap_in_bounds _ _` at destruct spat as (r14, ?).
  simpl eval_test in *.
  simpl c_exp in *; unfold c_test in *; unfold dlet in *.
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
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  repeat rewrite list_app_spec in *.
  repeat rewrite code_in_append in *; cleanup.
  eval_exp_correct_tac.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  unfold exp_res_rel in *; cleanup; subst.
  steps_inst_tac.
  eval_exp_correct_tac.
  1: destruct x0; destruct s0; cleanup; subst.
  all: unfold exp_res_rel in *; cleanup.
  1: pat `pc s0 = _` at rewrite <- pat in *.
  all: unfold state_rel in *; cleanup.
  2: eapply env_ok_add_None; eauto; eapply pmap_subsume_refl.
  2: eauto.
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
      pat `steps _ (State s0, _)` at rw ltac:(specialize steps_instructions with (1 := pat)); eauto.
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
    crunch_side_conditions.
  }
  eexists.
  split.
  1: {
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eauto.
    pat `steps _ (State s0, _)` at rw ltac:(specialize steps_instructions with (1 := pat)); eauto.
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
  crunch_side_conditions.
Qed.

Theorem c_test_Test_Equal: forall (cm : cmp) (e1 e2 : exp),
  cm = ImpSyntax.Equal ->
  goal_test (Test cm e1 e2).
Proof.
  Opaque word.eqb.
  intros.
  unfold goal_test; intros.
  spat `exists _, pmap_in_bounds _ _` at destruct spat as (r14, ?).
  simpl eval_test in *.
  simpl c_exp in *; unfold c_test in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_exp e1 s) eqn:?; simpl in *.
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  destruct (eval_exp e2 s0) eqn:?; simpl in *.
  destruct o eqn:?; subst.
  2: eval_exp_contr_stop_tac.
  unfold eval_cmp in *.
  destruct v0 eqn:?; unfold_outcome; cleanup; subst.
  2: destruct v eqn:?; unfold_outcome; cleanup; subst; congruence.
  destruct (c_exp e1 (pc t) vs) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  destruct (c_exp e2 n (None :: vs)) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  specialize (eval_exp_pure e1 _ _ _ Heqp).
  specialize (eval_exp_pure e2 _ _ _ Heqp0).
  intros; subst.
  repeat rewrite list_app_spec in *.
  repeat rewrite code_in_append in *; cleanup.
  eval_exp_correct_tac.
  rwr ltac:(specialize (c_exp_length e1 _ _ _ _ Heqp1)).
  specialize (c_exp_length e2 _ _ _ _ Heqp2) as ?; subst.
  destruct x; destruct s; cleanup; subst.
  unfold exp_res_rel in *; cleanup; subst.
  try steps_inst_tac.
  eval_exp_correct_tac.
  2: instantiate (1 := (Word x :: curr)).
  3: eauto.
  2: eapply env_ok_add_None; eauto; eapply pmap_subsume_refl.
  destruct x0; destruct s0; cleanup; subst.
  unfold exp_res_rel in *; cleanup.
  pat `pc s0 = _` at rewrite <- pat in *.
  unfold state_rel in *; cleanup.
  repeat has_stack_even_tac; cleanup.
  unfold env_ok in *; cleanup.
  steps_inst_tac.
  simpl in *.
  cleanup; subst.
  destruct v eqn:?; unfold_outcome; cleanup; subst; rewrite word.unsigned_eqb in *.
  1: { (* Word *)
    destruct (word.unsigned w0 =? word.unsigned w)%Z eqn:?; rewrite ?Z.eqb_eq in *.
    1: {
      eexists; split.
      1: {
        eapply steps_trans.
        1: eauto.
        eapply steps_trans.
        1: eauto.
        pat `steps _ (State s0, _)` at rw ltac:(specialize steps_instructions with (1 := pat)); eauto.
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
      simpl in *; subst.
      rewrite word.unsigned_eqb in *.
      rewrite <- Heqb; rewrite Z.eqb_refl.
      crunch_side_conditions.
    }
    simpl in *; subst.
    eexists; split.
    1: {
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eauto.
      pat `steps _ (State s0, _)` at rw ltac:(specialize steps_instructions with (1 := pat)); eauto.
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
      1: rewrite word.unsigned_eqb in *.
      1: simpl; rewrite Heqb; eauto.
      1: econstructor; simpl; eauto.
      eapply steps_refl.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    rewrite word.unsigned_eqb in *.
    rewrite Heqb.
    crunch_side_conditions.
  }
  (* Pointer *)
  destruct (word.unsigned w =? word.unsigned (word.of_Z 0))%Z eqn:?; rewrite ?Z.eqb_eq in *; cleanup.
  simpl in *; cleanup.
  eexists; split.
  1: {
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eauto.
    pat `steps _ (State s0, _)` at rw ltac:(specialize steps_instructions with (1 := pat)); eauto.
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
    rewrite word.unsigned_eqb in *.
    pat `word.unsigned w = _` at rewrite pat.
    pat `pmap _ = _` at rename pat into Hpmap.
    spat `pmap_in_bounds` at unfold pmap_in_bounds in spat; eapply spat in Hpmap; cleanup; [|unfold state_rel in *; cleanup; eauto].
    rewrite word.unsigned_ltu, Z.ltb_lt in *.
    assert ((word.unsigned x9 =? word.unsigned (word.of_Z 0: word64))%Z = false) as -> by lia.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump; eauto.
    1: econstructor; simpl; eauto.
    eapply steps_refl.
  }
  crunch_side_conditions.
Qed.

Theorem c_test_Test: forall (cm : cmp) (e1 e2 : exp),
  goal_test (Test cm e1 e2).
Proof.
  destruct cm; intros.
  - eapply c_test_Test_Less; reflexivity.
  - eapply c_test_Test_Equal; reflexivity.
Qed.

Lemma pmap_in_bounds_set_pc: forall s pmap r14 n,
  pmap_in_bounds pmap (regs s r14) ->
  pmap_in_bounds pmap (regs (set_pc n s) r14).
Proof.
  unfold pmap_in_bounds; intros; cleanup; eauto.
Qed.

Theorem c_test_And: ∀ (tst1 tst2 : test),
  goal_test tst1 -> goal_test tst2 ->
  goal_test (ImpSyntax.And tst1 tst2).
Proof.
  intros.
  unfold goal_test; intros.
  spat `exists _, pmap_in_bounds _ _` at destruct spat as (r14, ?).
  simpl eval_test in *.
  simpl c_test in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_test tst1 s) eqn:?; simpl in *.
  destruct o eqn:?; subst; cleanup.
  destruct (eval_test tst2 s0) eqn:?; simpl in *.
  destruct o eqn:?; subst; cleanup.
  unfold_outcome; cleanup.
  destruct (c_test tst1) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  destruct (c_test tst2) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  specialize (eval_test_pure tst1 _ _ _ Heqp).
  specialize (eval_test_pure tst2 _ _ _ Heqp0).
  intros; subst.
  repeat rewrite list_app_spec in *.
  repeat rewrite code_in_append in *; cleanup.
  assert (pc t + 1 + 1 = pc t + 2) as Htmp; [lia|]; rewrite Htmp in *; clear Htmp.
  rwr ltac:(specialize (c_test_length tst1 _ _ _ _ _ _ Heqp1)).
  assert (pc t + 2 = pc (set_pc (if true then pc t + 2 else pc t + 1) t)) as Htmp by (simpl; reflexivity).
  rewrite Htmp in *; clear Htmp.
  eval_test_goal_tac.
  destruct x; destruct s; cleanup; subst.
  assert (n = pc (set_pc n s)) as Htmp by (simpl; reflexivity); rewrite Htmp in *; clear Htmp.
  unfold goal_test in H0; eapply H0 with (fuel := fuel) in Heqp0; clear H0; cleanup.
  all: eauto.
  1: destruct x; destruct s0; cleanup; subst.
  2: simpl in *; unfold state_rel in *; cleanup; rwr ltac:(specialize (steps_instructions _ _ _ _ H)); eauto.
  unfold state_rel in *; cleanup.
  destruct v eqn:?; subst.
  1: {
    destruct v0 eqn:?; subst.
    - eexists; split. (* true && true *)
      1: pat `pc s = _` at rewrite <- pat in *.
      (* all: pat `steps _ (State s0, _)` at specialize steps_instructions with (1 := pat) as Htmp; rewrite Htmp in H9; clear Htmp
      all: specialize (steps_instructions _ _ _ _ H) as Htmp; simpl in Htmp; rewrite Htmp in H9; clear Htmp. *)
      1: {
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: simpl; eauto.
        1: constructor.
        eapply steps_trans.
        1: eauto.
        pat `steps _ (State s, _)` at specialize steps_instructions with (1 := pat) as Htmp; simpl in Htmp; rewrite Htmp in *; clear Htmp.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: simpl; eauto.
        1: constructor.
        simpl; eauto.
      }
      simpl.
      unfold code_rel in *; cleanup; eauto.
      crunch_side_conditions.
    - eexists; split. (* true && false *)
      1: pat `pc s = _` at rewrite <- pat in *.
      1: {
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: simpl; eauto.
        1: constructor.
        eapply steps_trans.
        1: eauto.
        pat `steps _ (State s, _)` at specialize steps_instructions with (1 := pat) as Htmp; simpl in Htmp; rewrite Htmp in *; clear Htmp.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump.
        1: simpl; eauto.
        1: constructor.
        simpl; eauto.
      }
      simpl.
      unfold code_rel in *; cleanup; eauto.
      crunch_side_conditions.
  }
  eexists; split. (* false && _ *)
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump.
    1: simpl; eauto.
    1: constructor.
    eauto.
  }
  simpl.
  unfold code_rel in *; cleanup; eauto.
  crunch_side_conditions.
Qed.

Theorem c_test_Or: ∀ (tst1 tst2 : test),
  goal_test tst1 -> goal_test tst2 ->
  goal_test (ImpSyntax.Or tst1 tst2).
Proof.
  intros.
  unfold goal_test; intros.
  spat `exists _, pmap_in_bounds _ _` at destruct spat as (r14, ?).
  simpl eval_test in *.
  simpl c_test in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_test tst1 s) eqn:?; simpl in *.
  destruct o eqn:?; subst; cleanup.
  destruct (eval_test tst2 s0) eqn:?; simpl in *.
  destruct o eqn:?; subst; cleanup.
  unfold_outcome; cleanup.
  destruct (c_test tst1) eqn:?; simpl in *.
  destruct (c_test tst2) eqn:?; simpl in *; unfold dlet in *; simpl in *.
  specialize (eval_test_pure tst1 _ _ _ Heqp).
  specialize (eval_test_pure tst2 _ _ _ Heqp0).
  intros; subst.
  repeat rewrite list_app_spec in *.
  repeat rewrite code_in_append in *; cleanup.
  assert (pc t + 1 + 1 = pc t + 2) as Htmp; [lia|]; rewrite Htmp in *; clear Htmp.
  rwr ltac:(specialize (c_test_length tst1 _ _ _ _ _ _ Heqp1)).
  assert (pc t + 2 = pc (set_pc (if true then pc t + 2 else pc t + 1) t)) as Htmp by (simpl; reflexivity).
  rewrite Htmp in *; clear Htmp.
  eval_test_goal_tac.
  destruct x; destruct s; cleanup; subst.
  assert (n = pc (set_pc n s)) as Htmp by (simpl; reflexivity); rewrite Htmp in *; clear Htmp.
  unfold goal_test in H0; eapply H0 in Heqp0; clear H0; cleanup.
  all: eauto.
  1: destruct x; destruct s0; cleanup; subst.
  2: simpl in *; unfold state_rel in *; cleanup; rwr ltac:(specialize (steps_instructions _ _ _ _ H)); eauto.
  unfold state_rel in *; cleanup.
  destruct v eqn:?; subst.
  1: { (* true || _ *)
    eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      eauto.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    crunch_side_conditions.
  }
  destruct v0 eqn:?; subst.
  - eexists; split. (* false || true *)
    1: pat `pc s = _` at rewrite <- pat in *.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      eapply steps_trans.
      1: eauto.
      pat `steps _ (State s, _)` at specialize steps_instructions with (1 := pat) as Htmp; simpl in Htmp; rewrite Htmp in *; clear Htmp.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      simpl; eauto.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    crunch_side_conditions.
  - eexists; split. (* false || false *)
    1: pat `pc s = _` at rewrite <- pat in *.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      eapply steps_trans.
      1: eauto.
      pat `steps _ (State s, _)` at specialize steps_instructions with (1 := pat) as Htmp; simpl in Htmp; rewrite Htmp in *; clear Htmp.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump.
      1: simpl; eauto.
      1: constructor.
      simpl; eauto.
    }
    simpl.
    unfold code_rel in *; cleanup; eauto.
    crunch_side_conditions.
Qed.

Theorem c_test_Not: ∀ (tst : test),
  goal_test tst ->
  goal_test (ImpSyntax.Not tst).
Proof.
  intros.
  unfold goal_test; intros.
  spat `exists _, pmap_in_bounds _ _` at destruct spat as (r14, ?).
  simpl eval_test in *.
  simpl c_test in *; unfold dlet in *.
  unfold bind in *.
  destruct (eval_test tst s) eqn:?; simpl in *.
  destruct o eqn:?; subst; cleanup.
  unfold_outcome; cleanup.
  destruct (c_test tst) eqn:?; simpl in *.
  specialize (eval_test_pure tst _ _ _ Heqp).
  intros; subst.
  repeat rewrite code_in_append in *; cleanup.
  eval_test_goal_tac.
  destruct x eqn:?; destruct s eqn:?; cleanup.
  destruct v eqn:?; subst.
  1: {
    eexists; split.
    1: eauto.
    crunch_side_conditions.
  }
  eexists; split.
  1: eauto.
  crunch_side_conditions.
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
  simpl c_cmd in *; unfold dlet in *; simpl in *; cleanup.
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
    eapply abortLoc; eauto.
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

Theorem c_cmd_Return: forall (e: exp) (fuel: nat),
  goal_cmd (ImpSyntax.Return e) fuel.
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
  simpl flatten in *; unfold dlet in *; simpl in *; cleanup.
  repeat rewrite list_len_spec in *.
  pat `eval_exp e _ = _` at specialize eval_exp_pure with (1 := pat) as ?; cleanup; subst.
  simpl flatten in *; repeat rewrite list_app_spec in *; repeat rewrite code_in_append in *; cleanup.
  simpl code_in in *; cleanup.
  pat `c_exp e _ _ = _` at specialize c_exp_length with (1 := pat) as Htmp; rewrite <- Htmp in *; clear Htmp.
  pat `eval_exp e _ = (?r, _)` at
    assert (r <> Stop Crash) as ? by congruence; specialize c_exp_correct as Htmp1; unfold goal_exp in Htmp1; eapply Htmp1 with (fuel := 0) in pat; unfold exp_res_rel in pat; eauto; clear Htmp1; cleanup.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  steps_inst_tac.
  repeat rewrite Nat.sub_diag in *.
  unfold env_ok in *; cleanup.
  unfold has_stack in *; cleanup.
  eexists; eexists; split.
  1: {
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_add_rsp.
    2: pat `_ = stack s` at rewrite <- pat; reflexivity.
    1: pat `_ = List.length curr` at rewrite <- pat; eauto.
    eapply steps_refl.
  }
  unfold state_rel in *; cleanup; eauto.
  crunch_side_conditions.
Qed.

Lemma v_inv_pmap_subsume: forall v w pmap pmap1,
  pmap_subsume pmap pmap1 ->
  v_inv pmap v w ->
  v_inv pmap1 v w.
Proof.
  intros.
  unfold v_inv in *.
  destruct v; eauto.
  unfold pmap_subsume in *; cleanup.
  eexists; eauto.
Qed.

Lemma env_ok_replace_head: forall vars vs curr xnew xold n v pmap pmap1,
  env_ok vars vs (xold :: curr) pmap →
  (match xnew with
  |Word xnew => v_inv pmap1 v xnew
  | _ => False
  end) →
  pmap_subsume pmap pmap1 →
  index_of vs n 0 = 0 →
  0 < List.length vs →
  index_of vs n 0 < (List.length vs) ->
  env_ok (IEnv.insert (n, Some v) vars) vs (xnew :: curr) pmap1.
Proof.
  intros.
  destruct xnew; cleanup.
  unfold env_ok in *; cleanup.
  simpl in *.
  split; [assumption|].
  intros.
  destruct (n =? n0)%N eqn:?.
  - spat `IEnv.lookup` at rewrite N.eqb_eq in *; rewrite Heqb in spat.
    rewrite IEnv.lookup_insert_eq in *; cleanup.
    rewrite <- index_of_In with (k := 0); rewrite Nat.add_0_l.
    spat `_ = S _` at rewrite spat.
    split; try eexists; try split; simpl; cleanup; eauto.
    all: pat `index_of _ _ _ = 0` at rewrite pat; eauto.
    lia.
  - rewrite N.eqb_neq in *.
    rewrite IEnv.lookup_insert_neq in *; try assumption.
    spat `IEnv.lookup` at pose proof spat as Hlookup.
    pat `∀ _, _` as Hthm at eapply Hthm in Hlookup; cleanup.
    split; try eexists; try split; simpl; cleanup; eauto.
    2: eapply v_inv_pmap_subsume; eauto.
    destruct (index_of vs n0 0) eqn:?.
    + spat `index_of _ n _ = _` at pose proof spat as Hidx_of_n.
      spat `index_of _ n0 _ = _` at pose proof spat as Hidx_of_n0.
      pat `0 < List.length vs` at pose proof pat as H0ltvs.
      specialize (index_of_bound_inj _ _ _ _ _ Hidx_of_n Hidx_of_n0 H0ltvs) as ?; subst.
      congruence.
    + simpl in *; assumption.
Qed.

Open Scope list_scope.
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

Lemma nth_error_list_update_neq: forall {A: Type} n1 n (v0: A) xs,
  n <> n1 ->
  nth_error (list_update n1 v0 xs) n = nth_error xs n.
Proof.
  induction n1; destruct xs; destruct n; simpl; intros; eauto; congruence.
Qed.

Lemma env_ok_replace_list_update: forall vars vs curr xnew x0 n n0 v pmap pmap1,
  env_ok vars vs (Word x0 :: curr) pmap →
  (match xnew with
  |Word xnew => v_inv pmap1 v xnew
  | _ => False
  end) →
  pmap_subsume pmap pmap1 →
  index_of vs n 0 = S n0 →
  S n0 < List.length vs →
  index_of vs n 0 < (List.length vs) ->
  env_ok (IEnv.insert (n, Some v) vars) vs (Word x0 :: list_update n0 xnew curr) pmap1.
Proof.
  intros.
  destruct xnew; cleanup.
  unfold env_ok in *; cleanup.
  simpl in *.
  split.
  1: rewrite list_update_size_same; eauto.
  intros.
  rewrite <- index_of_In with (k := 0); rewrite Nat.add_0_l.
  destruct (n =? n1)%N eqn:?.
  - spat `IEnv.lookup` at rewrite N.eqb_eq in *; rewrite Heqb in spat.
    pat `IEnv.lookup _ _ = _` at pose proof pat as ?.
    pat `IEnv.lookup _ _ = _` at rewrite IEnv.lookup_insert_eq in pat; cleanup.
    split; try eexists; try split; simpl; cleanup; eauto.
    pat `index_of _ _ _ = _` at rewrite pat; eauto; simpl.
    pat `List.length vs = _` at rewrite pat in *.
    rewrite <- Nat.succ_lt_mono in *.
    eapply nth_error_list_update_eq; eauto.
    eexists; eapply nth_error_nth'; eauto.
  - rewrite N.eqb_neq in *.
    rewrite IEnv.lookup_insert_neq in *; try assumption.
    spat `IEnv.lookup` at pose proof spat as Hlookup.
    pat `∀ _, _` as Hthm at eapply Hthm in Hlookup; cleanup.
    split; try eexists; try split; simpl; cleanup; eauto.
    1: pat `nth_error _ _ = Some _` at eapply nth_error_In in pat.
    1: rewrite index_of_In in *; eauto.
    2: eapply v_inv_pmap_subsume; eauto.
    destruct (index_of vs n1 0) eqn:?; simpl in *; cleanup; [reflexivity|].
    rewrite nth_error_list_update_neq; eauto.
    assert (S n2 <> S n0) as ?; eauto.
    pat `_ = S n2` at rewrite <- pat.
    pat `_ = S n0` at rewrite <- pat.
    intros Hcont; pat `n <> n1` at eapply pat.
    eapply index_of_bound_inj; eauto.
    pat `index_of _ n1 _ = _` at rewrite pat; eauto.
    Unshelve.
    exact (Word (word.of_Z 0)).
Qed.

Definition mk_new_curr n x h curr vs :=
  let idx := index_of vs n 0 in
  match idx with
  | 0 => Word x :: curr
  | S _ => Word h :: (list_update (idx - 1) (Word x) curr)
  end.

(* TODO: use this wherever possible *)
Lemma c_assign_thm: forall n v l l1 fs s vs t x h curr rest fuel c pmap,
  c_assign n l vs = (c, l1) ->
  In (Some n) vs ->
  v_inv pmap v x ->
  env_ok s.(vars) vs (Word h :: curr) pmap ->
  code_in t.(pc) (flatten c) t.(instructions) ->
  has_stack t (Word x :: Word h :: (curr ++ rest)) ->
  state_rel fs s t ->
  ∃ t1,
    steps (State t, fuel) (State t1, fuel) ∧
    has_stack t1 ((mk_new_curr n x h curr vs) ++ rest) ∧
    t1.(pc) = t.(pc) + List.length (flatten c) ∧
    l1 = l + List.length (flatten c) ∧
    env_ok (IEnv.insert (n, Some v) s.(vars)) vs (mk_new_curr n x h curr vs) pmap ∧
    state_rel fs s t1 ∧ regs t1 R14 = regs t R14 ∧
    t1.(instructions) = t.(instructions) ∧
    t1.(memory) = t.(memory).
Proof.
  intros.
  unfold c_assign, dlet in *; simpl in *; cleanup.
  unfold mk_new_curr.
  unfold has_stack in *; cleanup.
  spat `env_ok` at pose proof spat as Htmp; unfold env_ok in Htmp; cleanup.
  rewrite <- index_of_In with (k := 0) in *; rewrite Nat.add_0_l in *.
  destruct (index_of vs n 0) eqn:?; simpl in *; cleanup; simpl in *; cleanup.
  1: {
    eexists; split.
    1: {
      unfold set_stack, write_reg; simpl.
      eapply steps_step_same.
      eapply step_pop; eauto.
    }
    crunch_side_conditions.
    intros.
    eapply env_ok_replace_head; eauto.
    1: eapply pmap_subsume_refl.
    lia.
  }
  eexists; split.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_storersp; eauto.
    1: pat `_ = stack t` at rewrite <- pat in *; rewrite length_cons; rewrite length_app; lia.
    eapply steps_step_same.
    eapply step_pop; eauto.
    simpl; pat `_ = stack t` at rewrite <- pat; reflexivity.
  }
  rewrite Nat.sub_0_r.
  crunch_side_conditions.
  2: eapply env_ok_replace_list_update; eauto.
  all: crunch_side_conditions.
  rewrite list_update_append; eauto.
  lia.
Qed.

Theorem c_cmd_Assign: forall (n: name) (e: exp) (fuel: nat),
  goal_cmd (ImpSyntax.Assign n e) fuel.
Proof.
  intros.
  unfold goal_cmd; intros.
  simpl eval_cmd in *; unfold bind in *; simpl in *; subst.
  destruct eval_exp eqn:?; cleanup.
  simpl c_cmd in *; unfold dlet, ImpSemantics.assign in *.
  destruct c_exp eqn:?; cleanup.
  simpl flatten in *; unfold dlet in *; simpl in *; cleanup.
  repeat rewrite list_app_spec in *.
  repeat rewrite code_in_append in *; cleanup.
  destruct o; unfold_outcome; cleanup.
  2: eval_exp_contr_stop_tac.
  spat `eval_exp` at specialize (eval_exp_pure e _ _ _ Heqp) as ?; subst.
  spat `eval_exp` at specialize c_exp_correct as Htmp; unfold goal_exp in Htmp; eapply Htmp in spat; clear Htmp; cleanup; eauto; try congruence.
  destruct x eqn:?; destruct s eqn:?; cleanup; subst.
  unfold exp_res_rel in *; cleanup; subst.
  spat `env_ok` at pose proof spat as Henv_ok; unfold env_ok in spat; cleanup.
  spat `c_exp` at rwr ltac:(specialize (c_exp_length _ _ _ _ _ spat)).
  spat `steps` at rw ltac:(specialize (steps_instructions _ _ _ _ spat)).
  unfold has_stack in *|-; cleanup.
  destruct curr; cleanup.
  1: {
    rewrite <- index_of_In with (k := 0) in *; rewrite Nat.add_0_l in *.
    pat `Datatypes.length _ = Datatypes.length []` at rewrite pat in *; simpl in *.
    pat `List.length _ = 0` at eapply length_zero_iff_nil in pat; subst; simpl in *.
    pat `0 < 0` at inversion pat.
  }
  rewrite <- app_comm_cons in *.
  destruct c_assign eqn:?.
  pat `c_assign n _ _ = _` at eapply c_assign_thm in pat; eauto; cleanup.
  3: unfold has_stack; do 2 eexists; repeat (split; eauto).
  2: eauto.
  do 2 eexists; split.
  1: {
    eapply steps_trans.
    1: eauto.
    eauto.
  }
  simpl.
  crunch_side_conditions.
  Unshelve.
  eauto.
Qed.

Theorem prefix_refl: forall o,
  prefix o o = true.
Proof.
  intros; eapply prefix_correct; eapply substring_noop.
Qed.

Lemma substr_app: forall (s s1: string),
  substring 0 (length s) (s ++ s1) = s.
Proof.
  induction s; simpl; intros.
  - destruct s1; simpl; reflexivity.
  - f_equal; eauto.
Qed.

Theorem eval_cmd_mono: ∀ fuel c r s0 s1,
  eval_cmd c (EVAL_CMD fuel) s0 = (r, s1) -> prefix s0.(ImpSemantics.output) s1.(ImpSemantics.output) = true.
Proof.
  Opaque EVAL_CMD.
  induction fuel; induction c; simpl; intros; unfold_outcome; unfold_monadic; cleanup.
  all: repeat lazymatch goal with
  | IH: forall r s0 s1, eval_cmd ?c _ _ = _ -> _, H: context [ let (_, _) := eval_cmd ?c ?f ?s2 in _ ] |- _ =>
    let Hd := fresh "Hd" in
    destruct (eval_cmd c f s2) eqn:Hd; subst; cleanup; specialize IH with (1 := Hd); clear Hd
  | H: context [ match ?o with _ => _ end ] |- _ => destruct o eqn:?; subst; cleanup
  | H: eval_exp _ _ = _ |- _ => eapply eval_exp_pure in H; subst
  | H: eval_exps _ _ = _ |- _ => eapply eval_exps_pure in H; subst
  | H: eval_test _ _ = _ |- _ => eapply eval_test_pure in H; subst
  | H: EVAL_CMD 0 _ _ = _ |- _ => with_strategy transparent [EVAL_CMD] unfold EVAL_CMD in H
  | IH: forall c r s0 s1, eval_cmd _ _ _ = _ -> _, H: EVAL_CMD (S _) _ _ = _ |- _ =>
    with_strategy transparent [EVAL_CMD] unfold EVAL_CMD in H;
    specialize IH with (1 := H)
  | |- prefix _ (_ ++ _) = true =>
    eapply prefix_correct; eapply substr_app
  | H: (_, _) = (_, _) |- _ => inversion H; clear H; subst
  | _ => (unfold assign, alloc, update, get_vars, get_body_and_set_vars, set_varsM,
    catch_return, set_vars, set_memory, dest_word, get_char, put_char, set_output in * )
        || unfold_outcome || unfold_monadic || (eapply prefix_refl) || (simpl in * )
  end.
  all: try solve [eauto 4 using prefix_trans].
Qed.

Transparent EVAL_CMD.
Transparent eval_cmd.

Lemma env_ok_IMP_odd_curr1: forall vars vars1 vs curr curr1 pmap pmap1,
  env_ok vars vs curr pmap ->
  env_ok vars1 vs curr1 pmap1 ->
  odd (List.length curr) = true ->
  odd (List.length curr1) = true.
Proof.
  unfold env_ok; intros; cleanup.
  pat `_ = List.length curr1` at rewrite <- pat.
  pat `_ = List.length curr` at rewrite pat.
  assumption.
Qed.

Opaque pmap_ok.

Theorem c_cmd_Seq: forall (fuel: nat) (c1 c2: cmd),
  goal_cmd c1 fuel -> goal_cmd c2 fuel ->
  goal_cmd (ImpSyntax.Seq c1 c2) fuel.
Proof.
  Transparent eval_cmd.
  intros.
  unfold goal_cmd; intros.
  simpl c_cmd in *; unfold dlet in *.
  simpl eval_cmd in *; unfold bind in *; simpl in *; subst.
  destruct (c_cmd c1 _ _ _) eqn:?; simpl in *; subst; cleanup.
  destruct (c_cmd c2 _ _ _) eqn:?; simpl in *; subst; cleanup; unfold dlet in *; simpl in *.
  repeat rewrite list_app_spec in *.
  simpl flatten in *; repeat rewrite code_in_append in *; cleanup.
  pat `c_cmd c1 _ _ _ = _` at rwr ltac:(specialize (c_cmd_length c1 _ _ _ _ _ pat)).
  pat `c_cmd c2 _ _ _ = _` at specialize (c_cmd_length c2 _ _ _ _ _ pat) as ?; subst.
  destruct (eval_cmd c1 _) eqn:?; simpl in *; cleanup.
  assert (s0.(steps_done) <= s1.(steps_done)).
  1: destruct o; cleanup; repeat pat `eval_cmd _ _ _ = _` at eapply eval_cmd_steps_done_steps_up in pat; lia.
  assert (s.(steps_done) <= s0.(steps_done)).
  1: repeat pat `eval_cmd _ _ _ = _` at eapply eval_cmd_steps_done_steps_up in pat; lia.
  all: assert (steps_done s0 - steps_done s + (steps_done s1 - steps_done s0) = s1.(steps_done) - s.(steps_done)) as ? by lia.
  pat `goal_cmd c1 _` at unfold goal_cmd in pat; eapply pat in Heqp; clear pat; eauto; cleanup; [|destruct o; congruence].
  destruct x; destruct s2; cleanup.
  all: spat `steps` at pose proof spat.
  all: spat `steps` at eapply steps_add_fuel with (x := s1.(steps_done) - s0.(steps_done)) in spat.
  2: spat `_ = s1.(steps_done) - s.(steps_done)` at rewrite spat in *.
  2: do 2 eexists; repeat (split; eauto).
  2: {
    pat `match ?o with _ => _ end = _` at destruct o eqn:?; inversion pat; subst; eauto.
    eapply prefix_trans; eauto.
    pat `eval_cmd c2 _ _ = _` at eapply eval_cmd_mono in pat; eauto.
  }
  destruct o eqn:?; subst; cleanup.
  2: do 2 eexists; repeat (split; eauto).
  unfold cmd_res_rel in * |-; cleanup; subst.
  unfold goal_cmd in H0.
  pat `steps (State t, _) _` at rw ltac:(specialize (steps_instructions _ _ _ _ pat)).
  pat `eval_cmd c2 _ _ = _` at eapply H0 with (pmap := x0) (curr := x) in pat; clear H0; cleanup.
  all: eauto.
  2: eapply env_ok_IMP_odd_curr1 with (curr := curr); eauto.
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
    unfold state_rel in *; cleanup.
    crunch_side_conditions.
  }
Qed.

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
  destruct (c_test _ _ _ _ _) eqn:?; simpl in *; subst; cleanup.
  destruct (c_cmd c _ _ _) eqn:?; simpl in *; subst; cleanup; unfold dlet in *; simpl in *.
  repeat rewrite list_app_spec in *.
  simpl flatten in *; repeat rewrite code_in_append in *; cleanup; simpl code_in in *.
  spat `c_test` at rw ltac:(specialize (c_test_length _ _ _ _ _ _ _ spat)).
  spat `c_cmd c` at specialize (c_cmd_length c _ _ _ _ _ spat) as ?; subst.
  destruct eval_test eqn:?; cleanup.
  destruct o eqn:?; subst; cleanup.
  2: exfalso; destruct v eqn:?; spat `eval_test` at eapply eval_test_not_stop in spat; eauto; try congruence.
  unfold_outcome; cleanup.
  spat `c_test` at
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
    2: unfold state_rel in *; cleanup; pat `regs _ R14 = _` at rewrite pat in *; eauto.
    all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
    destruct x eqn:?; destruct s eqn:?; subst; cleanup.
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
    crunch_side_conditions.
    repeat (split; eauto).
  }
  (* test = true *)
  all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
  destruct eval_cmd eqn:?; destruct o eqn:?; subst; cleanup.
  2: { (* eval_cmd body = Stop v *)
    spat `eval_test` at eapply c_test_correct in spat.
    2: shelve.
    all: eauto.
    spat `_ -> _` at eauto; eapply spat in Heqp; clear spat; eauto; cleanup.
    2: unfold state_rel in *; cleanup; pat `regs _ R14 = _` at rewrite pat in *; eauto.
    all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
    destruct x eqn:?; destruct s eqn:?; cleanup; subst.
    assert ((pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) t0)) = (pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) s2))) as Htmp by reflexivity; rewrite Htmp in *; clear Htmp.
    spat `eval_cmd c` at unfold goal_cmd in spat; eapply H in spat; eapply spat in H2; clear spat; cleanup; eauto.
    2: unfold state_rel in *; cleanup; simpl in *; eapply r14_mono_IMP_pmap_in_bounds; eauto.
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
      crunch_side_conditions.
    }
    (* steps (body) ~~> Halt *)
    simpl in *; cleanup.
    crunch_side_conditions.
  }
  (* eval_cmd body = Cont v *)
  spat `eval_test` at eapply c_test_correct in spat.
  2: shelve.
  all: eauto.
  spat `_ -> _` at eauto; eapply spat in Heqp; clear spat; eauto; cleanup.
  2: unfold state_rel in *; cleanup; pat `regs _ R14 = _` at rewrite pat in *; eauto.
  all: rewrite Nat.add_comm; simpl; repeat rewrite Nat.add_1_r in *; eauto; cleanup.
  destruct x eqn:?; destruct s2 eqn:?; cleanup; subst.
  assert ((pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) t0)) = (pc (set_pc (pc t0 + 3 + Datatypes.length (flatten a)) s3))) as Htmp by reflexivity; rewrite Htmp in *; clear Htmp.
  assert (Cont v <> Stop Crash) by congruence.
  assert (s0.(steps_done) <= s.(steps_done)).
  1: pat `eval_cmd _ _ _ = _` at eapply eval_cmd_steps_done_steps_up in pat; lia.
  spat `eval_cmd c` at unfold goal_cmd in H; eapply H with (s1 := s) in spat; clear H; cleanup; eauto.
  2: unfold state_rel in *; cleanup; simpl in *; eapply r14_mono_IMP_pmap_in_bounds; eauto.
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
    all: crunch_side_conditions.
  }
  (* fuel = S n *)
  spat `EVAL_CMD` at pose proof spat; eapply EVAL_CMD_steps_done_non_zero in spat; eauto.
  spat `EVAL_CMD` at simpl in spat; unfold_outcome; cleanup.
  spat `_ = (res, _)` at unfold bind in *; simpl in spat; subst.
  assert (s.(steps_done) <= s1.(steps_done)).
  1: pat `eval_cmd (While t c) _ _ = _` at eapply eval_cmd_steps_done_steps_up in pat; unfold_asm_state; simpl in *; lia.
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
    crunch_side_conditions.
    eapply prefix_trans; eauto.
    pat `eval_cmd _ _ _ = _` at eapply eval_cmd_mono in pat; eauto.
  }
  (* steps (body) ~~> State *)
  all: pat `cmd_res_rel _ _ _ _ _ _ _` at unfold cmd_res_rel in pat; cleanup; eauto.
  spat `c_cmd _ (pc t0)` at assert (pc t0 = pc (set_pc (pc t0) s2)) as Hpceq by reflexivity; rewrite Hpceq in spat; clear Hpceq.
  assert (fuel < S fuel) as ? by lia.
  spat `_ < S _` at apply H0 in spat as Hgoal_While; clear H0.
  spat `eval_cmd (While t c)` at unfold goal_cmd in Hgoal_While; eapply Hgoal_While with (t := set_pc (pc t0) s2) in spat; clear Hgoal_While; cleanup.
  all: simpl; eauto.
  2: eapply env_ok_IMP_odd_curr1 with (curr := curr); eauto.
  2: {
    simpl; unfold dlet in *; simpl in *; repeat rewrite list_app_spec in *; repeat rewrite code_in_append; cleanup; repeat split.
    all: pat `steps (_, _) (State s2, _)` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); simpl.
    all: pat `steps (_, _) (State s3, _)` at rwr ltac:(specialize (steps_instructions _ _ _ _ pat)); simpl.
    all: repeat rewrite Nat.add_1_r; eauto; pat `pc s3 = _` at try rewrite <- pat; eauto.
  }
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
    crunch_side_conditions.
    assert ( (S (pc t0 + 3 + Datatypes.length (flatten a) + Datatypes.length (flatten a0))) =
      (S (Datatypes.length (flatten a0) + (pc t0 + 3 + Datatypes.length (flatten a))))) as <- by lia.
    eauto.
  }
  (* steps (body) ~~> Halt *)
  simpl in *; cleanup.
  crunch_side_conditions.
  Unshelve.
  all: eauto.
Qed.

Theorem c_cmd_Skip: forall (fuel: nat),
  goal_cmd Skip fuel.
Proof.
  Transparent c_cmd.
  Transparent eval_cmd.
  unfold goal_cmd; simpl; intros.
  unfold dlet in *; simpl in *.
  Opaque eval_cmd.
  unfold_outcome; cleanup.
  do 2 eexists.
  split; [eapply steps_refl|].
  crunch_side_conditions.
Qed.

Ltac addition_cleanup :=
  repeat match goal with
  | H: context[?x + 1 + 1 + 1 + 1] |- _ =>
    assert (x + 1 + 1 + 1 + 1 = x + 4) as Htmp by lia; rewrite Htmp in *; clear Htmp
  | H: context[?x + 1 + 1 + 1] |- _ =>
    assert (x + 1 + 1 + 1 = x + 3) as Htmp by lia; rewrite Htmp in *; clear Htmp
  | H: context[?x + 1 + 1] |- _ =>
    assert (x + 1 + 1 = x + 2) as Htmp by lia; rewrite Htmp in *; clear Htmp
  end.

Theorem c_cmd_If: forall (t: test) (c1 c2: cmd) (fuel: nat),
  goal_cmd c1 fuel -> goal_cmd c2 fuel ->
  goal_cmd (ImpSyntax.If t c1 c2) fuel.
Proof.
  intros.
  unfold goal_cmd; intros.
  spat `c_cmd` at simpl c_cmd in spat; unfold dlet in spat.
  with_strategy transparent [eval_cmd] simpl eval_cmd in *; unfold bind in *; simpl in *; subst.
  destruct c_test eqn:?; simpl in *; subst; cleanup.
  destruct (c_cmd c1) eqn:?; simpl in *; subst; cleanup.
  destruct (c_cmd c2) eqn:?; simpl in *; subst; cleanup; unfold dlet in *; simpl in *.
  repeat rewrite list_app_spec in *.
  simpl flatten in *; repeat rewrite code_in_append in *; cleanup; simpl code_in in *.
  spat `c_test` at rw ltac:(specialize (c_test_length _ _ _ _ _ _ _ spat)).
  spat `c_cmd c1` at specialize c_cmd_length with (1 := spat) as ?; subst.
  spat `c_cmd c2` at specialize c_cmd_length with (1 := spat) as ?; subst.
  destruct eval_test eqn:?; cleanup.
  addition_cleanup.
  pat `match ?o with _ => _ end = _` at destruct o eqn:?; subst; cleanup.
  2: exfalso; destruct v eqn:?; spat `eval_test` at eapply eval_test_not_stop in spat; eauto; try congruence.
  spat `c_test _ _ _ ?p` at
    assert (p = pc (set_pc p t0)) as Htmp by reflexivity; rewrite Htmp in spat; clear Htmp.
  spat `eval_test` at specialize (eval_test_pure t _ _ _ spat) as ?; subst.
  spat `eval_test` at specialize c_test_correct as Htmp; unfold goal_test in Htmp; eapply Htmp with (fuel := s1.(steps_done) - s0.(steps_done)) in spat; clear Htmp; eauto; cleanup.
  2: unfold state_rel in *; cleanup; pat `regs _ R14 = _` at rewrite pat in *; eauto.
  pat `let (_, _) := ?x in _` at destruct x eqn:?; subst; cleanup.
  pat `match ?s with _ => _ end` at destruct s eqn:?; subst; cleanup.
  spat `if ?v then _ else _` at destruct v eqn:?; cleanup; subst.
  2: { (* test = false *)
    spat `c_cmd c2 ?p` at
      assert (p = pc (set_pc p s2)) as Htmp by reflexivity; rewrite Htmp in spat; clear Htmp.
    spat `goal_cmd c2` at unfold goal_cmd in spat; rename spat into IHc.
    spat `eval_cmd c2` at eapply IHc in spat; clear IHc; cleanup; eauto.
    2: unfold state_rel in *; cleanup; simpl in *; eapply r14_mono_IMP_pmap_in_bounds; eauto.
    2: simpl; pat `steps _ (State s2, _)` at rewrite <- steps_instructions with (1 := pat); simpl; eauto.
    pat `let (_, _) := ?x in _` at destruct x eqn:?; subst; cleanup.
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; [eauto|econstructor|..].
      simpl.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; [|econstructor|..].
      1: unfold fetch; pat `pc s2 = _` at rewrite pat; pat `steps _ (State s2, _)` at rewrite <- steps_instructions with (1 := pat); simpl; eauto.
      simpl; eauto.
    }
    destruct s; cleanup.
    all: crunch_side_conditions.
  }
  spat `c_cmd c1 ?p` at
      assert (p = pc (set_pc p s2)) as Htmp by reflexivity; rewrite Htmp in spat; clear Htmp.
  spat `goal_cmd c1` at unfold goal_cmd in spat; rename spat into IHc.
  spat `eval_cmd c1` at eapply IHc in spat; clear IHc; cleanup; eauto.
  2: unfold state_rel in *; cleanup; simpl in *; eapply r14_mono_IMP_pmap_in_bounds; eauto.
  2: simpl; pat `steps _ (State s2, _)` at rewrite <- steps_instructions with (1 := pat); simpl; eauto.
  pat `let (_, _) := ?x in _` at destruct x eqn:?; subst; cleanup.
  pat `match ?s with _ => _ end` at destruct s eqn:?; subst; cleanup.
  2: { (* s = Halt *)
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; [eauto|econstructor|..].
      simpl.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; [|econstructor|..].
      1: unfold fetch; pat `pc s2 = _` at rewrite pat; pat `steps _ (State s2, _)` at rewrite <- steps_instructions with (1 := pat); simpl; eauto.
      eauto.
    }
    simpl; eauto.
  }
  (* s = State *)
  spat `cmd_res_rel` at pose proof spat.
  spat `cmd_res_rel` at unfold cmd_res_rel in spat.
  destruct res; cleanup.
  2: { (* res = Stop *)
    pat `match ?v with _ => _ end` at destruct v; cleanup; try congruence.
    1: { (* v = Return *)
      do 2 eexists; split.
      1: {
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump; [eauto|econstructor|..].
        simpl.
        eapply steps_trans.
        1: eauto.
        eapply steps_trans.
        1: eapply steps_step_same.
        1: eapply step_jump; [|econstructor|..].
        1: unfold fetch; pat `pc s2 = _` at rewrite pat; pat `steps _ (State s2, _)` at rewrite <- steps_instructions with (1 := pat); simpl; eauto.
        eauto.
      }
      simpl; eauto.
      crunch_side_conditions.
    }
    do 2 eexists; split.
    1: { (* v = TimeOut *)
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; [eauto|econstructor|..].
      simpl.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; [|econstructor|..].
      1: unfold fetch; pat `pc s2 = _` at rewrite pat; pat `steps _ (State s2, _)` at rewrite <- steps_instructions with (1 := pat); simpl; eauto.
      eauto.
    }
    simpl; eauto.
    crunch_side_conditions.
  }
  do 2 eexists; split.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump; [eauto|econstructor|..].
    simpl.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump; [|econstructor|..].
    all: pat `steps _ (State s2, _)` at specialize steps_instructions with (1 := pat) as Htmp; simpl in Htmp; rewrite Htmp in *; clear Htmp.
    1: unfold fetch; pat `pc s2 = _` at rewrite pat; simpl; eauto.
    eapply steps_trans.
    1: eauto.
    eapply steps_step_same.
    eapply step_jump; [|econstructor|..].
    all: pat `steps _ (State s3, _)` at specialize steps_instructions with (1 := pat) as Htmp; simpl in Htmp; rewrite Htmp in *; clear Htmp.
    unfold fetch; pat `pc s3 = _` at rewrite pat; eauto.
  }
  simpl.
  crunch_side_conditions.
  Unshelve.
  exact ImpSemantics.Abort.
Qed.

Lemma Z_div_mul_id: forall (a b: Z),
  (a mod b = 0)%Z ->
  (0 < b)%Z ->
  (a / b * b = a)%Z.
Proof.
  intros.
  destruct (a =? 0)%Z eqn:?.
  - rewrite Z.eqb_eq in *; subst.
    rewrite <- Z.gcd_0_l_nonneg with (n := b); eauto; lia.
  - rewrite Z.eqb_neq in *.
    assert (Z.gcd a b = b) as ?.
    1: rewrite <- Z.gcd_0_l_nonneg with (n := b) at 2; eauto; [|lia].
    1: rewrite <- Z.gcd_mod_l.
    1: pat `_ = 0%Z` at rewrite <- pat.
    1: reflexivity.
    pat `Z.gcd _ _ = _` at rewrite <- pat at 1.
    rewrite Z.gcd_div_swap.
    pat `Z.gcd _ _ = _` at rewrite pat.
    rewrite Z_div_same; [|lia]; rewrite Z.mul_1_r.
    reflexivity.
Qed.

Transparent mem_inv.

Lemma mem_inv_updated: forall pmap baseASM offASM i block off newBlock sASM s v1 v1ASM,
  pmap_ok pmap ->
  v_inv pmap (Pointer i) baseASM ->
  v_inv pmap (ImpSyntax.Word off) offASM ->
  v_inv pmap v1 v1ASM ->
  update_block block (w2n off / 8) v1 = Some newBlock ->
  (w2n off mod 8 =? 0) = true ->
  nth_error (ImpSemantics.memory s) i = Some block ->
  mem_inv pmap (memory sASM) (ImpSemantics.memory s) ->
  mem_inv pmap (λ a1 : word64, if (word.eqb (word.add baseASM offASM) a1)%Z then Some (Some v1ASM) else memory sASM a1)
    (list_update i newBlock (ImpSemantics.memory s)).
Proof.
  Opaque word.unsigned.
  Transparent pmap_ok.
  intros.
  rewrite Nat.eqb_eq in *.
  unfold mem_inv in *; cleanup; intros.
  unfold update_block in *; pat ` (if ?c then _ else _) = _` at destruct c eqn:?; cleanup.
  rewrite Nat.ltb_lt in *; unfold w2n in *.
  pat `v_inv _ (Pointer i) _` at unfold v_inv in pat; cleanup.
  pat `v_inv _ (ImpSyntax.Word off) _` at unfold v_inv in pat; cleanup; subst.
  destruct (i =? p) eqn:?.
  2: { (* i <> p *)
    rewrite Nat.eqb_neq in *.
    rewrite nth_error_list_update_neq in *; eauto.
    pat `forall _, _` at rename pat into Hmem.
    pat `nth_error _ p = _` at eapply Hmem in pat; cleanup.
    pat `nth_error _ i = _` at pose proof pat as Htmp; eapply Hmem in Htmp; cleanup; clear Hmem.
    spat `nth_error block _` at clear spat.
    pat `pmap i = _` at rewrite pat in *; cleanup.
    eexists; split; eauto; intros.
    destruct (word.eqb _ _)%Z eqn:?; [|eauto]; rewrite word.unsigned_eqb in *.
    exfalso; rewrite Z.eqb_eq in *.
    pat `i <> p` at eapply pat.
    eapply Properties.word.unsigned_inj in Heqb1.
    spat `pmap i` at rename spat into Hpmapi.
    spat `pmap p` at rename spat into Hpmapp.
    pat `pmap_ok _` at unfold pmap_ok in pat; specialize pat with (1 := Hpmapi) (2 := Hpmapp) (n2 := off0); eapply pat; clear pat; eauto.
    1: rewrite <- nth_error_Some; assert (nth_error v off0 <> None) by congruence; eauto.
    specialize (Properties.word.unsigned_range off) as ?; cleanup.
    rewrite mul_div_id; try lia.
    pat `_ mod _ = _` at assert (8 = Z.to_nat 8) as Htmp by lia; rewrite Htmp in pat; clear Htmp; rewrite <- Z2Nat.inj_mod in pat; eauto; try lia.
    rewrite Z2Nat.id; try lia.
    rewrite word.of_Z_unsigned; eauto.
  }
  (* i = p *)
  rewrite Nat.eqb_eq in *; subst.
  pat `nth_error (list_update _ _ _) p = _` at pose proof pat; rewrite nth_error_list_update_eq1 with (v0 := v) in pat; eauto; cleanup.
  pat `nth_error _ p = _` at eapply nth_error_list_update_eq1 in pat; rewrite <- nth_error_list_update_eq in pat; eauto; cleanup.
  pat `nth_error _ p = _` at rewrite pat in *; cleanup.
  pat `forall _, _` at rename pat into Hmem.
  pat `nth_error s.(ImpSemantics.memory) _ = _` at eapply Hmem in pat; clear Hmem; cleanup.
  rewrite list_update_size_same in *.
  eexists; split; eauto; intros.
  pat `pmap p = _` at rewrite pat in *; cleanup.
  specialize (Properties.word.unsigned_range off) as ?; cleanup.
  pat `_ mod _ = _` at pose proof pat as ?; assert (8 = Z.to_nat 8) as Htmp by lia; rewrite Htmp in pat; clear Htmp; rewrite <- Z2Nat.inj_mod in pat; eauto; try lia.
  spat ` (_ mod _)%Z` at rewrite <- Z2Nat.inj_0 in spat; rewrite Z2Nat.inj_iff in spat; eauto; try lia.
  2: spat ` (_ mod _)%Z` at inversion spat.
  2: eapply Z.mod_bound_pos; eauto; lia.
  destruct (off0 =? (Z.to_nat (word.unsigned off) / 8)) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *.
  - (* off0 = (word.unsigned off) / 8 *)
    eexists; subst.
    assert (off = word.of_Z (((word.unsigned off) / 8 * 8))) as Htmp; [|rewrite Htmp at 1; clear Htmp].
    1: rewrite Z_div_mul_id with (b := 8%Z); try lia; rewrite word.of_Z_unsigned; reflexivity.
    assert ((word.unsigned off / 8 * 8) = (Z.of_nat (Z.to_nat (word.unsigned off / 8 * 8))))%Z as ->.
    1: rewrite Z2Nat.id; [reflexivity|].
    1: rewrite Z_div_mul_id with (b := 8%Z); try lia; eapply Properties.word.unsigned_range.
    assert (Z.to_nat (word.unsigned off) / 8 * 8 = Z.to_nat (word.unsigned off / 8 * 8)) as ->.
    1: rewrite Z_div_mul_id with (b := 8%Z); try lia.
    1: rewrite mul_div_id; try lia.
    destruct (word.eqb _ _)%Z eqn:?; rewrite word.unsigned_eqb in *; rewrite ?Z.eqb_eq, ?Z.eqb_neq in *; subst; cleanup; try congruence.
    split; eauto.
    pat `nth_error (list_update _ _ _) _ = _` at pose proof pat; eapply nth_error_list_update_eq1 in pat; rewrite pat in *; cleanup.
    simpl; eauto.
  - (* off0 <> Z.to_nat (word.unsigned off) / 8 *)
    rewrite nth_error_list_update_neq in *; eauto.
    pat`forall _, _` at rename pat into Hmem.
    pat`nth_error _ off0 = _` at pose proof pat as ?.
    pat`nth_error _ _ = _` at eapply Hmem in pat; cleanup; clear Hmem.
    eexists.
    assert (off = word.of_Z (((word.unsigned off) / 8 * 8))) as Htmp; [|rewrite Htmp at 1; clear Htmp].
    1: rewrite Z_div_mul_id with (b := 8%Z); try lia; rewrite word.of_Z_unsigned; reflexivity.
    assert ((word.unsigned off / 8 * 8) = (Z.of_nat (Z.to_nat (word.unsigned off / 8 * 8))))%Z as ->.
    1: rewrite Z2Nat.id; [reflexivity|].
    1: rewrite Z_div_mul_id with (b := 8%Z); try lia; eapply Properties.word.unsigned_range.
    assert (Z.to_nat (word.unsigned off) / 8 * 8 = Z.to_nat (word.unsigned off / 8 * 8)) as <-.
    1: rewrite Z_div_mul_id with (b := 8%Z); try lia.
    1: rewrite mul_div_id; try lia.
    destruct (word.eqb _ _)%Z eqn:?; rewrite word.unsigned_eqb in *; rewrite ?Z.eqb_eq, ?Z.eqb_neq in *; subst; cleanup; [|eauto].
    exfalso.
    spat `pmap p` at rename spat into Hpmap.
    spat `pmap_ok` at unfold pmap_ok in spat; specialize spat with (1 := Hpmap) (2 := Hpmap) (n1 := off0) (n2 := Z.to_nat (word.unsigned off) / 8).
    assert(nth_error block off0 <> None) by congruence.
    pat`nth_error _ off0 <> None` at rewrite nth_error_Some in pat; rename pat into Hltoff0.
    pat`_ / 8 < _` at rename pat into Hltoff.
    spat `_ < _ -> _` at specialize spat with (1 := Hltoff0) (2 := Hltoff).
    pat `word.unsigned _ = word.unsigned _` at eapply Properties.word.unsigned_inj in pat; rename pat into Hwordeq.
    assert(off0 = Z.to_nat (word.unsigned off) / 8); try congruence.
    pat `word.add _ _ = word.add _ _ -> _` at eapply pat.
    congruence.
Qed.

Lemma memory_writeable_updated: forall s old_r14 r14 r15 pw offw impm w w1 i l l0 v1 pmap,
  memory_writable r14 r15 s.(memory) ->
  nth_error impm i = Some l ->
  update_block l (w2n w / 8) v1 = Some l0 ->
  (w2n w) mod 8 = 0 ->
  mem_inv pmap s.(memory) impm ->
  pmap_in_bounds pmap (Some old_r14) ->
  r14_mono (Some old_r14) (Some r14) ->
  v_inv pmap (Pointer i) pw ->
  v_inv pmap (ImpSyntax.Word w) offw ->
  memory_writable r14 r15 (λ a : word64, if word.eqb (word.add pw offw) a then Some (Some w1) else s.(memory) a).
Proof.
  intros.
  unfold memory_writable, can_write_mem_at in *; cleanup.
  repeat (split; eauto).
  intros; destruct (word.eqb (word.add pw offw) _)%Z eqn:?.
  2: {
    pat `forall _, _` at specialize pat with (a := a); rename pat into Hmem.
    pat `_ ∧ _` at eapply Hmem in pat; cleanup.
    unfold v_inv in *; cleanup; eauto.
  }
  pat `forall _, _` at clear pat.
  cleanup.
  pat `nth_error impm i = _` at rename pat into Hnth.
  spat `mem_inv` at eapply spat in Hnth; cleanup.
  unfold update_block in *.
  destruct (w2n w / 8 <? _) eqn:?; rewrite ?Nat.ltb_lt, ?Nat.ltb_ge in *; cleanup.
  unfold w2n in *.
  repeat (pat `v_inv _ _ _` at unfold v_inv in pat); cleanup; subst.
  pat `pmap i = _` at rewrite pat in *; cleanup.
  pat `pmap i = _` at rename pat into Hpmap.
  spat `pmap_in_bounds` at unfold pmap_in_bounds in spat; specialize spat with (1 := Hpmap) (2 := eq_refl); cleanup.
  pat `_ < _` at rename pat into Hlt.
  pat `forall n, _` at specialize pat with (1 := Hlt).
  rewrite mul_div_id in *; try lia.
  rewrite word.unsigned_eqb, word.unsigned_ltu, Z.eqb_eq, Z.eqb_neq, Z.ltb_lt in *.
  pat `_ = word.unsigned a` at rewrite <- pat in *.
  specialize (Properties.word.unsigned_range x) as ?.
  specialize (Properties.word.unsigned_range w) as ?.
  specialize (Properties.word.unsigned_range w) as ?.
  specialize (Properties.word.unsigned_range r14) as ?.
  specialize (Properties.word.unsigned_range r15) as ?.
  assert (8 = (Z.to_nat 8)) as Htmp by lia; rewrite Htmp in *; clear Htmp.
  pat `Z.to_nat _ mod _ = _` at pose proof pat as ?; rewrite <- Znat.Z2Nat.inj_mod in pat; try lia; rewrite <- Z2Nat.inj_0 in pat; eapply Z2Nat.inj in pat; try lia.
  2: specialize Z.mod_pos_bound with (a := word.unsigned w) (b := 8%Z) as ?; try lia.
  rewrite Z2Nat.id in *; try lia.
  rewrite Properties.word.unsigned_of_Z_0 in *.
  spat `r14_mono` at unfold r14_mono in spat; specialize spat with (old_wr14 := old_r14) (new_wr14 := r14) (1 := eq_refl) (2 := eq_refl).
  pat `_ < List.length l` at rename pat into Hlt.
  (* destruct(nth_error l (Z.to_nat (word.unsigned w) / Z.to_nat 8)) eqn:Hnthl.
  2: pat `nth_error l _ = None` at rewrite <- nth_error_Some in *; rewrite pat in *; congruence.
  pat `forall off xopt, _` at eapply pat in Hnthl; clear pat; cleanup. *)
  assert ((Z.to_nat 8) = 8) as Htmp by lia; rewrite Htmp in *; clear Htmp.
  (* rewrite mul_div_id in *; try lia. *)
  (* rewrite Z2Nat.id in *; try lia. *)
  rewrite word.of_Z_unsigned in *.
  rewrite ?word.unsigned_eqb, ?word.unsigned_ltu, ?Z.eqb_eq, ?Z.eqb_neq, ?Z.ltb_lt in *.
  lia.
Qed.

Theorem c_cmd_Update: forall (a e e': exp) (fuel: nat),
  goal_cmd (Update a e e') fuel.
Proof.
  Transparent c_cmd.
  Transparent eval_cmd.
  unfold goal_cmd; simpl; intros.
  Opaque eval_cmd.
  unfold dlet in *.
  destruct (c_exp a) eqn:?.
  destruct (c_exp e) eqn:?.
  destruct (c_exp e') eqn:?.
  simpl in *; cleanup.
  unfold_monadic.
  destruct (eval_exp a) eqn:?.
  destruct (eval_exp e) eqn:?.
  destruct (eval_exp e') eqn:?.
  destruct o; cleanup.
  2: eval_exp_contr_stop_tac.
  destruct o0; cleanup.
  2: eval_exp_contr_stop_tac.
  destruct o1; cleanup.
  2: eval_exp_contr_stop_tac.
  unfold update in *; unfold_outcome.
  destruct v; cleanup; [congruence|].
  destruct v0; cleanup; [|congruence].
  destruct (negb (w2n w mod 8 =? 0)) eqn:?; cleanup; [congruence|].
  destruct (nth_error s3.(ImpSemantics.memory) i) eqn:?; cleanup; [|congruence].
  destruct (update_block l (w2n w / 8) v1) eqn:?; cleanup; [|congruence].
  pat `eval_exp a _ = _` at specialize eval_exp_pure with (1 := pat) as ?.
  pat `eval_exp e _ = _` at specialize eval_exp_pure with (1 := pat) as ?.
  pat `eval_exp e' _ = _` at specialize eval_exp_pure with (1 := pat) as ?.
  cleanup; subst.
  simpl flatten in *; unfold dlet in *; simpl in *; repeat rewrite list_app_spec in *; repeat rewrite code_in_append in *; cleanup.
  pat `c_exp a _ _ = _` at specialize c_exp_length with (1 := pat) as Htmp; rewrite <- Htmp in *; clear Htmp.
  pat `c_exp e _ _ = _` at specialize c_exp_length with (1 := pat) as Htmp; rewrite <- Htmp in *; clear Htmp.
  pat `c_exp e' _ _ = _` at specialize c_exp_length with (1 := pat) as Htmp; rewrite <- Htmp in *; clear Htmp.
  pat `eval_exp a _ = (?r, _)` at
    assert (r <> Stop Crash) as ? by congruence; specialize c_exp_correct as Htmp1; unfold goal_exp in Htmp1; eapply Htmp1 with (fuel := 0) in pat; unfold exp_res_rel in pat; eauto; clear Htmp1; cleanup.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  try steps_inst_tac.
  pat `eval_exp e _ = (?r, _)` at
    assert (r <> Stop Crash) as ? by congruence; specialize c_exp_correct as Htmp1; unfold goal_exp in Htmp1; eapply Htmp1 with (curr := Word x :: curr) (vs := None :: vs) (fuel := 0) in pat; unfold exp_res_rel in pat; eauto; clear Htmp1; cleanup.
  2: eapply env_ok_add_None; eauto; eapply pmap_subsume_refl.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  pat `steps _ (State s0, _)`at specialize steps_instructions with (1 := pat) as Htmp; simpl in Htmp; rewrite Htmp in *; clear Htmp.
  pat `eval_exp e' _ = (?r, _)` at
    assert (r <> Stop Crash) as ? by congruence; specialize c_exp_correct as Htmp1; unfold goal_exp in Htmp1; eapply Htmp1 with (curr := Word x0 :: (Word x :: curr)) (vs := None :: None :: vs) (fuel := 0) in pat; unfold exp_res_rel in pat; eauto; clear Htmp1; cleanup.
  2: eapply env_ok_add_None; eauto; try eapply pmap_subsume_refl; eapply env_ok_add_None; eauto; eapply pmap_subsume_refl.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  simpl code_in in *; cleanup.
  unfold has_stack in *; cleanup.
  do 2 eexists; split; simpl.
  1: {
    rewrite Nat.sub_diag.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eauto.
    pat `steps (State s0, _) _`at specialize steps_instructions with (1 := pat) as Htmp; rewrite Htmp in *.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_pop; eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_pop; simpl; eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_add; simpl; eauto; simpl; reflexivity.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_store; simpl; eauto; simpl; [reflexivity|].
    1: unfold v_inv in *; simpl in *; cleanup; subst.
    1: unfold update_block in *.
    1: pat ` (if ?c then _ else _) = _` at destruct c eqn:?; cleanup.
    1: pat `mem_inv _ s1.(memory) _` at unfold mem_inv in pat; rename pat into Hmem.
    1: pat `nth_error s3.(ImpSemantics.memory) _ = Some _` at eapply Hmem in pat; clear Hmem; cleanup.
    1: pat `forall _, _` at rename pat into Hmem.
    1: pat ` (_ <? List.length l) = true` at rewrite Nat.ltb_lt in pat; rewrite <- nth_error_Some in *.
    1: destruct (nth_error l (w2n w / 8)) eqn:?; cleanup; [|congruence].
    1: pat `nth_error l _ = Some _` at eapply Hmem in pat; clear Hmem; cleanup.
    1: rewrite negb_false_iff in *; rewrite Nat.eqb_eq in *.
    1: pat `memory s1 _ = _` at rewrite mul_div_id in *; unfold w2n in pat; eauto.
    1: rewrite Z2Nat.id in *; [|specialize (Properties.word.unsigned_range w) as ?; lia].
    1: rewrite word.of_Z_unsigned in *; rewrite Properties.word.unsigned_of_Z_0 in *.
    1: rewrite Properties.word.add_0_r; rewrite Properties.word.add_comm.
    1: pat `pmap i = _` at rewrite pat in *; clear pat; cleanup.
    Opaque word.eqb.
    1: unfold write_mem; simpl.
    1: pat `memory s1 _ = Some _` at rewrite pat; reflexivity.
    eapply steps_step_same.
    eapply step_pop; eauto.
  }
  simpl.
  crunch_side_conditions.
  1: { (* state_rel *)
    pat `regs s1 R14 = _` at rewrite pat in *.
    pat `regs t R14 = _` at rewrite pat in *.
    rewrite negb_false_iff, Nat.eqb_eq in *.
    eapply memory_writeable_updated with (w := w); eauto.
    eapply r14_mono_trans; eauto; eapply r14_mono_trans; eauto.
  }
  1: eapply r14_mono_IMP_pmap_in_bounds; eauto.
  1: crunch_side_conditions.
  2: {
    unfold pmap_in_memory; intros * Hpmap; cleanup.
    destruct (p =? i) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; subst.
    1: eexists; eapply nth_error_list_update_eq; eauto.
    rewrite nth_error_list_update_neq; spat `pmap_in_memory` at eapply spat in Hpmap; eauto.
  }
  rewrite negb_false_iff in *.
  eapply mem_inv_updated; eauto.
  Unshelve.
  all: exact Abort.
Qed.

Lemma odd_is_succ: forall n,
  odd n = true ->
  exists n1, n = S n1.
Proof.
  intros.
  destruct n; simpl in *.
  - unfold odd, even, negb in *.
    congruence.
  - eauto. 
Qed.

Theorem c_cmd_GetChar: forall (n: name) (fuel: nat),
  goal_cmd (ImpSyntax.GetChar n) fuel.
Proof.
  unfold goal_cmd; simpl; intros.
  with_strategy transparent [eval_cmd] simpl in *.
  unfold_monadic; unfold get_char, assign, set_input, set_vars in *; unfold_outcome; simpl in *; cleanup.
  simpl c_cmd in *; unfold dlet in *.
  destruct c_read eqn:?; simpl in *.
  destruct c_assign eqn:?; simpl in *; cleanup.
  unfold c_assign, dlet, c_read, dlet in *.
  simpl in *; unfold dlet in *; simpl in *; cleanup.
  simpl flatten in *; rewrite list_app_spec in *.
  repeat rewrite code_in_append in *; cleanup.
  spat `env_ok` at pose proof spat as Henv_ok; unfold env_ok in spat; cleanup.
  unfold has_stack in *|-; cleanup.
  rewrite <- index_of_In with (k := 0) in *; rewrite Nat.add_0_l in *.
  destruct curr; cleanup.
  1: {
    pat `Datatypes.length _ = Datatypes.length []` at rewrite pat in *; simpl in *.
    pat `List.length _ = 0` at eapply length_zero_iff_nil in pat; subst; simpl in *.
    pat `0 < 0` at inversion pat.
  }
  cleanup.
  destruct index_of eqn:?; destruct t.(input) eqn:?.
  1: { (* index_of = 0; input = Lnil *)
    rewrite <- app_comm_cons in *.
    simpl in *; cleanup; simpl in *; cleanup.
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_get_ascii; simpl; eauto.
      1: unfold read_ascii; pat `t.(input) = _` at rewrite pat; subst; reflexivity.
      1: pat `_ = stack t` at rewrite <- pat.
      1: pat `List.length vs = _` at rewrite pat in *.
      1: rewrite <- Nat.even_succ in *; rewrite rw_mod_2_even in *; rewrite length_app; rewrite Nat.even_succ_succ in *.
      1: rewrite Nat.even_succ; rewrite Nat.odd_add; rewrite Nat.even_succ in *; rewrite <- Nat.negb_even in *; pat `negb (Nat.even (List.length rest)) = _` at rewrite Nat.negb_even in pat.
      1: spat `Nat.even (List.length curr)` at rewrite spat; spat `Nat.odd (List.length rest)` at rewrite spat; simpl; eauto.
      simpl; unfold write_reg; simpl.
      eapply steps_step_same.
      eapply step_pop; simpl; eauto.
      simpl; unfold write_reg; simpl.
      assert (pc t + 1 + 1 = pc t + 2) as -> by lia; eauto.
    }
    unfold write_reg, set_stack; simpl.
    unfold state_rel in *; cleanup.
    crunch_side_conditions.
    1: pat `ImpSemantics.input s = _` at rewrite pat; pat `input t = _` at rewrite pat; simpl; reflexivity.
    1: unfold has_stack in *; do 2 eexists; simpl; split; eauto; pat `_ = stack t` at rewrite <- pat; rewrite app_comm_cons; reflexivity.
    pat `ImpSemantics.input s = _` at rewrite pat; pat `input t = _` at rewrite pat.
    eapply env_ok_replace_head; eauto; simpl; eauto.
    1: eapply pmap_subsume_refl.
    pat `index_of _ _ _ = _` at rewrite pat; assumption.
  }
  1: { (* index_of = 0; input = Lcons *)
    rewrite <- app_comm_cons in *.
    simpl in *; cleanup; simpl in *; cleanup.
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_get_ascii; simpl; eauto.
      1: unfold read_ascii; pat `t.(input) = _` at rewrite pat; subst; reflexivity.
      1: pat `_ = stack t` at rewrite <- pat.
      1: pat `List.length vs = _` at rewrite pat in *.
      1: rewrite <- Nat.even_succ in *; rewrite rw_mod_2_even in *; rewrite length_app; rewrite Nat.even_succ_succ in *.
      1: rewrite Nat.even_succ; rewrite Nat.odd_add; rewrite Nat.even_succ in *; rewrite <- Nat.negb_even in *; pat `negb (Nat.even (List.length rest)) = _` at rewrite Nat.negb_even in pat.
      1: spat `Nat.even (List.length curr)` at rewrite spat; spat `Nat.odd (List.length rest)` at rewrite spat; simpl; eauto.
      simpl; unfold write_reg; simpl.
      eapply steps_step_same.
      eapply step_pop; simpl; eauto.
      simpl; unfold write_reg; simpl.
      assert (pc t + 1 + 1 = pc t + 2) as -> by lia; eauto.
    }
    unfold write_reg, set_stack; simpl.
    unfold state_rel in *; cleanup.
    crunch_side_conditions.
    1: pat `ImpSemantics.input s = _` at rewrite pat; pat `input t = _` at rewrite pat; simpl; reflexivity.
    1: unfold has_stack in *; do 2 eexists; simpl; split; eauto; pat `_ = stack t` at rewrite <- pat; rewrite app_comm_cons; reflexivity.
    pat `ImpSemantics.input s = _` at rewrite pat; pat `input t = _` at rewrite pat.
    eapply env_ok_replace_head; eauto; simpl; eauto.
    1: eapply pmap_subsume_refl.
    pat `index_of _ _ _ = _` at rewrite pat; assumption.
  }
  1: { (* index_of = S _; input = Lnil *)
    rewrite <- app_comm_cons in *.
    simpl in *; cleanup; simpl in *; cleanup.
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_get_ascii; simpl; eauto.
      1: unfold read_ascii; pat `t.(input) = _` at rewrite pat; subst; reflexivity.
      1: pat `_ = stack t` at rewrite <- pat.
      1: pat `List.length vs = _` at rewrite pat in *.
      1: rewrite <- Nat.even_succ in *; rewrite rw_mod_2_even in *; rewrite length_app; rewrite Nat.even_succ_succ in *.
      1: rewrite Nat.even_succ; rewrite Nat.odd_add; rewrite Nat.even_succ in *; rewrite <- Nat.negb_even in *; pat `negb (Nat.even (List.length rest)) = _` at rewrite Nat.negb_even in pat.
      1: spat `Nat.even (List.length curr)` at rewrite spat; spat `Nat.odd (List.length rest)` at rewrite spat; simpl; eauto.
      simpl; unfold write_reg; simpl.
      assert (pc t + 1 + 1 = pc t + 2) as -> by lia; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_storersp; simpl; eauto.
      1: eapply Nat.lt_trans; eauto; pat `_ = stack t` at rewrite <- pat; rewrite length_app; pat `List.length vs = _` at rewrite pat.
      1: pat `odd (List.length rest) = true` at eapply odd_is_succ in pat; cleanup; lia.
      1: simpl; reflexivity.
      unfold update_stack; simpl.
      eapply steps_step_same.
      eapply step_pop; simpl; eauto.
    }
    unfold write_reg, set_stack; simpl.
    unfold state_rel in *; cleanup.
    crunch_side_conditions.
    1: pat `ImpSemantics.input s = _` at rewrite pat; pat `input t = _` at rewrite pat; simpl; reflexivity.
    1: {
      unfold has_stack.
      do 2 eexists.
      split; try split; simpl; eauto.
      pat `_ = stack t` at rewrite <- pat.
      rewrite list_update_append; [|lia].
      rewrite app_comm_cons; reflexivity.
    }
    eapply env_ok_replace_list_update; eauto.
    1: pat `ImpSemantics.input s = _` at rewrite pat; pat `input t = _` at rewrite pat; simpl; reflexivity.
    1: eapply pmap_subsume_refl.
    pat `index_of _ _ _ = _` at rewrite pat; assumption.
  }
  (* index_of = S _; input = Lcons *)
  rewrite <- app_comm_cons in *.
  simpl in *; cleanup; simpl in *; cleanup.
  do 2 eexists; split.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_push; eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_get_ascii; simpl; eauto.
    1: unfold read_ascii; pat `t.(input) = _` at rewrite pat; subst; reflexivity.
    1: pat `_ = stack t` at rewrite <- pat.
    1: pat `List.length vs = _` at rewrite pat in *.
    1: rewrite <- Nat.even_succ in *; rewrite rw_mod_2_even in *; rewrite length_app; rewrite Nat.even_succ_succ in *.
    1: rewrite Nat.even_succ; rewrite Nat.odd_add; rewrite Nat.even_succ in *; rewrite <- Nat.negb_even in *; pat `negb (Nat.even (List.length rest)) = _` at rewrite Nat.negb_even in pat.
    1: spat `Nat.even (List.length curr)` at rewrite spat; spat `Nat.odd (List.length rest)` at rewrite spat; simpl; eauto.
    simpl; unfold write_reg; simpl.
    assert (pc t + 1 + 1 = pc t + 2) as -> by lia; eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_storersp; simpl; eauto.
    1: eapply Nat.lt_trans; eauto; pat `_ = stack t` at rewrite <- pat; rewrite length_app; pat `List.length vs = _` at rewrite pat.
    1: pat `odd (List.length rest) = true` at eapply odd_is_succ in pat; cleanup; lia.
    1: simpl; reflexivity.
    unfold update_stack; simpl.
    eapply steps_step_same.
    eapply step_pop; simpl; eauto.
  }
  unfold write_reg, set_stack; simpl.
  unfold state_rel in *; cleanup.
  crunch_side_conditions.
  1: pat `ImpSemantics.input s = _` at rewrite pat; pat `input t = _` at rewrite pat; simpl; reflexivity.
  1: { (* has_stack *)
    unfold has_stack.
    do 2 eexists.
    split; try split; simpl; eauto.
    pat `_ = stack t` at rewrite <- pat.
    rewrite list_update_append; [|lia].
    rewrite app_comm_cons; reflexivity.
  }
  eapply env_ok_replace_list_update; eauto.
  1: pat `ImpSemantics.input s = _` at rewrite pat; pat `input t = _` at rewrite pat; simpl; reflexivity.
  1: eapply pmap_subsume_refl.
  pat `index_of _ _ _ = _` at rewrite pat; assumption.
Qed.

Theorem c_cmd_PutChar: forall (e: exp) (fuel: nat),
  goal_cmd (ImpSyntax.PutChar e) fuel.
Proof.
  Transparent c_cmd.
  Transparent eval_cmd.
  unfold goal_cmd; simpl; intros.
  Opaque eval_cmd.
  unfold dlet in *.
  destruct (c_exp e) eqn:?.
  simpl in *; cleanup.
  unfold_monadic.
  destruct (eval_exp e) eqn:?.
  destruct o; cleanup.
  2: eval_exp_contr_stop_tac.
  unfold put_char in *; unfold_outcome.
  destruct v; cleanup; [|congruence].
  destruct (_ <? _) eqn:?; cleanup; [|congruence].
  pat `eval_exp e _ = _` at specialize eval_exp_pure with (1 := pat) as ?.
  cleanup; subst.
  simpl flatten in *; unfold dlet in *; simpl in *; repeat rewrite list_app_spec in *; repeat rewrite code_in_append in *; cleanup.
  pat `c_exp e _ _ = _` at specialize c_exp_length with (1 := pat) as Htmp; rewrite <- Htmp in *; clear Htmp.
  pat `eval_exp e _ = (?r, _)` at
    assert (r <> Stop Crash) as ? by congruence; specialize c_exp_correct as Htmp1; unfold goal_exp in Htmp1; eapply Htmp1 with (fuel := 0) in pat; unfold exp_res_rel in pat; eauto; clear Htmp1; cleanup.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  try steps_inst_tac.
  simpl code_in in *; cleanup.
  unfold has_stack in *|-; cleanup.
  spat `env_ok` at pose proof spat as Henv_ok; unfold env_ok in spat; cleanup. 
  do 2 eexists; split; simpl.
  1: {
    simpl in *; cleanup; simpl in *; cleanup; subst.
    rewrite Nat.sub_diag.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_mov; eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_put_ascii; simpl; eauto.
    1: unfold v_inv, w2n in *; cleanup; rewrite Nat.ltb_lt in *; subst; lia.
    1: pat `_ = stack s` at rewrite <- pat.
    1: rewrite length_app, rw_mod_2_even, Nat.even_add, <- Nat.negb_even, negb_true_iff in *.
    1: do 2 (pat `Nat.even _ = false` at rewrite pat; clear pat); simpl; eauto.
    simpl.
    eapply steps_step_same.
    eapply step_pop; simpl; eauto.
    pat `_ = stack s` at rewrite <- pat; pat `curr ++ rest = _ :: _` at rewrite pat; reflexivity.
  }
  simpl in *; subst.
  unfold write_reg, set_stack; simpl.
  unfold state_rel in *; cleanup.
  crunch_side_conditions.
  1: unfold w2n; pat `_ = output s` at rewrite <- pat; reflexivity.
  Unshelve.
  exact ImpSemantics.Abort.
Qed.

(* TODO: *)
(* - I need to know that the new moved r14 address (new allocation start) doesn't overflow *)
(*   I need (w2n r14) + (w2n off) < 2^64 *)
(* - I also need to know that the offset is in bounds *)
Lemma pmap_ok_impossible: forall p2 len2 base2 base1 off2 off1 pmap t s r14 l r15,
  pmap_in_bounds pmap (regs t R14) ->
  word.ltu (word.sub r15 base1) l = false ->
  word.ltu r15 base1 = false ->
  off1 < w2n l / 8 ->
  w2n l mod 8 = 0 ->
  r14_mono (regs t R14) (regs s R14) ->
  regs s R14 = Some base1 ->
  regs t R14 = Some r14 ->
  pmap p2 = Some (base2, len2) ->
  off2 < len2 ->
  word.add base2 (word.of_Z (Z.of_nat (off2 * 8))) = word.add base1 (word.of_Z (Z.of_nat (off1 * 8))) ->
  False.
Proof.
  intros.
  pat `pmap p2 = _` at rename pat into Hpmap.
  spat `pmap_in_bounds` at rename spat into Hpmapbounds.
  pat `regs t R14 = _` at unfold pmap_in_bounds in Hpmapbounds; specialize Hpmapbounds with (1 := Hpmap) (2 := pat); clear Hpmap; cleanup.
  pat `off2 < _` at rename pat into Hlt.
  spat `_ < _ -> word.ltu _ _ = true` at specialize spat with (1 := Hlt); clear Hlt.
  pat `regs s R14 = _` at rewrite pat in *; cleanup; clear pat.
  pat `word.ltu _ r14 = true` at rename pat into Hbase2ltx6.
  pat `r14_mono (regs t R14) (Some base1)` at unfold r14_mono in pat; rename pat into Hr14_mono.
  pat `regs t R14 = _` at eapply Hr14_mono with (2 := eq_refl) in pat; clear Hr14_mono.
  pat `word.add _ _ = _` at rewrite pat in *; clear pat.
  rewrite word.unsigned_eqb, word.unsigned_ltu, Z.eqb_eq, Z.ltb_lt in *.
  specialize (Properties.word.unsigned_range l) as ?.
  specialize (Properties.word.unsigned_range base1) as ?.
  specialize (Properties.word.unsigned_range r15) as ?.
  rewrite Properties.word.unsigned_add_nowrap in *.
  2: {
    assert(word.unsigned base1 + word.unsigned (word.of_Z (Z.of_nat (w2n l / 8 * 8)): word64) < 2 ^ 64)%Z.
    2: {
      rewrite mul_div_id in *; eauto.
      unfold w2n in *; rewrite Z2Nat.id in *; try lia.
      rewrite word.of_Z_unsigned in *.
      rewrite Z.lt_add_lt_sub_l in *.
      assert(off1 * 8 < Z.to_nat (word.unsigned l) / 8 * 8) as ? by lia.
      rewrite mul_div_id in *; eauto.
      pat `off1 * 8 < _` at rewrite <- Nat2Z.id with (n := off1 * 8) in pat.
      assert(Z.of_nat (off1 * 8) < word.unsigned l)%Z by lia.
      rewrite Properties.word.unsigned_of_Z_nowrap; lia.
    }
    rewrite Z.ltb_ge in *.
    rewrite Z.lt_add_lt_sub_l in *.
    rewrite mul_div_id in *; eauto.
    unfold w2n in *; rewrite Z2Nat.id in *; try lia.
    rewrite word.of_Z_unsigned in *.
    rewrite Properties.word.unsigned_sub_nowrap in *; lia.
  }
  rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia.
  assert (off1 * 8 < w2n l / 8 * 8) by lia; rewrite mul_div_id in *; eauto.
  pat `off1 * 8 < _` at rewrite <- Nat2Z.id with (n := off1 * 8) in pat.
  unfold w2n in *.
  assert(Z.of_nat (off1 * 8) < word.unsigned l)%Z by lia.
  lia.
Qed.

Lemma pmap_in_bounds_alloc: forall imem_size t s r14 old_r14 r15 w pmap,
  regs t R14 = Some old_r14 ->
  r14_mono (regs t R14) (regs s R14) ->
  regs s R14 = Some r14 ->
  regs s R15 = Some r15 ->
  pmap_in_bounds pmap (regs t R14) ->
  word.ltu r15 r14 = false ->
  word.ltu (word.sub r15 r14) w = false ->
  memory_writable r14 r15 s.(memory) ->
  w2n w mod 8 = 0 ->
  w2n w <> 0 ->
  pmap_in_bounds (fun p => if p =? imem_size then Some (r14, w2n w / 8) else pmap p)
    (Some (word.add r14 w)).
Proof.
  intros.
  unfold pmap_in_bounds; intros.
  destruct (p =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; cleanup; subst.
  2: {
    pat`pmap p = _` at rename pat into Hpmap.
    pat`regs t R14 = _` at rename pat into Htr14.
    spat `pmap_in_bounds` at unfold pmap_in_bounds in spat; eapply spat with (2 := Htr14) in Hpmap; cleanup.
    pat `regs s R14 = _` at rewrite pat in *.
    specialize (Properties.word.unsigned_range w) as ?.
    specialize (Properties.word.unsigned_range r14) as ?.
    specialize (Properties.word.unsigned_range old_r14) as ?.
    specialize (Properties.word.unsigned_range base) as ?.
    specialize (Properties.word.unsigned_range r15) as ?.
    split; eauto; intros.
    pat `n < len` at rename pat into Hlt.
    pat `forall n, _ < _ -> _` at specialize pat with (n := n) (1 := Hlt).
    pat `regs t R14 = _` at rewrite pat in *; cleanup.
    pat `r14_mono _ _` at unfold r14_mono in pat; specialize pat with (1 := eq_refl) (2 := eq_refl).
    rewrite word.unsigned_eqb, word.unsigned_ltu, Z.eqb_eq, Z.ltb_lt, Z.ltb_ge in *.
    eapply Z.lt_trans; eauto.
    rewrite Properties.word.unsigned_sub_nowrap in *; try lia.
    rewrite Properties.word.unsigned_add_nowrap; try lia.
    pat `_ \/ _` at destruct pat; try lia.
    pat `word.unsigned _ = _` at rewrite pat.
    unfold w2n in *; lia.
  }
  specialize (Properties.word.unsigned_range w) as ?.
  specialize (Properties.word.unsigned_range r15) as ?.
  specialize (Properties.word.unsigned_range base) as ?.
  specialize (Properties.word.unsigned_range old_r14) as ?.
  rewrite word.unsigned_ltu, Z.ltb_lt, Z.ltb_ge in *.
  split.
  2: {
    unfold memory_writable in *; cleanup.
    pat `word.eqb base _ = false` at rewrite word.unsigned_eqb, Z.eqb_neq in pat.
    rewrite Properties.word.unsigned_of_Z_0.
    assert(0 <> word.unsigned base)%Z; try lia.
    rewrite <- Properties.word.unsigned_of_Z_0.
    eauto.
  }
  intros.
  rewrite word.unsigned_ltu, Z.ltb_lt in *.
  unfold w2n in *.
  assert(n * 8 < Z.to_nat (word.unsigned w) / 8 * 8) as ? by lia.
  rewrite mul_div_id in *; eauto.
  assert(Z.of_nat (n * 8) < word.unsigned w)%Z as ? by lia.
  specialize (Properties.word.unsigned_range (word.of_Z (Z.of_nat (n * 8)): word64)) as ?.
  rewrite Properties.word.unsigned_sub_nowrap in *; try lia.
  assert(word.unsigned (word.of_Z (Z.of_nat (n * 8)): word64) < word.unsigned w)%Z.
  1: rewrite Properties.word.unsigned_of_Z_nowrap; try lia.
  rewrite Properties.word.unsigned_add_nowrap; try lia.
  rewrite Properties.word.unsigned_add_nowrap; try lia.
Qed.

Lemma pmap_ok_alloc: forall pmap fs imps t s w r14 r15,
  mem_inv pmap (memory s) imps.(ImpSemantics.memory) ->
  regs s R14 = Some r14 ->
  regs s R15 = Some r15 ->
  state_rel fs imps t ->
  pmap_ok pmap ->
  pmap_in_bounds pmap (regs t R14) ->
  word.ltu (word.sub r15 r14) w = false ->
  word.ltu r15 r14 = false ->
  w2n w mod 8 = 0 ->
  r14_mono (regs t R14) (regs s R14) ->
  pmap_ok (λ p : nat, if p =? List.length imps.(ImpSemantics.memory) then Some (r14, w2n w / 8) else pmap p).
Proof.
  Transparent pmap_ok.
  intros.
  unfold state_rel in*; cleanup.
  unfold pmap_ok in *; intros; unfold mem_inv in *; cleanup.
  unfold state_rel in *; cleanup.
  destruct (p1 =? _) eqn:?; destruct (p2 =? _) eqn:?; cleanup; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; subst; eauto.
  2,3: unfold memory_writable, can_write_mem_at in *; cleanup.
  2,3: exfalso; eapply pmap_ok_impossible; eauto.
  split; eauto.
  unfold w2n in *.
  specialize (Properties.word.unsigned_range w) as ?.
  specialize (Properties.word.unsigned_range base1) as ?.
  specialize (Properties.word.unsigned_range r15) as ?.
  rewrite word.unsigned_ltu, Z.ltb_ge in *.
  rewrite Properties.word.unsigned_sub_nowrap in *; [|lia].
  pat `word.add _ _ = word.add _ _` at rewrite <- Properties.word.unsigned_inj_iff in pat.
  assert(n1 * 8 < Z.to_nat (word.unsigned w) / 8 * 8) as ? by lia.
  rewrite mul_div_id in *; eauto.
  assert(n2 * 8 < Z.to_nat (word.unsigned w) / 8 * 8) as ? by lia.
  rewrite mul_div_id in *; eauto.
  rewrite Properties.word.unsigned_add_nowrap in *.
  2: rewrite Properties.word.unsigned_of_Z_nowrap; try lia.
  rewrite Properties.word.unsigned_add_nowrap in *.
  2: rewrite Properties.word.unsigned_of_Z_nowrap; try lia.
  assert(word.unsigned (word.of_Z (Z.of_nat (n1 * 8)): word64) = word.unsigned (word.of_Z (Z.of_nat (n2 * 8)): word64)) by lia.
  rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia.
  rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia.
Qed.

Lemma mem_inv_alloc: forall pmap s impm r14 r15 w,
  w2n w mod 8 = 0 ->
  w2n w ≠ 0 ->
  memory_writable r14 r15 (memory s) ->
  mem_inv pmap (memory s) impm ->
  pmap_in_memory pmap impm ->
  regs s RAX = Some w ->
  word.ltu r15 r14 = false ->
  word.ltu (word.sub r15 r14) w = false ->
  mem_inv (λ p : nat, if p =? Datatypes.length impm then Some (r14, w2n w / 8) else pmap p) (memory s)
  (impm ++ [repeat None (w2n w / 8)]).
Proof.
  intros.
  Opaque word.add word.sub word.unsigned word.of_Z word.ltu word.eqb.
  unfold mem_inv; intros.
  destruct (p =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; cleanup; subst.
  1: {
    rewrite nth_error_app2 in *; [|reflexivity].
    rewrite Nat.sub_diag, nth_error_0 in *; simpl in *; cleanup.
    rewrite repeat_length.
    eexists; split; eauto; intros.
    assert(nth_error (repeat (@None Value) (w2n w / 8)) off <> None) as Hnth by congruence.
    eapply nth_error_Some in Hnth; rewrite repeat_length in *.
    rewrite nth_error_repeat in *; eauto; cleanup.
    spat `memory_writable` at unfold memory_writable in spat; cleanup.
    assert(can_write_mem_at (memory s) (word.add r14 (word.of_Z (Z.of_nat (off * 8))))).
    1: {
      pat `forall a, _` at eapply pat; clear pat.
      all: repeat (rewrite ?word.unsigned_eqb, ?word.unsigned_ltu, ?Z.eqb_eq, ?Z.ltb_lt, ?Z.ltb_ge in * ).
      unfold w2n in *.
      specialize (Properties.word.unsigned_range w) as ?.
      specialize (Properties.word.unsigned_range r14) as ?.
      specialize (Properties.word.unsigned_range r15) as ?.
      rewrite Properties.word.unsigned_sub_nowrap in *; try lia.
      assert(off * 8 < Z.to_nat (word.unsigned w) / 8 * 8) as ? by lia.
      rewrite mul_div_id in *; eauto.
      pat `off * 8 < _` at rewrite <- Nat2Z.id with (n := off * 8) in pat.
      assert(Z.of_nat (off * 8) < word.unsigned w)%Z by lia.
      rewrite Properties.word.unsigned_add_nowrap in *; try lia.
      2: rewrite Properties.word.unsigned_of_Z_nowrap; try lia.
      assert(word.unsigned w <> 0)%Z by lia.
      repeat (rewrite Properties.word.unsigned_of_Z_nowrap; try lia).
      split; try lia.
      split; try lia.
      rewrite Properties.word.unsigned_modu_nowrap in *; try lia.
      all: rewrite Properties.word.unsigned_of_Z_nowrap; try lia.
      rewrite Properties.word.unsigned_add_nowrap in *; try lia.
      all: rewrite Properties.word.unsigned_of_Z_nowrap; try lia.
      repeat (rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia).
      assert(Z.of_nat (off * 8) = Z.of_nat off * 8)%Z as -> by lia.
      rewrite Z.mod_add; try lia.
    }
    unfold can_write_mem_at in *; cleanup.
    eexists; split; eauto.
    simpl; exact I.
  }
  assert(nth_error (impm ++ [repeat None (w2n w / 8)]) p <> None) by congruence.
  rewrite nth_error_Some, length_app in *; simpl in *.
  rewrite nth_error_app1 in *; try lia.      
  pat `nth_error _ p = _` at rename pat into Hnth.
  spat `mem_inv` at unfold mem_inv in spat; specialize spat with (1 := Hnth); cleanup.
  eexists; split; eauto; intros * Hnthoff.
  pat `forall off xopt, _` at eapply pat in Hnthoff; cleanup.
  eexists; split; eauto; simpl.
  destruct xopt; destruct x0; simpl in *; cleanup; eauto.
  destruct v0; simpl in *; eauto; cleanup.
  destruct (i =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; subst; eauto.
  pat `pmap (List.length _) = _` at rename pat into Hpmap.
  spat `pmap_in_memory` at eapply spat in Hpmap; cleanup.
  assert(nth_error impm (Datatypes.length impm) <> None) as Hnthneq by congruence.
  eapply nth_error_Some in Hnthneq; lia.
Qed.

Lemma memory_writeable_alloc: forall s (r14 r15 w: word64),
  w2n w mod 8 = 0 ->
  w2n w ≠ 0 ->
  regs s RAX = Some w ->
  word.ltu r15 r14 = false ->
  word.ltu (word.sub r15 r14) w = false ->
  memory_writable r14 r15 (memory s) ->
  memory_writable (word.add r14 w) r15 (memory s).
Proof.
  Opaque word.add word.sub word.unsigned word.of_Z word.ltu word.eqb word.modu.
  intros.
  unfold memory_writable in *; cleanup; simpl; eauto; rewrite ?Z.ltb_ge, ?Z.le_lteq, ?Z.ltb_lt, ?Z.eqb_eq in *.
  all: repeat (rewrite ?word.unsigned_eqb, ?word.unsigned_ltu, ?Z.eqb_eq, ?Z.ltb_lt, ?Z.ltb_ge in * ).
  unfold w2n in *.
  specialize (Properties.word.unsigned_range w) as ?.
  specialize (Properties.word.unsigned_range r14) as ?.
  specialize (Properties.word.unsigned_range r15) as ?.
  rewrite Properties.word.unsigned_sub_nowrap in *; try lia.
  repeat (rewrite Properties.word.unsigned_add_nowrap in *; try lia).
  assert(word.unsigned w <> 0)%Z by lia.
  repeat (rewrite Properties.word.unsigned_of_Z_nowrap; try lia).
  split; try lia.
  rewrite Properties.word.unsigned_modu_nowrap in *; try lia.
  all: repeat (rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia).
  repeat (rewrite Properties.word.unsigned_add_nowrap in *; try lia).
  assert (8 = (Z.to_nat 8)) as Htmp by lia; rewrite Htmp in *; clear Htmp.
  pat `Z.to_nat _ mod _ = _` at rewrite <- Znat.Z2Nat.inj_mod in pat; try lia; rewrite <- Z2Nat.inj_0 in pat; eapply Z2Nat.inj in pat; try lia.
  2: specialize Z.mod_pos_bound with (a := word.unsigned w) (b := 8%Z) as ?; try lia.
  rewrite Z.add_mod; try lia.
  pat ` (word.unsigned r14 mod 8 = _)%Z` at rewrite pat.
  pat ` ((word.unsigned w mod 8) = _)%Z` at rewrite pat; simpl.
  split; rewrite ?Zmod_0_l; try reflexivity.
  rewrite Properties.word.unsigned_modu_nowrap in *; try lia.
  all: repeat (rewrite Properties.word.unsigned_of_Z_nowrap in *; try lia).
  split; try lia.
  rewrite Z.eqb_neq in *; split; try lia.
  intros; cleanup.
  pat `forall a, _` at eapply pat.
  all: repeat (rewrite ?word.unsigned_eqb, ?word.unsigned_ltu, ?Z.eqb_eq, ?Z.ltb_lt, ?Z.ltb_ge in * ).
  split; try lia.
  repeat (rewrite Properties.word.unsigned_add_nowrap in *; try lia).
Qed.

Theorem c_cmd_Alloc: forall (n: name) (e: exp) (fuel: nat),
  goal_cmd (ImpSyntax.Alloc n e) fuel.
Proof.
  Transparent c_cmd.
  Transparent eval_cmd.
  unfold goal_cmd; simpl; intros.
  Opaque eval_cmd.
  unfold c_assign, dlet in *.
  destruct (c_exp e) eqn:?.
  simpl in *; cleanup.
  unfold_monadic.
  destruct (eval_exp e) eqn:?.
  destruct o; cleanup.
  2: eval_exp_contr_stop_tac.
  unfold dest_word in *; unfold_outcome.
  destruct v; cleanup; [|congruence].
  unfold alloc in *; unfold_outcome.
  destruct (negb (_ =? _)) eqn:?; cleanup; [congruence|]; simpl in *.
  destruct (w2n w =? 0) eqn:?; cleanup; [congruence|].
  unfold assign in *; unfold_outcome; cleanup.
  pat `eval_exp e _ = _` at specialize eval_exp_pure with (1 := pat) as ?.
  cleanup; subst.
  simpl flatten in *; unfold dlet in *; simpl in *; repeat rewrite list_app_spec in *; repeat rewrite code_in_append in *; cleanup.
  pat `c_exp e _ _ = _` at specialize c_exp_length with (1 := pat) as Htmp; rewrite <- Htmp in *; clear Htmp.
  pat `eval_exp e _ = (?r, _)` at
    assert (r <> Stop Crash) as ? by congruence; specialize c_exp_correct as Htmp1; unfold goal_exp in Htmp1; eapply Htmp1 with (fuel := 0) in pat; unfold exp_res_rel in pat; eauto; clear Htmp1; cleanup.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  try steps_inst_tac.
  simpl code_in in *; cleanup.
  unfold has_stack in *|-; cleanup.
  spat `env_ok` at pose proof spat as ?; unfold env_ok in spat; cleanup.
  rewrite <- index_of_In with (k := 0) in *; rewrite Nat.add_0_l in *.
  spat `state_rel` at unfold state_rel in spat; cleanup.
  spat `code_rel` at pose proof spat as ?; unfold code_rel, init_code_in, init in spat; cleanup.
  remember (Comment ("exit 1") :: _) as init_rest; clear Heqinit_rest.
  unfold code_in in *|-; fold code_in in *|-; cleanup.
  pat `forall (n: N) (params: list N) (body: cmd), _` at clear pat.
  Opaque nth_error.
  Opaque word.add word.sub word.ltu.
  simpl in *; destruct (word.ltu x1 x) eqn:?; cleanup.
  1: { (* word.ltu r15 r14 = true *)
    do 2 eexists; split; simpl.
    1: {
      rewrite Nat.sub_diag.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_call; simpl; eauto.
      unfold allocLoc, set_pc, set_stack; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; simpl; eauto.
      unfold inc, write_reg; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_sub; simpl; eauto; [simpl; reflexivity|..].
      unfold inc, write_reg; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; simpl; eauto; eauto.
      1: econstructor; simpl; eauto.
      unfold inc, write_reg; simpl; pat `word.ltu _ _ = _` at rewrite pat.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_const; eauto.
      unfold write_reg, inc, set_stack; simpl.
      eapply steps_step_same.
      eapply step_exit; simpl; eauto.
      pat `_ = stack s` at rewrite <- pat.
      rewrite length_app, rw_mod_2_even, Nat.even_succ_succ, Nat.even_add, <- Nat.negb_even, negb_true_iff in *.
      do 2 (pat `Nat.even _ = false` at rewrite pat; clear pat); simpl; eauto.
    }
    simpl in *; subst.
    unfold write_reg, set_stack; simpl.
    unfold state_rel in *; cleanup.
    crunch_side_conditions.
    1: pat `_ = output s` at rewrite <- pat; eapply prefix_refl.
  }
  simpl in *; destruct (word.ltu (word.sub x1 x) x0) eqn:?; cleanup.
  1: { (* word.ltu (r15 - r14) rdi = true *)
    do 2 eexists; split; simpl.
    1: {
      rewrite Nat.sub_diag.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_call; simpl; eauto.
      unfold allocLoc, set_pc, set_stack; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; simpl; eauto.
      unfold inc, write_reg; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_sub; simpl; eauto; [simpl; reflexivity|..].
      unfold inc, write_reg; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; simpl; eauto.
      1: econstructor; simpl; eauto.
      pat `word.ltu _ x = _` at rewrite pat.
      unfold set_pc; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; simpl; eauto; eauto.
      1: econstructor; simpl; eauto.
      unfold inc, write_reg; simpl; pat `word.ltu (word.sub _ _) _ = _` at rewrite pat.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_const; eauto.
      unfold write_reg, inc, set_stack; simpl.
      eapply steps_step_same.
      eapply step_exit; simpl; eauto.
      pat `_ = stack s` at rewrite <- pat.
      rewrite length_app, rw_mod_2_even, Nat.even_succ_succ, Nat.even_add, <- Nat.negb_even, negb_true_iff in *.
      do 2 (pat `Nat.even _ = false` at rewrite pat; clear pat); simpl; eauto.
    }
    simpl in *; subst.
    unfold write_reg, set_stack; simpl.
    unfold state_rel in *; cleanup.
    crunch_side_conditions.
    1: pat `_ = output s` at rewrite <- pat; eapply prefix_refl.
  }
  destruct index_of eqn:?; simpl in *; cleanup.
  1: { (* index_of = 0 *)
    do 2 eexists; split; simpl.
    1: {
      rewrite Nat.sub_diag.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_call; simpl; eauto.
      unfold allocLoc, set_pc, set_stack; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; simpl; eauto.
      unfold inc, write_reg; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_sub; simpl; eauto; [simpl; reflexivity|..].
      unfold inc, write_reg; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; simpl; eauto; eauto.
      1: econstructor; simpl; eauto.
      unfold inc, write_reg; simpl; pat `word.ltu _ x = _` at rewrite pat.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; simpl; eauto.
      1: econstructor; simpl; eauto.
      pat `word.ltu (word.sub _ _) _ = _` at rewrite pat.
      unfold set_pc; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_mov; simpl; eauto.
      unfold inc, write_reg; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_add; simpl; eauto; [simpl; reflexivity|..].
      unfold inc, write_reg; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_ret; simpl; eauto.
      unfold set_pc, set_stack; simpl.
      eapply steps_step_same.
      eapply step_pop; simpl; eauto.
      pat `_ = stack s` at rewrite <- pat; pat `curr ++ rest = _ :: _` at rewrite <- pat; reflexivity.
    }
    simpl in *; subst.
    rewrite negb_false_iff in *; rewrite Nat.eqb_eq, Nat.eqb_neq in *.
    split.
    1: instantiate (1 := (fun (p: nat) => if Nat.eqb p (List.length s0.(ImpSemantics.memory)) then Some (x, w2n w / 8) else pmap p)).
    1: eapply pmap_ok_alloc with (t := t) (s := s); eauto.
    assert (pmap_subsume pmap (λ p : nat, if p =? Datatypes.length (ImpSemantics.memory s0) then Some (x, w2n w / 8) else pmap p)).
    1: {
      unfold pmap_subsume; intros.
      destruct (p =? _) eqn:?; eauto.
      rewrite Nat.eqb_eq in *; subst.
      unfold mem_inv in *; cleanup.
      destruct v eqn:?; subst.
      pat `pmap _ = Some _` at pose proof pat as Hpmap.
      spat `pmap_in_memory` at eapply spat in Hpmap; cleanup.
      assert (nth_error s0.(ImpSemantics.memory) (List.length s0.(ImpSemantics.memory)) <> None) as ? by congruence.
      rewrite nth_error_None in *; lia.
    }
    split; eauto.
    unfold write_reg, set_stack; simpl.
    unfold state_rel in *; cleanup.
    repeat (pat `regs s _ = _` at rewrite pat in * ); cleanup.
    destruct curr; cleanup; [simpl odd in *; rewrite Nat.odd_0 in *; congruence|]; rewrite <- app_comm_cons in *.
    crunch_side_conditions.
    1: eapply memory_writeable_alloc; eauto.
    1: { (* r14_mono *)
      Opaque word.add.
      unfold r14_mono in *; intros; cleanup.
      pat `regs s R14 = _` at rewrite pat in *; cleanup.
      rewrite word.unsigned_eqb, word.unsigned_ltu, Z.eqb_eq, Z.ltb_lt, Z.ltb_ge in *.
      specialize (Properties.word.unsigned_range w) as ?.
      specialize (Properties.word.unsigned_range x) as ?.
      specialize (Properties.word.unsigned_range x1) as ?.
      rewrite Properties.word.unsigned_sub_nowrap in *; try lia.
      rewrite Properties.word.unsigned_add_nowrap in *; lia.
    }
    1: eapply pmap_in_bounds_alloc with (t := t) (s := s); eauto.
    1: { (* has_stack *)
      unfold has_stack; do 2 eexists; split; simpl; [|split; eauto].
      pat `_ = stack t` at rewrite <- pat.
      rewrite app_comm_cons; reflexivity.
    }
    1: eapply mem_inv_alloc; eauto.
    1: { (* pmap_in_memory *)
      unfold pmap_in_memory; intros.
      destruct (p =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; cleanup; subst.
      1: {
        rewrite nth_error_app2; [|reflexivity].
        Transparent nth_error.
        eexists; rewrite Nat.sub_diag; simpl.
        reflexivity.
      }
      pat `pmap p = _` at rename pat into Hpmap.
      spat `pmap_in_memory` at eapply spat in Hpmap; cleanup.
      rewrite nth_error_app.
      destruct (_ <? _) eqn:?; [eauto|].
      rewrite Nat.ltb_ge in *.
      assert (nth_error s0.(ImpSemantics.memory) p <> None) by congruence.
      spat `nth_error _ p <> None` at eapply nth_error_Some in spat.
      lia.
    }
    eapply env_ok_replace_head; try (pat `index_of _ _ _  = _` at rewrite pat); eauto.
    all: pat `List.length vs = _` at rewrite ?pat in *; simpl; try lia.
    eexists.
    unfold v_inv in *; cleanup.
    assert (List.length s0.(ImpSemantics.memory) =? List.length s0.(ImpSemantics.memory) = true) as Htmp by (rewrite Nat.eqb_eq; reflexivity); rewrite Htmp; clear Htmp.
    reflexivity.
  }
  destruct curr; cleanup; [simpl odd in *; rewrite Nat.odd_0 in *; congruence|]; rewrite <- app_comm_cons in *; subst.
  (* index_of = S _ *)
  do 2 eexists; split; simpl.
  1: {
    rewrite Nat.sub_diag.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_mov; eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_call; simpl; eauto.
    unfold allocLoc, set_pc, set_stack; simpl.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_mov; simpl; eauto.
    unfold inc, write_reg; simpl.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_sub; simpl; eauto; [simpl; reflexivity|..].
    unfold inc, write_reg; simpl.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump; simpl; eauto; eauto.
    1: econstructor; simpl; eauto.
    unfold inc, write_reg; simpl; pat `word.ltu _ x = _` at rewrite pat.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump; simpl; eauto.
    1: econstructor; simpl; eauto.
    pat `word.ltu (word.sub _ _) _ = _` at rewrite pat.
    unfold set_pc; simpl.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_mov; simpl; eauto.
    unfold inc, write_reg; simpl.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_add; simpl; eauto; [simpl; reflexivity|..].
    unfold inc, write_reg; simpl.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_ret; simpl; eauto.
    unfold set_pc, set_stack; simpl.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_storersp; simpl; eauto.
    1: eapply Nat.lt_trans; eauto; pat `_ = stack s` at rewrite <- pat; rewrite app_comm_cons, length_app; pat `List.length vs = _` at rewrite <- pat.
    1: pat `odd (List.length rest) = true` at eapply odd_is_succ in pat; cleanup; lia.
    1: simpl; reflexivity.
    unfold update_stack; simpl.
    eapply steps_step_same.
    eapply step_pop; simpl; eauto.
    pat `_ = stack s` at rewrite <- pat; pat `_ :: curr ++ rest = _ :: _` at inversion pat; subst.
    reflexivity.
  }
  Opaque nth_error.
  simpl in *; subst.
  rewrite negb_false_iff in *; rewrite Nat.eqb_eq, Nat.eqb_neq in *.
  split.
  1: instantiate (1 := (fun (p: nat) => if Nat.eqb p (List.length s0.(ImpSemantics.memory)) then Some (x, w2n w / 8) else pmap p)).
  1: eapply pmap_ok_alloc with (t := t) (s := s); eauto.
  assert (pmap_subsume pmap (λ p : nat, if p =? Datatypes.length (ImpSemantics.memory s0) then Some (x, w2n w / 8) else pmap p)).
  1: {
    unfold pmap_subsume; intros.
    destruct (p =? _) eqn:?; eauto.
    rewrite Nat.eqb_eq in *; subst.
    unfold mem_inv in *; cleanup.
    destruct v eqn:?; subst.
    pat `pmap _ = Some _` at pose proof pat as Hpmap.
    spat `pmap_in_memory` at eapply spat in Hpmap; cleanup.
    assert (nth_error s0.(ImpSemantics.memory) (List.length s0.(ImpSemantics.memory)) <> None) as ? by congruence.
    rewrite nth_error_None in *; lia.
  }
  split; eauto.
  unfold write_reg, set_stack; simpl.
  unfold state_rel in *; cleanup.
  repeat (pat `regs s _ = _` at rewrite pat in * ); cleanup.
  crunch_side_conditions.
  1: eapply memory_writeable_alloc; eauto.
  1: { (* r14_mono *)
    Opaque word.add.
    unfold r14_mono in *; intros; cleanup.
    pat `regs s R14 = _` at rewrite pat in *; cleanup.
    rewrite word.unsigned_eqb, word.unsigned_ltu, Z.eqb_eq, Z.ltb_lt, Z.ltb_ge in *.
    specialize (Properties.word.unsigned_range w) as ?.
    specialize (Properties.word.unsigned_range x) as ?.
    specialize (Properties.word.unsigned_range x1) as ?.
    rewrite Properties.word.unsigned_sub_nowrap in *; try lia.
    rewrite Properties.word.unsigned_add_nowrap in *; lia.
  }
  1: eapply pmap_in_bounds_alloc with (t := t) (s := s); eauto.
  1: { (* has_stack *)
    unfold has_stack; do 2 eexists; split; simpl; [|split; eauto].
    rewrite list_update_append; [|lia].
    rewrite app_comm_cons; reflexivity.
  }
  1: eapply mem_inv_alloc; eauto.
  1: { (* pmap_in_memory *)
    unfold pmap_in_memory; intros.
    destruct (p =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; cleanup; subst.
    1: {
      rewrite nth_error_app2; [|reflexivity].
      Transparent nth_error.
      eexists; rewrite Nat.sub_diag; simpl.
      reflexivity.
    }
    pat `pmap p = _` at rename pat into Hpmap.
    spat `pmap_in_memory` at eapply spat in Hpmap; cleanup.
    rewrite nth_error_app.
    destruct (_ <? _) eqn:?; [eauto|].
    rewrite Nat.ltb_ge in *.
    assert (nth_error s0.(ImpSemantics.memory) p <> None) by congruence.
    spat `nth_error _ p <> None` at eapply nth_error_Some in spat.
    lia.
  }
  eapply env_ok_replace_list_update; try (pat `index_of _ _ _  = _` at rewrite pat); eauto.
  unfold v_inv in *.
  assert (List.length s0.(ImpSemantics.memory) =? List.length s0.(ImpSemantics.memory) = true) as Htmp by (rewrite Nat.eqb_eq; reflexivity); rewrite Htmp; clear Htmp.
  eexists; reflexivity.
  Unshelve.
  exact ImpSemantics.Abort.
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

Lemma bdrs_vs_length: forall l,
  List.length (bdrs_vs l) = List.length l.
Proof.
  induction l; simpl in *; eauto.
Qed.

Lemma bdrs_vs_spec: forall ns,
  bdrs_vs ns = List.map Some ns.
Proof.
  induction ns; eauto.
Qed.

Lemma binders_ok_all_bdrs: forall c,
  binders_ok c (bdrs_vs (all_bdrs c)).
Proof.
  induction c; simpl in *; unfold dlet in *; simpl in *; eauto.
  all: split.
  all: repeat rewrite list_app_spec in *.
  all: rewrite bdrs_vs_spec.
  all: rewrite map_app.
  1,3: eapply binders_ok_append; eauto.
  all: eapply binders_ok_append2; eauto.
Qed.

Theorem names_in_spec: forall x ns,
  names_in ns x = true <-> In x ns.
Proof.
  induction ns; simpl in *; eauto.
  - split; intros; [congruence|eauto].
  - destruct (_ =? _)%N eqn:?; simpl; eauto.
    + rewrite N.eqb_eq in *; split; eauto.
    + rewrite N.eqb_neq in *.
      split; intros; [rewrite <- IHns|rewrite IHns]; eauto.
      pat `_ \/ _` at destruct H; congruence.
Qed.

Lemma nms_uniq_In: forall ns x acc,
  (In x ns \/ In x acc) -> In x (nms_uniq ns acc).
Proof.
  induction ns; intros; simpl in *; eauto.
  1: pat `_ \/ _` at destruct pat; eauto.
  1: pat `False` at inversion pat.
  destruct (names_in acc a) eqn:?.
  - rewrite names_in_spec in *; cleanup.
    pat `_ \/ _` at destruct pat; eauto.
    pat `_ \/ _` at destruct pat; eauto.
    eapply IHns; subst; eauto.
  - subst.
    eapply IHns; subst; eauto; simpl in *; cleanup.
    pat `_ \/ _` at destruct pat; eauto.
    pat `_ \/ _` at destruct pat; eauto.
Qed.

Lemma binders_ok_nms_uniq: forall c ns,
  binders_ok c (bdrs_vs ns) ->
    binders_ok c (bdrs_vs (nms_uniq ns [])).
Proof.
  induction c; intros; simpl in *; cleanup; eauto.
  all: rewrite bdrs_vs_spec in *.
  all: rewrite in_map_iff in *; cleanup; eexists; split; eauto.
  all: eapply nms_uniq_In; eauto.
Qed.

Theorem binders_ok_bdrs_unq: forall c,
  binders_ok c (bdrs_vs (bdrs_unq c)).
Proof.
  induction c; simpl in *; eauto.
  all: try split.
  all: unfold bdrs_unq, dlet in *; simpl.
  all: eapply binders_ok_nms_uniq.
  all: unfold dlet in *; simpl in *.
  all: repeat rewrite list_app_spec in *.
  all: rewrite bdrs_vs_spec; rewrite map_app.
  1,3: eapply binders_ok_append.
  3,4: eapply binders_ok_append2.
  all: rewrite <- bdrs_vs_spec.
  all: eapply binders_ok_all_bdrs.
Qed.

Lemma binders_ok_In_both: forall c vs vs1,
  binders_ok c vs ->
  (forall n, In (Some n) vs -> In (Some n) vs1) ->
    binders_ok c vs1.
Proof.
  intros.
  induction c; simpl in *; cleanup; eauto.
Qed.

Lemma fltr_nms_spec: forall n l,
  fltr_nms n l = filter (fun x => negb (N.eqb n x)) l.
Proof.
  induction l; eauto; simpl; rewrite IHl.
  destruct (N.eqb n a) eqn:?; simpl; eauto.
Qed.

Lemma rm_nms_not_In: forall l vs n,
  In n vs ->
  ~ In n l ->
    In n (rm_nms l vs).
Proof.
  induction l; eauto; intros; rewrite not_in_cons in *; cleanup.
  simpl; rewrite fltr_nms_spec.
  eapply IHl; eauto.
  rewrite filter_In, negb_true_iff, N.eqb_neq in *.
  split; eauto.
Qed.

Lemma all_In_add_remove: forall l vs n,
  In (Some n) (bdrs_vs vs) ->
    In (Some n) (map Some l ++ bdrs_vs (rm_nms l vs)).
Proof.
  intros.
  rewrite bdrs_vs_spec in *.
  rewrite bdrs_vs_spec with (ns := rm_nms _ _).
  rewrite <- map_app.
  eapply in_map; rewrite in_map_iff in *; cleanup.
  destruct in_dec with (a := n) (l := l); [eapply N.eq_dec|..].
  2: rewrite in_app_iff; right; eapply rm_nms_not_In; eauto.
  rewrite in_app_iff; left; eauto.
Qed.

Lemma binders_ok_add_remove: forall c vs l,
  binders_ok c (bdrs_vs vs) ->
    binders_ok c (map Some l ++ (bdrs_vs (rm_nms l vs))).
Proof.
  intros.
  eapply binders_ok_In_both; eauto.
  intros; eapply all_In_add_remove; eauto.
Qed.

Lemma binders_ok_rev_append: forall c vs1 vs2,
  binders_ok c (vs1 ++ vs2) ->
    binders_ok c (rev vs1 ++ vs2).
Proof.
  induction c; intros; simpl in *; cleanup; eauto.
  all: rewrite in_app_iff in *; cleanup.
  all: spat `_ \/ _` at destruct spat; eauto.
  all: left; rewrite <- in_rev; eauto.
Qed.

Definition ARGS_REGS := [RDI;RDX;RBX;RBP].

Definition write_reg r (w: word64) rgs :=
  (fun r' => if reg_eq_dec r r' then Some w else rgs r').

Fixpoint write_regs ws rs rgs :=
  match ws, rs with
  | w::ws, r::rs => write_reg r w (write_regs ws rs rgs)
  | _, _ => rgs
  end.

Definition pops_regs ws rgs :=
  match ws with
  | [] => rgs
  | _ =>
    write_regs ws (rev (firstn (List.length ws - 1) ARGS_REGS)) rgs
  end.

Lemma pops_thm: forall t fs ds ws rest r15 (xs: list exp) (vs: v_stack) fuel,
  has_stack t (map Word (rev ws) ++ rest) ->
  code_in t.(pc) (flatten (c_pops xs vs)) t.(instructions) ->
  code_rel fs ds t.(instructions) ->
  t.(regs) R15 = Some r15 ->
  List.length xs = List.length ws ->
  even_len rest = true ->
  ∃outcome,
    steps (State t, fuel) outcome ∧
    match outcome with
    | (Halt ec out, _) => t.(output) = out ∧ ec = (word.of_Z 4)
    | (State t1, fuel1) =>
      fuel1 = fuel ∧ List.length ws ≤ 5 ∧
      t1 = set_pc (t.(pc) + List.length (flatten (c_pops xs vs))) (
        set_stack rest (
          set_regs (pops_regs ws t.(regs)) t
        )
      )
    end.
Proof.
  intros.
  unfold c_pops, dlet, pops_regs in *.
  repeat (rewrite list_len_spec in * ).
  unfold has_stack in *; cleanup.
  unfold ARGS_REGS, set_stack, set_pc.
  destruct xs eqn:?; simpl in *; subst; cleanup.
  1: {
    destruct ws eqn:?; simpl in *; try congruence; subst.
    eexists; split.
    1: {
      eapply steps_step_same.
      eapply step_push; eauto.
    }
    unfold set_stack.
    simpl.
    crunch_side_conditions.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    cleanup.
    eexists; split.
    1: eapply steps_refl.
    unfold set_stack.
    simpl.
    crunch_side_conditions.
    rewrite Nat.add_0_r.
    destruct t; simpl in *.
    reflexivity.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    cleanup.
    eexists; split.
    1: {
      eapply steps_step_same.
      eapply step_pop; eauto.
    }
    unfold set_stack.
    simpl.
    crunch_side_conditions.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    cleanup.
    eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      unfold set_stack, write_reg, inc; simpl.
      eapply steps_step_same.
      eapply step_pop; eauto.
      simpl; reflexivity.
    }
    unfold set_stack.
    simpl.
    rewrite <- Nat.add_assoc; simpl.
    crunch_side_conditions.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    cleanup.
    eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      unfold set_stack, write_reg, inc; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      1: simpl; reflexivity.
      unfold set_stack, write_reg, inc; simpl.
      eapply steps_step_same.
      eapply step_pop; eauto.
      simpl; reflexivity.
    }
    unfold set_stack.
    simpl.
    repeat (rewrite <- Nat.add_assoc; simpl).
    crunch_side_conditions.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    cleanup.
    eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      unfold set_stack, write_reg, inc; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      1: simpl; reflexivity.
      unfold set_stack, write_reg, inc; simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_pop; eauto.
      1: simpl; reflexivity.
      unfold set_stack, write_reg, inc; simpl.
      eapply steps_step_same.
      eapply step_pop; eauto.
      simpl; reflexivity.
    }
    unfold set_stack.
    simpl.
    repeat (rewrite <- Nat.add_assoc; simpl).
    crunch_side_conditions.
  }
  unfold ImpToASMCodegen.give_up in *; simpl in *; cleanup.
  spat `List.length ?l` at destruct l; simpl in *; try congruence.
  Opaque nth_error.
  unfold code_rel, init_code_in, init in *; simpl in *; cleanup.
  pat `forall _, _` at clear pat.
  destruct (even_len l) eqn:?.
  1: {
    eexists; split.
    1: {
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_jump; eauto.
      1: econstructor.
      simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto.
      simpl.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_const; eauto.
      eapply steps_step_same.
      eapply step_exit; simpl; eauto.
      rewrite rw_mod_2_even.
      repeat (rewrite ?even_len_spec, ?odd_len_spec in * ).
      assert (List.length (map Word (rev ws) ++ rest) = List.length (Word x :: stack t)).
      1: pat `_ = _ :: _` at rewrite <- pat; reflexivity.
      rewrite length_app, length_map, length_rev in *; simpl List.length in *.
      spat `List.length t.(stack)` at rewrite <- spat.
      rewrite Nat.even_add, eqb_true_iff.
      pat `_ = List.length ws` at rewrite <- pat.
      pat `even (List.length rest) = _` at rewrite pat.
      rewrite Nat.even_succ_succ; eauto.
    }
    simpl; split; eauto.
  }
  eexists; split.
  1: {
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_jump; eauto.
    1: econstructor.
    simpl.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_const; eauto.
    eapply steps_step_same.
    eapply step_exit; simpl; eauto.
    rewrite rw_mod_2_even.
    repeat (rewrite ?even_len_spec, ?odd_len_spec in * ).
    assert (List.length (map Word (rev ws) ++ rest) = List.length (Word x :: stack t)).
    1: pat `_ = _ :: _` at rewrite <- pat; reflexivity.
    rewrite length_app, length_map, length_rev in *; simpl List.length in *.
    rewrite <- Nat.odd_succ.
    spat `List.length t.(stack)` at rewrite <- spat.
    rewrite Nat.odd_add.
    repeat (rewrite <- Nat.negb_even).
    pat `even (List.length rest) = _` at rewrite pat.
    pat `_ = List.length ws` at rewrite <- pat.
    rewrite Nat.even_succ_succ.
    pat `even (List.length l) = _` at rewrite pat.
    simpl; eauto.
  }
  simpl; split; eauto.
Qed.

Lemma list_rel_length_same : forall [A B] (R: A -> B -> Prop) l l1,
  list_rel R l l1 -> List.length l = List.length l1.
Proof.
  induction l; intros; simpl in *; eauto; cleanup.
  all: destruct l1; simpl in *; cleanup; eauto.
Qed.

Ltac crunch_ienv :=
  repeat match goal with
  | _ => progress eauto
  | _ => progress cleanup
  | H : IEnv.lookup (IEnv.insert (?n, _) _) ?n = _ |- _ =>
    rewrite IEnv.lookup_insert_eq in H
  | H : IEnv.lookup (IEnv.insert (?n1, _) _) ?n2 = _, H1: ?n1 <> ?n2 |- _ =>
    rewrite IEnv.lookup_insert_neq in H
  | H: IEnv.lookup IEnv.empty ?n = _ |- _ =>
    rewrite IEnv.lookup_empty in H
  | H: IEnv.lookup (IEnv.insert (?n1, _) _) ?n2 = _ |- _ =>
    destruct (N.eqb n1 n2) eqn:?; rewrite ?N.eqb_eq, ?N.eqb_neq in *; subst; cleanup
  | _ =>
    solve [crunch_side_conditions; spat `_ = w` at rewrite <- spat; simpl; eauto; congruence]
  end.

Lemma pushes_thm: forall t fs s fuel params args ws rest pos c vs1 l1 w rgs pmap, 
  c_pushes params pos = (c, vs1, l1) ->
  code_in t.(pc) (flatten c) t.(instructions) ->
  t.(regs) = pops_regs ws rgs ->
  t.(stack) = rest -> List.length params ≤ 5 ->
  t.(regs) RAX = Some w ->
  (ws ≠ [] -> List.last ws (word.of_Z 0) = w) ->
  list_rel (v_inv pmap) args ws ->
  List.length ws = List.length params ->
  state_rel fs s t ->
  ∃ new_curr t5,
    steps (State t, fuel) (State t5, fuel) ∧
    t5.(pc) = t.(pc) + List.length (flatten c) ∧
    l1 = pos + List.length (flatten c) ∧
    has_stack t5 (new_curr ++ rest) ∧
    env_ok (make_env params args IEnv.empty) vs1 new_curr pmap ∧
    state_rel fs s t5 ∧
    t5.(instructions) = t.(instructions) ∧
    r14_mono (regs t R14) (regs t5 R14)  ∧
    t5.(memory) = t.(memory) ∧
    vs1 = push_vs params.
Proof.
  Transparent nth_error.
  intros.
  unfold c_pushes, dlet, pops_regs in *.
  repeat (rewrite list_len_spec in * ).
  destruct params eqn:?; simpl in *; subst; cleanup.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    spat `list_rel _ _ _` at specialize list_rel_length_same with (1 := spat) as ?; subst.
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence); cleanup.
    exists [Word w]; eexists; split.
    1: eapply steps_refl.
    crunch_side_conditions.
    unfold env_ok; crunch_side_conditions.
    intros; rewrite IEnv.lookup_empty in *; congruence.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; cleanup.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    spat `list_rel _ _ _` at specialize list_rel_length_same with (1 := spat) as ?; subst.
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence); cleanup.
    exists [Word w]; eexists; split.
    1: eapply steps_refl.
    crunch_side_conditions.
    unfold env_ok; crunch_side_conditions; intros.
    crunch_ienv.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; cleanup.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    spat `list_rel _ _ _` at specialize list_rel_length_same with (1 := spat) as ?; subst.
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence); cleanup.
    exists [Word w; Word w0]; eexists; split.
    1: {
      eapply steps_step_same.
      eapply step_push; eauto.
      unfold inc, write_reg in *; simpl in *.
      pat `regs t = _` at rewrite pat; simpl; reflexivity.
    }
    crunch_side_conditions.
    unfold env_ok; crunch_side_conditions; intros.
    crunch_ienv.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; cleanup.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    spat `list_rel _ _ _` at specialize list_rel_length_same with (1 := spat) as ?; subst.
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence); cleanup.
    exists [Word w; Word w1; Word w0]; eexists; split.
    1: {
      unfold inc, write_reg in *; simpl in *.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto.
      1: pat `regs t = _` at rewrite pat; simpl; reflexivity.
      eapply steps_step_same.
      eapply step_push; eauto; simpl.
      pat `regs t = _` at rewrite pat; simpl; reflexivity.
    }
    crunch_side_conditions.
    unfold env_ok; crunch_side_conditions; intros.
    crunch_ienv.
  }
  destruct (List.length _ =? _) eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; cleanup.
  1: {
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
    spat `list_rel _ _ _` at specialize list_rel_length_same with (1 := spat) as ?; subst.
    repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence); cleanup.
    exists [Word w; Word w2; Word w1; Word w0]; eexists; split.
    1: {
      unfold inc, write_reg in *; simpl in *.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto.
      1: pat `regs t = _` at rewrite pat; simpl; reflexivity.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_push; eauto; simpl.
      1: pat `regs t = _` at rewrite pat; simpl; reflexivity.
      eapply steps_step_same.
      eapply step_push; eauto; simpl.
      pat `regs t = _` at rewrite pat; simpl; reflexivity.
    }
    crunch_side_conditions.
    unfold env_ok; crunch_side_conditions; intros.
    crunch_ienv.
  }
  repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence; try lia).
  spat `list_rel _ _ _` at specialize list_rel_length_same with (1 := spat) as ?; subst.
  repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence; try lia); cleanup.
  exists [Word w; Word w3; Word w2; Word w1; Word w0]; eexists; split.
  1: {
    unfold inc, write_reg in *; simpl in *.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_push; eauto.
    1: pat `regs t = _` at rewrite pat; simpl; reflexivity.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_push; eauto; simpl.
    1: pat `regs t = _` at rewrite pat; simpl; reflexivity.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_push; eauto; simpl.
    1: pat `regs t = _` at rewrite pat; simpl; reflexivity.
    eapply steps_step_same.
    eapply step_push; eauto; simpl.
    pat `regs t = _` at rewrite pat; simpl; reflexivity.
  }
  crunch_side_conditions.
  unfold env_ok; crunch_side_conditions; intros.
  crunch_ienv.
  crunch_side_conditions.
  eauto 6.
Qed.

Theorem eval_exps_length: forall xs s args s1,
  eval_exps xs s = (Cont args,s1) ->
    List.length args = List.length xs.
Proof.
  induction xs; simpl; unfold_monadic; intros; cleanup; simpl; eauto.
  destruct eval_exp eqn:?.
  spat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  destruct eval_exps eqn:?.
  spat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  simpl; eauto.
Qed.

Theorem list_rel_length: forall [A B] (R: A -> B -> Prop) (xs: list A) (ys: list B),
  list_rel R xs ys ->
  List.length xs = List.length ys.
Proof.
  induction xs; destruct ys; simpl; intros; cleanup; simpl; eauto.
Qed.

Theorem pops_regs_rw: forall ws rgs,
  pops_regs ws rgs RAX = rgs RAX ∧
  pops_regs ws rgs R12 = rgs R12 ∧
  pops_regs ws rgs R13 = rgs R13 ∧
  pops_regs ws rgs R14 = rgs R14 ∧
  pops_regs ws rgs R15 = rgs R15.
Proof.
  unfold pops_regs; intros.
  destruct ws eqn:?; simpl; repeat split.
  all: destruct rev eqn:?; simpl; eauto.
  all: unfold ARGS_REGS in *; rewrite Nat.sub_0_r in *; subst.
  all: repeat (spat `List.length ?l` at destruct l; simpl in *; try congruence).
  all: pat `_ = _ :: _` at inversion pat; simpl; reflexivity.
Qed.

Lemma index_of_app_greater: forall vs1 vs2 n k,
  index_of vs1 n k <= index_of (vs1 ++ vs2) n k.
Proof.
  induction vs1; intros; simpl; [rewrite index_of_spec; lia|].
  destruct a; simpl; eauto.
  destruct (n0 =? n)%N eqn:?; [lia|].
  eauto.
Qed.

Lemma index_of_app_r: forall vs1 vs2 n k,
  List.length vs1 + k <= index_of vs1 n k ->
    index_of (vs1 ++ vs2) n k = index_of vs2 n (k + List.length vs1).
Proof.
  induction vs1; intros; simpl in *; unfold dlet in *; simpl in *; eauto.
  destruct a; simpl.
  all: assert (S (List.length vs1) = 1 + List.length vs1) as HS by lia; rewrite HS in *.
  all: rewrite Nat.add_assoc in *.
  2: eapply IHvs1; lia.
  destruct (n0 =? n)%N eqn:?; rewrite ?Nat.eqb_eq, ?Nat.eqb_neq in *; subst; try lia.
  eapply IHvs1; lia.
Qed.

Lemma env_ok_append_l: forall env vs1 vs2 pmap curr1 curr2,
  env_ok env vs2 curr2 pmap ->
  List.length vs1 = List.length curr1 ->
  (forall n, In n vs2 -> ~ In n vs1) ->
    env_ok env (vs1 ++ vs2) (curr1 ++ curr2) pmap.
Proof.
  intros.
  unfold env_ok in *; intros; cleanup.
  split; [repeat rewrite length_app; lia|].
  intros.
  pat `IEnv.lookup _ _ = _` at rename pat into Hlookup.
  spat `IEnv.lookup _ _ = _ -> _` at specialize spat with (1 := Hlookup) as ?; cleanup.
  pat `forall _, _` at specialize pat with (n := Some n).
  assert (~ In (Some n) vs1); eauto.
  split.
  1: eapply in_or_app; eauto.
  eexists; split; eauto.
  pat `In _ _ -> _` at clear pat.
  pat `In _ vs2` at rewrite <- index_of_In with (k := List.length vs1) in pat.
  pat `~ In _ vs1` at rewrite <- index_of_In with (k := 0) in pat; rewrite Nat.add_0_l in pat; rewrite Nat.nlt_ge in pat.
  rewrite nth_error_app2.
  2: {
    pat `List.length vs1 = _` at rewrite <- pat; simpl.
    eapply Nat.le_trans; eauto.
    eapply index_of_app_greater; eauto.
  }
  specialize index_of_app_greater with (vs1 := vs1) (vs2 := vs2) (n := n) (k := List.length vs1) as ?.
  rewrite index_of_app_r; try lia.
  pat `List.length vs1 = _` at rewrite <- pat; simpl.
  rewrite index_of_spec.
  rewrite Nat.add_comm, <- Nat.add_sub_assoc, Nat.sub_diag, Nat.add_0_r; eauto.
Qed.

Lemma env_ok_append_r: forall env vs1 vs2 pmap curr1 curr2,
  env_ok env vs1 curr1 pmap ->
  List.length vs2 = List.length curr2 ->
    env_ok env (vs1 ++ vs2) (curr1 ++ curr2) pmap.
Proof.
  intros.
  unfold env_ok in *; intros; cleanup.
  split; [repeat rewrite length_app; lia|].
  intros.
  pat `IEnv.lookup _ _ = _` at rename pat into Hlookup.
  spat `IEnv.lookup _ _ = _ -> _` at specialize spat with (1 := Hlookup) as ?; cleanup.
  split; [eapply in_or_app; eauto|].
  eexists; split; eauto.
  (* pat `In _ _ -> _` at clear pat. *)
  pat `In _ vs1` at rewrite <- index_of_In with (k := 0) in pat; rewrite Nat.add_0_l in pat.
  rewrite <- index_of_app; eauto.
  (* pat `~ In _ vs1` at rewrite <- index_of_In with (k := 0) in pat; rewrite Nat.add_0_l in pat; rewrite Nat.nlt_ge in pat. *)
  rewrite nth_error_app1.
  2: pat `List.length vs1 = _` at rewrite <- pat; simpl; eauto.
  eauto.
Qed.

Lemma steps_done_set_vars: forall s vars,
  steps_done (set_vars vars s) = steps_done s.
Proof.
  destruct s; simpl; reflexivity.
Qed.

Lemma call_vs_spec: forall vs acc,
  call_vs vs acc = rev (map Some vs) ++ acc.
Proof.
  induction vs; intros; simpl in *; eauto.
  rewrite <- app_assoc; eauto.
Qed.

Lemma hd_app: forall [A] (l1 l2: list A) (d: A),
  l1 <> nil ->
    hd d (l1 ++ l2) = hd d l1.
Proof.
  destruct l1; intros; simpl in *; try congruence; eauto.
Qed.

Lemma last_eq_head_rev: forall [A] (l: list A) (d: A),
  List.last l d = hd d (rev l).
Proof.
  induction l; intros; simpl; eauto.
  Opaque last.
  destruct l; simpl; eauto.
  rewrite IHl; simpl; eauto.
  symmetry; rewrite hd_app; eauto.
  destruct (rev l); simpl; congruence.
Qed.

Theorem c_cmd_Call: forall (n: name) (f: name) (es: list exp) (fuel: nat)
  (IH: ∀ m : nat, m < fuel → ∀ c : cmd, goal_cmd c m),
  goal_cmd (ImpSyntax.Call n f es) fuel.
Proof.
  Transparent c_cmd.
  intros.
  unfold goal_cmd; simpl; intros.
  spat `eval_cmd` at specialize eval_cmd_mono with (1 := spat) as ?.
  spat `eval_cmd` at specialize eval_cmd_steps_done_steps_up with (1 := spat) as ?.
  Transparent eval_cmd.
  simpl in *.
  Opaque eval_cmd.
  unfold dlet in *.
  destruct (c_exps es) eqn:?.
  simpl in *; cleanup.
  unfold_monadic.
  destruct (eval_exps es) eqn:?.
  destruct o; cleanup.
  2: eval_exps_contr_stop_tac.
  unfold get_vars in *; unfold_outcome.
  unfold get_body_and_set_vars, assign in *; unfold_outcome.
  destruct find_fun eqn:?; unfold_outcome; simpl in *; unfold dlet in *; simpl in *.
  2: congruence.
  pat `find_fun _ _ = Some ?p` at destruct p.
  destruct (_ || _) eqn:?.
  1: congruence.
  spat `match ?s with _ => _ end` at destruct s eqn:?; cleanup; subst.
  unfold catch_return in *; unfold_outcome.
  destruct EVAL_CMD eqn:?.
  unfold set_varsM in *; unfold_outcome; cleanup.
  repeat (rewrite ?list_app_spec, ?appl_len_spec in * ).
  pat `eval_exps _ _ = _` at specialize eval_exps_pure with (1 := pat) as ?; subst.
  repeat (rewrite code_in_append in * ); cleanup.
  spat `eval_exps` at specialize eval_exps_length with (1 := spat) as ?.
  pat `eval_exps es _ = (?r, _)` at
    assert (r <> Stop Crash) as ? by congruence; specialize c_exps_correct as Htmp1; unfold goal_exps in Htmp1; eapply Htmp1 with (fuel := s1.(steps_done) - s0.(steps_done)) in pat; unfold exp_res_rel in pat; eauto; clear Htmp1; cleanup.
  pat `c_exps _ _ _ = _` at specialize c_exps_length with (1 := pat) as Htmp; rewrite Htmp in *; clear Htmp.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  unfold exps_res_rel in *; cleanup.
  try steps_inst_tac.
  rewrite orb_false_iff in *; cleanup.
  rewrite negb_false_iff, Nat.eqb_eq in *.
  pat `pc s = pc t + _` at rewrite <- pat in *.
  unfold state_rel in *|-; cleanup.
  spat `list_rel` at specialize list_rel_length with (1 := spat) as ?; subst.
  pat `has_stack _ (map Word (rev _) ++ _)` at pose proof pat as ?; eapply pops_thm in pat; eauto; try congruence; cleanup.
  2:{
    rewrite even_len_spec.
    rewrite length_app, Nat.even_add.
    repeat (rewrite <- Nat.negb_odd).
    pat `odd (List.length curr) = _` at rewrite pat.
    pat `odd (List.length rest) = _` at rewrite pat.
    now simpl.
  }
  destruct c_assign eqn:?.
  simpl in *; cleanup.
  spat `let (_, _) := ?x in _` at destruct x.
  spat `match ?s with _ => _ end` at destruct s eqn:?; simpl in *; cleanup; subst.
  2: {
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eauto.
      eauto.
    }
    simpl in *.
    crunch_side_conditions.
    congruence.
  }
  spat `code_rel` at pose proof spat as ?; unfold code_rel in spat; cleanup.
  pat `find_fun _ _ = Some _` at rename pat into Hfind_fun.
  pat `forall n params body, _` at specialize pat with (1 := Hfind_fun); cleanup; subst.
  destruct c_fundef eqn:?.
  simpl c_fundef in *; unfold dlet in *; cleanup.
  destruct c_pushes eqn:?.
  pat `c_pushes _ _ = (?p, _)` at destruct p.
  unfold c_bdrs in *|-; unfold dlet in *; simpl in *; cleanup.
  remember (vs_bdrs _ _) as vs_body.
  simpl in *; unfold dlet in *; simpl in *.
  repeat (rewrite ?list_app_spec, ?appl_len_spec, ?list_len_spec, ?length_app in * ).
  destruct c_cmd eqn:?.
  repeat (rewrite code_in_append in * ); cleanup; simpl in *; cleanup.
  unfold has_stack in *; cleanup.
  specialize pops_regs_rw with (ws := x) (rgs := regs s) as ?; cleanup.
  spat `c_pushes` at pose proof spat as Htmp; eapply pushes_thm with 
    (t := (set_pc _ (set_stack (map (λ _ : option N, Uninit) vs_body ++ (RetAddr (pc s + Datatypes.length (flatten (c_pops es vs)) + 1) :: curr ++ rest)) (set_regs (pops_regs x s.(regs)) s))))
    (fuel := s1.(steps_done) - s0.(steps_done) - 1) in Htmp; simpl; cleanup.
  6: pat `regs s RAX = _` at rewrite <- pat in *; cleanup; eauto.
  all: eauto; try lia.
  2: {
    intros.
    destruct (rev x) eqn:?; simpl in *; try congruence.
    1: destruct x; simpl in *; cleanup; try congruence; pat `_ ++ _ = []` at eapply app_eq_nil in pat; cleanup; congruence.
    pat `Word _ :: _ = Word _ :: _` at inversion pat; subst; simpl; eauto.
    rewrite last_eq_head_rev; pat `rev _ = _` at rewrite pat; simpl; eauto.
  }
  2: crunch_side_conditions.
  all: try (lazymatch goal with
  | H: pops_regs _ (regs ?s) ?r = _ |- pops_regs _ (regs ?s) ?r = _ => rewrite H; eauto
  end).
  destruct fuel.
  1: { (* fuel = 0 *)
    with_strategy transparent [EVAL_CMD] unfold EVAL_CMD in *; unfold_outcome; cleanup.
    rewrite Nat.sub_diag in *.
    unfold has_stack in *; cleanup.
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_call; simpl; eauto.
      simpl in *.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_sub_rsp; simpl; eauto.
      unfold set_stack; simpl; eauto.
    }
    simpl in *.
    crunch_side_conditions.
    all: pat `pops_regs _ _ R14 = _` at rewrite pat in *; eauto.
    eapply r14_mono_IMP_pmap_in_bounds; eauto.
    crunch_side_conditions.
  }
  (* fuel > 0 *)
  with_strategy transparent [EVAL_CMD] unfold EVAL_CMD in *; fold EVAL_CMD in *; unfold_outcome; cleanup.
  unfold_monadic; unfold inc_steps_done in *; unfold_outcome.
  simpl in *.
  pat `eval_cmd _ _ _ = (?o, _)` at assert (o <> Stop Crash).
  1: {
    pat `match ?s with _ => _ end = _` at destruct s; cleanup; subst.
    all: pat `match ?s with _ => _ end = _` at destruct s; cleanup; subst; try congruence.
    all: pat `match ?v with _ => _ end = _` at destruct v; cleanup; try congruence.
  }
  (* spat `c_cmd _ ?fl` at assert (fl = pc (set_pc fl x9)) as Htmp by (simpl; lia); rewrite Htmp in spat; clear Htmp. *)
  spat `eval_cmd` at rename spat into Heval_cmd.
  pat `has_stack x9 ?st` at remember st as x9_full_stack.
  specialize eval_cmd_steps_done_steps_up with (1 := Heval_cmd) as ?.
  specialize IH with (m := fuel).
  unfold goal_cmd in IH; eapply IH with
    (t := x9)
    (curr := x8 ++ map (λ _ : option N, Uninit) vs_body) (rest := RetAddr _ :: curr ++ rest) in Heval_cmd; clear IH; simpl; eauto; cleanup.
  all: simpl; pat `pops_regs x _ R14 = _` at rewrite pat in *; eauto.
  all: pat `pc x9 = _` at rewrite <- pat in *.
  2: subst; eauto.
  5: pat `memory x9 = _` at rewrite <- pat in *; eauto.
  (* pmap_in_bounds *)
  5: eapply r14_mono_IMP_pmap_in_bounds; eauto; eapply r14_mono_trans; solve [eauto].
  (* code_in *)
  7: pat `steps _ (State x9, _)` at simpl; specialize steps_instructions with (1 := pat) as Htmp; simpl in Htmp; rewrite <- Htmp in *; subst; solve [eauto].
  3: { (* binders_ok *)
    pat `l0 = _` at rewrite pat in *.
    Opaque call_vs rm_nms.
    unfold vs_bdrs in *; unfold dlet in *; simpl in *; rewrite ?list_app_spec.
    destruct l; unfold push_vs; destruct even_len; simpl in *; unfold dlet in *; simpl in *.
    all: try eapply binders_ok_append2 with (b1 := [None]).
    all: try eapply binders_ok_append with (b2 := [None]).
    all: try (rewrite app_assoc; eapply binders_ok_append with (b2 := [None])).
    all: rewrite ?call_vs_spec, ?app_nil_r.
    all: try eapply binders_ok_rev_append.
    all: try eapply binders_ok_add_remove.
    all: try eapply binders_ok_bdrs_unq.
  }
  (* env_ok*)
  2: eapply env_ok_append_r; eauto; rewrite ?length_map; simpl; subst; solve [eauto].
  2: { (* has_stack *)
    pat `l0 = _` at rewrite pat in *.
    simpl; eapply has_stack_set_pc.
    unfold has_stack in *; simpl in *; cleanup.
    subst x9_full_stack.
    do 2 eexists; rewrite <- app_assoc; repeat (split; eauto).
  }
  2:{
    rewrite length_app, Nat.odd_succ, Nat.even_add; do 2 rewrite <- Nat.negb_odd.
    pat `odd (List.length curr) = _` at rewrite pat.
    pat `odd (List.length rest) = _` at rewrite pat.
    simpl; eauto.
  }
  2: {
    subst vs_body l0.
    unfold env_ok in *; cleanup.
    rewrite length_app, length_map, bdrs_vs_spec in *; simpl.
    unfold vs_bdrs in *; unfold dlet in *; simpl in *; rewrite ?list_app_spec, ?even_len_spec in *.
    destruct even eqn:?; rewrite ?length_map, ?length_app, ?length_map in *; simpl.
    all: pat `_ = List.length x8` at rewrite <- pat; simpl in *.
    all: rewrite ?length_map, ?length_app, ?length_map in *; simpl in *.
    all: try rewrite Nat.add_assoc, Nat.add_1_r, Nat.odd_succ in *; eauto.
    rewrite <- Nat.negb_even; pat `even _ = false` at rewrite pat; eauto.
  }
  pat `let (_, _) := ?x in _` at destruct x.
  assert (s1.(steps_done) = s3.(steps_done)) as Hsdeq; [|rewrite <- Hsdeq in *].
  1: {
    all: repeat (pat `match ?s with _ => _ end = _` at destruct s; cleanup; subst; try congruence).
    unfold set_varsM in *; simpl in *; cleanup; destruct s2; simpl in *; try congruence.
  }
  unfold add_steps_done, set_steps_done in *; rewrite steps_done_set_vars in *; simpl in *; rewrite Nat.sub_add_distr in *.
  destruct (s1.(steps_done) - s0.(steps_done)) eqn:?.
  1: {
    pat `_ + 1 <= _` at eapply Nat.le_add_le_sub_l in pat.
    pat `s1.(steps_done) - s0.(steps_done) = _` at rewrite pat in *; lia.
  }
  simpl in *; rewrite Nat.sub_0_r in *.
  pat `match ?s with _ => _ end` at destruct s; cleanup; subst.
  2: { (* Halt *)
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_succ.
      1: eapply step_call; simpl; eauto.
      simpl in *.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_sub_rsp; simpl; eauto.
      unfold set_stack; simpl.
      eapply steps_trans.
      1: eauto.
      eauto.
    }
    simpl in *.
    crunch_side_conditions.
    eapply prefix_trans; eauto.
    all: repeat (pat `match ?s with _ => _ end = _` at destruct s; cleanup; subst; try congruence).
    all: try eapply prefix_refl.
  }
  (* State *)
  unfold cmd_res_rel in *|-; cleanup.
  pat `match ?o with _ => _ end` at destruct o; cleanup; subst; [congruence|].
  pat `match ?v with _ => _ end` at destruct v; cleanup; subst; try congruence.
  2: { (* TimeOut *)
    do 2 eexists; split.
    1: {
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eauto.
      eapply steps_trans.
      1: eapply steps_step_succ.
      1: eapply step_call; simpl; eauto.
      simpl in *.
      eapply steps_trans.
      1: eapply steps_step_same.
      1: eapply step_sub_rsp; simpl; eauto.
      unfold set_stack; simpl.
      eapply steps_trans.
      1: eauto.
      eauto.
    }
    simpl in *.
    crunch_side_conditions.
  }
  (* Return v *)
  pat `steps _ (State s4, _)` at specialize steps_instructions with (1 := pat) as ?.
  destruct curr as [|h curr1] eqn:?; simpl in *; rewrite ?Nat.odd_0 in *; [congruence|].
  pat `h :: _ ++ _ = _ :: _` at inversion pat; simpl in *; subst.
  spat `c_assign` at eapply c_assign_thm with
    (t := (set_pc (pc s + Datatypes.length (flatten (c_pops es vs)) + 1) (set_stack (_ ++ rest) s4)))
    (h := x6) (curr := curr1) (rest := rest) (s := set_vars _ _) (fuel := 0)
    in spat; simpl; eauto; cleanup.
  3: { (* code_in *)
    pat `_ = instructions s4` at rewrite <- pat.
    pat `instructions x9 = instructions s` at rewrite pat.
    rewrite <- Nat.add_assoc; eauto.
  }
  2: eapply env_ok_pmap_subsume; eauto.
  2: { (* has_stack *)
    eapply has_stack_set_pc.
    unfold has_stack in *; simpl in *; cleanup.
    do 2 eexists; rewrite app_comm_cons; do 2 (split; eauto).
  }
  2: crunch_side_conditions.  
  do 2 eexists; split.
  1: {
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_succ.
    1: eapply step_call; simpl; eauto.
    simpl in *.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_sub_rsp; simpl; eauto.
    unfold set_stack; simpl.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eauto.
    eapply steps_trans.
    1: eapply steps_step_same.
    1: eapply step_ret; eauto.
    1: unfold has_stack in *; cleanup; eauto.
    eauto.
  }
  simpl in *.
  crunch_side_conditions.
  Unshelve.
  all: eauto.
Qed.

Theorem c_cmd_correct : forall (fuel: nat) (c: cmd),
  goal_cmd c fuel.
Proof.
  induction fuel using lt_wf_ind; induction c.
  all: repeat lazymatch goal with
  | |- goal_cmd Skip _ => eapply c_cmd_Skip
  | |- goal_cmd (Seq _ _) _ => eapply c_cmd_Seq; eauto
  | |- goal_cmd (Assign _ _) _ => eapply c_cmd_Assign; eauto
  | |- goal_cmd (While _ _) _ => eapply c_cmd_While; eauto
  | |- goal_cmd ImpSyntax.Abort _ => eapply c_cmd_Abort
  | |- goal_cmd (ImpSyntax.Update _ _ _) _ => eapply c_cmd_Update; eauto
  | |- goal_cmd (ImpSyntax.If _ _ _) _ => eapply c_cmd_If; eauto
  | |- goal_cmd (ImpSyntax.Return _) _ => eapply c_cmd_Return; eauto
  | |- goal_cmd (ImpSyntax.GetChar _) _ => eapply c_cmd_GetChar; eauto
  | |- goal_cmd (ImpSyntax.PutChar _) _ => eapply c_cmd_PutChar; eauto
  | |- goal_cmd (Alloc _ _) _ => eapply c_cmd_Alloc; eauto
  | |- goal_cmd (ImpSyntax.Call _ _ _) _ => eapply c_cmd_Call; eauto
  end.
Qed.

(* Definition init_state_ok_def (t: ASMSemantics.state) (input: llist ascii) (asm: asm) :=
  ∃r14 r15,
    t.(pc) = 0 ∧ t.(instructions) = asm ∧
    t.(ASMSemantics.input) = input ∧ t.(output) = EmptyString ∧
    t.(stack) = [] ∧
    t.(regs) R14 = Some r14 ∧
    t.(regs) R15 = Some r15 ∧
    memory_writable r14 r15 t.(memory).

Definition asm_terminates (input: llist ascii) (asm: asm) (fuel: nat) (output: string) :=
  exists t fuel_left,
    init_state_ok t input asm /\
      steps (State t, fuel) (Halt (word.of_Z 0) output, fuel_left). *)

Ltac destruct_pair :=
  pat `let (_, _) := ?x in _` at destruct x.

Lemma init_length_same: forall l1 l2,
  List.length (init l1) = List.length (init l2).
Proof.
  unfold init.
  reflexivity.
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
  destruct (c_pushes) eqn:?; unfold dlet in *; simpl in *.
  pat `c_pushes _ _ = (?p, _)` at destruct p.
  destruct (c_cmd) eqn:?.
  spat `c_cmd` at eapply c_cmd_length in spat.
  spat `c_pushes` at eapply c_pushes_length in spat.
  simpl in *; cleanup.
  simpl; unfold dlet in *; simpl in *.
  all: repeat rewrite list_app_spec in *.
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
    destruct (c_test) eqn:?.
    destruct (c_cmd _ _ f_lookup0) eqn:?.
    simpl in *.
    f_equal.
    eapply IHc; eauto.
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

Lemma c_fndefs_l_same: forall funs lstart f_lookup f_lookup0 a1 a2 fs1 fs2 l1 l2,
  c_fndefs funs lstart f_lookup = (a1, fs1, l1) ->
  c_fndefs funs lstart f_lookup0 = (a2, fs2, l2) ->
  l1 = l2.
Proof.
  induction funs; intros; simpl in *; unfold dlet in *; simpl in *; cleanup; eauto.
  destruct c_fundef eqn:?.
  destruct (c_fundef _ _ f_lookup0) eqn:?.
  destruct c_fndefs eqn:?.
  pat `c_fndefs _ _ _ = (?p, _)` at destruct p.
  destruct (c_fndefs _ _ f_lookup0) eqn:?.
  pat `c_fndefs _ _ _ = (?p, _)` at destruct p.
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
    lookup (fs1 ++ (n, l) :: fs0) n = pos.
Proof.
  induction fs1; intros; simpl in *.
  - eexists.
    rewrite N.eqb_refl.
    reflexivity.
  - destruct a.
    destruct (_ =? _)%N eqn:?.
    + rewrite N.eqb_eq in *; subst; eauto.
    + eauto.
Qed.

Lemma c_fndefs_lookup_same: forall funcs fs0 fs1 fs2 fs3 asm1 asm2 l1 l2 n params body l,
  c_fndefs funcs l fs0 = (asm1, fs1, l1) ->
  c_fndefs funcs l fs2 = (asm2, fs3, l2) ->
  find_fun n funcs = Some (params, body) ->
  lookup fs1 n = lookup fs3 n.
Proof.
  Opaque c_fundef.
  induction funcs; intros; simpl in *; eauto; cleanup.
  unfold dlet in *; cleanup.
  destruct (c_fundef _ _ _) eqn:?.
  destruct (c_fndefs _ _ _) eqn:?.
  pat `c_fndefs _ _ _ = (?p, _)` at destruct p.
  simpl in *; cleanup.
  destruct (c_fundef _ _ fs2) eqn:?.
  destruct (c_fndefs _ _ fs2) eqn:?.
  pat `c_fndefs _ _ _ = (?p, _)` at destruct p.
  (* set asm1 as Sasm1. *)
  (* set fs as Sfs. *)
  (* set l1 as Sl1. *)
  simpl in *|-; cleanup; subst.
  pat `match ?a with _ => _ end = _` at destruct a; simpl in *.
  rewrite N.eqb_sym.
  destruct (_ =? _)%N eqn:?.
  - reflexivity.
  - eapply IHfuncs; eauto.
    spat `c_fundef` at eapply c_fundef_l_same in spat; [|exact Heqp]; subst.
    pat `c_fndefs _ _ _ = (_, l0, _)` at eapply c_fndefs_l_same in pat; eauto.
Qed.

Lemma c_fndefs_code_in: forall funcs fs0 fs asm1 l1 n params body xs,
  c_fndefs funcs (List.length xs) fs0 = (asm1, fs, l1) ->
  find_fun n funcs = Some (params, body) ->
  exists pos,
    lookup fs n = pos ∧ (* No fail case here... (<> 0) ? *)
    code_in pos (flatten (fst (c_fundef (Func n params body) pos fs0)))
      (xs ++ flatten asm1).
Proof.
  Opaque c_fundef.
  induction funcs; intros; simpl in *|-; cleanup.
  unfold dlet in *.
  destruct (c_fundef _ _ _) eqn:?.
  destruct (c_fndefs _ _ _) eqn:?.
  pat `c_fndefs _ _ _ = (?p, _)` at destruct p.
  set asm1 as Sasm1.
  set fs as Sfs.
  set l1 as Sl1.
  simpl in *|-; cleanup.
  pat `match ?a with _ => _ end = _` at destruct a; simpl in *|-.
  destruct (_ =? _)%N eqn:?; cleanup.
  1: {
    eexists; simpl; unfold dlet; simpl.
    rewrite N.eqb_eq in *; subst.
    rewrite N.eqb_refl.
    split; [reflexivity|].
    spat `c_fundef` at rewrite spat; simpl; unfold dlet; simpl.
    repeat rewrite list_app_spec in *.
    assert (xs ++ Comment (N2asciid n1) :: flatten a0 ++ Ret :: flatten a1 = (xs ++ [Comment (N2asciid n1)]) ++ flatten a0 ++ Ret :: flatten a1) as ->.
    1: induction xs; simpl; try rewrite <- app_assoc; eauto.
    eapply code_in_append_left2.
    rewrite length_app; simpl.
    lia.
  }
  subst Sasm1 Sfs.
  pat `c_fundef _ _ _ = _` at eapply c_fundef_length in pat; subst.
  assert (Datatypes.length (flatten a0) + (Datatypes.length xs + 1) + 1 = List.length (xs ++ flatten (List [Comment (N2asciid n1)] +++ a0 +++ List [Ret]))) as Hrwlength.
  (* assert (Datatypes.length (flatten a0) + (Datatypes.length xs) = List.length (xs ++ flatten a0)) as Hrwlength. *)
  1: simpl; rewrite list_app_spec; repeat rewrite length_app; simpl; repeat rewrite length_app; simpl; lia.
  rewrite Hrwlength in *.
  spat `c_fndefs` at eapply IHfuncs in spat; eauto; cleanup; simpl; unfold dlet in *; simpl in *.
  eexists; split; simpl.
  1: {
    destruct (n1 =? n)%N eqn:?; rewrite ?N.eqb_neq in *; rewrite ?N.eqb_eq in *.
    - congruence.
    - eauto.
  }
  simpl in *; unfold dlet in *; simpl in *.
  repeat rewrite list_app_spec in *.
  rewrite app_comm_cons.
  rewrite app_assoc.
  assert (Ret :: flatten a1 = [Ret] ++ flatten a1) as -> by (simpl; reflexivity).
  rewrite app_assoc with (n := flatten a1).
  rewrite <- app_assoc with (n := [Ret]).
  rewrite <- app_comm_cons.
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
  find_fun (name_of_string "main") funcs = Some ([], main_c) ->
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
      else
        prefix output s1.(ImpSemantics.output) = true
    end.
Proof.
  intros.
  Opaque word.eqb.
  Opaque init.
  Transparent nth_error.
  unfold codegen, dlet in *.
  Opaque name_of_string.
  Transparent rm_nms.
  repeat rewrite appl_len_spec in *.
  repeat rewrite list_app_spec in *.
  repeat rewrite list_len_spec in *.
  simpl in *.
  unfold catch_return in *.
  spat `let (_, _) := ?x in _` at destruct x eqn:?; unfold_outcome.
  destruct (c_fndefs funcs _ _) eqn:Heqcfuns0.
  spat `c_fndefs _ _ _ = (?p, _)` at destruct p.
  simpl in *.
  destruct (c_fndefs funcs _ l) eqn:Heqcfuns.
  spat `c_fndefs _ _ _ = (?p, _)` at destruct p.
  simpl in *.
  spat `eval_cmd` at rename spat into Heval_cmd.
  specialize c_fndefs_l_same with (1 := Heqcfuns) (2 := Heqcfuns0) as ?; subst.
  remember (lookup l _) as lookup_main_l.
  spat `c_fndefs` at rewrite init_length_same with (l2 := lookup_main_l) in spat.
  pat `find_fun _ _ = _` at rename pat into Hfind_fun.
  pat `c_fndefs _ _ _ = (_, _, _)` at specialize c_fndefs_code_in with (1 := pat) (2 := Hfind_fun) as ?; cleanup.
  Transparent c_fundef.
  rewrite c_fndefs_lookup_same with (fs1 := l0) (fs3 := l) (n := name_of_string "main") (1 := Heqcfuns) (2 := Heqcfuns0) (3 := Hfind_fun) in *.
  unfold c_fundef, dlet in *.
  destruct (c_pushes _ _) eqn:?.
  destruct (c_cmd _ _) eqn:?.
  simpl in *.
  repeat (rewrite code_in_append in *; simpl in * ); cleanup.
  assert (s0 = s1) by do 2 (pat `match ?o with _ => _ end = _` at destruct o; inversion pat; try congruence).
  pat `c_pushes _ _ = (?p, _)` at destruct p.
  unfold c_pushes, dlet in *; simpl in *; unfold dlet in *; simpl in *.
  pat ` (_, _, _) = (_, _, _)` at inversion pat; subst; clear pat.
  remember (lookup l _) as lookup_main_l.
  repeat rewrite list_app_spec in *.
  repeat rewrite list_len_spec in *.
  simpl in *|-.
  pat `c_cmd _ _ _ (None :: ?vs) = _` at remember vs as vs_bdrs.
  repeat (rewrite code_in_append in *; simpl in * ); cleanup.
  pose proof c_cmd_correct as Hccorrect; unfold goal_cmd in Hccorrect.
  eapply Hccorrect with (curr := (Word (word.of_Z 0)) :: (List.map (fun _ => Uninit) vs_bdrs)) (rest := [RetAddr 4]) in Heval_cmd as Hmain; clear Hccorrect; cleanup.
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
    remember (Comment ("malloc") :: _) as init_rest; clear Heqinit_rest.
    unfold cmd_res_rel in * ; cleanup.
    pat `eval_cmd _ _ _ = (?res, _)` at destruct res; cleanup.
    1: congruence.
    (* res = Stop v *)
    pat `match ?s with _ => _ end` at destruct s; cleanup.
    1: { (* s0 = State *)
      pat `eval_cmd _ _ _ = (Stop ?v, _)` at destruct v; cleanup; [| |congruence].
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
      pat `vs_bdrs = _` at rewrite <- pat in *.
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
  1: do 2 (pat `match ?o with _ => _ end = _` at destruct o; inversion pat; try congruence).
  5: { (* has_stack *)
    unfold has_stack.
    do 2 eexists.
    repeat split.
    pat `stack t = _` at rewrite pat.
    pat `pc t = _` at rewrite pat.
    simpl.
    pat `vs_bdrs = _` at rewrite pat.
    reflexivity.
  }
  1: { (* c_cmd main_c *)
    pat `lookup_main_l = _` at rewrite <- pat.
    eauto.
  }
  1: { (* state_rel *)
    unfold state_rel; simpl.
    replace (Z.of_nat (2 ^ 63 - 1)) with (2 ^ 63 - 1)%Z.
    2: rewrite Nat2Z.inj_sub; [rewrite Nat2Z.inj_pow|eapply Nat.pow_lower_bound]; lia.
    repeat split; eauto.
    - unfold init_code_in.
      eexists.
      pat `instructions t = _` at rewrite pat.
      Transparent init.
      simpl; repeat (split; eauto).
    - intros.
      spat `find_fun` at pose proof spat as Hfind_fun_n0; eapply c_fndefs_code_in in spat; eauto.
      pat `instructions t = _` at rewrite pat.
      cleanup; eexists.
      split; eauto.
      rewrite c_fndefs_lookup_same with (1 := Heqcfuns) (2 := Heqcfuns0) (3 := Hfind_fun_n0) in *; subst.
      eauto.
    - spat `memory_writable` at pose proof memory_writable as ?.
      spat `memory_writable` at unfold memory_writable in spat; cleanup.
      do 2 eexists.
      repeat split; eauto.
  }
  2: { (* binders_ok *)
    assert (None :: vs_bdrs = [None] ++ vs_bdrs) as -> by (simpl; congruence).
    eapply binders_ok_append2.
    pat `vs_bdrs = _` at rewrite pat.
    unfold ImpToASMCodegen.vs_bdrs in *; unfold dlet in *; simpl in *; rewrite ?list_app_spec.
    destruct (bdrs_vs) eqn:?.
    all: pat `bdrs_vs _ = _` at rewrite <- pat.
    2: destruct even_len.
    2: eapply binders_ok_append.
    all: eapply binders_ok_bdrs_unq.
  }
  6: unfold odd, even; reflexivity.
  6: {
    pat `vs_bdrs = _` at rewrite pat.
    unfold ImpToASMCodegen.vs_bdrs in *; unfold dlet in *; simpl in *; rewrite ?list_app_spec.
    destruct (bdrs_vs) eqn:?.
    all: rewrite length_map; simpl; eauto.
    rewrite app_comm_cons.
    destruct even_len eqn:?.
    all: rewrite ?length_app; simpl; rewrite ?Nat.add_1_r.
    all: rewrite even_len_spec in *.
    all: rewrite Nat.odd_succ_succ, ?Nat.odd_succ, <- ?Nat.negb_even.
    all: pat `even _ = _` at rewrite pat; reflexivity.
  }
  6: { (* code_in *)
    unfold ImpToASMCodegen.vs_bdrs in *; unfold dlet in *; simpl in *; rewrite ?list_app_spec.
    pat `lookup_main_l = _` at rewrite <- pat.
    pat `instructions t = _` at rewrite pat.
    eauto.
  }
  4: { (* pmap_ok *)
    instantiate (1 := (fun _ => None)).
    unfold pmap_ok.
    intros; cleanup.
  }
  1: { (* env_ok *)
    pat `vars s = _` at rewrite pat.
    unfold env_ok; simpl.
    Opaque init.
    repeat split.
    1: pat `vs_bdrs = _` at rewrite pat.
    1: simpl in *; rewrite length_map; lia.
    all: rewrite IEnv.lookup_empty in *; cleanup.
  }
  2: { (* pmap_in_memory *)
    unfold pmap_in_memory; intros; cleanup.
  }
  2: { (* pmap_in_bounds *)
    unfold pmap_in_bounds; intros; cleanup.
  }
  (* mem_inv *)
  pat `ImpSemantics.memory s = _` at rewrite pat.
  unfold mem_inv; intros.
  rewrite nth_error_nil in *; cleanup.
Qed.

Theorem codegen_terminates: forall fuel,
  forall input prog output1 output2,
    prog_terminates input prog fuel output1 /\
    asm_terminates input (codegen prog) output2 ->
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
  all: spat `Relation_Operators.clos_refl_trans_1n` at eapply RTC_IMP_steps in spat; cleanup.
  all: spat `steps` at eapply steps_determ_Halt in spat; cleanup.
  2,4: exact H.
  all: subst.
  2: spat `word.eqb` at eapply Properties.word.eqb_false in spat; congruence.
  reflexivity.
Qed.

(* Theorem codegen_terminates_weak:
  forall input prog output1 output2,
    prog_avoids_crash input prog ->
    imp_weak_termination input prog output1 /\
    asm_terminates input (codegen prog) output2 ->
      output1 = output2.
Proof.
  intros.
  destruct prog; cleanup.
  simpl in *; unfold imp_weak_termination, prog_avoids_crash, eval_from, asm_terminates, init_state_ok  in *; cleanup; subst.
  pat `match ?s with _ => _ end = _` at destruct s eqn:?; unfold_outcome; cleanup; try congruence.
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
  all: spat `Relation_Operators.clos_refl_trans_1n` at eapply RTC_IMP_steps in spat; cleanup.
  all: spat `steps` at eapply steps_determ_Halt in spat; cleanup.
  2,4: exact H.
  all: subst.
  2: spat `word.eqb` at eapply Properties.word.eqb_false in spat; congruence.
  reflexivity.
Qed. *)

Theorem codegen_no_abort: forall fuel,
  forall input prog output outcome s1,
    asm_terminates input (codegen prog) output ->
    eval_from fuel input prog = (outcome, s1) ->
    outcome <> Stop Crash ->
    outcome <> Stop Abort.
Proof.
  intros.
  destruct prog; cleanup.
  simpl in *; unfold prog_avoids_crash, eval_from, asm_terminates, init_state_ok in *; cleanup; subst.
  pat `match ?s with _ => _ end = _` at destruct s eqn:?; unfold_outcome; cleanup; try congruence.
  pat ` (let (_, _) := ?x in _) = _` at destruct x.
  pat `match ?s with _ => _ end = _` at destruct s; unfold_outcome; cleanup; try congruence.
  spat `eval_cmd` at eapply codegen_thm in spat; simpl; eauto; cleanup.
  pat `let (_, _) := ?x in _` at destruct x.
  pat `match ?s with _ => _ end` at destruct s.
  all: cleanup; subst.
  1: congruence.
  pat `if ?cond then _ else _` at destruct cond eqn:?.
  all: cleanup; subst.
  all: unfold init_state in *; simpl in *.
  all: rewrite Nat.sub_0_r in *.
  all: spat `Relation_Operators.clos_refl_trans_1n` at eapply RTC_IMP_steps in spat; cleanup.
  all: spat `steps` at eapply steps_determ_Halt in spat; cleanup.
  2,4: exact H0.
  all: subst.
  2: spat `word.eqb` at eapply Properties.word.eqb_false in spat; congruence.
  congruence.
Qed.

Lemma NRC_from_is_State: forall n x s1,
  NRC step n x (State s1) ->
  ∃s, x = State s.
Proof.
  destruct n; intros; simpl in *; cleanup.
  - eexists; eauto.
  - destruct x.
    1: eauto.
    pat `step (Halt _ _) _` at inversion pat.
Qed.

Lemma steps_from_is_State: forall n x s1 n1,
  steps (x, n) (State s1, n1) ->
  ∃s, x = State s.
Proof.
  intros * H.
  dependent induction H; intros; simpl in *; cleanup.
  - eexists; eauto.
  - spat `step` at inversion spat; eauto.
  - spat `step` at inversion spat; eauto.
  - specialize (IHsteps2 n2 s2 s1 n1 eq_refl eq_refl); cleanup; subst.
    specialize (IHsteps1 n x x0 n2 eq_refl eq_refl); cleanup; subst.
    eauto.
Qed.

Theorem NRC_step_IMP_steps: forall n t0 t1,
  NRC step n (State t0) (State t1) ->
  steps (State t0, n) (State t1, 0).
Proof.
  induction n; simpl in *; intros; cleanup.
  - pat `_ = _` at inversion pat; subst.
    eapply steps_refl.
  - pat `NRC _ _ ?x _` at specialize NRC_from_is_State with (1 := pat) as ?; cleanup; subst.
    eapply steps_trans.
    1: eapply steps_step_succ.
    1: eauto.
    eauto.
Qed.

Lemma NRC_step_add_inv: forall n m x y z,
  NRC step n (State x) (State z) -> NRC step m (State z) y ->
  NRC step (n + m) (State x) y.
Proof.
  induction n; intros; simpl in *; cleanup.
  - pat `_ = _` at inversion pat; subst.
    eauto.
  - pat `NRC _ _ x0 (State _)` at specialize NRC_from_is_State with (1 := pat) as ?; cleanup; subst.
    eexists; split; eauto.
Qed.

Theorem steps_IMP_NRC_step: ∀s k res r,
  steps (s, k) (res, r) -> ∃k, NRC step k s res.
Proof.
  intros * H.
  dependent induction H.
  - exists 0; simpl; reflexivity.
  - exists 1; simpl.
    eexists; cleanup; eauto.
  - exists 1; simpl.
    eexists; cleanup; eauto.
  - destruct s2.
    2: {
      pat `steps (Halt _ _, _) _` at specialize steps_from_Halt_is_Halt with (1 := pat) as ?; cleanup; subst.
      eapply IHsteps1; eauto.
    }
    pat `steps _ (State _, _)` at specialize steps_from_is_State with (1 := pat) as ?; cleanup; subst.
    specialize (IHsteps1 (State x) k (State s0) n2 eq_refl eq_refl) as ?.
    specialize (IHsteps2 (State s0) n2 res r eq_refl eq_refl) as ?.
    cleanup.
    exists (x1 + x0).
    eapply NRC_step_add_inv; eauto.
Qed.

Lemma NRC_step_add: forall n m x y,
  NRC step (n + m) (State x) (State y) ->
  ∃z, NRC step n (State x) (State z) ∧ NRC step m (State z) (State y).
Proof.
  induction n; intros; simpl in *; cleanup.
  - eexists; split; eauto.
  - pat `NRC _ _ _ (State _)` at specialize NRC_from_is_State with (1 := pat) as ?; cleanup; subst.
    pat `NRC _ (_ + _) _ _` at eapply IHn in pat; cleanup.
    eexists; split; eauto.
Qed.

Theorem NRC_step_determ: ∀k s res1 res2,
  NRC step k s res1 -> NRC step k s res2 -> res1 = res2.
Proof.
  induction k; intros; simpl in *.
  - congruence.
  - destruct H as [z1 [Hz1a Hz1b]].
    destruct H0 as [z2 [Hz2a Hz2b]].
    assert (z1 = z2) as Heq.
    1: eapply step_determ; eauto.
    subst z2.
    eapply IHk; eauto.
Qed.

Theorem steps_NRC: ∀s1 n1 s2 n2,
  steps (s1, n1) (State s2, n2) -> ∃k, NRC step (n1 - n2 + k) s1 (State s2) ∧ n2 ≤ n1.
Proof.
  intros * H.
  dependent induction H.
  - exists 0; split; eauto; rewrite Nat.sub_diag, Nat.add_0_r; simpl; reflexivity.
  - exists 1; split; eauto; rewrite Nat.sub_diag, Nat.add_1_r; simpl; eauto.
  - exists 0; split; eauto; rewrite Nat.sub_succ_l, Nat.sub_diag, Nat.add_0_r; simpl; [eauto|lia].
  - pat `steps _ (State _, _)` at specialize steps_from_is_State with (1 := pat) as ?; cleanup; subst.
    specialize (IHsteps1 s1 n1 x n4 eq_refl eq_refl); cleanup; subst.
    specialize (IHsteps2 (State x) n4 s2 n2 eq_refl eq_refl); cleanup; subst.
    eauto.
    exists (x0 + x1).
    assert (n1 - n2 + (x0 + x1) = (n1 - n4 + x0) + (n4 - n2 + x1)) as -> by lia.
    pat `NRC _ _ s1 _` at specialize NRC_from_is_State with (1 := pat) as ?; cleanup; subst.
    split; [|lia].
    eapply NRC_step_add_inv; eauto.
Qed.

Theorem NRC_step_mono: ∀n t1 t2,
  NRC step n (State t1) (State t2) -> prefix t1.(output) t2.(output) = true.
Proof.
  induction n; simpl; intros; cleanup.
  - pat `_ = _` at inversion pat; subst; cleanup.
    eapply prefix_correct.
    eapply substring_noop.
  - pat `NRC _ _ _ _` at specialize NRC_from_is_State with (1 := pat) as ?; cleanup; subst.
    pat `step _ _` at eapply step_mono in pat.
    eapply prefix_trans; [eauto|].
    eapply IHn; eauto.
Qed.

Lemma get_Some_IMP_lt: forall s i,
  get i s <> None -> i < length s.
Proof.
  induction s; simpl; intros; try congruence.
  destruct i; simpl in *; try lia.
  rewrite <- Nat.succ_lt_mono.
  eauto.
Qed.

Theorem get_prefix_correct: forall s1 s2 i,
  prefix s1 s2 = true ->
  get i s1 <> None ->
  get i s2 = get i s1.
Proof.
  intros.
  rewrite prefix_correct in *.
  pat `_ = s1` at rewrite <- pat.
  rewrite substring_correct1.
  1: rewrite Nat.add_0_r; eauto.
  eapply get_Some_IMP_lt.
  assumption.
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
    pat ` let (_, _) := ?p in _` at destruct p.
    spat `steps` at eapply steps_IMP_NRC_step in spat; cleanup.
    pat `forall _, _` at specialize pat with (k := x2); cleanup.
    spat `NRC _ _ _ (State _)` at eapply NRC_step_determ in spat; eauto; subst; cleanup.
    eauto.
  }
  (* output_ok_imp *)
  unfold output_ok_asm, output_ok_imp, imp_output in *; intros; cleanup.
  pat `forall _, _` at specialize pat with (i := i); cleanup; destruct pat.
  2: { (* output None at i*)
    right; cleanup; split; eauto.
    intros.
    destruct eval_from eqn:?.
    spat `_ <> Stop Crash` at specialize spat with (res := o) (s := s) as Hnocrash; clear spat.
    pat `eval_from _ _ _ = _` at specialize (Hnocrash _ pat).
    destruct prog.
    unfold eval_from in *.
    destruct find_fun eqn:?; unfold_outcome; cleanup.
    2: congruence.
    pat ` (let (l, _) := ?p in _) = _` at destruct p; destruct l.
    2: congruence.
    spat `eval_cmd` at eapply codegen_thm with (s := init_state input funcs) in spat; eauto; cleanup.
    simpl in *; rewrite Nat.sub_0_r in *.
    pat ` let (_, _) := ?p in _` at destruct p.
    pat `match ?s0 with _ => _ end` at destruct s0.
    2: {
      spat `steps` at eapply steps_IMP_NRC_step in spat; cleanup.
      pat `forall _, exists _, NRC _ _ _ _` at specialize pat with (k := x2); cleanup.
      spat `NRC _ x2 _ (State _)` at eapply NRC_step_determ in spat; eauto; cleanup.
      pat `Halt _ _ = State _` at inversion pat.
    }
    spat `steps` at eapply steps_IMP_NRC_step in spat; cleanup; subst.
    pat `forall _ _, _ ∧ _` at specialize pat with (k := x2) (t1 := s0); cleanup.
    pat `_ = ImpSemantics.output s` at rewrite <- pat.
    assumption.
  }
  (* output Some at i*)
  left; cleanup.
  exists x2.
  destruct eval_from eqn:?.
  spat `_ <> Stop Crash` at specialize spat with (res := o) (s := s) as Hnocrash; clear spat.
  pat `eval_from _ _ _ = _` at specialize (Hnocrash _ pat).
  destruct prog.
  unfold eval_from in *.
  destruct find_fun eqn:?; unfold_outcome; cleanup.
  2: congruence.
  pat ` (let (l, _) := ?p in _) = _` at destruct p; destruct l.
  2: congruence.
  assert (o = Stop TimeOut) as HoTimeOut.
  1: {
    spat `eval_cmd` at eapply codegen_thm in spat; eauto; cleanup.
    simpl in *; rewrite Nat.sub_0_r in *.
    pat ` let (_, _) := ?p in _` at destruct p.
    spat `steps` at eapply steps_IMP_NRC_step in spat; cleanup.
    pat `forall _, _` at specialize pat with (k := x4); cleanup.
    spat `NRC _ x4 _ (State _)` at eapply NRC_step_determ in spat; eauto; subst; cleanup.
    eauto.
  }
  spat `catch_return (eval_cmd ?c (_ ?f)) ?s1` at specialize catch_return_steps_done_ge_fuel with (c := c) (fuel := f) (1 := spat) (2 := HoTimeOut) as ?.
  spat `eval_cmd` at eapply codegen_thm with (s := init_state input funcs) in spat; eauto; cleanup.
  simpl in *; rewrite Nat.sub_0_r in *.
  pat ` let (_, _) := ?p in _` at destruct p.
  pat `match ?s0 with _ => _ end` at destruct s0.
  2: {
    spat `steps` at eapply steps_IMP_NRC_step in spat; cleanup.
    pat `forall _, _` at specialize pat with (k := x4); cleanup.
    spat `NRC _ x4 _ (State _)` at eapply NRC_step_determ in spat; eauto; cleanup.
    pat `Halt _ _ = State _` at inversion pat.
  }
  cleanup; subst.
  pat `_ = ImpSemantics.output s` at rewrite <- pat.
  spat `steps` at eapply steps_NRC in spat; cleanup.
  simpl in *; rewrite Nat.sub_0_r in *.
  assert (exists k_diff, steps_done s = x2 + k_diff) as [k_diff Hk_diff] by (exists (steps_done s - x2); lia).
  pat `NRC step (_ + _) (State x) _` at eapply NRC_step_add in pat; cleanup.
  pat `NRC _ x4 _ _` at eapply NRC_step_mono in pat.
  pat `steps_done s = _` at rewrite pat in *.
  pat `NRC step (_ + _) (State x) _` at eapply NRC_step_add in pat; cleanup.
  pat `NRC _ k_diff _ _` at eapply NRC_step_mono in pat.
  spat `NRC step x2` at eapply NRC_step_determ in spat.
  2: pat `NRC step x2 (State _) (State x3)` at exact pat; subst.
  pat `State _ = State _` at inversion pat; subst; clear pat.
  rewrite get_prefix_correct with (s1 := ASMSemantics.output x6); eauto.
  eapply prefix_trans; eauto.
Qed.

