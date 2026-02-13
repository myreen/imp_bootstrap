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

(* This is named reg2str1, since when I named it reg2str, it reified forever, see example in AsmToStringDerivations.v *)
Definition reg2str1 (r: reg) (str: string): string :=
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

Definition inst2str_const (r: reg) (imm: word64) (str: string): string :=
  "movq $" ++ N2str (Z.to_N (word.unsigned imm)) (", " ++ reg2str1 r str).

Definition inst2str_mov (dst: reg) (src: reg) (str: string): string :=
  "movq " ++ reg2str1 src (", " ++ reg2str1 dst str).

Definition inst2str_add (dst: reg) (src: reg) (str: string): string :=
  "addq " ++ reg2str1 src (", " ++ reg2str1 dst str).

Definition inst2str_sub (dst: reg) (src: reg) (str: string): string :=
  "subq " ++ reg2str1 src (", " ++ reg2str1 dst str).

Definition inst2str_div (r: reg) (str: string): string :=
  "divq " ++ reg2str1 r str.

Definition inst2str_jump (cond: cond) (n: nat) (str: string): string :=
  match cond with
    | Always => "jmp " ++ lab n str
    | Equal r1 r2 =>
      "cmpq " ++ reg2str1 r2 (", " ++ reg2str1 r1 (" ; je " ++ lab n str))
    | Less r1 r2 =>
      "cmpq " ++ reg2str1 r2 (", " ++ reg2str1 r1 (" ; jb " ++ lab n str))
    end.

Definition inst2str_call (n: nat) (str: string): string :=
  "call " ++ lab n str.

Definition inst2str_ret (str: string): string :=
  "ret" ++ str.

Definition inst2str_pop (r: reg) (str: string): string :=
  "popq " ++ reg2str1 r str.

Definition inst2str_push (r: reg) (str: string): string :=
  "pushq " ++ reg2str1 r str.

Definition inst2str_load_rsp (r: reg) (n: nat) (str: string): string :=
  "movq " ++ num2str (8 * n) ("(%rsp), " ++ reg2str1 r str).

Definition inst2str_store_rsp (r: reg) (n: nat) (str: string): string :=
  "movq " ++ (reg2str1 r (", " ++ num2str (8 * n) ("(%rsp) " ++ str))).

Definition inst2str_add_rsp (n: nat) (str: string): string :=
  "addq $" ++ num2str (8 * n) (", %rsp" ++ str).

Definition inst2str_sub_rsp (n: nat) (str: string): string :=
  "subq $" ++ num2str (8 * n) (", %rsp" ++ str).

Definition inst2str_store (src: reg) (a: reg) (w: word4) (str: string): string :=
  "movq " ++ reg2str1 src (", " ++ N2str (Z.to_N (word.unsigned w)) ("(" ++ reg2str1 a (")" ++ str))).

Definition inst2str_load (dst: reg) (a: reg) (w: word4) (str: string): string :=
  "movq " ++ N2str (Z.to_N (word.unsigned w)) ("(" ++ reg2str1 a ("), " ++ reg2str1 dst str)).

Definition inst2str_getchar1 (str: string): string :=
  "movq stdin(%rip), %rdi ; call _IO_getc@PLT" ++ str.

Definition inst2str_putchar (str: string): string :=
  "movq stdout(%rip), %rsi ; call _IO_putc@PLT" ++ str.

Definition inst2str_exit (str: string): string :=
  "call exit@PLT" ++ str.

Definition inst2str_comment (c: string) (str: string): string :=
  "
  
  	/* " ++ clean c (" */" ++ str).

Definition inst2str (i: instr) (str: string): string :=
  match i with
  | Const r imm =>
    let/d res := inst2str_const r imm str in
    res
  | Mov dst src =>
    let/d res := inst2str_mov dst src str in
    res
  | ASMSyntax.Add dst src =>
    let/d res := inst2str_add dst src str in
    res
  | Sub dst src =>
    let/d res := inst2str_sub dst src str in
    res
  | Div r =>
    let/d res := inst2str_div r str in
    res
  | Jump cond n =>
    inst2str_jump cond n str
  | Call n =>
    let/d res := inst2str_call n str in
    res
  | Ret =>
    let/d res := inst2str_ret str in
    res
  | Pop r =>
    let/d res := inst2str_pop r str in
    res
  | Push r =>
    let/d res := inst2str_push r str in
    res
  | Load_RSP r n =>
    let/d res := inst2str_load_rsp r n str in
    res
  | StoreRSP r n =>
    let/d res := inst2str_store_rsp r n str in
    res
  | Add_RSP n =>
    let/d res := inst2str_add_rsp n str in
    res
  | Sub_RSP n =>
    let/d res := inst2str_sub_rsp n str in
    res
  | Store src a w =>
    let/d res := inst2str_store src a w str in
    res
  | Load dst a w =>
    let/d res := inst2str_load dst a w str in
    res
  | GetChar =>
    let/d res := inst2str_getchar1 str in
    res
  | PutChar =>
    let/d res := inst2str_putchar str in
    res
  | Exit =>
    let/d res := inst2str_exit str in
    res
  | Comment c =>
    let/d res := inst2str_comment c str in
    res
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
    s ++ concat_strings ss
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
  "	.space 8*1024*1024  /* bytes of heap space */
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
Definition asm2str10 :=
  "	subq $8, %rsp        /* 16-byte align %rsp */
  ".
Definition asm2str11 :=
  "	movabs $heapS, %r14  /* r14 := heap start  */
  ".
Definition asm2str12 :=
  "	movabs $heapE, %r15  /* r15 := heap end    */
  
  ".

Definition asm2str (is: asm): string := concat_strings
  [asm2str1;
    asm2str2;
    asm2str3;
    asm2str4;
    asm2str5;
    asm2str6;
    asm2str7;
    asm2str8;
    asm2str9;
    asm2str10;
    asm2str11;
    asm2str12
    ]%string
  ++ instrs2str 0 is.
