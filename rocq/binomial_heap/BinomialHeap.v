From impboot.functional Require Import FunSyntax FunValues FunSemantics.
From impboot.imperative Require Import ImpSyntax.
From impboot.automation Require Import AutomationLemmas Ltac2Utils RelCompiler
  RelCompilerCommons ltac2.UnfoldFix.
From impboot.commons Require Import CompilerUtils.
From impboot.fp2imp Require Import FpToImpCodegen.
From impboot.utils Require Import Core.
From Stdlib Require Import Arith Bool Derive Lia List NArith String ZArith.
From coqutil Require Import Datatypes.List Word.Interface Word.Properties.
From Ltac2 Require Import Ltac2.

Import ListNotations.
Open Scope nat_scope.

(** The executable core is adapted from CertiCoq's [tests/lib/Binom.v].
    Only the dependency closure of [insert] and [merge] is retained. *)

Definition key := nat.

Inductive tree : Type :=
| Leaf : tree
| Node : (key * tree * tree) -> tree.

Definition heap := list tree.

Definition empty : heap := [].

Definition link (p q : key * tree * tree) : tree :=
  match p, q with
  | (x, t1, Leaf), (y, u1, Leaf) =>
      if y <? x
      then Node (x, Node (y, u1, t1), Leaf)
      else Node (y, Node (x, t1, u1), Leaf)
  | _, _ => Leaf
  end.

Definition smash (t u : tree) : tree :=
  match t, u with
  | Node p, Node q => link p q
  | _, _ => Leaf
  end.

Fixpoint carry (q : heap) (t : tree) : heap :=
  let/d ot := t in
  match q with
  | [] =>
      match t with
      | Leaf => []
      | Node _ =>
          let/d result := ot :: [] in
          result
      end
  | u :: q' =>
      let/d ou := u in
      match u with
      | Leaf =>
          let/d result := ot :: q' in
          result
      | Node _ =>
          match t with
          | Leaf =>
              let/d result := ou :: q' in
              result
          | Node _ =>
              let/d smashed := smash ot ou in
              let/d carried := carry q' smashed in
              let/d result := Leaf :: carried in
              result
          end
      end
  end.

Definition insert (x : key) (q : heap) : heap :=
  carry q (Node (x, Leaf, Leaf)).

Fixpoint join (p q : heap) (c : tree) : heap :=
  let/d op := p in
  let/d oc := c in
  match p with
  | [] => carry q oc
  | p1 :: p' =>
      let/d op1 := p1 in
      match q with
      | [] => carry op oc
      | q1 :: q' =>
          let/d oq1 := q1 in
          match p1 with
          | Leaf =>
              match q1 with
              | Leaf =>
                  let/d joined := join p' q' Leaf in
                  let/d result := oc :: joined in
                  result
              | Node _ =>
                  match c with
                  | Leaf =>
                      let/d joined := join p' q' Leaf in
                      let/d result := oq1 :: joined in
                      result
                  | Node _ =>
                      let/d smashed := smash oc oq1 in
                      let/d joined := join p' q' smashed in
                      let/d result := Leaf :: joined in
                      result
                  end
              end
          | Node _ =>
              match q1 with
              | Leaf =>
                  match c with
                  | Leaf =>
                      let/d joined := join p' q' Leaf in
                      let/d result := op1 :: joined in
                      result
                  | Node _ =>
                      let/d smashed := smash oc op1 in
                      let/d joined := join p' q' smashed in
                      let/d result := Leaf :: joined in
                      result
                  end
              | Node _ =>
                  let/d smashed := smash op1 oq1 in
                  let/d joined := join p' q' smashed in
                  let/d result := oc :: joined in
                  result
              end
          end
      end
  end.

Definition merge (p q : heap) : heap :=
  join p q Leaf.

(** Sum every key in a tree.  This makes the benchmark result observable
    without adding deletion to the initial reification target. *)
Fixpoint tsum (t : tree) : nat :=
  match t with
  | Leaf => 0
  | Node (x, l, r) => x + tsum l + tsum r
  end.

Fixpoint hsum (q : heap) : nat :=
  match q with
  | [] => 0
  | t :: q' => tsum t + hsum q'
  end.

(** Insert the keys [n], ..., [1] into [q]. *)
Fixpoint fill (n : nat) (q : heap) : heap :=
  match n with
  | 0 => q
  | S n' => fill n' (insert (n' + 1) q)
  end.

(** Build two heaps, merge them, and checksum all stored keys. *)
Definition bench (n : nat) : nat :=
  let/d q1 := fill n [] in
  let/d n1 := n + 1 in
  let/d q2 := fill n1 [] in
  let/d merged := merge q1 q2 in
  hsum merged.

(** Convert a checksum to its final ASCII decimal digit. *)
Definition digit (n : nat) : nat :=
  48 + (n - 10 * (n / 10)).

(** Trees are represented as constructor-tagged lists.  This matches the
    representation convention used by the functional source language. *)
Fixpoint encode_tree (t : tree) : FunValues.Value :=
  match t with
  | Leaf => FunValues.Num 0
  | Node (x, l, r) =>
      FunValues.Pair
        (FunValues.Pair
          (FunValues.Pair (encode x) (encode_tree l))
          (encode_tree r))
        (FunValues.Num 0)
  end.

Global Instance Refinable_tree : Refinable tree :=
  {| encode := encode_tree |}.

Lemma auto_tree_Leaf : forall env s,
  env |-- ([FunSyntax.Const 0], s) --->
    ([@encode tree Refinable_tree Leaf], s).
Proof.
  intros.
  constructor.
Qed.

Ltac2 auto_tree_Leaf_tac (_r : unit -> unit) :=
  match! goal with
  | [ |- ?env |-- (_, _) ---> ([?encoded], _) ] =>
      let (_, args) := Constr.decompose_app encoded in
      let result := Array.get args (Int.sub (Array.length args) 1) in
      lazy_match! result with
      | Leaf => refine open_constr:(auto_tree_Leaf $env _)
      end
  end.

Lemma auto_tree_Node : forall env s x0 p,
  env |-- ([x0], s) ---> ([encode p], s) ->
  env |--
    ([Op Cons [x0; FunSyntax.Const 0]], s)
    ---> ([@encode tree Refinable_tree (Node p)], s).
Proof.
  intros * Heval.
  destruct p as [[x l] r].
  simpl in *.
  ltac1:(Eval_eq).
Qed.

Ltac2 auto_tree_Node_tac (recur : unit -> unit) :=
  match! goal with
  | [ |- ?env |-- (_, _) ---> ([?encoded], _) ] =>
      let (_, args) := Constr.decompose_app encoded in
      let result := Array.get args (Int.sub (Array.length args) 1) in
      lazy_match! result with
      | Node ?p =>
          refine open_constr:(auto_tree_Node
            $env _ _ $p
            ltac2:(Control.enter recur))
      end
  end.

Ltac2 Set relCompilerDB as olddb :=
  fun recur =>
    Control.plus (fun () => olddb recur)
      (fun _ => auto_tree_Leaf_tac recur).

Ltac2 Set relCompilerDB as olddb :=
  fun recur =>
    Control.plus (fun () => olddb recur)
      (fun _ => auto_tree_Node_tac recur).

Lemma auto_tree_case : forall {A} `{Refinable A}
    env s np xt t xleaf xnode
    (fleaf : A) (fnode : (key * tree * tree) -> A),
  env |-- ([xt], s) ---> ([encode t], s) ->
  match t with
  | Leaf =>
      env |-- ([xleaf], s) ---> ([encode fleaf], s)
  | Node p =>
      (FEnv.insert (name_enc np, Some (encode p))
        env)
      |-- ([xnode], s) ---> ([encode (fnode p)], s)
  end ->
  env |--
    ([FunSyntax.If FunSyntax.Equal [xt; FunSyntax.Const 0]
       xleaf
       (Let (name_enc np) (Op Head [xt]) xnode)], s)
    --->
    ([encode (match t with
              | Leaf => fleaf
              | Node p => fnode p
              end)], s).
Proof.
  intros * Hscr Hbranch.
  destruct t as [|[[x l] r]].
  all: ltac1:(Eval_eq).
Qed.

Ltac2 auto_tree_case_tac (recur : unit -> unit) :=
  match! goal with
  | [ |- ?env |-- (_, _) ---> ([?encoded], _) ] =>
      let (_, args) := Constr.decompose_app encoded in
      let result := Array.get args (Int.sub (Array.length args) 1) in
      lazy_match! result with
      | (match ?t with
         | Leaf => ?fleaf
         | Node p => @?fnode p
         end) =>
          let names_in_cenv := List.map
            (fun hyp => let (id, _, _) := hyp in id)
            (Control.hyps ()) in
          let node_names :=
            binders_names_of_constr_lambda fnode names_in_cenv in
          let np := List.nth node_names 0 in
          refine open_constr:(auto_tree_case
            $env _ $np _ $t _ _ $fleaf $fnode
            ltac2:(Control.enter recur)
            ltac2:(destruct $t; Control.enter recur))
      end
  end.

Ltac2 Set relCompilerDB as olddb :=
  fun recur =>
    Control.plus (fun () => olddb recur)
      (fun _ => auto_tree_case_tac recur).

Theorem carry_equation : ltac2:(unfold_fix_type '@carry).
Proof. unfold_fix_proof '@carry. Qed.

Theorem join_equation : ltac2:(unfold_fix_type '@join).
Proof. unfold_fix_proof '@join. Qed.

Theorem tsum_equation : ltac2:(unfold_fix_type '@tsum).
Proof. unfold_fix_proof '@tsum. Qed.

Theorem hsum_equation : ltac2:(unfold_fix_type '@hsum).
Proof. unfold_fix_proof '@hsum. Qed.

Theorem fill_equation : ltac2:(unfold_fix_type '@fill).
Proof. unfold_fix_proof '@fill. Qed.

Derive link_prog
  in ltac2:(relcompile_tpe 'link_prog 'link [])
  as link_prog_correct.
Proof. relcompile. Qed.
Print link.
Print link_prog.

Derive smash_prog
  in ltac2:(relcompile_tpe 'smash_prog 'smash ['link])
  as smash_prog_correct.
Proof. relcompile. Qed.
Print smash.
Print smash_prog.

Derive carry_prog
  in ltac2:(relcompile_tpe 'carry_prog 'carry ['smash])
  as carry_prog_correct.
Proof. relcompile. Qed.
Print carry.
Print carry_prog.

Derive insert_prog
  in ltac2:(relcompile_tpe 'insert_prog 'insert ['carry])
  as insert_prog_correct.
Proof. relcompile. Qed.
Print insert.
Print insert_prog.

Derive join_prog
  in ltac2:(relcompile_tpe 'join_prog 'join ['carry; 'smash])
  as join_prog_correct.
Proof. relcompile; ltac1:(typeclasses eauto). Qed.
Print join.
Print join_prog.

Derive merge_prog
  in ltac2:(relcompile_tpe 'merge_prog 'merge ['join])
  as merge_prog_correct.
Proof. relcompile. Qed.

Derive tsum_prog
  in ltac2:(relcompile_tpe 'tsum_prog 'tsum [])
  as tsum_prog_correct.
Proof. relcompile. Qed.

Derive hsum_prog
  in ltac2:(relcompile_tpe 'hsum_prog 'hsum ['tsum])
  as hsum_prog_correct.
Proof. relcompile. Qed.

Derive fill_prog
  in ltac2:(relcompile_tpe 'fill_prog 'fill ['insert])
  as fill_prog_correct.
Proof. relcompile. Qed.

Derive bench_prog
  in ltac2:(relcompile_tpe 'bench_prog 'bench ['fill; 'merge; 'hsum])
  as bench_prog_correct.
Proof. relcompile. Qed.

Derive mul10_prog
  in ltac2:(relcompile_tpe 'mul10_prog 'mulnat10 [])
  as mul10_prog_correct.
Proof. relcompile. Qed.

Derive digit_prog
  in ltac2:(relcompile_tpe 'digit_prog 'digit ['mulnat10])
  as digit_prog_correct.
Proof. relcompile; ltac1:(lia). Qed.

(** Complete dependency-ordered functional program for the heap benchmark. *)
Definition binomial_funs : list FunSyntax.defun := [
  link_prog;
  smash_prog;
  carry_prog;
  insert_prog;
  join_prog;
  merge_prog;
  tsum_prog;
  hsum_prog;
  fill_prog;
  bench_prog;
  mul10_prog;
  digit_prog
].

Definition binomial_imp_funs := to_funs binomial_funs.

Lemma binomial_imp_funs_ok :
  exists fs, binomial_imp_funs = Some fs.
Proof.
  vm_compute.
  eauto.
Qed.

Lemma binomial_funs_no_dup :
  NoDup (List.map (fun d =>
    match d with FunSyntax.Defun name _ _ => name end) binomial_funs).
Proof.
  vm_compute.
  ltac1:(repeat (apply NoDup_cons; [vm_compute; intuition congruence |]);
    apply NoDup_nil).
Qed.
