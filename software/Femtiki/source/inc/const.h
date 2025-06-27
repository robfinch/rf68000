#ifndef CONST_H
#define CONST_H
#include <stdint.h>

#define TRUE        1
#define FALSE       0

#define null        (void *)0
//#define NULL				(void *)0
#define MAX_UINT    0xFFFFFFFF
#define MAX_INT		0x7FFFFFFF
#define TS_NONE     0
#define TS_TIMEOUT  1
#define TS_WAITMSG  2
#define TS_PREEMPT  4
#define TS_RUNNING  8
#define TS_READY   16

#define MQS_UNLIMITED    0
#define MQS_OLDEST       1
#define MQS_NEWEST       2

#define MBT_DATA         2
// message types
#define MT_NONE          0             // not a message
#define MT_FREE          1

enum {
     E_Ok = 0,
     E_BadTCBHandle,
     E_BadPriority,
     E_BadCallno,
     E_BadEntryno,
     E_Arg,
     E_BadASID,
     E_BadMapno,
     E_BadMbx,
     E_QueFull,
     // 10
     E_NoThread,
     E_NotAlloc,
     E_NoMsg,
     E_Timeout,
     E_BadAlarm,
     E_NotOwner,
     E_QueStrategy,
     E_DCBInUse,
	 E_Busy,
	 E_BadPageno,
	 	// 20
	 E_PagesizeMismatch,

     //; Device driver errors
     E_BadDevNum = 0x20,
     E_NoDev,
     E_BadDevOp,
     E_ReadError,
     E_WriteError,
     E_BadBlockNum,
     E_TooManyBlocks,

     // resource errors
     E_NoMoreMbx = 0x40,
     E_NoMoreMsgBlks,
     // 30
     E_NoMoreAlarmBlks,
     E_NoMoreACBs,
     E_NoMoreTCBs,
     E_NoMem,
     E_TooManyTasks
};

#define OBJ_MAGIC	(('O') | ('B' << 8) | ('J' << 16) | ('\0' << 24))
#define ACB_MAGIC	(('A') | ('C' << 8) | ('B' << 16) | ('\0' << 24))

#define OL_USER			3
#define OL_SUPERVISOR	2
#define OL_HYPERVISOR	1
#define OL_MACHINE		0

#define OBJ_WHITE		2
#define OBJ_GREY		1
#define OBJ_BLACK		0

#define MMU_WR	4
#define MMU_RD	2
#define MMU_EX	1

#define OS_INIT	0
#define OS_START_TASK	1
#define OS_EXIT_TASK 2
#define OS_KILL_TASK 3
#define OS_SET_TASK_PRIORITY	4
#define OS_SLEEP 5
#define OS_WAITMSG 6
#define OS_SENDMSG 7
#define OS_PEEKMSG 8
#define OS_CHECKMSG 9
#define OS_ALLOC_MBX 10
#define OS_FREE_MBX 11
#define OS_START_APP	12

#define MEMORY_SEMA	6
#define PMT_SEMA 10

/*
; the following constant is used to scramble device handles. The device handle
; (address) is rotated 16 bits then xor'd with this value.
*/

#define DEV_HMASH	0x56791123

#define DEV_INIT equ 0
#define DEV_STAT equ 1
#define DEV_PUTCHAR equ 2
#define DEV_PUTBUF equ 3
#define DEV_GETCHAR equ 4
#define DEV_GETBUF equ 5
#define DEV_SET_INPOS equ 6
#define DEV_SET_OUTPOS equ 7
#define DEV_GETCHAR_DIRECT equ 8
#define DEV_PEEKCHAR equ 9
#define DEV_PEEKCHAR_DIRECT equ 10
#define DEV_PUTCHAR_DIRECT equ 11
#define DEV_CLEAR equ 12
#define DEV_SWAPBUF equ 13
#define DEV_SETBUF1 equ 14
#define DEV_SETBUF2 equ 15
#define DEV_GETBUF1 equ 16
#define DEV_GETBUF2 equ 17
#define DEV_WRITEAT equ 18
#define DEV_SETUNIT equ 19
#define DEV_GET_DIMEN equ 20
#define DEV_GET_COLOR equ 21
#define DEV_GET_INPOS equ 22
#define DEV_GET_OUTPOS equ 23
#define DEV_GET_OUTPTR equ 24
#define DEV_SET_COLOR equ 25
#define DEV_SET_COLOR123 equ 26
#define DEV_PLOT_POINT equ 27
#define DEV_DRAW_LINE equ 28
#define DEV_DRAW_TRIANGLE equ 29
#define DEV_DRAW_RECTANGLE equ 30
#define DEV_DRAW_CURVE equ 31
#define DEV_SET_DIMEN equ 32
#define DEV_SET_COLOR_DEPTH equ 33
#define DEV_SET_DESTBUF equ 34
#define DEV_SET_DISPBUF equ 35
#define DEV_GET_INPTR equ 36

typedef struct _tagDCB
{
	uint32_t magic;					// 'DCB '
	uint8_t name[12];				// eleven chars + NULL
	int32_t (*cmdproc)();
	int32_t inpos_x;
	int32_t inpos_y;
	int32_t inpos_z;
	int32_t outpos_x;
	int32_t outpos_y;
	int32_t outpos_z;
	uint32_t inbufptr;
	uint32_t outbufptr;
	uint32_t inbuf_size;
	uint32_t outbuf_size;
	uint32_t indim_x;
	uint32_t indim_y;
	uint32_t indim_z;
	uint32_t outdim_x;
	uint32_t outdim_y;
	uint32_t outdim_z;
	uint32_t bk_color;
	uint32_t fg_color;
	uint32_t opcode;
	int32_t lasterc;
	uint32_t inbufptr2;
	uint32_t outbufptr2;
	uint32_t inbuf_size2;
	uint32_t outbuf_size2;
	int32_t unit;
} DCB;

/*
;Standard Devices are:

;#		Device					Standard name

;0		NULL device 			NUL		(OS built-in)
;1		Keyboard (sequential)	KBD		(OS built-in, ReadOnly)
;2		Video (sequential)		VID		(OS built-in, WriteOnly)
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
#endif
