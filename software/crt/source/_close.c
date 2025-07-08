extern long _io_close(long fh);

long _close(long fh)
{
	return (_io_close(fh));
}
