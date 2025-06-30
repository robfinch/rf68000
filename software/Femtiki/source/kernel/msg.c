#include <stdio.h>
#include "..\inc\types.h"
#include "..\inc\const.h"
#include "..\inc\config.h"
#include "..\inc\proto.h"
#include "..\inc\glo.h"

/* String work area */
static char strwka[256];

/*
		Initialize request blocks and services.
*/

void RQB_Initialize()
{
	int nn;
	
	for (nn = 0; nn < NR_RQB; nn++) {
		memset(&request_block[nn],0,sizeof(request_t));
		request_block[nn].next = nn+2;
	}	
	for (nn = 0; nn < NR_SERVICE; nn++)
		memset(service[nn],0,sizeof(service_t));
	FreeRQB = 1;
	nRequest = NR_RQB;
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

static long FreeRqb(hRQB rqb) {
	if (rqb > 0) {
		if (request_block[rqb-1].magic==0x52514220) {
			request_blocks[rqb-1].next = FreeRQB;
			FreeRQB = rqb;
			nRequest++;
			return (E_Ok);
		}
	}
	return (E_Arg);
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
			return (E_Service);
		}
	}
	return (E_Service);
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
	return (E_Service);
}

static MSG* MSGHandleToPointer(hMSG h)
{
	MSG* msg;
	
	msg = &message[h-1];
	return (msg);
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
--------------------------------------------------------------- */

static MSG* AllocMsg()
{
	if (freeMSG==0)
		return (NULL);
	msg = &message[freeMSG-1];
	freeMSG = msg->link;
	--nMsgBlk;
	msg->retadr = GetRunningAppid();
	return (msg);
}

/* ---------------------------------------------------------------
	Description:
		Freeup message and add back to free list.
--------------------------------------------------------------- */

static void FreeMsg(MSG *msg)
{
  msg->type = MT_FREE;
  msg->retadr = 0;
  msg->dstadr = 0;
	msg->link = freeMSG;
	freeMSG = (msg - message) + 1;
	nMsgBlk++;
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

	if (LockSysSemaphore(-1)) {
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
        tmpmsg = &message[htmp-1];
        message[mbx->mq_head-1].link = freeMSG;
        freeMSG = mbx->mq_head;
				nMsgBlk++;
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
				msg->link = freeMSG;
				freeMSG = (msg-message)+1;
				nMsgBlk++;
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
				tmpmsg = &message[mbx->mq_head-1];
				while ((tmpmsg-message)+1 != mbx->mq_tail) {
					msg = tmpmsg;
					tmpmsg = &message[tmpmsg->link-1];
				}
				mbx->mq_tail = (msg-message)+1;
				tmpmsg->link = freeMSG;
				freeMSG = (tmpmsg-message)+1;
				nMsgBlk++;
				if (mbx->mq_missed < MAX_UINT)
					mbx->mq_missed++;
				mbx->mq_count--;
				rr = E_QueFull;
			}
			if (rr == E_QueFull) {
   	    UnlockSysSemaphore();
				return (rr);
      }
      break;
		}
		// if there is a message in the queue
		if (mbx->mq_tail > 0)
			message[mbx->mq_tail-1].link = (msg-message)+1;
		else
			mbx->mq_head = (msg-message)+1;
		mbx->mq_tail = (msg-message)+1;
		msg->link = 0;
    UnlockSysSemaphore();
  }
	return (rr);
}


/* ----------------------------------------------------------------------------
	Description:
		Dequeues a message from a mailbox.

	Assumptions:
		Mailbox parameter is valid.
		System semaphore is locked already.

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
		hm = mbx->mq_head;
		if (hm > 0) {	// should not be null
		    tmpmsg = &message[hm-1];
			mbx->mq_head = tmpmsg->link;
			if (mbx->mq_head < 0)
				mbx->mq_tail = 0;
			tmpmsg->link = hm;
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
---------------------------------------------------------------------------- */

long DequeTaskFromMbx(MBX *mbx, TCB **task)
{
	if (task == NULL || mbx == NULL)
		return (E_Arg);

	if (LockSysSemaphore(-1)) {
		if (mbx->tq_head == 0) {
  		UnlockSysSemaphore();
			*task = null;
			return (E_NoTask);
		}
	
		mbx->tq_count--;
		*task = &tcbs[mbx->tq_head-1];
		mbx->tq_head = tcbs[mbx->tq_head-1].mbq_next;
		if (mbx->tq_head > 0)
			tcbs[mbx->tq_head-1].mbq_prev = 0;
		else
			mbx->tq_tail = 0;
		UnlockSysSemaphore();
	}

	// if task is also on the timeout list then
	// remove from timeout list
	// adjust succeeding task timeout if present
	if ((*task)->status & TS_TIMEOUT)
		TCBRemoveFromTimeoutList(TCBPointerToHandle(*task));

	(*task)->mbq_prev = (*task)->mbq_next = 0;
	(*task)->hWaitMbx = 0;	// no longer waiting at mailbox
	(*task)->status &= ~TS_WAITMSG;
	return (E_Ok);
}


/* ----------------------------------------------------------------------------
	Description:
		Allocate a mailbox. The default queue strategy is to queue the eight
	most recent messages.
	
	Returns:
		d0 = hMBX handle to mailbox, 0 if unsuccessful
---------------------------------------------------------------------------- */

long FMTK_AllocMbx()
{
	MBX *mbx;
	hMBX hMbx;

	if (LockSysSemaphore(-1)) {
		if (freeMBX <= 0 || freeMBX > NR_MBX) {
	    UnlockSysSemaphore();
			return (0);
    }
    hMbx = freeMBX;
		mbx = MBXHandleToPointer(freeMBX);
		freeMBX = mbx->link;
		nMailbox--;
    UnlockSysSemaphore();
  }
	mbx->owner = GetRunningAppid();
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
	TCB *task;
	
	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	if (LockSysSemaphore(-1)) {
		if ((mbx->owner != GetRunningAppid()) && (GetRunningAppid() != 0)) {
	    UnlockSysSemaphore();
			return (E_NotOwner);
    }
		// Free up any queued messages
		while (msg = DequeueMsg(mbx))
			FreeMsg(msg);
		// Send an indicator to any queued threads that the mailbox
		// is now defunct Setting MsgPtr = null will cause any
		// outstanding WaitMsg() to return E_NoMsg.
		while(1) {
			DequeTaskFromMbx(mbx, &task);
			if (task == null)
				break;
			task->msg.type = MT_NONE;
			if (task->status & TS_TIMEOUT)
				TCBRemoveFromTimeoutList(TCBPointerToHandle(task));
			TCBInsertIntoReadyQueue(TCBPointerToHandle(task));
		}
		mbx->link = freeMBX;
		freeMBX = mbx-mailbox;
		nMailbox++;
    UnlockSysSemaphore();
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
		return (E_Arg);
	if (qStrategy > 2)
		return (E_Arg);
	mbx = MBXHandleToPointer(hMbx);
	if (LockSysSemaphore(-1)) {
		if ((mbx->owner != GetRunningAppid()) && GetRunningAppid() != 0) {
	    UnlockSysSemaphore();
			return (E_NotOwner);
    }
		mbx->mq_strategy = qStrategy;
		mbx->mq_size = qSize;
    UnlockSysSemaphore();
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
	TCB *task;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	mbx = &mailbox[hMbx-1];
	if (LockSysSemaphore(-1)) {
		// check for a mailbox owner which indicates the mailbox
		// is active.
		if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
	    UnlockSysSemaphore();
      return (E_NotAlloc);
    }
		if (freeMSG <= 0 || freeMSG > NR_MSG) {
	    UnlockSysSemaphore();
			return (E_NoMoreMsgBlks);
    }
    msg = AllocMsg();
		msg->dstadr = hMbx;
		msg->type = MT_DATA;
		msg->d1 = d1;
		msg->d2 = d2;
		msg->d3 = d3;
		DequeTaskFromMbx(mbx, &task);
    UnlockSysSemaphore();
  }
	if (task == null)
		return (QueueMsg(mbx, msg));
	if (LockSysSemaphore(-1)) {
		CopyMsg(&task->msg,msg);
    FreeMsg(msg);
  	if (task->status & TS_TIMEOUT)
  		TCBRemoveFromTimeoutList(TCBPointerToHandle(task));
  	TCBInsertIntoReadyQueue(TCBPointerToHandle(task));
    UnlockSysSemaphore();
  }
	return (E_Ok);
}


/* ----------------------------------------------------------------------------
	Description:
		Wait for message. If timelimit is zero then the thread will wait
	indefinately for a message.
	
	Parameters:
		d0 = handle of mailbox to wait at
		d1 = pointer into app's address space to store d1
		d2 = pointer into app's address space to store d2
		d3 = pointer into app's address space to store d3
		d4 = time limit to wait for message
---------------------------------------------------------------------------- */

long FMTK_WaitMsg(
	__reg("d0") long hMbx,
	__reg("d1") long d1,
	__reg("d2") long d2,
	__reg("d3") long d3,
	__reg("d4") long timelimit
)
{
	MBX *mbx;
	MSG *msg;
	TCB *task;
	hTCB hTask;
	TCB *rt;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	// Switch to system address space
	mbx = MBXHandleToPointer(hMbx);
	if (LockSysSemaphore(-1)) {
  	// check for a mailbox owner which indicates the mailbox
  	// is active.
  	if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
   	    UnlockSysSemaphore();
      	return (E_NotAlloc);
      }
  	msg = DequeueMsg(mbx);
    UnlockSysSemaphore();
  }
  // Return message right away if there is one available.
  if (msg) {
		if (d1)
			*(long*)d1 = msg->d1;
		if (d2)
			*(long*)d2 = msg->d2;
		if (d3)
			*(long*)d3 = msg->d3;
		// MoveLongToAppAddressSpace() will set the address space to
   	if (LockSysSemaphore(-1)) {
   		FreeMsg(msg);
	    UnlockSysSemaphore();
	  }
		return (E_Ok);
	}
	//-------------------------
	// Queue thread at mailbox
	//-------------------------
	if (LockSysSemaphore(-1)) {
		task = GetRunningTCBPtr();
		hTask = GetRunningTCB();
		TCBRemoveFromReadyQueue(hTask);
    UnlockSysSemaphore();
  }
	task->status |= TS_WAITMSG;
	task->hWaitMbx = hMbx;
	task->mbq_next = 0;
	if (LockSysSemaphore(-1)) {
		if (mbx->tq_head < 0) {
			task->mbq_prev = 0;
			mbx->tq_head = hTask;
			mbx->tq_tail = hTask;
			mbx->tq_count = 1;
		}
		else {
			task->mbq_prev = mbx->tq_tail;
			tcbs[mbx->tq_tail-1].mbq_next = hTask;
			mbx->tq_tail = hTask;
			mbx->tq_count++;
		}
    UnlockSysSemaphore();
  }
	//---------------------------
	// Is a timeout specified ?
	if (timelimit) {
        //asm { ; Waitmsg here; }
    	if (LockSysSemaphore(-1)) {
    	    TCBInsertIntoTimeoutList(hTask, timelimit);
    	    UnlockSysSemaphore();
        }
    }
  // Reschedule will cause control to pass to another task.
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
	__reg("d1") long d1,
	__reg("d2") long d2,
	__reg("d3") long d3,
	__reg("d4") long qrmv
)
{
	MBX *mbx;
	MSG *msg;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	mbx = &mailbox[hMbx-1];
 	if (LockSysSemaphore(-1)) {
  	// check for a mailbox owner which indicates the mailbox
  	// is active.
  	if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
  	    UnlockSysSemaphore();
  		return (E_NotAlloc);
      }
  	if (qrmv)
  		msg = DequeueMsg(mbx);
  	else
  		msg = MSGHandleToPointer(mbx->mq_head);
    UnlockSysSemaphore();
  }
	if (msg == null)
		return (E_NoMsg);
	if (d1)
		*(long*)d1 = msg->d1;
	if (d2)
		*(long*)d2 = msg->d2;
	if (d3)
		*(long*)d3 = msg->d3;
	if (qrmv) {
   	if (LockSysSemaphore(-1)) {
   		FreeMsg(msg);
	    UnlockSysSemaphore();
    }
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
	MSG msg;
	hMSG hm;
	TCB* task;
	hRQB hRqb;

	if (pRequest==NULL)
		return (E_Arg);
	if (pRequest->response_mbx==0 || pRequest->response_mbx > NR_MBX)
		return (E_Arg);
	if (hSevice == 0 || hService > NR_MBX)
		return (E_Arg);
	hMbx = service[hService-1].service_mbx;
	hRqb = AllocRqb();
	if (hRqb == 0)
		return (E_NoMoreRbqs);
	req = RQBHandleToPointer(hRqb);
	memcpy(req,pRequest,sizeof(RQB));

//	hs = GetServiceMbx(req->svcname);
	mbx = MBXHandleToPointer(hMbx);
	if (LockSysSemaphore(-1)) {
		// check for a mailbox owner which indicates the mailbox
		// is active.
		if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
			FreeRqb(hRqb);
	    UnlockSysSemaphore();
      return (E_NotAlloc);
    }
		if (freeMSG <= 0 || freeMSG > NR_MSG) {
			FreeRqb(hRqb);
	    UnlockSysSemaphore();
			return (E_NoMoreMsgBlks);
    }
		msg = AllocMsg();
		msg->dstadr = hMbx;
		msg->type = MT_RQB;
		msg->d1 = hRequest;
		DequeTaskFromMbx(mbx, &task);
    UnlockSysSemaphore();
  }
	if (task == null)
		return (QueueMsg(mbx, msg));
	if (LockSysSemaphore(-1)) {
		CopyMsg(&task->msg,msg);
    FreeMsg(msg);
  	if (task->status & TS_TIMEOUT)
  		TCBRemoveFromTimeoutList(TCBPointerToHandle(task));
  	TCBInsertIntoReadyQueue(TCBPointerToHandle(task));
    UnlockSysSemaphore();
  }
	return (E_Ok);
}

