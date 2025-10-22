# 参数
# rdi: uint64_t* x_ptr
# rsi: uint64_t* y_ptr
# rdx: uint64_t L
# rcx: uint64_t len
# r8: uint64_t T
# 非参数
# r9: 小于 L 的最大的 4 的倍数
# r10: i 游走循环
# r11: j 粒子循环
# r12: Lq
# r13: L3q
# r14: 运算中间值
# r15: 运算中间值
# rbx: scalar_x (可能用上)，并在循环中用作 L_is_power_of_2（反正在尾部循环前不会用到这个值）
# rbp: scalar_y (可能用上), 并在循环中用作 len_is_not_multi_of_4（反正在尾部循环前不会用到这个值）
# ymm0: 向量 {1, 1, 1, 1}
# ymm1: 向量 {-1, -1, -1, -1}
# ymm2: xorshift 生成随机数
# ymm3: vector_L, L 广播成向量
# ymm4: vector_Lsub (L - 1)
# ymm5: vector_Lq
# ymm6: vector_L3q
# ymm7: x
# ymm8: y
# ymm14: 运算中间值
# ymm15: 运算中间值
# 返回值
# rax: uint64_t 中央区域粒子统计累加


.intel_syntax noprefix
.section .text
.global simulate
.equ x_ptr, rdi
.equ y_ptr, rsi
.equ L, rdx
.equ len, rcx
.equ T, r8
.equ max_multi4_under_len, r9
.equ i, r10
.equ j, r11
.equ Lq, r12
.equ L3q, r13
.equ tmp1, r14
.equ tmp1d, r14d
.equ tmp1w, r14w
.equ tmp1b, r14b
.equ tmp2, r15
.equ tmp2d, r15d
.equ tmp2w, r15w
.equ tmp2b, r15b
.equ L_is_power_of_2, rbx
.equ L_is_power_of_2_b, bl
.equ scalar_x, rbx
.equ len_is_not_multi_of_4, rbp
.equ len_is_not_multi_of_4_b, bpl
.equ scalar_y, rbp
.equ vector_ones, ymm0
.equ xvector_ones, xmm0
.equ vector_negative_ones, ymm1
.equ xvector_negative_ones, xmm1
.equ xrand, ymm2
.equ xxrand, xmm2
.equ vector_L, ymm3
.equ xvector_L, xmm3
.equ vector_Lsub, ymm4
.equ xvector_Lsub, xmm4
.equ vector_Lq, ymm5
.equ xvector_Lq, xmm5
.equ vector_L3q, ymm6
.equ xvector_L3q, xmm6
.equ x, ymm7
.equ x_x, xmm7
.equ y, ymm8
.equ x_y, xmm8
.equ ytmp1, ymm14
.equ xtmp1, xmm14
.equ ytmp2, ymm15
.equ xtmp2, xmm15
.equ central, rax
.equ NOT_3, 0xFFFFFFFFFFFFFFFC
.macro XORSHIFT256
    vpsllq ytmp2, xrand, 13
    vpxor xrand, xrand, ytmp2
    vpsrlq ytmp2, xrand, 7
    vpxor xrand, xrand, ytmp2
    vpsllq ytmp2, xrand, 17
    vpxor xrand, xrand, ytmp2
.endm

simulate:
    push r12
    push r13
    push r14
    push r15
    push rbx
    push rbp

    # 生成 2 个掩码常量
    mov  tmp1, 0x0000000000000001
    movq xvector_ones, tmp1
    vpbroadcastq vector_ones, xvector_ones
    mov tmp1, 0xFFFFFFFFFFFFFFFF
    movq xvector_negative_ones, tmp1
    vpbroadcastq vector_negative_ones, xvector_negative_ones

    # 生成随机种子
    .rand_seed_1:
        rdrand tmp1
        jnc .rand_seed_1
    .rand_seed_2:
        rdrand tmp2
        jnc .rand_seed_2
    pinsrq xxrand, tmp1, 0
    pinsrq xxrand, tmp2, 1
    .rand_seed_3:
        rdrand tmp1
        jnc .rand_seed_3
    .rand_seed_4:
        rdrand tmp2
        jnc .rand_seed_4
    pinsrq xtmp1, tmp1, 0
    pinsrq xtmp1, tmp2, 1
    vinserti128 xrand, xrand, xtmp1, 1

    # 计算 L 的广播
    movq xvector_L, L
    vpbroadcastq vector_L, xvector_L

    # 计算[L/4, 3*L/4)的整数等效区间[Lq, L3q)
    # Lq = ceil(L/4)
    mov Lq, L
    add Lq, 3
    shr Lq, 2
    movq xvector_Lq, Lq
    vpbroadcastq vector_Lq, xvector_Lq
    # L3q = ceil(3L/4)
    mov L3q, L
    imul L3q, 3
    add L3q, 3
    shr L3q, 2
    movq xvector_L3q, L3q
    vpbroadcastq vector_L3q, xvector_L3q

    # 计算 Lsub
    mov tmp1, L
    sub tmp1, 1
    movq xvector_Lsub, tmp1
    vpbroadcastq vector_Lsub, xvector_Lsub

    # 计算小于 L 的最大的 4 的倍数
    mov max_multi4_under_len, len
    and max_multi4_under_len, NOT_3

    # 游走循环
    xor i, i
    xor central, central
    .simulate_loop:
        # 计算 L_is_power_of_2 和 len_is_not_multi_of_4
        # 由于寄存器可能会在内部循环的尾部被覆盖，所以在外部循环重新计算一次
        mov tmp1, L
        sub tmp1, 1
        test tmp1, L
        setz L_is_power_of_2_b
        movzx L_is_power_of_2, L_is_power_of_2_b
        mov len_is_not_multi_of_4, len
        and len_is_not_multi_of_4, 3
        setnz len_is_not_multi_of_4_b
        movzx len_is_not_multi_of_4, len_is_not_multi_of_4_b
        # 粒子循环
        xor j, j
        .particle_loop:
            vmovdqu x, [x_ptr + j * 8]
            vmovdqu y, [y_ptr + j * 8]
            # 随机生成方向
            # 生成 seed 和 mask, mask 是全0或全1的掩码
            XORSHIFT256
            vpand ytmp1, xrand, vector_ones
            vpxor ytmp1, ytmp1, vector_negative_ones
            vpaddq ytmp1, ytmp1, vector_ones
            # particles[j].x += (((seed >> 1) & 1) * 2 - 1) & mask
            vpsrlq ytmp2, xrand, 1
            vpand ytmp2, ytmp2, vector_ones
            vpsllq ytmp2, ytmp2, 1
            vpsubq ytmp2, ytmp2, vector_ones
            vpand ytmp2, ytmp2, ytmp1
            vpaddq x, x, ytmp2
            # particles[j] += ((seed & 1) * 2 - 1) & ~mask
            vpand ytmp2, xrand, vector_ones
            vpsllq ytmp2, ytmp2, 1
            vpsubq ytmp2, ytmp2, vector_ones
            vpxor ytmp1, ytmp1, vector_negative_ones
            vpand ytmp2, ytmp2, ytmp1
            vpaddq y, y, ytmp2

            # 周期边界
            cmp L_is_power_of_2, 1
            jne .periodic_boundary_not_power2
            vpand x, x, vector_Lsub
            vpand y, y, vector_Lsub
            jmp .periodic_boundary_finish
            .periodic_boundary_not_power2:
                vpcmpeqq ytmp1, x, vector_L
                vpand ytmp1, ytmp1, vector_L
                vpsubq x, x, ytmp1
                vpcmpeqq ytmp1, x, vector_negative_ones
                vpand ytmp1, ytmp1, vector_L
                vpaddq x, x, ytmp1
                vpcmpeqq ytmp1, y, vector_L
                vpand ytmp1, ytmp1, vector_L
                vpsubq y, y, ytmp1
                vpcmpeqq ytmp1, y, vector_negative_ones
                vpand ytmp1, ytmp1, vector_L
                vpaddq y, y, ytmp1
            .periodic_boundary_finish:

            # 判断是否进入尾部循环
            # 当 len 不是 4 的倍数时，需要满足 j >= max_multi4_under_len
            # 当 len 是 4 的倍数时，永远不进入循环
            cmp j, max_multi4_under_len
            setae tmp1b
            movzx tmp1, tmp1b
            and tmp1, len_is_not_multi_of_4
            cmp tmp1, 1
            jne .vector_stat

            .tail_loop:
                # 提取所需的 64 位整数
                mov tmp1, j
                sub tmp1, max_multi4_under_len
                cmp tmp1, 0
                vmovq tmp2, x_x
                cmove scalar_x, tmp2
                vmovq tmp2, x_y
                cmove scalar_y, tmp2
                cmp tmp1, 1
                pextrq tmp2, x_x, 1
                cmove scalar_x, tmp2
                pextrq tmp2, x_y, 1
                cmove scalar_y, tmp2
                cmp tmp1, 2
                vextracti128 xtmp1, x, 1
                vmovq tmp2, xtmp1
                cmove scalar_x, tmp2
                vextracti128 xtmp1, y, 1
                vmovq tmp2, xtmp1
                cmove scalar_y, tmp2

                #  统计中央区域（标量）
                # 中央区域的概率约为 0.25, 随机性比较大，此时采用 SETcc 系列比跳转更高效
                cmp scalar_x, Lq
                setae tmp1b
                cmp scalar_x, L3q
                setb tmp2b
                and tmp1b, tmp2b
                cmp scalar_y, Lq
                setae tmp2b
                and tmp1b, tmp2b
                cmp scalar_y, L3q
                setb tmp2b
                and tmp1b, tmp2b
                movzx tmp1, tmp1b
                add central, tmp1

                mov [x_ptr + j * 8], scalar_x
                mov [y_ptr + j * 8], scalar_y
                inc j
                cmp j, len
                jb .tail_loop
                jmp .particle_loop_final

            .vector_stat:
            # 统计中央区域（向量）
            vpcmpgtq ytmp1, vector_Lq, x
            vpxor ytmp1, ytmp1, vector_negative_ones
            vpcmpgtq ytmp2, vector_L3q, x
            vpand ytmp1, ytmp1, ytmp2
            vpcmpgtq ytmp2, vector_Lq, y
            vpxor ytmp2, ytmp2, vector_negative_ones
            vpand ytmp1, ytmp1, ytmp2
            vpcmpgtq ytmp2, vector_L3q, y
            vpand ytmp1, ytmp1, ytmp2
            vpsrlq ytmp1, ytmp1, 63
            vextracti128 xtmp2, ytmp1, 1
            vpextrq tmp1, xtmp1, 0
            add central, tmp1
            vpextrq tmp1, xtmp1, 1
            add central, tmp1
            vpextrq tmp1, xtmp2, 0
            add central, tmp1
            vpextrq tmp1, xtmp2, 1
            add central, tmp1

            vmovdqu [x_ptr + j * 8], x
            vmovdqu [y_ptr + j * 8], y
            add j, 4
            cmp j, len
            jb .particle_loop
            .particle_loop_final:
        inc i
        cmp i, T
        jb .simulate_loop

    pop rbp
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    ret
.att_syntax
