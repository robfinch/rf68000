#include <string.h>

static char *devs[] =
{
	"/rom/dev/null",
	"/rom/dev/keybd",
	"/rom/dev/textvid"
};

extern long _io_open(__reg("d7") long fh);

int open(char *path, int flags, int mode)
{
	int nn;
	
	if (strncmp(path,"/rom/dev/",9)!=0)
		return (-1);
	for (nn = 0; nn < NR_DCB; nn++) {
		if (stricmp(&path[9],DeviceTable[nn]->name)==0) {
			return (_io_open(nn << 16));
		}
	}
	return (-1);
}
