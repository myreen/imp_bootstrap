From impboot Require Import
  utils.Core
  utils.Llist.
Import Llist.
Require Import impboot.assembly.ASMSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
From Stdlib Require Import Relations.Relation_Operators.
From Stdlib Require Import Program.Equality.

Inductive word_or_ret :=
| Word (w: word64)
| RetAddr (pc: nat)
| Uninit.

Record state := mkState {
  instructions : asm;
  pc : nat;
  regs : reg -> option word64;
  stack : list word_or_ret;
  memory : word64 -> option (option word64);
  input : llist ascii;  (* input can be an infinite stream *)
  output : string       (* at each point output must be finite *)
}.

Definition fetch (s : state) : option instr :=
  List.nth_error s.(instructions) s.(pc).

Definition inc (s : state) : state :=
  {| instructions := s.(instructions);
     pc := s.(pc) + 1;
     regs := s.(regs);
     stack := s.(stack);
     memory := s.(memory);
     input := s.(input);
     output := s.(output) |}.

Definition write_reg (r : reg) (w : word64) (s : state) : state :=
  {| instructions := s.(instructions);
     pc := s.(pc);
     regs := (fun r' => if reg_eq_dec r r' then Some w else s.(regs) r');
     stack := s.(stack);
     memory := s.(memory);
     input := s.(input);
     output := s.(output) |}.

Fixpoint unset_regs (rs : list reg) (s : state) : state :=
  match rs with
  | [] => s
  | r :: rs' =>
      let s' := {| instructions := s.(instructions);
                   pc := s.(pc);
                   regs := fun r' => if reg_eq_dec r r' then None else s.(regs) r';
                   stack := s.(stack);
                   memory := s.(memory);
                   input := s.(input);
                   output := s.(output) |} in
      unset_regs rs' s'
  end.

Definition put_ascii (c : ascii) (s : state) : state :=
  {| instructions := s.(instructions);
     pc := s.(pc);
     regs := s.(regs);
     stack := s.(stack);
     memory := s.(memory);
     input := s.(input);
     output := String.append s.(output) (String c EmptyString) |}.

Definition read_mem (a : word64) (s : state) : option word64 :=
  match s.(memory) a with
  | None => None
  | Some opt => opt
  end.

Definition write_mem (a : word64) (w : word64) (s : state) : option state :=
  match s.(memory) a with
  | Some _ =>
      Some {| instructions := s.(instructions);
              pc := s.(pc);
              regs := s.(regs);
              stack := s.(stack);
              memory := fun a' => if word.eqb a a' then Some (Some w) else s.(memory) a';
              input := s.(input);
              output := s.(output) |}
  | _ => None
  end.

Definition update_stack (offset: nat) (w: word64) (s: state): state :=
  {| instructions := s.(instructions);
     pc := s.(pc);
     regs := s.(regs);
     stack := list_update offset (Word w) s.(stack);
     memory := s.(memory);
     input := s.(input);
     output := s.(output) |}.

Definition set_stack (xs : list word_or_ret) (s : state) : state :=
  {| instructions := s.(instructions);
     pc := s.(pc);
     regs := s.(regs);
     stack := xs;
     memory := s.(memory);
     input := s.(input);
     output := s.(output) |}.

Definition set_pc (n : nat) (s : state) : state :=
  {| instructions := s.(instructions);
     pc := n;
     regs := s.(regs);
     stack := s.(stack);
     memory := s.(memory);
     input := s.(input);
     output := s.(output) |}.

Inductive s_or_h :=
| State : state -> s_or_h
| Halt : word64 -> string -> s_or_h.

Inductive take_branch : cond -> state -> bool -> Prop :=
| take_branch_always : forall (s : state),
  take_branch Always s true
| take_branch_less : forall (s : state) (r1 r2 : reg) (w1 w2 : word64),
  forall
  (REG_LOOKUP_LEFT : s.(regs) r1 = Some w1)
  (REG_LOOKUP_RIGHT : s.(regs) r2 = Some w2),
  take_branch (Less r1 r2) s (word.ltu w1 w2)
| take_branch_equal : forall (s : state) (r1 r2 : reg) (w1 w2 : word64),
  forall
  (REG_LOOKUP_LEFT : s.(regs) r1 = Some w1)
  (REG_LOOKUP_RIGHT : s.(regs) r2 = Some w2),
  take_branch (Equal r1 r2) s (word.eqb w1 w2).

Definition EOF_CONST : word64 := word.of_Z (0xFFFFFFFF : Z).

Definition read_ascii (input : llist ascii) : (word64 * llist ascii) :=
  match input with
  | Lnil => (EOF_CONST, input)
  | Lcons c cs => (word.of_Z (Z.of_nat (nat_of_ascii c)), cs)
  end.

