From impboot Require Import utils.Core.
Require Import impboot.functional.FunSyntax.
Require Import impboot.commons.CompilerUtils.
Require Import FunInd.
From coqutil Require Import dlet.

Open Scope N.

Inductive Value :=
  | Pair (v1 v2: Value)
  | Num (n: N).

Class Refinable (A: Type) :=
  { encode : A -> Value }.

Global Instance Refinable_nat: Refinable nat :=
  { encode n := Num (N.of_nat n) }.

Global Instance Refinable_N: Refinable N :=
  { encode := Num }.

Fixpoint name_enc_l (s: list ascii): N :=
  match s with
  | [] => 0%N
  | c :: s => (N_of_ascii c) * N.pow 256 (N.of_nat (List.length s)) + name_enc_l s
  end.

Definition name_enc (s: string): N :=
  name_enc_l (list_ascii_of_string s).

Definition value_name (s: string) : Value :=
  Num (name_enc s).

Definition value_list_of_values (xs : list Value) : Value :=
  fold_right (fun x acc => Pair x acc) (Num 0) xs.

Global Instance Refinable_list {A: Type} `{Refinable A}: Refinable (list A) :=
  { encode l := value_list_of_values (List.map encode l) }.

Definition enc_char(c: ascii): N :=
  N_of_ascii c.

Global Instance Refinable_char : Refinable ascii :=
  { encode c := Num (enc_char c) }.

Global Instance Refinable_string: Refinable string :=
  { encode s := encode (list_ascii_of_string s) }.

Global Instance Refinable_bool : Refinable bool :=
  { encode b := if b then Num 1 else Num 0 }.

Global Instance Refinable_pair {A B : Type} `{Refinable A} `{Refinable B} : Refinable (A * B) :=
  { encode p := Pair (encode (fst p)) (encode (snd p)) }.

Global Instance Refinable_option {A : Type} `{Refinable A} : Refinable (option A) :=
  { encode o :=
    match o with
    | None => encode []
    | Some x => encode [x]
    end }.

Global Instance Refinable_Prop {A: Prop}: Refinable A :=
  { encode _ := Num 0 }.

(* helpers *)

Definition vhead v :=
  match v with
  | Pair x y => x
  | Num n =>
    let/d res := Num n in
    res
  end.

Definition vtail v :=
  match v with
  | Pair x y => y
  | Num n =>
    let/d res := Num n in
    res
  end.

Definition vcons (x y : Value) : Value :=
  let/d res := Pair x y in
  res.

Function vlist (ls : list Value): Value :=
  match ls with
  | [] =>
    let/d res := Num 0 in
    res
  | x :: xs =>
    let/d t := vlist xs in
    let/d res := vcons x t in
    res
  end.

Definition vpair (f g: Value -> Value) (p: Value * Value) :=
  match p with
  | (x, y) => Pair (f x) (g y)
  end.

Definition voption f (o: option Value) :=
  match o with
  | None => vlist []
  | Some x => vlist [f x]
  end.

Definition vchar c :=
  Num (N_of_ascii c).

Definition visNum (v: Value) :=
  match v with
  | Num _ => true
  | _ => false
  end.

Definition vgetNum (v: Value) :=
  match v with
  | Num n => n
  | _ => 0
  end.

Definition visPair (v: Value) :=
  match v with
  | Pair _ _ => true
  | _ => false
  end.

Definition vel0 v :=
  let/d res := vhead v in
  res.

Definition vel1 v :=
  let/d t := vtail v in
  let/d res := vhead t in
  res.

Definition vel2 v :=
  let/d t := vtail v in
  let/d res := vel1 t in
  res.

Definition vel3 v :=
  let/d t := vtail v in
  let/d res := vel2 t in
  res.

(* checks whether string (represented as num) starts with uppercase letter *)
Fixpoint vis_upper_f (n: N) (fuel: nat): option bool :=
  if (n <? 256)%N then
    if n <? 65 (* ord A = 65 *) then
      let/d f := false in
      let/d res := Some f in
      res
    else if n <? 91 (* ord Z = 90 *) then
      let/d t := true in
      let/d res := Some t in
      res
    else
      let/d f := false in
      let/d res := Some f in
      res
  else
    match fuel with
    | O =>
      let/d none := None in
      none
    | S fuel' =>
      let/d n1 := (n / 256) in
      let/d res := vis_upper_f n1 fuel' in
      res
    end.

Theorem vis_upper_f_terminates: forall (fuel: nat) (n: N),
  (n <= (N.of_nat fuel))%N -> vis_upper_f n fuel <> None.
Proof.
  Opaque N.div.
  induction fuel; intros; simpl; unfold dlet; simpl.
  1: assert (N.of_nat 0 = 0%N) as Htmp by lia; rewrite Htmp in *; clear Htmp; destruct n; try lia; simpl; congruence.
  destruct (_ <? 256)%N eqn:?; rewrite ?N.ltb_lt, ?N.ltb_ge in *; subst.
  1: destruct (n <? 65)%N eqn:?; destruct (n <? 91)%N; congruence.
  eapply IHfuel.
  assert (n / 256 <= N.of_nat (S fuel) / 256)%N.
  1: eapply N.Div0.div_le_mono; try lia.
  specialize N.Div0.div_lt_upper_bound with (a := n) (q := N.of_nat fuel) (b := 256) as ?.
  assert (n / 256 < N.of_nat fuel)%N; lia.
Qed.

Definition vis_upper (n: N): bool :=
  let/d r := vis_upper_f n (N.to_nat n) in
  match r return bool with
  | Some b => b
  | None =>
    let/d res := false in
    res
  end.
