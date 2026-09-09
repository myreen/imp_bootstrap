# Verified Bootstrapping of a Compiler for an Imperative Language

This repository contains Rocq and HOL4 developments of a verified bootstrapped compiler for a small imperative language. The compiler is bootstrapped: it can compile itself inside of the ITP, thus removing the need to extract it.

## Project setup

The compiler developments in the two ITPs are available in their corresponding directories, together with ITP-specific instructions:
- [HOL4 in `./hol`](./hol) with the starting point in [`./hol/README.md`](./hol/README.md)
- [Rocq in `./rocq`](./rocq) with the starting point in [`./rocq/README.md`](./rocq/README.md)
