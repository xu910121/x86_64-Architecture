; debug64.asm
; Copyright (c) 2009-2012 ��־
; All rights reserved.


;*
;* 64 λ�� debug ��
;*



;-------------------------------------------
; set_debug_store_area(): ���� DS �������ַ
;-------------------------------------------
set_debug_store_area:
	mov rsi, DS_SAVE_BASE
	call clear_4K_page64		; ����� debug store area

; ���� IA32_DS_AERA �Ĵ���
	mov ecx, IA32_DS_AREA
	mov eax, DS_SAVE_BASE		; DS �������ַ
	mov edx, 0
	wrmsr
	ret

;----------------------------------------------------------------
; set_ds_management_record() ���ù�������¼���� DS_SAVE_BASE
; input:
;		rsi - BTS buffer base
;		rdi - PEBS buffer base
; description:
;		ȱʡ����£�����Ϊ���λ�· buffer ��ʽ��
;		threshold ֵ���� maximum��������� DS buffer ����ж�
;--------------------------------------------------------------------
set_ds_management_record:
	push rbp
	mov rbp, rsp
	push rcx
	push rdx
	push rbx

	;; ���� 64 λ BTS ������
	mov [DS_SAVE_BASE + BTS64_BASE], rsi
	mov [DS_SAVE_BASE + BTS64_INDEX], rsi
	lea rax, [rsi + BTS_RECORD_MAXIMUM * 24]
	mov [DS_SAVE_BASE + BTS64_MAXIMUM], rax			; ����¼��Ϊ BTS_RECORD_MAXIMUM ֵ

	;; ����Ϊ���λ�· BTS buffer
	lea rax, [rsi + BTS_RECORD_CIRCULAR_THRESHOLD * 24]
	mov [DS_SAVE_BASE + BTS64_THRESHOLD], rax			; �ٽ�ֵ��¼��Ϊ BTS_RECORD_THRESHOLD ֵ

	;; ������ BTS �������� pointer ֵ
	mov rax, DS_SAVE_BASE + BTS64_BASE
	mov [bts_base_pointer], rax
	mov rax, DS_SAVE_BASE + BTS64_INDEX
	mov [bts_index_pointer], rax
	mov rax, DS_SAVE_BASE + BTS64_MAXIMUM
	mov [bts_maximum_pointer], rax
	mov rax, DS_SAVE_BASE + BTS64_THRESHOLD
	mov [bts_threshold_pointer], rax


	;; ���� 64 λ PEBS ������
	mov ecx, IA32_PERF_CAPABILITIES
	rdmsr
	shr eax, 8
	and eax, 0Fh			; �õ� IA32_PREF_CAPABILITIES[11:8]
	cmp eax, 0001B			; �����Ƿ�֧����ǿ�� PEBS ��ʽ
	je enhancement_pebs64
	mov DWORD [enhancement_pebs_flag], 0				; ��֧��, enhancement_pebs_flag ��־�� 0
	mov DWORD [pebs_record_length], 144
	lea rax, [rdi + PEBS_RECORD_MAXIMUM * 144]			; maximum ֵ
	lea rdx, [rdi + PEBS_RECORD_THRESHOLD * 144]
	jmp set_pebs64
enhancement_pebs64:
	;*
	;* ��ǿ�� PEBS ��ʽ��ÿ����¼�� 176 ���ֽ� *
	;*
	mov DWORD [enhancement_pebs_flag], 1				; ֧�֣�enhancement_pebs_flag ��־�� 1
	mov DWORD [pebs_record_length], 176
	lea rax, [rdi + PEBS_RECORD_MAXIMUM * 176]			; maximum ֵ
	lea rdx, [rdi + PEBS_RECORD_THRESHOLD * 176]			; threshold ֵ

