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
hKeybdMbx			EQU		$001002BA
hFocusSwitchMbx		EQU		$001002BC
BIOS_RespMbx	EQU		$001002BE
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
_FMTK_Inited
	ds.l	1
_sys_pages_available
	ds.l	1
_nMsgBlk
	ds.l	1
_nMessage
	ds.l	1
_nMailbox
	ds.l	1
_DeviceTable
	ds.b	6144
_hDevMailbox
	ds.w	64

_ACBList
	ds.l	1
_ACBPtrs
	ds.l	64
_RunningTCB
	ds.w	1
_IOFocus
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
_iof_switch
	ds.b	1

KeybdLEDs
	ds.b	1
_KeyState1
	ds.b	1
_KeyState2
	ds.b	1
_KeybdHead
	ds.b	1
_KeybdTail
	ds.b	1
_KeybdCnt
	ds.b	1
KeybdEcho
	ds.b	1
KeybdWaitFlag
	ds.b	1
	align 2
KeybdID
	ds.l	1
_Keybd_tick
	ds.l	1
_KeybdBuf
	ds.b	32
_KeybdOBuf
	ds.b	32

	align 2
_SysAcb
	ds.b	16384
_PAM
	ds.l	2048
_PAMEnd

_FemtikiVars_end

	global _FMTK_Inited
	global _sys_pages_available
	global _ACBList
	global _ACBPtrs
	global _nMsgBlk
	global _nMailbox
	global _DeviceTable
	global _hDevMailbox
	global _RunningTCB
	global _IOFocus
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

	global KeybdLEDs
	global _KeyState1
	global _KeyState2
	global _KeybdHead
	global _KeybdTail
	global _Keybdnt
	global KeybdID	
	global _Keybd_tick
	global _KeybdBuf
	global _KeybdOBuf
	global _KeybdCnt
	global KeybdEcho
	global KeybdWaitFlag


;gc_stack		rmb		512
;gc_pc				fcdw		0
;gc_omapno		fcw			0
;gc_mapno		fcw			0
;gc_dl				fcw			0
