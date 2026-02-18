Set Warnings "-notation-overridden,-notation-incompatible-prefix".
From Stdlib Require Extraction.
Set Extraction Output Directory "./extraction".
Extraction Language OCaml.
From Stdlib Require Import ExtrOcamlBasic.
From Stdlib Require Import ExtrOcamlString.

From impboot.utils Require Import Core.
From impboot.parsing Require Import Parser.
From impboot.imperative Require Import Printing.

Extract Inductive nat => "int64"
  [ "0L" "(fun x -> Int64.add x 1L)" ]
  "(fun zero succ n -> if Int64.equal n 0L then zero () else succ (Int64.sub n 1L))".

Extract Inductive positive => "int64"
[ "(fun p -> Int64.add 1L (Int64.mul 2L p))" "(fun p -> Int64.mul 2L p)" "1L" ]
"(fun f2p1 f2p f1 p ->
  if Int64.compare p 1L <= 0 then f1 () else if Int64.equal (Int64.rem p 2L) 0L then f2p (Int64.div p 2L) else f2p1 (Int64.div p 2L))".

Extract Inductive N => "int64" [ "0L" "" ]
  "(fun f0 fp n -> if Int64.equal n 0L then f0 () else fp n)".

Extract Inlined Constant Nat.add => "Int64.add".
Extract Inlined Constant Nat.mul => "Int64.mul".
Extract Inlined Constant Nat.eqb => "Int64.sub".

Extract Inlined Constant Pos.add => "Int64.add".
Extract Inlined Constant Pos.succ => "Int64.succ".
Extract Inlined Constant Pos.pred => "fun n -> Int64.max 1L (Int64.sub n 1L)".
Extract Inlined Constant Pos.sub => "fun n m -> Int64.max 1L (Int64.sub n m)".
Extract Inlined Constant Pos.mul => "Int64.mul".
Extract Inlined Constant Pos.min => "Int64.min".
Extract Inlined Constant Pos.max => "Int64.max".
Extract Inlined Constant Pos.compare =>
 "fun x y -> if Int64.equal x y then Eq else if Int64.compare x y < 0 then Lt else Gt".
Extract Inlined Constant Pos.compare_cont =>
 "fun c x y -> if Int64.equal x y then c else if Int64.compare x y < 0 then Lt else Gt".

Extract Inlined Constant N.add => "Int64.add".
Extract Inlined Constant N.succ => "Int64.succ".
Extract Inlined Constant N.pred => "(fun n -> Int64.max 0L (Int64.sub n 1L))".
Extract Inlined Constant N.sub => "(fun n m -> Int64.max 0L (Int64.sub n m))".
Extract Inlined Constant N.mul => "Int64.mul".
Extract Inlined Constant N.min => "Int64.min".
Extract Inlined Constant N.max => "Int64.max".
Extract Inlined Constant N.div => "(fun a b -> if Int64.equal b 0L then 0L else Int64.div a b)".
Extract Inlined Constant N.modulo => "(fun a b -> if Int64.equal b 0L then a else Int64.rem a b)".
Extract Constant N.compare =>
 "fun x y -> if Int64.equal x y then Eq else if Int64.compare x y < 0 then Lt else Gt".
Extract Constant N.leb => "(fun n m -> Int64.compare n m <= 0)".
Extract Constant N.to_nat => "(fun x -> x)".


Extraction "ExtractParser.ml" str2imp imp2str.
