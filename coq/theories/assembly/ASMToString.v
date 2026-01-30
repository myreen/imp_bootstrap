From impboot Require Import assembly.ASMSyntax.
From impboot Require Import utils.Core.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
From impboot Require Import imp2asm.ImpToASMCodegen.
From impboot Require Import commons.PrintingUtils.

Open Scope string.

(* This is named reg2str1, since when I named it reg2str, it reified forever, see example in AsmToStringDerivations.v *)
Definition reg2str1 (r: reg) (str: string): string :=
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
  | Const r imm => 
    let prefix := "movq $" in
    let imm_unsigned := word.unsigned imm in
    let imm_n := Z.to_N imm_unsigned in
    let comma_str := ", " in
    let reg_str := reg2str1 r str in
    let comma_reg := comma_str ++ reg_str in
    let imm_str := N2str imm_n comma_reg in
    prefix ++ imm_str
  | Mov dst src => 
    let prefix := "movq " in
    let src_str := reg2str1 src in
    let comma_str := ", " in
    let dst_str := reg2str1 dst str in
    let comma_dst := comma_str ++ dst_str in
    let src_comma_dst := src_str comma_dst in
    prefix ++ src_comma_dst
  | ASMSyntax.Add dst src => 
    let prefix := "addq " in
    let src_str := reg2str1 src in
    let comma_str := ", " in
    let dst_str := reg2str1 dst str in
    let comma_dst := comma_str ++ dst_str in
    let src_comma_dst := src_str comma_dst in
    prefix ++ src_comma_dst
  | Sub dst src => 
    let prefix := "subq " in
    let src_str := reg2str1 src in
    let comma_str := ", " in
    let dst_str := reg2str1 dst str in
    let comma_dst := comma_str ++ dst_str in
    let src_comma_dst := src_str comma_dst in
    prefix ++ src_comma_dst
  | Div r => 
    let prefix := "divq " in
    let r_str := reg2str1 r str in
    prefix ++ r_str
  | Jump cond n =>
    match cond with
    | Always => 
      let prefix := "jmp " in
      let lab_str := lab n str in
      prefix ++ lab_str
    | Equal r1 r2 =>
      let cmpq_prefix := "cmpq " in
      let r2_str := reg2str1 r2 in
      let comma_str := ", " in
      let je_prefix := " ; je " in
      let lab_str := lab n str in
      let je_lab := je_prefix ++ lab_str in
      let r1_str := reg2str1 r1 je_lab in
      let comma_r1 := comma_str ++ r1_str in
      let r2_comma_r1 := r2_str comma_r1 in
      cmpq_prefix ++ r2_comma_r1
    | Less r1 r2 =>
      let cmpq_prefix := "cmpq " in
      let r2_str := reg2str1 r2 in
      let comma_str := ", " in
      let jb_prefix := " ; jb " in
      let lab_str := lab n str in
      let jb_lab := jb_prefix ++ lab_str in
      let r1_str := reg2str1 r1 jb_lab in
      let comma_r1 := comma_str ++ r1_str in
      let r2_comma_r1 := r2_str comma_r1 in
      cmpq_prefix ++ r2_comma_r1
    end
  | Call n => 
    let prefix := "call " in
    let lab_str := lab n str in
    prefix ++ lab_str
  | Ret => 
    let prefix := "ret" in
    prefix ++ str
  | Pop r => 
    let prefix := "popq " in
    let r_str := reg2str1 r str in
    prefix ++ r_str
  | Push r => 
    let prefix := "pushq " in
    let r_str := reg2str1 r str in
    prefix ++ r_str
  | Load_RSP r n => 
    let prefix := "movq " in
    let mult_const := 8 in
    let offset := mult_const * n in
    let rsp_prefix := "(%rsp), " in
    let r_str := reg2str1 r str in
    let rsp_r := rsp_prefix ++ r_str in
    let offset_str := num2str offset rsp_r in
    prefix ++ offset_str
  | Store_RSP r n => 
    let prefix := "movq " in
    let comma_str := ", " in
    let mult_const := 8 in
    let offset := mult_const * n in
    let rsp_suffix := "(%rsp), " in
    let rsp_suffix_str := rsp_suffix ++ str in
    let offset_str := num2str offset rsp_suffix_str in
    let comma_offset := comma_str ++ offset_str in
    let r_str := reg2str1 r comma_offset in
    prefix ++ r_str
  | Add_RSP n => 
    let prefix := "addq $" in
    let mult_const := 8 in
    let offset := mult_const * n in
    let rsp_suffix := ", %rsp" in
    let rsp_suffix_str := rsp_suffix ++ str in
    let offset_str := num2str offset rsp_suffix_str in
    prefix ++ offset_str
  | Sub_RSP n => 
    let prefix := "subq $" in
    let mult_const := 8 in
    let offset := mult_const * n in
    let rsp_suffix := ", %rsp" in
    let rsp_suffix_str := rsp_suffix ++ str in
    let offset_str := num2str offset rsp_suffix_str in
    prefix ++ offset_str
  | Store src a w =>
    let prefix := "movq " in
    let src_str := reg2str1 src in
    let comma_str := ", " in
    let w_unsigned := word.unsigned w in
    let w_n := Z.to_N w_unsigned in
    let paren_open := "(" in
    let paren_close := ")" in
    let paren_close_str := paren_close ++ str in
    let a_str := reg2str1 a paren_close_str in
    let paren_a := paren_open ++ a_str in
    let w_str := N2str w_n paren_a in
    let comma_w := comma_str ++ w_str in
    let src_comma_w := src_str comma_w in
    prefix ++ src_comma_w
  | Load dst a w =>
    let prefix := "movq " in
    let w_unsigned := word.unsigned w in
    let w_n := Z.to_N w_unsigned in
    let paren_open := "(" in
    let paren_close := "), " in
    let dst_str := reg2str1 dst str in
    let paren_close_dst := paren_close ++ dst_str in
    let a_str := reg2str1 a paren_close_dst in
    let paren_a := paren_open ++ a_str in
    let w_str := N2str w_n paren_a in
    prefix ++ w_str
  | GetChar => 
    let prefix := "movq stdin(%rip), %rdi ; call _IO_getc@PLT" in
    prefix ++ str
  | PutChar => 
    let prefix := "movq stdout(%rip), %rsi ; call _IO_putc@PLT" in
    prefix ++ str
  | Exit => 
    let prefix := "call exit@PLT" in
    prefix ++ str
  | Comment c => 
    let newline := "
    
    	/* " in
    let suffix := " */" in
    let suffix_str := suffix ++ str in
    let clean_c := clean c suffix_str in
    newline ++ clean_c
  end.

