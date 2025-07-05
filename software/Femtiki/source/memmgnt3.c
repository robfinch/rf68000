// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "inc/config.h"
#include "inc/const.h"
//#include "../inc/errno.h"
#include "inc/types.h"
#include "inc/proto.h"

#define NPAGES 131072	//-4096		// 2048 OS pages + 2048 Video
#define CARD_MEMORY		0xFFCE0000
#define IPT_MMU				0xFFDCD000
#define IPT
#define MMU	0xFDC00000

extern PDE_u sys_pd[512];
extern PTE_u kernel_pt[6][2048];
char *pNextPT;
extern long nPagesFree;
extern char *os_brk;
extern hMBX MemExch;

extern long min(long, long);
extern unsigned long lastSearchedPAMWord;
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
PTE* GetPageTableEntryAddress(hACB ha, char* virtadr, int alloc);
void *pt_alloc(int amt, int acr);

//unsigned __int32 *mmu_entries;
extern unsigned long PAM[(NPAGES+1)/32];
extern PMTE PMT[NPAGES];
extern unsigned long* page_table;
extern char *brks[512];
extern unsigned long pebble[512];

static void ramtest1(long aa, long bb)
{
	long *p;
	int errcount;
	
	errcount = 0;
	DBGHideCursor(1);
	puts("Writing code to ram\r");
	for (p = (long*)0x60000000; (unsigned long)p < 0x7fffffe0; p += 2) {
		if (((long)p & 0xfffff)==0) {
//			putnum((unsigned long)p>>20,5,',',' ');
			printf("%d MB\r", (unsigned long)p>>20);
//			putchar('M');
//			putchar('B');
//			putchar('\r');
		}
		p[0] = aa;
		p[1] = bb;
	}
	puts("\r\nReadback code from ram\r");
	for (p = (long*)0x60000000; (unsigned long)p < 0x7fffffe0; p += 2) {
		if (((long)p & 0xfffff)==0) {
//			putnum((unsigned long)p>>20,5,',',' ');
			printf("%d MB\r", (unsigned long)p>>20);
//			putchar('M');
//			putchar('B');
//			putchar('\r');
		}
		if (p[0] != aa || p[1] != bb) {
			errcount++;
			if (errcount > 10)
				break;
		}
	}
	printf("\r\nerrors: %d\r\n", errcount);
//	putnum(errcount,5,',',' ');
}

// Checkerboard ram test routine.

void ramtest()
{
	ramtest1(0x55555555L, 0xaaaaaaaaL);	
	ramtest1(0xaaaaaaaaL, 0x55555555L);	
	putchar('\r');
	putchar('\n');
	DBGHideCursor(0);
}


//private __int16 pam[NPAGES];	
// There are 128, 4MB pages in the system. Each 4MB page is composed of 64 64kb pages.
//private int pam4mb[NPAGES/64];	// 4MB page allocation map (bit for each 64k page)
//int syspages;					// number of pages reserved at the start for the system
//int sys_pages_available;	// number of available pages in the system
//int sys_4mbpages_available;

static unsigned long round8k(unsigned long amt)
{
  amt += 8191;
  amt &= PAGE_MASK;
  return (amt);
}

/* -----------------------------------------------------------------------------
		Get the page directory for the running app.

	Parameters:
		none
	Returns:
		pointer to page directory.
----------------------------------------------------------------------------- */

PDE* GetRunningPD()
{
	PDE* pde;
	hACB ha;
	ACB* pa;

	ha = GetRunningAppid();
	if (ha < 2)
		pde = &sys_pd;
	else {
		pa = ACBHandleToPointer(ha);
		pde = &pa->pd;
	}
	return (pde);
}

/* -----------------------------------------------------------------------------
		Mark a page as allocated.

	Parameters:
		address of page to mark
	Returns:
		none
----------------------------------------------------------------------------- */

void MarkPage(unsigned long page)
{
	long wd;
	long bit;

	page -= DRAM_BASE;
	wd = page >> (LOG_PAGESIZE+5);
	bit = (page >> LOG_PAGESIZE) & 31;
	PAM[wd] |= (1 << bit);
}

