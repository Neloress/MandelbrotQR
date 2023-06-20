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

.data


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
    ;;;;;;;;;; Paint
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    cmp  dword ptr [ebp+12], 000Fh ; msg, WM_PAINT
    jne wndProc_casePaintEnd
    ;{
        ;GetDC
        push dword ptr [ebp+8] ; hwnd
        call GetDC
        mov ua_hdc, eax

        ;https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-setpixel
        ;SetPixel
        push 255

        mov eax, [OFFSET ua_rect+12] ;height
        sub eax, 1
        push eax

        mov eax, [OFFSET ua_rect+8] ;width
        sub eax, 1
        push eax

        push ua_hdc
        call SetPixel
        
        ;SetPixel
        push 255
        push 0
        push 0 
        push ua_hdc
        call SetPixel

        ;ReleaseDC
        push ua_hdc
        push dword ptr [ebp+8] ; hwnd
        call ReleaseDC

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

    ;GetClientRect
    push OFFSET ua_rect
    push ua_hwnd
    call GetClientRect

    ;ShowWindow
    push 1  ;SW_SHOWNORMAL
    push ua_hwnd
    call ShowWindow;

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