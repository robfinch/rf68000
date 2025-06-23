
	global _nPagesFree
	global _oMemMax
	global rgPAM
	global sPAM
	global MarkPage
	global UnMarkPage
	global LinToPhy
	global _AliasMem
	global _DeAliasMem
	global _DeAllocPage
	global _QueryPages
	global _GetPhyAdd		

	align 2
OSCmdTable:
	dc.l	_SendMsg
	dc.l	_WaitMsg
	dc.l	_AliasMem
	dc.l	_DeAliasMem
	dc.l	_QueryPages
	dc.l	_GetPhyAdd

OSTrap:
	cmp.l #10,d7
	bhs.s .argerr
	move.w currentPID,d0
	ospush #0,d0								; push current PID onto OS stack #0
	move.w #1,MMU+$2100					; set PID in MMU to OS pid
	move.w #1,currentPID				; set current PID to OS pid
	lsl.l #2,d7
	lea OSCmdTable,a0
	move.l (a0,d7.w),a0
	jsr (a0)
	ospush #1,d0								; save d0 on stack #1
	ospop #0,d0									; get old PID back
	move.w d0,MMU+$2100					; set in MMU
	move.w d0,currentPID				; and current PID
	ospop #1,d0									; get back d0
	rte
.argerr
	moveq #E_Arg,d0
	rte
