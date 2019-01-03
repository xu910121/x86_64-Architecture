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
                  
;========= 初始化设置完毕 =================

        mov DWORD [PT1_BASE + 0 * 8 + 4], 0             ; 将 400000h 设置可执行

; 实验 14-4：过滤所有 jmp 指令分支记录

; 1)复制测试函数 func() 到 0x400000 地址上
        mov esi, func
        mov edi, 0x400000
        mov ecx, func_end - func
        rep movsb


; 2) 开启 LBR
        mov ecx, IA32_DEBUGCTL
        rdmsr
        bts eax, LBR_BIT                        ; 置 LBR 位
        wrmsr

; 3) 设置过滤条件

; 测试一（对所有的jmp过滤条件置位）
;        mov ecx, MSR_LBR_SELECT
;        xor edx, edx
;        mov eax, 0x1c4                        ; 过滤所有 jmp 指令
;        wrmsr

; 测试二（对所有的jmp过滤条件置位，除了 FAR_BRANCH)
        mov ecx, MSR_LBR_SELECT
        xor edx, edx
        mov eax, 0xc4                        ; 过滤所有 jmp 指令(除了 FAR_BRANCH)
        wrmsr
        
        
; 4) 测试函数

; 测试一（使用 near indirect call）
;        mov eax, 0x400000
;        call eax                                        ; 使用 near indirect call

; 测试二（使用 far call）
        call DWORD KERNEL_CS:0x400000

; 5) 清 LBR 
        mov ecx, IA32_DEBUGCTL
        rdmsr
        btr eax, LBR_BIT                        ; 清 LBR 位
        wrmsr


; 6) 输出 LBR stack 信息
        call dump_lbr_stack
        call println

        
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




;; 测试函数
func:
        mov eax, func_next-func+0x400000
        jmp eax                                        ; near indirect jmp
func_next:        
        call get_eip                                    ; near relative call
get_eip:
        pop eax        
        mov eax, 0
        mov esi, msg1                                   ; 空字符串
        int 0x40                                        ; 使用 int 来调用 system service
        ret
func_end:        

msg1        db 10, 0







        
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