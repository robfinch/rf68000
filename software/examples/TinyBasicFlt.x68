******************************************************************
*								 *
*		Tiny Float BASIC for the Motorola MC68000		 *
*								 *
* Derived from Palo Alto Tiny BASIC as published in the May 1976 *
* issue of Dr. Dobb's Journal.  Adapted to the 68000 by:         *
*	Gordon Brandly						 *
*								 *
******************************************************************
*    Copyright (C) 1984 by Gordon Brandly. This program may be	 *
*    freely distributed for personal use only. All commercial	 *
*		       rights are reserved.			 *
******************************************************************
* Modified (c) 2022 for the rf68000. Robert Finch
* Numerics changed to floating-point
* added string handling
******************************************************************

* Vers. 1.0  1984/7/17	- Original version by Gordon Brandly
*	1.1  1984/12/9	- Addition of '$' print term by Marvin Lipford
*	1.2  1985/4/9	- Bug fix in multiply routine by Rick Murray

*	OPT	FRS,BRS 	forward ref.'s & branches default to short

;CR	EQU	$0D		ASCII equates
;LF	EQU	$0A
;TAB	EQU	$09
;CTRLC	EQU	$03
;CTRLH	EQU	$08
;CTRLS	EQU	$13
;CTRLX	EQU	$18

DT_NONE equ 0
DT_NUMERIC equ 1
DT_STRING equ 2		; string descriptor
DT_TEXTPTR equ 3	; pointer into program text

BUFLEN	EQU	80		length of keyboard input buffer
STRAREASIZE	EQU	2048	; size of string area
	CODE
*	ORG	$10000		first free address using Tutor
*
* Standard jump table. You can change these addresses if you are
* customizing this interpreter for a different environment.
*
START	BRA	CSTART		Cold Start entry point
GOWARM	BRA	WSTART		Warm Start entry point
GOOUT	BRA OUTC		Jump to character-out routine
GOIN	BRA INC		Jump to character-in routine
GOAUXO	BRA	AUXOUT		Jump to auxiliary-out routine
GOAUXI	BRA	AUXIN		Jump to auxiliary-in routine
GOBYE	BRA	BYEBYE		Jump to monitor, DOS, etc.
*
* Modifiable system constants:
*
TXTBGN	DC.L	$41000		beginning of program memory
ENDMEM	DC.L	$47FF0		end of available memory
*
* The main interpreter starts here:
*
CSTART
	MOVE.L ENDMEM,SP	initialize stack pointer
	move.l #INC1,INPPTR
	move.b #0,InputDevice
	move.b #1,OutputDevice
	move.l #1,_fpTextIncr
	LEA	INITMSG,A6	tell who we are
	BSR	PRMESG
	MOVE.L TXTBGN,TXTUNF	init. end-of-program pointer
	MOVE.L ENDMEM,D0	get address of end of memory
	move.l ENDMEM,STKFP
	SUB.L	#4096,D0	reserve 4K for the stack
	MOVE.L D0,STRSTK
	ADD.L #32,D0
	MOVE.L D0,STKLMT
	SUB.L	#512,D0 	reserve variable area (32 16 byte floats)
	MOVE.L D0,VARBGN
	bsr ClearStringArea
WSTART
	CLR.L	D0		initialize internal variables
	move.l #1,_fpTextIncr
	clr.l IRQROUT
	MOVE.L	D0,LOPVAR
	MOVE.L	D0,STKGOS
	MOVE.L	D0,CURRNT	; current line number pointer = 0
	MOVE.L ENDMEM,SP	; init S.P. again, just in case
	bsr ClearStringStack
	LEA	OKMSG,A6			; display "OK"
	bsr	PRMESG
ST3
	MOVE.B	#'>',D0         Prompt with a '>' and
	bsr	GETLN		read a line.
	bsr	TOUPBUF 	convert to upper case
	MOVE.L	A0,A4		save pointer to end of line
	LEA	BUFFER,A0	point to the beginning of line
	bsr	TSTNUM		is there a number there?
	bsr	IGNBLK		skip trailing blanks
	FMOVE.L FP1,D1
	TST.L D2			; does line no. exist? (or nonzero?)
	BEQ	DIRECT		; if not, it's a direct statement
	CMP.L	#$FFFF,D1	see if line no. is <= 16 bits
	BCC	QHOW		if not, we've overflowed
	MOVE.B	D1,-(A0)	store the binary line no.
	ROR	#8,D1		(Kludge to store a word on a
	MOVE.B	D1,-(A0)	possible byte boundary)
	ROL	#8,D1
	bsr	FNDLN		find this line in save area
	MOVE.L	A1,A5		save possible line pointer
	BNE	ST4		if not found, insert
	bsr	FNDNXT		find the next line (into A1)
	MOVE.L	A5,A2		pointer to line to be deleted
	MOVE.L	TXTUNF,A3	points to top of save area
	bsr	MVUP		move up to delete
	MOVE.L	A2,TXTUNF	update the end pointer
ST4
	MOVE.L	A4,D0		calculate the length of new line
	SUB.L	A0,D0
	CMP.L	#3,D0		is it just a line no. & CR?
	BLE	ST3		if so, it was just a delete
	MOVE.L TXTUNF,A3	compute new end
	MOVE.L A3,A6
	ADD.L	D0,A3
	MOVE.L StrArea,D0	see if there's enough room
	CMP.L	A3,D0
	BLS	QSORRY		if not, say so
	MOVE.L	A3,TXTUNF	if so, store new end position
	MOVE.L	A6,A1		points to old unfilled area
	MOVE.L	A5,A2		points to beginning of move area
	bsr	MVDOWN		move things out of the way
	MOVE.L	A0,A1		set up to do the insertion
	MOVE.L	A5,A2
	MOVE.L	A4,A3
	bsr	MVUP		do it
	BRA	ST3		go back and get another line

ClearStringArea:
	move.l VARBGN,d0
	SUB.L #STRAREASIZE,D0
	MOVE.L D0,StrArea
	MOVE.L D0,LastStr
	move.l StrArea,a0
	clr.l (a0)+
	clr.l (a0)+
	rts

ClearStringStack:
	moveq #7,d0
	move.l STRSTK,a1
.0001
	clr.l (a1)+				; clear the string stack
	dbra d0,.0001
	move.l a1,StrSp		; set string stack stack pointer
	rts

	even

*******************************************************************
*
* *** Tables *** DIRECT *** EXEC ***
*
* This section of the code tests a string against a table. When
* a match is found, control is transferred to the section of
* code according to the table.
*
* At 'EXEC', A0 should point to the string, A1 should point to
* the character table, and A2 should point to the execution
* table. At 'DIRECT', A0 should point to the string, A1 and
* A2 will be set up to point to TAB1 and TAB1_1, which are
* the tables of all direct and statement commands.
*
* A '.' in the string will terminate the test and the partial
* match will be considered as a match, e.g. 'P.', 'PR.','PRI.',
* 'PRIN.', or 'PRINT' will all match 'PRINT'.
*
* There are two tables: the character table and the execution
* table. The character table consists of any number of text items.
* Each item is a string of characters with the last character's
* high bit set to one. The execution table holds a 16-bit
* execution addresses that correspond to each entry in the
* character table.
*
* The end of the character table is a 0 byte which corresponds
* to the default routine in the execution table, which is
* executed if none of the other table items are matched.
*
* Character-matching tables:
TAB1
	DC.B	'<CO',('M'+$80)
	DC.B	'<CO',('N'+$80)
	DC.B	'>CO',('M'+$80)
	DC.B	'>CO',('N'+$80)
	DC.B	'<>CO',('M'+$80)
	DC.B	'<>CO',('N'+$80)
	DC.B	'LIS',('T'+$80)         Direct commands
	DC.B	'LOA',('D'+$80)
	DC.B	'NE',('W'+$80)
	DC.B	'RU',('N'+$80)
	DC.B	'SAV',('E'+$80)
	DC.B 	'CL',('S'+$80)
TAB2
	DC.B	'NEX',('T'+$80)         Direct / statement
	DC.B	'LE',('T'+$80)
	DC.B	'I',('F'+$80)
	DC.B	'GOT',('O'+$80)
	DC.B	'GOSU',('B'+$80)
	DC.B	'RETUR',('N'+$80)
	DC.B	'RE',('M'+$80)
	DC.B	'FO',('R'+$80)
	DC.B	'INPU',('T'+$80)
	DC.B	'PRIN',('T'+$80)
	DC.B	'POK',('E'+$80)
	DC.B	'STO',('P'+$80)
	DC.B	'BY',('E'+$80)
	DC.B	'CAL',('L'+$80)
	DC.B	'ONIR',('Q'+$80)
	DC.B	0
TAB4
	DC.B	'PEE',('K'+$80)         Functions
	DC.B	'RN',('D'+$80)
	DC.B	'AB',('S'+$80)
	DC.B	'SIZ',('E'+$80)
	DC.B	'TIC',('K'+$80)
	DC.B	'COREN',('O'+$80)
	DC.B	'LEFT',('$'+$80)
	DC.B	'RIGHT',('$'+$80)
	DC.B	'MID',('$'+$80)
	DC.B	'LE',('N'+$80)
	DC.B	'IN',('T'+$80)
	DC.B	'CHR',('$'+$80)
	DC.B	0
TAB5
	DC.B	'T',('O'+$80)           "TO" in "FOR"
	DC.B	0
TAB6
	DC.B	'STE',('P'+$80)         "STEP" in "FOR"
	DC.B	0
TAB8
	DC.B	'>',('='+$80)           Relational operators
	DC.B	'<',('>'+$80)
	DC.B	('>'+$80)
	DC.B	('='+$80)
	DC.B	'<',('='+$80)
	DC.B	('<'+$80)
	DC.B	0
	DC.B	0	<- for aligning on a word boundary
TAB9
	DC.B	'AN',('D'+$80)
	DC.B	0
TAB10
	DC.B	'O',('R'+$80)
	DC.B	0
TAB11
	DC.B	'MO',('D'+$80)
	DC.B	0
	DC.B	0

; Execution address tables:
	align 2
TAB1_1	
	DC.L	INCOM
	DC.L	INCON
	DC.L	OUTCOM
	DC.L	OUTCON
	DC.L	IOCOM
	DC.L	IOCON
	DC.L	LIST			Direct commands
	DC.L	LOAD
	DC.L	NEW
	DC.L	RUN
	DC.L	SAVE
	DC.L	CLS
TAB2_1
	DC.L	NEXT			Direct / statement
	DC.L	LET
	DC.L	IF
	DC.L	GOTO
	DC.L	GOSUB
	DC.L	RETURN
	DC.L	REM
	DC.L	FOR
	DC.L	INPUT
	DC.L	PRINT
	DC.L	POKE
	DC.L	STOP
	DC.L	GOBYE
	DC.L	CALL
	DC.L	ONIRQ
	DC.L	DEFLT
TAB4_1
	DC.L	PEEK			; Functions
	DC.L	RND
	DC.L	ABS
	DC.L	SIZE
	DC.L	TICK
	DC.L	CORENO
	DC.L	LEFT
	DC.L	RIGHT
	DC.L	MID
	DC.L	LEN
	DC.L	INT
	DC.L  CHR
	DC.L	XP40
TAB5_1
	DC.L	FR1			; "TO" in "FOR"
	DC.L	QWHAT
TAB6_1
	DC.L	FR2			; "STEP" in "FOR"
	DC.L	FR3
TAB8_1
	DC.L	XP11	>=		Relational operators
	DC.L	XP12	<>
	DC.L	XP13	>
	DC.L	XP15	=
	DC.L	XP14	<=
	DC.L	XP16	<
	DC.L	XP17
TAB9_1
	DC.L	XP_AND
	DC.L	XP_ANDX
TAB10_1
	DC.L	XP_OR
	DC.L	XP_ORX
TAB11_1
	DC.L	XP_MOD
	DC.L	XP31
	even
	
DIRECT
	move.w #1,DIRFLG
	LEA	TAB1,A1
	LEA	TAB1_1,A2
EXEC
	bsr	IGNBLK				; ignore leading blanks
	MOVE.L A0,A3			; save the pointer
	CLR.B	D2					; clear match flag
