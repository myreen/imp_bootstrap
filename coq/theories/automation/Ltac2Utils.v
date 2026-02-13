From Ltac2 Require Import Ltac2 Std List Constr RedFlags Message Printf.
Import Ltac2.Constr.Unsafe.
From coqutil Require Import Tactics.reference_to_string.

Ltac2 Type exn ::= [
  Oopsie (message)
].

Ltac2 reference_of_constr_opt (c: constr): reference option :=
  match kind c with
  | Var id => Some (Std.VarRef id)
  | Constant const _inst => Some (Std.ConstRef const)
  | Ind ind _inst => Some (Std.IndRef ind)
  | Constructor cnstr _inst => Some (Std.ConstructRef cnstr)
  | _ => None
end.

Ltac2 reference_to_string (r : reference) : string option :=
  Some (Ident.to_string (List.last (Env.path r))).

Ltac2 ident_of_fqn (fqn: string list): ident list :=
  List.map (fun s => Option.get (Ident.of_string s)) fqn.

Ltac2 rec var_ident_of_constr (c: constr): ident :=
  match Unsafe.kind c with
  | Var i => i
  | _ =>
    Control.throw (Oopsie (fprintf "Error: Expected the argument of a compiled function to be an variable reference, got: %t" c))
  end.
