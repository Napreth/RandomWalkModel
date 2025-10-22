import subprocess
import csv
import re

# ===============================
# 配置区：要测试的程序
# ===============================
CONFIG = [
    {"name": "Python baseline", "cmd": ["python3", "Python_baseline.py"], "repeat": 10},
    {"name": "Python NumPy", "cmd": ["python3", "Python_NumPy.py"], "repeat": 1000},
    {"name": "Python CuPy", "cmd": ["python3", "Python_CuPy.py"], "repeat": 1000},
    {"name": "C baseline", "cmd": ["./C_baseline"], "repeat": 1000},
    {"name": "C ASM", "cmd": ["./C_ASM"], "repeat": 1000},
    {"name": "C ASM SIMD", "cmd": ["./C_ASM_SIMD"], "repeat": 1000},
    {"name": "C ASM SIMD 24 Thread", "cmd": ["./C_ASM_SIMD_MULTI_THREAD"], "repeat": 1000},
]

OUTPUT_DAT = "speeds.dat"

# ===============================
# 正则匹配规则
# ===============================
ratio_pattern = re.compile(r"Average\s+dwell\s+ratio:\s*([\d.]+)")
time_pattern = re.compile(r"Simulation\s+time:\s*([\d.]+)s?")

# ===============================
# 核心执行逻辑
# ===============================
def run_once(cmd):
    """执行单次程序并返回 (ratio, sim_time)"""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        out = result.stdout
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Command failed: {' '.join(cmd)}")
        print(e.stdout)
        print(e.stderr)
        return None, None

    ratio_match = ratio_pattern.search(out)
    time_match = time_pattern.search(out)

    ratio = float(ratio_match.group(1)) if ratio_match else None
    sim_time = float(time_match.group(1)) if time_match else None
    return ratio, sim_time


def main():
    results = []
    print("=== Simulation Speed Test ===")

    for item in CONFIG:
        name = item["name"]
        cmd = item["cmd"]
        repeat = item["repeat"]
        print(f"\n▶ Running {name} ({repeat} times) ...")

        ratios, times = [], []
        for i in range(repeat):
            print(f"  Run {i+1}/{repeat}...", end=" ", flush=True)
            ratio, sim_time = run_once(cmd)
            if ratio is not None and sim_time is not None:
                print(f"done ({sim_time:.6f}s, ratio={ratio:.4f})")
                ratios.append(ratio)
                times.append(sim_time)
            else:
                print("failed.")

        if ratios and times:
            avg_ratio = sum(ratios) / len(ratios)
            avg_time = sum(times) / len(times)
        else:
            avg_ratio = avg_time = None

        results.append({
            "Name": name,
            "Repeats": repeat,
            "Avg_Dwell_Ratio": avg_ratio,
            "Avg_Sim_Time": avg_time
        })

    # ===============================
    # 计算加速倍数（以第一个为基准）
    # ===============================
    baseline_time = results[0]["Avg_Sim_Time"]
    for r in results:
        if r["Avg_Sim_Time"] and baseline_time:
            speedup = baseline_time / r["Avg_Sim_Time"]
            r["Speedup"] = speedup
        else:
            r["Speedup"] = None

    # ===============================
    # 输出为 .dat（空格分隔）
    # ===============================
    with open(OUTPUT_DAT, "w", encoding="utf-8") as f:
        for r in results:
            name = r["Name"]
            repeat = r["Repeats"]
            avg_ratio = f"{r['Avg_Dwell_Ratio']:.5f}" if r["Avg_Dwell_Ratio"] else ""
            avg_time = f"{r['Avg_Sim_Time']:.4f}" if r["Avg_Sim_Time"] else ""
            speed = f"{r['Speedup']:.2f}x" if r["Speedup"] else ""
            f.write(f"{name},{repeat},{avg_ratio},{avg_time},{speed}\n")


    print(f"\n✅ All done. Results saved to: {OUTPUT_DAT}")


if __name__ == "__main__":
    main()
