#include <stdio.h>
#include <string.h>
#include "..\inc\types.h"
#include "..\inc\const.h"
#include "..\inc\config.h"
#include "..\inc\proto.h"
#include "..\inc\glo.h"

/* String work area */
static char strwka[256];
extern RQB request_block[NR_RQB];
extern service_t service[NR_SERVICE];
extern hRQB FreeRQB;
extern long nRequest;

/*
		Initialize request blocks and services.
*/

void RQB_Initialize()
{
	int nn;
	
	DisplayStringCRLF("RQB Initialize");
	DisplayLEDS(10);
	for (nn = 0; nn < NR_RQB; nn++) {
		memset(&request_block[nn],0,sizeof(RQB));
		DisplayLEDS(11);
		request_block[nn].next = nn+2;
	}	
	DisplayLEDS(12);
	DisplayStringCRLF("Setup request blocks");
	for (nn = 0; nn < NR_SERVICE; nn++) {
		memset(&service[nn],0,sizeof(service_t));
		DisplayLEDS(13);
	}
	DisplayStringCRLF("Setup service blocks");
	FreeRQB = 1;
	nRequest = NR_RQB;
	DisplayLEDS(14);
}

static hRQB AllocRqb()
{
	hRQB rqb;
	
	rqb = FreeRQB;
	if (rqb > 0) {
		FreeRQB = request_block[rqb-1].next;
		nRequest--;	
		request_block[rqb-1].magic = 0x52514220;	// 'RQB '
		request_block[rqb-1].owner = GetRunningAppid();
	}
	return (rqb);
}

static long FreeRqb(hRQB rqb)
{
	if (rqb == 0 && rqb > NR_RQB)
		return (-E_Arg);
		
	if (request_block[rqb-1].magic==0x52514220) {
		request_block[rqb-1].magic = 0;
		request_block[rqb-1].next = FreeRQB;
		FreeRQB = rqb;
		nRequest++;
		return (E_Ok);
	}
	return (-E_NotAlloc);
}

/*
		Parameters:
			d0 = long containing pointer to service name

		Returns:
			d0 = handle to service mailbox, 0 if service not found
*/
long FMTK_GetServiceMbx(__reg("d0") long name)
{
	int nn;
	char* pName;
	
	pName = (char*)name;
	for (nn = 0; nn < NR_SERVICE; nn++) {
		if (stricmp(pName,service[nn].name)) {
			return (service[nn].service_mbx);
		}
	}
	return (0);
}

/*
		Returns:
			E_Ok if service registered successfully, otherwise E_Service.
			E_Service may be returned if there are too many services or
			if a mailbox could not be allocated for the service.
*/
long FMTK_RegisterService(__reg("d0") long name)
{
	int nn;
	hMBX mbx;
	char *pName = (char*)name;
	
	for (nn = 0; nn < NR_SERVICE; nn++) {
		if (service[nn].name[0]=='\0') {
			mbx = FMTK_AllocMbx();
			if (mbx > 0) {
				strncpy(service[nn].name, pName, 61);
				service[nn].service_mbx = mbx;
				return (E_Ok);
			}
			return (-E_Service);
		}
	}
	return (-E_Service);
}

long FMTK_UnregisterService(__reg("d0") long name)
{
	int nn;
	hMBX mbx;
	char *pName = (char*)name;
	
	for (nn = 0; nn < NR_SERVICE; nn++) {
		if (strncmp(service[nn].name,pName,61)==0) {
			service[nn].name[0] = '\0';
			service[nn].service_mbx = 0;
			return (E_Ok);
		}
	}
	return (-E_Service);
}

static MSG* MSGHandleToPointer(hMSG h)
{
	MSG* msg;
	
	msg = &message[h-1];
	return (msg);
}

static hMSG MSGPointerToHandle(MSG *m)
{
	hMSG h;
	
	h = (m-message)+1;
	return (h);
}

MBX* MBXHandleToPointer(hMBX h)
{
	MBX* mbx;

	if (h <= 0 || h > NR_MBX)	
		return (NULL);
	mbx = &mailbox[h-1];
	return (mbx);
}

