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
        call disable_keyboard
        call disable_timer
        sti
        
;========= ��ʼ��������� =================


;*
;* ʵ�� ex14-11������BTS buffer�Ĺ��˹���
;*

; 1) ����APIC
        call enable_xapic        
        
; 2) ���� APIC performance monitor counter handler
        mov esi, APIC_PERFMON_VECTOR
        mov edi, apic_perfmon_handler
        call set_interrupt_handler
        
        
; ���� LVT performance monitor counter
        mov DWORD [APIC_BASE + LVT_PERFMON], FIXED_DELIVERY | APIC_PERFMON_VECTOR
        
        call available_bts                                ; ���� bts �Ƿ����
        test eax, eax
        jz next                                           ; ������


; �������� DS ���򣨻��� BTS buffer��
        SET_DS_AREA

        
; * ע���û��жϷ�������
; * �ҽ��� system_service_table ����

        mov esi, USER_ENABLE_BTS                        ; ���ܺ�
        mov edi, user_enable_bts                        ; �Զ�������
        call set_system_service_table

        mov esi, USER_DISABLE_BTS                        ; ���ܺ�
        mov edi, user_disable_bts                        ; �Զ������� 
        call set_system_service_table
                
        mov esi, USER_DUMP_BTS                           ; ���ܺ�
        mov edi, user_dump_bts                           ; �Զ�������
        call set_system_service_table
        
; ���� ring 3 ����
        push DWORD user_data32_sel | 0x3
        push DWORD USER_ESP
        push DWORD user_code32_sel | 0x3        
        push DWORD user_entry
        retf


;; **********************************        
;; �������û����루CPL = 3)
;; **********************************

user_entry:
        mov ax, user_data32_sel
        mov ds, ax
        mov es, ax

user_start:
        
        ; ���� BTS
        mov eax, USER_ENABLE_BTS
        int SYSTEM_SERVICE_VECTOR

        ; ��ӡ������Ϣ
        mov esi, msg
        mov eax, SYS_PUTS
        int SYSTEM_SERVICE_VECTOR
        
        ; �ر� BTS
        mov eax, USER_DISABLE_BTS
        int SYSTEM_SERVICE_VECTOR

        ; ��ӡ BTS
        mov eax, USER_DUMP_BTS
        int SYSTEM_SERVICE_VECTOR

        
next:
        jmp $


;; ���� 3 ���û��жϷ������̺�
;; ��Ӧ�� user_enable_bts(), user_dislable_bts() �Լ� user_dump_bts()

USER_ENABLE_BTS         equ SYSTEM_SERVICE_USER0
USER_DISABLE_BTS        equ SYSTEM_SERVICE_USER1
USER_DUMP_BTS           equ SYSTEM_SERVICE_USER2


;------------------------
; ���û����￪�� BTS ����
;-------------------------
user_enable_bts:
        ;*
        ;* �ر��� OS kernel ��� BTS ��¼
        ;* ʹ�û��� BTS buffer
        ;*
        mov ecx, IA32_DEBUGCTL
        mov edx, 0
        mov eax, 2C0h                ; TR=1, BTS=1, BTS_OFF_OS=1
        wrmsr
        ret

;--------------------------
; ���û�����ر� BTS ����
;-------------------------
user_disable_bts:
        mov ecx, IA32_DEBUGCTL
        rdmsr
        btr eax, TR_BIT                ; TR = 0
        wrmsr
        ret

;--------------------------
; ���û����ӡ BTS buffer
;--------------------------
user_dump_bts:
        call dump_ds_management
        call dump_bts_record
        ret



;;; ���Ժ���
foo:
        mov esi, msg
        call puts                        ; ��ӡһ����Ϣ
        ret


msg        db 'hi, message from User...', 10, 10, 0




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


;;************* ���������  *****************

; ��� lib32 �⵼������ common\ Ŀ¼�£�
; ������ʵ��� protected.asm ģ��ʹ��

%include "..\common\lib32_import_table.imt"


PROTECTED_END: