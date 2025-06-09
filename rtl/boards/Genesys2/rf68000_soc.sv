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
import fta_bus_pkg::*;
import video_pkg::*;
import nic_pkg::*;

//`define USE_GATED_CLOCK	1'b1
//`define HAS_MMU 1'b1

module rf68000_soc(cpu_reset_n, sysclk_p, sysclk_n, led, sw, btnl, btnr, btnc, btnd, btnu, 
  ps2_clk_0, ps2_data_0, uart_rx_out, uart_tx_in,
  hdmi_tx_clk_p, hdmi_tx_clk_n, hdmi_tx_p, hdmi_tx_n,
//  ac_mclk, ac_adc_sdata, ac_dac_sdata, ac_bclk, ac_lrclk,
  rtc_clk, rtc_data,
  sd_ss, sd_mosi, sd_miso, sd_sck,
	aud_adc_sdata, aud_adr, aud_bclk, aud_dac_sdata, aud_lrclk, aud_mclk, aud_scl, aud_sda,
  spiClkOut, spiDataIn, spiDataOut, spiCS_n, spiReset, sd_cd,
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
parameter WXGA1920x1080 = 1'b1;
parameter HAS_CPU = 1'b1;
parameter HAS_FRAME_BUFFER = 1'b1;
parameter HAS_TEXTCTRL = 1'b1;
parameter HAS_PRNG = 1'b1;
parameter HAS_UART = 1'b1;
parameter HAS_PS2KBD = 1'b1;
parameter SIM = 1'b0;
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

inout tri rtc_clk;
inout tri rtc_data;

output sd_sck;
input sd_miso;
output sd_mosi;
output sd_ss;

input aud_adc_sdata;
output [1:0] aud_adr;
output aud_bclk;
output aud_dac_sdata;
output aud_lrclk;
output aud_mclk;
inout tri aud_scl;
inout tri aud_sda;

output spiClkOut;
input spiDataIn;
output spiDataOut;
output spiCS_n;
output spiReset;
input sd_cd;

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
wire locked,locked2;
wire clk10, clk12;
wire clk20, clk40, clk50, clk100, clk70, clk140, clk200, clk700;
wire clk17, clk33;
wire mem_ui_clk;
wire mem_ui_rst;
wire xclk_bufg;
wire node_clk = clk50;
wire dfclk = clk20;
wire node_clk1;
wire node_clk2;
wire node_clk3;
wire node_clk4;
wire dot_clk = clk40;
wb_cmd_request256_t ch7req;
wb_cmd_request256_t ch7dreq;	// DRAM request
wb_cmd_response256_t ch7resp;
wire cpu_cyc;
wire cpu_stb;
wire cpu_we;
wire [2:0] cpu_fc;
wire [31:0] cpu_adr;
wire [31:0] cpu_dato;
reg ack;
reg [2:0] err;
wire vpa;
wire [3:0] sel;
reg [31:0] dati;
wire [31:0] dato;
wire [2:0] dram_err;
wire mmus, ios, iops;
wire mmu_ack;
wire [31:0] mmu_dato;
wire br1_cyc;
wire br1_stb;
reg br1_ack;
reg br1_stall;
wire br1_we;
wire [3:0] br1_sel;
wire [31:0] br1_adr;
wire [31:0] br1_cdato;
reg [31:0] br1_dati;
wire [5:0] br1_coreo;
wire [5:0] br1_ccoreo;
reg [5:0] br1_corei;
wire [31:0] br1_dato;
wire br1_cack;
wire br3_cyc;
wire br3_stb;
reg br3_ack;
wire br3_we;
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

wire [31:0] psg_dato;
wire psg_ack;
wire psgm_cyc;
wire psgm_stb;
wire psgm_ack;
wire psgm_we;
wire [31:0] psgm_sel;
wire [31:0] psgm_adr;
wire [255:0] psgm_dati;
wire [255:0] psgm_dato;

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
wire i2c1_ack;
wire [7:0] i2c1_dato;
wire i2c2_ack;
wire [7:0] i2c2_dato;
wire i2c2_irq;
wire [7:0] spi_dato;
wire spi_ack;
wire spi2_ack;
wire [7:0] spi2_dato;
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
wire dram_ack;
wire [255:0] dram_dato;
wire [7:0] mpmc_fifo_rst;

wire leds_ack;
reg [7:0] rst_reg;
wire rst_ack;

wire hSync, vSync;
wire blank, border;
wire [7:0] red, blue, green;
wire [31:0] fb_rgb, tc_rgb;
assign red = tc_rgb[29:22];
assign green = tc_rgb[19:12];
assign blue = tc_rgb[9:2];

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
  .clk200(clk200),	// 200 MHz	ddr3 interface clock
  .clk100(clk100),
  .clk50(clk50),
  .clk40(clk40),					// 40.000 MHz video / cpu clock
  .clk20(clk20),					// cpu
  .clk17(clk12),		// audio
//  .clk33(clk33),
//  .clk10(clk10),
//  .clk14(clk14),		// 16x baud clock
  // Status and control signals
  .reset(xrst), 
  .locked(locked),       // output locked
 // Clock in ports
  .clk_in1_p(sysclk_p),
  .clk_in1_n(sysclk_n)
);

WXGA1920x1080_clkgen ucg2
(
  // Clock out ports
  .clk742(clk700),	// 742.5 MHz	dvi clock
  .clk148(clk140),	// 148.5 MHz	dot clock
  .clk50(),
  .clk20(),		// cpu
  // Status and control signals
  .reset(xrst), 
  .locked(locked2),       // output locked
 // Clock in ports
  .clk_in1(clk200)
);

assign rst = !(locked|locked2);

rgb2dvi ur2d1
(
	.rst(rst),
	.PixelClk(clk40),
	.SerialClk(clk200),
	.red(red[7:0]),
	.green(green[7:0]),
	.blue(blue[7:0]),
	.de(~blank),
	.hSync(hSync),	// ~ for 640x480 100 Hz, -,- for 1920x1080
	.vSync(vSync),	// +,+ for 800x600
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

wire cs_tc = (cpu_adr[31:16]==16'hFD00 || cpu_adr[31:16]==16'hFD01 ||
							cpu_adr[31:16]==16'hFD02 || cpu_adr[31:16]==16'hFD03 ||
							cpu_adr[31:16]==16'hFD04 || cpu_adr[31:16]==16'hFD08
							) && ch7req.stb && cs_io2;
wire cs_br1_tc = (br1_adr[31:16]==16'hFD00 || br1_adr[31:16]==16'hFD01 ||
									br1_adr[31:16]==16'hFD02 || br1_adr[31:16]==16'hFD03 ||
									br1_adr[31:16]==16'hFD04 || br1_adr[31:16]==16'hFD08
									) && br1_stb && cs_io2;
wire cs_fb = cpu_adr[31:16]==16'hFE40 && ch7req.stb && cs_io2;
wire cs_br1_fb = br1_adr[31:16]==16'hFE40 && br1_stb && cs_io2;
wire cs_leds = cpu_adr[31:8]==24'hFD0FFF && ch7req.stb && cs_io2;
wire cs_br3_leds = br3_adr[31:8]==24'hFD0FFF && br3_stb && cs_io2;
wire cs_br3_rst  = br3_adr[31:8]==24'hFD0FFC && br3_stb && cs_io2;
wire cs_kbd  = cpu_adr[31:8]==24'hFD0FFE && cpu_stb && cs_io2;
wire cs_br3_kbd  = br3_adr[31:8]==24'hFD0FFE && br3_stb && cs_io2;
wire cs_rand  = cpu_adr[31:8]==24'hFD0FFD && ch7req.stb && cs_io2;
wire cs_br3_rand  = br3_adr[31:8]==24'hFD0FFD && br3_stb && cs_io2;
wire cs_sema = cpu_adr[31:16]==16'hFD05 && ch7req.stb && cs_io2;
wire cs_acia = cpu_adr[31:12]==20'hFD060 && ch7req.stb && cs_io2;
wire cs_br3_acia = br3_adr[31:12]==20'hFD060 && br3_stb && cs_io2;
wire cs_br1_i2c1 = br1_adr[31:4]==28'hFD06900 && br1_stb && cs_io2;
wire cs_br3_i2c2 = br3_adr[31:4]==28'hFD06901 && br3_stb && cs_io2;
wire cs_br1_1761 = br1_adr[31:4]==28'hFD06980 && br1_stb && cs_io2;
wire cs_br1_psg = br1_adr[31:12]==20'hFD06B && br1_stb && cs_io2;
wire cs_br3_spi = br3_adr[31:8]==24'hFD06A0 && br3_stb && cs_io2;
wire cs_br3_spi2 = br3_adr[31:8]==24'hFD06A1 && br3_stb && cs_io2;
wire cs_scr = cpu_adr[31:20]==12'h001 && cpu_stb;
wire cs_plic = cpu_adr[31:12]==20'hFD090 && cs_io2;
wire cs_br3_plic = br3_adr[31:12]==20'hFD090 && cs_io2;
wire cs_dram = (cpu_adr[31:30]==2'b01 || cpu_adr[31:30]==2'b10) && cpu_cyc && !cs_mmu && !cs_iobitmap && !cs_io;
wire cs_gfx = br1_adr[31:16]==16'hFD30 && br1_stb;

fta_bus_interface #(.DATA_WIDTH(256)) gfx_if();
fta_bus_interface #(.DATA_WIDTH(256)) fbm_if();
fta_bus_interface #(.DATA_WIDTH(256)) cpu_if();
fta_bus_interface #(.DATA_WIDTH(256)) ch1_if();
fta_bus_interface #(.DATA_WIDTH(256)) ch2_if();
fta_bus_interface #(.DATA_WIDTH(256)) psgm_if();
fta_bus_interface #(.DATA_WIDTH(256)) ch4_if();
fta_bus_interface #(.DATA_WIDTH(256)) ch5_if();
fta_bus_interface #(.DATA_WIDTH(256)) ch6_if();
fta_bus_interface #(.DATA_WIDTH(32)) fbs_if();
fta_bus_interface #(.DATA_WIDTH(32)) br1_fta();
fta_bus_interface #(.DATA_WIDTH(32)) br3_fta();
video_bus fb_video_i();
video_bus fb_video_o();

assign fbm_if.rst = mem_ui_rst;
assign fbm_if.clk = clk100;//fbm_clk;

assign fbs_if.rst = rst;
assign fbs_if.clk = node_clk;
assign fbs_if.req = br1_fta.req;
assign br1_fta.resp = fbs_if.resp;

assign fb_video_i.clk = dot_clk;
assign fb_video_i.hsync = hSync;
assign fb_video_i.vsync = vSync;
assign fb_video_i.blank = blank;
assign fb_video_i.border = border;
assign fb_video_i.data = 32'd0;

assign vSync = fb_video_o.vsync;
assign hSync = fb_video_o.hsync;
assign blank = fb_video_o.blank;
assign border = fb_video_o.border;

assign mpmc_fifo_rst[7:1] = 7'h00;

wire [31:0] fb_irq;

rfFrameBuffer_fta64 #(
	.BUSWID(32),
	.INTERNAL_SYNCGEN(1'b1),
	.FBC_ADDR(32'hFD200001)
) 
uframebuf1
(
	.rst_i(rst),
	.xonoff_i(sw[0]),
	.irq_o(fb_irq),
	.cs_config_i(br1_fta.req.adr[31:28]==4'hD),
	.s_bus_i(fbs_if),
	.m_bus_o(fbm_if),
	.m_fst_o(), 
	.m_rst_busy_i(mpmc_rst_busy),
	.fifo_rst_o(mpmc_fifo_rst[0]),
	.xal_o(),
	.video_i(fb_video_i),
	.video_o(fb_video_o),
	.vblank_o()
);

wb_cmd_request32_t gfxs_req;
wb_cmd_response32_t gfxs_resp;
wb_cmd_request256_t gfxm_req;
wb_cmd_response256_t gfxm_resp;

always_comb
begin
	gfxs_req = {$bits(wb_cmd_request32_t){1'b0}};
	gfxs_req.cyc = br1_cyc;
	gfxs_req.stb = br1_stb;
	gfxs_req.sel = br1_sel;
	gfxs_req.we = br1_we;
	gfxs_req.padr = br1_adr;
	gfxs_req.dat = br1_dato;
end

gfx_top ugfx1
(
	.wb_clk_i(clk100),
	.wb_rst_i(rst),
	.wb_inta_o(),
  // Wishbone master signals (interfaces with video memory, write)
  .wbm_req(gfxm_req),
  .wbm_resp(gfxm_resp),
  // Wishbone slave signals (interfaces with main bus/CPU)
  .wbs_clk_i(node_clk),
	.wbs_cs_i(cs_gfx),
  .wbs_req(gfxs_req),
  .wbs_resp(gfxs_resp)
);

assign gfx_if.clk = clk100;
assign gfx_if.rst = rst;

wb_to_fta_bridge uwb2fta2
(
	.rst_i(rst),
	.clk_i(clk100),
	.cs_i(1'b1),
	.cyc_i(gfxm_req.cyc),
	.stb_i(gfxm_req.stb),
	.ack_o(gfxm_resp.ack),
	.err_o(),
	.we_i(gfxm_req.we),
	.sel_i(gfxm_req.sel),
	.adr_i(gfxm_req.padr),
	.dat_i(gfxm_req.dat),
	.dat_o(gfxm_resp.dat),
	.fta_o(gfx_if)
);


/*
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
*/

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
	.dot_clk_i(dot_clk),
	.hsync_i(hSync),
	.vsync_i(vSync),
	.blank_i(blank),
	.border_i(border),
	.zrgb_i({2'b0,fb_video_o.data[29:0]}),
	.zrgb_o(tc_rgb),
	.xonoff_i(sw[1])
);

AVBridge ubridge1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.vclk_i(dot_clk),
	.hsync_i(hSync),
	.vsync_i(vSync),
	.gfx_que_empty_i(1'b1),
	.fta_en_i(1'b1),
	.io_gate_en_i(io_gate_en),
	.s1_cyc_i(cpu_cyc),
	.s1_stb_i(cpu_stb),
	.s1_ack_o(br1_cack),
	.s1_we_i(cpu_we),
	.s1_sel_i(sel),
	.s1_adr_i(cpu_adr),
	.s1_dat_i(dato),
	.s1_dat_o(br1_cdato),
	.m_cyc_o(br1_cyc),
	.m_stb_o(br1_stb),
	.m_ack_i(br1_ack),
	.m_stall_i(br1_stall),
	.m_we_o(br1_we),
	.m_sel_o(br1_sel),
	.m_adr_o(br1_adr),
	.m_dat_i(br1_dati),
	.m_dat_o(br1_dato),
	.m_fta_o(br1_fta)
);

wire [15:0] audi;
wire [15:0] audo [0:3];

PSG32 #(.MDW(256)) upsg1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.clk100_i(clk100),
	.cs_i(cs_br1_psg), 
	.cyc_i(br1_cyc),
	.stb_i(br1_stb),
	.ack_o(psg_ack),
	.rdy_o(),
	.we_i(br1_we),
	.adr_i(br1_adr[8:0]),
	.dat_i(br1_dato),
	.dat_o(psg_dato),
	.m_cyc_o(psgm_cyc),
	.m_stb_o(psgm_stb),
	.m_ack_i(psgm_ack_i),
	.m_we_o(psgm_we),
	.m_sel_o(psgm_sel),
	.m_adr_o(psgm_adr),
	.m_dat_i(psgm_dat_i),
	.m_dat_o(psgm_dat_o),
	.aud_i(audi),
	.aud_o(audo)
);

wire aud_dac_sdata1;
wire aud_bclk1;
wire aud_lrclk1;
wire en_rxtx;
wire en_tx;
ADAU1761_Interface uai1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_i(cs_br1_1761),
	.cyc_i(br1_cyc),
	.stb_i(br1_stb),
	.ack_o(ack_1761),
	.we_i(br1_we),
	.dat_i(br1_dato[7:0]),
	.aud0_i(audo[0]),
	.aud2_i(audo[2]),
	.audi_o(audi),
	.ac_mclk_i(aud_mclk),
	.ac_bclk_o(aud_bclk1),
	.ac_lrclk_o(aud_lrclk1),
	.ac_adc_sdata_i(aud_adc_sdata),
	.ac_dac_sdata_o(aud_dac_sdata1),
	.en_rxtx_o(en_rxtx),
	.en_tx_o(en_tx),
	.record_i(btnl_db),
	.playback_i(btnr_db)
);
assign aud_mclk = clk12;
assign aud_bclk = en_rxtx ? aud_bclk1 : 1'bz;
assign aud_lrclk = en_rxtx ? aud_lrclk1 : 1'bz;
assign aud_dac_sdata = en_tx ? aud_dac_sdata1 : 1'b0;
assign aud_adr = 2'b11;

assign psgm_if.rst = mem_ui_rst;
assign psgm_if.clk = clk100;

wb_to_fta_bridge uwb2fta3
(
	.rst_i(rst),
	.clk_i(clk100),
	.cs_i(1'b1),
	.cyc_i(psgm_cyc),
	.stb_i(psgm_stb),
	.ack_o(psgm_ack),
	.err_o(),
	.we_i(psgm_we),
	.sel_i(psgm_sel),
	.adr_i(psgm_adr),
	.dat_i(psgm_dato),
	.dat_o(psgm_dati),
	.fta_o(psgm_if)
);

wire scl, sda;
wire scl_padoen_o,sda_padoen_o;

i2c_master_top #(
	.ARST_LVL(1'b1),
	.ZERO_DATA(1'b1),
	.TIMING_HONORED(1'b0)
) ui2c1 
(
	.wb_clk_i(node_clk),
	.wb_rst_i(rst),
	.arst_i(rst),
	.wb_adr_i(br1_adr[2:0]),
	.wb_dat_i(br1_dato[7:0]),
	.wb_dat_o(i2c1_dato),
	.wb_we_i(br1_we),
	.wb_stb_i(br1_stb & cs_br1_i2c1),
	.wb_cyc_i(br1_cyc & cs_br1_i2c1),
	.wb_ack_o(i2c1_ack),
	.wb_inta_o(),
	.scl_pad_i(aud_scl),
	.scl_pad_o(scl),
	.scl_padoen_o(scl_padoen_o),
	.sda_pad_i(aud_sda),
	.sda_pad_o(sda),
	.sda_padoen_o(sda_padoen_o)
);

assign aud_scl = scl_padoen_o ? 1'bz : scl;
assign aud_sda = sda_padoen_o ? 1'bz : sda;


assign br1_fta.rst = rst;
assign br1_fta.clk = clk100;

always_ff @(posedge clk100)
	br1_dati <= tc_dato|gfxs_resp.dat|{4{i2c1_dato}};

always_ff @(posedge clk100)
	br1_ack <= tc_ack|gfxs_resp.ack|i2c1_ack|ack_1761;

always_ff @(posedge clk100)
	br1_stall <= gfxs_resp.stall;

wire kclk_en, kdat_en;
PS2kbd #(.pClkFreq(100000000)) ukbd1
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

assign ps2_clk_0 = kclk_en ? 1'b0 : 1'bz;
assign ps2_data_0 = kdat_en ? 1'b0 : 1'bz;

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

i2c_master_top ui2cm2
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
assign rtc_clk = rtc_clkoen ? 1'bz : rtc_clko;
assign rtc_data = rtc_dataoen ? 1'bz : rtc_datao;
/*
assign i2c2_dato = 8'd0;
assign i2c2_ack = 1'b0;
*/
IOBridge ubridge3
(
	.rst_i(rst),
	.clk_i(node_clk),
	.fta_en_i(1'b0),
	.io_gate_en_i(io_gate_en),
	.s1_cyc_i(cpu_cyc),
	.s1_stb_i(cpu_stb),
	.s1_ack_o(br3_cack),
	.s1_we_i(cpu_we),
	.s1_sel_i(sel),
	.s1_adr_i(cpu_adr),
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
	.m_stall_i(1'b0),
	.m_we_o(br3_we),
	.m_sel_o(br3_sel),
	.m_adr_o(br3_adr),
	.m_dat_i(br3_dati),
	.m_dat_o(br3_dato),
	.m_fta_o(br3_fta)
);

assign br3_fta.rst = rst;
assign br3_fta.clk = node_clk;
assign br3_fta.resp.ack = 1'b0;
assign br3_fta.resp.dat = 32'd0;

always_ff @(posedge clk100)
	casez(cs_br3_leds)
	1'b1:	br3_dati <= led;
	1'b0:	br3_dati <= {4{kbd_dato}}|rand_dato|acia_dato|{4{i2c2_dato}}|{4{spi_dato}}|{4{spi2_dato}};
	endcase

always_ff @(posedge clk100)
	br3_ack <= leds_ack|kbd_ack|rand_ack|acia_ack|i2c2_ack|rst_ack|spi_ack|spi2_ack;

assign leds_ack = cs_br3_leds;
always_ff @(posedge clk100)
	if (cs_br3_leds & br3_we)
		led <= br3_dato[7:0];

spiMaster uspi1 (
  .clk_i(node_clk),
  .rst_i(rst),
  .address_i(br3_adr[7:0]),
  .data_i(br3_dato[7:0]),
  .data_o(spi_dato),
  .strobe_i(br3_cyc && cs_br3_spi),
  .we_i(br3_we),
  .ack_o(spi_ack),

  // SPI logic clock
  .spiSysClk(clk50),

  //SPI bus
  .cardDetect(sd_cd),
  .spiReset(spiReset),
  .spiClkOut(spiClkOut),
  .spiDataIn(spiDataIn),
  .spiDataOut(spiDataOut),
  .spiCS_n(spiCS_n)
);

spiMaster uspi2 (
  .clk_i(node_clk),
  .rst_i(rst),
  .address_i(br3_adr[7:0]),
  .data_i(br3_dato[7:0]),
  .data_o(spi2_dato),
  .strobe_i(br3_cyc && cs_br3_spi2),
  .we_i(br3_we),
  .ack_o(spi2_ack),

  // SPI logic clock
  .spiSysClk(clk50),

  //SPI bus
  .cardDetect(1'b0),
  .spiReset(),
  .spiClkOut(sd_sck),
  .spiDataIn(sd_miso),
  .spiDataOut(sd_mosi),
  .spiCS_n(sd_ss)
);

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
//assign app_ref_req = 1'b0;

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
	.sys_rst(rstn & ~btnc_db),
	// user interface signals
	.app_addr({1'b0,mem_addr[29:2]}),
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
	.app_ref_req(1'b0),
	.app_ref_ack(app_ref_ack),
	.app_zq_req(1'b0),
	.app_zq_ack(),
	.ui_clk(mem_ui_clk),
	.ui_clk_sync_rst(mem_ui_rst),
	.init_calib_complete(calib_complete),
	.device_temp(ddr3_temp)
);

assign cpu_if.rst = rst;
assign cpu_if.clk = node_clk;
assign ch1_if.rst = 1'b1;
assign ch2_if.rst = 1'b1;
assign ch4_if.rst = 1'b1;
assign ch5_if.rst = 1'b1;
assign ch6_if.rst = rst;
assign ch1_if.clk = node_clk;
assign ch2_if.clk = 1'b0;
assign ch4_if.clk = 1'b0;
assign ch5_if.clk = 1'b0;
assign ch6_if.clk = 1'b0;
assign ch1_if.req = {$bits(fta_cmd_request256_t){1'b0}};
assign ch2_if.req = {$bits(fta_cmd_request256_t){1'b0}};
assign ch4_if.req = {$bits(fta_cmd_request256_t){1'b0}};
assign ch5_if.req = {$bits(fta_cmd_request256_t){1'b0}};
assign ch6_if.req = {$bits(fta_cmd_request256_t){1'b0}};


mpmc11_fta
#(
	.PORT_PRESENT(9'h199),
	.STREAM(8'h21),
	.CACHE(8'h46)
)
umpmc1
(
	.rst(rst),
	.sys_clk_i(clk100),//sysclk_p),
	.mem_ui_rst(mem_ui_rst),
	.mem_ui_clk(mem_ui_clk),
	.calib_complete(calib_complete || SIM),
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
	.app_ref_req(app_ref_req),
	.app_ref_ack(app_ref_ack),
	.ch0(fbm_if),
	.ch1(ch1_if),
	.ch2(ch2_if),
	.ch3(psgm_if),
	.ch4(gfx_if),
	.ch5(ch5_if),
	.ch6(ch6_if),
	.ch7(cpu_if),
	.fifo_rst(mpmc11_fifo_rst),
	.state(dram_state),
	.rst_busy(mpmc_rst_busy)
);

wb_to_fta_bridge uwb2fta1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_i(cs_dram),
	.cyc_i(cpu_cyc),
	.stb_i(cpu_stb),
	.ack_o(dram_ack),
	.err_o(dram_err),
	.we_i(cpu_we),
	.sel_i({28'h0,sel} << {cpu_adr[4:2],2'b00}),
	.adr_i(cpu_adr),
	.dat_i({8{cpu_dato}}),
	.dat_o(dram_dato),
	.fta_o(cpu_if)
);

/*
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
*/

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
	.adr_i(ch7req.padr[31:0]),
	.dat_i(dato),
	.dat_o(scr_dato)
);

io_bitmap uiob1
(
	.clk_i(node_clk),
	.cs_i(cs_iobitmap),
	.cyc_i(cpu_cyc),
	.stb_i(cpu_stb),
	.ack_o(io_ack),
	.we_i(cpu_we),
	.ioas_i(asid),
	.adr_i(cpu_adr[23:0]),
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
	.fc_i(cpu_fc),
	.cyc_i(cpu_cyc),
	.stb_i(cpu_stb),
	.ack_o(plic_ack),       // controller is ready
	.vpa_o(vpa),
	.wr_i(cpu_we),			// write
	.adr_i(cpu_adr),	// address
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
	.cyc_i(cpu_cyc && !cs_dram),
	.ack_i(ack),
	.stb_i(cpu_stb),
	.adr_i(cpu_adr),
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
assign ch7req.cmd = cpu_we ? wishbone_pkg::CMD_STORE : wishbone_pkg::CMD_LOAD;
assign mmu_ack = 1'b0;
assign mmu_dato = 32'd0;
`endif
always_comb
begin
	ch7req.cid = 4'd7;
	ch7dreq = ch7req;
	ch7dreq.cid = 4'd7;
	ch7dreq.cyc = ch7req.cyc & cs_dram;
	ch7dreq.stb = ch7req.stb & cs_dram;
end
assign ch7req.sel = ch7req.we ? {28'h0,sel} << {ch7req.padr[4:2],2'b0} : 32'hFFFFFFFF;
assign ch7req.dat = {8{dato}};

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
	.s_fc_i(3'd0),
	.s_adr_i(32'h0),
	.s_dat_i(32'h0),
	.s_dat_o(),
	.s_asid_i(8'd0),
	.s_mmus_i(1'b0),
	.s_ios_i(1'b0),
	.s_iops_i(1'b0),
	.m_cyc_o(cpu_cyc),
	.m_stb_o(cpu_stb),
	.m_ack_i(ack),
	.m_err_i(cs_dram?(dram_err!=fta_bus_pkg::OKAY):bus_err),
	.m_vpa_i(vpa),
	.m_we_o(cpu_we),
	.m_sel_o(sel),
	.m_asid_o(asid),
	.m_mmus_o(mmus),
	.m_ios_o(ios),
	.m_iops_o(iops),
	.m_fc_o(cpu_fc),
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
	.probe0(ugfx1.render_wbmwriter_addr),//umpu1.ucpu1.pc), // input wire [31:0]  probe0  
	.probe1(unode1.cyc1),//umpmc1.req_fifoo.req.cyc), // input wire [0:0]  probe1 
	.probe2(unode1.ack1),//umpmc1.req_fifoo.req.we), // input wire [0:0]  probe2
	.probe3(unode1.we1),
	.probe4(cs_gfx),
	.probe5(cs_br3_kbd),
	.probe6(kbd_ack),
	.probe7(kbd_irq),
	.probe8(unode1.dati1),
	.probe9(mem_rd_data_valid),
	.probe10(cs_dram),
//	.probe11({unode1.ram1_we[3:0],cpu_if.req.cmd}),
	.probe11({
		spiDataOut,
		spiDataIn,
		spiClkOut,
		spiCS_n,
		spiReset,
		rtc_clk,
		rtc_data,
		ugfx1.wbmreader_arbiter_ack,
		ugfx1.raster_clip_write,
		ugfx1.clip_wbmreader_z_request,
		ugfx1.fragment_wbmreader_texture_request,
		ugfx1.blender_wbmreader_target_request,
		ugfx1.render_wbmwriter_memory_pixel_read,
		ugfx1.render_wbmwriter_memory_pixel_write,
		ugfx1.textblit_read_request,
		ugfx1.clip_ack,
		ugfx1.fragment_clip_ack,
		ugfx1.wbmwriter_render_ack,
		ugfx1.blender_fragment_ack,
		ugfx1.render_blender_ack,
		ugfx1.transform_wbs_ack,
		ugfx1.raster_wbs_ack
	}),
	.probe12(umpmc1.app_wdf_rdy),
	.probe13(unode1.we1),
	.probe14(umpmc1.app_wdf_wren),
	.probe15(umpmc1.app_rdy),
	.probe16(umpmc1.app_en),
	.probe17({ugfx1.rasterizer0.clip_ack_i,ugfx1.rasterizer0.clip_write_o,ugfx1.rasterizer0.raster_state}),
	.probe18(unode1.dato1),
	.probe19(1'b0),
	.probe20(ugfx1.clip.clip_state),//uframebuf1.state)
	.probe21(umpmc1.req_fifoo.port)
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
always_ff @(posedge clk100)
if (cs_dram)
	dati <= dram_dato >> {cpu_adr[4:2],5'b0};
else
	dati <= br1_cdato|br3_cdato|sema_dato|scr_dato|plic_dato|io_dato|mmu_dato;
always_ff @(posedge clk100)
	ack <= dram_ack|br1_cack|br3_cack|sema_ack|scr_ack|plic_ack|io_ack|mmu_ack;

always_ff @(posedge clk100)
if (rst) begin
	rst_cnt <= 7'd0;
	rst_reg <= 16'h0000;
	clken_reg <= 16'h00000006;
end
else begin
	if (cs_br3_rst) begin
		if (|sel[1:0]) begin
			rst_reg <= br3_dato[15:0];
			rst_cnt <= 7'd0;
			clken_reg[2] <= clken_reg[2] | |br3_dato[5:4];
			//clken_reg[3] <= clken_reg[3] | |br3_dato[7:6];
		end
		if (|sel[3:2])
			clken_reg[2:0] <= br3_dato[18:16];
	end
	if (~rst_cnt[6])
		rst_cnt <= rst_cnt + 2'd1;
	else
		rst_reg <= 16'd0;
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
	.rst1(rst|rsts[2]),
	.rst2(rst|rsts[3]),
	.nic_rst(rst),
	.clk(node_clk1),
	.dfclk(dfclk),
	.packet_i(packet[5]),
	.packet_o(packet[3]),		// was 0
	.rpacket_i(rpacket[5]),
	.rpacket_o(rpacket[3]),
	.ipacket_i(ipacket[5]),
	.ipacket_o(ipacket[3])
);

/*
rf68000_node #(.SUPPORT_DECFLT(1'b1)) unode2
(
	.id(5'd2),
	.rst1(rst|rsts[4]),
	.rst2(rst|rsts[5]),
	.nic_rst(rst),
	.clk(node_clk2),
	.dfclk(dfclk),
	.packet_i(packet[0]),
	.packet_o(packet[3]),
	.rpacket_i(rpacket[0]),
	.rpacket_o(rpacket[3]),
	.ipacket_i(ipacket[0]),
	.ipacket_o(ipacket[3])
);
*/
/*
rf68000_node #(.SUPPORT_DECFLT(1'b0)) unode3
(
	.id(5'd3),
	.rst1(rst|rsts[6]),
	.rst2(rst|rsts[7]),
	.nic_rst(rst),
	.clk(node_clk3),
	.dfclk(dfclk),
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
	.nic_rst(rst),
	.clk(node_clk4),
	.dfclk(dfclk),
	.packet_i(packet[2]),
	.packet_o(packet[3]),
	.rpacket_i(rpacket[2]),
	.rpacket_o(rpacket[3]),
	.ipacket_i(ipacket[2]),
	.ipacket_o(ipacket[3])
);
*/

endmodule