EXLP
	MOVE.B (A0)+,D0	 	; get the program character
	MOVE.B (A1),D1 		; get the table character
	BNE	EXNGO					; If end of table,
	MOVE.L A3,A0			; restore the text pointer and...
	BRA	EXGO					; execute the default.
EXNGO
	MOVE.B D0,D3		 	; Else check for period...
	AND.B	D2,D3				; and a match.
	CMP.B	#'.',D3
	BEQ	EXGO					; if so, execute
	AND.B	#$7F,D1 		; ignore the table's high bit
	CMP.B	D0,D1				; is there a match?
	BEQ	EXMAT
	ADDQ.L #4,A2			; if not, try the next entry
	MOVE.L A3,A0			; reset the program pointer
	CLR.B	D2					; sorry, no match
EX1
	TST.B	(A1)+				; get to the end of the entry
	BPL	EX1
	BRA	EXLP					; back for more matching
EXMAT
	MOVEQ	#-1,D2			; we've got a match so far
	TST.B	(A1)+				; end of table entry?
	BPL	EXLP					; if not, go back for more
EXGO
	MOVE.L (A2),A3		; execute the appropriate routine
	JMP	(A3)

*******************************************************************
* Console redirection
* <COM will redirect input to the COM port
* >COM will redirect output to the COM port
* <CON will redirect input to the console
* >CON will redirect output to the console
* <>COM will redirect input and output to the COM port
* <>CON will redirect input and output to the console
*******************************************************************
INCON
	move.l	#INC1,INPPTR
	bra			FINISH
INCOM
	move.l	#AUXIN,INPPTR
	bra			FINISH
IOCOM
	move.l	#AUXIN,INPPTR
OUTCOM
	move.b #2,OutputDevice
	bra	FINISH
IOCON
	move.l	#INC1,INPPTR
OUTCON
	move.b #1,OutputDevice
	bra	FINISH

*******************************************************************
*
* What follows is the code to execute direct and statement
* commands. Control is transferred to these points via the command
* table lookup code of 'DIRECT' and 'EXEC' in the last section.
* After the command is executed, control is transferred to other
* sections as follows:
*
* For 'LIST', 'NEW', and 'STOP': go back to the warm start point.
* For 'RUN': go execute the first stored line if any; else go
* back to the warm start point.
* For 'GOTO' and 'GOSUB': go execute the target line.
* For 'RETURN' and 'NEXT'; go back to saved return line.
* For all others: if 'CURRNT' is 0, go to warm start; else go
* execute next command. (This is done in 'FINISH'.)
*
*******************************************************************
*
* *** NEW *** STOP *** RUN (& friends) *** GOTO ***
*
* 'NEW<CR>' sets TXTUNF to point to TXTBGN
*
* 'STOP<CR>' goes back to WSTART
*
* 'RUN<CR>' finds the first stored line, stores its address
* in CURRNT, and starts executing it. Note that only those
* commands in TAB2 are legal for a stored program.
*
* There are 3 more entries in 'RUN':
* 'RUNNXL' finds next line, stores it's address and executes it.
* 'RUNTSL' stores the address of this line and executes it.
* 'RUNSML' continues the execution on same line.
*
* 'GOTO expr<CR>' evaluates the expression, finds the target
* line, and jumps to 'RUNTSL' to do it.
*
NEW
	bsr	ENDCHK
	MOVE.L TXTBGN,TXTUNF	set the end pointer
	bsr ClearStringArea
	bsr ClearStringStack

STOP
	bsr	ENDCHK
	BRA	WSTART

RUN
	clr.w DIRFLG
	bsr	ENDCHK
	MOVE.L	TXTBGN,A0	set pointer to beginning
	MOVE.L	A0,CURRNT

RUNNXL
	TST.L	CURRNT		; executing a program?
	beq	WSTART			; if not, we've finished a direct stat.
	tst.l	IRQROUT		; are we handling IRQ's ?
	beq	RUN1
	tst.b IRQFlag		; was there an IRQ ?
	beq	RUN1
	clr.b IRQFlag

	; same code as GOSUB	
;	sub.l #128,sp		; allocate storage for local variables
;	move.l STKFP,-(sp)
;	move.l sp,STKFP
	bsr	PUSHA				; save the current 'FOR' parameters
	MOVE.L A0,-(SP)	; save text pointer
	MOVE.L CURRNT,-(SP)	found it, save old 'CURRNT'...
	MOVE.L STKGOS,-(SP)	and 'STKGOS'
	CLR.L	LOPVAR		; load new values
	MOVE.L SP,STKGOS

	move.l IRQROUT,a1
	bra	RUNTSL
RUN1
	CLR.L	D1			; else find the next line number
	MOVE.L A0,A1
	bsr	FNDLNP
	BCS	WSTART		; if we've fallen off the end, stop

RUNTSL
	MOVE.L	A1,CURRNT	set CURRNT to point to the line no.
	MOVE.L	A1,A0		set the text pointer to
	ADDQ.L	#2,A0		the start of the line text

RUNSML
	bsr	CHKIO		see if a control-C was pressed
	LEA	TAB2,A1 	find command in TAB2
	LEA	TAB2_1,A2
	BRA	EXEC		and execute it

GOTO	
	bsr	INT_EXPR	; evaluate the following expression
	bsr	ENDCHK		; must find end of line
	move.l d0,d1
	bsr	FNDLN			; find the target line
	bne	QHOW			; no such line no.
	bra	RUNTSL		; go do it

;******************************************************************
; ONIRQ <line number>
; ONIRQ sets up an interrupt handler which acts like a specialized
; subroutine call. ONIRQ is coded like a GOTO that never executes.
;******************************************************************

ONIRQ:
	bsr	INT_EXPR		; evaluate the following expression
	bsr ENDCHK			; must find end of line
	move.l d0,d1
	bsr FNDLN				; find the target line
	bne	ONIRQ1
	clr.l IRQROUT
	bra	FINISH
ONIRQ1:
	move.l a1,IRQROUT
	jmp	FINISH


WAITIRQ:
	jsr	CHKIO				; see if a control-C was pressed
	tst.b IRQFlag
	beq	WAITIRQ
	jmp	FINISH

*******************************************************************
*
* *** LIST *** PRINT ***
*
* LIST has two forms:
* 'LIST<CR>' lists all saved lines
* 'LIST #<CR>' starts listing at the line #
* Control-S pauses the listing, control-C stops it.
*
* PRINT command is 'PRINT ....:' or 'PRINT ....<CR>'
* where '....' is a list of expressions, formats, back-arrows,
* and strings.	These items a separated by commas.
*
* A format is a pound sign followed by a number.  It controls
* the number of spaces the value of an expression is going to
* be printed in.  It stays effective for the rest of the print
* command unless changed by another format.  If no format is
* specified, 11 positions will be used.
*
* A string is quoted in a pair of single- or double-quotes.
*
* An underline (back-arrow) means generate a <CR> without a <LF>
*
* A <CR LF> is generated after the entire list has been printed
* or if the list is empty.  If the list ends with a semicolon,
* however, no <CR LF> is generated.
*

LIST	
	bsr	TSTNUM		see if there's a line no.
	bsr	ENDCHK		if not, we get a zero
	bsr	FNDLN		find this or next line
LS1
	BCS	FINISH		warm start if we passed the end
	bsr	PRTLN		print the line
	bsr	CHKIO		check for listing halt request
	BEQ	LS3
	CMP.B	#CTRLS,D0	pause the listing?
	BNE	LS3
LS2
	bsr	CHKIO		if so, wait for another keypress
	BEQ	LS2
LS3
	bsr	FNDLNP		find the next line
	BRA	LS1

PRINT	
	MOVE.L #11,D4		D4 = number of print spaces
	bsr	TSTC		if null list and ":"
	DC.B	':',PR2-*
	bsr	CRLF		give CR-LF and continue
	BRA	RUNSML		execution on the same line
PR2	
	bsr	TSTC		if null list and <CR>
	DC.B	CR,PR0-*
	bsr	CRLF		also give CR-LF and
	BRA	RUNNXL		execute the next line
PR0
	bsr	TSTC				; else is it a format?
	dc.b '#',PR1-*
	bsr	INT_EXPR		; yes, evaluate expression
	move.l d0,d4		; and save it as print width
	bra	PR3					; look for more to print
PR1
	bsr	TSTC				; is character expression? (MRL)
	dc.b '$',PR8-*
	bsr	INT_EXPR		; yep. Evaluate expression (MRL)
	bsr	GOOUT				; print low byte (MRL)
	bra	PR3					; look for more. (MRL)
PR3
	bsr	TSTC						; if ",", go find next
	dc.b ',',PR6-*
	bsr	FIN							; in the list.
	BRA	PR0
PR6
	bsr	CRLF						; list ends here
	BRA	FINISH
PR8
	move.l d4,-(SP)			; save the width value
	bsr	EXPR						; evaluate the expression
	move.l (sp)+,d4			; restore the width
	cmpi.l #DT_STRING,d0	; is it a string?
	beq PR9
	fmove fp0,fp1
	move.l #35,d4
	bsr	PRTNUM					; print its value
	bra	PR3							; more to print?
	; Print a string
PR9
	fmove.x fp0,_fpWork
	move.w _fpWork,d1
	move.l _fpWork+4,a1
	bsr PRTSTR2
	bra PR3

FINISH
	bsr	FIN			; Check end of command
	BRA	QWHAT		; print "What?" if wrong

;******************************************************************
;
; *** GOSUB *** & RETURN ***
;
; 'GOSUB expr:' or 'GOSUB expr<CR>' is like the 'GOTO' command,
; except that the current text pointer, stack pointer, etc. are
; saved so that execution can be continued after the subroutine
; 'RETURN's.  In order that 'GOSUB' can be nested (and even
; recursive), the save area must be stacked.  The stack pointer
; is saved in 'STKGOS'.  The old 'STKGOS' is saved on the stack.
; If we are in the main routine, 'STKGOS' is zero (this was done
; in the initialization section of the interpreter), but we still
; save it as a flag for no further 'RETURN's.
;
; 'RETURN<CR>' undoes everything that 'GOSUB' did, and thus
; returns the execution to the command after the most recent
; 'GOSUB'.  If 'STKGOS' is zero, it indicates that we never had
; a 'GOSUB' and is thus an error.

GOSUB:
	sub.l #128,sp		; allocate storage for local variables
	move.l STKFP,-(sp)
	move.l sp,STKFP
	bsr	PUSHA				; save the current 'FOR' parameters
	bsr	INT_EXPR		; get line number
	MOVE.L	A0,-(SP)	save text pointer
	move.l	d0,d1
	bsr	FNDLN		find the target line
	BNE	AHOW		if not there, say "How?"
	MOVE.L	CURRNT,-(SP)	found it, save old 'CURRNT'...
	MOVE.L	STKGOS,-(SP)	and 'STKGOS'
	CLR.L	LOPVAR		load new values
	MOVE.L	SP,STKGOS
	BRA	RUNTSL

RETURN:
	bsr	ENDCHK					; there should be just a <CR>
	MOVE.L	STKGOS,D1		; get old stack pointer
	BEQ	QWHAT						; if zero, it doesn't exist
	MOVE.L	D1,SP				; else restore it
	MOVE.L	(SP)+,STKGOS	; and the old 'STKGOS'
	MOVE.L	(SP)+,CURRNT	; and the old 'CURRNT'
	MOVE.L	(SP)+,A0		; and the old text pointer
	bsr	POPA						; and the old 'FOR' parameters
;	move.l STKFP,sp
	move.l (sp)+,STKFP
	add.l #128,sp				; remove local variable storage
	BRA	FINISH					; and we are back home

*******************************************************************
*
* *** FOR *** & NEXT ***
*
* 'FOR' has two forms:
* 'FOR var=exp1 TO exp2 STEP exp1' and 'FOR var=exp1 TO exp2'
* The second form means the same thing as the first form with a
* STEP of positive 1.  The interpreter will find the variable 'var'
* and set its value to the current value of 'exp1'.  It also
* evaluates 'exp2' and 'exp1' and saves all these together with
* the text pointer, etc. in the 'FOR' save area, which consisits of
* 'LOPVAR', 'LOPINC', 'LOPLMT', 'LOPLN', and 'LOPPT'.  If there is
* already something in the save area (indicated by a non-zero
* 'LOPVAR'), then the old save area is saved on the stack before
* the new values are stored.  The interpreter will then dig in the
* stack and find out if this same variable was used in another
* currently active 'FOR' loop.  If that is the case, then the old
* 'FOR' loop is deactivated. (i.e. purged from the stack)
*
* 'NEXT var' serves as the logical (not necessarily physical) end
* of the 'FOR' loop.  The control variable 'var' is checked with
* the 'LOPVAR'.  If they are not the same, the interpreter digs in
* the stack to find the right one and purges all those that didn't
* match.  Either way, it then adds the 'STEP' to that variable and
* checks the result with against the limit value.  If it is within
* the limit, control loops back to the command following the
* 'FOR'.  If it's outside the limit, the save area is purged and
* execution continues.

FOR
	bsr	PUSHA			; save the old 'FOR' save area
	bsr	SETVAL		; set the control variable
	move.l a6,LOPVAR		; save its address
	LEA	TAB5,A1 	; use 'EXEC' to test for 'TO'
	LEA	TAB5_1,A2
	BRA	EXEC
FR1	
	bsr	NUM_EXPR		; evaluate the limit
	FMOVE.X	FP0,LOPLMT	; save that
	LEA	TAB6,A1 		; use 'EXEC' to look for the
	LEA	TAB6_1,A2		; word 'STEP'
	BRA	EXEC
FR2
	bsr	NUM_EXPR		found it, get the step value
	BRA	FR4
FR3
	FMOVE.B #1,FP0	; not found, step defaults to 1
FR4
	FMOVE.X	FP0,LOPINC	save that too
FR5	
	MOVE.L	CURRNT,LOPLN	save address of current line number
	MOVE.L	A0,LOPPT	and text pointer
	MOVE.L	SP,A6		dig into the stack to find 'LOPVAR'
	BRA	FR7
FR6
	lea 36(a6),a6			; look at next stack frame
	cmp.l ENDMEM,a6		; safety check
	bhs QWHAT
FR7
	MOVE.L	(A6),D0 	; is it zero?
	BEQ	FR8						; if so, we're done
	CMP.L	LOPVAR,D0		; same as current LOPVAR?
	BNE	FR6						; nope, look some more
	MOVE.L	SP,A2			; Else remove 9 long words from...
	MOVE.L	A6,A1			; inside the stack.
	lea	36(a1),a3
	bsr	MVDOWN
	MOVE.L	A3,SP		set the SP 9 long words up
FR8
	BRA	FINISH		and continue execution

NEXT	
	bsr	TSTV						; get address of variable
	bcs	QWHAT						; if no variable, say "What?"
	move.l d0,a1				; save variable's address
NX0
	move.l LOPVAR,D0		; If 'LOPVAR' is zero, we never...
	beq	QWHAT						; had a FOR loop, so say "What?"
	cmp.l	d0,a1					; else we check them
	beq	NX3							; OK, they agree
	bsr	POPA						; nope, let's see the next frame
	bra	NX0
NX3	
	fmove.x	4(a1),fp0		; get control variable's value
	fadd.x LOPINC,fp0		; add in loop increment
;	BVS	QHOW		say "How?" for 32-bit overflow
	fmove.x	fp0,4(a1)		; save control variable's new value
	fmove.x	LOPLMT,fp1	; get loop's limit value
	ftst LOPINC
	FBGE NX1				; branch if loop increment is positive
	FMOVE.X FP0,-(a7)	; exchange FP0,FP1
	FMOVE.X FP1,FP0
	FMOVE.X (a7)+,FP1
NX1	
	FCMP FP0,FP1		;	test against limit
	FBLT NX2				; branch if outside limit
	MOVE.L LOPLN,CURRNT	Within limit, go back to the...
	MOVE.L LOPPT,A0	saved 'CURRNT' and text pointer.
	BRA	FINISH
NX2
	bsr	POPA		purge this loop
	BRA	FINISH

*******************************************************************
*
* *** REM *** IF *** INPUT *** LET (& DEFLT) ***
*
* 'REM' can be followed by anything and is ignored by the
* interpreter.
*
* 'IF' is followed by an expression, as a condition and one or
* more commands (including other 'IF's) separated by colons.
* Note that the word 'THEN' is not used.  The interpreter evaluates
* the expression.  If it is non-zero, execution continues.  If it
* is zero, the commands that follow are ignored and execution
* continues on the next line.
*
* 'INPUT' is like the 'PRINT' command, and is followed by a list
* of items.  If the item is a string in single or double quotes,
* or is an underline (back arrow), it has the same effect as in
* 'PRINT'.  If an item is a variable, this variable name is
* printed out followed by a colon, then the interpreter waits for
* an expression to be typed in.  The variable is then set to the
* value of this expression.  If the variable is preceeded by a
* string (again in single or double quotes), the string will be
* displayed followed by a colon.  The interpreter the waits for an
* expression to be entered and sets the variable equal to the
* expression's value.  If the input expression is invalid, the
* interpreter will print "What?", "How?", or "Sorry" and reprint
* the prompt and redo the input.  The execution will not terminate
* unless you press control-C.  This is handled in 'INPERR'.
*
* 'LET' is followed by a list of items separated by commas.
* Each item consists of a variable, an equals sign, and an
* expression.  The interpreter evaluates the expression and sets
* the variable to that value.  The interpreter will also handle
* 'LET' commands without the word 'LET'.  This is done by 'DEFLT'.

REM
	BRA	IF2		skip the rest of the line

IF
	bsr	INT_EXPR		evaluate the expression
IF1
	TST.L	d0		is it zero?
	BNE	RUNSML		if not, continue
IF2
	MOVE.L	A0,A1
	CLR.L	D1
	bsr	FNDSKP		if so, skip the rest of the line
	BCC	RUNTSL		and run the next line
	BRA	WSTART		if no next line, do a warm start

INPERR	MOVE.L	STKINP,SP	restore the old stack pointer
	MOVE.L	(SP)+,CURRNT	and old 'CURRNT'
	ADDQ.L	#4,SP
	MOVE.L	(SP)+,A0	and old text pointer

INPUT	
	MOVE.L	A0,-(SP)	save in case of error
	bsr EXPR
	cmpi.b #DT_STRING,d0
	bne IP6
	fmove.x fp0,_fpWork
	move.w _fpWork,d1
	move.l _fpWork+4,a1
	bsr PRTSTR2
;	bsr	QTSTG		is next item a string?
;	BRA.S	IP2		nope
IP7
	bsr	TSTV		yes, but is it followed by a variable?
	BCS	IP4		if not, branch
	MOVE.L	D0,A2		put away the variable's address
	BRA	IP3		if so, input to variable
IP6
	move.l (sp),a0	; restore text pointer
	bra IP7
IP2
	MOVE.L	A0,-(SP)	save for 'PRTSTG'
	bsr	TSTV		must be a variable now
	BCS	QWHAT		"What?" it isn't?
	MOVE.L	D0,A2		put away the variable's address
	MOVE.B	(A0),D2 	get ready for 'PRTSTG'
	CLR.B	D0
	MOVE.B	D0,(A0)
	MOVE.L	(SP)+,A1
	bsr	PRTSTG		print string as prompt
	MOVE.B	D2,(A0) 	restore text
IP3
	MOVE.L	A0,-(SP)	save in case of error
	MOVE.L	CURRNT,-(SP)	also save 'CURRNT'
	MOVE.L	#-1,CURRNT	flag that we are in INPUT
	MOVE.L	SP,STKINP	save the stack pointer too
	MOVE.L	A2,-(SP)	save the variable address
	MOVE.B	#':',D0         print a colon first
	bsr	GETLN		then get an input line
	LEA	BUFFER,A0	point to the buffer
	bsr	EXPR		evaluate the input
	MOVE.L	(SP)+,A2	restore the variable address
	move.l d0,(a2)			; save data type
	FMOVE.X	FP0,4(A2) 	; save value in variable
	MOVE.L	(SP)+,CURRNT	restore old 'CURRNT'
	MOVE.L	(SP)+,A0	and the old text pointer
IP4
	ADDQ.L	#4,SP		clean up the stack
	bsr	TSTC		is the next thing a comma?
	DC.B	',',IP5-*
	BRA	INPUT		yes, more items
IP5
	BRA	FINISH

DEFLT
	CMP.B	#CR,(A0)	; empty line is OK
	BEQ	FINISH			; else it is 'LET'

LET
	bsr	SETVAL		 	; do the assignment
	bsr	TSTC				; check for more 'LET' items
	DC.B	',',LT1-*
	BRA	LET
LT1
	BRA	FINISH			; until we are finished.


*******************************************************************
*
* *** LOAD *** & SAVE ***
*
* These two commands transfer a program to/from an auxiliary
* device such as a cassette, another computer, etc.  The program
* is converted to an easily-stored format: each line starts with
* a colon, the line no. as 4 hex digits, and the rest of the line.
* At the end, a line starting with an '@' sign is sent.  This
* format can be read back with a minimum of processing time by
* the 68000.
*
LOAD	
	MOVE.L TXTBGN,A0	set pointer to start of prog. area
	MOVE.B #CR,D0		For a CP/M host, tell it we're ready...
	BSR	GOAUXO		by sending a CR to finish PIP command.
LOD1	
	BSR	GOAUXI		look for start of line
	BEQ	LOD1
	CMP.B	#'@',D0         end of program?
	BEQ	LODEND
	CMP.B	#':',D0         if not, is it start of line?
	BNE	LOD1		if not, wait for it
	BSR	GBYTE		get first byte of line no.
	MOVE.B	D1,(A0)+	store it
	BSR	GBYTE		get 2nd bye of line no.
	MOVE.B	D1,(A0)+	store that, too
LOD2
	BSR	GOAUXI		get another text char.
	BEQ	LOD2
	MOVE.B	D0,(A0)+	store it
	CMP.B	#CR,D0		is it the end of the line?
	BNE	LOD2		if not, go back for more
	BRA	LOD1		if so, start a new line
LODEND
	MOVE.L	A0,TXTUNF	set end-of program pointer
	BRA	WSTART		back to direct mode

GBYTE
	MOVEQ	#1,D2		get two hex characters from auxiliary
	CLR.L	D1		and store them as a byte in D1
GBYTE1	
	BSR	GOAUXI		get a char.
	BEQ	GBYTE1
	CMP.B	#'A',D0
	BCS	GBYTE2
	SUBQ.B	#7,D0		if greater than 9, adjust
GBYTE2
	AND.B	#$F,D0		strip ASCII
	LSL.B	#4,D1		put nybble into the result
	OR.B	D0,D1
	DBRA	D2,GBYTE1	get another char.
	RTS

SAVE
	MOVE.L	TXTBGN,A0	set pointer to start of prog. area
	MOVE.L	TXTUNF,A1	set pointer to end of prog. area
SAVE1	
	MOVE.B	#CR,D0		send out a CR & LF (CP/M likes this)
	BSR	GOAUXO
	MOVE.B	#LF,D0
	BSR	GOAUXO
	CMP.L	A0,A1		are we finished?
	BLS	SAVEND
	MOVE.B	#':',D0         if not, start a line
	BSR	GOAUXO
	MOVE.B	(A0)+,D1	send first half of line no.
	BSR	PBYTE
	MOVE.B	(A0)+,D1	and send 2nd half
	BSR	PBYTE
SAVE2
	MOVE.B	(A0)+,D0	get a text char.
	CMP.B	#CR,D0		is it the end of the line?
	BEQ	SAVE1		if so, send CR & LF and start new line
	BSR	GOAUXO		send it out
	BRA	SAVE2		go back for more text
SAVEND
	MOVE.B	#'@',D0         send end-of-program indicator
	BSR	GOAUXO
	MOVE.B	#CR,D0		followed by a CR & LF
	BSR	GOAUXO
	MOVE.B	#LF,D0
	BSR	GOAUXO
	MOVE.B	#$1A,D0 	and a control-Z to end the CP/M file
	BSR	GOAUXO
	BRA	WSTART		then go do a warm start

PBYTE	MOVEQ	#1,D2		send two hex characters from D1's low byte
PBYTE1	ROL.B	#4,D1		get the next nybble
	MOVE.B	D1,D0
	AND.B	#$F,D0		strip off garbage
	ADD.B	#'0',D0         make it into ASCII
	CMP.B	#'9',D0
	BLS	PBYTE2
	ADDQ.B	#7,D0		adjust if greater than 9
