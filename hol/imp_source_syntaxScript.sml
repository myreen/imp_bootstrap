Theory imp_source_syntax
Ancestors
  arithmetic list pair finite_map string words source_values

(* abstract syntax *)

Type name = “:num”

Datatype:
  exp = Var name      (*  variable             *)
      | Const word64  (*  word constant        *)
      | Add exp exp   (*  word addition        *)
      | Sub exp exp   (*  word subtraction     *)
      | Div exp exp   (*  word division        *)
      | Read exp exp  (*  read memory:  e[e']  *)
End

Datatype:
  cmp = Less | Equal
End

Datatype:
  test = Test cmp exp exp | And test test | Or test test | Not test
End

Datatype:
  cmd = Skip                       (*  do nothing              *)
      | Assign name exp            (*  v := e                  *)
      | Update exp exp exp         (*  a[e] := e'              *)
      | Seq cmd cmd                (*  ... ; ...               *)
      | If test cmd cmd            (*  if (test) ... else ...  *)
      | While test cmd             (*  while (test) ...        *)
      | Call name name (exp list)  (*  v := foo(e1,e2,e3,...)  *)
      | Return exp                 (*  return from function    *)
      | Alloc name exp             (*  v := malloc(e)          *)
      | GetChar name               (*  v := getchar()          *)
      | PutChar exp                (*  putchar(e)              *)
      | Abort                      (*  exit(1)                 *)
End

Datatype:
  func = Func name (name list) cmd   (* func name, formal params, body *)
End

Datatype:
  prog = Program (func list)    (*   a complete program is a list   *)
End                             (*   of function definitions        *)

Definition get_name_def[simp]:
  get_name (Func n _ _) = n
End

Definition get_funcs_def[simp]:
  get_funcs (Program funcs) = funcs
End
