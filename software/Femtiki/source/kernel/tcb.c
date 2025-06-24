extern hTCB FreeTCB;
extern TCB* tcbs;

TCB* TCBHandleToPointer(short int TCBHandle handle)
{
	if (handle <= 0)
		return (TCB*)0;
	return (&tcbs[handle-1]);
}

hTCB TCBPointerToHandle(TCB* ptr)
{
	hTCB h;
	
	h = ptr - &tcbs[0];
	return (h+1);	
}

void InsertIntoReadyQ(short int TCBHandle handle)
{
	TCB* p;
	
	p = TCBHandleToPointer(handle);
	
}

static hTCB iAllocTCB()
{
	TCB* p;
	hTCB h;

	if (FreeTCB==0)
		return (0);
	h = FreeTCB;
	p = TCBHandleToPointer(FreeTCB);
	FreeTCB = p->NextTCB;
	return (h);
}

hTCB AllocTCB(hTCB* ph)
{
	LockSysSemaphore();
	h = iAllocTCB();
	UnlockSysSemaphore();
	if (ph)
		*ph = h;
	return (E_Ok);
}

static void iFreeTCB(hTCB h)
{
	TCB* p;
	
	p = TCBHandleToPointer(h);
	if (p) {
		p->NextTCB = FreeTCB;
		FreeTCB = h;
	}
}

int FreeTCB(hTCB h)
{
	LockSysSemaphore();
	iFreeTCB(h);	
	UnlockSysSemaphore();
	return (E_Ok);
}
