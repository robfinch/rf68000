// ----------------------------------------------------------------------------
// Select a task to run.
// ----------------------------------------------------------------------------

static int invert;

static hTCB SelectTaskToRunHelper(int nn)
{
	int kk;
  hTCB h, h1;
	TCB *p, *q;
 
	h = readyQ[nn];
	if (h > 0 && h <= NR_TCB) {
		p = TCBHandleToPointer(h);
    kk = 0;
    // Can run the head of a lower Q level if it's not the running
    // task, otherwise look to the next task.
    if (h != GetRunningTCB())
   		q = p;
		else
   		q = TCBHandleToPointer(p->next);
    do {  
      if (!(q->status & TS_RUNNING)) {
        if (q->affinity == getCPU()) {
        	h1 = TCBPointerToHandle(q);
			  	readyQ[nn] = h1;
			   	return (h1);
        }
      }
      q = TCBHandleToPointer(q->next);
      kk = kk + 1;
    } while (q != p && kk < NR_TCB);
  }
	return (-1);
}

static hTCB SelectTaskToRun()
{
	int nn;
  hTCB h;
 
 	invert++;
	// Occasionally prioriies are inverted.
	if ((invert & 63)==0) {
		for (nn = 0; nn < 64; nn++) {
			if ((h = SelectTaskToRunHelper(nn)) > 0)
				return (h);
		}
		return (GetRunningTCB());
	}
	// Search the queues from the highest to lowest priority.
	for (nn = 63; nn >= 0; nn--) {
		if ((h = SelectTaskToRunHelper(nn)) > 0)
			return (h);
	}
	return (GetRunningTCB());
	panic("No entries in ready queue.");
}
