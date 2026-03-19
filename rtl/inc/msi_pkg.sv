package msi_pkg;

typedef struct packed
{
	logic [31:0] resv5;
	logic [15:0] resv4;
	logic [7:0] cpu_affinity_group;
	logic [2:0] resv3;
	logic [2:0] swstk;		// software stack required
	logic ie;							// 1=interrupt enabled
	logic resv2;					// reserved
	logic [31:0] resv1;		// reserved
	logic [31:0] adr;			// ISR address or
} msi_vec_t;						// 128 bits

typedef struct packed
{
	logic [23:0] timestamp;
	logic [15:0] msg;
} irq_hist_t;

endpackage
