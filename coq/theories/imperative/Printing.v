From impboot Require Import
  utils.Core
  utils.Llist.
Import Llist.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.functional.FunValues.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
Require Import impboot.commons.PrintingUtils.

Require Import Patat.Patat.

Open Scope N.
Open Scope string.

Fixpoint N2ascii_f (n: N) (fuel: nat): option string :=
  if (n =? 0)%N then None else
  let k := N_modulo n 256 in
  if ((N_of_ascii "*"%char <=? k) && (k <=? N_of_ascii "z"%char) && negb (k =? N_of_ascii "."%char))%N then
  if (n <? 256)%N then Some (String (ascii_of_N k) EmptyString) else
    match fuel with
    | 0%nat => Some EmptyString
    | S fuel =>
      match N2ascii_f (n / 256) fuel with
      | None => None
      | Some s => Some (s ++ String (ascii_of_N k) EmptyString)
      end
    end
  else None.

Theorem N2ascii_f_terminates: forall (n1: nat) (n: N),
  (n <= ((N.of_nat n1 * 256) - 1))%N -> N2ascii_f n n1 <> Some EmptyString.
Proof.
  Opaque N.add N.div N_modulo N_of_ascii.
  induction n1; intros; simpl; unfold dlet; simpl.
  all: destruct (n =? 0)%N eqn:?; rewrite ?N.eqb_eq, ?N.eqb_neq in *; subst; try lia; try congruence.
  set (k := N_modulo n 256).
  destruct (_ && _) eqn:?; try congruence.
  destruct (_ <? _)%N eqn:?; [congruence|]; rewrite N.ltb_ge in *.
  destruct N2ascii_f; try congruence.
  destruct s; simpl; try congruence.
Qed.
Transparent N.add N.div N_modulo N_of_ascii.

Definition N2ascii (n: N): option (string) :=
  N2ascii_f n (N.to_nat (n / 256 + 1)).

Theorem N2ascii_terminates: forall (n: N),
  N2ascii n <> Some EmptyString.
Proof.
  intros; eapply N2ascii_f_terminates; rewrite Nnat.N2Nat.id.
  rewrite (N.div_mod n 256) at 1 by discriminate.
  rewrite N.mul_comm, N.mul_add_distr_r, N.mul_1_l.
  assert (n mod 256 < 256)%N by (eapply N.mod_lt; lia).
  destruct (n mod 256)%N eqn:?; rewrite ?N.eqb_eq, ?N.eqb_neq in *; subst; try lia.
Qed.

Definition ascii_name n :=
  match N2ascii n with
  | None => None
  | Some s =>
    match get 0 s with
    | None => None
    | Some hd =>
      let k := N_of_ascii hd in
      if (N_of_ascii "0"%char <=? k)%N && (k <=? N_of_ascii "9"%char)%N then None else Some s
    end
  end.

Definition name2str n :=
  match ascii_name n with
  | None => N2str n ""
  | Some s => s
  end.

Fixpoint v2str (v: Value): string :=
  match v with
  | Num n =>
    let/d res := N2str n "" in
    res
  | Pair v1 v2 =>
    let/d str1 := v2str v1 in
    let/d str2 := v2str v2 in
    let/d res := ((String "("%char str1) ++ (String " "%char str2) ++ String ")"%char "") in
    res
  end.

(* Pretty printer for ImpSyntax - generates s-expression syntax *)

Inductive sexpr :=
| SNum (n: N)
| SStr (s: string)
| SPair (s1 s2: sexpr).

