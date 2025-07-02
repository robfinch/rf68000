#include "gfx.h"

#define SYS_FREQ	50e6

#define I2C1 0xFD250000
#define I2C2 0xFDFE4000
#define I2C_PREL 0
#define I2C_PREH 1
#define I2C_CTRL 2
#define I2C_RXR 3
#define I2C_TXR 3
#define I2C_CMD 4
#define I2C_STAT 4

#define RAND 0xFDFF4010
#define RAND_NUM	0
#define RAND_STRM	1
#define RAND_MZ		2
#define RAND_MW		3

typedef struct _tagdecflt
{
	int w[3];
} decflt_t;

int shell();
extern int GetCharNonBlocking();
extern void clear(unsigned int dev);
extern void set_color_depth(unsigned int dev, unsigned int tot, unsigned int red, unsigned int green, unsigned int blue);
extern void set_color(unsigned int dev, unsigned int color);
extern void dispbuf(unsigned int dev, unsigned int adr);
extern void drawbuf(unsigned int dev, unsigned int adr);
extern void plot_point(unsigned int dev, unsigned int x, unsigned int y, unsigned int color);
extern void draw_line(unsigned int dev, unsigned int x0, unsigned int y0, unsigned int x1, unsigned int y1, unsigned int color);
extern double CvtStringToDecflt(char* s);
extern void DumpStack();
extern long OutputDevice;
extern long InputDevice;
extern void OutputChar(int ch);
extern void OutputString(char *str);
extern void OutputCRLF();
extern void OutputFloat(double);
extern void OutputNumber(int num, int sz);
extern void OutputTetra(unsigned int);
extern void OutputWyde(unsigned int);
extern int coreno;
extern int CheckForCtrlC();
extern int GetChar();
extern int get_char(int dev);
extern int put_char(int dev, int ch);
extern int get_output_pos(int dev, int*x, int*y, int*z);
extern int set_input_pos(int dev, int x, int y, int z);

static char RTCBuf[96];

void bootrom()
{
	InputDevice = 0x10000;
	OutputDevice = 0x20000;
	OutputString("Bootrom\r\n");
	shell();
}

int i2c_init(char* i2c)
{
	i2c[I2C_CTRL] = 0;				// disable I2C
	i2c[I2C_PREL] = 24;				// 49 for 100 MHz clock, 24 for 50 MHz (400 kHz desired)
	i2c[I2C_PREH] = 0;
	return (0);
}

int i2c_enable(char* i2c)
{
	i2c[I2C_CTRL] = 0x80;
	return (0);
}

int i2c_disable(char* i2c)
{
	i2c[I2C_CTRL] = 0x00;
	return (0);
}

// Wait for tip to clear
int i2c_wait_tip(volatile char* i2c)
{
	do {
		;//CheckForCtrlC();
	} while (i2c[I2C_STAT] & 0x02);
	return (0);
}

int i2c_get_status(volatile char* i2c)
{
	return (i2c[I2C_STAT]);
}

int i2c_cmd_read_with_stop(volatile char* i2c)
{
	i2c[I2C_CMD] = 0x68;		// rd bit, STO + nack
	i2c_wait_tip(i2c);
	return (i2c_get_status(i2c));
}

int i2c_cmd_read_with_ack(volatile char* i2c)
{
	i2c[I2C_CMD] = 0x20;
	i2c_wait_tip(i2c);
	return (i2c_get_status(i2c));
}

int i2c_read_byte(volatile char* i2c)
{
	return (i2c[I2C_RXR]);
}

// Parameters
//		a6	 - I2C controller base address
//		d0.b - data to transmit
//		d1.b - command value
// Returns:
//		d0.b - I2C status

int i2c_cmd(volatile char* i2c, int cmd, int data)
{
	i2c[I2C_TXR] = data;
	i2c[I2C_CMD] = cmd;
	i2c_wait_tip(i2c);
	return (i2c_get_status(i2c));
}

/*
i2c_xmit1:
	move.l d0,-(a7)
	move.b #1,I2C_CTRL(a6)		; enable the core
	moveq	#$76,d0				; set slave address = %0111011
	move.w #$90,d1				; set STA, WR
	bsr i2c_wr_cmd
	bsr	i2c_wait_rx_nack
	move.l (a7)+,d0
	move.w #$50,d1				; set STO, WR
	bsr i2c_wr_cmd
	bsr	i2c_wait_rx_nack

i2c_wait_rx_nack:
.0001						
	bsr CheckForCtrlC
	btst #7,I2C_STAT(a6)		; wait for RXack = 0
	bne.s	.0001
	rts
*/
int i2c_read(volatile char* i2c, int i2c_adr, int addr, char* buf, int len)
{
	int ndx = 0;

	i2c_enable(i2c);
  i2c_cmd(i2c,0x90,i2c_adr << 1);	// STA + wr address $6F, write	
  i2c_cmd(i2c,0x10,addr);								// wr address, write	
  i2c_cmd(i2c,0x90,(i2c_adr << 1) | 1);	// STA + wr address $6F, read
  for (ndx = 0; len > 1; len--, addr++, ndx++) {
  	i2c_cmd_read_with_ack(i2c);
	  buf[ndx] = i2c_read(i2c);
	}
	i2c_cmd_read_with_stop(i2c);
  buf[ndx] = i2c_read(i2c);
	i2c_disable(i2c);
}

