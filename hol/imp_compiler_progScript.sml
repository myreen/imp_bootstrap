Theory imp_compiler_prog
Ancestors
  arithmetic list pair finite_map string
  source_values source_syntax source_semantics
  source_properties parsing codegen x64asm_syntax
  words automation_lemmas printing parsing
  imp_automation_lemmas
  imp_compiler imp_to_asm imp_parsing
Libs
  mp_then wordsLib imp_automationLib

val _ = temp_delsimps ["LT1_EQ0"];

val _ = show_assums := true;

(* codegen *)

val res = to_deep APPEND;
val res = to_deep codegenTheory.flatten_def;
val res = to_deep (init_def |> SIMP_RULE std_ss []);
val res = to_deep imp_to_asmTheory.lookup_def;
val res = to_deep (LENGTH |> REWRITE_RULE [ADD1]);
val res = to_deep imp_to_asmTheory.app_list_length_def;
val res = to_deep imp_to_asmTheory.make_vs_from_binders_def;
val res = to_deep imp_to_asmTheory.fltr_nms_def;
val res = to_deep imp_to_asmTheory.rm_nms_def;
val res = to_deep imp_to_asmTheory.call_v_stack_def;
val res = to_deep imp_to_asmTheory.push_vs_def;
val res = to_deep names_contain_def;
val res = to_deep imp_to_asmTheory.add_name_def;
val res = to_deep names_unique_def;
val res = to_deep all_binders_def;
val res = to_deep unique_binders_def;
val res = to_deep imp_source_syntaxTheory.get_name_def;
val res = to_deep imp_to_asmTheory.even_len_def;
val res = to_deep imp_to_asmTheory.vs_bdrs_def;
val res = to_deep imp_to_asmTheory.c_bdrs_def;
val res = to_deep imp_to_asmTheory.c_pushes_def;
val res = to_deep imp_to_asmTheory.c_read_def;
val res = to_deep imp_to_asmTheory.c_write_def;
val res = to_deep imp_to_asmTheory.index_of_def;

Theorem num_case_rw[local]:
  num_CASE x f g = if x = 0 then f else g (x - 1)
Proof
  Cases_on ‘x’ \\ fs []
QED

val res = to_deep (imp_to_asmTheory.c_assign_def |> SIMP_RULE std_ss [num_case_rw]);
val res = to_deep imp_to_asmTheory.c_alloc_def;
val res = to_deep imp_to_asmTheory.make_ret_def;
val res = to_deep imp_to_asmTheory.give_up_def;
val res = to_deep imp_to_asmTheory.c_pops_def;
val res = to_deep imp_to_asmTheory.c_call_def;
val res = to_deep imp_to_asmTheory.dest_tail_call_def;
val res = to_deep imp_to_asmTheory.c_tail_call_def;
val res = to_deep imp_to_asmTheory.c_cmp_def;
val res = to_deep imp_to_asmTheory.c_store_def;
val res = to_deep imp_to_asmTheory.c_var_def;
val res = to_deep imp_to_asmTheory.c_const_def;
val res = to_deep imp_to_asmTheory.c_add_def;
val res = to_deep imp_to_asmTheory.c_sub_def;
val res = to_deep imp_to_asmTheory.c_div_def;
val res = to_deep imp_to_asmTheory.c_load_def;

Theorem pairlet_imp:
  ((let (a,b) = f in x a b) = let temp = f in case temp of (a,b) => x a b) ∧
  ((let (a,b,c) = g in y a b c) = let temp = g in case temp of (a,b,c) => y a b c)
Proof
  Cases_on ‘f’ \\ simp []
  \\ PairCases_on ‘g’ \\ simp []
QED

val res = to_deep (imp_to_asmTheory.c_exp_def |> SIMP_RULE std_ss [pairlet_imp]);
val res = to_deep (imp_to_asmTheory.c_test_jump_def |> SIMP_RULE std_ss [pairlet_imp]);
val res = to_deep (imp_to_asmTheory.c_exps_def |> SIMP_RULE std_ss [pairlet_imp]);
val res = to_deep (imp_to_asmTheory.c_cmd_def |> SIMP_RULE std_ss [pairlet_imp]);
val res = to_deep (imp_to_asmTheory.c_fundef_def |> SIMP_RULE std_ss [pairlet_imp]);

Definition mul256_def:
  mul256 n =
    let n = n + n in
    let n = n + n in
    let n = n + n in
    let n = n + n in
    let n = n + n in
    let n = n + n in
    let n = n + n in
            n + n : num
