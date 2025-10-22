#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#include <stdbool.h>

extern void gen_rand_arr(uint64_t* x_ptr, uint64_t* y_ptr, uint64_t len);

int L = 512;
uint64_t N = 100000;
int T = 1000;

// 使用 Xorshift 生成随机数加快运算速度
static inline int xorshift(int* state) {
    int x = *state;
    x ^= x << 7;
    x ^= x >> 9;
    x ^= x << 8;
    *state = x;
    return x;
}

int main() {
    bool L_is_power_of_2 = (L & (L - 1)) == 0 ? true : false;
    const uint32_t Lq = L / 4;
    const uint32_t L3q = 3 * L / 4;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    srand(time(NULL));
    int rng = rand();
    uint64_t* particles_x = malloc(N * sizeof(uint64_t));
    uint64_t* particles_y = malloc(N * sizeof(uint64_t));
    if (!particles_x || !particles_y) {
        perror("malloc failed");
        return 1;
    }

    // 生成随机数
    gen_rand_arr(particles_x, particles_y, N);

    // 模拟位移
    double central = 0;
    for (int i = 0; i < T; i++) {
        for (unsigned j = 0; j < N; j++) {
            int seed = xorshift(&rng) & 3;
            int mask = seed & 1;
            particles_x[j] += (((seed >> 1) & 1) * 2 - 1) * mask;
            particles_y[j] += ((seed & 1) * 2 - 1) * (1 - mask);

            // 周期边界
            if (L_is_power_of_2) {
                particles_x[j] &= L - 1;
                particles_y[j] &= L - 1;
            }
            else {
                particles_x[j] %= L;
                particles_y[j] %= L;
            }

            // 统计中央区域
            if (particles_x[j] >= Lq && particles_x[j] < L3q && particles_y[j] >= Lq && particles_y[j] < L3q) {
                central += 1;
            }
        }
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    printf("Average dwell ratio: %.4lf\n", central / (N * T));
    printf("Simulation time: %.6lfs\n", elapsed);
    free(particles_x);
    free(particles_y);
    return 0;
}
