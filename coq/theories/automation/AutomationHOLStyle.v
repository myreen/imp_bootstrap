From impboot Require Import utils.Core.
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

(* TODO(kπ):
- consider using preterm instead of open_constr if thing get too slow
*)

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

(* TODO(kπ): this version doesn't work - loops infinitely *)
Ltac2 rec split_thm (c: constr): constr list :=
  lazy_match! c with
  | (∀ x, @?f x) =>
    x :: split_thm f
  | _ => []
  end.

Ltac2 rec split_thm_args (c: constr): constr list :=
  match Unsafe.kind c with
  | Prod b c1 =>
    (Binder.type b) :: split_thm_args c1
  | _ => []
  end.

Ltac2 intro_then (nm: string) (k: constr -> constr): constr :=
  open_constr:(ltac2:(Control.enter (fun () =>
    let x := Fresh.in_goal (Option.get (Ident.of_string nm)) in
    Std.intros false [IntroNaming (IntroFresh x)];
    let x_constr := (Control.hyp x) in
    Control.refine (fun () =>
      k x_constr
    )
  ))).

Ltac2 rec apply_thm (thm: constr) (args: constr list): constr :=
  match args with
  | [] => thm
  | arg :: args =>
    apply_thm open_constr:($thm $arg) args
  end.

Ltac2 isPropTerm (c: constr): bool :=
  printf "Checking type of %t with type %t" c (Constr.type c);
  Constr.equal (Constr.type c) constr:(Prop).

(* Named arguments -> automation relevant *)
(* Unnamed arguments -> irrelevant (side conditions) *)
Ltac2 rec compile_if_needed (compile_fn: constr list -> constr -> constr) (cenv: constr list)
                            (extracted: constr) (thm_part: constr): constr :=
  match! thm_part with
  | _ |-- (_, _) ---> (_, _) =>
    compile_fn cenv extracted
  | _ =>
    match Unsafe.kind thm_part with
    | Prod x f =>
      (* TODO(kπ): We ideally would like to use the type (Constr.type (Binder.type x) == Prop), but it throws an exception *)
      (*           Something about part of the type being free. *)
      (* if isPropTerm (Binder.type x) then *)
      match Binder.name x with
      | Some _ =>
        intro_then "x_nm" (fun x_constr =>
          compile_if_needed compile_fn (x_constr :: cenv) (eval_cbv beta open_constr:($extracted $x_constr)) f
        )
      | None =>
        intro_then "x_nm" (fun _ =>
          compile_if_needed compile_fn cenv extracted f
        )
      end
    | _ => open_constr:(_)
    end
  end.

Ltac2 rec compile_if_needed_pair (compile_fn: constr list -> constr -> constr) (cenv: constr list)
                                 (part_pair: (constr * constr) option): constr :=
  match part_pair with
  | None => open_constr:(_)
  | Some (extracted, thm_part) =>
    compile_if_needed compile_fn cenv extracted thm_part
  end.

Ltac2 rec isCompilable (c: constr): bool :=
  match! c with
  | _ |-- (_, _) ---> (_, _) => true
  | _ =>
    match Constr.Unsafe.kind c with
    | Prod _ c1 => isCompilable c1
    | _ => false
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
(*   Fill in `extracted` terms for "eval" premises *)
(*   (Also make sure to update the `cenv` while recursing) *)
Ltac2 app_lemma (compile_fn: constr list -> constr -> constr) (cenv : constr list) (lname: string) (extracted: constr list) :=
  let lemma_ref: reference := List.hd (Env.expand (ident_of_fqn [lname])) in
  let lemma_inst: constr := Env.instantiate lemma_ref in
  let lemma_tpe: constr := type lemma_inst in
  let thm_parts := split_thm_args lemma_tpe in
  let paired_parts := List.rev (pair_thm_parts thm_parts extracted []) in
  let compiled_parts := List.map (compile_if_needed_pair compile_fn cenv) paired_parts in
  apply_thm lemma_inst compiled_parts.

(* Lookup the funciton `fname` in the `f_lookup` map *)
Ltac2 f_lookup_name (f_lookup : (string * constr) list) (fname : string) : constr option :=
  match List.find_opt (fun (name, _) => String.equal name fname) f_lookup with
  | Some (_, c) => Some c
  | None => None
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

Ltac2 rec constr_list_of_constr (c : constr) : constr list :=
  match! c with
  | [] => []
  | ?x :: ?xs => x :: constr_list_of_constr xs
  end.

Ltac2 rec get_cenv_from_fenv_constr (fenv: constr) : constr list :=
  lazy_match! fenv with
  | FEnv.insert (?_n, ?v) ?fenv =>
    let acc := get_cenv_from_fenv_constr fenv in
    v :: acc
  | make_env ?_ns ?vs ?fenv =>
    let acc := get_cenv_from_fenv_constr fenv in
    (* let names := List.map (fun c => string_of_constr_string c) (constr_list_of_constr ns) in *)
    let values := constr_list_of_constr vs in
    List.append values acc
  | _ => []
  end.

Ltac2 rec compile_list_of_exprs (compile_fn: constr list -> constr -> constr) (cenv : constr list) (e0 : constr list): constr :=
  match e0 with
  | [] =>
    app_lemma compile_fn cenv "trans_nil" []
  | e :: es =>
    let compile_e := compile_fn cenv e in
    let compile_es := compile_list_of_exprs compile_fn cenv es in
    open_constr:(trans_cons
    (* x *) _
    (* xs *) _
    (* v *) _
    (* vs *) _
    (* env *) _
    (* s s1 s2 *) _ _ _
    (* eval x *) $compile_e
    (* eval xs *) $compile_es
    )
  end.

(* The priority of lemmas is as follows: *)
(* 1: variables *)
(* 2: functions from f_lookup *)
(* 3: other automation lemmas *)
(*   3.1: functions *)
(*   3.2: dlet *)
(*   3.x: "normal" automation lemmas *)
(*   3.last: constants *)
(* TODO(kπ) track free variables to name let_n (use Ltac2.Free) *)
Ltac2 rec compile (cenv : constr list) (f_lookup : (string * constr) list) (c : constr) : constr :=
  let compile_nofl := (fun cenv => compile cenv f_lookup) in
  let app_lemma_fixed := app_lemma compile_nofl cenv in
  let compile_list_exprs_fixed := compile_list_of_exprs compile_nofl cenv in
  printf "Compiling expression: %t with cenv %a" c (fun () cenv => message_of_list (List.map Message.of_constr cenv)) cenv;
  lazy_match! c with
  | ?fenv |-- (_, _) ---> ([encode ?e], _) =>
    (* TODO(kπ): Shadow cenv to test if we can get rid of it *)
    let cenv := get_cenv_from_fenv_constr fenv in
    let compCenv := get_cenv_from_fenv_constr fenv in
    printf "Compiling expression: %t with compCenv %a" e (fun () cenv => message_of_list (List.map Message.of_constr cenv)) compCenv;
    match List.find_opt (Constr.equal e) cenv with
    | Some _ =>
      open_constr:(trans_Var
      (* env *) _
      (* s *) _
      (* n *) _
      (* v *) $e
      (* FEnv.lookup *) _
      )
    | None =>
      let compile_go :=
        lazy_match! e with
        (* TODO(kπ): can we assume that we only compile lambdas, when we created them in the previous step? *)
        (*           For now, we assume so, and require that any argument in *)
        (*           automation lemma has to be followed by a precondition *)
        (*       kπ: This might be worked around with automatic lemma application – we look at the lemma premise, not the term *)
        (*           But then how do we know if an argument corresponds to a value or to a precondition? (== Prop) *)
        | (fun x => @?f x) =>
          printf "POTENTIAL ERROR: trying to compile a function in the wild, namely %t" e;
          intro_then "x_nm" (fun x_constr =>
            intro_then "x_precond" (fun _ =>
              compile (x_constr :: cenv) f_lookup (eval_cbv beta open_constr:($f $x_constr))
            )
          )
        | (dlet ?val ?body) =>
          let compiled_val := compile cenv f_lookup val in
          let applied_body := eval_cbv beta open_constr:($body $val) in
          let compiled_body := compile (val :: cenv) f_lookup applied_body in
          open_constr:(auto_let
          (* env *) _
          (* x1 y1 *) _ _
          (* s1 s2 s3 *) _ _ _
          (* v1 *) $val
          (* let_n *) _
          (* f *) $body
          (* eval v1 *) $compiled_val
          (* eval f *) $compiled_body
          )
        (* bool *)
        | true =>
          app_lemma_fixed "auto_bool_T" []
        | false =>
          app_lemma_fixed "auto_bool_F" []
        | (negb ?b) =>
          app_lemma_fixed "auto_bool_not" [b]
        | (andb ?bA ?bB) =>
          app_lemma_fixed "auto_bool_and" [bA; bB]
        | (eqb ?bA ?bB) =>
          app_lemma_fixed "auto_bool_iff" [bA; bB]
        | (if ?b then ?t else ?f) =>
          app_lemma_fixed "last_bool_if" [b; t; f]
        (* nat *)
        | (?n1 + ?n2) =>
          app_lemma_fixed "auto_nat_add" [n1; n2]
        | (?n1 - ?n2) =>
          app_lemma_fixed "auto_nat_sub" [n1; n2]
        | (?n1 / ?n2) =>
          app_lemma_fixed "auto_nat_div" [n1; n2]
        | (if Nat.eqb ?n1 ?n2 then ?t else ?f) =>
          app_lemma_fixed "auto_nat_if_eq" [n1; n2; t; f]
        | (if ?n1 <? ?n2 then ?t else ?f) =>
          app_lemma_fixed "auto_nat_if_less" [n1; n2; t; f]
        (* list *)
        | [] =>
          app_lemma_fixed "auto_list_nil" []
        | (?x :: ?xs) =>
          app_lemma_fixed "auto_list_cons" [x; xs]
        | (match ?v0 with | nil => ?v1 | h :: t => @?v2 h t end) =>
          app_lemma_fixed "auto_list_case" [v0; v1; v2]
        | (match ?v0 with | 0 => ?v1 | S n' => @?v2 n' end) =>
          app_lemma_fixed "auto_nat_case" [v0; v1; v2]
        | ?x =>
          if proper_const x then
            app_lemma_fixed "auto_nat_const" [x]
          else
            (printf "f_lookup %a" (fun _ => message_of_f_lookup) f_lookup;
            (Control.throw (Oopsie (fprintf
              "Error: Tried to compile a non-constant expression %t as a constant expression (%s kind)"
              x
              (kind_string_of_constr x)
            ));
            open_constr:(_)))
        end
      in
      match extract_fun e with
      | None =>
        compile_go
      | Some (f, args) =>
        (* A function application *)
        let f_name_r: reference option := reference_of_constr_opt f in
        let f_name_str := Option.bind f_name_r reference_to_string in
        let f_constr_opt := Option.bind f_name_str (f_lookup_name f_lookup) in
        match f_constr_opt, f_name_str with
        | (Some _, Some fname) =>
          (* Existing function that is in f_lookup (currently – in premises) *)
          let compile_args := compile_list_exprs_fixed args in
          let fname_str := constr_string_of_string fname in
          printf "f_lookup";
          print (message_of_f_lookup f_lookup);
          open_constr:(trans_Call
          (* env *) _
          (* xs *) _
          (* s1 s2 s3 *) _ _ _
          (* fname *) (name_enc $fname_str)
          (* vs *) _
          (* v *) (encode $e)
          (* eval args *) $compile_args
          (* eval_app *) _
          )
        | _ =>
          compile_go
        end
      end
    end
  | _ =>
    Control.throw (Oopsie (fprintf "Error: Malformed input to compile, namely %t" c))
  end.

Ltac2 rec has_make_env (c: constr): bool :=
  match! c with
  | (FEnv.insert _ ?c) => has_make_env c
  | make_env _ _ _ => true
  | _ => false
  end.

Ltac2 normalize_compile (f_lookup : (string * constr) list) (e : constr) : constr :=
  lazy_match! e with
  | ?fenv |-- (_, _) ---> ([encode ?c], _) =>
    if has_make_env fenv then
      open_constr:(ltac2:(Control.enter(fun () =>
        unfold make_env;
        Control.refine(fun () =>
          compile [] f_lookup c
        )
      )))
    else
      compile [] f_lookup e
  | _ => compile [] f_lookup e
  end.

Ltac2 rec constr_list_of_encode_constr (c : constr) : constr list :=
  match! c with
  | [] => []
  | (encode ?x) :: ?xs => x :: constr_list_of_encode_constr xs
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

Ltac2 unfold_ref_everywhere (r: reference): unit :=
  let cl := default_on_concl None in
  Std.unfold [(r, AllOccurrences)] cl.

(* Top level tactic that compiles a program into FunLang *)
(* Handles expression evaluation and function evaluation as goals *)
Ltac2 rec docompile () :=
  lazy_match! goal with
  | [ |- ?fenv |-- (_, _) ---> ([encode ?_c], _) ] =>
    let cenv := get_cenv_from_fenv_constr fenv in
    let f_lookup := get_f_lookup_from_hyps () in
    refine (compile cenv f_lookup (Control.goal ()));
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
      intros;
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

Derive has_match_prog in (forall s l,
  lookup_fun (name_enc "has_match") s.(funs) = Some ([name_enc "l"], has_match_prog) ->
  eval_app (name_enc "has_match") [encode l] s (encode (has_match l), s)
) as has_match_proof.
Proof.
  intros.
  subst has_match_prog.
  relcompile.
  Show Proof.
  Unshelve.
Abort.

Fixpoint sum_n (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 => (sum_n n1) + n
  end.
Lemma sum_n_equation : ltac:(unfold_tpe sum_n).
Proof. ltac1:(unfold_proof). Qed.
About sum_n_equation.

Derive sum_n_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "sum_n") s.(funs) = Some ([name_enc "n"], sum_n_prog) ->
    eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s))
  as sum_n_prog_proof.
Proof.
  intros.
  subst sum_n_prog.
  induction n.
  2: { (* Inductive case *)
    relcompile.
    Show Proof.
    Unshelve.
    13: {
      inversion x_nm0; subst.
      (* assumption (). *) (* TODO(kπ): Ltac2 assumption bug? why does exact work, but assumption doesn't? *)
      exact IHn.
    }
    all: ltac1:(shelve).
  }
  (* TODO(kπ): What should we do in the 0 case of induction? *)
  (*       kπ: Do we just symbolically evaluate? *)
  1: {
    eapply trans_app; eauto; eauto; unfold make_env.
    ltac1:(repeat (econstructor; eauto with fenvDb)).
  }
  (* TODO(kπ): Check if this is correct *)
  Unshelve.
  all: unfold make_env; eauto with fenvDb.
  1: exact "n1"%string.
  1: exact "n"%string.
  2: eauto with fenvDb.
  exact FEnv.empty.
Qed.

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
Abort.

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
Abort.

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
Abort.

Definition foo (n : nat) : nat :=
  letd x := 1 in
  letd y := n + x in
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
  1: exact "x"%string.
  1: exact "y"%string.
  1: exact "n"%string.
  1: exact "x"%string.
  1: exact "y"%string.
  all: eauto with fenvDb.
Qed.

Definition bar (n : nat) : nat :=
  foo (n + 1).

Derive bar_prog in (forall (s : state) (n : nat),
    (* TODO(kπ): I'm pretty sure that we don't want to add this vvv (we only want `eval_app`) *)
    (* lookup_fun (name_enc "foo") s.(funs) = Some ([name_enc "n"], foo_prog) -> *)
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
  1: exact FEnv.empty.
Qed.

Definition baz (n m : nat) : nat :=
  letd z := n + m in
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
  1: exact "n"%string.
  1: exact "z"%string.
  all: eauto with fenvDb.
Qed.

Definition baz2 (n : nat) : nat :=
  baz (n + 1) n.

Derive baz2_prog in (forall (s : state) (n : nat),
    (* TODO(kπ): I'm pretty sure that we don't want to add this vvv (we only want `eval_app`) *)
    (* lookup_fun (name_enc "baz") s.(funs) = Some ([name_enc "n"; name_enc "m"], baz_prog) -> *)
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
  exact FEnv.empty.
Qed.
Print baz2_prog.