PBYTE2	BSR	GOAUXO		send it out
	DBRA	D2,PBYTE1	then send the next nybble
	RTS

*******************************************************************
*
* *** POKE *** & CALL ***
*
* 'POKE expr1,expr2' stores the byte from 'expr2' into the memory
* address specified by 'expr1'.
*
* 'CALL expr' jumps to the machine language subroutine whose
* starting address is specified by 'expr'.  The subroutine can use
* all registers but must leave the stack the way it found it.
* The subroutine returns to the interpreter by executing an RTS.
*
POKE
	move.b #'B',d7
	move.b (a0),d1
	cmpi.b #'.',d1
	bne .0001
	addq #1,a0
	move.b (a0),d1
	cmpi.b #'B',d1
	beq .0002
	cmpi.b #'W',d1
	beq .0002
	cmpi.b #'L',d1
	beq .0002
	cmpi.b #'F',d1
	bne	PKER
.0002
	addq #1,a0
	move.b d1,d7
.0001
	BSR	INT_EXPR		get the memory address
	bsr	TSTC		it must be followed by a comma
	DC.B	',',PKER-*
	move.l d0,-(sp)		; save the address
	BSR	NUM_EXPR			; get the value to be POKE'd
	move.l	(sp)+,a1	; get the address back
	CMPI.B #'B',D7
	BNE .0003
	FMOVE.B	FP0,(A1) 	store the byte in memory
	BRA	FINISH
.0003
	CMPI.B #'W',d7
	BNE .0004
	FMOVE.W FP0,(A1)
	BRA FINISH
.0004
	CMPI.B #'L',D7
	BNE .0005
	FMOVE.L FP0,(A1)
	BRA FINISH
.0005
	CMPI.B #'F',D7
	BNE .0006
	FMOVE.X FP0,(A1)
	BRA FINISH
.0006
PKER
	BRA	QWHAT		if no comma, say "What?"

CALL	
	BSR	INT_EXPR		; get the subroutine's address
	TST.l d0				; make sure we got a valid address
	BEQ QHOW				; if not, say "How?"
	MOVE.L A0,-(SP)	; save the text pointer
	MOVE.L D0,A1
	JSR	(A1)				; jump to the subroutine
	MOVE.L (SP)+,A0	; restore the text pointer
	BRA	FINISH

