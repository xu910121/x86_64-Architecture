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



; 1) ����APIC
        call enable_xapic        
        
; 2) ���� APIC performance monitor counter handler
        mov esi, APIC_PERFMON_VECTOR
        mov edi, apic_perfmon_handler
        call set_interrupt_handler
        
        
; ���� LVT performance monitor counter
        mov DWORD [APIC_BASE + LVT_PERFMON], FIXED_DELIVERY | APIC_PERFMON_VECTOR
        

;*
;* ʵ�� ex15-9�����PMI�жϴ����Ĵ���
;*
        
        call available_pebs                             ; ���� pebs �Ƿ����
        test eax, eax
        jz next                                         ; ������

        ;*
        ;* perfmon ��ʼ����
        ;* �ر����� counter �� PEBS 
        ;* �� overflow ��־λ
        ;*
        DISABLE_GLOBAL_COUNTER
        DISABLE_PEBS
        RESET_COUNTER_OVERFLOW


; ���������� DS ����BTS buffer��ʱ�ж�
        SET_INT_DS_AREA

;*
;* ���� PEBS buffer
;* ֻ������ 1 �� PEBS ��¼
;*
        mov esi, 1
        call set_pebs_buffer_size

; ���� counter ����ֵ        
        mov ecx, IA32_PMC0
        mov eax, 0FFFFFFFFh - 9
        mov edx, 0
        wrmsr
        
; ���� IA32_PERFEVTSEL0 �Ĵ���, ��������
        mov ecx, IA32_PERFEVTSEL0
        mov eax, PEBS_INST_COUNT_EVENT                       ; ͳ��ָ����
        mov edx, 0
        wrmsr

;* ���� BTS, PEBS �Լ� counter
        ENABLE_BTS_BTINT_FREEZE_PERFMON_ON_PMI
        ENABLE_PEBS_PMC0
        ENABLE_IA32_PMC0

        jmp l1
l1:     jmp l2
l2:     jmp l3
l3:     jmp l4
l4:     jmp l5
l5:     jmp l6
l6:     jmp l7
l7:     jmp l8
l8:     jmp l9
l9:     jmp l10
l10:    jmp l11
l11:

; �ر� counter, PEBS �Լ� BTS
        DISABLE_IA32_PMC0
        DISABLE_PEBS_PMC0
        DISABLE_BTS_BTINT_FREEZE_PERFMON_ON_PMI

next:        
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


;*
;* ʹ�� common\handler32.asm ��� apic_perfmon_handler����
;*
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