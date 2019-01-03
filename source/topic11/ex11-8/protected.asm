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
        
;; �ر�8259�ж�
        call disable_8259

;; ���� #PF handler
        mov esi, PF_HANDLER_VECTOR
        mov edi, PF_handler
        call set_interrupt_handler        

;; ���� #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler
        
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
        call init_pae_paging
        
;���� PDPT ���ַ        
        mov eax, PDPT_BASE
        mov cr3, eax
                                
; �򿪡�paging
        mov eax, cr0
        bts eax, 31
        mov cr0, eax               
                  
                
        
; ʵ�� ex11-8������ XD��־�� 0 ��Ϊ 1ʱ������

; 1) �����Ժ������Ƶ� 0x400000λ����
        mov esi, func
        mov edi, 0x400000                                ; �� user���븴�Ƶ� 0x400000 λ����
        mov ecx, func_end - func
        rep movsb

        ; ����0x400000��ַ���Ϊ��ִ��
        mov DWORD [PT1_BASE + 0 * 8 + 4], 0

; 2���� 1 ��ִ�� 0x400000���Ĵ��루��ʱ�ǿ�ִ�е�,XD=0����Ŀ���ǣ��� TLB �н�����Ӧ�� TLB entry
        call DWORD 0x400000
        
; 3���� 0x400000 ��Ϊ����ִ�еģ����Ǵ�ʱûˢ�� TLB
        mov DWORD [PT1_BASE + 0 * 8 + 4], 0x80000000
        
; 4���� 2 ��ִ�� 0x400000 ���Ĵ��룬��Ȼ�������ģ���ʱ��XD=1��
        call DWORD 0x400000                                

        mov esi, msg4
        call puts

; 5������ˢ�� TLB, ʹ 0x400000 �� TLB ʧЧ
        invlpg [0x400000]

; 6) ��3��ִ�� 0x400000 ���Ĵ��룬������ #PF �쳣
        call DWORD 0x400000
                
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



;; ���Ժ���
func:
        mov edx, puts
        mov ebx, dump_pae_page        
                
        mov esi, msg2
        call edx                
        mov esi, msg3
        call edx        
        mov esi, 0x400000                ; dump virtual address 0x400000
        call ebx
        ret
func_end:        

                        
msg1        db  'now: enable paging with PAE paging '
msg2        db   10, 'now: enter the 0x400000 address<---', 10, 0
msg3        db  '---> dump vritual address: 0x400000 <---', 10, 0
msg4        db  10, 'now: execution INVLPG instruction flush TLB !', 10, 10, 0




        
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