`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );

   /***  YOUR CODE HERE ***/


   wire [15:0] mispredict_pc_out;
   wire stall_b;
   wire stall_a;
// F stage

   wire [15:0] f_next_pc;
   wire [15:0] f_pc;
   wire f_pc_reg_we;
   wire [15:0] f_pc_plus_one;
   wire [15:0] f_pc_plus_two;
   wire [15:0] f_pc_plus_three;

   wire is_mispredict;

   assign f_pc_reg_we = !stall_a; // stall pc reg only if a stalls (causing both to stall)

   assign f_next_pc = is_mispredict ? mispredict_pc_out : stall_b && !stall_a ?  f_pc_plus_one : f_pc_plus_two;

   Nbit_reg #(16, 16'h8200) f_pc_reg(.in(f_next_pc), .out(f_pc), .clk(clk), .we(f_pc_reg_we), .gwe(gwe), .rst(rst));

   cla16 f_pc_incr_1(.a(f_pc), .b(16'd1), .cin(1'd0), .sum(f_pc_plus_one));
   cla16 f_pc_incr_2(.a(f_pc), .b(16'd2), .cin(1'd0), .sum(f_pc_plus_two));
   cla16 f_pc_incr_3(.a(f_pc), .b(16'd3), .cin(1'd0), .sum(f_pc_plus_three));

   assign o_cur_pc = f_pc;
   
   wire [1:0] f_stall_signal = is_mispredict ? 2'd2 : 0;
   wire [1:0] d_stall_signal_in_a;
   wire [1:0] d_stall_signal_in_b;
   Nbit_reg #(2, 16'd2) f_stall_reg_a(.in(f_stall_signal), .out(d_stall_signal_in_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 16'd2) f_stall_reg_b(.in(f_stall_signal), .out(d_stall_signal_in_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));


   // D stage

   // pipe a
   wire [15:0] d_pc_a;
   wire d_reg_we_a = !stall_a;
   wire d_ir_rst_a = is_mispredict || rst;

   Nbit_reg #(16, 16'h8200) d_pc_reg_a(.in(f_pc), .out(d_pc_a), .clk(clk), .we(d_reg_we_a), .gwe(gwe), .rst(rst));
   
   wire[15:0] d_pc_plus_one_a;
   Nbit_reg #(16, 16'h8200) d_pc_plus_one_reg_a(.in(f_pc_plus_one), .out(d_pc_plus_one_a), .clk(clk), .we(d_reg_we_a), .gwe(gwe), .rst(rst));

   wire [15:0] d_ir_a;
   
   Nbit_reg #(16, 16'd0) d_ir_reg_a(.in(i_cur_insn_A), .out(d_ir_a), .clk(clk), .we(d_reg_we_a), .gwe(gwe), .rst(d_ir_rst_a));

   wire [2:0] d_r1sel_a;
   wire d_r1re_a;
   wire [2:0] d_r2sel_a;
   wire d_r2re_a;
   wire [2:0] d_rdsel_a;
   wire d_regfile_we_a;
   wire d_nzp_we_a;
   wire d_select_pc_plus_one_a;
   wire d_is_load_a;
   wire d_is_store_a;
   wire d_is_branch_a;
   wire d_is_control_a;

   lc4_decoder decoder_a(.insn(d_ir_a), .r1sel(d_r1sel_a), .r1re(d_r1re_a), .r2sel(d_r2sel_a), .r2re(d_r2re_a), .wsel(d_rdsel_a), .regfile_we(d_regfile_we_a), .nzp_we(d_nzp_we_a), .select_pc_plus_one(d_select_pc_plus_one_a), .is_load(d_is_load_a), .is_store(d_is_store_a), .is_branch(d_is_branch_a), .is_control_insn(d_is_control_a));

   wire [15:0] d_r1data_a;
   wire [15:0] d_r2data_a;

   // pipe b
   wire [15:0] d_pc_b;
   wire d_reg_we_b = !stall_b;
   wire d_ir_rst_b = is_mispredict || rst;

   Nbit_reg #(16, 16'h8200) d_pc_reg_b(.in(f_pc_plus_two), .out(d_pc_b), .clk(clk), .we(d_reg_we_b), .gwe(gwe), .rst(rst));
   
   wire[15:0] d_pc_plus_one_b;
   Nbit_reg #(16, 16'h8200) d_pc_plus_one_reg_b(.in(f_pc_plus_three), .out(d_pc_plus_one_b), .clk(clk), .we(d_reg_we_b), .gwe(gwe), .rst(rst));

   wire [15:0] d_ir_b;
   
   Nbit_reg #(16, 16'd0) d_ir_reg_b(.in(i_cur_insn_B), .out(d_ir_b), .clk(clk), .we(d_reg_we_b), .gwe(gwe), .rst(d_ir_rst_b));

   wire [2:0] d_r1sel_b;
   wire d_r1re_b;
   wire [2:0] d_r2sel_b;
   wire d_r2re_b;
   wire [2:0] d_rdsel_b;
   wire d_regfile_we_b;
   wire d_nzp_we_b;
   wire d_select_pc_plus_one_b;
   wire d_is_load_b;
   wire d_is_store_b;
   wire d_is_branch_b;
   wire d_is_control_b;

   lc4_decoder decoder_b(.insn(d_ir_b), .r1sel(d_r1sel_b), .r1re(d_r1re_b), .r2sel(d_r2sel_b), .r2re(d_r2re_b), .wsel(d_rdsel_b), .regfile_we(d_regfile_we_b), .nzp_we(d_nzp_we_b), .select_pc_plus_one(d_select_pc_plus_one_b), .is_load(d_is_load_b), .is_store(d_is_store_b), .is_branch(d_is_branch_b), .is_control_insn(d_is_control_b));

   wire [15:0] d_r1data_b;
   wire [15:0] d_r2data_b;

   lc4_regfile_ss regfile(.clk(clk), .gwe(gwe), .rst(rst), .i_rs_A(d_r1sel_a), .o_rs_data_A(d_r1data_a), .i_rt_A(d_r2sel_a), .o_rt_data_A(d_r2data_a), .i_rd_A(w_rdsel_a), .i_wdata_A(w_rddata_a), .i_rd_we_A(w_regfile_we_a), .i_rs_B(d_r1sel_b), .o_rs_data_B(d_r1data_b), .i_rt_B(d_r2sel_b), .o_rt_data_B(d_r2data_b), .i_rd_B(w_rdsel_b), .i_wdata_B(w_rddata_b), .i_rd_we_B(w_regfile_we_b));

   // WD bypass not necessary
   wire [2:0] w_rdsel_a;
   wire [15:0] w_rddata_a;
   
   wire [2:0] w_rdsel_b;
   wire [15:0] w_rddata_b;

   // dependencies
   wire is_load_use_a = x_is_load_a && x_stall_signal_a == 2'd0 &&
         (((((x_rdsel_a == d_r1sel_a) && d_r1re_a && x_regfile_we_a) || ((x_rdsel_a == d_r2sel_a) && d_r2re_a && x_regfile_we_a && !d_is_store_a)) || d_is_branch_a) ||
         ((((x_rdsel_b == d_r1sel_a) && d_r1re_a && x_regfile_we_b) || ((x_rdsel_b == d_r2sel_a) && d_r2re_a && x_regfile_we_b && !d_is_store_a)) || d_is_branch_a));
   wire is_load_use_b = x_is_load_b && x_stall_signal_b == 2'd0 &&
         (((((x_rdsel_b == d_r1sel_b) && d_r1re_b && x_regfile_we_b) || ((x_rdsel_b == d_r2sel_b) && d_r2re_b && x_regfile_we_b && !d_is_store_b)) || d_is_branch_b) ||
         ((((x_rdsel_a == d_r1sel_b) && d_r1re_b && x_regfile_we_a) || ((x_rdsel_a == d_r2sel_b) && d_r2re_b && x_regfile_we_a && !d_is_store_b)) || d_is_branch_b));
   wire has_dependence = d_stall_signal_a == 2'd0 && 
   ((((d_rdsel_a == d_r1sel_b) && d_r1re_b && d_regfile_we_a) || ((d_rdsel_a == d_r2sel_b) && d_r2re_b && d_regfile_we_a && !d_is_store_a)) || d_nzp_we_a && d_is_branch_b);
   wire dab_structural = (d_is_load_a || d_is_store_a) && (d_is_load_b || d_is_store_b);

   // stall signals
   wire [1:0] d_stall_signal_a = (d_stall_signal_in_a == 2'd2) ? 2'd2 : is_mispredict ? 2'd2 : is_load_use_a ? 2'd3 : 0;
   Nbit_reg #(2, 16'd2) d_stall_reg_a(.in(d_stall_signal_a), .out(x_stall_signal_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [1:0] d_stall_signal_b = (d_stall_signal_in_b == 2'd2) ? 2'd2 : is_mispredict ? 2'd2 : is_load_use_a ? 2'd1 : has_dependence || dab_structural ? 2'd1 : is_load_use_b ? 2'd3 : 0;
   Nbit_reg #(2, 16'd2) d_stall_reg_b(.in(d_stall_signal_b), .out(x_stall_signal_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   // TODO additional logic - checking middle ir
   assign stall_a = is_load_use_a;
   assign stall_b = is_load_use_a || is_load_use_b || has_dependence || dab_structural;

   wire switch_pipes = !stall_a && stall_b;

   // X stage
   
   // pipe a registers
   // PC reg
   wire [15:0] x_pc_a;
   Nbit_reg #(16, 16'h8200) x_pc_reg_a(.in(switch_pipes ? d_pc_b : d_pc_a), .out(x_pc_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   
   wire[15:0] x_pc_plus_one_a;
   Nbit_reg #(16, 16'h8200) x_pc_plus_one_reg_a(.in(switch_pipes ? d_pc_plus_one_b : d_pc_plus_one_a), .out(x_pc_plus_one_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire x_ir_rst_a = stall_a || is_mispredict || rst;
   wire [15:0] x_ir_a;
   Nbit_reg #(16, 16'd0) x_ir_reg_a(.in(switch_pipes ? d_ir_b : d_ir_a), .out(x_ir_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));

   // Data registers
   wire [15:0] x_r1data_a;
   Nbit_reg #(16, 16'd0) x_rs_data_a(.in(switch_pipes ? d_r1data_b : d_r1data_a), .out(x_r1data_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire [15:0] x_r2data_a;
   Nbit_reg #(16, 16'd0) x_rt_data_a(.in(switch_pipes ? d_r2data_b : d_r2data_a), .out(x_r2data_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] x_r1sel_a;
   Nbit_reg #(3, 3'd0) x_r1sel_reg_a(.in(switch_pipes ? d_r1sel_b : d_r1sel_a), .out(x_r1sel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_r1re_a;
   Nbit_reg #(1, 1'd0) x_r1re_reg_a(.in(switch_pipes ? d_r1re_b : d_r1re_a), .out(x_r1re_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire [2:0] x_r2sel_a;
   Nbit_reg #(3, 3'd0) x_r2sel_reg_a(.in(switch_pipes ? d_r2sel_b : d_r2sel_a), .out(x_r2sel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_r2re_a;
   Nbit_reg #(1, 1'd0) x_r2re_reg_a(.in(switch_pipes ? d_r2re_b : d_r2re_a), .out(x_r2re_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire [2:0] x_rdsel_a;
   Nbit_reg #(3, 3'd0) x_rdsel_reg_a(.in(switch_pipes ? d_rdsel_b : d_rdsel_a), .out(x_rdsel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_regfile_we_a;
   Nbit_reg #(1, 1'd0) x_regfile_we_reg_a(.in(switch_pipes ? d_regfile_we_b : d_regfile_we_a), .out(x_regfile_we_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_nzp_we_a;
   Nbit_reg #(1, 1'd0) x_nzp_we_reg_a(.in(switch_pipes ? d_nzp_we_b : d_nzp_we_a), .out(x_nzp_we_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_select_pc_plus_one_a;
   Nbit_reg #(1, 1'd0) x_select_pc_reg_a(.in(switch_pipes ? d_select_pc_plus_one_b : d_select_pc_plus_one_a), .out(x_select_pc_plus_one_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_is_load_a;
   Nbit_reg #(1, 1'd0) x_is_load_reg_a(.in(switch_pipes ? d_is_load_b : d_is_load_a), .out(x_is_load_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_is_store_a;
   Nbit_reg #(1, 1'd0) x_is_store_reg_a(.in(switch_pipes ? d_is_store_b : d_is_store_a), .out(x_is_store_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_is_branch_a;
   Nbit_reg #(1, 1'd0) x_is_branch_reg_a(.in(switch_pipes ? d_is_branch_b : d_is_branch_a), .out(x_is_branch_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));
   wire x_is_control_a;
   Nbit_reg #(1, 1'd0) x_is_control_reg_a(.in(switch_pipes ? d_is_control_b : d_is_control_a), .out(x_is_control_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_a));

   // pipe b registers
   // PC reg
   wire [15:0] x_pc_b;
   Nbit_reg #(16, 16'h8200) x_pc_reg_b(.in(d_pc_b), .out(x_pc_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   
   wire[15:0] x_pc_plus_one_b;
   Nbit_reg #(16, 16'h8200) x_pc_plus_one_reg_b(.in(d_pc_plus_one_b), .out(x_pc_plus_one_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire x_ir_rst_b = stall_b || is_mispredict || rst;
   wire [15:0] x_ir_b;
   Nbit_reg #(16, 16'd0) x_ir_reg_b(.in(switch_pipes ? 16'd0 : d_ir_b), .out(x_ir_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));

   // Data registers
   wire [15:0] x_r1data_b;
   Nbit_reg #(16, 16'd0) x_rs_data_b(.in(switch_pipes ? 16'd0 : d_r1data_b), .out(x_r1data_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire [15:0] x_r2data_b;
   Nbit_reg #(16, 16'd0) x_rt_data_b(.in(switch_pipes ? 16'd0 : d_r2data_b), .out(x_r2data_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] x_r1sel_b;
   Nbit_reg #(3, 3'd0) x_r1sel_reg_b(.in(switch_pipes ? 3'd0 : d_r1sel_b), .out(x_r1sel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_r1re_b;
   Nbit_reg #(1, 1'd0) x_r1re_reg_b(.in(switch_pipes ? 1'd0 : d_r1re_b), .out(x_r1re_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire [2:0] x_r2sel_b;
   Nbit_reg #(3, 3'd0) x_r2sel_reg_b(.in(switch_pipes ? 3'd0 : d_r2sel_b), .out(x_r2sel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_r2re_b;
   Nbit_reg #(1, 1'd0) x_r2re_reg_b(.in(switch_pipes ? 1'd0 : d_r2re_b), .out(x_r2re_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire [2:0] x_rdsel_b;
   Nbit_reg #(3, 3'd0) x_rdsel_reg_b(.in(switch_pipes ? 3'd0 : d_rdsel_b), .out(x_rdsel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_regfile_we_b;
   Nbit_reg #(1, 1'd0) x_regfile_we_reg_b(.in(switch_pipes ? 1'd0 : d_regfile_we_b), .out(x_regfile_we_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_nzp_we_b;
   Nbit_reg #(1, 1'd0) x_nzp_we_reg_b(.in(switch_pipes ? 1'd0 : d_nzp_we_b), .out(x_nzp_we_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_select_pc_plus_one_b;
   Nbit_reg #(1, 1'd0) x_select_pc_reg_b(.in(switch_pipes ? 1'd0 : d_select_pc_plus_one_b), .out(x_select_pc_plus_one_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_is_load_b;
   Nbit_reg #(1, 1'd0) x_is_load_reg_b(.in(switch_pipes ? 1'd0 : d_is_load_b), .out(x_is_load_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_is_store_b;
   Nbit_reg #(1, 1'd0) x_is_store_reg_b(.in(switch_pipes ? 1'd0 : d_is_store_b), .out(x_is_store_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_is_branch_b;
   Nbit_reg #(1, 1'd0) x_is_branch_reg_b(.in(switch_pipes ? 1'd0 : d_is_branch_b), .out(x_is_branch_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));
   wire x_is_control_b;
   Nbit_reg #(1, 1'd0) x_is_control_reg_b(.in(switch_pipes ? 1'd0 : d_is_control_b), .out(x_is_control_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst_b));

   // MX/WX bypass a
   wire [2:0] m_rdsel_a;
   wire m_regfile_we_a;
   wire [15:0] m_alu_out_a;
   wire w_regfile_we_a;
   wire [15:0] x_alu_r1data_a = ((m_rdsel_b == x_r1sel_a) && m_regfile_we_b && x_r1re_a && m_stall_signal_b == 2'd0) ? m_alu_out_b : ((m_rdsel_a == x_r1sel_a) && m_regfile_we_a && x_r1re_a && m_stall_signal_a == 2'd0) ? m_alu_out_a : ((w_rdsel_b == x_r1sel_a) && w_regfile_we_b && x_r1re_a && test_stall_B == 2'd0) ? w_rddata_a : ((w_rdsel_a == x_r1sel_a) && w_regfile_we_a && x_r1re_a && test_stall_A == 2'd0) ? w_rddata_a : x_r1data_a;

   wire [15:0] x_alu_r2data_a = ((m_rdsel_b == x_r2sel_a) && m_regfile_we_b && x_r2re_a && m_stall_signal_b == 2'd0) ? m_alu_out_b : ((m_rdsel_a == x_r2sel_a) && m_regfile_we_a && x_r2re_a && m_stall_signal_a == 2'd0) ? m_alu_out_a : ((w_rdsel_b == x_r2sel_a) && w_regfile_we_b && x_r2re_a && test_stall_B == 2'd0) ? w_rddata_a : ((w_rdsel_a == x_r2sel_a) && w_regfile_we_a && x_r2re_a && test_stall_A == 2'd0) ? w_rddata_a : x_r2data_a;

   // MX/WX bypass b
   wire [2:0] m_rdsel_b;
   wire m_regfile_we_b;
   wire [15:0] m_alu_out_b;
   wire w_regfile_we_b;
   wire [15:0] x_alu_r1data_b = ((m_rdsel_b == x_r1sel_b) && m_regfile_we_b && x_r1re_b && m_stall_signal_b == 2'd0) ? m_alu_out_b : ((m_rdsel_a == x_r1sel_b) && m_regfile_we_a && x_r1re_b && m_stall_signal_a == 2'd0) ? m_alu_out_a : ((w_rdsel_b == x_r1sel_b) && w_regfile_we_b && x_r1re_b && test_stall_B == 2'd0) ? w_rddata_a : ((w_rdsel_a == x_r1sel_b) && w_regfile_we_a && x_r1re_b && test_stall_A == 2'd0) ? w_rddata_a : x_r1data_b;

   wire [15:0] x_alu_r2data_b = ((m_rdsel_b == x_r2sel_b) && m_regfile_we_b && x_r2re_b && m_stall_signal_b == 2'd0) ? m_alu_out_b : ((m_rdsel_a == x_r2sel_b) && m_regfile_we_a && x_r2re_b && m_stall_signal_a == 2'd0) ? m_alu_out_a : ((w_rdsel_b == x_r2sel_b) && w_regfile_we_b && x_r2re_b && test_stall_B == 2'd0) ? w_rddata_a : ((w_rdsel_a == x_r2sel_b) && w_regfile_we_a && x_r2re_b && test_stall_A == 2'd0) ? w_rddata_a : x_r2data_b;

   // ALU
   wire [15:0] x_alu_out_a;
   wire [15:0] x_alu_out_b;
   lc4_alu alu_a(.i_insn(x_ir_a), .i_pc(x_pc_a), .i_r1data(x_alu_r1data_a), .i_r2data(x_alu_r2data_a), .o_result(x_alu_out_a));
   lc4_alu alu_b(.i_insn(x_ir_b), .i_pc(x_pc_b), .i_r1data(x_alu_r1data_b), .i_r2data(x_alu_r2data_b), .o_result(x_alu_out_b));

   // NZP
   wire [15:0] nzp_in;

   assign nzp_in = w_is_load_b && !m_nzp_we_b && !x_nzp_we_b ? w_rddata_b : w_is_load_a && !m_nzp_we_a && !x_nzp_we_a ? w_rddata_a : x_select_pc_plus_one_b ? x_pc_plus_one_b : x_select_pc_plus_one_a ? x_pc_plus_one_a : x_nzp_we_b ? x_alu_out_b : x_alu_out_a;
   wire nzp_we = (w_is_load_b && !m_nzp_we_b && !x_nzp_we_b) || (w_is_load_a && !m_nzp_we_a && !x_nzp_we_a) || x_select_pc_plus_one_b || x_select_pc_plus_one_a || x_nzp_we_b || x_nzp_we_a;

   wire [2:0] nzp_new = nzp_in == 0 ? 3'b010 : nzp_in[15] == 1'b1 ? 3'b100 : 3'b001;

   wire [2:0] nzp_out;
   Nbit_reg #(3, 3'd0) nzp(.in(nzp_new), .out(nzp_out), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));

   wire take_branch_a = | (x_ir_a[11:9] & nzp_out);
   wire is_mispredict_a = (take_branch_a && x_is_branch_a) || x_is_control_a;
   
   wire take_branch_b = | (x_ir_b[11:9] & nzp_out);
   wire is_mispredict_b = (take_branch_b && x_is_branch_b) || x_is_control_b;

   assign is_mispredict = is_mispredict_a || is_mispredict_b;

   // propagate stall signal
   wire [1:0] x_stall_signal_a;
   Nbit_reg #(2, 16'd2) x_stall_reg_a(.in(x_stall_signal_a), .out(m_stall_signal_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [1:0] x_stall_signal_b;
   Nbit_reg #(2, 16'd2) x_stall_reg(.in(x_stall_signal_b), .out(m_stall_signal_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // M stage
   // TODO dont forget put nop into b in event of mispredict_a
   // TODO MM bypass

   // pipe a
   // pc
   wire [15:0] m_pc_a;
   Nbit_reg #(16, 16'h8200) m_pc_reg_a(.in(x_pc_a), .out(m_pc_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire[15:0] m_pc_plus_one_a;
   Nbit_reg #(16, 16'h8200) m_pc_plus_one_reg_a(.in(x_pc_plus_one_a), .out(m_pc_plus_one_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire [15:0] m_ir_a;
   Nbit_reg #(16, 16'd0) m_ir_reg_a(.in(x_ir_a), .out(m_ir_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward nzp bits
   wire [2:0] m_nzp_a;
   Nbit_reg #(3, 3'd0) m_nzp_reg_a(.in(nzp_new), .out(m_nzp_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward alu output
   Nbit_reg #(16, 16'd0) m_alu_reg_a(.in(x_alu_out_a), .out(m_alu_out_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // just one data register because we don't need r1 anymore
   wire [15:0] m_r2data_a;
   Nbit_reg #(16, 16'd0) m_rt_data_reg_a(.in(x_alu_r2data_a), .out(m_r2data_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] m_r1sel_a;
   Nbit_reg #(3, 3'd0) m_r1sel_reg_a(.in(x_r1sel_a), .out(m_r1sel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_r1re_a;
   Nbit_reg #(1, 1'd0) m_r1re_reg_a(.in(x_r1re_a), .out(m_r1re_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [2:0] m_r2sel_a;
   Nbit_reg #(3, 3'd0) m_r2sel_reg_a(.in(x_r2sel_a), .out(m_r2sel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_r2re_a;
   Nbit_reg #(1, 1'd0) m_r2re_reg_a(.in(x_r2re_a), .out(m_r2re_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'd0) m_rdsel_reg_a(.in(x_rdsel_a), .out(m_rdsel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'd0) m_regfile_we_reg_a(.in(x_regfile_we_a), .out(m_regfile_we_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_nzp_we_a;
   Nbit_reg #(1, 1'd0) m_nzp_we_reg_a(.in(x_nzp_we_a), .out(m_nzp_we_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_select_pc_plus_one_a;
   Nbit_reg #(1, 1'd0) m_select_pc_reg_a(.in(x_select_pc_plus_one_a), .out(m_select_pc_plus_one_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_load_a;
   Nbit_reg #(1, 1'd0) m_is_load_reg_a(.in(x_is_load_a), .out(m_is_load_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_store_a;
   Nbit_reg #(1, 1'd0) m_is_store_reg_a(.in(x_is_store_a), .out(m_is_store_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_branch_a;
   Nbit_reg #(1, 1'd0) m_is_branch_reg_a(.in(x_is_branch_a), .out(m_is_branch_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_control_a;
   Nbit_reg #(1, 1'd0) m_is_control_reg_a(.in(x_is_control_a), .out(m_is_control_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // pipe b
   // pc
   wire [15:0] m_pc_b;
   Nbit_reg #(16, 16'h8200) m_pc_reg_b(.in(x_pc_b), .out(m_pc_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire[15:0] m_pc_plus_one_b;
   Nbit_reg #(16, 16'h8200) m_pc_plus_one_reg_b(.in(x_pc_plus_one_b), .out(m_pc_plus_one_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire [15:0] m_ir_b;
   Nbit_reg #(16, 16'd0) m_ir_reg_b(.in(is_mispredict_a ? 16'd0 : x_ir_b), .out(m_ir_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward nzp bits
   wire [2:0] m_nzp_b;
   Nbit_reg #(3, 3'd0) m_nzp_reg_b(.in(is_mispredict_a ? 16'd0 : nzp_new), .out(m_nzp_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward alu output
   Nbit_reg #(16, 16'd0) m_alu_reg_b(.in(is_mispredict_a ? 16'd0 : x_alu_out_b), .out(m_alu_out_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // just one data register because we don't need r1 anymore
   wire [15:0] m_r2data_b;
   Nbit_reg #(16, 16'd0) m_rt_data_reg_b(.in(is_mispredict_a ? 16'd0 : x_alu_r2data_b), .out(m_r2data_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] m_r1sel_b;
   Nbit_reg #(3, 3'd0) m_r1sel_reg_b(.in(is_mispredict_a ? 3'd0 : x_r1sel_b), .out(m_r1sel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_r1re_b;
   Nbit_reg #(1, 1'd0) m_r1re_reg_b(.in(is_mispredict_a ? 1'd0 : x_r1re_b), .out(m_r1re_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [2:0] m_r2sel_b;
   Nbit_reg #(3, 3'd0) m_r2sel_reg_b(.in(is_mispredict_a ? 3'd0 : x_r2sel_b), .out(m_r2sel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_r2re_b;
   Nbit_reg #(1, 1'd0) m_r2re_reg_b(.in(is_mispredict_a ? 1'd0 : x_r2re_b), .out(m_r2re_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'd0) m_rdsel_reg_b(.in(is_mispredict_a ? 3'd0 : x_rdsel_b), .out(m_rdsel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'd0) m_regfile_we_reg_b(.in(is_mispredict_a ? 1'd0 : x_regfile_we_b), .out(m_regfile_we_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_nzp_we_b;
   Nbit_reg #(1, 1'd0) m_nzp_we_reg_b(.in(is_mispredict_a ? 1'd0 : x_nzp_we_b), .out(m_nzp_we_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_select_pc_plus_one_b;
   Nbit_reg #(1, 1'd0) m_select_pc_reg_b(.in(is_mispredict_a ? 1'd0 : x_select_pc_plus_one_b), .out(m_select_pc_plus_one_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_load_b;
   Nbit_reg #(1, 1'd0) m_is_load_reg_b(.in(is_mispredict_a ? 1'd0 : x_is_load_b), .out(m_is_load_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_store_b;
   Nbit_reg #(1, 1'd0) m_is_store_reg_b(.in(is_mispredict_a ? 1'd0 : x_is_store_b), .out(m_is_store_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_branch_b;
   Nbit_reg #(1, 1'd0) m_is_branch_reg_b(.in(is_mispredict_a ? 1'd0 : x_is_branch_b), .out(m_is_branch_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_control_b;
   Nbit_reg #(1, 1'd0) m_is_control_reg_b(.in(is_mispredict_a ? 1'd0 : x_is_control_b), .out(m_is_control_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   assign o_dmem_we = m_is_store_a || m_is_store_b;
   assign o_dmem_addr = (m_is_load_b || m_is_store_b) ? m_alu_out_b : (m_is_load_a || m_is_store_a) ? m_alu_out_a : 16'd0;

   // propagate stall signal
   wire [1:0] m_stall_signal_a;
   Nbit_reg #(2, 16'd2) m_stall_reg_a(.in(m_stall_signal_a), .out(test_stall_A), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [1:0] m_stall_signal_b;
   Nbit_reg #(2, 16'd2) m_stall_reg_b(.in(m_stall_signal_b), .out(test_stall_B), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // W stage
   // pipe a regs
   // dmem
   wire w_dmem_we_a;
   Nbit_reg #(1, 1'd0) w_dmem_we_reg_a(.in(m_is_store_a), .out(w_dmem_we_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire [15:0] w_dmem_addr_a;
   Nbit_reg #(16, 16'd0) w_dmem_addr_reg_a(.in(o_dmem_addr), .out(w_dmem_addr_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire [15:0] w_dmem_towrite_a;
   Nbit_reg #(16, 16'd0) w_dmem_towrite_reg_a(.in(o_dmem_towrite), .out(w_dmem_towrite_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // pc
   wire [15:0] w_pc_a;
   Nbit_reg #(16, 16'h8200) w_pc_reg_a(.in(m_pc_a), .out(w_pc_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire[15:0] w_pc_plus_one_a;
   Nbit_reg #(16, 16'h8200) w_pc_plus_one_reg_a(.in(m_pc_plus_one_a), .out(w_pc_plus_one_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire [15:0] w_ir_a;
   Nbit_reg #(16, 16'd0) w_ir_reg_a(.in(m_ir_a), .out(w_ir_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward nzp bits
   wire [2:0] w_nzp_a;
   Nbit_reg #(3, 3'd0) w_nzp_reg_a(.in(m_nzp_a), .out(w_nzp_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward alu output
   wire [15:0] w_alu_out_a;
   Nbit_reg #(16, 16'd0) w_alu_reg_a(.in(m_alu_out_a), .out(w_alu_out_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] w_r1sel_a;
   Nbit_reg #(3, 3'd0) w_r1sel_reg_a(.in(m_r1sel_a), .out(w_r1sel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_r1re_a;
   Nbit_reg #(1, 1'd0) w_r1re_reg_a(.in(m_r1re_a), .out(w_r1re_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [2:0] w_r2sel_a;
   Nbit_reg #(3, 3'd0) w_r2sel_reg_a(.in(m_r2sel_a), .out(w_r2sel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_r2re_a;
   Nbit_reg #(1, 1'd0) w_r2re_reg_a(.in(m_r2re_a), .out(w_r2re_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'd0) w_rdsel_reg_a(.in(m_rdsel_a), .out(w_rdsel_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'd0) w_regfile_we_reg_a(.in(m_regfile_we_a), .out(w_regfile_we_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_nzp_we_a;
   Nbit_reg #(1, 1'd0) w_nzp_we_reg_a(.in(m_nzp_we_a), .out(w_nzp_we_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_select_pc_plus_one_a;
   Nbit_reg #(1, 1'd0) w_select_pc_reg_a(.in(m_select_pc_plus_one_a), .out(w_select_pc_plus_one_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_load_a;
   Nbit_reg #(1, 1'd0) w_is_load_reg_a(.in(m_is_load_a), .out(w_is_load_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_store_a;
   Nbit_reg #(1, 1'd0) w_is_store_reg_a(.in(m_is_store_a), .out(w_is_store_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_branch_a;
   Nbit_reg #(1, 1'd0) w_is_branch_reg_a(.in(m_is_branch_a), .out(w_is_branch_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_control_a;
   Nbit_reg #(1, 1'd0) w_is_control_reg_a(.in(m_is_control_a), .out(w_is_control_a), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // pipe b regs
   // dmem
   wire w_dmem_we_b;
   Nbit_reg #(1, 1'd0) w_dmem_we_reg_b(.in(m_is_store_b), .out(w_dmem_we_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire [15:0] w_dmem_addr_b;
   Nbit_reg #(16, 16'd0) w_dmem_addr_reg_b(.in(o_dmem_addr), .out(w_dmem_addr_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire [15:0] w_dmem_towrite_b;
   Nbit_reg #(16, 16'd0) w_dmem_towrite_reg_b(.in(o_dmem_towrite), .out(w_dmem_towrite_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // pc
   wire [15:0] w_pc_b;
   Nbit_reg #(16, 16'h8200) w_pc_reg_b(.in(m_pc_b), .out(w_pc_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire[15:0] w_pc_plus_one_b;
   Nbit_reg #(16, 16'h8200) w_pc_plus_one_reg_b(.in(m_pc_plus_one_b), .out(w_pc_plus_one_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire [15:0] w_ir_b;
   Nbit_reg #(16, 16'd0) w_ir_reg_b(.in(m_ir_b), .out(w_ir_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward nzp bits
   wire [2:0] w_nzp_b;
   Nbit_reg #(3, 3'd0) w_nzp_reg_b(.in(m_nzp_b), .out(w_nzp_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward alu output
   wire [15:0] w_alu_out_b;
   Nbit_reg #(16, 16'd0) w_alu_reg_b(.in(m_alu_out_b), .out(w_alu_out_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] w_r1sel_b;
   Nbit_reg #(3, 3'd0) w_r1sel_reg_b(.in(m_r1sel_b), .out(w_r1sel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_r1re_b;
   Nbit_reg #(1, 1'd0) w_r1re_reg_b(.in(m_r1re_b), .out(w_r1re_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [2:0] w_r2sel_b;
   Nbit_reg #(3, 3'd0) w_r2sel_reg_b(.in(m_r2sel_b), .out(w_r2sel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_r2re_b;
   Nbit_reg #(1, 1'd0) w_r2re_reg_b(.in(m_r2re_b), .out(w_r2re_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'd0) w_rdsel_reg_b(.in(m_rdsel_b), .out(w_rdsel_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'd0) w_regfile_we_reg_b(.in(m_regfile_we_b), .out(w_regfile_we_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_nzp_we_b;
   Nbit_reg #(1, 1'd0) w_nzp_we_reg_b(.in(m_nzp_we_b), .out(w_nzp_we_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_select_pc_plus_one_b;
   Nbit_reg #(1, 1'd0) w_select_pc_reg_b(.in(m_select_pc_plus_one_b), .out(w_select_pc_plus_one_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_load_b;
   Nbit_reg #(1, 1'd0) w_is_load_reg_b(.in(m_is_load_b), .out(w_is_load_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_store_b;
   Nbit_reg #(1, 1'd0) w_is_store_reg_b(.in(m_is_store_b), .out(w_is_store_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_branch_b;
   Nbit_reg #(1, 1'd0) w_is_branch_reg_b(.in(m_is_branch_b), .out(w_is_branch_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_control_b;
   Nbit_reg #(1, 1'd0) w_is_control_reg_b(.in(m_is_control_b), .out(w_is_control_b), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   
   // dmem data
   wire [15:0] w_dmem_data;
   Nbit_reg #(16, 16'd0) w_data_reg(.in(i_cur_dmem_data), .out(w_dmem_data), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   assign w_rddata_a = w_select_pc_plus_one_a ? w_pc_plus_one_a : w_is_load_a ? w_dmem_data : w_alu_out_a;
   assign w_rddata_b = w_select_pc_plus_one_b ? w_pc_plus_one_b : w_is_load_b ? w_dmem_data : w_alu_out_b;

   // WM/MM bypass
   assign o_dmem_towrite = ((m_rdsel_a == m_r2sel_b) && m_regfile_we_a && m_is_store_b) ? m_alu_out_a : ((w_is_load_b && m_is_store_b && w_rdsel_b == m_r2sel_b && w_regfile_we_b && m_r2re_b && test_stall_B == 2'd0) ? w_rddata_a : w_is_load_a && m_is_store_a && w_rdsel_a == m_r2sel_a && w_regfile_we_a && m_r2re_a && test_stall_A == 2'd0) ? w_rddata_a : m_is_store_b ? m_r2data_b : m_is_store_a ? m_r2data_a : 16'd0;

   // Test signals
   // pipe a
   assign test_cur_pc_A = w_pc_a;
   assign test_cur_insn_A = w_ir_a;
   assign test_regfile_we_A = w_regfile_we_a;
   assign test_regfile_wsel_A = w_rdsel_a;
   assign test_regfile_data_A = w_rddata_a;
   assign test_nzp_we_A = w_nzp_we_a;
   assign test_nzp_new_bits_A = w_rddata_a == 0 ? 3'b010 : w_rddata_a[15] == 1'b1 ? 3'b100 : 3'b001;

   assign test_dmem_we_A = w_dmem_we_a;
   assign test_dmem_addr_A = w_is_store_a || w_is_load_a ? w_dmem_addr_a : 16'd0;
   assign test_dmem_data_A = w_is_store_a ? w_dmem_towrite_a : w_is_load_a ? w_dmem_data : 16'd0;
   
   // pipe b
   assign test_cur_pc_B = w_pc_b;
   assign test_cur_insn_B = w_ir_b;
   assign test_regfile_we_B = w_regfile_we_b;
   assign test_regfile_wsel_B = w_rdsel_b;
   assign test_regfile_data_B = w_rddata_b;
   assign test_nzp_we_B = w_nzp_we_b;
   assign test_nzp_new_bits_B = w_rddata_b == 0 ? 3'b010 : w_rddata_b[15] == 1'b1 ? 3'b100 : 3'b001;

   assign test_dmem_we_B = w_dmem_we_b;
   assign test_dmem_addr_B = w_is_store_b || w_is_load_b ? w_dmem_addr_b : 16'd0;
   assign test_dmem_data_B = w_is_store_b ? w_dmem_towrite_b : w_is_load_b ? w_dmem_data : 16'd0;

   assign led_data = switch_data;

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nanoseconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display();
   end
endmodule
