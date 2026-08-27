# Running the Rocq submission

From the repository root, enter the `rocq/` directory. Run the remaining
commands there:

```sh
cd rocq
```

The development targets Rocq 9.0.0, as recorded in `dune-project`. Building the
generated compiler can use several gigabytes of memory; use `-j 1` on a
resource-constrained machine.

## Setup

Create or select an opam switch, then pin the development versions of
[`coqutil`](https://github.com/mit-plv/coqutil) and
[`patat`](https://github.com/kacperFKorban/patat):

```sh
opam pin add coq-coqutil.dev https://github.com/mit-plv/coqutil.git
opam pin add patat.dev https://github.com/kacperFKorban/patat.git
```

Install the remaining dependencies declared by the package:

```sh
opam install . --deps-only
```

## Check the development

Start with a clean build so that every theory is checked from source:

```sh
opam exec -- dune clean
opam exec -- dune build -j 1
opam exec -- dune runtest -j 1
```

The build checks the generated derivations and the formal bootstrap results in
`imp2asm/CompilerProofs.v`, including `compiler_program_imp_exists` and
`compiler_asm_bootstrap`. A focused rebuild of the formal bootstrap target can
be requested with:

```sh
opam exec -- dune build -j 1 imp2asm/CompilerProofs.vo
```

## Native compiler stack limit

The generated compiler uses the process stack extensively. A typical 8 MiB
default stack is insufficient for self-compilation, so raise the limit before
running the native compiler:

```sh
ulimit -s 1048576
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
