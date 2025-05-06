function [3:0] ilen(ins);
input [127:0] ins;

always @*
case (ins[15:12])
4'h0:
	casez(ins[11:8])
	4'h0,4'h2,4'hA:		// ORI ANDI EORI
		casez(ins[7:0])
		8'b00111100:	ilen = 4'd4;	// ORI ccr
		8'b01111100:	ilen = 4'd4;	// ORI sr
		default:	ilen = 4'd2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);
		endcase
	4'h6:		ilen = 4'd2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);	// ADDI
	4'h8:		ilen = 4'd2 + MXlen(2'b00,ins[5:3],ins[2:0]);		// Bxxx
	4'hC:		ilen = 4'd2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);	// CMPI
	4'b???1:
		casez(ins[5:3])
		3'b001:	ilen = 4'd4;														// MOVEP
		default:	ilen = 4'd2 + MXlen(2'b00,ins[5:3],ins[2:0]);		// Bxxx
	default:	ilen = 4'd2;
	endcase
// MOVE
4'h1:	ilen = 4'h2 + MXlen(2'b00,ins[8:6],ins[11:9]) + MXlen(2'b00,ins[5:3],ins[2:0]);
4'h2:	ilen = 4'h2 + MXlen(2'b10,ins[8:6],ins[11:9]) + MXlen(2'b00,ins[5:3],ins[2:0]);
4'h3:	ilen = 4'h2 + MXlen(2'b01,ins[8:6],ins[11:9]) + MXlen(2'b00,ins[5:3],ins[2:0]);
4'h4:
	casez(ins[11:8])
	4'h0:
		case(ins[7:6])
		2'b11:	ilen = 4'h2 + MXlen(2'b00,ins[5:3],ins[2:0]);	// MOVE from SR
		default:	ilen = 4'h2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);	// NEGX
		endcase
	4'h2:
		case(ins[7:6])
		2'b11:	ilen = 4'h2 + MXlen(2'b00,ins[5:3],ins[2:0]);	// MOVE to CCR
		default:	ilen = 4'h2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);	// CLR
		endcase	
	4'h4:	ilen = 4'h2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);	// NEG
	4'h6:	ilen = 4'h2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);	// NOT
	4'h8:
		if (ins[7])
			ilen = 4'h2 + MXlen(ins[6],~ins[6],ins[5:3],ins[2:0]);	// MOVEM
		else
			case(ins[5:3])
			3'd0:	ilen = 4'h2;	// EXT SWAP
			default:	ilen = 4'h2 + MXlen({ins[6],1'b0},ins[5:3],ins[2:0]);	// NBCD PEA
			endcase
	4'hA:
		casez(ins[7:0])
		8'hFC:	ilen = 4'h2;	// Illegal
		8'b11??????:	ilen = 4'h2 + MXlen(2'b00,ins[5:3],ins[2:0]);	// TAS
		default:	ilen = 4'h2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);	// TST
		endcase
	4'hC:
		ilen = 4'h2 + MXlen(ins[6],~ins[6],ins[5:3],ins[2:0]);	// MOVEM
	4'hE:
		casez(ins[7:0])
		8'h4?:	ilen = 4'h2;	// TRAP
		8'b10100???:	ilen = 4'h4:	// LINK
		8'b10101???:	ilen = 4'h2;	// UNLK
		8'h6?:	ilen = 4'h2;	// MOVE USP
		8'h70:	ilen = 4'h2;	// RESET
		8'h71:	ilen = 4'h2;	// NOP
		8'h72:	ilen = 4'h4;	// STOP
		8'h73:	ilen = 4'h2;	// RTE
		8'h74:	ilen = 4'h2;	// RTS
		8'h76:	ilen = 4'h2;	// TRAPV
		8'h77:	ilen = 4'h2;	// RTR
		8'b01??????:	ilen = MXlen(2'b00,ins[5:3],ins[2:0]);	// JSR JMP
		default:	ilen = 4'h2;
		endcase
	4'b???1:
		case(ins[7:6])
		2'b11:	ilen = 4'h2 + MXlen(2'b00,ins[5:3],ins[2:0]);	// LEA
		2'b10:	ilen = 4'h2 + MXlen(2'b01,ins[5:3],ins[2:0]);	// CHK
		default:	ilen = 4'h2;
		endcase
4'h5:
	case(ins[7:6])
	2'b11:
		case(ins[5:3])
		3'b001:	ilen = 4'h4;	// DBcc
		default:	ilen = 4'h2 + MXlen(2'b00,ins[5:3],ins[2:0]);	// Scc
		endcase
	default:	ilen = 4'h2 + MXlen(ins[7:6],ins[5:3],ins[2:0]);	// ADDQ SUBQ
	endcase
4'h6:											// Bcc
	case(ins[11:0])
	12'h?00:	ilen = 4'h4;
	default:	ilen = 4'h2;
	endcase
4'h7:	ilen = 4'h2;		// MOVEQ
4'h8:	
endcase

endmodule

