# 参数
# rdi: uint64_t* x_ptr
# rsi: uint64_t* y_ptr
# rdx: uint64_t len
# 非参数
# rcx: max_multi4_under_len
# rax: len_is_not_multi_of_4
# r8: i 循环索引
# r9: scalar_x
# r10: scalar_y
# r11: 运算中间值
# r12: 运算中间值
# ymm0: xorshift 生成随机数
# ymm1: x
# ymm2: y
# ymm15: 运算中间值
# 返回值：无

.intel_syntax noprefix
.section .text
.equ x_ptr, rdi
.equ y_ptr, rsi
.equ len, rdx
.equ max_multi4_under_len, rcx
.equ len_is_not_multi_of_4, rax
.equ len_is_not_multi_of_4_b, al
.equ i, r8
.equ scalar_x, r9
.equ scalar_y, r10
.equ tmp1, r11
.equ tmp1d, r11d
.equ tmp1w, r11w
.equ tmp1b, r11b
.equ tmp2, r12
.equ tmp2d, r12d
.equ tmp2w, r12w
.equ tmp2b, r12b
.equ xrand, ymm0
.equ xxrand, xmm0
.equ x, ymm1
.equ x_x, xmm1
.equ y, ymm2
.equ x_y, xmm2
.equ ytmp, ymm15
.equ xtmp, xmm15
.global gen_rand_arr
.macro XORSHIFT256
    vpsllq ytmp, xrand, 13
    vpxor xrand, xrand, ytmp
    vpsrlq ytmp, xrand, 7
    vpxor xrand, xrand, ytmp
    vpsllq ytmp, xrand, 17
    vpxor xrand, xrand, ytmp
.endm

gen_rand_arr:
    push r12

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
    pinsrq xtmp, tmp1, 0
    pinsrq xtmp, tmp2, 1
    vinserti128 xrand, xrand, xtmp, 1

    # 计算 len 是否是 4 的倍数
    mov len_is_not_multi_of_4, len
    and len_is_not_multi_of_4, 3
    setnz len_is_not_multi_of_4_b
    movzx len_is_not_multi_of_4, len_is_not_multi_of_4_b

    # 主循环
    xor i, i
    .gen_loop:
        # 生成随机数
        XORSHIFT256
        vmovdqa x, xrand
        XORSHIFT256
        vmovdqa y, xrand

        # 判断是否进入尾部循环
        # 当 len 不是 4 的倍数时，需要满足 i >= max_multi4_under_len
        # 当 len 是 4 的倍数时，永远不进入循环
        cmp i, max_multi4_under_len
        setae tmp1b
        movzx tmp1, tmp1b
        and tmp1, len_is_not_multi_of_4
        cmp tmp1, 1
        jne .tail_loop_final
        .tail_loop:
            # 提取所需的 64 位整数
            mov tmp1, i
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
            vextracti128 xtmp, x, 1
            vmovq tmp2, xtmp
            cmove scalar_x, tmp2
            vextracti128 xtmp, y, 1
            vmovq tmp2, xtmp
            cmove scalar_y, tmp2

            # 保存
            mov [x_ptr + i * 8], scalar_x
            mov [y_ptr + i * 8], scalar_y
            inc i
            cmp i, len
            jb .tail_loop
            .tail_loop_final:

        vmovdqu [x_ptr + i * 8], x
        vmovdqu [y_ptr + i * 8], y
        add i, 4
        cmp i, len
        jb .gen_loop
    pop r12
    ret
.att_syntax
