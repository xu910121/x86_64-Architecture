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

setup_length        dw (SETUP_END - SETUP_BEGIN)        ; SETUP_END-SETUP_BEGIN �����ģ��� size


main:                                                   ; ����ģ��������ڵ㡣
        
        mov si, caller_message
        call puts                       ; printf("'Now: I am the caller, address is 0x%x", get_hex_string(current_eip));
        mov si, current_eip        
        mov di, caller_address
current_eip:        
        call get_hex_string
        mov si, caller_address                                        
        call puts
        
        mov si, 13                      ; ��ӡ�س�
        call putc
        mov si, 10                      ; ��ӡ����
        call putc
        
        call say_hello
        
        jmp $        


caller_message  db 'Now: I am the caller, address is 0x'
caller_address  dq 0

hello_message   db 13, 10, 'hello,world!', 13,10
                db 'This is my first assembly program...', 13, 10, 13, 10, 0
callee_message  db "Now: I'm callee - say_hello(), address is 0x"
callee_address  dq 0                                


;-------------------------------------------
; say_hello()
;-------------------------------------------
say_hello:
        mov si, hello_message
        call puts                       ; printf("hello,world\nThis is my first assembly program...");
        
        mov si, callee_message          ; printf("Now: I'm callee - say_hello(), address is 0x%x", get_hex_string(say_hello));
        call puts
        
        mov si, say_hello                                                        
        mov di, callee_address
        call get_hex_string
        
        mov si, callee_address
        call puts
        ret



;
; ���������ģ��ĺ��������
; ʹ���� lib16 �����ĺ���

FUNCTION_IMPORT_TABLE:

puts:           jmp LIB16_SEG + LIB16_PUTS * 3
putc:           jmp LIB16_SEG + LIB16_PUTC * 3
get_hex_string: jmp LIB16_SEG + LIB16_GET_HEX_STRING * 3



SETUP_END:

; end of setup        