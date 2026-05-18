// opcode_t enum for opcode values
typedef enum logic [2:0] {
  ADD, SUB, MUL, OR, AND, XOR, SLL, SRL
} opcode_t;

module alu (
  output logic [7:0] out,
  output logic zero,
  input logic clk,
  input logic [7:0] a,
  input logic [7:0] b,
  input opcode_t opcode
);

timeunit 1ns;
timeprecision 100ps;

always @(negedge clk) begin
  unique case (opcode)
    ADD: out <= a + b;
    SUB: out <= a - b;
    MUL: out <= a * b;
    OR:  out <= a | b;
    AND: out <= a & b;
    XOR: out <= a ^ b;
    SLL: out <= a << b;
    SRL: out <= a >> b;  
    default: out <= 8'bx;
  endcase
end

always_comb begin
  zero = (out == 0);
end

endmodule
