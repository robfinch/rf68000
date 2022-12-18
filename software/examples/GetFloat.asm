; ============================================================================
;        __
;   \\__/ o\    (C) 2022  Robert Finch, Waterloo
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
;
; Get a floating point number
;
_GetFloatGetChar:
	move.b (a0),d1
	add.l d0,a0
	rts
_GetFloatIgnBlanks:
.0001
	bsr _GetFloatGetChar
	cmpi.b #' ',d1
	beq .0001
_GetFloatBackupChar:
	sub.l d0,a0
	rts

;-------------------------------------------------------------------------------
; Get fractional part of a number, 25 digits max, into a float register.
;
; Register Usage:
;		d1 = digit from input screen
;		d4 = digit count
;		d6 = digit scaling factor
;		fp1 = digit as float number
; Returns:
;		fp0 = fraction
;-------------------------------------------------------------------------------

_GetFraction:
	link a2,#-28
	move.l _canary,24(sp)
	movem.l d1/d4/d6,(sp)
	fmove.x fp1,12(sp)
	clr.l d6							; d6 = scale factor
	fmove.w #0,fp0				; fract = 0.0
	moveq #24,d4
.0002
	bsr _GetFloatGetChar
	cmpi.b #'0',d1
	blo .0001
	cmpi.b #'9',d1				; make sure between 0 and 9
	bhi .0001
	subi.b #'0',d1
	fscale.w #1,fp0				; fract * 10.0
	addq #1,d6						; record scaling
	fmove.b d1,fp1				; fp1 = digit
	fadd fp1,fp0					; fract += digit
	addq.w #1,d5					; increment number of digits in number
	dbra d4,.0002
.0001
	bsr _GetFloatBackupChar
	neg d6
	fscale.l d6,fp0				; fract /= scale
	movem.l (sp),d1/d4/d6
	fmove.x 12(sp),fp1
	cchk 24(sp)
	unlk a2
	rts

;-------------------------------------------------------------------------------
; Get exponent part of a number, 4 digits max, into a float register.
;
; Register Usage:
;		d1 = digit from input screen
;		d2 = exponent
;		d3 = temp, number times 2
;		d4 = digit counter
; Parameters:
;		fp0 = float number
; Returns:
;		fp0 = float number with exponent factored in
;-------------------------------------------------------------------------------

_GetExponent:
	link a2,#-32
	move.l _canary,28(sp)
	movem.l d1/d2/d3/d4,(sp)
	fmove.x fp2,16(sp)
	clr.l d2							; d2 = number = 0
	fmove.w #0,fp2				; fp2 = exp = 0.0
	moveq #1,d3						; d3 = exscale = 1
	bsr _GetFloatGetChar
	cmpi.b #'-',d1
	bne .0001
	neg.l d3							; exscale = -1
.0006
	bsr _GetFloatIgnBlanks
	bra .0002
.0001
	cmpi.b #'+',d1
	beq .0006
	bsr _GetFloatBackupChar
.0002	
	moveq #3,d4						; d4 = max 4 digits
.0004
	bsr _GetFloatGetChar	; d1 = digit char
	cmpi.b #'0',d1
	blo .0003
	cmpi.b #'9',d1				; ensure between 0 and 9
	bhi .0003
	subi.b #'0',d1
	add.l d2,d2						; number *2
	move.l d2,d3
	lsl.l #2,d2						; number *8
	add.l d3,d2						; number *10	
	ext.w d1
	ext.l d1
	add.l d1,d2						; number + digit
	addq.w #1,d5					; increment number of digits in number
	dbra d4,.0004
.0003
	bsr _GetFloatBackupChar	; backup a character
	mulu d3,d2						; *1 or *-1
	ext.l d2
	fscale.l d2,fp2				; exp * exmul
	fmul fp2,fp0					; rval *= exp
	movem.l (sp),d1/d2/d3/d4
	fmove.x 16(sp),fp2
	cchk 28(sp)
	unlk a2
	rts	

;-------------------------------------------------------------------------------
; Get an integer number, positive or negative, 25 digits max, into a float
; register.
;
; Register Usage:
;		d1 = digit from input screen
;		d2 = digit down counter
;		d3 = sign of number '+' or '-'
;		fp1 = digit
; Modifies:
;		a0,fp0
; Returns:
;		a0 = updated buffer pointer
;		fp0 = integer number
;-------------------------------------------------------------------------------

_GetInteger:
	link a2,#-28
	move.l _canary,24(sp)
	movem.l d1/d2/d3,(sp)
	fmove.x fp1,12(sp)
	fmove.w #0,fp0
	moveq #24,d2					; d2 = digit count (25 max)
	bsr _GetFloatIgnBlanks
	bsr _GetFloatGetChar	; get the sign of the number
	cmpi.b #'+',d1
	beq .0002
.0003
	cmpi.b #'-',d1
	bne .0004
	move.b #'-',d7
.0002
	bsr _GetFloatGetChar
.0004
	cmpi.b #'0',d1				; only characters 0 to 9 valid
	blo .0001
	cmpi.b #'9',d1
	bhi .0001
	subi.b #'0',d1
	fscale.w #1,fp0				; number *10
	fmove.b d1,fp1				; fp1 = digit
	fadd fp1,fp0
	addq.w #1,d5
	dbra d2,.0002
.0001
	bsr _GetFloatBackupChar
	movem.l (sp),d1/d2/d3
	fmove.x 12(sp),fp1
	cchk 24(sp)
	unlk a2
	rts
		
;-------------------------------------------------------------------------------
; Get a floating point number off the input screen.
;
; Parameters:
;		a0 = pointer to buffer containing string
;		d0 = stride of buffer (increment / decrement amount)
; Register Usage:
;		d1 = character from input screen
;		d5.lo = number of digits in number, d5.hi = number of characters fetched
; Returns:
;		fp0 = number
;		a0 = updated buffer pointer
;		d0 = length of number >0 if a number
;-------------------------------------------------------------------------------

_GetFloat:
	link a2,#-32
	move.l _canary,28(sp)
	movem.l d1/d5/d7/a1,(sp)
	fmove.x fp2,16(sp)
	clr.l d5
	move.b #'+',d7				; assume a positive number
	move.l a0,a1					; a1 = copy of pointer to buffer
	bsr _GetInteger				; rval = integer
	fmove.x fp0,fp2
	bsr _GetFloatGetChar
	cmpi.b #'.',d1
	beq .0004
.0005
	bsr _GetFloatBackupChar
	bra .0002
.0004
	bsr _GetFraction
	fadd fp2,fp0					; rval += fraction
	bsr _GetFloatGetChar
	cmpi.b #'e',d1				; accept either 'e' or 'E' indicating exponent
	beq .0001
	cmpi.b #'E',d1
	bne .0005
.0001
	bsr _GetExponent			; factor exponent into fp0
.0002
	cmpi.b #'-',d7				; adjust number for sign
	bne .0003
	fneg fp0
.0003
	suba.l a0,a1					; compute number of characters fetched
	move.w a1,d0					; move it to d0.hi
	swap d0
	move.w d5,d0					; return digit/character count in d0 (non zero for a number)
	movem.l (sp),d1/d5/d7/a1
	fmove.x 16(sp),fp2
	cchk 28(sp)
	unlk a2
	rts	

		