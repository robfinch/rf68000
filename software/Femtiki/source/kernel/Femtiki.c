// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
#include "config.h"
#include "const.h"
#include "types.h"
#include "proto.h"
#include "glo.h"
#include "TCB.h"

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
extern hTCB readyQ[64];
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
extern ACB *IOFocusNdx;
extern int IOFocusTbl[4];
extern int iof_switch;
extern char hasUltraHighPriorityTasks;
extern int missed_ticks;
extern byte hSearchApp;
extern byte hFreeApp;

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
	"\tadd.l#1 (a0)\r\n"
	"\tmovem.l (sp)+,d0/a0"
;

ACB *SafeGetACBPtr(register int n)
{
	if (n < 0 || n >= NR_ACB)
		return (null);
  return (ACBPtrs[n]);
}

ACB *GetACBPtr(register int n)
{
  return (ACBPtrs[n]);
}

hACB GetAppHandle()
{
	return (GetRunningTCBPtr()->hApp);
}

ACB *GetRunningACBPtr()
{
	return (GetACBPtr(GetAppHandle()));
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

// ----------------------------------------------------------------------------
// Semaphore lock/unlock code.
// Ultimately calls a BIOS routine to access the semaphoric memory which is
// set in an atomic fashion.
// ----------------------------------------------------------------------------

int LockSysSemaphore(int retries)
{
	return(LockSemaphore(OSSEMA,retries));
}

void UnlockSysSemaphore()
{
	UnlockSemaphore(OSSEMA);
}

int LockIOFSemaphore(register int retries)
{
	return(LockSemaphore(IOFSEMA,retries));
}

void UnlockIOFSemaphore()
{
	UnlockSemaphore(IOFSEMA);
}

int LockKbdSemaphore(register int retries)
{
	return(LockSemaphore(KEYBD_SEMA,retries));
}

void UnlockKbdSemaphore()
{
	UnlockSemaphore(KEYBD_SEMA);
}

unsigned long GetSP() = "\tmove.l sp,d0\r\n";
void SetSP(__reg("d0") unsigned long sp) = "\tmove.l d0,sp";

// ----------------------------------------------------------------------------
// Restore the thread's context.
//
// The registers were stored on the task's IRQ stack when the timer ISR was
// entered. They will automatically be restored from the IRQ stack when the
// the ISR exits. 
// ----------------------------------------------------------------------------

void SwapContext(register TCB *octx, register TCB *nctx)
{
	ACB* q;

	// Set the app's page directory in the MMU 
	q = GetACBPtr(nctx->hApp);
	SetMMUAppPD(q->pd);
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
// All rescheduling of tasks (task switching) is handled by the TimerIRQ() or
// RescheduleIRQ() functions. Calling a system function does not directly 
// change tasks so there's no reason to save/restore many of the control
// registers that need to be saved and restored by a task switch.
//
// Parameters to the system function are passed in registers d0 to d4.
// ----------------------------------------------------------------------------

long __interrupt FMTK_SystemCall(
__reg("d7") long callno,
__reg("d0") long arg1,
__reg("d1") long arg2,
__reg("d2") long arg3,
__reg("d3") long arg4,
__reg("d4") long arg5,
)
{
	if (LockSysSemaphore(100000)) {
		switch(callno) {
		case OS_INIT:				return (FMTK_Initialize());
		case OS_START_TASK:	return (FMTK_StartTask(arg1, arg2, arg3, arg4,arg5));
		case OS_EXIT_TASK:	return (FMTK_ExitTask());
		case OS_KILL_TASK:	return (FMTK_KillTask(arg1));
		case OS_SET_TASK_PRIORITY:	return (FMTK_SetTaskPriority(arg1, arg2));
		case OS_SLEEP:			return (FMTK_Sleep(arg1));
		case OS_WAITMSG:		return (FMTK_WaitMsg(arg1,arg2,arg3,arg4,arg5));
		case OS_SENDMSG:		return (FMTK_SendMsg(arg1,arg2,arg3,arg4));
		case OS_PEEKMSG:		return (FMTK_PeekMsg(arg1,arg2,arg3,arg4));
		case OS_CHECKKMSG:	return (FMTK_CheckMsg(arg1,arg2,arg3,arg4,arg5));
		case OS_ALLOC_MBX:	return (FMTK_AllocMbx(arg1));
		case OS_FREE_MBX:		return (FMTK_FreeMbx(arg1));
		default:
			return (E_BadCallno);
		}
	}
	else return (E_Busy);
}


// ----------------------------------------------------------------------------
// FMTK primitives need to re-schedule threads in a couple of places.
// ----------------------------------------------------------------------------

void TriggerTimerIRQ() =
"\tmove.l #1,_reschedFlag\r\n"
"\tmove.l #29,PLIC+$18\r\n"
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

void __interrupt FMTK_SchedulerIRQ()
{
  TCB *t, *ot, *tol;

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
						InsertIntoReadyList(PopTimeoutList());
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
		t->regs[29] = t->regs[28];   // set link register to catch handler
		t->epc = t->regs[28];        // and the PC register
		t->regs[TCB_D1] = t->exception;    // d1 = exception value
		t->exception = 0;
		t->regs[TCB_D2] = 45;        // d2 = exception type
	}
	t->startTick = GetTick();
	if (ot != t)
		SwapContext(ot,t);
}

void panic(char *msg)
{
     putstr(msg);
j1:  goto j1;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void IdleThread()
{
   int ii;
   int *screen = (int *)0xFFFFFFFFFFD00000L;

//     try {
j1:  ;
   forever {
     try {
       ii++;
       if (getCPU()==0) {
         screen[57] = 0xFFFF000F0000L|ii;
			 }
     }
     catch(static __exception ex=0) {
       if (ex&0xFFFFFFFFFFFFFFFFL==515) {
         printf("IdleTask: CTRL-C pressed.\r\n");
       }
       else
         throw ex;
     }
   }
/*
     }
     catch (static __exception ex1=0) {
         printf("IdleTask: exception %d.\r\n", ex1);
         goto j1;
     }
*/
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int FMTK_KillTask(register int threadno)
{
  hTCB ht, pht;
  hACB hApp;
  int nn;
  ACB *j;

  ht = threadno;
  if (LockSysSemaphore(-1)) {
    RemoveFromReadyList(ht);
    RemoveFromTimeoutList(ht);
    for (nn = 0; nn < 4; nn++)
      if (tcbs[ht].hMailboxes[nn] >= 0 && tcbs[ht].hMailboxes[nn] < NR_MBX) {
        FMTK_FreeMbx(tcbs[ht].hMailboxes[nn]);
        tcbs[ht].hMailboxes[nn] = 0;
      }
    // remove task from job's task list
    hApp = tcbs[ht].hApp;
    j = GetACBPtr(hApp);
    ht = j->thrd;
    if (ht==threadno)
    	j->thrd = tcbs[ht].acbnext;
    else {
    	while (ht > 0) {
    		pht = ht;
    		ht = tcbs[ht].acbnext;
    		if (ht==threadno) {
    			tcbs[pht].acbnext = tcbs[ht].acbnext;
    			break;
    		}
    	}
    }
		tcbs[ht].acbnext = 0;
    // If the job no longer has any threads associated with it, it is 
    // finished.
    if (j->thrd == 0) {
    	j->magic = 0;
    	mmu_FreeMap(hApp);
    }
    UnlockSysSemaphore();
  }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int FMTK_ExitTask()
{
  KillTask(GetRunningTCB());
	// The thread should not return from this reschedule because it's been
	// killed.
	while(1) {
  	FMTK_Reschedule();
	}
}


// ----------------------------------------------------------------------------
// Returns:
//	hTCB	positive number handle of thread started,
//			or negative number error code
// ----------------------------------------------------------------------------

int FMTK_StartTask(
	__reg("d0") unsigned short int* StartAddr,
	__reg("d1") long stacksize,
	__reg("d2") unsigned long* pStack,
	__reg("d3") long parm,
	__reg("d4") long info
)
{
  hTCB ht;
  TCB *t;
  int nn;
  unsigned long affinity;
	hACB hApp;
	unsigned char priority;

	// These fields extracted from a single parameter as there can be only
	// five register values passed to the function.	
  affinity = info & 0xffffffffL;
	hApp = (info >> 32) & 0xffffL;
	priority = (info >> 48) & 0xff;

  if (LockSysSemaphore(100000)) {
    ht = freeTCB;
    if (ht < 0 || ht >= NR_TCB) {
      UnlockSysSemaphore();
    	return (E_NoMoreTCBs);
    }
    freeTCB = tcbs[ht].next;
    UnlockSysSemaphore();
  }
	else {
		return (E_Busy);
	}
  t = &tcbs[ht];
  t->affinity = affinity;
  t->priority = priority;
  t->hApp = hApp;
  // Insert into the job's list of tasks.
  tcbs[ht].acbnext = ACBPtrs[hApp]->thrd;
  ACBPtrs[hApp]->thrd = ht;
  t->regs[1] = parm;
  t->regs[28] = FMTK_ExitThread;
  t->regs[TCB_USP] = (unsigned long)pStack + stacksize - 2048;
  t->bios_stack = (unsigned long)pStack + stacksize - 8;
  t->sys_stack = (unsigned long)pStack + stacksize - 1024;
  t->regs[TCB_SSP] = (unsigned long)pStack + stacksize - 1024;
  t->epc = StartAddr;
  t->cr0 = 0x140000000L;				// enable data cache and branch predictor
  t->startTick = GetTick();
  t->endTick = GetTick();
  t->ticks = 0;
  t->exception = 0;
  if (LockSysSemaphore(100000)) {
      InsertIntoReadyList(ht);
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

int FMTK_Sleep(__reg("d0") unsigned long timeout)
{
  hTCB ht;
  int tick1, tick2;

	while (timeout > 0) {
		tick1 = GetTick();
    if (LockSysSemaphore(100000)) {
      ht = GetRunningTCB();
      RemoveFromReadyList(ht);
      InsertIntoTimeoutList(ht, timeout);
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

int FMTK_SetTaskPriority(__reg("d0") hTCB ht, __reg("d1") int priority)
{
  TCB *t;

  if (priority > 31 || priority < 0)
   return (E_Arg);
  if (LockSysSemaphore(-1)) {
    t = &tcbs[ht];
    if (t->status & (TS_RUNNING | TS_READY)) {
      RemoveFromReadyList(ht);
      t->priority = priority;
      InsertIntoReadyList(ht);
    }
    else
      t->priority = priority;
    UnlockSysSemaphore();
  }
  return (E_Ok);
}

// ----------------------------------------------------------------------------
// Initialize FMTK global variables.
// ----------------------------------------------------------------------------

void FMTK_Initialize()
{
	int nn,jj;

//    firstcall
  {
  	reschedFlag = 0;
  	IRQFlag = 0;
    hasUltraHighPriorityTasks = 0;
    missed_ticks = 0;

    IOFocusTbl[0] = 0;
    IOFocusNdx = null;
    iof_switch = 0;
    hSearchApp = 0;
    hFreeApp = -1;

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
  }
}

