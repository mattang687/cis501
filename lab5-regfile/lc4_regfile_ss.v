`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

   /*** TODO: Your Code Here ***/

   wire [15:0] r_out [7:0];
   wire [15:0] r_out_bypass [7:0];
   wire [15:0] ab_dat [7:0];
   wire we [7:0];
   
   genvar i;
   for (i = 0; i < 8; i = i + 1) begin
        assign ab_dat[i] = i_rd_B == i && i_rd_we_B ? i_wdata_B : i_wdata_A;
        assign we[i] = (i_rd_B == i && i_rd_we_B) || (i_rd_A == i && i_rd_we_A);
        Nbit_reg #(16, 16'd0) reg0 (.in(ab_dat[i]), .out(r_out[i]), .clk(clk), .we(we[i]), .gwe(gwe), .rst(rst));
        assign r_out_bypass[i] = we[i] ? ab_dat[i] : r_out[i];
   end
   
   assign o_rs_data_A = i_rs_A == 3'd0 ? r_out_bypass[0] : i_rs_A == 3'd1 ? r_out_bypass[1] : i_rs_A == 3'd2 ? r_out_bypass[2] : i_rs_A == 3'd3 ? r_out_bypass[3] : i_rs_A == 3'd4 ? r_out_bypass[4] : i_rs_A == 3'd5 ? r_out_bypass[5] : i_rs_A == 3'd6 ? r_out_bypass[6] : r_out_bypass[7];

   assign o_rt_data_A = i_rt_A == 3'd0 ? r_out_bypass[0] : i_rt_A == 3'd1 ? r_out_bypass[1] : i_rt_A == 3'd2 ? r_out_bypass[2] : i_rt_A == 3'd3 ? r_out_bypass[3] : i_rt_A == 3'd4 ? r_out_bypass[4] : i_rt_A == 3'd5 ? r_out_bypass[5] : i_rt_A == 3'd6 ? r_out_bypass[6] : r_out_bypass[7];

   assign o_rs_data_B = i_rs_B == 3'd0 ? r_out_bypass[0] : i_rs_B == 3'd1 ? r_out_bypass[1] : i_rs_B == 3'd2 ? r_out_bypass[2] : i_rs_B == 3'd3 ? r_out_bypass[3] : i_rs_B == 3'd4 ? r_out_bypass[4] : i_rs_B == 3'd5 ? r_out_bypass[5] : i_rs_B == 3'd6 ? r_out_bypass[6] : r_out_bypass[7];

   assign o_rt_data_B = i_rt_B == 3'd0 ? r_out_bypass[0] : i_rt_B == 3'd1 ? r_out_bypass[1] : i_rt_B == 3'd2 ? r_out_bypass[2] : i_rt_B == 3'd3 ? r_out_bypass[3] : i_rt_B == 3'd4 ? r_out_bypass[4] : i_rt_B == 3'd5 ? r_out_bypass[5] : i_rt_B == 3'd6 ? r_out_bypass[6] : r_out_bypass[7];


endmodule
