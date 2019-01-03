; protected.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\support.inc"
%include "..\inc\protected.inc"

; ���� protected ģ��

        bits 32
        
        org PROTECTED_SEG - 2

PROTECTED_BEGIN:
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN                                ; protected ģ�鳤��

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


;==========================================================        

;; ��ӡ variable-rang ��Ϣ
        call enumerate_variable_rang

        mov esi, msg9
        call puts
        
;; ���� variable-rang 
        mov esi, 0
        mov edi, 0
        mov eax, 1FFFFFFH
        mov edx, 0
        push DWORD 0
        push DWORD 0
        call set_variable_rang
        add esp, 8
        
        mov esi, 2000000H
        mov edi, 0
        mov eax, 2FFFFFFH
        mov edx, 0
        push DWORD 1
        push DWORD 0
        call set_variable_rang        
        add esp, 8
        
        mov esi, 3000000H
        mov edi, 0
        mov eax, 3FFFFFFH
        mov edx, 0
        push DWORD 2
        push DWORD 0
        call set_variable_rang        
        add esp, 8
        
;; ��ӡ variable-rang ��Ϣ
        call enumerate_variable_rang
        
                                        
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



msg8                db 'no support!', 10, 0
msg9                db 10, 'Now: set variable-rang', 10, 0



;-------------------------------------------------------------------------
; set_variable_rang(): ���� variable_rang ����
; input:
;                 esi��edi-�������ַ�� edx:eax ������ַ�� [esp+4]: variable_rang���, [esp+8]: memory type
; ������
;                �������ʹ����4����������3��4������ͨ��stack����
;                esi:edi ��ԼĴ����ṩ����ַ��64λֵ������edx:eax ��ԼĴ����ṩ������ַ��64λֵ)
; ���ӣ�
;                mov esi, 1000000H
;                mov edi, 0H
;                mov edx, 0
;                mov eax, 1FFFFFFH
;                push 0
;                push 06H
;                cal set_variable_rang
; ע�⣺
;                �������ʹ���˲��� enumerate_variable_rang() �ı���!!
;-------------------------------------------------------------------
set_variable_rang:
        jmp do_set_variable_rang
set_physbase    dq 0                        ; ��Ҫ���õ� baseֵ(64λ)
set_physlimit   dq 0                        ; ��Ҫ���õ� limitֵ(64λ)
set_number      dd 0
set_type        dd 0
do_set_variable_rang:        
        push ecx
        push ebx
        push edx
        
;; �������        
        mov [set_physbase], esi
        mov [set_physbase + 4], edi
        mov [set_physlimit], eax
        mov [set_physlimit + 4], edx
        mov eax, [esp + 20]
        mov [set_number], eax
        mov eax, [esp + 16]
        mov [set_type], eax
        
;; ������������Ƿ���
        mov ecx, IA32_MTRRCAP
        rdmsr
        and eax, 0x0f
        mov [number], eax                       ; ��� number
        cmp eax, [set_number]
        jb set_variable_rang_done               ; ������ޣ�ʲô������

;; ����д��ֵ
        mov edx, [set_physbase + 4]             ; ��λ
        mov eax, [set_physbase]                 ; ��λ
        and eax, 0FFFFF000H                     ; ��� 12λ
        mov ebx, [set_type]
        and ebx, 0x0f
        or eax, ebx                             ; �� memory type��ע�⣬û�м��Ϸ��ԣ�
        mov ebx, [set_number]
        mov ecx, [mtrr_physbase_table + ebx * 4]                
        wrmsr                                   ; д IA32_MTRR_PHYSBASE �Ĵ���

;;;;; ������� PhysMask ֵ��;;;;;;
        mov esi, set_physlimit
        mov edi, set_physbase
        call subtract64                         ; ʹ��64λ�ļ�����limit - base
        push edx
        push eax
        
;; �õ� MAXPHYADDR ֵ
        call get_MAXPHYADDR
        mov [maxphyaddr], eax
        cmp eax, 40                             ; MAXPHYADDR = 40 ?
        je do_set_physmask
        cmp eax, 52                             ; MAXPHYADDR = 52 ?
        je maxphyaddr_52
        mov DWORD [maxphyaddr_value + 4], 0x0F          ; ���� 36 λ��ַ�����4λֵ
        jmp do_set_physmask
maxphyaddr_52:
        mov DWORD [maxphyaddr_value + 4], 0xFFFF        ; ���� 52 λ��ַ�����16λֵ

do_set_physmask:        
        mov esi, maxphyaddr_value                       ; ���ֵ
        mov edi, esp                                    ; ����
        call subtract64
        and eax, 0FFFFF000H
        bts eax, 11                                      ; �� valid = 1
        mov ebx, [set_number]        
        mov ecx, [mtrr_physmask_table + ebx * 4]
        wrmsr                                            ; д IA32_MTRR_PHYSMASK �Ĵ���
        
        add esp, 8                
set_variable_rang_done:
        pop edx 
        pop ebx
        pop ecx
        ret
        
        
        
;--------------------------------------------------------
; enumerate_variable_rang(): ö�ٳ���ǰ���е�variable����
;--------------------------------------------------------
enumerate_variable_rang:
        jmp do_enumerate_variable_rang
emsg1           db 'number of variable rang: 0x'
number          dd 0
nn              db '#', 0, 0, 0
physbase_msg    db 'rang: 0x', 0
physbase_value  dq 0, 0, 0
physlimit_msg   db ' - 0x', 0
physlimit_value dq 0, 0, 0
type_msg        db 'type: ', 0

mtrr_physbase_table        dd IA32_MTRR_PHYSBASE0, IA32_MTRR_PHYSBASE1, IA32_MTRR_PHYSBASE2, IA32_MTRR_PHYSBASE3, IA32_MTRR_PHYSBASE4
                           dd IA32_MTRR_PHYSBASE5, IA32_MTRR_PHYSBASE6, IA32_MTRR_PHYSBASE7, IA32_MTRR_PHYSBASE8, IA32_MTRR_PHYSBASE9
mtrr_physmask_table        dd IA32_MTRR_PHYSMASK0, IA32_MTRR_PHYSMASK1, IA32_MTRR_PHYSMASK2, IA32_MTRR_PHYSMASK3, IA32_MTRR_PHYSMASK4
                           dd IA32_MTRR_PHYSMASK5, IA32_MTRR_PHYSMASK6, IA32_MTRR_PHYSMASK7, IA32_MTRR_PHYSMASK8, IA32_MTRR_PHYSMASK9

emsg2           db 'MTRR disable', 10, 0
emsg3           db ' ---> ', 0
emsg4           db ' <invalid>', 0
;; ȱʡΪ 40 λ����ߵ�ֵַ: 0xFF_FFFFFFFF
maxphyaddr_value        dd 0xFFFFFFFF, 0xFF
maxphyaddr              dd 0                
vcnt                    dd 0                        ; ��������ֵ
physbase                dq 0                        ; ���� PhysBase ֵ
type                    dd 0                        ; ���� memory ����
physmask                dq 0                        ; ���� PhysMask ֵ
valid                   dd 0                        ; ���� valid λ

do_enumerate_variable_rang:        
        push ecx
        push edx
        push ebp

;; �����Ƿ��� MTRR ����        
        mov ecx, IA32_MTRR_DEF_TYPE
        rdmsr                        
        bt eax, 11                                   ; MTRR enable ?
        jc do_enumerate_variable_rang_enable
        mov esi, emsg2
        call puts
        jmp do_enumerate_variable_rang_done
        
do_enumerate_variable_rang_enable:        
        xor ebp, ebp
        mov ecx, IA32_MTRRCAP
        rdmsr                                        ; �� IA32_MTRRCAP �Ĵ���
        mov esi, eax                                
        and esi, 0x0f                                ; �õ� IA32_MTRRCAP.VCNT ֵ
        mov [vcnt], esi                              ; ���� variable-rang ����
        mov edi, number
        call get_byte_hex_string                     ; д�� buffer ��
        mov esi, emsg1
        call puts
        call println
        cmp DWORD [vcnt], 0                           ; ��� VCNT = 0
        je do_enumerate_variable_rang_done
        
;; �õ� MAXPHYADDR ֵ
        call get_MAXPHYADDR
        mov [maxphyaddr], eax
        cmp eax, 40                                    ; MAXPHYADDR = 40 ?
        je do_enumerate_variable_rang_loop
        cmp eax, 52                                    ; MAXPHYADDR = 52 ?
        je set_maxphyaddr_52
        mov DWORD [maxphyaddr_value + 4], 0x0F         ; ���� 36 λ��ַ�����4λֵ
        jmp do_enumerate_variable_rang_loop
set_maxphyaddr_52:
        mov DWORD [maxphyaddr_value + 4], 0xFFFF       ; ���� 52 λ��ַ�����16λֵ
        
do_enumerate_variable_rang_loop:
;; ��ӡ���        
        mov esi, ebp
        mov edi, nn + 1
        call get_byte_hex_string
        mov esi, nn
        call puts        
        mov esi, emsg3
        call puts
        
;; ��ӡ  base ��ַ
        mov esi, physbase_msg
        call puts
        mov ecx, [mtrr_physbase_table + ebp * 4]       ; �õ� MTRR_PHYSBASE �Ĵ�����ַ
        rdmsr
        
        mov [physbase], eax
        mov [physbase + 4], edx
        and DWORD [physbase], 0xFFFFFFF0               ; ȥ�� type ֵ
        and eax, 0xf0                                  ; �õ� type ֵ
        mov [type], eax
        mov ecx, [mtrr_physmask_table + ebp * 4]        ; �õ� MTRR_PHYSMASK �Ĵ�����ַ
        rdmsr
        btr eax, 11                                     ; �õ� valid ֵ
        mov [physmask], eax
        mov [physmask + 4], edx
        setc al
        movzx eax, al
        mov [valid], eax                                ; ���� valid ֵ
