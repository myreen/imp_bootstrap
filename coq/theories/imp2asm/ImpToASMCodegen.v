Require Import Coq.Lists.List.
Import ListNotations.
Require Import Coq.Strings.String.
Require Import Coq.Numbers.DecimalString.
Require Import Coq.Bool.Bool.
Require Import String.
Require Import Nat.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.imperative.ImpSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.
Require Import ZArith.

(*
For now simplify:
- no list (Append | List)
*)

(*
TODO(kπ):
- there might be an issue with sizes of arguments to assign vs arguments to
  malloc, unless we don't care
*)

Notation v_stack := (list (option nat)).
Notation f_lookup := (list (name * nat)).

(* Generates the initialization code for execution *)
Definition init (k : nat) : asm :=
  [
    (*  0 *) ASMSyntax.Const RAX (word.of_Z 0);
    (*  1 *) ASMSyntax.Const R12 (word.of_Z 16);
    (*  2 *) ASMSyntax.Const R13 (word.of_Z (2^63 - 1));
    (* jump to main function *)
    (*  3 *) ASMSyntax.Call k;
    (* return to exit 0 *)
    (*  4 *) ASMSyntax.Const RDI (word.of_Z 0);
    (*  5 *) ASMSyntax.Exit;
    (* alloc routine starts here: *)
    (*  6 *) ASMSyntax.Comment "malloc";
    (*  7 *) ASMSyntax.Jump (ASMSyntax.Equal R14 R15) 14;
    (*  8 *) ASMSyntax.Comment "noop";
    (*  9 *) ASMSyntax.Mov RDI RAX;
    (* 10 *) ASMSyntax.Mov RAX R14;
    (* 11 *) ASMSyntax.Add R14 RDI;
    (* 12 *) ASMSyntax.Ret;
    (* give up: *)
    (* 13 *) ASMSyntax.Comment "exit 1";
    (* 14 *) ASMSyntax.Push R15;
    (* 15 *) ASMSyntax.Const RDI (word.of_Z 1);
    (* 16 *) ASMSyntax.Exit
  ].

Definition AllocLoc : nat := 7.

(* Checks if a list has an even length *)
Fixpoint even_len {A} (xs : list A) : bool :=
  match xs with
  | [] => true
  | _ :: ys => negb (even_len ys)
  end.

(* jump label for failure cases
  b – also push R15 before exiting give_up
*)
Definition give_up (b : bool) : nat := if b then 14 else 15.

(* Compiles a constant value into assembly instructions *)
Definition c_const (n : word64) (l : nat) (vs : v_stack) : asm * nat :=
  if word.ltu (word.of_Z ((2^63) - 1)) n then
    ([Jump Always (give_up (even_len vs))], l+1)
  else
    ([ASMSyntax.Push RAX; ASMSyntax.Const RAX n], l+2).

(* Finds the index of a variable in a stack representation *)
Fixpoint find (n : name) (k : nat) (vs : v_stack) : nat :=
  match vs with
  | [] => k
  | None :: xs => find n (k+1) xs
  | Some v :: xs => if Nat.eqb v n then k else find n (k+1) xs
  end.

(* lookup variable with name `n`, based on stack `vs` *)
Definition c_var (n : name) (l : nat) (vs : v_stack) : asm * nat :=
  let k := find n 0 vs in
  if k =? 0 then ([ASMSyntax.Push RAX], l+1)
  else ([ASMSyntax.Push RAX; ASMSyntax.Load_RSP RAX k], l+2).

(* TODO(kπ) should we update the existing stack elements? *)
(* asign variable with name `n`, based on stack *)
Definition c_assign (n : name) (l : nat) (vs : v_stack) : (asm * nat * v_stack) :=
  ([], l, (Some n) :: vs).

(*
  RAX := RAX + top_of_stack
  if R13 < RAX then jump to give_up (R13 is the maximum value for a word)
*)
Definition c_add (vs : v_stack) : asm :=
  [ ASMSyntax.Pop RDI;
    ASMSyntax.Add RAX RDI;
    ASMSyntax.Jump (ASMSyntax.Less R13 RAX) (give_up (even_len vs)) ].

(*
  RAX := top_of_stack - RAX (or 0 if the result would be negative)
*)
Definition c_sub (l : nat) : asm :=
  [ ASMSyntax.Pop RDI;
    ASMSyntax.Jump (ASMSyntax.Less RAX RDI) (l+3);
    ASMSyntax.Mov RAX RDI;
    ASMSyntax.Sub RDI RAX;
    ASMSyntax.Mov RAX RDI ].

