#include "..\inc\const.h"
#include "..\inc\types.h"
#include "..\inc\proto.h"

// ----------------------------------------------------------------------------
// Semaphore lock/unlock code.
// Ultimately calls a BIOS routine to access the semaphoric memory which is
// set in an atomic fashion.
// ----------------------------------------------------------------------------

long LockSysSemaphore(long retries)
{
	return(LockSemaphore(OSSEMA,retries));
}

void UnlockSysSemaphore()
{
	UnlockSemaphore(OSSEMA);
}

long LockIOFSemaphore(long retries)
{
	return(LockSemaphore(IOFSEMA,retries));
}

void UnlockIOFSemaphore()
{
	UnlockSemaphore(IOFSEMA);
}

long LockKbdSemaphore(long retries)
{
	return(LockSemaphore(KEYBD_SEMA,retries));
}

void UnlockKbdSemaphore()
{
	UnlockSemaphore(KEYBD_SEMA);
}

long LockMMUSemaphore(long retries)
{
	return(LockSemaphore(MEMORY_SEMA,retries));
}

void UnlockMMUSemaphore()
{
	UnlockSemaphore(MEMORY_SEMA);
}

long LockPMTSemaphore(long retries)
{
	return(LockSemaphore(PMT_SEMA,retries));
}

void UnlockPMTSemaphore()
{
	UnlockSemaphore(PMT_SEMA);
}

long LockMSGSemaphore(long retries)
{
	return(LockSemaphore(MSG_SEMA,retries));
}

void UnlockMSGSemaphore()
{
	UnlockSemaphore(MSG_SEMA);
}

long LockMBXSemaphore(long retries)
{
	return(LockSemaphore(MBX_SEMA,retries));
}

void UnlockMBXSemaphore()
{
	UnlockSemaphore(MBX_SEMA);
}

long LockTimeoutList(long retries)
{
	return(LockSemaphore(TOL_SEMA,retries));
}

void UnlockTImeoutList()
{
	UnlockSemaphore(TOL_SEMA);
}

long LockReadyQueue(long retries)
{
	return(LockSemaphore(RDQ_SEMA,retries));
}

void UnlockReadyQueue()
{
	UnlockSemaphore(RDQ_SEMA);
}

long LockTCBList(long retries)
{
	return(LockSemaphore(TCB_SEMA,retries));
}

void UnlockTCBList()
{
	UnlockSemaphore(TCB_SEMA);
}

long LockACBSemaphore(long retries)
{
	return(LockSemaphore(ACB_SEMA,retries));
}

void UnlockACBSemaphore()
{
	UnlockSemaphore(ACB_SEMA);
}

