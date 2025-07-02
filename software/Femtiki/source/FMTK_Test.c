#include "inc\proto.h"
extern void OutputString(char *);

int main()
{
	hMBX hMbx;
	int nn;

	FMTK_Initialize();
	hMbx = FMTK_AllocMbx();
	for (nn = 0; nn < 10; nn++) {
		FMTK_SendMsg(hMbx, 0xfffffff1, 0xfffffff1, 0xfffffff1);
		OutputString("Sent\r'n");
		FMTK_WaitMsg(hMbx, (long)&d1, (long)&d2, (long)&d3, -1);
		OutputString("Received\r'n");
	}
	FMTK_FreeMbx(hMbx);
}
