static unsigned long GetSP() = "\tmove.l\tsp,d0\n";

// ----------------------------------------------------------------------------
// If timer interrupts are enabled during a priority #0 thread, this routine
// only updates the missed ticks and remains in the same thread. No timeouts
// are updated and no thread switches will occur. The timer tick routine
// basically has a fixed latency when priority #0 is present.
//	A task runs for four ticks before switching unless an explicit task switch
// is requested.
// ----------------------------------------------------------------------------

__interrupt FMTK_SchedulerIRQ()
{
  TCB *t, *ot, *tol;
  int ensw;		// enable task switch
  unsigned long *sf;
  unsigned short int *sfw;

	ensw = 0;
	ot = t = GetRunningTCBPtr();
	t->endTick = GetTick();
	if (t->endTick > t->startTick + 4)
		ensw = 1;
	switch(GetCauseCode()) {
	// Timer tick interrupt
	case 159:
//		AckTimerIRQ();
		if (getCPU()==0) DisplayIRQLive();
		if (LockSysSemaphore(20)) {
			t->ticks = t->ticks + (t->endTick - t->startTick);
			if (t->priority != 63) {
				t->status |= TS_PREEMPT;
				t->status &= ~TS_RUNNING;
				while (TimeoutList > 0 && TimeoutList <= NR_TCB) {
					tol = TCBHandleToPointer(TimeoutList);
					if (tol->timeout <= 0)
						InsertIntoReadyList(PopTimeoutList());
					else {
						tol->timeout = tol->timeout - missed_ticks - 1;
						missed_ticks = 0;
						break;
					}
				}
				if (t->priority < 60 && ensw)
					SetRunningTCBPtr(TCBHandleToPointer(SelectTaskToRun()));
				GetRunningTCBPtr()->status |= TS_RUNNING;
			}
			else
				missed_ticks++;
			UnlockSysSemaphore();
		}
		else {
			missed_ticks++;
		}
		break;
	// Explicit rescheduling request.
	case 241:
		ensw = 1;
		t->ticks = t->ticks + (t->endTick - t->startTick);
		t->status |= TS_PREEMPT;
		t->status &= ~TS_RUNNING;
//		t->epc = t->epc + 1;  // advance the return address
		SetRunningTCBPtr(TCBHandleToPointer(SelectTaskToRun()));
		GetRunningTCBPtr()->status |= TS_RUNNING;
		break;
	default:  ;
	}
	// If an exception was flagged (eg CTRL-C) return to the catch handler
	// not the interrupted code.
	t = GetRunningTCBPtr();
	if (t->exception) {
		sf = GetSP();
		sf[1] = t->exception;
		sf[2] = 45;
		sfw[33] = (unsigned short int)((unsigned long)(t->exceptionHandler >> 16));
		sfw[34] = (unsigned short int)((unsigned long)(t->exceptionHandler & 0xffff));
	}
	t->startTick = GetTick();
	if (ot != t && ensw)
		SwapContext(ot,t);
}
