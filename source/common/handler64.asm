; handler64.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


;*
;* ���� long-mode ģʽ�µ� interrupt/exception handler ����
;* �ɸ���ʵ�����ӵ� long.asm ģ���� include ��ȥ
;*


%ifndef HANDLER64_ASM
%define HANDLER64_ASM


;-------------------------------------------
; gp_handler:
;------------------------------------------
GP_handler:
        STORE_CONTEXT64
        jmp do_GP_handler
gmsg1   db '---> Now, enter #GP handler, occur at: 0x', 0
gmsg2   db 'error code = 0x', 0
gmsg3   db 'rsp = 0x', 0
gmsg4   db '--------------- register context ------------', 10, 0
do_GP_handler:        
        mov esi, gmsg1
        LIB32_PUTS_CALL
        mov esi, [rsp + 8]
        mov edi, [rsp + 8 + 4]
        LIB32_PRINT_QWORD_VALUE_CALL
        LIB32_PRINTLN_CALL

        mov esi, gmsg2
        LIB32_PUTS_CALL
        mov esi, [rsp]
        mov edi, [rsp + 4]
        LIB32_PRINT_QWORD_VALUE_CALL
        LIB32_PRINTLN_CALL

        mov esi, gmsg3
        LIB32_PUTS_CALL
        mov esi, [rsp + 32]
        mov edi, [rsp + 32 + 4]
        LIB32_PRINT_QWORD_VALUE_CALL
        LIB32_PRINTLN_CALL

        mov esi, gmsg4
        LIB32_PUTS_CALL
        call dump_reg64

        jmp $ 
        iret64

;-------------------------------------------
; #PF handler:
;------------------------------------------
PF_handler:
        jmp do_PF_handler
pf_msg1 db 10, '>>> Now, enter #PF handler', 10, 0
pf_msg2 db '>>>>>>> occur at: 0x', 0        
pf_msg3 db '>>>>>>> page fault address: 0x', 0
do_PF_handler:        
        add rsp, 8
        mov esi, pf_msg1
        LIB32_PUTS_CALL
        mov esi, pf_msg2
        LIB32_PUTS_CALL
        mov esi, [rsp]
        mov edi, [rsp + 4]
        LIB32_PRINT_QWORD_VALUE_CALL
        LIB32_PRINTLN_CALL
        mov esi, pf_msg3
        LIB32_PUTS_CALL
        mov rsi, cr2
        mov rdi, rsi
        shr rdi, 32
        LIB32_PRINT_QWORD_VALUE_CALL
        LIB32_PRINTLN_CALL
        jmp $ 
        iret64


;*********************************
; #DB handler
;*********************************
DB_handler:
        jmp do_db_handler
db_msg1 db '>>> now, enter #DB handler', 0
db_msg2 db 'now, exit #DB handler <<<', 10, 0
do_db_handler:        
        mov esi, db_msg1
        LIB32_PUTS_CALL
        
; �ص� L0 enable λ
        mov rax, dr7
        btr rax, 0
        mov dr7, rax
        
;        call dump_debugctl
        call dump_lbr_stack
        
do_db_handler_done:        
        bts QWORD [rsp+16], 16                ; RF=1
        mov esi, db_msg2
        LIB32_PUTS_CALL
        iret64        



%ifndef EX14_13

%define CONTEXT_POINTER64       debug_context64

;-------------------------------
; perfmon handler
;------------------------------
apic_perfmon_handler:
        jmp do_apic_perfmon_handler
ph_msg1 db '>>> now: enter PMI handler, occur at 0x', 0
ph_msg2 db 'exit the PMI handler <<<', 10, 0        
ph_msg3 db '****** BTS buffer full! *******', 10, 0
ph_msg4 db '****** PMI interrupt occur *******', 10, 0
ph_msg5 db '****** PEBS buffer full! *******', 10, 0
ph_msg6 db '****** PEBS interrupt occur *******', 10, 0

do_apic_perfmon_handler:
        ;; ���洦����������
        STORE_CONTEXT64

;*
;* ������ handler ��ر���صĹ���
;* �ڹرչ���֮ǰ���ȱ���ԭֵ���Ա㷵��ǰ�ָ�
;*
        mov ecx, IA32_DEBUGCTL
        rdmsr
        mov [debugctl_value], eax 
        mov [debugctl_value + 4], edx
        mov eax, 0 
        mov edx, 0
        wrmsr                                   ; �ر����� debug ����
        mov ecx, IA32_PEBS_ENABLE
        rdmsr
        mov [pebs_enable_value], eax
        mov [pebs_enable_value + 4], edx
        mov eax, 0
        mov edx, 0
        wrmsr                                   ; �ر����� PEBS �ж����
        mov ecx, IA32_PERF_GLOBAL_CTRL
        rdmsr
        mov [perf_global_ctrl_value], eax
        mov [perf_global_ctrl_value + 4], edx
        mov eax, 0
        mov edx, 0
        wrmsr                                   ; �ر����� performace counter

        ;; ��ӡ��Ϣ
        mov esi, ph_msg1
        LIB32_PUTS_CALL
        mov esi, [rsp]
        mov edi, [rsp + 4]
        LIB32_PRINT_QWORD_VALUE_CALL
        LIB32_PRINTLN_CALL

;*
;* �������ж� APIC performon monitor �жϴ�����ԭ��
;* 1. PMI �ж�
;* 2. PEBS �ж�
;* 3. BTS buffer ����ж�
;* 4. PEBS buffer ����ж�
;*

check_counter_overflow:
        ;*
        ;* ����Ƿ��� PMI �ж�
        ;*
        call test_counter_overflow
        test eax, eax
        jz check_pebs_interrupt

        ; ��ӡ��Ϣ
        mov esi, ph_msg4
        LIB32_PUTS_CALL
        call dump_perfmon_global_status       
        
        ;* �޸��ж����� *
        RESET_COUNTER_OVERFLOW                  ; ���������λ

check_pebs_interrupt:
        ;*
        ;* ����Ƿ��� PEBS �ж�
        ;*
        call test_pebs_interrupt
        test eax, eax
        jz check_bts_buffer_overflow

        ; ��ӡ��Ϣ
        mov esi, ph_msg6
        LIB32_PUTS_CALL

        call dump_pebs_record

        ;* �޸��ж����� *
        call update_pebs_index_track            ; ���� pebs index ��ع켣



check_bts_buffer_overflow:
        ;*
        ;* ����Ƿ��� BTS buffer ����ж�
        ;*
        call test_bts_buffer_overflow
        test eax, eax
        jz check_pebs_buffer_overflow

        ;* �޸��ж����� */
        call reset_bts_index                    ; ���� BTS index ֵ        

        ; ��ӡ��Ϣ
        mov esi, ph_msg3
        LIB32_PUTS_CALL

check_pebs_buffer_overflow:
        ;*
        ;* ����Ƿ��� PEBS buffer ����ж�
        ;*
        call test_pebs_buffer_overflow
        test eax, eax
        jz apic_perfmon_handler_done

        ;* �޸��ж����� */
        RESET_PEBS_BUFFER_OVERFLOW              ; �� OvfBuffer λ
        call reset_pebs_index                   ; ���� PEBS index ֵ

        ; ��ӡ��Ϣ
        mov esi, ph_msg5
        LIB32_PUTS_CALL


apic_perfmon_handler_done:
        mov esi, ph_msg2
        LIB32_PUTS_CALL

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

;*
;* apic performon handler ����ǰ
;*
        RESTORE_CONTEXT64                                       ; �ָ� context
        btr DWORD [APIC_BASE + LVT_PERFMON], 16                 ; �� LVT_PERFMON �Ĵ��� mask λ
        mov DWORD [APIC_BASE + EOI], 0                          ; д EOI ����
        iret64              
%endif
        
        

;---------------------------------------------
; apic_timer_handler()������ APIC TIMER �� ISR
;---------------------------------------------
apic_timer_handler:
        jmp do_apic_timer_handler
at_msg  db '>>> now: enter the APIC timer handler', 10, 0
at_msg1 db 10, 'exit ther APIC timer handler <<<', 10, 0        
do_apic_timer_handler:        
        mov esi, at_msg
        LIB32_PUTS_CALL
        call dump_apic                        ; ��ӡ apic �Ĵ�����Ϣ
        mov esi, at_msg1
        LIB32_PUTS_CALL
        mov DWORD [APIC_BASE + EOI], 0
        iret64


%endif