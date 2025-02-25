Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Import ListNotations.

Module ASMSyntax.

(* 
TODO(kπ)
- word64 in Coq?
- word4 in Coq?
*)

Inductive reg :=
| RAX (* ret val *)
| RDI (* arg to call *)
| RBX | RBP | R12 | R13 | R14 | R15 (* callee saved *)
| RDX. (* caller saved, i.e. gets clobbered by external calls *)

Inductive cond :=
| Always
| Less (r1 r2 : reg)
| Equal (r1 r2 : reg).

Inductive instr :=
(* arithmetic *)
| Const (r : reg) (w : nat)
| Mov (r1 r2 : reg)
| Add (r1 r2 : reg)
| Sub (r1 r2 : reg)
| Div (r : reg)
  (* jumps *)
| Jump (c : cond) (n : nat)
| Call (n : nat)
  (* stack *)
| Ret
| Pop (r : reg)
| Push (r : reg)
| Add_RSP (n : nat)
| Load_RSP (r : reg) (n : nat)
  (* memory *)
| Load (r1 r2 : reg) (w : nat)
| Store (r1 r2 : reg) (w : nat)
  (* I/O *)
| GetChar
| PutChar
| Exit
  (* comment (has no semantics) *)
| Comment (s : string).

Notation asm := (list instr).

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
Definition num2str (n : nat) (s : string) : string. Admitted.

(* TODO(kπ) asm2str defs *)


(* TODO(kπ) *)
Definition asm2str (a : asm) : string := "".

End ASMSyntax.
