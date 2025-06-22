
OSWaitMsg	equ
OSSendMsg equ
OSAllocOSPage equ
OSAllocPage equ

MMU equ $FD070000
pTBL1	equ $00118000		; second from top 16kB of boot area
pDir	equ $0011FD00		;	256 byte area
DRAMBASE	equ $40000000
DRAMLIMIT	equ	$7FFFFFFF
TSTCONST	equ $466D746B	; 'FMTK'
sPAMmax equ 8192			; maximum size of PAM
; These vars must be in shared OS memory
sPAM	equ	$00100154		; stores measured size of PAM
rgPAM equ $0011FE00		; top of shared SRAM (must be initialized with zero)
_nPagesFree equ $00100158	; number of pages free
; A special constant indicating an empty PTE, references the highest page of
; the address space, and is marked present as a supervisor page.
EMPTYPTE equ $FFFFFFFF	

	data
_oMemMax
	dc.l	$3FFFFFFF
	fill.b	8192,0
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
; Clear PAM memory (marks all pages free)
	clr.l sPAM
	move.l #sPAMMax-1,d3
	lea rgPAM,a0
.0001
	clr.l (a0)+
	dbra d3,.0001
; Find out how many pages of memory there are. Write the first word of a page
; with a special constant, then read it back to see if the write was successful.
; This requires the hardware not to hang when an invalid address is tested.
	move.l #DRAMBASE,a0					; start of DRAM area
	move.l #TSTCONST,d3					; Test constant 'FMTK'
	clr.l	d5										; storage for _nPagesFree
	clr.l d4										; storage for sPAM
	clr.l a1										; storage for _oMemMax
MemLoop
	clr.l (a0)									; clear memory lword
	move.l d3,(a0)							; move test string to memory
	move.l (a0),d2							; read it back
	cmp.l d2,d3									; compare
	bne.s MemLoopEnd						; did it set correctly?
	add.l #$0003FFFC,a0					; move to top LWORD of area
	move.l a0,a1								; there is at least this much memory
	lea 4(a0),a0								; check next page
	addq.l #1,d5								; increment number of pages available
	addq.l #1,d4								; 1 more bit in PAM
	cmp.l #DRAMLIMIT,a0					; hit end of possible DRAM?
	blo.s MemLoop
MemLoopEnd
	move.l d5,_nPagesFree				; update number of free pages
	move.l a1,_oMemMax					; set max limit of memory
	addq.l #7,d4								; round for number of bytes
	lsr.l #3,d4									; eight bits per byte
	move.l d4,sPAM							; update size of PAM

	; Setup the OS page directory
	; The OS page directory is in dedicated SRAM, it does not need to be marked
	; in the PAM
	moveq #62,d2								; 64 entries in page directory, one will be used
	lea pTbl1,a1								; first entry to point to page table
	lea pDir,a0									; a0 points to page directory
	move.l a1,(a0)							; lower 14 bits already zero
	or.l #$200F,(a0)						; present, supervisor, read-write-execute
	; Setup dummy references for remainder of page directory
	move.l #EMPTYPTE,d0					; highest page, supervisor
.0003
	lea 4(a0),a0
	move.l d0,(a0)
	dbra d2,.0003

	; Set first page table
	; Setup PTEs for the system boot area (256kB)
	; The pages for the boot area are outside of DRAM, they do not need to be
	; marked used.
	lea pTbl1,a0
	moveq #0,d0
.0002
	move.l d0,(a0)							; lower 14 bits already zero
	or.l #$200F,(a0)						; PTE = present, supervisor, read-write-execute
	lea 4(a0),a0								; point to next PTE
	add.l #16384,d0							; goto next memory page
	cmp.l #262144,d0						; 256 kB? (boot area size)
	blo .0002
	; Reserve remaining portion of 16MB area in page table for OS
	; Setup a dummy page - not marked as used because it does not exist
	; use the highest 16kB of the address space
	move.l #EMPTYPTE,d0					; PTE = present, supervisor, read-write-execute, highest address
.0006
	move.l d0,(a0)
	lea 4(a0),a0								; point to next PTE
	cmp.l #pTbl1+4096,a0				; 16 MB filled?
	blo .0006


	; Setup PTEs for the video RAM
	; 16 MB reserved
	; These pages need to be marked
	move.l #DRAMBASE,d0					; start of DRAM (must be page aligned)
.0001
	move.l d0,(a0)
	or.l #$200E,(a0)						; PTE = present, supervisor page, read-write
	move.l d0,d1								; mark page in use
	bsr MarkPage
	lea 4(a0),a0								; goto next PTE
	add.l #16384,d0							; goto next memory page
	cmp.l #pTbl1+8192,a0				; 16 MB reserved for video
	blo .0001

	; Fill remainder of page table with dummy references
	move.l #EMPTYPTE,d0					; PTE = present, supervisor, read-write-execute, highest address
.0008
	move.l d0,(a0)
	lea 4(a0),a0								; point to next PTE
	cmp.l #pTbl1+16384,a0				; page table filled?
	blo .0008

	; Set the root pointer for the OS pid in the MMU to pDir
.0004
	move.l #1,MMU+$2100					; set active pid in MMU
	move.l #pDir,d0							; page directory
	move.l d0,MMU								; page directory PID 0000
	move.l d0,MMU+4							; page directory PID 0001
	move.l #2,MMU+$2000					; enable MMU for PID 0001

	; At this point the MMU should be active
	; Flush processor nano-cache and pipeline
	rept 16
	nop
	endr
	bra .0005

.0005
	lea MemExch,a0
	move.l a0,-(sp)
	bsr _AllocExch
	move.l MemExch,d1
	move.l #$FFFFFFF1,d2
	move.l d2,d3
	move.l d2,d4
	move.l #OSSendMsg,d7
	trap #1
	move.l #1,d1				; 1 page for next page table
	move.l pNextPT,d2
	move.l #OSAllocOSPage,d7
	trap #1
	rts

; Returns
;		d1.l = physical address of page, 0 if error

FindHighPage:
	movem.l d0/d4/a0,-(sp)
	lea rgPAM,a0
	move.l sPAM,d0
	subq.l #1,d0
	; look for a lword without a page marked allocated (has a zero bit in it)
FHP1
	cmp.b #$FF,(a0,d0.l)
	bne.s FHP2
	tst.l d0
	ble FHPn										; finshed search with no available pages?
	subq.l #1,d0								; look at next lowest set of pages
	bra FHP1
FHP2
	moveq #7,d1									; scan from bit 7 to 0 (highest to lowest)
	move.b (a0,d0.l),d4					; get the byte
FHP3
	btst d1,d4									; check for a zero bit (unallocated page)
	beq.s FHPf									; unallocated page found?
	tst.l d1										; last bit checked?
	beq FHPn										; there should have been a zero bit, otherwise error
	subq.l #1,d1								; check next bit
	bra FHP3
FHPf
	bset d1,d4									; mark page allocated
	move.b d4,(a0,d0.l)					; and update PAM
	lsl.l #3,d0									; *8 bits per byte
	add.l d0,d1									; add allocated page bit number
	moveq #14,d0
	lsl.l d0,d1									; multiply page number by 16kB for address
	add.l #DRAMBASE							; add in DRAM base, available memory start here
	sub.l #1,_nPagesFree
	movem.l (sp)+,d0/d4/a0
	rts
FHPn													; no page was available, return NULL
	clr.l d1
	movem.l (sp)+,d0/d4/a0
	rts

FindLowPage:
	movem.l d0/d4/a0,-(sp)
	lea rgPAM,a0
	clr.l d0
.0001
	cmp.b #$FF,(a0,d0.l)				; any pages free?
	bne.s .0002
	cmp.l sPAM,d0								; reached end of PAM?
	bhs FHPn
	addq.l #1,d0								; check next set of bits
	bra .0001
.0002
	moveq #0,d1
	move.b (a0,d0.l),d4					; get bits
.0003
	btst d1,d4
	beq.s .found
	cmp.l #7,d1									; last bit checked?
	beq FHPn
	addq.l #1,d1
	bra .0003
.found
	bset d1,d4									; mark page allocated
	move.b d4,(a0,d0.l)					; save in PAM
	lsl.l #3,d0									; * 8 bits per lword
	add.l d0,d1									; plus bit number
	moveq #14,d0
	lsl.l d0,d1									; * 16384B page size
	add.l #DRAMBASE,d1					; add in memory base address
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
	lea rgPAM,a0
	sub.l #DRAMBASE,d1					; subract off memory base
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
	
; Mark a page as un-allocated
		
UnMarkPage:
	movem.l d1/d2/a0,-(sp)
	lea rgPAM,a0
	sub.l #DRAMBASE,d1					; subract off memory base
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

; Translate a linear address to a physical one.
;
; Parameters:
;		d1 = job numnber
;		d2 = linear address
;
; Returns:
;		d1 = physical address
;		a1 = linear address of PTE for this linear address
;
LinToPhy:
	movem.l d2/d3/d5/a0,-(sp)
	move.l d2,d3								; save linear address
	bsr GetpPCB									; get PCB pointer (in d1)
	move.l d1,a0								; a0 = PCB pointer
	move.l PcbPD(a0),a1					; put page directory into a1
	lea 128(a1),a1							; move to shadow addresses
	move.l d3,d2								; get back linear address
	moveq #26,d5								; shift linear address right by 26 bits
	lsr.l d5,d2
	lsl.l #2,d2									; make lword index into PD
	move.l (a1,d2.l),d1					; d1 = PDE
	and.l #$FFFFC000,d1					; d1 = address of page table
	move.l d1,a1								; a1 = address of page table
	move.l d3,d1								; d1 = original linear address
	moveq #14,d5
	lsr.l d5,d1
	and.l #$0FFF,d1							; get rid of six upper bits
	lsl.l #2,d1									; d1 = lword index into page table
	move.l (a1,d1.l),d1					; d1 = PTE
	lea (a1,d1.l),a1						; a1 = address of PTE
	and.l #$FFFFC000,d1					; d1 = address bits only
	and.l #$3fff,d3							; d3 = physical offset
	or.l d3,d1									; d1 = real physical address
	move.l (sp)+,d2/d3/d5/a0
	rts

; =============================================================================
; FindRun
;
; This finds a linear run of free linear memory in one of the user or OS PTs.
; This is either at address base (for OS) or base address plus 128 MB (for user).
; d1 = 0 if we are looking for OS memory, else
; d1 = 16 if we are looking for USER memory.
; The linear address of the run is returned in d1 unless no run that large
; exists, in which case 0 is returned.
; The linear run may span page tables (if they already exist).
;
; Parameters:
;		d1.l = search area, 0 = supervisor, 16+ = user
; 	d2.l = number of pages needed
;	Returns:
;		d1.l = first linear address of run, 0 if none available
;		d2.l = number of pages needed (preserved)

FindRun:
	movem.l d2/d3/d4/d6/a0/a1/a2,-(sp)
	move.l d1,d4								; d4 = search area 0=supervisor, 16+ = user
	move.l #144,d5							; d5 = last PDE for system area
	tst.l d1
	beq.s .0005
	move.l #256,d5							; d5 = last PDE for user area
.0005
	move.l d2,d6								; d6 = number of pages needed
	move.l d2,d3								; d3 = original count of pages needed
	bsr GetpCrntPCB
	move.l d1,a0
	move.l PcbPD(a0),a1					; a1 points to page directory
	lea 128(a1),a1							; move to shadow address range
	add.l d4,a1									; add in start position
