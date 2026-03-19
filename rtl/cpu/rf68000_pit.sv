`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	- programmable interval timer
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
//
//	Reg	Description
//	000	current count (read only)
//	004	max count	    (read-write)
//  008 on time				(read-write)
//	00C	control
//		bit in byte
//		0 = 1 = load, automatically clears
//	  1 = 1 = enable counting, 0 = disable counting
//		2 = 1 = auto-reload on terminal count, 0 = no reload
//		3 = 1 = use external clock, 0 = internal clk_i
//    4 = 1 = use gate to enable count, 0 = ignore gate
//		7 = 1 = set registers immediately, 0 = wait for sync
//	010 callback address
//	014	callback pid
//
//	020	current count 1
//	024  max count 1
//	028  on time 1
//
//	040	current count 2
//	044	max count 2
//	048	on time 2
//
//	060	current count 3
//	064	max count 3
//	068	on time 3
//	...
//	2E0 current count 31
//	2E4 max count 31
//	2E8 on time 31
//	2EC control 31
//
//	800	underflow status
//  804 synchronization register
//  808 interrupt enable
//	80C temporary register
//	810 output status
//	814 internal gate
//	818 internal gate on
//	81C internal gate off
//
//	- all counter controls can be written at the same time with a
//    single instruction allowing synchronization of the counters.
//
// Timer block supports up to 32 32-bit timers
//
// 1100 LUTs / 1850 FFs (8 timers)
// 3700 LUTs / 6050 FFs (32 timers)
// ============================================================================
//
import wishbone_pkg::*;

module rf68000_pit(rst_i, clk_i, cs_i, irq_chain_i, irq_chain_o,
	wbs_req_i, wbs_resp_o,
	clk0, gate0, out0, clk1, gate1, out1, clk2, gate2, out2, clk3, gate3, out3,
	irq_o
	);
parameter NTIMER=8;
parameter BITS=32;
input rst_i;
input clk_i;
input cs_i;
input [15:0] irq_chain_i;
output [15:0] irq_chain_o;
input wb_cmd_request32_t wbs_req_i;
output wb_cmd_response32_t wbs_resp_o;
input clk0;
input gate0;
output out0;
input clk1;
input gate1;
output out1;
input clk2;
input gate2;
output out2;
input clk3;
input gate3;
output out3;
output [31:0] irq_o;

parameter pReverseByteOrder = 1'b0;
parameter pDevName = "TIMER           ";

parameter IO_ADDR = 32'hFDFEC000;
parameter IO_ADDR_MASK = 32'hFFFFC000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd4;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h80;					// 80 = Other
parameter CFG_CLASS = 8'h03;						// 03 = display controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'd29;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter MSIX = 1'b0;

integer n,n1;
wire cs_pit;
wire [63:0] cfg_out;
wire irq_en;
reg [63:0] maxcounth [0:NTIMER-1];
reg [63:0] maxcount [0:NTIMER-1];
reg [63:0] count [0:NTIMER-1];
reg [63:0] onth [0:NTIMER-1];
reg [63:0] ont [0:NTIMER-1];
reg [BITS-1:0] callback [0:NTIMER-1];
reg [15:0] pid [0:NTIMER-1];
wire [NTIMER-1:0] gate;
reg [NTIMER-1:0] igate;
wire [NTIMER-1:0] pulse;
reg [NTIMER-1:0] ldh;
reg [NTIMER-1:0] ceh;
reg [NTIMER-1:0] arh;
reg [NTIMER-1:0] geh;
reg [NTIMER-1:0] xch;
reg [NTIMER-1:0] ieh;
reg [NTIMER-1:0] ld;
reg [NTIMER-1:0] ce;
reg [NTIMER-1:0] ar;
reg [NTIMER-1:0] ge;
reg [NTIMER-1:0] xc;
reg [NTIMER-1:0] ie;
reg [NTIMER-1:0] out;
reg [NTIMER-1:0] underflow;
reg [NTIMER-1:0] tmp;
reg [NTIMER-1:0] irqf;

wb_cmd_request32_t wbs_req;
wb_cmd_response32_t ddbb_resp;
reg we_i;
reg [3:0] sel_i;
reg [31:0] adr_i;
reg [31:0] dat_o;
reg [31:0] dat_i;

wire cs;
reg rdy;
reg ack_o;
always @(posedge clk_i)
	rdy <= cs;
always_comb
	ack_o = cs ? (wbs_req.we ? 1'b1 : rdy) : 1'b0;

always_comb
begin
	we_i = wbs_req_i.we;
	sel_i = wbs_req_i.sel;
	adr_i = wbs_req_i.adr;
	// Input side
	wbs_req = wbs_req_i;
	if (pReverseByteOrder) begin
		wbs_req.dat = {wbs_req_i.dat[7:0],wbs_req_i.dat[15:8],wbs_req_i.dat[23:16],wbs_req_i.dat[31:24]};
		dat_i = {wbs_req_i.dat[7:0],wbs_req_i.dat[15:8],wbs_req_i.dat[23:16],wbs_req_i.dat[31:24]};
	end
	else begin
		wbs_req.dat = wbs_req_i.dat;
		dat_i = wbs_req_i.dat;
	end
	// Output side
	if (cs_i) begin
		wbs_resp_o = ddbb_resp;
		if (pReverseByteOrder)
			wbs_resp_o.dat = {ddbb_resp.dat[7:0],ddbb_resp.dat[15:8],ddbb_resp.dat[23:16],ddbb_resp.dat[31:24]};
		else
			wbs_resp_o.dat = ddbb_resp.dat;
	end
	else if (cs) begin
		wbs_resp_o = 1000'd0;
		wbs_resp_o.ack = ack_o;
		if (pReverseByteOrder)
			wbs_resp_o.dat = {dat_o[7:0],dat_o[15:8],dat_o[23:16],dat_o[31:24]};
		else
			wbs_resp_o.dat = dat_o;
	end
	else
		wbs_resp_o = 1000'd0;
end

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
uddbb1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.irq_i(),
	.cs_i(cs_i),
	.resp_busy_i(),
	.req_i(wbs_req),
	.resp_o(ddbb_resp),
	.cs_bar0_o(cs),
	.cs_bar1_o(),
	.cs_bar2_o(),
	.irq_chain_i(irq_chain_i),
	.irq_chain_o(irq_chain_o)
);

assign out0 = out[0];
assign out1 = out[1];
assign out2 = out[2];
assign out3 = out[3];
assign gate[0] = gate0;
assign gate[1] = gate1;
assign gate[2] = gate2;
assign gate[3] = gate3;

edge_det ued0 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk0), .pe(pulse[0]), .ne(), .ee());
edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk1), .pe(pulse[1]), .ne(), .ee());
edge_det ued2 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk2), .pe(pulse[2]), .ne(), .ee());
edge_det ued3 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk3), .pe(pulse[3]), .ne(), .ee());


genvar g;
generate
	for (g = 4; g < NTIMER; g = g + 1) begin
assign gate[g] = 1'b1;
assign pulse[g] = 1'b0;
	end
endgenerate

initial begin
	for (n = 0; n < NTIMER; n = n + 1) begin
		maxcount[n] <= 64'd0;
		maxcounth[n] <= 64'd0;
		count[n] <= 64'd0;
		ont[n] <= 64'd0;
		onth[n] <= 64'd0;
		igate[n] <= 1'b0;
		ld[n] <= 1'b0;
		ce[n] <= 1'b0;
		ar[n] <= 1'b0;
		ge[n] <= 1'b0;
		xc[n] <= 1'b0;
		ldh[n] <= 1'b0;
		ceh[n] <= 1'b0;
		arh[n] <= 1'b0;
		geh[n] <= 1'b0;
		xch[n] <= 1'b0;
		out[n] <= 1'b0;
		irqf[n] <= 1'b0;
	end
end

always_ff @(posedge clk_i)
if (rst_i) begin
	ie <= 32'd0;
	for (n1 = 0; n1 < NTIMER; n1 = n1 + 1) begin
		callback[n1] <= 32'd0;
		pid[n1] <= 16'h0;
		maxcount[n1] <= 64'd0;
		maxcounth[n1] <= 64'd0;
		count[n1] <= 64'd0;
		ont[n1] <= 64'd0;
		onth[n1] <= 64'd0;
		igate[n1] <= 1'b0;
		ld[n1] <= 1'b0;
		ce[n1] <= 1'b0;
		ar[n1] <= 1'b1;
		ge[n1] <= 1'b0;
		ldh[n1] <= 1'b0;
		ceh[n1] <= 1'b0;
		arh[n1] <= 1'b1;
		geh[n1] <= 1'b0;
		out[n1] <= 1'b0;
		irqf[n1] <= 1'b0;
	end	
end
else begin
	ld <= 32'd0;
	if (cs && we_i)
		casez(adr_i[11:2])
		10'b00?????010:
			maxcounth[adr_i[9:5]][31:0] <= dat_i[31:0];
		10'b00?????011:
			maxcounth[adr_i[9:5]][63:32] <= dat_i[31:0];
		10'b00?????100:
			onth[adr_i[9:5]][31:0] <= dat_i[31:0];
		10'b00?????101:
			onth[adr_i[9:5]][63:32] <= dat_i[31:0];
		10'b00?????110:
			begin
				ldh[adr_i[9:5]] <= dat_i[0];
				ceh[adr_i[9:5]] <= dat_i[1];
				arh[adr_i[9:5]] <= dat_i[2];
				xch[adr_i[9:5]] <= dat_i[3];
				geh[adr_i[9:5]] <= dat_i[4];
				if (dat_i[7]) begin
					ld[adr_i[9:5]] <= dat_i[0];
					ce[adr_i[9:5]] <= dat_i[1];
					ar[adr_i[9:5]] <= dat_i[2];
					xc[adr_i[9:5]] <= dat_i[3];
					ge[adr_i[9:5]] <= dat_i[4];
					maxcount[adr_i[9:5]] <= maxcounth[adr_i[9:5]];
					ont[adr_i[9:5]] <= onth[adr_i[9:5]];
				end
			end
			
	// Writing the underflow register clears the underflows and disable further
	// interrupts where bits are set in the incoming data.
	// Interrupt processing should read the underflow register to determine
	// which timers underflowed, then write back the value to the underflow
	// register.
		10'h200:
			begin
				ie <= ie & (~(underflow & dat_i) | ar);
				underflow <= underflow & ~dat_i;
				irqf <= irqf & ~dat_i;
			end
		// The timer synchronization register indicates which timer's registers to
		// update. All timers may have their registers updated synchronously.
		10'h201:
			for (n1 = 0; n1 < NTIMER; n1 = n1 + 1) begin
				if (dat_i[n1]) begin
					ld[n1] <= ldh[n1];
					ce[n1] <= ceh[n1];
					ar[n1] <= arh[n1];
					xc[n1] <= xch[n1];
					ge[n1] <= geh[n1];
					ldh[n1] <= 1'b0;
					maxcount[n1] <= maxcounth[n1];
					ont[n1] <= onth[n1];
				end
			end
		10'h202:	ie <= dat_i;
		10'h203:	tmp <= dat_i;
		10'h205:	igate <= dat_i;
		10'h206:	igate <= igate | dat_i;
		10'h207:	igate <= igate & ~dat_i;
		default:	;
		endcase
	if (cs) begin
		casez(adr_i[11:2])
		10'b00?????000:	dat_o <= count[adr_i[9:5]][31: 0];
		10'b00?????001:	dat_o <= count[adr_i[9:5]][63:32];
		10'b00?????010:	dat_o <= maxcounth[adr_i[9:5]][31: 0];
		10'b00?????011:	dat_o <= maxcounth[adr_i[9:5]][63:32];
		10'b00?????100:	dat_o <= onth[adr_i[9:5]][31:0];
		10'b00?????101:	dat_o <= onth[adr_i[9:5]][63:32];
		10'b00?????110:	dat_o <= {24'd0,3'b0,ge[adr_i[9:5]],xc[adr_i[9:5]],ar[adr_i[9:5]],ce[adr_i[9:5]],1'b0};
		10'h200:	dat_o <= underflow;
		10'h201:	dat_o <= 32'd0;
		10'h202:	dat_o <= ie;
		10'h203:	dat_o <= tmp;
		10'h204:	dat_o <= out;
		10'h205:	dat_o <= igate;
		10'h206:	dat_o <= 32'd0;
		10'h207:	dat_o <= 32'd0;
		default:	dat_o <= 32'd0;
		endcase
	end
	else
		dat_o <= 32'd0;
		
	for (n1 = 0; n1 < NTIMER; n1 = n1 + 1) begin
		if (ld[n1]) begin
			count[n1] <= maxcount[n1];
		end
		else if ((xc[n1] ? pulse[n1] & ce[n1] : ce[n1]) & (ge[n1] ? igate[n1] & gate[n1] : 1'b1)) begin
			count[n1] <= count[n1] - 2'd1;
			if (count[n1]==ont[n1]) begin
				out[n1] <= 1'b1;
			end
			else if (count[n1]==32'd0) begin
				underflow[n1] <= 1'b1;
				if (ie[n1])
					irqf[n1] <= 1'b1;
				out[n1] <= 1'b0;
				if (ar[n1]) begin
					count[n1] <= maxcount[n1];
				end
				else begin
					ce[n1] <= 1'b0;
				end
			end
		end
	end
end

assign irq_o = |irqf;//irq_en);

endmodule
