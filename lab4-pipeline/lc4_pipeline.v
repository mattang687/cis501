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

   wire is_mispredict;
   wire is_load_use;

   assign f_pc_reg_we = !is_load_use;

   wire [15:0] x_alu_out;
   assign f_next_pc = is_mispredict ? x_alu_out : f_pc_plus_one;

   Nbit_reg #(16, 16'h8200) f_pc_reg(.in(f_next_pc), .out(f_pc), .clk(clk), .we(f_pc_reg_we), .gwe(gwe), .rst(rst));

   cla16 f_pc_incr(.a(f_pc), .b(16'd0), .cin(1'd1), .sum(f_pc_plus_one));

   assign o_cur_pc = f_pc;

   // D stage

   wire [15:0] d_pc;
   wire d_reg_we = !is_load_use;
   wire d_ir_rst = is_mispredict || rst;

   Nbit_reg #(16, 16'h8200) d_pc_reg(.in(f_pc), .out(d_pc), .clk(clk), .we(d_reg_we), .gwe(gwe), .rst(rst));

   wire [15:0] d_ir;
   Nbit_reg #(16, 16'd0) d_ir_reg(.in(i_cur_insn), .out(d_ir), .clk(clk), .we(d_reg_we), .gwe(gwe), .rst(d_ir_rst));

   wire [2:0] d_r1sel;
   wire d_r1re;
   wire [2:0] d_r2sel;
   wire d_r2re;
   wire [2:0] d_rdsel;
   wire d_regfile_we;
   wire d_nzp_we;
   wire d_select_pc_plus_one;
   wire d_is_load;
   wire d_is_store;
   wire d_is_branch;
   wire d_is_control;

   lc4_decoder decoder(.insn(d_ir), .r1sel(d_r1sel), .r1re(d_r1re), .r2sel(d_r2sel), .r2re(d_r2re), .wsel(d_rdsel), .regfile_we(d_regfile_we), .nzp_we(d_nzp_we), .select_pc_plus_one(d_select_pc_plus_one), .is_load(d_is_load), .is_store(d_is_store), .is_branch(d_is_branch), .is_control_insn(d_is_control));

   wire [15:0] d_r1data;
   wire [15:0] d_r2data;

   wire [15:0] d_r1data_tmp;
   wire [15:0] d_r2data_tmp;

   lc4_regfile regfile(.clk(clk), .gwe(gwe), .rst(rst), .i_rs(d_r1sel), .o_rs_data(d_r1data_tmp), .i_rt(d_r2sel), .o_rt_data(d_r2data_tmp), .i_rd(w_rdsel), .i_wdata(w_rddata), .i_rd_we(w_regfile_we));

   // WD bypass
   wire [2:0] w_rdsel;
   wire [15:0] w_rddata;

   assign d_r1data = ((w_rdsel == d_r1sel) && d_r1re && w_regfile_we) ? w_rddata : d_r1data_tmp;
   assign d_r2data = ((w_rdsel == d_r2sel) && d_r1re && w_regfile_we) ? w_rddata : d_r2data_tmp;

   

   // X stage
   
   // PC register
   wire [15:0] x_pc;
   Nbit_reg #(16, 16'h8200) x_pc_reg(.in(d_pc), .out(x_pc), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire x_ir_rst = is_load_use || is_mispredict || rst;
   wire [15:0] x_ir;
   Nbit_reg #(16, 16'd0) x_ir_reg(.in(d_ir), .out(x_ir), .clk(clk), .we(1'd1), .gwe(gwe), .rst(x_ir_rst));

   // Data registers
   wire [15:0] x_r1data;
   Nbit_reg #(16, 16'd0) x_rs_data(.in(d_r1data), .out(x_r1data), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   wire [15:0] x_r2data;
   Nbit_reg #(16, 16'd0) x_rt_data(.in(d_r2data), .out(x_r2data), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] x_r1sel;
   Nbit_reg #(3, 3'd0) x_r1sel_reg(.in(d_r1sel), .out(x_r1sel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_r1re;
   Nbit_reg #(1, 1'd0) x_r1re_reg(.in(d_r1re), .out(x_r1re), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [2:0] x_r2sel;
   Nbit_reg #(3, 3'd0) x_r2sel_reg(.in(d_r2sel), .out(x_r2sel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_r2re;
   Nbit_reg #(1, 1'd0) x_r2re_reg(.in(d_r2re), .out(x_r2re), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [2:0] x_rdsel;
   Nbit_reg #(3, 3'd0) x_rdsel_reg(.in(d_rdsel), .out(x_rdsel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_regfile_we;
   Nbit_reg #(1, 1'd0) x_regfile_we_reg(.in(d_regfile_we), .out(x_regfile_we), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_nzp_we;
   Nbit_reg #(1, 1'd0) x_nzp_we_reg(.in(d_nzp_we), .out(x_nzp_we), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_select_pc_plus_one;
   Nbit_reg #(1, 1'd0) x_select_pc_reg(.in(d_select_pc_plus_one), .out(x_select_pc_plus_one), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_is_load;
   Nbit_reg #(1, 1'd0) x_is_load_reg(.in(d_is_load), .out(x_is_load), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_is_store;
   Nbit_reg #(1, 1'd0) x_is_store_reg(.in(d_is_store), .out(x_is_store), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_is_branch;
   Nbit_reg #(1, 1'd0) x_is_branch_reg(.in(d_is_branch), .out(x_is_branch), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire x_is_control;
   Nbit_reg #(1, 1'd0) x_is_control_reg(.in(d_is_control), .out(x_is_control), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   assign is_load_use = x_is_load && !d_is_store && ((x_rdsel == d_r1sel) && d_r1re && x_regfile_we) && ((x_rdsel == d_r2sel) && d_r2re && x_regfile_we);

   // MX bypass
   wire [2:0] m_rdsel;
   wire m_regfile_we;
   wire [15:0] m_alu_out;
   wire w_regfile_we;
   wire [15:0] x_alu_r1data = ((m_rdsel == x_r1sel) && m_regfile_we && x_r1re) ? m_alu_out : ((w_rdsel == x_r1sel) && w_regfile_we && x_r1re) ? w_rddata : x_r1data;

   wire [15:0] x_alu_r2data = ((m_rdsel == x_r2sel) && m_regfile_we && x_r2re) ? m_alu_out : ((w_rdsel == x_r2sel) && w_regfile_we && x_r2re) ? w_rddata : x_r2data;

   // ALU

   lc4_alu alu(.i_insn(x_ir), .i_pc(x_pc), .i_r1data(x_alu_r1data), .i_r2data(x_alu_r2data), .o_result(x_alu_out));

   // NZP
   // TODO handle load
   wire [15:0] nzp_in;

   wire [15:0] x_pc_plus_one;
   cla16 x_pc_incr(.a(x_pc), .b(16'd0), .cin(1'd1), .sum(x_pc_plus_one));

   assign nzp_in = x_select_pc_plus_one ? x_pc_plus_one : x_alu_out;

   wire [2:0] nzp_new = nzp_in == 0 ? 3'b010 : nzp_in[15] == 1'b1 ? 3'b100 : 3'b001;

   wire [2:0] nzp_out;
   Nbit_reg #(3, 3'd0) nzp(.in(nzp_new), .out(nzp_out), .clk(clk), .we(x_nzp_we), .gwe(gwe), .rst(rst));

   wire take_branch = | (i_cur_insn[11:9] & nzp_out);
   assign is_mispredict = (take_branch && x_is_branch) || x_is_control;

   // M stage

   // pc
   wire [15:0] m_pc;
   Nbit_reg #(16, 16'h8200) m_pc_reg(.in(x_pc), .out(m_pc), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire [15:0] m_ir;
   Nbit_reg #(16, 16'd0) m_ir_reg(.in(x_ir), .out(m_ir), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward nzp bits
   wire [2:0] m_nzp;
   Nbit_reg #(3, 3'd0) m_nzp_reg(.in(nzp_new), .out(m_nzp), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward alu output
   Nbit_reg #(16, 16'd0) m_alu_reg(.in(x_alu_out), .out(m_alu_out), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // just one data register because we don't need r1 anymore
   wire [15:0] m_r2data;
   Nbit_reg #(16, 16'd0) m_rt_data_reg(.in(x_r2data), .out(m_r2data), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] m_r1sel;
   Nbit_reg #(3, 3'd0) m_r1sel_reg(.in(x_r1sel), .out(m_r1sel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_r1re;
   Nbit_reg #(1, 1'd0) m_r1re_reg(.in(x_r1re), .out(m_r1re), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [2:0] m_r2sel;
   Nbit_reg #(3, 3'd0) m_r2sel_reg(.in(x_r2sel), .out(m_r2sel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_r2re;
   Nbit_reg #(1, 1'd0) m_r2re_reg(.in(x_r2re), .out(m_r2re), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'd0) m_rdsel_reg(.in(x_rdsel), .out(m_rdsel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'd0) m_regfile_we_reg(.in(x_regfile_we), .out(m_regfile_we), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_nzp_we;
   Nbit_reg #(1, 1'd0) m_nzp_we_reg(.in(x_nzp_we), .out(m_nzp_we), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_select_pc_plus_one;
   Nbit_reg #(1, 1'd0) m_select_pc_reg(.in(x_select_pc_plus_one), .out(m_select_pc_plus_one), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_load;
   Nbit_reg #(1, 1'd0) m_is_load_reg(.in(x_is_load), .out(m_is_load), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_store;
   Nbit_reg #(1, 1'd0) m_is_store_reg(.in(x_is_store), .out(m_is_store), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_branch;
   Nbit_reg #(1, 1'd0) m_is_branch_reg(.in(x_is_branch), .out(m_is_branch), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire m_is_control;
   Nbit_reg #(1, 1'd0) m_is_control_reg(.in(x_is_control), .out(m_is_control), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   assign o_dmem_we = m_is_store;
   assign o_dmem_addr = (m_is_load || m_is_store) ? m_alu_out : 16'd0;
   assign o_dmem_towrite = m_is_store ? m_r2data : 16'd0;

   assign test_dmem_we = o_dmem_we;
   assign test_dmem_addr = o_dmem_addr;
   assign test_dmem_data = o_dmem_towrite;

   // W stage

   // pc
   wire [15:0] w_pc;
   Nbit_reg #(16, 16'h8200) w_pc_reg(.in(m_pc), .out(w_pc), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Insn register
   wire [15:0] w_ir;
   Nbit_reg #(16, 16'd0) w_ir_reg(.in(m_ir), .out(w_ir), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward nzp bits
   wire [2:0] w_nzp;
   Nbit_reg #(3, 3'd0) w_nzp_reg(.in(m_nzp), .out(w_nzp), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // forward alu output
   wire [15:0] w_alu_out;
   Nbit_reg #(16, 16'd0) w_alu_reg(.in(m_alu_out), .out(w_alu_out), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // Control signal registers
   wire [2:0] w_r1sel;
   Nbit_reg #(3, 3'd0) w_r1sel_reg(.in(m_r1sel), .out(w_r1sel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_r1re;
   Nbit_reg #(1, 1'd0) w_r1re_reg(.in(m_r1re), .out(w_r1re), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [2:0] w_r2sel;
   Nbit_reg #(3, 3'd0) w_r2sel_reg(.in(m_r2sel), .out(w_r2sel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_r2re;
   Nbit_reg #(1, 1'd0) w_r2re_reg(.in(m_r2re), .out(w_r2re), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'd0) w_rdsel_reg(.in(m_rdsel), .out(w_rdsel), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'd0) w_regfile_we_reg(.in(m_regfile_we), .out(w_regfile_we), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_nzp_we;
   Nbit_reg #(1, 1'd0) w_nzp_we_reg(.in(m_nzp_we), .out(w_nzp_we), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_select_pc_plus_one;
   Nbit_reg #(1, 1'd0) w_select_pc_reg(.in(m_select_pc_plus_one), .out(w_select_pc_plus_one), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_load;
   Nbit_reg #(1, 1'd0) w_is_load_reg(.in(m_is_load), .out(w_is_load), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_store;
   Nbit_reg #(1, 1'd0) w_is_store_reg(.in(m_is_store), .out(w_is_store), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_branch;
   Nbit_reg #(1, 1'd0) w_is_branch_reg(.in(m_is_branch), .out(w_is_branch), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire w_is_control;
   Nbit_reg #(1, 1'd0) w_is_control_reg(.in(m_is_control), .out(w_is_control), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   // dmem data
   wire [15:0] w_dmem_data;
   Nbit_reg #(16, 16'd0) w_data_reg(.in(i_cur_dmem_data), .out(w_dmem_data), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));

   assign w_rddata = w_is_load ? w_dmem_data : w_alu_out;

   // Test signals
   
   /*
   wire [15:0] test_r1sel;
   wire [15:0] test_r1re;
   wire [15:0] test_r2sel;
   wire [15:0] test_r2re;
   wire [15:0] test_select_pc_plus_one;
   wire [15:0] test_is_load;
   wire [15:0] test_is_store;
   wire [15:0] test_is_branch;
   wire [15:0] test_is_control;
   
   lc4_decoder test_decoder(.insn(w_ir), .r1sel(test_r1sel), .r1re(test_r1re), .r2sel(test_r2sel), .r2re(test_r2re), .wsel(test_regfile_wsel), .regfile_we(test_regfile_we), .nzp_we(test_nzp_we), .select_pc_plus_one(test_select_pc_plus_one), .is_load(test_is_load), .is_store(test_is_store), .is_branch(test_is_branch), .is_control_insn(test_is_control));
   */

   // stall stuff
   wire [1:0] f_stall_signal = is_mispredict ? 2'd2 : 0;
   wire [1:0] d_stall_signal_in;
   Nbit_reg #(2, 16'd2) f_stall_reg(.in(f_stall_signal), .out(d_stall_signal_in), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [1:0] d_stall_signal = (d_stall_signal_in == 2'd2) ? 2'd2 : is_mispredict ? 2'd2 : is_load_use ? 2'd3 : 0;
   Nbit_reg #(2, 16'd2) d_stall_reg(.in(d_stall_signal), .out(x_stall_signal), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [1:0] x_stall_signal;
   Nbit_reg #(2, 16'd2) x_stall_reg(.in(x_stall_signal), .out(m_stall_signal), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));
   wire [1:0] m_stall_signal;
   Nbit_reg #(2, 16'd2) m_stall_reg(.in(m_stall_signal), .out(test_stall), .clk(clk), .we(1'd1), .gwe(gwe), .rst(rst));


   assign test_cur_pc = w_pc;
   assign test_cur_insn = w_ir;
   assign test_regfile_we = w_regfile_we;
   assign test_regfile_wsel = w_rdsel;
   assign test_regfile_data = w_rddata;
   assign test_nzp_we = w_nzp_we;
   assign test_nzp_new_bits = w_nzp;

   assign led_data = switch_data;



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
