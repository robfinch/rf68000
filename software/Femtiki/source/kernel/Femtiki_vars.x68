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

	section local_ram
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
_DeviceTable
	ds.b	6144
spi_buff
	ds.b	512

TextRows
	ds.b	1
TextCols
	ds.b	1
CursorRow
	ds.b	1
CursorCol
	ds.b	1
TextPos
TextCurpos
	ds.w	1
	align 2
TextScr
	ds.l	1
S19StartAddress
	ds.l	1
S19Checksum
	ds.l	1
CmdBuf
	ds.b	64
CmdBufEnd
	align 2
fgColor
	ds.l	1
bkColor
	ds.l	1
_fpTextIncr
	ds.l	1
_canary
	ds.l	1
tickcnt
	ds.l	1
IRQFlag
	ds.l	1
InputDevice
	ds.l	1
OutputDevice
	ds.l	1
Regsave
	ds.l	96
BreakpointFlag
	ds.l	1
NumSetBreakpoints
	ds.l	1
Breakpoints
	ds.l	8
BreakpointWords
	ds.w	8
fpBuf
	ds.b  32
	align 2
_exp
	ds.l	1
_digit
	ds.l	1
_width 
	ds.l	1
_E
	ds.l	1
_digits_before_decpt
	ds.l	1
_precision
	ds.l	1
_fpBuf
	ds.b	64
_fpWork
	ds.b	512
_dasmbuf
	ds.b	128
OFFSET
	ds.l	1
	align 4
pen_color
	ds.l	1
gr_x
	ds.l	1
gr_y
	ds.l	1
gr_width
	ds.l	1
gr_height
	ds.l	1
gr_bitmap_screen
	ds.l	1
gr_raster_op
	ds.l	1
gr_double_buffer
	ds.l	1
gr_bitmap_buffer
	ds.l	1
sys_switches
	ds.l	2
gfxaccel_ctrl
	ds.l	1
m_z
	ds.l	1
m_w
	ds.l	1
next_m_z
	ds.l	1
next_m_w
	ds.l	1
TimeBuf
	ds.b	160
numwka
	ds.b	80

;EightPixels equ $40100000	; to $40200020

	section gvars
scratch_ram
IOFocus
_IOFocus
	ds.l	1
memend
	ds.l	1
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
_hDevMailbox
	ds.w	64

_ACBList
	ds.l	1
_ACBPtrs
	ds.l	64
_RunningTCB
	ds.w	1
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

SerTailRcv
	ds.w	1
SerHeadRcv
	ds.w	1
SerRcvXon
	ds.b	1
SerRcvXoff
	ds.b	1
SerTailXmit
	ds.w	1
SerHeadXmit
	ds.w	1
SerXmitXoff
	ds.l	1
	align 12
SerRcvBuf
	ds.b	4096
SerXmitBuf
	ds.b	4096
RTCBuf			
	ds.b	256

	align 2
_SysAcb
	ds.b	16384
_PAM
	ds.l	2048
_PAMEnd

_FemtikiVars_end

	global scratch_ram
	global IOFocus
	global _IOFocus
	global memend
	global TextRows
	global TextCols
	global CursorRow
	global CursorCol
	global TextPos
	global TextCurpos
	global TextScr
	global S19StartAddress
	global S19Checksum
	global CmdBuf
	global CmdBufEnd
	global fgColor
	global bkColor
	global _fpTextIncr
	global _canary
	global tickcnt
	global IRQFlag
	global InputDevice
	global OutputDevice
	global Regsave
	global BreakpointFlag
	global NumSetBreakpoints
	global Breakpoints
	global BreakpointWords
	global fpBuf
	global _exp
	global _digit
	global _width 
	global _E
	global _digits_before_decpt
	global _precision
	global _fpBuf
	global _fpWork
	global _dasmbuf
	global OFFSET
	global pen_color
	global gr_x
	global gr_y
	global gr_width
	global gr_height
	global gr_bitmap_screen
	global gr_raster_op
	global gr_double_buffer
	global gr_bitmap_buffer
	global sys_switches
	global gfxaccel_ctrl
	global m_z
	global m_w
	global next_m_z
	global next_m_w
	global TimeBuf
	global numwka

	global _FMTK_Inited
	global _sys_pages_available
	global _ACBList
	global _ACBPtrs
	global _nMsgBlk
	global _nMailbox
	global _DeviceTable
	global _hDevMailbox
	global _RunningTCB
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
	global SerTailRcv
	global SerHeadRcv
	global SerRcvXon
	global SerRcvXoff
	global SerTailXmit
	global SerHeadXmit
	global SerXmitXoff
	global SerRcvBuf
	global SerXmitBuf
	global RTCBuf			

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
