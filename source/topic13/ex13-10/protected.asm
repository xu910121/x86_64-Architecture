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
        
;; �ر�8259
        call disable_8259

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
        mov edi, debug_handler
        call set_interrupt_handler


;; ���� sysenter/sysexit ʹ�û���
        call set_sysenter

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
                  
                
        
; ���õ�ǰ�� TSS��
        call get_tr_base
        mov DWORD [eax + 28], PDPT_BASE          ; ���� CR3�л�����
        
;; ������ TSS ����
        mov esi, tss_sel
        call get_tss_base
        mov DWORD [eax+28], PDPT_BASE                           ; ���� CR3
        mov DWORD [eax + 32], tss_task_handler                  ; ���� EIP ֵΪ tss_task_handler
        mov DWORD [eax + 36], 0x02                              ; eflags = 2H
        mov DWORD [eax + 56], KERNEL_ESP                        ; esp
        mov WORD [eax + 76], KERNEL_CS                          ; cs
        mov WORD [eax + 80], KERNEL_SS                          ; ss
        mov WORD [eax + 84], KERNEL_SS                          ; ds
        mov WORD [eax + 72], KERNEL_SS                          ; es
        bts WORD [eax + 100], 0                                 ; �� T = 1
        
;; ���潫 TSS selector �� DPL ��Ϊ 3 ��
        mov esi, tss_sel
        call read_gdt_descriptor
        or edx, 0x6000                                          ; TSS desciptor DPL = 3
        mov esi, tss_sel
        call write_gdt_descriptor
        
                      
                                
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

; ʹ�� TSS ���������л�        
        call tss_sel:0        
        
        jmp $



;-----------------------------------------
; tss_task_handler()
;-----------------------------------------
tss_task_handler:
        jmp do_tss_task
tmsg1        db 10, 10, '---> now, switch to new Task, ', 0        
tmsg2        db 'CPL:', 0
do_tss_task:
        mov esi, tmsg1
        call puts

; ��� CPL ֵ        
        mov esi, tmsg2
        call puts
        CLIB32_GET_CPL_CALL
        mov esi, eax
        call print_byte_value
        call println
                
        clts                            ; �� CR0.TS ��־λ
; ʹ�� iret ָ���л���ԭ task
        iret



;--------------------------------
; #DB handler
;--------------------------------
debug_handler:
        jmp do_debug_handler
dh_msg1 db '>>> now: enter #DB handler', 10, 0
dh_msg2 db 'new, exit #DB handler <<<', 10, 0
do_debug_handler:
        mov esi, dh_msg1
        call puts
        call dump_drs
        call dump_dr6
        call dump_dr7
        mov eax, [esp]
        cmp WORD [eax], 0xfeeb              ; ���� jmp $ ָ��
        jne do_debug_handler_done
        btr DWORD [esp+8], 8                ; �� TF
do_debug_handler_done:        
        bts DWORD [esp+8], 16               ; RF=1
        mov esi, dh_msg2
        call puts
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