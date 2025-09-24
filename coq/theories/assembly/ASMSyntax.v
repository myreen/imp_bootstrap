From impboot Require Import utils.Core.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.

Inductive reg :=
| RAX (* ret val *)
| RDI (* arg to call *)
| RBX | RBP | R12 | R13 | R14 | R15 (* callee saved *)
| RDX. (* caller saved, i.e. gets clobbered by external calls *)

Notation ARG_REG := RDI (only parsing).
Notation RET_REG := RAX (only parsing).

Scheme Equality for reg.

Definition reg_CASE {A} (r : reg)
  (rax : A) (rdi : A) (rbx : A) (rbp : A) (r12 : A) (r13 : A) (r14 : A) (r15 : A) (rdx : A) : A :=
  match r with
  | RAX => rax
  | RDI => rdi
  | RBX => rbx
  | RBP => rbp
  | R12 => r12
  | R13 => r13
  | R14 => r14
  | R15 => r15
  | RDX => rdx
  end.

Inductive cond :=
| Always
| Less (r1 r2 : reg)
| Equal (r1 r2 : reg).

Inductive instr :=
(* arithmetic *)
| Const (r : reg) (w : word64)
| Add (r1 r2 : reg)
| Sub (r1 r2 : reg)
| Div (r : reg)
  (* jumps *)
| Jump (c : cond) (n : nat)
| Call (n : nat)
  (* stack *)
| Mov (r1 r2 : reg)
| Ret
| Pop (r : reg)
| Push (r : reg)
| Add_RSP (n : nat)
| Sub_RSP (n : nat)
| Load_RSP (r : reg) (n : nat)
| Store_RSP (r : reg) (n : nat)
  (* memory *)
| Load (r1 r2 : reg) (w : word4)
| Store (r1 r2 : reg) (w : word4)
  (* I/O *)
| GetChar
| PutChar
| Exit
  (* comment (has no semantics) *)
| Comment (s : string).

Notation asm := (list instr) (only parsing).

Definition reg2str (r : reg) (s: string) : string :=
  match r with
  | RAX => "%rax"
  | RDI => "%rdi"
  | RBX => "%rbx"
  | RBP => "%rbp"
  | R12 => "%r12"
  | R13 => "%r13"
  | R14 => "%r14"
  | R15 => "%r15"
  | RDX => "%rdx"
  end ++ s.

(* TODO(kπ) *)
Definition asm2str (a : asm) : string := "".
