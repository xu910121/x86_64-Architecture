; setup.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


; ����һ���հ�ģ��ʾ������Ϊ setup ģ��
; ����д����̵ĵ� 2 ������ ��
;

%include "..\inc\support.inc"
%include "..\inc\protected.inc"

;
; setup ģ���������� 16 λʵģʽ��

        bits 16
        
        
;
; ģ�鿪ʼ���� SETUP_SEG - 2���� 2 ����ΪҪ����ģ��ͷ�Ĵ�ŵġ�ģ�� size��
; load_module ���ص� SETUP_SEG-2��ʵ��Ч���� SETUP ģ��ᱻ���ص�����ڵ㡱����setup_entry
;
        org SETUP_SEG - 2
        
;
; ��ģ��Ŀ�ͷ word ��С����������ģ��Ĵ�С��
; load_module �������� size ����ģ�鵽�ڴ�

SETUP_BEGIN:

setup_length        dw (SETUP_END - SETUP_BEGIN)        ; SETUP_END-SETUP_BEGIN �����ģ��� size


setup_entry:                            ; ����ģ��������ڵ㡣

        cli
        NMI_DISABLE

        call support_long_mode
        test eax, eax
        jz no_support


; ���� GDTR
        db 66h                          ; ʹ�� 32 λ operand size
        lgdt [GDT_POINTER]        


; ���� PAE
        mov eax, cr4
        bts eax, 5                      ; CR4.PAE = 1
        mov cr4, eax

; init page
        call init_page

; ���� CR3
        mov eax, 5000h
        mov cr3, eax

; enable long-mode
        mov ecx, IA32_EFER
        rdmsr
        bts eax, 8                      ; IA32_EFER.LME =1
        wrmsr

        mov si, msg0
        call puts

; ���� IDTR        
        db 66h                          ; ʹ�� 32-bit operand size
        lidt [IDT_POINTER]        

; ���� PE �� paging
        mov eax, cr0
        bts eax, 0                      ; CR0.PE =1
        bts eax, 31
        mov cr0, eax                    ; IA32_EFER.LMA = 1

        
        jmp 28h:entry64                                                
        

no_support:
        mov si, msg1
        call puts
        jmp $

;;; ������ 64-bit ģʽ����
        
        bits 64

entry64:
        mov ax, 30h                    ; ���� data segment
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov esp, 7FF0h        

        mov esi, msg2
        call puts64
        jmp $
                


puts64:
        mov edi, 0B8000h

puts64_loop:
        lodsb
        test al, al
        jz puts64_done
        cmp al, 10
        jne puts64_next
        add edi, 80*2
        jmp puts64_loop
puts64_next:
        mov ah, 0Fh
        stosw
        jmp puts64_loop

puts64_done:
        ret


msg0        db 'now: enter real-mode', 13, 10, 0        
msg1        db 'no support long mode', 13, 10, 0
msg2        db 10, 'now: enter 64-bit mode', 0
        

; ���¶��� protected mode �� GDT �� segment descriptor

GDT:
null_desc               dq 0                            ; NULL descriptor

code16_desc             dq 0x00009a000000ffff           ; for real mode code segment
data16_desc             dq 0x000092000000ffff           ; for real mode data segment
code32_desc             dq 0x00cf9a000000ffff           ; for protected mode code segment
                                                           ; or for compatibility mode code segment
data32_desc             dq 0x00cf92000000ffff           ; for protected mode data segment
                                                        ; or for compatibility mode data segment

kernel_code64_desc      dq 0x0020980000000000           ; 64-bit code segment
kernel_data64_desc      dq 0x0000920000000001            ; 64-bit data segment
;;; ҲΪ sysexit ָ��ʹ�ö���֯
user_code32_desc        dq 0x00cffa000000ffff           ; for protected mode code segment
                                                        ; or for compatibility mode code segmnt
user_data32_desc        dq 0x00cff2000000ffff           ; for protected mode data segment
                                                        ; or for compatibility mode data segment        
;; ҲΪ sysexit ָ��ʹ�ö���֯                                                 
user_code64_desc        dq 0x0020f80000000000           ; 64-bit non-conforming
user_data64_desc        dq 0x0000f20000000000           ; 64-bit data segment
        times 10        dq 0                            ; ���� 10 ��
GDT_END:


; ���¶��� protected mode �� IDT entry
IDT:
        times 0x50 dq 0                                ; ���� 0x50 �� vector
IDT_END:


TSS32_SEG:
        dd 0                
        dd 1FFFF0h                                  ; esp0
        dd kernel_data32_sel                        ; ss0
        dq 0                                        ; ss1/esp1
        dq 0                                        ; ss2/esp2
times 19 dd 0        
         dw 0
IOBITMAP_ADDRESS        dw        IOBITMAP - TSS32_SEG
TSS32_END:

TSS_TEST_SEG:
        dd 0                
        dd 0x8f00                                   ; esp0
        dd kernel_data32_sel                        ; ss0
        dq 0                                        ; ss1/esp1
        dq 0                                        ; ss2/esp2
times 19 dd 0        
                dw 0
TEST_IOBITMAP_ADDRESS        dw        IOBITMAP - TSS_TEST_SEG
TSS_TEST_END:



;; Ϊ IO bit map ���� 10 bytes��IO space �� 0 - 80��
IOBITMAP:
times        10 db 0        
IOBITMAP_END:


; ���� GDT pointer
GDT_POINTER:
GDT_LIMIT        dw        GDT_END - GDT - 1
GDT_BASE         dd        GDT

; ���� IDT pointer
IDT_POINTER:
IDT_LIMIT        dw        IDT_END - IDT - 1
IDT_BASE         dd        IDT

;; ����ʵģʽ��  IVT pointer
IVT_POINTER:     dw     3FFH
                 dd     0


        bits 16

;; ��ʼ�� page 
init_page:
        ;; virtual address 0 �� 1FFFFFh
        ;; ӳ�䵽 physical address 0 �� 1FFFFFh��ʹ�� 2M ҳ

        ; PML4T[0]
        mov DWORD [0x5000], 0x6000 | RW | US | P
        mov DWORD [0x5004], 0

        ; PDPT[0]
        mov DWORD [0x6000], 0x7000 | RW | US | P
        mov DWORD [0x6004], 0

        ; PDT[0]
        mov DWORD [0x7000], 0000h | PS | RW | US | P    ; ���� page 0
        mov DWORD [0x7004], 0

        ret
                

;---------------------------------------------------
; support_long_mode(): ����Ƿ�֧��long-modeģʽ
; output:
;        1-support, 0-no support
;---------------------------------------------------
support_long_mode:
        mov eax, 80000000H
        cpuid
        cmp eax, 80000001H
        setnb al
        jb support_long_mode
        mov eax, 80000001H
        cpuid
        bt edx, 29                ; long mode  support λ
        setc al

support_long_mode_done:
        movzx eax, al
        ret


;
; ���������ģ��ĺ��������
; ʹ���� lib16 �����ĺ���


FUNCTION_IMPORT_TABLE:

puts:   jmp     LIB16_SEG + LIB16_PUTS * 3


SETUP_END:

; end of setup        