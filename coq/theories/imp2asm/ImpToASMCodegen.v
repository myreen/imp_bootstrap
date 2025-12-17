From impboot Require Import utils.Core.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import ZArith.
Require Import FunInd.
Require Import Ascii.

Require Import impboot.automation.ltac2.UnfoldFix.
Require Import Ltac2.Ltac2.

Open Scope app_list_scope.
Open Scope nat.

Notation asm_appl := (app_list instr).

Notation v_stack := (list (option name)).
Notation f_lookup := (list (name * nat)).

(* Generates the initialization code for execution *)
Definition init (k: nat): asm :=
  [
    (*  0 *) ASMSyntax.Const RAX (word.of_Z (Z.of_nat 0));
    (*  1 *) ASMSyntax.Const R12 (word.of_Z (Z.of_nat 16));
    (*  2 *) ASMSyntax.Const R13 (word.of_Z (Z.of_N (2^63 - 1)));
    (* jump to main function *)
    (*  3 *) ASMSyntax.Call k;
    (* return to exit 0 *)
    (*  4 *) ASMSyntax.Const RDI (word.of_Z (Z.of_nat 0));
    (*  5 *) ASMSyntax.Exit;
    (* alloc routine starts here: *)
    (*  6 *) ASMSyntax.Comment "malloc";
    (*  7 *) ASMSyntax.Mov RAX R15;
    (*  8 *) ASMSyntax.Sub RAX R14;
    (*  9 *) ASMSyntax.Jump (ASMSyntax.Less R15 R14) 15;
    (* 10 *) ASMSyntax.Jump (ASMSyntax.Less RAX RDI) 15;
    (* 11 *) ASMSyntax.Mov RAX R14;
    (* 12 *) ASMSyntax.Add R14 RDI;
    (* 13 *) ASMSyntax.Ret;
    (* give up: *)
    (* 14 *) ASMSyntax.Comment "exit 4"; (* Internal error – OOM or compiler limitation *)
    (* 15 *) ASMSyntax.Push R15; (* align stack *)
    (* 16 *) ASMSyntax.Const RDI (word.of_Z (Z.of_nat 4));
    (* 17 *) ASMSyntax.Exit;
    (* abort: *)
    (* 18 *) ASMSyntax.Comment "exit 1"; (* Internal error – OOM or compiler limitation *)
    (* 19 *) ASMSyntax.Push R15; (* align stack *)
    (* 20 *) ASMSyntax.Const RDI (word.of_Z (Z.of_nat 1));
    (* 21 *) ASMSyntax.Exit
  ]%string.

Definition allocLoc: nat := 7.

(* START boilerplate *)

Fixpoint list_length {A: Type} (l: list A): nat :=
  match l with
  | x :: l => 
    let/d rec := list_length l in
    let/d res := 1 + rec in 
    res
  | [] => 0
  end.
