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
                  
                
        
;; ʵ�� 13-3: ���� general detect �� single-step

; 1) ���� DR7.GD λ
        mov eax, dr7
        bts eax, 13                     ; GD=1
        mov dr7, eax

; 2���� TF=1        
        pushfd
        bts DWORD [esp], 8
        popfd

; 3) ���� general detect        
        ;mov eax, dr6                    ; 1) �ȴ��� general detect ����
                                         ; 2) ���Ŵ��� single-step ����

;; ���Զ���
        mov eax, eax                     ; ��������ָ����� single-step ������
        mov eax, dr6                     ; ͬʱ���� single-step �� general detect
        
        jmp $


        
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


;--------------------------------
; #DB handler
;--------------------------------
debug_handler:
        jmp do_debug_handler
debug_msg        db '---> now, enter #debug handler <---', 10, 0

do_debug_handler:        
        mov esi, debug_msg
        call puts
        call dump_dr6                     ; ��ӡ DR6 �Ĵ�����־λ
        mov eax, [esp]
        cmp WORD [eax], 0xfeeb              ; ���� jmp $ ָ��
        jne do_debug_handler_done
        btr DWORD [esp+8], 8                ; �� TF
do_debug_handler_done:        
        bts DWORD [esp+8], 16               ; RF=1
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