;https://stackoverflow.com/questions/71579808/masm-14-constant-expected-in-winextra-inc
;winextra.inc
;https://stackoverflow.com/questions/16500656/which-color-gradient-is-used-to-color-mandelbrot-in-wikipedia

.386
.model flat, stdcall
option casemap :none

include c:\masm32\include\Windows.inc
include c:\masm32\include\user32.inc
include c:\masm32\include\gdi32.inc

includelib c:\masm32\lib\user32.lib
includelib c:\masm32\lib\gdi32.lib

;https://justine.lol/sizetricks/

STACK_RESERVE_VARIABLES EQU 204 ;need to Reserve: 188+16 = 204 bytes

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; RECT:
;;;;;   LONG: left
;;;;;   LONG: top
;;;;;   LONG: right
;;;;;   LONG: bittom
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ua_rect DWORD 0,0,0,0 ;Offset 188, size 4*4=16
VARIABLE_OFF_ua_rect EQU 188

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; WNDCLASSEXA:
;;;;;    UINT:cbSize
;;;;;    UINT: style;
;;;;;    WNDPROC: lpfnWndProc;
;;;;;    int: cbClsExtra;
;;;;;    int: cbWndExtra;
;;;;;    HINSTANCE: hInstance;
;;;;;    HICON: hIcon;
;;;;;    HCURSOR: hCursor;
;;;;;    HBRUSH: hbrBackground;
;;;;;    LPCSTR: lpszMenuName;
;;;;;    LPCSTR: lpszClassName;
;;;;;    HICON: hIconSm;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ua_wc DWORD 0,0,0,0,0,0,0,0,0,0,0,0 ;Offset 140, size 12*4=48
VARIABLE_OFF_ua_wc EQU 140

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; MSG:
;;;;;   HWND: hwnd
;;;;;   UINT: hwnd
;;;;;   WPARAM: hwnd
;;;;;   LPARAM: hwnd
;;;;;   DWORD: hwnd
;;;;;   POINT: hwnd
;;;;;       Long: x
;;;;;       Long: y
;;;;;   DWORD: hwnd
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ua_msg DWORD 0,0,0,0,0,0,0,0 ;Offset 108, size 8*4=32
VARIABLE_OFF_ua_msg EQU 108


;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; BITMAPINFO:
;;;;;   BITMAPINFOHEADER: bmiHeader
;;;;;       DWORD biSize;
;;;;;       LONG  biWidth;
;;;;;       LONG  biHeight;
;;;;;       WORD  biPlanes;
;;;;;       WORD  biBitCount;
;;;;;       DWORD biCompression;
;;;;;       DWORD biSizeImage;
;;;;;       LONG  biXPelsPerMeter;
;;;;;       LONG  biYPelsPerMeter;
;;;;;       DWORD biClrUsed;
;;;;;       DWORD biClrImportant;
;;;;;   RGBQUAD: bmiColors[1]
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ua_bmi DWORD 0,0,0,0,0,0,0,0,0,0,0 ;Offset 64, size 11*4=44
VARIABLE_OFF_ua_bmi EQU 64

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; PAINTSTRUCT:
;;;;;   HDC: hdc
;;;;;   BOOL: fErase        ;DWORD
;;;;;   RECT:
;;;;;       LONG: left
;;;;;       LONG: top
;;;;;       LONG: right
;;;;;       LONG: bittom
;;;;;   BOOL: rcPaint       ;DWORD
;;;;;   BOOL: fIncUpdate    ;DWORD
;;;;;   BYTE: rgbReserved[32]
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;ua_paintstruct DWORD 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ;Offset 0, size 16*4=64
VARIABLE_OFF_ua_paintstruct EQU 0

.data ;.const
    g_szClassName DB "A",0;
    c_window_title DB "Mandelbrot set",0

