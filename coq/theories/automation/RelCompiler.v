From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
From coqutil Require Import dlet.
From coqutil Require Import Word.Interface.
Require Import impboot.commons.CompilerUtils.
Require Import impboot.parsing.ParserData.
Require Import impboot.parsing.Parser.
Require Import impboot.functional.FunValues.
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.
Require Import impboot.utils.Env.
From impboot.automation.ltac2 Require Import Messages Constrs Stdlib2 UnfoldFix.
From impboot.automation Require Import Ltac2Utils RelCompileUnfolding FunDeps ToLowerable ToANF RelCompilerCommons.
From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf Fresh.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import
  Tactics.reference_to_string
  Tactics.ident_of_string
  Tactics.ident_to_string.
From Stdlib Require Import derive.Derive.
From Stdlib Require Import FunInd.

(* Important notes *)
(* 1. every destruct has to have a `eqn:?` (Otherwise, we can get a bunch of
   goal that need to provide base case values for some types)
   This might be an issue with fix unfolding, since it only happens when we have a fixpoint with a match *)
(* 2. For polymorphic functions always provide them with @ e.g. @length *)

Open Scope nat.

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
          (fun () nl => Messages.message_of_list (List.map Message.of_ident nl))
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
  if debug_relcompile then printf "applying lemma: %s" lname else ();
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

Ltac2 rec disallowed_var (c: constr): bool :=
  match Constr.Unsafe.kind c with
  | Var _ => true
  (* TODO: probably should remove this (next) line – it allows too many undesirable things as consts *)
  | Constant _ _ => true
  | Constructor _ _ => true
  | App c cs => Bool.and (disallowed_var c) (Array.for_all disallowed_var cs)
  | _ => false
  end.

(* Check if `c` is a "proper" constant – used for sanity checks when compiling constants *)
Ltac2 rec proper_const_f (c: constr): bool :=
  match Constr.Unsafe.kind c with
  (* | Var _ => true *)
  (* TODO: probably should remove this (next) line – it allows too many undesirable things as consts *)
  | Constant _ _ => true
  | Constructor _ _ => true
  | App c cs => Bool.and (proper_const_f c) (Array.for_all proper_const_f cs)
  | _ => false
  end.
Ltac2 proper_const (c: constr): bool :=
  let evaluated := eval_cbv beta c in
  proper_const_f evaluated.

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

Ltac2 get_f_lookup_from_context () : string list :=
  let hyps := Control.hyps () in
  let f_lookup := List.flatten (List.map (fun (_iden, _, t) =>
    match! t with
    | context [ eval_app (name_enc ?fname1) _ _ _ ] =>
      [string_of_constr_string fname1]
    | _ => []
    end
  ) hyps) in
  f_lookup.

Ltac2 fname_if_in_f_lookup (f_lookup: string list) (f: constr): string option :=
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

(* TODO: extract this magic pattern as a utility function *)
Ltac2 rec collect_tpe_prod_binders_impl (c: constr) (magic: constr) (proj: binder -> constr option): constr :=
  match Unsafe.kind (Constr.type c) with
  | Prod b _ =>
    let curr := proj b in
    let binder_tpe := (Binder.type b) in
    let applied_magic := open_constr:($magic $binder_tpe) in
    let recursive := collect_tpe_prod_binders_impl open_constr:($c $applied_magic) magic proj in
    match curr with
    | Some curr => open_constr:($curr :: $recursive)
    | None => recursive
    end
  | _ => open_constr:(nil)
  end.

Ltac2 collect_tpe_prod_binders (c: constr) (proj: binder -> constr option): constr :=
  let magic_ident := Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "magic")) in
  let with_magic := Constr.in_context magic_ident constr:(forall A, A) (fun () =>
    let magic := Control.hyp magic_ident in
    Control.refine(fun () =>
      collect_tpe_prod_binders_impl c magic proj
    )
  ) in
  match Unsafe.kind with_magic with
  | Unsafe.Lambda _ v =>
    v
  | _ =>
    Control.throw (Oopsie (fprintf "collect_tpe_prod_binders: expected a product type, got %t" with_magic))
  end.

Ltac2 rec list_of_constr_list (c: constr): constr list :=
  match! c with
  | [] => []
  | ?x :: ?xs =>
    x :: list_of_constr_list xs
  end.

Ltac2 collect_non_prop_tpe_prod_names (c: constr): constr :=
  let cres := collect_tpe_prod_binders c
    (fun b =>
      let cstr := match Binder.name b with
      | Some n => constr_string_of_string (Ident.to_string n)
      | None => constr_string_of_string "?"
      end in
      if Constr.equal constr:(Prop) (Constr.type (Binder.type b)) then
        None
      else if Constrs.is_sort (Binder.type b) then
        None
      else
        Some open_constr:(name_enc $cstr)) in
  constr:($cres: list N).

Ltac2 exactk (c: constr): unit -> unit :=
  fun () => exact $c.

Ltac2 Type exn ::= [
  NoMoreExtensionTactics
].

Ltac2 mutable relCompilerDB: ((unit -> unit) -> unit) :=
  fun _r => Control.zero NoMoreExtensionTactics.

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
    if debug_relcompile then printf "Compiling expression: %t with cenv %a" e (fun () cenv => message_of_cenv cenv) cenv else ();
    (* printf "Goal: %t" c; *)
    let try_lemmas () :=
      lazy_match! e with
      | (fun x => @?_f x) =>
        if debug_relcompile then printf "POTENTIAL ERROR: trying to compile a function in the wild, namely %t" e else ();
        intro_then (Option.get (Ident.of_string "x_nm")) (fun _ =>
          compile ()
        )
      | (dlet ?val ?body) =>
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
        (* eval f *) ltac2:(Control.enter (fun () => intro; intro; cbv beta; compile_with_prep ()))
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
      | (ascii_of_nat ?x) =>
        app_lemma "auto_char_of_nat" [("env", exactk fenv); ("x", exactk x)] [compile; exactk open_constr:(_)]
      | (ascii_of_N ?x) =>
        app_lemma "auto_char_of_N" [("env", exactk fenv); ("x", exactk x)] [compile; exactk open_constr:(_)]
      | (nat_of_ascii ?x) =>
        app_lemma "auto_char_to_nat" [("env", exactk fenv); ("x", exactk x)] [compile]
      | (N_of_ascii ?x) =>
        app_lemma "auto_char_to_N" [("env", exactk fenv); ("x", exactk x)] [compile]
      | (if Ascii.eqb ?n1 ?n2 then ?t else ?f) =>
        app_lemma "auto_char_if_eq"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
          [compile; compile; compile_with_prep; compile_with_prep]
        (* word *)
      | (@word.of_Z 4 _ (Z.of_nat ?x)) =>
        app_lemma "auto_word4_n2w" [("env", exactk fenv); ("x", exactk x)] [compile; exactk open_constr:(_)]
      | (@word.of_Z 64 _ (Z.of_nat ?x)) =>
        app_lemma "auto_word64_n2w" [("env", exactk fenv); ("x", exactk x)] [compile; exactk open_constr:(_)]
      | (@word.of_Z 64 _ (Z.of_N ?x)) =>
        app_lemma "auto_word64_N2w" [("env", exactk fenv); ("x", exactk x)] [compile; exactk open_constr:(_)]
      | (Z.to_nat (@word.unsigned 4 _ ?x)) =>
        app_lemma "auto_word4_w2n" [("env", exactk fenv); ("x", exactk x)] [compile]
      | (Z.to_nat (@word.unsigned 64 _ ?x)) =>
        app_lemma "auto_word64_w2n" [("env", exactk fenv); ("x", exactk x)] [compile]
      | (Z.to_N (@word.unsigned 4 _ ?x)) =>
        app_lemma "auto_word4_w2N" [("env", exactk fenv); ("x", exactk x)] [compile]
      | (Z.to_N (@word.unsigned 64 _ ?x)) =>
        app_lemma "auto_word64_w2N" [("env", exactk fenv); ("x", exactk x)] [compile]
      (* num *)
      | (N.to_nat ?n) =>
        app_lemma "auto_N_to_nat" [("env", exactk fenv); ("n", exactk n)] [compile]
      | (?n1 + ?n2)%nat =>
        app_lemma "auto_nat_add"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
      | (?n1 + ?n2)%N =>
        app_lemma "auto_N_add"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
      (* | S ?n%nat =>
        if debug_relcompile then printf "S case detected: %t" e;
        if Constr.is_var n then
          app_lemma "auto_nat_succ"
            [("env", exactk fenv); ("n", exactk n)] [compile]
        else
          app_lemma "auto_nat_const" [("env", exactk fenv); ("n", exactk constr:(S $n))] [] *)
      (* | S ?n%nat =>
        app_lemma "auto_nat_succ"[("env", exactk fenv); ("n", exactk n)] [compile] *)
      | (?n1 - ?n2)%nat =>
        app_lemma "auto_nat_sub"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
      | (?n1 / ?n2)%nat =>
        app_lemma "auto_nat_div"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile; exactk open_constr:(_)]
      | (?n1 * ?n2)%nat =>
        app_lemma "auto_nat_mul"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
      | (?n1 - ?n2)%N =>
        app_lemma "auto_N_sub"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
      | (?n1 / ?n2)%N =>
        app_lemma "auto_N_div"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile; exactk open_constr:(_)]
      | (?n1 * ?n2)%N =>
        app_lemma "auto_N_mul"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
      | (if Nat.eqb ?n1 ?n2 then ?t else ?f) =>
        app_lemma "auto_nat_if_eq"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
          [compile; compile; compile_with_prep; compile_with_prep]
      | (match Nat.eq_dec ?n1 ?n2 with
        | left EQ => @?t EQ
        | right NE => @?f NE
        end) =>
        app_lemma "auto_nat_if_eq_dec"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
          [compile; compile; (fun () => destruct (Nat.eq_dec $n1 $n2); (Control.enter compile_with_prep))]
      | (if N.eqb ?n1 ?n2 then ?t else ?f) =>
        app_lemma "auto_N_if_eq"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
          [compile; compile; compile_with_prep; compile_with_prep]
      | (if Nat.ltb ?n1 ?n2 then ?t else ?f) =>
        app_lemma "auto_nat_if_less"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
          [compile; compile; compile_with_prep; compile_with_prep]
      | (if N.ltb ?n1 ?n2 then ?t else ?f) =>
        app_lemma "auto_N_if_less"
          [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
          [compile; compile; (fun () => intros; compile_with_prep ()); (fun () => intros; compile_with_prep ())]
      | (match ?v0 with | 0 => ?v1 | S n' => @?v2 n' end) =>
        let binders_of_v2 := binders_names_of_constr_lambda v2 names_in_cenv in
        let n_constr := List.nth binders_of_v2 0 in
        app_lemma "auto_nat_case"
          [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2); ("n", exactk n_constr)]
          [compile; (fun () =>
            (* We would like to use this: (but it give a weird unification for the type of the match) *)
            let h_fresh := Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "Hv0")) in
            destruct $v0 eqn:$h_fresh at 1; Control.enter compile_with_prep
          )]
      | (match ?v0 with | 0%N => ?v1 | N.pos _ => ?v2 end) =>
        app_lemma "auto_N_case"
          [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2)]
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep))]
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
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep) ); (fun () => ())]
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
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep))]
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
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep)); (fun () => ())]
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
                                        [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep)); (fun () => ())]
      (* cmp *)
      | ImpSyntax.Less =>
        app_lemma "auto_cmp_cons_Less" [("env", exactk fenv)] []
      | ImpSyntax.Equal =>
        app_lemma "auto_cmp_cons_Equal" [("env", exactk fenv)] []
      | (match ?v0 with | ImpSyntax.Less => ?f_Less | ImpSyntax.Equal => ?f_Equal end) =>
        app_lemma "auto_cmp_CASE" [("env", exactk fenv); ("v0", exactk v0); ("f_Less", exactk f_Less); ("f_Equal", exactk f_Equal)]
                                  [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep))]
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
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep));
            (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ())]
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
                                  [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep)); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ())]
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
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep)); (fun () => ())]
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
      | ASMSyntax.StoreRSP ?r ?n =>
        app_lemma "auto_instr_cons_StoreRSP" [("env", exactk fenv); ("r", exactk r); ("n", exactk n)] [compile; compile]
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
          | ASMSyntax.Const r w => @?f_Const r w
          | ASMSyntax.Add r1 r2 => @?f_Add r1 r2
          | ASMSyntax.Sub r1 r2 => @?f_Sub r1 r2
          | ASMSyntax.Div r => @?f_Div r
          | ASMSyntax.Jump c n => @?f_Jump c n
          | ASMSyntax.Call n => @?f_Call n
          | ASMSyntax.Mov r1 r2 => @?f_Mov r1 r2
          | ASMSyntax.Ret => ?f_Ret
          | ASMSyntax.Pop r => @?f_Pop r
          | ASMSyntax.Push r => @?f_Push r
          | ASMSyntax.Add_RSP n => @?f_Add_RSP n
          | ASMSyntax.Sub_RSP n => @?f_Sub_RSP n
          | ASMSyntax.Load_RSP r n => @?f_Load_RSP r n
          | ASMSyntax.StoreRSP r n => @?f_StoreRSP r n
          | ASMSyntax.Load r1 r2 w => @?f_Load r1 r2 w
          | ASMSyntax.Store r1 r2 w => @?f_Store r1 r2 w
          | ASMSyntax.GetChar => ?f_GetChar
          | ASMSyntax.PutChar => ?f_PutChar
          | ASMSyntax.Exit => ?f_Exit
          | ASMSyntax.Comment s => @?f_Comment s
          end) =>
        let binders_f_Const := binders_names_of_constr_lambda f_Const names_in_cenv in
        let binders_f_Add := binders_names_of_constr_lambda f_Add names_in_cenv in
        let binders_f_Sub := binders_names_of_constr_lambda f_Sub names_in_cenv in
        let binders_f_Div := binders_names_of_constr_lambda f_Div names_in_cenv in
        let binders_f_Jump := binders_names_of_constr_lambda f_Jump names_in_cenv in
        let binders_f_Call := binders_names_of_constr_lambda f_Call names_in_cenv in
        let binders_f_Mov := binders_names_of_constr_lambda f_Mov names_in_cenv in
        let binders_f_Pop := binders_names_of_constr_lambda f_Pop names_in_cenv in
        let binders_f_Push := binders_names_of_constr_lambda f_Push names_in_cenv in
        let binders_f_Add_RSP := binders_names_of_constr_lambda f_Add_RSP names_in_cenv in
        let binders_f_Sub_RSP := binders_names_of_constr_lambda f_Sub_RSP names_in_cenv in
        let binders_f_Load_RSP := binders_names_of_constr_lambda f_Load_RSP names_in_cenv in
        let binders_f_StoreRSP := binders_names_of_constr_lambda f_StoreRSP names_in_cenv in
        let binders_f_Load := binders_names_of_constr_lambda f_Load names_in_cenv in
        let binders_f_Store := binders_names_of_constr_lambda f_Store names_in_cenv in
        let binders_f_Comment := binders_names_of_constr_lambda f_Comment names_in_cenv in
        let nConst1 := List.nth binders_f_Const 0 in
        let nConst2 := List.nth binders_f_Const 1 in
        let nAdd1 := List.nth binders_f_Add 0 in
        let nAdd2 := List.nth binders_f_Add 1 in
        let nSub1 := List.nth binders_f_Sub 0 in
        let nSub2 := List.nth binders_f_Sub 1 in
        let nDiv1 := List.nth binders_f_Div 0 in
        let nJump1 := List.nth binders_f_Jump 0 in
        let nJump2 := List.nth binders_f_Jump 1 in
        let nCall1 := List.nth binders_f_Call 0 in
        let nMov1 := List.nth binders_f_Mov 0 in
        let nMov2 := List.nth binders_f_Mov 1 in
        let nPop1 := List.nth binders_f_Pop 0 in
        let nPush1 := List.nth binders_f_Push 0 in
        let nAdd_RSP1 := List.nth binders_f_Add_RSP 0 in
        let nSub_RSP1 := List.nth binders_f_Sub_RSP 0 in
        let nLoad_RSP1 := List.nth binders_f_Load_RSP 0 in
        let nLoad_RSP2 := List.nth binders_f_Load_RSP 1 in
        let nStoreRSP1 := List.nth binders_f_StoreRSP 0 in
        let nStoreRSP2 := List.nth binders_f_StoreRSP 1 in
        let nLoad1 := List.nth binders_f_Load 0 in
        let nLoad2 := List.nth binders_f_Load 1 in
        let nLoad3 := List.nth binders_f_Load 2 in
        let nStore1 := List.nth binders_f_Store 0 in
        let nStore2 := List.nth binders_f_Store 1 in
        let nStore3 := List.nth binders_f_Store 2 in
        let nComment1 := List.nth binders_f_Comment 0 in
        app_lemma "auto_instr_CASE" [("env", exactk fenv); ("v0", exactk v0);
        ("f_Const", exactk f_Const); ("f_Add", exactk f_Add); ("f_Sub", exactk f_Sub);
        ("f_Div", exactk f_Div); ("f_Jump", exactk f_Jump); ("f_Call", exactk f_Call);
        ("f_Mov", exactk f_Mov); ("f_Ret", exactk f_Ret); ("f_Pop", exactk f_Pop);
        ("f_Push", exactk f_Push); ("f_Add_RSP", exactk f_Add_RSP); ("f_Sub_RSP", exactk f_Sub_RSP);
        ("f_Load_RSP", exactk f_Load_RSP); ("f_StoreRSP", exactk f_StoreRSP); ("f_Load", exactk f_Load);
        ("f_Store", exactk f_Store); ("f_GetChar", exactk f_GetChar); ("f_PutChar", exactk f_PutChar);
        ("f_Exit", exactk f_Exit); ("f_Comment", exactk f_Comment); ("nConst1", exactk nConst1);
        ("nConst2", exactk nConst2); ("nAdd1", exactk nAdd1); ("nAdd2", exactk nAdd2);
        ("nSub1", exactk nSub1); ("nSub2", exactk nSub2); ("nDiv1", exactk nDiv1); ("nJump1", exactk nJump1);
        ("nJump2", exactk nJump2); ("nCall1", exactk nCall1); ("nMov1", exactk nMov1); ("nMov2", exactk nMov2);
        ("nPop1", exactk nPop1); ("nPush1", exactk nPush1); ("nAdd_RSP1", exactk nAdd_RSP1);
        ("nSub_RSP1", exactk nSub_RSP1); ("nLoad_RSP1", exactk nLoad_RSP1); ("nLoad_RSP2", exactk nLoad_RSP2);
        ("nStoreRSP1", exactk nStoreRSP1); ("nStoreRSP2", exactk nStoreRSP2); ("nLoad1", exactk nLoad1);
        ("nLoad2", exactk nLoad2); ("nLoad3", exactk nLoad3); ("nStore1", exactk nStore1);
        ("nStore2", exactk nStore2); ("nStore3", exactk nStore3); ("nComment1", exactk nComment1)]
            [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep));
              (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ());(fun () => ()); (fun () => ())]
      (* prog *)
      | ImpSyntax.Program ?funcs =>
        app_lemma "auto_prog_cons_Program" [("env", exactk fenv); ("funcs", exactk funcs)] [compile]
      | (match ?v0 with | ImpSyntax.Program funcs => @?f_Program funcs end) =>
        let binders_f_Program := binders_names_of_constr_lambda f_Program names_in_cenv in
        let n1 := List.nth binders_f_Program 0 in
        app_lemma "auto_prog_CASE"
          [("env", exactk fenv); ("v0", exactk v0); ("f_Program", exactk f_Program); ("n1", exactk n1)]
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep))]
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
          | ASMSyntax.RAX => ?f_RAX | ASMSyntax.RDI => ?f_RDI | ASMSyntax.RBX => ?f_RBX
          | ASMSyntax.RBP => ?f_RBP | ASMSyntax.R12 => ?f_R12 | ASMSyntax.R13 => ?f_R13
          | ASMSyntax.R14 => ?f_R14 | ASMSyntax.R15 => ?f_R15 | ASMSyntax.RDX => ?f_RDX
          end) =>
        app_lemma "auto_reg_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                    ("f_RAX", exactk f_RAX); ("f_RDI", exactk f_RDI); ("f_RBX", exactk f_RBX);
                                    ("f_RBP", exactk f_RBP); ("f_R12", exactk f_R12); ("f_R13", exactk f_R13);
                                    ("f_R14", exactk f_R14); ("f_R15", exactk f_R15); ("f_RDX", exactk f_RDX)]
                                  [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep))]
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
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep)); (fun () => ()); (fun () => ()); (fun () => ())]
      (* cond *)
      | ASMSyntax.Always =>
        app_lemma "auto_cond_cons_Always" [("env", exactk fenv)] []
      | ASMSyntax.Less ?r1 ?r2 =>
        app_lemma "auto_cond_cons_Less" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
      | ASMSyntax.Equal ?r1 ?r2 =>
        app_lemma "auto_cond_cons_Equal" [("env", exactk fenv); ("r1", exactk r1); ("r2", exactk r2)] [compile; compile]
      | (match ?v0 with
          | ASMSyntax.Always => ?f_Always
          | ASMSyntax.Less r1 r2 => @?f_Less r1 r2
          | ASMSyntax.Equal r1 r2 => @?f_Equal r1 r2
          end) =>
        let binders_f_Less := binders_names_of_constr_lambda f_Less names_in_cenv in
        let binders_f_Equal := binders_names_of_constr_lambda f_Equal names_in_cenv in
        let n1 := List.nth binders_f_Less 0 in
        let n2 := List.nth binders_f_Less 1 in
        let n3 := List.nth binders_f_Equal 0 in
        let n4 := List.nth binders_f_Equal 1 in
        app_lemma "auto_cond_CASE"
          [("env", exactk fenv); ("v0", exactk v0);
            ("f_Always", exactk f_Always); ("f_Less", exactk f_Less); ("f_Equal", exactk f_Equal);
            ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3); ("n4", exactk n4)]
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep)); (fun () => ()); (fun () => ())]
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
      | ASMSyntax.StoreRSP ?r ?n =>
        app_lemma "auto_instr_cons_StoreRSP" [("env", exactk fenv); ("r", exactk r); ("n", exactk n)] [compile; compile]
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
      (* token *)
      | OPEN =>
        app_lemma "auto_token_cons_OPEN" [("env", exactk fenv)] []
      | CLOSE =>
        app_lemma "auto_token_cons_CLOSE" [("env", exactk fenv)] []
      | DOT =>
        app_lemma "auto_token_cons_DOT" [("env", exactk fenv)] []
      | NUM ?n =>
        app_lemma "auto_token_cons_NUM" [("env", exactk fenv); ("n", exactk n)] [compile]
      | QUOTE ?str => 
        app_lemma "auto_token_cons_QUOTE" [("env", exactk fenv); ("str", exactk str)] [compile]
      | (match ?v0 with
        | OPEN => ?f_OPEN
        | CLOSE => ?f_CLOSE
        | DOT => ?f_DOT
        | NUM n => @?f_NUM n
        | QUOTE str => @?f_QUOTE str
        end) =>
        let binders_f_NUM := binders_names_of_constr_lambda f_NUM names_in_cenv in
        let binders_f_QUOTE := binders_names_of_constr_lambda f_QUOTE names_in_cenv in
        let n1 := List.nth binders_f_NUM 0 in
        let n2 := List.nth binders_f_QUOTE 0 in
        app_lemma "auto_token_CASE"
          [("env", exactk fenv); ("v0", exactk v0);
            ("f_OPEN", exactk f_OPEN); ("f_CLOSE", exactk f_CLOSE); ("f_DOT", exactk f_DOT);
            ("f_NUM", exactk f_NUM); ("f_QUOTE", exactk f_QUOTE);
            ("n1", exactk n1); ("n2", exactk n2)]
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep))]
      (* FunValues.Value *)
      | FunValues.Pair ?v1 ?v2 =>
        app_lemma "auto_value_cons_Pair" [("env", exactk fenv); ("v1", exactk v1); ("v2", exactk v2)] [compile; compile]
      | FunValues.Num ?n =>
        app_lemma "auto_value_cons_Num" [("env", exactk fenv); ("n", exactk n)] [compile]
      | (match ?v0 with
        | FunValues.Pair v1 v2 => @?f_Pair v1 v2
        | FunValues.Num n => @?f_Num n
        end) =>
        let binders_f_Pair := binders_names_of_constr_lambda f_Pair names_in_cenv in
        let binders_f_Num := binders_names_of_constr_lambda f_Num names_in_cenv in
        let n1 := List.nth binders_f_Pair 0 in
        let n2 := List.nth binders_f_Pair 1 in
        let n3 := List.nth binders_f_Num 0 in
        app_lemma "auto_value_case"
          [("env", exactk fenv); ("v0", exactk v0);
            ("f_Pair", exactk f_Pair); ("f_Num", exactk f_Num);
            ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3)]
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep)); (fun () => ())]
      (* string *)
      | EmptyString =>
        app_lemma "auto_string_nil" [("env", exactk fenv)] []
      | String ?x ?xs =>
        app_lemma "auto_string_cons"
          [("env", exactk fenv); ("x", exactk x); ("xs", exactk xs)]
          [compile; compile]
      | (match ?v0 with
        | EmptyString => ?v1
        | String h t => @?v2 h t
        end) =>
        let binders_v2 := binders_names_of_constr_lambda v2 names_in_cenv in
        let n1 := List.nth binders_v2 0 in
        let n2 := List.nth binders_v2 1 in
        app_lemma "auto_string_case"
          [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2);
            ("n1", exactk n1); ("n2", exactk n2)]
          [compile; (fun () => destruct $v0 eqn:? at 1; (Control.enter compile_with_prep)); (fun () => ())]
      | (list_ascii_of_string ?str) =>
        app_lemma "auto_string_to_list" [("env", exactk fenv); ("str", exactk str)] [compile]
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
                                  [compile; compile_with_prep; compile_with_prep]
      (* const *)
      | ?n =>
        Control.plus (fun () => relCompilerDB compile) (fun _ =>
          if Constr.equal (Constr.type (Constr.type n)) constr:(Prop) then
            app_lemma "auto_Prop" [("env", exactk fenv); ("v", exactk n)] []
          else if proper_const n then
            if Constr.equal (Constr.type n) constr:(nat) then
              app_lemma "auto_nat_const" [("env", exactk fenv); ("n", exactk n)] []
            else if Constr.equal (Constr.type n) constr:(N) then
              app_lemma "auto_N_const" [("env", exactk fenv); ("n", exactk n)] []
            (* else if Constr.equal (Constr.type n) constr:(string) then
              app_lemma "auto_string_const" [("env", exactk fenv); ("str", exactk n)] [(fun () => simpl list_ascii_of_string; compile ())] *)
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
        )
      end
    in
    let try_function () :=
      match extract_fun e with
      | None =>
        try_lemmas ()
      | Some (f, args) =>
        (* A function application *)
        let args := List.filter (fun c =>
          Bool.and
            (Bool.neg (Constr.equal constr:(Prop) (Constr.type (Constr.type c))))
            (Bool.neg (Constrs.is_sort (Constr.type c)))
        ) args in
        let f_lookup := get_f_lookup_from_context () in
        let fname_opt := fname_if_in_f_lookup f_lookup f in
        match fname_opt with
        | Some fname =>
          (* Existing function that is in f_lookup (currently – in premises) *)
          let args_constr := list_to_constr_encode args in
          let fname_str := constr_string_of_string fname in
          if debug_relcompile then printf "applying trans_Call with fname := %t and args := %t" fname_str args_constr else ();
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
          try_lemmas ()
        end
      end
    in
    let constr_comp_str (c1: constr) (c2: constr) :=
      let s1 := Message.to_string (fprintf "%t" c1) in
      let s2 := Message.to_string (fprintf "%t" c2) in
      String.equal s1 s2
    in
    match List.find_opt (fun p => Constr.equal e (snd p)) cenv with
    | Some (name_constr_opt, _) =>
      if Constr.is_var e then
        let name_constr := Option.get name_constr_opt in
        if debug_relcompile then printf "applying lemma: trans_Var with v := %t (named: %t)" e name_constr else ();
        refine open_constr:(trans_Var
        (* env *) $fenv
        (* s *) _
        (* n *) $name_constr
        (* v *) $e
        (* FEnv.lookup *) ltac2:(eauto with fenvDb)
        )
      else try_function ()
    | None =>
      try_function ()
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
  end
with compile_with_prep (): unit :=
  rewrite_lowerable (); (* have to try twice if a potential rewrite gets hidden under a binder (Maybe we should try this step every time?) *)
  try_to_anf_relcompile ();
  rewrite_lowerable ();
  compile ().

Ltac2 rec has_make_env (c: constr): bool :=
  match! c with
  | (FEnv.insert _ ?c) => has_make_env c
  | make_env _ _ _ => true
  | _ => false
  end.

(* Top level tactic that compiles a program into FunLang *)
(* Handles expression evaluation and function evaluation as goals *)
Ltac2 rec docompile () :=
  (* printf "docompile goal: = %t" (Control.goal ()); *)
  lazy_match! goal with
  | [ |- _ |-- (_, _) ---> ([encode _], _) ] =>
    compile_with_prep ()
  | [ h : (lookup_fun (name_enc ?fname) _ = Some (?params, ?_body))
  |- eval_app (name_enc ?fname) ?args _ (encode ?c, _) ] =>
    let h_hyp := Control.hyp h in
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
        unfold_once fconstr fargs;
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
  ltac1:(match goal with
  | H: ?g = FunSyntax.Defun ?nm ?args ?body |- _ =>
    instantiate(1 := FunSyntax.Defun nm args _) in H; inversion H; clear H; subst body
  end);
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
    (* Same as with in_contexts, should ideally be (Binder.type b), but it breaks with dependent types *)
    lambda_to_prod (Constr.in_context name open_constr:(_) (fun () =>
      let b_hyp := Control.hyp name in
      Control.refine (fun () =>
        if Constrs.is_sort (Binder.type b) then
          let nameR := Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "Refinable_inst")) in
          lambda_to_prod (Constr.in_context nameR open_constr:(Refinable $b_hyp) (fun () =>
            Control.refine (fun () =>
              gen_eval_app_impl fpargs f_constr_name open_constr:($f $b_hyp) ()
            )
          ))
        (* TODO: for proper Prop erasure *)
        else if Constr.equal constr:(Prop) (Constr.type (Binder.type b)) then
          gen_eval_app_impl fpargs f_constr_name open_constr:($f $b_hyp) ()
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
  let encoded_b_names := collect_non_prop_tpe_prod_names f in
  let eval_app_cont := gen_eval_app f in
  let deps_eval_app_conts := List.map gen_eval_app deps in
  Control.refine (fun () =>
    open_constr:(
      forall body, $prog = FunSyntax.Defun (name_enc $f_constr_name_c) $encoded_b_names body ->
      forall (s: state),
      ltac2:(Control.refine (
        mk_refine_impls
          deps_eval_app_conts
          (fun () => open_constr:(
            lookup_fun (name_enc $f_constr_name_c) &s.(funs) = Some ($encoded_b_names, &body) ->
            ltac2:(Control.refine eval_app_cont)
          ))
      ))
    )
  ).

(* TODO:
- automation for intros + subst *_prog?
- automation for writing Derivation statements?
- The debugs should be configurable by a (global) variable? (or maybe just an argument?)
- Do Free.in_goal on state/quantified arguments of a function (we cannot name arguments `s` right now)
*)

(* TODO(kπ): lookups might grow Qed time. Might want to rewrite them to multi-inserts *)

(* *********************************************** *)
(*                Examples/Tests                   *)
(* *********************************************** *)

(* TODO: for some reason, need this for generated derivation statement proofs *)
Opaque encode.

(* Definition has_many_definitions (n: nat): nat :=
  let/d x := 1 in
  let/d y := 2 in
  let/d z := 3 in
  let/d a := n + x in
  let/d b := a * 2 in
  let/d c := b + y in
  let/d d := c - z in
  let/d e := d * 3 in
  let/d f := e + a in
  let/d g := f * b in
  let/d h := g + c in
  let/d i := h - d in
  let/d j := i + e in
  let/d k := j * f in
  let/d l := k + g in
  let/d m := l - h in
  let/d o := m + i in
  let/d p := o * j in
  let/d q := p + k in
  let/d r := q - l in
  let/d s := r + m in
  let/d t := s * o in
  let/d u := t + p in
  a + b + c + d + e + f + g + h + i + j + k + l + m + o + p + q + r + s + t + u.

Derive has_many_definitions_prog
  in ltac2:(relcompile_tpe 'has_many_definitions_prog 'has_many_definitions ['mul_nat])
  as has_many_definitions_prog_proof.
Proof.
  time relcompile.
Qed.

Definition uses_long_strings (str: string): string :=
  "asdsfsdfsdfsdfjnsdfkljsndf".

Set Ltac2 In Ltac1 Profiling.
Set Ltac Profiling.
Reset Ltac Profile.

Derive uses_long_strings_prog
  in ltac2:(relcompile_tpe 'uses_long_strings_prog 'uses_long_strings ['string_append])
  as uses_long_strings_prog_proof.
Proof.
  time relcompile.
Qed.
Show Ltac Profile. *)

Definition nat_modulo1 (n1 n2: nat): nat :=
  match n2 with
  | 0%nat => 0
  | S _ => n1 - n2 * (n1 / n2)
  end.

Remark gcd_oblig:
  forall (a b: nat) (NE: b <> 0), nat_modulo1 a b < b.
Proof.
Admitted.

Function gcd_rec (a b: nat) (ACC: Acc lt b) {struct ACC}: nat :=
  match Nat.eq_dec b 0 with
  | left EQ => a
  | right NE =>
    gcd_rec b (nat_modulo1 a b) (Acc_inv ACC (gcd_oblig a b NE))
  end.

(* Derive gcd_rec_prog
  in ltac2:(relcompile_tpe 'gcd_rec_prog 'gcd_rec ['nat_modulo1])
  as gcd_rec_prog_proof.
Proof.
  time relcompile.
Qed. *)

(* Set Printing Implicit. *)

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
About polylength.
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
Proof.
  relcompile.
Qed.

Function has_match (l: list nat) : nat :=
  1 +
  match l with
  | nil => 0
  | cons h t => h + 100
  end.

Derive has_match_prog in ltac2:(relcompile_tpe 'has_match_prog 'has_match []) as has_match_proof.
Proof.
  relcompile.
Qed.

(* Fixpoint sum_n (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 => (sum_n n1) + n
  end.
Lemma sum_n_equation : ltac2:(unfold_fix_type 'sum_n).
Proof. unfold_fix_proof 'sum_n. Qed. *)

Fixpoint sum_n (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 => (sum_n n1) + (1 + n1)
  end.
Lemma sum_n_equation : ltac2:(unfold_fix_type 'sum_n).
Proof. unfold_fix_proof 'sum_n. Qed.

Derive sum_n_prog in ltac2:(relcompile_tpe 'sum_n_prog 'sum_n []) as sum_n_prog_proof.
Proof.
  time relcompile.
Qed.

Definition bool_ops (b: bool): bool :=
  b && true.

Derive bool_ops_prog in ltac2:(relcompile_tpe 'bool_ops_prog 'bool_ops []) as bool_ops_prog_proof.
Proof.
  relcompile.
Qed.

Definition has_cases (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 =>
    match n1 with
    | 0 =>
      let/d s := "ab" ++ "cd" in
      List.length (list_ascii_of_string s)
    | S n2 => n1 + n2
    end
  end.

Derive has_cases_prog in ltac2:(relcompile_tpe 'has_cases_prog 'has_cases ['string_append; '@list_length]) as has_cases_proof.
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
Proof.
  relcompile.
Qed.

Definition foo (n : nat) : nat :=
  let/d x := 1 in
  let/d y := n + x in
  y.

Derive foo_prog in ltac2:(relcompile_tpe 'foo_prog 'foo []) as foo_prog_proof.
Proof.
  relcompile.
Qed.

Definition bar (n : nat) : nat :=
  foo (n + 1).

Derive bar_prog in ltac2:(relcompile_tpe 'bar_prog 'bar ['foo]) as bar_prog_proof.
Proof.
  relcompile.
Qed.

Definition baz (n m : nat) : nat :=
  let/d z := n + m in
  z.

Derive baz_prog in ltac2:(relcompile_tpe 'baz_prog 'baz []) as baz_prog_proof.
Proof.
  relcompile.
Qed.

Definition baz2 (n : nat) : nat :=
  let/d m := baz (n + 1) n in
  m.

Derive baz2_prog in ltac2:(relcompile_tpe 'baz2_prog 'baz2 ['baz]) as baz2_prog_proof.
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
