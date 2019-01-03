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

        
; ���� #GP handler
        mov rsi, GP_HANDLER_VECTOR
        mov rdi, GP_handler
        call set_interrupt_descriptor
                        
; ���� #DB handler
        mov rsi, DB_HANDLER_VECTOR
        mov rdi, DB_handler
        call set_interrupt_descriptor
                                        

;; ���� conforming code segment descriptor        
        MAKE_SEGMENT_ATTRIBUTE 13, 0, 1, 0      ; type=conforming code segment, DPL=0, G=1, D/B=0
        mov r9, rax                             ; attribute
        mov rsi, conforming_code_sel            ; selector
        mov rdi, 0xFFFFF                        ; limit
        mov r8, 0                               ; base
        call set_segment_descriptor




;; ���� system service
        mov rsi, SYSTEM_SERVICE_VECTOR          ; 0x40
        mov rdi, system_service
        call set_user_interrupt_handler

;; ���� interrupt handler
        mov rsi, SYSTEM_SERVICE_VECTOR + 1      ; 0x41
        mov rdi, interrupt_handler
        call set_user_interrupt_handler

; �޸� gate descriptor        
        mov rsi, 0x41
        call read_idt_descriptor
        bts rax, 32                             ; IST = 1
        mov rsi, 0x41
        call write_idt_descriptor
        

;;;; ######  ������ʵ����Դ��� ##########        

;; �л��� compatibility mode������ 3 ����
        push user_data32_sel | 3
        push COMPATIBILITY_USER_ESP
        push user_code32_sel | 3
        push compatibility_entry     
        retf64

;;        call QWORD far [conforming_pointer]                        ; ����conforimg ����
        
;; �� 64 λ�л��� compatibility mode��Ȩ�޲��ı䣬0 ������        
;        jmp QWORD far [compatibility_pointer]


;; �л����û����롡
;        push USER_SS | 3
;        push ROCESSOR0_USER_RSP
;        push USER_CS | 3
;        push user_entry
;        retf64
                

compatibility_pointer:
                dq compatibility_entry              ; 64 bit offset on Intel64
                dw code32_sel





;;; ##### 64-bit �û����� #########

        bits 64
        
user_entry:
        
;        mov esi, msg1
;        mov eax, LIB32_PUTS
;        call lib32_service
        int 0x40        
        int 0x41

;        mov rsi, msg1
;        call strlen
        
;        call QWORD far [conforming_pointer]                ; ���� conforming ����
;        call QWORD far [gate_pointer]                        ; ���� conforming gate
        jmp $
;conforming_pointer:
;        dq puts64
;        dw 0x78        
gate_pointer:
        dq 0
        dw call_gate_sel        
;        jmp $

        

;;; ###### ������ 32-bit compatibility ģ�� ########                
        bits 32
compatibility_entry:
        mov ax, user_data32_sel | 3
        mov ds, ax
        mov es, ax


;; ͨ�� stub ������compaitibilityģʽ����call gate ����64λģʽ
        mov esi, cmsg1
        mov eax, LIB32_PUTS
        call compatibility_lib32_service                        ;; stub ������ʽ
        jmp $
        
        
                
compatibility_entry_end:
cmsg1       db '---> Now: enter compatibility mode', 10, 0
msg1        db 'entry long mode', 10, 0






;; ###### ������ 64 λ���̣�#######

        bits 64

;; 0x40���ж����̣�
system_service:
        jmp do_system_service
smsg1        db '---> Interrupt handler: RSP0 of 64-bit TSS is : ', 0
do_system_service:        
        mov esi, smsg1
        mov eax, LIB32_PUTS
        call lib32_service                        ;; stub ������ʽ        
        lea rdi, [rsp + 40]
        shr rdi, 32
        lea rsi, [rsp + 40]
        mov eax, LIB32_PRINT_QWORD_VALUE
        call lib32_service
        mov eax, LIB32_PRINTLN
        call lib32_service
        iretq
        

; 0x41���ж�����
interrupt_handler:
        jmp do_interrupt_handler
imsg1        db '---> Interrupt handler: IST1 of 64-bit TSS is : ', 0
do_interrupt_handler:        
        mov esi, imsg1
        mov eax, LIB32_PUTS
        call lib32_service                        ;; stub ������ʽ        
        lea rdi, [rsp + 40]
        shr rdi, 32
        lea rsi, [rsp + 40]
        mov eax, LIB32_PRINT_QWORD_VALUE
        call lib32_service
        mov eax, LIB32_PRINTLN
        call lib32_service
        iretq
        

;-----------------------------------------------
; strlen():
; input:
;                rsi: string
; output:
;                rax: length
; ������
;                �����������conforming�εĿ� routine
;-----------------------------------------------
strlen:
        jmp do_strlen
strlen_pointer:         dq        __strlen
                        dw        conforming_code_sel
do_strlen:        
        call QWORD far [strlen_pointer]
        ret





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


puts:           jmp LIB32_SEG + LIB32_PUTS * 5        


LONG_END:
                