(*
  RAX := RAX / top_of_stack
  RDX := RAX % top_of_stack
*)
Definition c_div : asm :=
  [ ASMSyntax.Mov RDI RAX;
    ASMSyntax.Pop RAX;
    ASMSyntax.Const RDX (word.of_Z 0);
    ASMSyntax.Div RDI ].

Definition c_alloc (vs : v_stack) : asm :=
  if even_len vs (* stack must be aligned at call *)
  then [Load_RSP RDI 0; ASMSyntax.Call AllocLoc; Pop RDI]
  else [Pop RDI; ASMSyntax.Call AllocLoc].

(* TODO(kπ) investigate this - why do we need an even(?) stack for read/call/etc? *)
(* TODO(ask Magnus?) *)
Definition align (b : bool) (cs : asm) : asm :=
  if b then [Push RAX] ++ cs ++ [Pop RDI] else cs.

Definition c_read (vs : v_stack) (l : nat) : (asm * nat) :=
  (align (even_len vs) [ASMSyntax.Push RAX; ASMSyntax.GetChar], l+2).

Definition c_write (vs : v_stack) (l : nat) : (asm * nat) :=
  (align (even_len vs) [Mov RDI RAX; ASMSyntax.PutChar; ASMSyntax.Const RAX (word.of_Z 0)], l+3).

(*
  input : RAX, top_of_stack
  RAX := top_of_stack[RAX]
  i.e.
  load (into)RAX (RAX + top of stack) 0w
*)
Definition c_load : asm :=
  [ ASMSyntax.Pop RDI;
    ASMSyntax.Add RDI RAX;
    ASMSyntax.Load RAX RDI 0 ].

(*
  input : RAX, top_of_stack, snd_top_of_stack
  snd_top_of_stack[top_of_stack] := RAX
*)
Definition c_store : asm :=
  [ ASMSyntax.Pop RDI;
    ASMSyntax.Pop RDX;
    ASMSyntax.Add RDI RDX;
    ASMSyntax.Store RAX RDI 0 ].

Fixpoint c_exp (e : exp) (l : nat) (vs : v_stack) : asm * nat :=
  match e with
  | Var n => c_var n l vs
  | Const n => c_const n l vs
  | Add e1 e2 =>
    let '(asm1, l1) := c_exp e1 l vs in
    let '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    let c_add_asm := c_add vs in
    (asm1 ++ asm2 ++ c_add_asm, l2 + List.length c_add_asm)
  | Sub e1 e2 =>
    let '(asm1, l1) := c_exp e1 l vs in
    let '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    let c_sub_asm := c_sub l2 in
    (asm1 ++ asm2 ++ c_sub_asm, l2 + List.length c_sub_asm)
  | Div e1 e2 =>
    let '(asm1, l1) := c_exp e1 l vs in
    let '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    (asm1 ++ asm2 ++ c_div, l2 + List.length c_div)
  | Read e1 e2 =>
    let '(asm1, l1) := c_exp e1 l vs in
    let '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    (asm1 ++ asm2 ++ c_load, l2 + List.length c_load)
  end.

Fixpoint c_exps (es: list exp) (l : nat) (vs : v_stack) : asm * nat :=
  match es with
  | [] => ([], l)
  | e :: es' =>
    let '(asm1, l1) := c_exp e l vs in
    let '(asm2, l2) := c_exps es' l1 vs in
    (asm1 ++ asm2, l2)
  end.

(*
  RDI `cmp` RBX
*)
Definition c_cmp (c : cmp) : cond :=
  match c with
  | Less => ASMSyntax.Less RDI RBX
  | Equal => ASMSyntax.Equal RDI RBX
  end.

Fixpoint c_test_jump (t : test) (pos_label : nat) (neg_label : nat)
  (l : nat) (vs : v_stack) : asm * nat :=
  match t with
  | Test c e1 e2 =>
    let '(asm1, l1) := c_exp e1 l vs in
    let '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    let c_cmp_asm := [ASMSyntax.Jump (c_cmp c) pos_label] in
    (asm1 ++ asm2 ++ c_cmp_asm, l2 + List.length c_cmp_asm)
  | And t1 t2 =>
    let '(asm1, l1) := c_test_jump t1 (l + 1) neg_label (l + 2) vs in
    let '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
    let jump_to_start := [ASMSyntax.Jump Always (l + 2)] in
    let jump_to_t2 := [ASMSyntax.Jump Always l1] in (* l1 is the start of t2*)
    (jump_to_start ++ jump_to_t2 ++ asm1 ++ asm2, l2)
  | Or t1 t2 =>
    let '(asm1, l1) := c_test_jump t1 pos_label (l + 1) (l + 2) vs in
    let '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
    let jump_to_start := [ASMSyntax.Jump Always (l + 2)] in
    let jump_to_t2 := [ASMSyntax.Jump Always l1] in (* l1 is the start of t2*)
    (jump_to_start ++ jump_to_t2 ++ asm1 ++ asm2, l2)
  | Not t =>
    c_test_jump t neg_label pos_label l vs
  end.

