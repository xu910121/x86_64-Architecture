; page32.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\page.inc"


        bits 32

        
;-----------------------------------------
; void clear_4K_page()����4Kҳ��
; input:  
;                esi: address
;------------------------------------------        
clear_4k_page:
clear_4K_page:
        pxor xmm1, xmm1
        mov eax, 4096
clear_4K_page_loop:        
        movdqu [esi + eax - 16], xmm1
        movdqu [esi + eax - 32], xmm1
        movdqu [esi + eax - 48], xmm1
        movdqu [esi + eax - 64], xmm1
        movdqu [esi + eax - 80], xmm1
        movdqu [esi + eax - 96], xmm1
        movdqu [esi + eax - 112], xmm1
        movdqu [esi + eax - 128], xmm1
        sub eax, 128
        jnz clear_4K_page_loop
        ret

;------------------------------------------
; pag_enable(): ��ʼ�� PAE paging ģʽʹ�û���
;---------------------------------------------
pae_enable:
        mov eax, 1
        cpuid
        bt edx, 6                                       ; PAE support?
        jnc pae_enable_done
        mov eax, cr4
        bts eax, PAE_BIT                                ; CR4.PAE = 1
        mov cr4, eax
pae_enable_done:        
        ret

;-------------------------------------------------
; execution_disable_enable():
;-------------------------------------------------
execution_disable_enable:
        mov eax, 0x80000001
        cpuid
        bt edx, 20                                      ; XD support ?
        mov eax, 0
        jnc execution_disalbe_enable_done
        mov ecx, IA32_EFER
        rdmsr 
        bts eax, 11                                     ; EFER.NXE = 1
        wrmsr        
        mov eax, 80000000h
execution_disalbe_enable_done:        
        mov DWORD [xd_bit], eax                         ; д XD ��־λ
        ret


;------------------------------------------------
; execution disable_disalbe(): �ر� XD
;------------------------------------------------
execution_disable_disable:
        mov ecx, IA32_EFER
        rdmsr
        btr eax, 11
        wrmsr
        ret

;----------------------------------------------
; semp_enable(): ���� SEMP ����
;----------------------------------------------
smep_enable:
        mov eax, 07
        mov ecx, 0                                      ; sub leaf=0
        cpuid
        bt ebx, 7                                       ; SMEP suport ?
        jnc smep_enable_done
        mov eax, cr4
        bts eax, SMEP_BIT                               ; enable SMEP
        mov cr4, eax
smep_enable_done:        
        ret



;-----------------------------------------------------------
; init_pae_paging(): ��ʼ�� PAE paging ��ҳģʽ
;-----------------------------------------------------------
init_pae_paging:
; 1) 0x000000-0x3fffff ӳ�䵽 000000h page frame, ʹ�� 2�� 2M ҳ��
; 2) 0x400000-0x400fff ӳ�䵽 400000h page frame ʹ�� 4K ҳ��
; 3) 0x600000-0x7fffff ӳ�䵽 0FEC00000h �����ַ�ϣ�ʹ�� 2M ҳ��
; 4) 0x800000-0x9fffff ӳ�䵽 0FEE00000h �����ַ�ϣ�ʹ�� 2M ҳ��
;
;** 400000h ʹ���� DS save ����
;** 600000h ʹ���� LPC ������
;** 800000h ʹ���� local APIC ����
;

PDT_BASE        equ                PDPT_BASE + 0x1000
PT1_BASE        equ                PDT_BASE + 0x1000
PT2_BASE        equ                PDT_BASE + 0x2000
PT3_BASE        equ                PDT_BASE + 0x3000


;; ���ڴ�ҳ�棨���һ�����Ѳ�� bug��
        mov esi, PDPT_BASE
        call clear_4K_page
        mov esi, PDT_BASE
        call clear_4K_page
        mov esi, PT1_BASE
        call clear_4K_page
        mov esi, 110000h
        call clear_4K_page
        mov esi, 111000h
        call clear_4K_page
        mov esi, 112000h
        call clear_4K_page
        mov esi, 113000h 
        call clear_4K_page
        
        mov DWORD [pdpt_base], PDPT_BASE

;; 1) ���� PDPTE[0] 
        mov DWORD [PDPT_BASE + 0 * 8], PDT_BASE | P                                ; base=0x201000, P=1
        mov DWORD [PDPT_BASE + 0 * 8 + 4], 0

        mov DWORD [PDPT_BASE + 1 * 8], 110000h | P
        mov DWORD [PDPT_BASE + 1 * 8 + 4], 0

        mov DWORD [PDPT_BASE + 3 * 8], 111000h | P
        mov DWORD [PDPT_BASE + 3 * 8 + 4], 0

;; 2) ���� PDE[0], PDE[1] �Լ� PDE[2]
        ; PDE[0] ��Ӧ virtual address: 0x0 �� 0x1fffff (2Mҳ)
        ; PDE[1] ��Ӧ virtual address: 0x200000 �� 0x3fffff (2Mҳ��
        ; PDE[2] ��Ӧ virtual address: 0x400000 �� 0x400fff (4Kҳ��
        mov DWORD [PDT_BASE + 0 * 8], PS | RW | US | P                                ; base=0, PS=1
        mov DWORD [PDT_BASE + 0 * 8 + 4], 0
        mov DWORD [PDT_BASE + 1 * 8], 200000h | PS | P                                ; base=0x200000
        mov DWORD [PDT_BASE + 1 * 8 + 4], 0
        mov DWORD [PDT_BASE + 2 * 8], PT1_BASE | RW | US | P                        ; base=PT_BASE, PS=0
        mov DWORD [PDT_BASE + 2 * 8 + 4], 0
        
; 0x800000 ӳ�䵽 0xFEE00000(Local APIC ����)        
        mov DWORD [PDT_BASE + 4 * 8], 0xFEE00000 | PS | PCD | PWT | RW | P        ; PCD=1,PWT=1
        mov eax, [xd_bit]
        mov DWORD [PDT_BASE + 4 * 8 + 4], eax                                        ; XDλ
        
; 0x600000 ӳ�䵽 0xFEC00000(LPC��������
        mov DWORD [PDT_BASE + 3 * 8], 0xFEC00000 | PCD | PWT | PS | RW | P        ; PCD=1,PWT=1
        mov DWORD [PDT_BASE + 3 * 8 + 4], eax                                        ; XDλ        

        mov DWORD [110000h + 1FFh * 8], 112000h | RW | US | P
        mov DWORD [110000h + 1FFh * 8 + 4], eax

        ; virutal address 0FEC00000h ӳ�䵽�����ַ 0FEC00000h �ϣ�2M��
        mov DWORD [111000h + 1F6h * 8], 0FEC00000h | PS | PCD | PWT | RW | P
        mov DWORD [111000h + 1F6h * 8 + 4], eax

        mov DWORD [111000h + 1FFh * 8], 113000h | RW | P
        mov DWORD [111000h + 1FFh * 8 + 4], eax

;; 3) ���� PTE[0]
        ; PTE[0] ��Ӧ virtual address: 0x400000 �� 0x400fff (4Kҳ��
        mov DWORD [PT1_BASE + 0 * 8], 400000h | RW | P                                ; base=0x400000, P=1, R/W=1
        mov eax, [xd_bit]
        mov DWORD [PT1_BASE + 0 * 8 + 4], eax                                        ; ���� XD��λ
        
        ; virutal address 7FE00000h - 7FE03FFFh
        ; ӳ�䵽 500000h - 503FFFh
        ; ���� User stack ����
        mov DWORD [112000h], 500000h | RW | US | P                                ; ������ 0
        mov DWORD [112000h + 4], 0
        mov DWORD [112000h + 1 * 8], 501000h | RW | US | P                        ; ������ 1
        mov DWORD [112000h + 1 * 8 + 4], 0
        mov DWORD [112000h + 2 * 8], 502000h | RW | US | P                        ; ������ 2
        mov DWORD [112000h + 2 * 8 + 4], 0
        mov DWORD [112000h + 3 * 8], 503000h | RW | US | P                        ; ������ 3
        mov DWORD [112000h + 3 * 8 + 4], 0
        mov DWORD [112000h + 4 * 8], 510000h | RW | US | P
        mov DWORD [112000h + 4 * 8 + 4], 0
        
        ; virtual address 0FFE0000h - 0FFE07FFFh
        ; ӳ�䵽 504000h -
        ; ���� kernel stack �� �ж� stack
        mov DWORD [113000h], 504000h | RW | P                                        ; ������ 0
        mov DWORD [113000h + 4], 0
        mov DWORD [113000h + 1 * 8], 505000h | RW | P                                ; ������ 1
        mov DWORD [113000h + 1 * 8 + 4], 0
        mov DWORD [113000h + 2 * 8], 506000h | RW | P                                ; ������ 2
        mov DWORD [113000h + 2 * 8 + 4], 0
        mov DWORD [113000h + 3 * 8], 507000h | RW | P                                ; ������ 3
        mov DWORD [113000h + 3 * 8 + 4], 0

        ; �ж� stack
        mov DWORD [113000h + 4 * 8], 508000h | RW | P                                ; ������ 0
        mov DWORD [113000h + 4 * 8 + 4], 0
        mov DWORD [113000h + 5 * 8], 509000h | RW | P                                ; ������ 1
        mov DWORD [113000h + 5 * 8 + 4], 0
        mov DWORD [113000h + 6 * 8], 50A000h | RW | P                                ; ������ 2
        mov DWORD [113000h + 6 * 8 + 4], 0
        mov DWORD [113000h + 7 * 8], 50B000h | RW | P                                ; ������ 3
        mov DWORD [113000h + 7 * 8 + 4], 0
        ret


;-------------------------------------------
; dump_pae_page(): ��ӡ PAE paging ģʽҳת������Ϣ
; input:
;                esi: virtual address(linear address)
; ע�⣺
;                �����������һ��һӳ�������£�virtual address��physical address һ�£�
;-------------------------------------------
dump_pae_page:
        push ecx
        push edx
        push ebx
        mov DWORD [pdpt_base], PDPT_BASE
        call get_maxphyaddr_select_mask
        mov ecx, esi
; ��� PDPTE
        mov esi, pdpte_msg
        call puts
        mov eax, ecx
        shr eax, 30
        and eax, 0x3
        mov edi, [PDPT_BASE + eax * 8 + 4]
        mov esi, [PDPT_BASE + eax * 8]        
        mov edx, esi
        mov ebx, edi
        bt edx, 0
        jc pdpte_next
        mov esi, not_available
        call puts
        call println
        jmp dump_pae_page_done
pdpte_next:
        and esi, [maxphyaddr_select_mask]
        and esi, 0xfffff000
        and edi, [maxphyaddr_select_mask + 4]
        mov [pdt_base], esi
        mov [pdt_base + 4], edi
        call print_qword_value
        call printblank
        mov esi, attr_msg
        call puts
        mov esi, edx
        shl esi, 19
        call reverse
        mov esi, eax
        mov edi, pdpte_pae_flags
        call dump_flags
        call println
        mov eax, [maxphyaddr_select_mask + 4]   ; select mask ��λ
        not eax
        test ebx, eax                           ; ����32λ����λ�Ƿ�Ϊ 0
        jnz print_reserved_error
        test edx, 1E6h                          ; ����32λ����λ�Ƿ�Ϊ 0 
print_reserved_error:
        mov esi, 0
        mov edi, reserved_error
        cmovnz esi, edi
        call puts

; ��� PDE        
        mov esi, pde_msg
        call puts
        mov eax, ecx
        and eax, 0x3fe00000
        shr eax, 21
        mov ebx, [pdt_base]
        mov edi, [ebx + eax * 8 + 4]
        mov esi, [ebx + eax * 8]        
        mov edx, esi
        mov ebx, edi
        bt edx, 0
        jc pde_next
        mov esi, not_available
        call puts
        call println
        jmp dump_pae_page_done
pde_next:        
        bt edx, 7                                                ; PS=1 ?
        jnc dump_pae_4k_pde
        and esi, [maxphyaddr_select_mask]
        and esi, 0xffe00000
        and edi, [maxphyaddr_select_mask + 4]
;        and edi, 0x7fffffff                                ; ��XDλ
        call print_qword_value
        call printblank
        mov esi, attr_msg
        call puts
        mov esi, edx
;        shl esi, 19
        ;; �¼��� xd ��־
        shl esi, 18
        btr esi, 31
        and ebx, 0x80000000
        or esi, ebx     
        call reverse
        mov esi, eax
        mov edi, pde_pae_2m_flags
        call dump_flags
        call println
        test edx, 0FE000h                       ; ��Ᵽ��λ�Ƿ�Ϊ 0
        mov esi, 0
        mov edi, reserved_error
        cmovnz esi, edi
        call puts
        jmp dump_pae_page_done                                
dump_pae_4k_pde:                
        and esi, 0xfffff000
        and edi, 0x7fffffff
        mov [pt_base], esi
        mov [pt_base + 4], edi
        call print_qword_value
        call printblank
        mov esi, attr_msg
        call puts
        mov esi, edx
;        shl esi, 19        
        ;�¼���xd��־
        shl esi, 18
        btr esi, 31
        and ebx, 0x80000000
        or esi, ebx
        
        call reverse
        mov esi, eax
        mov edi, pde_pae_4k_flags
        call dump_flags
        call println
;; ��� pte        
        mov esi, pte_msg
        call puts
        mov eax, ecx
        and eax, 0x1ff000
        shr eax, 12
        mov ebx, [pt_base]
        mov edi, [ebx + eax * 8 + 4]
        mov esi, [ebx + eax * 8]        
        mov edx, esi
        mov ebx, edi
        bt edx, 0
        jc pte_next
        mov esi, not_available
        call puts
        call println
        jmp dump_pae_page_done
pte_next:        
        and esi, 0xfffff000
        and edi, 0x7fffffff
        call print_qword_value
        call printblank
        mov esi, attr_msg
        call puts
        mov esi, edx
;        shl esi, 19        
        ; �¼��� xd ��־
        shl esi, 18
        btr esi, 31
        and ebx, 0x80000000
        or esi, ebx
        
        call reverse
        mov esi, eax
        mov edi, pte_pae_4k_flags
        call dump_flags
        call println        
dump_pae_page_done:        
        pop ebx
        pop edx
        pop ecx
        ret

;-------------------------------------------
; dump_page(): ��ӡҳת������Ϣ
; input:
;                esi: virtual address(linear address)
; ע�⣺
;                �����������һ��һӳ�������£�virtual address��physical address һ�£�
;-------------------------------------------        
dump_page:
        push ecx
        push edx
        mov ecx, esi
        mov esi, pde_msg
        call puts
        mov esi, ecx
        call __get_32bit_paging_pde_index
        mov eax, [PDT32_BASE + eax * 4]
        mov edx, eax
        bt eax, 7                                        ; PS = ?
        jnc dump_4k_page
;; ��� 4M ҳ��� PDE
        mov edi, eax
        mov esi, eax
        and esi, 0xffc00000                        ; 4M page frame
        shr edi, 13                                        ; base[39:32]
        and edi, 0xff                                ; base[39:32]
        call print_qword_value
        call printblank
        mov esi, attr_msg
        call puts
        mov esi, edx
        shl esi, 19
        call reverse
        mov esi, eax
        mov edi, pde_4m_flags
        call dump_flags
        call println
        jmp do_dump_page_done

dump_4k_page:        
;; 4Kҳ��

; 1) PDE
        mov esi, edx
        and esi, 0xfffff000
        mov [pt_base], esi
        mov edi, 0
        call print_qword_value
        call printblank
        mov esi, attr_msg
        call puts
        mov esi, edx
        shl esi, 19
        call reverse
        mov esi, eax
        mov edi, pde_4k_flags
        call dump_flags
        call println
;; 2) PTE
        mov esi, pte_msg
        call puts
        mov esi, ecx
        call __get_32bit_paging_pte_index
        lea eax, [eax * 4]
        add eax, [pt_base]
        mov ecx, [eax]
        mov esi, ecx
        and esi, 0xfffff000
        mov edi, 0
        call print_qword_value
        call printblank
        mov esi, attr_msg
        call puts
        mov esi, ecx
        shl esi, 19
        call reverse
        mov esi, eax
        mov edi, pte_4k_flags
        call dump_flags
        call println
do_dump_page_done:        
        pop edx
        pop ecx
        ret        

;---------------------------------------------------------------------
; get_32bit_paging_pte_index(): �õ�32-bit pagingģʽ�µ� pte index ֵ
; input:
;                esi: virtual address
; output:
;                eax: pte index
;--------------------------------------------------------------------
__get_32bit_paging_pte_index:
        mov eax, esi
        and eax, 0x3ff000
        shr eax, 12
        ret

;---------------------------------------------------------------------
; get_32bit_paging_pde_index(): �õ�32-bit pagingģʽ�µ� pde index ֵ
; input:
;                esi: virtual address
; output:
;                eax: pde index
;--------------------------------------------------------------------
__get_32bit_paging_pde_index:
        mov eax, esi
        and eax, 0xffc00000
        shr eax, 22
        ret        



;-----------------------------------------------------------------
; get_maxphyaddr_select_mask(): ������ MAXPHYADDR ֵ�� SELECT MASK
; output:
;       rax-maxphyaddr select mask
; ������
;       select mask ֵ����ȡ�� MAXPHYADDR ��Ӧ�������ֵַ
; ���磺
;       MAXPHYADDR = 36 ʱ: select mask = 0000000F_FFFFFFFFh
;       MAXPHYADDR = 40 ʱ: select mask = 000000FF_FFFFFFFFh
;       MAXPHYADDR = 52 ʱ��select mask = 000FFFFF_FFFFFFFFh
;-----------------------------------------------------------------
get_maxphyaddr_select_mask:
        push ecx
        push edx
        call get_maxphyaddr                     ; �õ� MAXPHYADDR ֵ
        lea ecx, [eax - 64]
        neg ecx
        mov eax, 0
        mov edx, -1
        cmp ecx, 32                             ; ����Ϊ 32 λ
        cmove edx, eax
        shl edx, cl
        shr edx, cl                            ; ȥ����λ
        mov eax, -1
        mov [maxphyaddr_select_mask], eax
        mov [maxphyaddr_select_mask + 4], edx
        pop edx
        pop ecx
        ret



;------------ ������ ------------

;; XD�Ѿ�������־λ
xd_bit  dd 0

maxphyaddr_select_mask  dq 0

;********* page table base *******
pml4t_base      dq 0
pdpt_base       dq 0
pdt_base        dq 0
pt_base         dq 0

pml4t_msg       db 'PML4T: base=0x', 0
pdpte_msg       db 'PDPTE: base=0x', 0
pde_msg         db 'PDE:   base=0x', 0
pte_msg         db 'PTE:   base=0x', 0
attr_msg        db 'Attr: ',0

not_available   db '***  not available (P=0)', 0
reserved_error  db '       <ERROR: reserved bit is not zero!>', 10, 0
                
;********* entry flags **********        

p_flags         db 'p',0
rw_flags        db 'r/w',0
us_flags        db 'u/s',0
pwt_flags       db 'pwt', 0
pcd_flags       db 'pcd', 0
a_flags         db 'a',0
d_flags         db 'd', 0
ps_flags        db 'ps',0
g_flags         db 'g',0
pat_flags       db 'pat',0
ignore_flags    db '-',0
blank_flags     db '   ', 0
reserved_flags  db '0', 0
xd_flags        db 'xd', 0

;************ flags ***********
pdpte_pae_flags         dd blank_flags, ignore_flags, ignore_flags, ignore_flags, reserved_flags, reserved_flags
                        dd reserved_flags, reserved_flags, pcd_flags, pwt_flags, reserved_flags, reserved_flags
                        dd p_flags, -1
pde_pae_2m_flags        dd xd_flags                                                
pde_4m_flags            dd pat_flags, ignore_flags, ignore_flags, ignore_flags, g_flags, ps_flags
                        dd d_flags, a_flags, pcd_flags, pwt_flags, us_flags, rw_flags, p_flags, -1
pde_pae_4k_flags        dd xd_flags        
pde_4k_flags            dd blank_flags, ignore_flags, ignore_flags, ignore_flags, ignore_flags, ps_flags
                        dd ignore_flags, a_flags, pcd_flags, pwt_flags, us_flags, rw_flags, p_flags, -1
pte_pae_4k_flags        dd xd_flags
pte_4k_flags            dd blank_flags, ignore_flags, ignore_flags, ignore_flags, g_flags, pat_flags
                        dd d_flags, a_flags, pcd_flags, pwt_flags, us_flags, rw_flags, p_flags, -1