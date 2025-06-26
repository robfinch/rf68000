#include <string.h>

static char *devs[] =
{
	"/rom/null",
	"/rom/keybd",
	"/rom/textvid"
};

int open(char *path, int flags, int mode)
{
	int nn;
	
	for (nn = 0; nn < 3; nn = nn + 1) {
		if (stricmp(path,devs[nn])==0)
			return (nn);
	}
	return (-1);
}