Fixpoint exp2v_imp (e: exp): Value :=
  match e with
  | Var n =>
    let/d nm := Num n in
    let/d vend := Num 0 in
    let/d res := Pair nm vend in
    res
  | Const w =>
    let/d w_N := Z.to_N (word.unsigned w) in
    let/d quote_name := name_of_string "'" in
    let/d quote_num := Num quote_name in
    let/d const_num := Num w_N in
    let/d vals := Pair quote_num (Pair const_num (Num 0)) in
    vals
  | Add e1 e2 =>
    let/d v1 := exp2v_imp e1 in
    let/d v2 := exp2v_imp e2 in
    let/d add_name := name_of_string "+" in
    let/d add_num := Num add_name in
    let/d vals := Pair add_num (Pair v1 (Pair v2 (Num 0))) in
    vals
  | Sub e1 e2 =>
    let/d v1 := exp2v_imp e1 in
    let/d v2 := exp2v_imp e2 in
    let/d sub_name := name_of_string "-" in
    let/d sub_num := Num sub_name in
    let/d vals := Pair sub_num (Pair v1 (Pair v2 (Num 0))) in
    vals
  | Div e1 e2 =>
    let/d v1 := exp2v_imp e1 in
    let/d v2 := exp2v_imp e2 in
    let/d div_name := name_of_string "div" in
    let/d div_num := Num div_name in
    let/d vals := Pair div_num (Pair v1 (Pair v2 (Num 0))) in
    vals
  | Read e1 e2 =>
    let/d v1 := exp2v_imp e1 in
    let/d v2 := exp2v_imp e2 in
    let/d read_name := name_of_string "read" in
    let/d read_num := Num read_name in
    let/d vals := Pair read_num (Pair v1 (Pair v2 (Num 0))) in
    vals
  end.

Fixpoint exps2v_imp (es: list exp): Value :=
  match es with
  | [] =>
    let/d res := Num 0 in
    res
  | e :: es' =>
    let/d v := exp2v_imp e in
    let/d vs := exps2v_imp es' in
    let/d res := Pair v vs in
    res
  end.

Definition cmp2str_imp (c: cmp): name :=
  match c with
  | Less =>
    let/d res := name_of_string "<" in
    res
  | Equal =>
    let/d res := name_of_string "=" in
    res
  end.

Fixpoint test2v_imp (t: test): Value :=
  match t with
  | Test c e1 e2 =>
    let/d cmp_name := cmp2str_imp c in
    let/d cmp_num := Num cmp_name in
    let/d v1 := exp2v_imp e1 in
    let/d v2 := exp2v_imp e2 in
    let/d vals := Pair cmp_num (Pair v1 (Pair v2 (Num 0))) in
    vals
  | And t1 t2 =>
    let/d v1 := test2v_imp t1 in
    let/d v2 := test2v_imp t2 in
    let/d and_name := name_of_string "and" in
    let/d and_num := Num and_name in
    let/d vals := Pair and_num (Pair v1 (Pair v2 (Num 0))) in
    vals
  | Or t1 t2 =>
    let/d v1 := test2v_imp t1 in
    let/d v2 := test2v_imp t2 in
    let/d or_name := name_of_string "or" in
    let/d or_num := Num or_name in
    let/d vals := Pair or_num (Pair v1 (Pair v2 (Num 0))) in
    vals
  | Not t' =>
    let/d v := test2v_imp t' in
    let/d not_name := name_of_string "not" in
    let/d not_num := Num not_name in
    let/d vals := Pair not_num (Pair v (Num 0)) in
    vals
  end.

Fixpoint names2v_imp (ns: list name): Value :=
  match ns with
  | [] =>
    let/d res := Num 0 in
    res
  | n :: ns' =>
    let/d v := Num n in
    let/d vs := names2v_imp ns' in
    let/d res := Pair v vs in
    res
  end.

Fixpoint cmd2v_imp (c: cmd): Value :=
  match c with
  | Skip =>
    let/d skip_name := name_of_string "skip" in
    let/d res := Num skip_name in
    res
  | Seq c1 c2 =>
    let/d v1 := cmd2v_imp c1 in
    let/d v2 := cmd2v_imp c2 in
    let/d seq_name := name_of_string "seq" in
    let/d seq_num := Num seq_name in
    let/d vals := Pair seq_num (Pair v1 (Pair v2 (Num 0))) in
    vals
  | Assign n e =>
    let/d name_v := Num n in
    let/d exp_v := exp2v_imp e in
    let/d assign_name := name_of_string "assign" in
    let/d assign_num := Num assign_name in
    let/d vals := Pair assign_num (Pair name_v (Pair exp_v (Num 0))) in
    vals
  | Update a e e' =>
    let/d addr_v := exp2v_imp a in
    let/d idx_v := exp2v_imp e in
    let/d val_v := exp2v_imp e' in
    let/d update_name := name_of_string "update" in
    let/d update_num := Num update_name in
    let/d vals := Pair update_num (Pair addr_v (Pair idx_v (Pair val_v (Num 0)))) in
    vals
  | If t c1 c2 =>
    let/d test_v := test2v_imp t in
    let/d cmd1_v := cmd2v_imp c1 in
    let/d cmd2_v := cmd2v_imp c2 in
    let/d if_name := name_of_string "if" in
    let/d if_num := Num if_name in
    let/d vals := Pair if_num (Pair test_v (Pair cmd1_v (Pair cmd2_v (Num 0)))) in
    vals
  | While t c' =>
    let/d test_v := test2v_imp t in
    let/d cmd_v := cmd2v_imp c' in
    let/d while_name := name_of_string "while" in
    let/d while_num := Num while_name in
    let/d vals := Pair while_num (Pair test_v (Pair cmd_v (Num 0))) in
    vals
  | Call n f es =>
    let/d name_v := Num n in
    let/d func_v := Num f in
    let/d args_vs := exps2v_imp es in
    let/d call_name := name_of_string "call" in
    let/d call_num := Num call_name in
    let/d vals := Pair call_num (Pair name_v (Pair func_v (Pair args_vs (Num 0)))) in
    vals
  | Return e =>
    let/d exp_v := exp2v_imp e in
    let/d return_name := name_of_string "return" in
    let/d return_num := Num return_name in
    let/d vals := Pair return_num (Pair exp_v (Num 0)) in
    vals
  | Alloc n e =>
    let/d name_v := Num n in
    let/d size_v := exp2v_imp e in
    let/d alloc_name := name_of_string "alloc" in
    let/d alloc_num := Num alloc_name in
    let/d vals := Pair alloc_num (Pair name_v (Pair size_v (Num 0))) in
    vals
  | GetChar n =>
    let/d name_v := Num n in
    let/d getchar_name := name_of_string "getchar" in
    let/d getchar_num := Num getchar_name in
    let/d vals := Pair getchar_num (Pair name_v (Num 0)) in
    vals
  | PutChar e =>
    let/d char_v := exp2v_imp e in
    let/d putchar_name := name_of_string "putchar" in
    let/d putchar_num := Num putchar_name in
    let/d vals := Pair putchar_num (Pair char_v (Num 0)) in
    vals
  | Abort =>
    let/d abort_name := name_of_string "abort" in
    let/d res := Num abort_name in
    res
  end.

Definition func2v_imp (f: func): Value :=
  match f with
  | Func n params body =>
    let/d name_v := Num n in
    let/d params_vs := names2v_imp params in
    let/d body_v := cmd2v_imp body in
    let/d defun_name := name_of_string "defun" in
    let/d defun_num := Num defun_name in
    let/d vals := Pair defun_num (Pair name_v (Pair params_vs (Pair body_v (Num 0)))) in
    vals
  end.

Fixpoint funcs2v_imp (fs: list func): Value :=
  match fs with
  | [] =>
    let/d res := Num 0 in
    res
  | f :: fs' =>
    let/d v := func2v_imp f in
    let/d vs := funcs2v_imp fs' in
    let/d res := Pair v vs in
    res
  end.

Definition prog2v_imp (p: prog): Value :=
  match p with
  | Program funcs =>
    let/d funcs_vs := funcs2v_imp funcs in
    let/d program_name := name_of_string "program" in
    let/d program_num := Num program_name in
    let/d vals := Pair program_num (Pair funcs_vs (Num 0)) in
    vals
  end.

Definition imp2str (p: prog): string :=
  let/d v := prog2v_imp p in
  let/d res := v2str v in
  res.

(* 
(* TODO: Is nested patterns trouble? *)
Definition dest_quote v :=
  match v with
  | (Pair x (Pair (Num n) (Num 0))) =>
    match x with
    | Num m =>
      if (m =? name_enc "'")%N then Some (name2str n) else None
    | _ => None
    end
  | _ => None
  end.

Fixpoint dest_list (v: Value): (list Value * Value) :=
  match v with
  | Num n => ([], Num n)
  | Pair x y =>
    let (l, e) := dest_list y in
    (x::l, e)
  end.

(* Theorem dest_list_size: ∀v e l,
    (l,e) = dest_list v ->
    v_size e ≤ v_size v ∧
    (~isNum v -> v_size e < v_size v) ∧
    ∀x, MEM x l -> v_size x < v_size v.
Proof
  Induct_on ‘v’ \\ fs [dest_list_def,isNum_def]
  \\ pairarg_tac \\ fs [] \\ rw [] \\ res_tac \\ fs [v_size_def]
QED *)

Inductive pretty: Type :=
| Parenthesis (inner: pretty)
| Str (str: list ascii)
| Append (l: pretty) (nl: bool) (r: pretty)
| Size (n: N) (inner: pretty).

Fixpoint newlines xs :=
  match xs with
  | [] => Str []
  | x :: nil => x
  | x :: xs => Append x true (newlines xs)
  end.

Definition is_Num_0 v :=
  match v with
  | Num n => (n =? 0)%N
  | _ => false
  end.

Fixpoint v2pretty (v: Value): pretty :=
  match v with
  | Num n => Str (name2str n)
  | _ =>
    match dest_quote v with
    | Some s => Str s
    | None =>
      let (l, e) := dest_list v in
        Parenthesis (
          if is_Num_0 e then
            newlines (List.map v2pretty l)
          else
            Append (newlines (List.map v2pretty l)) true
              (Append (Str [" "; "."; " "]%char) true (v2pretty e))
        )
    end
  end.
(* Termination
  WF_REL_TAC ‘measure v_size’ \\ rw []
  \\ imp_res_tac dest_list_size \\ fs [isNum_def]
End *)

Fixpoint get_size (p: pretty): N :=
  match p with
  | Size n x => n
  | Append x _ y => get_size x + get_size y + 1
  | Parenthesis x => get_size x + 2
  | _ => 0
  end.

Fixpoint get_next_size (p: pretty): N :=
  match p with
  | Size n x => n
  | Append x _ y => get_next_size x
  | Parenthesis x => get_next_size x + 2
  | _ => 0
  end.

Fixpoint annotate (p: pretty): pretty :=
  match p with
  | Str s => Size (N.of_nat (List.length s)) (Str s)
  | Parenthesis b =>
    let b := (annotate b) in
       Size (get_size b + 2) (Parenthesis b)
  | Append b1 n b2 =>
    let b1 := annotate b1 in
     let b2 := annotate b2 in
       (* Size (get_size b1 + get_size b2 + 1) *) (Append b1 n b2)
  | Size n b => annotate b
  end.

Fixpoint remove_all (p: pretty): pretty :=
  match p with
  | Parenthesis v => Parenthesis (remove_all v)
  | Str v1 => Str v1
  | Append v2 _ v3 => Append (remove_all v2) false (remove_all v3)
  | Size v4 v5 => remove_all v5
  end.

Fixpoint smart_remove i k (p: pretty): pretty :=
  match p with
  | Size n b =>
    (if (k + n <? 70)%N then remove_all b else smart_remove i k b)
  | Parenthesis v => Parenthesis (smart_remove (i+1) (k+1) v)
  | Str v1 => Str v1
  | Append v2 b v3 =>
    let n2 := get_size v2 in
    let n3 := get_next_size v3 in
      if (k + n2 + n3 <? 50)%N then
        Append (smart_remove i k v2) false (smart_remove i (k+n2) v3)
      else
        Append (smart_remove i k v2) true (smart_remove i i v3)
  end.

Fixpoint flatten indent (p: pretty) (s: list ascii): list ascii :=
  match p with
  | Size n p => flatten indent p s
  | Parenthesis p => (["("]%char ++ flatten (indent ++ [" "; " "; " "]%char)%list p ([")"]%char ++ s)%list)%list
  | Str t => t ++ s
  | Append p1 b p2 =>
    flatten indent p1 ((if b then indent else [" "]%char) ++ flatten indent p2 s)
  end.

Definition v2str v :=
  flatten "\n" (smart_remove 0 0 (annotate (v2pretty v))) "".

Definition is_comment_def:
  is_comment [] = T
  is_comment (c::cs) =
    if c = ascii_of_N 35 then
      (case dropWhile (λx. x ≠ ascii_of_N 10) cs with
       | [] => F
       | (c::cs) => is_comment cs)
    else if c = ascii_of_N 10 then is_comment cs else F
Termination
  WF_REL_TAC ‘measure LENGTH’ \\ rw []
  \\ rename [‘dropWhile f xs’]
  \\ qspecl_then [‘f’,‘xs’] mp_tac LENGTH_dropWhile_LESS_EQ
  \\ fs []
End

Definition vs2str_def:
  vs2str [] coms = "\n" ∧
  vs2str (x::xs) coms =
    ((case coms with [] => [] | (c::cs) => if is_comment c then c else []) ++
    ("\n" ++ (v2str x ++ ("\n" ++ vs2str xs (case coms with [] => [] | c::cs => cs)))))
End

(* converting prog to v *)

Definition op2str_def:
  op2str Add = "+" ∧
  op2str Sub = "-" ∧
  op2str Div = "div" ∧
  op2str Cons = "cons*" ∧
  op2str Head = "head" ∧
  op2str Tail = "tail" ∧
  op2str Read = "read" ∧
  op2str Write = "write"
End

Definition test2str_def:
  test2str Less = "<" ∧
  test2str Equal = "="
End

Definition protected_names_def:
  protected_names =
    (* does not need to include "defun" *)
    ["'"; "if"; "let"; "call"; "+"; "-"; "div"; "<"; "="; "cons"; "cons*";
     "head"; "tail"; "read"; "write"; "list"; "case"; "var"]
End

Definition dest_cons_chain_def:
  dest_cons_chain (Op Cons [x; y]) =
    (case dest_cons_chain y with
     | None => Some [x; y]
     | Some xs => Some (x :: xs)) ∧
  dest_cons_chain _ = None
End

Theorem dest_cons_chain_size:
  ∀x vs. dest_cons_chain x = Some vs -> list_size exp_size vs + op_size Cons + 1 ≤ exp_size x
Proof
  completeInduct_on ‘exp_size x’ \\ rw [] \\ fs [PULL_FORALL]
  \\ qpat_x_assum ‘dest_cons_chain _ = Some _’ mp_tac
  \\ once_rewrite_tac [DefnBase.one_line_ify None dest_cons_chain_def]
  \\ fs [AllCaseEqs()] \\ rw [] >> rw[]
  \\ first_assum (first_assum o mp_then Any mp_tac)
  \\ strip_tac \\ fs []
QED

Definition up_const_def:
  up_const (Const n::_) = (if is_upper n then Some n else None) ∧
  up_const _ = None
End

Definition is_Let_def[simp]:
  is_Let (Let _ _ _) = T ∧
  is_Let _ = F
End

Theorem exp_size_non_zero:
  exp_size y ≠ 0
Proof
  Cases_on ‘y’ \\ fs [exp_size_def]
QED

Definition dest_case_lets_def:
  dest_case_lets z (Let v x y) =
    (if x ≠ Op Head [z] then ([], Let v x y) else
       let (vs,t) = dest_case_lets (Op Tail [z]) y in
         (v::vs,t)) ∧
  dest_case_lets z r = ([],r)
End

Definition dest_case_tree_def:
  dest_case_tree y (Const n) = (if n = 0 then Some [] else None) ∧
  dest_case_tree y (If Equal [Const k; x] t1 t2) =
    (if x ≠ Op Head [y] then None else
       match dest_case_tree y t2 with
       | None => None
       | Some rows =>
          let (vars,rhs) = dest_case_lets (Op Tail [y]) t1 in
            Some ((k,vars,rhs)::rows)) ∧
  dest_case_tree y _ = None
End

Definition row2v_def:
  row2v [] = Num 0 ∧
  row2v ((k,vars,v)::rest) = cons (list [list (Num k :: MAP Num vars); v]) (row2v rest)
End

Definition get_Op_Head_def:
  get_Op_Head (Op Head [x]) = x ∧
  get_Op_Head _ = Const 0
End

Definition dest_case_enum_def:
  dest_case_enum y (Const n) = (if n = 0 then Some [] else None) ∧
  dest_case_enum y (If Equal [x; Const k] t1 t2) =
    (if x ≠ y then None else
     if k = name "_" then None else
       match dest_case_enum y t2 with
       | None => None
       | Some rows => Some ((Some k,t1)::rows)) ∧
  dest_case_enum y (If Less [Const n; Const m] t1 t2) =
    (if n ≠ 0 ∨ m ≠ 1 then None else
       match dest_case_enum y t2 with
       | None => None
       | Some rows => Some ((None,t1)::rows)) ∧
  dest_case_enum y _ = None
End

Definition enum2v_def:
  enum2v [] = Num 0 ∧
  enum2v ((None,v)::rest) = cons (list [Name "_"; v]) (enum2v rest) ∧
  enum2v ((Some k,v)::rest) =  cons (list [Num k; v]) (enum2v rest)
End

Theorem dest_case_enum_exp_size:
  ∀a x rows t h h' y z.
    dest_case_enum a x = Some rows ∧
    x = If t [h; h'] y z ->
    list_size exp_size (MAP SND rows) <
    exp_size h + exp_size h' + exp_size y + exp_size z
Proof
  ho_match_mp_tac dest_case_enum_ind
  \\ simp [dest_case_enum_def,AllCaseEqs()] \\ rw []
  \\ gvs []
  \\ qpat_x_assum ‘_ = Some _’ mp_tac
  \\ simp [Once (oneline dest_case_enum_def), AllCaseEqs()]
  \\ strip_tac \\ gvs []
QED

Theorem dest_case_lets_exp_size:
  ∀x y vars e. dest_case_lets x y = (vars,e) -> exp_size e ≤ exp_size y
Proof
  ho_match_mp_tac dest_case_lets_ind
  \\ fs [dest_case_lets_def]
  \\ rw [] \\ pairarg_tac \\ gvs[]
QED

Theorem dest_case_tree_exp_size:
  ∀z a t xs y rows.
    dest_case_tree a (If t xs y z) = Some rows ->
    list_size exp_size (MAP SND (MAP SND rows)) ≤ exp_size y + exp_size z ∧
    exp_size a < list_size exp_size xs
Proof
  gen_tac \\ completeInduct_on ‘exp_size z’
  \\ gen_tac \\ strip_tac \\ fs [PULL_FORALL]
  \\ simp [Once (DefnBase.one_line_ify None dest_case_tree_def), AllCaseEqs()]
  \\ fs [PULL_EXISTS]
  \\ rpt gen_tac \\ strip_tac
  \\ pairarg_tac \\ fs []
  \\ rpt BasicProvers.var_eq_tac
  \\ rw [] \\ fs []
  \\ ‘exp_size z ≠ 0’ by (Cases_on ‘z’ \\ fs [])
  \\ imp_res_tac dest_case_lets_exp_size \\ fs []
  \\ Cases_on ‘z’ \\ fs [dest_case_tree_def]
  \\ rw [] \\ fs []
  \\ rename [‘If _ _ _ e4’]
  \\ first_x_assum (qspec_then ‘e4’ mp_tac)
  \\ fs []
  \\ disch_then drule \\ fs []
QED

Definition is_protected_def:
  is_protected n ⇔ MEM n (MAP name protected_names) ∨ is_upper n
End

Definition exp2v_def:
  exp2v (Var v) =
    (if is_upper v then list [Num (name "var"); Num v] else Num v) ∧
  exp2v (Const n) =
    (if is_upper n then Num n else list [Num (name "'"); Num n]) ∧
  exp2v (Op op es) =
    (case dest_cons_chain (Op op es) with
     | Some es =>
         if ~NULL es ∧ LAST es = Const 0 then
           (case up_const es with
            | None => list ([Name "list"] ++ FRONT (exps2v es))
            | Some k => list (Num k :: FRONT (exps2v (TL es))))
         else list ([Name "cons"] ++ exps2v es)
     | None => list ([Name (op2str op)] ++ exps2v es)) ∧
  exp2v (If t xs y z) =
    (if LENGTH xs = 2 then
       let x0 = HD xs in
       let x1 = EL 1 xs in
        (case dest_case_enum x0 (If t xs y z) with
         | Some rows =>
             let xs = exps2v (MAP SND rows) in
             let ys = ZIP (MAP FST rows, xs) in
               cons (Name "case") (cons (exp2v x0) (enum2v ys))
         | None =>
           match dest_case_tree (get_Op_Head x1) (If t xs y z) with
           | Some rows =>
               let xs = exps2v (MAP SND (MAP SND rows)) in
               let ys = ZIP (MAP FST rows, ZIP (MAP (FST o SND) rows, xs)) in
                 cons (Name "case") (cons (exp2v (get_Op_Head x1)) (row2v ys))
           | None =>
              list [Num (name "if");
                    list (Num (name (test2str t)) :: exps2v xs);
                    exp2v y; exp2v z])
     else
       list [Num (name "if");
             list (Num (name (test2str t)) :: exps2v xs);
             exp2v y; exp2v z]) ∧
  exp2v (Let v x y) =
    (cons (Name "let") (lets2v (Let v x y))) ∧
  exp2v (Call n es) =
    (if is_protected n then
       list ([Num (name "call"); Num n] ++ exps2v es)
     else list ([Num n] ++ exps2v es)) ∧
  exps2v [] = [] ∧
  exps2v (v::vs) = exp2v v :: exps2v vs ∧
  lets2v (Let v x y) = (cons (list [Num v; exp2v x])
                             (if is_Let y then lets2v y else list [exp2v y])) ∧
  lets2v _ = Num 0
Termination
  WF_REL_TAC ‘measure (λx. case x with INL v => exp_size v + 1
                                   | INR (INL v) => list_size exp_size v + 1
                                   | INR (INR v) => exp_size v)’ \\ rw []
  \\ gvs [LENGTH_EQ_NUM_compute]
  \\ ‘exp_size x ≠ 0 ∧ exp_size y ≠ 0’ by fs [exp_size_non_zero] \\ fs []
  \\ imp_res_tac dest_case_enum_exp_size \\ fs []
  \\ imp_res_tac dest_case_tree_exp_size \\ fs []
  \\ imp_res_tac dest_cons_chain_size \\ gvs []
  \\ fs [dest_cons_chain_def]
  \\ TRY (Cases_on ‘op’) \\ fs [dest_cons_chain_def]
  \\ Cases_on ‘v’ \\ gvs []
End

Definition dec2v_def:
  dec2v (Defun n params body) =
    list [Num (name "defun"); Num n; list (MAP Num params); exp2v body]
End

Definition prog2vs_def:
  prog2vs (Program [] main) = [exp2v main] ∧
  prog2vs (Program (d::ds) main) = dec2v d :: prog2vs (Program ds main)
End


(* entire pretty printer *)

Definition prog2str_def:
  prog2str p = vs2str (prog2vs p)
End *)