(* Looks up a function name in a list of function addresses *)
Fixpoint lookup (n : nat) (fs : f_lookup) : nat :=
  match fs with
  | [] => 0
  | (x, y) :: xs => if Nat.eqb x n then y else lookup n xs
  end.

(* Drop the current stack frame - elements corresponding to `vs` *)
Definition make_ret (vs : v_stack) (l : nat) : asm * nat :=
  ([Add_RSP (List.length vs); Ret], l + 2).

(* Generates assembly instruction to pop a list of variables from the stack *)
Definition c_pops (xs : list exp) (vs : v_stack) : asm :=
  let k := List.length xs in
  match k with
  | 0 => [Push RAX]
  | 1 => []
  | 2 => [Pop RDI]
  | 3 => [Pop RDI; Pop RDX]
  | 4 => [Pop RDI; Pop RDX; Pop RBX]
  | 5 => [Pop RDI; Pop RDX; Pop RBX; Pop RBP]
  | _ => [Jump Always (give_up (xorb (negb (even_len xs)) (even_len vs)))]
  end.

(** Builds an environment list by prepending each name wrapped in [Some],
  resulting in the reversed list of names *)
Fixpoint call_env (xs: list name) (acc: v_stack): v_stack :=
  match xs with
  | [] => acc
  | x :: xs' => call_env xs' (Some x :: acc)
  end.

(** Generates assembly instructions to push a list of variables onto the stack *)
Definition c_pushes (vs: list name) (l : nat):
  (asm * list (option name) * nat) :=
  let k: nat := List.length vs in
  let e := call_env vs [] in
  match k with
  | 0 => ([], [None], l)
  | 1 => ([], e, l)
  | 2 => ([Push RDI], e, l + 1)
  | 3 => ([Push RDX; Push RDI], e, l + 2)
  | 4 => ([Push RBX; Push RDX; Push RDI], e, l + 3)
  | _ => ([Push RBP; Push RBX; Push RDX; Push RDI], e, l + 4)
  end.

(* TODO(kπ) check this carefully and add docstring *)
Definition c_call (vs : v_stack) (target : nat)
  (xs : list exp) (l : nat) : asm * nat :=
  let ys := c_pops xs vs in
  let cs := align (even_len vs) [ASMSyntax.Call target] in
  (ys ++ cs, l + List.length ys + List.length cs).

Fixpoint c_cmd (c : cmd) (l : nat) (fs : f_lookup)
  (vs : v_stack) (ck: nat) {measure ck} : (asm * nat * v_stack * nat) :=
  match ck with
  | 0 => ([], l, vs, 0)
  | S ck =>
    match c with
    | Assign n e =>
      let '(c1, l1) := c_exp e l vs in
      let '(c2, l2, vs') := c_assign n l1 vs in
      (c1 ++ c2, l2, vs', ck)
    | Update a e e' =>
      let '(asm1, l1) := c_exp a l vs in
      let '(asm2, l2) := c_exp e l1 vs in
      let '(asm3, l3) := c_exp e' l2 (None :: vs) in
      let asm4 := c_store in
      (asm1 ++ asm2 ++ asm3 ++ asm4, l3 + List.length asm4, vs, ck)
    | If t c1 c2 =>
      (* l jumps to start (t) *)
      (* (l + 1) jumps to c1 *)
      (* (l + 2) jumps to c2 *)
      let '(asm1, l1) := c_test_jump t (l + 1) (l + 2) (l + 3) vs in
      let '(asm2, l2, vs', ck1) := c_cmds c1 l1 fs vs (ck-1) in
      let '(asm3, l3, vs'', ck2) := c_cmds c2 l2 fs vs' (ck1-1) in
      let jump_to_start := [ASMSyntax.Jump Always (l + 3)] in
      let jump_to_c1 := [ASMSyntax.Jump Always l1] in
      let jump_to_c2 := [ASMSyntax.Jump Always l2] in
      let asmres := jump_to_start ++ jump_to_c1 ++ jump_to_c2 ++ asm1 ++ asm2 ++ asm3 in
      (asmres, l3, vs'', ck2)
    | While tst c1 =>
      (* l jumps to tst *)
      (* (l + 1) jumps to c1 *)
      (* (l + 2) jumps to end *)
      let '(asm1, l1) := c_test_jump tst (l + 1) (l + 2) (l + 3) vs in
      let '(asm2, l2, vs', ck1) := c_cmds c1 l1 fs vs (ck-1) in
      (* l2 jumps to tst *)
      let jump_to_tst := [ASMSyntax.Jump Always (l + 3)] in
      let jump_to_c1 := [ASMSyntax.Jump Always l1] in
      let jump_to_end := [ASMSyntax.Jump Always (l2+1)] in
      let asmres := jump_to_tst ++ jump_to_c1 ++ jump_to_end ++ asm1 ++ asm2 ++ jump_to_tst in
      (asmres, l2+1, vs', ck1)
    | Call n f es =>
      let target := lookup f fs in
      let '(asms, l1) := c_exps es l vs in
      let '(asm1, l2) := c_call vs target es l1 in
      let '(asm2, l3) := c_var n l2 vs in
      (asms ++ asm1 ++ asm2, l3, vs, ck)
    | Return e =>
      let '(asm1, l1) := c_exp e l vs in
      let '(asm2, l2) := make_ret vs l1 in
      (asm1 ++ asm2, l2, vs, ck)
    | Alloc n e =>
      let '(asm1, l1) := c_exp e l vs in
      let asm2 := c_alloc vs in
      let '(asm3, l3, vs') := c_assign n l1 vs in
      (asm1 ++ asm2 ++ asm3, l3, vs', ck)
    | GetChar n =>
      let '(asm1, l1) := c_read vs l in
      let '(asm2, l2, vs') := c_assign n l1 vs in
      (asm1 ++ asm2, l2, vs', ck)
    | PutChar e =>
      let '(asm1, l1) := c_exp e l vs in
      let '(asm2, l2) := c_write vs l1 in
      (asm1 ++ asm2, l2, vs, ck)
    | Abort =>
      ([Jump Always (give_up (even_len vs))], l+1, vs, ck)
    end
  end
with
  c_cmds (cs : list cmd) (l : nat) (fs : f_lookup)
  (vs : v_stack) (ck : nat) {measure ck} : (asm * nat * v_stack * nat) :=
  match ck with
  | 0 => ([], l, vs, 0) (* Base case: prevent infinite recursion *)
  | S ck =>
    match cs with
    | [] => ([], l, vs, ck)
    | c :: cs' =>
        let '(c1, l1, vs', ck1) := c_cmd c l fs vs ck in
        let '(c2, l2, vs'', ck2) := c_cmds cs' l1 fs vs' ck1 in
        (c1 ++ c2, l2, vs'', ck2)
    end
  end.

(** Compiles a single function definition into assembly code. *)
Definition c_defun (l: nat)
  (fs: list (name * nat))
  (fundef : func): (nat * asm) :=
  let '(Func n vs body) := fundef in
  let '(c0, vs0, l0) := c_pushes l vs in
  let '(c1, l1) := c_cmds T l0 vs0 fs body in
  (c0 ++ c1, l1).

(* Converts a numeric name to a string representation *)
Fixpoint name2str (n : nat) (acc : string) : string :=
  if n =? 0 then acc else name2str (n / 256) (String (ascii_of_nat (n mod 256)) acc).

(* Compiles a list of function declarations into assembly instructions *)
Fixpoint c_decs (l : nat)
  (fs : f_lookup) (ds : list func) : asm * list (name * nat) * nat :=
  match ds with
  | [] => (List [], [], l)
  | d :: ds' =>
      let fname := name_of d in
      let comment := List [Comment (name2str fname "")] in
      let (c1, l1) := c_defun (l + 1) fs d in
      let (c2, fs', l2) := c_decs true l1 fs ds' in
      (Append comment (Append c1 c2), (fname, l + 1) :: fs', l2)
  end.

(* Generates the complete assembly code for a given program *)
Definition codegen (prog : Prog) : asm :=
  let '(funs) := prog in
  let init_l := length (init 0) in
  let (_, fs, k) := c_decs init_l [] funs in
  (* TODO(kπ) pick main from fs? *)
  let (c, _, _) := c_decs init_l fs (funs ++ [(0, [], main)]) in
  (init (k + 1)) ++ c.
