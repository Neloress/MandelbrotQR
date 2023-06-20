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

        mov eax, [offset ua_rect+12] ;height
        sub eax, 1
        push eax

        mov eax, [offset ua_rect+8] ;width
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

    LOCAL wc:WNDCLASSEX
    LOCAL hwnd:HWND
    LOCAL Msg:MSG

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Registering the Window Class
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    mov wc.cbSize, sizeof WNDCLASSEX

    mov wc.style, 0

    mov wc.lpfnWndProc, OFFSET WndProc

    mov wc.cbClsExtra, 0

    mov wc.cbWndExtra, 0

    push hInstance
    pop wc.hInstance

    invoke LoadIcon, 0, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax

    invoke  LoadCursor, 0, IDC_ARROW
    mov wc.hCursor, eax

    mov wc.hbrBackground, COLOR_WINDOW+1

    mov wc.lpszMenuName, 0

    mov wc.lpszClassName, OFFSET g_szClassName


    invoke RegisterClassEx, ADDR wc

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Create Window
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    invoke CreateWindowEx, 
            WS_EX_CLIENTEDGE, 
            OFFSET g_szClassName, 
            OFFSET c_window_title, 
            000A0000h, ;WS_OVERLAPPEDWINDOW 0CF0000h
            CW_USEDEFAULT, 
            CW_USEDEFAULT, 
            c_Width, 
            c_Height, 
            0,
            0, 
            hInstance,
            0
    mov hwnd, eax

    invoke GetClientRect, hwnd, offset ua_rect;GetWindowRect

    invoke ShowWindow, hwnd, SW_SHOWNORMAL ;nCmdShow
    invoke UpdateWindow, hwnd 

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;;; The Message Loop
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    .while TRUE
        invoke GetMessage, ADDR Msg, 0, 0, 0
        .if !eax
            .break
        .endif

        invoke TranslateMessage, ADDR Msg ;eventeull raus TODO
        invoke DispatchMessage, ADDR Msg
    .endw

    mov eax, Msg.wParam
    ret

WinMain ENDP
END start