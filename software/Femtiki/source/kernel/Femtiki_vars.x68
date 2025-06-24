
PAMShareCounts	EQU	$20000000	; one byte for each physical page of memory
tcbs						EQU	$20010000	; 4095*256 = 1MB
tcbs_end				EQU	$20020000
messages				EQU	$20020000	; 32*8192 (680*16=21760 messages)
messages_end		EQU	$20060000
mailboxes				EQU	$20060000
mailboxes_end		EQU	$20078000	;	12*8192 (816*12=9792 mailboxes)
acbs						EQU	$20080000	; 32*2*8192 =512kB
acbs_end				EQU	$20100000


sys_stacks			EQU	$DF0000

FemtikiVars			EQU	$00100200
PAMLastAllocate2	EQU		$00100218
RunningAppID	EQU		$00100220
RunningTCB		EQU		$00100224
ACBPtrs				EQU		$00100228
MidStackBottoms	EQU		$00100264
FemtikiInited	EQU		$00100284
missed_ticks	EQU		$00100288
IOFocusList		EQU		$0010028C
IOFocusID			EQU		$001002AC
iof_switch		EQU		$001002AD
nMessage			EQU		$001002AE
nMailbox			EQU		$001002B0
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
FreeACB				EQU		$00100308
FreeTCB				EQU		$0010030C
FreeMSG				EQU		$00100310
FreeMBX				EQU		$00100314
TimeoutList		EQU		$00100318
QueueCycle    EQU   $0010031C
readyQ				EQU		$00100320		; 32 bytes per queue per core, 2 cores for now
readyQEnd			EQU		$00100360
FemtikiVars_end	EQU	$00100400
_SysAcb				EQU		$00118000
_PAM					EQU		$0011E000

;gc_stack		rmb		512
;gc_pc				fcdw		0
;gc_omapno		fcw			0
;gc_mapno		fcw			0
;gc_dl				fcw			0
