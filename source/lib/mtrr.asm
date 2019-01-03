; mtrr.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.



%ifndef MTRR_INC
%define MTRR_INC

;; ���ģ���� mtrr �Ĵ���������

        bits 32
        
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
        
;; ��ӡ        base ��ַ
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



;-------------------------------------------------------
; dump_smrr_region()
;-------------------------------------------------------
dump_smrr_region:
        jmp do_dump_smrr_region
dsr_msg1        db 'SMRR region: 0x'
smrr_value      dq 0, 0, 0
dsr_msg2        db ' - 0x'
smrrlimit_value dq 0, 0, 0
dsr_msg3        db ' <invalid>', 0
dsr_msg4        db 'not support SMRR feature', 10, 0        
do_dump_smrr_region:        
        mov ecx, IA32_MTRRCAP
        rdmsr
        bt eax, 11                                      ; SMRR support ?
        jnc smrr_not_support

;; �õ� MAXPHYADDR ֵ
        call get_MAXPHYADDR
        mov [maxphyaddr], eax
        cmp eax, 40                                     ; MAXPHYADDR = 40 ?
        je dump_smrr_region_next
        cmp eax, 52                                     ; MAXPHYADDR = 52 ?
        je set_smrr_maxphyaddr_52
        mov DWORD [maxphyaddr_value + 4], 0x0F          ; ���� 36 λ��ַ�����4λֵ
        jmp dump_smrr_region_next
set_smrr_maxphyaddr_52:
        mov DWORD [maxphyaddr_value + 4], 0xFFFF        ; ���� 52 λ��ַ�����16λֵ
        
        
dump_smrr_region_next:
        
        mov ecx, IA32_SMRR_PHYSBASE                                                
        rdmsr                                           ; �� IA32_SMRR_PHYSBASE
        
;;; ʹ���� enumerate_variable_rang() �ı���
        mov [physbase], eax                                
        mov [physbase + 4], edx                         ; ���� SMRR region
        and DWORD [physbase], 0xFFFFFFF0                ; ȥ�� type ֵ
        and eax, 0xff                                    ; �õ� type ֵ
        mov [type], eax
        mov ecx, IA32_SMRR_PHYSMASK                                
        rdmsr                                           ; �� IA32_SMRR_PHYSMASK
        btr eax, 11                                     ; �õ� valid ֵ
        mov [physmask], eax
        mov [physmask + 4], edx
        setc al
        movzx eax, al
        mov [valid], eax                                ; ���� valid ֵ
        
;; ��ӡ��ַ
        mov esi, physbase
        mov edi, smrr_value
        call get_qword_hex_string
        mov esi, dsr_msg1
        call puts
        mov esi, dsr_msg2
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
        mov edi, smrrlimit_value
        call get_qword_hex_string
        add esp, 16
        mov esi, smrrlimit_value
        call puts

;; �Ƿ� valid
        cmp DWORD [valid], 0
        jne print_smrr_type
        mov esi, dsr_msg3
        call puts
        jmp do_dump_smrr_region_done
        
print_smrr_type:
        mov esi, ' '
        call putc
        mov eax, [type]        
        mov esi, [memory_type_table + eax * 4]
        call puts
        jmp do_dump_smrr_region_done

smrr_not_support:
        mov esi, dsr_msg4
        call puts
                        
do_dump_smrr_region_done:        
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


;; **** �����Ǹ�ģ���һЩ���õı��� ****

;; IA32_MTRR_PHYSBASE ��ַ��
mtrr_physbase_table        dd IA32_MTRR_PHYSBASE0, IA32_MTRR_PHYSBASE1, IA32_MTRR_PHYSBASE2, IA32_MTRR_PHYSBASE3, IA32_MTRR_PHYSBASE4
                           dd IA32_MTRR_PHYSBASE5, IA32_MTRR_PHYSBASE6, IA32_MTRR_PHYSBASE7, IA32_MTRR_PHYSBASE8, IA32_MTRR_PHYSBASE9

;; IA32_MTRR_PHYSMASK ��ַ��                                
mtrr_physmask_table        dd IA32_MTRR_PHYSMASK0, IA32_MTRR_PHYSMASK1, IA32_MTRR_PHYSMASK2, IA32_MTRR_PHYSMASK3, IA32_MTRR_PHYSMASK4
                           dd IA32_MTRR_PHYSMASK5, IA32_MTRR_PHYSMASK6, IA32_MTRR_PHYSMASK7, IA32_MTRR_PHYSMASK8, IA32_MTRR_PHYSMASK9


%endif