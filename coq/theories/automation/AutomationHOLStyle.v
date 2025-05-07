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

Ltac rewrite_let := match goal with
| [ |- context C [?subterm] ] =>
  match subterm with
  | let x := ?a in @?b x =>
    let C' := context C [b a] in
    change C'
  end
end.

Definition empty_state : state := init_state Lnil [].

(* TODO(kπ):
- consider using preterm instead of open_constr if thing get too slow
- computing names seems super slow. Should we have some hardcoded automation for that?
  (I tried to automate this by injectivity, but it's not injective :sad_goat:)
*)

(* Rupicola approach *)

(* Ltac autostep :=
  (* eapply trans_app ||
  eapply trans_Var ||
  eapply trans_Call ||
  eapply trans_nil ||
  eapply trans_cons || *)
  (* eapply auto_otherwise || *)
  eapply auto_bool_F ||
  eapply auto_bool_T ||
  eapply auto_bool_not ||
  eapply auto_bool_and ||
  eapply auto_bool_iff ||
  eapply last_bool_if ||
  (* eapply auto_num_const_zero || *)
  eapply auto_num_const ||
  eapply auto_num_add ||
  eapply auto_num_sub ||
  eapply auto_num_div ||
  eapply auto_num_if_eq ||
  eapply auto_num_if_less ||
  eapply auto_list_nil ||
  eapply auto_list_cons ||
  eapply auto_list_case ||
  eapply auto_option_none ||
  eapply auto_option_some ||
  eapply auto_option_case ||
  eapply auto_pair_fst ||
  eapply auto_pair_snd ||
  eapply auto_pair_cons ||
  eapply auto_pair_case ||
  eapply auto_char_CHR ||
  eapply auto_char_ORD ||
  eapply auto_word4_n2w ||
  eapply auto_word64_n2w ||
  eapply auto_word4_w2n ||
  eapply auto_word64_w2n ||
  (* This gets applied to eagerly *)
  eapply auto_let. *)

(* *)

(* HOL4-ish approach *)

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

Ltac2 rec list_to_constr_encode (l : constr list) : constr :=
  match l with
  | [] => open_constr:([])
  | x :: xs =>
    let xs' := list_to_constr_encode xs in
    open_constr:((encode $x) :: $xs')
  end.

Ltac2 reference_of_constr_opt c :=
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
      (* num *)
      | (?n1 + ?n2) =>
        let compile_n1 := compile n1 cenv f_lookup in
        let compile_n2 := compile n2 cenv f_lookup in
        open_constr:(auto_num_add
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
        open_constr:(auto_num_sub
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
        open_constr:(auto_num_div
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
        open_constr:(auto_num_if_eq
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
        open_constr:(auto_num_if_less
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
      | (list_CASE ?v0 ?v1 ?v2) =>
        let compile_v0 := compile v0 cenv f_lookup in
        let compile_v1 := compile v1 cenv f_lookup in
        let hdv0 := open_constr:(hd _ $v0) in
        let tlv0 := open_constr:(tl $v0) in
        let v0ap := (eval_cbv beta open_constr:($v2 $hdv0 $tlv0)) in
        let compile_v2 := compile (eval_cbv beta v0ap) (tlv0 :: hdv0 :: cenv) f_lookup in
        (* let compile_v2 := (fun (xh : constr) (xt : constr) => compile (eval_cbv beta open_constr:($v2 $xh $xt)) (xh :: xt :: cenv) f_lookup) in *)
        open_constr:(auto_list_case
        (* env *) _
        (* s *) _
        (* x0 x1 x2 *) _ _ _
        (* n1 n2 *) _ _
        (* v0 v1 v2 *) $v0 $v1 $v2
        (* default_A *) _
        (* eval x0 *) $compile_v0
        (* eval x1 *) $compile_v1
        (* TODO(kπ) not sure if the &-references are correct *)
        (* eval x2 *) $compile_v2
        (* NoDup *) _
        )
      | (nat_CASE ?v0 ?v1 ?v2) =>
        let compile_v0 := compile v0 cenv f_lookup in
        let compile_v1 := compile v1 cenv f_lookup in
        let predv0 := open_constr:($v0 - 1) in
        let v0ap := (eval_cbv beta open_constr:($v2 $predv0)) in
        print (Message.of_string "$v2 _");
        print (Message.of_constr v0ap);
        print (Message.of_string "$v2");
        print (Message.of_constr open_constr:($v2));
        print (Message.of_string "adding to cenv:");
        print (Message.of_constr predv0);
        let compile_v2 := compile v0ap (predv0 :: cenv) f_lookup in
        (* TODO(kπ) Dunno why this works. It shouldn't. We can't really support lambdas *)
        (*          Also see the next comment. Is this OK? *)
        (* let fresh_ident := Option.map Fresh.in_goal (Ident.of_string "x") in
        print (Message.of_string "fresh_ident");
        print (Message.of_ident (Option.get fresh_ident));
        let compile_v2 := (fun (x : constr) => compile (* (eval_cbv beta  *)open_constr:($v2 $x(* ) *)) (x :: cenv) f_lookup) in
        print (Message.of_string "compile_v2");
        let compile_v2_applied := compile_v2 (Constr.Unsafe.make (Constr.Unsafe.Var (Option.get fresh_ident))) in
        print (Message.of_string "compile_v2_applied");
        print (Message.of_constr compile_v2_applied);
        let compile_lambda :=
          Constr.Unsafe.make (Constr.Unsafe.Lambda (Constr.Binder.make fresh_ident (Constr.type v0)) compile_v2_applied) in *)
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
        open_constr:(auto_num_const
        (* env *) _
        (* s *) _
        (* n *) $x
        )
      end
    in
    let (f, args) := extract_fun e in
    match args with
    | [] =>
      compile_go
    | _ =>
      let f_name_r := reference_of_constr_opt f in
      let f_name_str := Option.bind f_name_r reference_to_string in
      let f_constr_opt := Option.bind f_name_str (f_lookup_name f_lookup) in
      match f_constr_opt, f_name_str with
      | (Some _c, Some fname) =>
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
string) to reference. So constr stirng to string? *)
Ltac2 rec fun_ident (c : constr) : reference :=
  match kind c with
  | App f _ => reference_of_constr f
  | _ => reference_of_constr c
  end.

Ltac2 rec refine_up_to_eval_app (iden : ident) (t : constr) : constr :=
  lazy_match! t with
  (* TODO(kπ) Ltac(2) doesn't allow matching on open terms :sad_goat: *)
  | (forall _, ?t1) =>
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
  | [ (* h : (lookup_fun ?_fname _ = _) *)
  |- eval_app ?_fname ?args _ (encode ?g, _) ] =>
    let f_lookup := get_f_lookup_from_hyps () in
    let argsl := constr_to_list args in
    let f_ident := fun_ident g in
    let g_norm := eval_unfold [(f_ident, AllOccurrences)] g in
    (* print (Message.of_string "g_norm");
    print (Message.of_constr g_norm);
    print (of_list (List.map Message.of_constr argsl)); *)
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
    (* lookup_fun *) _
    );
    intros;
    eauto with fenvDb
  | [ |- ?x ] =>
    print (Message.of_string "No match in docompile");
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
Admitted.

Lemma list_example : forall (n : nat),
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

Definition has_cases (n : nat) : nat :=
  nat_CASE n 0 (fun n1 =>
    nat_CASE n1 1 (fun n2 => n1 + n2)).
Print has_cases.

Derive has_cases_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "has_cases") s.(funs) = Some ([name_enc "n"], has_cases_prog) ->
    eval_app (name_enc "has_cases") [encode n] s (encode (has_cases n), s))
  as has_cases_proof.
Proof.
  intros.
  subst has_cases_prog.
  docompile ().
Abort.

Definition has_cases_list (l : list nat) : nat :=
  list_CASE l 0 (fun hd tl =>
    list_CASE tl 1 (fun hdtl tltl => hd + hdtl)).

Derive has_cases_list_prog in (forall (s : state) (l : list nat),
    lookup_fun (name_enc "has_cases_list") s.(funs) = Some ([name_enc "l"], has_cases_list_prog) ->
    eval_app (name_enc "has_cases_list") [encode l] s (encode (has_cases_list l), s))
  as has_cases_list_proof.
Proof.
  intros.
  subst has_cases_list_prog.
  docompile ().
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
Qed.


Fixpoint sum_n (n : nat) : nat :=
  nat_CASE n 0 (fun n1 => n + (sum_n n1)).
Print sum_n.

Derive sum_n_prog in (forall (s : state) (n : nat),
    lookup_fun (name_enc "sum_n") s.(funs) = Some ([name_enc "n"], sum_n_prog) ->
    (* TODO(kπ) Added this just to try the HOL translation for recursion vvvvvvvvvvv *)
    eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s) ->
    eval_app (name_enc "sum_n") [encode n] s (encode (sum_n n), s))
  as fib_prog_proof.
Proof.
  intros.
  subst sum_n_prog.
  unfold sum_n.
  eapply trans_app.
  3: exact H.
  2: simpl; reflexivity ().
  unfold sum_n, make_env.


  docompile ().
  Show Proof.

  (* docompile (). *)
(*
  all: simpl.
  all: try (eapply auto_num_const).
  all: try (docompile ()).

  (* repeat (docompile ()). *)



  eapply auto_let; intros.
  all: try (eapply auto_num_add); intros.
  all: try (eapply auto_num_const); intros.
  (* all: repeat (autostep; intros). *)
  all: try eapply trans_Var; try eapply FEnv.lookup_insert_eq.
  all: repeat split.
  all: eauto.
  - exact I.
  - exact (fun n : nat => I).
  Unshelve.
  exact [].
  Show Proof.
  intros; eexists.
  Opaque encode.
  repeat (autostep; intros).
  Show Proof.

  eauto with automation. *)
 *)
