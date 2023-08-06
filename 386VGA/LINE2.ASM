   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386
   .CODE

_vga_line_bresenham PROC
   ARG x0:WORD, y0:WORD, deltax:WORD, deltay:WORD, D:WORD, colour:BYTE
   ; expects D = -max{|dx|, |dy|}
   
   ; ax = accum, dx = 2dx, bx = 2dy, si = D, cx = iters
   ; di = offset, al = colour

   push bp
   mov bp, sp
   push si
   push di

   ; set up VGA segment
   mov ax, 0a000h
   mov es, ax

   ; compute offset = y0*320 + x0
   mov ax, y0
   mov di, ax
   shl di, 2
   add di, ax
   shl di, 6
   add di, x0

   ; load dx, dy, D and iterations
   mov dx, deltax
   mov bx, deltay
   mov si, D

   ; load colour
   mov al, colour

   ; bytes per line
   mov bp, 320

   cmp bx, 0
   jge line_down

   neg bp
   neg bx

line_down:
   
   cmp dx, 0
   jl line_vl
   
line_vr:

   cmp dx, bx
   jae line_hr

   mov cx, bx
   shl dx, 1
   shl bx, 1

   ; iterations
   inc cx

   dec bp

line_loop_vr:
   stosb           ; write pixel
   add di, bp      ; inc/dec y

   add si, dx      ; D += 2dx
   jle line_skipx_vr ; if D > 0

   inc di          ; inc x
   sub si, bx      ; D -= 2dy

line_skipx_vr:

   loop line_loop_vr
   jmp line_end

line_vl:
   neg dx

   cmp dx, bx
   jae line_hl
   
   mov cx, bx
   shl dx, 1
   shl bx, 1

   ; iterations
   inc cx

   dec bp

line_loop_vl:
   stosb           ; write pixel
   add di, bp      ; inc/dec y

   add si, dx      ; D += 2dx
   jle line_skipx_vl ; if D > 0

   dec di          ; dec x
   sub si, bx      ; D -= 2dy

line_skipx_vl:

   loop line_loop_vl
   jmp line_end
   
line_hl:

   std

line_hr:

   mov cx, dx
   shl dx, 1
   shl bx, 1

   ; iterations
   inc cx

line_loop_h:
   stosb           ; write pixel, inc/dec x

   add si, bx      ; D += 2dy
   jle line_skipy_h ; if D > 0

   add di, bp      ; inc/dec y
   sub si, dx      ; D -= 2dx

line_skipy_h:

   loop line_loop_h
   cld

line_end:   
   pop di
   pop si
   pop bp
   ret
_vga_line_bresenham ENDP
   
start:
   ; set video mode = 13h (VGA 320x200x256)
   xor ah, ah
   mov al, 13h
   int 10h

   mov bp, 25  ; colour

next_colour8:
   mov cx, 199 ; x coord of end of first line

next_line8:
   push cx
   
   push bp      ; colour
   mov ax, -199 ; D = -dy 
   push ax
   neg ax
   push ax      ; dy
   push cx      ; dx
   xor ax, ax   ; y0
   push ax
   push ax      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop cx
   dec cx 
   jge next_line8

   dec bp
   jnz next_colour8

   mov bp, 25  ; colour

next_colour7:
   mov cx, 199 ; x coord of end of first line

next_line7:
   push cx
   
   push bp      ; colour
   mov ax, -199 ; D = -dy 
   push ax
   neg ax
   push ax      ; dy
   mov bx, cx
   sub bx, 199
   push bx      ; dx
   xor ax, ax   ; y0
   push ax
   mov ax, 199
   push ax      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop cx
   dec cx 
   jge next_line7

   dec bp
   jnz next_colour7

   mov bp, 25  ; colour

next_colour6:
   mov cx, 199 ; x coord of end of first line

next_line6:
   push cx
   
   push bp      ; colour
   mov ax, -199  ; D = -dy 
   push ax
   push ax      ; dy
   push cx      ; dx
   mov ax, 199  ; y0
   push ax
   xor ax, ax
   push ax      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop cx
   dec cx 
   jge next_line6

   dec bp
   jnz next_colour6

   mov bp, 25  ; colour

next_colour5:
   mov cx, 199 ; x coord of end of first line

next_line5:
   push cx
   
   push bp      ; colour
   mov ax, -199  ; D = -dy 
   push ax
   mov bx, cx
   sub bx, 199
   push ax      ; dy
   push bx      ; dx
   mov ax, 199  ; y0
   push ax
   push ax      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop cx
   dec cx 
   jge next_line5

   dec bp
   jnz next_colour5

   mov bp, 25  ; colour

next_colour4:
   mov cx, 199 ; y coord of end of first line

next_line4:
   push cx
   
   push bp      ; colour
   mov ax, -319  ; D = -dx 
   push ax
   mov bx, cx
   sub bx, 199
   push bx      ; dy
   push ax      ; dx
   mov ax, 199  ; y0
   push ax
   mov ax, 319
   push ax      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop cx
   dec cx 
   jge next_line4

   dec bp
   jnz next_colour4

   mov bp, 25  ; colour

next_colour3:
   mov cx, 199 ; y coord of end of first line

next_line3:
   push cx
   
   push bp      ; colour
   mov ax, -319 ; D = -dx 
   push ax
   mov bx, cx
   sub bx, 199
   push bx      ; dy
   neg ax       ; dx
   push ax
   mov ax, 199
   push ax      ; y0
   xor ax, ax
   push ax      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop cx
   dec cx 
   jge next_line3

   dec bp
   jnz next_colour3

   mov bp, 25  ; colour

next_colour2:
   mov cx, 199 ; y coord of end of first line

next_line2:
   push cx
   
   push bp      ; colour
   mov ax, -319 ; D = -dx 
   push ax
   push cx      ; dy
   push ax      ; dx
   xor ax, ax   ; y0
   push ax
   mov ax, 319
   push ax      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop cx
   dec cx 
   jge next_line2

   dec bp
   jnz next_colour2

   mov bp, 25  ; colour

next_colour1:
   mov cx, 199 ; y coord of end of first line

next_line1:
   push cx
   
   push bp      ; colour
   mov ax, -319 ; D = -dx 
   push ax
   push cx      ; dy
   neg ax       ; dx
   push ax
   xor ax, ax
   push ax      ; y0
   push ax      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop cx
   dec cx 
   jge next_line1

   dec bp
   jnz next_colour1
   
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
