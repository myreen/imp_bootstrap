From impboot Require Import assembly.ASMSyntax.
From impboot Require Import utils.Core.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
From impboot Require Import imp2asm.ImpToASMCodegen.

Open Scope string.

Definition reg2str (r: reg) (str: string): string :=
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
  end ++ str.

Fixpoint num2str_f (n: nat) (fuel: nat) (str: string): string :=
  if (n <? 10)%nat then String (ascii_of_nat (48 + n)) str
  else match fuel with
  | 0 => ""
  | S fuel => num2str_f (n / 10) fuel (String (ascii_of_nat (48 + (nat_modulo n 10))) str)
  end.

Theorem num2str_terminates_str: forall (n1: nat) (n: nat) (str: string),
  n <= n1 -> num2str_f n n1 str <> ""%string.
Proof.
  induction n1; intros; simpl; [inversion H; simpl; congruence|].
  destruct (n <? 10)%nat; [congruence|].
  specialize Nat.divmod_spec with (x := n) (y := 9) (q := 0) (u := 9) as ?.
  destruct Nat.divmod eqn:?; simpl.
  eapply IHn1.
  lia.
Qed.

Definition num2str (n: nat) (str: string): string :=
  num2str_f n n str.

Theorem num2str_terminates: forall (n: nat) (str: string),
  num2str n str <> ""%string.
Proof.
  intros; eapply num2str_terminates_str; lia.
Qed.

Definition lab (n: nat) (str: string): string :=
  String "L" (num2str n str).

Fixpoint clean (cs: string) (acc: string): string :=
  match cs with
  | EmptyString => acc
  | String c cs => if ((nat_of_ascii c) <? 43)%nat then clean cs acc else String c (clean cs acc)
  end.

Definition inst2str (i: instr) (str: string): string :=
  match i with
  | Const r imm => "movq $" ++ num2str (w2n imm) (", " ++ reg2str r str)
  | Mov dst src => "movq " ++ reg2str src (", " ++ reg2str dst str)
  | ASMSyntax.Add dst src => "addq " ++ reg2str src (", " ++ reg2str dst str)
  | Sub dst src => "subq " ++ reg2str src (", " ++ reg2str dst str)
  | Div r => "divq " ++ reg2str r str
  | Jump Always n => "jmp " ++ lab n str
  | Jump (Equal r1 r2) n =>
      "cmpq " ++ reg2str r2 (", " ++ reg2str r1 (" ; je " ++ lab n str))
  | Jump (Less r1 r2) n =>
      "cmpq " ++ reg2str r2 (", " ++ reg2str r1 (" ; jb " ++ lab n str))
  | Call n => "call " ++ lab n str
  | Ret => "ret" ++ str
  | Pop r => "popq " ++ reg2str r str
  | Push r => "pushq " ++ reg2str r str
  | Load_RSP r n => "movq " ++ num2str (8 * n) ("(%rsp), " ++ reg2str r str)
  | Store_RSP r n => "movq " ++ num2str (8 * n) (reg2str r ("(%rsp), " ++ str))
  | Add_RSP n => "addq $" ++ num2str (8 * n) (", %rsp" ++ str)
  | Sub_RSP n => "subq $" ++ num2str (8 * n) (", %rsp" ++ str)
  | Store src a w =>
      "movq " ++ reg2str src (", " ++ num2str (w2n4 w) ("(" ++ reg2str a (")" ++ str)))
  | Load dst a w =>
      "movq " ++ num2str (w2n4 w) ("(" ++ reg2str a ("), " ++ reg2str dst str))
  | GetChar => "movq stdin(%rip), %rdi ; call _IO_getc@PLT" ++ str
  | PutChar => "movq stdout(%rip), %rsi ; call _IO_putc@PLT" ++ str
  | Exit => "call exit@PLT" ++ str
  | Comment c => "\n\n\t/* " ++ clean c (" */" ++ str)
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
