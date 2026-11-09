option casemap:none

includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib

EXTERN __imp_RegisterClassExA:QWORD
EXTERN __imp_CreateWindowExA:QWORD
EXTERN __imp_BeginPaint:QWORD
EXTERN __imp_EndPaint:QWORD
EXTERN __imp_GetMessageA:QWORD
EXTERN __imp_DispatchMessageA:QWORD
EXTERN __imp_DefWindowProcA:QWORD
EXTERN __imp_PostQuitMessage:QWORD
EXTERN __imp_LoadCursorA:QWORD
EXTERN __imp_CreateDIBSection:QWORD
EXTERN __imp_CreateCompatibleDC:QWORD
EXTERN __imp_SelectObject:QWORD
EXTERN __imp_BitBlt:QWORD
EXTERN __imp_InvalidateRect:QWORD

; Register usage (Windows x64 ABI + the internal conventions of this program)
; The math routines (Function_MulF, Function_MulFint, Function_AddF, Function_GetIterations, Function_ZoomAxis) are NOT
; Windows ABI functions: they take their parameters in registers, use no stack frame and are only called from this file.
;
; Register | Windows x64 ABI      | Kept by API calls | Own usage
; ---------|----------------------|-------------------|------------------------------------------------------------------
; rax      | return value         | no (volatile)     | scratch
; rbx      | free                 | yes               | math routines: a_low / result_low
; rcx      | 1st argument         | no (volatile)     | math routines: a_high / result_high; WndProc: hwnd
; rdx      | 2nd argument         | no (volatile)     | scratch
; rsi      | free                 | yes               | GetIterations: zn_real_low; ZoomAxis: image size; Draw: row pointer
; rdi      | free                 | yes               | ZoomAxis: pointer to the axis block; Draw: inner x counter
; rbp      | free (frame pointer) | yes               | math routines: b_low; Draw: inner y counter
; rsp      | stack pointer        | always            | only push/pop/call and the frame set up in start
; r8       | 3rd argument         | no (volatile)     | math routines: b_high
; r9       | 4th argument         | no (volatile)     | scratch
; r10, r11 | scratch              | no (volatile)     | scratch (sign handling in the math routines)
; r12      | free                 | yes               | Draw: bitmap pointer; GetIterations: zn_real_high
; r13      | free                 | yes               | Draw: x counter; GetIterations: zn_imag_low; zoom: pixelSize_new_low
; r14      | free                 | yes               | Draw: y counter; GetIterations: zn_imag_high; zoom: pixelSize_new_high
; r15      | free                 | yes               | unused



.data
	g_szClassName DB "A",0
	;Window title ;64bit-specific
	;It is the lpWindowName of CreateWindowEx and at the same time the buffer that gets rewritten on every key press
	;(WM_SETTEXT), so the text of the initial title has to match the initial values of a_pixelBlockSize and a_maxIterations.
	;Layout: [fixed text][pixel size: 2 chars][fixed text][iterations: 8 bytes incl. terminator]
	;The iterations are the last part of the title, so no text has to be moved when the number of digits changes.
	c_window_title DB "Mandelbrot set | Keys 5-9: Pixel size "
	a_title_pixelSize DB " 4"
	DB " | Keys 0-4: Iterations "
	a_title_iterations DB "10", 6 DUP(0)	;8 bytes, same layout as the entries of a_iteration_title_lookup
	
	ALIGN 8
	;WNDCLASSEXA statically initialised, only hCursor is filled in at runtime ;64bit-specific
	ua_wc DWORD 80							;cbSize
		  DWORD 0							;style
		  QWORD OFFSET WndProc				;lpfnWndProc
		  DWORD 0, 0						;cbClsExtra, cbWndExtra
		  QWORD 0							;hInstance (NULL is accepted for the own process)
		  QWORD 0							;hIcon
		  QWORD 0							;hCursor (set in start)
		  QWORD 6							;hbrBackground
		  QWORD 0							;lpszMenuName
		  QWORD OFFSET g_szClassName		;lpszClassName
		  QWORD 0							;hIconSm
	;BITMAPINFOHEADER statically initialised ;64bit-specific
	ua_bmi DWORD 40, IMAGE_WIDTH, IMAGE_HEIGHT	;biSize, biWidth, biHeight
		   WORD 1, 32						;biPlanes, biBitCount
		   BYTE 24 DUP(0)					;remaining fields + padding
	ua_msg BYTE 48 DUP(0)
	ua_ps BYTE 80 DUP(0)
	ua_bitmapData QWORD 0
	ua_hdcMem QWORD 0
	ua_hwnd QWORD 0

	
	; ---------- Colour Palette Selection --------------------------------

	IFNDEF COLOUR_MODE
		COLOUR_MODE EQU 16       ; Default: 16 colours
	ENDIF

	IF COLOUR_MODE EQ 16
		MODOLU_MASK_COLOUR EQU 0Fh

		a_colour_pallet DWORD 0FF190720h,0FF421E0Fh,0FF6A3403h,0FF995700h,0FFCC8000h,0FFFFAA00h,0FFF8C95Fh,0FFF1E9BFh
						DWORD 0FFD3ECF8h,0FF86B5E5h,0FF397DD1h,0FF1852B1h,0FF0C2C8Ah,0FF000764h,0FF040449h,0FF09012Fh

	ELSEIF COLOUR_MODE EQ 32
		MODOLU_MASK_COLOUR EQU 01Fh

		a_colour_pallet DWORD 0FF190720h,0FF2C160Dh,0FF421E0Fh,0FF56300Ah,0FF6A3403h,0FF814500h,0FF995700h,0FFB36C00h
						DWORD 0FFCC8000h,0FFE69500h,0FFFFAA00h,0FFFBB950h,0FFF8C95Fh,0FFF5D88Ch,0FFF1E9BFh,0FFE5EBDCh
						DWORD 0FFD3ECF8h,0FFB6D8F0h,0FF86B5E5h,0FF5A99DBh,0FF397DD1h,0FF2869C1h,0FF1852B1h,0FF12419Dh
						DWORD 0FF0C2C8Ah,0FF082078h,0FF000764h,0FF020657h,0FF040449h,0FF06033Ch,0FF09012Fh,0FF05001Fh

	ELSEIF COLOUR_MODE EQ 64
		MODOLU_MASK_COLOUR EQU 03Fh 

		a_colour_pallet DWORD 0FF190720h,0FF230F0Ah,0FF2C160Dh,0FF371A0Eh,0FF421E0Fh,0FF4C270Dh,0FF56300Ah,0FF603208h
						DWORD 0FF6A3403h,0FF753C02h,0FF814500h,0FF8D4E00h,0FF995700h,0FFA56100h,0FFB36C00h,0FFBF7600h
						DWORD 0FFCC8000h,0FFD98B00h,0FFE69500h,0FFF29F00h,0FFFFAA00h,0FFFDB450h,0FFFBB950h,0FFF9C055h
						DWORD 0FFF8C95Fh,0FFF7D074h,0FFF5D88Ch,0FFF3E0A5h,0FFF1E9BFh,0FFEAEBD0h,0FFE5EBDCh,0FFDAECEDh
						DWORD 0FFD3ECF8h,0FFC7E3F4h,0FFB6D8F0h,0FFA0C9EBh,0FF86B5E5h,0FF71A8E0h,0FF5A99DBh,0FF4989D6h
						DWORD 0FF397DD1h,0FF3073C9h,0FF2869C1h,0FF2060B9h,0FF1852B1h,0FF154AA7h,0FF12419Dh,0FF0F3993h
						DWORD 0FF0C2C8Ah,0FF0A277Fh,0FF082078h,0FF061B70h,0FF000764h,0FF01065Dh,0FF020657h,0FF030550h
						DWORD 0FF040449h,0FF050342h,0FF06033Ch,0FF070235h,0FF09012Fh,0FF070128h,0FF05001Fh,0FF030018h

	ELSEIF COLOUR_MODE EQ 128
		MODOLU_MASK_COLOUR EQU 07Fh

		a_colour_pallet DWORD 0FF190720h,0FF1E0B25h,0FF230F0Ah,0FF28130Bh,0FF2C160Dh,0FF32180Eh,0FF371A0Eh,0FF3C1C0Fh
						DWORD 0FF421E0Fh,0FF47220Eh,0FF4C270Dh,0FF512B0Ch,0FF56300Ah,0FF5B3109h,0FF603208h,0FF653405h
						DWORD 0FF6A3403h,0FF703802h,0FF753C02h,0FF7B4101h,0FF814500h,0FF874A00h,0FF8D4E00h,0FF935300h
						DWORD 0FF995700h,0FF9F5C00h,0FFA56100h,0FFAC6600h,0FFB36C00h,0FFB97100h,0FFBF7600h,0FFC67B00h
						DWORD 0FFCC8000h,0FFD28600h,0FFD98B00h,0FFDF9000h,0FFE69500h,0FFEC9A00h,0FFF29F00h,0FFF9A500h
						DWORD 0FFFFAA00h,0FFFEAF28h,0FFFDB450h,0FFFBB950h,0FFFBBD53h,0FFF9C055h,0FFF8C95Fh,0FFF8CD69h
						DWORD 0FFF7D074h,0FFF6D580h,0FFF5D88Ch,0FFF4DC98h,0FFF3E0A5h,0FFF2E5B2h,0FFF1E9BFh,0FFEDEAC8h
						DWORD 0FFEAEBD0h,0FFE8EBD6h,0FFE5EBDCh,0FFE0ECE4h,0FFDAECEDh,0FFD7ECF2h,0FFD3ECF8h,0FFCEE8F6h
						DWORD 0FFC7E3F4h,0FFBFE0F2h,0FFB6D8F0h,0FFACD2EEh,0FFA0C9EBh,0FF93BFE8h,0FF86B5E5h,0FF7BAFE2h
						DWORD 0FF71A8E0h,0FF659FDCh,0FF5A99DBh,0FF518FD8h,0FF4989D6h,0FF4183D3h,0FF397DD1h,0FF3478CDh
						DWORD 0FF3073C9h,0FF2C6DC5h,0FF2869C1h,0FF2464BDh,0FF2060B9h,0FF1C59B5h,0FF1852B1h,0FF164EACh
						DWORD 0FF154AA7h,0FF1346A2h,0FF12419Dh,0FF103D98h,0FF0F3993h,0FF0D328Eh,0FF0C2C8Ah,0FF0B2984h
						DWORD 0FF0A277Fh,0FF09247Bh,0FF082078h,0FF071D74h,0FF061B70h,0FF041565h,0FF000764h,0FF01065Dh
						DWORD 0FF020657h,0FF030550h,0FF040449h,0FF040445h,0FF050342h,0FF06033Ch,0FF070235h,0FF080232h
						DWORD 0FF09012Fh,0FF08012Bh,0FF070128h,0FF060123h,0FF05001Fh,0FF04001Ch,0FF030018h,0FF020015h
						DWORD 0FF010012h,0FF00000Fh,0FF00000Ch,0FF000009h,0FF000006h,0FF000003h,0FF000001h,0FF000000h

	ELSE

		.ERR <Invalid COLOUR_MODE: use 16, 32, 64 or 128>

	ENDIF

	; --------------------------------------------------------------------

	;Image size is never changed -> fixed values (like MODOLU_MASK_COLOUR) ;64bit-specific
	IMAGE_WIDTH EQU 800
	IMAGE_HEIGHT EQU 608

	;Axis blocks: x and y have the identical layout so one subroutine (Function_ZoomAxis) can work on both. ;64bit-specific
	;Offsets inside a block:
	AXIS_lowerLeft_low EQU 0
	AXIS_lowerLeft_high EQU 8
	AXIS_lowerLeft_min_high EQU 16
	AXIS_upperRight_max_high EQU 24
	AXIS_mousePos EQU 32
	AXIS_SIZE EQU 40

	;x axis block
	a_lowerLeft_x_low QWORD  0000000000000000h
	a_lowerLeft_x_high QWORD 8900000000000000h
	a_lowerLeft_x_min_high QWORD 8900000000000000h
	;a_lowerLeft_x_min_low QWORD  0000000000000000h ;no need to hold zeros in .data
	a_upperRight_x_max_high QWORD 0455475A00000000h
	;a_upperRight_x_max_low QWORD  0000000000000000h ;no need to hold zeros in .data
	a_mousePos_x DWORD 0
	DWORD 0 ;padding to AXIS_SIZE

	;y axis block
	a_lowerLeft_y_low QWORD  0000000000000000h
	a_lowerLeft_y_high QWORD 855551D700000000h
	a_lowerLeft_y_min_high QWORD 855551D700000000h
	;a_lowerLeft_y_min_low QWORD  0000000000000000h ;no need to hold zeros in .data
	a_upperRight_y_max_high QWORD 04AAAE2900000000h
	;a_upperRight_y_max_low QWORD  0000000000000000h ;no need to hold zeros in .data
	a_mousePos_y DWORD 0
	DWORD 0 ;padding to AXIS_SIZE

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

	a_maxIterations DWORD 10
	; ---------- Iteration Lookup Table ---------------------------------
	; Index | Max Iterations
	;   0   | 10
	;   1   | 100
	;   2   | 1000
	;   3   | 10000
	;   4   | 100000
	ALIGN 4
	a_iteration_lookup DWORD 10, 100, 1000, 10000, 100000
	; ---------- Iteration Title Lookup Table (same indices as above) --------------
	; The text of every entry, padded with 0 to 8 bytes: that way a whole entry is copied into the window title with one 8 byte move ;64bit-specific
	a_iteration_title_lookup DB "10", 6 DUP(0)
							 DB "100", 5 DUP(0)
							 DB "1000", 4 DUP(0)
							 DB "10000", 3 DUP(0)
							 DB "100000", 2 DUP(0)
	; --------------------------------------------------------------------

	a_pixelBlockSize BYTE 4 ;controls how many pixels get drawn together in a block
	; ---------- Pixel Block Size Lookup Table ---------------------------------
	; Index | Pixel Block Size
	;   0   | 1
	;   1   | 2
	;   2   | 4
	;   3   | 8
	;   4   | 16
	a_pixelBlockSize_lookup BYTE 1, 2, 4, 8, 16
	; ---------- Pixel Block Size Title Lookup Table (same indices as above) --------
	; The text of every entry is exactly 2 characters (right aligned), so the part of the window title behind it never moves ;64bit-specific
	a_pixelBlockSize_title_lookup DB " 1", " 2", " 4", " 8", "16"
	; --------------------------------------------------------------------

	WC_hCursor EQU 40 ;offset of hCursor inside ua_wc

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
		mov r11, rcx
		xor r11, r8  ;combine a's and b's sign bit (xor -> one sign result in negative, two in positive, none in positive)
		shr r11, 63  ;extract combined sign bit (all other bits cleared) ;64bit-specific: no 64 bit mask needed
		shl r11, 63
	;}

	;Task: remove sign bits from a and b
	;{
		btr rcx, 63 ;remove sign bit from a
		btr r8, 63  ;remove sign bit from b
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
		mov rcx, r11
		shr rcx, 63 ;keep sign if X4 has the sign bit, else rcx will be 0
		shl rcx, 63
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
	ret

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
		mov r11, rcx
		xor r11, rbp ;combine a's and b's sign bit (xor -> one sign result in negative, two in positive, none in positive)
		shr r11, 63  ;extract combined sign bit (all other bits cleared) ;64bit-specific: no 64 bit mask needed
		shl r11, 63
	;}

	;Task: invert b if b is negative
	;{
		test rbp, rbp ;test is neg
		jns mulfint_b_not_neg
		neg rbp       ;invert b if negative
		mulfint_b_not_neg:
	;}

	;Task: remove sign bit from a
	;{
		btr rcx, 63 ;remove sign bit from a
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
	ret


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
		mov r10, rcx ; get a_high
		mov r11, r8  ; get b_high
		btr rcx, 63 ;remove sign bit from a ;64bit-specific: no 64 bit mask needed
		btr r8, 63  ;remove sign bit from b
		xor r10, rcx ;extract a's sign bit (original a_high xor a_high without sign)
		xor r11, r8  ;extract b's sign bit
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
	ret


; ---------- Function: GetIterations direct -----------------------------------
; Calculates the number of iterations for the Mandelbrot set
; a_low: rbx (64bit after dot)                              Real number part_low
; a_high: rcx (1bit sign, 5bit pre dot, 122 bit after dot) Real number part_high
; b_low: rbp (64bit after dot)                              Imaginary number part_low
; b_high: r8 (1bit sign, 5bit pre dot, 122 bit after dot)  Imaginary number part_high
; result_low: rbx (number of iterations -> -1 if not escaped, 32 bit)
; free_to_use: rax, rdx, r9, r10, r11
Function_GetIterations:
	;Task: save Registers
	;{
		push r12
		push r13
		push r14
		;rsi is free to use as Draw saves it
	;}

	;Task: reserve Stack and save number to stack
	;{
		sub rsp, 84  ;4 + 8*10
		mov qword ptr [rsp+4], rbx  ;num_real_low (64 bit)
		mov qword ptr [rsp+12], rcx ;num_real_high (64 bit)
		mov qword ptr [rsp+20], rbp ;num_imag_low (64 bit)
		mov qword ptr [rsp+28], r8  ;num_imag_high (64 bit)
	;}

	;Task: initialize iteration counter/return value and set z0
	;{
		mov dword ptr [rsp+0], -1 ;default return + counter for iterations (32 bit)
		xor esi, esi  ;z0_real_low = 0
		xor r12d, r12d  ;z0_real_high = 0
		xor r13d, r13d  ;z0_imag_low = 0
		xor r14d, r14d  ;z0_imag_high = 0
	;}

	;State: (rsi, r12) = zn_real_(low/high)
	;       (r13, r14) = zn_imag_(low/high)
	;       [SP+0] = iteration counter / return value (32 bit)
	;       ([SP+4], [SP+12]) = num_real_(low/high)
	;       ([SP+20], [SP+28]) = num_imag_(low/high)
	;Task: loop till maximum iterations or escape condition is met
	;{
	getit_loop:
		;State: (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;Task: zn_real*zn_real -> zn_real^2
		;{
			mov rbx, rsi
			mov rcx, r12
			mov rbp, rsi
			mov r8, r12
			call Function_MulF ;64bit-specific: call/ret instead of lea r15 + jmp r15
			mov qword ptr [rsp+36], rbx ;save (zn_real*zn_real)_low
			mov qword ptr [rsp+44], rcx ;save (zn_real*zn_real)_high
		;}

		;State: (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;Task: zn_imag*zn_imag -> zn_imag^2
		;{
			mov rbx, r13
			mov rcx, r14
			mov rbp, r13
			mov r8, r14
			call Function_MulF ;64bit-specific: call/ret instead of lea r15 + jmp r15
			mov qword ptr [rsp+52], rbx ;save (zn_imag*zn_imag)_low
			mov qword ptr [rsp+60], rcx ;save (zn_imag*zn_imag)_high
		;}

		;State: (rbx, rcx) = (zn_imag*zn_imag)_low/high
		;       (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;       ([SP+36], [SP+44]) = (zn_real*zn_real)_low/high
		;       ([SP+52], [SP+60]) = (zn_imag*zn_imag)_low/high
		;Task: zn_real*zn_real + zn_imag*zn_imag
		;{
			; a_low = (zn_imag*zn_imag)_low
			; a_high = (zn_imag*zn_imag)_high
			mov rbp, qword ptr [rsp+36] ;b_low = (zn_real*zn_real)_low
			mov r8, qword ptr [rsp+44]  ;b_high = (zn_real*zn_real)_high
			call Function_AddF ;64bit-specific: call/ret instead of lea r15 + jmp r15
		;}

		;State: (rbx, rcx) = (zn_real*zn_real + zn_imag*zn_imag)_low/high
		;       (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;       ([SP+36], [SP+44]) = (zn_real*zn_real)_low/high
		;       ([SP+52], [SP+60]) = (zn_imag*zn_imag)_low/high
		;Task: Check --> [(zn_real*zn_real + zn_imag*zn_imag) - ((escape threshold)^2)] >= 0
		;{
			; a_low = (zn_real*zn_real + zn_imag*zn_imag)_low
			; a_high = (zn_real*zn_real + zn_imag*zn_imag)_high
			xor ebp, ebp
			mov r8, 9000000000000000h ;b_high = -4 = -2^2
			call Function_AddF ;64bit-specific: call/ret instead of lea r15 + jmp r15
			test rcx, rcx
			jns getit_end ;escaped -> |zn| > 2 (sign bit not set)
		;}

		;State: (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;       ([SP+36], [SP+44]) = (zn_real*zn_real)_low/high
		;       ([SP+52], [SP+60]) = (zn_imag*zn_imag)_low/high
		;Task: zn_real*zn_real - zn_imag*zn_imag
		;{
			mov rbx, qword ptr [rsp+36]
			mov rcx, qword ptr [rsp+44]
			mov rbp, qword ptr [rsp+52]
			mov r8, qword ptr [rsp+60]
			btc r8, 63 ;invert sign
			call Function_AddF ;64bit-specific: call/ret instead of lea r15 + jmp r15
		;}

		;State: (rbx, rcx) = (zn_real*zn_real - zn_imag*zn_imag)_(low/high)
		;       (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;       ([SP+36], [SP+44]) = (zn_real*zn_real)_low/high
		;       ([SP+52], [SP+60]) = (zn_imag*zn_imag)_low/high
		;Task: (zn_real*zn_real - zn_imag*zn_imag) + num_real
		;{
			; a_low/high = (zn_real*zn_real - zn_imag*zn_imag)
			mov rbp, qword ptr [rsp+4]
			mov r8, qword ptr [rsp+12]
			call Function_AddF ;64bit-specific: call/ret instead of lea r15 + jmp r15
			mov qword ptr [rsp+68], rbx
			mov qword ptr [rsp+76], rcx
		;}

		;State: (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;       ([SP+36], [SP+44]) = (zn_real*zn_real)_low/high
		;       ([SP+52], [SP+60]) = (zn_imag*zn_imag)_low/high
		;       ([SP+68], [SP+76]) = new zn_real_(low/high)
		;Task: zn_real * zn_imag
		;{
			mov rbx, rsi
			mov rcx, r12
			mov rbp, r13
			mov r8, r14
			call Function_MulF ;64bit-specific: call/ret instead of lea r15 + jmp r15
		;}

		;State: (rbx, rcx) = (zn_real * zn_imag)_low/high
		;       (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;       ([SP+36], [SP+44]) = (zn_real*zn_real)_low/high
		;       ([SP+52], [SP+60]) = (zn_imag*zn_imag)_low/high
		;       ([SP+68], [SP+76]) = new zn_real_(low/high)
		;Task: 2 * (zn_real * zn_imag)
		;{
			; a_low/high = (zn_real * zn_imag)
			mov rbp, rbx
			mov r8, rcx
			call Function_AddF ;64bit-specific: call/ret instead of lea r15 + jmp r15
		;}

		;State: (rbx, rcx) = (2* zn_real * zn_imag)_low/high
		;       (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;       ([SP+36], [SP+44]) = (zn_real*zn_real)_low/high
		;       ([SP+52], [SP+60]) = (zn_imag*zn_imag)_low/high
		;       ([SP+68], [SP+76]) = new zn_real_(low/high)
		;Task: 2 * (zn_real * zn_imag) + num_imag
		;{
			; a_low/high = (2* zn_real * zn_imag)
			mov rbp, qword ptr [rsp+20]
			mov r8, qword ptr [rsp+28]
			call Function_AddF ;64bit-specific: call/ret instead of lea r15 + jmp r15
		;}

		;State: (rbx, rcx) = ((2* zn_real * zn_imag) + num_imag)_low/high
		;       (rsi, r12) = zn_real_(low/high)
		;       (r13, r14) = zn_imag_(low/high)
		;       [SP+0] = iteration counter / return value (32 bit)
		;       ([SP+4], [SP+12]) = num_real_(low/high)
		;       ([SP+20], [SP+28]) = num_imag_(low/high)
		;       ([SP+36], [SP+44]) = (zn_real*zn_real)_low/high
		;       ([SP+52], [SP+60]) = (zn_imag*zn_imag)_low/high
		;       ([SP+68], [SP+76]) = new zn_real_(low/high)
		;Task: set zn+1
		;      real: (zn_real*zn_real - zn_imag*zn_imag) + num_real
		;      imag: 2 * (zn_real * zn_imag) + num_imag
		;{
			mov r13, rbx
			mov r14, rcx
			mov rsi, qword ptr [rsp+68]
			mov r12, qword ptr [rsp+76]
		;}
	;}

	;Task: increment iteration counter and check against maximum
	;{
		mov eax, dword ptr [rsp+0]        	;load Counter
		inc eax                           	;increment iteration counter
		mov dword ptr [rsp+0], eax        	;save Counter
		mov ebx, dword ptr [a_maxIterations];load maximum iterations (32 bit)
		cmp eax, ebx                      	;check if maximum is reached
		jl getit_loop                     	;if maximum iterations not reached, continue loop
		mov dword ptr [rsp+0], -1         	;if maximum reached, set to -1 (inside)
	;}

getit_end:
	;Task: set return value in rbx
	;{
		movsxd rbx, dword ptr [rsp+0] ;set return (4 bytes to 8 bytes)
	;}

	;Task: restore Stack
	;{
		add rsp, 84
	;}

	;Task: restore Registers
	;{
		pop r14
		pop r13
		pop r12
	;}

	;Exit
	ret



; ---------- Function: ZoomAxis direct -----------------------------------
; Computes the new lower left of one axis after a zoom and bounds it
; (the code is the same for x and y, so the caller passes the addresses of the axis to work on)
; rdi: address of the axis block (x or y)
;      [rdi+AXIS_lowerLeft_low], [rdi+AXIS_lowerLeft_high] = lower_left_old (gets overwritten with lower_left_new)
;      [rdi+AXIS_lowerLeft_min_high] = lower_left_min_high
;      [rdi+AXIS_upperRight_max_high] = upper_right_max_high
;      [rdi+AXIS_mousePos] = mousePos (32 bit)
; rsi: image size in pixels of this axis (Image width for x, Image height for y)
; r13: pixelSize_new_low
; r14: pixelSize_new_high
; result: new lower left is bounded and stored in the axis block
; free_to_use: rax, rbx, rcx, rdx, rbp, r8, r9, r10, r11
Function_ZoomAxis:

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
	;Task: lower_left_new = lower_left_old + (pixelSize_old - pixelSize_new) * mousePos
	;{
		;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
		;Task: pixelSize_old - pixelSize_new = -pixelSize_new + pixelSize_old
		;{
			mov rcx, r14							;a_high = pixelSize_new_high
			mov rbx, r13							;a_low = +-pixelSize_new_low
			btc rcx, 63 							;a_high = -pixelSize_new_high
			mov rbp, qword ptr [a_pixelSize_low]	;b_low = pixelSize_old_low
			mov r8, qword ptr [a_pixelSize_high]	;b_high = pixelSize_old_high

			call Function_AddF
		;}

		;State rbx = (pixelSize_old - pixelSize_new)_low, rcx = (pixelSize_old - pixelSize_new)_high
		;Task: (pixelSize_old - pixelSize_new) * mousePos
		;{
													;a_low = (pixelSize_old - pixelSize_new)_low
													;a_high = (pixelSize_old - pixelSize_new)_high
			mov ebp, dword ptr [rdi+AXIS_mousePos]	;b = mousePos (upper 32bit get automatically filled with zeros)
			call Function_MulFint
		;}

		;State rbx = ((pixelSize_old - pixelSize_new) * mousePos)_low, rcx = ((pixelSize_old - pixelSize_new) * mousePos)_high
		;Task: lower_left_old + (pixelSize_old - pixelSize_new) * mousePos
		;{
													;a_low = (pixelSize_old - pixelSize_new)_low * mousePos
													;a_high = (pixelSize_old - pixelSize_new)_high * mousePos
			mov rbp, qword ptr [rdi+AXIS_lowerLeft_low]		;b_low = lower_left_old_low
			mov r8, qword ptr [rdi+AXIS_lowerLeft_high]		;b_high = lower_left_old_high
			call Function_AddF
		;}
	;}

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_low, rcx = lower_left_new_high
	;Task: Save lower_left_new to memory (as lower_left_old is no longer needed for further calculations it can be overwritten)
	;{
		mov qword ptr [rdi+AXIS_lowerLeft_low], rbx  ;overwrite lower_left_old_low with lower_left_new_low
		mov qword ptr [rdi+AXIS_lowerLeft_high], rcx ;overwrite lower_left_old_high with lower_left_new_high
	;}

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_low, rcx = lower_left_new_high
	;Task: Bound lower_left_new to min and max
	;{
		;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_low, rcx = lower_left_new_high
		;Task: Bound lower_left_new to min
		;{
			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_low, rcx = lower_left_new_high
			;Task: Check lower_left_new >= 0 --> is larger than min bound (min bound is negative)
			;{
				test rcx, rcx				;test sign is set
				jns BoundNewLL_4
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high, rbx = lower_left_new_low, rcx = lower_left_new_high, rax sign mask
			;Task: Check |lower_left_new| >= |lowerLeft_min_high|
			;{
				mov r9, rcx									;save lower_left_new_high before removing sign
				shl r9, 1									;remove sign from lower_left_new_high (both values are shifted, so the compare stays valid) ;64bit-specific
				mov r10, qword ptr [rdi+AXIS_lowerLeft_min_high]
				mov rax, r10
				shl rax, 1									;remove sign from lowerLeft_min_high
				cmp r9, rax									;compare |lower_left_new_high| with |lowerLeft_min_high|
				jb BoundNewLL_4								;number is in bound

				mov qword ptr [rdi+AXIS_lowerLeft_low], 0  	 	;set lower_left_low to 0
				mov qword ptr [rdi+AXIS_lowerLeft_high], r10 	;set lower_left_high to min bound
			;}
			BoundNewLL_4:
		;}

		;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
		;shiftVal = (lower_left_new + image_size * pixelSize_new) - upper_right_max
		;Task: Bound lower_left_new to max
		;{
			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
			;Task: image_size * pixelSize_new
			;{
				mov rbx, r13 							;a_low = pixelSize_new_low
				mov rcx, r14 							;a_high = pixelSize_new_high
				mov rbp, rsi 							;b = image size of this axis
				call Function_MulFint
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high,
			;		rbx = (image_size * pixelSize_new)_low, rcx = (image_size * pixelSize_new)_high
			;Task: lower_left_new + image_size * pixelSize_new
			;{
														;a_low = (image_size * pixelSize_new)_low
														;a_high = (image_size * pixelSize_new)_high
				mov rbp, qword ptr [rdi+AXIS_lowerLeft_low]  	;b_low = lower_left_new_low
				mov r8, qword ptr [rdi+AXIS_lowerLeft_high]  	;b_high = lower_left_new_high
				call Function_AddF
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high,
			;		rbx = (lower_left_new + image_size * pixelSize_new)_low, rcx = (lower_left_new + image_size * pixelSize_new)_high
			;Task: (lower_left_new + image_size * pixelSize_new) - upper_right_max
			;{
															;a_low = (lower_left_new + image_size * pixelSize_new)_low
															;a_high = (lower_left_new + image_size * pixelSize_new)_high
				xor ebp, ebp								;b_low = upper_right_max_low = 0
				mov r8, qword ptr [rdi+AXIS_upperRight_max_high] ;b_high = upper_right_max_high
				btc r8, 63 								;b_high = -upper_right_max_high
				call Function_AddF
			;}

			;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high,
			; 		rbx = shiftVal_low, rcx = shiftVal_high
			;Task: Check if shiftVal is positive -> add -shift to lower_left_new        else: do nothin is in bound
			;{
				test rcx, rcx
				js BoundNewLL_8	;if sign is set -> shiftVal is negative -> do nothing
				btc rcx, 63		;invert sign of shiftVal_high
															;a_low = +-shift_low
															;a_high = -shift_high
				mov rbp, qword ptr [rdi+AXIS_lowerLeft_low]		;b_low = lower_left_new_low
				mov r8, qword ptr [rdi+AXIS_lowerLeft_high]		;b_high = lower_left_new_high
				call Function_AddF

				mov qword ptr [rdi+AXIS_lowerLeft_low], rbx		;store shifted lower_left_new_low
				mov qword ptr [rdi+AXIS_lowerLeft_high], rcx	;store shifted lower_left_new_high

				BoundNewLL_8:
			;}
		;}
	;}

	;Exit
	ret

; ---------- Function: Draw -----------------------------------
; Draws the Mandelbrot set onto the bitmap
; Inputs: none
; Output: none
Draw PROC
	;64bit-specific: Draw is only called from start and calls no API, so nothing is saved here (start saves the non volatile registers, incl. r12) and no stack alignment is needed

	;Task: get bitmap data adress
	;{
		mov r12, qword ptr [ua_bitmapData]
	;}

	;State: r12 = bitmap data Ptr
	;Task: test if bitamp data is Nullptr     TODO: is this needed? and does it work at all?
	;{
		test r12, r12
		je draw_end
	;}


	;State: r12 = bitmap data Ptr
	;Task: get Image height
	;{
		mov r14d, IMAGE_HEIGHT
	;}
	
	;State: r14 = height, r12 = bitmap data Ptr
	;Task: start outer loop at height - a_pixelBlockSize
	;{
		movzx rax, byte ptr [a_pixelBlockSize]
		sub r14, rax
	;}


	draw_yo_loop:
		;State: r12 = bitmap data Ptr, r14 = y_counter
		;Task: reset x counter, start at width - a_pixelBlockSize
		;{
			mov r13d, IMAGE_WIDTH
			movzx rax, byte ptr [a_pixelBlockSize]
			sub r13, rax
		;}
		draw_xo_loop:
			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter
			;Task: Compute real y offset --> y*pixelsize
			;{
				mov rbx, qword ptr [a_pixelSize_low]	;a_low = a_pixelSize_low
				mov rcx, qword ptr [a_pixelSize_high]	;a_high = a_pixelSize_high
				mov rbp, r14							;b = y
				call Function_MulFint ;64bit-specific: call/ret instead of lea r15 + jmp r15
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter
			;       rbx = real_y_offset_low, rcx = real_y_offset_high
			;Task: Compute real y pos -->  y*pixelsize + lower_left
			;{
														;a_low = real_y_offset_low				
														;a_high = real_y_offset_high
				mov rbp, qword ptr [a_lowerLeft_y_low]  ;b_low = a_lowerLeft_y_low
				mov r8, qword ptr [a_lowerLeft_y_high]   ;b_high = a_lowerLeft_y_high
				call Function_AddF ;64bit-specific: call/ret instead of lea r15 + jmp r15
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
				call Function_MulFint ;64bit-specific: call/ret instead of lea r15 + jmp r15
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
				call Function_AddF ;64bit-specific: call/ret instead of lea r15 + jmp r15
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
				
				call Function_GetIterations ;64bit-specific: call/ret instead of lea r15 + jmp r15
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		rbx = Iteration (-1 if inside)
			;Task: Check is inside and set color
			;{
				xor ecx, ecx ;set color to 0 for inside pixels (default)
				cmp rbx, -1  ;test if inside
				je draw_color_ready
				and rbx, MODOLU_MASK_COLOUR ;Iterations module MODOLU_MASK_COLOUR to get color index
				lea rdx, a_colour_pallet
				mov ecx, dword ptr [rdx + rbx*4]
				draw_color_ready:
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		ecx = Color
			;Task: compute the address of the first pixel of the block --> bitmap + (y*IMAGE_WIDTH + x)*4
			;{
				mov eax, r14d
				imul eax, eax, IMAGE_WIDTH		;eax = IMAGE_WIDTH * y_counter
				add eax, r13d					;eax = IMAGE_WIDTH * y_counter + x_counter
				lea rsi, [r12+rax*4]			;rsi = pixel address of the block start (row pointer)
			;}

			;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter,
			;		ecx = Color, rsi = row pointer
			;Task: outer Loop for drawing pixels
				movzx ebp, byte ptr [a_pixelBlockSize] ;inner y loop counter
				draw_yi_loop:
				;{
					movzx edi, byte ptr [a_pixelBlockSize] ;inner x loop counter
					mov rdx, rsi					;rdx = pixel pointer
					draw_xi_loop:
					;{
						mov dword ptr [rdx], ecx	;pixel = color
						add rdx, 4					;next pixel
					;}
					dec edi ;decrement inner x loop counter
					jnz draw_xi_loop
					add rsi, IMAGE_WIDTH*4			;next row of the block
				;}
				dec ebp ;decrement inner y loop counter
				jnz draw_yi_loop
				

		;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter
		;Task: Update outer loop counters and check loop conditions
		;{
			movzx rax, byte ptr [a_pixelBlockSize]
			sub r13, rax
			jge draw_xo_loop
		;}

	;State: r12 = bitmap data Ptr, r14 = y_counter, r13 = x_counter
	;Task: Update outer loop counters and check loop conditions
	;{
		movzx rax, byte ptr [a_pixelBlockSize]
		sub r14, rax
		jge draw_yo_loop
	;}

draw_end:
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

	cmp edx, 000Fh
	je wndProc_paint

	cmp edx, 0100h
	je wndProc_keydown

	cmp edx, 2
	jne wndProc_default

	sub rsp, 28h
	xor ecx, ecx
	;call PostQuitMessage(
	; nExitCode->rcx = 0,
	;)
	call qword ptr [__imp_PostQuitMessage]
	add rsp, 28h
	xor eax, eax
	ret

wndProc_keydown:
	;Task: get lookup table index from pressed key
	;{
		mov eax, r8d ;get virtual key code
		sub eax, 30h ;convert VK_0..VK_9 to index 0..9
		cmp eax, 9
		ja wndProc_default ;ignore all keys outside 0-9

		

	;}

	;Task: ignore repeated keydown messages
	;{
		test r9d, 40000000h
		jnz wndProc_keydown_end
	;}

	;Task: decide between iteration and pixel Block size
	;{
		cmp eax, 4 
		ja wndProc_keydown_pixelBlocks ;keys 5-9 pressed --> pixel_blocks (keys 0-4 --> iterations)
	;}

	wndProc_keydown_iteration:
	;Task: load iteration count from lookup table
	;{
		lea rdx, a_iteration_title_lookup
		mov rdx, qword ptr [rdx+rax*8]				;64bit-specific: text of the new iteration count, 8 bytes incl. terminator
		mov qword ptr [a_title_iterations], rdx		;64bit-specific: put it behind the fixed text of the window title
		lea rdx, a_iteration_lookup
		mov eax, dword ptr [rdx+rax*4]
		mov dword ptr [a_maxIterations], eax
		jmp wndProc_keydown_update
	;}

	wndProc_keydown_pixelBlocks:
	;Task: load pixelBlock size from lookup table
	;{
		sub rax, 5
		lea rdx, a_pixelBlockSize_title_lookup
		movzx edx, word ptr [rdx+rax*2]				;64bit-specific: text of the new pixel size, 2 characters
		mov word ptr [a_title_pixelSize], dx		;64bit-specific: put it into the window title
		lea rdx, a_pixelBlockSize_lookup
		mov al, byte ptr [rdx+rax]
		mov byte ptr [a_pixelBlockSize], al
	;}

	wndProc_keydown_update:
	;Task: set draw command
	;{
		mov byte ptr [a_enable_draw], 1
	;}

	;Task: show the new setting in the window title ;64bit-specific
	;      The title text itself was already updated above (a_title_pixelSize / a_title_iterations), the title buffer is
	;      complete and 0 terminated. Now it only has to be sent to the window: WM_SETTEXT is handled by DefWindowProc,
	;      so no extra import is needed.
	;      rcx is still hwnd (WndProc argument, not touched on the way here)
	;{
																;rcx = hWnd (unchanged)
		mov edx, 0Ch											;Msg = WM_SETTEXT
		xor r8d, r8d											;wParam = 0 (unused by WM_SETTEXT)
		lea r9, c_window_title									;lParam = pointer to the new title
		sub rsp, 28h											;shadow space (+ alignment, WndProc is entered with rsp = 8 mod 16)
		call qword ptr [__imp_DefWindowProcA]
		add rsp, 28h
	;}


wndProc_keydown_end:
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

wndProc_paint:
	;64bit-specific: bitmap + memory DC are created once in start, no GetClientRect/CreateCompatibleDC/DeleteDC per paint
	sub rsp, 58h
	mov [rsp+50h], rcx

	lea rdx, ua_ps
	;call BeginPaint(
	; hWnd->rcx = hwnd,
	; lpPaint->rdx = ua_ps,
	;)
	call qword ptr [__imp_BeginPaint]

	mov rcx, rax
	xor edx, edx
	xor r8d, r8d
	mov r9d, IMAGE_WIDTH
	mov dword ptr [rsp+20h], IMAGE_HEIGHT
	mov rax, qword ptr [ua_hdcMem]
	mov qword ptr [rsp+28h], rax
	mov qword ptr [rsp+30h], rdx
	mov qword ptr [rsp+38h], rdx
	mov dword ptr [rsp+40h], 0CC0020h
	;call BitBlt(
	; hdc->rcx = hdc from BeginPaint,
	; x->rdx = 0,
	; y->r8 = 0,
	; cx->r9 = 800,
	; cy->rsp+20h = 608,
	; hdcSrc->rsp+28h = ua_hdcMem,
	; x1->rsp+30h = 0,
	; y1->rsp+38h = 0,
	; rop->rsp+40h = SRCCOPY,
	;)
	call qword ptr [__imp_BitBlt]

	mov rcx, [rsp+50h]
	lea rdx, ua_ps
	;call EndPaint(
	; hWnd->rcx = hwnd,
	; lpPaint->rdx = ua_ps,
	;)
	call qword ptr [__imp_EndPaint]
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
	call qword ptr [__imp_DefWindowProcA]
	add rsp, 28h
	ret
WndProc ENDP

; ---------- Function: start -----------------------------------
; Entry point for the application
; Inputs: none
; Output: none
start PROC
	;save nonvolatile register
	push rbx
	push rbp
	push rdi
	push rsi
	push r12 ;64bit-specific: Draw uses r12 and does not save it, the push also aligns the stack to 16 bytes
	push r13
	push r14

	;persistent call frame: 2 zeroed stack parameters (CreateDIBSection) + 32 byte shadow space, rsp stays 16-byte aligned for the whole program ;64bit-specific
	push 0
	push 0
	sub rsp, 20h

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;; Registering the Window Class
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;call params
	xor ecx, ecx
	mov edx, 7F00h

	;call LoadCursorA(
	; hInstance->rcx = NULL,
	; lpCursorName->rdx = IDC_ARROW,
	;)
	call qword ptr [__imp_LoadCursorA]

	;save return value
	mov qword ptr [ua_wc+WC_hCursor], rax

	;call params
	lea rcx, ua_wc

	;call RegisterClassExA(
	; lpwcx->rcx = ua_wc,
	;)
	call qword ptr [__imp_RegisterClassExA]

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;; Create Bitmap + memory DC (once)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	xor ecx, ecx
	;call CreateCompatibleDC(
	; hdc->rcx = NULL,
	;)
	call qword ptr [__imp_CreateCompatibleDC]
	mov qword ptr [ua_hdcMem], rax

	xor ecx, ecx
	lea rdx, ua_bmi
	xor r8d, r8d
	lea r9, ua_bitmapData
	;call CreateDIBSection(
	; hdc->rcx = NULL,
	; pbmi->rdx = ua_bmi,
	; iUsage->r8 = DIB_RGB_COLORS,
	; ppvBits->r9 = ua_bitmapData,
	; hSection->rsp+20h = NULL,
	; dwOffset->rsp+28h = 0,
	;)
	call qword ptr [__imp_CreateDIBSection]

	mov rcx, qword ptr [ua_hdcMem]
	mov rdx, rax
	;call SelectObject(
	; hdc->rcx = ua_hdcMem,
	; h->rdx = bitmap,
	;)
	call qword ptr [__imp_SelectObject]

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;; Create Window
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;stack parameters are pushed right to left, the shadow space is allocated below them
	push 0 ;lpParam
	push 0 ;hInstance
	push 0 ;hMenu
	push 0 ;hWndParent
	push 600 ;nHeight
	push IMAGE_WIDTH ;nWidth
	push 80000000h ;Y
	push 80000000h ;X
	sub rsp, 20h

	;call params
	mov ecx, 200h
	lea rdx, g_szClassName
	lea r8, c_window_title
	mov r9d, 100A0000h ;WS_VISIBLE | 0A0000h, replaces ShowWindow

	;call CreateWindowExA(
	; dwExStyle->rcx = 200h,
	; lpClassName->rdx = g_szClassName,
	; lpWindowName->r8 = c_window_title,
	; dwStyle->r9 = 100A0000h,
	; X->rsp+32 (int) = 80000000h,
	; Y->rsp+40 (int) = 80000000h,
	; nWidth->rsp+48 (int) = 800,
	; nHeight->rsp+56 (int) = 600,
	; hWndParent->rsp+64 (HWND) = 0,
	; hMenu->rsp+72 (HMENU) = 0,
	; hInstance->rsp+80 (HINSTANCE) = 0,
	; lpParam->rsp+88 (LPVOID) = 0,
	;)
	call qword ptr [__imp_CreateWindowExA]

	;save return value
	mov qword ptr [ua_hwnd], rax

	;remove the 8 stack parameters and the shadow space, back to the persistent frame
	add rsp, 60h

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;; The Message Loop
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

winMain_loop:
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
	call qword ptr [__imp_GetMessageA]

	test eax, eax
	je winMain_exit

	;call params
	lea rcx, ua_msg

	;call DispatchMessageA(
	; lpMsg->rcx = ua_msg,
	;)
	call qword ptr [__imp_DispatchMessageA]

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
		xor ebx, ebx 							;set a_low to 0 (a_low of zoom_factor)
												;a_high already set (a_high of zoom_factor)
		mov rbp, qword ptr [a_pixelSize_low]	;set b_low to pixelSize_low
		mov r8, qword ptr [a_pixelSize_high]	;set b_high to pixelSize_high
		call Function_MulF ;64bit-specific: call/ret instead of lea r15 + jmp r15
	;}

	;State: rbx = pixelSize_new_low, rcx = pixelSize_new_high
	;Task: Compare new pixel size with minimum allowed pixel size and adjust if necessary
	;{
		;Check if high is zero
		mov rax, rcx
		shl rax, 1 							  ;check if high part of pixel size is zero (sign bit shifted out, ZF set if all other bits are zero)
		jnz ComputePixelSize_toSmallCheck_end ;if high part is not zero, number is large enough
		mov rax, qword ptr [a_pixelSize_min_low]
		cmp rax, rbx
		jbe ComputePixelSize_toSmallCheck_end ;if a_pixelSize_min_low is <= pixelSize_low, number is large enough
		mov rbx, qword ptr [a_pixelSize_min_low] ;set pixelSize_low to minimum allowed value
		xor ecx, ecx								;set pixelSize_high to 0 (minimum allowed value)
		ComputePixelSize_toSmallCheck_end:
	;}

	;State: rbx = pixelSize_low, rcx = pixelSize_high (Value is bounded by minimum allowed pixel size)
	;Task: Compare new pixel size with maximum allowed pixel size and adjust if necessary
	;{
		mov rax, qword ptr [a_pixelSize_max_high]
		cmp rcx, rax
		jle ComputePixelSize_toBigCheck_end ;if high part is less than or equal to max, number is within bounds
		mov rcx, rax 						;set high part of pixel size to maximum allowed value
		xor ebx, ebx						;set low part of pixel size to 0 (maximum allowed value)
		ComputePixelSize_toBigCheck_end:
	;}

	;State: rbx = pixelSize_low, rcx = pixelSize_high (Value is bounded by min/max pixel size bounds)
	;Task: Store the new pixel size in the appropriate variable
	;{
		mov r13, rbx	;store pixelSize_new_low in r13
		mov r14, rcx	;store pixelSize_new_high in r14
	;}

	;---------------- New Lower Left X section ---------------------------------------------------------------------

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
	;Task: compute and bound the new lower left of the x axis (Function_ZoomAxis)
	;{
		lea rdi, a_lowerLeft_x_low	;rdi = address of the x axis block
		mov esi, IMAGE_WIDTH		;rsi = image size in pixels of this axis (Image width)
		call Function_ZoomAxis
	;}

	;---------------- New Lower Left Y section ---------------------------------------------------------------------

	;State: r13 = pixelSize_new_low, r14 = pixelSize_new_high
	;Task: compute and bound the new lower left of the y axis (Function_ZoomAxis)
	;{
		add rdi, AXIS_SIZE			;rdi = address of the y axis block (directly behind the x axis block)
		mov esi, IMAGE_HEIGHT		;rsi = image size in pixels of this axis (Image height)
		call Function_ZoomAxis
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

	call Draw

	;call params
	mov rcx, qword ptr [ua_hwnd]
	xor edx, edx
	xor r8d, r8d

	;call InvalidateRect(
	; hWnd->rcx = ua_hwnd,
	; lpRect->rdx = NULL,
	; bErase->r8 = FALSE,
	;)
	call qword ptr [__imp_InvalidateRect]

winMain_if_draw_end:
	jmp winMain_loop

winMain_exit:
	;remove persistent call frame
	add rsp, 30h

	;restore nonvolatile register
	pop r14
	pop r13
	pop r12
	pop rsi
	pop rdi
	pop rbp
	pop rbx

	;return from the entry point ends the process (no ExitProcess needed)
	xor eax, eax
	ret
start ENDP

END
