Theory source_to_imp
Ancestors
  arithmetic list pair finite_map string pred_set combin
  source_syntax imp_source_syntax source_semantics imp_source_semantics
Libs
  wordsLib


(* definition of a very partial compilation from source to imp_source *)

Definition to_exp_def:
  to_exp (Var v) =
    SOME (Var v) ∧
  to_exp (Const n) =
    (if n < 2**64 then SOME (Const (n2w n)) else NONE) ∧
  to_exp (Op Head [x]) =
    OPTION_MAP (λe. Read e (Const 0w)) (to_exp x) ∧
  to_exp (Op Tail [x]) =
    OPTION_MAP (λe. Read e (Const 8w)) (to_exp x) ∧
  to_exp _ = NONE
End

Definition to_exps_def:
  to_exps [] = SOME [] ∧
  to_exps (x::xs) =
    case (to_exp x, to_exps xs) of
    | (SOME y, SOME ys) => SOME (y::ys)
    | _ => NONE
End

Definition to_test_def:
  to_test source_syntax$Equal = imp_source_syntax$Equal ∧
  to_test source_syntax$Less = imp_source_syntax$Less
End

Definition to_guard_def:
  to_guard t es =
    case to_exps es of
    | SOME [x1;x2] => SOME (Test (to_test t) x1 x2)
    | _ => NONE
End

Definition dest_Cons_def:
  dest_Cons (Op Cons [e1; e2]) =
    (case to_exp e1 of
     | NONE => NONE
     | SOME e => SOME (e,e2)) ∧
  dest_Cons _ = NONE
End

Definition to_cons_def:
  to_cons v x =
    case dest_Cons x of
    | NONE => NONE
    | SOME (e1,x) =>
    case dest_Cons x of
    | NONE => OPTION_MAP (λe2. (Call v (name "cons") [e1; e2])) (to_exp x)
    | SOME (e2,x) =>
    case dest_Cons x of
    | NONE => OPTION_MAP (λe3. (Call v (name "cons3") [e1; e2; e3])) (to_exp x)
    | SOME (e3,x) =>
    case dest_Cons x of
    | NONE => OPTION_MAP (λe4. (Call v (name "cons4") [e1; e2; e3; e4])) (to_exp x)
    | SOME (e4,x) =>
              OPTION_MAP (λe5. (Call v (name "cons5") [e1; e2; e3; e4; e5])) (to_exp x)
End

Definition to_assign_def:
  to_assign v x =
    case to_exp x of
    | SOME i => SOME (Assign v i)
    | NONE =>
      case to_cons v x of
      | SOME r => SOME r
      | NONE =>
        case x of
        | Call n es =>
            (case to_exps es of
             | SOME xs => SOME (Call v n xs)
             | NONE => NONE)
        | Op p es =>
            (case p, to_exps es of
             | (Add,SOME [x1;x2]) => SOME (Call v (name "add") [x1;x2])
             | (Sub,SOME [x1;x2]) => SOME (Call v (name "sub") [x1;x2])
             | (Div,SOME [x1;x2]) => SOME (Assign v (Div x1 x2))
             | (Read,SOME [])     => SOME (GetChar v)
             | (Write,SOME [x1])  => SOME (Seq (PutChar x1) (Assign v (Const 0w)))
             | _ => NONE)
        | _ => NONE
End

Definition to_cmd_def:
  to_cmd (e:source_syntax$exp) =
    case to_exp e of
    | SOME i => SOME (Return i : cmd)
    | NONE =>
      case e of
      | If t es e1 e2 =>
         (case to_guard t es, to_cmd e1, to_cmd e2 of
          | (SOME t1, SOME c1, SOME c2) => SOME (If t1 c1 c2)
          | _ => NONE)
      | Let v x y =>
         (case to_assign v x, to_cmd y of
          | (SOME c1, SOME c2) => SOME (Seq c1 c2)
          | _ => NONE)
      | Call n es =>
         (case to_exps es of
          | SOME xs => SOME (Seq (Call (name "ret") n xs) (Return (Var (name "ret"))))
          | _ => NONE)
      | _ => NONE
End

Definition to_funs_def:
  to_funs [] = SOME [] ∧
  to_funs ((Defun n vs e)::fs) =
    if ~ ALL_DISTINCT vs then NONE else
    case to_cmd e, to_funs fs of
    | (SOME cmd, SOME funs) => SOME (Func n vs cmd :: funs)
    | _ => NONE
End

Definition list_Seq_def[simp]:
  list_Seq [] = Skip ∧
  list_Seq [x] = x ∧
  list_Seq (x::xs) = Seq x (list_Seq xs)
End

Definition builtin_def:
  builtin =
    [(name "add",[name "a"; name "b"], list_Seq
       [Assign (name "c") (Add (Var (name "a")) (Var (name "b")));
        If (Test Less (Var (name "c")) (Var (name "a"))) Abort Skip;
        If (Test Less (Var (name "c")) (Var (name "b"))) Abort Skip;
        Return (Var (name "c"))]);
     (name "sub",[name "a"; name "b"], list_Seq
       [If (Test Less (Var (name "a")) (Var (name "b")))
          (Return (Const 0w))
          (Return (Sub (Var (name "a")) (Var (name "b"))))]);
     (name "cons",[name "a"; name "b"], list_Seq
       [Alloc (name "ret") (Const 16w);
        Update (Var $ name "ret") (Const 0w) (Var $ name "a");
        Update (Var $ name "ret") (Const 8w) (Var $ name "b");
        Return (Var $ name "ret")]);
     (name "cons3",[name "a"; name "b"; name "c"], list_Seq
       [Call (name "ret") (name "cons") [Var (name "b"); Var (name "c")];
        Call (name "ret") (name "cons") [Var (name "a"); Var (name "ret")];
        Return (Var $ name "ret")]);
     (name "cons4",[name "a"; name "b"; name "c"; name "d"], list_Seq
       [Call (name "ret") (name "cons3") [Var (name "b"); Var (name "c"); Var (name "d")];
        Call (name "ret") (name "cons") [Var (name "a"); Var (name "ret")];
        Return (Var $ name "ret")]);
     (name "cons5",[name "a"; name "b"; name "c"; name "d"; name "e"], list_Seq
       [Call (name "ret") (name "cons4")
          [Var (name "b"); Var (name "c"); Var (name "d"); Var (name "e")];
        Call (name "ret") (name "cons") [Var (name "a"); Var (name "ret")];
        Return (Var $ name "ret")])]
End

Definition func_name_def[simp]:
  func_name (Defun fname params body) = fname
End

Definition to_imp_def:
  to_imp (source_syntax$Program l e) =
    if EXISTS (λx. MEM (func_name x) (name "main" :: MAP FST builtin)) l then NONE else
    case to_funs (Defun (name "main") [] e :: l) of
    | SOME fs => SOME (imp_source_syntax$Program $ MAP (λ(n,vs,b). Func n vs b) builtin ++ fs)
    | NONE => NONE
End

(* semntics preservation (forward only) *)

Inductive v_rel:
  (∀n mem.
     n < 2 ** 64 ⇒
     v_rel mem (Num n) (Word (n2w n))) ∧
  (∀mem p v1 v2 w1 w2.
     oEL p mem = SOME [SOME w1; SOME w2] ∧
     v_rel mem v1 w1 ∧
     v_rel mem v2 w2 ⇒
     v_rel mem (Pair v1 v2) (Pointer p))
End

Definition func_rel_def:
  func_rel s t ⇔
    EVERY (λ(n,ps,cs). find_fun n t = SOME (ps,cs)) builtin ∧
    ∀fname params body.
      lookup_fun fname s = SOME (params,body) ⇒
      ∃cs. find_fun fname t = SOME (params,cs) ∧
           to_cmd body = SOME cs ∧ ALL_DISTINCT params
End

Definition state_rel_def:
  state_rel s t ⇔
    t.input = s.input ∧
    t.output = s.output ∧
    func_rel s.funs t.funs
End

Definition env_rel_def:
  env_rel mem s_env t_env ⇔
    ∀n v.
      s_env n = SOME v ⇒
      ∃w. FLOOKUP t_env n = SOME w ∧ v_rel mem v w
End

Definition res_rel_def[simp]:
  res_rel mem v (Stop (Return w)) s t = (v_rel mem v w ∧ state_rel s t) ∧
  res_rel mem v (Stop Abort) s t = T ∧
  res_rel mem v _ s t = F
End

Theorem to_exp_thm:
  ∀e x s t env v s1.
    to_exp e = SOME x ∧ state_rel s t ∧ env_rel t.memory env t.vars ∧
    (env, [e], s) ---> ([v],s1) ⇒
    ∃w.
      (∀k. eval_exp x (t with clock := k) =
           ((Cont w) :(v,v) outcome, t with clock := k)) ∧
      s = s1 ∧ v_rel t.memory v w
Proof
  gen_tac \\ completeInduct_on ‘exp_size e’
  \\ gen_tac \\ strip_tac \\ gvs [PULL_FORALL]
  \\ once_rewrite_tac [DefnBase.one_line_ify NONE to_exp_def]
  \\ fs [AllCaseEqs()]
  \\ rpt strip_tac \\ gvs []
  >~ [‘Const’] >-
   (last_x_assum kall_tac
    \\ gvs [Once Eval_cases]
    \\ fs [state_rel_def,Once v_rel_cases])
  >~ [‘Var’] >-
   (last_x_assum kall_tac
    \\ gvs [Once Eval_cases,env_rel_def]
    \\ res_tac \\ fs [state_rel_def])
  \\ first_x_assum $ drule_at $ Pos $ el 2
  \\ pop_assum mp_tac
  \\ simp [Once Eval_cases]
  \\ strip_tac
  \\ pop_assum mp_tac
  \\ simp [eval_op_def |> DefnBase.one_line_ify NONE,AllCaseEqs()]
  \\ gvs [fail_def] \\ strip_tac
  \\ gvs [return_def,source_syntaxTheory.exp_size_def,GSYM PULL_FORALL]
  \\ disch_then drule_all
  \\ strip_tac \\ gvs [bind_def]
  \\ pop_assum mp_tac
  \\ simp [Once v_rel_cases] \\ strip_tac \\ gvs [oEL_def]
QED

Theorem Eval_cons:
  (env,e::es,s) ---> (vs,s1) ⇒
  ∃v s0 vs1.
    vs = v::vs1 ∧
    (env,[e],s) ---> ([v],s0) ∧
    (env,es,s0) ---> (vs1,s1)
Proof
  simp [Once Eval_cases] \\ rw []
  \\ rpt (first_x_assum $ irule_at Any \\ fs [])
  \\ simp [Once Eval_cases]
  \\ rpt (first_x_assum $ irule_at Any \\ fs [])
  \\ simp [Once Eval_cases]
QED

Theorem to_exps_thm:
  ∀es xs s t env vs s1.
    to_exps es = SOME xs ∧ state_rel s t ∧ env_rel t.memory env t.vars ∧
    (env, es, s) ---> (vs,s1) ⇒
    ∃ws.
      (∀k. eval_exps xs (t with clock := k) =
           ((Cont ws) :(v,v list) outcome, t with clock := k)) ∧
      LENGTH es = LENGTH xs ∧
      s = s1 ∧ LIST_REL (v_rel t.memory) vs ws
Proof
  Induct
  >- (fs [to_exps_def] \\ simp [Once Eval_cases])
  \\ fs [to_exps_def,AllCaseEqs(),PULL_EXISTS] \\ rw []
  \\ drule_then strip_assume_tac Eval_cons \\ gvs []
  \\ drule_all to_exp_thm \\ strip_tac \\ gvs [bind_def,PULL_EXISTS]
  \\ first_x_assum drule_all \\ strip_tac \\ gvs []
QED

Triviality with_clock[simp]:
  ((t:imp_source_semantics$state) with clock := t.clock) = t
Proof
  fs [imp_source_semanticsTheory.state_component_equality]
QED

Theorem Eval_length:
  ∀env es s rs s1.
    (env, es, s) ---> (rs,s1) ⇒ LENGTH es = LENGTH rs
Proof
  ho_match_mp_tac (Eval_strongind |> SIMP_RULE std_ss [FORALL_PROD]
    |> Q.SPEC ‘λ(x1,x2,x3) (y1,y2). P x1 x2 x3 y1 y2’
    |> SIMP_RULE std_ss [FORALL_PROD] |> GEN_ALL)
  \\ rpt conj_tac \\ simp []
QED

Theorem env_rel_update:
  env_rel m env vars ∧ v_rel m v1 w ⇒
  env_rel m env⦇n ↦ SOME v1⦈ (vars |+ (n,w))
Proof
  fs [env_rel_def,FLOOKUP_UPDATE,APPLY_UPDATE_THM,AllCaseEqs()]
  \\ rw [] \\ res_tac \\ fs []
QED

Triviality oEL_isPREFIX:
  ∀xs ys n y. xs ≼ ys ∧ oEL n xs = SOME y ⇒ oEL n ys = SOME y
Proof
  Induct \\ Cases_on ‘ys’ \\ fs [oEL_def] \\ rw []
QED

Theorem v_rel_isPREFIX:
  ∀m v w. v_rel m v w ⇒ ∀m'. m ≼ m' ⇒ v_rel m' v w
Proof
  Induct_on ‘v_rel’ \\ rw []
  \\ simp [Once v_rel_cases] \\ gvs []
  \\ drule_all oEL_isPREFIX \\ rw []
QED

Theorem env_rel_isPREFIX:
  env_rel m1 env vars ∧ m1 ≼ m2 ⇒ env_rel m2 env vars
Proof
  rw [env_rel_def] \\ res_tac \\ fs []
  \\ drule_all v_rel_isPREFIX \\ fs []
QED

Theorem eval_exp_with_clock:
  ∀e s v s1.
    eval_exp e s = (v,s1) ⇒
    eval_exp e (s with clock := s.clock + k) = (v,s1 with clock := s1.clock + k)
Proof
  Induct
  \\ fs [eval_exp_def,AllCaseEqs(),bind_def] \\ rw []
  \\ res_tac \\ fs [combine_words_def |> DefnBase.one_line_ify NONE, AllCaseEqs()]
  \\ rpt (CASE_TAC \\ gvs [])
  \\ fs [AllCaseEqs(),bind_def,mem_load_def |> DefnBase.one_line_ify NONE] \\ rw []
QED

Theorem eval_exps_with_clock:
  ∀e s v s1.
    eval_exps e s = (v,s1) ⇒
    eval_exps e (s with clock := s.clock + k) = (v,s1 with clock := s1.clock + k)
Proof
  Induct
  \\ gvs [eval_exps_def,bind_def,AllCaseEqs()]
  \\ rw [] \\ imp_res_tac eval_exp_with_clock
  \\ res_tac \\ fs []
QED

Theorem eval_test_with_clock:
  ∀e s v s1.
    eval_test e s = (v,s1) ⇒
    eval_test e (s with clock := s.clock + k) = (v,s1 with clock := s1.clock + k)
Proof
  Induct
  \\ gvs [eval_test_def,bind_def,AllCaseEqs()]
  \\ rw [] \\ imp_res_tac eval_exp_with_clock
  \\ res_tac \\ fs []
  \\ gvs [eval_cmp_def |> DefnBase.one_line_ify NONE, AllCaseEqs()]
  \\ rpt (CASE_TAC \\ gvs [])
QED

Theorem eval_cmd_add_clock:
  ∀cs s res s1.
    eval_cmd cs s = (res,s1) ∧ res ≠ Stop TimeOut ⇒
    ∀k. eval_cmd cs (s with clock := s.clock + k) = (res,s1 with clock := s1.clock + k)
Proof
  ho_match_mp_tac eval_cmd_ind \\ rw []
  >- gvs [eval_cmd_def,AllCaseEqs(),bind_def]
  >- gvs [eval_cmd_def,AllCaseEqs(),bind_def]
  >- (gvs [eval_cmd_def,bind_def,eval_exp_with_clock,CaseEq"prod"]
      \\ imp_res_tac eval_exp_with_clock \\ fs [] \\ gvs [AllCaseEqs()])
  >- gvs [eval_cmd_def,AllCaseEqs(),bind_def]
  >- (gvs [eval_cmd_def,bind_def,eval_exp_with_clock,CaseEq"prod"]
      \\ imp_res_tac eval_exp_with_clock \\ fs []
      \\ gvs [AllCaseEqs(),put_char_def |> DefnBase.one_line_ify NONE])
  >- gvs [eval_cmd_def,AllCaseEqs(),bind_def,get_char_def]
  >- (gvs [eval_cmd_def,bind_def,CaseEq"prod"]
      \\ imp_res_tac eval_exp_with_clock \\ fs []
      \\ gvs [AllCaseEqs(),alloc_def])
  >- (gvs [eval_cmd_def,bind_def,CaseEq"prod"]
      \\ imp_res_tac eval_exp_with_clock \\ fs []
      \\ gvs [AllCaseEqs(),update_def |> DefnBase.one_line_ify NONE]
      \\ imp_res_tac eval_exp_with_clock \\ fs [])
  >- (gvs [eval_cmd_def,bind_def,CaseEq"prod"]
      \\ imp_res_tac eval_test_with_clock \\ gvs []
      \\ gvs [AllCaseEqs()])
  >- (gvs [eval_cmd_def,bind_def,eval_exp_with_clock,CaseEq"prod"]
      \\ imp_res_tac eval_exp_with_clock \\ fs []
      \\ gvs [AllCaseEqs()])
  >- (fs [eval_cmd_def,CaseEq"prod"]
      \\ imp_res_tac eval_exps_with_clock \\ fs []
      \\ gvs [AllCaseEqs(),tick_def])
  \\ qpat_x_assum ‘eval_cmd _ _ = _’ mp_tac
  \\ once_rewrite_tac [eval_cmd_def]
  \\ gvs [bind_def,CaseEq"prod"] \\ rw []
  \\ imp_res_tac eval_test_with_clock \\ gvs []
  \\ gvs [AllCaseEqs(),tick_def]
QED

Theorem env_rel_make_env:
  LIST_REL (v_rel m) rs ws ∧ LENGTH params = LENGTH ws ⇒
  env_rel m (make_env params rs empty_env) (FEMPTY |++ ZIP (params,ws))
Proof
  fs [env_rel_def,PULL_FORALL,AND_IMP_INTRO] \\ rw []
  \\ qsuff_tac ‘
    ∀rs ws params m1 m2.
       LIST_REL (v_rel m) rs ws ∧
       LENGTH params = LENGTH ws ∧
       (∀n v1. m1 n = SOME v1 ⇒ ∃v2. FLOOKUP m2 n = SOME v2 ∧ v_rel m v1 v2) ∧
       make_env params rs m1 n = SOME v ⇒
       ∃w. FLOOKUP (m2 |++ ZIP (params,ws)) n = SOME w ∧ v_rel m v w’
  >-
   (disch_then irule \\ fs []
    \\ rpt $ first_x_assum $ irule_at Any
    \\ fs [empty_env_def])
  \\ rpt $ pop_assum kall_tac
  \\ Induct \\ fs [make_env_def,PULL_EXISTS,FUPDATE_LIST]
  \\ gen_tac \\ Cases \\ fs [] \\ rw []
  \\ fs [make_env_def]
  \\ last_x_assum $ drule_at $ Pos last
  \\ disch_then drule \\ fs []
  \\ disch_then irule
  \\ gvs [APPLY_UPDATE_THM,FLOOKUP_UPDATE]
  \\ rw [] \\ fs []
QED

Theorem v_rel_Num =
  SIMP_CONV (srw_ss()) [Once v_rel_cases] “v_rel m (Num n) v”;

Theorem dest_Cons_SOME =
  “dest_Cons x = SOME (e1,e2)”
  |> SIMP_CONV (srw_ss()) [dest_Cons_def |> DefnBase.one_line_ify NONE,
                           AllCaseEqs(),PULL_EXISTS];

Theorem oEL_LENGTH:
  ∀xs y ys. oEL (LENGTH xs) (xs ++ y::ys) = SOME y
Proof
  Induct \\ fs [oEL_def]
QED

Theorem names_back = LIST_CONJ $ map (GSYM o EVAL)
  [“name "a"”, “name "b"”, “name "c"”, “name "d"”, “name "e"”, “name "ret"”,
   “name "cons"”, “name "cons3"”, “name "cons4"”, “name "cons5"”,
   “imp_source_syntax$Var $ name "a"”,
   “imp_source_syntax$Var $ name "b"”,
   “imp_source_syntax$Var $ name "c"”,
   “imp_source_syntax$Var $ name "d"”,
   “imp_source_syntax$Var $ name "e"”];

Theorem Call_cons:
  ∀e1 e2 x y w w' n.
    v_rel t.memory y w' ∧
    v_rel t.memory x w ∧
    (∀k. eval_exp e2 (t with clock := k) = (Cont w' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e1 (t with clock := k) = (Cont w :(v,v)outcome,t with clock := k)) ∧
    EVERY (λ(n,ps,cs). find_fun n t.funs = SOME (ps,cs)) builtin ⇒
    ∃m1 ptr.
      ∀k c2.
          eval_cmd (Seq (Call n (name "cons") [e1; e2]) c2)
                   (t with clock := SUC k + t.clock) =
          eval_cmd c2
                   (t with <| vars := t.vars |+ (n,ptr) ;
                              memory := t.memory ++ m1 ;
                              clock := k + t.clock |>)  ∧
          v_rel (t.memory ++ m1) (Pair x y) ptr
Proof
  rw [Once eval_cmd_def]
  \\ simp [eval_cmd_def,bind_def,tick_def]
  \\ fs [builtin_def,source_valuesTheory.name_def,ADD1]
  \\ rpt $ qpat_x_assum ‘find_fun _ _ = _’ kall_tac
  \\ fs [eval_cmd_def,bind_def,alloc_def,FUPDATE_LIST,FLOOKUP_UPDATE,
         EVAL “REPLICATE 2 x”,update_def,oEL_LENGTH,update_block_def]
  \\ fs [LUPDATE_def,EVAL “LUPDATE t 1 [x;y]”]
  \\ qexists_tac ‘[[SOME w; SOME w']]’
  \\ qexists_tac ‘Pointer (LENGTH t.memory)’ \\ fs []
  \\ simp [Once v_rel_cases,oEL_LENGTH] \\ strip_tac
  \\ irule_at Any v_rel_isPREFIX
  \\ first_x_assum $ irule_at Any \\ fs []
QED

Theorem Call_cons3:
  ∀e1 e2 e3 x y z w w' w'' n.
    v_rel t.memory z w'' ∧
    v_rel t.memory y w' ∧
    v_rel t.memory x w ∧
    (∀k. eval_exp e3 (t with clock := k) = (Cont w'' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e2 (t with clock := k) = (Cont w' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e1 (t with clock := k) = (Cont w :(v,v)outcome,t with clock := k)) ∧
    EVERY (λ(n,ps,cs). find_fun n t.funs = SOME (ps,cs)) builtin ⇒
    ∃ck m1 ptr.
      ∀k c2.
          eval_cmd (Seq (Call n (name "cons3") [e1; e2; e3]) c2)
                   (t with clock := (SUC $ SUC $ SUC k) + t.clock) =
          eval_cmd c2
                   (t with <| vars := t.vars |+ (n,ptr) ;
                              memory := t.memory ++ m1 ;
                              clock := k + t.clock |>)  ∧
          v_rel (t.memory ++ m1) (Pair x (Pair y z)) ptr
Proof
  rw [Once eval_cmd_def]
  \\ simp [eval_cmd_def,bind_def,tick_def]
  \\ fs [builtin_def,source_valuesTheory.name_def]
  \\ gvs [names_back]
  \\ qmatch_goalsub_abbrev_tac ‘FEMPTY |++ vars’
  \\ qspecl_then [‘t with vars := FEMPTY |++ vars’,‘Var (name "b")’,‘Var (name "c")’] mp_tac
        (Q.GEN ‘t’ Call_cons)
  \\ gvs [FUPDATE_LIST,Abbr‘vars’,FLOOKUP_UPDATE,source_valuesTheory.name_def]
  \\ rpt $ disch_then drule
  \\ impl_tac >- (fs [builtin_def,source_valuesTheory.name_def])
  \\ disch_then $ qspec_then ‘name "ret"’ strip_assume_tac
  \\ simp [Once ADD1]
  \\ gvs [source_valuesTheory.name_def] \\ gvs [names_back]
  \\ gvs [GSYM PULL_FORALL]
  \\ qpat_x_assum ‘∀x. _’ kall_tac
  \\ qabbrev_tac ‘t2 = t with <|vars :=
       FEMPTY |+ (97,w) |+ (98,w') |+ (99,w'') |+
        (name "ret",ptr); memory := t.memory ⧺ m1 |>’
  \\ qspecl_then [‘t2’,‘Var (name "a")’,‘Var (name "ret")’] mp_tac (Call_cons |> Q.GEN ‘t’)
  \\ gvs [source_valuesTheory.name_def,Abbr‘t2’,FLOOKUP_UPDATE]
  \\ disch_then drule
  \\ disch_then $ qspecl_then [‘x’,‘name "ret"’] mp_tac
  \\ impl_tac
  >-
   (irule_at Any v_rel_isPREFIX
    \\ first_x_assum $ irule_at Any
    \\ fs [builtin_def,source_valuesTheory.name_def])
  \\ strip_tac \\ gvs [source_valuesTheory.name_def]
  \\ fs [eval_cmd_def,bind_def,FLOOKUP_UPDATE,GSYM PULL_FORALL]
  \\ full_simp_tac std_ss [GSYM APPEND_ASSOC]
  \\ pop_assum $ irule_at Any \\ fs []
QED

Theorem Call_cons4:
  ∀e1 e2 e3 e4 x y z q w w' w'' w''' n.
    v_rel t.memory q w''' ∧
    v_rel t.memory z w'' ∧
    v_rel t.memory y w' ∧
    v_rel t.memory x w ∧
    (∀k. eval_exp e4 (t with clock := k) = (Cont w''' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e3 (t with clock := k) = (Cont w'' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e2 (t with clock := k) = (Cont w' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e1 (t with clock := k) = (Cont w :(v,v)outcome,t with clock := k)) ∧
    EVERY (λ(n,ps,cs). find_fun n t.funs = SOME (ps,cs)) builtin ⇒
    ∃ck m1 ptr.
      ∀k c2.
          eval_cmd (Seq (Call n (name "cons4") [e1; e2; e3; e4]) c2)
                   (t with clock := (SUC $ SUC $ SUC $ SUC $ SUC k) + t.clock) =
          eval_cmd c2
                   (t with <| vars := t.vars |+ (n,ptr) ;
                              memory := t.memory ++ m1 ;
                              clock := k + t.clock |>)  ∧
          v_rel (t.memory ++ m1) (Pair x (Pair y (Pair z q))) ptr
Proof
  rw [Once eval_cmd_def]
  \\ simp [eval_cmd_def,bind_def,tick_def]
  \\ fs [builtin_def,source_valuesTheory.name_def]
  \\ gvs [names_back]
  \\ qmatch_goalsub_abbrev_tac ‘FEMPTY |++ vars’
  \\ qspecl_then [‘t with vars := FEMPTY |++ vars’,‘Var (name "b")’,‘Var (name "c")’,
        ‘Var (name "d")’] mp_tac (Q.GEN ‘t’ Call_cons3)
  \\ gvs [FUPDATE_LIST,Abbr‘vars’,FLOOKUP_UPDATE,source_valuesTheory.name_def]
  \\ rpt $ disch_then drule
  \\ impl_tac >- (fs [builtin_def,source_valuesTheory.name_def])
  \\ disch_then $ qspec_then ‘name "ret"’ strip_assume_tac
  \\ simp [Once ADD1]
  \\ gvs [source_valuesTheory.name_def] \\ gvs [names_back]
  \\ gvs [GSYM PULL_FORALL]
  \\ qpat_x_assum ‘∀x. _’ kall_tac
  \\ qabbrev_tac ‘t2 = t with <|vars :=
       FEMPTY |+ (97,w) |+ (98,w') |+ (99,w'') |+ (100,w''') |+
        (name "ret",ptr); memory := t.memory ⧺ m1 |>’
  \\ qspecl_then [‘t2’,‘Var (name "a")’,‘Var (name "ret")’] mp_tac (Call_cons |> Q.GEN ‘t’)
  \\ gvs [source_valuesTheory.name_def,Abbr‘t2’,FLOOKUP_UPDATE]
  \\ disch_then drule
  \\ disch_then $ qspecl_then [‘x’,‘name "ret"’] mp_tac
  \\ impl_tac
  >-
   (irule_at Any v_rel_isPREFIX
    \\ first_x_assum $ irule_at Any
    \\ fs [builtin_def,source_valuesTheory.name_def])
  \\ strip_tac \\ gvs [source_valuesTheory.name_def]
  \\ fs [eval_cmd_def,bind_def,FLOOKUP_UPDATE,GSYM PULL_FORALL]
  \\ full_simp_tac std_ss [GSYM APPEND_ASSOC]
  \\ pop_assum $ irule_at Any \\ fs []
QED

Theorem Call_cons5:
  ∀e1 e2 e3 e4 e5 x y z q r w w' w'' w''' w'''' n.
    v_rel t.memory r w'''' ∧
    v_rel t.memory q w''' ∧
    v_rel t.memory z w'' ∧
    v_rel t.memory y w' ∧
    v_rel t.memory x w ∧
    (∀k. eval_exp e5 (t with clock := k) = (Cont w'''' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e4 (t with clock := k) = (Cont w''' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e3 (t with clock := k) = (Cont w'' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e2 (t with clock := k) = (Cont w' :(v,v)outcome,t with clock := k)) ∧
    (∀k. eval_exp e1 (t with clock := k) = (Cont w :(v,v)outcome,t with clock := k)) ∧
    EVERY (λ(n,ps,cs). find_fun n t.funs = SOME (ps,cs)) builtin ⇒
    ∃ck m1 ptr.
      ∀k c2.
          eval_cmd (Seq (Call n (name "cons5") [e1; e2; e3; e4; e5]) c2)
                   (t with clock := (SUC $ SUC $ SUC $ SUC $ SUC $ SUC $ SUC k) + t.clock) =
          eval_cmd c2
                   (t with <| vars := t.vars |+ (n,ptr) ;
                              memory := t.memory ++ m1 ;
                              clock := k + t.clock |>)  ∧
          v_rel (t.memory ++ m1) (Pair x (Pair y (Pair z (Pair q r)))) ptr
Proof
  rw [Once eval_cmd_def]
  \\ simp [eval_cmd_def,bind_def,tick_def]
  \\ fs [builtin_def,source_valuesTheory.name_def]
  \\ gvs [names_back]
  \\ qmatch_goalsub_abbrev_tac ‘FEMPTY |++ vars’
  \\ qspecl_then [‘t with vars := FEMPTY |++ vars’,‘Var (name "b")’,‘Var (name "c")’,
        ‘Var (name "d")’, ‘Var (name "e")’] mp_tac (Q.GEN ‘t’ Call_cons4)
  \\ gvs [FUPDATE_LIST,Abbr‘vars’,FLOOKUP_UPDATE,source_valuesTheory.name_def]
  \\ rpt $ disch_then drule
  \\ impl_tac >- (fs [builtin_def,source_valuesTheory.name_def])
  \\ disch_then $ qspec_then ‘name "ret"’ strip_assume_tac
  \\ simp [Once ADD1]
  \\ gvs [source_valuesTheory.name_def] \\ gvs [names_back]
  \\ gvs [GSYM PULL_FORALL]
  \\ qpat_x_assum ‘∀x. _’ kall_tac
  \\ qabbrev_tac ‘t2 = t with <|vars :=
       FEMPTY |+ (97,w) |+ (98,w') |+ (99,w'') |+ (100,w''') |+ (101,w'''') |+
        (name "ret",ptr); memory := t.memory ⧺ m1 |>’
  \\ qspecl_then [‘t2’,‘Var (name "a")’,‘Var (name "ret")’] mp_tac (Call_cons |> Q.GEN ‘t’)
  \\ gvs [source_valuesTheory.name_def,Abbr‘t2’,FLOOKUP_UPDATE]
  \\ disch_then drule
  \\ disch_then $ qspecl_then [‘x’,‘name "ret"’] mp_tac
  \\ impl_tac
  >-
   (irule_at Any v_rel_isPREFIX
    \\ first_x_assum $ irule_at Any
    \\ fs [builtin_def,source_valuesTheory.name_def])
  \\ strip_tac \\ gvs [source_valuesTheory.name_def]
  \\ fs [eval_cmd_def,bind_def,FLOOKUP_UPDATE,GSYM PULL_FORALL]
  \\ full_simp_tac std_ss [GSYM APPEND_ASSOC]
  \\ pop_assum $ irule_at Any \\ fs []
QED

Theorem Eval_2 =
  “(env,[e1; e2],s) ---> ([x; y],s1)” |> SIMP_CONV (srw_ss()) [Once Eval_cases];

Theorem Eval_Op_Cons =
  “(env,[Op Cons [e1; e2]],s) ---> ([x],s1)”
  |> (SIMP_CONV (srw_ss()) [Once Eval_cases] THENC
      SIMP_CONV (srw_ss()) [Once Eval_cases,PULL_EXISTS,
                            eval_op_def,fail_def,return_def,AllCaseEqs()]);

Theorem to_cmd_thm:
  ∀env es s rs s1.
    (env, es, s) ---> (rs,s1) ⇒
    ∀e cs t r.
      es = [e] ∧ rs = [r] ∧ to_cmd e = SOME cs ∧ state_rel s t ∧
      env_rel t.memory env t.vars ⇒
      ∃k r1 t1.
        eval_cmd cs (t with clock := t.clock + k) = (r1,t1) ∧
        res_rel t1.memory r r1 s1 t1 ∧ t.memory ≼ t1.memory
Proof
  ho_match_mp_tac (Eval_strongind |> SIMP_RULE std_ss [FORALL_PROD]
    |> Q.SPEC ‘λ(x1,x2,x3) (y1,y2). P x1 x2 x3 y1 y2’
    |> SIMP_RULE std_ss [FORALL_PROD] |> GEN_ALL)
  \\ rpt conj_tac \\ simp []
  >~ [‘Const’] >-
   (fs [to_cmd_def,to_exp_def,AllCaseEqs(),eval_cmd_def,cont_def,bind_def]
    \\ rw [] \\ fs [state_rel_def]
    \\ simp [Once v_rel_cases])
  >~ [‘Var’] >-
   (fs [to_cmd_def,to_exp_def,AllCaseEqs(),eval_cmd_def,cont_def,bind_def]
    \\ rw [] \\ gvs [env_rel_def] \\ res_tac \\ fs [state_rel_def])
  >~ [‘Call’] >-
   (rpt gen_tac \\ strip_tac
    \\ simp [Once to_cmd_def,to_exp_def,AllCaseEqs()]
    \\ rw [] \\ gvs []
    \\ drule_all to_exps_thm \\ strip_tac \\ gvs []
    \\ gvs [env_and_body_def,AllCaseEqs(),eval_cmd_def,PULL_EXISTS]
    \\ fs [state_rel_def,func_rel_def]
    \\ first_assum drule \\ strip_tac
    \\ imp_res_tac LIST_REL_LENGTH
    \\ Q.REFINE_EXISTS_TAC ‘SUC k’
    \\ simp [PULL_EXISTS,tick_def,ADD1]
    \\ last_x_assum drule
    \\ disch_then $ qspec_then ‘t with vars := FEMPTY |++ ZIP (params,ws)’ mp_tac
    \\ impl_tac >- (gvs [] \\ irule env_rel_make_env \\ fs [])
    \\ strip_tac \\ fs []
    \\ first_x_assum $ irule_at $ Pos hd
    \\ Cases_on ‘r1’ \\ gvs []
    \\ Cases_on ‘r’ \\ gvs []
    \\ gvs [bind_def,FLOOKUP_UPDATE,state_rel_def])
  >~ [‘Op’] >-
   (rpt gen_tac \\ disch_tac
    \\ simp [Once to_cmd_def,AllCaseEqs(),PULL_EXISTS,eval_cmd_def]
    \\ rw []
    \\ drule to_exp_thm
    \\ disch_then drule
    \\ simp [Once Eval_cases,PULL_EXISTS]
    \\ disch_then $ drule_at $ Pos last
    \\ disch_then $ drule_at $ Pos last
    \\ impl_tac >- (fs [])
    \\ strip_tac \\ fs [bind_def]
    \\ qexists_tac ‘t.clock’ \\ fs []
    \\ fs [state_rel_def])
  >~ [‘If’] >-
   (rpt gen_tac \\ disch_tac
    \\ simp [Once to_cmd_def,AllCaseEqs(),PULL_EXISTS,eval_cmd_def]
    \\ fs [to_exp_def,PULL_EXISTS,to_guard_def,AllCaseEqs()]
    \\ Cases_on ‘es’ \\ fs [to_exps_def,AllCaseEqs()]
    \\ Cases_on ‘t’ \\ fs [to_exps_def,AllCaseEqs()]
    \\ Cases_on ‘t'’ \\ fs [to_exps_def,AllCaseEqs()]
    \\ rw [] \\ rename [‘state_rel s t’]
    \\ last_x_assum mp_tac
    \\ simp [Once Eval_cases] \\ strip_tac \\ gvs []
    \\ simp [Once eval_cmd_def]
    \\ pop_assum mp_tac
    \\ drule_all to_exp_thm
    \\ pop_assum kall_tac
    \\ rw [] \\ fs []
    \\ drule Eval_length
    \\ fs [LENGTH_EQ_NUM_compute]
    \\ strip_tac \\ gvs []
    \\ drule_all to_exp_thm
    \\ rw [] \\ fs []
    \\ ‘to_cmd (if b then y else z) = SOME (if b then c1 else c2)’ by rw []
    \\ first_x_assum drule_all
    \\ strip_tac
    \\ qexists_tac ‘k’ \\ fs [bind_def]
    \\ qsuff_tac ‘eval_cmp (to_test test) w w' (t with clock := k + t.clock) =
          (Cont b : (v,bool)outcome ,t with clock := k + t.clock)’ >- fs []
    \\ gvs [take_branch_def,fail_def,AllCaseEqs(),return_def,to_test_def]
    \\ fs [Once v_rel_cases]
    \\ gvs [eval_cmp_def,to_test_def,return_def,wordsTheory.WORD_LO])
  \\ rename [‘Let’]
  \\ rpt gen_tac \\ strip_tac
  \\ simp [Once to_cmd_def,AllCaseEqs(),to_exp_def,PULL_EXISTS]
  \\ simp [to_assign_def,AllCaseEqs(),PULL_EXISTS]
  \\ rpt strip_tac \\ gvs []
  >~ [‘to_exp x = SOME i’] >-
   (drule_all to_exp_thm \\ strip_tac \\ gvs []
    \\ fs [eval_cmd_def,bind_def]
    \\ first_x_assum $ qspec_then ‘t with vars := t.vars |+ (n,w)’ mp_tac
    \\ impl_tac
    >- (fs [state_rel_def] \\ irule_at Any env_rel_update \\ fs [])
    \\ rw [] \\ fs [])
  >~ [‘(env,[Call cn es],s)’] >-
   (simp [Once eval_cmd_def]
    \\ last_x_assum $ drule_at $ Pos last
    \\ simp [to_cmd_def]
    \\ strip_tac
    \\ rename [‘state_rel s1 t1’]
    \\ rename [‘res_rel _ _ res’]
    \\ Cases_on ‘res’ \\ fs []
    \\ reverse $ Cases_on ‘r’ \\ fs []
    >- (qexists_tac ‘k’ \\ fs []
        \\ gvs [eval_cmd_def,AllCaseEqs(),bind_def])
    \\ rename [‘state_rel s2 t2’]
    \\ drule_all env_rel_isPREFIX
    \\ strip_tac
    \\ drule_all env_rel_update
    \\ disch_then $ qspec_then ‘n’ assume_tac
    \\ last_x_assum $ qspec_then ‘t2 with vars := t1.vars |+ (n,a)’ mp_tac
    \\ impl_tac >- fs [state_rel_def]
    \\ strip_tac \\ fs []
    \\ qpat_x_assum ‘_ = (Stop (Return a),t2)’ mp_tac
    \\ simp [Once eval_cmd_def]
    \\ last_x_assum mp_tac
    \\ simp [Once Eval_cases] \\ strip_tac
    \\ drule_all to_exps_thm \\ strip_tac \\ gvs []
    \\ Cases_on ‘eval_cmd (Call (name "ret") cn xs) (t1 with clock := k + t1.clock)’
    \\ reverse $ Cases_on ‘q’
    >-
     (fs [] \\ strip_tac \\ gvs []
      \\ qexists_tac ‘k’ \\ fs [eval_cmd_def]
      \\ gvs [AllCaseEqs(),tick_def])
    \\ gvs []
    \\ drule eval_cmd_add_clock \\ simp []
    \\ pop_assum kall_tac
    \\ disch_then $ qspec_then ‘k'’ assume_tac \\ rw []
    \\ irule_at Any rich_listTheory.IS_PREFIX_TRANS
    \\ first_x_assum $ irule_at $ Pos $ el 2
    \\ first_x_assum $ irule_at Any
    \\ first_x_assum $ irule_at Any
    \\ qexists_tac ‘k+k'’ \\ fs []
    \\ pop_assum mp_tac
    \\ pop_assum mp_tac
    \\ fs [eval_cmd_def,CaseEq"prod",bind_def]
    \\ rpt strip_tac
    \\ gvs [AllCaseEqs(),bind_def]
    \\ irule EQ_TRANS
    \\ first_x_assum $ irule_at Any
    \\ AP_TERM_TAC
    \\ fs [tick_def,AllCaseEqs()]
    \\ gvs [imp_source_semanticsTheory.state_component_equality]
    \\ qpat_x_assum ‘_ |+ _ = _’ (assume_tac o GSYM)
    \\ gvs [FLOOKUP_UPDATE])
  \\ ‘EVERY (λ(n,ps,cs). find_fun n t.funs = SOME (ps,cs)) builtin’ by
        fs [state_rel_def,func_rel_def]
  >~ [‘Op Add es1’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ drule_all to_exps_thm
    \\ strip_tac \\ rw []
    \\ simp [Once eval_cmd_def]
    \\ simp [Once eval_cmd_def]
    \\ gvs [builtin_def]
    \\ Q.REFINE_EXISTS_TAC ‘k+1’
    \\ simp [source_valuesTheory.name_def,tick_def]
    \\ gvs [v_rel_Num]
    \\ gvs [eval_cmd_def,bind_def,FLOOKUP_UPDATE,FUPDATE_LIST]
    \\ IF_CASES_TAC \\ gvs [eval_cmd_def,bind_def,FLOOKUP_UPDATE]
    \\ IF_CASES_TAC \\ gvs [eval_cmd_def,bind_def,FLOOKUP_UPDATE]
    \\ gvs [wordsTheory.word_add_n2w,wordsTheory.WORD_LO]
    \\ Cases_on ‘n1 + n2 < 2**64’ \\ gvs []
    >-
     (first_x_assum $ qspec_then ‘t with vars := dd’ (assume_tac o Q.GEN ‘dd’)
      \\ gvs [] \\ pop_assum irule
      \\ fs [state_rel_def] \\ irule env_rel_update \\ fs [v_rel_Num])
    \\ qsuff_tac ‘F’ >- fs []
    \\ rpt $ qpat_x_assum ‘~(_ MOD _ < _)’ mp_tac \\ fs [NOT_LESS]
    \\ ‘0 < 18446744073709551616:num’ by fs []
    \\ drule_all $ GSYM SUB_MOD
    \\ disch_then $ once_rewrite_tac o single
    \\ ‘n1 + n2 − 18446744073709551616 < 18446744073709551616’ by fs []
    \\ fs [])
  >~ [‘Op Sub es1’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ drule_all to_exps_thm
    \\ strip_tac \\ rw []
    \\ simp [Once eval_cmd_def]
    \\ simp [Once eval_cmd_def]
    \\ gvs [builtin_def]
    \\ Q.REFINE_EXISTS_TAC ‘k+1’
    \\ simp [source_valuesTheory.name_def,tick_def]
    \\ gvs [v_rel_Num]
    \\ gvs [eval_cmd_def,bind_def,FLOOKUP_UPDATE,FUPDATE_LIST,wordsTheory.WORD_LO]
    \\ rename [‘if n1 < n2 then _ else _’] \\ IF_CASES_TAC
    \\ gvs [eval_cmd_def,bind_def,FLOOKUP_UPDATE]
    \\ first_x_assum $ qspec_then ‘t with vars := dd’ (assume_tac o Q.GEN ‘dd’)
    \\ gvs [] \\ pop_assum irule
    \\ fs [state_rel_def] \\ irule env_rel_update \\ fs [v_rel_Num,NOT_LESS]
    \\ fs [wordsTheory.n2w_sub])
  >~ [‘Op Div es1’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ imp_res_tac Eval_length \\ gvs [LENGTH_EQ_NUM_compute]
    \\ gvs [to_exps_def,AllCaseEqs()]
    \\ drule Eval_cons \\ simp [] \\ strip_tac
    \\ drule_all to_exp_thm \\ strip_tac \\ gvs []
    \\ drule_all to_exp_thm \\ strip_tac \\ gvs [v_rel_Num]
    \\ simp [Once eval_cmd_def]
    \\ simp [Once eval_cmd_def,bind_def]
    \\ first_x_assum $ qspec_then ‘t with vars := dd’ (assume_tac o Q.GEN ‘dd’)
    \\ gvs [] \\ pop_assum irule
    \\ fs [state_rel_def] \\ irule env_rel_update \\ fs [v_rel_Num,NOT_LESS]
    \\ gvs [wordsTheory.word_div_def,DIV_LT_X])
  >~ [‘Op Read es1’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ imp_res_tac Eval_length \\ gvs [LENGTH_EQ_NUM_compute]
    \\ pop_assum mp_tac \\ simp [Once Eval_cases] \\ strip_tac \\ gvs []
    \\ simp [Once eval_cmd_def]
    \\ simp [Once eval_cmd_def,bind_def,get_char_def]
    \\ first_x_assum $ qspec_then ‘t with <| vars := dd; input := ii |>’
         (assume_tac o Q.GENL [‘dd’,‘ii’])
    \\ gvs [] \\ pop_assum irule
    \\ fs [state_rel_def,source_semanticsTheory.next_def,
           imp_source_semanticsTheory.next_def]
    \\ irule env_rel_update \\ fs [v_rel_Num,NOT_LESS]
    \\ CASE_TAC \\ fs [v_rel_Num]
    \\ irule LESS_TRANS
    \\ irule_at Any ORD_BOUND \\ fs [])
  >~ [‘Op Write es1’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ imp_res_tac Eval_length \\ gvs [LENGTH_EQ_NUM_compute]
    \\ fs [eval_cmd_def,bind_def,to_exps_def,AllCaseEqs()]
    \\ drule_all to_exp_thm \\ strip_tac \\ gvs []
    \\ fs [imp_source_semanticsTheory.put_char_def,v_rel_Num]
    \\ simp [Once eval_cmd_def]
    \\ simp [Once eval_cmd_def,bind_def]
    \\ first_x_assum $ qspec_then ‘t with <| vars := dd; output := ii |>’
         (assume_tac o Q.GENL [‘dd’,‘ii’])
    \\ gvs [] \\ pop_assum irule
    \\ fs [state_rel_def]
    \\ irule env_rel_update \\ fs [v_rel_Num,NOT_LESS])
  \\ rename [‘to_cons n x = SOME c1’]
  \\ gvs [to_cons_def,AllCaseEqs(),dest_Cons_SOME]
  >~ [‘Call n (name "cons") [e1; e2]’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ drule Eval_cons \\ fs [] \\ strip_tac
    \\ drule_all to_exp_thm \\ strip_tac \\ gvs []
    \\ drule_all to_exp_thm \\ strip_tac \\ gvs []
    \\ dxrule Call_cons
    \\ disch_then dxrule
    \\ disch_then drule_all
    \\ disch_then $ qspecl_then [‘n’] strip_assume_tac
    \\ Q.REFINE_EXISTS_TAC ‘SUC k’ \\ fs []
    \\ first_x_assum $ qspec_then ‘t with <| vars := t.vars |+ (n,ptr);
                                             memory := t.memory ⧺ m1 |>’ mp_tac
    \\ impl_tac
    >-
     (fs [state_rel_def,GSYM PULL_FORALL]
      \\ irule env_rel_update \\ fs []
      \\ drule_then irule env_rel_isPREFIX \\ fs [])
    \\ strip_tac \\ qexists_tac ‘k’ \\ fs []
    \\ irule rich_listTheory.IS_PREFIX_TRANS
    \\ pop_assum $ irule_at Any \\ fs [])
  >~ [‘Call n (name "cons3") [e1; e2; e3]’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ gvs [Eval_2,Eval_Op_Cons]
    \\ ntac 3 (drule_all to_exp_thm \\ strip_tac \\ gvs [])
    \\ qspecl_then [‘e1’,‘e2’,‘e3’] mp_tac Call_cons3 \\ fs []
    \\ disch_then drule_all \\ strip_tac
    \\ Q.REFINE_EXISTS_TAC ‘k+3’ \\ fs []
    \\ pop_assum $ qspec_then ‘n’ strip_assume_tac
    \\ first_x_assum $ qspec_then ‘t with <| vars := t.vars |+ (n,ptr);
                                             memory := t.memory ⧺ m1 |>’ mp_tac
    \\ impl_tac
    >-
     (fs [state_rel_def,GSYM PULL_FORALL]
      \\ irule env_rel_update \\ fs []
      \\ drule_then irule env_rel_isPREFIX \\ fs [])
    \\ strip_tac \\ qexists_tac ‘k’ \\ fs [ADD1]
    \\ irule rich_listTheory.IS_PREFIX_TRANS
    \\ pop_assum $ irule_at Any \\ fs [])
  >~ [‘Call n (name "cons4") [e1; e2; e3; e4]’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ gvs [Eval_2,Eval_Op_Cons]
    \\ ntac 4 (drule_all to_exp_thm \\ strip_tac \\ gvs [])
    \\ qspecl_then [‘e1’,‘e2’,‘e3’,‘e4’] mp_tac Call_cons4 \\ fs []
    \\ disch_then drule_all \\ strip_tac
    \\ Q.REFINE_EXISTS_TAC ‘k+5’ \\ fs []
    \\ pop_assum $ qspec_then ‘n’ strip_assume_tac
    \\ first_x_assum $ qspec_then ‘t with <| vars := t.vars |+ (n,ptr);
                                             memory := t.memory ⧺ m1 |>’ mp_tac
    \\ impl_tac
    >-
     (fs [state_rel_def,GSYM PULL_FORALL]
      \\ irule env_rel_update \\ fs []
      \\ drule_then irule env_rel_isPREFIX \\ fs [])
    \\ strip_tac \\ qexists_tac ‘k’ \\ fs [ADD1]
    \\ irule rich_listTheory.IS_PREFIX_TRANS
    \\ pop_assum $ irule_at Any \\ fs [])
  >~ [‘Call n (name "cons5") [e1; e2; e3; e4; e5]’] >-
   (last_x_assum mp_tac
    \\ simp [Once Eval_cases,eval_op_def,AllCaseEqs(),fail_def,return_def]
    \\ strip_tac \\ gvs []
    \\ gvs [Eval_2,Eval_Op_Cons]
    \\ ntac 5 (drule_all to_exp_thm \\ strip_tac \\ gvs [])
    \\ qspecl_then [‘e1’,‘e2’,‘e3’,‘e4’,‘e5’] mp_tac Call_cons5 \\ fs []
    \\ disch_then drule_all \\ strip_tac
    \\ Q.REFINE_EXISTS_TAC ‘k+7’ \\ fs []
    \\ pop_assum $ qspec_then ‘n’ strip_assume_tac
    \\ first_x_assum $ qspec_then ‘t with <| vars := t.vars |+ (n,ptr);
                                             memory := t.memory ⧺ m1 |>’ mp_tac
    \\ impl_tac
    >-
     (fs [state_rel_def,GSYM PULL_FORALL]
      \\ irule env_rel_update \\ fs []
      \\ drule_then irule env_rel_isPREFIX \\ fs [])
    \\ strip_tac \\ qexists_tac ‘k’ \\ fs [ADD1]
    \\ irule rich_listTheory.IS_PREFIX_TRANS
    \\ pop_assum $ irule_at Any \\ fs [])
  \\ fs []
QED

Theorem to_funs_names:
  ∀l xs funs.
    EVERY (λx. ¬MEM (func_name x) (MAP get_name xs)) (l:dec list) ∧
    to_funs l = SOME funs ⇒
    ∀fname params body.
      lookup_fun fname l = SOME (params,body) ⇒
      ∃cs.
        find_fun fname (xs ++ funs) = SOME (params,cs) ∧
        to_cmd body = SOME cs ∧ ALL_DISTINCT params
Proof
  Induct \\ fs [to_funs_def,lookup_fun_def]
  \\ Cases \\ gvs [to_funs_def,AllCaseEqs(),lookup_fun_def] \\ rw []
  >- (Induct_on ‘xs’ \\ fs [find_fun_def]
      \\ fs [] \\ Cases \\ rw [find_fun_def] \\ gvs [EVERY_MEM])
  \\ qsuff_tac ‘find_fun fname (xs ⧺ Func n l' cmd::funs') = find_fun fname (xs ⧺ funs')’
  >- (disch_then $ rewrite_tac o single \\ last_x_assum irule \\ fs [])
  \\ qid_spec_tac ‘xs’ \\ Induct \\ fs [find_fun_def]
  \\ Cases \\ fs [find_fun_def]
QED

Theorem to_imp_thm:
  (input, prog) prog_terminates output ∧ to_imp prog = SOME imp_prog ⇒
  (input, imp_prog) imp_weak_termination output
Proof
  Cases_on ‘prog’ \\ rw [prog_terminates_def,imp_weak_termination_def]
  \\ imp_res_tac Eval_length \\ gvs [LENGTH_EQ_NUM_compute]
  \\ drule to_cmd_thm \\ fs [env_rel_def,empty_env_def,eval_from_def]
  \\ gvs [to_imp_def,AllCaseEqs(),eval_from_def,to_funs_def]
  \\ disch_then $ qspec_then ‘init_state input
               (MAP (λ(n,vs,b). Func n vs b) builtin ++
                 Func (name "main") [] cmd::funs) 0’ mp_tac
  \\ impl_tac >-
   (fs [state_rel_def,imp_source_semanticsTheory.init_state_def,
        source_semanticsTheory.init_state_def,o_DEF,func_rel_def]
    \\ conj_tac >- EVAL_TAC
    \\ rewrite_tac [GSYM $ SIMP_CONV std_ss [APPEND] “xs ++ ([y] ++ ys)”]
    \\ rewrite_tac [APPEND_ASSOC]
    \\ match_mp_tac to_funs_names \\ fs [] \\ fs [builtin_def]
    \\ gvs [EVERY_MEM] \\ rw [] \\ res_tac \\ fs [])
  \\ strip_tac
  \\ gvs [EVAL “(init_state _ _ _).clock”]
  \\ qexists_tac ‘k+1’ \\ fs []
  \\ gvs [eval_cmd_def,find_fun_def,init_state_def,tick_def,FUPDATE_LIST]
  \\ ‘∀funs. find_fun (name "main") (MAP (λ(n,vs,b). Func n vs b) builtin ⧺ funs) =
             find_fun (name "main") funs’ by
    simp [builtin_def,find_fun_def,source_valuesTheory.name_def]
  \\ gvs [eval_cmd_def,find_fun_def,init_state_def,tick_def,FUPDATE_LIST]
  \\ Cases_on ‘r1’ \\ gvs [res_rel_def]
  \\ Cases_on ‘r’ \\ gvs [res_rel_def,state_rel_def]
QED
