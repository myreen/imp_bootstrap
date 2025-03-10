Require Import Coq.Lists.List.
Require Import Coq.Strings.Ascii.
Import ListNotations.
Require Import impboot.functional.FunSyntax.
Require Import impboot.functional.FunValues.
Import Nat.

Module FunSemantics.

Notation num := nat.
Notation name := nat.
Notation char := ascii.
Notation llist := list.

Inductive err : Type :=
  | TimeOut
  | Crash.

Inductive result {A : Type} : Type :=
  | Res (v : A)
  | Err (e : err).
Arguments result : clear implicits.

Record state := mkState {
  funs : list FunSyntax.dec;
  clock : num;
  input : llist char;
  output : list char
}.

Definition set_input (s : state) (inp : llist char) : state :=
  {| funs := s.(funs);
     clock := s.(clock);
     input := inp;
     output := s.(output) |}.

Definition set_output (s : state) (out : list char) : state :=
  {| funs := s.(funs);
     clock := s.(clock);
     input := s.(input);
     output := out |}.

Definition return_ {A} (v : A) (s : state) : result A * state :=
  (Res v, s).

Definition fail {A} (s : state) : result A * state :=
  (Err Crash, s).

Definition next (s : state) : Value * state :=
  match s.(input) with
  | [] => (Num (2 ^ 32 - 1), s) (* EOF *)
  | c :: cs => (Num (nat_of_ascii c), set_input s cs)
  end.

Definition eval_op (f : FunSyntax.op) (vs : list Value) (s : state) : result Value * state :=
  match f, vs with
  | FunSyntax.Add, [Num n1; Num n2] => return_ (Num (n1 + n2)) s
  | FunSyntax.Sub, [Num n1; Num n2] => return_ (Num (n1 - n2)) s
  | FunSyntax.Div, [Num n1; Num n2] =>
    if n2 =? 0 then fail s else return_ (Num (n1 / n2)) s
  | FunSyntax.Cons, [x; y] => return_ (Pair x y) s
  | FunSyntax.Head, [Pair x y] => return_ x s
  | FunSyntax.Tail, [Pair x y] => return_ y s
  | FunSyntax.Read, [] =>
      let (v, s') := next s in
      return_ v s' (* TODO(kπ) LTL? – (s with input := case LTL s.input of NONE => s.input | SOME t => t) *)
  | FunSyntax.Write, [Num n] =>
      if n <? 256 then return_ (Num 0) (set_output s (s.(output) ++ [ascii_of_nat n]))
      else fail s
  | _, _ => fail s
  end.

Definition take_branch (test : FunSyntax.test) (vs : list Value) (s : state) : result bool * state :=
  match test, vs with
  | FunSyntax.Equal, [Pair x y; Num 0] => return_ false s
  | FunSyntax.Equal, [Num m; Num n] => return_ (m =? n) s
  | FunSyntax.Less, [Num m; Num n] => return_ (m <? n) s
  | _, _ => fail s
  end.

Definition empty_env : name -> option Value := fun _ => None.

Fixpoint make_env (keys : list name) (values : list Value) (acc : name -> option Value) : name -> option Value :=
  match keys, values with
  | [], [] => acc
  | k :: ks, v :: vs => make_env ks vs (fun x => if x =? k then Some v else acc x)
  | _, _ => acc
  end.

Fixpoint lookup_fun (n : name) (fs : list FunSyntax.dec) : option (list name * FunSyntax.exp) :=
  match fs with
  | [] => None
  | FunSyntax.Defun k ps body :: rest => if k =? n then Some (ps, body) else lookup_fun n rest
  end.

Definition env_and_body (n : name) (args : list Value) (s : state) : option ((name -> option Value) * FunSyntax.exp) :=
  match lookup_fun n s.(funs) with
  | None => None
  | Some (params, body) => if length params =? length args then Some (make_env params args empty_env, body) else None
  end.

Definition init_state (inp : llist char) (funs : list FunSyntax.dec) : state :=
  {| funs := funs; clock := 0; input := inp; output := [] |}.

(* TODO(kπ) Double check this *)
Inductive Eval : (name -> option Value) -> list FunSyntax.exp -> state -> list Value -> state -> Prop :=
  | Eval_Const : forall env n s,
      Eval env [FunSyntax.Const n] s [Num n] s
  | Eval_Var : forall env n v s,
      env n = Some v -> Eval env [FunSyntax.Var n] s [v] s
  | Eval_Nil : forall env s,
      Eval env [] s [] s
  | Eval_Cons : forall env x v y xs vs s1 s2 s3,
      Eval env [x] s1 [v] s2 ->
      Eval env (y :: xs) s2 vs s3 ->
      Eval env (x :: y :: xs) s1 (v :: vs) s3
  | Eval_Op : forall env xs s1 vs s2 f v s3,
      Eval env xs s1 vs s2 ->
      eval_op f vs s2 = (Res v, s3) ->
      Eval env [FunSyntax.Op f xs] s1 [v] s3
  | Eval_Let : forall env x y s1 v1 s2 n s3 v2,
      Eval env [x] s1 [v1] s2 ->
      Eval (fun k => if k =? n then Some v1 else env k) [y] s2 [v2] s3 ->
      Eval env [FunSyntax.Let n x y] s1 [v2] s3
  | Eval_If : forall env xs s1 vs s2 test b y z v s3,
      Eval env xs s1 vs s2 ->
      take_branch test vs s2 = (Res b, s2) ->
      Eval env [if b then y else z] s2 [v] s3 ->
      Eval env [FunSyntax.If test xs y z] s1 [v] s3
  | Eval_Call : forall env xs s1 vs s2 fname v s3 new_env body,
      Eval env xs s1 vs s2 ->
      env_and_body fname vs s2 = Some (new_env, body) ->
      Eval new_env [body] s2 [v] s3 ->
      Eval env [FunSyntax.Call fname xs] s1 [v] s3.

Definition prog_terminates (input : llist char) (p : FunSyntax.prog) (out : list char) : Prop :=
  exists s r,
    Eval empty_env
      [get_main p]
      (init_state input (get_defs p)) r s /\
        out = s.(output).

End FunSemantics.
