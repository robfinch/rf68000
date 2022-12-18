******************************************************************
*								 *
*		Tiny Float BASIC for the Motorola MC68000		 *
*								 *
* Derived from Palo Alto Tiny BASIC as published in the May 1976 *
* issue of Dr. Dobb's Journal.  Adapted to the 68000 by:         *
*	Gordon Brandly						 *
*	12147 - 51 Street					 *
*	Edmonton AB  T5W 3G8					 *
*	Canada							 *
*	(updated mailing address for 1996)			 *
* Modified 2022 for the rf68000. Robert Finch
*								 *
* This version is for MEX68KECB Educational Computer Board I/O.  *
*								 *
******************************************************************
*    Copyright (C) 1984 by Gordon Brandly. This program may be	 *
*    freely distributed for personal use only. All commercial	 *
*		       rights are reserved.			 *
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

BUFLEN	EQU	80		length of keyboard input buffer
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
CSTART	MOVE.L	ENDMEM,SP	initialize stack pointer
	move.l	#OUTC1,OUTPTR
	move.l	#INC1,INPPTR
	move.l #1,_fpTextIncr
	LEA	INITMSG,A6	tell who we are
	BSR	PRMESG
	MOVE.L	TXTBGN,TXTUNF	init. end-of-program pointer
	MOVE.L	ENDMEM,D0	get address of end of memory
	SUB.L	#4096,D0	reserve 4K for the stack
	MOVE.L	D0,STKLMT
	SUB.L	#512,D0 	reserve variable area (32 16 byte floats)
	MOVE.L	D0,VARBGN
WSTART
	CLR.L	D0		initialize internal variables
	move.l #1,_fpTextIncr
	clr.l IRQROUT
	MOVE.L	D0,LOPVAR
	MOVE.L	D0,STKGOS
	MOVE.L	D0,CURRNT	current line number pointer = 0
	MOVE.L	ENDMEM,SP	init S.P. again, just in case
	LEA	OKMSG,A6	display "OK"
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
	BEQ	ST3		if so, it was just a delete
	MOVE.L	TXTUNF,A3	compute new end
	MOVE.L	A3,A6
	ADD.L	D0,A3
	MOVE.L VARBGN,D0	see if there's enough room
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
	DC.L	PEEK			Functions
	DC.L	RND
	DC.L	ABS
	DC.L	SIZE
	DC.L	TICK
	DC.L	CORENO
	DC.L	XP40
TAB5_1
	DC.L	FR1			"TO" in "FOR"
	DC.L	QWHAT
TAB6_1
	DC.L	FR2			"STEP" in "FOR"
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

	even
	
DIRECT
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
	move.l	#AUXOUT,OUTPTR
	bra			FINISH
IOCON
	move.l	#INC1,INPPTR
OUTCON
	move.l	#OUTC1,OUTPTR
	bra			FINISH

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
NEW	bsr	ENDCHK
	MOVE.L	TXTBGN,TXTUNF	set the end pointer

STOP	bsr	ENDCHK
	BRA	WSTART

RUN
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
	sub.l #128,sp		; allocate storage for local variables
	move.l sp,STKFP
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
	bsr	EXPR			; evaluate the following expression
	bsr	ENDCHK		; must find end of line
	fmove.l fp0,d0
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
	bsr	EXPR				; evaluate the following expression
	bsr ENDCHK			; must find end of line
	fmove.l fp0,d0
	move.l d0,d1
	bsr FNDLN				; find the target line
	bne	ONIRQ1
	clr.l IRQROUT
	bra	FINISH
ONIRQ1:
	move.l a1,IRQROUT
	jmp		FINISH


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
LS1	BCS	FINISH		warm start if we passed the end
	bsr	PRTLN		print the line
	bsr	CHKIO		check for listing halt request
	BEQ	LS3
	CMP.B	#CTRLS,D0	pause the listing?
	BNE	LS3
LS2	bsr	CHKIO		if so, wait for another keypress
	BEQ	LS2
LS3	bsr	FNDLNP		find the next line
	BRA	LS1

