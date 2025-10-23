From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
From coqutil Require Import dlet.
From coqutil Require Import Word.Interface.
Require Import impboot.functional.FunValues.
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.
Require Import impboot.utils.Env.
From impboot Require Import automation.Ltac2Utils.
From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf Fresh.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import
  Tactics.reference_to_string
  Tactics.ident_of_string
  Tactics.ident_to_string.
From Coq Require Import derive.Derive.
From Coq Require Import FunInd.

(* Important notes *)
(* 1. every destruct has to have a `eqn:?` (Otherwise, we can get a bunch of
   goal that need to provide base case values for some types)
   This might be an issue with fix unfolding, since it only happens when we have a fixpoint with a match *)
(* 2. For polymorphic functions always provide them with @ e.g. @length *)

Open Scope nat.

Ltac2 rec string_of_relevance (r: Binder.relevance): string :=
  match r with
  | Binder.Relevant => "Relevant"
  | Binder.Irrelevant => "Irrelevant"
  | Binder.RelevanceVar (_) => "RelevanceVar"
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

Ltac2 constr_is_sort (c: constr): bool :=
  match Unsafe.kind c with
  | Unsafe.Sort _ => true
  | _ => false
  end.

Ltac2 rec split_thm_args (c: constr): constr list :=
  match Unsafe.kind c with
  | Prod b c1 =>
    (Binder.type b) :: split_thm_args c1
  | _ => []
  end.

Ltac2 maybe_thm_binder (c: constr): binder option :=
  match Unsafe.kind (Constr.type c) with
  | Prod b _ =>
    Some b
  | _ => None
  end.

Ltac2 intro_then (nm: ident) (k: constr -> unit): unit :=
  Control.enter (fun () =>
    let x := Fresh.in_goal nm in
    Std.intros false [IntroNaming (IntroFresh x)];
    let x_constr := (Control.hyp x) in
    k x_constr
  ).

Ltac2 intro_then_refine (nm: ident) (k: constr -> constr): constr :=
  open_constr:(ltac2:(
    intro_then nm (fun c => Control.refine (fun () => k c))
  )).

Ltac2 rec intros_then_refine (nms: ident list) (hyps_acc: constr list) (k: constr list -> constr): constr :=
  match nms with
  | [] => k hyps_acc
  | nm :: nms =>
    intro_then_refine nm (fun h =>
      intros_then_refine nms (List.append hyps_acc [h]) k
    )
  end.

Ltac2 rec apply_thm (thm: constr) (args: (unit -> unit) list): constr :=
  match args with
  | [] => thm
  | arg :: args =>
    apply_thm open_constr:($thm ltac2:(Control.enter arg)) args
  end.

(* Returns the number of arguments a theorem named `lname` takes *)
Ltac2 rec thm_parts_length (lname: string): int :=
  let lemma_ref: reference := List.hd (Env.expand (ident_of_fqn [lname])) in
  let lemma_inst: constr := Env.instantiate lemma_ref in
  let lemma_tpe: constr := type lemma_inst in
  let thm_parts := split_thm_args lemma_tpe in
  List.length thm_parts.

Ltac2 rec apply_continuations (lemma_inst: constr) (lname: string) (thm_parts: constr list)
                              (continuations: (unit -> unit) list): constr :=
  let lemma_inst := eval_cbv beta lemma_inst in
  match thm_parts, continuations with
  | [], [] => lemma_inst
  | _ :: thm_parts, k :: continuations =>
    apply_continuations open_constr:($lemma_inst ltac2:(Control.enter k)) lname thm_parts continuations
  | [], _ => Control.throw (Oopsie (fprintf "Too many continuations passed when compiling with lemma %s" lname))
  | _, [] => Control.throw (Oopsie (fprintf "Not enough continuations passed when compiling with lemma %s" lname))
  end.

Ltac2 rec assemble_lemma (lemma_inst: constr) (lname: string) (named_conts: (ident * (unit -> unit)) list)
                         (conts: (unit -> unit) list): constr :=
  let lemma_inst := eval_cbv beta lemma_inst in
  match maybe_thm_binder lemma_inst with
  | None =>
    if Bool.neg (Int.equal (List.length named_conts) 0) then
      let names_left := List.map fst named_conts in
      Control.throw (Oopsie (
        fprintf "Unapplied named continuations left after applying lemma %s, namely %a"
          lname
          (fun () nl => message_of_list (List.map Message.of_ident nl))
          names_left
      ))
    else if Bool.neg (Int.equal (List.length conts) 0) then
      Control.throw (Oopsie (
        fprintf "Unapplied unnamed continuations left after applying lemma %s, namely %i continuations left"
          lname
          (List.length conts)
      ))
    else lemma_inst
  | Some b =>
    match Binder.name b with
    | Some nm =>
      (* named binder -> term *)
      match List.find_opt (fun n => Ident.equal (fst n) nm) named_conts with
      | Some (_, ext) =>
        let new_named_conts := List.filter (fun p => Bool.neg (Ident.equal (fst p) nm)) named_conts in
        (* TODO: check the $extr                vvvvv *)
        assemble_lemma open_constr:($lemma_inst ltac2:(ext ())) lname new_named_conts conts
      | None =>
        assemble_lemma open_constr:($lemma_inst _) lname named_conts conts
      end
    | None =>
      (* unnamed binder -> use continuations *)
      match conts with
      | k :: conts =>
        assemble_lemma open_constr:($lemma_inst ltac2:(Control.enter k)) lname named_conts conts
      | _ =>
        Control.throw (Oopsie (fprintf "Not enough continuations passed when compiling with lemma %s" lname))
      end
    end
  end.

(* Apply lemma named `lname`, use compilaiton funciton `compile_fn` to compile "eval" premises of the lemma *)
(*   Fill in `extracted` terms for term premises *)
(*   (Also make sure to update the `cenv` while recursing) *)
Ltac2 app_lemma (lname: string) (named_conts: (string * (unit -> unit)) list)
                (conts: (unit -> unit) list): unit :=
  printf "applying lemma: %s" lname;
  let lemma_ref: reference := List.hd (Env.expand (ident_of_fqn [lname])) in
  let lemma_inst: constr := Env.instantiate lemma_ref in
  (* let lemma_tpe: constr := type lemma_inst in *)
  (* let thm_parts := split_thm_args lemma_tpe in *)
  let named_conts_id :=
    List.flat_map (fun p =>
      match Ident.of_string (fst p) with
      | Some i => [(i, snd p)]
      | _ => []
      end) named_conts in
  refine (assemble_lemma lemma_inst lname named_conts_id conts).

(* Lookup the funciton `fname` in the `f_lookup` map *)
Ltac2 is_in_loopkup (f_lookup : string list) (fname : string) : bool :=
  match List.find_opt (String.equal fname) f_lookup with
  | Some _ => true
  | None => false
  end.

(* Check if `c` is a "proper" constant – used for sanity checks when compiling constants *)
Ltac2 rec proper_const (c: constr): bool :=
  match Constr.Unsafe.kind c with
  | Var _ => true
  | Constant _ _ => true
  | Constructor _ _ => true
  | App c cs => Bool.and (proper_const c) (Array.for_all proper_const cs)
  | _ => false
  end.

(* Returns a tuple of (functions_part, arguments) if its a function application or ident,
   otherwise None*)
Ltac2 rec extract_fun (e: constr): (constr * constr list) option :=
  match! e with
  | (?f ?arg) =>
    match extract_fun f with
    | Some (f_fun, f_args) =>
      let f_args1 := List.append f_args [arg] in
      Some (f_fun, f_args1)
    | None =>
      Some (f, [arg])
    end
  | ?f =>
    if Constr.is_var f then
      Some (f, [])
    else if Constr.is_const f then
      Some (f, [])
    else
      None
  end.

Ltac2 rec apply_to_args (fn: constr) (args: constr list) :=
  match args with
  | [] => fn
  | arg :: args =>
    apply_to_args open_constr:($fn $arg) args
  end.

Ltac2 rec list_to_constr_encode (l: constr list): constr :=
  match l with
  | [] => open_constr:([])
  | x :: xs =>
    let xs' := list_to_constr_encode xs in
    open_constr:((encode $x) :: $xs')
end.

Ltac2 message_of_f_lookup (f_lookup : (string * constr) list) : message :=
  match f_lookup with
  | [] => Message.of_string "[]"
  | _ =>
    let f_lookup' := List.map (fun (name, iden) =>
      Message.concat (Message.of_string name) (Message.concat (Message.of_string " -> ") (Message.of_constr iden))
    ) f_lookup in
    message_of_list f_lookup'
end.

Ltac2 rec constr_list_of_encode_constr (c : constr) : constr list :=
  match! c with
  | [] => []
  | (encode ?x) :: ?xs => x :: constr_list_of_encode_constr xs
  end.

Ltac2 name_enc_of_constr (c: constr): constr option :=
  match! c with
  | name_enc ?x => Some x
  | _ => None
  end.

(* TODO: this may depend on name_enc being Opaque *)
Ltac2 rec name_enc_constr_list_of_constr (c : constr) : constr option list :=
  match! c with
  | [] => []
  | ?x :: ?xs =>
    name_enc_of_constr x :: name_enc_constr_list_of_constr xs
  end.

Ltac2 rec list_zip (xs: 'a list) (ys: 'b list): ('a * 'b) list :=
  match xs, ys with
  | x :: xs, y :: ys => (x, y) :: list_zip xs ys
  | _ => []
  end.

Ltac2 rec get_cenv_from_fenv_constr (fenv: constr): (constr option * constr) list :=
  lazy_match! fenv with
  | FEnv.insert (?n, Some (encode ?v)) ?fenv =>
    let acc := get_cenv_from_fenv_constr fenv in
    (name_enc_of_constr n, v) :: acc
  | FEnv.insert (?_n, None) ?fenv =>
    get_cenv_from_fenv_constr fenv
  | make_env ?ns ?vs ?fenv =>
    let acc := get_cenv_from_fenv_constr fenv in
    let names := name_enc_constr_list_of_constr ns in
    let values := constr_list_of_encode_constr vs in
    List.append (list_zip names values) acc
  | _ => []
  end.

(* Apply the hypothesis `iden` to wildcards, until it is a top-level `eval_app` *)
(* Ltac2 rec refine_up_to_eval_app (iden : ident) (t : constr) : constr :=
  lazy_match! t with
  | (forall x, @?t1 x) =>
    let t1_refined := refine_up_to_eval_app iden t1 in
    open_constr:($t1_refined _)
  | (fun _ => ?t1) =>
    let t1_refined := refine_up_to_eval_app iden t1 in
    open_constr:($t1_refined _)
  | (_ -> ?t1) =>
    let t1_refined := refine_up_to_eval_app iden t1 in
    open_constr:($t1_refined _)
  | eval_app _ _ _ _ =>
    Control.hyp iden
  | ?t1 =>
    t1
  end. *)

Ltac2 get_f_lookup_from_hyps () : string list :=
  let hyps := Control.hyps () in
  let f_lookup := List.flatten (List.map (fun (_iden, _, t) =>
    match! t with
    | context [ eval_app (name_enc ?fname1) _ _ _ ] =>
      [string_of_constr_string fname1]
    | _ => []
    end
  ) hyps) in
  f_lookup.

Ltac2 fname_if_in_f_lookup (f_lookup: string list) (f: constr) :=
  let f_name_r: reference option := reference_of_constr_opt f in
  let f_name_str := Option.bind f_name_r reference_to_string in
  Option.bind f_name_str (fun n => if is_in_loopkup f_lookup n then Some n else None).

Ltac2 rec binders_names_of_constr_lambda (c: constr) (avoid: ident list): constr list :=
  match Unsafe.kind c with
  | Lambda b c1 =>
    match Binder.name b with
    | Some n =>
      let n := Fresh.fresh (Free.of_ids avoid) n in
      constr_string_of_string (Ident.to_string n) :: binders_names_of_constr_lambda c1 (n :: avoid)
    | None =>
      let n := Fresh.fresh (Free.of_ids avoid) (Option.get (Ident.of_string "a")) in
      constr_string_of_string (Ident.to_string n) :: binders_names_of_constr_lambda c1 (n :: avoid)
    end
  | _ => []
  end.

Ltac2 rec binders_of_constr_lambda (c: constr): binder list :=
  match Unsafe.kind c with
  | Lambda b c1 =>
    b :: binders_of_constr_lambda c1
  | _ => []
  end.

Ltac2 rec in_contexts (bs: binder list) (c: unit -> constr) (): constr :=
  match bs with
  | [] => c ()
  | b :: bs =>
    (* let name := Option.default (Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "x"))) (Binder.name b) in *)
    let name := Option.get (Binder.name b) in
    (* it should ideally be (Binder.type b) instead of open_constr:(_), but it breaks the current procedure for dependent types *)
    Constr.in_context name open_constr:(_) (fun () =>
      (* let b_hyp := Control.hyp name in *)
      let r := in_contexts bs c in
      Control.refine r
    )
  end.

Ltac2 rec lambda_to_prod (c: constr): constr :=
  match Unsafe.kind c with
  | Lambda b body => make (Prod b (lambda_to_prod body))
  | _ => c
  end.

Ltac2 rec collect_prod_binders_impl (c: constr): binder list :=
  match Unsafe.kind c with
  | Prod b c =>
    b :: collect_prod_binders_impl c
  | _ => []
  end.
Ltac2 collect_prod_binders (c: constr): binder list :=
  collect_prod_binders_impl (Constr.type c).

Ltac2 struct_of_fix (fconstr: constr): int :=
  let fref := reference_of_constr fconstr in
  let unfolded := Std.eval_unfold [(fref, AllOccurrences)] fconstr in
  match Unsafe.kind unfolded with
  | Fix structs _ _ _ =>
    Array.get structs 0
  | _ =>
    Control.throw (Oopsie (fprintf "not a fix; %t" fconstr))
  end.

Ltac2 unfold_fix_impl (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let unfolded := Std.eval_unfold [(fref, AllOccurrences)] fconstr in
  match Unsafe.kind unfolded with
  | Fix structs _i bs cs =>
    let body := Array.get cs 0 in
    let struct := Array.get structs 0 in
    let fix_b := Array.get bs 0 in
    let _fix_name := Option.get (Binder.name fix_b) in
    let body_bs := binders_of_constr_lambda body in
    let body_bs_names := List.map (fun b => Option.get (Binder.name b)) body_bs in
    let struct_name := List.nth body_bs_names struct in
    let res := in_contexts body_bs (fun () =>
      let outer_args := List.map Control.hyp body_bs_names in
      let fconstr_applied := apply_to_args fconstr outer_args in
      let rhs := fun () => Control.enter (fun () =>
        let ind_clause := {
          indcl_arg := (ElimOnIdent struct_name);
          indcl_eqn := None;
          indcl_as := None;
          indcl_in := None;
        } in
        Std.destruct false [ind_clause] None;
        Control.refine (fun () => open_constr:(_))
      ) in
      open_constr:($fconstr_applied = ltac2:(rhs ()))
    ) in
    let res := fun () => Std.eval_cbv beta (res ()) in
    let res := fun () => lambda_to_prod (res ()) in
    Control.refine res
  | _ =>
    Control.throw (Oopsie (fprintf "Wrong definition passed to unfold_tpe, namely %t" fconstr))
  end.

Ltac2 unfold_fix_gen (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let unfolded_fix_template := open_constr:(ltac2:(unfold_fix_impl fconstr)) in
  ltac1:(unfolded_fix_template |- instantiate(1 := unfolded_fix_template)) (Ltac1.of_constr unfolded_fix_template);
  let bs := collect_prod_binders_impl (Control.goal ()) in
  let nms := List.map (fun b => Fresh.in_goal (Option.get (Binder.name b))) bs in
  Std.intros false (List.map (fun nm => IntroNaming (IntroFresh nm)) nms);
  let struct_name := List.nth nms (struct_of_fix fconstr) in
  let struct_hyp := Control.hyp struct_name in
  destruct $struct_hyp;
  Control.enter (fun () =>
    unfold $fref; fold $fconstr;
    reflexivity ()
  ).

Ltac2 unfold_fix_type fn :=
  let unfolded := open_constr:(ltac2:(Control.enter (fun () => unfold_fix_gen fn))) in
  let t := Constr.type unfolded in
  Control.refine (fun () => open_constr:($t)).

Ltac2 unfold_fix_proof (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let bs := collect_prod_binders_impl (Control.goal ()) in
  let nms := List.map (fun b => Fresh.in_goal (Option.get (Binder.name b))) bs in
  Std.intros false (List.map (fun nm => IntroNaming (IntroFresh nm)) nms);
  let struct_name := List.nth nms (struct_of_fix fconstr) in
  let struct_hyp := Control.hyp struct_name in
  destruct $struct_hyp;
  Control.enter (fun () =>
    unfold $fref; fold $fconstr;
    reflexivity ()
  ).

Ltac2 rec var_ident_of_constr (c: constr): ident :=
  match Unsafe.kind c with
  | Var i => i
  | _ =>
    Control.throw (Oopsie (fprintf "Error: Expected the argument of a compiled function to be an variable reference, got: %t" c))
  end.

Ltac2 exactk (c: constr): unit -> unit :=
  fun () => exact $c.

(* The priority of lemmas is as follows: *)
(* 1: variables *)
(* 2: functions from f_lookup *)
(* 3: other automation lemmas *)
(*   3.1: functions *)
(*   3.2: dlet *)
(*   3.x: "normal" automation lemmas *)
(*   3.last: constants *)
Ltac2 rec compile () : unit :=
  let c := Control.goal () in
  lazy_match! c with
  | ?fenv |-- (_, _) ---> ([encode ?e], _) =>
    let cenv := get_cenv_from_fenv_constr fenv in
    let names_in_cenv := List.concat (List.map opt_to_list (List.map (fun p => Option.bind (fst p) (fun c => Ident.of_string (string_of_constr_string c))) cenv)) in
    printf "Compiling expression: %t with cenv %a" e (fun () cenv => message_of_cenv cenv) cenv;
    (* printf "Goal: %t" c; *)
    match List.find_opt (fun p => Constr.equal e (snd p)) cenv with
    | Some (name_constr_opt, _) =>
      (* Figure out why adding a default here as (open_constr:(_)) leaves hanging evars for polymorophic functions *)
      let name_constr := Option.get name_constr_opt in
      refine open_constr:(trans_Var
      (* env *) $fenv
      (* s *) _
      (* n *) $name_constr
      (* v *) $e
      (* FEnv.lookup *) ltac2:(eauto with fenvDb)
      )
    | None =>
      let compile_go () :=
        lazy_match! e with
        | (fun x => @?_f x) =>
          printf "POTENTIAL ERROR: trying to compile a function in the wild, namely %t" e;
          intro_then (Option.get (Ident.of_string "x_nm")) (fun _ =>
            compile ()
          )
        | (dlet ?val ?body) =>
          (* freshen based on names in cenv *)
          let binders_of_body := binders_names_of_constr_lambda body names_in_cenv in
          let let_n_constr := List.nth binders_of_body 0 in
          refine open_constr:(auto_let
          (* env *) $fenv
          (* x1 y1 *) _ _
          (* s1 s2 s3 *) _ _ _
          (* v1 *) $val
          (* let_n *) $let_n_constr
          (* f *) $body
          (* eval v1 *) ltac2:(Control.enter compile)
          (* eval f *) ltac2:(Control.enter (fun () => cbv beta; compile ()))
          )
        | (let x := ?val in @?body x) =>
          (* might work, but normal `let`s get inlined before (maybe because of the "cbv beta" after unfolding) *)
          let binders_of_body := binders_names_of_constr_lambda body names_in_cenv in
          let let_n_constr := List.nth binders_of_body 0 in
          refine open_constr:(auto_let
          (* env *) $fenv
          (* x1 y1 *) _ _
          (* s1 s2 s3 *) _ _ _
          (* v1 *) $val
          (* let_n *) $let_n_constr
          (* f *) $body
          (* eval v1 *) ltac2:(Control.enter compile)
          (* eval f *) ltac2:(Control.enter (fun () => cbv beta; compile ()))
          )
        (* char *)
        | (ascii_of_N (N_of_nat ?x)) =>
          app_lemma "auto_char_CHR" [("env", exactk fenv); ("x", exactk x)] [compile; exactk open_constr:(_)]
        | (nat_of_N (N_of_ascii ?x)) =>
          app_lemma "auto_char_ORD" [("env", exactk fenv); ("x", exactk x)] [compile]
        (* word *)
        | (@word.of_Z 4 _ (Z.of_nat ?x)) =>
          app_lemma "auto_word4_n2w" [("env", exactk fenv); ("x", exactk x)] [compile; exactk open_constr:(_)]
        | (@word.of_Z 64 _ (Z.of_nat ?x)) =>
          app_lemma "auto_word64_n2w" [("env", exactk fenv); ("x", exactk x)] [compile; exactk open_constr:(_)]
        | (Z.to_N (@word.unsigned 4 _ ?x)) =>
          app_lemma "auto_word4_w2n" [("env", exactk fenv); ("x", exactk x)] [compile]
        | (Z.to_N (@word.unsigned 64 _ ?x)) =>
          app_lemma "auto_word64_w2n" [("env", exactk fenv); ("x", exactk x)] [compile]
        (* nat *)
        | (?n1 + ?n2)%nat =>
          app_lemma "auto_nat_add"
            [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)]
            [compile; compile]
        | (?n1 - ?n2)%nat =>
          app_lemma "auto_nat_sub" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
        | (?n1 / ?n2)%nat =>
          app_lemma "auto_nat_div" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
        | (if Nat.eqb ?n1 ?n2 then ?t else ?f) =>
          app_lemma "auto_nat_if_eq"
            [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
            [compile; compile; compile; compile]
        | (if Nat.ltb ?n1 ?n2 then ?t else ?f) =>
          app_lemma "auto_nat_if_less"
            [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
            [compile; compile; compile; compile]
        | (match ?v0 with | 0 => ?v1 | S n' => @?v2 n' end) =>
          let binders_of_v2 := binders_names_of_constr_lambda v2 names_in_cenv in
          let n_constr := List.nth binders_of_v2 0 in
          app_lemma "auto_nat_case"
            [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2); ("n", exactk n_constr)]
            [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile))]
        (* list *)
        | [] =>
          app_lemma "auto_list_nil" [("env", exactk fenv); ("ra", (fun () => eauto))] []
        | (?x :: ?xs) =>
          app_lemma "auto_list_cons" [("env", exactk fenv); ("x", exactk x); ("xs", exactk xs)] [compile; compile]
        | (match ?v0 with | nil => ?v1 | h :: t => @?v2 h t end) =>
          let binders_of_v2 := binders_names_of_constr_lambda v2 names_in_cenv in
          let n1_constr := List.nth binders_of_v2 0 in
          let n2_constr := List.nth binders_of_v2 1 in
          app_lemma "auto_list_case"
            [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2); ("n1", exactk n1_constr); ("n2", exactk n2_constr)]
            [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile) ); (fun () => ())]
        (* option *)
        | None =>
          app_lemma "auto_option_none" [("env", exactk fenv)] []
        | (Some ?x) =>
          app_lemma "auto_option_some" [("env", exactk fenv); ("x", exactk x)] [compile]
        | (match ?v0 with | None => ?v1 | Some x => @?v2 x end) =>
          let binders_of_v2 := binders_names_of_constr_lambda v2 names_in_cenv in
          let n_constr := List.nth binders_of_v2 0 in
          app_lemma "auto_option_case"
            [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2); ("n", exactk n_constr)]
            [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile))]
        (* pair *)
        | (fst ?x) =>
          app_lemma "auto_pair_fst" [("env", exactk fenv); ("x", exactk x)] [compile]
        | (snd ?x) =>
          app_lemma "auto_pair_snd" [("env", exactk fenv); ("x", exactk x)] [compile]
        | (?x, ?y) =>
          app_lemma "auto_pair_cons" [("env", exactk fenv); ("x", exactk x); ("y", exactk y)] [compile; compile]
        | (match ?v0 with | (x, y) => @?v1 x y end) =>
          let binders_of_v1 := binders_names_of_constr_lambda v1 names_in_cenv in
          let n1_constr := List.nth binders_of_v1 0 in
          let n2_constr := List.nth binders_of_v1 1 in
          app_lemma "auto_pair_case"
            [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("n1", exactk n1_constr); ("n2", exactk n2_constr)]
            [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile)); (fun () => ())]
        (* app_list *)
        | List ?xs =>
          app_lemma "auto_app_list_cons_List" [("env", exactk fenv); ("xs", exactk xs)] [compile]
        | Append ?l1 ?l2 =>
          app_lemma "auto_app_list_cons_Append" [("env", exactk fenv); ("l1", exactk l1); ("l2", exactk l2)] [compile; compile]
        | (match ?v0 with
           | List xs => @?f_List xs
           | Append l1 l2 => @?f_Append l1 l2
           end) =>
          let binders_f_List := binders_names_of_constr_lambda f_List names_in_cenv in
          let binders_f_Append := binders_names_of_constr_lambda f_Append names_in_cenv in
          let n1 := List.nth binders_f_List 0 in
          let n2 := List.nth binders_f_Append 0 in
          let n3 := List.nth binders_f_Append 1 in
          app_lemma "auto_app_list_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                           ("f_List", exactk f_List); ("f_Append", exactk f_Append);
                                           ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3)]
                                         [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile)); (fun () => ())]
        (* cmp *)
        | ImpSyntax.Less =>
          app_lemma "auto_cmp_cons_Less" [("env", exactk fenv)] []
        | ImpSyntax.Equal =>
          app_lemma "auto_cmp_cons_Equal" [("env", exactk fenv)] []
        | (match ?v0 with | ImpSyntax.Less => ?f_Less | ImpSyntax.Equal => ?f_Equal end) =>
          app_lemma "auto_cmp_CASE" [("env", exactk fenv); ("v0", exactk v0); ("f_Less", exactk f_Less); ("f_Equal", exactk f_Equal)]
                                    [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile))]
        (* cmd *)
        | ImpSyntax.Skip =>
          app_lemma "auto_cmd_cons_Skip" [("env", exactk fenv)] []
        | ImpSyntax.Seq ?c1 ?c2 =>
          app_lemma "auto_cmd_cons_Seq" [("env", exactk fenv); ("c1", exactk c1); ("c2", exactk c2)] [compile; compile]
        | ImpSyntax.Assign ?n ?e =>
          app_lemma "auto_cmd_cons_Assign" [("env", exactk fenv); ("n", exactk n); ("e", exactk e)] [compile; compile]
        | ImpSyntax.Update ?a ?e ?e' =>
          app_lemma "auto_cmd_cons_Update" [("env", exactk fenv); ("a", exactk a); ("e", exactk e); ("e'", exactk e')] [compile; compile; compile]
        | ImpSyntax.If ?t ?c1 ?c2 =>
          app_lemma "auto_cmd_cons_If" [("env", exactk fenv); ("t", exactk t); ("c1", exactk c1); ("c2", exactk c2)] [compile; compile; compile]
        | ImpSyntax.While ?t ?c =>
          app_lemma "auto_cmd_cons_While" [("env", exactk fenv); ("t", exactk t); ("c", exactk c)] [compile; compile]
        | ImpSyntax.Call ?n ?f ?es =>
          app_lemma "auto_cmd_cons_Call" [("env", exactk fenv); ("n", exactk n); ("f", exactk f); ("es", exactk es)] [compile; compile; compile]
        | ImpSyntax.Return ?e =>
          app_lemma "auto_cmd_cons_Return" [("env", exactk fenv); ("e", exactk e)] [compile]
        | ImpSyntax.Alloc ?n ?e =>
          app_lemma "auto_cmd_cons_Alloc" [("env", exactk fenv); ("n", exactk n); ("e", exactk e)] [compile; compile]
        | ImpSyntax.GetChar ?n =>
          app_lemma "auto_cmd_cons_GetChar" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ImpSyntax.PutChar ?e =>
          app_lemma "auto_cmd_cons_PutChar" [("env", exactk fenv); ("e", exactk e)] [compile]
        | ImpSyntax.Abort =>
          app_lemma "auto_cmd_cons_Abort" [("env", exactk fenv)] []
        | (match ?v0 with
           | ImpSyntax.Skip => ?f_Skip
           | ImpSyntax.Seq c1 c2 => @?f_Seq c1 c2
           | ImpSyntax.Assign n e => @?f_Assign n e
           | ImpSyntax.Update a e e' => @?f_Update a e e'
           | ImpSyntax.If t c1 c2 => @?f_If t c1 c2
           | ImpSyntax.While t c => @?f_While t c
           | ImpSyntax.Call n f es => @?f_Call n f es
           | ImpSyntax.Return e => @?f_Return e
           | ImpSyntax.Alloc n e => @?f_Alloc n e
           | ImpSyntax.GetChar n => @?f_GetChar n
           | ImpSyntax.PutChar e => @?f_PutChar e
           | ImpSyntax.Abort => ?f_Abort
           end) =>
          let binders_f_Seq := binders_names_of_constr_lambda f_Seq names_in_cenv in
          let binders_f_Assign := binders_names_of_constr_lambda f_Assign names_in_cenv in
          let binders_f_Update := binders_names_of_constr_lambda f_Update names_in_cenv in
          let binders_f_If := binders_names_of_constr_lambda f_If names_in_cenv in
          let binders_f_While := binders_names_of_constr_lambda f_While names_in_cenv in
          let binders_f_Call := binders_names_of_constr_lambda f_Call names_in_cenv in
          let binders_f_Return := binders_names_of_constr_lambda f_Return names_in_cenv in
          let binders_f_Alloc := binders_names_of_constr_lambda f_Alloc names_in_cenv in
          let binders_f_GetChar := binders_names_of_constr_lambda f_GetChar names_in_cenv in
          let binders_f_PutChar := binders_names_of_constr_lambda f_PutChar names_in_cenv in
          let n1 := List.nth binders_f_Seq 0 in
          let n2 := List.nth binders_f_Seq 1 in
          let n3 := List.nth binders_f_Assign 0 in
          let n4 := List.nth binders_f_Assign 1 in
          let n5 := List.nth binders_f_Update 0 in
          let n6 := List.nth binders_f_Update 1 in
          let n7 := List.nth binders_f_Update 2 in
          let n8 := List.nth binders_f_If 0 in
          let n9 := List.nth binders_f_If 1 in
          let n10 := List.nth binders_f_If 2 in
          let n11 := List.nth binders_f_While 0 in
          let n12 := List.nth binders_f_While 1 in
          let n13 := List.nth binders_f_Call 0 in
          let n14 := List.nth binders_f_Call 1 in
          let n15 := List.nth binders_f_Call 2 in
          let n16 := List.nth binders_f_Return 0 in
          let n17 := List.nth binders_f_Alloc 0 in
          let n18 := List.nth binders_f_Alloc 1 in
          let n19 := List.nth binders_f_GetChar 0 in
          let n20 := List.nth binders_f_PutChar 0 in
          app_lemma "auto_cmd_CASE"
            [("env", exactk fenv); ("v0", exactk v0);
              ("f_Skip", exactk f_Skip); ("f_Seq", exactk f_Seq); ("f_Assign", exactk f_Assign); ("f_Update", exactk f_Update);
              ("f_If", exactk f_If); ("f_While", exactk f_While); ("f_Call", exactk f_Call); ("f_Return", exactk f_Return);
              ("f_Alloc", exactk f_Alloc); ("f_GetChar", exactk f_GetChar); ("f_PutChar", exactk f_PutChar); ("f_Abort", exactk f_Abort);
              ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3); ("n4", exactk n4);
              ("n5", exactk n5); ("n6", exactk n6); ("n7", exactk n7); ("n8", exactk n8);
              ("n9", exactk n9); ("n10", exactk n10); ("n11", exactk n11); ("n12", exactk n12);
              ("n13", exactk n13); ("n14", exactk n14); ("n15", exactk n15); ("n16", exactk n16);
              ("n17", exactk n17); ("n18", exactk n18); ("n19", exactk n19); ("n20", exactk n20)]
            [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile));
              (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ())]
        (* cond *)
        | ASMSyntax.Always =>
          app_lemma "auto_cond_cons_Always" [("env", exactk fenv)] []
        | ASMSyntax.Less ?r1 ?r2 =>
          app_lemma "auto_cond_cons_Less" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | ASMSyntax.Equal ?r1 ?r2 =>
          app_lemma "auto_cond_cons_Equal" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | (match ?v0 with
           | ASMSyntax.Always => ?v1
           | ASMSyntax.Less r1 r2 => @?v2 r1 r2
           | ASMSyntax.Equal r1 r2 => @?v3 r1 r2
           end) =>
          let binders_v2 := binders_names_of_constr_lambda v2 names_in_cenv in
          let binders_v3 := binders_names_of_constr_lambda v3 names_in_cenv in
          let n1 := List.nth binders_v2 0 in
          let n2 := List.nth binders_v2 1 in
          let n3 := List.nth binders_v3 0 in
          let n4 := List.nth binders_v3 1 in
          app_lemma "auto_cond_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                       ("v1", exactk v1); ("v2", exactk v2); ("v3", exactk v3);
                                       ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3); ("n4", exactk n4)]
                                     [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile)); (fun () => ()); (fun () => ()); (fun () => ())]
        (* exp *)
        | ImpSyntax.Var ?n =>
          app_lemma "auto_exp_cons_Var" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ImpSyntax.Const ?n =>
          app_lemma "auto_exp_cons_Const" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ImpSyntax.Add ?e1 ?e2 =>
          app_lemma "auto_exp_cons_Add" [("env", exactk fenv); ("e1", exactk e1); ("e2", exactk e2)] [compile; compile]
        | ImpSyntax.Sub ?e1 ?e2 =>
          app_lemma "auto_exp_cons_Sub" [("env", exactk fenv); ("e1", exactk e1); ("e2", exactk e2)] [compile; compile]
        | ImpSyntax.Div ?e1 ?e2 =>
          app_lemma "auto_exp_cons_Div" [("env", exactk fenv); ("e1", exactk e1); ("e2", exactk e2)] [compile; compile]
        | ImpSyntax.Read ?e1 ?e2 =>
          app_lemma "auto_exp_cons_Read" [("env", exactk fenv); ("e1", exactk e1); ("e2", exactk e2)] [compile; compile]
        | (match ?v0 with
           | ImpSyntax.Var n => @?f_Var n
           | ImpSyntax.Const n => @?f_Const n
           | ImpSyntax.Add e1 e2 => @?f_Add e1 e2
           | ImpSyntax.Sub e1 e2 => @?f_Sub e1 e2
           | ImpSyntax.Div e1 e2 => @?f_Div e1 e2
           | ImpSyntax.Read e1 e2 => @?f_Read e1 e2
           end) =>
          let binders_f_Var := binders_names_of_constr_lambda f_Var names_in_cenv in
          let binders_f_Const := binders_names_of_constr_lambda f_Const names_in_cenv in
          let binders_f_Add := binders_names_of_constr_lambda f_Add names_in_cenv in
          let binders_f_Sub := binders_names_of_constr_lambda f_Sub names_in_cenv in
          let binders_f_Div := binders_names_of_constr_lambda f_Div names_in_cenv in
          let binders_f_Read := binders_names_of_constr_lambda f_Read names_in_cenv in
          let n1 := List.nth binders_f_Var 0 in
          let n2 := List.nth binders_f_Const 0 in
          let n3 := List.nth binders_f_Add 0 in
          let n4 := List.nth binders_f_Add 1 in
          let n5 := List.nth binders_f_Sub 0 in
          let n6 := List.nth binders_f_Sub 1 in
          let n7 := List.nth binders_f_Div 0 in
          let n8 := List.nth binders_f_Div 1 in
          let n9 := List.nth binders_f_Read 0 in
          let n10 := List.nth binders_f_Read 1 in
          app_lemma "auto_exp_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                      ("f_Var", exactk f_Var); ("f_Const", exactk f_Const); ("f_Add", exactk f_Add);
                                      ("f_Sub", exactk f_Sub); ("f_Div", exactk f_Div); ("f_Read", exactk f_Read);
                                      ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3);
                                      ("n4", exactk n4); ("n5", exactk n5); ("n6", exactk n6);
                                      ("n7", exactk n7); ("n8", exactk n8); ("n9", exactk n9);
                                      ("n10", exactk n10)]
                                    [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile)); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ())]
        (* func *)
        | ImpSyntax.Func ?n ?params ?body =>
          app_lemma "auto_func_cons_Func" [("env", exactk fenv); ("n", exactk n); ("params", exactk params); ("body", exactk body)] [compile; compile; compile]
        | (match ?v0 with | ImpSyntax.Func n params body => @?f_Func n params body end) =>
          let binders_f_Func := binders_names_of_constr_lambda f_Func names_in_cenv in
          let n1 := List.nth binders_f_Func 0 in
          let n2 := List.nth binders_f_Func 1 in
          let n3 := List.nth binders_f_Func 2 in
          app_lemma "auto_func_CASE"
            [("env", exactk fenv); ("v0", exactk v0); ("f_Func", exactk f_Func);
              ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3)]
            [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile)); (fun () => ())]
        (* instr *)
        | ASMSyntax.Const ?r ?w =>
          app_lemma "auto_instr_cons_Const" [("env", exactk fenv); ("r", exactk r); ("w", exactk w)] [compile; compile]
        | ASMSyntax.Add ?r1 ?r2 =>
          app_lemma "auto_instr_cons_Add" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | ASMSyntax.Sub ?r1 ?r2 =>
          app_lemma "auto_instr_cons_Sub" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | ASMSyntax.Div ?r =>
          app_lemma "auto_instr_cons_Div" [("env", exactk fenv); ("r", exactk r)] [compile]
        | ASMSyntax.Jump ?c ?n =>
          app_lemma "auto_instr_cons_Jump" [("env", exactk fenv); ("c", exactk c); ("n", exactk n)] [compile; compile]
        | ASMSyntax.Call ?n =>
          app_lemma "auto_instr_cons_Call" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ASMSyntax.Mov ?r1 ?r2 =>
          app_lemma "auto_instr_cons_Mov" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | ASMSyntax.Ret =>
          app_lemma "auto_instr_cons_Ret" [("env", exactk fenv)] []
        | ASMSyntax.Pop ?r =>
          app_lemma "auto_instr_cons_Pop" [("env", exactk fenv); ("r", exactk r)] [compile]
        | ASMSyntax.Push ?r =>
          app_lemma "auto_instr_cons_Push" [("env", exactk fenv); ("r", exactk r)] [compile]
        | ASMSyntax.Add_RSP ?n =>
          app_lemma "auto_instr_cons_Add_RSP" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ASMSyntax.Sub_RSP ?n =>
          app_lemma "auto_instr_cons_Sub_RSP" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ASMSyntax.Load_RSP ?r ?n =>
          app_lemma "auto_instr_cons_Load_RSP" [("env", exactk fenv); ("r", exactk r); ("n", exactk n)] [compile; compile]
        | ASMSyntax.Store_RSP ?r ?n =>
          app_lemma "auto_instr_cons_Store_RSP" [("env", exactk fenv); ("r", exactk r); ("n", exactk n)] [compile; compile]
        | ASMSyntax.Load ?r1 ?r2 ?w =>
          app_lemma "auto_instr_cons_Load" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2); ("w", exactk w)] [compile; compile; compile]
        | ASMSyntax.Store ?r1 ?r2 ?w =>
          app_lemma "auto_instr_cons_Store" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2); ("w", exactk w)] [compile; compile; compile]
        | ASMSyntax.GetChar =>
          app_lemma "auto_instr_cons_GetChar" [("env", exactk fenv)] []
        | ASMSyntax.PutChar =>
          app_lemma "auto_instr_cons_PutChar" [("env", exactk fenv)] []
        | ASMSyntax.Exit =>
          app_lemma "auto_instr_cons_Exit" [("env", exactk fenv)] []
        | ASMSyntax.Comment ?str =>
          app_lemma "auto_instr_cons_Comment" [("env", exactk fenv); ("str", exactk str)] [compile]
        | (match ?v0 with
           | ASMSyntax.Const r w => @?v1 r w
           | ASMSyntax.Add r1 r2 => @?v2 r1 r2
           | ASMSyntax.Sub r1 r2 => @?v3 r1 r2
           | ASMSyntax.Div r => @?v4 r
           | ASMSyntax.Jump c n => @?v5 c n
           | ASMSyntax.Call n => @?v6 n
           | ASMSyntax.Mov r1 r2 => @?v7 r1 r2
           | ASMSyntax.Ret => ?v8
           | ASMSyntax.Pop r => @?v9 r
           | ASMSyntax.Push r => @?v10 r
           | ASMSyntax.Add_RSP n => @?v11 n
           | ASMSyntax.Sub_RSP n => @?v12 n
           | ASMSyntax.Load_RSP r n => @?v13 r n
           | ASMSyntax.Store_RSP r n => @?v14 r n
           | ASMSyntax.Load r1 r2 w => @?v15 r1 r2 w
           | ASMSyntax.Store r1 r2 w => @?v16 r1 r2 w
           | ASMSyntax.GetChar => ?v17
           | ASMSyntax.PutChar => ?v18
           | ASMSyntax.Exit => ?v19
           | ASMSyntax.Comment s => @?v20 s
           end) =>
          let binders_v1 := binders_names_of_constr_lambda v1 names_in_cenv in
          let binders_v2 := binders_names_of_constr_lambda v2 names_in_cenv in
          let binders_v3 := binders_names_of_constr_lambda v3 names_in_cenv in
          let binders_v4 := binders_names_of_constr_lambda v4 names_in_cenv in
          let binders_v5 := binders_names_of_constr_lambda v5 names_in_cenv in
          let binders_v6 := binders_names_of_constr_lambda v6 names_in_cenv in
          let binders_v7 := binders_names_of_constr_lambda v7 names_in_cenv in
          let binders_v9 := binders_names_of_constr_lambda v9 names_in_cenv in
          let binders_v10 := binders_names_of_constr_lambda v10 names_in_cenv in
          let binders_v11 := binders_names_of_constr_lambda v11 names_in_cenv in
          let binders_v12 := binders_names_of_constr_lambda v12 names_in_cenv in
          let binders_v13 := binders_names_of_constr_lambda v13 names_in_cenv in
          let binders_v14 := binders_names_of_constr_lambda v14 names_in_cenv in
          let binders_v15 := binders_names_of_constr_lambda v15 names_in_cenv in
          let binders_v16 := binders_names_of_constr_lambda v16 names_in_cenv in
          let binders_v20 := binders_names_of_constr_lambda v20 names_in_cenv in
          let n1 := List.nth binders_v1 0 in
          let n2 := List.nth binders_v1 1 in
          let n3 := List.nth binders_v2 0 in
          let n4 := List.nth binders_v2 1 in
          let n5 := List.nth binders_v3 0 in
          let n6 := List.nth binders_v3 1 in
          let n7 := List.nth binders_v4 0 in
          let n8 := List.nth binders_v5 0 in
          let n9 := List.nth binders_v5 1 in
          let n10 := List.nth binders_v6 0 in
          let n11 := List.nth binders_v7 0 in
          let n12 := List.nth binders_v7 1 in
          let n13 := List.nth binders_v9 0 in
          let n14 := List.nth binders_v10 0 in
          let n15 := List.nth binders_v11 0 in
          let n16 := List.nth binders_v12 0 in
          let n17 := List.nth binders_v13 0 in
          let n18 := List.nth binders_v13 1 in
          let n19 := List.nth binders_v14 0 in
          let n20 := List.nth binders_v14 1 in
          let n21 := List.nth binders_v15 0 in
          let n22 := List.nth binders_v15 1 in
          let n23 := List.nth binders_v15 2 in
          let n24 := List.nth binders_v16 0 in
          let n25 := List.nth binders_v16 1 in
          let n26 := List.nth binders_v16 2 in
          let n27 := List.nth binders_v20 0 in
          app_lemma "auto_instr_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                        ("v1", exactk v1); ("v2", exactk v2); ("v3", exactk v3); ("v4", exactk v4);
                                        ("v5", exactk v5); ("v6", exactk v6); ("v7", exactk v7); ("v8", exactk v8);
                                        ("v9", exactk v9); ("v10", exactk v10); ("v11", exactk v11); ("v12", exactk v12);
                                        ("v13", exactk v13); ("v14", exactk v14); ("v15", exactk v15); ("v16", exactk v16);
                                        ("v17", exactk v17); ("v18", exactk v18); ("v19", exactk v19); ("v20", exactk v20);
                                        ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3); ("n4", exactk n4);
                                        ("n5", exactk n5); ("n6", exactk n6); ("n7", exactk n7); ("n8", exactk n8);
                                        ("n9", exactk n9); ("n10", exactk n10); ("n11", exactk n11); ("n12", exactk n12);
                                        ("n13", exactk n13); ("n14", exactk n14); ("n15", exactk n15); ("n16", exactk n16);
                                        ("n17", exactk n17); ("n18", exactk n18); ("n19", exactk n19); ("n20", exactk n20);
                                        ("n21", exactk n21); ("n22", exactk n22); ("n23", exactk n23); ("n24", exactk n24);
                                        ("n25", exactk n25); ("n26", exactk n26); ("n27", exactk n27)]
                                       [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile)); (fun () => ()); (fun () => ());
                                        (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ());
                                        (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ());
                                        (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ());
                                        (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ())]
        (* prog *)
        | ImpSyntax.Program ?funcs =>
          app_lemma "auto_prog_cons_Program" [("env", exactk fenv); ("funcs", exactk funcs)] [compile]
        | (match ?v0 with | ImpSyntax.Program funcs => @?f_Program funcs end) =>
          let binders_f_Program := binders_names_of_constr_lambda f_Program names_in_cenv in
          let n1 := List.nth binders_f_Program 0 in
          app_lemma "auto_prog_CASE"
            [("env", exactk fenv); ("v0", exactk v0); ("f_Program", exactk f_Program); ("n1", exactk n1)]
            [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile))]
        (* reg *)
        | ASMSyntax.RAX =>
          app_lemma "auto_reg_cons_RAX" [("env", exactk fenv)] []
        | ASMSyntax.RDI =>
          app_lemma "auto_reg_cons_RDI" [("env", exactk fenv)] []
        | ASMSyntax.RBX =>
          app_lemma "auto_reg_cons_RBX" [("env", exactk fenv)] []
        | ASMSyntax.RBP =>
          app_lemma "auto_reg_cons_RBP" [("env", exactk fenv)] []
        | ASMSyntax.R12 =>
          app_lemma "auto_reg_cons_R12" [("env", exactk fenv)] []
        | ASMSyntax.R13 =>
          app_lemma "auto_reg_cons_R13" [("env", exactk fenv)] []
        | ASMSyntax.R14 =>
          app_lemma "auto_reg_cons_R14" [("env", exactk fenv)] []
        | ASMSyntax.R15 =>
          app_lemma "auto_reg_cons_R15" [("env", exactk fenv)] []
        | ASMSyntax.RDX =>
          app_lemma "auto_reg_cons_RDX" [("env", exactk fenv)] []
        | ASMSyntax.R14 =>
          app_lemma "auto_reg_cons_R14" [("env", exactk fenv)] []
        | ASMSyntax.R15 =>
          app_lemma "auto_reg_cons_R15" [("env", exactk fenv)] []
        | ASMSyntax.RDX =>
          app_lemma "auto_reg_cons_RDX" [("env", exactk fenv)] []
        | (match ?v0 with
           | ASMSyntax.RAX => ?v1 | ASMSyntax.RDI => ?v2 | ASMSyntax.RBX => ?v3
           | ASMSyntax.RBP => ?v4 | ASMSyntax.R12 => ?v5 | ASMSyntax.R13 => ?v6
           | ASMSyntax.R14 => ?v7 | ASMSyntax.R15 => ?v8 | ASMSyntax.RDX => ?v9
           end) =>
          app_lemma "auto_reg_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                      ("v1", exactk v1); ("v2", exactk v2); ("v3", exactk v3);
                                      ("v4", exactk v4); ("v5", exactk v5); ("v6", exactk v6);
                                      ("v7", exactk v7); ("v8", exactk v8); ("v9", exactk v9)]
                                    [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile))]
        (* test *)
        | ImpSyntax.Test ?c ?e1 ?e2 =>
          app_lemma "auto_test_cons_Test" [("env", exactk fenv); ("c", exactk c); ("e1", exactk e1); ("e2", exactk e2)] [compile; compile; compile]
        | ImpSyntax.And ?t1 ?t2 =>
          app_lemma "auto_test_cons_And" [("env", exactk fenv); ("t1", exactk t1); ("t2", exactk t2)] [compile; compile]
        | ImpSyntax.Or ?t1 ?t2 =>
          app_lemma "auto_test_cons_Or" [("env", exactk fenv); ("t1", exactk t1); ("t2", exactk t2)] [compile; compile]
        | ImpSyntax.Not ?t =>
          app_lemma "auto_test_cons_Not" [("env", exactk fenv); ("t", exactk t)] [compile]
        | (match ?v0 with
           | ImpSyntax.Test c e1 e2 => @?f_Test c e1 e2
           | ImpSyntax.And t1 t2 => @?f_And t1 t2
           | ImpSyntax.Or t1 t2 => @?f_Or t1 t2
           | ImpSyntax.Not t => @?f_Not t
           end) =>
          let binders_f_Test := binders_names_of_constr_lambda f_Test names_in_cenv in
          let binders_f_And := binders_names_of_constr_lambda f_And names_in_cenv in
          let binders_f_Or := binders_names_of_constr_lambda f_Or names_in_cenv in
          let binders_f_Not := binders_names_of_constr_lambda f_Not names_in_cenv in
          let n1 := List.nth binders_f_Test 0 in
          let n2 := List.nth binders_f_Test 1 in
          let n3 := List.nth binders_f_Test 2 in
          let n4 := List.nth binders_f_And 0 in
          let n5 := List.nth binders_f_And 1 in
          let n6 := List.nth binders_f_Or 0 in
          let n7 := List.nth binders_f_Or 1 in
          let n8 := List.nth binders_f_Not 0 in
          app_lemma "auto_test_CASE"
            [("env", exactk fenv); ("v0", exactk v0);
              ("f_Test", exactk f_Test); ("f_And", exactk f_And); ("f_Or", exactk f_Or); ("f_Not", exactk f_Not);
              ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3);
              ("n4", exactk n4); ("n5", exactk n5); ("n6", exactk n6);
              ("n7", exactk n7); ("n8", exactk n8)]
            [compile; (fun () => destruct $v0 eqn:?; (Control.enter compile)); (fun () => ()); (fun () => ()); (fun () => ())]
        (* cond *)
        | ASMSyntax.Always =>
          app_lemma "auto_cond_cons_Always" [("env", exactk fenv)] []
        | ASMSyntax.Less ?r1 ?r2 =>
          app_lemma "auto_cond_cons_Less" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | ASMSyntax.Equal ?r1 ?r2 =>
          app_lemma "auto_cond_cons_Equal" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        (* instr *)
        | ASMSyntax.Const ?r ?w =>
          app_lemma "auto_instr_cons_Const" [("env", exactk fenv); ("r", exactk r); ("w", exactk w)] [compile; compile]
        | ASMSyntax.Add ?r1 ?r2 =>
          app_lemma "auto_instr_cons_Add" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | ASMSyntax.Sub ?r1 ?r2 =>
          app_lemma "auto_instr_cons_Sub" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | ASMSyntax.Div ?r =>
          app_lemma "auto_instr_cons_Div" [("env", exactk fenv); ("r", exactk r)] [compile]
        | ASMSyntax.Jump ?c ?n =>
          app_lemma "auto_instr_cons_Jump" [("env", exactk fenv); ("c", exactk c); ("n", exactk n)] [compile; compile]
        | ASMSyntax.Call ?n =>
          app_lemma "auto_instr_cons_Call" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ASMSyntax.Mov ?r1 ?r2 =>
          app_lemma "auto_instr_cons_Mov" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
        | ASMSyntax.Ret =>
          app_lemma "auto_instr_cons_Ret" [("env", exactk fenv)] []
        | ASMSyntax.Pop ?r =>
          app_lemma "auto_instr_cons_Pop" [("env", exactk fenv); ("r", exactk r)] [compile]
        | ASMSyntax.Push ?r =>
          app_lemma "auto_instr_cons_Push" [("env", exactk fenv); ("r", exactk r)] [compile]
        | ASMSyntax.Add_RSP ?n =>
          app_lemma "auto_instr_cons_Add_RSP" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ASMSyntax.Sub_RSP ?n =>
          app_lemma "auto_instr_cons_Sub_RSP" [("env", exactk fenv); ("n", exactk n)] [compile]
        | ASMSyntax.Load_RSP ?r ?n =>
          app_lemma "auto_instr_cons_Load_RSP" [("env", exactk fenv); ("r", exactk r); ("n", exactk n)] [compile; compile]
        | ASMSyntax.Store_RSP ?r ?n =>
          app_lemma "auto_instr_cons_Store_RSP" [("env", exactk fenv); ("r", exactk r); ("n", exactk n)] [compile; compile]
        | ASMSyntax.Load ?r1 ?r2 ?w =>
          app_lemma "auto_instr_cons_Load" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2); ("w", exactk w)] [compile; compile; compile]
        | ASMSyntax.Store ?r1 ?r2 ?w =>
          app_lemma "auto_instr_cons_Store" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2); ("w", exactk w)] [compile; compile; compile]
        | ASMSyntax.GetChar =>
          app_lemma "auto_instr_cons_GetChar" [("env", exactk fenv)] []
        | ASMSyntax.PutChar =>
          app_lemma "auto_instr_cons_PutChar" [("env", exactk fenv)] []
        | ASMSyntax.Exit =>
          app_lemma "auto_instr_cons_Exit" [("env", exactk fenv)] []
        | ASMSyntax.Comment ?s =>
          app_lemma "auto_instr_cons_Comment" [("env", exactk fenv); ("s", exactk s)] [compile]
        (* bool *)
        | true =>
          app_lemma "auto_bool_T" [("env", exactk fenv)] []
        | false =>
          app_lemma "auto_bool_F" [("env", exactk fenv)] []
        | (negb ?b) =>
          app_lemma "auto_bool_not" [("env", exactk fenv); ("b", exactk b)] [compile]
        | (andb ?bA ?bB) =>
          app_lemma "auto_bool_and" [("env", exactk fenv); ("bA", exactk bA); ("bB", exactk bB)] [compile; compile]
        | (Bool.eqb ?bA ?bB) =>
          app_lemma "auto_bool_iff" [("env", exactk fenv); ("bA", exactk bA); ("bB", exactk bB)] [compile; compile]
        | (if ?b then ?t else ?f) =>
          app_lemma "last_bool_if" [("env", exactk fenv); ("b", exactk b); ("t", exactk t); ("f", exactk f)]
                                   [compile; compile; compile]
        (* TODO: see if we can use pairs (name -> tactic/term) *)
        (*       End-goal: extesible table of all compilation lemmas -> (name, tactic to apply) *)
        (*       We can use names to have subsets of tactics (e.g. arithmetic only) *)
        (* const *)
        | ?n =>
          if proper_const n then
            if Constr.equal (Constr.type n) constr:(nat) then
              app_lemma "auto_nat_const" [("env", exactk fenv); ("n", exactk n)] []
            else if Constr.equal (Constr.type n) constr:(string) then
              app_lemma "auto_string_const" [("env", exactk fenv); ("str", exactk n)] []
            else if Constr.equal (Constr.type n) constr:(ascii) then
              app_lemma "auto_char_const" [("env", exactk fenv); ("chr", exactk n)] []
            else
              Control.throw (Oopsie (fprintf
                "Error: Tried to compile a constant of unsupported type: namely: %t of type %t"
                n
                (Constr.type n)
              ))
          else
            Control.throw (Oopsie (fprintf
              "Error: Tried to compile a non-constant expression %t as a constant expression (%s kind)"
              n
              (kind_string_of_constr n)
            ))
        end
      in
      match extract_fun e with
      | None =>
        compile_go ()
      | Some (f, args) =>
        (* A function application *)
        let args := List.filter (fun c => Bool.neg (constr_is_sort (Constr.type c))) args in
        let f_lookup := get_f_lookup_from_hyps () in
        let fname_opt := fname_if_in_f_lookup f_lookup f in
        match fname_opt with
        | Some fname =>
          (* Existing function that is in f_lookup (currently – in premises) *)
          let args_constr := list_to_constr_encode args in
          let fname_str := constr_string_of_string fname in
          printf "applying trans_Call with fname := %t and args := %t" fname_str args_constr;
          refine open_constr:(trans_Call
          (* env *) $fenv
          (* xs *) _
          (* s1 s2 s3 *) _ _ _
          (* fname *) (name_enc $fname_str)
          (* vs *) $args_constr
          (* v *) (encode $e)
          (* eval args *) ltac2:(Control.enter compile)
          (* eval_app *) ltac2:(eauto)
          )
        | _ =>
          compile_go ()
        end
      end
    end
  | ?fenv |-- (_, _) ---> ([], _) =>
    app_lemma "trans_nil" [("env", exactk fenv)] []
  | ?fenv |-- (_, _) ---> (?e :: ?es, _) =>
    refine open_constr:(trans_cons
    (* env *) $fenv
    (* x *) _
    (* xs *) _
    (* v *) $e
    (* vs *) $es
    (* s s1 s2 *) _ _ _
    (* eval x *) ltac2:(Control.enter compile)
    (* eval xs *) ltac2:(Control.enter compile)
    )
  | _ =>
    Control.throw (Oopsie (fprintf "Error: Malformed input to compile, namely %t" c))
  end.

Ltac2 rec has_make_env (c: constr): bool :=
  match! c with
  | (FEnv.insert _ ?c) => has_make_env c
  | make_env _ _ _ => true
  | _ => false
  end.

Ltac2 unfold_ref_everywhere (r: reference): unit :=
  let cl := default_on_concl None in
  Std.unfold [(r, AllOccurrences)] cl.

Ltac2 opt_is_empty (opt: 'a option): bool :=
  match opt with
  | None => true
  | _ => false
  end.

Ltac2 rec index_of (i: ident) (l: ident list): int option :=
  match l with
  | [] => None
  | j :: l =>
    if Ident.equal i j then Some 0
    else Option.map (Int.add 1) (index_of i l)
  end.

(* Top level tactic that compiles a program into FunLang *)
(* Handles expression evaluation and function evaluation as goals *)
Ltac2 rec docompile () :=
  (* printf "docompile goal: = %t" (Control.goal ()); *)
  lazy_match! goal with
  | [ |- _ |-- (_, _) ---> ([encode _], _) ] =>
    (* let cenv := get_cenv_from_fenv_constr fenv in *)
    compile ()
  | [ h : (lookup_fun (name_enc ?fname) _ = Some (?params, _))
  |- eval_app (name_enc ?fname) ?args _ (encode ?c, _) ] =>
    let h_hyp := Control.hyp h in
    (* let f_lookup := get_f_lookup_from_hyps () in *)
    (* let argsl := constr_list_of_encode_constr args in *)
    match extract_fun c with
    (* function reference --> unfold *)
    | Some (fconstr, fargs) =>
      let cname_ref := reference_of_constr_opt fconstr in
      (if opt_is_empty cname_ref then
        Control.throw (Oopsie (fprintf "Error: Expected a named function application, got: %t" fconstr))
      else ());
      let cname_ref := Option.get cname_ref in
      let cname_str := (Option.get (reference_to_string cname_ref)) in
      let fname_str := (string_of_constr_string fname) in
      (*  Check if the encoded name is the same as the compiled top level function *)
      if String.equal fname_str cname_str then
        (* If its a fixpoint apply `fname_equation`, otherwise unfold `fname` *)
        (if isFix fconstr then
          let all_fargs_ids := List.map var_ident_of_constr fargs in
          let non_type_fargs_ids := List.map var_ident_of_constr (List.filter (fun c => Bool.neg (constr_is_sort (Constr.type c))) fargs) in
          Std.revert non_type_fargs_ids;
          let struct_idx := struct_of_fix fconstr in
          let struct_id := List.nth all_fargs_ids struct_idx in
          let new_struct_idx := Option.get (index_of struct_id non_type_fargs_ids) in
          let hname := Fresh.in_goal (Option.get (Ident.of_string "IH")) in
          Std.fix_ hname (Int.add new_struct_idx 1);
          intros;
          rewrite_with_equation fconstr
        else
          unfold_ref_everywhere cname_ref
        );
        docompile ()
      else (
        refine open_constr:(trans_app
        (* n *) $fname
        (* params *) $params
        (* vs *) $args
        (* body *) _
        (* s *) _
        (* s1 *) _
        (* v *) (encode $c)
        (* eval body *) ltac2:(Control.enter docompile)
        (* params length eq *) _
        (* lookup_fun *) $h_hyp
        )
      )
    (* unfolded function --> just compile *)
    | None =>
      refine open_constr:(trans_app
      (* n *) $fname
      (* params *) $params
      (* vs *) $args
      (* body *) _
      (* s *) _
      (* s1 *) _
      (* v *) (encode $c)
      (* eval body *) ltac2:(Control.enter docompile)
      (* params length eq *) _
      (* lookup_fun *) $h_hyp
      )
    end
  | [ |- ?x ] =>
    Control.throw (Oopsie (fprintf "Error: Don't know how to compile %t" x))
  end.

(* TODO: this computes the exact names (number representations) -> might be slow *)
(*       - would be nice to prove name_enc_inj *)
Ltac2 crush_NoDup () :=
  ltac1:(
    try match goal with
    | |- NoDup _ => simpl; repeat constructor; simpl;
      repeat match goal with
      | _ => progress auto
      | |- context[name_enc _] => unfold name_enc, name_enc_l; simpl
      | _ => congruence
      | |- not _ =>
        let hnm := fresh "Hcont" in
        intros Hnm
      | H: _ \/ _ |- _ => destruct H
      | H: name_enc _ = name_enc _ |- _ => inversion H 
      end
    end
  ).

Ltac2 crush_FEnv () :=
  ltac1:(
    try match goal with
    | |- FEnv.lookup _ _ = _ =>
      eauto with fenvDb;
      cbn; try congruence; try reflexivity
    end
  ).

Ltac2 crush_side_conditions () :=
  Control.enter (fun () =>
    match! goal with
    | [ |- FEnv.lookup _ _ = _ ] => crush_FEnv ()
    | [ |- NoDup _ ] => crush_NoDup ()
    | [ |- (_ < _)%N ] => ltac1:(lia)
    | [ |- _ ] => eauto
    end
  ).

Ltac2 relcompile_impl (): unit :=
  intros;
  let prog_id :=
    match (List.nth (Control.hyps ()) 0) with
    | (i, _, _) => i
    end in
  subst $prog_id;
  unshelve (docompile ());
  crush_NoDup ();
  crush_side_conditions ().

Ltac2 Notation relcompile :=
  relcompile_impl ().

Ltac2 rec mk_constr_list (args: constr list): constr :=
  match args with
  | [] => open_constr:([])
  | h :: t =>
    let t_constr := mk_constr_list t in
    open_constr:($h :: $t_constr)
  end.

Ltac2 rec gen_eval_app_impl (fpargs: constr list) (f_constr_name: constr) (f: constr) (): constr :=
  (* printf "gen_eval_app_impl f.type: %t fpargs: %a f_constr_name: %t f: %t"
    (Constr.type f)
    (fun () x => message_of_list (List.map Message.of_constr x)) fpargs
    f_constr_name
    f; *)
  match Unsafe.kind (Constr.type f) with
  | Prod b _ =>
    let name := Option.default (Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "x"))) (Binder.name b) in
    (* Same as with in_contexts, should ideally be (Binder.type b), but it beaks with dependent types *)
    lambda_to_prod (Constr.in_context name open_constr:(_) (fun () =>
      let b_hyp := Control.hyp name in
      Control.refine (fun () =>
        if constr_is_sort (Binder.type b) then
          let nameR := Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "Refinable_inst")) in
          lambda_to_prod (Constr.in_context nameR open_constr:(Refinable $b_hyp) (fun () =>
            Control.refine (fun () =>
              gen_eval_app_impl fpargs f_constr_name open_constr:($f $b_hyp) ()
            )
          ))
        else gen_eval_app_impl (List.append fpargs [b_hyp]) f_constr_name open_constr:($f $b_hyp) ()
      )
    ))
  | _ =>
    open_constr:(ltac2:(Control.refine (fun () =>
      let encode_list_constr := mk_constr_list (List.map (fun c =>
        let ctpe := Constr.type c in
        constr:(@encode $ctpe _ $c)
      ) fpargs) in
      let f_tpe := Constr.type f in
      constr:(eval_app (name_enc $f_constr_name) $encode_list_constr &s (@encode $f_tpe _ $f, &s))
    )))
  end.

Ltac2 gen_eval_app (f: constr) (): constr :=
  let f_constr_name := Option.get (Option.bind (reference_of_constr_opt f) reference_to_string) in
  let f_constr_name_c := constr_string_of_string f_constr_name in
  open_constr:(ltac2:(Control.refine (gen_eval_app_impl [] f_constr_name_c f))).

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
  Message.print (message_of_list (List.map Message.of_ident bs));
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

Ltac2 rec mk_refine_impls (args: (unit -> constr) list) (res: unit -> constr) (): constr :=
  match args with
  | a :: args =>
    open_constr:(ltac2:(Control.refine a) -> ltac2:(Control.refine (mk_refine_impls args res)))
  | [] =>
    res ()
  end.

(* TODO:
- assume the names of _prog? (Whould be less typing)
*)
Ltac2 relcompile_tpe (prog: constr) (f: constr) (deps: constr list): unit :=
  let f_constr_name := Option.get (Option.bind (reference_of_constr_opt f) reference_to_string) in
  let f_constr_name_c := constr_string_of_string f_constr_name in
  let f_binders := collect_prod_binders f in
  let non_type_f_binders := List.filter (fun b => Bool.neg (constr_is_sort (Binder.type b))) f_binders in
  let f_binder_names := List.map (fun b =>
    let n := Option.default (Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "x"))) (Binder.name b) in
    constr_string_of_string (Ident.to_string n)
  ) non_type_f_binders in
  let encoded_b_names := mk_constr_list (List.map (fun n => constr:(name_enc $n)) f_binder_names) in
  let eval_app_cont := gen_eval_app f in
  (* TODO: this (below) might be easier to use, if we exclude some spurious deps, like "add" *)
  (* let _deps: constr list := get_fun_deps f in *)
  let deps_eval_app_conts := List.map gen_eval_app deps in
  Control.refine (fun () =>
    open_constr:(forall (s: state),
      ltac2:(Control.refine (
        mk_refine_impls
          deps_eval_app_conts
          (fun () => open_constr:(
            lookup_fun (name_enc $f_constr_name_c) &s.(funs) = Some ($encoded_b_names, $prog) ->
            ltac2:(Control.refine eval_app_cont)
          ))
      ))
    )
  ).

