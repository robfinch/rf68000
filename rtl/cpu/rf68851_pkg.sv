package rf68851_pkg;

typedef enum logic [4:0] {
	PMMU_WAIT_MISS = 0,
	PMMU_WAIT_ACK_A,
	PMMU_ACCESS_AL,
	PMMU_WAIT_ACK_AL,
	PMMU_ACCESS_B,
	PMMU_WAIT_ACK_B,
	PMMU_ACCESS_BL,
	PMMU_WAIT_ACK_BL,
	PMMU_ACCESS_C,
	PMMU_WAIT_ACK_C,
	PMMU_ACCESS_CL,
	PMMU_WAIT_ACK_CL,
	PMMU_ACCESS_D,
	PMMU_WAIT_ACK_D,
	PMMU_ACCESS_DL,
	PMMU_WAIT_ACK_DL,
	PMMU_ATC_UPDATE,
	PMMU_PTE_UPDATE,
	PMMU_PTE_ACK,
	PMMU_PTEST
} pmmu_state_t;

typedef enum logic [1:0] 
{
	PMMU_INVALID_DESC = 2'd0,
	PMMU_PAGE_DESC = 2'd1,
	PMMU_SHORT_DESC = 2'd2,
	PMMU_LONG_DESC = 2'd3
} pmmu_desc_t;

typedef struct packed
{
	logic [31:4] ta;		// table address
	logic u;						// used (accessed)
	logic wp;						// write protect
	pmmu_desc_t dt;			// descriptor type
} SFT_desc_t;		// Short Format Table descriptor

typedef struct packed
{
	logic lu;						// lower/upper limit indicator
	logic [14:0] limit;	// limit
	logic [2:0] ral;		// read access level
	logic [2:0] wal;		// write access level
	logic sg;						// global
	logic s;						// supervisor
	logic [3:0] zero;
	logic u;						// used (accessed)
	logic wp;						// write protect
	pmmu_desc_t dt;			// descriptor type
	logic [27:0] ta;		// table address
	logic [3:0] resv;
} LFT_desc_t;		// Long Format Table descriptor

typedef struct packed
{
	logic [31:8] pa;		// page address
	logic g;						// can contain gate
	logic ci;						// cache inhibit
	logic l;						// locked
	logic m;						// modified
	logic u;						// used (accessed)
	logic wp;						// write protect
	pmmu_desc_t dt;			// descriptor type
} SFP_desc_t;		// Short Format Page descriptor

typedef struct packed
{
	logic [15:0] resv2;	// unused
	logic [2:0] ral;		// read access level
	logic [2:0] wal;		// write access level
	logic sg;						// global
	logic s;						// supervisor
	logic g;						// can contain gate
	logic ci;						// cache inhibit
	logic l;						// locked
	logic m;						// modified
	logic u;						// used (accessed)
	logic wp;						// write protect
	pmmu_desc_t dt;			// descriptor type
	logic [31:8] pa;		// page address
	logic [7:0] resv1;	// unused
} LF1P_desc_t;		// Long Format1 Page descriptor

typedef struct packed
{
	logic lu;						// lower/upper limit indicator
	logic [14:0] limit;	// limit
	logic [2:0] ral;		// read access level
	logic [2:0] wal;		// write access level
	logic sg;						// global
	logic s;						// supervisor
	logic g;						// can contain gate
	logic ci;						// cache inhibit
	logic l;						// locked
	logic m;						// modified
	logic u;						// used (accessed)
	logic wp;						// write protect
	pmmu_desc_t dt;			// descriptor type
	logic [31:8] pa;		// page address
	logic [7:0] resv1;	// unused
} LF2P_desc_t;		// Long Format2 Page descriptor

typedef struct packed
{
	logic [31:2] da;		// descriptor address
	pmmu_desc_t dt;			// descriptor type
} SFI_desc_t;			// Short Format Indirect descriptor

typedef struct packed
{
	logic [31:2] resv2;	// unused
	pmmu_desc_t dt;			// descriptor type
	logic [31:2] da;		// descriptor address
	logic [1:0] resv1;		// unused
} LFI_desc_t;			// Long Format Indirect descriptor

typedef struct packed
{
	logic [31:2] resv;	// unused
	pmmu_desc_t dt;			// descriptor type
} SFInv_desc_t;			// Short Format Invalid descriptor

typedef struct packed
{
	logic [31:2] resv2;	// unused
	pmmu_desc_t dt;			// descriptor type
	logic [31:0] resv1;	// unused
} LFInv_desc_t;			// Long Format Invalid descriptor

typedef struct packed
{
  logic [23:0] ppn;
  logic resv;
	logic p;
	logic m;
	logic a;
	logic s;
	logic r;
	logic w;
	logic x;
} pte_t;

typedef struct packed
{
	logic v;						// valid bit
	logic berr;					// bus error occurred
	logic [2:0] func;		// function code
//	logic [15:0] appid;
	logic [2:0] ta;			// task alias
	logic [23:0] vpn;		// virtual page number
	LF2P_desc_t desc;		// room for long descriptor
} atc_entry_t;

typedef struct packed
{
	logic E;
	logic [4:0] zero;
	logic SRE;
	logic FCL;
	logic [3:0] PS;
	logic [3:0] IS;
	logic [3:0] A;
	logic [3:0] B;
	logic [3:0] C;
	logic [3:0] D;
} pmmu_trans_ctrl_t;

typedef struct packed
{
	logic [4:0] resv;
	logic [2:0] N;
	logic M;
	logic C;
	logic G;
	logic I;
	logic W;
	logic A;
	logic S;
	logic L;
	logic B;
} pmmu_stat_t;

typedef struct packed
{
	logic [4:0] resv;
	logic MC;
	logic [2:0] ALC;
} pmmu_acr_t;

typedef struct packed
{
	logic bpe;
	logic [6:0] resv;
	logic [7:0] skip;
} pmmu_bac_t;

endpackage
