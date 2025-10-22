#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#include <stdbool.h>

extern void gen_rand_arr(uint64_t* x_ptr, uint64_t* y_ptr, uint64_t len);
extern uint64_t simulate(uint64_t* x_ptr, uint64_t* y_ptr, uint64_t L, uint64_t len, uint64_t T);

uint64_t L = 512;
uint64_t N = 100000;
uint64_t T = 1000;

int main() {
    bool L_is_power_of_2 = (L & (L - 1)) == 0 ? true : false;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    size_t bytes = (N + 3) * sizeof(uint64_t);  // 在后面加至少 3 个空数据，避免
    bytes = (bytes + 31) & ~31ULL; // 向上取整为32字节倍数
    uint64_t* particles_x = aligned_alloc(32, bytes);
    uint64_t* particles_y = aligned_alloc(32, bytes);
    if (!particles_x || !particles_y) {
        perror("malloc failed");
        return 1;
    }

    // 生成随机数
    gen_rand_arr(particles_x, particles_y, N);

    // 模拟位移
    double central = simulate(particles_x, particles_y, L, N, T);

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    printf("Average dwell ratio: %.4lf\n", central / (N * T));
    printf("Simulation time: %.6lfs\n", elapsed);
    free(particles_x);
    free(particles_y);
    return 0;
}
