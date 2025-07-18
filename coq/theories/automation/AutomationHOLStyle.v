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
- computing names seems super slow. Should we have some hardcoded automation for that?
  (I tried to automate this by injectivity, but it's not injective :sad_goat:)
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

Ltac2 rec split_thm (c: constr): constr list :=
  match! c with
  | (∀ x, @?f x) =>
    (* print t; *)
    print (Message.of_constr c);
    split_thm f
  (* | (fun x => @?f x) =>
    (* print t; *)
    print (Message.of_constr c);
    split_thm f *)
  | ?c => [c]
  end.

Ltac2 rec split_thm_args_unsafe (c: constr): constr list :=
  match Unsafe.kind c with
  | Prod b c1 =>
    print (Message.of_constr (Binder.type b));
    print (Message.of_constr c1);
    (Binder.type b) :: split_thm_args_unsafe c1
  | _ => []
  end.

Ltac2 rec thm_constr_app (cf: constr -> constr) (ps: constr list) (acc: constr): constr :=
  match ps with
  | [] => acc
  | p :: ps =>
    let arg := match! p with
              | _ |-- (_, _) ---> (_, _) => cf(p)
              | (fun x => _) => cf(p)
              | _ => open_constr:(_)
              end in
    thm_constr_app cf ps open_constr:($acc $arg)
  end.

(* TODO(kπ) Try using this approach for automatic-ish automation lemma usage/extensibility *)
Ltac2 app_lemma (cf: constr -> constr) (lname: string) :=
  let r := List.hd (Env.expand (ident_of_fqn [lname])) in
  let c := Env.instantiate r in
  let ctpe := type c in
  let thm_parts := split_thm_args_unsafe ctpe in
  thm_constr_app cf thm_parts c.

Ltac2 beta_fix : red_flags := {
  rBeta := true; rMatch := false; rFix := true; rCofix := false;
  rZeta := false; rDelta := false; rConst := []; rStrength := Norm;
}.

Ltac2 f_lookup_name (f_lookup : (string * constr) list) (fname : string) : constr option :=
  match List.find_opt (fun (name, _) => String.equal name fname) f_lookup with
  | Some (_, c) => Some c
  | None => None
  end.

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

(* TODO(kπ) track free variables to name let_n (use Ltac2.Free) *)
Ltac2 rec compile_list_encode (e0 : constr) (cenv : constr list)
  (f_lookup : (string * constr) list) : constr :=
  (* TODO(kπ) We should handle shadowing things (or avoid any type of shadowing in the implementation) *)
  print (Message.of_string "compile");
  print (Message.of_constr e0);
  print (message_of_list (List.map Message.of_constr cenv));
  match! e0 with
  | [] =>
    open_constr:(trans_nil
    (* env *) _
    (* s *) _
    )
  | (encode ?e) :: ?es =>
    let compile_e := compile e cenv f_lookup in
    let compile_es := compile_list_encode es cenv f_lookup in
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
  end
with compile (e : constr) (cenv : constr list)
  (f_lookup : (string * constr) list) : constr :=
  print (Message.of_string "Compiling expression:");
  print (Message.of_constr e);
  print (Message.of_string "cenv");
  print (message_of_list (List.map Message.of_constr cenv));
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
      | (fun x => @?f x) =>
        open_constr:(ltac2:(Control.enter (fun () =>
          let x := Fresh.in_goal (Option.get (Ident.of_string "x_nm")) in
          Std.intros false [IntroNaming (IntroFresh x)];
          let x_constr := (Control.hyp x) in
          Control.refine (fun () =>
            compile (eval_cbv beta open_constr:($f $x_constr)) (x_constr :: cenv) f_lookup
          )
        )))
      | (dlet ?val ?body) =>
        let compiled_val := compile val cenv f_lookup in
        let applied_body := eval_cbv beta open_constr:($body $val) in
        let compiled_body := compile applied_body (val :: cenv) f_lookup in
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
        open_constr:(auto_bool_T
        (* env *) _
        (* s *) _
        )
      | false =>
        open_constr:(auto_bool_F
        (* env *) _
        (* s *) _
        )
      | (negb ?b) =>
        let compile_b := compile b cenv f_lookup in
        open_constr:(auto_bool_not
        (* env *) _
        (* s *) _
        (* x1 *) _
        (* b *) $b
        (* eval x1 *) $compile_b
        )
      | (andb ?bA ?bB) =>
        let compile_bA := compile bA cenv f_lookup in
        let compile_bB := compile bB cenv f_lookup in
        open_constr:(auto_bool_and
        (* env *) _
        (* s *) _
        (* x1 x2 *) _ _
        (* bA bB *) $bA $bB
        (* eval x1 *) $compile_bA
        (* eval x2 *) $compile_bB
        )
      | (eqb ?bA ?bB) =>
        let compile_bA := compile bA cenv f_lookup in
        let compile_bB := compile bB cenv f_lookup in
        open_constr:(auto_bool_iff
        (* env *) _
        (* s *) _
        (* x1 x2 *) _ _
        (* bA bB *) $bA $bB
        (* eval x1 *) $compile_bA
        (* eval x2 *) $compile_bB
        )
      | (if ?b then ?t else ?f) =>
        let compile_b := compile b cenv f_lookup in
        let compile_t := compile t cenv f_lookup in
        let compile_f := compile f cenv f_lookup in
        open_constr:(last_bool_if
        (* env *) _
        (* s *) _
        (* x_b x_t x_f *) _ _ _
        (* b t f *) $b $t $f
        (* eval x_b *) $compile_b
        (* eval x_t *) $compile_t
        (* eval x_f *) $compile_f
        )
      (* nat *)
      | (?n1 + ?n2) =>
        let compile_n1 := compile n1 cenv f_lookup in
        let compile_n2 := compile n2 cenv f_lookup in
        open_constr:(auto_nat_add
        (* env *) _
        (* s0 s1 s2 *) _ _ _
        (* x1 x2 *) _ _
        (* n1 n2 *) $n1 $n2
        (* eval x1 *) $compile_n1
        (* eval x2 *) $compile_n2
        )
      | (?n1 - ?n2) =>
        let compile_n1 := compile n1 cenv f_lookup in
        let compile_n2 := compile n2 cenv f_lookup in
        open_constr:(auto_nat_sub
        (* env *) _
        (* s0 s1 s2 *) _ _ _
        (* x1 x2 *) _ _
        (* n1 n2 *) $n1 $n2
        (* eval x1 *) $compile_n1
        (* eval x2 *) $compile_n2
        )
      | (?n1 / ?n2) =>
        let compile_n1 := compile n1 cenv f_lookup in
        let compile_n2 := compile n2 cenv f_lookup in
        open_constr:(auto_nat_div
        (* env *) _
        (* s0 s1 s2 *) _ _ _
        (* x1 x2 *) _ _
        (* n1 n2 *) $n1 $n2
        (* eval x1 *) $compile_n1
        (* eval x2 *) $compile_n2
        (* n2 <> 0 *) _
        )
      | (if Nat.eqb ?n1 ?n2 then ?t else ?f) =>
        let compile_n1 := compile n1 cenv f_lookup in
        let compile_n2 := compile n2 cenv f_lookup in
        let compile_t := compile t cenv f_lookup in
        let compile_f := compile f cenv f_lookup in
        open_constr:(auto_nat_if_eq
        (* A *) _
        (* env *) _
        (* s *) _
        (* x1 x2 y z *) _ _ _ _
        (* n1 n2 t f *) $n1 $n2 $t $f
        (* eval x1 *) $compile_n1
        (* eval x2 *) $compile_n2
        (* eval y *) $compile_t
        (* eval z *) $compile_f
        )
      | (if ?n1 <? ?n2 then ?t else ?f) =>
        let compile_n1 := compile n1 cenv f_lookup in
        let compile_n2 := compile n2 cenv f_lookup in
        let compile_t := compile t cenv f_lookup in
        let compile_f := compile f cenv f_lookup in
        open_constr:(auto_nat_if_less
        (* env *) _
        (* s *) _
        (* x1 x2 y z *) _ _ _ _
        (* n1 n2 t f *) $n1 $n2 $t $f
        (* eval x1 *) $compile_n1
        (* eval x2 *) $compile_n2
        (* eval y *) $compile_t
        (* eval z *) $compile_f
        )
      (* list *)
      | [] =>
        open_constr:(auto_list_nil
        (* env *) _
        (* s *) _
        )
      | (?x :: ?xs) =>
        let compile_x := compile x cenv f_lookup in
        let compile_xs := compile xs cenv f_lookup in
        open_constr:(auto_list_cons
        (* env *) _
        (* s *) _
        (* x1 x2 *) _ _
        (* x *) $x
        (* xs *) $xs
        (* eval x1 *) $compile_x
        (* eval x2 *) $compile_xs
        )
      | (match ?v0 with | nil => ?v1 | h :: t => @?v2 h t end) =>
        let compile_v0 := compile v0 cenv f_lookup in
        let compile_v1 := compile v1 cenv f_lookup in
        let compile_v2 := compile v2 cenv f_lookup in
        open_constr:(auto_list_case
        (* env *) _
        (* s *) _
        (* x0 x1 x2 *) _ _ _
        (* n1 n2 *) _ _
        (* v0 v1 v2 *) $v0 $v1 $v2
        (* eval x0 *) $compile_v0
        (* eval x1 *) $compile_v1
        (* eval x2 *) $compile_v2
        (* NoDup *) _
        )
      | (match ?v0 with | 0 => ?v1 | S n' => @?v2 n' end) =>
        let compile_v0 := compile v0 cenv f_lookup in
        let compile_v1 := compile v1 cenv f_lookup in
        let compile_v2 := compile v2 cenv f_lookup in
        open_constr:(auto_nat_case
        (* env *) _
        (* s *) _
        (* x0 x1 x2 *) _ _ _
        (* n *) _
        (* v0 v1 v2 *) $v0 $v1 $v2
        (* eval x0 *) $compile_v0
        (* eval x1 *) $compile_v1
        (* eval x2 *) $compile_v2
        )
      | ?x =>
        (* open_constr:(_) *)
        if proper_const x then
          open_constr:(auto_nat_const
          (* env *) _
          (* s *) _
          (* n *) $x
          )
        else
          (printf "f_lookup";
          print (message_of_f_lookup f_lookup);
          (Control.throw (Oopsie (fprintf
            "Error: Tried to compile a non-constant expression %t as a constant expression (%s kind)"
            x
            (kind_string_of_constr x)
          ));
          open_constr:(_)))
      end
    in
    let f_args := extract_fun e in
    (* print (Message.of_string "extract_fun");
    print (Message.of_constr f);
    print (message_of_list (List.map Message.of_constr args)); *)
    match f_args with
    | None =>
      printf "f_args  = None: e = %t" e;
      compile_go
    | Some (f, args) =>
      printf "f_args  = Some (%t, _): e = %t" f e;
      let f_name_r := reference_of_constr_opt f in
      let f_name_str := Option.bind f_name_r reference_to_string in
      let f_constr_opt := Option.bind f_name_str (f_lookup_name f_lookup) in
      match f_constr_opt, f_name_str with
      | (Some _, Some fname) =>
        let args_constr := list_to_constr_encode args in
        let compile_args := compile_list_encode args_constr cenv f_lookup in
        let fname_str := constr_string_of_string fname in
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
  end.

Ltac2 rec constr_list_to_list (c : constr) : constr list :=
  match! c with
  | [] => []
  | (encode ?x) :: ?xs => x :: constr_list_to_list xs
  end.

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
      (* print (Message.of_string "Found function in hypothesis");
      print (Message.of_constr t); *)
      let t_refined := refine_up_to_eval_app iden t in
      [(string_of_constr_string fname1, t_refined)]
    | _ => []
    end
  ) hyps) in
  f_lookup.

