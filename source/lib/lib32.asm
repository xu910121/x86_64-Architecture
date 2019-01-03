; lib32.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\lib.inc"
%include "..\inc\support.inc"
%include "..\inc\protected.inc"

        bits 32
        
        org LIB32_SEG - 2

lib32_length        dw        LIB32_END - $

;*
;* ˵����
;*      1. ������ lib32 �⺯���ĵ�����
;*      2. ��Ƕ�뵽 protected.asm ģ��ĵ���� lib32_import_table.imt ��ʹ��
;*      3. ��������һ����ת����ת�����յĺ�������
;*      4. ÿ����ת���� 5 ���ֽڿ��ɵ����������ַ

putc:                           jmp     DWORD __putc
println:                        jmp     DWORD __println
puts:                           jmp     DWORD __puts
get_dword_hex_string:           jmp     DWORD __get_dword_hex_string
hex_to_char:                    jmp     DWORD __hex_to_char
lowers_to_uppers:               jmp     DWORD __lowers_to_uppers
dump_flags:                     jmp     DWORD __dump_flags
uppers_to_lowers:               jmp     DWORD __uppers_to_lowers
strlen:                         jmp     DWORD __strlen
test_println:                   jmp     DWORD __test_println
reverse:                        jmp     DWORD __reverse
get_byte_hex_string:            jmp     DWORD __get_byte_hex_string
get_qword_hex_string:           jmp     DWORD __get_qword_hex_string
subtract64:                     jmp     DWORD __subtract64
addition64:                     jmp     DWORD __addition64
print_value:                    jmp     DWORD __print_value
printblank:                     jmp     DWORD __printblank
print_half_byte_value:          jmp     DWORD __print_half_byte_value
; ���������Ǳ���λ
RESERVED_0                      jmp     DWORD __reserved_func
RESERVED_1                      jmp     DWORD __reserved_func
set_interrupt_handler:          jmp     DWORD __set_interrupt_handler
set_IO_bitmap:                  jmp     DWORD __set_IO_bitmap
get_MAXPHYADDR:                 jmp     DWORD __get_MAXPHYADDR
print_byte_value:               jmp     DWORD __print_byte_value
print_word_value:               jmp     DWORD __print_word_value
print_dword_value:              jmp     DWORD __print_dword_value
print_qword_value:              jmp     DWORD __print_qword_value
set_call_gate:                  jmp     DWORD __set_call_gate
get_tss_base:                   jmp     DWORD __get_tss_base
write_gdt_descriptor:           jmp     DWORD __write_gdt_descriptor
read_gdt_descriptor:            jmp     DWORD __read_gdt_descriptor
get_tr_base:                    jmp     DWORD __get_tr_base
system_service:                 jmp     DWORD __system_service
set_user_interrupt_handler:     jmp     DWORD __set_user_interrupt_handler
sys_service_enter:              jmp     DWORD __sys_service_enter
set_sysenter:                   jmp     DWORD __set_sysenter
conforming_lib32_service:       jmp     DWORD __conforming_lib32_service
clib32_service_enter:           jmp     DWORD __clib32_service_enter
set_ldt_descriptor:             jmp     DWORD __set_ldt_descriptor
move_gdt:                       jmp     DWORD __move_gdt
set_clib32_service:             jmp     DWORD __set_clib32_service_table
print_dword_decimal:            jmp     DWORD __print_decimal
print_dword_float:              jmp     DWORD __print_dword_float
print_qword_float:              jmp     DWORD __print_qword_float
print_tword_float:              jmp     DWORD __print_tword_float
set_system_service_table        jmp     DWORD __set_system_service_table
set_video_current               jmp     DWORD __set_video_current
get_video_current               jmp     DWORD __get_video_current
mul64:                          jmp     DWORD __mul64

;*
;* ������ lib32 �⺯����ʵ��
;*

__reserved_func:        
        ret


;-----------------------------------------
; strlen(): ��ȡ�ַ�������
; input:
;                esi: string
; output:
;                eax: length of string
;------------------------------------------
__strlen:
        mov eax, -1
        test esi, esi
        jz strlen_done
strlen_loop:
        inc eax
        cmp BYTE [esi + eax], 0
        jnz strlen_loop
strlen_done:        
        ret
        
        
;---------------------------------------------------
; memcpy(): �����ַ�
; input:
;                esi: Դbuffer edi:Ŀ��buffer [esp+4]: �ֽ���
;---------------------------------------------------
__memcpy:
        push es
        push ecx
        mov ax, ds
        mov es, ax
        mov ecx, [esp + 12]                        ; length
        shr ecx, 2
        rep movsd
        mov ecx, [esp + 12]
        and ecx, 3
        rep movsb
        pop ecx
        pop es
        ret

;----------------------------------------------
; reverse():        ��bit��ת
; input:
;                esi: DWORD value
; ouput:
;                eax: reverse of value
;------------------------------------------
__reverse:
        push ecx
        xor eax, eax
do_reverse:
        bsr ecx, esi
        jz reverse_done
        btr esi, ecx
        neg ecx
        add ecx, 31
        bts eax, ecx
        jmp do_reverse
reverse_done:        
        pop ecx
        ret



;------------------------------------------
; __get_current_row()
;------------------------------------------
__get_current_row:
        push ebx
        mov eax, [video_current]
        sub eax, 0xb8000
        mov bl, 80*2
        div bl
        movzx eax, al
        pop ebx
        ret


;------------------------------------------
; __get_current_column()
;------------------------------------------
__get_current_column:
        push ebx
        mov eax, [video_current]
        sub eax, 0xb8000
        mov bl, 80*2
        div bl
        movzx eax, ah
        pop ebx
        ret


;--------------------------------------------
; test_println():        �����Ƿ���Ҫ��ӡ���з�
; input:
;                esi: string
; output:
;                eax: 1(��Ҫ), 0(����Ҫ��
;--------------------------------------------
__test_println:
        push ecx
        call __strlen                ; �õ��ַ�������
        mov ecx, eax
        shl ecx, 1                        ; len * 2
        call __get_current_column
        neg eax
        add eax, 80*2
        cmp eax, ecx
        setb al
        movzx eax, al
        pop ecx
        ret
        
;-------------------------------------------
; write_char(char c): �� video ��д��һ���ַ�
; input:
;                esi: �ַ�
;-------------------------------------------
__write_char:
        push ebx
        mov ebx, video_current
        or si, 0F00h
        cmp si, 0F0Ah                                ; LF
        jnz do_wirte_char
        call __get_current_column
        neg eax
        add eax, 80*2
        add eax, [ebx]
        jmp do_write_char_done
        
do_wirte_char:        
        mov eax, [ebx]
        cmp eax, 0B9FF0h
        ja do_write_char_done
        mov [eax], si
        add eax, 2
do_write_char_done:        
        mov [ebx], eax
        pop ebx
        ret
        

;--------------------------------
; putc(): ��ӡһ���ַ�
; input: 
;                esi: char
;--------------------------------
__putc:
        and esi, 0x00ff
        call __write_char
        ret

;--------------------------------
; println(): ��ӡ����
;--------------------------------
__println:
        mov si, 10
        call __putc
        ret
;------------------------------
; printblank(): ��ӡһ���ո�
;-----------------------------
__printblank:
        mov si, ' '
        call __putc
        ret        

;--------------------------------
; puts(): ��ӡ�ַ�����Ϣ
; input: 
;                esi: message
;--------------------------------
__puts:
        push ebx
        mov ebx, esi
        test ebx, ebx
        jz do_puts_done

do_puts_loop:        
        mov al, [ebx]
        test al, al
        jz do_puts_done
        mov esi, eax
        call __putc
        inc ebx
        jmp do_puts_loop

do_puts_done:        
        pop ebx
        ret        


;-----------------------------------------
; hex_to_char(): �� Hex ����ת��Ϊ Char �ַ�
; input:
;                esi: Hex number
; ouput:
;                eax: Char
;----------------------------------------
__hex_to_char:
        jmp do_hex_to_char
@char        db '0123456789ABCDEF', 0

do_hex_to_char:        
        push esi
        and esi, 0x0f
        movzx eax, BYTE [@char+esi]
        pop esi
        ret

;--------------------------------------
; dump_hex() : ��ӡ hex ��
; input:
;        esi: value
;--------------------------------------
__dump_hex:
        push ecx
        push esi
        mov ecx, 8                                        ; 8 �� half-byte
do_dump_hex_loop:
        rol esi, 4                                        ; ��4λ --> �� 4λ
        mov edi, esi
        call __hex_to_char
        mov esi, eax
        call __putc
        mov esi, edi
        dec ecx
        jnz do_dump_hex_loop
        pop esi
        pop ecx
        ret

;---------------------------------------
; print_value(): ��ӡֵ
;---------------------------------------
__print_value:
        call __dump_hex
        call __println
        ret
        
__print_half_byte_value:
        call __hex_to_char
        mov esi, eax
        call __putc
        ret

;------------------------
; print_decimal(): ��ӡʮ������
; input:
;                esi - 32 λֵ
;-------------------------
__print_decimal:
        jmp do_print_decimal
quotient        dd 0                        ; ��
remainder        dd 0                        ; ����
value_table: times 20 db 0
do_print_decimal:        
        push edx
        push ecx
        mov eax, esi                        ; ��ʼ��ֵ
        mov [quotient], eax        
        mov ecx, 10
        lea esi, [value_table+19]        
        
do_print_decimal_loop:
        dec esi                              ; ָ�� value_table
        xor edx, edx
        div ecx                              ; ��/10
        test eax, eax                        ; �� == 0 ?
        cmovz edx, [quotient]
        mov [quotient], eax
        lea edx, [edx + '0']        
        mov [esi], dl                        ; д������ֵ
        jnz do_print_decimal_loop
        
do_print_decimal_done:
        call puts        
        pop ecx
        pop edx
        ret        


;--------------------------------------
; print_dword_float(): ��ӡ������ֵ
; input:
;       esi - float ��ֵַ
;-------------------------------------
__print_dword_float:
        fnsave [fpu_image32]
        finit
        fld DWORD [esi]
        call __print_float
        frstor [fpu_image32]        
        ret
            
;--------------------------------------
; print_qword_float(): ��ӡ˫����ֵ
; input:
;       esi - double float ��ֵַ
;-------------------------------------
__print_qword_float:
        fnsave [fpu_image32]
        finit
        fld QWORD [esi]
        call __print_float
        frstor [fpu_image32]        
        ret

;--------------------------------------
; ��ӡ��չ˫����ֵ
;-------------------------------------
__print_tword_float:
        fnsave [fpu_image32]
        finit
        fld TWORD [esi]
        call __print_float
        frstor [fpu_image32]        
        ret
                
;-------------------------------------------
; ��ӡС����ǰ��ֵ
;-------------------------------------------     
__print_point:
        jmp do_print_point
digit_array times 200 db 0       
do_print_point:        
        push ebx
        lea ebx, [digit_array + 98]
        mov BYTE [ebx], '.'
print_point_loop:        
;; ��ǰ��
;; st(3) = 10.0
;; st(2) = 1.0
;; st(1) = ����ֵ
;; st(0) = point ֵ
        dec ebx
        fdiv st0, st3           ; value / 10
        fld st2
        fld st1
        fprem                   ; ������
        fsub st2, st0
        fmul st0, st5
        fistp DWORD [value]
        mov eax, [value]
        add eax, 0x30
        mov BYTE [ebx], al  
        fstp DWORD [value]      
        fldz
        fcomip st0, st1         ; ����С�� 0
        jnz print_point_loop

print_point_done:        
        fstp DWORD [value]
        mov esi, ebx
        call puts
        pop ebx
        ret    
                
;--------------------
; ��ӡ������
;--------------------        
__print_float:
        jmp do_print_float
value           dd 0     
f_value         dt 10.0
point           dd 0
do_print_float:        
        fld TWORD [f_value]             ; st2
        fld1                            ; st1
        fld st2                         ; st0
        fprem                           ; st0/st1, ȡ����
        fld st3
        fsub st0, st1
        call __print_point
        
        mov DWORD [point], 0                
;; ��ǰ��
;; st(2) = 10.0
;; st(1) = 1.0
;; st(0) = ����ֵ        
do_print_float_loop:        
        fldz
        fcomip st0, st1                 ; �����Ƿ�Ϊ 0
        jz print_float_next
        fmul st0, st2                   ; ���� * 10
        fld st1                         ; 1.0
        fld st1                         ; ���� * 10
        fprem                           ; ȡ����
        fld st2
        fsub st0, st1
        fistp DWORD [value]
        mov esi, [value]
        call print_dword_decimal          ; ��ӡֵ    
        mov DWORD [point], 1
        fxch st2
        fstp DWORD [value]
        fstp DWORD [value]
        jmp do_print_float_loop
        
print_float_next:        
        cmp DWORD [point], 1
        je print_float_done
        mov esi, '0'
        call putc
print_float_done:        
        ret        


;;---------------------------
;; ��ӡһ�� byte
;------------------------------        
__print_byte_value:
        push ebx
        push esi
        mov ebx, esi
        shr esi, 4
        call __hex_to_char
        mov esi, eax
        call __putc
        mov esi, ebx
        call __hex_to_char
        mov esi, eax
        call __putc
        pop esi
        pop ebx
        ret
        
        
__print_word_value:
        push ebx
        push esi
        mov ebx, esi
        shr esi, 8
        call __print_byte_value
        mov esi, ebx
        call __print_byte_value
        pop esi                
        pop ebx
        ret        

__print_dword_value:
        push ebx
        push esi
        mov ebx, esi
        shr esi, 16
        call __print_word_value
        mov esi, ebx
        call __print_word_value
        pop esi
        pop ebx
        ret

;--------------------------
; print_qword_value()
; input:
;                edi:esi - 64 λֵ
;--------------------------
__print_qword_value:
        push ebx
        push esi
        mov ebx, esi
        mov esi, edi
        call __print_dword_value
        mov esi, ebx
        call __print_dword_value
        pop esi
        pop ebx
        ret        
        
;-------------------------------------------
; letter():  �����Ƿ�Ϊ��ĸ
; input:
;                esi: char
; output:
;                eax: 1(����ĸ), 0(������ĸ��
;-------------------------------------------
__letter:
        and esi, 0xff
        cmp esi, DWORD 'z'
        setbe al
        ja test_letter_done
        cmp esi, DWORD 'A'
        setae al
        jb test_letter_done
        cmp esi, DWORD 'Z'
        setbe al
        jbe test_letter_done
        cmp esi, DWORD 'a'
        setae al
test_letter_done:
        movzx eax, al
        ret

;---------------------------------------
; lowercase(): �����Ƿ�ΪСд��ĸ
; input:
;                esi: char
; output:
;                1: �ǣ� 0����
;----------------------------------------
__lowercase:
        and esi, 0xff
        cmp esi, DWORD 'z'
        setbe al        
        ja test_lowercase_done
        cmp esi, DWORD 'a'
        setae al
test_lowercase_done:
        movzx eax, al        
        ret
        
;---------------------------------------
; uppercase(): �����Ƿ�Ϊ��д��ĸ
; input:
;                esi: char
; output:
;                1: �ǣ� 0����
;----------------------------------------
__uppercase:
        and esi, 0xff
        cmp esi, DWORD 'Z'
        setbe al        
        ja test_uppercase_done
        cmp esi, DWORD 'A'
        setae al
test_uppercase_done:
        movzx eax, al        
        ret

;-----------------------------------------
; digit(): �����Ƿ�Ϊ����
; input:
;                esi: char
; output: 
;                eax: 1-yes, 0-no
;-----------------------------------------
__digit:
        and esi, 0xff
        xor eax, eax
        cmp esi, DWORD '0'
        setae al
        jb test_digit_done        
        cmp esi, DWORD '9'
        setbe al
test_digit_done:
        movzx eax, al
        ret        
        
        
;----------------------------------------------------------------------
; lower_upper():        ��Сд��ĸ��ת��
; input:
;                esi:��Ҫת������ĸ,  edi: 1 (С��ת��Ϊ��д)��0 (��дת��ΪСд)
; output:
;                eax: result letter
;---------------------------------------------------------------------
__lower_upper:
        push ecx
        mov ecx, DWORD ('a' - 'A')
        call __letter
        test eax, eax
        jz do_lower_upper_done                   ; ���������ĸ
        bt edi, 0
        jnc set_lower_upper                      ; 1?
        neg ecx                                 ; Сдת��д����
set_lower_upper:                
        add esi, ecx
do_lower_upper_done:                
        mov eax, esi
        pop ecx
        ret

;---------------------------------------------------
; upper_to_lower(): ��д��ĸתСд��ĸ
; input:
;                esi: ��Ҫת������ĸ
; output:
;                eax: Сд��ĸ
;---------------------------------------------------
__upper_to_lower:
        call __uppercase                        ; �Ƿ�Ϊ��д��ĸ
        test eax, eax
        jz do_upper_to_lower_done        ; ������ǾͲ��ı�
        mov eax, DWORD ('a' - 'A')
do_upper_to_lower_done:        
        add eax, esi
        ret
        
;---------------------------------------------------
; lower_to_upper(): Сд��ĸת��д��ĸ
; input:
;                esi: ��Ҫת������ĸ
; output:
;                eax: ��д��ĸ
;---------------------------------------------------
__lower_to_upper:
        call __lowercase                        ; �Ƿ�ΪСд��ĸ
        test eax, eax
        jz do_lower_to_upper_done        ; ������ǾͲ��ı�
        mov eax, DWORD ('a' - 'A')
        neg eax
do_lower_to_upper_done:        
        add eax, esi                                
        ret
                
;---------------------------------------------------
; lowers_to_uppers(): Сд��ת��Ϊ��д��
; input:
;                esi: Դ���� edi:Ŀ�괮        
;---------------------------------------------------
__lowers_to_uppers:
        push ecx
        push edx
        
        mov ecx, esi
        mov edx, edi
        test ecx, ecx
        jz do_lowers_to_uppers_done
        test edx, edx
        jz do_lowers_to_uppers_done
        
do_lowers_to_uppers_loop:
        movzx esi, BYTE [ecx]
        test esi, esi
        jz do_lowers_to_uppers_done
        call __lower_to_upper
        mov BYTE [edx], al
        inc edx
        inc ecx
        jmp do_lowers_to_uppers_loop
        
do_lowers_to_uppers_done:        
        pop edx
        pop ecx
        ret

;---------------------------------------------------
; uppers_to_lowers(): ��д��ת��ΪСд��
; input:
;                esi: Դ���� edi:Ŀ�괮        
;---------------------------------------------------
__uppers_to_lowers:
        push ecx
        push edx
        
        mov ecx, esi
        mov edx, edi
        test ecx, ecx
        jz do_uppers_to_lowers_done
        test edx, edx
        jz do_uppers_to_lowers_done
        
do_uppers_to_lowers_loop:
        movzx esi, BYTE [ecx]
        test esi, esi
        jz do_uppers_to_lowers_done
        call __upper_to_lower
        mov BYTE [edx], al
        inc edx
        inc ecx
        jmp do_uppers_to_lowers_loop
        
do_uppers_to_lowers_done:        
        pop edx
        pop ecx
        ret

;--------------------------------------------------------------
; get_qword_hex_string(): �� QWORD ת��Ϊ�ַ���
; input:
;                esi: ָ�� QWORD ֵ��ָ��, edi: buffer��������Ҫ17bytes)
;--------------------------------------------------------------
__get_qword_hex_string:
        push ecx
        push esi
        mov ecx, esi
        mov esi, [ecx + 4]                        ; dump �� 32 λ
        call __get_dword_hex_string
        mov esi, [ecx]
        call __get_dword_hex_string
        pop esi
        pop ecx
        ret

;-------------------------------------------------
; get_dword_hex_string(): ���� (DWORD) ת��Ϊ�ַ���
; input:
;                esi: ��ת��������dword size)
;                edi: Ŀ�괮 buffer�������Ҫ 9 bytes������ 0)
;---------------------------------------------------
__get_dword_hex_string:
        push ecx
        push esi
        mov ecx, 8                                        ; 8 �� half-byte
do_get_dword_hex_string_loop:
        rol esi, 4                                        ; ��4λ --> �� 4λ
        call __hex_to_char
        mov byte [edi], al
        inc edi
        dec ecx
        jnz do_get_dword_hex_string_loop
        mov byte [edi], 0
        pop esi
        pop ecx
        ret        

;----------------------------------------------------
; get_byte_hex_string(): �� BYTE ת��Ϊ�ַ���
; input:
;                esi: BYTE ֵ, edi: buffer�������Ҫ3��)
;----------------------------------------------------
__get_byte_hex_string:
        push ecx
        push esi
        mov ecx, esi
        shr esi, 4
        call __hex_to_char
        mov BYTE [edi], al
        inc edi
        mov esi, ecx
        call __hex_to_char
        mov BYTE [edi], al
        inc edi
        mov BYTE [edi], 0
        pop esi
        pop ecx
        ret

;---------------------------------------------------------
; dump_flags():                ��ӡ 32 λ�ļĴ������ֵ
; description:
;                �������������������һ mask ֵ�Ͷ�Ӧ�� flags�ַ���
;                ��� bit��mask����ӡ��д���������ӡСд��
; example:
;                CPUID.EAX=01H ���ص� EDX �Ĵ������д�����֧�ֵ���չ����
;                ��� EDX ��λ�У�֧�־ʹ�ӡ��д����֧�־ʹ�ӡСд
;                mov esi, edx                        ;; CPUID.EAX=01H ���ص� edx�Ĵ���
;                mov edi, edx_flags
;                call dump_flags
; input:
;                esi: �Ĵ���ֵ, edi: flags��
;---------------------------------------------------------
__dump_flags:
        push ebx
        push edx
        push ecx
        mov ecx, esi
        mov ebx, edi
do_dump_flags_loop:        
        mov edx, [ebx]
        cmp edx, -1                                 ; ������־ 0xFFFFFFFF
        je do_dump_flags_done
        shr ecx, 1
        setc al
        test edx, edx
        jz dump_flags_next
        mov esi, edx                                        ; Դ��
        mov edi, edx                                        ; Ŀ�괮
        test al, al
        jz do_dump_flags_disable                ; ����λ�ʹ�дתСд
        call __lowers_to_uppers                        ; ����λ��Сдת��д
        jmp print_flags_msg        
do_dump_flags_disable:                                
        call __uppers_to_lowers
print_flags_msg:
        mov esi, edx
        call __test_println                                ; �����Ƿ���Ҫ����
        test eax, eax
        jz skip_ln
        call println
skip_ln:        
        mov esi, edx                                        ; ��ӡ flags ��Ϣ
        call __puts
        mov esi, DWORD ' '
        call __putc
dump_flags_next:        
        add ebx, 4
        jmp do_dump_flags_loop                
                
do_dump_flags_done:        
        pop ecx
        pop edx
        pop ebx
        ret

;__dump_flags:
;        push ebp
;        push ecx
;        push edx
;        push ebx
;        mov ecx, 0
;        mov ebx, edi                                ; flags �ַ���
;        mov edx, esi
;do_dump_flags_loop:
;        mov ebp, [ebx + ecx * 4]
;        cmp ebp, -1                                        ; ���Խ����� 0xFFFFFFFF
;        je do_dump_flags_done
;        test ebp, ebp
;        jnz dump_flags_next
;        inc ecx
;        jmp do_dump_flags_loop
;dump_flags_next:        
;        mov esi, ebp        
;        mov edi, ebp
;        bt edx, ecx
;        jnc do_dump_flags_disable                ; ����λ�ʹ�дתСд
;        call __lowers_to_uppers                        ; ����λ��Сдת��д
;        jmp print_flags_msg        
;do_dump_flags_disable:                                
;        call __uppers_to_lowers
;print_flags_msg:
;        mov esi, ebp
;        call __test_println                                ; �����Ƿ���Ҫ����
;        test eax, eax
;        jz skip_ln
;        call println
;skip_ln:        
;        mov esi, ebp                                        ; ��ӡ flags ��Ϣ
;        call __puts
;        mov esi, DWORD ' '
;        call __putc
;        inc ecx
;        jmp do_dump_flags_loop        

;do_dump_flags_done:        
;        pop ebx
;        pop edx
;        pop ecx
;        pop ebp
;        ret


;----------------------------------------------
; get_MAXPHYADDR(): �õ� MAXPHYADDR ֵ
; output:
;                eax: MAXPHYADDR
;----------------------------------------------
__get_maxphyaddr:
__get_MAXPHYADDR:
        push ecx
        mov ecx, 32
        mov eax, 80000000H
        cpuid
        cmp eax, 80000008H
        jb test_pse36                                                ; ��֧�� 80000008H leaf
        mov eax, 80000008H
        cpuid
        movzx ecx, al                                                ; MAXPHYADDR ֵ
        jmp do_get_MAXPHYADDR_done
test_pse36:        
        mov eax, 01H
        cpuid
        bt edx, 17                                                        ; PSE-36 support ?
        jnc do_get_MAXPHYADDR_done
        mov ecx, 36

do_get_MAXPHYADDR_done:        
        mov eax, ecx
        pop ecx
        ret
        
        
;--------------------------------------------
; subtract64(): 64λ�ļ���
; input:
;                esi: ��������ַ�� edi: ������ַ
; ouput:
;                edx:eax ���ֵ
;--------------------------------------------
__subtract64:
        mov eax, [esi]
        sub eax, [edi]
        mov edx, [esi + 4]
        sbb edx, [edi + 4]
        ret
        
;----------------------------------------
; addition64(): 64λ�ӷ�
; input:
;                esi: ��������ַ�� edi: ������ַ
; ouput:
;                edx:eax ���ֵ
;---------------------------------------
__addition64:
        mov eax, [esi]
        add eax, [edi]
        mov edx, [esi + 4]
        adc edx, [edi + 4]
        ret
        
;------------------------------------------------------        
; mul64(): 64λ�˷�
; input:
;       esi: ��������ַ, edi: ������ַ, ebp: ���ֵ��ַ
; ������
; c3:c2:c1:c0 = a1:a0 * b1:b0
;(1) a0*b0 = d1:d0
;(2) a1*b0 = e1:e0
;(3) a0*b1 = f1:f0
;(4) a1*b1 = h1:h0
;
;               a1:a0
; *             b1:b0
;----------------------
;               d1:d0
;            e1:e0
;            f1:f0
; +       h1:h0
;-----------------------
; c0 = b0
; c1 = d1 + e0 + f0
; c2 = e1 + f1 + h0 + carry
; c3 = h1 + carry
;------------------------------------------------------------
__mul64:
        jmp do_mul64
c2_carry        dd 0        
c3_carry        dd 0
temp_value      dd 0
do_mul64:        
        push ecx
        push ebx
        push edx
        mov eax, [esi]                  ; a0
        mov ebx, [esi + 4]              ; a1        
        mov ecx, [edi]                  ; b0
        mul ecx                         ; a0 * b0 = d1:d0, eax = d0, edx = d1
        mov [ebp], eax                  ; ���� c0
        mov ecx, edx                    ; ���� d1
        mov eax, [edi]                  ; b0
        mul ebx                         ; a1 * b0 = e1:e0, eax = e0, edx = e1
        add ecx, eax                    ; ecx = d1 + e0
        mov [temp_value], edx           ; ���� e1
        adc DWORD [c2_carry], 0         ; ���� c2 ��λ
        mov ebx, [esi]                  ; a0
        mov eax, [edi + 4]              ; b1
        mul ebx                         ; a0 * b1 = f1:f0
        add ecx, eax                    ; d1 + e0 + f0
        mov [ebp + 4], ecx              ; ���� c1
        adc DWORD [c2_carry], 0         ; ���� c2 ��λ
        add [temp_value], edx           ; e1 + f1
        adc DWORD [c3_carry], 0         ; ���� c3 ��λ
        mov eax, [esi + 4]              ; a1
        mul ebx                         ; a1 * b1 = h1:h0
        add [temp_value], eax           ; e1 + f1 + h0
        adc DWORD [c3_carry], 0         ; ���� c3 ��λ
        mov eax, [c2_carry]             ; ��ȡ c2 ��λֵ
        add eax, [temp_value]           ; e1 + f1 + h0 + carry
        mov [ebp + 8], eax              ; ���� c2
        add edx, [c3_carry]             ; h1 + carry
        mov [ebp + 12], edx             ; ���� c3
        pop edx
        pop ebx
        pop ecx
        ret
        
        
;;########### ������ϵͳ��ص� lib ���� ###########
        
;------------------------------------------------------
; set_interrupt_handler(int vector, void(*)()handler)
; input:
;       esi: vector,  edi: handler
;------------------------------------------------------
__set_interrupt_handler:
        sidt [__idt_pointer]        
        mov eax, [__idt_pointer + 2]
        mov [eax + esi * 8 + 4], edi                            ; set offset [31:16]
        mov [eax + esi * 8], di                                 ; set offset[15:0]
        mov DWORD [eax + esi * 8 + 2], kernel_code32_sel        ; set selector
        mov WORD [eax + esi * 8 + 5], 80h | INTERRUPT_GATE32    ; Type=interrupt gate, P=1, DPL=0
        ret

;------------------------------------------------------
; set_user_interrupt_handler(int vector, void(*)()handler)
; input:
;       esi: vector,  edi: handler
;------------------------------------------------------
__set_user_interrupt_handler:
        sidt [__idt_pointer]        
        mov eax, [__idt_pointer + 2]
        mov [eax + esi * 8 + 4], edi                           ; set offset [31:16]
        mov [eax + esi * 8], di                                ; set offset [15:0]
        mov DWORD [eax + esi * 8 + 2], kernel_code32_sel       ; set selector
        mov WORD [eax + esi * 8 + 5], 0E0h | INTERRUPT_GATE32  ; Type=interrupt gate, P=1, DPL=3
        ret
        

;------------------------------------------------------
; move_gdt(): �� GDT ����ĳ��λ����
; input:
;       esi: address
;--------------------------------------------------------
__move_gdt:
        push ecx
        push esi                                ; GDT' base
        mov edi, esi
        sgdt [__gdt_pointer]
        mov esi, [__gdt_pointer + 2]
        movzx ecx, WORD [__gdt_pointer]
        push cx                                 ; GDT's limit
        rep movsb
        lgdt [esp]                                ;
        add esp, 6
        pop ecx
        ret

;---------------------------------------------------------
; read_gdt_descriptor()
; input:        
;       esi: vector
; ouput:
;       edx:eax - descriptor
;---------------------------------------------------------
__read_gdt_descriptor:
        sgdt [__gdt_pointer]
        mov eax, [__gdt_pointer + 2]
        and esi, 0FFF8h        
        mov edx, [eax + esi + 4]        
        mov eax, [eax + esi]
        ret

;---------------------------------------------------------
; write_gdt_descriptor()
; input:        
;       esi: vector     edx:eax - descriptor
;---------------------------------------------------------
__write_gdt_descriptor:
        sgdt [__gdt_pointer]
        mov edi, [__gdt_pointer + 2]
        and esi, 0FFF8h        
        mov [edi + esi], eax
        mov [edi + esi + 4], edx
        ret
                
        
;-------------------------------------------------------
; get_tss_base(): ��� TSS �������ַ
; input:
;                esi: TSS selector
; output:
;                eax: base of TSS
;------------------------------------------------------
__get_tss_base:
        push edx
        call __read_gdt_descriptor
        shrd eax, edx, 16                                ; base[23:0]
        and eax, 0x00FFFFFF
        and edx, 0xFF000000                              ; base[31:24]
        or eax, edx                                
        pop edx
        ret

;-----------------------------------------------------
; get_tr_base(): ���� TR.base
;-----------------------------------------------------        
__get_tr_base:
        str esi
        call __get_tss_base
        ret


;------------------------------------------------------------------------
; set_call_gate(int selector, long address, int count)
; input:
;                esi: selector,  edi: address, eax: count
; ע�⣺
;                ���ｫ call gate ��Ȩ����Ϊ 3 �������û�������Ե���
;--------------------------------------------------------------------------
__set_call_gate:
        push ebx
        sgdt [__gdt_pointer]
        mov ebx, [__gdt_pointer + 2]
        and esi, 0FFF8h
        mov [ebx + esi + 4], edi                        ; offset [31:16]
        mov [ebx + esi], di                             ; offset[15:0]
        mov WORD [ebx + esi + 2], KERNEL_CS             ; selector
        and eax, 01Fh                                   ; count
        mov [ebx + esi + 4], al
        mov BYTE [ebx + esi + 5], 0E0h | CALL_GATE32    ; type=call_gate32, DPL=3
        pop ebx
        ret
        

;----------------------------------------------------
; set_ldt_descriptor()
; input:
;       esi: selector, edi: address,  eax: limit
;----------------------------------------------------
__set_ldt_descriptor:
        push ebx
        sgdt [__gdt_pointer]
        mov ebx, [__gdt_pointer + 2]
        and esi, 0FFF8h
        mov [ebx + esi + 4], edi                ; д base [31:24]
        mov [ebx + esi], cx                     ; д limit [15:0]
        mov [ebx + esi + 2], edi                ; д base [23:0]
        mov BYTE [ebx + esi + 5], 82h           ; type=LDT, P=1, DPL=0
        shr eax, 16
        and eax, 0Fh
        mov [ebx + esi + 6], al                 ; д limit [19:16]
        pop ebx
        ret


;--------------------------------------------------------
; set_IO_bitmap(int port, int value): ���� IOBITMAP �е�ֵ
; input:
;       esi - port���˿�ֵ����edi - value ���õ�ֵ
;---------------------------------------------------------
__set_IO_bitmap:
        push ebx
        push ecx
        str eax                                  ; �õ� TSS selector
        and eax, 0FFF8h
        sgdt [__gdt_pointer]                     ; �õ� GDT base
        add eax, [__gdt_pointer + 2]             ;
        mov ebx, [eax + 4]        
        and ebx, 0FFh
        shl ebx, 16
        mov ecx, [eax + 4]
        and ecx, 0FF000000h
        or ebx, ecx
        mov eax, [eax]                            ; �õ� TSS descriptor
        shr eax, 16
        or eax, ebx
        movzx ebx, WORD [eax + 102]
        add eax, ebx                              ; �õ� IOBITMAP
        mov ebx, esi
        shr ebx, 3
        and esi, 7
        bt edi, 0
        jc set_bitmap
        btr DWORD [eax + ebx], esi               ; ��λ
        jmp do_set_IO_bitmap_done
set_bitmap:
        bts DWORD [eax + ebx], esi               ; ��λ
do_set_IO_bitmap_done:        
        pop ecx
        pop ebx
        ret

;-----------------------------------------------------
; set_sysenter(): ����ϵͳ�� sysenter/sysexit ʹ�û���
;-----------------------------------------------------
__set_sysenter:
        xor edx, edx
        mov eax, KERNEL_CS
        mov ecx, IA32_SYSENTER_CS
        wrmsr                                                        ; ���� IA32_SYSENTER_CS
        mov eax, PROCESSOR_KERNEL_ESP
        mov ecx, IA32_SYSENTER_ESP                
        wrmsr                                                        ; ���� IA32_SYSENTER_ESP
        mov eax, __sys_service
        mov ecx, IA32_SYSENTER_EIP
        wrmsr                                                        ; ���� IA32_SYSENTER_EIP
        ret

;---------------------------------------------------
; sys_service_enter(): �������� service �� stub ����
;---------------------------------------------------
__sys_service_enter:
        push ecx
        push edx
        mov ecx, esp                                            ; ���ش���� ESP ֵ 
        mov edx, return_address                                 ; ���ش���� EIP ֵ
        sysenter                                                ; ���� 0 �� service
return_address:
        pop edx
        pop ecx
        ret

;--------------------------------------------------------
; sys_service()��ʹ�� sysenter/sysexit �汾��ϵͳ��������
; input:
;                eax: ϵͳ�������̺�
;--------------------------------------------------------
__sys_service:
        push ecx                                                ; ���淵�� esp ֵ
        push edx                                                ; ���淵�� eip ֵ
        mov eax, [system_service_table + eax * 4]
        call eax                                                ; ����ϵͳ��������        
        pop edx
        pop ecx
        sysexit
        
        
;-------------------------------------------------------
; system_service(): ϵͳ��������,ʹ���ж�0x40�ŵ��ý��롡
; input:
;                eax: ϵͳ�������̺�
;--------------------------------------------------------
__system_service:
        mov eax, [system_service_table + eax * 4]
        call eax                                ; ����ϵͳ��������
        iret

;-------------------------------------------------------
; set_system_service_table(): �����жϵ��ú���
; input:
;       esi: ���ܺţ���edi: ��������
;-------------------------------------------------------
__set_system_service_table:
        mov [system_service_table + esi * 4], edi
        ret

;-----------------------------
; set_video_current():
; input:
;       esi: video current
;------------------------------
__set_video_current:
        mov DWORD [video_current], esi
        ret

;------------------------------
; get_video_current();
;------------------------------
__get_video_current:
        mov eax, [video_current]        
        ret



; ���� conforming_lib32.asm ��
%include "..\lib\conforming_lib32.asm"


;******** lib32 ģ��ı������� ********
video_current   dd 0B8000h


;******** ϵͳ�������̺����� ***************
system_service_table:
        dd __puts                                       ; 0 ��
        dd __read_gdt_descriptor                        ; 1 ��
        dd __write_gdt_descriptor                       ; 2 ��
        dd 0                                            ; 3 ��
        dd 0                                            ; 4 ��
        dd 0                                            ; 5 ��
        dd 0                                            ; 6 ��
        dd 0
        dd 0
        dd 0

        
;; �� 28 ���ֽ�
fpu_image32:
x87env32:
control_word    dd 0
status_word     dd 0
tag_word        dd 0
ip_offset       dd 0
ip_selector     dw 0
opcode          dw 0
op_offset       dd 0
op_selector     dd 0

;; FSAVE/FNSAVE��FRSTOR ָ��ĸ���ӳ��
;; ���� 8 �� 80 λ���ڴ��ַ���� data �Ĵ���ֵ
r0_value        dt 0.0
r1_value        dt 0.0
r2_value        dt 0.0
r3_value        dt 0.0
r4_value        dt 0.0
r5_value        dt 0.0
r6_value        dt 0.0
r7_value        dt 0.0

;; ���� 32 λ�� GPRs �����Ĵ洢��
lib32_context  times 10 dd 0


; GDT ��ָ��
__gdt_pointer:
                dw 0                        ; GDT limit ֵ
                dd 0                        ; GDT base ֵ

; IDT ��ָ��
__idt_pointer:
                dw 0                        ; IDT limit ֵ
                dd 0                        ; IDT base ֵ
                        
                                                
LIB32_END:        

; 
; ���� protected mode ��ʹ�õĿ