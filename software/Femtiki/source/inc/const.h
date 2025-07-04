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

// message types
#define MT_NONE          0             // not a message
#define MT_FREE          1
#define MT_DATA          2
#define MT_RQB					 3
#define MT_RESP					 4

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
     E_NoTask,
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
	 E_Service,
	 E_OwnerAbort,
	 E_BadAlias,

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
     E_TooManyTasks,
     E_NoMoreRbqs
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
#define OS_REGISTER_SERVICE	13
#define OS_UNREGISTER_SERVICE 14
#define OS_GET_SERVICE_MBX 15
#define OS_ALLOC_SYSTEM_PAGES 16
#define OS_ALLOC_PAGES 17
#define OS_ALIAS_MEM 18
#define OS_DEALIAS_MEM 19

#define BIOS_SEMA		0
#define SERIAL_SEMA	2
#define KEYBD_SEMA	3
#define RAND_SEMA		4
#define SCREEN_SEMA	5
#define MEMORY_SEMA	6
#define TCB_SEMA 		7
#define OSSEMA			8
#define IOFSEMA			9
#define PMT_SEMA 		10

/*
; the following constant is used to scramble device handles. The device handle
; (address) is rotated 16 bits then xor'd with this value.
*/

#define DEV_HMASH	0x56791123


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
