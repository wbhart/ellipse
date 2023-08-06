   DOSSEG            
   .MODEL SMALL
   .STACK 100h
   .386
   .CODE

elldiag_incy PROC
   add di, 320
   add bp, 640
patch_incy:
   sub cx, 01234h
   jnc elldiag_incyx_skip
   dec di
   sub bp, 2
elldiag_incyx_skip:
   ret
elldiag_incy ENDP

elldiag_decy PROC
   sub di, 320
   sub bp, 640
patch_decy:
   add cx, 01234h
   jnc elldiag_decyx_skip
   inc di
   add bp, 2
elldiag_decyx_skip:
   ret
elldiag_decy ENDP

elldiag_incx PROC
   inc di
   add bp, 2
   ror ecx, 16
patch_incx:
   add cx, 01234h
   lahf
   rol ecx, 16
   sahf
   jnc elldiag_incxy_skip
   call elldiag_incy
elldiag_incxy_skip:
   ret
elldiag_incx ENDP

elldiag_decx PROC
   dec di
   sub bp, 2
   ror ecx, 16
patch_decx:
   sub cx, 01234h
   lahf
   rol ecx, 16
   sahf
   jnc elldiag_decxy_skip
   call elldiag_decy
elldiag_decxy_skip:
   ret
elldiag_decx ENDP

_vga_diag_ellipse PROC
   ARG x0:WORD, y0:WORD, r:WORD, s:WORD, a:WORD, b:WORD, c:WORD, colour:BYTE
   
   ; edx = xdelta, ebx = ydelta, esi = D, ecx:lo = yfrac, ecx:hi = xfrac
   ; bp = diff, di = offset, al = colour

   push bp
   mov bp, sp
   push si
   push di

   ; set up VGA segment
   mov ax, 0a000h
   mov es, ax

   ; compute ab/c^2
   mov ax, c
   mul al
   mov cx, ax
   mov ax, a
   mov bx, b
   mul bl
   mov dx, ax
   xor ax, ax
   div cx

   mov word ptr cs:[patch_incx+2], ax
   mov word ptr cs:[patch_decx+2], ax

   ; compute b/a

   mov dx, bx
   xor ax, ax
   mov bx, a
   div bx

   mov word ptr cs:[patch_incy+2], ax
   mov word ptr cs:[patch_decy+2], ax

   ; compute rb/c + 0.5
   mov ax, b
   mov bx, r
   mul bl
   mov cx, c
   mov dx, c
   shr dx, 1
   add ax, dx
   xor dx, dx
   div cx
   push ax        ; save rb/c

   ; compute offset = y0*320 + rb/c*320 + x0 + ra/c
   add ax, y0
   mov di, ax
   shl di, 2
   add di, ax
   shl di, 6
   add di, x0

   shl edx, 16    ; store remainder
   
   ; compute ra/c + 0.5
   mov ax, a 
   mul bl
   mov dx, cx
   shr dx, 1
   add ax, dx
   xor dx, dx
   div cx
   push ax      ; push ra/c
   
   add di, ax

   ; compute xfrac
   xor ax, ax
   div cx
   mov si, ax
   shl esi, 16

   ; compute yfrac
   shr edx, 16
   xor ax, ax
   div cx
   mov si, ax

   ; compute adjusted r := rc/a
   mov cx, r
   mov dx, c
   mov ax, dx
   mul cl
   mov bx, a
   div bl
   mov cx, ax

   ; compute adjusted s := sc/a
   xor eax, eax
   mov ax, dx
   mov dx, s
   mul dl
   div bl

   ; load dx, dy, D
   mul al      ; c = s^2
   mov DWORD PTR cs:[elldiag_patch4+3], eax
   mov DWORD PTR cs:[elldiag_patch5+3], eax
   mov DWORD PTR cs:[elldiag_patch6+3], eax
   mov DWORD PTR cs:[elldiag_patch7+3], eax
   mov DWORD PTR cs:[elldiag_patch11+3], eax
   mov DWORD PTR cs:[elldiag_patch12+3], eax
   mov DWORD PTR cs:[elldiag_patch13+3], eax
   mov DWORD PTR cs:[elldiag_patch14+3], eax

   shl ax, 1       ; xdelta = 2*c*r
   mul cx
   shl edx, 16
   mov dx, ax
   mov ax, r       ; a = r^2
   mul al
   mov ebx, eax
   shl ax, 1       ; 2a
   mov DWORD PTR cs:[elldiag_patch1+3], eax 
   mov DWORD PTR cs:[elldiag_patch2+3], eax
   mov DWORD PTR cs:[elldiag_patch3+3], eax
   mov DWORD PTR cs:[elldiag_patch8+3], eax 
   mov DWORD PTR cs:[elldiag_patch9+3], eax
   mov DWORD PTR cs:[elldiag_patch10+3], eax

   ; diff = 2*320*rb/c + 2*ra/c
   pop cx
   pop ax
   shl ax, 6
   add cx, ax
   shl ax, 2
   add cx, ax
   shl cx, 1

   ; load colour
   mov al, colour
   
   ; load diff
   mov bp, cx

   xor ecx, ecx  ; D = 0
   xchg esi, ecx

   push ebx
   push ecx
   push edx
   push esi
   push di
   push bp

   cmp edx, ebx     ; while xdelta >= ydelta
   jl elldiag_diagonal

