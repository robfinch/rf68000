	code
;==============================================================================
; Decimal-Floating point to string conversion routine.
;
; Modifies
;		_fpWork work area
; Register Usage:
; 	fp0 = input decimal-float to convert
;		fp1 = constant holder, 1.0, 10.0
;		fp2 = 1.0e<fp0 exponent> value for conversion
;		fp3 = holds digit value during significand conversion
; 	a0 = pointer to string buffer, updated to point to NULL at end of string
;		a1 = pointer to "Nan" or "Inf" message string
;		d0 = temporary
;		d1 = digit value during exponent, significand conversion
; 	d6 = exponent
;==============================================================================
	align 4
_dfOne	dc.l $25ff0000,$00000000,$00000000
_dfTen	dc.l $2600C000,$00000000,$00000000
_dfMil  dc.l $2606DDFA,$1C000000,$00000000

_msgNan	dc.b "NaN",0
_msgInf dc.b "Inf",0
	even

;------------------------------------------------------------------------------
; Check for the special Nan and infinity values. Output the appropriate string.
;
; Modifies
;		_fpWork area
;		a0
; Parameters:
;		fp0 = dbl
;------------------------------------------------------------------------------

_CheckNan:
	link a2,#-12
	movem.l d0/a1,(sp)
	fmove.x fp0,_fpWork
	move.b _fpWork,d0				; get sign+combo
	andi.b #$7C,d0					; mask for combo bits
	cmpi.b #$7C,d0					; is it the Nan combo?
	bne .notNan
	lea _msgNan,a1					; output "Nan"
	bra .outStr
.notNan
	cmpi.b #$78,d0					; is it infinity combo?
	bne .notInf
	lea _msgInf,a1
.outStr
	move.b (a1)+,(a0)+			; output "Inf"
	move.b (a1)+,(a0)+
	move.b (a1)+,(a0)+
	clr.b (a0)
	movem.l (sp),d0/a1
	unlk a2
	ori #1,ccr							; set carry and return
	rts
.notInf
	movem.l (sp),d0/a1
	unlk a2
	andi #$FE,ccr						; clear carry and return
	rts

;------------------------------------------------------------------------------
; Check for a zero value. Output a single "0" if zero,
;
; Modifies:
;		a0
; Parameters:
;		fp0 = dbl
;------------------------------------------------------------------------------

_CheckZero:
	ftst fp0								; check if number is zero
	fbne .0003
	move.b #'0',(a0)+				; if zero output "0"
	clr.b (a0)
	ori #4,ccr							; set zf
	rts
.0003
	andi #$FB,ccr						; clear zf
	rts

;------------------------------------------------------------------------------
; Check for a negative number. This includes Nans and Infinities. Output a "-"
; if negative.
;
;	Modifies
;		a0
; Parameters:
;		fp0 = dbl
;------------------------------------------------------------------------------

_CheckNegative:
	ftst fp0								; is number negative?
	fbge .0002
	move.b #'-',(a0)+				; yes, output '-'
	fneg fp0								; make fp0 positive
.0002
	rts

;------------------------------------------------------------------------------
; Make the input value larger so that digits may appear before the decimal
; point.
;
; Modifies:
;		fp0,fp1,d6
; Parameters:
;		fp0 = dbl
;------------------------------------------------------------------------------

;	if (dbl < 1.0) {
;		while (dbl < 1.0) {
;			dbl *= 1000000.0;
;			exp -= 6;  
;		}
;	}

_MakeBig:
	fmove.w #1,fp1
.0002
	fcmp fp1,fp0						; is fp0 > 1?
	fbge .0001							; yes, return
	move.b #3,leds
	fscale.l #6,fp0					; multiply fp0 by a million
	subi.w #6,d6						; decrement exponent by six
	bra .0002								; keep trying until number is > 1
.0001
	rts
	
;------------------------------------------------------------------------------
;	Create a number dbl2 on the same order of magnitude as dbl, but
;	less than dbl. The number will be 1.0e<dbl's exponent>
;
; Modifies:
;		d6,fp2
; Parameters:
;		fp0 = dbl
;------------------------------------------------------------------------------

;	// The following is similar to using log10() and pow() functions.
;	// Now dbl is >= 1.0
;	// Create a number dbl2 on the same order of magnitude as dbl, but
;	// less than dbl.
;	dbl2 = 1.0;
;	dbla = dbl2;
;	if (dbl > dbl2) {	// dbl > 1.0 ?
;		while (dbl2 <= dbl) {
;			dbla = dbl2;
;			dbl2 *= 10.0;	// increase power of 10
;			exp++;
;		}
;		// The above loop goes one too far, we want the last value less
;		// than dbl.
;		dbl2 = dbla;
;		exp--;
;	}

_LessThanDbl:
	fmove.w #1,fp2			; setup fp2 = 1
	fcmp fp2,fp0				; if (dbl > dbl2)
	fble .0004
.0006
	move.b #2,leds
	fcmp fp0,fp2				; while (dbl2 <= dbl)
	fbgt .0005
	fscale.w #1,fp2			; dbl2 *= 10 (increase exponent by one)
	addi.w #1,d6				; exp++
	bra .0006
.0005
	fscale.l #-1,fp2		; dbl2 /= 10 (decrease exponent by one)
	subi.w #1,d6				; exp--;
.0004	
;	fmove.x fp0,_fpWork	; debugging
;	fmove.x fp2,_fpWork+12
	rts

;------------------------------------------------------------------------------
; Compute the number of digits before the decimal point.
;
; Modifies:
;		d0,d6,_digits_before_decpt
; Parameters:
;		d6 = exponent
;------------------------------------------------------------------------------

; if (exp >= 0 && exp < 6) {
;   digits_before_decpt = exp+1;
;		exp = 0;
;	}
;	else if (exp >= -7)
;		digits_before_decpt = 1;
;	else
;		digits_before_decpt = -1;

_ComputeDigitsBeforeDecpt:
	move.l d0,-(a7)
	tst.w d6
	bmi .0007
	cmpi.w #6,d6
	bge .0007
	move.w d6,d0
	addi.w #1,d0
	move.w d0,_digits_before_decpt	
	clr.w d6
	move.l (a7)+,d0
	rts
.0007
	cmpi.w #-7,d6
	blt .0009
	move.w #1,_digits_before_decpt
	move.l (a7)+,d0
	rts
.0009
	move.w #-1,_digits_before_decpt
	move.l (a7)+,d0
	rts

;------------------------------------------------------------------------------
;	Spit out a leading zero before the decimal point for a small number.
;
; Modifies:
;		a0
; Parameters:
;		d6 = exponent
;------------------------------------------------------------------------------

;  if (exp < -7) {
;		 buf[ndx] = '0';
;		 ndx++;
;    buf[ndx] = '.';
;    ndx++;
;  }

_LeadingZero:
	cmpi.w #-7,d6
	bge .0010
	move.b #'0',(a0)+
	move.b #'.',(a0)+
.0010
	rts

;------------------------------------------------------------------------------
; Extract the digits of the significand.
;
; Modifies:
;		_precision variable
; Register Usage
;		d0 = counter
;		d1 = digit
;		fp0 = dbl
;		fp2 = dbl2
;		fp3 = digit as decimal float
;		fp7 = dbla
; Parameters:
;		fp0, fp2
;------------------------------------------------------------------------------

;	// Now loop processing one digit at a time.
;  for (nn = 0; nn < 25 && precision > 0; nn++) {
;    digit = 0;
;		dbla = dbl;
;		// dbl is on the same order of magnitude as dbl2 so
;		// a repeated subtract can be used to find the digit.
;    while (dbl >= dbl2) {
;      dbl -= dbl2;
;      digit++;
;    }
;    buf[ndx] = digit + '0';
;		// Now go back and perform just a single subtract and
;		// a multiply to find out how much to reduce dbl by.
;		// This should improve the accuracy
;		if (digit > 2)
;			dbl = dbla - dbl2 * digit;
;    ndx++;
;    digits_before_decpt--;
;    if (digits_before_decpt==0) {
;			buf[ndx] = '.';
;			ndx++;
;    }
;    else if (digits_before_decpt < 0)
;      precision--;
;		// Shift the next digit to be tested into position.
;    dbl *= 10.0;
;  }
	
_SpitOutDigits:
	link a2,#-24
	fmove.x fp7,(sp)
	movem.l d0/d1,12(sp)
	move.w #24,d0			; d0 = nn
.0017	
	tst.l _precision
	ble .0011
	moveq #0,d1				; digit = 0
	fmove fp0,fp7			; dbla = dbl
.0013
	fcmp fp2,fp0
	fblt .0012
	move.b #1,leds
	fsub fp2,fp0			; dbl -= dbl2
	addi.b #1,d1			; digit++
	bra .0013
.0012
	move.b #5,leds
	addi.b #'0',d1		; convert digit to ascii
	move.b d1,(a0)+		; and store
	subi.b #'0',d1		; d1 = binary digit again
