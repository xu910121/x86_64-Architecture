; debug.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


;*
;* ����Ϊ֧�� debug ���ܶ���ĺ�����
;*




;---------------------------------
; ���� BTS
;--------------------------------
enable_bts:
enable_branch_trace_store:
	call available_bts
	test eax, eax
	jz enable_branch_trace_store_done
	mov ecx, IA32_DEBUGCTL
	rdmsr
	or eax, 0C0h					; TR=1, BTS=1
	wrmsr
enable_branch_trace_store_done:	
	ret
	
;--------------------------------
; �ر� BTS
;--------------------------------
disable_bts:
	mov ecx, IA32_DEBUGCTL
	rdmsr
	and eax, 0FF3Fh				; TR=0, BTS=0
	wrmsr
	ret


;------------------------
;support_debug_store(): ��ѯ�Ƿ�֧�� DS ����
; output:
;		1-support, 0-no support
;------------------------
support_ds:
support_debug_store:
	mov eax, 1
	cpuid
	bt edx, 21				; DS λ
	setc al
	movzx eax, al
	ret

;------------------------------------
; support_ds64: ��ѯ�Ƿ�֧�� DS save 64 λ��ʽ
; output:
;		1-support, 0-no support
;-----------------------------------
support_ds64:
	mov eax, 1
	cpuid
	bt ecx, 2				; DEST64 λ
	setc al
	movzx eax, al
	ret


;---------------------------------
; available_branch_trace_store():
; output:
;		1-available, 0-unavailable
;---------------------------------
available_bts:
available_branch_trace_store:
	mov eax, 1
	cpuid
	bt edx, 21
	setc al
	jnc available_branch_trace_store_done		; no-support
	mov ecx, IA32_MISC_ENABLE
	rdmsr
	bt eax, 11					; BTS unavailable λ
	setnc al
available_branch_trace_store_done:	
	movzx eax, al
	ret


;--------------------------------------
; avaiable_pebs(): �Ƿ�֧�� PEBS ����
; output:
;		1-available, 0-unavailable
;--------------------------------------
available_pebs:
	mov eax, 1
	cpuid
	bt edx, 21
	setc al
	jnc available_pebs_done
	mov ecx, IA32_MISC_ENABLE
	rdmsr
	bt eax, 12					; PEBS unavailable λ
	setnc al
available_pebs_done:
	movzx eax, al
	ret

;------------------------------------------------------------
; support_enhancement_pebs(): ����Ƿ�֧����ǿ�� PEBS ��¼
; output:
;	1-support, 0-no support
;-----------------------------------------------------------
support_enhancement_pebs:
	mov ecx, IA32_PERF_CAPABILITIES
	rdmsr
	shr eax, 8
	and eax, 0Fh			; �õ� IA32_PREF_CAPABILITIES[11:8]
	cmp eax, 0001B			; �����Ƿ�֧����ǿ�� PEBS ��ʽ
	sete al
	movzx eax, al
	ret


;----------------------------------------------
; dump_support_ds(): ���Դ������� DS �� BTS, PEBS ֧�ֶ�
;-----------------------------------------------
dump_support_ds:
	jmp do_dump_support_ds
dsd_msg0	db 'support DS:     ', 0
dsd_msg1	db 'support DS64:   ', 0
dsd_msg2	db 'available BTS:  ', 0
dsd_msg3	db 'available PEBS: ', 0
dsd_yes		db 'yes', 10,0
dsd_no		db 'no', 10, 0
do_dump_support_ds:
; ���� DS
	mov esi, dsd_msg0
	call puts
	call support_ds
	mov esi, dsd_yes
	mov edi, dsd_no
	test eax, eax
	cmovz esi, edi
	call puts
; ���� DS64
	mov esi, dsd_msg1
	call puts
	call support_ds64
	mov esi, dsd_yes
	mov edi, dsd_no
	test eax, eax
	cmovz esi, edi
	call puts
; ���� BTS
	mov esi, dsd_msg2
	call puts
	call available_bts
	mov esi, dsd_yes
	mov edi, dsd_no
	test eax, eax
	cmovz esi, edi
	call puts
; ���� PEBS
	mov esi, dsd_msg3
	call puts
	call available_pebs
	mov esi, dsd_yes
	mov edi, dsd_no
	test eax, eax
	cmovz esi, edi
	call puts
	ret


;-------------------------------------------
; set_debug_store_area(): ���� DS �������ַ
;-------------------------------------------
set_debug_store_area:
	mov esi, DS_SAVE_BASE
	call clear_4K_page		; ����� debug store area

; ���� IA32_DS_AERA �Ĵ���
	mov ecx, IA32_DS_AREA
	mov eax, DS_SAVE_BASE		; DS �������ַ
	mov edx, 0
	wrmsr
	ret

;----------------------------------------------------------------
; set_ds_management_record() ���ù�������¼���� DS_SAVE_BASE
; input:
;		esi - BTS buffer base
;		edi - PEBS buffer base
; description:
;		ȱʡ����£�����Ϊ���λ�· buffer ��ʽ��
;		threshold ֵ���� maximum��������� DS buffer ����ж�
;--------------------------------------------------------------------
set_ds_management_record:
	push ebp
	mov ebp, esp
	push ecx
	push edx
	push ebx

;; �����Ƿ�֧�� 64λ�� DS save ��ʽ	
	mov eax, 1
	cpuid
	bt ecx, 2						; DEST64 λ
	jc set_ds_management_record64
	
	mov DWORD [ds64_flag], 0					; DS64 ��֧�֣�ds64_flags ��־��0
        mov DWORD [enhancement_pebs_flag], 0				; ��֧��, enhancement_pebs_flag ��־�� 0

	;; ���� 32λ�� BTS ��ʽ
	mov DWORD [DS_SAVE_BASE + BTS_BASE], esi
	mov DWORD [DS_SAVE_BASE + BTS_INDEX], esi
	lea eax, [esi + BTS_RECORD_MAXIMUM * 12]
	mov DWORD [DS_SAVE_BASE + BTS_MAXIMUM], eax			; ����¼��Ϊ BTS_RECORD_MAXIMUM ֵ		

	; ����Ϊ���λ�· BTS buffer
	lea eax, [esi + BTS_RECORD_CIRCULAR_THRESHOLD * 12]
	mov DWORD [DS_SAVE_BASE + BTS_THRESHOLD], eax			; �ٽ�ֵ��¼��Ϊ BTS_RECORD_THRESHOLD ֵ

	
	;; ���� 32 λ�� PEBS ��ʽ
	mov DWORD [DS_SAVE_BASE + PEBS_BASE], edi			; pebs buffer base
	mov DWORD [DS_SAVE_BASE + PEBS_INDEX], edi			; pebs buffer index
        mov DWORD [pebs_buffer_index], edi                              ; ���� index ֵ
	lea eax, [edi + PEBS_RECORD_MAXIMUM * 40]			; base + m * 40
	mov DWORD [DS_SAVE_BASE + PEBS_MAXIMUM], eax			; pebs buffer maximum
	lea eax, [edi + PEBS_RECORD_THRESHOLD * 40]			; base + t * 40
	mov DWORD [DS_SAVE_BASE + PEBS_THRESHOLD], eax			; pebs buffer threshold
	mov DWORD [DS_SAVE_BASE + PEBS_COUNTER0], 0
	mov DWORD [DS_SAVE_BASE + PEBS_COUNTER1], 0
	mov DWORD [DS_SAVE_BASE + PEBS_COUNTER2], 0
	mov DWORD [DS_SAVE_BASE + PEBS_COUNTER3], 0

	;; ������ BTS �������� pointer ֵ
	mov DWORD [bts_base_pointer], DS_SAVE_BASE + BTS_BASE
	mov DWORD [bts_index_pointer], DS_SAVE_BASE + BTS_INDEX
	mov DWORD [bts_maximum_pointer], DS_SAVE_BASE + BTS_MAXIMUM
	mov DWORD [bts_threshold_pointer], DS_SAVE_BASE + BTS_THRESHOLD

	;; ������ PEBS ������ pointer 
	mov DWORD [pebs_base_pointer], DS_SAVE_BASE + PEBS_BASE
	mov DWORD [pebs_index_pointer], DS_SAVE_BASE + PEBS_INDEX
	mov DWORD [pebs_maximum_pointer], DS_SAVE_BASE + PEBS_MAXIMUM
	mov DWORD [pebs_threshold_pointer], DS_SAVE_BASE + PEBS_THRESHOLD
	mov DWORD [pebs_counter0_pointer], DS_SAVE_BASE + PEBS_COUNTER0
	mov DWORD [pebs_counter1_pointer], DS_SAVE_BASE + PEBS_COUNTER1
	mov DWORD [pebs_counter2_pointer], DS_SAVE_BASE + PEBS_COUNTER2
	mov DWORD [pebs_counter3_pointer], DS_SAVE_BASE + PEBS_COUNTER3

	jmp set_ds_management_record_done

set_ds_management_record64:	
	mov DWORD [ds64_flag], 1					; DS64 ֧��, ds64_flags ��־�� 1

	;; ���� 64 λ BTS ������
	mov DWORD [DS_SAVE_BASE + BTS64_BASE], esi
	mov DWORD [DS_SAVE_BASE + BTS64_BASE + 4], 0
	mov DWORD [DS_SAVE_BASE + BTS64_INDEX], esi
	mov DWORD [DS_SAVE_BASE + BTS64_INDEX + 4], 0
	lea eax, [esi + BTS_RECORD_MAXIMUM * 24]
	mov DWORD [DS_SAVE_BASE + BTS64_MAXIMUM], eax			; ����¼��Ϊ BTS_RECORD_MAXIMUM ֵ
	mov DWORD [DS_SAVE_BASE + BTS64_MAXIMUM + 4], 0

	;; ����Ϊ���λ�· BTS buffer
	lea eax, [esi + BTS_RECORD_CIRCULAR_THRESHOLD * 24]
	mov DWORD [DS_SAVE_BASE + BTS64_THRESHOLD], eax			; �ٽ�ֵ��¼��Ϊ BTS_RECORD_THRESHOLD ֵ
	mov DWORD [DS_SAVE_BASE + BTS64_THRESHOLD + 4], 0

	;; ������ BTS �������� pointer ֵ
	mov DWORD [bts_base_pointer], DS_SAVE_BASE + BTS64_BASE
	mov DWORD [bts_index_pointer], DS_SAVE_BASE + BTS64_INDEX
	mov DWORD [bts_maximum_pointer], DS_SAVE_BASE + BTS64_MAXIMUM
	mov DWORD [bts_threshold_pointer], DS_SAVE_BASE + BTS64_THRESHOLD

        
	;; ���� 64 λ PEBS ������
	mov ecx, IA32_PERF_CAPABILITIES
	rdmsr
	shr eax, 8
	and eax, 0Fh			; �õ� IA32_PREF_CAPABILITIES[11:8]
	cmp eax, 0001B			; �����Ƿ�֧����ǿ�� PEBS ��ʽ
	je enhancement_pebs64
	mov DWORD [enhancement_pebs_flag], 0				; ��֧��, enhancement_pebs_flag ��־�� 0
	mov DWORD [pebs_record_length], 144
	lea eax, [edi + PEBS_RECORD_MAXIMUM * 144]			; maximum ֵ
	lea edx, [edi + PEBS_RECORD_THRESHOLD * 144]
	jmp set_pebs64
enhancement_pebs64:
	;*
	;* ��ǿ�� PEBS ��ʽ��ÿ����¼�� 176 ���ֽ� *
	;*
	mov DWORD [enhancement_pebs_flag], 1				; ֧�֣�enhancement_pebs_flag ��־�� 1
	mov DWORD [pebs_record_length], 176
	lea eax, [edi + PEBS_RECORD_MAXIMUM * 176]			; maximum ֵ
	lea edx, [edi + PEBS_RECORD_THRESHOLD * 176]			; threshold ֵ

set_pebs64:
	mov DWORD [DS_SAVE_BASE + PEBS64_BASE], edi			; pebs buffer base
	mov DWORD [DS_SAVE_BASE + PEBS64_BASE + 4], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_INDEX], edi			; pebs buffer index
	mov DWORD [DS_SAVE_BASE + PEBS64_INDEX + 4], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_MAXIMUM], eax			; pebs buffer maximum		
	mov DWORD [DS_SAVE_BASE + PEBS64_MAXIMUM + 4], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_THRESHOLD], edx		; pebs buffer threshold
	mov DWORD [DS_SAVE_BASE + PEBS64_THRESHOLD + 4], 0

        ;*
        ;* ���� pebs index ֵ
        ;* ��Ϊ�ж� PEBS �ж�����
        ;*
        mov DWORD [pebs_buffer_index], edi
        mov DWORD [pebs_buffer_index + 4], 0

	;; ���� counter reset
	mov DWORD [DS_SAVE_BASE + PEBS64_COUNTER0], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_COUNTER0 + 4], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_COUNTER1], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_COUNTER1 + 4], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_COUNTER2], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_COUNTER2 + 4], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_COUNTER3], 0
	mov DWORD [DS_SAVE_BASE + PEBS64_COUNTER3 + 4], 0

	;; ������ PEBS ������ pointer 
	mov DWORD [pebs_base_pointer], DS_SAVE_BASE + PEBS64_BASE
	mov DWORD [pebs_index_pointer], DS_SAVE_BASE + PEBS64_INDEX
	mov DWORD [pebs_maximum_pointer], DS_SAVE_BASE + PEBS64_MAXIMUM
	mov DWORD [pebs_threshold_pointer], DS_SAVE_BASE + PEBS64_THRESHOLD
	mov DWORD [pebs_counter0_pointer], DS_SAVE_BASE + PEBS64_COUNTER0
	mov DWORD [pebs_counter1_pointer], DS_SAVE_BASE + PEBS64_COUNTER1
	mov DWORD [pebs_counter2_pointer], DS_SAVE_BASE + PEBS64_COUNTER2
	mov DWORD [pebs_counter3_pointer], DS_SAVE_BASE + PEBS64_COUNTER3

set_ds_management_record_done:	
        ; �� PEBS buffer ���ָʾλ OvfBuffer
        RESET_PEBS_BUFFER_OVERFLOW

	pop ebx
	pop edx
	pop ecx
	mov esp, ebp
	pop ebp
	ret



;--------------------------------------------------------------
; test_bts_buffer_overflow(): �����Ƿ��� BTS buffer ����ж�
;--------------------------------------------------------------
test_bts_buffer_overflow:
        mov eax, [bts_index_pointer]
        mov eax, [eax]                          ; �� BTS index ֵ
        mov esi, [bts_threshold_pointer]
        cmp eax, [esi]                          ; �Ƚ� index >= threshold ?
        setae al
        movzx eax, al
        ret


