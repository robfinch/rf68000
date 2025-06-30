#ifndef TYPES_H
#define TYPES_H

typedef unsigned int uint;
typedef short int hTCB;
typedef short int hACB;
typedef short int hMBX;
typedef short int hMSG;
typedef short int hRBQ;

#define PTE_PRESENT		13
#define PTE_ALIAS			12
#define PTE_SYSTEM		3
#define PTE_READ			2
#define PTE_WRITE			1
#define PTE_EXECUTE		0

typedef struct _tagPTE {
	unsigned int x : 1;
	unsigned int w : 1;
	unsigned int r : 1;
	unsigned int s : 1;
	unsigned int acr : 7;
	unsigned int end_of_run : 1;
	unsigned int alias : 1;
	unsigned int present : 1;
	unsigned int page : 18;
} PTE;

typedef struct _tagPDE {
	unsigned int acr : 14;
	unsigned int page : 18;
} PDE;

typedef struct _tagPMTE {
	unsigned char share_count;
	unsigned char acr;
	unsigned char pl;
	unsigned char u;
	unsigned char reserved;
	unsigned long refcount;
} PMTE;

typedef struct _tagPageTable {
	PTE pte[4096];
} PageTable;

typedef struct _tagPageDirectory {
	PDE pte[64];
} PageDirectory;

typedef struct _tagPageTables {
	PageTable pgtbl[256];
} PageTables;

typedef struct _tagMBLK {
	long magic;
	long size;
	struct _tagMBLK *next;
	struct _tagMBLK *prev;
} MBLK;

typedef struct _tagObject {
	int magic;
	int size;
//	__gc_skip skip1 {
		long typenum;
		long id;
		char state;			// WHITE, GREY, or BLACK
		char scavangeCount;
		char owningMap;
		char pad1;
		long pad2;
		unsigned int usedInMap;		
//	};
	struct _tagObject *forwardingAddress;
	void (*finalizer)();
} __object;

// Types of memory spaces
#define MS_FROM		0
#define MS_TO		1
#define MS_OLD		2
#define MS_PRIM		3
#define MS_LO		4
#define MS_CODE		5
#define MS_CELL		6
#define MS_PCELL	7
#define MS_MAP		8

typedef struct _tagMEMORY {
	unsigned int key;
	void *addr;
	int size;
	int owningMap;
	unsigned int shareMap;
	__object *allocptr;
	struct _tagMEMORY *next;
} MEMORY;

typedef struct _tagHeap {
	MEMORY mem[9];
	MEMORY *fromSpace;
	MEMORY *toSpace;
	int size;
	int owningMap;
	struct _tagHeap *next;
} HEAP;

typedef struct tagMSG {
	hMSG link;
	unsigned short int retadr;    // return address
	unsigned short int dstadr;    // target address
	unsigned short int type;
	unsigned long d1;            // payload data 1
	unsigned long d2;            // payload data 2
	unsigned long d3;            // payload data 3
} MSG;

#define MT_RQB	1

typedef struct _tagRQB {
	long magic;
	hACB owner;
	hRBQ next;
	hMBX service_mbx;
	hMBX response_mbx;
	short int handle;
	short int opcode;
	unsigned long d1;
	unsigned long d2;
	unsigned long d3;
	unsigned char *pData1;
	unsigned long cbData1;
	unsigned char *pData2;
	unsigned long cbData2;
	unsigned char *pData3;
	unsigned long cbData3;
	long pad[3];
} RQB;	// 64 bytes
/*
npSend			EQU 34	;DB 0h			; Number of Send PbCbs
npRecv			EQU 35	;DB 0h			; Number of Recv PbCbs

*/

typedef struct _tagService {
	char name[62];
	hMBX service_mbx;
} service_t;

// Application control block
typedef struct _tagACB
{
	unsigned long magic;			// "ACB "
	char* pEnv;
	// Text mode display buffer, 8kB
	unsigned long* pVirtVidMem;
	// Card memory for garbage collection.
	unsigned long* pCard;

	short int* pCode;

	// 256 bytes
	PageDirectory pd;
	char* brk;
	char* pData;
	int pDataSize;
	char* pUIData;
	int pUIDataSize;
	__object **gc_roots;
	int gc_rootcnt;
	int gc_ndx;
	__object **gc_markingQue;
	char gc_markingQueFull;
	char gc_markingQueEmpty;
	char gc_overflow;
  char is_system;
	struct _tagObject *objectList;
	struct _tagObject *garbage_list;
	HEAP Heap;
  struct _tagACB *iof_next;
  struct _tagACB *iof_prev;
  char UserName[32];
  char path[256];
  char exitRunFile[256];
  char commandLine[256];
  unsigned long *pVidMem;
  unsigned char VideoRows;
  unsigned char VideoCols;
  unsigned char CursorRow;
  unsigned char CursorCol;
  unsigned long NormAttr;
  short int KeyState1;
  short int KeyState2;
  short int KeybdWaitFlag;
  short int KeybdHead;
  short int KeybdTail;
  unsigned short int KeybdBuffer[32];
  hACB number;
  hACB next;
  hTCB task;
  int *templates[256];
} ACB;

struct tagMBX;

typedef struct _tagTCB {
    // exception storage area
	unsigned long regs[17];
	unsigned long ssp;
	double fpregs[8];
	int epc;
	int vl;
	int cr0;
	hTCB acbnext;				// task list associated with app
	hTCB next;
	hTCB prev;
	hTCB mbq_next;
	hTCB mbq_prev;
	int stacksize;
	long *stack;
	long *sys_stack;
	long *bios_stack;
	int timeout;
	MSG msg;
	hMBX hMailboxes[4]; // handles of mailboxes owned by task
	hMBX hWaitMbx;      // handle of mailbox task is waiting at
	hTCB number;
	hACB hApp;
	unsigned char priority;
	unsigned char status;
	unsigned long affinity;
	unsigned long startTick;
	unsigned long endTick;
	unsigned long ticks;
	unsigned long exception;
	unsigned short int* exceptionHandler;
} TCB;

typedef struct tagMBX {
  hMBX link;
	hACB owner;		// hApp of owner
	hTCB tq_head;
	hTCB tq_tail;
	hMSG mq_head;
	hMSG mq_tail;
	char mq_strategy;
	char resv[2];
	uint tq_count;
	uint mq_size;
	uint mq_count;
	uint mq_missed;
} MBX;

typedef struct tagALARM {
	struct tagALARM *next;
	struct tagALARM *prev;
	MBX *mbx;
	MSG *msg;
	uint BaseTimeout;
	uint timeout;
	uint repeat;
	char resv[8];		// padding to 64 bytes
} ALARM;

typedef struct tagAppStartupRec {
	int pagesize : 4;
	int priority : 4;
	int reserved : 24;
	unsigned long affinity;
	unsigned long codesize;
	unsigned long datasize;	// Initialized data
	unsigned long uidatasize;	// uninitialized data
	unsigned long heapsize;
	unsigned long stacksize;
	unsigned short int* pCode;
	unsigned long* pData;
	unsigned long* pUIData;
	char hasGarbageCollector;
} AppStartupRec;

#endif