(* Top level tactic that compiles a program into FunLang *)
(* Handles expression evaluation and function evaluation as goals *)
Ltac2 rec docompile () :=
  lazy_match! goal with
  | [ |- _ |-- (_, _) ---> ([encode ?c], _) ] =>
    refine (compile c [] []);
    intros;
    eauto with fenvDb
  (* TODO(kπ) we need to know whether it is the currently compiled function at some point  *)
  (*          kπ: Don't we know it just by the fact that we are here instead of in compile? *)
  | [ h : (lookup_fun ?_fname _ = _)
  |- eval_app (name_enc ?fname) ?args _ (encode ?c, _) ] =>
    (* If there `fname_equation` exists then apply that, otherwise unfold `fname` *)
    let h_hyp := Control.hyp h in
    let f_lookup := get_f_lookup_from_hyps () in
    let argsl := constr_list_to_list args in
    match extract_fun c with
    (* function ref --> unfold *)
    | Some (fconstr, _) =>
      let f_name_r := reference_of_constr fconstr in
      if String.equal (string_of_constr_string fname) (Option.get (reference_to_string f_name_r)) then
        printf "extract_fun %t = Some (%t, _)" c fconstr;
        if isFix fconstr then
          rewrite_with_equation fconstr
        else (
          let f_name_r := reference_of_constr fconstr in
          let cl := default_on_concl None in
          Std.unfold [(f_name_r, AllOccurrences)] cl
        );
        docompile ()
      else (
        let compiled := compile c argsl f_lookup in
        refine open_constr:(trans_app
        (* n *) _
        (* params *) _
        (* vs *) $args
        (* body *) _
        (* s *) _
        (* s1 *) _
        (* v *) _
        (* eval body *) $compiled
        (* params length eq *) _
        (* lookup_fun *) $h_hyp
        );
        intros;
        eauto with fenvDb
      )
    (* unfolded function ref --> just compile *)
    | None =>
      let compiled := compile c argsl f_lookup in
      refine open_constr:(trans_app
      (* n *) _
      (* params *) _
      (* vs *) $args
      (* body *) _
      (* s *) _
      (* s1 *) _
      (* v *) _
      (* eval body *) $compiled
      (* params length eq *) _
      (* lookup_fun *) $h_hyp
      );
      intros;
      eauto with fenvDb
    end
  | [ |- ?x ] =>
    print (Message.of_string "No match in docompile for:");
    print (Message.of_constr x);
    (* fail *)
    refine open_constr:(_)
  end.

(* Lemma arith_example : forall n,
  exists prog,
    FEnv.empty |-- (prog, empty_state) --->
    ([encode
      (letd x := 1 in x + n)
    ], empty_state).
Proof.
  intros; eexists.
  docompile ().
  Show Proof.
  (* exact "a"%string. *)
Admitted. *)

(* Lemma list_example : forall (n : nat),
  exists prog,
    FEnv.empty |-- (prog, empty_state) --->
    ([encode
      (letd l := [1; 2; 3] in
      letd fnil := n in
      list_CASE l fnil (fun (x : nat) _ => x + 1))
    ], empty_state).
Proof.
  intros; eexists.
  (* Set Ltac2 Backtrace. *)
  docompile ().
  Show Proof.
  (* TODO(kπ) Common crush tactic for these vvv (free_vars, NoDup, in_nil) *)
  all: unfold FunProperties.free_vars; simpl.
  all: try (eapply NoDup_cons); try (eapply in_nil); try (eapply NoDup_nil).
  (* TODO(kπ) Also a common crush tactic for picking variable names *)
  (* TODO(kπ): Slow vvv *)
  (* - exact ("a"%string).
  - exact ("b"%string).
  - exact ("a"%string).
  - inversion e; subst; rewrite FEnv.lookup_insert_neq; try (rewrite FEnv.lookup_insert_eq); auto.
    unfold name_enc, name_enc_l; simpl; ltac1:(lia).
  - exact ("c"%string).
  - exact ("d"%string). *)
Admitted.

Lemma list_example2 : forall (n : nat),
  exists prog,
    FEnv.empty |-- (prog, empty_state) --->
    ([encode
      (letd l := [1; 2; 3] in
      letd fnil := n in
      list_CASE l fnil (fun (x : nat) xs =>
        list_CASE xs (x + 99) (fun (y : nat) _ => y + 1)
      ))
    ], empty_state).
Proof.
  intros; eexists.
  (* Set Ltac2 Backtrace. *)
  docompile ().
  Show Proof.
  (* TODO(kπ) Common crush tactic for these vvv (free_vars, NoDup, in_nil) *)
  all: unfold FunProperties.free_vars; simpl.
  all: try (eapply NoDup_cons); try (eapply in_nil); try (eapply NoDup_nil).
  (* TODO(kπ) Also a common crush tactic for picking variable names *)
  (* TODO(kπ): Slow vvv *)
  (* - exact ("a"%string).
  - exact ("b"%string).
  - exact ("c"%string).
  - exact ("b"%string).
  - exact ("a"%string).
  - exact ("f"%string).
  - eapply not_in_cons; split; try (eapply in_nil); unfold name_enc, name_enc_l; simpl; ltac1:(lia).
  - eapply NoDup_cons; try (eapply in_nil); try (eapply NoDup_nil).
  - inversion e; subst; rewrite FEnv.lookup_insert_neq; try (rewrite FEnv.lookup_insert_eq); auto.
    unfold name_enc, name_enc_l; simpl; ltac1:(lia).
  - inversion e; subst; rewrite FEnv.lookup_insert_neq; try (rewrite FEnv.lookup_insert_eq); auto.
    unfold name_enc, name_enc_l; simpl; ltac1:(lia).
  - exact ("g"%string).
  - exact ("h"%string). *)
Admitted. *)

(* Function has_match (l: list nat) : nat :=
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
  docompile ().
  Show Proof.
Abort. *)

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
    (* TODO(kπ) Added this just to try the HOL translation for recursion vvvvvvvvvvv *)
    (forall n, eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s)) ->
    eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s))
  as sum_n_prog_proof.
