; perfmon64.asm
; Copyright (c) 2009-2012 ��־
; All rights reserved.

;*
;* ���ܼ�ؿ� 64λ�汾
;*


;--------------------------------------------
; get_unhalted_cpi(): ���� non-halted CPI ֵ
; input:
;       rsi - ���ĺ�������
; outpu:
;       rax - CPI ֵ
; ����:
;       ʹ�� CPU_CLK_UNHALTED.CORE �¼�
;-------------------------------------------
get_unhalted_cpi:
        push r8
        push r9
        ;*
        ;* �ȹر�Fixed������������Ϊ0ֵ
        ;*
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR1_EN)
        RESET_FIXED_PMC

        ;*
        ;* ����Fixed����������ʼ����
        ;*
        mov ecx, IA32_FIXED_CTR_CTRL
        mov eax, 0BBh
        mov edx, 0
        wrmsr
        ENABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR1_EN)

        call rsi                ; ���ñ���������
        
        ;*
        ;* �ر�Fxied��������ֹͣ����
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR1_EN)
        
        mov ecx, IA32_FIXED_CTR0
        rdmsr
        mov esi, eax
        mov edi, edx
        mov ecx, IA32_FIXED_CTR1
        rdmsr
        mov r8d, eax
        mov r9d, edx
        RESET_FIXED_PMC
        mov rax, r8
        mov rdx, r9
        div rsi
        pop r9
        pop r8
        ret


;--------------------------------------------
; get_nominal_cpi(): ���� non-nominal CPI ֵ
; input:
;       rsi - ���ĺ�������
; outpu:
;       rax - CPI ֵ
; ������
;       ʹ�� CPU_CLK_UNHALTED.REF �¼�
;-------------------------------------------
get_nominal_cpi:
        push r8
        push r9
        ;*
        ;* �ȹر�Fixed������������Ϊ0ֵ
        ;*
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR2_EN)
        RESET_FIXED_PMC

        ;*
        ;* ����Fixed����������ʼ����
        mov ecx, IA32_FIXED_CTR_CTRL
        mov eax, 0B0Bh
        mov edx, 0
        wrmsr
        ENABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR2_EN)
        call rsi                ; ���ò��Ժ���
        
        ;*
        ;* �ر�Fxied��������ֹͣ����
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR2_EN)
        
        mov ecx, IA32_FIXED_CTR0
        rdmsr
        mov esi, eax
        mov edi, edx
        mov ecx, IA32_FIXED_CTR2
        rdmsr
        mov r8d, eax
        mov r9d, edx
        RESET_FIXED_PMC
        mov rax, r8
        mov rdx, r9
        div rsi
        pop r9
        pop r8
        ret


;-----------------------------------------------
; support_full_write(): �����Ƿ�֧�� full-write
; output:
;        1-support, 0-no support
;-----------------------------------------------
support_full_write:
        mov eax, 1
        cpuid
        bt ecx, 15                              ; ���� PDCM λ���Ƿ�֧�� IA32_PERF_CAPABILITIES
        setc al
        jnc support_full_write_done
        mov ecx, IA32_PERF_CAPABILITIES
        rdmsr
        bt eax, 13                               ; ���� FW_WRITE λ
        setc al
support_full_write_done:        
        movzx eax, al
        ret


;----------------------------------------------
; write_counter_maximum(): д�� counter �����ֵ
; input:
;       esi-counter
;-----------------------------------------------
write_counter_maximum:
        call support_full_write         ; �Ƿ�֧��д�����ֵ
        mov edi, 0FFFFh
        mov edx, 0
        test eax, eax
        cmovnz edx, edi
        mov eax, 0FFFFFFFFh
        mov ecx, esi
        wrmsr
        ret


;---------------------------------------------------
; test_counter_overflow(): �����Ƿ� counter �������
; output:
;	1-yes, 0-no
;---------------------------------------------------
test_counter_overflow:
	mov ecx, IA32_PERF_GLOBAL_STATUS
	rdmsr
	test edx, 7			; ���� IA32_FIXED_CTRx �Ĵ���
	setnz dl
	jnz test_counter_overflow_done
	test eax, 0Fh			; ���� IA32_PMCx �Ĵ���
	setnz dl
test_counter_overflow_done:
	movzx eax, dl
	ret

;-------------------------------------------------------
; test_pebs_buffer_overflow(): ���� PEBS buffer �Ƿ����
; output:
;	1-yes, 0-no
;-------------------------------------------------------
test_pebs_buffer_overflow:
	mov ecx, IA32_PERF_GLOBAL_STATUS
	rdmsr
	bt edx, 30			; ���� OvfBuffer λ
	setc al
	movzx eax, al
	ret

;-----------------------------------------------
; test_pebs_interrupt(): �����Ƿ���� PEBS �ж�
; output:
;       1-yes, 0-no
;----------------------------------------------
test_pebs_interrupt:
        mov rax, [pebs_buffer_index]    ; ԭ PEBS index ֵ
        mov rsi, [pebs_index_pointer]
        mov rsi, [rsi]                  ; ����ǰ PEBS index ֵ
        cmp rsi, rax
        seta al
        movzx eax, al
        ret

;------------------------------
; ��ӡ IA32_PERFEVTSELx �Ĵ���
;-----------------------------
dump_perfevtsel:
	jmp do_dump_perfevtsel
