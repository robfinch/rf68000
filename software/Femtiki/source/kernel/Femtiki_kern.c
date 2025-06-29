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
#include "..\inc\config.h"
#include "..\inc\const.h"
#include "..\inc\types.h"
#include "..\inc\proto.h"
#include "..\inc\glo.h"
//#include "TCB.h"

extern hTCB FreeTCB;

extern long __interrupt FMTK_Dispatch(
	__reg("d7") long,
	__reg("d0") long,
	__reg("d1") long,
	__reg("d2") long,
	__reg("d3") long,
	__reg("d4") long
);
extern void FMTK_TimerIRQLaunchpad(unsigned long);
extern int GetRand(register int stream);
extern int shell();
MEMORY memoryList[NR_MEMORY];

//int interrupt_table[512];
int reschedFlag;
int IRQFlag;
int irq_stack[512];
extern int FMTK_Inited;
extern ACB *ACBPtrs[NR_ACB];
extern TCB tcbs[NR_TCB];
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
extern hMSG freeMSG;
extern hMBX freeMBX;
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
	"\tendr"
;

static unsigned long GetTick() = "\tmovec.l\ttick,d0";

// Reset timer edge sense circuit
void AckTimerIRQ() =
	"\tmoveq #3,d0\r\n"
	"\tmove.l d0,PIC_ESR\r\n"
;

void DisplayIRQLive() =
	"\tmovem.l d0/a0,-(sp)\r\n"
	"\tmovec.l coreno,d0\r\n"
	"\tlsl.l #2,d0\r\n"
	"\tadd.l #$FD0000DC,d0\r\n"
	"\tmove.l d0,a0\r\n"
	"\tadd.l #1,(a0)\r\n"
	"\tmovem.l (sp)+,d0/a0"
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

hACB GetAppHandle()
{
	return (GetRunningTCBPtr()->hApp);
}

hACB GetRunningAppid()
{
	return (GetRunningTCBPtr()->hApp);
}

hACB GetRunningACB()
{
	return (GetAppHandle());
}

ACB *GetRunningACBPtr()
{
	return (GetACBPtr(GetAppHandle()));
}

ACB* ACBHandleToPointer(hACB h)
{
	return (ACBPtrs[h-1]);
}

int GetRunningPID() =
	"\tmovec.l cpid,d0\r\n"
;

int getCPU() = 
	"\tmovec coreno,d0\r\n"
;

// ----------------------------------------------------------------------------
// Get the current interrupt mask level.
// ----------------------------------------------------------------------------

int GetImLevel() =
"\tmove sr,d0\r\n"
"\tlsr.w #8,d0\r\n"
"\tand.l #7,d0\r\n"
;

// ----------------------------------------------------------------------------
// Carefully done so that the IM level is not affected until the end. There is
// no transient level.
// ----------------------------------------------------------------------------

void SetImLevelHelper(__reg("d0") int level) =
"\tmove.l d1,-(sp)\r\n"
"\tand.w #7,d0\r\n"
"\tlsl.w #8,d0\r\n"
"\tmove sr,d1\r\n"
"\tand.w #$F8FF,d1\r\n"
"\tor.w d1,d0\r\n"
"\tmove.w d0,sr\r\n"
"\tmove.l (sp)+,d1\r\n"
;

// ----------------------------------------------------------------------------
// SetImLevel will only set the interrupt mask level to level higher than the
// current one.
//
// Returns:
//		int	- the previous interrupt level setting
// ----------------------------------------------------------------------------

int SetImLevel(register int level)
{
	int x;

	if ((x = GetImLevel()) >= level)
		return (x);
	SetImLevelHelper(level);
	return(x);
}

unsigned long GetSP() = "\tmove.l sp,d0\r\n";
void SetSP(__reg("d0") unsigned long sp) = "\tmove.l d0,sp";

void SetMMUAppid(__reg("d0") hACB h) =
	"\tmove.l d0,$FDC02100\r\n"
;

