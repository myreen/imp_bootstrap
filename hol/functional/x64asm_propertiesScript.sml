Theory x64asm_properties
Ancestors
  arithmetic list pair words
  combin x64asm_syntax x64asm_semantics relation
Libs
  wordsLib BasicProvers mp_then

Inductive steps:
  (∀s (n:num).
    steps (s,n) (s,n))
  ∧
  (∀s1 s2 n.
    step s1 s2 ⇒ steps (s1,n) (s2,n))
  ∧
  (∀s1 s2 n.
    step s1 s2 ⇒ steps (s1,n+1) (s2,n))
  ∧
  (∀s1 n1 s2 n2 s3 n3.
    steps (s1,n1) (s2,n2) ∧
    steps (s2,n2) (s3,n3) ⇒ steps (s1,n1) (s3,n3))
End

(* A step preserves the instruction list and the domain of memory.  It does
   not preserve memory *contents*: Store may overwrite an initialised cell
   (see write_mem_def).  step_memory below says exactly what a step can do to
   memory, and mem_frame is the condition under which reads survive. *)
Theorem step_consts:
  step (State t0) (State t1) ⇒
  t1.instructions = t0.instructions ∧
  ∀w x. read_mem w t0 = SOME x ⇒ ∃y. read_mem w t1 = SOME y
Proof
  fs [step_cases] \\ rw [] \\ fs []
  \\ EVAL_TAC
  \\ gvs[APPLY_UPDATE_THM,write_mem_def,AllCaseEqs(),read_mem_def]
  \\ rw [] \\ gvs [] \\ metis_tac []
QED

(* A step either leaves memory alone or writes one cell that was already part
   of the machine's memory. *)
Theorem step_memory:
  step (State t0) (State t1) ⇒
  t1.memory = t0.memory ∨
  ∃a w v. t0.memory a = SOME v ∧ t1.memory = (a =+ SOME (SOME w)) t0.memory
Proof
  fs [step_cases] \\ rw [] \\ fs []
  \\ EVAL_TAC
  \\ gvs [write_mem_def, AllCaseEqs()]
  \\ metis_tac []
QED

(* mem_frame t0 t1: every successful read at t0 still succeeds, with the same
   value, at t1.  This is what v_inv needs in order to be carried forward. *)
Definition mem_frame_def:
  mem_frame t0 t1 ⇔ ∀a x. read_mem a t0 = SOME x ⇒ read_mem a t1 = SOME x
End

Theorem mem_frame_refl[simp]:
  mem_frame t t
Proof
  fs [mem_frame_def]
QED

Theorem mem_frame_trans:
  mem_frame t0 t1 ∧ mem_frame t1 t2 ⇒ mem_frame t0 t2
Proof
  fs [mem_frame_def]
QED

(* Writing only cells that were still uninitialised keeps every read intact --
   this is how the functional code generator, which writes each heap cell
   exactly once, discharges mem_frame. *)
Theorem mem_frame_write_fresh:
  (∀a. t1.memory a ≠ t0.memory a ⇒ t0.memory a = SOME NONE) ⇒ mem_frame t0 t1
Proof
  rw [mem_frame_def, read_mem_def]
  \\ Cases_on ‘t1.memory a = t0.memory a’ \\ gvs []
  \\ res_tac \\ gvs []
QED

Theorem steps_consts:
  ∀x y.
    steps x y ⇒
    (∀t1 m. y = (State t1,m) ⇒ ∃t0 n. x = (State t0,n)) ∧
    ∀t0 n t1 m.
      x = (State t0,n) ∧ y = (State t1,m) ⇒
      t1.instructions = t0.instructions ∧
      ∀w x. read_mem w t0 = SOME x ⇒ ∃y. read_mem w t1 = SOME y
Proof
  Induct_on ‘steps’ \\ rw [] \\ gvs[]
  \\ imp_res_tac step_consts \\ gvs[]
  \\ gs[Once step_cases]
  \\ res_tac \\ res_tac \\ metis_tac []
QED

Theorem steps_inst:
  steps (State t0,n) (State t1,m) ⇒ t1.instructions = t0.instructions
Proof
  rw [] \\ imp_res_tac steps_consts \\ fs []
QED

Theorem steps_trans:
  ∀x y z. steps x y ∧ steps y z ⇒ steps x z
Proof
  fs [FORALL_PROD] \\ metis_tac [steps_rules]
QED

Theorem steps_refl[simp]:
  ∀x. steps x x
Proof
  once_rewrite_tac [steps_cases] \\ fs [FORALL_PROD]
QED

Theorem IMP_steps_state:
  (∃mid. steps (start,n) mid ∧ ∃s. steps mid (State s,n) ∧ P s) ⇒
  ∃s. steps (start,n) (State s,n) ∧ P s
Proof
  rw [] \\ metis_tac [steps_trans]
QED

Theorem IMP_steps_alt:
  (∃y. steps x y ∧ ∃t1. steps y (State t1,n) ∧ P t1) ⇒
  ∃t1. steps x (State t1,n) ∧ P t1
Proof
  metis_tac [steps_trans]
QED

Theorem IMP_steps:
  (∃mid outcome. steps start mid ∧ steps mid outcome ∧ P outcome) ⇒
  ∃outcome. steps start outcome ∧ P outcome
Proof
  rw [] \\ qexists_tac ‘outcome’ \\ fs []
  \\ PairCases_on ‘start’ \\ PairCases_on ‘mid’ \\ PairCases_on ‘outcome’
  \\ match_mp_tac (steps_rules |> CONJUNCTS |> last)
  \\ goal_assum (first_assum o mp_then Any mp_tac) \\ fs []
QED

Theorem IMP_step:
  (∃mid outcome. step (FST start) (mid) ∧ steps (mid,SND start) outcome ∧ P outcome) ⇒
  ∃outcome. steps start outcome ∧ P outcome
Proof
  rw [] \\ qexists_tac ‘outcome’ \\ fs []
  \\ PairCases_on ‘start’ \\ PairCases_on ‘outcome’
  \\ match_mp_tac (steps_rules |> CONJUNCTS |> last)
  \\ goal_assum (first_assum o mp_then Any mp_tac) \\ fs []
  \\ match_mp_tac (steps_rules |> CONJUNCTS |> el 2) \\ fs []
QED

Theorem IMP_step':
  (∃mid outcome. step s mid ∧ steps (mid,n) outcome ∧ P outcome) ⇒
  ∃outcome. steps (s,SUC n) outcome ∧ P outcome
Proof
  rw [] \\ qexists_tac ‘outcome’ \\ fs []
  \\ PairCases_on ‘outcome’
  \\ match_mp_tac (steps_rules |> CONJUNCTS |> last)
  \\ goal_assum (first_assum o mp_then Any mp_tac) \\ fs [ADD1]
  \\ match_mp_tac (steps_rules |> CONJUNCTS |> el 3) \\ fs []
QED

Theorem IMP_start:
  P start ⇒
  ∃outcome. steps start outcome ∧ P outcome
Proof
  rw [] \\ qexists_tac ‘start’ \\ fs [] \\ PairCases_on ‘start’
  \\ match_mp_tac (steps_rules |> CONJUNCTS |> el 1 |> DISCH T) \\ fs []
QED

Theorem steps_imp_RTC_step:
  ∀s t. steps s t ⇒ step꙳ (FST s) (FST t)
Proof
  Induct_on ‘steps’ \\ fs []
  \\ metis_tac [RTC_TRANSITIVE,transitive_def]
QED

Theorem step_determ:
  step x y ∧ step x z ⇒ y = z
Proof
  once_rewrite_tac [step_cases] \\ rw [] \\ gvs[]
  \\ ntac 2 (fs [take_branch_cases] \\ gvs [])
  \\ gvs [APPEND_11_LENGTH]
QED

Theorem not_step_Halt[simp]:
  ~step (Halt e1 o1) u
Proof
  once_rewrite_tac [step_cases] \\ fs []
QED

Theorem RTC_step_determ:
  ∀x e1 o1 e2 o2.
    step꙳ x (Halt e1 o1) ∧ step꙳ x (Halt e2 o2) ⇒ e2 = e1 ∧ o2 = o1
Proof
  Induct_on ‘RTC’ \\ simp[]
  \\ metis_tac[step_determ, RTC_CASES1, not_step_Halt,
               TypeBase.one_one_of “:s_or_h”]
QED

Theorem steps_IMP_NRC_step:
  ∀s k res r. steps (s,k) (res,r) ⇒ ∃k. NRC step k s res
Proof
  Induct_on ‘steps’ \\ rw[]
  THEN1 (qexists_tac ‘0’ \\ fs [])
  THEN1 (qexists_tac ‘SUC 0’ \\ fs [])
  THEN1 (qexists_tac ‘SUC 0’ \\ fs [])
  \\ metis_tac [NRC_ADD_I]
QED

Theorem NRC_step_determ:
  ∀k s res1 res2. NRC step k s res1 ∧ NRC step k s res2 ⇒ res1 = res2
Proof
  Induct \\ fs [NRC] \\ rw []
  \\ imp_res_tac step_determ \\ rw [] \\ res_tac
QED

Theorem steps_NRC[local]:
  ∀s1 n1 s2 n2.
    steps (s1,n1) (s2,n2) ⇒ ∃k. NRC step (n1 - n2 + k) s1 s2 ∧ n2 ≤ n1
Proof
  Induct_on ‘steps’ \\ rw [] \\ gvs []
  THEN1 (qexists_tac ‘0’ \\ fs [])
  THEN1 (qexists_tac ‘SUC 0’ \\ fs [])
  THEN1 (qexists_tac ‘0’ \\ fs [])
  \\ qexists_tac ‘k+k'’
  \\ ‘k + k' + n1 − n3 = (k + n1 − n2) + (k' + n2 − n3)’ by fs []
  \\ metis_tac [NRC_ADD_I]