/* ----------------------------------------------------------------------------
---------------------------------------------------------------------------- */

long FMTK_Respond(__reg("d0") long hRbq, __reg("d1") long stat)
{
	RQB* rqb;
	MBX* rmbx;	
	hMSG hMsg;
	MSG *msg;
	TCB* task;
	
	if (hRqb==0 || hRqb > NR_RQB)
		return (E_Arg);
	rqb = RQBHandleToPointer(hRqb);
	if (rqb->response_mbx==0 || rqb->response_mbx > NR_MBX)
		return (E_BadMbx);
	rmbx = MBXHandleToPointer(rqb->response_mbx);
	if (rmbx->owner==0)
		return (E_BadMbx);
	if (stat==E_OwnerAbort) {
		FreeRqb(hRqb);
		return (E_Ok);
	}
	if (rqb->owner != GetRunningAppid()) {
		if (LockSysSemaphore(-1)) {
			if (rqb->pData1 && rqb->cbData1)
				DealiasMem(rqb->owner, rqb->pData1, rqb->cbData1);
			if (rqb->pData2 && rqb->cbData2)
				DealiasMem(rqb->owner, rqb->pData2, rqb->cbData2);
	    UnlockSysSemaphore();
		}
	}
	if (LockSysSemaphore(-1)) {
		msg = AllocMsg();
		msg->dstadr = rqb->response_mbx;
		msg->type = MT_RESP;
		msg->d1 = hRqb;
		msg->d2 = stat;
		msg->d3 = 0;
		DequeTaskFromMbx(rqb->response_mbx, &task);
    UnlockSysSemaphore();
	}
	if (task == null)
		return (QueueMsg(rqb->response_mbx, msg));
	if (LockSysSemaphore(-1)) {
		CopyMsg(&task->msg,msg);
    FreeMsg(msg);
  	if (task->status & TS_TIMEOUT)
  		TCBRemoveFromTimeoutList(TCBPointerToHandle(task));
  	TCBInsertIntoReadyQueue(TCBPointerToHandle(task));
    UnlockSysSemaphore();
  }
	return (E_Ok);
}
