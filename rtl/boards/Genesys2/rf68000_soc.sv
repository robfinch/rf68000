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

import wishbone_pkg::*;
import nic_pkg::*;

//`define USE_GATED_CLOCK	1'b1
//`define HAS_MMU 1'b1

module rf68000_soc(cpu_reset_n, sysclk_p, sysclk_n, led, sw, btnl, btnr, btnc, btnd, btnu, 
  ps2_clk_0, ps2_data_0, uart_rx_out, uart_tx_in,
  hdmi_tx_clk_p, hdmi_tx_clk_n, hdmi_tx_p, hdmi_tx_n,
//  ac_mclk, ac_adc_sdata, ac_dac_sdata, ac_bclk, ac_lrclk,
//  rtc_clk, rtc_data,
//  spiClkOut, spiDataIn, spiDataOut, spiCS_n,
//  sd_cmd, sd_dat, sd_clk, sd_cd, sd_reset,
//  pti_clk, pti_rxf, pti_txe, pti_rd, pti_wr, pti_siwu, pti_oe, pti_dat, spien,
  oled_sdin, oled_sclk, oled_dc, oled_res, oled_vbat, oled_vdd
  ,ddr3_ck_p,ddr3_ck_n,ddr3_cke,ddr3_reset_n,ddr3_ras_n,ddr3_cas_n,ddr3_we_n,
  ddr3_ba,ddr3_addr,ddr3_dq,ddr3_dqs_p,ddr3_dqs_n,ddr3_dm,ddr3_odt,
  ddr3_cs_n
//    gtp_clk_p, gtp_clk_n,
//    dp_tx_hp_detect, dp_tx_aux_p, dp_tx_aux_n, dp_rx_aux_p, dp_rx_aux_n,
//    dp_tx_lane0_p, dp_tx_lane0_n, dp_tx_lane1_p, dp_tx_lane1_n
);
parameter WXGA800x600 = 1'b1;
parameter HAS_CPU = 1'b1;
parameter HAS_FRAME_BUFFER = 1'b1;
parameter HAS_TEXTCTRL = 1'b1;
parameter HAS_PRNG = 1'b1;
parameter HAS_UART = 1'b1;
parameter HAS_PS2KBD = 1'b1;
input cpu_reset_n;
input sysclk_p;
input sysclk_n;
output reg [7:0] led;
input [7:0] sw;
input btnl;
input btnr;
input btnc;
input btnd;
input btnu;
inout ps2_clk_0;
tri ps2_clk_0;
inout ps2_data_0;
tri ps2_data_0;
output uart_rx_out;
input uart_tx_in;
output hdmi_tx_clk_p;
output hdmi_tx_clk_n;
output [2:0] hdmi_tx_p;
output [2:0] hdmi_tx_n;

output oled_sdin;
output oled_sclk;
output oled_dc;
output oled_res;
output oled_vbat;
output oled_vdd;

output [0:0] ddr3_ck_p;
output [0:0] ddr3_ck_n;
output [0:0] ddr3_cke;
output [0:0] ddr3_reset_n;
output [0:0] ddr3_ras_n;
output [0:0] ddr3_cas_n;
output [0:0] ddr3_we_n;
output [2:0] ddr3_ba;
output [14:0] ddr3_addr;
inout [31:0] ddr3_dq;
inout [3:0] ddr3_dqs_p;
inout [3:0] ddr3_dqs_n;
output [3:0] ddr3_dm;
output [0:0] ddr3_odt;
output [0:0] ddr3_cs_n;


wire rst, rstn;
wire xrst = ~cpu_reset_n;
wire locked;
wire clk20, clk40, clk50, clk100, clk200;
wire xclk_bufg;
wire node_clk = clk20;
wire node_clk1;
wire node_clk2;
wire node_clk3;
wire node_clk4;
wire dot_clk = clk40;
wb_cmd_request256_t ch7req;
wb_cmd_request256_t ch7dreq;	// DRAM request
wb_cmd_response256_t ch7resp;
wb_cmd_request256_t fb_req;
wb_cmd_response256_t fb_resp;
wire cpu_cyc;
wire cpu_stb;
wire cpu_we;
wire [31:0] cpu_adr;
wire [31:0] cpu_dato;
reg ack;
wire vpa;
wire [3:0] sel;
reg [31:0] dati;
wire [31:0] dato;
wire mmus, ios, iops;
wire mmu_ack;
wire [31:0] mmu_dato;
wire br1_cyc;
wire br1_stb;
reg br1_ack;
wire [3:0] br1_sel;
wire [31:0] br1_adr;
wire [31:0] br1_cdato;
reg [31:0] br1_dati;
wire [31:0] br1_dato;
wire br1_cack;
wire br3_cyc;
wire br3_stb;
reg br3_ack;
wire [3:0] br3_sel;
wire [31:0] br3_adr;
wire [31:0] br3_cdato;
reg [31:0] br3_dati;
wire [31:0] br3_dato;
wire br3_cack;
wire fb_ack;
wire [31:0] fb_dato;
wire tc_ack;
wire [31:0] tc_dato;
wire kbd_ack;
wire kbd_irq;
wire [7:0] kbd_dato;
wire rand_ack;
wire [31:0] rand_dato;
wire sema_ack;
wire [31:0] sema_dato;
wire scr_ack;
wire [31:0] scr_dato;
wire acia_ack;
wire [31:0] acia_dato;
wire acia_irq;
wire i2c2_ack;
wire [7:0] i2c2_dato;
wire i2c2_irq;
wire plic_ack;
wire [3:0] plic_irq;
wire [31:0] plic_dato;
wire [7:0] plic_cause;
wire [5:0] plic_core;
mpmc10_pkg::mpmc10_state_t dram_state;
wire [7:0] asid;
wire io_ack;
wire [31:0] io_dato;
wire io_gate, io_gate_en;

wire leds_ack;
reg [7:0] rst_reg;
wire rst_ack;

wire hSync, vSync;
wire blank, border;
wire [7:0] red, blue, green;
wire [39:0] fb_rgb, tc_rgb;
assign red = tc_rgb[35:28];
assign green = tc_rgb[23:16];
assign blue = tc_rgb[11:4];

// -----------------------------------------------------------------------------
// Input debouncing
// -----------------------------------------------------------------------------

wire btnu_db, btnd_db, btnl_db, btnr_db, btnc_db;
BtnDebounce udbu (clk20, btnu, btnu_db);
BtnDebounce udbd (clk20, btnd, btnd_db);
BtnDebounce udbl (clk20, btnl, btnl_db);
BtnDebounce udbr (clk20, btnr, btnr_db);
BtnDebounce udbc (clk20, btnc, btnc_db);

// -----------------------------------------------------------------------------
// Clock generation
// -----------------------------------------------------------------------------

WXGA800x600_clkgen ucg1
(
  // Clock out ports
  .clk200(clk200),	// 200 MHz	dvi/ddr3 interface clock
  .clk100(clk100),
  .clk50(clk50),
  .clk40(clk40),		// 40.000 MHz video / cpu clock
  .clk20(clk20),		// cpu
  .clk17(clk17),
  .clk33(clk33),
//  .clk10(clk10),
//  .clk14(clk14),		// 16x baud clock
  // Status and control signals
  .reset(xrst), 
  .locked(locked),       // output locked
 // Clock in ports
  .clk_in1_p(sysclk_p),
  .clk_in1_n(sysclk_n)
);

assign rst = !locked;

rgb2dvi ur2d1
(
	.rst(rst),
	.PixelClk(dot_clk),
	.SerialClk(clk200),
	.red(red[7:0]),
	.green(green[7:0]),
	.blue(blue[7:0]),
	.de(~blank),
	.hSync(hSync),	// ~ for 640x480 100 Hz
	.vSync(vSync),
	.TMDS_Clk_p(hdmi_tx_clk_p),
	.TMDS_Clk_n(hdmi_tx_clk_n),
	.TMDS_Data_p(hdmi_tx_p),
	.TMDS_Data_n(hdmi_tx_n)
);

wire cs_io;
assign cs_io = ios;//ch7req.adr[31:20]==12'hFD0;
wire cs_io2;
// These two decodes outside the IO area.
wire cs_iobitmap;
assign cs_iobitmap = iops;	//ch7req.adr[31:16]==16'hFC10;
wire cs_mmu;
assign cs_mmu = mmus;	//cpu_adr[31:16]==16'hFC00 || cpu_adr[31:16]==16'hFC01;

wire cs_tc = (ch7req.padr[31:16]==16'hFD00 || ch7req.padr[31:16]==16'hFD01 ||
							ch7req.padr[31:16]==16'hFD02 || ch7req.padr[31:16]==16'hFD03 ||
							ch7req.padr[31:16]==16'hFD04 || ch7req.padr[31:16]==16'hFD08
							) && ch7req.stb && cs_io2;
wire cs_br1_tc = (br1_adr[31:16]==16'hFD00 || br1_adr[31:16]==16'hFD01 ||
									br1_adr[31:16]==16'hFD02 || br1_adr[31:16]==16'hFD03 ||
									br1_adr[31:16]==16'hFD04 || br1_adr[31:16]==16'hFD08
									) && br1_stb && cs_io2;
wire cs_fb = ch7req.padr[31:16]==16'hFE40 && ch7req.stb && cs_io2;
wire cs_br1_fb = br1_adr[31:16]==16'hFE40 && br1_stb && cs_io2;
wire cs_leds = ch7req.padr[31:8]==24'hFD0FFF && ch7req.stb && cs_io2;
wire cs_br3_leds = br3_adr[31:8]==24'hFD0FFF && br3_stb && cs_io2;
wire cs_br3_rst  = br3_adr[31:8]==24'hFD0FFC && br3_stb && cs_io2;
wire cs_kbd  = ch7req.padr[31:8]==24'hFD0FFE && ch7req.stb && cs_io2;
wire cs_br3_kbd  = br3_adr[31:8]==24'hFD0FFE && br3_stb && cs_io2;
wire cs_rand  = ch7req.padr[31:8]==24'hFD0FFD && ch7req.stb && cs_io2;
wire cs_br3_rand  = br3_adr[31:8]==24'hFD0FFD && br3_stb && cs_io2;
wire cs_sema = ch7req.padr[31:16]==16'hFD05 && ch7req.stb && cs_io2;
wire cs_acia = ch7req.padr[31:12]==20'hFD060 && ch7req.stb && cs_io2;
wire cs_br3_acia = br3_adr[31:12]==20'hFD060 && br3_stb && cs_io2;
wire cs_br3_i2c2 = br3_adr[31:12]==20'hFD069 && br3_stb && cs_io2;
wire cs_scr = ch7req.padr[31:20]==12'h001 && ch7req.stb;
wire cs_plic = ch7req.padr[31:12]==20'hFD090 && cs_io2;
wire cs_br3_plic = br3_adr[31:12]==20'hFD090 && cs_io2;
wire cs_dram = ch7req.padr[31:30]==2'b01 && !cs_mmu && !cs_iobitmap && !cs_io;

rfFrameBuffer uframebuf1
(
	.rst_i(rst),
	.irq_o(),
	.cs_config_i(1'b0),
	.cs_io_i(1'b0),
	.s_clk_i(node_clk),
	.s_cyc_i(br1_cyc),
	.s_stb_i(br1_stb),
	.s_ack_o(fb_ack),
	.s_we_i(br1_we),
	.s_sel_i(br1_sel),
	.s_adr_i(br1_adr),
	.s_dat_i(br1_dato),
	.s_dat_o(fb_dato),
	.m_clk_i(clk50),
	.m_fst_o(), 
//	m_cyc_o, m_stb_o, m_ack_i, m_we_o, m_sel_o, m_adr_o, m_dat_i, m_dat_o,
	.wbm_req(fb_req),
	.wbm_resp(fb_resp),
	.dot_clk_i(clk40),
	.zrgb_o(fb_rgb),
	.xonoff_i(sw[0]),
	.xal_o(),
	.hsync_o(hSync),
	.vsync_o(vSync),
	.blank_o(blank),
	.border_o(border),
	.hctr_o(),
	.vctr_o(),
	.fctr_o(),
	.vblank_o()
);

rfTextController utc1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_config_i(1'b0),
	.cs_io_i(cs_br1_tc),
	.cti_i(3'd0),
	.cyc_i(br1_cyc),
	.stb_i(br1_stb),
	.ack_o(tc_ack),
	.wr_i(br1_we),
	.sel_i(br1_sel),
	.adr_i(br1_adr[31:0]),
	.dat_i(br1_dato),
	.dat_o(tc_dato),
	.dot_clk_i(clk40),
	.hsync_i(hSync),
	.vsync_i(vSync),
	.blank_i(blank),
	.border_i(border),
	.zrgb_i(fb_rgb),
	.zrgb_o(tc_rgb),
	.xonoff_i(sw[1])
);

IOBridge ubridge1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.s1_cyc_i(ch7req.cyc & io_gate_en),
	.s1_stb_i(ch7req.stb & io_gate_en),
	.s1_ack_o(br1_cack),
	.s1_we_i(ch7req.we & io_gate_en),
	.s1_sel_i(sel),
	.s1_adr_i(ch7req.padr),
	.s1_dat_i(dato),
	.s1_dat_o(br1_cdato),
	.s2_cyc_i(1'b0),
	.s2_stb_i(1'b0),
	.s2_ack_o(),
	.s2_we_i(1'b0),
	.s2_sel_i(4'h0),
	.s2_adr_i(32'h0),
	.s2_dat_i(32'h0),
	.s2_dat_o(),
	.m_cyc_o(br1_cyc),
	.m_stb_o(br1_stb),
	.m_ack_i(br1_ack),
	.m_we_o(br1_we),
	.m_sel_o(br1_sel),
	.m_adr_o(br1_adr),
	.m_dat_i(br1_dati),
	.m_dat_o(br1_dato)
);

always_ff @(posedge node_clk)
	br1_dati <= fb_dato|tc_dato;

always_ff @(posedge node_clk)
	br1_ack <= fb_ack|tc_ack;

PS2kbd #(.pClkFreq(50000000)) ukbd1
(
	// WISHBONE/SoC bus interface 
	.rst_i(rst),
	.clk_i(node_clk),	// system clock
	.cs_i(cs_br3_kbd),
	.cyc_i(br3_cyc),
	.stb_i(br3_stb),	// core select (active high)
	.ack_o(kbd_ack),	// bus transfer acknowledged
	.we_i(br3_we),	// I/O write taking place (active high)
	.adr_i(br3_adr[3:0]),	// address
	.dat_i(br3_dato[7:0]),	// data in
	.dat_o(kbd_dato),	// data out
	.db(),
	//-------------
	.irq(kbd_irq),	// interrupt request (active high)
	.kclk_i(ps2_clk_0),	// keyboard clock from keyboard
	.kclk_en(kclk_en),	// 1 = drive clock low
	.kdat_i(ps2_data_0),	// keyboard data
	.kdat_en(kdat_en)	// 1 = drive data low
);

assign ps2_clk_0 = kclk_en ? 1'b0 : 'bz;
assign ps2_data_o = kdat_en ? 1'b0 : 'bz;

random urnd1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_i(cs_br3_rand),
	.cyc_i(br3_cyc),
	.stb_i(br3_stb),
	.ack_o(rand_ack),
	.we_i(br3_we),
	.adr_i(br3_adr[3:0]),
	.dat_i(br3_dato),
	.dat_o(rand_dato)
);

uart6551 #(.pClkFreq(100), .pClkDiv(24'd130)) uuart
(
	.rst_i(rst),
	.clk_i(clk100),
	.cs_i(cs_br3_acia),
	.irq_o(acia_irq),
	.cyc_i(br3_cyc),
	.stb_i(br3_stb),
	.ack_o(acia_ack),
	.we_i(br3_we),
	.sel_i(br3_sel),
	.adr_i(br3_adr[3:2]),
	.dat_i(br3_dato),
	.dat_o(acia_dato),
	.cts_ni(1'b0),
	.rts_no(),
	.dsr_ni(1'b0),
	.dcd_ni(1'b0),
	.dtr_no(),
	.ri_ni(1'b1),
	.rxd_i(uart_tx_in),
	.txd_o(uart_rx_out),
	.data_present(),
	.rxDRQ_o(),
	.txDRQ_o(),
	.xclk_i(clk20),
	.RxC_i(clk20)
);

wire rtc_clko, rtc_clkoen;
wire rtc_datao, rtc_dataoen;
/*
i2c_master_top ui2cm1
(
	.wb_clk_i(node_clk),
	.wb_rst_i(rst),
	.arst_i(~rst),
	.wb_adr_i(br3_adr[2:0]),
	.wb_dat_i(br3_dato[7:0]),
	.wb_dat_o(i2c2_dato),
	.wb_we_i(br3_we),
	.wb_stb_i(cs_br3_i2c2),
	.wb_cyc_i(br3_cyc),
	.wb_ack_o(i2c2_ack),
	.wb_inta_o(i2c2_irq),
	.scl_pad_i(rtc_clk),
	.scl_pad_o(rtc_clko),
	.scl_padoen_o(rtc_clkoen),
	.sda_pad_i(rtc_data),
	.sda_pad_o(rtc_datao), 
	.sda_padoen_o(rtc_dataoen)
);
assign rtc_clk = rtc_clkoen ? 'bz : rtc_clko;
assign rtc_data = rtc_dataoen ? 'bz : rtc_datao;
*/

IOBridge ubridge3
(
	.rst_i(rst),
	.clk_i(node_clk),
	.s1_cyc_i(ch7req.cyc & io_gate_en),
	.s1_stb_i(ch7req.stb & io_gate_en),
	.s1_ack_o(br3_cack),
	.s1_we_i(ch7req.we & io_gate_en),
	.s1_sel_i(sel),
	.s1_adr_i(ch7req.padr),
	.s1_dat_i(dato),
	.s1_dat_o(br3_cdato),
	.s2_cyc_i(1'b0),
	.s2_stb_i(1'b0),
	.s2_ack_o(),
	.s2_we_i(1'b0),
	.s2_sel_i(4'h0),
	.s2_adr_i(32'h0),
	.s2_dat_i(32'h0),
	.s2_dat_o(),
	.m_cyc_o(br3_cyc),
	.m_stb_o(br3_stb),
	.m_ack_i(br3_ack),
	.m_we_o(br3_we),
	.m_sel_o(br3_sel),
	.m_adr_o(br3_adr),
	.m_dat_i(br3_dati),
	.m_dat_o(br3_dato)
);

always_ff @(posedge node_clk)
	casez(cs_br3_leds)
	1'b1:	br3_dati <= led;
	1'b0:	br3_dati <= {4{kbd_dato}}|rand_dato|acia_dato|{4{i2c2_dato}};
	default:	br3_dati <= 'd0;
	endcase

always_ff @(posedge node_clk)
	br3_ack <= leds_ack|kbd_ack|rand_ack|acia_ack|i2c2_ack;

assign leds_ack = cs_br3_leds;
always_ff @(posedge node_clk)
	if (cs_br3_leds & br3_we)
		led <= br3_dato[7:0];

wire calib_complete;
wire [29:0] mem_addr;
wire [2:0] mem_cmd;
wire mem_en;
wire [255:0] mem_wdf_data;
wire [31:0] mem_wdf_mask;
wire mem_wdf_end;
wire mem_wdf_wren;
wire [255:0] mem_rd_data;
wire mem_rd_data_valid;
wire mem_rd_data_end;
wire mem_rdy;
wire mem_wdf_rdy;
wire [11:0] ddr3_temp;
wire app_ref_req;
wire app_ref_ack;
assign app_ref_req = 1'b0;

mig_7series_0 uddr3
(
	.ddr3_dq(ddr3_dq),
	.ddr3_dqs_p(ddr3_dqs_p),
	.ddr3_dqs_n(ddr3_dqs_n),
	.ddr3_addr(ddr3_addr),
	.ddr3_ba(ddr3_ba),
	.ddr3_ras_n(ddr3_ras_n),
	.ddr3_cas_n(ddr3_cas_n),
	.ddr3_we_n(ddr3_we_n),
	.ddr3_ck_p(ddr3_ck_p),
	.ddr3_ck_n(ddr3_ck_n),
	.ddr3_cke(ddr3_cke),
	.ddr3_dm(ddr3_dm),
	.ddr3_odt(ddr3_odt),
	.ddr3_cs_n(ddr3_cs_n),
	.ddr3_reset_n(ddr3_reset_n),
	// Inputs
	.sys_clk_i(clk200),
//    .clk_ref_i(clk200),
	.sys_rst(rstn),//~btnc_db),
	// user interface signals
	.app_addr(mem_addr),
	.app_cmd(mem_cmd),
	.app_en(mem_en),
	.app_wdf_data(mem_wdf_data),
	.app_wdf_end(mem_wdf_end),
	.app_wdf_mask(mem_wdf_mask),
	.app_wdf_wren(mem_wdf_wren),
	.app_rd_data(mem_rd_data),
	.app_rd_data_end(mem_rd_data_end),
	.app_rd_data_valid(mem_rd_data_valid),
	.app_rdy(mem_rdy),
	.app_wdf_rdy(mem_wdf_rdy),
	.app_sr_req(1'b0),
	.app_sr_active(),
	.app_ref_req(app_ref_req),
	.app_ref_ack(app_ref_ack),
	.app_zq_req(1'b0),
	.app_zq_ack(),
	.ui_clk(mem_ui_clk),
	.ui_clk_sync_rst(mem_ui_rst),
	.init_calib_complete(calib_complete),
	.device_temp(ddr3_temp)
);

always_comb
begin
	ch7req.cid <= 4'd7;
	ch7dreq <= ch7req;
	ch7dreq.cid <= 4'd7;
	ch7dreq.cyc <= ch7req.cyc & cs_dram;
	ch7dreq.stb <= ch7req.stb & cs_dram;
end

mpmc10_wb umpmc1
(
	.rst(rst),
	.clk100MHz(clk100),
	.mem_ui_rst(mem_ui_rst),
	.mem_ui_clk(mem_ui_clk),
	.calib_complete(calib_complete),
	.rstn(rstn),
	.app_waddr(),
	.app_rdy(mem_rdy),
	.app_en(mem_en),
	.app_cmd(mem_cmd),
	.app_addr(mem_addr),
	.app_rd_data_valid(mem_rd_data_valid),
	.app_wdf_mask(mem_wdf_mask),
	.app_wdf_data(mem_wdf_data),
	.app_wdf_rdy(mem_wdf_rdy),
	.app_wdf_wren(mem_wdf_wren),
	.app_wdf_end(mem_wdf_end),
	.app_rd_data(mem_rd_data),
	.app_rd_data_end(mem_rd_data_end),
	.ch0clk(clk50),
	.ch1clk(1'b0),
	.ch2clk(1'b0),
	.ch3clk(1'b0),
	.ch4clk(1'b0),
	.ch5clk(1'b0),
	.ch6clk(1'b0),
	.ch7clk(node_clk),
	.ch0i(fb_req),
	.ch0o(fb_resp),
	.ch1i('d0),
	.ch1o(),
	.ch2i('d0),
	.ch2o(),
	.ch3i('d0),
	.ch3o(),
	.ch4i('d0),
	.ch4o(),
	.ch5i('d0),
	.ch5o(),
	.ch6i('d0),
	.ch6o(),
	.ch7i(ch7dreq),
	.ch7o(ch7resp),
	.state(dram_state)
);

binary_semamem usema1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_i(cs_sema),
	.cyc_i(ch7req.cyc),
	.stb_i(ch7req.stb),
	.ack_o(sema_ack),
	.we_i(ch7req.we),
	.adr_i(ch7req.padr[13:0]),
	.dat_i(dato),
	.dat_o(sema_dato)
);

scratchmem uscr1
(
	.rst_i(rst),
	.cs_i(cs_scr),
	.clk_i(node_clk),
	.cyc_i(ch7req.cyc),
	.stb_i(ch7req.stb),
	.ack_o(scr_ack),
	.we_i(ch7req.we),
	.sel_i(sel),
	.adr_i(ch7req.padr[13:0]),
	.dat_i(dato),
	.dat_o(scr_dato)
);

io_bitmap uiob1
(
	.clk_i(node_clk),
	.cs_i(cs_iobitmap),
	.cyc_i(ch7req.cyc),
	.stb_i(ch7req.stb),
	.ack_o(io_ack),
	.we_i(ch7req.we),
	.asid_i(asid),
	.adr_i(ch7req.padr[19:0]),
	.dat_i(dato),
	.dat_o(io_dato),
	.iocs_i(cs_io),
	.gate_o(cs_io2),
	.gate_en(io_gate_en)
);

assign io_irq = cs_io & ~cs_io2 & io_gate_en;

packet_t [5:0] packet;
packet_t [5:0] rpacket;
ipacket_t [5:0] ipacket;

// Generate 100Hz interrupt
reg [23:0] icnt;
reg tmr_irq;

always @(posedge clk100)
if (rst) begin
	icnt <= 24'd1;
	tmr_irq <= 1'b0;
end
else begin
	icnt <= icnt + 2'd1;
	if (icnt==24'd150)
		tmr_irq <= 1'b1;
	else if (icnt==24'd200)
		tmr_irq <= 1'b0;
	else if (icnt==24'd1000000)
		icnt <= 24'd1;
end

// PLIC needs to be able to detect INTA cycle where all address lines are high
// except for a0 to a3.
rf68000_plic uplic1
(
	.rst_i(rst),		// reset
	.clk_i(node_clk),		// system clock
	.cs_i(cs_plic),
	.fc_i(3'b111),
	.cyc_i(ch7req.cyc),
	.stb_i(ch7req.stb),
	.ack_o(plic_ack),       // controller is ready
	.vpa_o(vpa),
	.wr_i(ch7req.we),			// write
	.adr_i(ch7req.padr),	// address
	.dat_i(dato),
	.dat_o(plic_dato),
	.vol_o(),		// volatile register selected
	.i1(1'b0),
	.i2(1'b0),
	.i3(1'b0),
	.i4(io_irq),
	.i5(1'b0),
	.i6(1'b0),
	.i7(1'b0),
	.i8(1'b0),
	.i9(1'b0),
	.i10(1'b0),
	.i11(1'b0),
	.i12(i2c2_irq),
	.i13(1'b0),
	.i14(1'b0),
	.i15(1'b0),
	.i16(acia_irq),
	.i17(1'b0),
	.i18(1'b0),
	.i19(1'b0),
	.i20(1'b0),
	.i21(1'b0),
	.i22(1'b0),
	.i23(1'b0),
	.i24(1'b0),
	.i25(1'b0),
	.i26(1'b0),
	.i27(1'b0),
	.i28(1'b0),
	.i29(tmr_irq),
	.i30(kbd_irq),
	.i31(btnu_db),
	.irqo(plic_irq),	// normally connected to the processor irq
	.nmii(1'b0),		// nmi input connected to nmi requester
	.nmio(),	// normally connected to the nmi of cpu
	.causeo(plic_cause),
	.core_o(plic_core)
);

wire bus_err;
BusError ube1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cyc_i(ch7req.cyc),
	.ack_i(ack),
	.stb_i(ch7req.stb),
	.adr_i(ch7req.padr),
	.err_o(bus_err)
);

reg [6:0] rst_cnt;
reg [15:0] rsts;
reg [15:0] clken_reg;

`ifdef HAS_MMU
rf68000_mmu ummu1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.s_ex_i(1'b0),
	.s_cs_i(cs_mmu),
	.s_cyc_i(cpu_cyc),
	.s_stb_i(cpu_stb),
	.s_ack_o(mmu_ack),
	.s_we_i(cpu_we),
	.s_asid_i(asid),
	.s_adr_i(cpu_adr),
	.s_dat_i(cpu_dato),
	.s_dat_o(mmu_dato),
  .pea_o(ch7req.adr),
  .pdat_o(dato),
  .cyc_o(ch7req.cyc),
  .stb_o(ch7req.stb),
  .we_o(ch7req.we),
  .exv_o(),
  .rdv_o(),
  .wrv_o()
);
`else
assign dato = cpu_dato;
assign ch7req.cyc = cpu_cyc;
assign ch7req.stb = cpu_stb;
assign ch7req.we = cpu_we;
assign ch7req.padr = cpu_adr;
assign mmu_ack = 1'b0;
assign mmu_dato = 'd0;
`endif

rf68000_nic unic1
(
	.id(6'd62),			// system node id
	.rst_i(rst),
	.clk_i(node_clk),
	.s_cti_i(3'd0),
	.s_atag_o(),
	.s_cyc_i(1'b0),
	.s_stb_i(1'b0),
	.s_ack_o(),
	.s_aack_o(),
	.s_rty_o(),
	.s_err_o(),
	.s_vpa_o(),
	.s_we_i(1'b0),
	.s_sel_i(4'h0),
	.s_adr_i(32'h0),
	.s_dat_i(32'h0),
	.s_dat_o(),
	.s_asid_i('d0),
	.s_mmus_i(1'b0),
	.s_ios_i(1'b0),
	.s_iops_i(1'b0),
	.m_cyc_o(cpu_cyc),
	.m_stb_o(cpu_stb),
	.m_ack_i(ack),
	.m_err_i(bus_err),
	.m_vpa_i(vpa),
	.m_we_o(cpu_we),
	.m_sel_o(sel),
	.m_asid_o(asid),
	.m_mmus_o(mmus),
	.m_ios_o(ios),
	.m_iops_o(iops),
	.m_adr_o(cpu_adr),
	.m_dat_o(cpu_dato),
	.m_dat_i(dati),
	.packet_i(packet[3]),//clken_reg[3] ? packet[2] : clken_reg[2] ? packet[1] : packet[0]),
	.packet_o(packet[4]),
	.ipacket_i(ipacket[3]),//clken_reg[3] ? ipacket[2] : clken_reg[2] ? ipacket[1] : ipacket[0]),
	.ipacket_o(ipacket[4]),
	.rpacket_i(rpacket[3]),//clken_reg[3] ? rpacket[2] : clken_reg[2] ? rpacket[1] : rpacket[0]),
	.rpacket_o(rpacket[4]),
	.irq_i(plic_irq[2:0]),
	.firq_i(1'b0),
	.cause_i(plic_cause),
	.iserver_i(plic_core),
	.irq_o(),
	.firq_o(),
	.cause_o()
);

nic_ager uager1
(
	.clk_i(node_clk),
	.packet_i(packet[4]),
	.packet_o(packet[5]),
	.ipacket_i(ipacket[4]),
	.ipacket_o(ipacket[5]), 
	.rpacket_i(rpacket[4]),
	.rpacket_o(rpacket[5])
);

// -----------------------------------------------------------------------------
// Debug
// -----------------------------------------------------------------------------

ila_0 uila1 (
	.clk(mem_ui_clk), // input wire clk

//	.probe0(umpmc1.req_fifoo.req.padr), // input wire [31:0]  probe0  
	.probe0(br1_adr),//umpu1.ucpu1.pc), // input wire [31:0]  probe0  
	.probe1(cs_br3_leds),//umpmc1.req_fifoo.req.cyc), // input wire [0:0]  probe1 
	.probe2(br1_we),//umpmc1.req_fifoo.req.we), // input wire [0:0]  probe2
	.probe3(umpmc1.sel[1:0]),
	.probe4(umpmc1.ufifo1.req_fifoo),
	.probe5(calib_complete),
	.probe6(umpmc1.ufifo1.empty),
	.probe7(umpmc1.rd_data_valid_r),
	.probe8({mem_ui_rst,umpmc1.req}),
	.probe9(mem_rd_data_end),
	.probe10(cs_br1_tc),
	.probe11({br1_sel[3:0],br1_dato[7:0]}),
	.probe12(umpmc1.app_wdf_rdy),
	.probe13(umpmc1.wr_fifo),
	.probe14(umpmc1.app_wdf_wren),
	.probe15(umpmc1.app_rdy),
	.probe16(umpmc1.app_en),
	.probe17(umpmc1.app_cmd),
	.probe18(umpmc1.app_addr),
	.probe19(umpmc1.app_rd_data_valid),
	.probe20(umpmc1.state)
);


/*
ila_0 your_instance_name (
	.clk(clk100), // input wire clk

	.probe0(unode1.ucpu1.ir), // input wire [15:0]  probe0  
	.probe1(cpu_adr), // input wire [31:0]  probe1 
	.probe2(dato), // input wire [31:0]  probe2 
	.probe3({cpu_cyc,cpu_stb,ack,cs_io2,cs_io,ch7req.stb,cpu_we}), // input wire [7:0]  probe3
	.probe4(unode1.ucpu1.pc),
	.probe5({dram_state,unode1.ucpu1.ios_o,ios}),
	.probe6(unode1.ucpu1.state),
	.probe7(mem_wdf_mask),
	.probe8({umpmc1.req_fifoo.stb,umpmc1.req_fifoo.we}),
	.probe9(umpmc1.req_fifoo.sel),
	.probe10(unode1.ucpu1.dfdivo[95:64])
);
*/
assign ch7req.sel = ch7req.we ? sel << {ch7req.padr[3:2],2'b0} : 16'hFFFF;
assign ch7req.dat = {4{dato}};
always_ff @(posedge node_clk)
if (cs_dram)
	dati <= ch7resp.dat >> {ch7req.padr[3:2],5'b0};
else
	dati <= br1_cdato|br3_cdato|sema_dato|scr_dato|plic_dato|io_dato|mmu_dato;
always_ff @(posedge node_clk)
	ack <= ch7resp.ack|br1_cack|br3_cack|sema_ack|scr_ack|plic_ack|io_ack|mmu_ack;

always_ff @(posedge node_clk)
if (rst) begin
	rst_cnt <= 'd0;
	rst_reg <= 16'h0000;
	clken_reg <= 16'h00000006;
end
else begin
	if (cs_br3_rst) begin
		if (|sel[1:0]) begin
			rst_reg <= br3_dato[15:0];
			rst_cnt <= 'd0;
			clken_reg[2] <= clken_reg[2] | |br3_dato[5:4];
			//clken_reg[3] <= clken_reg[3] | |br3_dato[7:6];
		end
		if (|sel[3:2])
			clken_reg[2:0] <= br3_dato[18:16];
	end
	if (~rst_cnt[6])
		rst_cnt <= rst_cnt + 2'd1;
	else
		rst_reg <= 'd0;
end
assign rst_ack = cs_br3_rst;
always_comb
	rsts <= {16{~rst_cnt[6]}} & rst_reg;

assign node_clk1 = node_clk;
`ifdef USE_GATED_CLOCK
BUFGCE uce2 (.CE(clken_reg[2]), .I(node_clk), .O(node_clk2));
BUFGCE uce3 (.CE(clken_reg[3]), .I(node_clk), .O(node_clk3));
`else
assign node_clk2 = node_clk;
assign node_clk3 = node_clk;
`endif
assign node_clk4 = node_clk;

rf68000_node #(.SUPPORT_DECFLT(1'b1)) unode1
(
	.id(5'd1),
	.rst1(rst),
	.rst2(rst|rsts[3]),
	.clk(node_clk1),
	.packet_i(packet[5]),
	.packet_o(packet[0]),
	.rpacket_i(rpacket[5]),
	.rpacket_o(rpacket[0]),
	.ipacket_i(ipacket[5]),
	.ipacket_o(ipacket[0])
);


rf68000_node #(.SUPPORT_DECFLT(1'b0)) unode2
(
	.id(5'd2),
	.rst1(rst|rsts[4]),
	.rst2(rst|rsts[5]),
	.clk(node_clk2),
	.packet_i(packet[0]),
	.packet_o(packet[1]),
	.rpacket_i(rpacket[0]),
	.rpacket_o(rpacket[1]),
	.ipacket_i(ipacket[0]),
	.ipacket_o(ipacket[1])
);


rf68000_node #(.SUPPORT_DECFLT(1'b0)) unode3
(
	.id(5'd3),
	.rst1(rst|rsts[6]),
	.rst2(rst|rsts[7]),
	.clk(node_clk3),
	.packet_i(packet[1]),//clken_reg[2] ? packet[1] : packet[0]),
	.packet_o(packet[2]),
	.rpacket_i(rpacket[1]),//clken_reg[2] ? rpacket[1] : rpacket[0]),
	.rpacket_o(rpacket[2]),
	.ipacket_i(ipacket[1]),//clken_reg[2] ? ipacket[1] : ipacket[0]),
	.ipacket_o(ipacket[2])
);


rf68000_node #(.SUPPORT_DECFLT(1'b0)) unode4
(
	.id(5'd4),
	.rst1(rst|rsts[8]),
	.rst2(rst|rsts[9]),
	.clk(node_clk4),
	.packet_i(packet[2]),
	.packet_o(packet[3]),
	.rpacket_i(rpacket[2]),
	.rpacket_o(rpacket[3]),
	.ipacket_i(ipacket[2]),
	.ipacket_o(ipacket[3])
);


endmodule
