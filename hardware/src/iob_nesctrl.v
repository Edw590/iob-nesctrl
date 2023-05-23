/*
 * file    iob_nesctrl
 * date    May 2023
 * 
 * brief   Physical interface for 2 Nintendo NES controllers based on HEF4021B
*/
`timescale 1ns/1ps

`include "iob_lib.vh"
`include "iob_nesctrl_swreg_def.vh"

module iob_nesctrl # (
		parameter DATA_W = 32,        //PARAM & 32 & 64 & CPU data width
		parameter ADDR_W = `iob_nesctrl_swreg_ADDR_W 	//CPU address section width    
	) (
		//CPU interface
		`include "iob_s_if.vh"

		//additional inputs and outputs
		`IOB_INPUT(nesctrl_ctrl1_q7, 1),
		`IOB_INPUT(nesctrl_ctrl2_q7, 1),

		`IOB_OUTPUT(nesctrl_pl, 1),
		`IOB_OUTPUT(nesctrl_clk, 1),
		`IOB_OUTPUT(nesctrl_ctrl1_data, 16),
		`IOB_OUTPUT(nesctrl_ctrl2_data, 16),
		
		`include "iob_gen_if.vh"
	);

	//BLOCK Register File & Configuration control and status register file.
	`include "iob_nesctrl_swreg_gen.vh"

	reg ctrl1_q7;
	reg ctrl2_q7;
	reg pl;
	reg slow_clk;
	reg [5-1:0] q_counter;
	reg [9-1:0] clk_counter;
	reg [16-1:0] ctrl1_data;
	reg [16-1:0] ctrl2_data;

	// 2-5 MHz are the maximum clock frequencies for the HEF4021B for 3 V (possibly). The maximum delay for 3 V, I'm
	// supposing to be the double of the maximum for 5 V, so that's 250*2 = 500 ns. 500 ns = 2 MHz. To remove any noise
	// and delay, we can divide by 10 and get 200 kHz. 1/100 Mhz = 1e-8 s = 10 ns. 200 kHz = 1/200 kHz = 5e-6 s =
	// 5000 ns. 5000 ns / 10 ns = 500 (each 500 pulses). This is for the whole signal though. So we need to divide by 2
	// to get the correct frequency (edge frequency, compared to the 100 MHz main one): 500 / 2 = 250.
	localparam EACH_X_EDGES = 250;
	// 20 to have 1/2 of the time for the data to be read, while the remaining 1/2 is for the data to be wrote.
	localparam Q_COUNTER_MAX = 20;

	assign ctrl1_q7 = nesctrl_ctrl1_q7;
	assign ctrl2_q7 = nesctrl_ctrl2_q7;

	initial begin
		pl = 1'b0;
		slow_clk = 1'b0;
		q_counter = 5'd0;
		clk_counter = 9'd0;
		ctrl1_data = 16'd0;
		ctrl2_data = 16'd0;
	end

	//////////////////////////////////////////////
	// Slow 200 kHz clock generation

	`IOB_MODCNT_R(clk, rst, 0, clk_counter, EACH_X_EDGES)
	`IOB_REG_R(clk, 0 == clk_counter, ~slow_clk, slow_clk, slow_clk)

	//////////////////////////////////////////////
	// Q counter and data gathering, with the slow clock

	`IOB_COUNTER_R(slow_clk, Q_COUNTER_MAX == q_counter, q_counter)
	`IOB_REG_R(slow_clk, Q_COUNTER_MAX == q_counter || q_counter < 9, 1'b1, pl, 1'b0)
	`IOB_COMB begin
		if (0 == q_counter) begin
			ctrl1_data = 16'd0;
			ctrl2_data = 16'd0;
		end else if (q_counter < 9) begin
			// Invert the bit since 1 means not being pressed, and vice-versa (datasheet)
			ctrl1_data = ctrl1_q7 == 1'b1 ? ctrl1_data & ~(1'b1 << (q_counter - 1)) : ctrl1_data | (1'b1 << (q_counter - 1));
			ctrl2_data = ctrl2_q7 == 1'b1 ? ctrl1_data & ~(1'b1 << (q_counter - 1)) : ctrl1_data | (1'b1 << (q_counter - 1));
		end else if (10 == q_counter) begin
			ctrl1_data = ctrl1_data | (1'b1 << 8);
			ctrl2_data = ctrl2_data | (1'b1 << 8);
		end
	end


	// Read controller data
	assign NESCTRL_CTRL1_DATA_rdata = ctrl1_data;
	assign NESCTRL_CTRL2_DATA_rdata = ctrl2_data;

	// Outputs
	assign nesctrl_ctrl1_data = ctrl1_data;
	assign nesctrl_ctrl2_data = ctrl2_data;
	assign nesctrl_pl = pl;
	assign nesctrl_clk = ~slow_clk; // Invert the clock to have a delay of 1/2 clock cycle

endmodule // iob_nesctrl
