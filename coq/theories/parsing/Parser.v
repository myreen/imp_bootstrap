From impboot Require Import
  utils.Core
  utils.Llist.
Import Llist.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.functional.FunValues.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.

Require Import Patat.Patat.

Open Scope N.
Open Scope string.

(* lexing *)

Inductive token :=
  | OPEN
  | CLOSE
  | DOT
  | NUM (n: N)
  | QUOTE (s: N).

Fixpoint read_num (l h: ascii) (f x: N) (acc: N) (cs: list ascii): (N * list ascii) :=
  match cs with
  [] => (acc, [])
  | c :: cs =>
    if (andb (N_of_ascii l <=? N_of_ascii c) (N_of_ascii c <=? N_of_ascii h))%N then
      read_num l h f x (f * acc + (N_of_ascii c - x)) cs
    else (acc, c::cs)
  end.

Fixpoint end_line (cs: list ascii) :=
  match cs with
  | [] => []
  | c :: cs =>
    (*             vvvvv \n *)
    if Ascii.eqb c "010" then cs else end_line cs
  end.

Fixpoint lex q (cs: list ascii) (acc: list token) (fuel: nat): option (list token) :=
  (* TODO: change the order of matches? *)
  match cs with
  | [] => Some acc
  | c :: cs =>
    match fuel with
    | 0%nat => None
    | S fuel => 
      if List.existsb (fun c1 => Ascii.eqb c c1) (list_ascii_of_string " \t\n") then
        lex NUM cs acc fuel else
      if Ascii.eqb c "#" then lex NUM (end_line cs) acc fuel else
      if Ascii.eqb c "." then lex NUM cs (DOT :: acc) fuel else
      if Ascii.eqb c "(" then lex NUM cs (OPEN :: acc) fuel else
      if Ascii.eqb c ")" then lex NUM cs (CLOSE :: acc) fuel else
      if Ascii.eqb c "'" then lex QUOTE cs acc fuel else
        let (n, rest) := read_num "0" "9" 10 (N_of_ascii "0") 0 (c :: cs) in
        if negb (Nat.eqb (List.length rest) (List.length (c :: cs))) then
          lex NUM rest (q n :: acc) fuel
        else
          let (n, rest) := read_num "*" "z" 256 0 0 (c :: cs) in
          if negb (Nat.eqb (List.length rest) (List.length (c :: cs))) then
            lex NUM rest (q n :: acc) fuel
          else lex NUM cs acc fuel
    end
  end.

Ltac cleanup :=
  repeat match goal with
  | H: _ /\ _ |- _ => destruct H; clear H
  | H: (_, _) = (_, _) |- _ => inversion H; clear H; subst
  end.

Theorem read_num_length: ∀l h xs n ys f acc x,
  read_num l h f x acc xs = (n, ys) ->
    List.length ys ≤ List.length xs ∧ (xs ≠ ys -> List.length ys < List.length xs)%nat.
Proof.
  induction xs; intros; simpl in *; cleanup; simpl.
  1: split; eauto; intros; congruence.
  destruct andb eqn:?; rewrite ?andb_true_iff, ?andb_false_iff, ?N.leb_le, ?N.leb_gt in *; cleanup; simpl in *.
  1: {
    pat `read_num _ _ _ _ _ _ = _` at rename pat into Hread_num.
    pat `forall n ys f acc x, _` at eapply pat in Hread_num.
    split; [lia|].
    intros; lia.
  }
  split; [lia|].
  intros; congruence.
Qed.

Theorem end_line_length: ∀cs,
  (List.length (end_line cs) <= List.length cs)%nat.
Proof.
  induction cs; simpl; [lia|].
  destruct (_ =? _)%char eqn:?; lia.
Qed.

Theorem lex_terminates: forall fuel q cs acc,
  (List.length cs <= fuel)%nat -> lex q cs acc fuel <> None.
Proof.
  Opaque Ascii.eqb.
  induction fuel; intros; simpl.
  1: inversion H; simpl; destruct cs eqn:?; simpl in *; try congruence.
  destruct cs eqn:?; try congruence; simpl in *.
  repeat match goal with
  | |- (if ?c then _ else _) <> _ => destruct c eqn:?
  | |- lex _ _ _ _ <> _ =>
    eapply IHfuel
  | |- (let (_, _) := if ?c then _ else _ in _) <> _ =>
    destruct c eqn:?
  | |- (let (_, _) := read_num _ _ _ _ _ cs in _) <> _ =>
    destruct read_num eqn:?
  | H: _ = _ :: ?l |- (let (_, _) := read_num ?a1 ?a2 ?a3 ?a4 ?a5 ?l in _) <> _ =>
    destruct (read_num a1 a2 a3 a4 a5 l) eqn:?
  | |- (List.length (end_line _) <= _)%nat =>
    eapply Nat.le_trans; [eapply end_line_length|]; lia
  | H: (S _ <= S _)%nat |- _ =>
    eapply le_S_n in H
  | H: cs = ?h :: ?t |- (List.length (?h :: ?t) <= _)%nat =>
    rewrite negb_true_iff, Nat.eqb_neq in *; simpl in *; congruence
  | H: read_num _ _ _ _ _ ?t = (_, _) |- _ =>
    eapply read_num_length in H
  | _ => lia
  end.
Qed.

Definition lexer (input: string): option (list token) :=
  let/d in_list := list_ascii_of_string input in
  lex NUM in_list [] (List.length in_list).

Theorem lexer_terminates: forall (inp: string),
  lexer inp <> None.
Proof.
  intros; unfold lexer, dlet.
  eapply lex_terminates.
  eapply Nat.le_refl.
Qed.

(* parsing *)

Definition quote n :=
  FunValues.vlist [Num (name_enc "'"); Num n].

Fixpoint parse (ts: list token) x s :=
  match ts with
  | [] => x
  | (CLOSE :: rest) => parse rest (Num 0) (x::s)
  | (OPEN :: rest) =>
    match s with
    | [] => parse rest x s
    | (y::ys) => parse rest (Pair x y) ys
    end
  | (NUM n :: rest) => parse rest (Pair (Num n) x) s
  | (QUOTE n :: rest) => parse rest (Pair (quote n) x) s
  | (DOT :: rest) => parse rest (FunValues.vhead x) s
end.

(* converting from v to prog *)

Fixpoint v2list v :=
  match v with
  | Num _ => []
  | Pair v1 v2 =>
    v1 :: v2list v2
  end.

Fixpoint pat_lets x v rhs :=
  match v with
  | Num _ => rhs
  | Pair v1 v2 =>
    let var := vgetNum v1 in
      FunSyntax.Let var (FunSyntax.Op FunSyntax.Head [x])
        (pat_lets (FunSyntax.Op FunSyntax.Tail [x]) v2 rhs)
  end.

Definition num2exp n :=
  if vis_upper n then ImpSyntax.Const (word.of_Z (Z.of_N n)) else Var n.

Fixpoint v2exp (v: Value): ImpSyntax.exp :=
  match v with
  | Num n => num2exp n
  | Pair v0 v1 =>
    let n := vgetNum v0 in (* this can fail? *)
    if N.eqb n (name_enc "'") then Const (word.of_Z (Z.of_N (vgetNum v1))) else
    if N.eqb n (name_enc "var") then Var (vgetNum v1) else
    match v1 with
    | Num _ => Var (vgetNum v) (* fail? *)
    | Pair v1 v2 =>
      if N.eqb n (name_enc "+") then Add (v2exp v1) (v2exp v2) else
      if N.eqb n (name_enc "-") then Sub (v2exp v1) (v2exp v2) else
      if N.eqb n (name_enc "div") then Div (v2exp v1) (v2exp v2) else
      if N.eqb n (name_enc "read") then Read (v2exp v1) (v2exp v2) else
      Var (vgetNum (vel0 v)) (* fail? *)
    end
  end.

Fixpoint v2exps (v: Value): list ImpSyntax.exp :=
  match v with
  | Num _ => []
  | Pair v1 v2 =>
    v2exp v1 :: v2exps v2
  end.

Definition v2cmp (v: Value): ImpSyntax.cmp :=
  if N.eqb (vgetNum v) (name_enc "<") then Less else
  if N.eqb (vgetNum v) (name_enc "=") then Equal else
  Less. (* fail? *)

Fixpoint v2test (v: Value): ImpSyntax.test :=
  match v with
  | Num _ => Test Less (Const (word.of_Z 0)) (Const (word.of_Z 0)) (* fail? *)
  | Pair v0 v1 =>
    let n := vgetNum v0 in (* this can fail? *)
    if N.eqb n (name_enc "not") then Not (v2test v1) else
    match v1 with
    | Num _ => Test Less (Const (word.of_Z 0)) (Const (word.of_Z 0)) (* fail? *)
    | Pair v1 v2 =>
      if N.eqb n (name_enc "and") then And (v2test v1) (v2test v2) else
      if N.eqb n (name_enc "or") then Or (v2test v1) (v2test v2) else
      Test (v2cmp v0) (v2exp v1) (v2exp v2)
    end
  end.

(* TODO: can I use v2list here? *)
Fixpoint v2cmd (v: Value): ImpSyntax.cmd :=
  match v with
  | Num _ => Skip
  | Pair v0 v1 =>
    match v0 with
    | Pair _ _ =>
      Seq (v2cmd v0) (v2cmd v1)
    | Num _ =>
      let n := vgetNum v0 in
      if N.eqb n (name_enc "abort") then Abort else
      if N.eqb n (name_enc "return") then Return (v2exp v1) else
      if N.eqb n (name_enc "getchar") then GetChar (vgetNum v1) else
      if N.eqb n (name_enc "putchar") then PutChar (v2exp v1) else
      match v1 with
      | Num _ => Skip (* fail? *)
      | Pair v1 v2 =>
        if N.eqb n (name_enc "assign") then Assign (vgetNum v1) (v2exp v2) else
        if N.eqb n (name_enc "while") then While (v2test v1) (v2cmd v2) else
        if N.eqb n (name_enc "alloc") then Alloc (vgetNum v1) (v2exp v2) else
        match v2 with
        | Num _ => Skip (* fail? *)
        | Pair v2 v3 =>
          if N.eqb n (name_enc "update") then Update (v2exp v1) (v2exp v2) (v2exp v3) else
          if N.eqb n (name_enc "if") then If (v2test v1) (v2cmd v2) (v2cmd v3) else
          Call (vgetNum v1) (vgetNum v2) (v2exps v3)
        end
      end
    end
  end.

Fixpoint vs2args (vs: list Value) :=
  match vs with
  | [] => []
  | v :: vs =>
    match v with
    | Num _ => [] (* fail? *)
    | Pair v0 _ =>
      vgetNum v0 :: vs2args vs
    end
  end.

Definition v2dec (v: Value) :=
  match v with
  | Num _ => ImpSyntax.Func (0%N) [] Skip (* fail? *)
  | Pair v0 v1 =>
    match v1 with
    | Num _ => ImpSyntax.Func (0%N) [] Skip (* fail? *)
    | Pair v1 v2 =>
      match v2 with
      | Num _ => ImpSyntax.Func (0%N) [] Skip (* fail? *)
      | Pair v2 v3 =>
        match v3 with
        | Num _ => ImpSyntax.Func (0%N) [] Skip (* fail? *)
        | Pair v3 _ =>
          ImpSyntax.Func (vgetNum v1)
            (vs2args (v2list v2))
            (v2cmd v3)
        end
      end
    end
  end.

Fixpoint vdecs (vs: list Value) :=
  match vs with
  | [] => []
  | v :: vs =>
    v2dec v :: vdecs vs
  end.

Definition vs2prog (vs: list Value) :=
  let ds := vdecs vs in
  ImpSyntax.Program ds.

(* entire parser *)

Definition parser tokens :=
  vs2prog (v2list (parse tokens (Num 0) [])).
