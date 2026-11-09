option casemap:none

includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib

EXTERN GetModuleHandleA:PROC
EXTERN RegisterClassExA:PROC
EXTERN CreateWindowExA:PROC
EXTERN ShowWindow:PROC
EXTERN SetFocus:PROC
EXTERN BeginPaint:PROC
EXTERN EndPaint:PROC
EXTERN GetClientRect:PROC
EXTERN GetMessageA:PROC
EXTERN TranslateMessage:PROC
EXTERN DispatchMessageA:PROC
EXTERN DefWindowProcA:PROC
EXTERN PostQuitMessage:PROC
EXTERN LoadIconA:PROC
EXTERN LoadCursorA:PROC
EXTERN CreateDIBSection:PROC
EXTERN CreateCompatibleDC:PROC
EXTERN SelectObject:PROC
EXTERN BitBlt:PROC
EXTERN InvalidateRect:PROC
EXTERN DeleteDC:PROC
EXTERN ExitProcess:PROC
EXTERN DeleteObject:PROC

;available registers: 
; Register | Funktion (Windows x64)       | Changed by Call | Needs Saving | Can be used freely | Eigene Funktion (Verwendung)
; ---------|------------------------------|-----------------|--------------|--------------------|----------------------------------------
; rax      | Return Value (Ganzzahl/Ptr)  | JA (Flüchtig)   | NEIN         | JA                 | 
; rbx      | Freie Verwendung             | NEIN            | JA           | NEIN               | 
; rcx      | 1. Argument                  | JA (Flüchtig)   | NEIN         | JA                 | 
; rdx      | 2. Argument                  | JA (Flüchtig)   | NEIN         | JA                 | 
; rsi      | Freie Verwendung             | NEIN            | JA           | NEIN               | Stack Restore
; rdi      | Freie Verwendung             | NEIN            | JA           | NEIN               | 
; rbp      | Frame Pointer (optional)     | NEIN            | JA           | NEIN               | 
; rsp      | Stack Pointer                | JA (Sehr!)      | IMMER        | NIEMALS            | 
; r8       | 3. Argument                  | JA (Flüchtig)   | NEIN         | JA                 | 
; r9       | 4. Argument                  | JA (Flüchtig)   | NEIN         | JA                 | 
; r10      | Freie Verwendung / Scratch   | JA (Flüchtig)   | NEIN         | JA                 | 
; r11      | Freie Verwendung / Scratch   | JA (Flüchtig)   | NEIN         | JA                 | 
; r12      | Freie Verwendung             | NEIN            | JA           | NEIN               | unchanged by method
; r13      | Freie Verwendung             | NEIN            | JA           | NEIN               | unchanged by method
; r14      | Freie Verwendung             | NEIN            | JA           | NEIN               | unchanged by method
; r15      | Freie Verwendung             | NEIN            | JA           | NEIN               | Return address


.data
	g_szClassName DB "A",0
	c_window_title DB "Mandelbrot set",0
	
	ALIGN 8
	ua_wc BYTE 80 DUP(0)
	ua_msg BYTE 48 DUP(0)
	ua_ps BYTE 80 DUP(0)
	ua_rect BYTE 16 DUP(0)
	ua_bmi BYTE 48 DUP(0)
	ua_bitmapData QWORD 0
	ua_hbitmap QWORD 0
	ua_width QWORD 0
	ua_height QWORD 0
	a_colour_pallet DWORD 0FF190720h,0FF421E0Fh,0FF6A3403h,0FF995700h,0FFCC8000h,0FFFFAA00h,0FFF8C95Fh,0FFF1E9BFh,0FFD3ECF8h,0FF86B5E5h,0FF397DD1h,0FF1852B1h,0FF0C2C8Ah,0FF000764h,0FF040449h,0FF09012Fh
	
	a_lowerLeft_x_high QWORD 8900000000000000h
	a_lowerLeft_x_low QWORD  0000000000000000h
	a_lowerLeft_y_high QWORD 855551D700000000h
	a_lowerLeft_y_low QWORD  0000000000000000h

	a_lowerLeft_x_min_high QWORD 8900000000000000h
	;a_lowerLeft_x_min_low QWORD  0000000000000000h ;no need to hold zeros in .data
	a_lowerLeft_y_min_high QWORD 855551D700000000h
	;a_lowerLeft_y_min_low QWORD  0000000000000000h ;no need to hold zeros in .data

	a_upperRight_x_max_high QWORD 0455475A00000000h
	;a_upperRight_x_max_low QWORD  0000000000000000h ;no need to hold zeros in .data
	a_upperRight_y_max_high QWORD 04AAAE2900000000h
	;a_upperRight_y_max_low QWORD  0000000000000000h ;no need to hold zeros in .data

	a_pixelSize_high QWORD 00004444400000000h
	a_pixelSize_low QWORD 0000000000000000h
	a_pixelSize_max_high QWORD 00004444400000000h
	;a_pixelSize_max_low QWORD 0000000000000000h ;no need to hold zeros in .data
	;a_pixelSize_min_high QWORD 00004444400000000h ;no need to hold zeros in .data
	a_pixelSize_min_low QWORD 0000000000000010h ;TODO check values is a good value

	a_zoom_factor_out_high QWORD 03A2E8BA00000000h
	;a_zoom_factor_out_low QWORD 0000000000000000h ;no need to hold zeros in .data
	a_zoom_factor_in_high QWORD 0466666600000000h
	;a_zoom_factor_in_low QWORD 0000000000000000h ;no need to hold zeros in .data

	a_enable_draw BYTE 1
	a_mouseWheel_state WORD 0
	a_mousePos_x DWORD 0
	a_mousePos_y DWORD 0

	ua_hdcPaint QWORD 0
	ua_hdcMem QWORD 0
	ua_hwnd QWORD 0
	ua_hInstance QWORD 0

	WC_cbSize EQU 0
	WC_style EQU 4
	WC_lpfnWndProc EQU 8
	WC_cbClsExtra EQU 16
	WC_cbWndExtra EQU 20
	WC_hInstance EQU 24
	WC_hIcon EQU 32
	WC_hCursor EQU 40
	WC_hbrBackground EQU 48
	WC_lpszMenuName EQU 56
	WC_lpszClassName EQU 64
	WC_hIconSm EQU 72

.code

; ---------- Function: MulF direct -----------------------------------
; Multiplies two fixed-point numbers
; a_low: rbx (64bit after dot)
; a_high: rcx (1bit sign, 5bit pre dot, 122 bit after dot)
; b_low: rbp (64bit after dot)
; b_high: r8 (1bit sign, 5bit pre dot, 122 bit after dot)
; result_low: rbx
; result_high: rcx
; free_to_use: rax, rdx, r9, r10, r11
Function_MulF:

	;Task: get resulting sign (r11 signbit)
	;{
		mov rax, 8000000000000000h ;mask for sign bit
		mov r11, rcx
		and r11, rax ;extract a's sign bit
		xor r11, r8  ;combine with b's sign bit (xor -> one sign result in negative, two in positive, none in positive)
		and r11, rax ;extract combined sign bit
	;}

	;Task: remove sign bits from a and b
	;{
		not rax 	  ;invert mask for removing sign bit
		and rcx, rax ;remove sign bit from a
		and r8, rax  ;remove sign bit from b
	;}

	;Number structure:
	; A = A_high * 2^64 + A_low
	; B = B_high * 2^64 + B_low
	;-----------------------------------------------------------------------------------------------------------------------------
	;Raw mathematical product (256-bit):
	; A * B = (A_low * B_low)            <-- (low part)     
	;       + (A_low * B_high) * 2^64    <-- (middle part 1) 
	;       + (A_high * B_low) * 2^64    <-- (middle part 2) 
	;       + (A_high * B_high) * 2^128  <-- (high part)     
	; As we have 122-bits after the dot the dot gets shifted to position 2*122 = 244
	; The whole result is represented on 256 bits splittet into four 64-bit registers (X4, X3, x2, X1) high bits to low bits
	; The dot is now at bit 244 in the 256-bit result
	; We need to shift the result 244-122 = 122 to the right bits to align the fixed-point dot correctly
	; This means 64+58 = 122 one whole register and 58 bits inside the registers
	; So X1 gets completely shifted out of the result -> resulting number after 64 bit shift (X4, X3, X2)
	; In this number the dot is now at bit 244-64 = 180 leaving (64*3=192)-180 = 12 bits before the dot
	; As our representation has 128-122 = 6 bits before the dot we need to shift 6 to the left 
	; Our Resulting number is (Y2, Y1)
	; Y2 = (X4<<6 low 58 bits) | (X3>>58 high 6 bits)
	; Y1 = (X3<<6 low 58 bits) | (X2>>58 high 6 bits)
	;-----------------------------------------------------------------------------------------------------------------------------
	;Computation:
	; X4, X3_1 = (A_high*B_high)
	; X3_2, X2_1 = (A_high*B_low)
	; X3_3, X2_2 = (A_low*B_high)
	; X2_3, X1 = (A_low*B_low)
	;
	; X1 = X1                  					<--- ignored (shifted out)
	; X2 = X2_1 + X2_2 + X2_3  					<--- carry needs to be given to X3
	; X3 = X3_1 + X3_2 + X3_3 + (carry from X2) <--- carry needs to be given to X4
	; X4 = X4 + (carry from X3) 				<--- carry can not occur in our number range
	;-----------------------------------------------------------------------------------------------------------------------------

	;Task: X4, X3_1 = (A_high*B_high)
	;{
		mov rax, rcx ;set a_high as first param
		mul r8 ;a_high * b_high, result in rax (low) and rdx (high) -> rax is X3_1 and rdx is X4
		add r11, rdx ;store X4 in r11 for later use (r11 is also used for sign but collision are imbossible with our number range)
		mov r10, rax ;store X3_1 in r10 for later use
	;}
	
	;State: r11 = X4 + sign, r10 = X3_1
	;Task: X3_3, X2_2 = (A_low*B_high)
	;{
		mov rax, rbx ;set a_low as first param
		mul r8 ;a_low * b_high, result in rax (low) and rdx (high) -> rax is x2_2 and rdx is X3_3
		add r10, rdx ;add X3_3 to X3_1 need to react to carry if any
		adc r11, 0 ;add carry to X4 if any
		mov r9, rax ;store X2_2 in r9 for later use
	;}
	
	;State: r11 = X4 + sign, r10 = X3_3 + X3_1, r9 = X2_2
	;Task: X3_2, X2_1 = (A_high*B_low)
	;{
		mov rax, rcx ;set a_high as first param
		mul rbp ;a_high * b_low, result in rax (low) and rdx (high) -> rax is x2_1 and rdx is X3_2
		add r10, rdx ;add X3_2 to X3_3 + X3_1 need to react to carry if any
		adc r11, 0 ;add carry to X4 if any
		;State: r11 = X4 + sign, r10 = X3_3 + X3_2 + X3_1, r9 = X2_2
		add r9, rax ;add X2_1 to X2_2 need to react to carry if any
		adc r10, 0 ;add carry to X3 if any, need to react to carry if any
		adc r11, 0 ;add carry to X4 if any
	;}

	;State: r11 = X4 + sign, r10 = X3_3 + X3_2 + X3_1, r9 = X2_2 + X2_1 | a_high, b_low not needed anymore --> rcx, r8 free to use 
	;Task: X2_3, X1 = (A_low*B_low)
	;{
		mov rax, rbx ;set a_low as first param
		mul rbp ;a_low * b_low, result in rax (low) and rdx (high) -> rax is X1 and rdx is X2_3 -> rax ignored
		add r9, rdx ;add X2_3 to X2_2 + X2_1 need to react to carry if any
		adc r10, 0 ;add carry to X3 if any
		adc r11, 0 ;add carry to X4 if any
	;}

	;State: r11 = X4 + sign, r10 = X3_3 + X3_2 + X3_1, r9 = X2_1 + X2_2 + X2_3 | a and b not needed anymore --> rbx, rcx, rbp, r8 free to use
	;Task save sign removing is not needed as X4 will be shifted to the anyway
	;{
		mov rcx, 8000000000000000h ;set Mask
		and rcx, r11 ;keep mask/sign if X4 has the sign bit, else rbx will be 0
	;}

	;State: rcx = sing, r11 = X4 + sign, r10 = X3_3 + X3_2 + X3_1, r9 = X2_1 + X2_2 + X2_3 | rbx, rbp, r8 free to use
	;Task: Shift X4, X3 6bit to the left with X3 and X2 as filler
	;{
		shld r11, r10, 6 ;shift X4 left with X3 as filler
		shld r10, r9, 6 ;shift X3 left with X2 as filler
	;}

	;State: r11 result high (without sign), r10 result low, rcx = sign
	;Task add sign back to the result if needed, and move to final result registers
	;{
		or rcx, r11 ;add sign back to the high part of the result if needed
		mov rbx, r10 ;move low part to final result register
	;}

	;Exit
	jmp r15

; ---------- Function: MulFint direct -----------------------------------
; Multiplies a fixed-point number with an integer
; a_low: rbx (64bit after dot)
; a_high: rcx (1bit sign, 5bit pre dot, 122 bit after dot)
; b_int: rbp (64bit after dot)
; result_low: rbx
; result_high: rcx
; free_to_use: rax, rdx, r8, r9, r10, r11
Function_MulFint:

	;Task: get resulting sign (r11 signbit)
	;{
		mov rax, 8000000000000000h ;mask for sign bit
		mov r11, rcx
		and r11, rax ;extract a's sign bit
		xor r11, rbp ;combine with b's sign bit (xor -> one sign result in negative, two in positive, none in positive)
		and r11, rax ;extract combined sign bit
	;}

	;Task: invert b if b is negative
	;{
		test rbp, rax ;test is neg
		jz mulfint_b_not_neg
		neg rbp       ;invert b if negative
		mulfint_b_not_neg:
	;}

	;Task: remove sign bit from a
	;{
		not rax 	  ;invert mask for removing sign bit
		and rcx, rax ;remove sign bit from a
	;}


	;Number structure:
	; A = A_high * 2^64 + A_low
	; B = 64 bit int
	;-----------------------------------------------------------------------------------------------------------------------------
	;Raw mathematical product:
	; A * B = (A_low * B)          <-- (low part)     
	;       + (A_high * B) * 2^64  <-- (high part)     
	; As B is an integer, the dot does not move
	; The result is a 192-bit number of which the high 65 bits should never be reached given our number range
	; Y2 = X2
	; Y1 = X1
	;-----------------------------------------------------------------------------------------------------------------------------
	;Computation:
	; X3, X2_1 = (A_high*B)
	; X2_2, X1 = (A_low*B)
	;
	; X3 = X3									<--- ignored (to large for our number range)
	; x2 = X2_1 + X2_2							<--- carry can be ignored
	; X1 = X1
	;-----------------------------------------------------------------------------------------------------------------------------

	;Task: X3, X2_1 = (A_high*B)
	;{
		mov rax, rcx ;set a_high as first param
		mul rbp ;a_high * b_high, result in rax (low) and rdx (high) -> rax is X2_1 and rdx is X3 (ignored)
		mov rcx, rax ;store X2_1 in rcx for later use, (a_high overwritten as its not needed anymore and rcx is result_high)
	;}

	;State: r11 = sign, rcx = X2_1
	;Task: X2_2, X1 = (A_low*B)
	;{
		mov rax, rbx ;set a_low as first param
		mul rbp ;a_low * b, result in rax (low) and rdx (high) -> rax is X1 and rdx is X2_2
		add rcx, rdx ;add X2_2 to X2_1
		mov rbx, rax ;store X1 in rbx (rbx is result_low)
	;}

	;State: r11 = sign, rcx = X2_1 + X2_2, rbx = X1
	;Task: Add back Sign
	;{
		or rcx, r11 ;add back sign to X2
	;}

	;Exit
	jmp r15


; ---------- Function: AddF direct -----------------------------------
; Adds two fixed-point numbers
; a_low: rbx (64bit after dot)
; a_high: rcx (1bit sign, 5bit pre dot, 122 bit after dot)
; b_low: rbp (64bit after dot)
; b_high: r8 (1bit sign, 5bit pre dot, 122 bit after dot)
; result_low: rbx
; result_high: rcx
; free_to_use: rax, rdx, r9, r10, r11
Function_AddF:
	;Needed Steps:
	; 1. remove sign and remember if a or b was negative
	; 2. Case seperation
	; 	case1 both positive -> simple add
	; 	case2 both negative -> simple add + set negative sign (sign of a or b)
	; 	case3 |a| > |b| -> subtract |b| from |a|
	;   	case3_1 a positive, b negative -> set positive sign (sign of larger number = a)
	;		case3_2 a negative, b positive -> set negative sign (sign of larger number = a)
	;	case3 |b| > |a| -> subtract |a| from |b|
	;   	case3_1 a positive, b negative -> set negative sign (sign of larger number = b)
	;		case3_2 a negative, b positive -> set positive sign (sign of larger number = b)

	;Task: find signs
	;{
		mov r9, 8000000000000000h ;mask for sign bit
		mov r10, r9 ; get a_high
		mov r11, r8  ; get b_high
		and r10, r9 ;extract a's sign bit
		and r11, r9 ;extract b's sign bit
	;}

	;State: r11 = sign b, r10 = sign a
	;Task: remove sign bits from a and b
	;{
		xor rcx, r10 ;remove sign bit from a
		xor r8, r11  ;remove sign bit from b
	;}

	;State: r11 = sign b, r10 = sign a, r9 = signmask, a and b absolute values without sign bits
	;Task: case separation based on signs of a and b
	cmp r10, r11 ; test if signs are equal (both positive or both negative)
	jne addf_different_sign
		;Case both signs are equal
		;{
			add rbx, rbp ; add the low parts (already result_low)
			adc rcx, r8  ; add the high parts with carry (already result_high)

			or rcx, r10 ; set sign to the a sign

			jmp addf_end
		;}

	addf_different_sign:
		;Case signs differ
		;{
			;Check if a is greater than b in absolute value
			;{
				cmp rcx, r8 ;compare absolute values of a_high and b_high
				ja addf_a_greater	;above sign less
				jb addf_b_greater  	;below sign less
				cmp rbx, rbp ;compare absolute values of a_low and b_low if high parts are equal
				jb addf_b_greater ;below sign less
				;if low parts are equal, we but it in the a_greater case by default
				addf_a_greater:
				;{
					sub rbx, rbp ;subtract b_low from a_low 			 (already result_low)
					sbb rcx, r8 ;subtract b_high from a_high with borrow (already result_high)
					
					or rcx, r10 ; set sign to the a sign (a=larger number)

					jmp addf_end
				;}
				addf_b_greater:
				;{
					sub rbp, rbx ;subtract a_low from b_low 			 
					sbb r8, rcx ;subtract a_high from b_high with borrow 
					mov rbx, rbp ;move to result_low
					mov rcx, r8 ;move to result_high

					or rcx, r11 ; set sign to the b sign (b=larger number)

					jmp addf_end
				;}
			;}
		;}

	addf_end:
	;Exit
	jmp r15

