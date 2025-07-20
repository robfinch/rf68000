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
extern void DisplayStringCRLF(__reg("a1") char *str);
extern void DisplayWyde(__reg("d1") long val);
extern void DisplayTetra(__reg("d1") long val);
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
extern void FMTK_TimerISRLaunchpad();
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
extern ALARM Alarms[NR_ALARM];
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
extern hALARM AlarmList;
extern hMBX hKeybdMbx;
extern hMBX hFocusSwitchMbx;
extern int im_save;

pitreg_t* PITREG;

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

void SetTr(__reg("d0") long tr) =
	"\tmovec d0,tr\r\n"
;

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

ALARM* AlarmHandleToPointer(hTBLK h)
{
	return (&Alarms[h-1]);
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
// All cores will receive a reschedule interrupt.
// ----------------------------------------------------------------------------

void FMTK_RescheduleISR()
{
  TCB *t, *ot;
	unsigned long tdif;

  if (FMTK_Inited != FMTK_MAGIC)
		return;
	ot = t = GetRunningTCBPtr();
	t->endTick = GetTick();
	if (t->endTick < t->startTick)
		tdif = t->endTick + (0xffffffffUL - t->startTick);
	else
		tdif = t->endTick - t->startTick;
	t->ticks = t->ticks + tdif;
	t->status |= TS_PREEMPT;
	t->status &= ~TS_RUNNING;
	ISetRunningTCBPtr(TCBHandleToPointer(SelectThreadToRun()));
	GetRunningTCBPtr()->status |= TS_RUNNING;

	// If an exception was flagged (eg CTRL-C) return to the catch handler
	// not the interrupted code.
	t = GetRunningTCBPtr();
	if (t->exception) {
		t->regs[1] = t->exception;				// d1 = exception value
		t->regs[2] = 45;									// d2 = exception type
		t->pc = (unsigned long)t->exceptionHandler;	// Now copy exception handler address
	}
	if (ot != t) {
		t->startTick = GetTick();		// Only starting if context is switching to thread.
		SwapContext(ot,t);
		SetTr(TCBPointerToHandle(t));
	}
}

// ----------------------------------------------------------------------------
// All cores will receive a timer interrupt.
//
// If timer interrupts are enabled during a priority #0 thread, this routine
// only updates the missed ticks and remains in the same thread. No timeouts
// are updated and no thread switches will occur. The timer tick routine
// basically has a fixed latency when priority #0 is present.
// ----------------------------------------------------------------------------

void FMTK_TimerTickISR()
{
  TCB *t, *ot, *tol;
  unsigned long tdif;

	tickcnt++;
	// Set IRQ flag for interpreters
	IRQFlag = 1;
  if (FMTK_Inited != FMTK_MAGIC)
		return;
	ot = t = GetRunningTCBPtr();
	t->endTick = GetTick();
	if (t->endTick < t->startTick)
		tdif = t->endTick + (0xffffffffUL - t->startTick);
	else
		tdif = t->endTick - t->startTick;
	// Allow threads to run at least 3 ticks before switching.
	if (tdif > 3) {
		t->ticks = t->ticks + tdif;
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
				ISetRunningTCBPtr(TCBHandleToPointer(SelectThreadToRun()));
			GetRunningTCBPtr()->status |= TS_RUNNING;
		}
		else
			missed_ticks++;
	}
	// If an exception was flagged (eg CTRL-C) return to the catch handler
	// not the interrupted code.
	t = GetRunningTCBPtr();
	if (t->exception) {
		t->regs[1] = t->exception;				// d1 = exception value
		t->regs[2] = 45;									// d2 = exception type
		t->pc = (unsigned long)t->exceptionHandler;	// Now copy exception handler address
	}
	if (ot != t) {
		t->startTick = GetTick();		// Only starting if context is switching to thread.
		SwapContext(ot,t);
		SetTr(TCBPointerToHandle(t));
	}
}

// We're getting a timer block IRQ because a count has reached zero. Send a 
// message to the threads with zero counts.
/*
void FMTK_AlarmISR(__reg("d0") long underflow)
{
	ALARM* alm;
	hALARM htb;
	ACB* p;
	hACB ha,rha;
	int stat;
	unsigned long pd;
	unsigned long* PIT = (unsigned long*)0xFDFEC000;
	pitreg_t *PITREG = (unsigned long*)0xFDFEC000;

	// It should be possible to lock the alarm list right away as interrupts
	// were enabled so the alarm list could not be in the process of being
	// changed. The only case where locking the list is delayed is when another
	// core has the list locked. In that case this function returns without
	// acknowledging the interrupt, which will cause the interrupt to repeat.
	if ((stat = LockAlarmList(100)) >= 0) {
		// Acknowledge the timer interrupt (clears interrupt)
		PIT[0x200] = underflow;
		// As long as the block list is a valid handle.
		while (AlarmList > 0 && AlarmList <= NR_ALARM) {
			htb = AlarmList;
			alm = AlarmHandleToPointer(AlarmList);
			while (alm->timeout==0) {
				if (alm->hMbx > 0 && alm->hMbx <= NR_MBX)
					FMTK_PostMsg(alm->hMbx,0xffffffff,0xffffffff,0xffffffff);
				htb = AlarmList;
				AlarmList = alm->next;
				alm->next = freeAlarm;
				freeAlarm = htb;
				if (AlarmList <= 0)
					break;
				alm = AlarmHandleToPointer(AlarmList);
			}
		}
		// Program the PIT for the next countdown.
		if (AlarmList > 0) {
			PITREG[5].maxcount = alm->timeout;
			PITREG[5].ontime = 3;			// pulse is 3 clocks wide
			PITREG[5].ctrl = 0x83;		//load,enable,no auto-reload,internal clock,ignore gate,set
		}
		UnlockAlarmList(stat);
	}
}
*/

// Acknowledge the interrupt and send messsage.
//
// Parameter:
//		ndx = the number of the timer causing the interrupt

void FMTK_AlarmISR(__reg("d0") long ndx)
{
	MBX* mbx;
	hMBX h;
	unsigned long *PIT = (unsigned long*)0xFDFEC000;
	
	if (ndx > 31)
		PIT[0x205] = (1 << (ndx-32));
	else
		PIT[0x204] = (1 << ndx);
	h = PITREG[ndx].hMbx;
	if (h > 0 && h <= NR_MBX) {
		mbx = MBXHandleToPointer(h);
		if (mbx->owner==GetRunningAppid())
			FMTK_PostMsg(h,0xffffffff,0xffffffff,0xffffffff);
//		else
//			Priv_Error();
	}
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
   unsigned long *screen = (unsigned long *)0xFD000000L;

   while(1) {
     ii++;
     if (get_coreno()==2) {
       screen[47] = 0x000F0000L|ii;
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
  int stat;

  ht = threadno-1;
  stat = SetImLevel7();
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
  RestoreSr(stat);
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
//		d1 = stack (if preallocated), low five bits = LOG2 stack size
//		d2 = pointer to parameter
//		d3 = priority
//		d4 = affinity
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
	int stat;
	int stack_size;

//	DisplayStringCRLF("StartThread");
	hApp = GetRunningAppid();

  stat = LockTCBList(0);
  ht = freeTCB;
  if (ht <= 0 || ht > NR_TCB) {
    UnlockTCBList(stat);
  	return (-E_NoMoreTCBs);
  }
  t = TCBHandleToPointer(ht);
  if (t==NULL) {
	  UnlockTCBList(stat);
  	return (-E_NoMoreTCBs);
  }
  freeTCB = t->next;
  UnlockTCBList(stat);

  t->affinity = affinity;
  t->priority = priority;
  t->hApp = hApp;
  // Insert into the job's list of threads.
  stat = LockTCBList(0);
	t->acbnext = ACBPtrs[hApp-1]->thread;
	ACBPtrs[hApp-1]->thread = ht;
	UnlockTCBList(stat);

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
	t->regs[16] = 0x47c00;
  stat = SetImLevel7();
  TCBInsertIntoReadyQueue(ht);
  RestoreSr(stat);
  return (ht);
}

// ----------------------------------------------------------------------------
// Sleep for a number of clock ticks.
// ----------------------------------------------------------------------------

long FMTK_Sleep(__reg("d0") long timeout)
{
  hTCB ht;
  int tick1, tick2;
  int stat;

	stat = SetImLevel7();
  ht = GetRunningTCB();
  TCBInsertIntoTimeoutList(ht, timeout);
  RestoreSr(stat);
	FMTK_Reschedule();
  return (E_Ok);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

long FMTK_SetThreadPriority(__reg("d0") long ht, __reg("d1") long priority)
{
  TCB *t;
  int stat;

  if (priority > 31 || priority < 0)
   return (E_Arg);
  stat = SetImLevel7();
  t = TCBHandleToPointer(ht);
  if (t->status & (TS_RUNNING | TS_READY)) {
    TCBRemoveFromReadyQueue(ht);
    t->priority = priority;
    TCBInsertIntoReadyQueue(ht);
  }
  else
    t->priority = priority;
  RestoreSr(stat);
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

// The first thread is already running, but not setup. Set it up.

void SetupFirstThread()
{
	tcbs[0].number = 0;
	tcbs[0].acbnext = 0;
	tcbs[0].next = 0;
	tcbs[0].prev = 0;
	tcbs[0].status = TS_RUNNING|TS_READY;
	tcbs[0].priority = 15;
	tcbs[0].affinity = 2;
	tcbs[0].hApp = 1;
	tcbs[0].timeout = 0;
	tcbs[0].hMailboxes[0] = 0;
	tcbs[0].hMailboxes[1] = 0;
	tcbs[0].hMailboxes[2] = 0;
	tcbs[0].hMailboxes[3] = 0;
	tcbs[0].sys_stack = 0x47C00;
  tcbs[0].exception = 0;
}

void SetupTCBs()
{
	int nn;

	for (nn = 0; nn < 8; nn++)
		readyQ[nn] = 0;
	if (getCPU()==2) {
		freeTCB = 2;
		for (nn = 1; nn < NR_TCB; nn++) {
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
	      tcbs[nn].affinity = 2;
	      tcbs[nn].priority = 30;
	    }
	    tcbs[nn].exception = 0;
		}
		tcbs[NR_TCB-1].next = 0;
	}
	TimeoutList = 0;
}

// ----------------------------------------------------------------------------
// Initialize FMTK global variables.
// ----------------------------------------------------------------------------

long FMTK_Initialize()
{
	int nn,jj;
	int sr;
	AppStartupRec asr;
	hMBX hMbx;
	hACB hAcb;
	long d1, d2, d3;

	DisplayLEDS(0x21);

	// Nothing is running ATM
	SetRunningAppid(0);
	SetRunningTCB(0);

	// Delay 3s;
	for (nn = 1000000; nn > 0; nn--)
		DisplayLEDS(nn >> 15);
//	DBGClearScreen();
	DisplayStringCRLF("\r\nFMTK_Starting.");
//  SetupDevices();
//	DisplayStringCRLF("Setup devices");
	DisplayLEDS(1);
//    firstcall
  {
  	sr = SetImLevel7();										// Do not allow interrupts
    SetVector(30,(unsigned long)FMTK_TimerISRLaunchpad);	// Auto level 6
  	SetVector(33,(unsigned long)FMTK_Dispatch);					// TRAP #1
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
    // BIOS force unlocks all semaphores. This is a bit redundant.
    UnlockSysSemaphore(0x2700);
    UnlockIOFSemaphore(0x2700);
    UnlockKbdSemaphore(0x2700);
    UnlockMSGList(0x2700);
    UnlockMBX(0x2700);
//    UnlockTimeoutList();
//    UnlockReadyQueue();
    UnlockTCBList(0x2700);
    UnlockAlarmList(0x2700);

		DisplayLEDS(3);

    for (nn = 0; nn < NR_MBX; nn++) {
    	memset(&mailbox[nn],0,sizeof(MBX));
      mailbox[nn].link = nn+2;
    }
    mailbox[127].link = 0;
    freeMBX = 1;

		// Setting up message array
    for (nn = 0; nn < NR_MSG; nn++) {
      message[nn].link = nn+2;
    }
    message[NR_MSG-1].link = 0;
    freeMSG = 1;

		RQB_Initialize();
 		DisplayLEDS(4);

  	for (nn = 0; nn < 8; nn++)
  		readyQ[nn] = 0;
		SetupTCBs();
  	TimeoutList = 0;
  	
 		DisplayLEDS(4);
//    init_memory_management();
  	for (nn = 0; nn < NR_ACB; nn++)
  		ACBPtrs[nn] = NULL;
  	ACBPtrs[0] = &SysAcb;

		SetRunningAppid(1);
		SetRunningTCB(1);
  	RestoreSr(sr);								// Restore interrupts

		FMTK_StartThread(
			(unsigned long)IdleThread,
			(((unsigned long)&IdleStack[0]) & 0xffffffe0UL) | 10,	// 256 lwords
			0,
			15,
			2
		);

		FMTK_StartThread(
			(unsigned long)StartMon,
			(unsigned long)0x4780A,
			0,
			15,
			2
		);

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
  	FMTK_Inited = FMTK_MAGIC;
		DisplayLEDS(6);
  }
	DisplayStringCRLF("Femtiki Started.");
	hMbx = FMTK_AllocMbx();
		
	DisplayStringCRLF("Alloced Mailbox: ");
//	DisplayLEDS(hMbx);
	
	// Enable all interrupts
	RestoreSr(0x2000);
	if (hMbx > 0) {
		
		for (nn = 0; nn < 10; nn++) {
			FMTK_SendMsg(hMbx, 0xfffffff1, 0xfffffff2, 0xfffffff3);
			
			DisplayStringCRLF("Sent");
			FMTK_WaitMsg(hMbx, (long)&d1, (long)&d2, (long)&d3, -1);
			DisplayStringCRLF("Received");
			DisplayTetra(d1);
			OutputChar(' ');
			DisplayTetra(d2);
			OutputChar(' ');
			DisplayTetra(d3);
			OutputChar('\r');
			OutputChar('\n');
			
		}
		
//		FMTK_FreeMbx(hMbx);
	}
	
  return (E_Ok);
}
