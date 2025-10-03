From impboot Require Import utils.Core.
From coqutil Require Import dlet.
Require Import impboot.functional.FunValues.
(* Require Import impboot.functional.FunSyntax. *)
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

Open Scope nat.

Definition empty_state : state := init_state Llist.Lnil [].

Ltac2 automation_lemmas () := List.flat_map (fun s => opt_to_list (Env.get [Option.get (Ident.of_string s)])) [
  "auto_let";
  "auto_bool_T";
  "auto_bool_F";
  "auto_bool_and";
  "auto_bool_iff";
  "auto_bool_not"
].

Ltac2 get_test_ref() :=
  let refs := Env.expand (ident_of_fqn ["auto_bool_not"]) in
  List.hd refs.

(* TODO(kπ): this version doesn't work - loops indefinitely *)
Ltac2 rec split_thm (c: constr): constr list :=
  lazy_match! c with
  | (∀ x, @?f x) =>
    x :: split_thm f
  | _ => []
  end.

Ltac2 rec string_of_relevance (r: Binder.relevance): string :=
  match r with
  | Binder.Relevant => "Relevant"
  | Binder.Irrelevant => "Irrelevant"
  | Binder.RelevanceVar (_) => "RelevanceVar"
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

Ltac2 intro_then_refine (nm: string) (k: constr -> constr): constr :=
  open_constr:(ltac2:(Control.enter (fun () =>
    let x := Fresh.in_goal (Option.get (Ident.of_string nm)) in
    Std.intros false [IntroNaming (IntroFresh x)];
    let x_constr := (Control.hyp x) in
    Control.refine (fun () =>
      k x_constr
    )
  ))).

Ltac2 intro_then (nm: string) (k: constr -> unit): unit :=
  Control.enter (fun () =>
    let x := Fresh.in_goal (Option.get (Ident.of_string nm)) in
    Std.intros false [IntroNaming (IntroFresh x)];
    let x_constr := (Control.hyp x) in
    k x_constr
  ).

Ltac2 rec apply_thm (thm: constr) (args: (unit -> unit) list): constr :=
  match args with
  | [] => thm
  | arg :: args =>
    apply_thm open_constr:($thm ltac2:(Control.enter arg)) args
  end.

Ltac2 rec compile_if_needed (compile_fn: unit -> unit): unit :=
  match! Control.goal () with
  (* | match ?v with 0%nat => _ | S _ => _ end =>
    Control.enter (fun () =>
      (* Control.throw_invalid_argument ""; *)
      destruct $v;
      Control.enter (fun () => compile_if_needed compile_fn)
    ) *)
  | _ |-- (_, _) ---> (_, _) =>
    Control.enter (fun () =>
      cbv beta;
      compile_fn ()
    )
  | (forall _, _) =>
    intro_then "x_nm" (fun _ =>
      compile_if_needed compile_fn
    )
  | _ => 
    match Unsafe.kind (Control.goal ()) with
    | Case _ _ _ t bl =>
      printf "compile_if_needed %t %t %t" (Control.goal ()) (Array.get bl 0) t;
      refine open_constr:(_)
    | _ => refine open_constr:(_)
    end
  end.

Ltac2 rec isCompilable (c: constr): bool :=
  match! c with
  | _ |-- (_, _) ---> (_, _) => true
  | _ =>
    match Constr.Unsafe.kind c with
    | Prod _ c1 => isCompilable c1
    | Case _ _ _ t bl =>
      printf "compile_if_needed %t %t %t" (Control.goal ()) (Array.get bl 0) t;
      Array.for_all isCompilable bl
    | _ => false
    end
  end.

(* Returns the number of arguments a theorem named `lname` takes *)
Ltac2 rec thm_parts_length (lname: string): int :=
  let lemma_ref: reference := List.hd (Env.expand (ident_of_fqn [lname])) in
  let lemma_inst: constr := Env.instantiate lemma_ref in
  let lemma_tpe: constr := type lemma_inst in
  let thm_parts := split_thm_args lemma_tpe in
  List.length thm_parts.

Ltac2 rec compile_if_needed_rec (compile_fn: unit -> unit) (acc: constr) (lname: string)
                                (thm_parts: constr list) (extracted: constr list)
                                (continuations: (unit -> unit) list): constr :=
  let acc := eval_cbv beta acc in
  match thm_parts(* , continuations *) with
  | [](* , [] *) => acc
  | thm_part :: thm_parts(* , k :: continuations *) =>
    (* is compilable (_ |-- _ ---> _) -> compile *)
    if isCompilable thm_part then
      let compiled := (fun () =>
        compile_if_needed compile_fn
      ) in
      compile_if_needed_rec compile_fn open_constr:($acc ltac2:(Control.enter compiled)) lname thm_parts extracted continuations
    else
      match extracted with
      | extr :: extracted =>
        (* TODO(kπ): Check if this can backtrack too much (we only want this for an automatic check of unification) *)
        let use_extr := (fun () =>
          (open_constr:($acc ltac2:(Control.enter (fun () => refine extr))), extracted)
        ) in
        let skip_extr := (fun _ =>
          (open_constr:($acc _), (extr :: extracted))
        ) in
        let (acc, extracted) :=
          match Control.case use_extr with
          | Err _ => skip_extr ()
          | Val (x, _) => x
          end in
        compile_if_needed_rec compile_fn acc lname thm_parts extracted continuations
      | _ =>
        compile_if_needed_rec compile_fn open_constr:($acc _) lname thm_parts extracted continuations
      end
  (* | [], _ => Control.throw (Oopsie (fprintf "Too many continuations passed when compiling with lemma %s" lname))
  | _, [] => Control.throw (Oopsie (fprintf "Not enough continuations passed when compiling with lemma %s" lname)) *)
  end.

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
  | None => lemma_inst
  | Some b =>
    match Binder.name b with
    | Some nm =>
      (* named binder -> term *)
      match List.find_opt (fun n => Ident.equal (fst n) nm) named_conts with
      | Some (_, ext) =>
        (* TODO: check the $extr                vvvvv *)
        assemble_lemma open_constr:($lemma_inst ltac2:(ext ())) lname named_conts conts
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

Ltac2 rec pair_thm_parts (thm_parts: constr list) (extracted: constr list)
                         (acc: (constr * constr) option list): (constr * constr) option list :=
  match thm_parts with
  | [] => acc
  | p :: thm_parts =>
    if isCompilable p then
      match extracted with
      | extr :: extracted => pair_thm_parts thm_parts extracted (Some (extr, p) :: acc)
      | _ => Control.throw_invalid_argument "pair_thm_parts"
      end
    else pair_thm_parts thm_parts extracted (None :: acc)
  end.

(* Apply lemma named `lname`, use compilaiton funciton `compile_fn` to compile "eval" premises of the lemma *)
(*   Fill in `extracted` terms for term premises *)
(*   (Also make sure to update the `cenv` while recursing) *)
Ltac2 app_lemma (lname: string) (named_conts: (string * (unit -> unit)) list)
                (conts: (unit -> unit) list): unit :=
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
Ltac2 is_in_loopkup (f_lookup : (string * constr) list) (fname : string) : bool :=
  match List.find_opt (fun (name, _) => String.equal name fname) f_lookup with
  | Some (_, c) => true
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
Ltac2 rec extract_fun (e : constr): (constr * constr list) option :=
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
    else
      None
  end.

Ltac2 rec apply_to_args (fn: constr) (args: constr list) :=
  match args with
  | [] => fn
  | arg :: args =>
    apply_to_args open_constr:($fn $arg) args
  end.

Ltac2 rec list_to_constr_encode (l : constr list) : constr :=
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
Ltac2 rec refine_up_to_eval_app (iden : ident) (t : constr) : constr :=
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
  end.

Ltac2 get_f_lookup_from_hyps () : (string * constr) list :=
  let hyps := Control.hyps () in
  let f_lookup := List.flatten (List.map (fun (iden, _, t) =>
    match! t with
    | context [ eval_app (name_enc ?fname1) _ _ _ ] =>
      let t_refined := refine_up_to_eval_app iden t in
      [(string_of_constr_string fname1, t_refined)]
    | _ => []
    end
  ) hyps) in
  f_lookup.

Ltac2 fname_if_in_f_lookup (f_lookup: (string * constr) list) (f: constr) :=
  let f_name_r: reference option := reference_of_constr_opt f in
  let f_name_str := Option.bind f_name_r reference_to_string in
  Option.bind f_name_str (fun n => if is_in_loopkup f_lookup n then Some n else None).

Ltac2 rec binders_names_of_constr_lambda (c: constr): constr list :=
  match Unsafe.kind c with
  | Lambda b c1 =>
    match Binder.name b with
    | Some n =>
      constr_string_of_string (Ident.to_string n) :: binders_names_of_constr_lambda c1
    | None =>
      constr:("_"%string) :: binders_names_of_constr_lambda c1
    end
  | _ => []
  end.

Ltac2 message_of_option (opt: message option): message :=
  Option.default (fprintf "None") opt.

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
    printf "Compiling expression: %t with cenv %a" e (fun () cenv => message_of_cenv cenv) cenv;
    match List.find_opt (fun p => Constr.equal e (snd p)) cenv with
    | Some (name_constr_opt, _) =>
      let name_constr := Option.default open_constr:(_) name_constr_opt in
      refine open_constr:(trans_Var
      (* env *) $fenv
      (* s *) _
      (* n *) $name_constr
      (* v *) $e
      (* FEnv.lookup *) _
      )
    | None =>
      let compile_go () :=
        lazy_match! e with
        | (fun x => @?_f x) =>
          printf "POTENTIAL ERROR: trying to compile a function in the wild, namely %t" e;
          intro_then "x_nm" (fun _ =>
            compile ()
          )
        | (dlet ?val ?body) =>
          let binders_of_body := binders_names_of_constr_lambda body in
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
          let binders_of_body := binders_names_of_constr_lambda body in
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
        (* bool *)
        | true =>
          app_lemma "auto_bool_T" [("env", exactk fenv)] []
        | false =>
          app_lemma "auto_bool_F" [("env", exactk fenv)] []
        | (negb ?b) =>
          app_lemma "auto_bool_not" [("env", exactk fenv); ("b", exactk b)] [compile]
        | (andb ?bA ?bB) =>
          app_lemma "auto_bool_and" [("env", exactk fenv); ("bA", exactk bA); ("bB", exactk bB)] [compile; compile]
        | (eqb ?bA ?bB) =>
          app_lemma "auto_bool_iff" [("env", exactk fenv); ("bA", exactk bA); ("bB", exactk bB)] [compile; compile]
        | (if ?b then ?t else ?f) =>
          app_lemma "last_bool_if" [("env", exactk fenv); ("b", exactk b); ("t", exactk t); ("f", exactk f)]
                                   [compile; compile; compile]
        (* nat *)
        | (?n1 + ?n2) =>
          app_lemma "auto_nat_add" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)]
                                   [compile; compile]
        | (?n1 - ?n2) =>
          app_lemma "auto_nat_sub" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
        | (?n1 / ?n2) =>
          app_lemma "auto_nat_div" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
        | (if Nat.eqb ?n1 ?n2 then ?t else ?f) =>
          app_lemma "auto_nat_if_eq" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
                                     [compile; compile]
        | (if ?n1 <? ?n2 then ?t else ?f) =>
          app_lemma "auto_nat_if_less" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
                                       [compile; compile]
        (* list *)
        | [] =>
          app_lemma "auto_list_nil" [("env", exactk fenv)] []
        | (?x :: ?xs) =>
          app_lemma "auto_list_cons" [("env", exactk fenv); ("x", exactk x); ("xs", exactk xs)] [compile; compile]
        | (match ?v0 with | nil => ?v1 | h :: t => @?v2 h t end) =>
          let binders_of_v2 := binders_names_of_constr_lambda v2 in
          let n1_constr := List.nth binders_of_v2 0 in
          let n2_constr := List.nth binders_of_v2 1 in
          app_lemma "auto_list_case" [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2); ("n1", exactk n1_constr); ("n2", exactk n2_constr)]
                                     [compile; (fun () => destruct $v0; (Control.enter compile)); (fun () => ())]
        (* TODO: see if we can use pairs (name -> tactic/term) *)
        (*       End-goal: extesible table of all compilation lemmas -> (name, tactic to apply) *)
        (*       We can use names to have subsets of tactics (e.g. arithmetic only) *)
        | (match ?v0 with | 0 => ?v1 | S n' => @?v2 n' end) =>
          let binders_of_v2 := binders_names_of_constr_lambda v2 in
          let n_constr := List.nth binders_of_v2 0 in
          app_lemma "auto_nat_case" [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2); ("n", exactk n_constr)]
                                    [compile; (fun () => destruct $v0; (Control.enter compile))]
        | ?x =>
          if proper_const x then
            app_lemma "auto_nat_const" [("env", exactk fenv); ("x", exactk x)] []
          else
            Control.throw (Oopsie (fprintf
              "Error: Tried to compile a non-constant expression %t as a constant expression (%s kind)"
              x
              (kind_string_of_constr x)
            ))
        end
      in
      match extract_fun e with
      | None =>
        compile_go ()
      | Some (f, args) =>
        (* A function application *)
        let f_lookup := get_f_lookup_from_hyps () in
        let fname_opt := fname_if_in_f_lookup f_lookup f in
        match fname_opt with
        | Some fname =>
          (* Existing function that is in f_lookup (currently – in premises) *)
          let args_constr := list_to_constr_encode args in
          let fname_str := constr_string_of_string fname in
          refine open_constr:(trans_Call
          (* env *) $fenv
          (* xs *) _
          (* s1 s2 s3 *) _ _ _
          (* fname *) (name_enc $fname_str)
          (* vs *) $args_constr
          (* v *) (encode $e)
          (* eval args *) ltac2:(Control.enter compile)
          (* eval_app *) _
          )
        | _ =>
          compile_go ()
        end
      end
    end
  | ?fenv |-- (_, _) ---> ([], _) =>
    app_lemma "trans_nil" [("env", fun () => exact $fenv)] []
  | ?fenv |-- (_, _) ---> ((encode ?e) :: ?es, _) =>
    refine open_constr:(trans_cons
    (* env *) $fenv
    (* x *) _
    (* xs *) _
    (* v *) (encode $e)
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

Ltac2 rec var_ident_of_constr (c: constr): ident :=
  match Unsafe.kind c with
  | Var i => i
  | _ =>
    Control.throw (Oopsie (fprintf "Error: Expected the argument of a compiled function to be an variable reference, got: %t" c))
  end.

(* Top level tactic that compiles a program into FunLang *)
(* Handles expression evaluation and function evaluation as goals *)
Ltac2 rec docompile () :=
  lazy_match! goal with
  | [ |- ?_fenv |-- (_, _) ---> ([encode ?_c], _) ] =>
    (* let cenv := get_cenv_from_fenv_constr fenv in *)
    compile ()
  | [ h : (lookup_fun ?_fname _ = Some (?params, _))
  |- eval_app (name_enc ?fname) ?args _ (encode ?c, _) ] =>
    let h_hyp := Control.hyp h in
    (* let f_lookup := get_f_lookup_from_hyps () in *)
    (* let argsl := constr_list_of_encode_constr args in *)
    match extract_fun c with
    (* function reference --> unfold *)
    | Some (fconstr, fargs) =>
      let f_name_r := reference_of_constr fconstr in
      let fn_name_str := (Option.get (reference_to_string f_name_r)) in
      let fn_encoded_name_str := (string_of_constr_string fname) in
      (*  Check if the encoded name is the same as the compiled top level function *)
      if String.equal fn_encoded_name_str fn_name_str then
        (* If its a fixpoint apply `fname_equation`, otherwise unfold `fname` *)
        (if isFix fconstr then
          let arg1 := List.nth fargs 0 in
          let arg1_ident := var_ident_of_constr arg1 in
          revert $arg1_ident;
          ltac1:(let Hname := fresh "IH" in fix Hname 1);
          intros;
          rewrite_with_equation fconstr
        else
          unfold_ref_everywhere f_name_r
        );
        docompile ()
      else (
        (* top level function is different than the one currently compiling *)
        (* let compiled := compile argsl f_lookup c in *)
        refine open_constr:(trans_app
        (* n *) $fname
        (* params *) $params
        (* vs *) $args
        (* body *) _
        (* s *) _
        (* s1 *) _
        (* v *) (encode $c)
        (* eval body *) ltac2:(Control.enter(fun () => docompile ()))
        (* params length eq *) _
        (* lookup_fun *) $h_hyp
        )
      )
    (* unfolded function --> just compile *)
    | None =>
      (* let compiled := compile argsl f_lookup c in *)
      refine open_constr:(trans_app
      (* n *) $fname
      (* params *) $params
      (* vs *) $args
      (* body *) _
      (* s *) _
      (* s1 *) _
      (* v *) (encode $c)
      (* eval body *) ltac2:(Control.enter(fun () => docompile ()))
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
    repeat (match goal with
    | |- NoDup _ => simpl; repeat constructor; simpl
    | _ => progress auto
    | |- context[name_enc _] => unfold name_enc, name_enc_l; simpl
    | _ => congruence
    | |- not _ =>
      let hnm := fresh "Hcont" in
      intros Hnm
    | H: _ \/ _ |- _ => destruct H
    end)
  ).

Ltac2 relcompile_impl () :=
  unshelve (docompile ());
  crush_NoDup ();
  eauto with fenvDb.

Ltac2 Notation relcompile :=
  relcompile_impl ().

Ltac2 rec mk_constr_list (args: constr list): constr :=
  match args with
  | [] => open_constr:([])
  | h :: t =>
    let t_constr := mk_constr_list t in
    open_constr:($h :: $t_constr)
  end.

Ltac2 rec collect_prod_binders_impl (c: constr): binder list :=
  match Unsafe.kind c with
  | Prod b c =>
    b :: collect_prod_binders_impl c
  | _ => []
  end.
Ltac2 collect_prod_binders (c: constr): binder list :=
  collect_prod_binders_impl (Constr.type c).

Ltac2 rec gen_eval_app_impl (bs: binder list) (args: constr list) (f_constr_name: constr) (f: constr) (): constr :=
  match bs with
  | b :: bs =>
    let name := Option.default (Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "x"))) (Binder.name b) in
    let cont := Constr.in_context name (Binder.type b) (fun () =>
      let b_hyp := Control.hyp name in
      Control.refine (gen_eval_app_impl bs (b_hyp :: args) f_constr_name f)
    ) in
    match Constr.Unsafe.kind cont with
    | Lambda b body' => make (Prod b body')
    | _ => Control.throw_invalid_argument ""
    end
  | _ =>
    let encode_list_constr := mk_constr_list (List.map (fun c => open_constr:(encode $c)) args) in
    let applied_f := apply_to_args f args in
    open_constr:(eval_app (name_enc $f_constr_name) $encode_list_constr &s (encode $applied_f, &s))
  end.

Ltac2 gen_eval_app (f: constr) (): constr :=
  let f_constr_name := Option.get (Option.bind (reference_of_constr_opt f) reference_to_string) in
  let f_constr_name_c := constr_string_of_string f_constr_name in
  let f_binders := collect_prod_binders f in
  gen_eval_app_impl f_binders [] f_constr_name_c f ().

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
(*   i.e. why is add not a dependency? *)
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
  let f_binder_names := List.map (fun b =>
    let n := Option.default (Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "x"))) (Binder.name b) in
    constr_string_of_string (Ident.to_string n)
  ) f_binders in
  let encoded_b_names := mk_constr_list (List.map (fun n => constr:(name_enc $n)) f_binder_names) in
  let eval_app_cont := gen_eval_app f in
  (* TODO: this might be easier to use, if we exclude some spurious deps, like "add" *)
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
  intros.
  subst has_match_prog.
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
  subst sum_n_prog.
  intros.
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
  intros.
  subst bool_ops_prog.
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
  intros.
  subst has_cases_prog.
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
  intros.
  subst has_cases_list_prog.
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
  intros.
  subst foo_prog.
  relcompile.

  (* FEnv.lookup (FEnv.insert (30720%N, Some (encode 1)) (FEnv.insert (28160%N, Some (encode n)) FEnv.empty)) 28160%N = Some (encode n) *)
  eauto with fenvDb. (* TODO: this doesn't prove it! *)
  rewrite FEnv.lookup_insert_neq; try ltac1:(congruence).
  rewrite FEnv.lookup_insert_eq; reflexivity ().
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
  intros.
  subst bar_prog.
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
  intros.
  subst baz_prog.
  relcompile.

  eauto with fenvDb. (* TODO: this doesn't prove it! *)
  rewrite FEnv.lookup_insert_neq; try ltac1:(congruence).
  rewrite FEnv.lookup_insert_eq; reflexivity ().
Qed.

Definition baz2 (n : nat) : nat :=
  baz (n + 1) n.

Derive baz2_prog in ltac2:(relcompile_tpe 'baz2_prog 'baz2 ['baz]) as baz2_prog_proof.
(* Derive baz2_prog in (forall (s : state),
    (forall n m, eval_app (name_enc "baz") [encode n; encode m] s (encode (baz n m), s)) ->
    lookup_fun (name_enc "baz2") s.(funs) = Some ([name_enc "n"], baz2_prog) ->
    forall (n : nat),
      eval_app (name_enc "baz2") [encode n] s (encode (baz2 n), s))
  as baz2_prog_proof. *)
Proof.
  intros.
  subst baz2_prog.
  relcompile.
Qed.
