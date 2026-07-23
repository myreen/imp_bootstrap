Theory imp_parsing
Ancestors
  arithmetic list pair finite_map string words
  source_values imp_source_syntax
Libs
  BasicProvers

(* Lexer and parser for imperative (IMP) programs.
   Direct port of coq/theories/parsing/Parser.v (+ ParserData.v).
   The concrete syntax is s-expressions; values (source_values$v) are
   used as the intermediate tree, exactly as in the Rocq development. *)


(* ------------------------------------------------------------------ *)
(* Tokens (coq: parsing/ParserData.v)                                 *)
(* ------------------------------------------------------------------ *)

Datatype:
  token = OPEN | CLOSE | DOT | NUM num | QUOTE num
End


(* ------------------------------------------------------------------ *)
(* Lexing (coq: read_nmc / read_alp / end_line / lex / lexer)         *)
(* read_num generalises read_nmc ("0".."9", base 10) and              *)
(* read_alp ("*".."z", base 256) into a single reader.                *)
(* ------------------------------------------------------------------ *)

Definition read_num_def:
  read_num l h f x acc [] = (acc,[]) ∧
  read_num l h f x acc (c::cs) =
    if ORD l ≤ ORD c ∧ ORD c ≤ ORD h then
      read_num l h f x (f * acc + (ORD c - x)) cs
    else (acc,c::cs)
End

Theorem read_num_length:
  ∀l h xs n ys f acc x.
    read_num l h f x acc xs = (n,ys) ⇒
    LENGTH ys ≤ LENGTH xs ∧ (xs ≠ ys ⇒ LENGTH ys < LENGTH xs)
Proof
  Induct_on ‘xs’ \\ rw [read_num_def]
  \\ TRY pairarg_tac \\ fs [] \\ rw [] \\ res_tac \\ fs []
QED

Definition end_line_def:
  end_line [] = [] ∧
  end_line (c::cs) = if c = #"\n" then cs else end_line cs
End

Theorem end_line_length:
  ∀cs. STRLEN (end_line cs) < SUC (STRLEN cs)
Proof
  Induct \\ rw [end_line_def]
QED

Definition lex_def:
  lex q [] acc = acc ∧
  lex q (c::cs) acc =
      if MEM c " \t\n" then lex NUM cs acc else
      if c = #"#" then lex NUM (end_line cs) acc else
      if c = #"." then lex NUM cs (DOT::acc) else
      if c = #"(" then lex NUM cs (OPEN::acc) else
      if c = #")" then lex NUM cs (CLOSE::acc) else
      if c = #"'" then lex QUOTE cs acc else
        let (n,rest) = read_num #"0" #"9" 10 (ORD #"0") 0 (c::cs) in
          if rest ≠ c::cs then lex NUM rest (q n::acc) else
            let (n,rest) = read_num #"*" #"z" 256 0 0 (c::cs) in
              if rest ≠ c::cs then lex NUM rest (q n::acc) else
                lex NUM cs acc
Termination
  WF_REL_TAC ‘measure (LENGTH o FST o SND)’ \\ rw []
  \\ imp_res_tac (GSYM read_num_length) \\ fs [end_line_length]
End

Definition lexer_def:
  lexer input = lex NUM input []
End


(* ------------------------------------------------------------------ *)
(* Parsing tokens into a value tree (coq: quote / parse)              *)
(* ------------------------------------------------------------------ *)

Definition quote_def:
  quote n = list [Num (name "'"); Num n]
End

Definition parse_def:
  parse [] x s = x ∧
  parse (CLOSE :: rest) x s = parse rest (Num 0) (x::s) ∧
  parse (OPEN :: rest) x s =
    (case s of [] => parse rest x s
     | (y::ys) => parse rest (Pair x y) ys) ∧
  parse (NUM n :: rest) x s = parse rest (Pair (Num n) x) s ∧
  parse (QUOTE n :: rest) x s = parse rest (Pair (quote n) x) s ∧
  parse (DOT :: rest) x s = parse rest (head x) s
End


(* ------------------------------------------------------------------ *)
(* Converting a value tree into IMP abstract syntax                    *)
(* (coq: v2list / num2exp / v2exp / vs2exps / v2cmp / v2test /         *)
(*        v2cmd / vs2args / v2func / v2funcs / vs2prog)                *)
(* ------------------------------------------------------------------ *)

Definition v2list_def:
  v2list v = if isNum v then [] else head v :: v2list (tail v)
Termination
  WF_REL_TAC ‘measure v_size’ \\ Cases \\ fs []
End

Definition num2exp_def:
  num2exp n =
    if is_upper n then
      (if 18446744073709551615 < n then Const 0w else Const (n2w n))
    else Var n
End

Definition v2exp_def:
  v2exp v =
    case v of
    | Num n => num2exp n
    | Pair v0 (Num _) => num2exp (getNum v0)
    | Pair v0 (Pair v1 v2) =>
        let n = getNum v0 in
          if n = name "'" then
            (if 18446744073709551615 < getNum v1 then Const 0w
             else Const (n2w (getNum v1)))
          else if n = name "var" then Var (getNum v1)
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
    let n = getNum v in
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
        let n = getNum v0 in
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
        if ~isNum v0 then
          (if isNum v1 then v2cmd v0
           else Seq (v2cmd v0) (v2cmd v1))
        else
          let n = getNum v0 in
          if n = name "abort" then Abort
          else case v1 of
          | Num _ => Skip
          | Pair v1 v2 =>
              if n = name "return" then Return (v2exp v1)
              else if n = name "getchar" then GetChar (getNum v1)
              else if n = name "putchar" then PutChar (v2exp v1)
              else case v2 of
              | Num _ => Skip
              | Pair v2 v3 =>
                  if n = name "assign" then
                    Assign (getNum v1) (v2exp v2)
                  else if n = name "while" then
                    While (v2test v1) (v2cmd v2)
                  else if n = name "alloc" then
                    Alloc (getNum v1) (v2exp v2)
                  else case v3 of
                  | Num _ =>
                      Call (getNum v0) (getNum v1) (vs2exps (v2list v2))
                  | Pair v3 v4 =>
                      if n = name "update" then
                        Update (v2exp v1) (v2exp v2) (v2exp v3)
                      else if n = name "if" then
                        If (v2test v1) (v2cmd v2) (v2cmd v3)
                      else if n = name "call" then
                        Call (getNum v1) (getNum v2) (vs2exps (v2list v3))
                      else
                        Call (getNum v0) (getNum v1)
                             (vs2exps (v2list (Pair v2 v3)))
Termination
  WF_REL_TAC ‘measure v_size’ \\ simp [v_size_def]
End

Definition vs2args_def:
  vs2args [] = [] ∧
  vs2args (v::vs) = getNum v :: vs2args vs
End

Definition v2func_def:
  v2func v =
    let fname = getNum (el1 v) in
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
