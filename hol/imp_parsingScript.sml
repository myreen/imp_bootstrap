
open HolKernel Parse boolLib bossLib;
open arithmeticTheory listTheory pairTheory finite_mapTheory stringTheory;
open source_valuesTheory wordsTheory imp_source_syntaxTheory;

val _ = new_theory "imp_parsing";

Datatype:
  keyword = If | While | Else | Return | Abort | Add | Sub | Div |
            Less | Equal | Or | And | Not | Alloc | GetChar | PutChar
End

Datatype:
  token = Ident num
        | Lit num
        | ParenOpen
        | ParenClose
        | BraceOpen
        | BraceClose
        | BracketOpen
        | BracketClose
        | Keyword keyword
        | Semicolon
        | Comma
End

Definition add_parens_def:
  add_parens xs = if LENGTH xs = 1 then xs else [ParenOpen] ++ xs ++ [ParenClose]
End

Definition e2t_def:
  e2t (Var n)      = [Ident n] ∧
  e2t (Const c)    = [Lit (w2n c)] ∧
  e2t (Add e1 e2)  = add_parens (e2t e1) ++ [Keyword Add] ++ add_parens (e2t e2) ∧
  e2t (Sub e1 e2)  = add_parens (e2t e1) ++ [Keyword Sub] ++ add_parens (e2t e2) ∧
  e2t (Div e1 e2)  = add_parens (e2t e1) ++ [Keyword Div] ++ add_parens (e2t e2) ∧
  e2t (Read e1 e2) = add_parens (e2t e1) ++ [BracketOpen] ++ e2t e2 ++ [BracketClose]
End

Definition find_end_def:
  find_end [] d acc = (REVERSE acc,[]) ∧
  find_end (x::xs) d acc =
    case x of
    | ParenClose => if d = 0 then (REVERSE acc, xs) else find_end xs (d-1) (x::acc)
    | ParenOpen => find_end xs (d+1) (x::acc)
    | _ => find_end xs d (x::acc)
End

Theorem find_end_length:
  ∀xs k acc ys zs.
    find_end xs k acc = (ys,zs) ⇒
    LENGTH ys + LENGTH zs ≤ LENGTH xs + LENGTH acc
Proof
  Induct \\ fs [find_end_def,AllCaseEqs()] \\ rw [] \\ res_tac \\ fs []
QED

Definition read_fst_def:
  read_fst xs =
    case xs of
    | (ParenOpen :: ys) => find_end ys 0 []
    | (Ident n :: ys) => ([Ident n],ys)
    | (Lit w :: ys) => ([Lit w],ys)
    | _ => ([],[])
End

Definition k2e_def:
  k2e Add e1 e2 = Add e1 e2 ∧
  k2e Sub e1 e2 = Sub e1 e2 ∧
  k2e Div e1 e2 = Div e1 e2 ∧
  k2e (k:keyword) e1 e2 = Add e1 e2
End

Definition front_def:
  front [] = [] ∧
  front (x::xs) = if NULL xs then [] else x :: front xs
End

Theorem LENGTH_front:
  ∀xs. LENGTH (front xs) = LENGTH xs - 1
Proof
  Induct \\ fs [front_def] \\ rw [] \\ Cases_on ‘xs’ \\ fs []
QED

Theorem front_snoc:
  ∀xs x. front (xs ++ [x]) = xs
Proof
  Induct \\ fs [front_def]
QED

Definition t2e_def:
  t2e xs =
    if LENGTH xs < 2 then
      (case xs of
       | (Ident n :: _) => Var n
       | (Lit n :: _) => Const (n2w n)
       | _ => Const 0w)
    else
      let (ys,zs) = read_fst xs in
      let e1 = t2e ys in
        case zs of
        | (BracketOpen::ts) => Read e1 (t2e (front ts))
        | (Keyword k::ts) => k2e k e1 (t2e ts)
        | _ => e1
Termination
  WF_REL_TAC ‘measure LENGTH’ \\ rw []
  \\ gvs [read_fst_def,AllCaseEqs()]
  \\ imp_res_tac find_end_length \\ fs [LENGTH_front]
End

Inductive balanced:
[~nil:]
  balanced []
[~single:]
  (∀x. x ≠ ParenOpen ∧ x ≠ ParenClose ⇒ balanced [x])
[~append:]
  (∀xs ys. balanced xs ∧ balanced ys ⇒ balanced (xs ++ ys))
[~paren:]
  (∀xs. balanced xs ⇒ balanced ([ParenOpen] ++ xs ++ [ParenClose]))
End

