From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.
From impboot Require Import Ltac2Utils ltac2.Constrs ltac2.Stdlib2 ltac2.Messages.

Ltac2 rec dedup_go (acc: 'a list) (l: 'a list) (eq: 'a -> 'a -> bool): 'a list :=
  match l with
  | [] => acc
  | h :: l =>
    if List.exist (eq h) acc then dedup_go acc l eq
    else dedup_go (h :: acc) l eq
  end.
Ltac2 dedup (l: 'a list) (eq: 'a -> 'a -> bool): 'a list :=
  dedup_go [] l eq.

(* The problem with automatically detecting dependencies is: how do I know which are the "real" rependencies? *)
(*   i.e. why is "add" not a dependency? *)
(*   Actually, maybe just black-list some built-in functions? *)
Ltac2 rec collect_deps (bs: ident list) (c: constr): constr list :=
  Message.print (Messages.message_of_list (List.map Message.of_ident bs));
  match kind c with
  | Var i =>
    if List.exist (fun b => Ident.equal i b) bs then []
    else [c]
  | Constant _ _ => [c]
  | Rel _ | Meta _ | Sort _ | Ind _ _
  | Constructor _ _ | Uint63 _ | Float _ | String _ => []
  | Cast c _ _t => collect_deps bs c
  | Prod b c =>
    let new_bs := (List.append (opt_to_list (Binder.name b)) bs) in
    collect_deps new_bs c
  | Lambda b c =>
    let new_bs := (List.append (opt_to_list (Binder.name b)) bs) in
    collect_deps new_bs c
  | LetIn b t c =>
    let new_bs := (List.append (opt_to_list (Binder.name b)) bs) in
    List.append (collect_deps bs t) (collect_deps new_bs c)
  | App c l =>
    List.append (collect_deps bs c) (List.concat (List.map (collect_deps bs) (Array.to_list l)))
  | Evar _ _l => []
  | Case _ x _iv y bl =>
    List.append
      (List.append (match x with (x,_) => collect_deps bs x end) (List.concat (List.map (collect_deps bs) (Array.to_list bl))))
      (collect_deps bs y)
  | Proj _p _ c =>
    collect_deps bs c
  | Fix _ _ tl bl =>
    let new_bs := (List.append (List.flat_map (fun b => opt_to_list (Binder.name b)) (Array.to_list tl)) bs) in
    (* TODO: is this correct? vvvvvvvvvvvvvvvvvvvvvv *)
    List.concat (List.map (collect_deps new_bs) (Array.to_list bl))
  | CoFix _ tl bl =>
    let new_bs := (List.append (List.flat_map (fun b => opt_to_list (Binder.name b)) (Array.to_list tl)) bs) in
    (* TODO: is this correct? vvvvvvvvvvvvvvvvvvvvvv *)
    List.concat (List.map (collect_deps new_bs) (Array.to_list bl))
  | Array _u t def _ty =>
    List.append (List.concat (List.map (collect_deps bs) (Array.to_list t))) (collect_deps bs def)
  end.
Ltac2 get_fun_deps (f: constr): constr list :=
  let f_constr_name := Option.get (Option.bind (reference_of_constr_opt f) reference_to_string) in
  let f_name_r := reference_of_constr f in
  let all_deps := collect_deps (opt_to_list (Ident.of_string f_constr_name)) (Std.eval_unfold [(f_name_r, AllOccurrences)] f) in
  dedup all_deps (Constr.equal).
