
open HolKernel Parse boolLib bossLib BasicProvers;
open arithmeticTheory listTheory llistTheory pairTheory finite_mapTheory;
open source_valuesTheory imp_source_syntaxTheory stringTheory lprefix_lubTheory;

val _ = new_theory "imp_source_semantics";


(* types *)

Datatype:
  v = Word word64 | Pointer num
End

Type mem_block = “: v option list”;

Datatype:
  state = <| vars   : num |-> v       (* the local variables                           *)
           ; memory : mem_block list  (* memory consists of a list of blocks           *)
           ; funs   : func list       (* all defined functions                         *)
           ; clock  : num             (* clock for divergence preservation             *)
           ; input  : char llist      (* content of stdin, a potentially infinite list *)
           ; output : char list  |>   (* content of stdout, always a finite list       *)
End

Datatype:
  result = Return 'a | TimeOut | Crash | Abort
End

Datatype:
  outcome = Cont 'b | Stop ('a result)
End


(* monad syntax *)

Type M = ``:state -> 'a result # state``

Definition bind_def:
  bind f g (s:state) =
    case f s of
    | (Cont res, s1) => g res s1
    | (Stop e, s1) => (Stop e, s1)
End

Definition unit_bind_def[simp]:
  unit_bind f g (s:state) = bind f (K g) s
End

Overload monad_unitbind[local] = ``unit_bind``
Overload monad_bind[local] = ``bind``
Overload return[local] = ``return``

val _ = monadsyntax.add_monadsyntax()


(* helper functions for primitive operations etc. *)

Definition stop_def[simp]:
  stop v s = (Stop v, s:state)
End

Definition cont_def[simp]:
  cont v s = (Cont v, s:state)
End

Definition next_def:
  next s =
    case LHD s of
    | NONE => Word (n2w (2 ** 32 - 1)) (* EOF *)
    | SOME c => Word (n2w (ORD c))
End

Definition lookup_var_def[simp]:
  lookup_var n s =
    case FLOOKUP s.vars n of
     | SOME v => cont v s
     | NONE => stop Crash s
End

Definition combine_words_def[simp]:
  combine_word f (Word w1) (Word w2) = cont (Word (f w1 w2)) ∧
  combine_word f _ _ = stop Crash
End

Definition mem_load_def[simp]:
  mem_load (Pointer p) (Word w) s =
    (if w2n w MOD 8 ≠ 0 then (Stop Crash, s) else
     case oEL p s.memory of
     | NONE => stop Crash s
     | SOME block =>
       case oEL (w2n w DIV 8) block of
       | SOME (SOME w) => cont w s
       | _ => stop Crash s) ∧
  mem_load _ _ s = stop Crash s
End

Definition eval_exp_def[simp]:
  eval_exp (Const w)   = cont (Word w) ∧
  eval_exp (Var n)     = lookup_var n ∧
  eval_exp (Add e1 e2) =
    (do v1 <- eval_exp e1 ;
        v2 <- eval_exp e2 ;
        combine_word (+) v1 v2 od) ∧
  eval_exp (Sub e1 e2) =
    (do v1 <- eval_exp e1 ;
        v2 <- eval_exp e2 ;
        combine_word (-) v1 v2 od) ∧
  eval_exp (Div e1 e2) =
    (do v1 <- eval_exp e1 ;
        v2 <- eval_exp e2 ;
        (if v2 = Word 0w then stop Crash else combine_word word_div v1 v2) od) ∧
  eval_exp (Read e1 e2) =
    (do addr <- eval_exp e1 ;
        offset <- eval_exp e2 ;
        mem_load addr offset od)
End

Definition eval_exps_def[simp]:
  eval_exps [] = cont [] ∧
  eval_exps (e::es) =
    do v <- eval_exp e ;
       vs <- eval_exps es ;
       cont (v::vs) od
End

Definition dest_word_def[simp]:
  dest_word (Word w) = cont w ∧
  dest_word _ = stop Crash
End

Definition eval_cmp_def[simp]:
  eval_cmp Less (Word w1) (Word w2) = cont (w1 <+ w2) ∧
  eval_cmp Equal (Word w1) (Word w2) = cont (w1 = w2) ∧
  eval_cmp Equal (Pointer p) (Word w) = (if w = 0w then cont F else stop Crash) ∧
  eval_cmp _ _ _ = stop Crash
End

Definition eval_test_def[simp]:
  eval_test (Test cmp e1 e2) =
    do v1 <- eval_exp e1 ;
       v2 <- eval_exp e2 ;
       eval_cmp cmp v1 v2
    od ∧
  eval_test (And t1 t2) =
    do b1 <- eval_test t1 ;
       b2 <- eval_test t2 ;
       cont (b1 ∧ b2)
    od ∧
  eval_test (Or t1 t2) =
    do b1 <- eval_test t1 ;
       b2 <- eval_test t2 ;
       cont (b1 ∨ b2)
    od ∧
  eval_test (Not t) =
    do b <- eval_test t ;
       cont (¬b)
    od
End

Definition assign_def[simp]:
  assign n v s =
    cont () (s with vars := s.vars |+ (n,v))
End

Definition fix_def: (* helps prove termination of the definition of eval_cmd *)
  fix s x =
    if (SND x).clock ≤ s.clock then x
    else (FST x, SND x with clock := s.clock)
End

Definition tick_def:
  tick s =
    if s.clock = 0 then stop TimeOut s
    else cont () (s with clock := s.clock - 1)
End

Theorem eval_exp_pure:
  ∀t r s s'. eval_exp t s = (r,s') ⇒ s' = s
Proof
  Induct \\ fs [eval_exp_def,AllCaseEqs()]
  \\ rw [] \\ gvs [bind_def,AllCaseEqs()]
  \\ TRY (Cases_on ‘v1’ \\ Cases_on ‘v2’ \\ gvs [AllCaseEqs()])
  THEN1 (FULL_CASE_TAC \\ fs [])
  \\ Cases_on ‘addr’ \\ Cases_on ‘offset’ \\ gvs [AllCaseEqs()]
QED

Theorem eval_exps_pure:
  ∀t s r s'. eval_exps t s = (r,s') ⇒ s' = s
Proof
  Induct \\ fs [eval_exps_def,bind_def] \\ rw []
  \\ gvs [AllCaseEqs()] \\ res_tac \\ gvs []
  \\ imp_res_tac eval_exp_pure \\ gvs []
QED

Theorem dest_word_eq[simp]:
  (dest_word v1 s1 = (Cont w1,t1) ⇔ v1 = Word w1 ∧ s1 = t1) ∧
  (dest_word v1 s1 = (Stop e,t1) ⇔ ∃p. e = Crash ∧ v1 = Pointer p ∧ s1 = t1)
Proof
  Cases_on ‘v1’ \\ rw []
QED

Theorem eval_test_pure:
  ∀t s r s'. eval_test t s = (r,s') ⇒ s' = s
Proof
  Induct \\ gvs [eval_test_def,bind_def,AllCaseEqs()] \\ rw []
  \\ gvs [] \\ imp_res_tac eval_exp_pure \\ fs [] \\ res_tac
  \\ gvs [AllCaseEqs(), DefnBase.one_line_ify NONE eval_cmp_def]
  \\ every_case_tac \\ fs []
QED

Definition find_fun_def:
  find_fun n [] = NONE ∧
  find_fun n (Func m params body :: rest) =
    if n = m then SOME (params, body) else find_fun n rest
End

Definition update_block_def:
  update_block (vs:mem_block) offset v =
    if offset < LENGTH vs then SOME (LUPDATE (SOME v) offset vs) else NONE
End

