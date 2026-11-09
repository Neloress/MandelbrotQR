p = r'C:\Mandelbrot\MandelbrotASM\SmallASM\main64.asm'
s = open(p, encoding='utf-8', newline='').read().replace('\r\n', '\n')


def rep(old, new, count=1):
    global s
    assert s.count(old) == count, (old[:70], s.count(old))
    s = s.replace(old, new)


T = '\t'
# ---- MulF: sign handling -------------------------------------------------
rep(T*2 + "mov rax, 8000000000000000h ;mask for sign bit\n" + T*2 + "mov r11, rcx\n" + T*2 + "and r11, rax ;extract a's sign bit\n" + T*2 + "xor r11, r8  ;combine with b's sign bit (xor -> one sign result in negative, two in positive, none in positive)\n" + T*2 + "and r11, rax ;extract combined sign bit\n",
    T*2 + "mov r11, rcx\n" + T*2 + "xor r11, r8  ;combine a's and b's sign bit (xor -> one sign result in negative, two in positive, none in positive)\n" + T*2 + "shr r11, 63  ;extract combined sign bit (all other bits cleared) ;64bit-specific: no 64 bit mask needed\n" + T*2 + "shl r11, 63\n")
rep(T*2 + "not rax \t  ;invert mask for removing sign bit\n" + T*2 + "and rcx, rax ;remove sign bit from a\n" + T*2 + "and r8, rax  ;remove sign bit from b\n",
    T*2 + "btr rcx, 63 ;remove sign bit from a\n" + T*2 + "btr r8, 63  ;remove sign bit from b\n")
rep(T*2 + "mov rcx, 8000000000000000h ;set Mask\n" + T*2 + "and rcx, r11 ;keep mask/sign if X4 has the sign bit, else rbx will be 0\n",
    T*2 + "mov rcx, r11\n" + T*2 + "shr rcx, 63 ;keep sign if X4 has the sign bit, else rcx will be 0\n" + T*2 + "shl rcx, 63\n")

# ---- MulFint ------------------------------------------------------------
rep(T*2 + "mov rax, 8000000000000000h ;mask for sign bit\n" + T*2 + "mov r11, rcx\n" + T*2 + "and r11, rax ;extract a's sign bit\n" + T*2 + "xor r11, rbp ;combine with b's sign bit (xor -> one sign result in negative, two in positive, none in positive)\n" + T*2 + "and r11, rax ;extract combined sign bit\n",
    T*2 + "mov r11, rcx\n" + T*2 + "xor r11, rbp ;combine a's and b's sign bit (xor -> one sign result in negative, two in positive, none in positive)\n" + T*2 + "shr r11, 63  ;extract combined sign bit (all other bits cleared) ;64bit-specific: no 64 bit mask needed\n" + T*2 + "shl r11, 63\n")
rep(T*2 + "test rbp, rax ;test is neg\n" + T*2 + "jz mulfint_b_not_neg\n", T*2 + "test rbp, rbp ;test is neg\n" + T*2 + "jns mulfint_b_not_neg\n")
rep(T*2 + "not rax \t  ;invert mask for removing sign bit\n" + T*2 + "and rcx, rax ;remove sign bit from a\n", T*2 + "btr rcx, 63 ;remove sign bit from a\n")

# ---- AddF ----------------------------------------------------------------
rep(T*2 + "mov r9, 8000000000000000h ;mask for sign bit\n" + T*2 + "mov r10, rcx ; get a_high\n" + T*2 + "mov r11, r8  ; get b_high\n" + T*2 + "and r10, r9 ;extract a's sign bit\n" + T*2 + "and r11, r9 ;extract b's sign bit\n",
    T*2 + "mov r10, rcx ; get a_high\n" + T*2 + "mov r11, r8  ; get b_high\n" + T*2 + "btr rcx, 63 ;remove sign bit from a ;64bit-specific: no 64 bit mask needed\n" + T*2 + "btr r8, 63  ;remove sign bit from b\n" + T*2 + "xor r10, rcx ;extract a's sign bit (original a_high xor a_high without sign)\n" + T*2 + "xor r11, r8  ;extract b's sign bit\n")
rep(T + ";State: r11 = sign b, r10 = sign a\n" + T + ";Task: remove sign bits from a and b\n" + T + ";{\n" + T*2 + "xor rcx, r10 ;remove sign bit from a\n" + T*2 + "xor r8, r11  ;remove sign bit from b\n" + T + ";}\n\n", "")

# ---- GetIterations -------------------------------------------------------
rep(T*3 + "xor rbp, rbp\n" + T*3 + "mov r8, 9000000000000000h ;b_high = -4 = -2^2\n", T*3 + "xor ebp, ebp\n" + T*3 + "mov r8, 9000000000000000h ;b_high = -4 = -2^2\n")
rep(T*3 + "mov rax, 8000000000000000h ;sign mask\n" + T*3 + "test rcx, rax\n" + T*3 + "je getit_end ;escaped -> |zn| > 2\n",
    T*3 + "test rcx, rcx\n" + T*3 + "jns getit_end ;escaped -> |zn| > 2 (sign bit not set)\n")
rep(T*3 + "mov rax, 8000000000000000h\n" + T*3 + "xor r8, rax\n", T*3 + "btc r8, 63 ;invert sign\n")
for r in ("rsi", "r12", "r13", "r14"):
    pass

# ---- ZoomAxis ------------------------------------------------------------
rep(T*3 + "mov rcx, r14\t\t\t\t\t\t\t;a_high = pixelSize_new_high\n" + T*3 + "mov rax, 8000000000000000h \t\t\t\t;mask for sign bit\n" + T*3 + "mov rbx, r13\t\t\t\t\t\t\t;a_low = +-pixelSize_new_low\n" + T*3 + "xor rcx, rax \t\t\t\t\t\t\t;a_high = -pixelSize_new_high\n",
    T*3 + "mov rcx, r14\t\t\t\t\t\t\t;a_high = pixelSize_new_high\n" + T*3 + "mov rbx, r13\t\t\t\t\t\t\t;a_low = +-pixelSize_new_low\n" + T*3 + "btc rcx, 63 \t\t\t\t\t\t\t;a_high = -pixelSize_new_high\n")
rep(T*4 + "mov rax, 8000000000000000h \t;mask for sign bit\n" + T*4 + "test rcx, rax\t\t\t\t;test sign is set\n" + T*4 + "jz BoundNewLL_4\n",
    T*4 + "test rcx, rcx\t\t\t\t;test sign is set\n" + T*4 + "jns BoundNewLL_4\n")
rep(T*4 + "not rax\t\t\t\t\t\t\t\t\t\t;mask for removing sign\n" + T*4 + "mov r9, rcx\t\t\t\t\t\t\t\t\t;save lower_left_new_high before removing sign\n" + T*4 + "and r9, rax\t\t\t\t\t\t\t\t\t;remove sign from lower_left_new_high\n" + T*4 + "mov r10, qword ptr [rdi+AXIS_lowerLeft_min_high]\n" + T*4 + "and rax, r10\t\t\t\t\t\t\t\t;remove sign from lowerLeft_min_high\n",
    T*4 + "mov r9, rcx\t\t\t\t\t\t\t\t\t;save lower_left_new_high before removing sign\n" + T*4 + "shl r9, 1\t\t\t\t\t\t\t\t\t;remove sign from lower_left_new_high (both values are shifted, so the compare stays valid) ;64bit-specific\n" + T*4 + "mov r10, qword ptr [rdi+AXIS_lowerLeft_min_high]\n" + T*4 + "mov rax, r10\n" + T*4 + "shl rax, 1\t\t\t\t\t\t\t\t\t;remove sign from lowerLeft_min_high\n")
rep(T*4 + "xor rbp, rbp\t\t\t\t\t\t\t\t;b_low = upper_right_max_low = 0\n" + T*4 + "mov rax, 8000000000000000h \t;mask for sign bit\n" + T*4 + "mov r8, qword ptr [rdi+AXIS_upperRight_max_high] ;b_high = upper_right_max_high\n" + T*4 + "xor r8, rax \t\t\t\t\t\t\t\t;b_high = -upper_right_max_high\n",
    T*4 + "xor ebp, ebp\t\t\t\t\t\t\t\t;b_low = upper_right_max_low = 0\n" + T*4 + "mov r8, qword ptr [rdi+AXIS_upperRight_max_high] ;b_high = upper_right_max_high\n" + T*4 + "btc r8, 63 \t\t\t\t\t\t\t\t;b_high = -upper_right_max_high\n")
rep(T*4 + "mov rax, 8000000000000000h \t;mask for sign bit\n" + T*4 + "test rcx, rax\n" + T*4 + "jnz BoundNewLL_8\t;if not zero -> shiftVal is negative -> do nothing\n" + T*4 + "xor rcx, rax\t\t;invert sign of shiftVal_high\n",
    T*4 + "test rcx, rcx\n" + T*4 + "js BoundNewLL_8\t;if sign is set -> shiftVal is negative -> do nothing\n" + T*4 + "btc rcx, 63\t\t;invert sign of shiftVal_high\n")

# ---- start (zoom) --------------------------------------------------------
rep(T*2 + "mov rax, 7FFFFFFFFFFFFFFFh\n" + T*2 + "test rax, rcx \t\t\t\t\t\t  ;check if high part of pixel size is zero\n",
    T*2 + "mov rax, rcx\n" + T*2 + "shl rax, 1 \t\t\t\t\t\t\t  ;check if high part of pixel size is zero (sign bit shifted out, ZF set if all other bits are zero)\n")
open(p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n'))
print('ok')
