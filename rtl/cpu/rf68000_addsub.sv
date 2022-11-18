
module rf68000_addsub(op, ci, a, b, o, co, vo);
input op;							// 0=add, 1=sub
input ci;
input [7:0] a;
input [7:0] b;
output reg [7:0] o;
output reg co;
output reg vo;

reg [7:0] s1;
reg [1:0] s2;

always_comb
if (op)
	s1 = a[6:0] - b[6:0] - ci;
else
	s1 = a[6:0] + b[6:0] + ci;
always_comb
if (op)
	s2 = a[7] - b[7] - s1[7];
else
	s2 = a[7] + b[7] + s1[7];
always_comb
	co = s2[1];
always_comb
	vo = s2[1]^s1[7];
always_comb
	o = {s2[0],s1[6:0]};

endmodule
