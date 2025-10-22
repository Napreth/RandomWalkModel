cmake_minimum_required(VERSION 3.20)
project(C_ASM_SIMD_MULTI_THREAD C ASM)

# 设置输出文件名
set(TARGET C_ASM_SIMD_MULTI_THREAD.out)

# 添加源文件
set(SOURCES
    main.c
    gen_rand_arr.s
    simulate.s
)

# 设置编译选项
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} \
    -O3 -Ofast -flto -march=native -mtune=native \
    -funroll-loops -fomit-frame-pointer -ffast-math \
    -fno-math-errno -fno-trapping-math -fno-stack-protector \
    -falign-functions=32 -falign-loops=32 \
    -ftree-vectorize -funsafe-math-optimizations \
    -fno-plt -fno-semantic-interposition -fopenmp \
    -lpthread"
)

# 构建目标
add_executable(${TARGET} ${SOURCES})
