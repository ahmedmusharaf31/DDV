`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/08/2026 10:38:26 PM
// Design Name: 
// Module Name: typedefs
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

package typedefs;

  // Opcode enumerated type with explicit 3-bit logic encoding
  typedef enum logic [2:0] {
    HLT = 3'b000,
    SKZ = 3'b001,
    ADD = 3'b010,
    AND = 3'b011,
    XOR = 3'b100,
    LDA = 3'b101,
    STO = 3'b110,
    JMP = 3'b111
  } opcode_t;

  // State enumerated type with explicit 3-bit logic encoding
  typedef enum logic [2:0] {
    INST_ADDR = 3'b000,
    INST_FETCH = 3'b001,
    INST_LOAD  = 3'b010,
    IDLE       = 3'b011,
    OP_ADDR    = 3'b100,
    OP_FETCH   = 3'b101,
    ALU_OP     = 3'b110,
    STORE      = 3'b111
  } state_t;

endpackage
