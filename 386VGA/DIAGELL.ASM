   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386
   .DATA

   ANGLES DD 13176795, 7778716, 4110060, 2086331, 1047214
          DD 524117, 262123, 131069, 65536, 32768, 16384
          DD 8192, 4096, 2048, 1024, 512, 256, 128, 64
          DD 32, 16, 8, 4, 2, 1

   d1L DD 0
   d1H DD 0
   d2L DD 0
   d2H DD 0
   d3L DD 0
   d3H DD 0
   d4L DD 0
   d4H DD 0
   
   FnL DD 0
   FnH DD 0
   FnwL DD 0
   FnwH DD 0
   FsL DD 0
   FsH DD 0
   FswL DD 0
   FswH DD 0
   FwL DD 0
   FwH DD 0

   DLO DD 0
   DHI DD 0

   xoff DW 0
   yoff DW 0

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
   ; result is computed in 24.8 fixed point

   shl edx, 8
   mov cx, 1800h ; iters = 24, power of 2 = 0
   mov bx, offset ANGLES - 4
   mov esi, 1000000h ; R[0] = 1
   xor edi, edi      ; R[1] = 0

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

   mov eax, 10188014
   mov ebx, eax

   mul esi
   shld edx, eax, 8
   shl eax, 9
   adc edx, 0
   mov esi, edx

   mov eax, ebx
   mul edi
   shld edx, eax, 8
   shl eax, 9
   adc edx, 0
   mov edi, edx

   pop edx
   cmp edx, 0
   jge cordic_done
   neg edi
cordic_done:
 
   ret

cordic_zero:
   xor edi, edi
   mov esi, 1000000h
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

   xor cl, cl

   cmp esi, 0
   je norm_done
   bt esi, 30
   jc norm_done

norm_loop:
   bt esi, 28
   jc norm_done
   bt esi, 29
   jc norm_done
   shl esi, 2
   inc cl
   jmp norm_loop
norm_done:

   push cx
   clc
   pushf
 
sqrt_loop:
   mov ecx, eax
   add ecx, ebx

   popf
   jc sqrt_noskip
   cmp esi, ecx
   jb sqrt_skip

sqrt_noskip:
   sub esi, ecx
   mov eax, ecx
   add eax, ebx

sqrt_skip:
   shl esi, 1
   pushf
   shr ebx, 1

   cmp ebx, 040h
   ja sqrt_loop

sqrt_done:
   popf

   add eax, 128
   shr eax, 8 

   pop cx
   shr eax, cl

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

   mov ax, a   ; aSq = a*a in edi
   mul al
   shl eax, 16
   mov edi, eax
   cmp a, 70
   jae a2noscale1
   shl edi, 1
a2noscale1:
   cmp a, 128
   jb a2noscale2
   shr edi, 1
a2noscale2:

   mov ax, b   ; c = sqrt(aSq - b*b) in eax
   cmp ax, a
   jbe aok     ; must have a >= b
   pop bp
   pop bp
   ret
aok:
   mul al
   shl eax, 16
   cmp a, 70
   jae b2noscale1
   shl eax, 1
b2noscale1:
   cmp a, 128
   jb b2noscale2
   shr eax, 1
b2noscale2:

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
   shld edx, eax, 8
   shl eax, 8
   add eax, 80000000h
   adc edx, 0
   mov ecx, edx

   mov eax, ebx ; Yf = c * sin(theta) in ebx
   imul edi
   shld edx, eax, 8
   shl eax, 8
   add eax, 80000000h
   adc edx, 0
   mov ebx, edx

   mov eax, ecx ; XfSq = Xf * Xf in esi
   imul eax
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0
   mov esi, edx

   mov eax, ebx ; YfSq = Yf * Yf in edx
   imul eax
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0

   pop edi      ; A = aSq - XfSq in esi, aSq in edi
   sub esi, edi
   neg esi

   mov eax, ebx ; B = -2 * Xf * Yf in ebx
   push edx ; save YfSq
   imul ecx
   shld edx, eax, 17
   shl eax, 17
   add eax, 80000000h
   adc edx, 0
   neg edx
   mov ebx, edx

   pop edx
   mov eax, edx ; D = aSq * (YfSq - A)
   sub eax, esi
   sar eax, 1
   mov ecx, edi
   sub ecx, edx ; C = aSq - YfSq in ecx
   sar edi, 17
   imul edi

   cmp a, 70
   jb ell_noscale1
   shld edx, eax, 1
   shl eax, 1
ell_noscale1:
   cmp a, 128
   jb ell_noscale2
   shld edx, eax, 1
   shl eax, 1