.data ;.data?

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;; HDC:
    ;;;;;   HANDLE: hdc
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ua_hdc DWORD 0

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;; HWND:
    ;;;;;   HANDLE: hwnd
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ua_hwnd DWORD 0

    ;ua_graphics_buffer:
    ;{
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;; HANDLE:
    ;;;;;   HBITMAP: hbitmap
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ua_hbitmap DWORD 0

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;; Pointer:
    ;;;;;   Pointer: pointer
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ua_bitmapData DWORD 0
    ;} 


.data
    local_variable_start DWORD 0 ;gets set to stack pointer at start after reserving stack space

    a_enable_draw BYTE 1 ;TODO ?berlegen ob lieber dword
    a_mouseWheel_state WORD 0 ;TODO ?berlegen ob lieber dword
    a_mousePos_x DWORD 0
    a_mousePos_y DWORD 0
    a_lowerLeft_x DWORD 089000000h  ;-2.25
    a_lowerLeft_y DWORD 0855551D7h  ;-1.33332
    
    a_lowerLeft_x_min DWORD 089000000h ;-2
    a_lowerLeft_y_min DWORD 0855551D7h ;-1.166648
    a_upperRight_x_max DWORD 0455475Ah ;1.08328
    a_upperRight_y_max DWORD 04AAAE29h ;1.16668

    a_pixelSize DWORD 044444h ; 0.0041666
    a_pixelSize_max DWORD 044444h ; 0.0041666

    a_colour_pallet DWORD 0FF190720h,0FF421E0Fh,0FF6A3403h,0FF995700h,0FFCC8000h,0FFFFAA00h,0FFF8C95Fh,0FFF1E9BFh,0FFD3ECF8h,0FF86B5E5h,0FF397DD1h,0FF1852B1h,0FF0C2C8Ah,0FF000764h,0FF040449h,0FF09012Fh   ;rr,gg,bb
    ;r,g,b
    ;25,7,26     /19,07,20
    ;66,30,15    /42,1E,0F
    ;106,52,3    /6A,34,03
    ;153,87,0    /99,57,00
    ;204,128,0   /CC,80,00
    ;255,170,0   /FF,AA,00
    ;248,201,95  /F8,C9,5F
    ;241,233,191 /F1,E9,BF
    ;211,236,248 /D3,EC,F8
    ;134,181,229 /86,B5,E5
    ;57,125,209  /39,7D,D1
    ;24,82,177   /18,52,B1
    ;12,44,138   /0C,2C,8A
    ;0,7,100     /00,07,64
    ;4,4,73      /04,04,49
    ;9,1,47      /09,01,2F




.code
;https://learn.microsoft.com/en-us/windows/win32/inputdev/mouse-input-notifications
;https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-wndproc
;https://learn.microsoft.com/en-us/windows/win32/winmsg/about-messages-and-message-queues#system-defined-messages
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; WINDOW PROCEDURE;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
WndProc PROC hwnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD
    ;push ebp  
    ;mov  ebp,esp 


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; Close Window, TODO vielleicht schon in default mit drin
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    cmp  dword ptr [ebp+12], 0010h ; msg, WM_CLOSE
    jne wndProc_caseCloseEnd
    ;{
        ;DestroyWindow
        push dword ptr [ebp+8] ; hwnd
        call DestroyWindow

        ;return
        xor eax,eax
        jmp wndProc_return
    ;}
    wndProc_caseCloseEnd:

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; Destroy Window, TODO vielleicht schon in default mit drin
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    cmp  dword ptr [ebp+12], 0002h ; msg, WM_DESTROY
    jne wndProc_caseDestroyEnd
    ;{
        ;PostQuitMessage
        push 0
        call PostQuitMessage

        ;return
        xor eax,eax
        jmp wndProc_return
    ;}
    wndProc_caseDestroyEnd:

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; MouseWheel
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    cmp  dword ptr [ebp+12], 020Ah ; msg, WM_MOUSEWHEEL
    jne wndProc_caseMouseWheel
    ;{
        ;https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousewheel
        ;get mouse wheel movement
        mov ax, word ptr [ebp+18]  ;16bit eax
        mov a_mouseWheel_state, ax

        ;set draw command
        mov a_enable_draw, 1
    ;}
    wndProc_caseMouseWheel:

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; MousePos
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    cmp  dword ptr [ebp+12], 0200h ; msg, WM_MOUSEWHEEL
    jne wndProc_caseMouseMove
    ;{
        xor eax, eax               ;clear leading 16 bit
        mov ax, word ptr [ebp+20]  ;16 bit eax
        mov a_mousePos_x, eax

        mov ax, word ptr [ebp+22]  ;16 bit eax
        mov ecx, 600                 ;height
        sub ecx, eax                 ;invert logic
        sub ecx, 1                   ;invert logic
       
        mov a_mousePos_y, ecx

    ;}
    wndProc_caseMouseMove:

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; Create Bitmap, Window create event
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
     cmp  dword ptr [ebp+12], 1 ; msg, WM_CREATE
     jne wndProc_caseCreateBitmap
       
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;; Client Rectangle
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;GetClientRect
        mov ecx, local_variable_start
        add ecx, VARIABLE_OFF_ua_rect
        push ecx
        push dword ptr [ebp+8]
        call GetClientRect

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;; Bitmap creation
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;https://stackoverflow.com/questions/70620450/draw-raw-array-of-pixels-onto-a-window-c-winapi
        mov ecx, local_variable_start
        add ecx, VARIABLE_OFF_ua_bmi
        mov dword ptr[ecx], 40 ;biSize=sizeof(BITMAPINFOHEADER)
        mov dword ptr[ecx+4], 800
        mov dword ptr[ecx+8], 600
        mov word ptr[ecx+12], 1 ;biPlanes=sizeof(BITMAPINFOHEADER)
        mov word ptr[ecx+14], 32 ;biBitCount=sizeof(BITMAPINFOHEADER)
        mov dword ptr[ecx+16], 0 ;biCompression=BI_RGB
        mov dword ptr[ecx+20], 0 ;biSizeImage=0 TODO WEG
        mov dword ptr[ecx+24], 0 ;biXPelsPerMeter=0 TODO WEG
        mov dword ptr[ecx+28], 0 ;biYPelsPerMeter=0 TODO WEG
        mov dword ptr[ecx+32], 0 ;biClrUsed=0 TODO WEG
        mov dword ptr[ecx+36], 0 ;biClrImportant=0 TODO WEG
        mov dword ptr[ecx+40], 0 ;RGBQUAD=0 TODO WEG

        ;CreateDIBSection
        push 0
        push 0
        push OFFSET ua_bitmapData
        push 0                      ;DIB_RGB_COLORS
        mov ecx, local_variable_start
        add ecx, VARIABLE_OFF_ua_bmi
        push ecx
        push 0                      ;optional HDC
        call CreateDIBSection
        mov ua_hbitmap, eax


     wndProc_caseCreateBitmap:

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; Paint
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    cmp  dword ptr [ebp+12], 000Fh ; msg, WM_PAINT
    jne wndProc_casePaintEnd
    ;{
        ;https://stackoverflow.com/questions/70620450/draw-raw-array-of-pixels-onto-a-window-c-winapi
        ;BeginPaint
        mov eax, local_variable_start
        add eax, VARIABLE_OFF_ua_paintstruct
        push eax
        push dword ptr [ebp+8]
        call BeginPaint
        
        ;save hdc on stack
        push eax

        ;CreateCompatibleDC
        push eax
        call CreateCompatibleDC

        ;save hdc_bmp on stack
        push eax

        ;SelectObject
        push ua_hbitmap
        push eax 
        call SelectObject

        ;save old_bmp
        push eax

        ;https://board.flatassembler.net/topic.php?t=908 TODO
        ;BitBlt
        push 0CC0020h ;SRCCOPY
        push 0
        push 0
        push [esp+16] ;+4 + 3 pushs vorher = hdc_bmp
        push 600
        push 800
        push 0
        push 0
        push [esp+40] ;+8 + 8 pushs vorher = hdc
        call BitBlt

        ;SelectObject
        push [esp]   ;old_bmp
        push [esp+8] ;hdc
        call SelectObject

        ;DeleteDC
        push [esp+4] ;hdc_bmp

        ;EndPaint
        mov eax, local_variable_start
        add eax, VARIABLE_OFF_ua_paintstruct
        push eax
        push dword ptr [ebp+8]

        ;restore stack from 3 saved values
        add esp, 12

        ;return
        xor eax,eax
        jmp wndProc_return
    ;}
    wndProc_casePaintEnd:
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; Default
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;DefWindowProc
    push dword ptr [ebp+20] ; lParam
    push dword ptr [ebp+16] ; wParam
    push dword ptr [ebp+12] ; msg
    push dword ptr [ebp+8] ; hwnd
    call DefWindowProc;

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; Return
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    wndProc_return:
    ;return
    ;leave
    ;pop ebp
    ret

;END WndProc
WndProc ENDP

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; MulF: 1bit sign, 5bit pre dot, 26 bit after dot (S?????.??????????????????????????)
;;;;;;;;;;;;;;;;;;;;;;;;
MulF PROC a:DWORD, b:DWORD
;{
    mov eax, [ebp+8]    ;eax = a
    mov edx, [ebp+12]   ;edx = b

    mov ecx, 0 ;result sign

    test eax, 080000000h ;test a sign
    je MulF_a_positiv
    ;{
        xor ecx, 1  ;toggle sign
        and eax, 07FFFFFFFh ;remove a sign
    ;}
    MulF_a_positiv:

    test edx, 080000000h ;test b sign
    je MulF_b_positiv
    ;{
        xor ecx, 1  ;toggle sign
        and edx, 07FFFFFFFh ;remove b sign
    ;}
    MulF_b_positiv:

    mul edx
    ;edx high bits
    ;eax low bits

    sal ecx, 25  ;shift sign to right pos (57%32=25)
    or edx, ecx  ;add sign to result

    mov ecx, 26
    ;shift 26 to the right
    MulF_result_shift_right:
    ;{
        shr eax, 1 ;shift lower one to the right
        shr edx, 1 ;shift higher one to the right
        jae MulF_no_carry_shifted
        ;{
            or eax, 080000000h ;add carry from higher
        ;}
        MulF_no_carry_shifted:

        sub ecx, 1
        jg MulF_result_shift_right
    ;}
    MulF_result_shift_right_end:

    ret
;}
MulF ENDP

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; MulF: 1bit sign, 5bit pre dot, 26 bit after dot (S?????.??????????????????????????)
;;;;;;;;;;;;;;;;;;;;;;;;
MulFint PROC a:DWORD, b:DWORD ;a = decimal, b = int
;{
    mov eax, [ebp+8]    ;eax = a
    mov edx, [ebp+12]   ;edx = b
     
    mov ecx, 0 ;result sign

    test eax, 080000000h ;test a sign
    je MulFint_a_positiv
    ;{
        xor ecx, 1  ;toggle sign
        and eax, 07FFFFFFFh ;remove a sign
    ;}
    MulFint_a_positiv:

    test edx, 080000000h ;test b sign
    je MulFint_b_positiv
    ;{
        neg edx ;turn positive
        xor ecx, 1  ;toggle sign
    ;}
    MulFint_b_positiv:

    mul edx
    and eax, 07FFFFFFFh ;remove highest bit
    sal ecx, 31 ;shift sign at right pos
    or eax, ecx ;add sign

    ret
;}
MulFint ENDP

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; AddF: 1bit sign, 5bit pre dot, 26 bit after dot (S?????.??????????????????????????)
;;;;;;;;;;;;;;;;;;;;;;;;
AddF PROC a:DWORD, b:DWORD
;{
    mov eax, [ebp+8]    ;eax = a
    mov ecx, [ebp+12]   ;ecx = b

    test eax, 080000000h ;test a sign
    je AddF_a_positiv
    ;{
        and eax, 07FFFFFFFh ;remove a sign
        neg eax
    ;}
    AddF_a_positiv:

    test ecx, 080000000h ;test b sign
    je AddF_b_positiv
    ;{
        and ecx, 07FFFFFFFh ;remove b sign
        neg ecx
    ;}
    AddF_b_positiv:

    add eax, ecx
    jns AddF_result_positive
    ;{
        neg eax
        or eax, 080000000h ;set sign
    ;}
    AddF_result_positive:

    ret
;}
AddF ENDP

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; GetIterations
;;;;;;;;;;;;;;;;;;;;;;;;
GetIterations PROC x:DWORD, y:DWORD
;{
    push ebx ;Zn_x
    push esi ;Zn_y
    push edi ;iterations
    
  
    mov edi, -1 ;iterations
    mov ebx, 0 ;Zn_x
    mov esi, 0 ;Zn_y

    GetIterations_Loop:
    ;{
        ;Zn+1
        ;{
            ;Zn_x*Zn_x
            push ebx ;Zn_x
            push ebx ;Zn_x
            call MulF
            push eax ;save

            ;Zn_y*Zn_y
            push esi
            push esi
            call MulF
            push eax ;save

            ;check finished
            ;{
                ;result must be smaler qual than 4
                push [esp] ;Zn_y*Zn_y
                push [esp+4] ;Zn_x*Zn_x
                call AddF
                
                ;subtract 4
                push 090000000h ;-4
                push eax
                call AddF

                test eax, 080000000h
                jne GetIterations_no_clean_up
                ;{
                    pop eax     ;clean-up neaded if break
                    pop eax     ;clean-up neaded if break
                    jmp GetIterations_end
                ;}
                GetIterations_no_clean_up:
            ;}

            ;invert Zn_y*Zn_y
            ;eax still on stack
            pop eax
            or eax, 080000000h ;negate

            push eax ;-Zn_y*Zn_y 

            ;-Zn_y*Zn_y already on stack
            ;Zn_x*Zn_x already on stack
            call AddF
            ;eax = Zn_x*Zn_x-Zn_y*Zn_y

            ;add Cx
            push eax ;(Zn_x)^2
            push [ebp+8] ;Cx
            call AddF
            push eax ;save Zn+1_x

            ;Zn_x*Zn_y
            push ebx ;Zn_x
            push esi ;Zn_y
            call MulF

            ;Zn_x*Zn_y*2
            push eax
            push eax
            call AddF
           
            ;add Cy
            push eax ;(Zn_y)^2
            push [ebp+12] ;Cy
            call AddF

            ;set next gen
            mov esi, eax ;Zn_y = Zn+1_y
            pop ebx ;Zn_x = Zn+1_x

            add edi, 1 ;iterations++

            mov eax, 32 ;PARAM a_maxIterations
            cmp eax, edi
            jne GetIterations_Loop

            mov edi, -1
            jmp GetIterations_end
        ;}
    ;}

    GetIterations_end:

    mov eax, edi

    pop edi
    pop esi
    pop ebx

    ret
;}
GetIterations ENDP



;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Draw
;;;;;;;;;;;;;;;;;;;;;;;;
;No Params
Draw PROC ;TODO eventuell inline um speicher zu sparen
;{
    push ebx ;xO ;TODO pushs zusammenfassen
    push esi ;yO
    push edi ;xI
    push ebp ;yI ;TODO aufpassen basepointer genutzt

    mov esi, 596    ;yO ;DRAWPIXELSIZE PARAM
    Draw_yO_loop:
    ;{
        mov ebx, 796    ;xO ;DRAWPIXELSIZE PARAM
        Draw_xO_Loop:
        ;{
            ;y computation
            ;{
                push esi           ;int y
                push a_pixelSize   ;decimal pixelSize
                call MulFint

                ;x add offset
                ;eax = y*pixelsize
                push a_lowerLeft_y
                push eax
                call AddF

                ;eax = y * pixelsize + lowerLeft_y
                push eax  ;save y value
            ;}

            ;x computation
            ;{
                push ebx           ;int x
                push a_pixelSize   ;decimal pixelSize
                call MulFint

                ;x add offset
                ;eax = x*pixelsize
                push a_lowerLeft_x
                push eax
                call AddF

                ;eax = x * pixelsize + lowerLeft_x
                push eax  ;save x value
            ;}
           
            ;x and y already on stack
            call GetIterations

            cmp eax, -1
            jne Draw_outside
            ;{
                mov ecx, 0
                jmp Draw_outside_end
            ;}
            Draw_outside:
            ;{
                and eax, 0Fh ;%16 for 16 colours
                mov ecx, [OFFSET a_colour_pallet + eax*4]
            ;}
            Draw_outside_end:


            mov ebp, 3 ;yI  ;DRAWPIXELSIZE PARAM
            Draw_yI_Loop:
            ;{
                 mov edi, 3 ;xI     ;DRAWPIXELSIZE PARAM
                 Draw_xI_Loop:
                 ;{
                        ;Index
                        mov eax, esi
                        add eax, ebp
                        mov edx, 800 ;width
                        mul edx                 ;eax=y*width
                        add eax, ebx            ;eax=y*width+xO
                        add eax, edi            ;eax=y*width+xI
                        sal eax, 2              ;eax=(y*width+x)*4
                        add eax, ua_bitmapData  ;eax=arrayOffset+(y*width+x)*4

                        ;draw pixel
                        mov dword ptr [eax],ecx
                 ;}
                 sub edi, 1
                 jge Draw_xI_Loop
            ;}
            sub ebp, 1
            jge Draw_yI_Loop

        ;}
        sub ebx, 4  ;DRAWPIXELSIZE PARAM
        jge Draw_xO_Loop
    ;}
    sub esi, 4  ;DRAWPIXELSIZE PARAM
    jge Draw_yO_loop


    pop ebp
    pop edi
    pop esi
    pop ebx
    ret
;}
Draw ENDP

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; WinMain
;;;;;;;;;;;;;;;;;;;;;;;;
start:
WinMain PROC hInstance:DWORD, hPrevInstance:DWORD, lpCmdLine:DWORD, nCmdShow:DWORD
    push ebx
    push esi
    
    sub esp, STACK_RESERVE_VARIABLES ;reserve stack for local variables
    mov local_variable_start, esp ;fully decending -> first variable at offset 0

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Registering the Window Class
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    
    mov ebx, local_variable_start
    add ebx, VARIABLE_OFF_ua_wc
    mov dword ptr[ebx]    , 48 ;cbSize=12*4
    mov dword ptr[ebx+4]  , 0  ;syle=0
    mov dword ptr[ebx+8]  , OFFSET WndProc  ;lpfnWndProc=WndProc
    mov dword ptr[ebx+12] , 0  ;cbClsExtra=0
    mov dword ptr[ebx+16] , 0  ;cbWndExtra=0
    mov eax,  dword ptr[ebp+8]
    mov dword ptr[ebx+20] , eax ;hInstance=hInstance
    ;RegisterClassEx
    push 7F00h
    push 0
    call LoadIcon
    mov dword ptr[ebx+24] , eax  ;hIcon=LoadIcon(0,IDI_APPLICATION)
    mov dword ptr[ebx+44] , eax  ;hIconSm=LoadIcon(0,IDI_APPLICATION)
    push 7F00h
    push 0
    invoke  LoadCursor, 0, IDC_ARROW
    mov dword ptr[ebx+28] , eax  ;hCursor=LoadCursor(0,IDC_ARROW)
    mov dword ptr[ebx+32] , 6  ;hbrBackground=COLOR_WINDOW+1
    mov dword ptr[ebx+36] , 0  ;lpszMenuName=0
    mov dword ptr[ebx+40] , OFFSET g_szClassName  ;lpszClassName=(string)g_szClassName
    

    mov eax, local_variable_start
    add eax, VARIABLE_OFF_ua_wc
    push eax
    call RegisterClassEx

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Create Window
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;CreateWindowEx
    push 0  
    push dword ptr[ebp+8]      ;hInstance  
    push 0  
    push 0  
    push 600  
    push 800
    push 80000000h             ;CW_USEDEFAULT
    push 80000000h             ;CW_USEDEFAULT
    push 0A0000h               ;WS_OVERLAPPEDWINDOW
    push offset c_window_title  
    push offset g_szClassName 
    push 200h                  ;WS_EX_CLIENTEDGE
    call CreateWindowEx
    mov ua_hwnd, eax

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Show Window
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;ShowWindow
    push 1  ;SW_SHOWNORMAL
    push ua_hwnd
    call ShowWindow;

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Update Window
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;UpdateWindow
    push ua_hwnd

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;; The Message Loop
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    winMain_while_true:
    ;{
        ;GetMessage
        push 0
        push 0
        push 0
        mov eax, local_variable_start
        add eax, VARIABLE_OFF_ua_msg
        push eax
        call GetMessage; OFFSET ua_msg, 0, 0, 0

        cmp eax, 0
        je winMain_while_true_end

        ;TranslateMessage
        mov eax, local_variable_start
        add eax, VARIABLE_OFF_ua_msg
        push eax
        
        ;DispatchMessage
        push eax
        call DispatchMessage


        mov al, a_enable_draw  ;disableDraw ;1byte eax
        cmp al, 0
        je winMain_if_draw_end
        ;{
            ;disable_draw
            mov a_enable_draw, 0

            ;SetZoom
            ;;;;;;;;;;;;;;;;;;;;;;;;
            ;;;;; SetZoom
            ;;;;;;;;;;;;;;;;;;;;;;;;
            ;No Params
            ;SetZoom PROC
            ;{
                mov ax, a_mouseWheel_state ;16 bit eax

                cmp ax,0
                je SetZoom_end
                js SetZoom_zoom_in
                ;{
                    mov ebx, 003A2E8BAh; PARAM a_zoom_factor_out ;0.90909090
                    jmp SetZoom_zoom_end
                ;}
                SetZoom_zoom_in:
                ;{
                    mov ebx, 004666666h; PARAM a_zoom_factor_in ;1.1
                ;}
                SetZoom_zoom_end:

                push a_pixelSize
                push ebx
                call MulF
                mov esi, eax ;esi new pixel size
                cmp esi, a_pixelSize
                jne SetZoom_no_min_pixelSize
                ;{
                    add esi, 1
                ;}
                SetZoom_no_min_pixelSize:


                ;x
                ;{
                    push a_mousePos_y  ;int y
                    push a_pixelSize   ;decimal pixelSize
                    call MulFint
                    ;eax = real distance yO to y
                    push eax ;save

                    push a_mousePos_y
                    push esi            ;new pixel size
                    call MulFint
                    ;eax = real distance y0 to y with new pixelSize
                    or eax, 080000000h   ;negate
                    push eax

                    ;params already pushed
                    call AddF
                    ;eax=offset for new lower_left_y

                    push eax
                    push a_lowerLeft_y
                    call AddF
                    mov a_lowerLeft_y, eax
                ;}

                ;y
                ;{
                    push a_mousePos_x  ;int x
                    push a_pixelSize   ;decimal pixelSize
                    call MulFint
                    ;eax = real distance xO to x
                    push eax ;save

                    push a_mousePos_x
                    push esi            ;new pixel size
                    call MulFint
                    ;eax = real distance x0 to x with new pixelSize
                    xor eax, 080000000h   ;negate
                    push eax

                    ;params already pushed
                    call AddF
                    ;eax=offset for new lower_left_x

                    push eax
                    push a_lowerLeft_x
                    call AddF
                    mov a_lowerLeft_x, eax
                ;}

                mov a_pixelSize, esi

                ;test if pixel size is to big
                xor esi, 080000000h   ;negate
                mov ebx, a_pixelSize_max
                push ebx
                push esi
                call AddF
                test eax, 080000000h
                je SetZoom_no_fixed_pixelSize
                ;{
                    mov a_pixelSize, ebx
                ;}
                SetZoom_no_fixed_pixelSize:
    
    

                SetZoom_end:

                ;Fix to bounds
                ;{
                    ;x
                    ;{
                    ;min
                        mov eax, a_lowerLeft_x
                        mov ecx, a_lowerLeft_x_min
                        xor ecx, 080000000h   ;negate
            
                        push eax
                        push ecx
                        call AddF

                        test eax, 080000000h
                        je SetZoom_not_x_lower
                        ;{
                            mov eax, a_lowerLeft_x_min
                            mov a_lowerLeft_x, eax
                        ;}
                        SetZoom_not_x_lower:

                    ;max
                        push 800 ;width
                        push a_pixelSize
                        call MulFint
                        ;eax right bound value

                        push eax
                        push a_lowerLeft_x
                        call AddF
                        ;eax real right bound value

                        mov ecx, a_upperRight_x_max
                        xor ecx, 080000000h   ;negate

                        push eax
                        push ecx
                        call AddF

                        test eax, 080000000h
                        jne SetZoom_not_x_higher
                        ;{
                            mov eax, a_lowerLeft_x_min
                            mov a_lowerLeft_x, eax
                        ;}
                        SetZoom_not_x_higher:
                    ;}
        
                    ;y
                    ;{
                    ;min
                        mov eax, a_lowerLeft_y
                        mov ecx, a_lowerLeft_y_min
                        xor ecx, 080000000h   ;negate
            
                        push eax
                        push ecx
                        call AddF

                        test eax, 080000000h
                        je SetZoom_not_y_lower
                        ;{
                            mov eax, a_lowerLeft_y_min
                            mov a_lowerLeft_y, eax
                        ;}
                        SetZoom_not_y_lower:

                    ;max
                        push 600;height
                        push a_pixelSize
                        call MulFint
                        ;eax right bound value

                        push eax
                        push a_lowerLeft_y
                        call AddF
                        ;eax real right bound value

                        mov ecx, a_upperRight_y_max
                        xor ecx, 080000000h   ;negate

                        push eax
                        push ecx
                        call AddF

                        test eax, 080000000h
                        jne SetZoom_not_y_higher
                        ;{
                            mov eax, a_lowerLeft_y_min
                            mov a_lowerLeft_y, eax
                        ;}
                        SetZoom_not_y_higher:
                    ;}

                ;}


                
                ;ret
            ;}
            ;SetZoom ENDP

            ;Draw
            call Draw

            ;https://stackoverflow.com/questions/3954895/wm-paint-not-being-called-after-window-is-created
            ;InvalidateRect / redraw
            push 0
            mov ecx, local_variable_start
            add ecx, VARIABLE_OFF_ua_rect
            push ecx
            push ua_hwnd
            call InvalidateRect
        ;}
        winMain_if_draw_end:

        

        
    ;}
    jmp winMain_while_true
    winMain_while_true_end:

    ;restore stack to state before reserving local variables
    add esp, STACK_RESERVE_VARIABLES

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;; return
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    pop esi
    pop ebx
    
    xor eax, eax
    ret
    ;TODO min pixel size
    ;TODO bigger pixels (faster)
WinMain ENDP
END start



