; tinycat by opossumi
; nasm -f bin cat.asm -o cat
BITS 32
org     0x10000
    db  0x7F, "ELF"
    dd  1
    dd  0
    dd  $$
    dw  2
    dw  3
    dd  _start
    dd  _start
    dd  4
_start:
    pop     edi
    pop     edi
    mov     esi,    esp
_loop2:
    lodsd
    xchg    ecx,    eax
    jmp _loop
    dw      0x34
    dw      0x20
    dw      1

_loop:
    jecxz   _end
    xchg    ebx,    ecx
    mov     al, 5
    int     0x80

    xchg    ecx,    eax
    xor     ebx,    ebx
    inc     ebx
    mov     al,     186
_end:
    inc     eax
    int     0x80
    dec     ebx
    xor     ecx,    ecx

    jmp _loop2