(* TODO:
- automation for intros + subst *_prog?
- automation for writing Derivation statements?
- The debugs should be configurable by a (global) variable? (or maybe just an argument?)
*)

(* TODO(kπ): lookups might grow Qed time. Might want to rewrite them to multi-inserts *)

(* *********************************************** *)
(*                Examples/Tests                   *)
(* *********************************************** *)

(* TODO: for some reason, need this for generated derivation statement proofs *)
Opaque encode.

Set Printing Implicit.

Definition idd {A: Type} (a: list A): list A := a.

Derive idd_prog
  in ltac2:(relcompile_tpe 'idd_prog '@idd [])
  as idd_prog_proof.
Proof.
  time relcompile.
Qed.

Fixpoint polylength {A: Type} (l: list A) :=
  match l with
  | [] => 0
  | _ :: l => 1 + polylength l
  end.
Lemma polylength_equation: ltac2:(unfold_fix_type '@polylength).
Proof. unfold_fix_proof '@polylength. Qed.

Derive polylength_prog
  in ltac2:(relcompile_tpe 'polylength_prog '@polylength [])
  as polylength_prog_proof.
Proof.
  relcompile.
Qed.

Definition double_polylength (l: list nat) : nat :=
  2 + polylength l.

Derive double_polylength_prog
  in ltac2:(relcompile_tpe 'double_polylength_prog 'double_polylength ['@polylength])
  as double_polylength_prog_proof.
(* Derive double_polylength_prog
  in (∀ s : state,
  (∀ (A : Type) (Refinable_inst : Refinable A) (l : list A),
    eval_app (name_enc "polylength") [encode l] s (encode (polylength l), s)) →
  lookup_fun (name_enc "double_polylength") (funs s) = Some ([name_enc "l"], double_polylength_prog) →
  ∀ l : list nat,
    eval_app (name_enc "double_polylength") [encode l] s (encode (double_polylength l), s))
  as double_polylength_prog_proof. *)
Proof.
  relcompile.
Qed.

Function has_match (l: list nat) : nat :=
  1 +
  match l with
  | nil => 0
  | cons h t => h + 100
  end.
(* User-land wish: *)
(* TODO: the typeclass instance isn't resolved? maybe because of the open_constr? *)
Derive has_match_prog in ltac2:(relcompile_tpe 'has_match_prog 'has_match []) as has_match_proof.
(* Derive has_match_prog in (forall s,
  lookup_fun (name_enc "has_match") s.(funs) = Some ([name_enc "l"], has_match_prog) ->
  forall l,
    eval_app (name_enc "has_match") [encode l] s (encode (has_match l), s)
) as has_match_proof. *)
Proof.
  relcompile.
Qed.

Fixpoint sum_n (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 => (sum_n n1) + n
  end.
Lemma sum_n_equation : ltac:(unfold_tpe sum_n).
Proof. ltac1:(unfold_proof). Qed.

Derive sum_n_prog in ltac2:(relcompile_tpe 'sum_n_prog 'sum_n []) as sum_n_prog_proof.
(* Derive sum_n_prog in (forall (s: state),
    lookup_fun (name_enc "sum_n") s.(funs) = Some ([name_enc "n"], sum_n_prog) ->
    forall (n : nat),
      eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s))
  as sum_n_prog_proof. *)
Proof.
  relcompile.
Qed.

Definition bool_ops (b: bool): bool :=
  b && true.

Derive bool_ops_prog in ltac2:(relcompile_tpe 'bool_ops_prog 'bool_ops []) as bool_ops_prog_proof.
(* Derive bool_ops_prog in (forall (s : state),
  lookup_fun (name_enc "bool_ops") s.(funs) = Some ([name_enc "b"], bool_ops_prog) ->
  forall (b : bool),
    eval_app (name_enc "bool_ops") [encode b] s (encode (bool_ops b), s))
  as bool_ops_prog_proof. *)
Proof.
  relcompile.
Qed.

Definition has_cases (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 =>
    match n1 with
    | 0 => 1
    | S n2 => n1 + n2
    end
  end.

Derive has_cases_prog in ltac2:(relcompile_tpe 'has_cases_prog 'has_cases []) as has_cases_proof.
(* Derive has_cases_prog in (forall (s : state),
    lookup_fun (name_enc "has_cases") s.(funs) = Some ([name_enc "n"], has_cases_prog) ->
    forall (n: nat),
      eval_app (name_enc "has_cases") [encode n] s (encode (has_cases n), s))
  as has_cases_proof. *)
Proof.
  relcompile.
Qed.

Definition has_cases_list (l : list nat) : nat :=
  match l with
  | nil => 0
  | cons hd tl =>
    match tl with
    | nil => 1
    | cons hdtl tltl => hd + hdtl
    end
  end.

Derive has_cases_list_prog in ltac2:(relcompile_tpe 'has_cases_list_prog 'has_cases_list []) as has_cases_list_proof.
(* Derive has_cases_list_prog in (forall (s : state),
    lookup_fun (name_enc "has_cases_list") s.(funs) = Some ([name_enc "l"], has_cases_list_prog) ->
    forall (l : list nat),
      eval_app (name_enc "has_cases_list") [encode l] s (encode (has_cases_list l), s))
  as has_cases_list_proof. *)
Proof.
  relcompile.
Qed.

Definition foo (n : nat) : nat :=
  let/d x := 1 in
  let/d y := n + x in
  y.

(* TODO: The statements are the same, but eauto can prove one side condition, but not the other :thinking: *)
(*       Ask Clement? *)
Derive foo_prog in ltac2:(relcompile_tpe 'foo_prog 'foo []) as foo_prog_proof.
(* Derive foo_prog in (forall (s : state),
    lookup_fun (name_enc "foo") s.(funs) = Some ([name_enc "n"], foo_prog) ->
    forall (n : nat),
      eval_app (name_enc "foo") [encode n] s (encode (foo n), s))
  as foo_prog_proof. *)
Proof.
  relcompile.
Qed.

Definition bar (n : nat) : nat :=
  foo (n + 1).

Derive bar_prog in ltac2:(relcompile_tpe 'bar_prog 'bar ['foo]) as bar_prog_proof.
(* Derive bar_prog in (forall (s : state),
    (forall m, eval_app (name_enc "foo") [encode m] s (encode (foo m), s)) ->
    lookup_fun (name_enc "bar") s.(funs) = Some ([name_enc "n"], bar_prog) ->
    forall (n : nat),
      eval_app (name_enc "bar") [encode n] s (encode (bar n), s))
  as bar_prog_proof. *)
Proof.
  relcompile.
Qed.

Definition baz (n m : nat) : nat :=
  let/d z := n + m in
  z.

Derive baz_prog in ltac2:(relcompile_tpe 'baz_prog 'baz []) as baz_prog_proof.
(* Derive baz_prog in (forall (s : state),
    lookup_fun (name_enc "baz") s.(funs) = Some ([name_enc "n"; name_enc "m"], baz_prog) ->
    forall (n m : nat),
      eval_app (name_enc "baz") [encode n; encode m] s (encode (baz n m), s))
  as baz_prog_proof. *)
Proof.
  relcompile.
Qed.

Definition baz2 (n : nat) : nat :=
  let/d m := baz (n + 1) n in
  m.

Derive baz2_prog in ltac2:(relcompile_tpe 'baz2_prog 'baz2 ['baz]) as baz2_prog_proof.
(* Derive baz2_prog in (forall (s : state),
    (forall n m, eval_app (name_enc "baz") [encode n; encode m] s (encode (baz n m), s)) ->
    lookup_fun (name_enc "baz2") s.(funs) = Some ([name_enc "n"], baz2_prog) ->
    forall (n : nat),
      eval_app (name_enc "baz2") [encode n] s (encode (baz2 n), s))
  as baz2_prog_proof. *)
Proof.
  relcompile.
Qed.

Function sum_acc (xs: list nat) (acc: nat) :=
  match xs with
  | [] => acc
  | x :: xs => sum_acc xs (x + acc)
  end.

Derive sum_acc_prog
  in ltac2:(relcompile_tpe 'sum_acc_prog 'sum_acc [])
  as sum_acc_prog_proof.
Proof.
  relcompile.
Qed.
