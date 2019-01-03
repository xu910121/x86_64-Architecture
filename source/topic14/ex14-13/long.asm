; long.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.

;;
;; ��δ��뽫�л��� long mode ����

%include "..\inc\support.inc"
%include "..\inc\long.inc"
	
	bits 32

LONG_LENGTH:	dw	LONG_END - $
	
	org LONG_SEG - 2
	
	NMI_DISABLE
	cli

; �ر� PAE paging	
	mov eax, cr0
	btr eax, 31
	mov cr0, eax
	
	mov esp, 9FF0h

	call init_page

; ���� GDT ��
	lgdt [__gdt_pointer]
	
; ���� CR3 �Ĵ���	
	mov eax, PML4T_BASE
	mov cr3, eax
	
; ���� CR4 �Ĵ���
	mov eax, cr4
	bts eax, 5				; CR4.PAE = 1
	mov cr4, eax

; ���� EFER �Ĵ���
	mov ecx, IA32_EFER
	rdmsr 
	bts eax, 8				; EFER.LME = 1
	wrmsr

; ���� long mode
	mov eax, cr0
	bts eax, 31
	mov cr0, eax			; EFER.LMA = 1
	
; ת�� 64 λ����
	jmp KERNEL_CS : entry64


; ������ 64 λ����
	
	bits 64
		
entry64:
	mov ax, KERNEL_SS
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov rsp, PROCESSOR0_KERNEL_RSP

;; ���潫 GDT ��λ�� SYSTEM_DATA64_BASE �����Ե�ַ�ռ���
	mov rdi, SYSTEM_DATA64_BASE
	mov rsi, __system_data64_entry
	mov rcx, __system_data64_end - __system_data64_entry
	rep movsb

;; �������¼��� 64-bit �����µ� GDT �� IDT ��
	mov rbx, SYSTEM_DATA64_BASE + (__gdt_pointer - __system_data64_entry)
	mov rax, SYSTEM_DATA64_BASE + (__global_descriptor_table - __system_data64_entry)
	mov [rbx + 2], rax
	lgdt [rbx]
	
	mov rbx, SYSTEM_DATA64_BASE + (__idt_pointer - __system_data64_entry)
	mov rax, SYSTEM_DATA64_BASE + (__interrupt_descriptor_table - __system_data64_entry)
	mov [rbx + 2], rax
	lidt [rbx]

;; ���� TSS descriptor	
	mov rsi, tss64_sel
	mov edi, 0x67
	mov r8,	SYSTEM_DATA64_BASE + (__task_status_segment - __system_data64_entry)
	mov r9, TSS64
	call set_system_descriptor

; ���� LDT ������
	mov rsi, ldt_sel
	mov edi, __local_descriptor_table_end - __local_descriptor_table - 1
	mov r8, SYSTEM_DATA64_BASE + (__local_descriptor_table - __system_data64_entry)
	mov r9, LDT64
	call set_system_descriptor

;; ���� TSS �� LDT ��
	mov ax, tss64_sel
	ltr ax
	mov ax, ldt_sel
	lldt ax
		
;; ���� call gate descriptor
	mov rsi, call_gate_sel
	mov rdi, __lib32_service					; call-gate ���� __lib32_srvice() ������
	mov r8, 3									; call-gate �� DPL = 3
	mov r9, KERNEL_CS							; code selector = KERNEL_CS
	call set_call_gate

	mov rsi, conforming_callgate_sel
	mov rdi, __lib32_service					; call-gate ���� __lib32_srvice() ������
	mov r8, 3									; call-gate �� DPL = 0
	mov r9, conforming_code_sel					; code selector = conforming_code_sel
	call set_call_gate

;; ���� conforming code segment descriptor	
	MAKE_SEGMENT_ATTRIBUTE 13, 0, 1, 0			; type=conforming code segment, DPL=0, G=1, D/B=0
	mov r9, rax									; attribute
	mov rsi, conforming_code_sel				; selector
	mov rdi, 0xFFFFF							; limit
	mov r8, 0									; base       
	call set_segment_descriptor	
        
        
; ���� #GP handler
	mov rsi, GP_HANDLER_VECTOR
	mov rdi, GP_handler
	call set_interrupt_descriptor
			
; ���� #DB handler
	mov rsi, DB_HANDLER_VECTOR
	mov rdi, DB_handler
	call set_interrupt_descriptor					

;; ���� sysenter/sysexit ʹ�û���
	call set_sysenter
        
;; ���� syscall/sysret ʹ�û���
	call set_syscall
        
;; ���� int 40h ʹ�û���
        mov rsi, 40h
        mov rdi, user_system_service_call
        call set_user_interrupt_handler
	
; �� FS.base = 0xfffffff800000000	
	mov ecx, IA32_FS_BASE
	mov eax, 0x0
	mov edx, 0xfffffff8
	wrmsr	
	
; �����������
	NMI_ENABLE
	sti
        
;======== long-mode �������ô������=============


; 1) ����APIC
	call enable_xapic	

;
;* ʵ�� 14-13��ͳ�� 64-bit ģʽ�� PMI �ж� handler ���õĴ���
;*
	mov rsi, APIC_PERFMON_VECTOR
	mov rdi, apic_perfmon_handler
	call set_interrupt_handler


; ���� performance monitor �Ĵ���
	mov DWORD [APIC_BASE + LVT_PERFMON], FIXED | APIC_PERFMON_VECTOR

	
	SET_INT_DS_AREA64			; ���� 64-bit ģʽ�µ� DS �洢����
	ENABLE_BTS_BTINT			; ���� BTS��ʹ���ж��� BTS buffer

;; �����ӡ������Ϣ��ͳ�������ӡ�����˶��ٷ�֧
	mov esi, test_msg
	LIB32_PUTS_CALL

; �ر� BTS
	DISABLE_BTS


; ��ӡ���
	mov esi, pmi_msg
	LIB32_PUTS_CALL
	mov esi, [pmi_counter]
	LIB32_PRINT_DWORD_DECIMAL_CALL
	LIB32_PRINTLN_CALL
	LIB32_PRINTLN_CALL


;; ��ӡ BTS buffer ��Ϣ
	DUMP_BTS64				

	
	jmp $

test_msg	db 'this is a test message...', 10, 0
pmi_msg		db 'call PMI handler count is: ', 0
pmi_counter	dq 0

	
	;call QWORD far [conforming_callgate_pointer]	; ���� call-gate for conforming ��
	
	;call QWORD far [conforming_pointer]			; ����conforimg ����
	
;; �� 64 λ�л��� compatibility mode��Ȩ�޲��ı䣬0 ������	
	;jmp QWORD far [compatibility_pointer]

;; �л��� compatibility mode������ 3 ����
;	push user_data32_sel | 3
;	push 0x10ff0
;	push user_code32_sel | 3
;	push compatibility_user_entry
;	db 0x48
;	retf	

;; ʹ�� iret �л��� compatibility mode������ 3 ����
;	mov rax, KERNEL_RSP
;	push user_data32_sel | 3
;	push rax;USER_RSP
;	push 0x3000
;	push user_code32_sel | 3
;	push compatibility_user_entry
;	iretq

;; ʹ�� iret �л��� conforming ��
;	mov rax, KERNEL_RSP
;	push KERNEL_SS;user_data32_sel
;	push rax;USER_RSP
;	pushfq
;	push conforming_code_sel
;	push compatibility_user_entry
;	iretq

;	mov rsi, USER_CS
;	call read_segment_descriptor
;	btr rax, 47				; p=0
;	btr rax, 43				; code/data=0
;	btr rax, 41				; R=0
;	btr rax, 42				; c=1
;	btr rax, 45
;	mov rsi, 0x78
;	mov rdi, rax
;	call write_segment_descriptor
	
	


	
;; �л����û����롡
;	push USER_SS | 3
;	push USER_RSP
;	push USER_CS | 3
;	push user_entry
;	db 0x48
;	retf

;; ʹ�� iret �л����û����롡		
;	push USER_SS | 2;3
;	push USER_RSP
;	pushfq
;	push USER_CS | 2;3
;	push user_entry
;	iretq							; ���ص� 3 ��Ȩ��

;	mov rdi, 0x0000
;	mov rsi, user_entry
;	mov rcx, conforming_callgate_pointer-user_entry
;	rep movsb
	
;	mov DWORD [rsp], user_entry
;	mov DWORD [rsp + 4], KERNEL_CS;USER_CS | 2
;	mov DWORD [rsp + 8], 46
;	mov DWORD [rsp + 12], USER_RSP
;	mov DWORD [rsp + 16], KERNEL_SS;USER_SS | 2
;	iret

;	mov WORD [rsp], 0x0000;user_entry
;	mov WORD [rsp + 2], KERNEL_CS;USER_CS | 2
;	mov WORD [rsp + 4], 46
;	mov WORD [rsp + 6], 0x8f0;USER_RSP
;	mov WORD [rsp + 8], 0xa0;KERNEL_SS;USER_SS | 2
;	db 0x66
;	iret
		
compatibility_pointer:
		dq compatibility_kernel_entry              ; 64 bit offset on Intel64
		dw code32_sel

		

;;; ##### 64-bit �û����� #########

	bits 64
	
user_entry:
	mov rbx, lib32_service
;	mov rsi, rsp
;	mov rdi, rsi
;	shr rdi, 32
;	mov eax, LIB32_PRINT_QWORD_VALUE
;	call rbx
	
	mov rsi, rsp
	shl rsi, 16
	mov si, ss
	mov rdi, rsi
	shr rdi, 32
	mov eax, LIB32_PRINT_QWORD_VALUE
	call rbx
	
	;call lib32_service
	jmp $
	
; ʹ�� Call-gate ����
	mov esi, msg1
	mov eax, LIB32_PUTS
	call lib32_service

; ʹ�� sysenter ����
	mov esi, msg2
	mov eax, LIB32_PUTS
	call sys_service_enter

; ʹ�� syscall ����	
	mov esi, msg3
	mov eax, LIB32_PUTS
	call sys_service_call		
	
breakpoint:
	mov rax, rbx			; ���õ�ָ�����˲���#DB�쳣
	
		
;	mov rsi, msg1
;	mov eax, LIB32_PUTS	

;	call QWORD far [conforming_callgate_pointer]	; ���� call-gate for conforming ��		
;	call QWORD far [conforming_pointer]		; ���� conforming ����

	jmp $

conforming_callgate_pointer:
	dq 0
	dw conforming_callgate_sel

;	jmp $

msg		db '>>> now: test 64-bit LBR stack <<<', 10, 0
msg1	db '---> Now: call sys_service() with CALL-GATE', 10, 0
msg2	db '---> Now: call sys_service() with SYSENTER', 10, 0
msg3	db '---> Now: call sys_service() with SYSCALL', 10, 0


;;; ###### ������ 32-bit compatibility ģ�� ########		
	
	bits 32

;; 0 ���� compatibility �������	
compatibility_kernel_entry:
	mov ax, data32_sel
	mov ds, ax
	mov es, ax
	mov ss, ax	
	mov esp, COMPATIBILITY_USER_ESP
	jmp compatibility_entry

;; 3 ���� compatibility �������	
compatibility_user_entry:
	mov ax, user_data32_sel | 3
	mov ds, ax
	mov es, ax
	mov ss, ax	
	mov esp, COMPATIBILITY_USER_ESP
	
compatibility_entry:
;; ͨ�� stub ������compaitibilityģʽ����call gate ����64λģʽ
	mov esi, cmsg1
	mov eax, LIB32_PUTS
	call compatibility_lib32_service			;; stub ������ʽ


	mov esi, cmsg1
	mov eax, LIB32_PUTS
	call compatibility_sys_service_enter		; compatibility ģʽ�µ� sys_service() stub ����

;; �����л��� 3�� 64-bit ģʽ����
	push USER_SS | 3
	push USER_ESP
	push USER_CS | 3				; �� 4G��Χ��
	push user_entry
	retf

;; ʹ�� iretָ��� compatibility ģʽ�л��� 3 �� 64-bit ģʽ
;	push USER_SS | 3
;	push USER_RSP
;	pushf
;	push USER_CS | 3				; �� 4G ��Χ��
;	push user_entry
;	iret							; ʹ�� 32 λ������
	
	jmp $
	
cmsg1	db '---> Now: call sys_service() from compatibility mode with sysenter instruction', 10, 0
		
compatibility_entry_end:






;; ###### ������ 64 λ���̣�#######

	bits 64


;-------------------------------
; perfmon handler
;------------------------------
apic_perfmon_handler:
	jmp do_apic_perfmon_handler
ph_msg1	db '>>> now: enter PMI handler, occur at 0x', 0
ph_msg2 db 'exit the PMI handler <<<', 10, 0	
ph_msg3 db '****** DS interrupt occur with BTS buffer full! *******', 10, 0
ph_msg4 db '****** PMI interrupt occur *******', 10, 0
ph_msg5 db '****** DS interrupt occur with PEBS buffer full! *******', 10, 0
ph_msg6 db '****** PEBS interrupt occur *******', 10, 0

do_apic_perfmon_handler:
	;; ���洦����������
	STORE_CONTEXT64

;*
;* ������ handler ��رչ���
;*

	;; �ر� TR
	mov ecx, IA32_DEBUGCTL
	rdmsr
	mov [debugctl_value], eax	; ����ԭ IA32_DEBUGCTL �Ĵ���ֵ���Ա�ָ�
	mov [debugctl_value + 4], edx
	btr eax, 6			; TR = 0
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


;*
;* �������ж� PMI �ж�����ԭ��
;*
check_pebs_buffer_overflow:
	; �Ƿ� PEBS buffer ��
	call test_pebs_buffer_overflow
	test eax, eax
	jz check_counter_overflow

	; �� OvfBuffer λ
        RESET_PEBS_BUFFER_OVERFLOW
        call reset_pebs_index

check_counter_overflow:
	; �Ƿ� counter �������
	call test_counter_overflow	
	test eax, eax
	jz check_bts_buffer_overflow

        ;; �� overflow ��־
        RESET_COUNTER_OVERFLOW

check_bts_buffer_overflow:
        call test_bts_buffer_overflow
        test eax, eax
        jz check_pebs_interrupt
	;
	; ������ PMI �ж� handler �� count ֵ
	;
	mov rax, pmi_counter
	inc QWORD [rax]

	; ���� index ֵ
        call reset_bts_index

check_pebs_interrupt:
        call test_pebs_interrupt
        test eax, eax
        jz apic_perfmon_handler_done

	call update_pebs_index_track

apic_perfmon_handler_done:

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

	RESTORE_CONTEXT64		; �ָ� context

	btr DWORD [APIC_BASE + LVT_PERFMON], 16		; �� LVT_PERFMON �Ĵ��� mask λ
	mov DWORD [APIC_BASE + EOI], 0			; д EOI ����
	iret64




%define EX14_13


	
	bits 64

;*** include 64-bit ģʽ�� interrupt handler ****
%include "..\common\handler64.asm"


;*** include 64-bit ģʽ�µ�ϵͳ���� *****
%include "..\lib\system_data64.asm"


;*** include ���� 64 λ�� *****
%include "..\lib\lib64.asm"
%include "..\lib\page64.asm"
%include "..\lib\debug64.asm"
%include "..\lib\apic64.asm"
%include "..\lib\perfmon64.asm"




LONG_END:
		