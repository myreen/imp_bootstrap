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

Fixpoint exp2s (e: exp): sexpr :=
  match e with
  | Var n =>
    let/d var := SStr "var" in
    let/d nm := SStr (name2str n) in
    let/d res := SPair var nm in
    let/d resb := SBlock res in
    resb
  | Const w =>
    let/d w_N := Z.to_N (word.unsigned w) in
    let/d const_num := SNum w_N in
    const_num
  | Add e1 e2 =>
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d op := SStr "+" in
    let/d args := SPair v1 v2 in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | Sub e1 e2 =>
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d op := SStr "-" in
    let/d args := SPair v1 v2 in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | Div e1 e2 =>
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d op := SStr "div" in
    let/d args := SPair v1 v2 in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | Read e1 e2 =>
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d op := SStr "read" in
    let/d args := SPair v1 v2 in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
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
    let/d op := SStr cmp_str in
    let/d v1 := exp2s e1 in
    let/d v2 := exp2s e2 in
    let/d args := SPair v1 v2 in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | And t1 t2 =>
    let/d v1 := test2s_imp t1 in
    let/d v2 := test2s_imp t2 in
    let/d op := SStr "and" in
    let/d args := SPair v1 v2 in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | Or t1 t2 =>
    let/d v1 := test2s_imp t1 in
    let/d v2 := test2s_imp t2 in
    let/d op := SStr "or" in
    let/d args := SPair v1 v2 in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | Not t' =>
    let/d v := test2s_imp t' in
    let/d op := SStr "not" in
    let/d res := SPair op v in
    let/d resb := SBlock res in
    resb
  end.

Fixpoint names2s_imp (ns: list name): sexpr :=
  match ns with
  | [] =>
    let/d res := SEmpty in
    res
  | n :: ns' =>
    let/d v := SStr (name2str n) in
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
    let/d name_v := SStr (name2str n) in
    let/d exp_v := exp2s e in
    let/d op := SStr "assign" in
    let/d args := SPair name_v exp_v in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | Update a e e' =>
    let/d addr_v := exp2s a in
    let/d idx_v := exp2s e in
    let/d val_v := exp2s e' in
    let/d op := SStr "update" in
    let/d args1 := SPair addr_v idx_v in
    let/d args := SPair args1 val_v in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | If t c1 c2 =>
    let/d test_v := test2s_imp t in
    let/d cmd1_v := cmd2s_imp c1 in
    let/d cmd2_v := cmd2s_imp c2 in
    let/d op := SStr "if" in
    let/d args1 := SPair test_v cmd1_v in
    let/d args := SPair args1 cmd2_v in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | While t c' =>
    let/d test_v := test2s_imp t in
    let/d cmd_v := cmd2s_imp c' in
    let/d op := SStr "while" in
    let/d args := SPair test_v cmd_v in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | Call n f es =>
    let/d name_v := SStr (name2str n) in
    let/d func_v := SStr (name2str f) in
    let/d args_vs := exps2s es in
    let/d op := SStr "call" in
    let/d args1 := SPair name_v func_v in
    let/d args := SPair args1 args_vs in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | Return e =>
    let/d exp_v := exp2s e in
    let/d op := SStr "return" in
    let/d res := SPair op exp_v in
    let/d resb := SBlock res in
    resb
  | Alloc n e =>
    let/d name_v := SStr (name2str n) in
    let/d size_v := exp2s e in
    let/d op := SStr "alloc" in
    let/d args := SPair name_v size_v in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
  | GetChar n =>
    let/d name_v := SStr (name2str n) in
    let/d op := SStr "getchar" in
    let/d res := SPair op name_v in
    let/d resb := SBlock res in
    resb
  | PutChar e =>
    let/d char_v := exp2s e in
    let/d op := SStr "putchar" in
    let/d res := SPair op char_v in
    let/d resb := SBlock res in
    resb
  | Abort =>
    let/d res := SStr "abort" in
    let/d resb := SBlock res in
    resb
  end.

Definition func2s (f: func): sexpr :=
  match f with
  | Func n params body =>
    let/d name_v := SStr (name2str n) in
    let/d params_vs := names2s params in
    let/d body_v := cmd2s_imp body in
    let/d body_vb := SBlock body_v in
    let/d op := SStr "defun" in
    let/d params_body := SPair params_vs body_vb in
    let/d args := SPair name_v params_body in
    let/d res := SPair op args in
    let/d resb := SBlock res in
    resb
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
