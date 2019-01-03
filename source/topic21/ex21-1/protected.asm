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
        bts eax, 9                              ; CR4.OSFXSR = 1
        bts eax, 10                             ; CR4.OSXMMEXCPT = 1
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


;; 实验　ex21-1：测试#XM异常handler

;; 设置 x87 FPU 和 MMX 环境
        mov eax, cr0
        bts eax, 1              ; MP = 1
        btr eax, 2              ; EM = 0
        mov cr0, eax

; 设置 #XM handler
        mov esi, XM_HANDLER_VECTOR
        mov edi, xm_handler
        call set_interrupt_handler

        
        stmxcsr [esp]
        and DWORD [esp], 0xe07f         ; clear mask 位
        ldmxcsr [esp]
        movups xmm0, [a]
        movups xmm1, [b]
        addps xmm0, xmm1                ; 产生 numeric 异常
        jmp $

a       dd 0, 0, 0, 0x76000000
b       dd 0, 0x7fa00000, 1, 0x7f7fffff



;-------------------------------------
; SIMD floating-point 异常 handler
;-------------------------------------
xm_handler:
        jmp do_xm_handler
xhmsg   db '>>> now: enter #XM handler, occur at 0x', 0
xhmsg0  db 'exit the #XM handler <<<', 10, 0        

do_xm_handler:        
        mov esi, xhmsg
        call puts
        mov esi, [esp]
        call print_dword_value
        call println
        call dump_mxcsr
        sub esp, 4
        stmxcsr [esp]
        mov eax, [esp]
        
        bt eax, 0               ; IE
        jnc test_de
        btr eax, 0
        bts eax, 7        
test_de:        
        bt eax, 1               ; DE
        jnc test_ze
        btr eax, 1
        bts eax, 8
test_ze:        
        bt eax, 2               ; ZE
        jnc test_oe
        btr eax, 2
        bts eax, 9
test_oe:
        bt eax, 3               ; OE
        jnc test_ue
        btr eax, 3
        bts eax, 10
test_ue:
        bt eax, 4               ; UE
        jnc test_pe
        btr eax, 4
        bts eax, 11
test_pe:
        bt eax, 5               ; PE
        jnc set_mxcsr
        btr eax, 5
        bts eax, 12
set_mxcsr:
        mov [esp], eax
        ldmxcsr [esp]
        add esp, 4
        mov esi, xhmsg0
        call puts
        iret

        

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
%include "..\lib\sse.asm"

;;************* 函数导入表  *****************

; 这个 lib32 库导入表放在 common\ 目录下，
; 供所有实验的 protected.asm 模块使用

%include "..\common\lib32_import_table.imt"


PROTECTED_END: