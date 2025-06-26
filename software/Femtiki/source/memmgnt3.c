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
#include <stdio.h>
#include <string.h>
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

extern char *os_brk;

extern unsigned long* lastSearchedPAMWord;
extern int errno;
char *osmem;
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
PTE* GetPageTableEntryAddress(hACB ha, char* virtadr, int alloc);
void *pt_alloc(int amt, int acr);

//unsigned __int32 *mmu_entries;
extern unsigned long PAM[(NPAGES+1)/32];
extern PMTE PMT[NPAGES];
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
  osmem = (char *)mem_alloc(1, 16777216,7);
  // Allocate video frame buffer
  pACB = GetRunningACBPtr();
//  pACB-> = pt_alloc(8388607,7);
	DBGDisplayChar('a');
}

// ----------------------------------------------------------------------------
// Alloc enough pages to fill the requested amount.
// ----------------------------------------------------------------------------

void *mem_alloc(hACB hAcb, int amt, int acr)
{
	int npages;
	int nn;
	char* page;
	unsigned long* pte;
	unsigned long en;
	ACB* pacb;
	hACB hAcb;
	char* brk;

	acr &= 7;
	DBGDisplayChar('B');
	amt = round16k(amt);
	npages = amt >> 14;
	if (npages==0)
		return (NULL);
	DBGDisplayChar('C');
	brk = NULL;
	if (npages < sys_pages_available) {
		sys_pages_available -= npages;
		pacb = ACBHandleToPointer(hAcb);
		brk = pacb->brk;
		pacb->brk += amt;
		for (nn = 0; nn < npages-1; nn++) {
			pte = (unsigned long*)GetPageTableEntryAddress(hAcb,brk+(nn << 14),1);
			en = (unsigned long)pte;
			en &= 0xffffc000UL;
			en |= 0x2000 | acr;	// 0x2000 = page present bit
			*pte = en;
		}
		pte = (unsigned long*)GetPageTableEntryAddress(hAcb,brk+(nn << 14),1);
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

char *mem_free(hACB h, char *vadr)
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
		while (LockMMUSemaphore(-1)==0);
		last_page = 0;
		if (pe = (unsigned long*)GetPageTableEntryAddress(h,vadr,0)) {
			pte = *pe;
			last_page = (pte & 0x800) != 0;
			while (LockPMTSemaphore(-1)==0);
			if (PMT[vpageno].share_count != 0) {
				PMT[vpageno].share_count--;
				if (PMT[vpageno].share_count==0) {
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
	h = GetRunningACB();
	if (size > 0) {
		p = mem_alloc(h,size,7);
		if (p==NULL)
			errno = E_NoMem;
		return (p);
	}
	pAcb = GetRunningACBPtr();
	if (size < 0) {
		size = -size;
		if (size > (unsigned long)pAcb->brk) {
			errno = E_NoMem;
			return ((void*)-1);
		}
		r = p = pAcb->brk - size;
		for(q = p; q < pAcb->brk;)
			q = mem_free(h,q);
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