Inductive step: s_or_h -> s_or_h -> Prop :=
| step_const : forall s r w,
    fetch s = Some (Const r w) ->
    step (State s) (State (write_reg r w (inc s)))
| step_mov : forall s r1 r2 w,
    fetch s = Some (Mov r1 r2) ->
    s.(regs) r2 = Some w ->
    step (State s) (State (write_reg r1 w (inc s)))
| step_add : forall s r1 r2 w1 w2,
    fetch s = Some (Add r1 r2) ->
    s.(regs) r1 = Some w1 ->
    s.(regs) r2 = Some w2 ->
    step (State s) (State (write_reg r1 (word.add w1 w2) (inc s)))
| step_sub : forall s r1 r2 w1 w2,
    fetch s = Some (Sub r1 r2) ->
    s.(regs) r1 = Some w1 ->
    s.(regs) r2 = Some w2 ->
    step (State s) (State (write_reg r1 (word.sub w1 w2) (inc s)))
| step_div : forall s r w1 w2,
    fetch s = Some (Div r) ->
    w2 <> (word.of_Z 0) ->
    s.(regs) RDX = Some (word.of_Z 0) ->
    s.(regs) RAX = Some w1 ->
    s.(regs) r = Some w2 ->
    step (State s) (State (write_reg RAX (word.divu w1 w2)
                          (write_reg RDX (word.modu w1 w2)
                            (inc s))))
| step_jump : forall s cond n yes,
    fetch s = Some (Jump cond n) ->
    take_branch cond s yes ->
    step (State s) (State (set_pc (if yes then n else (s.(pc) + 1)) s))
| step_call : forall s n,
    fetch s = Some (Call n) ->
    step (State s) (State (set_pc n
                    (set_stack (RetAddr (s.(pc)+1) :: s.(stack)) s)))
| step_ret : forall s n rest,
    fetch s = Some Ret ->
    s.(stack) = RetAddr n :: rest ->
    step (State s) (State (set_pc n (set_stack rest s)))
| step_pop : forall s r w rest,
    fetch s = Some (Pop r) ->
    s.(stack) = Word w :: rest ->
    step (State s) (State (set_stack rest (write_reg r w (inc s))))
| step_push : forall s r w,
    fetch s = Some (Push r) ->
    s.(regs) r = Some w ->
    step (State s) (State (set_stack (Word w :: s.(stack)) (inc s)))
| step_load_rsp : forall s r w offset,
    fetch s = Some (Load_RSP r offset) ->
    offset < List.length s.(stack) ->
    nth_error s.(stack) offset = Some (Word w) ->
    step (State s) (State (write_reg r w (inc s)))
| step_store_rsp : forall s r w offset,
    fetch s = Some (Store_RSP r offset) ->
    offset < List.length s.(stack) ->
    s.(regs) r = Some w ->
    step (State s) (State (update_stack offset w (inc s)))
| step_add_rsp : forall s xs ys,
    fetch s = Some (Add_RSP (List.length xs)) ->
    s.(stack) = xs ++ ys ->
    step (State s) (State (set_stack ys (inc s)))
| step_sub_rsp : forall {A} s (xs: list A) ys,
    fetch s = Some (Sub_RSP (List.length xs)) ->
    s.(stack) = ys ->
    step (State s) (State (set_stack ((List.map (fun _ => Uninit) xs) ++ ys) (inc s)))
