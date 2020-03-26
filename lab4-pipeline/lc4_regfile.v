/* TODO: Names of all group members
 * TODO: PennKeys of all group members
 * Matt Tang, mattang
 *
 * lc4_regfile.v
 * Implements an 8-register register file parameterized on word size.
 *
 */

`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_regfile #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,
    input  wire [  2:0] i_rs,      // rs selector
    output wire [n-1:0] o_rs_data, // rs contents
    input  wire [  2:0] i_rt,      // rt selector
    output wire [n-1:0] o_rt_data, // rt contents
    input  wire [  2:0] i_rd,      // rd selector
    input  wire [n-1:0] i_wdata,   // data to write
    input  wire         i_rd_we    // write enable
    );

   /***********************
    * TODO YOUR CODE HERE *
    ***********************/

   wire [15:0] r_out [7:0];
   
   genvar i;
   for (i = 0; i < 8; i = i + 1) begin
        Nbit_reg #(16, 16'd0) reg0 (.in(i_wdata), .out(r_out[i]), .clk(clk), .we((i_rd == i) && i_rd_we), .gwe(gwe), .rst(rst));
   end
   
   assign o_rs_data = i_rs == 3'd0 ? r_out[0] : i_rs == 3'd1 ? r_out[1] : i_rs == 3'd2 ? r_out[2] : i_rs == 3'd3 ? r_out[3] : i_rs == 3'd4 ? r_out[4] : i_rs == 3'd5 ? r_out[5] : i_rs == 3'd6 ? r_out[6] : r_out[7];

   assign o_rt_data = i_rt == 3'd0 ? r_out[0] : i_rt == 3'd1 ? r_out[1] : i_rt == 3'd2 ? r_out[2] : i_rt == 3'd3 ? r_out[3] : i_rt == 3'd4 ? r_out[4] : i_rt == 3'd5 ? r_out[5] : i_rt == 3'd6 ? r_out[6] : r_out[7];

endmodule
