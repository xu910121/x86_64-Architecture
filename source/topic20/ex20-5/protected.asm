; protected.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\support.inc"
%include "..\inc\protected.inc"

; ���� protected ģ��

        bits 32
        
        org PROTECTED_SEG - 2

PROTECTED_BEGIN:
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN       ; protected ģ�鳤��

entry:
        
;; Ϊ�����ʵ�飬�ر�ʱ���жϺͼ����ж�
        call disable_timer
        
;; ���� #PF handler
        mov esi, PF_HANDLER_VECTOR
        mov edi, PF_handler
        call set_interrupt_handler        

;; ���� #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler

; ���� #DB handler
        mov esi, DB_HANDLER_VECTOR
        mov edi, DB_handler
        call set_interrupt_handler


;; ���� sysenter/sysexit ʹ�û���
        call set_sysenter

;; ���� system_service handler
        mov esi, SYSTEM_SERVICE_VECTOR
        mov edi, system_service
        call set_user_interrupt_handler 

; ����ִ�� SSE ָ��        
        mov eax, cr4
        bts eax, 9                                ; CR4.OSFXSR = 1
        mov cr4, eax
        
        
;���� CR4.PAE
        call pae_enable
        
; ���� XD ����
        call execution_disable_enable
                
; ��ʼ�� paging ����
        call init_pae_paging
        
;���� PDPT ���ַ        
        mov eax, PDPT_BASE
        mov cr3, eax
                                
; �򿪡�paging
        mov eax, cr0
        bts eax, 31
        mov cr0, eax                                 

        mov esi, PIC8259A_TIMER_VECTOR
        mov edi, timer_handler
        call set_interrupt_handler        

        mov esi, KEYBOARD_VECTOR
        mov edi, keyboard_handler
        call set_interrupt_handler                
        
        call init_8259A
        call init_8253        
;        call disable_8259
        call disable_timer
        call disable_keyboard
        sti
        
;========= ��ʼ��������� =================


;; ʵ�顡ex20-5������DOS compatibilityģʽ

        mov esi, FPU_VECTOR
        mov edi, fpu_handler
        call set_interrupt_handler

; δ���� CR0.NE λ��ʹ�� DOS compatibility ģʽ����
;        mov eax, cr0
;        bts eax, 5                        ; CR0.NE = 1
;        mov cr0, eax

        finit

       
; �� mask λ
        call clear_mask
        
        fld1
        fdiv DWORD [a]
        mov esi, msg
        call puts
        fst DWORD [result]        
        mov esi, msg1
        call puts
        mov esi, result
        call print_dword_float

        jmp $
                                
a       dd 3.0
result  dd 0
msg     db 'test DOS compatibility mode...', 10, 0
msg1    db '1/3 = ', 0
fh_msg1 db 10, '>>> now: enter floating-point exception handler, occur at 0x',  0
fh_msg2 db 'exit the floating-point exception handler <<<', 10, 10, 0

;-----------------------------------
; FPU ERROR (DOS compatibility)
;-----------------------------------
fpu_handler:
        push ebp
        mov ebp, esp
        sub esp, 32
        mov esi, fh_msg1
        call puts
        mov esi, [ebp + 4]
        call print_dword_value
        call println        
        
; �� IGNNE #        
        mov al, 00
        out 0xf0, al
        fstenv [esp]        
        fclex
        call dump_8259_isr       
        call dump_x87_status       
        call dump_data_register

; ��image��status �Ĵ���
        or WORD [esp], 0x3f              ;mask all
        and WORD [esp + 4], 0x7f00      ; ���쳣��־, B ��־
        fldenv [esp]

; EOI ����                
        call write_slave_EOI
        call write_master_EOI
        mov esi, fh_msg2
        call puts        
        mov esp, ebp
        pop ebp
        iret


; ת�� long ģ��
        ;jmp LONG_SEG
                                
                                
; ���� ring 3 ����
        push DWORD user_data32_sel | 0x3
        push DWORD USER_ESP
        push DWORD user_code32_sel | 0x3        
        push DWORD user_entry
        retf

        
;; �û�����

user_entry:
        mov ax, user_data32_sel
        mov ds, ax
        mov es, ax

user_start:

        jmp $






%define APIC_PERFMON_HANDLER

;******** include �ж� handler ���� ********
%include "..\common\handler32.asm"


;********* include ģ�� ********************
%include "..\lib\creg.asm"
%include "..\lib\cpuid.asm"
%include "..\lib\msr.asm"
%include "..\lib\pci.asm"
%include "..\lib\apic.asm"
%include "..\lib\debug.asm"
%include "..\lib\perfmon.asm"
%include "..\lib\page32.asm"
%include "..\lib\pic8259A.asm"
%include "..\lib\x87.asm"

;;************* ���������  *****************

; ��� lib32 �⵼������ common\ Ŀ¼�£�
; ������ʵ��� protected.asm ģ��ʹ��

%include "..\common\lib32_import_table.imt"


PROTECTED_END: