`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
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
// ============================================================================
//
import const_pkg::*;

module rfCopper(rst_i, clk_i, vclk_i, hsync_i, vsync_i, gfx_que_empty_i,
	scyc_i, sstb_i, sack_o, swe_i, ssel_i, sadr_i, sdat_i, sdat_o,
	mcyc_o, mstb_o, mack_i, mwe_o, msel_o, madr_o, mdat_o, mdat_i);
input rst_i;
input clk_i;
input vclk_i;
input hsync_i;
input vsync_i;
input gfx_que_empty_i;

input scyc_i;
input sstb_i;
output reg sack_o;
input swe_i;
input [3:0] ssel_i;
input [31:0] sadr_i;
input [31:0] sdat_i;
output reg [31:0] sdat_o;

output reg mcyc_o;
output reg mstb_o;
input mack_i;
output reg mwe_o;
output reg [3:0] msel_o;
output reg [31:0] madr_o;
output reg [31:0] mdat_o;
input [31:0] mdat_i;

typedef enum logic [2:0] {
	COP_IFETCH = 3'd0,
	COP_IFETCH2,
	COP_IFETCH3,
	COP_DECODE,
	COP_WAIT_ACK
} cop_state_e;
cop_state_e cop_state;

wire clka, clkb;
reg [15:0] addra;
reg [13:0] addrb;
wire [31:0] douta;
wire [127:0] doutb;
reg [31:0] dina;
reg [127:0] dinb;
reg ena, enb;
wire rsta, rstb;
reg wea, web;
reg ack1, ack2, ack3;

reg [15:0] pc;
reg [15:0] ar [0:15];
reg copper_en;

assign clka = clk_i;
assign clkb = clk_i;
assign rsta = rst_i;
assign rstb = rst_i;
reg cs_reg;

always_comb
	cs_reg = sadr_i[31:8]==24'hFD1FFF;

wire [15:0] hpos, vpos;
wire [15:0] hpos_mask = doutb[15: 0];
wire [15:0] vpos_mask = doutb[31:16];
wire [15:0] hpos_masked = hpos & hpos_mask;
wire [15:0] vpos_masked = vpos & vpos_mask;
wire [15:0] hpos_wait = doutb[79:64];
wire [15:0] vpos_wait = doutb[95:80];


always_ff @(posedge clk_i)
	addra <= sadr_i[15:2];

always_ff @(posedge clk_i)
	addrb <= pc[15:4];

always_ff @(posedge clk_i)
	dina <= sdat_i;
	
always_comb
	dinb = 128'd0;

always_ff @(posedge clk_i)
	ena <= sadr_i[31:20]==12'hFD1;

always_comb
	enb = 1'b1;

always_ff @(posedge clk_i)
	wea <= swe_i;

always_comb
	web = 1'b0;

always_comb
	sdat_o = ena ? (cs_reg ? ar[sadr_i[3:0]] : douta) : 32'd0;

always_ff @(posedge clk_i)
	ack1 <= ena;
always_ff @(posedge clk_i)
	ack2 <= ack1 & ena;
always_ff @(posedge clk_i)
	ack3 <= ack2 & ena;
always_ff @(posedge clk_i)
	sack_o <= ack3 & ena;

wire pe_hsync;
wire pe_vsync;
wire pe_vsync2;
edge_det edh1
(
	.rst(rst_i),
	.clk(vclk),
	.ce(1'b1),
	.i(hsync_i),
	.pe(pe_hsync),
	.ne(),
	.ee()
);

edge_det edv1
(
	.rst(rst_i),
	.clk(vclk),
	.ce(1'b1),
	.i(vsync_i),
	.pe(pe_vsync),
	.ne(),
	.ee()
);

edge_det edv2
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.i(vsync_i),
	.pe(pe_vsync2),
	.ne(),
	.ee()
);

// Raw scanline counter
vid_counter #(16) u_vctr (.rst(sym_rst), .clk(vclk), .ce(pe_hsync), .ld(pe_vsync), .d(16'd0), .q(vpos), .tc());
vid_counter #(16) u_hctr (.rst(sym_rst), .clk(vclk), .ce(1'b1), .ld(pe_hsync), .d(16'd0), .q(hpos), .tc());


always_ff @(posedge clk_i)
if (rst_i)
	copper_en <= 1'b0;
else begin
	if (pe_vsync) begin
		pc <= 16'd0;
		cop_state <= COP_IFETCH;
	end

	if (cs_reg && sadr_i[7:6]==2'h0)	
		ar[sadr_i[5:2]] <= {sdat_i[15:2],2'd0};
	if (cs_reg && sadr_i[7:6]==2'h1)
		copper_en <= sdat_i[0];

	case(cop_state)
	COP_IFETCH:
		cop_state <= COP_IFETCH2;
	COP_IFETCH2:
		cop_state <= COP_IFETCH3;
	COP_IFETCH3:
		begin
			pc <= pc + 16'd16;
			cop_state <= COP_DECODE;
		end
	COP_DECODE:
		case(doutb[127:124])	
		4'h0:	// WAIT
			if (hpos_masked >= hpos_wait && vpos_masked >= vpos_wait && (doutb[112] ? gfx_que_empty_i : 1'b1))
				cop_state <= COP_IFETCH;
		4'h1:	// MOVE
			begin
				mcyc_o <= 1'b1;
				mstb_o <= 1'b1;
				mwe_o <= 1'b1;
				msel_o <= 4'hF;
				madr_o <= doutb[95:64];
				mdat_o <= doutb[31: 0];
				cop_state <= COP_WAIT_ACK;
			end
		4'h2:	// SKIP
			if (hpos_masked >= hpos_wait && vpos_masked >= vpos_wait && (doutb[112] ? gfx_que_empty_i : 1'b1)) begin
				pc <= pc + 16'd16;
				cop_state <= COP_IFETCH;
			end
		4'd3:	// JUMP
			case(doutb[74:72])
			3'd0:	
				begin
					ar[doutb[83:80]] <= pc;
					pc <= doutb[15:0];
					cop_state <= COP_IFETCH;
				end
			3'd1:
				begin
					if (gfx_que_empty_i) begin
						ar[doutb[83:80]] <= pc;
						pc <= doutb[15:0];
						cop_state <= COP_IFETCH;
					end
				end
			3'd2:
				begin
					if (!gfx_que_empty_i) begin
						ar[doutb[83:80]] <= pc;
						pc <= doutb[15:0];
						cop_state <= COP_IFETCH;
					end
				end
			3'd4:
				begin
					pc <= ar[doutb[67:64]];
					cop_state <= COP_IFETCH;
				end
			3'd5:
				begin
					if (gfx_que_empty_i) begin
						pc <= ar[doutb[67:64]];
						cop_state <= COP_IFETCH;
					end
				end
			3'd6:
				begin
					if (!gfx_que_empty_i) begin
						pc <= ar[doutb[67:64]];
						cop_state <= COP_IFETCH;
					end
				end
			3'd3,3'd7:
				cop_state <= COP_IFETCH;
			endcase
		endcase	
	COP_WAIT_ACK:
		if (mack_i) begin
			mcyc_o <= 1'b0;
			mstb_o <= 1'b0;
			mwe_o <= 1'b0;
			msel_o <= 4'h0;
			cop_state <= COP_IFETCH;
		end
	endcase
end

   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2024.2

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(14),               // DECIMAL
      .ADDR_WIDTH_B(12),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(32),        // DECIMAL
      .BYTE_WRITE_WIDTH_B(128),       // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_BIT_RANGE("7:0"),          // String
      .ECC_MODE("no_ecc"),            // String
      .ECC_TYPE("none"),              // String
      .IGNORE_INIT_SYNTH(0),          // DECIMAL
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(65536*8),          // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .RAM_DECOMP("auto"),            // String
      .READ_DATA_WIDTH_A(32),         // DECIMAL
      .READ_DATA_WIDTH_B(128),        // DECIMAL
      .READ_LATENCY_A(2),             // DECIMAL
      .READ_LATENCY_B(2),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(32),        // DECIMAL
      .WRITE_DATA_WIDTH_B(128),       // DECIMAL
      .WRITE_MODE_A("no_change"),     // String
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   copper_mem (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(addrb),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(rstb),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(!copper_en),              // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );


endmodule
