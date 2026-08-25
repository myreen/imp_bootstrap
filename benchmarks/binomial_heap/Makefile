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
IMPL_REIFY = $(WORKSPACE)/impl/ReifyAdjusted.v
IMPL_PROGRAM = $(WORKSPACE)/impl/Program.v
DECODER = $(WORKSPACE)/impl/decode_assembly.py
CERTI_ADJUSTED_DRIVER = $(WORKSPACE)/certirocq/CompileAdjusted.v
CERTI_ORIGINAL_DRIVER = $(WORKSPACE)/certirocq/CompileOriginal.v
CERTI_MAIN = $(WORKSPACE)/certirocq/no_output_main.c
ORIGINAL_SOURCE = $(WORKSPACE)/certirocq/CertiCoqBinomOriginal.v

IMPL_DIR = $(BUILD)/impl-adjusted
CERTI_ADJUSTED_DIR = $(BUILD)/certirocq-adjusted
CERTI_ORIGINAL_DIR = $(BUILD)/certirocq-original

IMPL_BIN = $(IMPL_DIR)/impl-adjusted
CERTI_ADJUSTED_BIN = $(CERTI_ADJUSTED_DIR)/certirocq-adjusted
CERTI_ORIGINAL_BIN = $(CERTI_ORIGINAL_DIR)/certirocq-original

.PHONY: all check benchmark clean project

all: check

check: $(IMPL_BIN) $(CERTI_ADJUSTED_BIN) $(CERTI_ORIGINAL_BIN)
	ulimit -s 1048576; test -z "$$($(IMPL_BIN))"
	test -z "$$($(CERTI_ADJUSTED_BIN))"
	test -z "$$($(CERTI_ORIGINAL_BIN))"

benchmark: check
	bash ./run_benchmarks.sh

project:
	cd $(ROOT)/rocq && \
		opam exec --switch=$(PROJECT_SWITCH) -- \
		dune build binomial_heap/BinomialHeap.vo

$(IMPL_DIR) $(CERTI_ADJUSTED_DIR) $(CERTI_ORIGINAL_DIR):
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
	clang -w -Wno-everything -O2 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ADJUSTED_DIR)/AdjustedBinomialHeap.benchmark_main_default.c

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
	clang -w -Wno-everything -O2 -fomit-frame-pointer \
		-I$(CERTIROCQ_RUNTIME) -o $@ $(CERTI_MAIN) \
		$(CERTIROCQ_RUNTIME)/gc_stack.c \
		$(CERTI_ORIGINAL_DIR)/CertiCoqBinomOriginal.main_default.c

clean:
	rm -rf $(BUILD)
