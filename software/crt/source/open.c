#include <string.h>
#include "..\..\femtiki\source\inc\config.h"
#include "..\..\femtiki\source\inc\device.h"

extern DCB DeviceTable[NR_DCB];

static char *devs[] =
{
	"/rom/dev/null",
	"/rom/dev/keybd",
	"/rom/dev/textvid",
	"/rom/dev/err",
	"/rom/dev/unknown",
	"/rom/dev/com1",
	"/rom/dev/framebuf",
	"/rom/dev/gfxaccel",
	"/rom/dev/clock",
	"/rom/dev/random"
};

extern long _io_open(__reg("d7") long fh);

int open(char *path, int flags, int mode)
{
	int nn;
	
	if (strncmp(path,"/rom/dev/",9)!=0)
		return (-1);
	for (nn = 0; nn < NR_DCB; nn++) {
		if (stricmp(&path[9],DeviceTable[nn].name)==0) {
			return (_io_open(nn << 16));
		}
	}
	return (-1);
}
