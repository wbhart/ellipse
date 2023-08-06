   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386
   .CODE

_vga_ellipse PROC
   ARG x0:WORD, y0:WORD, r:WORD, s:WORD, colour:BYTE
   
   ; edx = xdelta, ebx = ydelta, esi = D, cx = xdiff
   ; bp = ydiff, di = offset, al = colour

   push bp
   mov bp, sp
   push si
   push di

   ; set up VGA segment
   mov ax, 0a000h
   mov es, ax

   ; compute offset = y0*320 + x0 + r
   mov ax, y0
   mov di, ax
   shl di, 2
   add di, ax
   shl di, 6
   add di, x0
   mov cx, r
   add di, cx
   
   cmp cx, 0       ; check r = 0
   jz ellipse_vert

   ; load dx, dy, D
   xor eax, eax
   mov ax, s       ; c = s^2
   cmp ax, 0       ; check if s = 0
   jz ellipse_horiz
   mul al
   mov DWORD PTR cs:[ellipse_patch4+3], eax
   mov DWORD PTR cs:[ellipse_patch5+3], eax
   mov DWORD PTR cs:[ellipse_patch6+3], eax
   mov DWORD PTR cs:[ellipse_patch7+3], eax

   shl ax, 1       ; xdelta = 2*c*r
   mul cx
   shl edx, 16
   mov dx, ax
   mov ax, r       ; a = r^2
   mul al
   mov ebx, eax
   shl ax, 1       ; 2a
   mov DWORD PTR cs:[ellipse_patch1+3], eax 
   mov DWORD PTR cs:[ellipse_patch2+3], eax
   mov DWORD PTR cs:[ellipse_patch3+3], eax
   xor esi, esi  ; D = 0

   ; load colour
   mov al, colour

   ; xdiff = 2*r
   shl cx, 1

   ; ydiff = 0
   xor bp, bp

   cmp edx, ebx     ; while xdelta >= ydelta
   jl ellipse_diagonal

ellipse_loop1:
   ; draw four points symmetrically
   stosb
   dec di
   sub di, bp
   stosb
   dec di
   sub di, cx
   stosb
   dec di
   add di, bp
   stosb
   dec di
   add di, cx

   add esi, ebx  ; D += ydelta
ellipse_patch1:
   add ebx, 012345678h  ; ydelta += 2a
   add di, 320   ; y += 1
   add bp, 640

   ; if D >= xdelta/2
   sar edx, 1
   lahf

   cmp esi, edx
   jl ellipse_skipx

   sahf
   rcl edx, 1     ; restore edx
   
ellipse_patch4:   
   sub edx, 012345678h ; xdelta -= c
   sub esi, edx     ; D -= xdelta
ellipse_patch5:
   sub edx, 012345678h ; xdelta -= c

   dec di         ; x -= 1
   sub cx, 2

   cmp edx, ebx
   jge ellipse_loop1
   jmp ellipse_diagonal

ellipse_skipx:
   sahf            ; restore edx
   rcl edx, 1

   cmp edx, ebx
   jge ellipse_loop1

ellipse_diagonal:
   
   ; if D > ydelta/2
   sar ebx, 1
   lahf

   cmp esi, ebx
   jle ellipse_skip_diag

   sahf
   rcl ebx, 1     ; temporarily restore ydelta

ellipse_patch2:   
   sub ebx, 012345678h  ; ydelta -= 2a
   sub esi, ebx   ; D -= ydelta
   sub di, 320    ; y -= 1
   sub bp, 640

   sar ebx, 1
ellipse_skip_diag:
   sahf
   rcl ebx, 1     ; restore ydelta

   neg esi        ; D = -D

   ; while xdelta >= 0
   cmp edx, 0
   jl ellipse_end
   
ellipse_loop2:
   ; draw four points symmetrically
   stosb
   dec di
   sub di, bp
   stosb
   dec di
   sub di, cx
   stosb
   dec di
   add di, bp
   stosb
   dec di
   add di, cx

ellipse_patch6:
   sub edx, 012345678h  ; xdelta -= c
   add esi, edx   ; D += xdelta
ellipse_patch7:
   sub edx, 012345678h  ; xdelta -= c

   dec di         ; x -= 1
   sub cx, 2

   ; if D >= ydelta/2
   sar ebx, 1
   lahf
   cmp esi, ebx
   jl ellipse_skipy

   sahf
   rcl ebx, 1     ; restore ebx
   
   sub esi, ebx   ; D -= ydelta
ellipse_patch3:
   add ebx, 012345678h ; ydelta += 2a

   add di, 320    ; y += 1
   add bp, 640

   cmp edx, 0
   jge ellipse_loop2
   jmp ellipse_end

ellipse_skipy:
   sahf
   rcl ebx, 1
   cmp edx, 0
   jge ellipse_loop2

ellipse_end:

   pop di
   pop si
   pop bp
   ret

ellipse_vert:
   mov al, colour  ; load colour
   mov cx, s       ; load s
   mov bx, cx      ; adjust offset by 320*s
   shl bx, 2
   add bx, cx
   shl bx, 6
   sub di, bx
   shl cx, 1       ; compute iterations
   inc cx
ellipse_vert_loop:
   stosb
   add di, 319
   loop ellipse_vert_loop

   pop di
   pop si
   pop bp
   ret

ellipse_horiz:
   mov al, colour
   std
   shl cx, 1
   inc cx
   rep stosb
   cld

   pop di
   pop si
   pop bp
   ret
_vga_ellipse ENDP
   
start:
   ; set video mode = 13h (VGA 320x200x256)
   xor ah, ah
   mov al, 13h
   int 10h

   mov bp, 100  ; colour

next_colour:
   mov cx, 159 ; x radius

next_ellipse:
   push cx

   push bp      ; colour
   mov ax, bp   ; s
   dec ax
   push ax
   dec cx
   push cx      ; r
   inc cx
   mov ax, 100  ; y0
   push ax
   mov ax, 160  ; x0
   push ax
   call _vga_ellipse
   add sp, 10

   pop cx
   loop next_ellipse

   dec bp
   jnz next_colour

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
