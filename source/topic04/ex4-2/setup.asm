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

;; ������ basic ���ܺ�
        mov eax, 0
        cpuid
        mov esi, eax
        mov di, value_address
        call get_dword_hex_string
        mov si, basic_message
        call puts
        mov si, value_address
        call puts
        call println
        
;; ������ extended ���ܺ�        
        mov eax, 0x80000000
        cpuid
        mov esi, eax
        mov di, value_address
        call get_dword_hex_string
        mov si, extend_message
        call puts
        mov si, value_address
        call puts        
        call println
        
        jmp $
        
no_support:        
        mov si, [message_table + eax * 2]
        call puts
        jmp $
        

support_message         db 'support CPUID instruction', 13, 10, 0
no_support_message      db 'no support CPUID instruction', 13, 10, 0                
message_table           dw no_support_message, support_message, 0

basic_message           db 'maximun basic function: 0x', 0
extend_message          db 'maximun extended function: 0x', 0
value_address           dd 0, 0, 0


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