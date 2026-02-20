From impboot Require Import
  utils.Core
  utils.Llist.
Import Llist.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.functional.FunValues.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
Require Import impboot.commons.CompilerUtils.

Require Import Patat.Patat.

Open Scope N.
Open Scope string.

Definition ascii_name (n: N): option string :=
  match N2ascii n with
  | None => None
  | Some s =>
    match s with
    | EmptyString => None
    | String hd _ =>
      let k := N_of_ascii hd in
      if (N_of_ascii "0"%char <=? k)%N && (k <=? N_of_ascii "9"%char)%N then None else Some s
    end
  end.

Definition name2str (n: N): string :=
  match ascii_name n with
  | None => N2str n ""
  | Some s => s
  end.

(* Pretty printer for ImpSyntax – generates s-expression syntax *)

Inductive sexpr :=
| SNum (n: N)
| SStr (s: string)
| SBlock (s: sexpr)
| SPair (s1 s2: sexpr)
| SEmpty.

(* Helper constructors for common s-expression patterns *)

Definition unary_sexpr (op: string) (v: sexpr): sexpr :=
  let res := SPair (SStr op) v in
  SBlock res.

Definition binary_sexpr (op: string) (v1 v2: sexpr): sexpr :=
  let res := SPair (SStr op) (SPair v1 v2) in
  SBlock res.

Definition ternary_sexpr (op: string) (v1 v2 v3: sexpr): sexpr :=
  let res := SPair (SStr op) (SPair (SPair v1 v2) v3) in
  SBlock res.

Definition quaternary_sexpr (op: string) (v1 v2 v3 v4: sexpr): sexpr :=
  let res := SPair (SStr op) (SPair (SPair (SPair v1 v2) v3) v4) in
  SBlock res.

Definition name_sexpr (n: N): sexpr := SStr (name2str n).

Fixpoint exp2s (e: exp): sexpr :=
  match e with
  | Var n =>
    let nm := name_sexpr n in
    unary_sexpr "var" nm
  | Const w =>
    let w_N := Z.to_N (word.unsigned w) in
    SNum w_N
  | Add e1 e2 =>
    let v1 := exp2s e1 in
    let v2 := exp2s e2 in
    binary_sexpr "+" v1 v2
  | Sub e1 e2 =>
    let v1 := exp2s e1 in
    let v2 := exp2s e2 in
    binary_sexpr "-" v1 v2
  | Div e1 e2 =>
    let v1 := exp2s e1 in
    let v2 := exp2s e2 in
    binary_sexpr "div" v1 v2
  | Read e1 e2 =>
    let v1 := exp2s e1 in
    let v2 := exp2s e2 in
    binary_sexpr "read" v1 v2
  end.

Fixpoint exps2s_imp (es: list exp): sexpr :=
  match es with
  | [] => SEmpty
  | e :: es' =>
    let v := exp2s e in
    let vs := exps2s_imp es' in
    SPair v vs
  end.
Definition exps2s (es: list exp): sexpr :=
  let v := exps2s_imp es in
  SBlock v.

Definition cmp2str_imp (c: cmp): string :=
  match c with
  | Less => "<"
  | Equal => "="
  end.

Fixpoint test2s_imp (t: test): sexpr :=
  match t with
  | Test c e1 e2 =>
    let cmp_str := cmp2str_imp c in
    let v1 := exp2s e1 in
    let v2 := exp2s e2 in
    binary_sexpr cmp_str v1 v2
  | And t1 t2 =>
    let v1 := test2s_imp t1 in
    let v2 := test2s_imp t2 in
    binary_sexpr "and" v1 v2
  | Or t1 t2 =>
    let v1 := test2s_imp t1 in
    let v2 := test2s_imp t2 in
    binary_sexpr "or" v1 v2
  | Not t' =>
    let v := test2s_imp t' in
    unary_sexpr "not" v
  end.

Fixpoint names2s_imp (ns: list name): sexpr :=
  match ns with
  | [] =>
    let res := SEmpty in
    res
  | n :: ns' =>
    let v := name_sexpr n in
    let vs := names2s_imp ns' in
    SPair v vs
  end.
Definition names2s (ns: list name): sexpr :=
  let v := names2s_imp ns in
  SBlock v.

Fixpoint cmd2s_imp (c: cmd): sexpr :=
  match c with
  | Skip =>
    SStr "skip"
  | Seq c1 c2 =>
    let v1 := cmd2s_imp c1 in
    let v2 := cmd2s_imp c2 in
    let r := SPair v1 v2 in
    SBlock r
  | Assign n e =>
    let name_v := name_sexpr n in
    let exp_v := exp2s e in
    binary_sexpr "assign" name_v exp_v
  | Update a e e' =>
    let addr_v := exp2s a in
    let idx_v := exp2s e in
    let val_v := exp2s e' in
    ternary_sexpr "update" addr_v idx_v val_v
  | If t c1 c2 =>
    let test_v := test2s_imp t in
    let cmd1_v := cmd2s_imp c1 in
    let cmd2_v := cmd2s_imp c2 in
    ternary_sexpr "if" test_v cmd1_v cmd2_v
  | While t c' =>
    let test_v := test2s_imp t in
    let cmd_v := cmd2s_imp c' in
    binary_sexpr "while" test_v cmd_v
  | Call n f es =>
    let name_v := name_sexpr n in
    let func_v := name_sexpr f in
    let args_vs := exps2s es in
    ternary_sexpr "call" name_v func_v args_vs
  | Return e =>
    let exp_v := exp2s e in
    unary_sexpr "return" exp_v
  | Alloc n e =>
    let name_v := name_sexpr n in
    let size_v := exp2s e in
    binary_sexpr "alloc" name_v size_v
  | GetChar n =>
    let name_v := name_sexpr n in
    unary_sexpr "getchar" name_v
  | PutChar e =>
    let char_v := exp2s e in
    unary_sexpr "putchar" char_v
  | Abort =>
    let res := SStr "abort" in
    SBlock res
  end.

Definition func2s (f: func): sexpr :=
  match f with
  | Func n params body =>
    let name_v := name_sexpr n in
    let params_vs := names2s params in
    let body_v := cmd2s_imp body in
    let body_vb := SBlock body_v in
    ternary_sexpr "defun" name_v params_vs body_vb
  end.

Fixpoint funcs2s_imp (fs: list func): sexpr :=
  match fs with
  | [] => SEmpty
  | f :: fs' =>
    let v := func2s f in
    let vs := funcs2s_imp fs' in
    SPair v vs
  end.

Definition prog2s_imp (p: prog): sexpr :=
  match p with
  | Program funcs =>
    funcs2s_imp funcs
  end.

Inductive str_app_list: Type :=
| StrList : string -> str_app_list
| StrAppend : str_app_list -> str_app_list -> str_app_list.
Notation "xs +++ ys" := (StrAppend xs ys) (right associativity, at level 60).

Fixpoint sexpr2str (s: sexpr): str_app_list :=
  match s with
  | SNum n =>
    StrList "'" +++ StrList (N2str n "")
  | SStr str => StrList str
  | SPair s1 s2 =>
    let str1 := sexpr2str s1 in
    let str2 := sexpr2str s2 in
    str1 +++ StrList " " +++ str2
  | SEmpty => StrList ""
  | SBlock s' =>
    let str' := sexpr2str s' in
    StrList "(" +++ str' +++ StrList ")"
  end.

Fixpoint flatten_str_app_list (sal: str_app_list): string :=
  match sal with
  | StrList s => s
  | StrAppend sal1 sal2 =>
    let s1 := flatten_str_app_list sal1 in
    let s2 := flatten_str_app_list sal2 in
    s1 ++ s2
  end.

Definition imp2str (p: prog): string :=
  let v := prog2s_imp p in
  flatten_str_app_list (sexpr2str v).
