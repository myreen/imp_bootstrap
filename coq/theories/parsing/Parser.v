From impboot Require Import
  utils.Core
  utils.Llist.
Import Llist.
Require Import impboot.parsing.ParserData.
Require Import impboot.imp2asm.ImpToASMCodegen.
Require Import impboot.imperative.ImpSyntax.
Require Import impboot.functional.FunValues.
Require Import impboot.commons.CompilerUtils.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.

Require Import impboot.automation.ltac2.UnfoldFix.
From Ltac2 Require Import Ltac2.

Require Import Patat.Patat.

Open Scope N.
Open Scope string.

(* lexing *)

Fixpoint read_num (l h: ascii) (f x: N) (acc: N) (cs: list ascii): (N * list ascii) :=
  match cs with
  [] => 
    let/d empty_list := [] in
    let/d result := (acc, empty_list) in
    result
  | c :: cs1 =>
    let/d l_ascii := N_of_ascii l in
    let/d c_ascii := N_of_ascii c in
    let/d h_ascii := N_of_ascii h in
    if (c_ascii <? l_ascii)%N then
      let/d result := (acc, cs) in
      result
    else
      if (h_ascii <? c_ascii)%N then
        let/d result := (acc, cs) in
        result
      else
        let/d f_mult_acc := f * acc in
        let/d c_minus_x := c_ascii - x in
        let/d new_acc := f_mult_acc + c_minus_x in
        let/d result := read_num l h f x new_acc cs1 in
        result
  end.
