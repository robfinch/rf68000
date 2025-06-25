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
#include "inc/config.h"
#include "inc/const.h"
//#include "../inc/errno.h"
#include "inc/types.h"
#include "inc/proto.h"

#define NPAGES	65536-2048		// 2048 OS pages
#define CARD_MEMORY		0xFFCE0000
#define IPT_MMU				0xFFDCD000
#define IPT
#define MMU	0xFDC00000

#define NULL    (void *)0

extern char *os_brk;

extern unsigned long* lastSearchedPAMWord;
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
extern char* memset(char* ptr, long c, size_t n);
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

static unsigned long round16k(unsigned long amt)
{
  amt += 16383;
  amt &= 0xFFFFC000UL;
  return (amt);
}

// ----------------------------------------------------------------------------
// Allocate a page table.
// ----------------------------------------------------------------------------

PTE* AllocPageTable()
{
	char* page;

	page = FindFreePage();
	return ((PTE*)page);
}

// ----------------------------------------------------------------------------
// Get the address of the page table entry for a given linear address.
// If there is no mapping for the linear address, create one by allocating a
// page table.
//
// Returns:
//		pointer to page table entry, NULL if no memory available.
// ----------------------------------------------------------------------------

PTE* GetPageTableEntryAddress(hACB hAcb, char* linear, int alloc)
{
	ACB* pAcb;	
	unsigned long* pde;
	unsigned long* pte;
	unsigned int ndx;
	unsigned long iLinear;
	unsigned long pta;
	unsigned long page;
	
	iLinear = (unsigned long)linear;
	pAcb = ACBHandleToPointer(hAcb);
	pde = (unsigned long*)&pAcb->pd;
	ndx = iLinear >> 26;
	pta = (unsigned long)&pde[ndx];
	if (pta==0xffffffffUL) {
		if (alloc) {
			pta = (unsigned long)AllocPageTable();
			if (pta == 0xffffffffUL) {
				errno = E_NoMem;
				return (NULL);
			}
			// Mark all pages with special constant for empty page.
			memset((char *)pte,-1,16384);
			pta |= 0x7;	// user read-write-execute
			pde[ndx] = pta;
		}
		else
			return (NULL);
	}
	pta &= 0xFFFFC000UL;
	pte = (unsigned long*)pta;
	ndx = (iLinear >> 14) & 0xfff;
	pte = &pte[ndx];
	if ((unsigned long)pte == 0xffffffffUL) {
		if (alloc) {
			page = (unsigned long)FindFreePage();
			if (page==0)
				return (NULL);
			page |= 0x2007;	// page present + user read-write-execute
			*pte = page;
		}
		else
			return (NULL);
	}
	return ((PTE*)pte);
}

// ----------------------------------------------------------------------------
// Translate a linear address to a physical one.
// ----------------------------------------------------------------------------

char* LinearToPhysical(hACB hAcb, char* linear)
{
	PTE* pte;
	unsigned long iLinear;
	unsigned long phys;
	unsigned long ndx;
	
	pte = GetPageTableEntryAddress(hAcb, linear,1);
	if (pte == NULL)
		return (NULL);
	phys = (unsigned long)pte;
	phys &= 0xFFFFC000UL;
	ndx = iLinear & 0x3fffUL;
	phys |= ndx;
	return ((char*)phys);
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
// Alloc enough pages to fill the requested amount.
// ----------------------------------------------------------------------------

void *pt_alloc(int amt, int acr)
{
	PageDirectory* p;
	int npages;
	int nn;
	char* page;
	unsigned long* pte;
	unsigned long en;
	ACB* pacb;
	hACB hAcb;
	char* brk;

	acr &= 7;
	p = (char *)-1;
	DBGDisplayChar('B');
	amt = round16k(amt);
	npages = amt >> 14;
	if (npages==0)
		return (NULL);
	DBGDisplayChar('C');
	brk = NULL;
	if (npages < sys_pages_available) {
		sys_pages_available -= npages;
		pacb = GetRunningACBPtr();
		hAcb = GetRunningACB();
		brk = pacb->brk;
		pacb->brk += amt;
		for (nn = 0; nn < npages-1; nn++) {
			pte = GetPageTableEntryAddress(hAcb,brk+(nn << 14),1);
			en = (unsigned long)pte;
			en &= 0xffffc000UL;
			en |= 0x2000 | acr;	// 0x2000 = page present bit
			*pte = en;
		}
		pte = GetPageTableEntryAddress(hAcb,brk+(nn << 14),1);
		en = (unsigned long)pte;
		en &= 0xffffc000UL;
		en |= 0x2800 | acr;	// 0x2800 = page present bit, plus last page
		*pte = en;
	}
//	p |= (asid << 52);
	DBGDisplayChar('E');
	return ((void *)brk);
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

char *pt_free(char *vadr)
{
	int n;
	int count;	// prevent looping forever
	int vpageno;
	int last_page;
	unsigned long* pe;
	unsigned long pte;
	hACB h;

	count = 0;
	do {
		vpageno = ((unsigned long)vadr >> 14) & 0xffff;
		h = GetRunningACB();
		while (LockMMUSemaphore(-1)==0);
		last_page = 0;
		if (pe = (unsigned long*)GetPageTableEntryAddress(h,vadr,0)) {
			pte = *pe;
			last_page = (pte & 0x800) != 0;
			while (LockPMTSemaphore(-1)==0);
			if (PageManagementTable[vpageno].share_count != 0) {
				PageManagementTable[vpageno].share_count--;
				if (PageManagementTable[vpageno].share_count==0) {
					pte = 0xffffffffUL;
					*pe = pte;
				}
			}
			UnlockPMTSemaphore();
		}
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
void *sbrk(long size)
{
	char *p, *q, *r;
	unsigned long pte;
	ACB* pAcb;
	hACB h;
	unsigned long* pe;

	p = 0;
	size = round16k(size);
	if (size > 0) {
		p = pt_alloc(size,7);
		if (p==NULL)
			errno = E_NoMem;
		return (p);
	}
	h = GetRunningACB();
	pAcb = GetRunningACBPtr();
	if (size < 0) {
		size = -size;
		if (size > (unsigned long)pAcb->brk) {
			errno = E_NoMem;
			return (-1);
		}
		r = p = pAcb->brk - size;
		for(q = p; q < pAcb->brk;)
			q = pt_free(q);
		pAcb->brk = r;
		// Mark the last page
		if (r > (char*)0) {
			while (LockMMUSemaphore(-1)==0);
			pe = (unsigned long*)GetPageTableEntryAddress(h,r,0);
			pte = *pe;
			pte &= 0xfffff7ffUL;
			pte |= 0x00000800UL;
			*pe = pte;
			UnlockMMUSemaphore();
		}
	}
	else {	// size==0
		p = pAcb->brk;
	}
	return (p);
}
extern memsetW(int *, int, int);
extern memsetT(long *, long, long);

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
extern int get_coreno();
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

void UpdateCursorPos()
{
	ACB *j;
	int pos;

	j = GetACBPtr();
//    if (j == IOFocusNdx) {
  pos = (j->CursorRow * j->VideoCols + j->CursorCol) +
  	(get_coreno() * j->VideoCols * j->VideoRows);
	SetVideoReg(11,pos);
//    }
}

void HomeCursor()
{
	ACB *j;

	j = GetACBPtr();
	j->CursorCol = 0;
	j->CursorRow = 0;
	UpdateCursorPos();
}

int *CalcScreenLocation()
{
  ACB *j;
  int pos;

  j = GetACBPtr();
  pos = (j->CursorRow * j->VideoCols + j->CursorCol) +
  	(get_coreno() * j->VideoCols * j->VideoRows);
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

extern memsetW(int *, int, int);
extern memsetT(long *, long, long);

// The text screen memory can only handle half-word transfers, hence the use
// of memsetH, memcpyH.
//#define DBGScreen	(__int32 *)0xFFD00000
#define TEXTVIDEO_REG	((unsigned long*)0xFD080000)
#define DBGScreen	((unsigned long*)0xFD000000)
#define DBGCOLS		64
#define DBGROWS		32

extern int IOFocusNdx;
extern __int8 DBGCursorCol;
extern __int8 DBGCursorRow;
extern int DBGAttr;
extern void puthexnum(int num, int wid, int ul, char padchar);
extern void out32(unsigned long* port, unsigned long val);
extern int get_coreno();

unsigned long rbo(unsigned long i)
{
	long o;
	
	o = (i >> 24) | ((i & 0xff0000) >> 8) | ((i & 0xff00) << 8) | ((i & 0xff) << 24);
	return (o);
}

unsigned long* DBGGetScreenLoc()
{
	return ((unsigned long *)((get_coreno() * DBGCOLS * DBGROWS) + DBGScreen));
}

void DBGClearScreen()
{
	unsigned long *p;
	unsigned long vc;

	p = DBGGetScreenLoc();
	//vc = AsciiToScreen(' ') | DBGAttr;
	vc = ' ' | DBGAttr;
	vc = rbo(vc);
	memsetT(p, vc, DBGROWS*DBGCOLS); //2604);
}

static void DBGSetVideoReg(int regno, unsigned long val)
{
	TEXTVIDEO_REG[regno] = rbo(val);
}

static unsigned long DBGGetVideoReg(int regno)
{
	return (rbo(TEXTVIDEO_REG[regno]));
}

void DBGSetCursorPos(unsigned long pos)
{
	DBGSetVideoReg(11,pos);
}

void DBGUpdateCursorPos()
{
	unsigned long pos;

	pos = (unsigned long)DBGGetScreenLoc();
	pos += DBGCursorRow * DBGCOLS + DBGCursorCol;
  DBGSetCursorPos(pos);
}

void DBGHomeCursor()
{
	DBGCursorCol = 0;
	DBGCursorRow = 0;
	DBGUpdateCursorPos();
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

void DBGScrollUp()
{
	unsigned long *scrn = DBGGetScreenLoc();
	int nn;
	int count;

	count = DBGROWS * DBGCOLS;
	for (nn = 0; nn < count; nn++)
		scrn[nn] = scrn[nn+DBGCOLS];

	DBGBlankLine(DBGROWS-1);
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


void DBGDisplayChar(char ch)
{
	unsigned long *p;
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
    p = DBGGetScreenLoc() + DBGCursorRow * DBGCOLS;
    for (nn = DBGCursorCol; nn < DBGCOLS-1; nn++) {
      p[nn] = p[nn+1];
    }
		p[nn] = rbo(DBGAttr | ' ');
    break;
	case 0x08: // backspace
    if (DBGCursorCol > 0) {
      DBGCursorCol--;
//	      p = DBGScreen;
  		p = DBGGetScreenLoc() + DBGCursorRow * DBGCOLS;
      for (nn = DBGCursorCol; nn < DBGCOLS-1; nn++) {
          p[nn] = p[nn+1];
      }
      p[nn] = rbo(DBGAttr | ' ');
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
	  p = DBGGetScreenLoc();
	  nn = DBGCursorRow * DBGCOLS + DBGCursorCol;
	  //p[nn] = ch | DBGAttr;
	  out32rbo(&p[nn],ch | DBGAttr);
	  DBGIncrementCursorPos();
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
// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//                                                                          
// ============================================================================
//
#include "inc\config.h"
#include "inc\const.h"
#include "inc\types.h"
#include "inc\proto.h"
#include "inc\glo.h"
//#include "TCB.h"

extern long __interrupt FMTK_Dispatch(
	__reg("d7") long,
	__reg("d0") long,
	__reg("d1") long,
	__reg("d2") long,
	__reg("d3") long,
	__reg("d4") long
);
extern void FMTK_TimerIRQLaunchpad(unsigned long);
extern int GetRand(register int stream);
extern int shell();
MEMORY memoryList[NR_MEMORY];

//int interrupt_table[512];
int reschedFlag;
int IRQFlag;
int irq_stack[512];
extern int FMTK_Inited;
extern ACB *ACBPtrs[NR_ACB];
extern TCB tcbs[NR_TCB];
extern hTCB readyQ[64];
extern int sysstack[1024];
extern int sys_stacks[NR_TCB][512];
extern int bios_stacks[NR_TCB][512];
extern int fmtk_irq_stack[512];
extern int fmtk_sys_stack[512];
extern MBX mailbox[NR_MBX];
extern MSG message[NR_MSG];
extern int nMsgBlk;
extern int nMailbox;
extern hACB freeACB;
extern hMSG freeMSG;
extern hMBX freeMBX;
extern ACB *IOFocusNdx;
extern int IOFocusTbl[4];
extern int iof_switch;
extern char hasUltraHighPriorityTasks;
extern int missed_ticks;
extern byte hSearchApp;
extern byte hFreeApp;

extern hTCB TimeoutList;
extern hMBX hKeybdMbx;
extern hMBX hFocusSwitchMbx;
extern int im_save;

// This set of nops needed just before the function table so that the cpu may
// fetch nop instructions after going past the end of the routine linked prior
// to this one.

void FMTK_NopRamp() =
	"\trept 16\r\n"
	"\tnop\r\n"
	"\tendr"
;

static unsigned long GetTick() = "\tmovec.l\ttick,d0";

// Reset timer edge sense circuit
void AckTimerIRQ() =
	"\tmoveq #3,d0\r\n"
	"\tmove.l d0,PIC_ESR\r\n"
;

void DisplayIRQLive() =
	"\tmovem.l d0/a0,-(sp)\r\n"
	"\tmovec.l coreno,d0\r\n"
	"\tlsl.l #2,d0\r\n"
	"\tadd.l #$FD0000DC,d0\r\n"
	"\tmove.l d0,a0\r\n"
	"\tadd.l #1,(a0)\r\n"
	"\tmovem.l (sp)+,d0/a0"
;

ACB *SafeGetACBPtr(register int n)
{
	if (n < 0 || n >= NR_ACB)
		return (null);
  return (ACBPtrs[n]);
}

ACB *GetACBPtr(int n)
{
  return (ACBPtrs[n-1]);
}

hACB GetAppHandle()
{
	return (GetRunningTCBPtr()->hApp);
}

ACB *GetRunningACBPtr()
{
	return (GetACBPtr(GetAppHandle()));
}

ACB* ACBHandleToPointer(hACB h)
{
	return (ACBPtrs[h-1]);
}

int GetRunningPID() =
"\tmovec.l cpid,d0\r\n"
;

// ----------------------------------------------------------------------------
// Get the current interrupt mask level.
// ----------------------------------------------------------------------------

int GetImLevel() =
"\tmove sr,d0\r\n"
"\tlsr.w #8,d0\r\n"
"\tand.l #7,d0\r\n"
;

// ----------------------------------------------------------------------------
// Carefully done so that the IM level is not affected until the end. There is
// no transient level.
// ----------------------------------------------------------------------------

void SetImLevelHelper(__reg("d0") int level) =
"\tmove.l d1,-(sp)\r\n"
"\tand.w #7,d0\r\n"
"\tlsl.w #8,d0\r\n"
"\tmove sr,d1\r\n"
"\tand.w #$F8FF,d1\r\n"
"\tor.w d1,d0\r\n"
"\tmove.w d0,sr\r\n"
"\tmove.l (sp)+,d1\r\n"
;

// ----------------------------------------------------------------------------
// SetImLevel will only set the interrupt mask level to level higher than the
// current one.
//
// Returns:
//		int	- the previous interrupt level setting
// ----------------------------------------------------------------------------

int SetImLevel(register int level)
{
	int x;

	if ((x = GetImLevel()) >= level)
		return (x);
	SetImLevelHelper(level);
	return(x);
}

unsigned long GetSP() = "\tmove.l sp,d0\r\n";
void SetSP(__reg("d0") unsigned long sp) = "\tmove.l d0,sp";

// ----------------------------------------------------------------------------
// Restore the task's context.
//
// The registers were stored on the task's IRQ stack when the timer ISR was
// entered. They will automatically be restored from the IRQ stack when the
// the ISR exits. The only thing required is to account for the other info
// related to the context.
// ----------------------------------------------------------------------------

void SwapContext(register TCB *octx, register TCB *nctx)
{
	ACB* q;

	// Set the app's page directory in the MMU 
	q = GetACBPtr(nctx->hApp);
	SetMMUAppPD(q->pd);
	octx->ssp = GetSP();
	SetSP(nctx->ssp);
}

// ----------------------------------------------------------------------------
// Select a task to run.
// ----------------------------------------------------------------------------

static int invert;

static hTCB SelectTaskToRunHelper(int nn)
{
	int kk;
  hTCB h, h1;
	TCB *p, *q;
 
	h = readyQ[nn];
	if (h > 0 && h <= NR_TCB) {
		p = TCBHandleToPointer(h);
    kk = 0;
    // Can run the head of a lower Q level if it's not the running
    // task, otherwise look to the next task.
    if (h != GetRunningTCB())
   		q = p;
		else
   		q = TCBHandleToPointer(p->next);
    do {  
      if (!(q->status & TS_RUNNING)) {
        if (q->affinity == getCPU()) {
        	h1 = TCBPointerToHandle(q);
			  	readyQ[nn] = h1;
			   	return (h1);
        }
      }
      q = TCBHandleToPointer(q->next);
      kk = kk + 1;
    } while (q != p && kk < NR_TCB);
  }
	return (-1);
}

static hTCB SelectTaskToRun()
{
	int nn;
  hTCB h;
 
 	invert++;
	// Occasionally prioriies are inverted.
	if ((invert & 31)==0) {
		for (nn = 0; nn < 32; nn++) {
			if ((h = SelectTaskToRunHelper(nn)) > 0)
				return (h);
		}
		return (GetRunningTCB());
	}
	// Search the queues from the highest to lowest priority.
	for (nn = 31; nn >= 0; nn--) {
		if ((h = SelectTaskToRunHelper(nn)) > 0)
			return (h);
	}
	return (GetRunningTCB());
	panic("No entries in ready queue.");
}

// ----------------------------------------------------------------------------
// FMTK primitives need to re-schedule threads in a couple of places.
// ----------------------------------------------------------------------------

void TriggerTimerIRQ() =
"\tmove.l #1,_reschedFlag\r\n"
"\tmove.l #29,PLIC+$18\r\n"
;

void FMTK_Reschedule()
{
	TriggerTimerIRQ();
}

// ----------------------------------------------------------------------------
// If timer interrupts are enabled during a priority #0 task, this routine
// only updates the missed ticks and remains in the same task. No timeouts
// are updated and no task switches will occur. The timer tick routine
// basically has a fixed latency when priority #0 is present.
// ----------------------------------------------------------------------------

void FMTK_TimerIRQ(unsigned long* sp)
{
  TCB *t, *ot, *tol;
  char* sp2;

	ot = t = GetRunningTCBPtr();
	t->endTick = GetTick();
	// Explicit rescheduling request?
	if (reschedFlag) {
		reschedFlag = 0;
		t->ticks = t->ticks + (t->endTick - t->startTick);
		t->status |= TS_PREEMPT;
		t->status &= ~TS_RUNNING;
//		t->epc = t->epc + 1;  // advance the return address
		SetRunningTCBPtr(TCBHandleToPointer(SelectTaskToRun()));
		GetRunningTCBPtr()->status |= TS_RUNNING;
	}
	// Timer tick interrupt
	else {
		// Timer will auto-reset, the following line should not be necessary.
//		AckTimerIRQ();
		// Set IRQ flag for interpreters
		IRQFlag = 1;
		DisplayIRQLive();
		// Try and lock the system semaphore, but not too hard.
		if (LockSysSemaphore(20)) {
			t->ticks = t->ticks + (t->endTick - t->startTick);
			if (t->priority != 31) {
				t->status |= TS_PREEMPT;
				t->status &= ~TS_RUNNING;
				while (TimeoutList > 0 && TimeoutList <= NR_TCB) {
					tol = TCBHandleToPointer(TimeoutList);
					if (tol->timeout <= 0)
						InsertIntoReadyList(PopTimeoutList());
					else {
						tol->timeout = tol->timeout - missed_ticks - 1;
						missed_ticks = 0;
						break;
					}
				}
				if (t->priority < 28)
					SetRunningTCBPtr(TCBHandleToPointer(SelectTaskToRun()));
				GetRunningTCBPtr()->status |= TS_RUNNING;
			}
			else
				missed_ticks++;
			UnlockSysSemaphore();
		}
		// System semaphore could not be locked.
		else {
			missed_ticks++;
		}
	}
	// If an exception was flagged (eg CTRL-C) return to the catch handler
	// not the interrupted code.
	t = GetRunningTCBPtr();
	if (t->exception) {
		// Dig into the stack here to set registers
		sp[2] = t->exception;				// d1 = exception value
		sp[3] = 45;									// d2 = exception type
		// The CPU stores a word instead of an lword for the status register.
		// This shifts the placement of the return PC value by two bytes.
		sp = &sp[17];								// PC would be here except that only
		sp2 = (char *)sp;						// two bytes were stored for the SR.
		sp2 -= 2;										// So, the pointer needs to back up two
		sp = (unsigned long*)sp2;		// bytes.
		*sp2 = (unsigned long)t->exceptionHandler;	// Now copy exception handler address to stack
	}
	t->startTick = GetTick();
	if (ot != t)
		SwapContext(ot,t);
}

void panic(char *msg)
{
     putstr(msg);
j1:  goto j1;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void IdleThread()
{
   int ii;
   unsigned long *screen = (unsigned long *)0xFFD00000L;

   while(1) {
     ii++;
     if (get_coreno()==0) {
       screen[57] = 0x000F0000L|ii;
		 }
   }
}

long FMTK_ExceptionHandler(__reg("d0") long val, __reg("d1") long typ)
{
	if (typ==515) {
		puts("Default exception handler: CTRL-C pressed.\r\n");
		FMTK_ExitTask();
	}
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int FMTK_KillTask(register int taskno)
{
  hTCB ht, pht;
  hACB hApp;
  int nn;
  ACB *j;

  ht = taskno-1;
  if (LockSysSemaphore(-1)) {
    RemoveFromReadyList(ht);
    RemoveFromTimeoutList(ht);
    for (nn = 0; nn < 4; nn++)
      if (tcbs[ht].hMailboxes[nn] >= 0 && tcbs[ht].hMailboxes[nn] < NR_MBX) {
        FMTK_FreeMbx(tcbs[ht].hMailboxes[nn]);
        tcbs[ht].hMailboxes[nn] = 0;
      }
    // remove task from job's task list
    hApp = tcbs[ht].hApp;
    j = GetACBPtr(hApp);
    ht = j->task;
    if (ht==taskno)
    	j->task = tcbs[ht].acbnext;
    else {
    	while (ht > 0) {
    		pht = ht;
    		ht = tcbs[ht].acbnext - 1;
    		if (ht==taskno-1) {
    			tcbs[pht].acbnext = tcbs[ht].acbnext;
    			break;
    		}
    	}
    }
		tcbs[ht].acbnext = 0;
    // If the job no longer has any threads associated with it, it is 
    // finished.
    if (j->task == 0) {
    	j->magic = 0;
    	mmu_FreeMap(hApp);
    }
    UnlockSysSemaphore();
  }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int FMTK_ExitTask()
{
  KillTask(GetRunningTCB());
	// The thread should not return from this reschedule because it's been
	// killed.
	while(1) {
  	FMTK_Reschedule();
	}
}


// ----------------------------------------------------------------------------
// Returns:
//	hTCB	positive number handle of thread started,
//			or negative number error code
// ----------------------------------------------------------------------------

long FMTK_StartTask(
	__reg("d0") unsigned short int* StartAddr,
	__reg("d1") long stacksize,
	__reg("d2") unsigned long* pStack,
	__reg("d3") long parm,
	__reg("d4") long info
)
{
  hTCB ht;
  TCB *t;
  int nn;
  unsigned long affinity;
	hACB hApp;
	unsigned char priority;
	short int *sp2;
	unsigned long int* sp;

	// These fields extracted from a single parameter as there can be only
	// five register values passed to the function.	
  affinity = info & 0xffffffffL;
	hApp = (info >> 32) & 0xffffL;
	priority = (info >> 48) & 0xff;

  if (LockSysSemaphore(100000)) {
    ht = freeTCB;
    if (ht < 0 || ht >= NR_TCB) {
      UnlockSysSemaphore();
    	return (E_NoMoreTCBs);
    }
    freeTCB = tcbs[ht].next;
    UnlockSysSemaphore();
  }
	else {
		return (E_Busy);
	}
  t = &tcbs[ht-1];
  t->affinity = affinity;
  t->priority = priority;
  t->hApp = hApp;
  // Insert into the job's list of tasks.
  tcbs[ht-1].acbnext = hApp;
  ACBPtrs[hApp]->task = ht;
  t->regs[1] = parm;
  t->regs[15] = (unsigned long)pStack + stacksize - 2048;	// Set USP
  t->bios_stack = (unsigned long*)pStack + stacksize - 8;
  t->sys_stack = (unsigned long*)pStack + stacksize - 1024;
  // Put ExitTask address on top of stack, when the task is finished then
  // this address will be returned to.
  pStack[stacksize - 2048 - 4] = (unsigned long)FMTK_ExitTask;
  // Setup system stack image to look as if a syscall were performed.
  sp = &pStack[stacksize - 1024 - 4 - 18*4];
  t->ssp = (unsigned long)sp;
	sp[0] = (unsigned long)pStack + stacksize - 2048;	// USP
	sp[1] = parm;				// d0 gets parameter
  for (nn = 2; nn < 16; nn = nn + 1)
  	sp[nn] = 0;
  sp2 = (short int*)&sp[16];
  *sp2 = 0x700;	// status register
  sp2++;
  sp = (unsigned long *)sp2;
  *sp = (unsigned long)StartAddr;
  sp[1] = (unsigned long)FMTK_ExitTask;

  t->startTick = GetTick();
  t->endTick = GetTick();
  t->ticks = 0;
  t->exception = 0;
  t->exceptionHandler = FMTK_ExceptionHandler;
  if (LockSysSemaphore(100000)) {
      InsertIntoReadyList(ht);
      UnlockSysSemaphore();
  }
	else {
		return (E_Busy);
	}
  return (ht);
}

// ----------------------------------------------------------------------------
// Sleep for a number of clock ticks.
// ----------------------------------------------------------------------------

int FMTK_Sleep(__reg("d0") unsigned long timeout)
{
  hTCB ht;
  int tick1, tick2;

	while (timeout > 0) {
		tick1 = GetTick();
    if (LockSysSemaphore(100000)) {
      ht = GetRunningTCB();
      RemoveFromReadyList(ht);
      InsertIntoTimeoutList(ht, timeout);
      UnlockSysSemaphore();
			FMTK_Reschedule();
      break;
    }
		else {
			tick2 = GetTick();
			timeout -= (tick2-tick1);
		}
	}
  return (E_Ok);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int FMTK_SetTaskPriority(__reg("d0") hTCB ht, __reg("d1") int priority)
{
  TCB *t;

  if (priority > 31 || priority < 0)
   return (E_Arg);
  if (LockSysSemaphore(-1)) {
    t = &tcbs[ht];
    if (t->status & (TS_RUNNING | TS_READY)) {
      RemoveFromReadyList(ht);
      t->priority = priority;
      InsertIntoReadyList(ht);
    }
    else
      t->priority = priority;
    UnlockSysSemaphore();
  }
  return (E_Ok);
}

void SetVector(__reg("d0") unsigned long num, __reg("d1") unsigned long addr) = 
	"\tmovem.l d0/a0,-(sp)\r\n"
	"\tlsl.l #2,d0\r\n"
	"\tmove.l d0,a0"
	"\tmove.l d1,(a0)\r\n"
	"\tmovem.l (sp)+,d0/a0\r\n"
;

// ----------------------------------------------------------------------------
// Initialize FMTK global variables.
// ----------------------------------------------------------------------------

long FMTK_Initialize()
{
	int nn,jj;
	int lev;

//    firstcall
  {
  	lev = SetImLevel(7);									// Do not allow interrupts
    SetVector(30,(unsigned long)FMTK_TimerIRQLaunchpad);	// Auto level 6
  	SetVector(33,(unsigned long)FMTK_Dispatch);					// TRAP #1

  	reschedFlag = 0;
  	IRQFlag = 0;
    hasUltraHighPriorityTasks = 0;
    missed_ticks = 0;

    IOFocusTbl[0] = 0;
    IOFocusNdx = null;
    iof_switch = 0;
    hSearchApp = 0;
    hFreeApp = -1;

		SetRunningTCBPtr(0);
    im_save = 7;
    UnlockSysSemaphore();
    UnlockIOFSemaphore();
    UnlockKbdSemaphore();

		// Setting up message array
    for (nn = 0; nn < NR_MSG; nn++) {
      message[nn].link = nn+2;
    }
    message[NR_MSG-1].link = 0;
    freeMSG = 1;

  	for (nn = 0; nn < 8; nn++)
  		readyQ[nn] = 0;
  	for (nn = 0; nn < NR_TCB; nn++) {
      tcbs[nn].number = nn;
      tcbs[nn].acbnext = 0;
  		tcbs[nn].next = nn+1;
  		tcbs[nn].prev = 0;
  		tcbs[nn].status = 0;
  		tcbs[nn].priority = 15;
  		tcbs[nn].affinity = 0;
  		tcbs[nn].hApp = 0;
  		tcbs[nn].timeout = 0;
  		tcbs[nn].hMailboxes[0] = 0;
  		tcbs[nn].hMailboxes[1] = 0;
  		tcbs[nn].hMailboxes[2] = 0;
  		tcbs[nn].hMailboxes[3] = 0;
  		if (nn<2) {
        tcbs[nn].affinity = nn;
        tcbs[nn].priority = 30;
      }
      tcbs[nn].exception = 0;
  	}
  	tcbs[NR_TCB-1].next = 0;
  	freeTCB = 2;
  	TimeoutList = 0;
/*
    	InsertIntoReadyList(0);
    	InsertIntoReadyList(1);
    	tcbs[0].status = TS_RUNNING;
    	tcbs[1].status = TS_RUNNING;
        asm {
            ldi   r1,#44
            sb    r1,$FFDC0600
        }
*/
//		SetVBA(FMTK_IRQDispatch);
//    	set_vector(4,(unsigned int)FMTK_SystemCall);
//    	set_vector(2,(unsigned int)FMTK_SchedulerIRQ);
		hKeybdMbx = 0;
		hFocusSwitchMbx = 0;
  	FMTK_Inited = 0x12345678;
    SetupDevices();
  	SetImLevelHelper(lev);								// Restore interrupts
  }
  return (0);
}

#include "inc\types.h"
#include "inc\const.h"
#include "inc\config.h"
#include "inc\proto.h"
#include "inc\glo.h"

static MSG* MSGHandleToPointer(hMSG h)
{
	MSG* msg;
	
	msg = &message[h-1];
	return (msg);
}

/* ---------------------------------------------------------------
	Description:
		Copy a message.
--------------------------------------------------------------- */

static void CopyMsg(MSG *dmsg, MSG *smsg)
{
	dmsg->type = smsg->type;
	dmsg->retadr = smsg->retadr;
	dmsg->dstadr = smsg->dstadr;
	dmsg->link = 0;
	dmsg->d1 = smsg->d1;
	dmsg->d2 = smsg->d2;
	dmsg->d3 = smsg->d3;
}

/* ---------------------------------------------------------------
	Description:
		Freeup message and add back to free list.
--------------------------------------------------------------- */

static void FreeMsg(MSG *msg)
{
  msg->type = MT_FREE;
  msg->retadr = 0;
  msg->dstadr = 0;
	msg->link = freeMSG;
	freeMSG = (msg - message) + 1;
	nMsgBlk++;
}

/* ---------------------------------------------------------------
	Description:
		Queue a message at a mailbox.

	Assumptions:
		valid mailbox parameter.

	Called from:
		SendMsg
		PostMsg
--------------------------------------------------------------- */

static long QueueMsg(MBX *mbx, MSG *msg)
{
  MSG *tmpmsg;
  hMSG htmp;
	int rr = E_Ok;

	if (LockSysSemaphore(-1)) {
		mbx->mq_count++;
	
		// handle potential queue overflows
    switch (mbx->mq_strategy) {
    
    	// unlimited queing (do nothing)
		case MQS_UNLIMITED:
			break;
			
		// buffer newest
		// if the queue is full then old messages are lost
		// Older messages are at the head of the queue.
		// loop incase message queing strategy was changed
    case MQS_NEWEST:
      while (mbx->mq_count > mbx->mq_size) {
        // return outdated message to message pool
        htmp = message[mbx->mq_head-1].link;
        tmpmsg = &message[htmp-1];
        message[mbx->mq_head-1].link = freeMSG;
        freeMSG = mbx->mq_head;
				nMsgBlk++;
				mbx->mq_count--;
        mbx->mq_head = htmp;
				if (mbx->mq_missed < MAX_UINT)
					mbx->mq_missed++;
				rr = E_QueFull;
			}
	    break;

		// buffer oldest
		// if the queue is full then new messages are lost
		// loop incase message queing strategy was changed
		case MQS_OLDEST:
			// first return the passed message to free pool
			if (mbx->mq_count > mbx->mq_size) {
				// return new message to pool
				msg->link = freeMSG;
				freeMSG = (msg-message)+1;
				nMsgBlk++;
				if (mbx->mq_missed < MAX_UINT)
					mbx->mq_missed++;
				rr = E_QueFull;
				mbx->mq_count--;
			}
			// next if still over the message limit (which
			// might happen if que strategy was changed), return
			// messages to free pool
			while (mbx->mq_count > mbx->mq_size) {
				// locate the second last message on the que
				tmpmsg = &message[mbx->mq_head-1];
				while ((tmpmsg-message)+1 != mbx->mq_tail) {
					msg = tmpmsg;
					tmpmsg = &message[tmpmsg->link-1];
				}
				mbx->mq_tail = (msg-message)+1;
				tmpmsg->link = freeMSG;
				freeMSG = (tmpmsg-message)+1;
				nMsgBlk++;
				if (mbx->mq_missed < MAX_UINT)
					mbx->mq_missed++;
				mbx->mq_count--;
				rr = E_QueFull;
			}
			if (rr == E_QueFull) {
   	    UnlockSysSemaphore();
				return (rr);
      }
      break;
		}
		// if there is a message in the queue
		if (mbx->mq_tail > 0)
			message[mbx->mq_tail-1].link = (msg-message)+1;
		else
			mbx->mq_head = (msg-message)+1;
		mbx->mq_tail = (msg-message)+1;
		msg->link = 0;
    UnlockSysSemaphore();
  }
	return (rr);
}


/* ---------------------------------------------------------------
	Description:
		Dequeues a message from a mailbox.

	Assumptions:
		Mailbox parameter is valid.
		System semaphore is locked already.

	Called from:
		FreeMbx - (locks mailbox)
		WaitMsg	-	"
		CheckMsg-	"
--------------------------------------------------------------- */

static MSG *DequeueMsg(MBX *mbx)
{
	MSG *tmpmsg = null;
  hMSG hm;
 
	if (mbx->mq_count) {
		mbx->mq_count--;
		hm = mbx->mq_head;
		if (hm >= 0) {	// should not be null
		    tmpmsg = &message[hm-1];
			mbx->mq_head = tmpmsg->link;
			if (mbx->mq_head < 0)
				mbx->mq_tail = 0;
			tmpmsg->link = hm;
		}
	}
	return (tmpmsg);
}


/* ---------------------------------------------------------------
	Description:
		Dequeues a thread from a mailbox. The thread will also
	be removed from the timeout list (if it's present there),
	and	the timeout list will be adjusted accordingly.

	Assumptions:
		Mailbox parameter is valid.
--------------------------------------------------------------- */

static long DequeThreadFromMbx(MBX *mbx, TCB **thrd)
{
	if (thrd == NULL || mbx == NULL)
		return (E_Arg);

	if (LockSysSemaphore(-1)) {
		if (mbx->tq_head == 0) {
  		UnlockSysSemaphore();
			*thrd = null;
			return (E_NoThread);
		}
	
		mbx->tq_count--;
		*thrd = &tcbs[mbx->tq_head-1];
		mbx->tq_head = tcbs[mbx->tq_head-1].mbq_next;
		if (mbx->tq_head > 0)
			tcbs[mbx->tq_head-1].mbq_prev = 0;
		else
			mbx->tq_tail = 0;
		UnlockSysSemaphore();
	}

	// if thread is also on the timeout list then
	// remove from timeout list
	// adjust succeeding thread timeout if present
	if ((*thrd)->status & TS_TIMEOUT)
		RemoveFromTimeoutList(((*thrd)-tcbs)+1);

	(*thrd)->mbq_prev = (*thrd)->mbq_next = 0;
	(*thrd)->hWaitMbx = 0;	// no longer waiting at mailbox
	(*thrd)->status &= ~TS_WAITMSG;
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Allocate a mailbox. The default queue strategy is to
	queue the eight most recent messages.
--------------------------------------------------------------- */

long FMTK_AllocMbx(__reg("d0") hMBX *phMbx)
{
	MBX *mbx;

	if (phMbx==NULL)
  	return (E_Arg);
	if (LockSysSemaphore(-1)) {
		if (freeMBX <= 0 || freeMBX >= NR_MBX) {
	    UnlockSysSemaphore();
			return (E_NoMoreMbx);
    }
		mbx = &mailbox[freeMBX-1];
		freeMBX = mbx->link;
		nMailbox--;
    UnlockSysSemaphore();
  }
	*phMbx = (mbx - mailbox) + 1;
	mbx->owner = GetAppHandle();
	mbx->tq_head = 0;
	mbx->tq_tail = 0;
	mbx->mq_head = 0;
	mbx->mq_tail = 0;
	mbx->tq_count = 0;
	mbx->mq_count = 0;
	mbx->mq_missed = 0;
	mbx->mq_size = 8;
	mbx->mq_strategy = MQS_NEWEST;
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Free up a mailbox. When the mailbox is freed any queued
	messages must be freed. Any queued threads must also be
	dequeued. 
--------------------------------------------------------------- */
long FMTK_FreeMbx(__reg("d0") hMBX hMbx) 
{
	MBX *mbx;
	MSG *msg;
	TCB *thrd;
	
	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	mbx = &mailbox[hMbx-1];
	if (LockSysSemaphore(-1)) {
		if ((mbx->owner != GetAppHandle()) && (GetAppHandle() != 0)) {
	    UnlockSysSemaphore();
			return (E_NotOwner);
    }
		// Free up any queued messages
		while (msg = DequeueMsg(mbx))
			FreeMsg(msg);
		// Send an indicator to any queued threads that the mailbox
		// is now defunct Setting MsgPtr = null will cause any
		// outstanding WaitMsg() to return E_NoMsg.
		while(1) {
			DequeThreadFromMbx(mbx, &thrd);
			if (thrd == null)
				break;
			thrd->msg.type = MT_NONE;
			if (thrd->status & TS_TIMEOUT)
				RemoveFromTimeoutList((thrd-tcbs)+1);
			InsertIntoReadyList((thrd-tcbs)+1);
		}
		mbx->link = freeMBX;
		freeMBX = mbx-mailbox;
		nMailbox++;
    UnlockSysSemaphore();
  }
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Set the mailbox message queueing strategy.
--------------------------------------------------------------- */
long SetMbxMsgQueStrategy(hMBX hMbx, int qStrategy, int qSize)
{
	MBX *mbx;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	if (qStrategy > 2)
		return (E_Arg);
	mbx = &mailbox[hMbx-1];
	if (LockSysSemaphore(-1)) {
		if ((mbx->owner != GetAppHandle()) && GetAppHandle() != 0) {
	    UnlockSysSemaphore();
			return (E_NotOwner);
    }
		mbx->mq_strategy = qStrategy;
		mbx->mq_size = qSize;
    UnlockSysSemaphore();
  }
	return (E_Ok);
}


/* ---------------------------------------------------------------
	Description:
		Send a message.
--------------------------------------------------------------- */
long FMTK_SendMsg(
	__reg("d0") hMBX hMbx,
	__reg("d1") long d1,
	__reg("d2") long d2,
	__reg("d3") long d3
)
{
	MBX *mbx;
	MSG *msg;
	TCB *thrd;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	mbx = &mailbox[hMbx-1];
	if (LockSysSemaphore(-1)) {
		// check for a mailbox owner which indicates the mailbox
		// is active.
		if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
	    UnlockSysSemaphore();
      return (E_NotAlloc);
    }
		if (freeMSG <= 0 || freeMSG > NR_MSG) {
	    UnlockSysSemaphore();
			return (E_NoMoreMsgBlks);
    }
		msg = &message[freeMSG-1];
		freeMSG = msg->link;
		--nMsgBlk;
		msg->retadr = GetAppHandle();
		msg->dstadr = hMbx;
		msg->type = MBT_DATA;
		msg->d1 = d1;
		msg->d2 = d2;
		msg->d3 = d3;
		DequeThreadFromMbx(mbx, &thrd);
    UnlockSysSemaphore();
  }
	if (thrd == null)
		return (QueueMsg(mbx, msg));
	if (LockSysSemaphore(-1)) {
		CopyMsg(&thrd->msg,msg);
    FreeMsg(msg);
  	if (thrd->status & TS_TIMEOUT)
  		RemoveFromTimeoutList(thrd-tcbs);
  	InsertIntoReadyList(thrd-tcbs);
    UnlockSysSemaphore();
  }
	return (E_Ok);
}


s/* ---------------------------------------------------------------
	Description:
		Wait for message. If timelimit is zero then the thread
	will wait indefinately for a message.
--------------------------------------------------------------- */

long FMTK_WaitMsg(
	__reg("d0") hMBX hMbx,
	__reg("d1") long *d1,
	__reg("d2") long *d2,
	__reg("d3") long *d3,
	__reg("d4") long timelimit
)
{
	MBX *mbx;
	MSG *msg;
	TCB *thrd;
	TCB *rt;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	mbx = &mailbox[hMbx-1];
	if (LockSysSemaphore(-1)) {
  	// check for a mailbox owner which indicates the mailbox
  	// is active.
  	if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
   	    UnlockSysSemaphore();
      	return (E_NotAlloc);
      }
  	msg = DequeueMsg(mbx);
    UnlockSysSemaphore();
  }
  // Return message right away if there is one available.
  if (msg) {
		d1 = LinearToPhysical(GetRunningPID(), d1);
		d2 = LinearToPhysical(GetRunningPID(), d2);
		d3 = LinearToPhysical(GetRunningPID(), d3);
		if (d1)
			*d1 = msg->d1;
		if (d2)
			*d2 = msg->d2;
		if (d3)
			*d3 = msg->d3;
   	if (LockSysSemaphore(-1)) {
   		FreeMsg(msg);
	    UnlockSysSemaphore();
	  }
		return (E_Ok);
	}
	//-------------------------
	// Queue thread at mailbox
	//-------------------------
	if (LockSysSemaphore(-1)) {
		thrd = GetRunningTCBPtr();
		RemoveFromReadyList(thrd-tcbs);
    UnlockSysSemaphore();
  }
	thrd->status |= TS_WAITMSG;
	thrd->hWaitMbx = hMbx;
	thrd->mbq_next = 0;
	if (LockSysSemaphore(-1)) {
		if (mbx->tq_head < 0) {
			thrd->mbq_prev = 0;
			mbx->tq_head = (thrd-tcbs)+1;
			mbx->tq_tail = (thrd-tcbs)+1;
			mbx->tq_count = 1;
		}
		else {
			thrd->mbq_prev = mbx->tq_tail;
			tcbs[mbx->tq_tail-1].mbq_next = thrd-tcbs;
			mbx->tq_tail = (thrd-tcbs)+1;
			mbx->tq_count++;
		}
    UnlockSysSemaphore();
  }
	//---------------------------
	// Is a timeout specified ?
	if (timelimit) {
        //asm { ; Waitmsg here; }
    	if (LockSysSemaphore(-1)) {
    	    InsertIntoTimeoutList(thrd-tcbs, timelimit);
    	    UnlockSysSemaphore();
        }
    }
  // Reschedule will cause control to pass to another thread.
  FMTK_Reschedule();
	// Control will return here as a result of a SendMsg or a
	// timeout expiring
	rt = GetRunningTCBPtr(); 
	if (rt->msg.type == MT_NONE)
		return (E_NoMsg);
	// rip up the envelope
	rt->msg.type = MT_NONE;
	rt->msg.dstadr = 0;
	rt->msg.retadr = 0;
	d1 = LinearToPhysical(GetRunningPID(), d1);
	d2 = LinearToPhysical(GetRunningPID(), d2);
	d3 = LinearToPhysical(GetRunningPID(), d3);
	if (d1)
		*d1 = rt->msg.d1;
	if (d2)
		*d2 = rt->msg.d2;
	if (d3)
		*d3 = rt->msg.d3;
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// PeekMsg()
//     Look for a message in the queue but don't remove it from the queue.
//     This is a convenince wrapper for CheckMsg().
// ----------------------------------------------------------------------------

long FMTK_PeekMsg (
	__reg("d0") hMBX hMbx,
	__reg("d1") long *d1,
	__reg("d2") long *d2,
	__reg("d3") long *d3
)
{
  return (CheckMsg(hMbx, d1, d2, d3, 0));
}

/* ---------------------------------------------------------------
	Description:
		Check for message at mailbox. If no message is
	available return immediately to the caller (CheckMsg() is
	non blocking). Optionally removes the message from the
	mailbox.
--------------------------------------------------------------- */

long FMTK_CheckMsg (
	__reg("d0") hMBX hMbx,
	__reg("d1") long *d1,
	__reg("d2") long *d2,
	__reg("d3") long *d3,
	__reg("d4") long qrmv
)
{
	MBX *mbx;
	MSG *msg;

	if (hMbx <= 0 || hMbx > NR_MBX)
		return (E_Arg);
	mbx = &mailbox[hMbx-1];
 	if (LockSysSemaphore(-1)) {
  	// check for a mailbox owner which indicates the mailbox
  	// is active.
  	if (mbx->owner <= 0 || mbx->owner > NR_ACB) {
  	    UnlockSysSemaphore();
  		return (E_NotAlloc);
      }
  	if (qrmv)
  		msg = DequeueMsg(mbx);
  	else
  		msg = MSGHandleToPointer(mbx->mq_head);
    UnlockSysSemaphore();
  }
	if (msg == null)
		return (E_NoMsg);
	d1 = LinearToPhysical(GetRunningPID(), d1);
	d2 = LinearToPhysical(GetRunningPID(), d2);
	d3 = LinearToPhysical(GetRunningPID(), d3);
	if (d1)
		*d1 = msg->d1;
	if (d2)
		*d2 = msg->d2;
	if (d3)
		*d3 = msg->d3;
	if (qrmv) {
   	if (LockSysSemaphore(-1)) {
   		FreeMsg(msg);
	    UnlockSysSemaphore();
    }
	}
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// Semaphore lock/unlock code.
// Ultimately calls a BIOS routine to access the semaphoric memory which is
// set in an atomic fashion.
// ----------------------------------------------------------------------------

int LockSysSemaphore(int retries)
{
	return(LockSemaphore(OSSEMA,retries));
}

void UnlockSysSemaphore()
{
	UnlockSemaphore(OSSEMA);
}

int LockIOFSemaphore(register int retries)
{
	return(LockSemaphore(IOFSEMA,retries));
}

void UnlockIOFSemaphore()
{
	UnlockSemaphore(IOFSEMA);
}

int LockKbdSemaphore(register int retries)
{
	return(LockSemaphore(KEYBD_SEMA,retries));
}

void UnlockKbdSemaphore()
{
	UnlockSemaphore(KEYBD_SEMA);
}

// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// TCB.c
// Task Control Block related functions.
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//                                                                          
// ============================================================================
//
#include "inc\config.h"
#include "inc\const.h"
#include "inc\types.h"
#include "inc\proto.h"
#include "inc\glo.h"
//#include "..\inc\TCB.h"

extern int hasUltraHighPriorityTasks;
extern void prtdbl(double);

extern hTCB FreeTCB;
extern TCB* tcbs;

hTCB GetRunningTCB() =
"\tmovec.l cpid,d0\r\n"
;

TCB* GetRunningTCBPtr()
{
	return (&tcbs[GetRunningPID()-1]);
}

TCB* TCBHandleToPointer(short int hTCB handle)
{
	if (handle <= 0)
		return (TCB*)0;
	return (&tcbs[handle-1]);
}

hTCB TCBPointerToHandle(TCB* ptr)
{
	hTCB h;

	if (ptr==NULL)
		return (0);	
	h = ptr - &tcbs[0];
	return (h+1);	
}

static hTCB iAllocTCB()
{
	TCB* p;
	hTCB h;

	if (FreeTCB<=0)
		return (0);
	h = FreeTCB;
	p = TCBHandleToPointer(FreeTCB);
	FreeTCB = p->next;
	return (h);
}

hTCB AllocTCB(hTCB* ph)
{
	hTCB h;

	LockSysSemaphore();
	h = iAllocTCB();
	UnlockSysSemaphore();
	if (ph)
		*ph = h;
	return (E_Ok);
}

static void iFreeTCB(hTCB h)
{
	TCB* p;
	
	p = TCBHandleToPointer(h);
	if (p) {
		p->next = FreeTCB;
		FreeTCB = h;
	}
}

int fnFreeTCB(hTCB h)
{
	LockSysSemaphore();
	iFreeTCB(h);	
	UnlockSysSemaphore();
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// These routines called only from within the timer ISR.
// ----------------------------------------------------------------------------

int InsertIntoReadyList(register hTCB ht)
{
	hTCB hq;
	TCB *p, *q;

//    __check(ht >=0 && ht < NR_TCB);
	p = TCBHandleToPointer(ht);
	if (p->priority > 31 || p->priority < 0)
		return (E_BadPriority);
	if (p->priority > 28)
	   hasUltraHighPriorityTasks |= (1 << p->priority);
	TCBSetStatusBit(ht, TS_READY);
	hq = readyQ[p->priority];
	// Ready list empty ?
	if (hq <= 0) {
		p->next = ht;
		p->prev = ht;
		readyQ[p->priority] = ht;
		return (E_Ok);
	}
	// Insert at tail of list
	q = TCBHandleToPointer(hq);
	p->next = hq;
	p->prev = q->prev;
	TCBHandleToPointer(q->prev)->next = ht;
	q->prev = ht;
	return (E_Ok);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int RemoveFromReadyList(register hTCB ht)
{
	TCB *t,* p, *q;

	//    __check(ht >=0 && ht < NR_TCB);
	t = TCBHandleToPointer(ht);
	if (t == NULL)
		return (E_Ok);
	if (t->priority > 31 || t->priority < 0)
		return (E_BadPriority);
	if (ht==readyQ[t->priority])
		readyQ[t->priority] = t->next;
	if (ht==readyQ[t->priority])
		readyQ[t->priority] = 0;
	p = TCBHandleToPointer(t->next);
	if (p)
		p->prev = t->prev;
	q = TCBHandleToPointer(t->prev);
	if (q)
		q->next = t->next;
	t->next = -1;
	t->prev = -1;
	// clear all the status bits
	TCBClearStatusBit(t, -1);
	return (E_Ok);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int InsertIntoTimeoutList(register hTCB ht, register int to)
{
	TCB *p, *q, *t;

	//    __check(ht >=0 && ht < NR_TCB);
	t = TCBHandleToPointer(ht);
	if (t == NULL)
		return (E_Ok);
	if (TimeoutList <= 0) {
		t->timeout = to;
		TimeoutList = ht;
		t->next = -1;
		t->prev = -1;
		return (E_Ok);
	}

	q = null;
	p = TCBHandleToPointer(TimeoutList);

	if (p) {
		while (to > p->timeout) {
			to -= p->timeout;
			q = p;
			p = TCBHandleToPointer(p->next);
		}
	}
	t->next = TCBPointerToHandle(p);
	t->prev = TCBPointerToHandle(q);
	if (p) {
		p->timeout -= to;
		p->prev = ht;
	}
	if (q)
		q->next = ht;
	else
		TimeoutList = ht;
	TCBSetStatusBit(t, TS_TIMEOUT);
	return (E_Ok);
};

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int RemoveFromTimeoutList(hTCB ht)
{
  TCB *t,* nxt, *prv;
  
//    __check(ht > 0 && ht <= NR_TCB);
  t = TCBHandleToPointer(ht);
  if (t == NULL)
  	return(E_Ok);
  if (t->next) {
  	nxt = TCBHandleToPointer(t->next);
  	if (nxt) {
			nxt->prev = t->prev;
			nxt->timeout += t->timeout;
		}
  }
  if (t->prev > 0) {
  	prv = TCBHandleToPointer(t->prev);
		prv->next = t->next;
	}
	// clear all the status bits
	TCBClearStatusBit(t, -1);
  t->next = -1;
  t->prev = -1;
  return (E_Ok);
}

// ----------------------------------------------------------------------------
// Pop the top entry from the timeout list.
// ----------------------------------------------------------------------------

hTCB PopTimeoutList()
{
  TCB *p;
  hTCB h;

  h = TimeoutList;
  if (TimeoutList > 0 && TimeoutList <= NR_TCB) {
  	p = TCBHandleToPointer(TimeoutList);
    TimeoutList = p->next;
    if (TimeoutList > 0 && TimeoutList <= NR_TCB) {
	  	p = TCBHandleToPointer(TimeoutList);
      p->prev = -1;
    }
  }
  return (h);
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void DumpTaskList()
{
   TCB *p, *q;
   int n;
   int kk;
   hTCB h, j;
 
//     printf("pi is ");
//     prtdbl(3.141592653589793238,10,6,'E');
	printf("CPU Pri Stat Task Prev Next Timeout\r\n");
	for (n = 0; n < 8; n++) {
		h = readyQ[n];
		if (h > 0 && h <= NR_TCB) {
			q = TCBHandleToPointer(h);
			p = q;
			kk = 0;
			do {
//                 if (!chkTCB(p)) {
//                     printf("Bad TCB (%X)\r\n", p);
//                     break;
//                 }
				j = (p - tcbs) + 1;
				printf("%3d %3d  %02X  %04X %04X %04X %08X %08X\r\n", p->affinity, p->priority, p->status, (int)j, p->prev, p->next, p->timeout, p->ticks);
				if (p->next <= 0 || p->next > NR_TCB)
					break;
				p = TCBHandleToPointer(p->next);
				if (getcharNoWait()==3)
					goto j1;
				kk = kk + 1;
			} while (p != q && kk < 10);
		}
	}
	printf("Waiting tasks\r\n");
	h = TimeoutList;
	while (h > 0 && h <= NR_TCB) {
		p = TCBHandleToPointer(h);
		printf("%3d %3d  %02X  %04X %04X %04X %08X %08X\r\n", p->affinity, p->priority, p->status, (int)j, p->prev, p->next, p->timeout, p->ticks);
		h = p->next;
		if (getcharNoWait()==3)
			goto j1;
	}
j1:  ;
}


