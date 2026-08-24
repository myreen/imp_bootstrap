Theory imp_automation_lemmas
Ancestors
  arithmetic list pair finite_map string
  source_values source_syntax source_semantics codegen
  source_properties parsing x64asm_syntax words
  imp_source_syntax automation_lemmas
Libs
  wordsLib


(* a bit of automation for cons lemmas *)

local
  val b_tm = “b:bool”
  val x_tm = “x:exp”
  val v_tm = “v:v”
in
  val env_tm = “env:num -> v option”
  val basic_tm = “^b_tm ⇒ (^env_tm,[^x_tm],s) ---> ([^v_tm],s)”
  fun mk_basic_env env b x v =
    basic_tm |> subst [env_tm|->env,v_tm|->v,b_tm|->b,x_tm|->x]
  val mk_basic = mk_basic_env env_tm
end

fun prove_cons inv_def = let
  fun prove_cons th = let
    val x = th |> concl
    val body = repeat (snd o dest_forall) x
    val (l,r) = dest_eq body
    val (name,is_enum) = (r |> rand |> rator |> rand |> rand, false)
                         handle HOL_ERR _ => (r |> rand, true)
    val const = “Const ^name”
    val vs = if is_enum then [] else r |> rand |> rand |> listSyntax.dest_list |> fst
    fun mk v = let
      val vn = v |> rand |> dest_var |> fst
      val new_x = mk_var("x_" ^ vn, “:exp”)
      val new_b = mk_var("b_" ^ vn, “:bool”)
      in (new_b,(new_x,mk_basic new_b new_x v)) end
    val xs = map mk vs
    val exps = const :: (map (fst o snd) xs @ [“Const 0”])
    val bs = if null xs then T else list_mk_conj (map fst xs)
    val new_x = if is_enum then const
                else mk_comb(“parsing$conses”,listSyntax.mk_list(exps,type_of const))
    val goal = mk_basic bs new_x l
    val goal = if null xs then goal else
      mk_imp(list_mk_conj (map (snd o snd) xs),goal)
    val tac =
      rw [Eval_eq,th,return_def,name_def,AllCaseEqs(),PULL_EXISTS,fail_def,
          parsingTheory.conses_def,eval_op_def]
      \\ fs [] \\ rpt (goal_assum (first_assum o mp_then Any mp_tac) \\ fs [])
    val res = prove(goal,tac)
    in res |> PURE_REWRITE_RULE [parsingTheory.conses_def] end
  in inv_def |> CONJUNCTS |> map prove_cons |> LIST_CONJ end

(* a bit of automation for case lemmas *)

fun prove_case inv_def = let
  fun right_dest f z =
    (case f z of (x,y) => [x] @ right_dest f y) handle HOL_ERR _ => [z];
  val inv_rows = inv_def |> CONJUNCTS
  val ty = inv_rows |> hd |> SPEC_ALL |> concl |> dest_eq |> fst |> rand |> type_of
  val in_inv = inv_rows |> hd |> SPEC_ALL |> concl |> dest_eq |> fst |> rator
  val case_const = TypeBase.case_const_of ty
  val conses = TypeBase.constructors_of ty
  fun dest_fun_type ty =
    case dest_type ty of ("fun",[a,b]) => (a,b) | _ => fail()
  val tys = tl (right_dest dest_fun_type (type_of case_const))
  val res_ty = last tys
  val case_tys = butlast tys
  fun mk_funs (c,ty) = mk_var("f_" ^ fst (dest_const c), ty)
  val f_tms = map mk_funs (zip conses case_tys)
  val v = mk_var("v0",ty)
  val res = list_mk_comb(case_const, v :: f_tms)
  val inv = mk_var(dest_vartype res_ty |> explode |> tl |> implode,
               mk_type("fun",[res_ty,“:v”]))
  val res_v = mk_comb(inv,res)
  val b0 = mk_var("b0",“:bool”)
  val x0 = mk_var("x0",“:source_syntax$exp”)
  val v0 = mk_var("v0",ty)
  val asm0 = mk_basic b0 x0 (mk_comb(in_inv,v0))
(*
  val (f,c) = hd (zip f_tms conses)
*)
  fun process_row (f,c) = let
    val s = dest_const c |> fst
    val row = first (can (find_term (aconv c)) o concl) inv_rows |> SPEC_ALL
    val c_case = row |> concl |> rator |> rand |> rand
    val cs = row |> concl |> rand |> rand
    val (name,is_enum) = (cs |> rator |> rand |> rand,false) handle HOL_ERR _ => (cs,true)
    val args = if is_enum then [] else cs |> rand |> listSyntax.dest_list |> fst
    val vs = map rand args
    val res = list_mk_comb(f,vs)
    (* make the b *)
    val bvar = mk_var("b_" ^ s,
        wfrecUtils.list_mk_fun_type(map (type_of o rand) args @ [“:bool”]))
    val b_tm = list_mk_comb(bvar,vs)
    (* make env *)
    val strs = map (fn v => mk_var(fst (dest_var v) ^ "_" ^ s,“:string”)) vs
    val nums = map (fn t => “name ^t”) strs
    val ups = map combinSyntax.mk_update (zip nums (map optionSyntax.mk_some args))
    val new_env = foldl mk_comb env_tm ups
    (* make asm *)
    val x = mk_var(s ^ "_exp",“:exp”)
    val asm = list_mk_forall(vs,mk_basic_env new_env b_tm x (mk_comb(inv,res)))
    (* for code construction *)
    val t1 = name |> rand
    val t2 = listSyntax.mk_list(strs,“:string”)
    val t = if is_enum then pairSyntax.mk_pair(t1,x)
            else pairSyntax.mk_pair(t1,pairSyntax.mk_pair(t2,x))
    (* construct pre *)
    val ns = listSyntax.mk_list(if null nums then [] else butlast nums,“:num”)
    val b_tm = if is_enum then b_tm else
                 mk_conj(b_tm,“ALL_DISTINCT (^ns ++ free_vars ^x0)”)
    val pre = list_mk_forall(vs,mk_imp(mk_eq(v0,c_case),b_tm))
    in (asm,(t,pre)) end
  val xs = map process_row (zip f_tms conses)
  val asm = list_mk_conj(b0 :: map (snd o snd) xs)
  val ys = map (fst o snd) xs
  val x = listSyntax.mk_list(ys,type_of(hd ys))
  val is_enum = not (can (first (can dest_fun_type o type_of)) conses)
  val code = if is_enum then list_mk_comb(“case_enum”,[x0,x])
             else list_mk_comb(“case_tree”,[x0,x])
  val goal = mk_imp(list_mk_conj(asm0::map fst xs),mk_basic asm code res_v)
  val tac =
      Cases_on ‘v0’ \\ fs [] \\ rw [] \\ fs []
      \\ rpt (full_simp_tac (srw_ss())
                 [Eval_eq,PULL_EXISTS,eval_op_def,AllCaseEqs(),fail_def,
                  take_branch_def,return_def,name_def,inv_def]
              \\ goal_assum (first_assum o mp_then Any mp_tac)
              \\ full_simp_tac (srw_ss()) [])
  in prove(goal,tac)
     |> PURE_REWRITE_RULE [case_lets_def,case_tree_def,case_enum_def] end

(* exp from imp_syntax *)

Definition exp_def:
  exp (Var n) = list [Name "Var"; Num n] ∧
  exp (imp_source_syntax$Const w) = list [Name "Const"; word w] ∧
  exp (Add e1 e2) = list [Name "Add"; exp e1; exp e2] ∧
  exp (Sub e1 e2) = list [Name "Sub"; exp e1; exp e2] ∧
  exp (Div e1 e2) = list [Name "Div"; exp e1; exp e2] ∧
  exp (Read e1 e2) = list [Name "Read"; exp e1; exp e2]
End

Theorem auto_exp_cons = prove_cons exp_def;
Theorem auto_exp_case = prove_case exp_def;

(* cmp from imp_syntax *)

Definition cmp_def[simp]:
  cmp imp_source_syntax$Equal = Name "Equal" ∧
  cmp imp_source_syntax$Less = Name "Less"
End

Theorem auto_cmp_cons = prove_cons cmp_def;
Theorem auto_cmp_case = prove_case cmp_def;

(* test from imp_syntax *)

