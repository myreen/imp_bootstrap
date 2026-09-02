Theory imp_to_asm_proof
Ancestors
  arithmetic list pair finite_map string words
  imp_source_syntax imp_source_semantics imp_source_properties
  x64asm_syntax x64asm_semantics x64asm_properties
  codegen imp_to_asm alist option
Libs
  wordsLib BasicProvers

(* Correctness proof for the IMP-to-x64-assembly code generator.     *)
(* Corresponds to coq/theories/imp2asm/ImpToASMCodegenProofs.v       *)

(* ------------------------------------------------------------------ *)
(* Auxiliary definitions                                               *)
(* ------------------------------------------------------------------ *)

(* code_in n xs code: the sequence xs appears starting at index n    *)
(* in the instruction list code.                                       *)
Definition code_in_def:
  code_in n [] code = T ∧
  code_in n (x::xs) code = (oEL n code = SOME x ∧ code_in (n+1) xs code)
End

(* The initial code fragment appears at position 0 in instructions.  *)
Definition init_code_in_def:
  init_code_in instructions = ∃start. code_in 0 (init start) instructions
End

(* code_rel: initial code is present and every function has its      *)
(* compiled form at the right position in the instruction list.       *)
Definition code_rel_def:
  code_rel fs ds instructions ⇔
    init_code_in instructions ∧
    ∀n params body.
      find_fun n ds = SOME (params, body) ⇒
      ∃pos.
        ALOOKUP fs n = SOME pos ∧
        code_in pos (flatten (FST (c_fundef (Func n params body) pos fs)) [])
                    instructions
End

Definition heap_ok_def:
  heap_ok (r14:word64) r15 m ⇔
    r14 <=+ r15 ∧ aligned 3 r14 ∧ aligned 3 r15 ∧ r14 ≠ 0w ∧
    ∀a. r14 <=+ a ∧ a <+ r15 ∧ aligned 3 a ⇒ can_write_mem_at m a
End

Theorem MOD8_ADD[local]:
  ∀a b. a MOD 8 = 0 ∧ b MOD 8 = 0 ⇒ (a + b) MOD 8 = 0
Proof
  rpt strip_tac
  \\ ‘(a + b) MOD 8 = (a MOD 8 + b MOD 8) MOD 8’ by
       metis_tac [arithmeticTheory.MOD_PLUS, DECIDE “0 < 8n”]
  \\ pop_assum (fn th => once_rewrite_tac [th])
  \\ fs []
QED

Theorem MOD16_MOD8[local]:
  ∀x:num. x MOD 16 = 0 ⇒ x MOD 8 = 0
Proof
  rw [arithmeticTheory.MOD_EQ_0_DIVISOR]
  \\ qexists_tac ‘2 * d’ \\ fs []
QED

(* The initial state satisfies the stronger, 16-byte aligned invariant. *)
Theorem memory_writable_heap_ok:
  ∀r14 r15 m. memory_writable r14 r15 m ⇒ heap_ok r14 r15 m
Proof
  rw [heap_ok_def, x64asm_semanticsTheory.memory_writable_def]
  \\ gvs [alignmentTheory.aligned_w2n]
  \\ irule MOD16_MOD8 \\ fs []
QED

(* state_rel: relates an IMP state to an x64 ASM state.              *)
Definition state_rel_def:
  state_rel fs s t ⇔
    s.input = t.input ∧
    s.output = t.output ∧
    code_rel fs s.funs t.instructions ∧
    ∃r14 r15.
      t.regs R12  = SOME 16w ∧
      t.regs R13  = SOME (n2w (2**63 - 1)) ∧
      t.regs R14  = SOME r14 ∧
      t.regs R15  = SOME r15 ∧
      heap_ok r14 r15 t.memory
End

(* has_stack: the ASM stack has a specific list of words/ret values, *)
(* with the top element in RAX.                                        *)
Definition has_stack_def:
  has_stack t xs ⇔
    ∃w ws.
      xs = Word w :: ws ∧
      t.regs RAX = SOME w ∧
      t.stack = ws
End

(* v_inv: relates an IMP value to an x64 word, using pmap for        *)
(* pointer-to-address translation.                                     *)
Definition v_inv_def:
  v_inv pmap (Word v) w = (w = v) ∧
  v_inv pmap (Pointer p) w = ∃length. pmap p = SOME (w, length)
End

(* pmap_in_memory: every pointer in pmap has a corresponding block   *)
(* in the IMP memory.                                                  *)
Definition pmap_in_memory_def:
  pmap_in_memory pmap impm ⇔
    ∀p l base. pmap p = SOME (base, l) ⇒ ∃v. oEL p impm = SOME v
End

(* mem_inv: the IMP memory and ASM memory are consistent via pmap.   *)
Definition mem_inv_def:
  mem_inv pmap asmm impm ⇔
    ∀p v.
      oEL p impm = SOME v ⇒
      ∃base.
        pmap p = SOME (base, LENGTH v) ∧
        ∀off xopt.
          oEL off v = SOME xopt ⇒
          ∃yopt.
            asmm (base + n2w (off * 8)) = SOME yopt ∧
            OPTREL (v_inv pmap) xopt yopt
End

(* env_ok: the IMP variable environment matches the ASM stack frame. *)
Definition env_ok_def:
  env_ok env vs curr pmap ⇔
    LENGTH vs = LENGTH curr ∧
    ∀n v.
      FLOOKUP env n = SOME v ⇒
      MEM (SOME n) vs ∧
      ∃w.
        oEL (index_of n 0 vs) curr = SOME (Word w) ∧
        v_inv pmap v w
End

(* binders_ok: all binders of command c appear in vs.                *)
Definition binders_ok_def:
  binders_ok Skip vs = T ∧
  binders_ok (Seq c1 c2) vs = (binders_ok c1 vs ∧ binders_ok c2 vs) ∧
  binders_ok (Assign n e) vs = MEM (SOME n) vs ∧
  binders_ok (Update a e e') vs = T ∧
  binders_ok (If t c1 c2) vs = (binders_ok c1 vs ∧ binders_ok c2 vs) ∧
  binders_ok (While tst body) vs = binders_ok body vs ∧
  binders_ok (Call n f es) vs = MEM (SOME n) vs ∧
  binders_ok (Return e) vs = T ∧
  binders_ok (Alloc n e) vs = MEM (SOME n) vs ∧
  binders_ok (GetChar n) vs = MEM (SOME n) vs ∧
  binders_ok (PutChar e) vs = T ∧
  binders_ok Abort vs = T
End

(* cmd_res_rel: relates an IMP command outcome to the resulting ASM  *)
(* state, parameterised by pmap and frame information.                *)
Definition cmd_res_rel_def:
  cmd_res_rel ri l1 rest vs t1 s1 pmap ⇔
    case ri of
    | Stop (Return v) =>
        ∃w.
          v_inv pmap v w ∧
          mem_inv pmap t1.memory s1.memory ∧
          pmap_in_memory pmap s1.memory ∧
          has_stack t1 (Word w :: rest) ∧
          fetch t1 = SOME Ret
    | Cont _ =>
        ∃curr1.
          has_stack t1 (curr1 ++ rest) ∧
          mem_inv pmap t1.memory s1.memory ∧
          pmap_in_memory pmap s1.memory ∧
          env_ok s1.vars vs curr1 pmap ∧
          t1.pc = l1
    | Stop Abort => F
    | Stop TimeOut => T
    | Stop Crash => T
End

(* exp_res_rel: relates an IMP expression outcome to an ASM state.   *)
Definition exp_res_rel_def:
  exp_res_rel ri l1 stck t1 s1 pmap ⇔
    case ri of
    | Cont v =>
        ∃w.
          v_inv pmap v w ∧
          mem_inv pmap t1.memory s1.memory ∧
          pmap_in_memory pmap s1.memory ∧
          has_stack t1 (Word w :: stck) ∧
          t1.pc = l1
    | _ => F
End

(* exps_res_rel: relates an IMP list-of-expressions outcome to an    *)
(* ASM state with multiple words pushed on the stack.                 *)
Definition exps_res_rel_def:
  exps_res_rel ri l1 stck t1 s1 pmap ⇔
    case ri of
    | Cont vs =>
        ∃ws.
          LIST_REL (v_inv pmap) vs ws ∧
          mem_inv pmap t1.memory s1.memory ∧
          pmap_in_memory pmap s1.memory ∧
          has_stack t1 (MAP Word (REVERSE ws) ++ stck) ∧
          t1.pc = l1
    | _ => F
End

(* pmap_in_bounds: all allocated blocks lie within [0, r14).         *)
Definition pmap_in_bounds_def:
  pmap_in_bounds pmap mr14 ⇔
    ∀p base len wr14.
      pmap p = SOME (base, len) ∧ mr14 = SOME wr14 ⇒
        (∀n. n < len ⇒ base + n2w (n * 8) <+ wr14) ∧
        0w <+ base
End

(* r14_mono: the allocation pointer (R14) only moves forward.        *)
Definition r14_mono_def:
  r14_mono old_r14 new_r14 ⇔
    ∃old_wr14 new_wr14.
      old_r14 = SOME old_wr14 ∧ new_r14 = SOME new_wr14 ∧
      old_wr14 <=+ new_wr14
End

(* pmap_ok: distinct blocks do not share addresses.                  *)
Definition pmap_ok_def:
  pmap_ok pmap ⇔
    ∀p1 p2 base1 len1 base2 len2.
      pmap p1 = SOME (base1, len1) ∧ pmap p2 = SOME (base2, len2) ⇒
      ∀n1 n2. n1 < len1 ∧ n2 < len2 ∧
              base1 + n2w (n1 * 8) = base2 + n2w (n2 * 8) ⇒
              p1 = p2 ∧ n1 = n2
End

(* pmap_subsume: pmap1 extends pmap (agrees on all entries of pmap). *)
Definition pmap_subsume_def:
  pmap_subsume pmap pmap1 ⇔
    ∀p v. pmap p = SOME v ⇒ pmap1 p = SOME v
End

(* ------------------------------------------------------------------ *)
(* Further proof helpers (used inside the correctness proofs)          *)
(* ------------------------------------------------------------------ *)

Definition ARGS_REGS_def:
  ARGS_REGS = [RDI; RDX; RBX; RBP]
End

Definition write_reg_map_def:
  write_reg_map r w rgs = (λr'. if r' = r then SOME w else rgs r')
End

Definition write_regs_def:
  write_regs [] rs rgs = rgs ∧
  write_regs (w::ws) [] rgs = rgs ∧
  write_regs (w::ws) (r::rs) rgs = write_reg_map r w (write_regs ws rs rgs)
End

Definition pops_regs_def:
  pops_regs ws rgs =
    case ws of
    | [] => rgs
    | _ => write_regs ws (REVERSE (TAKE (LENGTH ws - 1) ARGS_REGS)) rgs
End

Theorem s_with_clock[simp]:
  (s with clock := s.clock) = s
Proof
  simp [imp_source_semanticsTheory.state_component_equality]
QED

(* ------------------------------------------------------------------ *)
(* Goal statements (correctness specs for each compilation case)      *)
(* ------------------------------------------------------------------ *)

(* goal_exp: compiled expression is correct.                          *)
Definition goal_exp_def:
  goal_exp e ⇔
    ∀s s1 fuel res t vs fs asmc l1 curr rest pmap.
      eval_exp e s = (res, s1) ∧
      res ≠ Stop Crash ∧
      c_exp e t.pc vs = (asmc, l1) ∧
      state_rel fs s t ∧
      env_ok s.vars vs curr pmap ∧
      has_stack t (curr ++ rest) ∧
      mem_inv pmap t.memory s.memory ∧
      pmap_in_memory pmap s.memory ∧
      pmap_ok pmap ∧
      ODD (LENGTH rest) ∧
      code_in t.pc (flatten asmc []) t.instructions ⇒
      ∃t1.
        steps (State t, fuel) (State t1, fuel) ∧
        state_rel fs s1 t1 ∧
        r14_mono (t.regs R14) (t1.regs R14) ∧
        exp_res_rel res l1 (curr ++ rest) t1 s1 pmap ∧
        s1.vars = s.vars ∧
        ∀x. res ≠ Stop x
End

(* goal_exps: compiled expression list is correct.                    *)
Definition goal_exps_def:
  goal_exps es ⇔
    ∀s s1 fuel res t vs fs asmc l1 curr rest pmap.
      eval_exps es s = (res, s1) ∧
      res ≠ Stop Crash ∧
      c_exps es t.pc vs = (asmc, l1) ∧
      state_rel fs s t ∧
      env_ok s.vars vs curr pmap ∧
      has_stack t (curr ++ rest) ∧
      mem_inv pmap t.memory s.memory ∧
      pmap_in_memory pmap s.memory ∧
      pmap_ok pmap ∧
      ODD (LENGTH rest) ∧
      code_in t.pc (flatten asmc []) t.instructions ⇒
      ∃t1.
        steps (State t, fuel) (State t1, fuel) ∧
        state_rel fs s1 t1 ∧
        r14_mono (t.regs R14) (t1.regs R14) ∧
        exps_res_rel res l1 (curr ++ rest) t1 s1 pmap ∧
        s1.vars = s.vars ∧
        ∀x. res ≠ Stop x
End

(* goal_test: compiled test is correct.                               *)
Definition goal_test_def:
  goal_test tst ⇔
    ∀s s1 fuel b t vs fs asmc l1 ltrue lfalse curr rest pmap.
      eval_test tst s = (Cont b, s1) ∧
      c_test_jump tst ltrue lfalse t.pc vs = (asmc, l1) ∧
      state_rel fs s t ∧
      env_ok s.vars vs curr pmap ∧
      has_stack t (curr ++ rest) ∧
      mem_inv pmap t.memory s.memory ∧
      (∃r14. pmap_in_bounds pmap (SOME r14)) ∧
      pmap_in_memory pmap s.memory ∧
      pmap_ok pmap ∧
      ODD (LENGTH rest) ∧
      code_in t.pc (flatten asmc []) t.instructions ⇒
      ∃t1.
        steps (State t, fuel) (State t1, fuel) ∧
        state_rel fs s1 t1 ∧
        r14_mono (t.regs R14) (t1.regs R14) ∧
        mem_inv pmap t1.memory s1.memory ∧
        pmap_in_memory pmap s1.memory ∧
        has_stack t1 (curr ++ rest) ∧
        t1.pc = (if b then ltrue else lfalse)
End

(* goal_cmd: compiled command is correct.                            *)
(* The ASM machine runs for exactly as many steps as the IMP machine *)
(* used (measured by clock drop: s.clock - s1.clock).                *)
Definition goal_cmd_def:
  goal_cmd c fuel ⇔
    ∀s s1 res t vs fs asmc l1 curr rest pmap.
      eval_cmd c (s with clock := fuel) = (res, s1) ∧
      res ≠ Stop Crash ∧
      c_cmd c t.pc fs vs = (asmc, l1) ∧
      state_rel fs s t ∧
      env_ok s.vars vs curr pmap ∧
      binders_ok c vs ∧
      has_stack t (curr ++ rest) ∧
      mem_inv pmap t.memory s.memory ∧
      pmap_in_memory pmap s.memory ∧
      pmap_ok pmap ∧
      pmap_in_bounds pmap (t.regs R14) ∧
      ODD (LENGTH rest) ∧
      ODD (LENGTH curr) ∧
      code_in t.pc (flatten asmc []) t.instructions ⇒
      ∃outcome pmap1.
        steps (State t, fuel - s1.clock) outcome ∧
        pmap_ok pmap1 ∧
        pmap_subsume pmap pmap1 ∧
        case outcome of
        | (Halt ec output, ck) =>
            isPREFIX output s1.output ∧
            (ec = 1w ∨ ec = 4w)
        | (State t1, ck) =>
            ck = 0 ∧
            state_rel fs s1 t1 ∧
            r14_mono (t.regs R14) (t1.regs R14) ∧
            pmap_in_bounds pmap1 (t1.regs R14) ∧
            cmd_res_rel res l1 rest vs t1 s1 pmap1
End

(* ------------------------------------------------------------------ *)
(* Auxiliary lemmas                                                    *)
(* ------------------------------------------------------------------ *)

Theorem steps_add_fuel:
  ∀a n b m k. steps (a,n) (b,m) ⇒ steps (a,n+k) (b,m+k)
Proof
  rpt gen_tac
  \\ qsuff_tac ‘∀x y. steps x y ⇒ ∀k. steps (FST x,SND x + k) (FST y,SND y + k)’
  >- (rw [] \\ res_tac \\ fs [])
  \\ Induct_on ‘steps’ \\ rw []
  >- (irule (cj 2 steps_rules) \\ fs [])
  >- (qspecl_then [‘s1’,‘s2’,‘n+k’] mp_tac (cj 3 steps_rules) \\ fs [])
  \\ metis_tac [steps_trans]
QED

(*
Theorem exists_pair[local,simp]:
  ∀x:'a # 'b. ∃a b. x = (a,b)
Proof
  metis_tac [pair_CASES]
QED
*)

Theorem code_in_IMP_fetch:
  ∀t x xs. code_in t.pc (x::xs) t.instructions ⇒ fetch t = SOME x
Proof
  rw [code_in_def, fetch_def]
QED

(* An unconditional jump: one machine step that consumes no fuel. *)
Theorem steps_Jump:
  ∀t n k. fetch t = SOME (Jump Always n) ⇒
          steps (State t,k) (State (set_pc n t),k)
Proof
  rw [] \\ irule (cj 2 steps_rules)
  \\ simp [Once step_cases, take_branch_cases]
QED

(* A conditional jump: one step, no fuel, landing on whichever label the
   comparison selects. *)
Theorem steps_Jump_cond:
  ∀t cond n k b.
    fetch t = SOME (Jump cond n) ∧ take_branch cond t b ⇒
    steps (State t,k) (State (set_pc (if b then n else t.pc + 1) t),k)
Proof
  rw [] \\ irule (cj 2 steps_rules)
  \\ simp [Once step_cases] \\ metis_tac []
QED

(* The loop back-edge must consume one unit of fuel, matching the tick in
   the While semantics. *)
Theorem steps_Jump_tick:
  ∀t n k. fetch t = SOME (Jump Always n) ⇒
          steps (State t, k + 1) (State (set_pc n t), k)
Proof
  rw [] \\ irule (cj 3 steps_rules)
  \\ simp [Once step_cases, take_branch_cases]
QED

Theorem flatten_acc:
  ∀p acc. flatten p acc = flatten p [] ++ acc
Proof
  once_rewrite_tac [EQ_SYM_EQ]
  \\ Induct_on ‘p’ \\ simp_tac std_ss [flatten_def] \\ fs []
  \\ last_assum (once_rewrite_tac o single o GSYM)
  \\ first_assum (once_rewrite_tac o single o GSYM)
  \\ fs []
QED

Theorem LENGTH_flatten:
  ∀p acc. LENGTH (flatten p acc) = app_list_length p + LENGTH acc
Proof
  Induct \\ fs [flatten_def, app_list_length_def]
QED

Theorem app_list_length_thm:
  ∀p. app_list_length p = LENGTH (flatten p [])
Proof
  simp [LENGTH_flatten]
QED

(* Normalising form for flatten over +++, safe as a rewrite. *)
Theorem flatten_append:
  ∀a b acc. flatten (a +++ b) acc = flatten a [] ++ flatten b acc
Proof
  rw [flatten_def] \\ metis_tac [flatten_acc]
QED

Theorem c_exp_length:
  ∀e l vs asm l1. c_exp e l vs = (asm,l1) ⇒ l1 = l + app_list_length asm
Proof
  Induct \\ simp [Once c_exp_def] \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ fs []) \\ rw [] \\ res_tac
  \\ gvs [c_var_def, c_const_def, c_add_def, c_sub_def, c_div_def, c_load_def,
          app_list_length_def, AllCaseEqs()]
QED

Theorem c_exps_length:
  ∀es l vs asm l1. c_exps es l vs = (asm,l1) ⇒ l1 = l + app_list_length asm
Proof
  Induct \\ simp [Once c_exps_def] \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ fs []) \\ rw [] \\ res_tac
  \\ imp_res_tac c_exp_length \\ gvs [app_list_length_def]
QED

Theorem c_test_jump_length:
  ∀tst pos neg l vs asm l1.
    c_test_jump tst pos neg l vs = (asm,l1) ⇒ l1 = l + app_list_length asm
Proof
  Induct \\ simp [Once c_test_jump_def] \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ fs []) \\ rw [] \\ res_tac
  \\ imp_res_tac c_exp_length \\ gvs [app_list_length_def]
QED

Theorem c_cmd_length:
  ∀c l fs vs asm l1. c_cmd c l fs vs = (asm,l1) ⇒ l1 = l + app_list_length asm
Proof
  Induct \\ simp [Once c_cmd_def] \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ fs []) \\ rw [] \\ res_tac
  \\ imp_res_tac c_exp_length \\ imp_res_tac c_exps_length
  \\ imp_res_tac c_test_jump_length
  \\ gvs [c_assign_def, c_call_def, c_tail_call_def, c_read_def, c_write_def,
          make_ret_def, c_alloc_def, c_store_def, app_list_length_def,
          AllCaseEqs()]
  \\ rpt (pairarg_tac \\ gvs [])
  \\ imp_res_tac c_exps_length \\ gvs [app_list_length_def]
QED

Theorem c_pushes_length:
  ∀v_names l asm e l1.
    c_pushes v_names l = (asm,e,l1) ⇒ l1 = l + app_list_length asm
Proof
  rw [c_pushes_def] \\ gvs [AllCaseEqs(), app_list_length_def]
QED

Theorem c_pushes_vs[local]:
  ∀ps l asm1 vs1 l1. c_pushes ps l = (asm1,vs1,l1) ⇒ vs1 = push_vs ps
Proof
  rw [c_pushes_def] \\ gvs []
QED

Theorem c_fundef_length:
  ∀d l fs c l1. c_fundef d l fs = (c,l1) ⇒ l1 = l + app_list_length c
Proof
  Cases \\ simp [Once c_fundef_def] \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ simp []) \\ rw []
  \\ imp_res_tac c_cmd_length \\ imp_res_tac c_pushes_length
  \\ gvs [c_bdrs_def, app_list_length_def]
QED

Theorem c_fundefs_length:
  ∀ds l fs c fs1 l1.
    c_fundefs ds l fs = (c,fs1,l1) ⇒ l1 = l + app_list_length c
Proof
  Induct \\ simp [Once c_fundefs_def] \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ simp []) \\ rw []
  \\ imp_res_tac c_fundef_length \\ res_tac
  \\ gvs [app_list_length_def]
QED

Theorem c_cmd_11[local]:
  ∀c l fs1 fs2 vs c1 l1 c2 l2.
    c_cmd c l fs1 vs = (c1,l1) ∧ c_cmd c l fs2 vs = (c2,l2) ⇒ l1 = l2
Proof
  Induct \\ rpt gen_tac
  \\ once_rewrite_tac [c_cmd_def] \\ simp []
  \\ rpt (pairarg_tac \\ simp [])
  \\ every_case_tac \\ simp []
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs []
  \\ gvs [c_call_def, c_tail_call_def]
  \\ metis_tac []
QED

Theorem c_fundef_11[local]:
  ∀d l fs1 fs2 c1 l1 c2 l2.
    c_fundef d l fs1 = (c1,l1) ∧ c_fundef d l fs2 = (c2,l2) ⇒ l1 = l2
Proof
  Cases \\ rpt gen_tac
  \\ once_rewrite_tac [c_fundef_def] \\ simp []
  \\ rpt (pairarg_tac \\ simp []) \\ strip_tac \\ gvs []
  \\ imp_res_tac c_cmd_11 \\ gvs []
QED

Theorem c_fundefs_11[local]:
  ∀ds l fs1 fs2 c1 t1 m1 c2 t2 m2.
    c_fundefs ds l fs1 = (c1,t1,m1) ∧ c_fundefs ds l fs2 = (c2,t2,m2) ⇒
    m1 = m2 ∧ ∃tbl. t1 = tbl ++ fs1 ∧ t2 = tbl ++ fs2
Proof
  Induct \\ rpt gen_tac
  \\ once_rewrite_tac [c_fundefs_def] \\ simp []
  \\ rpt (pairarg_tac \\ simp []) \\ strip_tac \\ gvs []
  \\ ‘l1 = l1'’ by metis_tac [c_fundef_11]
  \\ gvs []
  \\ first_assum (qspecl_then
       [‘l1+1’,‘fs1’,‘fs2’,‘c2'’,‘fs'’,‘l2’,‘c2''’,‘fs''’,‘l2'’] mp_tac)
  \\ simp [] \\ strip_tac
  \\ qexists_tac ‘(get_name h,l + 1)::tbl’ \\ gvs []
QED

Theorem ALOOKUP_SOME_APPEND[local]:
  ∀xs n pos ys. ALOOKUP xs n = SOME pos ⇒ ALOOKUP (xs ++ ys) n = SOME pos
Proof
  rw [ALOOKUP_APPEND]
QED

Theorem put_char_output[local]:
  put_char v s = (res,s1) ⇒ s.output ≼ s1.output
Proof
  Cases_on ‘v’ \\ rw [] \\ gvs [AllCaseEqs()]
QED

(* Output monotonicity: a command can only append to the output. *)
Theorem eval_cmd_output:
  ∀c s res s1. eval_cmd c s = (res,s1) ⇒ s.output ≼ s1.output
Proof
  ho_match_mp_tac eval_cmd_ind \\ reverse (rw [])
  \\ pop_assum mp_tac
  \\ TRY
   (rename [‘While’]
    \\ once_rewrite_tac [eval_cmd_def]
    \\ TOP_CASE_TAC \\ fs []
    \\ imp_res_tac eval_test_pure \\ gvs []
    \\ TOP_CASE_TAC \\ fs [] \\ rw [] \\ gvs []
    \\ Cases_on ‘eval_cmd c r’ \\ fs [] \\ gvs [fix_def]
    \\ Cases_on ‘q’ \\ fs [] \\ rw [] \\ gvs []
    \\ gvs [tick_def,cont_def,stop_def,AllCaseEqs()]
    \\ metis_tac [rich_listTheory.IS_PREFIX_TRANS])
  \\ TRY
   (rename [‘Call’]
    \\ once_rewrite_tac [eval_cmd_def]
    \\ TOP_CASE_TAC \\ fs []
    \\ imp_res_tac eval_exps_pure \\ gvs [] \\ rw [] \\ gvs []
    \\ rpt (FULL_CASE_TAC \\ gvs [])
    \\ gvs [fix_def,tick_def,stop_def,cont_def,AllCaseEqs()]
    \\ metis_tac [rich_listTheory.IS_PREFIX_TRANS])
  \\ TRY
   (rename [‘If’]
    \\ once_rewrite_tac [eval_cmd_def]
    \\ TOP_CASE_TAC \\ fs []
    \\ imp_res_tac eval_test_pure \\ gvs []
    \\ TOP_CASE_TAC \\ fs [] \\ rw [] \\ gvs [])
  \\ once_rewrite_tac [eval_cmd_def]
  \\ gvs [cont_def,stop_def,fix_def,AllCaseEqs(),bind_def,assign_def,
          update_def |> DefnBase.one_line_ify NONE, alloc_def, put_char_def,
          dest_word_def |> DefnBase.one_line_ify NONE, get_char_def]
  \\ rw [] \\ gvs []
  \\ imp_res_tac eval_exp_pure \\ gvs []
  \\ rpt (FULL_CASE_TAC \\ gvs [AllCaseEqs()])
  \\ imp_res_tac put_char_output
  \\ metis_tac [rich_listTheory.IS_PREFIX_TRANS]
QED

Theorem eval_exps_LENGTH[local]:
  ∀es s vs s1. eval_exps es s = (Cont vs,s1) ⇒ LENGTH vs = LENGTH es
Proof
  Induct \\ simp [bind_def, AllCaseEqs()] \\ rw [] \\ res_tac \\ gvs []
QED

Theorem HD_REVERSE[local]:
  ∀l. l ≠ [] ⇒ HD (REVERSE l) = LAST l
Proof
  ho_match_mp_tac listTheory.SNOC_INDUCT \\ rw []
  \\ gvs [listTheory.REVERSE_SNOC, listTheory.LAST_SNOC]
QED

(* The last argument is the one left in RAX. *)
Theorem has_stack_LAST[local]:
  ∀t ws zs w.
    has_stack t (MAP Word (REVERSE ws) ⧺ zs) ∧ ws ≠ [] ∧
    t.regs RAX = SOME w ⇒
    LAST ws = w
Proof
  rw [has_stack_def]
  \\ ‘HD (REVERSE ws) = LAST ws’ by simp [HD_REVERSE]
  \\ Cases_on ‘REVERSE ws’ \\ gvs []
QED

(* ... so the callee's frame really does start with the word in RAX. *)
Theorem args_frame[local]:
  ∀ws w.
    (ws ≠ [] ⇒ LAST ws = w) ⇒
    ∃ys. (if ws = [] then [Word w] else MAP Word (REVERSE ws)) = Word w :: ys
Proof
  rw []
  \\ ‘HD (REVERSE ws) = LAST ws’ by simp [HD_REVERSE]
  \\ Cases_on ‘REVERSE ws’ \\ gvs []
QED

Theorem write_regs_not_MEM[local]:
  ∀ws rs rgs r. ¬MEM r rs ⇒ write_regs ws rs rgs r = rgs r
Proof
  Induct \\ Cases_on ‘rs’
  \\ gvs [write_regs_def, write_reg_map_def] \\ rw []
QED

(* c_pops only ever writes the argument registers. *)
Theorem pops_regs_other[local]:
  ∀ws rgs r. ¬MEM r ARGS_REGS ⇒ pops_regs ws rgs r = rgs r
Proof
  rw [pops_regs_def] \\ CASE_TAC \\ gvs []
  \\ irule write_regs_not_MEM
  \\ strip_tac \\ imp_res_tac listTheory.MEM_REVERSE
  \\ imp_res_tac rich_listTheory.MEM_TAKE \\ gvs []
QED

Theorem prefix_trans:
  ∀s1 s2 s3.
    isPREFIX s1 s2 ⇒ isPREFIX s2 s3 ⇒ isPREFIX s1 s3
Proof
  metis_tac [rich_listTheory.IS_PREFIX_TRANS]
QED

Theorem give_up:
  ∀fs ds t w n.
    code_rel fs ds t.instructions ∧
    t.regs R15 = SOME w ∧
    t.pc = give_up (ODD (LENGTH t.stack)) ⇒
    steps (State t, n) (Halt 4w t.output, n)
Proof
  rw [code_rel_def, init_code_in_def, init_def, code_in_def, give_up_def]
  >- (* odd stack: the Push at 15 realigns it first *)
   (ntac 2 (irule steps_trans \\ irule_at (Pos hd) (cj 2 steps_rules)
            \\ simp [Once step_cases, fetch_def, PULL_EXISTS,
                     inc_def, set_stack_def, write_reg_def,
                     combinTheory.APPLY_UPDATE_THM])
    \\ irule (cj 2 steps_rules)
    \\ simp [Once step_cases, fetch_def, PULL_EXISTS,
             inc_def, set_stack_def, write_reg_def,
             combinTheory.APPLY_UPDATE_THM, EVEN, ODD, EVEN_ODD])
  \\ irule steps_trans \\ irule_at (Pos hd) (cj 2 steps_rules)
  \\ simp [Once step_cases, fetch_def, PULL_EXISTS,
           inc_def, write_reg_def, combinTheory.APPLY_UPDATE_THM]
  \\ irule (cj 2 steps_rules)
  \\ simp [Once step_cases, fetch_def, PULL_EXISTS,
           inc_def, write_reg_def, combinTheory.APPLY_UPDATE_THM,
           EVEN, ODD, EVEN_ODD]
QED

Theorem state_rel_R14[local]:
  ∀fs s t. state_rel fs s t ⇒ ∃w. t.regs R14 = SOME w
Proof
  rw [state_rel_def] \\ metis_tac []
QED

Theorem heap_ok_update[local]:
  ∀r14 r15 m ad w.
    heap_ok r14 r15 m ∧ ad <+ r14 ⇒
    heap_ok r14 r15 ((ad =+ SOME (SOME w)) m)
Proof
  rewrite_tac [heap_ok_def]
  \\ rpt gen_tac \\ strip_tac \\ fs []
  \\ rpt strip_tac \\ res_tac
  \\ ‘a ≠ ad’ by (strip_tac \\ gvs [WORD_LO, WORD_LS])
  \\ fs [x64asm_semanticsTheory.can_write_mem_at_def,
         combinTheory.APPLY_UPDATE_THM]
QED

Theorem state_rel_IMP[local]:
  ∀fs s t.
    state_rel fs s t ⇒
    s.input = t.input ∧ s.output = t.output ∧
    ∃r14 r15.
      t.regs R14 = SOME r14 ∧ t.regs R15 = SOME r15 ∧ heap_ok r14 r15 t.memory
Proof
  rw [state_rel_def] \\ metis_tac []
QED

Theorem state_rel_step[local]:
  ∀fs s t1 t2 s'.
    state_rel fs s t1 ∧
    s'.input = t2.input ∧ s'.output = t2.output ∧ s'.funs = s.funs ∧
    t2.instructions = t1.instructions ∧
    t2.regs R12 = t1.regs R12 ∧ t2.regs R13 = t1.regs R13 ∧
    (∃r14 r15.
       t2.regs R14 = SOME r14 ∧ t2.regs R15 = SOME r15 ∧
       heap_ok r14 r15 t2.memory) ⇒
    state_rel fs s' t2
Proof
  rw [state_rel_def] \\ metis_tac []
QED

(* An odd-length frame is non-empty, and its first slot is the word held in
   RAX.  Every command case that touches the frame starts by splitting it. *)
Theorem has_stack_cons[local]:
  ∀t curr rest.
    has_stack t (curr ⧺ rest) ∧ ODD (LENGTH curr) ⇒
    ∃hw ct. curr = Word hw :: ct
Proof
  Cases_on ‘curr’ \\ rw [has_stack_def] \\ gvs []
QED

Theorem has_stack_LENGTH[local]:
  ∀t xs. has_stack t xs ⇒ LENGTH xs = SUC (LENGTH t.stack)
Proof
  rw [has_stack_def] \\ gvs []
QED

Theorem has_stack_ODD[local]:
  ∀t curr rest.
    has_stack t (curr ++ rest) ∧ ODD (LENGTH curr) ∧ ODD (LENGTH rest) ⇒
    ODD (LENGTH t.stack)
Proof
  rw [has_stack_def] \\ gvs []
  \\ qpat_x_assum ‘curr ⧺ rest = _’ (mp_tac o Q.AP_TERM ‘LENGTH’)
  \\ strip_tac
  \\ ‘EVEN (LENGTH curr + LENGTH rest)’ by fs [EVEN_ADD, ODD_EVEN]
  \\ gvs [EVEN, ODD_EVEN]
QED

Theorem abortLoc_thm:
  ∀fs ds t w n.
    code_rel fs ds t.instructions ∧
    t.regs R15 = SOME w ∧
    ODD (LENGTH t.stack) ∧
    t.pc = AbortLoc ⇒
    steps (State t, n) (Halt 1w t.output, n)
Proof
  rw [code_rel_def, init_code_in_def, init_def, code_in_def]
  \\ ntac 2 (irule steps_trans \\ irule_at (Pos hd) (cj 2 steps_rules)
             \\ simp [Once step_cases, fetch_def, PULL_EXISTS,
                      inc_def, set_stack_def, write_reg_def, combinTheory.APPLY_UPDATE_THM])
  \\ irule (cj 2 steps_rules)
  \\ simp [Once step_cases, fetch_def, PULL_EXISTS,
           inc_def, set_stack_def, write_reg_def, combinTheory.APPLY_UPDATE_THM,
           EVEN, ODD, EVEN_ODD]
QED

Theorem code_in_append:
  ∀xs ys n code.
    code_in n (xs ++ ys) code ⇔
    code_in n xs code ∧ code_in (n + LENGTH xs) ys code
Proof
  Induct \\ fs [code_in_def, ADD1, AC ADD_ASSOC ADD_COMM]
  \\ metis_tac []
QED

val code_layout =
  [flatten_append, flatten_def, code_in_append, code_in_def, LENGTH_flatten];

Theorem oEL_APPEND_LENGTH:
  ∀xs l. oEL (LENGTH xs) (xs ++ l) = oEL 0 l
Proof
  Induct \\ fs [listTheory.oEL_def]
QED

Theorem code_in_append_middle:
  ∀ys xs zs k. k = LENGTH xs ⇒ code_in k ys (xs ++ ys ++ zs)
Proof
  Induct \\ fs [code_in_def] \\ rw []
  >- (full_simp_tac std_ss [GSYM APPEND_ASSOC, APPEND]
      \\ fs [oEL_APPEND_LENGTH, listTheory.oEL_def])
  \\ first_x_assum (qspec_then ‘xs ⧺ [h]’ mp_tac)
  \\ fs [] \\ full_simp_tac std_ss [GSYM APPEND_ASSOC, APPEND]
QED

Theorem lookup_eq_ALOOKUP:
  ∀fs n pos. ALOOKUP fs n = SOME pos ⇒ lookup n fs = pos
Proof
  Induct \\ fs [] \\ Cases \\ rw [Once lookup_def]
QED

(* c_fundefs lays each function's code out at the position it records for
   that function in the returned f_lookup table. *)
Theorem c_fundefs_code_in:
  ∀ds l fs c fs1 l1 pre n params body.
    c_fundefs ds l fs = (c,fs1,l1) ∧ l = LENGTH pre ∧
    find_fun n ds = SOME (params,body) ⇒
    ∃pos.
      ALOOKUP fs1 n = SOME pos ∧
      code_in pos (flatten (FST (c_fundef (Func n params body) pos fs)) [])
              (pre ++ flatten c [])
Proof
  Induct \\ simp [Once c_fundefs_def] \\ Cases \\ rpt gen_tac
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs [find_fun_def, AllCaseEqs()]
  \\ imp_res_tac c_fundef_length
  >- (fs [flatten_append, flatten_def]
      \\ ‘pre ⧺ Comment (N2ascii n)::(flatten c1 [] ⧺ [Ret] ⧺ flatten c2 []) =
          (pre ⧺ [Comment (N2ascii n)]) ⧺ flatten c1 [] ⧺
          ([Ret] ⧺ flatten c2 [])’ by fs []
      \\ pop_assum (rewrite_tac o single)
      \\ irule code_in_append_middle \\ fs [])
  \\ last_x_assum (qspecl_then
       [‘fs’,‘c2’,‘fs'’,‘l1’,
        ‘pre ⧺ [Comment (N2ascii n)] ⧺ flatten c1 [] ⧺ [Ret]’,
        ‘n'’,‘params’,‘body’] mp_tac)
  \\ impl_tac >- fs [LENGTH_flatten]
  \\ strip_tac
  \\ qexists_tac ‘pos’
  \\ fs [flatten_append, flatten_def]
  \\ full_simp_tac std_ss [GSYM APPEND_ASSOC, APPEND]
QED

(* Both passes of c_fundefs lay the code out identically, so the table the
   first pass computes really does say where the second pass put each
   function -- which is exactly what code_rel asserts. *)
Theorem codegen_code_rel[local]:
  ∀ds l fs c0 m0 c t1 m1 pre start.
    c_fundefs ds l [] = (c0,fs,m0) ∧
    c_fundefs ds l fs = (c,t1,m1) ∧
    l = LENGTH pre ∧
    code_in 0 (init start) (pre ⧺ flatten c []) ⇒
    code_rel fs ds (pre ⧺ flatten c [])
Proof
  rw [code_rel_def]
  >- (simp [init_code_in_def] \\ metis_tac [])
  \\ qpat_x_assum ‘c_fundefs ds (LENGTH pre) [] = _’ assume_tac
  \\ drule c_fundefs_code_in
  \\ disch_then (qspecl_then [‘pre’,‘n’,‘params’,‘body’] mp_tac)
  \\ simp [] \\ strip_tac
  \\ qexists_tac ‘pos’ \\ simp []
  \\ qpat_x_assum ‘c_fundefs ds (LENGTH pre) fs = _’ assume_tac
  \\ drule c_fundefs_code_in
  \\ disch_then (qspecl_then [‘pre’,‘n’,‘params’,‘body’] mp_tac)
  \\ simp [] \\ strip_tac
  \\ ‘pos' = pos’ by
   (qspecl_then [‘ds’,‘LENGTH pre’,‘[]’,‘fs’,‘c0’,‘fs’,‘m0’,‘c’,‘t1’,‘m1’]
      mp_tac c_fundefs_11
    \\ simp [] \\ strip_tac \\ gvs []
    \\ imp_res_tac ALOOKUP_SOME_APPEND \\ gvs [])
  \\ gvs []
QED

Theorem v_inv_pmap_subsume:
  ∀pmap pmap1 v w.
    v_inv pmap v w ∧ pmap_subsume pmap pmap1 ⇒ v_inv pmap1 v w
Proof
  Cases_on ‘v’ \\ rw [v_inv_def, pmap_subsume_def] \\ metis_tac []
QED

Theorem env_ok_pmap_subsume:
  ∀vars vs curr pmap pmap1.
    env_ok vars vs curr pmap ∧ pmap_subsume pmap pmap1 ⇒
    env_ok vars vs curr pmap1
Proof
  rw [env_ok_def] \\ res_tac \\ metis_tac [v_inv_pmap_subsume]
QED

Theorem index_of_shift:
  ∀vs n k. index_of n (k + 1) vs = index_of n k vs + 1
Proof
  Induct \\ once_rewrite_tac [index_of_def] \\ simp []
  \\ Cases_on ‘h’ \\ simp [] \\ rw []
QED

(* Compiling a nested expression extends the frame with one scratch slot. *)
Theorem env_ok_NONE:
  ∀env vs curr pmap x.
    env_ok env vs curr pmap ⇒ env_ok env (NONE::vs) (x::curr) pmap
Proof
  rw [env_ok_def] \\ res_tac
  \\ ‘index_of n 0 (NONE::vs) = index_of n 0 vs + 1’ by
       simp [Once index_of_def, index_of_shift]
  \\ simp [listTheory.oEL_def] \\ metis_tac []
QED

(* index_of really does point at the variable's own slot in vs. *)
Theorem index_of_oEL[local]:
  ∀vs n.
    MEM (SOME n) vs ⇒
    index_of n 0 vs < LENGTH vs ∧ oEL (index_of n 0 vs) vs = SOME (SOME n)
Proof
  Induct \\ simp []
  \\ Cases_on ‘h’ \\ simp []
  >- (rw [] \\ res_tac
      \\ ‘index_of n 0 (NONE::vs) = index_of n 0 vs + 1’ by
           simp [Once index_of_def, index_of_shift]
      \\ simp [listTheory.oEL_def])
  \\ gen_tac
  \\ reverse (Cases_on ‘x = n’) \\ simp []
  >- (strip_tac \\ res_tac
      \\ ‘index_of n 0 (SOME x::vs) = index_of n 0 vs + 1’ by
           simp [Once index_of_def, index_of_shift]
      \\ simp [listTheory.oEL_def])
  \\ once_rewrite_tac [index_of_def] \\ simp [listTheory.oEL_def]
QED

(* Distinct variables occupy distinct slots. *)
Theorem index_of_11[local]:
  ∀vs n1 n2.
    MEM (SOME n1) vs ∧ MEM (SOME n2) vs ∧
    index_of n1 0 vs = index_of n2 0 vs ⇒ n1 = n2
Proof
  rpt strip_tac \\ imp_res_tac index_of_oEL \\ gvs []
QED

(* Writing v into the slot of n is exactly what c_assign does to the frame. *)
Theorem env_ok_assign[local]:
  ∀env vs curr pmap n v w.
    env_ok env vs curr pmap ∧ MEM (SOME n) vs ∧ v_inv pmap v w ⇒
    env_ok (env |+ (n,v)) vs (LUPDATE (Word w) (index_of n 0 vs) curr) pmap
Proof
  rewrite_tac [env_ok_def] \\ rpt gen_tac \\ strip_tac
  \\ conj_tac >- simp []
  \\ rpt gen_tac \\ strip_tac
  \\ reverse (Cases_on ‘n' = n’)
  \\ gvs [finite_mapTheory.FLOOKUP_UPDATE]
  >- (res_tac
      \\ ‘index_of n' 0 vs ≠ index_of n 0 vs’ by metis_tac [index_of_11]
      \\ gvs [listTheory.oEL_THM, listTheory.EL_LUPDATE]
      \\ metis_tac [])
  \\ imp_res_tac index_of_oEL
  \\ gvs [listTheory.oEL_THM, listTheory.EL_LUPDATE]
  \\ metis_tac []
QED

Theorem index_of_CONS[local]:
  ∀h vs n.
    index_of n 0 (h::vs) = if h = SOME n then 0 else index_of n 0 vs + 1
Proof
  rpt gen_tac \\ Cases_on ‘h’
  >- simp [Once index_of_def, index_of_shift]
  \\ rw [] \\ simp [Once index_of_def, index_of_shift]
QED

(* Where index_of looks when the v_stack is extended on the right: inside the
   prefix if the name is there, otherwise past it. *)
Theorem index_of_APPEND[local]:
  ∀vs n extra.
    index_of n 0 (vs ⧺ extra) =
    if MEM (SOME n) vs then index_of n 0 vs
    else LENGTH vs + index_of n 0 extra
Proof
  Induct \\ simp []
  \\ rpt gen_tac \\ simp [index_of_CONS]
  \\ rw [] \\ gvs []
QED

(* Slots added past the end of the frame are invisible to the variables that
   are already in it. *)
Theorem env_ok_APPEND[local]:
  ∀env vs curr pmap vs2 curr2.
    env_ok env vs curr pmap ∧ LENGTH vs2 = LENGTH curr2 ⇒
    env_ok env (vs ⧺ vs2) (curr ⧺ curr2) pmap
Proof
  rw [env_ok_def] \\ res_tac \\ simp [index_of_APPEND]
  \\ qexists_tac ‘w’ \\ simp []
  \\ gvs [listTheory.oEL_THM, rich_listTheory.EL_APPEND1, AllCaseEqs()]
QED

Theorem call_v_stack_thm[local]:
  ∀ps acc. call_v_stack ps acc = REVERSE (MAP SOME ps) ⧺ acc
Proof
  Induct \\ simp [Once call_v_stack_def]
QED

(* FEMPTY |++ l is just the association list, read left to right, when the
   keys are distinct. *)
Theorem FLOOKUP_alist[local]:
  ∀l n.
    ALL_DISTINCT (MAP FST l) ⇒
    FLOOKUP (FEMPTY |++ l) n = alist$ALOOKUP l n
Proof
  rpt strip_tac
  \\ simp [alistTheory.FLOOKUP_FUPDATE_LIST]
  \\ drule alistTheory.alookup_distinct_reverse
  \\ disch_then (fn th => simp [th])
  \\ CASE_TAC \\ fs []
QED

(* The frame the callee's entry code builds really does hold the arguments in
   the slots push_vs names. *)
Theorem env_ok_ZIP[local]:
  ∀ps args ws pmap.
    LIST_REL (v_inv pmap) args ws ∧ LENGTH ps = LENGTH ws ∧ ALL_DISTINCT ps ⇒
    env_ok (FEMPTY |++ ZIP (ps,args))
           (REVERSE (MAP SOME ps)) (REVERSE (MAP Word ws)) pmap
Proof
  Induct
  >- (rw [env_ok_def] \\ gvs [finite_mapTheory.FUPDATE_LIST_THM])
  \\ rpt gen_tac \\ strip_tac
  \\ ‘∃wv ws'. ws = wv::ws'’ by (Cases_on ‘ws’ \\ gvs [])
  \\ gvs []
  \\ rename [‘v_inv pmap a wv’]
  \\ rename [‘LIST_REL (v_inv pmap) args' ws'’]
  \\ first_x_assum (qspecl_then [‘args'’,‘ws'’,‘pmap’] mp_tac)
  \\ impl_tac >- gvs []
  \\ strip_tac
  \\ imp_res_tac listTheory.LIST_REL_LENGTH
  \\ simp [env_ok_def]
  \\ rpt gen_tac \\ strip_tac
  \\ ‘LENGTH ps = LENGTH args'’ by gvs []
  \\ ‘ALL_DISTINCT (MAP FST (ZIP (ps,args'))) ∧
      ALL_DISTINCT (MAP FST ((h,a)::ZIP (ps,args')))’ by
       simp [listTheory.MAP_ZIP]
  \\ gvs [FLOOKUP_alist]
  \\ reverse (Cases_on ‘h = n’) \\ gvs []
  >- (* one of the later parameters: it sits in the prefix of the frame *)
   (‘FLOOKUP (FEMPTY |++ ZIP (ps,args')) n = SOME v’ by simp [FLOOKUP_alist]
    \\ qpat_x_assum ‘env_ok _ _ _ _’ mp_tac
    \\ rewrite_tac [env_ok_def] \\ strip_tac
    \\ res_tac
    \\ simp [index_of_APPEND]
    \\ gvs [listTheory.oEL_THM, rich_listTheory.EL_APPEND1, AllCaseEqs()]
    \\ metis_tac [])
  (* this parameter: it is the slot the entry code just filled *)
  \\ ‘¬MEM (SOME h) (REVERSE (MAP SOME ps))’ by
       (gvs [listTheory.MEM_MAP] \\ metis_tac [])
  \\ simp [index_of_APPEND, index_of_CONS]
  \\ qexists_tac ‘wv’ \\ simp []
  \\ gvs [listTheory.oEL_THM, rich_listTheory.EL_APPEND2]
QED

Theorem pmap_subsume_refl:
  ∀pmap. pmap_subsume pmap pmap
Proof
  rw [pmap_subsume_def]
QED

Theorem pmap_subsume_trans:
  ∀pmap1 pmap2 pmap3.
    pmap_subsume pmap1 pmap2 ∧ pmap_subsume pmap2 pmap3 ⇒
    pmap_subsume pmap1 pmap3
Proof
  rw [pmap_subsume_def]
QED

Theorem r14_mono_refl:
  ∀r14. r14_mono (SOME r14) (SOME r14)
Proof
  rw [r14_mono_def]
QED

Theorem r14_mono_trans:
  ∀r14a r14b r14c.
    r14_mono r14a r14b ∧ r14_mono r14b r14c ⇒ r14_mono r14a r14c
Proof
  rw [r14_mono_def] \\ metis_tac [WORD_LOWER_EQ_TRANS]
QED

Theorem r14_mono_IMP_pmap_in_bounds:
  ∀pmap mr14old r14old r14new.
    pmap_in_bounds pmap (SOME r14old) ∧
    r14_mono (SOME r14old) (SOME r14new) ⇒
    pmap_in_bounds pmap (SOME r14new)
Proof
  rw [pmap_in_bounds_def, r14_mono_def] \\ res_tac
  \\ Cases_on ‘r14old’ \\ gvs []
  \\ Cases_on ‘r14new’ \\ gvs []
  \\ gvs [WORD_LO, WORD_LS]
QED

Theorem steps_unroll:
  step s1 s2 ∧ steps (s2,n) (s3,n) ⇒ steps (s1,n) (s3,n)
Proof
  rw [] \\ simp [Once steps_cases]
  \\ rpt disj2_tac
  \\ pop_assum $ irule_at Any
  \\ simp [Once steps_cases]
QED

Theorem step_IMP_steps:
  step s1 s2 ⇒ steps (s1,n) (s2,n)
Proof
  rw [] \\ simp [Once steps_cases]
QED

(* As steps_unroll, but leaving the fuel of the final configuration free:
   needed where the number of steps still to come is not yet determined. *)
Theorem steps_unroll_any:
  step s1 s2 ∧ steps (s2,n) x ⇒ steps (s1,n) x
Proof
  rw [] \\ irule steps_trans
  \\ irule_at Any step_IMP_steps
  \\ metis_tac []
QED

(* ------------------------------------------------------------------ *)
(* Writing a heap cell (used by Update)                                *)
(* ------------------------------------------------------------------ *)

Theorem write_mem_allocated[local]:
  ∀pmap impm p base blk off w t.
    mem_inv pmap t.memory impm ∧
    pmap p = SOME (base, LENGTH blk) ∧
    oEL p impm = SOME blk ∧
    off < LENGTH blk ⇒
    write_mem (base + n2w (off * 8)) w t =
      SOME (t with memory := ((base + n2w (off * 8)) =+ SOME (SOME w)) t.memory)
Proof
  rpt gen_tac \\ strip_tac
  \\ qpat_x_assum ‘mem_inv _ _ _’ mp_tac
  \\ rewrite_tac [mem_inv_def]
  \\ disch_then (qspecl_then [‘p’,‘blk’] mp_tac)
  \\ simp [] \\ strip_tac \\ gvs []
  \\ first_x_assum (qspecl_then [‘off’,‘EL off blk’] mp_tac)
  \\ simp [listTheory.oEL_THM] \\ strip_tac
  \\ gvs [x64asm_semanticsTheory.write_mem_def]
QED

Theorem c_store_step[local]:
  ∀t pmap impm p base blk off w.
    fetch t = SOME (Store RAX RDI 0w) ∧
    t.regs RDI = SOME (base + n2w (off * 8)) ∧
    t.regs RAX = SOME w ∧
    mem_inv pmap t.memory impm ∧
    pmap p = SOME (base, LENGTH blk) ∧
    oEL p impm = SOME blk ∧
    off < LENGTH blk ⇒
    step (State t)
         (State (inc (t with memory :=
                        ((base + n2w (off * 8)) =+ SOME (SOME w)) t.memory)))
Proof
  rpt strip_tac
  \\ qspecl_then [‘pmap’,‘impm’,‘p’,‘base’,‘blk’,‘off’,‘w’,‘t’]
       mp_tac write_mem_allocated
  \\ simp [] \\ strip_tac
  \\ qspecl_then [‘t’,‘RAX’,‘RDI’,‘0w’,‘base + n2w (off * 8)’,‘w’,
                  ‘t with memory :=
                     ((base + n2w (off * 8)) =+ SOME (SOME w)) t.memory’]
       mp_tac (cj 15 step_rules)
  \\ fs []
QED

(* pmap_ok, in the form the Update proof wants it: two live addresses that
   coincide come from the same block and the same offset. *)
Theorem pmap_ok_addr_11[local]:
  ∀pmap p1 p2 base1 len1 base2 len2 n1 n2.
    pmap_ok pmap ∧
    pmap p1 = SOME (base1,len1) ∧ pmap p2 = SOME (base2,len2) ∧
    n1 < len1 ∧ n2 < len2 ∧
    base1 + n2w (n1 * 8) = base2 + n2w (n2 * 8) ⇒
    p1 = p2 ∧ n1 = n2
Proof
  rw [pmap_ok_def] \\ res_tac \\ fs []
QED

(* Updating one slot of one block keeps mem_inv: the written address gets the
   new value, and pmap_ok says no other live address aliases it. *)
Theorem mem_inv_update[local]:
  ∀pmap m impm p base blk off v w.
    mem_inv pmap m impm ∧
    pmap_ok pmap ∧
    pmap p = SOME (base, LENGTH blk) ∧
    oEL p impm = SOME blk ∧
    off < LENGTH blk ∧
    v_inv pmap v w ⇒
    mem_inv pmap (((base + n2w (off * 8)) =+ SOME (SOME w)) m)
            (LUPDATE (LUPDATE (SOME v) off blk) p impm)
Proof
  rpt gen_tac \\ strip_tac
  \\ rewrite_tac [mem_inv_def] \\ rpt gen_tac \\ strip_tac
  \\ reverse (Cases_on ‘p' = p’)
  >-
   (‘oEL p' impm = SOME v'’ by
      (gvs [listTheory.oEL_THM, listTheory.EL_LUPDATE] \\ gvs [])
    \\ qpat_x_assum ‘mem_inv _ _ _’ mp_tac
    \\ rewrite_tac [mem_inv_def] \\ strip_tac
    \\ first_x_assum drule \\ strip_tac \\ gvs []
    \\ rpt strip_tac \\ first_x_assum drule \\ strip_tac
    \\ ‘off' < LENGTH v'’ by gvs [listTheory.oEL_THM, AllCaseEqs()]
    \\ ‘base' + n2w (off' * 8) ≠ base + n2w (off * 8)’ by
         (strip_tac \\ metis_tac [pmap_ok_addr_11])
    \\ gvs [combinTheory.APPLY_UPDATE_THM])
  \\ gvs []
  \\ ‘p < LENGTH impm’ by gvs [listTheory.oEL_THM, AllCaseEqs()]
  \\ ‘v' = LUPDATE (SOME v) off blk’ by
       gvs [listTheory.oEL_THM, listTheory.EL_LUPDATE]
  \\ gvs []
  \\ rpt strip_tac
  \\ ‘off' < LENGTH blk’ by gvs [listTheory.oEL_THM, AllCaseEqs()]
  \\ reverse (Cases_on ‘off' = off’)
  >-
   (‘oEL off' blk = SOME xopt’ by
      gvs [listTheory.oEL_THM, listTheory.EL_LUPDATE]
    \\ qpat_x_assum ‘mem_inv _ _ _’ mp_tac
    \\ rewrite_tac [mem_inv_def] \\ strip_tac
    \\ first_x_assum drule \\ strip_tac \\ gvs []
    \\ first_x_assum drule \\ strip_tac
    \\ ‘base + n2w (off' * 8) ≠ base + n2w (off * 8)’ by
         (strip_tac \\ metis_tac [pmap_ok_addr_11])
    \\ gvs [combinTheory.APPLY_UPDATE_THM])
  \\ gvs [listTheory.oEL_THM, listTheory.EL_LUPDATE,
          combinTheory.APPLY_UPDATE_THM]
QED

(* LUPDATE keeps the length, so every block pmap knows about is still there. *)
Theorem pmap_in_memory_LUPDATE[local]:
  ∀pmap impm p x.
    pmap_in_memory pmap impm ⇒ pmap_in_memory pmap (LUPDATE x p impm)
Proof
  rw [pmap_in_memory_def] \\ res_tac
  \\ gvs [listTheory.oEL_THM, AllCaseEqs()]
QED

(* ------------------------------------------------------------------ *)
(* Heap arithmetic for Alloc                                           *)
(* ------------------------------------------------------------------ *)

Theorem w2n_add_no_wrap[local]:
  ∀(a:word64) (b:word64) (c:word64).
    w2n a + w2n b ≤ w2n c ⇒ w2n (a + b) = w2n a + w2n b
Proof
  Cases \\ Cases \\ Cases
  \\ fs [wordsTheory.word_add_n2w, arithmeticTheory.LESS_MOD]
QED

Theorem w2n_not_zero[local]:
  ∀w:word64. w ≠ 0w ⇒ 0 < w2n w
Proof
  Cases \\ fs []
QED

(* Bumping R14 past a freshly handed out block keeps the heap invariant. *)
Theorem heap_ok_alloc[local]:
  ∀r14 r15 m len.
    heap_ok r14 r15 m ∧ w2n len MOD 8 = 0 ∧
    w2n r14 + w2n len ≤ w2n r15 ⇒
    w2n (r14 + len) = w2n r14 + w2n len ∧
    r14 <=+ r14 + len ∧
    heap_ok (r14 + len) r15 m
Proof
  rpt gen_tac \\ strip_tac
  \\ ‘w2n (r14 + len) = w2n r14 + w2n len’ by
       (irule w2n_add_no_wrap \\ qexists_tac ‘r15’ \\ fs [])
  \\ ‘0 < w2n r14’ by (irule w2n_not_zero \\ fs [heap_ok_def])
  \\ ‘w2n r14 MOD 8 = 0’ by fs [heap_ok_def, alignmentTheory.aligned_w2n]
  \\ simp [WORD_LS]
  \\ qpat_assum ‘heap_ok _ _ _’ mp_tac
  \\ rewrite_tac [heap_ok_def] \\ strip_tac
  \\ simp [heap_ok_def, WORD_LS]
  \\ rpt conj_tac
  >- fs [WORD_LS]
  >- (fs [alignmentTheory.aligned_w2n] \\ irule MOD8_ADD \\ fs [])
  >- (strip_tac \\ gvs [wordsTheory.w2n_eq_0])
  \\ rpt strip_tac \\ first_x_assum irule \\ fs [WORD_LS]
QED

Theorem addr_disjoint[local]:
  ∀(a:word64) b c. a <=+ b ∧ c <+ a ⇒ b ≠ c
Proof
  rw [WORD_LO, WORD_LS] \\ strip_tac \\ gvs []
QED

Theorem w2n_n2w_le[local]:
  ∀(c:word64) n. n ≤ w2n c ⇒ w2n (n2w n : word64) = n
Proof
  Cases \\ rw [wordsTheory.w2n_n2w, arithmeticTheory.LESS_MOD]
  \\ ‘dimword (:64) = 18446744073709551616’ by EVAL_TAC
  \\ fs []
QED

Theorem alloc_pmap[local]:
  ∀pmap pmap1 m impm r14 r15 len k.
    pmap1 = (λq. if q = LENGTH impm then SOME (r14,k) else pmap q) ∧
    mem_inv pmap m impm ∧
    pmap_in_memory pmap impm ∧
    pmap_ok pmap ∧
    pmap_in_bounds pmap (SOME r14) ∧
    heap_ok r14 r15 m ∧
    w2n len = 8 * k ∧
    w2n r14 + w2n len ≤ w2n r15 ⇒
    pmap_subsume pmap pmap1 ∧
    pmap_ok pmap1 ∧
    mem_inv pmap1 m (impm ⧺ [REPLICATE k NONE]) ∧
    pmap_in_memory pmap1 (impm ⧺ [REPLICATE k NONE]) ∧
    pmap_in_bounds pmap1 (SOME (r14 + len)) ∧
    v_inv pmap1 (Pointer (LENGTH impm)) r14
Proof
  rpt gen_tac \\ strip_tac
  \\ ‘w2n len MOD 8 = 0’ by fs []
  \\ ‘w2n (r14 + len) = w2n r14 + w2n len ∧ r14 <=+ r14 + len’ by
       metis_tac [heap_ok_alloc]
  \\ ‘w2n r14 MOD 8 = 0’ by fs [heap_ok_def, alignmentTheory.aligned_w2n]
  (* the fresh block index is outside pmap's domain *)
  \\ ‘pmap (LENGTH impm) = NONE’ by
       (Cases_on ‘pmap (LENGTH impm)’ \\ simp []
        \\ PairCases_on ‘x’
        \\ qpat_x_assum ‘pmap_in_memory _ _’ mp_tac
        \\ rewrite_tac [pmap_in_memory_def]
        \\ disch_then (qspecl_then [‘LENGTH impm’,‘x1’,‘x0’] mp_tac)
        \\ simp [listTheory.oEL_THM])
  (* every block pmap already knows about lies strictly below r14 *)
  \\ ‘∀q base l j. pmap q = SOME (base,l) ∧ j < l ⇒ base + n2w (j * 8) <+ r14’ by
       (rpt strip_tac
        \\ qpat_x_assum ‘pmap_in_bounds pmap (SOME r14)’ mp_tac
        \\ rewrite_tac [pmap_in_bounds_def]
        \\ disch_then (qspecl_then [‘q’,‘base’,‘l’,‘r14’] mp_tac)
        \\ fs [])
  (* the addresses of the new block *)
  \\ ‘∀i. i < k ⇒
        w2n (n2w (i * 8) : word64) = i * 8 ∧
        w2n (r14 + n2w (i * 8)) = w2n r14 + i * 8 ∧
        r14 <=+ r14 + n2w (i * 8) ∧
        r14 + n2w (i * 8) <+ r15 ∧
        r14 + n2w (i * 8) <+ r14 + len ∧
        aligned 3 (r14 + n2w (i * 8))’ by
       (gen_tac \\ strip_tac
        \\ ‘i * 8 ≤ w2n r15’ by fs []
        \\ ‘w2n (n2w (i * 8) : word64) = i * 8’ by
             (irule w2n_n2w_le \\ metis_tac [])
        \\ ‘w2n (r14 + n2w (i * 8)) = w2n r14 + i * 8’ by
             (‘w2n (r14 + n2w (i * 8)) =
               w2n r14 + w2n (n2w (i * 8) : word64)’ by
                (irule w2n_add_no_wrap \\ qexists_tac ‘r15’ \\ fs [])
              \\ fs [])
        \\ ‘(w2n r14 + i * 8) MOD 8 = 0’ by (irule MOD8_ADD \\ fs [])
        \\ fs [WORD_LO, WORD_LS, alignmentTheory.aligned_w2n])
  \\ rpt conj_tac
  >- (* pmap_subsume *)
   (gvs [pmap_subsume_def] \\ rw [] \\ gvs [])
  >- (* pmap_ok *)
   (rewrite_tac [pmap_ok_def] \\ rpt gen_tac \\ strip_tac
    \\ rpt gen_tac \\ strip_tac
    \\ Cases_on ‘p1 = LENGTH impm’ \\ Cases_on ‘p2 = LENGTH impm’ \\ gvs []
    >- (* p1 new, p2 old: the old address is below r14, the new one is not *)
     (‘base1 <=+ base1 + n2w (8 * n1)’ by
        (qpat_assum ‘∀i. i < k ⇒ _’ (qspec_then ‘n1’ mp_tac) \\ fs [])
      \\ ‘base2 + n2w (8 * n2) <+ base1’ by metis_tac []
      \\ metis_tac [addr_disjoint])
    >- (* p1 old, p2 new *)
     (‘base2 <=+ base2 + n2w (8 * n2)’ by
        (qpat_assum ‘∀i. i < k ⇒ _’ (qspec_then ‘n2’ mp_tac) \\ fs [])
      \\ ‘base1 + n2w (8 * n1) <+ base2’ by metis_tac []
      \\ metis_tac [addr_disjoint])
    \\ qpat_x_assum ‘pmap_ok pmap’ mp_tac
    \\ rewrite_tac [pmap_ok_def]
    \\ disch_then (qspecl_then [‘p1’,‘p2’,‘base1’,‘len1’,‘base2’,‘len2’] mp_tac)
    \\ simp []
    \\ disch_then (qspecl_then [‘n1’,‘n2’] mp_tac)
    \\ fs [])
  >- (* mem_inv *)
   (rewrite_tac [mem_inv_def] \\ rpt gen_tac \\ strip_tac
    \\ reverse (Cases_on ‘p = LENGTH impm’) \\ gvs []
    >- (* an old block: unchanged, and v_inv transfers along pmap_subsume *)
     (‘oEL p impm = SOME v’ by
        (gvs [listTheory.oEL_THM, rich_listTheory.EL_APPEND1, AllCaseEqs()])
      \\ qpat_x_assum ‘mem_inv pmap m impm’ mp_tac
      \\ rewrite_tac [mem_inv_def]
      \\ disch_then (qspecl_then [‘p’,‘v’] mp_tac)
      \\ simp [] \\ strip_tac
      \\ qexists_tac ‘base’ \\ simp []
      \\ rpt strip_tac \\ res_tac
      \\ qexists_tac ‘yopt’ \\ simp []
      \\ Cases_on ‘xopt’ \\ Cases_on ‘yopt’ \\ gvs []
      \\ irule v_inv_pmap_subsume
      \\ qexists_tac ‘pmap’ \\ gvs [pmap_subsume_def] \\ rw [] \\ gvs [])
    (* the new block: every cell is still uninitialised in the ASM memory *)
    \\ ‘v = REPLICATE k NONE’ by
         gvs [listTheory.oEL_THM, rich_listTheory.EL_APPEND2]
    \\ gvs []
    \\ rpt strip_tac
    \\ ‘off < k’ by gvs [listTheory.oEL_THM, AllCaseEqs()]
    \\ ‘xopt = NONE’ by gvs [listTheory.oEL_THM, rich_listTheory.EL_REPLICATE]
    \\ res_tac
    \\ ‘can_write_mem_at m (r14 + n2w (off * 8))’ by
         (qpat_x_assum ‘heap_ok r14 r15 m’ mp_tac
          \\ rewrite_tac [heap_ok_def] \\ strip_tac
          \\ first_x_assum irule \\ fs [])
    \\ gvs [x64asm_semanticsTheory.can_write_mem_at_def])
  >- (* pmap_in_memory *)
   (rewrite_tac [pmap_in_memory_def] \\ rpt gen_tac \\ strip_tac
    \\ Cases_on ‘p = LENGTH impm’ \\ gvs []
    >- (qexists_tac ‘REPLICATE k NONE’
        \\ gvs [listTheory.oEL_THM, rich_listTheory.EL_APPEND2])
    \\ qpat_x_assum ‘pmap_in_memory pmap impm’ mp_tac
    \\ rewrite_tac [pmap_in_memory_def]
    \\ disch_then (qspecl_then [‘p’,‘l’,‘base’] mp_tac)
    \\ simp [] \\ strip_tac
    \\ gvs [listTheory.oEL_THM, rich_listTheory.EL_APPEND1, AllCaseEqs()])
  >- (* pmap_in_bounds *)
   (rewrite_tac [pmap_in_bounds_def] \\ rpt gen_tac \\ strip_tac
    \\ Cases_on ‘p = LENGTH impm’ \\ gvs []
    >- (rpt strip_tac \\ res_tac \\ fs [heap_ok_def, WORD_LO, WORD_LS]
        \\ irule w2n_not_zero \\ fs [])
    \\ rpt strip_tac \\ res_tac
    >- (fs [WORD_LO, WORD_LS] \\ fs [heap_ok_def])
    \\ qpat_x_assum ‘pmap_in_bounds pmap (SOME r14)’ mp_tac
    \\ rewrite_tac [pmap_in_bounds_def]
    \\ disch_then (qspecl_then [‘p’,‘base’,‘len'’,‘r14’] mp_tac)
    \\ fs [])
  (* v_inv for the returned pointer *)
  \\ simp [v_inv_def]
QED

(* ------------------------------------------------------------------ *)
(* The malloc routine at AllocLoc (init_def)                           *)
(* ------------------------------------------------------------------ *)

Theorem alloc_steps[local]:
  ∀fs ds t len r14 r15 ret xs n.
    code_rel fs ds t.instructions ∧
    t.pc = AllocLoc ∧
    t.regs RDI = SOME len ∧
    t.regs R14 = SOME r14 ∧ t.regs R15 = SOME r15 ∧
    t.stack = RetAddr ret :: xs ∧
    EVEN (LENGTH xs) ∧
    heap_ok r14 r15 t.memory ⇒
    steps (State t,n) (Halt 4w t.output,n) ∨
    ∃t1.
      steps (State t,n) (State t1,n) ∧
      w2n r14 + w2n len ≤ w2n r15 ∧
      t1.pc = ret ∧ t1.stack = xs ∧
      t1.regs RAX = SOME r14 ∧ t1.regs R14 = SOME (r14 + len) ∧
      t1.regs R12 = t.regs R12 ∧ t1.regs R13 = t.regs R13 ∧
      t1.regs R15 = SOME r15 ∧
      t1.memory = t.memory ∧ t1.instructions = t.instructions ∧
      t1.input = t.input ∧ t1.output = t.output
Proof
  rpt gen_tac \\ strip_tac
  (* unfold the init block, but keep code_rel itself for the give-up case *)
  \\ qpat_assum ‘code_rel _ _ _’ mp_tac
  \\ rewrite_tac [code_rel_def, init_code_in_def]
  \\ strip_tac
  \\ fs [init_def, code_in_def]
  (* Mov RAX R15 *)
  \\ qabbrev_tac ‘ta = write_reg RAX r15 (inc t)’
  \\ ‘step (State t) (State ta)’ by
       (qunabbrev_tac ‘ta’ \\ irule (cj 2 step_rules)
        \\ fs [fetch_def])
  \\ ‘ta.pc = 8 ∧ ta.regs RAX = SOME r15 ∧ ta.regs R14 = SOME r14 ∧
      ta.regs R15 = SOME r15 ∧ ta.regs RDI = SOME len ∧
      ta.regs R12 = t.regs R12 ∧ ta.regs R13 = t.regs R13 ∧
      ta.instructions = t.instructions ∧ ta.stack = t.stack ∧
      ta.memory = t.memory ∧ ta.input = t.input ∧ ta.output = t.output’ by
       fs [Abbr‘ta’, write_reg_def, inc_def, combinTheory.APPLY_UPDATE_THM]
  (* Sub RAX R14: RAX is the size of the free area *)
  \\ qabbrev_tac ‘tb = write_reg RAX (r15 - r14) (inc ta)’
  \\ ‘step (State ta) (State tb)’ by
       (qunabbrev_tac ‘tb’ \\ irule (cj 4 step_rules)
        \\ fs [fetch_def])
  \\ ‘tb.pc = 9 ∧ tb.regs RAX = SOME (r15 - r14) ∧ tb.regs R14 = SOME r14 ∧
      tb.regs R15 = SOME r15 ∧ tb.regs RDI = SOME len ∧
      tb.regs R12 = t.regs R12 ∧ tb.regs R13 = t.regs R13 ∧
      tb.instructions = t.instructions ∧ tb.stack = t.stack ∧
      tb.memory = t.memory ∧ tb.input = t.input ∧ tb.output = t.output’ by
       fs [Abbr‘tb’, write_reg_def, inc_def, combinTheory.APPLY_UPDATE_THM]
  (* Jump (Less R15 R14) 15: never taken, because R14 <=+ R15 *)
  \\ ‘¬(w2n r15 < w2n r14)’ by fs [heap_ok_def, WORD_LS]
  \\ qabbrev_tac ‘tc = set_pc 10 tb’
  \\ ‘steps (State tb,n) (State tc,n)’ by
       (qspecl_then [‘tb’,‘Less R15 R14’,‘15’,‘n’,‘F’] mp_tac steps_Jump_cond
        \\ impl_tac
        >- (simp [fetch_def, Once take_branch_cases]
            \\ metis_tac [])
        \\ simp [Abbr‘tc’])
  \\ ‘tc.pc = 10 ∧ tc.regs RAX = SOME (r15 - r14) ∧ tc.regs R14 = SOME r14 ∧
      tc.regs R15 = SOME r15 ∧ tc.regs RDI = SOME len ∧
      tc.regs R12 = t.regs R12 ∧ tc.regs R13 = t.regs R13 ∧
      tc.instructions = t.instructions ∧ tc.stack = t.stack ∧
      tc.memory = t.memory ∧ tc.input = t.input ∧ tc.output = t.output’ by
       fs [Abbr‘tc’, set_pc_def]
  \\ ‘steps (State t,n) (State tc,n)’ by
       (irule steps_unroll \\ qexists_tac ‘State ta’ \\ conj_tac >- fs []
        \\ irule steps_unroll \\ qexists_tac ‘State tb’ \\ conj_tac >- fs []
        \\ fs [])
  (* Jump (Less RAX RDI) 15: the out-of-memory test *)
  \\ ‘steps (State tc,n)
        (State (set_pc (if w2n (r15 - r14) < w2n len then 15 else 11) tc),n)’ by
       (qspecl_then [‘tc’,‘Less RAX RDI’,‘15’,‘n’,
                     ‘w2n (r15 - r14) < w2n len’] mp_tac steps_Jump_cond
        \\ impl_tac
        >- (simp [fetch_def, Once take_branch_cases]
            \\ metis_tac [])
        \\ simp [])
  \\ ‘w2n (r15 - r14) = w2n r15 - w2n r14’ by
       (irule wordsTheory.word_sub_w2n \\ fs [heap_ok_def])
  \\ ‘w2n r14 ≤ w2n r15’ by fs [heap_ok_def, WORD_LS]
  \\ Cases_on ‘w2n (r15 - r14) < w2n len’ \\ fs []
  >- (* the free area is too small: fall into the give-up code *)
   (irule steps_trans \\ qexists_tac ‘(State (set_pc 15 tc),n)’
    \\ conj_tac >- metis_tac [steps_trans]
    \\ ‘t.output = (set_pc 15 tc).output’ by fs [set_pc_def]
    \\ pop_assum (fn th => once_rewrite_tac [th])
    \\ irule give_up
    \\ fs [set_pc_def, give_up_def, ODD, EVEN, ODD_EVEN]
    \\ metis_tac [])
  (* there is room: hand back R14 and bump it *)
  \\ disj2_tac
  \\ qabbrev_tac ‘td = set_pc 11 tc’
  \\ ‘td.pc = 11 ∧ td.regs RAX = SOME (r15 - r14) ∧ td.regs R14 = SOME r14 ∧
      td.regs R15 = SOME r15 ∧ td.regs RDI = SOME len ∧
      td.regs R12 = t.regs R12 ∧ td.regs R13 = t.regs R13 ∧
      td.instructions = t.instructions ∧ td.stack = t.stack ∧
      td.memory = t.memory ∧ td.input = t.input ∧ td.output = t.output’ by
       fs [Abbr‘td’, set_pc_def]
  (* Mov RAX R14 *)
  \\ qabbrev_tac ‘te = write_reg RAX r14 (inc td)’
  \\ ‘step (State td) (State te)’ by
       (qunabbrev_tac ‘te’ \\ irule (cj 2 step_rules)
        \\ fs [fetch_def])
  \\ ‘te.pc = 12 ∧ te.regs RAX = SOME r14 ∧ te.regs R14 = SOME r14 ∧
      te.regs R15 = SOME r15 ∧ te.regs RDI = SOME len ∧
      te.regs R12 = t.regs R12 ∧ te.regs R13 = t.regs R13 ∧
      te.instructions = t.instructions ∧ te.stack = t.stack ∧
      te.memory = t.memory ∧ te.input = t.input ∧ te.output = t.output’ by
       fs [Abbr‘te’, write_reg_def, inc_def, combinTheory.APPLY_UPDATE_THM]
  (* Add R14 RDI *)
  \\ qabbrev_tac ‘tf = write_reg R14 (r14 + len) (inc te)’
  \\ ‘step (State te) (State tf)’ by
       (qunabbrev_tac ‘tf’ \\ irule (cj 3 step_rules)
        \\ fs [fetch_def])
  \\ ‘tf.pc = 13 ∧ tf.regs RAX = SOME r14 ∧ tf.regs R14 = SOME (r14 + len) ∧
      tf.regs R15 = SOME r15 ∧
      tf.regs R12 = t.regs R12 ∧ tf.regs R13 = t.regs R13 ∧
      tf.instructions = t.instructions ∧ tf.stack = t.stack ∧
      tf.memory = t.memory ∧ tf.input = t.input ∧ tf.output = t.output’ by
       fs [Abbr‘tf’, write_reg_def, inc_def, combinTheory.APPLY_UPDATE_THM]
  (* Ret *)
  \\ qabbrev_tac ‘tg = set_pc ret (set_stack xs tf)’
  \\ ‘step (State tf) (State tg)’ by
       (qunabbrev_tac ‘tg’ \\ irule (cj 8 step_rules)
        \\ fs [fetch_def])
  \\ qexists_tac ‘tg’
  \\ conj_tac
  >- (irule steps_trans \\ qexists_tac ‘(State tc,n)’ \\ conj_tac >- fs []
      \\ irule steps_trans \\ qexists_tac ‘(State td,n)’
      \\ conj_tac >- fs [Abbr‘td’]
      \\ irule steps_unroll \\ qexists_tac ‘State te’ \\ conj_tac >- fs []
      \\ irule steps_unroll \\ qexists_tac ‘State tf’ \\ conj_tac >- fs []
      \\ irule (cj 2 steps_rules) \\ fs [])
  \\ fs [Abbr‘tg’, set_pc_def, set_stack_def]
QED

(* ------------------------------------------------------------------ *)
(* The code emitted by c_assign                                        *)
(* ------------------------------------------------------------------ *)

Theorem c_assign_steps[local]:
  ∀vn l vs asm2 l2 t1 w hw ct rest fu.
    c_assign vn l vs = (asm2,l2) ∧
    MEM (SOME vn) vs ∧
    LENGTH vs = LENGTH (Word hw :: ct) ∧
    code_in l (flatten asm2 []) t1.instructions ∧
    t1.pc = l ∧ t1.regs RAX = SOME w ∧
    t1.stack = Word hw :: (ct ⧺ rest) ⇒
    ∃t2.
      steps (State t1,fu) (State t2,fu) ∧
      t2.pc = l2 ∧ t2.instructions = t1.instructions ∧
      t2.memory = t1.memory ∧ t2.input = t1.input ∧ t2.output = t1.output ∧
      t2.regs R12 = t1.regs R12 ∧ t2.regs R13 = t1.regs R13 ∧
      t2.regs R14 = t1.regs R14 ∧ t2.regs R15 = t1.regs R15 ∧
      has_stack t2 (LUPDATE (Word w) (index_of vn 0 vs) (Word hw :: ct) ⧺ rest)
Proof
  rpt gen_tac \\ strip_tac
  \\ ‘index_of vn 0 vs < LENGTH vs’ by (imp_res_tac index_of_oEL \\ fs [])
  \\ qpat_x_assum ‘c_assign _ _ _ = _’ mp_tac
  \\ simp [c_assign_def]
  \\ Cases_on ‘index_of vn 0 vs’ \\ simp []
  >- (* the variable lives in RAX: pop the old top into the scratch RDI *)
   (strip_tac \\ gvs [flatten_def, code_in_def]
    \\ qexists_tac ‘set_stack (ct ⧺ rest) (write_reg RDI hw (inc t1))’
    \\ conj_tac
    >- (irule (cj 2 steps_rules) \\ irule (cj 9 step_rules)
        \\ fs [fetch_def])
    \\ fs [set_stack_def, write_reg_def, inc_def, has_stack_def,
           combinTheory.APPLY_UPDATE_THM, listTheory.LUPDATE_def])
  (* the variable lives further down the frame: StoreRSP, then restore RAX *)
  \\ rename1 ‘SUC k’
  \\ strip_tac \\ gvs [flatten_def, code_in_def]
  \\ ‘k < LENGTH ct’ by fs []
  \\ qabbrev_tac ‘t2 = set_stack (LUPDATE (Word w) (SUC k) t1.stack) (inc t1)’
  \\ ‘step (State t1) (State t2)’ by
       (qunabbrev_tac ‘t2’ \\ irule (cj 12 step_rules)
        \\ fs [fetch_def])
  \\ ‘t2.stack = Word hw :: (LUPDATE (Word w) k ct ⧺ rest) ∧
      t2.pc = t1.pc + 1 ∧ t2.regs = t1.regs ∧
      t2.instructions = t1.instructions ∧ t2.memory = t1.memory ∧
      t2.input = t1.input ∧ t2.output = t1.output’ by
       (fs [Abbr‘t2’, set_stack_def, inc_def, listTheory.LUPDATE_def]
        \\ irule rich_listTheory.LUPDATE_APPEND1 \\ fs [])
  \\ qexists_tac ‘set_stack (LUPDATE (Word w) k ct ⧺ rest)
                    (write_reg RAX hw (inc t2))’
  \\ conj_tac
  >- (irule steps_trans \\ qexists_tac ‘(State t2,fu)’
      \\ conj_tac >- (irule (cj 2 steps_rules) \\ fs [])
      \\ irule (cj 2 steps_rules) \\ irule (cj 9 step_rules)
      \\ fs [fetch_def])
  \\ fs [set_stack_def, write_reg_def, inc_def, has_stack_def,
         combinTheory.APPLY_UPDATE_THM, listTheory.LUPDATE_def]
QED

(* The ASM read_char and the IMP next/get_char agree. *)
Theorem read_char_next[local]:
  ∀ll c inp.
    read_char ll = (c,inp) ⇒
    next ll = Word c ∧
    inp = (case LTL ll of NONE => ll | SOME t => t)
Proof
  rpt gen_tac
  \\ qspec_then ‘ll’ strip_assume_tac llistTheory.llist_CASES
  \\ gvs [x64asm_semanticsTheory.read_char_def,
          imp_source_semanticsTheory.next_def]
  \\ EVAL_TAC
QED

Theorem even_len_EVEN[local]:
  ∀xs. even_len xs ⇔ EVEN (LENGTH xs)
Proof
  completeInduct_on ‘LENGTH xs’ \\ rw [] \\ gvs [PULL_FORALL]
  \\ Cases_on ‘xs’ \\ simp [Once even_len_def]
  \\ Cases_on ‘t’ \\ simp [Once even_len_def]
  \\ gvs [EVEN]
  \\ first_x_assum (qspec_then ‘t'’ mp_tac) \\ simp []
QED

(* ------------------------------------------------------------------ *)
(* Binders and the callee's v_stack                                    *)
(* ------------------------------------------------------------------ *)

Theorem names_contain_MEM[local]:
  ∀l a. names_contain l a ⇔ MEM a l
Proof
  Induct \\ rw [Once names_contain_def] \\ metis_tac []
QED

Theorem MEM_names_unique[local]:
  ∀l acc n. MEM n (names_unique l acc) ⇔ MEM n l ∨ MEM n acc
Proof
  Induct \\ simp [Once names_unique_def]
  \\ rw [add_name_def, names_contain_MEM] \\ metis_tac []
QED

Theorem MEM_unique_binders[local]:
  ∀c n. MEM n (unique_binders c) ⇔ MEM n (all_binders c)
Proof
  rw [unique_binders_def, MEM_names_unique]
QED

Theorem MEM_fltr_nms[local]:
  ∀l a n. MEM n (fltr_nms a l) ⇔ MEM n l ∧ n ≠ a
Proof
  Induct \\ rw [Once fltr_nms_def] \\ metis_tac []
QED

Theorem MEM_rm_nms[local]:
  ∀ps l n. MEM n (rm_nms ps l) ⇔ MEM n l ∧ ¬MEM n ps
Proof
  Induct \\ rw [Once rm_nms_def, MEM_fltr_nms] \\ metis_tac []
QED

Theorem MEM_make_vs_from_binders[local]:
  ∀l n. MEM (SOME n) (make_vs_from_binders l) ⇔ MEM n l
Proof
  Induct \\ rw [Once make_vs_from_binders_def] \\ metis_tac []
QED

Theorem MEM_call_v_stack[local]:
  ∀xs acc n. MEM (SOME n) (call_v_stack xs acc) ⇔ MEM n xs ∨ MEM (SOME n) acc
Proof
  Induct \\ rw [Once call_v_stack_def] \\ metis_tac []
QED

Theorem MEM_push_vs[local]:
  ∀ps n. MEM n ps ⇒ MEM (SOME n) (push_vs ps)
Proof
  rw [push_vs_def] \\ gvs [MEM_call_v_stack]
  \\ Cases_on ‘ps’ \\ gvs []
QED

Theorem binders_ok_all_binders[local]:
  ∀c vs. binders_ok c vs ⇔ ∀n. MEM n (all_binders c) ⇒ MEM (SOME n) vs
Proof
  Induct \\ rpt gen_tac
  \\ once_rewrite_tac [all_binders_def] \\ simp [binders_ok_def]
  \\ metis_tac []
QED

Theorem binders_ok_c_bdrs[local]:
  ∀params body asm0 vs_bind1 asm1 vs1 l0 l1.
    c_bdrs params body = (asm0,vs_bind1) ∧
    c_pushes params l0 = (asm1,vs1,l1) ⇒
    binders_ok body (vs1 ⧺ vs_bind1)
Proof
  rw [] \\ imp_res_tac c_pushes_vs \\ gvs [c_bdrs_def]
  \\ rw [binders_ok_all_binders]
  \\ Cases_on ‘MEM n params’
  >- (disj1_tac \\ irule MEM_push_vs \\ simp [])
  \\ disj2_tac
  \\ rw [vs_bdrs_def]
  \\ gvs [MEM_make_vs_from_binders, MEM_rm_nms, MEM_unique_binders]
QED

(* ------------------------------------------------------------------ *)
(* The code emitted by c_pops                                          *)
(* ------------------------------------------------------------------ *)

val step_tac =
  irule steps_unroll_any
  \\ simp [Once step_cases, fetch_def, PULL_EXISTS,
           write_reg_def, set_stack_def, inc_def,
           combinTheory.APPLY_UPDATE_THM];

(* One case of c_pops: k straight-line instructions, then the derivation ends
   where it started. *)
fun pops_tac k =
  gvs [c_pops_def, flatten_def, code_in_def, app_list_length_def,
       pops_regs_def, ARGS_REGS_def, write_regs_def, write_reg_map_def]
  \\ fs [has_stack_def] \\ gvs []
  \\ rpt (qpat_x_assum ‘_ = t.stack’ (assume_tac o GSYM))
  \\ ntac k step_tac
  \\ once_rewrite_tac [steps_cases]
  \\ fs [x64asm_semanticsTheory.state_component_equality, FUN_EQ_THM,
         combinTheory.APPLY_UPDATE_THM, write_reg_def, set_stack_def, inc_def];

(* c_pops moves the arguments that c_exps left on the stack into the registers
   the callee expects *)
Theorem c_pops_steps[local]:
  ∀xs vs ws t rest n fs ds r15.
    LENGTH xs = LENGTH ws ∧
    code_rel fs ds t.instructions ∧
    t.regs R15 = SOME r15 ∧
    code_in t.pc (flatten (c_pops xs vs) []) t.instructions ∧
    has_stack t (MAP Word (REVERSE ws) ⧺ rest) ∧
    EVEN (LENGTH rest) ⇒
    steps (State t,n) (Halt 4w t.output,n) ∨
    LENGTH xs ≤ 5 ∧
    steps (State t,n)
      (State (t with <| regs := pops_regs ws t.regs;
                        pc := t.pc + app_list_length (c_pops xs vs);
                        stack := rest |>),n)
Proof
  rpt gen_tac \\ strip_tac
  \\ reverse (Cases_on ‘LENGTH ws ≤ 5’)
  >- (* more than five arguments: jump to the give-up code *)
   (disj1_tac
    \\ ‘¬(LENGTH xs ≤ 5) ∧ ws ≠ []’ by (Cases_on ‘ws’ \\ fs [])
    \\ gvs [c_pops_def, flatten_def, code_in_def]
    \\ ‘EVEN (LENGTH xs) ⇔ ODD (LENGTH t.stack)’ by
         (imp_res_tac has_stack_LENGTH
          \\ ‘LENGTH t.stack + 1 = LENGTH ws + LENGTH rest’ by fs []
          \\ ‘EVEN (LENGTH t.stack + 1) ⇔ EVEN (LENGTH ws + LENGTH rest)’ by fs []
          \\ fs [EVEN_ADD, ODD_EVEN])
    \\ irule steps_trans
    \\ irule_at (Pos hd) steps_Jump
    \\ qexists_tac ‘give_up (even_len xs)’
    \\ conj_tac >- fs [fetch_def]
    \\ ‘t.output = (set_pc (give_up (even_len xs)) t).output’ by fs [set_pc_def]
    \\ pop_assum (fn th => once_rewrite_tac [th])
    \\ irule give_up
    \\ fs [set_pc_def, even_len_EVEN]
    \\ metis_tac [])
  \\ disj2_tac
  \\ ‘LENGTH ws = 0 ∨ LENGTH ws = 1 ∨ LENGTH ws = 2 ∨ LENGTH ws = 3 ∨
      LENGTH ws = 4 ∨ LENGTH ws = 5’ by
       (qpat_assum ‘LENGTH ws ≤ 5’ mp_tac \\ decide_tac)
  \\ gvs [LENGTH_EQ_NUM_compute]
  >- pops_tac 1   (* no arguments: Push RAX *)
  >- pops_tac 0   (* one argument, already in RAX *)
  >- pops_tac 1
  >- pops_tac 2
  >- pops_tac 3
  \\ pops_tac 4
QED

(* ------------------------------------------------------------------ *)
(* The callee's entry code (c_bdrs and c_pushes)                       *)
(* ------------------------------------------------------------------ *)

(* One case of the entry code: k straight-line instructions. *)
fun pushes_tac k =
  gvs ([c_pushes_def, push_vs_def, call_v_stack_def, app_list_length_def,
        pops_regs_def, ARGS_REGS_def, write_regs_def, write_reg_map_def] @
       code_layout)
  \\ ntac k step_tac
  \\ once_rewrite_tac [steps_cases]
  \\ fs [x64asm_semanticsTheory.state_component_equality, FUN_EQ_THM,
         combinTheory.APPLY_UPDATE_THM, write_reg_def, set_stack_def, inc_def];

Theorem c_bdrs_asm[local]:
  ∀params body asm0 vs_bind1.
    c_bdrs params body = (asm0,vs_bind1) ⇒
    asm0 = List [Sub_RSP (LENGTH vs_bind1)]
Proof
  rw [c_bdrs_def] \\ gvs []
QED

Theorem LENGTH_push_vs[local]:
  ∀ps. LENGTH (push_vs ps) = if ps = [] then 1 else LENGTH ps
Proof
  rw [push_vs_def, call_v_stack_thm] \\ Cases_on ‘ps’ \\ gvs []
QED

Theorem c_fundef_parts[local]:
  ∀f params body pos fs.
    ∃asm0 vs_bind1 asm1 vs1 l0 asm3 l2.
      c_bdrs params body = (asm0,vs_bind1) ∧
      c_pushes params (pos + app_list_length asm0) = (asm1,vs1,l0) ∧
      c_cmd body l0 fs (vs1 ⧺ vs_bind1) = (asm3,l2) ∧
      FST (c_fundef (Func f params body) pos fs) = asm0 +++ asm1 +++ asm3
Proof
  rpt gen_tac \\ simp [c_fundef_def]
  \\ rpt (pairarg_tac \\ simp []) \\ metis_tac []
QED

Theorem c_bdrs_ODD[local]:
  ∀params body asm0 vs_bind1 asm1 vs1 l0 l1.
    c_bdrs params body = (asm0,vs_bind1) ∧
    c_pushes params l0 = (asm1,vs1,l1) ⇒
    ODD (LENGTH vs1 + LENGTH vs_bind1)
Proof
  rw [] \\ imp_res_tac c_pushes_vs
  \\ gvs [c_bdrs_def, vs_bdrs_def, even_len_EVEN]
  \\ rw [] \\ gvs [ODD_EVEN, EVEN_ADD] \\ metis_tac []
QED

Theorem env_ok_callee[local]:
  ∀params b ws vs_bind1 pmap w.
    LIST_REL (v_inv pmap) b ws ∧ LENGTH params = LENGTH ws ∧
    ALL_DISTINCT params ⇒
    env_ok (FEMPTY |++ ZIP (params,b))
           (push_vs params ⧺ vs_bind1)
           ((if ws = [] then [Word w] else MAP Word (REVERSE ws)) ⧺
            REPLICATE (LENGTH vs_bind1) Undefined)
           pmap
Proof
  rw []
  >- (* no parameters: nothing is in scope yet *)
   (gvs []
    \\ gvs [push_vs_def, env_ok_def, finite_mapTheory.FUPDATE_LIST_THM])
  \\ irule env_ok_APPEND \\ simp []
  \\ ‘params ≠ []’ by (strip_tac \\ gvs [])
  \\ gvs [push_vs_def, call_v_stack_thm, listTheory.MAP_REVERSE]
  \\ irule env_ok_ZIP \\ simp []
QED

Theorem c_fundef_entry_steps[local]:
  ∀params body pos t asm0 vs_bind1 asm1 vs1 l1 ws w n regs.
    c_bdrs params body = (asm0,vs_bind1) ∧
    c_pushes params (pos + app_list_length asm0) = (asm1,vs1,l1) ∧
    t.pc = pos ∧
    code_in pos (flatten (asm0 +++ asm1) []) t.instructions ∧
    t.regs = pops_regs ws regs ∧ t.regs RAX = SOME w ∧
    (ws ≠ [] ⇒ LAST ws = w) ∧
    LENGTH params = LENGTH ws ∧ LENGTH ws ≤ 5 ⇒
    steps (State t,n)
      (State (t with
              <| pc := l1;
                 stack :=
                   TL (if ws = [] then [Word w] else MAP Word (REVERSE ws)) ⧺
                   REPLICATE (LENGTH vs_bind1) Undefined ⧺ t.stack |>),n)
Proof
  rpt gen_tac \\ strip_tac
  \\ imp_res_tac c_bdrs_asm
  \\ gvs [app_list_length_def]
  \\ ‘LENGTH ws = 0 ∨ LENGTH ws = 1 ∨ LENGTH ws = 2 ∨ LENGTH ws = 3 ∨
      LENGTH ws = 4 ∨ LENGTH ws = 5’ by
       (qpat_assum ‘LENGTH ws ≤ 5’ mp_tac \\ decide_tac)
  \\ gvs [LENGTH_EQ_NUM_compute]
  >- pushes_tac 1   (* no arguments: just reserve the binder slots *)
  >- pushes_tac 1   (* one argument, already in RAX *)
  >- pushes_tac 2
  >- pushes_tac 3
  >- pushes_tac 4
  \\ pushes_tac 5
QED

(* ------------------------------------------------------------------ *)
(* Correctness theorems for individual expression forms               *)
(* ------------------------------------------------------------------ *)

Theorem c_exp_correct:
  ∀e. goal_exp e
Proof
  Induct
  >~ [‘goal_exp (Var _)’]    >- suspend "Var"
  >~ [‘goal_exp (Const _)’]  >- suspend "Const"
  >~ [‘goal_exp (Add _ _)’]  >- suspend "Add"
  >~ [‘goal_exp (Sub _ _)’]  >- suspend "Sub"
  >~ [‘goal_exp (Div _ _)’]  >- suspend "Div"
  >~ [‘goal_exp (Read _ _)’] >- suspend "Read"
QED

Resume c_exp_correct[Const]:
  qx_gen_tac ‘cw’
  \\ rw [goal_exp_def]
  \\ gvs [Once c_exp_def, c_const_def, flatten_def, code_in_def]
  \\ ‘fetch t = SOME (Push RAX)’ by fs [fetch_def]
  \\ fs [has_stack_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases]
  \\ irule_at Any step_IMP_steps
  \\ fs [Once step_cases, set_stack_def, inc_def, fetch_def]
  \\ fs [exp_res_rel_def, v_inv_def, has_stack_def, state_rel_def,
         set_stack_def, inc_def, write_reg_def,
         combinTheory.APPLY_UPDATE_THM, r14_mono_refl]
QED

Resume c_exp_correct[Var]:
  qx_gen_tac ‘vn’
  \\ rw [goal_exp_def]
  \\ gvs [AllCaseEqs(), c_exp_def]
  \\ rename [‘FLOOKUP s.vars vn = SOME v’]
  \\ ‘MEM (SOME vn) vs ∧
      ∃wv. oEL (index_of vn 0 vs) curr = SOME (Word wv) ∧ v_inv pmap v wv’ by
       (qpat_x_assum ‘env_ok _ _ _ _’ mp_tac \\ rw [env_ok_def]
        \\ res_tac \\ metis_tac [])
  \\ ‘index_of vn 0 vs < LENGTH curr ∧ EL (index_of vn 0 vs) curr = Word wv’ by
       (qpat_x_assum ‘oEL _ _ = _’ mp_tac
        \\ rw [listTheory.oEL_THM] \\ gvs [AllCaseEqs()])
  \\ qpat_x_assum ‘c_var _ _ _ = _’ mp_tac
  \\ simp [Once c_exp_def, c_var_def]
  \\ IF_CASES_TAC \\ strip_tac \\ gvs [flatten_def, code_in_def]
  \\ ‘fetch t = SOME (Push RAX)’ by fs [fetch_def]
  \\ fs [has_stack_def]
  \\ qabbrev_tac ‘t1 = set_stack (Word w :: t.stack) (inc t)’
  \\ ‘step (State t) (State t1)’ by
       (simp [Abbr‘t1’] \\ irule (cj 10 step_rules) \\ fs [])
  \\ ‘t1.stack = curr ⧺ rest ∧ t1.pc = t.pc + 1 ∧
      t1.instructions = t.instructions’ by
       fs [Abbr‘t1’, set_stack_def, inc_def]
  >- (* the variable is already on top: the Push is all that is needed *)
   (‘w = wv’ by
      (Cases_on ‘curr’ \\ gvs [listTheory.oEL_def])
    \\ qexists_tac ‘t1’
    \\ conj_tac >- (irule (cj 2 steps_rules) \\ fs [])
    \\ fs [exp_res_rel_def, has_stack_def, state_rel_def, Abbr‘t1’,
           set_stack_def, inc_def, r14_mono_refl])
  (* otherwise load it out of the frame *)
  \\ ‘index_of vn 0 vs < LENGTH t1.stack ∧
      EL (index_of vn 0 vs) t1.stack = Word wv’ by
       (qpat_assum ‘t1.stack = _’ (fn th => rewrite_tac [th])
        \\ fs [rich_listTheory.EL_APPEND1])
  \\ qabbrev_tac ‘t2 = write_reg RAX wv (inc t1)’
  \\ ‘step (State t1) (State t2)’ by
       (simp [Abbr‘t2’] \\ irule (cj 11 step_rules)
        \\ qexists_tac ‘index_of vn 0 vs’
        \\ fs [fetch_def])
  \\ qexists_tac ‘t2’
  \\ conj_tac
  >- (irule steps_trans \\ qexists_tac ‘(State t1,fuel)’
      \\ conj_tac >- (irule (cj 2 steps_rules) \\ fs [])
      \\ irule (cj 2 steps_rules) \\ fs [])
  \\ fs [exp_res_rel_def, has_stack_def, state_rel_def, Abbr‘t2’, Abbr‘t1’,
         set_stack_def, inc_def, write_reg_def,
         combinTheory.APPLY_UPDATE_THM, r14_mono_refl]
QED

Resume c_exp_correct[Add]:
  rw [goal_exp_def]
  \\ fs [Once c_exp_def, bind_def]
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ last_x_assum drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp [] \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [flatten_append, code_in_append]
  \\ disch_then drule_all
  \\ disch_then $ qspec_then ‘fuel’ strip_assume_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ last_x_assum drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp [] \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [exp_res_rel_def]
  \\ disch_then drule
  \\ disch_then drule
  \\ disch_then $ qspecl_then [‘fuel’,‘Word w :: curr’, ‘rest’, ‘pmap’] mp_tac \\ gvs []
  \\ impl_tac
  >-
   (imp_res_tac steps_inst
    \\ imp_res_tac c_exp_length
    \\ gvs [app_list_length_thm]
    \\ irule env_ok_NONE \\ fs [])
  \\ strip_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ qabbrev_tac ‘c1 = LENGTH (flatten asm1 [])’
  \\ qabbrev_tac ‘c2 = LENGTH (flatten asm2 [])’
  \\ imp_res_tac c_exp_length
  \\ gvs [app_list_length_thm]
  \\ gvs [c_add_def,flatten_def, code_in_def]
  \\ gvs [has_stack_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases]
  \\ imp_res_tac steps_inst
  \\ qpat_x_assum ‘_ = t1'.stack’ $ assume_tac o GSYM
  \\ simp [fetch_def]
  \\ irule_at Any step_IMP_steps
  \\ simp [Once step_cases, fetch_def,
           write_reg_def, set_stack_def, inc_def]
  \\ simp [PULL_EXISTS, combinTheory.APPLY_UPDATE_THM]
  \\ Cases_on ‘b’ \\ gvs [combine_word_def]
  \\ Cases_on ‘b'’ \\ gvs [combine_word_def]
  \\ gvs [v_inv_def]
  \\ qpat_x_assum ‘state_rel fs s1 _’ mp_tac
  \\ simp [state_rel_def]
  \\ simp [PULL_EXISTS, combinTheory.APPLY_UPDATE_THM]
  \\ rw [] \\ imp_res_tac r14_mono_trans \\ gvs []
QED

Resume c_exp_correct[Sub]:
  rw [goal_exp_def]
  \\ fs [Once c_exp_def, bind_def]
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ last_x_assum drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp [] \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [flatten_append, code_in_append]
  \\ disch_then drule_all
  \\ disch_then $ qspec_then ‘fuel’ strip_assume_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ last_x_assum drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp [] \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [exp_res_rel_def]
  \\ disch_then drule
  \\ disch_then drule
  \\ disch_then $ qspecl_then [‘fuel’,‘Word w :: curr’, ‘rest’, ‘pmap’] mp_tac \\ gvs []
  \\ impl_tac
  >-
   (imp_res_tac steps_inst
    \\ imp_res_tac c_exp_length
    \\ gvs [app_list_length_thm]
    \\ irule env_ok_NONE \\ fs [])
  \\ strip_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ qabbrev_tac ‘c1 = LENGTH (flatten asm1 [])’
  \\ qabbrev_tac ‘c2 = LENGTH (flatten asm2 [])’
  \\ imp_res_tac c_exp_length
  \\ gvs [app_list_length_thm]
  \\ gvs [c_sub_def,flatten_def, code_in_def]
  \\ gvs [has_stack_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases]
  \\ imp_res_tac steps_inst
  \\ qpat_x_assum ‘_ = t1'.stack’ $ assume_tac o GSYM
  \\ simp [fetch_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases,
           fetch_def, set_stack_def, write_reg_def, inc_def]
  \\ simp [PULL_EXISTS, combinTheory.APPLY_UPDATE_THM]
  \\ irule_at Any step_IMP_steps
  \\ simp [Once step_cases, fetch_def,
           write_reg_def, set_stack_def, inc_def]
  \\ Cases_on ‘b’ \\ gvs [combine_word_def]
  \\ Cases_on ‘b'’ \\ gvs [combine_word_def]
  \\ gvs [v_inv_def]
  \\ qpat_x_assum ‘state_rel fs s1 _’ mp_tac
  \\ simp [state_rel_def]
  \\ simp [PULL_EXISTS, combinTheory.APPLY_UPDATE_THM]
  \\ rw [] \\ imp_res_tac r14_mono_trans \\ gvs []
QED

Resume c_exp_correct[Div]:
  rw [goal_exp_def]
  \\ fs [Once c_exp_def, bind_def]
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ last_x_assum drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp [] \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [flatten_append, code_in_append]
  \\ disch_then drule_all
  \\ disch_then $ qspec_then ‘fuel’ strip_assume_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ last_x_assum drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp [] \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [exp_res_rel_def]
  \\ disch_then drule
  \\ disch_then drule
  \\ disch_then $ qspecl_then [‘fuel’,‘Word w :: curr’, ‘rest’, ‘pmap’] mp_tac \\ gvs []
  \\ impl_tac
  >-
   (imp_res_tac steps_inst
    \\ imp_res_tac c_exp_length
    \\ gvs [app_list_length_thm]
    \\ irule env_ok_NONE \\ fs [])
  \\ strip_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ Cases_on ‘b' = Word 0w’ \\ gvs []
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ qabbrev_tac ‘c1 = LENGTH (flatten asm1 [])’
  \\ qabbrev_tac ‘c2 = LENGTH (flatten asm2 [])’
  \\ imp_res_tac c_exp_length
  \\ gvs [app_list_length_thm]
  \\ gvs [c_div_def,flatten_def, code_in_def]
  \\ gvs [has_stack_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases]
  \\ imp_res_tac steps_inst
  \\ qpat_x_assum ‘_ = t1'.stack’ $ assume_tac o GSYM
  \\ simp [fetch_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases,
           fetch_def, set_stack_def, write_reg_def, inc_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases,
           fetch_def, set_stack_def, write_reg_def, inc_def]
  \\ irule_at Any step_IMP_steps
  \\ simp [Once step_cases,
           fetch_def, set_stack_def, write_reg_def, inc_def]
  \\ simp [PULL_EXISTS, combinTheory.APPLY_UPDATE_THM]
  \\ Cases_on ‘b’ \\ gvs [combine_word_def]
  \\ Cases_on ‘b'’ \\ gvs [combine_word_def]
  \\ gvs [v_inv_def]
  \\ qpat_x_assum ‘state_rel fs s1 _’ mp_tac
  \\ simp [state_rel_def]
  \\ simp [PULL_EXISTS, combinTheory.APPLY_UPDATE_THM, word_div_def]
  \\ rw [] \\ imp_res_tac r14_mono_trans \\ gvs []
QED

Resume c_exp_correct[Read]:
  rw [goal_exp_def]
  \\ fs [Once c_exp_def, bind_def]
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ last_x_assum drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp [] \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [flatten_append, code_in_append]
  \\ disch_then drule_all
  \\ disch_then $ qspec_then ‘fuel’ strip_assume_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ last_x_assum drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp [] \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [exp_res_rel_def]
  \\ disch_then drule
  \\ disch_then drule
  \\ disch_then $ qspecl_then [‘fuel’,‘Word w :: curr’, ‘rest’, ‘pmap’] mp_tac \\ gvs []
  \\ impl_tac
  >-
   (imp_res_tac steps_inst
    \\ imp_res_tac c_exp_length
    \\ gvs [app_list_length_thm]
    \\ irule env_ok_NONE \\ fs [])
  \\ strip_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ qabbrev_tac ‘c1 = LENGTH (flatten asm1 [])’
  \\ qabbrev_tac ‘c2 = LENGTH (flatten asm2 [])’
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ imp_res_tac c_exp_length
  \\ gvs [app_list_length_thm]
  \\ gvs [c_load_def, flatten_def, code_in_def]
  \\ gvs [has_stack_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases]
  \\ imp_res_tac steps_inst
  \\ qpat_x_assum ‘_ = t1'.stack’ $ assume_tac o GSYM
  \\ simp [fetch_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases,
           fetch_def, set_stack_def, write_reg_def, inc_def]
  \\ irule_at Any step_IMP_steps
  \\ simp [Once step_cases,
           fetch_def, set_stack_def, write_reg_def, inc_def]
  \\ simp [PULL_EXISTS, combinTheory.APPLY_UPDATE_THM]
  \\ Cases_on ‘b’ \\ gvs [mem_load_def]
  \\ Cases_on ‘b'’ \\ gvs [mem_load_def]
  \\ gvs [v_inv_def]
  \\ Cases_on ‘w2n c MOD 8 = 0’ \\ gvs []
  \\ gvs [AllCaseEqs(), read_mem_def]
  \\ qpat_assum ‘mem_inv pmap _ _’ mp_tac
  \\ rewrite_tac [mem_inv_def]
  \\ disch_then drule \\ gvs []
  \\ strip_tac
  \\ pop_assum drule
  \\ simp [OPTREL_def]
  \\ ‘n2w (8 * (w2n c DIV 8)) = c’ by
   (Cases_on ‘c’ \\ gvs []
    \\ ‘0 < 8:num’ by EVAL_TAC
    \\ drule DIVISION
    \\ disch_then $ qspec_then ‘n'’ mp_tac
    \\ asm_rewrite_tac []
    \\ disch_then $ assume_tac o GSYM \\ gvs [])
  \\ strip_tac
  \\ Cases_on ‘yopt’ \\ gvs []
  \\ qpat_x_assum ‘state_rel fs s1 _’ mp_tac
  \\ simp [state_rel_def]
  \\ simp [PULL_EXISTS, combinTheory.APPLY_UPDATE_THM, word_div_def]
  \\ rw [] \\ imp_res_tac r14_mono_trans \\ gvs []
QED

Finalise c_exp_correct

Theorem c_exps_correct:
  ∀es. goal_exps es
Proof
  Induct
  >-
   (gvs [goal_exps_def, c_exps_def, flatten_def, code_in_def, exps_res_rel_def]
    \\ rpt strip_tac
    \\ irule_at Any steps_refl
    \\ gvs [] \\ gvs [state_rel_def, r14_mono_def])
  \\ rw [goal_exps_def, Once c_exps_def]
  \\ gvs [bind_def, CaseEq"prod"]
  \\ rpt (pairarg_tac \\ gvs [])
  \\ qspec_then ‘h’ mp_tac c_exp_correct
  \\ simp [goal_exp_def]
  \\ disch_then drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp []
  \\ gvs [flatten_append, code_in_append]
  \\ disch_then drule_all
  \\ disch_then $ qspec_then ‘fuel’ strip_assume_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ gvs [bind_def, CaseEq "prod", goal_exp_def]
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ gvs [exp_res_rel_def, goal_exps_def]
  \\ last_x_assum drule
  \\ Cases_on ‘v' = Stop Crash’ \\ gvs []
  \\ disch_then drule
  \\ disch_then drule
  \\ drule env_ok_NONE
  \\ disch_then $ qspec_then ‘Word w’ assume_tac
  \\ disch_then drule
  \\ fs []
  \\ disch_then drule
  \\ fs []
  \\ disch_then $ qspec_then ‘fuel’ mp_tac
  \\ impl_tac
  >-
   (imp_res_tac steps_inst
    \\ imp_res_tac c_exp_length
    \\ gvs [app_list_length_thm])
  \\ strip_tac
  \\ Cases_on ‘v'’ \\ gvs []
  \\ first_assum $ irule_at $ Pos hd
  \\ imp_res_tac r14_mono_trans
  \\ gvs []
  \\ fs [exps_res_rel_def, PULL_EXISTS]
  \\ first_assum $ irule_at Any
  \\ first_assum $ irule_at Any
  \\ rewrite_tac [GSYM APPEND_ASSOC, APPEND]
  \\ simp []
QED

Theorem eval_cmp_pure[local]:
  ∀cp v1 v2 s r s'. eval_cmp cp v1 v2 s = (r,s') ⇒ s' = s
Proof
  Cases \\ Cases_on ‘v1’ \\ Cases_on ‘v2’ \\ rw [] \\ gvs [AllCaseEqs()]
QED

Theorem take_branch_c_cmp[local]:
  ∀cp v1 v2 w1 w2 b s s' t pmap r14.
    eval_cmp cp v1 v2 s = (Cont b, s') ∧
    v_inv pmap v1 w1 ∧ v_inv pmap v2 w2 ∧
    pmap_in_bounds pmap (SOME r14) ∧
    t.regs RDI = SOME w1 ∧ t.regs RBX = SOME w2 ⇒
    take_branch (c_cmp cp) t b
Proof
  rpt gen_tac \\ strip_tac
  \\ Cases_on ‘cp’ \\ Cases_on ‘v1’ \\ Cases_on ‘v2’
  \\ gvs [c_cmp_def, v_inv_def, AllCaseEqs()]
  \\ simp [Once take_branch_cases, WORD_LO]
  \\ gvs [pmap_in_bounds_def] \\ res_tac \\ gvs []
  \\ qpat_x_assum ‘(if _ then _ else _) _ = _’ mp_tac
  \\ rw [] \\ gvs []
  \\ strip_tac \\ gvs []
QED

Theorem c_test_correct:
  ∀tst. goal_test tst
Proof
  Induct
  >~ [‘goal_test (Test _ _ _)’] >- suspend "Test"
  >~ [‘goal_test (And _ _)’]    >- suspend "And"
  >~ [‘goal_test (Or _ _)’]     >- suspend "Or"
  >~ [‘goal_test (Not _)’]      >- suspend "Not"
QED

(* Not swaps the two labels and negates the result. *)
Resume c_test_correct[Not]:
  rw [goal_test_def]
  \\ gvs [Once c_test_jump_def, bind_def, CaseEq "prod"]
  \\ Cases_on ‘v’ \\ gvs []
  \\ qpat_x_assum ‘goal_test _’ mp_tac
  \\ simp [goal_test_def]
  \\ disch_then $ qspecl_then
       [‘s’,‘s1’,‘fuel’,‘b'’,‘t’,‘vs’,‘fs’,‘asmc’,‘l1’,
        ‘lfalse’,‘ltrue’,‘curr’,‘rest’,‘pmap’] mp_tac
  \\ impl_tac >- (gvs [] \\ metis_tac [])
  \\ strip_tac
  \\ first_assum $ irule_at Any \\ gvs []
  \\ Cases_on ‘b'’ \\ gvs []
QED

Resume c_test_correct[And]:
  rw [goal_test_def]
  \\ gvs [Once c_test_jump_def, bind_def, CaseEq "prod"]
  \\ rpt (pairarg_tac \\ gvs [])
  \\ Cases_on ‘v’ \\ gvs []
  \\ Cases_on ‘eval_test tst' s1'’ \\ gvs []
  \\ rename [‘eval_test tst' s1' = (r2,s2)’]
  \\ Cases_on ‘r2’ \\ gvs []
  \\ imp_res_tac eval_test_pure \\ gvs []
  \\ imp_res_tac c_test_jump_length
  \\ gvs [flatten_append, flatten_def, code_in_append, code_in_def,
          app_list_length_thm]
  \\ qabbrev_tac ‘l2 = LENGTH (flatten asm1 []) + (t.pc + 2)’
  (* jump into the code for the first test *)
  \\ irule_at Any steps_trans
  \\ irule_at (Pos hd) steps_Jump
  \\ simp [fetch_def]
  (* run the first test *)
  \\ qpat_x_assum ‘goal_test tst’ mp_tac
  \\ simp [goal_test_def]
  \\ disch_then $ qspecl_then
       [‘s’,‘s’,‘fuel’,‘b'’,‘set_pc (t.pc + 2) t’,‘vs’,‘fs’,‘asm1’,‘l2’,
        ‘t.pc + 1’,‘lfalse’,‘curr’,‘rest’,‘pmap’] mp_tac
  \\ impl_tac
  >- (gvs [set_pc_def, state_rel_def, has_stack_def] \\ metis_tac [])
  \\ strip_tac
  \\ reverse $ Cases_on ‘b'’ \\ gvs []
  >- (* it failed: we have already landed on lfalse *)
     (first_assum $ irule_at Any \\ gvs [set_pc_def])
  (* it held: jump on to the code for the second test and run that *)
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ irule_at Any steps_trans
  \\ irule_at (Pos hd) steps_Jump
  \\ imp_res_tac steps_inst
  \\ gvs [set_pc_def]
  \\ simp [fetch_def]
  \\ qpat_x_assum ‘goal_test tst'’ mp_tac
  \\ simp [goal_test_def]
  \\ disch_then $ qspecl_then
       [‘s’,‘s’,‘fuel’,‘b''’,‘set_pc l2 t1’,‘vs’,‘fs’,‘asm2’,
        ‘LENGTH (flatten asm1 []) + (LENGTH (flatten asm2 []) + (t.pc + 2))’,
        ‘ltrue’,‘lfalse’,‘curr’,‘rest’,‘pmap’] mp_tac
  \\ impl_tac
  >- (gvs [set_pc_def, state_rel_def, has_stack_def, Abbr‘l2’] \\ metis_tac [])
  \\ strip_tac
  \\ first_assum $ irule_at Any
  \\ gvs [set_pc_def]
  \\ imp_res_tac r14_mono_trans \\ gvs []
QED

Resume c_test_correct[Or]:
  rw [goal_test_def]
  \\ gvs [Once c_test_jump_def, bind_def, CaseEq "prod"]
  \\ rpt (pairarg_tac \\ gvs [])
  \\ Cases_on ‘v’ \\ gvs []
  \\ Cases_on ‘eval_test tst' s1'’ \\ gvs []
  \\ rename [‘eval_test tst' s1' = (r2,s2)’]
  \\ Cases_on ‘r2’ \\ gvs []
  \\ imp_res_tac eval_test_pure \\ gvs []
  \\ imp_res_tac c_test_jump_length
  \\ gvs [flatten_append, flatten_def, code_in_append, code_in_def,
          app_list_length_thm]
  \\ qabbrev_tac ‘l2 = LENGTH (flatten asm1 []) + (t.pc + 2)’
  (* jump into the code for the first test *)
  \\ irule_at Any steps_trans
  \\ irule_at (Pos hd) steps_Jump
  \\ simp [fetch_def]
  (* run the first test *)
  \\ qpat_x_assum ‘goal_test tst’ mp_tac
  \\ simp [goal_test_def]
  \\ disch_then $ qspecl_then
       [‘s’,‘s’,‘fuel’,‘b'’,‘set_pc (t.pc + 2) t’,‘vs’,‘fs’,‘asm1’,‘l2’,
        ‘ltrue’,‘t.pc + 1’,‘curr’,‘rest’,‘pmap’] mp_tac
  \\ impl_tac
  >- (gvs [set_pc_def, state_rel_def, has_stack_def] \\ metis_tac [])
  \\ strip_tac
  \\ Cases_on ‘b'’ \\ gvs []
  >- (* it held: we have already landed on ltrue *)
     (first_assum $ irule_at Any \\ gvs [set_pc_def])
  (* it failed: jump on to the code for the second test and run that *)
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ irule_at Any steps_trans
  \\ irule_at (Pos hd) steps_Jump
  \\ imp_res_tac steps_inst
  \\ gvs [set_pc_def]
  \\ simp [fetch_def]
  \\ qpat_x_assum ‘goal_test tst'’ mp_tac
  \\ simp [goal_test_def]
  \\ disch_then $ qspecl_then
       [‘s’,‘s’,‘fuel’,‘b''’,‘set_pc l2 t1’,‘vs’,‘fs’,‘asm2’,
        ‘LENGTH (flatten asm1 []) + (LENGTH (flatten asm2 []) + (t.pc + 2))’,
        ‘ltrue’,‘lfalse’,‘curr’,‘rest’,‘pmap’] mp_tac
  \\ impl_tac
  >- (gvs [set_pc_def, state_rel_def, has_stack_def, Abbr‘l2’] \\ metis_tac [])
  \\ strip_tac
  \\ first_assum $ irule_at Any
  \\ gvs [set_pc_def]
  \\ imp_res_tac r14_mono_trans \\ gvs []
QED

Resume c_test_correct[Test]:
  rw [goal_test_def]
  \\ gvs [Once c_test_jump_def, bind_def, CaseEq "prod"]
  \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [flatten_append, code_in_append]
  (* the first operand *)
  \\ qspec_then ‘e’ mp_tac c_exp_correct
  \\ simp [goal_exp_def]
  \\ disch_then drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp []
  \\ disch_then drule_all
  \\ disch_then $ qspec_then ‘fuel’ strip_assume_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  (* the second operand, one slot deeper *)
  \\ gvs [exp_res_rel_def, bind_def, CaseEq "prod"]
  \\ qspec_then ‘e0’ mp_tac c_exp_correct
  \\ simp [goal_exp_def]
  \\ disch_then drule
  \\ Cases_on ‘v = Stop Crash’ >- gvs []
  \\ simp []
  \\ disch_then drule
  \\ disch_then $ qspecl_then
       [‘fuel’,‘fs’,‘Word w :: curr’,‘rest’,‘pmap’] mp_tac
  \\ gvs []
  \\ impl_tac
  >-
   (imp_res_tac steps_inst
    \\ imp_res_tac c_exp_length
    \\ gvs [app_list_length_thm]
    \\ irule env_ok_NONE \\ fs [])
  \\ strip_tac
  \\ reverse $ Cases_on ‘v’ \\ gvs []
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ gvs [exp_res_rel_def]
  \\ imp_res_tac steps_inst
  \\ imp_res_tac c_exp_length
  \\ gvs [app_list_length_thm, flatten_def, code_in_def, has_stack_def]
  (* the compiled comparison branches exactly when the IMP one holds *)
  \\ ‘∀u. u.regs RDI = SOME w ∧ u.regs RBX = SOME w' ⇒
          take_branch (c_cmp c) u b’ by
       metis_tac [take_branch_c_cmp]
  \\ qpat_x_assum ‘Word _::_ = t1'.stack’ $ assume_tac o GSYM
  \\ qpat_x_assum ‘Word _::_ = t1.stack’ $ assume_tac o GSYM
  (* Mov RBX RAX; Pop RDI; Pop RAX -- these three run either way *)
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases, fetch_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases, fetch_def,
           set_stack_def, write_reg_def, inc_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases, fetch_def,
           set_stack_def, write_reg_def, inc_def]
  (* and then the branch *)
  \\ imp_res_tac eval_cmp_pure \\ gvs []
  \\ qmatch_goalsub_abbrev_tac ‘steps (State u3,fuel) _’
  \\ ‘fetch u3 = SOME (Jump (c_cmp c) ltrue) ∧ take_branch (c_cmp c) u3 b’ by
       gvs [Abbr‘u3’, fetch_def, combinTheory.APPLY_UPDATE_THM]
  \\ reverse $ Cases_on ‘b’ \\ gvs []
  \\ drule_all steps_Jump_cond
  \\ disch_then $ qspec_then ‘fuel’ assume_tac \\ gvs []
  >- (* it failed: fall through to the unconditional jump to lfalse *)
   (irule_at Any steps_trans
    \\ first_assum $ irule_at $ Pos hd
    \\ irule_at Any steps_Jump
    \\ gvs [Abbr‘u3’, set_pc_def, fetch_def]
    \\ qpat_x_assum ‘state_rel fs _ t1'’ mp_tac
    \\ simp [state_rel_def, combinTheory.APPLY_UPDATE_THM]
    \\ rw [] \\ imp_res_tac r14_mono_trans \\ gvs [])
  (* it held: the conditional jump lands straight on ltrue *)
  \\ first_assum $ irule_at Any
  \\ gvs [Abbr‘u3’, set_pc_def]
  \\ qpat_x_assum ‘state_rel fs _ t1'’ mp_tac
  \\ simp [state_rel_def, combinTheory.APPLY_UPDATE_THM]
  \\ rw [] \\ imp_res_tac r14_mono_trans \\ gvs []
QED

Finalise c_test_correct

val not_crash_tac =
  fs [] \\ imp_res_tac imp_source_propertiesTheory.eval_exp_not_stop \\ gvs [];

Theorem c_cmd_correct:
  ∀fuel c. goal_cmd c fuel
Proof
  gen_tac \\ completeInduct_on ‘fuel’ \\ Induct
  >~ [‘goal_cmd Skip’]           >- suspend "Skip"
  >~ [‘goal_cmd (Seq _ _)’]      >- suspend "Seq"
  >~ [‘goal_cmd (Assign _ _)’]   >- suspend "Assign"
  >~ [‘goal_cmd (Update _ _ _)’] >- suspend "Update"
  >~ [‘goal_cmd (If _ _ _)’]     >- suspend "If"
  >~ [‘goal_cmd (While _ _)’]    >- suspend "While"
  >~ [‘goal_cmd (Call _ _ _)’]   >- suspend "Call"
  >~ [‘goal_cmd (Return _)’]     >- suspend "Return"
  >~ [‘goal_cmd (Alloc _ _)’]    >- suspend "Alloc"
  >~ [‘goal_cmd (GetChar _)’]    >- suspend "GetChar"
  >~ [‘goal_cmd (PutChar _)’]    >- suspend "PutChar"
  >~ [‘goal_cmd Abort’]          >- suspend "Abort"
QED

Resume c_cmd_correct[Skip]:
  rw [goal_cmd_def, c_cmd_def, eval_cmd_def]
  \\ qexistsl_tac [‘(State t, 0)’, ‘pmap’]
  \\ fs [cmd_res_rel_def, state_rel_def, pmap_subsume_refl, r14_mono_refl]
  \\ qexists_tac ‘curr’ \\ fs []
QED

Resume c_cmd_correct[Seq]:
  rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ reverse (Cases_on ‘dest_tail_call c c'’) \\ simp []
  >-
   (* c is a call in tail position *)
   (PairCases_on ‘x’ \\ simp []
    \\ rpt (pairarg_tac \\ simp [])
    \\ strip_tac \\ gvs []
    \\ gvs [dest_tail_call_def, AllCaseEqs()]
    \\ gvs [eval_cmd_def, CaseEq "prod"]
    (* the NONE branch's compilation of the two halves plays no role here *)
    \\ qpat_x_assum ‘c_cmd (Call _ _ _) _ _ _ = _’ kall_tac
    \\ qpat_x_assum ‘c_cmd (Return _) _ _ _ = _’ kall_tac
    \\ rename [‘c_exps args t.pc vs = (asms,lb)’]
    \\ rename [‘c_tail_call vs (lookup fname fs) args lb = (asm_tc,_)’]
    (* evaluate the arguments onto the stack *)
    \\ qspec_then ‘args’ mp_tac c_exps_correct
    \\ simp [goal_exps_def]
    \\ disch_then drule
    \\ rename [‘eval_exps args (s with clock := fuel) = (vv,s1)’]
    \\ Cases_on ‘vv = Stop Crash’ \\ gvs []
    \\ disch_then drule
    \\ ‘state_rel fs (s with clock := fuel) t’ by gvs [state_rel_def]
    \\ rpt $ disch_then drule
    \\ disch_then $ qspec_then ‘fuel − s1'.clock’ mp_tac
    \\ impl_tac >- gvs [flatten_append, code_in_append]
    \\ strip_tac
    \\ irule_at Any steps_trans
    \\ first_assum $ irule_at $ Pos hd
    \\ reverse $ Cases_on ‘vv’ >- gvs [] \\ gvs []
    \\ gvs [exps_res_rel_def]
    \\ rename1 ‘LIST_REL (v_inv pmap) argvs ws’
    \\ imp_res_tac c_exps_length
    \\ gvs [c_tail_call_def, app_list_length_thm, flatten_append, code_in_append]
    (* the callee must exist and its parameters must match the arguments *)
    \\ Cases_on ‘find_fun fname s1.funs’ \\ gvs []
    \\ rename [‘find_fun fname s1.funs = SOME pb’]
    \\ PairCases_on ‘pb’ \\ gvs []
    \\ rename [‘find_fun fname s1.funs = SOME (params,body)’]
    \\ Cases_on ‘LENGTH params = LENGTH argvs’ \\ gvs []
    \\ Cases_on ‘ALL_DISTINCT params’ \\ gvs []
    \\ imp_res_tac eval_exps_pure \\ gvs []
    (* the tick: no clock left means TimeOut, and no fuel to account for *)
    \\ Cases_on ‘fuel = 0’ \\ gvs [tick_def]
    >- (qexistsl_tac [‘(State t1,0)’,‘pmap’]
        \\ imp_res_tac state_rel_R14
        \\ gvs [pmap_subsume_refl, cmd_res_rel_def]
        \\ once_rewrite_tac [steps_cases] \\ simp []
        \\ metis_tac [r14_mono_IMP_pmap_in_bounds])
    (* move the arguments into the registers the callee expects *)
    \\ ‘∃r15. t1.regs R15 = SOME r15’ by
         (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def]
          \\ metis_tac [])
    \\ ‘code_rel fs s.funs t1.instructions’ by
         (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def])
    \\ ‘EVEN (LENGTH (curr ⧺ rest))’ by fs [EVEN_ADD, ODD_EVEN]
    \\ ‘LENGTH args = LENGTH ws’ by
         (imp_res_tac eval_exps_LENGTH
          \\ imp_res_tac listTheory.LIST_REL_LENGTH \\ gvs [])
    \\ qspecl_then [‘args’,‘vs’,‘ws’,‘t1’,‘curr ⧺ rest’,‘fuel − s1'.clock’,
                    ‘fs’,‘s.funs’,‘r15’] mp_tac c_pops_steps
    \\ impl_tac >- (imp_res_tac steps_inst \\ gvs [])
    \\ strip_tac
    >- (* more than five arguments: a compiler limitation, exit 4 *)
     (qexistsl_tac [‘(Halt 4w t1.output,fuel − s1'.clock)’,‘pmap’]
      \\ gvs [pmap_subsume_refl]
      \\ ‘t1.output = s.output’ by
           (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def])
      \\ gvs [AllCaseEqs(), bind_def, FLOOKUP_UPDATE]
      \\ imp_res_tac eval_cmd_output \\ gvs [])
    (* the arguments are in the registers now *)
    \\ qabbrev_tac ‘t2 = t1 with <|regs := pops_regs ws t1.regs;
                                  pc := t1.pc + app_list_length (c_pops args vs);
                                  stack := curr ⧺ rest|>’
    \\ ‘t2.pc = LENGTH (flatten asms []) + (LENGTH (flatten (c_pops args vs) []) + t.pc) ∧
        t2.stack = curr ⧺ rest ∧ t2.instructions = t1.instructions ∧
        t2.memory = t1.memory ∧ t2.input = t1.input ∧ t2.output = t1.output ∧
        t2.regs = pops_regs ws t1.regs’ by
         gvs [Abbr‘t2’, app_list_length_thm]
    (* where the callee's code lives -- done before the frame is dropped, so
       that gvs still has ‘rest’ to work with rather than ‘t2a.stack’ *)
    \\ qpat_x_assum ‘code_rel fs s.funs t1.instructions’ mp_tac
    \\ rewrite_tac [code_rel_def] \\ strip_tac
    \\ first_x_assum drule \\ strip_tac
    \\ imp_res_tac lookup_eq_ALOOKUP
    \\ Cases_on ‘eval_cmd body
                   (s with <|vars := FEMPTY |++ ZIP (params,argvs); clock := fuel − 1|>)’
    \\ rename [‘eval_cmd body _ = (res2,s2)’]
    (* split the callee's code into its entry sequence and its body *)
    \\ qspecl_then [‘fname’,‘params’,‘body’,‘pos’,‘fs’] strip_assume_tac c_fundef_parts
    \\ gvs []
    \\ ‘code_in (lookup fname fs) (flatten (asm0 +++ asm1) []) t1.instructions ∧
        code_in l0 (flatten asm3 []) t1.instructions’ by
         (qpat_x_assum ‘code_in _ (flatten (asm0 +++ asm1 +++ asm3) []) _’ mp_tac
          \\ imp_res_tac c_pushes_length \\ imp_res_tac c_bdrs_asm
          \\ gvs [app_list_length_def] \\ simp code_layout)
    \\ ‘∃w. t1.regs RAX = SOME w’ by (fs [has_stack_def] \\ metis_tac [])
    \\ ‘ws ≠ [] ⇒ LAST ws = w’ by
         (strip_tac
          \\ qspecl_then [‘t1’,‘ws’,‘curr ⧺ rest’,‘w’] mp_tac has_stack_LAST
          \\ gvs [])
    (* Add_RSP drops our own frame: the callee will return straight to our
       caller, whose return address is now on top of the stack *)
    \\ ‘LENGTH vs = LENGTH curr’ by fs [env_ok_def]
    \\ qabbrev_tac ‘t2a = set_stack rest (inc t2)’
    \\ ‘step (State t2) (State t2a)’ by
         (qunabbrev_tac ‘t2a’ \\ irule (cj 13 step_rules)
          \\ qexists_tac ‘curr’
          \\ imp_res_tac steps_inst
          \\ gvs [fetch_def, flatten_def, code_in_def])
    \\ ‘t2a.pc = t2.pc + 1 ∧ t2a.stack = rest ∧ t2a.regs = pops_regs ws t1.regs ∧
        t2a.instructions = t1.instructions ∧ t2a.memory = t1.memory ∧
        t2a.input = t1.input ∧ t2a.output = t1.output’ by
         gvs [Abbr‘t2a’, set_stack_def, inc_def]
    \\ qabbrev_tac ‘t3 = set_pc (lookup fname fs) t2a’
    \\ ‘fetch t2a = SOME (Jump Always (lookup fname fs))’ by
         (imp_res_tac steps_inst
          \\ gvs [fetch_def, flatten_def, code_in_def])
    (* run the entry code *)
    \\ ‘t3.pc = lookup fname fs ∧ t3.regs = pops_regs ws t1.regs ∧
        t3.stack = rest ∧ t3.instructions = t1.instructions ∧
        t3.memory = t1.memory ∧ t3.input = t1.input ∧ t3.output = t1.output’ by
         gvs [Abbr‘t3’, set_pc_def]
    \\ ‘t3.regs RAX = SOME w’ by gvs [pops_regs_other, ARGS_REGS_def]
    \\ qspecl_then [‘params’,‘body’,‘lookup fname fs’,‘t3’,‘asm0’,‘vs_bind1’,‘asm1’,
                    ‘vs1’,‘l0’,‘ws’,‘w’,‘fuel − 1 − s2.clock’,‘t1.regs’] mp_tac
         c_fundef_entry_steps
    \\ impl_tac >- (imp_res_tac listTheory.LIST_REL_LENGTH \\ gvs [])
    \\ strip_tac
    \\ qmatch_asmsub_abbrev_tac ‘steps (State t3,_) (State t4,_)’
    \\ ‘t4.pc = l0 ∧ t4.regs = t3.regs ∧ t4.instructions = t1.instructions ∧
        t4.memory = t1.memory ∧ t4.input = t1.input ∧ t4.output = t1.output ∧
        t4.stack = TL (if ws = [] then [Word w] else MAP Word (REVERSE ws)) ⧺
                   REPLICATE (LENGTH vs_bind1) Undefined ⧺ rest’ by
         gvs [Abbr‘t4’]
    \\ qpat_x_assum ‘Abbrev (t4 = _)’ kall_tac
    (* the callee's frame sits directly on our caller's return address *)
    \\ qabbrev_tac ‘new_curr =
         (if ws = [] then [Word w] else MAP Word (REVERSE ws)) ⧺
         REPLICATE (LENGTH vs_bind1) Undefined’
    \\ ‘has_stack t4 (new_curr ⧺ rest)’ by
         (‘∃ys. (if ws = [] then [Word w] else MAP Word (REVERSE ws)) = Word w :: ys’ by
            (irule args_frame \\ gvs [])
          \\ gvs [Abbr‘new_curr’, has_stack_def])
    \\ imp_res_tac c_pushes_vs
    \\ ‘env_ok (FEMPTY |++ ZIP (params,argvs)) (vs1 ⧺ vs_bind1) new_curr pmap’ by
         (gvs [Abbr‘new_curr’] \\ irule env_ok_callee
          \\ imp_res_tac listTheory.LIST_REL_LENGTH \\ gvs [])
    \\ ‘LENGTH new_curr = LENGTH vs1 + LENGTH vs_bind1’ by
         (imp_res_tac listTheory.LIST_REL_LENGTH
          \\ gvs [Abbr‘new_curr’, LENGTH_push_vs]
          \\ rw [] \\ gvs [])
    \\ ‘ODD (LENGTH new_curr)’ by (imp_res_tac c_bdrs_ODD \\ gvs [])
    \\ ‘binders_ok body (vs1 ⧺ vs_bind1)’ by
         (irule binders_ok_c_bdrs \\ metis_tac [])
    (* run the body, with one less unit of clock *)
    \\ ‘goal_cmd body (fuel − 1)’ by (first_x_assum irule \\ gvs [])
    \\ qpat_x_assum ‘goal_cmd body _’ mp_tac
    \\ rewrite_tac [goal_cmd_def]
    \\ disch_then (qspecl_then
         [‘s with <|vars := FEMPTY |++ ZIP (params,argvs); clock := fuel − 1|>’,
          ‘s2’,‘res2’,‘t4’,‘vs1 ⧺ vs_bind1’,‘fs’,‘asm3’,‘l2’,‘new_curr’,
          ‘rest’,‘pmap’] mp_tac)
    \\ impl_tac
    >- (gvs []
        \\ conj_tac >- (strip_tac \\ gvs [])
        \\ conj_tac
        >- (irule state_rel_step
            \\ qpat_assum ‘state_rel _ _ t1’ $ irule_at Any
            \\ imp_res_tac state_rel_IMP
            \\ gvs [pops_regs_other, ARGS_REGS_def])
        \\ imp_res_tac state_rel_IMP
        \\ gvs [pops_regs_other, ARGS_REGS_def]
        \\ metis_tac [r14_mono_IMP_pmap_in_bounds])
    \\ strip_tac
    (* the Jump into the callee is what consumes the clock tick *)
    \\ ‘s1'.clock = s2.clock ∧ s1'.output = s2.output’ by
         gvs [AllCaseEqs(), bind_def, FLOOKUP_UPDATE]
    \\ ‘s2.clock ≤ fuel − 1’ by (imp_res_tac eval_cmd_clock \\ gvs [])
    \\ ‘fuel − s1'.clock = fuel − 1 − s2.clock + 1’ by gvs []
    \\ ‘steps (State t2,fuel − 1 − s2.clock + 1) (State t2a,fuel − 1 − s2.clock + 1)’ by
         (irule (cj 2 steps_rules) \\ simp [])
    \\ ‘steps (State t2a,fuel − 1 − s2.clock + 1) (State t3,fuel − 1 − s2.clock)’ by
         (qunabbrev_tac ‘t3’ \\ irule steps_Jump_tick \\ simp [])
    \\ ‘steps (State t2,fuel − s1'.clock) (State t3,fuel − 1 − s2.clock)’ by
         (qpat_x_assum ‘fuel − s1'.clock = _’ (fn th => rewrite_tac [th])
          \\ metis_tac [steps_trans])
    \\ ‘steps (State t3,fuel − 1 − s2.clock) outcome’ by
         (irule steps_trans \\ qexists_tac ‘(State t4,fuel − 1 − s2.clock)’ \\ gvs [])
    \\ ‘steps (State t1,fuel − s1'.clock) outcome’ by metis_tac [steps_trans]
    (* this equation has done its job; kept, it is a looping rewrite once
       s1'.clock has been replaced by s2.clock *)
    \\ qpat_x_assum ‘fuel − s1'.clock = _’ kall_tac
    \\ qpat_x_assum ‘steps (State t2,fuel − 1 − s2.clock + 1) _’ kall_tac
    \\ qpat_x_assum ‘steps (State t2a,fuel − 1 − s2.clock + 1) _’ kall_tac
    (* R14 is untouched all the way from here into the callee *)
    \\ ‘t4.regs R14 = t1.regs R14’ by gvs [pops_regs_other, ARGS_REGS_def]
    \\ PairCases_on ‘outcome’ \\ reverse (Cases_on ‘outcome0’) \\ gvs []
    (* the callee halted the machine -- two goals, one per exit code *)
    >- (rename [‘Halt ec out’]
        \\ qexistsl_tac [‘(Halt ec out,outcome1)’,‘pmap1’] \\ gvs [])
    >- (rename [‘Halt ec out’]
        \\ qexistsl_tac [‘(Halt ec out,outcome1)’,‘pmap1’] \\ gvs [])
    \\ rename1 ‘cmd_res_rel _ _ _ _ t5 _ _’
    \\ ‘r14_mono (t.regs R14) (t5.regs R14)’ by metis_tac [r14_mono_trans]
    (* Only these facts matter from here on.  Carrying the other ninety into
       the case analysis below makes simp diverge. *)
    \\ qpat_x_assum ‘_ = (v1,s')’ mp_tac
    \\ qpat_x_assum ‘_ = (res,s1')’ mp_tac
    \\ qpat_x_assum ‘res ≠ Stop Crash’ mp_tac
    \\ qpat_x_assum ‘s1'.clock = s2.clock’ mp_tac
    \\ qpat_x_assum ‘s1'.output = s2.output’ mp_tac
    \\ qpat_x_assum ‘state_rel fs s2 t5’ mp_tac
    \\ qpat_x_assum ‘r14_mono (t.regs R14) (t5.regs R14)’ mp_tac
    \\ qpat_x_assum ‘pmap_in_bounds pmap1 _’ mp_tac
    \\ qpat_x_assum ‘pmap_ok pmap1’ mp_tac
    \\ qpat_x_assum ‘pmap_subsume pmap pmap1’ mp_tac
    \\ qpat_x_assum ‘cmd_res_rel _ _ _ _ t5 _ _’ mp_tac
    \\ qpat_x_assum ‘steps (State t1,_) (State t5,0)’ mp_tac
    \\ rpt (pop_assum kall_tac)
    \\ rpt strip_tac
    (* The callee's outcome is ours: a returned value is passed straight on
       (that is what makes this a tail call), and anything else propagates.
       Done in isolation -- simp diverges on the two nested case equations
       when they are left sitting in the main goal's context. *)
    \\ sg ‘(∃v. res2 = Stop (Return v) ∧ res = Stop (Return v) ∧
              s1' = s2 with vars := s.vars⟨n ↦ v⟩) ∨
         (res2 = Stop TimeOut ∧ res = Stop TimeOut ∧ s1' = s2) ∨
         (res2 = Stop Abort ∧ res = Stop Abort ∧ s1' = s2)’
    >- (qpat_x_assum ‘res ≠ Stop Crash’ mp_tac
        \\ qpat_x_assum ‘_ = (res,s1')’ mp_tac
        \\ qpat_x_assum ‘_ = (v1,s')’ mp_tac
        \\ rpt (pop_assum kall_tac)
        \\ rpt TOP_CASE_TAC \\ rpt strip_tac
        \\ gvs [bind_def, FLOOKUP_UPDATE])
    \\ qpat_x_assum ‘_ = (v1,s')’ kall_tac
    \\ qpat_x_assum ‘_ = (res,s1')’ kall_tac
    \\ gvs []
    >- (* the callee returned: its Ret returns directly to our caller *)
     (qexistsl_tac [‘(State t5,0)’,‘pmap1’]
      \\ gvs [cmd_res_rel_def, state_rel_def]
      \\ metis_tac [])
    >- (* the callee timed out *)
     (qexistsl_tac [‘(State t5,0)’,‘pmap1’]
      \\ gvs [cmd_res_rel_def])
    (* the callee aborted: it cannot have come back in a State *)
    \\ fs [cmd_res_rel_def])
  \\ strip_tac \\ gvs []
  \\ ‘code_in t.pc (flatten asm1 []) t.instructions ∧
      code_in l1' (flatten asm2 []) t.instructions’ by
   (imp_res_tac c_cmd_length
    \\ qpat_x_assum ‘code_in _ _ _’ mp_tac
    \\ simp [flatten_def, Once flatten_acc, code_in_append, LENGTH_flatten])
  \\ qpat_x_assum ‘eval_cmd (Seq _ _) _ = _’
       (mp_tac o SIMP_RULE std_ss [Once eval_cmd_def])
  \\ Cases_on ‘eval_cmd c (s with clock := fuel)’ \\ simp []
  \\ rename [‘eval_cmd c _ = (res0,s0)’]
  \\ strip_tac
  \\ ‘res0 ≠ Stop Crash’ by (Cases_on ‘res0’ \\ gvs [])
  \\ qpat_x_assum ‘goal_cmd c fuel’ mp_tac
  \\ rewrite_tac [goal_cmd_def]
  \\ disch_then (qspecl_then [‘s’,‘s0’,‘res0’,‘t’,‘vs’,‘fs’,‘asm1’,‘l1'’,
                              ‘curr’,‘rest’,‘pmap’] mp_tac)
  \\ impl_tac >- fs [binders_ok_def]
  \\ strip_tac
  \\ ‘s0.clock ≤ fuel’ by (imp_res_tac eval_cmd_clock \\ fs [])
  \\ ‘s1.clock ≤ s0.clock’ by
       (Cases_on ‘res0’ \\ gvs [] \\ imp_res_tac eval_cmd_clock \\ fs [])
  \\ ‘fuel − s0.clock + (s0.clock − s1.clock) = fuel − s1.clock’ by fs []
  \\ PairCases_on ‘outcome’ \\ reverse (Cases_on ‘outcome0’)
  >- (* the first command already halted the machine *)
   (rename [‘Halt ec out’]
    \\ qexistsl_tac [‘(Halt ec out, outcome1 + (s0.clock − s1.clock))’, ‘pmap1’]
    \\ conj_tac
    >- (qspecl_then [‘State t’,‘fuel − s0.clock’,‘Halt ec out’,‘outcome1’,
                     ‘s0.clock − s1.clock’] mp_tac steps_add_fuel \\ fs [])
    \\ fs [] \\ Cases_on ‘res0’ \\ gvs []
    \\ imp_res_tac eval_cmd_output
    \\ metis_tac [rich_listTheory.IS_PREFIX_TRANS])
  \\ gvs []
  \\ rename [‘steps _ (State t1,_)’]
  \\ reverse (Cases_on ‘res0’) \\ gvs []
  >- (* the first command stopped: its outcome is already the answer *)
   (rename [‘eval_cmd c _ = (Stop r,s0)’]
    \\ qexistsl_tac [‘(State t1,0)’, ‘pmap1’] \\ fs []
    \\ Cases_on ‘r’ \\ fs [cmd_res_rel_def] \\ metis_tac [])
  (* the first command continued: run the second from t1 *)
  \\ fs [cmd_res_rel_def]
  \\ rename [‘env_ok s0.vars vs curr1 pmap1’]
  \\ ‘goal_cmd c' s0.clock’ by
       (Cases_on ‘s0.clock = fuel’ \\ gvs [] \\ first_x_assum irule \\ fs [])
  \\ pop_assum mp_tac \\ rewrite_tac [goal_cmd_def]
  \\ disch_then (qspecl_then [‘s0’,‘s1’,‘res’,‘t1’,‘vs’,‘fs’,‘asm2’,‘l1’,
                              ‘curr1’,‘rest’,‘pmap1’] mp_tac)
  \\ impl_tac
  >- (‘(s0 with clock := s0.clock) = s0’ by
        fs [imp_source_semanticsTheory.state_component_equality]
      \\ fs [binders_ok_def] \\ imp_res_tac steps_inst \\ fs []
      \\ qpat_x_assum ‘env_ok s.vars vs curr pmap’ mp_tac
      \\ qpat_x_assum ‘env_ok s0.vars vs curr1 pmap1’ mp_tac
      \\ rewrite_tac [env_ok_def] \\ rpt strip_tac \\ fs [])
  \\ strip_tac
  \\ rename [‘steps (State t1,_) outcome’]
  \\ qexistsl_tac [‘outcome’, ‘pmap1'’]
  \\ ‘steps (State t,fuel − s1.clock) (State t1,s0.clock − s1.clock)’ by
       (qspecl_then [‘State t’,‘fuel − s0.clock’,‘State t1’,‘0’,
                     ‘s0.clock − s1.clock’] mp_tac steps_add_fuel \\ fs [])
  \\ conj_tac >- metis_tac [steps_trans]
  \\ conj_tac >- fs []
  \\ conj_tac >- metis_tac [pmap_subsume_trans]
  \\ PairCases_on ‘outcome’ \\ Cases_on ‘outcome0’ \\ fs [cmd_res_rel_def]
  \\ qpat_x_assum ‘state_rel fs s0 t1’ mp_tac
  \\ rewrite_tac [state_rel_def] \\ strip_tac
  \\ metis_tac [r14_mono_trans]
QED

Resume c_cmd_correct[Assign]:
  qx_genl_tac [‘vn’,‘e’]
  \\ rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs []
  \\ qpat_x_assum ‘eval_cmd (Assign _ _) _ = _’ mp_tac
  \\ simp [Once eval_cmd_def, bind_def]
  \\ Cases_on ‘eval_exp e (s with clock := fuel)’ \\ simp []
  \\ rename [‘eval_exp e _ = (eres,se)’]
  \\ strip_tac
  \\ ‘∃v. eres = Cont v’ by (Cases_on ‘eres’ \\ not_crash_tac)
  \\ imp_res_tac eval_exp_pure \\ gvs []
  (* the expression code, then the one or two instructions of c_assign *)
  \\ ‘code_in t.pc (flatten asm1 []) t.instructions ∧
      code_in l1' (flatten asm2 []) t.instructions’ by
       (imp_res_tac c_exp_length
        \\ qpat_x_assum ‘code_in t.pc _ _’ mp_tac
        \\ simp code_layout)
  \\ drule_all has_stack_cons \\ strip_tac \\ gvs []
  (* run the expression *)
  \\ qspec_then ‘e’ mp_tac c_exp_correct
  \\ rewrite_tac [goal_exp_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘0’, ‘Cont v’, ‘t’,
        ‘vs’, ‘fs’, ‘asm1’, ‘l1'’, ‘Word hw::ct’, ‘rest’, ‘pmap’] mp_tac)
  \\ impl_tac >- (imp_res_tac c_exp_length \\ fs [state_rel_def])
  \\ strip_tac
  \\ fs [exp_res_rel_def]
  \\ rename [‘steps (State t,0) (State t1,0)’]
  \\ imp_res_tac steps_inst
  (* store the result into the variable's frame slot *)
  \\ ‘MEM (SOME vn) vs’ by fs [binders_ok_def]
  \\ ‘LENGTH vs = LENGTH (Word hw::ct)’ by fs [env_ok_def]
  \\ drule c_assign_steps
  \\ disch_then (qspecl_then [‘t1’,‘w’,‘hw’,‘ct’,‘rest’,‘0’] mp_tac)
  \\ impl_tac >- fs [has_stack_def]
  \\ strip_tac
  \\ qexistsl_tac [‘(State t2, 0)’, ‘pmap’]
  \\ conj_tac >- metis_tac [steps_trans]
  \\ imp_res_tac state_rel_R14
  \\ fs [pmap_subsume_refl, cmd_res_rel_def]
  \\ rpt conj_tac
  >- (irule state_rel_step
      \\ qpat_assum ‘state_rel _ _ t1’ $ irule_at Any
      \\ imp_res_tac state_rel_IMP \\ gvs [])
  >- (fs [] \\ metis_tac [r14_mono_IMP_pmap_in_bounds])
  \\ qexists_tac ‘LUPDATE (Word w) (index_of vn 0 vs) (Word hw::ct)’
  \\ fs [] \\ irule env_ok_assign \\ fs []
QED

Resume c_cmd_correct[Update]:
  qx_genl_tac [‘ea’,‘eb’,‘ev’]
  \\ rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs [c_store_def]
  \\ qpat_x_assum ‘eval_cmd (Update _ _ _) _ = _’ mp_tac
  \\ simp [Once eval_cmd_def, bind_def]
  \\ strip_tac
  (* all three expressions must succeed: eval_exp only ever stops with Crash *)
  \\ Cases_on ‘eval_exp ea (s with clock := fuel)’ \\ fs []
  \\ rename [‘eval_exp ea _ = (ra,sa)’]
  \\ ‘∃vp. ra = Cont vp’ by (Cases_on ‘ra’ \\ not_crash_tac)
  \\ imp_res_tac eval_exp_pure \\ gvs []
  \\ Cases_on ‘eval_exp eb (s with clock := fuel)’ \\ fs []
  \\ rename [‘eval_exp eb _ = (rb,sb)’]
  \\ ‘∃vo. rb = Cont vo’ by (Cases_on ‘rb’ \\ not_crash_tac)
  \\ imp_res_tac eval_exp_pure \\ gvs []
  \\ Cases_on ‘eval_exp ev (s with clock := fuel)’ \\ fs []
  \\ rename [‘eval_exp ev _ = (rv,sv)’]
  \\ ‘∃vw. rv = Cont vw’ by (Cases_on ‘rv’ \\ not_crash_tac)
  \\ imp_res_tac eval_exp_pure \\ gvs []
  (* and the first two must be a pointer and a word, else update crashes *)
  \\ ‘∃p wo. vp = Pointer p ∧ vo = Word wo’ by
       (Cases_on ‘vp’ \\ Cases_on ‘vo’
        \\ gvs [imp_source_semanticsTheory.update_def])
  \\ gvs [imp_source_semanticsTheory.update_def, AllCaseEqs(),
          imp_source_semanticsTheory.update_block_def]
  \\ rename [‘oEL p s.memory = SOME blk’]
  (* the three expression fragments, then the five instructions of c_store *)
  \\ ‘code_in t.pc (flatten asm1 []) t.instructions ∧
      code_in l1' (flatten asm2 []) t.instructions ∧
      code_in l2 (flatten asm3 []) t.instructions ∧
      oEL l3 t.instructions = SOME (Pop RDI) ∧
      oEL (l3 + 1) t.instructions = SOME (Pop RDX) ∧
      oEL (l3 + 2) t.instructions = SOME (Add RDI RDX) ∧
      oEL (l3 + 3) t.instructions = SOME (Store RAX RDI 0w) ∧
      oEL (l3 + 4) t.instructions = SOME (Pop RAX)’ by
       (imp_res_tac c_exp_length
        \\ qpat_x_assum ‘code_in t.pc _ _’ mp_tac
        \\ simp code_layout)
  \\ drule_all has_stack_cons \\ strip_tac \\ gvs []
  (* run the address expression *)
  \\ qspec_then ‘ea’ mp_tac c_exp_correct
  \\ rewrite_tac [goal_exp_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘0’, ‘Cont (Pointer p)’,
        ‘t’, ‘vs’, ‘fs’, ‘asm1’, ‘l1'’, ‘Word hw::ct’, ‘rest’, ‘pmap’] mp_tac)
  \\ impl_tac >- fs [state_rel_def]
  \\ strip_tac
  \\ gvs [exp_res_rel_def, v_inv_def]
  \\ rename [‘steps (State t,0) (State t1,0)’]
  \\ imp_res_tac steps_inst
  (* run the offset expression, one scratch slot deeper *)
  \\ rename [‘pmap p = SOME (wp,plen)’]
  \\ ‘plen = LENGTH blk’ by
       (qpat_x_assum ‘mem_inv pmap t1.memory s.memory’ mp_tac
        \\ rewrite_tac [mem_inv_def]
        \\ disch_then (qspecl_then [‘p’,‘blk’] mp_tac)
        \\ fs [])
  \\ gvs []
  \\ qspec_then ‘eb’ mp_tac c_exp_correct
  \\ rewrite_tac [goal_exp_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘0’, ‘Cont (Word wo)’,
        ‘t1’, ‘NONE::vs’, ‘fs’, ‘asm2’, ‘l2’, ‘Word wp::Word hw::ct’, ‘rest’,
        ‘pmap’] mp_tac)
  \\ impl_tac
  >- (fs [has_stack_def] \\ irule env_ok_NONE \\ fs [])
  \\ strip_tac
  \\ gvs [exp_res_rel_def, v_inv_def]
  \\ rename [‘steps (State t1,0) (State t2,0)’]
  \\ imp_res_tac steps_inst
  (* run the value expression, two scratch slots deep *)
  \\ qspec_then ‘ev’ mp_tac c_exp_correct
  \\ rewrite_tac [goal_exp_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘0’, ‘Cont vw’,
        ‘t2’, ‘NONE::NONE::vs’, ‘fs’, ‘asm3’, ‘l3’,
        ‘Word wo::Word wp::Word hw::ct’, ‘rest’, ‘pmap’] mp_tac)
  \\ impl_tac
  >- (fs [has_stack_def]
      \\ irule env_ok_NONE \\ irule env_ok_NONE \\ fs [])
  \\ strip_tac
  \\ gvs [exp_res_rel_def]
  \\ rename [‘steps (State t2,0) (State t3,0)’]
  \\ rename [‘v_inv pmap vw wv’]
  \\ imp_res_tac steps_inst
  \\ ‘t3.regs RAX = SOME wv ∧
      t3.stack = Word wo :: Word wp :: Word hw :: (ct ⧺ rest)’ by
       fs [has_stack_def]
  (* the five instructions of c_store, run in one go so that the scratch
     states t4..t8 do not clutter the rest of the proof *)
  \\ ‘∃t8. steps (State t3,0) (State t8,0) ∧
          t8.stack = ct ⧺ rest ∧ t8.pc = t3.pc + 5 ∧ t8.regs RAX = SOME hw ∧
          t8.memory = ((wp + n2w (w2n wo DIV 8 * 8)) =+ SOME (SOME wv)) t3.memory ∧
          t8.instructions = t3.instructions ∧
          t8.input = t3.input ∧ t8.output = t3.output ∧
          t8.regs R12 = t3.regs R12 ∧ t8.regs R13 = t3.regs R13 ∧
          t8.regs R14 = t3.regs R14 ∧ t8.regs R15 = t3.regs R15’ by
   ((* Pop RDI: the offset *)
    qabbrev_tac ‘t4 = set_stack (Word wp :: Word hw :: (ct ⧺ rest))
                          (write_reg RDI wo (inc t3))’
    \\ ‘step (State t3) (State t4)’ by
         (qunabbrev_tac ‘t4’ \\ irule (cj 9 step_rules)
          \\ fs [fetch_def])
    \\ ‘t4.stack = Word wp :: Word hw :: (ct ⧺ rest) ∧ t4.pc = t3.pc + 1 ∧
        t4.regs RDI = SOME wo ∧ t4.regs RAX = SOME wv ∧
        t4.memory = t3.memory ∧ t4.instructions = t3.instructions ∧
        t4.input = t3.input ∧ t4.output = t3.output ∧
        t4.regs R12 = t3.regs R12 ∧ t4.regs R13 = t3.regs R13 ∧
        t4.regs R14 = t3.regs R14 ∧ t4.regs R15 = t3.regs R15’ by
         fs [Abbr‘t4’, set_stack_def, write_reg_def, inc_def,
             combinTheory.APPLY_UPDATE_THM]
    (* Pop RDX: the base address *)
    \\ qabbrev_tac ‘t5 = set_stack (Word hw :: (ct ⧺ rest))
                          (write_reg RDX wp (inc t4))’
    \\ ‘step (State t4) (State t5)’ by
         (qunabbrev_tac ‘t5’ \\ irule (cj 9 step_rules)
          \\ fs [fetch_def])
    \\ ‘t5.stack = Word hw :: (ct ⧺ rest) ∧ t5.pc = t3.pc + 2 ∧
        t5.regs RDI = SOME wo ∧ t5.regs RDX = SOME wp ∧ t5.regs RAX = SOME wv ∧
        t5.memory = t3.memory ∧ t5.instructions = t3.instructions ∧
        t5.input = t3.input ∧ t5.output = t3.output ∧
        t5.regs R12 = t3.regs R12 ∧ t5.regs R13 = t3.regs R13 ∧
        t5.regs R14 = t3.regs R14 ∧ t5.regs R15 = t3.regs R15’ by
         fs [Abbr‘t5’, set_stack_def, write_reg_def, inc_def,
             combinTheory.APPLY_UPDATE_THM]
    (* Add RDI RDX: base + offset *)
    \\ qabbrev_tac ‘t6 = write_reg RDI (wo + wp) (inc t5)’
    \\ ‘step (State t5) (State t6)’ by
         (qunabbrev_tac ‘t6’ \\ irule (cj 3 step_rules)
          \\ fs [fetch_def])
    \\ ‘t6.stack = Word hw :: (ct ⧺ rest) ∧ t6.pc = t3.pc + 3 ∧
        t6.regs RDI = SOME (wo + wp) ∧ t6.regs RAX = SOME wv ∧
        t6.memory = t3.memory ∧ t6.instructions = t3.instructions ∧
        t6.input = t3.input ∧ t6.output = t3.output ∧
        t6.regs R12 = t3.regs R12 ∧ t6.regs R13 = t3.regs R13 ∧
        t6.regs R14 = t3.regs R14 ∧ t6.regs R15 = t3.regs R15’ by
         fs [Abbr‘t6’, set_stack_def, write_reg_def, inc_def,
             combinTheory.APPLY_UPDATE_THM]
    (* the offset is a whole number of words, so RDI holds base + n2w (off * 8);
       the two intermediate forms are dropped again -- leaving both shapes of
       the address in the context makes the simp calls below diverge *)
    \\ ‘w2n wo DIV 8 * 8 = w2n wo’ by
         (qspec_then ‘8’ mp_tac arithmeticTheory.DIVISION \\ simp []
          \\ disch_then (qspec_then ‘w2n wo’ mp_tac) \\ fs [])
    \\ ‘t6.regs RDI = SOME (wp + n2w (w2n wo DIV 8 * 8))’ by
         simp [n2w_w2n, AC WORD_ADD_ASSOC WORD_ADD_COMM]
    \\ qpat_x_assum ‘w2n wo DIV 8 * 8 = w2n wo’ kall_tac
    \\ qpat_x_assum ‘t6.regs RDI = SOME (wo + wp)’ kall_tac
    (* Store RAX RDI 0w *)
    \\ ‘fetch t6 = SOME (Store RAX RDI 0w)’ by
         simp [fetch_def]
    \\ qabbrev_tac ‘t7 = inc (t6 with memory :=
          ((wp + n2w (w2n wo DIV 8 * 8)) =+ SOME (SOME wv)) t6.memory)’
    \\ ‘step (State t6) (State t7)’ by
         (qunabbrev_tac ‘t7’
          \\ qspecl_then
               [‘t6’,‘pmap’,‘s.memory’,‘p’,‘wp’,‘blk’,‘w2n wo DIV 8’,‘wv’]
               mp_tac c_store_step
          \\ simp [])
    \\ ‘t7.stack = Word hw :: (ct ⧺ rest) ∧ t7.pc = t3.pc + 4 ∧
        t7.memory = ((wp + n2w (w2n wo DIV 8 * 8)) =+ SOME (SOME wv)) t3.memory ∧
        t7.instructions = t3.instructions ∧
        t7.input = t3.input ∧ t7.output = t3.output ∧
        t7.regs R12 = t3.regs R12 ∧ t7.regs R13 = t3.regs R13 ∧
        t7.regs R14 = t3.regs R14 ∧ t7.regs R15 = t3.regs R15’ by
         fs [Abbr‘t7’, inc_def]
    (* Pop RAX: restore the frame top *)
    \\ qabbrev_tac ‘t8 = set_stack (ct ⧺ rest) (write_reg RAX hw (inc t7))’
    \\ ‘step (State t7) (State t8)’ by
         (qunabbrev_tac ‘t8’ \\ irule (cj 9 step_rules)
          \\ fs [fetch_def])
    \\ ‘t8.stack = ct ⧺ rest ∧ t8.pc = t3.pc + 5 ∧ t8.regs RAX = SOME hw ∧
        t8.memory = ((wp + n2w (w2n wo DIV 8 * 8)) =+ SOME (SOME wv)) t3.memory ∧
        t8.instructions = t3.instructions ∧
        t8.input = t3.input ∧ t8.output = t3.output ∧
        t8.regs R12 = t3.regs R12 ∧ t8.regs R13 = t3.regs R13 ∧
        t8.regs R14 = t3.regs R14 ∧ t8.regs R15 = t3.regs R15’ by
         fs [Abbr‘t8’, set_stack_def, write_reg_def, inc_def,
             combinTheory.APPLY_UPDATE_THM]
    \\ qexists_tac ‘t8’
    \\ conj_tac
    >- (irule steps_unroll \\ qexists_tac ‘State t4’ \\ conj_tac >- fs []
        \\ irule steps_unroll \\ qexists_tac ‘State t5’ \\ conj_tac >- fs []
        \\ irule steps_unroll \\ qexists_tac ‘State t6’ \\ conj_tac >- fs []
        \\ irule steps_unroll \\ qexists_tac ‘State t7’ \\ conj_tac >- fs []
        \\ irule (cj 2 steps_rules) \\ fs [])
    \\ fs [])
  (* the written address lies below R14, so the free area is untouched *)
  \\ ‘∃r14a. t.regs R14 = SOME r14a’ by metis_tac [state_rel_R14]
  \\ ‘∃r14b. t3.regs R14 = SOME r14b’ by metis_tac [state_rel_R14]
  \\ ‘r14_mono (t.regs R14) (t3.regs R14)’ by metis_tac [r14_mono_trans]
  \\ ‘r14_mono (SOME r14a) (SOME r14b)’ by
       (qpat_x_assum ‘r14_mono (t.regs R14) (t3.regs R14)’ mp_tac \\ simp [])
  \\ ‘pmap_in_bounds pmap (SOME r14b)’ by
       (fs [] \\ metis_tac [r14_mono_IMP_pmap_in_bounds])
  \\ ‘wp + n2w (w2n wo DIV 8 * 8) <+ r14b’ by
       (qpat_assum ‘pmap_in_bounds pmap (SOME r14b)’ mp_tac
        \\ rewrite_tac [pmap_in_bounds_def]
        \\ disch_then (qspecl_then [‘p’,‘wp’,‘LENGTH blk’,‘r14b’] mp_tac)
        \\ fs [])
  \\ ‘steps (State t,0) (State t3,0)’ by metis_tac [steps_trans]
  \\ ‘mem_inv pmap (((wp + n2w (w2n wo DIV 8 * 8)) =+ SOME (SOME wv)) t3.memory)
        (LUPDATE (LUPDATE (SOME vw) (w2n wo DIV 8) blk) p s.memory)’ by
       (irule mem_inv_update \\ fs [])
  \\ ‘pmap_in_memory pmap
        (LUPDATE (LUPDATE (SOME vw) (w2n wo DIV 8) blk) p s.memory)’ by
       (irule pmap_in_memory_LUPDATE \\ fs [])
  \\ qexistsl_tac [‘(State t8,0)’, ‘pmap’]
  \\ conj_tac >- metis_tac [steps_trans]
  \\ fs [pmap_subsume_refl, cmd_res_rel_def]
  \\ rpt conj_tac
  >- (irule state_rel_step
      \\ qpat_assum ‘state_rel _ _ t3’ $ irule_at Any
      \\ imp_res_tac state_rel_IMP \\ gvs []
      \\ irule heap_ok_update \\ gvs [])
  \\ qexists_tac ‘Word hw :: ct’ \\ simp [has_stack_def, app_list_length_def]
QED

Resume c_cmd_correct[If]:
  qx_gen_tac ‘tst’
  \\ rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs []
  \\ imp_res_tac c_cmd_length \\ imp_res_tac c_test_jump_length
  \\ qpat_x_assum ‘code_in t.pc _ _’ mp_tac
  \\ simp code_layout
  \\ strip_tac
  (* the test must succeed: a Stop from eval_test could only be a Crash *)
  \\ qpat_x_assum ‘eval_cmd (If _ _ _) _ = _’ mp_tac
  \\ simp [Once eval_cmd_def]
  \\ Cases_on ‘eval_test tst (s with clock := fuel)’ \\ simp []
  \\ rename [‘eval_test tst _ = (tres,st)’]
  \\ strip_tac
  \\ ‘∃b. tres = Cont b’ by
       (Cases_on ‘tres’ \\ fs []
        \\ imp_res_tac imp_source_propertiesTheory.eval_test_not_stop \\ gvs [])
  \\ imp_res_tac eval_test_pure \\ gvs []
  (* step 1: the leading jump into the test code *)
  \\ qabbrev_tac ‘t2 = set_pc (t.pc + 3) t’
  \\ ‘steps (State t,fuel − s1.clock) (State t2,fuel − s1.clock)’ by
       (simp [Abbr‘t2’] \\ irule steps_Jump
        \\ fs [fetch_def])
  (* step 2: run the test, landing on t.pc+1 (true) or t.pc+2 (false) *)
  \\ ‘t2.instructions = t.instructions ∧ t2.pc = t.pc + 3 ∧
      t2.regs = t.regs ∧ t2.stack = t.stack’ by fs [Abbr‘t2’, set_pc_def]
  \\ qspec_then ‘tst’ mp_tac c_test_correct
  \\ rewrite_tac [goal_test_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘fuel − s1.clock’, ‘b’,
        ‘t2’, ‘vs’, ‘fs’, ‘asm1’, ‘app_list_length asm1 + (t.pc + 3)’,
        ‘t.pc + 1’, ‘t.pc + 2’, ‘curr’, ‘rest’, ‘pmap’] mp_tac)
  \\ impl_tac
  >- (fs [Abbr‘t2’, set_pc_def, has_stack_def]
      \\ qpat_x_assum ‘state_rel fs s t’ mp_tac
      \\ rewrite_tac [state_rel_def] \\ strip_tac \\ fs []
      \\ qexists_tac ‘r14’ \\ fs [])
  \\ strip_tac
  \\ imp_res_tac steps_inst
  \\ ‘∃w14. t.regs R14 = SOME w14’ by metis_tac [state_rel_R14]
  \\ ‘∃w14'. t1.regs R14 = SOME w14'’ by metis_tac [state_rel_R14]
  \\ ‘pmap_in_bounds pmap (t1.regs R14)’ by
       (gvs [] \\ irule r14_mono_IMP_pmap_in_bounds
        \\ first_assum $ irule_at Any \\ gvs [])
  (* step 3: jump from the landing pad into the branch that was taken *)
  \\ reverse $ Cases_on ‘b’ \\ gvs []
  >-
   (* the test failed: the else-branch already ends on the If's exit label *)
   (qabbrev_tac ‘t3 = set_pc (app_list_length asm1 +
                              (app_list_length asm2 + (t.pc + 4))) t1’
    \\ ‘steps (State t1,fuel − s1.clock) (State t3,fuel − s1.clock)’ by
         (simp [Abbr‘t3’] \\ irule steps_Jump \\ fs [fetch_def])
    \\ qpat_x_assum ‘goal_cmd c' fuel’ mp_tac
    \\ rewrite_tac [goal_cmd_def]
    \\ disch_then (qspecl_then
         [‘s’,‘s1’,‘res’,‘t3’,‘vs’,‘fs’,‘asm3’,
          ‘app_list_length asm1 +
             (app_list_length asm2 + (app_list_length asm3 + (t.pc + 4)))’,
          ‘curr’,‘rest’,‘pmap’] mp_tac)
    \\ impl_tac
    >- (‘state_rel fs s t3’ by
          (qpat_x_assum ‘state_rel fs _ t1’ mp_tac
           \\ simp [Abbr‘t3’, set_pc_def, state_rel_def])
        \\ fs [Abbr‘t3’, set_pc_def, binders_ok_def, has_stack_def])
    \\ strip_tac
    \\ qexistsl_tac [‘outcome’, ‘pmap1’]
    \\ conj_tac >- metis_tac [steps_trans]
    \\ conj_tac >- fs []
    \\ conj_tac >- fs []
    \\ PairCases_on ‘outcome’ \\ Cases_on ‘outcome0’ \\ fs []
    \\ gvs [Abbr‘t3’, set_pc_def]
    \\ metis_tac [r14_mono_trans])
  (* the test held: jump to the then-branch; if it falls through, take the
     closing jump to the exit label *)
  \\ qabbrev_tac ‘t3 = set_pc (app_list_length asm1 + (t.pc + 3)) t1’
  \\ ‘steps (State t1,fuel − s1.clock) (State t3,fuel − s1.clock)’ by
       (simp [Abbr‘t3’] \\ irule steps_Jump \\ fs [fetch_def])
  \\ qpat_x_assum ‘goal_cmd c fuel’ mp_tac
  \\ rewrite_tac [goal_cmd_def]
  \\ disch_then (qspecl_then
       [‘s’,‘s1’,‘res’,‘t3’,‘vs’,‘fs’,‘asm2’,
        ‘app_list_length asm1 + (app_list_length asm2 + (t.pc + 3))’,
        ‘curr’,‘rest’,‘pmap’] mp_tac)
  \\ impl_tac
  >- (‘state_rel fs s t3’ by
        (qpat_x_assum ‘state_rel fs _ t1’ mp_tac
         \\ simp [Abbr‘t3’, set_pc_def, state_rel_def])
      \\ fs [Abbr‘t3’, set_pc_def, binders_ok_def, has_stack_def])
  \\ strip_tac
  \\ ‘steps (State t,fuel − s1.clock) (State t3,fuel − s1.clock)’ by
       metis_tac [steps_trans]
  \\ reverse (Cases_on ‘res’) \\ gvs []
  >- (* it stopped: whatever the machine did is already the answer *)
     (qexistsl_tac [‘outcome’, ‘pmap1’]
      \\ conj_tac >- metis_tac [steps_trans]
      \\ conj_tac >- fs []
      \\ conj_tac >- fs []
      \\ PairCases_on ‘outcome’ \\ Cases_on ‘outcome0’ \\ fs []
      \\ rename [‘Stop e’] \\ Cases_on ‘e’ \\ fs [cmd_res_rel_def]
      \\ gvs [Abbr‘t3’, set_pc_def]
      \\ metis_tac [r14_mono_trans])
  \\ PairCases_on ‘outcome’ \\ reverse (Cases_on ‘outcome0’)
  >- (* it halted the machine *)
     (rename [‘Halt ec out’]
      \\ qexistsl_tac [‘(Halt ec out,outcome1)’, ‘pmap1’]
      \\ conj_tac >- metis_tac [steps_trans]
      \\ fs [])
  (* it fell through: take the closing jump to the exit label *)
  \\ gvs []
  \\ rename [‘steps (State t3,fuel − s1.clock) (State tz,0)’]
  \\ fs [cmd_res_rel_def]
  \\ qabbrev_tac ‘t5 = set_pc (app_list_length asm1 +
                    (app_list_length asm2 + (app_list_length asm3 + (t.pc + 4)))) tz’
  \\ ‘steps (State tz,0) (State t5,0)’ by
       (simp [Abbr‘t5’] \\ irule steps_Jump
        \\ imp_res_tac steps_inst \\ fs [fetch_def])
  \\ qexistsl_tac [‘(State t5,0)’, ‘pmap1’]
  \\ conj_tac >- metis_tac [steps_trans]
  \\ conj_tac >- fs []
  \\ conj_tac >- fs []
  \\ fs [cmd_res_rel_def, Abbr‘t5’, set_pc_def]
  \\ first_assum $ irule_at Any
  \\ gvs [Abbr‘t3’, set_pc_def, state_rel_def, has_stack_def]
  \\ metis_tac [r14_mono_trans]
QED

Resume c_cmd_correct[While]:
  qx_gen_tac ‘tst’
  \\ rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs []
  \\ imp_res_tac c_cmd_length \\ imp_res_tac c_test_jump_length
  \\ qpat_x_assum ‘code_in t.pc _ _’ mp_tac
  \\ simp code_layout
  \\ strip_tac
  \\ qabbrev_tac ‘asmw =
       List [Jump Always (t.pc + 3)] +++
       List [Jump Always (app_list_length asm1 + (t.pc + 3))] +++
       List [Jump Always (app_list_length asm1 +
                          (app_list_length asm2 + (t.pc + 4)))] +++
       asm1 +++ asm2 +++ List [Jump Always t.pc]’
  \\ ‘c_cmd (While tst c) t.pc fs vs =
        (asmw,app_list_length asm1 + (app_list_length asm2 + (t.pc + 4)))’ by
       (simp [Once c_cmd_def, Abbr‘asmw’]
        \\ rpt (pairarg_tac \\ simp []) \\ gvs []
        \\ metis_tac [pairTheory.PAIR])
  \\ ‘code_in t.pc (flatten asmw []) t.instructions’ by
       simp (Abbr‘asmw’ :: code_layout)
  (* the test succeeds and leaves the state alone *)
  \\ qpat_x_assum ‘eval_cmd (While _ _) _ = _’ mp_tac
  \\ simp [Once eval_cmd_def, bind_def]
  \\ Cases_on ‘eval_test tst (s with clock := fuel)’ \\ simp []
  \\ rename [‘eval_test tst _ = (tres,st)’]
  \\ strip_tac
  \\ ‘∃b. tres = Cont b’ by
       (Cases_on ‘tres’ \\ fs []
        \\ imp_res_tac imp_source_propertiesTheory.eval_test_not_stop \\ gvs [])
  \\ imp_res_tac eval_test_pure \\ gvs []
  (* jump into the test code, then run it *)
  \\ qabbrev_tac ‘t2 = set_pc (t.pc + 3) t’
  \\ ‘∀k. steps (State t,k) (State t2,k)’ by
       (simp [Abbr‘t2’] \\ rw [] \\ irule steps_Jump
        \\ fs [fetch_def])
  \\ qspec_then ‘tst’ mp_tac c_test_correct
  \\ rewrite_tac [goal_test_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘fuel − s1.clock’, ‘b’,
        ‘t2’, ‘vs’, ‘fs’, ‘asm1’, ‘app_list_length asm1 + (t.pc + 3)’,
        ‘t.pc + 1’, ‘t.pc + 2’, ‘curr’, ‘rest’, ‘pmap’] mp_tac)
  \\ impl_tac
  >- (fs [Abbr‘t2’, set_pc_def, has_stack_def]
      \\ qpat_x_assum ‘state_rel fs s t’ mp_tac
      \\ rewrite_tac [state_rel_def] \\ strip_tac \\ fs []
      \\ qexists_tac ‘r14’ \\ fs [])
  \\ strip_tac
  \\ rename [‘steps (State t2,_) (State t3,_)’]
  \\ reverse (Cases_on ‘b’) \\ gvs []
  \\ imp_res_tac steps_inst
  >- (* the test was false: jump straight to the exit label *)
   (qexistsl_tac
      [‘(State (set_pc (app_list_length asm1 +
                (app_list_length asm2 + (t.pc + 4))) t3), 0)’, ‘pmap’]
    \\ conj_tac
    >- (irule steps_trans \\ qexists_tac ‘(State t2,0)’ \\ conj_tac >- fs []
        \\ irule steps_trans \\ qexists_tac ‘(State t3,0)’ \\ conj_tac >- fs []
        \\ irule steps_Jump
        \\ ‘t2.instructions = t.instructions’ by fs [Abbr‘t2’, set_pc_def]
        \\ fs [fetch_def])
    \\ fs [pmap_subsume_refl, cmd_res_rel_def, set_pc_def, has_stack_def]
    \\ conj_tac >- fs [state_rel_def]
    \\ ‘t2.regs = t.regs’ by fs [Abbr‘t2’, set_pc_def]
    \\ qpat_assum ‘state_rel fs _ t3’
         (strip_assume_tac o MATCH_MP state_rel_R14)
    \\ qpat_assum ‘state_rel fs s t’
         (strip_assume_tac o MATCH_MP state_rel_R14)
    \\ conj_tac >- metis_tac []
    \\ conj_tac
    >- (fs [] \\ irule r14_mono_IMP_pmap_in_bounds \\ metis_tac [])
    \\ qexists_tac ‘curr’ \\ fs [])
  (* the test held: the conditional jump landed on jump_to_body, so one more
     jump takes us to the start of the body *)
  \\ ‘t2.regs = t.regs ∧ t2.instructions = t.instructions’ by
       gvs [Abbr‘t2’, set_pc_def]
  \\ qabbrev_tac ‘t4 = set_pc (app_list_length asm1 + (t.pc + 3)) t3’
  \\ ‘∀k. steps (State t3,k) (State t4,k)’ by
       (simp [Abbr‘t4’] \\ rw [] \\ irule steps_Jump
        \\ gvs [fetch_def])
  \\ ‘t4.pc = app_list_length asm1 + (t.pc + 3) ∧ t4.regs = t3.regs ∧
      t4.stack = t3.stack ∧ t4.instructions = t.instructions ∧
      t4.memory = t3.memory ∧ t4.input = t3.input ∧ t4.output = t3.output’ by
       gvs [Abbr‘t4’, set_pc_def]
  (* run the body once *)
  \\ qpat_x_assum ‘_ = (res,s1)’ mp_tac
  \\ Cases_on ‘eval_cmd c (s with clock := fuel)’ \\ simp []
  \\ rename [‘eval_cmd c _ = (res0,s0)’]
  \\ strip_tac
  \\ ‘res0 ≠ Stop Crash’ by (Cases_on ‘res0’ \\ gvs [])
  \\ ‘pmap_in_bounds pmap (t4.regs R14)’ by
       (qpat_assum ‘state_rel fs _ t3’ (strip_assume_tac o MATCH_MP state_rel_R14)
        \\ qpat_assum ‘state_rel fs s t’ (strip_assume_tac o MATCH_MP state_rel_R14)
        \\ gvs [] \\ irule r14_mono_IMP_pmap_in_bounds \\ metis_tac [])
  \\ qpat_x_assum ‘goal_cmd c fuel’ mp_tac
  \\ rewrite_tac [goal_cmd_def]
  \\ disch_then (qspecl_then
       [‘s’,‘s0’,‘res0’,‘t4’,‘vs’,‘fs’,‘asm2’,
        ‘app_list_length asm1 + (app_list_length asm2 + (t.pc + 3))’,
        ‘curr’,‘rest’,‘pmap’] mp_tac)
  \\ impl_tac
  >- (gvs [binders_ok_def, has_stack_def]
      \\ qpat_x_assum ‘state_rel fs _ t3’ mp_tac
      \\ rewrite_tac [state_rel_def] \\ strip_tac \\ gvs [])
  \\ strip_tac
  \\ ‘s0.clock ≤ fuel’ by (imp_res_tac eval_cmd_clock \\ fs [])
  \\ ‘s1.clock ≤ s0.clock’ by
       (Cases_on ‘res0’ \\ gvs [tick_def, AllCaseEqs()]
        \\ imp_res_tac eval_cmd_clock \\ gvs [])
  \\ ‘steps (State t,fuel − s1.clock) (State t4,fuel − s1.clock)’ by
       metis_tac [steps_trans]
  \\ PairCases_on ‘outcome’ \\ reverse (Cases_on ‘outcome0’)
  >- (* the body halted the machine *)
   (rename [‘Halt ec out’]
    \\ ‘isPREFIX s0.output s1.output’ by
         (Cases_on ‘res0’ \\ gvs [tick_def, AllCaseEqs()]
          \\ imp_res_tac eval_cmd_output \\ gvs [])
    \\ qexistsl_tac [‘(Halt ec out,outcome1 + (s0.clock − s1.clock))’,‘pmap1’]
    \\ conj_tac
    >- (irule steps_trans
        \\ qexists_tac ‘(State t4,fuel − s1.clock)’
        \\ conj_tac >- gvs []
        \\ qspecl_then [‘State t4’,‘fuel − s0.clock’,‘Halt ec out’,‘outcome1’,
                        ‘s0.clock − s1.clock’] mp_tac steps_add_fuel
        \\ gvs [])
    \\ gvs []
    \\ metis_tac [rich_listTheory.IS_PREFIX_TRANS])
  \\ gvs []
  \\ rename1 ‘cmd_res_rel _ _ _ _ t5 _ _’
  \\ reverse (Cases_on ‘res0’) \\ gvs []
  >- (* the body stopped: its outcome is the loop's outcome *)
   (rename [‘eval_cmd c _ = (Stop r,s0)’]
    \\ qexistsl_tac [‘(State t5,0)’,‘pmap1’]
    \\ ‘steps (State t,fuel − s0.clock) (State t5,0)’ by metis_tac [steps_trans]
    \\ gvs []
    \\ Cases_on ‘r’ \\ gvs [cmd_res_rel_def]
    \\ metis_tac [r14_mono_trans])
  (* the body continued: tick, then go round again *)
  \\ ‘∃curr1.
        has_stack t5 (curr1 ⧺ rest) ∧ mem_inv pmap1 t5.memory s0.memory ∧
        pmap_in_memory pmap1 s0.memory ∧ env_ok s0.vars vs curr1 pmap1 ∧
        t5.pc = app_list_length asm1 + (app_list_length asm2 + (t.pc + 3))’ by
       (fs [cmd_res_rel_def] \\ metis_tac [])
  \\ Cases_on ‘s0.clock = 0’ \\ gvs [tick_def]
  >- (* the clock ran out *)
   (qexistsl_tac [‘(State t5,0)’,‘pmap1’]
    \\ conj_tac >- metis_tac [steps_trans]
    \\ gvs [cmd_res_rel_def]
    \\ metis_tac [r14_mono_trans])
  (* jump back to the top of the loop; that jump is where the tick is spent *)
  \\ imp_res_tac steps_inst
  \\ qabbrev_tac ‘t6 = set_pc t.pc t5’
  \\ ‘s1.clock ≤ s0.clock − 1’ by (imp_res_tac eval_cmd_clock \\ gvs [])
  \\ ‘steps (State t5,s0.clock − 1 − s1.clock + 1) (State t6,s0.clock − 1 − s1.clock)’ by
       (qunabbrev_tac ‘t6’ \\ irule steps_Jump_tick
        \\ gvs [fetch_def])
  \\ ‘t6.pc = t.pc ∧ t6.regs = t5.regs ∧ t6.stack = t5.stack ∧
      t6.instructions = t.instructions ∧ t6.memory = t5.memory ∧
      t6.input = t5.input ∧ t6.output = t5.output’ by
       gvs [Abbr‘t6’, set_pc_def]
  \\ ‘state_rel fs s0 t6’ by
       (irule state_rel_step
        \\ qpat_assum ‘state_rel fs s0 t5’ $ irule_at Any
        \\ imp_res_tac state_rel_IMP \\ gvs [])
  \\ ‘goal_cmd (While tst c) (s0.clock − 1)’ by (first_x_assum irule \\ gvs [])
  \\ pop_assum mp_tac
  \\ rewrite_tac [goal_cmd_def]
  \\ disch_then (qspecl_then
       [‘s0’,‘s1’,‘res’,‘t6’,‘vs’,‘fs’,‘asmw’,
        ‘app_list_length asm1 + (app_list_length asm2 + (t.pc + 4))’,
        ‘curr1’,‘rest’,‘pmap1’] mp_tac)
  \\ impl_tac
  >- (gvs [binders_ok_def, has_stack_def]
      \\ qpat_x_assum ‘env_ok s.vars vs curr pmap’ mp_tac
      \\ qpat_assum ‘env_ok s0.vars vs curr1 pmap1’ mp_tac
      \\ rewrite_tac [env_ok_def] \\ rpt strip_tac \\ gvs [])
  \\ strip_tac
  (* stitch the three runs together *)
  \\ ‘steps (State t,fuel − s1.clock) (State t5,s0.clock − s1.clock)’ by
       (irule steps_trans
        \\ qexists_tac ‘(State t4,fuel − s1.clock)’
        \\ conj_tac >- gvs []
        \\ qspecl_then [‘State t4’,‘fuel − s0.clock’,‘State t5’,‘0’,
                        ‘s0.clock − s1.clock’] mp_tac steps_add_fuel
        \\ gvs [])
  \\ ‘steps (State t,fuel − s1.clock) (State t6,s0.clock − 1 − s1.clock)’ by
       (irule steps_trans
        \\ qexists_tac ‘(State t5,s0.clock − 1 − s1.clock + 1)’
        \\ conj_tac >- gvs []
        \\ ‘s0.clock − 1 − s1.clock + 1 = s0.clock − s1.clock’ by gvs []
        \\ gvs [])
  \\ ‘r14_mono (t.regs R14) (t6.regs R14)’ by (gvs [] \\ metis_tac [r14_mono_trans])
  \\ qexistsl_tac [‘outcome’,‘pmap1'’]
  \\ conj_tac >- metis_tac [steps_trans]
  \\ conj_tac >- gvs []
  \\ conj_tac >- metis_tac [pmap_subsume_trans]
  \\ PairCases_on ‘outcome’ \\ Cases_on ‘outcome0’ \\ gvs []
  \\ metis_tac [r14_mono_trans]
QED

Resume c_cmd_correct[Call]:
  rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs [make_ret_def]
  \\ gvs [eval_cmd_def, CaseEq "prod"]
  \\ qspec_then ‘l’ mp_tac c_exps_correct
  \\ simp [goal_exps_def]
  \\ disch_then drule
  \\ rename [‘eval_exps l (s with clock := fuel) = (vv,s1)’]
  \\ Cases_on ‘vv = Stop Crash’ \\ gvs []
  \\ disch_then drule
  \\ ‘state_rel fs (s with clock := fuel) t’ by gvs [state_rel_def]
  \\ rpt $ disch_then drule
  \\ disch_then $ qspec_then ‘fuel − s1'.clock’ mp_tac
  \\ impl_tac >- gvs [flatten_append, code_in_append]
  \\ strip_tac
  \\ irule_at Any steps_trans
  \\ first_assum $ irule_at $ Pos hd
  \\ reverse $ Cases_on ‘vv’ >- gvs [] \\ gvs []
  \\ gvs [exps_res_rel_def]
  \\ imp_res_tac c_exps_length
  \\ gvs [c_call_def, app_list_length_thm, flatten_append, code_in_append]
  (* the callee must exist and its parameters must match the arguments *)
  \\ Cases_on ‘find_fun n0 s1.funs’ \\ gvs []
  \\ rename [‘find_fun n0 s1.funs = SOME pb’]
  \\ PairCases_on ‘pb’ \\ gvs []
  \\ rename [‘find_fun n0 s1.funs = SOME (params,body)’]
  \\ Cases_on ‘LENGTH params = LENGTH b’ \\ gvs []
  \\ Cases_on ‘ALL_DISTINCT params’ \\ gvs []
  \\ imp_res_tac eval_exps_pure \\ gvs []
  (* the tick: if the clock has run out the answer is TimeOut, and eval_exps
     leaves the clock alone, so there is no fuel left to account for either *)
  \\ Cases_on ‘fuel = 0’ \\ gvs [tick_def]
  >- (qexistsl_tac [‘(State t1,0)’,‘pmap’]
      \\ imp_res_tac state_rel_R14
      \\ gvs [pmap_subsume_refl, cmd_res_rel_def]
      \\ once_rewrite_tac [steps_cases] \\ simp []
      \\ metis_tac [r14_mono_IMP_pmap_in_bounds])
  (* move the arguments into the registers the callee expects *)
  \\ ‘∃r15. t1.regs R15 = SOME r15’ by
       (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def]
        \\ metis_tac [])
  \\ ‘code_rel fs s.funs t1.instructions’ by
       (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def])
  \\ ‘EVEN (LENGTH (curr ⧺ rest))’ by fs [EVEN_ADD, ODD_EVEN]
  \\ ‘LENGTH l = LENGTH ws’ by
       (imp_res_tac eval_exps_LENGTH
        \\ imp_res_tac listTheory.LIST_REL_LENGTH \\ gvs [])
  \\ qspecl_then [‘l’,‘vs’,‘ws’,‘t1’,‘curr ⧺ rest’,‘fuel − s1'.clock’,
                  ‘fs’,‘s.funs’,‘r15’] mp_tac c_pops_steps
  \\ impl_tac >- (imp_res_tac steps_inst \\ gvs [])
  \\ strip_tac
  >- (* more than five arguments: a compiler limitation, exit 4 *)
   (qexistsl_tac [‘(Halt 4w t1.output,fuel − s1'.clock)’,‘pmap’]
    \\ gvs [pmap_subsume_refl]
    \\ ‘t1.output = s.output’ by
         (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def])
    \\ gvs [AllCaseEqs()]
    \\ imp_res_tac eval_cmd_output \\ gvs [])
  (* the arguments are in the registers now: make the call *)
  \\ qabbrev_tac ‘t2 = t1 with <|regs := pops_regs ws t1.regs;
                                pc := t1.pc + app_list_length (c_pops l vs);
                                stack := curr ⧺ rest|>’
  \\ ‘t2.pc = LENGTH (flatten asms []) + (LENGTH (flatten (c_pops l vs) []) + t.pc) ∧
      t2.stack = curr ⧺ rest ∧ t2.instructions = t1.instructions ∧
      t2.memory = t1.memory ∧ t2.input = t1.input ∧ t2.output = t1.output ∧
      t2.regs = pops_regs ws t1.regs’ by
       gvs [Abbr‘t2’, app_list_length_thm]
  \\ qabbrev_tac ‘t3 = set_pc (lookup n0 fs)
                       (set_stack (RetAddr (t2.pc + 1) :: t2.stack) t2)’
  \\ ‘step (State t2) (State t3)’ by
       (qunabbrev_tac ‘t3’ \\ irule (cj 7 step_rules)
        \\ imp_res_tac steps_inst
        \\ gvs [fetch_def, flatten_def, code_in_def])
  (* where the callee's code lives *)
  \\ qpat_x_assum ‘code_rel fs s.funs t1.instructions’ mp_tac
  \\ rewrite_tac [code_rel_def] \\ strip_tac
  \\ first_x_assum drule \\ strip_tac
  \\ imp_res_tac lookup_eq_ALOOKUP
  \\ Cases_on ‘eval_cmd body
                 (s with <|vars := FEMPTY |++ ZIP (params,b); clock := fuel − 1|>)’
  \\ rename [‘eval_cmd body _ = (res2,s2)’]
  (* split the callee's code into its entry sequence and its body *)
  \\ qspecl_then [‘n0’,‘params’,‘body’,‘pos’,‘fs’] strip_assume_tac c_fundef_parts
  \\ gvs []
  \\ ‘code_in (lookup n0 fs) (flatten (asm0 +++ asm1) []) t1.instructions ∧
      code_in l0 (flatten asm3 []) t1.instructions’ by
       (qpat_x_assum ‘code_in _ (flatten (asm0 +++ asm1 +++ asm3) []) _’ mp_tac
        \\ imp_res_tac c_pushes_length \\ imp_res_tac c_bdrs_asm
        \\ gvs [app_list_length_def] \\ simp code_layout)
  (* run the entry code *)
  \\ ‘∃w. t1.regs RAX = SOME w’ by (fs [has_stack_def] \\ metis_tac [])
  \\ ‘ws ≠ [] ⇒ LAST ws = w’ by
       (strip_tac
        \\ qspecl_then [‘t1’,‘ws’,‘curr ⧺ rest’,‘w’] mp_tac has_stack_LAST
        \\ gvs [])
  \\ ‘t3.pc = lookup n0 fs ∧ t3.regs = pops_regs ws t1.regs ∧
      t3.stack = RetAddr (t2.pc + 1) :: (curr ⧺ rest) ∧
      t3.instructions = t1.instructions ∧ t3.memory = t1.memory ∧
      t3.input = t1.input ∧ t3.output = t1.output’ by
       gvs [Abbr‘t3’, set_pc_def, set_stack_def]
  \\ ‘t3.regs RAX = SOME w’ by gvs [pops_regs_other, ARGS_REGS_def]
  \\ qspecl_then [‘params’,‘body’,‘lookup n0 fs’,‘t3’,‘asm0’,‘vs_bind1’,‘asm1’,‘vs1’,‘l0’,
                  ‘ws’,‘w’,‘fuel − 1 − s2.clock’,‘t1.regs’] mp_tac
       c_fundef_entry_steps
  \\ impl_tac >- (imp_res_tac listTheory.LIST_REL_LENGTH \\ gvs [])
  \\ strip_tac
  \\ qmatch_asmsub_abbrev_tac ‘steps (State t3,_) (State t4,_)’
  \\ ‘t4.pc = l0 ∧ t4.regs = t3.regs ∧ t4.instructions = t1.instructions ∧
      t4.memory = t1.memory ∧ t4.input = t1.input ∧ t4.output = t1.output ∧
      t4.stack = TL (if ws = [] then [Word w] else MAP Word (REVERSE ws)) ⧺
                 REPLICATE (LENGTH vs_bind1) Undefined ⧺ t3.stack’ by
       gvs [Abbr‘t4’]
  (* the abbreviation has done its job; keeping it makes gvs loop, because
     l0 gets rewritten to t4.pc inside it *)
  \\ qpat_x_assum ‘Abbrev (t4 = _)’ kall_tac
  (* the callee's frame: its arguments, then the slots reserved for its own
     binders, sitting on top of the return address *)
  \\ qabbrev_tac ‘new_curr =
       (if ws = [] then [Word w] else MAP Word (REVERSE ws)) ⧺
       REPLICATE (LENGTH vs_bind1) Undefined’
  \\ ‘has_stack t4 (new_curr ⧺ t3.stack)’ by
       (‘∃ys. (if ws = [] then [Word w] else MAP Word (REVERSE ws)) = Word w :: ys’ by
          (irule args_frame \\ gvs [])
        \\ gvs [Abbr‘new_curr’, has_stack_def])
  \\ imp_res_tac c_pushes_vs
  \\ ‘env_ok (FEMPTY |++ ZIP (params,b)) (vs1 ⧺ vs_bind1) new_curr pmap’ by
       (gvs [Abbr‘new_curr’] \\ irule env_ok_callee
        \\ imp_res_tac listTheory.LIST_REL_LENGTH \\ gvs [])
  \\ ‘LENGTH new_curr = LENGTH vs1 + LENGTH vs_bind1’ by
       (imp_res_tac listTheory.LIST_REL_LENGTH
        \\ gvs [Abbr‘new_curr’, LENGTH_push_vs]
        \\ rw [] \\ gvs [])
  \\ ‘ODD (LENGTH new_curr)’ by (imp_res_tac c_bdrs_ODD \\ gvs [])
  \\ ‘ODD (LENGTH t3.stack)’ by gvs [ODD_EVEN, EVEN]
  \\ ‘binders_ok body (vs1 ⧺ vs_bind1)’ by
       (irule binders_ok_c_bdrs \\ metis_tac [])
  (* run the body, with one less unit of clock *)
  \\ ‘goal_cmd body (fuel − 1)’ by (first_x_assum irule \\ gvs [])
  \\ qpat_x_assum ‘goal_cmd body _’ mp_tac
  \\ rewrite_tac [goal_cmd_def]
  \\ disch_then (qspecl_then
       [‘s with <|vars := FEMPTY |++ ZIP (params,b); clock := fuel − 1|>’,
        ‘s2’,‘res2’,‘t4’,‘vs1 ⧺ vs_bind1’,‘fs’,‘asm3’,‘l2’,‘new_curr’,
        ‘t3.stack’,‘pmap’] mp_tac)
  \\ impl_tac
  >- (gvs []
      \\ conj_tac >- (strip_tac \\ gvs [])
      \\ conj_tac
      >- (irule state_rel_step
          \\ qpat_assum ‘state_rel _ _ t1’ $ irule_at Any
          \\ imp_res_tac state_rel_IMP
          \\ gvs [pops_regs_other, ARGS_REGS_def])
      \\ imp_res_tac state_rel_IMP
      \\ gvs [pops_regs_other, ARGS_REGS_def]
      \\ metis_tac [r14_mono_IMP_pmap_in_bounds])
  \\ strip_tac
  (* the Call instruction is what consumes the clock tick *)
  \\ ‘s1'.clock = s2.clock ∧ s1'.output = s2.output’ by gvs [AllCaseEqs()]
  \\ ‘s2.clock ≤ fuel − 1’ by (imp_res_tac eval_cmd_clock \\ gvs [])
  \\ ‘fuel − s1'.clock = fuel − 1 − s2.clock + 1’ by gvs []
  \\ ‘steps (State t2,fuel − 1 − s2.clock + 1) (State t3,fuel − 1 − s2.clock)’ by
       (irule (cj 3 steps_rules) \\ simp [])
  \\ ‘steps (State t2,fuel − s1'.clock) (State t3,fuel − 1 − s2.clock)’ by
       (qpat_x_assum ‘fuel − s1'.clock = _’ (fn th => rewrite_tac [th])
        \\ simp [])
  \\ ‘steps (State t3,fuel − 1 − s2.clock) outcome’ by
       (irule steps_trans \\ qexists_tac ‘(State t4,fuel − 1 − s2.clock)’ \\ gvs [])
  \\ ‘steps (State t1,fuel − s1'.clock) outcome’ by
       metis_tac [steps_trans]
  (* this equation has done its job; kept, it is a looping rewrite once
     s1'.clock has been replaced by s2.clock *)
  \\ qpat_x_assum ‘fuel − s1'.clock = _’ kall_tac
  \\ qpat_x_assum ‘steps (State t2,fuel − 1 − s2.clock + 1) _’ kall_tac
  \\ PairCases_on ‘outcome’ \\ reverse (Cases_on ‘outcome0’) \\ gvs []
  (* the callee halted the machine -- two goals, one per exit code *)
  >- (rename [‘Halt ec out’]
      \\ qexistsl_tac [‘(Halt ec out,outcome1)’,‘pmap1’] \\ gvs [])
  >- (rename [‘Halt ec out’]
      \\ qexistsl_tac [‘(Halt ec out,outcome1)’,‘pmap1’] \\ gvs [])
  \\ rename1 ‘cmd_res_rel _ _ _ _ t5 _ _’
  \\ qpat_x_assum ‘_ = (res,s1')’ mp_tac
  \\ rpt (qpat_x_assum ‘Abbrev _’ kall_tac)
  \\ rpt TOP_CASE_TAC \\ strip_tac \\ fs []
  >- (* the callee returned: come back and store the result *)
   (fs [cmd_res_rel_def]
    \\ rename [‘v_inv pmap1 v wv’]
    \\ ‘∃hw ct. curr = Word hw :: ct’ by
         (qspecl_then [‘t’,‘curr’,‘rest’] mp_tac has_stack_cons \\ gvs [])
    \\ gvs []
    \\ qabbrev_tac ‘t6 = set_pc (t2.pc + 1) (set_stack (Word hw :: (ct ⧺ rest)) t5)’
    \\ ‘step (State t5) (State t6)’ by
         (qunabbrev_tac ‘t6’ \\ irule (cj 8 step_rules) \\ gvs [has_stack_def])
    \\ ‘t6.pc = t2.pc + 1 ∧ t6.regs = t5.regs ∧ t6.stack = Word hw :: (ct ⧺ rest) ∧
        t6.instructions = t5.instructions ∧ t6.memory = t5.memory ∧
        t6.input = t5.input ∧ t6.output = t5.output’ by
         gvs [Abbr‘t6’, set_pc_def, set_stack_def]
    \\ ‘MEM (SOME n) vs’ by fs [binders_ok_def]
    \\ ‘LENGTH vs = LENGTH (Word hw::ct)’ by fs [env_ok_def]
    \\ imp_res_tac steps_inst
    \\ ‘t6.instructions = t.instructions’ by gvs []
    \\ ‘t6.regs RAX = SOME wv’ by gvs [has_stack_def]
    \\ drule c_assign_steps
    \\ disch_then (qspecl_then [‘t6’,‘wv’,‘hw’,‘ct’,‘rest’,‘0’] mp_tac)
    \\ impl_tac >- gvs [flatten_def]
    \\ strip_tac
    (* R14 is untouched from the call until the return *)
    \\ ‘t4.regs R14 = t1.regs R14’ by gvs [pops_regs_other, ARGS_REGS_def]
    \\ ‘t2'.regs R14 = t5.regs R14’ by gvs []
    \\ ‘r14_mono (t.regs R14) (t2'.regs R14)’ by metis_tac [r14_mono_trans]
    \\ ‘pmap_in_bounds pmap1 (t2'.regs R14)’ by gvs []
    \\ qexistsl_tac [‘(State t2',0)’,‘pmap1’]
    \\ conj_tac >- metis_tac [steps_trans, step_IMP_steps]
    \\ gvs [cmd_res_rel_def]
    \\ rpt conj_tac
    >- (irule state_rel_step
        \\ qpat_assum ‘state_rel _ _ t5’ $ irule_at Any
        \\ imp_res_tac state_rel_IMP \\ gvs [])
    \\ qexists_tac ‘LUPDATE (Word wv) (index_of n 0 vs) (Word hw::ct)’
    \\ gvs []
    \\ irule env_ok_assign \\ gvs []
    \\ irule env_ok_pmap_subsume
    \\ qexists_tac ‘pmap’ \\ gvs [])
  >- (* the callee timed out *)
   (‘t4.regs R14 = t1.regs R14’ by gvs [pops_regs_other, ARGS_REGS_def]
    \\ ‘r14_mono (t.regs R14) (t5.regs R14)’ by metis_tac [r14_mono_trans]
    \\ qexistsl_tac [‘(State t5,0)’,‘pmap1’]
    \\ gvs [cmd_res_rel_def])
  (* the callee aborted: it cannot have come back in a State *)
  \\ fs [cmd_res_rel_def]
QED

Resume c_cmd_correct[Return]:
  rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs [make_ret_def]
  \\ qpat_x_assum ‘eval_cmd (Return _) _ = _’ mp_tac
  \\ simp [Once eval_cmd_def, bind_def]
  \\ Cases_on ‘eval_exp e (s with clock := fuel)’ \\ simp []
  \\ rename [‘eval_exp e _ = (eres,se)’]
  \\ strip_tac
  \\ ‘∃v. eres = Cont v’ by (Cases_on ‘eres’ \\ not_crash_tac)
  \\ imp_res_tac eval_exp_pure \\ gvs []
  \\ ‘∃r14a. t.regs R14 = SOME r14a’ by
       (qpat_x_assum ‘state_rel fs s t’ mp_tac \\ rw [state_rel_def]
        \\ metis_tac [])
  (* the expression code, then Add_RSP and Ret *)
  \\ ‘code_in t.pc (flatten asm1 []) t.instructions ∧
      oEL l1' t.instructions = SOME (Add_RSP (LENGTH vs)) ∧
      oEL (l1' + 1) t.instructions = SOME Ret’ by
       (imp_res_tac c_exp_length
        \\ qpat_x_assum ‘code_in t.pc _ _’ mp_tac
        \\ simp code_layout)
  \\ qspec_then ‘e’ mp_tac c_exp_correct
  \\ rewrite_tac [goal_exp_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘0’, ‘Cont v’, ‘t’,
        ‘vs’, ‘fs’, ‘asm1’, ‘l1'’, ‘curr’, ‘rest’, ‘pmap’] mp_tac)
  \\ impl_tac >- (imp_res_tac c_exp_length \\ fs [state_rel_def])
  \\ strip_tac
  \\ fs [exp_res_rel_def]
  \\ rename [‘steps (State t,0) (State t1,0)’]
  (* one Add_RSP step drops the frame, leaving the result on top and Ret next *)
  \\ qexistsl_tac [‘(State (set_stack rest (inc t1)), 0)’, ‘pmap’]
  \\ ‘LENGTH vs = LENGTH curr’ by fs [env_ok_def]
  \\ ‘t1.stack = curr ++ rest ∧ t1.regs RAX = SOME w’ by fs [has_stack_def]
  \\ conj_tac
  >- (irule steps_trans
      \\ first_assum (irule_at (Pos hd))
      \\ irule (cj 2 steps_rules)
      \\ irule (cj 13 step_rules)
      \\ qexists_tac ‘curr’
      \\ imp_res_tac steps_inst
      \\ fs [fetch_def])
  \\ fs [pmap_subsume_refl, cmd_res_rel_def, has_stack_def, set_stack_def,
         inc_def, fetch_def]
  \\ imp_res_tac steps_inst \\ fs []
  \\ conj_tac >- fs [state_rel_def]
  \\ ‘∃y. t1.regs R14 = SOME y’ by
       (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def]
        \\ metis_tac [])
  \\ fs []
  \\ conj_tac >- metis_tac []
  \\ irule r14_mono_IMP_pmap_in_bounds
  \\ metis_tac []
QED

Resume c_cmd_correct[Alloc]:
  qx_genl_tac [‘vn’,‘e’]
  \\ rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs [c_alloc_def, app_list_length_def]
  \\ qpat_x_assum ‘eval_cmd (Alloc _ _) _ = _’ mp_tac
  \\ simp [Once eval_cmd_def, bind_def]
  \\ Cases_on ‘eval_exp e (s with clock := fuel)’ \\ fs []
  \\ rename [‘eval_exp e _ = (eres,se)’]
  \\ strip_tac
  \\ ‘∃v. eres = Cont v’ by (Cases_on ‘eres’ \\ not_crash_tac)
  \\ imp_res_tac eval_exp_pure \\ gvs []
  \\ ‘∃len. v = Word len’ by (Cases_on ‘v’ \\ gvs [])
  \\ gvs [imp_source_semanticsTheory.alloc_def, AllCaseEqs()]
  (* the expression code, then Mov / Call, then the c_assign code *)
  \\ ‘code_in t.pc (flatten asm1 []) t.instructions ∧
      oEL l1' t.instructions = SOME (Mov RDI RAX) ∧
      oEL (l1' + 1) t.instructions = SOME (Call AllocLoc) ∧
      code_in (l1' + 2) (flatten asm3 []) t.instructions’ by
       (imp_res_tac c_exp_length
        \\ qpat_x_assum ‘code_in t.pc _ _’ mp_tac
        \\ simp code_layout)
  \\ drule_all has_stack_cons \\ strip_tac \\ gvs []
  (* run the size expression *)
  \\ qspec_then ‘e’ mp_tac c_exp_correct
  \\ rewrite_tac [goal_exp_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘0’, ‘Cont (Word len)’,
        ‘t’, ‘vs’, ‘fs’, ‘asm1’, ‘l1'’, ‘Word hw::ct’, ‘rest’, ‘pmap’] mp_tac)
  \\ impl_tac >- fs [state_rel_def]
  \\ strip_tac
  \\ gvs [exp_res_rel_def, v_inv_def]
  \\ rename [‘steps (State t,0) (State t1,0)’]
  \\ imp_res_tac steps_inst
  \\ ‘t1.regs RAX = SOME len ∧ t1.stack = Word hw :: (ct ⧺ rest)’ by
       fs [has_stack_def]
  \\ ‘∃r14 r15. t1.regs R14 = SOME r14 ∧ t1.regs R15 = SOME r15 ∧
                heap_ok r14 r15 t1.memory ∧
                code_rel fs s.funs t1.instructions’ by
       (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def]
        \\ metis_tac [])
  (* Mov RDI RAX *)
  \\ qabbrev_tac ‘t2 = write_reg RDI len (inc t1)’
  \\ ‘step (State t1) (State t2)’ by
       (qunabbrev_tac ‘t2’ \\ irule (cj 2 step_rules)
        \\ fs [fetch_def])
  \\ ‘t2.pc = t1.pc + 1 ∧ t2.regs RDI = SOME len ∧ t2.stack = t1.stack ∧
      t2.instructions = t1.instructions ∧ t2.memory = t1.memory ∧
      t2.input = t1.input ∧ t2.output = t1.output ∧
      t2.regs R12 = t1.regs R12 ∧ t2.regs R13 = t1.regs R13 ∧
      t2.regs R14 = SOME r14 ∧ t2.regs R15 = SOME r15’ by
       fs [Abbr‘t2’, write_reg_def, inc_def, combinTheory.APPLY_UPDATE_THM]
  (* Call AllocLoc *)
  \\ qabbrev_tac ‘t3 = set_pc AllocLoc
                       (set_stack (RetAddr (t2.pc + 1) :: t2.stack) t2)’
  \\ ‘step (State t2) (State t3)’ by
       (qunabbrev_tac ‘t3’ \\ irule (cj 7 step_rules)
        \\ fs [fetch_def])
  \\ ‘t3.pc = AllocLoc ∧ t3.regs RDI = SOME len ∧
      t3.regs R14 = SOME r14 ∧ t3.regs R15 = SOME r15 ∧
      t3.stack = RetAddr (t1.pc + 2) :: (Word hw :: (ct ⧺ rest)) ∧
      t3.instructions = t1.instructions ∧ t3.memory = t1.memory ∧
      t3.input = t1.input ∧ t3.output = t1.output ∧
      t3.regs R12 = t1.regs R12 ∧ t3.regs R13 = t1.regs R13’ by
       fs [Abbr‘t3’, set_pc_def, set_stack_def]
  \\ ‘EVEN (LENGTH (Word hw :: (ct ⧺ rest)))’ by
       fs [EVEN_ADD, ODD_EVEN, EVEN, ADD1]
  \\ ‘steps (State t,0) (State t3,0)’ by
       (irule steps_trans \\ qexists_tac ‘(State t1,0)’ \\ conj_tac >- fs []
        \\ irule steps_unroll \\ qexists_tac ‘State t2’ \\ conj_tac >- fs []
        \\ irule (cj 2 steps_rules) \\ fs [])
  (* run the malloc routine: it either exits with 4 or hands back a block at
     r14 and bumps R14 past it *)
  \\ qspecl_then [‘fs’,‘s.funs’,‘t3’,‘len’,‘r14’,‘r15’,‘t1.pc + 2’,
                  ‘Word hw::(ct ⧺ rest)’,‘0’] mp_tac alloc_steps
  \\ impl_tac >- gvs []
  \\ strip_tac
  >- (* the heap is exhausted: exit 4 *)
   (qexistsl_tac [‘(Halt 4w t3.output,0)’,‘pmap’]
    \\ conj_tac >- metis_tac [steps_trans]
    \\ ‘t3.output = s.output’ by
         (qpat_x_assum ‘state_rel fs _ t1’ mp_tac \\ rw [state_rel_def])
    \\ gvs [pmap_subsume_refl])
  (* the block is ours: RAX holds its address and R14 has moved past it.  The
     pattern is one only the new assumption can match. *)
  \\ rename1 ‘t4.regs R14 = SOME (r14 + len)’
  (* store the pointer into the variable's frame slot *)
  \\ ‘MEM (SOME vn) vs’ by fs [binders_ok_def]
  \\ ‘LENGTH vs = LENGTH (Word hw::ct)’ by fs [env_ok_def]
  \\ drule c_assign_steps
  \\ disch_then (qspecl_then [‘t4’,‘r14’,‘hw’,‘ct’,‘rest’,‘0’] mp_tac)
  \\ impl_tac >- gvs []
  \\ strip_tac
  \\ rename1 ‘has_stack t5 (LUPDATE _ _ _ ⧺ rest)’
  \\ ‘t5.regs R14 = SOME (r14 + len) ∧ t5.regs R15 = SOME r15 ∧
      t5.memory = t1.memory ∧ t5.input = t1.input ∧ t5.output = t1.output ∧
      t5.instructions = t1.instructions ∧
      t5.regs R12 = t1.regs R12 ∧ t5.regs R13 = t1.regs R13’ by gvs []
  (* the fresh block is the next index in the IMP heap *)
  \\ ‘pmap_in_bounds pmap (SOME r14)’ by
       (irule r14_mono_IMP_pmap_in_bounds
        \\ qpat_assum ‘state_rel fs s t’ (strip_assume_tac o MATCH_MP state_rel_R14)
        \\ gvs [] \\ metis_tac [])
  \\ ‘w2n len = 8 * (w2n len DIV 8)’ by
       (gvs [arithmeticTheory.MOD_EQ_0_DIVISOR]
        \\ gvs [arithmeticTheory.MULT_DIV])
  \\ qspecl_then
       [‘pmap’,
        ‘λq. if q = LENGTH s.memory then SOME (r14,w2n len DIV 8) else pmap q’,
        ‘t1.memory’,‘s.memory’,‘r14’,‘r15’,‘len’,‘w2n len DIV 8’] mp_tac alloc_pmap
  \\ impl_tac >- gvs []
  \\ strip_tac
  \\ qspecl_then [‘r14’,‘r15’,‘t1.memory’,‘len’] mp_tac heap_ok_alloc
  \\ impl_tac >- gvs []
  \\ strip_tac
  \\ ‘r14_mono (t.regs R14) (t5.regs R14)’ by
       (‘r14_mono (SOME r14) (SOME (r14 + len))’ by gvs [r14_mono_def]
        \\ gvs [] \\ metis_tac [r14_mono_trans])
  \\ qexistsl_tac
       [‘(State t5,0)’,
        ‘λq. if q = LENGTH s.memory then SOME (r14,w2n len DIV 8) else pmap q’]
  \\ conj_tac >- metis_tac [steps_trans]
  \\ gvs [cmd_res_rel_def]
  \\ rpt conj_tac
  >- (irule state_rel_step
      \\ qpat_assum ‘state_rel fs _ t1’ $ irule_at Any
      \\ imp_res_tac state_rel_IMP
      \\ gvs [])
  \\ qexists_tac ‘LUPDATE (Word r14) (index_of vn 0 vs) (Word hw::ct)’
  \\ gvs []
  \\ irule env_ok_assign \\ gvs []
  \\ irule env_ok_pmap_subsume
  \\ qexists_tac ‘pmap’ \\ gvs []
QED

Resume c_cmd_correct[GetChar]:
  qx_gen_tac ‘vn’
  \\ rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs [c_read_def]
  \\ qpat_x_assum ‘eval_cmd (GetChar _) _ = _’ mp_tac
  \\ simp [Once eval_cmd_def, bind_def, imp_source_semanticsTheory.get_char_def]
  \\ strip_tac \\ gvs []
  (* Push RAX, GetChar, then the c_assign code *)
  \\ ‘oEL t.pc t.instructions = SOME (Push RAX) ∧
      oEL (t.pc + 1) t.instructions = SOME GetChar ∧
      code_in (t.pc + 2) (flatten asm2 []) t.instructions’ by
       (qpat_x_assum ‘code_in t.pc _ _’ mp_tac
        \\ simp code_layout)
  \\ drule_all has_stack_cons \\ strip_tac \\ gvs []
  \\ ‘t.input = s.input’ by fs [state_rel_def]
  \\ ‘∃c inp. read_char s.input = (c,inp)’ by
       (Cases_on ‘read_char s.input’ \\ fs [])
  \\ imp_res_tac read_char_next
  \\ ‘t.stack = ct ⧺ rest ∧ t.regs RAX = SOME hw’ by fs [has_stack_def]
  (* Push RAX *)
  \\ qabbrev_tac ‘ta = set_stack (Word hw :: t.stack) (inc t)’
  \\ ‘step (State t) (State ta)’ by
       (qunabbrev_tac ‘ta’ \\ irule (cj 10 step_rules)
        \\ fs [fetch_def])
  \\ ‘ta.stack = Word hw :: (ct ⧺ rest) ∧ ta.pc = t.pc + 1 ∧
      ta.regs = t.regs ∧ ta.instructions = t.instructions ∧
      ta.memory = t.memory ∧ ta.input = t.input ∧ ta.output = t.output’ by
       fs [Abbr‘ta’, set_stack_def, inc_def]
  \\ ‘EVEN (LENGTH ta.stack)’ by fs [EVEN_ADD, ODD_EVEN, EVEN, ADD1]
  (* GetChar *)
  \\ qabbrev_tac ‘tb = write_reg RET_REG c
                       (unset_regs [ARG_REG; RDX] (inc (ta with input := inp)))’
  \\ ‘step (State ta) (State tb)’ by
       (qunabbrev_tac ‘tb’ \\ irule (cj 17 step_rules)
        \\ fs [fetch_def])
  \\ ‘tb.stack = Word hw :: (ct ⧺ rest) ∧ tb.pc = t.pc + 2 ∧
      tb.regs RAX = SOME c ∧ tb.instructions = t.instructions ∧
      tb.memory = t.memory ∧ tb.input = inp ∧ tb.output = t.output ∧
      tb.regs R12 = t.regs R12 ∧ tb.regs R13 = t.regs R13 ∧
      tb.regs R14 = t.regs R14 ∧ tb.regs R15 = t.regs R15’ by
       fs [Abbr‘tb’, write_reg_def, unset_regs_def, inc_def, set_stack_def,
           combinTheory.APPLY_UPDATE_THM]
  (* store the character into the variable's frame slot *)
  \\ ‘MEM (SOME vn) vs’ by fs [binders_ok_def]
  \\ ‘LENGTH vs = LENGTH (Word hw::ct)’ by fs [env_ok_def]
  \\ drule c_assign_steps
  \\ disch_then (qspecl_then [‘tb’,‘c’,‘hw’,‘ct’,‘rest’,‘0’] mp_tac)
  \\ impl_tac >- fs []
  \\ strip_tac
  \\ qexistsl_tac [‘(State t2, 0)’, ‘pmap’]
  \\ conj_tac
  >- (irule steps_trans \\ qexists_tac ‘(State ta,0)’
      \\ conj_tac >- (irule (cj 2 steps_rules) \\ fs [])
      \\ irule steps_trans \\ qexists_tac ‘(State tb,0)’
      \\ conj_tac >- (irule (cj 2 steps_rules) \\ fs [])
      \\ fs [])
  \\ imp_res_tac state_rel_R14
  \\ fs [pmap_subsume_refl, cmd_res_rel_def]
  \\ rpt conj_tac
  >- (irule state_rel_step
      \\ qpat_assum ‘state_rel _ _ t’ $ irule_at Any
      \\ imp_res_tac state_rel_IMP \\ gvs [])
  >- (fs [] \\ metis_tac [r14_mono_refl, r14_mono_IMP_pmap_in_bounds])
  \\ qexists_tac ‘LUPDATE (Word c) (index_of vn 0 vs) (Word hw::ct)’
  \\ fs [] \\ irule env_ok_assign \\ fs [v_inv_def]
QED

Resume c_cmd_correct[PutChar]:
  rw [goal_cmd_def]
  \\ qpat_x_assum ‘c_cmd _ _ _ _ = _’ mp_tac
  \\ simp [Once c_cmd_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac \\ gvs [c_write_def]
  \\ qpat_x_assum ‘eval_cmd (PutChar _) _ = _’ mp_tac
  \\ simp [Once eval_cmd_def, bind_def]
  \\ Cases_on ‘eval_exp e (s with clock := fuel)’ \\ simp []
  \\ rename [‘eval_exp e _ = (eres,se)’]
  \\ strip_tac
  \\ ‘∃v. eres = Cont v’ by (Cases_on ‘eres’ \\ not_crash_tac)
  \\ imp_res_tac eval_exp_pure \\ gvs []
  \\ Cases_on ‘v’ \\ gvs [AllCaseEqs()]
  \\ rename [‘w2n w0 < 256’]
  (* the expression code, then Mov / PutChar / Pop *)
  \\ ‘code_in t.pc (flatten asm1 []) t.instructions ∧
      oEL l1' t.instructions = SOME (Mov RDI RAX) ∧
      oEL (l1' + 1) t.instructions = SOME PutChar ∧
      oEL (l1' + 2) t.instructions = SOME (Pop RAX)’ by
       (imp_res_tac c_exp_length
        \\ qpat_x_assum ‘code_in t.pc _ _’ mp_tac
        \\ simp code_layout)
  \\ ‘∃r14a. t.regs R14 = SOME r14a’ by
       (qpat_x_assum ‘state_rel fs s t’ mp_tac \\ rw [state_rel_def]
        \\ metis_tac [])
  \\ drule_all has_stack_cons \\ strip_tac \\ gvs []
  \\ qspec_then ‘e’ mp_tac c_exp_correct
  \\ rewrite_tac [goal_exp_def]
  \\ disch_then (qspecl_then
       [‘s with clock := fuel’, ‘s with clock := fuel’, ‘0’, ‘Cont (Word w0)’,
        ‘t’, ‘vs’, ‘fs’, ‘asm1’, ‘l1'’, ‘Word hw::ct’, ‘rest’, ‘pmap’] mp_tac)
  \\ impl_tac >- (imp_res_tac c_exp_length \\ fs [state_rel_def])
  \\ strip_tac
  \\ fs [exp_res_rel_def, v_inv_def]
  \\ rename [‘steps (State t,0) (State t1,0)’]
  \\ ‘t1.stack = Word hw :: (ct ⧺ rest) ∧ t1.regs RAX = SOME w0’ by
       fs [has_stack_def]
  \\ imp_res_tac steps_inst
  \\ ‘EVEN (LENGTH t1.stack)’ by
       fs [EVEN_ADD, ODD_EVEN, EVEN, ADD1]
  (* Mov RDI RAX *)
  \\ qabbrev_tac ‘t2 = write_reg RDI w0 (inc t1)’
  \\ ‘step (State t1) (State t2)’ by
       (simp [Abbr‘t2’] \\ irule (cj 2 step_rules)
        \\ fs [fetch_def])
  (* PutChar *)
  \\ qabbrev_tac ‘t3 = unset_regs [RAX; RDI; RDX]
                         (inc (x64asm_semantics$put_char (CHR (w2n w0)) t2))’
  \\ ‘step (State t2) (State t3)’ by
       (simp [Abbr‘t3’, Abbr‘t2’] \\ irule (cj 18 step_rules)
        \\ fs [fetch_def, write_reg_def, inc_def,
               combinTheory.APPLY_UPDATE_THM, n2w_w2n, EVEN, EVEN_ADD,
               ODD_EVEN])
  (* Pop RAX *)
  \\ qabbrev_tac ‘t4 = set_stack (ct ⧺ rest) (write_reg RAX hw (inc t3))’
  \\ ‘step (State t3) (State t4)’ by
       (simp [Abbr‘t4’] \\ irule (cj 9 step_rules)
        \\ fs [Abbr‘t3’, Abbr‘t2’, fetch_def, unset_regs_def,
               write_reg_def, inc_def, x64asm_semanticsTheory.put_char_def,
               combinTheory.APPLY_UPDATE_THM])
  \\ qexistsl_tac [‘(State t4, 0)’, ‘pmap’]
  \\ conj_tac
  >- (irule steps_trans \\ qexists_tac ‘(State t1,0)’ \\ conj_tac >- fs []
      \\ irule steps_trans \\ qexists_tac ‘(State t2,0)’
      \\ conj_tac >- (irule (cj 2 steps_rules) \\ fs [])
      \\ irule steps_trans \\ qexists_tac ‘(State t3,0)’
      \\ conj_tac >- (irule (cj 2 steps_rules) \\ fs [])
      \\ irule (cj 2 steps_rules) \\ fs [])
  \\ fs [pmap_subsume_refl, cmd_res_rel_def]
  \\ imp_res_tac state_rel_R14
  \\ ‘t4.regs R14 = t1.regs R14 ∧ t4.memory = t1.memory ∧
      t4.instructions = t1.instructions ∧ t4.input = t1.input ∧
      t4.output = t1.output ⧺ [CHR (w2n w0)] ∧
      t4.regs R12 = t1.regs R12 ∧ t4.regs R13 = t1.regs R13 ∧
      t4.regs R15 = t1.regs R15 ∧ t4.regs RAX = SOME hw ∧
      t4.stack = ct ⧺ rest ∧ t4.pc = l1' + 3’ by
       fs [Abbr‘t4’, Abbr‘t3’, Abbr‘t2’, set_stack_def, write_reg_def,
           inc_def, unset_regs_def, x64asm_semanticsTheory.put_char_def,
           combinTheory.APPLY_UPDATE_THM]
  \\ rpt conj_tac
  >- (qpat_assum ‘state_rel fs _ t1’ mp_tac
      \\ rewrite_tac [state_rel_def] \\ strip_tac
      \\ fs [state_rel_def] \\ metis_tac [])
  >- metis_tac []
  >- (fs [] \\ irule r14_mono_IMP_pmap_in_bounds \\ metis_tac [])
  \\ qexists_tac ‘Word hw :: ct’ \\ fs [has_stack_def]
QED

Resume c_cmd_correct[Abort]:
  rw [goal_cmd_def, c_cmd_def, eval_cmd_def]
  \\ qexistsl_tac [‘(Halt 1w t.output, 0)’, ‘pmap’]
  \\ fs [pmap_subsume_refl]
  \\ reverse conj_tac >- fs [state_rel_def]
  \\ irule steps_trans
  \\ irule_at (Pos hd) steps_Jump
  \\ qexists_tac ‘AbortLoc’
  \\ conj_tac >- fs [fetch_def, flatten_def, code_in_def]
  \\ ‘t.output = (set_pc AbortLoc t).output’ by fs [set_pc_def]
  \\ pop_assum (fn th => once_rewrite_tac [th])
  \\ irule abortLoc_thm
  \\ imp_res_tac has_stack_ODD
  \\ qpat_x_assum ‘state_rel fs s t’ mp_tac
  \\ rewrite_tac [state_rel_def] \\ strip_tac
  \\ fs [set_pc_def] \\ metis_tac []
QED

Finalise c_cmd_correct

(* ------------------------------------------------------------------ *)
(* Top-level correctness theorems for codegen                         *)
(* ------------------------------------------------------------------ *)

(* codegen_thm — THE main semantics-preservation theorem for the      *)
(* whole-program code generator.  Corresponds to codegen_thm in       *)
(* imp2asm/ImpToASMCodegenProofs.v.                                   *)

Theorem codegen_thm:
  ∀main_c s s1 res r14 r15 t funcs.
    catch_return (eval_cmd main_c) s = (res, s1) ∧
    res ≠ Stop Crash ∧
    s.vars = FEMPTY ∧
    s.memory = [] ∧
    s.funs = funcs ∧
    t.pc = 0 ∧
    t.instructions = codegen (Program funcs) ∧
    find_fun (name "main") funcs = SOME ([], main_c) ∧
    t.stack = [] ∧
    t.input = s.input ∧
    t.output = s.output ∧
    t.regs R14 = SOME r14 ∧
    t.regs R15 = SOME r15 ∧
    memory_writable r14 r15 t.memory ⇒
    ∃outcome.
      steps (State t, s.clock - s1.clock) outcome ∧
      case outcome of
      | (State t1, ck) =>
          t1.output = s1.output ∧ ck = 0 ∧ res = Stop TimeOut
      | (Halt ec output, ck) =>
          if ec = 0w then
            output = s1.output ∧ ∃v. res = Cont v
          else
            isPREFIX output s1.output
Proof
  rw [CaseEq"prod"]
  \\ gvs [codegen_def]
  \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [flatten_def, init_def]
  \\ ntac 4
   (irule_at Any steps_unroll_any
    \\ simp [Once step_cases, oEL_def,set_pc_def,
             fetch_def, set_stack_def, write_reg_def, inc_def])
  \\ ‘t.instructions = init (lookup (name "main") fs) ⧺ flatten asm1 []’ by
       simp [init_def]
  \\ qpat_assum ‘c_fundefs s.funs _ [] = _’ assume_tac
  \\ drule codegen_code_rel
  \\ qpat_assum ‘c_fundefs s.funs _ fs = _’ assume_tac
  \\ disch_then drule
  \\ disch_then (qspecl_then [‘init (lookup (name "main") fs)’,
                              ‘lookup (name "main") fs’] mp_tac)
  \\ impl_tac
  >- simp [init_def, app_list_length_def, code_in_def, listTheory.oEL_def]
  \\ strip_tac
  (* main's code sits exactly where the table says, i.e. at the pc we jumped to *)
  \\ qpat_x_assum ‘code_rel _ _ _’ mp_tac
  \\ simp [Once code_rel_def] \\ strip_tac
  \\ first_assum drule \\ strip_tac
  \\ imp_res_tac lookup_eq_ALOOKUP \\ gvs []
  (* main's prologue is a single Sub_RSP: c_pushes emits nothing for a
     function with no parameters *)
  \\ qpat_x_assum ‘code_in _ (flatten (FST (c_fundef _ _ _)) []) _’ mp_tac
  \\ simp [Once c_fundef_def]
  \\ rpt (pairarg_tac \\ simp [])
  \\ strip_tac
  \\ ‘binders_ok main_c (vs1 ⧺ vs_bind1)’ by
       (irule binders_ok_c_bdrs \\ metis_tac [])
  \\ gvs [c_bdrs_def, c_pushes_def, push_vs_def]
  \\ gvs [flatten_def, flatten_append, code_in_append, app_list_length_def]
  \\ qmatch_asmsub_abbrev_tac ‘Sub_RSP (LENGTH vsb)’
  \\ qpat_x_assum ‘code_in _ (Sub_RSP _ :: _) _’
       (strip_assume_tac o REWRITE_RULE [code_in_def])
  \\ irule_at Any steps_unroll_any
  \\ simp [Once step_cases, fetch_def, PULL_EXISTS,
           set_stack_def, inc_def]
  \\ qspecl_then [‘s.clock’,‘main_c’] mp_tac c_cmd_correct
  \\ rewrite_tac [goal_cmd_def]
  \\ disch_then (qspecl_then
       [‘s’,‘s'’,‘v1’,
        ‘t with <|pc := lookup (name "main") fs + 1;
                  regs := t.regs⦇R13 ↦ SOME 0x7FFFFFFFFFFFFFFFw; R12 ↦ SOME 16w;
                            RAX ↦ SOME 0w⦈;
                  stack := REPLICATE (LENGTH vsb) Undefined ⧺ [RetAddr 4]|>’,
        ‘NONE::vsb’,‘fs’,‘asm2’,‘l2’,
        ‘Word 0w :: REPLICATE (LENGTH vsb) Undefined’,‘[RetAddr 4]’,‘K NONE’] mp_tac)
  \\ impl_tac
  >- (‘s with clock := s.clock = s’ by
        simp [imp_source_semanticsTheory.state_component_equality]
      \\ gvs [env_ok_def, has_stack_def, mem_inv_def, pmap_in_memory_def,
              pmap_ok_def, pmap_in_bounds_def, listTheory.oEL_def,
              combinTheory.APPLY_UPDATE_THM]
      \\ rpt conj_tac
      >- (strip_tac \\ gvs [])
      >- (simp [state_rel_def, code_rel_def, combinTheory.APPLY_UPDATE_THM]
          \\ imp_res_tac memory_writable_heap_ok
          \\ metis_tac [])
      \\ unabbrev_all_tac
      \\ rw [vs_bdrs_def] \\ gvs [even_len_EVEN]
      \\ gvs [ODD_EVEN, EVEN, EVEN_ADD, ADD1, listTheory.LENGTH_APPEND])
  \\ strip_tac
  \\ ‘s' = s1’ by gvs [AllCaseEqs()] \\ gvs []
  \\ reverse $ Cases_on ‘∃res_v. v1 = Stop (Return res_v)’
  >-
   (qpat_x_assum ‘steps _ _’ $ irule_at Any
    \\ PairCases_on ‘outcome’ \\ gvs []
    \\ reverse $ Cases_on ‘outcome0’ \\ gvs []
    \\ gvs [cmd_res_rel_def, AllCaseEqs(), state_rel_def])
  \\ gvs []
  \\ irule_at Any steps_trans
  \\ qpat_x_assum ‘steps _ _’ $ irule_at Any
  \\ PairCases_on ‘outcome’ \\ gvs []
  \\ reverse $ Cases_on ‘outcome0’ \\ gvs []
  \\ gvs [cmd_res_rel_def, AllCaseEqs(), state_rel_def]
  >- (irule_at Any (cj 1 steps_rules) \\ gvs [])
  >- (irule_at Any (cj 1 steps_rules) \\ gvs [])
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases, PULL_EXISTS]
  \\ gvs [has_stack_def, set_stack_def, set_pc_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases, PULL_EXISTS]
  \\ simp [fetch_def, lookup_def]
  \\ gvs [code_rel_def, init_code_in_def, code_in_def, init_def, oEL_def,
          write_reg_def, inc_def]
  \\ irule_at Any steps_unroll
  \\ simp [Once step_cases, PULL_EXISTS, fetch_def]
  \\ irule_at Any (cj 1 steps_rules) \\ gvs []
QED

Theorem eval_from_Cont[local]:
  eval_from k input (Program funs) = (Cont v, s) ⇒
  ∃main_c v1 s1.
    find_fun (name "main") funs = SOME ([], main_c) ∧
    catch_return (eval_cmd main_c) (init_state input funs (k − 1)) = (Cont v1, s1) ∧
    s1.output = s.output
Proof
  rw [eval_from_def, eval_cmd_thm, bind_def, get_body_and_set_vars_def,
      init_state_def, FUPDATE_LIST_THM, AllCaseEqs()]
  \\ gvs [AllCaseEqs()]
QED

(* Same for an Abort: it can only have come from the body of main. *)
Theorem eval_from_Abort[local]:
  eval_from k input (Program funs) = (Stop Abort, s) ⇒
  ∃main_c s1.
    find_fun (name "main") funs = SOME ([], main_c) ∧
    catch_return (eval_cmd main_c) (init_state input funs (k − 1)) =
      (Stop Abort, s1) ∧
    s1.output = s.output
Proof
  rw [eval_from_def, eval_cmd_thm, bind_def, get_body_and_set_vars_def,
      init_state_def, FUPDATE_LIST_THM, AllCaseEqs()]
  \\ gvs [AllCaseEqs()]
QED

(* Same for an Abort: it can only have come from the body of main. *)
Theorem eval_from_Return[local]:
  eval_from k input (Program funs) = (Stop (Return a), s) ⇒
  ∃main_c s1.
    find_fun (name "main") funs = SOME ([], main_c) ∧
    catch_return (eval_cmd main_c) (init_state input funs (k − 1)) =
      (Stop (Return a), s1) ∧
    s1.output = s.output
Proof
  rw [eval_from_def, eval_cmd_thm, bind_def, get_body_and_set_vars_def,
      init_state_def, FUPDATE_LIST_THM, AllCaseEqs()]
  \\ gvs [AllCaseEqs()]
QED

(* A TimeOut can also arise before main is entered at all -- when the clock
   runs out in get_body_and_set_vars -- and then no output has been produced. *)
Theorem eval_from_TimeOut[local]:
  eval_from k input (Program funs) = (Stop TimeOut, s) ∧ 0 < k ⇒
  ∃main_c s1.
    find_fun (name "main") funs = SOME ([], main_c) ∧
    catch_return (eval_cmd main_c) (init_state input funs (k − 1)) =
      (Stop TimeOut, s1) ∧
    s1.output = s.output
Proof
  rw [eval_from_def, eval_cmd_thm, bind_def, get_body_and_set_vars_def,
      init_state_def, FUPDATE_LIST_THM, AllCaseEqs()]
  \\ gvs [AllCaseEqs()]
QED

(* Corresponds to codegen_terminates in ImpToASMCodegenProofs.v *)
Theorem codegen_terminates:
  ∀input prog fuel output1 output2.
    imp_terminates input prog fuel output1 ∧
    (input, codegen prog) asm_terminates output2 ⇒
    output1 = output2
Proof
  Cases_on ‘prog’
  \\ rw [imp_terminates_def, asm_terminates_def, init_state_ok_def]
  \\ drule eval_from_Cont \\ strip_tac
  \\ drule codegen_thm
  \\ disch_then (qspecl_then [‘r14’,‘r15’,‘t’,‘l’] mp_tac)
  \\ impl_tac >- gvs [init_state_def]
  \\ strip_tac
  \\ PairCases_on ‘outcome’ \\ Cases_on ‘outcome0’ \\ gvs []
  \\ imp_res_tac steps_imp_RTC_step \\ fs []
  \\ imp_res_tac RTC_step_determ \\ fs []
QED

(* Corresponds to codegen_no_abort in ImpToASMCodegenProofs.v *)
Theorem codegen_no_abort:
  ∀input prog fuel output outcome s1.
    (input, codegen prog) asm_terminates output ∧
    eval_from fuel input prog = (outcome, s1) ∧
    outcome ≠ Stop Crash ⇒
    outcome ≠ Stop Abort
Proof
  Cases_on ‘prog’
  \\ rw [asm_terminates_def, init_state_ok_def]
  \\ CCONTR_TAC \\ fs []
  \\ drule eval_from_Abort \\ strip_tac
  \\ drule codegen_thm
  \\ disch_then (qspecl_then [‘r14’,‘r15’,‘t’,‘l’] mp_tac)
  \\ impl_tac >- gvs [init_state_def]
  \\ strip_tac
  \\ PairCases_on ‘outcome'’ \\ Cases_on ‘outcome'0’ \\ gvs []
  \\ imp_res_tac steps_imp_RTC_step \\ fs []
  \\ imp_res_tac RTC_step_determ \\ fs []
QED

Theorem div_lemma[local]:
  ∀outcome t n.
    (∀k. ∃t'. NRC step k (State t) (State t')) ∧
    steps (State t,n) outcome ⇒
    ∃x y. outcome = (State x,y )
Proof
  Induct_on ‘steps’ \\ gvs [] \\ rw []
  >- (first_x_assum $ qspec_then ‘1’ assume_tac
      \\ gvs [] \\ imp_res_tac step_determ \\ fs [])
  >- (first_x_assum $ qspec_then ‘1’ assume_tac
      \\ gvs [] \\ imp_res_tac step_determ \\ fs [])
  \\ gvs [] \\ first_x_assum irule
  \\ ‘∃k0. NRC step k0 (State t) (State x)’ by
       metis_tac [x64asm_propertiesTheory.steps_IMP_NRC_step]
  \\ qx_gen_tac ‘kk’
  \\ qpat_x_assum ‘∀k. ∃t'. NRC step k (State t) (State t')’
       (qspec_then ‘k0 + kk’ strip_assume_tac)
  \\ metis_tac [arithmeticTheory.NRC_ADD_EQN, NRC_step_determ]
QED

Theorem imp_output_reachable[local]:
  ∀k res s1 t r14 r15 l.
    (∀k. ∃s. eval_from k t.input (Program l) = (Stop TimeOut,s)) ∧
    (∀k. ∃t'. NRC step k (State t) (State t')) ∧
    eval_from k t.input (Program l) = (res,s1) ∧
    t.pc = 0 ∧ t.instructions = codegen (Program l) ∧ t.output = [] ∧
    t.stack = [] ∧ t.regs R14 = SOME r14 ∧ t.regs R15 = SOME r15 ∧
    memory_writable r14 r15 t.memory ⇒
    ∃t1. step꙳ (State t) (State t1) ∧ t1.output = s1.output
Proof
  rpt gen_tac \\ strip_tac
  \\ last_x_assum (qspec_then ‘k’ strip_assume_tac) \\ gvs []
  \\ Cases_on ‘k = 0’
  >- (qexists_tac ‘t’
      \\ gvs [eval_from_def, init_state_def, eval_cmd_thm, bind_def,
              get_body_and_set_vars_def, AllCaseEqs()])
  \\ ‘0 < k’ by fs []
  \\ drule_all eval_from_TimeOut \\ strip_tac
  \\ drule codegen_thm
  \\ disch_then (qspecl_then [‘r14’,‘r15’,‘t’,‘l’] mp_tac)
  \\ impl_tac >- gvs [init_state_def]
  \\ strip_tac
  \\ drule_all div_lemma \\ strip_tac \\ gvs []
  \\ first_assum $ irule_at Any
  \\ imp_res_tac steps_imp_RTC_step \\ fs []
QED

(* Corresponds to codegen_diverges in ImpToASMCodegenProofs.v *)
Theorem codegen_diverges:
  ∀input prog output.
    imp_avoids_crash input prog ∧
    (input, codegen prog) asm_diverges output ⇒
    (input, prog) imp_diverges output
Proof
  Cases_on ‘prog’
  \\ rw [asm_diverges_def, init_state_ok_def]
  \\ simp [imp_diverges_def, imp_timesout_def]
  \\ conj_asm1_tac
  >-
   (CCONTR_TAC \\ fs [imp_avoids_crash_def]
    \\ Cases_on ‘eval_from k t.input (Program l)’
    \\ reverse $ Cases_on ‘q’ \\ gvs []
    >-
     (Cases_on ‘r'’ \\ gvs []
      >-
       (drule eval_from_Return \\ strip_tac
        \\ drule codegen_thm
        \\ disch_then (qspecl_then [‘r14’,‘r15’,‘t’,‘l’] mp_tac)
        \\ impl_tac >- gvs [init_state_def]
        \\ strip_tac \\ gvs []
        \\ drule_all div_lemma \\ strip_tac \\ gvs [])
      \\ drule eval_from_Abort \\ strip_tac
      \\ drule codegen_thm
      \\ disch_then (qspecl_then [‘r14’,‘r15’,‘t’,‘l’] mp_tac)
      \\ impl_tac >- gvs [init_state_def]
      \\ strip_tac \\ gvs []
      \\ drule_all div_lemma \\ strip_tac \\ gvs [])
    \\ drule eval_from_Cont \\ strip_tac
    \\ drule codegen_thm
    \\ disch_then (qspecl_then [‘r14’,‘r15’,‘t’,‘l’] mp_tac)
    \\ impl_tac >- gvs [init_state_def]
    \\ strip_tac \\ gvs []
    \\ drule_all div_lemma \\ strip_tac \\ gvs [])
  \\ ‘∀k res s1. eval_from k t.input (Program l) = (res,s1) ⇒
        ∃t1. step꙳ (State t) (State t1) ∧ t1.output = s1.output’ by
       metis_tac [imp_output_reachable]
  \\ irule lprefix_lubTheory.IMP_build_lprefix_lub_EQ
  \\ rpt conj_tac
  >- rewrite_tac [lprefix_chain_step]
  >- (* the IMP outputs form a chain, being a subset of the machine's *)
   (irule lprefix_lubTheory.lprefix_chain_subset
    \\ qexists_tac ‘{fromList t'.output | step꙳ (State t) (State t')}’
    \\ simp [lprefix_chain_step]
    \\ rw [pred_setTheory.SUBSET_DEF, imp_output_def]
    \\ pairarg_tac \\ gvs []
    \\ res_tac \\ metis_tac [])
  >- (* every reachable output is a prefix of some IMP output *)
   (rw [lprefix_lubTheory.lprefix_rel_def] \\ gvs [PULL_EXISTS]
    \\ imp_res_tac RTC_NRC \\ rename [‘NRC step kk’]
    \\ qexists_tac ‘kk+1’
    \\ simp [imp_output_def] \\ pairarg_tac \\ simp []
    \\ qpat_assum ‘∀k. ∃s. eval_from k _ _ = (Stop TimeOut,s)’
         (qspec_then ‘kk+1’ strip_assume_tac)
    \\ gvs []
    \\ ‘0 < kk+1’ by fs []
    \\ drule_all eval_from_TimeOut \\ strip_tac
    \\ drule codegen_thm
    \\ disch_then (qspecl_then [‘r14’,‘r15’,‘t’,‘l’] mp_tac)
    \\ impl_tac >- gvs [init_state_def]
    \\ strip_tac
    \\ drule_all div_lemma \\ strip_tac \\ gvs []
    \\ gvs [AllCaseEqs()]
    \\ imp_res_tac eval_cmd_timeout_clock_zero \\ gvs []
    \\ gvs [init_state_def]
    \\ drule_all asm_output_PREFIX
    \\ simp [llistTheory.LPREFIX_fromList, llistTheory.from_toList])
  >- (* and conversely *)
   (rw [lprefix_lubTheory.lprefix_rel_def] \\ gvs [PULL_EXISTS, imp_output_def]
    \\ Cases_on ‘eval_from k t.input (Program l)’ \\ gvs []
    \\ res_tac \\ first_assum $ irule_at Any \\ simp [])
QED

(* ------------------------------------------------------------------ *)
(* Correspondence between NRC step and steps relation                 *)
(* ------------------------------------------------------------------ *)

(* The converse direction, steps_IMP_NRC_step, and NRC_step_determ are
   already proved in x64asm_properties and are used from there.  Note that
   steps takes a step without consuming fuel (rule 2 of the steps rules), so
   an NRC bound of the form n ≤ k does not hold in that direction. *)
Theorem NRC_step_IMP_steps:
  ∀n t0 t1. NRC step n t0 t1 ⇒ steps (t0, n) (t1, 0)
Proof
  Induct \\ rw [NRC] \\ res_tac
  \\ irule steps_trans
  \\ first_assum $ irule_at Any
  \\ simp [ADD1]
  \\ irule (cj 3 steps_rules) \\ simp []
QED
