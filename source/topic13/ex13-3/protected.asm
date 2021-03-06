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
        
;; 关闭8259
        call disable_8259

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
        mov edi, debug_handler
        call set_interrupt_handler


;; 设置 sysenter/sysexit 使用环境
        call set_sysenter

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
                  
                
        
;; 实验 13-3: 测试 general detect 与 single-step

; 1) 设置 DR7.GD 位
        mov eax, dr7
        bts eax, 13                     ; GD=1
        mov dr7, eax

; 2）置 TF=1        
        pushfd
        bts DWORD [esp], 8
        popfd

; 3) 产生 general detect        
        ;mov eax, dr6                    ; 1) 先触发 general detect 条件
                                         ; 2) 接着触发 single-step 条件

;; 测试二：
        mov eax, eax                     ; 插入多余的指令，导致 single-step 被触发
        mov eax, dr6                     ; 同时激发 single-step 与 general detect
        
        jmp $


        
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


;--------------------------------
; #DB handler
;--------------------------------
debug_handler:
        jmp do_debug_handler
debug_msg        db '---> now, enter #debug handler <---', 10, 0

do_debug_handler:        
        mov esi, debug_msg
        call puts
        call dump_dr6                     ; 打印 DR6 寄存器标志位
        mov eax, [esp]
        cmp WORD [eax], 0xfeeb              ; 测试 jmp $ 指令
        jne do_debug_handler_done
        btr DWORD [esp+8], 8                ; 清 TF
do_debug_handler_done:        
        bts DWORD [esp+8], 16               ; RF=1
        iret







        
;******** include 中断 handler 代码 ********
%include "..\common\handler32.asm"


;********* include 模块 ********************
%include "..\lib\creg.asm"
%include "..\lib\cpuid.asm"
%include "..\lib\msr.asm"
%include "..\lib\pci.asm"
%include "..\lib\debug.asm"
%include "..\lib\page32.asm"
%include "..\lib\apic.asm"
%include "..\lib\pic8259A.asm"


;;************* 函数导入表  *****************

; 这个 lib32 库导入表放在 common\ 目录下，
; 供所有实验的 protected.asm 模块使用

%include "..\common\lib32_import_table.imt"


PROTECTED_END: