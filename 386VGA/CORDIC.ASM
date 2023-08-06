   DOSSEG
   .MODEL SMALL
   .STACK 100h
   .386
   .DATA

   ANGLES DD 51472, 30386, 16055, 8150, 4091, 2047, 1024, 512,
          DD 256, 128, 64, 32, 16, 8, 4, 2, 1

   .CODE

_cordic PROC
   ; returns cos(beta), sin(beta) in si, di
   ; given 0 < beta < pi/2 in edx in 0.16 fixed point

   xor cx, 1000h ; iters = 16, power of 2 = 0
   mov bx, offset ANGLES - 4
   xor esi, esi    ; R[0]
   xor edi, edi    ; R[1]

   cmp edx, 0
   jl cordic_neg

cordic_pos:

   ; esi, edi = esi - 2^-i * edi, 2^-i * esi + edi
   mov eax, esi
   shr eax, cl
   add eax, edi
   shr edi, cl
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

   ; esi, edi = esi + 2^-i * edi, 2^-i * esi - edi
   mov eax, esi
   shr eax, cl
   sub eax, edi
   shr edi, cl
   add esi, edi
   mov edi, eax
   
   inc cl    ; update power of 2
   dec ch    ; check iterations
   jl cordic_end

   ; beta += angle
   add bx, 4
   add edx, [bx]
   jge cordic_pos
   jmp cordic_neg

cordic_end:

   mov ax, 39797
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

   ret         
_cordic ENDP