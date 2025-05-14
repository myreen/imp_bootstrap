Require Import impboot.utils.Core.
Require Import impboot.utils.Env.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.imperative.ImpSemantics.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.assembly.ASMSemantics.

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

(* Constrains v to valid ranges and equates it with w in the context of ASM state t. *)
Definition v_inv (t : ASMSemantics.state) (v : Value) (w : word64) : Prop :=
  match v with
  | ImpSyntax.Word v => word.ltu v (word.of_Z (2 ^ 63)) = true /\ w = v
  | Pointer v => t.(memory) w <> None (* TODO(kπ) assert equality of memory blocks? *)
  end.

(* Checks that environment variables map to valid locations and values on the stack in the ASM state. *)
Definition env_ok (env : IEnv.env) (vs : list (option nat)) (curr : list word_or_ret) (t : ASMSemantics.state) : Prop :=
  List.length vs = List.length curr /\
  forall n v,
    IEnv.lookup env n = Some v ->
    index_of n 0 vs < List.length curr /\
    exists w,
      nth_error curr (index_of n 0 vs) = Some (Word w) /\
      v_inv t v w.

Definition cmd_res_rel (ri: outcome Value unit) (l1: nat) (stck: list word_or_ret) (t1: ASMSemantics.state) (s1: ImpSemantics.state) : Prop :=
  match ri with
  | Stop (Return v) => exists w,
    v_inv t1 v w /\
    has_stack t1 (Word w :: stck) /\
    t1.(pc) = l1
  | Cont _ =>
    has_stack t1 stck /\
    t1.(pc) = l1
  | _ => False
  end.

Definition exp_res_rel (ri: outcome Value Value) (l1: nat) (stck: list word_or_ret) (t1: ASMSemantics.state) (s1: ImpSemantics.state) : Prop :=
  match ri with
  | Cont v => exists w,
    v_inv t1 v w /\
    has_stack t1 (Word w :: stck) /\
    t1.(pc) = l1
  | _ => False
  end.

(* Goals *)

Definition goal_exp (e : exp) :=
  forall (s s1 : ImpSemantics.state) (fuel: nat)
         (res : outcome Value Value) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret),
    eval_exp e s = (res, s1) ->
    res <> Stop Crash ->
    c_exp e t.(pc) vs = (asmc, l1) ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr t ->
    has_stack t (curr ++ rest) ->
    odd (List.length rest) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome,
      steps (State t, fuel) outcome /\
      match outcome with
      | (Halt ec output, ck) => False
      | (State t1, ck) =>
          state_rel fs s1 t1 /\
          ck = fuel /\
          exp_res_rel res l1 (curr ++ rest) t1 s1
      end.

Definition goal_cmd (c : cmd) :=
  forall (s s1 : ImpSemantics.state) (fuel: nat)
         (res : outcome Value unit) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret),
    EVAL_CMD fuel c s = (res, s1) ->
    res <> Stop Crash ->
    c_cmd c t.(pc) fs vs = (asmc, l1, vs') ->
    state_rel fs s t ->
    env_ok s.(vars) vs curr t ->
    has_stack t (curr ++ rest) ->
    odd (List.length rest) = true ->
    code_in t.(pc) (flatten asmc) t.(instructions) ->
    exists outcome,
      steps (State t, fuel) outcome /\
      match outcome with
      | (Halt ec output, ck) =>
          prefix output (string_of_list_ascii s1.(ImpSemantics.output)) = true /\
          ec = (word.of_Z 1)
      | (State t1, ck) =>
          state_rel fs s1 t1 /\
          ck = fuel /\
          cmd_res_rel res l1 (curr ++ rest) t1 s1
      end.

(* proofs *)

Ltac unfold_outcome := unfold cont, crash, stop in *.

Ltac cleanup :=
  repeat match goal with
  | [ H: _ /\ _ |- _ ] => destruct H
  | [ H: exists _, _ |- _ ] => destruct H
  end.

Theorem give_up: forall fs ds t w n,
  code_rel fs ds t.(instructions) ->
  t.(regs) R15 = Some w ->
  t.(pc) = give_up (odd (List.length t.(stack))) ->
  steps (State t, n) (Halt (word.of_Z 1) (string_of_list_ascii t.(output)), n).
Proof.
  intros.
  unfold give_up in *.
  unfold code_rel in *.
  cleanup.
  eapply steps_trans.
  - eapply steps_step_same.
    eapply




Theorem c_exp_Const : forall (w: word64),
  goal_exp (ImpSyntax.Const w).
Proof.
  unfold goal_exp.
  intros.
  unfold has_stack in *.
  cleanup.
  eexists.
  simpl eval_exp in *.
  unfold_outcome.
  simpl c_exp in *.
  unfold c_const in *.
  destruct (word.of_Z _ <w _) eqn:?.
  1: {
    inversion H1; subst; clear H1.
    simpl flatten in *.
    split.
    1: {
      eapply steps_trans.
      + eapply steps_step_same.
        simpl code_in in *.
        cleanup.
        eapply step_jump in e; eauto.
      + eapply steps_step_same.
        simpl code_in in *.
        cleanup.
        eapply step_const.
        eauto.
    }
  }
  inversion H1; subst; clear H1.
  simpl flatten in *.
  split.
  1: {
     eapply steps_trans.
    + eapply steps_step_same.
      simpl code_in in *.
      cleanup.
      eapply step_push in e; eauto.
    + eapply steps_step_same.
      simpl code_in in *.
      cleanup.
      eapply step_const.
      eauto.
  }
  simpl.
  repeat split; unfold state_rel in *; cleanup; intros; repeat split; simpl.
  all: inversion H; subst; eauto.
  - unfold code_rel in *.
    cleanup.
    eauto.
  - unfold code_rel in *.
    cleanup.
    eapply H15 in H14.
    cleanup.
    eexists.
    split; eauto.
  - eexists; eexists.
    eauto.
  - unfold exp_res_rel.
    eexists.
    repeat split.
    1: {
      rewrite word.unsigned_ltu in *.
      rewrite word.unsigned_of_Z in *.
      unfold word.wrap in *.
      (* THIS IS HORRIBLY SLOW *)
      cbn.
      cbn in Heqb.
      lia.
    }
    + unfold has_stack.
      simpl.
      eauto.
    + simpl.
      lia.
Qed.