;	cmpi.b #2,d1
;	ble .0014

;	ext.w d1
;	ext.l d1
;	fmove.l d1,fp3		; fp3 = digit
;	fmul fp2,fp3			; fp3 = dbl2 * digit
;	fmove fp7,fp0
;	fsub fp3,fp0			; dbl = dbla - dbl2 * digit
.0014
	subi.w #1,_digits_before_decpt
	bne .0015
	move.b #'.',(a0)+
.0015
	tst.w _digits_before_decpt
	bge .0016
	subi.l #1,_precision
.0016
	fscale.l #-1,fp2		; dbl *= 10.0
	dbra d0,.0017
.0011
	movem.l 12(sp),d0/d1
	fmove.x (sp),fp7
	unlk a2
	rts

;------------------------------------------------------------------------------
; If the number ends in a decimal point, trim off the point.
;
; Registers Modified:
;		none
; Parameters:
;		a0 = pointer to end of number
; Returns:
;		a0 = updated to point just past last digit.
;------------------------------------------------------------------------------

_TrimTrailingPoint:
	cmpi.b #'.',-1(a0)
	bne .0001
	clr.b -(a0)
	rts
.0001
	cmpi.b #'.',(a0)
	bne .0002
	cmpi.b #0,1(a0)
	bne .0002
	clr.b (a0)
	subq #1,a0
.0002
	rts
	
;------------------------------------------------------------------------------
; If the number ends in .0 get rid of the .0
;
; Registers Modified:
;		none
; Parameters:
;		a0 = pointer to last digits of number
; Returns:
;		a0 = updated to point just past last digit.
;------------------------------------------------------------------------------

_TrimDotZero:
	tst.b (a0)
	bne .0004
	cmpi.b #'0',-1(a0)
	bne .0004
	cmpi.b #'.',-2(a0)
	bne .0004
	clr.b -2(a0)
	subq #2,a0
.0004
	rts

;------------------------------------------------------------------------------
; Trim trailing zeros from the number. Generally there is no need to display
; trailing zeros.
; Turns a number like 652.000000000000000000000 into 650.0
;
; Registers Modified:
;		none
; Parameters:
;		a0 = pointer to last digits of number
; Returns:
;		a0 = updated to point just past last digit.
;------------------------------------------------------------------------------

;	// Trim trailing zeros from the number
;  do {
;      ndx--;
;  } while(buf[ndx]=='0');
;  ndx++;

_TrimTrailingZeros:
.0018	
	cmpi.b #'0',-(a0)		; if the last digit was a zero, backup
	beq .0018
	addq #1,a0					; now advance by one
	move.b #0,(a0)			; NULL terminate string
	rts

;------------------------------------------------------------------------------
; Output 'e+' or 'e-'
;
; Registers Modified:
;		d6.w (if negative)
; Parameters:
;		a0 = pointer to last digits of number
; Returns:
;		a0 = updated to point just past '+' or '-'.
;------------------------------------------------------------------------------

;	// Spit out +/-E
;  buf[ndx] = E;
;  ndx++;
;  if (exp < 0) {
;    buf[ndx]='-';
;    ndx++;
;    exp = -exp;
;  }
;  else {
;		buf[ndx]='+';
;		ndx++;
;  }

_SpitOutE:	
	move.b _E,(a0)+
	tst.w d6
	bge .0021
	move.b #'-',(a0)+
	neg.w d6
	bra .0022
.0021
	move.b #'+',(a0)+
.0022
	rts

;------------------------------------------------------------------------------
; Extract a single digit of the exponent. Extract works from the leftmost digit
; to the rightmost.
;
; Register Usage
;		d2 = history of zeros
;		d3 = digit
; Modifies
;		d2,d6,a0
; Parameter
; 	d1.w = power of ten
;		d6.w = exponent
;------------------------------------------------------------------------------

_ExtExpDigit:
	move.l d3,-(a7)
	ext.l d6				; make d6 a long
	divu d1,d6			; divide by power of ten
	move.b d6,d3		; d3 = quotient (0 to 9)
	swap d6					; d6 = remainder, setup for next digit
	or.b d3,d2
	tst.b d3
	bne .0003
	tst.b d2	
	beq .0004
.0003
	addi.b #'0',d3	; convert to ascii
	move.b d3,(a0)+
.0004
	move.l (a7)+,d3
	rts

;------------------------------------------------------------------------------
; Extract all the digits of the exponent.
;
; Register Usage
;		d1 = power of 10
;		d2 = history of zeros
; Parameters
;		a0 = pointer to string buffer
;		d6 = exponent
;------------------------------------------------------------------------------

