#include <string.h>
#include "..\inc\config.h"
#include "..\inc\types.h"

extern hRQB FreeRBQ;
extern long nRequest;
extern service_t service[NR_SERVICE];

/*
		Initialize request blocks and services.
*/

void RQB_Initialize()
{
	int nn;
	
	for (nn = 0; nn < NR_RQB; nn++) {
		memset(&request_block[nn],0,sizeof(request_t));
		request_block[nn].next = nn+2;
	}	
	for (nn = 0; nn < NR_SERVICE; nn++)
		memset(service[nn],0,sizeof(service_t));
	FreeRQB = 1;
	nRequest = NR_RQB;
}

hRQB RQB_Alloc()
{
	hRQB rqb;
	
	rqb = FreeRQB;
	if (rqb > 0) {
		FreeRQB = request_block[rqb-1].next;
		nRequest--;	
		request_block[rqb-1].magic = 0x52514220;	// 'RQB '
		request_block[rqb-1].owner = GetRunningAppid();
	}
	return (rqb);
}

void RQB_Free(hRQB rqb) {
	if (rqb > 0) {
		request_blocks[rqb-q].next = FreeRQB;
		FreeRQB = rqb;
		nRequest++;
	}
}

hMBX GetServiceMbx(char *name)
{
	int nn;
	
	for (nn = 0; nn < NR_SERVICE; nn++) {
		if (stricmp(name,service[nn].name)) {
			return (service[nn].service_mbx);
		}
	}
	return (0);
}

long RegisterService(char *name)
{
	int nn;
	hMBX mbx;
	
	for (nn = 0; nn < NR_SERVICE; nn++) {
		if (service[nn].name[0]=='\0') {
			mbx = FMTK_AllocMbx();
			if (mbx > 0) {
				strncpy(service[nn].name, name, 61);
				service[nn].service_mbx = mbx;
				return (1);
			}
		}
	}
	return (0);
}

long UnregisterService(char *name)
{
	int nn;
	hMBX mbx;
	
	for (nn = 0; nn < NR_SERVICE; nn++) {
		if (strncmp(service[nn].name,name,61)==0) {
			service[nn].name[0] = '\0';
			service[nn].service_mbx = 0;
			return (1);
		}
	}
	return (0);
}

;=============================================================================
; The response primitive is used by system services to respond to a
; Request received at their service exchange.  The RqBlk handle must be
; supplied along with the error/status code to be returned to the
; caller.  This is very similar to Send except is dealiases addresses
; in the RqBlk and then deallocates it.  The exchange to respond to
; is located inside the RqBlk.
; If dStatRet is ErcOwnerAbort, simply return the Reqest Block
; to the free pool and return Erc 0 to caller.
;     Respond(dRqHndl, dStatRet): dError
;
;
dRqHndl	 EQU DWORD PTR [EBP+16]
dStatRet EQU DWORD PTR [EBP+12]

PUBLIC __Respond: 				;
		PUSH EBP				; Save Callers Frame
		MOV EBP,ESP				; Setup Local Frame
;RAB
		MOV EAX, dRqHndl		; pRqBlk into EAX
		MOV EBX, dStatRet
		CMP EBX, ErcOwnerAbort	;
		JNE Resp01
		CLI						; No interruptions
		CALL DisposeRQB			; Return Aborted RQB to pool.
		XOR EAX, EAX            ; No Error
		JMP RespEnd				; Get out
Resp01:
;RAB
		MOV ESI, [EAX+RespExch] ; Response Exchange into ESI
		CMP ESI,nExch           ; Is the exchange out of range?
		JNAE Resp02             ; No, continue
		MOV EAX,ercOutOfRange   ; Error into the EAX register.
		JMP RespEnd				; Get out
Resp02:
        MOV EAX,ESI             ; Exch => EAX
		MOV EDX,sEXCH           ; Compute offset of Exch in rgExch
		MUL EDX                 ;
		MOV EDX,prgExch         ; Add offset of rgExch => EAX
		ADD EAX,EDX             ;
		MOV ESI,EAX             ; MAKE ESI <= pExch
		CMP DWORD PTR [EAX+Owner], 0    ; If the exchange is not allocated
		JNE Resp04              ; return to the caller with error
		MOV EAX,ercNotAlloc     ; in the EAX register.
		JMP RespEnd				;
Resp04:
		MOV EAX, dRqHndl        ; Get Request handle into EBX (pRqBlk)
		MOV EBX, [EAX+RqOwnerJob]
		CALL GetCrntJobNum
		CMP EAX, EBX
		JE Resp06				;Same job - no DeAlias needed

		MOV EAX, dRqHndl        ; Get Request handle into EBX (pRqBlk)
		MOV EBX, [EAX+cbData1]	;
		OR EBX, EBX
		JZ Resp05				;No need to dealias (zero bytes)
		MOV EDX, [EAX+pData1]
		OR EDX, EDX
		JZ Resp05				;Null pointer!

		PUSH ESI				;Save pExch across call

		PUSH EDX				;pMem
		PUSH EBX				;cbMem
		CALL GetCrntJobNum
		PUSH EAX
		CALL FWORD PTR _DeAliasMem	;DO it and ignore errors
		POP ESI					;get pExch back
Resp05:
		MOV EAX, dRqHndl        ; Get Request handle into EBX (pRqBlk)
		MOV EBX, [EAX+cbData2]	;
		OR EBX, EBX
		JZ Resp06				;No need to dealias (zero bytes)
		MOV EDX, [EAX+pData2]
		OR EDX, EDX
		JZ Resp06				;Null pointer!
		PUSH ESI				;Save pExch across call

		PUSH EDX				;pMem
		PUSH EBX				;cbMem
		CALL GetCrntJobNum		;
		PUSH EAX
		CALL FWORD PTR _DeAliasMem	;DO it and ignore errors
		POP ESI					;get pExch back
Resp06:
		MOV EAX, dRqHndl        ; Get Request handle into EBX (pRqBlk)
		CLI						; No interruptions
		CALL DisposeRQB			; Return Rqb to pool. Not needed anymore

		; Allocate a link block
		MOV EAX,pFreeLB         ; NewLB <= pFreeLB;
		OR EAX,EAX              ; IF pFreeLB=NIL THEN No LBs;
		JNZ Resp07              ;
		MOV EAX,ercNoMoreLBs    ; caller with error in the EAX register
		JMP RespEnd
Resp07:
		MOV EBX,[EAX+NextLB]    ; pFreeLB <= pFreeLB^.Next
		MOV pFreeLB,EBX         ;
		DEC _nLBLeft			;

        MOV DWORD PTR [EAX+LBType], RESPLB ; This is a Response Link Block
		MOV DWORD PTR [EAX+NextLB], 0      ; pLB^.Next <= NIL;
		MOV EBX, dRqHndl        ; Get Request handle into EBX
		MOV [EAX+DataLo],EBX    ; Store in lower half of pLB^.Data
		MOV EBX, dStatRet       ; Get Status/Error into EBX
		MOV [EAX+DataHi],EBX    ; Store in upper half of pLB^.Data
		PUSH EAX                ; Save pLB on the stack
		CALL deQueueTSS         ; DeQueue a TSS on that Exch
		OR  EAX,EAX             ; Did we get one?
		JNZ Resp08              ; Yes, give up the message
		POP EAX                 ; Get the pLB just saved
		CALL enQueueMsg         ; EnQueue the Message on Exch
		XOR EAX, EAX			; No Error
		JMP SHORT RespEnd       ; And get out!
Resp08:
        POP EBX                 ; Get the pLB just saved into EBX
		MOV [EAX+pLBRet],EBX    ; and put it in the TSS
		CALL enQueueRdy         ; EnQueue the TSS on the RdyQ
		MOV EAX,pRunTSS         ; Get the Ptr To the Running TSS
		CALL enQueueRdy         ; and put him on the RdyQ
		CALL deQueueRdy         ; Get high priority TSS off the RdyQ

		CMP EAX,pRunTSS         ; If the high priority TSS is the
		JNE Resp10              ; same as the Running TSS then return
		XOR EAX,EAX             ; Return to Caller with erc ok.
		JMP SHORT RespEnd		;
Resp10:
        MOV pRunTSS,EAX         ; Make the TSS in EAX the Running TSS
		MOV BX,[EAX+Tid]        ; Get the task Id (TR)
		MOV TSS_Sel,BX          ; Put it in the JumpAddr
		INC _nSwitches
		MOV EAX, TimerTick		;Save time of this switch for scheduler
		MOV SwitchTick, EAX		;
		JMP FWORD PTR [TSS]     ; JMP TSS
        XOR EAX,EAX             ; Return to Caller with erc ok.
RespEnd:
		STI
		MOV ESP,EBP				;
		POP EBP					;
		RETF 8					; Rtn to Caller & Remove Params

