# 随机游走性能优化与实现（RandomWalkModel）

本仓库包含一套用于模拟 L×L 网格上 N 个粒子进行随机游走（Random Walk）的参考实现与若干优化变体。项目的目标是：在给定参数下保证正确性，同时尽可能缩短模拟时间。仓库中包含纯 Python 基线、NumPy/CuPy 向量化版本，以及若干用 C / 汇编 实现的变体，便于对比不同优化策略的性能和工程实现要点。

## 主要内容

- 多语言实现：纯 Python（基线）、NumPy/CuPy（向量化 / GPU）、C 与汇编（高性能实现）。
- 使用 CMake 管理 C 代码的构建（见 `src/C/`、`src/C_ASM/` 等子目录）。
- 包含复现实验所需的速度测试脚本（`tests/speedtests/`）和多线程测试示例。
- 附带实验报告（`report/`）和 LaTeX 源文件，便于复现与提交。

## 仓库概览

- `src/`
    - `C/`, `C_ASM/`, `C_ASM_SIMD/`, `C_ASM_SIMD_MULTI_THREAD/`：C / 汇编 实现与 CMake 构建
    - `Python_baseline/`：纯 Python 串行基线（`main.py`）
    - `Python_NumPy/`：NumPy 向量化实现（`main.py`）
    - `Python_CuPy/`：CuPy GPU 加速实现（`main.py`）
- `tests/`
    - `speedtests/`：性能对比脚本
    - `multi_thread/`, `multi_thread_cpu/`：线程/多进程示例
- `report/`：实验报告（LaTeX 源、编译文件）
- `requirements.txt`：Python 依赖
- `LICENSE`：MIT 许可证

## 如何运行（Python）

推荐在虚拟环境中运行并安装依赖：

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

运行基线示例：

```bash
cd src/Python_baseline
python3 main.py
```

运行 NumPy 实现：

```bash
cd ../Python_NumPy
python3 main.py
```

在支持 GPU 且已安装 CuPy 的环境下运行 CuPy 版本：

```bash
cd ../Python_CuPy
python3 main.py
```

运行后程序通常打印：

```
Average dwell ratio: 0.25xxx
Simulation time: 2.34s
```

说明：dwell ratio = 粒子在中心区域的总停留步数 / (N × T)。

## 如何构建（C / CMake）

以 `src/C/` 为例：

```bash
cd src/C
mkdir -p build && cd build
cmake ..
make
# 运行可执行文件（名称视具体实现而定）
./C_baseline.out
```

每个 C 子目录包含 `CMakeLists.txt` 和对应的源文件，请查看具体实现以获得参数说明。

## 性能复现

使用仓库内的性能测试脚本：

```bash
python3 tests/speedtests/test.py
```

建议：每次测试前清理 C 的 build 目录，并在干净的虚拟环境下运行 Python 测试以保证可重复性。

## 参数说明

- L：网格边长（示例 512）
- N：粒子数量（示例 100000）
- T：模拟步数（示例 1000）

## 许可证

本项目采用 MIT 许可证（见 `LICENSE`）。
