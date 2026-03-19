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

endpackage
