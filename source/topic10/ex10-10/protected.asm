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
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN      ; protected ģ�鳤��

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
        
;; ���� #OF handler
        mov esi, OF_HANDLER_VECTOR
        mov edi, OF_handler
        call set_user_interrupt_handler
        
;; ���� #BP handler
        mov esi, BP_HANDLER_VECTOR
        mov edi, BP_handler
        call set_user_interrupt_handler        

;; ����  #BR handler
        mov esi, BR_HANDLER_VECTOR
        mov edi, BR_handler
        call set_user_interrupt_handler        


;; ����ϵͳ�����������
        mov esi, SYSTEM_SERVICE_VECTOR
        mov edi, system_service
        call set_user_interrupt_handler
        
;; ���� TSS �� ESP0        
        mov esi, tss32_sel
        call get_tss_base
        mov DWORD [eax + 4], KERNEL_ESP

; ����ִ�� SSE ָ��	
	mov eax, cr4
	bts eax, 9				; CR4.OSFXSR = 1
	mov cr4, eax

;���� CR4.PAE
	call pae_enable
	
; ���� XD ����
	call execution_disable_enable


;; �ر����� 8259�ж�
        call disable_8259

;============================================


        
; ת�� long ģ��
        jmp LONG_SEG
        
                                        
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

;; ���� INTO ָ�� 
        mov eax, 0x80000000
        mov ebx, eax
        add eax, ebx                                      ; ���������OF��־��λ
        into                                              ; ���� #OF �쳣


;; �ϵ���Ե�ʹ��
        mov al, [breakpoint]                               ; ����ԭ�ֽ�
        mov BYTE [breakpoint], 0xcc                        ; д�� int3 ָ��
        
breakpoint:
        mov esi, msg1                                      ; ���Ƕϵ�λ�ã����� #BP �쳣
        call puts

;; ���� bound ָ��
        mov eax, 0x8000                                     ; ���ֵ��Խ��
        bound eax, [bound_rang]                             ; ���� #BR �쳣

        mov esi, msg2
        call puts
        
        jmp $

bound_rang        dd        10000h                      ; �����ķ�Χ�� 10000h �� 20000h
                  dd        20000h
                        
msg1        db  'Fixed the Breakpoint, OK!', 10, 0
msg2        db   'Fixed the Bound Error OK!', 10, 0







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