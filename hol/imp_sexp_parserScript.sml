Theory imp_sexp_parser
Ancestors
  arithmetic list pair finite_map string words
  imp_source_syntax source_values parsing

(* IMP s-expression parser.
   Reuses the token type and lexer/parse functions from the functional
   language parser (Theory parsing).  Defines IMP-specific converters
   from Value trees to ImpSyntax AST nodes. *)


(* ------------------------------------------------------------------ *)
(* num2exp: treat uppercase-starting names as numeric constants,       *)
(*          others as variable names                                   *)
(* ------------------------------------------------------------------ *)

Definition imp_num2exp_def:
  imp_num2exp n = if is_upper n then Const (n2w n) else Var n
End

(* ------------------------------------------------------------------ *)
(* v2exp: convert a Value to an ImpSyntax expression                  *)
(* ------------------------------------------------------------------ *)

Definition imp_v2exp_def:
  imp_v2exp v =
    case v of
    | Num n => imp_num2exp n
    | Pair v0 (Num _) => imp_num2exp (getNum v0)
    | Pair v0 (Pair v1 v2) =>
        let n = getNum v0 in
          if n = name "'" then Const (n2w (getNum v1))
          else if n = name "var" then Var (getNum v1)
          else case v2 of
               | Num _ => imp_num2exp n
               | Pair v2 v3 =>
                   if n = name "+" then Add (imp_v2exp v1) (imp_v2exp v2)
                   else if n = name "-" then Sub (imp_v2exp v1) (imp_v2exp v2)
                   else if n = name "div" then Div (imp_v2exp v1) (imp_v2exp v2)
                   else if n = name "read" then Read (imp_v2exp v1) (imp_v2exp v2)
                   else imp_num2exp n
Termination
  WF_REL_TAC ‘measure v_size’ \\ simp [v_size_def]
End

(* ------------------------------------------------------------------ *)
(* v2cmp / v2test: convert a Value to an ImpSyntax comparison / test  *)
(* ------------------------------------------------------------------ *)

Definition imp_v2cmp_def:
  imp_v2cmp v = if getNum v = name "<" then imp_source_syntax$Less else Equal
End

Definition imp_v2test_def:
  imp_v2test v =
    case v of
    | Num _ => Test Less (Const 0w) (Const 0w)
    | Pair v0 (Num _) => Test Less (Const 0w) (Const 0w)
    | Pair v0 (Pair v1 v2) =>
        let n = getNum v0 in
          if n = name "not" then Not (imp_v2test v1)
          else case v2 of
               | Num _ => Test Less (Const 0w) (Const 0w)
               | Pair v2 v3 =>
                   if n = name "and" then And (imp_v2test v1) (imp_v2test v2)
                   else if n = name "or" then Or (imp_v2test v1) (imp_v2test v2)
                   else Test (imp_v2cmp v0) (imp_v2exp v1) (imp_v2exp v2)
Termination
  WF_REL_TAC ‘measure v_size’ \\ simp [v_size_def]
End

(* ------------------------------------------------------------------ *)
(* v2cmd: convert a Value to an ImpSyntax command                     *)
(* ------------------------------------------------------------------ *)

Definition imp_v2cmd_def:
  imp_v2cmd v =
    case v of
    | Num _ => Skip
    | Pair v0 v1 =>
        if ~isNum v0 then
          (* v0 is itself a Pair => sequence of commands *)
          if isNum v1 then imp_v2cmd v0
          else Seq (imp_v2cmd v0) (imp_v2cmd v1)
        else
          let n = getNum v0 in
          if n = name "abort" then Abort
          else case v1 of
          | Num _ => Skip
          | Pair v1 v2 =>
              if n = name "return"  then Return (imp_v2exp v1)
              else if n = name "getchar" then GetChar (getNum v1)
              else if n = name "putchar" then PutChar (imp_v2exp v1)
              else case v2 of
              | Num _ => Skip
              | Pair v2 v3 =>
                  if n = name "assign" then
                    Assign (getNum v1) (imp_v2exp v2)
                  else if n = name "while" then
                    While (imp_v2test v1) (imp_v2cmd v2)
                  else if n = name "alloc" then
                    Alloc (getNum v1) (imp_v2exp v2)
                  else case v3 of
                  | Num _ =>
                      Call (getNum v0) (getNum v1)
                           (MAP imp_v2exp (v2list v2))
                  | Pair v3 v4 =>
                      if n = name "update" then
                        Update (imp_v2exp v1) (imp_v2exp v2) (imp_v2exp v3)
                      else if n = name "if" then
                        If (imp_v2test v1) (imp_v2cmd v2) (imp_v2cmd v3)
                      else if n = name "call" then
                        Call (getNum v1) (getNum v2)
                             (MAP imp_v2exp (v2list v3))
                      else
                        Call (getNum v0) (getNum v1)
                             (MAP imp_v2exp (v2list (Pair v2 v3)))
Termination
  WF_REL_TAC ‘measure v_size’ \\ simp [v_size_def]
End

(* ------------------------------------------------------------------ *)
(* v2func / v2funcs / vs2prog: build ImpSyntax function/program       *)
(* ------------------------------------------------------------------ *)

Definition imp_v2func_def:
  imp_v2func v =
    let fname  = getNum (el1 v) in
    let args   = MAP getNum (v2list (el2 v)) in
    let body   = imp_v2cmd (el3 v) in
      Func fname args body
End

Definition imp_v2funcs_def:
  imp_v2funcs []      = [] ∧
  imp_v2funcs (v::vs) = imp_v2func v :: imp_v2funcs vs
End

Definition imp_vs2prog_def:
  imp_vs2prog vs = Program (imp_v2funcs vs)
End

(* ------------------------------------------------------------------ *)
(* Top-level parser and str2imp                                        *)
(* ------------------------------------------------------------------ *)

Definition imp_parser_def:
  imp_parser tokens =
    imp_vs2prog (v2list (parse tokens (Num 0) []))
End

Definition str2imp_def:
  str2imp str = imp_parser (lexer str)
End