elldiag_loop1:
   ; draw two points symmetrically
   stosb
   dec di
   sub di, bp
   stosb
   dec di
   add di, bp

   add esi, ebx  ; D += ydelta
elldiag_patch1:
   add ebx, 012345678h  ; ydelta += 2a

   call elldiag_incy

   ; if D >= xdelta/2
   sar edx, 1
   lahf

   cmp esi, edx
   jl elldiag_skipx

   sahf
   rcl edx, 1     ; restore edx
   
elldiag_patch4:   
   sub edx, 012345678h ; xdelta -= c
   sub esi, edx     ; D -= xdelta
elldiag_patch5:
   sub edx, 012345678h ; xdelta -= c

   call elldiag_decx

   cmp edx, ebx
   jge elldiag_loop1
   jmp elldiag_diagonal

elldiag_skipx:
   sahf            ; restore edx
   rcl edx, 1

   cmp edx, ebx
   jge elldiag_loop1

elldiag_diagonal:
   
   ; if D > ydelta/2
   sar ebx, 1
   lahf

   cmp esi, ebx
   jle elldiag_skip_diag

   sahf
   rcl ebx, 1     ; temporarily restore ydelta

elldiag_patch2:   
   sub ebx, 012345678h  ; ydelta -= 2a
   sub esi, ebx   ; D -= ydelta

   call elldiag_decy

   sar ebx, 1
   lahf
elldiag_skip_diag:
   sahf
   rcl ebx, 1     ; restore ydelta

   neg esi        ; D = -D

   ; while xdelta >= 0
   cmp edx, 0
   jl elldiag_end
   
elldiag_loop2:
   ; draw two points symmetrically
   stosb
   dec di
   sub di, bp
   stosb
   dec di
   add di, bp

elldiag_patch6:
   sub edx, 012345678h  ; xdelta -= c
   add esi, edx   ; D += xdelta
elldiag_patch7:
   sub edx, 012345678h  ; xdelta -= c

   call elldiag_decx

   ; if D >= ydelta/2
   sar ebx, 1
   lahf
   cmp esi, ebx
   jl elldiag_skipy

   sahf
   rcl ebx, 1     ; restore ebx
   
   sub esi, ebx   ; D -= ydelta
elldiag_patch3:
   add ebx, 012345678h ; ydelta += 2a

   call elldiag_incy

   cmp edx, 0
   jge elldiag_loop2
   jmp elldiag_end

