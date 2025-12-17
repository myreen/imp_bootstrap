From impboot Require Import utils.Core.
Require Import impboot.functional.FunSyntax.
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
  | v => v
  end.

Definition vtail v :=
  match v with
  | Pair x y => y
  | v => v
  end.

Definition vcons (x y : Value) : Value :=
  Pair x y.

Fixpoint vlist (ls : list Value) : Value :=
  match ls with
  | [] => Num 0
  | x :: xs => vcons x (vlist xs)
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

Definition vel0 v :=
  vhead v.

Definition vel1 v :=
  vhead (vtail v).

Definition vel2 v :=
  vel1 (vtail v).

Definition vel3 v :=
  vel2 (vtail v).

Definition N_modulo (n1 n2: N): N :=
  match n2 with
  | 0%N => 0
  | N.pos _ => n1 - n2 * (n1 / n2)
  end.

(* checks whether string (represented as num) starts with uppercase letter *)
Definition vis_upper (n: N) :=
  let n1 := N_modulo n 256 in
  if n <? 65 (* ord A = 65 *) then false else
  if n <? 91 (* ord Z = 90 *) then true else false.
