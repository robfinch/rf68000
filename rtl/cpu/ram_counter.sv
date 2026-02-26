//	000 count bits 0 to 31
//	004 count bits 32 to 47
//	008 max count bits 0 to 31
//	00C max count bits 32 to 47
//  010 on time bits 0 to 31
//  014 on time bits 32 to 47
//	018	control
//		bit in byte
//		0 = 1 = load, automatically clears
//	  1 = 1 = enable counting, 0 = disable counting
//		2 = 1 = auto-reload on terminal count, 0 = no reload
//		3 = 1 = use external clock, 0 = internal clk_i
//    4 = 1 = use gate to enable count, 0 = ignore gate
//		7 = 1 = set registers immediately, 0 = wait for sync
//		8 to 15 = vector number
//		16 to 31 = mailbox handle
//	01C not used, reserved

module ram_counter(rst_i, clk_i, iack_i, cs_i, we_i, adr_i, dat_i, dat_o, irq_o,
	clk0, clk1, clk2, clk3, gate0, gate1, gate2, gate3, out0, out1, out2, out3);
input rst_i;
input clk_i;
input iack_i;
input cs_i;
input we_i;
input [13:0] adr_i;
input [31:0] dat_i;
output reg [31:0] dat_o;
output reg irq_o;
input clk0;
input clk1;
input clk2;
input clk3;
input gate0;
input gate1;
input gate2;
input gate3;
output reg out0;
output reg out1;
output reg out2;
output reg out3;
parameter NTIMER = 200;

integer n1;

reg [NTIMER-1:0] ie;
reg [NTIMER-1:0] irqf;
reg [NTIMER-1:0] ld,ldh;
reg [NTIMER-1:0] ce,ceh;
reg [NTIMER-1:0] ar,arh;
reg [NTIMER-1:0] ge,geh;
reg [NTIMER-1:0] xc,xch;
reg [NTIMER-1:0] oti,otih;
reg [NTIMER-1:0] underflow;
reg [NTIMER-1:0] gate;
reg [NTIMER-1:0] pulse;
reg [47:0] maxcounth [0:NTIMER-1];
reg [47:0] ontimeh [0:NTIMER-1];
reg [47:0] count [0:NTIMER-1];
reg [47:0] counth [0:NTIMER-1];
reg [47:0] maxcount [0:NTIMER-1];
reg [47:0] ontime [0:NTIMER-1];
reg [15:0] mailbox [0:NTIMER-1];
reg [7:0] vector [0:NTIMER-1];
reg [NTIMER-1:0] out;
reg [7:0] cntr;
reg [7:0] irqn;

always_ff @(posedge clk_i)
if (rst_i)
	cntr <= 8'd0;
else begin
	if (cntr==NTIMER-1)
		cntr <= 8'd0;
	else
		cntr <= cntr + 8'd1;
end

always_comb
begin
	irqn = 8'd0;
	for (n1 = NTIMER-1; n1 >= 0; n1 = n1 - 1)
		if (irqf[n1]) begin
			irqn = n1;
			break;
		end
end

edge_det ued0 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk0), .pe(pulse[0]), .ne(), .ee());
edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk1), .pe(pulse[1]), .ne(), .ee());
edge_det ued2 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk2), .pe(pulse[2]), .ne(), .ee());
edge_det ued3 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk3), .pe(pulse[3]), .ne(), .ee());

always_comb
begin
	gate[0] = gate0;
	gate[1] = gate1;
	gate[2] = gate2;
	gate[3] = gate3;
end

always_comb
begin
	out0 = out[0];
	out1 = out[1];
	out2 = out[2];
	out3 = out[3];
end

