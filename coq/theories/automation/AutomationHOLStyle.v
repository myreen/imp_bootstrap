(* From impboot Require Import utils.Core.
From coqutil Require Import dlet.
Require Import impboot.functional.FunValues.
(* Require Import impboot.functional.FunSyntax. *)
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.
From impboot Require Import automation.Ltac2Utils.
From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import
  Tactics.reference_to_string
  Tactics.ident_of_string
  Tactics.ident_to_string.
From Coq Require Import derive.Derive.
From Coq Require Import FunInd.

Open Scope nat.

Definition empty_state : state := init_state Lnil [].

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

Ltac2 rec assemble_lemma (lemma_inst: constr) (lname: string) (extracted_terms: constr option list)
                         (continuations: (unit -> unit) list): constr :=
  let lemma_inst := eval_cbv beta lemma_inst in
  match maybe_thm_binder lemma_inst with
  | None => lemma_inst
  | Some b =>
    match Binder.name b with
    | Some _nm =>
      (* named binder -> term *)
      match extracted_terms with
      | (Some ext) :: extracted_terms =>
        (* TODO: check the $extr                vvvvv *)
        assemble_lemma open_constr:($lemma_inst $ext) lname extracted_terms continuations
      | None :: extracted_terms =>
        assemble_lemma open_constr:($lemma_inst _) lname extracted_terms continuations
      | _ =>
        Control.throw (Oopsie (fprintf "Not enough extracted terms passed when compiling with lemma %s" lname))
      end
    | None =>
      (* unnamed binder -> use continuations *)
      match continuations with
      | k :: continuations =>
        assemble_lemma open_constr:($lemma_inst ltac2:(Control.enter k)) lname extracted_terms continuations
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
Ltac2 app_lemma (lname: string) (extracted_terms: constr option list)
                (continuations: (unit -> unit) list): unit :=
  let lemma_ref: reference := List.hd (Env.expand (ident_of_fqn [lname])) in
  let lemma_inst: constr := Env.instantiate lemma_ref in
  (* let lemma_tpe: constr := type lemma_inst in *)
  (* let thm_parts := split_thm_args lemma_tpe in *)
  (* TODO(kπ): we assume that `env` is the first argument, can we just special case fenv and pass it to every `FEnv.env` premise? *)
  (*           Otherwise, just pass it as a normal "extracted_terms" parameter to this function? *)
  refine (assemble_lemma lemma_inst lname extracted_terms continuations).

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

Ltac2 rec constr_list_of_constr (c : constr) : constr list :=
  match! c with
  | [] => []
  | ?x :: ?xs => x :: constr_list_of_constr xs
  end.

Ltac2 rec get_cenv_from_fenv_constr (fenv: constr) : constr list :=
  lazy_match! fenv with
  | FEnv.insert (?_n, Some (encode ?v)) ?fenv =>
    let acc := get_cenv_from_fenv_constr fenv in
    v :: acc
  | FEnv.insert (?_n, None) ?fenv =>
    get_cenv_from_fenv_constr fenv
  | make_env ?_ns ?vs ?fenv =>
    let acc := get_cenv_from_fenv_constr fenv in
    (* let names := List.map (fun c => string_of_constr_string c) (constr_list_of_constr ns) in *)
    let values := constr_list_of_encode_constr vs in
    List.append values acc
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

(* TODO:
- maybe make continuations to options and do open_constr:(_) as default
- be more clever about which arguments are implicit and only provide continuations for non impicit parameters?
- ask Clement about that. Is there a convention of what should be impicit?
- automate the setup for fix and everything around that (Would be cool to just run `relcompile` and for it to just work)
*)

(* The priority of lemmas is as follows: *)
(* 1: variables *)
(* 2: functions from f_lookup *)
(* 3: other automation lemmas *)
(*   3.1: functions *)
(*   3.2: dlet *)
(*   3.x: "normal" automation lemmas *)
(*   3.last: constants *)
(* TODO(kπ) track free variables to name let_n (use Ltac2.Free) *)
Ltac2 rec compile () : unit :=
  let c := Control.goal () in
  lazy_match! c with
  | ?fenv |-- (_, _) ---> ([encode ?e], _) =>
    let cenv := get_cenv_from_fenv_constr fenv in
    printf "Compiling expression: %t with cenv %a" e (fun () cenv => message_of_list (List.map Message.of_constr cenv)) cenv;
    match List.find_opt (Constr.equal e) cenv with
    | Some _ =>
      refine open_constr:(trans_Var
      (* env *) _
      (* s *) _
      (* n *) _
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
          refine open_constr:(auto_let
          (* env *) $fenv
          (* x1 y1 *) _ _
          (* s1 s2 s3 *) _ _ _
          (* v1 *) $val
          (* let_n *) _
          (* f *) $body
          (* eval v1 *) ltac2:(Control.enter compile)
          (* eval f *) ltac2:(Control.enter (fun () => cbv beta; compile ()))
          )
        | (let x := ?val in @?body x) =>
          (* might work, but normal `let`s get inlined before (maybe because of the "cbv beta" after unfolding) *)
          refine open_constr:(auto_let
          (* env *) $fenv
          (* x1 y1 *) _ _
          (* s1 s2 s3 *) _ _ _
          (* v1 *) $val
          (* let_n *) _
          (* f *) $body
          (* eval v1 *) ltac2:(Control.enter compile)
          (* eval f *) ltac2:(Control.enter (fun () => cbv beta; compile ()))
          )
        (* bool *)
        | true =>
          app_lemma "auto_bool_T" [Some fenv; None] []
        | false =>
          app_lemma "auto_bool_F" [Some fenv; None] []
        | (negb ?b) =>
          app_lemma "auto_bool_not" [Some fenv; None; None; Some b] [compile]
        | (andb ?bA ?bB) =>
          app_lemma "auto_bool_and" [Some fenv; None; None; None; Some bA; Some bB] [compile; compile]
        | (eqb ?bA ?bB) =>
          app_lemma "auto_bool_iff" [Some fenv; None; None; None; Some bA; Some bB] [compile; compile]
        | (if ?b then ?t else ?f) =>
          app_lemma "last_bool_if" [None; None; Some fenv; None; None; None; None; Some b; Some t; Some f]
                                   [compile; compile; compile]
        (* nat *)
        | (?n1 + ?n2) =>
          app_lemma "auto_nat_add" [Some fenv; None; None; None; None; None; Some n1; Some n2]
                                   [compile; compile]
        | (?n1 - ?n2) =>
          app_lemma "auto_nat_sub" [Some fenv; None; None; None; Some n1; Some n2] [compile; compile]
        | (?n1 / ?n2) =>
          app_lemma "auto_nat_div" [Some fenv; None; None; None; Some n1; Some n2] [compile; compile]
        | (if Nat.eqb ?n1 ?n2 then ?t else ?f) =>
          app_lemma "auto_nat_if_eq" [Some fenv; None; None; None; Some n1; Some n2; Some t; Some f]
                                     [compile; compile]
        | (if ?n1 <? ?n2 then ?t else ?f) =>
          app_lemma "auto_nat_if_less" [Some fenv; None; None; None; Some n1; Some n2; Some t; Some f]
                                       [compile; compile]
        (* list *)
        | [] =>
          app_lemma "auto_list_nil" [Some fenv; None] []
        | (?x :: ?xs) =>
          app_lemma "auto_list_cons" [None; None; Some fenv; None; None; Some x; Some xs] [compile; compile]
        | (match ?v0 with | nil => ?v1 | h :: t => @?v2 h t end) =>
          app_lemma "auto_list_case" [None; None; None; None; Some fenv; None; None; None; None; None; None; Some v0; Some v1; Some v2]
                                     [compile; (fun () => destruct $v0; (Control.enter compile)); (fun () => ())]
        (* TODO: see if we can use pairs (name -> tactic/term) *)
        (*       End-goal: extesible table of all compilation lemmas -> (name, tactic to apply) *)
        (*       We can use names to hae subsets of tactics (e.g. arithmetic only) *)
        | (match ?v0 with | 0 => ?v1 | S n' => @?v2 n' end) =>
          app_lemma "auto_nat_case" [None; None; Some fenv; None; None; None; None; None; Some v0; Some v1; Some v2]
                                    [compile; (fun () => destruct $v0; (Control.enter compile))]
        | ?x =>
          if proper_const x then
            app_lemma "auto_nat_const" [Some fenv; None; Some x] []
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
    app_lemma "trans_nil" [Some fenv; None] []
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

(* Top level tactic that compiles a program into FunLang *)
(* Handles expression evaluation and function evaluation as goals *)
Ltac2 rec docompile () :=
  lazy_match! goal with
  | [ |- ?_fenv |-- (_, _) ---> ([encode ?_c], _) ] =>
    (* let cenv := get_cenv_from_fenv_constr fenv in *)
    compile ();
    intros;
    eauto with fenvDb
  | [ h : (lookup_fun ?_fname _ = Some (?params, _))
  |- eval_app (name_enc ?fname) ?args _ (encode ?c, _) ] =>
    let h_hyp := Control.hyp h in
    (* let f_lookup := get_f_lookup_from_hyps () in *)
    (* let argsl := constr_list_of_encode_constr args in *)
    match extract_fun c with
    (* function reference --> unfold *)
    | Some (fconstr, _) =>
      let f_name_r := reference_of_constr fconstr in
      let fn_name_str := (Option.get (reference_to_string f_name_r)) in
      let fn_encoded_name_str := (string_of_constr_string fname) in
      (*  Check if the encoded name is the same as the compiled top level function *)
      if String.equal fn_encoded_name_str fn_name_str then
        (* If its a fixpoint apply `fname_equation`, otherwise unfold `fname` *)
        (if isFix fconstr then
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
        );
        intros;
        eauto with fenvDb
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
      );
      (* intros; *)
      eauto with fenvDb
    end
  | [ |- ?x ] =>
    Control.throw (Oopsie (fprintf "Error: Don't know how to compile %t" x))
  end.

Ltac2 Notation relcompile :=
  docompile ().

Function has_match (l: list nat) : nat :=
  1 +
  match l with
  | nil => 0
  | cons h t => h + 100
  end.

(* TODO(kπ): lookups might grow Qed time. Might want to rewrite them to multi-inserts *)

(* Derive has_match_prog in (forall s l,
  lookup_fun (name_enc "has_match") s.(funs) = Some ([name_enc "l"], has_match_prog) ->
  eval_app (name_enc "has_match") [encode l] s (encode (has_match l), s)
) as has_match_proof.
Proof.
  intros.
  subst has_match_prog.
  relcompile.
  Show Proof.
  Unshelve.
  all: subst; unfold make_env; eauto with fenvDb.
  3: exact "h"%string.
  3: exact "t"%string.
  3: exact "h"%string.
  all: eauto with fenvDb.
  simpl; ltac1:(repeat constructor).
  all: intro Hcont; unfold In in *; ltac1:(try contradiction); inversion Hcont; inversion H0.
Qed. *)

Fixpoint sum_n (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 => (sum_n n1) + n
  end.
Lemma sum_n_equation : ltac:(unfold_tpe sum_n).
Proof. ltac1:(unfold_proof). Qed.
About sum_n_equation.

Derive sum_n_prog in (forall (s: state),
    lookup_fun (name_enc "sum_n") s.(funs) = Some ([name_enc "n"], sum_n_prog) ->
    forall (n : nat),
      eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s))
  as sum_n_prog_proof.
Proof.
  subst sum_n_prog.
  intros * H.
  ltac1:(fix IH 1).
  Show Proof.
  intros.
  relcompile.
  Show Proof.
  Guarded.
  Unshelve.
  all: unfold make_env; eauto with fenvDb.
  2: exact "n1"%string.
  2: exact "n"%string.
  eauto with fenvDb.
Qed.
Print sum_n_prog.
Print sum_n_prog_proof.

Definition bool_ops (b: bool): bool :=
  b && true.

Derive bool_ops_prog in (forall (s : state) (b : bool),
    lookup_fun (name_enc "bool_ops") s.(funs) = Some ([name_enc "b"], bool_ops_prog) ->
    eval_app (name_enc "bool_ops") [encode b] s (encode (bool_ops b), s))
  as bool_ops_prog_proof.
Proof.
  intros.
  subst bool_ops_prog.
  relcompile.
  Show Proof.
  Unshelve.
  all: unfold make_env; eauto with fenvDb.
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
Print has_cases.

Derive has_cases_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "has_cases") s.(funs) = Some ([name_enc "n"], has_cases_prog) ->
    eval_app (name_enc "has_cases") [encode n] s (encode (has_cases n), s))
  as has_cases_proof.
Proof.
  intros.
  subst has_cases_prog.
  relcompile.
  Show Proof.
  Unshelve.
  all: unfold make_env; eauto with fenvDb.
  3: exact "n"%string.
  3: exact "n1"%string.
  3: exact "n2"%string.
  3: exact "n2"%string.
  all: eauto with fenvDb.
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

Derive has_cases_list_prog in (forall (s : state) (l : list nat),
    lookup_fun (name_enc "has_cases_list") s.(funs) = Some ([name_enc "l"], has_cases_list_prog) ->
    eval_app (name_enc "has_cases_list") [encode l] s (encode (has_cases_list l), s))
  as has_cases_list_proof.
Proof.
  intros.
  subst has_cases_list_prog.
  relcompile.
  Show Proof.
  Unshelve.
  all: unfold make_env; eauto with fenvDb.
  5: exact "hd"%string.
  5: exact "tl"%string.
  5: exact "hdtl"%string.
  5: exact "tltl"%string.
  5: exact "hd"%string.
  5: exact "hdtl"%string.
  all: eauto with fenvDb.
  all: simpl; ltac1:(repeat constructor).
  all: intro Hcont; unfold In in *; ltac1:(try contradiction); inversion Hcont; inversion H0.
Qed.

Definition foo (n : nat) : nat :=
  let/d x := 1 in
  let/d y := n + x in
  y.

