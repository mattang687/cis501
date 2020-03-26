/* INSERT NAME AND PENNKEY HERE */
// Matt Tang, mattang

`timescale 1ns / 1ps

`default_nettype none

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);


      /*** YOUR CODE HERE ***/

    // generate signals based on instruction

    // signal test
    //assign o_result = JSRR_ctl ? 16'd65535 : 16'd0;

    wire [3:0] opcode = i_insn[15:12];

    wire BR_ctl = (opcode == 4'b0000) ? 1 : 0;

    wire ADD_ctl = ((opcode == 4'b0001) && (i_insn[5:3] == 3'b000)) ? 1 : 0;
    wire MUL_ctl = ((opcode == 4'b0001) && (i_insn[5:3] == 3'b001)) ? 1 : 0;
    wire SUB_ctl = ((opcode == 4'b0001) && (i_insn[5:3] == 3'b010)) ? 1 : 0;
    wire DIV_ctl = ((opcode == 4'b0001) && (i_insn[5:3] == 3'b011)) ? 1 : 0;

    wire ADD_imm_ctl = ((opcode == 4'b0001) && (i_insn[5] == 1'b1)) ? 1 : 0;

    wire CMP_ctl = ((opcode == 4'b0010) && (i_insn[8:7] == 2'b00)) ? 1 : 0;
    wire CMPU_ctl = ((opcode == 4'b0010) && (i_insn[8:7] == 2'b01)) ? 1 : 0;
    wire CMPI_ctl = ((opcode == 4'b0010) && (i_insn[8:7] == 2'b10)) ? 1 : 0;
    wire CMPIU_ctl = ((opcode == 4'b0010) && (i_insn[8:7] == 2'b11)) ? 1 : 0;

    wire JSR_ctl = ((opcode == 4'b0100) && i_insn[11]) ? 1 : 0;
    wire JSRR_ctl = ((opcode == 4'b0100) && !i_insn[11]) ? 1 : 0;

    wire AND_ctl = ((opcode == 4'b0101) && (i_insn[5:3] == 3'b000)) ? 1 : 0;
    wire NOT_ctl = ((opcode == 4'b0101) && (i_insn[5:3] == 3'b001)) ? 1 : 0;
    wire OR_ctl = ((opcode == 4'b0101) && (i_insn[5:3] == 3'b010)) ? 1 : 0;
    wire XOR_ctl = ((opcode == 4'b0101) && (i_insn[5:3] == 3'b011)) ? 1 : 0;

    // signal test
    // assign o_result = {BR_ctl, ADD_ctl, MUL_ctl, SUB_ctl, DIV_ctl, ADD_imm_ctl, CMP_ctl, CMPU_ctl, CMPI_ctl, CMPIU_ctl, JSR_ctl, JSRR_ctl, AND_ctl, NOT_ctl, OR_ctl, XOR_ctl};

    wire AND_imm_ctl = ((opcode == 4'b0101) && (i_insn[5] == 1'b1)) ? 1 : 0;

    wire LDR_ctl = ((opcode == 4'b0110) || (opcode == 4'b0111)) ? 1 : 0;

    wire RTI_ctl = (opcode == 4'b1000) ? 1 : 0;

    wire CONST_ctl = (opcode == 4'b1001) ? 1 : 0;

    wire SLL_ctl = ((opcode == 4'b1010) && (i_insn[5:4] == 2'b00)) ? 1 : 0;
    wire SRA_ctl = ((opcode == 4'b1010) && (i_insn[5:4] == 2'b01)) ? 1 : 0;
    wire SRL_ctl = ((opcode == 4'b1010) && (i_insn[5:4] == 2'b10)) ? 1 : 0;
    wire MOD_ctl = ((opcode == 4'b1010) && (i_insn[5:4] == 2'b11)) ? 1 : 0;

    wire JMP_ctl = ((opcode == 4'b1100) && i_insn[11]) ? 1 : 0;
    wire JMPR_ctl = ((opcode == 4'b1100) && !i_insn[11]) ? 1 : 0;

    wire HICONST_ctl = (opcode == 4'b1101) ? 1 : 0;

    wire TRAP_ctl = (opcode == 4'b1111) ? 1 : 0;
    
    // set up cla inputs
    wire [15:0] i_cla_a = (BR_ctl | JMP_ctl) ? i_pc : i_r1data;

    wire [15:0] sub_out_tmp = SUB_ctl ? ~i_r2data : i_r2data;
    wire [15:0] add_sub_tmp = (ADD_ctl | SUB_ctl) ? sub_out_tmp : 16'd0;

    wire [15:0] add_imm_tmp = ADD_imm_ctl ? {{11{i_insn[4]}}, i_insn[4:0]} : 16'd0;

    wire [15:0] br_tmp = BR_ctl ? {{7{i_insn[8]}}, i_insn[8:0]} : 16'd0;

    wire [15:0] ldr_tmp = LDR_ctl ? {{10{i_insn[5]}}, i_insn[5:0]} : 16'd0;

    wire [15:0] jmp_tmp = JMP_ctl ? {{5{i_insn[10]}}, i_insn[10:0]} : 16'd0;

    wire [15:0] i_cla_b = add_sub_tmp | add_imm_tmp | br_tmp | ldr_tmp | jmp_tmp;

    wire cin = (BR_ctl | SUB_ctl | JMP_ctl) ? 1 : 0;

    wire [15:0] cla_out_tmp;

    wire [15:0] cla_out = (SUB_ctl | ADD_ctl | ADD_imm_ctl | BR_ctl | LDR_ctl | JMP_ctl) ? cla_out_tmp : 16'd0;

    // wire everything into the cla
    cla16 cla(.a(i_cla_a), .b(i_cla_b), .cin(cin), .sum(cla_out_tmp));

    // set up cmp inputs
    wire [15:0] cmp1 = i_r1data;
    wire [15:0] cmp2_tmp = i_r2data;
    wire [15:0] cmpi2_tmp = CMPIU_ctl ? {{9{1'b0}}, i_insn[6:0]} : {{9{i_insn[6]}}, i_insn[6:0]};
    wire[15:0] cmp2 = (CMPI_ctl | CMPIU_ctl) ? cmpi2_tmp : cmp2_tmp;

    // do the signed and unsigned comparisons separately
    wire [15:0] cmpu_out_tmp = (cmp1 < cmp2) ? 16'hFFFF : (cmp1 > cmp2) ? 16'd1 : 16'd0;
    wire [15:0] cmpu_out = (CMPU_ctl | CMPIU_ctl) ? cmpu_out_tmp : 16'd0;

    wire signed [15:0] cmp1s = cmp1;
    wire signed [15:0] cmp2s = cmp2;
    wire [15:0] cmps_out_tmp = (cmp1s < cmp2s) ? 16'hFFFF : (cmp1s > cmp2s) ? 16'd1 : 16'd0;
    wire [15:0] cmps_out = (CMP_ctl | CMPI_ctl) ? cmps_out_tmp : 16'd0;

    // multiply
    wire [15:0] mul_out = MUL_ctl ? i_r1data * i_r2data : 16'd0;

    //divide
    wire [15:0] div_out_tmp;
    wire [15:0] mod_out_tmp;
    lc4_divider div(.i_dividend(i_r1data), .i_divisor(i_r2data), .o_remainder(mod_out_tmp), .o_quotient(div_out_tmp));
    wire [15:0] div_out = DIV_ctl ? div_out_tmp : 16'd0;
    wire [15:0] mod_out = MOD_ctl ? mod_out_tmp : 16'd0;

    // rti, jmpr, jsrr
    wire [15:0] rti_jmpr_out = (JSRR_ctl | JMPR_ctl | RTI_ctl) ? i_r1data : 16'd0;

    // jsr
    wire [15:0] jsr_tmp = (i_pc & 16'h8000) | {i_insn[10:0], {4{1'b0}}};
    wire [15:0] jsr_out = JSR_ctl ? jsr_tmp : 16'd0;

    // and
    wire [15:0] and2 = AND_imm_ctl ? {{11{i_insn[4]}}, i_insn[4:0]} : i_r2data;
    wire [15:0] and_tmp = i_r1data & and2;
    wire [15:0] and_out = (AND_ctl | AND_imm_ctl) ? and_tmp : 16'd0;

    // or
    wire [15:0] or_out = OR_ctl ? i_r1data | i_r2data : 16'd0;

    // not
    wire [15:0] not_out = NOT_ctl ? ~i_r1data : 16'd0;

    // xor
    wire [15:0] xor_out = XOR_ctl ? i_r1data ^ i_r2data : 16'd0;

    // const
    wire [15:0] const_out = CONST_ctl ? {{7{i_insn[8]}}, i_insn[8:0]} : 16'd0;

    // sll
    wire [15:0] sll_out = SLL_ctl ? i_r1data << i_insn[3:0] : 16'd0;

    // srl
    wire [15:0] srl_out = SRL_ctl ? i_r1data >> i_insn[3:0] : 16'd0;

    // sra
    wire [15:0] sra_out_tmp = i_r1data >> i_insn[3:0];
    wire [15:0] mask = ~(16'hFFFF >> i_insn[3:0]);
    wire [15:0] sra_sign_tmp = i_r1data[15] ? mask | sra_out_tmp : sra_out_tmp;
    wire [15:0] sra_out = SRA_ctl ? sra_sign_tmp : 16'd0;

    // hiconst
    wire [15:0] hiconst_tmp = (i_r1data & 16'h00FF) | ({i_insn[7:0], {8{1'b0}}});
    wire [15:0] hiconst_out = HICONST_ctl ? hiconst_tmp : 16'd0;

    // trap
    wire [15:0] trap_out = TRAP_ctl ? (16'h8000 | {{8{1'b0}}, i_insn[7:0]}) : 16'd0;

    // or all the outputs together
    assign o_result = cla_out | cmpu_out | cmps_out | mul_out | div_out | mod_out | rti_jmpr_out | jsr_out | and_out | or_out | not_out | xor_out | const_out | sll_out | sra_out | srl_out | hiconst_out | trap_out;

endmodule
