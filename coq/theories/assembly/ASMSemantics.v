Require Import Nat.
Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
Import ListNotations.
Require Import impboot.assembly.ASMSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.
Require Import ZArith.
Require Import impboot.utils.Llist.

Inductive word_or_ret :=
| Word : word64 -> word_or_ret
| RetAddr : nat -> word_or_ret.

Record state := mkState {
  instructions : asm;
  pc : nat;
  regs : reg -> option word64;
  stack : list word_or_ret;
  memory : word64 -> option (option word64);
  input : llist ascii;  (* input can be an infinite stream *)
  output : list ascii    (* at each point output must be finite *)
}.

Fixpoint lookup {A} (n : nat) (xs : list A) : option A :=
  match xs with
  | [] => None
  | x :: xs' => if (n =? 0) then Some x else lookup (n - 1) xs'
  end.

Definition fetch (s : state) : option instr :=
  lookup s.(pc) s.(instructions).

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
     output := s.(output) ++ [c] |}.

Definition read_mem (a : word64) (s : state) : option word64 :=
  match s.(memory) a with
  | None => None
  | Some opt => opt
  end.

Definition write_mem (a : word64) (w : word64) (s : state) : option state :=
  match s.(memory) a with
  | Some None =>
      Some {| instructions := s.(instructions);
              pc := s.(pc);
              regs := s.(regs);
              stack := s.(stack);
              memory := fun a' => if word.eqb a a' then Some (Some w) else s.(memory) a';
              input := s.(input);
              output := s.(output) |}
  | _ => None
  end.

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
  | take_branch_always : forall s,
      take_branch Always s true
  | take_branch_less : forall s r1 r2 w1 w2,
      s.(regs) r1 = Some w1 ->
      s.(regs) r2 = Some w2 ->
      take_branch (Less r1 r2) s (word.ltu w1 w2)
  | take_branch_equal : forall s r1 r2 w1 w2,
      s.(regs) r1 = Some w1 ->
      s.(regs) r2 = Some w2 ->
      take_branch (Equal r1 r2) s (word.eqb w1 w2).

Definition EOF_CONST : word64 := word.of_Z (0xFFFFFFFF : Z).

Definition read_ascii (input : llist ascii) : (word64 * llist ascii) :=
  match input with
  | lnil => (EOF_CONST, input)
  | lcons c cs => (word.of_Z (Z.of_nat (nat_of_ascii c)), cs)
  end.

Inductive step : s_or_h -> s_or_h -> Prop :=
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
  | step_add_rsp : forall s xs ys,
      fetch s = Some (Add_RSP (List.length xs)) ->
      s.(stack) = xs ++ ys ->
      step (State s) (State (set_stack ys (inc s)))
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
      step (State s) (Halt exit_code (string_of_list_ascii s.(output))).