dp_msg1	db '<', 0
dp_msg2	db '>', 0	
dp_msg3 db ' ', 0
do_dump_perfevtsel:	
	push rcx
	push rbx

	xor rbx, rbx
	mov ecx, IA32_PERFEVTSEL0
	mov esi, perfevtsel_msg
	LIB32_PUTS_CALL
	
do_dump_perfevtsel_loop:	
	mov esi, dp_msg1
	LIB32_PUTS_CALL
	mov esi, ebx
	LIB32_PRINT_DWORD_DECIMAL_CALL
	mov esi, dp_msg2
	LIB32_PUTS_CALL
	rdmsr
	mov esi, eax
	LIB32_PRINT_DWORD_VALUE_CALL
	mov esi, dp_msg3
	LIB32_PUTS_CALL
	inc rbx
	inc rcx
	cmp ecx, IA32_PERFEVTSEL3
	jbe do_dump_perfevtsel_loop
	LIB32_PRINTLN_CALL
	pop rbx
	pop rcx
	ret

;----------------------------------
; ��ӡ PMC �Ĵ���
;----------------------------------
dump_pmc:
	push rcx
	push rbx
	xor rbx, rbx
	mov ecx, IA32_PMC0
	mov esi, pmc_msg
	LIB32_PUTS_CALL
	
dump_pmc_loop:	
	mov esi, dp_msg1
	LIB32_PUTS_CALL
	mov esi, ebx
	LIB32_PRINT_DWORD_DECIMAL_CALL
	mov esi, dp_msg2
	LIB32_PUTS_CALL
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL
	mov esi, dp_msg3
	LIB32_PUTS_CALL
	inc rbx
	inc rcx
	cmp ecx, IA32_PMC3
	jbe dump_pmc_loop
	LIB32_PRINTLN_CALL
	pop rbx
	pop rcx
	ret
	
;----------------------------
; ��ӡ Fixed-function counter
;----------------------------
dump_fixed_pmc:
	push rcx
	push rbx
	xor rbx, rbx
	mov ecx, IA32_FIXED_CTR0
	mov esi, fixed_pmc_msg
	LIB32_PUTS_CALL
	
dump_fixed_pmc_loop:	
	mov esi, dp_msg1
	LIB32_PUTS_CALL
	mov esi, ebx
	LIB32_PRINT_DWORD_DECIMAL_CALL
	mov esi, dp_msg2
	LIB32_PUTS_CALL
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL
	mov esi, dp_msg3
	LIB32_PUTS_CALL
	inc rbx
	inc rcx
	cmp ecx, IA32_FIXED_CTR2
	jbe dump_fixed_pmc_loop
	LIB32_PRINTLN_CALL
	pop rbx
	pop rcx
	ret

;--------------------------
;��ӡ fixed counter control
;---------------------------
dump_fixed_counter_control:
	mov esi, fixed_ctr_ctrl_msg
	LIB32_PUTS_CALL
	mov ecx, IA32_FIXED_CTR_CTRL
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL
	ret

;----------------------------------
; ��ӡ IA32_PERF_GLOBAL_CTRL �Ĵ���
;----------------------------------
dump_perf_global_ctrl:
dump_perfmon_global_ctrl:
	mov esi, perfmon_global_ctrl_msg
	LIB32_PUTS_CALL
	mov ecx, IA32_PERF_GLOBAL_CTRL
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL
	ret

;----------------------------------
; ��ӡ IA32_PERF_GLOBAL_STATUS �Ĵ���
;----------------------------------	
dump_perf_global_status:
dump_perfmon_global_status:
	mov esi, perfmon_global_status_msg
	LIB32_PUTS_CALL
	mov ecx, IA32_PERF_GLOBAL_STATUS
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL
	ret	
;----------------------------------
; ��ӡ IA32_PERF_GLOBAL_OVF �Ĵ���
;----------------------------------
dump_perf_global_ovf_ctrl:
dump_perfmon_global_ovf:
	mov esi, perfmon_global_ovf_msg
	LIB32_PUTS_CALL
	mov ecx, IA32_PERF_GLOBAL_OVF_CTRL
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL
	ret

;----------------------------------
; ��ӡ���� performace monitor �Ĵ���
;----------------------------------
dump_perfmon64:
dump_perfmon:
	call dump_perfevtsel
	call dump_pmc
	call dump_fixed_pmc
	call dump_fixed_counter_control
	call dump_perfmon_global_ctrl
	call dump_perfmon_global_status
	call dump_perfmon_global_ovf
	ret			

;; **** ������ *******

; ���涨�屣�� performance monitor ��صļĴ���ֵ
perf_global_ctrl_value		dq 0
perf_global_status_value	dq 0

perfevtsel_msg			db 'PERFEVTSEL: ', 0
pmc_msg				db 'PMC: ', 0
fixed_pmc_msg			db 'FIXED_PMC: ', 0
fixed_ctr_ctrl_msg		db 'FIXED_CTR_CTRL:       ', 0
perfmon_global_ctrl_msg		db 'PERF_GLOBAL_CTRL:     ', 0
perfmon_global_status_msg	db 'PERF_GLOBAL_STATUS:   ', 0
perfmon_global_ovf_msg		db 'PERF_GLOBAL_OVF_CTRL: ', 0