QED

Theorem step_mono:
  step (State t1) (State t2) ⇒ t1.output ≼ t2.output
Proof
  rw [step_cases] \\
  gvs [write_reg_def,inc_def,set_pc_def,set_stack_def,write_mem_def,
       AllCaseEqs(),unset_regs_def,put_char_def]
QED

Theorem NRC_step_mono:
  ∀n t1 t2. NRC step n (State t1) (State t2) ⇒ t1.output ≼ t2.output
Proof
  Induct \\ fs [NRC_SUC_RECURSE_LEFT] \\ rw []
  \\ Cases_on ‘z’ \\ fs [] \\ res_tac
  \\ imp_res_tac step_mono
  \\ imp_res_tac rich_listTheory.IS_PREFIX_TRANS
QED

Theorem asm_output_PREFIX:
  NRC step k (State t) (State t1) ∧
  steps (State t,k) (State t2,0) ⇒
  t1.output ≼ t2.output
Proof
  rw [] \\ drule steps_NRC \\ fs [] \\ rw []
  \\ imp_res_tac NRC_ADD_E
  \\ imp_res_tac NRC_step_determ \\ rw []
  \\ imp_res_tac NRC_step_mono
QED

Theorem lprefix_chain_step:
  lprefix_chain {fromList t'.output | step꙳ (State t) (State t')}
Proof
  fs [lprefix_lubTheory.lprefix_chain_def] \\ rw []
  \\ fs [llistTheory.LPREFIX_fromList,llistTheory.from_toList]
  \\ imp_res_tac RTC_NRC
  \\ ‘n ≤ n' ∨ n' ≤ n’ by fs []
  \\ fs [LESS_EQ_EXISTS] \\ rw []
  \\ metis_tac [NRC_ADD_E,NRC_step_determ,NRC_step_mono,
                rich_listTheory.IS_PREFIX_TRANS]
QED
