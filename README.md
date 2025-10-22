# 随机游走模拟优化考核

## 考核简介

随机游走模型常在计算机领域用于研究系统动态，随着问题规模增大，如何提升模拟效率成为突破计算优化的关键。

本考核要求在 Ubuntu 22.04 环境下，对 L×L 网格上 N 个粒子进行 T 步随机游走模拟（L=512，N=100000，T=1000）。粒子随机选方向、允许多粒子同格、网格采用周期性边界。需用纯 Python 实现串行基线，并通过不限手段优化，缩短运行时间。最终输出粒子在中心区域平均停留比例与模拟时间，可视化可加分，考查并行计算与优化能力。

## 考核目标

本考核要求您在虚拟机中安装 Ubuntu 22.04 并配置，在 L×L 网格上模拟 N 个相互独立的粒子进行 T 步随机游走，统计所有粒子在中心区域的平均停留比例，并优化模拟速度。

## 考核题流程

### 1. 安装虚拟机
- 安装 Ubuntu 22.04 LTS
- 配置网络连接

### 2. 配置编程环境
- 选择合适版本的Python解释器（要求Python 3.8+）
- 安装必要的开发工具

#![简洁版]

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
python3 main.py 512 100000 1000
```

运行 NumPy 实现：

```bash
cd ../Python_NumPy
python3 main.py 512 100000 1000
```

在支持 GPU 且已安装 CuPy 的环境下运行 CuPy 版本：

```bash
cd ../Python_CuPy
python3 main.py 512 100000 1000
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
make -j
# 运行可执行文件（名称视具体实现而定）
./C_baseline
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

示例：

```bash
python3 main.py <L> <N> <T>
```

## 可视化

若实现包含可视化（依赖 Matplotlib 等），程序会将热力图保存到文件或显示窗口，具体见对应 `main.py` 中的注释。

## 开发建议与贡献规则

- 提交代码前请确保通过基本的正确性测试（小规模参数）。
- 新增依赖请更新 `requirements.txt`。
- 提交 PR 时请在描述中包含性能测试复现步骤与结果摘要。

## 测试建议（小规模验证）

- 在 N=100、T=10 或更小的参数下先行测试正确性。
- 对比不同实现时，记录运行时间与 dwell ratio，注意随机性引入的波动。

## 许可证

本项目采用 MIT 许可证（见 `LICENSE`）。

## 我可以帮你做的下一步（可选）

- 把 README 调整为学术风格的实验报告模板（包含实验结果表格与图示）。
- 为 `src/Python_NumPy/main.py` 或其它实现生成更详细的使用说明与示例输出。 
- 添加 CI / 自动化脚本来运行 speedtests 并生成对比报告。

如需我继续完善 README（例如添加运行示例的真实输出、插入图片引用或为某个实现写详细使用文档），告诉我优先级与偏好风格，我会继续修改。
