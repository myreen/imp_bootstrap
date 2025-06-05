(* From impboot Require Import utils.Core.
From coqutil Require Import dlet.
Require Import impboot.functional.FunValues.
(* Require Import impboot.functional.FunSyntax. *)
Require Import impboot.functional.FunSemantics.
Require Import impboot.automation.AutomationLemmas.
Require Import impboot.utils.Llist.
From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import
  Tactics.reference_to_string
  Tactics.ident_of_string
  Tactics.ident_to_string.
From Stdlib Require Import derive.Derive.
From Stdlib Require Import FunInd.

Ltac rewrite_let := match goal with
| [ |- context C [?subterm] ] =>
  match subterm with
  | let x := ?a in @?b x =>
    let C' := context C [b a] in
    change C'
  end
end.

Theorem xddd: forall a, a -> a.
Proof.
  congruence.
Defined.

Definition empty_state : state := init_state Lnil [].

Inductive xd : Type := MkXD.

(* TODO(kπ):
- consider using preterm instead of open_constr if thing get too slow
- computing names seems super slow. Should we have some hardcoded automation for that?
  (I tried to automate this by injectivity, but it's not injective :sad_goat:)
*)

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

Ltac2 automation_lemmas () := List.flat_map (fun s => opt_to_list (Env.get [Option.get (Ident.of_string s)])) [
  "auto_let";
  "auto_bool_T";
  "auto_bool_F";
  "auto_bool_and";
  "auto_bool_iff";
  "auto_bool_not"
].

Ltac2 ident_of_fqn (fqn: string list): ident list :=
  List.map (fun s => Option.get (Ident.of_string s)) fqn.

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

Ltac2 rec of_list (l : message list) : message :=
  let rec of_list_go (l : message list) :=
    match l with
    | [] => Message.of_string ""
    | [x] => x
    | x :: xs => Message.concat x (Message.concat (Message.of_string ",") (of_list_go xs))
    end
  in Message.concat (Message.of_string "[ ") (Message.concat (of_list_go l) (Message.of_string " ]")).

Ltac2 of_option (o : message option) : message :=
  match o with
  | Some x => x
  | None => Message.of_string "None"
  end.

Ltac2 f_lookup_name (f_lookup : (string * constr) list) (fname : string) : constr option :=
  match List.find_opt (fun (name, _) => String.equal name fname) f_lookup with
  | Some (_, c) => Some c
  | None => None
  end.

Ltac2 rec extract_fun (e : constr) : (constr * constr list) :=
  match! e with
  | (?f ?arg) =>
    let (f_fun, f_args) := extract_fun f in
    let f_args1 := List.append f_args [arg] in
    (f_fun, f_args1)
  | ?f =>
    (f, [])
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

Ltac2 of_f_lookup (f_lookup : (string * constr) list) : message :=
  match f_lookup with
  | [] => Message.of_string "[]"
  | _ =>
    let f_lookup' := List.map (fun (name, iden) =>
      Message.concat (Message.of_string name) (Message.concat (Message.of_string " -> ") (Message.of_constr iden))
    ) f_lookup in
    of_list f_lookup'
end.

(* TODO(kπ) *)
Ltac unfold_fix fn :=
  lazymatch goal with
  | [  |- context[fn ?x] ] =>
    let f := fresh "f" in
    eassert (forall x, fn x = ?[f] x) as -> by
    (
      unfold fn;
      instantiate
        (f :=
          ltac:(
            let ll := fresh "ll" in
            intros ll;
            let thm := open_constr:(analyze ll) in
            apply thm; intros
          )
        );
      cbv beta;
      match goal with
      | [  |- forall l, _ ] =>
          let ll := fresh l in
          intros ll; destruct ll
      end; fold fn; simpl analyze; reflexivity
        ); cbv beta
end.

(* TODO(kπ) track free variables to name let_n (use Ltac2.Free) *)
Ltac2 rec compile_list_encode (e0 : constr) (cenv : constr list)
  (f_lookup : (string * constr) list) : constr :=
  (* TODO(kπ) We should handle shadowing things (or avoid any type of shadowing in the implementation) *)
  print (Message.of_string "compile");
  print (Message.of_constr e0);
  print (of_list (List.map Message.of_constr cenv));
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
  print (of_list (List.map Message.of_constr cenv));
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
        open_constr:(auto_nat_const
        (* env *) _
        (* s *) _
        (* n *) $x
        )
      end
    in
    let (f, args) := extract_fun e in
    print (Message.of_string "extract_fun");
    print (Message.of_constr f);
    print (of_list (List.map Message.of_constr args));
    match args with
    | [] =>
      compile_go
    | _ =>
      let f_name_r := reference_of_constr_opt f in
      let f_name_str := Option.bind f_name_r reference_to_string in
      let f_constr_opt := Option.bind f_name_str (f_lookup_name f_lookup) in
      match f_constr_opt, f_name_str with
      | (_, Some fname) =>
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

Ltac2 rec constr_to_list (c : constr) : constr list :=
  match! c with
  | [] => []
  | (encode ?x) :: ?xs => x :: constr_to_list xs
  end.

(* TODO(kπ) this only works when fun is the top level App in the compiled
expression, otherwise we might have to have a funtion from a constr (that is a
string) to reference. So constr string to string? *)
Ltac2 fun_ident (c : constr) : reference :=
  match kind c with
  | App f _ => reference_of_constr f
  | _ => reference_of_constr c
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
Ltac2 docompile () :=
  lazy_match! goal with
  | [ |- _ |-- (_, _) ---> ([encode ?g], _) ] =>
    refine (compile g [] []);
    intros;
    eauto with fenvDb
  (* TODO(kπ) we need to know whether it is the currently compiled function at some point  *)
  | [ h : (lookup_fun ?_fname _ = _)
  |- eval_app ?_fname ?args _ (encode ?g, _) ] =>
    (* If there `fname_equation` exists then apply that, otherwise unfold `fname` *)
    let h_hyp := Control.hyp h in
    let f_lookup := get_f_lookup_from_hyps () in
    let argsl := constr_to_list args in
    let (fconstr, _) := extract_fun g in
    (* let f_name_r_opt := reference_of_constr_opt fconstr in
    let f_name_str_opt := Option.bind f_name_r_opt reference_to_string in
    let f_ident_equation_opt := Option.map (fun n => String.app n "_equation") f_name_str_opt in
    let f_ident_equation_r_opt := Option.map (fun s => ident_of_fqn [s]) f_name_str_opt in *)
    let f_name_r := reference_of_constr fconstr in
    let g_norm := eval_unfold [(f_name_r, AllOccurrences)] g in
    let compile_g := compile g_norm argsl f_lookup in
    print (Message.of_string "compile_g:");
    print (Message.of_constr compile_g);
    refine open_constr:(trans_app
    (* n *) _
    (* params *) _
    (* vs *) $args
    (* body *) _
    (* s *) _
    (* s1 *) _
    (* v *) _
    (* eval body *) $compile_g
    (* params length eq *) _
    (* lookup_fun *) $h_hyp
    );
    intros;
    eauto with fenvDb
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

(* Definition has_match (l: list nat) : nat :=
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

Function sum_n (n : nat) : nat :=
  match n with
  | 0 => 0
  | S n1 => (sum_n n1)(*  + n *)
  end.
About sum_n_equation.

Goal forall (s : state) (n : nat),
  exists sum_n_prog,
    lookup_fun (name_enc "sum_n") s.(funs) = Some ([name_enc "n"], sum_n_prog) ->
    (forall n, eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s)) ->
    eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s).