Proof.
  intros.
  subst sum_n_prog.
  (* rewrite sum_n_equation.
  eapply trans_app.
  all: eauto.
  all: try (reflexivity ()). *)
                (* kπ: this (vvv) is because we anually apply trans_app, so we don't add the argument to env (we should probably reuse the relational env, though) *)
  (* error: (cannot instantiate "?body" because "n" is not in its scope) *)
  docompile ().
  (* Show Proof. *)
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
  docompile ().
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
  docompile ().
  Show Proof.
Abort.

(* Definition foo (n : nat) : nat :=
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
  docompile ().
  Show Proof.
  - exact [name_enc "n"].
  - simpl; ltac1:(reflexivity).
  Unshelve.
  4: exact "x"%string.
  4: exact "y"%string.
  4: exact "n"%string.
  4: exact "x"%string.
  all: unfold make_env; simpl.
  + rewrite FEnv.lookup_insert_neq > [|unfold not; unfold name_enc, name_enc_l; simpl; ltac1:(lia)].
    rewrite FEnv.lookup_insert_eq; auto.
  + rewrite FEnv.lookup_insert_eq; auto.
  + rewrite FEnv.lookup_insert_eq; auto.
  (* - exact "x"%string.
  - exact "y"%string.
  - exact "n"%string.
  - exact "x"%string.
  Unshelve.
  all: unfold make_env; simpl.
  + rewrite FEnv.lookup_insert_neq > [|unfold not; unfold name_enc, name_enc_l; simpl; ltac1:(lia)].
    rewrite FEnv.lookup_insert_eq; auto.
  + rewrite FEnv.lookup_insert_eq; auto.
  + rewrite FEnv.lookup_insert_eq; auto. *)
Qed.
Print foo_prog.

Definition bar (n : nat) : nat :=
  foo (n + 1).

Derive bar_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "foo") s.(funs) = Some ([name_enc "n"], foo_prog) ->
    (forall m, eval_app (name_enc "foo") [encode m] s (encode (foo m), s)) ->
    lookup_fun (name_enc "bar") s.(funs) = Some ([name_enc "n"], bar_prog) ->
    eval_app (name_enc "bar") [encode n] s (encode (bar n), s))
  as bar_prog_proof.
