`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2008-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	rf68000.sv
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
// 10,800 LUTS / 2,560 FFs / 2 DSP (no float, no MMU)                                                                          
// 24k LUTs / 14k FFs / 2 DSPs (with DFP)
// ============================================================================
//
import const_pkg::*;
import rf68851_pkg::*;

// Uncomment the following to optimize for performance. Increases the core size.
//`define OPT_PERF    1'b1
`define BIG_ENDIAN	1'b1

//`define SUPPORT_RETRY	1'b1
`define SUPPORT_MUL	1'b1
`define SUPPORT_DIV	1'b1
`define SUPPORT_BCD	1'b1
`define SUPPORT_010	1'b1
//`define SUPPORT_020 1'b1
`define SUPPORT_PMMU 1'b1
`define SUPPORT_BITPAIRS 1'b1

`define SUPPORT_NANO_CACHE	1'b1

//`define HAS_MMU 1'b1

//`define SUPPORT_TASK	1'b1

//`define SUPPORT_B24	1'b1		// To support 23-bit branch displacements

`define TRUE        1'b1
`define FALSE       1'b0
`define HIGH        1'b1
`define LOW         1'b0

`define RESET_VECTOR	32'h00000400
`define CSR_CORENO    32'hFFFFFFE0
`define CSR_TICK        32'hFFFFFFE4
`define CSR_ICNT				32'hFFFFFFE8
`define CSR_TASK        32'hFFFFFFFC

//`define SSP_VEC       9'd000
`define RESET_VEC       9'd001
`define BUSERR_VEC      9'd002
`define ADDRERR_VEC     9'd003
`define ILLEGAL_VEC     9'd004
`define DBZ_VEC         9'd005
`define CHK_VEC         9'd006
`define TRAPV_VEC       9'd007
`define PRIV_VEC        9'd008
`define TRACE_VEC       9'd009
`define LINE10_VEC      9'd010
`define LINE15_VEC      9'd011
`define FORMAT_VEC			8'd014
`define UNINITINT_VEC   9'd015
// Vectors 24-31 for IRQ's
`define SPURIOUS_VEC		9'd024
`define IRQ_VEC         9'd024
// Vectors 32-46 for TRAPQ instruction
`define TRAP_VEC        9'd032
`define PMMU_ILLOP_VEC	9'd057
`define DISP_VEC				9'd063
`define USER64          9'd064
//`define NMI_TRAP        9'h1FE
`define RESET_TASK      9'h000

`define	LDB		16'b0001_xxx0xx_xxxxxx
`define LDH		16'b0010_xxx0xx_xxxxxx
`define LDW		16'b0011_xxx0xx_xxxxxx
`define	STB		16'b0001_xxx1xx_xxxxxx
`define STH		16'b0010_xxx1xx_xxxxxx
`define STW		16'b0011_xxx1xx_xxxxxx

// DBcc also for Scc
`define DBRA	8'h50
`define DBSR	8'h51
`define DBHI	8'h52
`define DBLS	8'h53
`define DBHS	8'h54
`define DBLO	8'h55
`define DBNE	8'h56
`define DBEQ	8'h57
`define DBVC	8'h58
`define DBVS	8'h59
`define DBPL	8'h5A
`define DBMI	8'h5B
`define DBGE	8'h5C
`define DBLT	8'h5D
`define DBGT	8'h5E
`define DBLE	8'h5F

`define BRA		8'h60
`define BSR		8'h61
`define BHI		8'h62
`define BLS		8'h63
`define BHS		8'h64
`define BLO		8'h65
`define BNE		8'h66
`define BEQ		8'h67
`define BVC		8'h68
`define BVS		8'h69
`define BPL		8'h6A
`define BMI		8'h6B
`define BGE		8'h6C
`define BLT		8'h6D
`define BGT		8'h6E
`define BLE		8'h6F

// 12000 LUTs / 80MHz
// slices
// 1600 FF's
// 2 MULTS
// 8 BRAMs

module rf68000(coreno_i, clken_i, rst_i, rst_o, clk_i, dfclk_i, nmi_i, ipl_i, vpa_i, vpa2_i,
	cmd_o, lock_o, cyc_o, stb_o, ack_i, err_i, rty_i, we_o, sel_o, fc_o, dt_i, trace_o,
	asid_o, mmus_o, ios_o, iops_o, adr_o, dat_i, dat_o);
parameter SUPPORT_DECFLT = 1'b1;
parameter SUPPORT_BINFLT = 1'b0;
parameter SUPPORT_PMMU = 1'b0;
parameter SUPPORT_68020 = 1'b0;
parameter IOPS_ADDR = 32'hFDE00000;
parameter MMU_ADDR = 32'hFDC00000;

typedef struct packed
{
	logic ack;
	logic [1:0] resv;
	logic err;
	logic priverr;
	logic vpa;
	logic vpa2;
	logic rty;
} bus_stat_t;

typedef enum logic [9:0] {
	IFETCH = 10'd1,
	DECODE,
	RETSTATE,
	FETCH_BYTE,
	FETCH_WORD,
	FETCH_LWORD,
	FETCH_LWORDa,
	STORE_BYTE,
	USTORE_BYTE,
	// 10
	STORE_WORD,
	STORE_LWORD,
	STORE_LWORDa,

	LFETCH_BYTE,
	FETCH_BRDISP,
	FETCH_BRDISPa,
	FETCH_IMM16,
	FETCH_IMM16a,
	FETCH_IMM32,
	FETCH_IMM32a,

	// 20
	FETCH_IMM32b,
	JSR,
	JMP,
	DBRA,
	
	ADDQ,
	ADDQ2,
	ADDI,
	ADDI2,
	ADDI3,
	ADDI4,
	
	// 30
	ADD,
	ADD1,
	
	DIV1,
	DIV2,

	STORE_IN_DEST,
	SHIFT,
	SHIFT1,
	BIT,
	BIT1,
	BIT2,
	
	// 40
	RTD1,
	RTD2,
	
	RTE1,
	RTE2,
	RTE3,
	RTE4,
	RTE5,
	RTE6,
	RTE7,
	RTE8,
	
	// 50
	RTE9,
	RTE10,
	RTE11,

	RTS1,
	RTS2,
	
	LINK,
	LINK1,
	LINK2,
	UNLNK,
	UNLNK2,
	
	// 60
	JMP_VECTOR,
	JMP_VECTOR2,
	JMP_VECTOR3,
	
	NEG,
	NEGX,
	NEGX1,
	NOT,
	TAS,
	LEA,
	LEA2,
	
	//70
	EXG1,

	CMP,
	CMP1,
	CMPA,
	CMPM,
	CMPM1,	// defunct

	AND,
	AND1,
	EOR,
	ANDI_CCR,
	
	// 80
	ANDI_CCR2,
	ANDI_SR,
	ANDI_SRX,
	EORI_CCR,
	EORI_CCR2,
	EORI_SR,
	EORI_SRX,
	ORI_CCR,
	ORI_CCR2,
	ORI_SR,

	//90
	ORI_SRX,
	FETCH_NOP_BYTE,
	FETCH_NOP_WORD,
	FETCH_NOP_LWORD,
	FETCH_IMM8,
	FETCH_IMM8a,
	FETCH_D32,
	FETCH_D32a,
	FETCH_D32b,
	FETCH_D16,
	
	//100
	FETCH_D16a,
	FETCH_NDX,
	FETCH_NDXa,
	
	MOVE2CCR,
	MOVE2SR,
	MOVE2SRX,

	TRAP,
	TRAP3,
	TRAP3a,
	TRAP3b,
	
	//110
	TRAP4,
	TRAP5,
	TRAP6,
	TRAP7,
	TRAP7a,
	TRAP8,
	TRAP9,
	TRAP10,
	TRAP20,
	TRAP21,
	
	// 120
	TRAP22,
	TRAP23,
	TRAP24,
	TRAP25,
	TRAP26,
	INTA,
	
	RETRY,
	RETRY2,

	TST,
	MUL,
	
	// 130
	MUL1,
	STOP,
	STOP1,
	RESET,
	RESET2,
	RESET3,
	RESET4,
	RESET5,
	PEA1,
	PEA2,
	
	// 140
	PEA3,
	BCD,
	BCD0,
	BCD1,
	BCD2,
	BCD3,
	BCD4,
	OR,
	
	INT,
	INT2,
	
	// 150
	INT3,
	INT4,

	MOVEM_Xn2D,
	MOVEM_Xn2D2,
	MOVEM_Xn2D3,
	MOVEM_Xn2D4,
	MOVEM_s2Xn,
	MOVEM_s2Xn2,
	MOVEM_s2Xn3,
	
	TASK1,

	// 160
	THREAD2,
	TASK3,
	TASK4,
	
	LDT1,
	LDT2,
	LDT3,
	SDT1,
	SDT2,
	
	SUB,
	SUB1,
	
	// 170
	MOVEP,
	MOVEP1,
	MOVEP2,
	MOVEP3,
	CHK,
	
	MOVERc2Rn,
	MOVERn2Rc,
	MOVERn2Rc2,

	MOVES,
	MOVES2,
	
	// 180
	MOVES3,

	ADDX,
	ADDX2,
	ADDX3,
	SUBX,
	SUBX2,
	SUBX3,

	MULU1,
	MULU2,
	MULU3,

	//190	
	MULS1,
	MULS2,
	MULS3,
	
	BIN2BCD1,
	BIN2BCD2,
	BCD2BIN1,
	BCD2BIN2,
	BCD2BIN3,

	IFETCH2,
	FADD,
	FADD1,

	// 201
	FCMP,
	FCMP1,
	FCVTI1,
	FCVTI2,

	FMUL,
	FMUL1,
	FMUL2,
	FDIV,
	FDIV1,
	// 210
	FDIV2,
	FDIV3,
	FNEG,
	FNEG1,
	FMOVE,
	FMOVE1,
	I2DF1,
	I2DF2,
	DF2I1,
	DF2I2,
	// 220
	FTST,
	FTST1,
	FBCC,
	FSCALE,
	FSCALE1,
	FCOPYEXP,
	FINTRZ,
	FINTRZ1,

	FETCH_HEXI1,
	FETCH_HEXI2,
	// 230
	FETCH_HEXI3,
	FETCH_HEXI4,
	FETCH_NOP_HEXI,
	STORE_HEXI1,
	STORE_HEXI2,
	STORE_HEXI3,
	STORE_HEXI4,

	FMOVEM1,

	FETCH_IMM96,
	FETCH_IMM96b,
	// 240
	FETCH_IMM96c,
	FETCH_IMM96d,
	
	CCHK,
	
	FSDATA2,
	
	FETCH_OCTA,
	FETCH_OCTA1,
	FETCH_OCTA2,
	FETCH_NOP_OCTA,

	STORE_OCTA,
	STORE_OCTA1,
	// 250
	STORE_OCTA2,
	
	FETCH_IMM64,
	FETCH_IMM64b,
	FETCH_IMM64c,
	
	WAIT_NACK,
	
	PBCC,
	PDBCC,
	PDBCC1,
	PFLUSH,
	PFLUSH1,
	// 260
	PFLUSH2,
	PFLUSH3,
	PMOVE1,
	PMOVE2,
	PMOVE3,
	PSAVE,
	PSAVE1,
	PSAVE2,
	PRESTORE,
	PRESTORE1,
	// 270
	PRESTORE2,
	PSCC,
	STORE_NOP_BYTE,
	PTRAPCC,
	PTRAPCC1,
	PVALID,
	PVALID1,
	PLOAD,
	PTEST,
	PTEST1,
	// 280
	STORE_LWORD2,
	STORE_BYTE_ACK,
	USTORE_BYTE_ACK,
	STORE_WORD_ACK,
	STORE_LWORDa_ACK,
	INTA_ACK,
	FETCH_BYTE_ACK,
	LFETCH_BYTE_ACK,
	FETCH_WORD_ACK,
	FETCH_LWORD_ACK,
	// 290
	FETCH_LWORDa_ACK,
	FETCH_D16_ACK,
	FETCH_D32_ACK,
	FETCH_D32a_ACK,
	FETCH_NDX_ACK,
	FETCH_IMM8_ACK,
	FETCH_IMM16_ACK,
	FETCH_IMM32_ACK,
	FETCH_IMM32a_ACK,
	FETCH_BRDISP_ACK,
	// 300
	BREAKPOINT,
	BREAKPOINT_ACK,
	IFETCH_ACK,
	
	FETCH_NDXb,
	FETCH_NDXc,
	FETCH_NDXd,
	FETCH_NDXe,
	FETCH_NDXf,
	FETCH_NDXg,
	FETCH_NDXh,
	// 310
	FETCH_NDXi,
	BITFLD,
	BITFLD_UPDATE,
	FETCH_BRDISP32,
	MOVEP1_ACK,
	MOVEP2_ACK,
	MOVEP3_ACK,
	FETCH_QLW1,		// Quinta-long-word
	FETCH_QLW2,
	FETCH_QLW3,
	// 320
	FETCH_QLW4,
	FETCH_QLW5,
	FETCH_QLW6,
	STORE_QLW1,		// Quinta-long-word
	STORE_QLW2,
	STORE_QLW3,
	STORE_QLW4,
	STORE_QLW5,
	CALLM,
	// 330
	CALLM1,
	CALLM2,
	CALLM3,
	CALLM4,
	CALLM5,
	CALLM6,
	CALLM7,
	CALLM8,
	CALLM9,
	// 340
	CALLM10,
	CALLM11,
	CALLM12,
	CALLM13,
	CAS,
	CAS1,
	CAS2,
	CAS3,
	CAS4,
	// 350
	CASO,
	CASO1,
	CASO2,
	CASO3,
	CASO4,
	CASO5,
	CASO6,
	CHK2
} state_t;

typedef enum logic [4:0] {
	FU_NONE = 5'd0,
	FU_MUL,
	FU_TST, FU_ADDX, FU_SUBX,
	FU_CMP, FU_ADD, FU_SUB, FU_LOGIC, FU_ADDQ, FU_SUBQ,
	FU_ADDI, FU_ANDI_CCR, FU_ANDI_SR, FU_EORI_CCR,
	FU_ANDI_SRX, FU_EORI_SRX, FU_ORI_SRX, FU_MOVE2SRX,
	FU_EORI_SR, FU_ORI_CCR, FU_ORI_SR, FU_MOVE2CCR,
	FU_MOVE2SR
} flag_update_t;
typedef enum logic [4:0] {
	CMD_NONE = 5'd0,
	CMD_RD,
	CMD_WR,
	CMD_LOCK,
	CMD_UNLOCK
} cmd_e;

parameter S = 1'b0;
parameter D = 1'b1;

input [31:0] coreno_i;
input clken_i;
input rst_i;
output reg rst_o;
input clk_i;
input dfclk_i;
input nmi_i;
input vpa_i;
input vpa2_i;
input [2:0] ipl_i;
output lock_o;
reg lock_o;
output reg [4:0] cmd_o;
output cyc_o;
reg cyc_o;
output stb_o;
reg stb_o;
input ack_i;
input err_i;
input rty_i;
output we_o;
reg we_o;
output [3:0] sel_o;
reg [3:0] sel_o;
output [2:0] fc_o;
reg [2:0] fc_o;
output [7:0] asid_o;
output mmus_o;
output ios_o;
output iops_o;
output reg [31:0] adr_o;
input [31:0] dat_i;
output reg [31:0] dat_o;
input dt_i;
output reg [31:0] trace_o;


bus_stat_t bus_stat;
reg em;							// emulation mode
reg rext=1'b0,rext2=1'b0;
reg [15:0] ir;
reg [15:0] ir2;			// second word for ir
`ifdef SUPPORT_NANO_CACHE
reg [15:0] fetchbuf [0:7];
reg [31:0] fetchbuf_tag [0:7];
`endif
reg ext_ir;
reg [31:0] icnt;
(* fsm_encoding="none" *)
state_t state, prev_state;
always_ff @(posedge clk_i)
	prev_state <= state;
state_t rstate;
state_t state_stk1;
state_t state_stk2;
state_t state_stk3;
state_t state_stk4;
state_t state_stk5;
state_t state_stk6;
state_t sz_state;
flag_update_t flag_update;
reg [63:0] d0 = 'd0;
reg [63:0] d1 = 'd0;
reg [63:0] d2 = 'd0;
reg [63:0] d3 = 'd0;
reg [63:0] d4 = 'd0;
reg [63:0] d5 = 'd0;
reg [63:0] d6 = 'd0;
reg [63:0] d7 = 'd0;
reg [63:0] a0 = 'd0;
reg [63:0] a1 = 'd0;
reg [63:0] a2 = 'd0;
reg [63:0] a3 = 'd0;
reg [63:0] a4 = 'd0;
reg [63:0] a5 = 'd0;
reg [63:0] a6 = 'd0;
reg [63:0] sp = 'd0;

reg [95:0] fp0 = 'd0;
reg [95:0] fp1 = 'd0;
reg [95:0] fp2 = 'd0;
reg [95:0] fp3 = 'd0;
reg [95:0] fp4 = 'd0;
reg [95:0] fp5 = 'd0;
reg [95:0] fp6 = 'd0;
reg [95:0] fp7 = 'd0;
reg [31:0] d0i;
reg [31:0] d1i;
reg [31:0] d2i;
reg [31:0] d3i;
reg [31:0] d4i;
reg [31:0] d5i;
reg [31:0] d6i;
reg [31:0] d7i;
reg [31:0] a0i;
reg [31:0] a1i;
reg [31:0] a2i;
reg [31:0] a3i;
reg [31:0] a4i;
reg [31:0] a5i;
reg [31:0] a6i;
reg [31:0] spi;
reg [31:0] flagsi;
reg [31:0] pci;
wire [31:0] d0o;
wire [31:0] d1o;
wire [31:0] d2o;
wire [31:0] d3o;
wire [31:0] d4o;
wire [31:0] d5o;
wire [31:0] d6o;
wire [31:0] d7o;
wire [31:0] a0o;
wire [31:0] a1o;
wire [31:0] a2o;
wire [31:0] a3o;
wire [31:0] a4o;
wire [31:0] a5o;
wire [31:0] a6o;
wire [31:0] spo;
wire [31:0] flagso;
wire [31:0] pco;
function [63:0] fnReg;
input [6:0] rg;
begin
	case(rg)
	4'd0:	fnReg = d0;
	4'd1:	fnReg = d1;
	4'd2:	fnReg = d2;
	4'd3:	fnReg = d3;
	4'd4:	fnReg = d4;
	4'd5:	fnReg = d5;
	4'd6:	fnReg = d6;
	4'd7:	fnReg = d7;
	4'd8:	fnReg = a0;
	4'd9:	fnReg = a1;
	4'd10:	fnReg = a2;
	4'd11:	fnReg = a3;
	4'd12:	fnReg = a4;
	4'd13:	fnReg = a5;
	4'd14:	fnReg = a6;
	4'd15:	fnReg = sp;
	endcase
end
endfunction
// PMMU registers
integer pn5,pn6;
reg pmmu_en;
reg [4:0] pmmu_log_pagesize = 5'd13;
reg [4:0] pmmu_adrbits_consumed = pmmu_log_pagesize - 2'd2;
reg [2:0] pmmu_table_depth;
reg [63:0] pmmu_locked;
wire [6:0] pmmu_lock_cnt;
reg pmmu_lock_warning;
always_comb
	foreach (pmmu_locked[pn5])
		pmmu_locked[pn5] <= atc[pn5].desc.l;
cntpop64 (.i(pmmu_locked), .o(pmmu_lock_cnt));
always_comb
	pmmu_lock_warning = &pmmu_lock_cnt[5:0];

always_comb
	case(pmmu_log_pagesize)
	5'd0:	pmmu_table_depth = 4;
	5'd1:	pmmu_table_depth = 4;
	5'd2:	pmmu_table_depth = 4;
	5'd3:	pmmu_table_depth = 4;
	5'd4:	pmmu_table_depth = 4;
	5'd5:	pmmu_table_depth = 4;
	5'd6:	pmmu_table_depth = 4;
	5'd7:	pmmu_table_depth = 4;
	5'd8:	pmmu_table_depth = 4;
	5'd9:	pmmu_table_depth = 4;
	5'd10:	pmmu_table_depth = 3;
	5'd11:	pmmu_table_depth = 3;
	5'd12:	pmmu_table_depth = 2;
	5'd13:	pmmu_table_depth = 2;
	5'd14:	pmmu_table_depth = 2;
	5'd15:	pmmu_table_depth = 2;
	5'd16:	pmmu_table_depth = 2;
	default:	pmmu_table_depth = 1;
	endcase
reg [4:0] pmmu_table_level;
reg [31:0] pmmu_pmask;
pmmu_stat_t pmmu_sr;	// status reg
reg [2:0] pmmu_ta;
wire [15:0] pmmu_csr = {1'd0,pmmu_lock_warning,11'd0,pmmu_ta};	// cache status reg
pmmu_trans_ctrl_t pmmu_tc = 32'h0;
always_comb pmmu_en = pmmu_tc.E;
reg [2:0] pmmu_fc;
reg [7:0] pmmu_scc;
reg [7:0] pmmu_cal;
reg [7:0] pmmu_val;
pmmu_acr_t pmmu_acr;
reg [31:0] pmmu_ptest_adr;
reg [31:0] pmmu_amask;
always_comb
	pmmu_amask = ~((32'd1 << (pmmu_acr.ALC + 8'd24)) - 2'd1);
LFT_desc_t pmmu_cpu_root;
LFT_desc_t pmmu_dma_root;
LFT_desc_t pmmu_sys_root;
LFT_desc_t [7:0] pmmu_rpt;
reg [2:0] pmmu_flush_ta;
reg pmmu_rpt_found;
reg [2:0] pmmu_rpt_out;
reg [7:0] pmmu_rpt_in_use;
integer pn1,pn2;
reg [1:0] pmmu_rpt_state;
reg [1:0] pmmu_flush_cmd;
reg [2:0] pmmu_ptest_lvl;
always_ff @(posedge clk_i)
if (rst_i) begin
	pmmu_rpt_in_use <= 8'h00;
	pmmu_rpt_out <= 3'd0;
	pmmu_rpt_state <= 2'd0;
	foreach (pmmu_rpt[pn1])
		pmmu_rpt[pn1] <= {$bits(LFT_desc_t){1'b0}};
end
else begin
	case(pmmu_rpt_state)
	2'd0:
		begin
			pmmu_rpt_found <= FALSE;
			if (&pmmu_rpt_in_use)
				pmmu_rpt_state <= 2'd1;
			else
				pmmu_rpt_state <= 2'd2;
			for (pn1 = 0; pn1 < 8; pn1 = pn1 + 1)
				if (pmmu_rpt[pn1]==pmmu_cpu_root) begin
					pmmu_ta <= pn1;
					pmmu_rpt_found <= TRUE;
					pmmu_rpt_state <= 2'd0;
					break;
				end
		end
	2'd1:
		begin
			pmmu_flush_ta <= pmmu_rpt_out;
			pmmu_rpt[pmmu_rpt_out] <= pmmu_cpu_root;
			pmmu_rpt_out <= pmmu_rpt_out + 1;
		end
	// No need to flush if there are available RPT entries.
	2'd2:
		begin
			pmmu_rpt_in_use[pmmu_rpt_out] <= 1'b1;
			pmmu_rpt[pmmu_rpt_out] <= pmmu_cpu_root;
			pmmu_rpt_out <= pmmu_rpt_out + 1;
		end
	default:	pmmu_rpt_state <= 2'd0;
	endcase
end

reg [5:0] pmmu_cond;
reg [15:0] pmmu_bad [0:7];
pmmu_bac_t [7:0] pmmu_bac;
reg [7:0] pmmu_bpe;
reg pmmu_any_bpe;
always_comb
	foreach(pmmu_bpe[pn6])
		pmmu_bpe[pn6] = pmmu_bac[pn6];
always_comb
	pmmu_any_bpe = |pmmu_bpe;
wire [7:0] pmmu_version = 8'hC0;
reg [7:0] pmmu_format;
reg [31:0] pmmu_smask;
wire [5:0] pmmu_flo;
reg [31:0] padr_ignore;
reg [3:0] pmmu_offs;
reg [3:0] pmmu_Ashift;
reg [3:0] pmmu_Bshift;
reg [3:0] pmmu_Cshift;
reg [3:0] pmmu_Dshift;
reg [4:0] pmmu_ABCDP;
reg [4:0] pmmu_BCDP;
reg [4:0] pmmu_CDP;
reg [4:0] pmmu_DP;
reg [4:0] pmmu_P;
reg [31:0] pmmu_Amask;
reg [31:0] pmmu_Bmask;
reg [31:0] pmmu_Cmask;
reg [31:0] pmmu_Dmask;
reg [31:0] pmmu_index_ABCDP;
reg [31:0] pmmu_index_BCDP;
reg [31:0] pmmu_index_CDP;
reg [31:0] pmmu_index_DP;
reg [31:0] padr;
// Precalc for PMMU
always_ff @(posedge clk_i)
	padr_ignore <= 32'hFFFFFFFF >> pmmu_tc.IS;
always_ff @(posedge clk_i)
	pmmu_Amask <= (32'd1 << pmmu_tc.A) - 2'd1;
always_ff @(posedge clk_i)
	pmmu_Bmask <= (32'd1 << pmmu_tc.B) - 2'd1;
always_ff @(posedge clk_i)
	pmmu_Cmask <= (32'd1 << pmmu_tc.C) - 2'd1;
always_ff @(posedge clk_i)
	pmmu_Dmask <= (32'd1 << pmmu_tc.D) - 2'd1;
always_ff @(posedge clk_i)
	pmmu_Ashift <= (pmmu_tc.PS-pmmu_tc.A);
always_ff @(posedge clk_i)
	pmmu_Bshift <= (pmmu_tc.PS-pmmu_tc.B);
always_ff @(posedge clk_i)
	pmmu_Cshift <= (pmmu_tc.PS-pmmu_tc.C);
always_ff @(posedge clk_i)
	pmmu_Dshift <= (pmmu_tc.PS-pmmu_tc.D);
always_ff @(posedge clk_i)
	pmmu_pmask <= (32'd1 << pmmu_tc.PS) - 2'd1;
always_ff @(posedge clk_i)
	pmmu_ABCDP <= pmmu_tc.A + pmmu_tc.B + pmmu_tc.C + pmmu_tc.D + pmmu_tc.PS;
always_ff @(posedge clk_i)
	pmmu_BCDP <= pmmu_tc.B + pmmu_tc.C + pmmu_tc.D + pmmu_tc.PS;
always_ff @(posedge clk_i)
	pmmu_CDP <= pmmu_tc.C + pmmu_tc.D + pmmu_tc.PS;
always_ff @(posedge clk_i)
	pmmu_DP <= pmmu_tc.D + pmmu_tc.PS;
always_ff @(posedge clk_i)
	pmmu_P <= pmmu_tc.PS;
always_comb
	pmmu_index_ABCDP = (padr >> pmmu_ABCDP) & pmmu_Amask;
always_comb
	pmmu_index_BCDP = (padr >> pmmu_BCDP) & pmmu_Bmask;
always_comb
	pmmu_index_CDP = (padr >> pmmu_CDP) & pmmu_Cmask;
always_comb
	pmmu_index_DP = (padr >> pmmu_DP) & pmmu_Dmask;

atc_entry_t [63:0] atc;
reg [63:0] desc = 64'd0;
SFT_desc_t sft_desc;
LFT_desc_t lft_desc;
LF2P_desc_t lf2p_desc;
always_comb
	lft_desc = LFT_desc_t'(desc);
pmmu_desc_t prev_desc_type;
reg [5:0] atc_ua = 6'd0;
reg atc_hit, atc_err;
reg [15:0] appid;
integer n3;
reg [2:0] pfc_o;
reg pcyc_o;
reg pstb_o;
reg pwe_o;
reg [3:0] psel_o;
reg [31:0] padr_o;
always_comb
	padr = padr_o & padr_ignore;
reg [31:0] pdat_o;
reg pmmu_access;
wire [19:0] pmmu_state;
reg [2:0] work_fc;
reg work_cyc;
reg work_stb;
reg work_we;
reg [3:0] work_sel;
reg [31:0] work_adr;
reg [31:0] work_dat;
reg page_fault;
reg [31:0] page_fault_adr; 
reg pload, ptest=1'b0;

reg [15:0] pid_stack [0:15];
reg [3:0] pid_sp;
reg cf,vf,nf,zf,xf,sf,tf;
reg movemf;
reg [2:0] im;
reg [2:0] ccr57;
reg [1:0] sr1112;
reg sr14;
wire [15:0] sr = {tf,sr14,sf,sr1112,im,ccr57,xf,nf,zf,vf,cf};
wire [31:0] srx = {sr};
reg fnf,fzf,fvf,fnanf;
wire finff = fvf;
reg [7:0] quotient_bits;
reg [2:0] quotient_bitshi;
reg [7:0] fpexc,fpaexc;
wire [31:0] fpsr = {1'b0,quotient_bitshi,fnf,fzf,fvf,fnanf,quotient_bits,fpexc,fpaexc};
reg [31:0] isr;
reg [3:0] ifmt;
reg [11:0] fpcnt;
reg [31:0] pc;
reg [31:0] opc;			// pc for branch references
reg [31:0] fpiar;
reg [31:0] ssp,usp;
reg [31:0] disp;
reg [31:0] s,d,dd,imm,immx;
reg [31:0] bit2test;
reg wl;
reg ds;
reg [5:0] cnt;				// shift count
reg [31:0] ea;				// effective address
reg [31:0] vector;
reg [7:0] vecno;
reg [5:0] Rt;
wire [1:0] sz = ir[7:6];
reg dsix;
reg [2:0] mmm,mmmx,mmm_save='d0;
reg [2:0] rrr,rrrx;
reg [3:0] rrrr;
// Extension word fields
reg [31:0] base_reg;
reg [31:0] index_reg;
reg [31:0] base_disp;
reg [31:0] outer_disp;
reg [2:0] iis;
reg [1:0] bdsz;
reg index_suppress;
reg base_suppress;
reg xword_format;
reg [1:0] scale;

wire [2:0] MMM = ir[8:6];
wire [2:0] RRR = ir[11:9];
wire [2:0] QQQ = ir[11:9];
wire [2:0] DDD = ir[11:9];
wire [2:0] AAA = ir[11:9];
reg [10:0] tracendx,tracendx2;
reg [31:0] tracebuf [0:2047];

reg [2:0] FLTSRC;
reg [2:0] FLTDST;
reg MMMRRR;
wire Anabit;
wire [31:0] sp_dec = sp - 32'd2;
wire [63:0] rfoAn;
/*
always_comb
	rfoAn = fnReg({1'b1,rrr});
*/
wire [63:0] rfoAna;
/*
always_comb
	rfoAna = fnReg({1'b1,AAA});
*/
//wire [31:0] rfoAn =	rrr==3'b111 ? sp : regfile[{1'b1,rrr}];
wire [63:0] rfoDn;
/*
always_comb
	rfoDn = fnReg({1'b0,DDD});
*/
wire [63:0] rfoDnn;
/*
always_comb
	rfoDnn = fnReg({1'b0,rrr});
*/
// For bitfield
integer bf1;
state_t bf_size;
reg [5:0] bfwidth,bfoffs;
reg [31:0] bfdat;
reg [63:0] bfmask;
reg [1:0] bfcmd;
function [5:0] fnBfow;
input [5:0] fld;
begin
case(fld)
6'b100000:	fnBfow = {d0[4:0]==5'd0,d0[4:0]};
6'b100001:	fnBfow = {d1[4:0]==5'd0,d1[4:0]};
6'b100010:	fnBfow = {d2[4:0]==5'd0,d2[4:0]};
6'b100011:	fnBfow = {d3[4:0]==5'd0,d3[4:0]};
6'b100100:	fnBfow = {d4[4:0]==5'd0,d4[4:0]};
6'b100101:	fnBfow = {d5[4:0]==5'd0,d5[4:0]};
6'b100110:	fnBfow = {d6[4:0]==5'd0,d6[4:0]};
6'b100111:	fnBfow = {d7[4:0]==5'd0,d7[4:0]};
6'b0?????:	fnBfow = {fld[4:0]==5'd0,fld[4:0]};
default:	fnBfow = 6'd0;
endcase
end
endfunction
function [31:0] fnBfdat;
input [2:0] fld;
begin
	fnBfdat = fnReg({1'b0,fld});
end
endfunction

wire [63:0] rfob;
/*
always_comb
	rfob = fnReg({mmm[0],rrr});
*/
wire [63:0] rfoRnn;
/*
always_comb
	rfoRnn = fnReg(rrrr);
*/
reg rfwrL,rfwrB,rfwrW,rfwrX=1'b0;
reg [8:0] resB;
reg [16:0] resW;
reg [32:0] resL;
reg [64:0] resX;
reg [2:0] Xnx=3'd0,Rnx=3'd0,Nnx=3'd0;

regfile urgfile1
(
	.clk(clk_i),
	.wrb(rfwrB),
	.wrw(rfwrW),
	.wrl(rfwrL),
	.wrx(rfwrX),
	.wa(Rt),
	.i(rfwrB ? resB[7:0] : rfwrW ? resW[15:0] : rfwrL ? resL[31:0] : resX[63:0]),
	.ra0(|Xnx ? {Xnx,rrr} : {3'b001,rrr}), 
	.ra1(|Rnx ? {Rnx,AAA} : {3'b001,AAA}),
	.ra2(|Rnx ? {Rnx,DDD} : {3'b000,DDD}),
	.ra3(|Xnx ? {XnX,rrr} : {3'b000,rrr}),
	.ra4(|Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr}),
	.ra5(|Xnx ? {Xnx,rrr} : {2'b00,rrrr}),
	.ra6(6'd0),
	.o0(rfoAn),
	.o1(rfoAna),
	.o2(rfoDn),
	.o3(rfoDnn),
	.o4(rfob),
	.o5(rfoRnn),
	.o6()
);

reg [95:0] rfoFpdst, rfoFpsrc;
generate begin : gFLTSrcDst
if (SUPPORT_DECFLT) begin
always_comb
case(FLTDST)
3'd0:   rfoFpdst <= fp0;
3'd1:   rfoFpdst <= fp1;
3'd2:   rfoFpdst <= fp2;
3'd3:   rfoFpdst <= fp3;
3'd4:   rfoFpdst <= fp4;
3'd5:   rfoFpdst <= fp5;
3'd6:   rfoFpdst <= fp6;
3'd7:   rfoFpdst <= fp7;
endcase
always_comb
case(FLTSRC)
3'd0:   rfoFpsrc <= fp0;
3'd1:   rfoFpsrc <= fp1;
3'd2:   rfoFpsrc <= fp2;
3'd3:   rfoFpsrc <= fp3;
3'd4:   rfoFpsrc <= fp4;
3'd5:   rfoFpsrc <= fp5;
3'd6:   rfoFpsrc <= fp6;
3'd7:   rfoFpsrc <= fp7;
endcase
end
end
endgenerate

//wire [31:0] rfoDn = regfile[{1'b0,DDD}];
//wire [31:0] rfoAna = AAA==3'b111 ? sp : regfile[{1'b1,AAA}];
//wire [31:0] rfob = {mmm[0],rrr}==4'b1111 ? sp : regfile[{mmm[0],rrr}];
//wire [31:0] rfoDnn = regfile[{1'b0,rrr}];
//wire [31:0] rfoRnn = rrrr==4'b1111 ? sp : regfile[rrrr];
reg rfwrF;
reg takb, ftakb, ptakb;
reg [95:0] resF;
reg [95:0] fps, fpd;
(* USE_DSP = "no" *)
reg [32:0] resL1,resL2;
reg [32:0] resMS1,resMS2,resMU1,resMU2;
reg [31:0] st_data;
wire [11:0] bcdaddo,bcdsubo,bcdnego;
wire bcdaddoc,bcdsuboc,bcdnegoc;
reg [31:0] bad_addr;
reg [15:0] mac_cycle_type;
reg prev_nmi;
reg pe_nmi;
reg is_nmi;
reg is_irq, is_trace, is_priv, is_illegal, is_format, is_page_fault;
reg is_adr_err;
reg is_rst;
reg is_bus_err;
reg is_vpa2;
reg use_dfc, use_sfc;
// The following flag indicates a valid unlink operation. The state machine was
// transitioning to the UNLNK2 state as a runt state. Hopefully this flags
// ensures the UNLNK2 state is not executed if it is a runt.
reg dec_unlink;
reg [4:0] rst_cnt;
reg [2:0] shift_op;
reg rtr;
reg bsr;
reg lea;
reg fsub,fabs;
reg bcdsub, bcdneg;
reg fmovem;
reg [31:0] dati_buf;	// input data from bus error
reg [31:0] dato_buf;
reg [2:0] ie_cntdwn;
reg [2:0] ie_val;

// CSR's
reg [31:0] tick;	// FF0
reg [7:0] asid;		// 003
assign asid_o = asid;
reg [31:0] vbr;		// 801
reg [31:0] sfc;		// 000
reg [31:0] dfc;		// 001
reg [31:0] apc;
reg [7:0] cpl;
reg [31:0] tr;
reg [15:0] cpid;
wire [15:0] npid = pid_stack[pid_sp+4'd1];
reg [31:0] tcba;
reg [31:0] mmus, ios, iops;
reg [31:0] canary;
assign mmus_o = adr_o[31:20] == mmus[31:20];
assign iops_o = adr_o[31:16] == iops[31:16];
assign ios_o  = adr_o[31:24] == ios [31:24] || adr_o[31:24]==8'hF0;
wire pe_dt;
integer n,n1,n2;

initial begin
	for (n1 = 0; n1 < 2048; n1 = n1 + 1)
		tracebuf[n1] = 32'd0;
end

edge_det udted1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(dt_i), .pe(pe_dt), .ne(), .ee());


wire [16:0] lfsr_o;
lfsr17 ulfsr1
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

/*
reg [31:0] cache_tag [0:7];
reg [15:0] cache_dat [0:7];

task tPushCache;
input [31:0] adr;
input [15:0] dat;
integer n;
begin
	for (n = 1; n < 8; n = n + 1) begin
		cache_tag[n] <= cache_tag[n-1];
		cache_dat[n] <= cache_dat[n-1];
	end
	cache_tag[0] <= adr;
	cache_dat[0] <= dat;
end
endtask

function fnInCache;
input [31:0] adr;
integer n;
begin
	fnInCache = 1'b0;
	for (n = 0; n < 8; n = n + 1) begin
		if (cache_tag[n]==adr) begin
			fnInCache = 1'b1;		
	end
end
endfunction

task tFindInCache;
input [31:0] adr;
output [15:0] dat;
integer n;
begin
	dat = 16'h4E71;	// NOP
	for (n = 0; n < 8; n = n + 1) begin
		if (cache_tag[n]==adr) begin
			dat = cache_dat[n];
		end
	end
end
endtask
*/

function [31:0] rbo;
input [31:0] w;
rbo = {w[7:0],w[15:8],w[23:16],w[31:24]};
endfunction

wire [7:0] dbin, sbin;
reg [9:0] bcdres;
wire dd_done;
wire [11:0] bcdreso;
BCDToBin ub2b1 (clk_i, d, dbin);
BCDToBin ub2b2 (clk_i, s, sbin);

DDBinToBCD #(.WID(10)) udd1
(
	.rst(rst_i),
	.clk(clk_i),
	.ld(state==BCD3),
	.bin(bcdres),
	.bcd(bcdreso),
	.done(dd_done)
);

reg [31:0] dd32in;
wire [39:0] dd32out;
wire dd32done;
DDBinToBCD #(.WID(32)) udd2
(
	.rst(rst_i),
	.clk(clk_i),
	.ld(state==BIN2BCD1),
	.bin(dd32in),
	.bcd(dd32out),
	.done(dd32done)
);

/*
BCDAdd u1
(
	.ci(xf),
	.a(s[7:0]),
	.b(d[7:0]),
	.o(bcdaddo),
	.c(bcdaddoc)
);


BCDSub u2
(
	.ci(xf),
	.a(d[7:0]),
	.b(s[7:0]),
	.o(bcdsubo),
	.c(bcdsuboc)
);

BCDSub u3
(
	.ci(xf),
	.a(8'h00),
	.b(d[7:0]),
	.o(bcdnego),
	.c(bcdnegoc)
);
*/
// These functions take the MSBs of the operands and results and return an
// overflow status.

// If the signs of the operands are the same, and the sign of the result does
// not match the operands sign.
function fnAddOverflow;
input r;
input a;
input b;
	fnAddOverflow = (r ^ b) & (1'b1 ^ a ^ b);
endfunction

// If the signs of the operands are different and sign of the result does not
// match the first operand.
function fnSubOverflow;
input r;
input a;
input b;
	fnSubOverflow = (r ^ a) & (a ^ b);
endfunction

reg divs;
wire dvdone;
wire dvByZr;
wire dvovf;
wire [31:0] divq;
wire [31:0] divr;

rf68000_divider udiv1
(
	.rst(rst_i),
	.clk(clk_i),
	.ld(state==DIV1),
	.abort(1'b0),
	.sgn(divs),
	.sgnus(1'b0),
	.a(d),
	.b(divs? {{16{s[15]}},s[15:0]}:{16'd0,s[15:0]}),
	.qo(divq),
	.ro(divr),
	.dvByZr(dvByZr),
	.ovf(dvovf),
	.done(dvdone),
	.idle()
);

reg [95:0] dfaddsubo, dfmulo, dfdivo, i2dfo, df2io;
reg [95:0] dfscaleo, dftrunco;
wire [95:0] dfaddsubo1, dfmulo1, dfdivo1, i2dfo1, df2io1;
wire [95:0] dfscaleo1, dftrunco1;
reg dfmulinf;
reg dfmuldone, dfmulover, dfmulunder;
reg dfdivdone, dfdivover, dfdivunder;
wire dfmulinf1;
wire dfmuldone1, dfmulover1, dfmulunder1;
wire dfdivdone1, dfdivover1, dfdivunder1;
wire [11:0] dfcmpo;
reg i2dfdone, df2idone;
wire i2dfdone1, df2idone1;
reg df2iover;
wire df2iover1;
wire [95:0] dfp32To96;
wire [95:0] dfp64To96;
wire [63:0] dfp96To64o;
wire [31:0] dfp96To32o;
reg [95:0] dfpss1;

//DFP96U fpsu, fpdu;
//DFP96 fpdp;

reg [3:0] dfscnt;

reg [95:0] fpss;
reg [95:0] dfmao, dtrunco, dscaleo, ddivo, i2do, d2io;
wire [95:0] d2xdo, s2xdo;
wire [95:0] dfmao1, dtrunco1, dscaleo1, ddivo1, i2do1, d2io1;
reg dscaleo_overflow;
reg dscaleo_nan;
wire ddivo_nan = 1'b0;
wire dfmao_overflow1, dfmao_inf1;
reg dfmao_overflow;
reg ddivo_overflow, ddivo_underflow, d2io_overflow;
wire ddivo_overflow1, ddivo_underflow1, d2io_overflow1;
wire ddiv_done;
reg i2d_done,d2i_done;
wire [11:0] dcmpo;
wire dcmpo_nan;
reg dfmao_nan;
wire [63:0] fp96To64o;
wire [31:0] fp96To32o;

generate begin : gBinaryFloat
if (SUPPORT_BINFLT) begin

always_comb
if (ir2[14])
	casez(ir2[15:8])
	8'h6?,8'h7?:	// FMOVE to memory
		fpss = fps;
	default:
		case(ir2[12:10])
		3'b000:	fpss = i2do1;
		3'b001:	fpss = s2xdo;
		3'b010:	fpss = fps;
		3'b100:	fpss = i2do1;
		3'b101:	fpss = fps;
		3'b110:	fpss = i2do1;
		default:	fpss = fps;
		endcase
	endcase
else
	fpss = fps;

fpFMA96nrL8 ufdma1 (
	.clk(dfclk_i),
	.ce(1'b1),
	.op(fsub),
	.rm(3'b0),
	.a(fpd),
	.b(state==FADD ? 96'h3FFF00000000000000000000 : fpss),	// FADD/FSUB - multiply by one
	.c((state==FMUL1||state==FMUL2) ? 96'd0 : fpss),								// FMUL - add zero
	.o(dfmao1),
	.inf(dfmao_inf1),
	.zero(),
	.overflow(dfmao_overflow1),
	.underflow(),
	.inexact()
);
always_ff @(posedge clk_i)
	dfmao <= dfmao1;
always_ff @(posedge clk_i)
	dfmao_overflow <= dfmao_overflow1;
always_ff @(posedge clk_i)
	dfmao_nan <= dfmao1[94:80]==15'h7fff && !dfmao_inf1;

fpDivide96 uddiv1
(
	.rst(rst_i),
	.clk(dfclk_i),
	.clk4x(clk_i),
	.ce(1'b1),
	.ld(state==FDIV1),
	.op(1'b0),
	.a(fpd),
	.b(fpss),
	.o(ddivo1),
	.done(ddiv_done),
	.sign_exe(),
	.overflow(ddivo_overflow1),
	.underflow(ddivo_underflow1)
);
always_ff @(posedge clk_i)
	ddivo <= ddivo1;
always_ff @(posedge clk_i)
	ddivo_overflow <= ddivo_overflow1;
always_ff @(posedge clk_i)
	ddivo_underflow <= ddivo_underflow1;

fpTrunc96 udtrunc1
(
	.clk(dfclk_i),
	.ce(1'b1),
	.i(fpss),
	.o(dtrunco1)
);
always_ff @(posedge clk_i)
	dtrunco <= dtrunco1;

fpScaleb96 udscale1
(
	.clk(dfclk_i),
	.ce(1'b1),
	.a(fpd),
	.b(s[31:0]),
	.o(dscaleo1)
);
always_ff @(posedge clk_i)
	dscaleo <= dscaleo1;
always_ff @(posedge clk_i)
	dscaleo_overflow <= dscaleo1[62:52]==11'h7ff && dscaleo1[51:0]==52'd0;
always_ff @(posedge clk_i)
	dscaleo_nan <= dscaleo1[62:52]==11'h7ff && dscaleo1[51:0]!=52'd0;

fpCompare96 udcmp1
(
	.a(fpd),
	.b(fpss),
	.o(dcmpo),
	.inf(),
	.nan(dcmp_nan),
	.snan()
);

i2f96 ui2d1
(
	.clk(dfclk_i),
	.ce(1'b1),
	.op(1'b0),	// 0 = unsigned
	.rm(3'b0),
	.i(fps),
	.o(i2do1)
);
always_ff @(posedge clk_i)
	i2do <= i2do1;
always_ff @(posedge clk_i)
	i2d_done <= 1'b1;

f2i96 uf2i1
(
	.clk(clk_i),
	.ce(1'b1),
	.op(1'b0),
	.i(fpss),
	.o(d2io1),
	.overflow(d2io_overflow1)
);
always_ff @(posedge clk_i)
	d2io <= d2io1;
always_ff @(posedge clk_i)
	d2io_overflow <= d2io_overflow1;
always_ff @(posedge clk_i)
	d2i_done <= 1'b1;


fpCvt64To96 ud2xd1
(
	.i(fps[63:0]),
	.o(d2xdo)
);

fpCvt32To96 us2xd1
(
	.i(s[31:0]),
	.o(s2xdo)
);

fpCvt96To64 ufp96To64
(
	.i(rfoFpdst),
	.o(fp96To64o)
);

fpCvt96To32 ufp96To32
(
	.i(rfoFpdst),
	.o(fp96To32o)
);
end
end
endgenerate

generate begin : gDECFLT
if (SUPPORT_DECFLT) begin
/*
assign fpdu.infinity = fpsu.infinity;
assign fpdu.nan = fpsu.nan;
assign fpdu.snan = fpsu.snan;
assign fpdu.qnan = fpsu.qnan;
assign fpdu.sign = fpsu.sign;
assign fpdu.exp = fpsu.exp;
assign fpdu.sig = {4'h1,24{4'h0}};

DFPPack upack1
(
	.i(fpdu),
	.o(fpdp)
);

DFPUnpack uunpack1
(
	.i(fps),
	.o(fpsu)
);
*/

always_comb
if (ir2[14])
	case(ir2[12:10])
	3'b001:	dfpss1 = s;
	3'b010:	dfpss1 = fps;
	3'b101:	dfpss1 = fps;
	default:	dfpss1 = fps;
	endcase
else
	dfpss1 = fps;

DFPAddsub96nr ufaddsub1
(
	.clk(dfclk_i),
	.ce(1'b1),
	.rm(3'b0),
	.op(fsub),
	.a(fpd),
	.b(fps),
	.o(dfaddsubo1)
);

// Cross clock domain sync.
always_ff @(posedge clk_i)
	dfaddsubo <= dfaddsubo1;

DFPMultiply96nr udfmul1
(
	.clk(dfclk_i),
	.ce(1'b1),
	.ld(state==FMUL1),
	.a(fpd),
	.b(fps),
	.o(dfmulo1),
	.rm(3'b000),
	.sign_exe(),
	.inf(dfmulinf1),
	.overflow(dfmulover1),
	.underflow(dfmulunder1),
	.done(dfmuldone1)
);

// Cross clock domain sync.
always_ff @(posedge clk_i)
	dfmulo <= dfmulo1;
always_ff @(posedge clk_i)
	dfmulinf <= dfmulinf1;
always_ff @(posedge clk_i)
	dfmulover <= dfmulover1;
always_ff @(posedge clk_i)
	dfmulunder <= dfmulunder1;
always_ff @(posedge clk_i)
	dfmuldone <= dfmuldone1;
	
DFPDivide96nr udfdiv1
(
	.rst(rst_i),
	.clk(dfclk_i),
	.ce(1'b1),
	.ld(state==FDIV1),
	.op(1'b0),
	.a(fpd),
	.b(fps),
	.o(dfdivo1),
	.rm(3'b000),
	.done(dfdivdone1),
	.sign_exe(),
	.inf(),
	.overflow(dfdivover1),
	.underflow(dfdivunder1)
);

// Cross clock domain sync.
always_ff @(posedge clk_i)
	dfdivo <= dfdivo1;
always_ff @(posedge clk_i)
	dfdivdone <= dfdivdone1;
always_ff @(posedge clk_i)
	dfdivover <= dfdivover1;
always_ff @(posedge clk_i)
	dfdivunder <= dfdivunder1;
	
DFPCompare96 udfcmp1
(
	.a(fpd),
	.b(fps),
	.o(dfcmpo)
);

i2df96 ui2df1
(
	.rst(rst_i),
	.clk(dfclk_i),
	.ce(1'b1),
	.ld(state==I2DF1||state==FCVTI1),
	.op(1'b0),	// 0=unsigned, 1= signed
	.rm(3'b000),
	.i(fps),
	.o(i2dfo1),
	.done(i2dfdone1)
);
// Cross clock domain sync.
always_ff @(posedge clk_i)
	i2dfo <= i2dfo1;
always_ff @(posedge clk_i)
	i2dfdone <= i2dfdone1;

df96Toi udf2i1 (
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.ld(state==DF2I1),
	.op(1'b0),
	.i(fps),
	.o(df2io1),
	.overflow(df2iover1),
	.done(df2idone1)
);

// Cross clock domain sync.
always_ff @(posedge clk_i)
	df2io <= df2io1;
always_ff @(posedge clk_i)
	df2iover <= df2iover1;
always_ff @(posedge clk_i)
	df2idone <= df2idone1;
	
DFPScaleb96 udfscale1
(
	.clk(dfclk_i),
	.ce(1'b1),
	.a(fpd),
	.b(s),
	.o(dfscaleo1)
);
// Cross clock domain sync.
always_ff @(posedge clk_i)
	dfscaleo <= dfscaleo1;

DFPTrunc96 udftrunc1
(
	.clk(dfclk_i),
	.ce(1'b1),
	.i(fps),
	.o(dftrunco1),
	.overflow()
);
// Cross clock domain sync.
always_ff @(posedge clk_i)
	dftrunco <= dftrunco1;

DFP32To96 udfp32To96 (
	.i(dfpss1[31:0]),
	.o(dfp32To96)
);

DFP64To96 udfp32To64 (
	.i(dfpss1[63:0]),
	.o(dfp64To96)
);

DFP96To64 udfp96To64
(
	.i(rfoFpdst),
	.o(dfp96To64o)
);

DFP96To32 udfp96To32
(
	.i(rfoFpdst),
	.o(dfp96To32o)
);

end
end
endgenerate


always_comb
case(ir[15:8])
`BRA:	takb = 1'b1;
`BSR:	takb = 1'b0;
`BHI:	takb = !cf & !zf;
`BLS:	takb = cf | zf;
`BHS:	takb = !cf;
`BLO:	takb =  cf;
`BNE:	takb = !zf;
`BEQ:	takb =  zf;
`BVC:	takb = !vf;
`BVS:	takb =  vf;
`BPL:	takb = !nf;
`BMI:	takb =  nf;
`BGE:	takb = (nf & vf)|(!nf & !vf);
`BLT:	takb = (nf & !vf)|(!nf & vf);
`BGT:	takb = (nf & vf & !zf)|(!nf & !vf & !zf);
`BLE:	takb = zf | (nf & !vf) | (!nf & vf);
`DBRA:	takb = 1'b1;
`DBSR:	takb = 1'b0;
`DBHI:	takb = !cf & !zf;
`DBLS:	takb = cf | zf;
`DBHS:	takb = !cf;
`DBLO:	takb =  cf;
`DBNE:	takb = !zf;
`DBEQ:	takb =  zf;
`DBVC:	takb = !vf;
`DBVS:	takb =  vf;
`DBPL:	takb = !nf;
`DBMI:	takb =  nf;
`DBGE:	takb = ((nf & vf)|(!nf & !vf));
`DBLT:	takb = ((nf & !vf)|(!nf & vf));
`DBGT:	takb = ((nf & vf & !zf)|(!nf & !vf & !zf));
`DBLE:	takb = (zf | (nf & !vf) | (!nf & vf));
default:	takb = 1'b1;
endcase

generate begin : gDECFLTBranch
if (SUPPORT_DECFLT) begin
always_comb
case(ir[5:0])
6'b000001:	ftakb =  fzf;	// EQ
6'b001110:	ftakb = !fzf;	// NE
6'b010010:	ftakb = !fnanf && !fzf && !fvf && !fnf; // GT
6'b011101:	ftakb = fnanf || fzf || fnf;	// NGT
6'b010011:	ftakb = fzf || (!fnanf && !fvf && !fnf);	// GE
6'b011100:	ftakb = fnanf || (fnf && !fzf); 	// NGE
6'b010100:	ftakb = fnf && (!fnanf && !fvf && !fzf);	// LT
6'b011011:	ftakb = fnanf || (fzf || !fnf);	// NLT
6'b010101:	ftakb = fzf || (fnf && !fnanf);	// LE
6'b011010:	ftakb = fnanf || (!fnf && !fvf && !fzf);	// NLE
6'b010110:	ftakb = !fnanf && !fvf && !fzf;	// GL
6'b011001:	ftakb = fnanf || fzf;	// NGL
6'b010111:	ftakb = !fnanf;	// GLE
6'b011000:	ftakb = fnanf;	// NGLE

6'b000010:	ftakb = !fnanf && !fzf && !fvf && !fnf; // OGT
6'b001101:	ftakb = fnanf || fzf || fnf;	// ULE
6'b000011:	ftakb = fzf || (!fnanf && !fvf && !fnf);	// OGE
6'b001100:	ftakb = fnanf || (fnf && !fzf);	// ULT
6'b000100:	ftakb = fnf && (!fnanf && !fvf && !fzf);	// OLT
6'b001011:	ftakb = fnanf || fzf || fnf;	// UGE
6'b000101:	ftakb = fzf || (fnf && !fnanf);	// OLE
6'b001010:	ftakb = fnanf || (!fnf && !fvf && !fzf); // UGT
6'b000110:	ftakb = !fnanf && !fvf && !fzf;	// OGL
6'b001001:	ftakb = fnanf || fzf;	// UEQ
6'b000111:	ftakb = !fnanf;
6'b001000:	ftakb = fnanf;

6'b000000:	ftakb = 1'b0;	// F
6'b001111:	ftakb = 1'b1;	// T
6'b010000:	ftakb = 1'b0;	// SF
6'b011111:	ftakb = 1'b1;	// ST
6'b010001:	ftakb = fzf;	// SEQ
6'b011110:	ftakb = !fzf;	// SNE
endcase
end
end
endgenerate

generate begin : gPMMUcond
	always_comb
	if (ir2[5:4]==2'd0)
		ptakb = pmmu_sr[pmmu_cond[3:1]] ^ ~pmmu_cond[0];
	else
		ptakb = `FALSE;
