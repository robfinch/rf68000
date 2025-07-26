// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// TCB.c
// Task Control Block related functions.
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
#include "..\inc\config.h"
#include "..\inc\const.h"
#include "..\inc\types.h"
#include "..\inc\proto.h"
#include "..\inc\glo.h"
//#include "..\inc\TCB.h"

extern long hasUltraHighPriorityTasks;
extern void prtdbl(double);
extern DisplayString(__reg("a1") char*str);
extern DisplayWyde(__reg("d1") val);
extern DisplayTetra(__reg("d1") val);

/*
TCB* GetRunningTCBPtr()
{
	return (RunningTCBPointer);
	if (GetRunningTCB() > 0 && GetRunningTCB() <= NR_TCB)
		return (&tcbs[GetRunningTCB()-1]);
	else
		return (NULL);
}
*/
TCB* TCBHandleToPointer(hTCB handle)
{
	if (handle <= 0 || handle > NR_TCB)
		return (TCB*)0;
	return (&tcbs[handle-1]);
}

hTCB TCBPointerToHandle(TCB* ptr)
{
	hTCB h;

	if (ptr==NULL)
		return (0);	
	if (ptr < &tcbs[0])
		return (0);
	h = ptr - &tcbs[0];
	return (h+1);	
}

/*
		The following should be called with interrupts disabled.
*/
/*
void SetRunningTCBPtr(TCB* p)
{
	hTCB h;
	
	h = TCBPointerToHandle(p);	
	if (h > 0 && h <= NR_TCB) {
		RunningTCBPointer = p;
		OutputChar(' ');
		DisplayTetra((long)p);
		OutputChar(' ');
		SetRunningTCB(h);
	}	
}
*/

void ISetRunningTCBPtr(TCB* p)
{
	hTCB h;

	h = TCBPointerToHandle(p);	
	if (h > 0 && h <= NR_TCB)
		SetRunningTCB(h|0x80000000UL);
}

static hTCB iAllocTCB()
{
	TCB* p;
	hTCB h;

	if (freeTCB<=0)
		return (0);
	h = freeTCB;
	p = TCBHandleToPointer(freeTCB);
	freeTCB = p->next;
	return (h);
}

hTCB AllocTCB()
{
	hTCB h;
	int stat;

	stat = LockTCBList(0);
	h = iAllocTCB();
	UnlockTCBList(stat);
	return (h);
}

void iFreeTCB(hTCB h)
{
	TCB* p;
	
	p = TCBHandleToPointer(h);
	if (p) {
		p->next = freeTCB;
		freeTCB = h;
	}
}

int fnFreeTCB(hTCB h)
{
	int stat;

	if ((stat=LockTCBList(100000)) > 0) {
		iFreeTCB(h);	
		UnlockTCBList(stat);
		return (E_Ok);
	}
	return (E_Busy);
}

void TCBSetStatusBit(hTCB h, int bits)
{
	TCB* p;
	
	if (h <= 0 || h > NR_TCB)
		return;
	p = TCBHandleToPointer(h);
	if (p)
		p->status |= bits;
}

void TCBClearStatusBit(hTCB h, int bits)
{
	TCB* p;
	
	if (h <= 0 || h > NR_TCB)
		return;
	p = TCBHandleToPointer(h);
	if (p)
		p->status &= ~bits;
}

// ----------------------------------------------------------------------------
// These routines called only from within the timer ISR.
// Routine must be called with ready queue locked.
// ----------------------------------------------------------------------------

int TCBInsertIntoReadyQueue(hTCB ht)
{
	hTCB hq;
	TCB *p, *q;

//    __check(ht >=0 && ht < NR_TCB);
	p = TCBHandleToPointer(ht);
	if (p->priority > 31)
		return (E_BadPriority);
	if (p->priority > 28)
	   hasUltraHighPriorityTasks |= (1 << p->priority);
	p->status |= TS_READY;
	hq = readyQ[p->priority];
	// Ready list empty ?
	if (hq <= 0) {
		p->next = ht;
		p->prev = ht;
		readyQ[p->priority] = ht;
		return (E_Ok);
	}
	// Insert at tail of list
	q = TCBHandleToPointer(hq);
	// If not on a list already
	if (p == q) 
		panic("InsertIntoReadyQueue: thread at head already");
	if (p->next!=0 || p->prev!=0) 
		panic("InsertIntoReadyQueue: thread on a list already");
	p->next = hq;
	p->prev = q->prev;
	if (q->prev <= 0)
		panic("ReadyQueue corrupt");
	TCBHandleToPointer(q->prev)->next = ht;
	q->prev = ht;
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// Must be called with the ready queue locked.
// ----------------------------------------------------------------------------

int TCBRemoveFromReadyQueue(hTCB ht)
{
	TCB *t,* p, *q;
	hTCB hq;

	//    __check(ht >=0 && ht < NR_TCB);
	t = TCBHandleToPointer(ht);
	if (t == NULL)
		return (E_Ok);
	if (t->priority > 31)
		return (E_BadPriority);
	hq=readyQ[t->priority];
	p = TCBHandleToPointer(hq);
	// Thread pointing to self?
	if (t->next==ht) {
		if (ht==hq)	// Removed head and only one.
			readyQ[t->priority] = 0;
	}
	else {
		// Removing head?
		if (ht==hq) {
			if (p->next==hq)
				readyQ[t->priority] = 0;
			else
				readyQ[t->priority] = p->next;
		}
		// Double link list remove
		p = TCBHandleToPointer(t->next);
		if (p)
			p->prev = t->prev;
		q = TCBHandleToPointer(t->prev);
		if (q)
			q->next = t->next;
	}
	t->status = TS_NONE;
	t->next = 0;
	t->prev = 0;
	return (E_Ok);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int TCBInsertIntoTimeoutList(register hTCB ht, register int to)
{
	TCB *p, *q, *t;

	//    __check(ht >=0 && ht < NR_TCB);
	if (TimeoutList==ht)
		panic("InsertIntoTimeoutList: thread is already head of timeout list.");
	t = TCBHandleToPointer(ht);
	if (t == NULL)
		return (E_Ok);
	if (t->next != 0 || t->prev != 0)
		panic("InsertIntoTimeoutList: thread is still on a list.");
	if (TimeoutList <= 0) {
		t->timeout = to;
		t->status |= TS_TIMEOUT;
		TimeoutList = ht;
		return (E_Ok);
	}

	q = NULL;
	p = TCBHandleToPointer(TimeoutList);

	if (p) {
		while (to > p->timeout) {
			to -= p->timeout;
			q = p;
			if (p->next==ht)	// Already on list
				panic("InsertIntoTimeoutList: thread is already on timeout list.");
			p = TCBHandleToPointer(p->next);
			if (p == NULL)
				break;
		}
	}
	// Double link list insert before p and after q
	t->next = TCBPointerToHandle(p);
	t->prev = TCBPointerToHandle(q);
	t->status |= TS_TIMEOUT;
	if (p) {
		p->timeout -= to;
		p->prev = ht;
	}
	if (q)
		q->next = ht;
	else
		TimeoutList = ht;
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int TCBRemoveFromTimeoutList(hTCB ht)
{
  TCB *t,* nxt, *prv;
  
//    __check(ht > 0 && ht <= NR_TCB);
  t = TCBHandleToPointer(ht);
  if (t == NULL)
  	return(E_Ok);
  // Double link list remove
	nxt = TCBHandleToPointer(t->next);
	if (nxt) {
		nxt->prev = t->prev;
		nxt->timeout += t->timeout;
	}
	prv = TCBHandleToPointer(t->prev);
	if (prv)
		prv->next = t->next;
	// removing head of list?
	if (ht == TimeoutList)
		TimeoutList = t->next;
	// clear all the status bits
	t->status = TS_NONE;
  t->next = 0;
  t->prev = 0;
  return (E_Ok);
}

// ----------------------------------------------------------------------------
// Pop the top entry from the timeout list.
// ----------------------------------------------------------------------------

hTCB TCBPopTimeoutList()
{
  TCB *p;
  hTCB h;

  h = TimeoutList;
  if (TimeoutList > 0 && TimeoutList <= NR_TCB) {
  	p = TCBHandleToPointer(TimeoutList);
    TimeoutList = p->next;
    p->next = p->prev = 0;
    if (TimeoutList > 0 && TimeoutList <= NR_TCB) {
	  	p = TCBHandleToPointer(TimeoutList);
      p->prev = 0;
    }
  }
  return (h);
}


// ----------------------------------------------------------------------------
// Pop the top entry from the callback list.
// ----------------------------------------------------------------------------

unsigned long TCBPopCallbackList(TCB* t)
{
  unsigned long pcb;

	if (t->callback) {
		pcb = t->callback->func;
		t->callback = t->callback->next;
	}
  return (pcb);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void DumpThreadList()
{
   TCB *p, *q;
   int n;
   int kk;
   hTCB h, j;
 
//     printf("pi is ");
//     prtdbl(3.141592653589793238,10,6,'E');
	printf("CPU Pri Stat Task Prev Next Timeout\r\n");
	for (n = 0; n < 8; n++) {
		h = readyQ[n];
		if (h > 0 && h <= NR_TCB) {
			q = TCBHandleToPointer(h);
			p = q;
			kk = 0;
			do {
//                 if (!chkTCB(p)) {
//                     printf("Bad TCB (%X)\r\n", p);
//                     break;
//                 }
				j = (p - tcbs) + 1;
				printf("%3d %3d  %02X  %04X %04X %04X %08X %08X\r\n", p->affinity, p->priority, p->status, (int)j, p->prev, p->next, p->timeout, p->ticks);
				if (p->next <= 0 || p->next > NR_TCB)
					break;
				p = TCBHandleToPointer(p->next);
				if (CheckForCtrlC())
					goto j1;
				kk = kk + 1;
			} while (p != q && kk < 10);
		}
	}
	printf("Waiting tasks\r\n");
	h = TimeoutList;
	while (h > 0 && h <= NR_TCB) {
		p = TCBHandleToPointer(h);
		printf("%3d %3d  %02X  %04X %04X %04X %08X %08X\r\n", p->affinity, p->priority, p->status, (int)j, p->prev, p->next, p->timeout, p->ticks);
		h = p->next;
		if (CheckForCtrlC())
			goto j1;
	}
j1:  ;
}