.0000
	move.l (a1,d4.l),d2					; d2 = PTE
	cmp.l #$FFFFFFFF,d2					; empty PDE?
	bne.s .0001
	clr.l d1
	bra .exit
.0001
	and.l #$FFFFC000,d2					; d2 = page table address
	clr.l d1										; start at first PTE
.0002
	cmp.l #4096,d1							; past last PTE?
	blo .0003
	addq #4,d4									; next PDE
	cmp.l d5,d4									; end of search area?
	blo.s .0000
	clr.l d1
	bra .exit
.0003
	move.l d2,a2								; a2 = page table address
	cmp.l #EMPTYPTE,(a2,d1.l)		; special constant indicating empty PTE
	bne.s .0004
	subq #1,d6									; decrement count of pages needed
	beq.s .frok									; any more pages needed? if not we're done
	addq.l #4,d1								; increment to next PTE
	bra .0002
.0004
	addq #4,d1									; advance to next PTE
	move.l d3,d6								; restore page count
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
.exit
	movem.l (sp)+,d2/d3/d4/d6/a0/a1/a2
	rts

	; $40000000 to $47FFFFFC reserved for system (128 MB)
	;	$48000000 to $7FFFFFFC reserved for user (896 MB)
	;
; Paramters:
;		d1.l = linear address
;		d2.l = number of pages
	
AddRun:
	movem.l d1/d2/d3/d4/d5/d6/a1/a2,-(sp)
	move.l d2,d3								; d3 = number of pages
	move.l d1,d4								; d4 = linear address
	moveq #26,d5
	lsr.l d5,d4									; d4 = index into PD
	lsl.l #2,d4									; d4 = lword index
	move.l d1,-(sp)
	bsr GetpCrntPCB
	move.l d1,a1								; a1 = pointer to PCB
	move.l PcbPD(a1),a1					; a1 = pointer to PD
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
	cmp.l #$48000000,d1
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
;		a1 = linear address of pages to alias (from other process)
;		d4 = Process number of process we are aliasing
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
	bsr GetpCrntPCB
	move.l d1,a2
	move.l (sp)+,d1
	move.l PcbPD(a2),a1
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

; d1 = n4kPages equ 16
; d2 = ppMemRet equ 20

AllocOSPage:
	tst.l d1
	beq.s .argerr
	cmp.l _nPagesFree,d1
	bhs.s .nomem_err
	movem.l d1/d2/d3/d4/d7/a1,-(sp)
	movem.l d1/d2,-(sp)
	move.l MemExch,d1
	move.l pRunTSS,d2
	add.l #TSS_Msg,d2
	moveq #OSWaitMsg,d7
	trap #1
	movem.l (sp)+,d1/d2
	tst.l d0
	bne.s .exit

move.l d2,d3							; d3 = ppMemRet
.0001
	move.l d1,d2							; d2 = n4kpages
	clr.l d1
	bsr FindRun
	tst.l d1
	bne.s .0002
	
	bsr AddOSPT
	tst.l d1
	beq.s .0001
	bra.s .exit
.0002
	bsr AddRun
	move.l d3,a1
	; Assume we in the OS process
	move.l d1,(a1)
	clr.l d0
.exit
	move.l d0,-(sp)
	move.l MemExch,d1
	move.l #$FFFFFFF1,d2
	move.l #$FFFFFFF1,d3
	move.l #$FFFFFFF1,d4
	moveq #OSSendMsg,d7
	trap #1
	move.l (sp)+,d0
	movem.l (sp)+,d1/d2/d3/d4/d7/a1
	rts
.argerr
	move.l #E_Arg,d0
	rts
.nomem_err
	move.l #E_NoMem,d0
	rts

AllocPage:
	movem.l d1/d2/d3/d4/d7/a1,-(sp)
	tst.l d1
	beq.s .argerr
	cmp.l _nPagesFree,d1
	bhs.s .nomem_err
	movem.l d1/d2/a1,-(sp)
	movem.l d1/d2,-(sp)
	move.l MemExch,d1
	move.l pRunTSS,d2
	add.l #TSS_Msg,d2
	move.l #OSWaitMsg,d7
	trap #1
	movem.l (sp)+,d1/d2
	tst.l d0
	bne.s .exit

.0000
	move.l d2,d3							; d3 = ppMemRet
.0001
	move.l d1,d2
	clr.l d1
	bsr FindRun
	tst.l d1
	bne.s .0002
	
	bsr AddUserPT
	tst.l d1
	beq.s .0001
	bra.s .exit
.0002
	bsr AddRun
	move.l ppMemRet(sp),a1
	move.l d1,(a1)
	clr.l d0
.exit
	move.l d0,-(sp)
	move.l MemExch,d1
	move.l #$FFFFFFF1,d2
	move.l #$FFFFFFF1,d3
	move.l #$FFFFFFF1,d4
	moveq #OSSendMsg,d7
	trap #1
	move.l (sp)+,d0
	movem.l (sp)+,d1/d2/d3/d4/d7/a1
	rts
.argerr
	move.l #E_Arg,d0
	rts
.nomem_err
	move.l #E_NoMem,d0
	rts

; Parameters:
; 	d1 = pMem equ 28
; 	d2 = dcbMem equ 32
; 	d3 = pProcessNum equ 36
; 	d4 = ppAliasRet equ 40 
; Usage
;		d0 = current process number
;		a1 = pMem

_AliasMem:
	movem.l d1/d2/d3/d5/d6/d7/a1/a2,-(sp)
	move.l d1,d0
	bsr GetCrntProcessNum
	exg d1,d0							; d0 = process number
	cmp.l d0,d3
	beq.s .done

.0000
	move.l d1,d5					; d5[EBX] = pMem
	and.l #$3FFF,d5				; mod 16384
	move.l d2,d6					; d6[EAX] = dcbMem
	add.l d5,d6						; d6 = add remainder of address
	moveq #14,d5					;
	lsr.l d5,d6						; d6 = pages - 1
	addq.l #1,d6					; d6 = pages needed
	move.l d6,d7					; d7 = pages needed

	;Now we find out whos memory we are in to make alias
	;d1 is 16 for user space, 0 for OS
	;d2 is number of pages for run

	move.l d1,a1					; a1 = pMem
	cmp.l #1,d0						; system process ?
	beq.s .0011
	move.l #16,d1					; No, user memory
	bra.s .0001
.0011
	clr.l d1
.0001
	move.l d7,d2					; d2 = number of pages needed
	bsr FindRun
	tst.l d1							; d1 = linear address of new alias entries
	bne. .0004
	
	cmp.l #1,d0						; system process?
	beq.s .0002
	bsr AddUserPT
	bra.s .0003
.0002
	bsr AddOSPT
.0003
	clr.l d1
	beq.s .0000
	bra.s .exit
.0004
; Parameters:
;		d1 = linear address of first page of new alias entries (from FindRun)
;		d2 = number of pages to alias
;		a1 = linear address of pages to alias (from other process)
;		d4 = Process number of process we are aliasing
	move.l d1,a2					; a2 = linear address of new alias entries
	exg d3,d4							; d3 = ppAliasRet, d4 = process number
	bsr AddAliasRun
	
	move.l a1,d1
	and.l #$3FFF,d1
	add.l d1,a2
	move.l d3,a1
	move.l a2,(a1)
.done
	clr.l d0
.exit
	movem.l (sp)+,d1/d2/d3/d5/a1/a2
	rts

;	pAliasMem is the address to DeAlias
;	dcbAliasBytes is the size of the original memory aliased
;
; Parameters:
;		d1 = AliasJobNum	EQU [EBP+12]
;		d2 = dcbAliasBytes	EQU [EBP+16]
;		d3 = pAliasMem 		EQU [EBP+20]
; Returns:
;		d0 = error code

_DeAliasMem:
	movem.l d4/d5/d6/d7/a1,-(sp)
	move.l d3,d5				; d5 = pMem
	and.l #$3FFF,d5			; d5 mod 16384
	move.l d2,d4				; d4 = dcbMem
	add.l d4,d5
	moveq #14,d0
	lsr.l d0,d4					; d4 = # pages - 1
	move.l d4,d6				; d6 = number of pages -1
	addq.l #1,d4				; d4 = # pages to dealias
	move.l d4,a2				; a2 = number of pages
	move.l d3,d7				; d7 = lineaar mem to dealias
.0001	
	movem.l d1/d2,-(sp)
	move.l d7,d2				; d5 = address of next page to deallocate
	bsr LinToPhy				; gets address of PTE in a1
	movem.l (sp)+,d1/d2

	; See if PTE is an alias, if so just ZERO PTE.
	; DO NOT deallocate the physical page

	move.l (a1),d5			; d5 = PTE
	btst #13,d5					; Is page present? (it should always be)
	bne.s .0002					; yes, it's page is present
	cmp.l d6,a2					;NO! (did we do any at all)
	bne.s .0011					;We did some.
	move.l #E_BadLinAddr,d0	; None at all!
	bra.s .exit
	
.0011
	move.l #E_BadAlias,d0	;We dealiased what we could,
	bra.s .exit						;but less than you asked for!

.0002
	btst #12,d5					;Is page an ALIAS?
	beq.s .0003					;NO - DO not zero it!

	;If we got here the page is presnt and IS an alias
	;so we zero out the page.

	move.l #EMPTYPTE,(a1)	; Mark PTE empty
.0003
	add.l #16384,d7			;Next linear page
	dbra d6,.0001
	moveq #E_Ok,d0
.exit:
	movem.l (sp)+,d4/d5/d6/d7/a1
	rts

;=============================================================================
; DeAllocPage --
;
; Procedureal Interface :
;
;		DeAllocPage(pOrigMem, n4KPages):ercType
;
;   pOrigMem is a POINTER which should be point to memory page(s) to be
;   deallocate.	 The lower 12 bits of the pointer is actually ignored
;   because we deallocate 4K pages.  This will free physical pages unless
;   the page is marked as an alias. It will always free linear memory
;   providing it is valid.  Even if you specify more pages than are valid
;   this will deallocate or dealias as much as it can before reaching
;   an invalid page.
;
;	n4KPages is the number of 4K pages to deallocate
;
; Paramters:
;		d1 = pOrigMem 	EQU [EBP+10h]
;		d2 = n4KPagesD	EQU [EBP+0Ch]
;

_DeAllocPage:
	movem.l d1/d2/d3/d4/d6/d7/a1,-(sp)
	movem.l d1/d2,-(sp)
	move.l MemExch,d1			;Wait at the MemExch for Msg
	move.l pRunTSS,d2			;Put Msg in callers TSS Message Area
	add.l TSS_Msg,d2
	moveq #OSWaitMsg,d7
	trap #1
	tst.l d0							;Error??
	bne.s .exit
	movem.l (sp)+,d6/d7		; d6=pOrigMem,d7 = n4KPagesD
	subq.l #1,d7					; one less for dbra
	move.l d7,d3
	and.l #$FFFFC000,d6		;Drop bits from address (MOD 16384)
.0001
	move.l d6,d2					; d2 = address of next page to deallocate
	bsr GetCrntProcessNum	; Leave process# in d1 for LinToPhy
	bsr LinToPhy

	;Now we have Physical Address in d1
	;and pointer to PTE in a1.
	;See if PTE is an alias, if so just ZERO PTE,
	;else deallocate physical page THEN zero PTE

	move.l (a1),d2				;Get PTE into d2
	btst #13,d2						;Is page present (valid)???
	bne.s .0002						;Yes, it's page is present
	cmp.l d3,d7						;NO! (did we do any at all)
	bne.s .0011						;We did some..
	move.l #E_BadLinAddr,d0	;None at all!
	bra.s .exit

.0011
	move.l #E_ShortMem		;We deallocated what we could,
	bra.s .exit						;but less than you asked for!

.0002
	btst #12,d2						;Is page an ALIAS?
	bne.s .0003						;Yes, it's an Alias

	;If we got here the page is presnt and NOT an alias
	;so we must unmark (release) the physical page.

	move.l d2,d1					; arg in d1
	bsr UnMarkPage

.0003
	move.l #EMPTYPTE,(a1)	;ZERO PTE entry
	add.l #16384,d6				;Next linear page
	dbra d3,.0001
	moveq #E_Ok,d0
.exit:
	move.l d0,-(sp)		;save Memory error
	move.l MemExch,d1	;Send a dummy message to pick up
	move.l #$FFFFFFF1,d2	; so next guy can get in
	move.l #$FFFFFFF1,d3
	move.l #$FFFFFFF1,d4
	move.l #OSSendMsg,d7
	trap #1						;Kernel error has priority
	tst.l d0
	bne.s .exit1
	move.l (sp)+,d0		;get Memory error back
	movem.l (sp)+,d1/d2/d3/d4/d6/d7/a1
	rts
.exit1:
	addq #4,sp				; get rid of old error
	movem.l (sp)+,d1/d2/d3/d4/d6/d7/a1
	rts

;=============================================================================
; QueryMemPages --
;
; Procedureal Interface :
;
;		QueryMemPages(pdnPagesRet):ercType
;
;	pdnPagesRet is a pointer where you want the count of pages
;   left available returned
;
; d1 = pMemleft 	EQU [EBP+0Ch]

_QueryPages:
	tst.l d1
	beq.s .argerr
	movem.l d1/d2/a1,-(sp)
	move.l d1,a1
	move.l _nPagesFree,d1
	; Should use PID of caller to map address
	move.w sr,d2
	ori.w #$2700,sr							; mask interrupts
	move.l MMU+$2110,MMU+$2100	; set PID to stacked PID
	move.l d1,(a1)
	move.l #1,MMU+$2100					; reset system PID
	move.w d2,sr								; restore interrupts
	move.l (sp)+,d1/d2/a1
	move.l #E_Ok,d0
	rts
.argerr:
	moveq #E_Arg,d0
	rts
	
;==============================================================================
;
; GetPhyAdd -- This returns the phyical address for a linear address
;
;
; Procedureal Interface :
;
;		GetPhyAdd(JobNum, LinAdd, pPhyRet):ercType
;
;	LinAdd is the Linear address you want the physical address for
;	pPhyRet points to the unsigned long where Phyadd is returned
;
;
; d1 = ProcessNum  EQU [EBP+20]
; d2 = LinAdd  EQU [EBP+16]
; d3 = pPhyRet EQU [EBP+12]
;

_GetPhyAdd:
	tst.l d3
	beq.s .argerr
	movem.l d1/d2/a1,-(sp)
	bsr LinToPhy
	move.l d3,a1
	; Should use PID of caller to map address
	move.w sr,d2
	ori.w #$2700,sr							; mask interrupts
	move.l MMU+$2110,MMU+$2100	; set PID to stacked PID
	move.l d1,(a1)
	move.l #1,MMU+$2100					; reset system PID
	move.w d2,sr								; restore interrupts
	moveq #E_Ok,d0
	movem.l (sp)+,d1/d2/a1
	rts
.argerr:
	moveq #E_Arg,d0
	rts
	
	global _nPagesFree
	global _oMemMax
	global rgPAM
	global sPAM
	global MarkPage
	global UnMarkPage
	global LinToPhy
	global _AliasMem
	global _DeAliasMem
	global _DeAllocPage
	global _QueryPages
	global _GetPhyAdd		


		