/* -----------------------------------------------------------------------------
		Mark a page as available.

	Parameters:
		address of page to mark
	Returns:
		none
----------------------------------------------------------------------------- */

void UnmarkPage(unsigned long page)
{
	long wd;
	long bit;

	page -= DRAM_BASE;
	wd = page >> (LOG_PAGESIZE+5);
	bit = (page >> LOG_PAGESIZE) & 31;
	PAM[wd] &= ~(1 << bit);
}

/* -----------------------------------------------------------------------------
		Find a free page and allocate it. The search begins where it last left
	off under the notion that prior pages are more likely already allocated.

	Side Effects:
		marks page as allocated
	Parameters:
		none
	Returns:
		physical address of page
----------------------------------------------------------------------------- */

char* FindFreePage()
{
	long count = NPAGES/32;
	unsigned long nn;
	unsigned long wd;
	unsigned long bit;
	unsigned long page;
	unsigned long one;

	for (nn = lastSearchedPAMWord; count > 0; nn++, count--) {
		if (nn > 32767)
			nn = 0;
		wd = PAM[nn];
		if (wd != 0xffffffffUL) {
			one = 1;
			for (bit = 0; bit < 32; bit++) {
				if ((wd & 1)==0) {
					PAM[nn] |= one;		// Mark page allocated
					page = 0x40000000 | (nn << (5+LOG_PAGESIZE)) | (bit << LOG_PAGESIZE);
					lastSearchedPAMWord = nn;
					return ((char*)page);
				}
				wd >>= 1;
				one <<= 1;
			}
		}
	}
	return (NULL);
}

/* -----------------------------------------------------------------------------
		Find a run of pages in the linear address space that could be allocated.

		Parameters:
			search_area:	1 = userland, 0 = kernel address space
			num_pages:		number of pages needed
----------------------------------------------------------------------------- */

unsigned long FindRun(long search_area, unsigned long num_pages)
{
	PDE* pde,* spde, * pd;
	PDE_u pdeu;
	int ndx;
	int sb; 		// search begin
	int se;			// search end
	unsigned long pc;
	unsigned long la;
	

	pde = GetRunningPD();	
	pc = num_pages;
	// The first eight page tables are preallocated for the OS boot area and
	// video RAM. Do not bother searching in these pages.
	if (search_area) {
		sb = 8;
		se = 128;
	}
	else {
		sb = 128;
		se = 256;
	}
	for (ndx = sb; ndx < se; ndx++) {
		pd = &pde[ndx];
		pde = pd;
		pdeu.pde = *pde;
		if (pdeu.l==0xffffffffUL) {
			spde = pde;
			while (pdeu.l==0xffffffffUL) {
				pc--;
				if (pc==0) {
					pdeu.pde = *spde;
					la = pdeu.l;
					la &= PAGE_MASK;
					return (la);
				}
				ndx++;
				pde = &pd[ndx];
			}
		}
		else {
			pc = num_pages;
		}
	}
	return (0);
}

/* ----------------------------------------------------------------------------
		Adds alias pages to the page tables of the selected app. Maps physical
	pages from a given app into the address space of the current app.

	Parameters:
		1 = linear address of first page of new alias entries (from FindRun)
		2 = number of pages to alias
		3 = linear address of pages to alias (from other process)
		4 = Process number of app we are aliasing

	Returns:
		nothing
----------------------------------------------------------------------------- */

