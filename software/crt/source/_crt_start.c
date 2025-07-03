#include <stdio.h>

extern long StartMon();

int _crt_start()
{
	stdin = fopen("/rom/dev/keybd","r");
	stdout = fopen("/rom/dev/textvid", "r+");
	stderr = fopen("/rom/dev/err", "w");
	return (StartMon());
}
