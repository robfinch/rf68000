function [4:0] mapDn;
input [2:0] Dn;
begin
	mapDn = {2'b00,Dn} + 1'b1;
end
endfunction

function [4:0] mapAn;
input [2:0] An;
begin
	mapAn = {2'b00,An} + 4'd9;
end
endfunction

function updpat_e fnUpdpat;
input decode_bus_t db;
begin
	case(1'b1)
	db.ori_ccr:	fnUpdpat = UPD_ORI_CCR;
	db.ori_sr:	fnUpdpat = UPD_ORI_SR;
	db.ori:			fnUpdpat = UPD_LOGIC;
	db.andi_ccr:	fnUpdpat = UPD_ANDI_CCR;
	db.andi_sr:		fnUpdpat = UPD_ANDI_SR;
	db.andi:			fnUpdpat = UPD_LOGIC;
	db.subi:			fnUpdpat = UPD_SUB;
	db.addi:			fnUpdpat = UPD_ADD;
	db.eori_ccr:	fnUpdpat = UPD_EORI_CCR;
	db.eori_sr:		fnUpdpat = UPD_EORI_SR;
	db.eori:			fnUpdpat = UPD_LOGIC;
	db.cmpi:			fnUpdpat = UPD_CMP;
	db.btst:			fnUpdpat = UPD_BTST;
	db.bchg:			fnUpdpat = UPD_BTST;
	db.bclr:			fnUpdpat = UPD_BTST;
	db.bset:			fnUpdpat = UPD_BTST;
	db.btst_dn:		fnUpdpat = UPD_BTST;
	db.bchg_dn:		fnUpdpat = UPD_BTST;
	db.bclr_dn:		fnUpdpat = UPD_BTST;
	db.bset_dn:		fnUpdpat = UPD_BTST;
	db.movep:			fnUpdpat = UPD_NONE;
	db.movea:			fnUpdpat = UPD_NONE;
	db.move:			fnUpdpat = UPD_MOVE;
	db.move_from_sr:	fnUpdpat = UPD_NONE;
	db.move_to_ccr:		fnUpdpat = UPD_MOVE2CCR;
	db.move_to_sr:		fnUpdpat = UPD_MOVE2SR;
	db.negx:					fnUpdpat = UPD_NEGX;
	db.clr:						fnUpdpat = UPD_CLR;
	db.neg:						fnUpdpat = UPD_NEG;
	db.inot:					fnUpdpat = UPD_LOGIC;
	db.ext:						fnUpdpat = UPD_LOGIC;
	db.nbcd:					fnUpdpat = UPD_BCD;
	db.swap:					fnUpdpat = UPD_LOGIC;
	db.pea:						fnUpdpat = UPD_NONE;
	db.illegal:				fnUpdpat = UPD_NONE;
	db.tas:						fnUpdpat = UPD_TST;
	db.tst:						fnUpdpat = UPD_TST;
	db.trap:					fnUpdpat = UPD_NONE;
	db.link:					fnUpdpat = UPD_NONE;
	db.unlk:					fnUpdpat = UPD_NONE;
	db.move2usp:			fnUpdpat = UPD_NONE;
	db.reset:					fnUpdpat = UPD_NONE;
	db.nop:						fnUpdpat = UPD_NONE;
	db.stop:					fnUpdpat = UPD_STOP;
	db.rte:						fnUpdpat = UPD_RTE;
	db.rts:						fnUpdpat = UPD_NONE;
	db.trapv:					fnUpdpat = UPD_NONE;
	db.rtr:						fnUpdpat = UPD_RTR;
	db.jsr:						fnUpdpat = UPD_NONE;
	db.jmp:						fnUpdpat = UPD_NONE;
	db.movem:					fnUpdpat = UPD_NONE;
	db.lea:						fnUpdpat = UPD_NONE;
	db.chk:						fnUpdpat = UPD_CHK;
	db.addq:					fnUpdpat = UPD_ADD;
	db.subq:					fnUpdpat = UPD_SUB;
	db.scc:						fnUpdpat = UPD_NONE;
	db.dbcc:					fnUpdpat = UPD_NONE;
	db.bra:						fnUpdpat = UPD_NONE;
	db.bsr:						fnUpdpat = UPD_NONE;
	db.bcc:						fnUpdpat = UPD_NONE;
	db.moveq:					fnUpdpat = UPD_LOGIC;
	db.divu:					fnUpdpat = UPD_MUL;
	db.divs:					fnUpdpat = UPD_MUL;
	db.sbcd:					fnUpdpat = UPD_BCD;
	db.ior:						fnUpdpat = UPD_LOGIC;
	db.sub:						fnUpdpat = UPD_SUB;
	db.subx:					fnUpdpat = UPD_SUBX;
	db.suba:					fnUpdpat = UPD_NONE;
	db.eor:						fnUpdpat = UPD_LOGIC;
	db.cmpm:					fnUpdpat = UPD_SUB;
	db.cmp:						fnUpdpat = UPD_SUB;
	db.cmpa:					fnUpdpat = UPD_SUB;
	db.mulu:					fnUpdpat = UPD_MUL;
	db.muls:					fnUpdpat = UPD_MUL;
	db.abcd:					fnUpdpat = UPD_BCD;
	db.exg:						fnUpdpat = UPD_NONE;
	db.iand:					fnUpdpat = UPD_LOGIC;
	db.add:						fnUpdpat = UPD_ADD;
	db.addx:					fnUpdpat = UPD_ADDX;
	db.adda:					fnUpdpat = UPD_ADD;
	db.as:						fnUpdpat = UPD_AS;
	db.ls:						fnUpdpat = UPD_LS;
	db.rox:						fnUpdpat = UPD_ROX;
	db.ro:						fnUpdpat = UPD_RO;
end
endfunction

// Handles mapping:
//	ADD,SUB,AND,OR
task tAluUop;
input uop_opcode_t opc;
input instruction_t ir;
input ndx_t ir2;
input [15:0] ir3;
input [15:0] ir4;
input [51:0] ir5;
input [4:0] updpat;
output uop_t [3:0] uop;
output [2:0] icount;
begin
	icount = 3'd1;
	uop[0] = {$bits(uop_t){1'b0}};
	uop[1] = {$bits(uop_t){1'b0}};
	uop[2] = {$bits(uop_t){1'b0}};
	uop[3] = {$bits(uop_t){1'b0}};
	uop[0].updpat = UPD_ALL;
	uop[1].updpat = UPD_ALL;
	uop[2].updpat = UPD_ALL;
	uop[3].updpat = UPD_ALL;
	uop[1].num = 3'd1;
	uop[2].num = 3'd2;
	uop[3].num = 3'd3;
	case({ir.add.d,ir.add.m})
	4'b0000:	// Dn
		begin
			uop[0].count = 3'd2;
			uop[0].opcode = opc;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = mapDn(ir.add.Dn);
			uop[0].Rs1 = mapDn(ir.add.Dn);
			uop[0].Rs2 = mapDn(ir.add.Xn);

			uop[1].opcode = 7'd64|opc;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = 5'd30;
			uop[1].Rs1 = mapDn(ir.add.Dn);
			uop[1].Rs2 = mapDn(ir.add.Xn);
			uop[1].updpat = updpat;
		end
	4'b0001:	// An
		begin
			uop[0].count = 3'd2;
			uop[0].opcode = opc;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = mapDn(ir.add.Dn);
			uop[0].Rs1 = mapDn(ir.add.Dn);
			uop[0].Rs2 = mapAn(ir.add.Xn);
			uop[0].updpat = updpat;

			uop[1].opcode = 7'd64|opc;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = 5'd30;
			uop[1].Rs1 = mapDn(ir.add.Dn);
			uop[1].Rs2 = mapDn(ir.add.Xn);
			uop[1].updpat = updpat;
		end
	4'b0010:	// (An)
		begin
			uop[0].count = 3'd3;
			uop[0].opcode = rf68000_pkg::OP_LOAD;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = 5'd17;
			uop[0].Rs1 = mapAn(ir.add.Xn);
		
			uop[1].opcode = opc;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = mapDn(ir.add.Dn);
			uop[1].Rs1 = mapDn(ir.add.Dn);
			uop[1].Rs2 = 5'd17;
			uop[1].updpat = updpat;

			uop[2].opcode = 7'd64|opc;
			uop[2].sz = ir.add.sz;
			uop[2].Rd = 5'd30;
			uop[2].Rs1 = mapDn(ir.add.Dn);
			uop[2].Rs2 = mapDn(ir.add.Xn);
			uop[2].updpat = updpat;
		end
	4'b0011:	// (An)+
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd3;
			uop[0].num = 3'd0;
			uop[0].updpat = UPD_ALL;
			uop[0].opcode = rf68000_pkg::OP_LOAD;
			uop[0].i = 1'b1;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = 5'd17;
			uop[0].Rs1 = mapAn(ir.add.Xn);
		
			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].updpat = UPD_ALL;
			uop[1].opcode = rf68000_pkg::OP_ADD;
			uop[1].sz = rf68000_pkg::SZ_LONG;
			uop[1].Rd = mapAn(ir.add.Xn);
			uop[1].Rs1 = mapAn(ir.add.Xn);
			case(ir.add.sz)
			2'b00:	uop[1].imm = 32'd1;
			2'b01:	uop[1].imm = 32'd2;
			2'b10:	uop[1].imm = 32'd4;
			2'b11:	uop[1].imm = 32'd8;
			endcase
		
			uop[2] = {$bits(uop_t){1'b0}};
			uop[2].num = 3'd2;
			uop[2].updpat = UPD_ALL;
			uop[2].opcode = opc;
			uop[2].i = 1'b0;
			uop[2].sz = ir.add.sz;
			uop[2].Rd = mapDn(ir.add.Dn);
			uop[2].Rs1 = mapDn(ir.add.Rn);
			uop[2].Rs2 = 5'd17;
			uop[2].updpat = updpat;
		end
	4'b0100:	// -(An)
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd3;
			uop[0].opcode = rf68000_pkg::OP_ADD;
			uop[0].sz = rf68000_pkg::SZ_LONG;
			uop[0].Rd = mapAn(ir.add.Xn);
			uop[0].Rs1 = mapAn(ir.add.Xn);
			case(ir.add.sz)
			2'b00:	uop[0].imm = 32'hFFFFFFFF;
			2'b01:	uop[0].imm = 32'hFFFFFFFE;
			2'b10:	uop[0].imm = 32'hFFFFFFFC;
			2'b11:	uop[0].imm = 32'hFFFFFFF8;
			endcase
			
			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].updpat = UPD_ALL;
			uop[1].opcode = rf68000_pkg::OP_LOAD;
			uop[1].i = 1'b1;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = 5'd17;
			uop[1].Rs1 = mapAn(ir.add.Xn);
		
			uop[2] = {$bits(uop_t){1'b0}};
			uop[2].num = 3'd2;
			uop[2].opcode = opc;
			uop[2].sz = ir.add.sz;
			uop[2].Rd = mapDn(ir.add.Dn);
			uop[2].Rs1 = mapDn(ir.add.Rn);
			uop[2].Rs2 = 5'd17;
			uop[2].updpat = updpat;
		end
	4'b0101:	// d16(An)
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd2;
			uop[0].opcode = rf68000_pkg::OP_LOAD;
			uop[0].i = 1'b1;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = 5'd17;
			uop[0].Rs1 = mapAn(ir.add.Xn);
			uop[0].imm = {{16{ir2[15]}},ir2};

			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].opcode = opc;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = mapDn(ir.add.Dn);
			uop[1].Rs1 = mapDn(ir.add.Dn);
			uop[1].Rs2 = 5'd17;
			uop[1].updpat = updpat;
			icount = 3'd2;
		end
	4'b0110:	//d8(An,Xn)
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd2;
			uop[0].opcode = rf68000_pkg::OP_LOAD;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = 5'd17;
			uop[0].Rs1 = mapAn(ir.add.Xn);
			uop[0].Rs2 = ir2.ndx.m ? mapAn(ir2.ndx.Xn) : mapDn(ir2.ndx.Xn);
			uop[0].Rs2wl = ir2.ndx.wl;
			uop[0].imm = {{23{ir2[7]}},ir2[7:0]};

			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].opcode = opc;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = mapDn(ir.add.Dn);
			uop[1].Rs1 = mapDn(ir.add.Dn);
			uop[1].Rs2 = 5'd17;
			uop[1].updpat = updpat;
			icount = 3'd2;
		end
	4'b0111:
		begin
			case(ir.add.Xn)
			3'b000:	// abs16
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd2;
					uop[0].opcode = rf68000_pkg::OP_LOAD;
					uop[0].i = 1'b1;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = 5'd17;
					uop[0].Rs1 = 5'd0;
					uop[0].imm = {{16{ir2[15]}},ir2};

					uop[1] = {$bits(uop_t){1'b0}};
					uop[1].num = 3'd1;
					uop[1].opcode = opc;
					uop[1].sz = ir.add.sz;
					uop[1].Rd = mapDn(ir.add.Dn);
					uop[1].Rs1 = mapDn(ir.add.Dn);
					uop[1].Rs2 = 5'd17;
					uop[1].updpat = updpat;
					icount = 3'd2;
				end
			3'b001:	// abs32
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd2;
					uop[0].opcode = rf68000_pkg::OP_LOAD;
					uop[0].i = 1'b1;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = 5'd17;
					uop[0].Rs1 = 5'd0;
					uop[0].imm = {ir2,ir3};

					uop[1] = {$bits(uop_t){1'b0}};
					uop[1].num = 3'd1;
					uop[1].opcode = opc;
					uop[1].sz = ir.add.sz;
					uop[1].Rd = mapDn(ir.add.Dn);
					uop[1].Rs1 = mapDn(ir.add.Dn);
					uop[1].Rs2 = 5'd17;
					uop[1].updpat = updpat;
					icount = 3'd3;
				end
			3'b010:		// d16(PC)
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd2;
					uop[0].opcode = rf68000_pkg::OP_LOAD;
					uop[0].i = 1'b1;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = 5'd17;
					uop[0].Rs1 = 5'd31;	// PC
					uop[0].imm = {{16{ir2[15]}},ir2};

					uop[1] = {$bits(uop_t){1'b0}};
					uop[1].num = 3'd1;
					uop[1].opcode = opc;
					uop[1].sz = ir.add.sz;
					uop[1].Rd = mapDn(ir.add.Dn);
					uop[1].Rs1 = mapDn(ir.add.Dn);
					uop[1].Rs2 = 5'd17;
					uop[1].updpat = updpat;
					icount = 3'd2;
				end
			3'b011:	// d8(PC,Xn)
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd2;
					uop[0].opcode = rf68000_pkg::OP_LOAD;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = 5'd17;
					uop[0].Rs1 = 5'd31;		// PC
					uop[0].Rs2 = ir2.ndx.m ? mapAn(ir2.ndx.Xn) : mapDn(ir2.ndx.Xn);
					uop[0].Rs2wl = ir2.ndx.wl;
					uop[0].imm = {{23{ir2[7]}},ir2[7:0]};

					uop[1] = {$bits(uop_t){1'b0}};
					uop[1].num = 3'd1;
					uop[1].opcode = opc;
					uop[1].sz = ir.add.sz;
					uop[1].Rd = mapDn(ir.add.Dn);
					uop[1].Rs1 = mapDn(ir.add.Dn);
					uop[1].Rs2 = 5'd17;
					uop[1].updpat = updpat;
					icount = 3'd2;
				end		
			3'b100:
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd1;
					uop[0].opcode = opc;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = mapDn(ir.add.Dn);
					uop[0].Rs1 = mapDn(ir.add.Dn);
					uop[0].Rs2 = 5'd0;
					case(ir.add.sz)
					2'b00:	begin uop[0].imm = {{24{ir2[7]}},ir2[7:0]}; icount = 3'd2; end
					2'b01:	begin uop[0].imm = {{16{ir2[15]}},ir2}; icount = 3'd2; end
					2'b10:	begin uop[0].imm = {ir2,ir3}; icount = 3'd3; end
					2'b11:	begin uop[0].imm = {ir2,ir3,ir4,ir5}; icount = 3'd5; end
					endcase
					uop[0].updpat = updpat;
				end
			default:
				uop[0] = {$bits(uop_t){1'b0}};
				uop[0].count = 3'd1;
			endcase
		end
	4'b1000:	// Dn
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd1;
			uop[0].num = 3'd0;
			uop[0].opcode = opc;
			uop[0].Rd = mapDn(ir.add.Xn);
			uop[0].Rs1 = mapDn(ir.add.Xn);
			uop[0].Rs2 = mapDn(ir.add.Dn);
			uop[0].updpat = updpat;
		end
	4'b1001:	// An
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd1;
			uop[0].num = 3'd0;
			uop[0].opcode = opc;
			uop[0].Rd = mapAn(ir.add.Xn);
			uop[0].Rs1 = mapAn(ir.add.Xn);
			uop[0].Rs2 = mapDn(ir.add.Dn);
			uop[0].updpat = updpat;
		end
	4'b1010:	// (An)
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd3;
			uop[0].num = 3'd0;
			uop[0].opcode = rf68000_pkg::OP_LOAD;
			uop[0].i = 1'b1;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = 5'd17;
			uop[0].Rs1 = mapAn(ir.add.Xn);
		
			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].opcode = opc;
			uop[1].i = 1'b0;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = 5'd17;
			uop[1].Rs1 = 5'd17;
			uop[1].Rs2 = mapDn(ir.add.Dn);
			uop[1].updpat = updpat;

			uop[2] = {$bits(uop_t){1'b0}};
			uop[2].num = 3'd2;
			uop[2].opcode = rf68000_pkg::OP_STORE;
			uop[2].i = 1'b1;
			uop[2].sz = ir.add.sz;
			uop[2].Rd = 5'd17;
			uop[2].Rs1 = mapAn(ir.add.Xn);
		end
	4'b1011:	// (An)+
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd4;
			uop[0].num = 3'd0;
			uop[0].opcode = rf68000_pkg::OP_LOAD;
			uop[0].i = 1'b1;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = 5'd17;
			uop[0].Rs1 = mapAn(ir.add.Xn);
		
			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].opcode = opc;
			uop[1].i = 1'b0;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = 5'd17;
			uop[1].Rs1 = 5'd17;
			uop[1].Rs2 = mapDn(ir.add.Dn);
			uop[1].updpat = updpat;

			uop[2] = {$bits(uop_t){1'b0}};
			uop[2].num = 3'd2;
			uop[2].opcode = rf68000_pkg::OP_STORE;
			uop[2].i = 1'b1;
			uop[2].sz = ir.add.sz;
			uop[2].Rd = 5'd17;
			uop[2].Rs1 = mapAn(ir.add.Xn);

			uop[3] = {$bits(uop_t){1'b0}};
			uop[3].num = 3'd3;
			uop[3].opcode = rf68000_pkg::OP_ADD;
			uop[3].sz = rf68000_pkg::SZ_LONG;
			uop[3].Rd = mapAn(ir.add.Xn);
			uop[3].Rs1 = mapAn(ir.add.Xn);
			case(ir.add.sz)
			2'b00:	uop[3].imm = 32'd1;
			2'b01:	uop[3].imm = 32'd2;
			2'b10:	uop[3].imm = 32'd4;
			2'b11:	uop[3].imm = 32'd8;
			endcase
		end
	4'b1100:	// -(An)
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd4;
			uop[0].opcode = rf68000_pkg::OP_ADD;
			uop[0].sz = rf68000_pkg::SZ_LONG;
			uop[0].Rd = mapAn(ir.add.Xn);
			uop[0].Rs1 = mapAn(ir.add.Xn);
			case(ir.add.sz)
			2'b00:	uop[0].imm = 32'hFFFFFFFF;
			2'b01:	uop[0].imm = 32'hFFFFFFFE;
			2'b10:	uop[0].imm = 32'hFFFFFFFC;
			2'b11:	uop[0].imm = 32'hFFFFFFF8;
			endcase
			
			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].opcode = rf68000_pkg::OP_LOAD;
			uop[1].i = 1'b1;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = 5'd17;
			uop[1].Rs1 = mapAn(ir.add.Xn);
		
			uop[2] = {$bits(uop_t){1'b0}};
			uop[2].num = 3'd2;
			uop[2].opcode = opc;
			uop[2].sz = ir.add.sz;
			uop[2].Rd = 5'd17;
			uop[2].Rs1 = 5'd17;
			uop[2].Rs2 = mapDn(ir.add.Dn);
			uop[2].updpat = updpat;

			uop[3] = {$bits(uop_t){1'b0}};
			uop[3].num = 3'd3;
			uop[3].opcode = rf68000_pkg::OP_STORE;
			uop[3].i = 1'b1;
			uop[3].sz = ir.add.sz;
			uop[3].Rd = 5'd17;
			uop[3].Rs1 = mapAn(ir.add.Xn);
		end
	4'b1101:	// d16(An)
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd3;
			uop[0].opcode = rf68000_pkg::OP_LOAD;
			uop[0].i = 1'b1;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = 5'd17;
			uop[0].Rs1 = mapAn(ir.add.Xn);
			uop[0].imm = {{16{ir2[15]}},ir2};

			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].opcode = opc;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = 5'd17;
			uop[1].Rs1 = 5'd17;
			uop[1].Rs2 = mapDn(ir.add.Dn);
			uop[1].updpat = updpat;

			uop[2] = {$bits(uop_t){1'b0}};
			uop[2].num = 3'd2;
			uop[2].opcode = rf68000_pkg::OP_STORE;
			uop[2].i = 1'b1;
			uop[2].sz = ir.add.sz;
			uop[2].Rd = 5'd17;
			uop[2].Rs1 = mapAn(ir.add.Xn);
			uop[2].imm = {{16{ir2[15]}},ir2};
			icount = 3'd2;
		end
	4'b1110:	//d8(An,Xn)
		begin
			uop[0] = {$bits(uop_t){1'b0}};
			uop[0].count = 3'd3;
			uop[0].opcode = rf68000_pkg::OP_LOAD;
			uop[0].sz = ir.add.sz;
			uop[0].Rd = 5'd17;
			uop[0].Rs1 = mapAn(ir.add.Xn);
			uop[0].Rs2 = ir2.ndx.m ? mapAn(ir2.ndx.Xn) : mapDn(ir2.ndx.Xn);
			uop[0].Rs2wl = ir2.ndx.wl;
			uop[0].imm = {{23{ir2[7]}},ir2[7:0]};

			uop[1] = {$bits(uop_t){1'b0}};
			uop[1].num = 3'd1;
			uop[1].opcode = opc;
			uop[1].sz = ir.add.sz;
			uop[1].Rd = 5'd17;
			uop[1].Rs1 = 5'd17;
			uop[1].Rs2 = mapDn(ir.add.Dn);
			uop[1].updpat = updpat;

			uop[2] = {$bits(uop_t){1'b0}};
			uop[2].num = 3'd2;
			uop[2].opcode = rf68000_pkg::OP_STORE;
			uop[2].i = 1'b1;
			uop[2].sz = ir.add.sz;
			uop[2].Rd = 5'd17;
			uop[2].Rs1 = mapAn(ir.add.Xn);
			uop[2].imm = {{16{ir2[15]}},ir2};
			icount = 3'd2;
		end
	4'b1111:
		begin
			case(ir.add.Xn)
			3'b000:	// abs16
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd2;
					uop[0].opcode = rf68000_pkg::OP_LOAD;
					uop[0].i = 1'b1;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = 5'd17;
					uop[0].Rs1 = 5'd0;
					uop[0].imm = {{16{ir2[15]}},ir2};

					uop[1] = {$bits(uop_t){1'b0}};
					uop[1].num = 3'd1;
					uop[1].opcode = opc;
					uop[1].sz = ir.add.sz;
					uop[1].Rd = 5'd17;
					uop[1].Rs1 = 5'd17;
					uop[1].Rs2 = mapDn(ir.add.Dn);
					uop[1].updpat = updpat;

					uop[2] = {$bits(uop_t){1'b0}};
					uop[2].num = 3'd2;
					uop[2].opcode = rf68000_pkg::OP_STORE;
					uop[2].i = 1'b1;
					uop[2].sz = ir.add.sz;
					uop[2].Rd = 5'd17;
					uop[2].Rs1 = 5'd0;
					uop[2].imm = {{16{ir2[15]}},ir2};
					icount = 3'd2;
				end
			3'b001:	// abs32
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd3;
					uop[0].opcode = rf68000_pkg::OP_LOAD;
					uop[0].i = 1'b1;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = 5'd17;
					uop[0].Rs1 = 5'd0;
					uop[0].imm = {ir2,ir3};

					uop[1] = {$bits(uop_t){1'b0}};
					uop[1].num = 3'd1;
					uop[1].opcode = opc;
					uop[1].sz = ir.add.sz;
					uop[1].Rd = 5'd17;
					uop[1].Rs1 = 5'd17;
					uop[1].Rs2 = mapDn(ir.add.Dn);
					uop[1].updpat = updpat;

					uop[2] = {$bits(uop_t){1'b0}};
					uop[2].num = 3'd2;
					uop[2].opcode = rf68000_pkg::OP_STORE;
					uop[2].i = 1'b1;
					uop[2].sz = ir.add.sz;
					uop[2].Rd = 5'd17;
					uop[2].Rs1 = 5'd0;
					uop[2].imm = {ir2,ir3};
					icount = 3'd3;
				end
			3'b010:		// d16(PC)
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd3;
					uop[0].opcode = rf68000_pkg::OP_LOAD;
					uop[0].i = 1'b1;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = 5'd17;
					uop[0].Rs1 = 5'd31;	// PC
					uop[0].imm = {{16{ir2[15]}},ir2};

					uop[1] = {$bits(uop_t){1'b0}};
					uop[1].num = 3'd1;
					uop[1].opcode = opc;
					uop[1].sz = ir.add.sz;
					uop[1].Rd = 5'd17;
					uop[1].Rs1 = 5'd17;
					uop[1].Rs2 = mapDn(ir.add.Dn);
					uop[1].updpat = updpat;

					uop[2] = {$bits(uop_t){1'b0}};
					uop[2].num = 3'd2;
					uop[2].opcode = rf68000_pkg::OP_STORE;
					uop[2].i = 1'b1;
					uop[2].sz = ir.add.sz;
					uop[2].Rd = 5'd17;
					uop[2].Rs1 = 5'd31;
					uop[2].imm = {{16{ir2[15]}},ir2};
					icount = 3'd2;
				end
			3'b011:	// d8(PC,Xn)
				begin
					uop[0] = {$bits(uop_t){1'b0}};
					uop[0].count = 3'd2;
					uop[0].opcode = rf68000_pkg::OP_LOAD;
					uop[0].sz = ir.add.sz;
					uop[0].Rd = 5'd17;
					uop[0].Rs1 = 5'd31;		// PC
					uop[0].Rs2 = ir2.ndx.m ? mapAn(ir2.ndx.Xn) : mapDn(ir2.ndx.Xn);
					uop[0].Rs2wl = ir2.ndx.wl;
					uop[0].imm = {{23{ir2[7]}},ir2[7:0]};

					uop[1] = {$bits(uop_t){1'b0}};
					uop[1].num = 3'd1;
					uop[1].opcode = opc;
					uop[1].sz = ir.add.sz;
					uop[1].Rd = 5'd17;
					uop[1].Rs1 = 5'd17;
					uop[1].Rs2 = mapDn(ir.add.Dn);
					uop[1].updpat = updpat;

					uop[2] = {$bits(uop_t){1'b0}};
					uop[2].num = 3'd2;
					uop[2].opcode = rf68000_pkg::OP_STORE;
					uop[2].i = 1'b1;
					uop[2].sz = ir.add.sz;
					uop[2].Rd = 5'd17;
					uop[2].Rs1 = 5'd31;		// PC
					uop[2].Rs2 = ir2.ndx.m ? mapAn(ir2.ndx.Xn) : mapDn(ir2.ndx.Xn);
					uop[2].Rs2wl = ir2.ndx.wl;
					uop[2].imm = {{23{ir2[7]}},ir2[7:0]};
					icount = 3'd2;
				end		
			default:
				uop[0] = {$bits(uop_t){1'b0}};
				uop[0].count = 3'd1;
			endcase
		end
	endcase
end
endtask
