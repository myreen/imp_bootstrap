ROOT := $(abspath ../..)
WORKSPACE := $(CURDIR)
BUILD := $(WORKSPACE)/_build

PROJECT_SWITCH ?= $(ROOT)
CERTIROCQ_SWITCH ?= /tmp/opencode/certirocq-0.9.1-switch
CERTIROCQ_SRC ?= /tmp/opencode/certirocq-0.9.1-src

PROJECT_ROCQ = opam exec --switch=$(PROJECT_SWITCH) -- rocq
CERTIROCQ = opam exec --switch=$(CERTIROCQ_SWITCH) -- rocq
IMPBOOT_BUILD = $(ROOT)/rocq/_build/default
CERTIROCQ_RUNTIME = $(CERTIROCQ_SRC)/runtime

SHARED_SOURCE = $(WORKSPACE)/shared/AdjustedBinomialHeap.v
MYNAT_SOURCE = $(WORKSPACE)/shared/MyNatBinomialHeap.v
IMPL_REIFY = $(WORKSPACE)/impl/ReifyAdjusted.v
IMPL_PROGRAM = $(WORKSPACE)/impl/Program.v
IMPL_MYNAT_REIFY = $(WORKSPACE)/impl/ReifyMyNat.v
IMPL_MYNAT_PROGRAM = $(WORKSPACE)/impl/ProgramMyNat.v
DECODER = $(WORKSPACE)/impl/decode_assembly.py
CERTI_ADJUSTED_DRIVER = $(WORKSPACE)/certirocq/CompileAdjusted.v
CERTI_MYNAT_DRIVER = $(WORKSPACE)/certirocq/CompileMyNat.v
CERTI_ORIGINAL_DRIVER = $(WORKSPACE)/certirocq/CompileOriginal.v
CERTI_MAIN = $(WORKSPACE)/certirocq/no_output_main.c
ORIGINAL_SOURCE = $(WORKSPACE)/certirocq/CertiCoqBinomOriginal.v

IMPL_DIR = $(BUILD)/impl-adjusted
IMPL_MYNAT_DIR = $(BUILD)/impl-mynat
CERTI_ADJUSTED_DIR = $(BUILD)/certirocq-adjusted
CERTI_MYNAT_DIR = $(BUILD)/certirocq-mynat
CERTI_ORIGINAL_DIR = $(BUILD)/certirocq-original

IMPL_BIN = $(IMPL_DIR)/impl-adjusted
IMPL_MYNAT_BIN = $(IMPL_MYNAT_DIR)/impl-mynat
CERTI_ADJUSTED_BIN = $(CERTI_ADJUSTED_DIR)/certirocq-adjusted
CERTI_ADJUSTED_O0_BIN = $(CERTI_ADJUSTED_DIR)/certirocq-adjusted-o0
CERTI_ADJUSTED_O1_BIN = $(CERTI_ADJUSTED_DIR)/certirocq-adjusted-o1
CERTI_ADJUSTED_O3_BIN = $(CERTI_ADJUSTED_DIR)/certirocq-adjusted-o3
CERTI_MYNAT_BIN = $(CERTI_MYNAT_DIR)/certirocq-mynat
CERTI_MYNAT_O0_BIN = $(CERTI_MYNAT_DIR)/certirocq-mynat-o0
CERTI_MYNAT_O1_BIN = $(CERTI_MYNAT_DIR)/certirocq-mynat-o1
CERTI_MYNAT_O3_BIN = $(CERTI_MYNAT_DIR)/certirocq-mynat-o3
CERTI_ORIGINAL_BIN = $(CERTI_ORIGINAL_DIR)/certirocq-original
CERTI_ORIGINAL_O0_BIN = $(CERTI_ORIGINAL_DIR)/certirocq-original-o0
CERTI_ORIGINAL_O1_BIN = $(CERTI_ORIGINAL_DIR)/certirocq-original-o1
CERTI_ORIGINAL_O3_BIN = $(CERTI_ORIGINAL_DIR)/certirocq-original-o3

