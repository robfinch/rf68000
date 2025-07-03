#include <stdio.h>
#include <string.h>
#include "..\inc\types.h"
#include "..\inc\proto.h"

// The text screen memory can only handle half-word transfers, hence the use
// of memsetH, memcpyH.
//#define DBGScreen	(__int32 *)0xFFD00000
#define TEXTVIDEO_REG	((unsigned long*)0xFD080000)
#define DBGScreen	((unsigned long*)0xFD000000)
#define DBGCOLS		64
#define DBGROWS		32

extern int IOFocusNdx;
extern char DBGCursorCol;
extern char DBGCursorRow;
extern int DBGAttr;
extern void DispChar(register char ch);
extern void puthexnum(int num, int wid, int ul, char padchar);
extern void out32(unsigned long* port, unsigned long val);
extern unsigned long rbo(unsigned long);
/*
unsigned long rbo(unsigned long i)
{
	long o;
	
	o = (i >> 24) | ((i & 0xff0000) >> 8) | ((i & 0xff00) << 8) | ((i & 0xff) << 24);
	return (o);
}
*/

unsigned long *GetScreenLocation()
{
  return GetACBPtr(1)->pVidMem;
}

unsigned long GetCurrAttr()
{
  return GetACBPtr(1)->NormAttr;
}

void SetCurrAttr(unsigned long attr)
{
   GetACBPtr(1)->NormAttr = attr & 0xFFFF0000;
}

static void SetVideoReg(int regno, unsigned long val)
{
	if (regno < 0 || regno > 4) {
		printf("bad video regno: %d", regno);
		return;
	}
	TEXTVIDEO_REG[regno] = rbo(val);
}

void UpdateCursorPos()
{
	ACB *j;
	int pos;

	j = GetACBPtr(1);
//    if (j == IOFocusNdx) {
  pos = (j->CursorRow * j->VideoCols + j->CursorCol) +
  	(get_coreno() * j->VideoCols * j->VideoRows);
	SetVideoReg(11,pos);
//    }
}

void SetCursorPos(int row, int col)
{
	ACB *j;

	j = GetACBPtr(1);
	j->CursorCol = col;
	j->CursorRow = row;
	UpdateCursorPos();
}

void SetCursorCol(int col)
{
	ACB *j;

	j = GetACBPtr(1);
	j->CursorCol = col;
	UpdateCursorPos();
}

int GetCursorPos()
{
	ACB *j;

	j = GetACBPtr(1);
	return j->CursorCol | (j->CursorRow << 8);
}

int GetTextCols()
{
	return GetACBPtr(1)->VideoCols;
}

int GetTextRows()
{
	return GetACBPtr(1)->VideoRows;
}

void HomeCursor()
{
	ACB *j;

	j = GetACBPtr(1);
	j->CursorCol = 0;
	j->CursorRow = 0;
	UpdateCursorPos();
}

unsigned long* CalcScreenLocation()
{
  ACB *j;
  int pos;

  j = GetACBPtr(1);
  pos = (j->CursorRow * j->VideoCols + j->CursorCol) +
  	(get_coreno() * j->VideoCols * j->VideoRows);
//    if (j == IOFocusNdx) {
     SetVideoReg(11,pos);
//    }
  return GetScreenLocation()+pos;
}

unsigned long AsciiToScreen(unsigned long ch)
{
	return (ch);
}

void ClearScreen()
{
	unsigned long* p;
	int nn;
	int mx;
	ACB *j;
	int vc;

	j = GetACBPtr(1);
	p = GetScreenLocation();
	// Compiler did a byte multiply generating a single byte result first
	// before assigning it to mx. The (int) casts force the compiler to use
	// an int result.
	mx = (int)j->VideoRows * (int)j->VideoCols;
	vc = rbo(GetCurrAttr() | ' ');
	memsetT(p, vc, mx);
}

void ClearBmpScreen()
{
   memsetT(0x40000000, 0, 0x400000);
}

void BlankLine(int row)
{
	unsigned long* p;
	int nn;
	int mx;
	ACB *j;
	int vc;

	j = GetACBPtr(1);
	p = GetScreenLocation();
	p = p + (int)j->VideoCols * row;
	vc = GetCurrAttr() | ' ';
	vc = rbo(vc);
	memsetT(p, vc, j->VideoCols);
}

void VBScrollUp()
{
	unsigned long* scrn = GetScreenLocation();
	int nn;
	int count;
  ACB *j;

  j = GetACBPtr(1);
	count = (int)j->VideoCols*(int)(j->VideoRows-1);
	for (nn = 0; nn < count; nn++)
		scrn[nn] = scrn[nn+(int)j->VideoCols];

	BlankLine(GetTextRows()-1);
}

void IncrementCursorRow()
{
	ACB *j;

	j = GetACBPtr(1);
	j->CursorRow++;
	if (j->CursorRow < j->VideoRows) {
		UpdateCursorPos();
		return;
	}
	j->CursorRow--;
	UpdateCursorPos();
	VBScrollUp();
}

void IncrementCursorPos()
{
	ACB *j;

	j = GetACBPtr(1);
	j->CursorCol++;
	if (j->CursorCol < j->VideoCols) {
		UpdateCursorPos();
		return;
	}
	j->CursorCol = 0;
	IncrementCursorRow();
}

void DisplayChar(char ch)
{
   unsigned long* p;
   int nn;
   ACB *j;

   j = GetACBPtr(1);
   switch(ch) {
   case '\r':  j->CursorCol = 0; UpdateCursorPos(); break;
   case '\n':  IncrementCursorRow(); break;
   case 0x91:
      if (j->CursorCol < j->VideoCols-1) {
         j->CursorCol++;
         UpdateCursorPos();
      }
      break;
   case 0x90:
      if (j->CursorRow > 0) {
           j->CursorRow--;
           UpdateCursorPos();
      }
      break;
   case 0x93:
      if (j->CursorCol > 0) {
           j->CursorCol--;
           UpdateCursorPos();
      }
      break;
   case 0x92:
      if (j->CursorRow < j->VideoRows-1) {
         j->CursorRow++;
         UpdateCursorPos();
      }
      break;
   case 0x94:
      if (j->CursorCol==0)
         j->CursorRow = 0;
      j->CursorCol = 0;
      UpdateCursorPos();
      break;
   case 0x99:  // delete
      p = CalcScreenLocation();
      for (nn = j->CursorCol; nn < j->VideoCols-1; nn++) {
          p[nn-j->CursorCol] = p[nn+1-j->CursorCol];
      }
      p[nn-j->CursorCol] = GetCurrAttr() | AsciiToScreen(' ');
      break;
   case 0x08: // backspace
      if (j->CursorCol > 0) {
        j->CursorCol--;
        p = CalcScreenLocation();
        for (nn = j->CursorCol; nn < j->VideoCols-1; nn++) {
            p[nn-j->CursorCol] = p[nn+1-j->CursorCol];
        }
        p[nn-j->CursorCol] = GetCurrAttr() | AsciiToScreen(' ');
      }
      break;
   case 0x0C:   // CTRL-L
      ClearScreen();
      HomeCursor();
      break;
   case '\t':
      DisplayChar(' ');
      DisplayChar(' ');
      DisplayChar(' ');
      DisplayChar(' ');
      break;
   default:
      p = CalcScreenLocation();
      *p = GetCurrAttr() | AsciiToScreen(ch);
      IncrementCursorPos();
      break;
   }
}

void CRLF()
{
	DisplayChar('\r');
	DisplayChar('\n');
}

void DisplayString(char *s)
{
	char ch;
	while (ch = *s) { DisplayChar(ch); s++; }
}

void DisplayStringCRLF(char *s)
{
	DisplayString(s);
	CRLF();
}

