; application_processor.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


;*
;* Application Processors ����
;*

%ifdef AP_PROTECTED_ENTER

;------------------------------------------------
; ������ application processor ��ʼ������
;-----------------------------------------------

application_processor_enter:
        bits 32

        ;*
        ;* ��ǰ���ڱ���ģʽ��
        ;* 

; ���� PDPT ��ַ        
        mov eax, PDPT_BASE
        mov cr3, eax

; ������ҳ
        mov eax, cr0
        bts eax, 31
        mov cr0, eax  

;����APIC
        call enable_apic        

        inc DWORD [processor_index]                             ; ���� index ֵ
        inc DWORD [processor_count]                             ; ���� logical processor ����
        mov ecx, [processor_index]                              ; ȡ index ֵ
        mov edx, [APIC_BASE + APIC_ID]                          ; �� APIC ID
        mov [apic_id + ecx * 4], edx                            ; ���� APIC ID 
;*
;* ���� stack �ռ�
;*
        mov eax, PROCESSOR_STACK_SIZE                           ; ÿ���������� stack �ռ��С
        mul ecx                                                 ; stack_offset = STACK_SIZE * index
        mov esp, PROCESSOR_KERNEL_ESP                           ; stack ��ֵ
        add esp, eax  

; ���� logical ID
        mov eax, 01000000h
        shl eax, cl
        mov [APIC_BASE + LDR], eax

; ��ȡ APIC ID
        call extrac_x2apic_id

; ���� LVT timer
        mov DWORD [APIC_BASE + LVT_ERROR], APIC_ERROR_VECTOR

;============= Ap ������ protected-mode ��ʼ����� ============

        ;*
        ;* �������Ƿ���Ҫ���� long-mode
        ;*
        cmp DWORD [long_flag], 1
        je LONG_SEG

;�ͷ� lock���������� AP ����
        lock btr DWORD [20100h], 0

;���� IPI ��Ϣ֪ͨ bsp
        mov DWORD [APIC_BASE + ICR1], 0
        mov DWORD [APIC_BASE + ICR0], PHYSICAL_ID | BP_IPI_VECTOR

        sti
        hlt
        jmp $

%endif



%ifdef AP_LONG_ENTER

;-------------------------------------------------
; ������ application processor ת�뵽 long-mode
;-------------------------------------------------
application_processor_long_enter:

        bits 64


; ���� LVT error
        mov DWORD [APIC_BASE + LVT_ERROR], APIC_ERROR_VECTOR

        ;�ͷ� lock���������� AP ����
     ;   lock btr DWORD [20100h], 0

;============== Ap ������ long-mode ��ʼ����� ======================

        ;*
        ;* �� BSP �������ظ� IPI ��Ϣ
        ;*
;        mov DWORD [APIC_BASE + ICR1], 0h
;        mov DWORD [APIC_BASE + ICR0], PHYSICAL_ID | BP_IPI_VECTOR


; �����û���Ȩִ��0��������
        mov rsi, SYSTEM_SERVICE_USER8
        mov rdi, user_hlt_routine
        call set_user_system_service

        mov rsi, SYSTEM_SERVICE_USER9
        mov rdi, user_send_ipi_routine
        call set_user_system_service

; ���� user stack pointer
        mov ecx, [processor_index]
        mov eax, PROCESSOR_STACK_SIZE
        mul ecx
        mov rcx, PROCESSOR_USER_RSP
        add rax, rcx


;; �л����û����롡
        push USER_SS | 3
        push rax
        push USER_CS | 3
        push application_processor_user_enter
        retf64

        sti
        hlt
        jmp $



application_processor_user_enter:
        mov esi, ap_msg
        mov rax, LIB32_PUTS
        call sys_service_enter        

        ; ������Ϣ�� BSP, �ظ���ɳ�ʼ��
        mov esi, PHYSICAL_ID | BP_IPI_VECTOR
        mov edi, 0
        mov eax, SYSTEM_SERVICE_USER9
        int 40h

        ;�ͷ� lock���������� AP ����
        lock btr DWORD [20100h], 0

        mov eax, SYSTEM_SERVICE_USER8
        int 40h

        jmp $

ap_msg  db '>>> enter 64-bit user code', 0

;---------------------------------
; user_send_ipi_routine()
; input:
;       rsi - ICR0, rdi - ICR1
;---------------------------------
user_send_ipi_routine:
        mov DWORD [APIC_BASE + ICR1], edi
        mov DWORD [APIC_BASE + ICR0], esi
        ret

;---------------------------------
; ���û��������￪���жϣ���ͣ��
;---------------------------------
user_hlt_routine:
        sti
        hlt
        ret

%endif



;*------------------------------------------------------
;* ������ starup routine ����
;* ���� AP ������ִ�� setupģ�飬ִ�� protected ģ��
;* ʹ���� AP ����������protectedģʽ
;*------------------------------------------------------
startup_routine:
        ;*
        ;* ��ǰ���������� 16 λʵģʽ
        ;*
        bits 16

        mov ax, 0
        mov ds, ax
        mov es, ax
        mov ss, ax

;*
;* ���� lock��ֻ���� 1 �� local processor ����
;*

test_ap_lock:        
        ;*
        ;* ���� lock��lock �ź��� 20100h λ����
        ;* �� CS + offset ֵ����ʽʹ�� lock
        ;*
        lock bts DWORD [cs:100h], 0
        jc get_ap_lock

;*
;* ��� lock ��ת��ִ�� setup --> protected --> long ����
;*
        jmp WORD 0:SETUP_SEG

get_ap_lock:
        pause
        jmp test_ap_lock

        bits 32
startup_routine_end: 




        bits 32

;-----------------------------------
; bootstarp processor IPI hanlder
;-----------------------------------
bp_ipi_handler:
        ;*
        ;* �������е� application processor �Ƿ����
        ;*
        cmp DWORD [20100h], 0
        sete al
        movzx eax, al
        mov [ap_init_done], eax
bp_ipi_handler_done:
        mov DWORD [APIC_BASE + EOI], 0

%ifdef BP_IPI_HANDLER64
        iret64
%else
        iret
%endif




;******** ������ **************

;* 
;* �������ָʾ���Ƿ���� long-mode 
;* �� bsp ���������ã�����1ʱ��ap������ת�뵽 long-mode
;* 
long_flag       dd      0


