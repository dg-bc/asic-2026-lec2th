.DEFAULT_GOAL := run

VERILATOR ?= verilator
GTKWAVE   ?= gtkwave
TOP       ?= tb
SRCS      ?= tb.v $(wildcard rtl/*.v rtl/*.sv)
JOBS      ?= 4
VFLAGS    ?=
ARGS      ?=

BUILD_DIR := build
WAVE      := $(BUILD_DIR)/wave.vcd
FLAGS     := --timing --assert -Wall -Wno-fatal --top-module $(TOP)

# 编译缓存也留在项目内，make clean 一并清理。
export CCACHE_DIR ?= $(abspath $(BUILD_DIR)/.ccache)

.PHONY: run build sim wave lint clean help

# 用依赖和递归 make 保证 make -j run 也是先仿真、再打开波形。
run: sim
	@$(MAKE) --no-print-directory wave

# 每次交给 Verilator 检查依赖；未修改的生成文件和 C++ 对象会复用。
build:
	@mkdir -p $(BUILD_DIR)
	+$(VERILATOR) --binary --trace $(FLAGS) $(VFLAGS) \
		-j $(JOBS) --Mdir $(BUILD_DIR) -o sim $(SRCS)

sim: build
	./$(BUILD_DIR)/sim $(ARGS)

wave:
	@test -s "$(WAVE)" || { echo "找不到 $(WAVE)，请先运行 make sim"; exit 1; }
	@command -v "$(GTKWAVE)" >/dev/null || { echo "找不到 GTKWave：$(GTKWAVE)"; exit 1; }
	@printf 'do_initial_zoom_fit 1\n' > "$(BUILD_DIR)/gtkwaverc"
	@if [ -z "$$DISPLAY" ] && [ -S /tmp/.X11-unix/X0 ]; then \
		export DISPLAY=:0; \
	fi; \
	$(GTKWAVE) --rcfile "$(BUILD_DIR)/gtkwaverc" "$(WAVE)" tb.gtkw

lint:
	$(VERILATOR) --lint-only $(FLAGS) $(VFLAGS) $(SRCS)

clean:
	rm -rf $(BUILD_DIR)

help:
	@echo "make run    编译、仿真，再打开 GTKWave（默认目标）"
	@echo "make sim    编译、仿真，生成 build/wave.vcd"
	@echo "make build  只编译"
	@echo "make wave   打开已有波形，关闭窗口后命令返回"
	@echo "make lint   检查 Verilog/SystemVerilog"
	@echo "make clean  删除 build/"
