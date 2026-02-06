From impboot Require Import assembly.ASMSyntax.
From impboot Require Import utils.Core.
Require Import impboot.utils.Words4Naive.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
From impboot Require Import imp2asm.ImpToASMCodegen.
From impboot Require Import commons.CompilerUtils.

Open Scope string.

(* This is named reg2str1, since when I named it reg2str1, it reified forever, see example in AsmToStringDerivations.v *)
Definition reg2str1 (r: reg) (str: string): string :=
  match r with
  | RAX =>
    let/d rs := "%rax" in
    let/d res := rs ++ str in
    res
  | RDI =>
    let/d rs := "%rdi" in
    let/d res := rs ++ str in
    res
  | RBX =>
    let/d rs := "%rbx" in
    let/d res := rs ++ str in
    res
  | RBP =>
    let/d rs := "%rbp" in
    let/d res := rs ++ str in
    res
  | R12 =>
    let/d rs := "%r12" in
    let/d res := rs ++ str in
    res
  | R13 =>
    let/d rs := "%r13" in
    let/d res := rs ++ str in
    res
  | R14 =>
    let/d rs := "%r14" in
    let/d res := rs ++ str in
    res
  | R15 =>
    let/d rs := "%r15" in
    let/d res := rs ++ str in
    res
  | RDX =>
    let/d rs := "%rdx" in
    let/d res := rs ++ str in
    res
  end.

Definition lab (n: nat) (str: string): string :=
  let/d num := num2str n str in
  let/d res := String "L" num in
  res.

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
  let/d prefix := "movq $" in
  let/d imm_n := Z.to_N (word.unsigned imm) in
  let/d comma_str := ", " in
  let/d reg_str := reg2str1 r str in
  let/d comma_reg := comma_str ++ reg_str in
  let/d imm_str := N2str imm_n comma_reg in
  let/d res := prefix ++ imm_str in
  res.

Definition inst2str_mov (dst: reg) (src: reg) (str: string): string :=
  let/d prefix := "movq " in
  let/d comma_str := ", " in
  let/d dst_str := reg2str1 dst str in
  let/d comma_dst := comma_str ++ dst_str in
  let/d src_comma_dst := reg2str1 src  comma_dst in
  let/d res := prefix ++ src_comma_dst in
  res.

Definition inst2str_add (dst: reg) (src: reg) (str: string): string :=
  let/d prefix := "addq " in
  let/d comma_str := ", " in
  let/d dst_str := reg2str1 dst str in
  let/d comma_dst := comma_str ++ dst_str in
  let/d src_comma_dst := reg2str1 src comma_dst in
  let/d res := prefix ++ src_comma_dst in
  res.

Definition inst2str_sub (dst: reg) (src: reg) (str: string): string :=
  let/d prefix := "subq " in
  let/d comma_str := ", " in
  let/d dst_str := reg2str1 dst str in
  let/d comma_dst := comma_str ++ dst_str in
  let/d src_comma_dst := reg2str1 src comma_dst in
  let/d res := prefix ++ src_comma_dst in
  res.

Definition inst2str_div (r: reg) (str: string): string :=
  let/d prefix := "divq " in
  let/d r_str := reg2str1 r str in
  let/d res := prefix ++ r_str in
  res.

Definition inst2str_jump_always (n: nat) (str: string): string :=
  let/d prefix := "jmp " in
  let/d lab_str := lab n str in
  let/d res := prefix ++ lab_str in
  res.

Definition inst2str_jump_equal (r1: reg) (r2: reg) (n: nat) (str: string): string :=
  let/d cmpq_prefix := "cmpq " in
  let/d comma_str := ", " in
  let/d je_prefix := " ; je " in
  let/d lab_str := lab n str in
  let/d je_lab := je_prefix ++ lab_str in
  let/d r1_str := reg2str1 r1 je_lab in
  let/d comma_r1 := comma_str ++ r1_str in
  let/d r2_comma_r1 := reg2str1 r2 comma_r1 in
  let/d res := cmpq_prefix ++ r2_comma_r1 in
  res.

Definition inst2str_jump_less (r1: reg) (r2: reg) (n: nat) (str: string): string :=
  let/d cmpq_prefix := "cmpq " in
  let/d comma_str := ", " in
  let/d jb_prefix := " ; jb " in
  let/d lab_str := lab n str in
  let/d jb_lab := jb_prefix ++ lab_str in
  let/d r1_str := reg2str1 r1 jb_lab in
  let/d comma_r1 := comma_str ++ r1_str in
  let/d r2_comma_r1 := reg2str1 r2 comma_r1 in
  let/d res := cmpq_prefix ++ r2_comma_r1 in
  res.

Definition inst2str_call (n: nat) (str: string): string :=
  let/d prefix := "call " in
  let/d lab_str := lab n str in
  let/d res := prefix ++ lab_str in
  res.

Definition inst2str_ret (str: string): string :=
  let/d prefix := "ret" in
  let/d res := prefix ++ str in
  res.

Definition inst2str_pop (r: reg) (str: string): string :=
  let/d prefix := "popq " in
  let/d r_str := reg2str1 r str in
  let/d res := prefix ++ r_str in
  res.

Definition inst2str_push (r: reg) (str: string): string :=
  let/d prefix := "pushq " in
  let/d r_str := reg2str1 r str in
  let/d res := prefix ++ r_str in
  res.

Definition inst2str_load_rsp (r: reg) (n: nat) (str: string): string :=
  let/d prefix := "movq " in
  let/d mult_const := 8 in
  let/d offset := mult_const * n in
  let/d rsp_prefix := "(%rsp), " in
  let/d r_str := reg2str1 r str in
  let/d rsp_r := rsp_prefix ++ r_str in
  let/d offset_str := num2str offset rsp_r in
  let/d res := prefix ++ offset_str in
  res.

Definition inst2str_store_rsp (r: reg) (n: nat) (str: string): string :=
  let/d prefix := "movq " in
  let/d comma_str := ", " in
  let/d mult_const := 8 in
  let/d offset := mult_const * n in
  let/d rsp_suffix := "(%rsp), " in
  let/d rsp_suffix_str := rsp_suffix ++ str in
  let/d offset_str := num2str offset rsp_suffix_str in
  let/d comma_offset := comma_str ++ offset_str in
  let/d r_str := reg2str1 r comma_offset in
  let/d res := prefix ++ r_str in
  res.

Definition inst2str_add_rsp (n: nat) (str: string): string :=
  let/d prefix := "addq $" in
  let/d mult_const := 8 in
  let/d offset := mult_const * n in
  let/d rsp_suffix := ", %rsp" in
  let/d rsp_suffix_str := rsp_suffix ++ str in
  let/d offset_str := num2str offset rsp_suffix_str in
  let/d res := prefix ++ offset_str in
  res.

Definition inst2str_sub_rsp (n: nat) (str: string): string :=
  let/d prefix := "subq $" in
  let/d mult_const := 8 in
  let/d offset := mult_const * n in
  let/d rsp_suffix := ", %rsp" in
  let/d rsp_suffix_str := rsp_suffix ++ str in
  let/d offset_str := num2str offset rsp_suffix_str in
  let/d res := prefix ++ offset_str in
  res.

Definition inst2str_store (src: reg) (a: reg) (w: word4) (str: string): string :=
  let/d prefix := "movq " in
  let/d comma_str := ", " in
  let/d w_n := Z.to_N (word.unsigned w) in
  let/d paren_open := "(" in
  let/d paren_close := ")" in
  let/d paren_close_str := paren_close ++ str in
  let/d a_str := reg2str1 a paren_close_str in
  let/d paren_a := paren_open ++ a_str in
  let/d w_str := N2str w_n paren_a in
  let/d comma_w := comma_str ++ w_str in
  let/d src_comma_w := reg2str1 src comma_w in
  let/d res := prefix ++ src_comma_w in
  res.

Definition inst2str_load (dst: reg) (a: reg) (w: word4) (str: string): string :=
  let/d prefix := "movq " in
  let/d w_n := Z.to_N (word.unsigned w) in
  let/d paren_open := "(" in
  let/d paren_close := "), " in
  let/d dst_str := reg2str1 dst str in
  let/d paren_close_dst := paren_close ++ dst_str in
  let/d a_str := reg2str1 a paren_close_dst in
  let/d paren_a := paren_open ++ a_str in
  let/d w_str := N2str w_n paren_a in
  let/d res := prefix ++ w_str in
  res.

Definition inst2str_getchar1 (str: string): string :=
  let/d movq_part := "movq st" in
  let/d din_part := "din(%ri" in
  let/d p_part := "p), %rd" in
  let/d i_part := "i ; cal" in
  let/d l_part := "l _IO_g" in
  let/d etc_part := "etc@PLT" in
  let/d temp1 := movq_part ++ din_part in
  let/d temp2 := temp1 ++ p_part in
  let/d temp3 := temp2 ++ i_part in
  let/d temp4 := temp3 ++ l_part in
  let/d prefix := temp4 ++ etc_part in
  let/d res := prefix ++ str in
  res.

Definition inst2str_putchar (str: string): string :=
  let/d movq_part := "movq st" in
  let/d dout_part := "dout(%r" in
  let/d ip_part := "ip), %r" in
  let/d si_part := "si ; ca" in
  let/d ll_part := "ll _IO_" in
  let/d putc_part := "putc@PL" in
  let/d t_part := "T" in
  let/d temp1 := movq_part ++ dout_part in
  let/d temp2 := temp1 ++ ip_part in
  let/d temp3 := temp2 ++ si_part in
  let/d temp4 := temp3 ++ ll_part in
  let/d temp5 := temp4 ++ putc_part in
  let/d prefix := temp5 ++ t_part in
  let/d res := prefix ++ str in
  res.

Definition inst2str_exit (str: string): string :=
  let/d call_part := "call ex" in
  let/d it_part := "it@PLT" in
  let/d prefix := call_part ++ it_part in
  let/d res := prefix ++ str in
  res.

Definition inst2str_comment (c: string) (str: string): string :=
  let/d newline := "
  
  	/* " in
  let/d suffix := " */" in
  let/d suffix_str := suffix ++ str in
  let/d clean_c := clean c suffix_str in
  let/d res := newline ++ clean_c in
  res.

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
    match cond with
    | Always =>
      let/d res := inst2str_jump_always n str in
      res
    | Equal r1 r2 =>
      let/d res := inst2str_jump_equal r1 r2 n str in
      res
    | Less r1 r2 =>
      let/d res := inst2str_jump_less r1 r2 n str in
      res
    end
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
  | [] =>
    let/d res := EmptyString in
    res
  | i :: is =>
    let/d colon := ":"%char in
    let/d tab_char := "009"%char in
    let/d newline_char := "010"%char in
    let/d next_n := n + 1 in
    let/d rest_str := instrs2str next_n is in
    let/d newline_rest := String newline_char rest_str in
    let/d inst_str := inst2str i newline_rest in
    let/d tab_inst := String tab_char inst_str in
    let/d colon_tab_inst := String colon tab_inst in
    let/d result := lab n colon_tab_inst in
    result
  end.

Fixpoint concat_strings (ss: list string): string :=
  match ss with
  | [] =>
    let/d res := EmptyString in
    res
  | s :: ss =>
    let/d rest := concat_strings ss in
    let/d res := s ++ rest in
    res
  end.

Definition asm2str_header1: list string :=
  let/d dot_bss := "	.bss
  " in
  let/d bss_str := dot_bss in
  let/d dot_p2a := "	.p2alig" in
  let/d n3_spc := "n 3    " in
  let/d comment1 := "      " in
  let/d comment2 := "  /* 8-" in
  let/d comment3 := "byte al" in
  let/d comment4 := "ign    " in
  let/d comment5 := "    */
  " in
  let/d p2align_temp2 := dot_p2a ++ n3_spc in
  let/d p2align_temp3 := p2align_temp2 ++ comment1 in
  let/d p2align_temp4 := p2align_temp3 ++ comment2 in
  let/d p2align_temp5 := p2align_temp4 ++ comment3 in
  let/d p2align_temp6 := p2align_temp5 ++ comment4 in
  let/d p2align_temp7 := p2align_temp6 ++ comment5 in
  let/d p2align1_str := p2align_temp7 in
  let/d heaps_lbl := "heapS:
  " in
  let/d space_cmd := "	.space " in
  let/d size_str := "8*1024*" in
  let/d size_str2 := "1024  /" in
  let/d comment6 := "* bytes" in
  let/d comment7 := " of hea" in
  let/d comment8 := "p space" in
  let/d comment9 := " */
  " in
  let/d space_temp2 := space_cmd ++ size_str in
  let/d space_temp3 := space_temp2 ++ size_str2 in
  let/d space_temp4 := space_temp3 ++ comment6 in
  let/d space_temp5 := space_temp4 ++ comment7 in
  let/d space_temp6 := space_temp5 ++ comment8 in
  let/d space_temp7 := space_temp6 ++ comment9 in
  let/d space_str := space_temp7 in
  let/d list1 := [bss_str; p2align1_str; heaps_lbl; space_str] in
  list1.

