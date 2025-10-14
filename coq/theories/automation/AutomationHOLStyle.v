From impboot Require Import utils.Core.
From impboot Require Import utils.AppList.
From coqutil Require Import dlet.
From coqutil Require Import Word.Interface.
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
    intro_then (Option.get (Ident.of_string "x_nm")) (fun _ =>
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

Ltac2 rec binders_of_constr_lambda (c: constr): binder list :=
  match Unsafe.kind c with
  | Lambda b c1 =>
    b :: binders_of_constr_lambda c1
  | _ => []
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
    (* printf "Goal: %t" c; *)
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
          intro_then (Option.get (Ident.of_string "x_nm")) (fun _ =>
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
          app_lemma "auto_nat_add" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)]
                                   [compile; compile]
        | (?n1 - ?n2)%nat =>
          app_lemma "auto_nat_sub" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
        | (?n1 / ?n2)%nat =>
          app_lemma "auto_nat_div" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2)] [compile; compile]
        | (if Nat.eqb ?n1 ?n2 then ?t else ?f) =>
          app_lemma "auto_nat_if_eq" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
                                     [compile; compile; compile; compile]
        | (if Nat.ltb ?n1 ?n2 then ?t else ?f) =>
          app_lemma "auto_nat_if_less" [("env", exactk fenv); ("n1", exactk n1); ("n2", exactk n2); ("t", exactk t); ("f", exactk f)]
                                       [compile; compile; compile; compile]
        | (match ?v0 with | 0 => ?v1 | S n' => @?v2 n' end) =>
          let binders_of_v2 := binders_names_of_constr_lambda v2 in
          let n_constr := List.nth binders_of_v2 0 in
          app_lemma "auto_nat_case" [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2); ("n", exactk n_constr)]
                                    [compile; (fun () => destruct $v0; (Control.enter compile))]
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
        (* option *)
        | None =>
          app_lemma "auto_option_none" [("env", exactk fenv)] []
        | (Some ?x) =>
          app_lemma "auto_option_some" [("env", exactk fenv); ("x", exactk x)] [compile]
        | (match ?v0 with | None => ?v1 | Some x => @?v2 x end) =>
          let binders_of_v2 := binders_names_of_constr_lambda v2 in
          let n_constr := List.nth binders_of_v2 0 in
          app_lemma "auto_option_case" [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2); ("n", exactk n_constr)]
                                       [compile; (fun () => destruct $v0; (Control.enter compile))]
        (* pair *)
        | (fst ?x) =>
          app_lemma "auto_pair_fst" [("env", exactk fenv); ("x", exactk x)] [compile]
        | (snd ?x) =>
          app_lemma "auto_pair_snd" [("env", exactk fenv); ("x", exactk x)] [compile]
        | (?x, ?y) =>
          app_lemma "auto_pair_cons" [("env", exactk fenv); ("x", exactk x); ("y", exactk y)] [compile; compile]
        | (match ?v0 with | (x, y) => @?v2 x y end) =>
          let binders_of_v2 := binders_names_of_constr_lambda v2 in
          let n1_constr := List.nth binders_of_v2 0 in
          let n2_constr := List.nth binders_of_v2 1 in
          app_lemma "auto_pair_case" [("env", exactk fenv); ("v0", exactk v0); ("v2", exactk v2); ("n1", exactk n1_constr); ("n2", exactk n2_constr)]
                                     [compile; (fun () => destruct $v0; (Control.enter compile))]
        (* app_list *)
        | List ?xs =>
          app_lemma "auto_app_list_cons_List" [("env", exactk fenv); ("xs", exactk xs)] [compile]
        | Append ?l1 ?l2 =>
          app_lemma "auto_app_list_cons_Append" [("env", exactk fenv); ("l1", exactk l1); ("l2", exactk l2)] [compile; compile]
        | (match ?v0 with
           | List xs => @?v1 xs
           | Append l1 l2 => @?v2 l1 l2
           end) =>
          let binders_v1 := binders_names_of_constr_lambda v1 in
          let binders_v2 := binders_names_of_constr_lambda v2 in
          let n1 := List.nth binders_v1 0 in
          let n2 := List.nth binders_v2 0 in
          let n3 := List.nth binders_v2 1 in
          app_lemma "auto_app_list_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                           ("v1", exactk v1); ("v2", exactk v2);
                                           ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3)]
                                         [compile; (fun () => destruct $v0; (Control.enter compile)); (fun () => ())]
        (* cmp *)
        | ImpSyntax.Less =>
          app_lemma "auto_cmp_cons_Less" [("env", exactk fenv)] []
        | ImpSyntax.Equal =>
          app_lemma "auto_cmp_cons_Equal" [("env", exactk fenv)] []
        | (match ?v0 with | ImpSyntax.Less => ?v1 | ImpSyntax.Equal => ?v2 end) =>
          app_lemma "auto_cmp_CASE" [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("v2", exactk v2)]
                                    [compile; (fun () => destruct $v0; (Control.enter compile))]
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
           | ImpSyntax.Skip => ?v1
           | ImpSyntax.Seq c1 c2 => @?v2 c1 c2
           | ImpSyntax.Assign n e => @?v3 n e
           | ImpSyntax.Update a e e' => @?v4 a e e'
           | ImpSyntax.If t c1 c2 => @?v5 t c1 c2
           | ImpSyntax.While t c => @?v6 t c
           | ImpSyntax.Call n f es => @?v7 n f es
           | ImpSyntax.Return e => @?v8 e
           | ImpSyntax.Alloc n e => @?v9 n e
           | ImpSyntax.GetChar n => @?v10 n
           | ImpSyntax.PutChar e => @?v11 e
           | ImpSyntax.Abort => ?v12
           end) =>
          let binders_v2 := binders_names_of_constr_lambda v2 in
          let binders_v3 := binders_names_of_constr_lambda v3 in
          let binders_v4 := binders_names_of_constr_lambda v4 in
          let binders_v5 := binders_names_of_constr_lambda v5 in
          let binders_v6 := binders_names_of_constr_lambda v6 in
          let binders_v7 := binders_names_of_constr_lambda v7 in
          let binders_v8 := binders_names_of_constr_lambda v8 in
          let binders_v9 := binders_names_of_constr_lambda v9 in
          let binders_v10 := binders_names_of_constr_lambda v10 in
          let binders_v11 := binders_names_of_constr_lambda v11 in
          let n1 := List.nth binders_v2 0 in
          let n2 := List.nth binders_v2 1 in
          let n3 := List.nth binders_v3 0 in
          let n4 := List.nth binders_v3 1 in
          let n5 := List.nth binders_v4 0 in
          let n6 := List.nth binders_v4 1 in
          let n7 := List.nth binders_v4 2 in
          let n8 := List.nth binders_v5 0 in
          let n9 := List.nth binders_v5 1 in
          let n10 := List.nth binders_v5 2 in
          let n11 := List.nth binders_v6 0 in
          let n12 := List.nth binders_v6 1 in
          let n13 := List.nth binders_v7 0 in
          let n14 := List.nth binders_v7 1 in
          let n15 := List.nth binders_v7 2 in
          let n16 := List.nth binders_v8 0 in
          let n17 := List.nth binders_v9 0 in
          let n18 := List.nth binders_v9 1 in
          let n19 := List.nth binders_v10 0 in
          let n20 := List.nth binders_v11 0 in
          app_lemma "auto_cmd_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                      ("v1", exactk v1); ("v2", exactk v2); ("v3", exactk v3); ("v4", exactk v4);
                                      ("v5", exactk v5); ("v6", exactk v6); ("v7", exactk v7); ("v8", exactk v8);
                                      ("v9", exactk v9); ("v10", exactk v10); ("v11", exactk v11); ("v12", exactk v12);
                                      ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3); ("n4", exactk n4);
                                      ("n5", exactk n5); ("n6", exactk n6); ("n7", exactk n7); ("n8", exactk n8);
                                      ("n9", exactk n9); ("n10", exactk n10); ("n11", exactk n11); ("n12", exactk n12);
                                      ("n13", exactk n13); ("n14", exactk n14); ("n15", exactk n15); ("n16", exactk n16);
                                      ("n17", exactk n17); ("n18", exactk n18); ("n19", exactk n19); ("n20", exactk n20)]
                                    [compile; (fun () => destruct $v0; (Control.enter compile)); (fun () => ()); (fun () => ());
                                     (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ());
                                     (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ())]
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
          let binders_v2 := binders_names_of_constr_lambda v2 in
          let binders_v3 := binders_names_of_constr_lambda v3 in
          let n1 := List.nth binders_v2 0 in
          let n2 := List.nth binders_v2 1 in
          let n3 := List.nth binders_v3 0 in
          let n4 := List.nth binders_v3 1 in
          app_lemma "auto_cond_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                       ("v1", exactk v1); ("v2", exactk v2); ("v3", exactk v3);
                                       ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3); ("n4", exactk n4)]
                                     [compile; (fun () => destruct $v0; (Control.enter compile)); (fun () => ()); (fun () => ())]
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
           | ImpSyntax.Var n => @?v1 n
           | ImpSyntax.Const n => @?v2 n
           | ImpSyntax.Add e1 e2 => @?v3 e1 e2
           | ImpSyntax.Sub e1 e2 => @?v4 e1 e2
           | ImpSyntax.Div e1 e2 => @?v5 e1 e2
           | ImpSyntax.Read e1 e2 => @?v6 e1 e2
           end) =>
          let binders_v1 := binders_names_of_constr_lambda v1 in
          let binders_v2 := binders_names_of_constr_lambda v2 in
          let binders_v3 := binders_names_of_constr_lambda v3 in
          let binders_v4 := binders_names_of_constr_lambda v4 in
          let binders_v5 := binders_names_of_constr_lambda v5 in
          let binders_v6 := binders_names_of_constr_lambda v6 in
          let n1 := List.nth binders_v1 0 in
          let n2 := List.nth binders_v2 0 in
          let n3 := List.nth binders_v3 0 in
          let n4 := List.nth binders_v3 1 in
          let n5 := List.nth binders_v4 0 in
          let n6 := List.nth binders_v4 1 in
          let n7 := List.nth binders_v5 0 in
          let n8 := List.nth binders_v5 1 in
          let n9 := List.nth binders_v6 0 in
          let n10 := List.nth binders_v6 1 in
          app_lemma "auto_exp_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                      ("v1", exactk v1); ("v2", exactk v2); ("v3", exactk v3);
                                      ("v4", exactk v4); ("v5", exactk v5); ("v6", exactk v6);
                                      ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3);
                                      ("n4", exactk n4); ("n5", exactk n5); ("n6", exactk n6);
                                      ("n7", exactk n7); ("n8", exactk n8); ("n9", exactk n9);
                                      ("n10", exactk n10)]
                                    [compile; (fun () => destruct $v0; (Control.enter compile)); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ())]
        (* func *)
        | ImpSyntax.Func ?n ?params ?body =>
          app_lemma "auto_func_cons_Func" [("env", exactk fenv); ("n", exactk n); ("params", exactk params); ("body", exactk body)] [compile; compile; compile]
        | (match ?v0 with | ImpSyntax.Func n params body => @?v1 n params body end) =>
          let binders_v1 := binders_names_of_constr_lambda v1 in
          let n1 := List.nth binders_v1 0 in
          let n2 := List.nth binders_v1 1 in
          let n3 := List.nth binders_v1 2 in
          app_lemma "auto_func_CASE" [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1);
                                       ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3)]
                                     [compile; (fun () => destruct $v0; (Control.enter compile))]
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
          let binders_v1 := binders_names_of_constr_lambda v1 in
          let binders_v2 := binders_names_of_constr_lambda v2 in
          let binders_v3 := binders_names_of_constr_lambda v3 in
          let binders_v4 := binders_names_of_constr_lambda v4 in
          let binders_v5 := binders_names_of_constr_lambda v5 in
          let binders_v6 := binders_names_of_constr_lambda v6 in
          let binders_v7 := binders_names_of_constr_lambda v7 in
          let binders_v9 := binders_names_of_constr_lambda v9 in
          let binders_v10 := binders_names_of_constr_lambda v10 in
          let binders_v11 := binders_names_of_constr_lambda v11 in
          let binders_v12 := binders_names_of_constr_lambda v12 in
          let binders_v13 := binders_names_of_constr_lambda v13 in
          let binders_v14 := binders_names_of_constr_lambda v14 in
          let binders_v15 := binders_names_of_constr_lambda v15 in
          let binders_v16 := binders_names_of_constr_lambda v16 in
          let binders_v20 := binders_names_of_constr_lambda v20 in
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
                                       [compile; (fun () => destruct $v0; (Control.enter compile)); (fun () => ()); (fun () => ());
                                        (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ());
                                        (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ());
                                        (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ()); (fun () => ());
                                        (fun () => ()); (fun () => ())]
        (* prog *)
        | ImpSyntax.Program ?funcs =>
          app_lemma "auto_prog_cons_Program" [("env", exactk fenv); ("funcs", exactk funcs)] [compile]
        | (match ?v0 with | ImpSyntax.Program funcs => @?v1 funcs end) =>
          let binders_v1 := binders_names_of_constr_lambda v1 in
          let n1 := List.nth binders_v1 0 in
          app_lemma "auto_prog_CASE" [("env", exactk fenv); ("v0", exactk v0); ("v1", exactk v1); ("n1", exactk n1)]
                                     [compile; (fun () => destruct $v0; (Control.enter compile))]
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
        | (match ?v0 with
           | ASMSyntax.RAX => ?v1 | ASMSyntax.RDI => ?v2 | ASMSyntax.RBX => ?v3
           | ASMSyntax.RBP => ?v4 | ASMSyntax.R12 => ?v5 | ASMSyntax.R13 => ?v6
           | ASMSyntax.R14 => ?v7 | ASMSyntax.R15 => ?v8 | ASMSyntax.RDX => ?v9
           end) =>
          app_lemma "auto_reg_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                      ("v1", exactk v1); ("v2", exactk v2); ("v3", exactk v3);
                                      ("v4", exactk v4); ("v5", exactk v5); ("v6", exactk v6);
                                      ("v7", exactk v7); ("v8", exactk v8); ("v9", exactk v9)]
                                    [compile; (fun () => destruct $v0; (Control.enter compile))]
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
           | ImpSyntax.Test c e1 e2 => @?v1 c e1 e2
           | ImpSyntax.And t1 t2 => @?v2 t1 t2
           | ImpSyntax.Or t1 t2 => @?v3 t1 t2
           | ImpSyntax.Not t => @?v4 t
           end) =>
          let binders_v1 := binders_names_of_constr_lambda v1 in
          let binders_v2 := binders_names_of_constr_lambda v2 in
          let binders_v3 := binders_names_of_constr_lambda v3 in
          let binders_v4 := binders_names_of_constr_lambda v4 in
          let n1 := List.nth binders_v1 0 in
          let n2 := List.nth binders_v1 1 in
          let n3 := List.nth binders_v1 2 in
          let n4 := List.nth binders_v2 0 in
          let n5 := List.nth binders_v2 1 in
          let n6 := List.nth binders_v3 0 in
          let n7 := List.nth binders_v3 1 in
          let n8 := List.nth binders_v4 0 in
          app_lemma "auto_test_CASE" [("env", exactk fenv); ("v0", exactk v0);
                                       ("v1", exactk v1); ("v2", exactk v2); ("v3", exactk v3); ("v4", exactk v4);
                                       ("n1", exactk n1); ("n2", exactk n2); ("n3", exactk n3);
                                       ("n4", exactk n4); ("n5", exactk n5); ("n6", exactk n6);
                                       ("n7", exactk n7); ("n8", exactk n8)]
                                     [compile; (fun () => destruct $v0; (Control.enter compile)); (fun () => ()); (fun () => ()); (fun () => ())]
        (* TODO: see if we can use pairs (name -> tactic/term) *)
        (*       End-goal: extesible table of all compilation lemmas -> (name, tactic to apply) *)
        (*       We can use names to have subsets of tactics (e.g. arithmetic only) *)
        (* nat const *)
        | ASMSyntax.R14 =>
          app_lemma "auto_reg_cons_R14" [("env", exactk fenv)] []
        | ASMSyntax.R15 =>
          app_lemma "auto_reg_cons_R15" [("env", exactk fenv)] []
        | ASMSyntax.RDX =>
          app_lemma "auto_reg_cons_RDX" [("env", exactk fenv)] []
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
        (* TODO: see if we can use pairs (name -> tactic/term) *)
        (*       End-goal: extesible table of all compilation lemmas -> (name, tactic to apply) *)
        (*       We can use names to have subsets of tactics (e.g. arithmetic only) *)
        (* nat const *)
        | ?n =>
          if proper_const n then
            if Constr.equal (Constr.type n) constr:(nat) then
              app_lemma "auto_nat_const" [("env", exactk fenv); ("n", exactk n)] []
            else if Constr.equal (Constr.type n) constr:(string) then
              app_lemma "auto_string_const" [("env", exactk fenv); ("str", exactk n)] []
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

