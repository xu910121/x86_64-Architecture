; protected.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%define NON_PAGING
%include "..\inc\support.inc"
%include "..\inc\protected.inc"

; ���� protected ģ��

        bits 32
        
        org PROTECTED_SEG - 2

PROTECTED_BEGIN:
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN                                ; protected ģ�鳤��

entry:
        
;; ���� #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler        

;; ���� #DB handler
        mov esi, DB_HANDLER_VECTOR
        mov edi, DB_handler
        call set_interrupt_handler

;; ���� #AC handler
        mov esi, AC_HANDLER_VECTOR
        mov edi, AC_handler
        call set_interrupt_handler

;; ���� #UD handler
        mov esi, UD_HANDLER_VECTOR
        mov edi, UD_handler
        call set_interrupt_handler
                
;; ���� #NM handler
        mov esi, NM_HANDLER_VECTOR
        mov edi, NM_handler
        call set_interrupt_handler
        
;; ���� #TS handler
        mov esi, TS_HANDLER_VECTOR
        mov edi, TS_handler
        call set_interrupt_handler

;; ���� TSS �� ESP0        
        mov esi, tss32_sel
        call get_tss_base
        mov DWORD [eax + 4], KERNEL_ESP
        
;; �ر����� 8259�ж�
        call disable_8259

;======================================================



;; ������ TSS ����
        mov esi, tss_sel
        call get_tss_base
        mov DWORD [eax + 32], tss_task_handler                ; ���� EIP ֵΪ tss_task_handler
        mov DWORD [eax + 36], 0                               ; eflags = 0
        mov DWORD [eax + 56], KERNEL_ESP                      ; esp
        mov WORD [eax + 76], KERNEL_CS                        ; cs
        mov WORD [eax + 80], KERNEL_SS                        ; ss
        mov WORD [eax + 84], KERNEL_SS                        ; ds
        mov WORD [eax + 72], KERNEL_SS                        ; es


;; ���� Task-gate ������
        mov esi, taskgate_sel                                 ; Task-gate selector
        mov eax, tss_sel << 16
        mov edx, 0E500h                                       ; DPL=3, type=Task-gate
        call write_gdt_descriptor
        

        
; ת�� long ģ��
        ;jmp LONG_SEG
        
                                        
; ���� ring 3 ����
        push DWORD user_data32_sel | 0x3
        push esp
        push DWORD user_code32_sel | 0x3        
        push DWORD user_entry
        retf

        
;; �û�����

user_entry:
        mov ax, user_data32_sel
        mov ds, ax
        mov es, ax

;; ʹ�� Task-gate���������л�
        call taskgate_sel : 0
        
        mov esi, msg1
        call puts                        ; ���û��������ӡ��Ϣ

        jmp $
msg1                db '---> now, switch back to old task', 10, '---> now, enter user code', 10, 0





;-----------------------------------------
; tss_task_handler()
;-----------------------------------------
tss_task_handler:
        jmp do_tss_task
tmsg1        db '---> now, switch to new Task with Task-gate', 10, 0        
do_tss_task:
        mov esi, tmsg1
        call puts
        
        clts                                                ; �� CR0.TS ��־λ
        

; ʹ�� iret ָ���л���ԭ task
        iret        
   






;******** include �ж� handler ���� ********
%include "..\common\handler32.asm"


;********* include ģ�� ********************
%include "..\lib\creg.asm"
%include "..\lib\cpuid.asm"
%include "..\lib\msr.asm"
%include "..\lib\pci.asm"
%include "..\lib\debug.asm"
%include "..\lib\page32.asm"
%include "..\lib\apic.asm"
%include "..\lib\pic8259A.asm"


;;************* ���������  *****************

; ��� lib32 �⵼������ common\ Ŀ¼�£�
; ������ʵ��� protected.asm ģ��ʹ��

%include "..\common\lib32_import_table.imt"



PROTECTED_END: