Theory imp_parsing
Ancestors
  arithmetic list pair finite_map string words
  source_values imp_source_syntax
  parsing (* lexing, parrsing *)
Libs
  BasicProvers


(* ------------------------------------------------------------------ *)
(* Converting a value tree into IMP abstract syntax                    *)
(* (coq: v2list / num2exp / v2exp / vs2exps / v2cmp / v2test /         *)
(*        v2cmd / vs2args / v2func / v2funcs / vs2prog)                *)
(* ------------------------------------------------------------------ *)

Definition get_num_def:
  get_num v = getNum v
End

Definition v2list_def:
  v2list v = if isNum v then [] else head v :: v2list (tail v)
Termination
  WF_REL_TAC ‘measure v_size’ \\ Cases \\ fs []
End

Definition num2exp_def:
  num2exp n =
    let b = is_upper n in
      if b then
        (if 18446744073709551615 < n then Const 0w else Const (n2w n))
      else Var n
End

Definition v2exp_def:
  v2exp v =
    case v of
    | Num n => num2exp n
    | Pair v0 (Num _) => num2exp (get_num v0)
    | Pair v0 (Pair v1 v2) =>
        let n = get_num v0 in
          if n = name "'" then
            (if 18446744073709551615 < get_num v1 then Const 0w
             else Const (n2w (get_num v1)))
          else if n = name "var" then Var (get_num v1)
          else case v2 of
               | Num _ => num2exp n
               | Pair v2 v3 =>
                   if n = name "+" then Add (v2exp v1) (v2exp v2)
                   else if n = name "-" then Sub (v2exp v1) (v2exp v2)
                   else if n = name "div" then Div (v2exp v1) (v2exp v2)
                   else if n = name "read" then Read (v2exp v1) (v2exp v2)
                   else num2exp n
Termination
  WF_REL_TAC ‘measure v_size’ \\ simp [v_size_def]
End

Definition vs2exps_def:
  vs2exps [] = [] ∧
  vs2exps (v::vs) = v2exp v :: vs2exps vs
End

Definition v2cmp_def:
  v2cmp v =
    let n = get_num v in
      if n = name "<" then imp_source_syntax$Less
      else if n = name "=" then Equal
      else imp_source_syntax$Less
End

Definition v2test_def:
  v2test v =
    case v of
    | Num _ => Test imp_source_syntax$Less (Const 0w) (Const 0w)
    | Pair v0 (Num _) => Test imp_source_syntax$Less (Const 0w) (Const 0w)
    | Pair v0 (Pair v1 v2) =>
        let n = get_num v0 in
          if n = name "not" then Not (v2test v1)
          else case v2 of
               | Num _ => Test imp_source_syntax$Less (Const 0w) (Const 0w)
               | Pair v2 v3 =>
                   if n = name "and" then And (v2test v1) (v2test v2)
                   else if n = name "or" then Or (v2test v1) (v2test v2)
                   else Test (v2cmp v0) (v2exp v1) (v2exp v2)
Termination
  WF_REL_TAC ‘measure v_size’ \\ simp [v_size_def]
End

Definition v2cmd_def:
  v2cmd v =
    case v of
    | Num _ => Skip
    | Pair v0 v1 =>
        if isNum v0 then
          let n = get_num v0 in
          if n = name "abort" then Abort
          else case v1 of
          | Num _ => Skip
          | Pair v1 v2 =>
              if n = name "return" then Return (v2exp v1)
              else if n = name "getchar" then GetChar (get_num v1)
              else if n = name "putchar" then PutChar (v2exp v1)
              else case v2 of
              | Num _ => Skip
              | Pair v2 v3 =>
                  if n = name "assign" then
                    Assign (get_num v1) (v2exp v2)
                  else if n = name "while" then
                    While (v2test v1) (v2cmd v2)
                  else if n = name "alloc" then
                    Alloc (get_num v1) (v2exp v2)
                  else case v3 of
                  | Num _ =>
                      Call (get_num v0) (get_num v1) (vs2exps (v2list v2))
                  | Pair v3 v4 =>
                      if n = name "update" then
                        Update (v2exp v1) (v2exp v2) (v2exp v3)
                      else if n = name "if" then
                        If (v2test v1) (v2cmd v2) (v2cmd v3)
                      else if n = name "call" then
                        Call (get_num v1) (get_num v2) (vs2exps (v2list v3))
                      else
                        Call (get_num v0) (get_num v1)
                             (vs2exps (v2list (Pair v2 v3)))
        else
          (if isNum v1 then v2cmd v0
           else Seq (v2cmd v0) (v2cmd v1))
Termination
  WF_REL_TAC ‘measure v_size’ \\ simp [v_size_def]
End

Definition vs2args_def:
  vs2args [] = [] ∧
  vs2args (v::vs) = get_num v :: vs2args vs
End

Definition v2func_def:
  v2func v =
    let fname = get_num (el1 v) in
    let args  = vs2args (v2list (el2 v)) in
    let body  = v2cmd (el3 v) in
      Func fname args body
End

Definition v2funcs_def:
  v2funcs []      = [] ∧
  v2funcs (v::vs) = v2func v :: v2funcs vs
End

Definition vs2prog_def:
  vs2prog vs = Program (v2funcs vs)
End


(* ------------------------------------------------------------------ *)
(* Entire parser (coq: parser / str2imp)                              *)
(* ------------------------------------------------------------------ *)

Definition parser_def:
  parser tokens = vs2prog (v2list (parse tokens (Num 0) []))
End

Definition str2imp_def:
  str2imp str = parser (lexer str)
End
