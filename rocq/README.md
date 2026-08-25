## Setup

Pin [`patat`](https://github.com/kacperFKorban/patat):

```sh
opam pin add patat.dev https://github.com/kacperFKorban/patat.git
```

Then, install the dependencies:

```sh
opam install . --deps-only
```

## Measure compiler construction

Measure reification of the compiler itself and its subsequent compilation to
the imperative and assembly languages with:

```sh
opam exec -- python3 measure_compiler.py --runs 3
```

The command prints an aggregate table and stores CSV results plus the raw Rocq
logs in `timings/`. Use `--output <directory>` to select a stable result
directory when comparing revisions.

Each run uses a fresh Dune build directory with the shared prerequisites built
before measurement. Reification is reported both as a full-pipeline total and
by compiler component. The generated compiler is then timed separately for
functional-to-imperative compilation, imperative printing, assembly generation,
and assembly printing. Each compiler stage is materialized before the next one,
so the measurements are not cumulative. The CSV records monotonic process-level
timings as well as Rocq's `Time` output. Existing `time relcompile` commands in
the derivation files provide finer per-function diagnostics when a component
regresses.
