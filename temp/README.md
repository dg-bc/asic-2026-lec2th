# 最小 Verilator 仿真框架

在本目录执行：

```sh
make run
```

依次完成 Verilator 编译、运行 `tb.v`、生成 `build/wave.vcd`、打开 GTKWave。
GTKWave 会预先显示示例信号，关闭窗口后 `make run` 返回。直接执行 `make` 效果相同。

## 文件

```text
Makefile        编译、运行、打开波形
tb.v            仿真顶层：时钟、复位、激励、检查、波形导出
rtl/counter.v   可替换的示例 DUT
tb.gtkw         GTKWave 默认显示的信号
build/          自动生成的可执行文件、C++ 中间文件和波形
```

框架需要 Verilator 5.x、支持 C++20 的编译器、GNU Make 和 GTKWave。
使用 `--binary --timing --trace --assert`，由 Verilator 自动生成 C++ 入口，
可直接在 `tb.v` 中使用 `initial`、`always`、`#delay`、`@(posedge clk)` 和 `$finish`。

## 常用命令

```sh
make run     # 编译 + 仿真 + GTKWave
make sim     # 编译 + 仿真，适合终端或批量运行
make build   # 只编译
make wave    # 打开已经生成的波形
make lint    # 检查代码
make clean   # 删除生成文件
make help    # 显示命令
```

示例会检查复位、计数、溢出和使能保持，成功打印 `PASS`。
检查失败使用 `$fatal(1, ...)`，会使 Make 返回非零状态并停止后续步骤。
每次构建会让 Verilator 检查源文件、头文件和编译参数，复用无需重新生成的文件。

## 换成自己的设计

1. 把 RTL 放入 `rtl/`，自动收集这一层的 `*.v`、`*.sv`。
2. 修改 `tb.v` 中的 DUT 实例、激励和检查逻辑，保留波形导出代码和 `$finish`。
3. 执行 `make run`。

`tb.gtkw` 保存的是示例信号。换 DUT 后，在 GTKWave 中从左侧添加自己的信号，
用 **File → Write Save File** 保存到本目录的 `tb.gtkw`；后续运行会自动恢复。
时钟周期、仿真超时均在 `tb.v` 修改。

更多源文件、头文件目录、宏和仿真 plusargs 可以从命令行传入：

```sh
make run SRCS="tb.v rtl/top.sv rtl/submodule.v" VFLAGS="-Iinclude -DMY_DEFINE=1"
make sim ARGS="+SEED=123"
make build JOBS=8
```

`ARGS` 原样传给仿真程序；自定义 plusargs 需在 testbench 内用 `$value$plusargs`
或 `$test$plusargs` 读取。Verilator 的警告会显示，但默认不会阻止编译。

## WSL 图形显示

如果未设置 `DISPLAY`，但存在 WSLg 的 `/tmp/.X11-unix/X0`，`make wave`
会自动使用 `DISPLAY=:0`。GTKWave 打开失败时会直接显示错误，波形仍保存在
`build/wave.vcd`。无图形环境时可使用 `make sim`，之后在支持图形显示的终端
执行 `make wave`。
