package rf68000_pkg;

function [3:0] MXlen(sz, m, x);
input [1:0] sz;
input [2:0] m;
input [2:0] x;

always @*
case(m)
3'd0,3'd1,3'd2,3'd3,3'd4;	MXlen = 4'd0; //	Dn An (An) (An)+ -(An)
3'd5:	MXlen = 4'd2;		// d16(An)
3'd6:	MXlen = 4'd2;		// d8(An,Xn)
3'd7:	
	case(x)
	3'd0:		MXlen = 4'd2;	// abs16
	3'd1:		MXlen = 4'd4;	// abs32
	3'd2:		MXlen = 4'd2;	// d16(PC)
	3'd3:		MXlen = 4'd2;	// d8(PC,Xn)
	3'd4:
		case(sz)
		2'd0:	MXlen = 4'd2;	// k8
		2'd1:	MXlen = 4'd2;	// k16
		2'd2:	MXlen = 4'd4;	// k32
		default:	MXlen = 4'd2;
		endcase
	default:
		MXlen = 4'd0;
	endcase
endcase
	
endfunction

endpackage