Definition test_def:
  test (imp_source_syntax$Test c e1 e2) = list [Name "Test"; cmp c; exp e1; exp e2] ∧
  test (imp_source_syntax$And t1 t2) = list [Name "And"; test t1; test t2] ∧
  test (imp_source_syntax$Or t1 t2) = list [Name "TOr"; test t1; test t2] ∧
  test (imp_source_syntax$Not t) = list [Name "Not"; test t]
End

Theorem auto_test_cons = prove_cons test_def;
Theorem auto_test_case = prove_case test_def;

(* cmd from imp_syntax *)

Definition cmd_def:
  cmd Skip              = list [Name "Skip"] ∧
  cmd (Seq c1 c2)       = list [Name "Seq"; cmd c1; cmd c2] ∧
  cmd (Assign n e)      = list [Name "Assign"; Num n; exp e] ∧
  cmd (Update e1 e2 e3) = list [Name "Update"; exp e1; exp e2; exp e3] ∧
  cmd (If t c1 c2)      = list [Name "If"; test t; cmd c1; cmd c2] ∧
  cmd (While t c)       = list [Name "While"; test t; cmd c] ∧
  cmd (Call n1 n2 es)   = list [Name "Call"; Num n1; Num n2; map exp es] ∧
  cmd (Return e)        = list [Name "Return"; exp e] ∧
  cmd (Alloc n e)       = list [Name "Alloc"; Num n; exp e] ∧
  cmd (GetChar n)       = list [Name "GetChar"; Num n] ∧
  cmd (PutChar e)       = list [Name "PutChar"; exp e] ∧
  cmd Abort             = list [Name "Abort"]
End

Theorem auto_cmd_cons = prove_cons cmd_def;
Theorem auto_cmd_case = prove_case cmd_def;

(* func from imp_syntax *)

Definition func_def:
  func (Func n ns c) = list [Name "Func"; Num n; map Num ns; cmd c]
End

Theorem auto_func_cons = prove_cons func_def;
Theorem auto_func_case = prove_case func_def;

(* prog from imp_syntax *)

Definition prog_def:
  prog (Program fs) = list [Name "Program"; map func fs]
End

Theorem auto_prog_cons = prove_cons prog_def;
Theorem auto_prog_case = prove_case prog_def;

(* case expressions over v *)

Theorem auto_v_case:
  (b0 ⇒ (env,[x0],s) ---> ([deep v0],s)) ∧
  (∀xs.
     b_Num xs ⇒
     (env⦇name xs_Num ↦ SOME (Num xs)⦈,[Num_exp],s) --->
     ([b (f_Num xs)],s)) ∧
  (∀x y.
     b_Pair x y ⇒
     (env⦇
         name y_Pair ↦ SOME (deep y);
         name x_Pair ↦ SOME (deep x)
         ⦈,[Pair_exp],s) ---> ([b (f_Pair x y)],s)) ⇒
  b0 ∧
  (∀xs. v0 = Num xs ⇒ b_Num xs ∧ ALL_DISTINCT ([] ⧺ free_vars x0)) ∧
  (∀x y.
     v0 = Pair x y ⇒
     b_Pair x y ∧ ALL_DISTINCT ([name x_Pair] ⧺ free_vars x0)) ⇒
  (env,
   [If Equal [Const 1; Op Head [x0]]
       (Let (name xs_Num) (Op Tail [x0]) Num_exp)
       (Let (name x_Pair) (Op Head [Op Tail [x0]]) $
        Let (name y_Pair) (Op Tail [Op Tail [x0]])
              Pair_exp)],s) --->
  ([b (v_CASE v0 f_Pair f_Num)],s)
Proof
  rpt strip_tac \\ gvs []
  \\ reverse $ Cases_on ‘v0’ \\ fs []
  \\ simp [Once Eval_cases]
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ last_assum $ irule_at Any
  \\ simp [eval_op_def, return_def, take_branch_def]
  >-
   (simp [Once Eval_cases, PULL_EXISTS]
    \\ simp [Once Eval_cases, PULL_EXISTS]
    \\ last_assum $ irule_at Any
    \\ simp [eval_op_def, return_def, take_branch_def])
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ last_assum $ irule_at Any
  \\ simp [eval_op_def, return_def, take_branch_def]
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ simp [Once Eval_cases, PULL_EXISTS]
  \\ last_assum $ irule_at Any
  \\ simp [eval_op_def, return_def, take_branch_def]
QED
