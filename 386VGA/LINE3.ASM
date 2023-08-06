   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386

   .DATA

   x0inc DW 1
   y0inc DW 1
   x1inc DW -1
   y1inc DW 1
   endxx DW 1

   .CODE

_set_palette PROC
   mov cx, 255
   mov dx, 03c8h
   mov al, 1
   out dx, al
   inc dx

next_colour:
   mov ax, cx
   shr ax, 2
   dec ax
   out dx, al

   xor al, al
   out dx, al

   mov al, 03fh
   out dx, al

   loop next_colour

   ret
_set_palette ENDP

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

   call _set_palette

   mov ax, @data
   mov ds, ax

   mov bp, 255  ; colour
   mov si, 0   ; x0, y0
   mov di, 128 
   mov cx, 147 ; x1, y1
   mov dx, 0
   
next_line:
   push cx
   push dx
   push si
   push di

   sub si, cx
   sub di, dx
   mov ax, si
   mov bx, di
   cmp ax, 0
   jle noneg_ax
   neg ax
noneg_ax:
   cmp bx, 0
   jle noneg_bx
   neg bx
noneg_bx:
   cmp ax, bx
   jle no_switch
   mov ax, bx
no_switch:

   push bp      ; colour
   push ax ; D = -dy 
   push di      ; dy
   push si      ; dx
   push dx      ; y0
   push cx      ; x0
   call _vga_line_bresenham
   add sp, 12

   pop di
   pop si
   pop dx
   pop cx

   cmp endxx, 2
   jae endxx2
   cmp endxx, 1
   je endxx1

   add cx, x0inc
   cmp cx, 320
   jl x0_ok
   neg x0inc
   add cx, x0inc
   add cx, x0inc
x0_ok:

   cmp cx, 0
   jge x0_ok2
   neg x0inc
   add cx, x0inc
   add cx, x0inc
x0_ok2:

   jmp end_done

endxx1:
   add dx, y0inc
   cmp dx, 200
   jl y0_ok
   neg y0inc
   add dx, y0inc
   add dx, y0inc
y0_ok:

   cmp dx, 0
   jge y0_ok2
   neg y0inc
   add cx, y0inc
   add cx, y0inc
y0_ok2:

   jmp end_done

endxx2:

   cmp endxx, 3
   je endxx3

   add si, x1inc
   cmp si, 320
   jl x1_ok
   neg x1inc
   add si, x1inc
   add si, x1inc
x1_ok:

   cmp si, 0
   jge x1_ok2
   neg x1inc
   add si, x1inc
   add si, x1inc
x1_ok2:

   jmp end_done

endxx3:
   add di, y1inc
   cmp di, 200
   jl y1_ok
   neg y1inc
   add di, y1inc
   add di, y1inc
y1_ok:

   cmp di, 0
   jge y1_ok2
   neg y1inc
   add di, y1inc
   add di, y1inc
y1_ok2:

end_done:

   inc endxx
   cmp endxx, 4
   jne endxx_next

   dec bp
   mov endxx, 0

endxx_next:
   jnz next_line

   mov bp, 255
   jmp next_line
   
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
