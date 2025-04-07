Require Import Coq.Lists.List.
Import ListNotations.

Notation name := nat (only parsing).

Inductive op : Type :=
| Add
| Sub
| Div
| Cons
| Head
| Tail
| Read
| Write.

Inductive test : Type :=
| Less
| Equal.

Inductive exp : Type :=
| Const (n : nat)                                (* constant number            *)
| Var (n : name)                                 (* local variable             *)
| Op (o : op) (args : list exp)                  (* primitive operations       *)
| If (t : test) (conds : list exp) (e1 e2 : exp) (* if test .. then .. else .. *)
| Let (n : name) (e1 e2 : exp)                   (* let name = .. in ..        *)
| Call (f : name) (args : list exp).             (* call a function            *)

Fixpoint exp_ind_str (P : exp -> Prop)
  (HConst : forall n : nat, P (Const n))
  (HVar : forall n : name, P (Var n))
  (HOp : forall (o : op) (args : list exp), Forall P args -> P (Op o args))
  (HIf : forall (t : test) (conds : list exp) (e1 e2 : exp),
      Forall P conds -> P e1 -> P e2 -> P (If t conds e1 e2))
  (HLet : forall (n : name) (e1 e2 : exp), P e1 -> P e2 -> P (Let n e1 e2))
  (HCall : forall (f : name) (args : list exp), Forall P args -> P (Call f args))
  (e : exp) : P e :=
  match e as e0 return P e0 with
  | Const n =>
    HConst n
  | Var n =>
    HVar n
  | Op o args =>
    HOp o args ((fix list_exp_ind (l : list exp) : Forall P l :=
                  match l with
                  | [] => Forall_nil P
                  | e :: l' => Forall_cons e (exp_ind_str P HConst HVar HOp HIf HLet HCall e)
                                      (list_exp_ind l')
                  end) args)
  | If t conds e1 e2 =>
    HIf t conds e1 e2 ((fix list_exp_ind (l : list exp) : Forall P l :=
                          match l with
                          | [] => Forall_nil P
                          | e :: l' => Forall_cons e (exp_ind_str P HConst HVar HOp HIf HLet HCall e)
                                                (list_exp_ind l')
                          end) conds) (exp_ind_str P HConst HVar HOp HIf HLet HCall e1)
                          (exp_ind_str P HConst HVar HOp HIf HLet HCall e2)
  | Let n e1 e2 =>
    HLet n e1 e2 (exp_ind_str P HConst HVar HOp HIf HLet HCall e1)
                 (exp_ind_str P HConst HVar HOp HIf HLet HCall e2)
  | Call f args =>
    HCall f args ((fix list_exp_ind (l : list exp) : Forall P l :=
                    match l with
                    | [] => Forall_nil P
                    | e :: l' => Forall_cons e (exp_ind_str P HConst HVar HOp HIf HLet HCall e)
                                          (list_exp_ind l')
                    end) args)
  end.

(* Not decreasing *)
Fail Fixpoint exp_ind_list (P : list exp -> Prop)
  (HNil : P [])
  (HCons : forall e es, P [e] -> P es -> P (e :: es))
  (HConst : forall n : nat, P [Const n])
  (HVar : forall n : name, P [Var n])
  (HOp : forall (o : op) (args : list exp), P args -> P [Op o args])
  (HIf : forall (t : test) (conds : list exp) (e1 e2 : exp),
      P conds -> P [e1] -> P [e2] -> P [If t conds e1 e2])
  (HLet : forall (n : name) (e1 e2 : exp), P [e1] -> P [e2] -> P [Let n e1 e2])
  (HCall : forall (f : name) (args : list exp), P args -> P [Call f args])
  (es : list exp) : P es :=
  match es with
  | [] => HNil
  | [Const n] => HConst n
  | [Var n] => HVar n
  | [Op o args] =>
    HOp o args (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall args)
  | [If t conds e1 e2] =>
    HIf t conds e1 e2 (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall conds)
                      (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall [e1])
                      (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall [e2])
  | [Let n e1 e2] =>
    HLet n e1 e2 (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall [e1])
                 (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall [e2])
  | [Call f args] =>
    HCall f args (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall args)
  | e :: es' =>
    HCons e es'
           (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall [e])
           (exp_ind_list P HNil HCons HConst HVar HOp HIf HLet HCall es')
  end.

Inductive dec : Type :=
| Defun (n : name) (params : list name) (body : exp). (* func name, formal params, body *)

(* a complete program is a list of function declarations followed by *)
(* an expression to evaluate *)
Inductive prog : Type :=
| Program (defs : list dec) (main : exp).

Definition get_main (p : prog) : exp :=
  match p with
  | Program _ main => main
  end.

Definition get_defs (p : prog) : list dec :=
  match p with
  | Program defs _ => defs
  end.
