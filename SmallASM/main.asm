;https://stackoverflow.com/questions/71579808/masm-14-constant-expected-in-winextra-inc
;winextra.inc

.386
.model flat, stdcall
option casemap:none

;include c:\masm32\include\Windows.inc
;include c:\masm32\include\user32.inc

includelib c:\masm32\lib\user32.lib

    EXTERN MessageBoxA@16 :PROC ;4*DWORD=4*4 ;Proc hInstance:DWORD, hPrevInstance:DWORD, lpCmdLine:DWORD, nCmdShow:DWORD

.const
    message_caption DB "Note",0
    message_text DB "Goodbye",0

.code

WinMain: 
    push ebp
    mov ebp, esp

    push 0 ;MB_OK
    push OFFSET message_caption 
    push OFFSET message_text 
    push 0
    call MessageBoxA@16



    xor eax, eax
    pop ebp
    ret

END WinMain