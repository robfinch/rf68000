// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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

package nic_pkg;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

// Packet types
parameter PT_NULL = 6'd0;
parameter PT_READ = 6'd1;
parameter PT_WRITE = 6'd2;
parameter PT_ACK = 6'd3;
parameter PT_RETRY = 6'd4;
parameter PT_AREAD = 6'd5;	// asynchronous read
parameter PT_AACK = 6'd6;
parameter PT_ERR = 6'd7;
parameter PT_VPA = 6'd8;

typedef logic [31:0] address_t;
typedef logic [31:0] data_t;

typedef struct packed
{
	logic [5:0] did;
	logic [5:0] sid;
	logic [5:0] age;
	logic ack;
	logic [5:0] typ;
	logic [1:0] pad2;
	logic we;
	logic [3:0] sel;
	logic [7:0] asid;
	logic mmus;
	logic ios;
	logic iops;
	logic [2:0] fc;
	address_t adr;
	data_t dat;
} packet_t;

typedef struct packed
{
	logic [5:0] did;
	logic [5:0] sid;
	logic [5:0] age;
	logic [2:0] irq;
	logic [1:0] resv;
	logic firq;
	logic [7:0] cause;
} ipacket_t;	// 32 bits

endpackage