set_pebs64:
	mov [DS_SAVE_BASE + PEBS64_BASE], rdi			; pebs buffer base
	mov [DS_SAVE_BASE + PEBS64_INDEX], rdi			; pebs buffer index
	mov [DS_SAVE_BASE + PEBS64_MAXIMUM], rax		; pebs buffer maximum		
	mov [DS_SAVE_BASE + PEBS64_THRESHOLD], rdx		; pebs buffer threshold

        ;*
        ;* ���� pebs index ֵ
        ;* ��Ϊ�ж� PEBS �ж�����
        ;*
        mov [pebs_buffer_index], rdi

	;; ���� counter reset
	mov rax, 0
	mov [DS_SAVE_BASE + PEBS64_COUNTER0], rax
	mov [DS_SAVE_BASE + PEBS64_COUNTER1], rax
	mov [DS_SAVE_BASE + PEBS64_COUNTER2], rax
	mov [DS_SAVE_BASE + PEBS64_COUNTER3], rax

	;; ������ PEBS ������ pointer
	mov rax, DS_SAVE_BASE + PEBS64_BASE
	mov [pebs_base_pointer], rax
	mov rax, DS_SAVE_BASE + PEBS64_INDEX
	mov [pebs_index_pointer], rax
	mov rax, DS_SAVE_BASE + PEBS64_MAXIMUM
	mov [pebs_maximum_pointer], rax
	mov rax, DS_SAVE_BASE + PEBS64_THRESHOLD
	mov [pebs_threshold_pointer], rax
	mov rax, DS_SAVE_BASE + PEBS64_COUNTER0
	mov [pebs_counter0_pointer], rax
	mov rax, DS_SAVE_BASE + PEBS64_COUNTER1
	mov [pebs_counter1_pointer], rax
	mov rax, DS_SAVE_BASE + PEBS64_COUNTER2
	mov [pebs_counter2_pointer], rax
	mov rax, DS_SAVE_BASE + PEBS64_COUNTER3
	mov [pebs_counter3_pointer], rax

        ; �� PEBS buffer ���ָʾλ OvfBuffer
        RESET_PEBS_BUFFER_OVERFLOW

set_ds_management_record_done:	
	pop rbx
	pop rdx
	pop rcx
	mov rsp, rbp
	pop rbp
	ret


;--------------------------------------------------------------
; test_bts_buffer_overflow(): �����Ƿ��� BTS buffer ����ж�
;--------------------------------------------------------------
test_bts_buffer_overflow:
        mov rax, [bts_index_pointer]
        mov rax, [rax]                          ; �� BTS index ֵ
        mov rsi, [bts_threshold_pointer]
        cmp rax, [rsi]                          ; �Ƚ� index >= threshold ?
        setae al
        movzx eax, al
        ret


;-----------------------------------------
; set_bts_buffer_size(): ���� BTS buffer ��¼��
; input:
;       esi-BTS buffer ���ɵļ�¼��
;-----------------------------------------
set_bts_buffer_size:
        push rcx
        push rdx

        mov ecx, BTS_RECORD64_SIZE
        imul esi, ecx                           ; count * sizeof(bts_record)
        mov rdi, [bts_maximum_pointer]
        mov rax, [bts_base_pointer]
        mov rax, [rax]                          ; ��ȡ BTS base ֵ
        add rsi, rax                            ; base + buffer size
        mov [rdi], rsi                          ; ���� bts maximum ֵ

        mov rdi, [bts_threshold_pointer]
        mov [rdi], rsi                          ; ���� bts thrshold ֵ
        mov rsi, rcx                            ; sizeof(bts_record)

        mov ecx, IA32_DEBUGCTL
        rdmsr 
        bt eax, BTINT_BIT                       ; �����Ƿ��� BTINT λ
        mov ecx, 0
        cmovc rsi, rcx                          ; ��������ˣ�bts threshold = bts maximum
                                                ; ���� bts threshold = bts maximum + sizeof(bts_record)
        add [rdi], rsi                          ; ���յ� bts threshold ֵ
        pop rdx
        pop rcx
        ret


set_int_bts_buffer_size:
        push rcx
        push rdx
        mov ecx, BTS_RECORD64_SIZE
        imul esi, ecx                           ; count * sizeof(bts_record)
        mov rdi, [bts_maximum_pointer]
        mov rax, [bts_base_pointer]
        mov rax, [rax]                          ; ��ȡ BTS base ֵ
        add rsi, rax                            ; base + buffer size
        mov [rdi], rsi                          ; ���� bts maximum ֵ
        mov rdi, [bts_threshold_pointer]
        mov [rdi], rsi                          ; ���� bts thrshold ֵ
        pop rdx
        pop rcx
        ret



;--------------------------------------------------
; set_pebs_buffer_size(): ���� PEBS buffer ��������
; input:
;       esi-PEBS buffer ���ɵļ�¼��
;---------------------------------------------------
set_pebs_buffer_size:
        push rcx
        cmp DWORD [enhancement_pebs_flag], 1            ; �����Ƿ�֧����ǿ�� PEBS ��¼��ʽ
        mov ecx, PEBS_ENHANCEMENT_RECORD64_SIZE
        mov edi, PEBS_RECORD64_SIZE
        cmovne ecx, edi                                  
        imul esi, ecx                                   ; count * size(pebs_record)
        mov rdi, [pebs_maximum_pointer]
        mov rax, [pebs_base_pointer]
        mov rax, [rax]                                  ; ��ȡ pebs base ֵ
        add rsi, rax                                    ; base + buffer_size
        mov [rdi], rsi                                  ; ���� pebs maximum
        mov rdi, [pebs_threshold_pointer]
        mov [rdi], rsi                                  ; ���� pebs threshold ֵ
        pop rcx
        ret


;----------------------------------------------
; reset_bts_index(): ���� BTS index Ϊ base ֵ
;----------------------------------------------
reset_bts_index:
        mov rdi, [bts_index_pointer]
        mov rsi, [bts_base_pointer]
        mov rsi, [rsi]                                  ; ��ȡ BTS base ֵ
        mov [rdi], rsi                                  ; BTS index = BTS base
        ret

;----------------------------------------------
; reset_pebs_index()������ PEBS index ֵΪ base
;----------------------------------------------
reset_pebs_index:
        mov rdi, [pebs_index_pointer]       
        mov rsi, [pebs_base_pointer]
        mov rsi, [rsi]                                  ; ��ȡ PEBS base ֵ
        mov [rdi], rsi                                  ; PEBS index = PEBS base
        mov [pebs_buffer_index], rsi                    ; ���±���� PEBS index ֵ
        ret


;------------------------------------------------------------
; update_pebs_index_track(): ����PEBS index �Ĺ켣
; ������
;       ���� [pebs_buffer_index]������ֵ�����ּ�� PEBS �ж�
;       [pebs_buffer_index] ��¼�š���ǰ���� PEBS index ֵ
;------------------------------------------------------------
update_pebs_index_track:
        mov rax, [pebs_index_pointer]
        mov rax, [rax]                                  ; ����ǰ pebs index ֵ
        mov [pebs_buffer_index], rax                    ; ���±���� pebs index ֵ        
        ret



;-----------------------------
; ��ӡ BTS ����������
;----------------------------
dump_ds_management:
	jmp do_dump_ds_management
dbm_msg1	db 'BTS base:      ', 0
dbm_msg2	db 'BTS index:     ', 0
dbm_msg3	db 'BTS maximum:   ', 0
dbm_msg4	db 'BTS threshold: ', 0

dbm_msg5	db 'PEBS base:      ', 0
dbm_msg6	db 'PEBS index:     ', 0
dbm_msg7	db 'PEBS maximum:   ', 0
dbm_msg8	db 'PEBS threshold: ', 0

dbm_msg0	db '       ', 0
do_dump_ds_management:	
	push rcx
	push rdx
	push rbx