PRINT	MOVE	#11,D4		D4 = number of print spaces
	bsr	TSTC		if null list and ":"
	DC.B	':',PR2-*
	bsr	CRLF		give CR-LF and continue
	BRA	RUNSML		execution on the same line
PR2	bsr	TSTC		if null list and <CR>
	DC.B	CR,PR0-*
	bsr	CRLF		also give CR-LF and
	BRA	RUNNXL		execute the next line
PR0	bsr	TSTC		else is it a format?
	DC.B	'#',PR1-*
	bsr	EXPR		yes, evaluate expression
	FMOVE.L	FP0,D4		and save it as print width
	BRA	PR3		look for more to print
PR1	bsr	TSTC		is character expression? (MRL)
	DC.B	'$',PR4-*
	bsr	EXPR		yep. Evaluate expression (MRL)
	FMOVE.L FP0,D0
	BSR	GOOUT		print low byte (MRL)
	BRA	PR3		look for more. (MRL)
PR4	bsr	QTSTG		is it a string?
	BRA.S	PR8		if not, must be an expression
PR3	bsr	TSTC		if ",", go find next
	DC.B	',',PR6-*
	bsr	FIN		in the list.
	BRA	PR0
PR6	bsr	CRLF		list ends here
	BRA	FINISH
PR8	MOVE	D4,-(SP)	save the width value
	bsr	EXPR		evaluate the expression
	MOVE	(SP)+,D4	restore the width
	FMOVE.X FP0,FP1
;	MOVE.L	D0,D1
	bsr	PRTNUM		print its value
	BRA	PR3		more to print?

FINISH	bsr	FIN		Check end of command
	BRA	QWHAT		print "What?" if wrong

*
*******************************************************************
*
* *** GOSUB *** & RETURN ***
*
* 'GOSUB expr:' or 'GOSUB expr<CR>' is like the 'GOTO' command,
* except that the current text pointer, stack pointer, etc. are
* saved so that execution can be continued after the subroutine
* 'RETURN's.  In order that 'GOSUB' can be nested (and even
* recursive), the save area must be stacked.  The stack pointer
* is saved in 'STKGOS'.  The old 'STKGOS' is saved on the stack.
* If we are in the main routine, 'STKGOS' is zero (this was done
* in the initialization section of the interpreter), but we still
* save it as a flag for no further 'RETURN's.
*
* 'RETURN<CR>' undoes everything that 'GOSUB' did, and thus
* returns the execution to the command after the most recent
* 'GOSUB'.  If 'STKGOS' is zero, it indicates that we never had
* a 'GOSUB' and is thus an error.
*
GOSUB:
	sub.l #128,sp		; allocate storage for local variables
	move.l sp,STKFP
	bsr	PUSHA		save the current 'FOR' parameters
	bsr	EXPR		get line number
	MOVE.L	A0,-(SP)	save text pointer
	FMOVE.L FP0,D0
	FMOVE.L	FP0,D1
	bsr	FNDLN		find the target line
	BNE	AHOW		if not there, say "How?"
	MOVE.L	CURRNT,-(SP)	found it, save old 'CURRNT'...
	MOVE.L	STKGOS,-(SP)	and 'STKGOS'
	CLR.L	LOPVAR		load new values
	MOVE.L	SP,STKGOS
	BRA	RUNTSL

RETURN:
	bsr	ENDCHK		there should be just a <CR>
	MOVE.L	STKGOS,D1	get old stack pointer
	BEQ	QWHAT		if zero, it doesn't exist
	MOVE.L	D1,SP		else restore it
	MOVE.L	(SP)+,STKGOS	and the old 'STKGOS'
	MOVE.L	(SP)+,CURRNT	and the old 'CURRNT'
	MOVE.L	(SP)+,A0	and the old text pointer
	bsr	POPA		and the old 'FOR' parameters
	move.l STKFP,sp
	add.l #128,sp
	BRA	FINISH		and we are back home

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
*
FOR	bsr	PUSHA		save the old 'FOR' save area
	bsr	SETVAL		set the control variable
	MOVE.L	A6,LOPVAR	save its address
	LEA	TAB5,A1 	use 'EXEC' to test for 'TO'
	LEA	TAB5_1,A2
	BRA	EXEC
FR1	
	bsr	EXPR		evaluate the limit
	FMOVE.X	FP0,LOPLMT	save that
	LEA	TAB6,A1 	use 'EXEC' to look for the
	LEA	TAB6_1,A2	word 'STEP'
	BRA	EXEC
FR2
	bsr	EXPR		found it, get the step value
	BRA	FR4
FR3
;	MOVEQ	#1,D0		not found, step defaults to 1
	FMOVE.B #1,FP0	; not found, step defaults to 1
FR4
	FMOVE.X	FP0,LOPINC	save that too
FR5	
	MOVE.L	CURRNT,LOPLN	save address of current line number
	MOVE.L	A0,LOPPT	and text pointer
	MOVE.L	SP,A6		dig into the stack to find 'LOPVAR'
	BRA	FR7
FR6
	ADD.L	#26,A6		look at next stack frame
FR7
	MOVE.L	(A6),D0 	is it zero?
	BEQ	FR8		if so, we're done
	CMP.L	LOPVAR,D0	same as current LOPVAR?
	BNE	FR6		nope, look some more
	MOVE.L	SP,A2		Else remove 5 long words from...
	MOVE.L	A6,A1		inside the stack.
	LEA	26,A3
	ADD.L	A1,A3
	bsr	MVDOWN
	MOVE.L	A3,SP		set the SP 5 long words up
FR8
	BRA	FINISH		and continue execution

NEXT	
	bsr	TSTV		get address of variable
	BCS	QWHAT		if no variable, say "What?"
	MOVE.L	D0,A1		save variable's address
NX0
	MOVE.L	LOPVAR,D0	If 'LOPVAR' is zero, we never...
	BEQ	QWHAT		had a FOR loop, so say "What?"
	CMP.L	D0,A1		else we check them
	BEQ	NX3		OK, they agree
	bsr	POPA		nope, let's see the next frame
	BRA	NX0
NX3	
	FMOVE.X	(A1),FP0 	get control variable's value
	FADD	LOPINC,FP0	add in loop increment
;	BVS	QHOW		say "How?" for 32-bit overflow
	FMOVE.X	FP0,(A1) 	save control variable's new value
	FMOVE.X	LOPLMT,FP1	get loop's limit value
	FTST LOPINC
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

*
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
*
REM	BRA	IF2		skip the rest of the line

IF	bsr	EXPR		evaluate the expression
IF1	FTST	FP0		is it zero?
	FBNE	RUNSML		if not, continue
IF2	MOVE.L	A0,A1
	CLR.L	D1
	bsr	FNDSKP		if so, skip the rest of the line
	BCC	RUNTSL		and run the next line
	BRA	WSTART		if no next line, do a warm start

INPERR	MOVE.L	STKINP,SP	restore the old stack pointer
	MOVE.L	(SP)+,CURRNT	and old 'CURRNT'
	ADDQ.L	#4,SP
	MOVE.L	(SP)+,A0	and old text pointer

INPUT	MOVE.L	A0,-(SP)	save in case of error
	bsr	QTSTG		is next item a string?
	BRA.S	IP2		nope
	bsr	TSTV		yes, but is it followed by a variable?
	BCS	IP4		if not, branch
	MOVE.L	D0,A2		put away the variable's address
	BRA	IP3		if so, input to variable
IP2	MOVE.L	A0,-(SP)	save for 'PRTSTG'
	bsr	TSTV		must be a variable now
	BCS	QWHAT		"What?" it isn't?
	MOVE.L	D0,A2		put away the variable's address
	MOVE.B	(A0),D2 	get ready for 'PRTSTG'
	CLR.B	D0
	MOVE.B	D0,(A0)
	MOVE.L	(SP)+,A1
	bsr	PRTSTG		print string as prompt
	MOVE.B	D2,(A0) 	restore text