Proof.
  eexists.
  intros.
  rewrite sum_n_equation.
  eapply trans_app.
  all: eauto.
  all: try (reflexivity ()).
  docompile ().
  Show Proof.
Abort.


Derive sum_n_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "sum_n") s.(funs) = Some ([name_enc "n"], sum_n_prog) ->
    (* TODO(kπ) Added this just to try the HOL translation for recursion vvvvvvvvvvv *)
    (forall n, eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s)) ->
    eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s))
  as sum_n_prog_proof.
Proof.
  intros.
  subst sum_n_prog.
  rewrite sum_n_equation.
  eapply trans_app.
  all: eauto.
  all: try (reflexivity ()).
                (* kπ: this (vvv) is because we anually apply trans_app, so we don't add the argument to env (we should probably reuse the relational env, though) *)
  docompile (). (* error: (cannot instantiate "?body" because "n" is not in its scope) *)
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

Goal forall (s : state) (n : nat),
  exists has_cases_prog,
    lookup_fun (name_enc "has_cases") s.(funs) = Some ([name_enc "n"], has_cases_prog) ->
    eval_app (name_enc "has_cases") [encode n] s (encode (has_cases n), s).
Proof.
  eexists.
  intros.
  docompile ().
  Show Proof.


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

Definition foo (n : nat) : nat :=
  letd x := 1 in
  letd y := n + x in
  y.

Lemma function_example : forall (s : state) (n : nat),
  exists prog,
    lookup_fun (name_enc "foo") s.(funs) = Some ([name_enc "n"], prog) ->
      eval_app (name_enc "foo") [encode n] s (encode (foo n), s).
Proof.
  intros; eexists; intros.

  (* TODO(kπ) This inlined the `y` :thinking: *)
  docompile ().
  Show Proof.
  (* - simpl; ltac1:(reflexivity).
  - exact "a"%string.
  - exact "b"%string.
  - exact "a"%string.
  - exact "b"%string.
  Unshelve. *)
Admitted.

Derive foo_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "foo") s.(funs) = Some ([name_enc "n"], foo_prog) ->
    eval_app (name_enc "foo") [encode n] s (encode (foo n), s))
  as foo_prog_proof.
Proof.
  intros.
  subst foo_prog.
  docompile ().
  Show Proof.
  (* - exact [name_enc "n"]. *)
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
