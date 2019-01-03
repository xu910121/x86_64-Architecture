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


;开启APIC
        call enable_xapic        
        

;========= 初始化设置完毕 =================


;;; 实验 18-06：枚举所有的processor和APIC ID值
        
;;; 测试 bootstrap processor 还是 application processor ?
        mov ecx, IA32_APIC_BASE
        rdmsr
        bt eax, 8
        jnc ap_processor

;; ** 下面是 BSP 代码 ***

        ;*
        ;* perfmon 初始设置
        ;* 关闭所有 counter 和 PEBS 
        ;* 清 overflow 标志位
        ;*
        DISABLE_GLOBAL_COUNTER
        DISABLE_PEBS
        RESET_COUNTER_OVERFLOW       
        RESET_PMC

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


;*        
;* 复制 startup routine 代码到 20000h                
;* 以便于 AP processor 运行
;*
        mov esi, startup_routine
        mov edi, 20000h
        mov ecx, startup_routine_end - startup_routine
        rep movsb


;*
;* 增加处理器编号计数
;* BSP 处理器为 processor #0
;*
        inc DWORD [processor_index]                             ; 增加 index 值
        inc DWORD [processor_count]                             ; 增加 logical processor 数量
        mov ecx, [processor_index]                              ; 处理器 index 值
        mov edx, [APIC_BASE + APIC_ID]                          ; 读取 APIC ID 值
        mov [apic_id + ecx * 4], edx                            ; 保存 APIC ID

;*
;* 分配 stack 空间
;*
;* 分配方法：
;       1) 每个处理器的 idedx * STACK_SIZE 得到 stack_offset
;       2) stack_offset 加上 stack_base 值
;
        mov eax, PROCESSOR_STACK_SIZE                           ; 每个处理器的 stack 空间大小
        mul ecx                                                 ; stack_offset = STACK_SIZE * index
        mov esp, PROCESSOR_KERNEL_ESP + PROCESSOR_STACK_SIZE    ; stack 基值
        add esp, eax                                            ; stack_base + stack_offset

        mov esi, bp_msg1
        call puts
        mov esi, msg
        call puts
        mov esi, edx
        call print_dword_value
        call println
        mov esi, bp_msg2
        call puts

                  
;*
;* 开放 lock 信号
;*
        mov DWORD [vacant], 0                                   ; lock 


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

        ;* 等所有 AP 完成
test_ap_done:
        cmp DWORD [ap_done], 1
        jne get_ap_done
        mov DWORD [APIC_BASE + TIMER_ICR], 100                  ; 开启 apic timer
        hlt
        jmp $

get_ap_done:
        jmp test_ap_done

        jmp $



; 下面是 APs 代码
ap_processor:        

;*
;* 关闭计数器，收集数据
;*
        DISABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR2_EN)

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
        mov esp, PROCESSOR_KERNEL_ESP                           ; stack 基值
        add esp, eax                                            ; stack_base + stack_offset


        ;* 打印信息
        mov esi, ap_msg1
        call puts
        mov esi, ecx
        call print_dword_decimal
        mov esi, ap_msg2
        call puts

        mov esi, edx
        call print_dword_value
        mov esi, ','
        call putc
        call printblank

; 打印指令数
        mov esi, msg2
        call puts
        mov ecx, IA32_FIXED_CTR0
        rdmsr
        mov esi, eax
        call print_dword_decimal
        mov esi, ','
        call putc
        call printblank

; 打印 clocks 值       
        mov esi, msg1
        call puts
        mov ecx, IA32_FIXED_CTR2
        rdmsr
        mov esi, eax
        mov edi, edx
        call print_qword_value
        call println

; 所有 AP 完成工作
        xor eax, eax
        cmp DWORD [processor_index], 3
        setae al
        mov [ap_done], eax

        lock btr DWORD [vacant], 0                          ; 释放 lock
        cli
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

;*
;* **** 开启计数器 ****
;* 统计每个 AP 处理器从等待到完成初始化，所使用指令和 cloks数
;*
        mov ecx, IA32_FIXED_CTR_CTRL
        mov eax, 0B0Bh
        mov edx, 0
        wrmsr
        ENABLE_COUNTER 0, (IA32_FIXED_CTR0_EN | IA32_FIXED_CTR2_EN)


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

       
ap_done         dd 0

bp_msg1         db '<bootstrap processor>: ', 0
bp_msg2         db 'now, sent all processor IPIs...', 10, 10, 0
ap_msg1         db '<Processor #', 0
ap_msg2         db '>: ', 0
msg             db 'APIC ID: ', 0
msg1            db 'clocks:', 0
msg2            db 'instructions:', 0

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
; apic_timer_handler()：这是 APIC TIMER 的 ISR
;---------------------------------------------
apic_timer_handler:
        jmp do_apic_timer_handler
at_msg2 db        10, '--------- summary -------------', 10
        db        'processor: ', 0
at_msg3 db        'APIC ID : ', 0
do_apic_timer_handler:        
        mov esi, at_msg2
        call puts
        mov ebx, [processor_count]
        mov esi, ebx
        call print_dword_decimal
        call println
        mov esi, at_msg3
        call puts
        xor ecx, ecx

at_loop:
        mov esi, [apic_id + ecx * 4]
        call print_dword_value
        mov esi, ','
        call putc
        inc ecx
        cmp ecx, ebx
        jb at_loop

        mov DWORD [APIC_BASE + EOI], 0
        iret




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