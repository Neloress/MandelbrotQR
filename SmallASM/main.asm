;https://stackoverflow.com/questions/71579808/masm-14-constant-expected-in-winextra-inc
;winextra.inc

.386
.model flat, stdcall
option casemap:none

include c:\masm32\include\Windows.inc
include c:\masm32\include\user32.inc

includelib c:\masm32\lib\user32.lib

.const
    message_caption DB "Note",0
    message_text DB "Goodbye",0

.code

start:
WinMain Proc hInstance:HINSTANCE, hPrevInstance:HINSTANCE,lpCmdLine:LPSTR,nCmdShow:DWORD

    ;invoke MessageBoxA, NULL, OFFSET message_text, OFFSET message_caption, MB_OK
    push MB_OK
    push OFFSET message_caption 
    push OFFSET message_text 
    push 0
    call MessageBoxA

    xor eax, eax
    ret

WinMain ENDP
END start