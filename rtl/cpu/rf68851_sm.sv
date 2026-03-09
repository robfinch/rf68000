// State machine for PMMU table walking.

import rf68851_pkg::*;

module rf68851_sm(rst, clk, pmmu_en, pmmu_tc, atc_hit, ack, prev_desc_type, desc,
	pload, ptest, ptest_lvl, pmmu_state);
input rst;
input clk;
input pmmu_en;
input pmmu_trans_ctrl_t pmmu_tc;
input atc_hit;
input ack;
input pmmu_desc_t prev_desc_type;
input [63:0] desc;
input pload;
input ptest;
input [2:0] ptest_lvl;
output reg [19:0] pmmu_state;

// PMMU access state machine
always_ff @(posedge clk)
if (rst) begin
	pmmu_state <= 20'd0;
	pmmu_state[PMMU_WAIT_MISS] <= 1'b1;
end
else begin
	pmmu_state <= 20'd0;
	case(1'b1)

	pmmu_state[PMMU_WAIT_MISS]:
		if (!atc_hit && pmmu_en)
			pmmu_state[PMMU_WAIT_ACK_A] <= 1'b1;
		else
			pmmu_state[PMMU_WAIT_MISS] <= 1'b1;

	pmmu_state[PMMU_WAIT_ACK_A]:
		if (ack) begin
			if (prev_desc_type==PMMU_LONG_DESC)
				pmmu_state[PMMU_ACCESS_AL] <= 1'b1;
			else if (ptest && ptest_lvl==3'd1)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else if (pmmu_tc.B==4'd0)
				pmmu_state[PMMU_ATC_UPDATE] <= 1'b1;
			else
				pmmu_state[PMMU_ACCESS_B] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_A] <= 1'b1;

	pmmu_state[PMMU_ACCESS_AL]:
		pmmu_state[PMMU_WAIT_ACK_AL] <= 1'b1;

	pmmu_state[PMMU_WAIT_ACK_AL]:
		if (ack) begin
			if (ptest && ptest_lvl==3'd1)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else if (pmmu_tc.B==4'd0)
				pmmu_state[PMMU_ATC_UPDATE] <= 1'b1;
			else
				pmmu_state[PMMU_ACCESS_B] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_AL] <= 1'b1;

	pmmu_state[PMMU_ACCESS_B]:
		if (prev_desc_type==2'd0) begin
			if (ptest)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else				
				pmmu_state[PMMU_WAIT_MISS] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_B] <= 1'b1;

	pmmu_state[PMMU_WAIT_ACK_B]:
		if (ack) begin
			if (prev_desc_type==PMMU_LONG_DESC)
				pmmu_state[PMMU_ACCESS_BL] <= 1'b1;
			else if (ptest && ptest_lvl==3'd2)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else if (pmmu_tc.C==4'd0)
				pmmu_state[PMMU_ATC_UPDATE] <= 1'b1;
			else
				pmmu_state[PMMU_ACCESS_C] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_B] <= 1'b1;

	pmmu_state[PMMU_ACCESS_BL]:
		pmmu_state[PMMU_WAIT_ACK_BL] <= 1'b1;

	pmmu_state[PMMU_WAIT_ACK_BL]:
		if (ack) begin
			if (ptest && ptest_lvl==3'd2)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else if (pmmu_tc.C==4'd0)
				pmmu_state[PMMU_ATC_UPDATE] <= 1'b1;
			else
				pmmu_state[PMMU_ACCESS_C] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_BL] <= 1'b1;

	pmmu_state[PMMU_ACCESS_C]:
		if (prev_desc_type==2'd0) begin
			if (ptest)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else				
				pmmu_state[PMMU_WAIT_MISS] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_C] <= 1'b1;

	pmmu_state[PMMU_WAIT_ACK_C]:
		if (ack) begin
			if (prev_desc_type==PMMU_LONG_DESC)
				pmmu_state[PMMU_ACCESS_CL] <= 1'b1;
			else if (ptest && ptest_lvl==3'd3)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else if (pmmu_tc.D==4'd0)
				pmmu_state[PMMU_ATC_UPDATE] <= 1'b1;
			else
				pmmu_state[PMMU_ACCESS_D] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_C] <= 1'b1;

	pmmu_state[PMMU_ACCESS_CL]:
		pmmu_state[PMMU_WAIT_ACK_CL] <= 1'b1;

	pmmu_state[PMMU_WAIT_ACK_CL]:
		if (ack) begin
			if (ptest && ptest_lvl==3'd3)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else if (pmmu_tc.D==4'd0)
				pmmu_state[PMMU_ATC_UPDATE] <= 1'b1;
			else
				pmmu_state[PMMU_ACCESS_D] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_CL] <= 1'b1;

	pmmu_state[PMMU_ACCESS_D]:
		if (prev_desc_type==2'd0) begin
			if (ptest)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else				
				pmmu_state[PMMU_WAIT_MISS] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_D] <= 1'b1;

	pmmu_state[PMMU_WAIT_ACK_D]:
		if (ack) begin
			if (prev_desc_type==PMMU_LONG_DESC)
				pmmu_state[PMMU_ACCESS_DL] <= 1'b1;
			else if (ptest && ptest_lvl==3'd4)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else
				pmmu_state[PMMU_ATC_UPDATE] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_D] <= 1'b1;

	pmmu_state[PMMU_ACCESS_DL]:
		pmmu_state[PMMU_WAIT_ACK_DL] <= 1'b1;

	pmmu_state[PMMU_WAIT_ACK_DL]:
		if (ack) begin
			if (ptest && ptest_lvl==3'd4)
				pmmu_state[PMMU_PTEST] <= 1'b1;
			else
				pmmu_state[PMMU_ATC_UPDATE] <= 1'b1;
		end
		else
			pmmu_state[PMMU_WAIT_ACK_DL] <= 1'b1;

	pmmu_state[PMMU_ATC_UPDATE]:
		if (|desc[33:32] & pload)
			pmmu_state[PMMU_PTE_UPDATE] <= 1'b1;
		else
			pmmu_state[PMMU_WAIT_MISS] <= 1'b1;
		
	pmmu_state[PMMU_PTE_UPDATE]:
		pmmu_state[PMMU_PTE_ACK] <= 1'b1;
		
	pmmu_state[PMMU_PTE_ACK]:
		if (ack)
			pmmu_state[PMMU_WAIT_MISS] <= 1'b1;
		else
			pmmu_state[PMMU_PTE_ACK] <= 1'b1;
			
	pmmu_state[PMMU_PTEST]:
		pmmu_state[PMMU_WAIT_MISS] <= 1'b1;

	default:
		pmmu_state[PMMU_WAIT_MISS] <= 1'b1;
		
	endcase
end

endmodule
