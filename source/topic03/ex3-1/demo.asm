; demo.asm
; Copyright (c) 2009-2012 mik 
; All rights reserved.


; ʵ��2-1:
; ����һ�� 1.44M �� floppy ӳ���ļ�����Ϊ��demo.img
;
; �������nasm demo.asm -o demo.img




;
; �� 0 ���� 1.44M floppy �Ŀռ�

times 0x168000-($-$$) db 0