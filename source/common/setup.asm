; setup.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


; ����һ���հ�ģ��ʾ������Ϊ setup ģ��
; ����д����̵ĵ� 2 ������ ��
;

%include "..\inc\support.inc"
%include "..\inc\protected.inc"

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

        cli
        
        db 0x66
        lgdt [__gdt_pointer]                      ; ���� GDT
        
        db 0x66
        lidt [__idt_pointer]                      ; ���� IDT

;;���� TSS 
        mov WORD [tss32_desc], 0x68 + __io_bitmap_end - __io_bitmap
        mov WORD [tss32_desc + 2], __task_status_segment
        mov BYTE [tss32_desc + 5], 0x80 | TSS32
        
;; �������ڲ��Ե� TSS
        mov WORD [tss_test_desc], 0x68 + __io_bitmap_end - __io_bitmap
        mov WORD [tss_test_desc + 2], __test_tss
        mov BYTE [tss_test_desc + 5], 0x80 | TSS32        

;; ���� LDT 
        mov WORD [ldt_desc], __local_descriptor_table_end - __local_descriptor_table - 1        ; limit
        mov DWORD [ldt_desc + 4], __local_descriptor_table              ; base [31:24]
        mov DWORD [ldt_desc + 2], __local_descriptor_table              ; base [23:0]
        mov WORD [ldt_desc + 5], 80h | LDT_SEGMENT                      ; DPL=0, type=LDT


        mov eax, cr0
        bts eax, 0                              ; CR0.PE = 1
        mov cr0, eax
        
        jmp kernel_code32_sel:entry32                                                
        


;;; ������ 32 λ protected ģʽ����
        
        bits 32

entry32:
        mov ax, kernel_data32_sel               ; ���� data segment
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov esp, 0x7ff0        

;; load TSS segment
        mov ax, tss32_sel
        ltr ax
                
        jmp PROTECTED_SEG                        
                
  
     
;*        
;* ���¶��� protected mode �� GDT �� segment descriptor
;*
__global_descriptor_table:

null_desc                       dq 0                    ; NULL descriptor

code16_desc                     dq 0x00009a000000ffff   ; base=0, limit=0xffff, DPL=0                
data16_desc                     dq 0x000092000000ffff   ; base=0, limit=0xffff, DPL=0
kernel_code32_desc              dq 0x00cf9a000000ffff   ; non-conforming, DPL=0, P=1
kernel_data32_desc              dq 0x00cf92000000ffff   ; DPL=0, P=1, writeable, expand-up
user_code32_desc                dq 0x00cff8000000ffff   ; non-conforming, DPL=3, P=1
user_data32_desc                dq 0x00cff2000000ffff   ; DPL=3, P=1, writeable, expand-up

tss32_desc                      dq 0
call_gate_desc                  dq 0
conforming_code32_desc          dq 0x00cf9e000000ffff   ; conforming, DPL=0, P=1
tss_test_desc                   dq 0
task_gate_desc                  dq 0
ldt_desc                        dq 0
                       times 10 dq 0                    ; ���� 10 ��
__global_descriptor_table_end:


; ���¶��� protected mode �� IDT entry
__interrupt_descriptor_table:
        times 0x80 dq 0                                ; ���� 0x80 �� vector
__interrupt_descriptor_table_end:


__local_descriptor_table:
        times 10 dq 0
__local_descriptor_table_end:

;*
;* ���¶��� TSS �νṹ
;*
__task_status_segment:
        dd 0                
        dd PROCESSOR0_KERNEL_ESP        ; esp0
        dd kernel_data32_sel            ; ss0
        dq 0                            ; ss1/esp1
        dq 0                            ; ss2/esp2
times 19 dd 0        
        dw 0
        ;*** ������ IOBITMAP ƫ������ַ ***
        dw __io_bitmap - __task_status_segment

__task_status_segment_end:


;*** ������ TSS ��
__test_tss:
        dd 0                
        dd 0x8f00                       ; esp0
        dd kernel_data32_sel            ; ss0
        dq 0                            ; ss1/esp1
        dq 0                            ; ss2/esp2
times 19 dd 0        
        dw 0
        ;*** ������ IOBITMAP ƫ������ַ ***
        dw __io_bitmap - __test_tss
__test_tss_end:



;; Ϊ IO bit map ���� 10 bytes��IO space �� 0 - 80��
__io_bitmap:
        times 10 db 0        
__io_bitmap_end:



; ���� GDT pointer
__gdt_pointer:
gdt_limit       dw      (__global_descriptor_table_end - __global_descriptor_table) - 1
gdt_base        dd      __global_descriptor_table


; ���� IDT pointer
__idt_pointer:
idt_limit       dw      (__interrupt_descriptor_table_end - __interrupt_descriptor_table) - 1
idt_base        dd       __interrupt_descriptor_table


;; ����ʵģʽ��  IVT pointer
__ivt_pointer:
                dw 3FFH
                dd 0
                



;
; ���������ģ��ĺ��������
; ʹ���� lib16 �����ĺ���


FUNCTION_IMPORT_TABLE:

puts:                   jmp LIB16_SEG + LIB16_PUTS * 3
putc:                   jmp LIB16_SEG + LIB16_PUTC * 3
get_hex_string:         jmp LIB16_SEG + LIB16_GET_HEX_STRING * 3
test_CPUID:             jmp LIB16_SEG + LIB16_TEST_CPUID * 3
clear_screen:           jmp LIB16_SEG + LIB16_CLEAR_SCREEN * 3

puts32:                 jmp LIB32_SEG + LIB32_PUTS * 5
get_dword_hex_string:   jmp LIB32_SEG + LIB32_GET_DWORD_HEX_STRING * 5        
println                 jmp LIB32_SEG + LIB32_PRINTLN * 5
print_value             jmp LIB32_SEG + LIB32_PRINT_VALUE * 5



SETUP_END:

; end of setup        