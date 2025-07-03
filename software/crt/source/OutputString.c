extern void OutputChar(char ch);

void OutputString(char* str)
{
	while (*str) {
		OutputChar(*str);
		str++;
	}
}

