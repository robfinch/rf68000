package rf68000_pkg;

typedef struct packed
{
	logic [31:0] userdat;	// user data
	logic [31:0] resv;		// reserved area
	logic [31:0] datptr;	// data area pointer
	logic [31:0] ewptr;		// entry word pointer
	logic [2:0] opt;
	logic [4:0] typ;
	logic [7:0] al;				// access level
	logic [15:0] zero;
} mod_desc_t;						// 5x32 bits

typedef struct packed
{
	logic da;							// data (0) or address (1) register
	logic [14:12] rg;			// register
	logic [11:0] zero;		// must be zero
} mod_entry_word_t;

typedef struct packed
{
	logic [31:0] datptr;
	logic [31:0] pc;
	logic [31:0] modptr;	//  module descriptor pointer
	logic [15:0] resv;
	logic [7:0] zero2;
	logic [7:0] argcnt;
	logic [7:0] zero1;
	logic [7:0] ccr;
	logic [2:0] opt;
	logic [4:0] typ;
	logic [7:0] al;				// access level
} mod_stack_frame_t;		// 5x32 bits

typedef enum logic [5:0] {
	FU_NONE = 6'd0,
	FU_MOVE, FU_MUL, FU_SHIFT, FU_SHIFT1,
	FU_TST, FU_ADDX, FU_SUBX, FU_NEGX,
	FU_CMP, FU_ADD, FU_SUB, FU_LOGIC, FU_ADDQ, FU_SUBQ,
	FU_ADDI, FU_ANDI_CCR, FU_ANDI_SR, FU_EORI_CCR,
	FU_ANDI_SRX, FU_EORI_SRX, FU_ORI_SRX, FU_MOVE2SRX,
	FU_EORI_SR, FU_ORI_CCR, FU_ORI_SR, FU_MOVE2CCR,
	FU_MOVE2SR, FU_MOVEQ, FU_CLR, FU_EXT, FU_SWAP, FU_CAS, FU_CASO,
	FU_BCD, FU_STOP, FU_DIV, FU_TAS, FU_BTST, FU_RTE,
	FU_BITFLD, FU_BIN2BCD
} flag_update_e;

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

endpackage
