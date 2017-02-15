; tinycat by opossumi
; nasm -f bin cat.asm -o cat
BITS 32
org     0x08048000
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
    dec     esi
    push    ecx
    mov     bl,     4
    inc     eax
    push    eax
    jmp     _loop
    dw      0x34
    dw      0x20
    dw      1
    dw      0
    dw      0
    dw      0

_loop:
    mov     edi,    DWORD [esp + 4 * ebx]
    test    edi,    edi
    jz      _end
    inc     ebx
    push    ebx
    mov     ebx,    edi
    xor     ecx,    ecx
    lea     eax,    [ecx+5]
    int     0x80
    xchg    ecx,    eax
    xor     ebx,    ebx
    inc     ebx
    xor     eax,    eax
    mov     al,     187
    int     0x80
    pop     ebx
    jmp     _loop

_end:
    pop     eax
    pop     ebx
    int     0x80
