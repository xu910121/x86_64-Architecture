; lib16.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


%include "..\inc\lib.inc"
%include "..\inc\support.inc"

; ���� 16λʵģʽ��ʹ�õĿ⡣
; ʹ���� bios ���жϣ�So ������������� bios �ġ�
; �����ᱻ���ص��ڴ� 0x8c00 ��λ����

	bits 16


	org LIB16_SEG - 2					; ���ص� LIB16_SEG �Σ�ȥ����ģ�� size
	
begin	dw (end - begin)				; ģ�� size


; �����Ǻ�������ת��
; ������ģ����� lib16 ��ĺ���ʱ���Ȼ�ȡ�������ת���ַ
	
LIB16_FUNCTION_TABLE:

putc:					jmp 		WORD __putc
puts:					jmp 		WORD __puts
hex_to_char:			jmp			WORD __hex_to_char
get_hex_string:			jmp			WORD __get_hex_string
test_CPUID:				jmp			WORD __test_CPUID
get_dword_hex_string:	jmp			WORD __get_dword_hex_string
println:				jmp			WORD __println
get_DisplayFamily_DisplayModel:	jmp WORD __get_DisplayFamily_DisplayModel
clear_screen:			jmp			WORD __clear_screen




;------------------------------------------------------
; clear_screen()
; description:
;		clear the screen & set cursor position at (0,0)
;------------------------------------------------------
__clear_screen:
	pusha
	mov ax, 0x0600
	xor cx, cx
	xor bh, 0x0f						; white
	mov dh,	24
	mov dl, 79
	int 0x10
	
set_cursor_position:
	mov ah, 02
	mov bh, 0
	mov dx, 0
	int 0x10	
	popa
	ret
	

;--------------------------------
; putc(): ��ӡһ���ַ�
; input: 
;		si: char
;--------------------------------
__putc:
	push bx
	xor bh, bh
	mov ax, si
	mov ah, 0x0e		
	int 0x10
	pop bx
	ret

;--------------------------------
; println(): ��ӡ����
;--------------------------------
__println:
	mov si, 13
	call __putc
	mov si, 10
	call __putc
	ret

;--------------------------------
; puts(): ��ӡ�ַ�����Ϣ
; input: 
;		si: message
;--------------------------------
__puts:
	pusha
	mov ah, 0x0e
	xor bh, bh	

do_puts_loop:	
	lodsb
	test al,al
	jz do_puts_done
	int 0x10
	jmp do_puts_loop

do_puts_done:	
	popa
	ret	
	

;-----------------------------------------
; hex_to_char(): �� Hex ����ת��Ϊ Char �ַ�
; input:
;		si: Hex number
; ouput:
;		ax: Char
;----------------------------------------
__hex_to_char:
	jmp do_hex_to_char
@char	db '0123456789ABCDEF', 0

do_hex_to_char:	
	push si
	and si, 0x0f
	mov ax, [@char+si]
	pop si
	ret
	
;---------------------------------------------------
; get_hex_string(): ����(WORD)ת��Ϊ�ַ���
; input:
;		si: ��ת��������word size)
;		di: Ŀ�괮 buffer�������Ҫ 5 bytes������ 0)
;---------------------------------------------------
__get_hex_string:
	push cx
	push si
	mov cx, 4					; 4 �� half-byte
do_get_hex_string_loop:
	rol si, 4					; ��4λ --> �� 4λ
	call __hex_to_char
	mov byte [di], al
	inc di
	dec cx
	jnz do_get_hex_string_loop
	mov byte [di], 0
	pop si
	pop cx
	ret

;---------------------------------------------------
; get_dword_hex_string(): ���� (DWORD) ת��Ϊ�ַ���
; input:
;		esi: ��ת��������dword size)
;		di: Ŀ�괮 buffer�������Ҫ 9 bytes������ 0)
;---------------------------------------------------
__get_dword_hex_string:
	push cx
	push esi
	mov cx, 8					; 8 �� half-byte
do_get_dword_hex_string_loop:
	rol esi, 4					; ��4λ --> �� 4λ
	call __hex_to_char
	mov byte [di], al
	inc di
	dec cx
	jnz do_get_dword_hex_string_loop
	mov byte [di], 0
	pop esi
	pop cx
	ret

;---------------------------------------------------
; test_CPUID(): �����Ƿ�֧�� CPUID ָ��
; output:
;		1 - support,  0 - no support
;---------------------------------------------------
__test_CPUID:
	pushfd								; save eflags DWORD size
	mov eax, dword [esp]				; get old eflags
	xor dword [esp], 0x200000			; xor the eflags.ID bit
	popfd								; set eflags register
	pushfd								; save eflags again
	pop ebx								; get new eflags
	cmp eax, ebx						; test eflags.ID has been modify
	setnz al							; OK! support CPUID instruction
	movzx eax, al
	ret

;---------------------------------------------------------------------
; get_DisplayFamily_DisplayModel():	��� DisplayFamily �� DisplayModel	
; output:
;		ah: DisplayFamily,  al: DisplayModel
;--------------------------------------------------------------------
__get_DisplayFamily_DisplayModel:
	push ebx
	push edx
	push ecx
	mov eax, 01H
	cpuid
	mov ebx, eax
	mov edx, eax
	mov ecx, eax
	shr eax, 4
	and eax, 0x0f			; �õ� model ֵ
	shr edx, 8
	and edx, 0x0f			; �õ� family ֵ
	
	cmp edx, 0FH
	jnz test_family_06
	shr ebx, 20
	add edx, ebx			; �õ� DisplayFamily
	jmp get_displaymodel
test_family_06:	
	cmp edx, 06H
	jnz get_DisplayFamily_DisplayModel_done
get_displaymodel:	
	shr ecx, 12
	and ecx, 0xf0
	add eax, ecx			; �õ� DisplayModel
get_DisplayFamily_DisplayModel_done:	
	mov ah, dl
	pop ecx
	pop edx
	pop ebx
	ret

end:	