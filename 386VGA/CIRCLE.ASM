   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386

   .DATA

   xoff DW -1
   yoff DW -1

   .CODE

_set_palette PROC
   mov cx, 255
   mov dx, 03c8h
   mov al, 1
   out dx, al
   inc dx

pal_next_colour:
   mov ax, cx
   shr ax, 2
   dec ax
   out dx, al

   xor al, al
   out dx, al

   mov ax, cx
   shr ax, 2
   dec ax
   out dx, al

   loop pal_next_colour

   ret
_set_palette ENDP

_vga_circle PROC
   ARG x0:WORD, y0:WORD, radius:WORD, colour:BYTE
   
   ; dx = xdelta, bx = ydelta, si = D, cx = xdiff
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
   mov cx, radius
   add di, cx

   ; load dx, dy, D
   mov al, 50
   mul cl
   xor edx, edx    ; clear high bits for rotations
   xor ebx, ebx
   mov dx, ax
   mov bx, 36
   xor si, si

   ; load colour
   mov al, colour

   ; xdiff = 2*radius
   shl cx, 1

   ; ydiff = 0
   xor bp, bp

   cmp dx, bx     ; while xdelta >= ydelta
   jl circle_diagonal

circle_loop1:
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

   add si, bx    ; D += ydelta
   add bx, 72    ; ydelta += 2a
   add di, 320   ; y += 1
   add bp, 640

   ; if D >= xdelta/2
   ror edx, 1
   cmp si, dx
   jl circle_skipx

   rol edx, 1     ; restore edx
   
   sub dx, 25     ; xdelta -= c
   sub si, dx     ; D -= xdelta
   sub dx, 25     ; xdelta -= c

   dec di         ; x -= 1
   sub cx, 2

   cmp dx, bx
   jge circle_loop1
   jmp circle_diagonal

circle_skipx:
   rol edx, 1
   cmp dx, bx
   jge circle_loop1

circle_diagonal:
   
   ; if D > ydelta/2
   ror ebx, 1
   cmp si, bx
   jge circle_skip_diag

   rol ebx, 1     ; temporarily restore ydelta

   sub bx, 72     ; ydelta -= 2a
   sub si, bx     ; D -= ydelta
   sub di, 320    ; y -= 1
   sub bp, 640

   ror ebx, 1
circle_skip_diag:
   rol ebx, 1     ; restore ydelta

   neg si         ; D = -D

   ; while xdelta >= 0
   cmp dx, 0
   jl circle_end
   
circle_loop2:
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

   sub dx, 25     ; xdelta -= c
   add si, dx     ; D += xdelta
   sub dx, 25     ; xdelta -= c

   dec di         ; x -= 1
   sub cx, 2

   ; if D >= ydelta/2
   ror ebx, 1
   cmp si, bx
   jl circle_skipy

   rol ebx, 1     ; restore ebx
   
   sub si, bx     ; D -= ydelta
   add bx, 72     ; ydelta += 2a

   add di, 320    ; y += 1
   add bp, 640

   cmp dx, 0
   jge circle_loop2
   jmp circle_end

circle_skipy:
   rol ebx, 1
   cmp dx, 0
   jge circle_loop2

circle_end:

   pop di
   pop si
   pop bp
   ret
_vga_circle ENDP
   
start:
   ; set video mode = 13h (VGA 320x200x256)
   xor ah, ah
   mov al, 13h
   int 10h

   mov ax, @data
   mov ds, ax

   call _set_palette

   mov bp, 240  ; colour
   mov dx, 200

next_colour:
   push dx
   mov cx, 118 ; x radius

next_circle:
   push cx

   push bp      ; colour
   push cx      ; radius
   mov ax, 100  ; y0
   add ax, yoff
   push ax
   mov ax, 160  ; x0
   add ax, xoff
   push ax
   call _vga_circle
   add sp, 8

   inc xoff
   cmp xoff, 2
   jl xoff_ok
   mov xoff, -1
   inc yoff
   cmp yoff, 2
   jl yoff_ok
   mov xoff, -1
   mov yoff, -1
   dec bp
   cmp bp, 0
   jge colour_ok
   mov bp, 240
colour_ok:
   pop cx
   loop next_circle
yoff_ok:
xoff_ok:

   pop cx
   cmp cx, 0
   ja next_circle

   pop dx
   dec dx
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