IP3	MOVE.L	A0,-(SP)	save in case of error
	MOVE.L	CURRNT,-(SP)	also save 'CURRNT'
	MOVE.L	#-1,CURRNT	flag that we are in INPUT
	MOVE.L	SP,STKINP	save the stack pointer too
	MOVE.L	A2,-(SP)	save the variable address
	MOVE.B	#':',D0         print a colon first
	bsr	GETLN		then get an input line
	LEA	BUFFER,A0	point to the buffer
	bsr	EXPR		evaluate the input
	MOVE.L	(SP)+,A2	restore the variable address
	FMOVE.X	FP0,(A2) 	save value in variable
	MOVE.L	(SP)+,CURRNT	restore old 'CURRNT'
	MOVE.L	(SP)+,A0	and the old text pointer
IP4	ADDQ.L	#4,SP		clean up the stack
	bsr	TSTC		is the next thing a comma?
	DC.B	',',IP5-*
	BRA	INPUT		yes, more items
IP5	BRA	FINISH

DEFLT
	CMP.B	#CR,(A0)	empty line is OK
	BEQ	LT1		else it is 'LET'

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

*
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
	BSR	EXPR		get the memory address
	bsr	TSTC		it must be followed by a comma
	DC.B	',',PKER-*
	FMOVE.L	FP0,-(SP)	save the address
	BSR	EXPR		get the byte to be POKE'd
	MOVE.L	(SP)+,A1	get the address back
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
PKER	BRA	QWHAT		if no comma, say "What?"

CALL	
	BSR	EXPR		get the subroutine's address
	FTST FP0			; make sure we got a valid address
	BEQ	QHOW		if not, say "How?"
	MOVE.L	A0,-(SP)	save the text pointer
	FMOVE.L	FP0,D0
	MOVE.L D0,A1
	JSR	(A1)		jump to the subroutine
	MOVE.L	(SP)+,A0	restore the text pointer
	BRA	FINISH

*******************************************************************
*
* *** EXPR ***
*
* 'EXPR' evaluates arithmetical or logical expressions.
* <EXPR>::=<EXPR2>
*	   <EXPR2><rel.op.><EXPR2>
* where <rel.op.> is one of the operators in TAB8 and the result
* of these operations is 1 if true and 0 if false.
* <EXPR2>::=(+ or -)<EXPR3>(+ or -)<EXPR3>(...
* where () are optional and (... are optional repeats.
* <EXPR3>::=<EXPR4>( <* or /><EXPR4> )(...
* <EXPR4>::=<variable>
*	    <function>
*	    (<EXPR>)
* <EXPR> is recursive so that the variable '@' can have an <EXPR>
* as an index, functions can have an <EXPR> as arguments, and
* <EXPR4> can be an <EXPR> in parenthesis.

EXPR
EXPR_OR
	BSR EXPR_AND
	FMOVE.X FP0,-(SP)
	LEA TAB10,A1
	LEA TAB10_1,A2
	BRA EXEC
	
XP_OR
	BSR EXPR_AND
	FMOVE.X (SP)+,FP1
	FMOVE.L FP1,D1
	FMOVE.L FP0,D0
	OR.L D1,D0
	FMOVE.L D0,FP0
	RTS
	
EXPR_AND
	BSR EXPR_REL
	FMOVE.X FP0,-(SP)
	LEA TAB9,A1
	LEA TAB9_1,A2
	BRA EXEC

XP_AND
	BSR EXPR_REL
	FMOVE.X (SP)+,FP1
	FMOVE.L FP1,D1
	FMOVE.L FP0,D0
	AND.L D1,D0
	FMOVE.L D0,FP0
	RTS
	
XP_ANDX
XP_ORX
	FMOVE.X (SP)+,FP0
	RTS

EXPR_REL
	BSR	EXPR2
	FMOVE.X	FP0,-(SP)		; save <EXPR2> value
	LEA	TAB8,A1 				; look up a relational operator
	LEA	TAB8_1,A2
	BRA	EXEC		go do it

XP11
	FMOVE.X (SP)+,FP0	
	BSR	XP18		is it ">="?
	FBLT XPRT0		no, return D0=0
	BRA	XPRT1		else return D0=1

XP12
	FMOVE.X (SP)+,FP0	
	BSR	XP18		is it "<>"?
	FBEQ XPRT0		no, return D0=0
	BRA	XPRT1		else return D0=1

XP13
	FMOVE.X (SP)+,FP0	
	BSR	XP18		is it ">"?
	FBLE XPRT0		no, return D0=0
	BRA	XPRT1		else return D0=1

XP14
	FMOVE.X (SP)+,FP0	
	BSR	XP18		is it "<="?
	FBGT XPRT0		no, return D0=0
	BRA	XPRT1		else return D0=1

XP15
	FMOVE.X (SP)+,FP0	
	BSR	XP18		is it "="?
	FBNE XPRT0		if not, return D0=0
	BRA	XPRT1		else return D0=1
XP15RT
	RTS

XP16
	FMOVE.X (SP)+,FP0	
	BSR	XP18		is it "<"?
	FBGE XPRT0		if not, return D0=0
	BRA	XPRT1		else return D0=1
XP16RT
	RTS

XPRT0
	FMOVE.B #0,FP0	; return fp0 = 0 (false)
	RTS

XPRT1	
	FMOVE.B #1,FP0	; return fp0 = 1 (true)
	RTS

XP17								; it's not a rel. operator
	FMOVE.X (SP)+,FP0
	RTS								;		return FP0=<EXPR2>

XP18
	FMOVE.X	FP0,-(SP)	; save <EXPR2> value
	BSR	EXPR2					; do second <EXPR2>
	FMOVE.X (SP)+,FP1	; get stacked value
	FCMP FP0,FP1			; compare with the first result
	RTS								; return the result

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
	FMOVE.X FP0,-(SP)	; yes, save the value
	BSR	EXPR3					; get the second <EXPR3>
XP24
	FMOVE.X (SP)+,FP1
	FADD FP1,FP0			; add it to the first <EXPR3>
;	FBVS	QHOW		branch if there's an overflow
	BRA	XP23		else go back for more operations
XP25
	bsr	TSTC		subtract?
	DC.B	'-',XP42-*
XP26
	FMOVE.X	FP0,-(SP)	; yes, save the result of 1st <EXPR3>
	BSR	EXPR3					; get second <EXPR3>
	FNEG FP0					; change its sign
	JMP	XP24					; and do an addition

EXPR3
	BSR	EXPR4					; get first <EXPR4>
XP31
	bsr	TSTC					; multiply?
	DC.B	'*',XP34-*
	FMOVE.X FP0,-(SP)	; yes, save that first result
	BSR	EXPR4					; get second <EXPR4>
	FMOVE.X (SP)+,FP1
	FMUL FP1,FP0			; multiply the two
	BRA	XP31					; then look for more terms
XP34
	bsr	TSTC		divide?
	DC.B	'/',XP42-*
	FMOVE.X FP0,-(SP)	; save result of 1st <EXPR4>
	BSR	EXPR4					; get second <EXPR4>
	FMOVE.X FP0,FP1
	FMOVE.X (SP)+,FP0
	FDIV FP1,FP0			; do the division
	BRA	XP31					; go back for any more terms

EXPR4
	LEA	TAB4,A1 			; find possible function
	LEA	TAB4_1,A2
	BRA	EXEC
XP40
	BSR	TSTV					; nope, not a function
	BCS	XP41					; nor a variable
	MOVE.L	D0,A1			; A1 = variable address
	FMOVE.X (A1),FP0	; if a variable, return its value in FP0
EXP4RT
	RTS
XP41
	bsr	TSTNUM				; or is it a number?
	FMOVE.X FP1,FP0
	TST.w	D2					; (if not, # of digits will be zero)
	BNE	EXP4RT				; if so, return it in FP0
PARN
	bsr	TSTC					; else look for ( EXPR )
	DC.B	'(',XP43-*
	BSR	EXPR
	bsr	TSTC
	DC.B	')',XP43-*
XP42	
	RTS
XP43
	BRA	QWHAT					; else say "What?"


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
	MOVE.L D0,-(SP)		; save the index
	bsr	SIZE					; get amount of free memory
	MOVE.L (SP)+,D1		; get back the index
	CMP.L	D1,D0				; see if there's enough memory
	BLS	QSORRY				; if not, say "Sorry"
	MOVE.L VARBGN,D0	; put address of array element...
	SUB.L	D1,D0				; into D0
	RTS
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
	ADDX.L	D0,D0		the divide routine in Ron Cain's
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

*
* ===== The PEEK function returns the byte stored at the address
*	contained in the following expression.
*
PEEK
	MOVE.B #'B',d7
	MOVE.B (a0),d1
	CMPI.B #'.',d1
	BNE .0001
	ADDQ #1,a0
	move.b (a0)+,d7
.0001
	BSR	PARN		get the memory address
	FMOVE.L FP0,D0
	MOVE.L D0,A1
	cmpi.b #'B',d7
	bne .0002
.0005
	CLR.L	D0		upper 3 bytes will be zero
	FMOVE.B	(A1),FP0 	get the addressed byte
	RTS			and return it
.0002
	cmpi.b #'W',d7
	bne .0003
	CLR.L d0
	FMOVE.W	(A1),FP0 	get the addressed byte
	RTS			and return it
.0003
	cmpi.b #'L',d7
	bne .0004
	CLR.L d0
	FMOVE.L	(A1),FP0 		; get the lword
	RTS			and return it
.0004
	cmpi.b #'F',d7
	bne .0005
	FMOVE.X	(A1),FP0 		; get the addressed float
	RTS			and return it

; ===== The RND function returns a random number from 0 to
; the value of the following expression in fp0.

RND:
	bsr	PARN			; get the upper limit
	ftst.x fp0		; it must be positive and non-zero
	fbeq QHOW
	fblt QHOW
	fmove.x fp0,fp2
	moveq #40,d0	; function #40 get random float
	trap #15
	fmul.x fp2,fp0
	rts

; ===== The ABS function returns an absolute value in D0.

ABS:	
	bsr	PARN			; get the following expr.'s value
	fabs.x fp0
	rts

; ===== The SIZE function returns the size of free memory in D0.

SIZE:
	move.l VARBGN,d0		; get the number of free bytes...
	sub.l	 TXTUNF,d0		; between 'TXTUNF' and 'VARBGN'
	fmove.l d0,fp0
	rts									; return the number in d0/fp0
	
; ===== The TICK function returns the processor tick register in D0.

TICK:
	movec tick,d0
	fmove.l d0,fp0
	rts

; ===== The CORENO function returns the core number in D0.

CORENO:
	movec coreno,d0
	fmove.l d0,fp0
	rts

*******************************************************************
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
*
SETVAL	
	bsr	TSTV					; variable name?
	bcs	QWHAT					; if not, say "What?"
	move.l d0,-(sp)		; save the variable's address
	bsr	TSTC					; get past the "=" sign
	dc.b	'=',SV1-*
	bsr	EXPR					; evaluate the expression
	move.l (sp)+,a6
	fmove.x fp0,(a6) 	; and save its value in the variable
	rts
SV1
	bra	QWHAT					; if no "=" sign

FIN
	bsr	TSTC		*** FIN ***
	DC.B	':',FI1-*
	ADDQ.L	#4,SP		if ":", discard return address
	BRA	RUNSML		continue on the same line
FI1
	bsr	TSTC		not ":", is it a CR?
	DC.B	CR,FI2-*
	ADDQ.L	#4,SP		yes, purge return address
	BRA	RUNNXL		execute the next line
FI2
	RTS			else return to the caller

ENDCHK
	bsr	IGNBLK
	CMP.B #':',(a0)
	BEQ ENDCHK1
	CMP.B	#CR,(A0)	does it end with a CR?
	BNE	QWHAT		if not, say "WHAT?"
ENDCHK1:
	RTS

QWHAT	MOVE.L	A0,-(SP)
AWHAT	LEA	WHTMSG,A6
ERROR	bsr	PRMESG		display the error message
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
QSORRY	MOVE.L	A0,-(SP)
ASORRY	LEA	SRYMSG,A6
	BRA	ERROR
QHOW	MOVE.L	A0,-(SP)	Error: "How?"
AHOW	LEA	HOWMSG,A6
	BRA	ERROR
*
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
*
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

*
*******************************************************************
*
* *** MVUP *** MVDOWN *** POPA *** PUSHA ***
*
* 'MVUP' moves a block up from where A1 points to where A2 points
* until A1=A3
*
* 'MVDOWN' moves a block down from where A1 points to where A3
* points until A1=A2
*
* 'POPA' restores the 'FOR' loop variable save area from the stack
*
* 'PUSHA' stacks for 'FOR' loop variable save area onto the stack
*
MVUP	CMP.L	A1,A3		see the above description
	BEQ	MVRET
	MOVE.B	(A1)+,(A2)+
	BRA	MVUP
MVRET	RTS

MVDOWN	CMP.L	A1,A2		see the above description
	BEQ	MVRET
	MOVE.B	-(A1),-(A3)
	BRA	MVDOWN

POPA	MOVE.L	(SP)+,A6	A6 = return address
	MOVE.L	(SP)+,LOPVAR	restore LOPVAR, but zero means no more
	BEQ	PP1
	MOVE.L	(SP)+,LOPINC+8	if not zero, restore the rest
	MOVE.L	(SP)+,LOPINC+4
	MOVE.L	(SP)+,LOPINC
	MOVE.L	(SP)+,LOPLMT+8
	MOVE.L	(SP)+,LOPLMT+4
	MOVE.L	(SP)+,LOPLMT
	MOVE.L	(SP)+,LOPLN
	MOVE.L	(SP)+,LOPPT
PP1	JMP	(A6)		return

PUSHA	MOVE.L	STKLMT,D1	Are we running out of stack room?
	SUB.L	SP,D1
	BCC	QSORRY		if so, say we're sorry
	MOVE.L	(SP)+,A6	else get the return address
	MOVE.L	LOPVAR,D1	save loop variables
	BEQ	PU1		if LOPVAR is zero, that's all
	MOVE.L	LOPPT,-(SP)	else save all the others
	MOVE.L	LOPLN,-(SP)
	MOVE.L	LOPLMT,-(SP)
	MOVE.L	LOPLMT+4,-(SP)
	MOVE.L	LOPLMT+8,-(SP)
	MOVE.L	LOPINC,-(SP)
	MOVE.L	LOPINC+4,-(SP)
	MOVE.L	LOPINC+8,-(SP)
PU1	
	MOVE.L	D1,-(SP)
	JMP	(A6)		return

*
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
PRTSTG	MOVE.B	D0,D1		save the stop character
PS1	MOVE.B	(A1)+,D0	get a text character
	CMP.B	D0,D1		same as stop character?
	BEQ	PRTRET		if so, return
	BSR	GOOUT		display the char.
	CMP.B	#CR,D0		is it a C.R.?
	BNE	PS1		no, go back for more
	MOVE.B	#LF,D0		yes, add a L.F.
	BSR	GOOUT
PRTRET	RTS			then return

QTSTG	bsr	TSTC		*** QTSTG ***
	DC.B	'"',QT3-*
	MOVE.B	#'"',D0         it is a "
QT1	MOVE.L	A0,A1
	BSR	PRTSTG		print until another
	MOVE.L	A1,A0
	MOVE.L	(SP)+,A1	pop return address
	CMP.B	#LF,D0		was last one a CR?
	BEQ	RUNNXL		if so, run next line
QT2	ADDQ.L	#2,A1		skip 2 bytes on return
	JMP	(A1)		return
QT3	bsr	TSTC		is it a single quote?
	DC.B	'''',QT4-*
	MOVE.B	#'''',D0        if so, do same as above
	BRA	QT1
QT4	bsr	TSTC		is it an underline?
	DC.B	'_',QT5-*
	MOVE.B	#CR,D0		if so, output a CR without LF
	bsr	GOOUT
	MOVE.L	(SP)+,A1	pop return address
	BRA	QT2
QT5	RTS			none of the above

PRTNUM:
	link a2,#-36
	move.l _canary,32(a0)
	movem.l d0/d1/d2/d3/a1,(sp)
	fmove.x fp0,20(sp)
	fmove.x fp1,fp0					; fp0 = number to print
	lea _fpBuf,a1						; a0 = pointer to buffer to use
	moveq #39,d0						; d0 = function #39 print float
	move.l d4,d1						; d1 = width
	move.l d4,d2						; d2 = precision max
	moveq #'e',d3
	trap #15
	movem.l (sp),d0/d1/d2/d3/a1
	fmove.x 20(sp),fp0
	cchk 32(a0)
	unlk a2
	rts

PRTLN:
	CLR.L	D1
	MOVE.B	(A1)+,D1	get the binary line number
	LSL	#8,D1
	MOVE.B	(A1)+,D1
	FMOVE.W D1,FP1
	MOVEQ	#5,D4		display a 5 digit line no.
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
	movem.l d0/d1/a1,(sp)
	fmove.x fp0,16(sp)
	moveq #41,d0						; function #41, get float
	moveq #1,d1							; d1 = input stride
	move.l a0,a1						; a1 = pointer to input buffer
	trap #15								; call BIOS get float function
	move.l a1,a0						; set text pointer
	fmove.x fp0,fp1					; return expected in fp1
	tst.w d1								; check if a number (digits > 0?)
	beq .0002
	clr.l d2								; d2.l = 0
	move.w d1,d2						; d2 = number of digits
	bra .0001
.0002											; not a number, return with orignal text pointer
	moveq #0,d2							; d2 = 0
	fmove.l d2,fp1					; return a zero
.0001
	movem.l (sp),d0/d1/a1
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
CHKIO	bsr	GOIN		get input if possible
	BEQ	CHKRET		if Zero, no input
	CMP.B	#CTRLC,D0	is it control-C?
	BNE	CHKRET		if not
	BRA	WSTART		if so, do a warm start
CHKRET	RTS

*
* ===== Display a CR-LF sequence
*
;CRLF	LEA	CLMSG,A6

*
* ===== Display a zero-ended string pointed to by register A6
*
PRMESG	MOVE.B	(A6)+,D0	get the char.
	BEQ	PRMRET		if it's zero, we're done
	BSR	GOOUT		else display it
	BRA	PRMESG
PRMRET	RTS

******************************************************
* The following routines are the only ones that need *
* to be changed for a different I/O environment.     *
******************************************************

*
* ===== Output character to the console (Port 1) from register D0
*	(Preserves all registers.)
*
OUTC
	move.l	a6,-(a7)
	move.l	OUTPTR,a6
	jsr			(a6)
	move.l	(a7)+,a6
	rts

OUTC1
	movem.l		d0/d1,-(a7)
	move.l		d0,d1
	moveq.l		#6,d0
	trap			#15
	movem.l		(a7)+,d0/d1
	rts

*OUTC	BTST	#1,$10040	is port 1 ready for a character?
*	BEQ	OUTC		if not, wait for it
*	MOVE.B	D0,$10042	out it goes.
*	RTS

*
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

*
* ===== Output character to the host (Port 2) from register D0
*	(Preserves all registers.)
*
AUXOUT:
	movem.l	d0/d1,-(a7)
	move.l	d0,d1
	moveq		#34,d0
	trap		#15
	movem.l	(a7)+,d0/d1
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

*
* ===== Return to the resident monitor, operating system, etc.
*
BYEBYE	
	move.l #8,_fpTextIncr
	bra		Monitor
;	MOVE.B	#228,D7 	return to Tutor
;	TRAP	#14

INITMSG DC.B	CR,LF,'Finch''s MC68000 Tiny Float BASIC, v1.2',CR,LF,LF,0
OKMSG	DC.B	CR,LF,'OK',CR,LF,0
HOWMSG	DC.B	'How?',CR,LF,0
WHTMSG	DC.B	'What?',CR,LF,0
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
CURRNT	DS.L	1		Current line pointer
STKFP		DS.L	1		; saves frame pointer
STKGOS	DS.L	1		Saves stack pointer in 'GOSUB'
STKINP	DS.L	1		Saves stack pointer during 'INPUT'
LOPVAR	DS.L	1		'FOR' loop save area
LOPINC	DS.L	3		increment
LOPLMT	DS.L	3		limit
LOPLN	DS.L	1		line number
LOPPT	DS.L	1		text pointer
IRQROUT	DS.L	1
TXTUNF	DS.L	1		points to unfilled text area
VARBGN	DS.L	1		points to variable area
STKLMT	DS.L	1		holds lower limit for stack growth
BUFFER	DS.B	BUFLEN		Keyboard input buffer
TXT	EQU	*		Beginning of program area
;	END
