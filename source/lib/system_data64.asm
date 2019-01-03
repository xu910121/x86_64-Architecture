; system_data64.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


;*
;* ���� long-mode ģʽ�µ�ϵͳ����
;*

        bits 64


;----------------------------------------------
; BSP ��������ʼ�� long-mode ϵͳ��
;----------------------------------------------
bsp_init_system_struct:
init_system_struct:
;*
;* �����Ƿ� BSP ������
;*
        mov ecx, IA32_APIC_BASE
        rdmsr
        bt eax, 8
        jnc bsp_init_system_struct_done


; ���� LDT ������                       
        mov rbx, ldt_sel + __global_descriptor_table                                            ; LDT descriptor
        mov rsi, SYSTEM_DATA64_BASE + (__local_descriptor_table - __system_data64_entry)        ; base
        mov rdi, __local_descriptor_table_end - __local_descriptor_table - 1                    ; limit
        mov [rbx], di                   ; limit[15:0]
        mov [rbx + 4], rsi              ; base[63:24]
        mov [rbx + 2], esi              ; base[23:0]
        mov BYTE [rbx + 5], 82h         ; type
        mov BYTE [rbx + 6], 0           ; limit[19:16]

;; ���潫ϵͳ���ݽṹ��λ�� SYSTEM_DATA64_BASE �����Ե�ַ�ռ���
        mov rdi, SYSTEM_DATA64_BASE
        mov rsi, __system_data64_entry
        mov rcx, __system_data64_end - __system_data64_entry
        rep movsb

;; ������������ 64-bit �����µ� GDT �� IDT ��ָ��
        mov rbx, SYSTEM_DATA64_BASE + (__gdt_pointer - __system_data64_entry)
        mov rax, SYSTEM_DATA64_BASE + (__global_descriptor_table - __system_data64_entry)
        mov [rbx + 2], rax

        mov rbx, SYSTEM_DATA64_BASE + (__idt_pointer - __system_data64_entry)
        mov rax, SYSTEM_DATA64_BASE + (__interrupt_descriptor_table - __system_data64_entry)
        mov [rbx + 2], rax

bsp_init_system_struct_done:
        ret



; ���涨������ system ���ݵ����

__system_data64_entry:

;-----------------------------------------
; ���涨�� long-mode �� GDT ��
;-----------------------------------------
__global_descriptor_table:


null_desc			dq 0                            ; NULL descriptor

code16_desc			dq 0x00009a000000ffff           ; for real mode code segment
data16_desc			dq 0x000092000000ffff           ; for real mode data segment
code32_desc			dq 0x00cf9a000000ffff           ; for protected mode code segment
								 ; or for compatibility mode code segmnt
data32_desc			dq 0x00cf92000000ffff           ; for protected mode data segment
								 ; or for compatibility mode data segment

kernel_code64_desc		dq 0x0020980000000000		; 64-bit code segment
kernel_data64_desc		dq 0x0000920000000001		; 64-bit data segment

;;; ҲΪ sysexit ָ��ʹ�ö���֯
user_code32_desc		dq 0x00cffa000000ffff           ; for protected mode code segment
								 ; or for compatibility mode code segmnt
user_data32_desc		dq 0x00cff2000000ffff           ; for protected mode data segment
								; or for compatibility mode data segment	
;; ҲΪ sysexit ָ��ʹ�ö���֯                                                 
user_code64_desc		dq 0x0020f80000000000		; 64-bit non-conforming
user_data64_desc		dq 0x0000f20000000000		; 64-bit data segment

tss64_desc			dw 0x67                         ; 64bit TSS
				dd 0
				dw 0
				dq 0

call_gate_desc			dq 0, 0

conforming_code64_desc		dq 0

;; ����Ϊ syscall/sysret ����׼��					
				dq 0				; reserved
sysret_stack64_desc		dq 0x0000f20000000000
sysret_code64_desc		dq 0x0020f80000000000

data64_desc			dq 0x0000f00000000000		; 64-bit data segment

;test_kernel_data64_desc		dq 0x0000920000000001		; 64-bit data segment
                                                 				
	times	40 dq 0						; ���� 40 �� descriptor λ��


__global_descriptor_table_end:




;--------------------------------------
; ���涨�� long-mode �� LDT ��
;--------------------------------------

__local_descriptor_table:

				dq 0
ldt_kernel_code64_desc		dq 0x0020980000000000		; 64-bit code segment
ldt_kernel_data64_desc		dq 0x0000920000000000		; 64-bit data segment
ldt_user_code32_desc		dq 0x00cffa000000ffff           ; for protected mode code segment
				                                 ; or for compatibility mode code segmnt
ldt_user_data32_desc		dq 0x00cff2000000ffff           ; for protected mode data segment	
ldt_user_code64_desc		dq 0x0020f80000000000		; 64-bit non-conforming
ldt_user_data64_desc		dq 0x0000f20000000000		; 64-bit data segment

			times 5 dq 0

__local_descriptor_table_end:



;-------------------------------------------
; ���涨�� long-mode �� IDT ��
;-------------------------------------------
__interrupt_descriptor_table:

times 0x50 dq 0, 0			; ���� 0x50 �� vector

__interrupt_descriptor_table_end:



;-------------------------------------------
; TSS64 for long mode
;-------------------------------------------
__processor0_task_status_segment:
__task_status_segment:
	dd 0							; reserved
	dq PROCESSOR0_IDT_RSP					; rsp0
	dq 0							; rsp1
	dq 0							; rsp2
	dq 0							; reserved
	dq PROCESSOR0_IST1_RSP       				; IST1
times 0x3c db 0
__task_status_segment_end:
__processor0_task_status_segment_end:


;*
;* Ϊ 7 ������������ 7 �� TSS ����
;*
__processor_task_status_segment:
        times 104 * 8 db 0                                      ; ���� 8 �� TSS �ռ�
        

;--------------------------------------------
; TEST_TSS SEGMENT
;-------------------------------------------
__test_tss:
	dd 0							; reserved
	dq PROCESSOR0_IDT_RSP					; rsp0
	dq 0							; rsp1
	dq 0							; rsp2
	dq 0							; reserved
	dq PROCESSOR0_IST1_RSP       				; IST1
times 0x3c db 0
__test_tss_end:


;----------------------------------------
; ���涨�� descriptor table pointer ����
;----------------------------------------

__gdt_pointer:
gdt_limit	dw (__global_descriptor_table_end - __global_descriptor_table) - 1
gdt_base:	dq __global_descriptor_table


__idt_pointer:
idt_limit	dw (__interrupt_descriptor_table_end - __interrupt_descriptor_table)- 1 
idt_base	dq __interrupt_descriptor_table



;; system ��������Ľ���
__system_data64_end:


