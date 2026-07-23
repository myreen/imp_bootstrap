Theory imp_to_asm_proof
Ancestors
  arithmetic list pair finite_map string words
  imp_source_syntax imp_source_semantics imp_source_properties
  x64asm_syntax x64asm_semantics x64asm_properties
  imp_to_asm
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

(* Look up the position of function name n in an f_lookup table.     *)
Definition lookup_f_def:
  lookup_f n [] = NONE ∧
  lookup_f n ((fname,pos)::fs) =
    if fname = n then SOME pos else lookup_f n fs
End

(* code_rel: initial code is present and every function has its      *)
(* compiled form at the right position in the instruction list.       *)
Definition code_rel_def:
  code_rel fs ds instructions ⇔
    init_code_in instructions ∧
    ∀n params body.
      find_fun n ds = SOME (params, body) ⇒
      ∃pos.
        lookup_f n fs = SOME pos ∧
        code_in pos (flatten (FST (c_fundef (Func n params body) pos fs)) [])
                    instructions
End

(* state_rel: relates an IMP state to an x64 ASM state.              *)
Definition state_rel_def:
  state_rel fs s t ⇔
    s.input = t.input ∧
    s.output = t.output ∧
    code_rel fs s.funs t.instructions ∧
    ∃r14 r15.
      t.regs RAX  = NONE ∧   (* placeholder — actual register setup *)
      t.regs R12  = SOME 16w ∧
      t.regs R13  = SOME (n2w (2**63 - 1)) ∧
      t.regs R14  = SOME r14 ∧
      t.regs R15  = SOME r15 ∧
      memory_writable r14 r15 t.memory
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

(* opt_rel: relates optional values using a pointwise relation.       *)
Definition opt_rel_def:
  opt_rel P NONE NONE = T ∧
  opt_rel P (SOME a) (SOME b) = P a b ∧
  opt_rel P _ _ = F
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
            opt_rel (v_inv pmap) xopt yopt
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

(* list_rel: pointwise lifting of a relation to lists.               *)
Definition list_rel_def:
  list_rel R [] [] = T ∧
  list_rel R (a::al) (b::bl) = (R a b ∧ list_rel R al bl) ∧
  list_rel R _ _ = F
End

(* exps_res_rel: relates an IMP list-of-expressions outcome to an    *)
(* ASM state with multiple words pushed on the stack.                 *)
Definition exps_res_rel_def:
  exps_res_rel ri l1 stck t1 s1 pmap ⇔
    case ri of
    | Cont vs =>
        ∃ws.
          list_rel (v_inv pmap) vs ws ∧
          mem_inv pmap t1.memory s1.memory ∧
          pmap_in_memory pmap s1.memory ∧
          has_stack t1 (MAP Word (REVERSE ws) ++ stck) ∧
          t1.pc = l1
    | _ => F
End

(* addresses_of: enumerate word-aligned addresses in a memory block. *)
Definition addresses_of_def:
  addresses_of base 0 = [] ∧
  addresses_of base (SUC n) = base :: addresses_of (base + 8w) n
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
    ∀old_wr14 new_wr14.
      old_r14 = SOME old_wr14 ∧ new_r14 = SOME new_wr14 ⇒
        old_wr14 <+ new_wr14 ∨ old_wr14 = new_wr14
End

(* has_address: addr is the n-th slot in a block at base of length l. *)
Definition has_address_def:
  has_address addr base length ⇔
    ∃n. n < length ∧ base + n2w (n * 8) = addr
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
      ∃outcome.
        steps (State t, fuel) outcome ∧
        case outcome of
        | (Halt ec output, _) => F
        | (State t1, fuel1) =>
            state_rel fs s1 t1 ∧
            fuel1 = fuel ∧
            r14_mono (t.regs R14) (t1.regs R14) ∧
            exp_res_rel res l1 (curr ++ rest) t1 s1 pmap
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
      ∃outcome.
        steps (State t, fuel) outcome ∧
        case outcome of
        | (Halt ec output, _) => F
        | (State t1, fuel1) =>
            state_rel fs s1 t1 ∧
            fuel1 = fuel ∧
            r14_mono (t.regs R14) (t1.regs R14) ∧
            exps_res_rel res l1 (curr ++ rest) t1 s1 pmap
End

(*
(* goal_test: compiled test is correct.                               *)
Definition goal_test_def:
  goal_test tst ⇔
    ∀s s1 fuel b t t1 vs fs asmc l1 ltrue lfalse curr rest pmap.
      eval_test tst s = (Cont b, s1) ∧
      c_test tst ltrue lfalse t.pc vs = (asmc, l1) ∧
      state_rel fs s t ∧
      env_ok s.vars vs curr pmap ∧
      has_stack t (curr ++ rest) ∧
      mem_inv pmap t.memory s.memory ∧
      (∃r14. pmap_in_bounds pmap (SOME r14)) ∧
      pmap_in_memory pmap s.memory ∧
      pmap_ok pmap ∧
      ODD (LENGTH rest) ∧
      code_in t.pc (flatten asmc []) t.instructions ⇒
      ∃outcome.
        steps (State t, fuel) outcome ∧
        case outcome of
        | (Halt ec output, _) => F
        | (State t1, fuel1) =>
            state_rel fs s1 t1 ∧
            fuel1 = fuel ∧
            r14_mono (t.regs R14) (t1.regs R14) ∧
            mem_inv pmap t1.memory s1.memory ∧
            pmap_in_memory pmap s1.memory ∧
            has_stack t1 (curr ++ rest) ∧
            t1.pc = (if b then ltrue else lfalse)
End
*)

(* goal_cmd: compiled command is correct.                             *)
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

Theorem prefix_trans:
  ∀s1 s2 s3.
    isPREFIX s1 s2 ⇒ isPREFIX s2 s3 ⇒ isPREFIX s1 s3
Proof
  cheat
QED

Theorem give_up:
  ∀fs ds t w n.
    code_rel fs ds t.instructions ∧
    t.regs R15 = SOME w ∧
    t.pc = give_up (ODD (LENGTH t.stack)) ⇒
    steps (State t, n) (Halt 4w t.output, n)
Proof
  cheat
QED

Theorem abortLoc_thm:
  ∀fs ds t w n.
    code_rel fs ds t.instructions ∧
    t.regs R15 = SOME w ∧
    ODD (LENGTH t.stack) ∧
    t.pc = abortLoc ⇒
    steps (State t, n) (Halt 1w t.output, n)
Proof
  cheat
QED

Theorem code_in_append:
  ∀xs ys n code.
    code_in n (xs ++ ys) code ⇔
    code_in n xs code ∧ code_in (n + LENGTH xs) ys code
Proof
  cheat
QED

Theorem env_ok_pmap_subsume:
  ∀vars vs curr pmap pmap1.
    env_ok vars vs curr pmap ∧ pmap_subsume pmap pmap1 ⇒
    env_ok vars vs curr pmap1
Proof
  cheat
QED

Theorem pmap_subsume_refl:
  ∀pmap. pmap_subsume pmap pmap
Proof
  cheat
QED

Theorem pmap_subsume_trans:
  ∀pmap1 pmap2 pmap3.
    pmap_subsume pmap1 pmap2 ∧ pmap_subsume pmap2 pmap3 ⇒
    pmap_subsume pmap1 pmap3
Proof
  cheat
QED

Theorem r14_mono_refl:
  ∀r14. r14_mono r14 r14
Proof
  cheat
QED

Theorem r14_mono_trans:
  ∀r14a r14b r14c.
    r14_mono r14a r14b ∧ r14_mono r14b r14c ⇒ r14_mono r14a r14c
Proof
  cheat
QED

Theorem r14_mono_IMP_pmap_in_bounds:
  ∀pmap mr14old r14old r14new.
    pmap_in_bounds pmap (SOME r14old) ∧
    r14_mono (SOME r14old) (SOME r14new) ⇒
    pmap_in_bounds pmap (SOME r14new)
Proof
  cheat
QED

(* ------------------------------------------------------------------ *)
(* Correctness theorems for individual expression forms               *)
(* ------------------------------------------------------------------ *)

Theorem c_exp_correct:
  ∀e. goal_exp e
Proof
  cheat
QED