end
endgenerate

`ifdef BIG_ENDIAN
wire [15:0] iri = pc[1] ? {dat_i[23:16],dat_i[31:24]} : {dat_i[7:0],dat_i[15:8]};
`else
wire [15:0] iri = pc[1] ? dat_i[31:16] : dat_i[15:0];
`endif

`ifdef SUPPORT_NANO_CACHE
integer n4;
reg fetchbuf_found;
reg [15:0] fetchbuf_ir;
always_comb
begin
	fetchbuf_found = 1'b0;
	fetchbuf_ir = 16'h4E71;
	for (n4 = 0; n4 < 8; n4 = n4 + 1) begin
		if (fetchbuf_tag[n4]==pc) begin
			fetchbuf_ir = fetchbuf[n4];
			fetchbuf_found = 1'b1;
		end
	end
end
`endif

wire [4:0] flo;
flo24 uflo1 (.i({8'h00,imm[15:0]}), .o(flo));
flo48 uflo2 (.i({16'h00,pmmu_smask[31:0]}), .o(pmmu_flo));

always_ff @(posedge clk_i)
if (rst_i) begin
	pc <= 32'h1000;
	pid_sp <= 4'd0;
	for (n = 0; n < 16; n = n + 1)
		pid_stack[n] <= 16'd1;
	em <= 1'b0;
	cmd_o <= CMD_NONE;
	lock_o <= 1'b0;
	pfc_o <= 3'b000;
	pcyc_o <= 1'b0;
	pstb_o <= 1'b0;
	pwe_o <= 1'b0;
	psel_o <= 4'h0;
	padr_o <= 32'd0;
	pdat_o <= 32'd0;
	work_fc <= 3'd0;
	work_cyc <= 1'b0;
	work_stb <= 1'b0;
	work_we <= 1'b0;
	work_sel <= 4'h0;
	work_adr <= 32'h0;
	work_dat <= 32'h0;
	rfwrB <= 1'b0;
	rfwrW <= 1'b0;
	rfwrL <= 1'b0;
	rfwrX <= 1'b0;
	rfwrF <= 1'b0;
	zf <= 1'b0;
	nf <= 1'b0;
	cf <= 1'b0;
	vf <= 1'b0;
	xf <= 1'b0;
	im <= 3'b111;
	sf <= 1'b1;
	tf <= 1'b0;
	movemf <= 1'b0;
	fnanf <= 1'b0;
	fzf <= 1'b0;
	fnf <= 1'b0;
	fvf <= 1'b0;
	goto (RESET);
	rstate <= RESET;
	prev_nmi <= 1'b0;
	pe_nmi <= 1'b0;
  tick <= 32'd0;
  rst_cnt <= 5'd10;
  rst_o <= 1'b1;
  is_rst <= 1'b1;
	MMMRRR <= 1'b0;
	rtr <= 1'b0;
	bsr <= 1'b0;
	lea <= 1'b0;
	divs <= 1'b0;
	fsub <= 1'b0;
	fabs <= 1'b0;
	bcdsub <= 1'b0;
	bcdneg <= 1'b0;
	fmovem <= 1'b0;
	icnt <= 'd0;
	is_bus_err <= 1'b0;
	is_adr_err <= 1'b0;
	is_trace <= 1'b0;
	is_priv <= 1'b0;
	is_illegal <= 1'b0;
	is_format <= 1'b0;
	is_vpa2 <= 1'b0;
	vbr <= 'd0;
	sfc <= 'd0;
	dfc <= 'd0;
	dati_buf <= 'd0;
	dato_buf <= 'd0;
	use_sfc <= 'd0;
	use_dfc <= 'd0;
	ext_ir <= 1'b0;
	ios  <= 32'hFD000000;
	iops <= IOPS_ADDR;
	mmus <= MMU_ADDR;
	canary <= 'd0;
`ifdef SUPPORT_NANO_CACHE
	for (n = 0; n < 8; n = n + 1) begin
		fetchbuf[n] <= 16'h4E71;	// NOP
		fetchbuf_tag[n] <= 32'hFFFFFFFF;
	end
