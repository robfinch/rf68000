#include "..\Femtiki\source\inc\const.h"
#include "..\Femtiki\source\inc\config.h"
#include "..\Femtiki\source\inc\types.h"
#include "..\Femtiki\source\inc\proto.h"


extern TCB tcbs[NR_TCB];
extern ACB* ACBPtrs[NR_ACB];
extern hTCB readyQ[32];
extern hTCB TimeoutList;
extern hMBX hIdleMbx;

extern void DisplayString(__reg("a1") char *);
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
	DisplayStringCRLF("\r\nthrd next stat    pc       sp    owner pri affin");
	DisplayStringCRLF(    "---- ---- ---- -------- -------- ----- --- -----");
	for (nn = 0; nn < 10;/*NR_TCB;*/ nn++) {
		if (tcbs[nn].hApp != 0 || tcbs[nn].status != 0)
		{
			DisplayByte(nn+1);
			OutputChar(' ');
			DisplayByte(tcbs[nn].next);
			OutputChar(' ');
			DisplayByte(tcbs[nn].status);
			OutputChar(' ');
			DisplayTetra(tcbs[nn].pc);
			OutputChar(' ');
			DisplayTetra(tcbs[nn].regs[16]);
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
		}
	}
	SetImLevelHelper(im);
}

void DumpTOL()
{
	int sr;
	hTCB ht;
	TCB* p;

	DisplayStringCRLF("\r\nTimeout List ");
	DisplayStringCRLF("thrd next timeout ");
	DisplayStringCRLF("---- ---- ------- ");
	sr = SetImLevel7();
	for (ht = TimeoutList; ht; ) {
		p = TCBHandleToPointer(ht);
		if (p == (TCB*)0)
			break;
		DisplayByte(ht);
		OutputChar(' ');
		DisplayByte(p->next);
		OutputChar(' ');
		DisplayTetra(p->timeout);
		DisplayStringCRLF(" ");
		ht = p->next;
	}
	RestoreSr(sr);
}

void DumpReadyQueue()
{
	int nn;
	int sr;
	int thd,fst;
	TCB* p;
	
	sr = SetImLevel7();
	for (nn = 0; nn < 32; nn++) {
		if (readyQ[nn] > 0 && readyQ[nn] <= NR_TCB) {
			DisplayString("\r\nQueue: ");
			DisplayByte(nn);
			DisplayStringCRLF(" ");
			DisplayStringCRLF("\r\nthrd next status ");
			DisplayStringCRLF(    "---- ---- ------ ");
			fst = readyQ[nn];
			for (thd = fst; thd > 0 && thd <= NR_TCB; ) {
				p = TCBHandleToPointer(thd);
				DisplayByte(thd);
				OutputChar(' ');
				DisplayByte(p->next);
				OutputChar(' ');
				DisplayByte(p->status);
				OutputChar(' ');
				thd = p->next;
				OutputChar('\r');
				OutputChar('\n');
				if (thd==fst)
					break;
			}
		}
	}
	RestoreSr(sr);
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

void SendIdle()
{
	static int kk = 0;
	
	FMTK_SendMsg(hIdleMbx, 0xfffffff1, 0xfffffff1, kk);
	kk++;
}