Definition asm2str_header2: list string :=
  let/d dot_p2a := "	.p2alig" in
  let/d n3_spc := "n 3    " in
  let/d comment1 := "      " in
  let/d comment2 := "  /* 8-" in
  let/d comment3 := "byte al" in
  let/d comment4 := "ign    " in
  let/d comment5 := "    */
  " in
  let/d p2align2_temp2 := dot_p2a ++ n3_spc in
  let/d p2align2_temp3 := p2align2_temp2 ++ comment1 in
  let/d p2align2_temp4 := p2align2_temp3 ++ comment2 in
  let/d p2align2_temp5 := p2align2_temp4 ++ comment3 in
  let/d p2align2_temp6 := p2align2_temp5 ++ comment4 in
  let/d p2align2_temp7 := p2align2_temp6 ++ comment5 in
  let/d p2align2_str := p2align2_temp7 in
  let/d heape_lbl := "heapE:" in
  let/d double_nl := "
    
    " in
  let/d heapE_str := heape_lbl ++ double_nl in
  let/d dot_text := "	.text
  " in
  let/d dot_globl := "	.globl " in
  let/d main_lbl := "main
  " in
  let/d globl_str := dot_globl ++ main_lbl in
  let/d list2 := [p2align2_str; heapE_str; dot_text; globl_str] in
  list2.

Definition asm2str_header3: list string :=
  let/d main_colon := "main:
  " in
  let/d subq_cmd := "	subq $8" in
  let/d rsp_part := ", %rsp " in
  let/d align_cmt1 := "       " in
  let/d align_cmt2 := "/* 16-b" in
  let/d align_cmt3 := "yte ali" in
  let/d align_cmt4 := "gn %rsp" in
  let/d align_cmt5 := " */
  " in
  let/d subq_temp2 := subq_cmd ++ rsp_part in
  let/d subq_temp3 := subq_temp2 ++ align_cmt1 in
  let/d subq_temp4 := subq_temp3 ++ align_cmt2 in
  let/d subq_temp5 := subq_temp4 ++ align_cmt3 in
  let/d subq_temp6 := subq_temp5 ++ align_cmt4 in
  let/d subq_temp7 := subq_temp6 ++ align_cmt5 in
  let/d subq_str := subq_temp7 in
  let/d movabs1_cmd := "	movabs " in
  let/d heaps_ref := "$heapS," in
  let/d r14_reg := " %r14  " in
  let/d heap_cmt1 := "/* r14 " in
  let/d heap_cmt2 := ":= heap" in
  let/d heap_cmt3 := " start " in
  let/d heap_cmt4 := " */
  " in
  let/d movabs1_temp2 := movabs1_cmd ++ heaps_ref in
  let/d movabs1_temp3 := movabs1_temp2 ++ r14_reg in
  let/d movabs1_temp4 := movabs1_temp3 ++ heap_cmt1 in
  let/d movabs1_temp5 := movabs1_temp4 ++ heap_cmt2 in
  let/d movabs1_temp6 := movabs1_temp5 ++ heap_cmt3 in
  let/d movabs1_temp7 := movabs1_temp6 ++ heap_cmt4 in
  let/d movabs1_str := movabs1_temp7 in
  let/d heape_ref := "$heapE," in
  let/d r15_reg := " %r15  " in
  let/d heap_cmt5 := ":= heap" in
  let/d heap_cmt6 := " end   " in
  let/d final_nl := "
    
    " in
  let/d movabs2_temp2 := movabs1_cmd ++ heape_ref in
  let/d movabs2_temp3 := movabs2_temp2 ++ r15_reg in
  let/d movabs2_temp4 := movabs2_temp3 ++ heap_cmt1 in
  let/d movabs2_temp5 := movabs2_temp4 ++ heap_cmt5 in
  let/d movabs2_temp6 := movabs2_temp5 ++ heap_cmt6 in
  let/d movabs2_temp7 := movabs2_temp6 ++ heap_cmt4 in
  let/d movabs2_str := movabs2_temp7 ++ final_nl in
  let/d list3 := [main_colon; subq_str; movabs1_str; movabs2_str] in
  list3.

Definition asm2str (is: asm): string := 
  let/d list1 := asm2str_header1 in
  let/d list2 := asm2str_header2 in
  let/d list3 := asm2str_header3 in
  let/d list12 := list_append list1 list2 in
  let/d header_list := list_append list12 list3 in
  let/d header_str := concat_strings header_list in
  let/d zero_val := 0 in
  let/d instrs_str := instrs2str zero_val is in
  let/d res := header_str ++ instrs_str in
  res.
