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
		`IOB_OUTPUT(nesctrl_pl2, 1),
		`IOB_OUTPUT(nesctrl_clk, 1),
		`IOB_OUTPUT(nesctrl_clk2, 1),
		`IOB_OUTPUT(nesctrl_ctrl2_data, 8),

		`include "iob_gen_if.vh"
	);

	//BLOCK Register File & Configuration control and status register file.
	`include "iob_nesctrl_swreg_gen.vh"

	wire ctrl1_q7;
	wire ctrl2_q7;
	reg pl;
	reg slow_clk;
	reg [5-1:0] q_counter;
	reg [32-1:0] clk_counter;

	assign ctrl1_q7 = nesctrl_ctrl1_q7;
	assign ctrl2_q7 = nesctrl_ctrl2_q7;

	`IOB_WIRE(CTRL1_DATA, 8)
    iob_reg #(.DATA_W(8))
    ctrl1_data (
        .clk        (clk),
        .arst       (rst),
        .rst        (rst),
        .en         (0 == clk_counter && q_counter < 8),
        .data_in    (ctrl1_q7 == 1'b1 ? CTRL1_DATA & ~(1'b1 << q_counter) : CTRL1_DATA | (1'b1 << q_counter)),
        .data_out   (CTRL1_DATA)
    );
	`IOB_WIRE(CTRL2_DATA, 8)
    iob_reg #(.DATA_W(8))
    ctrl2_data (
        .clk        (clk),
        .arst       (rst),
        .rst        (rst),
        .en         (0 == clk_counter && q_counter < 8),
        .data_in    (ctrl2_q7 == 1'b1 ? CTRL2_DATA & ~(1'b1 << q_counter) : CTRL2_DATA | (1'b1 << q_counter)),
        .data_out   (CTRL2_DATA)
    );

	//////////////////////////////////////////////
	// Slow 200 kHz clock generation

	// 2-5 MHz are the maximum clock frequencies for the HEF4021B for 3 V (possibly). The maximum delay for 3 V, I'm
	// supposing to be the double of the maximum for 5 V, so that's 250*2 = 500 ns. 500 ns = 2 MHz. To remove any noise
	// and delay, we can divide by 10 and get 200 kHz. 1/100 Mhz = 1e-8 s = 10 ns. 200 kHz = 1/200 kHz = 5e-6 s =
	// 5000 ns. 5000 ns / 10 ns = 500 (each 500 clocks).
	localparam EACH_X_CLOCKS = 500;

	`IOB_MODCNT_R(clk, rst, 0, clk_counter, EACH_X_CLOCKS)
	// The slow clock is generated by checking if 0 or X_CLOCKS/2 edges are reached.
	`IOB_REG_ARR(clk, rst, 0, (0 == clk_counter) || (EACH_X_CLOCKS/2 == clk_counter), ~slow_clk, slow_clk, slow_clk)

	//////////////////////////////////////////////
	// Q counter and data gathering, with the slow clock

	// 10 to be just a bit after all the 8 bits having been received
	`IOB_MODCNT_ARE(clk, rst, 0, 0 == clk_counter, q_counter, 10+1)
	`IOB_REG_RE(clk, 0 == q_counter, 1'b1, 1 == q_counter, pl, 1'b0)


	// Read controller data
	assign NESCTRL_CTRL1_DATA_rdata = CTRL1_DATA;
	assign NESCTRL_CTRL2_DATA_rdata = CTRL2_DATA;

	// Outputs
	assign nesctrl_ctrl2_data = CTRL2_DATA;
	assign nesctrl_pl = pl;
	assign nesctrl_pl2 = pl;
	assign nesctrl_clk = q_counter > 0 && q_counter < 8 ? ~slow_clk : 1'b0; // Invert the clock to have a delay of 1/2 clock cycle
	assign nesctrl_clk2 = q_counter > 0 && q_counter < 8 ? ~slow_clk : 1'b0; // Invert the clock to have a delay of 1/2 clock cycle

endmodule // iob_nesctrl
