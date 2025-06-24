#include "inc/config.h"
#include "inc/const.h"
//#include "../inc/errno.h"
#include "inc/types.h"
#include "inc/proto.h"

// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
#define NPAGES	65536-2048		// 2048 OS pages
#define CARD_MEMORY		0xFFCE0000
#define IPT_MMU				0xFFDCD000
#define IPT
#define MMU	0xFDC00000

#define NULL    (void *)0

extern char *os_brk;

extern unsigned int lastSearchedPAMWord;
extern int errno;
extern char *osmem;
extern int highest_data_word;
extern short int mmu_freelist;		// head of list of free pages
extern int syspages;
extern int sys_pages_available;
extern int mmu_FreeMaps;
extern int mmu_key;
extern char hSearchMap;
extern MEMORY memoryList[NR_MEMORY];
extern int RTCBuf[12];
void puthexnum(int num, int wid, int ul, char padchar);
void putnum(int num, int wid, int sepchar, int padchar);
extern void DBGHideCursor(int hide);
extern void* memsetT(void* ptr, long c, size_t n);
extern char* FindFreePage();
extern PTE* GetPageTableEntryAddress(unsigned long virtadr);
void *pt_alloc(int amt, int acr);

//unsigned __int32 *mmu_entries;
extern unsigned long PAM[(NPAGES+1)/32];
extern PMTE PageManagementTable[NPAGES];
extern unsigned long* page_table;
extern char *brks[512];
extern unsigned long pebble[512];

void ramtest1(int aa, int bb)
{
	int *p;
	int errcount;
	
	errcount = 0;
	DBGHideCursor(1);
	DBGDisplayStringCRLF("Writing code to ram");
	for (p = 0; (unsigned long)p < 1073741824; p += 2) {
		if (((long)p & 0xfffff)==0) {
			putnum((unsigned long)p>>20,5,',',' ');
			DBGDisplayChar('M');
			DBGDisplayChar('B');
			DBGDisplayChar('\r');
		}
		p[0] = aa;
		p[1] = bb;
	}
	DBGDisplayStringCRLF("\r\nReadback 5A code from ram");
	for (p = 0; (unsigned long)p < 1073741824; p += 2) {
		if (((long)p & 0xfffff)==0) {
			putnum((unsigned long)p>>20,5,',',' ');
			DBGDisplayChar('M');
			DBGDisplayChar('B');
			DBGDisplayChar('\r');
		}
		if (p[0] != aa || p[1] != bb) {
			errcount++;
			if (errcount > 10)
				break;
		}
	}
	DBGDisplayString("\r\nerrors: ");
	putnum(errcount,5,',',' ');
}

// Checkerboard ram test routine.

void ramtest()
{
	ramtest1(0x55555555L, 0xaaaaaaaaL);	
	ramtest1(0xaaaaaaaaL, 0x55555555L);	
	DBGDisplayChar('\r');
	DBGDisplayChar('\n');
	DBGHideCursor(0);
}


//private __int16 pam[NPAGES];	
// There are 128, 4MB pages in the system. Each 4MB page is composed of 64 64kb pages.
//private int pam4mb[NPAGES/64];	// 4MB page allocation map (bit for each 64k page)
//int syspages;					// number of pages reserved at the start for the system
//int sys_pages_available;	// number of available pages in the system
//int sys_4mbpages_available;

static unsigned int round16k(register unsigned int amt)
{
  amt += 16383;
  amt &= 0xFFFFFFFFFFFFC000L;
  return (amt);
}

// ----------------------------------------------------------------------------
// Must be called to initialize the memory system before any
// other calls to the memory system are made.
// Initialization includes setting up the linked list of free pages and
// setting up the 512k page bitmap.
// ----------------------------------------------------------------------------