; ---------- Function: GetIterations direct -----------------------------------
; Calculates the number of iterations for the Mandelbrot set
; a_low: rbx (64bit after dot)								TODO? (Real number part)_low
; a_high: rcx (1bit sign, 5bit pre dot, 122 bit after dot)  TODO? (Real number part)_high
; b_low: rbp (64bit after dot)								TODO? (Imaginary number part)_low
; b_high: r8 (1bit sign, 5bit pre dot, 122 bit after dot)  	TODO? (Imaginary number part)_high
; result_low: rbx (number of iterations -> -1 if not escaped)
; free_to_use: rax, rdx, r9, r10, r11
Function_GetIterations:
	;Task: save Registers
	;{
		push r12
		push r13
		push r14
		push r15 ;return adress
		;rsi is free to use as Draw saves it
	;}

	;Task: reserve Stack and save number to stack
	;{
		sub rsp, 82  ;8*10 + 1*2
		mov qword ptr [rsp+2], rbx ;num_real_low (64 bit)
		mov qword ptr [rsp+10], rcx ;num_real_high (64 bit)
		mov qword ptr [rsp+18], rbp ;num_imag_low (64 bit)
		mov qword ptr [rsp+26], r8 ;num_image_high (64 bit)
	;}
	
	;Task: initialize iteration counter/return value and set z0
	;{
		mov word ptr [rsp+0], -1   ;default return + counter for iterations (16 bit)
		xor rsi, rsi  ;z0_real_low = 0
		xor r12, r12  ;z0_real_high = 0
		xor r13, r13  ;z0_imag_low = 0
		xor r14, r14  ;z0_imag_high = 0
	;}

	;State: (rsi, r12) = zn_real_(low/high) 
	;		(r13, r14) = zn_imag_(low/high) 
	;		[SP+0] = iteration counter / return value (16 bit)
	;		([SP+2], [SP+10]) = num_real_(low/high)
	;		([SP+18], [SP+26]) = num_imag_(low/high)
	;Task: loop till maximum iterations or escape condition is met
	;{
	getit_loop:
		;State: (rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;Task: zn_real*zn_real -> zn_real^2
		;{
			mov rbx, rsi							;a_low = zn_real_low
			mov rcx, r12							;a_high = zn_real_high
			mov rbp, rsi							;b_low = zn_real_low
			mov r8, r12								;b_high = zn_real_high
			lea r15, ReturnAdress_GetIterations_1   ;save return adress
			jmp Function_MulF 						;zn_real*zn_real
			ReturnAdress_GetIterations_1:
			mov qword ptr [rsp+34], rbx 			;save (zn_real*zn_real)_low
			mov qword ptr [rsp+42], rcx 			;save (zn_real*zn_real)_high
		;}

		;State: (rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;Task: zn_imag*zn_imag -> zn_imag^2
		;{
			mov rbx, r13							;a_low = zn_imag_low
			mov rcx, r14							;a_high = zn_imag_high
			mov rbp, r13							;b_low = zn_imag_low
			mov r8, r14								;b_high = zn_imag_high
			lea r15, ReturnAdress_GetIterations_2   ;save return adress
			jmp Function_MulF 						;zn_imag*zn_imag
			ReturnAdress_GetIterations_2:
			mov qword ptr [rsp+50], rbx 			;save (zn_imag*zn_imag)_low
			mov qword ptr [rsp+58], rcx 			;save (zn_imag*zn_imag)_high
		;}

		;State: (rbx, rcx) = (zn_imag*zn_imag)_low/high
		;		(rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;		([SP+50], [SP+58]) = (zn_imag*zn_imag)_low/high
		;Task: zn_real*zn_real + zn_imag*zn_imag
		;{
													;a_low = (zn_imag*zn_imag)_low
													;a_high = (zn_imag*zn_imag)_high
			mov rbp, qword ptr [rsp+34]				;b_low = (zn_real*zn_real)_low
			mov r8, qword ptr [rsp+42]				;b_high = (zn_real*zn_real)_high
			lea r15, ReturnAdress_GetIterations_3   ;save return adress
			jmp Function_AddF 						;zn_real*zn_real + zn_imag*zn_imag
			ReturnAdress_GetIterations_3:
		;}

		;State: (rbx, rcx) = (zn_real*zn_real + zn_imag*zn_imag)_low/high
		;		(rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;		([SP+50], [SP+58]) = (zn_imag*zn_imag)_low/high
		;Task: Check --> [(zn_real*zn_real + zn_imag*zn_imag) - ((escape threshold)^2)] >= 0
		;{
													;a_low = (zn_real*zn_real + zn_imag*zn_imag)_low
													;a_high = (zn_real*zn_real + zn_imag*zn_imag)_high
			xor rbp, rbp							;b_low = 0											
			mov r8, 9000000000000000h				;b_high = -4 = -2^2  -> escape threshold for Mandelbrot set squared and negated
			lea r15, ReturnAdress_GetIterations_4   ;save return adress
			jmp Function_AddF						;(zn_real*zn_real + zn_imag*zn_imag) - ((escape threshold)^2)
			ReturnAdress_GetIterations_4:
			mov rax, 8000000000000000h				;sign mask
			test rcx, rax							;check if result is negative (escaped) -> |zn| > 2
			je getit_end
		;}

		;State: (rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;		([SP+50], [SP+58]) = (zn_imag*zn_imag)_low/high
		;Task: zn_real*zn_real - zn_imag*zn_imag
		;{
			mov rbx, qword ptr [rsp+34]				;a_low = (zn_real*zn_real)_low
			mov rcx, qword ptr [rsp+42]				;a_high = (zn_real*zn_real)_high
			mov rbp, qword ptr [rsp+50]				;b_low = +-(zn_imag*zn_imag)_low
			mov r8, qword ptr [rsp+58]				;b_high = +(zn_imag*zn_imag)_high
			mov rax, 8000000000000000h				;sign mask
			xor r8, rax								;b_high = -(zn_imag*zn_imag)_high
			lea r15, ReturnAdress_GetIterations_5   ;save return adress
			jmp Function_AddF 						;zn_real*zn_real - zn_imag*zn_imag
			ReturnAdress_GetIterations_5:
		;}

		;State: (rbx, rcx) = (zn_real*zn_real - zn_imag*zn_imag)_(low/high)
		;		(rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;		([SP+50], [SP+58]) = (zn_imag*zn_imag)_low/high
		;Task: (zn_real*zn_real - zn_imag*zn_imag) + num_real
		;{
													;a_low = (zn_real*zn_real - zn_imag*zn_imag)_low
													;a_high = (zn_real*zn_real - zn_imag*zn_imag)_high
			mov rbp, qword ptr [rsp+2]				;b_low = num_real_low
			mov r8, qword ptr [rsp+10]				;b_high = num_real_high
			lea r15, ReturnAdress_GetIterations_6   ;save return adress
			jmp Function_AddF						;(zn_real*zn_real - zn_imag*zn_imag) + num_real
			ReturnAdress_GetIterations_6:
			mov qword ptr [rsp+66], rbx				;((zn_real*zn_real - zn_imag*zn_imag) + num_real)_low
			mov qword ptr [rsp+74], rcx				;((zn_real*zn_real - zn_imag*zn_imag) + num_real)_high
		;}

		;State: (rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;		([SP+50], [SP+58]) = (zn_imag*zn_imag)_low/high
		;		([SP+66], [SP+74]) = ((zn_real*zn_real - zn_imag*zn_imag) + num_real)_low/high
		;Task: zn_real * zn_imag
		;{
			mov rbx, rsi							;a_low = zn_real_low
			mov rcx, r12							;a_high = zn_real_high
			mov rbp, r13							;b_low = zn_imag_low
			mov r8, r14								;b_high = zn_imag_high
			lea r15, ReturnAdress_GetIterations_7   ;save return adress
			jmp Function_MulF						;zn_real * zn_imag
			ReturnAdress_GetIterations_7:
		;}

		;State: (rbx, rcx) = (zn_real * zn_imag)_low/high
		;		(rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;		([SP+50], [SP+58]) = (zn_imag*zn_imag)_low/high
		;		([SP+66], [SP+74]) = ((zn_real*zn_real - zn_imag*zn_imag) + num_real)_low/high
		;Task: 2 * (zn_real * zn_imag)
		;{
													;a_low = (zn_real * zn_imag)_low
													;a_high = (zn_real * zn_imag)_high
			mov rbp, rbx							;b_low = (zn_real * zn_imag)_low		
			mov r8, rcx								;b_high = (zn_real * zn_imag)_high
			lea r15, ReturnAdress_GetIterations_8   ;save return adress
			jmp Function_AddF						;2 * (zn_real * zn_imag)
			ReturnAdress_GetIterations_8:
		;}

		;State: (rbx, rcx) = (2* zn_real * zn_imag)_low/high
		;		(rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;		([SP+50], [SP+58]) = (zn_imag*zn_imag)_low/high
		;		([SP+66], [SP+74]) = ((zn_real*zn_real - zn_imag*zn_imag) + num_real)_low/high
		;Task: 2 * (zn_real * zn_imag) + num_imag
		;{
													;a_low = (2* zn_real * zn_imag)_low
													;a_high = (2* zn_real * zn_imag)_high
			mov rbp, qword ptr [rsp+18]				;b_low = num_imag__low
			mov r8, qword ptr [rsp+26]				;b_high = num_imag__high
			lea r15, ReturnAdress_GetIterations_9   ;save return adress
			jmp Function_AddF						;2 * (zn_real * zn_imag) + num_imag
			ReturnAdress_GetIterations_9:

		;}

		;State: (rbx, rcx) = ((2* zn_real * zn_imag) + num_imag)_low/high
		;		(rsi, r12) = zn_real_(low/high) 
		;		(r13, r14) = zn_imag_(low/high) 
		;		[SP+0] = iteration counter / return value (16 bit)
		;		([SP+2], [SP+10]) = num_real_(low/high)
		;		([SP+18], [SP+26]) = num_imag_(low/high)
		;		([SP+34], [SP+42]) = (zn_real*zn_real)_low/high
		;		([SP+50], [SP+58]) = (zn_imag*zn_imag)_low/high
		;		([SP+66], [SP+74]) = ((zn_real*zn_real - zn_imag*zn_imag) + num_real)_low/high
		;Task: set zn+1 --> real: (zn_real*zn_real - zn_imag*zn_imag) + num_real    |    imag: 2 * (zn_real * zn_imag) + num_imag
		;{
			mov r13, rbx							;zn+1_imag_low = ((2* zn_real * zn_imag) + num_imag)_low
			mov r14, rcx							;zn+1_imag_high = ((2* zn_real * zn_imag) + num_imag)_high
			mov rsi, qword ptr [rsp+66]				;zn+1_real_low = ((zn_real*zn_real - zn_imag*zn_imag) + num_real)_low
			mov r12, qword ptr [rsp+74]				;zn+1_real_high = ((zn_real*zn_real - zn_imag*zn_imag) + num_real)_high
		;}
	;}
	;Task: increment iteration counter and check against maximum
	;{
		mov ax, word ptr [rsp+0] 	;load Counter
		inc ax  					;increment iteration counter
		mov word ptr [rsp+0], ax	;save Counter
		cmp ax, 32					;check if maximum is reached
		jl getit_loop				;if maximum iterations not reached, continue loop
		mov word ptr [rsp+0], -1	;if maximum iterations reached, set to -1 (inside)
	;}

	getit_end:
	;Task: set return value in rbx
	;{
		movsx rbx, word ptr [rsp+0] 				;set return (2byte to 8bytes)
	;}

	;Task: restore Stack
	;{
		add rsp, 82
	;}

	;Task: restore Registers
	;{
		pop r15
		pop r14
		pop r13
		pop r12 ;return adress
	;}

	;Exit
	jmp r15


; ---------- Function: RecreateBitmap -----------------------------------
; Recreates the bitmap for drawing
; Inputs: none
; Output: none
RecreateBitmap PROC
	push rbx
	sub rsp, 30h

	mov rax, qword ptr [ua_hbitmap]
	test rax, rax
	je recreate_skip_delete
	mov rcx, rax
	call DeleteObject
recreate_skip_delete:

	xor ecx, ecx
	lea rdx, ua_bmi
	xor r8d, r8d
	lea r9, ua_bitmapData
	mov qword ptr [rsp+20h], 0
	mov qword ptr [rsp+28h], 0
	call CreateDIBSection
	mov qword ptr [ua_hbitmap], rax

	add rsp, 30h
	pop rbx
	ret
RecreateBitmap ENDP

; ---------- Function: Draw -----------------------------------
; Draws the Mandelbrot set onto the bitmap
; Inputs: none
; Output: none
Draw PROC
	;Task: save registers
	;{
		push rbx
		push rsi
		push rdi
		push rbp
		push r12
		push r13
		push r14
		push r15
		sub rsp, 28h
	;}

	;Task: get bitmap data adress
	;{
		mov r12, qword ptr [ua_bitmapData]
	;}

	;State: r12 = bitmap data Ptr
	;Task: test if bitamp data is Nullptr     TODO: brauche ich das? und funktioniert das ueberhaupt
	;{
		test r12, r12
		je draw_end
	;}


	;State: r12 = bitmap data Ptr
	;Task: get Image height
	;{
		mov r14, qword ptr [ua_height]
	;}
	
	;State: r14 = height, r12 = bitmap data Ptr
	;Task: start outer loop at height - 4
	;{
		sub r14, 4
	;}


	draw_yo_loop:
		;State: r12 = bitmap data Ptr, r14 = y_counter
		;Task: reset x counter, start at width -4
		;{
			mov r13, qword ptr [ua_width]
			sub r13, 4
		;}
		draw_xo_loop:
			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter
			;Task: Compute real y offset --> y*pixelsize
			;{
				mov rbx, qword ptr [a_pixelSize_low]	;a_low = a_pixelSize_low
				mov rcx, qword ptr [a_pixelSize_high]	;a_high = a_pixelSize_high
				mov rbp, r14							;b = y
				lea r15, ReturnAdress_Draw_1   		;save return adress
				jmp Function_MulFint 				;run MulFint with pixelSize_new and y
				ReturnAdress_Draw_1:
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter
			;       rbx = real_y_offset_low, rcx = real_y_offset_high
			;Task: Compute real y pos -->  y*pixelsize + lower_left
			;{
														;a_low = real_y_offset_low				
														;a_high = real_y_offset_high
				mov rbp, qword ptr [a_lowerLeft_y_low]  ;b_low = a_lowerLeft_y_low
				mov r8, qword ptr [a_lowerLeft_y_high]   ;b_high = a_lowerLeft_y_high
				lea r15, ReturnAdress_Draw_2   		;save return adress
				jmp Function_AddF 					;run AddF with y*pixelsize and lower_left
				ReturnAdress_Draw_2:
			;}



			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		rbx = real_y_pos_low, rcx = real_y_pos_high
			;Task: save real_y_pos to stack
			;{
				push rcx ;real_y_pos_high
				push rbx ;real_y_pos_low
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		real_y_pos_low/high on stack
			;Task: Compute real x offset --> x*pixelsize
			;{
				mov rbx, qword ptr [a_pixelSize_low]	;a_low = a_pixelSize_low
				mov rcx, qword ptr [a_pixelSize_high]	;a_high = a_pixelSize_high
				mov rbp, r13							;b = x
				lea r15, ReturnAdress_Draw_3   		;save return adress
				jmp Function_MulFint 				;run MulFint with pixelSize_new and x
				ReturnAdress_Draw_3:
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		real_y_pos_low/high on stack,
			;		rbx = real_x_offset_low, rcx = real_x_offset_high
			;Task: Compute real x pos --> x*pixelsize + lower_left
			;{
														;a_low = real_x_offset_low				
														;a_high = real_x_offset_high
				mov rbp, qword ptr [a_lowerLeft_x_low]  ;b_low = a_lowerLeft_x_low
				mov r8, qword ptr [a_lowerLeft_x_high]  ;b_high = a_lowerLeft_x_high
				lea r15, ReturnAdress_Draw_4   		;save return adress
				jmp Function_AddF 					;run AddF with x*pixelsize and lower_left
				ReturnAdress_Draw_4:
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		real_y_pos_low/high on stack,
			;		rbx = real_x_pos_low, rcx = real_x_pos_high
			;Task: Get Iteratrions for real x and y
			;{
							;a_low = real_x_pos_low				
							;a_high = real_x_pos_high
				pop rbp		;b_low = real_y_pos_low
				pop r8		;b_high = real_y_pos_high
				lea r15, ReturnAdress_Draw_5   		;save return adress
				jmp Function_GetIterations 			;run GetIterations with real x and y
				ReturnAdress_Draw_5:
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		rbx = Iteration (-1 if inside)
			;Task: Check is inside and set color
			;{
				xor ecx, ecx ;set color to 0 for inside pixels (default)
				cmp rbx, -1  ;test if inside
				je draw_color_ready
				and rbx, 0Fh ;Iterations module 16 to get color index
				lea rdx, a_colour_pallet
				mov ecx, dword ptr [rdx + rbx*4]
				draw_color_ready:
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		ecx = Color
			;Task: outer Loop for drawing pixels
				mov rbp, 3	;initialize inner y loop counter to rbp=3
				draw_yi_loop:
				;{
					mov rdi, 3 ;initialize inner x loop counter to rdi=3
					draw_xi_loop:
					;{
						mov rax, r14					;rax = y_counter
						add rax, rbp					;rax = y_sum = y_counter + inner y loop counter
						imul rax, qword ptr [ua_width]	;rax = ua_width * y_sum
						add rax, r13					;rax = ua_width * y_sum + outer_x
						add rax, rdi					;rax = ua_width * y_sum + outer_x + inner_x
						shl rax, 2						;rax = (ua_width * y_sum + outer_x + inner_x)*4
						mov rdx, r12					;rdx = bitmap data Ptr
						add rdx, rax					;rdx = pixel address
						mov dword ptr [rdx], ecx		;pixel = color
					;}
					dec edi ;decrement inner x loop counter
					jge draw_xi_loop
				;}
				dec ebp ;decrement inner y loop counter
				jge draw_yi_loop
				

		;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter
		;Task: Update outer loop counters and check loop conditions
		;{
			sub r13, 4
			jge draw_xo_loop
		;}

	;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter
	;Task: Update outer loop counters and check loop conditions
	;{
		sub r14, 4
		jge draw_yo_loop
	;}

draw_end:
	;Task: Restore saved Registers and SP
	;{
		add rsp, 28h
		pop r15
		pop r14
		pop r13
		pop r12
		pop rbp
		pop rdi
		pop rsi
		pop rbx
	;}

	;Task: Return
	;{
		ret
	;}
Draw ENDP

; ---------- Function: WndProc -----------------------------------
; Window procedure for handling messages
; Inputs: rcx = hwnd, rdx = uMsg, r8 = wParam, r9 = lParam
; Output: eax = result
WndProc PROC
	cmp edx, 020Ah
	je wndProc_mousewheel

	cmp edx, 0200h
	je wndProc_mousemove

	cmp edx, 0005h
	je wndProc_size

	cmp edx, 000Fh
	je wndProc_paint

	cmp edx, 2
	jne wndProc_default

	sub rsp, 28h
	xor ecx, ecx
	;call PostQuitMessage(
	; nExitCode->rcx = 0,
	;)
	call PostQuitMessage
	add rsp, 28h
	xor eax, eax
	ret

wndProc_mousewheel:
	sub rsp, 28h
	;https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousewheel
	;get mouse wheel movement
	mov eax, r8d                   ;64bit-specific
	shr eax, 16                    ;64bit-specific
	movsx eax, ax                  ;64bit-specific
	mov word ptr [a_mouseWheel_state], ax

	;set draw command
	mov byte ptr [a_enable_draw], 1

wndProc_mousewheel_end:
	add rsp, 28h
	xor eax, eax
	ret

wndProc_mousemove:
	mov eax, r9d
	and eax, 0FFFFh
	mov dword ptr [a_mousePos_x], eax

	mov eax, r9d
	shr eax, 16
	mov ecx, 600
	sub ecx, eax
	dec ecx
	mov dword ptr [a_mousePos_y], ecx

	xor eax, eax
	ret

wndProc_size:
	sub rsp, 38h
	mov [rsp+30h], rcx

	lea rdx, ua_rect
	;call GetClientRect(
	; hWnd->rcx = hwnd,
	; lpRect->rdx = ua_rect,
	;)
	call GetClientRect

	mov dword ptr [ua_width], 800
	mov dword ptr [ua_height], 600
	mov dword ptr [ua_bmi+4], 800
	mov dword ptr [ua_bmi+8], 600

	mov dword ptr [ua_bmi], 40
	mov word ptr [ua_bmi+12], 1
	mov word ptr [ua_bmi+14], 32
	mov dword ptr [ua_bmi+16], 0
	mov dword ptr [ua_bmi+20], 0
	mov dword ptr [ua_bmi+24], 0
	mov dword ptr [ua_bmi+28], 0
	mov dword ptr [ua_bmi+32], 0
	mov dword ptr [ua_bmi+36], 0
	mov dword ptr [ua_bmi+40], 0

	xor ecx, ecx
	lea rdx, ua_bmi
	xor r8d, r8d
	lea r9, ua_bitmapData
	mov qword ptr [rsp+20h], 0
	mov qword ptr [rsp+28h], 0
	;call CreateDIBSection(
	; hdc->rcx = NULL,
	; pbmi->rdx = ua_bmi,
	; iUsage->r8 = DIB_RGB_COLORS,
	; ppvBits->r9 = ua_bitmapData,
	; hSection->rsp+20h = NULL,
	; dwOffset->rsp+28h = 0,
	;)
	call CreateDIBSection
	mov qword ptr [ua_hbitmap], rax

	mov r10, qword ptr [ua_bitmapData]
	test r10, r10
	je wndProc_size_end
	call Draw

wndProc_size_end:
	mov rcx, [rsp+30h]
	add rsp, 38h
	xor eax, eax
	ret

wndProc_paint:
	sub rsp, 58h
	mov [rsp+50h], rcx
	lea rdx, ua_rect
	;call GetClientRect(
	; hWnd->rcx = hwnd,
	; lpRect->rdx = ua_rect,
	;)
	call GetClientRect
	mov rcx, [rsp+50h]

	lea rdx, ua_ps
	;call BeginPaint(
	; hWnd->rcx = hwnd,
	; lpPaint->rdx = ua_ps,
	;)
	call BeginPaint
	mov qword ptr [ua_hdcPaint], rax

	mov rax, qword ptr [ua_hbitmap]
	test rax, rax
	je wndProc_paint_end

	mov rcx, qword ptr [ua_hdcPaint]
	;call CreateCompatibleDC(
	; hdc->rcx = ua_hdcPaint,
	;)
	call CreateCompatibleDC
	mov qword ptr [ua_hdcMem], rax

	mov rcx, rax
	mov rdx, qword ptr [ua_hbitmap]
	;call SelectObject(
	; hdc->rcx = ua_hdcMem,
	; h->rdx = ua_hbitmap,
	;)
	call SelectObject

	mov rcx, qword ptr [ua_hdcPaint]
	xor edx, edx
	xor r8d, r8d
	mov r9d, dword ptr [ua_rect+8]
	sub r9d, dword ptr [ua_rect]
	mov eax, dword ptr [ua_rect+12]
	sub eax, dword ptr [ua_rect+4]
	mov qword ptr [rsp+20h], rax
	mov rax, qword ptr [ua_hdcMem]
	mov qword ptr [rsp+28h], rax
	xor rax, rax
	mov qword ptr [rsp+30h], rax
	mov qword ptr [rsp+38h], rax
	mov qword ptr [rsp+40h], 0CC0020h
	;call BitBlt(
	; hdc->rcx = ua_hdcPaint,
	; x->rdx = 0,
	; y->r8 = 0,
	; cx->r9 = client width,
	; cy->rsp+20h = client height,
	; hdcSrc->rsp+28h = ua_hdcMem,
	; x1->rsp+30h = 0,
	; y1->rsp+38h = 0,
	; rop->rsp+40h = SRCCOPY,
	;)
	call BitBlt

wndProc_paint_end:
	mov rcx, qword ptr [ua_hdcMem]
	test rcx, rcx
	je wndProc_paint_skip_deletedc
	call DeleteDC
wndProc_paint_skip_deletedc:

	mov rcx, qword ptr [ua_hwnd]
	lea rdx, ua_ps
	;call EndPaint(
	; hWnd->rcx = ua_hwnd,
	; lpPaint->rdx = ua_ps,
	;)
	call EndPaint
	add rsp, 58h
	xor eax, eax
	ret

wndProc_default:
	sub rsp, 28h
	;call DefWindowProcA(
	; hWnd->rcx = hwnd,
	; Msg->rdx = uMsg,
	; wParam->r8 = wParam,
	; lParam->r9 = lParam,
	;)
	call DefWindowProcA
	add rsp, 28h
	ret
WndProc ENDP

; ---------- Function: start -----------------------------------
; Entry point for the application
; Inputs: none
; Output: none
start PROC
	;save nonvolatile register
	push r15
	push r14
	push r13
	push r12
	push rbx

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;; Get Module Handle
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	xor rcx, rcx

	;call GetModuleHandleA(
	; lpModuleName->rcx = NULL,
	;)
	call GetModuleHandleA

	;save return value
	mov qword ptr [ua_hInstance], rax

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;; Registering the Window Class
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	lea rbx, ua_wc
	mov dword ptr [rbx+WC_cbSize], 80
	mov dword ptr [rbx+WC_style], 0
	lea rax, WndProc
	mov qword ptr [rbx+WC_lpfnWndProc], rax
	mov dword ptr [rbx+WC_cbClsExtra], 0
	mov dword ptr [rbx+WC_cbWndExtra], 0
	mov rax, qword ptr [ua_hInstance]
	mov qword ptr [rbx+WC_hInstance], rax

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	xor rcx, rcx
	mov edx, 7F00h

	;call LoadIconA(
	; hInstance->rcx = NULL,
	; lpIconName->rdx = IDI_APPLICATION,
	;)
	call LoadIconA

	;save return value
	mov qword ptr [rbx+WC_hIcon], rax
	mov qword ptr [rbx+WC_hIconSm], rax

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	xor rcx, rcx
	mov edx, 7F00h

	;call LoadCursorA(
	; hInstance->rcx = NULL,
	; lpCursorName->rdx = IDC_ARROW,
	;)
	call LoadCursorA

	;save return value
	mov qword ptr [rbx+WC_hCursor], rax

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	mov qword ptr [rbx+WC_hbrBackground], 6
	mov qword ptr [rbx+WC_lpszMenuName], 0
	lea rax, g_szClassName
	mov qword ptr [rbx+WC_lpszClassName], rax

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	lea rcx, ua_wc

	;call RegisterClassExA(
	; lpwcx->rcx = ua_wc,
	;)
	call RegisterClassExA

	;restore stack pointer
	mov rsp, rsi ;restore stack pointer

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;; Create Window
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 96 ;allocate shadow space for the call (32) + space for additional parameters on the stack (64)

	;call params
	mov rcx, 200h
	lea rdx, g_szClassName
	lea r8, c_window_title
	mov r9, 0A0000h
	mov qword ptr [rsp+32], 80000000h
	mov qword ptr [rsp+40], 80000000h
	mov qword ptr [rsp+48], 800
	mov qword ptr [rsp+56], 600
	mov qword ptr [rsp+64], 0
	mov qword ptr [rsp+72], 0
	mov rax, qword ptr [ua_hInstance]
	mov qword ptr [rsp+80], rax
	mov qword ptr [rsp+88], 0

	;call CreateWindowExA(
	; dwExStyle->rcx = 200h,
	; lpClassName->rdx = g_szClassName, TODO could be NULL?
	; lpWindowName->r8 = c_window_title,
	; dwStyle->r9 = 0A0000h,
	; X->rsp+32 (int) = 80000000h,
	; Y->rsp+40 (int) = 80000000h,
	; nWidth->rsp+48 (int) = 800,
	; nHeight->rsp+56 (int) = 600,
	; hWndParent->rsp+64 (HWND) = 0,
	; hMenu->rsp+72 (HMENU) = 0,
	; hInstance->rsp+80 (HINSTANCE) = ua_hInstance,
	; lpParam->rsp+88 (LPVOID) = 0,
	;)
	call CreateWindowExA

	;save return value
	mov qword ptr [ua_hwnd], rax

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;; Show Window
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	mov rcx, qword ptr [ua_hwnd]
	mov edx, 1

	;call ShowWindow(
	; hWnd->rcx = ua_hwnd,
	; nCmdShow->rdx = SW_SHOWNORMAL,
	;)
	call ShowWindow

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	mov rcx, qword ptr [ua_hwnd]

	;call SetFocus(
	; hWnd->rcx = ua_hwnd,
	;)
	call SetFocus

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;; The Message Loop
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

winMain_loop:
	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	lea rcx, ua_msg
	xor edx, edx
	xor r8d, r8d
	xor r9d, r9d

	;call GetMessageA(
	; lpMsg->rcx = ua_msg,
	; hWnd->rdx = NULL,
	; wMsgFilterMin->r8 = 0,
	; wMsgFilterMax->r9 = 0,
	;)
	call GetMessageA

	;save return value
	mov ebx, eax

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	test ebx, ebx
	je winMain_exit

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	lea rcx, ua_msg

	;call TranslateMessage(
	; lpMsg->rcx = ua_msg,
	;)
	call TranslateMessage

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	lea rcx, ua_msg

	;call DispatchMessageA(
	; lpMsg->rcx = ua_msg,
	;)
	call DispatchMessageA

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

	mov al, byte ptr [a_enable_draw]
	test al, al
	je winMain_if_draw_end
	mov byte ptr [a_enable_draw], 0

	movsx eax, word ptr [a_mouseWheel_state]
	test eax, eax
	je winMain_setzoom_end

	;SetZoom
	;64bit-specific
	movsx eax, word ptr [a_mouseWheel_state]
	test eax, eax
	;registers used: None
	;registers free: rax, rbx, rcx, rdx, rdi, rbp, r8, r9, r10, r11, [r12], [r13], [r14]
	js SetZoom_zoom_in
	;{
		mov rcx, qword ptr [a_zoom_factor_out_high] ;set a_high to zoom_factor_out_high
		jmp SetZoom_zoom_end
	;}
SetZoom_zoom_in:
	;{
		mov rcx, qword ptr [a_zoom_factor_in_high] ;set a_high to zoom_factor_in_high
	;}
SetZoom_zoom_end:

	;Overall Task: Compute new lower left new
	;Variables:
	; old_pixelSize (.data)
	; new_pixelSize (r13, r14)
	; pixelSize_max (.data)
	; pixelSize_min (.data)
	; mousePos_x (.data)
	; mousePos_y (.data)
	; image width = 800
	; image height = 600
	; lower_left_x_old
	; lower_left_y_old
	; lower_left_x_new
	; lower_left_y_new
	; lower_left_x_min (.data)
	; lower_left_y_min (.data)
	; upper_right_max_x (.data)
	; upper_right_max_y (.data)
	;
	;Logic:
	; The real positon (pixelsize * mousePos) of the mouse must stay the same after zoom
	; Old mouse Pos = lower_left_old + pixelSize_old * mousePos
	; New mouse Pos = lower_left_new + pixelSize_new * mousePos
	; Old mouse Pos = New mouse Pos
	; lower_left_old + pixelSize_old * mousePos = lower_left_new + pixelSize_new * mousePos
	; lower_left_new = lower_left_old + (pixelSize_old - pixelSize_new) * mousePos
	;
	;Bound checking:
	; Ensure that lower_left_new stays within the image boundaries
	; if lower_left_new < lower_left_min -> lower_left_new = lower_left_min
	; if lower_left_new + image_size * pixelSize_new > upper_right_max:
	; 		shiftVal = (lower_left_new + image_size * pixelSize_new) - upper_right_max
	;			if shiftVal >= 0 -> do Nothing
	;			if shiftVal < 0 -> lower_left_new = lower_left_new + shiftVal
	;
	; Formulars need to be split into x and y components
	;
	; Start State: rcx = a_high = high part of zoom_factor

	;State: rcx = a_high = high part of zoom_factor
	;Task: Compute new pixel size after zoom
	;{
		xor rbx, rbx 							;set a_low to 0 (a_low of zoom_factor)
												;a_high already set (a_high of zoom_factor)
		mov rbp, qword ptr [a_pixelSize_low]	;set b_low to pixelSize_low
		mov r8, qword ptr [a_pixelSize_high]	;set b_high to pixelSize_high
		lea r15, ReturnAddress_ComputeNewPixelSize ;save return adress
		jmp Function_MulF 						;run MulF with zoom_factor and pixel_size
	ReturnAddress_ComputeNewPixelSize:		
	;}

	;State: rbx = pixelSize_new_low, rcx = pixelSize_new_high
	;Task: Compare new pixel size with minimum allowed pixel size and adjust if necessary
	;{
		;Check if high is zero
		mov rax, 7FFFFFFFFFFFFFFFh
		test rax, rcx 						  ;check if high part of pixel size is zero
		jnz ComputePixelSize_toSmallCheck_end ;if high part is not zero, number is large enough
		mov rax, qword ptr [a_pixelSize_min_low]
		cmp rax, rbx
		jle ComputePixelSize_toSmallCheck_end ;if a_pixelSize_min_low is <= pixelSize_low, number is large enough
		mov rbx, qword ptr [a_pixelSize_min_low] ;set pixelSize_low to minimum allowed value
		xor rcx, rcx								;set pixelSize_high to 0 (minimum allowed value)
		ComputePixelSize_toSmallCheck_end:
	;}

	;State: rbx = pixelSize_low, rcx = pixelSize_high (Value is bounded by minimum allowed pixel size)
	;Task: Compare new pixel size with maximum allowed pixel size and adjust if necessary
	;{
		mov rax, qword ptr [a_pixelSize_max_high]
		cmp rcx, rax
		jle ComputePixelSize_toBigCheck_end ;if high part is less than or equal to max, number is within bounds
		mov rcx, rax 						;set high part of pixel size to maximum allowed value
		xor rbx, rbx						;set low part of pixel size to 0 (maximum allowed value)
		ComputePixelSize_toBigCheck_end:
	;}

	;State: rbx = pixelSize_low, rcx = pixelSize_high (Value is bounded by min/max pixel size bounds)
	;Task: Store the new pixel size in the appropriate variable
	;{
		mov r13, rbx	;store pixelSize_new_low in r13
		mov r14, rcx	;store pixelSize_new_high in r14
	;}

	;---------------- New Lower Left X section ---------------------------------------------------------------------

	;State: r13, rbx = pixelSize_new_low, r14, rcx = pixelSize_new_high
	;Task: lower_left_new_x = lower_left_old_x + (pixelSize_old_x - pixelSize_new_x) * mousePos_x
	;{
		;State: r13, rbx = pixelSize_new_low, r14, rcx = pixelSize_new_high
		;Task: pixelSize_old_x - pixelSize_new_x = -pixelSize_new_x + pixelSize_old_x
		;{
			mov rax, 8000000000000000h 				;mask for sign bit
													;a_low = +-pixelSize_new_low
			xor rcx, rax 							;a_high = -pixelSize_new_high
			mov rbp, qword ptr [a_pixelSize_low]	;b_low = pixelSize_old_low
			mov r8, qword ptr [a_pixelSize_high]	;b_high = pixelSize_old_high

			lea r15, ReturnAddress_ComputeNewLL_X_1 ;save return adress
			jmp Function_AddF 						;run MulF with zoom_factor and pixel_size
			ReturnAddress_ComputeNewLL_X_1:		
		;} 

		;State rbx = (pixelSize_old_x - pixelSize_new_x)_low, rcx = (pixelSize_old_x - pixelSize_new_x)_high
		;Task: (pixelSize_old_x - pixelSize_new_x) * mousePos_x
		;{
													;a_low = (pixelSize_old_x - pixelSize_new_x)_low
													;a_high = (pixelSize_old_x - pixelSize_new_x)_high
			mov ebp, dword ptr [a_mousePos_x]		;b = mousePos_x (upper 32bit get automatically filled with zeros)
			lea r15, ReturnAddress_ComputeNewLL_X_2 ;save return adress
			jmp Function_MulFint 					;run MulFint with (pixelSize_old_x - pixelSize_new_x) and mousePosX
			ReturnAddress_ComputeNewLL_X_2:	
		;}

		;State rbx = ((pixelSize_old_x - pixelSize_new_x) * mousePos_x)_low, rcx = ((pixelSize_old_x - pixelSize_new_x) * mousePos_x)_high
		;Task: lower_left_old_x + (pixelSize_old_x - pixelSize_new_x) * mousePos_x
		;{
													;a_low = (pixelSize_old_x - pixelSize_new_x)_low * mousePos_x
													;a_high = (pixelSize_old_x - pixelSize_new_x)_high * mousePos_x
			mov rbp, qword ptr [a_lowerLeft_x_low]	;b_low = lower_left_old_x
			mov r8, qword ptr [a_lowerLeft_x_high]	;b_high = lower_left_old_x
			lea r15, ReturnAddress_ComputeNewLL_X_3 ;save return adress
			jmp Function_AddF 					    ;run AddF with (pixelSize_old_x - pixelSize_new_x) * mousePosX and lower_left_old
			ReturnAddress_ComputeNewLL_X_3:	
		;}
	;}

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_x_low, rcx = lower_left_new_x_high
	;Task: Save lower_left_new_x to memory (as lower_left_old_x is no longer needed for further calculations it can be overwritten)
	;{
		mov qword ptr [a_lowerLeft_x_low], rbx  ;overwrite lower_left_old_x_low with lower_left_new_x_low
		mov qword ptr [a_lowerLeft_x_high], rcx ;overwrite lower_left_old_x_high with lower_left_new_x_high
	;}

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_x_low, rcx = lower_left_new_x_high 
	;Task: Bound lower_left_new_x to min and max
	;{
		;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_x_low, rcx = lower_left_new_x_high
		;Task: Bound lower_left_new_x to min
		;{
			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_x_low, rcx = lower_left_new_x_high
			;Task: Check lower_left_new_x >= 0 --> is larger than min bound (min bound is negative) 
			;{
				mov rax, 8000000000000000h 	;mask for sign bit
				test rcx, rax				;test sign is set
				jz BoundNewLL_X_4
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_x_low, rcx = lower_left_new_x_high, rax sign mask
			;Task: Check |lower_left_new_x| >= |a_lowerLeft_x_min_high|
			;{
				not rax										;mask for removing sign
				mov r9, rcx									;save lower_left_new_x_high before removing sign
				and r9, rax									;remove sign from lower_left_new_x_high
				mov r10, qword ptr [a_lowerLeft_x_min_high] 
				and rax, r10								;remove sign from a_lowerLeft_x_min_high
				cmp r9, rax									;compare |lower_left_new_x_high| with |a_lowerLeft_x_min_high|
				jge BoundNewLL_X_4							;number is in bound

				mov qword ptr [a_lowerLeft_x_low], 0  	 								;set lower_left_x_low to 0
				mov qword ptr [a_lowerLeft_x_high], r10 	;set lower_left_x_high to min bound
			;}
			BoundNewLL_X_4:
		;}

		;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
		;shiftVal = (lower_left_new + image_size * pixelSize_new) - upper_right_max
		;Task: Bound lower_left_new_x to max
		;{
			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
			;Task: image_size * pixelSize_new
			;{
				mov rbx, r13 							;a_low = pixelSize_new_low
				mov rcx, r14 							;a_high = pixelSize_new_high
				mov rbp, qword ptr [ua_width] 			;b = ua_width (Image width)
				lea r15, ReturnAddress_BoundNewLL_X_5   ;save return adress
				jmp Function_MulFint 					;run MulFint with pixelSize_new and image_size
				ReturnAddress_BoundNewLL_X_5:
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, 
			;		rbx = (image_size * pixelSize_new)_low, rcx = (image_size * pixelSize_new)_high
			;Task: lower_left_new + image_size * pixelSize_new
			;{
														;a_low = (image_size * pixelSize_new)_low
														;a_high = (image_size * pixelSize_new)_high
				mov rbp, qword ptr [a_lowerLeft_x_low]  ;b_low = lower_left_new_x_low
				mov r8, qword ptr [a_lowerLeft_x_high]  ;b_high = lower_left_new_x_high
				lea r15, ReturnAddress_BoundNewLL_X_6   ;save return adress
				jmp Function_AddF						;run AddF with image_size * pixelSize_new and lower_left_new
				ReturnAddress_BoundNewLL_X_6:
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, 
			;		rbx = (lower_left_new + image_size * pixelSize_new)_low, rcx = (lower_left_new + image_size * pixelSize_new)_high
			;Task: (lower_left_new + image_size * pixelSize_new) - upper_right_max
			;{
															;a_low = (lower_left_new + image_size * pixelSize_new)_low
															;a_high = (lower_left_new + image_size * pixelSize_new)_high
				xor rbp, rbp								;b_low = upper_right_max_low = 0
				mov rax, 8000000000000000h 	;mask for sign bit
				mov r8, qword ptr [a_upperRight_x_max_high] ;b_high = upper_right_max_high
				xor r8, rax 								;b_high = -upper_right_max_high
				lea r15, ReturnAddress_BoundNewLL_X_7   ;save return adress
				jmp Function_AddF						;run AddF with (lower_left_new + image_size * pixelSize_new) and -upper_right_max
				ReturnAddress_BoundNewLL_X_7:
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, 
			; 		rbx = shiftVal_low, rcx = shiftVal_high
			;Task: Check if shiftVal is negative -> add shift to lower_left_new        else: do nothin is in bound
			;{
				mov rax, 8000000000000000h 	;mask for sign bit
				test rcx, rax
				jz BoundNewLL_X_8 ;if zero -> shiftVal is positive -> do nothing
															;a_low = shift_low
															;a_high = shift_high
				mov rbp, qword ptr [a_lowerLeft_x_low]		;b_low = lower_left_new_x_low
				mov r8, qword ptr [a_lowerLeft_x_high]		;b_high = lower_left_new_x_high
				lea r15, ReturnAddress_BoundNewLL_X_9
				jmp Function_AddF
				ReturnAddress_BoundNewLL_X_9:

				mov qword ptr [a_lowerLeft_x_low], rbx		;store shifted lower_left_new_x_low
				mov qword ptr [a_lowerLeft_x_high], rcx		;store shifted lower_left_new_x_high

				BoundNewLL_X_8:
			;}
		;}
	;}

	;---------------- New Lower Left Y section ---------------------------------------------------------------------

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
	;Task: lower_left_new_y = lower_left_old_y + (pixelSize_old_y - pixelSize_new_y) * mousePos_y
	;{
		;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
		;Task: pixelSize_old_y - pixelSize_new_y = -pixelSize_new_y + pixelSize_old_y
		;{
			mov rcx, r14							;a_high = pixelSize_new_high (different than X because rbx and rcx are different at start)
			mov rax, 8000000000000000h 				;mask for sign bit
			mov rbx, r13							;a_low = +-pixelSize_new_low (different than X because rbx and rcx are different at start)
			xor rcx, rax 							;a_high = -pixelSize_new_high
			mov rbp, qword ptr [a_pixelSize_low]	;b_low = pixelSize_old_low
			mov r8, qword ptr [a_pixelSize_high]	;b_high = pixelSize_old_y_high

			lea r15, ReturnAddress_ComputeNewLL_Y_1 ;save return adress
			jmp Function_AddF 						;run MulF with zoom_factor and pixel_size
			ReturnAddress_ComputeNewLL_Y_1:		
		;} 

		;State rbx = (pixelSize_old_y - pixelSize_new_y)_low, rcx = (pixelSize_old_y - pixelSize_new_y)_high
		;Task: (pixelSize_old_y - pixelSize_new_y) * mousePos_y
		;{
													;a_low = (pixelSize_old_y - pixelSize_new_y)_low
													;a_high = (pixelSize_old_y - pixelSize_new_y)_high
			mov ebp, dword ptr [a_mousePos_y]		;b = mousePos_y (upper 32bit get automatically filled with zeros)
			lea r15, ReturnAddress_ComputeNewLL_Y_2 ;save return adress
			jmp Function_MulFint 					;run MulFint with (pixelSize_old_y - pixelSize_new_y) and mousePosY
			ReturnAddress_ComputeNewLL_Y_2:	
		;}

		;State rbx = ((pixelSize_old_y - pixelSize_new_y) * mousePos_y)_low, rcx = ((pixelSize_old_y - pixelSize_new_y) * mousePos_y)_high
		;Task: lower_left_old_y + (pixelSize_old_y - pixelSize_new_y) * mousePos_y
		;{
													;a_low = (pixelSize_old_y - pixelSize_new_y)_low * mousePos_y
													;a_high = (pixelSize_old_y - pixelSize_new_y)_high * mousePos_y
			mov rbp, qword ptr [a_lowerLeft_y_low]	;b_low = lower_left_old_x
			mov r8, qword ptr [a_lowerLeft_y_high]	;b_high = lower_left_old_x
			lea r15, ReturnAddress_ComputeNewLL_Y_3 ;save return adress
			jmp Function_AddF 					    ;run AddF with (pixelSize_old_y - pixelSize_new_y) * mousePosY and lower_left_old_y
			ReturnAddress_ComputeNewLL_Y_3:	
		;}
	;}

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_y_low, rcx = lower_left_new_y_high
	;Task: Save lower_left_new_y to memory (as lower_left_old_y is no longer needed for further calculations it can be overwritten)
	;{
		mov qword ptr [a_lowerLeft_y_low], rbx  ;overwrite lower_left_old_y_low with lower_left_new_y_low
		mov qword ptr [a_lowerLeft_y_high], rcx ;overwrite lower_left_old_y_high with lower_left_new_y_high
	;}

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_y_low, rcx = lower_left_new_y_high 
	;Task: Bound lower_left_new_y to min and max
	;{
		;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_y_low, rcx = lower_left_new_y_high
		;Task: Bound lower_left_new_y to min
		;{
			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_y_low, rcx = lower_left_new_y_high
			;Task: Check lower_left_new_y >= 0 --> is larger than min bound (min bound is negative) 
			;{
				mov rax, 8000000000000000h 	;mask for sign bit
				test rcx, rax				;test sign is set
				jz BoundNewLL_Y_4
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_y_low, rcx = lower_left_new_y_high, rax sign mask
			;Task: Check |lower_left_new_y| >= |a_lowerLeft_y_min_high|
			;{
				not rax										;mask for removing sign
				mov r9, rcx									;save lower_left_new_y_high before removing sign
				and r9, rax									;remove sign from lower_left_new_y_high
				mov r10, qword ptr [a_lowerLeft_y_min_high] 
				and rax, r10								;remove sign from a_lowerLeft_y_min_high
				cmp r9, rax									;compare |lower_left_new_y_high| with |a_lowerLeft_y_min_high|
				jge BoundNewLL_Y_4							;number is in bound

				mov qword ptr [a_lowerLeft_y_low], 0  	 								;set lower_left_y_low to 0
				mov qword ptr [a_lowerLeft_y_high], r10 	;set lower_left_y_high to min bound
			;}
			BoundNewLL_Y_4:
		;}

		;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
		;shiftVal = (lower_left_new + image_size * pixelSize_new) - upper_right_max
		;Task: Bound lower_left_new_y to max
		;{
			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
			;Task: image_size * pixelSize_new
			;{
				mov rbx, r13 							;a_low = pixelSize_new_low
				mov rcx, r14 							;a_high = pixelSize_new_high
				mov rbp, qword ptr [ua_height] 			;b = ua_height (Image height)
				lea r15, ReturnAddress_BoundNewLL_Y_5   ;save return adress
				jmp Function_MulFint 					;run MulFint with pixelSize_new and image_size
				ReturnAddress_BoundNewLL_Y_5:
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, 
			;		rbx = (image_size * pixelSize_new)_low, rcx = (image_size * pixelSize_new)_high
			;Task: lower_left_new + image_size * pixelSize_new
			;{
														;a_low = (image_size * pixelSize_new)_low
														;a_high = (image_size * pixelSize_new)_high
				mov rbp, qword ptr [a_lowerLeft_y_low]  ;b_low = lower_left_new_y_low
				mov r8, qword ptr [a_lowerLeft_y_high]  ;b_high = lower_left_new_y_high
				lea r15, ReturnAddress_BoundNewLL_Y_6   ;save return adress
				jmp Function_AddF						;run AddF with image_size * pixelSize_new and lower_left_new
				ReturnAddress_BoundNewLL_Y_6:
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, 
			;		rbx = (lower_left_new + image_size * pixelSize_new)_low, rcx = (lower_left_new + image_size * pixelSize_new)_high
			;Task: (lower_left_new + image_size * pixelSize_new) - upper_right_max
			;{
															;a_low = (lower_left_new + image_size * pixelSize_new)_low
															;a_high = (lower_left_new + image_size * pixelSize_new)_high
				xor rbp, rbp								;b_low = upper_right_max_low = 0
				mov rax, 8000000000000000h 	;mask for sign bit
				mov r8, qword ptr [a_upperRight_y_max_high] ;b_high = upper_right_max_high
				xor r8, rax 								;b_high = -upper_right_max_high
				lea r15, ReturnAddress_BoundNewLL_Y_7   ;save return adress
				jmp Function_AddF						;run AddF with (lower_left_new + image_size * pixelSize_new) and -upper_right_max
				ReturnAddress_BoundNewLL_Y_7:
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
			; 		rbx = shiftVal_low, rcx = shiftVal_high
			;Task: Check if shiftVal is negative -> add shift to lower_left_new        else: do nothin is in bound
			;{
				mov rax, 8000000000000000h 	;mask for sign bit
				test rcx, rax
				jz BoundNewLL_Y_8 ;if zero -> shiftVal is positive -> do nothing
															;a_low = shift_low
															;a_high = shift_high
				mov rbp, qword ptr [a_lowerLeft_y_low]		;b_low = lower_left_new_y_low
				mov r8, qword ptr [a_lowerLeft_y_high]		;b_high = lower_left_new_y_high
				lea r15, ReturnAddress_BoundNewLL_Y_9
				jmp Function_AddF
				ReturnAddress_BoundNewLL_Y_9:

				mov qword ptr [a_lowerLeft_y_low], rbx		;store shifted lower_left_new_y_low
				mov qword ptr [a_lowerLeft_y_high], rcx		;store shifted lower_left_new_y_high

				BoundNewLL_Y_8:
			;}
		;}
	;}

	;State:  r13 = pixelSize_new_low, r14 = pixelSize_new_high, new lower left is bounded and set
	;Task: Update pixelsize to new value
	;{
		mov qword ptr [a_pixelSize_low] , r13
		mov qword ptr [a_pixelSize_high] , r14
	;}

	;State: new lower left is bounded and set, new pixelsize is bounded and set 
	;Task: Reset mouse wheel state to 0
	;{
		mov word ptr [a_mouseWheel_state], 0
	;}

winMain_setzoom_end:
	;State: Zoom is fully updated

	call RecreateBitmap
	call Draw

	;pre call shadowStack
	mov rsi, rsp
	and rsp, -16 ;align stack to 16-byte boundary
	sub rsp, 32 ;allocate shadow space for the call

	;call params
	mov rcx, qword ptr [ua_hwnd]
	xor rdx, rdx
	xor r8d, r8d

	;call InvalidateRect(
	; hWnd->rcx = ua_hwnd,
	; lpRect->rdx = NULL,
	; bErase->r8 = FALSE,
	;)
	call InvalidateRect

	;restore stack pointer
	mov rsp, rsi ;restore original stack pointer after call

winMain_if_draw_end:
	jmp winMain_loop

winMain_exit:
	;restore nonvolatile register
	pop rbx
	pop r12
	pop r13
	pop r14
	pop r15

	;ExitProcess (no return)
	;The original entry stack is 8-byte misaligned; reserve 32-byte shadow space + 8-byte alignment.
	sub rsp, 28h

	;call params
	xor ecx, ecx

	;call ExitProcess(
	; uExitCode->rcx = 0,
	;)
	call ExitProcess

	add rsp, 28h
	ret
start ENDP

END
