%{ 
From impboot Require Import
  utils.Core
  utils.Llist.
Import Llist.
Require Import impboot.imperative.ImpSyntax.
Require Import coqutil.Word.Interface.
Require Import coqutil.Word.Properties.
%}

(* Tokens *)

%token LPAREN "("
%token RPAREN ")"
%token COMMA ","
%token <string> NAME
%token <Z> INT

%token SKIP "Skip"
%token SEQ "Seq"
%token ASSIGN "Assign"
%token UPDATE "Update"
%token IF "If"
%token WHILE "While"
%token CALL "Call"
%token RETURN "Return"
%token ALLOC "Alloc"
%token GETCHAR "GetChar"
%token PUTCHAR "PutChar"
%token ABORT "Abort"
%token VAR "Var"
%token CONST "Const"
%token ADD "Add"
%token SUB "Sub"
%token DIV "Div"
%token READ "Read"
%token TEST "Test"
%token AND "And"
%token OR "Or"
%token NOT "Not"
%token LESS "Less"
%token EQUAL "Equal"

%start <prog> prog
%type<test> test
%type<list N> params
%type<list N> names
%type<list func> many_func_rec
%type<list func> many_func
%type<list exp> many_exp
%type<list exp> exps
%type<exp> exp
%type<cmp> cmp
%type<cmd> cmd
%type<func> f
%type<N> name
%type<word64> word64

%%

prog:
  | funcs = many_func { Program funcs }

many_func:
  | LPAREN; fs = many_func_rec { fs }
many_func_rec:
  | RPAREN                   { [] }
  | f = f; COMMA; fs = many_func  { f :: fs }

name:
  | n = NAME { name_of_string n }

f:
  | LPAREN; n = name; ps = params; c = cmd; RPAREN { Func n ps c }

params:
  | LPAREN; ns = names  { ns }

names:
  | RPAREN                    { [] }
  | n = name; COMMA; ns = names  { n :: ns }

cmd:
  | LPAREN; "Skip"; RPAREN
        { Skip }
  | LPAREN; "Seq"; c1 = cmd; c2 = cmd; RPAREN
        { Seq c1 c2 }
  | LPAREN; "Assign"; n = name; e = exp; RPAREN
        { Assign n e }
  | LPAREN; "Update"; a = exp; e1 = exp; e2 = exp; RPAREN
        { Update a e1 e2 }
  | LPAREN; "If"; t = test; c1 = cmd; c2 = cmd; RPAREN
        { If t c1 c2 }
  | LPAREN; "While"; t = test; c = cmd; RPAREN
        { While t c }
  | LPAREN; "Call"; n = name; f = name; es = many_exp; RPAREN
        { Call n f es }
  | LPAREN; "Return"; e = exp; RPAREN
        { Return e }
  | LPAREN; "Alloc"; n = name; e = exp; RPAREN
        { Alloc n e }
  | LPAREN; "GetChar"; n = name; RPAREN
        { GetChar n }
  | LPAREN; "PutChar"; e = exp; RPAREN
        { PutChar e }
  | LPAREN; "Abort"; RPAREN
        { Abort }

many_exp:
  | LPAREN es = exps RPAREN      { es }
  |                         { [] }

exps:
  | /* empty */             { [] }
  | e = exp; COMMA; es = exps { e :: es }

word64:
  | n = INT { (word.of_Z n): word64 }

exp:
  | LPAREN; "Var"; n = name; RPAREN
        { Var n }
  | LPAREN; "Const"; num = word64; RPAREN
        { Const num }
  | LPAREN; "Add"; e1 = exp; e2 = exp; RPAREN
        { Add e1 e2 }
  | LPAREN; "Sub"; e1 = exp; e2 = exp; RPAREN
        { Sub e1 e2 }
  | LPAREN; "Div"; e1 = exp; e2 = exp; RPAREN
        { Div e1 e2 }
  | LPAREN; "Read"; e1 = exp; e2 = exp; RPAREN
        { Read e1 e2 }

test:
  | LPAREN; "Test"; cmp = cmp; e1 = exp; e2 = exp; RPAREN
        { Test cmp e1 e2 }
  | LPAREN; "And"; t1 = test; t2 = test; RPAREN
        { And t1 t2 }
  | LPAREN; "Or"; t1 = test; t2 = test; RPAREN
        { Or t1 t2 }
  | LPAREN; "Not"; t = test; RPAREN
        { Not t }

cmp:
  | LPAREN "Less" RPAREN   { Less }
  | LPAREN "Equal" RPAREN  { Equal }
