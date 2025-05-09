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
Definition v_inv (t : ASMSemantics.state) (v : word64) (w : word64) : Prop :=
  word.ltu v (word.of_Z (2 ^ 63)) = true /\ w = v.

(* Checks that environment variables map to valid locations and values on the stack in the ASM state. *)
Definition env_ok (env : IEnv.env) (vs : list (option nat)) (curr : list word_or_ret) (t : ASMSemantics.state) : Prop :=
  List.length vs = List.length curr /\
  forall n v,
    (* TODO(kπ) should this also assert pointers? *)
    IEnv.lookup env n = Some (ImpSyntax.Word v) ->
    index_of n 0 vs < List.length curr /\
    exists w,
      nth_error curr (index_of n 0 vs) = Some (Word w) /\
      v_inv t v w.

(* Goals *)

Definition goal :=
  forall (env : IEnv.env) (s s1 : ImpSemantics.state) (fuel: nat) (c : cmd)
         (res : outcome Value unit) (t : ASMSemantics.state)
         (vs vs' : v_stack) (fs : f_lookup)
         (asmc : asm_appl) (l1 : nat)
         (curr rest : list word_or_ret),
    EVAL_CMD fuel c s = (res, s1) /\
    res <> Stop Crash /\
    c_cmd c t.(pc) fs vs = (asmc, l1, vs') /\
    state_rel fs s t /\
    env_ok env vs curr t /\
    has_stack t (curr ++ rest) /\
    odd (List.length rest) = true /\
    code_in t.(pc) (flatten asmc) t.(instructions)
    ->
    exists outcome,
      steps (State t, fuel) outcome /\
      match outcome with
      | (Halt ec output, ck) =>
          prefix output (string_of_list_ascii s1.(ImpSemantics.output)) = true /\
          ec = (word.of_Z 1)
      | (State t1, ck) =>
          state_rel fs s1 t1 /\
          ck = fuel /\
          forall v,
            res = Stop (Return v) ->
            exists w,
              (* TODO(kπ) Do we need this? vvvvvv (probably in a different form?) *)
              (* v_inv t1 v w /\ *)
                has_stack t1 (Word w :: curr ++ rest) /\
                t1.(pc) = l1
      end.
