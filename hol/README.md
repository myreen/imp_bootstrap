# Running the HOL4 submission

This directory contains the HOL4 development of a simple verified bootstrapped compiler for an imperative language.

## Setup

Prerequisites: Git, a C/C++ compiler, Make, and GMP development headers.

Follow [`build-instructions.sh`](build-instructions.sh) to install Poly/ML and
HOL4 and build this development. The instructions are adapted from the
[CakeML build instructions](https://github.com/CakeML/cakeml/blob/master/build-instructions.sh)
and pin HOL4 to Trindemossen-2-v7, commit
`e395eb6e69054ff6f7cef9d1107fd1a04dd5848f`.

## Check the development

From this repository's `hol` directory, start with a clean build so that every
theory is checked from source:

```sh
export HOLDIR="$HOME/HOL"
export PATH="$HOLDIR/bin:$PATH"
Holmake -r cleanAll
Holmake -r
```

## Paper theorems and lemmas

| Paper result | Source location |
| --- | --- |
| Theorems 2.1 and 5.1: correctness of `impl_to_asm` | [`codegen_terminates`](./imp_to_asm_proofScript.sml#L4297) |
| Theorem 2.2: correctness of compiler in FP | [`compiler_prog_correct`](./imp_compiler_progScript.sml#L689) |
| Theorem 2.3: correctness of compiler in IMPL | [`compiler_program_thm`](./bootstrappingScript.sml#L72) |
| Theorem 2.4: correctness of compiler in ASM | [`compiler_correct`](./bootstrappingScript.sml#L91) |
| Lemma 2.5: preservation of aborts | [`codegen_no_abort`](./imp_to_asm_proofScript.sml#L4316) |
| Theorem 2.6: correctness of recompilation check | [`compiler_asm_bootstrap`](./bootstrappingScript.sml#L130) |
| Lemma 2.7: parser validation for compiler in IMPL | [`print_parser_compiler_correct`](./bootstrappingScript.sml#L112) |
| Theorem 3.6: reifying the compiler | component certificates are composed in [`compiler_prog_correct`](./imp_compiler_progScript.sml#L689). |
| Theorem 3.7: reifying the compiler with I/O | [`compiler_prog_correct`](./imp_compiler_progScript.sml#L689) |
| Theorem 4.1: correctness of `fp_to_impl` | [`to_imp_thm`](./source_to_impScript.sml#L929) |
| Theorem 5.2: no-divergence introduction of `impl_to_asm` | [`codegen_diverges`](./imp_to_asm_proofScript.sml#L4383) |

## Code structure

| Location | Contents |
| --- | --- |
| [`./functional`](./functional) | Functional-language and assembly definitions, parser and printer infrastructure, low-level code generation, and shared automation lemmas. |
| [`imp_source_syntaxScript.sml`](./imp_source_syntaxScript.sml), [`imp_source_semanticsScript.sml`](./imp_source_semanticsScript.sml), [`imp_source_propertiesScript.sml`](./imp_source_propertiesScript.sml) | Imperative language syntax, semantics, and properties. |
| [`imp_parsingScript.sml`](./imp_parsingScript.sml), [`imp_printingScript.sml`](./imp_printingScript.sml) | Imperative language parser and pretty-printer. |
| [`source_to_impScript.sml`](./source_to_impScript.sml) | FP-to-IMPL code generator and correctness proof. |
| [`imp_to_asmScript.sml`](./imp_to_asmScript.sml), [`imp_to_asm_proofScript.sml`](./imp_to_asm_proofScript.sml) | IMPL-to-ASM code generator and correctness proofs. |
| [`imp_compilerScript.sml`](./imp_compilerScript.sml), [`imp_compiler_proofsScript.sml`](./imp_compiler_proofsScript.sml) | Compiler pipeline and top-level correctness theorems. |
| [`imp_automationLib.sml`](./imp_automationLib.sml), [`imp_automation_lemmasScript.sml`](./imp_automation_lemmasScript.sml) | Reification automation and supporting lemmas. |
| [`imp_compiler_progScript.sml`](./imp_compiler_progScript.sml) | Compiler reification and its correctness certificate. |
| [`imp_compiler_cvScript.sml`](./imp_compiler_cvScript.sml) | Support for verified evaluation with `cv_compute`. |
| [`bootstrappingScript.sml`](./bootstrappingScript.sml) | Bootstrapping definitions, proofs, and generated compiler files. |
