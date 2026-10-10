`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2008-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	rf68000_ccr.sv
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
import const_pkg::*;
import rf68000_pkg::*;

module rf68000_ccr(rst, clk, ir, sz, resL, d, s, dd, imm, immx, Dc, Dc1, dvovf,
	bf_nf, bf_zf, cnt, shift_op, flag_update, flag_updated, cf, vf, nf, zf, xf, lm);
input rst;
input clk;
input [15:0] ir;
input [1:0] sz;
input [64:0] resL;
input [63:0] d;
input [63:0] s;
input [63:0] dd;
input [63:0] imm;
input [63:0] immx;
input [63:0] Dc;
input [63:0] Dc1;
input dvovf;					// divide overflow
input bf_nf;
input bf_zf;
input [5:0] cnt;
input [2:0] shift_op;
input flag_update_e flag_update;
output flag_update_e flag_updated;
output reg cf;
output reg vf;
output reg nf;
output reg zf;
output reg xf;
output reg lm;


always_ff @(posedge clk)
	flag_updated <= flag_update;

always_ff @(posedge clk)
if (rst) begin
	cf <= 1'b0;
	vf <= 1'b0;
	nf <= 1'b0;
	zf <= 1'b0;
	xf <= 1'b0;
	lm <= 1'b0;
end
else begin
	case(flag_update)
	FU_SHIFT1:
		begin
			vf <= 1'b0;
			case(shift_op)
			3'b010,	// ROXL, ROXR
			3'b110:	cf <= xf;
			default:
				begin
					if (cnt=='d0)
						cf <= 1'b0;
				end
			endcase
		end
	FU_SHIFT:
		if (cnt!='d0) begin
			case(shift_op)
			3'b000:	// ASR
				case(sz)
				2'b00:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b01:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b10:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b11:	begin cf <= resL[0]; xf <= resL[0]; end
				endcase
			3'b001:	// LSR
				case(sz)
				2'b00:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b01:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b10:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b11:	begin cf <= resL[0]; xf <= resL[0]; end
				endcase
			3'b010:	// ROXR
				case(sz)
				2'b00:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b01:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b10:	begin cf <= resL[0]; xf <= resL[0]; end
				2'b11:	begin cf <= resL[0]; xf <= resL[0]; end
				endcase
			3'b011:	// ROR
				case(sz)
				2'b00:	begin cf <= resL[0]; end
				2'b01:	begin cf <= resL[0]; end
				2'b10:	begin cf <= resL[0]; end
				2'b11:	begin cf <= resL[0]; end
				endcase
			3'b100:	// ASL
				case({lm,sz})
				3'b000:	begin cf <= resL[ 7]; xf <= resL[ 7]; if (resL[ 7] != resL[ 8]) vf <= 1'b1; end
				3'b001:	begin cf <= resL[15]; xf <= resL[15]; if (resL[15] != resL[16]) vf <= 1'b1; end
				3'b010:	begin cf <= resL[31]; xf <= resL[31]; if (resL[31] != resL[32]) vf <= 1'b1; end
				3'b011:	begin cf <= resL[15]; xf <= resL[15]; if (resL[15] != resL[16]) vf <= 1'b1; end
				3'b100:	begin cf <= resL[15]; xf <= resL[15]; if (resL[15] != resL[16]) vf <= 1'b1; end
				3'b101:	begin cf <= resL[31]; xf <= resL[31]; if (resL[31] != resL[32]) vf <= 1'b1; end
				3'b110:	begin cf <= resL[63]; xf <= resL[63]; if (resL[63] != resL[64]) vf <= 1'b1; end
				3'b111:	begin cf <= resL[31]; xf <= resL[31]; if (resL[31] != resL[32]) vf <= 1'b1; end
				endcase
			3'b101:	// LSL
				case({lm,sz})
				3'b000:	begin cf <= resL[ 7]; xf <= resL[ 7]; end
				3'b001:	begin cf <= resL[15]; xf <= resL[15]; end
				3'b010:	begin cf <= resL[31]; xf <= resL[31]; end
				3'b011:	begin cf <= resL[15]; xf <= resL[15]; end
				3'b100:	begin cf <= resL[15]; xf <= resL[15]; end
				3'b101:	begin cf <= resL[31]; xf <= resL[31]; end
				3'b110:	begin cf <= resL[63]; xf <= resL[63]; end
				3'b111:	begin cf <= resL[31]; xf <= resL[31]; end
				endcase
			3'b110:	// ROXL
				case({lm,sz})
				3'b000:	begin cf <= resL[ 7]; xf <= resL[ 7]; end
				3'b001:	begin cf <= resL[15]; xf <= resL[15]; end
				3'b010:	begin cf <= resL[31]; xf <= resL[31]; end
				3'b011:	begin cf <= resL[15]; xf <= resL[15]; end
				3'b100:	begin cf <= resL[15]; xf <= resL[15]; end
				3'b101:	begin cf <= resL[31]; xf <= resL[31]; end
				3'b110:	begin cf <= resL[63]; xf <= resL[63]; end
				3'b111:	begin cf <= resL[31]; xf <= resL[31]; end
				endcase
			3'b111: // ROL
				case({lm,sz})
				3'b000:	begin cf <= resL[ 7]; end
				3'b001:	begin cf <= resL[15]; end
				3'b010:	begin cf <= resL[31]; end
				3'b011:	begin cf <= resL[15]; end
				3'b100:	begin cf <= resL[15]; end
				3'b101:	begin cf <= resL[31]; end
				3'b110:	begin cf <= resL[63]; end
				3'b111:	begin cf <= resL[31]; end
				endcase
			endcase
		end
		else begin
			if (shift_op==3'b100)	// ASL
				case({lm,sz})
				2'b000:	if (resL[ 7] != resL[ 8]) vf <= 1'b1;
				2'b001:	if (resL[15] != resL[16]) vf <= 1'b1;
				2'b010:	if (resL[31] != resL[32]) vf <= 1'b1;
				2'b011:	if (resL[15] != resL[16]) vf <= 1'b1;
				3'b100:	if (resL[15] != resL[16]) vf <= 1'b1;
				3'b101:	if (resL[31] != resL[32]) vf <= 1'b1;
				3'b110:	if (resL[63] != resL[64]) vf <= 1'b1;
				3'b111:	if (resL[31] != resL[32]) vf <= 1'b1;
				/*
				2'b00:	vf <= resL[ 7] != d[ 7];
				2'b01:	vf <= resL[15] != d[15];
				2'b10:	vf <= resL[31] != d[31];
				2'b11:	vf <= resL[15] != d[15];
				*/
				endcase
		end
	endcase
	
	case(flag_updated)
	FU_MOVE:
		if (ir[8:6]!=3'b001) begin	// not MOVEA
			case({lm,ir[15:12]})
			5'd1:		begin zf <= resL[ 7:0]== 8'h00; nf <= resL[7]; end
			5'd3:		begin zf <= resL[15:0]==16'h00; nf <= resL[15]; end
			5'd2:		begin zf <= resL[31:0]==32'd0;  nf <= resL[31]; end
			5'd17:	begin zf <= resL[15:0]==16'h00; nf <= resL[7]; end
			5'd19:	begin zf <= resL[31:0]==32'd0;  nf <= resL[31]; end
			5'd18:	begin zf <= resL[63:0]==64'd0;  nf <= resL[63]; end
			default:	;
			endcase
			cf <= 1'b0;
			vf <= 1'b0;
		end
	FU_CLR:
		begin
			cf <= 1'b0;
			vf <= 1'b0;
			zf <= 1'b1;
			nf <= 1'b0;
		end
	FU_EXT:
		if (lm) begin
			if (ir[6]) begin
				cf <= 1'b0;
				vf <= 1'b0;
				nf <= resL[31];
				zf <= resL[31:0]==32'h0000;
			end
			else begin
				cf <= 1'b0;
				vf <= 1'b0;
				nf <= resL[15];
				zf <= resL[15:0]==16'h00;
			end
		end
		else begin
			if (ir[6]) begin
				cf <= 1'b0;
				vf <= 1'b0;
				nf <= resL[15];
				zf <= resL[15:0]==16'h0000;
			end
			else begin
				cf <= 1'b0;
				vf <= 1'b0;
				nf <= resL[7];
				zf <= resL[7:0]==8'h00;
			end
		end
	FU_SWAP:
		begin
			cf <= 1'b0;
			vf <= 1'b0;
			if (lm) begin
				nf <= resL[63];
				zf <= resL[63:0]==64'd0;
			end
			else begin
				nf <= resL[31];
				zf <= resL[31:0]==32'd0;
			end
		end
	FU_MUL:
		begin
			cf <= 1'b0;
			vf <= 1'b0;
			if (lm) begin
				nf <= resL[63];
				zf <= resL[63:0]==64'd0;
			end
			else begin
				nf <= resL[31];
				zf <= resL[31:0]==32'd0;
			end
		end
	FU_TST:
		begin
			cf <= 1'b0;
			vf <= 1'b0;
			case({lm,sz})
			3'b000:	begin zf <= resL[7:0]==8'h00; nf <= resL[7]; end
			3'b001:	begin zf <= resL[15:0]==16'h00; nf <= resL[15]; end
			3'b010:	begin zf <= resL[31:0]==32'h00; nf <= resL[31]; end
			3'b100:	begin zf <= resL[15:0]==16'h00; nf <= resL[15]; end
			3'b101:	begin zf <= resL[31:0]==32'h00; nf <= resL[31]; end
			3'b110:	begin zf <= resL[63:0]==64'h00; nf <= resL[63]; end
			default:	;
			endcase
		end
	FU_CMP:
		begin
			case({lm,sz})
			3'b000:	begin zf <= resL[ 7:0]== 8'd0; nf <= resL[ 7]; cf <= resL[ 8]; vf <= fnSubOverflow(resL[ 7],d[ 7],s[ 7]); end
			3'b001:	begin zf <= resL[15:0]==16'd0; nf <= resL[15]; cf <= resL[16]; vf <= fnSubOverflow(resL[15],d[15],s[15]); end
			3'b010:	begin zf <= resL[31:0]==32'd0; nf <= resL[31]; cf <= resL[32]; vf <= fnSubOverflow(resL[31],d[31],s[31]); end
			3'b011:	
				begin	// CMPA
					if (ir[8]) begin
				 		zf <= resL[31:0]==32'd0; nf <= resL[31]; cf <= resL[32]; vf <= fnSubOverflow(resL[31],d[31],s[31]); end
				 	else begin
				 		zf <= resL[15:0]==16'd0; nf <= resL[15]; cf <= resL[16]; vf <= fnSubOverflow(resL[15],d[15],s[15]); end
				end
			3'b000:	begin zf <= resL[15:0]==16'd0; nf <= resL[15]; cf <= resL[16]; vf <= fnSubOverflow(resL[15],d[15],s[15]); end
			3'b001:	begin zf <= resL[31:0]==32'd0; nf <= resL[31]; cf <= resL[32]; vf <= fnSubOverflow(resL[31],d[31],s[31]); end
			3'b010:	begin zf <= resL[63:0]==64'd0; nf <= resL[63]; cf <= resL[64]; vf <= fnSubOverflow(resL[63],d[63],s[63]); end
			3'b011:	
				begin	// CMPA
					if (ir[8]) begin
				 		zf <= resL[63:0]==64'd0; nf <= resL[63]; cf <= resL[64]; vf <= fnSubOverflow(resL[63],d[63],s[63]); end
				 	else begin
				 		zf <= resL[31:0]==32'd0; nf <= resL[31]; cf <= resL[32]; vf <= fnSubOverflow(resL[31],d[31],s[31]); end
				end
			endcase
		end
	FU_ADD:
		begin
			case({lm,sz})
			3'b000:
				begin
					cf <= resL[8];
					nf <= resL[7];
					zf <= resL[7:0]==8'h00;
					vf <= fnAddOverflow(resL[7],dd[7],s[7]);
					xf <= resL[8];
				end
			3'b001:
				begin
					cf <= resL[16];
					nf <= resL[15];
					zf <= resL[15:0]==16'h0000;
					vf <= fnAddOverflow(resL[15],dd[15],s[15]);
					xf <= resL[16];
				end
			3'b010:
				begin
					cf <= resL[32];
					nf <= resL[31];
					zf <= resL[31:0]==32'h00000000;
					vf <= fnAddOverflow(resL[31],dd[31],s[31]);
					xf <= resL[32];
				end
			3'b100:
				begin
					cf <= resL[16];
					nf <= resL[15];
					zf <= resL[15:0]==16'h0000;
					vf <= fnAddOverflow(resL[15],dd[15],s[15]);
					xf <= resL[16];
				end
			3'b101:
				begin
					cf <= resL[32];
					nf <= resL[31];
					zf <= resL[31:0]==32'h00000000;
					vf <= fnAddOverflow(resL[31],dd[31],s[31]);
					xf <= resL[32];
				end
			3'b110:
				begin
					cf <= resL[64];
					nf <= resL[63];
					zf <= resL[63:0]==64'h00;
					vf <= fnAddOverflow(resL[63],dd[63],s[63]);
					xf <= resL[64];
				end
			default:	;
			endcase
		end
	FU_ADDX:
		begin
			case({lm,sz})
			3'b000:
				begin
					cf <= resL[8];
					nf <= resL[7];
					if (resL[7:0]!=8'h00)
						zf <= 1'b0;
					vf <= fnAddOverflow(resL[7],dd[7],s[7]);
					xf <= resL[8];
				end
			3'b001:
				begin
					cf <= resL[16];
					nf <= resL[15];
					if (resL[15:0]!=16'h00)
						zf <= 1'b0;
					vf <= fnAddOverflow(resL[15],dd[15],s[15]);
					xf <= resL[16];
				end
			3'b010:
				begin
					cf <= resL[32];
					nf <= resL[31];
					if (resL[31:0]!=32'h00)
						zf <= 1'b0;
					vf <= fnAddOverflow(resL[31],dd[31],s[31]);
					xf <= resL[32];
				end
			3'b100:
				begin
					cf <= resL[16];
					nf <= resL[15];
					if (resL[15:0]!=16'h00)
						zf <= 1'b0;
					vf <= fnAddOverflow(resL[15],dd[15],s[15]);
					xf <= resL[16];
				end
			3'b101:
				begin
					cf <= resL[32];
					nf <= resL[31];
					if (resL[31:0]!=32'h00)
						zf <= 1'b0;
					vf <= fnAddOverflow(resL[31],dd[31],s[31]);
					xf <= resL[32];
				end
			3'b110:
				begin
					cf <= resL[64];
					nf <= resL[63];
					if (resL[63:0]!=64'h00)
						zf <= 1'b0;
					vf <= fnAddOverflow(resL[63],dd[63],s[63]);
					xf <= resL[64];
				end
			default:	;
			endcase
		end
	FU_SUBX:
		begin
			case({lm,sz})
			3'b000:
				begin
					cf <= resL[8];
					nf <= resL[7];
					if (resL[7:0]!=8'h00)
						zf <= 1'b0;
					vf <= fnSubOverflow(resL[7],dd[7],s[7]);
					xf <= resL[8];
				end
			3'b001:
				begin
					cf <= resL[16];
					nf <= resL[15];
					if (resL[15:0]!=16'h00)
						zf <= 1'b0;
					vf <= fnSubOverflow(resL[15],dd[15],s[15]);
					xf <= resL[16];
				end
			3'b010:
				begin
					cf <= resL[32];
					nf <= resL[31];
					if (resL[31:0]!=32'h00)
						zf <= 1'b0;
					vf <= fnSubOverflow(resL[31],dd[31],s[31]);
					xf <= resL[32];
				end
			3'b100:
				begin
					cf <= resL[16];
					nf <= resL[15];
					if (resL[15:0]!=16'h00)
						zf <= 1'b0;
					vf <= fnSubOverflow(resL[15],dd[15],s[15]);
					xf <= resL[16];
				end
			3'b101:
				begin
					cf <= resL[32];
					nf <= resL[31];
					if (resL[31:0]!=32'h00)
						zf <= 1'b0;
					vf <= fnSubOverflow(resL[31],dd[31],s[31]);
					xf <= resL[32];
				end
			3'b110:
				begin
					cf <= resL[64];
					nf <= resL[63];
					if (resL[63:0]!=64'h00)
						zf <= 1'b0;
					vf <= fnSubOverflow(resL[63],dd[63],s[63]);
					xf <= resL[64];
				end
			default:	;
			endcase
		end
	FU_NEGX:
		case({lm,sz})
		3'b000:
			begin
				cf <= resL[8];
				nf <= resL[7];
				vf <= fnSubOverflow(resL[7],dd[7],s[7]);
				zf <= resL[7:0]==8'h00;
				xf <= resL[8];
			end
		3'b001:
			begin
				cf <= resL[16];
				nf <= resL[15];
				vf <= fnSubOverflow(resL[15],dd[15],s[15]);
				zf <= resL[15:0]==16'h00;
				xf <= resL[16];
			end
		3'b010:
			begin
				cf <= resL[32];
				nf <= resL[31];
				vf <= fnSubOverflow(resL[31],dd[31],s[31]);
				zf <= resL[31:0]==32'h00;
				xf <= resL[32];
			end
		3'b100:
			begin
				cf <= resL[16];
				nf <= resL[15];
				vf <= fnSubOverflow(resL[15],dd[15],s[15]);
				zf <= resL[15:0]==16'h00;
				xf <= resL[16];
			end
		3'b101:
			begin
				cf <= resL[32];
				nf <= resL[31];
				vf <= fnSubOverflow(resL[31],dd[31],s[31]);
				zf <= resL[31:0]==32'h00;
				xf <= resL[32];
			end
		3'b110:
			begin
				cf <= resL[64];
				nf <= resL[63];
				vf <= fnSubOverflow(resL[63],dd[63],s[63]);
				zf <= resL[63:0]==64'h00;
				xf <= resL[64];
			end
		endcase
	FU_SUB:
		begin
			case({lm,sz})
			3'b000:
				begin
					cf <= resL[8];
					nf <= resL[7];
					zf <= resL[7:0]==8'h00;
					vf <= fnSubOverflow(resL[7],dd[7],s[7]);
					xf <= resL[8];
				end
			3'b001:
				begin
					cf <= resL[16];
					nf <= resL[15];
					zf <= resL[15:0]==16'h0000;
					vf <= fnSubOverflow(resL[15],dd[15],s[15]);
					xf <= resL[16];
				end
			3'b010:
				begin
					cf <= resL[32];
					nf <= resL[31];
					zf <= resL[31:0]==32'h00000000;
					vf <= fnSubOverflow(resL[31],dd[31],s[31]);
					xf <= resL[32];
				end
			2'b100:
				begin
					cf <= resL[16];
					nf <= resL[15];
					zf <= resL[15:0]==16'h0000;
					vf <= fnSubOverflow(resL[15],dd[15],s[15]);
					xf <= resL[16];
				end
			2'b101:
				begin
					cf <= resL[32];
					nf <= resL[31];
					zf <= resL[31:0]==32'h00000000;
					vf <= fnSubOverflow(resL[31],dd[31],s[31]);
					xf <= resL[32];
				end
			3'b110:
				begin
					cf <= resL[64];
					nf <= resL[63];
					zf <= resL[63:0]==64'h00;
					vf <= fnSubOverflow(resL[63],dd[63],s[63]);
					xf <= resL[64];
				end
			default:	;
			endcase
		end
	FU_LOGIC:
		begin
			cf <= 1'b0;
			vf <= 1'b0;
			case({lm,sz})
			3'b000:
				begin
					nf <= resL[7];
					zf <= resL[7:0]==8'h00;
				end
			3'b001:
				begin
					nf <= resL[15];
					zf <= resL[15:0]==16'h0000;
				end
			3'b010:
				begin
					nf <= resL[31];
					zf <= resL[31:0]==32'h00000000;
				end
			3'b100:
				begin
					nf <= resL[15];
					zf <= resL[15:0]==16'h0000;
				end
			3'b101:
				begin
					nf <= resL[31];
					zf <= resL[31:0]==32'h00000000;
				end
			3'b110:
				begin
					nf <= resL[63];
					zf <= resL[63:0]==64'h00;
				end
			default:	;
			endcase
		end
	FU_ADDQ:
		begin
			case({lm,sz})
			3'b000:
				begin
					 xf <= resL[8];
					 cf <= resL[8];
//						 vf <= resL[8]!=resL[7];
					vf <= fnAddOverflow(resL[7],dd[7],s[7]);
					 zf <= resL[7:0]==8'd0;
					 nf <= resL[7];
				end
			3'b001:
				begin
					 xf <= resL[16];
					 cf <= resL[16];
					vf <= fnAddOverflow(resL[15],dd[15],s[15]);
					 //vf <= resW[16]!=resW[15];
					 zf <= resL[15:0]==16'd0;
					 nf <= resL[15];
				end
			3'b010:
				begin
					 xf <= resL[32];
					 cf <= resL[32];
					vf <= fnAddOverflow(resL[31],dd[31],s[31]);
					// vf <= resL[32]!=resL[31];
					 zf <= resL[31:0]==32'd0;
					 nf <= resL[31];
				end
			3'b100:
				begin
					 xf <= resL[16];
					 cf <= resL[16];
					vf <= fnAddOverflow(resL[15],dd[15],s[15]);
					 //vf <= resW[16]!=resW[15];
					 zf <= resL[15:0]==16'd0;
					 nf <= resL[15];
				end
			3'b101:
				begin
					 xf <= resL[32];
					 cf <= resL[32];
					vf <= fnAddOverflow(resL[31],dd[31],s[31]);
					// vf <= resL[32]!=resL[31];
					 zf <= resL[31:0]==32'd0;
					 nf <= resL[31];
				end
			3'b110:
				begin
					 xf <= resL[64];
					 cf <= resL[64];
//						 vf <= resL[8]!=resL[7];
					vf <= fnAddOverflow(resL[63],dd[63],s[63]);
					 zf <= resL[63:0]==64'd0;
					 nf <= resL[63];
				end
			default:	;
			endcase
		end
	FU_SUBQ:
		begin
			case({lm,sz})
			3'b00:
				begin
					 xf <= resL[8];
					 cf <= resL[8];
//						 vf <= resL[8]!=resL[7];
					vf <= fnSubOverflow(resL[7],dd[7],s[7]);
					 zf <= resL[7:0]==8'd0;
					 nf <= resL[7];
				end
			3'b01:
				begin
					 xf <= resL[16];
					 cf <= resL[16];
					vf <= fnSubOverflow(resL[15],dd[15],s[15]);
					 //vf <= resW[16]!=resW[15];
					 zf <= resL[15:0]==16'd0;
					 nf <= resL[15];
				end
			3'b10:
				begin
					 xf <= resL[32];
					 cf <= resL[32];
					vf <= fnSubOverflow(resL[31],dd[31],s[31]);
					// vf <= resL[32]!=resL[31];
					 zf <= resL[31:0]==32'd0;
					 nf <= resL[31];
				end
			3'b100:
				begin
					 xf <= resL[16];
					 cf <= resL[16];
					vf <= fnSubOverflow(resL[15],dd[15],s[15]);
					 //vf <= resW[16]!=resW[15];
					 zf <= resL[15:0]==16'd0;
					 nf <= resL[15];
				end
			3'b101:
				begin
					 xf <= resL[32];
					 cf <= resL[32];
					vf <= fnSubOverflow(resL[31],dd[31],s[31]);
					// vf <= resL[32]!=resL[31];
					 zf <= resL[31:0]==32'd0;
					 nf <= resL[31];
				end
			3'b110:
				begin
					 xf <= resL[64];
					 cf <= resL[64];
//						 vf <= resL[8]!=resL[7];
					vf <= fnSubOverflow(resL[63],dd[63],s[63]);
					 zf <= resL[63:0]==64'd0;
					 nf <= resL[63];
				end
			default:	;
			endcase
		end
	FU_MOVEQ:
		begin
			vf <= 1'b0;
			cf <= 1'b0;
			nf <= resL[7];
			zf <= resL[7:0]==8'h00;
		end
	FU_ADDI:
		begin
			case(ir[11:8])
			4'h0,4'h2,4'hA:
				begin	// ORI,ANDI,EORI
					cf <= 1'b0;
					vf <= 1'b0;
					case({lm,sz})
					3'b000:	zf <= resL[7:0]==8'h00;
					3'b001:	zf <= resL[15:0]==16'h00;
					3'b010:	zf <= resL[31:0]==32'd0;
					3'b100:	zf <= resL[15:0]==16'h00;
					3'b101:	zf <= resL[31:0]==32'd0;
					3'b110:	zf <= resL[63:0]==64'h00;
					default:	;
					endcase
					case({lm,sz})
					3'b000:	nf <= resL[7];
					3'b001:	nf <= resL[15];
					3'b010:	nf <= resL[31];
					3'b100:	nf <= resL[15];
					3'b101:	nf <= resL[31];
					3'b110:	nf <= resL[63];
					default:	;
					endcase
				end
			4'h4:	// SUBI
				case({lm,sz})
				3'b000:
					begin
						xf <= resL[8];
						cf <= resL[8];
						vf <= fnSubOverflow(resL[7],dd[7],immx[7]);
						//vf <= resB[8]!=resB[7];
						zf <= resL[7:0]==8'd0;
						nf <= resL[7];
					end
				3'b001:
					begin
						xf <= resL[16];
						cf <= resL[16];
						vf <= fnSubOverflow(resL[15],dd[15],immx[15]);
						//vf <= resW[16]!=resW[15];
						zf <= resL[15:0]==16'd0;
						nf <= resL[15];
					end
				3'b010:
					begin
						xf <= resL[32];
						cf <= resL[32];
						vf <= fnSubOverflow(resL[31],dd[31],immx[31]);
						//vf <= resL[32]!=resL[31];
						zf <= resL[31:0]==32'd0;
						nf <= resL[31];
					end
				3'b100:
					begin
						xf <= resL[16];
						cf <= resL[16];
						vf <= fnSubOverflow(resL[15],dd[15],immx[15]);
						//vf <= resW[16]!=resW[15];
						zf <= resL[15:0]==16'd0;
						nf <= resL[15];
					end
				3'b101:
					begin
						xf <= resL[32];
						cf <= resL[32];
						vf <= fnSubOverflow(resL[31],dd[31],immx[31]);
						//vf <= resL[32]!=resL[31];
						zf <= resL[31:0]==32'd0;
						nf <= resL[31];
					end
				3'b110:
					begin
						xf <= resL[64];
						cf <= resL[64];
						vf <= fnSubOverflow(resL[63],dd[63],immx[63]);
						//vf <= resB[8]!=resB[7];
						zf <= resL[63:0]==64'd0;
						nf <= resL[63];
					end
				default:	;
				endcase
			4'h6:	// ADDI
				case({lm,sz})
				3'b00:
					begin
						xf <= resL[8];
						cf <= resL[8];
						vf <= fnAddOverflow(resL[7],dd[7],immx[7]);
						//vf <= resB[8]!=resB[7];
						zf <= resL[7:0]==8'd0;
						nf <= resL[7];
					end
				3'b01:
					begin
						xf <= resL[16];
						cf <= resL[16];
						vf <= fnAddOverflow(resL[15],dd[15],immx[15]);
						//vf <= resW[16]!=resW[15];
						zf <= resL[15:0]==16'd0;
						nf <= resL[15];
					end
				3'b10:
					begin
						xf <= resL[32];
						cf <= resL[32];
						vf <= fnAddOverflow(resL[31],dd[31],immx[31]);
						//vf <= resL[32]!=resL[31];
						zf <= resL[31:0]==32'd0;
						nf <= resL[31];
					end
				3'b100:
					begin
						xf <= resL[16];
						cf <= resL[16];
						vf <= fnAddOverflow(resL[15],dd[15],immx[15]);
						//vf <= resW[16]!=resW[15];
						zf <= resL[15:0]==16'd0;
						nf <= resL[15];
					end
				3'b101:
					begin
						xf <= resL[32];
						cf <= resL[32];
						vf <= fnAddOverflow(resL[31],dd[31],immx[31]);
						//vf <= resL[32]!=resL[31];
						zf <= resL[31:0]==32'd0;
						nf <= resL[31];
					end
				3'b110:
					begin
						xf <= resL[64];
						cf <= resL[64];
						vf <= fnAddOverflow(resL[63],dd[63],immx[63]);
						//vf <= resB[8]!=resB[7];
						zf <= resL[63:0]==64'd0;
						nf <= resL[63];
					end
				default:	;
				endcase
			4'hC:	// CMPI
				case({lm,sz})
				3'b000:
					begin
						cf <= resL[8];
						vf <= fnSubOverflow(resL[7],dd[7],immx[7]);
						zf <= resL[7:0]==8'd0;
						nf <= resL[7];
					end
				3'b001:
					begin
						cf <= resL[16];
						vf <= fnSubOverflow(resL[15],dd[15],immx[15]);
						//vf <= resW[16]!=resW[15];
						zf <= resL[15:0]==16'd0;
						nf <= resL[15];
					end
				3'b010:
					begin
						cf <= resL[32];
						vf <= fnSubOverflow(resL[31],dd[31],immx[31]);
						//vf <= resL[32]!=resL[31];
						zf <= resL[31:0]==32'd0;
						nf <= resL[31];
					end
				3'b100:
					begin
						cf <= resL[16];
						vf <= fnSubOverflow(resL[15],dd[15],immx[15]);
						//vf <= resW[16]!=resW[15];
						zf <= resL[15:0]==16'd0;
						nf <= resL[15];
					end
				3'b101:
					begin
						cf <= resL[32];
						vf <= fnSubOverflow(resL[31],dd[31],immx[31]);
						//vf <= resL[32]!=resL[31];
						zf <= resL[31:0]==32'd0;
						nf <= resL[31];
					end
				3'b110:
					begin
						cf <= resL[64];
						vf <= fnSubOverflow(resL[63],dd[63],immx[63]);
						zf <= resL[63:0]==64'd0;
						nf <= resL[63];
					end
				default:	;
				endcase
			endcase
		end
	FU_ANDI_CCR:
		begin
			cf <= cf & imm[0];
			vf <= vf & imm[1];
			zf <= zf & imm[2];
			nf <= nf & imm[3];
			xf <= xf & imm[4];
			lm <= lm & imm[5];
		end
	FU_ANDI_SR:
		begin
			cf <= cf & imm[0];
			vf <= vf & imm[1];
			zf <= zf & imm[2];
			nf <= nf & imm[3];
			xf <= xf & imm[4];
			lm <= lm & imm[5];
		end
	FU_ANDI_SRX:
		begin
			cf <= cf & imm[0];
			vf <= vf & imm[1];
			zf <= zf & imm[2];
			nf <= nf & imm[3];
			xf <= xf & imm[4];
			lm <= lm & imm[5];
		end
	FU_EORI_CCR:
		begin
			cf <= cf ^ imm[0];
			vf <= vf ^ imm[1];
			zf <= zf ^ imm[2];
			nf <= nf ^ imm[3];
			xf <= xf ^ imm[4];
			lm <= lm ^ imm[5];
		end
	FU_EORI_SR:
		begin
			cf <= cf ^ imm[0];
			vf <= vf ^ imm[1];
			zf <= zf ^ imm[2];
			nf <= nf ^ imm[3];
			xf <= xf ^ imm[4];
			lm <= lm ^ imm[5];
		end
	FU_EORI_SRX:
		begin
			cf <= cf ^ imm[0];
			vf <= vf ^ imm[1];
			zf <= zf ^ imm[2];
			nf <= nf ^ imm[3];
			xf <= xf ^ imm[4];
			lm <= lm ^ imm[5];
		end
	FU_ORI_CCR:
		begin
			cf <= cf | imm[0];
			vf <= vf | imm[1];
			zf <= zf | imm[2];
			nf <= nf | imm[3];
			xf <= xf | imm[4];
			lm <= lm | imm[5];
		end
	FU_ORI_SR:
		begin
			cf <= cf | imm[0];
			vf <= vf | imm[1];
			zf <= zf | imm[2];
			nf <= nf | imm[3];
			xf <= xf | imm[4];
			lm <= lm | imm[5];
		end
	FU_ORI_SRX:
		begin
			cf <= cf | imm[0];
			vf <= vf | imm[1];
			zf <= zf | imm[2];
			nf <= nf | imm[3];
			xf <= xf | imm[4];
			lm <= lm | imm[5];
		end
	FU_MOVE2CCR:
		begin
			cf <= s[0];
			vf <= s[1];
			zf <= s[2];
			nf <= s[3];
			xf <= s[4];
			lm <= s[5];
		end	
	FU_MOVE2SR:
		begin
			cf <= s[0];
			vf <= s[1];
			zf <= s[2];
			nf <= s[3];
			xf <= s[4];
			lm <= s[5];
		end
	FU_MOVE2SRX:
		begin
			cf <= s[0];
			vf <= s[1];
			zf <= s[2];
			nf <= s[3];
			xf <= s[4];
			lm <= s[5];
		end
	FU_SHIFT:
		case({lm,sz})
		3'b00:	begin zf <= resL[7:0]== 8'h00; nf <= resL[ 7]; end
		3'b01:	begin zf <= resL[15:0]==16'h00; nf <= resL[15]; end
		3'b10:	begin zf <= resL[31:0]==32'h00; nf <= resL[31]; end
		3'b11:	begin zf <= resL[15:0]==16'h00; nf <= resL[15]; end
		3'b100:	begin zf <= resL[15:0]==16'h00; nf <= resL[15]; end
		3'b101:	begin zf <= resL[31:0]==32'h00; nf <= resL[31]; end
		3'b110:	begin zf <= resL[63:0]==64'h00; nf <= resL[63]; end
		3'b111:	begin zf <= resL[31:0]==32'h00; nf <= resL[31]; end
		endcase
	FU_CAS:
		case({lm,ir[10:9]})
		3'b001:
			begin
				zf <= resL[7:0]==8'd0;
				nf <= resL[7];
				cf <= resL[8];
				vf <= fnSubOverflow(resL[7],d[7],Dc[7]);
			end
		3'b010:
			begin
				zf <= resL[15:0]==16'd0;
				nf <= resL[15];
				cf <= resL[16];
				vf <= fnSubOverflow(resL[15],d[15],Dc[15]);
			end
		3'b011:
			begin
				zf <= resL[31:0]==32'd0;
				nf <= resL[31];
				cf <= resL[32];
				vf <= fnSubOverflow(resL[31],d[31],Dc[31]);
			end
		3'b101:
			begin
				zf <= resL[15:0]==16'd0;
				nf <= resL[15];
				cf <= resL[16];
				vf <= fnSubOverflow(resL[15],d[15],Dc[15]);
			end
		3'b110:
			begin
				zf <= resL[31:0]==32'd0;
				nf <= resL[31];
				cf <= resL[32];
				vf <= fnSubOverflow(resL[31],d[31],Dc[31]);
			end
		3'b111:
			begin
				zf <= resL[63:0]==64'd0;
				nf <= resL[63];
				cf <= resL[64];
				vf <= fnSubOverflow(resL[63],d[63],Dc[63]);
			end
		default:	;
		endcase
	FU_CASO:
		case({lm,ir[10:9]})
		3'b010:
			begin
				zf <= resL[31:0]==32'd0;
				nf <= resL[31];
				cf <= resL[32];
				vf <= fnSubOverflow(resL[31],dd[31],Dc1[31]);
			end
		3'b011:
			begin
				zf <= resL[63:0]==64'd0;
				nf <= resL[63];
				cf <= resL[64];
				vf <= fnSubOverflow(resL[63],dd[63],Dc1[63]);
			end
		3'b110:
			begin
				zf <= resL[63:0]==64'd0;
				nf <= resL[63];
				cf <= resL[64];
				vf <= fnSubOverflow(resL[63],dd[63],Dc1[63]);
			end
		default:	;
		endcase
	FU_BCD:
		begin
			cf <= resL[11:8];
			xf <= resL[11:8];
			nf <= resL[7];
			if (resL[7:0]!=8'h00)
				zf <= 1'b0;
		end
	FU_STOP:
		begin
			cf <= imm[0];
			vf <= imm[1];
			zf <= imm[2];
			nf <= imm[3];
			xf <= imm[4];
			lm <= imm[5];
		end
	FU_DIV:
		begin
			cf <= 1'b0;
			nf <= resL[15];
			zf <= resL[15:0]==16'h0000;
			vf <= dvovf;
		end
	FU_TAS:
		begin
			cf <= 1'b0;
			vf <= 1'b0;
			zf <= dd[7:0]==8'h00;
			nf <= dd[7];
		end
	FU_BTST:
		begin
			zf <= dd[1:0] == 2'b00;
`ifdef SUPPORT_BITPAIRS					
			cf <= dd[1:0] == 2'b01;
			nf <= dd[1:0] == 2'b10;
			vf <= dd[1:0] == 2'b11;
`endif					
		end
	FU_RTE:
		begin
			cf <= s[0];
			vf <= s[1];
			zf <= s[2];
			nf <= s[3];
			xf <= s[4];
			lm <= s[5];
		end
	FU_BIN2BCD:
		begin
			zf <= s==32'h0;
			vf <= d[7:0]!=8'h00;
		end
	FU_BITFLD:
		begin
			cf <= 1'b0;
			vf <= 1'b0;
			nf <= bf_nf;
			zf <= bf_zf;
		end
	FU_RESET:
		begin
			lm <= 1'b0;
		end
	default:	;
	endcase
end

endmodule
