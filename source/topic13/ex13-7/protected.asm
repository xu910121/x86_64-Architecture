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
                  
                
        
;; ʵ�� 13-7���������ݶϵ�

;1) �������ݶϵ� enable λ
        mov eax, dr7
        or eax, 0x70001                                     ; L0=1, R/W0=11B, LEN0=01B
        mov dr7, eax

;2) ���öϵ��ַ
        mov eax, 0x400003
        mov dr0, eax

; 3) ���ϵ�
        mov esi, msg
        call puts
        mov esi, msg1
        call puts
        mov ax, [0x400000]                                ; 1
        call println
        mov esi, msg2
        call puts
        mov ax, [0x400001]                                ; 2
        call println
        mov esi, msg3
        call puts
        mov al, [0x400001]                                ; 3
        call println
        mov esi, msg4
        call puts
        mov ax, [0x400002]                                ; 4
        call println
        mov esi, msg5
        call puts
        mov eax, [0x400003]                                ; 5
        call println

        
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

msg     db '**** DR0=0x400003, R/W0=11B, LEN0=01B ****', 10, 10, 0
msg1    db 'MOV ax  [0x400000]', 0
msg2    db 'MOV ax  [0x400001]', 0
msg3    db 'MOV al  [0x400001]', 0
msg4    db 'MOV ax  [0x400002]', 0
msg5    db 'MOV eax [0x400003]', 0



;--------------------------------
; #DB handler
;--------------------------------
debug_handler:
	jmp do_debug_handler
dh_msg1	db ' ---> occur #DB exception !',0
do_debug_handler:
	mov esi, dh_msg1
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