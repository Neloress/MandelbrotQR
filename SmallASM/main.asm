;https://stackoverflow.com/questions/71579808/masm-14-constant-expected-in-winextra-inc
;winextra.inc

.386
.model flat, stdcall
option casemap :none

include c:\masm32\include\Windows.inc
include c:\masm32\include\user32.inc
include c:\masm32\include\gdi32.inc

includelib c:\masm32\lib\user32.lib
includelib c:\masm32\lib\gdi32.lib

;https://justine.lol/sizetricks/

.const
    g_szClassName DB "A",0;
    c_window_title DB "Mandelbrot set",0
    c_Width DWORD 800
    c_Height DWORD 600

.data?
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;; RECT:
    ;;;;;   LONG: left
    ;;;;;   LONG: top
    ;;;;;   LONG: right
    ;;;;;   LONG: bittom
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ua_rect DWORD 0,0,0,0

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;; HDC:
    ;;;;;   HANDLE: hdc
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ua_hdc DWORD 0

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
    ua_wc DWORD 0,0,0,0,0,0,0,0,0,0,0,0

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;; HWND:
    ;;;;;   HANDLE: hwnd
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ua_hwnd DWORD 0

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
    ua_msg DWORD 0,0,0,0,0,0,0,0

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
    ua_bmi DWORD 0,0,0,0,0,0,0,0,0,0,0
    
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
    ua_paintstruct DWORD 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0


