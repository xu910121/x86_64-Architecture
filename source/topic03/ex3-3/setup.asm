; boot.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


; ����һ���հ�ģ��ʾ������Ϊ setup ģ��
; ����д����̵ĵ� 2 ������ ��
;

%include "..\inc\support.inc"

;
; ģ�鿪ʼ���� SETUP_SEG - 2���� 2 ����ΪҪ����ģ��ͷ�Ĵ�ŵġ�ģ�� size��
; load_module ���ص� SETUP_SEG-2��ʵ��Ч���� SETUP ģ��ᱻ���ص�����ڵ㡱����setup_entry
;
	org SETUP_SEG - 2
	
;
; ��ģ��Ŀ�ͷ word ��С����������ģ��Ĵ�С��
; load_module �������� size ����ģ�鵽�ڴ�

SETUP_BEGIN:

setup_length	dw (SETUP_END - SETUP_BEGIN)				; SETUP_END-SETUP_BEGIN �����ģ��� size


setup_entry:												; ����ģ��������ڵ㡣	


message		db 'the message from setup module at sector 20...', 13, 10, 0

	
times 512-($-$$) db 0


SETUP_END:

; end of setup	