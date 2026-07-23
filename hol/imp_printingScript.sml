Theory imp_printing
Ancestors
  arithmetic list pair finite_map string words
  imp_source_syntax printing

(* Pretty printer for imperative (IMP) programs.
   Direct port of coq/theories/imperative/Printing.v.
   Prints an IMP program as s-expression concrete syntax.
   (ascii_name / name2str / num2str are reused from Theory printing.) *)


(* ------------------------------------------------------------------ *)
(* S-expression intermediate representation                            *)
(* ------------------------------------------------------------------ *)

Datatype:
  sexpr = SNum num
        | SStr (char list)
        | SBlock sexpr
        | SPair sexpr sexpr
        | SEmpty
End

Definition unary_sexpr_def:
  unary_sexpr op v = SBlock (SPair (SStr op) v)
End

Definition binary_sexpr_def:
  binary_sexpr op v1 v2 = SBlock (SPair (SStr op) (SPair v1 v2))
End

Definition ternary_sexpr_def:
  ternary_sexpr op v1 v2 v3 =
    SBlock (SPair (SStr op) (SPair (SPair v1 v2) v3))
End

Definition quaternary_sexpr_def:
  quaternary_sexpr op v1 v2 v3 v4 =
    SBlock (SPair (SStr op) (SPair (SPair (SPair v1 v2) v3) v4))
End

Definition name_sexpr_def:
  name_sexpr n = SStr (name2str n)
End


(* ------------------------------------------------------------------ *)
(* Expressions                                                         *)
(* ------------------------------------------------------------------ *)

Definition exp2s_def:
  exp2s (Var n)      = unary_sexpr "var" (name_sexpr n) ∧
  exp2s (Const w)    = SNum (w2n w) ∧
  exp2s (Add e1 e2)  = binary_sexpr "+" (exp2s e1) (exp2s e2) ∧
  exp2s (Sub e1 e2)  = binary_sexpr "-" (exp2s e1) (exp2s e2) ∧
  exp2s (Div e1 e2)  = binary_sexpr "div" (exp2s e1) (exp2s e2) ∧
  exp2s (Read e1 e2) = binary_sexpr "read" (exp2s e1) (exp2s e2)
End

Definition exps2s_imp_def:
  exps2s_imp []      = SEmpty ∧
  exps2s_imp (e::es) = SPair (exp2s e) (exps2s_imp es)
End

Definition exps2s_def:
  exps2s es = SBlock (exps2s_imp es)
End


(* ------------------------------------------------------------------ *)
(* Comparisons and tests                                              *)
(* ------------------------------------------------------------------ *)

Definition cmp2str_def:
  cmp2str imp_source_syntax$Less  = "<" ∧
  cmp2str Equal = "="
End

Definition test2s_def:
  test2s (Test c e1 e2) = binary_sexpr (cmp2str c) (exp2s e1) (exp2s e2) ∧
  test2s (And t1 t2)    = binary_sexpr "and" (test2s t1) (test2s t2) ∧
  test2s (Or t1 t2)     = binary_sexpr "or" (test2s t1) (test2s t2) ∧
  test2s (Not t)        = unary_sexpr "not" (test2s t)
End


(* ------------------------------------------------------------------ *)
(* Parameter name lists                                               *)
(* ------------------------------------------------------------------ *)

Definition names2s_imp_def:
  names2s_imp []      = SEmpty ∧
  names2s_imp (n::ns) = SPair (name_sexpr n) (names2s_imp ns)
End

Definition names2s_def:
  names2s ns = SBlock (names2s_imp ns)
End


(* ------------------------------------------------------------------ *)
(* Commands                                                           *)
(* ------------------------------------------------------------------ *)

Definition cmd2s_def:
  cmd2s Skip            = SStr "skip" ∧
  cmd2s (Seq c1 c2)     = SBlock (SPair (cmd2s c1) (cmd2s c2)) ∧
  cmd2s (Assign n e)    = binary_sexpr "assign" (name_sexpr n) (exp2s e) ∧
  cmd2s (Update a e e') =
    ternary_sexpr "update" (exp2s a) (exp2s e) (exp2s e') ∧
  cmd2s (If t c1 c2)    =
    ternary_sexpr "if" (test2s t) (cmd2s c1) (cmd2s c2) ∧
  cmd2s (While t c)     = binary_sexpr "while" (test2s t) (cmd2s c) ∧
  cmd2s (Call n f es)   =
    ternary_sexpr "call" (name_sexpr n) (name_sexpr f) (exps2s es) ∧
  cmd2s (Return e)      = unary_sexpr "return" (exp2s e) ∧
  cmd2s (Alloc n e)     = binary_sexpr "alloc" (name_sexpr n) (exp2s e) ∧
  cmd2s (GetChar n)     = unary_sexpr "getchar" (name_sexpr n) ∧
  cmd2s (PutChar e)     = unary_sexpr "putchar" (exp2s e) ∧
  cmd2s Abort           = SBlock (SStr "abort")
End


(* ------------------------------------------------------------------ *)
(* Functions and programs                                             *)
(* ------------------------------------------------------------------ *)

Definition func2s_def:
  func2s (Func n params body) =
    ternary_sexpr "defun" (name_sexpr n) (names2s params)
      (SBlock (cmd2s body))
End

Definition funcs2s_imp_def:
  funcs2s_imp []      = SEmpty ∧
  funcs2s_imp (f::fs) = SPair (func2s f) (funcs2s_imp fs)
End

Definition prog2s_def:
  prog2s (Program funcs) = funcs2s_imp funcs
End


(* ------------------------------------------------------------------ *)
(* Flattening an s-expression to a string via an append list          *)
(* ------------------------------------------------------------------ *)

Datatype:
  str_app_list = StrList (char list)
               | StrAppend str_app_list str_app_list
End

Definition sexpr2str_def:
  sexpr2str (SNum n)      = StrAppend (StrList "'") (StrList (num2str n)) ∧
  sexpr2str (SStr s)      = StrList s ∧
  sexpr2str (SPair s1 s2) =
    StrAppend (sexpr2str s1) (StrAppend (StrList " ") (sexpr2str s2)) ∧
  sexpr2str SEmpty        = StrList "" ∧
  sexpr2str (SBlock s)    =
    StrAppend (StrList "(") (StrAppend (sexpr2str s) (StrList ")"))
End

Definition flatten_str_app_list_def:
  flatten_str_app_list (StrList s)       = s ∧
  flatten_str_app_list (StrAppend s1 s2) =
    flatten_str_app_list s1 ++ flatten_str_app_list s2
End


(* ------------------------------------------------------------------ *)
(* Top-level: IMP program to string                                   *)
(* ------------------------------------------------------------------ *)

Definition imp2str_def:
  imp2str p = flatten_str_app_list (sexpr2str (prog2s p))
End
