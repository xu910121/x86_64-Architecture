; long.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.

;;
;; ��δ��뽫�л��� long mode ����

%include "..\inc\support.inc"
%include "..\inc\long.inc"
        
        bits 32

LONG_LENGTH:        dw        LONG_END - $
        
        org LONG_SEG - 2
        
        NMI_DISABLE
        cli

; �ر� PAE paging        
        mov eax, cr0
        btr eax, 31
        mov cr0, eax
        
        mov esp, 9FF0h

; BSP ���������г�ʼ��ҳ��
        call bsp_init_page

; ���� GDT ��
        lgdt [__gdt_pointer]
        
; ���� CR3 �Ĵ���        
        mov eax, PML4T_BASE
        mov cr3, eax
        
; ���� CR4 �Ĵ���
        mov eax, cr4
        bts eax, 5                                ; CR4.PAE = 1
        mov cr4, eax

; ���� EFER �Ĵ���
        mov ecx, IA32_EFER
        rdmsr 
        bts eax, 8                                ; EFER.LME = 1
        wrmsr

; ���� long mode
        mov eax, cr0
        bts eax, 31
        mov cr0, eax                              ; EFER.LMA = 1



; ת�� 64 λ����
        jmp KERNEL_CS : entry64

; ������ 64 λ����
        
        bits 64
                
entry64:
        mov ax, KERNEL_SS
        mov ds, ax
        mov es, ax
        mov ss, ax

; ���� long-mode ��ϵͳ���ݽṹ
        call bsp_init_system_struct

;; �������¼��� 64-bit �����µ� GDT �� IDT ��
        mov rax, SYSTEM_DATA64_BASE + (__gdt_pointer - __system_data64_entry)
        lgdt [rax]
        mov rax, SYSTEM_DATA64_BASE + (__idt_pointer - __system_data64_entry)
        lidt [rax]


;*
;* ���öദ��������
;*
        inc DWORD [processor_index]                             ; ���Ӵ����� index
        inc DWORD [processor_count]                             ; ���Ӵ���������
        mov eax, [APIC_BASE + APIC_ID]                          ; �� APIC ID
        mov ecx, [processor_index]
        mov [apic_id + rcx * 4], eax                            ; ���� APIC ID
        mov eax, 01000000h
        shl eax, cl
        mov [APIC_BASE + LDR], eax                              ; logical ID

;*
;* Ϊÿ������������ kernel stack pointer
;*
        ; ���� stack size
        mov eax, PROCESSOR_STACK_SIZE                           ; ÿ���������� stack �ռ��С
        mul ecx                                                 ; stack_offset = STACK_SIZE * index

        ; ���� stack pointer
        mov rsp, PROCESSOR_KERNEL_RSP
        add rsp, rax                                            ; �õ� RSP
        mov r8, PROCESSOR_IDT_RSP    
        add r8, rax                                             ; �õ� TSS RSP0
        mov r9, PROCESSOR_IST1_RSP                              ; �õ� TSS IDT1
        add r9, rax  

;*
;* Ϊÿ������������ TSS �ṹ
;*
        ; ���� TSS ��ַ
        mov eax, 104                                            ; TSS size
        mul ecx                                                 ; index * 104
        mov rbx, __processor_task_status_segment - __system_data64_entry + SYSTEM_DATA64_BASE
        add rbx, rax

        ; ���� TSS ��
        mov [rbx + 4], r8                                       ; ���� RSP0
        mov [rbx + 36], r9                                      ; ���� IST1


        ; ���� TSS selector ֵ       
        mov edx, processor_tss_sel                             
        shl ecx, 4                                              ; 16 * index
        add edx, ecx                                            ; TSS selector                                            

        ; ���� TSS ������
        mov esi, edx                                            ; TSS selector
        mov edi, 67h                                            ; TSS size
        mov r8, rbx                                             ; TSS base address
        mov r9, TSS64                                           ; TSS type
        call set_system_descriptor

;*
;* ������ؼ��� TSS �� LDT
;*
        ltr dx
        mov ax, ldt_sel
        lldt ax


