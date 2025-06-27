; ============================================================================
;        __
;   \\__/ o\    (C) 2025  Robert Finch, Waterloo
;    \  __ /    All rights reserved.
;     \/_//     robfinch<remove>@opencores.org
;       ||
;  
;
; BSD 3-Clause License
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, this
;    list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its
;    contributors may be used to endorse or promote products derived from
;    this software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;                                                                          
; ============================================================================

;	include "..\Femtiki\source\inc\const.x68"
;	include "..\Femtiki\source\inc\device.x68"

	extrn DisplayString

null_dcb	equ _DeviceTable+160*0

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Setup the NULL device
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

setup_null:
null_init:
	movem.l d0/a0/a1,-(a7)
	moveq #32,d0
	lea.l null_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$44434220,null_dcb+DCB_MAGIC				; 'DCB'
	move.l #$4E554C4C,null_dcb+DCB_NAME					; 'NULL'
	move.l #null_cmdproc,null_dcb+DCB_CMDPROC
	lea.l null_dcb+DCB_MAGIC,a1
	jsr DisplayString
	jsr CRLF
	movem.l (a7)+,d0/a0/a1
null_ret:
	rts

_null_cmdproc:
null_cmdproc:
	moveq #E_Ok,d0
	rts
	global _null_cmdproc
