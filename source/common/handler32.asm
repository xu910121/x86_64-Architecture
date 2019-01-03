; handler32.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


;*
;* ���� protected ģʽ�µ� interrupt/exception handler ����
;* �ɸ���ʵ�����ӵ� protected.asm ģ���� include ��ȥ
;*


%ifndef HANDLER32_ASM
%define HANDLER32_ASM


;----------------------------------------
; DB_handler():  #DB handler
; ������
;       
;----------------------------------------
DB_handler:
        jmp do_DB_handler
db_msg1         db '-----< Single-Debug information >-----', 10, 0        
db_msg2         db '>>>>> END <<<<<', 10, 0

;* ��Щ�ַ�����ַ������ debug.asm �ļ�
register_message_table: 
        dd eax_msg, ecx_msg, edx_msg, ebx_msg, esp_msg, ebp_msg, esi_msg, edi_msg, 0

do_DB_handler:        
        ;; �õ��Ĵ���ֵ
        STORE_CONTEXT
        
        mov esi, db_msg1
        call puts
        
        ;; ֹͣ����        
        mov eax, [db_stop_address]              ; �� #DB ֹͣ��ַ
        cmp eax, [esp]                          ; �Ƿ�����ֹͣ����
        je stop_debug

        mov ebx, CONTEXT_POINTER
do_DB_handler_loop:        
     
        mov esi, [register_message_table + ecx * 4]
        call puts                               ; ��ӡ�ַ���
        mov esi, [ebx + ecx * 4]
        call print_dword_value                  ; ��ӡ�Ĵ���ֵ

        mov eax, ecx
        and eax, 3
        cmp eax, 3
        mov esi, printblank                     ; �ո�
        mov edi, println                        ; ����
        cmove esi, edi                          ; ��ӡ 4 ���󣬻���
        call esi

        inc ecx        
        cmp ecx, 7
        jbe do_DB_handler_loop

do_DB_handler_next:        
        mov esi, eip_msg
        call puts
        mov esi, [esp]
        call print_dword_value
        call println
        jmp do_DB_handler_done

stop_debug:
        btr DWORD [esp + 8], 8                  ; �� TF ��־
        mov esi, db_msg2
        call puts
do_DB_handler_done:        
        bts DWORD [esp + 8], 16                 ; ���� eflags.RF Ϊ 1���Ա��жϷ���ʱ������ִ��

        RESTORE_CONTEXT
        iret


%ifdef DEBUG
;--------------------------------------------
; #DB handler
; ������
;       ����汾�� #DB handler ����
;-------------------------------------------
debug_handler:
        jmp do_debug_handler
dh_msg1 db '>>> now: enter #DB handler', 10, 0
dh_msg2 db 'new, exit #DB handler <<<', 10, 0
do_debug_handler:
        mov esi, dh_msg1
        call puts
        call dump_drs
        call dump_dr6
        call dump_dr7
        mov eax, [esp]
        cmp WORD [eax], 0xfeeb              ; ���� jmp $ ָ��
        jne do_debug_handler_done
        btr DWORD [esp+8], 8                ; �� TF
do_debug_handler_done:        
        bts DWORD [esp+8], 16               ; RF=1
        mov esi, dh_msg2
        call puts
        iret

%endif


;-------------------------------------------
; GP_handler():  #GP handler
;-------------------------------------------
GP_handler:
        jmp do_GP_handler
gmsg1   db '---> Now, enter #GP handler, occur at: 0x', 0
gmsg2   db ', error code = 0x', 0
gmsg3   db '<ID:', 0
gmsg4   db '--------------- register context ------------', 10, 0
do_GP_handler:        
        mov esi, gmsg1
        call puts
        mov esi, [esp + 4]
        call print_dword_value
        call println
        mov esi, gmsg3
        call puts
        mov esi, [APIC_BASE + APIC_ID]
        call print_dword_value
        mov esi, '>'
        call putc
        mov esi, gmsg2
        call puts
        mov esi, [esp]
        call print_dword_value
        call println

        jmp $       