static RQB* RQBHandleToPointer(hRQB h)
{
	RQB* rqb;
	
	rqb = &request_block[h-1];
	return (rqb);
}

/* ---------------------------------------------------------------
	Description:
		Copy a message.
--------------------------------------------------------------- */

static void CopyMsg(MSG *dmsg, MSG *smsg)
{
	dmsg->type = smsg->type;
	dmsg->retadr = smsg->retadr;
	dmsg->dstadr = smsg->dstadr;
	dmsg->link = 0;
	dmsg->d1 = smsg->d1;
	dmsg->d2 = smsg->d2;
	dmsg->d3 = smsg->d3;
}

/* ---------------------------------------------------------------
	Description:
		Allocatte a message from the free list.
	Returns:
		msg*:	pointer to message
--------------------------------------------------------------- */

static MSG* AllocMsg()
{
	MSG* msg;
	int stat;

	stat = LockMSGSemaphore(0);
	if (freeMSG==0) {
		UnlockMSGSemaphore(stat);
		return (NULL);
	}
	msg = MSGHandleToPointer(freeMSG);
	freeMSG = msg->link;
	--nMsgBlk;
	UnlockMSGSemaphore(stat);
	msg->type = 0;
	msg->retadr = GetRunningAppid();
	msg->dstadr = 0;
	return (msg);
}

/* ---------------------------------------------------------------
	Description:
		Freeup message and add back to free list.
--------------------------------------------------------------- */

static void FreeMsg(MSG *msg)
{
	int stat;

	if (msg == NULL)
		return;
  msg->type = MT_FREE;
  msg->retadr = 0;
  msg->dstadr = 0;
  stat = LockMSGSemaphore(0);
	msg->link = freeMSG;
	freeMSG = (msg - message) + 1;
	nMsgBlk++;
	UnlockMSGSemaphore(stat);
}

/* ---------------------------------------------------------------
	Description:
		Queue a message at a mailbox.

	Assumptions:
		valid mailbox parameter.

	Called from:
		SendMsg
		PostMsg
--------------------------------------------------------------- */

static long QueueMsg(MBX *mbx, MSG *msg, int lock)
{
  MSG *tmpmsg;
  hMSG htmp;
	int rr = E_Ok;
	int stat1,stat2;

	// Lock MBX and MSG
	if (lock==-1) {
		stat1 = LockMBXSemaphore(0);
		stat2 = LockMSGSemaphore(0);
	}
	else {
		if ((stat1 = LockMBXSemaphore(lock)) >= 0) {
			if ((stat2 = LockMSGSemaphore(lock)) < 0) {
				UnlockMBXSemaphore(stat1);
				return (-E_Busy);
			}
		}
	}

	mbx->mq_count++;

	// handle potential queue overflows
  switch (mbx->mq_strategy) {
  
  	// unlimited queing (do nothing)
	case MQS_UNLIMITED:
		break;
		
	// buffer newest
	// if the queue is full then old messages are lost
	// Older messages are at the head of the queue.
	// loop incase message queing strategy was changed
  case MQS_NEWEST:
    while (mbx->mq_count > mbx->mq_size) {
      // return outdated message to message pool
      htmp = message[mbx->mq_head-1].link;
      tmpmsg = MSGHandleToPointer(htmp);
      FreeMsg(tmpmsg);
			mbx->mq_count--;
      mbx->mq_head = htmp;
			if (mbx->mq_missed < MAX_UINT)
				mbx->mq_missed++;
			rr = E_QueFull;
		}
    break;

	// buffer oldest
	// if the queue is full then new messages are lost
	// loop incase message queing strategy was changed
	case MQS_OLDEST:
		// first return the passed message to free pool
		if (mbx->mq_count > mbx->mq_size) {
			// return new message to pool
			FreeMsg(msg);
			if (mbx->mq_missed < MAX_UINT)
				mbx->mq_missed++;
			rr = E_QueFull;
			mbx->mq_count--;
		}
		// next if still over the message limit (which
		// might happen if que strategy was changed), return
		// messages to free pool
		while (mbx->mq_count > mbx->mq_size) {
			// locate the second last message on the que
			tmpmsg = MSGHandleToPointer(mbx->mq_head);
			while (MSGPointerToHandle(tmpmsg) != mbx->mq_tail) {
				msg = tmpmsg;
				tmpmsg = MSGHandleToPointer(tmpmsg->link);
			}
			mbx->mq_tail = MSGPointerToHandle(msg);
			FreeMsg(tmpmsg);
			if (mbx->mq_missed < MAX_UINT)
				mbx->mq_missed++;
			mbx->mq_count--;
			rr = E_QueFull;
		}
		if (rr == E_QueFull) 
			goto j1;
    break;
	}
	// if there is a message in the queue
	if (mbx->mq_tail > 0)
		message[mbx->mq_tail-1].link = MSGPointerToHandle(msg);
	else
		mbx->mq_head = MSGPointerToHandle(msg);
	mbx->mq_tail = MSGPointerToHandle(msg);
	msg->link = 0;
j1:
	UnlockMSGSemaphore(stat2);
  UnlockMBXSemaphore(stat1);
	return (-rr);
}


/* ----------------------------------------------------------------------------
	Description:
		Dequeues a message from a mailbox.

	Assumptions:
		Mailbox parameter is valid.
		Mailbox semaphore is locked already.

	Called from:
		FreeMbx - (locks mailbox)
		WaitMsg	-	"
		CheckMsg-	"
----------------------------------------------------------------------------- */

static MSG *DequeueMsg(MBX *mbx)
{
	MSG *tmpmsg = null;
  hMSG hm;
  int stat;
 
	if (mbx->mq_count) {
		mbx->mq_count--;
		stat = LockMSGSemaphore(0);
		hm = mbx->mq_head;
		if (hm > 0) {	// should not be null
	    tmpmsg = MSGHandleToPointer(hm);
			mbx->mq_head = tmpmsg->link;
			if (mbx->mq_head < 0)
				mbx->mq_tail = 0;
			tmpmsg->link = hm;
		}
		UnlockMSGSemaphore(stat);
	}
	return (tmpmsg);
}


/* ----------------------------------------------------------------------------
	Description:
		Dequeues a thread from a mailbox. The thread will also be removed from
	the timeout list (if it's present there), and	the timeout list will be
	adjusted accordingly.

	Assumptions:
		Mailbox parameter is valid.
		Mailbox is locked
---------------------------------------------------------------------------- */

long DequeueThreadFromMailbox(MBX *mbx, TCB **thread)
{
	int im_level;

	if (thread == NULL || mbx == NULL)
		return (E_Arg);

	if (mbx->tq_head == 0) {
		*thread = null;
		return (-E_NoTask);
	}

	mbx->tq_count--;
	*thread = TCBHandleToPointer(mbx->tq_head);
	mbx->tq_head = tcbs[mbx->tq_head-1].mbq_next;
	if (mbx->tq_head > 0)
		tcbs[mbx->tq_head-1].mbq_prev = 0;
	else
		mbx->tq_tail = 0;

	// if thread is also on the timeout list then
	// remove from timeout list
	// adjust succeeding thread timeout if present
	if ((*thread)->status & TS_TIMEOUT) {
		im_level = SetImLevel(7);
		TCBRemoveFromTimeoutList(TCBPointerToHandle(*thread));
		SetImLevelHelper(im_level);
	}

	(*thread)->mbq_prev = (*thread)->mbq_next = 0;
	(*thread)->hWaitMbx = 0;	// no longer waiting at mailbox
	(*thread)->status &= ~TS_WAITMSG;
	return (E_Ok);
}


/* ----------------------------------------------------------------------------
	Description:
		Allocate a mailbox. The default queue strategy is to queue the eight
	most recent messages.
	
	Returns:
		d0 = hMBX handle to mailbox, <0 if unsuccessful
---------------------------------------------------------------------------- */

