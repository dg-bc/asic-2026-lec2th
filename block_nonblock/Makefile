.DEFAULT_GOAL := run

VERILATOR ?= verilator
IVERILOG  ?= iverilog
VVP       ?= vvp
GTKWAVE   ?= gtkwave
JOBS      ?= 4

BUILD_DIR := build
FLAGS     := --timing --assert -Wall --top-module tb
export CCACHE_DIR ?= $(abspath $(BUILD_DIR)/.ccache)

.PHONY: run build sim sim-iverilog wave lint check clean

run: sim
	@$(MAKE) --no-print-directory wave

build:
	@mkdir -p $(BUILD_DIR)
	+$(VERILATOR) --binary --trace $(FLAGS) -j $(JOBS) --Mdir $(BUILD_DIR) -o sim tb.v

sim: build
	./$(BUILD_DIR)/sim

sim-iverilog:
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s tb -o $(BUILD_DIR)/sim_iverilog tb.v
	$(VVP) $(BUILD_DIR)/sim_iverilog

wave:
	@test -s $(BUILD_DIR)/wave.vcd || { echo "请先运行 make sim"; exit 1; }
	@if [ -z "$$DISPLAY" ] && [ -S /tmp/.X11-unix/X0 ]; then \
		export DISPLAY=:0; \
	fi; \
	$(GTKWAVE) --rcfile gtkwaverc $(BUILD_DIR)/wave.vcd tb.gtkw

lint:
	$(VERILATOR) --lint-only $(FLAGS) tb.v

# 两个仿真器顺序运行，避免同时写同一份波形。
check:
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory sim-iverilog
	@$(MAKE) --no-print-directory sim

clean:
	rm -rf $(BUILD_DIR)
