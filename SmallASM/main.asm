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
    ua_test DWORD 255 ;TODO Weg
    ua_enable_test DWORD 0  ;TODO Weg

.code
;https://learn.microsoft.com/en-us/windows/win32/inputdev/mouse-input-notifications
;https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-wndproc
;https://learn.microsoft.com/en-us/windows/win32/winmsg/about-messages-and-message-queues#system-defined-messages
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; WINDOW PROCEDURE;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
WndProc PROC hwnd:HWND, msg:UINT, wParam:WPARAM, lParam:LPARAM
    ;push ebp  
    ;mov  ebp,esp 



   ;TODO WEG
    cmp ua_enable_test, 0
   je ahhhh
     mov eax, ua_test
    mov ecx, ua_bitmapData
    mov edx, 400000
    lol:

    mov dword ptr [ecx], eax;0ff0000ffh
    add ecx, 4
    sub edx, 1
    add eax, 1 
    cmp edx, 0
    jne lol

    mov eax, ua_test
    add eax, 1
    mov ua_test, eax
    ahhhh:
    ;ENDE TODO


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
    ;;;;;;;;;; MouseStuff z.b. WM_LBUTTONDOWN
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


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
        mov dword ptr[OFFSET ua_bmi], 40 ;biSize=sizeof(BITMAPINFOHEADER)
        mov eax,[OFFSET ua_rect+8]
        mov dword ptr[OFFSET ua_bmi+4], eax ;biWidth=[OFFSET ua_rect+8]
        mov eax,[OFFSET ua_rect+12]
        neg eax
        mov dword ptr[OFFSET ua_bmi+8], eax ;biHeight=[OFFSET ua_rect+12]
        mov word ptr[OFFSET ua_bmi+12], 1 ;biPlanes=sizeof(BITMAPINFOHEADER)
        mov word ptr[OFFSET ua_bmi+14], 32 ;biBitCount=sizeof(BITMAPINFOHEADER)
        mov dword ptr[OFFSET ua_bmi+16], 0 ;biCompression=BI_RGB
        mov dword ptr[OFFSET ua_bmi+20], 0 ;biSizeImage=0 TODO WEG
        mov dword ptr[OFFSET ua_bmi+24], 0 ;biXPelsPerMeter=0 TODO WEG
        mov dword ptr[OFFSET ua_bmi+28], 0 ;biYPelsPerMeter=0 TODO WEG
        mov dword ptr[OFFSET ua_bmi+32], 0 ;biClrUsed=0 TODO WEG
        mov dword ptr[OFFSET ua_bmi+36], 0 ;biClrImportant=0 TODO WEG
        mov dword ptr[OFFSET ua_bmi+40], 0 ;RGBQUAD=0 TODO WEG

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


        mov ua_enable_test, 1 ;TODO weg
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



        ;old
        ;GetDC
        ;push dword ptr [ebp+8] ; hwnd
        ;call GetDC
        ;mov ua_hdc, eax
        

        ;GO THROUGH ALL PIXELS
        ;{
        ;push ebx    ;save
        ;push esi    ;save

        ;outer loop
        ;mov esi, 0  ;y
        ;wndProc_paint_loop1:
        ;{
            ;mov ebx, 0 ; x
            ;wndProc_paint_loop2:
            ;{
                ;SetPixel
                ;push 255
                ;push esi
                ;push ebx
                ;push ua_hdc
                ;call SetPixel

            ;}
            ;add ebx, 1 ; x++
            ;cmp ebx,[OFFSET ua_rect+8] ;ebx,widrh
            ;jne wndProc_paint_loop2
        ;}
        ;add esi, 1 ; y++
        ;cmp esi, [OFFSET ua_rect+12] ; esi,height
        ;jne wndProc_paint_loop1
        ;outer loop end

        ;pop esi     ;save
        ;pop ebx     ;save
        ;}

        ;https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-setpixel
        ;SetPixel
        ;push 255

        ;mov eax, [OFFSET ua_rect+12] ;height
        ;sub eax, 1
        ;push eax

        ;mov eax, [OFFSET ua_rect+8] ;width
        ;sub eax, 1
        ;push eax

        ;push ua_hdc
        ;call SetPixel
        
        ;SetPixel
        ;push 255
        ;push 0
        ;push 0 
        ;push ua_hdc
        ;call SetPixel

        ;ReleaseDC
        ;push ua_hdc
        ;push dword ptr [ebp+8] ; hwnd
        ;call ReleaseDC

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
;;;;; WinMain
;;;;;;;;;;;;;;;;;;;;;;;;
start:
WinMain PROC hInstance:HINSTANCE, hPrevInstance:HINSTANCE, lpCmdLine:LPSTR, nCmdShow:SDWORD
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Registering the Window Class
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov dword ptr[OFFSET ua_wc]    , 48 ;cbSize=12*4
    mov dword ptr[OFFSET ua_wc+4]  , 0  ;syle=0
    mov dword ptr[OFFSET ua_wc+8]  , OFFSET WndProc  ;lpfnWndProc=WndProc
    mov dword ptr[OFFSET ua_wc+12] , 0  ;cbClsExtra=0
    mov dword ptr[OFFSET ua_wc+16] , 0  ;cbWndExtra=0
    mov eax,  dword ptr[ebp+8]
    mov dword ptr[OFFSET ua_wc+20] , eax ;hInstance=hInstance
    ;RegisterClassEx
    push 7F00h
    push 0
    call LoadIcon
    mov dword ptr[OFFSET ua_wc+24] , eax  ;hIcon=LoadIcon(0,IDI_APPLICATION)
    mov dword ptr[OFFSET ua_wc+44] , eax  ;hIconSm=LoadIcon(0,IDI_APPLICATION)
    push 7F00h
    push 0
    invoke  LoadCursor, 0, IDC_ARROW
    mov dword ptr[OFFSET ua_wc+28] , eax  ;hCursor=LoadCursor(0,IDC_ARROW)
    mov dword ptr[OFFSET ua_wc+32] , 6  ;hbrBackground=COLOR_WINDOW+1
    mov dword ptr[OFFSET ua_wc+36] , 0  ;lpszMenuName=0
    mov dword ptr[OFFSET ua_wc+40] , OFFSET g_szClassName  ;lpszClassName=(string)g_szClassName

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

        ;https://stackoverflow.com/questions/3954895/wm-paint-not-being-called-after-window-is-created
        ;InvalidateRect / redraw
        push 0
        push OFFSET ua_rect
        push ua_hwnd
        call InvalidateRect
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