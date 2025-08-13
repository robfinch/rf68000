	align 2
KeybdTranslateKeys:
.0003
	move.b _KeybdCnt(a3),d2
	beq .0001
	move.b _KeybdHead(a3),d2
	ext.w d2
	lea _KeybdBuf(a3),a0
	clr.l d1
	move.b (a0,d2.w),d1			; d1 = scan code from buffer
	addi.b #1,d2						; increment keyboard head index
	andi.b #31,d2						; and wrap around at buffer size
	move.b d2,_KeybdHead(a3)
	subi.b #1,_KeybdCnt(a3)	; decrement count of scan codes in buffer

	cmpi.b #SC_KEYUP,d1
	beq .doKeyup
	cmpi.b #SC_EXTEND,d1
	beq	.doExtend
	cmpi.b #SC_CTRL,d1
	beq	.doCtrl
	cmpi.b #SC_LSHIFT,d1
	beq	.doShift
	cmpi.b #SC_RSHIFT,d1
	beq	.doShift
	cmpi.b #SC_NUMLOCK,d1
	beq	.doNumLock
	cmpi.b #SC_CAPSLOCK,d1
	beq	.doCapsLock
	cmpi.b #SC_SCROLLLOCK,d1
	beq	.doScrollLock
	cmpi.b #SC_ALT,d1
	beq .doAlt
	move.b _KeyState1(a3),d2			; check key up/down
	move.b #0,_KeyState1(a3)			; clear keyup status
	tst.b	d2
	bne	.sendKeyup								; send key up message
	cmp.b #SC_TAB,d1
	beq .doTab
.0013
	move.b _KeyState2(a3),d2
	bpl	.0010							; is it extended code ?
	and.b	#$7F,d2					; clear extended bit
	move.b d2,_KeyState2(a3)
	move.b #0,_KeyState1(a3)			; clear keyup
	lea	_keybdExtendedCodes,a0
	move.b (a0,d1.w),_VirtKey
	bra	.sendKeyDown
.0010
	btst #2,d2					; is it CTRL code ?
	beq	.0009
	and.w	#$7F,d1
	lea	_keybdControlCodes,a0
	move.b (a0,d1.w),_VirtKey
	bra	.sendKeyDown
.0009
	btst #0,d2					; is it shift down ?
	beq .0007
	lea	_shiftedScanCodes,a0
	move.b (a0,d1.w),_VirtKey
	bra .sendKeyDown
.0007
	lea	_unshiftedScanCodes,a0
	move.b (a0,d1.w),_VirtKey

;typedef struct tagMSG {
;	hMSG link;
;	unsigned short int retadr;    // return address
;	unsigned short int dstadr;    // destination address
;	unsigned short int type;
;	unsigned long d1;            // payload data 1
;	unsigned long d2;            // payload data 2
;	unsigned long d3;            // payload data 3
;} MSG;

.sendKeyDown
	move.b _PrevKeyState2(a3),d0
	cmp.b _KeyState2(a3),d0
	bne .skd1
	move.b _PrevScanCode(a3),d0
	cmp.b _ScanCode(a3),d0
	bne .skd1
	
;	move.w _KeybdMsg(a3),a0
	addq.w #1,14(a0)							; increment repeat count
	bra .0003
.skd1
	clr.l d0
	move.w _hKeybdMbx(a3),d0
	move.l #WM_KEYDOWN,d1
	clr.l d2
	move.b _KeyState2(a3),d2
	lsl.l #8,d2
	move.b _ScanCode(a3),d2
	swap d2
;	move.w _RepCnt(a3),d2
	clr.b d3
	move.b _VirtKey,d3
	lea _KeyState(a3),a0
	move.b #1,(a0,d3.w)
	jsr _FMTK_SendMsg
	bra .0003

.sendKeyup
	clr.l d0
	move.w _hKeybdMbx(a3),d0
	move.l #WM_KEYUP,d1
	clr.l d2
	move.b _KeyState2(a3),d2
	lsl.l #8,d2
	move.b _ScanCode(a3),d2
	swap d2
;	move.w _RepCnt(a3),d2
	clr.b d3
	move.b _VirtKey,d3
	lea _KeyState(a3),a0
	move.b #-1,(a0,d3.w)
	jsr _FMTK_SendMsg
	bra .0003

.0001
	rts

.doKeyup:
	move.b #-1,_KeyState1(a3)
	bra .0003
.doExtend:
	or.b #$80,_KeyState2(a3)
	bra .0003
.doCtrl:
	move.b _KeyState1(a3),d1
	clr.b	_KeyState1(a3)
	tst.b	d1
	bpl.s	.0004
	bclr #2,_KeyState2(a3)
	bra .0003
.0004:
	bset #2,_KeyState2(a3)
	bra .0003
.doAlt:
	move.b _KeyState1(a3),d1
	clr.b	_KeyState1(a3)
	tst.b	d1
	bpl .0011
	bclr #1,_KeyState2(a3)
	bra	.0003
.0011:
	bset #1,_KeyState2(a3)
	bra .0003
.doTab:
	move.l d1,-(a7)
  move.b _KeyState2(a3),d1
  btst #1,d1                 ; is ALT down ?
  beq .0012
;    	inc     _iof_switch
  move.l (a7)+,d1
  bra .0003
.0012:
  move.l (a7)+,d1
  bra .0013
.doShift:
	move.b _KeyState1(a3),d1
	clr.b	_KeyState1(a3)
	tst.b	d1
	bpl.s	.0005
	bclr #0,_KeyState2(a3)
	bra	.0003
.0005:
	bset #0,_KeyState2(a3)
	bra	.0003
.doNumLock:
	bchg #4,_KeyState2(a3)
	bsr KeybdSetLEDStatus
	bra .0003
.doCapsLock:
	bchg #5,_KeyState2(a3)
	bsr KeybdSetLEDStatus
	bra	.0003
.doScrollLock:
	bchg #6,_KeyState2(a3)
	bsr KeybdSetLEDStatus
	bra	.0003

