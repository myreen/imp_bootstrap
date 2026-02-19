From impboot Require Import assembly.ASMSyntax.
From impboot Require Import utils.Core.
Require Import coqutil.Word.Interface.
From impboot Require Import commons.CompilerUtils.

Open Scope string.

Notation "cst ::: s" :=
  ltac:(match cst with
        | context c[EmptyString] => let c' := context c[s] in exact c'
        | _ => fail "Left string is not constant"
        end) (at level 60, only parsing).

Definition reg2s (r: reg) (str: string): string :=
  match r with
  | RAX => "%rax" ++ str
  | RDI => "%rdi" ++ str
  | RBX => "%rbx" ++ str
  | RBP => "%rbp" ++ str
  | R12 => "%r12" ++ str
  | R13 => "%r13" ++ str
  | R14 => "%r14" ++ str
  | R15 => "%r15" ++ str
  | RDX => "%rdx" ++ str
  end.

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

Definition i2s_con (r: reg) (imm: word64) (str: string): string :=
  "movq $" ++ N2str (Z.to_N (word.unsigned imm)) (", " ++ reg2s r str).

Definition i2s_mov (dst: reg) (src: reg) (str: string): string :=
  "movq " ++ reg2s src (", " ++ reg2s dst str).

Definition i2s_add (dst: reg) (src: reg) (str: string): string :=
  "addq " ++ reg2s src (", " ++ reg2s dst str).

Definition i2s_sub (dst: reg) (src: reg) (str: string): string :=
  "subq " ++ reg2s src (", " ++ reg2s dst str).

Definition i2s_div (r: reg) (str: string): string :=
  "divq " ++ reg2s r str.

Definition i2s_jump (cond: cond) (n: nat) (str: string): string :=
  match cond with
    | Always => "jmp " ++ lab n str
    | Equal r1 r2 =>
      "cmpq " ++ reg2s r2 (", " ++ reg2s r1 (" ; je " ++ lab n str))
    | Less r1 r2 =>
      "cmpq " ++ reg2s r2 (", " ++ reg2s r1 (" ; jb " ++ lab n str))
    end.

Definition i2s_call (n: nat) (str: string): string :=
  "call " ++ lab n str.

Definition i2s_ret (str: string): string :=
  "ret" ++ str.

Definition i2s_pop (r: reg) (str: string): string :=
  "popq " ++ reg2s r str.

Definition i2s_push (r: reg) (str: string): string :=
  "pushq " ++ reg2s r str.

Definition i2s_lrsp (r: reg) (n: nat) (str: string): string :=
  "movq " ++ num2str (8 * n) ("(%rsp), " ++ reg2s r str).

Definition i2s_srsp (r: reg) (n: nat) (str: string): string :=
  "movq " ++ (reg2s r (", " ++ num2str (8 * n) ("(%rsp) " ++ str))).

Definition i2s_arsp (n: nat) (str: string): string :=
  "addq $" ++ num2str (8 * n) (", %rsp" ++ str).

Definition i2s_surs (n: nat) (str: string): string :=
  "subq $" ++ num2str (8 * n) (", %rsp" ++ str).

Definition i2s_stor (src: reg) (a: reg) (w: word4) (str: string): string :=
  "movq " ++ reg2s src (", " ++ N2str (Z.to_N (word.unsigned w)) ("(" ++ reg2s a (")" ++ str))).

Definition i2s_load (dst: reg) (a: reg) (w: word4) (str: string): string :=
  "movq " ++ N2str (Z.to_N (word.unsigned w)) ("(" ++ reg2s a ("), " ++ reg2s dst str)).

Definition i2s_gch (str: string): string :=
  "movq stdin(%rip), %rdi ; call _IO_getc@PLT" ++ str.

Definition i2s_pch (str: string): string :=
  "movq stdout(%rip), %rsi ; call _IO_putc@PLT" ++ str.

Definition i2s_exit (str: string): string :=
  "call exit@PLT" ++ str.

Definition i2s_comm (c: string) (str: string): string :=
  "
  
  	/* " ++ clean c (" */" ++ str).

Definition inst2str (i: instr) (str: string): string :=
  match i with
  | Const r imm =>
    let/d res := i2s_con r imm str in
    res
  | Mov dst src =>
    let/d res := i2s_mov dst src str in
    res
  | ASMSyntax.Add dst src =>
    let/d res := i2s_add dst src str in
    res
  | Sub dst src =>
    let/d res := i2s_sub dst src str in
    res
  | Div r =>
    let/d res := i2s_div r str in
    res
  | Jump cond n =>
    i2s_jump cond n str
  | Call n =>
    let/d res := i2s_call n str in
    res
  | Ret =>
    let/d res := i2s_ret str in
    res
  | Pop r =>
    let/d res := i2s_pop r str in
    res
  | Push r =>
    let/d res := i2s_push r str in
    res
  | Load_RSP r n =>
    let/d res := i2s_lrsp r n str in
    res
  | StoreRSP r n =>
    let/d res := i2s_srsp r n str in
    res
  | Add_RSP n =>
    let/d res := i2s_arsp n str in
    res
  | Sub_RSP n =>
    let/d res := i2s_surs n str in
    res
  | Store src a w =>
    let/d res := i2s_stor src a w str in
    res
  | Load dst a w =>
    let/d res := i2s_load dst a w str in
    res
  | GetChar =>
    let/d res := i2s_gch str in
    res
  | PutChar =>
    let/d res := i2s_pch str in
    res
  | Exit =>
    let/d res := i2s_exit str in
    res
  | Comment c =>
    let/d res := i2s_comm c str in
    res
  end.


Fixpoint is2str (n: nat) (is: asm): string :=
  match is with
  | [] => EmptyString
  | i :: is =>
    lab n (String ":" (String "009" (inst2str i (String "010" (is2str (n+1) is)))))
  end.

Fixpoint ccat_str (ss: list string): string :=
  match ss with
  | [] => EmptyString
  | s :: ss =>
    s ++ ccat_str ss
  end.

Definition asm2str1 :=
  "	.bss
  ".
Definition asm2str2 :=
  "	.p2align 3          /* 8-byte align        */
  ".
Definition asm2str3 :=
  "heapS:
  ".
Definition asm2str4 :=
  "	.space 32*1024*1024  /* bytes of heap space */
  ".
Definition asm2str5 :=
  "	.p2align 3          /* 8-byte align        */
  ".
Definition asm2str6 :=
  "heapE:
  
  ".
Definition asm2str7 :=
  "	.text
  ".
Definition asm2str8 :=
  "	.globl main
  ".
Definition asm2str9 :=
  "main:
  ".
Definition asm2str0 :=
  "	subq $8, %rsp        /* 16-byte align %rsp */
  ".
Definition asm2stra :=
  "	movabs $heapS, %r14  /* r14 := heap start  */
  ".
Definition asm2strb :=
  "	movabs $heapE, %r15  /* r15 := heap end    */
  
  ".

Definition asm2str (is: asm): string := ccat_str
  [asm2str1;
    asm2str2;
    asm2str3;
    asm2str4;
    asm2str5;
    asm2str6;
    asm2str7;
    asm2str8;
    asm2str9;
    asm2str0;
    asm2stra;
    asm2strb
    ]%string
  ++ is2str 0 is.
