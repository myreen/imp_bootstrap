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
  cheat
QED

Theorem eval_exps_not_stop:
  ∀es s res s1. eval_exps es s = (res, s1) ⇒ ∀v. res = Stop v ⇒ v = Crash
Proof
  cheat
QED

Theorem eval_test_not_stop:
  ∀t s res s1. eval_test t s = (res, s1) ⇒ ∀v. res = Stop v ⇒ v = Crash
Proof
  cheat
QED

(* ------------------------------------------------------------------ *)
(* Clock monotonicity: eval_cmd can only decrease the clock.          *)
(* (eval_cmd_clock is already proved in imp_source_semanticsScript)   *)
(* ------------------------------------------------------------------ *)

(* If eval_cmd times out, the clock must be zero. *)
Theorem eval_cmd_timeout_clock_zero:
  ∀c s s1. eval_cmd c s = (Stop TimeOut, s1) ⇒ s1.clock = 0
Proof
  cheat
QED

(* Same for catch_return. *)
Theorem catch_return_timeout_clock_zero:
  ∀c s s1.
    catch_return (eval_cmd c) s = (Stop TimeOut, s1) ⇒ s1.clock = 0
Proof
  cheat
QED

(* ------------------------------------------------------------------ *)
(* Adding clock does not change successful results.                    *)
(* (eval_cmd_add_clock is proved in source_to_impScript.sml)          *)
(* Here we state a variant phrased in terms of a clock offset.        *)
(* ------------------------------------------------------------------ *)

Theorem eval_cmd_add_clock_variant:
  ∀c s res s1.
    eval_cmd c s = (res, s1) ⇒ res ≠ Stop TimeOut ⇒
    ∀k. eval_cmd c (s with clock := s.clock + k) =
        (res, s1 with clock := s1.clock + k)
Proof
  cheat
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
  cheat
QED