Ltac2 opt_is_empty (opt: 'a option): bool :=
  match opt with
  | None => true
  | _ => false
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
      let f_name_r := reference_of_constr_opt fconstr in
      (if opt_is_empty f_name_r then
        Control.throw (Oopsie (fprintf "Error: Expected a named function application, got: %t" fconstr))
      else ());
      let f_name_r := Option.get f_name_r in
      let fn_name_str := (Option.get (reference_to_string f_name_r)) in
      let fn_encoded_name_str := (string_of_constr_string fname) in
      (*  Check if the encoded name is the same as the compiled top level function *)
      if String.equal fn_encoded_name_str fn_name_str then
        (* If its a fixpoint apply `fname_equation`, otherwise unfold `fname` *)
        (if isFix fconstr then
          (* let arg1 := List.nth fargs 0 in *)
          let fargs_ids := List.map var_ident_of_constr fargs in
          (* let arg1_ident := var_ident_of_constr arg1 in *)
          Std.revert fargs_ids;
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

Ltac2 crush_side_conditions () :=
  ltac1:(
    repeat (match goal with
    | |- context[ FEnv.lookup _ _ ] => progress eauto with fenvDb
    (* | |- context[ FEnv.lookup _ _ ] => cbn; try congruence; try reflexivity *)
    | _ => progress eauto with fenvDb
    end)
  ).

Ltac2 relcompile_impl () :=
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

Ltac2 rec collect_prod_binders_impl (c: constr): binder list :=
  match Unsafe.kind c with
  | Prod b c =>
    b :: collect_prod_binders_impl c
  | _ => []
  end.
Ltac2 collect_prod_binders (c: constr): binder list :=
  collect_prod_binders_impl (Constr.type c).

Ltac2 rec gen_eval_app_impl (bs: binder list) (args: constr list) (f_constr_name: constr) (f: constr) (): constr :=
  (* printf "gen_eval_app_impl bs: %a args: %a f_constr_name: %t f: %t"
    (fun () x => message_of_list (List.map (fun b => fprintf "%I %t" (Option.default (Option.get (Ident.of_string "dummy")) (Binder.name b)) (Binder.type b)) x)) bs
    (fun () x => message_of_list (List.map Message.of_constr x)) args
    f_constr_name
    f; *)
  match bs with
  | b :: bs =>
    let name := Option.default (Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "x"))) (Binder.name b) in
    let cont := Constr.in_context name (Binder.type b) (fun () =>
      let b_hyp := Control.hyp name in
      Control.refine (gen_eval_app_impl bs (List.append args [b_hyp]) f_constr_name f)
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
  (* printf "encoded_b_names: %t" encoded_b_names; *)
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
  (* eauto with fenvDb. *)
  ltac1:(cbn; try congruence; try reflexivity).
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
  ltac1:(cbn; try congruence; try reflexivity).
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

Function sum_acc (n: nat) (acc: nat) :=
  match n with
  | 0 => acc
  | S n => sum_acc n (1 + acc)
  end.

Derive sum_acc_prog
  in ltac2:(relcompile_tpe 'sum_acc_prog 'sum_acc [])
  as sum_acc_prog_proof.
Proof.
  intros.
  subst sum_acc_prog.
  relcompile.
Qed.

Ltac2 rec in_contexts (bs: binder list) (c: unit -> constr) (): constr :=
  match bs with
  | [] => c ()
  | b :: bs =>
    (* let name := Option.default (Fresh.fresh (Free.of_goal ()) (Option.get (Ident.of_string "x"))) (Binder.name b) in *)
    let name := Option.get (Binder.name b) in
    Constr.in_context name (Binder.type b) (fun () =>
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

Ltac2 rec constr_transform_simple (f: constr -> constr) (c: constr): constr :=
  printf "transform: %t" c;
  match kind c with
  | Rel _ => f c
  | Meta _ | Var _ | Sort _ | Constant _ _ | Ind _ _
  | Constructor _ _ | Uint63 _ | Float _ | String _ => c
  | Cast c k t =>
      let c := constr_transform_simple f c
      with t := constr_transform_simple f t in
      make (Cast c k t)
  | Prod b c =>
    (* shouldn't matter in our case *)
    make (Prod b c)
  | Lambda b _ =>
      let name := Fresh.fresh (Free.of_goal ()) (Option.get (Binder.name b)) in
      printf "name: %I" name;
      Constr.in_context name (Binder.type b) (fun () =>
        let h := Control.hyp name in
        printf "%t" c;
        let c := apply_to_args c [h] in
        printf "%t" c;
        let c := Std.eval_cbv beta c in
        printf "%t" c;
        Control.refine (fun () =>
          constr_transform_simple f c
        )
      )
  | LetIn b t c =>
      (* let t := constr_transform_simple f t in
      let b_id := Option.get (Binder.name b) in
      let c := Constr.in_context b_id (Binder.type b) (fun () =>
        Control.refine (fun () => constr_transform_simple f c)
      ) in
      let b_var := Unsafe.make (Var b_id) in
      let c := Std.eval_cbv beta open_constr:($c $b_var) in *)
      make (LetIn b t c)
  | App c l =>
      let c := constr_transform_simple f c
      with l := Array.map (constr_transform_simple f) l in
      make (App c l)
  | Evar e l =>
      let l := Array.map (constr_transform_simple f) l in
      make (Evar e l)
  | Case info x iv y bl =>
      let y := constr_transform_simple f y
      with bl := Array.map (constr_transform_simple f) bl in
      make (Case info x iv y bl)
  | Proj p r c =>
      let c := constr_transform_simple f c in
      make (Proj p r c)
  | Fix structs which tl bl =>
      (* unsupported *)
      let bl := Array.map (constr_transform_simple f) bl in
      make (Fix structs which tl bl)
  | CoFix which tl bl =>
      (* unsupported *)
      let bl := Array.map (constr_transform_simple f) bl in
      make (CoFix which tl bl)
  | Array u t def ty =>
      let ty := constr_transform_simple f ty
      with t := Array.map (constr_transform_simple f) t
      with def := constr_transform_simple f def in
      make (Array u t def ty)
end.

Ltac2 unfold_tpe (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let unfolded := Std.eval_unfold [(fref, AllOccurrences)] fconstr in
  match Unsafe.kind unfolded with
  | Fix structs i bs cs =>
    if Int.equal (Array.length cs) 1 then
      let body := Array.get cs 0 in
      let _struct := Array.get structs 0 in
      let fix_b := Array.get bs 0 in
      let fix_name := Option.get (Binder.name fix_b) in
      printf "unfolded: %t" unfolded;
      printf "Fix with which = %i, body = [%t]" i body;
      Message.print (message_of_list (Array.to_list (Array.map Message.of_int structs)));
      Message.print (message_of_list (Array.to_list (Array.map message_of_binder bs)));
      let body_bs := binders_of_constr_lambda body in
      let res :=
      Constr.in_context fix_name (Binder.type fix_b) (fun () =>
        let _fix_hyp := Control.hyp fix_name in
        Control.refine (in_contexts body_bs (fun () =>
          let hyps := List.map Control.hyp (List.map (fun b => Option.get (Binder.name b)) body_bs) in
          let f_applied := apply_to_args fconstr hyps in
          let f_applied1 := Std.eval_cbv beta (apply_to_args body hyps) in
          printf "%t" f_applied1;
          let f_applied1 := constr_transform_simple (fun _c =>
            (* printf "%t" c;
            printf "%t" (Constr.type c);
            Message.print (Message.of_string (kind_string_of_constr c)); *)
            fconstr
          ) f_applied1 in
          printf "f_applied1: %t" f_applied1;
          (* let f_applied1 := apply_to_args fconstr hyps *)
          open_constr:($f_applied = $f_applied1)
        ))
      ) in
      let r := lambda_to_prod res in
      printf "%t" r;
      Control.refine (fun () => r)
    else
      Control.throw (Oopsie (fprintf "Wrong definition passed to unfold_tpe, namely %t" fconstr))
  | _ => Control.throw (Oopsie (fprintf "Wrong definition passed to unfold_tpe, namely %t" fconstr))
  end.

(* ************************* *)
(*        Playground         *)
(* ************************* *)

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
    (* printf "unfolded: %t" unfolded;
    printf "Fix with which = %i, body = [%t]" _i body;
    Message.print (message_of_list (Array.to_list (Array.map Message.of_int structs)));
    Message.print (message_of_list (Array.to_list (Array.map message_of_binder bs))); *)
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
    let r := lambda_to_prod (res ()) in
    (* printf "end of unfold_fix2: %t" r; *)
    Control.refine (fun () => r)
  | _ => Control.throw (Oopsie (fprintf "Wrong definition passed to unfold_tpe, namely %t" fconstr))
  end.

Ltac2 unfold_fix_gen (fconstr: constr): unit :=
  let fref := reference_of_constr fconstr in
  let unfolded_fix_template := open_constr:(ltac2:(unfold_fix_impl fconstr)) in
  ltac1:(unfolded_fix_template |- instantiate(1 := unfolded_fix_template)) (Ltac1.of_constr unfolded_fix_template);
  (* printf "%t" (Control.goal ()); *)
  let bs := collect_prod_binders_impl (Control.goal ()) in
  Message.print (message_of_list (List.map message_of_binder bs));
  let nms := List.map (fun b => Fresh.in_goal (Option.get (Binder.name b))) bs in
  Std.intros false (List.map (fun nm => IntroNaming (IntroFresh nm)) nms);
  (* printf "%t" (Control.goal ()); *)
  let struct_name := List.nth nms (struct_of_fix fconstr) in
  let struct_hyp := Control.hyp struct_name in
  destruct $struct_hyp;
  Control.enter (fun () =>
    (* printf "enter: %t" (Control.goal ()); *)
    unfold $fref; fold $fconstr;
    (* printf "folded: %t" (Control.goal ()); *)
    reflexivity ()
  ).

Ltac2 unfold_fix2_type fn :=
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

Fixpoint length (l: list bool) : nat :=
  match l with
  | nil => 0
  | cons hd tl => 1 + length tl
  end.
Goal ltac2:(unfold_fix2_type 'length).
Proof. unfold_fix_proof 'length. Qed.

Fixpoint sum_acc1 (acc: nat) (n: nat) :=
  match n with
  | 0 => acc
  | S n => sum_acc1 (acc + 1) n
  end.
Lemma sum_acc1_equation: ltac2:(unfold_fix2_type 'sum_acc1).
Proof. unfold_fix_proof 'sum_acc1. Qed.
About sum_acc1_equation.

(* TODO *)
(* genrated _equation rewrites to this: *)
(*
  (eval_app (name_enc "sum_acc1") [encode n; encode acc] s
  (encode (match n with
  | 0 => λ acc : nat, acc
  | S n' => λ acc : nat, sum_acc1 n' (acc + 1)
  end acc), s))
*)

(* TODO: automation always assumes that the first param is decreasing *)

Derive sum_acc1_prog
  in ltac2:(relcompile_tpe 'sum_acc1_prog 'sum_acc1 [])
  as sum_acc1_prog_proof.
Proof.
  intros.
  subst sum_acc1_prog.
  relcompile.
Qed.
