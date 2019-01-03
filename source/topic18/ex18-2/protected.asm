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
        call disable_keyboard
        call disable_timer
        sti

        ;*
        ;* perfmon 初始设置
        ;* 关闭所有 counter 和 PEBS 
        ;* 清 overflow 标志位
        ;*
        DISABLE_GLOBAL_COUNTER
        DISABLE_PEBS
        RESET_COUNTER_OVERFLOW        

;开启APIC
        call enable_xapic        
        
;设置 APIC performance monitor counter handler
        mov esi, APIC_PERFMON_VECTOR
        mov edi, apic_perfmon_handler
        call set_interrupt_handler

        
; 设置 LVT performance monitor counter
        mov DWORD [APIC_BASE + LVT_PERFMON], FIXED_DELIVERY | APIC_PERFMON_VECTOR


;========= 初始化设置完毕 =================


;;; 实验 18-02：测试 APIC base地址的重定位
        
;; 1) 读原来的 SVR 寄存器值        
        mov esi, msg2
        call puts
        call get_apic_base
        add eax, SVR                                        ; 得到 SVR 寄存器物理地址
        mov esi, eax
        mov edi, edx
        call print_qword_value
        mov esi, msg3
        call puts
        mov esi, [APIC_BASE + SVR]
        call print_dword_value
        call println
        
        mov esi, msg1
        call puts
        
; 2) 设置 APIC base 地址
        mov esi, 0xFEF00000                                ; 重定位在 0xFEF00000 上
        mov edi, 0
        call set_apic_base
        mov esi, msg2
        call puts
        call get_apic_base
        add eax, SVR                                        ; 得到 SVR 寄存器物理地址
        mov esi, eax
        mov edi, edx
        call print_qword_value
        mov esi, msg3
        call puts
        mov esi, [APIC_BASE + 0xfef00000 - 0xfee00000 + SVR]
        call print_dword_value
  

        jmp $

msg1    db 10, '>>> now: set APIC base is 0xfef00000 <<<', 10, 0
msg2    db 'SVR(0x', 0
msg3    db '): 0x', 0


        
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


;;************* 函数导入表  *****************

; 这个 lib32 库导入表放在 common\ 目录下，
; 供所有实验的 protected.asm 模块使用

%include "..\common\lib32_import_table.imt"


PROTECTED_END: