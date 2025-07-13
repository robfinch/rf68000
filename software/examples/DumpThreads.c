#include "..\Femtiki\source\inc\const.h"
#include "..\Femtiki\source\inc\config.h"
#include "..\Femtiki\source\inc\types.h"

extern TCB tcbs[NR_TCB];
extern ACB* ACBPtrs[NR_ACB];

extern void DisplayStringCRLF(__reg("a1") char *);
extern void OutputChar(char);
extern void DisplayByte(__reg("d1") long);
extern void DisplayWyde(__reg("d1") long);
extern void DisplayTetra(__reg("d1") long);

void DumpThreads()
{
	int nn;
	int im;
	
	im = SetImLevel(7);
	DisplayStringCRLF("\r\nthrd next status    pc    owner pri affin");
	DisplayStringCRLF(    "---- ---- ------ -------- ----- --- -----");
	for (nn = 0; nn < 10;/*NR_TCB;*/ nn++) {
//		if (tcbs[nn].hApp != 0 || tcbs[nn].status != 0)
//		{
			DisplayByte(nn);
			OutputChar(' ');
			DisplayByte(tcbs[nn].next);
			OutputChar(' ');
			DisplayByte(tcbs[nn].status);
			OutputChar(' ');
			DisplayTetra(tcbs[nn].pc);
			OutputChar(' ');
			DisplayByte(tcbs[nn].hApp);
			OutputChar(' ');
			DisplayByte(tcbs[nn].priority);
			OutputChar(' ');
			DisplayByte(tcbs[nn].affinity);
			OutputChar(' ');
//			DisplayWyde(tcbs[nn].stacksize);
			OutputChar('\r');
			OutputChar('\n');
//		}
	}
	SetImLevelHelper(im);
}

void DumpApps()
{
	int nn;

	DisplayStringCRLF("\r\napp code thread");
	DisplayStringCRLF("--- ---- ----");
	for (nn = 0; nn < NR_ACB; nn++) {
		if (ACBPtrs[nn]) {
			if (ACBPtrs[nn]->magic == ACB_MAGIC) {
				DisplayByte(nn);
				OutputChar(' ');
				DisplayTetra((long)ACBPtrs[nn]->pCode);
				OutputChar(' ');
				DisplayByte(ACBPtrs[nn]->thread);
				OutputChar(' ');
				OutputChar('\r');
				OutputChar('\n');
			}
		}
	}
}
