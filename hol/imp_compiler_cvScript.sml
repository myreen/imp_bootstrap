Theory imp_compiler_cv
Ancestors
  arithmetic list pair finite_map string words
  source_values source_syntax imp_source_syntax
  printing parsing codegen x64asm_syntax
  imp_printing imp_parsing imp_to_asm source_to_imp
  cv cv_std
Libs
  term_tactic cv_transLib wordsLib

(* Fast in-logic evaluation (cv_compute) for the IMP compiler pipeline:

     lexer          -- Theory parsing      (read_num, end_line, lex, lexer)
     parser         -- Theory parsing      (quote, parse)
                       Theory imp_parsing  (v2exp .. vs2prog, parser, str2imp)
     pretty printer -- Theory imp_printing (exp2s .. prog2s, imp2str)
     source_to_imp  -- Theory source_to_imp (to_exp .. to_imp)
     IMP code gen   -- Theory imp_to_asm   (c_exp .. codegen)

   Theory compiler_funs_cv does the same job for the functional compiler.  The
   two are deliberately kept in separate branches of the theory graph: Theory
   codegen and Theory imp_to_asm share many constant names (c_exp, c_var,
   c_pops, codegen, ...), as do Theory parsing and Theory imp_parsing (v2exp,
   v2list, parser, ...), so the generated cv_ constants would shadow one
   another.  Every reference below is therefore theory-qualified. *)


(* ------------------------------------------------------------------ *)
(* Helpers shared with the functional compiler (Theory printing)      *)
(* ------------------------------------------------------------------ *)

val pre = cv_trans_pre_rec "num2str_pre" printingTheory.num2str_def
  (WF_REL_TAC ‘measure cv_size’ \\ Cases \\ gvs [] \\ rw [] \\ gvs []);

Theorem num2str_pre[cv_pre]:
  ∀n. num2str_pre n
Proof
  ho_match_mp_tac printingTheory.num2str_ind \\ rw [] \\ simp [Once pre]
  \\ ‘n MOD 10 < 10’ by fs [] \\ decide_tac
QED

val pre = cv_trans_pre "num2ascii_pre" printingTheory.num2ascii_def;

Theorem num2ascii_pre[cv_pre]:
  ∀n. num2ascii_pre n
Proof
  ho_match_mp_tac printingTheory.num2ascii_ind \\ rw [] \\ simp [Once pre]
QED

val pre = cv_trans_pre "ascii_name_pre" printingTheory.ascii_name_def;

Theorem ascii_name_pre[cv_pre]:
  ∀n. ascii_name_pre n
Proof
  simp [Once pre] \\ simp [Once printingTheory.num2ascii_def] \\ rw []
  \\ gvs [AllCaseEqs()]
QED

val _ = cv_auto_trans printingTheory.name2str_def;


(* ------------------------------------------------------------------ *)
(* Lexer (Theory parsing)                                             *)
(* ------------------------------------------------------------------ *)

val _ = cv_auto_trans parsingTheory.read_num_def;
val _ = cv_auto_trans parsingTheory.end_line_def;

(* `lex` recurses on a suffix of its input returned by `read_num`, so the cv
   termination proof needs cv-level analogues of read_num_length and
   end_line_length. *)

Theorem cv_read_num_snd_size:
  ∀v l h f x acc.
    cv_size (cv_snd (cv_read_num l h f x acc v)) ≤ cv_size v
Proof
  Induct \\ rpt gen_tac
  \\ simp [Once (fetch "-" "cv_read_num_def")]
  \\ cv_termination_tac \\ gvs []
  \\ IF_CASES_TAC \\ gvs []
  \\ rpt (first_x_assum (qspecl_then
       [‘l’,‘h’,‘f’,‘x’,‘cv_add (cv_mul f acc) (cv_sub v x)’] assume_tac))
  \\ decide_tac
QED

Theorem cv_read_num_snd_less:
  ∀g g' l h f x acc.
    cv_snd (cv_read_num l h f x acc (cv$Pair g g')) ≠ cv$Pair g g' ⇒
    cv_size (cv_snd (cv_read_num l h f x acc (cv$Pair g g'))) <
    cv_size (cv$Pair g g')
Proof
  rpt gen_tac
  \\ ONCE_REWRITE_TAC [fetch "-" "cv_read_num_def"]
  \\ cv_termination_tac
  \\ IF_CASES_TAC \\ gvs []
  \\ irule LESS_EQ_LESS_TRANS
  \\ irule_at Any cv_read_num_snd_size \\ gvs []
QED

Theorem cv_read_num_less:
  ∀l h f x acc g g' a b.
    cv_read_num l h f x acc (cv$Pair g g') = cv$Pair a b ∧
    cv$c2b (cv_sub (cv$Num 1) (cv_eq b (cv$Pair g g'))) ⇒
    cv_size b < cv_size g + (cv_size g' + 1)
Proof
  rw []
  \\ ‘b ≠ cv$Pair g g'’ by
        (strip_tac \\ gvs [cvTheory.c2b_def, cvTheory.cv_eq_def0])
  \\ ‘cv_snd (cv_read_num l h f x acc (cv$Pair g g')) = b’ by gvs []
  \\ qspecl_then [‘g’,‘g'’,‘l’,‘h’,‘f’,‘x’,‘acc’] mp_tac cv_read_num_snd_less
  \\ gvs []
QED

Theorem cv_end_line_size:
  ∀v. cv_size (cv_end_line v) ≤ cv_size v
Proof
  Induct \\ simp [Once (fetch "-" "cv_end_line_def")]
  \\ cv_termination_tac \\ gvs []
  \\ IF_CASES_TAC \\ gvs []
QED

Theorem cv_end_line_less:
  ∀x1 x2. cv_size (cv_end_line x2) < cv_size x1 + (cv_size x2 + 1)
Proof
  rw [] \\ irule LESS_EQ_LESS_TRANS
  \\ irule_at Any cv_end_line_size \\ gvs []
QED

(* `lex` takes the token constructor (NUM / QUOTE) as an argument.  cv terms
   cannot have function-typed arguments, so translate a first-order variant
   that carries a boolean instead, and prove the two agree. *)

Definition lex_f_def:
  lex_f b [] acc = acc ∧
  lex_f b (c::cs) acc =
      if c = #" " then lex_f F cs acc else
      if c = #"\n" then lex_f F cs acc else
      if c = #"\t" then lex_f F cs acc else
      if c = #"#" then lex_f F (end_line cs) acc else
      if c = #"." then lex_f F cs (DOT::acc) else
      if c = #"(" then lex_f F cs (OPEN::acc) else
      if c = #")" then lex_f F cs (CLOSE::acc) else
      if c = #"'" then lex_f T cs acc else
        let (k,rest) = read_num #"0" #"9" 10 (ORD #"0") 0 (c::cs) in
          if rest ≠ c::cs then
            lex_f F rest ((if b then QUOTE k else NUM k)::acc)
          else
            let (k,rest) = read_num #"*" #"z" 256 0 0 (c::cs) in
              if rest ≠ c::cs then
                lex_f F rest ((if b then QUOTE k else NUM k)::acc)
              else lex_f F cs acc
Termination
  WF_REL_TAC ‘measure (LENGTH o FST o SND)’ \\ rw []
  \\ imp_res_tac (GSYM parsingTheory.read_num_length)
  \\ fs [parsingTheory.end_line_length]
End

Theorem lex_f_thm:
  ∀b cs acc. lex_f b cs acc = lex (if b then QUOTE else NUM) cs acc
Proof
  recInduct lex_f_ind \\ rpt strip_tac
  \\ simp [Once lex_f_def, Once parsingTheory.lex_def]
  \\ rpt (pairarg_tac \\ gvs [])
  \\ rw [] \\ gvs []
QED

val pre = cv_auto_trans_pre_rec "lex_f_pre" lex_f_def
  (WF_REL_TAC ‘measure $ λ(b,cs,acc). cv_size cs’
   \\ rpt strip_tac \\ cv_termination_tac \\ gvs []
   \\ metis_tac [cv_read_num_less, cv_end_line_less]);

Theorem lex_f_pre[cv_pre]:
  ∀b cs acc. lex_f_pre b cs acc
Proof
  ho_match_mp_tac lex_f_ind \\ rw [] \\ simp [Once pre]
  \\ rw [] \\ rpt (pairarg_tac \\ gvs [])
  \\ metis_tac []
QED

Theorem lexer_eq:
  lexer input = lex_f F input []
Proof
  fs [parsingTheory.lexer_def, lex_f_thm]
QED

val _ = cv_auto_trans lexer_eq;

(* ------------------------------------------------------------------ *)
(* Generic s-expression parser (Theory parsing)                       *)
(* ------------------------------------------------------------------ *)

val _ = cv_auto_trans parsingTheory.quote_def;
val _ = cv_auto_trans parsingTheory.parse_def;


(* ------------------------------------------------------------------ *)
(* IMP parser (Theory imp_parsing)                                    *)
(* ------------------------------------------------------------------ *)

val _ = cv_auto_trans imp_parsingTheory.get_num_def;

(* `v2list` recurses via `tail`, which is the identity on `Num`.  In the cv
   encoding a bare `Num` is a malformed value on which that recursion does not
   terminate, so translate a structurally recursive variant instead. *)

Definition v2list_f_def:
  v2list_f (Num n) = [] ∧
  v2list_f (Pair x y) = x :: v2list_f y
End

Theorem v2list_f_thm:
  ∀v. v2list v = v2list_f v
Proof
  Induct \\ simp [Once imp_parsingTheory.v2list_def, v2list_f_def]
QED

val _ = cv_auto_trans v2list_f_def;
val _ = cv_auto_trans v2list_f_thm;

val _ = cv_auto_trans imp_parsingTheory.num2exp_def;
val _ = cv_auto_trans imp_parsingTheory.v2exp_def;
val _ = cv_auto_trans imp_parsingTheory.vs2exps_def;
val _ = cv_auto_trans imp_parsingTheory.v2cmp_def;
val _ = cv_auto_trans imp_parsingTheory.v2test_def;
val _ = cv_auto_trans imp_parsingTheory.vs2args_def;

val pre = cv_auto_trans_pre "v2cmd_pre" imp_parsingTheory.v2cmd_def;

Theorem v2mcd_pre[cv_pre]:
  ∀v. v2cmd_pre v
Proof
  ho_match_mp_tac v2cmd_ind
  \\ gen_tac \\ strip_tac
  \\ simp [Once pre]
QED

val _ = cv_auto_trans imp_parsingTheory.v2func_def;
val _ = cv_auto_trans imp_parsingTheory.v2funcs_def;
val _ = cv_auto_trans imp_parsingTheory.vs2prog_def;
val _ = cv_auto_trans imp_parsingTheory.parser_def;
val _ = cv_auto_trans imp_parsingTheory.str2imp_def;

(* ------------------------------------------------------------------ *)
(* IMP pretty printer (Theory imp_printing)                           *)
(* ------------------------------------------------------------------ *)

val _ = cv_auto_trans imp_printingTheory.unary_sexpr_def;
val _ = cv_auto_trans imp_printingTheory.binary_sexpr_def;
val _ = cv_auto_trans imp_printingTheory.ternary_sexpr_def;
val _ = cv_auto_trans imp_printingTheory.name_sexpr_def;
val _ = cv_auto_trans imp_printingTheory.exp2s_def;
val _ = cv_auto_trans imp_printingTheory.exps2s_imp_def;
val _ = cv_auto_trans imp_printingTheory.exps2s_def;
val _ = cv_auto_trans imp_printingTheory.cmp2str_def;
val _ = cv_auto_trans imp_printingTheory.test2s_def;
val _ = cv_auto_trans imp_printingTheory.names2s_imp_def;
val _ = cv_auto_trans imp_printingTheory.names2s_def;
val _ = cv_auto_trans imp_printingTheory.cmd2s_def;
val _ = cv_auto_trans imp_printingTheory.func2s_def;
val _ = cv_auto_trans imp_printingTheory.funcs2s_imp_def;
val _ = cv_auto_trans imp_printingTheory.prog2s_def;
val _ = cv_auto_trans imp_printingTheory.sexpr2str_def;
val _ = cv_auto_trans imp_printingTheory.imp2str_def;

(* ------------------------------------------------------------------ *)
(* source -> IMP (Theory source_to_imp)                               *)
(* ------------------------------------------------------------------ *)

val _ = cv_auto_trans source_to_impTheory.to_exp_def;
val _ = cv_auto_trans source_to_impTheory.to_exps_def;
val _ = cv_auto_trans source_to_impTheory.to_test_def;
val _ = cv_auto_trans source_to_impTheory.to_guard_def;
val _ = cv_auto_trans source_to_impTheory.dest_Cons_def;
val _ = cv_auto_trans source_to_impTheory.to_cons_def;
val _ = cv_auto_trans source_to_impTheory.to_assign_def;
val _ = cv_auto_trans source_to_impTheory.to_cmd_def;
val _ = cv_auto_trans source_to_impTheory.to_funs_def;
val _ = cv_auto_trans source_to_impTheory.list_Seq_def;
val _ = cv_auto_trans source_to_impTheory.builtin_def;

(* to_imp tests `MEM (func_name x) (name "main" :: MAP FST builtin)`.  Two
   things defeat cv_auto_trans there: the list expression itself, and MEM
   applied to a translated constant rather than a literal list (both give
   NO_MATCH in cv_repLib).  Precompute the list, and use an explicit
   membership function. *)

Definition builtin_names_def:
  builtin_names = name "main" :: MAP FST builtin
End

val _ = cv_trans_deep_embedding EVAL builtin_names_def;

Definition mem_name_def:
  mem_name (n:num) [] = F ∧
  mem_name n (x::xs) = (n = x ∨ mem_name n xs)
End

Theorem mem_name_thm:
  ∀n l. mem_name n l = MEM n l
Proof
  Induct_on ‘l’ \\ gvs [mem_name_def]
QED

val _ = cv_auto_trans mem_name_def;
val _ = cv_auto_trans source_syntaxTheory.func_name_def;

Theorem to_imp_eq:
  to_imp (source_syntax$Program l e) =
    if EXISTS (λx. mem_name (func_name x) builtin_names) l then NONE else
    case to_funs (Defun (name "main") [] e :: l) of
    | SOME fs => SOME (imp_source_syntax$Program $
                         MAP (λ(n,vs,b). Func n vs b) builtin ++ fs)
    | NONE => NONE
Proof
  simp [source_to_impTheory.to_imp_def, builtin_names_def, mem_name_thm]
QED

val _ = cv_auto_trans to_imp_eq;


(* ------------------------------------------------------------------ *)
(* IMP -> x64 code generator (Theory imp_to_asm)                      *)
(* ------------------------------------------------------------------ *)

val _ = cv_auto_trans imp_to_asmTheory.init_def;
val _ = cv_auto_trans imp_to_asmTheory.even_len_def;
val _ = cv_auto_trans imp_to_asmTheory.give_up_def;
val _ = cv_auto_trans imp_to_asmTheory.c_const_def;
val _ = cv_auto_trans imp_to_asmTheory.index_of_def;
val _ = cv_auto_trans imp_to_asmTheory.c_var_def;
val _ = cv_auto_trans imp_to_asmTheory.c_assign_def;
val _ = cv_auto_trans imp_to_asmTheory.c_add_def;
val _ = cv_auto_trans imp_to_asmTheory.c_sub_def;
val _ = cv_auto_trans imp_to_asmTheory.c_div_def;
val _ = cv_auto_trans imp_to_asmTheory.c_alloc_def;
val _ = cv_auto_trans imp_to_asmTheory.app_list_length_def;
val _ = cv_auto_trans imp_to_asmTheory.c_read_def;
val _ = cv_auto_trans imp_to_asmTheory.c_write_def;
val _ = cv_auto_trans imp_to_asmTheory.c_load_def;
val _ = cv_auto_trans imp_to_asmTheory.c_store_def;

val pre = cv_auto_trans_pre "c_exp_pre" imp_to_asmTheory.c_exp_def;

Theorem c_exp_pre[cv_pre]:
  ∀e l vs. c_exp_pre e l vs
Proof
  ho_match_mp_tac imp_to_asmTheory.c_exp_ind \\ rw [] \\ simp [Once pre]
  \\ rpt (pairarg_tac \\ gvs [])
QED

val pre = cv_auto_trans_pre "c_exps_pre" imp_to_asmTheory.c_exps_def;

Theorem c_exps_pre[cv_pre]:
  ∀es l vs. c_exps_pre es l vs
Proof
  ho_match_mp_tac imp_to_asmTheory.c_exps_ind \\ rw [] \\ simp [Once pre]
  \\ rpt (pairarg_tac \\ gvs [])
QED

val _ = cv_auto_trans imp_to_asmTheory.c_cmp_def;

val pre = cv_auto_trans_pre "c_test_jump_pre" imp_to_asmTheory.c_test_jump_def;

Theorem c_test_jump_pre[cv_pre]:
  ∀t p n l vs. c_test_jump_pre t p n l vs
Proof
  ho_match_mp_tac imp_to_asmTheory.c_test_jump_ind \\ rw [] \\ simp [Once pre]
  \\ rpt (pairarg_tac \\ gvs [])
QED

val _ = cv_auto_trans imp_to_asmTheory.lookup_def;
val _ = cv_auto_trans imp_to_asmTheory.make_ret_def;
val _ = cv_auto_trans imp_to_asmTheory.c_pops_def;
val _ = cv_auto_trans imp_to_asmTheory.call_v_stack_def;
val _ = cv_auto_trans imp_to_asmTheory.push_vs_def;
val _ = cv_auto_trans imp_to_asmTheory.c_pushes_def;
val _ = cv_auto_trans imp_to_asmTheory.c_call_def;

val pre = cv_auto_trans_pre "c_cmd_pre" imp_to_asmTheory.c_cmd_def;

Theorem c_cmd_pre[cv_pre]:
  ∀c l fs vs. c_cmd_pre c l fs vs
Proof
  ho_match_mp_tac imp_to_asmTheory.c_cmd_ind \\ rw [] \\ simp [Once pre]
  \\ rpt (pairarg_tac \\ gvs [])
QED

val _ = cv_auto_trans imp_to_asmTheory.all_binders_def;
val _ = cv_auto_trans imp_to_asmTheory.names_contain_def;
val _ = cv_auto_trans imp_to_asmTheory.add_name_def;
val _ = cv_auto_trans imp_to_asmTheory.names_unique_def;
val _ = cv_auto_trans imp_to_asmTheory.unique_binders_def;
val _ = cv_auto_trans imp_to_asmTheory.make_vs_from_binders_def;
val _ = cv_auto_trans imp_to_asmTheory.fltr_nms_def;
val _ = cv_auto_trans imp_to_asmTheory.rm_nms_def;
val _ = cv_auto_trans imp_to_asmTheory.vs_bdrs_def;
val _ = cv_auto_trans imp_to_asmTheory.c_bdrs_def;
val _ = cv_auto_trans imp_to_asmTheory.c_fundef_def;

val pre = cv_trans_pre_rec "N2ascii_pre" imp_to_asmTheory.N2ascii_def
  (WF_REL_TAC ‘measure cv_size’ \\ Cases \\ gvs [] \\ rw [] \\ gvs []);

Theorem N2ascii_pre[cv_pre]:
  ∀n. N2ascii_pre n
Proof
  ho_match_mp_tac imp_to_asmTheory.N2ascii_ind \\ rw [] \\ simp [Once pre]
QED

val pre = cv_auto_trans_pre "c_fundefs_pre" imp_to_asmTheory.c_fundefs_def;

Theorem c_fundefs_pre[cv_pre]:
  ∀ds l fs. c_fundefs_pre ds l fs
Proof
  ho_match_mp_tac imp_to_asmTheory.c_fundefs_ind \\ rw [] \\ simp [Once pre]
  \\ rpt (pairarg_tac \\ gvs [])
QED
val _ = cv_auto_trans codegenTheory.flatten_def;
val _ = cv_auto_trans imp_to_asmTheory.codegen_def;

(* ------------------------------------------------------------------ *)
(* Assembly printing (Theory x64asm_syntax)                           *)
(* ------------------------------------------------------------------ *)

val pre = cv_trans_pre "num_pre" x64asm_syntaxTheory.num_def;

Theorem num_pre[cv_pre]:
  ∀n s. num_pre n s
Proof
  ho_match_mp_tac x64asm_syntaxTheory.num_ind \\ rw [] \\ simp [Once pre]
  \\ ‘n MOD 10 < 10’ by fs [] \\ decide_tac
QED

val _ = cv_auto_trans x64asm_syntaxTheory.asm2str_def;
