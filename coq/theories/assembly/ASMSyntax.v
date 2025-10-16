From impboot Require Import utils.Core.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
Require Import Corelib.Program.Wf.
Require Import Lia.

Inductive reg :=
| RAX (* ret val *)
| RDI (* arg to call *)
| RBX | RBP | R12 | R13 | R14 | R15 (* callee saved *)
| RDX. (* caller saved, i.e. gets clobbered by external calls *)

Notation ARG_REG := RDI (only parsing).
Notation RET_REG := RAX (only parsing).

Scheme Equality for reg.

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
| Comment (s: list ascii).

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

Program Fixpoint num2str (n: nat) (s: string) {measure n} : string :=
  if n <? 10 then String (ascii_of_nat (48 + n)) s
  else num2str (n / 10) (String (ascii_of_nat (48 + (Nat.modulo n 10))) s).
Next Obligation.
  (* simpl.
  specialize (Nat.divmod_spec n 9 0 9 ltac:(lia)) as ?.
  destruct Nat.divmod eqn:?.
  destruct H.
  simpl. 
  destruct n; simpl.
  - destruct n0; try lia.
    assert (n1 <> 9).
    1: {
      intros Hn1; subst.

    }
    lia. *)
  admit.
Admitted.

Definition lab (n: nat) (s: string): string :=
  String "L" (num2str n s).

Fixpoint clean (cs: string) (acc: string): string :=
  match cs with
  | EmptyString => acc
  | String c cs => if (nat_of_ascii c) <? 43 then clean cs acc else String c (clean cs acc)
  end.

Definition inst2str (i: instr) (s: string): string :=
  match i with
  | Const r imm => "movq $" ++ num2str (w2n imm) (", " ++ reg2str r s)
  | Mov dst src => "movq " ++ reg2str src (", " ++ reg2str dst s)
  | Add dst src => "addq " ++ reg2str src (", " ++ reg2str dst s)
  | Sub dst src => "subq " ++ reg2str src (", " ++ reg2str dst s)
  | Div r => "divq " ++ reg2str r s
  | Jump Always n => "jmp " ++ lab n s
  | Jump (Equal r1 r2) n =>
      "cmpq " ++ reg2str r2 (", " ++ reg2str r1 (" ; je " ++ lab n s))
  | Jump (Less r1 r2) n =>
      "cmpq " ++ reg2str r2 (", " ++ reg2str r1 (" ; jb " ++ lab n s))
  | Call n => "call " ++ lab n s
  | Ret => "ret" ++ s
  | Pop r => "popq " ++ reg2str r s
  | Push r => "pushq " ++ reg2str r s
  | Load_RSP r n => "movq " ++ num2str (8 * n) ("(%rsp), " ++ reg2str r s)
  | Store_RSP r n => "movq " ++ num2str (8 * n) (reg2str r ("(%rsp), " ++ s))
  | Add_RSP n => "addq $" ++ num2str (8 * n) (", %rsp" ++ s)
  | Sub_RSP n => "subq $" ++ num2str (8 * n) (", %rsp" ++ s)
  | Store src a w =>
      "movq " ++ reg2str src (", " ++ num2str (w2n4 w) ("(" ++ reg2str a (")" ++ s)))
  | Load dst a w =>
      "movq " ++ num2str (w2n4 w) ("(" ++ reg2str a ("), " ++ reg2str dst s))
  | GetChar => "movq stdin(%rip), %rdi ; call _IO_getc@PLT" ++ s
  | PutChar => "movq stdout(%rip), %rsi ; call _IO_putc@PLT" ++ s
  | Exit => "call exit@PLT" ++ s
  | Comment c => "\n\n\t/* " ++ clean (string_of_list_ascii c) (" */" ++ s)
  end.

Fixpoint instrs2str (n: nat) (is: asm): string :=
  match is with
  | [] => EmptyString
  | i :: is =>
    lab n (String ":" (String "009" (inst2str i (String "010" (instrs2str (n+1) is)))))
  end.

Definition asm2str (is: asm): string := String.concat ""
    ["\t.bss\n";
     "\t.p2align 3          /* 8-byte align        */\n";
     "heapS:\n";
     "\t.space 8*1024*1024  /* bytes of heap space */\n";
     "\t.p2align 3          /* 8-byte align        */\n";
     "heapE:\n\n";
     "\t.text\n";
     "\t.globl main\n";
     "main:\n";
     "\tsubq $8, %rsp        /* 16-byte align %rsp */\n";
     "\tmovabs $heapS, %r14  /* r14 := heap start  */\n";
     "\tmovabs $heapE, %r15  /* r15 := heap end    */\n\n"]%string
    ++ instrs2str 0 is.
