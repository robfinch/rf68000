`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	nic.sv
//
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

import nic_pkg::*;

module rf68000_nic(id, rst_i, clk_i, s_cti_i, s_atag_o,
	s_cyc_i, s_stb_i, s_ack_o, s_aack_o, s_rty_o, s_err_o, s_vpa_o, 
	s_we_i, s_sel_i, s_asid_i, s_adr_i, s_dat_i, s_dat_o,
	s_mmus_i, s_ios_i, s_iops_i,
	m_cyc_o, m_stb_o, m_ack_i, m_err_i, m_vpa_i,
	m_we_o, m_sel_o, m_asid_o, m_adr_o, m_dat_o, m_dat_i,
	m_mmus_o, m_ios_o, m_iops_o,
	packet_i, packet_o, ipacket_i, ipacket_o,
	rpacket_i, rpacket_o,
	irq_i, firq_i, cause_i, iserver_i, irq_o, firq_o, cause_o);
parameter SYNC_WRITE = 1'b1;
input [5:0] id;
input rst_i;
input clk_i;
input [2:0] s_cti_i;
output reg [3:0] s_atag_o;
input s_cyc_i;
input s_stb_i;
output reg s_ack_o;
output reg s_rty_o;
output reg s_err_o;
output reg s_vpa_o;
output reg s_aack_o;
input s_we_i;
input [3:0] s_sel_i;
input [7:0] s_asid_i;
input [31:0] s_adr_i;
input [31:0] s_dat_i;
output reg [31:0] s_dat_o;
input s_mmus_i;
input s_ios_i;
input s_iops_i;
output reg m_cyc_o;
output reg m_stb_o;
input m_ack_i;
input m_err_i;
input m_vpa_i;
output reg m_we_o;
output reg [3:0] m_sel_o;
output reg [7:0] m_asid_o;
output reg [31:0] m_adr_o;
output reg [31:0] m_dat_o;
input [31:0] m_dat_i;
output reg m_mmus_o;
output reg m_ios_o;
output reg m_iops_o;
input packet_t packet_i;
output packet_t packet_o;
input packet_t rpacket_i;
output packet_t rpacket_o;

input ipacket_t ipacket_i;
output ipacket_t ipacket_o;
input [2:0] irq_i;
input firq_i;
input [7:0] cause_i;
input [5:0] iserver_i;
output reg [2:0] irq_o;
output reg firq_o;
output reg [7:0] cause_o;

reg [5:0] state;
parameter ST_IDLE = 6'd0;
parameter ST_READ = 6'd1;
parameter ST_READWRITE_ACK = 6'd2;
parameter ST_ACK = 6'd3;
parameter ST_ACK_ACK = 6'd4;
parameter ST_WRITE = 6'd5;
parameter ST_XMIT = 6'd7;
parameter ST_AACK = 6'd8;
parameter ST_RETRY = 6'd9;
parameter ST_ERR = 6'd10;
parameter ST_VPA = 6'd11;
reg [3:0] rsp_state;
reg [11:0] mto;

packet_t packet_rx, packet_tx;
packet_t rpacket_rx, rpacket_tx;
ipacket_t ipacket_tx;
packet_t [7:0] gbl_packets;
reg seen_gbl;
reg s_ack1;
reg cyc,cycd;

integer n,n1,n2;

always_comb
	cyc = s_cyc_i & s_stb_i;

always_comb
begin
	seen_gbl = FALSE;
	for (n = 0; n < 8; n = n + 1)
		if (gbl_packets[n]==packet_i)
			seen_gbl = TRUE;
end

reg rcv;
reg wait_ack;
reg rw_done;
reg burst;
always_comb
	burst = s_cti_i==3'b001||s_cti_i==3'b111;
always_comb
	s_ack_o <= s_ack1 & s_cyc_i & s_stb_i;

// Bus timeout for bus mastering.
wire timeout = mto[8];
always_ff @(posedge clk_i)
if (rst_i)
	mto <= 12'd0;
else begin
	if (m_ack_i|m_err_i|m_vpa_i)
		mto <= 12'd0;
	else if (m_cyc_o)
		mto <= mto + 1'b1;
	if (timeout)
		mto <= 12'd0;
end

always_ff @(posedge clk_i)
if (rst_i) begin
	s_ack1 <= FALSE;
	s_aack_o <= FALSE;
	s_dat_o <= 12'h00;
	s_atag_o <= 4'h0;
	s_err_o <= FALSE;
	s_rty_o <= FALSE;
	s_vpa_o <= FALSE;
	packet_o <= {$bits(packet_t){1'b0}};
	rpacket_o <= {$bits(packet_t){1'b0}};
	ipacket_o <= {$bits(ipacket_t){1'b0}};
	ipacket_tx <= {$bits(ipacket_t){1'b0}};
	packet_rx <= {$bits(packet_t){1'b0}};
	packet_tx <= {$bits(packet_t){1'b0}};
	rpacket_rx <= {$bits(packet_t){1'b0}};
	rpacket_tx <= {$bits(packet_t){1'b0}};
	for (n2 = 0; n2 < 8; n2 = n2 + 1)
		gbl_packets[n] <= {$bits(packet_t){1'b0}};
	rcv <= 1'b0;
	rw_done <= TRUE;
	wait_ack <= 1'b0;
	m_cyc_o <= 1'b0;
	m_stb_o <= 1'b0;
	m_we_o <= 1'b0;
	m_sel_o <= 4'h0;
	m_asid_o <= 'd0;
	m_mmus_o <= 'd0;
	m_ios_o <= 'd0;
	m_iops_o <= 'd0;
	m_adr_o <= 24'h0;
	m_dat_o <= 12'h00;
	irq_o <= 'd0;
	firq_o <= 'd0;
	cause_o <= 'd0;
	state <= ST_IDLE;
	rsp_state <= ST_IDLE;
	cycd <= 1'b0;
end
else begin
	cycd <= cyc;

	// This signal just pulses once.
	s_aack_o <= FALSE;

	// Transfer the packet around the ring on every clock cycle.
	packet_o <= packet_i;
	ipacket_o <= ipacket_i;
	rpacket_o <= rpacket_i;

	// Look for slave cycle termination. High to low transition on cyc.
	if (~cyc & cycd) begin
		rw_done <= TRUE;
		s_ack1 <= FALSE;
		s_rty_o <= FALSE;
		s_err_o <= FALSE;
		s_vpa_o <= FALSE;
	end

	if (firq_i| |irq_i) begin
		ipacket_o.sid <= id;
		ipacket_o.did <= iserver_i;
		ipacket_o.age <= 6'd0;
		ipacket_o.firq <= firq_i;
		ipacket_o.irq <= irq_i;
		ipacket_o.cause <= cause_i;
	end
	if (ipacket_i.did==id) begin
		ipacket_o.did <= 6'd0;
		irq_o <= ipacket_i.irq;
		firq_o <= ipacket_i.firq;
		cause_o <= ipacket_i.cause;
	end
	else if (ipacket_i.did==6'd63) begin
		irq_o <= ipacket_i.irq;
		firq_o <= ipacket_i.firq;
		cause_o <= ipacket_i.cause;
	end
	else begin
		irq_o <= 'd0;
		firq_o <= 'd0;
		cause_o <= 'd0;
	end

	// Receive response packet, even when not IDLE
	// Remove packet only if not a broadcast packet
	if ((rpacket_i.did==id || rpacket_i.did==6'd63) && rpacket_rx.did==6'd0) begin
		if (rpacket_i.did == id)
			rpacket_o.did <= 6'd0;
		rpacket_rx <= rpacket_i;
		case (rpacket_i.typ)
		PT_VPA:	rsp_state <= ST_VPA;
		PT_ERR:	rsp_state <= ST_ERR;
		PT_RETRY:	rsp_state <= ST_RETRY;
		PT_ACK:	rsp_state <= ST_ACK;
		PT_AACK:	rsp_state <= ST_AACK;
		default:	
			begin
				rpacket_rx.did <= 6'd0;
				rsp_state <= ST_IDLE;
			end
		endcase
	end

	// Was this request packet for us?
	// Remove packet only if not a broadcast packet
	if ((packet_i.did==id || packet_i.did==6'd63) && 
		packet_rx.did==6'd0 &&
		rpacket_tx.did==6'd0) begin
		if (packet_i.did == id)
			packet_o.did <= 6'd0;
		packet_rx <= packet_i;
		case (packet_i.typ)
		PT_READ,PT_AREAD:	state <= ST_READ;
		PT_WRITE:	state <= ST_WRITE;
		default:
			begin	
				packet_rx.did <= 6'd0;
				state <= ST_IDLE;
			end
		endcase
		// Have we seen packet already?
		// If not, add to seen list and process, otherwise ignore
		if (packet_i.did==6'd63 && !seen_gbl) begin
			for (n1 = 0; n1 < 7; n1 = n1 + 1)
				gbl_packets[n1+1] <= gbl_packets[n1];
			gbl_packets[0] <= packet_i;
			case (packet_i.typ)
			PT_WRITE:	state <= ST_WRITE;
			default:	
				begin
					packet_rx.did <= 6'd0;
					state <= ST_IDLE;
				end
			endcase
		end
	end

	// Transmit IPI packet
	if (!(firq_i| |irq_i) && ipacket_i.did==6'd0 && ipacket_tx.did != 6'd0) begin
		ipacket_o <= ipacket_tx;
		ipacket_tx.did <= 6'd0;
	end

	// Transmit waiting transmit buffers.
	if (packet_i.did==6'd0 && packet_tx.did!=6'd0) begin
		packet_o <= packet_tx;
		packet_tx.did <= 6'd0;
	end
	if (rpacket_i.did==6'd0 && rpacket_tx.did!=6'd0) begin
		rpacket_o <= rpacket_tx;
		rpacket_tx.did <= 6'd0;
	end
	
	if (packet_tx.did==6'd0 && rw_done)
		tSetupReadWrite(cyc, s_we_i, s_adr_i, s_dat_i);

	// Process request
	case(state)
	ST_IDLE:	;

	ST_READ:
		if (!m_ack_i) begin
			tBusCycle(FALSE,packet_rx);
			state <= ST_READWRITE_ACK;
		end

	ST_WRITE:
		if (!m_ack_i) begin
			tBusCycle(TRUE,packet_rx);
			state <= ST_READWRITE_ACK;
		end

	// Writes are posted so they do not generate a response.
	ST_READWRITE_ACK:
		begin
			if (m_ack_i) begin
				tClearBus();
				if (!m_we_o || SYNC_WRITE)
					tSetupResponsePacket(
						packet_rx.typ==PT_AREAD ? PT_AACK : PT_ACK,
						id,
						packet_rx.sid,
						packet_rx.adr,
						m_dat_i
					);
				packet_rx.did <= 6'd0;
				state <= ST_IDLE;
			end
			else if (m_err_i) begin
				tClearBus();
				if (!m_we_o || SYNC_WRITE)
					tSetupResponsePacket(
						PT_ERR,
						id,
						packet_rx.sid,
						packet_rx.adr,
						m_dat_i
					);
				packet_rx.did <= 6'd0;
				state <= ST_IDLE;
			end
			else if (m_vpa_i) begin
				tClearBus();
				if (!m_we_o || SYNC_WRITE)
					tSetupResponsePacket(
						PT_VPA,
						id,
						packet_rx.sid,
						packet_rx.adr,
						m_dat_i
					);
				packet_rx.did <= 6'd0;
				state <= ST_IDLE;
			end
			else if (timeout) begin
				tClearBus();
				if (!m_we_o || SYNC_WRITE)
					tSetupResponsePacket(
						PT_ERR,
						id,
						packet_rx.sid,
						packet_rx.adr,
						m_dat_i
					);
				packet_rx.did <= 6'd0;
				state <= ST_IDLE;
			end
		end

	default:
		state <= ST_IDLE;
	endcase

	// Process response packet
	case(rsp_state)
	ST_IDLE:	;
	ST_ACK:
		begin
			// If there is an active cycle
			if (cyc & ~s_we_i) begin
				if (TRUE || s_adr_i == rpacket_rx.adr) begin
					s_dat_o <= rpacket_rx.dat;
					s_ack1 <= TRUE;
					rsp_state <= ST_ACK_ACK;
				end
				else begin
					s_rty_o <= TRUE;
					rsp_state <= ST_ACK_ACK;
				end
			end
			// If we got an ack for an asynch write cycle and the cycle is still active
			// treat it like a sync write.
			else if (cyc & s_we_i) begin
				if (TRUE || s_adr_i == rpacket_rx.adr) begin
					if (TRUE || SYNC_WRITE) begin
						s_ack1 <= TRUE;
					end
					rsp_state <= ST_ACK_ACK;
				end
				else begin
					s_rty_o <= TRUE;
					rsp_state <= ST_ACK_ACK;
				end
			end
			else begin
				rpacket_rx.did <= 6'd0;
				rsp_state <= ST_IDLE;
			end
		end
	ST_ACK_ACK:
		// Wait for the slave cycle to finish.
		if (~cyc) begin
			rpacket_rx.did <= 6'd0;
			rsp_state <= ST_IDLE;
		end
	ST_VPA:
		begin
			s_vpa_o <= TRUE;
			s_atag_o <= rpacket_rx.adr[3:0];
			rpacket_rx.did <= 6'd0;
			rsp_state <= ST_IDLE;
		end
	ST_RETRY:
		begin
			s_rty_o <= TRUE;
			s_atag_o <= rpacket_rx.adr[3:0];
			rpacket_rx.did <= 6'd0;
			rsp_state <= ST_IDLE;
		end
	ST_ERR:
		begin
			s_err_o <= TRUE;
			s_atag_o <= rpacket_rx.adr[3:0];
			rpacket_rx.did <= 6'd0;
			rsp_state <= ST_IDLE;
		end
		
	// Asynchronous acknowledge; there does not need to be an active slave cycle.
	// It is assumed the slave is waiting for the response.
	ST_AACK:
		begin
			s_aack_o <= TRUE;
			s_atag_o <= rpacket_rx.adr[3:0];
			s_dat_o <= rpacket_rx.dat;
			rpacket_rx.did <= 6'd0;
			rsp_state <= ST_IDLE;
		end

	default:
		rsp_state <= ST_IDLE;
	endcase
end

task tSetupResponsePacket;
input [5:0] typ;
input [5:0] id;
input [5:0] sid;
input [31:0] adr;
input [31:0] dat;
begin
	rpacket_tx <= {$bits(packet_t){1'b0}};
	rpacket_tx.sid <= id;
	rpacket_tx.did <= sid;
	rpacket_tx.age <= 6'd0;
	rpacket_tx.typ <= typ;
	rpacket_tx.ack <= TRUE;
	rpacket_tx.asid <= m_asid_o;
	rpacket_tx.mmus <= m_mmus_o;
	rpacket_tx.ios <= m_ios_o;
	rpacket_tx.iops <= m_iops_o;
	rpacket_tx.adr <= adr;
	rpacket_tx.dat <= dat;
end
endtask

task tSetupReadWrite;
input cyc;
input wr;
input [31:0] adr;
input [31:0] dat;
begin
	if (cyc) begin
		rw_done <= FALSE;
		casez(adr)
		// IPI?
		32'h001FFFFC:
			begin
				ipacket_tx.sid <= id;
				ipacket_tx.age <= 6'd0;
				ipacket_tx.did <= dat[21:16];
				ipacket_tx.firq <= dat[15];
				ipacket_tx.irq <= dat[14:12];
				ipacket_tx.cause <= dat[7:0];
			end
		default:
			begin
				packet_tx.sid <= id;
				packet_tx.age <= 6'd0;
				packet_tx.ack <= 1'b0;
				packet_tx.typ <= wr ? PT_WRITE : burst ? PT_AREAD : PT_READ;
				packet_tx.pad2 <= 2'b0;
				packet_tx.we <= wr;
				packet_tx.sel <= s_sel_i;
				packet_tx.asid <= s_asid_i;
				packet_tx.mmus <= s_mmus_i;
				packet_tx.ios <= s_ios_i;
				packet_tx.iops <= s_iops_i;
				packet_tx.adr <= adr;
				packet_tx.dat <= dat;
			end
		endcase
		casez(adr[31:24])
		// Read global ROM? / INTA
		8'hFF:	
			if (!wr) begin
				packet_tx.did <= 6'd62;
				s_ack1 <= burst;
				rw_done <= burst;
			end
			else begin
				packet_tx.did <= 6'd62;
				s_ack1 <= wr & ~SYNC_WRITE;
			end
		/* I/O area */
		8'hFD,
		8'h01:	// virtual address
			begin
				packet_tx.did <= 6'd62;
				s_ack1 <= (wr & ~SYNC_WRITE)|burst;
			end
		// Global broadcast
		8'hDF:
			begin
				packet_tx.did <= 6'd63;
				packet_tx.age <= 6'd30;
				s_ack1 <= (wr & ~SYNC_WRITE)|burst;
			end
		// C0xyyyyy
		8'hC0:
			begin
				if (adr!=32'hC0FFFFFC)
					packet_tx.did <= {2'd0,adr[23:20]};
				s_ack1 <= (wr & ~SYNC_WRITE)|burst;
			end
		8'h8?,8'h9?,8'hA?,8'hB?:
			begin
				packet_tx.did <= 6'd62;
				s_ack1 <= (wr & ~SYNC_WRITE)|burst;
			end
		/* Global DRAM area */
		8'h4?,8'h5?,8'h6?,8'h7?:
			begin
				packet_tx.did <= 6'd62;
				s_ack1 <= (wr & ~SYNC_WRITE)|burst;
			end
		8'h00:
			if (adr==32'h001FFFFC)
				s_ack1 <= (wr & ~SYNC_WRITE)|burst;
			else if (adr[23:20]>=4'h1) begin
				packet_tx.did <= 6'd62;
				s_ack1 <= (wr & ~SYNC_WRITE)|burst;
			end
			else begin
				packet_tx.did <= 6'd0;
				rw_done <= TRUE;
			end
		default:
			begin
				packet_tx.did <= 6'd0;
				rw_done <= TRUE;
			end
		endcase
	end
end
endtask

task tBusCycle;
input wr;
input packet_t packet_rx;
begin
	m_cyc_o <= TRUE;
	m_stb_o <= TRUE;
	m_we_o <= wr;
	m_sel_o <= packet_rx.sel;
	m_asid_o <= packet_rx.asid;
	m_adr_o <= packet_rx.adr;
	m_dat_o <= packet_rx.dat;
	m_mmus_o <= packet_rx.mmus;
	m_ios_o <= packet_rx.ios;
	m_iops_o <= packet_rx.iops;
end
endtask

task tClearBus;
begin
	m_cyc_o <= FALSE;
	m_stb_o <= FALSE;
	m_we_o <= FALSE;
	m_sel_o <= 4'h0;
	m_mmus_o <= FALSE;
	m_ios_o <= FALSE;
	m_iops_o <= FALSE;
end
endtask

endmodule
