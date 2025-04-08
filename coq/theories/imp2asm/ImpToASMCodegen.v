From impboot Require Import utils.Core.
Require Import impboot.assembly.ASMSyntax.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.utils.AppList.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Naive.
Require Import ZArith.

Open Scope app_list_scope.

Notation asm_appl := (app_list instr).

(*
TODO(kπ):
- there might be an issue with sizes of arguments to assign vs arguments to
  malloc, unless we don't care
*)

Notation v_stack := (list (option nat)).
Notation f_lookup := (list (name * nat)).

(* Generates the initialization code for execution *)
Definition init (k : nat) : asm_appl :=
  List [
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
  list_CASE xs
    (* nil *)
    true
    (* :: *)
    (fun _ ys => negb (even_len ys)).

(* jump label for failure cases
  if b is true – also push R15 before exiting give_up
*)
Definition give_up (b : bool) : nat := if b then 14 else 15.

(* Compiles a constant value into assembly instructions *)
Definition c_const (n : word64) (l : nat) (vs : v_stack) : asm_appl * nat :=
  if word.ltu (word.of_Z ((2^63) - 1)) n then
    (List [Jump Always (give_up (even_len vs))], l+1)
  else
    (List [ASMSyntax.Push RAX; ASMSyntax.Const RAX n], l+2).

(* Finds the index of a variable in a stack representation *)
Fixpoint find (n : name) (k : nat) (vs : v_stack) : nat :=
  list_CASE vs
    (* nil *)
    k
    (* :: *)
    (fun x xs =>
      option_CASE x
        (* none *)
        (find n (k+1) xs)
        (* some *)
        (fun v => if Nat.eqb v n then k else find n (k+1) xs)
    ).

(* lookup variable with name `n`, based on stack `vs` *)
Definition c_var (n : name) (l : nat) (vs : v_stack) : asm_appl * nat :=
  letd k := find n 0 vs in
  if k =? 0 then (List [ASMSyntax.Push RAX], l+1)
  else (List [ASMSyntax.Push RAX; ASMSyntax.Load_RSP RAX k], l+2).

(* TODO(kπ) should we update the existing stack elements? *)
(* asign variable with name `n`, based on stack *)
Definition c_assign (n : name) (l : nat) (vs : v_stack) : (asm_appl * nat * v_stack) :=
  (List [], l, (Some n) :: vs).

(*
  RAX := RAX + top_of_stack
  if R13 < RAX then jump to give_up (R13 is the maximum value for a word)
*)
Definition c_add (vs : v_stack) : asm_appl :=
  List [ ASMSyntax.Pop RDI;
    ASMSyntax.Add RAX RDI;
    ASMSyntax.Jump (ASMSyntax.Less R13 RAX) (give_up (even_len vs)) ].

(*
  RAX := top_of_stack - RAX (or 0 if the result would be negative)
*)
Definition c_sub (l : nat) : asm_appl :=
  List [ ASMSyntax.Pop RDI;
    ASMSyntax.Jump (ASMSyntax.Less RAX RDI) (l+3);
    ASMSyntax.Mov RAX RDI;
    ASMSyntax.Sub RDI RAX;
    ASMSyntax.Mov RAX RDI ].

(*
  RAX := RAX / top_of_stack
  RDX := RAX % top_of_stack
*)
Definition c_div : asm_appl :=
  List [ ASMSyntax.Mov RDI RAX;
    ASMSyntax.Pop RAX;
    ASMSyntax.Const RDX (word.of_Z 0);
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
  (align (even_len vs) (List [ASMSyntax.Push RAX; ASMSyntax.GetChar]), l+2).

Definition c_write (vs : v_stack) (l : nat) : (asm_appl * nat) :=
  (align (even_len vs) (List [Mov RDI RAX; ASMSyntax.PutChar; ASMSyntax.Const RAX (word.of_Z 0)]), l+3).

(*
  input : RAX, top_of_stack
  RAX := top_of_stack[RAX]
  i.e.
  load (into)RAX (RAX + top of stack) 0w
*)
Definition c_load : asm_appl :=
  List [ ASMSyntax.Pop RDI;
    ASMSyntax.Add RDI RAX;
    ASMSyntax.Load RAX RDI (word.of_Z 0) ].

(*
  input : RAX, top_of_stack, snd_top_of_stack
  snd_top_of_stack[top_of_stack] := RAX
*)
Definition c_store : asm_appl :=
  List [ ASMSyntax.Pop RDI;
    ASMSyntax.Pop RDX;
    ASMSyntax.Add RDI RDX;
    ASMSyntax.Store RAX RDI (word.of_Z 0) ].

Fixpoint c_exp (e : exp) (l : nat) (vs : v_stack) : asm_appl * nat :=
  exp_CASE e
  (* Var *)
  (fun n => c_var n l vs)
  (* Const *)
  (fun n => c_const n l vs)
  (* Add *)
  (fun e1 e2 =>
    letd '(asm1, l1) := c_exp e1 l vs in
    letd '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    letd c_add_asm := c_add vs in
    (asm1 +++ asm2 +++ c_add_asm, l2 + app_list_length c_add_asm))
  (* Sub *)
  (fun e1 e2 =>
    letd '(asm1, l1) := c_exp e1 l vs in
    letd '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    letd c_sub_asm := c_sub l2 in
    (asm1 +++ asm2 +++ c_sub_asm, l2 + app_list_length c_sub_asm))
  (* Div *)
  (fun e1 e2 =>
    letd '(asm1, l1) := c_exp e1 l vs in
    letd '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    (asm1 +++ asm2 +++ c_div, l2 + app_list_length c_div))
  (* Read *)
  (fun e1 e2 =>
    letd '(asm1, l1) := c_exp e1 l vs in
    letd '(asm2, l2) := c_exp e2 l1 (None :: vs) in
    (asm1 +++ asm2 +++ c_load, l2 + app_list_length c_load)).

Fixpoint c_exps (es: list exp) (l : nat) (vs : v_stack) : asm_appl * nat :=
  list_CASE es
    (* [] *)
    (List [], l)
    (* :: *)
    (fun e es' =>
      letd '(asm1, l1) := c_exp e l vs in
      letd '(asm2, l2) := c_exps es' l1 vs in
      (asm1 +++ asm2, l2)).

(*
  RDI `cmp` RBX
*)
Definition c_cmp (c : cmp) : cond :=
  cmp_CASE c
    (* Less *)
    (ASMSyntax.Less RDI RBX)
    (* Equal *)
    (ASMSyntax.Equal RDI RBX).

Fixpoint c_test_jump (t : test) (pos_label : nat) (neg_label : nat)
  (l : nat) (vs : v_stack) : asm_appl * nat :=
  test_CASE t
    (* Test *)
    (fun c e1 e2 =>
      letd '(asm1, l1) := c_exp e1 l vs in
      letd '(asm2, l2) := c_exp e2 l1 (None :: vs) in
      letd c_cmp_asm := List [ASMSyntax.Jump (c_cmp c) pos_label] in
      (asm1 +++ asm2 +++ c_cmp_asm, l2 + app_list_length c_cmp_asm))
    (* And *)
    (fun t1 t2 =>
      letd '(asm1, l1) := c_test_jump t1 (l + 1) neg_label (l + 2) vs in
      letd '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
      letd jump_to_start := List [ASMSyntax.Jump Always (l + 2)] in
      letd jump_to_t2 := List [ASMSyntax.Jump Always l1] in (* l1 is the start of t2*)
      (jump_to_start +++ jump_to_t2 +++ asm1 +++ asm2, l2))
    (* Or *)
    (fun t1 t2 =>
      letd '(asm1, l1) := c_test_jump t1 pos_label (l + 1) (l + 2) vs in
      letd '(asm2, l2) := c_test_jump t2 pos_label neg_label l1 vs in
      letd jump_to_start := List [ASMSyntax.Jump Always (l + 2)] in
      letd jump_to_t2 := List [ASMSyntax.Jump Always l1] in (* l1 is the start of t2*)
      (jump_to_start +++ jump_to_t2 +++ asm1 +++ asm2, l2))
    (* Not *)
    (fun t =>
      c_test_jump t neg_label pos_label l vs).

(* Looks up a function name in a list of function addresses *)
Fixpoint lookup (n : nat) (fs : f_lookup) : nat :=
  list_CASE fs
    (* [] *)
    0
    (* :: *)
    (fun xy xs =>
      letd '(x, y) := xy in
      if Nat.eqb x n then y else lookup n xs).

(* Drop the current stack frame - elements corresponding to `vs` *)
Definition make_ret (vs : v_stack) (l : nat) : asm_appl * nat :=
  (List [Add_RSP (List.length vs); Ret], l + 2).

(* Store the variables from the stack in the registers, so that they can be
passed to the function call *)
Definition c_pops (xs : list exp) (vs : v_stack) : asm_appl :=
  letd k := List.length xs in
  if k =? 0 then List [Push RAX] else
  if k =? 1 then List [] else
  if k =? 2 then List [Pop RDI] else
  if k =? 3 then List [Pop RDI; Pop RDX] else
  if k =? 4 then List [Pop RDI; Pop RDX; Pop RBX] else
  if k =? 5 then List [Pop RDI; Pop RDX; Pop RBX; Pop RBP] else
  List [Jump Always (give_up (xorb (negb (even_len xs)) (even_len vs)))].

(** Builds a stack representation for parameters of a function *)
Fixpoint call_v_stack (xs: list name) (acc: v_stack): v_stack :=
  list_CASE xs
    (* [] *)
    acc
    (* :: *)
    (fun x xs' => call_v_stack xs' (Some x :: acc)).

(** Push a list of variables onto the stack *)
Definition c_pushes (v_names: list name) (l : nat): (asm_appl * v_stack * nat) :=
  letd k := List.length v_names in
  letd e := call_v_stack v_names [] in
  if k =? 0 then (List [], [None], l) else
  if k =? 1 then (List [], e, l) else
  if k =? 2 then (List [Push RDI], e, l + 1) else
  if k =? 3 then (List [Push RDX; Push RDI], e, l + 2) else
  if k =? 4 then (List [Push RBX; Push RDX; Push RDI], e, l + 3) else
  (List [Push RBP; Push RBX; Push RDX; Push RDI], e, l + 4).

(* Call the given function, passing the arguments in registers*)
Definition c_call (vs : v_stack) (target : nat)
  (xs : list exp) (l : nat) : asm_appl * nat :=
  letd asm_pops := c_pops xs vs in
  letd asm1 := align (even_len vs) (List [ASMSyntax.Call target]) in
  (asm_pops +++ asm1, l + app_list_length asm_pops + app_list_length asm1).

Fixpoint c_cmd (c : cmd) (l : nat) (fs : f_lookup)
  (vs : v_stack) (ck: nat) {struct ck} : (asm_appl * nat * v_stack) :=
  nat_CASE ck
    (* 0 *)
    (List [], l, vs)
    (* S *)
    (fun ck' =>
      cmd_CASE c
      (* Assign *)
      (fun n e =>
        letd '(c1, l1) := c_exp e l vs in
        letd '(c2, l2, vs') := c_assign n l1 vs in
        (c1 +++ c2, l2, vs'))
      (* Update *)
      (fun a e e' =>
        letd '(asm1, l1) := c_exp a l vs in
        letd '(asm2, l2) := c_exp e l1 vs in
        letd '(asm3, l3) := c_exp e' l2 (None :: vs) in
        letd asm4 := c_store in
        (asm1 +++ asm2 +++ asm3 +++ asm4, l3 + app_list_length asm4, vs))
      (* If *)
      (fun t c1 c2 =>
        letd '(asm1, l1) := c_test_jump t (l + 1) (l + 2) (l + 3) vs in
        letd '(asm2, l2, vs') := c_cmds c1 l1 fs vs ck' in
        letd '(asm3, l3, vs'') := c_cmds c2 l2 fs vs' ck' in
        letd jump_to_start := List[ASMSyntax.Jump Always (l + 3)] in
        letd jump_to_c1 := List [ASMSyntax.Jump Always l1] in
        letd jump_to_c2 := List [ASMSyntax.Jump Always l2] in
        letd asmres := jump_to_start +++ jump_to_c1 +++ jump_to_c2 +++ asm1 +++ asm2 +++ asm3 in
        (asmres, l3, vs''))
      (* While *)
      (fun tst c1 =>
        letd '(asm1, l1) := c_test_jump tst (l + 1) (l + 2) (l + 3) vs in
        letd '(asm2, l2, vs') := c_cmds c1 l1 fs vs ck' in
        letd jump_to_tst := List [ASMSyntax.Jump Always (l + 3)] in
        letd jump_to_c1 := List [ASMSyntax.Jump Always l1] in
        letd jump_to_end := List [ASMSyntax.Jump Always (l2+1)] in
        letd asmres := jump_to_tst +++ jump_to_c1 +++ jump_to_end +++ asm1 +++ asm2 +++ jump_to_tst in
        (asmres, l2+1, vs'))
      (* Call *)
      (fun n f es =>
        letd target := lookup f fs in
        letd '(asms, l1) := c_exps es l vs in
        letd '(asm1, l2) := c_call vs target es l1 in
        letd '(asm2, l3) := c_var n l2 vs in
        (asms +++ asm1 +++ asm2, l3, vs))
      (* Return *)
      (fun e =>
        letd '(asm1, l1) := c_exp e l vs in
        letd '(asm2, l2) := make_ret vs l1 in
        (asm1 +++ asm2, l2, vs))
      (* Alloc *)
      (fun n e =>
        letd '(asm1, l1) := c_exp e l vs in
        letd asm2 := c_alloc vs in
        letd '(asm3, l3, vs') := c_assign n l1 vs in
        (asm1 +++ asm2 +++ asm3, l3, vs'))
      (* GetChar *)
      (fun n =>
        letd '(asm1, l1) := c_read vs l in
        letd '(asm2, l2, vs') := c_assign n l1 vs in
        (asm1 +++ asm2, l2, vs'))
      (* PutChar *)
      (fun e =>
        letd '(asm1, l1) := c_exp e l vs in
        letd '(asm2, l2) := c_write vs l1 in
        (asm1 +++ asm2, l2, vs))
      (* Abort *)
        (List [Jump Always (give_up (even_len vs))], l+1, vs)
      )
with
  c_cmds (cs : list cmd) (l : nat) (fs : f_lookup)
    (vs : v_stack) (ck : nat) {struct ck} : (asm_appl * nat * v_stack) :=
  nat_CASE ck
    (* 0 *)
    (List [], l, vs)
    (* S *)
    (fun ck' =>
      list_CASE cs
        (* [] *)
        (List [], l, vs)
        (* :: *)
        (fun c cs' =>
            letd '(c1, l1, vs') := c_cmd c l fs vs ck' in
            letd '(c2, l2, vs'') := c_cmds cs' l1 fs vs' ck' in
            (c1 +++ c2, l2, vs''))
    ).

(** Compiles a single function definition into assembly code. *)
Definition c_fundef (fundef : func) (l: nat) (fs: f_lookup)
    (ck : nat): (asm_appl * nat) :=
  func_CASE fundef
    (fun n v_names body =>
      letd '(asm0, vs0, l0) := c_pushes v_names l in
      letd '(asm1, l1, vs1) := c_cmds body l0 fs vs0 ck in
      (asm0 +++ asm1, l1)
    ).

(* TODO(kπ) termination is unobvious to Coq, super unimportant function, hacked for now *)
(* Converts a numeric name to a string representation *)
Fail Fixpoint name2str (n : nat) (acc : string) : string :=
  if n =? 0 then
    acc
  else
    name2str (n / 256) (String (ascii_of_nat (n mod 256)) acc).

Definition name2str (n : nat) (acc : string) : string :=
  String (ascii_of_nat (n mod 256)) acc.

(* Compiles a list of function declarations into assembly instructions *)
Fixpoint c_fundefs (ds : list func) (l : nat) (fs : f_lookup) : (asm_appl * list (name * nat) * nat) :=
  list_CASE ds
    (* [] *)
    (List [], fs, l)
    (* :: *)
    (fun d ds' =>
      letd fname := name_of_func d in
      letd comment := List [Comment (name2str fname "")] in
      letd '(c1, l1) := c_fundef d (l + 1) fs 0 in
      letd '(c2, fs', l2) := c_fundefs ds' l1 fs in
      (comment +++ c1 +++ c2, (fname, l + 1) :: fs', l2)
    ).

Fixpoint lookup_main (fs : list (name * nat)) : nat :=
  list_CASE fs
    (* [] *)
    0
    (* :: *)
    (fun f xs =>
      letd '(f_name, f_line) := f in
      if Nat.eqb f_name 0 then f_line else lookup_main xs).

(* Generates the complete assembly code for a given program *)
Definition codegen (prog : prog) : asm :=
  letd funs := get_funcs prog in
  letd init_l := app_list_length (init 0) in
  letd '(_, fs, _) := c_fundefs funs init_l [] in
  letd '(asm1, _, _) := c_fundefs funs init_l fs in
  letd main_l := lookup_main fs in
  flatten ((init main_l) +++ asm1).
