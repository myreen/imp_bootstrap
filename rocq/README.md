# Running the Rocq submission

This directory contains the rocq development of a simple verified bootstrapped compiler for an imperative language.

## Setup

Create (`opam switch create . --no-install`) or select an existing opam switch, then install the dependencies declared by the package:

```sh
opam install . --deps-only
```

## Check the development

Start with a clean build so that every theory is checked from source:

```sh
ulimit -s 1048576
opam exec -- dune clean
opam exec -- dune build
```

## Running the bootstrapped compiler

The generated compiler uses the stack extensively. A typical 8 MiB
default stack is insufficient for self-compilation, so raise the limit before
running the compiler outside of Rocq:

```sh
ulimit -s 1048576
```
