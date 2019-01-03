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

        call init_page

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
        mov rsp, PROCESSOR0_KERNEL_RSP


;===== ������ long-mode ���������ô��� ==========


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
        mov r8, SYSTEM_DATA64_BASE + (__task_status_segment - __system_data64_entry)
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

;======== long-mode �������ô������=============


;; ʵ�� ex14-6������ 64-bit ģʽ�µ� LBR stack        

; 1)������ LBR        
        mov ecx, IA32_DEBUGCTL
        rdmsr
        bts eax, 0                                             ; LBR = 1
        wrmsr

; 2) ���ù�������        
        mov ecx, MSR_LBR_SELECT
        mov edx, 0
        mov eax, 0xc4                                        ; JCC = NEAR_IND_JMP = NEAR_REL_JMP = 1
        wrmsr

; 3) ���� branch
        mov esi, msg
        LIB32_PUTS_CALL                                        ; ���� lib32 ��� puts() ����

; 4) �ر� LBR
        mov ecx, IA32_DEBUGCTL
        rdmsr
        btr eax, 0                                                ; LBR = 0
        wrmsr

; 5) ��� LBR stack ��Ϣ        
        call dump_lbr_stack
               
                
        jmp $


msg     db '>>> now: test 64-bit LBR stack <<<', 10, 10, 0


        
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
                