;; �����ӡ DS ��������¼	
	mov esi, dbm_msg1
	LIB32_PUTS_CALL
	mov rax, [bts_base_pointer]
	mov esi, [rax]
	mov edi, [rax + 4]
	LIB32_PRINT_QWORD_VALUE_CALL		; ��ӡ bts base
	mov esi, dbm_msg0
	LIB32_PUTS_CALL
	mov esi, dbm_msg5
	LIB32_PUTS_CALL
	mov rax, [pebs_base_pointer]
	mov esi, [rax]
	mov edi, [rax + 4]
	LIB32_PRINT_QWORD_VALUE_CALL		; ��ӡ pebs base
	LIB32_PRINTLN_CALL
	mov esi, dbm_msg2
	LIB32_PUTS_CALL
	mov rax, [bts_index_pointer]
	mov esi, [rax]
	mov edi, [rax + 4]
	LIB32_PRINT_QWORD_VALUE_CALL		; ��ӡ bts index
	mov esi, dbm_msg0
	LIB32_PUTS_CALL
	mov esi, dbm_msg6
	LIB32_PUTS_CALL
	mov rax, [pebs_index_pointer]
	mov esi, [rax]
	mov edi, [rax + 4]
	LIB32_PRINT_QWORD_VALUE_CALL		; ��ӡ pebs index
	LIB32_PRINTLN_CALL
	mov esi, dbm_msg3
	LIB32_PUTS_CALL
	mov rax, [bts_maximum_pointer]
	mov esi, [rax]
	mov edi, [rax + 4]
	LIB32_PRINT_QWORD_VALUE_CALL		; ��ӡ bts maximum
	mov esi, dbm_msg0
	LIB32_PUTS_CALL
	mov esi, dbm_msg7
	LIB32_PUTS_CALL
	mov rax, [pebs_maximum_pointer]
	mov esi, [rax]
	mov edi, [rax + 4]
	LIB32_PRINT_QWORD_VALUE_CALL		; ��ӡ pebs maximum
	LIB32_PRINTLN_CALL
	mov esi, dbm_msg4
	LIB32_PUTS_CALL
	mov rax, [bts_threshold_pointer]
	mov esi, [rax]
	mov edi, [rax + 4]
	LIB32_PRINT_QWORD_VALUE_CALL		; ��ӡ bts threshold
	mov esi, dbm_msg0
	LIB32_PUTS_CALL
	mov esi, dbm_msg8
	LIB32_PUTS_CALL
	mov rax, [pebs_threshold_pointer]
	mov esi, [rax]
	mov edi, [rax + 4]
	LIB32_PRINT_QWORD_VALUE_CALL		; ��ӡ pebs threshold
	LIB32_PRINTLN_CALL
	
dump_ds_management_done:	
	pop rbx
	pop rdx
	pop rcx
	ret



;--------------------------------------
;��ӡ BTS ��¼
;--------------------------------------
dump_bts_record:
	jmp do_dump_bts_record
br_msg1	db  '----------------------------- BTS64 Record -------------------------------', 10, 0
br_msg2 db  ' <-- INDEX  ', 0
br_msg3 db  '<BTS threshold> :', 10, 0
br_msg4 db  '------------------------------------------------------------------------', 10, 0
br_msg5 db  'from_ip_', 0
br_msg6 db  'to_ip_', 0
br_msg7 db  '            ', 0
do_dump_bts_record:
	push rcx
	push rdx
	push rbx
	push r10

	; ��ӡ��ͷ
	mov esi, br_msg1
	LIB32_PUTS_CALL

	mov rax, [bts_maximum_pointer]
	mov r10, [rax]				; ȡ BTS maximum ֵ
	mov rax, [bts_threshold_pointer]
	cmp r10, [rax]				; maximum �� threshold �Ƚ�
	cmovb r10, [rax]			; �ҳ� maximum �� threshold �����ֵ

	mov rax, [bts_base_pointer]
	mov rbx, [rax]				; ȡ BTS base ֵ


; ���ڣ�rbx = base ֵ��r10 = BTS buffer ���ֵ

	xor rcx, rcx
dump_bts_record_loop:
	cmp rbx, r10				; �Ƿ� >= BTS maximum �� BTS threshold ?
	jg do_dump_bts_record_done
	

	; �����Ƿ����� BTS maximum
	mov rax, [bts_maximum_pointer]
	cmp rbx, [rax]
	jne dump_bts_record_next
	mov esi, br_msg4
	LIB32_PUTS_CALL

dump_bts_record_next:

; ��ӡ threshold ��Ϣ
	mov rax, [bts_threshold_pointer]
	cmp rbx, [rax]				; �Ƿ�Ϊ threshold ֵ
	mov esi, 0
	mov edi, br_msg3
	cmove esi, edi
	LIB32_PUTS_CALL

	mov esi, br_msg5
	LIB32_PUTS_CALL					
	cmp rcx, 10
	mov eax, LIB32_PRINT_BYTE_VALUE
	mov esi, LIB32_PRINT_DWORD_DECIMAL
	cmovge eax, esi
	mov esi, ecx,
	call lib32_service	

	mov esi, fs_msg3
	LIB32_PUTS_CALL
	mov esi, [rbx]					; from_ip
	mov edi, [rbx + 4]
	LIB32_PRINT_QWORD_VALUE_CALL

	mov rax, [bts_index_pointer]
	cmp rbx, [rax]					; ��ǰ�Ƿ�Ϊ index ֵ
	mov eax, br_msg7
	mov esi, br_msg2
	cmovne esi, eax
	LIB32_PUTS_CALL

	mov esi, br_msg6
	LIB32_PUTS_CALL
	mov eax, LIB32_PRINT_BYTE_VALUE
	mov esi, LIB32_PRINT_DWORD_DECIMAL
	cmp ecx, 10
	cmovge eax, esi
	mov esi, ecx
	call lib32_service
	mov esi, fs_msg3
	LIB32_PUTS_CALL
	mov esi, [rbx + 8]				; to_ip
	mov edi, [rbx + 12]
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL
	
	add rbx, 24
	inc rcx
	jmp dump_bts_record_loop

