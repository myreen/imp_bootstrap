Require Import Coq.Lists.List.
Require Import Coq.Strings.Ascii.
Import ListNotations.
Require Import impboot.functional.FunSyntax.
Import Nat.
Require Import impboot.utils.Llist.

Notation name := nat.

Inductive Value :=
  | Pair (v1 v2 : Value)
  | Num (n : nat).

Inductive err : Type :=
  | TimeOut
  | Crash.

Inductive result {A : Type} : Type :=
  | Res (v : A)
  | Err (e : err).
Arguments result : clear implicits.

Record state := mkState {
  funs : list FunSyntax.dec;
  clock : nat;
  input : llist ascii;
  output : list ascii
}.

Definition set_input (s : state) (inp : llist ascii) : state :=
  {| funs := s.(funs);
     clock := s.(clock);
     input := inp;
     output := s.(output) |}.

Definition set_output (s : state) (out : list ascii) : state :=
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
  | lnil => (Num (2 ^ 32 - 1), s) (* EOF *)
  | lcons c cs => (Num (nat_of_ascii c), set_input s cs)
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
      return_ v (set_input s' (ltail s'.(input)))
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

Notation env := (name -> option Value).

Definition empty_env : env := fun _ => None.

Fixpoint make_env (keys : list name) (values : list Value) (acc : env) : env :=
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

Definition env_and_body (n : name) (args : list Value) (s : state) : option (env * FunSyntax.exp) :=
  match lookup_fun n s.(funs) with
  | None => None
  | Some (params, body) => if length params =? length args then Some (make_env params args empty_env, body) else None
  end.

Definition init_state (inp : llist ascii) (funs : list FunSyntax.dec) : state :=
  {| funs := funs; clock := 0; input := inp; output := [] |}.

Reserved Notation "env '|-' es '/' s1 '-->' vs '/' s2" (at level 40, es at next level, s1 at next level, vs at next level, s2 at next level).

(* TODO(ask Magnus) why he likes using `list of exp`, instead of exp *)
Inductive Eval : env -> list FunSyntax.exp -> state -> list Value -> state -> Prop :=
  | Eval_Nil : forall env s,
    env |- [] / s --> [] / s
  | Eval_Cons : forall env exp1 v exp2 exps vs s1 s2 s3,
    forall
      (EVAL_HEAD : env |- [exp1] / s1 --> [v] / s2)
      (EVAL_TAIL : env |- (exp2 :: exps) / s2 --> vs / s3),
    env |- (exp1 :: exp2 :: exps) / s1 --> (v :: vs) / s3
  | Eval_Const : forall env n s,
    env |- [FunSyntax.Const n] / s --> [Num n] / s
  | Eval_Var : forall env n v s,
    env n = Some v ->
    env |- [FunSyntax.Var n] / s --> [v] / s
  | Eval_Op : forall env exps s1 vs s2 op v s3,
    forall
      (EVAL_ARGS : env |- exps / s1 --> vs / s2)
      (EVAL_OP : eval_op op vs s2 = (Res v, s3)),
    env |- [FunSyntax.Op op exps] / s1 --> [v] / s3
  | Eval_Let : forall env exp1 exp2 s1 v1 s2 n s3 v2,
    forall
      (EVAL_RHS : env |- [exp1] / s1 --> [v1] / s2)
      (EVAL_RES : (fun k => if k =? n then Some v1 else env k) |- [exp2] / s2 --> [v2] / s3),
    env |- [FunSyntax.Let n exp1 exp2] / s1 --> [v2] / s3
  | Eval_If : forall env exps s1 vs s2 test b expt expf v s3,
    forall
      (EVAL_COND : env |- exps / s1 --> vs / s2)
      (TAKE_BRANCH : take_branch test vs s2 = (Res b, s2))
      (EVAL_RES : env |- [if b then expt else expf] / s2 --> [v] / s3),
    env |- [FunSyntax.If test exps expt expf] / s1 --> [v] / s3
  | Eval_Call : forall env exps s1 vs s2 fname v s3 new_env body,
    forall
      (EVAL_ARGS : env |- exps / s1 --> vs / s2)
      (ENV_BODY : env_and_body fname vs s2 = Some (new_env, body))
      (EVAL_BODY : new_env |- [body] / s2 --> [v] / s3),
    env |- [FunSyntax.Call fname exps] / s1 --> [v] / s3
where "env '|-' es '/' s1 '-->' vs '/' s2" := (Eval env es s1 vs s2).

Definition prog_terminates (input : llist ascii) (p : FunSyntax.prog) (out : list ascii) : Prop :=
  exists s r,
    empty_env |- [get_main p] / (init_state input (get_defs p)) --> r / s /\
        out = s.(output).
