; protected.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\support.inc"
%include "..\inc\protected.inc"

; 这是 protected 模块

        bits 32
        
        org PROTECTED_SEG - 2

PROTECTED_BEGIN:
protected_length        dw        PROTECTED_END - PROTECTED_BEGIN       ; protected 模块长度

entry:
        
;; 为了完成实验，关闭时间中断和键盘中断
        call disable_timer
        
;; 设置 #PF handler
        mov esi, PF_HANDLER_VECTOR
        mov edi, PF_handler
        call set_interrupt_handler        

;; 设置 #GP handler
        mov esi, GP_HANDLER_VECTOR
        mov edi, GP_handler
        call set_interrupt_handler

; 设置 #DB handler
        mov esi, DB_HANDLER_VECTOR
        mov edi, DB_handler
        call set_interrupt_handler


;; 设置 sysenter/sysexit 使用环境
        call set_sysenter

;; 设置 system_service handler
        mov esi, SYSTEM_SERVICE_VECTOR
        mov edi, system_service
        call set_user_interrupt_handler 

; 允许执行 SSE 指令        
        mov eax, cr4
        bts eax, 9                                ; CR4.OSFXSR = 1
        mov cr4, eax
        
        
;设置 CR4.PAE
        call pae_enable
        
; 开启 XD 功能
        call execution_disable_enable
                
; 初始化 paging 环境
        call init_pae_paging
        
;设置 PDPT 表地址        
        mov eax, PDPT_BASE
        mov cr3, eax
                                
; 打开　paging
        mov eax, cr0
        bts eax, 31
        mov cr0, eax                                 

        mov esi, PIC8259A_TIMER_VECTOR
        mov edi, timer_handler
        call set_interrupt_handler        

        mov esi, KEYBOARD_VECTOR
        mov edi, keyboard_handler
        call set_interrupt_handler                
        
        call init_8259A
        call init_8253        
        call disable_8259
        sti
        
;========= 初始化设置完毕 =================


;
;** 实验 20-3：打印 status信息及 stack
;

        finit                                   ; 初始化 x87 FPU
        fldz                                    ; 加载 0.0
        fld TWORD [QNaN_value]                  ; 加载 QNaN 数
        fld TWORD [SNaN_value]                  ; 加载 SNaN 数
        fld1                                    ; 加载 1.0
        call dump_data_register                 ; 打印 stack
        call println
        mov esi, msg
        call puts

;; 有序比较
        fcom st2                                ; ST(2)是 QNaN 数
        call dump_x87_status

;; 清异常和条件位
        fstenv [x87env32]
        and WORD [status_word], 0x3800          ; 清 status
        fldenv [x87env32]

;; 无序比较
        mov esi, msg1
        call puts

        fucom st2                               ; ST(2)是 QNaN 数
        call dump_x87_status

;; 清异常和条件位
        fstenv [x87env32]
        and WORD [status_word], 0x3800          ; 清 status
        fldenv [x87env32]

; 比较 SNaN 数
        mov esi, msg2
        call puts

        fucom st1                               ; ST(1)是 SNaN 数
        call dump_x87_status

        jmp $
        


SNaN_value      dd 0xffffffff                    ; SNaN 数编码
                dd 0xbfffffff
                dw 0xffff

QNaN_value      dd 0xffffffff                   ; QNaN 数编码
                dd 0xffffffff
                dw 0xffff
infinity        dd 0x7f800000                   ; infinity 数编码
denormal        dd 0xFFFFFFFF                   ; denormal 数编码
                dd 0x7FFFFFFF
                dw 0


msg     db 10, 'fcom st2 (for QNaN): ', 10, 0
msg1    db 10, 'fucom st2 (for QNaN): ', 10, 0
msg2    db 10, 'fucom st1 (for SNaN): ', 10, 0


; 转到 long 模块
        ;jmp LONG_SEG
                                
                                
; 进入 ring 3 代码
        push DWORD user_data32_sel | 0x3
        push DWORD USER_ESP
        push DWORD user_code32_sel | 0x3        
        push DWORD user_entry
        retf

        
;; 用户代码

user_entry:
        mov ax, user_data32_sel
        mov ds, ax
        mov es, ax

user_start:

        jmp $






%define APIC_PERFMON_HANDLER

;******** include 中断 handler 代码 ********
%include "..\common\handler32.asm"


;********* include 模块 ********************
%include "..\lib\creg.asm"
%include "..\lib\cpuid.asm"
%include "..\lib\msr.asm"
%include "..\lib\pci.asm"
%include "..\lib\apic.asm"
%include "..\lib\debug.asm"
%include "..\lib\perfmon.asm"
%include "..\lib\page32.asm"
%include "..\lib\pic8259A.asm"
%include "..\lib\x87.asm"

;;************* 函数导入表  *****************

; 这个 lib32 库导入表放在 common\ 目录下，
; 供所有实验的 protected.asm 模块使用

%include "..\common\lib32_import_table.imt"


PROTECTED_END: