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
	return(LockSemaphoreNB(OSSEMA+(long)&semaphores,retries));
}

void UnlockSysSemaphore(int im)
{
	UnlockSemaphoreNB(OSSEMA+(long)&semaphores,im);
}

int LockIOFSemaphore(long retries)
{
	return(LockSemaphoreNB(IOFSEMA+(long)&semaphores,retries));
}

void UnlockIOFSemaphore(int im)
{
	UnlockSemaphoreNB(IOFSEMA+(long)&semaphores, im);
}

int LockKbdSemaphore(long retries)
{
	return(LockSemaphoreNB(KEYBD_SEMA+(long)&semaphores,retries));
}

void UnlockKbdSemaphore(int im)
{
	UnlockSemaphoreNB(KEYBD_SEMA+(long)&semaphores, im);
}

int LockMMUSemaphore(long retries)
{
	return(LockSemaphoreNB(MEMORY_SEMA+(long)&semaphores,retries));
}

void UnlockMMUSemaphore(int im)
{
	UnlockSemaphoreNB(MEMORY_SEMA+(long)&semaphores, im);
}

int LockPMTSemaphore(long retries)
{
	return(LockSemaphoreNB(PMT_SEMA+(long)&semaphores,retries));
}

void UnlockPMTSemaphore(int im)
{
	UnlockSemaphoreNB(PMT_SEMA+(long)&semaphores, im);
}

int LockMSGList(long retries)
{
	return(LockSemaphoreNB(MSG_SEMA+(long)&semaphores,retries));
}

void UnlockMSGList(int im)
{
	UnlockSemaphoreNB(MSG_SEMA+(long)&semaphores, im);
}

int LockMBXList(long retries)
{
	return(LockSemaphoreNB(MBXLIST_SEMA+(long)&semaphores,retries));
}

void UnlockMBXList(int im)
{
	UnlockSemaphoreNB(MBXLIST_SEMA+(long)&semaphores, im);
}

int LockMBX(long wh, long retries)
{
	return(LockSemaphoreNB(mailbox[wh-1].lock,retries));
}

void UnlockMBX(long wh, int im)
{
	UnlockSemaphoreNB(mailbox[wh-1].lock, im);
}

int LockTimeoutList(long retries)
{
	return(LockSemaphoreNB(TOL_SEMA+(long)&semaphores,retries));
}

void UnlockTimeoutList(int im)
{
	UnlockSemaphoreNB(TOL_SEMA+(long)&semaphores, im);
}

int LockReadyQueue(long retries)
{
	return(LockSemaphoreNB(RDQ_SEMA+(long)&semaphores,retries));
}

void UnlockReadyQueue(int im)
{
	UnlockSemaphoreNB(RDQ_SEMA+(long)&semaphores, im);
}

int LockTCBList(long retries)
{
	return(LockSemaphoreNB(TCB_SEMA+(long)&semaphores,retries));
}

void UnlockTCBList(int im)
{
	UnlockSemaphoreNB(TCB_SEMA+(long)&semaphores, im);
}

int LockACBSemaphore(long retries)
{
	return(LockSemaphoreNB(ACB_SEMA+(long)&semaphores,retries));
}

void UnlockACBSemaphore(int im)
{
	UnlockSemaphoreNB(ACB_SEMA+(long)&semaphores, im);
}

int LockAlarmList(long retries)
{
	return(LockSemaphoreNB(ALARM_SEMA+(long)&semaphores,retries));
}

void UnlockAlarmList(int im)
{
	UnlockSemaphoreNB(ALARM_SEMA+(long)&semaphores, im);
}

int LockTMRSemaphore(long retries)
{
	return(LockSemaphoreNB(TMR_SEMA+(long)&semaphores,retries));
}

void UnlockTMRSemaphore(int im)
{
	UnlockSemaphoreNB(TMR_SEMA+(long)&semaphores, im);
}