do_GP_handler_done:                
        iret

;------------------------------------------------
; #GF handler
;------------------------------------------------
PF_handler:
        jmp do_pf_handler
pf_msg  db 10, '---> now, enter #PF handler', 10
        db 'occur at: 0x', 0
pf_msg2 db 10, 'fixed the error', 10, 0                
do_pf_handler:        
        add esp, 4                              ; ���� Error code
        push ecx
        push edx
        mov esi, pf_msg
        call puts
        
        mov ecx, cr2                            ; ����#PF�쳣��virtual address
        mov esi, ecx
        call print_dword_value

        jmp $
        
        mov esi, pf_msg2
        call puts

;; ������������
        mov eax, ecx
        shr eax, 30
        and eax, 0x3                        ; PDPTE index
        mov eax, [PDPT_BASE + eax * 8]
        and eax, 0xfffff000
        mov esi, ecx
        shr esi, 21
        and esi, 0x1ff                        ; PDE index
        mov eax, [eax + esi * 8]
        btr DWORD [eax + esi * 8 + 4], 31                ; �� PDE.XD
        bt eax, 7                                ; PDE.PS=1 ?
        jc do_pf_handler_done
        mov esi, ecx
        shr esi, 12
        and esi, 0x1ff                        ; PTE index
        and eax, 0xfffff000
        btr DWORD [eax + esi * 8 + 4], 31                ; �� PTE.XD
do_pf_handler_done:        
        pop edx
        pop ecx
        iret


;----------------------------------------------
; UD_handler(): #UD handler
;----------------------------------------------
UD_handler:
        jmp do_UD_handler
ud_msg1         db '>>> Now, enter the #UD handler, occur at: 0x', 0        
do_UD_handler:
        mov esi, ud_msg1
        call puts
        mov eax, [esp+12]               ; �õ� user esp
        mov eax, [eax]
        mov [esp], eax                  ; ��������#UD��ָ��
        add DWORD [esp+12], 4           ; pop �û� stack
        iret
        
;----------------------------------------------
; NM_handler(): #NM handler
;----------------------------------------------
NM_handler:
        jmp do_NM_handler
nm_msg1         db '---> Now, enter the #NM handler', 10, 0        
do_NM_handler:        
        mov esi, nm_msg1
        call puts
        mov eax, [esp+12]               ; �õ� user esp
        mov eax, [eax]
        mov [esp], eax                  ; ��������#NM��ָ��
        add DWORD [esp+12], 4           ; pop �û� stack
        iret        

;-----------------------------------------------
; AC_handler(): #AC handler
;-----------------------------------------------
AC_handler:
        jmp do_AC_handler
ac_msg1         db '---> Now, enter the #AC exception handler <---', 10
ac_msg2         db 'exception location at 0x'
ac_location     dq 0, 0
do_AC_handler:        
        pusha
        mov esi, [esp+4+4*8]                        
        mov edi, ac_location
        call get_dword_hex_string
        mov esi, ac_msg1
        call puts
        call println
;; ���� disable AC ����
        btr DWORD [esp+12+4*8], 18      ; ��elfags image�е�AC��־        
        popa
        add esp, 4                      ; ���� error code        
        iret


;----------------------------------------
; #TS handler
;----------------------------------------
TS_handler:
        jmp do_ts_handler
ts_msg1        db '--> now, enter the #TS handler', 10, 0        
ts_msg2        db 'return addres: 0x', 0
ts_msg3        db 'error code: 0x', 0
do_ts_handler:
        mov esi, ts_msg1
        call puts
        mov esi, ts_msg2
        call puts
        mov esi, [esp+4]
        call print_value
        mov esi, ts_msg3
        call puts
        mov esi, [esp]
        call print_value
        jmp $
        iret



%ifndef EX10_7
%define EX10_7

;-------------------------------------
; BR_handler(): #BR handler
;-------------------------------------
BR_handler:
        jmp do_BR_handler
brmsg1        db 10, 10, '---> Now, enter #BR handler', 10, 0        
do_BR_handler:        
        mov esi, brmsg1
        call puts
;        mov eax, [bound_rang]                ; �޸�����
        iret
        
;--------------------------------------
; BP_handler(): #BP handler
;--------------------------------------
BP_handler:
        jmp do_BP_handler
bmsg1        db 10, 10, 10, '---> Now, enter #BP handler, Breakpoint at: ', 0
do_BP_handler:
        push ebx
        mov bl, al
        mov esi, bmsg1
        call puts
        mov esi, [esp + 4]                        ;  ����ֵ
        dec esi                                   ;  breakpoint λ��
        mov [esp + 4], esi                        ; ��������ֵ
        mov BYTE [esi], bl                        ; �޸� breakpoint ����
        call print_value
        pop ebx
        iret

;---------------------------------------
; OF_handler(): #OF handler
;---------------------------------------
OF_handler:
        jmp do_OF_handler
omsg1   db '---> Now, enter #OF handler',10, 10,0        

do_OF_handler:
        push ebx
        mov ebx, [esp + 12]             ; �� eflags ֵ
        mov esi, omsg1
        call puts
        mov esi, ebx
        call dump_flags_value
        pop ebx
        iret


%endif



;-------------------------------
; system timer handler
; ������
;       ʹ���� 8259 IRQ0 handler
;-------------------------------
timer_handler:                
        jmp do_timer_handler
t_msg           db 10, '>>> now: enter 8253-timer handler', 10, 0
t_msg1          db 'exit the 8253-timer handler <<<', 10, 0
t_msg2          db 'wait for keyboard...', 10, 0
spin_lock       dd 0
keyboard_done   dd 0
do_timer_handler:
        mov esi, t_msg
        call puts
        call dump_8259_imr        
        call dump_8259_irr
        call dump_8259_isr

test_lock:        
        bt DWORD [spin_lock], 0                        ; ������
        jnc get_lock
        pause
        jmp test_lock
get_lock:
        lock bts DWORD [spin_lock], 0
        jc test_lock
        
;���� special mask mode ����
        call enable_keyboard
        call send_smm_command
        call disable_timer
        sti        
        mov esi, t_msg2
        call puts        
wait_for_keyboard:        
        mov ecx, 0xffff
delay:        
        nop
        loop delay
        bt DWORD [keyboard_done], 0
        jnc wait_for_keyboard        
        btr DWORD [spin_lock], 0                ; �ͷ���              
        mov esi, t_msg1
        call puts
        call write_master_EOI
        call disable_timer
        iret
        

        
;----------------------------
; keyboard_handler:
; ������
;       ʹ���� 8259 IRQ1 handler
;----------------------------        
keyboard_handler:
        jmp do_keyboard_handler
k_msg   db 10, '>>> now: entry keyboard handler', 10, 0
k_msg1  db 'exit the keyboard handler <<<', 10, 0
do_keyboard_handler:
        mov esi, k_msg
        call puts
        call dump_8259_imr
        call dump_8259_irr
        call dump_8259_isr
        bts DWORD [keyboard_done], 0                ; ���
        mov esi, k_msg1
        call puts        
        call write_master_EOI
        iret        
        

%ifdef APIC_TIMER_HANDLER        
;---------------------------------------------
; apic_timer_handler()������ APIC TIMER �� ISR
;---------------------------------------------
apic_timer_handler:
        jmp do_apic_timer_handler
at_msg  db '>>> now: enter the APIC timer handler', 10, 0
at_msg1 db 10, 'exit ther APIC timer handler <<<', 10, 0        
do_apic_timer_handler:        
        mov esi, at_msg
        call puts
        call dump_apic                        ; ��ӡ apic �Ĵ�����Ϣ
        mov esi, at_msg1
        call puts
        mov DWORD [APIC_BASE + EOI], 0
        iret

