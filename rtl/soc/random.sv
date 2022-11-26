// ============================================================================
//        __
//   \\__/ o\    (C) 2011-2022  Robert Finch, Waterloo
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
`define TRUE	1'b1
`define FALSE	1'b0

module random(rst_i, clk_i, cs_i, cyc_i, stb_i, ack_o, we_i, adr_i, dat_i, dat_o);
input rst_i;
input clk_i;
input cs_i;
input cyc_i;
input stb_i;
output reg ack_o;
input we_i;
input [3:0] adr_i;
input [31:0] dat_i;
output reg [31:0] dat_o;
parameter pAckStyle = 1'b0;

reg ack;
reg cs;
reg we;
reg [3:0] adr;
reg [31:0] dat;
always_ff @(posedge clk_i)
	cs <= cs_i && cyc_i && stb_i;
always_ff @(posedge clk_i)
	we <= we_i;
always_ff @(posedge clk_i)
	adr <= adr_i;
always_ff @(posedge clk_i)
	dat <= dat_i;

always_ff @(posedge clk_i)
	ack_o <= cs & cs_i & cyc_i & stb_i;
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

edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(we), .pe(pe_we), .ne(), .ee());
rand_ram u1 (clk_i, wrw, stream, w, m_ws);
rand_ram u2 (clk_i, wrz, stream, z, m_zs);

always_comb
begin
	next_m_z = (32'h36969 * m_zs[15:0]) + m_zs[31:16];
	next_m_w = (32'h18000 * m_ws[15:0]) + m_ws[31:16];
end

// Register read path
//
always_ff @(posedge clk_i)
if (cs_i)
	case(adr[3:2])
	2'd0:	dat_o <= {m_zs[15:0],16'd0} + m_ws;
	2'd1:	dat_o <= {22'h0,stream};
// Uncomment these for register read-back
//		3'd4:	dat_o <= m_z[31:16];
//		3'd5:	dat_o <= m_z[15: 0];
//		3'd6:	dat_o <= m_w[31:16];
//		3'd7:	dat_o <= m_w[15: 0];
	default:	dat_o <= 32'h0000;
	endcase
else
	dat_o <= 32'h0;

// Register write path
//
always_ff @(posedge clk_i)
begin
	wrw <= `FALSE;
	wrz <= `FALSE;
	if (cs) begin
		if (pe_we)
			case(adr[3:2])
			2'd0:
				begin
					z <= next_m_z;
					w <= next_m_w;
					wrw <= `TRUE;
					wrz <= `TRUE;
				end
			2'd1:	stream <= dat[9:0];
			2'd2:	begin z <= dat; wrz <= `TRUE; end
			2'd3:	begin w <= dat; wrw <= `TRUE; end
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