Definition update_def:
  update (Pointer p) (Word offset) v s =
    (if w2n offset MOD 8 ≠ 0 then (Stop Crash, s) else
       case oEL p s.memory of
       | NONE => (Stop Crash, s)
       | SOME vs =>
         case update_block vs (w2n offset DIV 8) v of
         | NONE => (Stop Crash, s)
         | SOME ws => (Cont (), s with memory := LUPDATE ws p s.memory)) ∧
  update _ _ v s = (Stop Crash, s)
End

Definition alloc_def:
  alloc len s =
    if w2n len MOD 8 ≠ 0 then (Stop Crash, s) else
      (Cont (Pointer (LENGTH s.memory)),
       s with memory := s.memory ++ [REPLICATE (w2n len DIV 8) NONE])
End

Definition put_char_def[simp]:
  put_char (Pointer p) s = stop Crash s ∧
  put_char (Word w) s =
    if w2n w < 256 then cont () (s with output := s.output ++ [CHR (w2n w)])
                   else stop Crash s
End

Definition next_def[allow_rebind]:
  next l =
    case LHD l of
    | NONE   => Word (n2w (2 ** 32 - 1)) (* EOF *)
    | SOME c => Word (n2w (ORD c))
End

Definition get_char_def:
  get_char s =
    (Cont (next s.input),
     s with input := case LTL s.input of NONE => s.input | SOME t => t)
End

Definition get_vars_def[simp]:
  get_vars s = cont s.vars s
End

Definition set_vars_def[simp]:
  set_vars vs s = cont () (s with vars := vs)
End

Definition get_body_and_set_vars_def:
  get_body_and_set_vars m vs s =
  case find_fun m s.funs of
  | NONE => (Stop Crash, s)
  | SOME (params, body) =>
      (if LENGTH params ≠ LENGTH vs ∨ ~ALL_DISTINCT params then
         (Stop Crash, s)
       else if s.clock = 0 then
         (Stop TimeOut, s)
       else (cont body (s with <| vars := FEMPTY |++ ZIP (params,vs) ;
                                  clock := s.clock − 1 |> )))
End

Definition catch_return_def[simp]:
  catch_return f s =
    case f s of
    | (Cont _, s) => (Stop Crash, s)
    | (Stop (Return v), s) => cont v s
    | (Stop TimeOut,s) => (Stop TimeOut,s)
    | (Stop Crash,s) => (Stop Crash,s)
    | (Stop Abort,s) => (Stop Abort,s)
End

Definition eval_cmd_def:
  eval_cmd [] s = cont () s ∧
  eval_cmd (x::y::ys) s =
   (case fix s (eval_cmd [x] s) of
    | (Stop r, s) => (Stop r, s)
    | (Cont v, s) => eval_cmd (y::ys) s) ∧
  eval_cmd [Assign n e] s =
   do v <- eval_exp e ;
      assign n v od s ∧
  eval_cmd [Abort] s = (Stop Abort, s) ∧
  eval_cmd [PutChar c] s =
   do v <- eval_exp c ;
      put_char v od s ∧
  eval_cmd [GetChar n] s =
   do v <- get_char ;
      assign n v od s ∧
  eval_cmd [Alloc n e] s =
    do
       val <- eval_exp e ;
       len <- dest_word val ;
       ptr <- alloc len ;
       assign n ptr
    od s ∧
  eval_cmd [Update e1 e2 e3] s =
    do
       ptr <- eval_exp e1 ;
       off <- eval_exp e2 ;
       val <- eval_exp e3 ;
       update ptr off val
    od s ∧
  eval_cmd [If t cs1 cs2] s =
   (case eval_test t s of
    | (Stop r, s) => (Stop r, s)
    | (Cont v, s) => eval_cmd (if v then cs1 else cs2) s) ∧
  eval_cmd [Return e] s =
   do v <- eval_exp e ;
      stop (Return v) od s ∧
  eval_cmd [Call n m es] s =
   (case eval_exps es s of
    | (Stop r, s) => (Stop r, s)
    | (Cont vs, s) =>
       let vars = s.vars in
       case find_fun m s.funs of
       | NONE => (Stop Crash, s)
       | SOME (params, body) =>
           (if LENGTH params ≠ LENGTH vs ∨ ~ALL_DISTINCT params
            then (Stop Crash, s)
            else case tick s of
            | (Stop r, s) => (Stop r, s)
            | (Cont v, s) =>
               (case eval_cmd body (s with vars := FEMPTY |++ ZIP (params,vs)) of
                | (Cont _, s) => (Stop Crash, s)
                | (Stop (Return v), s) => assign n v (s with vars := vars)
                | res => res))) ∧
  eval_cmd [While t cs] s =
   (case eval_test t s of
    | (Stop r, s) => (Stop r, s)
    | (Cont v, s) =>
       if ~v then (Cont (), s) else
       (case fix s (eval_cmd cs s) of
        | (Stop r, s) => (Stop r, s)
        | (Cont v, s) =>
           (case tick s of
            | (Stop r, s) => (Stop r, s)
            | (Cont v, s) =>
               eval_cmd [While t cs] s)))
Termination
  WF_REL_TAC ‘inv_image (measure I LEX measure I) (λ(xs,s). (s.clock,cmd1_size xs))’
  \\ rw [] \\ fs [fix_def,CaseEq"bool"] \\ rw [] \\ fs []
  \\ gvs [tick_def,AllCaseEqs(),stop_def,cont_def]
  \\ imp_res_tac eval_test_pure \\ gvs []
  \\ imp_res_tac eval_exps_pure \\ gvs []
End

Theorem eval_cmd_clock:
  ∀xs s res s'. eval_cmd xs s = (res,s') ⇒ s'.clock ≤ s.clock
Proof
  ho_match_mp_tac eval_cmd_ind \\ reverse (rw [])
  \\ pop_assum mp_tac
  \\ TRY
   (rename [‘While’]
    \\ once_rewrite_tac [eval_cmd_def]
    \\ TOP_CASE_TAC \\ fs []
    \\ imp_res_tac eval_test_pure \\ gvs []
    \\ TOP_CASE_TAC \\ fs [] \\ rw [] \\ gvs []
    \\ Cases_on ‘eval_cmd xs r’ \\ fs [] \\ gvs [fix_def]
    \\ Cases_on ‘q’ \\ fs [] \\ rw [] \\ gvs []
    \\ gvs [tick_def,cont_def,stop_def]
    \\ gvs [AllCaseEqs()])
  \\ TRY
   (rename [‘Call’]
    \\ once_rewrite_tac [eval_cmd_def]
    \\ TOP_CASE_TAC \\ fs []
    \\ imp_res_tac eval_exps_pure \\ gvs [] \\ rw [] \\ gvs []
    \\ rpt (FULL_CASE_TAC \\ gvs [])
    \\ gvs [fix_def,tick_def,stop_def,cont_def]
    \\ gvs [AllCaseEqs()])
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
  \\ gvs [put_char_def |> DefnBase.one_line_ify NONE, AllCaseEqs()]
  \\ FULL_CASE_TAC
  \\ gvs [cont_def,stop_def,fix_def,AllCaseEqs(),bind_def,assign_def,
          update_def |> DefnBase.one_line_ify NONE, alloc_def,
          dest_word_def |> DefnBase.one_line_ify NONE]
QED

Triviality fix_eval:
  fix s (eval_cmd xs s) = eval_cmd xs s
Proof
  Cases_on ‘eval_cmd xs s’ \\ imp_res_tac eval_cmd_clock \\ fs [fix_def]
QED

Theorem eval_cmd_def[allow_rebind] = REWRITE_RULE [fix_eval] eval_cmd_def;
Theorem eval_cmd_ind[allow_rebind] = REWRITE_RULE [fix_eval] eval_cmd_ind;

Theorem eval_cmd_thm:
  eval_cmd [] = cont () ∧
  eval_cmd (x::y::ys) =
    do eval_cmd [x]
     ; eval_cmd (y::ys)
    od ∧
  eval_cmd [Assign n e] =
    do v <- eval_exp e
     ; assign n v
    od ∧
  eval_cmd [Return e] =
    do v <- eval_exp e
     ; stop (Return v)
    od ∧
  eval_cmd [PutChar c] =
    do v <- eval_exp c
     ; put_char v
    od ∧
  eval_cmd [GetChar n] =
    do v <- get_char
     ; assign n v od ∧
  eval_cmd [Alloc n e] =
    do val <- eval_exp e
     ; len <- dest_word val
     ; ptr <- alloc len
     ; assign n ptr
    od ∧
  eval_cmd [Update e1 e2 e3] =
    do ptr <- eval_exp e1
     ; off <- eval_exp e2
     ; val <- eval_exp e3
     ; update ptr off val
    od ∧
  eval_cmd [If t cs1 cs2] =
    do b <- eval_test t
     ; eval_cmd (if b then cs1 else cs2)
    od ∧
  eval_cmd [While t cs] =
    do b <- eval_test t
     ; if ~b then cont () else
         do eval_cmd cs ; tick ; eval_cmd [While t cs] od
    od ∧
  eval_cmd [Call n fname es] =
    do args <- eval_exps es
     ; locals <- get_vars
     ; body <- get_body_and_set_vars fname args
     ; v <- catch_return (eval_cmd body)
     ; set_vars locals
     ; assign n v
    od
Proof
  rpt conj_tac
  \\ once_rewrite_tac [FUN_EQ_THM]
  \\ once_rewrite_tac [eval_cmd_def]
  \\ rw [bind_def,get_body_and_set_vars_def,tick_def]
  \\ TOP_CASE_TAC \\ gvs [cont_def]
  \\ TOP_CASE_TAC \\ gvs [cont_def]
  \\ TOP_CASE_TAC \\ gvs [cont_def]
  \\ TOP_CASE_TAC \\ gvs [cont_def]
  \\ TOP_CASE_TAC \\ gvs [cont_def,bind_def,tick_def]
  \\ rpt (CASE_TAC \\ fs [])
QED

(* --- observable semantics --- *)

Definition init_state_def:
  init_state inp funs k =
    <| vars   := FEMPTY
     ; memory := []
     ; funs   := funs
     ; clock  := k
     ; input  := inp
     ; output := [] |>
End

Definition eval_from_def:
  eval_from k input (Program funs) =
    eval_cmd [Call 0 (name "main") []] (init_state input funs k)
End

Definition imp_avoids_crash_def:
  imp_avoids_crash input prog =
    ∀k res s. eval_from k input prog = (res, s) ⇒ res ≠ Stop Crash
End

Definition imp_timesout_def:
  imp_timesout k input prog =
    ∃s. eval_from k input prog = (Stop TimeOut, s)
End

Definition imp_output_def:
  imp_output k input prog =
    let (res,s) = eval_from k input prog in
      fromList s.output
End

val _ = set_fixity "imp_diverges" (Infixl 480);

Definition imp_diverges_def:
  (input, prog) imp_diverges output ⇔
    (∀k. imp_timesout k input prog) ∧
    output = build_lprefix_lub { imp_output k input prog | k IN UNIV }
End

val _ = set_fixity "imp_weak_termination" (Infixl 480);

Definition imp_weak_termination_def:
  (input, prog) imp_weak_termination output ⇔
  ∃k outcome s.
    eval_from k input prog = (outcome, s) ∧
    (outcome ≠ Stop Abort ⇒ outcome = Cont () ∧ s.output = output)
End

val _ = export_theory();
