
module regfile(clk, wrb, wrw, wrl, wrx, wa, i, ra0, ra1, ra2, ra3, ra4, ra5, ra6,
	o0, o1, o2, o3, o4, o5, o6);
input clk;
input wrb;
input wrw;
input wrl;
input wrx;
input [5:0] wa;
input [63:0] i;
input [5:0] ra0;
input [5:0] ra1;
input [5:0] ra2;
input [5:0] ra3;
input [5:0] ra4;
input [5:0] ra5;
input [5:0] ra6;
output reg [63:0] o0;
output reg [63:0] o1;
output reg [63:0] o2;
output reg [63:0] o3;
output reg [63:0] o4;
output reg [63:0] o5;
output reg [63:0] o6;

(* ram_style="distributed" *)
reg [63:0] mem [0:63];

always_ff @(posedge clk)
	if (wrb)
		mem[wa][7:0] <= i[7:0];
	else if (wrw) begin
		if (wa>=6'd8 && wa <= 6'd15)
			mem[wa] <= {{48{i[15]}},i[15:0]};
		else
			mem[wa][15:0] <= i[15:0];
	end
	else if (wrl) begin
		if (wa>=6'd8 && wa <= 6'd15)
			mem[wa] <= {{32{i[31]}},i[31:0]};
		else
			mem[wa][31:0] <= i[31:0];
	end
	else if (wrx)
		mem[wa][63:0] <= i[63:0];

always_comb o0 = mem[ra0];
always_comb o1 = mem[ra1];
always_comb o2 = mem[ra2];
always_comb o3 = mem[ra3];
always_comb o4 = mem[ra4];
always_comb o5 = mem[ra5];
always_comb o6 = mem[ra6];
	
endmodule
