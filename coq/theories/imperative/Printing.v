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
      if (N_of_ascii "0"%char <=? k)%N then
      if (k <=? N_of_ascii "9"%char)%N then None
      else Some s else Some s
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
  let/d op_s := SStr op in
  let/d res := SPair op_s v in
  let/d resb := SBlock res in
  resb.

Definition binary_sexpr (op: string) (v1 v2: sexpr): sexpr :=
  let/d op_s := SStr op in
  let/d args := SPair v1 v2 in
  let/d res := SPair op_s args in
  let/d resb := SBlock res in
  resb.

Definition ternary_sexpr (op: string) (v1 v2 v3: sexpr): sexpr :=
  let/d op_s := SStr op in
  let/d args1 := SPair v1 v2 in
  let/d args := SPair args1 v3 in
  let/d res := SPair op_s args in
  let/d resb := SBlock res in
  resb.

Definition quaternary_sexpr (op: string) (v1 v2 v3 v4: sexpr): sexpr :=
  let/d op_s := SStr op in
  let/d args1 := SPair v1 v2 in
  let/d args2 := SPair args1 v3 in
  let/d args := SPair args2 v4 in
  let/d res := SPair op_s args in
  let/d resb := SBlock res in
  resb.

Definition name_sexpr (n: N): sexpr :=
  let/d nm := SStr (name2str n) in
  nm.

Fixpoint exp2s (e: exp): sexpr :=
  match e with
  | Var n =>
    let/d nm := name_sexpr n in
    let/d res := unary_sexpr "var" nm in
    res
  | Const w =>
    let/d w_N := Z.to_N (word.unsigned w) in
    let/d res := SNum w_N in
    res
  | Add e1 e2 =>
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d res := binary_sexpr "+" v1 v2 in
    res
  | Sub e1 e2 =>
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d res := binary_sexpr "-" v1 v2 in
    res
  | Div e1 e2 =>
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d res := binary_sexpr "div" v1 v2 in
    res
  | Read e1 e2 =>
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d res := binary_sexpr "read" v1 v2 in
    res
  end.

Fixpoint exps2s_imp (es: list exp): sexpr :=
  match es with
  | [] =>
    let/d res := SEmpty in
    res
  | e :: es' =>
    let/d v := exp2s e in
    let/d vs := exps2s_imp es' in
    let/d res := SPair v vs in
    res
  end.
Definition exps2s (es: list exp): sexpr :=
  let/d v := exps2s_imp es in
  let/d res := SBlock v in
  res.

Definition cmp2str_imp (c: cmp): string :=
  match c with
  | Less =>
    let/d res := "<" in
    res
  | Equal =>
    let/d res := "=" in
    res
  end.

Fixpoint test2s_imp (t: test): sexpr :=
  match t with
  | Test c e1 e2 =>
    let/d cmp_str := cmp2str_imp c in
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d res := binary_sexpr cmp_str v1 v2 in
    res
  | And t1 t2 =>
    let/d v1 := test2s_imp t1 in
    let/d v2 := test2s_imp t2 in
    let/d res := binary_sexpr "and" v1 v2 in
    res
  | Or t1 t2 =>
    let/d v1 := test2s_imp t1 in
    let/d v2 := test2s_imp t2 in
    let/d res := binary_sexpr "or" v1 v2 in
    res
  | Not t' =>
    let/d v := test2s_imp t' in
    let/d res := unary_sexpr "not" v in
    res
  end.

Fixpoint names2s_imp (ns: list name): sexpr :=
  match ns with
  | [] =>
    let/d res := SEmpty in
    res
  | n :: ns' =>
    let/d v := name_sexpr n in
    let/d vs := names2s_imp ns' in
    let/d res := SPair v vs in
    res
  end.
Definition names2s (ns: list name): sexpr :=
  let/d v := names2s_imp ns in
  let/d res := SBlock v in
  res.

Fixpoint cmd2s_imp (c: cmd): sexpr :=
  match c with
  | Skip =>
    let/d res := SEmpty in
    res
  | Seq c1 c2 =>
    let/d v1 := cmd2s_imp c1 in
    let/d v2 := cmd2s_imp c2 in
    let/d res := SPair v1 v2 in
    res
  | Assign n e =>
    let/d name_v := name_sexpr n in
    let/d exp_v := exp2s e in
    let/d res := binary_sexpr "assign" name_v exp_v in
    res
  | Update a e e' =>
    let/d addr_v := exp2s a in
    let/d idx_v := exp2s e in
    let/d val_v := exp2s e' in
    let/d res := ternary_sexpr "update" addr_v idx_v val_v in
    res
  | If t c1 c2 =>
    let/d test_v := test2s_imp t in
    let/d cmd1_v := cmd2s_imp c1 in
    let/d cmd2_v := cmd2s_imp c2 in
    let/d res := ternary_sexpr "if" test_v cmd1_v cmd2_v in
    res
  | While t c' =>
    let/d test_v := test2s_imp t in
    let/d cmd_v := cmd2s_imp c' in
    let/d res := binary_sexpr "while" test_v cmd_v in
    res
  | Call n f es =>
    let/d name_v := name_sexpr n in
    let/d func_v := name_sexpr f in
    let/d args_vs := exps2s es in
    let/d res := ternary_sexpr "call" name_v func_v args_vs in
    res
  | Return e =>
    let/d exp_v := exp2s e in
    let/d res := unary_sexpr "return" exp_v in
    res
  | Alloc n e =>
    let/d name_v := name_sexpr n in
    let/d size_v := exp2s e in
    let/d res := binary_sexpr "alloc" name_v size_v in
    res
  | GetChar n =>
    let/d name_v := name_sexpr n in
    let/d res := unary_sexpr "getchar" name_v in
    res
  | PutChar e =>
    let/d char_v := exp2s e in
    let/d res := unary_sexpr "putchar" char_v in
    res
  | Abort =>
    let/d res := SStr "abort" in
    let/d resb := SBlock res in
    resb
  end.

Definition func2s (f: func): sexpr :=
  match f with
  | Func n params body =>
    let/d name_v := name_sexpr n in
    let/d params_vs := names2s params in
    let/d body_v := cmd2s_imp body in
    let/d body_vb := SBlock body_v in
    let/d res := ternary_sexpr "defun" name_v params_vs body_vb in
    res
  end.

Fixpoint funcs2s_imp (fs: list func): sexpr :=
  match fs with
  | [] =>
    let/d res := SEmpty in
    res
  | f :: fs' =>
    let/d v := func2s f in
    let/d vs := funcs2s_imp fs' in
    let/d res := SPair v vs in
    res
  end.

Definition prog2s_imp (p: prog): sexpr :=
  match p with
  | Program funcs =>
    let/d funcs_vs := funcs2s_imp funcs in
    funcs_vs
  end.

Fixpoint sexpr2str (s: sexpr): string :=
  match s with
  | SNum n =>
    let/d res := "'" ++ N2str n "" in
    res
  | SStr str =>
    str
  | SPair s1 s2 =>
    let/d str1 := sexpr2str s1 in
    let/d str2 := sexpr2str s2 in
    let/d res := str1 ++ " " ++ str2 in
    res
  | SEmpty =>
    let/d res := "" in
    res
  | SBlock s' =>
    let/d str' := sexpr2str s' in
    let/d res := "(" ++ str' ++ ")" in
    res
  end.

Definition imp2str (p: prog): string :=
  let/d v := prog2s_imp p in
  let/d res := sexpr2str v in
  res.
