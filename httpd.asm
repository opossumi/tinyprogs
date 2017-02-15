; Tiny http web server for 32-bit linux
; (c) opossumi, 2016

; nasm -f bin httpd.asm -o httpd

; Thanks to breadbox for ELF header magic
; http://www.muppetlabs.com/~breadbox/software/tiny/teensy.html

; 79 bytes
;%define SEND_404

; Prevents things like:
; curl http://127.0.0.1:8000//etc/passwd
; 10 bytes
;%define SECURE

; Really useful when restarting this program is needed often
; Prevents bind() from returning EADDRINUSE (Address already in use)
; 15 bytes
;%define REUSEPORT

BITS 64
		org	0x100000000

		db	0x7F, "ELF"
		db	2, 1, 1, 1
_start:	inc		rsi		; 1 = SOCK_STREAM
		mov		dil,	2		; 2 = PF_INET
		jmp	_realstart
		dw	2
		dw	62			; e_machine
		dd	1			; e_version
		dd	_start - $$		; e_entry
phdr:		dd	1					; p_type
		dd	phdr - $$		; e_phoff	; p_flags
		dd	0					; p_offset
		dd	0			; e_shoff
		dq	$$					; p_vaddr
						; e_flags
		dw	0x40			; e_ehsize	; p_paddr
		dw	0x38			; e_phentsize
		dw	1			; e_phnum
		dw	0			; e_shentsize
		dq	filesize		; e_shnum	; p_filesz
						; e_shstrndx
		dq	filesize		; p_memsz
		dq	0x00200000				; p_align

_realstart:
	;xor		r9,		r9
	; socket()
	;xor		rdx,	rdx		; 0 = protocol (already set to 0 in elf header)
	;lea		rdi,	[r9+2]	; 2 = PF_INET
	mov		al,		41		; sys_socket
	syscall
	;mov	r15,	rax		; socket fd
	xchg	rdi,	rax

%ifdef REUSEPORT
	; setsockopt()
	mov			r8b,	4	; 4 = optlen
	;;sub		rsp,	r8
	;;mov		[rsp],	rsi		; set optval to 1 (rsi set to 1 in call to socket())
	push	rsi				; set optval to 1
	mov		r10,	rsp		; optval
	mov		dl,		15		; SO_REUSEPORT
	;;mov	rsi,	1		; SOL_SOCKET (is already 1 from call to socket())
	;;mov	rdi,	r15		; socket fd	(rdi is socket fd from call to socket())
	lea		rax,	[r9+54]	; sys_setsockopt
	syscall
%endif

	; bind()
%ifdef REUSEPORT
	inc		dl				; 16 = addrlen (alt form)
%else
	mov		dl,		0x10
%endif
	; This pushes too much, but it's fine
	;xor		rax,	rax
	push	r9				; 0.0.0.0
	push	word 0x401f		; port (8000)
	push	word 2			; AF_INET
	mov		rsi,	rsp		; addr
	;mov	rdi,	r15		; socket fd	(rdi is socket fd from call to socket())
	mov		al,		49		; sys_bind (relies on socket()/setsockopt() return value)
	syscall

;_listen:
	; listen()
	lea		rsi,	[r9+1]	; backlog
	;mov	rdi,	r15		; socket fd (rdi is socket fd from call to socket())
	mov		al,		50		; sys_listen (relies on bind() returning 0)
	syscall

_accept:
	; accept()
	xor		rdx,	rdx		; address len
	xor		rsi,	rsi		; address ptr (no need for it)
	;mov	rdi,	r15		; socket fd (rdi is socket fd from call to socket())
	;lea		rax,	[r9+43]	; sys_accept
	mov		al,		43		; sys_accept
	syscall
	xchg	r14,	rax		; store client socket fd in r14

	; fork()
	mov		al,		57		; sys_fork (relies on upper bits of old r14 being zero)
	syscall
	test	rax,	rax
	;cmp		rax,	rax
	jz		_write			; jump to _write in child process

	; close() client socket fd
	xchg	rdi,	r14		; client socket fd <-> server socket fd
	lea		rax,	[r9+3]	; sys_close
	syscall
	; Move original rdi value back from r14
	xchg	rdi,	r14		; Move original rdi value back from r14
	jmp		_accept		; jump in parent process back to listen

_write:
	; Read request
	;xor		r9,		r9		; srclen ptr
	;xor		r8,		r8		; src_addr ptr
	xor		r10,	r10		; flags
	mov		dx,		1024	; buflen
	sub		rsp,	rdx		; request data
	mov		rsi,	rsp		; buf ptr
	mov		rdi,	r14		; client socket
	mov		al,		45		; sys_recvfrom (was initially zero from call to fork())
	syscall

	xor		rbx,	rbx
	mov		ecx,	eax
	add		rsi,	4	; Skip "GET " and hope the client did not use any other method
_loop:
	; foo
	lea		rax,	[rsi+rbx]
	;mov		rcx,	[rax+1]
	mov		al,		[rax]
	; stop at the first ' ' after filename
	cmp		al,		0x20	; cmp with ' '
	jz		_endloop

%ifdef SECURE
	; cmp i:th character
	cmp		al,		0x2e	; cmp with '.'
	jnz		_skipcmp2

	; cmp i+1:th character
	cmp		BYTE [rax+1], 0x2e	; cmp with '.'
	jz		_404
%endif

_skipcmp2:
	inc		rbx
	loop	_loop
_endloop:
	dec		rbx
	inc		rsi

	mov		byte [rsi+rbx], 0x0	; NULL terminate filename
	xchg	r12,	rsi		; store filename in r12

	; Get file size
	sub		rsp,	144		; reserve space for stat struct
	mov		rsi,	rsp
	mov		rdi,	r12		; filename
	lea		rax,	[r9+4]	; sys_stat
	syscall
	;mov	r12,	[rsp+48]
	cmp		al,	0
	jl		_404

	; Send headers
	mov		dx,		msgsize	; buflen (rdx was set to 1024 previously)
	mov		rsi,	msg		; buf
	mov		rdi,	r14		; client socket fd
	;lea		rax,	[r9+1]	; sys_write
	inc		rax
	syscall

	; Open file
	xor		rdx,	rdx		; mode
	xor		rsi,	rsi		; flags
	mov		rdi,	r12		; filename
	lea		rax,	[r9+2]	; sys_open
	syscall

	; Send file
	mov		r10,	[rsp+48]; count
	;xor		rdx,	rdx		; offset (was already 0 from previous syscall
	xchg	rsi,	rax		; file fd (return value from open())
	mov		rdi,	r14		; client socket fd
	lea		rax,	[r9+40]
	syscall

	jmp		_close

_404:
	; Send 404
%ifdef SEND_404
	mov		rdx,	msg404size	; buflen
	mov		rsi,	msg404	; buf
	mov		rdi,	r14		; client socket fd
	lea		rax,	[r9+1]	; sys_write
	syscall
%endif

_close:
	;mov	rdi,	r14		; client socket fd
	;lea		rax,	[r9+3]	; sys_close
	;syscall

_exit:
	;xor		rdi,	rdi		; exit code (we don't really care about it)
	mov		al,		60		; sys_exit
	syscall

msg:	db "HTTP/1.1 200", 0xa, "Content-Type: text/html", 0xd, 0xa, 0xd, 0xa
msgsize equ	$ - msg
%ifdef SEND_404
msg404	db "HTTP/1.1 404 Not Found", 0xa, "Content-Type: text/html", 0xd, 0xa, 0xd, 0xa, "404", 0xd, 0xa
msg404size equ	$ - msg404
%endif

filesize equ	$ - $$
