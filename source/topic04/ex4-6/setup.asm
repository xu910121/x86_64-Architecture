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


setup_length    dw (SETUP_END - SETUP_BEGIN)    ; SETUP_END-SETUP_BEGIN �����ģ��� size


setup_entry:                                    ; ����ģ��������ڵ㡣
        
        
        call test_CPUID
        test ax, ax
        jz no_support
        
        mov eax, 02
        cpuid
        
        mov [eax_value], eax
        mov [ebx_value], ebx
        mov [ecx_value], ecx
        mov [edx_value], edx
        
        call print_register_value

        ;call print_cpu_clflush
        ;call print_cpu_model
        
        


        jmp $
        
no_support:        
        mov si, [message_table + eax * 2]
        call puts
        jmp $


eax_value               dd 0        
eax_message             db 'eax: 0x', 0
ebx_value               dd 0
ebx_message             db 'ebx: 0x', 0
ecx_value               dd 0
ecx_message             db 'ecx: 0x', 0
edx_value               dd 0
edx_message             db 'edx: 0x', 0

value_address           dd 0, 0, 0

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
        
register_value_message  db '---- Register Value Information ----', 13, 10, 0        
register_table          dw eax_value, ebx_value, ecx_value, edx_value, 0
        
do_print_register_value:
        mov si, register_value_message
        call puts
                
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

;------------------------------------
; print_cpu_model()
;-----------------------------------
print_cpu_model:
        jmp do_print_cpu_model
@message        db '---- Processor Model Information ----', 13, 10, 0
model           db 'Model: 0x', 0
family          db 'Family: 0x', 0
stepping        db 'Stepping: 0x', 0
type            db 'Processor Type: 0x', 0
extended_model  db 'Extended Model ID: 0x', 0
extended_family db 'Extended Family ID: 0x',0

do_print_cpu_model:
        mov si, @message
        call puts
        
        mov eax, [eax_value]
        mov esi, eax
        and esi, dword 0xf0
        shr esi, 4
        mov di, value_address
        call get_hex_string
        mov si, model
        call puts
        mov si, value_address
        call puts
        call println
        
        mov esi, eax
        and esi, dword 0xf00
        shr esi, 8
        mov di, value_address
        call get_hex_string
        mov si, family
        call puts
        mov si, value_address
        call puts
        call println        

        mov esi, eax
        and esi, dword 0x0f
        mov di, value_address
        call get_hex_string
        mov si, stepping
        call puts
        mov si, value_address
        call puts
        call println        

        mov esi, eax
        and esi, dword 0x3000
        shr esi, 12
        mov di, value_address
        call get_hex_string
        mov si, type
        call puts
        mov si, value_address
        call puts
        call println        
        ret


;------------------------------------
; print_cpu_model()
;-----------------------------------
print_cpu_clflush:
        jmp do_print_cpu_clflush
cpu_clflush_message     db '---- Cache line size & logic processors number ----', 13, 10, 0
clflush_line_size       db 'Cache line size(bytes): 0x', 0
maximum_core            db 'Logic processor: 0x',  0

do_print_cpu_clflush:
        mov si, cpu_clflush_message
        call puts
        mov ebx, [ebx_value]
        mov esi, ebx
        and esi, dword 0xf00
        shr esi, 8
        lea esi, [esi*8]
        mov di, value_address
        call get_hex_string
        mov si, clflush_line_size 
        call puts
        mov si, value_address
        call puts
        call println
        mov esi, ebx
        and esi, dword 0xf0000
        shr esi, 16
        mov di, value_address
        call get_hex_string
        mov si, maximum_core
        call puts
        mov si, value_address
        call puts
        call println
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