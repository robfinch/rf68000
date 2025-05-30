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

import const_pkg::*;
import nic_pkg::*;

module rf68000_nic(id, rst_i, clk_i, s_cti_i, s_atag_o,
	s_cyc_i, s_stb_i, s_ack_o, s_aack_o, s_rty_o, s_err_o, s_vpa_o, 
	s_we_i, s_sel_i, s_asid_i, s_adr_i, s_dat_i, s_dat_o,
	s_mmus_i, s_ios_i, s_iops_i,
	m_core_o, m_cyc_o, m_stb_o, m_ack_i, m_err_i, m_vpa_i,
	m_we_o, m_sel_o, m_asid_o, m_adr_o, m_dat_o, m_dat_i, m_core_i,
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
output reg [5:0] m_core_o;
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
input [5:0] m_core_i;
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
parameter ST_READ_ACK = 6'd2;
parameter ST_ACK = 6'd3;
parameter ST_ACK_ACK = 6'd4;
parameter ST_WRITE = 6'd5;
parameter ST_WRITE_ACK = 6'd6;
parameter ST_XMIT = 6'd7;
parameter ST_AACK = 6'd8;
parameter ST_RETRY = 6'd9;
parameter ST_ERR = 6'd10;
parameter ST_VPA = 6'd11;
parameter ST_WRITE_ACK_ASYNC = 6'd12;

packet_t packet_rx, packet_tx;
packet_t rpacket_rx, rpacket_tx;
packet_t [7:0] gbl_packets;
reg seen_gbl;
reg s_ack1;

integer n,n1,n2;

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
reg [11:0] mto;
wire timeout = mto[9];
always_ff @(posedge clk_i)
if (rst_i)
	mto <= 12'd0;
else begin
	if ((m_ack_i|m_err_i|m_vpa_i) | ~m_cyc_o)
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
	packet_rx <= {$bits(packet_t){1'b0}};
	packet_tx <= {$bits(packet_t){1'b0}};
	rpacket_rx <= {$bits(packet_t){1'b0}};
	rpacket_tx <= {$bits(packet_t){1'b0}};
	for (n2 = 0; n2 < 8; n2 = n2 + 1)
		gbl_packets[n] <= {$bits(packet_t){1'b0}};
	rcv <= 1'b0;
	rw_done <= TRUE;
	wait_ack <= 1'b0;
	m_core_o <= 6'd0;
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
end
else begin
	// This signal just pulses once.
	s_aack_o <= FALSE;

	// Transfer the packet around the ring on every clock cycle.
	packet_o <= packet_i;
	ipacket_o <= ipacket_i;
	rpacket_o <= rpacket_i;

	if (packet_i.did==6'd0 && packet_tx.did!=6'd0) begin
		packet_o <= packet_tx;
		packet_tx.did <= 6'd0;
		packet_tx.sid <= 6'd0;
	end
	if (rpacket_i.did==6'd0 && rpacket_tx.did!=6'd0) begin
		rpacket_o <= rpacket_tx;
		rpacket_tx.did <= 6'd0;
		rpacket_tx.sid <= 6'd0;
	end
	
	// Look for slave cycle termination.
	if (~(s_cyc_i & s_stb_i)) begin
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
		ipacket_o <= 'd0;
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

	case(state)
	ST_IDLE:
		begin
			if (rpacket_i.did==id || rpacket_i.did==6'd63) begin
				rpacket_rx <= rpacket_i;
				// Remove packet only if not a broadcast packet
				if (rpacket_i.did==id) begin
					case (rpacket_i.typ)
					PT_VPA:
						begin
							rpacket_o.did <= 6'd0;
							rpacket_o.sid <= 6'd0;
							state <= ST_VPA;
						end
					PT_ERR:
						begin
							rpacket_o.did <= 6'd0;
							rpacket_o.sid <= 6'd0;
							state <= ST_ERR;
						end
					PT_RETRY:
						begin
							rpacket_o.did <= 6'd0;
							rpacket_o.sid <= 6'd0;
							state <= ST_RETRY;
						end
					PT_ACK:
						begin
							rpacket_o.did <= 6'd0;
							rpacket_o.sid <= 6'd0;
							state <= ST_ACK;
						end
					PT_AACK:
						begin
							rpacket_o.did <= 6'd0;
							rpacket_o.sid <= 6'd0;
							state <= ST_AACK;
						end
					default:
						begin
							rpacket_o.did <= 6'd0;
							rpacket_o.sid <= 6'd0;
						end
					endcase
				end
			end
			// Was this packet for us?
			else if (packet_i.did==id || packet_i.did==6'd63) begin
				packet_rx <= packet_i;
				// Remove packet only if not a broadcast packet
				if (packet_i.did==id) begin
					case (packet_i.typ)
					PT_READ,PT_AREAD:
						if (rpacket_tx.did==6'd0) begin
							packet_o.did <= 6'd0;
							packet_o.sid <= 6'd0;
							state <= ST_READ;
						end
					PT_WRITE:	
						begin
							packet_o.did <= 6'd0;
							packet_o.sid <= 6'd0;
							state <= ST_WRITE;
						end
					default:
						begin
							packet_o.did <= 6'd0;
							packet_o.sid <= 6'd0;
						end
					endcase
				end
				// Have we seen packet already?
				// If not, add to seen list and process, otherwise ignore
				else if (!seen_gbl) begin
					for (n1 = 0; n1 < 7; n1 = n1 + 1)
						gbl_packets[n1+1] <= gbl_packets[n1];
					gbl_packets[0] <= packet_i;
					case (packet_i.typ)
					//PT_ACK:		state <= ST_ACK;
					//PT_READ:	state <= ST_READ;
					PT_WRITE:	state <= ST_WRITE;
					default:	;
					endcase
				end
			end
			// If previous op is complete, and theres nothing in the transmit buffer.
			else if (packet_tx.did==6'd0) begin
				tSetupReadWrite();
			end
		end

	ST_READ:
		if (!m_ack_i) begin
			m_core_o <= packet_rx.sid;
			m_cyc_o <= TRUE;
			m_stb_o <= TRUE;
			m_we_o <= FALSE;
			m_sel_o <= 4'hF;
			m_asid_o <= packet_rx.asid;
			m_adr_o <= packet_rx.adr;
			m_mmus_o <= packet_rx.mmus;
			m_ios_o <= packet_rx.ios;
			m_iops_o <= packet_rx.iops;
			state <= ST_READ_ACK;
		end
	ST_READ_ACK:
		if (m_ack_i) begin
			tClearBus();
			tSetupResponse(packet_rx.sid,packet_rx.typ==PT_AREAD ? PT_AACK : PT_ACK);
			state <= ST_IDLE;
		end
		else if (m_err_i) begin
			tClearBus();
			tSetupResponse(packet_rx.sid,PT_ERR);
			state <= ST_IDLE;
		end
		else if (m_vpa_i) begin
			tClearBus();
			tSetupResponse(packet_rx.sid,PT_VPA);
			state <= ST_IDLE;
		end
		else if (timeout) begin
			tClearBus();
			tSetupResponse(packet_rx.sid,PT_ERR);
			state <= ST_IDLE;
		end

	ST_WRITE:
		if (!m_ack_i) begin
			m_core_o <= packet_rx.sid;
			m_cyc_o <= TRUE;
			m_stb_o <= TRUE;
			m_we_o <= TRUE;
			m_sel_o <= packet_rx.sel;
			m_asid_o <= packet_rx.asid;
			m_mmus_o <= packet_rx.mmus;
			m_ios_o <= packet_rx.ios;
			m_iops_o <= packet_rx.iops;
			m_adr_o <= packet_rx.adr;
			m_dat_o <= packet_rx.dat;
			state <= ST_WRITE_ACK;
		end
	ST_WRITE_ACK:
		if (m_ack_i) begin
			tClearBus();
			if (SYNC_WRITE)
				tSetupResponse(packet_rx.sid,PT_ACK);
			state <= ST_IDLE;
		end
		else if (m_err_i) begin
			tClearBus();
			if (SYNC_WRITE)
				tSetupResponse(packet_rx.sid,PT_ERR);
			state <= ST_IDLE;
		end
		else if (m_vpa_i) begin
			tClearBus();
			if (SYNC_WRITE)
				tSetupResponse(packet_rx.sid,PT_VPA);
			state <= ST_IDLE;
		end
		else if (timeout) begin
			tClearBus();
			if (SYNC_WRITE)
				tSetupResponse(packet_rx.sid,PT_ERR);
			state <= ST_IDLE;
		end

	ST_ACK:
		// If there is an active read cycle
		if (s_cyc_i & s_stb_i & ~s_we_i) begin
			if (TRUE || s_adr_i == rpacket_rx.adr) begin
				s_dat_o <= rpacket_rx.dat;
				s_ack1 <= TRUE;
				state <= ST_ACK_ACK;
			end
			else begin
				s_rty_o <= TRUE;
				state <= ST_IDLE;
			end
		end
		else if (s_cyc_i & s_stb_i & s_we_i & SYNC_WRITE) begin
			if (TRUE || s_adr_i == rpacket_rx.adr) begin
				s_dat_o <= rpacket_rx.dat;
				s_ack1 <= TRUE;
				state <= ST_ACK_ACK;
			end
			else begin
				s_rty_o <= TRUE;
				state <= ST_IDLE;
			end
		end
		else
			state <= ST_IDLE;
	ST_ACK_ACK:
		// Wait for the slave cycle to finish.
		if (~(s_cyc_i & s_stb_i))
			state <= ST_IDLE;
	ST_VPA:
		begin
			s_vpa_o <= TRUE;
			s_atag_o <= rpacket_rx.adr[3:0];
			state <= ST_IDLE;
		end
	ST_RETRY:
		begin
			s_rty_o <= TRUE;
			s_atag_o <= rpacket_rx.adr[3:0];
			state <= ST_IDLE;
		end
	ST_ERR:
		begin
			s_err_o <= TRUE;
			s_atag_o <= rpacket_rx.adr[3:0];
			state <= ST_IDLE;
		end
		
	// Asynchronous acknowledge; there does not need to be an active slave cycle.
	// It is assumed the slave is waiting for the response.
	ST_AACK:
		begin
			s_aack_o <= TRUE;
			s_atag_o <= rpacket_rx.adr[3:0];
			s_dat_o <= rpacket_rx.dat;
			state <= ST_IDLE;
		end

	default:
		state <= ST_IDLE;
	endcase

end

task tSetupReadWrite;
begin
	if (s_cyc_i && s_stb_i) begin
		rw_done <= FALSE;
		packet_tx.sid <= id;
		packet_tx.age <= 6'd0;
		packet_tx.ack <= 1'b0;
		packet_tx.typ <= s_we_i ? PT_WRITE : burst ? PT_AREAD : PT_READ;
		packet_tx.pad2 <= 2'b0;
		packet_tx.we <= s_we_i;
		packet_tx.sel <= s_sel_i;
		packet_tx.asid <= s_asid_i;
		packet_tx.mmus <= s_mmus_i;
		packet_tx.ios <= s_ios_i;
		packet_tx.iops <= s_iops_i;
		packet_tx.adr <= s_adr_i;
		packet_tx.dat <= s_dat_i;
		casez(s_adr_i[31:24])
		// Read global ROM? / INTA
		8'hFF:	
			if (!s_we_i) begin
				packet_tx.did <= 6'd62;
				s_ack1 <= burst;
				rw_done <= burst;
			end
			else begin
				packet_tx <= {$bits(packet_t){1'b0}};
				s_ack1 <= (s_we_i & ~SYNC_WRITE);
			end
		/* I/O area */
		8'hFD,
		8'h01:	// virtual address
			begin
				packet_tx.did <= 6'd62;
				s_ack1 <= (s_we_i & ~SYNC_WRITE)|burst;
			end
		// Global broadcast
		8'hDF:
			begin
				packet_tx.did <= 6'd63;
				packet_tx.age <= 6'd30;
				s_ack1 <= (s_we_i & ~SYNC_WRITE)|burst;
			end
		// C0xyyyyy
		8'hC0:
			begin
				packet_tx.did <= {2'd0,s_adr_i[23:20]};
				s_ack1 <= (s_we_i & ~SYNC_WRITE)|burst;
			end
		8'h4?,8'h5?,8'h6?,8'h7?,8'h8?,8'h9?,8'hA?,8'hB?:
			begin
				packet_tx.did <= 6'd62;
				s_ack1 <= (s_we_i & ~SYNC_WRITE)|burst;
			end
		/* Global DRAM area */
		8'h2?,8'h3?:
			begin
				packet_tx.did <= 6'd62;
				s_ack1 <= (s_we_i & ~SYNC_WRITE)|burst;
			end
		8'h00:
			if (s_adr_i[23:20]>=4'h1) begin
				packet_tx.did <= 6'd62;
				s_ack1 <= (s_we_i & ~SYNC_WRITE)|burst;
			end
			else begin
				packet_tx <= {$bits(packet_t){1'b0}};
				rw_done <= TRUE;
			end
		default:
			begin
				packet_tx <= {$bits(packet_t){1'b0}};
				rw_done <= TRUE;
			end
		endcase
	end
end
endtask

task tSetupResponse;
input [5:0] did;
input [5:0] typ;
begin
	rpacket_tx <= {$bits(packet_t){1'b0}};
	rpacket_tx.sid <= id;
	rpacket_tx.did <= did;
	rpacket_tx.age <= 6'd0;
	rpacket_tx.typ <= typ;
	rpacket_tx.ack <= TRUE;
	rpacket_tx.asid <= m_asid_o;
	rpacket_tx.mmus <= m_mmus_o;
	rpacket_tx.ios <= m_ios_o;
	rpacket_tx.iops <= m_iops_o;
	rpacket_tx.adr <= m_adr_o;
	rpacket_tx.dat <= m_dat_i;
end
endtask

task tClearBus;
begin
	m_cyc_o <= LOW;
	m_stb_o <= LOW;
	m_we_o <= LOW;
	m_sel_o <= 4'h0;
	m_mmus_o <= LOW;
	m_ios_o <= LOW;
	m_iops_o <= LOW;
end
endtask

endmodule
