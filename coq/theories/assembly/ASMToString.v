From impboot Require Import assembly.ASMSyntax.
From impboot Require Import utils.Core.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
From impboot Require Import imp2asm.ImpToASMCodegen.
From impboot Require Import commons.PrintingUtils.

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

Definition lab (n: nat) (str: string): string :=
  String "L" (num2str n str).

Fixpoint clean (cs: string) (acc: string): string :=
  match cs with
  | EmptyString => acc
  | String c cs =>
    let/d n := nat_of_ascii c in
    if (n <? 43)%nat then
      let/d res := clean cs acc in
      res
    else
      let/d cl := clean cs acc in
      let/d res := String c cl in
      res
  end.

Definition inst2str (i: instr) (str: string): string :=
  match i with
  | Const r imm => "movq $" ++ N2str (Z.to_N (word.unsigned imm)) (", " ++ reg2str r str)
  | Mov dst src => "movq " ++ reg2str src (", " ++ reg2str dst str)
  | ASMSyntax.Add dst src => "addq " ++ reg2str src (", " ++ reg2str dst str)
  | Sub dst src => "subq " ++ reg2str src (", " ++ reg2str dst str)
  | Div r => "divq " ++ reg2str r str
  | Jump cond n =>
    match cond with
    | Always => "jmp " ++ lab n str
    | Equal r1 r2 =>
      "cmpq " ++ reg2str r2 (", " ++ reg2str r1 (" ; je " ++ lab n str))
    | Less r1 r2 =>
      "cmpq " ++ reg2str r2 (", " ++ reg2str r1 (" ; jb " ++ lab n str))
    end
  | Call n => "call " ++ lab n str
  | Ret => "ret" ++ str
  | Pop r => "popq " ++ reg2str r str
  | Push r => "pushq " ++ reg2str r str
  | Load_RSP r n => "movq " ++ num2str (8 * n) ("(%rsp), " ++ reg2str r str)
  | Store_RSP r n => "movq " ++ (reg2str r (", " ++ num2str (8 * n) ("(%rsp), " ++ str)))
  | Add_RSP n => "addq $" ++ num2str (8 * n) (", %rsp" ++ str)
  | Sub_RSP n => "subq $" ++ num2str (8 * n) (", %rsp" ++ str)
  | Store src a w =>
      "movq " ++ reg2str src (", " ++ N2str (Z.to_N (word.unsigned w)) ("(" ++ reg2str a (")" ++ str)))
  | Load dst a w =>
      "movq " ++ N2str (Z.to_N (word.unsigned w)) ("(" ++ reg2str a ("), " ++ reg2str dst str))
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

Fixpoint concat_strings (ss: list string): string :=
  match ss with
  | [] => EmptyString
  | s :: ss =>
    let/d rest := concat_strings ss in
    let/d res := s ++ rest in
    res
  end.

(* TODO: special characters are wrong *)
Definition asm2str (is: asm): string := concat_strings
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
