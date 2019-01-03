; protected.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\support.inc"
%include "..\inc\protected.inc"

; ���� protected ģ��

        bits 32
        
        org PROTECTED_SEG - 2

PROTECTED_BEGIN:
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN           ; protected ģ�鳤��

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

;; ���� TSS �� ESP0        
        mov esi, tss32_sel
        call get_tss_base
        mov DWORD [eax + 4], 9FFFh
        
                
;; �ر����� 8259�ж�
        call disable_8259


;################  ʵ�����  ###########################        

; SMRAM control
        SET_SMRAM_OPEN                       ; �� D_OPEN Ϊ 1���� SMRAM ����

; �� SMI handler д�� a8000 ��
        mov ecx, CSEG_SMM_END - CSEG_SMM_BEGIN
        mov esi, CSEG_SMM_BEGIN
        mov edi, 0A8000h
        rep movsb

; �� Tseg SMM д�� 2000000h ��
        mov ecx, TSEG_SMM_END - TSEG_SMM_BEGIN
        mov esi, TSEG_SMM_BEGIN
        mov edi, 2008000h
        rep movsb


;; д SMI_EN �Ĵ����� APMC_EN λ
        call get_PMBASE
        mov edx, eax
        add edx, 30h                        ; SMI_EN �Ĵ���λ��
        in eax, dx                          ; �� DWORD
        bts eax, 5                          ; APMC_EN = 1
        out dx, eax                         ; д DWORD
        

;; ��1�δ��� SMI#������ SMI handler �� 0A8000h ��                
        mov dx, APM_CNT
        out dx, al
        
        
;; #### ʵ��: �� SMI handler ���ݲ��� ########
        mov ebx, 100FFFCh                        ; �� ebx ���� 100FFFCh �� SMI handler ���ݲ���
        mov al, 01                               ; �������� 1
        mov dx, APM_STS                         ; ͨ�� APM status �Ĵ����� SMI handler ��������
        out dx, al
        
        
        
;; ��2�δ��� SMI# ���� SMI handler �� 2008000h λ��        
        mov dx, APM_CNT
        out dx, al        
        
;; *** �������̽�� SMRAM �����ʵ�� ***        
;; 1. �� D_OPEN = 1 ������£�����̽�� SMRAM ����
        SET_SMRAM_CLOSE                                ; �ر�Ϊ����ʾ���
        mov esi, msg12
        call puts
        SET_SMRAM_OPEN                                ; �򿪽���̽��
        call enumerate_smi_region

;; �� SMI handler ����        
        SET_SMRAM_CLOSE                               ; �� D_OPEN λ���ر� SMRAM ����


;; 2. �� D_OPEN = 0 ������£�������� SMRAM ����

;; ̽�� SMRAM ����        
        mov esi, msg13
        call puts
        call enumerate_smi_region        
        

        mov dx, APM_STS
        in al, dx
        cmp al, 1
        jnz next

;; �����ʵ������ SMI handler �︴�� State Save Map ��Ϣ���ṩ��λ���� ****
;; *** ��ӡ SMM State Save Map ������Ϣ������)        
        mov esi, msg14
        call puts
        
        mov ebx, 1000000h
;*** ��� ES ��Ϣ        
        mov esi, es_msg
        call puts
        mov esi, selector_msg
        call puts
        mov si, WORD [ebx + 0FE00h]                   ; selector
        call print_word_value
        call printblank
        mov esi, attribute_msg
        call puts
        mov si, WORD [ebx + 0FE02h]                  ; attribute
        call print_word_value
        call printblank        
        mov esi, limit_msg
        call puts
        mov esi, DWORD [ebx + 0FE04h]                ; limit
        call print_dword_value
        call printblank        
        mov esi, base_msg
        call puts
        mov esi, DWORD [ebx + 0FE08h]                ; base[31:0]
        mov edi, DWORD [ebx + 0FE0Ch]                ; base[63:32]
        call print_qword_value
        call println
        
;*** ��� CS ��Ϣ        
        mov esi, cs_msg
        call puts
        mov esi, selector_msg
        call puts
        mov si, WORD [ebx + 0FE10h]                   ; selector
        call print_word_value
        call printblank
        mov esi, attribute_msg
        call puts
        mov si, WORD [ebx + 0FE12h]                   ; attribute
        call print_word_value
        call printblank        
        mov esi, limit_msg
        call puts
        mov esi, DWORD [ebx + 0FE14h]                ; limit
        call print_dword_value
        call printblank        
        mov esi, base_msg
        call puts
        mov esi, DWORD [ebx + 0FE18h]                ; base[31:0]
        mov edi, DWORD [ebx + 0FE1Ch]                ; base[63:32]
        call print_qword_value
        call println        
        
;*** ��� SS ��Ϣ        
        mov esi, ss_msg
        call puts
        mov esi, selector_msg
        call puts
        mov si, WORD [ebx + 0FE20h]                 ; selector
        call print_word_value
        call printblank
        mov esi, attribute_msg
        call puts
        mov si, WORD [ebx + 0FE22h]                 ; attribute
        call print_word_value
        call printblank        
        mov esi, limit_msg
        call puts
        mov esi, DWORD [ebx + 0FE24h]                ; limit
        call print_dword_value
        call printblank        
        mov esi, base_msg
        call puts
        mov esi, DWORD [ebx + 0FE28h]                ; base[31:0]
        mov edi, DWORD [ebx + 0FE2Ch]                ; base[63:32]
        call print_qword_value
        call println        
        
;*** ��� DS ��Ϣ        
        mov esi, ds_msg
        call puts
        mov esi, selector_msg
        call puts
        mov si, WORD [ebx + 0FE30h]                ; selector
        call print_word_value
        call printblank
        mov esi, attribute_msg
        call puts
        mov si, WORD [ebx + 0FE32h]                 ; attribute
        call print_word_value
        call printblank        
        mov esi, limit_msg
        call puts
        mov esi, DWORD [ebx + 0FE34h]                ; limit
        call print_dword_value
        call printblank        
        mov esi, base_msg
        call puts
        mov esi, DWORD [ebx + 0FE38h]                ; base[31:0]
        mov edi, DWORD [ebx + 0FE3Ch]                ; base[63:32]
        call print_qword_value
        call println        
        call println
        
;*** ��� GDTR ��Ϣ        
        mov esi, gdtr_msg
        call puts
        mov esi, base_msg
        call puts
        mov esi, DWORD [ebx + 0FE68h]                ; base[31:0]
        mov edi, DWORD [ebx + 0FE6Ch]                ; base[63:32]
        call print_qword_value
        call printblank                
        mov esi, limit_msg
        call puts        
        mov si, WORD [ebx + 0FE64h]                ; limit
        call print_word_value        
        call println
        
;*** ��� IDTR ��Ϣ        
        mov esi, idtr_msg
        call puts
        mov esi, base_msg
        call puts
        mov esi, DWORD [ebx + 0FE88h]                ; base[31:0]
        mov edi, DWORD [ebx + 0FE8Ch]                ; base[63:32]
        call print_qword_value
        call printblank        
        mov esi, limit_msg
        call puts        
        mov si, WORD [ebx + 0FE84h]                  ; limit
        call print_dword_value        
        call println
                

;*** ��� LDTR ��Ϣ        
        mov esi, ldtr_msg
        call puts
        mov esi, selector_msg
        call puts
        mov si, WORD [ebx + 0FE70h]               ; selector
        call print_word_value
        call printblank
        mov esi, attribute_msg
        call puts
        mov si, WORD [ebx + 0FE72h]                 ; attribute
        call print_word_value
        call printblank        
        mov esi, limit_msg
        call puts
        mov esi, DWORD [ebx + 0FE74h]                ; limit
        call print_dword_value
        call printblank        
        mov esi, base_msg
        call puts
        mov esi, DWORD [ebx + 0FE78h]                ; base[31:0]
        mov edi, DWORD [ebx + 0FE7Ch]                ; base[63:32]
        call print_qword_value
        call println
                

