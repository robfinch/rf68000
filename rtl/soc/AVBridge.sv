`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@opencores.org
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
// AVBridge.sv
//
// Adds FF's into the io path. This makes it easier for the place and
// route to take place. This module also filters requests to the I/O
// memory range, and hopefully reduces the cost of comparators in I/O
// modules that have internal decoding.
// Multiple devices are connected to the master port side of the bridge.
// The slave side of the bridge is connected to the cpu. The bridge looks
// like just a single device then to the cpu.
// The cost is an extra clock cycle to perform I/O accesses. For most
// devices which are low-speed it doesn't matter much.              
// ============================================================================
//
import const_pkg::*;

module AVBridge(rst_i, clk_i, vclk_i, fta_en_i, io_gate_en_i, hsync_i, vsync_i,
	gfx_que_empty_i,
	s1_cyc_i, s1_stb_i, s1_ack_o, s1_we_i, s1_sel_i, s1_adr_i, s1_dat_i, s1_dat_o,
	cs0_o, cs1_o, cs2_o, cs3_o, cs4_o, cs5_o, cs6_o, cs7_o,
	m_cyc_o, m_stb_o, m_ack_i, m_stall_i, m_we_o, m_sel_o, m_adr_o, m_dat_i, m_dat_o,
	m_fta_o);
parameter WID=32;
parameter IDLE = 3'd0;
parameter WAIT_ACK = 3'd1;
parameter WAIT_NACK = 3'd2;
parameter WR_ACK = 3'd3;
parameter WR_ACK2 = 3'd4;
parameter CS0_MASK = 32'hFFE00000;	// text controller
parameter CS1_MASK = 32'hFFFF0000;	// frame buffer
parameter CS2_MASK = 32'hFFFFFC00;	// graphics accelerator
parameter CS3_MASK = 32'hFFFF0000;
parameter CS4_MASK = 32'hFFFFFC00;	// sound generator
parameter CS5_MASK = 32'hFFFFFFF0;	// audio codec
parameter CS6_MASK = 32'hFFFFFFF0;	// I2C for codec
parameter CS7_MASK = 32'hFFFF0000;
parameter BRIDGENUM = 1;

input rst_i;
input clk_i;
input vclk_i;
input fta_en_i;
input io_gate_en_i;
input hsync_i;
input vsync_i;
input gfx_que_empty_i;

input s1_cyc_i;
input s1_stb_i;
output reg s1_ack_o;
input s1_we_i;
input [3:0] s1_sel_i;
input [31:0] s1_adr_i;
input [31:0] s1_dat_i;
output reg [31:0] s1_dat_o;

output reg cs0_o;
output reg cs1_o;
output reg cs2_o;
output reg cs3_o;
output reg cs4_o;
output reg cs5_o;
output reg cs6_o;
output reg cs7_o;

output reg m_cyc_o;
output reg m_stb_o;
input m_ack_i;
input m_stall_i;
output reg m_we_o;
output reg [3:0] m_sel_o;
output reg [31:0] m_adr_o;
input [31:0] m_dat_i;
output reg [31:0] m_dat_o;

fta_bus_interface.master m_fta_o;
//assign m_fta_o.clk = clk_i;
//assign m_fta_o.rst = rst_i;
reg [31:0] cs [0:7];


wire cop_cyc;
wire cop_stb;
reg cop_ack;
wire cop_we;
wire cop_sel;
wire [31:0] cop_adr;
reg [31:0] cop_dati;
wire [31:0] cop_dato;
wire cop_sack;
wire [31:0] cop_sdato;

reg [1:0] which;
reg [2:0] state;
reg s_ack;
reg s1_cycd;
always_ff @(posedge clk_i)
	s1_cycd <= s1_stb_i && s1_adr_i[31:16]==12'hFD20;
always_comb// @(posedge clk_i)
if (rst_i)
	s1_ack_o <= 1'b0;
else
	s1_ack_o <= s_ack && s1_stb_i && (which==2'b00 || which==2'b10);
always_comb// @(posedge clk_i)
if (rst_i)
	cop_ack <= 1'b0;
else
	cop_ack <= s_ack && cop_stb && which==2'b01;

reg cop_cs;
always_comb
	cop_cs = s1_cyc_i && s1_adr_i[31:14]==18'b1111_1101_0010_1000_10;

reg s1_cyc;
always_comb
	s1_cyc = s1_cyc_i && ((s1_adr_i[31:24]==8'hFD && s1_adr_i[23:16]!=8'h20) || (s1_adr_i[31:28]==4'hD));

reg cop_cs0;
reg cop_cs1;
reg cop_cs2;
reg cop_cs3;
reg cop_cs4;
reg cop_cs5;
reg cop_cs6;
reg cop_cs7;
always_comb cop_cs0 = ((cs[0] ^ cop_adr) & CS0_MASK) == 32'd0;
always_comb cop_cs1 = ((cs[1] ^ cop_adr) & CS1_MASK) == 32'd0;
always_comb cop_cs2 = ((cs[2] ^ cop_adr) & CS2_MASK) == 32'd0;
always_comb cop_cs3 = ((cs[3] ^ cop_adr) & CS3_MASK) == 32'd0;
always_comb cop_cs4 = ((cs[4] ^ cop_adr) & CS4_MASK) == 32'd0;
always_comb cop_cs5 = ((cs[5] ^ cop_adr) & CS5_MASK) == 32'd0;
always_comb cop_cs6 = ((cs[6] ^ cop_adr) & CS6_MASK) == 32'd0;
always_comb cop_cs7 = ((cs[7] ^ cop_adr) & CS7_MASK) == 32'd0;
reg s1_cs0;
reg s1_cs1;
reg s1_cs2;
reg s1_cs3;
reg s1_cs4;
reg s1_cs5;
reg s1_cs6;
reg s1_cs7;
always_comb s1_cs0 = ((cs[0] ^ s1_adr_i) & CS0_MASK) == 32'd0;
always_comb s1_cs1 = ((cs[1] ^ s1_adr_i) & CS1_MASK) == 32'd0;
always_comb s1_cs2 = ((cs[2] ^ s1_adr_i) & CS2_MASK) == 32'd0;
always_comb s1_cs3 = ((cs[3] ^ s1_adr_i) & CS3_MASK) == 32'd0;
always_comb s1_cs4 = ((cs[4] ^ s1_adr_i) & CS4_MASK) == 32'd0;
always_comb s1_cs5 = ((cs[5] ^ s1_adr_i) & CS5_MASK) == 32'd0;
always_comb s1_cs6 = ((cs[6] ^ s1_adr_i) & CS6_MASK) == 32'd0;
always_comb s1_cs7 = ((cs[7] ^ s1_adr_i) & CS7_MASK) == 32'd0;

always_ff @(posedge clk_i)
if (rst_i) begin
	cs[0] = 32'hFD000000;		// Text controller
	cs[1] = 32'hFD200000;		// Frame buffer
	cs[2] = 32'hFD210000;		// graphics accelerator
	cs[3] = 32'hFD400000;		//
	cs[4] = 32'hFD240000;		// sound generator
	cs[5] = 32'hFD254000;		// ADAU1761 audio codec
	cs[6] = 32'hFD250000;		// I2C for codec
	cs[7] = 32'hFD700000;
end
else begin
	if (s1_cyc_i && s1_stb_i && s1_we_i && s1_adr_i[31:8]==24'hFDFFF1) begin
		if (s1_adr_i[7])
			cs[s1_adr_i[4:2]] <= {s1_dat_i[7:0],s1_dat_i[15:8],s1_dat_i[23:16],s1_dat_i[31:24]};
		else
			cs[s1_adr_i[4:2]] <= s1_dat_i;
	end
end

always_ff @(posedge clk_i)
if (rst_i) begin
	tClearBus();
	s_ack <= 1'b0;
	s1_dat_o <= 32'd0;
	cop_dati <= 32'd0;
	cop_ack <= 1'b0;
	m_fta_o.req <= 500'd0;
	which <= 2'b00;
	state <= IDLE;
end
else begin
	m_fta_o.req.bte <= fta_bus_pkg::LINEAR;
	m_fta_o.req.cti <= fta_bus_pkg::CLASSIC;
	m_fta_o.req.cyc <= LOW;
	m_fta_o.req.we <= LOW;
	m_fta_o.req.sel <= {WID/8{1'b0}};
	m_fta_o.req.adr <= 32'd0;
case(state)
IDLE:
  if (~m_ack_i & io_gate_en_i & ~m_stall_i) begin
    if (cop_cyc && cop_adr[31:24]==8'hFD && cop_adr[23:16]!=8'h20) begin
    	which <= 2'b01;
    	cs0_o <= cop_cs0;
    	cs1_o <= cop_cs1;
    	cs2_o <= cop_cs2;
    	cs3_o <= cop_cs3;
    	cs4_o <= cop_cs4;
    	cs5_o <= cop_cs5;
    	cs6_o <= cop_cs6;
    	cs7_o <= cop_cs7;
      m_cyc_o <= 1'b1;
      m_stb_o <= 1'b1;
	    m_we_o <= cop_we;
      m_sel_o <= cop_sel;
	    m_adr_o <= cop_adr;
			m_dat_o <= cop_dato;
`ifdef ACK_WR
      if (cop_we) begin
      	s_ack <= 1'b1;
		    state <= WR_ACK;
    	end
    	else 
`endif    	
    	begin
//	      	s_ack <= 1'b0;
      	state <= WAIT_ACK;
    	end
    end
    // Filter requests to the I/O address range
    else if (s1_cyc & s1_stb_i & ~cop_cs) begin
    	which <= 2'b00;
    	cs0_o <= s1_cs0;
    	cs1_o <= s1_cs1;
    	cs2_o <= s1_cs2;
    	cs3_o <= s1_cs3;
    	cs4_o <= s1_cs4;
    	cs5_o <= s1_cs5;
    	cs6_o <= s1_cs6;
    	cs7_o <= s1_cs7;
      m_cyc_o <= 1'b1;
      m_stb_o <= s1_stb_i;
	    m_we_o <= s1_we_i;
      m_sel_o <= s1_sel_i;
	    m_adr_o <= s1_adr_i;
	    m_dat_o <= s1_dat_i;
`ifdef ACK_WR
      if (s1_we_i) begin
      	s_ack <= 1'b1;
		    state <= WR_ACK;
    	end
    	else
`endif    	
    	begin
//	      	s_ack <= 1'b0;
      	state <= WAIT_ACK;
    	end
    end
    else if (s1_cyc & s1_stb_i & cop_cs)
    	state <= WAIT_ACK;
	end
	/*
	else begin
		tClearBus();
		s_ack <= 1'b1;
		s1_dat_o <= m_dat_i;
		s2_dat_o <= m_dat_i;
		state <= WAIT_NACK;
	end
	*/
WR_ACK:
	begin
		if (!cop_stb && !s1_stb_i) begin
			s_ack <= 1'b0;
			s1_dat_o <= 32'h0;
			cop_dati <= 32'h0;
		end
		if ( which==2'b01 & !cop_stb) begin
			s_ack <= 1'b0;
			cop_dati <= 32'h0;
		end
		if ((which==2'b00||which==2'b10) & !s1_stb_i) begin
			s1_dat_o <= 32'h0;
			s_ack <= 1'b0;
		end
		if (m_ack_i) begin
			m_cyc_o <= 1'b0;
			m_stb_o <= 1'b0;
			m_we_o <= 1'b0;
//			m_sel_o <= 8'h00;
			if (!s_ack)
				state <= IDLE;
			else
				state <= WR_ACK2;
		end
	end
WR_ACK2:
	begin
		if (!cop_stb && !s1_stb_i) begin
			s_ack <= 1'b0;
			state <= IDLE;
		end
		if ( which==2'b01 & !cop_stb) begin
			s_ack <= 1'b0;
			state <= IDLE;
		end
		if ((which==2'b00||which==2'b10) & !s1_stb_i) begin
			s_ack <= 1'b0;
			state <= IDLE;
		end
	end

// Wait for rising edge on m_ack_i or cycle abort
WAIT_ACK:
	begin
		// Repeat signal assertion in case of bus skew.
		/*
    m_cyc_o <= 1'b1;
    m_stb_o <= 1'b1;
    if (s1_cyc) begin
	    m_we_o <= s1_we_i;
	    m_sel_o <= s1_sel_i;
	    m_adr_o <= s1_adr_i;
	    m_dat_o <= s1_dat_i;
  	end
  	*/
  	if (cop_sack) begin
  		s_ack <= 1'b1;
  		s1_dat_o <= cop_sdato;
			state <= WAIT_NACK;
  	end
		if (m_ack_i) begin
			tClearBus();
			s_ack <= 1'b1;
			// Easier for debug, on a write respond with data written.
			/*
			if (m_we_o) begin
				s1_dat_o <= m_dat_o;
				s2_dat_o <= m_dat_o;
				state <= WAIT_NACK;
			end
			else
			*/
			begin
				s1_dat_o <= m_dat_i;
				cop_dati <= m_dat_i;
				state <= WAIT_NACK;
			end
		end
		// Cycle terminated prematurely?
		else if (!cop_cyc && !s1_cyc) begin
			tClearBus();
			s1_dat_o <= 32'h0;
			cop_dati <= 32'h0;
			s_ack <= 1'b0;
			state <= IDLE;
		end
		else if (which==2'b01 ? !cop_cyc : !s1_cyc) begin
			if (which != 2'b10) begin
				tClearBus();
				s_ack <= 1'b0;
		//			m_sel_o <= 8'h00;
		//		m_adr_o <= 32'h0;
		//		m_dat_o <= 32'd0;
				if (!s1_cyc)
					s1_dat_o <= 32'h0;
				if (!cop_cyc)
					cop_dati <= 32'h0;
				state <= IDLE;
			end
		end
	end

// Wait for falling edge on strobe or strobe low.
WAIT_NACK:
	begin
		s1_dat_o <= m_dat_i;
		cop_dati <= m_dat_i;
		if (!cop_cyc && !s1_stb_i) begin
			if (which != 2'b10) begin
				tClearBus();
				s_ack <= 1'b0;
				s1_dat_o <= 32'h0;
				cop_dati <= 32'h0;
			end
			// Read-modify-write cycle?
			if (which!=2'b01 && s1_cyc_i)
				state <= WAIT_ACK;
			else
				state <= IDLE;
		end
		else if (which==2'b01 ? !cop_cyc : !s1_stb_i) begin
			if (which != 2'b10) begin
				tClearBus();
				s_ack <= 1'b0;
				if (!s1_stb_i)
					s1_dat_o <= 32'h0;
				if (!cop_stb)
					cop_dati <= 32'h0;
			end
			// Read-modify-write cycle?
			if (which!=2'b01 && s1_cyc_i)
				state <= WAIT_ACK;
			else
				state <= IDLE;
		end
	end
default:	state <= IDLE;
endcase
	if (s1_stb_i && !s1_cycd && s1_adr_i[31:16]==16'hFD20 && fta_en_i && !m_stall_i) begin
		which <= 2'b10;
		m_fta_o.req.cmd <= s1_we_i ? fta_bus_pkg::CMD_STORE : fta_bus_pkg::CMD_LOAD;
		m_fta_o.req.cyc <= HIGH;
		m_fta_o.req.sel <= s1_sel_i;
		m_fta_o.req.we <= s1_we_i;
		m_fta_o.req.adr <= s1_adr_i;
		m_fta_o.req.data1 <= s1_dat_i;
		if (s1_we_i) begin
			s_ack <= HIGH;
			s1_dat_o <= s1_dat_i;
		end
	end
	if (m_fta_o.resp.ack) begin
		which <= 2'b10;
		s_ack <= !s1_we_i;
		s1_dat_o <= m_fta_o.resp.dat;
	end
	if (which==2'b10) begin
		if (!s1_stb_i) begin
			which <= 2'b11;
			s_ack <= LOW;
			s1_dat_o <= 32'd0;
			state <= IDLE;
		end
	end
end

rfCopper ucop1
(
	.rst_i(rst),
	.clk_i(clk_i),
	.vclk_i(vclk_i),
	.hsync_i(hsync_i),
	.vsync_i(vsync_i),
	.gfx_que_empty_i(gfx_que_empty_i),

	.scyc_i(s1_cyc),
	.sstb_i(s1_stb),
	.sack_o(cop_sack),
	.swe_i(s1_we),
	.ssel_i(s1_sel),
	.sadr_i(s1_adr),
	.sdat_i(s1_dati),
	.sdat_o(cop_sdato),

	.mcyc_o(cop_cyc),
	.mstb_o(cop_stb),
	.mack_i(cop_ack),
	.mwe_o(cop_we),
	.msel_o(cop_sel),
	.madr_o(cop_adr),
	.mdat_o(cop_dato),
	.mdat_i(cop_dati)
);

task tClearBus;
begin
	cs0_o <= LOW;
	cs1_o <= LOW;
	cs2_o <= LOW;
	cs3_o <= LOW;
	cs4_o <= LOW;
	cs5_o <= LOW;
	cs6_o <= LOW;
	cs7_o <= LOW;
	m_cyc_o <= 1'b0;
	m_stb_o <= 1'b0;
	m_we_o <= 1'b0;
	m_sel_o <= 4'h0;
	m_adr_o <= 32'd0;
	m_dat_o <= 32'd0;
end
endtask

endmodule
