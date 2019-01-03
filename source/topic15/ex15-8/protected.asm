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
;* ʵ�� ex15-8������PMI�ж���PEBS�ж�ͬʱ����
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
        SET_DS_AREA


; ���� BTS ��ʹ�� PMI ���Ṧ��
        ENABLE_BTS_FREEZE_PERFMON_ON_PMI                ; TR=1, BTS=1, BTINT=1


; �������� counter ����ֵ        
        mov esi, IA32_PMC0                              ; ���� IA32_PMC0
        call write_counter_maximum
        mov esi, IA32_PMC1                              ; ���� IA32_PMC1
        call write_counter_maximum
        

; �������� IA32_PERFEVTSEL0 �Ĵ���, ��������
        mov ecx, IA32_PERFEVTSEL0                       ; counter 0                       
        mov eax, INST_COUNT_EVENT
        mov edx, 0
        wrmsr
        mov ecx, IA32_PERFEVTSEL1                       ; counter 1
        mov eax, PEBS_INST_COUNT_EVENT
        mov edx, 0
        wrmsr
 
; ���� PEBS
        ;*
        ;* ����һ: IA32_PMC0 ʹ�� PMI ������IA32_PMC1 ʹ�� PEBS ����
        ;*
;        ENABLE_PEBS_PMC1

        ;*
        ;* ���Զ�: IA32_PMC0 ʹ�� PEBS ������IA32_PMC1 ʹ�� PMI ����
        ;*
        ENABLE_PEBS_PMC0

; ͬʱ������������������ʼ����
        ENABLE_COUNTER (IA32_PMC0_EN | IA32_PMC1_EN), 0

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


; �ر�����������
        DISABLE_COUNTER (IA32_PMC0_EN | IA32_PMC1_EN), 0

; �ر� PEBS ����
        DISABLE_PEBS_PMC1

; �ر� BTS
        DISABLE_BTS_FREEZE_PERFMON_ON_PMI                ; TR=0, BTS=0

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



;* ʹ�� ..\common\handler32.asm ����� apic_perfmon_handler ���� *
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