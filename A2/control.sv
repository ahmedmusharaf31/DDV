`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/08/2026 10:41:25 PM
// Design Name: 
// Module Name: control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// import SystemVerilog package for opcode_t and state_t
import typedefs::*;

module control(
output logic load_ac,
output logic mem_rd,
output logic mem_wr,
output logic inc_pc,
output logic load_pc,
output logic load_ir,
output logic halt,
input opcode_t opcode, // opcode type name must be opcode_t
input zero,
input clk,
input rst_   
);

timeunit 1ns;
timeprecision 100ps;

// State variable declaration using enumerated type
state_t state;

// ALU operation flag: true for ADD, AND, XOR, LDA
logic APTS;

assign APTS = (opcode == ADD) || (opcode == AND) || (opcode == XOR) || (opcode == LDA);

// State generation
always_ff @(posedge clk or negedge rst_)
  if (!rst_)
    state <= INST_ADDR;
  else
    state <= state_t'(state.next());

// Output decode: combinational block
always_comb begin
  // Default all outputs to 0
  mem_rd  = 1'b0;
  load_ir = 1'b0;
  halt    = 1'b0;
  inc_pc  = 1'b0;
  load_ac = 1'b0;
  load_pc = 1'b0;
  mem_wr  = 1'b0;

  unique case (state)
    INST_ADDR: begin
      mem_rd = 1'b0;
    end

    INST_FETCH: begin
      mem_rd = 1'b1;
    end

    INST_LOAD: begin
      mem_rd  = 1'b1;
      load_ir = 1'b1;
    end

    IDLE: begin
      mem_rd  = 1'b1;
      load_ir = 1'b1;
    end

    OP_ADDR: begin
      halt   = (opcode == HLT);
      inc_pc = 1'b1;
    end

    OP_FETCH: begin
      mem_rd = APTS;
    end

    ALU_OP: begin
      mem_rd  = APTS;
      load_ac = APTS;
      load_pc = (opcode == JMP);
      inc_pc  = (opcode == SKZ) && zero;
    end

    STORE: begin
      mem_rd  = APTS;
      load_ac = APTS;
      load_pc = (opcode == JMP);
      inc_pc  = (opcode == JMP);
      mem_wr  = (opcode == STO);
    end

    default: begin
      mem_rd  = 1'b0;
      load_ir = 1'b0;
      halt    = 1'b0;
      inc_pc  = 1'b0;
      load_ac = 1'b0;
      load_pc = 1'b0;
      mem_wr  = 1'b0;
    end
  endcase
end

endmodule