;; ��ӡ��ַ
        mov esi, physbase
        mov edi, physbase_value
        call get_qword_hex_string
        mov esi, physbase_value
        call puts
        mov esi, physlimit_msg
        call puts
;; ���㷶Χֵ
        mov esi, maxphyaddr_value
        mov edi, physmask
        call subtract64
        push edx
        push eax
        mov esi, esp
        mov edi, physbase
        call addition64
        push edx
        push eax
        mov esi, esp
        mov edi, physlimit_value
        call get_qword_hex_string
        add esp, 16
        mov esi, physlimit_value
        call puts

;; �Ƿ� valid
        cmp DWORD [valid], 0
        jne print_memory_type
        mov esi, emsg4
        call puts
        jmp do_enumerate_variable_rang_next
        
print_memory_type:
        mov esi, ' '
        call putc
        mov eax, [type]        
        mov esi, [memory_type_table + eax * 4]
        call puts
        
do_enumerate_variable_rang_next:        
        call println        
        inc ebp
        cmp ebp, [vcnt]                                     ; ���� VCNT ����
        jb do_enumerate_variable_rang_loop
        
do_enumerate_variable_rang_done:        
        pop ebp
        pop edx
        pop ecx
        ret




;------------------------------------------
; dump_fixed64K_rang(): ��ӡ fixed-rang ������
; input:
;                esi: low32, edi: hi32
;------------------------------------------
dump_fixed64K_rang:
        jmp do_dump_fixed64K_rang
byte0        db '00000-0FFFF: ', 0
byte1        db '10000-1FFFF: ', 0
byte2        db '20000-2FFFF: ', 0
byte3        db '30000-3FFFF: ', 0
byte4        db '40000-4FFFF: ', 0
byte5        db '50000-5FFFF: ', 0
byte6        db '60000-6FFFF: ', 0
byte7        db '70000-7FFFF: ', 0
t0           db 'Uncacheable', 0
t1           db 'WriteCombining', 0
t2           db 'WriteThrough', 0
t3           db 'WriteProtected', 0
t4           db 'WriteBack', 0
mtrr_table          dd byte0,byte1,byte2,byte3,byte4,byte5,byte6,byte7, -1
memory_type_table   dd t0, t1, 0, 0, t2, t3, t4
mtrr_value          dq 0        
do_dump_fixed64K_rang:        
        push ecx
        push ebx
        mov [mtrr_value], esi
        mov [mtrr_value+4], edi
        mov ebx, mtrr_table
        xor ecx, ecx
        
do_dump_fixed64K_rang_loop:        
        mov esi, [ebx + ecx * 4]
        cmp esi, -1
        jz do_dump_fixed64K_rang_done
        call puts                                                ; ��ӡ��Ϣ
        movzx eax, BYTE [mtrr_value + ecx]
        mov esi, [memory_type_table + eax * 4]
        call puts
        call println
        inc ecx
        jmp do_dump_fixed64K_rang_loop
        
do_dump_fixed64K_rang_done:        
        pop ebx
        pop ecx
        ret


        

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
eip_message        db 'eip: 0x          ', 0
return_address     dq 0, 0

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
        btr DWORD [esp + 4 * 8 + 8], 8                  ; �� TF ��־
        mov esi, db_msg2
        call puts
do_DB_handler_done:        
        bts DWORD [esp + 4 * 8 + 8], 16                 ; ���� eflags.RF Ϊ 1���Ա��жϷ���ʱ������ִ��
        popad
        iret

;-------------------------------------------
; GP_handler():  #GP handler
;-------------------------------------------
GP_handler:
        jmp do_GP_handler
gp_msg1         db '---> Now, enter the #GP handler. '
gp_msg2         db 'return address: 0x'
ret_address     dq 0, 0 
gp_msg3         db 'skip STI instruction', 10, 0
do_GP_handler:        
        add esp, 4                                    ;  ���Դ�����
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
        mov esi, [esp+4]                            ; �õ����жϴ���� cs
        test esi, 3
        jz fix_eip
        mov eax, [eax]
fix_eip:        
        mov [esp], eax                                ; д�뷵�ص�ַ        
do_GP_handler_done:                
        iret

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
        mov [esp], eax                          ; ��������#UD��ָ��
        add DWORD [esp+12], 4                  ; pop �û� stack
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
;; ���� disable AC ����
        btr DWORD [esp+12+4*8], 18                ; ��elfags image�е�AC��־        
        popa
        add esp, 4                                 ; ���� error code        
        iret






%include "..\lib\pic8259A.asm"

;; ���������
%include "..\common\lib32_import_table.imt"

PROTECTED_END: