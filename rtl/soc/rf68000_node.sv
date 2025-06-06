`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
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

import nic_pkg::*;

module rf68000_node(id, rst1, rst2, nic_rst, clk, dfclk, clken1, clken2, packet_i, packet_o, 
	rpacket_i, rpacket_o, ipacket_i, ipacket_o);
parameter SUPPORT_DECFLT = 1'b1;
input [4:0] id;
input rst1;
input rst2;
input nic_rst;
input clk;
input dfclk;
input clken1;
input clken2;
input packet_t packet_i;
output packet_t packet_o;
input packet_t rpacket_i;
output packet_t rpacket_o;
input ipacket_t ipacket_i;
output ipacket_t ipacket_o;

wire [2:0] fc1, fc2, fc1a;
wire cyc1, stb1, ack1;
wire cyc1a, stb1a, ack1a;
wire cyc2, stb2, ack2;
wire we1, we2, we1a;
wire [3:0] sel1, sel2, sel1a;
wire [31:0] adr1, adr2, adr1a;
reg [31:0] dati1, dati2;
wire [31:0] dati1a;
wire [31:0] dato1, dato2, dato1a;
wire ram1_en, ram2_en;
wire [3:0] ram1_we, ram2_we;
wire [31:0] ram1_adr, ram2_adr;
wire [31:0] ram1_dati, ram2_dati;
wire [31:0] ram1_dato, ram2_dato;
wire [31:0] ram1_dat, ram2_dat;
wire ram1_ack, ram1_aack;
wire ram2_ack, ram2_aack;
wire [2:0] nic1_fc, nic2_fc;
wire nic1_cyc, nic1_stb, nic1_ack, nic1_we;
wire nic2_cyc, nic2_stb, nic2_ack, nic2_we;
wire [31:0] nic1_dato, nic2_dato, nic1_dati, nic2_dati;
wire [3:0] nic1_sel, nic2_sel;
wire [31:0] nic1_adr, nic2_adr;
wire nic1_sack, nic2_sack;
wire [31:0] nic1_sdato, nic2_sdato;
wire [2:0] cpu1_irq, cpu2_irq;
wire [7:0] cpu1_icause, cpu2_icause;
wire err1, err2, err1a;
wire vpa1, vpa2, vpa1a;
wire spram1_ack, spram2_ack;
wire [31:0] spram1o, spram2o;
wire [7:0] asid1, asid2;
wire mmus1, mmus2;
wire ios1, ios2;
wire iops1, iops2;
reg [31:0] icause1 [0:7];
reg [31:0] icause2 [0:7];

wire rst = rst1|rst2;

packet_t packet_x;
packet_t rpacket_x;
ipacket_t ipacket_x;

assign ack1 = nic1_sack|ram1_ack|spram1_ack;
assign ack2 = nic2_sack|ram2_ack|spram2_ack;
always_comb
	casez({fc1,adr1[31:15]})
//	20'b111?????????????????:	dati1 <= icause1[adr1[3:1]];
	20'b???00000000000000???:	dati1 <= ram1_dat;
	20'b???00000000000001000:	dati1 <= spram1o;
	default:	dati1 <= nic1_sdato;
	endcase
always_comb
	casez({fc2,adr2[31:15]})
//	20'b111?????????????????:	dati2 <= icause2[adr2[3:1]];
	20'b???00000000000000???:	dati2 <= ram2_dat;
	20'b???00000000000001000:	dati2 <= spram2o;
	default:	dati2 <= nic2_sdato;
	endcase

always_ff @(posedge clk)
	if (cpu1_irq!=3'b000)
		icause1[cpu1_irq] <= {24'd0,cpu1_icause};
always_ff @(posedge clk)
	if (cpu2_irq!=3'b000)
		icause2[cpu2_irq] <= {24'd0,cpu2_icause};

/*
always_comb
	case(id)
	5'd1:	romname = "rom1.mem";
	5'd2:	romname = "rom2.mem";
	5'd3:	romname = "rom3.mem";
	5'd4:	romname = "rom4.mem";
	5'd5:	romname = "rom5.mem";
	5'd6:	romname = "rom6.mem";
	5'd7:	romname = "rom7.mem";
	default:	romname = "rom1.mem";
	endcase
*/

wire [2:0] irq;
wire firq0;

rf68000_nic unic1
(
	.id({id,1'b0}),
	.rst_i(nic_rst),
	.clk_i(clk),
	.s_cti_i(3'd0),
	.s_atag_o(),
	.s_cyc_i(cyc1),
	.s_stb_i(stb1),
	.s_ack_o(nic1_sack),
	.s_aack_o(),
	.s_rty_o(),
	.s_err_o(err1),
	.s_vpa_o(vpa1),
	.s_we_i(we1),
	.s_sel_i(sel1),
	.s_asid_i(asid1),
	.s_mmus_i(mmus1),
	.s_ios_i(ios1),
	.s_iops_i(iops1),
	.s_fc_i(fc1),
	.s_adr_i(adr1),
	.s_dat_i(dato1),
	.s_dat_o(nic1_sdato),
	.m_cyc_o(nic1_cyc),
	.m_stb_o(nic1_stb),
	.m_ack_i(nic1_ack),
	.m_err_i(1'b0),
	.m_vpa_i(1'b0),
	.m_we_o(nic1_we),
	.m_sel_o(nic1_sel),
	.m_asid_o(),
	.m_mmus_o(),
	.m_ios_o(),
	.m_iops_o(),
	.m_fc_o(nic1_fc),
	.m_adr_o(nic1_adr),
	.m_dat_o(nic1_dato),
	.m_dat_i(nic1_dati),
	.packet_i(packet_i),
	.packet_o(packet_x),
	.ipacket_i(ipacket_i),
	.ipacket_o(ipacket_x),
	.rpacket_i(rpacket_i),
	.rpacket_o(rpacket_x),
	.irq_i(3'b000),
	.firq_i(1'b0),
	.cause_i(8'h00),
	.iserver_i(6'h00),
	.irq_o(cpu1_irq),
	.firq_o(),
	.cause_o(cpu1_icause)
);

rf68000_nic unic2
(
	.id({id,1'b1}),
	.rst_i(nic_rst),
	.clk_i(clk),
	.s_cti_i(3'd0),
	.s_atag_o(),
	.s_cyc_i(cyc2),
	.s_stb_i(stb2),
	.s_ack_o(nic2_sack),
	.s_aack_o(),
	.s_rty_o(),
	.s_err_o(err2),
	.s_vpa_o(vpa2),
	.s_we_i(we2),
	.s_sel_i(sel2),
	.s_asid_i(asid2),
	.s_mmus_i(mmus2),
	.s_ios_i(ios2),
	.s_iops_i(iops2),
	.s_fc_i(fc2),
	.s_adr_i(adr2),
	.s_dat_i(dato2),
	.s_dat_o(nic2_sdato),
	.m_cyc_o(nic2_cyc),
	.m_stb_o(nic2_stb),
	.m_ack_i(nic2_ack),
	.m_err_i(1'b0),
	.m_vpa_i(1'b0),
	.m_we_o(nic2_we),
	.m_sel_o(nic2_sel),
	.m_asid_o(),
	.m_mmus_o(),
	.m_ios_o(),
	.m_iops_o(),
	.m_fc_o(nic2_fc),
	.m_adr_o(nic2_adr),
	.m_dat_o(nic2_dato),
	.m_dat_i(nic2_dati),
	.packet_i(packet_x),
	.packet_o(packet_o),
	.ipacket_i(ipacket_x),
	.ipacket_o(ipacket_o),
	.rpacket_i(rpacket_x),
	.rpacket_o(rpacket_o),
	.irq_i(3'b000),
	.firq_i(1'b0),
	.cause_i(8'h00),
	.iserver_i(6'h00),
	.irq_o(cpu2_irq),
	.firq_o(),
	.cause_o(cpu2_icause)
);

rf68000_node_arbiter undarb1
(
	.id({id[2:0],1'b0}),
	.rst_i(rst),
	.clk_i(clk),
	.cpu_cyc(cyc1 && adr1[31:18]==14'h000),
	.cpu_stb(stb1 && adr1[31:18]==14'h000),
	.cpu_ack(ram1_ack),
	.cpu_aack(ram1_aack),
	.cpu_we(we1),
	.cpu_sel(sel1),
	.cpu_adr(adr1),
	.cpu_dato(dato1),
	.cpu_dati(ram1_dat),
	.nic_cyc(nic1_cyc),
	.nic_stb(nic1_stb),
	.nic_ack(nic1_ack),
	.nic_we(nic1_we),
	.nic_sel(nic1_sel),
	.nic_adr(nic1_adr),
	.nic_dati(nic1_dati),
	.nic_dato(nic1_dato),
	.ram_en(ram1_en),
	.ram_we(ram1_we),
	.ram_adr(ram1_adr),
	.ram_dati(ram1_dati),
	.ram_dato(ram1_dato)
);

rf68000_node_arbiter undarb2
(
	.id({id[2:0],1'b1}),
	.rst_i(rst),
	.clk_i(clk),
	.cpu_cyc(cyc2 && adr2[31:18]==14'h000),
	.cpu_stb(stb2 && adr2[31:18]==14'h000),
	.cpu_ack(ram2_ack),
	.cpu_aack(ram2_aack),
	.cpu_we(we2),
	.cpu_sel(sel2),
	.cpu_adr(adr2),
	.cpu_dato(dato2),
	.cpu_dati(ram2_dat),
	.nic_cyc(nic2_cyc),
	.nic_stb(nic2_stb),
	.nic_ack(nic2_ack),
	.nic_we(nic2_we),
	.nic_sel(nic2_sel),
	.nic_adr(nic2_adr),
	.nic_dati(nic2_dati),
	.nic_dato(nic2_dato),
	.ram_en(ram2_en),
	.ram_we(ram2_we),
	.ram_adr(ram2_adr),
	.ram_dati(ram2_dati),
	.ram_dato(ram2_dato)
);

rf68000 #(.SUPPORT_DECFLT(SUPPORT_DECFLT)) ucpu1
(
	.coreno_i({26'd0,id,1'b0}),
	.clken_i(clken1),
	.rst_i(rst1),
	.rst_o(),
	.clk_i(clk),
	.dfclk_i(dfclk),
	.nmi_i(1'b0),
	.ipl_i(cpu1_irq),
	.vpa_i(vpa1a),
	.lock_o(),
	.cyc_o(cyc1a),
	.stb_o(stb1a),
	.ack_i(ack1a),
	.err_i(err1a),
	.rty_i(1'b0),
	.we_o(we1a),
	.sel_o(sel1a),
	.fc_o(fc1a),
	.asid_o(asid1),
	.mmus_o(mmus1),
	.ios_o(ios1),
	.iops_o(iops1),
	.adr_o(adr1a),
	.dat_i(dati1a),
	.dat_o(dato1a)
);

rf68851 ummu1
(
	.rst_i(rst1),
	.clk_i(clk),
	
	.cfc_i(fc1a),
	.ccyc_i(cyc1a),
	.cstb_i(stb1a),
	.cack_o(ack1a),
	.cerr_o(err1a),
	.cvpa_o(vpa1a),
	.cwe_i(we1a),
	.csel_i(sel1a),
	.cadr_i(adr1a),
	.cdat_i(dati1a),
	.cdat_o(dato1a),
	
	.mfc_o(fc1),
	.mcyc_o(cyc1),
	.mstb_o(stb1),
	.mack_i(ack1),
	.merr_i(err1),
	.mvpa_i(vpa1),
	.mwe_o(we1),
	.msel_o(sel1),
	.madr_o(adr1),
	.mdat_o(dato1),
	.mdat_i(dati1),

	.page_fault_o()
);


rf68000 #(.SUPPORT_DECFLT(SUPPORT_DECFLT)) ucpu2
(
	.coreno_i({26'd0,id,1'b1}),
	.clken_i(clken2),
	.rst_i(rst2),
	.rst_o(),
	.clk_i(clk),
	.dfclk_i(dfclk),
	.nmi_i(1'b0),
	.ipl_i(cpu2_irq),
	.vpa_i(vpa2),
	.lock_o(),
	.cyc_o(cyc2),
	.stb_o(stb2),
	.ack_i(ack2),
	.err_i(err2),
	.rty_i(1'b0),
	.we_o(we2),
	.sel_o(sel2),
	.fc_o(fc2),
	.asid_o(asid2),
	.mmus_o(mmus2),
	.ios_o(ios2),
	.iops_o(iops2),
	.adr_o(adr2),
	.dat_i(dati2),
	.dat_o(dato2)
);

// +---------------------------------------------------------------------------------------------------------------------+
// | MEMORY_INIT_FILE     | String             | Default value = none.                                                   |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify "none" (including quotes) for no memory initialization, or specify the name of a memory initialization file-|
// | Enter only the name of the file with .mem extension, including quotes but without path (e.g. "my_file.mem").        |
// | File format must be ASCII and consist of only hexadecimal values organized into the specified depth by              |
// | narrowest data width generic value of the memory. Initialization of memory happens through the file name specified only when parameter|
// | MEMORY_INIT_PARAM value is equal to "". |                                                                           |
// | When using XPM_MEMORY in a project, add the specified file to the Vivado project as a design source.                |
// +---------------------------------------------------------------------------------------------------------------------+
// | MEMORY_INIT_PARAM    | String             | Default value = 0.                                                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify "" or "0" (including quotes) for no memory initialization through parameter, or specify the string          |
// | containing the hex characters. Enter only hex characters with each location separated by delimiter (,).             |
// | Parameter format must be ASCII and consist of only hexadecimal values organized into the specified depth by         |
// | narrowest data width generic value of the memory.For example, if the narrowest data width is 8, and the depth of    |
// | memory is 8 locations, then the parameter value should be passed as shown below.                                    |
// | parameter MEMORY_INIT_PARAM = "AB,CD,EF,1,2,34,56,78"                                                               |
// | Where "AB" is the 0th location and "78" is the 7th location.                                                        |
// +---------------------------------------------------------------------------------------------------------------------+
// | USE_MEM_INIT         | Integer            | Range: 0 - 1. Default value = 1.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specify 1 to enable the generation of below message and 0 to disable generation of the following message completely.|
// | "INFO - MEMORY_INIT_FILE and MEMORY_INIT_PARAM together specifies no memory initialization.                         |
// | Initial memory contents will be all 0s."                                                                            |
// | NOTE: This message gets generated only when there is no Memory Initialization specified either through file or      |
// | Parameter.                                                                                                          |

   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(15),               // DECIMAL
      .ADDR_WIDTH_B(15),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
      .BYTE_WRITE_WIDTH_B(8),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("rom68k.mem"),    // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("block"),      // String
      .MEMORY_SIZE(131072*8),         // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A(32),         // DECIMAL
      .READ_DATA_WIDTH_B(32),         // DECIMAL
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
      .WRITE_DATA_WIDTH_B(32),        // DECIMAL
      .WRITE_MODE_A("no_change"),     // String
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(ram1_dato),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(ram2_dato),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),				             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             				// 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(ram1_adr[16:2]),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(ram2_adr[16:2]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(ram1_dati),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(ram2_dati),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(ram1_en),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(ram2_en),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), 					// 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectdbiterrb(1'b0), 					// 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), 					// 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterrb(1'b0), 					// 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(1'b0),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(ram1_we),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(ram2_we)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

wire cs_spram1 = adr1[31:15]==17'h8 && cyc1 && stb1;
wire cs_spram2 = adr2[31:15]==17'h8 && cyc2 && stb2;

ack_gen uag1
(
	.rst_i(rst1),
	.clk_i(clk),
	.ce_i(1'b1),
	.i(cs_spram1 & ~we1),
	.rid_i({id,1'b0}),
	.we_i(cs_spram1 & we1),
	.wid_i({id,1'b0}),
	.o(spram1_ack), 
	.rid_o(),
	.wid_o()
);

ack_gen uag2
(
	.rst_i(rst2),
	.clk_i(clk),
	.ce_i(1'b1),
	.i(cs_spram2 & ~we2),
	.rid_i({id,1'b1}),
	.we_i(cs_spram2 & we2),
	.wid_i({id,1'b1}),
	.o(spram2_ack), 
	.rid_o(),
	.wid_o()
);

	 // xpm_memory_spram: Single Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_spram #(
      .ADDR_WIDTH_A(13),              // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),       // DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE("none"),     // String
      .MEMORY_INIT_PARAM("0"),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("auto"),     // String
      .MEMORY_SIZE(32768*8),            // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(32),        // DECIMAL
      .READ_LATENCY_A(2),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .USE_MEM_INIT_MMI(0),          // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(32),       // DECIMAL
      .WRITE_MODE_A("read_first"),   // String
      .WRITE_PROTECT(1)              // DECIMAL
   )
   xpm_memory_spram_inst1 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(spram1o),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .addra(adr1[14:2]),          // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A.
      .dina(dato1),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(cs_spram1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(1'b0),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(sel1 & {4{we1}})                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // End of xpm_memory_spram_inst instantiation
				
	 // xpm_memory_spram: Single Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_spram #(
      .ADDR_WIDTH_A(13),              // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),       // DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE("none"),     // String
      .MEMORY_INIT_PARAM("0"),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("auto"),     // String
      .MEMORY_SIZE(32768*8),            // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(32),        // DECIMAL
      .READ_LATENCY_A(2),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .USE_MEM_INIT_MMI(0),          // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(32),       // DECIMAL
      .WRITE_MODE_A("read_first"),   // String
      .WRITE_PROTECT(1)              // DECIMAL
   )
   xpm_memory_spram_inst2 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(spram2o),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .addra(adr2[14:2]),          // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A.
      .dina(dato2),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(cs_spram2),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(1'b0),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(sel2 & {4{we2}})                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // End of xpm_memory_spram_inst instantiation
				
							
endmodule
