; setup.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\support.inc"
%include "..\inc\protected.inc"

; ���� protected ģ��

        bits 32
        
        org PROTECTED_SEG - 2

PROTECTED_BEGIN:
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN              ; protected ģ�鳤��

entry:
        
;; ���� #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler        

;; ���� #DB handler
        mov esi, DB_HANDLER_VECTOR
        mov edi, DB_handler
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


;; ͨ��stack��#GP handler���ݲ���
        push DWORD .L1
        
;; ���� CR0.TS λ
        mov eax, cr0
        btr eax, 30                                                ; CR0.CD = 0
        bts eax, 29                                                ; CR0.NW = 1
        mov cr0, eax
                
.L1:
        add esp, 4
                
; ���� ring 3 ����
        push DWORD user_data32_sel | 0x3
        push esp
        push DWORD user_code32_sel | 0x3        
        push DWORD user_entry
        retf
        
        
        jmp $


user_entry:
        mov ax, user_data32_sel | 0x3
        mov ds, ax
        mov es, ax

        mov esi, msg
        call puts                                ;��ӡ�ɹ���Ϣ
        call println
        
        jmp $



msg             db 'success!', 10, 0




        
;----------------------------------------------
; UD_handler(): #UD handler
;----------------------------------------------
UD_handler:
        jmp do_UD_handler
ud_msg1  db '---> Now, enter the #UD handler', 10, 0        
do_UD_handler:
        mov esi, ud_msg1
        call puts
        mov eax, [esp+12]                        ; �õ� user esp
        mov eax, [eax]
        mov [esp], eax                           ; ��������#UD��ָ��
        add DWORD [esp+12], 4                    ; pop �û� stack
        iret
        
;----------------------------------------------
; NM_handler(): #NM handler
;----------------------------------------------
NM_handler:
        jmp do_NM_handler
nm_msg1 db '---> Now, enter the #NM handler', 10, 0        
do_NM_handler:        
        mov esi, nm_msg1
        call puts
        mov eax, [esp+12]                    ; �õ� user esp
        mov eax, [eax]
        mov [esp], eax                       ; ��������#NM��ָ��
        add DWORD [esp+12], 4                ; pop �û� stack
        iret        


;-------------------------------------------
; GP_handler():  #GP handler
;-------------------------------------------
GP_handler:
        jmp do_GP_handler
gp_msg1         db '---> Now, enter the #GP handler, '
gp_msg2         db 'return address: 0x', 0
do_GP_handler:        
        pop eax                                       ;  ���Դ�����
        mov esi, gp_msg1
        call puts
        mov esi, [esp]
        call print_dword_value        
        call println
        mov eax, [esp + 12]                       ; 
        mov [esp], eax
do_GP_handler_done:        
        iret
        
        
;----------------------------------------
; DB_handler():  #DB handler
;----------------------------------------
DB_handler:
        jmp do_DB_handler
db_msg1            db '-----< Single-Debug information >-----', 10, 0        
db_msg2            db '>>>>> END <<<<<', 10, 0
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
        btr DWORD [esp + 4 * 8 + 8], 8                                        ; �� TF ��־
        mov esi, db_msg2
        call puts
do_DB_handler_done:        
        bts DWORD [esp + 4 * 8 + 8], 16                                        ; ���� eflags.RF Ϊ 1���Ա��жϷ���ʱ������ִ��
        popad
        iret


%include "..\lib\pic8259A.asm"

;; ���������
%include "..\common\lib32_import_table.imt"


PROTECTED_END: