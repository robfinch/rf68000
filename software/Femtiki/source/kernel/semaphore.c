// ----------------------------------------------------------------------------
// Semaphore lock/unlock code.
// Ultimately calls a BIOS routine to access the semaphoric memory which is
// set in an atomic fashion.
// ----------------------------------------------------------------------------

int LockSysSemaphore(int retries)
{
	return(LockSemaphore(OSSEMA,retries));
}

void UnlockSysSemaphore()
{
	UnlockSemaphore(OSSEMA);
}

int LockIOFSemaphore(register int retries)
{
	return(LockSemaphore(IOFSEMA,retries));
}

void UnlockIOFSemaphore()
{
	UnlockSemaphore(IOFSEMA);
}

int LockKbdSemaphore(register int retries)
{
	return(LockSemaphore(KEYBD_SEMA,retries));
}

void UnlockKbdSemaphore()
{
	UnlockSemaphore(KEYBD_SEMA);
}

int LockMMUSemaphore(register int retries)
{
	return(LockSemaphore(MEMORY_SEMA,retries));
}

void UnlockMMUSemaphore()
{
	UnlockSemaphore(MEMORY_SEMA);
}

int LockPMTSemaphore(register int retries)
{
	return(LockSemaphore(PMT_SEMA,retries));
}

void UnlockPMTSemaphore()
{
	UnlockSemaphore(PMT_SEMA);
}