;******************************************************************
;
; *** EXPR ***
;
; 'EXPR' evaluates arithmetical or logical expressions.
; <EXPR>::=<EXPR2>
;	   <EXPR2><rel.op.><EXPR2>
; where <rel.op.> is one of the operators in TAB8 and the result
; of these operations is 1 if true and 0 if false.
; <EXPR2>::=(+ or -)<EXPR3>(+ or -)<EXPR3>(...
; where () are optional and (... are optional repeats.
; <EXPR3>::=<EXPR4>( <* or /><EXPR4> )(...
; <EXPR4>::=<variable>
;	    <function>
;	    (<EXPR>)
; <EXPR> is recursive so that the variable '@' can have an <EXPR>
; as an index, functions can have an <EXPR> as arguments, and
; <EXPR4> can be an <EXPR> in parenthesis.

;-------------------------------------------------------------------------------
; Push a value on the stack.
;-------------------------------------------------------------------------------

XP_PUSH:
	move.l (sp)+,a1				; a1 = return address
	move.l _canary,-(sp)	; push the canary
	sub.l #16,sp					; allocate for value
	move.l d0,(sp)				; push data type
	fmove.x fp0,4(sp)			; and value
	jmp (a1)

;-------------------------------------------------------------------------------
; Pop value from stack into first operand.
;-------------------------------------------------------------------------------
	
XP_POP:
	move.l (sp)+,a1			; get return address
	move.l (sp),d0			; pop data type
	fmove.x 4(sp),fp0		; and data element
	add.l #16,sp
	cchk (sp)						; check the canary
	add.l #4,sp					; pop canary	
	jmp (a1)

;-------------------------------------------------------------------------------
; Pop value from stack into second operand.
;-------------------------------------------------------------------------------

XP_POP1:
	move.l (sp)+,a1			; get return address
	move.l (sp),d1			; pop data type
	fmove.x 4(sp),fp1		; and data element
	add.l #16,sp
	cchk (sp)						; check the canary
	add.l #4,sp					; pop canary
	jmp (a1)

;-------------------------------------------------------------------------------
; Get and expression and make sure it is numeric.
;-------------------------------------------------------------------------------

NUM_EXPR:
	bsr EXPR
	cmpi.l #DT_NUMERIC,d0
	bne ETYPE
	rts

;-------------------------------------------------------------------------------
; Get and expression and make sure it is numeric. Convert to integer.
;-------------------------------------------------------------------------------

INT_EXPR:
	bsr EXPR
	cmpi.l #DT_NUMERIC,d0
	bne ETYPE
	fmove.l fp0,d0
	rts

;-------------------------------------------------------------------------------
; The top level of the expression parser.
; Get an expression, string or numeric.
;
; EXEC will smash a lot of regs, so push the current expression value before
; doing EXEC
;-------------------------------------------------------------------------------

EXPR:
EXPR_OR:
	BSR EXPR_AND
	BSR XP_PUSH
	LEA TAB10,A1
	LEA TAB10_1,A2
	BRA EXEC
	
;-------------------------------------------------------------------------------
; Boolean 'Or' level
;-------------------------------------------------------------------------------

XP_OR:
	BSR EXPR_AND
	bsr XP_POP1
	bsr CheckNumeric
	FMOVE.L FP1,D1
	FMOVE.L FP0,D0
	OR.L D1,D0
	FMOVE.L D0,FP0
	rts
	
;-------------------------------------------------------------------------------
; Boolean 'And' level
;-------------------------------------------------------------------------------

EXPR_AND:
	bsr EXPR_REL
	bsr XP_PUSH
	LEA TAB9,A1
	LEA TAB9_1,A2
	BRA EXEC

XP_AND:
	BSR EXPR_REL
	bsr XP_POP1
	bsr CheckNumeric
	FMOVE.L FP1,D1
	FMOVE.L FP0,D0
	AND.L D1,D0
	FMOVE.L D0,FP0
	RTS
	
XP_ANDX:
XP_ORX
	bsr XP_POP
	rts

;-------------------------------------------------------------------------------
; Check that two numeric values are being used.
;-------------------------------------------------------------------------------

CheckNumeric:
	CMPI.B #DT_NUMERIC,D1
	BNE ETYPE
	CMPI.B #DT_NUMERIC,D0
	BNE ETYPE
	RTS

;-------------------------------------------------------------------------------
; Relational operator level, <,<=,>=,>,=,<>
;-------------------------------------------------------------------------------

EXPR_REL:
	bsr	EXPR2
	bsr XP_PUSH
	LEA	TAB8,A1 				; look up a relational operator
	LEA	TAB8_1,A2
	bra	EXEC		go do it

XP11:
	bsr XP_POP
	BSR	XP18		is it ">="?
	FBLT XPRT0		no, return D0=0
	BRA	XPRT1		else return D0=1

XP12:
	bsr XP_POP
	BSR	XP18		is it "<>"?
	FBEQ XPRT0		no, return D0=0
	BRA	XPRT1		else return D0=1

XP13:
	bsr XP_POP
	BSR	XP18		is it ">"?
	FBLE XPRT0		no, return D0=0
	BRA	XPRT1		else return D0=1

XP14:
	bsr XP_POP
	BSR	XP18		;is it "<="?
	FBGT XPRT0	;	no, return D0=0
	BRA	XPRT1		;else return D0=1

XP15:
	bsr XP_POP
	BSR	XP18		; is it "="?
	FBNE XPRT0	;	if not, return D0=0
	BRA	XPRT1		;else return D0=1
XP15RT
	RTS

XP16:
	bsr XP_POP
	BSR	XP18		; is it "<"?
	FBGE XPRT0	;	if not, return D0=0
	BRA	XPRT1		; else return D0=1
	RTS

XPRT0:
	FMOVE.B #0,FP0	; return fp0 = 0 (false)
	RTS

XPRT1:
	FMOVE.B #1,FP0	; return fp0 = 1 (true)
	RTS

XP17:								; it's not a rel. operator
	bsr XP_POP				;	return FP0=<EXPR2>
	rts

XP18:
	bsr XP_PUSH
	bsr	EXPR2					; do second <EXPR2>
	bsr XP_POP1
	bsr CheckNumeric
	fcmp fp0,fp1			; compare with the first result
	rts								; return the result

;-------------------------------------------------------------------------------
; Add/Subtract operator level, +,-
;-------------------------------------------------------------------------------

EXPR2
	bsr	TSTC		; negative sign?
	DC.B	'-',XP21-*
	FMOVE.B #0,FP0
	BRA	XP26
XP21	
	bsr	TSTC		; positive sign? ignore it
	DC.B	'+',XP22-*
XP22
	BSR	EXPR3		; first <EXPR3>
XP23
	bsr	TSTC		; add?
	DC.B	'+',XP25-*
	bsr XP_PUSH
	BSR	EXPR3					; get the second <EXPR3>
XP24
	bsr XP_POP1
	CMP.B #DT_NUMERIC,d0
	BNE .notNum
	CMP.B #DT_NUMERIC,d1
	BNE .notNum
	FADD FP1,FP0			; add it to the first <EXPR3>
;	FBVS	QHOW		branch if there's an overflow
	BRA	XP23		else go back for more operations
.notNum
	cmp.l #DT_STRING,d0
	bne ETYPE
	cmp.l #DT_STRING,d1
	bne ETYPE
	bsr ConcatString
	rts

XP25
	bsr	TSTC							; subtract?
	dc.b	'-',XP27-*
XP26
	bsr XP_PUSH
	BSR	EXPR3					; get second <EXPR3>
	cmpi.b #DT_NUMERIC,d0
	bne ETYPE
	FNEG FP0					; change its sign
	JMP	XP24					; and do an addition

XP27
	rts

;-------------------------------------------------------------------------------
; Concatonate strings, for the '+' operator.
;
; Parameters:
;		fp0 = holds string descriptor for second string
;		fp1 = holds string descriptor for first string
;	Returns:
;		fp0 = string descriptor for combined strings
;-------------------------------------------------------------------------------

ConcatString:
	fmove.x fp1,_fpWork		; save first string descriptor to memory
	fmove.x fp0,_fpWork+16; save second string descriptor to memory
	move.w _fpWork,d2			; d2 = length of first string
	add.w	_fpWork+16,d2		; add length of second string
	ext.l d2							; make d2 a long word
	bsr AllocateString		; allocate
	move.l a1,a4					; a4 = allocated string, saved for later
	move.l a1,a2					; a2 = allocated string
	move.w d2,-2(a2)			; save length of new string (a2)
	move.l _fpWork+4,a1		; a1 = pointer to string text of first string
	move.l a1,a3					; compute pointer to end of first string
	move.w _fpWork,d3			; d3 = length of first string
	ext.l d3
	add.l d3,a3						; add length of first string
	bsr MVUP							; move from A1 to A2 until A1=A3
	move.l _fpWork+20,a1	; a1 = pointer to second string text
	move.l a1,a3
	move.w _fpWork+16,d3	; d3 = length of second string
	ext.l d3
	add.l d3,a3						; a3 points to end of second string
	bsr MVUP							; concatonate on second string
	move.w d2,_fpWork			; save total string length in fp work
	move.l a4,_fpWork+4		; save pointer in fp work area
	moveq #DT_STRING,d0		; set return data type = string
	fmove.x _fpWork,fp0		; fp0 = string descriptor
	rts

;-------------------------------------------------------------------------------
; Multiply / Divide operator level, *,/,mod
;-------------------------------------------------------------------------------

EXPR3
	bsr	EXPR4					; get first <EXPR4>
XP36
	bsr XP_PUSH
XP30
	lea TAB11,a1
	lea TAB11_1,a2
	bra EXEC
XP31
	bsr	TSTC					; multiply?
	dc.b	'*',XP34-*
	bsr	EXPR4					; get second <EXPR4>
	bsr XP_POP1
	bsr CheckNumeric
	fmul fp1,fp0			; multiply the two
	bra	XP36					; then look for more terms
XP34
	bsr	TSTC					; divide?
	dc.b	'/',XP35-*
	bsr	EXPR4					; get second <EXPR4>
	bsr XP_POP1
	bsr CheckNumeric
	fdiv fp0,fp1			; do the division
	fmove fp1,fp0
	bra	XP36					; go back for any more terms
XP35
	bsr XP_POP
	rts
XP_MOD:
	bsr EXPR4
	bsr XP_POP1
	fdiv fp0,fp1			; divide
	fmove.l fp1,d0		; convert to integer
	fmove.l d0,fp3		; convert back to float
	fmul fp0,fp3			; multiply quotient times divisor
	fsub fp3,fp1			; subtract from original number
	fmove.x fp1,fp0		; return difference in fp0
	moveq #DT_NUMERIC,d0
	bra XP36					; go back and check for more multiply ops
	
;-------------------------------------------------------------------------------
; Lowest Level of expression evaluation.
;	Check for
;		a function or
;		a variable or
;		a number or
;		a string or
;		( expr )
;-------------------------------------------------------------------------------

EXPR4
	LEA	TAB4,A1 			; find possible function
	LEA	TAB4_1,A2
	BRA	EXEC
XP40
	bsr	TSTV					; nope, not a function
	bcs	XP41					; nor a variable
	move.l d0,a1			; a1 = variable address
	move.l (a1),d0		; return type in d0
	fmove.x 4(a1),fp0	; if a variable, return its value in fp0
EXP4RT
	rts
XP41
	bsr	TSTNUM				; or is it a number?
	fmove fp1,fp0
	cmpi.l #DT_NUMERIC,d0
	beq	EXP4RT				; if so, return it in FP0
XPSTNG
	bsr TSTC					; is it a string constant?
	dc.b '"',XP44-*
	move.b #'"',d3
XP45
	move.l a0,a1			; record start of string in a1
	move.l #511,d2		; max 512 characters
.0003	
	move.b (a0)+,d0		; get a character
	beq .0001					; should not be a NULL
	cmpi.b #CR,d0			; CR means the end of line was hit without a close quote
	beq .0001
	cmp.b d3,d0				; close quote?
	beq .0002
	dbra d2,.0003			; no close quote, go back for next char
.0001
	bra QHOW
.0002
	move.l a0,d0				; d0 = end of string pointer
	sub.l a1,d0					; compute string length + 1
	subq #1,d0					; subtract out closing quote
	move.l d0,d2				; d2 = string length
	move.l a1,a3				; a3 = pointer to string text
	bsr AllocateString
	move.l a1,a2				; a2 points to new text area
	move.l a1,a4				; save a1 for later
	move.l a3,a1				; a1 = pointer to string in program
	move.w d2,-2(a2)		; copy length into place
	add.l d2,a3					; a3 points to end of string
	bsr MVUP						; move from A1 to A2 until A1=A3
	move.w d2,_fpWork		; copy length into place
	move.l a4,_fpWork+4	; copy pointer to text into place
	fmove.x _fpWork,fp0	; put string descriptor into fp0
	moveq #DT_STRING,d0	; return string data type
	rts
XP44
	bsr TSTC					; alternate string constant?
	dc.b '''',PARN-*
	move.b #'''',d3
	bra XP45
PARN
	bsr	TSTC					; else look for ( EXPR )
	dc.b '(',XP43-*
	bsr	EXPR
	bsr	TSTC
	dc.b ')',XP43-*
XP42	
	rts
XP43
	bra	QWHAT					; else say "What?"

;-------------------------------------------------------------------------------	
; Allocate storage for a string variable.
;
; Parameters:
;		d2 = number of bytes needed
; Returns:
;		a1 = pointer to string text area
;-------------------------------------------------------------------------------	

AllocateString:
	movem.l d2-d4/a2-a5,-(sp)
	move.l VARBGN,d4
	move.l LastStr,a1			; a1 = last string
	move.w (a1),d3				; d3 = length of last string (0)
	ext.l d3
	sub.l d3,d4						; subtract off length
	subq.l #3,d4					; size of length field+1 for rounding
	sub.l a1,d4						; and start position
	cmp.l d4,d2						; is there enough room?
	bhi .needMoreRoom
.0001
	move.l LastStr,a1
	move.l a1,a3
	addq.l #2,a1					; point a1 to text part of string
	move.w d2,(a3)				; save the length
	add.l d2,a3
	addq.l #3,a3					; 2 for length field, 1 for rounding
	move.l a3,d3
	andi.l #$FFFFFFFE,d3	; make pointer even wyde
	move.l a3,LastStr			; set new last str position
	clr.w (a3)						; set zero length
	movem.l (sp)+,d2-d4/a2-a5
	rts
.needMoreRoom
	bsr GarbageCollectStrings
	move.l VARBGN,d4			; d4 = start of variables
	move.l LastStr,a1			; a1 = pointer to last string
	move.w (a1),d3				; d3 = length of last string (likely 0)
	ext.l d3
	add.l a1,d3						; d3 = pointer past end of last string
	addq.l #3,d3					; 2 for length, 1 for rounding
	sub.l d3,d4						; free = VARBGN - LastStr+length of (LastStr)
	cmp.l d4,d2						; request < free?
	blo .0001
	lea NOSTRING,a6
	bra ERROR
		
;-------------------------------------------------------------------------------	
; Garbage collect strings. This copies all strings in use to the lower end of
; the string area and adjusts the string pointers in variables and on the
; stack to point to the new location.
;
; Modifies:
;		none
;-------------------------------------------------------------------------------	

GarbageCollectStrings:
	movem.l a1/a2/a3/a5,-(sp)
	move.l StrArea,a1			; source area pointer
	move.l StrArea,a2			; target area pointer
	move.l LastStr,a5
.0001
	bsr StringInVar				; check if the string is used by a variable
	bcs .moveString
	bsr StringOnStack			; check if string is on string expression stack
	bcc .nextString				; if not on stack or in a var then move to next string
	
	; The string is in use, copy to active string area
.moveString:
	bsr UpdateStringPointers	; update pointer to string on stack or in variable
	bsr NextString				; a3 = pointer to next string
	bsr MVUPW							; will copy the length and string text
.0005
	cmp.l a5,a1						; is it the last string?
	bls .0001
	move.l a2,LastStr			; update last string pointer
	clr.w (a2)						; set zero length
	movem.l (sp)+,a1/a2/a3/a5
	rts
.nextString:
	bsr NextString
	move.l a3,a1
	bra .0005

;-------------------------------------------------------------------------------	
; Parameters:
;		a1 - pointer to current string
; Returns:
;		a3 - pointer to next string
;-------------------------------------------------------------------------------	

NextString:
	move.l d4,-(sp)
	move.w (a1),d4				; d4 = string length
	ext.l d4							; make d4 long
	addq.l #3,d4					; plus 2 for length field, 1 for rounding
	add.l a1,d4
	andi.l #$FFFFFFFE,d4	; make even wyde address
	move.l d4,a3
	move.l (sp)+,d4
	rts

;-------------------------------------------------------------------------------	
; Check if a variable is using a string
;
; Modifies:
;		d2,d3,a4
; Parameters:
;		a1 = pointer to string descriptor
; Returns:
;		cf = 1 if string in use, 0 otherwise
;-------------------------------------------------------------------------------	

StringInVar:
	; check global vars
	move.l VARBGN,a4
	moveq #31,d3			; 32 vars
	bsr SIV1
	; now check local vars
	move.l STKFP,a4
.0001
	addq.l #4,a4			; point to variable area
	moveq #7,d3
	bsr SIV1					; check variable area
	move.l -4(a4),a4	; get previous frame pointer
	cmp.l ENDMEM,a4
	blo .0001
	rts

;-------------------------------------------------------------------------------	
; SIV1 - string in variable helper. This routine does a two-up return if the
; string is found in a variable. No need to keep searching.
;
; Modifies:
;		d2,d3,a4
; Parameters:
;		d3 = number of variables-1 to check
;		a4 = string space
;		a1 = pointer to string descriptor
; Returns:
;		cf = 1 if string in use, 0 otherwise
;-------------------------------------------------------------------------------	

SIV1:
.0003
	cmp.l #DT_STRING,(a4)
	bne .0004
	move.l 8(a4),d2
	subq.l #2,d2
	cmp.l d2,a1
	bne .0004
	addq.l #4,sp			; pop return address
	ori #1,ccr
	rts								; do two up return
.0004
	addq.l #8,a4			;  increment pointer by 16
	addq.l #8,a4
	dbra d3,.0003
	andi #$FE,ccr
	rts

;-------------------------------------------------------------------------------	
; Check if a value could be a pointer into the string area.
; Even if the data type indicated a string, it may not be. It could just be a
; coincidence. So check that the pointer portion is pointing into string
; memory. It is extremely unlikely to have a data type and a valid pointer
; match and it not be a string.
;
; Returns
;		d3 = pointer to string
;		cf=1 if points into string area, 0 otherwise
;-------------------------------------------------------------------------------	

PointsIntoStringArea:
	cmp.l #DT_STRING,(a4)		; is it a string data type?
	bne .0001
	move.l 8(a4),d3					; likely a string if
	cmp.l StrArea,d3				; flagged as a string, and pointer is into string area
	blo .0001
	cmp.l VARBGN,d3
	bhs .0001
	ori #1,ccr
	rts
.0001
	andi #$FE,ccr
	rts

;-------------------------------------------------------------------------------	
; Check if the string is a temporary on stack
;
; Parameters:
;		a3 = pointer to old string text area
; Returns:
;		cf = 1 if string in use, 0 otherwise
;-------------------------------------------------------------------------------	

StringOnStack:
	movem.l d2/a2/a4,-(sp)
	moveq #7,d3
	move.l sp,a4
.0002
	bsr PointsIntoStringArea
	bcc .0003
	move.l 8(a4),d2			; d2 = string text pointer
	cmp.l d2,a3					; compare string pointers
	beq .0001						; same pointer?
.0003
	addq.l #4,a4				; bump pointer into stack
	cmp.l ENDMEM,a4			; have we hit end of stack yet?
	blo .0002
	movem.l (sp)+,d2/a2/a4
	andi #$FE,ccr
	rts
.0001
	movem.l (sp)+,d2/a2/a4
	ori #1,ccr
	rts
	
;-------------------------------------------------------------------------------	
; Update pointers to string to point to new area. All string areas must be
; completely checked because there may be more than one pointer to the string.
;
; Modifies:
;		d2,d3,d4,a4
; Parameters:
;		a1 = old pointer to string
;		a2 = new pointer to string
;-------------------------------------------------------------------------------	

UpdateStringPointers:
	move.l a3,-(sp)
	lea 2(a1),a3						; a3 points to old string text area
	; check global variable space
	move.l VARBGN,a4
	moveq #31,d3						; 32 vars to check
	bsr USP1
	; check stack for strings
	move.l sp,a4						; start at stack bottom and work towards top
.0002
	bsr PointsIntoStringArea
	bcc .0001
	; Here we probably have a string, one last check
	cmp.l a2,d3							; should be >= a2 as we are packing the space
	blo .0001
	move.l a2,8(a4)					; update pointer on stack with new address
	addi.w #2,8(a4)					; bump up to text part of string
.0001
	addq.l #4,a4
	cmp.l ENDMEM,a4
	blo .0002
	move.l (sp)+,a3
	rts

;-------------------------------------------------------------------------------	
; Both global and local variable spaces are updated in the same manner.
;
; Parameters:
;		a1 = old pointer to string
;		a2 = new pointer to string
;		a4 = start of string space
;		d3 = number of string variables
;-------------------------------------------------------------------------------	

USP1:
.0002
	cmp.l #DT_STRING,(a4)		; check the data type
	bne .0001								; not a string, go to next
	move.l 8(a4),d2					; d2 = pointer to string text
	cmp.l d2,a3							; does pointer match old pointer?
	bne .0001
	move.l a2,8(a4)					; copy in new pointer
	addi.l #2,8(a4)					; point to string text
.0001
	addq.l #8,a4						; increment pointer by 16
	addq.l #8,a4
	dbra d3,.0002
	rts

;-------------------------------------------------------------------------------	
; ===== Test for a valid variable name.  Returns Carry=1 if not
;	found, else returns Carry=0 and the address of the
;	variable in D0.

TSTV:
	bsr	IGNBLK
	CLR.L	D0
	MOVE.B (A0),D0 	 	; look at the program text
	SUB.B	#'@',D0
	BCS	TSTVRT				; C=1: not a variable
	BNE	TV1						; branch if not "@" array
	ADDQ #1,A0				; If it is, it should be
	BSR	PARN					; followed by (EXPR) as its index.
	ADD.L	D0,D0
	BCS	QHOW					; say "How?" if index is too big
	ADD.L	D0,D0
	BCS	QHOW
	ADD.L	D0,D0
	BCS	QHOW
	ADD.L	D0,D0
	BCS	QHOW
	move.l d0,-(sp)		; save the index
	bsr	SIZE					; get amount of free memory
	move.l (sp)+,d1		; get back the index
	fmove.l fp0,d0		; convert to integer
	cmp.l	d1,d0				; see if there's enough memory
	bls	QSORRY				; if not, say "Sorry"
	move.l VARBGN,d0	; put address of array element...
	sub.l	d1,d0				; into D0
	rts
TV1
	CMP.B	#27,D0			; if not @, is it A through Z?
	EOR	#1,CCR
	BCS	TSTVRT				; if not, set Carry and return
	ADDQ #1,A0				; else bump the text pointer
	cmpi.b #'L',d0		; is it a local? L0 to L7
	bne TV2
	move.b (a0),d0
	cmpi.b #'0',d0
	blo TV2
	cmpi.b #'7',d0
	bhi TV2
	sub.b #'0',d0
	addq #1,a0			; bump text pointer
	lsl.l #4,d0			; *16 bytes per var
	add.l STKFP,d0
	add.l #4,d0
	rts
TV2
	LSL.L #4,D0			; compute the variable's address
	MOVE.L VARBGN,D1
	ADD.L	D1,D0			; and return it in D0 with Carry=0
TSTVRT
	RTS


* ===== Divide the 32 bit value in D0 by the 32 bit value in D1.
*	Returns the 32 bit quotient in D0, remainder in D1.
*
DIV32
	TST.L	D1		check for divide-by-zero
	BEQ	QHOW		if so, say "How?"
	MOVE.L	D1,D2
	MOVE.L	D1,D4
	EOR.L	D0,D4		see if the signs are the same
	TST.L	D0		take absolute value of D0
	BPL	DIV1
	NEG.L	D0
DIV1	TST.L	D1		take absolute value of D1
	BPL	DIV2
	NEG.L	D1
DIV2	MOVEQ	#31,D3		iteration count for 32 bits
	MOVE.L	D0,D1
	CLR.L	D0
DIV3	ADD.L	D1,D1		(This algorithm was translated from
	ADDX.L	D0,D0		; the divide routine in Ron Cain's
	BEQ	DIV4		Small-C run time library.)
	CMP.L	D2,D0
	BMI	DIV4
	ADDQ.L	#1,D1
	SUB.L	D2,D0
DIV4	DBRA	D3,DIV3
	EXG	D0,D1		put rem. & quot. in proper registers
	TST.L	D4		were the signs the same?
	BPL	DIVRT
	NEG.L	D0		if not, results are negative
	NEG.L	D1
DIVRT	RTS


; ===== The PEEK function returns the byte stored at the address
;	contained in the following expression.

PEEK
	MOVE.B #'B',d7
	MOVE.B (a0),d1
	CMPI.B #'.',d1
	BNE .0001
	ADDQ #1,a0
	move.b (a0)+,d7
.0001
	BSR	PARN		get the memory address
	cmpi.l #DT_NUMERIC,d0
	bne ETYPE
	FMOVE.L FP0,D0
	MOVE.L D0,A1
	cmpi.b #'B',d7
	bne .0002
.0005
	CLR.L	D0				; upper 3 bytes will be zero
	MOVE.B (A1),D0
	FMOVE.B	D0,FP0 	; get the addressed byte
	moveq #DT_NUMERIC,d0					; data type is a number
	RTS							; and return it
.0002
	cmpi.b #'W',d7
	bne .0003
	CLR.L d0
	MOVE.W (A1),D0
	FMOVE.W	D0,FP0	;	get the addressed word
	moveq #DT_NUMERIC,d0					; data type is a number
	RTS							; and return it
.0003
	cmpi.b #'L',d7
	bne .0004
	CLR.L d0
	MOVE.L (A1),D0
	FMOVE.L	D0,FP0 	; get the lword
	moveq #DT_NUMERIC,d0					; data type is a number
	RTS							; and return it
.0004
	cmpi.b #'F',d7
	bne .0005
	FMOVE.X	(A1),FP0 		; get the addressed float
	moveq #DT_NUMERIC,d0					; data type is a number
	RTS			and return it

;-------------------------------------------------------------------------------
; The RND function returns a random number from 0 to the value of the following
; expression in fp0.
;-------------------------------------------------------------------------------

RND:
	bsr	PARN								; get the upper limit
	cmpi.l #DT_NUMERIC,d0		; must be numeric
	bne ETYPE
	ftst.x fp0							; it must be positive and non-zero
	fbeq QHOW
	fblt QHOW
	fmove fp0,fp2
	moveq #40,d0						; function #40 get random float
	trap #15
	fmul fp2,fp0
	moveq #DT_NUMERIC,d0		; data type is a number
	rts

; ===== The ABS function returns an absolute value in D0.

ABS:	
	bsr	PARN			; get the following expr.'s value
	fabs.x fp0
	moveq #DT_NUMERIC,d0					; data type is a number
	rts

; ===== The SIZE function returns the size of free memory in D0.

SIZE:
	move.l StrArea,d0		; get the number of free bytes...
	sub.l	 TXTUNF,d0		; between 'TXTUNF' and 'StrArea'
	fmove.l d0,fp0
	moveq #DT_NUMERIC,d0	; data type is a number
	rts										; return the number in fp0
	
; ===== The TICK function returns the processor tick register in D0.

TICK:
	movec tick,d0
	fmove.l d0,fp0
	moveq #DT_NUMERIC,d0					; data type is a number
	rts

; ===== The CORENO function returns the core number in D0.

CORENO:
	movec coreno,d0
	fmove.l d0,fp0
	moveq #DT_NUMERIC,d0					; data type is a number
	rts

;-------------------------------------------------------------------------------
; Get a pair of argments for the LEFT$ and RIGHT$ functions.
; 	(STRING, NUM)
; Returns:
;		fp0 = number
;		fp1 = string
;-------------------------------------------------------------------------------

LorRArgs:
	bsr	TSTC						; else look for ( STRING EXPR, NUM EXPR )
	dc.b	'(',LorR1-*
	bsr	EXPR
	cmpi.l #DT_STRING,d0
	bne ETYPE
	bsr XP_PUSH
	bsr TSTC
	dc.b ',',LorR1-*
	bsr EXPR
	cmpi.l #DT_NUMERIC,d0
	bne ETYPE
	bsr	TSTC
	dc.b	')',LorR1-*
	bsr XP_POP1
	rts
LorR1
	bra QHOW
	
;-------------------------------------------------------------------------------
; MID$ function gets a substring of characters from start position for
; requested length.
;-------------------------------------------------------------------------------

MID:
	bsr	TSTC						; look for ( STRING EXPR, NUM EXPR [, NUM_EXPR] )
	dc.b	'(',MID1-*
	bsr	EXPR
	cmpi.l #DT_STRING,d0
	bne ETYPE
	bsr XP_PUSH
	bsr TSTC
	dc.b ',',MID1-*
	bsr EXPR
	cmpi.l #DT_NUMERIC,d0
	bne ETYPE
	bsr XP_PUSH
	moveq #2,d5
	bsr	TSTC
	dc.b ',',MID2-*
	bsr EXPR
	cmpi.l #DT_NUMERIC,d0
	bne ETYPE
	moveq #3,d5					; d5 indicates 3 params
MID2
	bsr TSTC
	dc.b ')',MID1-*
	bsr XP_POP1
	cmpi.b #3,d5				; did we have 3 arguments?
	beq MID5						; branch if did
	fmove.l #$FFFF,fp0	; set length = max
MID5
	fmove.x fp1,fp2			; fp2 = start pos
	bsr XP_POP1					; fp1 = string descriptor
;-------------------------------------------------------------------------------
; Perform MID$ function
; 	fp1 = string descriptor
; 	fp2 = starting position
; 	fp0 = length
;-------------------------------------------------------------------------------
DOMID
	fmove.x fp1,_fpWork	; _fpWork = string descriptor
	fmove.l fp2,d3			; d3 = start pos
	cmp.w _fpWork,d3		; is start pos < length
	bhs QHOW
	fmove.l fp0,d2			; d2=length
	add.l d2,d3					; start pos + length < string length?
	cmp.w _fpWork,d2
	bls MID4
	move.w _fpWork,d2		; move string length to d2
	ext.l d2
MID4
	bsr AllocateString	; a1 = pointer to new string
	move.l a1,a2				; a2 = pointer to new string
	move.l _fpWork+4,a1	; a1 = pointer to string
	fmove.l fp2,d3			; d3 = start pos
	add.l d3,a1					; a1 = pointer to start pos
	move.w d2,_fpWork		; length
	move.l a2,_fpWork+4	; prep to return target string
	move.l a1,a3				; a3 = pointer to start pos
	add.l d2,a3					; a3 = pointer to end pos
	bsr MVUP						; move A1 to A2 until A1 = A3
	moveq #DT_STRING,d0	; data type is a string
	fmove.x _fpWork,fp0	; string descriptor in fp0
	rts
MID1
	bra QHOW
	
;-------------------------------------------------------------------------------
; LEFT$ function truncates the string after fp0 characters.
; Just like MID$ but with a zero starting postion.
;-------------------------------------------------------------------------------
	
LEFT:
	bsr LorRArgs				; get arguments
	fmove.b #0,fp2			; start pos = 0
	bra DOMID

;-------------------------------------------------------------------------------
; RIGHT$ function gets the rightmost characters.
; The start position must be calculated based on the number of characters
; requested and the string length.
;-------------------------------------------------------------------------------

RIGHT:
	bsr LorRArgs				; get arguments
	fmove.l fp0,d2			; d2 = required length
	fmove.x fp1,_fpWork	; _fpWork = string descriptor
	move.w _fpWork,d3		; d3 = string length
	ext.l d3						; make d3 a long
	cmp.l d2,d3					; is length > right
	bhi .0001
	moveq #0,d2					; we want all the characters if length <= right
.0001
	sub.l d2,d3					; d3 = startpos = length - right
	fmove.l d3,fp2			; fp2 = start position
	bra DOMID

;-------------------------------------------------------------------------------
; LEN( EXPR ) returns the length of a string expression.
;-------------------------------------------------------------------------------

LEN:
	bsr PARN
	cmpi.l #DT_STRING,d0
	bne ETYPE
	fmove.x fp0,_fpWork
	move.w _fpWork,d0
	ext.l d0
	fmove.w d0,fp0
	moveq #DT_NUMERIC,d0
	rts

;-------------------------------------------------------------------------------
; INT( EXPR ) returns the integer value of the expression.
; the expression must be in the range of a 32-bit integer.
;-------------------------------------------------------------------------------

INT:
	bsr PARN
	cmpi.l #DT_NUMERIC,d0
	bne ETYPE
	fintrz fp0,fp0
;	fmove.l fp0,d0
;	fmove.l d0,fp0
	moveq #DT_NUMERIC,d0
	rts


;-------------------------------------------------------------------------------
; CHR$( EXPR ) returns a one byte string containing the character.
;-------------------------------------------------------------------------------

CHR:
	bsr PARN
	cmpi.l #DT_NUMERIC,d0
	bne ETYPE
	fmove.l fp0,d0
	moveq #1,d2
	bsr AllocateString
	move.b d0,(a1)
	clr.b 1(a1)
	moveq #DT_STRING,d0
	move.l a1,_fpWork+4
	move.w #1,_fpWork
	fmove.x _fpWork,fp0
	rts

********************************************************************
*
* *** SETVAL *** FIN *** ENDCHK *** ERROR (& friends) ***
*
* 'SETVAL' expects a variable, followed by an equal sign and then
* an expression.  It evaluates the expression and sets the variable
* to that value.
*
* 'FIN' checks the end of a command.  If it ended with ":",
* execution continues.	If it ended with a CR, it finds the
* the next line and continues from there.
*
* 'ENDCHK' checks if a command is ended with a CR. This is
* required in certain commands, such as GOTO, RETURN, STOP, etc.
*
* 'ERROR' prints the string pointed to by A0. It then prints the
* line pointed to by CURRNT with a "?" inserted at where the
* old text pointer (should be on top of the stack) points to.
* Execution of Tiny BASIC is stopped and a warm start is done.
* If CURRNT is zero (indicating a direct command), the direct
* command is not printed. If CURRNT is -1 (indicating
* 'INPUT' command in progress), the input line is not printed
* and execution is not terminated but continues at 'INPERR'.
*
* Related to 'ERROR' are the following:
* 'QWHAT' saves text pointer on stack and gets "What?" message.
* 'AWHAT' just gets the "What?" message and jumps to 'ERROR'.
* 'QSORRY' and 'ASORRY' do the same kind of thing.
* 'QHOW' and 'AHOW' also do this for "How?".

; SETVAL
; Returns:
;		a6 pointer to variable

SETVAL	
	bsr	TSTV					; variable name?
	bcs	QWHAT					; if not, say "What?"
	move.l d0,-(sp)		; save the variable's address
	bsr	TSTC					; get past the "=" sign
	dc.b	'=',SV1-*
	bsr	EXPR					; evaluate the expression
	move.l (sp)+,a6
	move.l d0,(a6)		; save type
	fmove.x fp0,4(a6) ; and save its value in the variable
	rts
SV1
	bra	QWHAT					; if no "=" sign

FIN
	bsr	TSTC					; *** FIN ***
	DC.B ':',FI1-*
	ADDQ.L #4,SP			; if ":", discard return address
	BRA	RUNSML				; continue on the same line
FI1
	bsr	TSTC					; not ":", is it a CR?
	DC.B	CR,FI2-*
	ADDQ.L #4,SP			; yes, purge return address
	BRA	RUNNXL				; execute the next line
FI2
	RTS								; else return to the caller

ENDCHK
	bsr	IGNBLK
	CMP.B #':',(a0)
	BEQ ENDCHK1
	CMP.B	#CR,(A0)		; does it end with a CR?
	BNE	QWHAT					; if not, say "WHAT?"
ENDCHK1:
	RTS

QWHAT
	MOVE.L A0,-(SP)
AWHAT
	LEA	WHTMSG,A6
ERROR
	bsr	PRMESG		display the error message
	MOVE.L	(SP)+,A0	restore the text pointer
	MOVE.L	CURRNT,D0	get the current line number
	BEQ	WSTART		if zero, do a warm start
	CMP.L	#-1,D0		is the line no. pointer = -1?
	BEQ	INPERR		if so, redo input
	MOVE.B	(A0),-(SP)	save the char. pointed to
	CLR.B	(A0)		put a zero where the error is
	MOVE.L	CURRNT,A1	point to start of current line
	bsr	PRTLN		display the line in error up to the 0
	MOVE.B	(SP)+,(A0)	restore the character
	MOVE.B	#'?',D0         display a "?"
	BSR	GOOUT
	CLR	D0
	SUBQ.L	#1,A1		point back to the error char.
	bsr	PRTSTG		display the rest of the line
	BRA	WSTART		and do a warm start
QSORRY
	MOVE.L	A0,-(SP)
ASORRY
	LEA	SRYMSG,A6
	BRA	ERROR
QHOW
	MOVE.L	A0,-(SP)	Error: "How?"
AHOW
	LEA	HOWMSG,A6
	BRA	ERROR
ETYPE
	lea TYPMSG,a6
	bra ERROR

*******************************************************************
*
* *** GETLN *** FNDLN (& friends) ***
*
* 'GETLN' reads in input line into 'BUFFER'. It first prompts with
* the character in D0 (given by the caller), then it fills the
* buffer and echos. It ignores LF's but still echos
* them back. Control-H is used to delete the last character
* entered (if there is one), and control-X is used to delete the
* whole line and start over again. CR signals the end of a line,
* and causes 'GETLN' to return.
*
* 'FNDLN' finds a line with a given line no. (in D1) in the
* text save area.  A1 is used as the text pointer. If the line
* is found, A1 will point to the beginning of that line
* (i.e. the high byte of the line no.), and flags are NC & Z.
* If that line is not there and a line with a higher line no.
* is found, A1 points there and flags are NC & NZ. If we reached
* the end of the text save area and cannot find the line, flags
* are C & NZ.
* 'FNDLN' will initialize A1 to the beginning of the text save
* area to start the search. Some other entries of this routine
* will not initialize A1 and do the search.
* 'FNDLNP' will start with A1 and search for the line no.
* 'FNDNXT' will bump A1 by 2, find a CR and then start search.
* 'FNDSKP' uses A1 to find a CR, and then starts the search.

GETLN
	BSR	GOOUT		display the prompt
	MOVE.B	#' ',D0         and a space
	BSR	GOOUT
	LEA	BUFFER,A0	A0 is the buffer pointer
GL1
	bsr	CHKIO		check keyboard
	BEQ	GL1		wait for a char. to come in
	CMP.B	#CTRLH,D0	delete last character?
	BEQ	GL3		if so
	CMP.B	#CTRLX,D0	delete the whole line?
	BEQ	GL4		if so
	CMP.B	#CR,D0		accept a CR
	BEQ	GL2
	CMP.B	#' ',D0         if other control char., discard it
	BCS	GL1
GL2
	MOVE.B	D0,(A0)+	save the char.
	BSR	GOOUT		echo the char back out
	CMP.B	#CR,D0		if it's a CR, end the line
	BEQ	GL7
	CMP.L	#(BUFFER+BUFLEN-1),A0	any more room?
	BCS	GL1		yes: get some more, else delete last char.
GL3
	MOVE.B	#CTRLH,D0	delete a char. if possible
	BSR	GOOUT
	MOVE.B	#' ',D0
	BSR	GOOUT
	CMP.L	#BUFFER,A0	any char.'s left?
	BLS	GL1		if not
	MOVE.B	#CTRLH,D0	if so, finish the BS-space-BS sequence
	BSR	GOOUT
	SUBQ.L	#1,A0		decrement the text pointer
	BRA	GL1		back for more
GL4
	MOVE.L	A0,D1		delete the whole line
	SUB.L	#BUFFER,D1	figure out how many backspaces we need
	BEQ	GL6		if none needed, branch
	SUBQ	#1,D1		adjust for DBRA
GL5
	MOVE.B	#CTRLH,D0	and display BS-space-BS sequences
	BSR	GOOUT
	MOVE.B	#' ',D0
	BSR	GOOUT
	MOVE.B	#CTRLH,D0
	BSR	GOOUT
	DBRA	D1,GL5
GL6
	LEA	BUFFER,A0	reinitialize the text pointer
	BRA	GL1		and go back for more
GL7
	MOVE.B	#LF,D0		echo a LF for the CR
	BRA	GOOUT

FNDLN
	CMP.L	#$FFFF,D1	line no. must be < 65535
	BCC	QHOW
	MOVE.L	TXTBGN,A1	init. the text save pointer

FNDLNP
	MOVE.L	TXTUNF,A2	check if we passed the end
	SUBQ.L	#1,A2
	CMP.L	A1,A2
	BCS	FNDRET		if so, return with Z=0 & C=1
	MOVE.B	(A1),D2	if not, get a line no.
	LSL	#8,D2
	MOVE.B	1(A1),D2
	CMP.W	D1,D2		is this the line we want?
	BCS	FNDNXT		no, not there yet
FNDRET
	RTS			return the cond. codes

FNDNXT
	ADDQ.L	#2,A1		find the next line

FNDSKP	
	CMP.B	#CR,(A1)+	try to find a CR
	BEQ		FNDLNP
	CMP.L	TXTUNF,A1
	BLO		FNDSKP
	BRA		FNDLNP		check if end of text

;******************************************************************
;
; *** MVUP *** MVDOWN *** POPA *** PUSHA ***
;
; 'MVUP' moves a block up from where A1 points to where A2 points
; until A1=A3
;
; 'MVDOWN' moves a block down from where A1 points to where A3
; points until A1=A2
;
; 'POPA' restores the 'FOR' loop variable save area from the stack
;
; 'PUSHA' stacks for 'FOR' loop variable save area onto the stack
;

MVUP
	CMP.L	A1,A3					; see the above description
	BLS	MVRET
	MOVE.B	(A1)+,(A2)+
	BRA	MVUP
MVRET
	RTS

; For string movements only suitable in some circumstances

MVUPW
	cmp.l a3,a1
	bhs .0001
	move.w (a1)+,(a2)+
	bra MVUPW
.0001
	rts

MVDOWN
	CMP.L	A1,A2		see the above description
	BEQ	MVRET
	MOVE.B	-(A1),-(A3)
	BRA	MVDOWN

POPA
	MOVE.L	(SP)+,A6			; A6 = return address
	MOVE.L	(SP)+,LOPVAR	restore LOPVAR, but zero means no more
	BEQ	.0001
	MOVE.L	(SP)+,LOPINC+8	if not zero, restore the rest
	MOVE.L	(SP)+,LOPINC+4
	MOVE.L	(SP)+,LOPINC
	MOVE.L	(SP)+,LOPLMT+8
	MOVE.L	(SP)+,LOPLMT+4
	MOVE.L	(SP)+,LOPLMT
	MOVE.L	(SP)+,LOPLN
	MOVE.L	(SP)+,LOPPT
.0001
	JMP	(A6)		return

PUSHA
	MOVE.L	STKLMT,D1		; Are we running out of stack room?
	SUB.L	SP,D1
	BCC	QSORRY					; if so, say we're sorry
	MOVE.L	(SP)+,A6		; else get the return address
	MOVE.L	LOPVAR,D1		; save loop variables
	BEQ	.0001						; if LOPVAR is zero, that's all
	MOVE.L	LOPPT,-(SP)	; else save all the others
	MOVE.L	LOPLN,-(SP)
	MOVE.L	LOPLMT,-(SP)
	MOVE.L	LOPLMT+4,-(SP)
	MOVE.L	LOPLMT+8,-(SP)
	MOVE.L	LOPINC,-(SP)
	MOVE.L	LOPINC+4,-(SP)
	MOVE.L	LOPINC+8,-(SP)
.0001
	MOVE.L	D1,-(SP)
	JMP	(A6)		return

*******************************************************************
*
* *** PRTSTG *** QTSTG *** PRTNUM *** PRTLN ***
*
* 'PRTSTG' prints a string pointed to by A1. It stops printing
* and returns to the caller when either a CR is printed or when
* the next byte is the same as what was passed in D0 by the
* caller.
*
* 'QTSTG' looks for an underline (back-arrow on some systems),
* single-quote, or double-quote.  If none of these are found, returns
* to the caller.  If underline, outputs a CR without a LF.  If single
* or double quote, prints the quoted string and demands a matching
* end quote.  After the printing, the next 2 bytes of the caller are
* skipped over (usually a short branch instruction).
*
* 'PRTNUM' prints the 32 bit number in D1, leading blanks are added if
* needed to pad the number of spaces to the number in D4.
* However, if the number of digits is larger than the no. in
* D4, all digits are printed anyway. Negative sign is also
* printed and counted in, positive sign is not.
*
* 'PRTLN' prints the saved text line pointed to by A1
* with line no. and all.
*
PRTSTG:
	MOVE.B	D0,D1		save the stop character
PS1
	MOVE.B	(A1)+,D0	get a text character
	CMP.B	D0,D1		same as stop character?
	BEQ	PRTRET		if so, return
	BSR	GOOUT		display the char.
	CMP.B	#CR,D0		is it a C.R.?
	BNE	PS1		no, go back for more
	MOVE.B	#LF,D0		yes, add a L.F.
	BSR	GOOUT
PRTRET
	RTS			then return

PRTSTR2a
	move.b (a1)+,d0
	bsr GOOUT
PRTSTR2:
	dbra d1,PRTSTR2a
	rts
	
	if 0
QTSTG
	bsr	TSTC		*** QTSTG ***
	DC.B	'"',QT3-*
	MOVE.B	#'"',D0         it is a "
QT1
	MOVE.L	A0,A1
	BSR	PRTSTG		print until another
	MOVE.L	A1,A0
	MOVE.L	(SP)+,A1	pop return address
	CMP.B	#LF,D0		was last one a CR?
	BEQ	RUNNXL		if so, run next line
QT2
	ADDQ.L	#2,A1		skip 2 bytes on return
	JMP	(A1)		return
QT3
	bsr	TSTC		is it a single quote?
	DC.B	'''',QT4-*
	MOVE.B	#'''',D0        if so, do same as above
	BRA	QT1
QT4
	bsr	TSTC		is it an underline?
	DC.B	'_',QT5-*
	MOVE.B	#CR,D0		if so, output a CR without LF
	bsr	GOOUT
	MOVE.L	(SP)+,A1	pop return address
	BRA	QT2
QT5
	RTS			none of the above
	endif

PRTNUM:
	link a2,#-48
	move.l _canary,44(a0)
	movem.l d0/d1/d2/d3/a1,(sp)
	fmove.x fp0,20(sp)
	fmove.x fp1,32(sp)
	fmove.x fp1,fp0					; fp0 = number to print
	lea _fpBuf,a1						; a1 = pointer to buffer to use
	moveq #39,d0						; d0 = function #39 print float
	move.l d4,d1						; d1 = width
	move.l d4,d2						; d2 = precision max
	moveq #'e',d3
	trap #15
	movem.l (sp),d0/d1/d2/d3/a1
	fmove.x 20(sp),fp0
	fmove.x 32(sp),fp1
	cchk 44(a0)
	unlk a2
	rts

; Debugging
	if 0
PRTFP0:
	link a2,#-48
	move.l _canary,44(a0)
	movem.l d0/d1/d2/d3/a1,(sp)
	fmove.x fp0,20(sp)
	lea _fpBuf,a1						; a1 = pointer to buffer to use
	moveq #39,d0						; d0 = function #39 print float
	moveq #30,d1						; d1 = width
	moveq #25,d2						; d2 = precision max
	moveq #'e',d3
	trap #15
	movem.l (sp),d0/d1/d2/d3/a1
	fmove.x 20(sp),fp0
	cchk 44(a0)
	unlk a2
	rts
	endif

PRTLN:
	CLR.L	D1
	MOVE.B (A1)+,D1	get the binary line number
	LSL	#8,D1
	MOVE.B (A1)+,D1
	FMOVE.W D1,FP1
	MOVEQ	#5,D4			; display a 5 digit line no.
	BSR	PRTNUM
	MOVE.B	#' ',D0         followed by a blank
	BSR	GOOUT
	CLR	D0		stop char. is a zero
	BRA	PRTSTG		display the rest of the line


; ===== Test text byte following the call to this subroutine. If it
; equals the byte pointed to by A0, return to the code following
; the call. If they are not equal, branch to the point
;	indicated by the offset byte following the text byte.

TSTC:
	BSR	IGNBLK				; ignore leading blanks
	MOVE.L (SP)+,A1		; get the return address
	MOVE.B (A1)+,D1		; get the byte to compare
	CMP.B	(A0),D1 		;	is it = to what A0 points to?
	BEQ	TC1						; if so
	CLR.L	D1					; If not, add the second
	MOVE.B (A1),D1 		; byte following the call to
	ADD.L	D1,A1				; the return address.
	JMP	(A1)					; jump to the routine
TC1
	ADDQ.L #1,A0			; if equal, bump text pointer
	ADDQ.L #1,A1			; Skip the 2 bytes following
	JMP	(A1)					; the call and continue.


; ===== See if the text pointed to by A0 is a number. If so,
;	return the number in FP1 and the number of digits in D2,
;	else return zero in FP1 and D2.
; If text is not a number, then A0 is not updated, otherwise
; A0 is advanced past the number. Note A0 is always updated
; past leading spaces.

TSTNUM
	link a2,#-32
	move.l _canary,28(sp)
	movem.l d1/a1,(sp)
	fmove.x fp0,16(sp)
	moveq #41,d0						; function #41, get float
	moveq #1,d1							; d1 = input stride
	move.l a0,a1						; a1 = pointer to input buffer
	trap #15								; call BIOS get float function
	move.l a1,a0						; set text pointer
	moveq #DT_NUMERIC,d0		; default data type = number
	fmove.x fp0,fp1					; return expected in fp1
	tst.w d1								; check if a number (digits > 0?)
	beq .0002
	clr.l d2								; d2.l = 0
	move.w d1,d2						; d2 = number of digits
	bra .0001
.0002											; not a number, return with orignal text pointer
	moveq #0,d0							; data type = not a number
	moveq #0,d2							; d2 = 0
	fmove.l d2,fp1					; return a zero
.0001
	movem.l (sp),d1/a1
	fmove.x 16(sp),fp0
	cchk 28(sp)
	unlk a2
	rts
		
; ===== Skip over blanks in the text pointed to by A0.

IGNBLK
	CMP.B	#' ',(A0)+		; see if it's a space
	BEQ	IGNBLK					; if so, swallow it
	SUBQ.L #1,A0				; decrement the text pointer
	RTS

*
* ===== Convert the line of text in the input buffer to upper
*	case (except for stuff between quotes).
*
TOUPBUF LEA	BUFFER,A0	set up text pointer
	CLR.B	D1		clear quote flag
TOUPB1	
	MOVE.B	(A0)+,D0	get the next text char.
	CMP.B	#CR,D0		is it end of line?
	BEQ	TOUPBRT 	if so, return
	CMP.B	#'"',D0         a double quote?
	BEQ	DOQUO
	CMP.B	#'''',D0        or a single quote?
	BEQ	DOQUO
	TST.B	D1		inside quotes?
	BNE	TOUPB1		if so, do the next one
	BSR	TOUPPER 	convert to upper case
	MOVE.B	D0,-(A0)	store it
	ADDQ.L	#1,A0
	BRA	TOUPB1		and go back for more
TOUPBRT
	RTS

DOQUO	TST.B	D1		are we inside quotes?
	BNE	DOQUO1
	MOVE.B	D0,D1		if not, toggle inside-quotes flag
	BRA	TOUPB1
DOQUO1	CMP.B	D0,D1		make sure we're ending proper quote
	BNE	TOUPB1		if not, ignore it
	CLR.B	D1		else clear quote flag
	BRA	TOUPB1

*
* ===== Convert the character in D0 to upper case
*
TOUPPER CMP.B	#'a',D0         is it < 'a'?
	BCS	TOUPRET
	CMP.B	#'z',D0         or > 'z'?
	BHI	TOUPRET
	SUB.B	#32,D0		if not, make it upper case
TOUPRET RTS

*
* 'CHKIO' checks the input. If there's no input, it will return
* to the caller with the Z flag set. If there is input, the Z
* flag is cleared and the input byte is in D0. However, if a
* control-C is read, 'CHKIO' will warm-start BASIC and will not
* return to the caller.
*
CHKIO
	bsr	GOIN		get input if possible
	BEQ	CHKRET		if Zero, no input
	CMP.B	#CTRLC,D0	is it control-C?
	BNE	CHKRET		if not
	BRA	WSTART		if so, do a warm start
CHKRET
	RTS

*
* ===== Display a CR-LF sequence
*
;CRLF	LEA	CLMSG,A6


; ===== Display a zero-ended string pointed to by register A6

PRMESG
	MOVE.B (A6)+,D0		; get the char.
	BEQ	PRMRET				; if it's zero, we're done
	BSR	GOOUT					; else display it
	BRA	PRMESG
PRMRET
	RTS

******************************************************
* The following routines are the only ones that need *
* to be changed for a different I/O environment.     *
******************************************************

; ===== Clear screen and home cursor

CLS:
	moveq #11,d0			; set cursor position
	move.w #$FF00,d1	; home cursor and clear screen
	trap #15
	bra FINISH

; ===== Output character to the console (Port 1) from register D0
;(Preserves all registers.)

OUTC:
	movem.l d0/d1,-(sp)
	move.l d0,d1
	moveq #6,d0
	trap #15
	movem.l (sp)+,d0/d1
	rts

* ===== Input a character from the console into register D0 (or
*	return Zero status if there's no character available).
*
INC
	move.l	a6,-(a7)
	move.l	INPPTR,a6
	jsr			(a6)
	move.l	(a7)+,a6
	rts

INC1
	move.l	d1,-(a7)
	moveq.l	#5,d0			* function 5 GetKey
	trap		#15
	move.l	d1,d0
	move.l	(a7)+,d1
	cmpi.b	#-1,d0
	bne			.0001
	clr.b		d0
.0001:
	rts

*INC	BTST	#0,$10040	is character ready?
*	BEQ	INCRET		if not, return Zero status
*	MOVE.B	$10042,D0	else get the character
*	AND.B	#$7F,D0 	zero out the high bit
*INCRET	RTS

* ===== Output character to the host (Port 2) from register D0
*	(Preserves all registers.)
*
AUXOUT:
	move.b #2,OutputDevice
	bsr OUTC
	move.b #1,OutputDevice
	rts

*AUXOUT	BTST	#1,$10041	is port 2 ready for a character?
*	BEQ	AUXOUT		if not, wait for it
*	MOVE.B	D0,$10043	out it goes.
*	RTS

*
* ===== Input a character from the host into register D0 (or
*	return Zero status if there's no character available).
*
AUXIN:
	move.l	d1,-(a7)
	moveq		#36,d0				; serial get char from buffer
	trap		#15
	move.l	d1,d0
	move.l	(a7)+,d1
	cmpi.w	#-1,d0
	beq			.0001
	andi.b	#$7F,d0				; clear high bit
	ext.w		d0						; return character in d0
	ext.l		d0
	rts
.0001:
	moveq		#0,d0					; return zf=1 if no character available
	rts

;AUXIN
*AUXIN	BTST	#0,$10041	is character ready?
*	BEQ	AXIRET		if not, return Zero status
*	MOVE.B	$10043,D0	else get the character
*	AND.B	#$7F,D0 	zero out the high bit
AXIRET	RTS

; ===== Return to the resident monitor, operating system, etc.
;
BYEBYE	
	move.l #8,_fpTextIncr
	bra		Monitor
;	MOVE.B	#228,D7 	return to Tutor
;	TRAP	#14

INITMSG DC.B	CR,LF,'MC68000 Tiny Float BASIC, v1.0',CR,LF,LF,0
OKMSG	DC.B	CR,LF,'OK',CR,LF,0
HOWMSG	DC.B	'How?',CR,LF,0
WHTMSG	DC.B	'What?',CR,LF,0
TYPMSG	DC.B	'Type?',CR,LF,0
NOSTRING	DC.B 'No string space',CR,LF,0
SRYMSG	DC.B	'Sorry.'
CLMSG	DC.B	CR,LF,0
	DC.B	0	<- for aligning on a word boundary
LSTROM	EQU	*		end of possible ROM area
*
* Internal variables follow:
*
	align 2
RANPNT	DC.L	START		random number pointer
INPPTR	DS.L	1		input pointer
OUTPTR	DS.L	1 	output pointer
CURRNT	DS.L	1		; Current line pointer
STKFP		DS.L	1		; saves frame pointer
STKGOS	DS.L	1		Saves stack pointer in 'GOSUB'
STKINP	DS.L	1		Saves stack pointer during 'INPUT'
LOPVAR	DS.L	1		'FOR' loop save area
LOPINC	DS.L	3		increment
LOPLMT	DS.L	3		limit
LOPLN	DS.L	1		line number
LOPPT	DS.L	1		text pointer
IRQROUT	DS.L	1
STRSTK	DS.L	1		; string pointer stack area, 8 entries
StrSp		DS.L	1		; string stack stack pointer
StrArea	DS.L	1		; pointer to string area
LastStr	DS.L	1		; pointer to last used string in area
TXTUNF	DS.L	1		points to unfilled text area
VARBGN	DS.L	1		points to variable area
STKLMT	DS.L	1		holds lower limit for stack growth
DIRFLG	DS.L	1		; indicates 1=DIRECT mode
BUFFER	DS.B	BUFLEN		Keyboard input buffer
TXT	EQU	*		Beginning of program area
;	END
