`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2011-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// random.sv
//     Multi-stream random number generator.
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
// 	Reg no.
//	00			read: random output bits [31:0], write: gen next number	
//  04           random stream number
//  08           m_z seed setting bits [31:0]
//  0C           m_w seed setting bits [31:0]
//
//  +- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|WISHBONE Datasheet
//	|WISHBONE SoC Architecture Specification, Revision B.3
//	|
//	|Description:						Specifications:
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|General Description:				random number generator
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Supported Cycles:					SLAVE,READ/WRITE
//	|									SLAVE,BLOCK READ/WRITE
//	|									SLAVE,RMW
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Data port, size:					16 bit
//	|Data port, granularity:			16 bit
//	|Data port, maximum operand size:	16 bit
//	|Data transfer ordering:			Undefined
//	|Data transfer sequencing:			Undefined
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Clock frequency constraints:		none
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Supported signal list and			Signal Name		WISHBONE equiv.
//	|cross reference to equivalent		ack_o			ACK_O
//	|WISHBONE signals					adr_i[43:0]		ADR_I()
//	|									clk_i			CLK_I
//	|                                   rst_i           RST_I()
//	|									dat_i(15:0)		DAT_I()
//	|									dat_o(15:0)		DAT_O()
//	|									cyc_i			CYC_I
//	|									stb_i			STB_I
//	|									we_i			WE_I
//	|
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//	|Special requirements:
//	+- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//
// ============================================================================
//
// Uses George Marsaglia's multiply method
//
// m_w = <choose-initializer>;    /* must not be zero */
// m_z = <choose-initializer>;    /* must not be zero */
//
// uint get_random()
// {
//     m_z = 36969 * (m_z & 65535) + (m_z >> 16);
//     m_w = 18000 * (m_w & 65535) + (m_w >> 16);
//     return (m_z << 16) + m_w;  /* 32-bit result */
// }
//
import wishbone_pkg::*;

`define TRUE	1'b1
`define FALSE	1'b0

module random(rst_i, clk_i, cs_i, cyc_i, stb_i, ack_o, we_i, adr_i, dat_i, dat_o,
    irq_chain_i, irq_chain_o);
input rst_i;
input clk_i;
input cs_i;				// ddbb circuit select
input cyc_i;
input stb_i;
output reg ack_o;
input we_i;
input [31:0] adr_i;
input [31:0] dat_i;
output reg [31:0] dat_o;
input [15:0] irq_chain_i;
output [15:0] irq_chain_o;
parameter IO_ADDR = 32'hFDFF4000;
parameter IO_ADDR_MASK = 32'hFFFFC000;
parameter pAckStyle = 1'b0;
parameter pReverseByteOrder = 1'b0;
parameter pDevName = "RANDOM\0\0\0\0\0\0\0\0\0\0";

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd8;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h00;					// 00 = non VGA compatiable unclassfied device
parameter CFG_CLASS = 8'h00;						// 00 = unclassified
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'hFF;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

wire cs1;
reg ack;
reg cs;
reg we;
reg [13:0] adr;
reg [31:0] dat,dato;
//always @*
//	ack_o <= cs ? ack : pAckStyle;

reg [9:0] stream;
reg [31:0] next_m_z;
reg [31:0] next_m_w;
reg [31:0] out;
reg wrw, wrz;
reg [31:0] w=32'd3,z=32'd17;
wire [31:0] m_zs;
wire [31:0] m_ws;
wire pe_we;

wb_cmd_request32_t wbs_req;
wb_cmd_response32_t ddbb_resp;

always_comb
begin
	wbs_req = {$bits(wb_cmd_request32_t){1'b0}};
	wbs_req.cyc = cyc_i;
	wbs_req.stb = stb_i;
	wbs_req.we = we_i;
	wbs_req.sel = 4'hF;
	wbs_req.adr = adr_i;
	if (pReverseByteOrder) begin
		wbs_req.dat = {dat_i[7:0],dat_i[15:8],dat_i[23:16],dat_i[31:24]};
		dat_o = {dato[7:0],dato[15:8],dato[23:16],dato[31:24]};
	end
	else begin
		wbs_req.dat = dat_i;
		dat_o = dato;
	end
end

always_ff @(posedge clk_i)
	cs <= cs1;
always_ff @(posedge clk_i)
	we <= we_i;
always_ff @(posedge clk_i)
	adr <= adr_i[13:0];
always_ff @(posedge clk_i)
	dat <= wbs_req.dat;

ack_gen #(
	.READ_STAGES(2),
	.WRITE_STAGES(1),
	.REGISTER_OUTPUT(1)
) uag1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.ce_i(1'b1),
	.rid_i('d0),
	.wid_i('d0),
	.i(cs & ~we),
	.we_i(cs & we),
	.o(ack),
	.rid_o(),
	.wid_o()
);

always_comb
	ack_o = cs_i ? ddbb_resp.ack : cs ? ack : pAckStyle;

ddbb32_config #(
	.pDevName(pDevName),
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_LINE(CFG_IRQ_LINE)
)
ucfg1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.irq_i(4'b0),
	.irq_chain_i(irq_chain_i),
	.irq_chain_o(irq_chain_o),
	.cs_i(cs_i), 
	.req_i(wbs_req),
	.resp_o(ddbb_resp),
	.cs_bar0_o(cs1),
	.cs_bar1_o(),
	.cs_bar2_o()
);


edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(we), .pe(pe_we), .ne(), .ee());
rand_ram u1 (clk_i, wrw, stream, w, m_ws);
rand_ram u2 (clk_i, wrz, stream, z, m_zs);

always_comb
begin
	next_m_z = (32'h36969 * m_zs[15:0]) + m_zs[31:16];
	next_m_w = (32'h18000 * m_ws[15:0]) + m_ws[31:16];
end

wire [31:0] num = {m_zs[15:0],16'd0} + m_ws;
wire [31:0] strm = {22'h0,stream};

// Register read path
//
always_ff @(posedge clk_i)
if (cs_i)
	dato <= ddbb_resp.dat;
else if (cs)
	casez(adr)
	14'b000000000000??:	dato <= num;
	14'b000000000001??:	dato <= strm;
// Uncomment these for register read-back
//		3'd4:	dat_o <= m_z[31:16];
//		3'd5:	dat_o <= m_z[15: 0];
//		3'd6:	dat_o <= m_w[31:16];
//		3'd7:	dat_o <= m_w[15: 0];
	14'b11111?????????:	dato <= 32'd0;	// dcb RAM
	default:	dato <= 32'h0000;
	endcase
else
	dato <= 32'h0;
	
// Register write path
//
always_ff @(posedge clk_i)
begin
	wrw <= `FALSE;
	wrz <= `FALSE;
	if (cs) begin
		if (pe_we)
			casez(adr)
			14'b000000000000??:
				begin
					z <= next_m_z;
					w <= next_m_w;
					wrw <= `TRUE;
					wrz <= `TRUE;
				end
			14'b000000000001??:	stream <= dat[9:0];
			14'b000000000010??:	begin z <= dat; wrz <= `TRUE; end
			14'b000000000011??:	begin w <= dat; wrw <= `TRUE; end
			default:	;
			endcase
	end
end

endmodule


// Tools were inferring a massive distributed ram so we help them out a bit by
// creating an explicit ram definition.

module rand_ram(clk, wr, ad, i, o);
input clk;
input wr;
input [9:0] ad;
input [31:0] i;
output [31:0] o;

reg [31:0] ri;
reg [9:0] regadr;
reg regwr;
(* RAM_STYLE="BLOCK" *)
reg [31:0] mem [0:1023];

always_ff @(posedge clk)
	regadr <= ad;
always_ff @(posedge clk)
	regwr <= wr;
always_ff @(posedge clk)
	ri <= i;
always_ff @(posedge clk)
	if (regwr)
		mem[regadr] <= ri;
assign o = mem[regadr];

endmodule