ell_noscale2:

   mov DLO, eax
   mov DHI, edx

   mov eax, ebx  ; k1 = -B/C2 in ebp
   inc eax
   sar eax, 1
   cdq
   shld edx, eax, 16
   shl eax, 16
   idiv ecx
   neg eax
   mov ebp, eax

   mov eax, ecx  ; A + B*k1 + C*k1*k1 in edi
   inc eax
   sar eax, 1
   imul ebp
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0
   mov eax, ebx
   inc eax
   sar eax, 1
   add edx, eax
   mov eax, edx
   imul ebp
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0
   mov eax, esi
   inc eax
   sar eax, 1
   add edx, eax
   mov edi, edx
   
   mov eax, DLO  ; -D/(A + B*k1 + C*k1*k1) in edx
   mov edx, DHI
   shld edx, eax, 16
   shl eax, 16
   idiv edi
   neg eax
   mov edx, eax

   push ebx
   push ecx
   push esi
   call _sqrt    ; Xv = sqrt(-D/(A + B*k1 + C*k1*k1)) in eax
   pop esi
   pop ecx
   pop ebx
   
   mov edx, eax

;   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_XV+1], dx    
   mov WORD PTR cs:[ell_Xinit+1], dx    
   mov WORD PTR cs:[ell_x+2], dx

   push ebp ; check we are not off screen
   mov bp, [esp+4]
   cmp dx, x0
   jbe xv_ok
xv_not_ok:
   pop ebp
   pop bp
   pop bp
   ret
xv_ok:   
   add dx, x0
   cmp dx, 320
   jae xv_not_ok 
   pop ebp

   imul ebp       ; Yv = Xv*k1      
   shld edx, eax, 16
;   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_YV+1], dx
   mov WORD PTR cs:[ell_Yinit+1], dx    
   mov WORD PTR cs:[ell_y+1], dx
   
   mov eax, ebx  ; k2 = -B/A2 in ebp
   inc eax
   sar eax, 1
   cdq
   shld edx, eax, 16
   shl eax, 16
   idiv esi
   neg eax
   mov ebp, eax

   push ebp      ; save k2

   mov eax, esi  ; A*k2*k2 + B*k2 + C in ebp
   inc eax
   sar eax, 1
   imul ebp
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0
   mov eax, ebx
   inc eax
   sar eax, 1
   add edx, eax
   mov eax, edx
   imul ebp
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0
   mov eax, ecx
   inc eax
   sar eax, 1
   add edx, eax
   mov edi, edx   

   mov eax, DLO  ; -D/(A*k2*k2 + B*k2 + C) in edx
   mov edx, DHI
   shld edx, eax, 16
   shl eax, 16
   idiv edi
   neg eax
   mov edx, eax

   push ebx
   push ecx
   push esi
   call _sqrt    ; Yh = sqrt(-D/(A + B*k2 + C*k2*k2)) in eax
   pop esi
   pop ecx
   pop ebx

   mov edx, eax
;   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_YH+1], dx

   push ebp ; check we are not off screen
   mov bp, [esp+8]
   cmp dx, y0
   jb yh_ok
yh_not_ok:
   pop ebp
   pop ebp
   pop bp
   pop bp
   ret
yh_ok:
   add dx, y0
   cmp dx, 200
   jae yh_not_ok
   pop ebp

   imul ebp       ; Xh = Yh*k2      
   shld edx, eax, 16
;   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_XH+2], dx
   mov WORD PTR cs:[ell_XH2+2], dx

   mov ebp, ecx  ; k3 = (A2 - B)/(C2 - B) in ebp
   mov edx, ebx
   inc edx
   sar edx, 1
   mov eax, esi
   sub eax, edx
   sub ebp, edx
   cmp eax, 0
   jge a2b1pos
   neg eax
   neg ebp
a2b1pos:
   cdq
   shld edx, eax, 16
   shl eax, 16
   push ebp
   sar ebp, 2 ; temporarily divide by 4
   cmp edx, ebp
   jl noof1
   neg ebp
   cmp edx, ebp
   jl noof2
   pop ebp
k3_limit:
   mov eax, DLO  ; XR = 0, YR = sqrt(-D/C)
   mov edx, DHI
   shld edx, eax, 16
   shl eax, 16
   neg edx  ; -D is positive 
   neg eax
   sbb edx, 0
   mov edi, ecx
   add edi, 1
   sar edi, 1
   div edi
   mov edx, eax
   push ebx
   push ecx
   push esi
   call _sqrt    ; Yr = sqrt(-D/C) in eax
   pop esi
   pop ecx
   pop ebx
   xor edi, edi  ; Xr = 0
   mov edx, eax  ; Yr
   jmp ell_xr0   
noof2:
   neg ebp
noof1:   
   pop ebp ; restore temporary div by 4
   idiv ebp
   mov ebp, eax

   push ebp     ; save k3 with original sign

   mov edi, ebx ; put B in edi
   inc edi
   sar edi, 1
   cmp ebp, 0
   jg k3pos
   neg edi
   neg ebp
k3pos:

   mov eax, ecx  ; A + B*k3 + C*k3*k3 in edi
   inc eax
   sar eax, 1
   imul ebp
   push edi
   shl edi, 16
   add eax, edi
   adc edx, 0
   pop edi
   sar edi, 16
   add edx, edi
   cmp edx, 32768*256
   jl ck3ok
k3_bad:
   pop ebp
   jmp k3_limit
ck3ok:
   cmp edx, 32768
   pushf
   jg k3big
   shld edx, eax, 8
   shl eax, 8
k3big:
   shld edx, eax, 8
   shl eax, 8
   add eax, 80000000h
   adc edx, 0
   mov eax, edx
   imul ebp

   popf
   push esi
   pushf
   jle k3noshift
   shr esi, 8
k3noshift:
   push esi          ; add A
   shl esi, 15
   add eax, esi
   adc edx, 0
   pop esi
   sar esi, 17
   add edx, esi

   mov edi, edx
   mov esi, eax

   mov eax, DLO  ; -D/(A + B*k3 + C*k3*k3) in edx
   mov edx, DHI

   cmp edi, 32768*256
   jge k3_huge
   cmp edi, -32768*256
   jle k3_huge

   shld edi, esi, 8
   shl esi, 8
   jmp k3_normal

k3_huge:   
   shrd eax, edx, 8
   sar edx, 8
   
k3_normal:
   popf
   jg k3_skip_scale
   shld edx, eax, 8
   shl eax, 8
k3_skip_scale:

   cmp edi, 32768*256
   jge k3_large
   cmp edi, -32768*256
   jle k3_large

   shld edx, eax, 8
   shl eax, 8
   add esi, 00800000h
   adc edi, 0
   shld edi, esi, 8

k3_large:

   pop esi
            
   idiv edi
   neg eax
   mov edx, eax

   push ebx
   push ecx
   push esi
   call _sqrt    ; Xr = sqrt(-D/(A + B*k3 + C*k3*k3)) in eax
   pop esi
   pop ecx
   pop ebx

   pop ebp       ; restore k3 with original sign

                 ; Yr = Xr*k3      
   mov edi, eax  ; save Xr
   imul ebp
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0

ell_xr0:
      
   pop eax       ; if Xr < Yr*k2 then Yr = -Yr
   push eax
   mov ebp, edx  ; save Yr
   imul edx
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0
   cmp edx, edi
   jle ell_no_neg_Yr
   neg ebp
ell_no_neg_Yr:
   mov edx, ebp

;   add edx, 8000h
   shr edx, 16
   mov WORD PTR cs:[ell_YR+1], dx      

   mov ebp, ecx  ; k4 = (-A2 - B)/(C2 + B) in ebp
   mov edx, ebx
   inc edx
   sar edx, 1
   mov eax, esi
   add eax, edx
   add ebp, edx
   cmp eax, 0
   jge a2b2pos
   neg eax
   neg ebp
a2b2pos:
   cdq
   shld edx, eax, 16
   shl eax, 16
   push ebp ; temporarily divide by 4
   sar ebp, 2
   cmp edx, ebp
   jl noof4
   neg ebp
   cmp edx, ebp
   jl noof3
   pop ebp
k4_limit:
   mov eax, DLO  ; XR = 0, YR = sqrt(-D/C)
   mov edx, DHI
   shld edx, eax, 16
   shl eax, 16
   neg edx  ; -D is positive 
   neg eax
   sbb edx, 0
   mov edi, ecx
   add edi, 1
   sar edi, 1
   div edi
   mov edx, eax
   push ebx
   push ecx
   push esi
   call _sqrt    ; Yl = sqrt(-D/C) in eax
   pop esi
   pop ecx
   pop ebx
   xor edi, edi  ; Xl = 0
   mov edx, eax  ; Yl
   jmp ell_xl0
noof3:
   neg ebp
noof4:   
   pop ebp ; restore temporary div by 4
   idiv ebp
   mov ebp, eax
   neg ebp

   push ebp     ; save k4 with original sign

   mov edi, ebx ; put B in edi
   inc edi
   sar edi, 1
   cmp ebp, 0
   jg k4pos
   neg edi
   neg ebp
k4pos:

   mov eax, ecx  ; A + B*k4 + C*k4*k4 in edi
   inc eax
   sar eax, 1
   imul ebp
   push edi
   shl edi, 16
   add eax, edi
   adc edx, 0
   pop edi
   sar edi, 16
   add edx, edi
   cmp edx, 32768*256
   jl ck4ok
k4_bad:
   pop ebp
   jmp k4_limit   
ck4ok:
   cmp edx, 32768
   pushf
   jg k4big
   shld edx, eax, 8
   shl eax, 8