elldiag_skipy:
   sahf
   rcl ebx, 1
   cmp edx, 0
   jge elldiag_loop2

elldiag_end:

   pop bp
   pop di
   pop esi
   pop edx
   pop ecx
   pop ebx

   cmp edx, ebx     ; while xdelta >= ydelta
   jl elldiag_diagonal_2

elldiag_loop1_2:
   ; draw two points symmetrically
   stosb
   dec di
   sub di, bp
   stosb
   dec di
   add di, bp

   add esi, ebx  ; D += ydelta
elldiag_patch8:
   add ebx, 012345678h  ; ydelta += 2a

   call elldiag_decy

   ; if D >= xdelta/2
   sar edx, 1
   lahf

   cmp esi, edx
   jl elldiag_skipx_2

   sahf
   rcl edx, 1     ; restore edx
   
elldiag_patch11:   
   sub edx, 012345678h ; xdelta -= c
   sub esi, edx     ; D -= xdelta
elldiag_patch12:
   sub edx, 012345678h ; xdelta -= c

   call elldiag_decx

   cmp edx, ebx
   jge elldiag_loop1_2
   jmp elldiag_diagonal_2

elldiag_skipx_2:
   sahf            ; restore edx
   rcl edx, 1

   cmp edx, ebx
   jge elldiag_loop1_2

elldiag_diagonal_2:
   
   ; if D > ydelta/2
   sar ebx, 1
   lahf

   cmp esi, ebx
   jle elldiag_skip_diag_2

   sahf
   rcl ebx, 1     ; temporarily restore ydelta

elldiag_patch9:   
   sub ebx, 012345678h  ; ydelta -= 2a
   sub esi, ebx   ; D -= ydelta

   call elldiag_incy

   sar ebx, 1
   lahf
elldiag_skip_diag_2:
   sahf
   rcl ebx, 1     ; restore ydelta

   neg esi        ; D = -D

   ; while xdelta >= 0
   cmp edx, 0
   jl elldiag_end_2
   
elldiag_loop2_2:
   ; draw two points symmetrically
   stosb
   dec di
   sub di, bp
   stosb
   dec di
   add di, bp

elldiag_patch13:
   sub edx, 012345678h  ; xdelta -= c
   add esi, edx   ; D += xdelta
elldiag_patch14:
   sub edx, 012345678h  ; xdelta -= c

   call elldiag_decx

   ; if D >= ydelta/2
   sar ebx, 1
   lahf
   cmp esi, ebx
   jl elldiag_skipy_2

   sahf
   rcl ebx, 1     ; restore ebx
   
   sub esi, ebx   ; D -= ydelta
elldiag_patch10:
   add ebx, 012345678h ; ydelta += 2a

   call elldiag_decy

   cmp edx, 0
   jge elldiag_loop2_2
   jmp elldiag_end_2

elldiag_skipy_2:
   sahf
   rcl ebx, 1
   cmp edx, 0
   jge elldiag_loop2_2

elldiag_end_2:

   pop di
   pop si
   pop bp
   ret
_vga_diag_ellipse ENDP
   
start:
   ; set video mode = 13h (VGA 320x200x256)
   xor ah, ah
   mov al, 13h
   int 10h

   mov cx, 10000
big_ellipse_loop:

   push cx

   mov ax, 5    ; colour
   push ax
   mov ax, 5
   push ax
   mov ax, 3
   push ax
   mov ax, 4
   push ax
   mov ax, 20   ; s
   push ax
   mov ax, 60
   push ax      ; r
   mov ax, 100  ; y0
   push ax
   mov ax, 160  ; x0
   push ax
   call _vga_diag_ellipse
   add sp, 16

   pop cx
   loop big_ellipse_loop

   ; wait for keypress
   xor ah, ah
   int 16h
   
   ; restore video mode
   xor ah, ah
   mov al, 3
   int 10h

   mov  ah, 4ch ; terminate program
   int  21h
   END start
