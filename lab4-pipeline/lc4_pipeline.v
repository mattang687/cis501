/* TODO: name and PennKeys of all group members here */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this is stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter
    output wire [15:0] test_cur_insn, // Testbench: instruction bits
    output wire        test_regfile_we, // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );
   
   /*** YOUR CODE HERE ***/
   
   // F stage

   wire [15:0] f_next_pc;
   wire [15:0] f_pc;
   wire f_pc_reg_we;
   wire [15:0] f_pc_plus_one;
   wire [15:0] x_alu_out

   wire is_mispredict;
   wire is_load_use;

   assign f_pc_reg_we = !is_load_use;

   assign f_next_pc = is_mispredict ? x_alu_out : f_pc_plus_one;

   Nbit_reg #(16, 16'h8200) f_pc_reg(.in(f_next_pc), .out(f_pc), .clk(clk), .we(f_pc_reg_we), .gwe(gwe), .rst(rst));

   cla16 f_pc_incr(.a(f_pc), .b(16'd0), .cin(16'd1), .sum(f_pc_plus_one));

   // D stage

   wire [15:0] d_pc;
   wire d_reg_we = !is_load_use;
   wire d_ir_rst = is_mispredict || rst;

   Nbit_reg #(16, 16'h8200) d_pc_reg(.in(f_pc), .out(d_pc), .clk(clk), .we(d_reg_we), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'd0) d_ir_reg(.in(i_cur_insn), .out(d_ir), .clk(clk), .we(d_reg_we), .gwe(gwe), .rst(d_ir_rst));

   wire [2:0] d_r1sel;
   wire d_r1re;
   wire [2:0] d_r2sel;
   wire d_r2re;
   wire [2:0] d_wsel;
   wire d_regfile_we;
   wire d_nzp_we;
   wire d_select_pc_plus_one;
   wire d_is_load;
   wire d_is_store;
   wire d_is_branch;
   wire d_is_control;

   lc4_decoder decoder(.insn(i_cur_insn), .r1sel(d_r1sel), .r1re(d_r1re), .r2sel(d_r2sel), .r2re(d_r2re), .wsel(d_wsel), .regfile_we(d_regfile_we), .nzp_we(d_nzp_we), .select_pc_plus_one(d_select_pc_plus_one), .is_load(d_is_load), .is_store(d_is_store), .is_branch(d_is_branch), .is_control_insn(d_is_control));

   wire [15:0] d_r1data;
   wire [15:0] d_r2data;

   wire [15:0] d_r1data_tmp;
   wire [15:0] d_r2data_tmp;

   lc4_regfile regfile(.clk(clk), .gwe(gwe), .rst(rst), .i_rs(d_r1sel), .o_rs_data(d_r1data_tmp), .i_rt(d_r2sel), .o_rt_data(d_r2data_tmp), .i_rd(d_wsel), .i_wdata(w_rddata), .i_rd_we(w_regfile_we));

   assign d_r1data = (w_wsel == d_r1sel) ? w_rddata : d_r1data_tmp;
   assign d_r2data = (w_wsel == d_r2sel) ? w_rddata : d_r2data_tmp;

   // X stage
   
   wire [15:0] x_pc;
   Nbit_reg #(16, 16'h8200) x_pc_reg(.in(d_pc), .out(x_pc), .clk(clk), .we(1), .gwe(gwe), .rst(rst));

   wire x_ir_rst = is_load_use || is_mispredict || rst;
   wire [15:0] x_ir;
   Nbit_reg #(16, 16'd0) x_ir_reg(.in(d_ir), .out(x_ir), .clk(clk), .we(1), .gwe(gwe), .rst(x_ir_rst));

   wire [15:0] x_r1data;
   Nbit_reg #(16, 16'd0) x_rs_data(.in(d_r1data), .out(x_r1data), .clk(clk), .we(1), .gwe(gwe), .rst(rst));

   wire [15:0] x_r2data;
   Nbit_reg #(16, 16'd0) x_rt_data(.in(d_r2data), .out(x_r2data), .clk(clk), .we(1), .gwe(gwe), .rst(rst));

   wire [2:0] x_r1sel;
   Nbit_reg #(3, 3'd0) x_r1sel_reg(.in(d_r1sel), .out(x_r1sel), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_r1re;
   Nbit_reg #(1, 1'd0) x_r1re_reg(.in(d_r1re), .out(x_r1re), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire [2:0] x_r2sel;
   Nbit_reg #(3, 3'd0) x_r2sel_reg(.in(d_r2sel), .out(x_r2sel), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_r2re;
   Nbit_reg #(1, 1'd0) x_r2re_reg(.in(d_r2re), .out(x_r2re), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire [2:0] x_wsel;
   Nbit_reg #(3, 3'd0) x_wsel_reg(.in(d_wsel), .out(x_wsel), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_regfile_we;
   Nbit_reg #(1, 1'd0) x_regfile_we_reg(.in(d_regfile_we), .out(x_regfile_we), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_nzp_we;
   Nbit_reg #(1, 1'd0) x_nzp_we_reg(.in(d_nzp_we), .out(x_nzp_we), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_select_pc_plus_one;
   Nbit_reg #(1, 1'd0) x_select_pc_reg(.in(d_select_pc_plus_one), .out(x_select_pc_plus_one, .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_is_load;
   Nbit_reg #(1, 1'd0) x_is_load_reg(.in(d_is_load), .out(x_is_load), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_is_store;
   Nbit_reg #(1, 1'd0) x_is_store_reg(.in(d_is_store), .out(x_is_store), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_is_branch;
   Nbit_reg #(1, 1'd0) x_is_branch_reg(.in(d_is_branch), .out(x_is_branch), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
   wire x_is_control;
   Nbit_reg #(1, 1'd0) x_is_control_reg(.in(d_is_control), .out(x_is_control), .clk(clk), .we(1), .gwe(gwe), .rst(rst));

   assign is_load_use = x_is_load && !d_is_store && ((x_wsel == d_r1sel) && d_r1re && x_regfile_we) && ((x_wsel == d_r2sel) && d_r2re && x_regfile_we);

   // MX bypass
   wire [15:0] x_alu_r1data = ((m_wsel == x_r1sel) && m_regfile_we && x_r1re) ? m_alu_out : ((w_wsel == x_r1sel) && w_regfile_we && x_r1re) ? w_rd_data : x_r1data;

   wire [15:0] x_alu_r2data = ((m_wsel == x_r2sel) && m_regfile_we && x_r2re) ? m_alu_out : ((w_wsel == x_r2sel) && w_regfile_we && x_r2re) ? w_rd_data : x_r2data;






   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    * 
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    */
`ifndef NDEBUG
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
      // run it for that many nano-seconds, then set
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
`endif
endmodule
