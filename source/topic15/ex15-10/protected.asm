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
;* ʵ�� ex15-10������ load latency ����
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
        ENABLE_BTS                                     ; TR=1, BTS=1

; ���� counter ����ֵ        
        mov esi, IA32_PMC0
        call write_counter_maximum

; д�� load latency ���ֵ
        mov ecx, MSR_PEBS_LD_LAT
        mov eax, 03h                                    ; ���ֵΪ 3
        mov edx, 0
        wrmsr

; ���ü���¼�, ����������
        mov ecx, IA32_PERFEVTSEL0
        mov eax, PEBS_MEM_INST_COUNT_EVENT              ; ʹ�� MEM load �¼�
        mov edx, 0
        wrmsr     

; ���� IA32_PMC0 �������� PEBS ���ƣ���ʹ�� load latency ����
        ENABLE_PEBS_WITH_LL_PMC0
        ENABLE_IA32_PMC0
        

; ���Ժ��� 
        call test_func


; �ر� IA32_PMC0 ������
        DISABLE_IA32_PMC0
        DISABLE_PEBS_PMC0
        DISABLE_BTS

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



test_func:
        jmp do_test_func
test_msg db 'this is a test message', 10, 0
do_test_func:
        mov esi, test_msg
        call puts
        ret

pebs_count dd 0


;-------------------------------
; perfmon handler
;------------------------------
apic_perfmon_handler:
        jmp do_apic_perfmon_handler
ph_msg1 db '>>> now: enter PMI handler, occur at 0x', 0
ph_msg2 db 'exit the PMI handler <<<', 10, 0        
ph_msg3 db '****** DS interrupt occur with BTS buffer full! *******', 10, 0
ph_msg4 db '****** PMI interrupt occur *******', 10, 0
ph_msg5 db '****** DS interrupt occur with PEBS buffer full! *******', 10, 0
ph_msg6 db '****** PEBS interrupt occur *******', 10, 0

do_apic_perfmon_handler:
        ;; ���洦����������
        STORE_CONTEXT

;*
;* ������ handler ��رչ���
;*

        ;; �� TR ����ʱ���͹ر� TR
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


        ; �ر� performance counter
        mov ecx, IA32_PERF_GLOBAL_CTRL
        rdmsr
        mov [perf_global_ctrl_value], eax
        mov [perf_global_ctrl_value + 4], edx
        mov eax, 0
        mov edx, 0
        wrmsr

        mov esi, ph_msg1
        call puts
        mov esi, [esp]
        call print_dword_value
        call println

        call dump_pmc
;*
;* �������ж� PMI �ж�����ԭ��
;*

checK_pebs_interrupt:
        ; �Ƿ� PEBS �ж�
        call test_pebs_interrupt
        test eax, eax
        jz check_counter_overflow
        ; ��ӡ��Ϣ
        mov esi, ph_msg6
        call puts
        call dump_pebs_record
        call update_pebs_index_track            ; ���� PEBS index �Ĺ켣�����ֶ� PEBS �жϵļ��

check_counter_overflow:
        ; ����Ƿ��� PMI �ж�
        call test_counter_overflow
        test eax, eax
        jz check_pebs_buffer_overflow
        ; ��ӡ��Ϣ
        mov esi, ph_msg4
        call puts
        call dump_perf_global_status
        RESET_COUNTER_OVERFLOW                  ; �������־

check_pebs_buffer_overflow:
        ; ����Ƿ��� PEBS buffer ����ж�
        call test_pebs_buffer_overflow
        test eax, eax
        jz check_bts_buffer_overflow
        ; ��ӡ��Ϣ
        mov esi, ph_msg5
        call puts
        call dump_perf_global_status
        RESET_PEBS_BUFFER_OVERFLOW              ; �� OvfBuffer �����־
        call reset_pebs_index                   ; ���� PEBS ֵ

check_bts_buffer_overflow:
        ; �����Ƿ��� BTS buffer ����ж�
        call test_bts_buffer_overflow
        test eax, eax
        jz apic_perfmon_handler_done
        ; ��ӡ��Ϣ
        mov esi, ph_msg3
        call puts
        call reset_bts_index                    ; ���� BTS index ֵ

apic_perfmon_handler_done:
        mov esi, ph_msg2
        call puts

;*
;* ����ָ�����ԭ����!
;* 
        ; �ָ�ԭ IA32_PERF_GLOBAL_CTRL �Ĵ���ֵ
        mov ecx, IA32_PERF_GLOBAL_CTRL
        mov eax, [perf_global_ctrl_value]
        mov edx, [perf_global_ctrl_value + 4]
        wrmsr

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
        btr DWORD [APIC_BASE + LVT_PERFMON], 16         ; �� LVT_PERFMON �Ĵ��� mask λ
        mov DWORD [APIC_BASE + EOI], 0                  ; д EOI ����
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