; protected.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\support.inc"
%include "..\inc\protected.inc"

; ���� protected ģ��

        bits 32
        
        org PROTECTED_SEG - 2

PROTECTED_BEGIN:
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN       ; protected ģ�鳤��

entry:
        
;; Ϊ�����ʵ�飬�ر�ʱ���жϺͼ����ж�
        call disable_timer
        
;; ���� #PF handler
        mov esi, PF_HANDLER_VECTOR
        mov edi, PF_handler
        call set_interrupt_handler        

;; ���� #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler

; ���� #DB handler
        mov esi, DB_HANDLER_VECTOR
        mov edi, DB_handler
        call set_interrupt_handler


;; ���� sysenter/sysexit ʹ�û���
        call set_sysenter

;; ���� system_service handler
        mov esi, SYSTEM_SERVICE_VECTOR
        mov edi, system_service
        call set_user_interrupt_handler 

; ����ִ�� SSE ָ��        
        mov eax, cr4
        bts eax, 9                                ; CR4.OSFXSR = 1
        mov cr4, eax
        
        
;���� CR4.PAE
        call pae_enable
        
; ���� XD ����
        call execution_disable_enable
                
; ��ʼ�� paging ����
        call init_pae_paging
        
;���� PDPT ���ַ        
        mov eax, PDPT_BASE
        mov cr3, eax
                                
; �򿪡�paging
        mov eax, cr0
        bts eax, 31
        mov cr0, eax                                 

        mov esi, PIC8259A_TIMER_VECTOR
        mov edi, timer_handler
        call set_interrupt_handler        

        mov esi, KEYBOARD_VECTOR
        mov edi, keyboard_handler
        call set_interrupt_handler                
        
        call init_8259A
        call init_8253        
        call disable_8259
        
        sti
        
;========= ��ʼ��������� =================


; 1) ����APIC
        call enable_xapic        
        
; 2) ���� APIC performance monitor counter handler
        mov esi, APIC_PERFMON_VECTOR
        mov edi, apic_perfmon_handler
        call set_interrupt_handler
        
        
; ���� LVT performance monitor counter
        mov DWORD [APIC_BASE + LVT_PERFMON], FIXED_DELIVERY | APIC_PERFMON_VECTOR
        

;*
;* ʵ�� ex15-13: ����CPIֵ
;*
        ;*
        ;* perfmon ��ʼ����
        ;* �ر����� counter �� PEBS 
        ;* �� overflow ��־λ
        ;*
        DISABLE_GLOBAL_COUNTER
        DISABLE_PEBS
        RESET_COUNTER_OVERFLOW


; 1) �õ� non-halted CPI ֵ
        mov esi, test_func                      ; �������ĺ���
        call get_unhalted_cpi                   ; �õ� CPI ֵ
        mov ebx, eax
        mov esi, msg1
        call puts
        mov esi, ebx
        call print_dword_decimal                ; ��ӡ CPI ֵ
        call println
        call println

; 2)�õ� nominal CPI ֵ
        mov esi, test_func
        call get_nominal_cpi
        mov ebx, eax
        mov esi, msg2
        call puts
        mov esi, ebx
        call print_dword_decimal
        call println
        call println

; 3)�õ� non-halted CPI ֵ
        mov esi, test_print_float
        call get_unhalted_cpi
        mov ebx, eax
        mov esi, msg1
        call puts
        mov esi, ebx
        call print_dword_decimal
        call println
        call println

; 4���õ� nomial CPI ֵ
        mov esi, test_print_float
        call get_nominal_cpi
        mov ebx, eax
        mov esi, msg2
        call puts
        mov esi, ebx
        call print_dword_decimal
        call println
        call println
        
        jmp $
     
    

        
; ת�� long ģ��
        ;jmp LONG_SEG
                                
                                
; ���� ring 3 ����
        push DWORD user_data32_sel | 0x3
        push DWORD USER_ESP
        push DWORD user_code32_sel | 0x3        
        push DWORD user_entry
        retf

        
;; �û�����

user_entry:
        mov ax, user_data32_sel
        mov ds, ax
        mov es, ax

user_start:

        jmp $

msg1    db '<non-halted CPI>: ', 0
msg2    db '<nominal CPI>: ', 0


;*
;* ���� float ��Ԫ
;*
test_print_float:
        jmp do_test_print_float
f1      dd 1.3333
tpf_msg db 'the float is: ', 0
do_test_print_float:
        finit
        mov esi, tpf_msg
        call puts
        mov esi, f1
        call print_dword_float
        call println
        ret 


;*
;* �����ַ���
;*
test_func:
        jmp do_test_func
test_msg db 'this is a test message', 10, 0
do_test_func:
        mov esi, test_msg
        mov eax, SYS_PUTS
        int SYSTEM_SERVICE_VECTOR
        ret
        








%define APIC_PERFMON_HANDLER

;******** include �ж� handler ���� ********
%include "..\common\handler32.asm"


;********* include ģ�� ********************
%include "..\lib\creg.asm"
%include "..\lib\cpuid.asm"
%include "..\lib\msr.asm"
%include "..\lib\pci.asm"
%include "..\lib\apic.asm"
%include "..\lib\debug.asm"
%include "..\lib\perfmon.asm"
%include "..\lib\page32.asm"
%include "..\lib\pic8259A.asm"


;;************* ���������  *****************

; ��� lib32 �⵼������ common\ Ŀ¼�£�
; ������ʵ��� protected.asm ģ��ʹ��

%include "..\common\lib32_import_table.imt"


PROTECTED_END: