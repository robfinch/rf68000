	section dram
_PMT
	ds.b	65536*16
_tcbs
	ds.b	4096*256
_tcbs_end
_message
	ds.b	8192*32
_message_end
_mailbox
	ds.b	8192*12
_mailbox_end
_acbs
	ds.b	32*32768
_acbs_end
	global _tcbs
	global _message
	global _mailbox
	
PAMShareCounts	EQU	$20000000	; one byte for each physical page of memory


sys_stacks			EQU	$DF0000

FemtikiVars			EQU	$00100200
PAMLastAllocate2	EQU		$00100218
RunningAppID	EQU		$00100220
MidStackBottoms	EQU		$00100264
FemtikiInited	EQU		$00100284
IOFocusList		EQU		$0010028C
iof_switch		EQU		$001002AD
hKeybdMbx			EQU		$001002BA
hFocusSwitchMbx		EQU		$001002BC
BIOS_RespMbx	EQU		$001002BE
hasUltraHighPriorityTasks	EQU		$001002C0
im_save				EQU		$001002C2
sp_tmp				EQU		$001002C4
startQNdx			EQU		$001002C6
NPAGES				EQU		$001002D8
syspages			EQU		$001002DA
mmu_FreeMaps	EQU		$001002E0
mmu_entries		EQU		$00100300
freelist			EQU		$00100302
hSearchMap		EQU		$00100304
OSActive			EQU		$00100305
QueueCycle    EQU   $0010031C
FemtikiVars_end	EQU	$00100400

	section gvars
_sys_pages_available
	ds.l	1
_nMsgBlk
	ds.l	1
_nMessage
	ds.l	1
_nMailbox
	ds.l	1
_ACBPtrs
	ds.l	64
_RunningTCB
	ds.w	1
_IOFocusID
	ds.l	1
_FreeTCB
_freeTCB
	ds.w	1
_FreeACB
	ds.w	1
_FreeMSG
_freeMSG
	ds.w	1
_FreeMBX
_freeMBX
	ds.w	1
_missed_ticks
	ds.l	1
_TimeoutList
	ds.l	1
_readyQ
	ds.w	32
_readyQEnd

_hasUltraHighPriorityTasks
	ds.b	1
	align 2
_SysAcb
	ds.b	16384
_PAM
	ds.l	2048
_PAMEnd

_FemtikiVars_end

	global _sys_pages_available
	global _ACBPtrs
	global _nMsgBlk
	global _nMailbox
	global _RunningTCB
	global _IOFocusID
	global _FreeTCB
	global _freeTCB
	global _FreeACB
	global _FreeMSG
	global _freeMSG
	global _FreeMBX
	global _freeMBX
	global _missed_ticks
	global _TimeoutList
	global _readyQ
	global _SysACB
	global _PMT
	global _PAM
	global _PAMEnd
	global _hasUltraHighPriorityTasks


;gc_stack		rmb		512
;gc_pc				fcdw		0
;gc_omapno		fcw			0
;gc_mapno		fcw			0
;gc_dl				fcw			0
