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

;开启APIC
        call enable_xapic        

        ;*
        ;* perfmon 初始设置
        ;* 关闭所有 counter 和 PEBS 
        ;* 清 overflow 标志位
        ;*
        DISABLE_GLOBAL_COUNTER
        DISABLE_PEBS
        RESET_COUNTER_OVERFLOW       
        RESET_PMC
        

;========= 初始化设置完毕 =================


       
;;; 测试 bootstrap processor 还是 application processor ?
        mov ecx, IA32_APIC_BASE
        rdmsr
        bt eax, 8
        jnc ap_processor

;; ** 下面是 BSP 代码 ***


;设置 APIC performance monitor counter handler
        mov esi, APIC_PERFMON_VECTOR
        mov edi, apic_perfmon_handler
        call set_interrupt_handler

;  设置 APIC timer handler
        mov esi, APIC_TIMER_VECTOR
        mov edi, apic_timer_handler
        call set_interrupt_handler      
        
; 设置 LVT 寄存器
        mov DWORD [APIC_BASE + LVT_PERFMON], FIXED_DELIVERY | APIC_PERFMON_VECTOR
        mov DWORD [APIC_BASE + LVT_TIMER], TIMER_ONE_SHOT | APIC_TIMER_VECTOR

; 设置 AP IPI handler
        mov esi, 30h
        mov edi, ap_ipi_handler
        call set_interrupt_handler             
;*        
;* 复制 startup routine 代码到 20000h                
;* 以便于 AP processor 运行
;*
        mov esi, startup_routine
        mov edi, 20000h
        mov ecx, startup_routine_end - startup_routine
        rep movsb

        inc DWORD [processor_index]                             ; 增加 index 值
        inc DWORD [processor_count]                             ; 增加 logical processor 数量
        mov ecx, [processor_index]                              ; 取 index 值
        mov edx, [APIC_BASE + APIC_ID]                          ; 读 APIC ID
        mov [apic_id + ecx * 4], edx                            ; 保存 APIC ID 
;*
;* 分配 stack 空间
;*
        mov eax, PROCESSOR_STACK_SIZE                           ; 每个处理器的 stack 空间大小
        mul ecx
        mov esp, PROCESSOR_KERNEL_ESP
        add esp, eax  

; 设置 logical ID
        mov eax, 01000000h
        shl eax, cl
        mov [APIC_BASE + LDR], eax

        sti

        ; 提取 x2APIC ID
        call extrac_x2apic_id

        ;*
        ;* 下面发送 IPIs，使用 INIT-SIPI-SIPI 序列
        ;* 发送 SIPI 时，发送 startup routine 地址位于 200000h
        ;*

        mov DWORD [APIC_BASE + ICR0], 000c4500h                ; 发送 INIT IPI, 使所有 processor 执行 INIT
        DELAY
        DELAY
        mov DWORD [APIC_BASE + ICR0], 000C4620H                ; 发送 Start-up IPI
        DELAY
        mov DWORD [APIC_BASE + ICR0], 000C4620H                ; 再次发送 Start-up IPI
        DELAY        
        DELAY

;; 实验 18-9：使用 logical 目标模式发送 IPI 消息
        mov esi, bp_msg1
        call puts

        ; 下面是发送 IPI
        mov DWORD [APIC_BASE + ICR1], 0C000000h                 ; logical ID = 0Ch
        mov DWORD [APIC_BASE + ICR0], LOGICAL_ID | 30h          ;

        jmp $



; 下面是 APs 代码
ap_processor:       
        inc DWORD [processor_index]                             ; 增加 index 值
        inc DWORD [processor_count]                             ; 增加 logical processor 数量
        mov ecx, [processor_index]                              ; 取 index 值
        mov edx, [APIC_BASE + APIC_ID]                          ; 读 APIC ID
        mov [apic_id + ecx * 4], edx                            ; 保存 APIC ID 
;*
;* 分配 stack 空间
;*
        mov eax, PROCESSOR_STACK_SIZE                           ; 每个处理器的 stack 空间大小
        mul ecx                                                 ; stack_offset = STACK_SIZE * index
        mov esp, PROCESSOR_KERNEL_ESP
        add esp, eax  

; 设置 logical ID
        mov eax, 01000000h
        shl eax, cl
        mov [APIC_BASE + LDR], eax

        call extrac_x2apic_id
        lock btr DWORD [vacant], 0                          ; 释放 lock
        sti
        hlt
        
        jmp $


;*
;* 下面是 starup routine 代码
;* 引导 AP 处理器执行 setup模块，执行 protected 模块
;* 使所有 AP 处理器进入protected模式
;*
startup_routine:
        bits 16
        
        mov ax, 0
        mov ds, ax
        mov es, ax
        mov ss, ax

; 测试 lock，只允许 1 个 local processor 访问
test_ap_lock:        
        lock bts DWORD [vacant], 0
        jc get_ap_lock

        jmp WORD 0:SETUP_SEG                ; 进入实模式的 setup.asm 模块

get_ap_lock:
        jmp test_ap_lock

        bits 32
startup_routine_end: 

  



        jmp $

bp_msg1         db '<bootstrap processor>  : '
bp_msg2         db 'now, send IPIs with logical mode', 10, 10, 0

msg0    db '-------------------------------------------', 10, 0
msg1    db 'APIC ID: 0x', 0
msg2    db 'pkg_ID: 0x', 0
msg3    db 'core_ID: 0x', 0
msg4    db 'smt_ID: 0x', 0


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


;---------------------------------------------
; ap_ipi_handler()：这是 AP IPI handler
;---------------------------------------------
ap_ipi_handler:
	jmp do_ap_ipi_handler
at_msg2 db 10, 10, '>>>>>>> This is processor ID: ', 0
at_msg3 db '---------------------------------', 10, 0
at_msg4 db 'APIC ID:', 0
at_msg5 db 'LDR:', 0

do_ap_ipi_handler:	
        
        ; 测试 lock
test_handler_lock:
        lock bts DWORD [vacant], 0
        jc get_handler_lock

        mov esi, at_msg2
        call puts
        mov edx, [APIC_BASE + APIC_ID]        ; 读 APIC ID
        shr edx, 24
        mov esi, edx
        call print_dword_value
        call println
        mov esi, at_msg3
        call puts

        mov esi, at_msg4
        call puts
        mov esi, [APIC_BASE + APIC_ID]
        call print_dword_value
        call printblank

        mov esi, at_msg5
        call puts
        mov esi, [APIC_BASE + LDR]
        call print_dword_value
        call println

        mov DWORD [APIC_BASE + EOI], 0
        ; 释放lock
        lock btr DWORD [vacant], 0        
        iret

get_handler_lock:
        jmp test_handler_lock

	iret






%define APIC_PERFMON_HANDLER
%define APIC_TIMER_HANDLER

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