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
; rsi      | Freie Verwendung             | NEIN            | JA           | NEIN               | Reset SP after call
; rdi      | Freie Verwendung             | NEIN            | JA           | NEIN               | 
; rbp      | Frame Pointer (optional)     | NEIN            | JA           | NEIN               | 
; rsp      | Stack Pointer                | JA (Sehr!)      | IMMER        | NIEMALS            | 
; r8       | 3. Argument                  | JA (Flüchtig)   | NEIN         | JA                 | 
; r9       | 4. Argument                  | JA (Flüchtig)   | NEIN         | JA                 | 
; r10      | Freie Verwendung / Scratch   | JA (Flüchtig)   | NEIN         | JA                 | 
; r11      | Freie Verwendung / Scratch   | JA (Flüchtig)   | NEIN         | JA                 | 
; r12      | Freie Verwendung             | NEIN            | JA           | NEIN               | 
; r13      | Freie Verwendung             | NEIN            | JA           | NEIN               | 
; r14      | Freie Verwendung             | NEIN            | JA           | NEIN               | 
; r15      | Freie Verwendung             | NEIN            | JA           | NEIN               | 



;rax = return value
;rcx, rdx, r8, r9 = first four integer/pointer arguments
;rdi, rsi, rbx, rbp, r12-r15 = callee-saved registers
;rsp = stack pointer (callee-saved)
;r10, r11 = caller-saved registers (volatile)

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
	ua_width DWORD 0
	ua_height DWORD 0
	a_colour_pallet DWORD 0FF190720h,0FF421E0Fh,0FF6A3403h,0FF995700h,0FFCC8000h,0FFFFAA00h,0FFF8C95Fh,0FFF1E9BFh,0FFD3ECF8h,0FF86B5E5h,0FF397DD1h,0FF1852B1h,0FF0C2C8Ah,0FF000764h,0FF040449h,0FF09012Fh
	a_lowerLeft_x DWORD 089000000h
	a_lowerLeft_y DWORD 0855551D7h
	a_lowerLeft_x_min DWORD 089000000h
	a_lowerLeft_y_min DWORD 0855551D7h
	a_upperRight_x_max DWORD 0455475Ah
	a_upperRight_y_max DWORD 04AAAE29h
	a_pixelSize DWORD 044444h
	a_pixelSize_max DWORD 044444h
	a_zoom_factor_out DWORD 003A2E8BAh
	a_zoom_factor_in DWORD 004666666h
	a_center_x DWORD 400
	a_center_y DWORD 300
	a_zoom_old DWORD 0
	a_zoom_new DWORD 0
	a_zoom_tmp DWORD 0
	a_wheel_delta DWORD 0
	a_enable_draw BYTE 1
	a_mouseWheel_state WORD 0
	a_mousePos_x DWORD 0
	a_mousePos_y DWORD 0
	a_tmp0 DWORD 0
	a_tmp1 DWORD 0
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
; Multiplies two fixed-point numbers in ecx and edx, result in eax
; return address: rdi
; a_low: rax (64bit after dot)
; a_high: rbx (1bit sign, 31bit pre dot, 96 bit after dot)
; b_low: rcx (64bit after dot)
; b_high: rdx (1bit sign, 31bit pre dot, 96 bit after dot)
; result_low: rbp
; result_high: r8
; free_to_use: r9, r10, r11




; ---------- Function: MulF -----------------------------------
; Multiplies two fixed-point numbers in ecx and edx, result in eax
MulF PROC
	mov eax, ecx
	mov edx, edx

	xor r8d, r8d
	test eax, 080000000h
	je mulf_a_pos
	xor r8d, 1
	and eax, 07FFFFFFFh

mulf_a_pos:
	test edx, 080000000h
	je mulf_b_pos
	xor r8d, 1
	and edx, 07FFFFFFFh
mulf_b_pos:
	mul edx
	sal r8d, 25
	or edx, r8d
	mov ecx, 26
mulf_shift:
	shr eax, 1
	shr edx, 1
	jae mulf_no_carry
	or eax, 080000000h
mulf_no_carry:
	dec ecx
	jg mulf_shift
	ret
MulF ENDP

; ---------- Function: MulFint -----------------------------------
; Multiplies fixed point with integer in ecx and edx, result in eax
MulFint PROC
	mov eax, ecx
	mov edx, edx
	xor r8d, r8d
	test eax, 080000000h
	je mulfint_a_pos
	xor r8d, 1
	and eax, 07FFFFFFFh
mulfint_a_pos:
	test edx, 080000000h
	je mulfint_b_pos
	neg edx
	xor r8d, 1
mulfint_b_pos:
	mul edx
	and eax, 07FFFFFFFh
	sal r8d, 31
	or eax, r8d
	ret
MulFint ENDP

; ---------- Function: AddF -----------------------------------
; Adds two fixed-point numbers in ecx and edx, result in eax
AddF PROC
	mov eax, ecx
	mov r8d, edx
	test eax, 080000000h
	je addf_a_pos
	and eax, 07FFFFFFFh
	neg eax
addf_a_pos:
	test r8d, 080000000h
	je addf_b_pos
	and r8d, 07FFFFFFFh
	neg r8d
addf_b_pos:
	add eax, r8d
	jns addf_pos
	neg eax
	or eax, 080000000h
addf_pos:
	ret
AddF ENDP

; ---------- Function: GetIterations -----------------------------------
; Calculates the number of iterations for the Mandelbrot set
; Inputs: ecx = some fixed-point number, edx = some fixed-point number
; Output: eax = number of iterations
GetIterations PROC
	push rbx
	push rsi
	push rdi
	push r12
	push r13
	sub rsp, 20h

	mov r12d, ecx
	mov r13d, edx
	mov edi, -1
	xor ebx, ebx
	xor esi, esi

getit_loop:
	mov ecx, ebx
	mov edx, ebx
	call MulF
	mov dword ptr [rsp], eax

	mov ecx, esi
	mov edx, esi
	call MulF
	mov dword ptr [rsp+4], eax

	mov ecx, dword ptr [rsp]
	mov edx, dword ptr [rsp+4]
	call AddF
	mov ecx, eax
	mov edx, 090000000h
	call AddF
	test eax, 080000000h
	je getit_end

	mov eax, dword ptr [rsp+4]
	or eax, 080000000h
	mov ecx, dword ptr [rsp]
	mov edx, eax
	call AddF
	mov ecx, eax
	mov edx, r12d
	call AddF
	mov dword ptr [rsp+8], eax

	mov ecx, ebx
	mov edx, esi
	call MulF
	mov ecx, eax
	mov edx, eax
	call AddF
	mov ecx, eax
	mov edx, r13d
	call AddF
	mov esi, eax
	mov ebx, dword ptr [rsp+8]

	inc edi
	cmp edi, 32
	jl getit_loop
	mov edi, -1

getit_end:
	mov eax, edi
	add rsp, 20h
	pop r13
	pop r12
	pop rdi
	pop rsi
	pop rbx
	ret
GetIterations ENDP

; ---------- Function: RecreateBitmap -----------------------------------
; Recreates the bitmap for drawing
; Inputs: none
; Output: none
RecreateBitmap PROC
	push rbx
	sub rsp, 28h

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

	add rsp, 28h
	pop rbx
	ret
RecreateBitmap ENDP

; ---------- Function: Draw -----------------------------------
; Draws the Mandelbrot set onto the bitmap
; Inputs: none
; Output: none
Draw PROC
	push rbx
	push rsi
	push rdi
	push rbp
	push r12
	push r13
	sub rsp, 28h

	mov r12, qword ptr [ua_bitmapData]
	test r12, r12
	je draw_end

	mov esi, dword ptr [ua_height]
	sub esi, 4
draw_yo_loop:
	mov ebx, dword ptr [ua_width]
	sub ebx, 4
draw_xo_loop:
	mov ecx, dword ptr [a_pixelSize]
	mov edx, esi
	call MulFint
	mov ecx, dword ptr [a_lowerLeft_y]
	mov edx, eax
	call AddF
	mov r13d, eax

	mov ecx, dword ptr [a_pixelSize]
	mov edx, ebx
	call MulFint
	mov ecx, dword ptr [a_lowerLeft_x]
	mov edx, eax
	call AddF
	mov ecx, eax
	mov edx, r13d
	call GetIterations

	cmp eax, -1
	jne draw_outside
	xor ecx, ecx
	jmp draw_color_ready
draw_outside:
	and eax, 0Fh
	lea rdx, a_colour_pallet
	mov ecx, dword ptr [rdx + rax*4]
draw_color_ready:

	mov ebp, 3
draw_yi_loop:
	mov edi, 3
draw_xi_loop:
	mov eax, esi
	add eax, ebp
	imul eax, dword ptr [ua_width]
	add eax, ebx
	add eax, edi
	shl eax, 2
	mov rdx, r12
	add rdx, rax
	mov dword ptr [rdx], ecx
	dec edi
	jge draw_xi_loop
	dec ebp
	jge draw_yi_loop

	sub ebx, 4
	jge draw_xo_loop
	sub esi, 4
	jge draw_yo_loop

draw_end:
	add rsp, 28h
	pop r13
	pop r12
	pop rbp
	pop rdi
	pop rsi
	pop rbx
	ret
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
	;64bit-specific
	mov eax, r9d
	and eax, 0FFFFh
	mov dword ptr [a_mousePos_x], eax

	;64bit-specific
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
	js SetZoom_zoom_in
	;{
		mov ebx, dword ptr [a_zoom_factor_out]
		jmp SetZoom_zoom_end
	;}
SetZoom_zoom_in:
	;{
		mov ebx, dword ptr [a_zoom_factor_in]
	;}
SetZoom_zoom_end:

	mov ecx, dword ptr [a_pixelSize]
	mov edx, ebx
	call MulF
	mov esi, eax
	cmp esi, dword ptr [a_pixelSize]
	jne SetZoom_no_min_pixelSize
	;{
		inc esi
	;}
SetZoom_no_min_pixelSize:

	;x
	;{
		mov ecx, dword ptr [a_pixelSize]
		mov edx, dword ptr [a_mousePos_y]
		call MulFint
		mov dword ptr [a_tmp0], eax

		mov ecx, esi
		mov edx, dword ptr [a_mousePos_y]
		call MulFint
		or eax, 080000000h

		mov ecx, dword ptr [a_tmp0]
		mov edx, eax
		call AddF

		mov ecx, dword ptr [a_lowerLeft_y]
		mov edx, eax
		call AddF
		mov dword ptr [a_lowerLeft_y], eax
	;}

	;y
	;{
		mov ecx, dword ptr [a_pixelSize]
		mov edx, dword ptr [a_mousePos_x]
		call MulFint
		mov dword ptr [a_tmp0], eax

		mov ecx, esi
		mov edx, dword ptr [a_mousePos_x]
		call MulFint
		xor eax, 080000000h

		mov ecx, dword ptr [a_tmp0]
		mov edx, eax
		call AddF

		mov ecx, dword ptr [a_lowerLeft_x]
		mov edx, eax
		call AddF
		mov dword ptr [a_lowerLeft_x], eax
	;}

	mov dword ptr [a_pixelSize], esi

	;test if pixel size is to big
	xor esi, 080000000h
	mov ebx, dword ptr [a_pixelSize_max]
	mov ecx, esi
	mov edx, ebx
	call AddF
	test eax, 080000000h
	je SetZoom_no_fixed_pixelSize
	;{
		mov dword ptr [a_pixelSize], ebx
	;}
SetZoom_no_fixed_pixelSize:

	;Fix to bounds
	;{
		;x
		;{
		;min
			mov eax, dword ptr [a_lowerLeft_x]
			mov ecx, dword ptr [a_lowerLeft_x_min]
			xor ecx, 080000000h

			mov edx, ecx
			mov ecx, eax
			call AddF
			test eax, 080000000h
			je SetZoom_not_x_lower
			;{
				mov eax, dword ptr [a_lowerLeft_x_min]
				mov dword ptr [a_lowerLeft_x], eax
			;}
SetZoom_not_x_lower:

		;max
			mov ecx, dword ptr [a_pixelSize]
			mov edx, 800
			call MulFint
			mov dword ptr [a_tmp1], eax

			mov ecx, dword ptr [a_lowerLeft_x]
			mov edx, dword ptr [a_tmp1]
			call AddF

			mov ecx, dword ptr [a_upperRight_x_max]
			xor ecx, 080000000h
			mov edx, ecx
			mov ecx, eax
			call AddF

			test eax, 080000000h
			jne SetZoom_not_x_higher
			;{
				mov eax, dword ptr [a_lowerLeft_x_min]
				mov dword ptr [a_lowerLeft_x], eax
			;}
SetZoom_not_x_higher:
		;}

		;y
		;{
		;min
			mov eax, dword ptr [a_lowerLeft_y]
			mov ecx, dword ptr [a_lowerLeft_y_min]
			xor ecx, 080000000h

			mov edx, ecx
			mov ecx, eax
			call AddF
			test eax, 080000000h
			je SetZoom_not_y_lower
			;{
				mov eax, dword ptr [a_lowerLeft_y_min]
				mov dword ptr [a_lowerLeft_y], eax
			;}
SetZoom_not_y_lower:

		;max
			mov ecx, dword ptr [a_pixelSize]
			mov edx, 600
			call MulFint
			mov dword ptr [a_tmp1], eax

			mov ecx, dword ptr [a_lowerLeft_y]
			mov edx, dword ptr [a_tmp1]
			call AddF

			mov ecx, dword ptr [a_upperRight_y_max]
			xor ecx, 080000000h
			mov edx, ecx
			mov ecx, eax
			call AddF

			test eax, 080000000h
			jne SetZoom_not_y_higher
			;{
				mov eax, dword ptr [a_lowerLeft_y_min]
				mov dword ptr [a_lowerLeft_y], eax
			;}
SetZoom_not_y_higher:
		;}
	;}

	mov word ptr [a_mouseWheel_state], 0

winMain_setzoom_end:
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
