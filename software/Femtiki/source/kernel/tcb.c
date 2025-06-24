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
#include "..\inc\config.h"
#include "..\inc\const.h"
#include "..\inc\types.h"
#include "..\inc\proto.h"
#include "..\inc\glo.h"
//#include "..\inc\TCB.h"

extern int hasUltraHighPriorityTasks;
extern void prtdbl(double);

extern hTCB FreeTCB;
extern TCB* tcbs;

TCB* TCBHandleToPointer(short int hTCB handle)
{
	if (handle <= 0)
		return (TCB*)0;
	return (&tcbs[handle-1]);
}

hTCB TCBPointerToHandle(TCB* ptr)
{
	hTCB h;

	if (ptr==NULL)
		return (0);	
	h = ptr - &tcbs[0];
	return (h+1);	
}

static hTCB iAllocTCB()
{
	TCB* p;
	hTCB h;

	if (FreeTCB<=0)
		return (0);
	h = FreeTCB;
	p = TCBHandleToPointer(FreeTCB);
	FreeTCB = p->next;
	return (h);
}

hTCB AllocTCB(hTCB* ph)
{
	hTCB h;

	LockSysSemaphore();
	h = iAllocTCB();
	UnlockSysSemaphore();
	if (ph)
		*ph = h;
	return (E_Ok);
}

static void iFreeTCB(hTCB h)
{
	TCB* p;
	
	p = TCBHandleToPointer(h);
	if (p) {
		p->next = FreeTCB;
		FreeTCB = h;
	}
}

int fnFreeTCB(hTCB h)
{
	LockSysSemaphore();
	iFreeTCB(h);	
	UnlockSysSemaphore();
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// These routines called only from within the timer ISR.
// ----------------------------------------------------------------------------

int InsertIntoReadyList(register hTCB ht)
{
	hTCB hq;
	TCB *p, *q;

//    __check(ht >=0 && ht < NR_TCB);
	p = TCBHandleToPointer(ht);
	if (p->priority > 31 || p->priority < 0)
		return (E_BadPriority);
	if (p->priority > 28)
	   hasUltraHighPriorityTasks |= (1 << p->priority);
	TCBSetStatusBit(ht, TS_READY);
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
	p->next = hq;
	p->prev = q->prev;
	TCBHandleToPointer(q->prev)->next = ht;
	q->prev = ht;
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int RemoveFromReadyList(register hTCB ht)
{
	TCB *t,* p, *q;

	//    __check(ht >=0 && ht < NR_TCB);
	t = TCBHandleToPointer(ht);
	if (t == NULL)
		return (E_Ok);
	if (t->priority > 31 || t->priority < 0)
		return (E_BadPriority);
	if (ht==readyQ[t->priority])
		readyQ[t->priority] = t->next;
	if (ht==readyQ[t->priority])
		readyQ[t->priority] = 0;
	p = TCBHandleToPointer(t->next);
	if (p)
		p->prev = t->prev;
	q = TCBHandleToPointer(t->prev);
	if (q)
		q->next = t->next;
	t->next = -1;
	t->prev = -1;
	// clear all the status bits
	TCBClearStatusBit(t, -1);
	return (E_Ok);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int InsertIntoTimeoutList(register hTCB ht, register int to)
{
	TCB *p, *q, *t;

	//    __check(ht >=0 && ht < NR_TCB);
	t = TCBHandleToPointer(ht);
	if (t == NULL)
		return (E_Ok);
	if (TimeoutList <= 0) {
		t->timeout = to;
		TimeoutList = ht;
		t->next = -1;
		t->prev = -1;
		return (E_Ok);
	}

	q = null;
	p = TCBHandleToPointer(TimeoutList);

	if (p) {
		while (to > p->timeout) {
			to -= p->timeout;
			q = p;
			p = TCBHandleToPointer(p->next);
		}
	}
	t->next = TCBPointerToHandle(p);
	t->prev = TCBPointerToHandle(q);
	if (p) {
		p->timeout -= to;
		p->prev = ht;
	}
	if (q)
		q->next = ht;
	else
		TimeoutList = ht;
	TCBSetStatusBit(t, TS_TIMEOUT);
	return (E_Ok);
};

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int RemoveFromTimeoutList(hTCB ht)
{
  TCB *t,* nxt, *prv;
  
//    __check(ht > 0 && ht <= NR_TCB);
  t = TCBHandleToPointer(ht);
  if (t == NULL)
  	return(E_Ok);
  if (t->next) {
  	nxt = TCBHandleToPointer(t->next);
  	if (nxt) {
			nxt->prev = t->prev;
			nxt->timeout += t->timeout;
		}
  }
  if (t->prev > 0) {
  	prv = TCBHandleToPointer(t->prev);
		prv->next = t->next;
	}
	// clear all the status bits
	TCBClearStatusBit(t, -1);
  t->next = -1;
  t->prev = -1;
  return (E_Ok);
}

// ----------------------------------------------------------------------------
// Pop the top entry from the timeout list.
// ----------------------------------------------------------------------------

hTCB PopTimeoutList()
{
  TCB *p;
  hTCB h;

  h = TimeoutList;
  if (TimeoutList > 0 && TimeoutList <= NR_TCB) {
  	p = TCBHandleToPointer(TimeoutList);
    TimeoutList = p->next;
    if (TimeoutList > 0 && TimeoutList <= NR_TCB) {
	  	p = TCBHandleToPointer(TimeoutList);
      p->prev = -1;
    }
  }
  return (h);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void DumpTaskList()
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
				if (getcharNoWait()==3)
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
		if (getcharNoWait()==3)
			goto j1;
	}
j1:  ;
}


