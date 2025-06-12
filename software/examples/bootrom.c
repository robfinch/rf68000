#include "gfx.h"

#define SYS_FREQ	50e6

#define I2C1 0xFD069000
#define I2C2 0xFD069010
#define I2C_PREL 0
#define I2C_PREH 1
#define I2C_CTRL 2
#define I2C_RXR 3
#define I2C_TXR 3
#define I2C_CMD 4
#define I2C_STAT 4

#define RAND 0xFD0FFD10
#define RAND_NUM	0
#define RAND_STRM	1
#define RAND_MZ		2
#define RAND_MW		3

extern char OutputDevice;
extern void OutputChar(int ch);
extern int coreno;
extern void CheckForCtrlC();

static char RTCBuf[96];

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

int get_rand(int* p)
{
	int r;
	
	r = p[RAND_NUM];
	p[RAND_NUM] = r;
	return (r);
}

// Get a random float number between 0 and 1.0.

double get_rand_float(int* p)
{
	int r;
	double d;
	
	r = p[RAND_NUM];
	p[RAND_NUM] = r;
	d = (r >> 1);
	d /= 2147483648.0;
	return (d);
}

void OutputString(char* str)
{
	while (*str) {
		OutputChar(*str);
		str++;
	}
}

void bootrom()
{
	int x0i, y0i, x1i, y1i;
	int nn;
	int color;
	double width = 800.0;
	double height = 600.0;
	
	OutputDevice = 2;
	OutputString("Booting \r\n");
	i2c_init(I2C1);
	i2c_init(I2C2);
	rand_init(RAND);

	gfx_set_color_depth(10);
	// Erase screen
	gfx_set_color(0);
	gfx_rect(0,0,800<<16,600<<16);
	// Draw random points
	for (nn = 0; nn < 20000; nn++) {
		x0i = (get_rand_float(RAND) * width);
		y0i = (get_rand_float(RAND) * height);
		x0i <<= 16;
		y0i <<= 16;
		color = get_rand(RAND);
		gfx_set_pixel(x0i,y0i,color);
	}
	// Draw random lines
	for (nn = 0; nn < 20000; nn++) {
		x0i = (get_rand_float(RAND) * width);
		y0i = (get_rand_float(RAND) * height);
		x1i = (get_rand_float(RAND) * width);
		y1i = (get_rand_float(RAND) * height);
		x0i <<= 16;
		y0i <<= 16;
		x1i <<= 16;
		y1i <<= 16;
		color = get_rand(RAND);
		gfx_set_color(color);
		gfx_line(x0i,y0i,x1i,y1i);
	}
}
