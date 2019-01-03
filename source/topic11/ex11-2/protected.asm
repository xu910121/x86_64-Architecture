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
        
;; Ϊ�����ʵ�飬�ر�ʱ���жϺͼ����ж�
        call disable_timer

;; ���� #PF handler
        mov esi, PF_HANDLER_VECTOR
        mov edi, page_fault_handler
        call set_interrupt_handler        

;; ���� #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler        

; ���������
        inc DWORD [index]

;; ���� sysenter/sysexit ʹ�û���
        call set_sysenter
        
        
; ��ʼ�� paging ����
        call init_32bit_paging
        
;���� PDT ���ַ        
        mov eax, PDT32_BASE
        mov cr3, eax

;���� CR4.PSE
        call pse_enable
                
; �򿪡�paging
        mov eax, cr0
        bts eax, 31
        mov cr0, eax                
        
; ת�� long ģ��
        ;jmp LONG_SEG
        
;���Զ����� CR0.WP=0ʱ����0��������д0x400000��ַ
;        mov DWORD [0x400000], 0                        

;��������CR0.WP=1ʱ��д0x400000
;        mov eax, cr0
;        bts eax, WP_BIT
;        mov cr0, eax        
;        mov DWORD [0x400000], 0                                
                                
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

        mov esi, msg1
        call puts
        
        mov esi, 0x200000                ; dump virtual address 0x200000
        call dump_page
        
        mov esi, msg3
        call puts
        
        mov esi, 0x400000                ; dump virtual address 0x400000
        call dump_page
        
;; ����һ�����û��������� 0x400000 ��ַд���ݽ����� #PF�쳣
;        mov DWORD [0x400000], 0

;        mov esi, msg3
;        call puts
        
;        mov esi, 0x400000                ; dump virtual address 0x400000
;        call dump_page
        
        
        jmp $

                        
msg1        db  'now: enable paging with 32-bit paging '
msg2        db  10, 10, '---> dump vritual address: 0x200000 ---', 10, 0
msg3        db  10, 10, '---> dump vritual address: 0x400000 ---', 10, 0





;;; ��ʼ�� 32-bit paging ģʽʹ�û���

pse_enable:
        mov eax, 1
        cpuid
        bt edx, 3                                ; PSE support?
        jnc pse_enable_done
        mov eax, cr4
        bts eax, 4                                ; CR4.PSE = 1
        mov cr4, eax
pse_enable_done:        
        ret
        

;---------------------------------------------
; init_32bit_paging(): ���� 32-bit paging ����
;---------------------------------------------
init_32bit_paging:
; 1) 0x000000-0x3fffff ӳ�䵽 0x0 page frame, ʹ�� 4M ҳ��
; 2) 0x400000-0x400fff ӳ�䵽 0x400000 page frame ʹ�� 4K ҳ��

;; PDT �������ַ���� 0x200000 λ����, PT�������ַ�� 0x201000λ����
; 1) ���� PDT[0]��ӳ�� 0 page frame)
        mov DWORD [PDT32_BASE + 0], 0000h | PS | RW | US | P              ; base=0, PS=1,  P=1,R/W=1,U/S=1, 
        
; 2) ���� PDT[1]
        ; PT��ĵ�ַ��0x201000λ���ϣ�����Ϊsupervisor,only-read Ȩ��
        mov DWORD [PDT32_BASE + 1 * 4], 201000h | P                       ; PT base=0x201000, P=1

; 3) ���� PT[0]��ӳ��0x400000 page frame),����Ϊsupervisor,only-read Ȩ��
        mov DWORD [201000h + 0], 400000h | P                            ; page frame��0x400000, P=1
        ret





;--------------------------------------
; #PF handler
;-------------------------------------
page_fault_handler:
        jmp do_page_fault_handler
page_fault_msg db '---> now, enter #PF handler', 10, 0
do_page_fault_handler:        
        mov esi, pf_msg
        call puts
        jmp $
        iret


        

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