// ----------------------------------------------------------------------------
// Restore the task's context.
//
// The registers were stored on the task's IRQ stack when the timer ISR was
// entered. They will automatically be restored from the IRQ stack when the
// the ISR exits. The only thing required is to account for the other info
// related to the context.
// ----------------------------------------------------------------------------

void SwapContext(register TCB *octx, register TCB *nctx)
{
	ACB* q;

	// Set the app's page directory in the MMU 
	SetMMUAppid(nctx->hApp);
	octx->ssp = GetSP();
	SetSP(nctx->ssp);
}

// ----------------------------------------------------------------------------
// Select a task to run.
// ----------------------------------------------------------------------------

static int invert;

static hTCB SelectTaskToRunHelper(int nn)
{
	int kk;
  hTCB h, h1;
	TCB *p, *q;
 
	h = readyQ[nn];
	if (h > 0 && h <= NR_TCB) {
		p = TCBHandleToPointer(h);
    kk = 0;
    // Can run the head of a lower Q level if it's not the running
    // task, otherwise look to the next task.
    if (h != GetRunningTCB())
   		q = p;
		else
   		q = TCBHandleToPointer(p->next);
    do {  
      if (!(q->status & TS_RUNNING)) {
        if (q->affinity == getCPU()) {
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

static hTCB SelectTaskToRun()
{
	int nn;
  hTCB h;
 
 	invert++;
	// Occasionally prioriies are inverted.
	if ((invert & 31)==0) {
		for (nn = 0; nn < 32; nn++) {
			if ((h = SelectTaskToRunHelper(nn)) > 0)
				return (h);
		}
		return (GetRunningTCB());
	}
	// Search the queues from the highest to lowest priority.
	for (nn = 31; nn >= 0; nn--) {
		if ((h = SelectTaskToRunHelper(nn)) > 0)
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
"\tmove.l #29,$FD260000+$18\r\n"	// PLIC
;

void FMTK_Reschedule()
{
	TriggerTimerIRQ();
}

// ----------------------------------------------------------------------------
// If timer interrupts are enabled during a priority #0 task, this routine
// only updates the missed ticks and remains in the same task. No timeouts
// are updated and no task switches will occur. The timer tick routine
// basically has a fixed latency when priority #0 is present.
// ----------------------------------------------------------------------------

void FMTK_TimerIRQ(unsigned long* sp)
{
  TCB *t, *ot, *tol;
  char* sp2;

	ot = t = GetRunningTCBPtr();
	t->endTick = GetTick();
	// Explicit rescheduling request?
	if (reschedFlag) {
		reschedFlag = 0;
		t->ticks = t->ticks + (t->endTick - t->startTick);
		t->status |= TS_PREEMPT;
		t->status &= ~TS_RUNNING;
//		t->epc = t->epc + 1;  // advance the return address
		SetRunningTCBPtr(TCBHandleToPointer(SelectTaskToRun()));
		GetRunningTCBPtr()->status |= TS_RUNNING;
	}
	// Timer tick interrupt
	else {
		// Timer will auto-reset, the following line should not be necessary.
//		AckTimerIRQ();
		// Set IRQ flag for interpreters
		IRQFlag = 1;
		DisplayIRQLive();
		// Try and lock the system semaphore, but not too hard.
		if (LockSysSemaphore(20)) {
			t->ticks = t->ticks + (t->endTick - t->startTick);
			if (t->priority != 31) {
				t->status |= TS_PREEMPT;
				t->status &= ~TS_RUNNING;
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
				if (t->priority < 28)
					SetRunningTCBPtr(TCBHandleToPointer(SelectTaskToRun()));
				GetRunningTCBPtr()->status |= TS_RUNNING;
			}
			else
				missed_ticks++;
			UnlockSysSemaphore();
		}
		// System semaphore could not be locked.
		else {
			missed_ticks++;
		}
	}
	// If an exception was flagged (eg CTRL-C) return to the catch handler
	// not the interrupted code.
	t = GetRunningTCBPtr();
	if (t->exception) {
		// Dig into the stack here to set registers
		sp[2] = t->exception;				// d1 = exception value
		sp[3] = 45;									// d2 = exception type
		// The CPU stores a word instead of an lword for the status register.
		// This shifts the placement of the return PC value by two bytes.
		sp = &sp[17];								// PC would be here except that only
		sp2 = (char *)sp;						// two bytes were stored for the SR.
		sp2 -= 2;										// So, the pointer needs to back up two
		sp = (unsigned long*)sp2;		// bytes.
		*sp2 = (unsigned long)t->exceptionHandler;	// Now copy exception handler address to stack
	}
	t->startTick = GetTick();
	if (ot != t)
		SwapContext(ot,t);
}

void panic(char *msg)
{
//     putstr(msg);
j1:  goto j1;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

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
		FMTK_ExitTask();
	}
	return (0);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

long FMTK_KillTask(__reg("d0") long taskno)
{
  hTCB ht, pht;
  hACB hApp;
  int nn;
  ACB *j;

  ht = taskno-1;
  if (LockSysSemaphore(-1)) {
    TCBRemoveFromReadyQueue(ht);
    TCBRemoveFromTimeoutList(ht);
    for (nn = 0; nn < 4; nn++)
      if (tcbs[ht].hMailboxes[nn] >= 0 && tcbs[ht].hMailboxes[nn] < NR_MBX) {
        FMTK_FreeMbx(tcbs[ht].hMailboxes[nn]);
        tcbs[ht].hMailboxes[nn] = 0;
      }
    // remove task from job's task list
    hApp = tcbs[ht].hApp;
    j = GetACBPtr(hApp);
    ht = j->task;
    if (ht==taskno)
    	j->task = tcbs[ht].acbnext;
    else {
    	while (ht > 0) {
    		pht = ht;
    		ht = tcbs[ht].acbnext - 1;
    		if (ht==taskno-1) {
    			tcbs[pht].acbnext = tcbs[ht].acbnext;
    			break;
    		}
    	}
    }
		tcbs[ht].acbnext = 0;
    // If the job no longer has any threads associated with it, it is 
    // finished.
    if (j->task == 0) {
    	j->magic = 0;
    	FreeACB(hApp);
    }
    UnlockSysSemaphore();
  }
  return (0);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

long FMTK_ExitTask()
{
  FMTK_KillTask(GetRunningTCB());
	// The thread should not return from this reschedule because it's been
	// killed.
	while(1) {
  	FMTK_Reschedule();
	}
	return (0);
}


// ----------------------------------------------------------------------------
// Returns:
//	hTCB	positive number handle of thread started,
//			or negative number error code
// ----------------------------------------------------------------------------

long FMTK_StartTask(
	__reg("d0") long StartAddr,
	__reg("d1") long stacksize,
	__reg("d2") long parm,
	__reg("d3") long info,
	__reg("d4") long affinity
)
{
  hTCB ht;
  TCB *t;
  int nn;
	hACB hApp;
	unsigned char priority;
	short int *sp2;
	unsigned long int* sp;

	// These fields extracted from a single parameter as there can be only
	// five register values passed to the function.	
	hApp = info & 0xffL;
	priority = (info >> 8) & 0xff;

  if (LockSysSemaphore(100000)) {
    ht = FreeTCB;
    if (ht <= 0 || ht > NR_TCB) {
      UnlockSysSemaphore();
    	return (E_NoMoreTCBs);
    }
    FreeTCB = tcbs[ht-1].next;
    UnlockSysSemaphore();
  }
	else {
		return (E_Busy);
	}
  t = &tcbs[ht-1];
  t->affinity = affinity;
  t->priority = priority;
  t->hApp = hApp;
  // Insert into the job's list of tasks.
  tcbs[ht-1].acbnext = hApp;
  ACBPtrs[hApp]->task = ht;
  t->regs[1] = parm;
  // Allocate stacks
  t->stack = (unsigned long*)mem_alloc(ht,stacksize,6);
  // The following stacks are in the system address space
  t->bios_stack = (unsigned long*)mem_alloc(1,1024,6);
  t->sys_stack = (unsigned long*)mem_alloc(1,1024,6);
  // Put ExitTask address on top of stack, when the task is finished then
  // this address will be returned to.
  t->stack[stacksize - 4] = (unsigned long)FMTK_ExitTask;
  t->regs[15] = (unsigned long)t->stack + stacksize - 4;	// Set USP
  // Setup system stack image to look as if a syscall were performed.
  sp = &t->sys_stack[1024 - 4 - 18*4];
  t->ssp = (unsigned long)sp;
	sp[0] = (unsigned long)t->stack + stacksize - 4;	// USP
	sp[1] = parm;				// d0 gets parameter
  for (nn = 2; nn < 16; nn = nn + 1)
  	sp[nn] = 0;
  sp2 = (short int*)&sp[16];
  *sp2 = 0x700;	// status register
  sp2++;
  sp = (unsigned long *)sp2;
  *sp = (unsigned long)StartAddr;
  sp[1] = (unsigned long)FMTK_ExitTask;

  t->startTick = GetTick();
  t->endTick = GetTick();
  t->ticks = 0;
  t->exception = 0;
  t->exceptionHandler = FMTK_ExceptionHandler;
  if (LockSysSemaphore(100000)) {
      TCBInsertIntoReadyQueue(ht);
      UnlockSysSemaphore();
  }
	else {
		return (E_Busy);
	}
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
    if (LockSysSemaphore(100000)) {
      ht = GetRunningTCB();
      TCBInsertIntoTimeoutList(ht, timeout);
      UnlockSysSemaphore();
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

long FMTK_SetTaskPriority(__reg("d0") long ht, __reg("d1") long priority)
{
  TCB *t;

  if (priority > 31 || priority < 0)
   return (E_Arg);
  if (LockSysSemaphore(-1)) {
    t = &tcbs[ht];
    if (t->status & (TS_RUNNING | TS_READY)) {
      TCBRemoveFromReadyQueue(ht);
      t->priority = priority;
      TCBInsertIntoReadyQueue(ht);
    }
    else
      t->priority = priority;
    UnlockSysSemaphore();
  }
  return (E_Ok);
}

void SetVector(__reg("d0") unsigned long num, __reg("d1") unsigned long addr) = 
	"\tmovem.l d0/a0,-(sp)\r\n"
	"\tlsl.l #2,d0\r\n"
	"\tmove.l d0,a0"
	"\tmove.l d1,(a0)\r\n"
	"\tmovem.l (sp)+,d0/a0\r\n"
;

// ----------------------------------------------------------------------------
// Initialize FMTK global variables.
// ----------------------------------------------------------------------------

long FMTK_Initialize()
{
	int nn,jj;
	int lev;

//    firstcall
  {
  	lev = SetImLevel(7);									// Do not allow interrupts
    SetVector(30,(unsigned long)FMTK_TimerIRQLaunchpad);	// Auto level 6
  	SetVector(33,(unsigned long)FMTK_Dispatch);					// TRAP #1

  	reschedFlag = 0;
  	IRQFlag = 0;
    hasUltraHighPriorityTasks = 0;
    missed_ticks = 0;

    IOFocus = 2;
    iof_switch = 0;
    hSearchApp = 0;
    hFreeApp = 0;

		SetRunningTCBPtr(0);
    im_save = 7;
    UnlockSysSemaphore();
    UnlockIOFSemaphore();
    UnlockKbdSemaphore();

		// Setting up message array
    for (nn = 0; nn < NR_MSG; nn++) {
      message[nn].link = nn+2;
    }
    message[NR_MSG-1].link = 0;
    freeMSG = 1;

  	for (nn = 0; nn < 8; nn++)
  		readyQ[nn] = 0;
  	for (nn = 0; nn < NR_TCB; nn++) {
      tcbs[nn].number = nn;
      tcbs[nn].acbnext = 0;
  		tcbs[nn].next = nn+1;
  		tcbs[nn].prev = 0;
  		tcbs[nn].status = 0;
  		tcbs[nn].priority = 15;
  		tcbs[nn].affinity = 0;
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
  	freeTCB = 2;
  	TimeoutList = 0;
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
  	FMTK_Inited = 0x12345678;
    SetupDevices();
  	SetImLevelHelper(lev);								// Restore interrupts
  }
  return (0);
}

