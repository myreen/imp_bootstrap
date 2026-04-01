Require Import String Nat.

Open Scope nat.

Inductive natExpr: Type :=
  | NEConst (n: nat)
  | NEVar (x: string)
  | NEAdd (e1 e2: natExpr)
  | NESub (e1 e2: natExpr).

Inductive cmd: Type :=
  | WLSkip
  | WLAssign (x: string) (e: natExpr)
  | WLSeq (c1 c2: cmd)
  | WLIf (e: natExpr) (c1 c2: cmd)
  | WLWhile (e: natExpr) (body: cmd).

Definition state := string -> nat.
Inductive res: Type :=
| State (s: state)
| TimeOut.
Definition empty_state: res := State (fun _ => 0).
Definition state_add (s: res) (x: string) (v: nat): res :=
  match s with
  | TimeOut => TimeOut
  | State s => State (
    fun y => if String.eqb y x then v else s y
  )
  end.
Definition bind (s: res) (f: state -> res): res :=
  match s with
  | TimeOut => TimeOut
  | State st => f st
  end.
Notation "'let*' x := s1 'in' s2" :=
  (bind s1 (fun x => s2))
  (at level 60, right associativity).

Fixpoint eval_natExpr (s: state) (e: natExpr): nat :=
  match e with
  | NEConst n => n
  | NEVar x => s x
  | NEAdd e1 e2 => eval_natExpr s e1 + eval_natExpr s e2
  | NESub e1 e2 => eval_natExpr s e1 - eval_natExpr s e2
  end.
Definition eval_natExpr_res (r: res) (e: natExpr): nat :=
  match r with
  | TimeOut => 0
  | State s => eval_natExpr s e
  end.

Fixpoint eval_cmd (EVAL_CMD: forall (r: res) (c: cmd), res) (r: res) (c: cmd): res :=
  let eval_cmd := eval_cmd EVAL_CMD in
  match c with
  | WLSkip => r
  | WLAssign x e =>
    state_add r x (eval_natExpr_res r e)
  | WLSeq c1 c2 =>
    let* r1 := eval_cmd r c1 in
    eval_cmd (State r1) c2
  | WLIf e c1 c2 =>
    if eval_natExpr_res r e =? 0 then
      eval_cmd r c2
    else
      eval_cmd r c1
  | WLWhile e body =>
    if eval_natExpr_res r e =? 0 then
      r
    else
      let* r1 := eval_cmd r body in
      EVAL_CMD (State r1) (WLWhile e body)
  end.

Fixpoint EVAL_CMD (fuel: nat) (r: res) (c: cmd): res :=
  match fuel with
  | 0 => TimeOut
  | S fuel' =>
    eval_cmd (EVAL_CMD fuel') r c
  end.

Example test_cmd :=
  WLSeq
    (WLAssign "x" (NEConst 1))
    (WLWhile (NEVar "x")
      (WLSeq
        (WLAssign "y" (NEVar "x"))
        (WLAssign "x" (NESub (NEVar "x") (NEConst (1)))))).

Eval lazy in (
  match (eval_cmd (EVAL_CMD 10) empty_state test_cmd) with
  | TimeOut => 0
  | State s => s "y"%string
  end
).
