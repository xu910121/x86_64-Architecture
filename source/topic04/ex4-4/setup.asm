; setup.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


; ����һ���հ�ģ��ʾ������Ϊ setup ģ��
; ����д����̵ĵ� 2 ������ ��
;

%include "..\inc\support.inc"

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
        mov si, [message_table + eax * 2]
        call puts
        call println
        
        mov si, eax_msg
        call puts        
        mov eax, 01H
        cpuid
        mov esi, eax
        mov di, value_address
        call get_dword_hex_string
        mov si, value_address
        call puts
        call println
        call get_DisplayFamily_DisplayModel
        mov ebx, eax
        mov si, display_family_msg
        call puts
        mov esi, ebx
        shr esi, 8
        mov di, value_address
        call get_hex_string
        mov si, value_address
        call puts
        call println
        mov si, display_model_msg
        call puts
        mov esi, ebx
        and esi, 0xff
        mov di, value_address
        call get_hex_string
        mov si, value_address
        call puts
        
                
        jmp $

display_family_msg      db 'DisplayFamily: 0x', 0
display_model_msg       db 'DisplayModel: 0x', 0
value_address           dd 0 ,0, 0

eax_msg                 db '<eax>: 0x', 0

support_message         db 'support CPUID instruction', 13, 10, 0
no_support_message      db 'no support CPUID instruction', 13, 10, 0                
message_table           dw no_support_message, support_message, 0

;
; ���������ģ��ĺ��������
; ʹ���� lib16 �����ĺ���

FUNCTION_IMPORT_TABLE:

puts:                           jmp LIB16_SEG + LIB16_PUTS * 3
putc:                           jmp LIB16_SEG + LIB16_PUTC * 3
get_hex_string:                 jmp LIB16_SEG + LIB16_GET_HEX_STRING * 3
test_CPUID:                     jmp LIB16_SEG + LIB16_TEST_CPUID * 3
get_dword_hex_string:           jmp LIB16_SEG + LIB16_GET_DWORD_HEX_STRING * 3
println                         jmp LIB16_SEG + LIB16_PRINTLN * 3
get_DisplayFamily_DisplayModel: jmp LIB16_SEG + LIB16_GET_DISPLAYFAMILY_DISPLAYMODEL * 3


SETUP_END:

; end of setup        