;-----------------------------------------
; set_bts_buffer_size(): ���� BTS buffer ��¼��
; input:
;       esi-BTS buffer ���ɵļ�¼��
;-----------------------------------------
set_bts_buffer_size:
        push ecx
        push edx
        cmp DWORD [ds64_flag], 1                ; �����Ƿ�֧�� DS64 ��ʽ
        mov ecx, BTS_RECORD_SIZE
        mov edi, BTS_RECORD64_SIZE
        cmove ecx, edi                          ; �õ���¼ size
        imul esi, ecx                           ; count * sizeof(bts_record)
        mov edi, [bts_maximum_pointer]
        mov eax, [bts_base_pointer]
        mov eax, [eax]                          ; ��ȡ BTS base ֵ
        add esi, eax                            ; base + buffer size
        mov [edi], esi                          ; ���� bts maximum ֵ

        mov edi, [bts_threshold_pointer]
        mov [edi], esi                          ; ���� bts thrshold ֵ
        mov esi, ecx                            ; sizeof(bts_record)

        mov ecx, IA32_DEBUGCTL
        rdmsr 
        bt eax, BTINT_BIT                       ; �����Ƿ��� BTINT λ
        mov ecx, 0
        cmovc esi, ecx                          ; ��������ˣ�bts threshold = bts maximum
                                                ; ���� bts threshold = bts maximum + sizeof(bts_record)
        add [edi], esi                          ; ���յ� bts threshold ֵ
        pop edx
        pop ecx
        ret


;---------------------------------------------------------
; set_int_bts_buffer_size(): ���� INT �� bts buffer ��¼��
; input:
;       esi - ��¼��
;--------------------------------------------------------
set_int_bts_buffer_size:
        push ecx
        push edx
        cmp DWORD [ds64_flag], 1                ; �����Ƿ�֧�� DS64 ��ʽ
        mov ecx, BTS_RECORD_SIZE
        mov edi, BTS_RECORD64_SIZE
        cmove ecx, edi                          ; �õ���¼ size
        imul esi, ecx                           ; count * sizeof(bts_record)
        mov edi, [bts_maximum_pointer]
        mov eax, [bts_base_pointer]
        mov eax, [eax]                          ; ��ȡ BTS base ֵ
        add esi, eax                            ; base + buffer size
        mov [edi], esi                          ; ���� bts maximum ֵ
        mov edi, [bts_threshold_pointer]
        mov [edi], esi                          ; ���� bts thrshold ֵ
        pop edx
        pop ecx
        ret

;--------------------------------------------------
; set_pebs_buffer_size(): ���� PEBS buffer ��������
; input:
;       esi-PEBS buffer ���ɵļ�¼��
;---------------------------------------------------
set_pebs_buffer_size:
        push ecx
        cmp DWORD [enhancement_pebs_flag], 1            ; �����Ƿ�֧����ǿ�� PEBS ��¼��ʽ
        mov ecx, PEBS_ENHANCEMENT_RECORD64_SIZE
        mov edi, PEBS_RECORD64_SIZE
        cmovne ecx, edi                                  
        cmp DWORD [ds64_flag], 1                        ; �����Ƿ�֧�� DS64 ��ʽ
        mov edi, PEBS_RECORD_SIZE
        cmovne ecx, edi                                 ; ��֧�ֵĻ���ʹ�� PEBS_RECORD_SIZE �ߴ�
        imul esi, ecx                                   ; count * size(pebs_record)
        mov edi, [pebs_maximum_pointer]
        mov eax, [pebs_base_pointer]
        mov eax, [eax]                                  ; ��ȡ pebs base ֵ
        add esi, eax                                    ; base + buffer_size
        mov [edi], esi                                  ; ���� pebs maximum
        mov edi, [pebs_threshold_pointer]
        mov [edi], esi                                  ; ���� pebs threshold ֵ
        pop ecx
        ret


;----------------------------------------------
; reset_bts_index(): ���� BTS index Ϊ base ֵ
;----------------------------------------------
reset_bts_index:
        mov edi, [bts_index_pointer]
        mov esi, [bts_base_pointer]
        mov esi, [esi]                                  ; ��ȡ BTS base ֵ
        mov [edi], esi                                  ; BTS index = BTS base
        ret

;----------------------------------------------
; reset_pebs_index()������ PEBS index ֵΪ base
;----------------------------------------------
reset_pebs_index:
        mov edi, [pebs_index_pointer]       
        mov esi, [pebs_base_pointer]
        mov esi, [esi]                                  ; ��ȡ PEBS base ֵ
        mov [edi], esi                                  ; PEBS index = PEBS base
        mov [pebs_buffer_index], esi                    ; ���±���� PEBS index ֵ
        ret

;------------------------------------------------------------
; update_pebs_index_track(): ����PEBS index �Ĺ켣
; ������
;       ���� [pebs_buffer_index]������ֵ�����ּ�� PEBS �ж�
;       [pebs_buffer_index] ��¼�š���ǰ���� PEBS index ֵ
;------------------------------------------------------------
update_pebs_index_track:
        mov eax, [pebs_index_pointer]
        mov eax, [eax]                          ; ����ǰ pebs index ֵ
        mov [pebs_buffer_index], eax            ; ���±���� pebs index ֵ        
        ret


;------------------------------------------
; get_bts_base(): ��ȡ BTS buffer base ֵ
; output:
;		eax - BTS base
;-------------------------------------------
get_bts_base:
	mov eax, [bts_base_pointer]
	mov eax, [eax]
	ret


;------------------------------------------
; get_bts_index(): ��ȡ BTS buffer index ֵ
; output:
;		eax - BTS index
;-------------------------------------------
get_bts_index:
	mov eax, [bts_index_pointer]
	mov eax, [eax]
	ret

;------------------------------------------
; get_bts_maximum(): ��ȡ BTS buffer maximum ֵ
; output:
;		eax - BTS maximum
;-------------------------------------------
get_bts_maximum:
	mov eax, [bts_maximum_pointer]
	mov eax, [eax]
	ret

;----------------------------------------------------
; get_bts_threshold(): ��ȡ BTS buffer thresholdֵ
; output:
;		eax - BTS threshold
;----------------------------------------------------
get_bts_threshold:
	mov eax, [bts_threshold_pointer]
	mov eax, [eax]
	ret


;-------------------------------------------
; set_bts_index(): ���� BTS index ֵ
; input:
;	esi - BTS index
;-------------------------------------------
set_bts_index:
	mov eax, [bts_index_pointer]
	mov [eax], esi
	ret


;---------------------------------------------------------
; get_last_pebs_record_pointer()
; output:
;       eax - PEBS ��¼�ĵ�ֵַ������ 0 ʱ��ʾ�� PEBS ��¼
;----------------------------------------------------------
get_last_pebs_record_pointer:
        mov eax, [pebs_index_pointer]
        mov esi, [eax]
        mov eax, [pebs_base_pointer]
        cmp esi, [eax]                  ; index > base ?
        seta al
        movzx eax, al
        jbe get_last_pebs_record_pointer_done
        sub esi, [pebs_record_length]
        mov eax, esi
get_last_pebs_record_pointer_done:
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
	push ecx
	push edx
	push ebx


; �����Ƿ�֧�� 64 λ��ʽ
	test DWORD [ds64_flag], 1
	mov eax, print_dword_value		; �����֧�֣���ӡ 32 λ��ʽ
	mov edx, print_qword_value		; ���֧�֣���ӡ 64 λ��ʽ
	cmovz edx, eax				; edx ��Ŵ�ӡ����
	

;; �����ӡ DS ��������¼	
	mov esi, dbm_msg1
	call puts
	mov eax, [bts_base_pointer]
	mov esi, [eax]
	mov edi, [eax + 4]
	call edx				; ��ӡ bts base
	mov esi, dbm_msg0
	call puts
	mov esi, dbm_msg5
	call puts
	mov eax, [pebs_base_pointer]
	mov esi, [eax]
	mov edi, [eax + 4]
	call edx				; ��ӡ pebs base
	call println
	mov esi, dbm_msg2
	call puts
	mov eax, [bts_index_pointer]
	mov esi, [eax]
	mov edi, [eax + 4]
	call edx				; ��ӡ bts index
	mov esi, dbm_msg0
	call puts
	mov esi, dbm_msg6
	call puts
	mov eax, [pebs_index_pointer]
	mov esi, [eax]
	mov edi, [eax + 4]
	call edx				; ��ӡ pebs index
	call println
	mov esi, dbm_msg3
	call puts
	mov eax, [bts_maximum_pointer]
	mov esi, [eax]
	mov edi, [eax + 4]
	call edx				; ��ӡ bts maximum
	mov esi, dbm_msg0
	call puts
	mov esi, dbm_msg7
	call puts
	mov eax, [pebs_maximum_pointer]
	mov esi, [eax]
	mov edi, [eax + 4]
	call edx				; ��ӡ pebs maximum
	call println
	mov esi, dbm_msg4
	call puts
	mov eax, [bts_threshold_pointer]
	mov esi, [eax]
	mov edi, [eax + 4]
	call edx				; ��ӡ bts threshold
	mov esi, dbm_msg0
	call puts
	mov esi, dbm_msg8
	call puts
	mov eax, [pebs_threshold_pointer]
	mov esi, [eax]
	mov edi, [eax + 4]
	call edx				; ��ӡ pebs threshold
	call println
	
dump_ds_management_done:	
	pop ebx
	pop edx
	pop ecx
	ret


;--------------------------------------
;��ӡ BTS ��¼
;--------------------------------------
dump_bts_record:
	jmp do_dump_bts_record
br_msg1	db  '----------------------------- BTS Record -------------------------------', 10, 0	
br_msg2 db  ' <-- INDEX  ', 0
br_msg3 db  '<BTS threshold> :', 10, 0
br_msg4 db  '------------------------------------------------------------------------', 10, 0
db64_msg1 db '----------------------------- BTS64 Record -------------------------------', 10, 0
print_func	dd	print_dword_decimal
do_dump_bts_record:
	push ecx
	push edx
	push ebx
	push ebp
;*
;* �Ƿ�֧�� DEST64, ���֧�� DEST64 ���ܣ����ӡ 64 λ��ʽ
;*
	test DWORD [ds64_flag], 1
	mov eax, print_dword_value		; ��֧�֣���ӡ 32 λ
	mov edx, print_qword_value		; ֧�֣���ӡ 64 λ
	cmovz edx, eax

	; ��ӡ��ͷ
	mov esi, db64_msg1
	mov edi, br_msg1
	cmovz esi, edi
	call puts

	mov eax, [bts_maximum_pointer]
	mov ebp, [eax]				; ȡ BTS maximum ֵ
	mov eax, [bts_threshold_pointer]
	cmp ebp, [eax]				; maximum �� threshold �Ƚ�
	cmovb ebp, [eax]			; �ҳ� maximum �� threshold �����ֵ

	mov eax, [bts_base_pointer]
	mov ebx, [eax]				; ȡ BTS base ֵ


; ���ڣ�ebx = base ֵ��ebp = BTS buffer ���ֵ

	xor ecx, ecx
dump_bts_record_loop:
	cmp ebx, ebp				; �Ƿ� >= BTS maximum �� BTS threshold ?
	jg do_dump_bts_record_done
	

	; �����Ƿ����� BTS maximum
	mov eax, [bts_maximum_pointer]
	cmp ebx, [eax]
	jne dump_bts_record_next
	mov esi, br_msg4
	call puts

dump_bts_record_next:

; ��ӡ threshold ��Ϣ
	mov eax, [bts_threshold_pointer]
	cmp ebx, [eax]				; �Ƿ�Ϊ threshold ֵ
	mov esi, 0
	mov edi, br_msg3
	cmove esi, edi
	call puts

	mov esi, fs_msg1
	call puts
	mov eax, print_byte_value
	cmp ecx, 10
	cmovge eax, [print_func]
	mov esi, ecx,
	call eax	
	mov esi, fs_msg3
	call puts
	mov esi, [ebx]					; from_ip
	mov edi, [ebx + 4]
	call edx

	mov eax, [bts_index_pointer]
	cmp ebx, [eax]					; ��ǰ�Ƿ�Ϊ index ֵ
	mov eax, fs_msg4
	mov esi, br_msg2
	cmovne esi, eax
	call puts
	mov esi, fs_msg5
	call puts
	mov eax, print_byte_value
	cmp ecx, 10
	cmovge eax, [print_func]
	mov esi, ecx,
	call eax
	mov esi, fs_msg3
	call puts
	mov esi, [ebx + 8]				; to_ip
	mov edi, [ebx + 12]
	call edx
	call println
	
	add ebx, 24
	inc ecx
	jmp dump_bts_record_loop

do_dump_bts_record_done:
	pop ebp
	pop ebx
	pop edx
	pop ecx
	ret
	
	

;-------------------------------------
; dump_pebs32_record(): ��ӡһ�� PEBS 32 ��¼
; input:
;	esi - address of PEBS record
;-------------------------------------
dump_pebs32_record:
	jmp do_dump_pebs32_record
dpr_msg0	db '         ', 0
context32_flags	dd eflags_msg, eip_msg, eax_msg, ebx_msg, ecx_msg, edx_msg, esi_msg
		dd edi_msg, ebp_msg, esp_msg, 0
do_dump_pebs32_record:
	
	ret

;--------------------------------------------
; dump_pebs64_record(): ��ӡһ�� PEBS 64 ��¼
; input:
;	esi - address of PEBS record
;--------------------------------------------
dump_pebs64_record:
	jmp do_dump_pebs64_record
context64_flags	dd rflags_msg, rip_msg, rax_msg, rbx_msg, rcx_msg, rdx_msg, rsi_msg
		dd rdi_msg, rbp_msg, rsp_msg
		dd r8_msg, r9_msg, r10_msg, r11_msg, r12_msg, r13_msg, r14_msg, r15_msg, 0
enhancement_flags dd perf_global_status_msg, data_linear_address_msg, data_source_encoding_msg, latency_value_msg, 0
dpr64_msg       db '<enhancement pebs record>: ', 10, 0
do_dump_pebs64_record:
	push ebx
	push edx
	mov ebx, context64_flags
	mov edx, esi

dump_pebs64_record_loop:	
	mov esi, [ebx]
	call puts
	mov esi, [edx]
	mov edi, [edx + 4]
	call print_qword_value
	mov esi, dpr_msg0
	call puts
	add ebx, 4
	mov esi, [ebx]
	call puts
	mov esi, [edx + 8]
	mov edi, [edx + 12]
	call print_qword_value
	call println
	add edx, 16
	add ebx, 4
	cmp DWORD [ebx], 0
	jne dump_pebs64_record_loop
	cmp DWORD [pebs_record_length], 176	; �Ƿ�Ϊ��ǿ�� PEBS ��¼
	jne dump_pebs64_record_done
	
        
	;; ��ӡ��ǿ�ļ�¼��Ϣ
        mov esi, dpr64_msg
        call puts
	mov ebx, enhancement_flags
dump_enhancement_record:
	mov esi, [ebx]
	call puts
	mov esi, [edx]
	mov edi, [edx + 4]
	call print_qword_value
	call println
	add edx, 8
	add ebx, 4
	cmp DWORD [ebx], 0
	jne dump_enhancement_record
dump_pebs64_record_done:
	pop edx
	pop ebx
	ret

;---------------------------------------------
; dump_pebs_record()����ӡ���һ�� PEBS ��¼
;---------------------------------------------
dump_pebs_record:
	jmp do_dump_pebs_record
dpr_msg	 db '---------------- last PEBS record -------------------', 10, 0
dpr_msg1 db '*** no record ****', 10, 0
dpr_msg2 db '--------------------- <END> --------------------------', 10, 0
do_dump_pebs_record:
	push ecx
	push edx
	push ebx
	mov esi, dpr_msg
	call puts

;*
;* �Ƿ�֧�� DEST64, ���֧�� DEST64 ���ܣ����ӡ 64 λ��ʽ
;*
	test DWORD [ds64_flag], 1
	jnz dump_pebs64
	mov eax, [pebs_base_pointer]
	mov esi, [pebs_index_pointer]
	mov esi, [esi]
	cmp esi, [eax]			; index �� base �Ƚ�
	ja dump_pebs_next
	mov esi, dpr_msg1
	call puts
	jmp dump_pebs_record_done
dump_pebs_next:
	sub esi, [pebs_record_length]
	call dump_pebs32_record
	jmp dump_pebs_record_done

dump_pebs64:
	mov eax, [pebs_base_pointer]
	mov esi, [pebs_index_pointer]
	mov esi, [esi]
	cmp esi, [eax]			; index �� base �Ƚ�
	ja dump_pebs64_next
	mov esi, dpr_msg1
	call puts
	jmp dump_pebs_record_done
dump_pebs64_next:
	sub esi, [pebs_record_length]
	call dump_pebs64_record
dump_pebs_record_done:
        mov esi, dpr_msg2
        call puts
	pop ebx
	pop edx
	pop ecx
	ret

;-----------------------
; ��ӡ���� LBR stack
;-----------------------
dump_lbr_stack:
	jmp do_dump_lbr_stack
fs_msg0	db 10, '----------------------------- LBR STACK -------------------------------', 10, 0	
fs_msg1	db 'from_ip_', 0
fs_msg3	db ': 0x', 0
fs_msg2	db ' <-- TOP    ', 0
fs_msg4	db '            ', 0
fs_msg5	db 'to_ip_', 0
do_dump_lbr_stack:
	push ecx
	push ebx
	push edx
	push ebp
	xor ebx, ebx
	mov ebp, print_dword_decimal

	mov esi, fs_msg0
	call puts

; ��ӡ��Ϣ
dump_lbr_stack_loop:

	mov esi, fs_msg1
	call puts
	mov esi, ebx
	mov eax, print_byte_value
	cmp ebx, 10
	cmovae eax, ebp
	call eax
	mov esi, fs_msg3
	call puts

; ��ӡ from ip
	lea ecx, [ebx + MSR_LASTBRANCH_0_FROM_IP]
	rdmsr
	mov esi, eax
	call print_dword_value

	mov ecx, MSR_LASTBRANCH_TOS
	rdmsr
	cmp eax, ebx
	jnz dump_lbr_from_stack_next
	mov esi, fs_msg2
	call puts
	jmp dump_lbr_to_stack
dump_lbr_from_stack_next:
	mov esi, fs_msg4
	call puts

;; ��ӡ to ip
dump_lbr_to_stack:
	mov esi, fs_msg5
	call puts
	mov esi, ebx
	mov eax, print_byte_value
	cmp ebx, 10
	cmovae eax, ebp
	call eax
	mov esi, fs_msg3
	call puts

	lea ecx, [ebx + MSR_LASTBRANCH_0_TO_IP]
	rdmsr
	mov esi, eax
	call print_dword_value

	mov ecx, MSR_LASTBRANCH_TOS
	rdmsr
	cmp eax, ebx
	jnz dump_lbr_to_stack_next
	mov esi, fs_msg2
	call puts
	jmp dump_lbr_stack_next
dump_lbr_to_stack_next:
	mov esi, fs_msg4
	call puts
	
dump_lbr_stack_next:
	call println
	inc ebx
	cmp ebx, 16
	jb dump_lbr_stack_loop
	call println

	pop ebp
	pop edx
	pop ebx
	pop ecx
	ret

;-----------------------------
; ��ӡ last exception from/to
;-----------------------------
dump_last_exception:
	mov esi, last_exception_from
	call puts
	mov ecx, MSR_LER_FROM_LIP
	rdmsr
	mov esi, eax
	call print_dword_value
	mov esi, last_exception_to
	call puts
	mov ecx, MSR_LER_TO_LIP
	rdmsr
	mov esi, eax
	call print_dword_value
	call println
	ret
	
;-------------------------------
; ��ӡ IA32_DEBUGCTL �Ĵ���
;-------------------------------
dump_debugctl:
	mov esi, debugctl_msg
	call puts
	mov ecx, IA32_DEBUGCTL
	rdmsr
	mov esi, eax
	shl esi, 17
	call reverse
	mov esi, eax
	mov edi, debugctl_flags
	call dump_flags
	call println
	ret


;-----------------------
; ��ӡ DR0-DR3 �Ĵ���
;----------------------
dump_drs:
	mov esi, dr0_msg
	call puts
	mov esi, dr0
	call print_dword_value
	call printblank
	mov esi, dr1_msg
	call puts
	mov esi, dr1
	call print_dword_value
	call printblank
	mov esi, dr2_msg
	call puts
	mov esi, dr2
	call print_dword_value
	call printblank
	mov esi, dr3_msg
	call puts
	mov esi, dr3
	call print_dword_value
	call println
	ret
	
;-----------------------
; ��ӡ DR6 �Ĵ���
;-----------------------
dump_dr6:
	mov esi, dr6_msg
	call puts	
	mov esi, dr6
	call reverse
	mov esi, eax
	mov edi, dr6_flags
	call dump_flags
	call println
	ret

;-------------------------------------------
; dump_dr6_flags(): ��ӡ DR6 ��־ʹ�������ֵ
; input:
;		esi: ����ֵ
;-------------------------------------------
dump_dr6_flags:
	push ecx
	mov ecx, esi
	mov esi, dr6_msg
	call puts
	mov esi, ecx
	call reverse
	mov esi, eax
	mov edi, dr6_flags
	call dump_flags
	call println	
	pop ecx	
	ret


;----------------------------
; ��ӡ dr7 �Ĵ���
;----------------------------
dump_dr7:
	push ebx	
	push ecx
	mov ecx, dr7
	mov ebx, len_rw_flags
	mov esi, dr7_msg
	call puts
dump_len_rw:	
	mov esi, [ebx]
	cmp esi, -1
	je dump_dr7_next
	call puts
	rol ecx, 2
	mov esi, ecx
	and esi, 0x3
	call print_dword_decimal
	call printblank
	add ebx, 4
	jmp dump_len_rw
	
dump_dr7_next:		
	mov esi, dr7
	shl esi, 18
	call reverse
	mov esi, eax
	mov edi, enable_flags
	call dump_flags
	call println
	pop ecx
	pop ebx 	
	ret
	
;***** ������ *********
bts_buffer_base		dq 0
bts_buffer_index	dq 0
bts_buffer_maximum	dq 0
bts_buffer_threshold	dq 0
pebs_buffer_base	dq 0
pebs_buffer_index	dq 0
pebs_buffer_maximum	dq 0
pebs_buffer_threshold	dq 0
pebs_record_length	dd 0

;;; �����Ǵ�Ź�������ַ
bts_base_pointer	dd 0
bts_index_pointer	dd 0
bts_maximum_pointer	dd 0
bts_threshold_pointer	dd 0
pebs_base_pointer	dd 0
pebs_index_pointer	dd 0
pebs_maximum_pointer	dd 0
pebs_threshold_pointer	dd 0
pebs_counter0_pointer	dd 0
pebs_counter1_pointer	dd 0
pebs_counter2_pointer	dd 0
pebs_counter3_pointer	dd 0

;; ��־����
ds64_flag		dd 0
enhancement_pebs_flag	dd 0


;; ������ IA32_DEBUGCTL �� IA32_PEBS_ENABLE �Ĵ���
debugctl_value		dq 0
pebs_enable_value	dq 0


last_exception_from		db 'last_exception_from: 0x', 0
last_exception_to		db '    last_exception_to: 0x', 0

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
			
;; ���� 32 λͨ�üĴ��� context
;; �� inc\lib.inc �ļ���� STORE_CONTEXT() �� RESTORE_CONTEXT() ��������

debug_context	times 10 dd 0

;*
;* ��������ֹͣĿ���ַ
;* �� #DB handler ��⵽Ŀ���ַΪ��ֵʱ����ֹ��������
;*
db_stop_address         dd 0


;; 32 λ context ��Ϣ
eflags_msg	db 'EFLAGS: ', 0
eip_msg		db 'EIP: ', 0
eax_msg		db 'EAX: ', 0
ecx_msg		db 'ECX: ', 0
edx_msg		db 'EDX: ', 0
ebx_msg		db 'EBX: ', 0
esp_msg		db 'ESP: ', 0
ebp_msg		db 'EBP: ', 0
esi_msg		db 'ESI: ', 0
edi_msg		db 'EDI: ', 0

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
					
