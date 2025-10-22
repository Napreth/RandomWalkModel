#!/usr/bin/env python3
import subprocess
import re
import statistics

# ===============================
# 配置区
# ===============================
THREADS = [i for i in range(1, 25)]  # 测试的线程数
REPEATS = 10000                             # 每个线程重复次数
EXECUTABLE = "./simulate.out"               # 编译后可执行文件名
DAT_RUNTIME = "runtime.dat"
DAT_EFFICIENCY = "efficiency.dat"

# 编译参数
GCC = ["gcc"]
SRC = ["main.c", "gen_rand_arr.s", "simulate.s"]
PARAMS = [
    "-O3", "-Ofast", "-flto",
    "-march=native", "-mtune=native",
    "-funroll-loops", "-fomit-frame-pointer",
    "-ffast-math", "-fno-math-errno", "-fno-trapping-math",
    "-fno-stack-protector", "-falign-functions=32", "-falign-loops=32",
    "-ftree-vectorize", "-funsafe-math-optimizations",
    "-fno-plt", "-fno-semantic-interposition",
    "-fopenmp"
]
TIME_PATTERN = re.compile(r"Simulation\s+time:\s*([\d.]+)s?")

# ===============================
# 函数定义
# ===============================
def compile_program(thread_num):
    cmd = GCC + SRC + PARAMS + [f"-DTHREAD_NUM={thread_num}", "-o", EXECUTABLE]
    print(f"\n[BUILD] THREAD_NUM={thread_num}")
    subprocess.run(cmd, check=True)

def run_once():
    """运行一次程序并提取运行时间"""
    result = subprocess.run([EXECUTABLE], capture_output=True, text=True)
    match = TIME_PATTERN.search(result.stdout)
    if match:
        return float(match.group(1))
    return None

# ===============================
# 主逻辑
# ===============================
def main():
    results = []  # [(thread_num, avg_time)]

    for t in THREADS:
        compile_program(t)
        times = []
        print(f"[RUN] THREAD_NUM={t}, repeat={REPEATS}")
        for i in range(REPEATS):
            tval = run_once()
            if tval is not None:
                times.append(tval * 100)
                print(f"  Run {i+1}/{REPEATS}: {tval:.6f}s")
            else:
                print("  Run failed.")

        if times:
            avg_time = statistics.mean(times)
            results.append((t, avg_time))
            print(f"→ Avg time = {avg_time:.6f} ×10²s")
        else:
            results.append((t, None))

    # ==========================
    # 写入运行时间文件
    # ==========================
    with open(DAT_RUNTIME, "w") as f:
        for t, avg_time in results:
            if avg_time is not None:
                f.write(f"{t} {avg_time:.6f}\n")
    print(f"\n✅ 已保存运行时间数据到 {DAT_RUNTIME}")

    # ==========================
    # 计算效率并写入
    # ==========================
    if results and results[0][1] is not None:
        base_time = results[0][1]
        with open(DAT_EFFICIENCY, "w") as f:
            for t, avg_time in results:
                if avg_time is not None:
                    eff = base_time / (t * avg_time) * 100
                    f.write(f"{t} {eff:.6f}\n")
        print(f"✅ 已保存效率数据到 {DAT_EFFICIENCY}")
    else:
        print("⚠️ 无法计算效率（缺少单线程基准）")

    print("\n全部完成！")

if __name__ == "__main__":
    main()