int i2c_write(volatile char* i2c, int i2c_adr, int addr, char* buf, int len)
{
	int ndx = 0;

	i2c_enable(i2c);
  i2c_cmd(i2c,0x90,i2c_adr << 1);	// STA + wr address $6F, write	
  i2c_cmd(i2c,0x10,addr);								// wr address, write	
  for (ndx = 0; len > 1; len--, addr++, ndx++) {
  	i2c_cmd(i2c, 0x10, buf[ndx]);
	}
 	i2c_cmd(i2c, 0x50, buf[ndx]);
	i2c_disable(i2c);
}

//===============================================================================
// Realtime clock routines
//===============================================================================

int rtc_read()
{
	i2c_read(I2C2, 0x6F, 0, RTCBuf, 96);
}

int rtc_write()
{
	i2c_write(I2C2, 0x6F, 0, RTCBuf, 96);
}

//===============================================================================
//===============================================================================

void rand_init(int* p)
{
	p[RAND_STRM] = 0;
	p[RAND_MZ] = 0x12345678;
	p[RAND_MW] = 0x88888888;
	p[RAND_NUM] = 0x12345678;	
}

int get_rand(int* p, int max)
{
	int r,s;
	int cnt;
	
	r = p[RAND_NUM];
	p[RAND_NUM] = r;
	if (max==-1)
		return (r);
	for (s = cnt = 0; cnt < 16; cnt++) {
		if (r & 1)
			s = s + max;
		r >>= 1;
		max <<= 1;
	}
	return (s>>16);
}

// Get a random float number between 0 and 1.0.

double get_rand_float(int* p)
{
	unsigned int r;
	double d;
	static int first = 1;
	static double divisor;
	
	if (first) {
		first = 0;
		divisor = CvtStringToDecflt("2147483648.0");
		OutputFloat(divisor);
		OutputCRLF();
		GetChar();
	}
	r = p[RAND_NUM];
	p[RAND_NUM] = r;
	d = (r >> 1);
	d /= divisor;
	OutputFloat(d);
	OutputCRLF();
	return (d);
}

void OutputString(char* str)
{
	while (*str) {
		OutputChar(*str);
		str++;
	}
}

void DisplayAddress(unsigned long addr)
{
	OutputWyde(addr >> 20);
	OutputChar('\r');
}

void log_ramtest_err(unsigned long addr, unsigned long val)
{
	OutputTetra(addr);
	OutputChar(' ');
	OutputTetra(val);
	OutputChar('\r');
	OutputChar('\n');
}

void ramtest1(unsigned long val1, unsigned long val2)
{
	unsigned long* pRAM = (unsigned long*)0x40000000;
	
	while (pRAM < (unsigned long*)0x7FFFFFC0) {
		if (((unsigned long)pRAM & 0xffff)==0)	
			DisplayAddress((unsigned long)pRAM);
		pRAM[0] = val1;
		pRAM[1] = val2;
		pRAM += 2;
	}
}

void ramtest2(unsigned long val1, unsigned long val2)
{
	unsigned long* pRAM = (unsigned long*)0x40000000;
	
	while (pRAM < (unsigned long*)0x7FFFFFC0) {
		if (((unsigned long)pRAM & 0xffff)==0)	
			DisplayAddress((unsigned long)pRAM);
		if (pRAM[0] != val1)
			log_ramtest_err((unsigned long)&pRAM[0], pRAM[0]);
		if (pRAM[1] != val1)
			log_ramtest_err((unsigned long)&pRAM[1], pRAM[1]);
		pRAM += 2;
	}
}

// Double checkboard RAM test.
void cmdTestRAM()
{
	OutputString("Running RAM test\r\n");
	ramtest1(0xAAAAAAAA,0x55555555);
	ramtest2(0xAAAAAAAA,0x55555555);
	ramtest1(0x55555555,0xAAAAAAAA);
	ramtest2(0x55555555,0xAAAAAAAA);
}

