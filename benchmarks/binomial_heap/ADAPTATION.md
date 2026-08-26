# CertiCoq Binomial Heap Adaptation

## Source Baseline

[`CertiCoqBinomOriginal.v`](certirocq/CertiCoqBinomOriginal.v)
contains the source from CertiCoq commit
`59f110359ed57550a746124441f20b993774af78` with its MIT notice. The adapted
implementation is [`AdjustedBinomialHeap.v`](shared/AdjustedBinomialHeap.v);
its reification support and generated definitions are in
[`ReifyAdjusted.v`](impl/ReifyAdjusted.v).

The representation-matched variant is
[`MyNatBinomialHeap.v`](shared/MyNatBinomialHeap.v), with IMPL support in
[`ReifyMyNat.v`](impl/ReifyMyNat.v). Both IMPL and CertiRocq compile this same
source file.

## Unary `MyNat` Variant

The representation-matched benchmark replaces every numeric key and the
`make_list` counter with the usual unary type:

```coq
Inductive MyNat : Type :=
| MyO : MyNat
| MyS : MyNat -> MyNat.
```

Its `2000` and `2001` inputs are built at run time using only `MyNat`
constructors, addition, and multiplication. No built-in `nat` value is
converted as part of the timed workload.

IMPL encodes `MyO` as zero and `MyS n` as one pair cell containing the encoding
of `n`. The reifier supplies constructor, elimination, recursive-unfolding,
and correctness rules for this encoding. This removes the previous numeric
representation mismatch: IMPL no longer encodes these values as machine
numbers while CertiRocq encodes them in unary.

Calls to the recursive `MyNat` comparison are staged with `dlet`, and custom
`MyNat` match branches are converted to administrative normal form before
reification. These are lowering requirements of IMPL and are definitionally
ordinary lets; both compilers receive the staged shared source.

The remaining allocation layouts are compiler-specific, so this variant
matches the asymptotic unary representation rather than claiming identical
object headers or heap-cell layouts.

## Source Code Changes

### First-Order `unzip`

**Original:**

```coq
unzip t2 (fun q => Node x t1 Leaf :: cont q)
```

**Adapted:**

```coq
unzip_acc t2 (Node x t1 Leaf :: acc)
```

**Reason:** the reifier supports first-order values and cannot represent
continuation closures.

**Limitation:** calls and allocations differ from the continuation-based
implementation, although the resulting list order is the same.

### Scrutinee Evaluation Staging

**Original:**

```coq
match find_max q with
| None => None
| Some m => ...
end
```

**Adapted:**

```coq
dlet! mx := find_max q in
match mx return option (key * priqueue) with
| None => None
| Some m => ...
end
```

The recursive pair results in `delete_max_aux` and `delete_max` are staged in
the same way before they are destructured.

**Reason:** the reifier automatically lifts nested calls, constructors, and
arithmetic, but does not lift computations out of match and pair-destructuring
scrutinees.

**Limitation:** computed scrutinees remain slightly more verbose than in the
original source, although `dlet!` is definitionally an ordinary let.

### Explicit Match Result Types

**Without the annotation:**

```coq
match mx with
| None => None
| Some m => ...
end
```

**Required after staging:**

```coq
match mx return option (key * priqueue) with
| None => None
| Some m => ...
end
```

**Reason:** Rocq cannot infer the result type of this match through the `dlet`
that stages its computed scrutinee.

**Limitation:** this adds type-level verbosity but does not change execution.

### Benchmark Function Name

**Original:**

```coq
Definition main := ...
```

**Adapted:**

```coq
Definition benchmark_main := ...
```

**Reason:** `to_imp` reserves `main` and synthesizes the executable entry point.

**Limitation:** the source-level symbol differs and the generated entry point
must call `benchmark_main`.

## Added Definitions and Proofs

### Natural-Number Successor Reification

**Added:**

```coq
| S ?n =>
    if proper_const e then
      app_lemma "auto_nat_const"
        [("env", exactk fenv); ("n", exactk constr:(S $n))] []
    else
      app_lemma "auto_nat_succ"
        [("env", exactk fenv); ("n", exactk n)] [compile]
```

The existing `auto_nat_succ` semantic lemma proves that this generated addition
evaluates to the encoding of `S n`.

**Reason:** this allows the original `S (S n)` expression in `make_list` to be
reified directly instead of rewriting it as arithmetic in the source.

**Limitation:** nonconstant successors are represented by addition in the
generated functional program; closed numerals remain constants.

### Runtime Encoding and Reification Rules

**Added:**

```coq
Fixpoint encode_tree (t : tree) : FunValues.Value :=
  match t with
  | Leaf => FunValues.Num 0
  | Node x l r =>
      value_list_of_values [encode x; encode_tree l; encode_tree r]
  end.

Global Instance Refinable_tree : Refinable tree :=
  {| encode := encode_tree |}.
```

The port also adds semantic rules and Ltac2 tactics for constructing and
eliminating encoded trees. The elimination rule supplies an equality for the
matched value to each branch:

```coq
match t with
| Leaf => t = Leaf -> ...
| Node x l r => t = Node x l r -> ...
end
```

**Reason:** reification requires an explicit runtime representation and proofs
that generated expressions evaluate to the corresponding encoded values. The
branch equality preserves the original scrutinee when a multi-pattern match
reuses it, allowing `carry` and `join` to retain the CertiCoq source shape.

**Limitation:** the representation and allocation layout differ from CertiCoq,
and the eliminator and its equality handling are specific to this tree encoding.

### Recursive Unfolding Equations

**Added:**

```coq
Theorem make_list_equation : ltac2:(unfold_fix_type '@make_list).
Proof. unfold_fix_proof '@make_list. Qed.
```

Equivalent equations are added for every recursive function used by the
relational compiler.

**Reason:** the proof-producing compiler needs named one-step unfolding
theorems for recursive calls.

**Limitation:** this adds proof boilerplate tied to the exact function names and
definitions.

### Generated Programs and Correctness Proofs

**Added:**

```coq
Derive delete_max_prog
  in ltac2:(relcompile_tpe 'delete_max_prog 'delete_max
    ['find_max; 'delete_max_aux; 'join])
  as delete_max_prog_correct.
Proof. relcompile. Qed.
```

A generated definition and correctness proof are added for each function in the
benchmark's dependency graph.

**Reason:** these definitions are the functional-language programs consumed by
`to_funs`, and the proofs connect them to their Gallina implementations.

**Limitation:** the proofs establish correctness of the adapted definitions;
they are not a cross-module equivalence proof with the preserved source file.

### Program List and Compilation

**Added:**

```coq
Definition adjusted_funs : list FunSyntax.defun := [
  smash_prog; carry_prog; insert_prog; join_prog; merge_prog;
  unzip_acc_prog; unzip_prog; heap_delete_max_prog;
  find_max'_prog; find_max_prog; delete_max_aux_prog; delete_max_prog;
  insert_list_prog; make_list_prog; benchmark_main_prog
].
```

`Program.v` supplies this exact dependency closure to `to_funs` and `to_imp`,
then lowers the resulting imperative program to assembly. The benchmark build
validates the generated executable.

**Reason:** IMP code generation emits every supplied definition, so the
comparison needs an explicit dependency closure and checks that it lowers
successfully without name collisions.

**Limitation:** the dependency lists are maintained manually.

### Benchmark Result Check

**Added:**

```coq
Lemma benchmark_main_result : benchmark_main = 2001.
Proof. vm_compute. reflexivity. Qed.
```

**Reason:** the executable runtime discards the functional return value, so the
expected result is checked inside Rocq.

**Limitation:** this proves the result only for the fixed `2000`/`2001`
benchmark instance.
