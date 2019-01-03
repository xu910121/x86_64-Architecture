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


;; 实验ex20-6：测试进程切换中的x87 FPU延时切换

;; 设置 #NM handler
        mov esi, NM_HANDLER_VECTOR
        mov edi, nm_handler
        call set_interrupt_handler
        
;; 设置 x87 FPU 和 MMX 环境
        mov eax, cr0
        bts eax, 1              ; MP = 1
        btr eax, 2              ; EM = 0
        mov cr0, eax
                    
        finit
        fsave [task_image]
        fsave [task_image + 108]
        
; 设置 switch_to() 函数环境
        mov esi, 0x41
        mov edi, switch_to
        call set_user_interrupt_handler       
        
; 任务环境
        mov DWORD [task_context + 40 + CONTEXT_ESP], USER_ESP
        mov DWORD [task_context + 40 + CONTEXT_EIP], task_a
        mov DWORD [task_context + 40 + CONTEXT_VIDEO], 0xb8000
        mov DWORD [task_context + 40 * 2 + CONTEXT_ESP], USER_ESP
        mov DWORD [task_context + 40 * 2 + CONTEXT_EIP], task_b
        mov DWORD [task_context + 40 * 2 + CONTEXT_VIDEO], 0xb8000
       

; 产生进程换
        mov esi, TASK_ID_A      ; 切换到 task a
        int 0x41
        
        
        jmp $


task_link       dd 0, task_a, task_b, 0
task_id         dd 0

;; 两个 x87 FPU 状态 image
task_image: times (2 * 108) db 0

; integer 单元 context
task_context: times (3 * 10) dd 0

TASK_ID_A       equ 1
TASK_ID_B       equ 2


;------------------------------------
; switch_to(): 进程切换函数
; input:
;       esi: task ID
;------------------------------------
switch_to:
        jmp do_switch
smsg    db '---> now: switch to task ID: ', 0
temp_id dd 0
do_switch:        
        mov [temp_id], esi
        mov esi, [task_id]                              ; 原进程 ID
        lea esi, [esi * 4 + esi]
        lea esi, [esi * 8]                              ; esi * 40

; *** 保存旧进程 integer 单元 context
        mov [task_context + esi + CONTEXT_EAX], eax     ; 保存 eax 寄存器
        mov eax, [temp_id]
        mov [task_context + esi + CONTEXT_ESI], eax     ; 保存 esi 寄存器
        
;  判断权限
        mov eax, [esp + 4]                              ; 读取 CS selector
        and eax, 3                                      ; CS.RPL
        jz save_cpl0
        ; 发生权限改变
        mov eax, [esp + 12]                             ; esp
        mov [task_context + esi + CONTEXT_ESP], eax     ; 保存 esp
        jmp save_next
save_cpl0:        
        lea eax, [esp + 12]
        mov [task_context + esi + CONTEXT_ESP], eax     ; 保存 esp
save_next:        
        mov eax, [esp]                                  ; eip
        mov [task_context + esi + CONTEXT_EIP], eax     ; 保存 eip
        mov [task_context + esi + CONTEXT_ECX], ecx
        mov [task_context + esi + CONTEXT_EDX], edx
        mov [task_context + esi + CONTEXT_EBX], ebx
        mov [task_context + esi + CONTEXT_EBP], ebp
        mov [task_context + esi + CONTEXT_EDI], edi
        call get_video_current
        mov [task_context + esi + CONTEXT_VIDEO], eax
        
; 置进程 ID
        mov eax, [temp_id]
        mov DWORD [task_id], eax                        ; 当前进程（切换的目标进程）        
        
; 打印信息        
        mov esi, smsg
        call puts
        mov ebx, [task_id]
        mov esi, ebx
        call print_dword_decimal
        call println

        
; 置 TS 位
        mov eax, cr0
        bts eax, 3                                      ; TS = 1
        mov cr0, eax
      
      
     
; *** 加载目标进程 integer 单元 context

;  判断权限
        mov eax, [esp + 4]                              ; 读取 CS selector
        and eax, 3                                      ; CS.RPL
        mov eax, 20
        mov esi, 12
        cmovz eax, esi
        add esp, eax                                    ; 改写返回地址
        
; 切换到目标进程
        mov esi, ebx                                    ; 目标进程 ID                        
        lea esi, [esi * 4 + esi]
        lea esi, [esi * 8]                              ; esi * 40
        
        call get_video_current
        mov [task_context + esi + CONTEXT_VIDEO], eax        
        mov ebx, [task_context + esi + CONTEXT_ESP]
        mov eax, [task_context + esi + CONTEXT_EIP]
                
        push DWORD user_data32_sel | 0x3
        push ebx
        push DWORD 2
        push DWORD user_code32_sel | 0x3        
        push eax
        
        mov eax, esi
        mov esi, [task_context + esi + CONTEXT_VIDEO]   ; video_current
        test esi, esi
        jz load_next
        call set_video_current
load_next:        
        mov esi, eax
        mov eax, [task_context + esi + CONTEXT_EAX]
        mov ecx, [task_context + esi + CONTEXT_ECX]
        mov edx, [task_context + esi + CONTEXT_EDX]
        mov ebx, [task_context + esi + CONTEXT_EBX]
        mov ebp, [task_context + esi + CONTEXT_EBP]
        mov edi, [task_context + esi + CONTEXT_EDI]
        mov esi, [task_context + esi + CONTEXT_ESI]        
        
        iret

;-----------------------------------
; 进程 A
;----------------------------------
task_a:
        jmp do_task_a
a dd 0.25
b dd 1.5
amsg        db '<task A>:', 10, 0
result  dd 0
msg3    db ' + ', 0
msg4    db ' ) = ', 0

do_task_a:
        mov ax, user_data32_sel | 3
        mov ds, ax
        mov ss, ax
        mov es, ax
        
        mov esi, amsg
        call puts
        mov esi, '('
        call putc
        mov esi, a
        call print_dword_float
        mov esi, msg3
        call puts
        mov esi, b
        call print_dword_float
        mov esi, msg4
        call puts
        fld DWORD [a]
        fadd DWORD [b]   
         
        mov esi, TASK_ID_B
        int 0x41                                ; 发生进程切换，切换到 task b 
        
        fstp DWORD [result]
        mov esi, result
        call print_dword_float
        jmp $

;------------------------------------
; 进程 B
;-----------------------------------
task_b:
        jmp do_task_b
array   dd 1, 2, 3, 4, 5, 6, 7, 8        
fmsg    db '(1+2+3+4+5+6+7+8) = ', 0
fmsg1   db '<task B>:', 10, 0
do_task_b:      
        mov ax, user_data32_sel | 3
        mov ds, ax
        mov ss, ax
        mov es, ax
          
        push ebp
        mov ebp, esp
        sub esp, 8

        mov esi, fmsg1
        call puts
        movq mm0, [array]                       ; 12
        movq mm1, [array + 8]                   ; 34
        movq mm2, [array + 16]                  ; 56
        movq mm3, [array + 24]                  ; 78
        paddd mm0, mm1                          
        paddd mm2, mm3                          
        movq mm4, mm0
        punpckhdq mm4, mm2                       
        punpckldq mm0, mm2
        paddd mm0, mm4
        movq [esp], mm0
        mov esi, fmsg
        call puts
        mov esi, [esp]
        add esi, [esp + 4]
        call print_dword_decimal
        call println

; 切换回 task a        
        mov esi, TASK_ID_A 
        int 0x41
        
        mov esp, ebp
        pop ebp
        jmp $

;----------------------------------------------
; #NM handler
;----------------------------------------------
nm_handler:
        jmp do_nm_handler    
nmsg    db 10, '>>> now, enter the #NM handler', 10, 0
nmsg1   db 'exit the #NM handler <<<', 10, 0        
do_nm_handler:
        STORE_CONTEXT    
        mov esi, nmsg
        call puts

; 清 TS 标志位        
        clts
        
        ; 判断进程 ID
        mov eax, [task_id]
        cmp eax, TASK_ID_A
        je switch_task_a                ; 切换到 task A
        ;; 切换到 task B
        fsave [task_image]              ; 保存 task A 的 image
        frstor [task_image + 108]       ; 加载 task B 的 image
        jmp do_nm_handler_done
        
switch_task_a:
        fsave [task_image + 108]        ; 保存 task B 的 image
        frstor [task_image]             ; 加载 task A 的 image

do_nm_handler_done:        
        mov esi, nmsg1
        call puts
        RESTORE_CONTEXT
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

;;************* 函数导入表  *****************

; 这个 lib32 库导入表放在 common\ 目录下，
; 供所有实验的 protected.asm 模块使用

%include "..\common\lib32_import_table.imt"


PROTECTED_END: