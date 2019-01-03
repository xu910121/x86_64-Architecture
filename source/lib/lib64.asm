; lib64.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.

;; long mode �µĿ�

%include "..\inc\long.inc"


        bits 64
        
set_system_descriptor:                  jmp DWORD __set_system_descriptor
set_segment_descriptor:                 jmp DWORD __set_segment_descriptor
set_call_gate:                          jmp DWORD __set_call_gate
set_interrupt_handler:
set_interrupt_descriptor:               jmp DWORD __set_interrupt_handler
read_segment_descriptor:                jmp DWORD __read_segment_descriptor
write_segment_descriptor:               jmp DWORD __write_segment_descriptor
read_idt_descriptor:                    jmp DWORD __read_idt_descriptor
write_idt_descriptor:                   jmp DWORD __write_idt_descriptor
set_user_interrupt_handler:             jmp DWORD __set_user_interrupt_handler
get_tss_base:                           jmp DWORD __get_tss_base
get_tr_base:                            jmp DWORD __get_tr_base
set_sysenter:                           jmp DWORD __set_sysenter
sys_service_enter:                      jmp DWORD __sys_service_enter
compatibility_sys_service_enter:        jmp DWORD __compatibility_sys_service_enter
set_syscall:                            jmp DWORD __set_syscall
sys_service_call:                       jmp DWORD __sys_service_call
set_user_system_service:                jmp DWORD __set_user_system_service
user_system_service_call:               jmp DWORD __user_system_service_call

;-----------------------------------------------------
; strlen(): ��ȡ�ַ�������
; input:
;                rsi: string
; output:
;                rax: length of string
;
; ������
;                ������������� conforming ����������Ȩ��ִ��(ʹ�� far pointerָ����ʽ����
;-----------------------------------------------------
__strlen:
        mov rax, -1
        test rsi, rsi
        jz strlen_done
strlen_loop:
        inc rax
        cmp BYTE [rsi + rax], 0
        jnz strlen_loop
strlen_done:        
        db 0x48
        retf


;-------------------------------------------------------
; lib32_service(): ����ӿ�
; input:
;                rax: �⺯�����
; ������
;                ͨ�� call-gate ���е���ʵ�ʹ����� lib32_service()
;-------------------------------------------------------
lib32_service:
        jmp lib32_service_next
CALL_GATE_POINTER:      dq 0
                        dw call_gate_sel
lib32_service_next:                                        
        call QWORD far [CALL_GATE_POINTER]      ;; �� 64 λģʽ����� call gate                                        
        ret



;; **** ʹ�� 32 λ���� ****
        bits 32
;---------------------------------------------------------------------------
; compatibility_lib32_service(): ����ӿڣ����� 32-bit compatibilityģʽ��
; input:
;                eax: �⺯�����
; ������
;; �����Ǽ���ģʽ�µĵ��� lib32_service() stub ����
;---------------------------------------------------------------------------
compatibility_lib32_service:
        jmp compatibility_lib32_service_next
CALL_GATE_POINTER32:    dd 0
                        dw call_gate_sel
compatibility_lib32_service_next:                                        
        call DWORD far [CALL_GATE_POINTER32]    ;; �� compatibility ģʽ����� call gate                                        
        ret
                



;; **** ת�� 64 λ���� *****                
        bits 64



;****************************************************************************************
;* Bug�����ȱ��˵����                                                                  *
;*      lib32_service() ����ϵ��С��������롱��ȱ�ݣ�                                    *
;*      ����64-bitģʽͨ�� lib32_service()����lib32�⺯��ʱ,                            *
;*      lib32_service()ת��compatibilityģʽǰ����stackָ��espΪLIB32_ESPֵ             *
;*      ���ִ��lib32�⺯���ڼ䷢�����쳣�������ж���ռʱ���������쳣���ж�           *
;*      �ٴε���lib32_service()��ִ��lib32�⺯��ʱ���������غ����                      *
;*      ����ǣ�stackָ���ֱ�����ΪLIB32_ESPֵ������stack��������!                      *
;*                                                                                      *
;* ����취��                                                                           *
;*      1)���޷�Ԥ֪�����lib32�⺯��ִ���ڼ�����ж�����£�����ʹ���жϵ��÷�ʽ       *
;*        ����ʹ�� call-gate ��ʽ����lib32_service()��ת��compatibilityģʽ��           *
;*        ���������Ա��ⱻ�жϴ���ʱ��ռ����Ĳ����������ܱ��ⱻ�쳣��ռ��              *
;*                                                                                      *
;*      2)�����64-bit�����µ�stack������compatibilityģʽ��stack�����غϣ�             *
;*        ��ת��compaibilityģʽ���32λESPֵ����RSP�ĸ�32λ��0�󣬻��ܱ�����Ч�ԡ�     *
;*        �����ַ����£��ڽ���lib32_service()�������ESP�������裡                      *
;*        ������ȷ��RSP�ĵ�32λֵ���������޸ĵ�����±�����ȷ�ԣ�RSP��ESPֵ���Ӧ��     *
;*                                                                                      *
;*      3)���±�дlib32���Ӧ��64λ�汾�ĺ����⣬������64-bit������ʹ��lib32��!      �� *
;*      ����Ȼ�����������������ȷ�Ľ������������lib32�⺯�����ñ����á�               *
;****************************************************************************************


;-------------------------------------------------------
; lib32_service(): ��64λ�Ĵ�����ʹ��32λ�Ŀ⺯��
; input:
;                rax: �⺯����ţ�rsi...��Ӧ�ĺ�������
; ����:
;                (1) rax ��32λ�⺯���ţ�������ϵͳ�������̵Ĺ��ܺ�
;                (2) ��������л��� compaitibility ģʽ���� 32 λģʽ�ĺ���
;                (3) 32 λ����ִ����ϣ��л��� 64 λģʽ
;                (4) �� 64 λģʽ�з��ص�����
;                (5) lib32_service() ����ʹ�� call-gate ���е���
;-------------------------------------------------------
__lib32_service:
;*
;* changlog: ʹ�� r15 ���� rbp ���� rsp ָ��
;*           Ŀ�ģ�ʹ�� lib32 �������ʹ�� ebp ָ�룡   
;*                 ���ʹ�� rbp ���� rsp ָ�룬��ô��lib32 �⺯��ʹ�� ebp ʱ��ˢ�� rbp �Ĵ���ֵ
;*
        push r15
        mov r15, rsp
        push rbp
        push rbx  
        push rcx
        push rdx

        ; �������
        mov rcx, rsi
        mov rdx, rdi
        mov rbx, rax                            ; ���ܺ�

        mov rsi, [r15 + 16]                     ; �� CS selector
        call read_segment_descriptor
        shr rax, 32

        ; �ָ�����
        mov rsi, rcx
        mov rdi, rdx

        jmp QWORD far [lib32_service_compatiblity_pointer]      ; �� 64 λ�л��� compatibilityģʽ
;; ���� far pointer        
lib32_service_compatiblity_pointer:     dq        lib32_service_compatibility
                                        dw        code32_sel
lib32_service_64_pointer:               dd        lib32_service_done
                                        dw        KERNEL_CS

        bits 32                                                                        
lib32_service_compatibility:
        bt eax, 21                              ; ���� CS.L
        jc reload_sreg                          ; �������� 64 λ����
        shr eax, 13
        and eax, 0x03                           ; ȡ RPL
        cmp eax, 0
        je call_lib32                           ; Ȩ�޲���
reload_sreg:
;; �������� 32 λ����
        mov ax, data32_sel
        mov ds, ax
        mov es, ax        
        mov ss, ax
;*
;* �� compatibility ��stack�ṹ��������
;* ������²������� ==> mov esp, LIB32_ESP
;*
;* chang log: ȥ�� mov esp, LIB32_ESP ����ָ��������� compatibility ģʽ�µ� esp ֵ
;*            ʹ�� compatibility ģʽ�� esp �� 64-bit rsp �� 32 λ��ͬ��ӳ�䷽ʽ
;*


