   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386
   .DATA

   ANGLES DD 51472, 30386, 16055, 8150, 4091, 2047, 1024, 512
          DD 256, 128, 64, 32, 16, 8, 4, 2, 1

   .CODE

   PUBLIC _vga_draw_pixel
_vga_draw_pixel PROC
   ARG x0:WORD, Y0:WORD, colour:BYTE
   push bp
   mov bp, sp
   push di

   mov ax, 0a000h
   mov es, ax

   mov di, y0
   mov ax, y0
   shl ax, 2
   add di, ax
   shl di, 6
   add di, x0

   mov al, colour
   stosb
   
   pop di
   pop bp
   ret
_vga_draw_pixel ENDP

   PUBLIC _set_palette
_set_palette PROC
   mov cx, 63
   mov dx, 03c8h
   mov al, 1
   out dx, al
   inc dx

next_colour1:
   mov al, 03fh
   out dx, al

   mov ax, 63
   sub ax, cx
   out dx, al

   xor al, al
   out dx, al

   loop next_colour1

   out dx, al
   out dx, al
   out dx, al

   mov cx, 63

next_colour2:
   mov ax, 63
   sub ax, cx
   out dx, al

   mov al, 03fh
   out dx, al

   xor al, al
   out dx, al

   loop next_colour2

   out dx, al
   out dx, al
   out dx, al

   mov cx, 63

next_colour3:
   mov ax, 63
   sub ax, cx
   out dx, al

   mov al, 03fh
   out dx, al

   mov ax, cx
   out dx, al

   loop next_colour3

   out dx, al
   out dx, al
   out dx, al

   mov cx, 63

next_colour4:
   mov al, 03fh
   out dx, al

   mov ax, 63
   sub ax, cx
   out dx, al

   mov ax, cx
   out dx, al

   loop next_colour4

   ret
_set_palette ENDP

_cordic PROC
   ; returns cos(beta), sin(beta) in esi, edi
   ; given -pi/2 < beta < pi/2 in edx in 16.16 fixed point

   mov cx, 1000h ; iters = 16, power of 2 = 0
   mov bx, offset ANGLES - 4
   mov esi, 10000h ; R[0] = 1
   xor edi, edi    ; R[1] = 0

   push edx

   cmp edx, 0
   je cordic_zero
   jge cordic_pos
   neg edx

cordic_pos:

   ; esi, edi = esi - 2^-i * edi, 2^-i * esi + edi
   mov eax, esi
   sar eax, cl
   add eax, edi
   sar edi, cl
   sub esi, edi
   mov edi, eax
   
   inc cl    ; update power of 2
   dec ch    ; check iterations
   jl cordic_end

   ; beta -= angle
   add bx, 4
   sub edx, [bx]
   jge cordic_pos

cordic_neg:

   ; esi, edi = esi + 2^-i * edi, -2^-i * esi + edi
   mov eax, edi
   sar eax, cl
   add eax, esi
   sar esi, cl
   sub edi, esi
   mov esi, eax
   
   inc cl    ; update power of 2
   dec ch    ; check iterations
   jl cordic_end

   ; beta += angle
   add bx, 4
   add edx, [bx]
   cmp edx, 0
   jge cordic_pos
   jmp cordic_neg

cordic_end:

   mov ax, 39796
   mov bx, ax

   mul si
   shr esi, 17
   jnc cordic_no_add1
   add dx, bx
cordic_no_add1:
   mov si, dx

   mov ax, bx
   mul di
   shr edi, 17
   jnc cordic_no_add2
   add dx, bx
cordic_no_add2:
   mov di, dx

   pop edx
   cmp edx, 0
   jge cordic_done
   neg edi
cordic_done:
 
   ret

cordic_zero:
   xor edi, edi
   mov esi, 10000h
   pop edx
   ret         
_cordic ENDP

_sqrt PROC
   ; returns sqrt(x) in eax where x is in 16.16 format in edx
   xor ebx, ebx ; b = 2^30
   inc ebx
   shl ebx, 30
   
   xor eax, eax ; q = 0
   mov esi, edx ; r = v

sqrt_loop:
   mov ecx, eax
   add ecx, ebx

   cmp esi, ecx
   jb sqrt_skip

   sub esi, ecx
   mov eax, ecx
   add eax, ebx

sqrt_skip:
   shl esi, 1
   shr ebx, 1

   cmp ebx, 040h
   ja sqrt_loop

sqrt_done:
   shr eax, 8 

   ret
_sqrt ENDP

   PUBLIC _set_video_mode
_set_video_mode PROC
   ARG mode:WORD
   push bp
   mov bp, sp

   mov ax, mode
   int 10h
   
   pop bp
   ret
_set_video_mode ENDP

   PUBLIC _vga_ellipse
_vga_ellipse PROC
   ARG x0:WORD, y0:WORD, XV:WORD, YV:WORD, YR:WORD, XH:WORD, XL:WORD, A:DWORD, B:DWORD, C:DWORD, Fn:DWORD, Fnw:DWORD, d1:DWORD, colour:BYTE
   
   push bp
   mov bp, sp

   push si
   push di

   mov ax, 0a000h ; set up video segment
   mov es, ax

   mov esi, A
   mov ebx, B
   mov ecx, C   

   mov dx, XV
   shl edx, 16

   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_x+2], dx

   mov dx, YV
   shl edx, 16

   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_YV+1], dx
   mov WORD PTR cs:[ell_y+1], dx
   
   mov dx, XH
   shl edx, 16

   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_XH+2], dx
   mov WORD PTR cs:[ell_XH2+2], dx

   mov dx, YR
   shl edx, 16

   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_YR+1], dx      

   mov dx, XL
   shl edx, 16

   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_XL+2], dx

   shl esi, 1
   shl ecx, 1

   ; second order differences

   mov DWORD PTR cs:[ell_Fn_n+3], ecx
   mov DWORD PTR cs:[ell_Fs_s+3], ecx
   mov eax, ecx
   sub eax, ebx
   mov DWORD PTR cs:[ell_Fn_nw+3], eax
   mov DWORD PTR cs:[ell_Fnw_n+3], eax
   mov eax, ecx
   add eax, ebx
   mov DWORD PTR cs:[ell_Fs_sw+3], eax
   mov DWORD PTR cs:[ell_Fsw_s+3], eax

   mov DWORD PTR cs:[ell_Fw_w+3], esi
   mov DWORD PTR cs:[ell_Fw_w2+3], esi
   mov eax, esi
   sub eax, ebx
   mov DWORD PTR cs:[ell_Fw_nw+3], eax
   mov DWORD PTR cs:[ell_Fnw_w+3], eax

   mov eax, esi
   add eax, ebx
   mov DWORD PTR cs:[ell_Fw_sw+3], eax
   mov DWORD PTR cs:[ell_Fsw_w+3], eax

   shl ebx, 1

   mov eax, esi
   sub eax, ebx
   add eax, ecx
   mov DWORD PTR cs:[ell_Fnw_nw+3], eax
   mov DWORD PTR cs:[ell_Fnw_nw2+3], eax

   add eax, ebx
   add eax, ebx
   mov DWORD PTR cs:[ell_Fsw_sw+3], eax
   mov DWORD PTR cs:[ell_Fsw_sw2+3], eax

   sar ebx, 1

   sar esi, 1
   sar ecx, 1

   mov eax, ebx
   sub eax, esi
   mov DWORD PTR cs:[ell_cross1+3], eax
   
   neg eax
   add eax, ecx
   mov DWORD PTR cs:[ell_cross2+3], eax

   add eax, ebx
   add eax, ebx
   mov DWORD PTR cs:[ell_cross3+3], eax

   sub eax, ecx
   mov DWORD PTR cs:[ell_cross4+3], eax

   mov edx, Fn

   mov DWORD PTR cs:[ell_Fn+2], edx

   mov edx, Fnw
   mov DWORD PTR cs:[ell_Fnw+2], edx

   mov edx, d1

   ; --------- region 1 ----------
   ; di = offset, al = colour, edx = d1
   ; esi = Fn, ecx = Fnw, bx = YR offset
   ; ebp = accum

   push ecx ; C
   push ebx ; B
   push esi ; A
   
ell_y:                ; set up offset for x0, y0
   mov di, 01234h
   add di, y0
   mov ax, di
   shl ax, 2
   add di, ax
   shl di, 6
   add di, x0
ell_x:
   add di, 01234h

   mov si, y0 ; compute reflected offset
   mov bx, si
   shl bx, 2
   add bx, si
   shl bx, 6
   add bx, x0
   shl bx, 1 
   sub bx, di
   shl ebx, 16

ell_YR:
   mov bx, 01234h    ; bx = YR offset 
   add bx, y0
   mov ax, bx
   shl ax, 2
   add bx, ax
   shl bx, 6
         
ell_Fn:
   mov esi, 012345678h ; Fn
ell_Fnw:
   mov ecx, 012345678h ; Fnw
   
   mov al, colour  ; colour      

   push bp

   cmp di, bx
   jae ell_skip_region1

ell_region1_loop:
   stosb
   dec di
   add di, 320   ; y += 1

   rol ebx, 16
   xchg di, bx
   stosb
   dec di
   sub di, 320
   
   cmp edx, 0    ; if d1 < 0 or Fn - Fnw < cross1 skip decx
   jl ell_skip_decx1
   mov ebp, esi
   sub ebp, ecx
ell_cross1:
   cmp ebp, 012345678h
   jl ell_skip_decx1

   inc di         ; x -= 1
   dec bx

   add edx, ecx   ; d1 += Fnw
ell_Fn_nw:
   add esi, 012345678h
ell_Fnw_nw:
   add ecx, 012345678h

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   jb ell_region1_loop

   jmp ell_skip_region1

ell_skip_decx1:
   
   add edx, esi   ; d1 += Fn
ell_Fn_n:
   add esi, 012345678h
ell_Fnw_n:
   add ecx, 012345678h

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   jb ell_region1_loop

ell_skip_region1:
   
   ; --------- region 2 ----------
   ; di = offset, al = colour, edx = d2
   ; esi = Fw, ecx = Fnw, bx = XH offset

   pop bp
   shl ebp, 16
   mov bp, di ; save offset

   pop edi   ; A
   pop ebx   ; B
   pop eax   ; C

   push eax   ; C
   push ebx   ; B
   push edi   ; A

   push esi   ; Fn

   sub esi, ecx ; Fw = Fnw - Fn + A + B + B/2
   neg esi
   add esi, edi
   add esi, ebx
   sar ebx, 1
   add esi, ebx
   
   add ecx, edi ; Fnw = Fnw + A - C
   sub ecx, eax     

   pop ebx    ; Fn
   sub ebx, esi ; d2 = d1 + (Fw - Fn + C)/2 + (A + C)/4 - A
   sub ebx, eax
   sar ebx, 1
   sub edx, ebx
   add eax, edi
   sar eax, 2
   add edx, eax
   sub edx, edi    

   mov di, bp  ; restore offset
   shr ebp, 16
   push bp
   
   mov si, y0 ; compute reflected offset
   mov bx, si
   shl bx, 2
   add bx, si
   shl bx, 6
   add bx, x0
   shl bx, 1 
   sub bx, di
   shl ebx, 16

   mov ax, di  ; compute y offset
   shr ax, 1   ; compute x coord/2
   mov bl, 160
   div bl
   shr ax, 8
   shl ax, 1
   sub ax, di ; subtract from offset
   neg ax
   and ax, 0fffeh ; mask final bit
   add ax, x0 ; add x0
   mov bx, ax

ell_XH:
   add bx, 01234h

   mov al, colour

   cmp di, bx
   jbe ell_skip_region2

ell_region2_loop:
   stosb
   sub di, 2  ; x -= 1

   rol ebx, 16
   xchg di, bx
   stosb

   cmp edx, 0
   jl ell_incy2

   mov ebp, ecx
   sub ebp, esi
ell_cross2:
   cmp ebp, 012345678h
   jl ell_incy2

   add edx, esi ; d2 += Fw
ell_Fw_w:
   add esi, 012345678h
ell_Fnw_w:
   add ecx, 012345678h

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   ja ell_region2_loop

   jmp ell_skip_region2
      
ell_incy2:

   sub di, 320 ; y += 1
   add ebx, 320+320*65536

   add edx, ecx ; d2 += Fnw
ell_Fw_nw:
   add esi, 012345678h
ell_Fnw_nw2:
   add ecx, 012345678h

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   ja ell_region2_loop

ell_skip_region2:
   
   ; --------- region 3 ----------
   ; di = offset, al = colour, edx = d3
   ; esi = Fw, ecx = Fsw, bx = XL offset

   pop bp
   shl ebp, 16 ; save offset
   mov bp, di

   pop edi   ; A
   pop eax   ; B

   add ecx, eax   ; d3 = d2 + Fw - Fnw + C2 - B
   neg ecx
   add ecx, esi

   add esi, eax   ; Fw += B

   xchg eax, [esp] ; B on stack
   
   shl eax, 1
   add ecx, eax
   add edx, ecx

   add ecx, eax    ; Fsw = Fw - Fnw + Fw + C2 + C2 - B
   sar eax, 1 
   xchg eax, [esp] ; C on stack   
   add ecx, esi
   add ecx, eax

   push eax  ; B
   push edi  ; A