Theorem read_num_equation: ltac2:(unfold_fix_type '@read_num).
Proof. unfold_fix_proof '@read_num. Qed.

Fixpoint end_line (cs: list ascii) :=
  match cs with
  | [] => 
    let/d empty_list := [] in
    empty_list
  | c :: cs =>
    let/d newline_char := "010"%char in
    if Ascii.eqb c newline_char then 
      cs 
    else 
      let/d result := end_line cs in
      result
  end.
Theorem end_line_equation: ltac2:(unfold_fix_type '@end_line).
Proof. unfold_fix_proof '@end_line. Qed.

Definition q_from_nat (n: nat) (arg: N) :=
  match n with
  | 0%nat =>
    let/d res := NUM arg in
    res
  | _ =>
    let/d res := QUOTE arg in
    res
  end.

Fixpoint lex (q: nat) (cs: list ascii) (acc: list token) (fuel: nat): option (list token) :=
  match cs with
  | [] => 
    let/d result := Some acc in
    result
  | c :: cs =>
    match fuel with
    | 0%nat => 
      let/d result := None in
      result
    | S fuel =>
      if Ascii.eqb c " "%char then
        let/d result := lex 0 cs acc fuel in
        result
      else if Ascii.eqb c "009"%char then
        let/d result := lex 0 cs acc fuel in
        result
      else if Ascii.eqb c "010"%char then
        let/d result := lex 0 cs acc fuel in
        result
      else if Ascii.eqb c "#"%char then 
        let/d line_end := end_line cs in
        let/d result := lex 0 line_end acc fuel in
        result
      else if Ascii.eqb c "."%char then 
        let/d dot_token := DOT in
        let/d new_acc := dot_token :: acc in
        let/d result := lex 0 cs new_acc fuel in
        result
      else if Ascii.eqb c "("%char then 
        let/d open_token := OPEN in
        let/d new_acc := open_token :: acc in
        let/d result := lex 0 cs new_acc fuel in
        result
      else if Ascii.eqb c ")"%char then 
        let/d close_token := CLOSE in
        let/d new_acc := close_token :: acc in
        let/d result := lex 0 cs new_acc fuel in
        result
      else if Ascii.eqb c "'"%char then 
        let/d result := lex 1 cs acc fuel in
        result
      else
        let/d zero_char := "0"%char in
        let/d nine_char := "9"%char in
        let/d zero_ascii := N_of_ascii zero_char in
        let/d c_cons_cs := c :: cs in
        let/d digit_result := read_num zero_char nine_char 10 zero_ascii 0 c_cons_cs in
        match digit_result return (option (list token)) with
        | (n, rest) =>
          let/d rest_length := list_length rest in
          let/d original_length := list_length c_cons_cs in
          if Nat.eqb rest_length original_length then
            let/d star_char := "*"%char in
            let/d z_char := "z"%char in
            let/d alpha_result := read_num star_char z_char 256 0 0 c_cons_cs in
            match alpha_result return (option (list token)) with
            | (n2, rest2) =>
              let/d rest2_length := list_length rest2 in
              let/d original_length2 := list_length c_cons_cs in
              if Nat.eqb rest2_length original_length2 then
                let/d result := lex 0 cs acc fuel in
                result
              else
                let/d q_token2 := q_from_nat q n2 in
                let/d new_acc2 := q_token2 :: acc in
                let/d result := lex 0 rest2 new_acc2 fuel in
                result
            end
          else
            let/d q_token := q_from_nat q n in
            let/d new_acc := q_token :: acc in
            let/d result := lex 0 rest new_acc fuel in
            result
        end
    end
  end.
Theorem lex_equation: ltac2:(unfold_fix_type '@lex).
Proof. unfold_fix_proof '@lex. Qed.

Definition lexer_i (input: list ascii): option (list token) :=
  let/d len := list_length input in
  let/d empty_list := [] in
  lex 0 input empty_list len.

Definition lexer (input: list ascii): list token :=
  match lexer_i input with
  | None =>
    let/d res := [] in
    res
  | Some ts => ts
  end.

(* parsing *)

Definition quote (n: N) :=
  let/d quote_enc := name_enc "'" in
  let/d quote_num := Num quote_enc in
  let/d n_num := Num n in
  let/d pair_list := [quote_num; n_num] in
  let/d result := FunValues.vlist pair_list in
  result.

Fixpoint parse (ts: list token) (x: Value) (stck: list Value) :=
  match ts with
  | [] => x
  | (CLOSE :: rest) => 
    let/d zero_num := Num 0 in
    let/d x_cons_s := x :: stck in
    let/d result := parse rest zero_num x_cons_s in
    result
  | (OPEN :: rest) =>
    match stck with
    | [] => 
      let/d result := parse rest x stck in
      result
    | (y :: ys) => 
      let/d pair_x_y := Pair x y in
      let/d result := parse rest pair_x_y ys in
      result
    end
  | (NUM n :: rest) => 
    let/d n_num := Num n in
    let/d pair_n_x := Pair n_num x in
    let/d result := parse rest pair_n_x stck in
    result
  | (QUOTE n :: rest) => 
    let/d quote_n := quote n in
    let/d pair_quote_x := Pair quote_n x in
    let/d result := parse rest pair_quote_x stck in
    result
  | (DOT :: rest) => 
    let/d vhead_x := FunValues.vhead x in
    let/d result := parse rest vhead_x stck in
    result
  end.
Theorem parse_equation: ltac2:(unfold_fix_type '@parse).
Proof. unfold_fix_proof '@parse. Qed.

(* converting from v to prog *)

Fixpoint v2list (v: FunValues.Value) :=
  match v with
  | Num _ => 
    let/d empty_list := [] in
    empty_list
  | Pair v1 v2 =>
    let/d v2_list := v2list v2 in
    let/d result := v1 :: v2_list in
    result
  end.
Theorem v2list_equation: ltac2:(unfold_fix_type '@v2list).
Proof. unfold_fix_proof '@v2list. Qed.

Definition num2exp (n: N) :=
  let/d is_upper := vis_upper n in
  if is_upper then
    let/d n1 := N_modulo n (2 ^ 64 - 1) in
    let/d word_val := word.of_Z (Z.of_N n1) in
    let/d result := ImpSyntax.Const word_val in
    result
  else 
    let/d result := Var n in
    result.

Fixpoint v2exp (v: Value): ImpSyntax.exp :=
  match v with
  | Num n => 
    let/d result := num2exp n in
    result
  | Pair v0 v1 =>
    let/d n := vgetNum v0 in (* this can fail? *)
    match v1 return ImpSyntax.exp with
    | Num _ => 
      let/d result := num2exp n in (* fail? *)
      result
    | Pair v1 v2 =>
      if N.eqb n (name_enc "'") then 
        let/d v1_num := vgetNum v1 in
        let/d v1_num_mod := N_modulo v1_num (2 ^ 64 - 1) in
        let/d word_val := word.of_Z (Z.of_N v1_num_mod) in
        let/d result := Const word_val in
        result
      else if N.eqb n (name_enc "var") then 
        let/d v1_num := vgetNum v1 in
        let/d result := Var v1_num in
        result
      else
        match v2 with
        | Num _ => 
          let/d result := num2exp n in (* fail? *)
          result
        | Pair v2 v3 =>
          if N.eqb n (name_enc "+") then 
            let/d v1_exp := v2exp v1 in
            let/d v2_exp := v2exp v2 in
            let/d result := Add v1_exp v2_exp in
            result
          else if N.eqb n (name_enc "-") then 
            let/d v1_exp := v2exp v1 in
            let/d v2_exp := v2exp v2 in
            let/d result := Sub v1_exp v2_exp in
            result
          else if N.eqb n (name_enc "div") then 
            let/d v1_exp := v2exp v1 in
            let/d v2_exp := v2exp v2 in
            let/d result := Div v1_exp v2_exp in
            result
          else if N.eqb n (name_enc "read") then 
            let/d v1_exp := v2exp v1 in
            let/d v2_exp := v2exp v2 in
            let/d result := Read v1_exp v2_exp in
            result
          else
            let/d vel0_v := vel0 v in
            let/d vel0_num := vgetNum vel0_v in
            let/d result := Var vel0_num in (* fail? *)
            result
        end
    end
  end.
Theorem v2exp_equation: ltac2:(unfold_fix_type '@v2exp).
Proof. unfold_fix_proof '@v2exp. Qed.

Fixpoint vs2exps (v: list Value): list ImpSyntax.exp :=
  match v with
  | [] => 
    let/d empty_list := [] in
    empty_list
  | v1 :: vs =>
    let/d v1_exp := v2exp v1 in
    let/d vs_exps := vs2exps vs in
    let/d result := v1_exp :: vs_exps in
    result
  end.
Theorem vs2exps_equation: ltac2:(unfold_fix_type '@vs2exps).
Proof. unfold_fix_proof '@vs2exps. Qed.

Definition v2cmp (v: Value): ImpSyntax.cmp :=
  let/d v_num := vgetNum v in
  if N.eqb v_num (name_enc "<") then 
    let/d res := Less in
    res 
  else if N.eqb v_num (name_enc "=") then 
    let/d res := Equal in
    res
  else
    let/d res := Less in
    res. (* fail? *)

Fixpoint v2test (v: Value): ImpSyntax.test :=
  match v with
  | Num _ => 
    let/d zero_word := word.of_Z (Z.of_N 0) in
    let/d zero_const := Const zero_word in
    let/d less := Less in
    let/d result := Test less zero_const zero_const in (* fail? *)
    result
  | Pair v0 v1 =>
    let/d n := vgetNum v0 in (* this can fail? *)
    match v1 return ImpSyntax.test with
    | Num _ => 
      let/d zero_word := word.of_Z (Z.of_N 0) in
      let/d zero_const := Const zero_word in
      let/d less := Less in
      let/d result := Test less zero_const zero_const in (* fail? *)
      result
    | Pair v1 v2 =>
      if N.eqb n (name_enc "not") then 
        let/d v1_test := v2test v1 in
        let/d result := Not v1_test in
        result
      else
        match v2 with
        | Num _ => 
          let/d zero_word := word.of_Z (Z.of_N 0) in
          let/d zero_const := Const zero_word in
          let/d less := Less in
          let/d result := Test less zero_const zero_const in (* fail? *)
          result
        | Pair v2 v3 =>
          if N.eqb n (name_enc "and") then 
            let/d v1_test := v2test v1 in
            let/d v2_test := v2test v2 in
            let/d result := And v1_test v2_test in
            result
          else if N.eqb n (name_enc "or") then 
            let/d v1_test := v2test v1 in
            let/d v2_test := v2test v2 in
            let/d result := Or v1_test v2_test in
            result
          else
            let/d v0_cmp := v2cmp v0 in
            let/d v1_exp := v2exp v1 in
            let/d v2_exp := v2exp v2 in
            let/d result := Test v0_cmp v1_exp v2_exp in
            result
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
        let/d result := v2cmd v0 in
        result
      else
        let/d v0_cmd := v2cmd v0 in
        let/d v1_cmd := v2cmd v1 in
        let/d result := Seq v0_cmd v1_cmd in
        result
    else
      let/d n := vgetNum v0 in
      if N.eqb n (name_enc "abort") then
        Abort
      else
        match v1 with
        | Num _ => (* fail? *)
          let/d res := Skip in
          res
        | Pair v1 v2 =>
          if N.eqb n (name_enc "return") then
            let/d v1_exp := v2exp v1 in
            let/d result := Return v1_exp in
            result
          else if N.eqb n (name_enc "getchar") then
            let/d v1_num := vgetNum v1 in
            let/d result := GetChar v1_num in
            result
          else if N.eqb n (name_enc "putchar") then
            let/d v1_exp := v2exp v1 in
            let/d result := PutChar v1_exp in
            result
          else
            match v2 with
            | Num n2 => (* fail? *)
              let/d res := Skip in
              res
            | Pair v2 v3 =>
              if N.eqb n (name_enc "assign") then
                let/d v1_num := vgetNum v1 in
                let/d v2_exp := v2exp v2 in
                let/d result := Assign v1_num v2_exp in
                result
              else if N.eqb n (name_enc "while") then
                let/d v1_test := v2test v1 in
                let/d v2_cmd := v2cmd v2 in
                let/d result := While v1_test v2_cmd in
                result
              else if N.eqb n (name_enc "alloc") then
                let/d v1_num := vgetNum v1 in
                let/d v2_exp := v2exp v2 in
                let/d result := Alloc v1_num v2_exp in
                result
              else
                match v3 with
                | Num _ =>
                  let/d v0_num := vgetNum v0 in
                  let/d v1_num := vgetNum v1 in
                  let/d v2_list := v2list v2 in
                  let/d v2_exps := vs2exps v2_list in
                  let/d result := Call v0_num v1_num v2_exps in
                  result
                | Pair v3 v4 =>
                  if N.eqb n (name_enc "update") then
                    let/d v1_exp := v2exp v1 in
                    let/d v2_exp := v2exp v2 in
                    let/d v3_exp := v2exp v3 in
                    let/d result := Update v1_exp v2_exp v3_exp in
                    result
                  else if N.eqb n (name_enc "if") then
                    let/d v1_test := v2test v1 in
                    let/d v2_cmd := v2cmd v2 in
                    let/d v3_cmd := v2cmd v3 in
                    let/d result := If v1_test v2_cmd v3_cmd in
                    result
                  else if N.eqb n (name_enc "call") then
                    let/d v1_num := vgetNum v1 in
                    let/d v2_num := vgetNum v2 in
                    let/d v3_list := v2list v3 in
                    let/d v3_exps := vs2exps v3_list in
                    let/d result := Call v1_num v2_num v3_exps in
                    result
                  else
                    let/d v0_num := vgetNum v0 in
                    let/d v1_num := vgetNum v1 in
                    let/d v2_v3_pair := Pair v2 v3 in
                    let/d pair_list := v2list v2_v3_pair in
                    let/d pair_exps := vs2exps pair_list in
                    let/d result := Call v0_num v1_num pair_exps in
                    result
                end
            end
        end
  end.
Theorem v2cmd_equation: ltac2:(unfold_fix_type '@v2cmd).
Proof. unfold_fix_proof '@v2cmd. Qed.

Fixpoint vs2args (vs: list Value) :=
  match vs with
  | [] => 
    let/d empty_list := [] in
    empty_list
  | v :: vs =>
    let/d v_num := vgetNum v in
    let/d vs_args := vs2args vs in
    let/d result := v_num :: vs_args in
    result
  end.
Theorem vs2args_equation: ltac2:(unfold_fix_type '@vs2args).
Proof. unfold_fix_proof '@vs2args. Qed.

Definition v2func (v: Value) :=
  let/d vel1_v := vel1 v in
  let/d func_name := vgetNum vel1_v in
  let/d vel2_v := vel2 v in
  let/d vel2_list := v2list vel2_v in
  let/d args := vs2args vel2_list in
  let/d vel3_v := vel3 v in
  let/d body := v2cmd vel3_v in
  let/d result := ImpSyntax.Func func_name args body in
  result.

Fixpoint v2funcs (vs: list Value) :=
  match vs with
  | [] => 
    let/d empty_list := [] in
    empty_list
  | v :: vs =>
    let/d v_func := v2func v in
    let/d vs_funcs := v2funcs vs in
    let/d result := v_func :: vs_funcs in
    result
  end.
Theorem v2funcs_equation: ltac2:(unfold_fix_type '@v2funcs).
Proof. unfold_fix_proof '@v2funcs. Qed.

Definition vs2prog (vs: list Value) :=
  let/d ds := v2funcs vs in
  let/d result := ImpSyntax.Program ds in
  result.

(* entire parser *)

Definition parser (tokens: list token): prog :=
  let/d zero_num := Num 0 in
  let/d empty_stack := [] in
  let/d parsed_val := parse tokens zero_num empty_stack in
  let/d val_list := v2list parsed_val in
  let/d result := vs2prog val_list in
  result.

Definition str2imp (str: list ascii): ImpSyntax.prog :=
  let/d toks := lexer str in
  let/d prog := parser toks in
  let/d result := prog in
  result.
