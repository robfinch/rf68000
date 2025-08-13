#include "..\inc\const.h"
#include "..\inc\config.h"
#include "..\inc\types.h"
#include "..\inc\proto.h"
#include "..\inc\glo.h"

extern long semaphores;

// ----------------------------------------------------------------------------
// Semaphore lock/unlock code.
// Ultimately calls a BIOS routine to access the semaphoric memory which is
// set in an atomic fashion.
// ----------------------------------------------------------------------------

int LockSysSemaphore(long retries)
{
	return(LockSemaphore(OSSEMA+(long)&semaphores,retries));
}

void UnlockSysSemaphore(int im)
{
	UnlockSemaphore(OSSEMA+(long)&semaphores,im);
}

int LockIOFSemaphore(long retries)
{
	return(LockSemaphore(IOFSEMA+(long)&semaphores,retries));
}

void UnlockIOFSemaphore(int im)
{
	UnlockSemaphore(IOFSEMA+(long)&semaphores, im);
}

int LockKbdSemaphore(long retries)
{
	return(LockSemaphore(KEYBD_SEMA+(long)&semaphores,retries));
}

void UnlockKbdSemaphore(int im)
{
	UnlockSemaphore(KEYBD_SEMA+(long)&semaphores, im);
}

int LockMMUSemaphore(long retries)
{
	return(LockSemaphore(MEMORY_SEMA+(long)&semaphores,retries));
}

void UnlockMMUSemaphore(int im)
{
	UnlockSemaphore(MEMORY_SEMA+(long)&semaphores, im);
}

int LockPMTSemaphore(long retries)
{
	return(LockSemaphore(PMT_SEMA+(long)&semaphores,retries));
}

void UnlockPMTSemaphore(int im)
{
	UnlockSemaphore(PMT_SEMA+(long)&semaphores, im);
}

int LockMSGList(long retries)
{
	return(LockSemaphore(MSG_SEMA+(long)&semaphores,retries));
}

void UnlockMSGList(int im)
{
	UnlockSemaphore(MSG_SEMA+(long)&semaphores, im);
}

int LockMBXList(long retries)
{
	return(LockSemaphore(MBXLIST_SEMA+(long)&semaphores,retries));
}

void UnlockMBXList(int im)
{
	UnlockSemaphore(MBXLIST_SEMA+(long)&semaphores, im);
}

int LockMBX(long wh, long retries)
{
	return(LockSemaphore(mailbox[wh-1].lock,retries));
}

void UnlockMBX(long wh, int im)
{
	UnlockSemaphore(mailbox[wh-1].lock, im);
}

int LockTimeoutList(long retries)
{
	return(LockSemaphore(TOL_SEMA+(long)&semaphores,retries));
}

void UnlockTimeoutList(int im)
{
	UnlockSemaphore(TOL_SEMA+(long)&semaphores, im);
}

int LockReadyQueue(long retries)
{
	return(LockSemaphore(RDQ_SEMA+(long)&semaphores,retries));
}

void UnlockReadyQueue(int im)
{
	UnlockSemaphore(RDQ_SEMA+(long)&semaphores, im);
}

int LockTCBList(long retries)
{
	return(LockSemaphore(TCB_SEMA+(long)&semaphores,retries));
}

void UnlockTCBList(int im)
{
	UnlockSemaphore(TCB_SEMA+(long)&semaphores, im);
}

int LockACBSemaphore(long retries)
{
	return(LockSemaphore(ACB_SEMA+(long)&semaphores,retries));
}

void UnlockACBSemaphore(int im)
{
	UnlockSemaphore(ACB_SEMA+(long)&semaphores, im);
}

int LockAlarmList(long retries)
{
	return(LockSemaphore(ALARM_SEMA+(long)&semaphores,retries));
}

void UnlockAlarmList(int im)
{
	UnlockSemaphore(ALARM_SEMA+(long)&semaphores, im);
}

int LockTMRSemaphore(long retries)
{
	return(LockSemaphore(TMR_SEMA+(long)&semaphores,retries));
}

void UnlockTMRSemaphore(int im)
{
	UnlockSemaphore(TMR_SEMA+(long)&semaphores, im);
}

