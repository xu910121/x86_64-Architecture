; setup.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


; ����һ���հ�ģ��ʾ������Ϊ setup ģ��
; ����д����̵ĵ� 2 ������ ��
;

%include "..\inc\support.inc"

;
; setup ģ���������� 16 λʵģʽ��

        bits 16
        
        
;
; ģ�鿪ʼ���� SETUP_SEG - 2���� 2 ����ΪҪ����ģ��ͷ�Ĵ�ŵġ�ģ�� size��
; load_module ���ص� SETUP_SEG-2��ʵ��Ч���� SETUP ģ��ᱻ���ص�����ڵ㡱����setup_entry
;
        org SETUP_SEG - 2
        
;
; ��ģ��Ŀ�ͷ word ��С����������ģ��Ĵ�С��
; load_module �������� size ����ģ�鵽�ڴ�

SETUP_BEGIN:

setup_length    dw (SETUP_END - SETUP_BEGIN)            ; SETUP_END-SETUP_BEGIN �����ģ��� size


setup_entry:                                            ; ����ģ��������ڵ㡣
        
        call test_CPUID
        test ax, ax
        jz no_support
        
        

;; ���ڵõ�����ܺ� 0DH ����Ϣ
        mov si, msg1
        call puts        
        mov eax, 0Dh
        cpuid        
        mov [eax_value], eax
        mov [ebx_value], ebx
        mov [ecx_value], ecx
        mov [edx_value], edx        
        call print_register_value                    ; ��ӡ�Ĵ�����ֵ
        
; �������빦�ܺ�Ϊ eax = 0Ch
        mov si, msg2
        call puts
        mov eax, 0Ch
        cpuid
        mov [eax_value], eax
        mov [ebx_value], ebx
        mov [ecx_value], ecx
        mov [edx_value], edx        
        call print_register_value                    ; ��ӡ�Ĵ�����ֵ
        
        
;; ���ڵõ� extended ����ܺ� 80000008h ����Ϣ        
        mov si, msg3
        call puts
        mov eax, 80000008h
        cpuid
        mov [eax_value], eax
        mov [ebx_value], ebx
        mov [ecx_value], ecx
        mov [edx_value], edx
        call print_register_value                    ; ��ӡ�Ĵ�����ֵ

;; ���ڲ��� extended ����ܺ� 80000009 ����Ϣ
        mov si, msg4
        call puts
        mov eax, 80000009h
        cpuid
        mov [eax_value], eax
        mov [ebx_value], ebx
        mov [ecx_value], ecx
        mov [edx_value], edx
        call print_register_value                    ; ��ӡ�Ĵ�����ֵ

        jmp $
        
no_support:        
        mov si, [message_table + eax * 2]
        call puts
        jmp $

msg1                    db '---- Now: eax = 0DH ----', 13, 10, 0
msg2                    db '---- Now: eax = 0Ch ----', 13, 10, 0
msg3                    db '---- Now: eax = 80000008H ----', 13, 10, 0
msg4                    db '---- Now: eax = 80000009H ----', 13, 10, 0


eax_value               dd 0        
eax_message             db 'eax: 0x', 0
ebx_value               dd 0
ebx_message             db 'ebx: 0x', 0
ecx_value               dd 0
ecx_message             db 'ecx: 0x', 0
edx_value               dd 0
edx_message             db 'edx: 0x', 0


support_message         db 'support CPUID instruction', 13, 10, 0
no_support_message      db 'no support CPUID instruction', 13, 10, 0                
message_table           dw no_support_message, support_message, 0


;------------------------------------
; print_register_value()
; input:
;                esi - regiser value
;------------------------------------
print_register_value:
        jmp do_print_register_value
        
register_table  dw eax_value, ebx_value, ecx_value, edx_value, 0
value_address   dd 0, 0, 0
        
do_print_register_value:        
        xor ecx, ecx

do_print_register_value_loop:        
        movzx ebx, word [register_table + ecx * 2]
        mov esi, [ebx]
        mov di, value_address
        call get_dword_hex_string
        
        lea si, [ebx + 4]
        call puts
        mov si, value_address
        call puts
        call println
        
        inc ecx
        cmp ecx, 3
        jle do_print_register_value_loop

        ret



;
; ���������ģ��ĺ��������
; ʹ���� lib16 �����ĺ���

FUNCTION_IMPORT_TABLE:

puts:                   jmp LIB16_SEG + LIB16_PUTS * 3
putc:                   jmp LIB16_SEG + LIB16_PUTC * 3
get_hex_string:         jmp LIB16_SEG + LIB16_GET_HEX_STRING * 3
test_CPUID:             jmp LIB16_SEG + LIB16_TEST_CPUID * 3
get_dword_hex_string:   jmp LIB16_SEG + LIB16_GET_DWORD_HEX_STRING * 3
println                 jmp LIB16_SEG + LIB16_PRINTLN * 3


SETUP_END:

; end of setup        