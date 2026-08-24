Theory imp_to_asm
Ancestors
  arithmetic list pair finite_map string codegen (* for app_list *)
  imp_source_syntax x64asm_syntax

Overload "+++" = “Append”;

Type asm_appl = “:inst app_list”;

Type v_stack = “:(name option) list”;
Type f_lookup = “:(name # num) list”;

(* Generates the initialization code for execution *)
Definition init_def:
  init k =
  [
    (*  0 *) Const RAX 0w;
    (*  1 *) Const R12 16w;
    (*  2 *) Const R13 (n2w (2 ** 63 - 1));
    (* jump to main function *)
    (*  3 *) Call k;
    (* return to exit 0 *)
    (*  4 *) Const RDI 0w;
    (*  5 *) Exit;
    (* alloc routine starts here: *)
    (*  6 *) Comment "malloc";
    (*  7 *) Mov RAX R15;
    (*  8 *) Sub RAX R14;
    (*  9 *) Jump (Less R15 R14) 15;
    (* 10 *) Jump (Less RAX RDI) 15;
    (* 11 *) Mov RAX R14;
    (* 12 *) Add R14 RDI;
    (* 13 *) Ret;
    (* give up: *)
    (* 14 *) Comment "exit 4"; (* Internal error – OOM or compiler limitation *)
    (* 15 *) Push R15; (* align stack *)
    (* 16 *) Const RDI 4w;
    (* 17 *) Exit;
    (* abort: *)
    (* 18 *) Comment "exit 1"; (* Internal error – OOM or compiler limitation *)
    (* 19 *) Push R15; (* align stack *)
    (* 20 *) Const RDI 1w;
    (* 21 *) Exit
  ]
End

Definition AllocLoc_def:
  AllocLoc = 7:num
End

Definition abortLoc_def:
  abortLoc = 19:num
End

Definition even_len_def:
  even_len xs =
    case xs of
    | [] => T
    | (_ :: ys) =>
      case ys of
      | [] => F
      | (_ :: zs) => even_len zs
End

Definition odd_len_def:
  odd_len xs =
    case xs of
    | [] => F
    | (_ :: ys) =>
      case ys of
      | [] => T
      | (_ :: zs) => odd_len zs
End

(* jump label for failure cases
  b – does the stack need to be aligned
*)
Definition give_up_def:
  give_up b = if b then 15 else 16 : num
End

(* Compiles a constant value into assembly instructions *)
Definition c_const_def:
  c_const (n : word64) (l : num) =
    (List [Push RAX; Const RAX n], l+2)
End

(* Finds the index of a variable in a stack representation *)
Definition index_of_def:
  index_of (n : name) (k : num) (vs : v_stack) =
  case vs of
  | [] => k
  | (x :: xs) =>
    case x of
    | NONE => index_of n (k+1) xs
    | SOME v => if v = n then k else index_of n (k+1) xs
End

(* lookup variable with name `n`, based on stack `vs` *)
Definition c_var_def:
  c_var (n : name) (l : num) (vs : v_stack) =
    let k = index_of n 0 vs in
      if k = 0 then (List [Push RAX], l+1)
      else (List [Push RAX; Load_RSP RAX k], l+2)
End

(* assign variable with name `n`, based on stack *)
Definition c_assign_def:
  c_assign (n : name) (l : num) (vs : v_stack) =
    let k = index_of n 0 vs in
      case k of
      | 0 => (List [Pop RDI], l+1)
      | SUC _ => (List [Store_RSP RAX k; Pop RAX], l+2)
End

(*
  RAX := RAX + top_of_stack
*)
Definition c_add_def:
  c_add =
    List [Pop RDI; Add RAX RDI]
End

(*
  RAX := top_of_stack - RAX (or 0 if the result would be negative)
*)
Definition c_sub_def:
  c_sub =
    List [Pop RDI; Sub RDI RAX; Mov RAX RDI]
End

(*
  RAX := RAX / top_of_stack
  RDX := RAX % top_of_stack
*)
Definition c_div_def:
  c_div =
    List [Mov RDI RAX; Pop RAX; Const RDX 0w; Div RDI]
End

Definition c_alloc_def:
  c_alloc (vs : v_stack) =
    List [Mov RDI RAX; Call AllocLoc]
End

Definition app_list_length_def:
  app_list_length (List l) = LENGTH l ∧
  app_list_length (Append l1 l2) = app_list_length l1 + app_list_length l2
End

Definition c_read_def:
  c_read (vs : v_stack) (l : num) =
    (List [Push RAX; GetChar], l + 2)
End

Definition c_write_def:
  c_write (vs : v_stack) (l : num) =
    (List [Mov RDI RAX; PutChar; Pop RAX], l + 3)
End

(*
  input : RAX, top_of_stack
  RAX := top_of_stack[RAX]
  i.e.
  load (into)RAX (RAX + top of stack) 0w
*)
Definition c_load_def:
  c_load = List [Pop RDI; Add RDI RAX; Load RAX RDI 0w]
End

(*
  input : RAX, top_of_stack, snd_top_of_stack
  snd_top_of_stack[top_of_stack] := RAX
*)
Definition c_store_def:
  c_store = List [Pop RDI; Pop RDX; Add RDI RDX; Store RAX RDI 0w; Pop RAX]
End

Definition c_exp_def:
  c_exp (e : exp) (l : num) (vs : v_stack) =
  case e of
  | Var n => c_var n l vs
  | Const n => c_const n l
  | Add e1 e2 =>
      let (asm1, l1) = c_exp e1 l vs in
      let (asm2, l2) = c_exp e2 l1 (NONE :: vs) in
        (asm1 +++ asm2 +++ c_add, l2 + app_list_length c_add)
  | Sub e1 e2 =>
      let (asm1, l1) = c_exp e1 l vs in
      let (asm2, l2) = c_exp e2 l1 (NONE :: vs) in
        (asm1 +++ asm2 +++ c_sub, l2 + app_list_length c_sub)
  | Div e1 e2 =>
      let (asm1, l1) = c_exp e1 l vs in
      let (asm2, l2) = c_exp e2 l1 (NONE :: vs) in
        (asm1 +++ asm2 +++ c_div, l2 + app_list_length c_div)
  | Read e1 e2 =>
      let (asm1, l1) = c_exp e1 l vs in
      let (asm2, l2) = c_exp e2 l1 (NONE :: vs) in
        (asm1 +++ asm2 +++ c_load, l2 + app_list_length c_load)
End

Definition c_exps_def:
  c_exps (es: exp list) (l : num) (vs : v_stack) =
  case es of
  | [] => (List [], l)
  | (e :: es') =>
    let (asm1, l1) = c_exp e l vs in
    let (asm2, l2) = c_exps es' l1 (NONE :: vs) in
      (asm1 +++ asm2, l2)
End

(*
  RDI `cmp` RBX
*)
Definition c_cmp_def:
  c_cmp (c : cmp) =
  case c of
  | Less => Less RDI RBX
  | Equal => Equal RDI RBX
End

Definition c_test_jump_def:
  c_test_jump (t : test) (pos_label : num) (neg_label : num) (l : num) (vs : v_stack) =
  case t of
  | Test c e1 e2 =>
    let (asm1, l1) = c_exp e1 l vs in
    let (asm2, l2) = c_exp e2 l1 (NONE :: vs) in
    let c_cmp_asm = List [Mov RBX RAX; Pop RDI; Pop RAX;
      Jump (c_cmp c) pos_label;
      Jump Always neg_label] in
    (asm1 +++ asm2 +++ c_cmp_asm, l2 + app_list_length c_cmp_asm)
  | And t1 t2 =>
    let (asm1, l1) = c_test_jump t1 (l + 1) neg_label (l + 2) vs in
    let (asm2, l2) = c_test_jump t2 pos_label neg_label l1 vs in
    let jump_to_start = List [Jump Always (l + 2)] in
    let jump_to_t2 = List [Jump Always l1] in (* l1 is the start of t2*)
    (jump_to_start +++ jump_to_t2 +++ asm1 +++ asm2, l2)
  | Or t1 t2 =>
    let (asm1, l1) = c_test_jump t1 pos_label (l + 1) (l + 2) vs in
    let (asm2, l2) = c_test_jump t2 pos_label neg_label l1 vs in
    let jump_to_start = List [Jump Always (l + 2)] in
    let jump_to_t2 = List [Jump Always l1] in (* l1 is the start of t2*)
    (jump_to_start +++ jump_to_t2 +++ asm1 +++ asm2, l2)
  | Not t' =>
    c_test_jump t' neg_label pos_label l vs
End

(* Looks up a function name in a list of function addresses *)
Definition lookup_def:
  lookup  (n : num) (fs : f_lookup) =
  case fs of
  | [] => 0
  | ((x, y) :: xs) => if x = n then y else lookup n xs
End

(* Drop the current stack frame - elements corresponding to `vs` *)
Definition make_ret_def:
  make_ret (vs : v_stack) (l : num) =
    (List [Add_RSP (LENGTH vs); Ret], l + 2)
End

(* Store the variables from the stack in the registers, so that they can be
passed to the function call *)
Definition c_pops_def:
  c_pops (xs : exp list) (vs : v_stack) =
  let k = LENGTH xs in
  if k = 0 then List [Push RAX] else
  if k = 1 then List [] else
  if k = 2 then List [Pop RDI] else
  if k = 3 then List [Pop RDI; Pop RDX] else
  if k = 4 then List [Pop RDI; Pop RDX; Pop RBX] else
  if k = 5 then List [Pop RDI; Pop RDX; Pop RBX; Pop RBP] else
    List [Jump Always (give_up (even_len xs))]
End

(** Builds a stack representation for parameters of a function *)
Definition call_v_stack_def:
  call_v_stack (xs : name list) (acc : v_stack) =
  case xs of
  | [] => acc
  | (x :: xs') => call_v_stack xs' (SOME x :: acc)
End

Definition push_vs_def:
  push_vs (v_names : name list) =
    if LENGTH v_names = 0 then [NONE] else call_v_stack v_names []
End

(** Push a list of variables onto the stack *)
Definition c_pushes_def:
  c_pushes (v_names : name list) (l : num) =
  let k = LENGTH v_names in
  let e = push_vs v_names in
  if k = 0 then (List [], e, l) else
  if k = 1 then (List [], e, l) else
  if k = 2 then (List [Push RDI], e, l + 1) else
  if k = 3 then (List [Push RDX; Push RDI], e, l + 2) else
  if k = 4 then (List [Push RBX; Push RDX; Push RDI], e, l + 3) else
  (List [Push RBP; Push RBX; Push RDX; Push RDI], e, l + 4)
End

(* Call the given function, passing the arguments in registers*)
Definition c_call_def:
  c_call (vs : v_stack) (target : num) (xs : exp list) (l : num) =
  let asm_pops = c_pops xs vs in
  let asm_cmb = asm_pops +++ List [Call target] in
  let len = app_list_length asm_pops + 1 in
  (asm_cmb, l + len)
End

Definition c_cmd_def:
  c_cmd (c : cmd) (l : num) (fs : f_lookup) (vs : v_stack) =
  case c of
  | Skip => (List [], l)
  | Seq c1 c2 =>
    let (asm1, l1) = c_cmd c1 l fs vs in
    let (asm2, l2) = c_cmd c2 l1 fs vs in
    (asm1 +++ asm2, l2)
  | Assign n e =>
    let (asm1, l1) = c_exp e l vs in
    let (asm2, l2) = c_assign n l1 vs in
    (asm1 +++ asm2, l2)
  | Update a e e' =>
    let (asm1, l1) = c_exp a l vs in
    let (asm2, l2) = c_exp e l1 (NONE :: vs) in
    let (asm3, l3) = c_exp e' l2 (NONE :: NONE :: vs) in
    let asm4 = c_store in
    (asm1 +++ asm2 +++ asm3 +++ asm4, l3 + app_list_length asm4)
  | If t c1 c2 =>
    let (asm1, l1) = c_test_jump t (l + 1) (l + 2) (l + 3) vs in
    let (asm2, l2) = c_cmd c1 l1 fs vs in
    let (asm3, l3) = c_cmd c2 (l2 + 1) fs vs in
    let jump_to_start = List [Jump Always (l + 3)] in
    let jump_to_c1 = List [Jump Always l1] in
    let jump_to_c2 = List [Jump Always (l2 + 1)] in
    let jump_to_end = List [Jump Always l3] in
    let asmres = jump_to_start +++ jump_to_c1 +++ jump_to_c2 +++ asm1 +++ asm2 +++ jump_to_end +++ asm3 in
    (asmres, l3)
  | While tst body =>
    let (asm1, l1) = c_test_jump tst (l + 1) (l + 2) (l + 3) vs in
    let (asm2, l2) = c_cmd body l1 fs vs in
    let jump_to_tst = List [Jump Always (l + 3)] in
    let jump_to_beginning = List [Jump Always l] in
    let jump_to_body = List [Jump Always l1] in
    let jump_to_end = List [Jump Always (l2 + 1)] in
    let asmres = jump_to_tst +++ jump_to_body +++ jump_to_end +++ asm1 +++ asm2 +++ jump_to_beginning in
    (asmres, l2+1)
  | Call n f es =>
    let (asms, l1) = c_exps es l vs in
    let (asm1, l2) = c_call vs (lookup f fs) es l1 in
    let (asm2, l3) = c_assign n l2 vs in
    (asms +++ asm1 +++ asm2, l3)
  | Return e =>
    let (asm1, l1) = c_exp e l vs in
    let (asm2, l2) = make_ret vs l1 in
    (asm1 +++ asm2, l2)
  | Alloc n e =>
    let (asm1, l1) = c_exp e l vs in
    let asm2 = c_alloc vs in
    let (asm3, l3) = c_assign n (l1 + app_list_length asm2) vs in
    (asm1 +++ asm2 +++ asm3, l3)
  | GetChar n =>
    let (asm1, l1) = c_read vs l in
    let (asm2, l2) = c_assign n l1 vs in
    (asm1 +++ asm2, l2)
  | PutChar e =>
    let (asm1, l1) = c_exp e l vs in
    let (asm2, l2) = c_write vs l1 in
    (asm1 +++ asm2, l2)
  | Abort =>
    (List [Jump Always abortLoc], l+1)
End

Definition all_binders_def:
  all_binders (body: cmd) =
  case body of
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
End

Definition names_contain_def:
  names_contain (l: name list) (a: name) =
  case l of
  | [] => F
  | (x :: l) => if x = a then T else names_contain l a
End

Definition names_unique_def:
  names_unique (l: name list) (acc: name list) =
  case l of
  | [] => acc
  | (x :: l) => names_unique l (if names_contain acc x then acc else (x :: acc))
End

Definition unique_binders_def:
  unique_binders (body: cmd) =
  let binds = all_binders body in
  names_unique binds []
End

Definition make_vs_from_binders_def:
  make_vs_from_binders (binders: name list) =
  case binders of
  | [] => []
  | (b :: binders) => (SOME b) :: make_vs_from_binders binders
End

(* Remove a single name from a list of names *)
Definition fltr_nms_def:
  fltr_nms (a: name) (l: name list) =
  case l of
  | [] => []
  | (x :: xs) => if a = x then fltr_nms a xs else x :: fltr_nms a xs
End

(* Remove all names in l1 from l2 *)
Definition rm_nms_def:
  rm_nms (l1: name list) (l2: name list) =
  case l1 of
  | [] => l2
  | (x :: xs) => rm_nms xs (fltr_nms x l2)
End

(* Pad the binder stack with an extra slot when alignment requires it *)
Definition vs_bdrs_def:
  vs_bdrs (vs_after: v_stack) (vs_bind: v_stack) =
    if even_len vs_after then vs_bind ++ [NONE] else vs_bind
End

(* Reserve stack space for the (non-parameter) local binders of a function *)
Definition c_bdrs_def:
  c_bdrs (v_names: name list) (c: cmd) =
    let vs_bind = make_vs_from_binders (rm_nms v_names (unique_binders c)) in
    let vs_after = push_vs v_names ++ vs_bind in
    let vs_bind1 = vs_bdrs vs_after vs_bind in
      (List [Sub_RSP (LENGTH vs_bind1)], vs_bind1)
End

(** Compiles a single function definition into assembly code. *)
Definition c_fundef_def:
  c_fundef (fundef: func) (l: num) (fs: f_lookup) =
  case fundef of
  | Func n v_names body =>
    let (asm0, vs_bind1) = c_bdrs v_names body in
    let l0 = l + app_list_length asm0 in
    let (asm1, vs1, l1) = c_pushes v_names l0 in
    let (asm2, l2) = c_cmd body l1 fs (vs1 ++ vs_bind1) in
    (asm0 +++ asm1 +++ asm2, l2)
End

(* Converts a numeric name to a string representation *)
Definition N2ascii_def:
  N2ascii n =
    if n = 0 then "" else
      let k = n MOD 256 in
        if k < ORD #"*" then "" else
        if ORD #"z" < k then "" else
        if k = ORD #"." then "" else
        if n < 256 then [CHR k]
        else N2ascii (n DIV 256) ++ [CHR k]
Termination
  WF_REL_TAC ‘measure (λn. n)’ \\ rw []
  \\ irule DIV_LESS \\ fs []
End

(* Compiles a list of function declarations into assembly instructions *)
Definition c_fundefs_def:
  c_fundefs (ds : func list) (l : num) (fs : f_lookup)  =
  case ds of
  | [] => (List [], fs, l)
  | (d :: ds') =>
    let fname = get_name d in
    let (c1, l1) = c_fundef d (l + 1) fs in
    let (c2, fs', l2) = c_fundefs ds' (l1 + 1) fs in
    let comment = List [Comment (N2ascii fname)] in
    (comment +++ c1 +++ List [Ret] +++ c2, (fname, l + 1) :: fs', l2)
End

(* Generates the complete assembly code for a given program *)
Definition codegen_def:
  codegen (prog : prog) =
  let funs = get_funcs prog in
  let init_l = app_list_length (List (init 0)) in
  let (_, fs, _) = c_fundefs funs init_l [] in
  let (asm1, _, _) = c_fundefs funs init_l fs in
  let main_l = lookup (name "main") fs in
  flatten ((List (init main_l)) +++ asm1) [] : asm
End
