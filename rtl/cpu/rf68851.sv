`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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

module rf68851(rst_i, clk_i,
	cfc_i, ccyc_i, cstb_i, cack_o, cerr_o, cvpa_o, cios_i,
	cwe_i, csel_i, cadr_i, cdat_i, cdat_o,
	mfc_o, mcyc_o, mstb_o, mack_i, merr_i, mvpa_i, mwe_o, msel_o, madr_o,
	mdat_o, mdat_i, mios_o, page_fault_o);
input rst_i;
input clk_i;
input [2:0] cfc_i;
input ccyc_i;
input cstb_i;
output reg cack_o;
output reg cerr_o;
output reg cvpa_o;
input cwe_i;
input [3:0] csel_i;
input [31:0] cadr_i;
output reg [31:0] cdat_i;
input [31:0] cdat_o;
input cios_i;
output reg [2:0] mfc_o;
output reg mcyc_o;
output reg mstb_o;
input mack_i;					// From system
input merr_i;
input mvpa_i;
output reg mwe_o;
output reg [3:0] msel_o;
output reg [31:0] madr_o;
output reg [31:0] mdat_o;
input [31:0] mdat_i;
output reg mios_o;
output reg page_fault_o;

parameter PTE_PRESENT = 13;
parameter PTE_R = 2;
parameter PTE_W = 1;
parameter PTE_X = 0;

typedef struct packed
{
	logic [17:0] ppage;
	logic p;
	logic [8:0] resv;
	logic s;
	logic r;
	logic w;
	logic x;
} pte_t;

typedef struct packed
{
	logic [10:0] pid;
	logic [17:0] vpage;
	pte_t pte;
} atc_entry_t;

integer n1,n2;

reg [2:0] fc_i;
reg cyc_i,stb_i,we_i;
reg [3:0] sel_i;
reg [31:0] adr_i;
reg [31:0] dat_o;
reg ios_i;
reg mack_id,merr_id,mvpa_id;
reg [31:0] mdat_id;
reg work_cyc,work_stb,work_we;
reg [3:0] work_sel;
reg [31:0] work_adr;
reg ack1d;
reg cs_mmu;
reg ack1,ack2;
reg cs_root_ptr;
reg atc_hit, atc_hit_r;
reg mmu_act;
reg [5:0] atc_ua;
atc_entry_t atc [0:63];
reg atc_err;
reg [31:14] padr1;
reg [31:0] adri_r;
reg [31:0] dati_r;
reg [31:8] root_ptro;
reg [31:0] mmu_en [0:63];

reg [10:0] pid;
reg [31:8] root_adr;
pte_t pte;
reg [31:0] page_fault_addr;
reg mmu_access;
reg kernel_as;

initial begin
	for (n2 = 0; n2 < 64; n2 = n2 + 1)
	begin
		atc[n2] = {$bits(atc_entry_t){1'b1}};
		mmu_en[n2] = 32'd0;
	end
end

typedef enum logic [3:0] 
{
	ST_WAIT_MISS = 4'd0,
	ST_ACCESS1,
	ST_ACCESS2,
	ST_WAIT_ACK2,
	ST_ATC_UPDATE	
} mmu_state_e;
reg [9:0] mmu_state;

// Detect kernel address space
// First 256MB or highest 1GB
always_comb
	kernel_as = cadr_i[31:28]==4'h0 || cadr_i[31:30]==2'b11 || cfc_i[2];

always_comb
	cs_mmu = cadr_i[31:16]==16'hFD07 && ccyc_i && cstb_i;
always_ff @(posedge clk_i)
	ack2 <= cs_mmu;
always_ff @(posedge clk_i)
	ack1 <= ack2 & cs_mmu;

always_ff @(posedge clk_i)
	adri_r <= cadr_i;
always_ff @(posedge clk_i)
	dati_r <= cdat_o;

(* ram_style="block" *)
reg [31:8] root_ptr [0:2047];
always_ff @(posedge clk_i)
	if (cs_mmu && cwe_i && !cadr_i[13]) begin
		root_ptr[cadr_i[12:2]] <= cdat_i[31:8];
	end
always_ff @(posedge clk_i)
	root_adr <= root_ptr[pid];
always_ff @(posedge clk_i)
	root_ptro <= root_ptr[adri_r];

wire pe_wr, pe_rd, ne_mcyc;
edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(cs_mmu &  cwe_i), .pe(pe_wr), .ne(), .ee());
edge_det ued2 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(cs_mmu & ~cwe_i), .pe(pe_rd), .ne(), .ee());

always_ff @(posedge clk_i)
if (rst_i) begin
	pid <= 11'd0;
end
else begin
if (cs_mmu & cwe_i)
	casez(cadr_i[13:2])
	12'b100000??????:	
		mmu_en[cadr_i[7:2]] <= cdat_o;
	12'b100001000000:	
		pid <= cdat_o[10:0];
	default:	;
	endcase
end


always_ff @(posedge clk_i)
if (cs_mmu & ~cwe_i)
	casez(adri_r[13:2])
	12'b0???????????:	cdat_i <= root_ptro;
	12'b100000??????:	
		begin
			cdat_i <= mmu_en[adri_r[7:2]];
		end
	12'b100001000000:
		begin
			cdat_i <= 32'd0;
			cdat_i[10:0] <= pid;
		end
	12'b100001000001:
		cdat_i <= page_fault_addr;
	default:	cdat_i <= 32'd0;
	endcase
else
	cdat_i <= mdat_i;

always_ff @(posedge clk_i)
	ack1d <= cs_mmu ? ack1 : mack_i;

always_comb
begin
	atc_hit = 1'b0;
	atc_err = 1'b0;
	for (n1 = 0; n1 < 64; n1 = n1 + 1)
		if (atc[n1].vpage==cadr_i[31:14] && pid==atc[n1].pid) begin
			padr1 = atc[n1].pte.ppage;
			atc_hit = 1'b1;
			case(cfc_i)
			3'b000:	;	// not used
			3'b001:		// user data
				begin
					if (~atc[n1].pte.w & cwe_i)
						atc_err = 1'b1;
					if (~atc[n1].pte.r & ~cwe_i)
						atc_err = 1'b1;
				end
			3'b010:		// user code
				begin
					if (~atc[n1].pte.x)
						atc_err = 1'b1;
				end
			3'b011:	;	// not used
			3'b100:	;	// not used
			3'b101:	;	// supervisor data
			3'b110:	;	// supervisor program
			3'b111:	; // interrupt acknowledge
			endcase
			break;
		end
end

always_comb
	atc_hit_r = atc_hit || !mmu_en[pid[10:5]][pid[4:0]] || kernel_as;
always_comb
	mmu_act = mmu_en[pid[10:5]][pid[4:0]] && !kernel_as;

always_comb
begin
	if (mmu_act) begin
		if (atc_hit)
			adr_i <= {padr1,cadr_i[13:0]};
	end
	// No translation if mmu not enabled.
	else
		adr_i <= cadr_i;
end

always_ff @(posedge clk_i) fc_i <= cfc_i;
always_ff @(posedge clk_i) cyc_i <= ccyc_i & atc_hit_r;
always_ff @(posedge clk_i) stb_i <= cstb_i & atc_hit_r;
always_ff @(posedge clk_i) we_i <= cwe_i;
always_ff @(posedge clk_i) sel_i <= csel_i;
always_ff @(posedge clk_i) dat_o <= cdat_o;
always_ff @(posedge clk_i) ios_i <= cios_i;

always_comb
if (mmu_access) begin
	mcyc_o = work_cyc;
	mstb_o = work_stb;
	cack_o = 1'b0;
	cerr_o = 1'b0;
	cvpa_o = 1'b0;
	mwe_o = work_we;
	msel_o = work_sel;
	madr_o = work_adr;
	mdat_o = 32'd0;
end
else 
begin
	mfc_o = cfc_i;
	mcyc_o = ccyc_i & atc_hit_r;
	mstb_o = cstb_i & atc_hit_r;
	cack_o = ack1d;
	cerr_o = mmu_act ? atc_err|merr_i : merr_i;
	cvpa_o = mvpa_i;
	mwe_o = cwe_i;
	msel_o = csel_i;
	madr_o = cadr_i;
	mdat_o = cdat_o;
	mios_o = cios_i;
end

always_ff @(posedge clk_i)
if (rst_i) begin
	mmu_access <= 1'b0;
	work_cyc <= 1'b0;
	work_stb <= 1'b0;
	work_we <= 1'b0;
	work_sel <= 4'h0;
	work_adr <= 32'h0;
	atc_ua <= 6'd0;
	pte <= 32'h0;
	page_fault_o <= 1'b0;
end
else begin
	if (cs_mmu & cwe_i && cadr_i[13:2]==12'b100001000001)
		page_fault_o <= 1'b0;
	case(1'b1)
	mmu_state[ST_WAIT_MISS]:
		if (!atc_hit_r) begin
			mmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			work_adr <= {root_adr,cadr_i[31:26],2'b00};
		end
	mmu_state[ST_ACCESS1]:
		begin
			mmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			work_adr <= {root_adr,cadr_i[31:26],2'b00};
			if (mack_i) begin
				work_cyc <= 1'b0;
				work_stb <= 1'b0;
				work_sel <= 4'h0;
				pte <= pte_t'(mdat_i);
			end
		end
	mmu_state[ST_ACCESS2]:
		begin
			mmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			work_adr <= {pte.ppage,cadr_i[25:14],2'b00};
		end
	mmu_state[ST_WAIT_ACK2]:
		begin
			mmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			work_adr <= {pte.ppage,cadr_i[25:14],2'b00};
			if (mack_i) begin
				work_cyc <= 1'b0;
				work_stb <= 1'b0;
				work_sel <= 4'h0;
				pte <= pte_t'(mdat_i);
			end
		end	
	// This update state should cause an immediate hit on the ATC.
	mmu_state[ST_ATC_UPDATE]:
		begin
			mmu_access <= 1'b0;
			if (pte.p) begin
				atc[atc_ua].pte <= pte;
				atc[atc_ua].vpage <= cadr_i[31:14];
				atc[atc_ua].pid <= pid;
				atc_ua <= atc_ua + 6'd1;
			end
			else begin
				page_fault_o <= 1'b1;
				page_fault_addr <= cadr_i;
			end
		end

	default:	;
	endcase
end

always_ff @(posedge clk_i)
if (rst_i) begin
	mmu_state <= 10'd0;
	mmu_state[ST_WAIT_MISS] <= 1'b1;
end
else begin
	mmu_state <= 10'd0;
	case(1'b1)

	mmu_state[ST_WAIT_MISS]:
		if (!atc_hit_r)
			mmu_state[ST_ACCESS1] <= 1'b1;
		else
			mmu_state[ST_WAIT_MISS] <= 1'b1;

	mmu_state[ST_ACCESS1]:
		if (mack_i)
			mmu_state[ST_ACCESS2] <= 1'b1;
		else
			mmu_state[ST_ACCESS1] <= 1'b1;

	mmu_state[ST_ACCESS2]:
		mmu_state[ST_WAIT_ACK2] <= 1'b1;

	mmu_state[ST_WAIT_ACK2]:
		if (mack_i)
			mmu_state[ST_ATC_UPDATE] <= 1'b1;
		else
			mmu_state[ST_WAIT_ACK2] <= 1'b1;

	mmu_state[ST_ATC_UPDATE]:
		mmu_state[ST_WAIT_MISS] <= 1'b1;
		
	default:
		mmu_state[ST_WAIT_MISS] <= 1'b1;
		
	endcase
end

endmodule

