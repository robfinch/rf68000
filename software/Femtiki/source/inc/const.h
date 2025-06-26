#ifndef CONST_H
#define CONST_H

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
     E_BadDevNum,// =	0x20,
     E_NoDev,
     E_BadDevOp,
     E_ReadError,
     E_WriteError,
     E_BadBlockNum,
     E_TooManyBlocks,

     // resource errors
     E_NoMoreMbx,// =	0x40,
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

#endif
