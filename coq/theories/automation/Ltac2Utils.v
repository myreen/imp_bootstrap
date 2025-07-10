From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message.
Import Ltac2.Constr.Unsafe.
From Coq Require Import derive.Derive.
From Coq Require Import Recdef.

From coqutil Require Import
  Tactics.reference_to_string
  Tactics.ident_of_string
  Tactics.ident_to_string.

From impboot Require Import utils.Core.
From impboot Require Import AutomationLemmas.

Open Scope nat.

Ltac2 opt_to_list (o: 'a option): 'a list := match o with | Some x => [x] | None => [] end.

Ltac2 kind_of_constr (c: constr): string :=
  match Unsafe.kind c with
  | Rel _ => "Rel"
  | Var _ => "Var"
  | Meta _ => "Meta"
  | Evar _ _ => "Evar"
  | Sort _ => "Sort"
  | Cast _ _ _ => "Cast"
  | Prod _ _ => "Prod"
  | Lambda _ _ => "Lambda"
  | LetIn _ _ _ => "LetIn"
  | App _ _ => "App"
  | Constant _ _ => "Constant"
  | Ind _ _ => "Ind"
  | Constructor _ _ => "Constructor"
  | Case _ _ _ _ _ => "Case"
  | Fix _ _ _ _ => "Fix"
  | CoFix _ _ _ => "CoFix"
  | Proj _ _ _ => "Proj"
  | Uint63 _ => "Uint63"
  | Float _ => "Float"
  | String _ => "String"
  | Array _ _ _ _ => "Array"
  end.

Ltac2 reference_of_constr_opt (c: constr): reference option :=
  match kind c with
  | Var id => Some (Std.VarRef id)
  | Constant const _inst => Some (Std.ConstRef const)
  | Ind ind _inst => Some (Std.IndRef ind)
  | Constructor cnstr _inst => Some (Std.ConstructRef cnstr)
  | _ => None
end.

Ltac2 reference_to_string (r : reference) : string option :=
  Some (Ident.to_string (List.last (Env.path r))).

Ltac2 ident_of_fqn (fqn: string list): ident list :=
  List.map (fun s => Option.get (Ident.of_string s)) fqn.

Ltac2 messsage_of_option (o : message option) : message :=
  match o with
  | Some x => x
  | None => Message.of_string "None"
  end.

Ltac2 message_of_list (l : message list) : message :=
  let rec of_list_go (l : message list) :=
    match l with
    | [] => Message.of_string ""
    | [x] => x
    | x :: xs => Message.concat x (Message.concat (Message.of_string ",") (of_list_go xs))
    end
  in Message.concat (Message.of_string "[ ") (Message.concat (of_list_go l) (Message.of_string " ]")).

Ltac2 messsage_of_option_constr (o : constr option) : message :=
  match o with
  | Some c => Message.of_constr c
  | None => Message.of_string "None"
  end.

Ltac rewrite_let :=
  match goal with
  | [ |- context C [?subterm] ] =>
    match subterm with
    | let x := ?a in @?b x =>
      let C' := context C [b a] in
      change C'
    end
  end.

Ltac unfold_fix fn :=
  let H := fresh "H" in
  let f := fresh "f" in
  instantiate (1 := forall x, fn x = ?[f] x);
  (
    unfold fn;
    instantiate
      (f :=
        ltac:(
          let ll := fresh "ll" in
          intros ll;
          let thm := constr:(analyze ll) in
          apply thm; intros
        )
      );
    cbv beta;
    match goal with
    | [ |- forall l, _ ] =>
        let ll := fresh l in
        intros ll; destruct ll
    end; fold fn; simpl analyze; reflexivity
  );
  cbv beta;
  simpl analyze.

Ltac unfold_tpe fn :=
  let unfolded := ltac:(unfold_fix constr:(fn)) in
  let t := type of ltac:(unfolded) in
  refine t.

Ltac unfold_proof :=
  let ll := fresh "ll" in
  intros ll;
  cbv beta;
  destruct ll;
  simpl;
  reflexivity.

Ltac2 isFix (fconstr: constr): bool :=
  let fref := reference_of_constr fconstr in
  let unfolded := Std.eval_unfold [(fref, AllOccurrences)] fconstr in
  Constr.is_fix unfolded.

Ltac2 Type exn ::= [
  Oopsie (string)
].

Ltac2 unfold_once (fconstr: constr) (exprconstr: constr): constr :=
  if isFix fconstr then
    let fref: reference option := reference_of_constr_opt fconstr in
    let f_str: string option := Option.bind fref reference_to_string in
    let f_equation_str: string option := Option.map (fun n => String.app n "_equation") f_str in
    let f_equation_ident: ident list option := Option.map (fun s => ident_of_fqn [s]) f_equation_str in
    (* print (messsage_of_option (Option.map (fun l => messsage_of_list (List.map Message.of_ident l)) f_equation_ident)); *)
    let f_equation_ref: reference list := List.flat_map (fun id => Env.expand id) (opt_to_list f_equation_ident) in
    match f_equation_ref with
    | [ref] =>
      (* TODO(kπ) should be rewrite *)
      (* can we rewrite in constr? *)
      Std.eval_unfold [(ref, AllOccurrences)] exprconstr
    | _ =>
      (* TODO(kπ) Add fconstr name or sth *)
      Control.throw (Oopsie "No (or too many) _equation lemma found");
      fconstr
    end
  else
    let f_name_r := reference_of_constr fconstr in
    let expr_norm := Std.eval_unfold [(f_name_r, AllOccurrences)] exprconstr in
    expr_norm.

(* Definition has_match (l: list nat) : nat :=
  1 +
  match l with
  | nil => 0
  | cons h t => h + 100
  end.

Lemma has_match_equation : ltac:(unfold_tpe has_match).
Proof. ltac1:(unfold_proof). Qed.

About has_match_equation.

Fixpoint sum_n (n : nat) : nat :=
  match n with
  | 0 => 1 + 1
  | S n1 => (sum_n n1)(*  + n *)
  end.

Lemma sum_n_equation : ltac:(unfold_tpe sum_n).
Proof. ltac1:(unfold_proof). Qed.

About sum_n_equation.

Goal forall n, sum_n n = 1.
Proof.
  intros.
  (* unfold_once constr:(sum_n) constr:(forall n, sum_n n = 1). *)
  rewrite sum_n_equation.
  (* ltac1:(unfold_fix sum_n). *)
Abort.

Goal forall l, has_match l = 1.
Proof.
  intros.
  rewrite has_match_equation.
  unfolded_def constr:(has_match).
  (* ltac1:(unfold_fix has_match). *)
Abort. *)