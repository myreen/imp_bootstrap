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

The `mynat` pair uses the usual unary constructors `MyO` and `MyS`. IMPL's
encoding represents `MyO` as zero and allocates one cell per `MyS`, rather than
using IMPL's machine-number encoding for Rocq's built-in `nat`.

Every CertiRocq-generated C program is compiled four ways: `-O0` (no C
optimization), `-O1`, `-O2` (the existing baseline), and `-O3` (maximum
standard Clang optimization). The optimized variants also use
`-fomit-frame-pointer`.

The CertiCoq-derived sources use the MIT terms in [NOTICE](NOTICE).

## Run

```sh
make
make benchmark
```