Theorem c_exps_correct:
  ∀es. goal_exps es
Proof
  cheat
QED

Theorem c_test_correct:
  ∀tst. goal_test tst
Proof
  cheat
QED

Theorem c_cmd_correct:
  ∀fuel c. goal_cmd c fuel
Proof
  cheat
QED

(* ------------------------------------------------------------------ *)
(* Top-level correctness theorems for codegen                         *)
(* ------------------------------------------------------------------ *)

(*
(* asm_terminates: the ASM program terminates with given output.      *)
Definition asm_terminates_def:
  asm_terminates _input _instructions _output = ARB (*
    ∃fuel t.
      steps ARB (* (State <| pc := 0; regs := K NONE; stack := [];
                      instructions := instructions; memory := K NONE;
                      input := input; output := [] |>, fuel) *)
            (Halt 0w output, 0) *)
End
*)

Theorem codegen_thm:
  ∀main_c fuel s s1 res r14 r15 t funcs.
    eval_cmd main_c s = (res, s1) ∧
    res ≠ Stop Crash ∧
    s.funs = funcs ∧
    state_rel [] s t ∧
    t.regs R14 = SOME r14 ∧
    t.regs R15 = SOME r15 ∧
    pmap_in_bounds (λ_. NONE) (SOME r14) ∧
    ODD (LENGTH t.stack) ⇒
    ∃outcome pmap.
      steps (State t, s.clock - s1.clock) outcome ∧
      pmap_ok pmap ∧
      case outcome of
      | (Halt ec output, ck) =>
          isPREFIX output s1.output ∧ (ec = 1w ∨ ec = 4w)
      | (State t1, ck) =>
          ck = 0 ∧
          state_rel [] s1 t1 ∧
          r14_mono (t.regs R14) (t1.regs R14)
Proof
  cheat
QED

(* Corresponds to codegen_terminates in ImpToASMCodegenProofs.v:
   if the IMP program terminates (in the strong sense) with output1 and
   the generated ASM terminates with output2, the outputs agree. *)
Theorem codegen_terminates:
  ∀input prog fuel output1 output2.
    imp_terminates input prog fuel output1 ∧
    (input, codegen prog) asm_terminates output2 ⇒
    output1 = output2
Proof
  cheat
QED

(* Corresponds to codegen_no_abort in ImpToASMCodegenProofs.v:
   if the generated ASM terminates and the IMP program does not crash,
   then the IMP program does not abort either. *)
Theorem codegen_no_abort:
  ∀input prog fuel output outcome s1.
    (input, codegen prog) asm_terminates output ∧
    eval_from fuel input prog = (outcome, s1) ∧
    outcome ≠ Stop Crash ⇒
    outcome ≠ Stop Abort
Proof
  cheat
QED

(* Corresponds to codegen_diverges in ImpToASMCodegenProofs.v:
   if the IMP program never crashes and the generated ASM diverges with
   some output, then the IMP program diverges with the same output. *)
Theorem codegen_diverges:
  ∀input prog output.
    imp_avoids_crash input prog ∧
    (input, codegen prog) asm_diverges output ⇒
    (input, prog) imp_diverges output
Proof
  cheat
QED

(* ------------------------------------------------------------------ *)
(* Correspondence between NRC step and steps relation                 *)
(* ------------------------------------------------------------------ *)

Theorem NRC_step_IMP_steps:
  ∀n t0 t1. NRC step n t0 t1 ⇒ steps (t0, n) (t1, 0)
Proof
  cheat
QED

Theorem steps_IMP_NRC_step:
  ∀s k res r.
    steps (s, k) (res, r) ⇒
    ∃n. NRC step n s res ∧ n ≤ k
Proof
  cheat
QED

Theorem NRC_step_determ:
  ∀k s res1 res2.
    NRC step k s res1 ∧ NRC step k s res2 ⇒ res1 = res2
Proof
  cheat
QED

Theorem steps_NRC:
  ∀s1 n1 s2 n2.
    steps (s1, n1) (s2, n2) ⇔
    ∃k. NRC step k s1 s2 ∧ k ≤ n1 ∧ n2 = n1 - k
Proof
  cheat
QED
