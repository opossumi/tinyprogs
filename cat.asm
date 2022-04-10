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
    inc     eax
    push    eax
    jmp _loop
    dw      0x34
    dw      0x20
    dw      1

_loop:
    lodsd
    test    eax,    eax
    jz      _end
    xor     ecx,    ecx
    xchg    ebx,    eax
    mov     al, 5
    push    eax
_end:
    pop     eax
    int     0x80

    xchg    ecx,    eax
    xor     ebx,    ebx
    inc     ebx
    mov     al,     187
    int     0x80

    jmp _loop
