#include <stdio.h>
#include "..\..\Femtiki\source\inc\proto.h"

extern long InputDevice;
extern long OutputDevice;
extern long StartMon();

int _crt_start()
{
	DisplayLEDS(0x30);
	InputDevice = 0x10000;
	OutputDevice = 0x20000;
	DisplayLEDS(0x31);
//	FMTK_Initialize();
	DisplayLEDS(0x32);
	stdin = fopen("/rom/dev/keybd","r");
	stdout = fopen("/rom/dev/textvid", "r+");
	stderr = fopen("/rom/dev/err", "w");
	DisplayLEDS(0x33);
	return (StartMon());
}
