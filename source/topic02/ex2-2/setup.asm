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

setup_length    dw (SETUP_END - SETUP_BEGIN)    ; SETUP_END-SETUP_BEGIN �����ģ��� size


main:                                           ; ����ģ��������ڵ㡣


        les ax, [far_pointer]                   ; get far pointer(16:16)

current_eip:
        mov si, ax
        mov di, address
        call get_hex_string
        mov si, message
        call puts
        
        jmp $        


far_pointer:
        dw current_eip                          ; offset 16
        dw 0                                    ; segment 16


message db 'current ip is 0x',
address dq 0, 0



;
; ���������ģ��ĺ��������
; ʹ���� lib16 �����ĺ���

FUNCTION_IMPORT_TABLE:

puts:           jmp LIB16_SEG + LIB16_PUTS * 3
putc:           jmp LIB16_SEG + LIB16_PUTC * 3
get_hex_string: jmp LIB16_SEG + LIB16_GET_HEX_STRING * 3



SETUP_END:

; end of setup        