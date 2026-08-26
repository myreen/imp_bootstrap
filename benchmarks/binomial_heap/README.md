# Binomial Heap Benchmarks

Fourteen no-output executables run the same `2000`/`2001` heap workload:

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
using IMPL's machine-number encoding for Rocq's built-in `nat`. The inputs 2000
and 2001 are constructed solely with `MyNat` addition and multiplication, so
the timed workload does not convert from a differently represented numeric
type.

Every CertiRocq-generated C program is compiled four ways: `-O0` (no C
optimization), `-O1`, `-O2` (the existing baseline), and `-O3` (maximum
standard Clang optimization). The optimized variants also use
`-fomit-frame-pointer`. The benchmark labels always include the C optimization
level.

See [ADAPTATION.md](ADAPTATION.md) for the source changes needed by the IMPL
reifier and their limitations.

The CertiCoq-derived sources use the MIT terms in [NOTICE](NOTICE).

## Run

```sh
make
make benchmark
```

Defaults use the project opam switch plus CertiRocq `v0.9.1+9.1` installed at:

```text
/tmp/opencode/certirocq-0.9.1-switch
/tmp/opencode/certirocq-0.9.1-src
```

Override them when needed:

```sh
make PROJECT_SWITCH=/path/to/project-switch \
  CERTIROCQ_SWITCH=/path/to/certirocq-switch \
  CERTIROCQ_SRC=/path/to/certirocq
```

`make benchmark` validates each binary once, then times only executable runs.
