#include "inc/config.h"
#include "inc/device.h"
#include "inc/types.h"

// Standard Devices are:
//
// #		Device					Standard name

// 0		NULL device 		NULL				(OS built-in)
// 1		Keyboard (sequential)	KBD		(OS built-in)
// 2		Video (sequential)		VID		(OS built-in)
// 3		Printer (parallel 1)	LPT
// 4		Printer (parallel 2)	LPT2
// 5		RS-232 1				COM1	(OS built-in)
// 6		RS-232 2				COM2
// 7		RS-232 3				COM3
// 8		RS-232 4				COM4
// 9		Parallel xfer	  PTI
// 10		Floppy					FD0
// 11		Floppy					FD1
// 12		Hard disk				HD0
// 13		Hard disk				HD1
// 14
// 15
// 16		SDCard					CARD1 	(OS built-in)
// 17
// 18
// 19
// 20
// 21
// 22
// 23
// 24
// 25
// 26
// 27
// 28		Audio						PSG1	(OS built-in)
// 29		Console					CON		(OS built-in)
// 30   Random Number		PRNG
// 31		Debug						DBG

extern hMBX hDevMailbox[64];
extern DCB DeviceTable[NR_DCB];
extern long null_cmdproc(__reg("d6") long cmd, __reg("d1") long p1, __reg("d2") long p2, __reg("d3") long p3, __reg("d4") long p4, __reg("d5") long p5);
extern long keybd_cmdproc(__reg("d6") long cmd, __reg("d1") long p1, __reg("d2") long p2, __reg("d3") long p3, __reg("d4") long p4, __reg("d5") long p5);
extern long textvid_cmdproc(__reg("d6") long cmd, __reg("d1") long p1, __reg("d2") long p2, __reg("d3") long p3, __reg("d4") long p4, __reg("d5") long p5);
extern long framebuf_cmdproc(__reg("d6") long cmd, __reg("d1") long p1, __reg("d2") long p2, __reg("d3") long p3, __reg("d4") long p4, __reg("d5") long p5);
extern long gfxaccel_cmdproc(__reg("d6") long cmd, __reg("d1") long p1, __reg("d2") long p2, __reg("d3") long p3, __reg("d4") long p4, __reg("d5") long p5);
extern long serial_cmdproc(__reg("d6") long cmd, __reg("d1") long p1, __reg("d2") long p2, __reg("d3") long p3, __reg("d4") long p4, __reg("d5") long p5);
//extern long pti_cmdProc(long cmd, long p1, long p2, long p3, long p4);
//extern long dbg_cmdProc(long cmd, long p1, long p2, long p3, long p4);
//extern long prng_cmdProc(long cmd, long p1, long p2, long p3, long p4);
//extern long sdc_cmdProc(long cmd, long p1, long p2, long p3, long p4);
//extern long con_cmdProc(long cmd, long p1, long p2, long p3, long p4);

void SetupDevices()
{
	DCB *p;
	int n;

  for (n = 0; n < 32; n++) {
    FMTK_AllocMbx(&hDevMailbox[n*2]);
    FMTK_AllocMbx(&hDevMailbox[n*2+1]);
    p = &DeviceTable[n];
    p->hMbxSend = hDevMailbox[n*2];
    p->hMbxRcv = hDevMailbox[n*2+1];
  }

	p = &DeviceTable[0];
	memset(p, 0, sizeof(DCB) * NR_DCB);

	strncpy(p->name,"\x04NULL",12);
	p->type = DVT_Unit;
	p->UnitSize = 0;
	p->cmdproc = null_cmdproc;
	
	p = &DeviceTable[1];
	strncpy(p->name,"\x03KBD",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;
	p->cmdproc = keybd_cmdproc;

	p = &DeviceTable[2];
	strncpy(p->name,"\x07TEXTVID",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;
	p->cmdproc = textvid_cmdproc;

	p = &DeviceTable[5];
	strncpy(p->name,"\x04COM1",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;
	p->cmdproc = serial_cmdproc;

	p = &DeviceTable[6];
	strncpy(p->name,"\x08FRAMEBUF",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;
	p->cmdproc = framebuf_cmdproc;

	p = &DeviceTable[7];
	strncpy(p->name,"\x08GFXACCEL",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;
	p->cmdproc = gfxaccel_cmdproc;

	p = &DeviceTable[9];
	strncpy(p->name,"\x03PTI",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;

	p = &DeviceTable[16];
	strncpy(p->name,"\x05CARD1",12);
	p->type = DVT_Block;
	p->UnitSize = 1;

	p = &DeviceTable[29];
	strncpy(p->name,"\x03CON",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;

	p = &DeviceTable[30];
	strncpy(p->name,"\x04PRNG",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;

	p = &DeviceTable[31];
	strncpy(p->name,"\x03DBG",12);
	p->type = DVT_Unit;
	p->UnitSize = 1;

}
