From impboot Require Import utils.Core.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import impboot.commons.CompilerUtils.
Require Import coqutil.Word.Interface.
Require Import ZArith.
Require Import FunInd.
Require Import Ascii.

Require Import impboot.imperative.Printing.

Require Import impboot.automation.ltac2.UnfoldFix.
Require Import Ltac2.Ltac2.

Open Scope app_list_scope.
Open Scope nat.
Open Scope list.

Notation asm_appl := (app_list instr).

Notation v_stack := (list (option name)).
Notation f_lookup := (list (name * nat)).
(* Generates the initialization code for execution *)
Definition init (k: nat): asm :=
  [
    (*  0 *) ASMSyntax.Const RAX (word.of_Z (Z.of_nat 0));
    (*  1 *) ASMSyntax.Const R12 (word.of_Z (Z.of_nat 16));
    (*                                               vvv (2^63 - 1)%N *)
    (*  2 *) ASMSyntax.Const R13 (word.of_Z (Z.of_N (9223372036854775807)%N));
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

Fixpoint even_len {A: Type} (xs: list A): bool :=
  match xs with
  | nil => true
  | _ :: ys =>
    match ys with
    | nil => false
    | _ :: zs => even_len zs
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
    | _ :: zs => odd_len zs
    end
  end.
Theorem odd_len_equation: ltac2:(unfold_fix_type '@odd_len).
Proof. unfold_fix_proof '@odd_len. Qed.

(* jump label for failure cases
  b – does the stack need to be aligned
*)
Definition give_up (b: bool): nat := 
  if b then 15 else 16.

Definition abortLoc: nat := 19.

(* Compiles a constant value into assembly instructions *)
Definition c_const (n : word64) (l : nat) : asm_appl * nat :=
  (List [ASMSyntax.Push RAX; ASMSyntax.Const RAX n], l + 2).

(* Finds the index of a variable in a stack representation *)
Fixpoint index_of (vs: v_stack) (n: name) (k: nat): nat :=
  match vs with
  | nil => k
  | x :: vs =>
    match x with
    | None =>
      index_of vs n (k + 1)
    | Some v => 
      if N.eqb v n then
        k
      else
        index_of vs n (k + 1)
    end
  end.
Theorem index_of_equation: ltac2:(unfold_fix_type '@index_of).
Proof. unfold_fix_proof '@index_of. Qed.

Fixpoint index_of_opt (vs: v_stack) (n: name) (k: nat): option nat :=
  match vs with
  | nil => None
  | x :: vs =>
    match x with
    | None =>
      index_of_opt vs n (k + 1)
    | Some v =>
      if N.eqb v n then
        Some k
      else
        index_of_opt vs n (k + 1)
    end
  end.
Theorem index_of_opt_equation: ltac2:(unfold_fix_type '@index_of_opt).
Proof. unfold_fix_proof '@index_of_opt. Qed.

(* lookup variable with name `n`, based on stack `vs` *)
Definition c_var (n: name) (l: nat) (vs: v_stack): asm_appl * nat :=
  let/d k := index_of vs n 0 in
  if (k =? 0)%nat then
    (List [ASMSyntax.Push RAX], l + 1)
  else
    (List [ASMSyntax.Push RAX; ASMSyntax.Load_RSP RAX k], l + 2).

(* assign variable with name `n`, based on stack *)
Definition c_assign (n: name) (l: nat) (vs: v_stack): (asm_appl * nat) :=
  let/d k := index_of vs n 0 in
  if k =? 0 then
    (List [ASMSyntax.Pop RDI], l + 1)
  else
    (List [ASMSyntax.StoreRSP RAX k; ASMSyntax.Pop RAX], l + 2).

(*
  RAX := RAX + top_of_stack
*)
Definition c_add: asm_appl :=
  List [ASMSyntax.Pop RDI; ASMSyntax.Add RAX RDI].

(*
  RAX := top_of_stack - RAX (or 0 if the result would be negative)
*)
Definition c_sub: asm_appl :=
  List [ASMSyntax.Pop RDI; ASMSyntax.Sub RDI RAX; ASMSyntax.Mov RAX RDI].

(*
  RAX := RAX / top_of_stack
  RDX := RAX % top_of_stack
*)
Definition c_div: asm_appl :=
  List [ASMSyntax.Mov RDI RAX; ASMSyntax.Pop RAX; ASMSyntax.Const RDX (word.of_Z (Z.of_nat 0)); ASMSyntax.Div RDI].

Definition c_alloc (vs: v_stack): asm_appl :=
  List [Mov RDI RAX; ASMSyntax.Call allocLoc].

Definition c_read (vs: v_stack) (l: nat): (asm_appl * nat) :=
  (List [Push RAX; ASMSyntax.GetChar], l + 2).

Definition c_write (vs: v_stack) (l: nat): (asm_appl * nat) :=
  (List [Mov RDI RAX; ASMSyntax.PutChar; Pop RAX], l + 3).

(*
  input : RAX, top_of_stack
  RAX := top_of_stack[RAX]
  i.e.
  load (into)RAX (RAX + top of stack) 0w
*)
Definition c_load: asm_appl :=
  List [ASMSyntax.Pop RDI; ASMSyntax.Add RDI RAX; ASMSyntax.Load RAX RDI (word.of_Z (Z.of_nat 0))].

(*
  input : RAX, top_of_stack, snd_top_of_stack
  snd_top_of_stack[top_of_stack] := RAX
*)
Definition c_store: asm_appl :=
  List [ASMSyntax.Pop RDI; ASMSyntax.Pop RDX; ASMSyntax.Add RDI RDX; ASMSyntax.Store RAX RDI (word.of_Z (Z.of_nat 0)); ASMSyntax.Pop RAX].

Fixpoint c_exp (e: exp) (l: nat) (vs: v_stack): asm_appl * nat :=
  match e with
  | Var n => c_var n l vs
  | Const n => c_const n l
  | Add e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d c_add_asm := c_add in
    let/d c_add_len := app_list_length c_add_asm in
    let/d l3 := l2 + c_add_len in
    (asm1 +++ asm2 +++ c_add_asm, l3)
  | Sub e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d c_sub_asm := c_sub in
    let/d c_sub_len := app_list_length c_sub_asm in
    let/d l3 := l2 + c_sub_len in
    (asm1 +++ asm2 +++ c_sub_asm, l3)
  | Div e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d cdiv := c_div in
    let/d c_div_len := app_list_length cdiv in
    let/d l3 := l2 + c_div_len in
    (asm1 +++ asm2 +++ cdiv, l3)
  | Read e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d cload := c_load in
    let/d c_load_len := app_list_length cload in
    let/d l3 := l2 + c_load_len in
    (asm1 +++ asm2 +++ cload, l3)
  end.
Theorem c_exp_equation: ltac2:(unfold_fix_type '@c_exp).
Proof. unfold_fix_proof '@c_exp. Qed.

Fixpoint c_exps (es: list exp) (l: nat) (vs: v_stack): asm_appl * nat :=
  match es with
  | [] => 
    (List [], l)
  | e :: es' =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exps es' l1 vs1 in
    (asm1 +++ asm2, l2)
  end.
Theorem c_exps_equation: ltac2:(unfold_fix_type '@c_exps).
Proof. unfold_fix_proof '@c_exps. Qed.

(*
  RDI `cmp` RBX
*)
Definition c_cmp (c: cmp) : cond :=
  match c with
  | Less =>
    ASMSyntax.Less RDI RBX
  | Equal =>
    ASMSyntax.Equal RDI RBX
  end.

Fixpoint c_test_jump (t: test) (pos_label: nat) (neg_label: nat)
  (l: nat) (vs: v_stack): asm_appl * nat :=
  match t with
  | Test c e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d vs1 := None :: vs in
    let/d '(asm2, l2) := c_exp e2 l1 vs1 in
    let/d cmp_cond := c_cmp c in
    let/d c_cmp_asm := List [Mov RBX RAX; Pop RDI; Pop RAX; ASMSyntax.Jump cmp_cond pos_label; ASMSyntax.Jump Always neg_label] in
    let/d c_cmp_len := app_list_length c_cmp_asm in
    let/d l3 := l2 + c_cmp_len in
    (asm1 +++ asm2 +++ c_cmp_asm, l3)
  | And t1 t2 =>
    let/d l1_label := l + 1 in
    let/d l2_label := l + 2 in
    let/d '(asm1, l1) := c_test_jump t1 l1_label neg_label l2_label vs in
    let/d '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
    let/d asm0 := List [ASMSyntax.Jump Always l2_label; ASMSyntax.Jump Always l1] in
    (asm0 +++ asm1 +++ asm2, l2)
  | Or t1 t2 =>
    let/d l1_label := l + 1 in
    let/d l2_label := l + 2 in
    let/d '(asm1, l1) := c_test_jump t1 pos_label l1_label l2_label vs in
    let/d '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
    let/d asm0 := List [ASMSyntax.Jump Always l2_label; ASMSyntax.Jump Always l1] in
    (asm0 +++ asm1 +++ asm2, l2)
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
      lookup xs n
  end.
Theorem lookup_equation: ltac2:(unfold_fix_type '@lookup).
Proof. unfold_fix_proof '@lookup. Qed.

(* Drop the current stack frame - elements corresponding to `vs` *)
Definition make_ret (vs: v_stack) (l: nat): asm_appl * nat :=
  let/d vs_len := list_length vs in
  (List [Add_RSP vs_len; Ret], l + 2).

(* Store the variables from the stack in the registers, so that they can be
passed to the function call *)
Definition c_pops (xs: list exp) (vs: v_stack): asm_appl :=
  let/d k := list_length xs in
  if k =? 0 then 
    List [Push RAX]
  else if k =? 1 then 
    List []
  else if k =? 2 then 
    List [Pop RDI]
  else if k =? 3 then 
    List [Pop RDI; Pop RDX]
  else if k =? 4 then 
    List [Pop RDI; Pop RDX; Pop RBX]
  else if k =? 5 then 
    List [Pop RDI; Pop RDX; Pop RBX; Pop RBP]
  else
    let/d even_xs := even_len xs in
    List [Jump Always (give_up even_xs)].
(* Some assembly languages and architectures (including x86_64) require aligning
the stack to 16-bytes before function calls. If `vs` is even – we have to push
something to the stack before calling any function. (the first value from the stack is kept in RAX,
so the actual stack size is odd then)
*)

(** Builds a stack representation for parameters of a function *)
Fixpoint call_v_stack (xs: list name) (acc: v_stack): v_stack :=
  match xs with
  | [] => acc
  | x :: xs' =>
    let/d some_x := Some x in
    let/d x_acc := some_x :: acc in
    call_v_stack xs' x_acc
  end.
Theorem call_v_stack_equation: ltac2:(unfold_fix_type '@call_v_stack).
Proof. unfold_fix_proof '@call_v_stack. Qed.

Definition c_pushes_vs (v_names: list name): list (option name) :=
  let/d len := list_length v_names in
  if len =? 0 then [None]
  else
    call_v_stack v_names (@nil (option name)).
(** Push a list of variables onto the stack *)
Definition c_pushes (v_names: list name) (l: nat): (asm_appl * v_stack * nat) :=
  let/d k := list_length v_names in
  let/d e := c_pushes_vs v_names in
  if k =? 0 then 
    ((List [], e), l)
  else if k =? 1 then 
    ((List [], e), l)
  else if k =? 2 then 
    ((List [Push RDI], e), l + 1)
  else if k =? 3 then 
    ((List [Push RDX; Push RDI], e), l + 2)
  else if k =? 4 then 
    ((List [Push RBX; Push RDX; Push RDI], e), l + 3)
  else 
    ((List [Push RBP; Push RBX; Push RDX; Push RDI], e), l + 4).

(* Call the given function, passing the arguments in registers*)
Definition c_call (vs: v_stack) (target: nat) (xs: list exp) (l: nat): asm_appl * nat :=
  let/d asm_pops := c_pops xs vs in
  let/d asm_combined := asm_pops +++ List [ASMSyntax.Call target] in
  let/d total_len := app_list_length asm_pops + 1 in
  (asm_combined, l + total_len).

Fixpoint c_cmd (c: cmd) (l: nat) (fs: f_lookup) (vs: v_stack): (asm_appl * nat) :=
  match c with
  | Skip => 
    (List [], l)
  | Seq c1 c2 =>
    let/d '(asm1, l1) := c_cmd c1 l fs vs in
    let/d '(asm2, l2) := c_cmd c2 l1 fs vs in
    (asm1 +++ asm2, l2)
  | Assign n e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := c_assign n l1 vs in
    (asm1 +++ asm2, l2)
  | Update a e e' =>
    let/d '(asm1, l1) := c_exp a l vs in
    let/d '(asm2, l2) := c_exp e l1 (None :: vs) in
    let/d '(asm3, l3) := c_exp e' l2 (None :: None :: vs) in
    let/d asm4_len := app_list_length c_store in
    (asm1 +++ asm2 +++ asm3 +++ c_store, l3 + asm4_len)
  | If t c1 c2 =>
    let/d l1_label := l + 1 in
    let/d l2_label := l + 2 in
    let/d l3_label := l + 3 in
    let/d '(asm1, l1) := c_test_jump t l1_label l2_label l3_label vs in
    let/d '(asm2, l2) := c_cmd c1 l1 fs vs in
    let/d '(asm3, l3) := c_cmd c2 (l2 + 1) fs vs in
    let/d asm_combined := List [ASMSyntax.Jump Always l3_label;
                          ASMSyntax.Jump Always l1;
                          ASMSyntax.Jump Always (l2 + 1)] +++ 
                          asm1 +++ asm2 +++ 
                          List [ASMSyntax.Jump Always l3] +++ asm3 in
    (asm_combined, l3)
  | While tst body =>
    let/d l1_label := l + 1 in
    let/d l2_label := l + 2 in
    let/d l3_label := l + 3 in
    let/d '(asm1, l1) := c_test_jump tst l1_label l2_label l3_label vs in
    let/d '(asm2, l2) := c_cmd body l1 fs vs in
    let/d asm_combined := List [ASMSyntax.Jump Always l3_label] +++ 
                          List [ASMSyntax.Jump Always l1] +++ 
                          List [ASMSyntax.Jump Always (l2 + 1)] +++ 
                          asm1 +++ asm2 +++ 
                          List [ASMSyntax.Jump Always l] in
    (asm_combined, l2 + 1)
  | Call n f es =>
    let/d '(asms, l1) := c_exps es l vs in
    let/d '(asm1, l2) := c_call vs (lookup fs f) es l1 in
    let/d '(asm2, l3) := c_assign n l2 vs in
    (asms +++ asm1 +++ asm2, l3)
  | Return e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := make_ret vs l1 in
    (asm1 +++ asm2, l2)
  | Alloc n e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d asm2_len := app_list_length (c_alloc vs) in
    let/d '(asm3, l3) := c_assign n (l1 + asm2_len) vs in
    (asm1 +++ c_alloc vs +++ asm3, l3)
  | GetChar n =>
    let/d '(asm1, l1) := c_read vs l in
    let/d '(asm2, l2) := c_assign n l1 vs in
    (asm1 +++ asm2, l2)
  | PutChar e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := c_write vs l1 in
    (asm1 +++ asm2, l2)
  | Abort =>
    (List [Jump Always abortLoc], l + 1)
  end.
Theorem c_cmd_equation: ltac2:(unfold_fix_type '@c_cmd).
Proof. unfold_fix_proof '@c_cmd. Qed.

Fixpoint all_binders (c: cmd): list name :=
  match c with
  | Skip =>
    let/d l := [] in
    l
  | Seq c1 c2 => 
    list_append (all_binders c1) (all_binders c2)
  | Assign n e => [n]
  | Update a e e' =>
    let/d l := [] in
    l
  | If t c1 c2 => 
    list_append (all_binders c1) (all_binders c2)
  | While tst body => 
    all_binders body
  | Call n f es => [n]
  | Return e =>
    let/d l := [] in
    l
  | Alloc n e => [n]
  | GetChar n => [n]
  | PutChar e =>
    let/d l := [] in
    l
  | Abort =>
    let/d l := [] in
    l
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
      names_contain l a
  end.
Theorem names_contain_equation: ltac2:(unfold_fix_type '@names_contain).
Proof. unfold_fix_proof '@names_contain. Qed.

Fixpoint names_unique (l: list name) (acc: list name): list name :=
  match l with
  | nil => acc
  | x :: xs =>
    let/d acc_contains_x := names_contain acc x in
    if acc_contains_x then
      names_unique xs acc
    else
      names_unique xs (x :: acc)
  end.
Theorem names_unique_equation: ltac2:(unfold_fix_type '@names_unique).
Proof. unfold_fix_proof '@names_unique. Qed.

Definition unique_binders (c: cmd): list name :=
  names_unique (all_binders c) [].

Fixpoint make_vs_from_binders (binders: list name): v_stack :=
  match binders with
  | nil => nil
  | b :: binders => 
    Some b :: make_vs_from_binders binders
  end.
Theorem make_vs_from_binders_equation: ltac2:(unfold_fix_type '@make_vs_from_binders).
Proof. unfold_fix_proof '@make_vs_from_binders. Qed.

Fixpoint filter_name (a: name) (l: list name): list name :=
  match l with
  | nil => let/d l := [] in l
  | x :: xs =>
    if (a =? x)%N then
      filter_name a xs
    else
      x :: filter_name a xs
  end.
Theorem filter_name_equation: ltac2:(unfold_fix_type '@filter_name).
Proof. unfold_fix_proof '@filter_name. Qed.

Fixpoint remove_names (l1 l2: list name): list name :=
  match l1 with
  | nil => l2
  | x :: xs => 
    remove_names xs (filter_name x l2)
  end.
Theorem remove_names_equation: ltac2:(unfold_fix_type '@remove_names).
Proof. unfold_fix_proof '@remove_names. Qed.

Definition get_vs_binders (vs_after_pushes: v_stack) (vs_binders: v_stack): v_stack :=
  let/d cond := even_len vs_after_pushes in
  if cond then
    let/d vs_binders1 := list_append vs_binders [None] in
    vs_binders1
  else
    vs_binders.

Definition c_declare_binders (v_names: list name) (c: cmd): (asm_appl * v_stack) :=
  let/d vs_binders := make_vs_from_binders (remove_names v_names (unique_binders c)) in
  let/d vs_after_pushes := list_append (c_pushes_vs v_names) vs_binders in
  let/d cond := even_len vs_after_pushes in
  let/d vs_binders1 := get_vs_binders vs_after_pushes vs_binders in
  (List [Sub_RSP (List.length vs_binders1)], vs_binders1).

(** Compiles a single function definition into assembly code. *)
Definition c_fundef (fundef: func) (l: nat) (fs: f_lookup): (asm_appl * nat) :=
  match fundef with
  | Func n v_names body =>
    let/d '(asm0, vs_binders1) := c_declare_binders v_names body in
    let/d l0 := l + app_list_length asm0 in
    let/d '(asm1, vs1, l1) := c_pushes v_names l0 in
    let/d '(asm2, l2) := c_cmd body l1 fs (list_append vs1 vs_binders1) in
    (asm0 +++ asm1 +++ asm2, l2)
  end.

Definition get_funcs (prg: prog): list func :=
  match prg with
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
    (List [], fs, l)
  | d :: ds' =>
    let/d fname := name_of_func d in
    let/d '(c1, l1) := c_fundef d (l + 1) fs in
    let/d '(c2, fs', l2) := c_fundefs ds' (l1 + 1) fs in
    let/d comment := List [Comment (N2ascii_default fname)] in
    (comment +++ c1 +++ List [Ret] +++ c2, (fname, (l + 1)) :: fs', l2)
  end.
Theorem c_fundefs_equation: ltac2:(unfold_fix_type '@c_fundefs).
Proof. unfold_fix_proof '@c_fundefs. Qed.

(* Generates the complete assembly code for a given program *)
Definition codegen (prog : prog) : asm :=
  let/d funs := get_funcs prog in
  let/d init_list := List (init 0) in
  let/d init_l := app_list_length init_list in
  let/d '(_, fs, _) := c_fundefs funs init_l [] in
  let/d '(asm1, _, _) := c_fundefs funs init_l fs in
  (*                        vvv (name_of_string ("main"%string)) *)
  let/d main_l := lookup fs 1835100526%N in
  let/d main_init_list := List (init main_l) in
  flatten (main_init_list +++ asm1).