;	// If the number is times 10^0 don't output the exponent
;  if (exp==0) {
;    buf[ndx]='\0';
;    goto prt;
;  }

_ExtExpDigits:
	move.l d1,-(a7)
	tst.w d6							; is exponent zero?
	beq .0002
	bsr _SpitOutE					; exponent is non-zero e+
	clr.b d2							; d2 = history of zeros
	move.w #1000,d1
	bsr _ExtExpDigit
	move.w #100,d1
	bsr _ExtExpDigit
	move.w #10,d1
	bsr _ExtExpDigit
	move.w #1,d1
	bsr _ExtExpDigit
.0002:
	move.l (a7)+,d1
	move.b #0,(a0)				; NULL terminate string
	rts										; and return

;------------------------------------------------------------------------------
; Pad the left side of the output string.
;
; Modifies:
;		d0,d1,d2,d3
;------------------------------------------------------------------------------

;  // pad left
;  if (width > 0) {
;    if (ndx < width) {
;      for (nn = 39; nn >= width-ndx; nn--)
;        buf[nn] = buf[nn-(width-ndx)];
;      for (; nn >= 0; nn--)
;        buf[nn] = ' ';
;    }
;  }
	
_PadLeft:
	movem.l d0/d1/d2/d3,-(a7)
	tst.b _width
	ble .0041
	move.b #12,leds
	move.l a0,d0
	sub.l #_fpBuf,d0	; d0 = ndx
	cmp.b _width,d0
	bge .0041
	move.w #49,d1			; d1 = nn
.0040
	move.b #13,leds
	move.b _width,d2
	ext.w d2
	sub.w d0,d2				; d2 = width-ndx
	cmp.w d2,d1
	blt .0039
	move.b #14,leds
	move.w d1,d3			; d3 = nn
	sub.w d2,d3				; d3 = nn-(width-ndx)
	move.b (a0,d3.w),(a0,d1.w)
	subi.w #1,d1
	bra .0040
.0039
	move.b #15,leds
	tst.w d1
	bmi .0041
	move.b #' ',(a0,d1.w)
	subi.w #1,d1
	bra .0039
.0041
	movem.l (a7)+,d0/d1/d2/d3
	rts

;------------------------------------------------------------------------------
; Pad the right side of the output string.
;
; Parameters:
;		a0 = pointer to end of string
; Modifies:
;		none
; Returns:
;		none
;------------------------------------------------------------------------------

;  // pad right
;  if (width < 0) {
;    width = -width;
;    while (ndx < width) {
;      buf[ndx]=' ';
;      ndx++;
;    }
;    buf[ndx]='\0';
;  }
;  return (ndx);

_PadRight:
	move.l d0,-(a7)
	tst.b _width
	bpl .0042
	neg.b _width
	move.l a0,d0
	sub.l #_fpBuf,d0	; d0 = ndx
.0044
	cmp.b _width,d0
	bge .0043
	move.b #' ',(a0,d0.w)
	addi.w #1,d0
	bra .0044
.0043
	move.b #0,(a0,d0.w)
.0042
	move.l (a7)+,d0
	rts

;------------------------------------------------------------------------------
; Output a string representation of a decimal floating point number to a 
; buffer.
;
; Register Usage
;		a0 = pointer to string buffer
;		d6 = exponent
; Modifies:
;		a0 = points to end of string
; Parameters:
;		fp0 = number to convert
; Returns:
;		none
;------------------------------------------------------------------------------

_FloatToString:
	move.l d6,-(a7)
	move.b #5,leds
	bsr _CheckNegative			; is number negative?
	bsr _CheckZero					; check for zero
	beq .0001								; branch since already output "0"
	bsr _CheckNan						; check for Nan or infinity
	bcs .0001								; branch if nan/inf string output
	; Now the fun begins
	clr.l d6								; exponent = 0
	bsr _MakeBig
	bsr _LessThanDbl
	bsr _ComputeDigitsBeforeDecpt
	bsr _LeadingZero
	bsr _SpitOutDigits
	move.b #4,leds
	bsr _TrimTrailingZeros
	move.b #6,leds
	bsr _TrimTrailingPoint
	move.b #7,leds
	bsr _TrimDotZero
	move.b #8,leds
	bsr _ExtExpDigits				; extract exponent digits
	move.b #9,leds
	bsr _PadLeft						; pad the number to the left or right
	move.b #10,leds
	bsr _PadRight
	move.b #11,leds
.0001
	move.l (a7)+,d6
	rts