;; ���� sysenter/sysexit, syscall/sysret ʹ�û���
        call set_sysenter
        call set_syscall

; �� FS.base = 0xfffffff800000000        
        mov ecx, IA32_FS_BASE
        mov eax, 0x0
        mov edx, 0xfffffff8
        wrmsr

; ��ȡ x2APIC ID
        call extrac_x2apic_id


; ����Ƿ�Ϊ bootstrap processor
        mov ecx, IA32_APIC_BASE
        rdmsr
        bt eax, 8
        jnc application_processor_long_enter

;-------------------------------------
; ������ BSP ����������
;-------------------------------------

bsp_processsor_enter:

;; ���� call gate descriptor
        mov rsi, call_gate_sel
        mov rdi, __lib32_service                ; call-gate ���� __lib32_srvice() ������
        mov r8, 3                               ; call-gate �� DPL = 3
        mov r9, KERNEL_CS                       ; code selector = KERNEL_CS
        call set_call_gate

        mov rsi, conforming_callgate_sel
        mov rdi, __lib32_service                 ; call-gate ���� __lib32_srvice() ������
        mov r8, 3                               ; call-gate �� DPL = 0
        mov r9, conforming_code_sel             ; code selector = conforming_code_sel
        call set_call_gate

;; ���� conforming code segment descriptor        
        MAKE_SEGMENT_ATTRIBUTE 13, 0, 1, 0      ; type=conforming code segment, DPL=0, G=1, D/B=0
        mov r9, rax                             ; attribute
        mov rsi, conforming_code_sel            ; selector
        mov rdi, 0xFFFFF                        ; limit
        mov r8, 0                               ; base
        call set_segment_descriptor        

; ���� #GP handler
        mov rsi, GP_HANDLER_VECTOR
        mov rdi, GP_handler
        call set_interrupt_handler

; ���� #PF handler
        mov rsi, PF_HANDLER_VECTOR
        mov rdi, PF_handler
        call set_interrupt_handler

; ���� #DB handler
        mov rsi, DB_HANDLER_VECTOR
        mov rdi, DB_handler
        call set_interrupt_handler

;; ���� int 40h ʹ�û���
        mov rsi, 40h
        mov rdi, user_system_service_call
        call set_user_interrupt_handler
  
; �����������
	NMI_ENABLE
	sti
        
        mov DWORD [20100h], 0           ; lock �ź���Ч

        
;======== long-mode �������ô������=============

        mov rsi, BP_IPI_VECTOR
        mov rdi, bp_ipi_handler
        call set_interrupt_handler

        mov rsi, APIC_TIMER_VECTOR
        mov rdi, bp_timer_handler
        call set_interrupt_handler

        mov rsi, AP_IPI_VECTOR
        mov rdi, ap_ipi_handler
        call set_interrupt_handler

        mov DWORD [APIC_BASE + LVT_TIMER], APIC_TIMER_VECTOR

        mov esi, msg
        LIB32_PUTS_CALL

        ;*
        ;* ���淢�� IPIs��ʹ�� INIT-SIPI-SIPI ����
        ;* ���� SIPI ʱ������ startup routine ��ַλ�� 200000h
        ;*
        mov DWORD [APIC_BASE + ICR0], 000c4500h                ; ���� INIT IPI, ʹ���� processor ִ�� INIT
        DELAY
        DELAY
        mov DWORD [APIC_BASE + ICR0], 000C4620H                ; ���� Start-up IPI
        DELAY
        mov DWORD [APIC_BASE + ICR0], 000C4620H                ; �ٴη��� Start-up IPI

        ;*
        ;* �ȴ� AP ��������ɳ�ʼ��
        ;*
wait_for_done:
        cmp DWORD [ap_init_done], 1
        je next
        nop
        pause
        jmp wait_for_done 

next:   ; ���� apic timer �ж�
        mov DWORD [APIC_BASE + TIMER_ICR], 10
        DELAY

        ; ���� lock �ź�
        ; ���� IPI ������ AP ��������������ִ�в��Ժ���
        mov DWORD [vacant], 0   
        mov DWORD [APIC_BASE + ICR1], 0E000000h
        mov DWORD [APIC_BASE + ICR0], LOGICAL_ID | AP_IPI_VECTOR

        jmp $

msg     db '<BSP>: now, send INIT-SIPI-SIPI message', 10, 10
        db '       waiting for application processsor...', 10  
        db '---------------------------------------------------------------', 10, 0
msg1    db 'this is a test message...', 0


;-----------------------------
; ������Ϣ
;-----------------------------
test_func:
        mov esi, msg1
        LIB32_PUTS_CALL
        ret

;-----------------------------------
; bootstarp processor IPI hanlder
;-----------------------------------
bp_ipi_handler:
        jmp do_bp_ipi_handler
bimsg   db '--- AP<ID:', 0
bimsg1  db '> Initialization done ! --- ', 10, 0
do_bp_ipi_handler:
        mov esi, bimsg
        LIB32_PUTS_CALL
        mov r8d, [processor_index]
        mov esi, [apic_id + r8 * 4]
        LIB32_PRINT_DWORD_VALUE_CALL
        mov esi, bimsg1
        LIB32_PUTS_CALL

        ;*
        ;* �������е� application processor �Ƿ����
        ;*
        cmp DWORD [20100h], 0
        sete al
        movzx eax, al
        mov [ap_init_done], eax
bp_ipi_handler_done:
        mov DWORD [APIC_BASE + EOI], 0
        iret64

;--------------------------------
; BSP apic timer handler
;--------------------------------
bp_timer_handler:
        jmp do_ap_timer_handler
ap_msg0 db 'system bus processor :', 0
do_ap_timer_handler:
        mov esi, ap_msg0
        LIB32_PUTS_CALL
        mov esi, [processor_count]
        LIB32_PRINT_DWORD_DECIMAL_CALL
        LIB32_PRINTLN_CALL
        LIB32_PRINTLN_CALL
        mov DWORD [APIC_BASE + EOI], 0
        iret64

;------------------------------
; AP IPI handler
;------------------------------
ap_ipi_handler:
        jmp do_ap_ipi_handler
aih_msg db ' <CPI>: ', 0
aih_msg1 db 'AP<', 0
aih_msg2 db '>: ', 0
do_ap_ipi_handler:
        lock bts DWORD [vacant], 0
        jc get_lock
        mov esi, aih_msg1
        LIB32_PUTS_CALL
        mov esi, [APIC_BASE + APIC_ID]
        LIB32_PRINT_DWORD_VALUE_CALL
        mov esi, aih_msg2
        LIB32_PUTS_CALL
        mov rsi, test_func
        call get_unhalted_cpi
        mov r8, rax
        mov esi, aih_msg
        LIB32_PUTS_CALL
        mov rsi, r8
        LIB32_PRINT_DWORD_DECIMAL_CALL
        LIB32_PRINTLN_CALL
        jmp ap_ipi_handler_done
get_lock:
        pause
        jmp do_ap_ipi_handler

ap_ipi_handler_done:
        lock btr DWORD [vacant], 0
        mov DWORD [APIC_BASE + EOI], 0
        iret64



        ;call QWORD far [conforming_callgate_pointer]        ; ���� call-gate for conforming ��
        
        ;call QWORD far [conforming_pointer]                        ; ����conforimg ����
        
;; �� 64 λ�л��� compatibility mode��Ȩ�޲��ı䣬0 ������        
        ;jmp QWORD far [compatibility_pointer]

;compatibility_pointer:
;                dq compatibility_kernel_entry              ; 64 bit offset on Intel64
;                dw code32_sel

;; �л��� compatibility mode������ 3 ����
;        push user_data32_sel | 3
;        push COMPATIBILITY_USER_ESP
;        push user_code32_sel | 3
;        push compatibility_user_entry
;        retf64

;; ʹ�� iret �л��� compatibility mode������ 3 ����
;        push user_data32_sel | 3
;        push COMPATIBILITY_USER_ESP
;        push 02h
;        push user_code32_sel | 3
;        push compatibility_user_entry
;        iretq