;*
;* ����Ĵ��뽫���� lib32.asm ���ڵĺ����������� compatibility ģʽ��
;*
call_lib32:
        lea eax, [LIB32_SEG + ebx * 4 + ebx]            ; rbx * 5 + LIB32_SEG �õ� lib32 �⺯����ַ
        call eax                                        ;; ִ�� 32λ����
        jmp DWORD far [lib32_service_64_pointer]        ;; �л��� 64 λģʽ

        bits 64
lib32_service_done:   
        lea rsp, [r15 - 32]                             ; ȡ��ԭ RSP ֵ
        pop rdx
        pop rcx
        pop rbx
        pop rbp
        pop r15
        retf64                                          ; ʹ�ú� ref64 



;------------------------------------------------------------------------
; set_system_descriptor(int selector, int limit, long long base, int type)
; input:
;                rsi: selector,  rdi: limit, r8: base, r9: type
;--------------------------------------------------------------------------
__set_system_descriptor:
        sgdt [gdt_pointer]
        mov rax, [gdt_pointer + 2]
        and esi, 0FFF8h                         ; selector
        mov [rax + rsi + 4], r8                 ; base[63:24]
        mov [rax + rsi + 2], r8d                ; base[23:0]
        or r9b, 80h
        mov [rax + rsi + 5], r9b                ; DPL=0, type=r9

        ;* �������� limit ֵ
        ;* ��� limit ���� 4K �Ļ�
        mov r8, rdi
        shr r8, 12                              ; �� 4K
        cmovz r8d, edi                          ; Ϊ 0 ʹ��ԭֵ
        setnz dil                                ; ��Ϊ 0 �� G λ
        mov [rax + rsi], r8w                    ; limit[15:0]
        shl r8w, 5
        shrd r8w, di, 17                        ; ���� G λ
        mov [rax + rsi + 6], r8b                ; limit[19:16]
        ret
        
;------------------------------------------------------------------------
; set_call_gate(int selector, long long address)
; input:
;                rsi: selector,  rdi: address, r8: DPL, r9: code_selector
; ע�⣺
;                ���ｫ call gate ��Ȩ����Ϊ 3 �������û�������Ե���
;--------------------------------------------------------------------------
__set_call_gate:
        sgdt [gdt_pointer]
        mov rax, [gdt_pointer + 2]
        and esi, 0FFF8h
        mov [rax + rsi], rdi                    ; offset[15:0]
        mov [rax + rsi + 4], rdi                ; offset[63:16]
        mov DWORD [rax + rsi + 12], 0           ; ���λ
        mov [rax + rsi + 2], r9d                ; selector
        and r8b, 0Fh
        shl r8b, 5
        or r8b, 80h | CALL_GATE64
        mov [rax + rsi + 5], r8b                ; attribute
        ret        



        
;------------------------------------------------------
; set_interrupt_handler(int vector, void(*)()handler)
; input:
;                rsi: vector,  rdi: handler
;------------------------------------------------------
__set_interrupt_handler:
        sidt [idt_pointer]        
        mov rax, [idt_pointer + 2]                              ; IDT base
        shl rsi, 4                                              ; vector * 16
        mov [rax + rsi], rdi                                    ; offset [15:0]
        mov [rax + rsi + 4], rdi                                ; offset [63:16]
        mov DWORD [rax + rsi + 2], kernel_code64_sel            ; set selector
        mov BYTE [rax + rsi + 5], 80h | INTERRUPT_GATE64        ; Type=interrupt gate, P=1, DPL=0
        ret
        
;------------------------------------------------------
; set_user_interrupt_handler(int vector, void(*)()handler)
; input:
;                rsi: vector,  rdi: handler
;------------------------------------------------------
__set_user_interrupt_handler:
        sidt [idt_pointer]        
        mov rax, [idt_pointer + 2]                              ; IDT base
        shl rsi, 4                                              ; vector * 16
        mov [rax + rsi], rdi                                    ; offset [15:0]
        mov [rax + rsi + 4], rdi                                ; offset [63:16]
        mov DWORD [rax + rsi + 2], kernel_code64_sel            ; set selector
        mov BYTE [rax + rsi + 5], 0E0h | INTERRUPT_GATE64       ; Type=interrupt gate, P=1, DPL=3
        ret
                
;-----------------------------------------------------
; read_idt_descriptor(): �� IDT ����� gate descriptor
; input:
;                rsi: vector
; output:
;                rdx:rax - 16 bytes gate descriptor
;------------------------------------------------------
__read_idt_descriptor:
        sidt [idt_pointer]        
        mov rax, [idt_pointer + 2]                              ; IDT base
        shl rsi, 4                                              ; vector * 16
        mov rdx, [rax + rsi + 8]
        mov rax, [rax + rsi]
        ret

;-----------------------------------------------------
; write_idt_descriptor(): д�� IDT ��
; input:
;                rsi: vector�� rdx:rax - gate descriptor
;------------------------------------------------------
__write_idt_descriptor:
        sidt [idt_pointer]        
        mov rdi, [idt_pointer + 2]                              ; IDT base
        shl rsi, 4                                              ; vector * 16
        mov [rdi + rsi + 8], rdx
        mov [rdi + rsi], rax
        ret
        
                        
;------------------------------------------------------
; read_segment_descriptor(): ����������
; input:
;                rsi: selector
; output:
;                rax: segment descriptor 
;------------------------------------------------------
__read_segment_descriptor:
        sgdt [gdt_pointer]
        mov rax, [gdt_pointer + 2]
        and esi, 0FFF8h
        mov rax, [rax + rsi]
        ret
        
;-------------------------------------------------------
; write_segment_descriptor():
; input:
;                rsi: selector,  rdi: descriptor
;--------------------------------------------------------        
__write_segment_descriptor:
        sgdt [gdt_pointer]
        mov rax, [gdt_pointer + 2]
        and esi, 0FFF8h
        mov [rax + rsi], rdi
        ret        

;------------------------------------------------------
; read_system_descriptor(): ��ϵͳ������
; input:
;                rsi: selector
; output:
;                rdx:rax: system descriptor
;------------------------------------------------------
__read_system_descriptor:
        sgdt [gdt_pointer]
        mov rax, [gdt_pointer + 2]
        and esi, 0FFF8h
        mov rdx, [rax + rsi + 8]
        mov rax, [rax + rsi]        
        ret
        
;-----------------------------------------------------
; get_tss_base();
; input:
;                rsi: tss selector
; output:
;                rax: base
;-----------------------------------------------------
__get_tss_base:
        call __read_system_descriptor                   ; rdx:rax
        shld rdx, rax, 32                               ; base[63:24]
        mov rdi, 0FFFFFFFFFF000000h
        and rdx, rdi
        shr rax, 16
        and eax, 0FFFFh
        or rax, rdx
        ret

        
__get_tr_base:
        str esi
        call __get_tss_base
        ret        
        
        
        
;---------------------------------------------------------
; set_segment_descriptor(): ���ö�������
; input:
;                rsi: selector, rdi: limit, r8: base, r9: attribute
;---------------------------------------------------------
__set_segment_descriptor:
        sgdt [gdt_pointer]
        mov rax, [gdt_pointer + 2]
        and esi, 0FFF8h
        and edi, 0FFFFFh
        mov [rax + rsi], di                       ; limit[15:0]
        mov [rax + rsi + 2], r8w                ; base[15:0]
        shr r8, 16
        mov [rax + rsi + 4], r8b                ; base[23:16]
        shr edi, 16
        shl edi, 8
        or edi, r9d
        mov [rax + rsi + 5], di                   ; attribute
        shr r8, 8
        mov [rax + rsi + 7], r8b                ; base[31,24]
        ret


;----------------------------------------------------------------
; set_sysenter():       long-mode ģʽ�� sysenter/sysexitʹ�û���
;----------------------------------------------------------------
__set_sysenter:
        xor edx, edx
        mov eax, KERNEL_CS
        mov ecx, IA32_SYSENTER_CS
        wrmsr                                                        ; ���� IA32_SYSENTER_CS

%ifdef MP
;*
;* chang log: 
;       ���ӶԶദ����������֧��
;*      ÿ�����������䲻ͬ�� RSP ֵ
;*
        mov ecx, [processor_index]                                      ; index ֵ
        mov eax, PROCESSOR_STACK_SIZE                                   ; ÿ���������� stack �ռ��С
        mul ecx                                                         ; stack_offset = STACK_SIZE * index
        mov rcx, PROCESSOR_SYSENTER_RSP                                 ; stack ��ֵ
        add rax, rcx  
%else
        mov rax, KERNEL_RSP
%endif
        mov rdx, rax
        shr rdx, 32
        mov ecx, IA32_SYSENTER_ESP                
        wrmsr                                                        ; ���� IA32_SYSENTER_ESP
        mov rdx, __sys_service
        shr rdx, 32
        mov rax, __sys_service
        mov ecx, IA32_SYSENTER_EIP
        wrmsr                                                        ; ���� IA32_SYSENTER_EIP
        ret        

;----------------------------------------------------------------
; set_syscall():        long-mode ģʽ�� syscall/sysretʹ�û��� 
;----------------------------------------------------------------
__set_syscall:
; enable syscall ָ��
        mov ecx, IA32_EFER
        rdmsr
        bts eax, 0                                      ; SYSCALL enable bit
        wrmsr
        mov edx, KERNEL_CS | (sysret_cs_sel << 16)
        xor eax, eax
        mov ecx, IA32_STAR
        wrmsr                                           ; ���� IA32_STAR
        mov rdx, __sys_service_routine
        shr rdx, 32
        mov rax, __sys_service_routine
        mov ecx, IA32_LSTAR
        wrmsr                                            ; ���� IA32_LSTAR
        xor eax, eax
        xor edx, edx
        mov ecx, IA32_FMASK
        wrmsr
;;  �������� KERNEL_GS_BASE �Ĵ���
        mov rdx, kernel_data_base
        mov rax, rdx
        shr rdx, 32
        mov ecx, IA32_KERNEL_GS_BASE        
        wrmsr
        ret

;-----------------------------------------------------
; sys_service_enter():         ϵͳ�������̽ӿ� stub ����
; input:
;                rax: ϵͳ�������̺�
;-----------------------------------------------------
__sys_service_enter:
        push rcx
        push rdx
        mov rcx, rsp
        mov rdx, return_64_address
        sysenter
return_64_address:        
        pop rdx
        pop rcx
        ret

;-----------------------------------------------------
; sys_service_call():         ϵͳ�������̽ӿ� stub ����, syscall �汾
; input:
;                rax: ϵͳ�������̺�
;-----------------------------------------------------
__sys_service_call:
        push rbp
        push rcx
        mov rbp, rsp                                    ; ��������ߵ� rsp ֵ
        mov rcx, return_64_address_syscall              ; ���ص�ַ
        syscall
return_64_address_syscall:        
        mov rsp, rbp
        pop rcx
        pop rbp
        ret
        
        


        bits 32
;-------------------------------------------------------------
; compatibility_sys_service_enter(): compatibility ģʽ�µ� stub
; ������
;       ������ compatibilityģʽ��ʹ��
;----------------------------------------------------------------
__compatibility_sys_service_enter:
        push ecx
        push edx
        mov ecx, esp
        mov edx, return_compatibility_address
        sysenter
return_compatibility_pointer:   dq compatibility_sys_service_enter_done
                                dw user_code32_sel | 3        
return_compatibility_address:        
        bits 64
        jmp QWORD far [return_compatibility_pointer]            ; ��64-bit�л���compatibilityģʽ
compatibility_sys_service_enter_done:
        bits 32
        pop edx
        pop ecx
        ret


        bits 64
;---------------------------------------------------
; sys_service(): ϵͳ��������, sysenter/sysexit�汾
;---------------------------------------------------
__sys_service:
        push rbp
        push rcx
        push rdx
        push rbx
        mov rbp, rsp
        mov rbx, rax
        
        
        jmp QWORD far [lib32_service_enter_compatiblity_pointer]        ; �� 64 λ�л��� compatibilityģʽ
        
;; ���� far pointer        
lib32_service_enter_compatiblity_pointer:       dq        lib32_service_enter_compatibility
                                                dw        code32_sel
lib32_service_enter_64_pointer:                 dd        lib32_service_enter_done
                                                dw        KERNEL_CS
                                                                        
lib32_service_enter_compatibility:
        bits 32
;; �������� 32 λ����
        mov ax, data32_sel
        mov ds, ax
        mov es, ax        
        mov ss, ax
;        mov esp, LIB32_ESP
lib32_enter:
        lea eax, [LIB32_SEG + ebx * 4 + ebx]                      ; rbx * 5 + LIB32_SEG �õ� lib32 �⺯����ַ
        call eax                                                  ;; ִ�� 32λ����
        jmp DWORD far [lib32_service_enter_64_pointer]            ;; �л��� 64 λģʽ
        bits 64
lib32_service_enter_done:        
        mov rsp, rbp
        pop rbx
        pop rdx
        pop rcx
        pop rbp
        sysexit64                                                 ; ���ص� 64-bit ģʽ
        
;-----------------------------------------------------
; sys_service_routine():  ϵͳ�������̣�syscall/sysret �汾
;-----------------------------------------------------        
__sys_service_routine:
        swapgs                                 ; ��ȡ Kernel ����
        mov rsp, [gs:0]                        ; �õ� kernel rsp ֵ
        push rbp
        push r11
        push rcx
        push rbx
        mov rbp, rsp
        mov rbx, rax

        jmp QWORD far [lib32_service_call_compatiblity_pointer] ; �� 64 λ�л��� compatibilityģʽ
        
;; ���� far pointer
lib32_service_call_compatiblity_pointer:        dq        lib32_service_call_compatibility
                                                dw         code32_sel
lib32_service_call_64_pointer:                  dd        lib32_service_call_done
                                                dw        KERNEL_CS
                                                                        
lib32_service_call_compatibility:
        bits 32
;; �������� 32 λ����
        mov ax, data32_sel
        mov ds, ax
        mov es, ax        
        mov ss, ax
;        mov esp, LIB32_ESP
lib32_call:
        lea eax, [LIB32_SEG + ebx * 4 + ebx]                        ; rbx * 5 + LIB32_SEG �õ� lib32 �⺯����ַ
        call eax                                                     ;; ִ�� 32λ����
        jmp DWORD far [lib32_service_call_64_pointer]                ;; �л��� 64 λģʽ
        bits 64
lib32_service_call_done:
        
        mov rsp, rbp
        pop rbx
        pop rcx
        pop r11
        pop rbp
        swapgs                                        ; �ֵ� GS.base
        sysret64                                      ; ���� 64-bit ģʽ
        
        

;*
;* ���ùҽ�ϵͳ�����
;* ʹ�������û������� int 40h ����
;*

;--------------------------------------
; set_system_service(): ����ϵͳ�����
; input:
;       rsi - �û��Զ���ϵͳ�������̺�
;       rdi - �û��Զ���ϵͳ��������
;-------------------------------------
__set_user_system_service:
        cmp rsi, 10
        jae set_system_service_done                     ; �����û����̺Ŵ��ڵ��� 10 ���˳�
        mov [__system_service_table + rsi * 8], rdi     ; д���û��Զ�������
set_system_service_done:        
        ret


;------------------------------------------------------
; user_system_service_call(): �����û��Զ���ķ�������
; input:
;       rax - �û��Զ���ϵͳ�������̺�
; ������
;       �ɺ����� Int 40h ������
;-----------------------------------------------------
__user_system_service_call:
        cmp rax, 10
        jae user_system_service_call_done
        mov rax, [__system_service_table + rax * 8]
        call rax
user_system_service_call_done:
        iret64

                
;******** lib64 ģ��ı������� ********

video_current        dd 0B8000h


;****** ϵͳ����� ***********

__system_service_table:
        times 10 dq 0                                   ; ���� 10 ���Զ���ϵͳ������


lib64_context   times 20 dq 0


;; ϵͳ���ݱ�
kernel_data_base        dq        PROCESSOR_SYSCALL_RSP         ; ϵͳջ

                

; GDT ��ָ��
gdt_pointer             dw 0                        ; GDT limit ֵ
                        dq 0                        ; GDT base ֵ

; IDT ��ָ��
idt_pointer             dw 0                        ; IDT limit ֵ
                        dq 0                        ; IDT base ֵ
                        
                        
LIB64_END:                