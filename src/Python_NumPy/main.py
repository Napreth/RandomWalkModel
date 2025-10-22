# 向量唯一不好的一点就是写出来全是注释，这个看起来还很正常
import numpy as np
import time

def get_direction(N, T):
    seed = np.random.randint(0, 4, size=(T, N), dtype=np.int8)
    x_direction = ((seed >> 1) & 1) * 2 - 1
    y_direction = (seed & 1) * 2 - 1
    mask = seed & 1
    return np.stack((x_direction * mask, y_direction * (1 - mask)), axis=2)

def simulate(L, N, T):
    particles = np.random.randint(0, L, size=(N, 2))
    L_is_power_of_two = (L & (L - 1)) == 0
    directions = get_direction(N, T)
    central = 0

    # 如果是 2 的整数次幂，使用位运算优化计算
    for t in range(T):
        if L_is_power_of_two:
            particles = (particles + directions[t]) & (L - 1)
        else:
            particles = (particles + directions[t]) % L

        # 计算中央区域的粒子
        central += np.sum(
            (particles[:, 0] >= L // 4) & (particles[:, 0] < 3 * L // 4) &
            (particles[:, 1] >= L // 4) & (particles[:, 1] < 3 * L // 4)
        )
    return central / (N * T)

if __name__ == '__main__':
    L = 512
    N = 100000
    T = 1000
    start_time = time.monotonic()
    ratio = simulate(L, N, T)
    print(f"Average dwell ratio: {ratio:.4f}")
    print(f"Simulation time: {time.monotonic() - start_time:.6f}s")