;        mov rsi, USER_CS
;        call read_segment_descriptor
;        btr rax, 47                                ; p=0
;        btr rax, 43                                ; code/data=0
;        btr rax, 41                                ; R=0
;        btr rax, 42                                ; c=1
;        btr rax, 45
;        mov rsi, 0x78
;        mov rdi, rax
;        call write_segment_descriptor
        

;; �л����û����롡
;        push USER_SS | 3
;        mov rax, USER_RSP
;        push rax
;        push USER_CS | 3
;        push user_entry
;        retf64

;; ʹ�� iret �л����û����롡                
;        push USER_SS | 3
;        mov rax, USER_RSP        
;        push rax
;        push 02h
;        push USER_CS | 3
;        push user_entry
;        iretq                                       ; ���ص� 3 ��Ȩ��
        



;;; ##### 64-bit �û����� #########

        bits 64
        
user_entry:

;##### �����ǲ���ʵ�� ########
; 1)�����ӡ virtual address 0xfffffff800000000 ���� table entry ��Ϣ
        mov esi, address_msg1
        LIB32_PUTS_CALL                        
        mov rsi, 0xfffffff800000000
        mov rax, SYSTEM_SERVICE_USER0
        int 40h
        LIB32_PRINTLN_CALL

; 2)�����ӡ virtual address 0x200000 ���� table entry ��Ϣ        
        mov esi, address_msg2
        LIB32_PUTS_CALL                        
        mov rsi, 0x200000
        mov rax, SYSTEM_SERVICE_USER0
        int 40h
        LIB32_PRINTLN_CALL
                
; 3)�����ӡ virtual address 0x800000 ���� table entry ��Ϣ        
        mov esi, address_msg3
        LIB32_PUTS_CALL                        
        mov rsi, 0x800000
        mov rax, SYSTEM_SERVICE_USER0
        int 40h
        LIB32_PRINTLN_CALL

; 3)�����ӡ virtual address 0 ���� table entry ��Ϣ        
        mov esi, address_msg4
        LIB32_PUTS_CALL                        
        mov rsi, 0
        mov rax, SYSTEM_SERVICE_USER0
        int 40h
        
                        
        
         jmp $
         
;        mov rsi, msg1
;        call strlen

        call QWORD far [conforming_callgate_pointer]        ; ���� call-gate for conforming ��                
;        call QWORD far [conforming_pointer]                ; ���� conforming ����

        jmp $

conforming_callgate_pointer:
        dq 0
        dw conforming_callgate_sel

       

address_msg1 db '---> dump virtual address 0xfffffff8_00000000 <---', 10, 0
address_msg2 db '---> dump virtual address 0x200000 <---', 10, 0
address_msg3 db '---> dump virtual address 0x800000 <---', 10, 0
address_msg4 db '---> dump virtual address 0 <---', 10, 0


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
        call compatibility_lib32_service                 ;; stub ������ʽ


        mov eax, [fs:100]
        
        mov esi, cmsg1
        mov eax, LIB32_PUTS
        call compatibility_sys_service_enter            ; compatibility ģʽ�µ� sys_service() stub ����

;; �����л��� 3�� 64-bit ģʽ����
        push USER_SS | 3
        push COMPATIBILITY_USER_ESP
        push USER_CS | 3                                ; �� 4G��Χ��
        push user_entry
        retf

;; ʹ�� iretָ��� compatibility ģʽ�л��� 3 �� 64-bit ģʽ
;        push USER_SS | 3
;        push USER_RSP
;        pushf
;        push USER_CS | 3                                ; �� 4G ��Χ��
;        push user_entry
;        iret                                            ; ʹ�� 32 λ������
        
        jmp $
        
cmsg1        db '---> Now: call sys_service() from compatibility mode with sysenter instruction', 10, 0
                
compatibility_entry_end:
 



        bits 64


%define MP
%define AP_LONG_ENTER

;** AP ���������� ***
%include "..\common\application_processor.asm"

        bits 64
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
                