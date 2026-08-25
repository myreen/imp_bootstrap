From impboot.functional Require Import FunSyntax FunValues FunSemantics FunProperties.
From impboot.imperative Require Import ImpSyntax.
From impboot.automation Require Import AutomationLemmas Ltac2Utils RelCompiler
  RelCompilerCommons ToANF ToLowerable ltac2.UnfoldFix.
From impboot.commons Require Import CompilerUtils.
From impboot.fp2imp Require Import FpToImpCodegen.
From impboot.utils Require Import Core.
From Stdlib Require Import Arith Bool Derive Lia List NArith String ZArith.
From coqutil Require Import Datatypes.List Word.Interface Word.Properties.
From Ltac2 Require Import Ltac2.
Require Import AdjustedBinomialHeap.

Import ListNotations.
Open Scope nat_scope.

Fixpoint encode_tree (t : tree) : FunValues.Value :=
  match t with
  | Leaf => FunValues.Num 0
  | Node x l r =>
      value_list_of_values [encode x; encode_tree l; encode_tree r]
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

Lemma auto_tree_Node : forall env s x0 x1 x2 x l r,
  env |-- ([x0], s) ---> ([encode x], s) ->
  env |-- ([x1], s) ---> ([encode l], s) ->
  env |-- ([x2], s) ---> ([encode r], s) ->
  env |--
    ([Op Cons [x0; Op Cons [x1; Op Cons [x2; FunSyntax.Const 0]]]], s)
    ---> ([@encode tree Refinable_tree (Node x l r)], s).
Proof.
  intros.
  ltac1:(Eval_eq).
Qed.

Ltac2 auto_tree_Node_tac (recur : unit -> unit) :=
  match! goal with
  | [ |- ?env |-- (_, _) ---> ([?encoded], _) ] =>
      let (_, args) := Constr.decompose_app encoded in
      let result := Array.get args (Int.sub (Array.length args) 1) in
      lazy_match! result with
      | Node ?x ?l ?r =>
          refine open_constr:(auto_tree_Node
            $env _ _ _ _ $x $l $r
            ltac2:(Control.enter recur)
            ltac2:(Control.enter recur)
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
    env s nx nl nr xt t xleaf xnode
    (fleaf : A) (fnode : key -> tree -> tree -> A),
  env |-- ([xt], s) ---> ([encode t], s) ->
  match t with
  | Leaf => t = Leaf ->
      env |-- ([xleaf], s) ---> ([encode fleaf], s)
  | Node x l r => t = Node x l r ->
      (FEnv.insert (name_enc nr, Some (encode r))
        (FEnv.insert (name_enc nl, Some (encode l))
          (FEnv.insert (name_enc nx, Some (encode x)) env)))
      |-- ([xnode], s) ---> ([encode (fnode x l r)], s)
  end ->
  NoDup ([name_enc nx; name_enc nl; name_enc nr] ++ free_vars xt) ->
  env |--
    ([FunSyntax.If FunSyntax.Equal [xt; FunSyntax.Const 0]
       xleaf
       (Let (name_enc nx) (Op Head [xt])
         (Let (name_enc nl) (Op Head [Op Tail [xt]])
           (Let (name_enc nr) (Op Head [Op Tail [Op Tail [xt]]])
             xnode)))], s)
    --->
    ([encode (match t with
              | Node x l r => fnode x l r
              | Leaf => fleaf
              end)], s).
Proof.
  intros * Hscr Hbranch Hnames.
  destruct t as [x l r|].
  2: ltac1:(Eval_eq).
  simpl in *.
  ltac1:(repeat rewrite NoDup_cons_iff in Hnames;
    simpl in Hnames;
    decompose [and] Hnames;
    clear Hnames).
  ltac1:(assert (Hnx : ~ In (name_enc nx) (free_vars xt)) by intuition).
  ltac1:(assert (Hnl : ~ In (name_enc nl) (free_vars xt)) by intuition).
  ltac1:(Eval_eq).
  all: try ltac1:(repeat rewrite remove_env_update by assumption; eauto).
  all: ltac1:(Eval_eq).
Qed.

Ltac2 auto_tree_case_tac (recur : unit -> unit) :=
  match! goal with
  | [ |- ?env |-- (_, _) ---> ([?encoded], _) ] =>
      let (_, args) := Constr.decompose_app encoded in
      let result := Array.get args (Int.sub (Array.length args) 1) in
      lazy_match! result with
      | (match ?t with
         | Node x l r => @?fnode x l r
         | Leaf => ?fleaf
         end) =>
          let names_in_cenv := List.map
            (fun hyp => let (id, _, _) := hyp in id)
            (Control.hyps ()) in
          let node_names :=
            binders_names_of_constr_lambda fnode names_in_cenv in
          let nx := List.nth node_names 0 in
          let nl := List.nth node_names 1 in
          let nr := List.nth node_names 2 in
          refine open_constr:(auto_tree_case
            $env _ $nx $nl $nr _ $t _ _ $fleaf $fnode
            ltac2:(Control.enter recur)
            ltac2:(destruct $t at 1; Control.enter (fun () =>
              intros;
              rewrite_lowerable ();
              try_to_anf_relcompile ();
              rewrite_lowerable ();
              recur ()))
            _)
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

Theorem unzip_acc_equation : ltac2:(unfold_fix_type '@unzip_acc).
Proof. unfold_fix_proof '@unzip_acc. Qed.

Theorem find_max'_equation : ltac2:(unfold_fix_type '@find_max').
Proof. unfold_fix_proof '@find_max'. Qed.

Theorem find_max_equation : ltac2:(unfold_fix_type '@find_max).
Proof. unfold_fix_proof '@find_max. Qed.

Theorem delete_max_aux_equation :
  ltac:(with_strategy opaque [heap_delete_max]
    ltac2:(unfold_fix_type '@delete_max_aux)).
Proof. unfold_fix_proof '@delete_max_aux. Qed.

Theorem insert_list_equation : ltac2:(unfold_fix_type '@insert_list).
Proof. unfold_fix_proof '@insert_list. Qed.

Theorem make_list_equation : ltac2:(unfold_fix_type '@make_list).
Proof. unfold_fix_proof '@make_list. Qed.

Derive smash_prog
  in ltac2:(relcompile_tpe 'smash_prog 'smash [])
  as smash_prog_correct.
Proof. relcompile. Qed.

Derive carry_prog
  in ltac2:(relcompile_tpe 'carry_prog 'carry ['smash])
  as carry_prog_correct.
Proof. relcompile. Qed.

Derive insert_prog
  in ltac2:(relcompile_tpe 'insert_prog 'insert ['carry])
  as insert_prog_correct.
Proof. relcompile. Qed.

Derive join_prog
  in ltac2:(relcompile_tpe 'join_prog 'join ['carry; 'smash])
  as join_prog_correct.
Proof. relcompile. Qed.

Derive merge_prog
  in ltac2:(relcompile_tpe 'merge_prog 'merge ['join])
  as merge_prog_correct.
Proof. relcompile. Qed.

Derive unzip_acc_prog
  in ltac2:(relcompile_tpe 'unzip_acc_prog 'unzip_acc [])
  as unzip_acc_prog_correct.
Proof. relcompile. Qed.

Derive unzip_prog
  in ltac2:(relcompile_tpe 'unzip_prog 'unzip ['unzip_acc])
  as unzip_prog_correct.
Proof. relcompile. Qed.

Derive heap_delete_max_prog
  in ltac2:(relcompile_tpe 'heap_delete_max_prog 'heap_delete_max ['unzip])
  as heap_delete_max_prog_correct.
Proof. relcompile. Qed.

Derive find_max'_prog
  in ltac2:(relcompile_tpe 'find_max'_prog 'find_max' [])
  as find_max'_prog_correct.
Proof. relcompile. Qed.

Derive find_max_prog
  in ltac2:(relcompile_tpe 'find_max_prog 'find_max ['find_max'])
  as find_max_prog_correct.
Proof. relcompile. Qed.

Derive delete_max_aux_prog
  in ltac2:(relcompile_tpe 'delete_max_aux_prog 'delete_max_aux ['heap_delete_max])
  as delete_max_aux_prog_correct.
Proof. relcompile. Qed.

Derive delete_max_prog
  in ltac2:(relcompile_tpe 'delete_max_prog 'delete_max
    ['find_max; 'delete_max_aux; 'join])
  as delete_max_prog_correct.
Proof. relcompile. Qed.

Derive insert_list_prog
  in ltac2:(relcompile_tpe 'insert_list_prog 'insert_list ['insert])
  as insert_list_prog_correct.
Proof. relcompile. Qed.

Derive make_list_prog
  in ltac2:(relcompile_tpe 'make_list_prog 'make_list [])
  as make_list_prog_correct.
Proof. relcompile. Qed.

Derive benchmark_main_prog
  in ltac2:(relcompile_tpe 'benchmark_main_prog 'benchmark_main
    ['make_list; 'insert_list; 'merge; 'delete_max])
  as benchmark_main_prog_correct.
Proof. relcompile. Qed.
