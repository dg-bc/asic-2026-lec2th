.DEFAULT_GOAL := run

VERILATOR ?= verilator
IVERILOG  ?= iverilog
VVP       ?= vvp
GTKWAVE   ?= gtkwave
JOBS      ?= 4
SRCS      := tb.v regfile_256x8.v rtl/rw_fsm.v
FLAGS     := --timing --assert -Wall --top-module tb

export CCACHE_DIR ?= $(abspath build/.ccache)

.PHONY: run build sim sim-iverilog wave lint check clean

run: sim
	@$(MAKE) --no-print-directory wave

build:
	@mkdir -p build
	+$(VERILATOR) --binary --trace $(FLAGS) -j $(JOBS) --Mdir build -o sim $(SRCS)

sim: build
	./build/sim

sim-iverilog:
	@mkdir -p build
	$(IVERILOG) -g2012 -Wall -s tb -o build/sim_iverilog $(SRCS)
	$(VVP) build/sim_iverilog

wave:
	@test -s build/wave.vcd || { echo "请先运行 make sim"; exit 1; }
	@if [ -z "$$DISPLAY" ] && [ -S /tmp/.X11-unix/X0 ]; then \
		export DISPLAY=:0; \
	fi; \
	$(GTKWAVE) build/wave.vcd tb.gtkw

lint:
	$(VERILATOR) --lint-only $(FLAGS) $(SRCS)

# 顺序运行，避免同时覆盖输出 hex 和波形。
check:
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory sim-iverilog
	@$(MAKE) --no-print-directory sim

clean:
	rm -rf build