CERTIROCQ_CFLAGS = -w -Wno-everything

.PHONY: all check benchmark clean project

all: check

check: $(IMPL_BIN) $(CERTI_ADJUSTED_BIN) $(CERTI_ORIGINAL_BIN) \
		$(IMPL_MYNAT_BIN) $(CERTI_MYNAT_BIN) \
		$(CERTI_ADJUSTED_O0_BIN) $(CERTI_ADJUSTED_O1_BIN) $(CERTI_ADJUSTED_O3_BIN) \
		$(CERTI_MYNAT_O0_BIN) $(CERTI_MYNAT_O1_BIN) $(CERTI_MYNAT_O3_BIN) \
		$(CERTI_ORIGINAL_O0_BIN) $(CERTI_ORIGINAL_O1_BIN) $(CERTI_ORIGINAL_O3_BIN)
	ulimit -s 1048576; output="$$($(IMPL_BIN))" && test -z "$$output"
	output="$$($(CERTI_ADJUSTED_O0_BIN))" && test -z "$$output"
	output="$$($(CERTI_ADJUSTED_O1_BIN))" && test -z "$$output"
	output="$$($(CERTI_ADJUSTED_BIN))" && test -z "$$output"
	output="$$($(CERTI_ADJUSTED_O3_BIN))" && test -z "$$output"
	ulimit -s 1048576; output="$$($(IMPL_MYNAT_BIN))" && test -z "$$output"
	output="$$($(CERTI_MYNAT_O0_BIN))" && test -z "$$output"
	output="$$($(CERTI_MYNAT_O1_BIN))" && test -z "$$output"
	output="$$($(CERTI_MYNAT_BIN))" && test -z "$$output"
	output="$$($(CERTI_MYNAT_O3_BIN))" && test -z "$$output"
	output="$$($(CERTI_ORIGINAL_O0_BIN))" && test -z "$$output"
	output="$$($(CERTI_ORIGINAL_O1_BIN))" && test -z "$$output"
	output="$$($(CERTI_ORIGINAL_BIN))" && test -z "$$output"
	output="$$($(CERTI_ORIGINAL_O3_BIN))" && test -z "$$output"

benchmark: check
	bash ./run_benchmarks.sh

project:
	cd $(ROOT)/rocq && \
		opam exec --switch=$(PROJECT_SWITCH) -- \
		dune build \
			functional/FunSyntax.vo \
			functional/FunValues.vo \
			functional/FunSemantics.vo \
			functional/FunProperties.vo \
			imperative/ImpSyntax.vo \
			automation/AutomationLemmas.vo \
			automation/Ltac2Utils.vo \
			automation/RelCompiler.vo \
			automation/RelCompilerCommons.vo \
			automation/ToANF.vo \
			automation/ToLowerable.vo \
			automation/ltac2/UnfoldFix.vo \
			commons/CompilerUtils.vo \
			fp2imp/FpToImpCodegen.vo \
			utils/Core.vo

$(IMPL_DIR) $(IMPL_MYNAT_DIR) $(CERTI_ADJUSTED_DIR) $(CERTI_MYNAT_DIR) \
		$(CERTI_ORIGINAL_DIR):
	mkdir -p $@

$(IMPL_DIR)/AdjustedBinomialHeap.vo: $(SHARED_SOURCE) | $(IMPL_DIR)
	cd $(IMPL_DIR) && \
		$(PROJECT_ROCQ) compile -q -noglob -o AdjustedBinomialHeap.vo \
		$(SHARED_SOURCE)

$(IMPL_DIR)/ReifyAdjusted.vo: $(IMPL_REIFY) $(IMPL_DIR)/AdjustedBinomialHeap.vo | project
	cd $(IMPL_DIR) && \
		$(PROJECT_ROCQ) compile -q -R $(IMPBOOT_BUILD) impboot \
		-noglob -o ReifyAdjusted.vo $(IMPL_REIFY)

