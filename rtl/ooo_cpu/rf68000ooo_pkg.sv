package rf68000ooo_pkg;

typedef enum logic [5:0] {
	UPD_NONE = 6'd0,
	UPD_ALL,
	UPD_BCD,
	UPD_MUL,
	UPD_TST,
	UPD_ADDX,
	UPD_SUBX,
	UPD_CMP,
	UPD_ADD,
	UPD_SUB,
	UPD_LOGIC,
	UPD_ADDQ,
	UPD_SUBQ,
	UPD_ADDI,
	UPD_ANDI_CCR,
	UPD_ORI_CCR,
	UPD_EORI_CCR,
	UPD_ANDI_SR,
	UPD_EORI_SR,
	UPD_ORI_SR,
	UPD_ANDI_SRX,
	UPD_EORI_SRX,
	UPD_ORI_SRX,
	UPD_MOVE2CCR,
	UPD_MOVE2SR,
	UPD_MOVE2SRX,
	UPD_MOVE,
	UPD_NEG,
	UPD_NEGX,
	UPD_CLR,
	UPD_STOP,
	UPD_RTE,
	UPD_RTR,
	UPD_CHK,
	UPD_AS,
	UPD_LS,
	UPD_ROX,
	UPD_RO
} updpat_e;

typedef struct packed
{
	logic [2:0] count;
	logic [2:0] num;
	logic flgdep;					// 1=depencency on flags
	updpat_e updpat;			// update pattern
	logic [31:0] imm;
	logic Rs2wl;
	logic [4:0] Rs2;
	logic [4:0] Rs1;
	logic [4:0] Rsd;
	logic [6:0] opcode;
} uop_t;

endpackage
