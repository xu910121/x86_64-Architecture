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
        mov edi, perfmon_handler
        call set_interrupt_handler
        
        
; ���� LVT performance monitor counter
        mov DWORD [APIC_BASE + LVT_PERFMON], FIXED_DELIVERY | APIC_PERFMON_VECTOR
        

;*
;* ʵ�� ex15-7������ PEBS buffer ��ʱ�����ж�
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


; ���������� DS ����
        SET_DS_AREA
        
; ���� BTS   
        ENABLE_BTS_FREEZE_PERFMON_ON_PMI


; ���� counter ����ֵ        
        mov esi, IA32_PMC0
        call write_counter_maximum

; ���� PEBS buffer size
        mov esi, 1                                      ; ֻ���� 1 �� PEBS ��¼
        call set_pebs_buffer_size

        
; ���� IA32_PERFEVTSEL0 �Ĵ���, ��������
        mov ecx, IA32_PERFEVTSEL0
        mov eax, PEBS_INST_COUNT_EVENT                ; ָ������¼�
        mov edx, 0
        wrmsr


; ���� PEBS ���������
        ENABLE_PEBS_PMC0                            ; ���� IA32_PMC0 PEBS�ж�����
        ENABLE_IA32_PMC0


; ִ��һЩָ��۲�
        mov eax, 1
        mov eax, 2
        mov eax, 3

; �رռ�����
        DISABLE_IA32_PMC0

; �ر� PEBS ����
        DISABLE_PEBS_PMC0

; �ر� BTS
        DISABLE_BTS_FREEZE_PERFMON_ON_PMI

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




;-------------------------------
; perfmon handler
;------------------------------
perfmon_handler:
        jmp do_perfmon_handler
pfh_msg1 db '>>> now: enter PMI handler, occur at 0x', 0
pfh_msg2 db 'exit the PMI handler <<<', 10, 0        
pfh_msg3 db '*** DS interrupt with PEBS buffer full! ***', 10, 0
pfh_msg4 db '*** PEBS interrupt ***', 10, 0
do_perfmon_handler:        
        STORE_CONTEXT                     ; ���� context

        ;; �ر� BTS
        mov ecx, IA32_DEBUGCTL
        rdmsr
        mov [debugctl_value], eax        ; ����ԭ IA32_DEBUGCTL �Ĵ���ֵ���Ա�ָ�
        mov [debugctl_value + 4], edx
        mov eax, 0
        mov edx, 0
        wrmsr

        ;; �ر� pebs enable
        mov ecx, IA32_PEBS_ENABLE
        rdmsr
        mov [pebs_enable_value], eax
        mov [pebs_enable_value + 4], edx
        mov eax, 0
        mov edx, 0
        wrmsr


        mov esi, pfh_msg1
        call puts
        mov esi, [esp]
        call print_dword_value
        call println


        ; ���� PEBS �жϴ�������
check_pebs_interrupt:
        call test_pebs_interrupt
        test eax, eax
        jz check_pebs_buffer_overflow
        mov esi, pfh_msg4
        call puts
        call update_pebs_index_track            ; ���� PEBS index �Ĺ켣�����ֶ� PEBS �жϵļ��
        jmp do_perfmon_handler_done

check_pebs_buffer_overflow:
        ; ����Ƿ��� PEBS buffer ����ж�
        call test_pebs_buffer_overflow
        test eax, eax
        jz do_perfmon_handler_done

        mov esi, pfh_msg3
        call puts                 
        call dump_perf_global_status            ; ��ӡ���״̬ 
        call dump_ds_management                 ; ��ӡDS��������Ϣ
        RESET_PEBS_BUFFER_OVERFLOW              ; �� OvfBuffer �����־
        call reset_pebs_index                   ; ���� PEBS 

do_perfmon_handler_done:
        mov esi, pfh_msg2
        call puts

        ; �ָ�ԭ IA32_DEBUGCTL ���á�
        mov ecx, IA32_DEBUGCTL
        mov eax, [debugctl_value]
        mov edx, [debugctl_value + 4]
        wrmsr

        ;; �ָ� IA32_PEBS_ENABLE �Ĵ���
        mov ecx, IA32_PEBS_ENABLE
        mov eax, [pebs_enable_value]
        mov edx, [pebs_enable_value + 4]
        wrmsr

        RESTORE_CONTEXT                                 ; �ָ� context
        btr DWORD [APIC_BASE + LVT_PERFMON], 16         ; �� mask λ
        mov DWORD [APIC_BASE + EOI], 0                  ; ���� EOI ����
        iret




        
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