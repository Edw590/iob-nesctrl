/*
 * file    iob_nesctrl
 * date    May 2023
 * 
 * brief   Physical interface for 2 Nintendo NES controllers
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
		`IOB_OUTPUT(nesctrl_ctrl1_data, 16),
		`IOB_OUTPUT(nesctrl_ctrl2_data, 16),
		
		`include "iob_gen_if.vh"
	);

	//BLOCK Register File & Configuration control and status register file.
	`include "iob_nesctrl_swreg_gen.vh"

	reg ctrl1_q7;
	reg ctrl2_q7;
	reg pl;
	reg count_rst;
	reg [4-1:0] counter;
	reg [16-1:0] ctrl1_data;
	reg [16-1:0] ctrl2_data;

	initial begin
		ctrl1_q7 <= 1'b0;
		ctrl2_q7 <= 1'b0;
		pl <= 1'b0;
		count_rst <= 1'b0;
		counter <= 4'd0;
		ctrl1_data <= 16'd0;
		ctrl2_data <= 16'd0;
	end

	`IOB_COUNTER_R(clk, count_rst, counter)

	always @(posedge clk) begin
		if (9 == counter) begin
			count_rst <= 1'b1;
		end else begin
			if (10 == counter) begin
				pl <= 1'b1;
			end else begin
				pl <= 1'b0;
			end
			count_rst <= 1'b0;
		end

		if (counter < 10) begin
			ctrl1_data <= (ctrl1_data | (1'b1 << 10)) | (ctrl1_q7 << counter);
			ctrl2_data <= (ctrl2_data | (1'b1 << 10)) | (ctrl2_q7 << counter);
		end else begin
			ctrl1_data <= 16'd0;
			ctrl2_data <= 16'd0;
		end
	end


	// Read controller data
	assign NESCTRL_CTRL1_DATA_rdata = ctrl1_data;
	assign NESCTRL_CTRL2_DATA_rdata = ctrl2_data;

	// Outputs
	assign nesctrl_ctrl1_data = ctrl1_data;
	assign nesctrl_ctrl2_data = ctrl2_data;
	assign nesctrl_pl = pl;

endmodule // iob_nesctrl
