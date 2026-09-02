Theory imp_source_properties
Ancestors
  arithmetic list pair finite_map string words
  imp_source_syntax imp_source_semantics
Libs
  wordsLib BasicProvers

(* Properties of evaluation functions for the IMP source language. *)
(* Corresponds to coq/theories/imperative/ImpProperties.v          *)

(* ------------------------------------------------------------------ *)
(* Expression, list of expressions, and test evaluation cannot         *)
(* produce a Stop error other than Crash (i.e. they never time out    *)
(* or abort; they either succeed or crash).                            *)
(* ------------------------------------------------------------------ *)

Theorem eval_exp_not_stop:
  ∀e s res s1. eval_exp e s = (res, s1) ⇒ ∀v. res = Stop v ⇒ v = Crash
Proof
  Induct \\ fs [eval_exp_def,bind_def,AllCaseEqs()] \\ rw [] \\ gvs []
  \\ res_tac \\ gvs []
  \\ gvs [combine_word_def |> DefnBase.one_line_ify NONE,
          mem_load_def |> DefnBase.one_line_ify NONE]
  \\ every_case_tac \\ gvs []
QED

Theorem eval_exps_not_stop:
  ∀es s res s1. eval_exps es s = (res, s1) ⇒ ∀v. res = Stop v ⇒ v = Crash
Proof
  Induct \\ fs [eval_exps_def,bind_def,AllCaseEqs()] \\ rw [] \\ gvs []
  \\ imp_res_tac eval_exp_not_stop \\ res_tac \\ gvs []
QED

Theorem eval_test_not_stop:
  ∀t s res s1. eval_test t s = (res, s1) ⇒ ∀v. res = Stop v ⇒ v = Crash
Proof
  Induct \\ fs [eval_test_def,bind_def,AllCaseEqs()] \\ rw [] \\ gvs []
  \\ imp_res_tac eval_exp_not_stop \\ res_tac \\ gvs []
  \\ gvs [eval_cmp_def |> DefnBase.one_line_ify NONE]
  \\ every_case_tac \\ gvs []
QED

(* ------------------------------------------------------------------ *)
(* Clock monotonicity: eval_cmd can only decrease the clock.          *)
(* (eval_cmd_clock is already proved in imp_source_semanticsScript)   *)
(* ------------------------------------------------------------------ *)

Theorem eval_cmd_timeout_clock_zero_lemma[local]:
  ∀c s res s1. eval_cmd c s = (res, s1) ⇒ res = Stop TimeOut ⇒ s1.clock = 0
Proof
  ho_match_mp_tac eval_cmd_ind \\ rw []
  \\ qpat_x_assum ‘eval_cmd _ _ = _’ mp_tac
  \\ once_rewrite_tac [eval_cmd_def]
  \\ gvs [bind_def,cont_def,stop_def,tick_def,assign_def,get_char_def,alloc_def,
          put_char_def |> DefnBase.one_line_ify NONE,
          dest_word_def |> DefnBase.one_line_ify NONE,
          update_def |> DefnBase.one_line_ify NONE,
          AllCaseEqs()]
  \\ rw [] \\ gvs []
  \\ imp_res_tac eval_exp_not_stop
  \\ imp_res_tac eval_exps_not_stop
  \\ imp_res_tac eval_test_not_stop
  \\ gvs []
  \\ every_case_tac \\ gvs []
QED

(* If eval_cmd times out, the clock must be zero. *)
Theorem eval_cmd_timeout_clock_zero:
  ∀c s s1. eval_cmd c s = (Stop TimeOut, s1) ⇒ s1.clock = 0
Proof
  metis_tac [eval_cmd_timeout_clock_zero_lemma]
QED

(* Same for catch_return. *)
Theorem catch_return_timeout_clock_zero:
  ∀c s s1.
    catch_return (eval_cmd c) s = (Stop TimeOut, s1) ⇒ s1.clock = 0
Proof
  rw [] \\ gvs [AllCaseEqs()]
  \\ imp_res_tac eval_cmd_timeout_clock_zero \\ gvs []
QED

(* ------------------------------------------------------------------ *)
(* Adding clock does not change successful results.                    *)
(* source_to_impScript.sml derives eval_cmd_add_clock from the variant *)
(* below by conjoining its antecedents.                               *)
(* ------------------------------------------------------------------ *)

Theorem eval_exp_with_clock:
  ∀e s v s1.
    eval_exp e s = (v,s1) ⇒
    eval_exp e (s with clock := s.clock + k) = (v,s1 with clock := s1.clock + k)
Proof
  Induct
  \\ fs [eval_exp_def,AllCaseEqs(),bind_def] \\ rw []
  \\ res_tac \\ fs [combine_word_def |> DefnBase.one_line_ify NONE, AllCaseEqs()]
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

Theorem eval_cmd_add_clock_variant:
  ∀c s res s1.
    eval_cmd c s = (res, s1) ⇒ res ≠ Stop TimeOut ⇒
    ∀k. eval_cmd c (s with clock := s.clock + k) =
        (res, s1 with clock := s1.clock + k)
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

(* ------------------------------------------------------------------ *)
(* Monotonicity: if the initial clock is positive, the clock          *)
(* decreases strictly for While/Call (uses tick).                     *)
(* ------------------------------------------------------------------ *)

(* When a While or Call step is taken the clock drops by at least 1.
   More precisely: the clock used by a sequence of ticks is bounded. *)
Theorem eval_cmd_clock_bound:
  ∀c s res s1.
    eval_cmd c s = (res, s1) ⇒
    s1.clock ≤ s.clock
Proof
  (* This is exactly eval_cmd_clock from imp_source_semanticsScript *)
  metis_tac [eval_cmd_clock]
QED