k4big:
   shld edx, eax, 8
   shl eax, 8
   add eax, 80000000h
   adc edx, 0
   mov eax, edx
   imul ebp

   popf
   push esi
   pushf
   jle k4noshift
   shr esi, 8
k4noshift:
   push esi          ; add A
   shl esi, 15
   add eax, esi
   adc edx, 0
   pop esi
   sar esi, 17
   add edx, esi

   mov edi, edx
   mov esi, eax

   mov eax, DLO  ; -D/(A + B*k3 + C*k3*k3) in edx
   mov edx, DHI

   cmp edi, 32768*256
   jge k4_huge
   cmp edi, -32768*256
   jle k4_huge

   shld edi, esi, 8
   shl esi, 8
   jmp k4_normal

k4_huge:   
   shrd eax, edx, 8
   sar edx, 8
   
k4_normal:
   popf
   jg k4_skip_scale
   shld edx, eax, 8
   shl eax, 8
k4_skip_scale:

   cmp edi, 32768*256
   jge k4_large
   cmp edi, -32768*256
   jle k4_large

   shld edx, eax, 8
   shl eax, 8
   add esi, 00800000h
   adc edi, 0
   shld edi, esi, 8

k4_large:

   pop esi

   idiv edi
   neg eax
   mov edx, eax

   push ebx
   push ecx
   push esi
   call _sqrt     ; Xl = -sqrt(-D/(A + B*k4 + C*k4*k4))     
   pop esi
   pop ecx
   pop ebx

   pop ebp       ; restore k4 with original sign

                 ; Yl = Xl*k4      
   mov edi, eax  ; save Xl
   imul ebp
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0

ell_xl0:
      
   pop eax       ; if Xl > Yl*k2 then Xl = -Xl
   imul edx
   shld edx, eax, 16
   shl eax, 16
   add eax, 80000000h
   adc edx, 0
   mov eax, edi
   cmp edx, eax
   jge ell_no_neg_Xl
   neg eax
ell_no_neg_Xl:

;   add eax, 8000h
   shr eax, 16
   mov WORD PTR cs:[ell_XL+2], ax

   ; second order differences
   mov eax, esi
   sub eax, ebx
   add eax, ecx
   mov DWORD PTR cs:[ell_Fnw_nw+2], eax
   mov DWORD PTR cs:[ell_Fnw_nw2+2], eax

   add eax, ebx
   add eax, ebx
   mov DWORD PTR cs:[ell_Fsw_sw+2], eax
   mov DWORD PTR cs:[ell_Fsw_sw2+2], eax

   push ebx
   inc ebx
   sar ebx, 1

   mov DWORD PTR cs:[ell_Fn_n+2], ecx
   mov DWORD PTR cs:[ell_Fs_s+2], ecx
   mov eax, ecx
   sub eax, ebx
   mov DWORD PTR cs:[ell_Fn_nw+2], eax
   mov DWORD PTR cs:[ell_Fnw_n+2], eax
   mov eax, ecx
   add eax, ebx
   mov DWORD PTR cs:[ell_Fs_sw+2], eax
   mov DWORD PTR cs:[ell_Fsw_s+2], eax

   mov DWORD PTR cs:[ell_Fw_w+2], esi
   mov DWORD PTR cs:[ell_Fw_w2+2], esi
   mov eax, esi
   sub eax, ebx
   mov DWORD PTR cs:[ell_Fw_nw+2], eax
   mov DWORD PTR cs:[ell_Fnw_w+2], eax

   mov eax, esi
   add eax, ebx
   mov DWORD PTR cs:[ell_Fw_sw+2], eax
   mov DWORD PTR cs:[ell_Fsw_w+2], eax

   pop ebx

   mov eax, ebx
   sub eax, esi
   inc eax
   sar eax, 1
   mov DWORD PTR cs:[ell_cross1+2], eax
   
   mov eax, esi
   sub eax, ebx
   add eax, ecx
   inc eax
   sar eax, 1
   mov DWORD PTR cs:[ell_cross2+2], eax

   mov eax, esi
   add eax, ebx
   add eax, ecx
   inc eax
   sar eax, 1
   mov DWORD PTR cs:[ell_cross3+2], eax

   mov eax, esi
   add eax, ebx
   inc eax
   sar eax, 1
   mov DWORD PTR cs:[ell_cross4+2], eax
      
ell_Xinit:          ; Xinit = x - 0.5 put x in ebp
   mov bp, 01234h
   movsx ebp, bp 

   xor edx, edx
ell_Yinit:          ; Yinit = y + 1 in edx
   mov dx, 01234h
   inc dx
   movsx edx, dx
   push edx         ; save Yinit

   mov eax, ecx     ; Fn = C2*Yinit + B*Xinit + C
   imul edx
   mov edi, eax     ; ebp:edi = C2*Yinit 
   xchg ebp, edx
   mov eax, ebx
   inc eax
   sar eax, 1
   push edx         ; save Xinit
   imul edx
   add eax, edi
   adc edx, ebp
   mov ebp, ebx
   add ebx, 2
   sar ebp, 2
   sub eax, ebp
   sbb edx, 0
   bt ebp, 31
   adc edx, 0
   push ecx
   inc ecx
   sar ecx, 1
   add eax, ecx
   pop ecx
   adc edx, 0
   mov FnH, edx
   mov FnL, eax

   mov FnwH, edx
   mov FnwL, eax

    ; [esp+4] = Yinit
    ; [esp] = Xinit

   mov eax, esi     ; Fnw = Fn - A2*Xinit - B*Yinit + A - B
   imul DWORD PTR [esp]
   push esi
   inc esi
   sar esi, 1
   sub eax, esi
   pop esi
   sbb edx, 0
   mov ebp, edx     ; ebp:edi = A2*Xinit
   mov edi, eax

   mov eax, ebx
   inc eax
   sar eax, 1
   imul DWORD PTR [esp+4]
   add eax, edi
   adc edx, ebp
   push esi
   shr esi, 1
   sub eax, esi
   pop esi
   sbb edx, 0
   push ebx
   inc ebx
   sar ebx, 1
   add eax, ebx
   pop ebx
   adc edx, 0
   bt ebx, 31
   sbb edx, 0
   sub FnwL, eax
   sbb FnwH, edx

                   ; d1 = A*Xinit^2 + B*Xinit*Yinit + C*Yinit^2 + D in edx
   pop ebp         ; Xinit
   mov eax, ebp
   imul ebp
   sub eax, ebp
   mov edx, esi
   imul edx
   mov edi, esi
   add edi, 2
   shr edi, 2
   add eax, edi
   adc edx, 0
   add eax, 1
   adc edx, 0
   shrd eax, edx, 1
   sar edx, 1
   xchg eax, ebp   ; edi:ebp = A*Xinit^2
   mov edi, edx

   imul DWORD PTR [esp]      ; Yinit
   shl eax, 1
   sub eax, [esp]
   imul ebx
   add eax, 2
   adc edx, 0
   shrd eax, edx, 2
   sar edx, 2
   add ebp, eax
   adc edi, edx

   pop eax       ; Yinit
   imul eax
   imul ecx
   add eax, 1
   adc edx, 0
   shrd eax, edx, 1
   sar edx, 1
   add ebp, eax
   adc edi, edx

   add ebp, DLO
   adc edi, DHI

   mov d1L, ebp
   mov d1H, edi

   ; --------- region 1 ----------
   ; di = offsets, al = colour
   ; bx = YR offset
   ; edx:ecx = Fn, ebp:esi = Fnw

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
            
   mov al, colour  ; colour      

   push ebp

   mov ecx, FnL
   mov edx, FnH
   mov esi, FnwL
   mov ebp, FnwH

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

   shl eax, 16
   mov ax, di
ell_cross1:
   mov edi, 012345678h

   add esi, edi ; add cross1
   adc ebp, 0
   bt edi, 31
   sbb ebp, 0
   
   cmp d1H, 0    ; if d1 < 0 or Fn - Fnw < cross1 skip decx
   jl ell_skip_decx1

   cmp edx, ebp
   jl ell_skip_decx1
   jg ell_decx1
   cmp ecx, esi
   jb ell_skip_decx1

ell_decx1:

   sub esi, edi ; sub cross1
   sbb ebp, 0
   bt edi, 31
   adc ebp, 0
   
   inc ax         ; x -= 1
   dec bx

   add d1L, esi   ; d1 += Fnw
   adc d1H, ebp

ell_Fn_nw:
   mov edi, 012345678h
   bt edi, 31
   sbb edx, 0
   add ecx, edi
   adc edx, 0

ell_Fnw_nw:
   mov edi, 012345678h
   bt edi, 31
   sbb ebp, 0
   add esi, edi   
   adc ebp, 0

   mov di, ax
   shr eax, 16

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   jb ell_region1_loop

   jmp ell_skip_region1

ell_skip_decx1:

   sub esi, edi ; sub cross1
   sbb ebp, 0
   bt edi, 31
   adc ebp, 0
   
   add d1L, ecx   ; d1 += Fn
   adc d1H, edx

ell_Fn_n:
   mov edi, 012345678h
   bt edi, 31
   sbb edx, 0
   add ecx, edi
   adc edx, 0

ell_Fnw_n:
   mov edi, 012345678h
   bt edi, 31
   sbb ebp, 0
   add esi, edi
   adc ebp, 0

   mov di, ax
   shr eax, 16

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   jb ell_region1_loop

ell_skip_region1:

   ; --------- region 2 ----------
   ; di = offset, al = colour
   ; bx = XH offset
   ; edx:ecx = Fw, ebp:esi = Fsw

   push edx ; save Fn
   push ecx

   sub ecx, esi ; Fw = Fnw - Fn + A + B + B/2
   sbb edx, ebp
   neg edx
   neg ecx
   sbb edx, 0
   shld edx, ecx, 1
   shl ecx, 1
   add ecx, [esp+12]
   adc edx, 0
   mov eax, [esp+16]
   add ecx, eax
   adc edx, 0
   bt eax, 31
   sbb edx, 0
   inc eax
   sar eax, 1
   add ecx, eax
   adc edx, 0
   bt eax, 31
   sbb edx, 0
   add ecx, 1
   adc edx, 0
   shrd ecx, edx, 1
   sar edx, 1
      
   shld ebp, esi, 1
   shl esi, 1
   add esi, [esp+12] ; Fnw = Fnw + A - C
   adc ebp, 0
   sub esi, [esp+20]
   sbb ebp, 0
   add esi, 1
   adc ebp, 0
   shrd esi, ebp, 1
   sar ebp, 1     

   pop eax    ; Fn
   pop ebx

   sub eax, ecx  ; d2 = d1 + (Fw - Fn + C)/2 + (A + C)/4 - A
   sbb ebx, edx
   neg ebx
   neg eax
   sbb ebx, 0
   shld ebx, eax, 1
   shl eax, 1
   add eax, [esp+12]
   adc ebx, 0
   add eax, 2
   adc ebx, 0
   shrd eax, ebx, 2
   sar ebx, 2
   add d1L, eax
   adc d1H, ebx
   mov eax, [esp+4]
   add eax, [esp+12]
   add eax, 4
   shr eax, 3 ; A + C is positive   
   add d1L, eax
   adc d1H, 0
   mov eax, [esp+4]
   inc eax
   shr eax, 1
   sub d1L, eax
   sbb d1H, 0

   xchg ebp, [esp] ; restore bp
   
   mov ax, y0 ; compute reflected offset
   mov bx, ax
   shl bx, 2
   add bx, ax
   shl bx, 6
   add bx, x0
   shl bx, 1 
   sub bx, di
   shl ebx, 16

ell_YH:
   mov bx, 01234h    ; bx = YH offset 
   add bx, y0
   mov ax, bx
   shl ax, 2
   add bx, ax
   shl bx, 6
   mov yoff, bx

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

   xchg ebp, [esp]

   cmp di, yoff
   ja ell_skip_region2
   cmp di, bx
   jbe ell_skip_region2

ell_region2_loop:
   stosb
   sub di, 2  ; x -= 1

   rol ebx, 16
   xchg di, bx
   stosb

   shl eax, 16
   mov ax, di
ell_cross2:
   mov edi, 012345678h

   add ecx, edi ; add cross2
   adc edx, 0
   bt edi, 31
   sbb edx, 0
   
   cmp d1H, 0    ; if d2 < 0 or Fnw - Fw < cross2 inc y
   jl ell_incy2

   cmp ebp, edx
   jl ell_incy2
   jg ell_skip_incy2
   cmp esi, ecx
   jb ell_incy2

ell_skip_incy2:

   sub ecx, edi ; sub cross2
   sbb edx, 0
   bt edi, 31
   adc edx, 0
   
   add d1L, ecx   ; d2 += Fw
   adc d1H, edx

ell_Fw_w:
   mov edi, 012345678h
   bt edi, 31
   sbb edx, 0
   add ecx, edi
   adc edx, 0

ell_Fnw_w:
   mov edi, 012345678h
   bt edi, 31
   sbb ebp, 0
   add esi, edi   
   adc ebp, 0

   mov di, ax
   shr eax, 16

   xchg di, bx
   rol ebx, 16

   cmp di, yoff
   ja ell_skip_region2
   cmp di, bx
   ja ell_region2_loop

   jmp ell_skip_region2

ell_incy2:

   sub ax, 320 ; y += 1
   add ebx, 320+320*65536

   sub ecx, edi ; sub cross2
   sbb edx, 0
   bt edi, 31
   adc edx, 0
   
   add d1L, esi   ; d2 += Fnw
   adc d1H, ebp

ell_Fw_nw:
   mov edi, 012345678h
   bt edi, 31
   sbb edx, 0
   add ecx, edi
   adc edx, 0

ell_Fnw_nw2:
   mov edi, 012345678h
   bt edi, 31
   sbb ebp, 0
   add esi, edi
   adc ebp, 0

   mov di, ax
   shr eax, 16

   xchg di, bx
   rol ebx, 16

   cmp di, yoff
   ja ell_skip_region2
   cmp di, bx
   ja ell_region2_loop

ell_skip_region2:

   ; --------- region 3 ----------
   ; di = offset, al = colour
   ; bx = XL offset
   ; edx:ecx = Fw, ebp:esi = Fsw

   push ebx

   mov eax, ecx     ; d3 = d2 + Fw - Fnw + C2 - B
   mov ebx, [esp+12]
   inc ebx
   sar ebx, 1
   sub eax, ebx
   pushf
   bt ebx, 31
   mov ebx, edx
   adc ebx, 0
   popf
   sbb ebx, 0
   sub eax, esi
   sbb ebx, ebp
   add eax, [esp+16]
   adc ebx, 0
   add d1L, eax
   adc d1H, ebx
   
   mov eax, [esp+12]
   inc eax
   sar eax, 1
   add ecx, eax   ; Fw += B
   adc edx, 0
   bt eax, 31
   sbb edx, 0

                   ; Fsw = Fw - Fnw + Fw + C2 + C2 - B
   sub esi, ecx
   sbb ebp, edx
   sub esi, ecx
   sbb ebp, edx
   neg ebp
   neg esi
   sbb ebp, 0   
   add esi, [esp+16]
   adc ebp, 0
   add esi, [esp+16]
   adc ebp, 0
   mov eax, [esp+12]
   inc eax
   sar eax, 1
   bt eax, 31
   adc ebp, 0
   sub esi, eax
   sbb ebp, 0

   pop ebx
   
ell_XH2:
   sub bx, 01234h
ell_XL:
   add bx, 01234h

   xchg ebp, [esp]

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

   xchg ebp, [esp]

   cmp di, bx
   jbe ell_skip_region3

ell_region3_loop:
   stosb
   sub di, 2  ; x -= 1

   rol ebx, 16
   xchg di, bx
   stosb

   shl eax, 16
   mov ax, di
ell_cross3:
   mov edi, 012345678h

   add ecx, edi ; add cross3
   adc edx, 0
   bt edi, 31
   sbb edx, 0
   
   cmp d1H, 0    ; if d3 < 0 or Fsw - Fw > cross3 skip dec y
   jl ell_skip_decy3

   cmp ebp, edx
   jg ell_skip_decy3
   jl ell_decy3
   cmp esi, ecx
   ja ell_skip_decy3

ell_decy3:

   sub ecx, edi ; sub cross3
   sbb edx, 0
   bt edi, 31
   adc edx, 0

   add ax, 320
   sub ebx, 320+320*65536

   add d1L, esi ; d3 += Fsw
   adc d1H, ebp

ell_Fw_sw:
   mov edi, 012345678h
   bt edi, 31
   sbb edx, 0
   add ecx, edi
   adc edx, 0

ell_Fsw_sw:
   mov edi, 012345678h
   bt edi, 31
   sbb ebp, 0
   add esi, edi
   adc ebp, 0

   mov di, ax
   shr eax, 16

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   ja ell_region3_loop

   jmp ell_skip_region3
      
ell_skip_decy3:

   sub ecx, edi ; sub cross3
   sbb edx, 0
   bt edi, 31
   adc edx, 0

   add d1L, ecx ; d3 += Fw
   adc d1H, edx

ell_Fw_w2:
   mov edi, 012345678h
   bt edi, 31
   sbb edx, 0
   add ecx, edi
   adc edx, 0

ell_Fsw_w:
   mov edi, 012345678h
   bt edi, 31
   sbb ebp, 0
   add esi, edi
   adc ebp, 0

   mov di, ax
   shr eax, 16

   xchg di, bx
   rol ebx, 16

   cmp di, bx
   ja ell_region3_loop

ell_skip_region3:

   ; --------- region 4 ----------
   ; di = offset, al = colour, edx = d4
   ; esi = Fs, ecx = Fsw, bx = YV

                 ; Fs = Fsw - Fw - B
   sub ecx, esi
   sbb edx, ebp
   neg edx
   neg ecx
   sbb edx, 0
   mov eax, [esp+8]
   inc eax
   sar eax, 1
   bt eax, 31
   adc edx, 0
   sub ecx, eax
   sbb edx, 0

   ; d4 = d3 - Fsw/2 + Fs + A - (A + C - B)/4
   mov eax, esi
   mov ebx, ebp
   sub eax, ecx
   sbb ebx, edx
   sub eax, ecx
   sbb ebx, edx
   sub eax, [esp+4]
   sbb ebx, 0
   add eax, 1
   adc ebx, 0
   shrd eax, ebx, 1
   sar ebx, 1
   sub d1L, eax
   sbb d1H, ebx
   mov eax, [esp+4]
   inc eax
   sar eax, 1
   mov ebx, [esp+12]
   inc ebx
   sar ebx, 1
   add eax, ebx
   mov ebx, [esp+8]
   inc ebx
   sar ebx, 1
   sub eax, ebx
   add eax, 2
   sar eax, 2
   sub d1L, eax
   sbb d1H, 0
   bt eax, 31
   adc d1H, 0

   ; Fsw = Fsw + C - A
   mov eax, [esp+12]
   inc eax
   shr eax, 1
   add esi, eax
   adc ebp, 0
   mov eax, [esp+4]
   inc eax
   shr eax, 1
   sub esi, eax
   sbb ebp, 0   

   mov eax, [esp+12] ; Fs = Fs + C - B_2
   inc eax
   sar eax, 1
   add ecx, eax
   adc edx, 0
   mov eax, [esp+8]
   add eax, 2
   sar eax, 2
   sub ecx, eax
   sbb edx, 0
   bt eax, 31
   adc edx, 0

   xchg ebp, [esp]

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

ell_XV:
   sub ax, 01234h
   mov xoff, ax

ell_YV:
   mov bx, 01234h
   neg bx
   add bx, y0
   mov ax, bx
   shl ax, 2
   add bx, ax
   shl bx, 6

   mov al, colour  ; colour      

   xchg ebp, [esp]

   cmp di, xoff
   jb ell_skip_region4
   cmp di, bx
   jbe ell_skip_region4

ell_region4_loop:
   stosb
   dec di
   sub di, 320   ; y -= 1
   sub xoff, 320

   rol ebx, 16
   xchg di, bx
   stosb
   dec di
   add di, 320
   
   shl eax, 16
   mov ax, di
ell_cross4:
   mov edi, 012345678h

   add ecx, edi ; add cross4
   adc edx, 0
   bt edi, 31
   sbb edx, 0
   
   cmp d1H, 0    ; if d3 < 0 or Fsw - Fs < cross4 dec x
   jl ell_decx4

   cmp ebp, edx
   jl ell_decx4
   jg ell_skip_decx4
   cmp esi, ecx
   jb ell_decx4

ell_skip_decx4:

   sub ecx, edi ; sub cross4
   sbb edx, 0
   bt edi, 31
   adc edx, 0

   add d1L, ecx   ; d4 += Fs
   adc d1H, edx

ell_Fs_s:
   mov edi, 012345678h
   bt edi, 31
   sbb edx, 0
   add ecx, edi
   adc edx, 0

ell_Fsw_s:
   mov edi, 012345678h
   bt edi, 31
   sbb ebp, 0
   add esi, edi
   adc ebp, 0

   mov di, ax
   shr eax, 16

   xchg di, bx
   rol ebx, 16

   cmp di, xoff
   jb ell_skip_region4
   cmp di, bx
   ja ell_region4_loop

   jmp ell_skip_region4

ell_decx4:
   
   sub ecx, edi ; sub cross4
   sbb edx, 0
   bt edi, 31
   adc edx, 0

   inc ax         ; x -= 1
   dec bx

   add d1L, esi   ; d4 += Fsw
   adc d1H, ebp

ell_Fs_sw:
   mov edi, 012345678h
   bt edi, 31
   sbb edx, 0
   add ecx, edi
   adc edx, 0

ell_Fsw_sw2:
   mov edi, 012345678h
   bt edi, 31
   sbb ebp, 0
   add esi, edi
   adc ebp, 0

   mov di, ax
   shr eax, 16

   xchg di, bx
   rol ebx, 16

   cmp di, xoff
   jb ell_skip_region4
   cmp di, bx
   ja ell_region4_loop

ell_skip_region4:
   cmp di, bx
   jbe ell_end

   cmp di, xoff
   jb ell_end

   mov al, colour

   stosb ; put final pixel

   rol ebx, 16
   xchg di, bx
   stosb

ell_end:

   pop ebp
   pop esi
   pop ebx
   pop ecx
   
   pop bp
   ret
_diag_ell ENDP

start:
   mov ax, @DATA
   mov ds, ax

   mov ax, 13h ; mode 13h graphics
   int 10h

   call _set_palette

   mov bx, 90
rotate_loop:
   push bx
   mov dx, bx

   mov cx, 804
ell_loop:
   push cx
   push dx
   mov ax, cx
   shr ax, 1
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
   sub ax, 402
   movsx eax, ax
   shl eax, 8
   mov bx, ax
   shr eax, 16 ; theta_hi
   push ax
   mov ax, bx ; theta_lo
   push ax
   mov ax, dx   ; b
   push ax
   mov ax, 90   ; a
   push ax
   mov ax, 100  ; y0
   push ax
   mov ax, 160  ; x0
   push ax
   call _diag_ell
   add sp, 14

;   xor ah, ah   ; wait for key
;   int 16h

   pop dx
   pop cx
   dec cx
   cmp cx, 0
   jge ell_loop

;   xor ah, ah   ; wait for key
;   int 16h

   pop bx
   dec bx
   jnz rotate_loop

   xor ah, ah   ; wait for key
   int 16h

   mov ax, 03h  ; back to text mode
   int 10h

   mov ah, 04ch ; exit program
   int 21h

   END start