End

val res = to_deep mul256_def;

Theorem mul256_thm[simp]:
  mul256_side n ∧
  mul256 n = 256 * n
Proof
  fs [mul256_def,res]
QED

Definition name2str_def:
  name2str n =
    if n = 0 then "" else
      let n_div = n DIV 256 in
      let n_mul = mul256 n_div in
      let k = n - n_mul in
        if k < 42 then "" else
        if 122 < k then "" else
        if k = 46 then "" else
        if n < 256 then STRING (CHR k) "" else
          STRCAT (name2str n_div) (STRING (CHR k) "")
End

val res = to_deep name2str_def;

Theorem N2ascii_eq_name2str:
  ∀n. N2ascii n = name2str n
Proof
  ho_match_mp_tac name2str_ind \\ rw []
  \\ once_rewrite_tac [name2str_def, N2ascii_def]
  \\ IF_CASES_TAC >- gvs []
  \\ simp_tac bool_ss [LET_THM]
  \\ ‘n − mul256 (n DIV 256) = n MOD 256’ by
   (‘0 < 256:num’ by simp []
    \\ drule DIVISION
    \\ disch_then $ qspec_then ‘n’ mp_tac
    \\ strip_tac
    \\ simp [])
  \\ asm_rewrite_tac [] \\ fs []
  \\ IF_CASES_TAC \\ simp []
  \\ IF_CASES_TAC \\ simp []
QED

val res = to_deep (imp_to_asmTheory.c_fundefs_def
                     |> SIMP_RULE std_ss [pairlet_imp,N2ascii_eq_name2str]);
val res = to_deep imp_source_syntaxTheory.get_funcs_def;
val res = to_deep (imp_to_asmTheory.codegen_def
                     |> SIMP_RULE (srw_ss()) [pairlet_imp, name_def]);

(* parser *)

