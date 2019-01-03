; protected.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%define NON_PAGING
%include "..\inc\support.inc"
%include "..\inc\protected.inc"

; ���� protected ģ��

        bits 32
        
        org PROTECTED_SEG - 2

PROTECTED_BEGIN:
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN       ; protected ģ�鳤��

entry:
        
;; ���� #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler        

;; ���� #DB handler
        mov esi, DB_HANDLER_VECTOR
        mov edi, DB_handler
        call set_interrupt_handler

;; ���� #AC handler
        mov esi, AC_HANDLER_VECTOR
        mov edi, AC_handler
        call set_interrupt_handler

;; ���� #UD handler
        mov esi, UD_HANDLER_VECTOR
        mov edi, UD_handler
        call set_interrupt_handler
                
;; ���� #NM handler
        mov esi, NM_HANDLER_VECTOR
        mov edi, NM_handler
        call set_interrupt_handler
        
;; ���� #TS handler
        mov esi, TS_HANDLER_VECTOR
        mov edi, TS_handler
        call set_interrupt_handler

;; ���� TSS �� ESP0        
        mov esi, tss32_sel
        call get_tss_base
        mov DWORD [eax + 4], KERNEL_ESP
        
;; �ر����� 8259�ж�
        call disable_8259
        
;=======================================================        

        mov esi, call_gate_sel
        mov edi, call_gate_handler
        mov eax, 0
        call set_call_gate



;; ������ TSS ����
        mov esi, tss_sel
        call get_tss_base
        mov DWORD [eax + 32], tss_task_handler                  ; ���� EIP ֵΪ tss_task_handler
        mov DWORD [eax + 36], 0                                 ; eflags = 2H
        mov DWORD [eax + 56], USER_ESP                          ; esp
        mov WORD [eax + 76], USER_CS|3                          ; cs
        mov WORD [eax + 80], USER_SS|3                          ; ss
        mov WORD [eax + 84], USER_SS                            ; ds
        mov WORD [eax + 72], USER_SS                            ; es

        mov esi, msg2
        call puts
        mov eax, CLIB32_GET_CPL
        call clib32_service_enter
        mov esi, eax
        call print_byte_value
        call println        
        

; �� 0 ���л��� 3 ��        
        call tss_sel:0

        mov esi, msg1
        call puts        
        
; ��� CPL ֵ        
        mov esi, msg2
        call puts
        mov eax, CLIB32_GET_CPL
        call clib32_service_enter
        mov esi, eax
        call print_byte_value
        call println
        
        jmp $
; ת�� long ģ��
        ;jmp LONG_SEG
                                        
; ���� ring 3 ����
        push DWORD user_data32_sel | 0x3
        push esp
        push DWORD user_code32_sel | 0x3        
        push DWORD user_entry
        retf

        
;; �û�����

user_entry:
        mov ax, user_data32_sel
        mov ds, ax
        mov es, ax

; ��� CPL ֵ        
;        mov esi, msg2
;        call puts
;        call get_cpl
;        mov esi, eax
;        call print_byte_value
;        call println
                
; ʹ�� TSS ���������л�        
        call tss_sel:0        
        
        mov esi, msg1
        call puts        
        
; ��� CPL ֵ        
        mov esi, msg2
        call puts
        mov eax, CLIB32_GET_CPL
        call clib32_service_enter
        mov esi, eax
        call print_byte_value
        call println
        

        jmp $

msg1                db '---> now, switch back to old task,', 0
msg2                db 'CPL: ', 0

callgate_pointer:        dd        call_gate_handler
                         dw        call_gate_sel




;-----------------------------------------
; tss_task_handler()
;-----------------------------------------
tss_task_handler:
        jmp do_tss_task
tmsg1        db '---> now, switch to new Task,', 0        
tmsg2        db 'CPL:', 0
do_tss_task:
        mov esi, tmsg1
        call puts

; ��� CPL ֵ        
        mov esi, tmsg2
        call puts
        mov eax, CLIB32_GET_CPL
        call clib32_service_enter
        mov esi, eax
        call print_byte_value
        call println
                
        ;clts                                                ; �� CR0.TS ��־λ
; ʹ�� iret ָ���л���ԭ task
        iret


;------------------------------------------
; sys_service():  system service entery
;-----------------------------------------
sys_service:
        jmp do_syservice
smsg1        db '---> Now, enter the system service', 10, 0
do_syservice:        
        mov esi, smsg1
        call puts
        sysexit

;-----------------------------------------
; call_gate_handler()
;----------------------------------------
call_gate_handler:
        jmp do_callgate
cgmsg1        db '---> Now, enter the call gate', 10, 0
do_callgate:        
        mov esi, cgmsg1
        call puts
        ret
        
 



;******** include �ж� handler ���� ********
%include "..\common\handler32.asm"


;********* include ģ�� ********************
%include "..\lib\creg.asm"
%include "..\lib\cpuid.asm"
%include "..\lib\msr.asm"
%include "..\lib\pci.asm"
%include "..\lib\debug.asm"
%include "..\lib\page32.asm"
%include "..\lib\apic.asm"
%include "..\lib\pic8259A.asm"



;;************* ���������  *****************

; ��� lib32 �⵼������ common\ Ŀ¼�£�
; ������ʵ��� protected.asm ģ��ʹ��

%include "..\common\lib32_import_table.imt"




PROTECTED_END: