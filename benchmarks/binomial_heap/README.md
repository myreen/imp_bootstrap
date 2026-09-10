# Binomial Heap Benchmarks

This directory contains the adapted binomial heap benchmark from CertiRocq.

| Benchmark labels | Source | Compiler |
|---|---|---|
| `impl-adjusted` | shared first-order source | IMPL |
| `certirocq-adjusted-{o0,o1,o2,o3}` | shared first-order source | CertiRocq + Clang |
| `impl-mynat` | shared first-order source with unary `MyNat` | IMPL |
| `certirocq-mynat-{o0,o1,o2,o3}` | shared first-order source with unary `MyNat` | CertiRocq + Clang |
| `certirocq-original-{o0,o1,o2,o3}` | original higher-order source | CertiRocq + Clang |

Each directly comparable pair compiles the same physical source file:

- `impl-adjusted` and `certirocq-adjusted` compile
  `shared/AdjustedBinomialHeap.v`.
- `impl-mynat` and `certirocq-mynat` compile
  `shared/MyNatBinomialHeap.v`.

The `mynat` pair uses the unary constructors `MyO` and `MyS`. IMPL's
encoding represents `MyO` as zero and allocates one cell per `MyS`, rather than
using IMPL's machine-number encoding for Rocq's built-in `nat`.

Every CertiRocq-generated C program is compiled four ways: `-O0` (no C
optimization), `-O1`, `-O2` (the existing baseline), and `-O3` (maximum
standard Clang optimization). The optimized variants also use
`-fomit-frame-pointer`.

The CertiCoq-derived sources use the MIT terms in [NOTICE](NOTICE).

## Setup

First follow the [Rocq setup instructions](../../rocq/README.md) for the IMPL
compiler. The benchmarks also require Make, GCC, Clang, Python 3, and Bash on
x86-64 Linux.

From this directory, create a separate local opam switch and install the
benchmark dependencies:

```sh
opam switch create . 4.14.2 --no-install
opam repository add rocq-released https://rocq-prover.org/opam/released
opam install . --deps-only
```

The Makefile uses this switch for CertiRocq and the switch selected in `rocq/`
for IMPL. It finds the C runtime in the installed CertiRocq package; no separate
source checkout is needed.

## Check and run

```sh
make
make benchmark
```

For a quick check of all variants, use `bash ./run_benchmarks.sh 2 2` after
`make`. The arguments are iterations per variant and number of batches;
the defaults are 1000 and 3.
