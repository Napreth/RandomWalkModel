#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#include <stdbool.h>
#include <pthread.h>

extern void gen_rand_arr(uint64_t* x_ptr, uint64_t* y_ptr, uint64_t len);
extern uint64_t simulate(uint64_t* x_ptr, uint64_t* y_ptr, uint64_t L, uint64_t len, uint64_t T);

#ifndef THREAD_NUM
#define THREAD_NUM 24
#endif
uint64_t L = 512;
uint64_t N = 100000;
uint64_t T = 1000;

typedef struct {
    uint64_t* x_ptr;
    uint64_t* y_ptr;
    uint64_t L;
    uint64_t len;
    uint64_t T;
    double partial_result;
} ThreadArgs;

void* thread_func(void* arg) {
    ThreadArgs* p = (ThreadArgs*) arg;
    gen_rand_arr(p->x_ptr, p->y_ptr, p->len);
    p->partial_result = simulate(p->x_ptr, p->y_ptr, p->L, p->len, p->T);
    return NULL;
}

int main() {
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    bool L_is_power_of_2 = (L & (L - 1)) == 0 ? true : false;
    uint64_t* particles_x = malloc((N + 3) * sizeof(uint64_t));
    uint64_t* particles_y = malloc((N + 3) * sizeof(uint64_t));
    if (!particles_x || !particles_y) {
        perror("malloc failed");
        return 1;
    }

    // 创建线程
    pthread_t threads[THREAD_NUM];
    ThreadArgs args[THREAD_NUM];
    uint64_t chunk = N / THREAD_NUM;
    uint64_t offset = 0;
    for (int i = 0; i < THREAD_NUM; i++) {
        uint64_t sub_len = (i == THREAD_NUM - 1) ? (N - offset) : chunk;
        args[i].x_ptr = particles_x + offset;
        args[i].y_ptr = particles_y + offset;
        args[i].L = L;
        args[i].len = sub_len;
        args[i].T = T;
        args[i].partial_result = 0;
        offset += sub_len;
        pthread_create(&threads[i], NULL, thread_func, &args[i]);
    }

    // 等待所有线程完成
    double central = 0;
    for (int i = 0; i < THREAD_NUM; i++) {
        pthread_join(threads[i], NULL);
        central += args[i].partial_result;
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    printf("Average dwell ratio: %.4lf\n", central / (N * T));
    printf("Simulation time: %.6lfs\n", elapsed);
    free(particles_x);
    free(particles_y);
    return 0;
}
