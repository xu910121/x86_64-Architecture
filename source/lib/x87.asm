; x87.asm
; Copyright (c) 2009-2012 ��־
; All rights reserved.


;
; x87 FPU ������

clear_mask:
	fstcw WORD [control_word]
	and WORD [control_word], 0xFFC0
	fldcw WORD [control_word]
        ret

;-----------------------------------
; ��ӡ x87 FPU ��Ϣ
;-----------------------------------
dump_x87fpu:
	call dump_x87env		; ��ӡ������Ϣ
	call dump_data_register		; ��ӡ stack ��Ϣ
	ret

;------------------------------------------------
; dump_x87env()����ӡ x87 FPU ����ֵ
; ������
;	ʹ�� protected ģʽ 32λ operand size ��ʽ
;-------------------------------------------------
dump_x87env:
	fnstenv [x87env32]
; control word	
	mov esi, cw_msg
	call puts
	mov esi, [control_word]
	call print_word_value
	call println
; status word	
	mov esi, sw_msg
	call puts
	mov esi, [status_word]
	call print_word_value
	call println
; tag word	
	mov esi, tag_msg
	call puts
	mov esi, [tag_word]
	call print_word_value
	call println
; opcode 	
	mov esi, opcode_msg
	call puts
	mov esi, [opcode]
	call print_word_value
	call println
; last ip offset
	mov esi, ip_msg
	call puts
	mov esi, [ip_offset]
	call print_dword_value
	call println
; last ip selctor
	mov esi, ips_msg
	call puts
	mov esi, [ip_selector]
	call print_word_value
	call println	
; last op offset
	mov esi, op_msg
	call puts
	mov esi, [op_offset]
	call print_dword_value
	call println
; last ip selctor
	mov esi, ops_msg
	call puts
	mov esi, [op_selector]
	call print_word_value
	call println
	ret


;-------------------------------
; ��ӡ x87 FPU �������ݼĴ���
;-------------------------------
dump_data_register:
	jmp do_dump_data_register
ddr_msg		db ' )', 0
ddr_msg1	db '--------------------- x87 FPU stack --------------------', 10, 0
do_dump_data_register:
	push ebx
	push edx
	push ecx

	mov esi, ddr_msg1
	call puts

	call get_top					; �õ���ǰ TOP ֵ
	mov [top_value], eax
	call get_data_register_value			; �� stack ֵ

;; ��������ӡ stack ��Ϣ
	xor ebx, ebx
dump_data_register_loop:
	mov esi, [r_msg_set + ebx * 4]
	test esi, esi
	jz dump_data_register_done
	call puts
	mov edx, [data_register_file + ebx * 4]
	mov esi, [edx + 8]
	call print_word_value
	mov esi, '_'
	call putc
	mov esi, [edx]
	mov edi, [edx + 4]
	call print_qword_value
	mov esi, ddr_msg
	call puts

;; ��ӡ ST(i) ״̬��Ϣ
	mov edx, [data_register_status_set + ebx * 4]
	mov eax, [edx]
	mov esi, [status_msg_set + eax * 4]
	call puts


; *** ���������� stack �Ĵ���ָ����Ϣ ***
;;  
;; ������ʽ�ǣ�offset = TOP - ����Ĵ������
;              ST(i) = |8 - offset| ��8-offset�ľ���ֵ��
;
; ʾ������ TOP = 3 ʱ����ô R7�Ĵ����� ST(i)ֵ�ǣ�
;	offset = 3 - 7 = -4
;	8 - (-4) = 12 = 00001100B
;	12 & 7 = 4������R7 �Ĵ���Ϊ ST(4)
;	
	mov ecx, 8
	mov eax, [top_value]
	sub eax, ebx			; offset = TOP - R �ı��
	sub ecx, eax			; 8 - offset
	and ecx, 0x7			; �� 8 - offset �ľ���ֵ����ȥ������λ��
	mov esi, [st_msg_set + ecx * 4] ; �õ���ȷ�� ST(i) ��Ϣ
	call puts

	inc ebx
	jmp dump_data_register_loop

dump_data_register_done:	
	pop ecx
	pop edx
	pop ebx
	ret

;---------------------------------
; get_top():
; output:
;	eax: Top Of Stack
;---------------------------------
get_top:
        ; ʹ�� no-wait �汾
	fnstsw ax
	shr eax, 11
	and eax, 7
	ret

;--------------------------
; �õ����� data �Ĵ�����ֵ
;--------------------------
get_data_register_value:
	jmp do_get_data_register_value
qnan_index dd 7
do_get_data_register_value:
	push edx
	push ecx
	call get_top		; �õ� TOP ָ��ֵ
	mov edx, eax
	mov ecx, 8

; ʹ�� no-wait �汾���� x87 FPU �쳣 handler �����ʹ��
	fnstenv [x87env32]			; ����ԭ������Ϣ
        fnclex                                  ; ���쳣��־λ
get_data_register_value_loop:
	fxam
	fstsw ax
	movzx esi, ax
	mov edi, 0
	bt esi, 14		; C3
	rcl edi, 1
	bt esi, 10		; C2
	rcl edi, 1
	bt esi, 8		; C0
	rcl edi, 1		

; �� stack ֵ
	mov eax, [data_register_file + edx * 4]	
	fstp TWORD [eax]	; ��������Ӧ���ڴ���

; �����Ƿ�Ϊ NaN
	cmp edi, 1
	jnz get_data_register_value_next

	; ����� SNaN ���� QNaN
	bt DWORD [eax + 4], 30		; �� bit 62 �ж�
	cmovc edi, [qnan_index]

get_data_register_value_next:
	mov eax, [data_register_status_set + edx * 4]
	mov [eax], edi

	inc edx
	and edx, 7		; �����Ӧ������Ĵ���
	dec ecx
	jnz get_data_register_value_loop

;; �ָ� x87 FPU ��Ϣ
	fldenv [x87env32]

	pop ecx
	pop edx
	ret

;----------------------------------------------
; dump_x87_status(): ��ӡ status�Ĵ���״̬��Ϣ
;----------------------------------------------
dump_x87_status:
	jmp do_dump_x87_status
status_msg	db '<status>: ', 0
top_msg		db 'TOP:', 0
condition_msg	db ' condition:', 0
status_value	dd 0
do_dump_x87_status:
;;; ע�⣺ʹ�� no-wait �汾�� FSTSW ָ������� floating-point excepiton handler ��ʹ��
;;;
	fnstsw WORD [status_value]
	mov esi, status_msg
	call puts
	mov esi, top_msg
	call puts
	mov esi, [status_value]
	shr esi, 11
	and esi, 7
	call print_dword_decimal

	mov esi, condition_msg
	call puts

;; ��ӡ������
	mov eax, 0
	bt DWORD [status_value], 14
	setc al
	movzx esi, al
	call print_dword_decimal
	bt DWORD [status_value], 10
	setc al
	movzx esi, al
	call print_dword_decimal
	bt DWORD [status_value], 9
	setc al
	movzx esi, al
	call print_dword_decimal
	bt DWORD [status_value], 8
	setc al
	movzx esi, al
	call print_dword_decimal
	call printblank
	call printblank
; ��ӡ������־λ
	mov si, [status_value]
	shld ax, si, 1
	shl esi, 24
	shrd esi, eax, 1
	call reverse
	mov esi, eax
	mov edi, status_flags
	call dump_flags
	call println
	ret


;****** x87 FPU ������ ************

;; protected ģʽ�� realģʽ�µ� 32 λ x87 environment ������
;; �� 28 ���ֽ�
x87env32:
control_word	dd 0
status_word	dd 0
tag_word	dd 0
ip_offset	dd 0
ip_selector	dw 0
opcode		dw 0
op_offset	dd 0
op_selector	dd 0

;; FSAVE/FNSAVE��FRSTOR ָ��ĸ���ӳ��
;; ���� 8 �� 80 λ���ڴ��ַ���� data �Ĵ���ֵ
r0_value	dt 0.0
r1_value	dt 0.0
r2_value	dt 0.0
r3_value	dt 0.0
r4_value	dt 0.0
r5_value	dt 0.0
r6_value	dt 0.0
r7_value	dt 0.0

r0_status_value	dd 0
r1_status_value	dd 0
r2_status_value	dd 0
r3_status_value	dd 0
r4_status_value	dd 0
r5_status_value	dd 0
r6_status_value	dd 0
r7_status_value	dd 0

; ���� TOP ֵ
top_value	dd 0

; x87 FPU �Ĵ������ڴ��ַ��
data_register_file	dd r0_value, r1_value, r2_value, r3_value
			dd r4_value, r5_value, r6_value, r7_value, 0
data_register_status_set	dd r0_status_value, r1_status_value, r2_status_value, r3_status_value
				dd r4_status_value, r5_status_value, r6_status_value, r7_status_value, 0

cw_msg		db 'control register: 0x', 0
sw_msg		db 'status register:  0x', 0
tag_msg		db 'tag register:     0x', 0
opcode_msg	db 'opcode:           0x', 0
ip_msg		db 'last instruction pointer offset:   0x', 0
ips_msg		db 'last instruction pointer selector: 0x', 0
op_msg		db 'last operand pointer offset:       0x', 0
ops_msg		db 'last operand pointer selector:     0x', 0

r0_msg		db 'r0: ( 0x', 0
r1_msg		db 'r1: ( 0x', 0
r2_msg		db 'r2: ( 0x', 0
r3_msg		db 'r3: ( 0x', 0
r4_msg		db 'r4: ( 0x', 0
r5_msg		db 'r5: ( 0x', 0
r6_msg		db 'r6: ( 0x', 0
r7_msg		db 'r7: ( 0x', 0

r_msg_set	dd r0_msg, r1_msg, r2_msg, r3_msg, r4_msg, r5_msg, r6_msg, r7_msg, 0

st0_msg		db '  <-- ST(0)', 10, 0
st1_msg		db '      ST(1)', 10, 0
st2_msg		db '      ST(2)', 10, 0
st3_msg		db '      ST(3)', 10, 0
st4_msg		db '      ST(4)', 10, 0
st5_msg		db '      ST(5)', 10, 0
st6_msg		db '      ST(6)', 10, 0
st7_msg		db '      ST(7)', 10, 0

st_msg_set	dd st0_msg, st1_msg, st2_msg, st3_msg, st4_msg, st5_msg, st6_msg, st7_msg, 0

status_msg0	db ' <unsupported> ', 0
status_msg1	db ' <SNaN>        ', 0
status_msg2	db ' <normal>      ', 0
status_msg3	db ' <infinity>    ', 0
status_msg4	db ' <zero>        ', 0
status_msg5	db ' <empty>       ', 0
status_msg6	db ' <denormal>    ', 0
status_msg7	db ' <QNaN>        ', 0

status_msg_set	dd status_msg0, status_msg1, status_msg2, status_msg3, status_msg4
		dd status_msg5, status_msg6, status_msg7, 0

status_ie_msg	db 'ie', 0
status_de_msg	db 'de', 0
status_ze_msg	db 'ze', 0
status_oe_msg	db 'oe', 0
status_ue_msg	db 'ue', 0
status_pe_msg	db 'pe', 0
status_sf_msg	db 'sf', 0
status_es_msg	db 'es', 0
status_b_msg	db 'b', 0
status_flags	dd status_b_msg, status_es_msg, status_sf_msg, status_pe_msg, status_ue_msg
		dd status_oe_msg, status_ze_msg, status_de_msg, status_ie_msg, -1