(* Theorem find_end_lemma:
  ∀xs ys d acc.
    balanced xs ⇒
    find_end (xs ++ ys) d acc = find_end ys d (REVERSE xs ++ acc)
Proof
  Induct_on ‘balanced’ \\ rw []
  >- (Cases_on ‘x’ \\ fs [find_end_def])
  >- asm_rewrite_tac [GSYM APPEND_ASSOC,REVERSE_APPEND]
  \\ simp [find_end_def] \\ asm_rewrite_tac [GSYM APPEND_ASSOC,REVERSE_APPEND,APPEND]
  \\ simp [find_end_def] \\ asm_rewrite_tac [GSYM APPEND_ASSOC,APPEND]
QED

Theorem balanced_add_parens:
  balanced xs ⇒ balanced (add_parens xs)
Proof
  rw [add_parens_def] \\ simp [Once balanced_cases]
QED

Theorem balanced_e2t:
  ∀e. balanced (e2t e)
Proof
  Induct \\ fs [e2t_def]
  >- simp [Once balanced_cases]
  >- simp [Once balanced_cases]
  \\ rpt $ irule_at Any balanced_append
  \\ rpt $ irule_at Any balanced_add_parens
  \\ simp [] \\ rpt $ simp [Once balanced_cases]
QED

Theorem read_fst_lemma:
  ∀e ys. read_fst (add_parens (e2t e) ++ ys) = (e2t e,ys)
Proof
  fs [read_fst_def] \\ rw [add_parens_def]
  >- (pop_assum mp_tac \\ Cases_on ‘e’ \\ fs [e2t_def]
      \\ simp [Once t2e_def] \\ rw [add_parens_def])
  \\ rewrite_tac [GSYM APPEND_ASSOC,APPEND]
  \\ qspec_then ‘e’ assume_tac balanced_e2t
  \\ drule find_end_lemma \\ fs [find_end_def]
QED

Theorem t2e_add_parens:
  t2e (add_parens (e2t e)) = t2e (e2t e)
Proof
  simp [Once t2e_def]
  \\ qspecl_then [‘e’,‘[]’] mp_tac read_fst_lemma \\ fs []
  \\ rw [] \\ fs [add_parens_def] \\ rw [] \\ fs []
  \\ pop_assum mp_tac \\ Cases_on ‘e’ \\ fs [e2t_def] \\ simp [Once t2e_def]
QED

Theorem t2e_e2t:
  ∀e. t2e (e2t e) = e
Proof
  Induct \\ simp [Once t2e_def,e2t_def]
  \\ ‘1 ≤ LENGTH (add_parens (e2t e))’ by rw [add_parens_def]
  \\ rewrite_tac [GSYM APPEND_ASSOC,APPEND]
  \\ simp [read_fst_lemma,k2e_def,front_snoc,t2e_add_parens]
QED

Definition test2t_def:
  test2t _ = ARB
End

Definition es2t_def:
  es2t sep [] = [ParenClose] ∧
  es2t sep (x::xs) = [sep] ++ e2t x ++ es2t Comma xs
End

Definition args2t_def:
  args2t xs = if NULL xs then [ParenOpen; ParenClose] else es2t ParenOpen xs
End

Definition c2t_def:
  c2t []            = [BraceClose] ∧
  c2t (x::y::ys)    = c2t [x] ++ c2t (y::ys) ∧
  c2t [Assign n e]  = [Ident n; Keyword Equal] ++ e2t e ++ [Semicolon] ∧
  c2t [Return e]    = [Keyword Return] ++ e2t e ++ [Semicolon] ∧
  c2t [Abort]       = [Keyword Abort; Semicolon] ∧
  c2t [PutChar e]   = [Keyword PutChar; ParenOpen] ++ e2t e ++ [ParenClose; Semicolon] ∧
  c2t [GetChar n]   = [Ident n; Keyword Equal; Keyword GetChar;
                       ParenOpen; ParenClose; Semicolon] ∧
  c2t [If t c1 c2]  = [Keyword If; ParenOpen] ++ test2t t ++ [ParenClose; BraceOpen] ++
                       c2t c1 ++ [Keyword Else; BraceOpen] ++ c2t c2 ∧
  c2t [While t c]   = [Keyword While; ParenOpen] ++ test2t t ++ [ParenClose; BraceOpen] ++
                       c2t c ∧
  (*    | Update exp exp exp              a[e] := e'              *)
  c2t [Call v n es] = [Ident v; Keyword Equal; Ident n] ++ args2t es ++ [Semicolon] ∧
  c2t [Alloc v e]   = [Ident v; Keyword Equal; Keyword Alloc] ++ e2t e ++ [Semicolon]
Termination
  WF_REL_TAC ‘measure $ list_size cmd_size’
End *)

(*

Definition rhs2c_def:
  rhs2c n xs =
    case xs of
    | [] => ([],xs)
    | (Keyword k :: ys) =>
         (case k of
          | Alloc => )

    |

Definition t2c_def:
  t2c (BraceClose::xs) acc = (REVERE acc,xs) ∧
  t2c (Keyword k::xs) acc =
    (case k of
     | If => ARB
     | While => ARB
     | Return => ARB
     | PutChar => ARB
     | (* Abort *) _ => (REVERSE (Abort::acc),xs)) ∧
  t2c (Ident n::xs) acc =
    (let (cs.ys) = rhs2c n (TL xs) acc in
       t2c ys (cs ++ acc))
  t2c _ acc = (REVERSE acc,[])
End





Datatype:
  cmp = Less | Equal
End

Datatype:
  test = Test cmp exp exp | And test test | Or test test | Not test
End

Datatype:
  cmd = Assign name exp                (*  v := e                  *)
      | Update exp exp exp             (*  a[e] := e'              *)
      | If test (cmd list) (cmd list)  (*  if (test) ... else ...  *)
      | While test (cmd list)          (*  while (test) ...        *)
      | Call name name (exp list)      (*  v := foo(e1,e2,e3,...)  *)
      | Return exp                     (*  return from function    *)
      | Alloc name exp                 (*  v := malloc(e)          *)
      | GetChar name                   (*  v := getchar()          *)
      | PutChar exp                    (*  putchar(e)              *)
      | Abort                          (*  exit(1)                 *)
End

Datatype:
  func = Func name (name list) (cmd list)   (* func name, formal params, body *)
End

Datatype:
  prog = Program (func list)    (*   a complete program is a list   *)
End                             (*   of function definitions        *)

Definition get_name_def[simp]:
  get_name (Func n _ _) = n
End

*)

val _ = export_theory();
