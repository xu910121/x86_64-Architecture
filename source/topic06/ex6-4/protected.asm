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


        mov esi, cr0
        call dump_CR0                        ; ��ӡ CR0 �Ĵ���
        mov esi, cr4
        call dump_CR4                        ; ��ӡ CR4 �Ĵ���
        call println
        call println
        
        mov eax, 01H
        cpuid
        call dump_CPUID_leaf_01_ecx                ; ��ӡ CPUID.EAX=01H.ECX ��֧��λ
        call println
        call dump_CPUID_leaf_01_edx                ; ��ӡ CPUID.EAX=01H.EDX ��֧��λ
        

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




msg8                db 'no support: CR4.TSD or RDTSCP', 10, 0

        


;------------------------------------------------------------
; dump_CPUID_leaf_01_edx(): ��ӡ CPUID.EAX=01H ���ص� EDXֵ
;------------------------------------------------------------
dump_CPUID_leaf_01_edx:
        jmp do_dump_CPUID_leaf_01_edx        
fpu0        db 'fpu', 0
vme0        db 'vme', 0
de0         db 'de',  0
pse0        db 'pse', 0
tsc0        db 'tsc', 0
msr0        db 'msr', 0
pae0        db 'pae', 0
mce0        db 'mce', 0
cx80        db 'cx8', 0
apic0       db 'apic', 0
sep0        db 'sep', 0
mtrr0       db 'mtrr', 0
pge0        db 'pge', 0
mca0        db 'mca', 0
cmov0       db 'cmov', 0
pat0        db 'pat', 0
pse360      db 'pse-36', 0
psn0        db 'psn', 0
clfsh0      db 'clfsh', 0
ds0         db 'ds', 0
acpi0       db 'acpi', 0
mmx0        db 'mmx', 0
fxsr0       db 'fxsr', 0
sse0        db 'sse', 0
sse20       db 'sse2', 0
ss0         db 'ss', 0
htt0        db 'htt', 0
tm0         db 'tm', 0
pbe0        db 'pbe', 0

edx_flags   dd fpu0, vme0, de0, pse0, tsc0, msr0, pae0, mce0
            dd cx80, apic0, 0, sep0, mtrr0, pge0, mca0, cmov0
            dd pat0, pse360, psn0, clfsh0, 0, ds0, acpi0, mmx0
            dd fxsr0, sse0, sse20, ss0, htt0, tm0, 0, pbe0, -1

dump_edx_msg        db '<CPUID.EAX=01H.EDX:>', 10, 0

do_dump_CPUID_leaf_01_edx:
        mov esi, dump_edx_msg
        call puts
        mov esi, edx
        mov edi, edx_flags
        call dump_flags
        call println
        ret
        
;------------------------------------------
; dump_CPUID_leaf_01_ecx():
;------------------------------------------
dump_CPUID_leaf_01_ecx:
        jmp do_dump_CPUID_leaf_01_ecx
sse30           db 'sse3', 0
pclmuldq0       db 'pclmuldq', 0
dtes640         db 'dtes64', 0
monitor0        db 'monitor', 0
ds_cpl0         db 'ds-cpl', 0
vmx0            db 'vmx', 0
smx0            db 'smx', 0
eist0           db 'eist', 0
tm20            db 'tm2', 0
ssse30          db 'ssse3', 0
cnxt_id0        db 'cnxt-id', 0
fma0            db 'fma', 0
cx160           db 'cx16', 0
xptr0           db 'xptr', 0
pdcm0           db 'pdcm', 0
pcid0           db 'pcid', 0
dca0            db 'dca', 0
sse4_10         db 'sse4.1', 0
sse4_20         db 'sse4.2', 0
x2apic0         db 'x2apic', 0
movbe0          db 'movbe', 0
popcnt0         db 'popcnt', 0
tsc_deadline0   db 'tsc-deadline', 0
aes0            db 'aes', 0
xsave0          db 'xsave', 0
osxsave0        db 'osxsave', 0
avx0            db 'avx', 0

leaf_01_ecx_flags        dd sse30, pclmuldq0, dtes640, monitor0, ds_cpl0
                         dd vmx0, smx0, eist0, tm20, ssse30, cnxt_id0, 0
                         dd fma0, cx160, xptr0, pdcm0, 0, pcid0, dca0
                         dd sse4_10, sse4_20, x2apic0, movbe0, popcnt0
                         dd tsc_deadline0, aes0, xsave0, osxsave0, avx0
                         dd -1
                                        
dump_CPUID_leaf_01_msg        db '<CPUID.EAX=01H.ECX:>', 10, 0

do_dump_CPUID_leaf_01_ecx:        
        mov esi, dump_CPUID_leaf_01_msg
        call puts
        mov esi, ecx
        mov edi, leaf_01_ecx_flags
        call dump_flags
        call println
        ret


;-------------------------------------
; dump_CR0()
; input:
;                esi: CR0
;-------------------------------------        
dump_CR0:
        jmp do_dump_CR0
pe        db 'pe', 0
mp        db 'mp', 0
em         db 'em', 0
ts        db 'ts', 0
et        db 'et', 0
ne        db 'ne', 0
wp        db 'wp', 0
am        db 'am', 0
nw        db 'nw', 0
cd        db 'cd', 0
pg        db 'pg', 0

cr0_flags        dd pg, cd, nw, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                 dd am, 0, wp, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                 dd ne, et, ts, em, mp, pe, -1

dump_cr0_msg     db '<CR0>: ', 0                        
do_dump_CR0:
        push ecx
        mov ecx, esi
        mov esi, dump_cr0_msg
        call puts
        mov esi, ecx
        call reverse        
        mov esi, eax
        mov edi, cr0_flags
        call dump_flags
        call println
        pop ecx
        ret

;-------------------------------------
; dump_CR4()
; input:
;                esi: CR4
;-------------------------------------        
dump_CR4:
        jmp do_dump_CR4
vme             db 'vme', 0
pvi             db 'pvi', 0
tsd             db 'tsd', 0
de              db 'de', 0
pse             db 'pse', 0
pae             db 'pae', 0
mce             db 'mce', 0
pge             db 'pge', 0
pce             db 'pce', 0
osfxsr          db 'osfxsr', 0
osxmmexcpt      db 'osxmmexcpt', 0
vmxe            db 'vmxe', 0
smxe            db 'smxe', 0
pcide           db 'pcide', 0
osxsave         db 'osxsave', 0
smep            db 'smep', 0        
                
cr4_flags       dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                dd smep, 0, osxsave, pcide, 0, 0, smxe, vmxe
                dd 0, 0, osxmmexcpt, osfxsr, pce, pge, mce, pae, pse, de, tsd, pvi,vme, -1
                        
dump_cr4_msg    db '<CR4>: ', 0                        
do_dump_CR4:
        push ecx
        mov ecx, esi
        mov esi, dump_cr4_msg
        call puts
        mov esi, ecx
        call reverse
        mov esi, eax
        mov edi, cr4_flags
        call dump_flags
        call println
        pop ecx
        ret        
        
;----------------------------------------
; DB_handler():  #DB handler
;----------------------------------------
DB_handler:
        jmp do_DB_handler
db_msg1                db '-----< Single-Debug information >-----', 10, 0        
db_msg2                db '>>>>> END <<<<<', 10, 0
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
        inc eax                                                        ; ����ǵĻ����������� #GP �쳣�� sti ָ�ִ����һ��ָ��
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
        mov [esp], eax                                        ; д�뷵�ص�ַ        
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
        mov [esp], eax                                ; ��������#UD��ָ��
        add DWORD [esp+12], 4                ; pop �û� stack
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
        mov [esp], eax                                ; ��������#NM��ָ��
        add DWORD [esp+12], 4                ; pop �û� stack
        iret        

;-----------------------------------------------
; AC_handler(): #AC handler
;-----------------------------------------------
AC_handler:
        jmp do_AC_handler
ac_msg1                db '---> Now, enter the #AC exception handler <---', 10
ac_msg2                db 'exception location at 0x'
ac_location        dq 0, 0
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
        add esp, 4                                                ; ���� error code        
        iret





%include "..\lib\pic8259A.asm"

;; ���������
%include "..\common\lib32_import_table.imt"


PROTECTED_END: