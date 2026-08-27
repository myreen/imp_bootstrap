From Ltac2 Require Import Ltac2 Std.
From impboot.utils Require Import Core.
From impboot.commons Require Import CompilerUtils.

Open Scope list_scope.
Open Scope nat.

Lemma dlet_spec: forall {A B: Type} (a: A) (f: A -> B),
  let/d x := a in f x = let x := a in f x.
Proof.
  intros; reflexivity ().
Qed.

Ltac2 rewrite_lowerable_step (): unit :=
  match! goal with
  | [ |- context [ Nat.mul 8%nat _ ] ] =>
    rewrite <- mulnat_8_spec_l
  | [ |- context [ Nat.mul _ 8%nat ] ] =>
    rewrite <- mulnat_8_spec_r
  | [ |- context [ Nat.mul 10%nat _ ] ] =>
    rewrite <- mulnat10_spec_l
  | [ |- context [ Nat.mul _ 10%nat ] ] =>
    rewrite <- mulnat10_spec_r
  | [ |- context [ N.mul 10%N _ ] ] =>
    rewrite <- mulN_10_spec_l
  | [ |- context [ N.mul _ 10%N ] ] =>
    rewrite <- mulN_10_spec_r
  | [ |- context [ N.mul 256%N _ ] ] =>
    rewrite <- mulN_256_spec_l
  | [ |- context [ N.mul _ 256%N ] ] =>
    rewrite <- mulN_256_spec_r
  | [ |- context ctx [ N_modulo ?e 10%N ] ] =>
    let inst := Pattern.instantiate ctx constr:(Nmod_10 $e) in
    change $inst
  | [ |- context ctx [ N_modulo ?e 256%N ] ] =>
    let inst := Pattern.instantiate ctx constr:(Nmod_256 $e) in
    change $inst
  | [ |- context ctx [ nat_mod ?e 10%nat ] ] =>
    let inst := Pattern.instantiate ctx constr:(natmod10 $e) in
    change $inst
  | [ |- context [ (_ ++ _)%string ] ] =>
    rewrite <- str_app_spec
  | [ |- context [ (_ ++ _)%list ] ] =>
    rewrite <- list_app_spec
  | [ |- context [ List.length _ ] ] =>
    rewrite <- list_len_spec
  | [ |- context c [ dlet (?x1 :: ?x2 :: ?x3 :: ?x4 :: ?x5 :: ?rst) ?f ] ] =>
    let new_constr := constr:(
      let/d sfx := $x5 :: $rst in
      dlet ($x1 :: $x2 :: $x3 :: $x4 :: sfx) $f
    ) in
    let inst := Pattern.instantiate c new_constr in
    change $inst
  end.

Ltac2 rewrite_lowerable (): unit :=
  repeat (rewrite_lowerable_step ()).