void AddAliasRun(long la, long num_pages, long pMem, long h)
{
	PDE* pd;
	int pd_ndx;
	long pt_ndx;
	unsigned long phys;
	PDE pde;
	unsigned long pta;
	PTE pte;
	PDE_u pdeu;
	PTE_u pteu;
	
	pd = GetRunningPD();
	for (; num_pages > 0; num_pages--) {
		pd_ndx = la >> 24;
		pt_ndx = (la >> LOG_PAGESIZE) & 0x7ff;
		pdeu.pde = pd[pd_ndx];
		pta = pdeu.l;
		pta &= PAGE_MASK;
		// Get the physical address of the memory to alias.
		phys = (unsigned long)LinearToPhysical(h,(char*)pMem);
		phys &= PAGE_MASK;
		pteu.l = phys;
		pteu.pte.present = 1;
		pteu.pte.alias = 1;
		pteu.pte.s = 0;
		pteu.pte.r = 1;
		pteu.pte.w = 1;
		pteu.pte.x = 1;
		if (num_pages==1)
			pteu.pte.end_of_run = 1;
		((PTE*)(pta))[pt_ndx] = pteu.pte;
		// Put linear address in upper half of PD.
		pteu.l = la;
		pteu.pte.present = 1;
		pteu.pte.alias = 1;
		pteu.pte.s = 0;
		pteu.pte.r = 1;
		pteu.pte.w = 1;
		pteu.pte.x = 1;
		if (num_pages==1)
			pteu.pte.end_of_run = 1;
		((PTE*)(pta))[pt_ndx+256] = pteu.pte;
		PMT[(phys >> LOG_PAGESIZE) & 0x1ffff].share_count++;
		// Advance the addresses by a page
		pMem += MEM_PAGE_SIZE;
		la += MEM_PAGE_SIZE;
	}
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

/* ----------------------------------------------------------------------------
		System page tables need to be added to the address space of all the 
	applications.
---------------------------------------------------------------------------- */

long AddSystemPageTable()
{
	unsigned long phys;
	ACB* pa;
	PDE* pde,* spde, * pd;
	hACB ha;
	int ndx;
	PDE pde1;
	PDE_u pdeu;
	
	if (nPagesFree==0)
		return (E_NoMem);
	if (pNextPT==NULL)
		return (E_NoMem);
	phys = (unsigned long)LinearToPhysical(1, pNextPT)
	if (phys == 0)
		return (E_NoMem);
	// Find an unused entry in the PD.
	pd = &sys_pd;
	for (ndx = 128; ndx < 256; ndx++) {
		pdeu.pde = pd[ndx];
		if (pdeu.l==0xffffffff) {
			pdeu.l = phys;
			pdeu.pde.present = 1;
			pdeu.pde.s = 1;
			pdeu.pde.r = 1;
			pdeu.pde.w = 1;
			pd[ndx] = pdeu.pde;
			pdeu.l = (uint32_t)pNextPT & PAGE_MASK;
			pd[ndx+256] = pdeu.pde;
			break;
		}
	}
	// Could a PDE be allocated? If not no memory available.
	if (ndx > 255)
		return (E_NoMem);
	// Now, update the corresponding entry in each PD.
	for (ha = 2; ha < 33; ha++) {
		pa = ACBHandleToPointer(ha);
		if (pa) {
			pd = &pa->pd;
			pde = &pd[ndx];
			pdeu.l = phys;
			pdeu.pde.present = 1;
			pdeu.pde.s = 1;
			pdeu.pde.r = 1;
			pdeu.pde.w = 1;
			pd[ndx] = pdeu.pde;
			pdeu.l = (uint32_t)pNextPT & PAGE_MASK;
			pd[ndx+256] = pdeu.pde;
		}
	}
	// Allocate the next page table
	pNextPT = AllocPageTable();
	return (E_Ok);
}

/* ----------------------------------------------------------------------------
		Adds a user page table and inserts it into the page directory for the
	app.
---------------------------------------------------------------------------- */

long AddUserPageTable()
{
	hACB ha;
	unsigned long phys;
	PDE* pde,* spde, * pd;
	int ndx;
	PDE_u pdeu;
	
	if (nPagesFree==0)
		return (E_NoMem);
	
	ha = GetRunningAppid();
	pd = GetRunningPD();
	for (ndx = 8; ndx < 128; ndx++) {
		pdeu.pde = pd[ndx];
		if (pdeu.l==0xffffffff) {
			phys = (unsigned long)LinearToPhysical(ha, pNextPT)
			pdeu.l = phys;
			pdeu.pde.present = 1;
			pdeu.pde.s = 0;
			pdeu.pde.r = 1;
			pdeu.pde.w = 1;
			pd[ndx] = pdeu.pde;
			pdeu.l = ((uint32_t)pNextPT & PAGE_MASK);
			pdeu.pde.present = 1;
			pdeu.pde.s = 0;
			pdeu.pde.r = 1;
			pdeu.pde.w = 1;
			pdeu.pde.x = 1;
			pd[ndx+256] = pdeu.pde;
			pNextPT = AllocPageTable();
			return (E_Ok);
		}
	}
	return (E_NoMem);
}

/* -----------------------------------------------------------------------------
		Allocate pages of system memory.
----------------------------------------------------------------------------- */

long FMTK_AllocSystemPages(__reg("d0") long num_pages, __reg("d1") long ppAddr)
{
	char* page;
	long re;
	long d1,d2,d3;

	if (num_pages==0 || ppAddr==0)
		return(E_Arg);
	FMTK_WaitMsg(MemExch,(long)&d1,(long)&d2,(long)&d3,-1);
	if (num_pages > nPagesFree) {
		re = E_NoMem;
		goto j1;
	}
	do {
		page = (char *)FindRun(0,num_pages);
		if (page==NULL) {
			re = AddSystemPageTable();
			if (re)
				goto j1;
		}
	} while (page == NULL);
	*(char **)ppAddr = page;
j1:
	// Send a message to allow next request to be processed.
	FMTK_SendMsg(MemExch,0xfffffff1,0xfffffff1,0xfffffff1);
	return (re);
}

/* -----------------------------------------------------------------------------
		Allocate pages of user memory.
----------------------------------------------------------------------------- */

long FMTK_AllocPages(__reg("d0") long num_pages, __reg("d1") long ppAddr)
{
	char* page;
	long re;
	long d1,d2,d3;

	if (num_pages==0 || ppAddr==0)
		return(E_Arg);
	FMTK_WaitMsg(MemExch,(long)&d1,(long)&d2,(long)&d3,-1);
	if (num_pages > nPagesFree) {
		re = E_NoMem;
		goto j1;
	}
	do {
		page = (char *)FindRun(1,num_pages);
		if (page==NULL) {
			re = AddUserPageTable();
			if (re)
				goto j1;
		}
	} while (page == NULL);
	*(char **)ppAddr = page;
j1:
	// Send a message to allow next request to be processed.
	FMTK_SendMsg(MemExch,0xfffffff1,0xfffffff1,0xfffffff1);
	return (re);
}

// ----------------------------------------------------------------------------
// Get the address of the page table entry for a given linear address.
// If there is no mapping for the linear address, create one by allocating a
// page table.
//
//	Parameters:
//	1) handle of app containing linear address
//	2) linear address as a pointer
//	3) flag to allocate if no translation for linear address exists.
//
// 	Returns:
//		pointer to page table entry, NULL if no memory available.
// ----------------------------------------------------------------------------

PTE* GetPageTableEntryAddress(hACB hAcb, char* linear, int alloc)
{
	ACB* pAcb;	
	PDE* pde;
	PTE* pte;
	unsigned int ndx;
	unsigned long iLinear;
	unsigned long pta;
	unsigned long page;
	PTE_u pteu;
	PDE_u pdeu;
	
	iLinear = (unsigned long)linear;
	if (hAcb < 2)
		pde = &sys_pd;
	else {
		pAcb = ACBHandleToPointer(hAcb);
		pde = &pAcb->pd;
	}
	ndx = iLinear >> 24;
	pdeu.pde = pde[ndx];
	pta = pdeu.l;
	if (pta==0xffffffffUL) {
		if (alloc) {
			pta = (unsigned long)AllocPageTable();
			if (pta == 0xffffffffUL) {
				errno = E_NoMem;
				return (NULL);
			}
			// Mark all pages with special constant for empty page.
			memset((char *)pta,-1,MEM_PAGE_SIZE);
			pta |= 0x7;	// user read-write-execute
			pdeu.l = pta;
			pde[ndx] = pdeu.pde;
			/* Stuff the linear address of the page table in the shadow area.
			pdeu.l = (unsigned long)&pde[ndx];
			pde[ndx+256] = pdeu.pde;
			*/
		}
		// Address could not be found and not allocating.
		else
			return (NULL);
	}
	pta &= PAGE_MASK;
	pte = (PTE*)pta;
	ndx = (iLinear >> LOG_PAGESIZE) & 0x7ff;
	pteu.pte = pte[ndx];
	pte = &pte[ndx];
	if (pteu.l == 0xffffffffUL) {
		if (alloc) {
			page = (unsigned long)FindFreePage();
			if (page==0)
				return (NULL);
			// Make a system page for system apps?
			if (hAcb < 2 || pAcb->is_system)
				page |= 0x100F;
			else
				page |= 0x1007;	// page present + user read-write-execute
			pteu.l = page;
			*pte = pteu.pte;
		}
		else
			return (NULL);
	}
	return (pte);
}

// ----------------------------------------------------------------------------
// 		Translate a linear address to a physical one. This function will
//	allocate a physical page if there is no valid translation.
//
//	Parameters:
//		handle of app containing linear address
//		pointer which is linear address
//	Returns:
//		physical address of page, NULL if insufficient memory
// ----------------------------------------------------------------------------

char* LinearToPhysical(hACB hAcb, char* linear)
{
	PTE* pte;
	unsigned long iLinear;
	unsigned long phys;
	unsigned long ndx;
	
	pte = GetPageTableEntryAddress(hAcb, linear, 1);
	if (pte == NULL)
		return (NULL);
	phys = (unsigned long)pte;
	phys &= PAGE_MASK;
	ndx = iLinear & 0x1fffUL;
	phys |= ndx;
	return ((char*)phys);
}

// ----------------------------------------------------------------------------
//		Alias memory.
// ----------------------------------------------------------------------------

long FMTK_AliasMem(
	__reg("d0") long pMem,
	__reg("d1") long cbMem,
	__reg("d2") long hApp,
	__reg("d3") long ppAliasRet
)
{
	unsigned long la;
	unsigned long pages_needed;
	hACB ra;
	ACB* pa;
	long er;

	if (hApp == (ra = GetRunningAppid()))
		return (0);
	pa = ACBHandleToPointer(hApp);
	pages_needed = (((pMem & PAGE_MASK) + cbMem) >> LOG_PAGESIZE) + 1;
	do {
		la = FindRun(pa->is_system?0:1,pages_needed);
		if (la==0) {
			if (pa->is_system)
				er = AddSystemPageTable();
			else 
				er = AddUserPageTable();
			if (er)
				return (er);
		}
	} while(la==0);
	AddAliasRun(la, pages_needed, pMem, hApp);
	la |= (pMem & ~PAGE_MASK);
	*(unsigned long*)ppAliasRet = la;
	return (E_Ok);
}


// ----------------------------------------------------------------------------
// Memory is de-aliased but not deallocated.
// ----------------------------------------------------------------------------

long FMTK_DeAliasMem(__reg("d0") long hAcb, __reg("d1") long pMem, __reg("d2") long len)
{
	PTE* pte;
	PTE_u pteu;
	char *phys;
	int eor = 0;
	
	pMem &= PAGE_MASK;
	for (; len > 0; len -= min(MEM_PAGE_SIZE,len)) {
		pte = GetPageTableEntryAddress(hAcb, (char *)pMem, 0);
		if (pte) {
			pteu.pte = *pte;
			eor = pteu.pte.end_of_run;
			if (pteu.pte.alias) {
				pteu.l = 0;
				pteu.pte.present = 1;
				pteu.pte.s = 1;
				pteu.pte.r = 1;
				pteu.pte.w = 1;
				PMT[pteu.pte.page & 0x1ffff].share_count--;
				pteu.pte.page = 0x7ffff;
				*pte = pteu.pte;
			}
		}
		if (eor)
			return ((len - min(MEM_PAGE_SIZE,len) > 0) ? E_BadAlias : E_Ok);
		pMem += MEM_PAGE_SIZE;
	}
	return (E_Ok);
}


// ----------------------------------------------------------------------------
// 		Initialize the system page directory and page tables.
// ----------------------------------------------------------------------------

void init_sys_page_tables()
{
	int nn;

	for (nn = 0; nn < 512; nn++)
		sys_pd[nn].l = 0xffffffffUL;
	// Lowest 16MB is kernel local vars and boot area.
	sys_pd[0x000].l = (long)&kernel_pt[0] + 0x100f;
	sys_pd[0x100].l = 0x00000000;
	for (nn = 0; nn < 2048; nn++)
		kernel_pt[0][nn].l = 0x00000000 + (nn * MEM_PAGE_SIZE) +0x100f;	// present, system, read-write-execute
	// Allocate pages for video
	sys_pd[0x004].l = (long)&kernel_pt[1] + 0x100e;
	sys_pd[0x104].l = (long)0x00400000;
	for (nn = 0; nn < 2048; nn++) {
		MarkPage(nn);
		kernel_pt[1][nn].l = 0x40000000 + (nn * MEM_PAGE_SIZE) +0x100f;
	}
	// Inter-CPU communication area
	sys_pd[0x0c0].l = (long)&kernel_pt[2] + 0x100f;
	sys_pd[0x1c0].l = 0xc0000000;
	for (nn = 0; nn < 2048; nn++)
		kernel_pt[2][nn].l = 0xC0000000 + (nn * MEM_PAGE_SIZE) +0x100f;
	// Device discovery black-boxes
	sys_pd[0x0d0].l = (long)&kernel_pt[3] + 0x100f;
	sys_pd[0x1d0].l = 0xd0000000;
	for (nn = 0; nn < 2048; nn++)
		kernel_pt[3][nn].l = 0xD0000000 + (nn * MEM_PAGE_SIZE) +0x100f;
	// IO devices
	sys_pd[0x0fd].l = (long)&kernel_pt[4] + 0x100f;
	sys_pd[0x1fd].l = 0xfd000000;
	for (nn = 0; nn < 2048; nn++)
		kernel_pt[4][nn].l = 0xFD000000 + (nn * MEM_PAGE_SIZE) +0x100f;
	// Last page is IRQ ack
	sys_pd[0x0ff].l = (long)&kernel_pt[5] + 0x100f;
	sys_pd[0x1ff].l = 0xff000000;
	for (nn = 0; nn < 2048; nn++)
		kernel_pt[5][nn].l = 0xFD000000 + (nn * MEM_PAGE_SIZE) +0x100f;
}

// ----------------------------------------------------------------------------
// Must be called to initialize the memory system before any
// other calls to the memory system are made.
// Initialization includes setting up the linked list of free pages and
// setting up the 128k page bitmap.
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
	lastSearchedPAMWord = 0;
	memset(PAM, 0, NPAGES/8);
	
	init_sys_page_tables();

	// Send a dummy message to memory exchange.
	FMTK_SendMsg(MemExch,0xfffffff1,0xfffffff1,0xfffffff1);
	FMTK_AllocSystemPages(1, (long)&pNextPT);

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
	char* brk;

	acr &= 7;
	DBGDisplayChar('B');
	amt = round8k(amt);
	npages = amt >> LOG_PAGESIZE;
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
			pte = (unsigned long*)GetPageTableEntryAddress(hAcb,brk+(nn << LOG_PAGESIZE),1);
			en = (unsigned long)pte;
			en &= PAGE_MASK;
			en |= 0x1000 | acr;	// 0x1000 = page present bit
			*pte = en;
		}
		pte = (unsigned long*)GetPageTableEntryAddress(hAcb,brk+(nn << LOG_PAGESIZE),1);
		en = (unsigned long)pte;
		en &= PAGE_MASK;
		en |= 0x1400 | acr;	// 0x1400 = page present bit, plus last page
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

	count = 0;
	do {
		vpageno = ((unsigned long)vadr >> LOG_PAGESIZE) & 0x1ffff;
		while (LockMMUSemaphore(-1)==0);
		last_page = 0;
		if (pe = (unsigned long*)GetPageTableEntryAddress(h,vadr,0)) {
			pte = *pe;
			last_page = (pte & 0x400) != 0;
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
		vadr += MEM_PAGE_SIZE;
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
	size = round8k(size);
	h = GetRunningAppid();
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
			pte &= 0xfffffbffUL;
			pte |= 0x00000400UL;
			*pe = pte;
			UnlockMMUSemaphore();
		}
	}
	else {	// size==0
		p = pAcb->brk;
	}
	return (p);
}