Derive foo_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "foo") s.(funs) = Some ([name_enc "n"], foo_prog) ->
    eval_app (name_enc "foo") [encode n] s (encode (foo n), s))
  as foo_prog_proof.
Proof.
  intros.
  subst foo_prog.
  relcompile.
  Show Proof.
  Unshelve.
  2: exact "x"%string.
  2: exact "y"%string.
  2: exact "n"%string.
  eauto with fenvDb.
Qed.

Definition bar (n : nat) : nat :=
  foo (n + 1).

Derive bar_prog in (forall (s : state) (n : nat),
    (forall m, eval_app (name_enc "foo") [encode m] s (encode (foo m), s)) ->
    lookup_fun (name_enc "bar") s.(funs) = Some ([name_enc "n"], bar_prog) ->
    eval_app (name_enc "bar") [encode n] s (encode (bar n), s))
  as bar_prog_proof.
Proof.
  intros.
  subst bar_prog.
  relcompile.
  Show Proof.
  Unshelve.
  all: unfold make_env; eauto with fenvDb.
Qed.

Definition baz (n m : nat) : nat :=
  let/d z := n + m in
  z.

Derive baz_prog in (forall (s : state) (n m : nat),
    lookup_fun (name_enc "baz") s.(funs) = Some ([name_enc "n"; name_enc "m"], baz_prog) ->
    eval_app (name_enc "baz") [encode n; encode m] s (encode (baz n m), s))
  as baz_prog_proof.
Proof.
  intros.
  subst baz_prog.
  relcompile.
  Show Proof.
  Unshelve.
  all: unfold make_env; eauto with fenvDb.
  2: exact "n"%string.
  2: exact "n"%string.
  all: eauto with fenvDb.
Qed.

Definition baz2 (n : nat) : nat :=
  baz (n + 1) n.

Derive baz2_prog in (forall (s : state) (n : nat),
    (forall n m, eval_app (name_enc "baz") [encode n; encode m] s (encode (baz n m), s)) ->
    lookup_fun (name_enc "baz2") s.(funs) = Some ([name_enc "n"], baz2_prog) ->
    eval_app (name_enc "baz2") [encode n] s (encode (baz2 n), s))
  as baz2_prog_proof.
Proof.
  intros.
  subst baz2_prog.
  relcompile.
  Show Proof.
  Unshelve.
  all: unfold make_env; eauto with fenvDb.
Qed. *)
