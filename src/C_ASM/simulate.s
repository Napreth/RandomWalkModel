# 参数
# rdi: uint64_t* x_ptr
# rsi: uint64_t* y_ptr
# rdx: uint64_t L
# rcx: uint64_t len
# r8: uint64_t T
# 非参数
# r9: Lq
# r10: L3q
# r11: i 游走循环
# r12: j 粒子循环
# r13: xorshift 生成随机数
# r14: 运算中间值
# r15: 运算中间值
# rbx: x 的值
# rbp: y 的值
# 返回值
# rax: uint64_t 中央区域粒子统计累加

.align 32
.intel_syntax noprefix
.section .text
.global simulate
.equ x_ptr, rdi
.equ y_ptr, rsi
.equ L, rdx
.equ len, rcx
.equ T, r8
.equ Lq, r9
.equ L3q, r10
.equ i, r11
.equ j, r12
.equ xrand, r13
.equ tmp1, r14
.equ tmp1d, r14d
.equ tmp1w, r14w
.equ tmp1b, r14b
.equ tmp2, r15
.equ tmp2d, r15d
.equ tmp2w, r15w
.equ tmp2b, r15b
.equ x, rbx
.equ y, rbp
.equ central, rax
.macro XORSHIFT64
    mov tmp2, xrand
    shl tmp2, 13
    xor xrand, tmp2
    mov tmp2, xrand
    shr tmp2, 7
    xor xrand, tmp2
    mov tmp2, xrand
    shl tmp2, 17
    xor xrand, tmp2
.endm

simulate:
    push r12
    push r13
    push r14
    push r15
    push rbx
    push rbp
    xor i, i
    xor central, central
    gen_xorshift_seed:
        rdrand xrand
        jnc gen_xorshift_seed
        
    # 计算[L/4, 3*L/4)的整数等效区间[Lq, L3q)
    # Lq = ceil(L/4)
    mov Lq, L
    add Lq, 3
    shr Lq, 2
    # L3q = ceil(3L/4)
    mov L3q, L
    imul L3q, 3
    add L3q, 3
    shr L3q, 2

    # 计算 L 是否为 2 的整数幂，即(L & (L - 1)) == 0
    mov tmp1, L
    sub tmp1, 1
    and tmp1, L
    test tmp1, tmp1
    jne simulate_loop_normal

    simulate_loop_power2:
        xor j, j
        particle_loop_power2:
            mov x, [x_ptr + j * 8]
            mov y, [y_ptr + j * 8]
            # 随机生成方向
            # 生成 seed 和 mask
            XORSHIFT64
            mov tmp1, xrand
            and tmp1, 1
            # particles[j].x += (((seed >> 1) & 1) * 2 - 1) * mask
            mov tmp2, xrand
            shr tmp2, 1
            and tmp2, 1
            shl tmp2, 1
            sub tmp2, 1
            imul tmp2, tmp1
            add x, tmp2
            # particles[j].y += ((seed & 1) * 2 - 1) * (1 - mask)
            mov tmp2, xrand
            and tmp2, 1
            shl tmp2, 1
            sub tmp2, 1
            not tmp1
            and tmp1, 1
            imul tmp2, tmp1
            add y, tmp2

            # 周期边界，particles[j] &= L - 1
            mov tmp1, L
            sub tmp1, 1
            and x, tmp1
            and y, tmp1

            # 统计中央区域
            cmp x, Lq
            jb not_central_power2
            cmp x, L3q
            jae not_central_power2
            cmp y, Lq
            jb not_central_power2
            cmp y, L3q
            jae not_central_power2
            inc central
            not_central_power2:

            mov [x_ptr + j * 8], x
            mov [y_ptr + j * 8], y
            inc j
            cmp j, len
            jb particle_loop_power2
        inc i
        cmp i, T
        jb simulate_loop_power2
        jmp final

    simulate_loop_normal:
        xor j, j
        particle_loop_normal:
            mov x, [x_ptr + j * 8]
            mov y, [y_ptr + j * 8]
            # 随机生成方向
            # 生成 seed 和 mask
            XORSHIFT64
            mov tmp1, xrand
            and tmp1, 1
            # particles[j] += (((seed >> 1) & 1) * 2 - 1) * mask
            mov tmp2, xrand
            shr tmp2, 1
            and tmp2, 1
            shl tmp2, 1
            sub tmp2, 1
            imul tmp2, tmp1
            add x, tmp2
            # particles[j] += ((seed & 1) * 2 - 1) * (1 - mask)
            mov tmp2, xrand
            and tmp2, 1
            shl tmp2, 1
            sub tmp2, 1
            not tmp1
            and tmp1, 1
            imul tmp2, tmp1
            add y, tmp2

            # 周期边界，particles[j] %= L
            mov tmp1, 0
            cmp x, L
            cmovnb x, tmp1
            test x, x
            jns .no_under_x
            add x, L
            .no_under_x:
            mov tmp1, 0
            cmp y, L
            cmovnb y, tmp1
            test y, y
            jns .no_under_y
            add y, L
            .no_under_y:

            # 统计中央区域
            cmp x, Lq
            jb not_central_normal
            cmp x, L3q
            jae not_central_normal
            cmp y, Lq
            jb not_central_normal
            cmp y, L3q
            jae not_central_normal
            inc central
            not_central_normal:

            mov [x_ptr + j * 8], x
            mov [y_ptr + j * 8], y
            inc j
            cmp j, len
            jb particle_loop_normal
        inc i
        cmp i, T
        jb simulate_loop_normal

    final:
        pop rbp
        pop rbx
        pop r15
        pop r14
        pop r13
        pop r12
        ret
.att_syntax
