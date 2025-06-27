MAX_TID		EQU		4095
NR_TCB		EQU		4096
NTASK     EQU   4096    ; number of threads allowed
LOG_TCBSZ	EQU		8
LOG_PGSZ	EQU		14
LOG_ACBSZ EQU   12
OSPAGES		EQU		16			; pages of memory dedicated to OS
PAGESZ    EQU   16384  	; size of a page of memory
MEMSZ     EQU   65536   ; pages
MBX_BLOCKPTR_BUFSZ  EQU   8 ; number of block pointer entries
NR_MSG		EQU		21842		; number of messages available
NR_MBX		EQU		9792
PMTESIZE	EQU		16

SCREEN_FORMAT equ 1
HAS_MMU equ 0
TEXTCOL equ 64
TEXTROW equ 32
VIDEO_X	equ 800
VIDEO_Y	equ 600
VIDEO_Z	equ	256



