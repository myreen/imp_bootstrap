# Binomial Heap Benchmarks

Three no-output executables run the same `2000`/`2001` heap workload:

| Target | Source | Compiler |
|---|---|---|
| `impl-adjusted` | shared first-order source | IMPL |
| `certirocq-adjusted` | shared first-order source | CertiRocq |
| `certirocq-original` | original higher-order source | CertiRocq |

The first two targets compile the same physical file:
`shared/AdjustedBinomialHeap.v`.

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
