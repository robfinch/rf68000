
MMU equ $FD070000
pTBL1	equ $3C000			; top 16kB of boot area
pDir	equ $3BF00			; next lowest 256 bytes

	data
_nPagesFree
	dc.l	0
_oMemMax
	dc.l	$3FFFFFFF
rgPAM
	fill.b	8192,0
sPAM
	dc.l	32
sPAMmax equ 8192
MemExch
	dc.l	0
pNextPT
	dc.l	0
	
MEMALIAS	equ	%00000000000000000000000000000010	; User writable
MEMUSERD	equ %00000000000000000000000000000010	; User writable data
MEMUSERC	equ %00000000000000000000000000000101	; User Readable or executable
MEMSYS		equ %00000000000000000000000000001110	; System read/write
ALIASBIT	equ %00000000000000000001000000000000	;
PRSNTBIT	equ %00000000000000000010000000000000	;

	code
	even
InitMemMgmt:
	move.l #0,_nPagesFree				; 0 MB free
	move.l #$40000000,a0				; start of DRAM area
	move.l #$6D72746C,d3
MemLoop
	clr.l (a0)									; clear memory lword
	move.l d3,(a0)							; move test string to memory
	move.l (a0),d2							; read it back
	cmp.l d2,d3									; compare
	bne.s MemLoopEnd						; did it set correctly?
	add.l #$000FFFFC,a0					; move to top LWORD of area
	move.l a0,_oMemMax					; there is at least this much memory
	add.l #4,a0									; check next mega-byte
	add.l 64,_nPagesFree				; 64 pages per mega-byte
	add.l sPAM,8								; 64 more bits in PAM
	cmp.l #$7FFFFFFC,a0					; hit end of possible DRAM?
	bhs.s MemLoopEnd						
	bra MemLoop
MemLoopEnd
	; Setup the OS page directory
	; The OS page directory is in dedicated SRAM, it does not need to be marked
	; in the PAM
	moveq #62,d2								; 64 entries in page directory
	move.l #pTbl1,d0						; first entry to point to page table
	move.l #pDir,a0
	move.l d0,(a0)
	and.l #$FFFFC000,(a0)				; keep upper 18 bits
	or.l #$200F,(a0)						; present, supervisor, read-write-execute
	; Setup dummy references for remainder of page directory
	move.l #$FFFFE00F,d0				; highest page, supervisor
.0003
	lea 4(a0),a0
	move.l d0,(a0)
	dbra d2,.0003

	; Set first page table
	; Setup PTEs for the system boot area (256kB)
	; The pages for the boot area are outside of DRAM, they do not need to be
	; marked used.
	move.l #pTbl1,a0
	moveq #0,d0
.0002
	move.l d0,(a0)
	and.l #$FFFFC000,(a0)				; keep only upper 18 address bits
	or.l #$200F,(a0)						; PTE = present, supervisor, read-write-execute
	move.l d0,d1
	lea 4(a0),a0								; point to next PTE
	add.l #16384,d0							; goto next memory page
	cmp.l #262144,d0						; 256 kB? (boot area size)
	blo .0002
	; Reserve remaining portion of 16MB area in page table for OS
	; Setup a dummy page - not marked as used because it does not exist
	; use the highest 16kB of the address space
	move.l #$FFFFE00F,d0				; PTE = present, supervisor, read-write-execute, highest address
.0006
	move.l d0,(a0)
	lea 4(a0),a0								; point to next PTE
	cmp.l #pTbl1+1024,a0				; 16 MB filled?
	blo .0006

	; Setup PTSs to access I/O area
	move.l #$FD000000,d0				; I/O is in $FD block
.0007
	move.l d0,(a0)
	and.l #$FFFFC000,(a0)				; keep only upper 18 bits
	or.l #$200E,(a0)						; PTE = present, supervisor page, read-write
	move.l d0,d1								; mark page in use
	lea 4(a0),a0								; goto next PTE
	add.l #16384,d0							; goto next page of I/O
	cmp.l #pTbl1+2048,a0				; 16 MB reserved for I/O
	blo .0007

	; Setup PTEs for the video RAM
	; 16 MB reserved
	; These pages need to be marked
	move.l #$40000000,d0				; start of DRAM
.0001
	move.l d0,(a0)
	and.l #$FFFFC000,(a0)				; keep only upper 18 bits
	or.l #$200E,(a0)						; PTE = present, supervisor page, read-write
	move.l d0,d1								; mark page in use
	bsr MarkPage
	lea 4(a0),a0								; goto next PTE
	add.l #16384,d0							; goto next memory page
	cmp.l #pTbl1+3072,a0				; 16 MB reserved for video
	blo .0001

	; Fill remainder of page table with dummy references
	move.l #$FFFFE00F,d0				; PTE = present, supervisor, read-write-execute, highest address
.0008
	move.l d0,(a0)
	lea 4(a0),a0								; point to next PTE
	cmp.l #pTbl1+4096,a0				; 16 MB filled?
	blo .0008

	; Set the root pointer for the OS pid in the MMU to pDir
.0004
	clr.l MMU+$2100			; set active pid in MMU
	move.l #PDir1,d0
	move.l d0,MMU				; page directory PID 0000
	move.l #1,MMU+$2000	; enable MMU for PID 0000

	; At this point the MMU should be active
	bra .0005

.0005
	lea MemExch,a0
	move.l a0,-(sp)
	bsr _AllocExch
	move.l MemExch,-(sp)
	move.l #$FFFFFFF1,-(sp)
	move.l #$FFFFFFF1,-(sp)
	bsr _SendMsg
	move.l #1,-(sp)			; 1 page for next page table
	move.l pNextPT,d0
	move.l d0,-(sp)
	bsr _AllocOSPage	
	lea 24(sp),sp				; pop args
	rts

; Returns
;		d1.l = physical address of page, 0 if error

FindHighPage:
	movem.l d0/d4/a0,-(sp)
	move.l #rgPAM,a0
	move.l sPAM,d0
	subq.l #4,d0
	; look for a lword without a page marked allocated (has a zero bit in it)
FHP1
	cmp.l #$FFFFFFFF,(a0,d0.l)
	bne.s FHP2
	tst.l d0
	ble FHPn										; finshed search with no available pages?
	subq.l #4,d0								; look at next lowest set of pages
	bra FHP1
FHP2
	moveq #31,d1								; scan from bit 31 to 0 (highest to lowest)
	move.l (a0,d0.l),d4					; get the lword
FHP3
	btst d1,d4									; check for a zero bit (unallocated page)
	beq.s FHPf									; unallocated page found?
	tst.l d1										; last bit checked?
	beq FHPn										; there should have been a zero bit, otherwise error
	subq.l #1,d1								; check next bit
	bra FHP3
FHPf
	bset d1,d4									; mark page allocated
	move.l d4,(a0,d0.l)					; and update PAM
	lsl.l #5,d0									; *32 bits per lword
	add.l d0,d1									; add allocated page bit number
	lsl.l #8,d1									; multiply page number by 16kB for address
	lsl.l #6,d1
	add.l #$40000000						; add in DRAM base, available memory start here
	sub.l #1,_nPagesFree
	movem.l (sp)+,d0/d4/a0
	rts
FHPn													; no page was available, return NULL
	clr.l d1
	movem.l (sp)+,d0/d4/a0
	rts

FindLowPage:
	movem.l d0/d4/a0,-(sp)
	move.l #rgPAM,a0
	clr.l d0
.0001
	cmp.l #$FFFFFFFF,(a0,d0.l)	; any pages free?
	bne.s .0002
	cmp.l sPAM,d0								; reached end of PAM?
	bhs FHPn
	addq.l #4,d0								; check next set of bits
	bra .0001
.0002
	moveq #0,d1
	move.l (a0,d0.l),d4					; get bits
.0003
	btst d1,d4
	beq.s .found
	cmp.l #31,d1								; last bit checked?
	beq FHPn
	addq.l #1,d1
	bra .0003
.found
	bset d1,d4									; mark page allocated
	move.l d4,(a0,d0.l)					; save in PAM
	lsl.l #5,d0									; * 32 bits per lword
	add.l d0,d1									; plus bit number
	lsl.l #8,d1									; * 16384B page size
	lsl.l #6,d1
	add.l #$40000000,d1					; add in memory base address
	sub.l #1,_nPagesFree				; one less pages free
	movem.l (sp)+,d0/d4/a0
	rts
FHPn
	clr.l d1										; return NULL if no pages available or error
	movem.l (sp)+,d0/d4/a0
	rts

; Mark a page as allocated
		
MarkPage:
	movem.l d1/d2/a0,-(sp)
	move.l #rgPAM,a0
	sub.l #$40000000,d1					; subract off memory base
	and.l #$FFFFC000,d1					; round address down to page size
	moveq #14,d2
	lsr.l d2,d1									; d1 = page number
	move.l d1,d2								; d2 = page number
	and.l #31,d2								; d2 = bit number in lword
	lsr.l #5,d1									; d1 = lword number
	bset d2,(a0,d1.l)						; set the bit in the PAM
	bne.s .0001									; was the page already marked allocated?
	sub.l #1,_nPagesFree				; one less page available
.0001
	movem.l (sp)+,d1/d2/a0
	rts
	
; Mark a page as allocated
		
UnMarkPage:
	movem.l d1/d2/a0,-(sp)
	move.l #rgPAM,a0
	sub.l #$40000000,d1					; subract off memory base
	and.l #$FFFFC000,d1					; round address down to page size
	moveq #14,d2
	lsr.l d2,d1									; d1 = page number
	move.l d1,d2								; d2 = page number
	and.l #31,d2								; d2 = bit number in lword
	lsr.l #5,d1									; d1 = lword number
	bclr d2,(a0,d1.l)						; set the bit in the PAM
	beq.s .0001									; was the page already marked free?
	add.l #1,_nPagesFree				; one more page available
.0001
	movem.l (sp)+,d1/d2/a0
	rts

; Parameters:
;		d1 = job numnber
;		d2 = linear address
;
; Returns:
;		d1 = physical address
;		a1 = linear address of PTE for this linear address
;
LinToPhy:
	movem.l d2/a0,-(sp)
	move.l d1,-(sp)
	bsr GetpJCB									; get JCB pointer (in d1)
	move.l d1,a0								; a0 = JCB pointer
	move.l JcbPD(a0),a1					; put page directory into a1
	lea 128(a1),a1							; move to shadow addresses
	move.l (sp),d1							; get back linear address
	moveq #26,d2								; shift linear address right by 26 bits
	lsr.l d2,d1
	lsl.l #2,d1									; make lword index into PD
	move.l (a1,d1.l),d1					; d1 = PDE
	and.l #$FFFFC000,d1					; d1 = address of page table
	move.l d1,a1								; a1 = address of page table
	move.l (sp),d1							; d1 = original linear address
	moveq #14,d2
	lsr.l d2,d1
	and.l #$0FFF,d1							; get rid of six upper bits
	lsl.l #2,d1									; d1 = lword index into page table
	move.l (a1,d1.l),d1					; d1 = PTE
	lea (a1,d1.l),a1						; a1 = address of PTE
	and.l #$FFFFC000,d1					; d1 = address bits
	move.l (sp)+,d2							; d2 = original linear
	and.l #$3fff,d2							; d2 = physical offset
	or.l d2,d1									; d1 = real physical address
	move.l (sp)+,d2/a0
	rts
	
FindRun:
	movem.l d2/d3/d4/d6/a0/a1/a2,-(sp)
	move.l d1,d4								; d4 = search area 0=supervisor, 4+ = user
	move.l d2,d6								; d6 = number of pages needed
	move.l d2,d3								; d3 = original count of pages needed
	bsr GetpCrntJCB
	move.l d1,a0
	move.l JcbPD(a0),a1
	lea 128(a1),a1							; move to shadow address range
.0000
	move.l (a1,d4.l),d2					; d2 = PTE
	and.l #$FFFFC000,d2					; d2 = page table address
	bne.s .0001
	clr.l d1
	bra FRExit
.0001
	clr.l d1										; start at first PTE
.0002
	cmp.l #4096,d1							; past last PTE?
	blo .0003
	addq #4,d4									; next PDE
	bra.s .0000
.0003
	move.l d2,a2
	cmp.l #$FFFFE00F,(a2,d1.l)	; special constant indicating empty PTE
	bne.s .0004
	subq #1,d6
	beq.s .frok
	addq.l #4,d1
	bra .0002
.0004
	addq #4,d1									; advance to next PTE
	move.l d3,d6
	bra .0002
.frok
	moveq #24,d6								; the six MSBs of address were in d4 (d4 already shifted left two bits)
	lsl.l d6,d4									; as it was an index to the PDE
	moveq #12,d6
	lsl.l d6,d1									; d1 was the PTE index (already shifted two bits left)
	or.l d4,d1									; d1 = upper 18 bits of address
	subq #1,d3									; d3 = one less page
	moveq #14,d6
	lsl.l d6,d3									; pages * size of page
	sub.l d3,d1									; d1 = first linear address of run
	movem.l (sp)+,d2/d3/d4/d6/a0/a1/a2
	rts

	; $40000000 to $5FFFFFFC reserved for system (512 MB)
	;	$60000000 to $7FFFFFFC reserved for user
	
AddRun:
	movem.l d1/d2/d3/d4/d5/d6/a1/a2,-(sp)
	move.l d2,d3								; d3 = number of pages
	move.l d1,d4								; d4 = linear address
	moveq #26,d5
	lsr.l d5,d4									; d4 = index into PD
	lsl.l #2,d4									; d4 = lword index
	move.l d1,-(sp)
	bsr GetpCrntJCB
	move.l d1,a1
	move.l JcbPD(a1),a1					; a1 = pointer to PD
	move.l (sp)+,d1
	add.l #128,a1								; a1 = shadow address of PD
	add.l d4,a1									; a1 points to initial PT
	move.l d1,d4								; d4 = linear address
	and.l #$03FFC000,d4					; get rid of upper six and lower 14
	moveq #12,d5
	lsr.l d5,d4									; shift right by 12 to make PT index
.0000
	move.l (a1),a2							; a2 = address of next page table
	
	; At this point a2 points to the next PT
	; a2+d4 will point to the next PTE
	; Call FindPage to get a physical address in d1
	; then check the original linear address to see if system or user
	; and OR in the appropriate control bits, then store in PT
.0001
	move.l d1,-(sp)
	bsr FindHighPage
	move.l d1,d2
	move.l (sp)+,d1
	move.l #MEMSYS,d6					; assume a system page
	cmp.l #$60000000,d1
	blo.s .0002
	move.l #MEMUSERD,d6				; switch to user data page
.0002
	or.l d6,d2
	move.l d2,(a2,d4.l)				; d4 is index to entry
	subq.l #1,d3
	beq.s .done
	addq.l #4,d4
	cmp.l #16384,d4						; past last PTE of this PT?
	blo.s .0001
	add.l #4,a1
	clr.l d4
	bra.s .0000
.done
	movem.l (sp)+,d1/d2/d3/d4/d5/d6/a1/a2
	rts

; Parameters:
;		d1 = linear address of first page of new alias entries (from FindRun)
;		d2 = number of pages to alias
;		a1 = linear address of pages to alias (from other job)
;		d4 = Job number of job we are aliasing
;
; Uses
;		a4 = AliasLin
;		a5 = AliasJob
;
; Returns:
;		nothing

AddAliasRun:
	movem.l d1/d2/d3/d4/d5/d6/a1/a2/a3/a4/a5,-(sp)
	move.l a1,a4
	move.l d4,a5
	
	move.l d2,d3
	move.l d1,d4
	moveq #26,d5
	lsr.l d5,d4
	lsl.l #2,d4
	move.l d1,-(sp)
	bsr GetpCrntJCB
	move.l d1,a2
	move.l (sp)+,d1
	move.l JcbPD(a2),a1
	add.l #128,a1
	add.l d4,a1
	move.l d1,d4
	and.l #$03FFC000,d4
	moveq #12,d5
	lsr.l d5,d4
.0000
	move.l (a1),a3
.0001
	move.l a1,-(sp)
	move.l a5,d1
	move.l a4,d2
	add.l #16384,a4
	bsr LinToPhys
	; d1 now has physical address of page
	
	and.l #$FFFFC000,d1
	or.l #MEMALIAS,d1
	move.l (sp)+,a1
	move.l d1,(a3,d4.l)
	subq.l #1,d3
	beq.s .done
	addq.l #4,d4
	cmp.l #16384,d4
	blo.s .0001
	lea 4(a1),a1
	clr.l d4
	bra.s .0000
.done
	movem.l (sp)+,d1/d2/d3/d4/d5/d6/a1/a2/a3/a4/a5
	rts

; Parameters:
;		none
;
; Returns
;		d1 = 0 if okay, or E_NoMem if no free pages
;
AddUserPT:
	movem.l d2/d3/a1/a2,-(sp)
	move.l _nPagesFree,d1
	tst.l d1
	bne.s .0001
	move.l #E_NoMem,d1
	bra .done
.0001
	bsr GetCrntJobNum		; leaves job number in d1
	move.l pNextPT,d2
	bsr LinToPhys
	
	bsr GetpCrntJCB
	move.l #JcbPD,a2
	add.l d1,a2
	move.l (a2),a1
	add.l #128,a1
	move.l #127,d3
.0002
	lea 4(a1),a1
	move.l (a1),d2
	cmp.l #$FFFFE00F,d2
	dbeq d3,.0002
	; a1 now points to empty slot
	or.l #MEMUSERD,d1
	move.l d1,(a1)
	add.l #128,a1				; move to shadow
	move.l pNextPT,d2
	move.l d2,(a1)			; put in linear address of PT (upper half)
	
	;
	
	moveq #1,d2
	clr.l d1
	bsr FindRun
	tst.l d1
	bne.s .0005
	move.l #E_NoMem,d1
	bra .done
.0005
	move.l d1,pNextPT
	bsr AddRun
.done
	movem.l (sp)+,d2/d3/a1/a2
	rts

AddOSPT:
	movem.l d2/d3/d4/a1,-(sp)
	move.l _nPagesFree,d1
	tst.l d1
	bne.s .0001
	move.l #E_NoMem,d1
	bra .done
.0001
	moveq #1,d1					; OS job number
	move.l pNextPT,d2
	bsr LinToPhys
	
	lea.l PDir1,a1			; a1 points to OS PD
	move.l #127,d3			; count of PDEs to check
.0002
	lea 4(a1),a1
	move.l (a1),d2
	cmp.l #$FFFFE00F,d2	; special "empty" constant
	dbeq d3,.0002
	; a1 now points to empty slot
	or.l #PRSNTBIT,d1
	move.l d1,(a1)
	lea 128(a1),a1			; move to shadow
	move.l pNextPT,d2
	move.l d2,(a1)			; put in linear address of PT (upper half)
	
	;

	; Update ALL PDs from PDir1 !!
	;
	move.l nJCBs,d4
.0003
	move.l d4,d1
	bsr GetpJCB
	move.l d1,a0
	move.l JcbPD(a0),d3
	tst.l d3
	beq.s .0004
	add.l JcbPD,d1
	move.l #PDir1,d2
	move.l d4,-(sp)
	move.l d1,-(sp)
	move.l d2,-(sp)
	move.l d2,-(sp)			; source
	move.l d1,-(sp)			; destination
	move.l #128,-(sp)
	bsr _CopyData
	add.l #12,sp				; get rid of args
	move.l (sp)+,d2			; get back values
	move.l (sp)+,d1
	add.l #8192,d2			; move to shadow area
	move.l d2,-(sp)
	add.l #8192,d1
	move.l d1,-(sp)
	move.l #128,-(sp)
	bsr _CopyData
	add.l #12,sp
	move.l (sp)+,d4
.0004
	subq #1,d4
	cmp.l #2,d4
	bhi .0003

	moveq #1,d2					; size of request
	clr.l d1						; PD shadow offset
	bsr FindRun
	tst.l d1						; was there an error?
	bne .0005
	move.l #E_NoMem,d1
	bra.s .done
.0005
	move.l d1,pNextPT
	bsr AddRun
	clr.l d1
.done
	movem.l (sp)+,d2/d3/d4/a1
	rts
		
	
	global _nPagesFree
	global _oMemMax
	global rgPAM
	global sPAM
	global MarkPage
	global UnMarkPage
	global LinToPhy

		