$(IMPL_DIR)/program.out: $(IMPL_PROGRAM) $(IMPL_DIR)/ReifyAdjusted.vo
	cd $(IMPL_DIR) && \
		$(PROJECT_ROCQ) compile -q -R $(IMPBOOT_BUILD) impboot \
		-noglob -o Program.vo $(IMPL_PROGRAM) > program.out

$(IMPL_DIR)/program.s: $(IMPL_DIR)/program.out $(DECODER)
	python3 $(DECODER) $< $@

$(IMPL_DIR)/program.o: $(IMPL_DIR)/program.s
	gcc -c $< -o $@

$(IMPL_BIN): $(IMPL_DIR)/program.o
	gcc -no-pie $< -o $@

$(IMPL_MYNAT_DIR)/MyNatBinomialHeap.vo: $(MYNAT_SOURCE) | $(IMPL_MYNAT_DIR)
	cd $(IMPL_MYNAT_DIR) && \
		$(PROJECT_ROCQ) compile -q -noglob -o MyNatBinomialHeap.vo \
		$(MYNAT_SOURCE)

$(IMPL_MYNAT_DIR)/ReifyMyNat.vo: $(IMPL_MYNAT_REIFY) $(IMPL_MYNAT_DIR)/MyNatBinomialHeap.vo | project
	cd $(IMPL_MYNAT_DIR) && \
		$(PROJECT_ROCQ) compile -q -R $(IMPBOOT_BUILD) impboot \
		-noglob -o ReifyMyNat.vo $(IMPL_MYNAT_REIFY)

$(IMPL_MYNAT_DIR)/program.out: $(IMPL_MYNAT_PROGRAM) $(IMPL_MYNAT_DIR)/ReifyMyNat.vo
	cd $(IMPL_MYNAT_DIR) && \
		$(PROJECT_ROCQ) compile -q -R $(IMPBOOT_BUILD) impboot \
		-noglob -o ProgramMyNat.vo $(IMPL_MYNAT_PROGRAM) > program.out

$(IMPL_MYNAT_DIR)/program.s: $(IMPL_MYNAT_DIR)/program.out $(DECODER)
	python3 $(DECODER) $< $@

$(IMPL_MYNAT_DIR)/program.o: $(IMPL_MYNAT_DIR)/program.s
	gcc -c $< -o $@

$(IMPL_MYNAT_BIN): $(IMPL_MYNAT_DIR)/program.o
	gcc -no-pie $< -o $@

$(CERTI_ADJUSTED_DIR)/AdjustedBinomialHeap.vo: $(SHARED_SOURCE) | $(CERTI_ADJUSTED_DIR)
	cd $(CERTI_ADJUSTED_DIR) && \
		$(CERTIROCQ) compile -q -noglob -o AdjustedBinomialHeap.vo \
		$(SHARED_SOURCE)

$(CERTI_ADJUSTED_DIR)/.generated: $(CERTI_ADJUSTED_DRIVER) $(CERTI_ADJUSTED_DIR)/AdjustedBinomialHeap.vo
	cd $(CERTI_ADJUSTED_DIR) && \
		$(CERTIROCQ) compile -q -noglob -o CompileAdjusted.vo \
		$(CERTI_ADJUSTED_DRIVER)
	test -f $(CERTI_ADJUSTED_DIR)/AdjustedBinomialHeap.benchmark_main_default.c
	touch $@

$(CERTI_ADJUSTED_BIN): $(CERTI_ADJUSTED_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O2 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ADJUSTED_DIR)/AdjustedBinomialHeap.benchmark_main_default.c

$(CERTI_ADJUSTED_O0_BIN): $(CERTI_ADJUSTED_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O0 \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ADJUSTED_DIR)/AdjustedBinomialHeap.benchmark_main_default.c

$(CERTI_ADJUSTED_O1_BIN): $(CERTI_ADJUSTED_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O1 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ADJUSTED_DIR)/AdjustedBinomialHeap.benchmark_main_default.c

$(CERTI_ADJUSTED_O3_BIN): $(CERTI_ADJUSTED_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O3 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ADJUSTED_DIR)/AdjustedBinomialHeap.benchmark_main_default.c

$(CERTI_MYNAT_DIR)/MyNatBinomialHeap.vo: $(MYNAT_SOURCE) | $(CERTI_MYNAT_DIR)
	cd $(CERTI_MYNAT_DIR) && \
		$(CERTIROCQ) compile -q -noglob -o MyNatBinomialHeap.vo \
		$(MYNAT_SOURCE)

$(CERTI_MYNAT_DIR)/.generated: $(CERTI_MYNAT_DRIVER) $(CERTI_MYNAT_DIR)/MyNatBinomialHeap.vo
	cd $(CERTI_MYNAT_DIR) && \
		$(CERTIROCQ) compile -q -noglob -o CompileMyNat.vo \
		$(CERTI_MYNAT_DRIVER)
	test -f $(CERTI_MYNAT_DIR)/MyNatBinomialHeap.benchmark_main_default.c
	touch $@

$(CERTI_MYNAT_BIN): $(CERTI_MYNAT_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O2 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_MYNAT_DIR)/MyNatBinomialHeap.benchmark_main_default.c

$(CERTI_MYNAT_O0_BIN): $(CERTI_MYNAT_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O0 \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_MYNAT_DIR)/MyNatBinomialHeap.benchmark_main_default.c

$(CERTI_MYNAT_O1_BIN): $(CERTI_MYNAT_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O1 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_MYNAT_DIR)/MyNatBinomialHeap.benchmark_main_default.c

$(CERTI_MYNAT_O3_BIN): $(CERTI_MYNAT_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O3 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_MYNAT_DIR)/MyNatBinomialHeap.benchmark_main_default.c

$(CERTI_ORIGINAL_DIR)/CertiCoqBinomOriginal.vo: $(ORIGINAL_SOURCE) | $(CERTI_ORIGINAL_DIR)
	cd $(CERTI_ORIGINAL_DIR) && \
		$(CERTIROCQ) compile -q -noglob -o CertiCoqBinomOriginal.vo \
		$(ORIGINAL_SOURCE)

$(CERTI_ORIGINAL_DIR)/.generated: $(CERTI_ORIGINAL_DRIVER) $(CERTI_ORIGINAL_DIR)/CertiCoqBinomOriginal.vo
	cd $(CERTI_ORIGINAL_DIR) && \
		$(CERTIROCQ) compile -q -noglob -o CompileOriginal.vo \
		$(CERTI_ORIGINAL_DRIVER)
	test -f $(CERTI_ORIGINAL_DIR)/CertiCoqBinomOriginal.main_default.c
	touch $@

$(CERTI_ORIGINAL_BIN): $(CERTI_ORIGINAL_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O2 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ORIGINAL_DIR)/CertiCoqBinomOriginal.main_default.c

$(CERTI_ORIGINAL_O0_BIN): $(CERTI_ORIGINAL_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O0 \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ORIGINAL_DIR)/CertiCoqBinomOriginal.main_default.c

$(CERTI_ORIGINAL_O1_BIN): $(CERTI_ORIGINAL_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O1 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ORIGINAL_DIR)/CertiCoqBinomOriginal.main_default.c

$(CERTI_ORIGINAL_O3_BIN): $(CERTI_ORIGINAL_DIR)/.generated $(CERTI_MAIN)
	clang $(CERTIROCQ_CFLAGS) -O3 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ORIGINAL_DIR)/CertiCoqBinomOriginal.main_default.c

clean:
	rm -rf $(BUILD)