;*** ��� TR ��Ϣ        
        mov esi, tr_msg
        call puts
        mov esi, selector_msg
        call puts
        mov si, WORD [ebx + 0FE90h]                 ; selector
        call print_word_value
        call printblank
        mov esi, attribute_msg
        call puts
        mov si, WORD [ebx + 0FE92h]                 ; attribute
        call print_word_value
        call printblank        
        mov esi, limit_msg
        call puts
        mov esi, DWORD [ebx + 0FE94h]                ; limit
        call print_dword_value
        call printblank        
        mov esi, base_msg
        call puts
        mov esi, DWORD [ebx + 0FE98h]                ; base[31:0]
        mov edi, DWORD [ebx + 0FE9Ch]                ; base[63:32]
        call print_qword_value
        call println
        call println
                        
; ��ӡ SMBASE 
        mov esi, smbase_msg
        call puts
        mov esi, [ebx + 0FF00h]                        
        call print_dword_value
        call println

; ��ӡ Rip
        mov esi, rip_msg
        call puts
        mov esi, [ebx + 0FF78h]        
        mov edi, [ebx + 0FF7Ch]
        call print_qword_value
        call println

; ��ӡ Rflags
        mov esi, rflags_msg
        call puts
        mov esi, [ebx + 0FF70h]
        mov edi, [ebx + 0FF74h]        
        call print_qword_value
        call println        

next:
                        
                                                
; ���� ring 3 ����
        push DWORD user_data32_sel | 0x3
        push esp
        push DWORD user_code32_sel | 0x3        
        push DWORD user_entry
        retf
        
        
no_support:
        mov esi, msg8
        call puts
        
        jmp $


user_entry:
        mov ax, user_data32_sel | 0x3
        mov ds, ax
        mov es, ax

        
        jmp $




msg1                db 'Now: CPL=0, eflags value is:', 0
msg2                db 'Now: test the #DB exception...', 10,0
msg3                db 'Now: modify the eflags.IOPL to level 2 from 0', 0
msg4                db 'Now: CPL=3, eflags value is:', 10, 0
msg5                db 'Now: try to read port 0x21', 10, 0
msg6                db 'Now: try to write port 0x21', 10, 0
msg7                db 'success!', 10, 0
msg8                db 'no support!', 10, 0
msg9                db 10, 'Now: set variable-rang', 10, 0
msg10                db 10, 'Now: exit the system service', 10, 0
msg11                db 10,  '---> Now: set monitor/mwait to disable, and monitor line size <---', 10, 10, 0
msg12                db '---> Now: D_OPEN = 1 <---', 10, 0
msg13                db '---> Now: D_OPEN = 0 <---', 10, 0
msg14                db 10, 10, '>>>> SMM State Save Map information(partial) <<<<<', 10, 10, 0
value_address        dq 0, 0
mem32int             dd 0

selector_msg        db 'selector:', 0
attribute_msg       db 'attribute:', 0
limit_msg           db 'limit:', 0
base_msg            db 'base:', 0

es_msg              db '<ES:> ', 0
cs_msg              db '<CS:> ', 0
ss_msg              db '<SS:> ', 0
ds_msg               db '<DS:> ', 0
fs_msg               db '<FS:> ', 0
gs_msg               db '<GS:> ', 0
gdtr_msg             db '<GDTR:> ', 0
ldtr_msg             db '<LDTR:> ', 0
idtr_msg             db '<IDTR:> ', 0
tr_msg               db '<TR:>   ', 0

smbase_msg           db 'SMBASE: ', 0
rip_msg              db 'RIP:    ', 0
rflags_msg           db 'Rflags: ', 0


;####### ������ SMM ���� #######

CSEG_SMM_BEGIN:

        bits 16        

;#
;# ��� SMI handler ��Ŀ�����ض�λ�� 200000h λ���� ###
;#
cseg_smi_entry:
        mov ebx, 0AFEFCh                        ; SMM revision id
        mov al, [ebx]
        cmp al, 0x64                                ; ���� SMM �汾
        je new_rev
        mov ebx, 0AFEF8h
        jmp set_SMBASE
new_rev:
        mov ebx, 0AFF00h
set_SMBASE:        
        mov eax, 2000000h                        ; 32M �߽�
        mov [ebx], eax                            ; �µ� SMBASE

;; ���Դ� CR0.PE = 1
;        db 0x66
;        lgdt [DWORD gdt_pointer- cseg_smi_entry + 0xa8000]
;        mov eax, cr0
;        bts eax, 0
;        mov cr0, eax        
;        jmp DWORD 08:smi_next-cseg_smi_entry + 0xa8000
;        bits 32
;smi_next:
;        mov ax, 0x10
;        mov ds, ax        

; ���Ե����ж�
;        int 13h                

; ���� jmp far
        ;jmp DWORD 0:0x2008000                ; Զ����
        
;; ���� SMM ����жϵ���        
        ;db 0x66
        ;lidt [DWORD smm_ivt - cseg_smi_entry + 0xa8000]
        ;int 0

;; ���� SMM ��ĵ�������        
;        pushfd
;        bts DWORD [esp], 8
;        popfd
;        mov eax, 1
;        mov eax, 2

;; ���� I/O restart
;        mov BYTE [DWORD 0AFEC8h], 0FFh

;; ���� CR0/CR4
;        mov eax, [DWORD 0A0000h + 0FF58h]                ; CR0 image
;        btr eax, 30                                                                ; CR0.CD = 0
;        bts eax, 29                                                                ; CR0.NW = 1
;        mov [DWORD 0A0000h + 0FF58h], eax                ; write CR0 image
        rsm

smm_ivt        dw 0x3ff
                dd vector0 -cseg_smi_entry + 0xa8000
        
IVT:
vector0        dw        8000H                        ;; ��!! vector 0 ��ת�� SMI handler ��ڵ�
               dw         0A000H

GDT:
                                  dq 0
kernel_code32_desc                dq 0x00cf9a000000ffff                ; non-conforming, accessed, DPL=0, P=1
kernel_data32_desc                dq 0x00cf92000000ffff                ; DPL=0, P=1, writeable/accessed, expand-up
GDT_END:

gdt_pointer:
        dw GDT_END - GDT -1
        dd GDT-cseg_smi_entry + 0xa8000
                                
CSEG_SMM_END:





TSEG_SMM_BEGIN:
;#
;### ��������յ� SMI handler
;#

tseg_smi_entry:
        mov dx, APM_STS
        in al, dx                          ; ����������
        cmp al, 01                         ; �Ƿ�Ϊ���� 1
        jnz smi_handler_done
        
        mov ebx, 200FEFCh                ; SMM revision id ��λ��
        cmp byte [ebx], 64h                ; �����Ƿ�Ϊ�汾 64h
        je rev_64h
        mov ebx, 2007FDCh                ; Intel �汾�� ebx �Ĵ���λ��
        jmp read_ebx
rev_64h:        
        mov ebx, 200FFE0h                ; AMD64 �汾�� rbx �Ĵ���λ��
read_ebx:        
        mov edi, [ebx]                   ; ��ȡ ebx �Ĵ�����ֵ�����ݹ��Ĳ���-ջ�ף�
        
;; �����Ǹ��� SMI handler �� state save ����Ŀ��λ���ϣ���ebx�Ĵ����������Ĳ�����
        mov esi, 200FFFCh                ; save �������ʼλ��(ջ�ף�
        mov ecx, (2010000h-200FC00h)/4
        std
        db 0x67                  ; address size override ����
        rep movsd
        
        mov al, 01
smi_handler_done:
        mov dx, APM_STS
        out dx, al
        rsm                
TSEG_SMM_END:                




;###############################

        bits 32

enumerate_smi_region:
        jmp do_enumerate_smi_region
es_msg1        db 'rsm instruction at region: '
es_value dq 0, 0
es_msg2 db ' address: 0x', 0
smi_region: times 10 dd 0, 0                ; ���� 10 ���������� region �� address
do_enumerate_smi_region:
        push ebx
        push ecx
        push edx
        
;; �����
        mov edi, smi_region
        xor eax, eax
        mov ecx, 20
        rep stosd
                
        mov ebx, 0x30000                      ;; �� 300000H λ�ÿ�ʼ̽��
        xor ecx, ecx
        xor edx, edx
do_enumerate_smi_region_loop:
        mov ax, [ebx + ecx]
        cmp ax, 0xaa0f                        ; ���� rsm ָ��
        jne enumerate_smi_region_next
        ;; ���� region �� address
        mov [smi_region + edx * 4], ebx
        lea esi, [ebx + ecx]
        mov [smi_region + edx * 4 + 4], esi
        add edx, 2
        jmp enumerate_smi_region_next_region
enumerate_smi_region_next:
        inc ecx
        cmp ecx, 8000h + 7C00h
        jb do_enumerate_smi_region_loop
enumerate_smi_region_next_region:
        xor ecx, ecx
        add ebx, 0x10000
        cmp ebx, 0x10000000
        jb do_enumerate_smi_region_loop
        
;; ��ӡ̽����        
        SET_SMRAM_CLOSE                          ; �ر� SMRAM Ϊ�˴�ӡ̽����
        xor edx, edx        
enumerate_smi_region_result:        
        mov eax, [smi_region + edx * 4]
        mov ebx, [smi_region + edx * 4 + 4]
        test eax, eax
        jz enumerate_smi_region_done
        mov esi, eax
        mov edi, es_value
        call get_dword_hex_string
        mov esi, es_msg1
        call puts
        mov esi, es_msg2
        call puts
        mov esi, ebx
        call print_value
        add edx, 2
        jmp enumerate_smi_region_result
        
enumerate_smi_region_done:
        pop edx
        pop ecx
        pop ebx
        ret


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


;----------------------------------------
; DB_handler():  #DB handler
;----------------------------------------
DB_handler:
        jmp do_DB_handler
db_msg1           db '-----< Single-Debug information >-----', 10, 0        
db_msg2           db '>>>>> END <<<<<', 10, 0
eax_message        db 'eax: 0x          ', 0
ebx_message        db 'ebx: 0x          ', 0
ecx_message        db 'ecx: 0x          ', 0
edx_message        db 'edx: 0x          ', 0
esp_message        db 'esp: 0x          ', 0
ebp_message        db 'ebp: 0x          ', 0
esi_message        db 'esi: 0x          ', 0
edi_message        db 'edi: 0x          ', 0
eip_message db 'eip: 0x          ', 0
return_address dq 0, 0

register_message_table        dd eax_message, ebx_message, ecx_message, edx_message  
                              dd esp_message, ebp_message, esi_message, edi_message, 0

do_DB_handler:        
;; �õ��Ĵ���ֵ
        pushad
        
        mov esi, db_msg1
        call puts
        
        lea ebx, [esp + 4 * 7]
        xor ecx, ecx

;; ֹͣ����        
        mov esi, [esp + 4 * 8]
        cmp esi, [return_address]
        je clear_TF
        
do_DB_handler_loop:        
        lea eax, [ecx*4]
        neg eax
        mov esi, [ebx + eax]
        mov edx, [register_message_table + ecx *4]
        lea edi, [edx + 7]
        call get_dword_hex_string
        mov esi, edx
        call puts
        
        inc ecx        
        test ecx, 3
        jnz do_DB_handler_tab
        call println
        jmp do_DB_handler_next
do_DB_handler_tab:        
        mov esi, DWORD '  '
        call putc
do_DB_handler_next:        
        cmp ecx, 8
        jb do_DB_handler_loop
        
        mov esi, [esp + 4 * 8]
        mov edi, eip_message+7
        call get_dword_hex_string
        mov esi, eip_message
        call puts
        call println
        mov eax, [esp + 4 * 8]
        mov [return_address], eax
        jmp do_DB_handler_done
clear_TF:
        btr DWORD [esp + 4 * 8 + 8], 8             ; �� TF ��־
        mov esi, db_msg2
        call puts
do_DB_handler_done:        
        bts DWORD [esp + 4 * 8 + 8], 16            ; ���� eflags.RF Ϊ 1���Ա��жϷ���ʱ������ִ��
        popad
        iret

;-------------------------------------------
; GP_handler():  #GP handler
;-------------------------------------------
GP_handler:
        jmp do_GP_handler
gp_msg1                db '---> Now, enter the #GP handler. '
gp_msg2                db 'return address: 0x'
ret_address        dq 0, 0 
gp_msg3                db 'skip STI instruction', 10, 0
do_GP_handler:        
        add esp, 4                                                        ;  ���Դ�����
        mov esi, [esp]
        mov edi, ret_address
        call get_dword_hex_string
        mov esi, gp_msg1
        call puts
        call println
        mov eax, [esp]
        cmp BYTE [eax], 0xfb                        ; ����Ƿ���Ϊ sti ָ������� #GP �쳣
        jne fix
        inc eax                                      ; ����ǵĻ����������� #GP �쳣�� sti ָ�ִ����һ��ָ��
        mov [esp], eax
        mov esi, gp_msg3
        call puts
        jmp do_GP_handler_done
fix:
        mov eax, [esp+12]
        mov esi, [esp+4]                                ; �õ����жϴ���� cs
        test esi, 3
        jz fix_eip
        mov eax, [eax]
fix_eip:        
        mov [esp], eax                                  ; д�뷵�ص�ַ        
do_GP_handler_done:                
        iret

;----------------------------------------------
; UD_handler(): #UD handler
;----------------------------------------------
UD_handler:
        jmp do_UD_handler
ud_msg1                db '---> Now, enter the #UD handler', 10, 0        
do_UD_handler:
        mov esi, ud_msg1
        call puts
        mov eax, [esp+12]                        ; �õ� user esp
        mov eax, [eax]
        mov [esp], eax                           ; ��������#UD��ָ��
        add DWORD [esp+12], 4                   ; pop �û� stack
        iret
        
;----------------------------------------------
; NM_handler(): #NM handler
;----------------------------------------------
NM_handler:
        jmp do_NM_handler
nm_msg1                db '---> Now, enter the #NM handler', 10, 0        
do_NM_handler:        
        mov esi, nm_msg1
        call puts
        mov eax, [esp+12]                        ; �õ� user esp
        mov eax, [eax]
        mov [esp], eax                           ; ��������#NM��ָ��
        add DWORD [esp+12], 4                   ; pop �û� stack
        iret          

;-----------------------------------------------
; AC_handler(): #AC handler
;-----------------------------------------------
AC_handler:
        jmp do_AC_handler
ac_msg1  db '---> Now, enter the #AC exception handler <---', 10
ac_msg2  db 'exception location at 0x'
ac_location   dq 0, 0
do_AC_handler:        
        pusha
        mov esi, [esp+4+4*8]                        
        mov edi, ac_location
        call get_dword_hex_string
        mov esi, ac_msg1
        call puts
        call println
;; ���� disable        AC ����
        btr DWORD [esp+12+4*8], 18                ; ��elfags image�е�AC��־        
        popa
        add esp, 4                                 ; ���� error code        
        iret


;********* include ģ�� ********************
%include "..\lib\creg.asm"
%include "..\lib\cpuid.asm"
%include "..\lib\msr.asm"
%include "..\lib\pci.asm"
%include "..\lib\pic8259A.asm"

;; ���������
%include "..\common\lib32_import_table.imt"

PROTECTED_END: