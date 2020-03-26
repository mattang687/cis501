/* TODO: INSERT NAME AND PENNKEY HERE */
// Matt Tang, mattang

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals 
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits collectively generate a carry (ignoring cin)
 * @param pout whether these 4 bits collectively would propagate an incoming carry (ignoring cin)
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);
   
    assign pout = &pin;
    wire [3:0] g_tmp;
    
    assign g_tmp[0] = cin & pin[0];
    assign cout[0] = gin[0] | g_tmp[0];

    assign g_tmp[1] = cout[0] & pin[1];
    assign cout[1] = gin[1] | g_tmp[1];

    assign g_tmp[2] = cout[1] & pin[2];
    assign cout[2] = gin[2] | g_tmp[2];

    wire [3:0] gout_tmp;
    assign gout_tmp[3] = gin[3];
    assign gout_tmp[2] = gin[2] & pin[3];
    assign gout_tmp[1] = gin[1] & pin[2] & pin[3];
    assign gout_tmp[0] = gin[0] & pin[1] & pin[2] & pin[3];
    assign gout = |gout_tmp;

endmodule

/**
 * 16-bit Carry-Lookahead Adder
 * @param a first input
 * @param b second input
 * @param cin carry in
 * @param sum sum of a + b + carry-in
 */
module cla16
  (input wire [15:0]  a, b,
   input wire         cin,
   output wire [15:0] sum);

    wire [15:0] c;
    assign c[0] = cin;

    wire [15:0] g0;
    wire [15:0] p0;
    
    genvar i;
    for (i = 0; i < 16; i = i + 1) begin
        gp1 my_gp1(.a(a[i]), .b(b[i]), .g(g0[i]), .p(p0[i]));
    end

    wire [3: 0] g1;
    wire [3: 0] p1;

    gp4 my_gp4_0(.gin(g0[3:0]), .pin(p0[3:0]), .cin(cin), .gout(g1[0]), .pout(p1[0]), .cout(c[3:1]));
    gp4 my_gp4_1(.gin(g0[7:4]), .pin(p0[7:4]), .cin(c[4]), .gout(g1[1]), .pout(p1[1]), .cout(c[7:5]));
    gp4 my_gp4_2(.gin(g0[11:8]), .pin(p0[11:8]), .cin(c[8]), .gout(g1[2]), .pout(p1[2]), .cout(c[11:9]));
    gp4 my_gp4_3(.gin(g0[15:12]), .pin(p0[15:12]), .cin(c[12]), .gout(g1[3]), .pout(p1[3]), .cout(c[15:13]));

    gp4 big_gp4(.gin(g1), .pin(p1), .cin(cin), .gout(), .pout(), .cout({c[12], c[8], c[4]}));

    assign sum = a ^ b ^ c;

endmodule


/** Lab 2 Extra Credit, see details at
  https://github.com/upenn-acg/cis501/blob/master/lab2-alu/lab2-cla.md#extra-credit
 If you are not doing the extra credit, you should leave this module empty.
 */
module gpn
  #(parameter N = 4)
  (input wire [N-1:0] gin, pin,
   input wire  cin,
   output wire gout, pout,
   output wire [N-2:0] cout);
 
endmodule