do_dump_bts_record_done:
	pop r10
	pop rbx
	pop rdx
	pop rcx
	ret
	

;-----------------------------------------
; dump_reg64(): ��ӡͨ�üĴ�����
;-----------------------------------------
dump_reg64:
        jmp do_dump_reg64
reg64_offset    dq RAX_OFFSET, RBX_OFFSET, RCX_OFFSET, RDX_OFFSET, RSI_OFFSET, RDI_OFFSET, RBP_OFFSET, RSP_OFFSET
                dq R8_OFFSET, R9_OFFSET, R10_OFFSET, R11_OFFSET, R12_OFFSET, R13_OFFSET, R14_OFFSET, R15_OFFSET
new_line        db 10, 0
do_dump_reg64:
        push rbx
        push rcx
        STORE_CONTEXT64
        mov rbx, context64_flags + 8
        xor rcx, rcx
do_dump_reg64_loop:
        mov esi, [rbx + rcx * 4]
        LIB32_PUTS_CALL
        mov rax, [reg64_offset + rcx * 8]
        mov esi, [rax + CONTEXT_POINTER64]
        mov edi, [rax + CONTEXT_POINTER64 + 4]
        LIB32_PRINT_QWORD_VALUE_CALL
        test rcx, 1
        mov edi, new_line
        mov esi, dpr_msg2
        cmovnz esi, edi
        LIB32_PUTS_CALL
        inc rcx
        cmp rcx, 16
        jb do_dump_reg64_loop
        pop rcx
        pop rbx
        ret


;---------------------------------------------
; dump_pebs_record()����ӡ���һ�� PEBS ��¼
;---------------------------------------------
dump_pebs_record:
	jmp do_dump_pebs_record
dpr_msg	db '---------------- last PEBS record -------------------', 10, 0
dpr_msg1 db '*** no record ****', 10, 0
dpr_msg2 db '      ', 0
dpr_msg3 db '------------------------ <END> ----------------------', 10, 0
dpr_msg4 db '<enhancement PEBS record>:', 10, 0
context64_flags	dd rflags_msg, rip_msg, rax_msg, rbx_msg, rcx_msg, rdx_msg, rsi_msg
		dd rdi_msg, rbp_msg, rsp_msg
		dd r8_msg, r9_msg, r10_msg, r11_msg, r12_msg, r13_msg, r14_msg, r15_msg, 0
enhancement_flags dd perf_global_status_msg, data_linear_address_msg, data_source_encoding_msg, latency_value_msg, 0

do_dump_pebs_record:
	push rcx
	push rdx
	push rbx
	push r10

	mov esi, dpr_msg
	LIB32_PUTS_CALL


	mov rax, [pebs_index_pointer]
	mov r10, [rax]
	mov rax, [pebs_base_pointer]
	cmp r10, [rax]			; index �� base �Ƚ�
	ja dump_pebs_record_next
	mov esi, dpr_msg1
	LIB32_PUTS_CALL
	jmp dump_pebs_record_done

dump_pebs_record_next:
	sub r10, [pebs_record_length]
	mov rbx, context64_flags

dump_pebs_record_loop:
	mov esi, [rbx]
	LIB32_PUTS_CALL
	mov esi, [r10]
	mov edi, [r10 + 4]
	LIB32_PRINT_QWORD_VALUE_CALL
	mov esi, dpr_msg2
	LIB32_PUTS_CALL
	add rbx, 4
	mov esi, [rbx]
	LIB32_PUTS_CALL
	mov esi, [r10 + 8]
	mov edi, [r10 + 12]
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL
	add r10, 16
	add rbx, 4
	cmp DWORD [rbx], 0
	jne dump_pebs_record_loop

	;; �Ƿ�Ϊ��ǿ PEBS ��¼
	cmp DWORD [enhancement_pebs_flag], 1
	jne dump_pebs_record_done
        
        mov esi, dpr_msg4
        LIB32_PUTS_CALL
	mov rbx, enhancement_flags
dump_enhancement_pebs:
	mov esi, [rbx]
	LIB32_PUTS_CALL
	mov esi, [r10]
	mov edi, [r10 + 4]
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL
	add r10, 8
	add rbx, 4
	cmp DWORD [rbx], 0
	jnz dump_enhancement_pebs

dump_pebs_record_done:
        mov esi, dpr_msg3
        LIB32_PUTS_CALL
        pop r10
	pop rbx
	pop rdx
	pop rcx
	ret



;-----------------------
; ��ӡ���� LBR stack
;-----------------------
dump_lbr_stack:
	jmp do_dump_lbr_stack
fs_msg0	db 10, '---------------------- LBR STACK ', 0	
fs_msg1	db 'from_', 0
fs_msg3	db ': 0x', 0
fs_msg2	db '  <-- TOP -->  ', 0
fs_msg4	db '               ', 0
fs_msg5	db 'to_', 0
fs_msg6	db '(00:32-bit) --------------------------', 10, 0
fs_msg7 db '(01:64 LIP) --------------------------', 10, 0
fs_msg8 db '(10:64 EIP) --------------------------', 10, 0
fs_msg9 db '(11:64 EIP and flags) ----------------', 10, 0
address_format_falgs	dd fs_msg6, fs_msg7, fs_msg8, fs_msg9, 0
do_dump_lbr_stack:
	push rcx
	push rdx	
	push r10
	push r12
	
	xor r12d, r12d
	mov r10d, LIB32_PRINT_DWORD_DECIMAL

	mov esi, fs_msg0
	LIB32_PUTS_CALL
	mov ecx, IA32_PERF_CAPABILITIES
	rdmsr
	and eax, 0x3f
	mov esi, [eax * 4 + address_format_falgs]
	LIB32_PUTS_CALL
	
; ��ӡ��Ϣ
dump_lbr_stack_loop:

	mov esi, fs_msg1
	LIB32_PUTS_CALL
	mov esi, r12d
	mov eax, LIB32_PRINT_BYTE_VALUE
	cmp r12d, 10
	cmovae eax, r10d
	call lib32_service
	mov esi, fs_msg3
	LIB32_PUTS_CALL

; ��ӡ from ip
	lea ecx, [r12d + MSR_LASTBRANCH_0_FROM_IP]
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL

	mov ecx, MSR_LASTBRANCH_TOS
	rdmsr
	cmp eax, r12d
	jnz dump_lbr_from_stack_next
	mov esi, fs_msg2
	LIB32_PUTS_CALL
	jmp dump_lbr_to_stack
dump_lbr_from_stack_next:
	mov esi, fs_msg4
	LIB32_PUTS_CALL

;; ��ӡ to ip
dump_lbr_to_stack:
	mov esi, fs_msg5
	LIB32_PUTS_CALL
	mov esi, r12d
	mov eax, LIB32_PRINT_BYTE_VALUE
	cmp r12d, 10
	cmovae eax, r10d
	call lib32_service
	mov esi, fs_msg3
	LIB32_PUTS_CALL

	lea ecx, [r12d + MSR_LASTBRANCH_0_TO_IP]
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL

	
dump_lbr_stack_next:
	LIB32_PRINTLN_CALL
	inc r12d
	cmp r12d, 16
	jb dump_lbr_stack_loop
	LIB32_PRINTLN_CALL

	pop r12
	pop r10
	pop rdx
	pop rcx
	ret

;-----------------------------
; ��ӡ last exception from/to
;-----------------------------
dump_last_exception:
	mov esi, last_exception_from
	LIB32_PUTS_CALL
	mov ecx, MSR_LER_FROM_LIP
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL
	mov esi, last_exception_to
	LIB32_PUTS_CALL
	mov ecx, MSR_LER_TO_LIP
	rdmsr
	mov esi, eax
	mov edi, edx
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL
	ret
	
;-------------------------------
; ��ӡ IA32_DEBUGCTL �Ĵ���
;-------------------------------
dump_debugctl:
	mov esi, debugctl_msg
	LIB32_PUTS_CALL
	mov ecx, IA32_DEBUGCTL
	rdmsr
	mov esi, eax
	shl esi, 17
	LIB32_REVERSE_CALL
	mov esi, eax
	mov edi, debugctl_flags
	LIB32_DUMP_FLAGS_CALL
	LIB32_PRINTLN_CALL
	ret


;-----------------------
; ��ӡ DR0-DR3 �Ĵ���
;----------------------
dump_drs:
	mov esi, dr0_msg
	LIB32_PUTS_CALL
	mov rsi, dr0
	mov rdi, rsi
	shr rdi, 32
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTBLANK_CALL
	mov esi, dr1_msg
	LIB32_PUTS_CALL
	mov rsi, dr1
	mov rdi, rsi
	shr rdi, 32
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL	
	mov esi, dr2_msg
	LIB32_PUTS_CALL
	mov rsi, dr2
	mov rdi, rsi
	shr rdi, 32
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTBLANK_CALL	
	mov esi, dr3_msg
	LIB32_PUTS_CALL
	mov rsi, dr3
	mov rdi, rsi
	shr rdi, 32
	LIB32_PRINT_QWORD_VALUE_CALL
	LIB32_PRINTLN_CALL	
	ret
	
;-----------------------
; ��ӡ DR6 �Ĵ���
;-----------------------
dump_dr6:
	mov esi, dr6_msg
	LIB32_PUTS_CALL
	mov rsi, dr6
	LIB32_REVERSE_CALL
	mov esi, eax
	mov edi, dr6_flags
	LIB32_DUMP_FLAGS_CALL
	LIB32_PRINTLN_CALL
	ret

;-------------------------------------------
; dump_dr6_flags(): ��ӡ DR6 ��־ʹ�������ֵ
; input:
;		esi: ����ֵ
;-------------------------------------------
dump_dr6_flags:
	push rcx
	mov ecx, esi
	mov esi, dr6_msg
	LIB32_PUTS_CALL
	mov esi, ecx
	LIB32_REVERSE_CALL
	mov esi, eax
	mov edi, dr6_flags
	LIB32_DUMP_FLAGS_CALL
	LIB32_PRINTLN_CALL	
	pop rcx
	ret


;----------------------------
; ��ӡ dr7 �Ĵ���
;----------------------------
dump_dr7:
	push r10	
	push r12
	
	mov r10, dr7
	shl r10, 32
	mov r12, len_rw_flags
	mov esi, dr7_msg
	LIB32_PUTS_CALL
dump_len_rw:	
	mov esi, [r12]
	cmp esi, -1
	je dump_dr7_next
	LIB32_PUTS_CALL
	rol r10, 2
	mov rsi, r10
	and rsi, 0x3
	LIB32_PRINT_DWORD_DECIMAL_CALL
	LIB32_PRINTBLANK_CALL
	add r12, 4
	jmp dump_len_rw
	
dump_dr7_next:		
	mov rsi, dr7
	shl rsi, 18
	LIB32_REVERSE_CALL
	mov esi, eax
	mov edi, enable_flags
	LIB32_DUMP_FLAGS_CALL
	LIB32_PRINTLN_CALL
	pop r12
	pop r10 	
	ret
	
;***** ������ *********

;;; �����Ǵ�Ź�������ַ
bts_base_pointer	dq 0
bts_index_pointer	dq 0
bts_maximum_pointer	dq 0
bts_threshold_pointer	dq 0
pebs_base_pointer	dq 0
pebs_index_pointer	dq 0
pebs_maximum_pointer	dq 0
pebs_threshold_pointer	dq 0
pebs_counter0_pointer	dq 0
pebs_counter1_pointer	dq 0
pebs_counter2_pointer	dq 0
pebs_counter3_pointer	dq 0

; ��������¼ֵ
bts_buffer_base		dq 0
bts_buffer_index	dq 0
bts_buffer_maximum	dq 0
bts_buffer_threshold	dq 0
pebs_buffer_base	dq 0
pebs_buffer_index	dq 0
pebs_buffer_maximum	dq 0
pebs_buffer_threshold	dq 0
pebs_record_length	dq 0
enhancement_pebs_flag	dq 0


;; �Ĵ���ԭ����ֵ
debugctl_value		dq 0
pebs_enable_value	dq 0


;; 64 λ�� context �����ַ
debug_context64	times 20 dq 0

; 64 λ context
rflags_msg	db 'RFLAGS: ', 0
rip_msg		db 'RIP: ', 0
rax_msg		db 'RAX: ', 0
rcx_msg		db 'RCX: ', 0
rdx_msg		db 'RDX: ', 0
rbx_msg		db 'RBX: ', 0
rsp_msg		db 'RSP: ', 0
rbp_msg		db 'RBP: ', 0
rsi_msg		db 'RSI: ', 0
rdi_msg		db 'RDI: ', 0
r8_msg		db 'R8:  ', 0
r9_msg		db 'R9:  ', 0
r10_msg		db 'R10: ', 0
r11_msg		db 'R11: ', 0
r12_msg		db 'R12: ', 0
r13_msg		db 'R13: ', 0
r14_msg		db 'R14: ', 0
r15_msg		db 'R15: ', 0
perf_global_status_msg		db 'IA32_PERF_GLOBAL_STATUS: ', 0
data_linear_address_msg		db 'data linear address:     ', 0
data_source_encoding_msg	db 'data source encoding:    ', 0
latency_value_msg		db 'latency value:           ', 0




last_exception_from		db 'last_exception_from: 0x', 0
last_exception_to		db ' last_exception_to: 0x', 0

debugctl_msg	db '<IA32_DEBUGCTL:> ', 0

lbr_msg					db 'lbr', 0
btf_msg					db 'btf', 0
tr_msg					db 'tr', 0
bts_msg					db 'bts', 0
btint_msg				db 'btint', 0
bts_off_os				db 'bts_off_os', 0
bts_off_usr				db 'bts_off_usr', 0
freeze_lbrs_on_pmi		db 'freeze_lbrs_on_pmi', 0
freeze_perfmon_on_pmi	db 'freeze_perfmon_on_pmi', 0
uncore_pmi_en			db 'uncore_pmi_en', 0
freeze_while_smm_en		db 'freeze_while_smm_en', 0

debugctl_flags		dd freeze_while_smm_en, uncore_pmi_en, freeze_perfmon_on_pmi, freeze_lbrs_on_pmi
					dd bts_off_usr, bts_off_os, btint_msg, bts_msg, tr_msg, 0, 0, 0, 0, btf_msg, lbr_msg, -1


dr0_msg	db	'<DR0:> ',0
dr1_msg	db	'<DR1:> ', 0
dr2_msg	db 	'<DR2:> ', 0
dr3_msg	db	'<DR3:> ', 0

;������ dr6 �ı�־λ
b0_msg	db 'b0', 0
b1_msg	db 'b1', 0
b2_msg	db 'b2', 0
b3_msg	db 'b3', 0
bd_msg	db 'bd', 0
bs_msg	db 'bs', 0
bt_msg	db 'bt', 0
dr6_msg	db '<DR6:> ', 0
dr6_flags	dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			dd bt_msg, bs_msg, bd_msg, 0, 0, 0, 0, 0, 0, 0, 0, 0, b3_msg, b2_msg, b1_msg, b0_msg,  -1
			
			
;; ������ dr7 �ı�־λ
dr7_msg		db '<DR7:> ',0
rw0_msg		db 'RW0:', 0
rw1_msg		db 'RW1:', 0
rw2_msg		db 'RW2:', 0
rw3_msg		db 'RW3:', 0
len0_msg	db 'L0:', 0
len1_msg	db 'L1:', 0
len2_msg	db 'L2:', 0
len3_msg	db 'L3:', 0
gd_msg		db 'gd', 0
ge_msg		db 'ge', 0
le_msg		db 'le', 0
l0_msg		db 'l0', 0	
l1_msg		db 'l1', 0
l2_msg		db 'l2', 0
l3_msg		db 'l3', 0
g0_msg		db 'g0', 0
g1_msg		db 'g1', 0
g2_msg		db 'g2', 0
g3_msg		db 'g3', 0
len_rw_flags	dd	len3_msg, rw3_msg, len2_msg, rw2_msg, len1_msg, rw1_msg, len0_msg, rw0_msg, -1
enable_flags	dd	gd_msg, 0, 0, 0, 0, 0		;;; , ge_msg, le_msg
				dd	g3_msg, l3_msg, g2_msg, l2_msg, g1_msg, l1_msg, g0_msg, l0_msg, -1
					