%endif



;*
;* ��������� APIC_PERFMON_HANDLER
;* ��ʹ�� handler32.asm �ļ���� apic_perfmon_handler
;* ��Ϊ PMI �ж� handler
;* ������ protected.asm �ļ����ṩ PMI handler
;*

%ifdef APIC_PERFMON_HANDLER

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

;*
;* �������ж� PMI �ж�����ԭ��
;*

check_pebs_interrupt:
        ; �Ƿ� PEBS �ж�
        call test_pebs_interrupt
        test eax, eax
        jz check_counter_overflow
        ; ��ӡ��Ϣ
        mov esi, ph_msg6
        call puts
        call dump_ds_management
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
        call dump_pmc
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
        
%endif
;*
;* ����
;*


%ifdef AP_IPI_HANDLER

;---------------------------------------------
; ap_ipi_handler()������ AP IPI handler
;---------------------------------------------
ap_ipi_handler:
	jmp do_ap_ipi_handler
at_msg2 db 10, 10, '>>>>>>> This is processor ID: ', 0
at_msg3 db '---------- extract APIC ID -----------', 10, 0
do_ap_ipi_handler:	
        
        ; ���� lock
test_handler_lock:
        lock bts DWORD [vacant], 0
        jc get_handler_lock

        mov esi, at_msg2
        call puts
        mov edx, [APIC_BASE + APIC_ID]        ; �� APIC ID
        shr edx, 24
        mov esi, edx
        call print_dword_value
        call println
        mov esi, at_msg3
        call puts

        mov esi, msg2                        ; ��ӡ package ID
        call puts
        mov esi, [x2apic_package_id + edx * 4]
        call print_dword_value
        call printblank        
        mov esi, msg3                        ; ��ӡ core ID
        call puts
        mov esi, [x2apic_core_id + edx * 4]
        call print_dword_value
        call printblank        
        mov esi, msg4                        ; ��ӡ smt ID
        call puts
        mov esi, [x2apic_smt_id + edx * 4]
        call print_dword_value
        call println

        mov DWORD [APIC_BASE + EOI], 0

        ; �ͷ�lock
        lock btr DWORD [vacant], 0        
        iret

get_handler_lock:
        jmp test_handler_lock
	iret

%endif


%ifdef APIC_ERROR_HANDLER

;-----------------------------------------
; apic_error_handler() ���� APIC error ����
;------------------------------------------
apic_error_handler:
        jmp do_apic_error_handler
ae_msg0        db 10, '>>> now: enter APIC Error handler, occur at: 0x', 0
ae_msg1        db 'exit the APIC error handler <<<', 10, 0
ae_msg2        db 'APIC ID: 0x', 0
ae_msg3        db 'ESR:     0x', 0
do_apic_error_handler:
test_error_handler_lock:
        lock bts DWORD [vacant], 0
        jc get_error_handler_lock
        mov esi, ae_msg0
        call puts
        mov esi, [esp]
        call print_dword_value
        call println
        mov esi, ae_msg2
        call puts
        mov esi, [APIC_BASE + APIC_ID]
        call print_dword_value
        call println
        mov esi, ae_msg3
        call puts
        call read_esr
        mov esi, eax
        call print_dword_value
        call println
        mov esi, ae_msg1
        call puts
        mov DWORD [APIC_BASE + EOI], 0
        lock btr DWORD [vacant], 0                ; �ͷ� lock
        iret
get_error_handler_lock:
        jmp test_error_handler_lock
%endif


;----------------------------------------------------
; ap_init_done_handler(): AP��ɳ�ʼ����ظ�BSP
;----------------------------------------------------
ap_init_done_handler:
        cmp DWORD [20100h], 0
        sete al
        movzx eax, al
        mov [ap_init_done], eax
        mov DWORD [APIC_BASE + EOI], 0
        iret

%endif

