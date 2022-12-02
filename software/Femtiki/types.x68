; Thread Control Block
TCBMagic    EQU		$0000
TCBRegs  		EQU   $0004		; register set storage area
TCBUSP			EQU		$0044
TCBSSP			EQU		$0048
TCBSR				EQU		$004C
TCBPC				EQU		$0050
TCBStatus		EQU		$0054
TCBPriority	EQU		$0055
TCBWaitMbx	EQU		$0056
TCBHasFocus EQU   $005A
TCBStackBot	EQU		$005C
TCBMsgD1		EQU		$0060
TCBMsgD2		EQU		$0064
TCBMsgD3		EQU		$0068
TCBStartTick	EQU	$006C
TCBEndTick	EQU		$0070
TCBTicks		EQU		$0074
TCBException	EQU	$0078
TCBNext			EQU		$007C
TCBPrev			EQU		$0080
TCBAffinity	EQU		$0084
TCBTimeout	EQU		$0088
TCBtid      EQU   $008C
TCBmid      EQU   $0090
TCBappid    EQU   $0094
TCBOpMode   EQU   $0098
TCBMbxNext  EQU   $009C
TCBMbxPrev  EQU   $00A0
TCBThreadNum  EQU   $00A4
TCBAcbNext	EQU		$00A8
TCBAcbPrev	EQU		$00AC
TCBhMailboxes	EQU		$00B0
TCBName			EQU		$00C0
TCB_SIZE		EQU		$0100

MBC_MAGIC		equ		0
MBX_OWNER		equ		4		; tid of owning task
MBX_LINK    equ   8
MBX_TQHEAD  equ   12   ; link field for free list shared with task queue head
MBX_TQTAIL  equ   16
MBX_MQHEAD	equ		20
MBX_MQTAIL	equ		24
MBX_SIZE		equ		32

MSG_MAGIC   equ   0
MSG_LINK	  equ		4
MSG_RETADR  equ   8
MSG_TGTADR  equ   12
MSG_TYPE    equ   16
MSG_D1		  equ		20
MSG_D2		  equ		24
MSG_D3		  equ		28
MSG_SIZE	  equ		32
