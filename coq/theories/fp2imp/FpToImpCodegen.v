From impboot Require Import functional.FunSyntax.
From impboot Require Import imperative.ImpSyntax.
From Stdlib Require Import NArith.
From Stdlib Require Import ZArith.
From Stdlib Require Import Lists.List.
From Stdlib Require Import Bool.
From Stdlib Require Import String.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
Require Import coqutil.Datatypes.List.
Import ListNotations.

(* definition of a very partial compilation from functional to imperative source *)

Open Scope string_scope.

Definition option_bind {A B: Type} (f: A -> option B) (ma: option A): option B :=
  match ma with
  | None => None
  | Some a => f a
  end.

Notation "'let/o' v := r1 'in' r2" :=
  (option_bind (fun v => r2) r1)
  (at level 200, right associativity).

Fixpoint to_exp (e: FunSyntax.exp): option ImpSyntax.exp :=
  match e with
  | FunSyntax.Var v => Some (ImpSyntax.Var (N.to_nat v))
  | FunSyntax.Const n =>
      if (n <? 2^64)%N then
        Some (ImpSyntax.Const (word.of_Z (Z.of_N n)))
      else None
  | FunSyntax.Op FunSyntax.Head [x] =>
      option_map (fun e' => ImpSyntax.Read e' (ImpSyntax.Const (word.of_Z 0))) (to_exp x)
  | FunSyntax.Op FunSyntax.Tail [x] =>
      option_map (fun e' => ImpSyntax.Read e' (ImpSyntax.Const (word.of_Z 8))) (to_exp x)
  | _ => None
  end.

Fixpoint to_exps (es: list FunSyntax.exp): option (list ImpSyntax.exp) :=
  match es with
  | [] => Some []
  | x :: xs =>
    let/o y := to_exp x in
    let/o ys := to_exps xs in
    Some (y :: ys)
  end.

Definition to_test (t: FunSyntax.test): ImpSyntax.cmp :=
  match t with
  | FunSyntax.Equal => ImpSyntax.Equal
  | FunSyntax.Less => ImpSyntax.Less
  end.

Definition to_guard (t: FunSyntax.test) (es: list FunSyntax.exp): option ImpSyntax.test :=
  match to_exps es with
  | Some [x1; x2] => Some (ImpSyntax.Test (to_test t) x1 x2)
  | _ => None
  end.

Definition dest_Cons (e: FunSyntax.exp): option (ImpSyntax.exp * FunSyntax.exp) :=
  match e with
  | FunSyntax.Op FunSyntax.Cons [e1; e2] =>
      option_map (fun e' => (e', e2)) (to_exp e1)
  | _ => None
  end.

(* TODO: is this just an optimization? *)
Definition to_cons (v: name) (x: FunSyntax.exp): option ImpSyntax.cmd :=
  match dest_Cons x with
  | None => None
  | Some (e1, x) =>
      match dest_Cons x with
      | None =>
          option_map (fun e2 => ImpSyntax.Call v (name_of_string "cons") [e1; e2]) (to_exp x)
      | Some (e2, x) =>
          match dest_Cons x with
          | None =>
              option_map (fun e3 => ImpSyntax.Call v (name_of_string "cons3") [e1; e2; e3]) (to_exp x)
          | Some (e3, x) =>
              match dest_Cons x with
              | None =>
                  option_map (fun e4 => ImpSyntax.Call v (name_of_string "cons4") [e1; e2; e3; e4]) (to_exp x)
              | Some (e4, x) =>
                  option_map (fun e5 => ImpSyntax.Call v (name_of_string "cons5") [e1; e2; e3; e4; e5]) (to_exp x)
              end
          end
      end
  end.

Definition to_assign (v: name) (x: FunSyntax.exp): option ImpSyntax.cmd :=
  match to_exp x with
  | Some i => Some (ImpSyntax.Assign v i)
  | None =>
      match to_cons v x with
      | Some r => Some r
      | None =>
          match x with
          | FunSyntax.Call n es =>
              option_map (fun xs => ImpSyntax.Call v (N.to_nat n) xs) (to_exps es)
          | FunSyntax.Op p es =>
              match p, to_exps es with
              | FunSyntax.Add, Some [x1; x2] => 
                  Some (ImpSyntax.Call v (name_of_string "add") [x1; x2])
              | FunSyntax.Sub, Some [x1; x2] => 
                  Some (ImpSyntax.Call v (name_of_string "sub") [x1; x2])
              | FunSyntax.Div, Some [x1; x2] => 
                  Some (ImpSyntax.Assign v (ImpSyntax.Div x1 x2))
              | FunSyntax.Read, Some [] => 
                  Some (ImpSyntax.GetChar v)
              | FunSyntax.Write, Some [x1] => 
                  Some (ImpSyntax.Seq (ImpSyntax.PutChar x1) 
                                      (ImpSyntax.Assign v (ImpSyntax.Const (word.of_Z 0))))
              | _, _ => None
              end
          | _ => None
          end
      end
  end.

Fixpoint to_cmd (e: FunSyntax.exp): option ImpSyntax.cmd :=
  match to_exp e with
  | Some i => Some (ImpSyntax.Return i)
  | None =>
      match e with
      | FunSyntax.If t es e1 e2 =>
          let/o t1 := to_guard t es in
          let/o c1 := to_cmd e1 in
          let/o c2 := to_cmd e2 in
          Some (ImpSyntax.If t1 c1 c2)
      | FunSyntax.Let v x y =>
          let/o c1 := to_assign (N.to_nat v) x in
          let/o c2 := to_cmd y in
          Some (ImpSyntax.Seq c1 c2)
      | FunSyntax.Call n es =>
          option_map (fun xs => 
            ImpSyntax.Seq 
              (ImpSyntax.Call (name_of_string "ret") (N.to_nat n) xs) 
              (ImpSyntax.Return (ImpSyntax.Var (name_of_string "ret")))
          ) (to_exps es)
      | _ => None
      end
  end.

  Fixpoint list_uniqb {A: Type} (eqb: A -> A -> bool) (l: list A): bool :=
    match l with
    | [] => true
    | x :: xs => negb (List.existsb (eqb x) xs) && list_uniqb eqb xs
    end.

Fixpoint to_funs (fs: list FunSyntax.defun): option (list ImpSyntax.func) :=
  match fs with
  | [] => Some []
  | FunSyntax.Defun n vs e :: fs =>
    if list_uniqb N.eqb vs then
      let/o cmd := to_cmd e in
      let/o funs := to_funs fs in
      Some (ImpSyntax.Func (N.to_nat n) (map N.to_nat vs) cmd :: funs)
    else
      None
  end.

Fixpoint list_Seq (cs: list ImpSyntax.cmd): ImpSyntax.cmd :=
  match cs with
  | [] => ImpSyntax.Skip
  | [x] => x
  | x :: xs => ImpSyntax.Seq x (list_Seq xs)
  end.

