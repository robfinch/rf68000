#include "..\inc\const.h"
#include "..\inc\types.h"
#include "..\inc\proto.h"

// ----------------------------------------------------------------------------
// Semaphore lock/unlock code.
// Ultimately calls a BIOS routine to access the semaphoric memory which is
// set in an atomic fashion.
// ----------------------------------------------------------------------------

int LockSysSemaphore(long retries)
{
	return(LockSemaphore(OSSEMA,retries));
}

void UnlockSysSemaphore(int im)
{
	UnlockSemaphore(OSSEMA,im);
}

int LockIOFSemaphore(long retries)
{
	return(LockSemaphore(IOFSEMA,retries));
}

void UnlockIOFSemaphore(int im)
{
	UnlockSemaphore(IOFSEMA, im);
}

int LockKbdSemaphore(long retries)
{
	return(LockSemaphore(KEYBD_SEMA,retries));
}

void UnlockKbdSemaphore(int im)
{
	UnlockSemaphore(KEYBD_SEMA, im);
}

int LockMMUSemaphore(long retries)
{
	return(LockSemaphore(MEMORY_SEMA,retries));
}

void UnlockMMUSemaphore(int im)
{
	UnlockSemaphore(MEMORY_SEMA, im);
}

int LockPMTSemaphore(long retries)
{
	return(LockSemaphore(PMT_SEMA,retries));
}

void UnlockPMTSemaphore(int im)
{
	UnlockSemaphore(PMT_SEMA, im);
}

int LockMSGList(long retries)
{
	return(LockSemaphore(MSG_SEMA,retries));
}

void UnlockMSGList(int im)
{
	UnlockSemaphore(MSG_SEMA, im);
}

int LockMBXList(long retries)
{
	return(LockSemaphore(MBXLIST_SEMA,retries));
}

void UnlockMBXList(int im)
{
	UnlockSemaphore(MBXLIST_SEMA, im);
}

int LockMBX(long wh, long retries)
{
	return(LockSemaphore(MBX_SEMA+wh,retries));
}

void UnlockMBX(long wh, int im)
{
	UnlockSemaphore(MBX_SEMA+wh, im);
}

int LockTimeoutList(long retries)
{
	return(LockSemaphore(TOL_SEMA,retries));
}

void UnlockTimeoutList(int im)
{
	UnlockSemaphore(TOL_SEMA, im);
}

int LockReadyQueue(long retries)
{
	return(LockSemaphore(RDQ_SEMA,retries));
}

void UnlockReadyQueue(int im)
{
	UnlockSemaphore(RDQ_SEMA, im);
}

int LockTCBList(long retries)
{
	return(LockSemaphore(TCB_SEMA,retries));
}

void UnlockTCBList(int im)
{
	UnlockSemaphore(TCB_SEMA, im);
}

int LockACBSemaphore(long retries)
{
	return(LockSemaphore(ACB_SEMA,retries));
}

void UnlockACBSemaphore(int im)
{
	UnlockSemaphore(ACB_SEMA, im);
}

int LockAlarmList(long retries)
{
	return(LockSemaphore(ALARM_SEMA,retries));
}

void UnlockAlarmList(int im)
{
	UnlockSemaphore(ALARM_SEMA, im);
}

