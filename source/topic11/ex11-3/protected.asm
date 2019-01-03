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
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN        ; protected ģ�鳤��

entry:
        
;; �ر�8259�ж�
        call disable_8259

;; ���� #PF handler
        mov esi, PF_HANDLER_VECTOR
        mov edi, page_fault_handler
        call set_interrupt_handler        

;; ���� #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler

        inc DWORD [index]
        
;; ���� sysenter/sysexit ʹ�û���
        call set_sysenter

; ����ִ�� SSE ָ��        
        mov eax, cr4
        bts eax, 9                                ; CR4.OSFXSR = 1
        mov cr4, eax
        
        
;���� CR4.PAE
        call pae_enable
        
; ���� XD ����
        call execution_disable_enable
                
; ��ʼ�� paging ����
        call init_pae32_paging
        
;���� PDPT ���ַ        
        mov eax, PDPT_BASE
        mov cr3, eax
                                
; �򿪡�paging
        mov eax, cr0
        bts eax, 31
        mov cr0, eax                
        
;=======================================


; ����һ����XDҳ��ִ�д���
;        mov esi, user_start
;        mov edi, 0x400000                                ; �� user���븴�Ƶ� 0x400000 λ����
;        mov ecx, user_end - user_start
;        rep movsb
        
;        jmp DWORD 0x400000                                ; ��ת�� 0x400000 ��

                
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

;; ʹ�� puts()�� dump_pae_page() �ľ��Ե�ַ��ʽ        
        mov edx, puts
        mov ebx, dump_pae_page        
        
        mov esi, msg1
        call edx
        mov esi, 0x200000                ; dump virtual address 0x200000
        call ebx
        
        mov esi, msg3
        call edx        
        mov esi, 0x400000                ; dump virtual address 0x400000
        call ebx

        mov esi, msg4
        call edx        
        mov esi, 0x401000                ; dump virtual address 0x401000
        call ebx        
        
        mov esi, msg5
        call edx        
        mov esi, 0x600000                ; dump virtual address 0x600000
        call ebx
                
;        mov esi, msg6
;        call puts        
;        mov esi, 0x40000000                ; dump virtual address 0x40000000
;        call dump_pae_page
                        

        jmp $

user_end:

                        
msg1        db  'now: enable paging with PAE paging '
msg2        db  10, 10, '---> dump vritual address: 0x200000 <---', 10, 0
msg3        db  10, 10, '---> dump vritual address: 0x400000 <---', 10, 0
msg4        db  10, 10, '---> dump vritual address: 0x401000 <---', 10, 0
msg5        db  10, 10, '---> dump vritual address: 0x600000 <---', 10, 0
msg6        db  10, 10, '---> dump vritual address: 0x40000000 <---', 10, 0




;-------------------------------------------------------------
; init_page32_paging(): ��ʼ�� 32 λ������ PAE paging ��ҳģʽ
;-------------------------------------------------------------
init_pae32_paging:
; 1) 0x000000-0x3fffff ӳ�䵽 0x0 page frame, ʹ�� 2�� 2M ҳ��
; 2) 0x400000-0x400fff ӳ�䵽 0x400000 page frame ʹ�� 4K ҳ��


;; ���ڴ�ҳ�棨���һ�����Ѳ�� bug��
        mov esi, PDPT_BASE
        call clear_4k_page
        mov esi, 201000h
        call clear_4k_page
        mov esi, 202000h
        call clear_4k_page


;* PDPT_BASE ������ page.inc 
;; 1) ���� PDPTE[0]
        mov DWORD [PDPT_BASE + 0 * 8], 201000h | P        ; base=0x201000, P=1
        mov DWORD [PDPT_BASE + 0 * 8 + 4], 0

        
;; 2) ���� PDE[0], PDE[1] �Լ� PDE[2]
        ;* PDE[0] ��Ӧ virtual address: 0 �� 1FFFFFh (2Mҳ)
        ;* ʹ�� PS=1, R/W=1, U/S=1, P=1 ����
        ;** PDE[1] ��Ӧ virtual address: 200000h �� 3FFFFFh (2Mҳ��
        ;** ʹ�� PS=1,R/W=1, U/S=1, P=1 ����
        ;*** PDE[2] ��Ӧ virtual address: 400000h �� 400FFFh (4Kҳ��
        ;*** ʹ�� R/W=1, U/S=1, P=1
        mov DWORD [201000h + 0 * 8], 0000h | PS | RW | US | P 
        mov DWORD [201000h + 0 * 8 + 4], 0
        mov DWORD [201000h + 1 * 8], 200000h | PS | RW | US | P
        mov DWORD [201000h + 1 * 8 + 4], 0
        mov DWORD [201000h + 2 * 8], 202000h | RW | US | P
        mov DWORD [201000h + 2 * 8 + 4], 0
        
;; 3) ���� PTE[0]
        ;** PTE[0] ��Ӧ virtual address: 0x400000 �� 0x400fff (4Kҳ��
        ; 400000h ʹ�� Execution disable λ
        mov DWORD [202000h + 0 * 8], 400000h | P                      ; base=0x400000, P=1, R/W=U/S=0
        mov eax, [xd_bit]
        mov DWORD [202000h + 0 * 8 + 4], eax                          ; ���� XD��λ
        ret
                








;----------------------------------------------
; #PF handler;
;----------------------------------------------
page_fault_handler:
        jmp do_page_fault_handler
pfmsg   db '---> now, enter #PF handler', 10
        db 'occur at: 0x', 0
pfmsg2  db 10, 'fixed the error', 10, 0                
do_page_fault_handler:        
        add esp, 4                              ; ���� Error code
        push ecx
        push edx
        mov esi, pfmsg
        call puts
        
        mov ecx, cr2                            ; ����#PF�쳣��virtual address
        mov esi, ecx
        call print_dword_value
        
        mov esi, pfmsg2
        call puts

;; ������������
        mov eax, ecx
        shr eax, 30
        and eax, 0x3                            ; PDPTE index
        mov eax, [PDPT_BASE + eax * 8]
        and eax, 0xfffff000
        mov esi, ecx
        shr esi, 21
        and esi, 0x1ff                          ; PDE index
        mov eax, [eax + esi * 8]
        btr DWORD [eax + esi * 8 + 4], 31       ; �� PDE.XD
        bt eax, 7                               ; PDE.PS=1 ?
        jc do_pf_handler_done
        mov esi, ecx
        shr esi, 12
        and esi, 0x1ff                          ; PTE index
        and eax, 0xfffff000
        btr DWORD [eax + esi * 8 + 4], 31       ; �� PTE.XD
do_page_fault_handler_done:        
        pop edx
        pop ecx
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