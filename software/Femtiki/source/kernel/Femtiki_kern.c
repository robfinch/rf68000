// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "..\inc\config.h"
#include "..\inc\const.h"
#include "..\inc\types.h"
#include "..\inc\proto.h"
#include "..\inc\glo.h"
//#include "TCB.h"

extern void DumpThreads();
extern void DisplayString(__reg("a1") char *str);
extern void ClearScreen();

extern hTCB freeTCB;

extern long __interrupt FMTK_Dispatch(
	__reg("d7") long,
	__reg("d0") long,
	__reg("d1") long,
	__reg("d2") long,
	__reg("d3") long,
	__reg("d4") long
);
extern void FMTK_TimerIRQLaunchpad(unsigned long);
extern void RQB_Initialize();
extern int GetRand(register int stream);
extern int shell();
extern int StartMon();
MEMORY memoryList[NR_MEMORY];

//int interrupt_table[512];
int reschedFlag;
int IRQFlag;
int irq_stack[512];
extern int FMTK_Inited;
extern ACB acbs[NR_ACB];
extern ACB *ACBPtrs[NR_ACB];
extern TCB tcbs[NR_TCB];
extern TBLK TimerBlocks[NR_TMRBLOCK];
extern hTCB readyQ[32];
extern int sysstack[1024];
extern int sys_stacks[NR_TCB][512];
extern int bios_stacks[NR_TCB][512];
extern int fmtk_irq_stack[512];
extern int fmtk_sys_stack[512];
extern MBX mailbox[NR_MBX];
extern MSG message[NR_MSG];
extern int nMsgBlk;
extern int nMailbox;
extern hACB freeACB;
extern hACB IOFocus;
extern int iof_switch;
extern long hasUltraHighPriorityTasks;
extern int missed_ticks;
extern int8_t hSearchApp;
extern int8_t hFreeApp;

extern hTCB TimeoutList;
extern hMBX hKeybdMbx;
extern hMBX hFocusSwitchMbx;
extern int im_save;



// This set of nops needed just before the function table so that the cpu may
// fetch nop instructions after going past the end of the routine linked prior
// to this one.

void FMTK_NopRamp() =
	"\trept 16\r\n"
	"\tnop\r\n"
	"\tendr\r\n"
;

static unsigned long GetTick() = "\tmovec.l tick,d0\r\n";

// Reset timer edge sense circuit
void AckTimerIRQ() =
	"\tmoveq #3,d0\r\n"
	"\tmove.l d0,PIC_ESR\r\n"
;

ACB *SafeGetACBPtr(register int n)
{
	if (n < 0 || n >= NR_ACB)
		return (null);
  return (ACBPtrs[n]);
}

ACB *GetACBPtr(int n)
{
  return (ACBPtrs[n-1]);
}

/*
hACB GetAppHandle()
{
	return (GetRunningTCBPtr()->hApp);
}
*/
/*
hACB GetRunningAppid()
{
	if (GetRunningTCBPtr())
		return (GetRunningTCBPtr()->hApp);
	else 
		return (1);
}
*/
/*
hACB GetRunningACB()
{
	return (GetAppHandle());
}
*/
ACB *GetRunningACBPtr()
{
	return (GetACBPtr(GetRunningAppid()));
}

ACB* ACBHandleToPointer(hACB h)
{
	return (ACBPtrs[h-1]);
}

TBLK* TBLKHandleToPointer(hTBLK h)
{
	return (&TimerBlocks[h-1]);
}

int GetRunningPID() =
	"\tmovec.l cpid,d0\r\n"
;

int IsSystemApp(hACB h)
{
	ACB* a;
	a = ACBHandleToPointer(h);
	if (a)
		return (a->is_system);
	else 
		return (0);
}

// ----------------------------------------------------------------------------
// Get the current interrupt mask level.
// ----------------------------------------------------------------------------

int GetImLevel() =
"\tmove sr,d0\r\n"
"\tlsr.w #8,d0\r\n"
"\tand.l #7,d0\r\n"
;

// ----------------------------------------------------------------------------
// SetImLevel will only set the interrupt mask level to level higher than the
// current one.
//
// Returns:
//		int	- the previous interrupt level setting
// ----------------------------------------------------------------------------

int SetImLevel(int level)
{
	int x;

	if ((x = GetImLevel()) >= level)
		return (x);
	SetImLevelHelper(level);
	return(x);
}

// ----------------------------------------------------------------------------
// Restore the thread's context.
//
// The registers were stored on the thread's IRQ stack when the timer ISR was
// entered. They will automatically be restored from the IRQ stack when the
// the ISR exits. The only thing required is to account for the other info
// related to the context.
// ----------------------------------------------------------------------------

void SwapContext(register TCB *octx, register TCB *nctx)
{
	ACB* p;

	SetMMUAppid(nctx->hApp);
	// Set the app's page directory in the MMU 
	p = ACBHandleToPointer(nctx->hApp);
	SetMMUPD(p->is_system ? 1 : 0, (long)&p->pd);
}

// ----------------------------------------------------------------------------
// Select a thread to run.
// ----------------------------------------------------------------------------

static int invert;

static hTCB SelectThreadToRunHelper(int nn)
{
	int kk;
  hTCB h, h1;
	TCB *p, *q;
 
	h = readyQ[nn];
	if (h > 0 && h <= NR_TCB) {
		p = TCBHandleToPointer(h);
    kk = 0;
    // Can run the head of a lower Q level if it's not the running
    // thread, otherwise look to the next thread.
    if (h != GetRunningTCB())
   		q = p;
		else
   		q = TCBHandleToPointer(p->next);
    do {  
      if (!(q->status & TS_RUNNING)) {
        if (q->affinity == getCPU() || q->affinity==63) {
        	h1 = TCBPointerToHandle(q);
			  	readyQ[nn] = h1;
			   	return (h1);
        }
      }
      q = TCBHandleToPointer(q->next);
      kk = kk + 1;
    } while (q != p && kk < NR_TCB);
  }
	return (-1);
}

static hTCB SelectThreadToRun()
{
	int nn;
  hTCB h;
 
 	invert++;
	// Occasionally prioriies are inverted.
	if ((invert & 31)==0) {
		for (nn = 0; nn < 32; nn++) {
			if ((h = SelectThreadToRunHelper(nn)) > 0)
				return (h);
		}
		return (GetRunningTCB());
	}
	// Search the queues from the highest to lowest priority.
	for (nn = 31; nn >= 0; nn--) {
		if ((h = SelectThreadToRunHelper(nn)) > 0)
			return (h);
	}
	return (GetRunningTCB());
	panic("No entries in ready queue.");
}

// ----------------------------------------------------------------------------
// FMTK primitives need to re-schedule threads in a couple of places.
// ----------------------------------------------------------------------------

void TriggerTimerIRQ() =
"\tmove.l #1,_reschedFlag\r\n"
"\tmove.l #29,$FD260000+$18\r\n"	// PIC
;

void FMTK_Reschedule()
{
	TriggerTimerIRQ();
}

// ----------------------------------------------------------------------------
// All cores will receive a timer interrupt.
//
// If timer interrupts are enabled during a priority #0 thread, this routine
// only updates the missed ticks and remains in the same thread. No timeouts
// are updated and no thread switches will occur. The timer tick routine
// basically has a fixed latency when priority #0 is present.
// ----------------------------------------------------------------------------

void FMTK_TimerTickIRQ()
{
  TCB *t, *ot, *tol;

  if (FMTK_Inited != FMTK_MAGIC) {
		tickcnt++;
		IRQFlag = 1;
		return;
  }
	ot = t = GetRunningTCBPtr();
	t->endTick = GetTick();
	// Explicit rescheduling request?
	if (reschedFlag) {
		reschedFlag = 0;
		t->ticks = t->ticks + (t->endTick - t->startTick);
		t->status |= TS_PREEMPT;
		t->status &= ~TS_RUNNING;
//		t->epc = t->epc + 1;  // advance the return address
		SetRunningTCBPtr(TCBHandleToPointer(SelectThreadToRun()));
		GetRunningTCBPtr()->status |= TS_RUNNING;
	}
	// Timer tick interrupt
	else {
		// Timer will auto-reset, the following line should not be necessary.
//		AckTimerIRQ();
		// Set IRQ flag for interpreters
		tickcnt++;
		IRQFlag = 1;
		// Allow threads to run at least 3 ticks before switching.
		if (1 || t->endTick - t->startTick > 3) {
			// Try and lock the system semaphore, but not too hard.
	//		if (LockReadyQueue(100)) {
				t->ticks = t->ticks + (t->endTick - t->startTick);
				if (t->priority != 31) {
					t->status |= TS_PREEMPT;
					t->status &= ~TS_RUNNING;
//					if (LockTimeoutList(1000)) {
						while (TimeoutList > 0 && TimeoutList <= NR_TCB) {
							tol = TCBHandleToPointer(TimeoutList);
							if (tol->timeout <= 0)
								TCBInsertIntoReadyQueue(TCBPopTimeoutList());
							else {
								tol->timeout = tol->timeout - missed_ticks - 1;
								missed_ticks = 0;
								break;
							}
						}
//						UnlockTImeoutList();
//					}
					if (t->priority < 28)
						SetRunningTCBPtr(TCBHandleToPointer(SelectThreadToRun()));
					GetRunningTCBPtr()->status |= TS_RUNNING;
				}
				else
					missed_ticks++;
//				UnlockReadyQueue();
//			}
//			else {
//				missed_ticks++;
//			}
		}
	}
	// If an exception was flagged (eg CTRL-C) return to the catch handler
	// not the interrupted code.
	t = GetRunningTCBPtr();
	if (t->exception) {
		// Dig into the stack here to set registers
		t->regs[1] = t->exception;				// d1 = exception value
		t->regs[2] = 45;									// d2 = exception type
		t->pc = (unsigned long)t->exceptionHandler;	// Now copy exception handler address
	}
	if (ot != t) {
		t->startTick = GetTick();		// Only starting if context is switching to thread.
		SwapContext(ot,t);
	}
}

// We're getting a timer block IRQ because a count has reached zero. Call all
// the callback functions with zero counts.

void FMTK_TimerBlockIRQ()
{
	TBLK* tb;
	hTBLK htb;
	ACB* p;
	hACB ha;
	unsigned long pd;
	unsigned long* PIT = (unsigned long*)0xFDFEC000;

	// If the timer block list cannot be locked, there is likely a system call
	// to allocate a timer block for use. It should be done is short order.
	if (LockTimerBlockList(100)) {
		// As long as the block list is a valid handle.
		while (TimerBlockList > 0 && TimerBlockList <= NR_TMRBLOCK) {
			htb = TimerBlockList;
			tb = TBLKHandleToPointer(TimerBlockList);
			// Get the current page directory	
			ha = GetRunningAppid();
			p = ACBHandleToPointer(ha);
			pd = (unsigned long)&p->pd;
			// Call the callback function.
			while (tb->countdown==0) {
				// Set page directory to callback space
				ha = tb->appid;
				p = ACBHandleToPointer(ha);
				SetMMUPD(USERPD,(unsigned long)&p->pd);
				// Call callback function
				if (tb->func)
					(*tb->func)();
				htb = TimerBlockList;
				TimerBlockList = tb->next;
				tb->next = freeTBLK;
				freeTBLK = htb;
				tb = TBLKHandleToPointer(TimerBlockList);
				if (TimerBlockList <= 0)
					break;
			}
			// Restore page directory
			SetMMUPD(USERPD,pd);
		}
		// Program the PIT for the next countdown.
		if (TimerBlockList > 0) {
			PIT[5*4+1] = tb->countdown;
			PIT[5*4+2] = 5;			// pulse is 5 clocks wide
			PIT[5*4+3] = 0x83;	//load,enable,no auto-reload,internal clock,ignore gate,set
		}
	}
	UnlockTimerBlockList();
}

void panic(char *msg)
{
//     putstr(msg);
j1:  goto j1;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

long IdleStack[300];

void IdleThread()
{
   int ii;
   unsigned long *screen = (unsigned long *)0xFFD00000L;

   while(1) {
     ii++;
     if (get_coreno()==0) {
       screen[57] = 0x000F0000L|ii;
		 }
   }
}

long FMTK_ExceptionHandler(__reg("d0") long val, __reg("d1") long typ)
{
	if (typ==515) {
		puts("Default exception handler: CTRL-C pressed.\r\n");
		FMTK_ExitThread();
	}
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

long FMTK_KillThread(__reg("d0") long threadno)
{
  hTCB ht, pht;
  hACB hApp;
  int nn;
  ACB *j;

  ht = threadno-1;
  if (LockSysSemaphore(-1)) {
    TCBRemoveFromReadyQueue(ht);
    TCBRemoveFromTimeoutList(ht);
    for (nn = 0; nn < 4; nn++)
      if (tcbs[ht].hMailboxes[nn] >= 0 && tcbs[ht].hMailboxes[nn] < NR_MBX) {
        FMTK_FreeMbx(tcbs[ht].hMailboxes[nn]);
        tcbs[ht].hMailboxes[nn] = 0;
      }
    // remove thread from job's thread list
    hApp = tcbs[ht].hApp;
    j = GetACBPtr(hApp);
    ht = j->thread;
    if (ht==threadno)
    	j->thread = tcbs[ht].acbnext;
    else {
    	while (ht > 0) {
    		pht = ht;
    		ht = tcbs[ht].acbnext - 1;
    		if (ht==threadno-1) {
    			tcbs[pht].acbnext = tcbs[ht].acbnext;
    			break;
    		}
    	}
    }
		tcbs[ht].acbnext = 0;
    // If the job no longer has any threads associated with it, it is 
    // finished.
    if (j->thread == 0) {
    	j->magic = 0;
    	FreeACB(hApp);
    }
    UnlockSysSemaphore();
  }
  return (E_Ok);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

long FMTK_ExitThread()
{
  FMTK_KillThread(GetRunningTCB());
	// The thread should not return from this reschedule because it's been
	// killed.
	while(1) {
  	FMTK_Reschedule();
	}
	return (0);
}


// ----------------------------------------------------------------------------
// Start a thread.
// Stacks are automatically allocated for the system and app.
//
//
// Parameters:
//		d0 = starting address
//		d1 = pointer to parameter
//		d2 = info
//				bits 0 to 7 = priority
//				bits 16 to 31 = affinity
//
// Returns:
//	hTCB	positive number handle of thread started,
//			or negative number error code
// ----------------------------------------------------------------------------

long FMTK_StartThread(
	__reg("d0") long StartAddr,
	__reg("d1") long stack,
	__reg("d2") long parm,
	__reg("d3") long priority,
	__reg("d4") long affinity
)
{
  hTCB ht;
  TCB *t;
  int nn;
	hACB hApp;
	short int *sp2;
	unsigned long int* sp;
	int im_level;
	int stack_size;

	DisplayStringCRLF("StartThread");
	hApp = GetRunningAppid();

  while (LockTCBList(-1)==0);
	DisplayString("Locked TCB list, handle: ");
  ht = freeTCB;
  DisplayWyde(ht);
  DisplayStringCRLF(" ");
  if (ht <= 0 || ht > NR_TCB) {
    UnlockTCBList();
		DisplayStringCRLF("Unlocked TCB list - no more tcbs");
  	return (-E_NoMoreTCBs);
  }
  t = TCBHandleToPointer(ht);
  freeTCB = t->next;
  DisplayString("freeTCB=");
  DisplayWyde(freeTCB);
  DisplayStringCRLF(" ");
  UnlockTCBList();
	DisplayStringCRLF("Unlocked TCB list");

  t->affinity = affinity;
  t->priority = priority;
  t->hApp = hApp;
  // Insert into the job's list of threads.
  while (LockTCBList(-1)==0);
	DisplayStringCRLF("Locked TCB list");
	t->acbnext = ACBPtrs[hApp-1]->thread;
	ACBPtrs[hApp-1]->thread = ht;
	UnlockTCBList();
	DisplayStringCRLF("Unlocked TCB list");

  t->regs[0] = 0;
  t->regs[1] = parm;
  for (nn = 2; nn < 17; nn++)
  	t->regs[nn] = 0;
	t->pc = StartAddr;
	t->sr = 0x22002200;
	t->fmt = 0;
  t->startTick = GetTick();
  t->endTick = GetTick();
  t->ticks = 0;
  t->exception = 0;
  t->exceptionHandler = FMTK_ExceptionHandler;
	t->callback = 0;
	if (stack) {
		t->stack = (stack + 31) & 0xffffffe0UL;
		t->stack_size = stack & 31;
		t->regs[14] = t->stack + (1 << t->stack_size) - 32;
	}
	else {
		t->stack = (unsigned long)mem_alloc(hApp,8180,6);
		t->stack_size = 13;
		t->regs[14] = t->stack + (1 << t->stack_size) - 32;
	}
  im_level = SetImLevel(7);
	DisplayStringCRLF("Locked RDQ");
  TCBInsertIntoReadyQueue(ht);
  SetImLevelHelper(im_level);
	DisplayStringCRLF("Unlocked RDQ");
  return (ht);
}

// ----------------------------------------------------------------------------
// Sleep for a number of clock ticks.
// ----------------------------------------------------------------------------

long FMTK_Sleep(__reg("d0") long timeout)
{
  hTCB ht;
  int tick1, tick2;

	while (timeout > 0) {
		tick1 = GetTick();
    if (LockTimeoutList(100000)) {
      ht = GetRunningTCB();
      TCBInsertIntoTimeoutList(ht, timeout);
      UnlockTImeoutList();
			FMTK_Reschedule();
      break;
    }
		else {
			tick2 = GetTick();
			timeout -= (tick2-tick1);
		}
	}
  return (E_Ok);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

long FMTK_SetThreadPriority(__reg("d0") long ht, __reg("d1") long priority)
{
  TCB *t;

  if (priority > 31 || priority < 0)
   return (E_Arg);
  while (LockReadyQueue(-1)==0);
  t = TCBHandleToPointer(ht);
  if (t->status & (TS_RUNNING | TS_READY)) {
    TCBRemoveFromReadyQueue(ht);
    t->priority = priority;
    TCBInsertIntoReadyQueue(ht);
  }
  else
    t->priority = priority;
  UnlockReadyQueue();
  return (E_Ok);
}

void SetVector(__reg("d0") unsigned long num, __reg("d1") unsigned long addr) = 
	"\tmovem.l d0/a0,-(sp)\r\n"
	"\tlsl.l #2,d0\r\n"
	"\tmovec vbr,a0\r\n"
	"\tadd.l d0,a0\r\n"
	"\tmove.l d1,(a0)\r\n"
	"\tmovem.l (sp)+,d0/a0\r\n"
;

void SetupTCBs()
{
	int nn;

	for (nn = 0; nn < 8; nn++)
		readyQ[nn] = 0;
	DisplayStringCRLF("Setup readyQs");
	if (getCPU()==2) {
		DisplayStringCRLF("CPU 2");
		for (nn = 0; nn < NR_TCB; nn++) {
	    tcbs[nn].number = nn;
	    tcbs[nn].acbnext = 0;
			tcbs[nn].next = nn+2;
			tcbs[nn].prev = nn;
			tcbs[nn].status = 0;
			tcbs[nn].priority = 15;
			tcbs[nn].affinity = 63;
			tcbs[nn].hApp = 0;
			tcbs[nn].timeout = 0;
			tcbs[nn].hMailboxes[0] = 0;
			tcbs[nn].hMailboxes[1] = 0;
			tcbs[nn].hMailboxes[2] = 0;
			tcbs[nn].hMailboxes[3] = 0;
			if (nn<2) {
	      tcbs[nn].affinity = nn;
	      tcbs[nn].priority = 30;
	    }
	    tcbs[nn].exception = 0;
		}
		tcbs[NR_TCB-1].next = 0;
		freeTCB = 1;
	}
	TimeoutList = 0;
	
	DisplayStringCRLF("Setup thread control blocks");
}

// ----------------------------------------------------------------------------
// Initialize FMTK global variables.
// ----------------------------------------------------------------------------

long FMTK_Initialize()
{
	int nn,jj;
	int lev;
	AppStartupRec asr;
	hMBX hMbx;
	hACB hAcb;
	long d1, d2, d3;

	DisplayLEDS(0x21);

	// Nothing is running ATM
	SetRunningAppid(0);
	SetRunningTCB(0);

	// Delay 3s;
	for (nn = 3000000; nn > 0; nn--)
		DisplayLEDS(nn >> 16);
//	DBGClearScreen();
	DisplayStringCRLF("\r\nFMTK_Starting.");
  SetupDevices();
	DisplayStringCRLF("Setup devices");
	DisplayLEDS(1);
//    firstcall
  {
  	lev = SetImLevel(7);									// Do not allow interrupts
    SetVector(30,(unsigned long)FMTK_TimerIRQLaunchpad);	// Auto level 6
  	SetVector(33,(unsigned long)FMTK_Dispatch);					// TRAP #1
		DisplayStringCRLF("Set vectors");
		DisplayLEDS(2);

  	reschedFlag = 0;
  	IRQFlag = 0;
    hasUltraHighPriorityTasks = 0;
    missed_ticks = 0;

    IOFocus = 2;
    iof_switch = 0;
    hSearchApp = 0;
    hFreeApp = 0;

//		SetRunningTCBPtr(0);
    im_save = 7;
    UnlockSysSemaphore();
    UnlockIOFSemaphore();
    UnlockKbdSemaphore();
    UnlockMSGSemaphore();
    UnlockMBXSemaphore();
//    UnlockTImeoutList();
//    UnlockReadyQueue();
    UnlockTCBList();

		DisplayStringCRLF("Unlocked lists");
		DisplayLEDS(3);

    for (nn = 0; nn < NR_MBX; nn++) {
    	memset(&mailbox[nn],0,sizeof(MBX));
      mailbox[nn].link = nn+2;
    }
    mailbox[127].link = 0;
    freeMBX = 1;

		DisplayStringCRLF("Setup mailboxes");

		// Setting up message array
    for (nn = 0; nn < NR_MSG; nn++) {
      message[nn].link = nn+2;
    }
    message[NR_MSG-1].link = 0;
    freeMSG = 1;

		DisplayStringCRLF("Setup messages");

		RQB_Initialize();
 		DisplayLEDS(4);

  	for (nn = 0; nn < 8; nn++)
  		readyQ[nn] = 0;
		DisplayStringCRLF("Setup readyQs");
		SetupTCBs();
  	TimeoutList = 0;
  	
 		DisplayLEDS(4);
//    init_memory_management();
  	for (nn = 0; nn < NR_ACB; nn++)
  		ACBPtrs[nn] = NULL;
  	ACBPtrs[0] = &SysAcb;

		SetRunningAppid(1);

		FMTK_StartThread(
			(unsigned long)IdleThread,
			(((unsigned long)&IdleStack[0]) & 0xffffffe0UL) | 10,	// 256 lwords
			0,
			15,
			63
		);

		DisplayStringCRLF("Started thread");
		DumpThreads();
/*
*/
/*
		asr.pagesize = 8;
		asr.priority = 15;
		asr.affinity = 2;
		asr.codesize = 0;
		asr.datasize = 0;
		asr.uidatasize = 0;
		asr.heapsize = 0;
		asr.stacksize = 0;
		asr.pCode = StartMon;
		asr.pData = 0;
		asr.pUIData = 0;
		asr.hasGarbageCollector = 0;
		hAcb = FMTK_StartApp((unsigned long)&asr, 1);
		if (hAcb < 0) {
			DisplayLEDS(-hAcb);
			return (hAcb);
		}
		ACBPtrs[hAcb]->is_system = 1;
*/	
		DisplayLEDS(5);
/*
    	InsertIntoReadyList(0);
    	InsertIntoReadyList(1);
    	tcbs[0].status = TS_RUNNING;
    	tcbs[1].status = TS_RUNNING;
        asm {
            ldi   r1,#44
            sb    r1,$FFDC0600
        }
*/
//		SetVBA(FMTK_IRQDispatch);
//    	set_vector(4,(unsigned int)FMTK_SystemCall);
//    	set_vector(2,(unsigned int)FMTK_SchedulerIRQ);
		hKeybdMbx = 0;
		hFocusSwitchMbx = 0;
//  	FMTK_Inited = FMTK_MAGIC;
  	SetImLevelHelper(lev);								// Restore interrupts
		DisplayLEDS(6);
  }
	DisplayStringCRLF("FMTK_Started.");
	hMbx = FMTK_AllocMbx();
		
	DisplayStringCRLF("Alloced Mailbox: ");
	DisplayLEDS(hMbx);
	/*
	if (hMbx > 0) {
		for (nn = 0; nn < 10; nn++) {
			FMTK_SendMsg(hMbx, 0xfffffff1, 0xfffffff1, 0xfffffff1);
			DisplayStringCRLF("Sent");
			FMTK_WaitMsg(hMbx, (long)&d1, (long)&d2, (long)&d3, -1);
			DisplayStringCRLF("Received");
		}
		FMTK_FreeMbx(hMbx);
	}
	*/
  return (E_Ok);
}