ell_XH2:
   sub bx, 01234h
ell_XL:
   add bx, 01234h

   mov di, bp
   shr ebp, 16
   push bp

   rol ebx, 16
   mov ax, y0 ; compute reflected offset
   mov bx, ax
   shl bx, 2
   add bx, ax
   shl bx, 6
   add bx, x0
   shl bx, 1 
   sub bx, di
   rol ebx, 16

   mov al, colour

   cmp di, bx
   jbe ell_skip_region3

ell_region3_loop:
   stosb
   sub di, 2  ; x -= 1

   rol ebx, 16
   xchg di, bx
   stosb

   cmp edx, 0
   jl ell_skip_decy3

   mov ebp, ecx
   sub ebp, esi
ell_cross3:
   cmp ebp, 012345678h
   jg ell_skip_decy3

   add di, 320
   sub ebx, 320+320*65536

   add edx, ecx ; d3 += Fsw
ell_Fw_sw:
   add esi, 012345678h
ell_Fsw_sw:
   add ecx, 012345678h

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   ja ell_region3_loop

   jmp ell_skip_region3
      
ell_skip_decy3:

   add edx, esi ; d3 += Fw
ell_Fw_w2:
   add esi, 012345678h
ell_Fsw_w:
   add ecx, 012345678h

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   ja ell_region3_loop

ell_skip_region3:

   ; --------- region 4 ----------
   ; di = offset, al = colour, edx = d4
   ; esi = Fs, ecx = Fsw, bx = YV

   pop bp
   shl ebp, 16 ; save offset
   mov bp, di

   pop edi   ; A
   pop ebx   ; B
   pop eax   ; C

   neg esi   ; Fs = Fsw - Fw - B
   add esi, ecx
   sub esi, ebx

   ; d4 = d3 - Fsw/2 + Fs + A - (A + C - B)/4
   ; Fsw = Fsw + C - A
   push ecx ; save Fsw
   sar ecx, 1
   sub edx, ecx
   add edx, esi
   pop ecx ; restore Fsw
   add edx, edi
   sub ecx, edi
   add edi, eax
   sub edi, ebx
   sar edi, 2
   sub edx, edi
   add ecx, eax

   sar ebx, 1 ; Fs = Fs + C - B_2
   sub esi, ebx
   add esi, eax   

   mov di, bp  ; restore offset
   shr ebp, 16

   mov si, y0 ; compute reflected offset
   mov bx, si
   shl bx, 2
   add bx, si
   shl bx, 6
   add bx, x0
   shl bx, 1 
   sub bx, di
   shl ebx, 16

ell_YV:
   mov bx, 01234h
   neg bx
   add bx, y0
   mov ax, bx
   shl ax, 2
   add bx, ax
   shl bx, 6

   mov al, colour  ; colour      

   cmp di, bx
   jbe ell_skip_region4

ell_region4_loop:
   stosb
   dec di
   sub di, 320   ; y -= 1

   rol ebx, 16
   xchg di, bx
   stosb
   dec di
   add di, 320
   
   cmp edx, 0    ; if d4 < 0 or Fsw - Fs < cross4 decx
   jl ell_decx4
   mov ebp, ecx
   sub ebp, esi
ell_cross4:
   cmp ebp, 012345678h
   jl ell_decx4

   add edx, esi   ; d4 += Fs
ell_Fs_s:
   add esi, 012345678h
ell_Fsw_s:
   add ecx, 012345678h

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   ja ell_region4_loop

   jmp ell_skip_region4

ell_decx4:
   
   inc di         ; x -= 1
   dec bx

   add edx, ecx   ; d4 += Fsw
ell_Fs_sw:
   add esi, 012345678h
ell_Fsw_sw2:
   add ecx, 012345678h

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   ja ell_region4_loop

ell_skip_region4:
   stosb ; put final pixels

   rol ebx, 16
   xchg di, bx
   stosb

ell_end:

   pop di
   pop si
   
   pop bp
   ret
_vga_ellipse ENDP

   END