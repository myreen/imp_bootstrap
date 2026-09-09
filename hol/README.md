# Running the HOL4 submission

This directory contains the HOL4 development of a simple verified bootstrapped compiler for an imperative language.

## Setup

Follow [`build-instructions.sh`](build-instructions.sh) to install Poly/ML and
HOL4 and build this development. The instructions are adapted from the
[CakeML build instructions](https://github.com/CakeML/cakeml/blob/master/build-instructions.sh)
and pin HOL4 to the Trindemossen-2 release.

## Check the development

From this repository's `hol` directory, start with a clean build so that every
theory is checked from source:

```sh
Holmake -r cleanAll
Holmake -r
```

The `-r` option also builds the dependencies in `functional` and the HOL4
directories listed in the `Holmakefile`s. The clean command cleans those
dependencies as well. The build checks the bootstrapping proofs and generates
`imp_compiler_prog.txt` and `imp_compiler_asm.s`.
