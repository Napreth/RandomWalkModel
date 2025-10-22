#!/usr/bin/env python3
import subprocess
import threading
import statistics
import time
import sys

# ===============================
# 配置区
# ===============================
THREADS = [i for i in range(1, 25)]
REPEATS = 10000
EXECUTABLE = "./simulate.out"
DAT_CPU = "cpu_usage.dat"
SAMPLE_INTERVAL = 0.10   # 建议 0.05~0.10；更小更密集但I/O更多
WARMUP_MS = 120          # PerformanceCounter 第一次读通常为0，预热等待

# 编译配置（你的保持不变）
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

# 使用 .NET 性能计数器的持久 PowerShell（极快）
PS_INLINE = r"""
$pc = New-Object System.Diagnostics.PerformanceCounter('Processor','% Processor Time','_Total')
# 预热：第一次几乎必为0，先等待再取一次
$null = $pc.NextValue()
Start-Sleep -Milliseconds """ + str(WARMUP_MS) + r"""
$in  = [Console]::In
$out = [Console]::Out
while ($true) {
    $line = $in.ReadLine()
    if ($null -eq $line) { break }
    $v = $pc.NextValue()
    $out.WriteLine([math]::Round($v,6))
    $out.Flush()
}
"""

# ===============================
# PowerShell 采样器（常驻）
# ===============================
class HostCpuSampler:
    def __init__(self, interval=0.1):
        self.interval = interval
        self.proc = subprocess.Popen(
            ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", PS_INLINE],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, text=True, bufsize=1
        )
        self.samples = []           # 只在 active 阶段追加
        self.lock = threading.Lock()
        self.active = threading.Event()
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self._loop, daemon=True)
        self.thread.start()

        # 启动自检：尝试拿一个样本（最多等待 1s）
        if not self._probe_ready(timeout=1.0):
            print("\n⚠️  警告：PowerShell 采样器启动失败或无响应（检查 powershell.exe 是否可用）", file=sys.stderr)

    def _probe_ready(self, timeout=1.0):
        t0 = time.time()
        # 临时拉起一次 active，尝试得到至少一个样本
        self.active.set()
        ok = False
        while time.time() - t0 < timeout:
            v = self._take_one()
            if v is not None:
                with self.lock:
                    self.samples.append(v)
                ok = True
                break
            time.sleep(0.05)
        self.active.clear()
        return ok

    def _take_one(self):
        try:
            self.proc.stdin.write("\n")
            self.proc.stdin.flush()
            line = self.proc.stdout.readline()
            if not line:
                return None
            # 处理可能的逗号小数（取决于地区设置）
            s = line.strip().replace(',', '.')
            return float(s)
        except Exception:
            return None

    def _loop(self):
        while not self.stop.is_set():
            if self.active.is_set():
                v = self._take_one()
                if v is not None:
                    with self.lock:
                        self.samples.append(v)
                time.sleep(self.interval)
            else:
                time.sleep(0.02)

    def mark_active(self, is_active: bool):
        self.active.set() if is_active else self.active.clear()

    def snapshot_len(self):
        with self.lock:
            return len(self.samples)

    def slice_avg(self, start_idx, end_idx=None):
        with self.lock:
            arr = self.samples[start_idx:end_idx]
        return statistics.mean(arr) if arr else None

    def latest(self):
        with self.lock:
            return self.samples[-1] if self.samples else None

    def close(self):
        self.stop.set()
        try:
            self.proc.stdin.close()
        except Exception:
            pass
        self.thread.join(timeout=1.0)
        try:
            self.proc.terminate()
        except Exception:
            pass

# ===============================
# 其他函数
# ===============================
def compile_program(thread_num):
    cmd = GCC + SRC + PARAMS + [f"-DTHREAD_NUM={thread_num}", "-o", EXECUTABLE]
    print(f"\n[BUILD] THREAD_NUM={thread_num}")
    subprocess.run(cmd, check=True)

def clear_line():
    # 清空当前行并回到行首（单行刷新）
    sys.stdout.write("\r\x1b[2K")

def run_once_quiet():
    subprocess.run([EXECUTABLE], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# ===============================
# 主逻辑
# ===============================
def main():
    sampler = HostCpuSampler(interval=SAMPLE_INTERVAL)
    results = []

    try:
        for t in THREADS:
            compile_program(t)
            print(f"[RUN] THREAD_NUM={t}, repeat={REPEATS}")

            # 开始该线程组采样
            sampler.mark_active(True)
            start_idx = sampler.snapshot_len()
            start_time = time.time()

            for i in range(1, REPEATS + 1):
                run_once_quiet()

                # 实时刷新状态（安全处理 None）
                latest = sampler.latest()
                cur_len = max(0, sampler.snapshot_len() - start_idx)
                cur_avg = sampler.slice_avg(start_idx)

                latest_str = f"{latest:6.2f}%" if isinstance(latest, (int, float)) else "  --  %"
                avg_str    = f"{cur_avg:6.2f}%" if isinstance(cur_avg, (int, float)) else "  --  %"

                clear_line()
                sys.stdout.write(
                    f"  Run {i}/{REPEATS} | samples={cur_len:4d} | "
                    f"latest={latest_str} | avg={avg_str} | elapsed={time.time()-start_time:6.1f}s"
                )
                sys.stdout.flush()

            # 结束该线程组采样
            end_idx = sampler.snapshot_len()
            sampler.mark_active(False)
            final_avg = sampler.slice_avg(start_idx, end_idx)
            final_avg_str = f"{final_avg:.2f}%" if isinstance(final_avg, (int, float)) else "--"

            clear_line()
            print(f"→ THREAD_NUM={t:2d} 平均CPU占用 = {final_avg_str} | samples={end_idx-start_idx} | total={time.time()-start_time:.1f}s")
            results.append((t, final_avg))

        # 写文件（None 用空着）
        with open(DAT_CPU, "w") as f:
            for t, avg_cpu in results:
                if isinstance(avg_cpu, (int, float)):
                    f.write(f"{t} {avg_cpu:.2f}\n")

        print(f"\n✅ 已保存CPU占用数据到 {DAT_CPU}")
        print("全部完成！")

    finally:
        sampler.close()

if __name__ == "__main__":
    main()
