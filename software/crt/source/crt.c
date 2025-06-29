int _close(int fh)
{
	return (0);
}

static unsigned long rbo32(unsigned long val)
{
	return (val >> 24) | ((val & 0xff0000) >> 8) | ((val & 0xff00) << 8) | ((val & 0xff) << 24);
}

void out32(long* port, long val)
{
	*port = val;
}

void out32rbo(long* port, long val)
{
	*port = rbo32(val);
}


long lseek(int fh, long offs, int wh)
{
	return (offs);
}#include <string.h>

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


void putnum(long num, int dig, char sep, char pad)
{
	char buf[50];
	int n;

	for (n = 0; num; num /= 10) {
		if ((n % 3)==0 && n > 0) {
			buf[n] = sep;
			n++;
		}
		buf[n] = (num % 10) + '0';
		n++;
	}

	// Trim leading zeros
	for (--n; n > 0; ) {
		if (buf[n]=='0') {
			buf[n] = '\0';
			n--;
			if (buf[n]==sep) {
				buf[n] = '\0';
				n--;
			}
		}
		else 
			break;
	}
	
	// The number is in the buffer in the reverse order.
	if (dig > 0) {				// Right justify number
		dig = dig - n;
		while (dig > 0) {
			buf[n] = pad;
			n++;
			dig--;
		}
		buf[n] = '\0';
	}
	else if (dig < 0) {		// Left justify number
		dig = -dig;
		dig - n;
		if (dig > 0) {
			for (; n > 0; n--) {
				buf[n+dig] = buf[n];
			}
			for (; dig > 0; dig--)
				buf[dig] = pad;
		}
	}
	
	// Now the number is padded and in reverse order
	// Move to the end of the buffer.
	for (n = 0; buf[n]; n++)
		;
	// Spit out characters
	for ( --n; n >= 0; n--)
		OutputChar(buf[n]);
}
