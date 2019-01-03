; clib.inc
; Copyright (c) 2009-2012 mik 
; All rights reserved.


; ���� conforming ���ͷ�ļ�


%ifndef CLIB_INC
%define CLIB_INC


%define CLIB32_SERVICE_USER             10
%define CLIB32_SERVICE_USER0            (CLIB32_SERVICE_USER)
%define CLIB32_SERVICE_USER1            (CLIB32_SERVICE_USER + 1)
%define CLIB32_SERVICE_USER2            (CLIB32_SERVICE_USER + 2)
%define CLIB32_SERVICE_USER3            (CLIB32_SERVICE_USER + 3)
%define CLIB32_SERVICE_USER4            (CLIB32_SERVICE_USER + 4)



%define CLIB32_GET_CPL                  0
%define CLIB32_GET_DPL                  1
%define CLIB32_GET_GDT_LIMIT            2
%define CLIB32_GET_LDT_LIMIT            3
%define CLIB32_CHECK_NULL_SELECTOR      4
%define CLIB32_LOAD_SS_REG              5




;*
;* ���� clib32 ��� get_cpl() ���� **
;*
%macro CLIB32_GET_CPL_CALL 0
        mov eax, CLIB32_GET_CPL
        call clib32_service_enter
%endmacro


; ���� load_ss_reg() ����
%macro CLIB32_LOAD_SS_REG 0
        mov eax, CLIB32_LOAD_SS_REG
        call clib32_service_enter
%endmacro

%endif