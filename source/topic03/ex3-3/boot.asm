; boot.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


;
; ����������: nasm boot.asm -o boot (��floppy����)
;			  nasm boot.asm -o boot -d UBOOT (��U������)
; ���� boot ģ��Ȼ��д�� demo.img������ӳ�񣩵ĵ� 0 ����(MBR)


%include "..\inc\support.inc"
%include "..\inc\ports.inc"

	bits 16

;--------------------------------------
; now, the processor is real mode
;--------------------------------------	
	
; Int 19h ���� sector 0 (MBR) ���� BOOT_SEG ��, BOOT_SEG ����Ϊ 0x7c00
 	
	org BOOT_SEG
	
start:
	cli

; enable a20 line
	FAST_A20_ENABLE
	
	sti
	
; set BOOT_SEG environment
	mov ax, cs
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov sp, BOOT_SEG			; �� stack ��Ϊ BOOT_SEG
	
	call clear_screen
	mov si, hello
	call print_message
	
	mov si, 20						; setup ģ���ڵ�20��������
	mov di, SETUP_SEG - 2
	call load_module				; ʹ�� load_module() ���������
	
	mov si, SETUP_SEG
	call print_message
	
	mov si, word [load_message_table + eax * 2]
	call print_message
	
next:	
	jmp $
	
	
;------------------------------------------------------
; clear_screen()
; description:
;		clear the screen & set cursor position at (0,0)
;------------------------------------------------------
clear_screen:
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
; print_message()
; input: 
;		si: message
;--------------------------------
print_message:
	pusha
	mov ah, 0x0e
	xor bh, bh	

do_print_message_loop:	
	lodsb
	test al,al
	jz do_print_message_done
	int 0x10
	jmp do_print_message_loop

do_print_message_done:	
	popa
	ret

;--------------------------
; dot(): ��ӡ��
;--------------------------
dot:	
	push ax
	push bx
	mov ah, 0x0e
	xor bh, bh
	mov al, '.'
	int 0x10		
	pop bx
	pop ax
	ret
	
	
;-------------------------------------------------------
; LBA_to_CHS(): LBA mode converting CHS	mode for floppy 
; input:
;		ax - LBA sector
; output:
;		ch - cylinder
;		cl - sector (1-63)
;		dh - head	
;-------------------------------------------------------
LBA_to_CHS:
	mov cl, SPT
	div cl							; al = LBA / SPT, ah = LBA % SPT
; cylinder = LBA / SPT / HPC
	mov ch, al
	shr ch, (HPC / 2)				; ch = cylinder
; head = (LBA / SPT ) % HPC
	mov dh, al
	and dh, 1						; dh = head
; sector = LBA % SPT + 1
	mov cl, ah
	inc cl							; cl = sector
	ret


;--------------------------------------------------------
; check_int13h_extension(): �����Ƿ�֧�� int13h ��չ����
; ouput:
;		0 - support, 1 - not support
;--------------------------------------------------------
check_int13h_extension:
	push bx
	mov bx, 0x55aa
	mov ah, 0x41
	int 0x13
	setc al									; ʧ��
	jc do_check_int13h_extension_done
	cmp bx, 0xaa55
	setnz al								; ��֧��
	jnz do_check_int13h_extension_done
	test cx, 1
	setz al									; ��֧����չ���ܺţ�AH=42h-44h,47h,48h
do_check_int13h_extension_done:	
	pop bx
	movzx ax, al
	ret
	
;--------------------------------------------------------------
; read_sector_extension(): ʹ����չ���ܶ�����	
; input:
;		si - sector
;		di - buf (es:di)
;----------------------------------------------------------------------
read_sector_extension:
	xor eax, eax
	movzx esi, si
	push eax
	push esi					; Ҫ���������� (LBA) - 64 λֵ
	push es
	push di						; buf ������ es:di - 32 λֵ
	push word 0x01				; ������, word
	push word 0x10				; �ṹ�� size, 16 bytes
	
	mov ah, 0x42				; ��չ���ܺ�
%ifdef UBOOT
	mov dl, 0x80
%else
	mov dl, 0
%endif		
	mov si, sp					; ����ṹ���ַ
	int 0x13	
	add sp, 0x10
	ret
	
	
;----------------------------------------------------------------------	
; read_sector(int sector, char *buf): read one floppy sector(LBA mode)
; input:  
;		si - sector
;		di - buf
;----------------------------------------------------------------------
read_sector:
	pusha
	push es
	push ds
	pop es

; �����Ƿ�֧�� int 13h ��չ����
	call check_int13h_extension
	test ax, ax
	jz do_read_sector_extension		; ֧��

	mov bx, di						; data buffer
	mov ax, si						; disk sector number
; now: LBA mode --> CHS mode	
	call LBA_to_CHS
; now: read sector	
%ifdef UBOOT
	mov dl, 0x80					; for U �̻���Ӳ��
%else	
	mov dl, 0						; for floppy
%endif
	mov ax, 0x201
	int 0x13
	setc al							; 0: success  1: failure	
	jmp do_read_sector_done

; ʹ����չ���ܶ�����
do_read_sector_extension:
	call read_sector_extension
	mov al, 0
	
do_read_sector_done:	
	pop es
	popa
	movzx ax, al
	ret
	

;-------------------------------------------------------------------
; load_module(int module_sector, char *buf):  ����ģ�鵽 buf ������
; input:
;		si: module_sector ģ�������
;		di: buf ������
; example:
;		load_module(SETUP_SEG, SETUP_SECTOR);
;-------------------------------------------------------------------
load_module:
	call read_sector    				; read_sector(sector, buf)
	test ax, ax
	jnz do_load_module_done
	
	mov cx, [di]						; ��ȡģ�� size
	test cx, cx
	setz al
	jz do_load_module_done
	add cx, 512 - 1
	shr cx, 9							; ���� block��sectors��
  
do_load_module_loop:  
	call dot
	dec cx
	jz do_load_module_done 
	inc si
	add di, 0x200
	call read_sector
	test ax, ax
	jz do_load_module_loop

do_load_module_done:  
	ret




hello db 'hello, world', 13, 10, 0

read_sector_failure		db 'failure: read sector from '
%ifdef UBOOT
						db 'U drive or Hard disk'
%else
						db 'floppy'
%endif								
						db 13, 10, 0
	
read_sector_success		db 'success: read sector from '
%ifdef UBOOT
						db 'U drive or Hard disk'
%else
						db 'floppy'
%endif								
						db 13, 10, 0

load_module_success		db 'success: load module from '
%ifdef UBOOT
						db 'U drive or Hard disk'
%else
						db 'floppy'
%endif								
						db 13, 10, 0						

load_module_failure		db 'failure: load module from '
%ifdef UBOOT
						db 'U drive or Hard disk'
%else
						db 'floppy'
%endif								
						db 13, 10, 0
												
message_table			dw	read_sector_success, read_sector_failure, 0
load_message_table		dw  load_module_success, load_module_failure, 0

							
times 510-($-$$) db 0
	dw 0xaa55
