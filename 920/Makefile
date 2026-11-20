.DEFAULT_GOAL := run

VERILATOR ?= verilator
IVERILOG  ?= iverilog
VVP       ?= vvp
GTKWAVE   ?= gtkwave
DOT       ?= dot
JOBS      ?= 4
SRCS      := tb.v rtl/traffic_light.v
FLAGS     := --timing --assert -Wall --top-module tb

export CCACHE_DIR ?= $(abspath build/.ccache)

.PHONY: run build sim sim-iverilog wave lint check diagram clean

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
	$(GTKWAVE) --rcfile gtkwaverc build/wave.vcd tb.gtkw

lint:
	$(VERILATOR) --lint-only $(FLAGS) $(SRCS)

# 顺序执行，避免两个仿真器同时写入波形。
check:
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory sim-iverilog
	@$(MAKE) --no-print-directory sim

diagram: state_diagram.svg

state_diagram.svg: state_diagram.dot
	$(DOT) -Tsvg $< -o $@

clean:
	rm -rf build