Fixpoint instrs2str (n: nat) (is: asm): string :=
  match is with
  | [] => EmptyString
  | i :: is =>
    let colon := ":"%char in
    let tab_char := "009"%char in
    let newline_char := "010"%char in
    let next_n := n + 1 in
    let rest_str := instrs2str next_n is in
    let newline_rest := String newline_char rest_str in
    let inst_str := inst2str i newline_rest in
    let tab_inst := String tab_char inst_str in
    let colon_tab_inst := String colon tab_inst in
    let result := lab n colon_tab_inst in
    result
  end.

Fixpoint concat_strings (ss: list string): string :=
  match ss with
  | [] => EmptyString
  | s :: ss =>
    let/d rest := concat_strings ss in
    let/d res := s ++ rest in
    res
  end.

Definition asm2str (is: asm): string := concat_strings
  ["	.bss
  ";
    "	.p2align 3          /* 8-byte align        */
    ";
    "heapS:
    ";
    "	.space 8*1024*1024  /* bytes of heap space */
    ";
    "	.p2align 3          /* 8-byte align        */
    ";
    "heapE:
    
    ";
    "	.text
    ";
    "	.globl main
    ";
    "main:
    ";
    "	subq $8, %rsp        /* 16-byte align %rsp */
    ";
    "	movabs $heapS, %r14  /* r14 := heap start  */
    ";
    "	movabs $heapE, %r15  /* r15 := heap end    */
    
    "]%string
  ++ instrs2str 0 is.