val h_code_def = define_code ‘
  (defun h (x) (if (= (head x) '1) x (head (tail x))))’

val t_code_def = define_code ‘
  (defun t (x) (if (= (head x) '1) x (tail (tail x))))’

val res = to_deep source_valuesTheory.el1_def;
val res = to_deep source_valuesTheory.el2_def;
val res = to_deep source_valuesTheory.el3_def;
val res = to_deep imp_parsingTheory.get_num_def;
val res = to_deep imp_parsingTheory.v2list_def;
val res = to_deep imp_parsingTheory.vs2args_def;
val res = to_deep is_upper_def;
val res = to_deep imp_parsingTheory.num2exp_def;

Theorem num2exp_side[local]:
  num2exp_side n
Proof
  simp [res]
QED

val _ = update_mem num2exp_side;

val res = to_deep (imp_parsingTheory.v2exp_def |> SRULE [name_def]);
val res = to_deep (imp_parsingTheory.v2cmp_def |> SRULE [name_def]);
val res = to_deep (imp_parsingTheory.v2test_def |> SRULE [name_def]);
val res = to_deep imp_parsingTheory.vs2exps_def;
val res = to_deep (imp_parsingTheory.v2cmd_def |> SRULE [name_def]);
val res = to_deep imp_parsingTheory.v2func_def;
val res = to_deep imp_parsingTheory.v2funcs_def;
val res = to_deep imp_parsingTheory.vs2prog_def;
val res = to_deep (quote_def |> SIMP_RULE (srw_ss()) [name_def]);
val res = to_deep (parse_def |> DefnBase.one_line_ify NONE |> Q.INST [‘v’|->‘input’]);
val res = to_deep imp_parsingTheory.parser_def;

(* lexer *)

Definition mul10_def:
  mul10 n =
    let n2 = n + n in
    let n4 = n2 + n2 in
    let n5 = n4 + n in
      n5 + n5 : num
End

val res = to_deep mul10_def;

Theorem mul10_thm[simp]:
  mul10_side n ∧
  mul10 n = 10 * n
Proof
  fs [mul10_def,res]
QED

val read_num_code_def = define_code ‘
  (defun read_num (acc next)
     (if (< next '58)
       (if (< next '48)
         (let (res (cons acc next)) res)
         (let (acc1 (mul10 acc))
           (let (dig (- next '48))
             (let (acc2 (+ acc1 dig))
               (let (next1 (read))
                 (read_num acc2 next1))))))
       (let (res (cons acc next)) res)))’

val read_str_code_def = define_code ‘
  (defun read_str (acc next)
     (if (< next '123)
       (if (< next '42)
         (let (res (cons acc next)) res)
         (let (acc1 (mul256 acc))
           (let (acc2 (+ acc1 next))
             (let (next1 (read))
               (read_str acc2 next1)))))
       (let (res (cons acc next)) res)))’

val read_any_code_def = define_code ‘
  (defun read_any (next)
     (if (< next '58)
       (if (< next '48)
         (read_str '0 next)
         (read_num '0 next))
       (read_str '0 next)))’

Theorem read_num_thm:
  ∀input s acc k rest.
    read_num #"0" #"9" 10 (ORD #"0") acc input = (k, rest) ∧
    lookup_fun (name "mul10") s.funs = SOME ([name "n"],mul10_code) ∧
    lookup_fun (name "read_num") s.funs = SOME ([name "acc"; name "next"],read_num_code) ∧
    s.input = fromList (TL input) ⇒
    app (name "read_num") [Num acc; next (fromList input)] s
      (Pair (Num k) (next (fromList rest)), s with input := fromList (TL rest))
Proof
  gen_tac \\ completeInduct_on ‘LENGTH input’
  \\ rw [] \\ fs [PULL_FORALL]
  \\ match_mp_tac (trans_app |> SIMP_RULE std_ss [LET_THM] |> MP_CANON |> GEN_ALL)
  \\ fs [make_env_def]
  \\ simp [read_num_code_def]
  \\ simp [Eval_eq,PULL_EXISTS]
  \\ fs [combinTheory.APPLY_UPDATE_THM,name_def]
  \\ Cases_on ‘input’ \\ fs [next_def]
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  \\ rpt BasicProvers.VAR_EQ_TAC
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1 fs [state_component_equality]
  \\ reverse IF_CASES_TAC
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1 (rw [] \\ fs [state_component_equality,next_def])
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  \\ IF_CASES_TAC
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1 (rw [] \\ fs [state_component_equality,next_def])
  \\ (theorem "mul10_app" |> DISCH_ALL |> Q.INST [‘n’|->‘acc’]
         |> SIMP_RULE (srw_ss()) [] |> mp_tac)
  \\ fs [name_def,llistTheory.LFINITE_fromList]
  \\ strip_tac \\ goal_assum (first_assum o mp_then Any mp_tac)
  \\ fs [] \\ Cases_on ‘t’ \\ fs [AND_IMP_INTRO]
  \\ first_x_assum (first_assum o mp_then (Pos (el 2)) mp_tac)
  \\ fs []
  THEN1 (disch_then (qspec_then ‘s with input := fromList ""’ mp_tac) \\ fs [])
  \\ disch_then (qspec_then ‘s with input := fromList t'’ mp_tac) \\ fs []
QED

Theorem read_str_thm:
  ∀input s acc k rest.
    read_num #"*" #"z" 256 0 acc input = (k, rest) ∧
    lookup_fun (name "mul256") s.funs = SOME ([name "n"],mul256_code) ∧
    lookup_fun (name "read_str") s.funs = SOME ([name "acc"; name "next"],read_str_code) ∧
    s.input = fromList (TL input) ⇒
    app (name "read_str") [Num acc; next (fromList input)] s
      (Pair (Num k) (next (fromList rest)), s with input := fromList (TL rest))
Proof
  gen_tac \\ completeInduct_on ‘LENGTH input’
  \\ rw [] \\ fs [PULL_FORALL]
  \\ match_mp_tac (trans_app |> SIMP_RULE std_ss [LET_THM] |> MP_CANON |> GEN_ALL)
  \\ fs [make_env_def]
  \\ simp [read_str_code_def]
  \\ simp [Eval_eq,PULL_EXISTS]
  \\ fs [combinTheory.APPLY_UPDATE_THM,name_def]
  \\ Cases_on ‘input’ \\ fs [next_def]
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  \\ rpt BasicProvers.VAR_EQ_TAC
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1 fs [state_component_equality]
  \\ reverse IF_CASES_TAC
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1 (rw [] \\ fs [state_component_equality,next_def])
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  \\ IF_CASES_TAC
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1 (rw [] \\ fs [state_component_equality,next_def])
  \\ (theorem "mul256_app" |> DISCH_ALL |> Q.INST [‘n’|->‘acc’]
         |> SIMP_RULE (srw_ss()) [] |> mp_tac)
  \\ fs [name_def,llistTheory.LFINITE_fromList]
  \\ strip_tac \\ goal_assum (first_assum o mp_then Any mp_tac)
  \\ fs [] \\ Cases_on ‘t’ \\ fs [AND_IMP_INTRO]
  \\ first_x_assum (first_assum o mp_then (Pos (el 2)) mp_tac)
  \\ fs []
  THEN1 (disch_then (qspec_then ‘s with input := fromList ""’ mp_tac) \\ fs [])
  \\ disch_then (qspec_then ‘s with input := fromList t'’ mp_tac) \\ fs []
QED

val end_line_code_def = define_code ‘
  (defun end_line (next)
     (if (< next '256)
       (if (= next '10)
         (let (next1 (read)) next1)
         (let (next1 (read)) (end_line next1)))
       next))’

Theorem end_line_thm:
  ∀input s.
    lookup_fun (name "end_line") s.funs = SOME ([name "next"],end_line_code) ∧
    s.input = fromList (TL input) ⇒
    app (name "end_line") [next (fromList input)] s
      (next (fromList (end_line input)), s with input := fromList (TL (end_line input)))
Proof
  simp [] \\ gen_tac \\ completeInduct_on ‘LENGTH input’
  \\ rpt strip_tac \\ fs [PULL_FORALL]
  \\ match_mp_tac (trans_app |> SIMP_RULE std_ss [LET_THM] |> MP_CANON |> GEN_ALL)
  \\ fs [make_env_def]
  \\ simp [end_line_code_def]
  \\ simp [Eval_eq,PULL_EXISTS]
  \\ fs [combinTheory.APPLY_UPDATE_THM,name_def]
  \\ Cases_on ‘input’ \\ fs [next_def]
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1 fs [state_component_equality,lex_def,end_line_def,next_def]
  \\ fs [ORD_BOUND]
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  \\ fs [end_line_def]
  \\ Cases_on ‘h’ \\ fs []
  \\ IF_CASES_TAC \\ fs []
  \\ simp [Eval_eq,PULL_EXISTS]
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  \\ fs [AND_IMP_INTRO,state_component_equality]
  THEN1 (Cases_on ‘t’ \\ fs [])
  \\ first_x_assum (qspecl_then [‘t’,‘s with input := fromList (TL t)’] mp_tac) \\ fs []
  \\ Cases_on ‘t’ \\ fs []
QED

val lex_code_def = define_code ‘
  (defun lex (q next acc)
     (if (< next '* )
       (let (n (read))
         (if (= next '40)
           (let (tk (OPEN)) (let (acc1 (cons tk acc)) (lex '0 n acc1)))
           (if (= next '41)
             (let (tk (CLOSE)) (let (acc1 (cons tk acc)) (lex '0 n acc1)))
             (if (= next '39) (lex '1 n acc)
               (if (= next '35)
                 (let (m (end_line n)) (lex '0 m acc))
                 (lex '0 n acc))))))
       (if (= next '46)
         (let (n (read))
           (let (tk (DOT)) (let (acc1 (cons tk acc)) (lex '0 n acc1))))
         (if (< 'z next)
           (if (< next '256)
             (let (n (read)) (lex '0 n acc)) acc)
             (let (r (read_any next))
               (let (h (head r))
                 (let (u (tail r))
                   (if (= q '0)
                     (let (tk (NUM h)) (let (acc1 (cons tk acc)) (lex '0 u acc1)))
                     (let (tk (QUOTE h)) (let (acc1 (cons tk acc)) (lex '0 u acc1)))))))))))’

val lexer_code_def = define_code ‘
  (defun lexer ()
     (let (next1 (read)) (lex '0 next1 '0)))’

Theorem LTL_fromList_lemma[local,simp]:
  (case LTL (fromList t) of NONE => fromList t | SOME t => t) = fromList (TL t)
Proof
  Cases_on ‘t’ \\ fs []
QED

Theorem lex_thm:
  ∀input s acc k toks.
    lookup_fun (name "mul10") s.funs = SOME ([name "n"],mul10_code) ∧
    lookup_fun (name "mul256") s.funs = SOME ([name "n"],mul256_code) ∧
    lookup_fun (name "end_line") s.funs = SOME ([name "next"],end_line_code) ∧
    lookup_fun (name "read_num") s.funs = SOME ([name "acc"; name "next"],read_num_code) ∧
    lookup_fun (name "read_str") s.funs = SOME ([name "acc"; name "next"],read_str_code) ∧
    lookup_fun (name "read_any") s.funs = SOME ([name "next"],read_any_code) ∧
    lookup_fun (name "lex") s.funs = SOME ([name "q"; name "next"; name "acc"],lex_code) ∧
    s.input = fromList (TL input) ∧
    lex (if k = 0 then NUM else QUOTE) input acc = toks ⇒
    app (name "lex") [Num k; next (fromList input); list token acc] s
      (list token toks, s with input := fromList [])
Proof
  simp [] \\ gen_tac \\ completeInduct_on ‘LENGTH input’
  \\ rw [] \\ fs [PULL_FORALL]
  \\ match_mp_tac (trans_app |> SIMP_RULE std_ss [LET_THM] |> MP_CANON |> GEN_ALL)
  \\ fs [make_env_def]
  \\ simp_tac std_ss [Once lex_code_def]
  \\ simp_tac (srw_ss()) [Once Eval_eq,PULL_EXISTS]
  \\ fs [combinTheory.APPLY_UPDATE_THM,name_def]
  \\ Cases_on ‘input’ \\ fs [next_def]
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1 fs [state_component_equality,lex_def]
  \\ IF_CASES_TAC
  \\ rpt BasicProvers.var_eq_tac
  \\ fs [take_branch_def,return_def,Eval_eq,PULL_EXISTS,next_def,
         combinTheory.APPLY_UPDATE_THM,eval_op_def,read_num_def]
  THEN1
   (IF_CASES_TAC
    \\ fs [Eval_eq,PULL_EXISTS,combinTheory.APPLY_UPDATE_THM,eval_op_def,return_def]
    THEN1
     (Cases_on ‘h’ \\ fs [lex_def] \\ rw [] \\ fs [AND_IMP_INTRO]
      \\ first_x_assum (qspecl_then [‘t’,
           ‘s with input := fromList (TL t)’,‘OPEN::acc’,‘0’] mp_tac)
      \\ fs [name_def])
    \\ fs [Eval_eq,eval_op_def,return_def, take_branch_def]
    \\ IF_CASES_TAC
    THEN1
     (Cases_on ‘h’ \\ fs [lex_def] \\ rw []
      \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
             eval_op_def,return_def]
      \\ first_x_assum (qspecl_then [‘t’,
           ‘s with input := fromList (TL t)’,‘CLOSE::acc’,‘0’] mp_tac)
      \\ fs [name_def])
    \\ fs [Eval_eq,eval_op_def,return_def, take_branch_def,PULL_EXISTS,
           combinTheory.APPLY_UPDATE_THM]
    \\ IF_CASES_TAC
    THEN1
     (Cases_on ‘h’ \\ fs [lex_def] \\ rw []
      \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
             eval_op_def,return_def]
      \\ first_x_assum (qspecl_then [‘t’,
           ‘s with input := fromList (TL t)’,‘acc’,‘1’] mp_tac)
      \\ fs [name_def])
    \\ fs [Eval_eq,eval_op_def,return_def, take_branch_def,PULL_EXISTS,
           combinTheory.APPLY_UPDATE_THM]
    \\ IF_CASES_TAC
    THEN1
     (Cases_on ‘h’ \\ fs [lex_def] \\ rw []
      \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
             eval_op_def,return_def]
      \\ qspecl_then [‘t’,‘s with input := fromList (TL t)’] mp_tac
           (SIMP_RULE (srw_ss()) [name_def] end_line_thm)
      \\ fs [next_def]
      \\ strip_tac \\ goal_assum (first_assum o mp_then Any mp_tac)
      \\ first_x_assum (qspecl_then [‘end_line t’,
            ‘s with input := fromList (TL (end_line t))’,‘acc’,‘0’] mp_tac)
      \\ fs [name_def]
      \\ disch_then match_mp_tac \\ fs [end_line_length])
    \\ fs [Eval_eq,eval_op_def,return_def, take_branch_def,PULL_EXISTS,
           combinTheory.APPLY_UPDATE_THM]
    \\ Cases_on ‘h’ \\ fs [lex_def] \\ rw [] \\ fs []
    \\ first_x_assum (qspecl_then [‘t’,‘s with input := fromList (TL t)’,‘acc’,‘0’]
                      mp_tac) \\ fs [name_def]
    \\ fs [read_num_def])
  \\ IF_CASES_TAC
  THEN1
   (Cases_on ‘h’ \\ fs [lex_def] \\ rw []
    \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
           eval_op_def,return_def]
    \\ first_x_assum (qspecl_then [‘t’,‘s with input := fromList (TL t)’,‘DOT::acc’,‘0’]
                      mp_tac) \\ fs [name_def,next_def])
  \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
         eval_op_def,return_def,take_branch_def]
  \\ IF_CASES_TAC
  THEN1
   (fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
        eval_op_def,return_def,take_branch_def,ORD_BOUND]
    \\ first_x_assum (qspecl_then [‘t’,‘s with input := fromList (TL t)’,‘acc’,‘0’]
                      mp_tac) \\ fs [name_def,lex_def]
    \\ rw [] \\ fs [read_num_def,next_def])
  \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
         eval_op_def,return_def,take_branch_def,ORD_BOUND]
  \\ fs [lex_def]
  \\ qpat_abbrev_tac ‘pp2 = if k = 0 then _ else _’
  \\ qpat_abbrev_tac ‘pp = if k = 0 then _ else _’
  \\ rw [] \\ fs []
  \\ simp [Once app_cases,PULL_EXISTS,env_and_body_def,make_env_def]
  \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,name_def,
         eval_op_def,return_def,take_branch_def,read_any_code_def]
  \\ reverse (Cases_on ‘ORD #"0" ≤ ORD h ⇒ ORD #"9" < ORD h’) \\ fs [NOT_LESS]
  THEN1
   (fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,name_def,
        eval_op_def,return_def,take_branch_def,read_any_code_def]
    \\ pairarg_tac \\ fs []
    \\ drule (read_num_thm |> SIMP_RULE (srw_ss()) []) \\ fs [next_def]
    \\ disch_then (qspec_then ‘s’ mp_tac) \\ fs [name_def]
    \\ strip_tac \\ goal_assum (first_assum o mp_then Any mp_tac)
    \\ fs [] \\ reverse IF_CASES_TAC
    THEN1
     (fs [] \\ rfs [read_num_def]
      \\ imp_res_tac read_num_length \\ fs [])
    \\ unabbrev_all_tac \\ fs []
    \\ Cases_on ‘k = 0’ \\ fs []
    \\ fs [PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,name_def,
           eval_op_def,return_def,take_branch_def]
    \\ imp_res_tac read_num_length \\ fs []
    \\ first_x_assum (qspecl_then [‘rest’,‘s with input := fromList (TL rest)’,
         ‘if k = 0 then NUM n::acc else QUOTE n::acc’,‘0’] mp_tac)
    \\ fs [name_def])
  \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
         eval_op_def,return_def,take_branch_def,read_any_code_def,name_def]
  \\ IF_CASES_TAC
  \\ pairarg_tac \\ fs []
  \\ pop_assum (mp_tac o REWRITE_RULE [read_num_def]) \\ fs []
  \\ rw []
  \\ fs [AND_IMP_INTRO,PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,
         eval_op_def,return_def,take_branch_def,name_def]
  \\ pairarg_tac \\ fs []
  \\ drule (read_str_thm |> SIMP_RULE (srw_ss()) []) \\ fs [next_def,name_def]
  \\ disch_then (qspec_then ‘s’ mp_tac) \\ fs [name_def]
  \\ strip_tac \\ goal_assum (first_assum o mp_then Any mp_tac)
  \\ fs [] \\ (reverse IF_CASES_TAC
  THEN1 (fs [] \\ rfs [read_num_def] \\ imp_res_tac read_num_length \\ fs []))
  \\ ‘rest' ≠ STRING h t’ by fs [read_num_def]
  \\ unabbrev_all_tac \\ fs []
  \\ Cases_on ‘k = 0’ \\ fs []
  \\ fs [PULL_EXISTS,Eval_eq,combinTheory.APPLY_UPDATE_THM,name_def,
         eval_op_def,return_def,take_branch_def]
  \\ imp_res_tac read_num_length \\ fs []
  \\ first_x_assum (qspecl_then [‘rest'’,
       ‘s with input := fromList (TL rest')’,
       ‘if k = 0 then NUM n' :: acc else QUOTE n'::acc’,‘0’] mp_tac)
  \\ fs [name_def] \\ rfs []
QED

Theorem lexer_thm:
  lookup_fun (name "mul10") s.funs = SOME ([name "n"],mul10_code) ∧
  lookup_fun (name "mul256") s.funs = SOME ([name "n"],mul256_code) ∧
  lookup_fun (name "end_line") s.funs = SOME ([name "next"],end_line_code) ∧
  lookup_fun (name "read_num") s.funs = SOME ([name "acc"; name "next"],read_num_code) ∧
  lookup_fun (name "read_str") s.funs = SOME ([name "acc"; name "next"],read_str_code) ∧
  lookup_fun (name "read_any") s.funs = SOME ([name "next"],read_any_code) ∧
  lookup_fun (name "lex") s.funs = SOME ([name "q"; name "next"; name "acc"],lex_code) ∧
  lookup_fun (name "lexer") s.funs = SOME ([],lexer_code) ∧
  s.input = fromList input ⇒
  app (name "lexer") [] s (list token (lexer input), s with input := LNIL)
Proof
  rw []
  \\ match_mp_tac (trans_app |> SIMP_RULE std_ss [LET_THM] |> MP_CANON |> GEN_ALL)
  \\ fs [make_env_def]
  \\ simp [lexer_code_def]
  \\ simp [Eval_eq,PULL_EXISTS,eval_op_def,return_def]
  \\ qspecl_then [‘input’,‘s with input := fromList (TL input)’,‘[]’,‘0’]
       mp_tac (lex_thm |> SIMP_RULE std_ss [])
  \\ fs [lexer_def]
QED

(* asm2str *)

val res = to_deep x64asm_syntaxTheory.reg_def;

Theorem num_thm: (* this rephrasing avoids MOD, which is not supported *)
  num n s =
    if n < 10 then (CHR (48 + n))::s else
      let d = n DIV 10 in
      let m = n - mul10 d in
        num d ((CHR (48 + m)) :: s)
Proof
  simp [Once x64asm_syntaxTheory.num_def]
  \\ rw [] \\ ‘0 < 10n’ by fs []
  \\ drule DIVISION
  \\ disch_then (qspec_then ‘n’ strip_assume_tac)
  \\ AP_TERM_TAC \\ AP_THM_TAC \\ rpt AP_TERM_TAC \\ decide_tac
QED

Definition num_temp:
  num_temp n s =
    if n < 10 then (CHR (48 + n))::s else
      let d = n DIV 10 in
      let m = n - mul10 d in
        num_temp d ((CHR (48 + m)) :: s)
End

Theorem num_ind = num_temp_ind

val res = to_deep num_thm

Theorem num_side[local]:
  ∀n s. num_side n s ⇔ T
Proof
  completeInduct_on ‘n’ \\ fs []
  \\ once_rewrite_tac [res]
  \\ Cases_on ‘n < 10’ \\ fs []
  \\ rw [] \\ ‘0 < 10n’ by fs []
  \\ drule DIVISION
  \\ disch_then (qspec_then ‘n’ strip_assume_tac)
  \\ decide_tac
QED

val _ = update_mem num_side;

val res = to_deep lab_def
val res = to_deep x64asm_syntaxTheory.clean_def

Definition mul8_def:
  mul8 n =
    let n = n + n in
    let n = n + n in
      n + n : num
End

val res = to_deep mul8_def;

Theorem mul8_thm[simp]:
  mul8_side n = T ∧
  mul8 n = 8 * n
Proof
  fs [mul8_def,res]
QED

val res = to_deep (x64asm_syntaxTheory.inst_def |> REWRITE_RULE [GSYM mul8_thm])
val res = to_deep x64asm_syntaxTheory.insts_def
val lemma = asm2str_def |> concl |> find_term (can (match_term “FLAT _”)) |> EVAL
val res = to_deep (asm2str_def |> SIMP_RULE std_ss [lemma])

(* print *)

(* the dummy binder is called "ret" on purpose: to_cmd names the result of a
   call "ret" too, so the two share a stack slot and print's frame is half the
   size it would otherwise be (see c_bdrs_def / unique_binders_def) *)
val print_code_def = define_code ‘
  (defun print (s)
     (if (= s '0) '0
       (let
         (ret (write (head s)))
         (print (tail s)))))’

Theorem print_thm:
  ∀str s.
    lookup_fun (name "print") s.funs = SOME ([name "s"],print_code) ⇒
    app (name "print") [list char str] s
      (Num 0, s with output := s.output ++ str)
Proof
  gen_tac \\ completeInduct_on ‘LENGTH str’
  \\ rw [] \\ fs [PULL_FORALL]
  \\ match_mp_tac (trans_app |> SIMP_RULE std_ss [LET_THM] |> MP_CANON |> GEN_ALL)
  \\ fs [make_env_def]
  \\ simp [print_code_def]
  \\ simp [Eval_eq,PULL_EXISTS]
  \\ fs [combinTheory.APPLY_UPDATE_THM]
  \\ rename [‘list (MAP char t)’]
  \\ Cases_on ‘t’ \\ fs []
  \\ fs [list_def,take_branch_def,return_def]
  \\ simp [Eval_eq,PULL_EXISTS]
  THEN1 fs [state_component_equality]
  \\ fs [combinTheory.APPLY_UPDATE_THM,eval_op_def,return_def,ORD_BOUND]
  \\ fs [name_def,AND_IMP_INTRO,CHR_ORD]
  \\ first_x_assum (qspecl_then [‘t'’,
      ‘s with output := STRCAT s.output (STRING h "")’] mp_tac)
  \\ fs [] \\ simp_tac std_ss [GSYM APPEND_ASSOC,APPEND]
QED

(* definition of whole program *)

local
val _ = max_print_depth := 15;
val main_exp = parse_exp ‘(let (toks (lexer))
                               (prog (parser toks))
                               (asm  (codegen prog))
                               (str  (asm2str asm))
                            (print str))’;
val entire_program = get_program main_exp;
in

Definition compiler_prog_def:
  compiler_prog = ^entire_program :source_syntax$prog
End

Theorem compiler_prog_thm[local] =
        compiler_prog_def |> CONV_RULE (RAND_CONV EVAL);

end

(* proving that it's correct *)

Theorem compiler_prog_correct:
  ∀input. (input, compiler_prog) prog_terminates (imp_compiler$compiler input)
Proof
  rw [source_semanticsTheory.prog_terminates_def,compiler_prog_thm,compiler_def]
  \\ qpat_abbrev_tac ‘pat = Defun _ _ _ :: _’
  \\ simp [Eval_eq,PULL_EXISTS]
  \\ qspecl_then [‘init_state (fromList input) pat’,‘input’]
       mp_tac (GEN_ALL lexer_thm)
  \\ impl_tac THEN1
    (rewrite_tac [read_num_code_def,read_str_code_def,read_any_code_def,
                  lex_code_def,lexer_code_def,end_line_code_def]
     \\ rpt strip_tac \\ unabbrev_all_tac \\ EVAL_TAC)
  \\ simp [name_def] \\ strip_tac
  \\ goal_assum (first_x_assum o mp_then Any mp_tac)
  \\ ‘init_state (fromList input) pat with input := LNIL = init_state LNIL pat’ by
      simp [init_state_def]
  \\ simp [] \\ pop_assum kall_tac
  \\ ‘∀input. (init_state input pat).input = input’ by (EVAL_TAC \\ fs [])
  \\ simp [] \\ pop_assum kall_tac
  \\ irule_at Any (fetch "-" "parser_app" |> DISCH_ALL |> REWRITE_RULE [AND_IMP_INTRO]
                                                       |> SRULE [name_def])
  \\ simp [GSYM PULL_EXISTS] \\ rewrite_tac [CONJ_ASSOC]
  \\ conj_tac
  >- (unabbrev_all_tac \\ EVAL_TAC \\ fs [llistTheory.LFINITE_THM])
  \\ irule_at Any (fetch "-" "codegen_app" |> DISCH_ALL |> REWRITE_RULE [AND_IMP_INTRO]
                                                        |> SRULE [name_def])
  \\ simp [GSYM PULL_EXISTS] \\ rewrite_tac [CONJ_ASSOC]
  \\ conj_tac
  >- (unabbrev_all_tac \\ EVAL_TAC \\ fs [llistTheory.LFINITE_THM])
  \\ irule_at Any (fetch "-" "asm2str_app" |> DISCH_ALL |> REWRITE_RULE [AND_IMP_INTRO]
                                                        |> SRULE [name_def])
  \\ simp [GSYM PULL_EXISTS] \\ rewrite_tac [CONJ_ASSOC]
  \\ conj_tac
  >- (unabbrev_all_tac \\ EVAL_TAC \\ fs [llistTheory.LFINITE_THM])
  \\ irule_at Any (print_thm |> DISCH_ALL |> REWRITE_RULE [AND_IMP_INTRO]
                                          |> SRULE [name_def])
  \\ simp [str2imp_def]
  \\ unabbrev_all_tac \\ EVAL_TAC \\ simp [print_code_def] \\ EVAL_TAC
QED
