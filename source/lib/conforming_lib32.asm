; conforming_lib32.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


;; ������� conforming ����ִ�У������κ�Ȩ�޵Ĵ���ִ��

        bits 32


;-----------------------------------------------
; conforming_lib32_service_enter(): conforming������ stub����
; input:
;       esi: clib32 �⺯�������̺�
; ������
;       conforming_lib32_service_enter()���������л��� conforming����,
;       Ȼ����� conforming lib32 ����ķ�������, ���൱��һ�� gate �����á�
; -----------------------------------------------
__clib32_service_enter:
__conforming_lib32_service_enter:
        jmp do_conforming_lib32_service
conforming_lib32_service_pointer        dd __conforming_lib32_service
                                        dw conforming_sel        
do_conforming_lib32_service:        
        call DWORD far [conforming_lib32_service_pointer]        ; ʹ�� conforming �ν��е���
        ret

;--------------------------------------------
; clib32_service()
; input:
;       eax: clib32 �⺯������
;--------------------------------------------
__conforming_lib32_service:
        mov eax, [__clib32_service_table + eax * 4]
        call eax
        retf


;---------------------------------------------
; set_clib32_service_table
; input:
;       esi-�����, edi-��������
;---------------------------------------------
__set_clib32_service_table:
        lea eax, [__clib32_service_table + esi * 4]
        mov [eax], edi
        ret


;----------------------------------------------------------
; get_cpl(): �õ� CPL ֵ
; output:
;       eax: CPL ֵ
;----------------------------------------------------------
__get_cpl:
        mov ax, cs
        and eax, 0x03
        ret

;----------------------------------------------------------
; get_dpl()
; input:
;       esi: selector
; output:
;       eax: dpl
;----------------------------------------------------------
__get_dpl:
        push edx
        call read_gdt_descriptor
        shr edx, 13
        and edx, 03h
        mov eax, edx
        pop edx
        ret
        
;----------------------------------------------------------
; get_gdt_limit():
; output:
;       eax: limit
;-----------------------------------------------------------
__get_gdt_limit:
        jmp do_get_gdt_limit
get_gdt_pointer:        dw 0                ; limit
                        dd 0                ; base        
do_get_gdt_limit:        
        sgdt [get_gdt_pointer]
        movzx eax, WORD [get_gdt_pointer]
        ret

;----------------------------------------------------------
; get_ldt_limit():
; output:
;       eax: limit
;-----------------------------------------------------------
__get_ldt_limit:
        jmp do_get_ldt_limit
get_ldt_pointer         dw 0                ; limit
                        dd 0                ; base        
do_get_ldt_limit:
        sldt [get_ldt_pointer]
        movzx eax, WORD [get_ldt_pointer]
        ret        
        
;-------------------------------------------
; check_null_selector():
; input:
;       esi: selector
;-------------------------------------------
__check_null_selector:
        mov eax, esi
        and eax, 0x00FFFC
        setz al
        movzx eax, al
        ret        
        
;------------------------------------------------------------
; load_ss_reg(): ���� SS �Ĵ���
; input:
;       esi: selector
;-----------------------------------------------------------
__load_ss_reg:
        jmp do_load_ss_reg
lsr_msg1        db 'load SS failure: Null-selector', 10, 0
lsr_msg2        db 'load SS failure: selector.RPL != CPL', 10, 0
lsr_msg3        db 'load SS failure: CPL != DPL', 10, 0
lsr_msg4        db 'load SS failure: check limit', 10, 0
lsr_msg5        db 'load SS failure: a system descriptor', 10, 0
lsr_msg6        db 'load SS failure: non data segment', 10, 0
lsr_msg7        db 'load SS failure: non writable segment', 10, 0
lsr_msg8        db 'load SS failure: non present', 10, 0
do_load_ss_reg:        
        push ecx
        push edx
        mov ecx, esi
        
; ��� selector
        call __check_null_selector
        test eax, eax
        jz check_privilege
        mov esi,lsr_msg1
        call puts
        jmp load_ss_reg_done
        
; ���Ȩ��        
check_privilege:
        call __get_cpl
        mov esi, ecx
        and esi, 0x03
        cmp esi, eax                                ; RPL == CPL ?
        jz check_privilege_next
        mov esi, lsr_msg2
        call puts
        jmp load_ss_reg_done
check_privilege_next:
        mov esi, ecx
        call __get_dpl
        mov esi, ecx
        and esi, 0x03
        cmp esi, eax                                ; CPL == DPL ?
        jz check_limit
        mov esi, lsr_msg3
        call puts
        jmp load_ss_reg_done
        
; ��� selector �Ƿ� GDT/LDT limits
check_limit:        
        mov esi, ecx
        bt esi, 2
        jc ldt_limit
        call __get_gdt_limit
        jmp check_limit_next
ldt_limit:
        call __get_ldt_limit
check_limit_next:        
        and esi, 0xFFF8
        add esi, 8
        cmp esi, eax
        jbe check_descriptor
        mov esi, lsr_msg4
        call puts
        jmp load_ss_reg_done

; ��� data segment descriptor ����                
check_descriptor:
        mov esi, ecx
        call __read_gdt_descriptor
        bt edx, 12                                        ; S ��־                
        jc check_cd                        
        mov esi, lsr_msg5
        call puts
        jmp load_ss_reg_done
check_cd:
        bt edx, 11                                        ; Code/Data ��־
        jnc check_w
        mov esi, lsr_msg6
        call puts
        jmp load_ss_reg_done        
check_w:
        bt edx, 9                                        ; W ��־
        jc check_p
        mov esi, lsr_msg7
        call puts
        jmp load_ss_reg_done
check_p:
        bt edx, 15                                        ; P ��־
        jc load_ss
        mov esi, lsr_msg8                 
        call puts
        jmp load_ss_reg_done
load_ss:
        mov ss, cx        
load_ss_reg_done:        
        pop edx
        pop ecx
        ret



;*** conforming ������ *****

;
; conforming lib32 ��������̱�
__clib32_service_table:
        dd __get_cpl                            ; 0 ��
        dd __get_dpl                            ; 1 ��
        dd __get_gdt_limit                      ; 2 ��
        dd __get_ldt_limit                      ; 3 ��
        dd __check_null_selector                ; 4 ��
        dd __load_ss_reg                        ; 5 ��
        dd 0
        dd 0
        dd 0
        dd 0

; ���汣�� 5 ������Ÿ��û�����
        dd 0                                    ; CLIB32_SERVICE_USER0
        dd 0                                    ; CLIB32_SERVICE_USER1
        dd 0                                    ; CLIB32_SERVICE_USER2
        dd 0                                    ; CLIB32_SERVICE_USER3
        dd 0                                    ; CLIB32_SERVICE_USER4


