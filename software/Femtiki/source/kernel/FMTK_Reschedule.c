// ----------------------------------------------------------------------------
// FMTK primitives need to re-schedule threads in a couple of places.
// ----------------------------------------------------------------------------

void FMTK_Reschedule()
{
	ForceTimerIRQ();
}

