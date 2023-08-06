   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386
   .CODE

_vga_rot PROC
   ARG x0:WORD, y0:WORD, r:WORD, s:WORD, a:WORD, b:WORD, c:WORD

   push bp
   mov bp, sp
   push si
   push di

   ; set up VGA segment
   mov ax, 0a000h
   mov es, ax
   mov ds, ax

   ; compute bx = ab/c^2
   mov ax, c
   mul al
   mov cx, ax
   mov ax, a
   mov bx, b
   mul bl
   mov dx, ax
   xor ax, ax
   div cx

   mov word ptr cs:[rot_patch1+2], ax
   mov word ptr cs:[rot_patch2+2], ax

   ; set initial shift = 0.5
   mov bx, 08000h

   ; compute offset = (y0 + s)*320 + x0
   mov ax, y0
   add ax, s
   mov si, ax
   shl si, 2
   add si, ax
   shl si, 6
   add si, x0
   mov di, si

   ; compute inner iterations
   mov cx, s
   shl cx, 1
   inc cx

   ; compute outer iterations
   mov dx, r
   inc dx   

rot_loop1:
   push si
   push di
   push cx

rot_inner1:
   lodsb
   dec si
   mov byte ptr [si], 0
   stosb
   
   sub di, 321
   sub si, 320
   loop rot_inner1

   pop cx
   pop di
   pop si
   
rot_patch1:
   add bx, 01234h
   jnc rot_skip_inc1

   add di, 320
rot_skip_inc1:

   inc si
   inc di

   dec dx
   jnz rot_loop1

   ; set initial shift
   mov bx, 08000h

   ; compute offset = (y0 - s)*320 + x0
   mov ax, y0
   sub ax, s
   mov si, ax
   shl si, 2
   add si, ax
   shl si, 6
   add si, x0
   mov di, si

   ; compute inner iterations
   mov cx, s
   shl cx, 1
   inc cx

   ; compute outer iterations
   mov dx, r
   inc dx   

rot_loop2:
   push si
   push di
   push cx

rot_inner2:
   lodsb
   dec si
   mov byte ptr [si], 0
   stosb
   
   add di, 319
   add si, 320
   loop rot_inner2

   pop cx
   pop di
   pop si
   
rot_patch2:
   sub bx, 01234h
   jnc rot_skip_dec2

   sub di, 320
rot_skip_dec2:

   dec si
   dec di

   dec dx
   jnz rot_loop2

   pop di
   pop si
   pop bp
   ret
_vga_rot ENDP

_vga_rot2 PROC
   ARG x0:WORD, y0:WORD, r:WORD, s:WORD, a:WORD, b:WORD, c:WORD

   push bp
   mov bp, sp
   push si
   push di

   ; set up VGA segment
   mov ax, 0a000h
   mov es, ax
   mov ds, ax

   ; compute b/a
   mov dx, b
   xor ax, ax
   mov cx, a
   div cx

   mov word ptr cs:[rot_patch4+2], ax
   mov word ptr cs:[rot_patch5+2], ax

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

   ; compute shifted s

   mov bx, r
   mul bx
   add ax, 08000h
   adc dx, 0
   add dx, s

   push dx

   ; set initial shift = 0.5
   mov bx, 08000h

   ; compute offset = y0*320 + x0 - r
   mov ax, y0
   mov si, ax
   shl si, 2
   add si, ax
   shl si, 6
   add si, x0
   sub si, r
   mov di, si
  
   ; compute inner iterations
   mov cx, r
   shl cx, 1
   inc cx

   ; compute outer iterations
   inc dx   

rot_loop3:
   push si
   push di
   push cx

rot_inner3:
   lodsb
   dec si
   mov byte ptr [si], 0
   inc si
   stosb
   
   loop rot_inner3

   pop cx
   pop di
   pop si
   
rot_patch4:
   sub bx, 01234h
   jnc rot_skip_dec3

   dec di
rot_skip_dec3:

   add si, 320
   add di, 320

   dec dx
   jnz rot_loop3
   
   ; restore shifted s
   pop dx

   ; set initial shift = 0.5
   mov bx, 08000h

   ; compute offset = y0*320 + x0 + r
   mov ax, y0
   mov si, ax
   shl si, 2
   add si, ax
   shl si, 6
   add si, x0
   add si, r
   mov di, si
  
   ; compute inner iterations
   mov cx, r
   shl cx, 1
   inc cx

   ; compute outer iterations
   inc dx   

rot_loop4:
   push si
   push di
   push cx

rot_inner4:
   lodsb
   dec si
   mov byte ptr [si], 0
   dec si
   stosb
   sub di, 2
   
   loop rot_inner4

   pop cx
   pop di
   pop si
   
rot_patch5:
   add bx, 01234h
   jnc rot_skip_inc4

   inc di
rot_skip_inc4:

   sub si, 320
   sub di, 320

   dec dx
   jnz rot_loop4

   pop di
   pop si
   pop bp
   ret
_vga_rot2 ENDP

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

   mov ax, 100  ; colour

   push ax      ; colour
   mov ax, 25   ; s
   push ax
   mov ax, 75
   push ax      ; r
   inc cx
   mov ax, 100  ; y0
   push ax
   mov ax, 160  ; x0
   push ax
   call _vga_ellipse
   add sp, 10

   ; wait for keypress
   xor ah, ah
   int 16h

   ; shift in y-direction
   mov ax, 5
   push ax      ; c
   mov ax, 3
   push ax      ; b
   mov ax, 4
   push ax      ; a
   mov ax, 25
   push ax      ; s
   mov ax, 75
   push ax      ; r
   mov ax, 100
   push ax      ; y0
   mov ax, 160
   push ax      ; x0
   call _vga_rot
   add sp, 14

   ; wait for keypress
   xor ah, ah
   int 16h

   ; shift in x-direction
   mov ax, 5
   push ax      ; c
   mov ax, 3
   push ax      ; b
   mov ax, 4
   push ax      ; a
   mov ax, 25
   push ax      ; s
   mov ax, 75
   push ax      ; r
   mov ax, 100
   push ax      ; y0
   mov ax, 160
   push ax      ; x0
   call _vga_rot2
   add sp, 14

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
