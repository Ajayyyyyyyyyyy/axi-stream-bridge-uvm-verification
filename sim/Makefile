#===============================================================================
# StreamBridge UVM regression Makefile (Cadence Xcelium)
#
# This repo shows one complete completer-path vertical slice; the DUT
# top-level and its requester/DMA-path counterpart are omitted (see README),
# so this Makefile is illustrative of the real regression flow rather than
# directly runnable as-is.
#
# Usage:
#   make test TEST=test_cpl_write_readback
#   make regress
#   make clean
#===============================================================================

SIMULATOR   ?= xrun
UVM_HOME    ?= $(CDS_UVM_HOME)
TEST        ?= base_test
SEED        ?= random
VERBOSITY   ?= UVM_MEDIUM
WAVES       ?= 0

RTL_DIR     := ../src
IF_FILE     := $(RTL_DIR)/env/stream_bridge_if.sv
PKG_TOP     := $(RTL_DIR)/stream_bridge_pkg.sv

XRUN_OPTS   := -uvm -access +rwc -sv -timescale 1ns/1ps \
               -incdir $(RTL_DIR)/env -incdir $(RTL_DIR)/agents \
               -incdir $(RTL_DIR)/tests

LOG_DIR     := logs
RESULTS_DIR := results

.PHONY: all compile test regress clean waves help

all: test

$(LOG_DIR) $(RESULTS_DIR):
	mkdir -p $@

compile: | $(LOG_DIR)
	$(SIMULATOR) -compile $(XRUN_OPTS) $(IF_FILE) $(PKG_TOP) \
		-l $(LOG_DIR)/compile.log

test: | $(LOG_DIR) $(RESULTS_DIR)
	$(SIMULATOR) $(XRUN_OPTS) $(IF_FILE) $(PKG_TOP) \
		+UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERBOSITY) \
		$(if $(filter-out random,$(SEED)),-svseed $(SEED),-svseed random) \
		$(if $(filter 1,$(WAVES)),+WAVES,) \
		-l $(LOG_DIR)/$(TEST).log
	@echo "---- $(TEST) complete, see $(LOG_DIR)/$(TEST).log ----"

# Focused-test suite for the completer path shown in this repo.
REGRESSION_TESTS := test_cpl_write_readback

regress: | $(LOG_DIR) $(RESULTS_DIR)
	@for t in $(REGRESSION_TESTS); do \
		echo "==== running $$t ===="; \
		$(MAKE) test TEST=$$t SEED=$(SEED) VERBOSITY=$(VERBOSITY) || exit 1; \
	done
	@echo "==== regression complete: $(words $(REGRESSION_TESTS)) tests ===="

waves:
	$(MAKE) test WAVES=1

clean:
	rm -rf xcelium.d $(LOG_DIR) $(RESULTS_DIR) *.log *.history *.key \
	       INCA_libs *.shm waves.shm .simvision

help:
	@echo "Targets:"
	@echo "  make test TEST=<uvm_test_name> [SEED=<n>] [VERBOSITY=UVM_HIGH]"
	@echo "  make regress                     - run the full focused-test suite"
	@echo "  make waves TEST=<uvm_test_name>  - run with waveform capture enabled"
	@echo "  make clean                       - remove simulation artifacts"
