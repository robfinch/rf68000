; ============================================================================
;        __
;   \\__/ o\    (C) 2020-2025  Robert Finch, Waterloo
;    \  __ /    All rights reserved.
;     \/_//     robfinch<remove>@finitron.ca
;       ||
;  
;
; BSD 3-Clause License
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, this
;    list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its
;    contributors may be used to endorse or promote products derived from
;    this software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; ============================================================================

	include "inc\config.x68"

E_NoMem	equ 33

	bss
_lastSearchedPAMWord:
	ds.l	1
_ACBList
	ds.l	1

	global _lastSearchedPAMWord

	code
	even
; ------------------------------------------------------------------------------
; Clear a page of memory
;
; Parameters:
;		a0 = pointer to page
; Returns:
;		none
; ------------------------------------------------------------------------------

_ClearPage:
	movem.l a1/a2,-(sp)
	move.l a0,a1
	move.l a0,a2
	add.l #PAGESZ,a2
.0001:
	clr.l (a1)
	lea 4(a1),a1
	cmp.l a2,a1
	blo .0001
	movem.l (sp)+,a1/a2
	rts

; ------------------------------------------------------------------------------
; Search for a memory page that is not used yet. Mark it as in use and return
; the address. The search proceeds 32-bits at a time. During the search 32
; pages are marked allocated in an atomic fashion to prevent interference from
; another source. Once it is determined which individual page to allocate the
; original state of the 32 pages is restored, plus the page marked allocated.
;
; Parameters:
;		none
; Returns:
;		a0 = address of page (zero if no page available)
;		cr0.eq set if no page found, zero otherwise
; ------------------------------------------------------------------------------

_FindFreePage:
	movem.l a1-a4,-(sp)
	move.l _lastSearchedPAMWord,a0
	move.l a0,a1
	; search the PAM 32-bits at a time for a free page
.0002:
	cmpi.l #$FFFFFFFF,(a0)	; find a set of bits with an unallocated page
	bne.s .0004
	lea 4(a0),a0						; move to next set of bits
	cmp.l a1,a0							; did we loop all the way around to the start?
	beq.s .0006							; if yes, no memory available
	cmp.l #_PAMEnd,a0				; hit end of PAM?
	blo.s .0002							; nope, continue search
	move.l #_PAM,a0					; load with start of PAM
	bra.s .0002							; continue search
.0006
	movem.l (sp)+,a0				; reached end of PAM with no pages available
	moveq #E_NoMem,d0				; return no-memory left error
	rts
	; Here there was a free page indicated
.0004
	clr.l d0
.0005
	bset d0,(a0)						; set bit
	beq.s .0003							; was it set already?
	addq #1,d0							; check next page
	cmpi.b #32,d0						; all bits tested?
	blo.s .0005
	bra.s .0002							; if all bits tested set, app must have set the bit
	; Here there was a page available
.0003:
	move.l a0,_lastSearchedPAMWord
	sub.l #_PAM,a0					; a0 = tetra index into PAM
	move.l a0,d1
	lsl.l #5,d1							; 32 bits per entry
	add.l d1,d0							;	add in bit number, d0 = page number
	move.l d0,d1						; d1 = page number
	mulu #PMTESIZE,d0				; page number times size of PMT entry
	add.l #_PMT,d0					; add in PMT base address
	move.l d0,a0
	move.w #1,4(a0)					; set share count to 1
	move.w #7,(a0)					; set acr = user, rwx
	sub.l #_PMT,d0
	move.l d1,d0						; d0 = page number
	moveq #LOG_PGSZ,d1
	lsl.l d1,d0							; convert page number to address
	rts


; ------------------------------------------------------------------------------
; Gets the physical address for given the virtual address.
;
; Parameters:
;		a0 = virtual address to translate
; Returns:
;		a0 = physical address (-1 if timeout)
; ------------------------------------------------------------------------------

_GetPageTableEntryAddress:
	movem.l d1,-(sp)
	move.l #-1,d1
	bsr _LockMMUSemaphore
	tst.l d1
	bne .0001
.0003:
	movem.l (sp)+,d1
	move.l #-1,d0
	rts
.0001:
	bsr _GetRunningACBPtr
;	move.l
;.0002:
;	addi %a0,%a0,-1
;	beq %cr0,.0004
;	load. %a1,MMU_PADRV
;	beq %cr0,.0002
;	load. %a0,MMU_PADR
;	macUnlockMMUSemaphore
;	pop %a1
;	pop %br1
;	blr
;.0004:
;	macUnlockMMUSemaphore
;	b .0003
;
;.if 0
;; Walks the page table. Currently assumes a two-level page table.
;; Incomplete - needs to include the base/bound registers.
;_GetPageTableEntryAddress:
;	enter 7,0
;.0001:
;	bl GetRunningACBPointer							# a0 = pointer to ACB
;	load %a0,ACBPageTableAddress[%a0]		# a0 = pointer to page table
;	srli %s2,%a0,25											# a2 = index into root page table
;	andi %s2,%s2,11'h7ff								# '
;	loada %s6,[%a0+%s2*4]								# a6 = PTE address
;	load. %s3,[%s6]											# Get the PTP
;	bgt %cr0,.0002											# check if valid bit set (bit 31)
;.0003:
;	extz %s4,%s3,61,63									# Extract PTP/PTE type bits
;	cmpi %cr0,%s4,2											# Is it a PTP?
;	bne %cr0,.0006											# If not, error
;	# Type 2 PTE = PTP
;	extz %s4,%s3,0,43										# Extract PPN
;	slli %s4,%s4,LOG_PGSZ								# Turn into an address
;	extz %s2,%a0,14,24									# extract vadr bits 14 to 24
;	slli %s2,%s2,3											# convert index to page offset
;	or %s2,%s2,%s4											# a2 = pointer to entry now
;	load %s3,[%s2]											# Load the PTE
; 	move %s6,%s2												# a6 = PTE address
;	extz %s4,%s3,61,63									# Extract PTP/PTE type bits
;	cmpi %cr0,%s4,2											# Is it a PTE?
;	bge %cr0,.0006											# If not then error
;	# Type 0 or 1 PTE
;	move %a0,%a6
;	exit 7,0
;	# invalid PTE? Assign a page.
;.0002:
;	bl _FindFreePage									# allocate a page of memory
;	cmpi %cr0,%a0,0				# if page could not be allocated, return NULL pointer
;	peq %cr0,.0005
;	bl _ClearPage
;	# set the PTP to point to the page
;	srli %a0,%a0,LOG_PGSZ
;	ori %a3,%a0,0xC0000000	# set valid bit, and type 2 page
;	store %a3,[%a6]				# update the page table
;	b .0001
;.0005:
;	loadi %a0,0
;	pop %a1-%a6
;	blr
;.endif
;
;# ------------------------------------------------------------------------------
;# Page fault handler. Triggered when there is no translation for a virtual
;# address. Allocates a page of memory an puts an entry in the page table for it.
;# If the PTP was invalid, then a page is allocated for the page table it points
;# to and the PTP entry updated in the page table.
;#
;# Side Effects:
;#		Page table is updated.
;# Modifies:
;#		none
;# Parameters:
; #		none - it is an ISR
;# Returns:
;#		none - it is an ISR
;# ------------------------------------------------------------------------------
;
;_PageFaultHandlerISR:	
;	push %br1
;	push %a0-%t0				# push %a0 to a7, t0
;	# search the PMT for a free page
;	loadi %a0,-1
;	bl LockPMTSemaphore
;	bl _FindFreePage
;	pne %cr0,.0001
;	# Here there are no more free pages
;	macUnlockPMTSemaphore
;	# Here a free page was found
;.0001:
;	macUnlockPMTSemaphore
;	bl _ClearPage
;	# Should add the base address of the memory from the region table
;	loadi %a5,8					# maximum numober of levels of page tables (limits looping)
;	load %a1,MMU_PTBR		# a1 = address of page table
;	load %t0,MMU_PFA			# t0 = fault address (virtual address), clear page fault
;	srli %a2,%t0,26				# a2 = index into root page table
;	loada %a6,[%a1+%a2*4]	# a6 = PTE address
;	load. %a3,[%a6]				# Get the PTE
;	bgt %cr0,.0002				# check valid bit (bit 31)
;.0003:
;	srli %a4,%a3,29				# Extra PTE type bits
;	andi %a4,%a4,3
;	cmpi %cr0,%a4,2
;	bne %cr0,.0002
;.0004:
;	andi %a4,%a3,0x1FFFFFFF	# Extract PPN
;	slli %a4,%a4,LOG_PGSZ		# Turn into an address
; 	srli %a2,%t0,14					# extract vadr bits 14 to 25
;	andi %a2,%a2,0xFFF				# convert to index into page
;	slli %a2,%a2,2						# convert index to page offset
;	or %a6,%a2,%a4						# %a6 = pointer to entry now
;	loadi %a0,-1
;	bl LockPMTSemaphore
;	load. %a3,[%a6]					# Get the PTE
;	blt %cr0,.0006					# Check PTE was invalid, if not something is wrong
;	# set the PTE to point to the page
;	srli %a0,%a0,LOG_PGSZ
;	andi %a0,%a0,0x1FFF		# Keep only low order bits of page number
;	ori %a0,%a0,0x8000E000	# set valid bit, and type 0 page, user, rwx=7
;	store %a0,[%a6]				# update the page table
;	macUnlockPMTSemaphore
;	pop %a0-%t0
;	pop %br1
;	rfi
;	# Here the PTP was invalid, so allocate a new page table and set PTP
;.0002:
;	loadi %a0,-1
;	bl LockPMTSemaphore
;	bl _FindFreePage
;	macUnlockPMTSemaphore
;	cmp %cr0,%a0,0
;	peq %cr0,.0005
;	bl _ClearPage
;	# set the PTP to point to the page
;	srl %a0,%a0,LOG_PGSZ
;	or %a3,%a0,0xC0000000	# set valid bit, and type 2 page
;	store %a3,[%a6]				# update the page table
;	b .0004
;.0006:
;	macUnlockPMTSemaphore
;	# Here there was no memory available
;.0005:
; 	pop %a0-%t0
;	pop %br1
;	rfi
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
;
; Parameters:
;		none
;	Returns:
;		d0 = ACB handle
;
_FindFreeACB:
	move.l d1,-(sp)
	clr.l d1
	move.l _ACBList,d0
.0002
	bset.l d1,d0
	beq.s .0001
	addq #1,d1
	cmpi.b #32,d1
	blo.s .0002
	move.l (sp)+,d1
	clr.l d0
	rts
.0001
	move.l d0,_ACBList
	move.l d1,d0
	addq.l #1,d0
	move.l (sp)+,d1
	rts

	global _FindFreePage