long FMTK_AllocMbx()
{
	MBX *mbx;
	hMBX hMbx;
	int stat;

	DisplayStringCRLF("AllocMbx");
	stat = LockMBXSemaphore(0);
	DisplayStringCRLF("Locked MBXs");
	if (freeMBX <= 0 || freeMBX > NR_MBX) {
		DisplayStringCRLF("No more MBXs");
    UnlockMBXSemaphore(stat);
		return (-E_NoMoreMbx);
  }
  hMbx = freeMBX;
	mbx = MBXHandleToPointer(freeMBX);
	if (mbx) {
		freeMBX = mbx->link;
		nMailbox--;
	}	
  UnlockMBXSemaphore(stat);
 	DisplayStringCRLF("Unlocked MBXs");
 // At system startup there may not be a running App. We want allocated
  // mailboxes to be owned by the system.
  if (mbx) {
		mbx->owner = GetRunningAppid();
		if (mbx->owner==0)
			mbx->owner = 1;
		mbx->tq_head = 0;
		mbx->tq_tail = 0;
		mbx->mq_head = 0;
		mbx->mq_tail = 0;
		mbx->tq_count = 0;
		mbx->mq_count = 0;
		mbx->mq_missed = 0;
		mbx->mq_size = 8;
		mbx->mq_strategy = MQS_NEWEST;
	}
	return (hMbx);
}


/* ---------------------------------------------------------------
	Description:
		Free up a mailbox. When the mailbox is freed any queued
	messages must be freed. Any queued threads must also be
	dequeued. 
--------------------------------------------------------------- */
long FMTK_FreeMbx(__reg("d0") long hMbx) 
{
	MBX *mbx;
	MSG *msg;
	TCB *thread;
	int stat;
	
	if (hMbx <= 0 || hMbx > NR_MBX)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	stat = LockMBXSemaphore(0);
	if ((mbx->owner != GetRunningAppid()) && (GetRunningAppid() > 1)) {
    UnlockMBXSemaphore(stat);
		return (-E_NotOwner);
  }
	// Free up any queued messages
	while (msg = DequeueMsg(mbx))
		FreeMsg(msg);
	// Send an indicator to any queued threads that the mailbox
	// is now defunct Setting MsgPtr = null will cause any
	// outstanding WaitMsg() to return E_NoMsg.
	while(1) {
		DequeueThreadFromMailbox(mbx, &thread);
		if (thread == null)
			break;
		thread->msg.type = MT_NONE;
		// Interrupts are already disabled at this point.
		if (thread->status & TS_TIMEOUT)
			TCBRemoveFromTimeoutList(TCBPointerToHandle(thread));
		TCBInsertIntoReadyQueue(TCBPointerToHandle(thread));
	}
	mbx->link = freeMBX;
	freeMBX = mbx-mailbox;
	nMailbox++;
  UnlockMBXSemaphore(stat);
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Set the mailbox message queueing strategy.
--------------------------------------------------------------- */
long SetMbxMsgQueStrategy(hMBX hMbx, int qStrategy, int qSize)
{
	MBX *mbx;
	int stat;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (-E_Arg);
	if (qStrategy > 2)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	stat = LockMBXSemaphore(0);
	if ((mbx->owner != GetRunningAppid()) && GetRunningAppid() > 1) {
    UnlockMBXSemaphore(stat);
		return (-E_NotOwner);
  }
	mbx->mq_strategy = qStrategy;
	mbx->mq_size = qSize;
  UnlockMBXSemaphore(stat);
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Send a message. May switch threads.
--------------------------------------------------------------- */

long FMTK_SendMsg(
	__reg("d0") long hMbx,
	__reg("d1") long d1,
	__reg("d2") long d2,
	__reg("d3") long d3
)
{
	MBX *mbx;
	MSG *msg;
	TCB *thread;
	int im_level;
	int stat,stat2;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	stat = LockMBXSemaphore(0);
	// check for a mailbox owner which indicates the mailbox
	// is active.
	if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
    UnlockMBXSemaphore(stat);
    return (-E_NotAlloc);
  }
  stat2 = LockMSGSemaphore(0);
	if (freeMSG <= 0 || freeMSG > NR_MSG) {
    UnlockMSGSemaphore(stat2);
    UnlockMBXSemaphore(stat);
		return (-E_NoMoreMsgBlks);
  }
  msg = AllocMsg();
  UnlockMSGSemaphore(stat2);
	msg->dstadr = hMbx;
	msg->type = MT_DATA;
	msg->d1 = d1;
	msg->d2 = d2;
	msg->d3 = d3;
	DequeueThreadFromMailbox(mbx, &thread);
  UnlockMBXSemaphore(stat);
	if (thread == null)
		return (QueueMsg(mbx, msg, -1));
	CopyMsg(&thread->msg,msg);
  FreeMsg(msg);
	im_level = SetImLevel7();
	if (thread->status & TS_TIMEOUT)
		TCBRemoveFromTimeoutList(TCBPointerToHandle(thread));
	TCBInsertIntoReadyQueue(TCBPointerToHandle(thread));
  RestoreSr(im_level);
  FMTK_Reschedule();
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Send a message from within an interrupt routine. Does not
	switch threads. Does not wait very long for locks.
--------------------------------------------------------------- */

long FMTK_PostMsg(
	__reg("d0") long hMbx,
	__reg("d1") long d1,
	__reg("d2") long d2,
	__reg("d3") long d3
)
{
	MBX *mbx;
	MSG *msg;
	TCB *thread;
	int im_level;
	int stat,stat2;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	thread = null;
	msg = null;
	if ((stat = LockMBXSemaphore(50)) >= 0) {
		// check for a mailbox owner which indicates the mailbox
		// is active.
		if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
	    UnlockMBXSemaphore(stat);
	    return (-E_NotAlloc);
	  }
	  if ((stat2 = LockMSGSemaphore(50)) >= 0) {
			if (freeMSG <= 0 || freeMSG > NR_MSG) {
				UnlockMSGSemaphore(stat2);
		    UnlockMBXSemaphore(stat);
				return (-E_NoMoreMsgBlks);
		  }
		  msg = AllocMsg();
			UnlockMSGSemaphore(stat2);
			msg->dstadr = hMbx;
			msg->type = MT_DATA;
			msg->d1 = d1;
			msg->d2 = d2;
			msg->d3 = d3;
		}
		DequeueThreadFromMailbox(mbx, &thread);
	  UnlockMBXSemaphore(stat);
	}
	if (thread == null) {
		if (msg)
			return (QueueMsg(mbx, msg, 50));
		else 
			return (-E_Busy);
	}
	CopyMsg(&thread->msg,msg);
  FreeMsg(msg);
	im_level = SetImLevel7();
	if (thread->status & TS_TIMEOUT)
		TCBRemoveFromTimeoutList(TCBPointerToHandle(thread));
	TCBInsertIntoReadyQueue(TCBPointerToHandle(thread));
  RestoreSr(im_level);
	return (E_Ok);
}


/* ----------------------------------------------------------------------------
	Description:
		Wait for message. If timelimit is zero then the thread will wait
	indefinately for a message.
		The app's address space will be the active one. The message block is
	available in the app's address space, as the kernel address space is mapped
	into it.
	
	Parameters:
		d0 = handle of mailbox to wait at
		d1 = pointer into app's address space to store d1
		d2 = pointer into app's address space to store d2
		d3 = pointer into app's address space to store d3
		d4 = time limit to wait for message
----------------------------------------------------------------------------- */

long FMTK_WaitMsg(
	__reg("d0") long hMbx,
	__reg("d1") long d1,			// Pointer to where to store d1
	__reg("d2") long d2,			// pointer to where to store d2
	__reg("d3") long d3,			// pointer to where to store d3
	__reg("d4") long timelimit
)
{
	MBX *mbx;
	MSG *msg;
	TCB *thread;
	hTCB hThread;
	TCB *rt;
	int im_level;
	int stat;

	if (hMbx == 0 || hMbx > NR_MBX)
		return (-E_Arg);
	// Switch to system address space
	mbx = MBXHandleToPointer(hMbx);
	stat = LockMBXSemaphore(0);
	// check for a mailbox owner which indicates the mailbox
	// is active.
	if (mbx->owner == 0 || mbx->owner > NR_ACB) {
    UnlockMBXSemaphore(stat);
  	return (-E_NotAlloc);
  }
	msg = DequeueMsg(mbx);
  UnlockMBXSemaphore(stat);
  // Return message right away if there is one available.
  if (msg) {
		if (d1)
			*(long*)d1 = msg->d1;
		if (d2)
			*(long*)d2 = msg->d2;
		if (d3)
			*(long*)d3 = msg->d3;
		// MoveLongToAppAddressSpace() will set the address space to
 		FreeMsg(msg);
		return (E_Ok);
	}
	//-------------------------
	// Queue thread at mailbox
	//-------------------------
 	im_level = SetImLevel7();
	thread = GetRunningTCBPtr();
	hThread = GetRunningTCB();
	TCBRemoveFromReadyQueue(hThread);
  RestoreSr(im_level);
	thread->status |= TS_WAITMSG;
	thread->hWaitMbx = hMbx;
	thread->mbq_next = 0;
	stat = LockMBXSemaphore(0);
	if (mbx->tq_head < 0) {
		thread->mbq_prev = 0;
		mbx->tq_head = hThread;
		mbx->tq_tail = hThread;
		mbx->tq_count = 1;
	}
	else {
		thread->mbq_prev = mbx->tq_tail;
		tcbs[mbx->tq_tail-1].mbq_next = hThread;
		mbx->tq_tail = hThread;
		mbx->tq_count++;
	}
  UnlockMBXSemaphore(stat);
	//---------------------------
	// Is a timeout specified ?
	if (timelimit) {
      //asm { ; Waitmsg here; }
  	im_level = SetImLevel7();
    TCBInsertIntoTimeoutList(hThread, timelimit);
    RestoreSr(im_level);
  }
  // Reschedule will cause control to pass to another thread.
  FMTK_Reschedule();
	// Control will return here as a result of a SendMsg or a
	// timeout expiring
	rt = GetRunningTCBPtr(); 
	if (rt->msg.type == MT_NONE)
		return (E_NoMsg);
	// rip up the envelope
	rt->msg.type = MT_NONE;
	rt->msg.dstadr = 0;
	rt->msg.retadr = 0;
	if (d1)
		*(long*)d1 = rt->msg.d1;
	if (d2)
		*(long*)d2 = rt->msg.d2;
	if (d3)
		*(long*)d3 = rt->msg.d3;
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// PeekMsg()
//     Look for a message in the queue but don't remove it from the queue.
//     This is a convenince wrapper for CheckMsg().
// ----------------------------------------------------------------------------

long FMTK_PeekMsg (
	__reg("d0") long hMbx,
	__reg("d1") long d1,
	__reg("d2") long d2,
	__reg("d3") long d3
)
{
  return (FMTK_CheckMsg(hMbx, d1, d2, d3, 0));
}

/* ----------------------------------------------------------------------------
	Description:
		Check for message at mailbox. If no message is available return
	immediately to the caller (CheckMsg() is non blocking). Optionally removes
	the message from the mailbox.
---------------------------------------------------------------------------- */

long FMTK_CheckMsg (
	__reg("d0") long hMbx,
	__reg("d1") long d1,		// where to put d1
	__reg("d2") long d2,		// where to put d2
	__reg("d3") long d3,		// where to put d3
	__reg("d4") long qrmv
)
{
	MBX *mbx;
	MSG *msg;
	int stat;

	if (hMbx == 0 || hMbx > NR_MBX)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
 	stat = LockMBXSemaphore(0);
	// check for a mailbox owner which indicates the mailbox
	// is active.
	if (mbx->owner == 0 || mbx->owner > NR_ACB) {
	  UnlockMBXSemaphore(stat);
		return (-E_NotAlloc);
  }
	if (qrmv)
		msg = DequeueMsg(mbx);
	else
		msg = MSGHandleToPointer(mbx->mq_head);
  UnlockMBXSemaphore(stat);
	if (msg == null)
		return (-E_NoMsg);
	if (d1)
		*(long*)d1 = msg->d1;
	if (d2)
		*(long*)d2 = msg->d2;
	if (d3)
		*(long*)d3 = msg->d3;
	if (qrmv) {
 		FreeMsg(msg);
	}
	return (E_Ok);
}

/* ----------------------------------------------------------------------------
		Operates similar to SendMsg().
---------------------------------------------------------------------------- */

long FMTK_Request(
	__reg("d0") long hService,
	__reg("d1") long pRequest
)
{
	RQB* req;
	hMBX hs, hr, hMbx;
	MBX* mbx;
	MSG* msg;
	hMSG hm;
	TCB* task;
	hRQB hRqb;
	int stat;

	if (pRequest==0)
		return (-E_Arg);
	if (((RQB*)pRequest)->response_mbx==0 || ((RQB*)pRequest)->response_mbx > NR_MBX)
		return (-E_Arg);
	if (hService == 0 || hService > NR_MBX)
		return (-E_Arg);
	hMbx = service[hService-1].service_mbx;
	hRqb = AllocRqb();
	if (hRqb == 0)
		return (-E_NoMoreRbqs);
	req = RQBHandleToPointer(hRqb);
	memcpy(req,(RQB*)pRequest,sizeof(RQB));

//	hs = GetServiceMbx(req->svcname);
	mbx = MBXHandleToPointer(hMbx);
	stat = LockMBXSemaphore(0);
	// check for a mailbox owner which indicates the mailbox
	// is active.
	if (mbx->owner == 0 || mbx->owner > NR_ACB) {
		FreeRqb(hRqb);
    UnlockMBXSemaphore(stat);
    return (-E_NotAlloc);
  }
	if (freeMSG == 0 || freeMSG > NR_MSG) {
		FreeRqb(hRqb);
    UnlockMBXSemaphore(stat);
		return (-E_NoMoreMsgBlks);
  }
	msg = AllocMsg();
	msg->dstadr = hMbx;
	msg->type = MT_RQB;
	msg->d1 = hRqb;
	DequeueThreadFromMailbox(mbx, &task);
  UnlockMBXSemaphore(stat);
	if (task == null)
		return (QueueMsg(mbx, msg, -1));
	CopyMsg(&task->msg,msg);
  FreeMsg(msg);
  stat = SetImLevel7();
	if (task->status & TS_TIMEOUT)
		TCBRemoveFromTimeoutList(TCBPointerToHandle(task));
	TCBInsertIntoReadyQueue(TCBPointerToHandle(task));
	RestoreSr(stat);
	return (E_Ok);
}

/* ----------------------------------------------------------------------------
---------------------------------------------------------------------------- */

long FMTK_Respond(__reg("d0") long hRqb, __reg("d1") long stat)
{
	RQB* rqb;
	MBX* rmbx;	
	hMSG hMsg;
	MSG *msg;
	TCB* task;
	int st;
	
	if (hRqb==0 || hRqb > NR_RQB)
		return (-E_Arg);
	rqb = RQBHandleToPointer(hRqb);
	if (rqb->response_mbx==0 || rqb->response_mbx > NR_MBX)
		return (-E_BadMbx);
	rmbx = MBXHandleToPointer(rqb->response_mbx);
	if (rmbx->owner==0)
		return (-E_BadMbx);
	if (stat==E_OwnerAbort) {
		FreeRqb(hRqb);
		return (E_Ok);
	}
	if (rqb->owner != GetRunningAppid()) {
		if ((st = LockSysSemaphore(-1)) >= 0) {
			if (rqb->pData1 && rqb->cbData1)
				FMTK_DeAliasMem(rqb->owner, (long)rqb->pData1, rqb->cbData1);
			if (rqb->pData2 && rqb->cbData2)
				FMTK_DeAliasMem(rqb->owner, (long)rqb->pData2, rqb->cbData2);
	    UnlockSysSemaphore(st);
		}
	}
	st = LockMBXSemaphore(0);
	msg = AllocMsg();
	msg->dstadr = rqb->response_mbx;
	msg->type = MT_RESP;
	msg->d1 = hRqb;
	msg->d2 = stat;
	msg->d3 = 0;
	DequeueThreadFromMailbox(MBXHandleToPointer(rqb->response_mbx), &task);
  UnlockMBXSemaphore(st);
	if (task == null)
		return (QueueMsg(MBXHandleToPointer(rqb->response_mbx), msg, -1));
	CopyMsg(&task->msg,msg);
  FreeMsg(msg);
  st = SetImLevel7();
	if (task->status & TS_TIMEOUT)
		TCBRemoveFromTimeoutList(TCBPointerToHandle(task));
	TCBInsertIntoReadyQueue(TCBPointerToHandle(task));
	RestoreSr(st);
	return (E_Ok);
}

/*
		All alarm to list of alarms. The list is sorted by the soonest alarm.
		Called during Alarm ISR to repeat a recurring alarm.
*/
/*
long ISRAddAlarm(hALARM ha)
{
	hALARM ha, hl;
	ALARM* p, *pl, *ppl;
	int stat;
	unsigned long* PIT = (unsigned long*)0xFDFEC000;
	unsigned long timeout;

	p = AlarmHandleToPointer(h);
	p->hMbx = hMbx;
	timeout = p->BaseTimeout;
	p->timeout = timeout;
	pl = NULL;
	ppl = NULL;
	for (hl = p->next; hl > 0; hl = pl->next) {
		pl = AlarmHandleToPointer(hl);
		// Add somewhere in the middle.
		if (p->timeout < pl->timeout) {
			pl->timeout -= p->timeout;
			if (ppl)
				ppl->next = ha;
			else
				AlarmList = ha; 
			p->next = hl;
			goto j1;
		}
		else {
			ppl = pl;
			p->timeout -= pl->timeout;
		}
	}
	// Add at end of list
	if (AlarmList) {
		if (pl)
			pl->next = ha;
	}
	else
		AlarmList = ha;
	p->next = 0;
j1:
	return (ha);
}
*/

long FMTK_AddAlarm(__reg("d0") long hMbx, __reg("d1") long callback, __reg("d2") long timeout)
{
	hALARM ha, hl;
	ALARM* p, *pl, *ppl;
	int stat;
	unsigned long* PIT = (unsigned long*)0xFDFEC000;

	stat = LockAlarmList(0);
	ha = freeAlarm;
	if (ha <= 0) {
		UnlockAlarmList(stat);
		return (-E_NoMoreAlarms);
	}
	p = AlarmHandleToPointer(ha);
	freeAlarm = p->next;

	p->hMbx = hMbx;
	p->BaseTimeout = timeout;
	p->timeout = timeout;
//	p->func = (void (*)())callback;
	ppl = null;
	for (hl = AlarmList; hl > 0; hl = pl->next) {
		pl = AlarmHandleToPointer(hl);
		// Check timeout at head of list. This timeout will be located in the 
		// current count register of the timer itself.
		if (hl==AlarmList) {
			// 30 is a guess at the number of CPU clocks required to update the
			// timeout in the PIT.
			if (p->timeout < (volatile)PIT[5*4+0] + 30) {
				pl->timeout = (volatile)PIT[5*4+0] - p->timeout;	// current count remaining
				// Re-program PIT with new sooner timeout.
				PIT[5*4+1] = p->timeout;
				PIT[5*4+2] = 5;			// pulse is 5 clocks wide
				PIT[5*4+3] = 0x83;	//load,enable,no auto-reload,internal clock,ignore gate,set
				p->next = AlarmList;
				AlarmList = ha;
				goto j1;
			}	
			ppl = pl;
			p->timeout -= (volatile)PIT[5*40+0];
		}
		// Add somewhere in the middle.
		else if (p->timeout < pl->timeout) {
			pl->timeout -= p->timeout;
			ppl->next = ha;
			p->next = hl;
			goto j1;
		}
		else {
			ppl = pl;
			p->timeout -= pl->timeout;
		}
	}
	// Add at end of list
	if (AlarmList)
		pl->next = ha;
	else
		AlarmList = ha;
	p->next = 0;
j1:
	UnlockAlarmList(stat);
	return (ha);
}
