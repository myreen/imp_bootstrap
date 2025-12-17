From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From Stdlib Require Import derive.Derive.
From Stdlib Require Import Recdef.

From coqutil Require Import Tactics.reference_to_string.

From impboot Require Import utils.Core.
From impboot Require Import Ltac2Utils.

Open Scope nat.

Ltac2 kind_string_of_constr (c: constr): string :=
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

Ltac2 message_of_binder_relevance (r: Binder.relevance): message :=
  match r with
  | Binder.Relevant => fprintf "Relevant"
  | Binder.Irrelevant => fprintf "Irrelevant"
  | Binder.RelevanceVar _ => fprintf "RelevanceVar(..)"
  end.

Ltac2 message_of_reference (r: reference): message :=
  match reference_to_string r with
  | Some s => Message.of_string s
  | None => fprintf "WRONG REFERENCE"
  end.

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

Ltac2 message_of_option (opt: message option): message :=
  Option.default (fprintf "None") opt.

Ltac2 message_of_binder (b: binder): message :=
  match Binder.name b with
  | None =>
    fprintf "(_, %t)" (Binder.type b)
  | Some n =>
    fprintf "(%I, %t)" n (Binder.type b)
  end.

Ltac2 message_of_cenv (cenv: (constr option * constr) list): message :=
  message_of_list (
    List.map (fun p =>
      fprintf "(%a, %t)"
        (fun () c => message_of_option (Option.map Message.of_constr c))
        (fst p)
        (snd p)
    )
    cenv
  ).

Ltac2 print_full_goal () :=
  let hyps := Control.hyps () in
  List.iter (fun h =>
    match h with
    | (id, body, ty) =>
      (match body with
       | None => printf "%I : %t" id ty
       | Some b => printf "%I := %t : %t" id b ty
       end)
    end
  ) hyps;
  printf "----------------------------------------";
  let g := Control.goal () in
  printf "|- %t" g.