`endif
	ie_cntdwn <= 3'd0;
	ie_val <= 3'd7;
	tracendx <= 11'd0;
	tracendx2 <= 11'd0;
	appid <= 16'h0000;
	pmmu_access <= `FALSE;
	pmmu_tc <= 32'h0;
	pmmu_format <= 8'h48;
	atc_ua <= 6'd0;
	pload <= `FALSE;
	dec_unlink <= FALSE;
	bus_stat <= 8'h00;
end
else begin

	if (pe_dt)
		tracendx2 <= 11'd1;
	if (tracendx2 != 11'd0) begin
		trace_o <= tracebuf[tracendx2];
		tracendx2 <= tracendx2 + 11'd1;
	end	

if (rst_cnt != 5'd0)
    rst_cnt <= rst_cnt - 5'd1;
else
    rst_o <= 1'b0;

tick <= tick + 32'd1;
prev_nmi <= nmi_i;
if (nmi_i & !prev_nmi)
	pe_nmi <= 1'b1;

// Register file update
rfwrB <= 1'b0;
rfwrW <= 1'b0;
rfwrL <= 1'b0;
rfwrF <= 1'b0;
if (rfwrL) begin
  case(Rt)
  4'd0:   d0 <= resL[31:0];
  4'd1:   d1 <= resL[31:0];
  4'd2:   d2 <= resL[31:0];
  4'd3:   d3 <= resL[31:0];
  4'd4:   d4 <= resL[31:0];
  4'd5:   d5 <= resL[31:0];
  4'd6:   d6 <= resL[31:0];
  4'd7:   d7 <= resL[31:0];
  4'd8:   a0 <= resL[31:0];
  4'd9:   a1 <= resL[31:0];
  4'd10:  a2 <= resL[31:0];
  4'd11:  a3 <= resL[31:0];
  4'd12:  a4 <= resL[31:0];
  4'd13:  a5 <= resL[31:0];
  4'd14:  a6 <= resL[31:0];
  4'd15:  sp <= resL[31:0];
  endcase
end
else if (rfwrW) begin
  case(Rt)
  4'd0:   d0[15:0] <= resW[15:0];
  4'd1:   d1[15:0] <= resW[15:0];
  4'd2:   d2[15:0] <= resW[15:0];
  4'd3:   d3[15:0] <= resW[15:0];
  4'd4:   d4[15:0] <= resW[15:0];
  4'd5:   d5[15:0] <= resW[15:0];
  4'd6:   d6[15:0] <= resW[15:0];
  4'd7:   d7[15:0] <= resW[15:0];
  4'd8:   a0 <= {{16{resW[15]}},resW[15:0]};
  4'd9:   a1 <= {{16{resW[15]}},resW[15:0]};
  4'd10:  a2 <= {{16{resW[15]}},resW[15:0]};
  4'd11:  a3 <= {{16{resW[15]}},resW[15:0]};
  4'd12:  a4 <= {{16{resW[15]}},resW[15:0]};
  4'd13:  a5 <= {{16{resW[15]}},resW[15:0]};
  4'd14:  a6 <= {{16{resW[15]}},resW[15:0]};
  4'd15:  sp <= {{16{resW[15]}},resW[15:0]};
  endcase
end
else if (rfwrB)
  case(Rt)
  4'd0:   d0[7:0] <= resB[7:0];
  4'd1:   d1[7:0] <= resB[7:0];
  4'd2:   d2[7:0] <= resB[7:0];
  4'd3:   d3[7:0] <= resB[7:0];
  4'd4:   d4[7:0] <= resB[7:0];
  4'd5:   d5[7:0] <= resB[7:0];
  4'd6:   d6[7:0] <= resB[7:0];
  4'd7:   d7[7:0] <= resB[7:0];
  default:    ;
  endcase

 if (SUPPORT_DECFLT && rfwrF)
 	case(Rt)
 	4'd0:	fp0 <= resF;
 	4'd1:	fp1 <= resF;
 	4'd2:	fp2 <= resF;
 	4'd3:	fp3 <= resF;
 	4'd4:	fp4 <= resF;
 	4'd5:	fp5 <= resF;
 	4'd6:	fp6 <= resF;
 	4'd7:	fp7 <= resF;
	default:	;
	endcase

	pmmu_flush_cmd <= 2'd0;	// NOP

case(state)

IFETCH:
	begin
		case(flag_update)
		FU_MUL:
			begin
				cf <= 1'b0;
				vf <= 1'b0;
				nf <= resL[31];
				zf <= resL[31:0]==32'd0;
			end
		FU_TST:
			begin
				cf <= 1'b0;
				vf <= 1'b0;
				case(sz)
				2'b00:	begin zf <= d[7:0]==8'h00; nf <= d[7]; end
				2'b01:	begin zf <= d[15:0]==16'h00; nf <= d[15]; end
				2'b10:	begin zf <= d[31:0]==32'h00; nf <= d[31]; end
				default:	;
				endcase
			end
		FU_CMP:
			begin
				case(sz)
				2'b00:	begin zf <= resB[ 7:0]== 8'd0; nf <= resB[ 7]; cf <= resB[ 8]; vf <= fnSubOverflow(resB[ 7],d[ 7],s[ 7]); end
				2'b01:	begin zf <= resW[15:0]==16'd0; nf <= resW[15]; cf <= resW[16]; vf <= fnSubOverflow(resW[15],d[15],s[15]); end
				2'b10:	begin zf <= resL[31:0]==32'd0; nf <= resL[31]; cf <= resL[32]; vf <= fnSubOverflow(resL[31],d[31],s[31]); end
				2'b11:	begin zf <= resL[31:0]==32'd0; nf <= resL[31]; cf <= resL[32]; vf <= fnSubOverflow(resL[31],d[31],s[31]); end	// CMPA
				endcase
			end
		FU_ADD:
			begin
				case(sz)
				2'b00:
					begin
						cf <= resB[8];
						nf <= resB[7];
						zf <= resB[7:0]==8'h00;
						vf <= fnAddOverflow(resB[7],dd[7],s[7]);
						xf <= resB[8];
					end
				2'b01:
					begin
						cf <= resW[16];
						nf <= resW[15];
						zf <= resW[15:0]==16'h0000;
						vf <= fnAddOverflow(resW[15],dd[15],s[15]);
						xf <= resW[16];
					end
				2'b10:
					begin
						cf <= resL[32];
						nf <= resL[31];
						zf <= resL[31:0]==32'h00000000;
						vf <= fnAddOverflow(resL[31],dd[31],s[31]);
						xf <= resL[32];
					end
				default:	;
				endcase
			end
		FU_ADDX:
			begin
				case(sz)
				2'b00:
					begin
						cf <= resB[8];
						nf <= resB[7];
						if (resB[7:0]!=8'h00)
							zf <= 1'b0;
						vf <= fnAddOverflow(resB[7],dd[7],s[7]);
						xf <= resB[8];
					end
				2'b01:
					begin
						cf <= resW[16];
						nf <= resW[15];
						if (resW[15:0]!=16'h00)
							zf <= 1'b0;
						vf <= fnAddOverflow(resW[15],dd[15],s[15]);
						xf <= resW[16];
					end
				2'b10:
					begin
						cf <= resL[32];
						nf <= resL[31];
						if (resL[31:0]!=32'h00)
							zf <= 1'b0;
						vf <= fnAddOverflow(resL[31],dd[31],s[31]);
						xf <= resL[32];
					end
				default:	;
				endcase
			end
		FU_SUBX:
			begin
				case(sz)
				2'b00:
					begin
						cf <= resB[8];
						nf <= resB[7];
						if (resB[7:0]!=8'h00)
							zf <= 1'b0;
						vf <= fnSubOverflow(resB[7],dd[7],s[7]);
						xf <= resB[8];
					end
				2'b01:
					begin
						cf <= resW[16];
						nf <= resW[15];
						if (resW[15:0]!=16'h00)
							zf <= 1'b0;
						vf <= fnSubOverflow(resW[15],dd[15],s[15]);
						xf <= resW[16];
					end
				2'b10:
					begin
						cf <= resL[32];
						nf <= resL[31];
						if (resL[31:0]!=32'h00)
							zf <= 1'b0;
						vf <= fnSubOverflow(resL[31],dd[31],s[31]);
						xf <= resL[32];
					end
				default:	;
				endcase
			end
		FU_SUB:
			begin
				case(sz)
				2'b00:
					begin
						cf <= resB[8];
						nf <= resB[7];
						zf <= resB[7:0]==8'h00;
						vf <= fnSubOverflow(resB[7],dd[7],s[7]);
						xf <= resB[8];
					end
				2'b01:
					begin
						cf <= resW[16];
						nf <= resW[15];
						zf <= resW[15:0]==16'h0000;
						vf <= fnSubOverflow(resW[15],dd[15],s[15]);
						xf <= resW[16];
					end
				2'b10:
					begin
						cf <= resL[32];
						nf <= resL[31];
						zf <= resL[31:0]==32'h00000000;
						vf <= fnSubOverflow(resL[31],dd[31],s[31]);
						xf <= resL[32];
					end
				default:	;
				endcase
			end
		FU_LOGIC:
			begin
				cf <= 1'b0;
				vf <= 1'b0;
				case(sz)
				2'b00:
					begin
						nf <= resB[7];
						zf <= resB[7:0]==8'h00;
					end
				2'b01:
					begin
						nf <= resW[15];
						zf <= resW[15:0]==16'h0000;
					end
				2'b10:
					begin
						nf <= resL[31];
						zf <= resL[31:0]==32'h00000000;
					end
				default:	;
				endcase
			end
		FU_ADDQ:
			begin
				case(sz)
				2'b00:
					begin
						 xf <= resB[8];
						 cf <= resB[8];
						 vf <= resB[8]!=resB[7];
						vf <= fnAddOverflow(resB[7],dd[7],s[7]);
						 zf <= resB[7:0]==8'd0;
						 nf <= resB[7];
					end
				2'b01:
					begin
						 xf <= resW[16];
						 cf <= resW[16];
						vf <= fnAddOverflow(resW[15],dd[15],s[15]);
						 //vf <= resW[16]!=resW[15];
						 zf <= resW[15:0]==16'd0;
						 nf <= resW[15];
					end
				2'b10:
					begin
						 xf <= resL[32];
						 cf <= resL[32];
						vf <= fnAddOverflow(resL[31],dd[31],s[31]);
						// vf <= resL[32]!=resL[31];
						 zf <= resL[31:0]==32'd0;
						 nf <= resL[31];
					end
				default:	;
				endcase
			end
		FU_SUBQ:
			begin
				case(sz)
				2'b00:
					begin
						 xf <= resB[8];
						 cf <= resB[8];
						 vf <= resB[8]!=resB[7];
						vf <= fnSubOverflow(resB[7],dd[7],s[7]);
						 zf <= resB[7:0]==8'd0;
						 nf <= resB[7];
					end
				2'b01:
					begin
						 xf <= resW[16];
						 cf <= resW[16];
						vf <= fnSubOverflow(resW[15],dd[15],s[15]);
						 //vf <= resW[16]!=resW[15];
						 zf <= resW[15:0]==16'd0;
						 nf <= resW[15];
					end
				2'b10:
					begin
						 xf <= resL[32];
						 cf <= resL[32];
						vf <= fnSubOverflow(resL[31],dd[31],s[31]);
						// vf <= resL[32]!=resL[31];
						 zf <= resL[31:0]==32'd0;
						 nf <= resL[31];
					end
				default:	;
				endcase
			end
		FU_ADDI:
			begin
				case(ir[11:8])
				4'h0,4'h2,4'hA:
						begin	// ORI,ANDI,EORI
							cf <= 1'b0;
							vf <= 1'b0;
							case(sz)
							2'b00:	zf <= resB[7:0]==8'h00;
							2'b01:	zf <= resW[15:0]==16'h00;
							2'b10:	zf <= resL[31:0]==32'd0;
							default:	;
							endcase
							case(sz)
							2'b00:	nf <= resB[7];
							2'b01:	nf <= resW[15];
							2'b10:	nf <= resL[31];
							default:	;
							endcase
						end
				4'h4:	// SUBI
					begin
						case(sz)
						2'b00:
							begin
								xf <= resB[8];
								cf <= resB[8];
								vf <= fnSubOverflow(resB[7],dd[7],immx[7]);
								//vf <= resB[8]!=resB[7];
								zf <= resB[7:0]==8'd0;
								nf <= resB[7];
							end
						2'b01:
							begin
								xf <= resW[16];
								cf <= resW[16];
								vf <= fnSubOverflow(resW[15],dd[15],immx[15]);
								//vf <= resW[16]!=resW[15];
								zf <= resW[15:0]==16'd0;
								nf <= resW[15];
							end
						2'b10:
							begin
								xf <= resL[32];
								cf <= resL[32];
								vf <= fnSubOverflow(resL[31],dd[31],immx[31]);
								//vf <= resL[32]!=resL[31];
								zf <= resL[31:0]==32'd0;
								nf <= resL[31];
							end
						default:	;
						endcase
					end
				4'h6:	// ADDI
					begin
						case(sz)
						2'b00:
							begin
								xf <= resB[8];
								cf <= resB[8];
								vf <= fnAddOverflow(resB[7],dd[7],immx[7]);
								//vf <= resB[8]!=resB[7];
								zf <= resB[7:0]==8'd0;
								nf <= resB[7];
							end
						2'b01:
							begin
								xf <= resW[16];
								cf <= resW[16];
								vf <= fnAddOverflow(resW[15],dd[15],immx[15]);
								//vf <= resW[16]!=resW[15];
								zf <= resW[15:0]==16'd0;
								nf <= resW[15];
							end
						2'b10:
							begin
								xf <= resL[32];
								cf <= resL[32];
								vf <= fnAddOverflow(resL[31],dd[31],immx[31]);
								//vf <= resL[32]!=resL[31];
								zf <= resL[31:0]==32'd0;
								nf <= resL[31];
							end
						default:	;
						endcase
					end
				4'hC:	// CMPI
					begin
						case(sz)
						2'b00:
							begin
								cf <= resB[8];
								vf <= fnSubOverflow(resB[7],dd[7],immx[7]);
								zf <= resB[7:0]==8'd0;
								nf <= resB[7];
							end
						2'b01:
							begin
								cf <= resW[16];
								vf <= fnSubOverflow(resW[15],dd[15],immx[15]);
								//vf <= resW[16]!=resW[15];
								zf <= resW[15:0]==16'd0;
								nf <= resW[15];
							end
						2'b10:
							begin
								cf <= resL[32];
								vf <= fnSubOverflow(resL[31],dd[31],immx[31]);
								//vf <= resL[32]!=resL[31];
								zf <= resL[31:0]==32'd0;
								nf <= resL[31];
							end
						default:	;
						endcase
					end
				endcase
			end
		FU_ANDI_CCR:
			begin
				cf <= cf & imm[0];
				vf <= vf & imm[1];
				zf <= zf & imm[2];
				nf <= nf & imm[3];
				xf <= xf & imm[4];
			end
		FU_ANDI_SR:
			begin
				cf <= cf & imm[0];
				vf <= vf & imm[1];
				zf <= zf & imm[2];
				nf <= nf & imm[3];
				xf <= xf & imm[4];
				im[0] <= im[0] & imm[8];
				im[1] <= im[1] & imm[9];
				im[2] <= im[2] & imm[10];
				sf <= sf & imm[13];
				tf <= tf & imm[15];
			end
		FU_ANDI_SRX:
			begin
				cf <= cf & imm[0];
				vf <= vf & imm[1];
				zf <= zf & imm[2];
				nf <= nf & imm[3];
				xf <= xf & imm[4];
				im[0] <= im[0] & imm[8];
				im[1] <= im[1] & imm[9];
				im[2] <= im[2] & imm[10];
				sf <= sf & imm[13];
				tf <= tf & imm[15];
			end
		FU_EORI_CCR:
			begin
				cf <= cf ^ imm[0];
				vf <= vf ^ imm[1];
				zf <= zf ^ imm[2];
				nf <= nf ^ imm[3];
				xf <= xf ^ imm[4];
			end
		FU_EORI_SR:
			begin
				cf <= cf ^ imm[0];
				vf <= vf ^ imm[1];
				zf <= zf ^ imm[2];
				nf <= nf ^ imm[3];
				xf <= xf ^ imm[4];
				im[0] <= im[0] ^ imm[8];
				im[1] <= im[1] ^ imm[9];
				im[2] <= im[2] ^ imm[10];
				sf <= sf ^ imm[13];
				tf <= tf ^ imm[15];
			end
		FU_EORI_SRX:
			begin
				cf <= cf ^ imm[0];
				vf <= vf ^ imm[1];
				zf <= zf ^ imm[2];
				nf <= nf ^ imm[3];
				xf <= xf ^ imm[4];
				im[0] <= im[0] ^ imm[8];
				im[1] <= im[1] ^ imm[9];
				im[2] <= im[2] ^ imm[10];
				sf <= sf ^ imm[13];
				tf <= tf ^ imm[15];
			end
		FU_ORI_CCR:
			begin
				cf <= cf | imm[0];
				vf <= vf | imm[1];
				zf <= zf | imm[2];
				nf <= nf | imm[3];
				xf <= xf | imm[4];
			end
		FU_ORI_SR:
			begin
				cf <= cf | imm[0];
				vf <= vf | imm[1];
				zf <= zf | imm[2];
				nf <= nf | imm[3];
				xf <= xf | imm[4];
				im[0] <= im[0] | imm[8];
				im[1] <= im[1] | imm[9];
				im[2] <= im[2] | imm[10];
				sf <= sf | imm[13];
				tf <= tf | imm[15];
			end
		FU_ORI_SRX:
			begin
				cf <= cf | imm[0];
				vf <= vf | imm[1];
				zf <= zf | imm[2];
				nf <= nf | imm[3];
				xf <= xf | imm[4];
				im[0] <= im[0] | imm[8];
				im[1] <= im[1] | imm[9];
				im[2] <= im[2] | imm[10];
				sf <= sf | imm[13];
				tf <= tf | imm[15];
			end
		FU_MOVE2CCR:
			begin
				cf <= s[0];
				vf <= s[1];
				zf <= s[2];
				nf <= s[3];
				xf <= s[4];
				ccr57 <= s[7:5];
			end	
		FU_MOVE2SR:
			begin
				cf <= s[0];
				vf <= s[1];
				zf <= s[2];
				nf <= s[3];
				xf <= s[4];
				ccr57 <= s[7:5];
				im[0] <= s[8];
				im[1] <= s[9];
				im[2] <= s[10];
				sr1112 <= s[12:11];
				sf <= s[13];
				sr14 <= s[14];
				tf <= s[15];
			end
		FU_MOVE2SRX:
			begin
				cf <= s[0];
				vf <= s[1];
				zf <= s[2];
				nf <= s[3];
				xf <= s[4];
				ccr57 <= s[7:5];
				im[0] <= s[8];
				im[1] <= s[9];
				im[2] <= s[10];
				sr1112 <= s[12:11];
				sf <= s[13];
				sr14 <= s[14];
				tf <= s[15];
			end
		default:	;
		endcase
		goto (IFETCH_ACK);
		flag_update <= FU_NONE;
		MMMRRR <= 1'b0;
		rtr <= 1'b0;
		bsr <= 1'b0;
		lea <= 1'b0;
		pload <= `FALSE;
		dec_unlink <= FALSE;
		fsub <= 1'b0;
		fabs <= 1'b0;
		bcdsub <= 1'b0;
		bcdneg <= 1'b0;
		fmovem <= 1'b0;
		is_illegal <= 1'b0;
		is_format <= 1'b0;
		use_sfc <= 1'b0;
		use_dfc <= 1'b0;
		fpcnt <= 12'd0;
		fpiar <= pc;
		ext_ir <= 1'b0;
		movemf <= 1'b0;
		bus_stat <= 8'h00;
		if (ie_cntdwn != 3'd0)
			ie_cntdwn <= ie_cntdwn - 3'd1;
		if (ie_cntdwn==3'd1)
			im <= ie_val;
		is_nmi <= 1'b0;
		is_irq <= 1'b0;
		/*
		if (pe_nmi) begin
			pe_nmi <= 1'b0;
			is_nmi <= 1'b1;
			goto(TRAP);
		end
		else 
		*/
		if (ipl_i > im || ipl_i==3'd7) begin
			is_irq <= 1'b1;
			pcyc_o <= LOW;
			pstb_o <= LOW;
			psel_o <= 4'h0;
			gosub(TRAP);
		end
		else if (pc[0]) begin
			is_adr_err <= 1'b1;
			pcyc_o <= LOW;
			pstb_o <= LOW;
			psel_o <= 4'h0;
			padr_o <= pc;
			gosub(TRAP);
		end
		else begin
`ifdef SUPPORT_NANO_CACHE				
			if (fetchbuf_found) begin
				ir <= fetchbuf_ir;
				mmm <= fetchbuf_ir[5:3];
				rrr <= fetchbuf_ir[2:0];
				rrrr <= fetchbuf_ir[3:0];
				pmmu_cond <= fetchbuf_ir[5:0];
				gosub (DECODE);
			end
			else begin
				pfc_o <= {sf,2'b10};
				pcyc_o <= 1'b1;
				pstb_o <= 1'b1;
				psel_o <= 4'b1111;
				padr_o <= pc;
				goto (IFETCH_ACK);
			end
`else
			pfc_o <= {sf,2'b10};
			pcyc_o <= 1'b1;
			pstb_o <= 1'b1;
			psel_o <= 4'b1111;
			padr_o <= pc;
			goto (IFETCH_ACK);
`endif				
		end
	end
IFETCH_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 2'b00;
		ir <= iri;
		pmmu_cond <= iri[5:0];
		mmm <= iri[5:3];
		rrr <= iri[2:0];
		rrrr <= iri[3:0];
`ifdef SUPPORT_NANO_CACHE			
		for (n = 0; n < 7; n = n + 1) begin
			fetchbuf_tag[n+1] <= fetchbuf_tag[n];
			fetchbuf[n+1] <= fetchbuf[n];
		end
		fetchbuf_tag[0] <= pc;
		fetchbuf[0] <= iri;
`endif			
		call (DECODE, IFETCH);
	end
IFETCH2:
	begin
`ifdef SUPPORT_NANO_CACHE			
		if (fetchbuf_found) begin
			ext_ir <= 1'b1;
			ir2 <= fetchbuf_ir;
			pmmu_cond <= fetchbuf_ir[5:0];
			FLTSRC <= fetchbuf_ir[12:10];
			FLTDST <= fetchbuf_ir[ 9: 7];
			goto (DECODE);
		end
		else
`endif			
		begin
			if (!cyc_o) begin
				pfc_o <= {sf,2'b10};
				pcyc_o <= 1'b1;
				pstb_o <= 1'b1;
				psel_o <= 4'b1111;
				padr_o <= pc;
				ext_ir <= 1'b1;
				goto (IFETCH2);
			end
			else if (ack_i) begin
				pcyc_o <= 1'b0;
				pstb_o <= 1'b0;
				psel_o <= 2'b00;
				ext_ir <= 1'b1;
				ir2 <= iri;
				FLTSRC <= iri[12:10];
				FLTDST <= iri[ 9: 7];
				pmmu_cond <= iri[5:0];
`ifdef SUPPORT_NANO_CACHE			
				for (n = 0; n < 7; n = n + 1) begin
					fetchbuf_tag[n+1] <= fetchbuf_tag[n];
					fetchbuf[n+1] <= fetchbuf[n];
				end
				fetchbuf_tag[0] <= pc;
				fetchbuf[0] <= iri;
`endif			
				goto (DECODE);
			end
		end
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
DECODE:
	begin
		tracebuf[tracendx] <= pc;
		tracendx <= tracendx + 11'd1;
		pc <= pc + 4'd2;
		opc <= pc + 4'd2;
		icnt <= icnt + 2'd1;
	case({ext_ir,ir[15:12]})
	5'h0:
		case(ir[11:8])
		4'h0:
			case(ir[7:0])
			8'h3C:	state <= ORI_CCR;
			8'h7C:
				if (sf)	
					goto (ORI_SR);
				else
					tPrivilegeViolation();
			8'hBC:	
				if (sf)	
					goto (ORI_SRX);
				else
					tPrivilegeViolation();
			default:	state <= ADDI;	// ORI
			endcase
		4'h2:
			case(ir[7:0])
			8'h3C:	state <= ANDI_CCR;
			8'h7C:	
				if (sf)	
					goto (ANDI_SR);
				else
					tPrivilegeViolation();
			8'hBC:
				if (sf)	
					goto (ANDI_SRX);
				else
					tPrivilegeViolation();
			default:	state <= ADDI;	// ANDI
			endcase
		4'h4:	state <= ADDI;	// SUBI
		4'h6:	state <= ADDI;	// ADDI
		4'hA:
			case(ir[7:0])
			8'h3C:	state <= EORI_CCR;
			8'h7C:
				if (sf)	
					goto (EORI_SR);
				else
					tPrivilegeViolation();
			8'hBC:
				if (sf)	
					goto (EORI_SRX);
				else
					tPrivilegeViolation();
			default:	state <= ADDI;	// EORI
			endcase
		4'hC:	state <= ADDI;	// CMPI
`ifdef SUPPORT_010		
		4'hE:	// MOVES
			begin
				call(FETCH_IMM16,MOVES);
			end
`endif			
		default:	
			if (mmm==3'b001 && ir[8]) begin
				push(MOVEP);
				fs_data(3'b101,rrr,FETCH_NOP_WORD,S);
			end
			else
				goto (BIT);
		endcase
//-----------------------------------------------------------------------------
// MOVE.B
//-----------------------------------------------------------------------------
	5'h1:	
		begin
			push(STORE_IN_DEST);
			fs_data(mmm,rrr,FETCH_BYTE,S);
		end
//-----------------------------------------------------------------------------
// MOVE.L
//-----------------------------------------------------------------------------
  5'h2:    
   	begin
			push(STORE_IN_DEST);
    	fs_data(mmm,rrr,FETCH_LWORD,S);
    end
//-----------------------------------------------------------------------------
// MOVE.W
//-----------------------------------------------------------------------------
	5'h3:
		begin
			push(STORE_IN_DEST);
			fs_data(mmm,rrr,FETCH_WORD,S);
		end
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
	5'h4:
		casez(ir[11:3])
		9'b0000?????:
			case(sz)
			2'b00:	begin push(NEGX); fs_data(mmm,rrr,FETCH_BYTE,D); end
			2'b01:	begin push(NEGX); fs_data(mmm,rrr,FETCH_WORD,D); end
			2'b10:	begin push(NEGX); fs_data(mmm,rrr,FETCH_LWORD,D); end
			2'b11:	// MOVE sr,<ea>
				if (sf) begin 
					d <= sr;
					resW <= sr;
					fs_data(mmm,rrr,STORE_WORD,S);
				end
				else
					tPrivilegeViolation();
			endcase
		9'b000110???:	// MOVE.L srx,<ea>
				if (sf) begin
					d <= srx;
					resL <= srx;
					fs_data(mmm,rrr,STORE_LWORD,S);
				end	
				else
					tPrivilegeViolation();
		9'b0010?????:
			begin		// 42xx	CLR
				cf <= 1'b0;
				vf <= 1'b0;
				zf <= 1'b1;
				nf <= 1'b0;
				d <= 32'd0;
				resB <= 9'd0;
				resW <= 17'd0;
				resL <= 33'd0;
				case(sz)
				2'b00:	fs_data(mmm,rrr,STORE_BYTE,D);
				2'b01:	fs_data(mmm,rrr,STORE_WORD,D);
				2'b10:	fs_data(mmm,rrr,STORE_LWORD,D);
				default:	tIllegal();
				endcase
			end
		9'b0100?????:
			casez(sz)
			2'b00:	begin push(NEG); fs_data(mmm,rrr,FETCH_BYTE,D); end
			2'b01:	begin push(NEG); fs_data(mmm,rrr,FETCH_WORD,D); end
			2'b10:	begin push(NEG); fs_data(mmm,rrr,FETCH_LWORD,D); end
			2'b11:	// MOVE <src>,ccr
				begin
					flag_update <= FU_MOVE2CCR;
					fs_data(mmm,rrr,FETCH_WORD,S);
				end
			endcase
		9'b0110?????:
			case(sz)
			2'b00:	begin push(NOT); fs_data(mmm,rrr,FETCH_BYTE,D); end
			2'b01:	begin push(NOT); fs_data(mmm,rrr,FETCH_WORD,D); end
			2'b10:	begin push(NOT); fs_data(mmm,rrr,FETCH_LWORD,D); end
			2'b11:	
				if (sf) begin	// MOVE <src>,sr
					flag_update <= FU_MOVE2SR;
					fs_data(mmm,rrr,FETCH_WORD,S);
				end
				else
					tPrivilegeViolation();
			endcase
/*			
		9'b0111?????:
			case(sz)
			2'b00:	tIllegal();
			2'b01:	tIllegal();
			2'b10:	tIllegal();
			2'b11:	
				if (sf) begin	// MOVE <src>,srx
					flag_update <= FU_MOVE2SRX;
					fs_data(mmm,rrr,FETCH_LWORD,S);
				end
				else
					tPrivilegeViolation();
			default:	;
			endcase
*/			
		9'b10001?000:
			if (ir[6]) begin	// EXT.L
				cf <= 1'b0;
				vf <= 1'b0;
				nf <= rfoRnn[15];
				zf <= rfoRnn[15:0]==16'h0000;
				rfwrL <= 1'b1;
				Rt <= {Xnx,ir[2:0]};
				resL <= {{16{rfoRnn[15]}},rfoRnn[15:0]};
				ret();
			end
			else begin	// EXT.W
				cf <= 1'b0;
				vf <= 1'b0;
				nf <= rfoRnn[7];
				zf <= rfoRnn[7:0]==8'h00;
				rfwrW <= 1'b1;
				Rt <= {Xnx,ir[2:0]};
				resW <= {rfoRnn[31:16],{8{rfoRnn[7]}},rfoRnn[7:0]};
				ret();
			end
`ifdef SUPPORT_BCD			
		9'b100000???:	// NBCD
			begin
				bcdneg <= 1'b1;
				push(BCD1);
				fs_data(mmm,rrr,FETCH_BYTE,D);
			end
`endif			
		9'b100001000:	// 484x		SWAP
			begin	
				cf <= 1'b0;
				vf <= 1'b0;
				zf <= rfoDnn==32'd0;
				nf <= rfoDnn[15];
				resL <= {rfoDnn[15:0],rfoDnn[31:16]};
				Rt <= {Xnx,rrr};
				rfwrL <= 1'b1;
				ret();
			end
		9'b100001001:	// 484x		Breakpoint
			goto (BREAKPOINT);
		9'b100001???:	// PEA
			begin
				lea <= 1'b1;
				goto (PEA1);
			end
		9'b1010?????:	// TST / TAS
			if (ir==16'h4AFC)	// 4AFC	Illegal
				tIllegal();
			else
				case(sz)
				2'b00:	begin flag_update <= FU_TST; fs_data(mmm,rrr,FETCH_BYTE,D); end
				2'b01:	begin flag_update <= FU_TST; fs_data(mmm,rrr,FETCH_WORD,D); end
				2'b10:	begin flag_update <= FU_TST; fs_data(mmm,rrr,FETCH_LWORD,D); end
				2'b11:	begin push(TAS); fs_data(mmm,rrr,LFETCH_BYTE,D); end		// TAS
				endcase
		9'b11100100?:
			goto (TRAP);
		9'b111001010:
			goto (LINK);
		9'b111001011:
			begin		// UNLK
				sp <= rfoAn;
				dec_unlink <= TRUE;
				goto (UNLNK);
			end
		9'b11100110?:
			if (ir[3]) begin
				ret();
				Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
				rfwrL <= 1'b1;
				resL <= usp;
			end
			else begin
				ret();
				usp <= rfoAn;
			end
		9'b111001110:	// 4E70 RESET
			case(ir[2:0])
			3'b000:	
				if (sf) begin
					rst_o <= 1'b1;
					rst_cnt <= 5'd10;
					ret(); 
				end  
				else
					tPrivilegeViolation();
			3'b001:	ret();	// NOP
			3'b010: 
				if (sf)
					goto (STOP);
				else
					tPrivilegeViolation();
			3'b011: 
				if (sf)
					goto (RTE1);
				else
					tPrivilegeViolation();
			3'b101:
				begin
					ea <= sp;
					sp <= sp + 4'd4;
					ds <= S;
					call (FETCH_LWORD,RTS1);
				end
			3'b110:
				if (vf) begin
	    		isr <= srx;
	    		tf <= 1'b0;
	    		sf <= 1'b1;
			    vecno <= `TRAPV_VEC;
    			goto (TRAP3);
				end
				else
					ret();		// 4E76 TRAPV
			3'b111:	
				begin
					rtr <= 1'b1;
					goto (RTE1); // RTR
				end
			endcase
		9'b111001111:
			case(ir[2:0])
			3'b010:		call(FETCH_IMM16,MOVERc2Rn);
			3'b011:		call(FETCH_IMM16,MOVERn2Rc);
			default:	tIllegal();
			endcase
		9'b111010???:	// JSR		
			begin
				push(JSR);
				fs_data(mmm,rrr,FETCH_LWORD,D);
			end
		9'b111011???:	// JMP
			begin
				push(JMP);
				fs_data(mmm,rrr,FETCH_NOP_LWORD,D);
			end
		9'b1?001????:
			begin
				movemf <= 1'b1;
				if (ir[10])
					call(FETCH_IMM16,MOVEM_s2Xn);
				else
					call(FETCH_IMM16,MOVEM_Xn2D);
			end
		9'b???111???:
			begin // LEA
				lea <= 1'b1;	// ToDo: fix this, lea needs to be set one cycle before fs_data is called
				goto (LEA);
			end
		9'b???110???:
			begin	// CHK
				d <= rfoDn;
				push(CHK);
				fs_data(mmm,rrr,FETCH_WORD,S);
			end
		default:
			tIllegal();
		endcase
//***		4'hF:	state <= RTD1;	// 4Fxx = rtd

//-----------------------------------------------------------------------------
// ADDQ / SUBQ / DBRA / Scc
//-----------------------------------------------------------------------------
	5'h5:
		begin
			casez(ir[7:3])
			// When optimizing DBRA for performance, the memory access cycle to fetch
			// the displacement constant is not done, instead the PC is incremented by
			// two if not doing the DBRA. This is an extra PC increment that increases
			// the code size. It is slower, but more hardware efficient to just always
			// fetch the displacement.
			5'b11001:					// DBRA
`ifdef OPT_PERF			
				if (~takb) begin
					call(FETCH_IMM16,DBRA);
				end
				else begin
					pc <= pc + 32'd4;	// skip over displacement
					ret();
				end
`else
				call(FETCH_IMM16,DBRA);				
`endif				
			5'b11???:		// Scc
				begin
					resL <= {32{takb}};
					resW <= {16{takb}};
					resB <= {8{takb}};
					d <= {32{takb}};
					if (mmm==3'b000) begin
						rfwrB <= 1'b1;
						Rt <= {Xnx,rrr};
						ret();
					end
					else begin
						fs_data(mmm,rrr,STORE_BYTE,S);
					end
				end
			default:
				begin
					case(QQQ)
					3'd0:	begin imm <= 32'd8; immx <= 32'd8; end
					default:	begin imm <= {29'd0,QQQ}; immx <= {29'd0,QQQ}; end
					endcase
					case(sz)
					2'b00:	begin push(ADDQ); fs_data(mmm,rrr,FETCH_BYTE,D); end
					2'b01:	begin push(ADDQ); fs_data(mmm,rrr,FETCH_WORD,D); end
					2'b10:	begin push(ADDQ); fs_data(mmm,rrr,FETCH_LWORD,D); end
					default:	tIllegal();
					endcase
				end
			endcase
		end
		
//-----------------------------------------------------------------------------
// Branches
//-----------------------------------------------------------------------------
	5'h6:
		begin
			opc <= pc + 4'd2;
			begin
				ea <= pc + {{24{ir[7]}},ir[7:1],1'b0} + 4'd2;
				if (ir[11:0]==12'h100) begin		// 6100 = BSR
					bsr <= 1'b1;
					call(FETCH_BRDISP,JSR);
				end
				else if (ir[11:8]==4'h1)	// 61xx = BSR
					goto(JSR);
				else if (takb) begin
					// If branch back to self, trap
				  if (ir[7:0]==8'hFE)
				  	tBadBranchDisp();
					else
`ifdef SUPPORT_B24			
					if (ir[7:0]==8'h00 || ir[0]) begin
`else				
					if (ir[7:0]==8'h00) begin
`endif
						goto(FETCH_BRDISP);
					end
					else if (ir[7:0]==8'hFF)
						call (FETCH_IMM32,FETCH_BRDISP32);
					else begin
						pc <= pc + {{24{ir[7]}},ir[7:1],1'b0} + 4'd2;
						ret();
					end
				end
				else begin
`ifdef SUPPORT_B24			
					if (ir[7:0]==8'h00 || ir[0])		// skip over long displacement
`else
					if (ir[7:0]==8'h00)		// skip over long displacement
`endif			
						pc <= pc + 4'd4;
					else if (ir[7:0]==8'hFF)
						pc <= pc + 4'd6;
					ret();
				end
			end
		end

//-----------------------------------------------------------------------------
// MOVEQ
//-----------------------------------------------------------------------------
	5'h7:
		// MOVEQ only if ir[8]==0, but it is otherwise not used for the 68k.
		// So some decode and fmax is saved by not decoding ir[8]
		//if (ir[8]==1'b0) 
		if (ir[8]) begin
			Xnx <= ir[2:0];
			Rnx <= ir[5:3];
			Nnx <= ir[11:9];
			No <= ir[6];
			rext <= TRUE;
			rext2 <= FALSE;
			ret();
		end
		else begin
			vf <= 1'b0;
			cf <= 1'b0;
			nf <= ir[7];
			zf <= ir[7:0]==8'h00;
			rfwrL <= 1'b1;
			Rt <= {Rnx,ir[11:9]};
			resL <= {{24{ir[7]}},ir[7:0]};
			ret();
		end
//-----------------------------------------------------------------------------
// OR / DIVU / DIVS / SBCD
//-----------------------------------------------------------------------------
	5'h8:
		begin
			casez(ir[11:0])
`ifdef SUPPORT_DIV			
			12'b????_11??_????:	// DIVU / DIVS
				begin
					divs <= ir[8];
					d <= rfoDn;
					push(DIV1);
					fs_data(mmm,rrr,FETCH_WORD,S);
				end
`endif
`ifdef SUPPORT_BCD				
			12'b???1_0000_????:	// SBCD
				begin
					bcdsub <= 1'b1;
					if (ir[3])
						goto (BCD);
					else begin
						s <= rfoDnn;
						d <= rfoDn;
						goto (BCD1);
					end
				end
`endif				
			default:	
				begin
	        case(sz)
	        2'b00:    begin push(OR); fs_data(mmm,rrr,FETCH_BYTE,ir[8]?D:S); end
	        2'b01:    begin push(OR); fs_data(mmm,rrr,FETCH_WORD,ir[8]?D:S); end
	        2'b10:    begin push(OR); fs_data(mmm,rrr,FETCH_LWORD,ir[8]?D:S); end
	        default:	;	// can't get here, picked off by DIV
					endcase
				end
			endcase
		end
//-----------------------------------------------------------------------------
// SUB / SUBA / SUBX
//-----------------------------------------------------------------------------
  5'h9:
    begin
      if (ir[8])
        s <= rfoDn;
      else
        d <= rfoDn;
      if (ir[8] && ir[5:4]==2'b00)
				case(sz)
				2'b00:
					if (ir[3])
						goto (SUBX);
					else begin
						s <= rfoDnn;
						d <= rfoDn;
						goto (SUBX3);
					end
				2'b01:
					if (ir[3])
						goto (SUBX);
					else begin
						s <= rfoDnn;
						d <= rfoDn;
						goto (SUBX3);
					end
				2'b10:
					if (ir[3])
						goto (SUBX);
					else begin
						s <= rfoDnn;
						d <= rfoDn;
						goto (SUBX3);
					end
				2'b11:
	        begin
		        d <= rfoAna;
		        push(SUB);
		        if (ir[8]) fs_data(mmm,rrr,FETCH_LWORD,S);
		        else fs_data(mmm,rrr,FETCH_WORD,S);
	        end
				endcase
      else
	      case(sz)
	      2'b00:    begin push(SUB); fs_data(mmm,rrr,FETCH_BYTE,ir[8]?D:S); end
	      2'b01:    begin push(SUB); fs_data(mmm,rrr,FETCH_WORD,ir[8]?D:S); end
	      2'b10:    begin push(SUB); fs_data(mmm,rrr,FETCH_LWORD,ir[8]?D:S); end
	      2'b11:
	        begin
		        d <= rfoAna;
		        push(SUB);
		        if (ir[8]) fs_data(mmm,rrr,FETCH_LWORD,S);
		        else fs_data(mmm,rrr,FETCH_WORD,S);
	        end
	      endcase
    end
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
  5'hA:
  	if (ir[11:8]==4'h2)
  		goto (IFETCH2);
		else begin
  		isr <= srx;
  		tf <= 1'b0;
  		sf <= 1'b1;
    	vecno <= `LINE10_VEC;
    	goto (TRAP3);
  	end
//-----------------------------------------------------------------------------
// CMP / CMPA / CMPM / EOR
//-----------------------------------------------------------------------------
	5'hB:
		begin
			if (ir[8]) begin	// EOR
				if (mmm==001)
					case(sz)
					2'b00:	begin push(CMPM); fs_data(3'b011,rrr,FETCH_BYTE,S); end
					2'b01:	begin push(CMPM); fs_data(3'b011,rrr,FETCH_WORD,S); end
					2'b10:	begin push(CMPM); fs_data(3'b011,rrr,FETCH_LWORD,S); end
					2'b11:	begin d <= rfoAna; push(CMPA); fs_data(mmm,rrr,FETCH_LWORD,S); end	// CMPA
					endcase
				else
					case(sz)
					2'b00:	begin push(EOR); fs_data(mmm,rrr,FETCH_BYTE,D); end
					2'b01:	begin push(EOR); fs_data(mmm,rrr,FETCH_WORD,D); end
					2'b10:	begin push(EOR); fs_data(mmm,rrr,FETCH_LWORD,D); end
					2'b11:	begin d <= rfoAna; push(CMPA); fs_data(mmm,rrr,FETCH_LWORD,S); end	// CMPA
					endcase
			end
			else	// CMP
				case(sz)
				2'b00:	begin d <= rfoDn; push(CMP); fs_data(mmm,rrr,FETCH_BYTE,S); end
				2'b01:	begin d <= rfoDn; push(CMP); fs_data(mmm,rrr,FETCH_WORD,S); end
				2'b10:	begin d <= rfoDn; push(CMP); fs_data(mmm,rrr,FETCH_LWORD,S); end
				2'b11:	begin d <= rfoAna; push(CMPA); fs_data(mmm,rrr,FETCH_WORD,S); end	// CMPA
				endcase
		end
//-----------------------------------------------------------------------------
// AND / EXG / MULU / MULS / ABCD
//-----------------------------------------------------------------------------
	5'hC:
		begin
			casez(ir[11:0])
`ifdef SUPPORT_BCD			
			12'b???1_0000_????:	// ABCD
				if (ir[3])
					goto (BCD);
				else begin
					s <= rfoDnn;
					d <= rfoDn;
					goto (BCD1);
				end
`endif				
			12'b????_11??_????:	// MULS / MULU
				begin
					push(ir[8] ? MULS1 : MULU1);
					fs_data(mmm,rrr,FETCH_WORD,S);
				end
			12'b???1_0100_0???:	// EXG	Dx,Dy
			begin
				Rt <= {Xnx,DDD};
				rfwrL <= 1'b1;
				resL <= rfoRnn;
				s <= rfoDn;
				goto (EXG1);
			end
			12'b???1_0100_1???:	// EXG Ax,Ay
			begin
				Rt <= {1'b1,AAA};
				rfwrL <= 1'b1;
				resL <= rfoRnn;
				s <= rfoAna;
				goto (EXG1);
			end
			12'b???1_1000_1???:	// EXG Dx,Ay
			begin
				Rt <= {Xnx,DDD};
				rfwrL <= 1'b1;
				resL <= rfoRnn;
				s <= rfoDn;
				goto (EXG1);
			end
			default:
				case(sz)
				2'b00:	begin push(AND); fs_data(mmm,rrr,FETCH_BYTE,ir[8]?D:S); end
				2'b01:	begin push(AND); fs_data(mmm,rrr,FETCH_WORD,ir[8]?D:S); end
				2'b10:	begin push(AND); fs_data(mmm,rrr,FETCH_LWORD,ir[8]?D:S); end
				default:	;	// Can't get here, picked off by MUL
				endcase
			endcase
		end

//-----------------------------------------------------------------------------
// ADD / ADDA / ADDX
//-----------------------------------------------------------------------------
	5'hD:
		begin
			if (ir[8])
				s <= rfoDn;
			else
				d <= rfoDn;
			if (ir[8] && ir[5:4]==2'b00)
				case(sz)
				2'b00:	
					if (ir[3])
						goto (ADDX);
					else begin
						s <= rfoDnn;
						d <= rfoDn;
						goto (ADDX3);
					end
				2'b01:	
					if (ir[3])
						goto (ADDX);
					else begin
						s <= rfoDnn;
						d <= rfoDn;
						goto (ADDX3);
					end
				2'b10:
					if (ir[3])
						goto (ADDX);
					else begin
						s <= rfoDnn;
						d <= rfoDn;
						goto (ADDX3);
					end
				2'b11:
					begin
						d <= rfoAna;
						push(ADD);
						if (ir[8]) fs_data(mmm,rrr,FETCH_LWORD,S);
						else fs_data(mmm,rrr,FETCH_WORD,S);
					end
				endcase
			else
				case(sz)
				2'b00:	begin push(ADD); fs_data(mmm,rrr,FETCH_BYTE,ir[8]?D:S); end
				2'b01:	begin push(ADD); fs_data(mmm,rrr,FETCH_WORD,ir[8]?D:S); end
				2'b10:	begin push(ADD); fs_data(mmm,rrr,FETCH_LWORD,ir[8]?D:S); end
				2'b11:
					begin
						d <= rfoAna;
						push(ADD);
						if (ir[8]) fs_data(mmm,rrr,FETCH_LWORD,S);
						else fs_data(mmm,rrr,FETCH_WORD,S);
					end
				endcase
		end
//-----------------------------------------------------------------------------
// ASL / LSL / ASR / LSR / ROL / ROR / ROXL / ROXR
//-----------------------------------------------------------------------------
	5'hE:
		begin
			casez(ir)
			16'b1110_1000_11??_????,
			16'b1110_1001_11??_????,
			16'b1110_1010_11??_????,
			16'b1110_1011_11??_????,
			16'b1110_1100_11??_????,
			16'b1110_1101_11??_????,
			16'b1110_1110_11??_????,
			16'b1110_1111_11??_????:	goto (IFETCH2);
			default:
				if (sz==2'b11) begin
					cnt <= 6'd1;	// memory shifts only by one
					shift_op <= {ir[8],ir[10:9]};
					push(SHIFT1);
					fs_data(mmm,rrr,FETCH_WORD,D);
				end
				else begin
					shift_op <= {ir[8],ir[4:3]};
					goto (SHIFT1);
					if (ir[5])
						cnt <= rfoDn[5:0];
					else
						cnt <= {2'b0,~|QQQ,QQQ};
					// Extend by a bit for ASL overflow detection.
					resL <= {rfoDnn[31],rfoDnn};
					resB <= {rfoDnn[7],rfoDnn[7:0]};
					resW <= {rfoDnn[15],rfoDnn[15:0]};
					d <= rfoDnn;
				end
			endcase
		end
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
  5'hF:
  	// Switch on co-processor id field
  	case(ir[11:9])
  	3'b000:	// PMMU
  		casez(ir[8:6])
  		3'b00?:	goto (IFETCH2);
	  	3'b01?:
				begin
					if (ir[6])
						call(FETCH_IMM32,PBCC);
					else
						call(FETCH_IMM16,PBCC);
				end
			3'b100: 
				begin
					if (pmmu_any_bpe)
						pmmu_format <= 8'h48;
					else
						pmmu_format <= 8'h28;
					goto(PSAVE);
				end
			3'b101:	goto(PRESTORE);
			default:
				begin
		  		isr <= srx;
		  		tf <= 1'b0;
		  		sf <= 1'b1;
		    	vecno <= `LINE15_VEC;
		    	goto (TRAP3);
		  	end
  		endcase
  	// FPU
  	3'b001:
			if (ir[8:7]==2'b01) begin
				if (ir[6])
					call(FETCH_IMM32,FBCC);
				else
					call(FETCH_IMM16,FBCC);
			end
			else
  			goto (IFETCH2);
  	// PMMU
  	3'b010:
  		if (ir[8])
  			goto (PFLUSH3);
  		else begin
	  		isr <= srx;
	  		tf <= 1'b0;
	  		sf <= 1'b1;
	    	vecno <= `LINE15_VEC;
	    	goto (TRAP3);
	  	end
  	default:
			begin
	  		isr <= srx;
	  		tf <= 1'b0;
	  		sf <= 1'b1;
	    	vecno <= `LINE15_VEC;
	    	goto (TRAP3);
	  	end
	  endcase

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
	5'h1A:
		begin
			ext_ir <= 1'b0;
			if (ir[11:8]==4'h2) begin
				case(ir2[15:0])
				16'h0000:
					begin
						dd32in <= rfoDnn;
						goto (BIN2BCD1);
					end
				16'h0001:
					begin
						d <= rfoDnn;
						goto (BCD2BIN1);
					end
				16'h0003:
					begin
						push(CCHK);
						fs_data(mmm,rrr,FETCH_LWORD,S);
					end
				default:	tIllegal();
				endcase
			end
			else
				tIllegal();
		end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
	5'h1E:
`ifdef SUPPORT_020
		casez(ir)
		16'b1110_1000_11??_????,	// BFTEST
		16'b1110_1001_11??_????,	// BFEXTU
		16'b1110_1010_11??_????,	// BFCHG
		16'b1110_1011_11??_????,	// BFEXTS
		16'b1110_1100_11??_????,	// BFCLR
		16'b1110_1101_11??_????,	// BFFFO
		16'b1110_1110_11??_????,	// BFSET
		16'b1110_1111_11??_????:	// BFINS
			begin
				bfdat <= fnBfdat(ir2[14:12]);
				bfwidth <= fnBfow(ir2[5:0]);
				bfoffs <= fnBfow(ir2[11:6]);
				bfmask <= ((64'd1 << fnBfow(ir2[5:0])) - 64'd1) << fnBfow(ir[11:6]);
				push (BITFLD);
				if ({2'b0,bfoffs} + {2'd0,bfwidth} <= 7'd8) begin
					bf_size <= FETCH_BYTE;
					fs_data(mmm,rrr,FETCH_BYTE,S);
				end
				else if ({2'b0,bfoffs} + {2'd0,bfwidth} <= 7'd16) begin
					bf_size <= FETCH_WORD;
					fs_data(mmm,rrr,FETCH_WORD,S);
				end
				else if ({2'b0,bfoffs} + {2'd0,bfwidth} <= 7'd32) begin
					bf_size <= FETCH_LWORD;
					fs_data(mmm,rrr,FETCH_LWORD,S);
				end
				else begin
					bf_size <= FETCH_OCTA;
					fs_data(mmm,rrr,FETCH_OCTA,S);
				end
			end
		endcase
`else
	tIllegal();		
`endif
		

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
	5'h1F:
		begin
			ext_ir <= 1'b0;
			case(ir[11:9])
			3'b000:	// PMMU
				case(ir2[15:13])
				// PScc
				3'b000:	goto (PSCC);
				// PFLUSH
				3'b001:
					// PVALID?
					if (ir2[12:0]==13'h0800) begin
						lea <= `TRUE;
						goto (PVALID);
					end
					else if (!sf)
						tPrivilegeViolation();
					else
					case(ir2[12:10])
					// PLOAD - do a flush then a load
					3'b000:
						begin
							pload <= 1'b1;
							call (PFLUSH2, PLOAD);
						end
					3'b001:
						begin	// flush all?
							for (n2 = 0; n2 < $size(atc); n2 = n2 + 1)
								atc[n2].v <= 1'b0;
							ret();
						end
					3'b100:	// flush by func code?
						begin
							for (n2 = 0; n2 < $size(atc); n2 = n2 + 1)
								if (atc[n2].v)
									casez(ir2[4:0])
									5'b00000: 
										if ((atc[n2].func & imm[8:5])==(sfc[2:0] & imm[8:5]))
											atc[n2].v <= 1'b0;
									5'b00001:
										if ((atc[n2].func & imm[8:5])==(dfc[2:0] & imm[8:5]))
											atc[n2].v <= 1'b0;
									5'b01???:
										case(ir2[2:0])
										3'b000:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5])) atc[n2].v <= 1'b0;
										3'b001:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5])) atc[n2].v <= 1'b0;
										3'b010:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5])) atc[n2].v <= 1'b0;
										3'b011:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5])) atc[n2].v <= 1'b0;
										3'b100:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5])) atc[n2].v <= 1'b0;
										3'b101:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5])) atc[n2].v <= 1'b0;
										3'b110:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5])) atc[n2].v <= 1'b0;
										3'b111:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5])) atc[n2].v <= 1'b0;
										endcase
									5'b10???:
										if ((atc[n2].func & ir2[8:5])==(ir2[2:0] & ir2[8:5]))
											atc[n2].v <= 1'b0;
									default:	tIllegal();
									endcase
							ret();
						end
					3'b110:
						begin
							lea <= `TRUE;
							goto (PFLUSH1);
						end
					default:	tIllegal();
					endcase
				// PMOVE
				3'b010:
					begin
						if (ir2[9]) begin
							case(ir2[12:10])
							3'b000:	
								begin
									d <= pmmu_tc;
									fs_data(mmm,rrr,STORE_LWORD,D);	// Translation control reg
								end
							3'b001:
								begin
									push(PMOVE1);
									d <= pmmu_dma_root[63:32];
									fs_data(mmm,rrr,STORE_LWORD,D);	// DMA root pointer
								end
							3'b010:	
								begin
									push(PMOVE1);
									d <= pmmu_sys_root[63:32];
									fs_data(mmm,rrr,STORE_LWORD,D);	// System root pointer
								end
							3'b011:
								begin
									push(PMOVE1);
									d <= pmmu_cpu_root[63:32];
									fs_data(mmm,rrr,STORE_LWORD,D);	// CPU root pointer
								end
							3'b100:
								begin
									d <= {4{pmmu_cal}};
									fs_data(mmm,rrr,STORE_BYTE,D);	// Current access level
								end
							3'b101:
								begin
									d <= {4{pmmu_val}};
									fs_data(mmm,rrr,STORE_BYTE,D);	// Valid access level
								end
							3'b110:
								begin
									d <= {4{pmmu_scc}};
									fs_data(mmm,rrr,STORE_BYTE,D);	// Stack change control
								end
							3'b111:
								begin
									d <= {4{pmmu_acr}};
									fs_data(mmm,rrr,STORE_BYTE,D);	// Access control
								end
							endcase
						end
						else
							case(ir2[12:10])
							3'b000:	
								begin
									push(PMOVE1);
									fs_data(mmm,rrr,FETCH_LWORD,S);	// Translation control reg
								end
							3'b001:
								begin
									push(PMOVE1);
									fs_data(mmm,rrr,FETCH_LWORD,S);	// DMA root pointer
								end
							3'b010:
								begin
									push(PMOVE1);
									fs_data(mmm,rrr,FETCH_LWORD,S);	// System root pointer
								end
							3'b011:
								begin
									push(PMOVE1);
									fs_data(mmm,rrr,FETCH_LWORD,S);	// CPU root pointer
								end
							3'b100:
								begin
									push(PMOVE1);
									fs_data(mmm,rrr,FETCH_BYTE,S);	// Current access level
								end
							3'b101:
								begin
									push(PMOVE1);
									fs_data(mmm,rrr,FETCH_BYTE,S);	// Valid access level
								end
							3'b110:
								begin
									push(PMOVE1);
									fs_data(mmm,rrr,FETCH_BYTE,S);	// Stack change control
								end
							3'b111:
								begin
									push(PMOVE1);
									fs_data(mmm,rrr,FETCH_BYTE,S);	// Access control
								end
							endcase
					end
				// PMOVE
				3'b011:
					if (ir2[9])
						case(ir2[12:10])
						3'b000:
							begin
								d <= pmmu_sr;
								fs_data(mmm,rrr,STORE_WORD,D);	// breakpoint data
							end
						3'b001:
							begin
								d <= pmmu_csr;
								fs_data(mmm,rrr,STORE_WORD,D);	// breakpoint data
							end
						3'b100:
							begin
								d <= pmmu_bad[ir2[4:2]];
								fs_data(mmm,rrr,STORE_WORD,D);	// breakpoint data
							end
						3'b101:
							begin
								d <= pmmu_bac[ir2[4:2]];
								fs_data(mmm,rrr,STORE_WORD,D);	// breakpoint data
							end
						default:	tIllegal();
						endcase
					else begin
						casez(ir2[12:10])
						3'b?10:	tIllegal();
						3'b?11:	tIllegal();
						default:
							begin
								push(PMOVE3);
								fs_data(mmm,rrr,FETCH_WORD,S);	// Valid access level
							end
						endcase
					end
				// PTEST
				3'b100:
					begin
						if (sf) begin
							if (!pmmu_tc.E)
								tPMMUIllop();
							else begin
								lea <= 1'b1;
								ptest <= 1'b1;
								goto (PTEST);
							end
						end
						else
							tPrivilegeViolation();
					end
				default:	tIllegal();
				endcase
			3'b001:	// Co-processor #1 (FPU)
			begin
				casez(ir2[15:8])
				8'h6?,8'h7?:	// FMOVE to memory
					begin
						case(ir2[12:10])
						3'b000,3'b100,3'b110:
							begin
								fps <= rfoFpdst;
								goto (DF2I1);
							end
						3'b001:	// single
							begin
								if (SUPPORT_DECFLT)
									d <= dfp96To32o;
								else if (SUPPORT_BINFLT)
									d <= fp96To32o;
								fs_data(mmm,rrr,STORE_LWORD,D);
							end
						3'b101:	// double
							begin
								if (SUPPORT_DECFLT)
									fpd <= dfp96To64o;
								else if (SUPPORT_BINFLT)
									fpd <= fp96To64o;
								fs_data(mmm,rrr,STORE_OCTA,D);
							end
						default:
							begin
								fpd <= rfoFpdst;
								fs_data(mmm,rrr,STORE_HEXI1,D);
							end
						endcase
					end
				8'b10????00:	// PG 4-71
					if (ir2[13])
						case(ir2[7:0])
						8'h00:	// FMOVE
							case(ir2[12:10])
							3'b001:	// FPIAR
								begin
									d <= fpiar;
									fs_data(mmm,rrr,STORE_LWORD,D);
								end
							3'b010:	// FPSR
								begin
									d <= fpsr;
									fs_data(mmm,rrr,STORE_LWORD,D);
								end
							3'b100:	tIllegal();// FPCR
							default:	tIllegal();
							endcase
						default:	tIllegal();
						endcase
					else
						tIllegal();
				8'b11??????:	// FMOVEM
					begin
						fmovem <= 1'b1;
						if (ir2[11]) begin	// dynamic list?
							rrr <= ir2[6:4];
							goto (FMOVEM1);
						end
						else begin
							imm <= ir2[7:0];
							if (ir2[13])
								goto(MOVEM_Xn2D);
							else
								goto(MOVEM_s2Xn);
						end
					end
				8'h0?,8'h1?,8'h2?,8'h3?,8'h4?,8'h5?:
					case(ir2[6:0])
					7'b0000000:	// FMOVE
						if (ir2[14]) begin	// RM from memory
							push(FMOVE1);
							goto(FMOVE);
						end
						else begin
							fps <= rfoFpsrc;
							goto(FMOVE1);
						end
					7'b0000001,	// FINT
					7'b0000011:	// FINTRZ
						if (ir2[14]) begin
							//tIllegal();
							push(FINTRZ1);
							goto(FINTRZ);
						end
						else begin
							fps <= rfoFpsrc;
							goto(FINTRZ1);
						end
					7'b0100000:	// FDIV
						if (ir2[14]) begin	// RM
							fpd <= rfoFpdst;
							push(FDIV1);
							goto(FDIV);
						end
						else begin
							fpd <= rfoFpdst;
							fps <= rfoFpsrc;
							goto(FDIV1);
						end
					7'b0100010:	// FADD
						if (ir2[14]) begin	// RM
							fpd <= rfoFpdst;
							push(FADD1);
							goto(FADD);
						end
						else begin
							fpd <= rfoFpdst;
							fps <= rfoFpsrc;
							goto(FADD1);
						end
					7'b0100011:	// FMUL
						if (ir2[14]) begin	// RM
							fpd <= rfoFpdst;
							push(FMUL1);
							goto(FMUL);
						end
						else begin
							fpd <= rfoFpdst;
							fps <= rfoFpsrc;
							goto(FMUL1);
						end
					7'b0101000:	// FSUB
						if (ir2[14]) begin	// RM
							fsub <= 1'b1;
							fpd <= rfoFpdst;
							push(FADD1);
							goto(FADD);
						end
						else begin
							fsub <= 1'b1;
							fpd <= rfoFpdst;
							fps <= rfoFpsrc;
							goto(FADD1);
						end
					7'b0011000:	// FABS
						if (ir2[14]) begin	// RM
							fabs <= 1'b1;
							push(FNEG1);
							goto(FNEG);
						end
						else begin
							fabs <= 1'b1;
							fps <= rfoFpsrc;
							goto(FNEG1);
						end
					7'b0011010:	// FNEG
						if (ir2[14]) begin	// RM
							push(FNEG1);
							goto(FNEG);
						end
						else begin
							fps <= rfoFpsrc;
							goto(FNEG1);
						end
					7'b0111000:	// FCMP
						if (ir2[14]) begin	// RM
							fpd <= rfoFpdst;
							push(FCMP1);
							goto(FCMP);
						end
						else begin
							fpd <= rfoFpdst;
							fps <= rfoFpsrc;
							goto(FCMP1);
						end
					7'b0111010:	// FTST
						if (ir2[14]) begin
							push (FTST1);
							goto (FTST);
						end
						else begin
							fps <= rfoFpsrc;
							goto (FTST1);
						end
					7'b0100110:	// FSCALE
						if (ir2[14]) begin	// RM
							fpd <= rfoFpdst;
							push(FSCALE1);
							goto(FSCALE);
						end
						else begin
							fpd <= rfoFpdst;
							fps <= rfoFpsrc;
							goto(FSCALE1);
						end
/*						
					7'b0011011:	// FGETEXP2
						begin
							resL <= {18'd0,fpsu.exp};
							rfwrL <= 1'b1;
							Rt <= {1'b0,rrr};
							ret();
						end
*/						
/*						
					7'b0011100:	// FCOPY
						begin
							fps <= rfoFpsrc;
							goto (FCOPYEXP);
						end
*/						
					default:
						tIllegal();
					endcase
				default:
					tIllegal();
				endcase
			end
			default:
				tIllegal();
			endcase
		end
	default: tIllegal();
	endcase
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
`ifdef SUPPORT_010
MOVES:
	begin
		ir2 <= imm[15:0];
		rrrr <= |Nnx ? {Nnx,imm[14:12]} : {2'b00,imm[15:12]};
		Rt <= |Nnx ? {Nnx,imm[14:12]} : {2'b00,imm[15:12]};
		if (imm[11])
			goto (MOVES2);
		else begin
			push(MOVES3);
			use_sfc <= 1'b1;
			case(sz)
			2'd0:	fs_data(mmm,rrr,FETCH_BYTE,S);
			2'd1:	fs_data(mmm,rrr,FETCH_WORD,S);
			2'd2:	fs_data(mmm,rrr,FETCH_LWORD,S);
			endcase
		end
	end
MOVES2:
	begin
		d <= rfoRnn;
		use_dfc <= 1'b1;
		case(sz)
		2'd0:	fs_data(mmm,rrr,STORE_BYTE,D);
		2'd1:	fs_data(mmm,rrr,STORE_WORD,D);
		2'd2:	fs_data(mmm,rrr,STORE_LWORD,D);
		default:	tIllegal();
		endcase
	end
MOVES3:
	begin
		case(sz)
		2'd0:
			begin
				resB <= s[7:0];
				rfwrB <= 1'b1;
			end
		2'd1:
			begin
				resW <= s[15:0];
				rfwrW <= 1'b1;
			end
		2'd2:
			begin
				resL <= s[31:0];
				rfwrL <= 1'b1;
			end
		default:	;
		endcase
		ret();
	end
`endif

//-----------------------------------------------------------------------------
// BCD arithmetic
// ABCD / SBCD / NBCD
//-----------------------------------------------------------------------------
`ifdef SUPPORT_BCD
BCD:
	begin
		push(BCD0);
		fs_data(3'b100,{Xnx,rrr},FETCH_BYTE,S);
	end
BCD0:
	begin
		if (ir[3]) begin
			push(BCD1);
			fs_data(3'b100,{Rnx,RRR},FETCH_BYTE,D);
		end
		else
			goto (BCD1);
	end
BCD1:	goto (BCD2);	// clock to convert BCD to binary.
BCD2:
	begin
		if (bcdsub)
			bcdres <= dbin - sbin - xf;
		else if (bcdneg)
			bcdres <= 8'h00 - dbin - xf;
		else
			bcdres <= dbin + sbin + xf;
		goto (BCD3);
	end
BCD3:	goto (BCD4);	// clock to load binary to BCD conversion
BCD4:
	if (dd_done) begin
		if (ir[3] || (bcdneg && mmm!=3'b000 && mmm != 3'b001))
			goto (STORE_BYTE);
		else begin
			rfwrB <= 1'b1;
			if (bcdneg)
				Rt <= {Xnx,rrr};
			else
				Rt <= {Rnx,RRR};
			resB <= bcdreso[7:0];
			ret();
		end
		d <= bcdreso[7:0];
		cf <= |bcdreso[11:8];
		xf <= |bcdreso[11:8];
		nf <= bcdreso[7];
		if (bcdreso[7:0]!=8'h00)
			zf <= 1'b0;
	end
`endif		

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
STOP:
	begin
		call (FETCH_IMM16, STOP1);
	end
STOP1:
	begin
		cf <= imm[0];
		vf <= imm[1];
		zf <= imm[2];
		nf <= imm[3];
		xf <= imm[4];
		im[0] <= imm[8];
		im[1] <= imm[9];
		im[2] <= imm[10];
		sf <= imm[13];
		tf <= imm[15];
		if (ipl_i > imm[10:8] || ipl_i==3'd7 || imm[15])
			ret();
	end

//-----------------------------------------------------------------------------
// MULU / MULS
// - a couple of regs may be needed.
//-----------------------------------------------------------------------------
MULS1:
	begin
		resMS1 <= $signed(rfoDn[15:0]) * $signed(s[15:0]);
		goto (MULS2);
	end
MULS2:
	begin
		resMS2 <= resMS1;
		goto (MULS3);
	end
MULS3:
	begin
		flag_update <= FU_MUL;
		rfwrL <= 1'b1;
		Rt <= {Rnx,DDD};
		resL <= resMS2;
		ret();
	end
MULU1:
	begin
		resMU1 <= rfoDn[15:0] * s[15:0];
		goto (MULU2);
	end
MULU2:
	begin
		resMU2 <= resMU1;
		goto (MULU3);
	end
MULU3:
	begin
		flag_update <= FU_MUL;
		rfwrL <= 1'b1;
		Rt <= {Rnx,DDD};
		resL <= resMU2;
		ret();
	end

//-----------------------------------------------------------------------------
// DIVU / DIVS
// - the target register is not updated if overflow occurs.
// - the carry flag is always cleared
// - N and Z flags are defined only for valid results
//-----------------------------------------------------------------------------
DIV1:
	if (s[15:0]==16'd0) begin
		isr <= srx;
		tf <= 1'b0;
		sf <= 1'b1;
		cf <= 1'b0;
		vecno <= `DBZ_VEC;
		goto (TRAP3);
	end
	else
		goto (DIV2);
DIV2:
	if (dvdone) begin
		cf <= 1'b0;		// always cleared
		nf <= divq[15];
		zf <= divq[15:0]==16'h0000;
		Rt <= {Rnx,DDD};
		resL <= {divr[15:0],divq[15:0]};
		if (dvovf) begin
			vf <= 1'b1;
		end
		else begin
			vf <= 1'b0;
			rfwrL <= 1'b1;
		end
		ret();
	end

//-----------------------------------------------------------------------------
// NOT
//-----------------------------------------------------------------------------
NOT:
	begin
		resB <= ~d[7:0];
		resW <= ~d[15:0];
		resL <= ~d;
		d <= ~d;
		cf <= 1'b0;
		vf <= 1'b0;
		case(sz)
		2'b00:	begin zf <= d[7:0]==8'hFF; nf <= ~d[7]; end
		2'b01:	begin zf <= d[15:0]==16'hFFFF; nf <= ~d[15]; end
		2'b10:	begin zf <= d[31:0]==32'hFFFFFFFF; nf <= ~d[31]; end
		default:	;
		endcase
		if (mmm==3'b000) begin
			Rt <= {Rnx,rrr};
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
		else if (mmm==3'b001)
			ret();
		else begin
			case(sz)
			2'b00:	begin goto(STORE_BYTE); end
			2'b01:	begin goto(STORE_WORD); end
			2'b10:	begin goto(STORE_LWORD); end
			default:	;
			endcase
		end
	end

//-----------------------------------------------------------------------------
// NEG / NEGX
//-----------------------------------------------------------------------------
NEG:
	begin
		resL <= -d;
		resW <= -d[15:0];
		resB <= -d[7:0];
		d <= -d;
		s <= d;
		dd <= 'd0;
		goto (NEGX1);
	end
NEGX:
	begin
		resL <= -d - xf;
		resW <= -d[15:0] - xf;
		resB <= -d[7:0] - xf;
		d <= -d - xf;
		s <= d + xf;
		dd <= 'd0;
		goto (NEGX1);
	end
NEGX1:
	begin
		case(sz)
		2'b00:	begin cf <= resB[8]; nf <= resB[7]; vf <= fnSubOverflow(resB[7],dd[7],s[7]); zf <= resB[7:0]==8'h00; xf <= resB[8]; end
		2'b01:	begin cf <= resW[16]; nf <= resW[15]; vf <= fnSubOverflow(resW[15],dd[15],s[15]); zf <= resW[15:0]==16'h00; xf <= resW[16]; end
		2'b10:	begin cf <= resL[32]; nf <= resL[31]; vf <= fnSubOverflow(resL[31],dd[31],s[31]); zf <= resL[31:0]==32'h00; xf <= resL[32]; end
		endcase
		if (mmm==3'b000) begin
			Rt <= {Xnx,rrr};
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
		else if (mmm==3'b001)
			ret();
		else
			case(sz)
			2'b00:	begin goto(STORE_BYTE); end
			2'b01:	begin goto(STORE_WORD); end
			2'b10:	begin goto(STORE_LWORD); end
			default:	;
			endcase
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
TAS:
	begin
		resB <= {1'b1,d[6:0]};
		cf <= 1'b0;
		vf <= 1'b0;
		zf <= d[7:0]==8'h00;
		nf <= d[7];
		d <= {1'b1,d[6:0]};
		goto(USTORE_BYTE);
	end

//-----------------------------------------------------------------------------
// Link
//-----------------------------------------------------------------------------
LINK:
	begin
		d <= rfoAn;
		ea <= sp - 4'd4;
		call (STORE_LWORD,LINK1);
	end
LINK1:
	begin
		call(FETCH_IMM16,LINK2);
	end
LINK2:
	begin
		resL <= sp - 32'd4;
		rfwrL <= 1'b1;
		Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
		sp <= sp + imm - 32'd4;
		ret();		
	end

//-----------------------------------------------------------------------------
// LEA
//-----------------------------------------------------------------------------
LEA:
	begin
		push(LEA2);
		fs_data(mmm,rrr,FETCH_NOP_LWORD,S);
	end
LEA2:
	begin
		Rt <= |Rnx ? {Rnx,AAA} : {3'b001,AAA};
		rfwrL <= 1'b1;
		resL <= ea;
		ret();
	end
	
//-----------------------------------------------------------------------------
// PEA
//-----------------------------------------------------------------------------
PEA1:
	begin
		push(PEA2);
		fs_data(mmm,rrr,FETCH_NOP_LWORD,S);
	end
PEA2:
	begin
		d <= ea;
		ea <= sp - 32'd4;
		call (STORE_LWORD,PEA3);
	end
PEA3:
	begin
		sp <= sp - 32'd4;
		ret();
	end

//-----------------------------------------------------------------------------
// DBRA
//-----------------------------------------------------------------------------
DBRA:
`ifndef OPT_PERF
	if (~takb)
`endif
	begin
		resW <= rfoDnn - 4'd1;
		Rt <= {Xnx,rrr};
		rfwrW <= 1'b1;
		if (rfoDnn[15:0]!=0)
			pc <= opc + imm;
		ret();
	end
`ifndef OPT_PERF
	else
		ret();
`endif

//-----------------------------------------------------------------------------
// EXG
//-----------------------------------------------------------------------------
EXG1:
	begin
		rfwrL <= 1'b1;
		resL <= s;
		Rt <= |Xnx ? {Xnx,rrr} : {2'b00,rrrr};
		ret();
	end

//-----------------------------------------------------------------------------
// The destination store for the MOVE instruction.
// Flags are not updated if the target is an address register.
//-----------------------------------------------------------------------------

STORE_IN_DEST:
	begin
		resL <= s;
		resW <= s[15:0];
		resB <= s[7:0];
		d <= s;
		if (ir[8:6]!=3'b001) begin
			case(ir[15:12])
			4'd1:	begin zf <= s[ 7:0]== 8'h00; nf <= s[7]; end
			4'd3:	begin zf <= s[15:0]==16'h00; nf <= s[15]; end
			4'd2:	begin zf <= s[31:0]==32'd0;  nf <= s[31]; end
			default:	;
			endcase
			cf <= 1'b0;
			vf <= 1'b0;
		end
		case(ir[15:12])
		4'd1:	fs_data(MMM,RRR,STORE_BYTE,D);
		4'd2:	fs_data(MMM,RRR,STORE_LWORD,D);
		4'd3:	fs_data(MMM,RRR,STORE_WORD,D);
		default:	;	// cant get here
		endcase
	end


//-----------------------------------------------------------------------------
// Compares
//-----------------------------------------------------------------------------
CMP:
	begin
		flag_update <= FU_CMP;
		case(sz)
		2'b00:	resB <= d[ 7:0] - s[ 7:0];
		2'b01:	resW <= d[15:0] - s[15:0];
		2'b10:	resL <= d[31:0] - s[31:0];
		2'b11:	;
		endcase
		ret();
	end

CMPA:
	begin
		flag_update <= FU_CMP;
		case(ir[8])
		1'b0:	resL <= d[31:0] - {{16{s[15]}},s[15:0]};
		1'b1:	resL <= d[31:0] - s[31:0];
		endcase
		ret();
	end

CMPM:
	begin
		push (CMP);
		case(sz)
		2'd0:	fs_data(3'b011,RRR,FETCH_BYTE,D);
		2'd1:	fs_data(3'b011,RRR,FETCH_WORD,D);
		2'd2:	fs_data(3'b011,RRR,FETCH_LWORD,D);
		default:	;	// cant get here
		endcase
	end

//-----------------------------------------------------------------------------
// Shifts
// Rotate instructions ROL,ROR do not affect the X flag.
//-----------------------------------------------------------------------------
SHIFT1:
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
		// Extend by a bit for ASL overflow detection.
		resB <= {d[7],d[7:0]};
		resW <= {d[15],d[15:0]};
		resL <= {d[31],d[31:0]};
		state <= SHIFT;
	end
SHIFT:
	if (cnt!='d0) begin
		cnt <= cnt - 2'd1;
		case(shift_op)
		3'b000:	// ASR
			case(sz)
			2'b00:	begin resB <= {resB[ 7],resB[ 7:1]}; cf <= resB[0]; xf <= resB[0]; end
			2'b01:	begin resW <= {resW[15],resW[15:1]}; cf <= resW[0]; xf <= resW[0]; end
			2'b10:	begin resL <= {resL[31],resL[31:1]}; cf <= resL[0]; xf <= resL[0]; end
			2'b11:	begin resW <= {resW[15],resW[15:1]}; cf <= resW[0]; xf <= resW[0]; end
			endcase
		3'b001:	// LSR
			case(sz)
			2'b00:	begin resB <= {1'b0,resB[ 7:1]}; cf <= resB[0]; xf <= resB[0]; end
			2'b01:	begin resW <= {1'b0,resW[15:1]}; cf <= resW[0]; xf <= resW[0]; end
			2'b10:	begin resL <= {1'b0,resL[31:1]}; cf <= resL[0]; xf <= resL[0]; end
			2'b11:	begin resW <= {1'b0,resW[15:1]}; cf <= resW[0]; xf <= resW[0]; end
			endcase
		3'b010:	// ROXR
			case(sz)
			2'b00:	begin resB <= {xf,resB[ 7:1]}; cf <= resB[0]; xf <= resB[0]; end
			2'b01:	begin resW <= {xf,resW[15:1]}; cf <= resW[0]; xf <= resW[0]; end
			2'b10:	begin resL <= {xf,resL[31:1]}; cf <= resL[0]; xf <= resL[0]; end
			2'b11:	begin resW <= {xf,resW[15:1]}; cf <= resW[0]; xf <= resW[0]; end
			endcase
		3'b011:	// ROR
			case(sz)
			2'b00:	begin resB <= {resB[0],resB[ 7:1]}; cf <= resB[0]; end
			2'b01:	begin resW <= {resW[0],resW[15:1]}; cf <= resW[0]; end
			2'b10:	begin resL <= {resL[0],resL[31:1]}; cf <= resL[0]; end
			2'b11:	begin resW <= {resW[0],resW[15:1]}; cf <= resW[0]; end
			endcase
		3'b100:	// ASL
			case(sz)
			2'b00:	begin resB <= {resB[ 7:0],1'b0}; cf <= resB[ 7]; xf <= resB[ 7]; if (resB[ 7] != resB[ 8]) vf <= 1'b1; end
			2'b01:	begin resW <= {resW[15:0],1'b0}; cf <= resW[15]; xf <= resW[15]; if (resW[15] != resW[16]) vf <= 1'b1; end
			2'b10:	begin resL <= {resL[31:0],1'b0}; cf <= resL[31]; xf <= resL[31]; if (resL[31] != resL[32]) vf <= 1'b1; end
			2'b11:	begin resW <= {resW[15:0],1'b0}; cf <= resW[15]; xf <= resW[15]; if (resW[15] != resW[16]) vf <= 1'b1; end
			endcase
		3'b101:	// LSL
			case(sz)
			2'b00:	begin resB <= {resB[ 6:0],1'b0}; cf <= resB[ 7]; xf <= resB[ 7]; end
			2'b01:	begin resW <= {resW[14:0],1'b0}; cf <= resW[15]; xf <= resW[15]; end
			2'b10:	begin resL <= {resL[30:0],1'b0}; cf <= resL[31]; xf <= resL[31]; end
			2'b11:	begin resW <= {resW[14:0],1'b0}; cf <= resW[15]; xf <= resW[15]; end
			endcase
		3'b110:	// ROXL
			case(sz)
			2'b00:	begin resB <= {resB[ 6:0],xf}; cf <= resB[ 7]; xf <= resB[ 7]; end
			2'b01:	begin resW <= {resW[14:0],xf}; cf <= resW[15]; xf <= resW[15]; end
			2'b10:	begin resL <= {resL[30:0],xf}; cf <= resL[31]; xf <= resL[31]; end
			2'b11:	begin resW <= {resW[14:0],xf}; cf <= resW[15]; xf <= resW[15]; end
			endcase
		3'b111: // ROL
			case(sz)
			2'b00:	begin resB <= {resB[ 6:0],resB[ 7]}; cf <= resB[ 7]; end
			2'b01:	begin resW <= {resW[14:0],resW[15]}; cf <= resW[15]; end
			2'b10:	begin resL <= {resL[30:0],resL[31]}; cf <= resL[31]; end
			2'b11:	begin resW <= {resW[14:0],resW[15]}; cf <= resW[15]; end
			endcase
		endcase
	end
	else begin
		if (shift_op==3'b100)	// ASL
			case(sz)
			2'b00:	if (resB[ 7] != resB[ 8]) vf <= 1'b1;
			2'b01:	if (resW[15] != resW[16]) vf <= 1'b1;
			2'b10:	if (resL[31] != resL[32]) vf <= 1'b1;
			2'b11:	if (resW[15] != resW[16]) vf <= 1'b1;
			/*
			2'b00:	vf <= resB[ 7] != d[ 7];
			2'b01:	vf <= resW[15] != d[15];
			2'b10:	vf <= resL[31] != d[31];
			2'b11:	vf <= resW[15] != d[15];
			*/
			endcase
		case(sz)
		2'b00:	d <= resB;
		2'b01:	d <= resW;
		2'b10:	d <= resL;
		2'b11:	d <= resW;
		endcase
		Rt <= {Xnx,rrr};
		case(sz)
		2'b00:	begin zf <= resB[7:0]== 8'h00; nf <= resB[ 7]; end
		2'b01:	begin zf <= resW[15:0]==16'h00; nf <= resW[15]; end
		2'b10:	begin zf <= resL[31:0]==32'h00; nf <= resL[31]; end
		2'b11:	begin zf <= resW[15:0]==16'h00; nf <= resW[15]; end
		endcase
		case(sz)
		2'b00:	begin rfwrB <= 1'b1; ret(); end
		2'b01:	begin rfwrW <= 1'b1; ret(); end
		2'b10:	begin rfwrL <= 1'b1; ret(); end
		2'b11:	fs_data(mmm,rrr,STORE_WORD,D);	// word operations only if memory operate
		endcase
	end
	
//-----------------------------------------------------------------------------
// ADD / SUB / ADDA / SUBA / ADDX / SUBX
//-----------------------------------------------------------------------------
ADD:
	begin
		flag_update <= FU_ADD;
		if (sz==2'b11) begin
			flag_update <= FU_NONE;
			Rt <= |Rnx ? {Rnx,AAA} : {3'b001,AAA};
			if (ir[8]) begin
				rfwrL <= 1'b1;
				resL <= d + s;
			end
			else begin
				resW <= d[15:0] + s[15:0];
				rfwrW <= 1'b1;
			end
			d <= d + s;
			dd <= d;
			ret();
		end
		else if (ir[8]) begin
			resB <= d[7:0] + s[7:0];
			resW <= d[15:0] + s[15:0];
			resL <= d + s;
			d <= d + s;
			dd <= d;
			if (mmm==3'd0 || mmm==3'd1) begin
				Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
				case(sz)
				2'b00:	rfwrB <= 1'b1;
				2'b01:	rfwrW <= 1'b1;
				2'b10:	rfwrL <= 1'b1;
				default:	;
				endcase
				ret();
			end
			else begin
				case(sz)
				2'b00:	goto(STORE_BYTE);
				2'b01:	goto(STORE_WORD);
				2'b10:	goto(STORE_LWORD);
				default:	;
				endcase
			end
		end
		else begin
			Rt <= {Rnx,DDD};
			resB <= d[7:0] + s[7:0];
			resW <= d[15:0] + s[15:0];
			resL <= d + s;
			d <= d + s;
			dd <= d;
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
SUB:
	begin
		flag_update <= FU_SUB;
		if (sz==2'b11) begin
			flag_update <= FU_NONE;
			Rt <= |Rnx ? {Rnx,AAA} : {3'b001,AAA};
			if (ir[8]) begin
				rfwrL <= 1'b1;
				resL <= d - s;
			end
			else begin
				resW <= d[15:0] - s[15:0];
				rfwrW <= 1'b1;
			end
			d <= d - s;
			dd <= d;
			ret();
		end
		else if (ir[8]) begin
			resB <= d[7:0] - s[7:0];
			resW <= d[15:0] - s[15:0];
			resL <= d - s;
			d <= d - s;
			dd <= d;
			if (mmm==3'd0 || mmm==3'd1) begin
				Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
				case(sz)
				2'b00:	rfwrB <= 1'b1;
				2'b01:	rfwrW <= 1'b1;
				2'b10:	rfwrL <= 1'b1;
				default:	;
				endcase
				ret();
			end
			else begin
				case(sz)
				2'b00:	goto(STORE_BYTE);
				2'b01:	goto(STORE_WORD);
				2'b10:	goto(STORE_LWORD);
				default:	;
				endcase
			end
		end
		else begin
			Rt <= {Rnx,DDD};
			resB <= d[7:0] - s[7:0];
			resW <= d[15:0] - s[15:0];
			resL <= d - s;
			dd <= d;
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
	end

ADDX:
	begin
		push (ADDX2);
		case(sz)
		2'd0:	fs_data(3'b100,rrr,FETCH_BYTE,S);
		2'd1:	fs_data(3'b100,rrr,FETCH_WORD,S);
		2'd2:	fs_data(3'b100,rrr,FETCH_LWORD,S);
		default:	;
		endcase
	end
ADDX2:
	begin
		push(ADDX3);
		case(sz)
		2'd0:	fs_data(3'b100,RRR,FETCH_BYTE,D);
		2'd1:	fs_data(3'b100,RRR,FETCH_WORD,D);
		2'd2:	fs_data(3'b100,RRR,FETCH_LWORD,D);
		default:	;
		endcase
	end
ADDX3:
	begin
		flag_update <= FU_ADDX;
		resB <= d[ 7:0] + s[ 7:0] + xf;
		resW <= d[15:0] + s[15:0] + xf;
		resL <= d[31:0] + s[31:0] + xf;
		dd <= d;
		d <= d + s + xf;
		if (ir[3])
			case(sz)
			2'b00:	goto(STORE_BYTE);
			2'b01:	goto(STORE_WORD);
			2'b10:	goto(STORE_LWORD);
			default:	;
			endcase
		else begin
			Rt <= {Rnx,RRR};
			case(sz)
			2'd0:	rfwrB <= 1'b1;
			2'd1:	rfwrW <= 1'b1;
			2'd2:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
	end

SUBX:
	begin
		push (SUBX2);
		case(sz)
		2'd0:	fs_data(3'b100,rrr,FETCH_BYTE,S);
		2'd1:	fs_data(3'b100,rrr,FETCH_WORD,S);
		2'd2:	fs_data(3'b100,rrr,FETCH_LWORD,S);
		default:	;
		endcase
	end
SUBX2:
	begin
		push(SUBX3);
		case(sz)
		2'd0:	fs_data(3'b100,RRR,FETCH_BYTE,D);
		2'd1:	fs_data(3'b100,RRR,FETCH_WORD,D);
		2'd2:	fs_data(3'b100,RRR,FETCH_LWORD,D);
		default:	;
		endcase
	end
SUBX3:
	begin
		flag_update <= FU_SUBX;
		resB <= d[7:0] - s[7:0] - xf;
		resW <= d[15:0] - s[15:0] - xf;
		resL <= d[31:0] - s[31:0] - xf;
		dd <= d;
		d <= d - s - xf;
		if (ir[3])
			case(sz)
			2'b00:	goto(STORE_BYTE);
			2'b01:	goto(STORE_WORD);
			2'b10:	goto(STORE_LWORD);
			default:	;
			endcase
		else begin
			Rt <= {Rnx,RRR};
			case(sz)
			2'd0:	rfwrB <= 1'b1;
			2'd1:	rfwrW <= 1'b1;
			2'd2:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
AND:
	begin
		flag_update <= FU_LOGIC;
		if (ir[8]) begin
			resB <= d[7:0] & rfoDn[7:0];
			resW <= d[15:0] & rfoDn[15:0];
			resL <= d & rfoDn;
			d <= d & rfoDn;
			if (mmm==3'd0 || mmm==3'd1) begin
				Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
				case(sz)
				2'b00:	rfwrB <= 1'b1;
				2'b01:	rfwrW <= 1'b1;
				2'b10:	rfwrL <= 1'b1;
				default:	;
				endcase
				ret();
			end
			else begin
				case(sz)
				2'b00:	goto(STORE_BYTE);
				2'b01:	goto(STORE_WORD);
				2'b10:	goto(STORE_LWORD);
				default:	;
				endcase
			end
		end
		else begin
			Rt <= {Rnx,DDD};
			resB <= rfoDn[7:0] & s[7:0];
			resW <= rfoDn[15:0] & s[15:0];
			resL <= rfoDn & s;
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
	end

//-----------------------------------------------------------------------------
// OR
//-----------------------------------------------------------------------------
OR:
	begin
		flag_update <= FU_LOGIC;
		if (ir[8]) begin
			resB <= d[7:0] | rfoDn[7:0];
			resW <= d[15:0] | rfoDn[15:0];
			resL <= d | rfoDn;
			d <= d | rfoDn;
			if (mmm==3'd0 || mmm==3'd1) begin
				Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
				case(sz)
				2'b00:	rfwrB <= 1'b1;
				2'b01:	rfwrW <= 1'b1;
				2'b10:	rfwrL <= 1'b1;
				default:	;	// DIV
				endcase
				ret();
			end
			else begin
				case(sz)
				2'b00:	goto(STORE_BYTE);
				2'b01:	goto(STORE_WORD); 
				2'b10:	goto(STORE_LWORD);
				default:	;	// DIV
				endcase
			end
		end
		else begin
			Rt <= {Rnx,DDD};
			resB <= rfoDn[7:0] | s[7:0];
			resW <= rfoDn[15:0] | s[15:0];
			resL <= rfoDn | s;
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
	end

//-----------------------------------------------------------------------------
// EOR
//-----------------------------------------------------------------------------
EOR:
	begin
		flag_update <= FU_LOGIC;
		resB <= d[7:0] ^ rfoDn[7:0];
		resW <= d[15:0] ^ rfoDn[15:0];
		resL <= d ^ rfoDn;
		d <= d ^ rfoDn;
		if (mmm[2:1]==2'd0) begin
			Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
			ret();
		end
		else begin
			case(sz)
			2'b00:	goto(STORE_BYTE);
			2'b01:	goto(STORE_WORD);
			2'b10:	goto(STORE_LWORD);
			default:	;
			endcase
		end
	end

//-----------------------------------------------------------------------------
// ADDQ / SUBQ
// Flags are not updated if the target is an address register.
// If the target is an address register, the entire register is updated.
//-----------------------------------------------------------------------------
ADDQ:
	begin
		if (ir[8]) begin
			if (mmm!=3'b001)
				flag_update <= FU_SUBQ;
			resL <= d - immx;
			resB <= d[7:0] - immx[7:0];
			resW <= d[15:0] - immx[15:0];
			d <= d - immx;
			dd <= d;
			s <= immx;
		end
		else begin
			if (mmm!=3'b001)
				flag_update <= FU_ADDQ;
			resL <= d + immx;
			resB <= d[7:0] + immx[7:0];
			resW <= d[15:0] + immx[15:0];
			d <= d + immx;
			dd <= d;
			s <= immx;
		end
		if (mmm==3'd0) begin
			ret();
			Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
		end
		// If the target is an address register, the entire register is updated.
		else if (mmm==3'b001) begin
			ret();
			Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
			rfwrL <= 1'b1;
		end
		else
			case(sz)
			2'b00:	goto(STORE_BYTE);
			2'b01:	goto(STORE_WORD);
			2'b10:	goto(STORE_LWORD);
			default:	;	// Scc / DBRA
			endcase
	end

//-----------------------------------------------------------------------------
// ADDI / SUBI / CMPI / ANDI / ORI / EORI
//-----------------------------------------------------------------------------
ADDI:
	case(sz)
	2'b00:	call(FETCH_IMM8,ADDI2);
	2'b01:	call(FETCH_IMM16,ADDI2);
	2'b10:	call(FETCH_IMM32,ADDI2);
	default:	tIllegal();
	endcase
ADDI2:
	begin
	immx <= imm;
	case(sz)
	2'b00:	begin push(ADDI3); fs_data(mmm,rrr,FETCH_BYTE,D); end
	2'b01:	begin push(ADDI3); fs_data(mmm,rrr,FETCH_WORD,D); end
	2'b10:	begin push(ADDI3); fs_data(mmm,rrr,FETCH_LWORD,D); end
	default:	;	// Cant get here
	endcase
	end
ADDI3:
	begin
		flag_update <= FU_ADDI;
		dd <= d;
		s <= immx;
		// Odd numbers are BIT insns.
		case(ir[11:8])
		4'h0:	resL <= d | immx;	// ORI
		4'h2:	resL <= d & immx;	// ANDI
		4'h4:	resL <= d - immx;	// SUBI
		4'h6:	resL <= d + immx;	// ADDI
		4'hA:	resL <= d ^ immx;	// EORI
		4'hC:	resL <= d - immx;	// CMPI
		default:	;
		endcase
		case(ir[11:8])
		4'h0:	resW <= d[15:0] | immx[15:0];	// ORI
		4'h2:	resW <= d[15:0] & immx[15:0];	// ANDI
		4'h4:	resW <= d[15:0] - immx[15:0];	// SUBI
		4'h6:	resW <= d[15:0] + immx[15:0];	// ADDI
		4'hA:	resW <= d[15:0] ^ immx[15:0];	// EORI
		4'hC:	resW <= d[15:0] - immx[15:0];	// CMPI
		default:	;
		endcase
		case(ir[11:8])
		4'h0:	resB <= d[7:0] | immx[7:0];	// ORI
		4'h2:	resB <= d[7:0] & immx[7:0];	// ANDI
		4'h4:	resB <= d[7:0] - immx[7:0];	// SUBI
		4'h6:	resB <= d[7:0] + immx[7:0];	// ADDI
		4'hA:	resB <= d[7:0] ^ immx[7:0];	// EORI
		4'hC:	resB <= d[7:0] - immx[7:0];	// CMPI
		default:	;
		endcase
		case(ir[11:8])
		4'h0:	d <= d | immx;	// ORI
		4'h2:	d <= d & immx;	// ANDI
		4'h4:	d <= d - immx;	// SUBI
		4'h6:	d <= d + immx;	// ADDI
		4'hA:	d <= d ^ immx;	// EORI
		4'hC:	d <= d - immx;	// CMPI
		default:	;
		endcase
		if (ir[11:8]==4'hC)
			ret();
		else if (mmm==3'b000 || mmm==3'b001) begin
			case(sz)
			2'b00:	rfwrB <= 1'b1;
			2'b01:	rfwrW <= 1'b1;
			2'b10:	rfwrL <= 1'b1;
			default:	;
			endcase
			Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
			ret();
		end
		else
			case(sz)
			2'b00:	goto(STORE_BYTE);
			2'b01:	goto(STORE_WORD);
			2'b10:	goto(STORE_LWORD);
			default:	ret();
			endcase
	end

//-----------------------------------------------------------------------------
// ANDI_CCR / ANDI_SR / EORI_CCR / EORI_SR / ORI_CCR / ORI_SR
//-----------------------------------------------------------------------------
//
ANDI_CCR:
	begin flag_update <= FU_ANDI_CCR; goto(FETCH_IMM8); end
ANDI_SR:
	begin flag_update <= FU_ANDI_SR; goto(FETCH_IMM16); end
ANDI_SRX:
	begin flag_update <= FU_ANDI_SRX; goto(FETCH_IMM32); end
EORI_CCR:
	begin flag_update <= FU_EORI_CCR; goto(FETCH_IMM8); end
EORI_SR:
	begin flag_update <= FU_EORI_SR; goto(FETCH_IMM16); end
EORI_SRX:
	begin flag_update <= FU_EORI_SRX; goto(FETCH_IMM32); end
ORI_CCR:
	begin flag_update <= FU_ORI_CCR; goto(FETCH_IMM8); end
ORI_SR:
	begin flag_update <= FU_ORI_SR; goto(FETCH_IMM16); end
ORI_SRX:
	begin flag_update <= FU_ORI_SRX; goto(FETCH_IMM32); end

//-----------------------------------------------------------------------------
// Bit manipulation
//-----------------------------------------------------------------------------
BIT:
	begin
		mmm_save <= mmm;
		if (ir[11:8]==4'h8) begin
			call(FETCH_IMM16,BIT1);
		end
		else begin
			imm <= rfoDn;
			goto(BIT1);
		end
	end
BIT1:
	begin
		bit2test <= imm;
		if (mmm_save==3'b000) begin	// Dn
			goto(BIT2);
			d <= rfob;
		end
		else begin
			push(BIT2);
			// This might fetch an immediate
			// might also alter mmm
			fs_data(mmm,rrr,FETCH_BYTE,D);
		end
	end
// ToDo: Speed this up by a clock cycle by placing the update in IFETCH.
BIT2:
	begin
		// Targets a data register then the size is 32-bit, test is mod 32.
		if (mmm_save==3'b000)
			case(sz)
			2'b00:	// BTST
				begin
`ifdef SUPPORT_BITPAIRS					
					if (bit2test[7]) begin
						zf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b00;
						cf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b01;
						nf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b10;
						vf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b11;
					end
					else
`endif					
						zf <= ~d[bit2test[4:0]];
					ret();
				end
			2'b01:	// BCHG
				begin
`ifdef SUPPORT_BITPAIRS					
					if (bit2test[7]) begin
						zf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b00;
						cf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b01;
						nf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b10;
						vf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b11;
						resL <= d ^ (32'd3 << {bit2test[3:0],1'b0});
					end
					else
`endif					
					begin
						zf <= ~d[bit2test[4:0]];
						resL <= d ^  (32'd1 << bit2test[4:0]);
					end
					rfwrL <= 1'b1;
					Rt <= {Xnx,rrr};
					ret();
				end
			2'b10:	// BCLR
				begin
`ifdef SUPPORT_BITPAIRS					
					if (bit2test[7]) begin
						zf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b00;
						cf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b01;
						nf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b10;
						vf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b11;
						resL <= d & ~(32'd3 << {bit2test[3:0],1'b0});
					end
					else
`endif					
					begin
						zf <= ~d[bit2test[4:0]];
						resL <= d & ~(32'd1 << bit2test[4:0]);
					end
					rfwrL <= 1'b1;
					Rt <= {Xnx,rrr};
					ret();
				end
			2'b11:	// BSET
				begin
`ifdef SUPPORT_BITPAIRS					
					if (bit2test[7]) begin
						zf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b00;
						cf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b01;
						nf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b10;
						vf <= (d >> {bit2test[3:0],1'b0} & 4'd3) == 2'b11;
						resL <= (d & ~(32'd3 << {bit2test[3:0],1'b0})) | (bit2test[5:4] << {bit2test[3:0],1'b0});
					end
					else
`endif					
					begin
						zf <= ~d[bit2test[4:0]];
						resL <= d |  (32'd1 << bit2test[4:0]);
					end
					rfwrL <= 1'b1;
					Rt <= {Xnx,rrr};
					ret();
				end
			endcase
		// Target is memory, size is byte, test is mod 8.
		else
			case(sz)
			2'b00:	// BTST
				begin
`ifdef SUPPORT_BITPAIRS					
					if (bit2test[7]) begin
						zf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b00;
						cf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b01;
						nf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b10;
						vf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b11;
					end
					else
`endif					
						zf <= ~d[bit2test[2:0]];
					ret();
				end
			2'b01:	// BCHG
				begin
`ifdef SUPPORT_BITPAIRS					
					if (bit2test[7]) begin
						zf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b00;
						cf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b01;
						nf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b10;
						vf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b11;
						d <= d ^ (32'd3 << {bit2test[1:0],1'b0});
					end
					else
`endif					
					begin
						zf <= ~d[bit2test[2:0]];
						d <= d ^  (32'd1 << bit2test[2:0]);
					end
					goto(STORE_BYTE);
				end
			2'b10:	// BCLR
				begin
`ifdef SUPPORT_BITPAIRS					
					if (bit2test[7]) begin
						zf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b00;
						cf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b01;
						nf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b10;
						vf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b11;
						d <= d & ~(32'd3 << {bit2test[1:0],1'b0});
					end
					else
`endif					
					begin
						zf <= ~d[bit2test[2:0]];
						d <= d & ~(32'd1 << bit2test[2:0]);
					end
					goto(STORE_BYTE);
				end
			2'b11:	// BSET
				begin
`ifdef SUPPORT_BITPAIRS					
					if (bit2test[7]) begin
						zf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b00;
						cf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b01;
						nf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b10;
						vf <= (d >> {bit2test[1:0],1'b0} & 4'd3) == 2'b11;
						d <= (d & ~(32'd3 << {bit2test[1:0],1'b0})) | (bit2test[5:4] << {bit2test[1:0],1'b0});
					end
					else 
`endif					
					begin
						zf <= ~d[bit2test[2:0]];
						d <= d |  (32'd1 << bit2test[2:0]);
					end
					goto(STORE_BYTE);
				end
			endcase
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
CHK:
	begin
		if (d[15] || $signed(d[15:0]) > $signed(s[15:0])) begin
  		isr <= srx;
  		tf <= 1'b0;
  		sf <= 1'b1;
			vecno <= `CHK_VEC;
	    state <= TRAP3;
		end
		else
			ret();
	end

//-----------------------------------------------------------------------------
// Memory NOP operations - for LEA and PLOAD
//-----------------------------------------------------------------------------
FETCH_NOP_BYTE,FETCH_NOP_WORD,FETCH_NOP_LWORD:
	ret();
STORE_NOP_BYTE:
	ret();

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
FETCH_BRDISP:
/*
		if (fnInCache(pc)) begin
			tFindInCache(pc,disp);
			goto (FETCH_BRDISP1);
		end
		else
*/		
		if (!cyc_o) begin
			pfc_o <= {sf,2'b10};
			pcyc_o <= 1'b1;
			pstb_o <= 1'b1;
			case(pc[1])
			1'b0:	psel_o <= 4'b0011;
			1'b1:	psel_o <= 4'b1100;
			endcase
			padr_o <= pc;
			goto (FETCH_BRDISP_ACK);
		end
FETCH_BRDISP_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 4'b00;
		d <= {16'd0,iri};
		goto (FETCH_BRDISPa);
	end
FETCH_BRDISPa:
	begin
		// Record 'd' for bsr
`ifdef SUPPORT_B24		
		if (ir[0]) begin
			d <= pc + {{9{ir[7]}},ir[7:1],d[15:0],1'b0};
			ea <= pc + {{9{ir[7]}},ir[7:1],d[15:0],1'b0};
		end
		else
`endif		
			d <= pc + {{16{d[15]}},d[15:0]};
			ea <= pc + {{16{d[15]}},d[15:0]};
		// Want to point PC to return after displacement, it will be stacked
		if (bsr)
			pc <= pc + 4'd2;
		// else branch
		else begin
`ifdef SUPPORT_B24			
			if (ir[0])
				pc <= pc + {{9{ir[7]}},ir[7:1],d[15:0],1'b0};
			else
`endif			
				pc <= pc + {{16{d[15]}},d[15:0]};
		end
		goto(WAIT_NACK);
	end
FETCH_BRDISP32:
	begin
		d <= pc + {imm[31:1],1'b0};
		pc <= pc + {imm[31:1],1'b0};
		ea <= pc + {imm[31:1],1'b0};
		goto(WAIT_NACK);
	end

// Fetch 8 bit immediate
//
FETCH_IMM8:
	if (!cyc_o) begin
		pfc_o <= {sf,2'b10};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		case(pc[1])
		1'b0:	psel_o <= 4'b0011;
		1'b1:	psel_o <= 4'b1100;
		endcase
		padr_o <= pc;
		goto (FETCH_IMM8_ACK);
	end
FETCH_IMM8_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 4'b00;
		imm <= {{24{iri[7]}},iri[7:0]};
		if (ds==D)
			d <= {{24{iri[7]}},iri[7:0]};
		else
			s <= {{24{iri[7]}},iri[7:0]};
		goto (FETCH_IMM8a);
	end
FETCH_IMM8a:
	begin
		pc <= pc + 32'd2;
		goto(WAIT_NACK);
	end

// Fetch 16 bit immediate
//
FETCH_IMM16:
	if (!cyc_o) begin
		pfc_o <= {sf,2'b10};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		case(pc[1])
		1'b0:	psel_o <= 4'b0011;
		1'b1:	psel_o <= 4'b1100;
		endcase
		padr_o <= pc;
		goto (FETCH_IMM16_ACK);
	end
FETCH_IMM16_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 4'b00;
		imm <= {{16{iri[15]}},iri};
		if (ds==D)
			d <= {{16{iri[15]}},iri};
		else
			s <= {{16{iri[15]}},iri};
		goto (FETCH_IMM16a);
	end
FETCH_IMM16a:
	begin
		pc <= pc + 32'd2;
		goto(WAIT_NACK);
	end

// Fetch 32 bit immediate
//
FETCH_IMM32:
	if (!cyc_o) begin
		pfc_o <= {sf,2'b10};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		case(pc[1])
		1'b0:	psel_o <= 4'b1111;
		1'b1:	psel_o <= 4'b1100;
		endcase
		padr_o <= pc;
		goto (FETCH_IMM32_ACK);
	end
FETCH_IMM32_ACK:
	if (ack_i) begin
		pstb_o <= 1'b0;
		psel_o <= 4'b00;
		if (pc[1]) begin
`ifdef BIG_ENDIAN
			imm[31:16] <= {dat_i[23:16],dat_i[31:24]};
			if (ds==D)
				d[31:16] <= {dat_i[23:16],dat_i[31:24]};
			else
				s[31:16] <= {dat_i[23:16],dat_i[31:24]};
`else			
      imm[15:0] <= dat_i[31:16];
      if (ds==D)
      	d[15:0] <= dat_i[31:16];
     	else
      	s[15:0] <= dat_i[31:16];
`endif      
		  call(WAIT_NACK,FETCH_IMM32a);
		end
		else begin
`ifdef BIG_ENDIAN
			imm <= rbo(dat_i);
			if (ds==D)
				d <= rbo(dat_i);
			else
				s <= rbo(dat_i);
`else
      imm <= dat_i;
      if (ds==D)
      	d <= dat_i;
      else
      	s <= dat_i;
`endif      
		  pcyc_o <= 1'b0;
		  goto (FETCH_IMM32b);
		end
	end
FETCH_IMM32a:
	if (!stb_o) begin
		pstb_o <= 1'b1;
		psel_o <= 4'b0011;
		padr_o <= pc + 4'd2;
		goto (FETCH_IMM32a_ACK);
	end
FETCH_IMM32a_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 4'b00;
`ifdef BIG_ENDIAN
		imm[15:0] <= {dat_i[7:0],dat_i[15:8]};
		if (ds==D)
			d[15:0] <= {dat_i[7:0],dat_i[15:8]};
		else
			s[15:0] <= {dat_i[7:0],dat_i[15:8]};
`else
		imm[31:16] <= dat_i[15:0];
		if (ds==D)
			d[31:16] <= dat_i[15:0];
		else
			s[31:16] <= dat_i[15:0];
`endif
		goto (FETCH_IMM32b);
	end
FETCH_IMM32b:
	begin
		pc <= pc + 32'd4;
		goto(WAIT_NACK);
	end
	
FETCH_IMM64:
	begin
		call(FETCH_IMM32,FETCH_IMM64b);
	end
FETCH_IMM64b:
	begin
`ifdef BIG_ENDIAN
		fps[63:32] <= imm;
`else
		fps[31: 0] <= imm;
`endif
		call(FETCH_IMM32,FETCH_IMM64c);
	end
FETCH_IMM64c:
	begin
`ifdef BIG_ENDIAN
		fps[31: 0] <= imm;
`else
		fps[63:32] <= imm;
`endif
		ret();
	end

FETCH_IMM96:
	begin
		call(FETCH_IMM32,FETCH_IMM96b);
	end
FETCH_IMM96b:
	begin
`ifdef BIG_ENDIAN
		fps[95:64] <= imm;
`else
		fps[31: 0] <= imm;
`endif
		call(FETCH_IMM32,FETCH_IMM96c);
	end
FETCH_IMM96c:
	begin
`ifdef BIG_ENDIAN
		fps[63:32] <= imm;
`else
		fps[63:32] <= imm;
`endif
		call(FETCH_IMM32,FETCH_IMM96d);
	end
FETCH_IMM96d:
	begin
`ifdef BIG_ENDIAN
		fps[31: 0] <= imm;
`else
		fps[95:64] <= imm;
`endif
		ret();
	end

// Fetch 32 bit displacement
//
FETCH_D32:
	if (!cyc_o) begin
		pfc_o <= {sf,2'b10};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		case(pc[1])
		1'b0:	psel_o <= 4'b1111;
		1'b1:	psel_o <= 4'b1100;
		endcase
		padr_o <= pc;
		goto (FETCH_D32_ACK);
	end
FETCH_D32_ACK:
	if (ack_i) begin
    if (pc[1]) begin
      pstb_o <= 1'b0;
      psel_o <= 4'b0000;
`ifdef BIG_ENDIAN
			disp[31:16] <= {dat_i[23:16],dat_i[31:24]};
`else
      disp[15:0] <= dat_i[31:16];
`endif        
			call (WAIT_NACK,FETCH_D32a);
		end
		else begin
	    pcyc_o <= `LOW;
      pstb_o <= 1'b0;
      psel_o <= 4'b0000;
`ifdef BIG_ENDIAN
			disp <= rbo(dat_i);
`else      
      disp <= dat_i;
`endif      
      goto (FETCH_D32b);
		end
	end
FETCH_D32a:
	if (!stb_o) begin
		pstb_o <= 1'b1;
		psel_o <= 4'b0011;
		padr_o <= pc + 4'd2;
		goto (FETCH_D32a_ACK);
	end
FETCH_D32a_ACK:
	if (ack_i) begin
    pcyc_o <= `LOW;
		pstb_o <= 1'b0;
		psel_o <= 2'b00;
`ifdef BIG_ENDIAN
		disp[15:0] <= {dat_i[7:0],dat_i[15:8]};
`else		
		disp[31:16] <= dat_i[15:0];
`endif		
		goto (FETCH_D32b);
	end
FETCH_D32b:
	begin
		pc <= pc + 4'd4;
		ea <= ea + disp;
		goto(WAIT_NACK);
	end

// Fetch 16 bit displacement
//
FETCH_D16:
	if (!cyc_o) begin
		pfc_o <= {sf,2'b10};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		case(pc[1])
		1'b0:	psel_o <= 4'b0011;
		1'b1:	psel_o <= 4'b1100;
		endcase
		padr_o <= pc;
		goto(FETCH_D16_ACK);
	end
FETCH_D16_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 4'b0;
		disp <= {{16{iri[15]}},iri};
		goto (FETCH_D16a);
	end
FETCH_D16a:
	begin
		pc <= pc + 32'd2;
		ea <= ea + disp;
		goto(WAIT_NACK);
	end

// Fetch index word
//
FETCH_NDX:
	if (!cyc_o) begin
		pfc_o <= {sf,2'b10};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		case(pc[1])
		1'b0:	psel_o <= 4'b0011;
		1'b1:	psel_o <= 4'b1100;
		endcase
		padr_o <= pc;
		goto (FETCH_NDX_ACK);
	end
FETCH_NDX_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 2'b00;
		disp <= {{24{iri[7]}},iri[7:0]};
		mmm <= {2'b00,iri[15]};	// to get reg
		rrr <= iri[14:12];
		wl <= iri[11];
		iis <= iri[2:0];
		bdsz <= iri[5:4];
		index_suppress = iri[6];
		base_suppress = iri[7];
		xword_format = iri[8];
		scale = iri[10:9];
		state <= FETCH_NDXa;
	end
FETCH_NDXa:
	begin
		if (xword_format) begin
			if (SUPPORT_68020) begin
				imm <= 32'd0;
				base_disp <= 32'd0;
				outer_disp <= 32'd0;
				if (base_suppress)
					base_reg <= 32'd0;
				else
					base_reg <= ea;
				ea <= 32'd0;
				if (index_suppress)
					index_reg <= 32'd0;
				else begin
					if (wl)
						index_reg <= rfob << scale;
					else
						index_reg <= {{16{rfob[15]}},rfob[15:0]} << scale;
				end
				case(bdsz)
				2'd0:	tIllegal();
				2'd1: goto (FETCH_NDXb);
				2'd2:	call (FETCH_IMM16,FETCH_NDXb);
				2'd3:	call (FETCH_IMM32,FETCH_NDXb);
				endcase
			end
			else
				tIllegal();
		end
		else begin
			pc <= pc + 32'd2;
			if (wl)
				ea <= ea + rfob + disp;
			else
				ea <= ea + {{16{rfob[15]}},rfob[15:0]} + disp;
		end
		goto(WAIT_NACK);
	end
FETCH_NDXb:
	begin
		case(iis)
		// No indirection
		3'd0:	begin ea <= imm + base_reg + index_reg; ret(); end
		// Indirect pre-indexed with no outer displacement
		3'd1:	begin ea <= imm + base_reg + index_reg; ds <= S; call (FETCH_LWORD,FETCH_NDXc); end
		// Indirect pre-indxed with word outer displacement
		3'd2:	begin base_disp <= imm; call (FETCH_IMM16, FETCH_NDXd); end
		// Indirect pre-indxed with long word outer displacement
		3'd3:	begin base_disp <= imm; call (FETCH_IMM32, FETCH_NDXd); end
		3'd4:	tIllegal();
		// Indirect post-indexed with no outer displacement
		3'd5:	begin ea <= imm + base_reg; call(FETCH_LWORD,FETCH_NDXf); end
		// Indirect post-indexed with word outer displacement
		3'd6:	begin ea <= imm + base_reg; call(FETCH_LWORD,FETCH_NDXg); end
		// Indirect post-indexed with long word outer displacement
		3'd7:	begin ea <= imm + base_reg; call(FETCH_LWORD,FETCH_NDXi); end
		endcase
	end
FETCH_NDXc:
	begin
		ea <= s;
		goto(WAIT_NACK);
	end
FETCH_NDXd:
	begin
		ea <= base_disp + base_reg + index_reg;
		ds <= S;
		call (FETCH_LWORD,FETCH_NDXe);
	end
FETCH_NDXe:
	begin
		ea <= s + imm;
		goto(WAIT_NACK);
	end
FETCH_NDXf:
	begin
		ea <= s + index_reg;
		goto(WAIT_NACK);
	end
FETCH_NDXg:
	begin
		ea <= s + index_reg;
		call (FETCH_IMM16,FETCH_NDXh);
	end
FETCH_NDXh:
	begin
		ea <= ea + imm;
		goto(WAIT_NACK);
	end
FETCH_NDXi:
	begin
		ea <= s + index_reg;
		call (FETCH_IMM32,FETCH_NDXh);
	end

FETCH_BYTE:
	if (!cyc_o) begin
		if (use_sfc)
			pfc_o <= sfc[2:0];
		else if (use_dfc)
			pfc_o <= dfc[2:0];
		else
			pfc_o <= {sf,2'b01};
		pcyc_o <= `HIGH;
		pstb_o <= `HIGH;
		padr_o <= ea;
		case(ea[1:0])
		2'b00:	psel_o <= 4'b0001;
		2'b01:	psel_o <= 4'b0010;
		2'b10:	psel_o <= 4'b0100;
		2'b11:	psel_o <= 4'b1000;
		endcase
		goto (FETCH_BYTE_ACK);
	end
FETCH_BYTE_ACK:
	if (ack_i) begin
		pcyc_o <= `LOW;
		pstb_o <= `LOW;
		psel_o <= 4'b0000;
		if (ds==D) begin
	    case(ea[1:0])
	    2'b00:  d <= {{24{dat_i[7]}},dat_i[7:0]};
	    2'b01:  d <= {{24{dat_i[15]}},dat_i[15:8]};
	    2'b10:  d <= {{24{dat_i[23]}},dat_i[23:16]};
	    2'b11:  d <= {{24{dat_i[31]}},dat_i[31:24]};
	    endcase
		end
		else begin
	    case(ea[1:0])
      2'b00:  s <= {{24{dat_i[7]}},dat_i[7:0]};
      2'b01:  s <= {{24{dat_i[15]}},dat_i[15:8]};
      2'b10:  s <= {{24{dat_i[23]}},dat_i[23:16]};
      2'b11:  s <= {{24{dat_i[31]}},dat_i[31:24]};
      endcase
		end
		goto(WAIT_NACK);
	end

// Fetch byte, but hold onto bus
//
LFETCH_BYTE:
	if (!cyc_o) begin
		if (use_sfc)
			pfc_o <= sfc[2:0];
		else if (use_dfc)
			pfc_o <= dfc[2:0];
		else
			pfc_o <= {sf,2'b01};
		lock_o <= `HIGH;
		cmd_o <= CMD_LOCK;
		pcyc_o <= `HIGH;
		pstb_o <= `HIGH;
		padr_o <= ea;
		case(ea[1:0])
		2'b00:	psel_o <= 4'b0001;
		2'b01:	psel_o <= 4'b0010;
		2'b10:	psel_o <= 4'b0100;
		2'b11:	psel_o <= 4'b1000;
		endcase
		goto (LFETCH_BYTE_ACK);
	end
LFETCH_BYTE_ACK:
	if (ack_i) begin
		cmd_o <= CMD_NONE;
		pstb_o <= 1'b0;
		psel_o <= 4'b0;
		if (ds==D) begin
      case(ea[1:0])
      2'b00:  d <= {{24{dat_i[7]}},dat_i[7:0]};
      2'b01:  d <= {{24{dat_i[15]}},dat_i[15:8]};
      2'b10:  d <= {{24{dat_i[23]}},dat_i[23:16]};
      2'b11:  d <= {{24{dat_i[31]}},dat_i[31:24]};
      endcase
    end
    else begin
      case(ea[1:0])
      2'b00:  s <= {{24{dat_i[7]}},dat_i[7:0]};
      2'b01:  s <= {{24{dat_i[15]}},dat_i[15:8]};
      2'b10:  s <= {{24{dat_i[23]}},dat_i[23:16]};
      2'b11:  s <= {{24{dat_i[31]}},dat_i[31:24]};
      endcase
    end
		goto(WAIT_NACK);
	end

FETCH_WORD:
	if (!cyc_o) begin
		if (use_sfc)
			pfc_o <= sfc[2:0];
		else if (use_dfc)
			pfc_o <= dfc[2:0];
		else
			pfc_o <= {sf,2'b01};
		pcyc_o <= `HIGH;
		pstb_o <= `HIGH;
		padr_o <= ea;
		case(ea[1])
		1'b0:	psel_o <= 4'b0011;
		1'b1:	psel_o <= 4'b1100;
		endcase
		goto (FETCH_WORD_ACK);
	end
FETCH_WORD_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 4'b00;
`ifdef BIG_ENDIAN
		if (ds==D)
		  d <= ea[1] ? {{16{dat_i[23]}},dat_i[23:16],dat_i[31:24]} : {{16{dat_i[7]}},dat_i[7:0],dat_i[15:8]};
		else
		  s <= ea[1] ? {{16{dat_i[23]}},dat_i[23:16],dat_i[31:24]} : {{16{dat_i[7]}},dat_i[7:0],dat_i[15:8]};
`else
		if (ds==D)
		  d <= ea[1] ? {{16{dat_i[31]}},dat_i[31:16]} : {{16{dat_i[15]}},dat_i[15:0]};
		else
		  s <= ea[1] ? {{16{dat_i[31]}},dat_i[31:16]} : {{16{dat_i[15]}},dat_i[15:0]};
`endif		  
		goto(WAIT_NACK);
	end

FETCH_LWORD:
  if (!cyc_o) begin
		if (use_sfc)
			pfc_o <= sfc[2:0];
		else if (use_dfc)
			pfc_o <= dfc[2:0];
		else
			pfc_o <= {sf,2'b01};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		padr_o <= ea;
		case(ea[1])
		1'b0:	psel_o <= 4'b1111;
		1'b1:	psel_o <= 4'b1100;
		endcase
		goto (FETCH_LWORD_ACK);
	end
FETCH_LWORD_ACK:
	if (ack_i) begin
		pstb_o <= 1'b0;
		psel_o <= 4'b00;
		if (ea[1]) begin
`ifdef BIG_ENDIAN
      if (ds==D)
        d[31:16] <= {dat_i[23:16],dat_i[31:24]};
      else
        s[31:16] <= {dat_i[23:16],dat_i[31:24]};
`else			
      if (ds==D)
        d[15:0] <= dat_i[31:16];
      else
        s[15:0] <= dat_i[31:16];
`endif          
  		goto (FETCH_LWORDa);
    end
    else begin
      pcyc_o <= `LOW;
`ifdef BIG_ENDIAN
      if (ds==D)
        d <= rbo(dat_i);
      else
        s <= rbo(dat_i);
`else        
      if (ds==D)
        d <= dat_i;
      else
        s <= dat_i;
`endif            
			goto(WAIT_NACK);
    end
	end
FETCH_LWORDa:
	if (!stb_o) begin
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		padr_o <= ea + 32'd2;
		psel_o <= 4'b0011;
		goto (FETCH_LWORDa_ACK);
	end
FETCH_LWORDa_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 4'b00;
`ifdef BIG_ENDIAN
		if (ds==D)
			d[15:0] <= {dat_i[7:0],dat_i[15:8]};
		else
			s[15:0] <= {dat_i[7:0],dat_i[15:8]};
`else		
		if (ds==D)
			d[31:16] <= dat_i[15:0];
		else
			s[31:16] <= dat_i[15:0];
`endif			
		goto(WAIT_NACK);
	end
WAIT_NACK:
	if (!ack_i)
		ret();

FETCH_OCTA:
	call (FETCH_LWORD,FETCH_OCTA1);
FETCH_OCTA1:
	begin
`ifdef BIG_ENDIAN
		if (ds==S)
			fps[63:32] <= s;
		else
			fpd[63:32] <= d;
`else
		if (ds==S)
			fps[31: 0] <= s;
		else
			fpd[31: 0] <= d;
`endif
		ea <= ea + 4'd4;			
		call (FETCH_LWORD,FETCH_OCTA2);
	end
FETCH_OCTA2:
	begin
`ifdef BIG_ENDIAN
		if (ds==S)
			fps[31:0] <= s;
		else
			fpd[31:0] <= d;
`else
		if (ds==S)
			fps[63:32] <= s;
		else
			fpd[63:32] <= d;
`endif
		ea <= ea - 4'd4;
		goto(WAIT_NACK);
	end

FETCH_HEXI1:
	call (FETCH_LWORD,FETCH_HEXI2);
FETCH_HEXI2:
	begin
`ifdef BIG_ENDIAN
		if (ds==S)
			fps[95:64] <= s;
		else
			fpd[95:64] <= d;
`else
		if (ds==S)
			fps[31: 0] <= s;
		else
			fpd[31: 0] <= d;
`endif
		ea <= ea + 4'd4;			
		call (FETCH_LWORD,FETCH_HEXI3);
	end
FETCH_HEXI3:
	begin
`ifdef BIG_ENDIAN
		if (ds==S)
			fps[63:32] <= s;
		else
			fpd[63:32] <= d;
`else
		if (ds==S)
			fps[63:32] <= s;
		else
			fpd[63:32] <= d;
`endif			
		ea <= ea + 4'd4;
		call (FETCH_LWORD,FETCH_HEXI4);
	end
FETCH_HEXI4:
	begin
`ifdef BIG_ENDIAN
		if (ds==S)
			fps[31: 0] <= s;
		else
			fpd[31: 0] <= d;
`else
		if (ds==S)
			fps[95:64] <= s;
		else
			fpd[95:64] <= d;
`endif
		ea <= ea - 4'd8;			
		goto(WAIT_NACK);
	end

STORE_OCTA:
	begin
`ifdef BIG_ENDIAN
		d <= fpd[63:32];
`else
		d <= fpd[31: 0];
`endif
		call (STORE_LWORD,STORE_OCTA1);
	end
STORE_OCTA1:
	begin
`ifdef BIG_ENDIAN
		d <= fpd[31: 0];
`else
		d <= fpd[63:32];
`endif
		ea <= ea + 4'd4;
		call (STORE_LWORD,STORE_OCTA2);
	end
STORE_OCTA2:
	begin
		ea <= ea - 4'd4;
		goto(WAIT_NACK);
	end

STORE_HEXI1:
	begin
`ifdef BIG_ENDIAN
		d <= fpd[95:64];
`else
		d <= fpd[31: 0];
`endif
		call (STORE_LWORD,STORE_HEXI2);
	end
STORE_HEXI2:
	begin
`ifdef BIG_ENDIAN
		d <= fpd[63:32];
`else
		d <= fpd[63:32];
`endif
		ea <= ea + 4'd4;
		call (STORE_LWORD,STORE_HEXI3);
	end
STORE_HEXI3:
	begin
`ifdef BIG_ENDIAN
		d <= fpd[31: 0];
`else
		d <= fpd[95:32];
`endif
		ea <= ea + 4'd4;
		call (STORE_LWORD,STORE_HEXI4);
	end
STORE_HEXI4:
	begin
		ea <= ea - 4'd8;
		goto(WAIT_NACK);
	end


STORE_BYTE:
	begin
		if (use_sfc)
			pfc_o <= sfc[2:0];
		else if (use_dfc)
			pfc_o <= dfc[2:0];
		else
			pfc_o <= {sf,2'b01};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		pwe_o <= 1'b1;
		padr_o <= ea;
		case(ea[1:0])
		2'b00:	psel_o <= 4'b0001;
		2'b01:	psel_o <= 4'b0010;
		2'b10:	psel_o <= 4'b0100;
		2'b11:	psel_o <= 4'b1000;
		endcase
//		pdat_o <= {4{resB[7:0]}};
		pdat_o <= {4{d[7:0]}};
		goto (STORE_BYTE_ACK);
	end
STORE_BYTE_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		pwe_o <= 1'b0;
		psel_o <= 4'b0;
		goto(WAIT_NACK);
	end

// Store byte and unlock
//
USTORE_BYTE:
	if (!stb_o) begin
		cmd_o <= CMD_UNLOCK;
		if (use_sfc)
			pfc_o <= sfc[2:0];
		else if (use_dfc)
			pfc_o <= dfc[2:0];
		else
			pfc_o <= {sf,2'b01};
		pstb_o <= 1'b1;
		pwe_o <= 1'b1;
		padr_o <= ea;
		case(ea[1:0])
		2'b00:	psel_o <= 4'b0001;
		2'b01:	psel_o <= 4'b0010;
		2'b10:	psel_o <= 4'b0100;
		2'b11:	psel_o <= 4'b1000;
		endcase
//		pdat_o <= {4{resB[7:0]}};
		pdat_o <= {4{d[7:0]}};
		goto (USTORE_BYTE_ACK);
	end
USTORE_BYTE_ACK:
	if (ack_i) begin
		cmd_o <= CMD_NONE;
		lock_o <= 1'b0;
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		pwe_o <= 1'b0;
		psel_o <= 2'b00;
		goto(WAIT_NACK);
	end

STORE_WORD:
	begin
		if (use_sfc)
			pfc_o <= sfc[2:0];
		else if (use_dfc)
			pfc_o <= dfc[2:0];
		else
			pfc_o <= {sf,2'b01};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		pwe_o <= 1'b1;
		padr_o <= ea;
		psel_o <= ea[1] ? 4'b1100 : 4'b0011;
`ifdef BIG_ENDIAN
//		pdat_o <= {2{resW[7:0],resW[15:8]}};
		pdat_o <= {2{d[7:0],d[15:8]}};
`else		
//		pdat_o <= {2{resW[15:0]}};
		pdat_o <= {2{d[15:0]}};
`endif		
		goto (STORE_WORD_ACK);
	end
STORE_WORD_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		pwe_o <= 1'b0;
		psel_o <= 4'b00;
		goto(WAIT_NACK);
	end

STORE_LWORD:
	if (!cyc_o) begin
		if (use_sfc)
			pfc_o <= sfc[2:0];
		else if (use_dfc)
			pfc_o <= dfc[2:0];
		else
			pfc_o <= {sf,2'b01};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		pwe_o <= 1'b1;
		padr_o <= ea;
		psel_o <= ea[1] ? 4'b1100 : 4'b1111;
`ifdef BIG_ENDIAN
//		pdat_o <= ea[1] ? {resL[23:16],resL[31:24],resL[7:0],resL[15:8]} : rbo(resL);
		pdat_o <= ea[1] ? {d[23:16],d[31:24],d[7:0],d[15:8]} : rbo(d);
`else		
//		pdat_o <= ea[1] ? {resL[15:0],resL[31:16]} : resL;
		pdat_o <= ea[1] ? {d[15:0],d[31:16]} : d;
`endif		
		goto(STORE_LWORD2);
	end
STORE_LWORD2:
	if (ack_i) begin
    if (ea[1]) begin
      pstb_o <= 1'b0;
      pwe_o <= 1'b0;
      psel_o <= 4'b00;
      goto(STORE_LWORDa);
		end
		else begin
	    pcyc_o <= `LOW;
      pstb_o <= 1'b0;
      pwe_o <= 1'b0;
      psel_o <= 4'b00;
			goto(WAIT_NACK);
		end
	end

STORE_LWORDa:
	if (!stb_o) begin
		pstb_o <= 1'b1;
		pwe_o <= 1'b1;
		padr_o <= ea + 32'd2;
		psel_o <= 4'b0011;
		goto (STORE_LWORDa_ACK);
	end
STORE_LWORDa_ACK:
	if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		pwe_o <= 1'b0;
		psel_o <= 4'b0000;
		goto(WAIT_NACK);
	end

//----------------------------------------------------
//----------------------------------------------------
RESET:
  begin
    pc <= `RESET_VECTOR;
    padr_o <= 32'h0;
    push(IFETCH);
    goto(TRAP);
	end

//----------------------------------------------------
//----------------------------------------------------
TRAP:
  begin
    goto (TRAP3);
    /*
    if (is_nmi)
        vecno <= `NMI_VEC;
    else
    */
    case(1'b1)
    // group 0
    is_rst:
    	begin
    		is_rst <= 1'b0;
    		tf <= 1'b0;
    		sf <= 1'b1;
    		im <= 3'd7;
    		vecno <= `RESET_VEC;
    		goto(TRAP6);
    	end
    is_adr_err:
    	begin
    		isr <= srx;
    		tf <= 1'b0;
    		sf <= 1'b1;
	    	vecno <= `ADDRERR_VEC;
      	goto (TRAP3);
    	end
    is_bus_err:
    	begin
    		isr <= srx;
    		tf <= 1'b0;
    		sf <= 1'b1;
    		vecno <= `BUSERR_VEC;
      	goto (TRAP3);
    	end
    // group 1
    is_trace:
    	begin
    		isr <= srx;
    		tf <= 1'b0;
    		sf <= 1'b1;
    		vecno <= `TRACE_VEC;
    		is_trace <= 1'b0;
      	goto (TRAP3);
    	end
    is_irq:
    	begin
    		isr <= srx;
    		tf <= 1'b0;
    		sf <= 1'b1;
      	vecno <= `IRQ_VEC + ipl_i;
      	im <= ipl_i;
      	goto (INTA);
    	end
    is_priv:
    	begin
    		isr <= srx;
    		tf <= 1'b0;
    		sf <= 1'b1;
    		is_priv <= 1'b0;
    		vecno <= `PRIV_VEC;
      	goto (TRAP3);
    	end
    is_illegal:
    	begin
    		isr <= srx;
    		tf <= 1'b0;
    		sf <= 1'b1;
    		vecno <= `ILLEGAL_VEC;
      	goto (TRAP3);
    	end
    is_format:
    	begin
    		isr <= srx;
    		tf <= 1'b0;
    		sf <= 1'b1;
    		vecno <= `FORMAT_VEC;
      	goto (TRAP3);
    	end
    default:
    	begin
    		isr <= srx;
//    		tf <= 1'b0;
    		sf <= 1'b1;
      	vecno <= `TRAP_VEC + ir[3:0];
    	end
    endcase
  end
INTA:
  begin
  	pfc_o <= 3'b111;
    pcyc_o <= `HIGH;
    pstb_o <= `HIGH;
    psel_o <= 4'b1111;
    padr_o <= {28'hFFFFFFF,ipl_i,1'b0};
    goto (INTA_ACK);
  end
INTA_ACK:
  if (ack_i|err_i|vpa_i|vpa2_i) begin
    pcyc_o <= `LOW;
    pstb_o <= `LOW;
    psel_o <= 4'b0;
    if (err_i) begin
    	vecno <= `SPURIOUS_VEC;
	  	is_vpa2 <= 1'b0;
	  end
    else if (vpa2_i) begin
    	vector <= dat_i;
    	is_vpa2 <= 1'b1;
    end
    else if (!vpa_i) begin
    	// The same value is on every byte of the data input.
    	vecno <= dat_i[7:0];
	  	is_vpa2 <= 1'b0;
    end
    goto (TRAP3);
  end
TRAP3:
	begin
		// If was in user mode, capture stack pointer in usp.
		if (!isr[13]) begin
			usp <= sp;
			sp <= ssp;
		end
		pid_stack[pid_sp-4'd1] <= cpid;
		pid_sp <= pid_sp - 4'd1;
`ifdef SUPPORT_010
		if (is_bus_err | is_adr_err) begin
   		is_adr_err <= FALSE;
    	is_bus_err <= FALSE;
			goto (TRAP20);
		end
		else
			goto (TRAP3a);
`else
		goto (TRAP3b);
`endif		
	end
// First 16 words of internal state are stored
TRAP20:
	begin
		sp <= sp - 6'd32;
		goto (TRAP21);
	end
// Next instruction input buffer.
TRAP21:
	begin
		d <= ir;
		ea <= sp - 4'd2;
		sp <= sp - 4'd2;
		call (STORE_WORD, TRAP22);
	end
TRAP22:
	begin
		d <= dati_buf;
		ea <= sp - 4'd4;
		sp <= sp - 4'd4;
		call (STORE_LWORD, TRAP23);
	end
TRAP23:
	begin
		d <= dato_buf;
		ea <= sp - 4'd4;
		sp <= sp - 4'd4;
		call (STORE_LWORD, TRAP24);
	end
// 1 word Unused
TRAP24:
	begin
		sp <= sp - 4'd2;
		goto (TRAP25);
	end
TRAP25:
	begin
		d <= bad_addr;
		ea <= sp - 4'd4;
		sp <= sp - 4'd4;
		call (STORE_LWORD, TRAP26);
	end
TRAP26:
	begin
		d <= mac_cycle_type;
		ea <= sp - 4'd2;
		sp <= sp - 4'd2;
		s <= sp - 4'd2;
		call (STORE_WORD, TRAP3a);
	end
// For the 68010 and above push the format word.
TRAP3a:
	begin
`ifdef SUPPORT_010
		if (is_bus_err|is_adr_err) begin
   		is_adr_err <= FALSE;
    	is_bus_err <= FALSE;
			d <= {4'b1000,2'b00,vecno,2'b00};
		end
		else		
			d <= {4'b0000,2'b00,vecno,2'b00};
		ea <= sp - 4'd2;
		sp <= sp - 4'd2;
		call (STORE_WORD, TRAP3b);
`else		
		goto (TRAP3b);
`endif		
	end
// Push the program counter
TRAP3b:
	begin
		d <= pc;
		ea <= sp - 4'd4;
		sp <= sp - 4'd4;
		call (STORE_LWORD, TRAP4);
	end
// And the status register
TRAP4:
	begin
		d <= isr;
		ea <= sp - 4'd2;
		sp <= sp - 4'd2;
		s <= sp - 4'd2;
`ifdef SUPPORT_010
		call (STORE_WORD, TRAP7);
`else		
		call (STORE_WORD, is_bus_err|is_adr_err?TRAP8:TRAP7);
`endif		
	end
// Push IR
TRAP8:
	begin
		d <= ir;
		ea <= sp - 4'd2;
		sp <= sp - 4'd2;
		is_bus_err <= 1'b0;
		is_adr_err <= 1'b0;
		call (STORE_WORD, TRAP9);
	end
// Push bad address
TRAP9:
	begin
		d <= bad_addr;
		ea <= sp - 4'd4;
		sp <= sp - 4'd4;
		call (STORE_LWORD, TRAP10);
	end
TRAP10:
	begin
		d <= mac_cycle_type;
		ea <= sp - 4'd2;
		sp <= sp - 4'd2;
		s <= sp - 4'd2;
		call (STORE_WORD, TRAP7);
	end
// Load SP from vector table
TRAP6:
	begin
		ea <= 32'd0;
		ds <= S;
		call (FETCH_LWORD, TRAP7);
	end
// Load PC from vector table.
TRAP7:
	begin
		sp <= s;
		ssp <= s;
		if (is_vpa2)
			goto (TRAP7a);
		else begin
			ea <= {vbr[31:2]+vecno,2'b00};
			ds <= S;
			call (FETCH_LWORD, TRAP7a);
		end
	end
TRAP7a:
	begin
		if (is_vpa2)
			pc <= vector;
		else
			pc <= s;
		ret();
	end

//----------------------------------------------------
//----------------------------------------------------
/*
JMP_VECTOR:
	if (!cyc_o) begin
		pfc_o <= {sf,2'b01};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		psel_o <= 2'b11;
		padr_o <= vector;
	end
	else if (ack_i) begin
		pstb_o <= 1'b0;
		psel_o <= 2'b00;
		pc[15:0] <= dat_i;
		state <= JMP_VECTOR2;
	end
JMP_VECTOR2:
	if (!stb_o) begin
		pfc_o <= {sf,2'b01};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		psel_o <= 2'b11;
		padr_o <= adr_o + 32'd2;
	end
	else if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		psel_o <= 2'b00;
		pc[31:16] <= dat_i;
		state <= IFETCH;
	end
*/
//----------------------------------------------------
//----------------------------------------------------
UNLNK:
	begin
		ds <= S;
		ea <= sp;
		sp <= sp + 4'd4;
		call (FETCH_LWORD,UNLNK2);
	end
UNLNK2:
	if (dec_unlink) begin
		rfwrL <= 1'b1;
		Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
		resL <= s;
		ret();
	end

//----------------------------------------------------
// JMP / JSR / BSR
//----------------------------------------------------

JMP:
	begin
		pc <= ea;
		ret();
	end
JSR:
	begin
		ea <= sp - 4'd4;
		sp <= sp - 4'd4;
		d <= pc;
		pc <= ea;
		goto (STORE_LWORD);
	end
/*
	if (!cyc_o) begin
		pfc_o <= {sf,2'b01};
		pcyc_o <= 1'b1;
		pstb_o <= 1'b1;
		pwe_o <= 1'b1;
		psel_o <= 4'b1111;
		padr_o <= sp - 32'd4;
`ifdef BIG_ENDIAN
		pdat_o <= rbo(pc);
`else		
		pdat_o <= pc;
`endif		
	end
	else if (ack_i) begin
		pcyc_o <= 1'b0;
		pstb_o <= 1'b0;
		pwe_o <= 1'b0;
		psel_o <= 4'b00;
		sp <= sp - 32'd4;
		pc <= d;
`ifdef SUPPORT_TASK		
`ifdef BIG_ENDIAN		
		if (d[24]) begin
			otr <= tr;
			tr <= d[29:25];
    	reg_copy_mask <= {d[7:0],d[15:8],d[16]};
			goto (THREAD2);
    end
		else
			ret();
`else    	
		if (d[0]) begin
			otr <= tr;
			tr <= d[5:1];
			reg_copy_mask <= d[31:16];
			goto (THREAD2);
		end
		else
			ret();
`endif
`else
		ret();
`endif
	end
*/

//----------------------------------------------------
// RTE / RTR
// Return from exception
//----------------------------------------------------

RTE1:
	begin
		ds <= S;
		ea <= sp;
		sp <= sp + 4'd2;
		call (FETCH_WORD,RTE2);
	end
RTE2:
	begin
		ds <= S;
		ea <= sp;
		sp <= sp + 4'd4;
		cf <= s[0];
		vf <= s[1];
		zf <= s[2];
		nf <= s[3];
		xf <= s[4];
		ccr57 <= s[7:5];
		if (!rtr) begin
			ie_cntdwn <= 3'd3;
			ie_val <= s[10:8];
			//im[0] <= s[8];
			//im[1] <= s[9];
			//im[2] <= s[10];
			sr1112 <= s[12:11];
			sf <= s[13];
			sr14 <= s[14];
			tf <= s[15];
			//pl <= s[31:24];
		end
		call (FETCH_LWORD,RTE3);
	end
RTE3:
	begin
		pc <= s;
`ifdef SUPPORT_010
		ea <= sp;
		if (!rtr) begin
			sp <= sp + 4'd2;
			call (FETCH_WORD,RTE4);
		end
		else begin
			cpid <= pid_stack[pid_sp];
			pid_sp <= pid_sp + 4'd1;
			ret();
		end
`else
		if (!rtr && !sf) begin
			ssp <= sp;
			sp <= usp;
		end		
		cpid <= pid_stack[pid_sp];
		pid_sp <= pid_sp + 4'd1;
		ret();
`endif		
	end
// The core might have been in supervisor mode already when the exception
// occurred. Reset the working stack pointer accordingly.
`ifdef SUPPORT_010
RTE4:
	begin
		if (s[15:12]==4'b1000) begin
			ea <= sp;
			sp <= sp + 4'd2;
			call(FETCH_WORD,RTE5);
		end
		else begin
			if (!sf) begin
				ssp <= sp;
				sp <= usp;	// switch back to user stack
			end
			cpid <= pid_stack[pid_sp];
			pid_sp <= pid_sp + 4'd1;
			ret();
		end
	end
RTE5:
	begin
		mac_cycle_type <= s;
		ea <= sp;
		sp <= sp + 4'd4;
		call(FETCH_LWORD,RTE6);
	end
RTE6:
	begin
		bad_addr <= s;
		ea <= sp;
		sp <= sp + 4'd2;
		call(FETCH_WORD,RTE7);
	end
RTE7:
	begin
		ea <= sp;
		sp <= sp + 4'd4;
		call(FETCH_LWORD,RTE8);
	end
RTE8:
	begin
		dato_buf <= s;
		ea <= sp;
		sp <= sp + 4'd4;
		call(FETCH_LWORD,RTE9);
	end
RTE9:
	begin
		dati_buf <= s;
		ea <= sp;
		sp <= sp + 4'd2;
		call(FETCH_WORD,RTE10);
	end
RTE10:
	begin
		ea <= sp;
		sp <= sp + 6'd32;
		goto (RTE11);
	end
RTE11:
	begin
		if (!sf) begin
			ssp <= sp;
			sp <= usp;	// switch back to user stack
		end
		cpid <= pid_stack[pid_sp];
		pid_sp <= pid_sp + 4'd1;
		ret();
	end
`endif
	
//----------------------------------------------------
// Return from subroutine.
//----------------------------------------------------

RTS1:
	begin
		pc <= s;
		ret();
	end

//----------------------------------------------------
MOVEM_Xn2D:
`ifdef OPT_PERF
	if (imm[15:0]!=16'h0000) begin
		push(MOVEM_Xn2D2);
		fs_data(mmm,rrr,fmovem ? FETCH_NOP_HEXI : ir[6] ? FETCH_NOP_LWORD : FETCH_NOP_WORD,D);
	end
	else
		fs_data(mmm,rrr,fmovem ? FETCH_NOP_HEXI : ir[6] ? FETCH_NOP_LWORD : FETCH_NOP_WORD,D);
`else
	begin
		push(MOVEM_Xn2D2);
		fs_data(mmm,rrr,fmovem ? FETCH_NOP_HEXI : ir[6] ? FETCH_NOP_LWORD : FETCH_NOP_WORD,D);
	end
`endif
MOVEM_Xn2D2:
	begin
		if (imm[15:0]!=16'h0000)
			state <= MOVEM_Xn2D3;
		else begin
			case(mmm)
			3'b100:	// -(An)
				begin
					Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
					resL <= ea + (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
					rfwrL <= 1'b1;
				end
			endcase
			ret();
		end
		if (mmm!=3'b100) begin
			case(flo)
			5'd0: begin imm[0] <= 1'b0; rrrr <= 4'd0; FLTSRC <= 3'd7; end
			5'd1: begin imm[1] <= 1'b0; rrrr <= 4'd1; FLTSRC <= 3'd6; end
			5'd2: begin imm[2] <= 1'b0; rrrr <= 4'd2; FLTSRC <= 3'd5; end
			5'd3: begin imm[3] <= 1'b0; rrrr <= 4'd3; FLTSRC <= 3'd4; end
			5'd4: begin imm[4] <= 1'b0; rrrr <= 4'd4; FLTSRC <= 3'd3; end
			5'd5: begin imm[5] <= 1'b0; rrrr <= 4'd5; FLTSRC <= 3'd2; end
			5'd6: begin imm[6] <= 1'b0; rrrr <= 4'd6; FLTSRC <= 3'd1; end
			5'd7: begin imm[7] <= 1'b0; rrrr <= 4'd7; FLTSRC <= 3'd0; end
			5'd8: begin imm[8] <= 1'b0; rrrr <= 4'd8; end
			5'd9: begin imm[9] <= 1'b0; rrrr <= 4'd9; end
			5'd10: begin imm[10] <= 1'b0; rrrr <= 4'd10; end
			5'd11: begin imm[11] <= 1'b0; rrrr <= 4'd11; end
			5'd12: begin imm[12] <= 1'b0; rrrr <= 4'd12; end
			5'd13: begin imm[13] <= 1'b0; rrrr <= 4'd13; end
			5'd14: begin imm[14] <= 1'b0; rrrr <= 4'd14; end
			5'd15: begin imm[15] <= 1'b0; rrrr <= 4'd15; end
			default:	;
			endcase
			
		end
		else begin
			case(flo)
			5'd0: begin imm[0] <= 1'b0; rrrr <= 4'd15; FLTSRC <= 3'd0; end
			5'd1: begin imm[1] <= 1'b0; rrrr <= 4'd14; FLTSRC <= 3'd1; end
			5'd2: begin imm[2] <= 1'b0; rrrr <= 4'd13; FLTSRC <= 3'd2; end
			5'd3: begin imm[3] <= 1'b0; rrrr <= 4'd12; FLTSRC <= 3'd3; end
			5'd4: begin imm[4] <= 1'b0; rrrr <= 4'd11; FLTSRC <= 3'd4; end
			5'd5: begin	imm[5] <= 1'b0; rrrr <= 4'd10; FLTSRC <= 3'd5; end
			5'd6: begin imm[6] <= 1'b0; rrrr <= 4'd9;	FLTSRC <= 3'd6; end
			5'd7: begin imm[7] <= 1'b0; rrrr <= 4'd8; FLTSRC <= 3'd7; end
			5'd8: begin imm[8] <= 1'b0; rrrr <= 4'd7; end
			5'd9: begin imm[9] <= 1'b0; rrrr <= 4'd6; end
			5'd10: begin imm[10] <= 1'b0; rrrr <= 4'd5; end
			5'd11: begin imm[11] <= 1'b0; rrrr <= 4'd4; end
			5'd12: begin imm[12] <= 1'b0; rrrr <= 4'd3; end
			5'd13: begin imm[13] <= 1'b0; rrrr <= 4'd2; end
			5'd14: begin imm[14] <= 1'b0; rrrr <= 4'd1; end
			5'd15: begin imm[15] <= 1'b0; rrrr <= 4'd0; end
			default:	;
			endcase
			
		end
	end
MOVEM_Xn2D3:
	begin
		resL <= rfoRnn;
		resW <= rfoRnn[15:0];
		if (fmovem)
			fpd <= rfoFpsrc;
		else
			d <= rfoRnn;
		ds <= D;
		call(fmovem ? STORE_HEXI1 : ir[6] ? STORE_LWORD : STORE_WORD,MOVEM_Xn2D4);
	end
MOVEM_Xn2D4:
	begin
		case(mmm)
		// ea is updated by STORE_HEXI1, incremented by 8
		3'b011:	ea <= ea + (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
		3'b100:	ea <= ea - (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
		default:
			ea <= ea + (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
		endcase
		if (imm[15:0]!=16'h0000)
			state <= MOVEM_Xn2D3;
		else begin
			case(mmm)
			3'b011:
				begin
					Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
					resL <= ea + (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
					rfwrL <= 1'b1;
				end
			3'b100:
				begin
					Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
					resL <= ea;
					rfwrL <= 1'b1;
				end
			endcase
			ret();
		end
		if (mmm!=3'b100) begin
//			imm[flo[3:0]] <= 1'b0;
//			rrrr <= flo[3:0];
			case(flo)
			5'd0: begin imm[0] <= 1'b0; rrrr <= 4'd0; FLTSRC <= 3'd7; end
			5'd1: begin imm[1] <= 1'b0; rrrr <= 4'd1; FLTSRC <= 3'd6; end
			5'd2: begin imm[2] <= 1'b0; rrrr <= 4'd2; FLTSRC <= 3'd5;	end
			5'd3: begin imm[3] <= 1'b0; rrrr <= 4'd3; FLTSRC <= 3'd4; end
			5'd4: begin	imm[4] <= 1'b0;	rrrr <= 4'd4;	FLTSRC <= 3'd3;	end
			5'd5: begin	imm[5] <= 1'b0;	rrrr <= 4'd5;	FLTSRC <= 3'd2;	end
			5'd6: begin	imm[6] <= 1'b0;	rrrr <= 4'd6;	FLTSRC <= 3'd1;	end
			5'd7: begin	imm[7] <= 1'b0;	rrrr <= 4'd7;	FLTSRC <= 3'd0;	end
			5'd8: begin	imm[8] <= 1'b0;	rrrr <= 4'd8;	end
			5'd9: begin	imm[9] <= 1'b0;	rrrr <= 4'd9;	end
			5'd10: begin imm[10] <= 1'b0;	rrrr <= 4'd10; end
			5'd11: begin imm[11] <= 1'b0;	rrrr <= 4'd11; end
			5'd12: begin imm[12] <= 1'b0;	rrrr <= 4'd12; end
			5'd13: begin imm[13] <= 1'b0; rrrr <= 4'd13; end
			5'd14: begin imm[14] <= 1'b0; rrrr <= 4'd14; end
			5'd15: begin imm[15] <= 1'b0; rrrr <= 4'd15; end
			default:	;
			endcase
			
		end
		else begin
			case(flo)
			5'd0: begin imm[0] <= 1'b0; rrrr <= 4'd15; FLTSRC <= 3'd0; end
			5'd1: begin	imm[1] <= 1'b0; rrrr <= 4'd14; FLTSRC <= 3'd1; end
			5'd2: begin imm[2] <= 1'b0; rrrr <= 4'd13; FLTSRC <= 3'd2; end
			5'd3: begin imm[3] <= 1'b0;	rrrr <= 4'd12; FLTSRC <= 3'd3; end
			5'd4: begin imm[4] <= 1'b0; rrrr <= 4'd11; FLTSRC <= 3'd4; end
			5'd5: begin imm[5] <= 1'b0; rrrr <= 4'd10; FLTSRC <= 3'd5; end
			5'd6: begin imm[6] <= 1'b0; rrrr <= 4'd9; FLTSRC <= 3'd6; end
			5'd7: begin imm[7] <= 1'b0; rrrr <= 4'd8; FLTSRC <= 3'd7; end
			5'd8: begin imm[8] <= 1'b0; rrrr <= 4'd7; end
			5'd9: begin	imm[9] <= 1'b0; rrrr <= 4'd6; end
			5'd10: begin imm[10] <= 1'b0; rrrr <= 4'd5; end
			5'd11: begin imm[11] <= 1'b0;	rrrr <= 4'd4; end
			5'd12: begin imm[12] <= 1'b0; rrrr <= 4'd3; end
			5'd13: begin imm[13] <= 1'b0; rrrr <= 4'd2; end
			5'd14: begin imm[14] <= 1'b0; rrrr <= 4'd1; end
			5'd15: begin imm[15] <= 1'b0; rrrr <= 4'd0; end
			default:	;
			endcase
			
		end
	end
	
//----------------------------------------------------
MOVEM_s2Xn:
`ifdef OPT_PERF
	if (imm[15:0]!=16'h0000) begin
		push(MOVEM_s2Xn2);
		fs_data(mmm,rrr,fmovem ? FETCH_NOP_HEXI : ir[6] ? FETCH_NOP_LWORD : FETCH_NOP_WORD,S);
	end
	else
		fs_data(mmm,rrr,fmovem ? FETCH_NOP_HEXI : ir[6] ? FETCH_NOP_LWORD : FETCH_NOP_WORD,S);
`else
	begin
		push(MOVEM_s2Xn2);
		fs_data(mmm,rrr,fmovem ? FETCH_NOP_HEXI : ir[6] ? FETCH_NOP_LWORD : FETCH_NOP_WORD,S);
	end
`endif
MOVEM_s2Xn2:
	if (imm[15:0] != 16'h0000) begin
		ds <= S;
		call(fmovem ? FETCH_HEXI1 : ir[6] ? FETCH_LWORD : FETCH_WORD,MOVEM_s2Xn3);
	end
	else begin
		case(mmm)
		3'b011:	// (An)+
			begin
				Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
				resL <= ea;
				rfwrL <= 1'b1;
			end
		3'b100:	// -(An)
			begin
				Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
				resL <= ea + (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
				rfwrL <= 1'b1;
			end
		endcase
		ret();
	end
MOVEM_s2Xn3:
	begin
		case(mmm)
		3'b011:	ea <= ea + (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
		3'b100:	ea <= ea - (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
		default:
			ea <= ea + (fmovem ? 32'd12 : ir[6] ? 32'd4 : 32'd2);
		endcase
		goto (MOVEM_s2Xn2);
		// Another bizzare gotcha. Word values moved to a data register are sign
		// extended to long-word width.
		rfwrL <= 1'b1;
		if (ir[6])
			resL <= s;
		else
			resL <= {{16{s[15]}},s[15:0]};
		resF <= fps;
		if (mmm!=3'b100) begin
			case(flo)
			5'd0: begin imm[0] <= 1'b0; Rt <= 4'd0 ^ {3{fmovem}}; end
			5'd1: begin imm[1] <= 1'b0; Rt <= 4'd1 ^ {3{fmovem}};	end
			5'd2: begin	imm[2] <= 1'b0; Rt <= 4'd2 ^ {3{fmovem}};	end
			5'd3: begin	imm[3] <= 1'b0;	Rt <= 4'd3 ^ {3{fmovem}};	end
			5'd4: begin	imm[4] <= 1'b0;	Rt <= 4'd4 ^ {3{fmovem}};	end
			5'd5: begin	imm[5] <= 1'b0;	Rt <= 4'd5 ^ {3{fmovem}};	end
			5'd6: begin	imm[6] <= 1'b0;	Rt <= 4'd6 ^ {3{fmovem}};	end
			5'd7: begin	imm[7] <= 1'b0;	Rt <= 4'd7 ^ {3{fmovem}};	end
			5'd8: begin	imm[8] <= 1'b0;	Rt <= 4'd8;	end
			5'd9: begin	imm[9] <= 1'b0;	Rt <= 4'd9;	end
			5'd10: begin imm[10] <= 1'b0;	Rt <= 4'd10; end
			5'd11: begin imm[11] <= 1'b0;	Rt <= 4'd11; end
			5'd12: begin imm[12] <= 1'b0;	Rt <= 4'd12; end
			5'd13: begin imm[13] <= 1'b0;	Rt <= 4'd13; end
			5'd14: begin imm[14] <= 1'b0;	Rt <= 4'd14; end
			5'd15: begin imm[15] <= 1'b0; Rt <= 4'd15; end
			default:	;
			endcase
			
		end
		else begin
			case(flo)
			5'd0: begin imm[0] <= 1'b0; Rt <= 4'd15 ^ {4{fmovem}}; end
			5'd1: begin imm[1] <= 1'b0; Rt <= 4'd14 ^ {4{fmovem}}; end
			5'd2: begin	imm[2] <= 1'b0;	Rt <= 4'd13 ^ {4{fmovem}}; end
			5'd3: begin imm[3] <= 1'b0; Rt <= 4'd12 ^ {4{fmovem}}; end
			5'd4: begin imm[4] <= 1'b0; Rt <= 4'd11 ^ {4{fmovem}}; end
			5'd5: begin imm[5] <= 1'b0; Rt <= 4'd10 ^ {4{fmovem}}; end
			5'd6: begin imm[6] <= 1'b0; Rt <= 4'd9 ^ {4{fmovem}}; end
			5'd7: begin imm[7] <= 1'b0;	Rt <= 4'd8 ^ {4{fmovem}}; end
			5'd8: begin	imm[8] <= 1'b0; Rt <= 4'd7;	end
			5'd9: begin imm[9] <= 1'b0; Rt <= 4'd6; end
			5'd10: begin imm[10] <= 1'b0; Rt <= 4'd5; end
			5'd11: begin imm[11] <= 1'b0; Rt <= 4'd4; end
			5'd12: begin imm[12] <= 1'b0;	Rt <= 4'd3; end
			5'd13: begin imm[13] <= 1'b0; Rt <= 4'd2; end
			5'd14: begin imm[14] <= 1'b0; Rt <= 4'd1; end
			5'd15: begin imm[15] <= 1'b0; Rt <= 4'd0; end
			endcase
			
		end
	end
//----------------------------------------------------
RETSTATE:
	ret();

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
MOVEP:
	if (!cyc_o) begin
		pcyc_o <= `HIGH;
		pstb_o <= `HIGH;
		pwe_o <= ir[7];
		casez({ir[7],ea[1:0]})
		3'b0??:	psel_o <= 4'b1111;
		3'b100:	psel_o <= 4'b0001;
		3'b101:	psel_o <= 4'b0010;
		3'b110:	psel_o <= 4'b0100;
		3'b111:	psel_o <= 4'b1000;
		endcase
		padr_o <= ea;
		if (ir[6])
			pdat_o <= {4{rfoDn[31:24]}};
		else
			pdat_o <= {4{rfoDn[15:8]}};
	end
	else if (ack_i) begin
		pstb_o <= `LOW;
		if (ir[6])
			resL[31:24] <= dat_i >> {ea[1:0],3'b0};
		else
			resW[15:8] <= dat_i >> {ea[1:0],3'b0};
		goto (MOVEP1);
	end
MOVEP1:
	if (!stb_o) begin
		pstb_o <= `HIGH;
		pwe_o <= ir[7];
		casez({ir[7],~ea[1],ea[0]})
		3'b0??:	psel_o <= 4'b1111;
		3'b100:	psel_o <= 4'b0001;
		3'b101:	psel_o <= 4'b0010;
		3'b110:	psel_o <= 4'b0100;
		3'b111:	psel_o <= 4'b1000;
		endcase
		padr_o <= ea + 4'd2;
		if (ir[6])
			pdat_o <= {4{rfoDn[23:16]}};
		else
			pdat_o <= {4{rfoDn[7:0]}};
	end
	else if (ack_i) begin
		pstb_o <= `LOW;
		if (ir[6])
			resL[23:16] <= dat_i >> {ea[1:0]+4'd2,3'b0};
		else
			resW[7:0] <= dat_i >> {ea[1:0]+4'd2,3'b0};
		Rt <= {Rnx,DDD};
		if (ir[6])
			goto (MOVEP2);
		else begin
			pcyc_o <= `LOW;
			pwe_o <= `LOW;
			psel_o <= 4'h0;
			rfwrW <= ~ir[7];
			ret();
		end
	end
MOVEP2:
	if (!stb_o) begin
		pstb_o <= `HIGH;
		pwe_o <= ir[7];
		casez({ir[7],ea[1:0]})
		3'b0??:	psel_o <= 4'b1111;
		3'b100:	psel_o <= 4'b0001;
		3'b101:	psel_o <= 4'b0010;
		3'b110:	psel_o <= 4'b0100;
		3'b111:	psel_o <= 4'b1000;
		endcase
		padr_o <= ea + 4'd4;
		pdat_o <= {4{rfoDn[15:8]}};
	end
	else if (ack_i) begin
		pstb_o <= `LOW;
		resL[15:8] <= dat_i >> {ea[1:0],3'b0};
		goto (MOVEP3);
	end
MOVEP3:
	if (!stb_o) begin
		pstb_o <= `HIGH;
		pwe_o <= ir[7];
		casez({ir[7],~ea[1],ea[0]})
		3'b0??:	psel_o <= 4'b1111;
		3'b100:	psel_o <= 4'b0001;
		3'b101:	psel_o <= 4'b0010;
		3'b110:	psel_o <= 4'b0100;
		3'b111:	psel_o <= 4'b1000;
		endcase
		padr_o <= ea + 4'd6;
		pdat_o <= {4{rfoDn[7:0]}};
	end
	else if (ack_i) begin
		pcyc_o <= `LOW;
		pstb_o <= `LOW;
		pwe_o <= `LOW;
		psel_o <= 4'h0;
		resL[7:0] <= dat_i >> {ea[1:0]+4'd2,3'b0};
		Rt <= {Rnx,DDD};
		rfwrL <= ~ir[7];
		ret();
	end


FSDATA2:
	fs_data2(mmmx,rrrx,sz_state,dsix);

// On a retry, wait some random number of cycle before retrying the bus
// operation.
`ifdef SUPPORT_RETRY
RETRY:
	begin
		cnt <= {lfsr_o[3:0] + 4'd8};
		goto (RETRY2);
	end
RETRY2:
	begin
		cnt <= cnt - 2'd1;
		if (cnt=='d0)
			goto (rstate);
	end
`endif

MOVERn2Rc:
	begin
		rrrr <= imm[15:12];
		goto (MOVERn2Rc2);
	end
MOVERn2Rc2:
	case(imm[11:0])
	12'h000:	begin sfc <= rfoRnn; ret(); end
	12'h001:	begin dfc <= rfoRnn; ret(); end
	12'h003:  begin asid <= rfoRnn[7:0]; ret(); end
	12'h010:  begin apc <= rfoRnn; ret(); end
	12'h011:  begin cpl <= rfoRnn[7:0]; ret(); end
	12'h012:  begin tr <= rfoRnn; ret(); end
	12'h013:  begin tcba <= rfoRnn; ret(); end
	12'h014:	begin mmus <= rfoRnn; ret(); end
	12'h015:	begin ios <= rfoRnn; ret(); end
	12'h016:	begin iops <= rfoRnn; ret(); end
	12'h017:	begin cpid <= rfoRnn[15:0]; ret(); end
	12'h020:	begin canary <= rfoRnn; ret(); end
	12'h800:	begin usp <= rfoRnn; ret(); end
	12'h801:	begin vbr <= rfoRnn; ret(); end
/*	
	12'hFE1:
		begin
			cf <= rfoRnn[0];
			vf <= rfoRnn[1];
			zf <= rfoRnn[2];
			nf <= rfoRnn[3];
			xf <= rfoRnn[4];
			ccr57 <= rfoRnn[7:5];
			if (!rtr) begin
				im[0] <= rfoRnn[8];
				im[1] <= rfoRnn[9];
				im[2] <= rfoRnn[10];
				sr1112 <= rfoRnn[12:11];
				sf <= rfoRnn[13];
				sr14 <= rfoRnn[14];
				tf <= rfoRnn[15];
				//pl <= rfoRnn[31:24];
			end
//			tr <= rfoRnn[23:16];
//			pl <= rfoRnn[31:24];
		end
*/		
	default:	tIllegal();
	endcase
MOVERc2Rn:
	case(imm[11:0])
	12'h000:	begin resL <= sfc; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h001:	begin resL <= dfc; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h003:  begin resL <= {24'h0,asid}; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h010:  begin resL <= apc; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h011:  begin resL <= {24'h0,cpl}; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h012:  begin resL <= tr; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h013:  begin resL <= tcba; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h014:  begin resL <= mmus; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h015:  begin resL <= ios; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h016:  begin resL <= iops; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h017:  begin resL <= {16'h0,cpid}; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h018:  begin resL <= {16'h0,npid}; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h020:  begin resL <= canary; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h800:	begin resL <= usp; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'h801:	begin resL <= vbr; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'hFE0:	begin resL <= coreno_i; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
//	12'hFE1:	begin resL <= srx; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'hFF0:	begin resL <= tick; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	12'hFF8:	begin resL <= icnt; Rt <= imm[15:12]; rfwrL <= 1'b1; ret(); end
	default:	tIllegal();
	endcase

BIN2BCD1:
	goto (BIN2BCD2);
BIN2BCD2:
	if (dd32done) begin
		zf <= dd32in==32'h0;
		vf <= dd32out[39:32]!=8'h00;
		resL <= dd32out[31:0];
		rfwrL <= 1'b1;
		Rt <= {Xnx,rrr};
		ret();
	end
BCD2BIN1:
	begin
		(* USE_DSP = "no" *)
		resL1 <= d[3:0] +
		     d[7:4] * 4'd10 +
		     d[11:8] * 7'd100 +
		     d[15:12] * 10'd1000 +
		     d[19:16] * 14'd10000 +
		     d[23:20] * 17'd100000 +
		     d[27:24] * 20'd1000000 +
		     d[31:28] * 24'd10000000
		     ;
		goto (BCD2BIN2);
	end
BCD2BIN2:
	begin
		resL2 <= resL1;
		goto (BCD2BIN3);
	end
BCD2BIN3:
	begin
		resL <= resL2;
		rfwrL <= 1'b1;
		Rt <= {Xnx,rrr};
		ret();
	end
CCHK:
	begin
		if (s != canary) begin
  		isr <= srx;
  		tf <= 1'b0;
  		sf <= 1'b1;
			vecno <= `CHK_VEC;
	    goto (TRAP3);
		end
		else
			ret();
	end
FADD:
	begin
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_HEXI1,S);
		endcase
	end
FADD1:
	begin
		fpcnt <= fpcnt + 2'd1;
		if (SUPPORT_DECFLT) begin
			if (fpcnt>=12'd300) begin
				fzf <= dfaddsubo[94:0]==95'd0;
				fnf <= dfaddsubo[95];
				fvf <= dfaddsubo[94:90]==5'b11110;
				fnanf <= dfaddsubo[94:90]==5'b11111;
				resF <= dfaddsubo;
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
				ret();
			end
		end
		else if (SUPPORT_BINFLT) begin
			if (fpcnt==8'd50) begin
				fzf <= dfmao[94:0]==95'd0;
				fnf <= dfmao[95];
				fvf <= dfmao_overflow;
				fnanf <= dfmao_nan;
				resF <= dfmao;
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
				ret();
			end
		end
	end
FINTRZ:
	begin
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_HEXI1,S);
		endcase
	end
FINTRZ1:	// Also FINT
	begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt>=8'd6) begin
			if (SUPPORT_DECFLT) begin
				resF <= dftrunco;
				fzf <= dftrunco[94:0]==95'd0;
				fnf <= dftrunco[95];
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
			end
			else if (SUPPORT_BINFLT) begin
				resF <= dtrunco;
				fzf <= dtrunco[95:0]==95'd0;
				fnf <= dtrunco[95];
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
			end
			ret();
		end
	end
FSCALE:
	begin
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_LWORD,S);	// ToDo: convert to int first
		endcase
	end
FSCALE1:
	begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt==8'd20) begin
			if (SUPPORT_DECFLT) begin
				fzf <= dfscaleo[94:0]==95'd0;
				fnf <= dfscaleo[95];
				fvf <= dfscaleo[94:90]==5'b11110;
				fnanf <= dfscaleo[94:90]==5'b11111;
				resF <= dfscaleo;
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
			end
			else if (SUPPORT_BINFLT) begin
				fzf <= dscaleo[94:0]==95'd0;
				fnf <= dscaleo[95];
				fvf <= dscaleo_overflow;
				fnanf <= dscaleo_nan;
				resF <= dscaleo;
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
			end
			ret();
		end
	end
FNEG:
	begin
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_HEXI1,S);
		endcase
	end
FNEG1:	// Also FABS
	begin
		if (SUPPORT_DECFLT) begin
			resF <= {~fps[95] & ~fabs,fps[94:0]};
			fzf <= fps[94:0]==95'd0;
			fnf <= ~fps[95] & ~fabs;
			Rt <= {1'b0,FLTDST};
			rfwrF <= 1'b1;
		end
		else if (SUPPORT_BINFLT) begin
			resF <= {~fps[95] & ~fabs,fps[94:0]};
			fzf <= fps[94:0]==95'd0;
			fnf <= ~fps[95] & ~fabs;
			Rt <= {1'b0,FLTDST};
			rfwrF <= 1'b1;
		end
		ret();
	end
FMUL:
	begin
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_HEXI1,S);
		endcase
	end	
FMUL1:
	begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt==8'd6)
			goto (FMUL2);
	end
FMUL2:
	if (SUPPORT_DECFLT) begin
		if (dfmuldone) begin
			fzf <= dfmulo[94:0]==95'd0;
			fnf <= dfmulo[95];
			fvf <= dfmulo[94:90]==5'b11110;
			fnanf <= dfmulo[94:90]==5'b11111;
			resF <= dfmulo;
			Rt <= {1'b0,FLTDST};
			rfwrF <= 1'b1;
			ret();
		end
	end
	else if (SUPPORT_BINFLT) begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt >= 8'd50) begin
			fzf <= dfmao[94:0]==95'd0;
			fnf <= dfmao[95];
			fvf <= dfmao[94:80]==15'h7fff && dfmao[79:0]==80'd0;
			fnanf <= dfmao[94:80]==15'h7fff && dfmao[79:0]!=80'd0;
			resF <= dfmao;
			Rt <= {1'b0,FLTDST};
			rfwrF <= 1'b1;
			ret();
		end
	end
	else
		ret();
	// For divide the done signal may take several cycles to go inactive after
	// the load signal is activated. Prevent a premature recognition of done
	// using a counter.
FDIV:
	begin	
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_HEXI1,S);
		endcase
	end
FDIV1:
	begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt == 8'd6) begin
			fpcnt <= 8'd0;
			goto (FDIV2);
		end
	end
FDIV2:
	begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt == 8'd45)
			goto (FDIV3);
	end
FDIV3:
	if (SUPPORT_DECFLT) begin
		if (dfdivdone) begin
			fzf <= dfdivo[94:0]==95'd0;
			fnf <= dfdivo[95];
			fvf <= dfdivo[94:90]==5'b11110;
			fnanf <= dfdivo[94:90]==5'b11111;
			resF <= dfdivo;
			Rt <= {1'b0,FLTDST};
			rfwrF <= 1'b1;
			quotient_bits <= {dfdivo[95],dfdivo[6:0]};
			quotient_bitshi <= {dfdivo[9:7]};
			ret();
		end
	end
	else if (SUPPORT_BINFLT) begin
		if (ddiv_done) begin
			fzf <= ddivo[94:0]==95'd0;
			fnf <= ddivo[95];
			fvf <= ddivo[94:80]==15'h7fff && ddivo[79:0]==80'd0;
			fnanf <= ddivo[94:80]==15'h7fff && ddivo[79:0]!=80'd0;
			resF <= ddivo;
			Rt <= {1'b0,FLTDST};
			rfwrF <= 1'b1;
			quotient_bits <= {ddivo[95],ddivo[6:0]};
			quotient_bitshi <= {ddivo[9:7]};
			ret();
		end
	end
FCVTI1:
	begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt>=8'd7)
			goto (FCVTI2);
		case(ir2[12:10])
		3'b000:	fps <= {64'd0,s[31:0]};
		3'b001:	fps <= {64'd0,s[31:0]};
		3'b100:	fps <= {80'd0,s[15:0]};
		3'b110:	fps <= {88'd0,s[7:0]};
		default:	fps <= fps;
		endcase
	end
FCVTI2:
	begin
		case(ir2[12:10])
		3'b000,3'b100,3'b110:
			if (i2dfdone) begin
				if (SUPPORT_DECFLT)
					fps <= i2dfo;
				else if (SUPPORT_BINFLT)
					fps <= i2do;
				ret();
			end
		3'b001:
			begin
				if (SUPPORT_DECFLT)
					fps <= dfp32To96;
				else if (SUPPORT_BINFLT)
					fps <= s2xdo;
				ret();
			end
		3'b101:
			begin
				if (SUPPORT_DECFLT)
					fps <= dfp64To96;
				else if (SUPPORT_BINFLT)
					fps <= d2xdo;
				ret();
			end
		default:
			begin
				fps <= fps;
				ret();
			end
		endcase
	end
FCMP:
	begin
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_HEXI1,S);
		endcase
	end
FCMP1:
	begin
		if (SUPPORT_DECFLT) begin
			fzf <= dfcmpo[0];
			fnf <= dfcmpo[1];
			fvf <= 1'b0;
			fnanf <= dfcmpo[4];
		end
		else if (SUPPORT_BINFLT) begin
			fzf <= dcmpo[0];
			fnf <= dcmpo[1];
			fvf <= 1'b0;
			fnanf <= dcmpo[4];
		end
		ret();
	end
FMOVE:
	begin
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_HEXI1,S);
		endcase
	end
FMOVE1:
	begin
		if (SUPPORT_DECFLT|SUPPORT_BINFLT) begin
			resF <= fps[95:0];
			fzf <= fps[94:0]==95'd0;
			fnf <= fps[95];
			Rt <= {1'b0,FLTDST};
			rfwrF <= 1'b1;
			ret();
		end
		// DEAD code
		else begin
			if (ir2[14])
				case(ir2[12:10])
				3'b000:
					begin
						fps <= {64'd0,s};
						goto (I2DF1);
					end
				3'b001:
					begin
						resF <= fpss[63:0];
						fzf <= fpss[62:0]==63'd0;
						fnf <= fpss[63];
						Rt <= {1'b0,FLTDST};
						rfwrF <= 1'b1;
						ret();
					end
				3'b100:
					begin
						fps <= {80'd0,s[15:0]};
						goto (I2DF1);
					end
				3'b110:
					begin
						fps <= {88'd0,s[7:0]};
						goto (I2DF1);
					end
				default:
					begin
						resF <= fps[63:0];
						fzf <= fps[62:0]==63'd0;
						fnf <= fps[63];
						Rt <= {1'b0,FLTDST};
						rfwrF <= 1'b1;
						ret();
					end
				endcase
			else begin
				resF <= fps[63:0];
				fzf <= fps[62:0]==63'd0;
				fnf <= fps[63];
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
				ret();
			end
		end
	end
I2DF1:
	begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt>=8'd7)
			goto (I2DF2);
	end
I2DF2:
	begin
		if (SUPPORT_DECFLT) begin
			if (i2dfdone) begin
				resF <= i2dfo;
				fzf <= i2dfo[94:0]==95'd0;
				fnf <= i2dfo[95];
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
				ret();
			end
		end
		else if (SUPPORT_BINFLT) begin
			if (i2d_done) begin
				resF <= i2do;
				fzf <= i2do[94:0]==95'd0;
				fnf <= i2do[95];
				Rt <= {1'b0,FLTDST};
				rfwrF <= 1'b1;
				ret();
			end
		end
		else
			ret();
	end
DF2I1:
	begin
		fpcnt <= fpcnt + 2'd1;
		if (fpcnt==8'd6)
			goto (DF2I2);
	end
DF2I2:
	begin
		if (SUPPORT_DECFLT) begin
			if (df2idone) begin
				if (ir2[14])
					case(ir2[12:10])
					3'b000:	fs_data(mmm,rrr,STORE_LWORD,D);
					3'b100:	fs_data(mmm,rrr,STORE_WORD,D);
					3'b110:	fs_data(mmm,rrr,STORE_BYTE,D);
					default:	ret();
					endcase
				else begin
					rfwrF <= 1'b1;
					ret();
				end
				resF <= df2io;
				resL <= df2io[31:0];
				resW <= df2io[15:0];
				resB <= df2io[ 7:0];
				d <= df2io;
				// Flags are not affected by FMOVE
				if (ir2[15:13]!=3'b011) begin
					fzf <= df2io[94:0]==95'd0;
					fnf <= df2io[95];
					fvf <= df2iover;
				end
				//Rt <= {1'b0,FLTDST};
				//rfwrL <= 1'b1;
			end
		end
		else if (SUPPORT_BINFLT) begin
			if (d2i_done) begin
				case(ir2[12:10])
				3'b000:	fs_data(mmm,rrr,STORE_LWORD,D);
				3'b100:	fs_data(mmm,rrr,STORE_WORD,D);
				3'b110:	fs_data(mmm,rrr,STORE_BYTE,D);
				default:	ret();
				endcase
				resF <= d2io;
				resL <= d2io[31:0];
				resW <= d2io[15:0];
				resB <= d2io[ 7:0];
				d <= d2io;
				if (ir2[15:13]!=3'b011) begin
					fzf <= d2io[94:0]==95'd0;
					fnf <= d2io[95];
					fvf <= d2io[94:80]==15'h7fff && d2io[79:0]==80'd0;
				end
				//Rt <= {1'b0,FLTDST};
				//rfwrL <= 1'b1;
			end
		end
		else
			ret();
	end
FTST:
	begin
		case(ir2[12:10])
		3'b000:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b001:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_LWORD,S); end
		3'b100:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_WORD,S); end
		3'b101:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_OCTA,S); end
		3'b110:	begin push(FCVTI1); fs_data(mmm,rrr,FETCH_BYTE,S); end
		default:	fs_data(mmm,rrr,FETCH_HEXI1,S);
		endcase
	end
FTST1:
	begin
		if (SUPPORT_DECFLT) begin
			fnf <= fps[95];
			fzf <= fps[94:0]==95'd0;
			fnanf <= fps[94:90]==5'b11111;
			fvf <= fps[94:90]==5'b11110;
		end
		else if (SUPPORT_BINFLT) begin
			fnf <= fps[95];
			fzf <= fps[94:0]==95'd0;
			fnanf <= fps[94:80]==15'h7fff && fps[79:0]!=80'd0;
			fvf <= fps[94:80]==15'h7fff && fps[79:0]==80'd0;
		end
		ret();
	end
FBCC:
	begin
		if (ftakb)
			pc <= opc + imm;
		ret();
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// PMMU states
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
`ifdef SUPPORT_PMMU
PBCC:
	begin
		if (ptakb)
			pc <= opc + imm;
		ret();
	end

//-----------------------------------------------------------------------------
// PDBcc
//-----------------------------------------------------------------------------
PDBCC:
	begin
		if (ir[5:3]==3'b111)
			goto (PTRAPCC);
		else
			call(FETCH_IMM16,PDBCC1);
	end
PDBCC1:
	if (~takb) begin
		resW <= rfoDnn - 4'd1;
		Rt <= {Xnx,rrr};
		rfwrW <= 1'b1;
		if (rfoDnn[15:0]!=0)
			pc <= opc + imm;
		ret();
	end
	else
		ret();

//-----------------------------------------------------------------------------
// PTRAPCC
//-----------------------------------------------------------------------------
PTRAPCC:
	begin
		case(ir[2:0])
		3'b010:	call (FETCH_IMM16,PTRAPCC1);
		3'b011:	call (FETCH_IMM32,PTRAPCC1);
		3'b100:	goto (PTRAPCC1);
		default:	tIllegal();
		endcase
	end
PTRAPCC1:
	begin
		if (ptakb)
			tPTRAPcc();
		else
			ret();
	end

//-----------------------------------------------------------------------------
// PSCC
//-----------------------------------------------------------------------------
PSCC:
	begin
		d <= {32{ptakb}};
		fs_data(mmm,rrr,STORE_BYTE,D);
	end

//-----------------------------------------------------------------------------
// PFLUSH
//-----------------------------------------------------------------------------

PFLUSH1:
	begin
		push(PFLUSH2);
		fs_data(mmm,rrr,FETCH_NOP_LWORD,S);
	end
PFLUSH2:
	begin
		pmmu_flush_cmd <= 2'd1;
		ret();
	end
PFLUSH3:
	begin
		pmmu_flush_cmd <= 2'd2;
		ret();
	end	

//-----------------------------------------------------------------------------
// PLOADn
//-----------------------------------------------------------------------------
PLOAD:
	begin
		if (!pmmu_tc.E)
			tPMMUIllop();
		else begin
			if (ir2[9])
				fs_data(mmm,rrr,FETCH_NOP_BYTE,S);	// Translation control reg
			else
				fs_data(mmm,rrr,STORE_NOP_BYTE,D);	// Translation control reg
		end
	end

//-----------------------------------------------------------------------------
// PTESTn
//-----------------------------------------------------------------------------
PTEST:
	begin
		pmmu_ptest_lvl <= ir2[12:10];
		push(PTEST1);
		fs_data(mmm,rrr,FETCH_NOP_BYTE,S);	// Compute effective address
		casez(ir2[4:0])
		5'b00000:	pmmu_fc <= sfc;
		5'b00001:	pmmu_fc <= dfc;
		5'b01???:	
			case(ir2[2:0])
			3'd0:	pmmu_fc <= d0[2:0];
			3'd1:	pmmu_fc <= d1[2:0];
			3'd2:	pmmu_fc <= d2[2:0];
			3'd3:	pmmu_fc <= d3[2:0];
			3'd4:	pmmu_fc <= d4[2:0];
			3'd5:	pmmu_fc <= d5[2:0];
			3'd6:	pmmu_fc <= d6[2:0];
			3'd7:	pmmu_fc <= d7[2:0];
			endcase
		5'b10???:	pmmu_fc <= ir2[2:0];
		default:	;
		endcase
	end
PTEST1:
	begin
		if (pmmu_ptest_lvl==3'd0) begin
			n2 = fnATCFind(pmmu_fc,ea);
			lf2p_desc = LF2P_desc_t'(atc[n2].desc);
			if (n2==8'hFF)
				pmmu_sr.I <= `TRUE;
			else begin
				pmmu_sr.I <= `FALSE;
				if (atc[n2].v) begin
					if (atc[n2].berr)
						pmmu_sr.B <= `TRUE;
					else
						pmmu_sr.B <= `FALSE;
					if (lf2p_desc.s && !pmmu_fc[2])
						pmmu_sr.S <= `TRUE;
					else
						pmmu_sr.S <= `FALSE;
					pmmu_sr.L <= `FALSE;
					/*
					if (~atc[n2].desc.r & ir2[9])
						pmmu_sr.A <= `TRUE;
					else
						pmmu_sr.A <= `FALSE;
					*/
					if (~lf2p_desc.wp & ~ir2[9])
						pmmu_sr.W <= `TRUE;
					else
						pmmu_sr.W <= `FALSE;
					pmmu_sr.M <= lf2p_desc.m;
					pmmu_sr.G <= atc[n2].desc.sg;
					pmmu_sr.N <= 3'd0;
				end
			end
		end
		else begin
		end
	end

//-----------------------------------------------------------------------------
// PLOADn
//-----------------------------------------------------------------------------
PVALID:
	begin
		push(PVALID1);
		fs_data(mmm,rrr,FETCH_NOP_BYTE,S);
	end
PVALID1:
	begin
		if (pmmu_acr.MC)
			tPrivilegeViolation();
		else
			case(ir2[2:0])
			3'b000:
				if ((ea & pmmu_amask) < (({24'd0,pmmu_val} << 24) & pmmu_amask))
					tPrivilegeViolation();
				else
					ret();
			3'b001:	
				if ((ea & pmmu_amask) < (a1 & pmmu_amask))
					tPrivilegeViolation();
				else
					ret();
			3'b010:	
				if ((ea & pmmu_amask) < (a2 & pmmu_amask))
					tPrivilegeViolation();
				else
					ret();
			3'b011:	
				if ((ea & pmmu_amask) < (a3 & pmmu_amask))
					tPrivilegeViolation();
				else
					ret();
			3'b100:	
				if ((ea & pmmu_amask) < (a4 & pmmu_amask))
					tPrivilegeViolation();
				else
					ret();
			3'b101:	
				if ((ea & pmmu_amask) < (a5 & pmmu_amask))
					tPrivilegeViolation();
				else
					ret();
			3'b110:	
				if ((ea & pmmu_amask) < (a6 & pmmu_amask))
					tPrivilegeViolation();
				else
					ret();
			3'b111:	
				if ((ea & pmmu_amask) < (sp & pmmu_amask))
					tPrivilegeViolation();
				else
					ret();
			endcase
	end

//-----------------------------------------------------------------------------
// PMOVE
//-----------------------------------------------------------------------------
PMOVE1:
	begin
		if (ir2[9])
			case(ir2[12:10])
			3'b001:
				begin
					ds <= D;
					d <= pmmu_dma_root[31:0];
					ea <= ea + 4'd4;
					goto (STORE_LWORD);
				end
			3'b010:	
				begin
					ds <= D;
					d <= pmmu_sys_root[31:0];
					ea <= ea + 4'd4;
					goto (STORE_LWORD);
				end
			3'b011:
				begin
					ds <= D;
					d <= pmmu_cpu_root[31:0];
					ea <= ea + 4'd4;
					goto (STORE_LWORD);
				end
			default:	ret();
			endcase
		else
			case(ir2[12:10])
			3'b000:
				begin
					pmmu_tc <= s;
					ret();
				end
			3'b001:
				begin
					pmmu_dma_root[63:32] <= s;
					ds <= S;
					ea <= ea + 4'd4;
					push(PMOVE2);
					goto (FETCH_LWORD);
				end
			3'b010:	
				begin
					pmmu_sys_root[63:32] <= s;
					d <= pmmu_sys_root[31:0];
					ds <= S;
					ea <= ea + 4'd4;
					push(PMOVE2);
					goto (FETCH_LWORD);
				end
			3'b011:
				begin
					ds <= S;
					ea <= ea + 4'd4;
					push(PMOVE2);
					goto (FETCH_LWORD);
				end
			3'b100:
				begin
					pmmu_cal <= s[7:0];
					ret();
				end
			3'b101:
				begin
					pmmu_val <= s[7:0];
					ret();
				end
			3'b110:
				begin
					pmmu_scc <= s[7:0];
					ret();
				end
			3'b111:
				begin
					pmmu_acr <= s[7:0];
					ret();
				end
			endcase
	end
PMOVE2:
	begin
		case(ir2[12:10])
		3'b001:	pmmu_dma_root[31:0] <= s;
		3'b010:	pmmu_sys_root[31:0] <= s;
		3'b011:	pmmu_cpu_root[31:0] <= s;
		default:	;
		endcase
		ret();
	end
PMOVE3:
	begin
		case(ir2[12:10])
		3'b000:	pmmu_sr <= s[15:0];
		3'b001:	;	// read-only register
		3'b100:	pmmu_bad[ir2[4:2]] <= s[15:0];
		3'b101:	pmmu_bac[ir2[4:2]] <= s[15:0];
		default:	;
		endcase
		ret();
	end

//-----------------------------------------------------------------------------
// PSAVE
//-----------------------------------------------------------------------------
PSAVE:
	begin
	    lea <= `TRUE;
		fs_data(mmm,rrr,STORE_BYTE,D);	// Calc address
		case(pmmu_format)
		8'h00:	ret();	// NULL
		8'h20:	begin pmmu_smask <= 32'h83F40001; goto(PSAVE1); end
		8'h28:	begin pmmu_smask <= 32'h83FF0001; goto(PSAVE1); end
		8'h48:	begin pmmu_smask <= 32'h83FFFF01; goto(PSAVE1); end
		default:	tFormat();
		endcase
	end
PSAVE1:
	begin
		lea <= FALSE;
		casez(pmmu_flo)
		6'd0:	begin push(PSAVE2); goto(STORE_LWORD); d <= {pmmu_version,pmmu_format,16'h0000}; end
		6'b001???:	begin	push(PSAVE2); goto(STORE_LWORD); d <= {pmmu_bac[pmmu_flo[2:0]],pmmu_bad[pmmu_flo[2:0]]}; end
		6'd16:	begin push(PSAVE2); goto(STORE_LWORD); d <= 32'd0; end	// internal data
		6'd17:	begin push(PSAVE2); goto(STORE_LWORD); d <= 32'd0; end
		6'd18:	begin	push(PSAVE2); goto(STORE_LWORD); d <= {pmmu_sr,pmmu_scc,pmmu_cal[7:5],1'b0,pmmu_val[7:5],1'b0}; end
		6'd19:	begin	push(PSAVE2); goto(STORE_LWORD); d <= pmmu_sys_root[31:0]; end
		6'd20:	begin	push(PSAVE2); goto(STORE_LWORD); d <= pmmu_sys_root[63:32]; end
		6'd21:	begin	push(PSAVE2); goto(STORE_LWORD); d <= pmmu_cpu_root[31:0]; end
		6'd22:	begin	push(PSAVE2); goto(STORE_LWORD); d <= pmmu_cpu_root[63:32]; end
		6'd23:	begin	push(PSAVE2); goto(STORE_LWORD); d <= pmmu_dma_root[31:0]; end	// internal data
		6'd24:	begin	push(PSAVE2); goto(STORE_LWORD); d <= pmmu_dma_root[63:32]; end
		6'd25:	begin push(PSAVE2); goto(STORE_LWORD); d <= {16'd0,3'b0,pmmu_cal[4:0],3'b0,pmmu_val[4:0]}; end	// internal data
		6'd26:	begin	push(PSAVE2); goto(STORE_LWORD); d <= 32'd0; end	//pmmu_tc; end
		6'd27:	begin	push(PSAVE2); goto(STORE_LWORD); d <= 32'd0; end//{2{pmmu_csr}}; end
		6'd28:	begin	push(PSAVE2); goto(STORE_LWORD); d <= 32'd0; end
		6'd29:	begin	push(PSAVE2); goto(STORE_LWORD); d <= 32'd0; end
		6'd31:	ret();
		default:	goto(PSAVE2);
		endcase
	end
PSAVE2:
	begin
		ea <= ea + 4'd4;
		pmmu_smask[pmmu_flo] <= 1'b0; 
		goto (PSAVE1);
	end

//-----------------------------------------------------------------------------
// PRESTORE
//-----------------------------------------------------------------------------
PRESTORE:
	begin
		lea <= `TRUE;
		pmmu_smask <= 32'h00000001;
		fs_data(mmm,rrr,FETCH_BYTE,S);	// Calc address
	end
PRESTORE1:
	begin
		casez(pmmu_flo)
		6'd31:	ret();
		default:	begin	push(PRESTORE2); goto(FETCH_LWORD); end
		endcase
	end
PRESTORE2:
	begin
		ea <= ea + 4'd4;
		casez(pmmu_flo)
		6'd0:	
			begin
				pmmu_format <= s[23:16];
				case(s[23:16])
				8'h00:	ret();	// NULL
				8'h20:	begin pmmu_smask <= 32'h83F40000; goto(PRESTORE1); end
				8'h28:	begin pmmu_smask <= 32'h83FF0000; goto(PRESTORE1); end
				8'h48:	begin pmmu_smask <= 32'h83FFFF00; goto(PRESTORE1); end
				default:	tFormat();
				endcase
			end
		6'b001???:	begin {pmmu_bac[pmmu_flo[2:0]],pmmu_bad[pmmu_flo[2:0]]} <= s; end
		6'd16,6'd17:	;
		6'd18:	begin pmmu_scc <= s[15:8]; pmmu_cal[7:5] <= s[7:5]; pmmu_val[7:5] <= s[3:1]; end
		6'd19:	begin pmmu_sys_root[31:0] <= s; end
		6'd20:	begin pmmu_sys_root[63:32] <= s; end
		6'd21:	begin pmmu_cpu_root[31:0] <= s; end
		6'd22:	begin pmmu_cpu_root[63:32] <= s; end
		6'd23:	begin pmmu_dma_root[31:0] <= s; end
		6'd24:	begin pmmu_dma_root[63:32] <= s; end
		6'd25:	begin pmmu_cal[4:0] <= s[12:8]; pmmu_val[4:0] <= s[4:0]; end
		default:	;
		endcase
		pmmu_smask[pmmu_flo] <= 1'b0; 
		goto (PRESTORE1);
	end
`endif

//-----------------------------------------------------------------------------
// 68020 - 
//-----------------------------------------------------------------------------
`ifdef SUPPORT_020
BITFLD:
	begin
		goto (BITFLD_UPDATE);
		case(bf_size)
		FETCH_BYTE,FETCH_WORD,FETCH_LWORD:	
			begin
				case(ir[11:8])
				4'b1011:	// BFEXTS
					begin
						d <= (s & bfmask) >> bfoffs;
						for (bf1 = 0; bf1 < 32; bf1 = bf1 + 1)
							if (bf1 >= bfwidth)
								d[bf1] <= s[bfoffs+bfwidth-1];
						cf <= 1'b0;
						vf <= 1'b0;
						nf <= s[bfoffs+bfwidth-1];
						zf <= (s & bfmask)==32'd0;
					end
				4'b1001:	// BFEXTU
					begin
						d <= (s & bfmask) >> bfoffs;
						for (bf1 = 0; bf1 < 32; bf1 = bf1 + 1)
							if (bf1 >= bfwidth)
								d[bf1] <= 1'b0;
						cf <= 1'b0;
						vf <= 1'b0;
						nf <= s[bfoffs+bfwidth-1];
						zf <= (s & bfmask)==32'd0;
					end
				4'b1101:	// BFFFO
					begin
						d <= bfoffs + bfwidth;
						for (bf1 = 31; bf1 >= 0; bf1 = bf1 - 1)
							if (bf1 <= bfoffs)
								if (s[bf1]==1'b1) begin
									d <= bf1;
									break;
								end
						cf <= 1'b0;
						vf <= 1'b0;
						nf <= s[bfoffs+bfwidth-1];
						zf <= (s & bfmask)==32'd0;
					end
				4'b1111:	// BFINS
					begin
						d <= (s & ~bfmask) | (bfdat & (bfmask >> bfoffs) << bfoffs);
						zf <= (bfdat & (bfmask >> bfoffs))==32'd0;
						nf <= bfdat[bfwidth-1];
						cf <= 1'b0;
						vf <= 1'b0;
					end
				4'b1000:
					begin
						nf <= s[bfoffs+bfwidth-1];
						zf <= (s & bfmask)==32'd0;
						cf <= 1'b0;
						vf <= 1'b0;
						ret();
					end
				default:
				begin
					zf <= TRUE;
					for (bf1 = 0; bf1 < 32; bf1 = bf1 + 1)
						if (bf1 < bfoffs && bf1 < bfoffs + bfwidth-1) begin
							zf <= zf & ~s[bf1];
							case(ir[11:8])
							4'b1010:	d[bf1] <= s[bf1] ^ 1'b1;
							4'b1100:	d[bf1] <= 1'b0;
							4'b1110:	d[bf1] <= 1'b1;
							default:	;
							endcase
						end
						else
							d[bf1] <= s[bf1];
					cf <= 1'b0;
					vf <= 1'b0;
					nf <= s[bfoffs+bfwidth-1];
				end
				endcase
			end
		FETCH_OCTA:
			begin
				case(ir[11:8])
				4'b1011:
					begin
						fpd <= (fps & bfmask) >> bfoffs;
						for (bf1 = 0; bf1 < 32; bf1 = bf1 + 1)
							if (bf1 >= bfwidth)
								fpd[bf1] <= fps[bfoffs+bfwidth-1];
						cf <= 1'b0;
						vf <= 1'b0;
						nf <= fps[bfoffs+bfwidth-1];
						zf <= (fps & bfmask)==64'd0;
					end
				4'b1001:
					begin
						fpd <= fps >> bfoffs;
						for (bf1 = 0; bf1 < 32; bf1 = bf1 + 1)
							if (bf1 >= bfwidth)
								fpd[bf1] <= 1'b0;
						cf <= 1'b0;
						vf <= 1'b0;
						nf <= fps[bfoffs+bfwidth-1];
						zf <= (fps & bfmask)==64'd0;
					end
				4'b1101:
					begin
						fpd <= bfoffs + bfwidth;
						for (bf1 = 63; bf1 >= 0; bf1 = bf1 - 1)
							if (bf1 <= bfoffs)
								if (fps[bf1]==1'b1) begin
									fpd <= bf1;
									break;
								end
						cf <= 1'b0;
						vf <= 1'b0;
						nf <= fps[bfoffs+bfwidth-1];
						zf <= (fps & bfmask)==64'd0;
					end
				4'b1111:	// BFINS
					begin
						fpd <= (fps & ~bfmask) | (bfdat & (bfmask >> bfoffs) << bfoffs);
						zf <= (bfdat & (bfmask >> bfoffs))==64'd0;
						nf <= bfdat[bfwidth-1];
						cf <= 1'b0;
						vf <= 1'b0;
					end
				4'b1000:
					begin
						nf <= fps[bfoffs+bfwidth-1];
						zf <= (fps & bfmask)==64'd0;
						cf <= 1'b0;
						vf <= 1'b0;
						ret();
					end
				default:
				begin
					zf <= TRUE;
					for (bf1 = 0; bf1 < 64; bf1 = bf1 + 1)
						if (bf1 < bfoffs && bf1 < bfoffs + bfwidth-1) begin
							zf <= zf & ~fps[bf1];
							case(ir[11:8])
							4'b1010:	fpd[bf1] <= fps[bf1] ^ 1'b1;
							4'b1100:	fpd[bf1] <= 1'b0;
							4'b1110:	fpd[bf1] <= 1'b1;
							default:	;
							endcase
						end
						else
							fpd[bf1] <= fps[bf1];
					cf <= 1'b0;
					vf <= 1'b0;
					nf <= fps[bfoffs+bfwidth-1];
				end
				endcase
			end
		default:	;
		endcase
	end
BITFLD_UPDATE:
	if (ir[11:8]==4'b1011 || ir[11:8]==4'b1001 || ir[11:8]==4'b1101) begin
		Rt <= {Nnx,ir2[14:12]};
		rfwrL <= TRUE;
		resL <= bf_size==FETCH_OCTA ? fpd[31:0] : d[31:0];
		ret();
	end
	else
		fs_data(mmm,rrr,bf_size,D);

// Do breakpoint acknowledge cycle
BREAKPOINT:
  begin
  	pfc_o <= 3'b111;
    pcyc_o <= HIGH;
    pstb_o <= HIGH;
    psel_o <= 4'b1111;
    padr_o <= {28'h00000000,ir[2:0],2'b0};
    goto (BREAKPOINT_ACK);
  end
BREAKPOINT_ACK:
  if (ack_i|err_i|pmmu_bac[ir[2:0]].bpe) begin
  	pfc_o <= {sf,2'b00};
    pcyc_o <= LOW;
    pstb_o <= LOW;
    psel_o <= 4'b0;
    if (err_i)
    	tIllegal();
    else if (pmmu_bac[ir[2:0]].bpe) begin
    	if (pmmu_bac[ir[2:0]].skip!=8'h00) begin
    		ir <= pmmu_bad[ir[2:0]];
    		pmmu_bac[ir[2:0]].skip <= pmmu_bac[ir[2:0]].skip - 2'd1;
    		goto (DECODE);
    	end
    	else
    		tIllegal();
  	end
    else begin
    	ir <= iri;
    	goto (DECODE);
    end
  end

// Fetch sources	
CAS:
	begin
		case(ir[10:9])
		2'b01:	begin lock_o <= HIGH; push(CAS1); fs_data(mmm,rrr,FETCH_BYTE,D); end
		2'b10:	begin lock_o <= HIGH; push(CAS1); fs_data(mmm,rrr,FETCH_WORD,D); end
		2'b11:	begin lock_o <= HIGH; push(CAS1); fs_data(mmm,rrr,FETCH_LWORD,D); end
		default:	tIllegal();
		endcase
		Dc <= fnReg({1'b0,ir2[2:0]});
		Du <= fnReg({1'b0,ir2[8:6]});
	end
// Compare
CAS1:
	begin
		resB <= d[7:0] - Dc[7:0];
		resW <= d[15:0] - Dc[15:0];
		resL <= d - Dc;
		goto (CAS2);
	end
// Update flags
CAS2:
	begin
		case(ir[10:9])
		2'b01:
			begin
				zf <= resB[7:0]==8'd0;
				nf <= resB[7];
				cf <= resB[8];
				vf <= fnSubOverflow(resB[7],d[7],Dc[7]);
			end
		2'b10:
			begin
				zf <= resW[15:0]==16'd0;
				nf <= resW[15];
				cf <= resW[16];
				vf <= fnSubOverflow(resW[15],d[15],Dc[15]);
			end
		2'b11:
			begin
				zf <= resL[31:0]==32'd0;
				nf <= resL[31];
				cf <= resL[32];
				vf <= fnSubOverflow(resL[31],d[31],Dc[31]);
			end
		default:	;
		endcase
		goto (CAS3);
	end
// Conditionally store
CAS3:
	begin
		d <= Du;
		if (zf)
			case(ir[10:9])
			2'b01:	call(STORE_BYTE,CAS4);
			2'b10:	call(STORE_WORD,CAS4);
			2'b11:	call(STORE_LWORD,CAS4);
			default:	tIllegal();
			endcase
		else begin
			lock_o <= LOW;
			Rt <= ir2[8:6];
			resL <= d;
			case(ir[10:9])
			2'b01:	rfwrB <= TRUE;
			2'b10:	rfwrW <= TRUE;
			2'b11:	rfwrL <= TRUE;
			default:	;
			endcase
			ret();
		end
	end
CAS4:
	begin
		lock_o <= LOW;
		ret();
	end

// Fetch sources	
// CAS2 instruction.

CASO:
	begin
		ds <= D;
		case(ir[10:9])
		2'b01:	begin ea <= fnReg(ir2[15:12]); lock_o <= HIGH; call (FETCH_BYTE,CASO1); end
		2'b10:	begin ea <= fnReg(ir2[15:12]); lock_o <= HIGH; call (FETCH_WORD,CASO1); end
		2'b11:	begin ea <= fnReg(ir2[15:12]); lock_o <= HIGH; call (FETCH_LWORD,CASO1); end
		default:	tIllegal();
		endcase
		Dc1 <= fnReg({1'b0,ir2[2:0]});
		Du1 <= fnReg({1'b0,ir2[8:6]});
	end
CASO1:
	begin
		dd <= d;
		case(ir[10:9])
		2'b01:	begin ea <= fnReg(imm[15:12]); lock_o <= HIGH; call (FETCH_BYTE,CASO2); end
		2'b10:	begin ea <= fnReg(imm[15:12]); lock_o <= HIGH; call (FETCH_WORD,CASO2); end
		2'b11:	begin ea <= fnReg(imm[15:12]); lock_o <= HIGH; call (FETCH_LWORD,CASO2); end
		default:	tIllegal();
		endcase
		Dc2 <= fnReg({1'b0,imm[2:0]});
		Du2 <= fnReg({1'b0,imm[8:6]});
	end
// Compare
CASO2:
	begin
		case(ir[10:9])
		2'b10:	resL <= {dd[15:0],d[15:0]} - {Dc1[15:0],Dc2[15:0]};
		2'b11:	resO <= {dd,d} - {Dc1,Dc2};
		endcase
		goto (CASO3);
	end
// Update flags
CASO3:
	begin
		case(ir[10:9])
		2'b10:
			begin
				zf <= resL[31:0]==32'd0;
				nf <= resL[31];
				cf <= resL[32];
				vf <= fnSubOverflow(resL[31],dd[15],Dc1[15]);
			end
		2'b11:
			begin
				zf <= resO[63:0]==64'd0;
				nf <= resO[63];
				cf <= resO[64];
				vf <= fnSubOverflow(resO[63],dd[31],Dc1[31]);
			end
		default:	;
		endcase
		goto (CASO4);
	end
// Conditionally store
CASO4:
	begin
		d <= Du1;
		if (zf)
			case(ir[10:9])
			2'b10:	begin ea <= fnReg(ir2[15:12]); call (STORE_WORD,CASO5); end
			2'b11:	begin ea <= fnReg(ir2[15:12]); call (STORE_LWORD,CASO5); end
			default:	tIllegal();
			endcase
		else begin
			lock_o <= LOW;
			Rt <= ir2[8:6];
			resW <= d[15:0];
			resL <= d;
			case(ir[10:9])
			2'b10:	rfwrW <= TRUE;
			2'b11:	rfwrL <= TRUE;
			default:	;
			endcase
			goto (CASO5);
		end
	end
CASO5:
	begin
		d <= Du2;
		if (zf)
			case(ir[10:9])
			2'b10:	begin ea <= fnReg(imm[15:12]); call (STORE_WORD,CASO6); end
			2'b11:	begin ea <= fnReg(imm[15:12]); call (STORE_LWORD,CASO6); end
			default:	;
			endcase
		else begin
			lock_o <= LOW;
			Rt <= imm[8:6];
			resW <= d[15:0];
			resL <= d;
			case(ir[10:9])
			2'b10:	rfwrW <= TRUE;
			2'b11:	rfwrL <= TRUE;
			default:	;
			endcase
			ret();
		end
	end
CASO6:
	begin
		lock_o <= LOW;
		ret();
	end

`endif
/*
FCOPYEXP:
	begin
		resF <= fpdp;
		rfwrF <= 1'b1;
		Rt <= {1'b0,FLTDST};
		ret();
	end
*/
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

FMOVEM1:
	begin
		imm <= rfoDnn[7:0];
		if (ir2[13])
			goto(MOVEM_Xn2D);
		else
			goto(MOVEM_s2Xn);
	end

default:
	goto(RESET);
endcase

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// ATC flushing
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if (pmmu_rpt_state==2'd1)
		pmmu_flush_cmd <= 2'd3;

	for (n2 = 0; n2 < $size(atc); n2 = n2 + 1)
		if (atc[n2].v)
			case(pmmu_flush_cmd)
			2'd0:	;	// NOP
			2'd1:
				casez(ir2[4:0])
				5'b00000: 
					if ((atc[n2].func & ir2[8:5])==(sfc[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn)
						atc[n2].v <= INV;
				5'b00001:
					if ((atc[n2].func & ir2[8:5])==(dfc[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn)
						atc[n2].v <= INV;
				5'b01???:
					case(ir2[2:0])
					3'b000:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn) atc[n2].v <= `FALSE;
					3'b001:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn) atc[n2].v <= `FALSE;
					3'b010:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn) atc[n2].v <= `FALSE;
					3'b011:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn) atc[n2].v <= `FALSE;
					3'b100:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn) atc[n2].v <= `FALSE;
					3'b101:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn) atc[n2].v <= `FALSE;
					3'b110:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn) atc[n2].v <= `FALSE;
					3'b111:	if ((atc[n2].func & ir2[8:5])==(d0[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn) atc[n2].v <= `FALSE;
					endcase
				5'b10???:
					if ((atc[n2].func & ir2[8:5])==(ir2[2:0] & ir2[8:5]) && (ea >> pmmu_tc.PS) == atc[n2].vpn)
						atc[n2].v <= INV;
				default:	tIllegal();
				endcase
			2'd2:
				case(ir[4:3])
				2'b00:	if (!atc[n2].desc.sg && atc[n2].func==dfc[2:0] && (ea >> pmmu_tc.PS) == (rfoAn >> pmmu_tc.PS)) atc[n2].v <= INV;
				2'b01:	if (atc[n2].func==dfc[2:0] && (ea >> pmmu_tc.PS) == (rfoAn >> pmmu_tc.PS)) atc[n2].v <= INV;
				2'b10:	if (!atc[n2].desc.sg) atc[n2].v <= INV;	// flush all except global
				2'b11:	atc[n2].v <= INV;												// flush all entries	
				endcase
			// Flush all entries matching the evicted task alias.
			2'd3:
				if (atc[n2].ta==pmmu_flush_ta) atc[n2].v <= INV;
			default:	;
			endcase
	
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Bus error: abort current cycle and trap.
	if (cyc_o & err_i) begin
		pcyc_o <= `LOW;
		pstb_o <= `LOW;
		pwe_o <= `LOW;
		psel_o <= 4'h0;
		mac_cycle_type <= {state[6:0],psel_o,~pwe_o,1'b0,pfc_o};
		bad_addr <= adr_o;
		if (state != INTA) begin
			is_bus_err <= 1'b1;
			dati_buf <= dat_i;
			dato_buf <= pdat_o;
			goto (TRAP);
		end
		// If a bus error occurs during the PTEST instruction set status in PMMU.
		if (ptest)
			pmmu_sr.B <= 1'b1;
	end

	if (page_fault) begin
		pcyc_o <= `LOW;
		pstb_o <= `LOW;
		pwe_o <= `LOW;
		psel_o <= 4'h0;
		mac_cycle_type <= {state[6:0],psel_o,~pwe_o,1'b0,pfc_o};
		bad_addr <= adr_o;
		begin
			is_bus_err <= 1'b1;
			dati_buf <= dat_i;
			dato_buf <= pdat_o;
			page_fault <= 1'b0;
			goto (TRAP);
		end
	end

	// Bus error: abort current cycle and trap.
	if (atc_err) begin
		pcyc_o <= `LOW;
		pstb_o <= `LOW;
		pwe_o <= `LOW;
		psel_o <= 4'h0;
		mac_cycle_type <= {state[6:0],psel_o,~pwe_o,1'b0,pfc_o};
		bad_addr <= adr_o;
		if (state != INTA) begin
			is_priv <= 1'b1;
			dati_buf <= dat_i;
			dato_buf <= pdat_o;
			goto (TRAP);
		end
	end


`ifdef SUPPORT_RETRY
	// Retry: abort current cycle and retry.
	if (cyc_o & rty_i) begin
		pcyc_o <= `LOW;
		pstb_o <= `LOW;
		pwe_o <= `LOW;
		psel_o <= 4'h0;
		rstate <= state;
		goto (RETRY);
	end
`endif

	case(1'b1)
	pmmu_state[PMMU_WAIT_MISS]:
		// Trim a cycle off the access time by detecting the state transition.
		if (!(atc_hit|pload|ptest) && pmmu_en) begin
			pmmu_access <= 1'b1;
			work_fc <= 3'd5;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			pmmu_sr.S <= FALSE;
			pmmu_sr.A <= FALSE;
			pmmu_sr.W <= FALSE;
			pmmu_sr.I <= FALSE;
			pmmu_sr.M <= FALSE;
			pmmu_sr.G <= FALSE;
			pmmu_sr.C <= FALSE;
			pmmu_sr.N <= 3'd0;
			if (pfc_o[2]) begin
				if (pmmu_sys_root.dt==2'd3)	begin // long format
					if (pmmu_sys_root.lu && pmmu_index_ABCDP < pmmu_sys_root.limit)
						pmmu_sr.L <= TRUE;
					else if (pmmu_index_ABCDP > pmmu_sys_root.limit)
						pmmu_sr.L <= TRUE;
				end
				work_adr <= {pmmu_sys_root[31:4],4'h0} + (pmmu_tc.FCL ? {pfc_o,4'h0} : 8'h00) + ((pmmu_index_ABCDP << pmmu_Ashift) & pmmu_pmask);
			end
			else begin
				if (pmmu_cpu_root.dt==2'd3)	begin // long format
					if (pmmu_cpu_root.lu && pmmu_index_ABCDP < pmmu_cpu_root.limit)
						pmmu_sr.L <= TRUE;
					else if (pmmu_index_ABCDP > pmmu_cpu_root.limit)
						pmmu_sr.L <= TRUE;
				end
				work_adr <= {pmmu_cpu_root[31:4],4'h0} + (pmmu_tc.FCL ? {pfc_o,4'h0} : 8'h00) + ((pmmu_index_ABCDP << pmmu_Ashift) & pmmu_pmask);
			end
		end

	pmmu_state[PMMU_ACCESS_AL]:
		begin
			pmmu_access <= 1'b1;
			pmmu_sr.N <= 3'd1;
			work_fc <= 3'd5;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			pmmu_offs = pmmu_state[PMMU_ACCESS_AL] ? 4'd4 : 4'd0;
			if (pfc_o[2]) begin
				if (pmmu_sys_root.dt==2'd3)	begin // long format
					if (pmmu_sys_root.lu && pmmu_index_ABCDP < pmmu_sys_root.limit)
						pmmu_sr.L <= TRUE;
					else if (pmmu_index_ABCDP > pmmu_sys_root.limit)
						pmmu_sr.L <= TRUE;
				end
				work_adr <= {pmmu_sys_root[31:4],pmmu_offs} + (pmmu_tc.FCL ? {pfc_o,4'h0} : 8'h00) + ((pmmu_index_ABCDP << pmmu_Ashift) & pmmu_pmask);
			end
			else begin
				if (pmmu_cpu_root.dt==2'd3)	begin // long format
					if (pmmu_cpu_root.lu && pmmu_index_ABCDP < pmmu_cpu_root.limit)
						pmmu_sr.L <= TRUE;
					else if (pmmu_index_ABCDP > pmmu_cpu_root.limit)
						pmmu_sr.L <= TRUE;
				end
				work_adr <= {pmmu_cpu_root[31:4],pmmu_offs} + (pmmu_tc.FCL ? {pfc_o,4'h0} : 8'h00) + ((pmmu_index_ABCDP << pmmu_Ashift) & pmmu_pmask);
			end
		end
	pmmu_state[PMMU_WAIT_ACK_A],
	pmmu_state[PMMU_WAIT_ACK_AL]:
		begin
			if (pmmu_ptest_lvl==3'd1 && (pmmu_state[PMMU_WAIT_ACK_AL] || prev_desc_type!=PMMU_LONG_DESC)) begin
				pmmu_ptest_adr <= work_adr;
			end
			pmmu_access <= 1'b1;
			work_fc <= 3'd5;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			pmmu_offs = pmmu_state[PMMU_WAIT_ACK_AL] ? 4'd4 : 4'd0;
			if (pfc_o[2])
				work_adr <= {pmmu_sys_root[31:4],pmmu_offs} + ((pmmu_index_ABCDP << pmmu_Ashift) & pmmu_pmask);
			else
				work_adr <= {pmmu_cpu_root[31:4],pmmu_offs} + ((pmmu_index_ABCDP << pmmu_Ashift) & pmmu_pmask);
			if (ptest & ir2[8]) begin
				rfwrL <= TRUE;
				resL <= work_adr;
				Rt <= ir2[7:5];
			end
			if (ack_i) begin
				work_cyc <= 1'b0;
				work_stb <= 1'b0;
				work_sel <= 4'h0;
				desc <= {desc,dat_i};
				if (pmmu_state[PMMU_WAIT_ACK_AL]) begin
					prev_desc_type <= pmmu_desc_t'(desc[1:0]);
					if (!pfc_o[2] && desc[8])
						pmmu_sr.S <= TRUE;
					if (desc[9])
						pmmu_sr.C <= TRUE;
				end
				else
					prev_desc_type <= pmmu_desc_t'(dat_i[1:0]);
			end
		end

	pmmu_state[PMMU_ACCESS_B],
	pmmu_state[PMMU_ACCESS_BL]:
		begin
			pmmu_access <= 1'b1;
			pmmu_sr.N <= 3'd2;
			if (prev_desc_type!=3'd0) begin
				work_cyc <= 1'b1;
				work_stb <= 1'b1;
				work_we <= 1'b0;
				work_sel <= 4'hF;
			end
			pmmu_offs = pmmu_state[PMMU_ACCESS_BL] ? 4'd4 : 4'd0;
			if (pfc_o[2])
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_BCDP << pmmu_Bshift) & pmmu_pmask);
			else
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_BCDP << pmmu_Bshift) & pmmu_pmask);
			case(prev_desc_type)
			2'd0:	pmmu_sr.I <= TRUE;
			2'd3:
				begin // long format
					if (lft_desc.lu && pmmu_index_BCDP < lft_desc.limit)
						pmmu_sr.L <= TRUE;
					else if (pmmu_index_BCDP > lft_desc.limit)
						pmmu_sr.L <= TRUE;
				end
			default:	;
			endcase
		end
	pmmu_state[PMMU_WAIT_ACK_B],
	pmmu_state[PMMU_WAIT_ACK_BL]:
		begin
			if (pmmu_ptest_lvl==3'd2 && (pmmu_state[PMMU_WAIT_ACK_BL] || prev_desc_type!=PMMU_LONG_DESC))
				pmmu_ptest_adr <= work_adr;
			pmmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			pmmu_offs = pmmu_state[PMMU_WAIT_ACK_BL] ? 4'd4 : 4'd0;
			if (pfc_o[2])
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_BCDP << pmmu_Bshift) & pmmu_pmask);
			else
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_BCDP << pmmu_Bshift) & pmmu_pmask);
			if (ptest & ir2[8]) begin
				rfwrL <= TRUE;
				resL <= work_adr;
				Rt <= ir2[7:5];
			end
			if (ack_i) begin
				work_cyc <= 1'b0;
				work_stb <= 1'b0;
				work_sel <= 4'h0;
				desc <= {desc,dat_i};
				if (pmmu_state[PMMU_WAIT_ACK_BL]) begin
					prev_desc_type <= pmmu_desc_t'(desc[1:0]);
					if (!pfc_o[2] && desc[8])
						pmmu_sr.S <= TRUE;
				end
				else
					prev_desc_type <= pmmu_desc_t'(dat_i[1:0]);
			end
		end	

	pmmu_state[PMMU_ACCESS_C],
	pmmu_state[PMMU_ACCESS_CL]:
		begin
			pmmu_access <= 1'b1;
			pmmu_sr.N <= 3'd3;
			if (prev_desc_type!=3'd0) begin
				work_cyc <= 1'b1;
				work_stb <= 1'b1;
				work_we <= 1'b0;
				work_sel <= 4'hF;
			end
			pmmu_offs = pmmu_state[PMMU_ACCESS_CL] ? 4'd4 : 4'd0;
			if (pfc_o[2])
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_CDP << pmmu_Cshift) & pmmu_pmask);
			else
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_CDP << pmmu_Cshift) & pmmu_pmask);
			case(prev_desc_type)
			2'd0:	pmmu_sr.I <= TRUE;
			2'd3:
				begin // long format
					if (lft_desc.lu && pmmu_index_CDP < lft_desc.limit)
						pmmu_sr.L <= TRUE;
					else if (pmmu_index_CDP > lft_desc.limit)
						pmmu_sr.L <= TRUE;
				end
			default:	;
			endcase
		end
	pmmu_state[PMMU_WAIT_ACK_C],
	pmmu_state[PMMU_WAIT_ACK_CL]:
		begin
			if (pmmu_ptest_lvl==3'd3 && (pmmu_state[PMMU_WAIT_ACK_CL] || prev_desc_type!=PMMU_LONG_DESC))
				pmmu_ptest_adr <= work_adr;
			pmmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			pmmu_offs = pmmu_state[PMMU_WAIT_ACK_CL] ? 4'd4 : 4'd0;
			if (pfc_o[2])
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_CDP << pmmu_Cshift) & pmmu_pmask);
			else
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_CDP << pmmu_Cshift) & pmmu_pmask);
			if (ptest & ir2[8]) begin
				rfwrL <= TRUE;
				resL <= work_adr;
				Rt <= ir2[7:5];
			end
			if (ack_i) begin
				work_cyc <= 1'b0;
				work_stb <= 1'b0;
				work_sel <= 4'h0;
				desc <= {desc,dat_i};
				if (pmmu_state[PMMU_WAIT_ACK_CL]) begin
					prev_desc_type <= pmmu_desc_t'(desc[1:0]);
					if (!pfc_o[2] && desc[8])
						pmmu_sr.S <= TRUE;
				end
				else
					prev_desc_type <= pmmu_desc_t'(dat_i[1:0]);
			end
		end	

	pmmu_state[PMMU_ACCESS_D],
	pmmu_state[PMMU_ACCESS_DL]:
		begin
			pmmu_access <= 1'b1;
			pmmu_sr.N <= 3'd4;
			if (prev_desc_type!=3'd0) begin
				work_cyc <= 1'b1;
				work_stb <= 1'b1;
				work_we <= 1'b0;
				work_sel <= 4'hF;
			end
			pmmu_offs = pmmu_state[PMMU_ACCESS_DL] ? 4'd4 : 4'd0;
			if (pfc_o[2])
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_DP << pmmu_Dshift) & pmmu_pmask);
			else
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_DP << pmmu_Dshift) & pmmu_pmask);
			case(prev_desc_type)
			2'd0:	pmmu_sr.I <= TRUE;
			2'd3:
				begin // long format
					if (lft_desc.lu && pmmu_index_DP < lft_desc.limit)
						pmmu_sr.L <= TRUE;
					else if (pmmu_index_DP > lft_desc.limit)
						pmmu_sr.L <= TRUE;
				end
			default:	;
			endcase
		end
	pmmu_state[PMMU_WAIT_ACK_D],
	pmmu_state[PMMU_WAIT_ACK_DL]:
		begin
			if (pmmu_ptest_lvl==3'd4 && (pmmu_state[PMMU_WAIT_ACK_DL] || prev_desc_type!=PMMU_LONG_DESC))
				pmmu_ptest_adr <= work_adr;
			pmmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b0;
			work_sel <= 4'hF;
			pmmu_offs = pmmu_state[PMMU_WAIT_ACK_DL] ? 4'd4 : 4'd0;
			if (pfc_o[2])
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_DP << pmmu_Dshift) & pmmu_pmask);
			else
				work_adr <= {lft_desc.ta,pmmu_offs} + ((pmmu_index_DP << pmmu_Dshift) & pmmu_pmask);
			if (ptest & ir2[8]) begin
				rfwrL <= TRUE;
				resL <= work_adr;
				Rt <= ir2[7:5];
			end
			if (ack_i) begin
				work_cyc <= 1'b0;
				work_stb <= 1'b0;
				work_sel <= 4'h0;
				desc <= {desc,dat_i};
				if (pmmu_state[PMMU_WAIT_ACK_DL]) begin
					prev_desc_type <= pmmu_desc_t'(desc[1:0]);
					if (!pfc_o[2] && desc[8])
						pmmu_sr.S <= TRUE;
				end
				else
					prev_desc_type <= pmmu_desc_t'(dat_i[1:0]);
			end
		end	

	pmmu_state[PMMU_PTEST]:
		begin
			ptest <= FALSE;
		end
/*
	// This update state should cause an immediate hit on the ATC.
	pmmu_state[PMMU_ATC_UPDATE]:
		begin
			pmmu_access <= 1'b0;
			pload <= `FALSE;
			if (|desc[33:32]) begin
				lfp_desc.u <= `TRUE;
				atc[atc_ua].pte.a <= `TRUE;
				if (pwe_o) begin
					lfp_desc.m <= `TRUE;
					atc[atc_ua].desc.m <= `TRUE;
				end
				atc[atc_ua].desc <= lfp_desc;
				atc[atc_ua].vpn <= padr_o[31:8];
				atc[atc_ua].appid <= appid;
				atc_ua <= atc_ua + 6'd1;
			end
			else begin
				page_fault <= 1'b1;
				page_fault_adr <= padr_o;
			end
		end
*/
/*
	pmmu_state[PMMU_PTE_UPDATE]:
		begin
			pmmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b1;
			work_sel <= 4'hF;
			work_dat <= desc;
		end
	pmmu_state[PMMU_PTE_ACK]:
		begin
			pmmu_access <= 1'b1;
			work_cyc <= 1'b1;
			work_stb <= 1'b1;
			work_we <= 1'b1;
			work_sel <= 4'hF;
			if (ack_i) begin
				pmmu_table_level <= pmmu_table_level - 2'd1;
				work_cyc <= 1'b0;
				work_stb <= 1'b0;
				work_sel <= 4'h0;
				work_we <= 1'b0;
			end
		end	
*/
	// ToDo: dump evicted translation to memory.
	default:	;
	endcase
end

rf68851_sm upmmusm1
(
	.rst(rst_i),
	.clk(clk_i),
	.pmmu_en(pmmu_en),
	.pmmu_tc(pmmu_tc),
	.atc_hit(atc_hit),
	.ack(ack_i),
	.prev_desc_type(prev_desc_type),
	.desc(desc),
	.pload(pload),
	.pmmu_state(pmmu_state)
);

reg [31:0] padr1;

// Bus signals all need to be delayed a clock to aligned with PMMU translation.
// However, as soon as the cycle is terminated, we want the signals to be
// inactive;
reg [2:0] fco;
reg cyco,stbo,weo;
reg [3:0] selo;
reg [31:0] adro;
reg [31:0] dato;
always_ff @(posedge clk_i)	
	fco <= pmmu_access ? work_fc : pfc_o;
always_ff @(posedge clk_i)	
	cyco <= pmmu_access ? work_cyc : pcyc_o;
always_ff @(posedge clk_i)	
	stbo <= pmmu_access ? work_stb : pstb_o;
always_ff @(posedge clk_i)	
	weo <= pmmu_access ? work_we : pwe_o;
always_ff @(posedge clk_i)	
	selo <= pmmu_access ? work_sel : psel_o;
always_ff @(posedge clk_i)	
	dato <= pmmu_access ? work_dat : pdat_o;
// Address is a little more complex
always_ff @(posedge clk_i)
begin
	if (pmmu_en) begin
		if (atc_hit)
			//         Low order         High order
			adro <= pmmu_access ? work_adr : (padr_o & pmmu_pmask) | (padr1 & ~pmmu_pmask);
		else
			adro <= 32'h00000000;
	end
	// No translation if mmu not enabled.
	else
		adro <= padr_o;
end

always_comb fc_o = fco;
always_comb cyc_o = cyco & ~atc_err;
always_comb stb_o = stbo & ~atc_err;
always_comb we_o = weo & ~atc_err;
always_comb sel_o = selo;
always_comb adr_o = adro;
always_comb dat_o = dato;

always_comb
begin
	atc_hit = 1'b0;
	atc_err = 1'b0;
	for (n3 = 0; n3 < $size(atc); n3 = n3 + 1)
		if (atc[n1].vpn==(padr_o >> pmmu_tc.PS) && pmmu_ta==atc[n1].ta) begin
		    lf2p_desc = LF2P_desc_t'(atc[n1].desc);
			padr1 = {lf2p_desc.pa,8'h00};
			atc_hit = 1'b1;
			case(pfc_o)
			3'b000:	;	// not used
			3'b001:		// user data
				begin
					if ((lf2p_desc.wp & pwe_o) || ((padr_o[31:29] < lf2p_desc.wal) && pwe_o))
						atc_err = pmmu_en;
					if ((padr_o[31:29] < lf2p_desc.ral) && ~pwe_o)
						atc_err = pmmu_en;
				end
			3'b010:		// user code
				begin
				    ;
				    /*
					if (~atc[n1].pte.x)
						atc_err = pmmu_en;
					*/
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


//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
task fs_data;
input [2:0] mmm;
input [2:0] rrr;
input state_t size_state;
input dsi;
begin
	ds <= dsi;
	case(mmm)
	3'd0:	begin
				if (dsi==D)
					d <= MMMRRR ? rfoDn : rfob;
				else begin
					s <= MMMRRR ? rfoDn : rfob;
					fps <= MMMRRR ? rfoDn : rfob;
				end
				case(size_state)
				STORE_LWORD:
					begin
						Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
						rfwrL <= 1'b1;
					end
				STORE_WORD:
					begin
						Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
						rfwrW <= 1'b1;
					end
				STORE_BYTE:
					begin
						Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
						rfwrB <= 1'b1;
					end
				default:	;
				endcase
				goto(RETSTATE);
			end	// Dn
	3'd1:	begin
				if (dsi==D)
					d <= rfob;
				else
					s <= rfob;
				case(size_state)
				STORE_LWORD:
					begin
						Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
						rfwrL <= 1'b1;
					end
				STORE_WORD:
					begin
						Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
						rfwrW <= 1'b1;
					end
				STORE_BYTE:
					begin
						Rt <= |Xnx ? {Xnx,rrr} : {2'b00,mmm[0],rrr};
						rfwrB <= 1'b1;
					end
				default:	;
				endcase
				goto(RETSTATE);
				end	// An
	3'd2:	begin	//(An)
				ea <= MMMRRR ? rfoAna : rfoAn;
				goto(size_state);
			end
	3'd3:	begin	// (An)+
				ea <= (MMMRRR ? rfoAna : rfoAn);
				if (!lea && !pload) begin
					Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
					rfwrL <= 1'b1;
				end			
				case(size_state)
				LFETCH_BYTE,FETCH_BYTE,STORE_BYTE,USTORE_BYTE:	resL <= (MMMRRR ? rfoAna : rfoAn) + 4'd1;
				FETCH_WORD,STORE_WORD:	resL <= (MMMRRR ? rfoAna : rfoAn) + 4'd2;
				FETCH_LWORD,STORE_LWORD:	resL <= (MMMRRR ? rfoAna : rfoAn) + 4'd4;
				FETCH_HEXI1,STORE_HEXI1: resL <= rfoAn + 5'd12;
				default:	;
				endcase
				goto(size_state);
			end
	3'd4:	begin	// -(An)
				if (!lea && !pload) begin
					Rt <= |Xnx ? {Xnx,rrr} : {3'b001,rrr};
					rfwrL <= 1'b1;
				end
				case(size_state)
				FETCH_NOP_BYTE,LFETCH_BYTE,FETCH_BYTE,STORE_BYTE,USTORE_BYTE:	ea <= (MMMRRR ? rfoAna : rfoAn) - 4'd1;
				FETCH_NOP_WORD,FETCH_WORD,STORE_WORD:	ea <= (MMMRRR ? rfoAna : rfoAn) - 4'd2;
				FETCH_NOP_LWORD,FETCH_LWORD,STORE_LWORD:	ea <= (MMMRRR ? rfoAna : rfoAn) - 4'd4;
				FETCH_NOP_HEXI,FETCH_HEXI1,STORE_HEXI1: ea <= rfoAn - 5'd12;
				default:	;
				endcase
				case(size_state)
				LFETCH_BYTE,FETCH_BYTE,STORE_BYTE,USTORE_BYTE:	resL <= (MMMRRR ? rfoAna : rfoAn) - 4'd1;
				FETCH_WORD,STORE_WORD:	resL <= (MMMRRR ? rfoAna : rfoAn) - 4'd2;
				FETCH_LWORD,STORE_LWORD:	resL <= (MMMRRR ? rfoAna : rfoAn) - 4'd4;
				FETCH_HEXI1,STORE_HEXI1: resL <= rfoAn - 5'd12;
				default:	;
				endcase
				goto(size_state);
			end
	3'd5:	begin	// d16(An)
				ea <= (MMMRRR ? rfoAna : rfoAn);
				mmmx <= mmm;
				rrrx <= {Xnx,rrr};
				sz_state <= size_state;
				dsix <= dsi;
				goto (FSDATA2);
			end
	3'd6:	begin	// d8(An,Xn)
				ea <= (MMMRRR ? rfoAna : rfoAn);
				mmmx <= mmm;
				rrrx <= {Xnx,rrr};
				sz_state <= size_state;
				dsix <= dsi;
				goto (FSDATA2);
			end
	3'd7:	begin
				case(rrr)
				3'd0:	begin	// abs short
							ea <= 32'd0;
							mmmx <= mmm;
							rrrx <= {Xnx,rrr};
							sz_state <= size_state;
							dsix <= dsi;
							goto (FSDATA2);
						end
				3'd1:	begin	// abs long
							ea <= 32'd0;
							mmmx <= mmm;
							rrrx <= {Xnx,rrr};
							sz_state <= size_state;
							dsix <= dsi;
							goto (FSDATA2);
						end
				3'd2:	begin	// d16(PC)
							ea <= pc;
							mmmx <= mmm;
							rrrx <= {Xnx,rrr};
							sz_state <= size_state;
							dsix <= dsi;
							goto (FSDATA2);
						end
				3'd3:	begin	// d8(PC,Xn)
							ea <= pc;
							mmmx <= mmm;
							rrrx <= {Xnx,rrr};
							sz_state <= size_state;
							dsix <= dsi;
							goto (FSDATA2);
						end
						// ToDo: add FETCH_IMM128
				3'd4:	begin	// #i16
							goto(size_state==FETCH_NOP_HEXI ? FETCH_IMM96 : 
								(size_state==FETCH_NOP_OCTA||size_state==FETCH_OCTA) ? FETCH_IMM64 : 
								(size_state==FETCH_LWORD||size_state==FETCH_NOP_LWORD)?FETCH_IMM32:FETCH_IMM16);
						end
				3'd5:	begin	// #i32
							state <= FETCH_IMM32;
							goto (FETCH_IMM32);
						end
				default:
					tIllegal();
				endcase
			end
		endcase
	end
endtask

task fs_data2;
input [2:0] mmm;
input [2:0] rrr;
input state_t size_state;
input dsi;
begin
	ds <= dsi;
	case(mmm)
	3'd5:	begin	// d16(An)
				ea <= (MMMRRR ? rfoAna : rfoAn);
				call(FETCH_D16,size_state);
			end
	3'd6:	begin	// d8(An,Xn)
				ea <= (MMMRRR ? rfoAna : rfoAn);
				call(FETCH_NDX,size_state);
			end
	3'd7:	begin
				case(rrr)
				3'd0:	begin	// abs short
							ea <= 32'd0;
							call(FETCH_D16,size_state);
						end
				3'd1:	begin	// abs long
							ea <= 32'd0;
							call(FETCH_D32,size_state);
						end
				3'd2:	begin	// d16(PC)
							ea <= pc;
							call(FETCH_D16,size_state);
						end
				3'd3:	begin	// d8(PC,Xn)
							ea <= pc;
							call(FETCH_NDX,size_state);
						end
				3'd4:	begin	// #i16
							goto((size_state==FETCH_LWORD||size_state==FETCH_NOP_LWORD||size_state==FETCH_NOP_HEXI)?FETCH_IMM32:FETCH_IMM16);
							end
				3'd5:	begin	// #i32
							state <= FETCH_IMM32;
							goto (FETCH_IMM32);
						end
				endcase
			end
		endcase
	end
endtask

task goto;
input state_t nst;
begin
	state <= nst;
end
endtask

task gosub;
input state_t tgt;
begin
	state_stk1 <= state;
	state_stk2 <= state_stk1;
	state_stk3 <= state_stk2;
	state_stk4 <= state_stk3;
	state_stk5 <= state_stk4;
	state_stk6 <= state_stk5;
	state <= tgt;
end
endtask

task call;
input state_t tgt;
input state_t retst;
begin
	state_stk1 <= retst;
	state_stk2 <= state_stk1;
	state_stk3 <= state_stk2;
	state_stk4 <= state_stk3;
	state_stk5 <= state_stk4;
	state_stk6 <= state_stk5;
	state <= tgt;
end
endtask

task push;
input state_t st;
begin
	state_stk1 <= st;
	state_stk2 <= state_stk1;
	state_stk3 <= state_stk2;
	state_stk4 <= state_stk3;
	state_stk5 <= state_stk4;
	state_stk6 <= state_stk5;
end
endtask

task tPTRAPcc;
begin
	vecno <= `TRAPV_VEC;
	goto (TRAP);
end
endtask

task tIllegal;
begin
	is_illegal <= 1'b1;
  vecno <= `ILLEGAL_VEC;
  goto (TRAP);
end
endtask

task tPMMUIllop;
begin
	is_illegal <= 1'b1;
  vecno <= `PMMU_ILLOP_VEC;
  goto (TRAP);
end
endtask

task tFormat;
begin
	is_format <= 1'b1;
  vecno <= `FORMAT_VEC;
  goto (TRAP);
end
endtask

task tPrivilegeViolation;
begin
	is_priv <= 1'b1;
	vecno <= `PRIV_VEC;
	goto (TRAP);
end
endtask

task tBadBranchDisp;
begin
	isr <= srx;
	tf <= 1'b0;
	sf <= 1'b1;
	vecno <= `DISP_VEC;
	goto (TRAP3);
end
endtask

// MMMRRR needs to be set already when the STORE_IN_DEST state is entered.
// This state is entered after being popped off the state stack.
// If about to fetch the next instruction and trace is enabled, then take the
// trace trap.
task ret;
begin
	if (state_stk1==STORE_IN_DEST ||
			state_stk1==ADDX2 ||	
			state_stk1==SUBX2 ||
			state_stk1==BCD0 ||
			state_stk1==CMPM)
		MMMRRR <= 1'b1;
	if (state_stk1==IFETCH) begin
		rext2 <= rext;
		rext <= FALSE;
		if (rext2) begin
			rext2 <= FALSE;
			Xnx <= 3'b000;
			Rnx <= 3'b000;
			Nnx <= 3'b000;
		end
	end
	// TRAP will come back here for a second try at returning. If trace is on
	// then a return is not done, instead flow goes to the TRAP sequence which
	// will then do a ret(), but this time trace will be off.
	if (state_stk1==IFETCH && tf && ir != 16'h4E73) begin
		is_trace <= 1'b1;
		state <= TRAP;
	end
	else begin
		state <= state_stk1;
		state_stk1 <= state_stk2;
		state_stk2 <= state_stk3;
		state_stk3 <= state_stk4;
		state_stk4 <= state_stk5;
		state_stk5 <= state_stk6;
	end
end
endtask

function [7:0] fnATCFind;
input [2:0] fc;
input [31:0] ea;
integer n2;
begin
	fnATCFind = 8'hFF;
	for (n2 = 0; n2 < $size(atc); n2 = n2 + 1)
		if (atc[n2].v) begin
			if ((atc[n2].func==fc) && (ea >> pmmu_tc.PS) == atc[n2].vpn) begin
				fnATCFind = n2;
				break;
			end
		end
end
endfunction

endmodule

