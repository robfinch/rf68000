	ifnd MAX_TID
MAX_TID		EQU		255
NR_TCB		EQU		256
NTASK     EQU   256    ; number of threads allowed
LOG_TCBSZ	EQU		8
LOG_PGSZ	EQU		13
LOG_ACBSZ EQU   13
OSPAGES		EQU		16			; pages of memory dedicated to OS
PAGESZ    EQU   8192  	; size of a page of memory
MEMSZ     EQU   131072   ; pages
MBX_BLOCKPTR_BUFSZ  EQU   8 ; number of block pointer entries
NR_MSG		EQU		800		; number of messages available
NR_MBX		EQU		128
NR_RBQ		equ		64
NR_SERVICE	equ		64
PMTESIZE	EQU		16

SCREEN_FORMAT equ 1
HAS_MMU equ 0
TEXTCOL equ 64
TEXTROW equ 32
VIDEO_X	equ 800
VIDEO_Y	equ 600
VIDEO_Z	equ	256

	endif