.data
    a_enable_draw BYTE 1 ;TODO überlegen ob lieber dword
    a_mouseWheel_state WORD 0 ;TODO überlegen ob lieber dword
    a_mousePos_x DWORD 0
    a_mousePos_y DWORD 0

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
        ;get mouse wheel movement
        xor eax, eax               ;clear leading 16 bit
        mov ax, word ptr [ebp+20]  ;16 bit eax
        mov a_mousePos_x, eax

        mov ax, word ptr [ebp+22]  ;16 bit eax
        mov a_mousePos_y, eax

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
        push OFFSET ua_rect
        push dword ptr [ebp+8]
        call GetClientRect

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;; Bitmap creation
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;https://stackoverflow.com/questions/70620450/draw-raw-array-of-pixels-onto-a-window-c-winapi
        mov ecx, OFFSET ua_bmi
        mov dword ptr[ecx], 40 ;biSize=sizeof(BITMAPINFOHEADER)
        mov eax,[OFFSET ua_rect+8]
        mov dword ptr[ecx+4], eax ;biWidth=[OFFSET ua_rect+8]
        mov eax,[OFFSET ua_rect+12]
        ;neg eax ;without neg normal karthesich
        mov dword ptr[ecx+8], eax ;biHeight=[OFFSET ua_rect+12]
        mov word ptr[ecx+12], 1 ;biPlanes=sizeof(BITMAPINFOHEADER)
        mov word ptr[ecx+14], 32 ;biBitCount=sizeof(BITMAPINFOHEADER)
        mov dword ptr[ecx+16], 0 ;biCompression=BI_RGB
        mov dword ptr[ecx+20], 0 ;biSizeImage=0 TODO WEG
        mov dword ptr[ecx+24], 0 ;biXPelsPerMeter=0 TODO WEG
        mov dword ptr[ecx+28], 0 ;biYPelsPerMeter=0 TODO WEG
        mov dword ptr[ecx+32], 0 ;biClrUsed=0 TODO WEG
        mov dword ptr[ecx+36], 0 ;biClrImportant=0 TODO WEG
        mov dword ptr[ecx+40], 0 ;RGBQUAD=0 TODO WEG

        ;GetDC
        push 0
        call GetDC
        push eax
    
        ;CreateDIBSection
        push 0
        push 0
        push OFFSET ua_bitmapData
        push 0                      ;DIB_RGB_COLORS
        push OFFSET ua_bmi
        push eax
        call CreateDIBSection
        mov ua_hbitmap, eax


        ;ReleaseDC
        ;eax still on stack
        push 0
        call ReleaseDC
     wndProc_caseCreateBitmap:

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;;;;; Paint
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    cmp  dword ptr [ebp+12], 000Fh ; msg, WM_PAINT
    jne wndProc_casePaintEnd
    ;{
        ;https://stackoverflow.com/questions/70620450/draw-raw-array-of-pixels-onto-a-window-c-winapi
        ;BeginPaint
        push OFFSET ua_paintstruct
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
        push dword ptr[OFFSET ua_rect+12]
        push dword ptr[OFFSET ua_rect+8]
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
        call DeleteDC

        ;EndPaint
        push OFFSET ua_paintstruct
        push dword ptr [ebp+8]
        call EndPaint

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
;;;;; Add: 1bit dummy 31bit exponent(signed), value=1bit sign, 31bit value(01.??,????,????,????)
;;;;;;;;;;;;;;;;;;;;;;;;
AddF PROC a1:DWORD, a0:DWORD, b1:DWORD, b0:DWORD, resultAddr:DWORD
;{
    push ebx

    ;check a zero
    mov eax, [ebp+12]   ;eax = a0
    or eax, 03FFFFFFFh
    cmp eax, 0
    jne AddF_no_direct_return_b
    ;{
        ;result is eax=value, ecx=exponent
        mov eax, [ebp+20]
        mov ecx, [ebp+16]
        jmp AddF_exponent_finished
    ;}
    AddF_no_direct_return_b:

    ;check b zero
    mov eax, [ebp+20]   ;eax = b0
    or eax, 03FFFFFFFh
    cmp eax, 0
    jne AddF_no_direct_return_a
    ;{
        ;result is eax=value, ecx=exponent
        mov eax, [ebp+12]
        mov ecx, [ebp+8]
        jmp AddF_exponent_finished
    ;}
    AddF_no_direct_return_a:





    mov eax, [ebp+8]    ;eax = a1
    mov ecx, [ebp+16]   ;ecx = b1

    sub ecx, eax        ;check which is greater
    jge AddF_b_greater_equal_a 
    jmp AddF_a_greater_b

    AddF_b_greater_equal_a:
    ;{
        ;ecx = right shift number

        ;if a shifted to right pos smaler than smallest number return b+0
        cmp ecx, 30
        jl AddF_no_return_b
        ;{
            ;result is eax=value, ecx=exponent
            mov eax, [ebp+20]
            mov ecx, [ebp+16]
            jmp AddF_exponent_finished
        ;}
        AddF_no_return_b:

        ;eax = value1
        ;ebx = value2
        ;ecx = shift of value 2
        ;edx = exponent value 1

        mov eax, [ebp+20] ;b0
        mov ebx, [ebp+12] ;a1
        mov edx, [ebp+16] ;b1
        
        jmp AddF_do_add
    ;}

    AddF_a_greater_b:
    ;{
        ;ecx = right shift number
        neg ecx

        ;if b shifted to right pos smaler than smallest number return a+0
        cmp eax, 30
        jl AddF_no_return_a
        ;{
            ;result is eax=value, ecx=exponent
            mov eax, [ebp+12]
            mov ecx, [ebp+8]
            jmp AddF_exponent_finished
        ;}
        AddF_no_return_a:

        ;eax = value1
        ;ebx = value2
        ;ecx = shift of value 2
        ;edx = exponent value 1

        mov eax, [ebp+12] ;a0
        mov ebx, [ebp+20] ;b1
        mov edx, [ebp+8]  ;a1
        
        jmp AddF_do_add
    ;}

    AddF_do_add:
    ;{
        ;eax = value1
        ;ebx = value2

        ;apply sign
        ;{
            test eax, 080000000h  ;test sign flag
            jns AddF_a_positive   ;SF=0
            ;{
                and eax, 03FFFFFFFh    ;remove sign and dummy
                neg eax
            ;}
            and eax, 03FFFFFFFh   ;remove sign and dummy
            AddF_a_positive:


            test ebx, 080000000h  ;test sign flag
            jns AddF_b_positive   ;SF=0
            ;{
                and ebx, 03FFFFFFFh    ;remove sign
                neg ebx
            ;}
            and ebx, 03FFFFFFFh   ;remove sign
            AddF_b_positive:
        ;}



        ;ecx = shift of value 2
        ;edx = exponent value 1


        ;shift value2 to right pos
        ;{
        AddF_shift_loop:
            sub ecx, 1 
            js AddF_no_shift
            sar ebx, 1
            jmp AddF_shift_loop
        ;}
        AddF_no_shift:

        mov ecx, 0
        add eax, ebx        ;if carry is generated, SF is set
        jns Addf_num_pos    ;number is positive
        ;{
            neg eax             ;turn positive
            mov ecx, 1          ;remember is negative
        ;}

    Addf_num_pos:
        test eax, 040000000h
        je AddF_no_carry ;ZF=0
        ;{
            shr eax, 1          ;get the carry back in
            add edx, 1          ;increase exponent by one
        ;}
        AddF_no_carry:

        cmp ecx, 1
        jne AddF_not_neg
        ;{
            or  eax, 080000000h ;add sign
        ;}
        AddF_not_neg:
        
        

        ;result is eax=value, ecx=exponent
        mov ecx, edx
    ;}

    AddF_exponent_finished:

    ;result is eax=value, ecx=exponent
    mov edx, [ebp+24]
    mov [edx], ecx
    mov [edx+4], eax

    pop ebx
    ret
;}
AddF ENDP

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Index
;;;;;;;;;;;;;;;;;;;;;;;;
Index PROC x:DWORD, y:DWORD
;{
    mov ecx, [esp+8] ;x
    mov eax, [esp+12] ;y

    mov edx, [OFFSET ua_rect+8] ;width

    mul edx                 ;eax=y*width
    add eax, ecx            ;eax=y*width+x
    sal eax, 2              ;eax=(y*width+x)*4
    add eax, ua_bitmapData  ;eax=arrayOffset+(y*width+x)*4

    ret
;}   
Index ENDP

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Draw
;;;;;;;;;;;;;;;;;;;;;;;;
;No Params
Draw PROC ;TODO eventuell inline um speicher zu sparen
;{
    push ebx ;TODO pushs zusammenfassen
    push esi
    push edi
    push ebp ;TODO aufpassen basepointer genutzt

    mov ebx, [OFFSET ua_rect+8]  ;width
    mov esi, [OFFSET ua_rect+12] ;height

    mov edi, 0      ;y
    draw_loop_y:
    ;{
    cmp edi, esi
    je draw_loop_y_end
        
        mov ebp, 0  ;x
        draw_loop_x:
        ;{
        cmp ebp, ebx
        je draw_loop_x_end

            ;Index ;TODO eventuell inline um speicher zu sparen
            push edi ;y
            push ebp ;x
            call Index

            ;draw pixel
            ;mov dword ptr [eax],0ffh

        add ebp, 1 ;x++
        jmp draw_loop_x
        ;}
        draw_loop_x_end:
    
    add edi, 1 ;y++
    jmp draw_loop_y
    ;}
    draw_loop_y_end:

    ;TODO weg, draw mouse pos
    mov eax, a_mousePos_y
    sub esi, eax
    sub esi, 1
    push esi
    push a_mousePos_x

    call Index
    mov dword ptr [eax],0ff00h


    ;ende TODO weg

    pop ebp
    pop edi
    pop edi
    pop ebx

    ;TODO weg
    push 0
    push 020000000h
    push 2
    push 030000000h
    push 1    ;a1
    call AddF
    ;ende TODO weg

    ret
;}
Draw ENDP

;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; WinMain
;;;;;;;;;;;;;;;;;;;;;;;;
start:
WinMain PROC hInstance:DWORD, hPrevInstance:DWORD, lpCmdLine:DWORD, nCmdShow:DWORD
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Registering the Window Class
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    push ebx
    mov ebx, OFFSET ua_wc
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
    pop ebx

    push OFFSET ua_wc
    call RegisterClassEx

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Create Window
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;CreateWindowEx
    push 0  
    push dword ptr[ebp+8]      ;hInstance  
    push 0  
    push 0  
    push dword ptr [c_Height]  
    push dword ptr [c_Width]  
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
    call UpdateWindow

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;; The Message Loop
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    winMain_while_true:
    ;{
        ;GetMessage
        push 0
        push 0
        push 0
        push OFFSET ua_msg
        call GetMessage; OFFSET ua_msg, 0, 0, 0

        cmp eax, 0
        je winMain_while_true_end

        ;TranslateMessage
        push OFFSET ua_msg
        call TranslateMessage ;eventeull raus TODO
        
        ;DispatchMessage
        push OFFSET ua_msg
        call DispatchMessage


        mov al, a_enable_draw  ;disableDraw ;1byte eax
        cmp al, 0
        je winMain_if_draw_end
        ;{
            ;disable_draw
            mov a_enable_draw, 0

            ;Draw
            call Draw

            ;https://stackoverflow.com/questions/3954895/wm-paint-not-being-called-after-window-is-created
            ;InvalidateRect / redraw
            push 0
            push OFFSET ua_rect
            push ua_hwnd
            call InvalidateRect
        ;}
        winMain_if_draw_end:

        

        
    ;}
    jmp winMain_while_true
    winMain_while_true_end:

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;; return
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    xor eax, eax
    ret

WinMain ENDP
END start