| step_store : forall s src ra imm wa w s',
    fetch s = Some (Store src ra imm) ->
    s.(regs) ra = Some wa ->
    s.(regs) src = Some w ->
    write_mem (word.add wa (word.of_Z (word.unsigned imm))) w s = Some s' ->
    step (State s) (State (inc s'))
| step_load : forall s dst ra imm wa w,
    fetch s = Some (Load dst ra imm) ->
    s.(regs) ra = Some wa ->
    read_mem (word.add wa (word.of_Z (word.unsigned imm))) s = Some w ->
    step (State s) (State (write_reg dst w (inc s)))
| step_get_ascii : forall s c rest,
    fetch s = Some GetChar ->
    read_ascii s.(input) = (c, rest) ->
    (List.length s.(stack)) mod 2 = 0 ->
    step (State s)
          (State (write_reg RET_REG c
                    (unset_regs [ARG_REG; RDX]
                      (inc (mkState s.(instructions) s.(pc) s.(regs) s.(stack) s.(memory) rest s.(output))))))
| step_put_ascii : forall s n,
    fetch s = Some PutChar ->
    s.(regs) ARG_REG = Some n ->
    Z.lt (word.unsigned n) (256 : Z) ->
    (List.length s.(stack)) mod 2 = 0 ->
    step (State s)
          (State (unset_regs [RET_REG; ARG_REG; RDX]
                    (inc (put_ascii (ascii_of_nat (Z.to_nat (word.unsigned n))) s))))
| step_exit : forall s exit_code,
    fetch s = Some Exit ->
    s.(regs) ARG_REG = Some exit_code ->
    (List.length s.(stack)) mod 2 = 0 ->
    step (State s) (Halt exit_code s.(output)).

Inductive steps : (s_or_h * nat) -> (s_or_h * nat) -> Prop :=
| steps_refl : forall s n,
  steps (s, n) (s, n)
| steps_step_same : forall s1 s2 n,
  step s1 s2 ->
  steps (s1, n) (s2, n)
| steps_step_succ : forall s1 s2 n,
  step s1 s2 ->
  steps (s1, S n) (s2, n)
| steps_trans : forall s1 n1 s2 n2 s3 n3,
  steps (s1, n1) (s2, n2) ->
  steps (s2, n2) (s3, n3) ->
  steps (s1, n1) (s3, n3).

Lemma steps_add_fuel: forall s1 n1 s2 n2 x,
  steps (s1, n1) (s2, n2) ->
  steps (s1, n1 + x) (s2, n2 + x).
Proof.
  intros.
  dependent induction H.
  - simpl. eapply steps_refl.
  - eapply steps_step_same.
    eauto.
  - replace (n2 + 1 + x) with (n2 + x + 1) by lia.
    simpl.
    eapply steps_step_succ.
    eauto.
  - eapply steps_trans; eauto.
Qed.

Theorem step_determ: forall x y z,
  step x y ∧ step x z -> y = z.
Proof.
Admitted.

Theorem steps_determ: forall s fuel s1 s2 e1 e2 o1 o2,
  steps (s, fuel) (Halt e1 o1, s1) ->
  steps (s, fuel) (Halt e2 o2, s2) ->
  e1 = e2 /\ o1 = o2.
Proof.
Admitted.

Theorem step_mono: forall s0 s1,
  step (State s0) (State s1) -> prefix s0.(output) s1.(output) = true.
Proof.
Admitted.

Definition can_write_mem_at (m : word64 -> option (option word64)) (a : word64) : Prop :=
  m a = Some None.

Definition memory_writable (r14 r15 : word64) (m : word64 -> option (option word64)) : Prop :=
  (word.ltu r14 r15 = true \/ word.eqb r14 r15 = true) /\
  word.eqb (word.modu r14 (word.of_Z 8)) (word.of_Z 0) = true /\
  word.eqb (word.modu r15 (word.of_Z 8)) (word.of_Z 0) = true /\
  r14 <> word.of_Z 0 /\
  (forall a, (word.ltu r14 a = true \/ word.eqb r14 a = true) /\
              word.ltu a r15 = true /\
              word.eqb (word.modu a (word.of_Z 8)) (word.of_Z 0) = true ->
              can_write_mem_at m a).

Definition init_state_ok (t : state) (inp : llist ascii) (asm : asm) : Prop :=
  exists r14 r15,
    t.(pc) = 0 /\
    t.(instructions) = asm /\
    t.(input) = inp /\
    t.(output) = EmptyString /\
    t.(stack) = [] /\
    t.(regs) R14 = Some r14 /\
    t.(regs) R15 = Some r15 /\
    memory_writable r14 r15 t.(memory).

Definition asm_terminates (input: llist ascii) (asm: asm) (output: string): Prop :=
  exists t,
    init_state_ok t input asm /\
    clos_refl_trans s_or_h step (State t) (Halt (word.of_Z 0) output).

(* Definition asm_diverges_def:
  (input, asm) asm_diverges output =
    ∃t. init_state_ok t input asm ∧
      (* repeated application of step never halts or gets stuck: *)
      (∀k. ∃t'. NRC step k (State t) (State t')) ∧
      (* the output is the least upper bound of all reachable output *)
      output = build_lprefix_lub { fromList t'.output | step꙳ (State t) (State t') }
End *)

Fixpoint NRC {A} (R: A -> A -> Prop) (n: nat) x y :=
  match n with
  | 0 => x = y
  | S n =>
    exists z, R x z /\ NRC R n z y
  end.

(* TODO: define as in IMP *)
Definition output_ok_asm (t: state) (out: llist ascii): Prop :=
  ∀ i,
    (∃ k t1, NRC step k (State t) (State t1) ∧ String.get i t1.(output) <> None ∧ String.get i t1.(output) = Llist.nth i out) ∨
    (not (Llist.defined_at i out) ∧ (∀k t1, NRC step k (State t) (State t1) ∧ String.get i t1.(output) = None)).

Definition asm_diverges (input: llist ascii) (asm: asm) (output: llist ascii) : Prop :=
  exists t,
    init_state_ok t input asm /\
    (forall k, exists t1, NRC step k (State t) (State t1)) /\
    output_ok_asm t output.
    (* output = build_lprefix_lub (fun t' => exists t'', clos_refl_trans step (State t) (State t') /\ t'.(output) = t''.(output)). *)