Theorem list_length_equation: ltac2:(unfold_fix_type '@list_length).
Proof. unfold_fix_proof '@list_length. Qed.

Fixpoint list_append {A: Type} (l1 l2: list A): list A :=
  match l1 with
  | x :: l1 =>
    let/d rec := list_append l1 l2 in
    let/d res := x :: rec in
    res
  | [] => l2
  end.
Theorem list_append_equation: ltac2:(unfold_fix_type '@list_append).
Proof. unfold_fix_proof '@list_append. Qed.

Fixpoint flatten {A: Type} (xs: app_list A): list A :=
  match xs with
  | List l => l
  | Append l1 l2 =>
    let/d flatten_l1 := flatten l1 in
    let/d flatten_l2 := flatten l2 in
    let/d res := list_append flatten_l1 flatten_l2 in
    res
  end.
Theorem flatten_equation: ltac2:(unfold_fix_type '@flatten).
Proof. unfold_fix_proof '@flatten. Qed.

Fixpoint app_list_length {A: Type} (xs: app_list A): nat :=
  match xs with
  | List l => 
    let/d res := list_length l in
    res
  | Append l1 l2 =>
    let/d app_list_length_l1 := app_list_length l1 in
    let/d app_list_length_l2 := app_list_length l2 in
    let/d res := app_list_length_l1 + app_list_length_l2 in
    res
  end.
Theorem app_list_length_equation: ltac2:(unfold_fix_type '@app_list_length).
Proof. unfold_fix_proof '@app_list_length. Qed.

(* END boilerplate *)

Fixpoint even_len {A: Type} (xs: list A): bool :=
  match xs with
  | nil => true
  | _ :: ys =>
    match ys with
    | nil => false
    | _ :: zs => 
      let/d res := even_len zs in
      res
    end
  end.
Theorem even_len_equation: ltac2:(unfold_fix_type '@even_len).
Proof. unfold_fix_proof '@even_len. Qed.

Fixpoint odd_len {A: Type} (xs: list A) : bool :=
  match xs with
  | nil => false
  | _ :: ys =>
    match ys with
    | nil => true
    | _ :: zs => 
      let/d res := odd_len zs in
      res
    end
  end.
Theorem odd_len_equation: ltac2:(unfold_fix_type '@odd_len).
Proof. unfold_fix_proof '@odd_len. Qed.

(* jump label for failure cases
  b – does the stack need to be aligned
*)
Definition give_up (b: bool): nat := 
  let/d res := if b then 15 else 16 in
  res.

Definition abortLoc: nat := 19.

(* Compiles a constant value into assembly instructions *)
Definition c_const (n : word64) (l : nat) : asm_appl * nat :=
  let/d l1 := l + 2 in
  let/d push_rax := ASMSyntax.Push RAX in
  let/d const_rax := ASMSyntax.Const RAX n in
  let/d asm1 := [push_rax; const_rax] in
  let/d asm1 := List asm1 in
  let/d res := (asm1, l1) in
  res.

(* Finds the index of a variable in a stack representation *)
Fixpoint index_of (vs: v_stack) (n: name) (k: nat): nat :=
  match vs with
  | nil => k
  | x :: vs =>
    match x with
      | None =>
        let/d k1 := k + 1 in
        let/d res := index_of vs n k1 in
        res
      | Some v => 
        if N.eqb v n then
          k
        else
          let k1 := k + 1 in
          let/d res := index_of vs n k1 in
          res
    end
  end.
Theorem index_of_equation: ltac2:(unfold_fix_type '@index_of).
Proof. unfold_fix_proof '@index_of. Qed.

Fixpoint index_of_opt (vs: v_stack) (n: name) (k: nat): option nat :=
  match vs with
  | nil =>
    let/d none := None in
    none
  | x :: vs =>
    match x with
    | None =>
      let/d k1 := k + 1 in
      let/d res := index_of_opt vs n k1 in
      res
    | Some v =>
      if N.eqb v n then
        let/d res := Some k in
        res
      else
        let/d k1 := k + 1 in
        let/d res := index_of_opt vs n k1 in
        res
    end
  end.
Theorem index_of_opt_equation: ltac2:(unfold_fix_type '@index_of_opt).
Proof. unfold_fix_proof '@index_of_opt. Qed.

(* lookup variable with name `n`, based on stack `vs` *)
Definition c_var (n: name) (l: nat) (vs: v_stack): asm_appl * nat :=
  let/d k := index_of vs n 0 in
  if (k =? 0)%nat then
    let/d l1 := l + 1 in
    let/d push_rax := ASMSyntax.Push RAX in
    let/d asm1 := [push_rax] in
    let/d asm1 := List asm1 in
    let/d res := (asm1, l1) in
    res
  else
    let/d l1 := l + 2 in
    let/d push_rax := ASMSyntax.Push RAX in
    let/d load_rsp_rax := ASMSyntax.Load_RSP RAX k in
    let/d asm1 := [push_rax; load_rsp_rax] in
    let/d asm1 := List asm1 in
    let/d res := (asm1, l1) in
    res.

(* Fixpoint c_declare_binders_rec (binders: list name) (l: nat) (vs: v_stack) (acc_asm: asm_appl): (asm_appl * nat * v_stack) :=
  match binders with
  | nil => (acc_asm, l, vs)
  | binder_name :: binders =>
    c_declare_binders_rec binders (l + 1) ((Some binder_name) :: vs) (acc_asm +++ List [ASMSyntax.Push RDI])
  end.

Definition c_declare_binders (binders: list name) (l: nat) (vs: v_stack): (asm_appl * nat * v_stack) :=
  let/d '(asm1, l1, vs1) := c_declare_binders_rec binders (l + 1) vs (List []) in
  (asm1 +++ List [ASMSyntax.Const RDI (word.of_Z (Z.of_nat 0))], l1, vs1). *)

(* assign variable with name `n`, based on stack *)
Definition c_assign (n : name) (l : nat) (vs : v_stack) : (asm_appl * nat) :=
  let/d k := index_of vs n 0 in
  match k return (asm_appl * nat) with
  | 0%nat =>
    let/d l1 := l + 1 in
    let/d pop_rdi := ASMSyntax.Pop RDI in
    let/d asm1 := [pop_rdi] in
    let/d asm1 := List asm1 in
    let/d res := (asm1, l1) in
    res
  | S _ =>
    let/d l1 := l + 2 in
    let/d store_rsp_rax := ASMSyntax.Store_RSP RAX k in
    let/d pop_rax := ASMSyntax.Pop RAX in
    let/d asm1 := [store_rsp_rax; pop_rax] in
    let/d asm1 := List asm1 in
    let/d res := (asm1, l1) in
    res
  end.

(*
  RAX := RAX + top_of_stack
*)
Definition c_add: asm_appl :=
  let/d pop_rdi := ASMSyntax.Pop RDI in
  let/d add_rax_rdi := ASMSyntax.Add RAX RDI in
  let/d asm1 := [pop_rdi; add_rax_rdi] in
  let/d res := List asm1 in
  res.

(*
  RAX := top_of_stack - RAX (or 0 if the result would be negative)
*)
Definition c_sub: asm_appl :=
  let/d pop_rdi := ASMSyntax.Pop RDI in
  let/d sub_rdi_rax := ASMSyntax.Sub RDI RAX in
  let/d mov_rax_rdi := ASMSyntax.Mov RAX RDI in
  let/d asm1 := [pop_rdi; sub_rdi_rax; mov_rax_rdi] in
  let/d res := List asm1 in
  res.

(*
  RAX := RAX / top_of_stack
  RDX := RAX % top_of_stack
*)
Definition c_div: asm_appl :=
  let/d mov_rdi_rax := ASMSyntax.Mov RDI RAX in
  let/d pop_rax := ASMSyntax.Pop RAX in
  let/d const_rdx := ASMSyntax.Const RDX (word.of_Z (Z.of_nat 0)) in
  let/d div_rdi := ASMSyntax.Div RDI in
  let/d asm1 := [mov_rdi_rax; pop_rax; const_rdx; div_rdi] in
  let/d res := List asm1 in
  res.

Definition c_alloc (vs: v_stack): asm_appl :=
  let/d mov_rdi_rax := Mov RDI RAX in
  let/d call_alloc := ASMSyntax.Call allocLoc in
  let/d asm1 := [mov_rdi_rax; call_alloc] in
  let/d res := List asm1 in
  res.

Definition c_read (vs: v_stack) (l: nat): (asm_appl * nat) :=
  let/d push_rax := Push RAX in
  let/d get_char := ASMSyntax.GetChar in
  let/d asm_list := [push_rax; get_char] in
  let/d asm1 := List asm_list in
  let/d asm_len := app_list_length asm1 in
  let/d l1 := (l + asm_len)%nat in
  let/d res := (asm1, l1) in
  res.

Definition c_write (vs: v_stack) (l: nat): (asm_appl * nat) :=
  let/d mov_rdi_rax := Mov RDI RAX in
  let/d put_char := ASMSyntax.PutChar in
  let/d pop_rax := Pop RAX in
  let/d asm_list := [mov_rdi_rax; put_char; pop_rax] in
  let/d asm1 := List asm_list in
  let/d asm_len := app_list_length asm1 in
  let/d l1 := (l + asm_len)%nat in
  let/d res := (asm1, l1) in
  res.

(*
  input : RAX, top_of_stack
  RAX := top_of_stack[RAX]
  i.e.
  load (into)RAX (RAX + top of stack) 0w
*)
Definition c_load: asm_appl :=
  let/d pop_rdi := ASMSyntax.Pop RDI in
  let/d add_rdi_rax := ASMSyntax.Add RDI RAX in
  let/d load_rax_rdi := ASMSyntax.Load RAX RDI (word.of_Z (Z.of_nat 0)) in
  let/d asm1 := [pop_rdi; add_rdi_rax; load_rax_rdi] in
  let/d res := List asm1 in
  res.

(*
  input : RAX, top_of_stack, snd_top_of_stack
  snd_top_of_stack[top_of_stack] := RAX
*)
Definition c_store: asm_appl :=
  let/d pop_rdi := ASMSyntax.Pop RDI in
  let/d pop_rdx := ASMSyntax.Pop RDX in
  let/d add_rdi_rdx := ASMSyntax.Add RDI RDX in
  let/d store_rax_rdi := ASMSyntax.Store RAX RDI (word.of_Z (Z.of_nat 0)) in
  let/d pop_rax := ASMSyntax.Pop RAX in
  let/d asm1 := [pop_rdi; pop_rdx; add_rdi_rdx; store_rax_rdi; pop_rax] in
  let/d res := List asm1 in
  res.

Fixpoint c_exp (e: exp) (l: nat) (vs: v_stack): asm_appl * nat :=
  match e with
  | Var n => c_var n l vs
  | Const n => c_const n l
  | Add e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d c_add_asm := c_add in
    let/d asm_combined := asm1 +++ asm2 +++ c_add_asm in
    let/d c_add_len := app_list_length c_add_asm in
    let/d l3 := l2 + c_add_len in
    let/d res := (asm_combined, l3) in
    res
  | Sub e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d c_sub_asm := c_sub in
    let/d asm_combined := asm1 +++ asm2 +++ c_sub_asm in
    let/d c_sub_len := app_list_length c_sub_asm in
    let/d l3 := l2 + c_sub_len in
    let/d res := (asm_combined, l3) in
    res
  | Div e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d asm_combined := asm1 +++ asm2 +++ c_div in
    let/d c_div_len := app_list_length c_div in
    let/d l3 := l2 + c_div_len in
    let/d res := (asm_combined, l3) in
    res
  | Read e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d asm_combined := asm1 +++ asm2 +++ c_load in
    let/d c_load_len := app_list_length c_load in
    let/d l3 := l2 + c_load_len in
    let/d res := (asm_combined, l3) in
    res
  end.
Theorem c_exp_equation: ltac2:(unfold_fix_type '@c_exp).
Proof. unfold_fix_proof '@c_exp. Qed.

Fixpoint c_exps (es: list exp) (l: nat) (vs: v_stack): asm_appl * nat :=
  match es with
  | [] => 
    let/d empty_list := List [] in
    let/d res := (empty_list, l) in
    res
  | e :: es' =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exps es' l1 vs1 in
    let/d asm_combined := asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  end.
Theorem c_exps_equation: ltac2:(unfold_fix_type '@c_exps).
Proof. unfold_fix_proof '@c_exps. Qed.

(*
  RDI `cmp` RBX
*)
Definition c_cmp (c: cmp) : cond :=
  match c with
  | Less => ASMSyntax.Less RDI RBX
  | Equal => ASMSyntax.Equal RDI RBX
  end.

Fixpoint c_test_jump (t: test) (pos_label: nat) (neg_label: nat)
  (l: nat) (vs: v_stack): asm_appl * nat :=
  match t with
  | Test c e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d mov_rbx_rax := Mov RBX RAX in
    let/d pop_rdi := Pop RDI in
    let/d pop_rax := Pop RAX in
    let/d cmp_cond := c_cmp c in
    let/d jump_pos := ASMSyntax.Jump cmp_cond pos_label in
    let/d jump_neg := ASMSyntax.Jump Always neg_label in
    let/d c_cmp_list := [mov_rbx_rax; pop_rdi; pop_rax; jump_pos; jump_neg] in
    let/d c_cmp_asm := List c_cmp_list in
    let/d asm_combined := asm1 +++ asm2 +++ c_cmp_asm in
    let/d c_cmp_len := app_list_length c_cmp_asm in
    let/d l3 := l2 + c_cmp_len in
    let/d res := (asm_combined, l3) in
    res
  | And t1 t2 =>
    let/d l1_label := l + 1 in
    let/d l2_label := l + 2 in
    let/d '(asm1, l1) := c_test_jump t1 l1_label neg_label l2_label vs in
    let/d '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
    let/d jump_always_l2 := ASMSyntax.Jump Always l2_label in
    let/d jump_to_start := List [jump_always_l2] in
    let/d jump_always_l1 := ASMSyntax.Jump Always l1 in
    let/d jump_to_t2 := List [jump_always_l1] in (* l1 is the start of t2*)
    let/d asm_combined := jump_to_start +++ jump_to_t2 +++ asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  | Or t1 t2 =>
    let/d l1_label := l + 1 in
    let/d l2_label := l + 2 in
    let/d '(asm1, l1) := c_test_jump t1 pos_label l1_label l2_label vs in
    let/d '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
    let/d jump_always_l2 := ASMSyntax.Jump Always l2_label in
    let/d jump_to_start := List [jump_always_l2] in
    let/d jump_always_l1 := ASMSyntax.Jump Always l1 in
    let/d jump_to_t2 := List [jump_always_l1] in (* l1 is the start of t2*)
    let/d asm_combined := jump_to_start +++ jump_to_t2 +++ asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  | Not t' =>
    c_test_jump t' neg_label pos_label l vs
  end.
Theorem c_test_jump_equation: ltac2:(unfold_fix_type '@c_test_jump).
Proof. unfold_fix_proof '@c_test_jump. Qed.

(* Looks up a function name in a list of function addresses *)
Fixpoint lookup (fs: f_lookup) (n: N): nat :=
  match fs with
  | [] => 0
  | (x, y) :: xs =>
    if N.eqb x n then
      y
    else
      let/d res := lookup xs n in
      res
  end.
Theorem lookup_equation: ltac2:(unfold_fix_type '@lookup).
Proof. unfold_fix_proof '@lookup. Qed.

(* Drop the current stack frame - elements corresponding to `vs` *)
Definition make_ret (vs: v_stack) (l: nat): asm_appl * nat :=
  let/d vs_len := list_length vs in
  let/d add_rsp := Add_RSP vs_len in
  let/d ret_instr := Ret in
  let/d asm_list := [add_rsp; ret_instr] in
  let/d asm1 := List asm_list in
  let/d l1 := l + 2 in
  let/d res := (asm1, l1) in
  res.

(* Store the variables from the stack in the registers, so that they can be
passed to the function call *)
Definition c_pops (xs: list exp) (vs: v_stack): asm_appl :=
  let/d k := list_length xs in
  if k =? 0 then 
    let/d push_rax := Push RAX in
    let/d asm_list := [push_rax] in
    let/d res := List asm_list in
    res
  else
  if k =? 1 then 
    let/d empty_list := [] in
    let/d res := List empty_list in
    res
  else
  if k =? 2 then 
    let/d pop_rdi := Pop RDI in
    let/d asm_list := [pop_rdi] in
    let/d res := List asm_list in
    res
  else
  if k =? 3 then 
    let/d pop_rdi := Pop RDI in
    let/d pop_rdx := Pop RDX in
    let/d asm_list := [pop_rdi; pop_rdx] in
    let/d res := List asm_list in
    res
  else
  if k =? 4 then 
    let/d pop_rdi := Pop RDI in
    let/d pop_rdx := Pop RDX in
    let/d pop_rbx := Pop RBX in
    let/d asm_list := [pop_rdi; pop_rdx; pop_rbx] in
    let/d res := List asm_list in
    res
  else
  if k =? 5 then 
    let/d pop_rdi := Pop RDI in
    let/d pop_rdx := Pop RDX in
    let/d pop_rbx := Pop RBX in
    let/d pop_rbp := Pop RBP in
    let/d asm_list := [pop_rdi; pop_rdx; pop_rbx; pop_rbp] in
    let/d res := List asm_list in
    res
  else 
    let/d even_xs := even_len xs in
    let/d give_up_label := give_up even_xs in
    let/d jump_always := Jump Always give_up_label in
    let/d asm_list := [jump_always] in
    let/d res := List asm_list in
    res.
(* Some assembly languages and architectures (including x86_64) require aligning
the stack to 16-bytes before function calls. If `vs` is even – we have to push
something to the stack before calling any function. (the first value from the stack is kept in RAX,
so the actual stack size is odd then)
*)

(** Builds a stack representation for parameters of a function *)
Function call_v_stack (xs: list name) (acc: v_stack): v_stack :=
  match xs with
  | [] => acc
  | x :: xs' => call_v_stack xs' (Some x :: acc)
  end.

Definition c_pushes_vs (v_names: list name): list (option name) :=
  match v_names with
  | [] => 
    let/d none_val := None in
    let/d res := [none_val] in
    res
  | _ => 
    let/d empty_list := @nil (option name) in
    let/d res := call_v_stack v_names empty_list in
    res
  end.

(** Push a list of variables onto the stack *)
Definition c_pushes (v_names: list name) (l: nat): (asm_appl * v_stack * nat) :=
  let/d k := list_length v_names in
  let/d e := c_pushes_vs v_names in
  if k =? 0 then 
    let/d empty_list := [] in
    let/d asm1 := List empty_list in
    let/d res := (asm1, e, l) in
    res
  else
  if k =? 1 then 
    let/d empty_list := [] in
    let/d asm1 := List empty_list in
    let/d res := (asm1, e, l) in
    res
  else
  if k =? 2 then 
    let/d push_rdi := Push RDI in
    let/d asm_list := [push_rdi] in
    let/d asm1 := List asm_list in
    let/d l1 := l + 1 in
    let/d res := (asm1, e, l1) in
    res
  else
  if k =? 3 then 
    let/d push_rdx := Push RDX in
    let/d push_rdi := Push RDI in
    let/d asm_list := [push_rdx; push_rdi] in
    let/d asm1 := List asm_list in
    let/d l1 := l + 2 in
    let/d res := (asm1, e, l1) in
    res
  else
  if k =? 4 then 
    let/d push_rbx := Push RBX in
    let/d push_rdx := Push RDX in
    let/d push_rdi := Push RDI in
    let/d asm_list := [push_rbx; push_rdx; push_rdi] in
    let/d asm1 := List asm_list in
    let/d l1 := l + 3 in
    let/d res := (asm1, e, l1) in
    res
  else 
    let/d push_rbp := Push RBP in
    let/d push_rbx := Push RBX in
    let/d push_rdx := Push RDX in
    let/d push_rdi := Push RDI in
    let/d asm_list := [push_rbp; push_rbx; push_rdx; push_rdi] in
    let/d asm1 := List asm_list in
    let/d l1 := l + 4 in
    let/d res := (asm1, e, l1) in
    res.

(* Call the given function, passing the arguments in registers*)
Definition c_call (vs: v_stack) (target: nat) (xs: list exp) (l: nat): asm_appl * nat :=
  let/d asm_pops := c_pops xs vs in
  let/d call_target := ASMSyntax.Call target in
  let/d asm_list := [call_target] in
  let/d asm1 := List asm_list in
  let/d asm_combined := asm_pops +++ asm1 in
  let/d pops_len := app_list_length asm_pops in
  let/d asm1_len := app_list_length asm1 in
  let/d total_len := pops_len + asm1_len in
  let/d l1 := l + total_len in
  let/d res := (asm_combined, l1) in
  res.

Fixpoint c_cmd (c: cmd) (l: nat) (fs: f_lookup) (vs: v_stack): (asm_appl * nat) :=
  match c with
  | Skip => 
    let/d empty_list := [] in
    let/d asm1 := List empty_list in
    let/d res := (asm1, l) in
    res
  | Seq c1 c2 =>
    let/d '(asm1, l1) := c_cmd c1 l fs vs in
    let/d '(asm2, l2) := c_cmd c2 l1 fs vs in
    let/d asm_combined := asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  | Assign n e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := c_assign n l1 vs in
    let/d asm_combined := asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  | Update a e e' =>
    let/d '(asm1, l1) := c_exp a l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e l1 vs1 in
    let/d vs2 := None :: None :: vs in
    let/d '(asm3, l3) := c_exp e' l2 vs2 in
    let/d asm4 := c_store in
    let/d asm_combined := asm1 +++ asm2 +++ asm3 +++ asm4 in
    let/d asm4_len := app_list_length asm4 in
    let/d l4 := l3 + asm4_len in
    let/d res := (asm_combined, l4) in
    res
  | If t c1 c2 =>
    let/d l1_label := l + 1 in
    let/d l2_label := l + 2 in
    let/d l3_label := l + 3 in
    let/d '(asm1, l1) := c_test_jump t l1_label l2_label l3_label vs in
    let/d '(asm2, l2) := c_cmd c1 l1 fs vs in
    let/d l2_plus1 := l2 + 1 in
    let/d '(asm3, l3) := c_cmd c2 l2_plus1 fs vs in
    let/d jump_always_l3 := ASMSyntax.Jump Always l3_label in
    let/d jump_to_test := List[jump_always_l3] in
    let/d jump_always_l1 := ASMSyntax.Jump Always l1 in
    let/d jump_to_c1 := List [jump_always_l1] in
    let/d jump_always_l2_plus1 := ASMSyntax.Jump Always l2_plus1 in
    let/d jump_to_c2 := List [jump_always_l2_plus1] in
    let/d jump_always_l3_end := ASMSyntax.Jump Always l3 in
    let/d jump_to_end := List [jump_always_l3_end] in
    let/d asmres := jump_to_test +++ jump_to_c1 +++ jump_to_c2 +++ asm1 +++ asm2 +++ jump_to_end +++ asm3 in
    let/d res := (asmres, l3) in
    res
  | While tst body =>
    let/d l1_label := l + 1 in
    let/d l2_label := l + 2 in
    let/d l3_label := l + 3 in
    let/d '(asm1, l1) := c_test_jump tst l1_label l2_label l3_label vs in
    let/d '(asm2, l2) := c_cmd body l1 fs vs in
    let/d jump_always_l3 := ASMSyntax.Jump Always l3_label in
    let/d jump_to_tst := List [jump_always_l3] in
    let/d jump_always_l := ASMSyntax.Jump Always l in
    let/d jump_to_beginning := List [jump_always_l] in
    let/d jump_always_l1 := ASMSyntax.Jump Always l1 in
    let/d jump_to_body := List [jump_always_l1] in
    let/d l2_plus1 := l2 + 1 in
    let/d jump_always_l2_plus1 := ASMSyntax.Jump Always l2_plus1 in
    let/d jump_to_end := List [jump_always_l2_plus1] in
    let/d asmres := jump_to_tst +++ jump_to_body +++ jump_to_end +++ asm1 +++ asm2 +++ jump_to_beginning in
    let/d res := (asmres, l2_plus1) in
    res
  | Call n f es =>
    let/d target := lookup fs f in
    let/d '(asms, l1) := c_exps es l vs in
    let/d '(asm1, l2) := c_call vs target es l1 in
    let/d '(asm2, l3) := c_assign n l2 vs in
    let/d asm_combined := asms +++ asm1 +++ asm2 in
    let/d res := (asm_combined, l3) in
    res
  | Return e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := make_ret vs l1 in
    let/d asm_combined := asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  | Alloc n e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d asm2 := c_alloc vs in
    let/d asm2_len := app_list_length asm2 in
    let/d l2 := l1 + asm2_len in
    let/d '(asm3, l3) := c_assign n l2 vs in
    let/d asm_combined := asm1 +++ asm2 +++ asm3 in
    let/d res := (asm_combined, l3) in
    res
  | GetChar n =>
    let/d '(asm1, l1) := c_read vs l in
    let/d '(asm2, l2) := c_assign n l1 vs in
    let/d asm_combined := asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  | PutChar e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := c_write vs l1 in
    let/d asm_combined := asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  | Abort =>
    let/d jump_always_abort := Jump Always abortLoc in
    let/d asm_list := [jump_always_abort] in
    let/d asm1 := List asm_list in
    let/d l1 := l + 1 in
    let/d res := (asm1, l1) in
    res
  end.
Theorem c_cmd_equation: ltac2:(unfold_fix_type '@c_cmd).
Proof. unfold_fix_proof '@c_cmd. Qed.

Fixpoint all_binders (c: cmd): list name :=
  match c with
  | Skip => []
  | Seq c1 c2 => 
    let/d binders_c1 := all_binders c1 in
    let/d binders_c2 := all_binders c2 in
    let/d res := list_append binders_c1 binders_c2 in
    res
  | Assign n e => 
    let/d res := [n] in
    res
  | Update a e e' => []
  | If t c1 c2 => 
    let/d binders_c1 := all_binders c1 in
    let/d binders_c2 := all_binders c2 in
    let/d res := list_append binders_c1 binders_c2 in
    res
  | While tst body => 
    let/d res := all_binders body in
    res
  | Call n f es => 
    let/d res := [n] in
    res
  | Return e => []
  | Alloc n e => 
    let/d res := [n] in
    res
  | GetChar n => 
    let/d res := [n] in
    res
  | PutChar e => []
  | Abort => []
  end.
Theorem all_binders_equation: ltac2:(unfold_fix_type '@all_binders).
Proof. unfold_fix_proof '@all_binders. Qed.

Fixpoint names_contain (l: list name) (a: name): bool :=
  match l with
  | nil => false
  | x :: l =>
    if (x =? a)%N then
      true
    else
      let/d res := names_contain l a in
      res
  end.
Theorem names_contain_equation: ltac2:(unfold_fix_type '@names_contain).
Proof. unfold_fix_proof '@names_contain. Qed.

Fixpoint names_unique (l: list name) (acc: list name): list name :=
  match l with
  | nil => acc
  | x :: xs => 
    let/d contains_check := names_contain acc x in
    let/d x_cons_acc := x :: acc in
    if contains_check then
      let/d res := names_unique xs acc in
      res
    else
      let/d res := names_unique xs x_cons_acc in
      res
  end.
Theorem names_unique_equation: ltac2:(unfold_fix_type '@names_unique).
Proof. unfold_fix_proof '@names_unique. Qed.

Definition unique_binders (c: cmd): list name :=
  let/d binds := all_binders c in
  names_unique binds [].

Fixpoint make_vs_from_binders (binders: list name): v_stack :=
  match binders with
  | nil => nil
  | b :: binders => 
    let/d some_b := Some b in
    let/d rest := make_vs_from_binders binders in
    let/d res := some_b :: rest in
    res
  end.
Theorem make_vs_from_binders_equation: ltac2:(unfold_fix_type '@make_vs_from_binders).
Proof. unfold_fix_proof '@make_vs_from_binders. Qed.

Fixpoint filter_name (a: name) (l: list name): list name :=
  match l with
  | nil => nil
  | x :: xs =>
    if (a =? x)%N then
      let/d res := filter_name a xs in
      res
    else
      let/d rec_call := filter_name a xs in
      let/d x_cons_rec := x :: rec_call in
      x_cons_rec
  end.
Theorem filter_name_equation: ltac2:(unfold_fix_type '@filter_name).
Proof. unfold_fix_proof '@filter_name. Qed.

Fixpoint remove_names (l1 l2: list name): list name :=
  match l1 with
  | nil => l2
  | x :: xs => 
    let/d filtered := filter_name x l2 in
    let/d res := remove_names xs filtered in
    res
  end.
Theorem remove_names_equation: ltac2:(unfold_fix_type '@remove_names).
Proof. unfold_fix_proof '@remove_names. Qed.

Definition c_declare_binders (v_names: list name) (c: cmd): (asm_appl * v_stack) :=
  let/d binders := unique_binders c in
  let/d binders_no_params := remove_names v_names binders in
  let/d vs_binders := make_vs_from_binders binders_no_params in
  (* Make sure that at the start of every command vs (the stack) is odd *)
  let/d vs_pushes := c_pushes_vs v_names in
  let/d vs_after_pushes := list_append vs_pushes vs_binders in
  let/d is_even := even_len vs_after_pushes in
  let/d none_val := None in
  let/d none_list := [none_val] in
  let/d vs_binders1 := if is_even then list_append vs_binders none_list else vs_binders in
  let/d binders1_len := list_length vs_binders1 in
  let/d sub_rsp := Sub_RSP binders1_len in
  let/d asm_list := [sub_rsp] in
  let/d asm1 := List asm_list in
  let/d res := (asm1, vs_binders1) in
  res.

(** Compiles a single function definition into assembly code. *)
Definition c_fundef (fundef: func) (l: nat) (fs: f_lookup): (asm_appl * nat) :=
  match fundef with
  | Func n v_names body =>
    let/d '(asm0, vs_binders1) := c_declare_binders v_names body in
    let/d asm0_len := app_list_length asm0 in
    let/d l0 := l + asm0_len in
    let/d '(asm1, vs1, l1) := c_pushes v_names l0 in
    let/d vs_combined := list_append vs1 vs_binders1 in
    let/d '(asm2, l2) := c_cmd body l1 fs vs_combined in
    let/d asm_combined := asm0 +++ asm1 +++ asm2 in
    let/d res := (asm_combined, l2) in
    res
  end.

Definition nat_modulo (n1 n2: nat): nat :=
  match n2 with
  | 0%nat => 0
  | S _ =>
    let/d d := (n1 / n2) in
    let/d m := n2 * d in
    let/d res := n1 - m in
    res
  end.

Definition N_modulo (n1 n2: N): N :=
  match n2 with
  | 0%N => 0
  | N.pos _ =>
    let/d d := (n1 / n2)%N in
    let/d m := (n2 * d)%N in
    let/d res := (n1 - m)%N in
    res
  end.

(* TODO: Can we use the same helper as with ASMToString.name2str? *)
Definition name2str (n: N) (acc: string): string :=
  let/d n_mod := N_modulo n 256 in
  let/d ascii_val := ascii_of_N n_mod in
  let/d res := String ascii_val acc in
  res.

Definition get_funcs (p: prog): list func :=
  match p with
  | Program funcs => funcs
  end.

Definition name_of_func (f: func) : name :=
  match f with
  | Func n _ _ => n
  end.

(* Compiles a list of function declarations into assembly instructions *)
Fixpoint c_fundefs (ds: list func) (l: nat) (fs: f_lookup): (asm_appl * list (name * nat) * nat) :=
  match ds with
  | [] => 
    let/d empty_list := [] in
    let/d asm1 := List empty_list in
    let/d res := (asm1, fs, l) in
    res
  | d :: ds' =>
    let/d fname := name_of_func d in
    (* TODO: is using name2str as a constant correct? Should we reify it?  *)
    let/d empty_str := ""%string in
    let/d fname_str := name2str fname empty_str in
    let/d comment_instr := Comment fname_str in
    let/d comment_list := [comment_instr] in
    let/d comment := List comment_list in
    let/d l_plus1 := l + 1 in
    let/d '(c1, l1) := c_fundef d l_plus1 fs in
    let/d '(c2, fs', l2) := c_fundefs ds' l1 fs in
    let/d asm_combined := comment +++ c1 +++ c2 in
    let/d fname_pair := (fname, l_plus1) in
    let/d fs_new := fname_pair :: fs' in
    let/d res := (asm_combined, fs_new, l2) in
    res
  end.
Theorem c_fundefs_equation: ltac2:(unfold_fix_type '@c_fundefs).
Proof. unfold_fix_proof '@c_fundefs. Qed.

(* Generates the complete assembly code for a given program *)
Definition codegen (prog : prog) : asm :=
  let/d funs := get_funcs prog in
  let/d zero_val := 0 in
  let/d init_asm := init zero_val in
  let/d init_list := List init_asm in
  let/d init_l := app_list_length init_list in
  let/d empty_fs := [] in
  let/d '(_, fs, _) := c_fundefs funs init_l empty_fs in
  let/d '(asm1, _, _) := c_fundefs funs init_l fs in
  let/d main_str := "main"%string in
  let/d main_name := name_of_string main_str in
  let/d main_l := lookup fs main_name in
  let/d main_init := init main_l in
  let/d main_init_list := List main_init in
  let/d combined_asm := main_init_list +++ asm1 in
  let/d res := flatten combined_asm in
  res.
