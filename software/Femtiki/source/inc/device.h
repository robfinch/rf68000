// ============================================================================
//        __
//   \\__/ o\    (C) 2018-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	device.h
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ============================================================================
//
// Device command opcodes
//
#include <stdint.h>
#include "config.h"
#include "types.h"

/*
; the following constant is used to scramble device handles. The device handle
; (address) is rotated 16 bits then xor'd with this value.
*/

#define DEV_HMASH	0x56791123

#define DEV_NOP 0
#define DEV_SETUP 1
#define DEV_INIT 2
#define DEV_STAT 3
#define DEV_MEDIA_CHECK 4
#define DEV_OPEN 6
#define DEV_CLOSE 7
#define DEV_GETCHAR 8
#define DEV_PEEKCHAR 9
#define DEV_GETCHAR_DIRECT 10
#define DEV_PEEKCHAR_DIRECT 11
#define DEV_INPUT_STATUS 12
#define DEV_PUTCHAR 13
#define DEV_PUTCHAR_DIRECT 14
#define DEV_SET_POSITION 15
#define DEV_READ_BLOCK 16
#define DEV_WRITE_BLOCK 17
#define DEV_VERIFY_BLOCK 18
#define DEV_OUTPUT_STATUS 19
#define DEV_FLUSH_INPUT 20
#define DEV_FLUST_OUTPUT 21
#define DEV_IRQ 22
#define DEV_IS_REMOVEABLE 23
#define DEV_IOCTRL_READ 24
#define DEV_IOCTRL_WRITE 25
#define DEV_OUTPUT_UNTIL_BUSY 26
#define DEV_SHUTDOWN 27
#define DEV_CLEAR  28
#define DEV_SWAPBUF 29
#define DEV_SETBUF1 30
#define DEV_SETBUF2 31
#define DEV_GETBUF1 32
#define DEV_GETBUF2 33
#define DEV_GET_DIMEN 34
#define DEV_GET_COLOR 35
#define DEV_GET_POSITION 36
#define DEV_SET_COLOR 37
#define DEV_SET_COLOR123 38
#define DEV_PLOT_POINT 40
#define DEV_DRAW_LINE 41
#define DEV_DRAW_TRIANGLE 42
#define DEV_DRAW_RECTANGLE 43
#define DEV_DRAW_CURVE 44
#define DEV_SET_DIMEN 45
#define DEV_SET_COLOR_DEPTH 46
#define DEV_SET_DESTBUF 47
#define DEV_SET_DISPBUF 48
#define DEV_GET_INPOS 49
#define DEV_SET_INPOS 50
#define DEV_SET_OUTPOS 51
#define DEV_GET_OUTPOS 52
#define DEV_GET_INPTR	53
#define DEV_GET_OUTPTR 54
#define DEV_SET_UNIT 55
#define DEV_SET_ECHO 56
//#define MAX_DEV_OP		31

#define DVT_Block			0
#define DVT_Unit			1

typedef struct _tagDCB {
	char magic[4];		// 'DCB '
	char name[12];		// first char is length, 11 chars max
	int32_t (*cmdproc)();
	int8_t type;
	int8_t ReentCount;
	int8_t fSingleUser;
	int8_t UnitSize;
	int8_t pad1[4];
	long nBPB;
	long LastErc;			// last error code
	long StartBlock;
	long nBlocks;
	hMBX hMbxSend;
	hMBX hMbxRcv;
	hACB hApp;
	short int resv1;
	int8_t *pSema;
	long resv2[2];
} DCB;	// 64 bytes

extern DCB DeviceTable[NR_DCB];

/*
;Standard Devices are:

;#		Device					Standard name

;0		NULL device 			NUL		(OS built-in)
;1		Keyboard (sequential)	KBD		(OS built-in)
;2		Text Video (sequential)		TEXTVID		(OS built-in)
;3		Printer (parallel 1)	LPT		(OS built-in)
;4		Printer (parallel 2)	LPT2	(OS built-in)
;5		RS-232 1				COM1	(OS built-in)
;6		RS-232 2				COM2	(OS built-in)
;7		RS-232 3				COM3	(OS built-in)
;8		RS-232 4				COM4	(OS built-in)
;9
;10		Floppy					FD0 	(OS built-in)
;11		Floppy					FD1 	(OS built-in)
;12		Hard disk				HD0 	(OS built-in)
;13		Hard disk				HD1 	(OS built-in)
;14
;15
;16
;17
;18
;19
;20
;21
;22
;23
*/
