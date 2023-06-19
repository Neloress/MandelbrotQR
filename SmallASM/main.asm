;https://stackoverflow.com/questions/71579808/masm-14-constant-expected-in-winextra-inc
;winextra.inc

.386
.model flat, stdcall
option casemap :none

include c:\masm32\include\Windows.inc
include c:\masm32\include\user32.inc

includelib c:\masm32\lib\user32.lib

    ;EXTERN MessageBoxA@16 :PROC ;4*DWORD=4*4 ;Proc hInstance:DWORD, hPrevInstance:DWORD, lpCmdLine:DWORD, nCmdShow:DWORD

.const
    g_szClassName DB "myWindowClass",0
    window_title DB "The title of my window",0
    error_message1 DB "Window Registration Failed!",0
    error_message2 DB "Window Creation Failed!",0

.code
;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; WINDOW PROCEDURE
;;;;;;;;;;;;;;;;;;;;;;;;
WndProc PROC hwnd:HWND, msg:UINT, wParam:WPARAM, lParam:LPARAM

    .if msg == WM_CLOSE
        invoke DestroyWindow, hwnd
    
    .elseif msg == WM_DESTROY
        invoke PostQuitMessage, 0

    .else
        invoke DefWindowProc, hwnd, msg, wParam, lParam 
        ret

    .endif

    xor eax,eax
    ret

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
    .if !eax

        invoke MessageBox, 0,OFFSET error_message1,0, MB_ICONEXCLAMATION
        mov eax, 1
        ret

    .endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;;;; Create Window
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    invoke CreateWindowEx, 
            WS_EX_CLIENTEDGE, 
            OFFSET g_szClassName, 
            OFFSET window_title, 
            WS_OVERLAPPEDWINDOW, 
            CW_USEDEFAULT, 
            CW_USEDEFAULT, 
            240, 
            120, 
            0,
            0, 
            hInstance,
            0
    mov hwnd, eax

    .if hwnd == 0
        invoke MessageBoxA, 0, OFFSET error_message2, 0, MB_ICONEXCLAMATION
        xor eax,eax
    .endif

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

        invoke TranslateMessage, ADDR Msg
        invoke DispatchMessage, ADDR Msg
    .endw

    mov eax, Msg.wParam
    ret

WinMain ENDP
END start