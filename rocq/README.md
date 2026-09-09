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

## Paper theorems and lemmas

| Paper result | Source location |
| --- | --- |
| Theorems 2.1 and 5.1: correctness of `impl_to_asm` | [`codegen_terminates`](./imp2asm/ImpToASMCodegenProofs.v#L5925) |
| Theorem 2.2: correctness of compiler in FP | [`compiler_program_thm`](./derivations/CompilerDerivations.v#L219) |
| Theorem 2.3: correctness of compiler in IMPL | [`to_imp_thm` applied within `compiler_correct`](./imp2asm/CompilerProofs.v#L31) |
| Theorem 2.4: correctness of compiler in ASM | [`compiler_correct`](./imp2asm/CompilerProofs.v#L19) |
| Lemma 2.5: preservation of aborts | [`codegen_no_abort`](./imp2asm/ImpToASMCodegenProofs.v#L5954) |
| Theorem 2.6: correctness of recompilation check | [`compiler_asm_bootstrap`](./imp2asm/CompilerProofs.v#L54) |
| Lemma 2.7: parser validation for compiler in IMPL | [`print_parser_compiler_correct`](./imp2asm/CompilerProofs.v#L44) |
| Theorem 3.6: reifying the compiler | [`compiler_thm`](./derivations/CompilerDerivations.v#L153) |
| Theorem 3.7: reifying the compiler with I/O | [`compiler_program_thm`](./derivations/CompilerDerivations.v#L219) |
| Theorem 4.1: correctness of `fp_to_impl` | [`to_imp_thm`](./fp2imp/FpToImpCodegenProof.v#L1454) |
| Theorem 5.2: no-divergence introduction of `impl_to_asm` | [`codegen_diverges`](./imp2asm/ImpToASMCodegenProofs.v#L6138) |

## Code structure

| Location | Contents |
| --- | --- |
| [`./functional`](./functional) | Functional language syntax, semantics, value encodings, and properties. |
| [`./imperative`](./imperative) | Imperative language syntax, semantics, properties, and pretty-printing. |
| [`./assembly`](./assembly) | Assembly syntax, semantics, properties, and pretty-printing. |
| [`./parsing`](./parsing) | Imperative language parser and supporting proofs. |
| [`./fp2imp`](./fp2imp) | FP-to-IMPL code generator and correctness proof. |
| [`./imp2asm`](./imp2asm) | IMPL-to-ASM code generator, compiler pipeline, and correctness proofs. |
| [`./automation`](./automation), [`./plugin`](./plugin) | Reification tactics, supporting lemmas, and tactic syntax. |
| [`./derivations`](./derivations) | Reified compiler functions and their correctness certificates. |
| [`./bootstrapping`](./bootstrapping) | Bootstrapping definitions, computation, and output of compiler files. |
| [`./commons`](./commons), [`./utils`](./utils) | Shared compiler definitions and proof utilities. |
| [`./demo`](./demo) | Reification and bootstrapping examples. |

The paper's reification tutorial example is available in [`demo/PaperTutorial.v`](./demo/PaperTutorial.v).
