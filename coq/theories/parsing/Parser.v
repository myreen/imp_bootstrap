From impboot Require Import
  utils.Core
  utils.Llist.
Import Llist.
Require Import impboot.parsing.ParserData.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.functional.FunValues.
Require Import impboot.commons.CompilerUtils.
Require Import coqutil.Word.Interface.

Require Import impboot.automation.ltac2.UnfoldFix.
From Ltac2 Require Import Ltac2.

Require Import Patat.Patat.

Open Scope N.
Open Scope string.

(* lexing *)

Fixpoint read_num (l h: ascii) (f x: N) (acc: N) (cs: list ascii): (N * list ascii) :=
  match cs return (N * list ascii) with
  [] => 
    let/d empty := [] in
    let/d result := (acc, empty) in
    result
  | c :: cs1 =>
    let/d l_asc := N_of_ascii l in
    let/d c_asc := N_of_ascii c in
    let/d h_asc := N_of_ascii h in
    if (c_asc <? l_asc)%N then
      let/d result := (acc, cs) in
      result
    else
      if (h_asc <? c_asc)%N then
        let/d result := (acc, cs) in
        result
      else
        let/d f_mult := acc * f in
        let/d c_min_x := c_asc - x in
        let/d new_acc := f_mult + c_min_x in
        let/d result := read_num l h f x new_acc cs1 in
        result
  end.

(* read_num ("0"%char, "9"%char) (10, N_of_ascii "0"%char) *)
Fixpoint read_nmc (acc: N) (cs: list ascii) (len: N): (N * list ascii * N) :=
  match cs return (N * list ascii * N) with
  [] => 
    let/d empty := [] in
    (acc, empty, len)
  | c :: cs1 =>
    let/d l_asc := N_of_ascii "0"%char in
    let/d c_asc := N_of_ascii c in
    let/d h_asc := N_of_ascii "9"%char in
    if (c_asc <? l_asc)%N then
      (acc, cs, len)
    else
      if (h_asc <? c_asc)%N then
        (acc, cs, len)
      else
        let/d f_mult := acc * 10 in
        let/d c_min_x := c_asc - (N_of_ascii "0"%char) in
        let/d new_acc := f_mult + c_min_x in
        read_nmc new_acc cs1 (len + 1)
  end.
Theorem read_nmc_equation: ltac2:(unfold_fix_type '@read_nmc).
Proof. unfold_fix_proof '@read_nmc. Qed.

(* read_num ("*"%char, "z"%char) (256, 0) *)
Fixpoint read_alp (acc: N) (cs: list ascii) (len: N): (N * list ascii * N) :=
  match cs return (N * list ascii * N) with
  [] => 
    let/d empl := [] in
    (acc, empl, len)
  | c :: cs1 =>
    let/d l_asc := N_of_ascii "*"%char in
    let/d c_asc := N_of_ascii c in
    let/d h_asc := N_of_ascii "z"%char in
    if (c_asc <? l_asc)%N then
      (acc, cs, len)
    else
      if (h_asc <? c_asc)%N then
        (acc, cs, len)
      else
        let/d f_mult := acc * 256 in
        let/d new_acc := f_mult + c_asc in
        read_alp new_acc cs1 (len + 1)
  end.
Theorem read_alp_equation: ltac2:(unfold_fix_type '@read_alp).
Proof. unfold_fix_proof '@read_alp. Qed.

Fixpoint end_line (cs: list ascii) (len: N): (list ascii * N) :=
  match cs with
  | [] => 
    ([], len)
  | c :: cs =>
    let/d newline := "010"%char in
    if Ascii.eqb c newline then 
      (cs, len + 1)
    else
      end_line cs (len + 1)
  end.
Theorem end_line_equation: ltac2:(unfold_fix_type '@end_line).
Proof. unfold_fix_proof '@end_line. Qed.

Definition q_of_nat (n: nat) (arg: N) :=
  match n with
  | 0%nat =>
    NUM arg
  | _ =>
    QUOTE arg
  end.

Fixpoint lex (q: nat) (cs: list ascii) (cs_len: N) (acc: list token) (fuel: nat): option (list token) :=
  match cs with
  | [] => Some acc
  | c :: cs =>
    match fuel with
    | 0%nat => 
      let/d result := None in
      result
    | S fuel =>
      if Ascii.eqb c " "%char then
        lex 0 cs (cs_len - 1) acc fuel
      else if Ascii.eqb c "009"%char then
        lex 0 cs (cs_len - 1) acc fuel
      else if Ascii.eqb c "010"%char then
        lex 0 cs (cs_len - 1) acc fuel
      else if Ascii.eqb c "#"%char then 
        let/d '(cs1, len) := end_line cs 0 in
        lex 0 cs1 (cs_len - len) acc fuel
      else if Ascii.eqb c "."%char then 
        let/d new_acc := DOT :: acc in
        lex 0 cs (cs_len - 1) new_acc fuel
      else if Ascii.eqb c "("%char then 
        let/d new_acc := OPEN :: acc in
        lex 0 cs (cs_len - 1) new_acc fuel
      else if Ascii.eqb c ")"%char then 
        let/d new_acc := CLOSE :: acc in
        lex 0 cs (cs_len - 1) new_acc fuel
      else if Ascii.eqb c "'"%char then 
        lex 1 cs (cs_len - 1) acc fuel
      else
        let/d c_cons := c :: cs in
        let/d digitr := read_nmc 0 c_cons 0 in
        match digitr return (option (list token)) with
        | (n, rest, len) =>
          if N.eqb len 0 then
            let/d alphar := read_alp 0 c_cons 0 in
            match alphar return (option (list token)) with
            | (n2, rest2, len2) =>
              if N.eqb len2 0 then
                lex 0 cs (cs_len - 1) acc fuel
              else
                let/d q_tok2 := q_of_nat q n2 in
                let/d new_acc2 := q_tok2 :: acc in
                lex 0 rest2 (cs_len - len2) new_acc2 fuel
            end
          else
            let/d q_tok := q_of_nat q n in
            let/d new_acc := q_tok :: acc in
            lex 0 rest (cs_len - len) new_acc fuel
        end
    end
  end.
Theorem lex_equation: ltac2:(unfold_fix_type '@lex).
Proof. unfold_fix_proof '@lex. Qed.

Definition lexer_i (input: list ascii): option (list token) :=
  let/d len := list_len input in
  let/d empty := [] in
  lex 0 input (N.of_nat len) empty len.

Definition lexer (input: list ascii): list token :=
  let/d r := lexer_i input in
  match r return (list token) with
  | None =>
    let/d res := [] in
    res
  | Some ts => ts
  end.

(* parsing *)

Definition quote (n: N) :=
  FunValues.vlist [Num (name_enc "'"); Num n].

Fixpoint parse (ts: list token) (x: Value) (stck: list Value): Value :=
  match ts with
  | [] => x
  | (CLOSE :: rest) => 
    let/d zero := Num 0 in
    let/d x_cons_s := x :: stck in
    parse rest zero x_cons_s
  | (OPEN :: rest) =>
    match stck with
    | [] => 
      parse rest x stck
    | (y :: ys) => 
      let/d pair_xy := Pair x y in
      parse rest pair_xy ys
    end
  | (NUM n :: rest) => 
    let/d n_num := Num n in
    let/d pair_nx := Pair n_num x in
    parse rest pair_nx stck
  | (QUOTE n :: rest) => 
    let/d q_n := quote n in
    let/d pair_qx := Pair q_n x in
    parse rest pair_qx stck
  | (DOT :: rest) => 
    let/d vhead := FunValues.vhead x in
    parse rest vhead stck
  end.
Theorem parse_equation: ltac2:(unfold_fix_type '@parse).
Proof. unfold_fix_proof '@parse. Qed.

(* converting from v to prog *)

Fixpoint v2list (v: FunValues.Value) :=
  match v with
  | Num _ => 
    let/d empty := [] in
    empty
  | Pair v1 v2 =>
    let/d v2_lst := v2list v2 in
    v1 :: v2_lst
  end.
Theorem v2list_equation: ltac2:(unfold_fix_type '@v2list).
Proof. unfold_fix_proof '@v2list. Qed.

Definition num2exp (n: N): exp :=
  let/d is_up := vupper n in
  if is_up then
    (*  vvvvvvvvvvvvvvvvvvvv (2 ^ 64 - 1) *)
    if (18446744073709551615 <? n)%N then
      ImpSyntax.Const (word.of_Z (Z.of_N 0)) (* fail? *)
    else
      ImpSyntax.Const (word.of_Z (Z.of_N n))
  else 
    Var n.

Fixpoint v2exp (v: Value): ImpSyntax.exp :=
  match v with
  | Num n => 
    num2exp n
  | Pair v0 v1 =>
    let/d n := vgetNum v0 in (* this can fail? *)
    match v1 return ImpSyntax.exp with
    | Num _ => 
      num2exp n (* fail? *)
    | Pair v1 v2 =>
      if N.eqb n (name_enc "'") then 
        let/d v1_n := vgetNum v1 in
        (*  vvvvvvvvvvvvvvvvvvvv (2 ^ 64 - 1) *)
        if (18446744073709551615 <? v1_n)%N then
          ImpSyntax.Const (word.of_Z (Z.of_N 0)) (* fail? *)
        else
          ImpSyntax.Const (word.of_Z (Z.of_N v1_n))
      else if N.eqb n (name_enc "var") then 
        let/d v1_n := vgetNum v1 in
        Var v1_n
      else
        match v2 with
        | Num _ => 
          num2exp n (* fail? *)
        | Pair v2 v3 =>
          if N.eqb n (name_enc "+") then 
            let/d v1_e := v2exp v1 in
            let/d v2_e := v2exp v2 in
            Add v1_e v2_e
          else if N.eqb n (name_enc "-") then 
            let/d v1_e := v2exp v1 in
            let/d v2_e := v2exp v2 in
            Sub v1_e v2_e
          else if N.eqb n (name_enc "div") then 
            let/d v1_e := v2exp v1 in
            let/d v2_e := v2exp v2 in
            Div v1_e v2_e
          else if N.eqb n (name_enc "read") then 
            let/d v1_e := v2exp v1 in
            let/d v2_e := v2exp v2 in
            Read v1_e v2_e
          else
            num2exp n (* fail? *)
        end
    end
  end.
Theorem v2exp_equation: ltac2:(unfold_fix_type '@v2exp).
Proof. unfold_fix_proof '@v2exp. Qed.

Fixpoint vs2exps (v: list Value): list ImpSyntax.exp :=
  match v with
  | [] => 
    let/d empl := [] in
    empl
  | v1 :: vs =>
    let/d v1_e := v2exp v1 in
    let/d vs_e := vs2exps vs in
    v1_e :: vs_e
  end.
Theorem vs2exps_equation: ltac2:(unfold_fix_type '@vs2exps).
Proof. unfold_fix_proof '@vs2exps. Qed.

Definition v2cmp (v: Value): ImpSyntax.cmp :=
  let/d v_n := vgetNum v in
  if N.eqb v_n (name_enc "<") then 
    Less
  else if N.eqb v_n (name_enc "=") then 
    Equal
  else
    Less. (* fail? *)

Fixpoint v2test (v: Value): ImpSyntax.test :=
  match v with
  | Num _ => 
    let/d zero_w := word.of_Z (Z.of_N 0) in
    let/d zero_c := Const zero_w in
    let/d less := Less in
    Test less zero_c zero_c (* fail? *)
  | Pair v0 v1 =>
    let/d n := vgetNum v0 in (* this can fail? *)
    match v1 return ImpSyntax.test with
    | Num _ => 
      let/d zero_w := word.of_Z (Z.of_N 0) in
      let/d zero_c := Const zero_w in
      let/d less := Less in
      Test less zero_c zero_c (* fail? *)
    | Pair v1 v2 =>
      if N.eqb n (name_enc "not") then 
        let/d v1_t := v2test v1 in
        Not v1_t
      else
        match v2 with
        | Num _ => 
          let/d zero_w := word.of_Z (Z.of_N 0) in
          let/d zero_c := Const zero_w in
          let/d less := Less in
          Test less zero_c zero_c (* fail? *)
        | Pair v2 v3 =>
          if N.eqb n (name_enc "and") then 
            let/d v1_t := v2test v1 in
            let/d v2_t := v2test v2 in
            And v1_t v2_t
          else if N.eqb n (name_enc "or") then 
            let/d v1_t := v2test v1 in
            let/d v2_t := v2test v2 in
            Or v1_t v2_t
          else
            let/d v0_c := v2cmp v0 in
            let/d v1_e := v2exp v1 in
            let/d v2_e := v2exp v2 in
            Test v0_c v1_e v2_e
        end
    end
  end.
Theorem v2test_equation: ltac2:(unfold_fix_type '@v2test).
Proof. unfold_fix_proof '@v2test. Qed.

Fixpoint v2cmd (v: Value): ImpSyntax.cmd :=
  match v with
  | Num _ =>
    let/d res := Skip in
    res
  | Pair v0 v1 =>
    let/d iPv0 := visPair v0 in
    if iPv0 then
      let/d iNv1 := visNum v1 in
      if iNv1 then
        v2cmd v0
      else
        let/d v0_c := v2cmd v0 in
        let/d v1_c := v2cmd v1 in
        Seq v0_c v1_c
    else
      let/d n := vgetNum v0 in
      if N.eqb n (name_enc "abort") then
        let/d res := Abort in
        res
      else
        match v1 with
        | Num _ => (* fail? *)
          let/d res := Skip in
          res
        | Pair v1 v2 =>
          if N.eqb n (name_enc "return") then
            let/d v1_e := v2exp v1 in
            Return v1_e
          else if N.eqb n (name_enc "getchar") then
            let/d v1_n := vgetNum v1 in
            GetChar v1_n
          else if N.eqb n (name_enc "putchar") then
            let/d v1_e := v2exp v1 in
            PutChar v1_e
          else
            match v2 with
            | Num _ => (* fail? *)
              let/d res := Skip in
              res
            | Pair v2 v3 =>
              if N.eqb n (name_enc "assign") then
                let/d v1_n := vgetNum v1 in
                let/d v2_e := v2exp v2 in
                Assign v1_n v2_e
              else if N.eqb n (name_enc "while") then
                let/d v1_t := v2test v1 in
                let/d v2_c := v2cmd v2 in
                While v1_t v2_c
              else if N.eqb n (name_enc "alloc") then
                let/d v1_n := vgetNum v1 in
                let/d v2_e := v2exp v2 in
                Alloc v1_n v2_e
              else
                match v3 with
                | Num _ =>
                  let/d v0_n := vgetNum v0 in
                  let/d v1_n := vgetNum v1 in
                  let/d v2_lst := v2list v2 in
                  let/d v2_e := vs2exps v2_lst in
                  Call v0_n v1_n v2_e
                | Pair v3 v4 =>
                  if N.eqb n (name_enc "update") then
                    let/d v1_e := v2exp v1 in
                    let/d v2_e := v2exp v2 in
                    let/d v3_e := v2exp v3 in
                    Update v1_e v2_e v3_e
                  else if N.eqb n (name_enc "if") then
                    let/d v1_t := v2test v1 in
                    let/d v2_c := v2cmd v2 in
                    let/d v3_c := v2cmd v3 in
                    If v1_t v2_c v3_c
                  else if N.eqb n (name_enc "call") then
                    let/d v1_n := vgetNum v1 in
                    let/d v2_n := vgetNum v2 in
                    let/d v3_lst := v2list v3 in
                    let/d v3_e := vs2exps v3_lst in
                    Call v1_n v2_n v3_e
                  else
                    let/d v0_n := vgetNum v0 in
                    let/d v1_n := vgetNum v1 in
                    let/d v2_v3 := Pair v2 v3 in
                    let/d pair_lst := v2list v2_v3 in
                    let/d pair_e := vs2exps pair_lst in
                    Call v0_n v1_n pair_e
                end
            end
        end
  end.
Theorem v2cmd_equation: ltac2:(unfold_fix_type '@v2cmd).
Proof. unfold_fix_proof '@v2cmd. Qed.

Fixpoint vs2args (vs: list Value) :=
  match vs with
  | [] => 
    let/d empl := [] in
    empl
  | v :: vs =>
    let/d v_n := vgetNum v in
    let/d vs_a := vs2args vs in
    let/d result := v_n :: vs_a in
    result
  end.
Theorem vs2args_equation: ltac2:(unfold_fix_type '@vs2args).
Proof. unfold_fix_proof '@vs2args. Qed.

Definition v2func (v: Value) :=
  let/d vel1 := vel1 v in
  let/d fname := vgetNum vel1 in
  let/d vel2 := vel2 v in
  let/d vel2_l := v2list vel2 in
  let/d args := vs2args vel2_l in
  let/d vel3 := vel3 v in
  let/d body := v2cmd vel3 in
  ImpSyntax.Func fname args body.

Fixpoint v2funcs (vs: list Value) :=
  match vs with
  | [] => 
    let/d empl := [] in
    empl
  | v :: vs =>
    let/d v_f := v2func v in
    let/d vs_f := v2funcs vs in
    v_f :: vs_f
  end.
Theorem v2funcs_equation: ltac2:(unfold_fix_type '@v2funcs).
Proof. unfold_fix_proof '@v2funcs. Qed.

Definition vs2prog (vs: list Value) :=
  let/d ds := v2funcs vs in
  ImpSyntax.Program ds.

(* entire parser *)

Definition parser (tokens: list token): prog :=
  let/d zero := Num 0 in
  let/d empty_s := [] in
  let/d parsed := parse tokens zero empty_s in
  let/d val_lst := v2list parsed in
  vs2prog val_lst.

Definition str2imp (str: list ascii): ImpSyntax.prog :=
  let/d toks := lexer str in
  let/d prog := parser toks in
  prog.

(* examples *)

(* (defun read_inp ()
  (
    (getchar curr)
    (if (= (var curr) '4294967295)
      (return '0)
      ((call rest read_inp ())
      ((call result cons ((var curr) (var rest) ))
      (return (var result))))
    )
  )
) *)

Example ex1 := 
  "(defun read_inp () (((getchar curr) (if (= (var curr) '4294967295) (return '0) ((call rest read_inp ()) ((call result cons ((var curr) (var rest) )) (return (var result)))))))) ".

Eval lazy in str2imp (list_ascii_of_string ex1).