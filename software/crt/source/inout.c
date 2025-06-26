
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

