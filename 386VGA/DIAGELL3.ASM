   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386
   .DATA

   ANGLES DD 51472, 30386, 16055, 8150, 4091, 2047, 1024, 512
          DD 256, 128, 64, 32, 16, 8, 4, 2, 1

   .CODE

_set_palette PROC
   mov cx, 255
   mov dx, 03c8h
   mov al, 1
   out dx, al
   inc dx

next_colour:
   mov al, 03fh
   out dx, al

   mov ax, cx
   shr ax, 2
   dec ax
   out dx, al

   xor al, al
   out dx, al

   loop next_colour

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

_diag_ell PROC
   ARG x0:WORD, y0:WORD, a:WORD, b:WORD, theta_hi:DWORD, colour:BYTE
   ; for now a >= b
   
   push bp
   mov bp, sp

   push bp

   mov ax, 0a000h ; set up video segment
   mov es, ax

   xor eax, eax
   mov ax, a   ; aSq = a*a in edi
   mul al
   shl eax, 16
   mov edi, eax

   mov ax, b   ; c = sqrt(aSq - b*b) in eax
   mul al
   shl eax, 16

   mov edx, edi
   sub edx, eax

   call _sqrt

   push edi    ; aSq
   push eax    ; c

   mov edx, theta_hi

   call _cordic

   pop eax     ; Xf = c * cos(theta) in ecx
   mov ebx, eax
   imul esi
   shld edx, eax, 16
   mov ecx, edx

   mov eax, ebx ; Yf = c * sin(theta) in ebx
   imul edi
   shld edx, eax, 16
   mov ebx, edx

   mov eax, ecx ; XfSq = Xf * Xf in esi
   imul eax
   shld edx, eax, 16
   mov esi, edx

   mov eax, ebx ; YfSq = Yf * Yf in edx
   imul eax
   shld edx, eax, 16

   pop edi      ; A = aSq - XfSq in esi, aSq in edi
   sub esi, edi
   sar esi, 8   ; we shift A, B, C, D right by 2
   neg esi

   mov eax, ebx ; B = -2 * Xf * Yf in ebx
   mov ebp, edx ; save YfSq in ebp
   imul ecx
   shld edx, eax, 9 ; we shift A, B, C, D right by 2
   neg edx
   mov ebx, edx

   mov eax, ebp ; D = aSq * (YfSq - A) in edi
   sar eax, 8 ; we shift A, B, C, D right by 2
   sub eax, esi
   ; we omit the aSq here and multiply sqrts by a below
   ; imul edi
   ; shld edx, eax, 16

   mov ecx, edi ; C = aSq - YfSq in ecx
   mov edi, eax
   sub ecx, ebp
   sar ecx, 8 ; we shift A, B, C, D right by 2

   mov eax, ebx  ; k1 = -B/C2 in ebp
   cdq
   shld edx, eax, 16
   shl eax, 16
   shl ecx, 1
   idiv ecx
   sar ecx, 1
   neg eax
   mov ebp, eax

   mov eax, ecx  ; A + B*k1 + C*k1*k1 in ebp
   imul ebp
   shld edx, eax, 16
   add edx, ebx
   mov eax, edx
   imul ebp
   shld edx, eax, 16
   add edx, esi
   push ebp      ; save k1
   mov ebp, edx
   
   mov eax, edi  ; -D/(A + B*k1 + C*k1*k1) in edx
   cdq
   shld edx, eax, 16
   shl eax, 16
   idiv ebp
   neg eax
   mov edx, eax

   push ebx
   push ecx
   push esi
   call _sqrt    ; Xv = sqrt(-D/(A + B*k1 + C*k1*k1)) in eax
   pop esi
   pop ecx
   pop ebx

   ; compensating multiplication by a
   mov bp, [esp+4] ; restore bp
   mov bp, a
   shl ebp, 16
   imul ebp
   shld edx, eax, 16
   mov eax, edx

   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_Xinit+1], dx    
   mov WORD PTR cs:[ell_x+2], dx

   pop ebp       ; Yv = Xv*k1      
   imul ebp
   shld edx, eax, 16
   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_YV+1], dx
   mov WORD PTR cs:[ell_Yinit+1], dx    
   mov WORD PTR cs:[ell_y+1], dx
   
   mov eax, ebx  ; k2 = -B/A2 in ebp
   cdq
   shld edx, eax, 16
   shl eax, 16
   shl esi, 1
   idiv esi
   sar esi, 1
   neg eax
   mov ebp, eax

   push ebp      ; save k2

   mov eax, esi  ; A*k2*k2 + B*k2 + C in ebp
   imul ebp
   shld edx, eax, 16
   add edx, ebx
   mov eax, edx
   imul ebp
   shld edx, eax, 16
   add edx, ecx
   push ebp      ; save k2
   mov ebp, edx   

   mov eax, edi  ; -D/(A*k2*k2 + B*k2 + C) in edx
   cdq
   shld edx, eax, 16
   shl eax, 16
   idiv ebp
   neg eax
   mov edx, eax

   push ebx
   push ecx
   push esi
   call _sqrt    ; Yh = sqrt(-D/(A + B*k2 + C*k2*k2)) in eax
   pop esi
   pop ecx
   pop ebx

   ; compensating multiplication by a
   mov bp, [esp+8] ; restore bp
   mov bp, a
   shl ebp, 16
   imul ebp
   shld edx, eax, 16
   mov eax, edx

   pop ebp       ; Xh = Yh*k2      
   imul ebp
   shld edx, eax, 16
   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_XH+2], dx
   mov WORD PTR cs:[ell_XH2+2], dx

   mov ebp, ecx  ; k3 = (A2 - B)/(C2 - B) in ebp
   shl ebp, 1
   sub ebp, ebx
   mov eax, esi
   shl eax, 1
   sub eax, ebx
   cdq
   shld edx, eax, 16
   shl eax, 16
   idiv ebp
   mov ebp, eax

   cmp ebp, 128*65536
   jl k3_ok1