Definition builtin: list (name * list name * ImpSyntax.cmd) :=
  [(name_of_string "add", [name_of_string "a"; name_of_string "b"], list_Seq
     [ImpSyntax.Assign (name_of_string "c") 
        (ImpSyntax.Add (ImpSyntax.Var (name_of_string "a")) (ImpSyntax.Var (name_of_string "b")));
      ImpSyntax.If (ImpSyntax.Test ImpSyntax.Less (ImpSyntax.Var (name_of_string "c")) 
                                    (ImpSyntax.Var (name_of_string "a"))) 
        ImpSyntax.Abort ImpSyntax.Skip;
      ImpSyntax.If (ImpSyntax.Test ImpSyntax.Less (ImpSyntax.Var (name_of_string "c")) 
                                    (ImpSyntax.Var (name_of_string "b"))) 
        ImpSyntax.Abort ImpSyntax.Skip;
      ImpSyntax.Return (ImpSyntax.Var (name_of_string "c"))]);
   (name_of_string "sub", [name_of_string "a"; name_of_string "b"], list_Seq
     [ImpSyntax.If (ImpSyntax.Test ImpSyntax.Less (ImpSyntax.Var (name_of_string "a")) 
                                    (ImpSyntax.Var (name_of_string "b")))
        (ImpSyntax.Return (ImpSyntax.Const (word.of_Z 0)))
        (ImpSyntax.Return (ImpSyntax.Sub (ImpSyntax.Var (name_of_string "a")) 
                                          (ImpSyntax.Var (name_of_string "b"))))]);
   (name_of_string "cons", [name_of_string "a"; name_of_string "b"], list_Seq
     [ImpSyntax.Alloc (name_of_string "ret") (ImpSyntax.Const (word.of_Z 16));
      ImpSyntax.Update (ImpSyntax.Var (name_of_string "ret")) (ImpSyntax.Const (word.of_Z 0)) 
                       (ImpSyntax.Var (name_of_string "a"));
      ImpSyntax.Update (ImpSyntax.Var (name_of_string "ret")) (ImpSyntax.Const (word.of_Z 8)) 
                       (ImpSyntax.Var (name_of_string "b"));
      ImpSyntax.Return (ImpSyntax.Var (name_of_string "ret"))]);
   (name_of_string "cons3", [name_of_string "a"; name_of_string "b"; name_of_string "c"], list_Seq
     [ImpSyntax.Call (name_of_string "ret") (name_of_string "cons") 
        [ImpSyntax.Var (name_of_string "b"); ImpSyntax.Var (name_of_string "c")];
      ImpSyntax.Call (name_of_string "ret") (name_of_string "cons") 
        [ImpSyntax.Var (name_of_string "a"); ImpSyntax.Var (name_of_string "ret")];
      ImpSyntax.Return (ImpSyntax.Var (name_of_string "ret"))]);
   (name_of_string "cons4", [name_of_string "a"; name_of_string "b"; name_of_string "c"; name_of_string "d"], list_Seq
     [ImpSyntax.Call (name_of_string "ret") (name_of_string "cons3") 
        [ImpSyntax.Var (name_of_string "b"); ImpSyntax.Var (name_of_string "c"); ImpSyntax.Var (name_of_string "d")];
      ImpSyntax.Call (name_of_string "ret") (name_of_string "cons") 
        [ImpSyntax.Var (name_of_string "a"); ImpSyntax.Var (name_of_string "ret")];
      ImpSyntax.Return (ImpSyntax.Var (name_of_string "ret"))]);
   (name_of_string "cons5", [name_of_string "a"; name_of_string "b"; name_of_string "c"; name_of_string "d"; name_of_string "e"], list_Seq
     [ImpSyntax.Call (name_of_string "ret") (name_of_string "cons4")
        [ImpSyntax.Var (name_of_string "b"); ImpSyntax.Var (name_of_string "c"); 
         ImpSyntax.Var (name_of_string "d"); ImpSyntax.Var (name_of_string "e")];
      ImpSyntax.Call (name_of_string "ret") (name_of_string "cons") 
        [ImpSyntax.Var (name_of_string "a"); ImpSyntax.Var (name_of_string "ret")];
      ImpSyntax.Return (ImpSyntax.Var (name_of_string "ret"))])].

Definition get_func_name (d: FunSyntax.defun): name :=
  match d with
  | FunSyntax.Defun n _ _ => N.to_nat n
  end.

Definition has_conflicting_names (defs: list FunSyntax.defun): bool :=
  let reserved_names := name_of_string_N "main" :: map (fun '(n,_,_) => (N.of_nat n)) builtin in
  List.existsb (fun d =>
    List.existsb (N.eqb (N.of_nat (get_func_name d))) reserved_names
  ) defs.

Definition to_imp (p: FunSyntax.prog): option ImpSyntax.prog :=
  match p with
  | FunSyntax.Program defs main =>
    if has_conflicting_names defs then None else
    match to_funs (FunSyntax.Defun (name_of_string_N "main") [] main :: defs) with
    | Some fs =>
        Some (
          ImpSyntax.Program
            (map (fun '(n, vs, b) => ImpSyntax.Func n vs b) builtin ++ fs)
        )
    | None => None
    end
  end.

Example fp_prog1 :=
  FunSyntax.Program (@nil FunSyntax.defun) (
    FunSyntax.Op FunSyntax.Add [FunSyntax.Const 1; FunSyntax.Const 2]
  ).
Compute (to_imp fp_prog1).

Example fp_prog2 :=
  FunSyntax.Program (@nil FunSyntax.defun) (
    FunSyntax.Let 1
      (FunSyntax.Op FunSyntax.Add [FunSyntax.Const 1; FunSyntax.Const 2])
      (FunSyntax.Var 1)
  ).
Compute (to_imp fp_prog2).

(* TODO: forward semantics preservation *)
