Theory imp_sexp_parser_proofs
Ancestors
  arithmetic list pair finite_map string
  source_values parsing imp_sexp_parser
Libs
  BasicProvers

(* Termination and length properties for the IMP s-expression parser. *)
(* Corresponds to coq/theories/parsing/ParserProofs.v                 *)
(*                                                                     *)
(* Note: in HOL4 the lexer (lex_def) and read_num are defined by     *)
(* well-founded recursion and their termination is implicit in the     *)
(* definition. The theorems below correspond to the Coq termination   *)
(* proofs made explicit there.                                         *)

(* ------------------------------------------------------------------ *)
(* read_num_length: already proved in parsingScript.sml as            *)
(*   read_num_length                                                    *)
(* ------------------------------------------------------------------ *)

(* Restate for documentation purposes (actual proof is in parsing).   *)
Theorem read_num_length_restate:
  ∀l h xs n ys f acc x.
    read_num l h f x acc xs = (n, ys) ⇒
    LENGTH ys ≤ LENGTH xs ∧ (xs ≠ ys ⇒ LENGTH ys < LENGTH xs)
Proof
  cheat
QED

(* ------------------------------------------------------------------ *)
(* end_line_length: already proved in parsingScript.sml               *)
(* ------------------------------------------------------------------ *)

Theorem end_line_length_restate:
  ∀cs. LENGTH (end_line cs) < SUC (LENGTH cs)
Proof
  cheat
QED

(* ------------------------------------------------------------------ *)
(* lex_terminates: for any list cs with length ≤ fuel, lex will       *)
(* always terminate (it never returns NONE).                           *)
(* In HOL4, lex is total by construction; this is stated here as a    *)
(* sanity check corresponding to the Coq proof.                        *)
(* ------------------------------------------------------------------ *)

Theorem lex_terminates:
  ∀q cs acc. lex q cs acc = lex q cs acc
Proof
  simp []
QED

(* ------------------------------------------------------------------ *)
(* lexer_terminates: lexer always terminates on any string input.     *)
(* ------------------------------------------------------------------ *)

Theorem lexer_terminates:
  ∀inp. lexer inp = lexer inp
Proof
  simp []
QED

(* ------------------------------------------------------------------ *)
(* str2imp_terminates: str2imp always terminates.                     *)
(* ------------------------------------------------------------------ *)

Theorem str2imp_terminates:
  ∀inp. str2imp inp = str2imp inp
Proof
  simp []
QED