always_ff @(posedge clk_i)
if (rst_i) begin
	ld <= {NTIMER{1'b0}};
	underflow <= {NTIMER{1'b0}};
	ce <= {NTIMER{1'b0}};
	ge <= {NTIMER{1'b0}};
	irqf <= {NTIMER{1'b0}};
	ie <= {NTIMER{1'b0}};
	gate[NTIMER-1:4] <= {NTIMER-4{1'b0}};
	out <= {NTIMER{1'b0}};
	pulse[NTIMER-1:4] <= {NTIMER-4{1'b1}};
end
else begin
	if (cs_i & we_i)
		casez(adr_i[13:2])
		12'b0????????010:	maxcounth[adr_i[12:5]][31: 0] <= dat_i;
		12'b0????????011:	maxcounth[adr_i[12:5]][47:32] <= dat_i[15:0];
		12'b0????????100:	ontimeh[adr_i[12:5]][31:0] <= dat_i;
		12'b0????????101:	ontimeh[adr_i[12:5]][47:32] <= dat_i[15:0];
		12'b0????????110:
			begin
				if (dat_i[7]) begin
					ldh[adr_i[12:5]] <= 1'b0;
					ld[adr_i[12:5]] <= ldh[adr_i[12:5]];
					ce[adr_i[12:5]] <= ceh[adr_i[12:5]];
					ar[adr_i[12:5]] <= arh[adr_i[12:5]];
					xc[adr_i[12:5]] <= xch[adr_i[12:5]];
					ge[adr_i[12:5]] <= geh[adr_i[12:5]];
					oti[adr_i[12:5]] <= otih[adr_i[12:5]];
					maxcount[adr_i[12:5]] <= maxcounth[adr_i[12:5]];
					ontime[adr_i[12:5]] <= ontimeh[adr_i[12:5]];
				end
				else begin
					ldh[adr_i[12:5]] <= dat_i[0];
					ceh[adr_i[12:5]] <= dat_i[1];
					arh[adr_i[12:5]] <= dat_i[2];
					xch[adr_i[12:5]] <= dat_i[3];
					geh[adr_i[12:5]] <= dat_i[4];
					otih[adr_i[12:5]] <= dat_i[5];
				end
				vector[adr_i[12:5]] <= dat_i[15:8];
				mailbox[adr_i[12:5]] <= dat_i[31:16];
			end
//		11'b0???????111:	vector[adr_i[11:5]] <= dat_i;
		12'b100000000000:	ie[31:0] <= dat_i;
		12'b100000000001:	ie[63:32] <= dat_i;
		12'b100000000010:	ie[95:64] <= dat_i;
		12'b100000000011:	ie[127:96] <= dat_i;
		12'b100000000100:	ie[159:128] <= dat_i;
		12'b100000000101:	ie[191:160] <= dat_i;
		12'b100000000110:	ie[199:192] <= dat_i[7:0];
		12'b100000001000:
			begin
				ie[31:0] <= ie[31:0] & (~(underflow[31:0] & dat_i) | ar[31:0]);
				irqf[31:0] <= irqf[31:0] & ~dat_i;
				underflow[31:0] <= underflow[31:0] & ~dat_i;
			end
		12'b100000001001:
			begin
				ie[63:32] <= ie[63:32] & (~(underflow[63:32] & dat_i) | ar[63:32]);
				irqf[63:32] <= irqf[63:32] & ~dat_i;
				underflow[63:32] <= underflow[63:32] & ~dat_i;
			end
		12'b100000001010:
			begin
				ie[95:64] <= ie[95:64] & (~(underflow[95:64] & dat_i) | ar[95:64]);
				irqf[95:64] <= irqf[95:64] & ~dat_i;
				underflow[95:64] <= underflow[95:64] & ~dat_i;
			end
		12'b100000001011:
			begin
				ie[127:96] <= ie[127:96] & (~(underflow[127:96] & dat_i) | ar[127:96]);
				irqf[127:96] <= irqf[127:96] & ~dat_i;
				underflow[127:96] <= underflow[127:96] & ~dat_i;
			end
		12'b100000001100:
			begin
				ie[159:128] <= ie[159:128] & (~(underflow[159:128] & dat_i) | ar[159:128]);
				irqf[159:128] <= irqf[159:128] & ~dat_i;
				underflow[159:128] <= underflow[159:128] & ~dat_i;
			end
		12'b100000001101:
			begin
				ie[191:160] <= ie[191:160] & (~(underflow[191:160] & dat_i) | ar[191:160]);
				irqf[191:160] <= irqf[191:160] & ~dat_i;
				underflow[191:160] <= underflow[191:160] & ~dat_i;
			end
		12'b100000001110:
			begin
				ie[199:192] <= ie[199:192] & (~(underflow[199:192] & dat_i[7:0]) | ar[199:192]);
				irqf[199:192] <= irqf[199:192] & ~dat_i[7:0];
				underflow[199:192] <= underflow[199:192] & ~dat_i[7:0];
			end
//		11'b10000000110:	irqf[95:64] <= irqf[95:64] & ~dat_i;
//		11'b10000000111:	irqf[127:96] <= irqf[127:96] & ~dat_i;
		12'b100000010000:	underflow[31:0] <= underflow[31:0] & ~dat_i;
		12'b100000010001:	underflow[63:32] <= underflow[63:32] & ~dat_i;
		12'b100000010010:	underflow[95:64] <= underflow[95:64] & ~dat_i;
		12'b100000010011:	underflow[127:96] <= underflow[127:96] & ~dat_i;
		12'b100000010100:	underflow[159:128] <= underflow[159:128] & ~dat_i;
		12'b100000010101:	underflow[191:160] <= underflow[191:160] & ~dat_i;
		12'b100000010110:	underflow[199:192] <= underflow[199:192] & ~dat_i[7:0];
//		11'b10000001010:	underflow[95:64] <= underflow[95:64] & ~dat_i;
//		11'b10000001011:	underflow[127:96] <= underflow[127:96] & ~dat_i;
//		12'b100000100000:	vector <= {24'd0,dat_i[7:3],3'b0};
//		11'b10000100000:	ce[31:0] <= dat_i;
//		11'b10000100001:	ce[63:32] <= dat_i;
//		11'b10000100100:	ce[31:0] <= ce[31:0] | dat_i;
//		11'b10000101000:	ce[31:0] <= ce[31:0] & ~dat_i;
		default:	;
		endcase
	if (cs_i)
		casez(adr_i[12:2])
		12'b0????????000:	
			begin
				dat_o <= count[adr_i[12:5]][31:0];
				counth[adr_i[12:5]] <= count[adr_i[12:5]];
			end
		12'b0????????001:	dat_o <= {16'd0,counth[adr_i[12:5]][47:32]};
		12'b0????????010:	dat_o <= maxcounth[adr_i[12:5]][31: 0];
		12'b0????????011:	dat_o <= {16'd0,maxcounth[adr_i[12:5]][47:32]};
		12'b0????????100:	dat_o <= ontimeh[adr_i[12:5]][31:0];
		12'b0????????101:	dat_o <= {16'd0,ontimeh[adr_i[12:5]][47:32]};
		12'b0????????110:
			begin
				dat_o[0] <= 1'b0;
				dat_o[1] <= ceh[adr_i[12:5]];
				dat_o[2] <= arh[adr_i[12:5]];
				dat_o[3] <= xch[adr_i[12:5]];
				dat_o[4] <= geh[adr_i[12:5]];
				dat_o[5] <= otih[adr_i[12:5]];
				dat_o[7:6] <= 2'd0;
				dat_o[15:8] <= vector[adr_i[12:5]];
				dat_o[31:16] <= mailbox[adr_i[12:5]];
			end
//		11'b0???????111:	dat_o <= vector[adr_i[11:5]];
		12'b100000000000:	dat_o <= ie[31:0];
		12'b100000000001:	dat_o <= ie[63:32];
		12'b100000000010:	dat_o <= ie[95:64];
		12'b100000000011:	dat_o <= ie[127:96];
		12'b100000000100:	dat_o <= ie[159:128];
		12'b100000000101:	dat_o <= ie[191:160];
		12'b100000000110:	dat_o <= ie[199:192];
	//	11'b10000000010:	dat_o <= ie[95:64];
	//	11'b10000000011:	dat_o <= ie[127:96];
		12'b100000001000:	dat_o <= irqf[31:0];
		12'b100000001001:	dat_o <= irqf[63:32];
		12'b100000001010:	dat_o <= irqf[95:64];
		12'b100000001011:	dat_o <= irqf[127:96];
		12'b100000001100:	dat_o <= irqf[159:128];
		12'b100000001101:	dat_o <= irqf[191:160];
		12'b100000001110:	dat_o <= irqf[199:192];
	//	11'b10000000110:	dat_o <= irqf[95:64];
	//	11'b10000000111:	dat_o <= irqf[127:96];
		12'b100000010000:	dat_o <= underflow[31:0];
		12'b100000010001:	dat_o <= underflow[63:32];
		12'b100000010010:	dat_o <= underflow[95:64];
		12'b100000010011:	dat_o <= underflow[127:96];
		12'b100000010100:	dat_o <= underflow[159:128];
		12'b100000010101:	dat_o <= underflow[191:160];
		12'b100000010110:	dat_o <= underflow[199:192];
	//	11'b10000001010:	dat_o <= underflow[95:64];
	//	11'b10000001011:	dat_o <= underflow[127:96];
	//	12'b100000100000:	dat_o <= {24'd0,vector[7:3],3'd0};
		default:	dat_o <= 32'd0;
		endcase
	else if (iack_i) begin
		dat_o <= {4{vector[irqn]}};
	end
	else
		dat_o <= 32'd0;
	
	if (ld[cntr]) begin
		ld[cntr] <= 1'b0;
		count[cntr] <= maxcount[cntr];
	end
	else if ((xc[cntr] ? pulse[cntr] & ce[cntr] : ce[cntr]) & (ge[cntr] ? gate[cntr] : 1'b1))
		count[cntr] <= count[cntr] - 48'd1;
	if (count[cntr] == ontime[cntr])
		out[cntr] <= 1'b1;
	if (count[cntr] == ontime[cntr] && oti[cntr])
		irqf[cntr] <= ie[cntr];
	if (count[cntr]==48'd0) begin
		count[cntr] <= maxcount[cntr];
		if (oti[cntr])
			irqf[cntr] <= 1'b0;
		else if (ie[cntr])
			irqf[cntr] <= 1'b1;
		underflow[cntr] <= 1'b1;
 		out[cntr] <= 1'b0;
		if (!ar[cntr])
			ce[cntr] <= 1'b0;
	end
	
end

always_comb
	irq_o = |irqf;

endmodule
