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

