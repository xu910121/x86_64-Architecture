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
                  
                
        
;; 实验 13-9：测试数据断点

; 1) 开启 CR4.DE
	mov eax, cr4
	bts eax, DE_BIT
	mov cr4, eax
	
;2) 设置I/O断点 enable 位
	mov eax, dr7
	or eax, 0xE0001					; L0=1, R/W0=10B, LEN0=11B
	mov dr7, eax

;3) 设置 I/O断点
	mov eax, 0x93
	mov dr0, eax

	
; 4) 测试 I/O 断点
	in al, 0x92

; 5) 测试 ins 指令
;	mov dx, 0x90
;	mov ecx, 4
;	rep insb
        
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
dh_msg1	db '>>> now, enter #DB handler', 10, 0
dh_msg2	db 'now, exit #DB handler <<<', 10, 0	
dh_msg3	db 'read 92 port(Byte): 0x',0
do_debug_handler:
	push ecx
	movzx ecx, al
	mov esi, dh_msg1
	call puts
	call dump_drs				; 打印 DR0-DR3
	call dump_dr6				; 打印 DR6
	call dump_dr7				; 打印 DR7
	mov esi, dh_msg3
	call puts
	mov esi, ecx
	call print_byte_value
	call println
	mov esi, dh_msg2
	call puts
	pop ecx
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