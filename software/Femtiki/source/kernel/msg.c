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

static MBX* MBXHandleToPointer(hMBX h)
{
	MBX* mbx;
	
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

	if (LockMSGSemaphore(-1)) {
		if (freeMSG==0) {
			UnlockMSGSemaphore();
			return (NULL);
		}
		msg = MSGHandleToPointer(freeMSG);
		freeMSG = msg->link;
		--nMsgBlk;
		UnlockMSGSemaphore();
	}
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
	if (msg == NULL)
		return;
  msg->type = MT_FREE;
  msg->retadr = 0;
  msg->dstadr = 0;
  if (LockMSGSemaphore(-1)) {
		msg->link = freeMSG;
		freeMSG = (msg - message) + 1;
		nMsgBlk++;
		UnlockMSGSemaphore();
	}
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

static long QueueMsg(MBX *mbx, MSG *msg)
{
  MSG *tmpmsg;
  hMSG htmp;
	int rr = E_Ok;

	if (LockMBXSemaphore(-1)) {
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
				if (LockMSGSemaphore(-1)) {
					tmpmsg = MSGHandleToPointer(mbx->mq_head);
					while (MSGPointerToHandle(tmpmsg) != mbx->mq_tail) {
						msg = tmpmsg;
						tmpmsg = MSGHandleToPointer(tmpmsg->link);
					}
					mbx->mq_tail = MSGPointerToHandle(msg);
					UnlockMSGSemaphore();
				}
				FreeMsg(tmpmsg);
				if (mbx->mq_missed < MAX_UINT)
					mbx->mq_missed++;
				mbx->mq_count--;
				rr = E_QueFull;
			}
			if (rr == E_QueFull) {
   	    UnlockMBXSemaphore();
				return (-rr);
      }
      break;
		}
		// if there is a message in the queue
		if (LockMSGSemaphore(-1)) {
			if (mbx->mq_tail > 0)
				message[mbx->mq_tail-1].link = MSGPointerToHandle(msg);
			else
				mbx->mq_head = MSGPointerToHandle(msg);
			mbx->mq_tail = MSGPointerToHandle(msg);
			msg->link = 0;
			UnlockMSGSemaphore();
		}
    UnlockMBXSemaphore();
  }
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
 
	if (mbx->mq_count) {
		mbx->mq_count--;
		if (LockMSGSemaphore(-1)) {
			hm = mbx->mq_head;
			if (hm > 0) {	// should not be null
			    tmpmsg = MSGHandleToPointer(hm);
				mbx->mq_head = tmpmsg->link;
				if (mbx->mq_head < 0)
					mbx->mq_tail = 0;
				tmpmsg->link = hm;
			}
			UnlockMSGSemaphore();
		}
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
		if (LockTimeoutList(-1)) {
			TCBRemoveFromTimeoutList(TCBPointerToHandle(*thread));
			UnlockTImeoutList();
		}
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

	if (LockMBXSemaphore(-1)) {
		if (freeMBX <= 0 || freeMBX > NR_MBX) {
	    UnlockMBXSemaphore();
			return (-E_NoMoreMbx);
    }
    hMbx = freeMBX;
		mbx = MBXHandleToPointer(freeMBX);
		freeMBX = mbx->link;
		nMailbox--;
    UnlockMBXSemaphore();
  }
  // At system startup there may not be a running App. We want allocated
  // mailboxes to be owned by the system.
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
	
	if (hMbx <= 0 || hMbx > NR_MBX)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	if (LockMBXSemaphore(-1)) {
		if ((mbx->owner != GetRunningAppid()) && (GetRunningAppid() > 1)) {
	    UnlockMBXSemaphore();
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
			if (thread->status & TS_TIMEOUT) {
				if (LockTimeoutList(-1)) {
					TCBRemoveFromTimeoutList(TCBPointerToHandle(thread));
					UnlockTImeoutList();
				}
			}
			if (LockReadyQueue(-1)) {
				TCBInsertIntoReadyQueue(TCBPointerToHandle(thread));
				UnlockReadyQueue();
			}
		}
		mbx->link = freeMBX;
		freeMBX = mbx-mailbox;
		nMailbox++;
    UnlockMBXSemaphore();
  }
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Set the mailbox message queueing strategy.
--------------------------------------------------------------- */
long SetMbxMsgQueStrategy(hMBX hMbx, int qStrategy, int qSize)
{
	MBX *mbx;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (-E_Arg);
	if (qStrategy > 2)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	if (LockMBXSemaphore(-1)) {
		if ((mbx->owner != GetRunningAppid()) && GetRunningAppid() > 1) {
	    UnlockMBXSemaphore();
			return (-E_NotOwner);
    }
		mbx->mq_strategy = qStrategy;
		mbx->mq_size = qSize;
    UnlockMBXSemaphore();
  }
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Send a message.
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

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	while (LockMBXSemaphore(-1)==0);
	// check for a mailbox owner which indicates the mailbox
	// is active.
	if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
    UnlockMBXSemaphore();
    return (-E_NotAlloc);
  }
	if (freeMSG <= 0 || freeMSG > NR_MSG) {
    UnlockMBXSemaphore();
		return (-E_NoMoreMsgBlks);
  }
  msg = AllocMsg();
	msg->dstadr = hMbx;
	msg->type = MT_DATA;
	msg->d1 = d1;
	msg->d2 = d2;
	msg->d3 = d3;
	DequeueThreadFromMailbox(mbx, &thread);
  UnlockMBXSemaphore();
	if (thread == null)
		return (QueueMsg(mbx, msg));
	CopyMsg(&thread->msg,msg);
  FreeMsg(msg);
	if (thread->status & TS_TIMEOUT) {
		while (LockTimeoutList(-1)==0);
		TCBRemoveFromTimeoutList(TCBPointerToHandle(thread));
		UnlockTImeoutList();
	}
	while (LockReadyQueue(-1)==0);
	TCBInsertIntoReadyQueue(TCBPointerToHandle(thread));
	UnlockReadyQueue();
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

	if (hMbx == 0 || hMbx > NR_MBX)
		return (-E_Arg);
	// Switch to system address space
	mbx = MBXHandleToPointer(hMbx);
	while (LockMBXSemaphore(-1)==0);
	// check for a mailbox owner which indicates the mailbox
	// is active.
	if (mbx->owner == 0 || mbx->owner > NR_ACB) {
    UnlockMBXSemaphore();
  	return (-E_NotAlloc);
  }
	msg = DequeueMsg(mbx);
  UnlockMBXSemaphore();
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
	while (LockReadyQueue(-1)==0);
	thread = GetRunningTCBPtr();
	hThread = GetRunningTCB();
	TCBRemoveFromReadyQueue(hThread);
  UnlockReadyQueue();
	thread->status |= TS_WAITMSG;
	thread->hWaitMbx = hMbx;
	thread->mbq_next = 0;
	while (LockMBXSemaphore(-1)==0);
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
  UnlockMBXSemaphore();
	//---------------------------
	// Is a timeout specified ?
	if (timelimit) {
      //asm { ; Waitmsg here; }
  	while (LockTimeoutList(-1)==0);
    TCBInsertIntoTimeoutList(hThread, timelimit);
    UnlockTImeoutList();
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

	if (hMbx == 0 || hMbx > NR_MBX)
		return (-E_Arg);
	mbx = MBXHandleToPointer(hMbx);
 	while (LockMBXSemaphore(-1)==0);
	// check for a mailbox owner which indicates the mailbox
	// is active.
	if (mbx->owner == 0 || mbx->owner > NR_ACB) {
	  UnlockMBXSemaphore();
		return (-E_NotAlloc);
  }
	if (qrmv)
		msg = DequeueMsg(mbx);
	else
		msg = MSGHandleToPointer(mbx->mq_head);
  UnlockMBXSemaphore();
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
	if (LockMBXSemaphore(-1)) {
		// check for a mailbox owner which indicates the mailbox
		// is active.
		if (mbx->owner == 0 || mbx->owner > NR_ACB) {
			FreeRqb(hRqb);
	    UnlockMBXSemaphore();
      return (-E_NotAlloc);
    }
		if (freeMSG == 0 || freeMSG > NR_MSG) {
			FreeRqb(hRqb);
	    UnlockMBXSemaphore();
			return (-E_NoMoreMsgBlks);
    }
		msg = AllocMsg();
		msg->dstadr = hMbx;
		msg->type = MT_RQB;
		msg->d1 = hRqb;
		DequeueThreadFromMailbox(mbx, &task);
    UnlockMBXSemaphore();
  }
	if (task == null)
		return (QueueMsg(mbx, msg));
	CopyMsg(&task->msg,msg);
  FreeMsg(msg);
	if (task->status & TS_TIMEOUT) {
		if (LockTimeoutList(-1)) {
			TCBRemoveFromTimeoutList(TCBPointerToHandle(task));
			UnlockTImeoutList();
		}
	}
	if (LockReadyQueue(-1)) {
		TCBInsertIntoReadyQueue(TCBPointerToHandle(task));
    UnlockReadyQueue();
  }
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
		if (LockSysSemaphore(-1)) {
			if (rqb->pData1 && rqb->cbData1)
				FMTK_DeAliasMem(rqb->owner, (long)rqb->pData1, rqb->cbData1);
			if (rqb->pData2 && rqb->cbData2)
				FMTK_DeAliasMem(rqb->owner, (long)rqb->pData2, rqb->cbData2);
	    UnlockSysSemaphore();
		}
	}
	if (LockMBXSemaphore(-1)) {
		msg = AllocMsg();
		msg->dstadr = rqb->response_mbx;
		msg->type = MT_RESP;
		msg->d1 = hRqb;
		msg->d2 = stat;
		msg->d3 = 0;
		DequeueThreadFromMailbox(MBXHandleToPointer(rqb->response_mbx), &task);
    UnlockMBXSemaphore();
	}
	if (task == null)
		return (QueueMsg(MBXHandleToPointer(rqb->response_mbx), msg));
	CopyMsg(&task->msg,msg);
  FreeMsg(msg);
	if (task->status & TS_TIMEOUT) {
		if (LockTimeoutList(-1)) {
			TCBRemoveFromTimeoutList(TCBPointerToHandle(task));
			UnlockTImeoutList();
		}
	}
	if (LockReadyQueue(-1)) {
		TCBInsertIntoReadyQueue(TCBPointerToHandle(task));
  	UnlockReadyQueue();
  }
	return (E_Ok);
}