k3_not_ok:
   xor edx, edx
   xor ebp, ebp
   jmp ell_xr0
k3_ok1:

   cmp ebp, -128*65536
   jl k3_not_ok

   mov eax, ecx  ; A + B*k3 + C*k3*k3 in ebp
   imul ebp
   shld edx, eax, 16
   add edx, ebx
   mov eax, edx
   imul ebp
   shld edx, eax, 16
   add edx, esi
   push ebp      ; save k3
   mov ebp, edx
   
   mov eax, edi  ; -D/(A + B*k3 + C*k3*k3) in edx
   cdq
   shld edx, eax, 16
   shl eax, 16
   idiv ebp
   neg eax
   mov edx, eax

   push ebx
   push ecx
   push esi
   call _sqrt    ; Xr = sqrt(-D/(A + B*k3 + C*k3*k3)) in eax
   pop esi
   pop ecx
   pop ebx

   ; compensating multiplication by a
   mov bp, [esp+8] ; restore bp
   mov bp, a
   shl ebp, 16
   imul ebp
   shld edx, eax, 16
   mov eax, edx

   pop edx       ; Yr = Xr*k3      
   mov ebp, eax  ; save Xr
   imul edx
   shld edx, eax, 16
      
ell_xr0:

   pop eax       ; if Xr < Yr*k2 then Yr = -Yr
   push eax
   push edx      ; save Yr
   imul edx
   shld edx, eax, 16
   cmp edx, ebp
   pop edx
   jle ell_no_neg_Yr
   neg edx
ell_no_neg_Yr:

   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_YR+1], dx      

   mov ebp, ecx  ; k4 = (-A2 - B)/(C2 + B) in ebp
   shl ebp, 1
   add ebp, ebx
   mov eax, esi
   shl eax, 1
   neg eax
   sub eax, ebx
   cdq
   shld edx, eax, 16
   shl eax, 16
   idiv ebp
   mov ebp, eax

   cmp ebp, 128*65536
   jl k4_ok1
k4_not_ok:
   xor edx, edx
   xor ebp, ebp
   jmp ell_xl0
k4_ok1:

   cmp ebp, -128*65536
   jl k4_not_ok

   mov eax, ecx  ; A + B*k4 + C*k4*k4 in ebp
   imul ebp
   shld edx, eax, 16
   add edx, ebx
   mov eax, edx
   imul ebp
   shld edx, eax, 16
   add edx, esi
   push ebp      ; save k4
   mov ebp, edx
   
   mov eax, edi  ; -D/(A + B*k4 + C*k4*k4) in edx
   cdq
   shld edx, eax, 16
   shl eax, 16
   idiv ebp
   neg eax
   mov edx, eax

   push ebx
   push ecx
   push esi
   call _sqrt     ; Xl = -sqrt(-D/(A + B*k4 + C*k4*k4))     
   pop esi
   pop ecx
   pop ebx

   ; neg eax

   ; compensating multiplication by a
   mov bp, [esp+8] ; restore bp
   mov bp, a
   shl ebp, 16
   imul ebp
   shld edx, eax, 16
   mov eax, edx

   pop edx       ; Yl = Xl*k4      
   mov ebp, eax  ; save Xl
   imul edx
   shld edx, eax, 16

ell_xl0:
      
   pop eax       ; if Xl > Yl*k2 then Xl = -Xl
   imul edx
   shld edx, eax, 16
   mov eax, ebp
   cmp edx, eax
   jge ell_no_neg_Xl
   neg eax
ell_no_neg_Xl:

   add eax, 8000h
   shr eax, 16
   mov WORD PTR cs:[ell_XL+2], ax

   mov bp, [esp] ; restore bp temporarily
   mov ax, a
   mul ax
   shl eax, 16
   imul edi
   shld edx, eax, 16 ; result is shifted right by 8 bits
   mov edi, edx

   shl esi, 1
   shl ecx, 1

   ;sar esi, 7 ; multiply by 2 and shift right by 8 bits
   ;sar ebx, 8 ; shift right by 8 bits
   ;sar ecx, 7 ; multiply by 2 and shift right by 8 bits

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
      
ell_Xinit:          ; Xinit = x - 0.5 in ebp
   mov bp, 01234h
   shl ebp, 16
   sub ebp, 8000h

ell_Yinit:          ; Yinit = y + 1 in edx
   mov dx, 01234h
   inc dx
   shl edx, 16
   push edx         ; save Yinit

   mov eax, ecx     ; Fn = C2*Yinit + B*Xinit + C
   shl eax, 1
   imul edx
   shld edx, eax, 16
   xchg ebp, edx
   mov eax, ebx
   push edx         ; save Xinit
   imul edx
   shld edx, eax, 16
   add edx, ebp
   add edx, ecx
   mov DWORD PTR cs:[ell_Fn+2], edx
   push edx         ; save Fn

   mov edx, [esp+8]  ; Yinit
   mov ebp, [esp+4]  ; Xinit

   mov eax, ebx     ; Fnw = Fn - A2*Xinit - B*Yinit + A - B
   imul edx
   shld edx, eax, 16
   xchg edx, ebp
   mov eax, esi
   shl eax, 1
   imul edx
   shld edx, eax, 16
   add edx, ebp
   pop eax
   sub eax, edx
   add eax, esi
   sub eax, ebx
   mov DWORD PTR cs:[ell_Fnw+2], eax

                   ; d1 = A*Xinit^2 + B*Xinit*Yinit + C*Yinit^2 + D in edx
   pop ebp         ; Xinit
   mov eax, ebp
   imul ebp
   shld edx, eax, 16
   mov eax, esi
   imul edx
   shld edx, eax, 16
   mov eax, ebp
   pop ebp         ; Yinit
   push esi        ; save A
   mov esi, edx
   imul ebp
   shld edx, eax, 16
   mov eax, ebx
   imul edx
   shld edx, eax, 16
   add esi, edx
   mov eax, ebp
   imul ebp
   shld edx, eax, 16
   mov eax, ecx
   imul edx
   shld edx, eax, 16
   add edx, esi
   add edx, edi   
   pop esi         ; restore A

   ; --------- region 1 ----------
   ; di = offset, al = colour, edx = d1
   ; esi = Fn, ecx = Fnw, bx = YR offset
   ; ebp = accum

   pop bp
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
   stosb ; put final pixel

ell_end:
   
   pop bp
   ret
_diag_ell ENDP

start:
   mov ax, @DATA
   mov ds, ax

   mov ax, 13h ; mode 13h graphics
   int 10h

   call _set_palette

;   mov bx, 100
;rotate_loop:
;   push bx

   mov cx, 402
ell_loop:
   push cx
   mov ax, cx
   sub ax, 201
   cmp ax, 0
   jge no_invert_colour
   neg ax
no_invert_colour:
   add ax, 1
   xor ah, ah ; colour
   push ax 
   xor eax, eax
   mov ax, cx
   sub ax, 201
   movsx eax, ax
   shl eax, 9
   mov bx, ax
   shr eax, 16 ; theta_hi
   push ax
   mov ax, bx ; theta_lo
   push ax
   mov ax, 50   ; b
   push ax
   mov ax, 80   ; a
   push ax
   mov ax, 100  ; y0
   push ax
   mov ax, 160  ; x0
   push ax
   call _diag_ell
   add sp, 14

   xor ah, ah   ; wait for key
   int 16h

   pop cx
   loop ell_loop

;   pop bx
;   dec bx
;   jnz rotate_loop

   xor ah, ah   ; wait for key
   int 16h

   mov ax, 03h  ; back to text mode
   int 10h

   mov ah, 04ch ; exit program
   int 21h

   END start