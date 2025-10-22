# 参数
# rdi: uint64_t* x_ptr
# rsi: uint64_t* y_ptr
# rdx: uint64_t len
# 非参数
# rcx: i 循环索引
# r8: xorshift 生成随机数
# r9: r8 的位移中间值
# r10: len - 1
# 返回值：无

.intel_syntax noprefix
.section .text
.global gen_rand_arr
.macro XORSHIFT64
    mov r9, r8
    shl r9, 13
    xor r8, r9
    mov r9, r8
    shr r9, 7
    xor r8, r9
    mov r9, r8
    shl r9, 17
    xor r8, r9
.endm

gen_rand_arr:
    xor rcx, rcx
    mov r10, rdx
    dec r10
    gen_xorshift_seed:
        rdrand r8
        jnc gen_xorshift_seed

    # 主循环，使用 xorshift 算法生成随机数
    gen_loop:
        gen_rand_x:
            XORSHIFT64
            mov [rdi + rcx * 8], r8
        gen_rand_y:
            XORSHIFT64
            mov [rsi + rcx * 8], r8
        inc rcx
        cmp rcx, rdx
        jb gen_loop
        ret
.att_syntax
