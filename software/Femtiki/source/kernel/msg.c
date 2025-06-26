#include "inc\types.h"
#include "inc\const.h"
#include "inc\config.h"
#include "inc\proto.h"
#include "inc\glo.h"

static MSG* MSGHandleToPointer(hMSG h)
{
	MSG* msg;
	
	msg = &message[h-1];
	return (msg);
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


/* ---------------------------------------------------------------
	Description:
		Dequeues a message from a mailbox.

	Assumptions:
		Mailbox parameter is valid.
		System semaphore is locked already.

	Called from:
		FreeMbx - (locks mailbox)
		WaitMsg	-	"
		CheckMsg-	"
--------------------------------------------------------------- */

static MSG *DequeueMsg(MBX *mbx)
{
	MSG *tmpmsg = null;
  hMSG hm;
 
	if (mbx->mq_count) {
		mbx->mq_count--;
		hm = mbx->mq_head;
		if (hm >= 0) {	// should not be null
		    tmpmsg = &message[hm-1];
			mbx->mq_head = tmpmsg->link;
			if (mbx->mq_head < 0)
				mbx->mq_tail = 0;
			tmpmsg->link = hm;
		}
	}
	return (tmpmsg);
}


/* ---------------------------------------------------------------
	Description:
		Dequeues a thread from a mailbox. The thread will also
	be removed from the timeout list (if it's present there),
	and	the timeout list will be adjusted accordingly.

	Assumptions:
		Mailbox parameter is valid.
--------------------------------------------------------------- */

static long DequeThreadFromMbx(MBX *mbx, TCB **thrd)
{
	if (thrd == NULL || mbx == NULL)
		return (E_Arg);

	if (LockSysSemaphore(-1)) {
		if (mbx->tq_head == 0) {
  		UnlockSysSemaphore();
			*thrd = null;
			return (E_NoThread);
		}
	
		mbx->tq_count--;
		*thrd = &tcbs[mbx->tq_head-1];
		mbx->tq_head = tcbs[mbx->tq_head-1].mbq_next;
		if (mbx->tq_head > 0)
			tcbs[mbx->tq_head-1].mbq_prev = 0;
		else
			mbx->tq_tail = 0;
		UnlockSysSemaphore();
	}

	// if thread is also on the timeout list then
	// remove from timeout list
	// adjust succeeding thread timeout if present
	if ((*thrd)->status & TS_TIMEOUT)
		RemoveFromTimeoutList(((*thrd)-tcbs)+1);

	(*thrd)->mbq_prev = (*thrd)->mbq_next = 0;
	(*thrd)->hWaitMbx = 0;	// no longer waiting at mailbox
	(*thrd)->status &= ~TS_WAITMSG;
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Allocate a mailbox. The default queue strategy is to
	queue the eight most recent messages.
--------------------------------------------------------------- */

long FMTK_AllocMbx(__reg("d0") hMBX *phMbx)
{
	MBX *mbx;

	if (phMbx==NULL)
  	return (E_Arg);
	if (LockSysSemaphore(-1)) {
		if (freeMBX <= 0 || freeMBX >= NR_MBX) {
	    UnlockSysSemaphore();
			return (E_NoMoreMbx);
    }
		mbx = &mailbox[freeMBX-1];
		freeMBX = mbx->link;
		nMailbox--;
    UnlockSysSemaphore();
  }
	*phMbx = (mbx - mailbox) + 1;
	mbx->owner = GetAppHandle();
	mbx->tq_head = 0;
	mbx->tq_tail = 0;
	mbx->mq_head = 0;
	mbx->mq_tail = 0;
	mbx->tq_count = 0;
	mbx->mq_count = 0;
	mbx->mq_missed = 0;
	mbx->mq_size = 8;
	mbx->mq_strategy = MQS_NEWEST;
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Free up a mailbox. When the mailbox is freed any queued
	messages must be freed. Any queued threads must also be
	dequeued. 
--------------------------------------------------------------- */
long FMTK_FreeMbx(__reg("d0") hMBX hMbx) 
{
	MBX *mbx;
	MSG *msg;
	TCB *thrd;
	
	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	mbx = &mailbox[hMbx-1];
	if (LockSysSemaphore(-1)) {
		if ((mbx->owner != GetAppHandle()) && (GetAppHandle() != 0)) {
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
			DequeThreadFromMbx(mbx, &thrd);
			if (thrd == null)
				break;
			thrd->msg.type = MT_NONE;
			if (thrd->status & TS_TIMEOUT)
				RemoveFromTimeoutList((thrd-tcbs)+1);
			InsertIntoReadyList((thrd-tcbs)+1);
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
	mbx = &mailbox[hMbx-1];
	if (LockSysSemaphore(-1)) {
		if ((mbx->owner != GetAppHandle()) && GetAppHandle() != 0) {
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
	__reg("d0") hMBX hMbx,
	__reg("d1") long d1,
	__reg("d2") long d2,
	__reg("d3") long d3
)
{
	MBX *mbx;
	MSG *msg;
	TCB *thrd;

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
		msg = &message[freeMSG-1];
		freeMSG = msg->link;
		--nMsgBlk;
		msg->retadr = GetAppHandle();
		msg->dstadr = hMbx;
		msg->type = MBT_DATA;
		msg->d1 = d1;
		msg->d2 = d2;
		msg->d3 = d3;
		DequeThreadFromMbx(mbx, &thrd);
    UnlockSysSemaphore();
  }
	if (thrd == null)
		return (QueueMsg(mbx, msg));
	if (LockSysSemaphore(-1)) {
		CopyMsg(&thrd->msg,msg);
    FreeMsg(msg);
  	if (thrd->status & TS_TIMEOUT)
  		RemoveFromTimeoutList(thrd-tcbs);
  	InsertIntoReadyList(thrd-tcbs);
    UnlockSysSemaphore();
  }
	return (E_Ok);
}


s/* ---------------------------------------------------------------
	Description:
		Wait for message. If timelimit is zero then the thread
	will wait indefinately for a message.
--------------------------------------------------------------- */

long FMTK_WaitMsg(
	__reg("d0") hMBX hMbx,
	__reg("d1") long *d1,
	__reg("d2") long *d2,
	__reg("d3") long *d3,
	__reg("d4") long timelimit
)
{
	MBX *mbx;
	MSG *msg;
	TCB *thrd;
	TCB *rt;

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
  	msg = DequeueMsg(mbx);
    UnlockSysSemaphore();
  }
  // Return message right away if there is one available.
  if (msg) {
		d1 = LinearToPhysical(GetRunningPID(), d1);
		d2 = LinearToPhysical(GetRunningPID(), d2);
		d3 = LinearToPhysical(GetRunningPID(), d3);
		if (d1)
			*d1 = msg->d1;
		if (d2)
			*d2 = msg->d2;
		if (d3)
			*d3 = msg->d3;
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
		thrd = GetRunningTCBPtr();
		RemoveFromReadyList(thrd-tcbs);
    UnlockSysSemaphore();
  }
	thrd->status |= TS_WAITMSG;
	thrd->hWaitMbx = hMbx;
	thrd->mbq_next = 0;
	if (LockSysSemaphore(-1)) {
		if (mbx->tq_head < 0) {
			thrd->mbq_prev = 0;
			mbx->tq_head = (thrd-tcbs)+1;
			mbx->tq_tail = (thrd-tcbs)+1;
			mbx->tq_count = 1;
		}
		else {
			thrd->mbq_prev = mbx->tq_tail;
			tcbs[mbx->tq_tail-1].mbq_next = thrd-tcbs;
			mbx->tq_tail = (thrd-tcbs)+1;
			mbx->tq_count++;
		}
    UnlockSysSemaphore();
  }
	//---------------------------
	// Is a timeout specified ?
	if (timelimit) {
        //asm { ; Waitmsg here; }
    	if (LockSysSemaphore(-1)) {
    	    InsertIntoTimeoutList(thrd-tcbs, timelimit);
    	    UnlockSysSemaphore();
        }
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
	d1 = LinearToPhysical(GetRunningPID(), d1);
	d2 = LinearToPhysical(GetRunningPID(), d2);
	d3 = LinearToPhysical(GetRunningPID(), d3);
	if (d1)
		*d1 = rt->msg.d1;
	if (d2)
		*d2 = rt->msg.d2;
	if (d3)
		*d3 = rt->msg.d3;
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// PeekMsg()
//     Look for a message in the queue but don't remove it from the queue.
//     This is a convenince wrapper for CheckMsg().
// ----------------------------------------------------------------------------

long FMTK_PeekMsg (
	__reg("d0") hMBX hMbx,
	__reg("d1") long *d1,
	__reg("d2") long *d2,
	__reg("d3") long *d3
)
{
  return (FMTK_CheckMsg(hMbx, d1, d2, d3, 0));
}

/* ---------------------------------------------------------------
	Description:
		Check for message at mailbox. If no message is
	available return immediately to the caller (CheckMsg() is
	non blocking). Optionally removes the message from the
	mailbox.
--------------------------------------------------------------- */

long FMTK_CheckMsg (
	__reg("d0") hMBX hMbx,
	__reg("d1") long *d1,
	__reg("d2") long *d2,
	__reg("d3") long *d3,
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
	d1 = LinearToPhysical(GetRunningPID(), d1);
	d2 = LinearToPhysical(GetRunningPID(), d2);
	d3 = LinearToPhysical(GetRunningPID(), d3);
	if (d1)
		*d1 = msg->d1;
	if (d2)
		*d2 = msg->d2;
	if (d3)
		*d3 = msg->d3;
	if (qrmv) {
   	if (LockSysSemaphore(-1)) {
   		FreeMsg(msg);
	    UnlockSysSemaphore();
    }
	}
	return (E_Ok);
}

