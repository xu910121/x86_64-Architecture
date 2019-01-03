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

setup_length        dw (SETUP_END - SETUP_BEGIN)          ; SETUP_END-SETUP_BEGIN �����ģ��� size


setup_entry:                                             ; ����ģ��������ڵ㡣

        cli
        NMI_DISABLE
        
        db 0x66
        lgdt [GDT_POINTER]                               ; ���� GDT
        
        db 0x66
        lidt [IDT_POINTER]                               ; ���� IDT
        
        mov WORD [tss32_desc], 0x68 + IOBITMAP_END - IOBITMAP
        mov WORD [tss32_desc+2], TSS32_SEG
        mov BYTE [tss32_desc+5], 0x80 | TSS32
        

        mov eax, cr0
        bts eax, 0                                       ; CR0.PE = 1
        mov cr0, eax
        
        jmp kernel_code32_sel:entry32                                                
        


;;; ������ 32 λ protected ģʽ����
        
        bits 32

entry32:
        mov ax, kernel_data32_sel                       ; ���� data segment
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov esp, 0x7ff0        

;; load TSS segment
        mov ax, tss32_sel
        ltr ax
                
;; *** ʵ��: �� realģʽ��ʹ��4G���� ***
        mov si, msg1
        call puts32
        
;;; ������ 16 λ protected ģʽ����        

;; �л��� 16 λ
        jmp code16_sel:entry16                          ; ����16λ����ģʽ
        
        bits 16
entry16:        
        mov eax, cr0
        btr eax, 0
        mov cr0, eax         

;; �л��� real ģʽ                
        jmp 0:back_to_real

;;;  ������ real ģʽ
back_to_real:
        mov ax, cs
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov sp, 0x7ff0
        
;; �л���ʵģʽ�� IVT ��        
        lidt [IVT_POINTER]
        
        mov eax, LIB16_SEG + LIB16_CLEAR_SCREEN * 3
        call eax
        
        mov eax, LIB16_SEG + LIB16_PUTS * 3
        mov si, msg2
        call eax        
        
        mov eax, 2000000H
        mov DWORD [eax], 0x5A5AA5A5                      ; ����д 32M �ռ�
        mov esi, DWORD [eax]                             ; ��32M�ռ�
        mov edi, value_address
        mov eax, LIB16_SEG + LIB16_GET_DWORD_HEX_STRING * 3
        call eax
        
        mov si, msg3
        mov eax, LIB16_SEG + LIB16_PUTS * 3
        call eax
        
        jmp $
        
msg1                db 'Now: switch back to real from protected', 10, 0
msg2                db 'Now: back to real mode', 13, 10, 0
msg3                db 'write memory [2000000H] to: 0x'
value_address        dq 0, 0
        
        
; ���¶��� protected mode �� GDT �� segment descriptor

GDT:

null_desc                      dq 0                                 ; NULL descriptor
code16_desc                    dq 0x00009a000000ffff                ; base=0, limit=0xffff, DPL=0                
data16_desc                    dq 0x000092000000ffff                ; base=0, limit=0xffff, DPL=0
kernel_code32_desc             dq 0x00cf9a000000ffff                ; non-conforming, accessed, DPL=0, P=1
kernel_data32_desc             dq 0x00cf92000000ffff                ; DPL=0, P=1, writeable/accessed, expand-up
user_code32_desc               dq 0x00cffa000000ffff                ; non-conforming, accessed, DPL=3, P=1
user_data32_desc               dq 0x00cff2000000ffff                ; DPL=3, P=1, writeable/accessed, expand-up

tss32_desc                     dq 0
code16_sel                     equ  08h

GDT_END:

; ���¶��� protected mode �� IDT entry
IDT:
vector0                                 dq 0
vector1                                 dq 0
vector2                                 dq 0
vector3                                 dq 0
vector4                                 dq 0
vector5                                 dq 0
vector6                                 dq 0
vector7                                 dq 0
vector8                                 dq 0
vector9                                 dq 0                       ; reserved
vector10                                dq 0
vector11                                dq 0
vector12                                dq 0
vector13                                dq 0
vector14                                dq 0
vector15                                dq 0                      ; reserved
vector16                                dq 0
vector17                                dq 0
vector18                                dq 0
vector19                                dq 0
times 10                                dq 0                       ; 20-29: reserved
vector30                                dq 0
vector31                                dq 0                      ; reserved
IDT_END:


TSS32_SEG:
        dd 0                
        dd 0x8f00                    ; esp0
        dd kernel_data32_sel        ; ss0

times 22 dd 0        
         dw 0
IOBITMAP_ADDRESS        dw        IOBITMAP - TSS32_SEG
TSS32_END:


;; Ϊ IO bit map ���� 10 bytes��IO space �� 0 - 80��
IOBITMAP:
times        10 db 0        
IOBITMAP_END:


; ���� GDT pointer
GDT_POINTER:
GDT_LIMIT        dw        GDT_END - GDT
GDT_BASE         dd        GDT

; ���� IDT pointer
IDT_POINTER:
IDT_LIMIT        dw        IDT_END - GDT
IDT_BASE         dd        IDT

;; ����ʵģʽ��  IVT pointer
IVT_POINTER:        dw 3FFH
                    dd 0
                



;
; ���������ģ��ĺ��������
; ʹ���� lib16 �����ĺ���

        bits 16
FUNCTION_IMPORT_TABLE:

puts:                     jmp LIB16_SEG + LIB16_PUTS * 3
putc:                     jmp LIB16_SEG + LIB16_PUTC * 3
get_hex_string:           jmp LIB16_SEG + LIB16_GET_HEX_STRING * 3
test_CPUID:               jmp LIB16_SEG + LIB16_TEST_CPUID * 3
get_dword_hex_string:     jmp LIB16_SEG + LIB16_GET_DWORD_HEX_STRING * 3
println                   jmp LIB16_SEG + LIB16_PRINTLN * 3
clear_screen:             jmp LIB16_SEG + LIB16_CLEAR_SCREEN * 3

        bits 32
puts32                    jmp LIB32_SEG + LIB32_PUTS * 5


SETUP_END:

; end of setup        