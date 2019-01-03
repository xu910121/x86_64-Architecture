; hpet.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.



;------------------------------------
; enable_hpet(): ���� HPET���߾��ȶ�ʱ����
;------------------------------------
enable_hpet:
      
;* 
;* ��ȡ HPET ���üĴ���
;* Address Enable λ��λ������ HPET ��ַ
;* Address Select ������Ϊ 00B��HPET ��ַλ�� 0FED00000h
;
        call get_root_complex_base_address
        mov esi, [eax + 3404h]
        bts esi, 7                      ; address enable λ
        and esi, 0FFFFFFFCh             ; address select = 00B
        mov [eax + 3404h], esi
;*
;* ���� HPET �����üĴ���
;*
;* legacy replacement rout = 1 ʱ:
;*      1. timer0 ת���� IOAPIC IRQ2
;*      2. timer1 ת���� IOAPIC IRQ8
;*
;* overall enable ������Ϊ 1
;*
        mov eax, 3                      ; Overall Enable = 1, legacy replacement rout = 1
        mov [HPET_BASE + 10h], eax

;*
;* ��ʼ�� HPET timer ����
;*
        call init_hpet_timer
        ret


;------------------------------------------
; init_hpet_timer(): ��ʼ�� 8 �� timer
;------------------------------------------
init_hpet_timer:
;*
;* HPET ����˵��:
;*
;* 1). timer 0 ���� routed �� IO APIC �� IRQ2 ��
;* 2). timer 1 ���� routed �� IO APIC �� IRQ8 ��
;* 3). timer 2, 3 ���� routed �� IO APIC �� IRQ20 ��
;* 4). timer 4, 5, 6, 7 ����ʹ�� direct processor message ��ʽ
;*    ������ routed �� 8259 �� IO APIC �� IRQ
;*

        ;*
        ;* timer 0 ����Ϊ���������ж�, 64 λ�� comparator ֵ
        ;*
        mov DWORD [HPET_TIMER0_CONFIG], 0000004Ch
        mov DWORD [HPET_TIMER0_CONFIG + 4], 0
        mov DWORD [HPET_TIMER1_CONFIG], 00000004h
        mov DWORD [HPET_TIMER1_CONFIG + 4], 0
        mov DWORD [HPET_TIMER2_CONFIG], 00002804h
        mov DWORD [HPET_TIMER2_CONFIG + 4], 0
        mov DWORD [HPET_TIMER3_CONFIG], 00002804h
        mov DWORD [HPET_TIMER3_CONFIG + 4], 0
        ret



;--------------------------------------------
; dump_hpet_capabilities(): ��� HPET ������Ϣ
;--------------------------------------------
dump_hpet_capabilities:
        push ebx
        push edx
        mov ebx, [HPET_BASE + 0h]
        mov edx, [HPET_BASE + 4h]
        mov esi, counter_period_msg
        call puts
        mov esi, edx
        call print_dword_decimal
        call println
        mov esi, interrupt_rout_msg
        call puts
        bt ebx, 15
        mov esi, yes
        mov edi, no
        cmovnc esi, edi
        call puts
        mov esi, counter_size_msg
        call puts
        bt ebx, 13
        mov esi, yes
        mov edi, no
        cmovnc esi, edi
        call puts
        mov esi, timer_number_msg
        call puts
        shr ebx, 8
        and ebx, 01Fh
        lea esi, [ebx + 1]
        call print_dword_decimal
        pop edx
        pop ebx
        ret


counter_period_msg      db 'counter period:       ', 0
interrupt_rout_msg      db 'interrupt rout:       ', 0
counter_size_msg        db 'counter size(64 bit): ', 0
timer_number_msg        db 'number of timer:      ', 0

