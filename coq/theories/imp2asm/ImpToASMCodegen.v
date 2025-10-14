From impboot Require Import utils.Core.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import ZArith.
Require Import FunInd.

Open Scope app_list_scope.

Notation asm_appl := (app_list instr).

Notation v_stack := (list (option name)).
Notation f_lookup := (list (name * nat)).

(* Generates the initialization code for execution *)
Definition init (k : nat) : asm :=
  [
    (*  0 *) ASMSyntax.Const RAX (word.of_Z (Z.of_nat 0));
    (*  1 *) ASMSyntax.Const R12 (word.of_Z (Z.of_nat 16));
    (*  2 *) ASMSyntax.Const R13 (word.of_Z (Z.of_nat (2^63 - 1)));
    (* jump to main function *)
    (*  3 *) ASMSyntax.Call k;
    (* return to exit 0 *)
    (*  4 *) ASMSyntax.Const RDI (word.of_Z (Z.of_nat 0));
    (*  5 *) ASMSyntax.Exit;
    (* alloc routine starts here: *)
    (*  6 *) ASMSyntax.Comment "malloc";
    (*  7 *) ASMSyntax.Mov RDI RAX;
    (*  8 *) ASMSyntax.Mov RAX R14;
    (*  9 *) ASMSyntax.Add R14 RDI;
    (* 10 *) ASMSyntax.Jump (ASMSyntax.Less R15 R14) 14;
    (* 11 *) ASMSyntax.Comment "noop";
    (* 12 *) ASMSyntax.Ret;
    (* give up: *)
    (* 13 *) ASMSyntax.Comment "exit 4"; (* Internal error – OOM or compiler limitation *)
    (* 14 *) ASMSyntax.Push R15; (* align stack *)
    (* 15 *) ASMSyntax.Const RDI (word.of_Z (Z.of_nat 4));
    (* 16 *) ASMSyntax.Exit;
    (* abort: *)
    (* 17 *) ASMSyntax.Comment "exit 1"; (* Internal error – OOM or compiler limitation *)
    (* 18 *) ASMSyntax.Push R15; (* align stack *)
    (* 19 *) ASMSyntax.Const RDI (word.of_Z (Z.of_nat 1));
    (* 20 *) ASMSyntax.Exit
  ].

Definition AllocLoc : nat := 7.

Function even_len (xs: v_stack): bool :=
  match xs with
  | nil => true
  | _ :: ys =>
    match ys with
    | nil => false
    | _ :: zs => even_len zs
    end
  end.

Function even_len_exp (xs: list exp): bool :=
  match xs with
  | nil => true
  | _ :: ys =>
    match ys with
    | nil => false
    | _ :: zs => even_len_exp zs
    end
  end.

Function odd_len (xs: v_stack) : bool :=
  match xs with
  | nil => false
  | _ :: ys =>
    match ys with
    | nil => true
    | _ :: zs => odd_len zs
    end
  end.

(* jump label for failure cases
  b – does the stack need to be aligned
*)
Definition give_up (b : bool) : nat := if b then 14 else 15.

(* abort
  b – does the stack need to be aligned
*)
Definition abort (b : bool) : nat := if b then 18 else 19.

(* Compiles a constant value into assembly instructions *)
Definition c_const (n : word64) (l : nat) : asm_appl * nat :=
  (List [ASMSyntax.Push RAX; ASMSyntax.Const RAX n], l + 2).

(* Finds the index of a variable in a stack representation *)
Function index_of (vs: v_stack) (n: name) (k: nat): nat :=
  match vs with
  | nil => k
  | x :: vs =>
    match x with
      | None => index_of vs n (k + 1)
      | Some v => if Nat.eqb v n then k else index_of vs n (k + 1)
    end
  end.

Function index_of_opt (vs: v_stack) (n: name) (k: nat): option nat :=
  match vs with
  | nil => None
  | x :: vs =>
    match x with
    | None => index_of_opt vs n (k + 1)
    | Some v => if Nat.eqb v n then Some k else index_of_opt vs n (k + 1)
    end
  end.

(* lookup variable with name `n`, based on stack `vs` *)
Definition c_var (n: name) (l: nat) (vs: v_stack): asm_appl * nat :=
  let/d k := (index_of vs n 0) in
  if k =? 0 then (List [ASMSyntax.Push RAX], l+1)
  else (List [ASMSyntax.Push RAX; ASMSyntax.Load_RSP RAX k], l+2).

Fixpoint c_declare_binders_rec (binders: list name) (l: nat) (vs: v_stack) (acc_asm: asm_appl): (asm_appl * nat * v_stack) :=
  match binders with
  | nil => (acc_asm, l, vs)
  | binder_name :: binders =>
    c_declare_binders_rec binders (l + 1) ((Some binder_name) :: vs) (acc_asm +++ List [ASMSyntax.Push RDI])
  end.

Definition c_declare_binders (binders: list name) (l: nat) (vs: v_stack): (asm_appl * nat * v_stack) :=
  let/d '(asm1, l1, vs1) := c_declare_binders_rec binders (l + 1) vs (List []) in
  (asm1 +++ List [ASMSyntax.Const RDI (word.of_Z (Z.of_nat 0))], l1, vs1).

(* assign variable with name `n`, based on stack *)
Definition c_assign (n : name) (l : nat) (vs : v_stack) : (asm_appl * nat) :=
  let/d k := index_of vs n 0 in
  match k return (asm_appl * nat) with
  | 0 => (List [ASMSyntax.Pop RDI], l+1)
  | S _ => (List [ASMSyntax.Store_RSP RAX k; ASMSyntax.Pop RAX], l+2)
  end.

(*
  RAX := RAX + top_of_stack
*)
Definition c_add (vs : v_stack) : asm_appl :=
  List [ ASMSyntax.Pop RDI;
    ASMSyntax.Add RAX RDI ].

(*
  RAX := top_of_stack - RAX (or 0 if the result would be negative)
*)
Definition c_sub (l : nat) : asm_appl :=
  List [ ASMSyntax.Pop RDI;
    ASMSyntax.Sub RDI RAX;
    ASMSyntax.Mov RAX RDI ].

(*
  RAX := RAX / top_of_stack
  RDX := RAX % top_of_stack
*)
Definition c_div : asm_appl :=
  List [ ASMSyntax.Mov RDI RAX;
    ASMSyntax.Pop RAX;
    ASMSyntax.Const RDX (word.of_Z (Z.of_nat 0));
    ASMSyntax.Div RDI ].

Definition c_alloc (vs : v_stack) : asm_appl :=
  if even_len vs (* stack must be aligned at call *)
  then List [Load_RSP RDI 0; ASMSyntax.Call AllocLoc; Pop RDI]
  else List [Pop RDI; ASMSyntax.Call AllocLoc].

(* Some aasmbly languages and architectures (including x86_64) require alignint
the stack to 16-bytes before function calls. If `vs` is even – we have to push
something to the stack before calling any function. (the first value from the stack is kept in RAX,
so the actual stack size is odd then)
*)
Definition align (needs_alignment : bool) (asm1 : asm_appl) : asm_appl :=
  if needs_alignment then (List [Push RAX]) +++ asm1 +++ (List [Pop RDI]) else asm1.

Definition c_read (vs : v_stack) (l : nat) : (asm_appl * nat) :=
  let/d asm1 := align (even_len vs) (List [ASMSyntax.Push RAX; ASMSyntax.GetChar]) in
  (asm1, l + app_list_length asm1).

Definition c_write (vs : v_stack) (l : nat) : (asm_appl * nat) :=
  let/d asm1 := align (even_len vs) (List [Mov RDI RAX; ASMSyntax.PutChar; ASMSyntax.Const RAX (word.of_Z (Z.of_nat 0))]) in
  (asm1, l + app_list_length asm1).

(*
  input : RAX, top_of_stack
  RAX := top_of_stack[RAX]
  i.e.
  load (into)RAX (RAX + top of stack) 0w
*)
Definition c_load : asm_appl :=
  List [ ASMSyntax.Pop RDI;
    ASMSyntax.Add RDI RAX;
    ASMSyntax.Load RAX RDI (word.of_Z (Z.of_nat 0)) ].

(*
  input : RAX, top_of_stack, snd_top_of_stack
  snd_top_of_stack[top_of_stack] := RAX
*)
Definition c_store : asm_appl :=
  List [ ASMSyntax.Pop RDI;
    ASMSyntax.Pop RDX;
    ASMSyntax.Add RDI RDX;
    ASMSyntax.Store RAX RDI (word.of_Z (Z.of_nat 0)) ].

Fixpoint c_exp (e : exp) (l : nat) (vs : v_stack) : asm_appl * nat :=
  match e with
  | Var n => c_var n l vs
  | Const n => c_const n l
  | Add e1 e2 =>
      let/d '(asm1, l1) := c_exp e1 l vs in
      let/d '(asm2, l2) := c_exp e2 l1 (None :: vs) in
      let/d c_add_asm := c_add (None :: None :: vs) in
      (asm1 +++ asm2 +++ c_add_asm, l2 + app_list_length c_add_asm)
  | Sub e1 e2 =>
      let/d '(asm1, l1) := c_exp e1 l vs in
      let/d '(asm2, l2) := c_exp e2 l1 (None :: vs) in
      let/d c_sub_asm := c_sub l2 in
      (asm1 +++ asm2 +++ c_sub_asm, l2 + app_list_length c_sub_asm)
  | Div e1 e2 =>
      let/d '(asm1, l1) := c_exp e1 l vs in
      let/d '(asm2, l2) := c_exp e2 l1 (None :: vs) in
      (asm1 +++ asm2 +++ c_div, l2 + app_list_length c_div)
  | Read e1 e2 =>
      let/d '(asm1, l1) := c_exp e1 l vs in
      let/d '(asm2, l2) := c_exp e2 l1 (None :: vs) in
      (asm1 +++ asm2 +++ c_load, l2 + app_list_length c_load)
  end.

Fixpoint c_exps (es: list exp) (l: nat) (vs: v_stack): asm_appl * nat :=
  match es with
  | [] => (List [], l)
  | e :: es' =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := c_exps es' l1 vs in
    (asm1 +++ asm2, l2)
  end.

(*
  RDI `cmp` RBX
*)
Definition c_cmp (c : cmp) : cond :=
  match c with
    | Less => ASMSyntax.Less RDI RBX
    | Equal => ASMSyntax.Equal RDI RBX
  end.

Fixpoint c_test_jump (t: test) (pos_label: nat) (neg_label: nat)
  (l: nat) (vs: v_stack): asm_appl * nat :=
  match t with
  | Test c e1 e2 =>
    let/d '(asm1, l1) := c_exp e1 l vs in
    let/d '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    let/d c_cmp_asm := List [Mov RBX RAX; Pop RDI; Pop RAX;
      ASMSyntax.Jump (c_cmp c) pos_label;
      ASMSyntax.Jump Always neg_label] in
    (asm1 +++ asm2 +++ c_cmp_asm, l2 + app_list_length c_cmp_asm)
  | And t1 t2 =>
    let/d '(asm1, l1) := c_test_jump t1 (l + 1) neg_label (l + 2) vs in
    let/d '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
    let/d jump_to_start := List [ASMSyntax.Jump Always (l + 2)] in
    let/d jump_to_t2 := List [ASMSyntax.Jump Always l1] in (* l1 is the start of t2*)
    (jump_to_start +++ jump_to_t2 +++ asm1 +++ asm2, l2)
  | Or t1 t2 =>
    let/d '(asm1, l1) := c_test_jump t1 pos_label (l + 1) (l + 2) vs in
    let/d '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
    let/d jump_to_start := List [ASMSyntax.Jump Always (l + 2)] in
    let/d jump_to_t2 := List [ASMSyntax.Jump Always l1] in (* l1 is the start of t2*)
    (jump_to_start +++ jump_to_t2 +++ asm1 +++ asm2, l2)
  | Not t' =>
    c_test_jump t' neg_label pos_label l vs
  end.

(* Looks up a function name in a list of function addresses *)
Function lookup (fs: f_lookup) (n: nat): nat :=
  match fs with
  | [] => 0
  | (x, y) :: xs =>
    if Nat.eqb x n then y else lookup xs n
  end.

(* Drop the current stack frame - elements corresponding to `vs` *)
Definition make_ret (vs : v_stack) (l : nat) : asm_appl * nat :=
  (List [Add_RSP (List.length vs); Ret], l + 2).

(* Store the variables from the stack in the registers, so that they can be
passed to the function call *)
Definition c_pops (xs : list exp) (vs : v_stack) : asm_appl :=
  let/d k := List.length xs in
  if k =? 0 then List [Push RAX] else
  if k =? 1 then List [] else
  if k =? 2 then List [Pop RDI] else
  if k =? 3 then List [Pop RDI; Pop RDX] else
  if k =? 4 then List [Pop RDI; Pop RDX; Pop RBX] else
  if k =? 5 then List [Pop RDI; Pop RDX; Pop RBX; Pop RBP] else
  List [Jump Always (give_up (xorb (negb (even_len_exp xs)) (even_len vs)))].

(** Builds a stack representation for parameters of a function *)
Function call_v_stack (xs: list name) (acc: v_stack): v_stack :=
  match xs with
  | [] => acc
  | x :: xs' => call_v_stack xs' (Some x :: acc)
  end.

(** Push a list of variables onto the stack *)
Definition c_pushes (v_names: list name) (l: nat): (asm_appl * v_stack * nat) :=
  let/d k := List.length v_names in
  let/d e := call_v_stack v_names [] in
  if k =? 0 then (List [], [None], l) else
  if k =? 1 then (List [], e, l) else
  if k =? 2 then (List [Push RDI], e, l + 1) else
  if k =? 3 then (List [Push RDX; Push RDI], e, l + 2) else
  if k =? 4 then (List [Push RBX; Push RDX; Push RDI], e, l + 3) else
  (List [Push RBP; Push RBX; Push RDX; Push RDI], e, l + 4).

(* Call the given function, passing the arguments in registers*)
Definition c_call (vs: v_stack) (target: nat)
  (xs: list exp) (l: nat): asm_appl * nat :=
  let/d asm_pops := c_pops xs vs in
  let/d asm1 := align (even_len vs) (List [ASMSyntax.Call target]) in
  (asm_pops +++ asm1, l + app_list_length asm_pops + app_list_length asm1).

Fixpoint c_cmd (c: cmd) (l: nat) (fs: f_lookup) (vs: v_stack): (asm_appl * nat) :=
  match c with
  | Skip => (List [], l)
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
    let/d '(asm2, l2) := c_exp e l1 vs in
    let/d '(asm3, l3) := c_exp e' l2 (None :: vs) in
    let/d asm4 := c_store in
    (asm1 +++ asm2 +++ asm3 +++ asm4, l3 + app_list_length asm4)
  | If t c1 c2 =>
    let/d '(asm1, l1) := c_test_jump t (l + 1) (l + 2) (l + 3) vs in
    let/d '(asm2, l2) := c_cmd c1 l1 fs vs in
    let/d '(asm3, l3) := c_cmd c2 (l2 + 1) fs vs in
    let/d jump_to_start := List[ASMSyntax.Jump Always (l + 3)] in
    let/d jump_to_c1 := List [ASMSyntax.Jump Always l1] in
    let/d jump_to_c2 := List [ASMSyntax.Jump Always l2] in
    let/d jump_to_end := List [ASMSyntax.Jump Always l3] in
    let/d asmres := jump_to_start +++ jump_to_c1 +++ jump_to_c2 +++ asm1 +++ asm2 +++ jump_to_end +++ asm3 in
    (asmres, l3)
  | While tst body =>
    let/d '(asm1, l1) := c_test_jump tst (l + 1) (l + 2) (l + 3) vs in
    let/d '(asm2, l2) := c_cmd body l1 fs vs in
    let/d jump_to_tst := List [ASMSyntax.Jump Always (l + 3)] in
    let/d jump_to_beginning := List [ASMSyntax.Jump Always l] in
    let/d jump_to_body := List [ASMSyntax.Jump Always l1] in
    let/d jump_to_end := List [ASMSyntax.Jump Always (l2 + 1)] in
    let/d asmres := jump_to_tst +++ jump_to_body +++ jump_to_end +++ asm1 +++ asm2 +++ jump_to_beginning in
    (asmres, l2+1)
  | Call n f es =>
    let/d target := lookup fs f in
    let/d '(asms, l1) := c_exps es l vs in
    let/d '(asm1, l2) := c_call vs target es l1 in
    let/d '(asm2, l3) := c_var n l2 vs in
    (asms +++ asm1 +++ asm2, l3)
  | Return e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := make_ret vs l1 in
    (asm1 +++ asm2, l2)
  | Alloc n e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d asm2 := c_alloc vs in
    let/d '(asm3, l3) := c_assign n (l1 + app_list_length asm2) vs in
    (asm1 +++ asm2 +++ asm3, l3)
  | GetChar n =>
    let/d '(asm1, l1) := c_read vs l in
    let/d '(asm2, l2) := c_assign n l1 vs in
    (asm1 +++ asm2, l2)
  | PutChar e =>
    let/d '(asm1, l1) := c_exp e l vs in
    let/d '(asm2, l2) := c_write vs l1 in
    (asm1 +++ asm2, l2)
  | Abort =>
    (List [Jump Always (abort (odd_len vs))], l+1)
  end.

Function all_binders (body: cmd): list name :=
  match body with
  | Skip => []
  | Seq c1 c2 => all_binders c1 ++ all_binders c2
  | Assign n e => [n]
  | Update a e e' => []
  | If t c1 c2 => all_binders c1 ++ all_binders c2
  | While tst body => all_binders body
  | Call n f es => [n]
  | Return e => []
  | Alloc n e => [n]
  | GetChar n => [n]
  | PutChar e => []
  | Abort => []
  end.

Function names_contain (l: list name) (a: name): bool :=
  match l with
  | nil => false
  | x :: l => (x =? a) || names_contain l a
  end.

Fixpoint names_unique (l: list name) (acc: list name): list name :=
  match l with
  | nil => acc
  | x :: l => names_unique l (if names_contain acc x then acc else (x :: acc))
  end.

Definition unique_binders (body: cmd): list name :=
  let/d binds := all_binders body in
  names_unique binds [].

Function make_vs_from_binders (binders: list name): v_stack :=
  match binders with
  | nil => nil
  | b :: binders => (Some b) :: make_vs_from_binders binders
  end.

(** Compiles a single function definition into assembly code. *)
Definition c_fundef (fundef: func) (l: nat) (fs: f_lookup): (asm_appl * nat) :=
  match fundef with
  | Func n v_names body =>
    let/d '(asm0, vs0, l0) := c_pushes v_names l in
    let/d binders := unique_binders body in
    let/d vs_binders := make_vs_from_binders binders in
    let/d asm1 := List [Sub_RSP (List.length vs_binders)] in
    let/d '(asm2, l2) := c_cmd body (l0 + 1) fs (vs_binders ++ vs0) in
    (asm0 +++ asm1 +++ asm2, l2)
  end.

(* TODO(kπ) termination is unobvious to Coq, super unimportant function, hacked for now *)
(* Converts a numeric name to a string representation *)
Fail Function name2str (n: nat) (acc: string): string :=
  if n =? 0 then
    acc
  else
    name2str (n / 256) (String (ascii_of_nat (n mod 256)) acc).

Definition name2str (n: nat) (acc: string): string :=
  String (ascii_of_nat (n mod 256)) acc.

(* Compiles a list of function declarations into assembly instructions *)
Fixpoint c_fundefs (ds: list func) (l: nat) (fs: f_lookup): (asm_appl * list (name * nat) * nat) :=
  match ds with
  | [] => (List [], fs, l)
  | d :: ds' =>
    let/d fname := name_of_func d in
    let/d comment := List [Comment (name2str fname "")] in
    let/d '(c1, l1) := c_fundef d (l + 1) fs in
    let/d '(c2, fs', l2) := c_fundefs ds' l1 fs in
    (comment +++ c1 +++ c2, (fname, l + 1) :: fs', l2)
  end.

(* Generates the complete assembly code for a given program *)
Definition codegen (prog : prog) : asm :=
  let/d funs := get_funcs prog in
  let/d init_l := app_list_length (List (init 0)) in
  let/d '(_, fs, _) := c_fundefs funs init_l [] in
  let/d '(asm1, _, _) := c_fundefs funs init_l fs in
  let/d main_l := lookup fs (fun_name_of_string "main") in
  flatten ((List (init main_l)) +++ asm1).