void init_memory_management()
{
	ACB* pACB;

	// System break positions.
	// All breaks start out at address 16777216. Addresses before this are
	// reserved for the video frame buffer. This also allows a failed
	// allocation to return 0.
	DBGDisplayChar('A');
	sys_pages_available = NPAGES;
	lastSearchedPAMWord = PAM;
  
  // Allocate 16MB to the OS, 8MB OS, 8MB video frame buffer
  osmem = (char *)pt_alloc(16777216,7);
  // Allocate video frame buffer
  pACB = GetRunningACBPtr();
//  pACB-> = pt_alloc(8388607,7);
	DBGDisplayChar('a');
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

unsigned long* GetPageTableAddr(char* vadr)
{
//	GetPageTableAddress(vadr);
	return (0);
}

// ----------------------------------------------------------------------------
// Alloc enough pages to fill the requested amount.
// ----------------------------------------------------------------------------

void *pt_alloc(int amt, int acr)
{
	char *p;
	int npages;
	int nn;
	char* page;
	unsigned long* pe;
	unsigned long en;
	TCB* ptcb;

	p = (char *)-1;
	DBGDisplayChar('B');
	amt = round16k(amt);
	npages = amt >> 14;
	if (npages==0)
		return (p);
	DBGDisplayChar('C');
	if (npages < sys_pages_available) {
		sys_pages_available -= npages;
		ptcb = GetRunningTCBPointer();
		p = ptcb[230];
		ptcb[230] += amt;
		for (nn = 0; nn < npages-1; nn++) {
			page = FindFreePage();
			pe = GetPageTableEntryAddress(page+(nn << 14));
			en = (acr << 13) | ((page >> 14) & 0x1fff) | 0x80000000;
			*pe = en;
		}
		page = FindFreePage();
		pe = GetPageTableEntryAddress(page+(nn << 14));
		en = (acr << 13) | ((page >> 14) & 0x1fff) | 0x80200000;
		*pe = en;
	}
//	p |= (asid << 52);
	DBGDisplayChar('E');
	return (p);
}


// ----------------------------------------------------------------------------
// pt_free() frees up 16kB blocks previously allocated with pt_alloc(), but does
// not reset the virtual address pointer. The freed blocks will be available for
// allocation. With a 64-bit pointer the virtual address can keep increasing with
// new allocations even after memory is freed.
//
// Parameters:
//		vadr - virtual address of memory to free
// ----------------------------------------------------------------------------

byte *pt_free(byte *vadr)
{
	int n;
	int count;	// prevent looping forever
	int vpageno;
	int last_page;
	PTE* pe;
	PTE pte;

	count = 0;
	do {
		vpageno = (vadr >> 14) & 0xffff;
		while (LockMMUSemaphore(-1)==0);
		pe = (PTE*)GetPageTableEntryAddress(vadr);
		pte = *pe;
		last_page = (pte >> 22) & 1;
		while (LockPMTSemaphore(-1)==0);
		if (PageManagementTable[vpageno].share_count != 0) {
			PageManagementTable[vpageno].share_count--;
			if (PageManagementTable[vpageno].share_count==0) {
				pte = 0;
				*pe = pte;
			}
		}
		UnlockPMTSemaphore();
		UnlockMMUSemaphore();
		if (last_page)
			break;
		vadr += 16384;
		count++;
	}
	while (count < NPAGES);
	return (vadr);
}

// Returns:
//	-1 on error, otherwise previous program break.
//
void *sbrk(int size)
{
	char *p, *q, *r;
	unsigned __int32 pte;
	unsigned __int32* ptcb;
	unsigned __int32* pe;

	p = 0;
	ptcb = GetRunningTCBPointer();
	size = round16k(size);
	if (size > 0) {
		p = pt_alloc(size,7);
		if (p==-1)
			errno = E_NoMem;
		return (p);
	}
	else if (size < 0) {
		size = -size;
		if (size > ptcb[230]) {
			errno = E_NoMem;
			return (-1);
		}
		r = p = ptcb[230] - size;
		for(q = p; q < ptcb[230];)
			q = pt_free(q);
		ptcb[230] = r;
		// Mark the last page
		if (r > 0) {
			while (LockMMUSemaphore(-1)==0);
			pe = GetPageTableEntryAddress(r);
			pte = *pe;
			pte &= 0xfcffffff;
			pte |= 0x00200000;
			*pe = pte;
			UnlockMMUSemaphore();
		}
	}
	else {	// size==0
		p = ptcb[230];
	}
	return (p);
}
extern memsetW(int *, int, int);

// The text screen memory can only handle half-word transfers, hence the use
// of memsetH, memcpyH.
//#define DBGScreen	(__int32 *)0xFFD00000
#define TEXTVIDEO_REG	(unsigned long*)0xFD080000
#define DBGScreen	(unsigned long*)0xFD000000
#define DBGCOLS		64
#define DBGROWS		32

extern int IOFocusNdx;
extern __int8 DBGCursorCol;
extern __int8 DBGCursorRow;
extern int DBGAttr;
extern void DispChar(register char ch);
extern void puthexnum(int num, int wid, int ul, char padchar);
extern void out64(int port, int val);
extern int get_coreno();

unsigned long rbo(unsigned long i)
{
	long o;
	
	o = (i >> 24) | ((i & 0xff0000) >> 8) | ((i & 0xff00) << 8) | ((i & 0xff) << 24);
	return (o);
}

void DBGClearScreen()
{
	unsigned long *p;
	unsigned long vc;

	p = DBGScreen + get_coreno() * DBGCOLS * DBGROWS;
	//vc = AsciiToScreen(' ') | DBGAttr;
	vc = ' ' | DBGAttr;
	vc = rbo(vc);
	memsetW(p, vc, DBGROWS*DBGCOLS); //2604);
}

unsigned long *GetScreenLocation()
{
  return GetACBPtr()->pVidMem;
}

unsigned long GetCurrAttr()
{
  return GetACBPtr()->NormAttr;
}

void SetCurrAttr(unsigned long attr)
{
   GetACBPtr()->NormAttr = attr & 0xFFFF0000;
}

static void SetVideoReg(int regno, unsigned long val)
{
	if (regno < 0 || regno > 4) {
		printf("bad video regno: %d", regno);
		return;
	}
	TEXTVIDEO_REG[regno] = rbo(val);
}

static void DBGSetVideoReg(int regno, unsigned long val)
{
	TEXTVIDEO_REG[regno] = rbo(val);
}

static unsigned long DBGGetVideoReg(int regno)
{
	return (rob(TEXTVIDEO_REG[regno]));
}

void SetCursorPos(int row, int col)
{
	ACB *j;

	j = GetACBPtr();
	j->CursorCol = col;
	j->CursorRow = row;
	UpdateCursorPos();
}

void SetCursorCol(int col)
{
	ACB *j;

	j = GetACBPtr();
	j->CursorCol = col;
	UpdateCursorPos();
}

int GetCursorPos()
{
	ACB *j;

	j = GetACBPtr();
	return j->CursorCol | (j->CursorRow << 8);
}

int GetTextCols()
{
	return GetACBPtr()->VideoCols;
}

int GetTextRows()
{
	return GetACBPtr()->VideoRows;
}

char AsciiToScreen(char ch)
{
/*
	if (ch==0x5B)
		return (0x1B);
	if (ch==0x5D)
		return (0x1D);
	ch &= 0xFF;
	ch |= 0x100;
	if (!(ch & 0x20))
		return (ch);
	if (!(ch & 0x40))
		return (ch);
	ch = ch & 0x19F;
*/
	return (ch);
}

char ScreenToAscii(char ch)
{
/*
	ch &= 0xFF;
	if (ch==0x1B)
		return 0x5B;
	if (ch==0x1D)
		return 0x5D;
	if (ch < 27)
		ch += 0x60;
*/
	return (ch);
}
    

void UpdateCursorPos()
{
	ACB *j;
	int pos;

	j = GetACBPtr();
//    if (j == IOFocusNdx) {
	pos = j->CursorRow * j->VideoCols + j->CursorCol;
	SetVideoReg(11,pos);
//    }
}

void DBGSetCursorPos(unsigned long pos)
{
	DBGSetVideoReg(11,pos);
}

void DBGUpdateCursorPos()
{
	unsigned long pos;

	pos = get_coreno() * DBGCOLS * DBGROWS;
	pos += DBGCursorRow * DBGCOLS + DBGCursorCol;
  DBGSetCursorPos(pos);
}

void HomeCursor()
{
	ACB *j;

	j = GetACBPtr();
	j->CursorCol = 0;
	j->CursorRow = 0;
	UpdateCursorPos();
}

void DBGHomeCursor()
{
	DBGCursorCol = 0;
	DBGCursorRow = 0;
	DBGUpdateCursorPos();
}

int *CalcScreenLocation()
{
  ACB *j;
  int pos;

  j = GetACBPtr();
  pos = j->CursorRow * j->VideoCols + j->CursorCol;
//    if (j == IOFocusNdx) {
     SetVideoReg(11,pos);
//    }
  return GetScreenLocation()+pos;
}

void ClearScreen()
{
	int *p;
	int nn;
	int mx;
	ACB *j;
	int vc;

	j = GetACBPtr();
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
	int *p;
	int nn;
	int mx;
	ACB *j;
	int vc;

	j = GetACBPtr();
	p = GetScreenLocation();
	p = p + (int)j->VideoCols * row;
	vc = GetCurrAttr() | ' ';
	vc = rbo(vc);
	memsetT(p, vc, j->VideoCols);
}

void DBGBlankLine(int row)
{
	int *p;
	int nn;
	int mx;
	int vc;

	p = DBGScreen;
	p = p + row * DBGCOLS;
	vc = DBGAttr | ' ';
	vc = rbo(vc);
	memsetT(p, vc, DBGCOLS);
}

void VBScrollUp()
{
	int *scrn = GetScreenLocation();
	int nn;
	int count;
  ACB *j;

  j = GetACBPtr();
	count = (int)j->VideoCols*(int)(j->VideoRows-1);
	for (nn = 0; nn < count; nn++)
		scrn[nn] = scrn[nn+(int)j->VideoCols];

	BlankLine(GetTextRows()-1);
}

void DBGScrollUp()
{
	unsigned int *scrn = DBGScreen;
	int nn;
	int count;

	count = DBGROWS * DBGCOLS;
	for (nn = 0; nn < count; nn++)
		scrn[nn] = scrn[nn+DBGCOLS];

	DBGBlankLine(DBGROWS-1);
}

void IncrementCursorRow()
{
	ACB *j;

	j = GetACBPtr();
	j->CursorRow++;
	if (j->CursorRow < j->VideoRows) {
		UpdateCursorPos();
		return;
	}
	j->CursorRow--;
	UpdateCursorPos();
	VBScrollUp();
}

void DBGIncrementCursorRow()
{
	if (DBGCursorRow < DBGROWS - 1) {
		DBGCursorRow++;
		DBGUpdateCursorPos();
		return;
	}
	DBGScrollUp();
}

void IncrementCursorPos()
{
	ACB *j;

	j = GetACBPtr();
	j->CursorCol++;
	if (j->CursorCol < j->VideoCols) {
		UpdateCursorPos();
		return;
	}
	j->CursorCol = 0;
	IncrementCursorRow();
}

void DBGIncrementCursorPos()
{
	DBGCursorCol++;
	if (DBGCursorCol < DBGCOLS) {
		DBGUpdateCursorPos();
		return;
	}
	DBGCursorCol = 0;
	DBGIncrementCursorRow();
}

void DisplayChar(char ch)
{
   int *p;
   int nn;
   ACB *j;

   j = GetACBPtr();
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


void DBGDisplayChar(char ch)
{
	int *p;
	int nn;

	switch(ch) {
	case '\r':  DBGCursorCol = 0; DBGUpdateCursorPos(); break;
	case '\n':  DBGIncrementCursorRow(); break;
	case 0x91:
    if (DBGCursorCol < DBGCOLS - 1) {
       DBGCursorCol++;
       DBGUpdateCursorPos();
    }
    break;
	case 0x90:
    if (DBGCursorRow > 0) {
         DBGCursorRow--;
         DBGUpdateCursorPos();
    }
    break;
	case 0x93:
    if (DBGCursorCol > 0) {
         DBGCursorCol--;
         DBGUpdateCursorPos();
    }
    break;
	case 0x92:
    if (DBGCursorRow < DBGROWS-1) {
       DBGCursorRow++;
       DBGUpdateCursorPos();
    }
    break;
	case 0x94:
    if (DBGCursorCol==0)
       DBGCursorRow = 0;
    DBGCursorCol = 0;
    DBGUpdateCursorPos();
    break;
	case 0x99:  // delete
    p = DBGScreen + __mulf(DBGCursorRow, DBGCOLS);
    for (nn = DBGCursorCol; nn < DBGCOLS-1; nn++) {
      p[nn] = p[nn+1];
    }
		p[nn] = DBGAttr | ' ';
    break;
	case 0x08: // backspace
    if (DBGCursorCol > 0) {
      DBGCursorCol--;
//	      p = DBGScreen;
  		p = DBGScreen + __mulf(DBGCursorRow, DBGCOLS);
      for (nn = DBGCursorCol; nn < DBGCOLS-1; nn++) {
          p[nn] = p[nn+1];
      }
      p[nn] = DBGAttr | ' ';
		}
    break;
	case 0x0C:   // CTRL-L
    DBGClearScreen();
    DBGHomeCursor();
    break;
	case '\t':
    DBGDisplayChar(' ');
    DBGDisplayChar(' ');
    DBGDisplayChar(' ');
    DBGDisplayChar(' ');
    break;
	default:
	  p = DBGScreen;
	  nn = __mulf(DBGCursorRow, DBGCOLS) + DBGCursorCol;
	  //p[nn] = ch | DBGAttr;
	  out64(&p[nn],ch | DBGAttr);
	  DBGIncrementCursorPos();
		__asm {
			ldi		r1,#51
			sb		r1,LEDS
		}
    break;
	}
}

void DBGCRLF()
{
   DBGDisplayChar('\r');
   DBGDisplayChar('\n');
}

void DBGDisplayString(char *s)
{
	// Declaring ch here causes the compiler to generate shorter faster code
	// because it doesn't have to process another *s inside in the loop.
	char ch;
  while (ch = *s) { DBGDisplayChar(ch); s++; }
}

void DBGDisplayAsciiString(unsigned char *s)
{
	// Declaring ch here causes the compiler to generate shorter faster code
	// because it doesn't have to process another *s inside in the loop.
	unsigned char ch;
  while (ch = *s) { DBGDisplayChar(ch); s++; }
}

void DBGDisplayStringCRLF(char *s)
{
   DBGDisplayString(s);
   DBGCRLF();
}

void DBGDisplayAsciiStringCRLF(unsigned char *s)
{
   DBGDisplayAsciiString(s);
   DBGCRLF();
}

void DBGHideCursor(int hide)
{
	unsigned int vr;

	if (hide) {
		vr = DBGGetVideoReg(8);
		DBGSetVideoReg(8,vr|0xffff);
	}
	else {
		vr = DBGGetVideoReg(8) & 0xFFFF0000;
		DBGSetVideoReg(8,vr|0x00E7);
	}
}
extern TCB* tcbs;

TCB* TCBHandleToPointer(short int TCBHandle handle)
{
	if (handle <= 0)
		return (TCB*)0;
	return (&tcbs[handle-1]);
}

void InsertIntoReadyQ(short int TCBHandle handle)
{
	TCB* p;
	
	p = TCBHandleToPointer(handle);
	
}
