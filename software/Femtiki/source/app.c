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
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include "inc/config.h"
#include "inc/const.h"
#include "inc/types.h"
#include "inc/proto.h"
#include "inc/glo.h"

#define NR_APPS	32
#define MMU_WR	4
#define MMU_RD	2
#define MMU_EX	1

#define MMU_RW	MMU_WR|MMU_RD

void FreeACB(__reg("d0")long h) =
"\tmove.l d1,-(sp)\r\n"
"\tmove.l _ACBList,d1\r\n"
"\tbclr d0,d1\r\n"
"\tmove.l d1,_ACBList\r\n"
"\tmove.l (sp)+,d1\r\n"
;
// ToDo: Add UI data

long FMTK_StartApp(__reg("d0") long asrec, __reg("d1") long hParent)
{
	int mapno, omapno;
	int ret;
	ACB *pACB, *pParentACB;
	int32_t *pScrn;
	int *pStack;
	int ncpages, ndpages, nhpages, nspages, nn, nCardPages;
	int page;
	int *p;
	uint16_t *pCode;
	char *pData;
	int ndx;
	long info;
	hACB h;
	AppStartupRec *asr;

	DisplayStringCRLF("Starting App");
	asr = (AppStartupRec *)asrec;
	h = FindFreeACB();
	if (h == 0)
		return (E_NoMoreACBs);
	DisplayLEDS(1);
	// Allocate memory for the ACB
	pACB = (ACB*)mem_alloc(1,sizeof(ACB),14);
	if (pACB==NULL)
		goto err1;
	memset(pACB,0,sizeof(ACB));
	DisplayLEDS(2);

	// Keep track of the physical address of the ACB
	ACBPtrs[h] = pACB;
	// Allocate memory for environment area
	pACB->pEnv = (char*)mem_alloc(h,16384,6);
	if (pACB->pEnv==NULL)
		goto err1;
	pParentACB = ACBHandleToPointer(hParent);
	if (pParentACB)
		memcpy(pACB->pEnv, pParentACB->pEnv, 16384);
	DisplayLEDS(3);
	
	// Allocate memory for virtual video
	pACB->pVirtVidMem = (uint32_t*)mem_alloc(h,8192,6);
	if (pACB->pVirtVidMem == NULL)
		goto err1;
	pACB->magic = ACB_MAGIC;
	DisplayLEDS(4);
	
	pACB->garbage_list = null;
	// Allocate memory for card space
	if (asr->hasGarbageCollector) {
		pACB->pCard = mem_alloc(h,
			(asr->uidatasize>>8)+			// First level memory
			(asr->uidatasize>>16),
		6);
	}
	//pACB->CardMemory = MapCardMemory();
	nCardPages = 2;	// +1 for ACB

	pACB->pVidMem = pACB->pVirtVidMem;
	pACB->VideoRows = 32;
	pACB->VideoCols = 64;
	pACB->CursorRow = 0;
	pACB->CursorCol = 0;
	pACB->NormAttr = 0x87fc0000;

	// Allocate storage space for code and copy
	pCode = (uint16_t*)mem_alloc(h,asr->codesize+16383,5);
	if (pCode==NULL)
		goto err1;
	memcpy(pCode,&asr->pCode,asr->codesize);
	pACB->pCode = pCode;
	DisplayLEDS(5);

	// Allocate storage space for initialized data
	// and copy from start-up record
	pData = (char*)mem_alloc(h,asr->datasize+8191,6);
	if (pData==NULL)
		goto err1;
	memcpy(pData,&asr->pData,asr->datasize);
	pACB->pData = pData;
	DisplayLEDS(6);

	/*
	pACB->Heap->pHeap = (MBLK *)((1+ndpages+ncpages) << 13);
	pACB->Heap->size = (((asr->heapsize + 8191) >> 13) << 13);
	pACB->Heap->next = null;
	pACB->Heap->shareMap = (1 << mapno);
	*/
	//pACB->Heap.addr = (MBLK *)((ndpages+ncpages+nCardPages) << 13)
	//		| 0xFFFFF00000000000L;
	//CreateHeap((void *)((1+ndpages+ncpages) << 14) | 0xFFFFF00000000000L,
	//	(((asr->heapsize + 16383) >> 14) << 14));
	//InitHeap(pACB->Heap->pHeap, nhpages << 13);

	// Start the startup thread
	info = ((asr->priority & 0xff) << 8) | (h  & 0xff);
	FMTK_StartTask(
		(long)pCode,			// start address
		(long)nspages << 14,
		(long)&pACB->commandLine[0],	// parameter
		(long)info,
		(long)asr->affinity
	);
	DisplayLEDS(7);
	return (E_Ok);
err1:
	if (pACB) {
		if (pACB->pData)
			mem_free(h,pACB->pData);
		if (pACB->pCode)
			mem_free(h,pACB->pCode);
		if (pACB->pVirtVidMem) 
			mem_free(h,pACB->pVirtVidMem);
		if (pACB->pEnv)
			mem_free(h,pACB->pEnv);
		mem_free(1,pACB);
	}
	FreeACB(h);
}
