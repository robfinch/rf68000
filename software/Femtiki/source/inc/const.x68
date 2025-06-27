; ============================================================================
;        __
;   \\__/ o\    (C) 2020-2022  Robert Finch, Waterloo
;    \  __ /    All rights reserved.
;     \/_//     robfinch<remove>@finitron.ca
;       ||
;  
;
; BSD 3-Clause License
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, this
;    list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its
;    contributors may be used to endorse or promote products derived from
;    this software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; ============================================================================

TS_NONE			EQU		0
TS_READY		EQU		1
TS_DEAD			EQU		2
TS_MSGRDY		EQU		4
TS_WAITMSG	EQU		8
TS_TIMEOUT	EQU		16
TS_PREEMPT	EQU		32
TS_RUNNING	EQU		128

; error codes
E_Ok		EQU		0
E_BadTCBHandle equ 1
E_BadPriority equ 2
E_BadCallno equ 3
E_BadEntryno equ 4
E_Arg	equ 5
;E_Func  EQU    $02
E_BadMbx	EQU		8
E_QueFull	EQU		9
E_NoThread	EQU		10
E_NotAlloc	EQU		11
E_NoMsg		EQU		12
E_Timeout	EQU		13
E_BadAlarm	EQU		14
E_NotOwner	EQU		15
E_QueStrategy EQU		16
E_DCBInUse	EQU		17
E_Busy equ 18
E_BadPageno equ 19
E_PagesizeMismatch equ 20

E_NotSupported equ 21
E_BadLinAddr equ 22
E_BadAlias equ 23
E_ShortMem equ 24

; Device driver errors
E_BadDevNum	EQU		32
E_NoDev		EQU		33
E_BadDevOp	EQU		34
E_ReadError	EQU		35
E_WriteError EQU		36
E_BadBlockNum	EQU	37
E_TooManyBlocks	EQU	38
E_InitErr EQU 39

; resource errors
E_NoMoreMbx	EQU		64
E_NoMoreMsgBlks	EQU	65
E_NoMoreAlarmBlks	EQU 66
E_NoMoreACBs	EQU	67
E_NoMoreTCBs	EQU	68
E_NoMem		EQU 69
E_TooManyTasks equ 70

OS_INIT	equ 0
OS_START_TASK	equ 1
OS_EXIT_TASK equ 2
OS_KILL_TASK equ 3
OS_SET_TASK_PRIORITY	equ 4
OS_SLEEP equ 5
OS_WAITMSG equ 6
OS_SENDMSG equ 7
OS_PEEKMSG equ 8
OS_CHECKMSG equ 9
OS_ALLOC_MBX equ 10
OS_FREE_MBX equ 11

SERIAL_SEMA	EQU	2
KEYBD_SEMA	EQU	3
RAND_SEMA		EQU	4
SCREEN_SEMA	EQU	5
MEMORY_SEMA EQU 6
TCB_SEMA 		EQU	7
FMTK_SEMA		EQU	8
OSSEMA			EQU	8
IOFSEMA			EQU 9
PMT_SEMA		EQU	10

MMU	equ	$FDC00000

SC_F12  EQU    $07
SC_C    EQU    $21
SC_T    EQU    $2C
SC_Z    EQU    $1A
SC_KEYUP	EQU		$F0
SC_EXTEND   EQU		$E0
SC_CTRL		EQU		$14
SC_RSHIFT	EQU		$59
SC_NUMLOCK	EQU		$77
SC_SCROLLLOCK	EQU	$7E
SC_CAPSLOCK		EQU	$58
SC_ALT		EQU		$11
SC_LSHIFT	EQU		$12
SC_DEL		EQU		$71		; extend
SC_LCTRL	EQU		$58
SC_TAB      EQU		$0D

