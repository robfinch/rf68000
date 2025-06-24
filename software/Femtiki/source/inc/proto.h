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
// ACB functions
ACB *GetACBPtr();                   // get the ACB pointer of the running task
ACB *GetRunningACBPtr();
hACB GetAppHandle();
extern hTCB GetRunningTCB();
extern TCB *GetRunningTCBPtr();
extern unsigned long get_tick();

void FMTK_Reschedule();
int FMTK_SendMsg(hMBX hMbx, int d1, int d2, int d3);
int FMTK_WaitMsg(hMBX hMbx, int *d1, int *d2, int *d3, int timelimit);
int FMTK_StartThread(unsigned short *pCode, int stacksize, int *pStack, char *pCmd, int info);
int FMTK_StartApp(AppStartupRec *rec);
void RequestIOFocus(ACB *);

int chkTCB(TCB *p);
int InsertIntoReadyList(hTCB ht);
int RemoveFromReadyList(hTCB ht);
int InsertIntoTimeoutList(hTCB ht, int to);
int RemoveFromTimeoutList(hTCB ht);
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
int LockSemaphore(int *sema, int retries);
inline void UnlockSemaphore(long *sema)
{
	*sema = 0;
}

int LockSysSemaphore(int retries);
int LockIOFSemaphore(int retries);
int LockKbdSemaphore(int retries);
inline void UnlockIOFSemaphore()
{
}

inline void UnlockKbdSemaphore()
{
}


inline int GetImLevel()
{
}

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

extern int mmu_Alloc8kPage();
extern void mmu_Free8kPage(int pg);
extern int mmu_Alloc512kPage();
extern void mmu_Free512kPage(int pg);
extern void mmu_SetAccessKey(int mapno);
extern int mmu_SetOperateKey(int mapno);
extern void *mmu_alloc(int amt, int acr);
extern void mmu_free(void *pmem);
extern void mmu_SetMapEntry(void *physptr, int acr, int entryno);
extern int mmu_AllocateMap();
extern void mmu_FreeMap(int mapno);
extern int *mmu_MapCardMemory();

extern void DBGDisplayChar(char);
extern void DBGDisplayString(char *);
extern void DBGDisplayStringCRLF(char *);

extern long* LinearToPhysical(short int pid, long* linadr);

#endif
