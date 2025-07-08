// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// glo.h
// Global variables.
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
#ifndef _GLO_H
#define _GLO_H

extern int irq_stack[];
extern int FMTK_Inited;
extern ACB *ACBPtrs[NR_ACB];
extern TCB tcbs[];
extern hTCB readyQ[32];
extern hTCB freeTCB;
extern int sysstack[];
extern int stacks[][];
extern int sys_stacks[][];
extern int bios_stacks[][];
extern int fmtk_irq_stack[];
extern int fmtk_sys_stack[];
extern MBX mailbox[];
extern MSG message[];
extern int nMsgBlk;
extern int nMailbox;
extern hMSG freeMSG;
extern hMBX freeMBX;
extern ACB *IOFocusNdx;
extern int IOFocusTbl[];
extern int iof_switch;
extern int BIOS1_sema;
extern int iof_sema;
extern int sys_sema;
extern int kbd_sema;
extern int BIOS_RespMbx;
extern long hasUltraHighPriorityTasks;
extern int missed_ticks;
extern short int video_bufs[][];
extern hTCB TimeoutList;
extern hMBX hFocusSwitchMbx;
extern ACB SysAcb;

#endif
