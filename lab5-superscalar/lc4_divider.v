/* TODO: INSERT NAME AND PENNKEY HERE */
// Matt Tang
// mattang

`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);
    wire [15:0] div_tmp [16:0];
    wire [15:0] r_tmp [16:0];
    wire [15:0] q_tmp [16:0];
    
    assign div_tmp[0] = i_dividend;
    assign r_tmp[0] = 16'd0;
    assign q_tmp[0] = 16'd0;

    genvar i;
    for (i = 0; i < 16; i = i + 1) begin
        lc4_divider_one_iter d0(.i_dividend(div_tmp[i]), .i_divisor(i_divisor), .i_remainder(r_tmp[i]), .i_quotient(q_tmp[i]), .o_dividend(div_tmp[i + 1]), .o_remainder(r_tmp[i + 1]), .o_quotient(q_tmp[i + 1]));
    end

    assign o_remainder = r_tmp[16];
    assign o_quotient = q_tmp[16];


      /*** YOUR CODE HERE ***/

endmodule // lc4_divider

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);
    wire [15:0] dividend_left;
    assign dividend_left = i_dividend << 4'd1;
    assign o_dividend = dividend_left;

    wire [15:0] dividend_right;
    assign dividend_right = i_dividend >> 4'd15;
    
    wire [15:0] remainder;
    assign remainder = dividend_right | i_remainder << 4'd1;

    wire [15:0] is_greater;
    assign is_greater = remainder >= i_divisor;

    wire [15:0] temp_quotient = i_quotient << 4'd1 | is_greater;

    wire [15:0] diff = remainder - i_divisor;
    wire[15:0] temp_remainder = is_greater ? diff : remainder;

    assign o_quotient = i_divisor == 0 ? 16'd0 : temp_quotient;
    assign o_remainder = i_divisor == 0 ? 16'd0 : temp_remainder;

      /*** YOUR CODE HERE ***/

endmodule