void cmdGrTest()
{
	unsigned int x0i, y0i, x1i, y1i;
	int nn;
	int color;
	int width = 1024;
	int height = 768;
	unsigned int buf = 0;
	
	OutputDevice = 2;
	OutputString("Booting \r\n");
//	i2c_init(I2C1);
//	i2c_init(I2C2);
	rand_init(RAND);

	set_color_depth(0x70000,16,5,5,5);
	set_color_depth(0x60000,16,5,5,5);

	dispbuf(0x60000,buf);
	drawbuf(0x70000,buf);

	// Erase screen
	set_color(0x70000,0x0000007F);	// medium blue
	clear(0x70000);

	// Draw random points
	for (nn = 0; nn < 50000; nn++) {
		dispbuf(0x60000,buf);
		drawbuf(0x70000,buf);
		x0i = get_rand(RAND, -1) & 0x3ffffff;
		y0i = (get_rand(RAND, -1) & 0x1ffffff) + (get_rand(RAND, -1) & 0xffffff);
		color = get_rand(RAND,-1);
		plot_point(0x70000, x0i, y0i, color);
	}
	OutputString("Drew Points \r\n");
	// Draw random lines
	for (nn = 0; nn < 20000; nn++) {
		dispbuf(0x60000,buf);
		drawbuf(0x70000,buf);
		x0i = get_rand(RAND, -1) & 0x3ffffff;
		y0i = (get_rand(RAND, -1) & 0x1ffffff) + (get_rand(RAND, -1) & 0xffffff);
		x1i = get_rand(RAND, -1) & 0x3ffffff;
		y1i = (get_rand(RAND, -1) & 0x1ffffff) + (get_rand(RAND, -1) & 0xffffff);
		color = get_rand(RAND,-1);
		draw_line(0x70000,x0i,y0i,x1i,y1i,color);
	}
	OutputString("Drew Lines \r\n");
	OutputString("Demo Finished \r\n");
}

char cmdTable[] =
{
	'J'+0x80,
	'G','R'+0x80,
	'T','R','A','M'+0x80,
	0,0
}

int asciiToHexNybble(int ch)
{
	if (ch >= '0' && ch <= '9')	
		return (ch-'0');
	if (ch >= 'a' && ch <= 'f')
		return (ch-'a' + 10);
	if (ch >= 'A' && ch <= 'F')
		return (ch-'A' + 10);
	return (0);
}

int isHexDigit(int ch)
{
	if (ch >= '0' && ch <= '9')
		return (1);
	if (ch >= 'a' && ch <= 'f')
		return (1);
	if (ch >= 'A' && ch <= 'F')
		return (1);
	return (0);
}

int GetHexNumber(unsigned int* num)
{
	unsigned int n;
	unsigned int dc;
	int ch;

	do {
		ch = get_char(0x20000);
	} while (ch==' ');
	if (!isHexDigit(ch))
		return (0);
	n = 0;
	dc = 0;
	do {
		n << 4;
		n = n | asciiToHexNybble(ch);
		ch = get_char(0x20000);
		dc++;
	} while (isHexDigit(ch));
	if (num)
		*num = n;
	return (dc);
}

int cmdJump()
{
	int (*addr)();
	
	if (GetHexNumber((unsigned int*)&addr))
		return ((*addr)());
	return (0);
}

int (*shell_cmd[])() = {
	cmdJump,
	cmdGrTest,
	cmdTestRAM
}

void prompt()
{
	OutputString("\r\n$");
}

int shell()
{
	int ch, posx,posy,posz;
	int n, cmd_num;
	long fh = 0x20000;

/*	set_sp(0x47FF0); */
	OutputString("Monitor v0.1 \r\n\r\n");
	while(1) {
/*		set_sp(0x47FF0); */
		prompt();
		do {
			// Grab a character from the keyboard
			ch = get_char(0x10000);
			// Echo back out to display
			if (ch > 0)
				put_char(fh,ch);
		} while (ch != 13);
		get_output_pos(fh,&posx,&posy,&posz);
		// Go to start of line
		set_input_pos(fh,0,posy,posz);

		cmd_num = 0;
		// Skip prompt character
		do {
			ch = get_char(fh);
		} while (ch == '$');
		// Skip leading blanks
		while (ch == ' ')
			ch = get_char(fh);
		// Remember start position
		get_input_pos(fh,&posx,&posy,&posz);
		if (posx > 0) {
			posx--;
			set_input_pos(fh,posx,posy,posz);
		}
		while (1) {
			ch = get_char(fh);
			if (ch != cmdTable[n]) {
				if (((cmdTable[n] & 0x80)==0x80) && (ch == (cmdTable[n] & 0x7f))) {
					shell_cmd[cmd_num]();
					break;
				}
				// Scan to end of command
				while((cmdTable[n] & 0x80)==0)
					n++;
				n++;
				// Reached end of table?
				if (cmdTable[n]==0) {
					OutputString("??\r\n");
					break;
				}
				// Reset input position for next compare
				set_input_pos(fh,posx,posy,posz);
				cmd_num++;
			}
			else {
				n++;
			}
		}
	}
	return (0);
}