Proof.
  intros.
  subst bar_prog.
  docompile ().
  Show Proof.
  - simpl; reflexivity ().
  Unshelve.
  all: unfold make_env; eauto.
  2: eapply FEnv.lookup_insert_eq; auto.
  1: exact (FEnv.empty).
  Show Proof.
Qed.
Print bar_prog.

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
  docompile ().
  Show Proof.
  - simpl; reflexivity ().
  Unshelve.
  all: unfold make_env; eauto.
  4: exact "z"%string.
  4: exact "n"%string.
  4: exact "m"%string.
  4: exact "z"%string.
  + rewrite FEnv.lookup_insert_neq > [|unfold not; unfold name_enc, name_enc_l; simpl; ltac1:(lia)].
    rewrite FEnv.lookup_insert_eq; auto.
  + rewrite FEnv.lookup_insert_eq; auto.
  + rewrite FEnv.lookup_insert_eq; auto.
Qed.

Definition baz2 (n : nat) : nat :=
  baz (n + 1) n.

Derive baz2_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "baz") s.(funs) = Some ([name_enc "n"; name_enc "m"], baz_prog) ->
    (forall n m, eval_app (name_enc "baz") [encode n; encode m] s (encode (baz n m), s)) ->
    lookup_fun (name_enc "baz2") s.(funs) = Some ([name_enc "n"], baz2_prog) ->
    eval_app (name_enc "baz2") [encode n] s (encode (baz2 n), s))
  as baz2_prog_proof.
Proof.
  intros.
  subst baz2_prog.
  docompile ().
  Show Proof.
  - simpl; reflexivity ().
  Unshelve.
  all: unfold make_env; eauto.
  2: eapply FEnv.lookup_insert_eq; auto.
  2: eapply FEnv.lookup_insert_eq; auto.
  1: exact (FEnv.empty).
Qed. *)
