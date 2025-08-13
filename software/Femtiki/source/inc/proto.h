#ifndef _PROTO_H
#define _PROTO_H

// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// proto.h
// Function prototypes.
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
// ACB functions
ACB *GetACBPtr();                   // get the ACB pointer of the running task
extern ACB *GetRunningACBPtr();

int getCPU() = 
	"\tmovec coreno,d0\r\n"
;

unsigned long GetTick() =
	"\tmovec.l tick,d0\r\n"
;

hTCB GetRunningAppid() =
	"\tmovec.l cpid,d0\r\n"
;
void SetRunningAppid(__reg("d0") hACB h) =
	"\tmovec.l d0,cpid\r\n"
;
hTCB GetRunningTCB() =
	"\tmovec.l tr,d0\r\n"
	"\tbclr #31,d0\r\n"
;
void SetRunningTCB(__reg("d0") hTCB h) =
	"\tmovec.l d0,tr\r\n"
;

TCB* GetRunningTCBPtr() =
	"\tmovec.l tcba,d0\r\n"
;

// wh=0 user
// wh=1 system
// wh=2 dma

void SetMMUPD(__reg("d0") long wh, __reg("d1") long pd) =
	"\tmovem.l d0/d1/a0,-(sp)\r\n"
	"\tlea $FDC00040,a0\r\n"
	"\tlsl.l #3,d0\r\n"
	"\tadd.l d0,a0\r\n"
	"\tmove.l d1,(a0)\r\n"
	"\tmovem.l (sp)+,d0/d1/a0\r\n"
;

void SetMMUAppid(__reg("d0") long appid) =
	"\tmove.l d0,$FDC00008\r\n"
;

int SetImLevel7() =
	"\tmove sr,d0\r\n"
	"\tori #$700,sr\r\n"
;

void RestoreSr(__reg("d0") int sr) = 
	"\tmove d0,sr\r\n"
;

// ----------------------------------------------------------------------------
// FMTK primitives need to re-schedule threads in a couple of places.
// ----------------------------------------------------------------------------

void FMTK_Stop() = 
	"\tstop #$2000\r\n"					// wait for 1interrupt
;

void FMTK_Reschedule() =
	"\tmove.l #$03000000,$FD260018\r\n"	// trigger IRQ in PIC
	"\tstop #$2000\r\n"					// wait for the interrupt
;

extern int SetImLevel(int level);
extern void SetImLevelHelper(__reg("d0") int level);
extern hACB GetRunningAppid();
extern TCB *GetRunningTCBPtr();
extern void SetRunningTCBPtr(TCB *p);
extern void ISetRunningTCBPtr(TCB *p);
extern hACB ACBPointerToHandle(ACB* ptr);
extern ACB* ACBHandleToPointer(hACB h);
extern TCB* TCBHandleToPointer(hTCB h);
extern hTCB TCBPointerToHandle(TCB* p);
extern MBX* MBXHandleToPointer(hMBX h);
extern ALARM* AlarmHandleToPointer(hALARM h);
extern unsigned long get_tick();
extern int IsSystemApp(hACB);

void FMTK_Reschedule();
long FMTK_Initialize();
long FMTK_Sleep(__reg("d0") long);
long FMTK_SendMsg(__reg("d0") long hMbx, __reg("d1") long pMsg);
long FMTK_PostMsg(__reg("d0") long hMbx, __reg("d1") long pMsg);
long FMTK_WaitMsg(__reg("d0") long hMbx, __reg("d1") long pMsg, __reg("d2") long timelimit);
long FMTK_PeekMsg(__reg("d0") long hMbx, __reg("d1") long pMsg);
long FMTK_CheckMsg(__reg("d0") long hMbx, __reg("d1") long pMsg, __reg("d2") long qrmv);
long FMTK_StartThread(__reg("d0") long pCode, __reg("d1") long stack, __reg("d2") long pCmd, __reg("d3") long priority, __reg("d4") long affinity);
long FMTK_ExitThread();
long FMTK_KillThread(__reg("d0") long);
long FMTK_AllocMbx();
long FMTK_FreeMbx(__reg("d0") long hMbx);
long FMTK_SetThreadPriority(__reg("d0") long hTCB, __reg("d1") long pri);
long FMTK_StartApp(__reg("d0") long rec, __reg("d1") long hParent);
long FMTK_RegisterService(__reg("d0") long pName);
long FMTK_UnregisterService(__reg("d0") long pName);
long FMTK_GetServiceMbx(__reg("d0") long name);
long FMTK_AllocSystemPages(__reg("d0") long numpage, __reg("d0") long ppAddr);
long FMTK_AllocPages(__reg("d0") long numpage, __reg("d0") long ppAddr);
long FMTK_AliasMem(__reg("d0") long pMem,__reg("d1") long cbMem,__reg("d2") long hApp,__reg("d3") long ppAliasRet);
long FMTK_DeAliasMem(__reg("d0") long hACB, __reg("d1") long pMem, __reg("d2") long len);
long FMTK_AllocTimer();
long FMTK_FreeTimer(__reg("d0") long ht);
long FMTK_SetAlarm(
	__reg("d0") long hTmr,
	__reg("d1") long hMbx,
	__reg("d2") long ticklo,
	__reg("d3") long tickhi,
	__reg("d4") long opt
);
long FMTK_KillAlarm(__reg("d0") long hTmr);

void RequestIOFocus(ACB *);

int chkTCB(TCB *p);
int TCBInsertIntoReadyQueue(hTCB ht);
int TCBRemoveFromReadyQueue(hTCB ht);
int TCBInsertIntoTimeoutList(hTCB ht, int to);
int TCBRemoveFromTimeoutList(hTCB ht);
hTCB TCBPopTimeoutList();
void DumpTaskList();

void SetBound48(TCB *ps, TCB *pe, int algn);
void SetBound49(ACB *ps, ACB *pe, int algn);
void SetBound50(MBX *ps, MBX *pe, int algn);
void SetBound51(MSG *ps, MSG *pe, int algn);

void set_vector(unsigned int, unsigned int);
int getCPU();
int GetVecno();          // get the last interrupt vector number
void outb(unsigned int, int);
void outc(unsigned int, int);
void outh(unsigned int, int);
void outw(unsigned int, int);
int LockSemaphore(long sema, int retries);
void UnlockSemaphore(long sema, int stat);

int LockSysSemaphore(long retries);
int LockIOFSemaphore(long retries);
int LockKbdSemaphore(long retries);
int LockMMUSemaphore(long retries);
int LockPMTSemaphore(long retries);
int LockMSGList(long retries);
int LockMBX(long hMbx, long retries);
int LockMBXList(long retries);
int LockTimeoutList(long retries);
int LockReadyQueue(long retries);
int LockTCBList(long retries);
int LockACBSemaphore(long retries);
int LockAlarmList(long retries);
int LockTMRSemaphore(long retries);

void UnlockSysSemaphore(int);
void UnlockIOFSemaphore(int);
void UnlockKbdSemaphore(int);
void UnlockMMUSemaphore(int);
void UnlockPMTSemaphore(int);
void UnlockMSGList(int);
void UnlockMBX(hMBX,int);
void UnlockMBXList(int);
void UnlockTimeoutList(int);
void UnlockReadyQueue(int);
void UnlockTCBList(int);
void UnlockACBSemaphore(int);
void UnlockAlarmList(int);
void UnlockTMRSemaphore(int);

// Restoring the interrupt level does not have a ramp, because the level is
// being set back to enable interrupts, from a disabled state. Following the
// restore interupts are allowed to happen, we don't care if they do.

inline void RestoreImLevel(int level)
{
}

// The following causes a privilege violation if called from user mode
#define check_privilege() asm { }

// tasks
void FocusSwitcher();

inline void LEDS(int val)
{
}

extern char* FindFreePage();
extern void FreeACB(hACB);
extern hACB FindFreeACB();
extern void* mem_alloc(hACB,unsigned long sz,int acr);
extern void mem_free(hACB,void *p);

extern void OutputChar(char);
extern void DBGDisplayChar(char);
extern void DBGDisplayString(char *);
extern void DBGDisplayStringCRLF(char *);
extern void DisplayStringCRLF(__reg("a1") char *);
void DisplayLEDS(__reg("d0") long v) =
	"\tmove.b d0,$FDFFC000\r\n"
;

extern char* LinearToPhysical(hACB appid, char* linadr);

extern long CheckForCtrlC();
extern void panic(char*);
extern void putstr(char*);
extern long get_coreno();
extern void SetupDevices();

#endif
