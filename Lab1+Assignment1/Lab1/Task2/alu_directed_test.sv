module alu_directed_test;
  timeunit 1ns;
  timeprecision 100ps;

  logic        clk = 1'b0;
  logic [7:0]  a, b;
  logic [7:0]  out;
  logic        zero;
  opcode_t     opcode;

  `define PERIOD 10

  // Clock generation
  always #(`PERIOD/2) clk = ~clk;

  // DUT
  alu dut (
    .out(out),
    .zero(zero),
    .clk(clk),
    .a(a),
    .b(b),
    .opcode(opcode)
  );

  // Checker task
  task expected (
    input [7:0] exp_out,
    input       exp_zero
  );
    if (out !== exp_out || zero !== exp_zero) begin
      $display("FAIL: opcode=%0d a=%h b=%h out=%h (exp=%h) zero=%b (exp=%b)",
               opcode, a, b, out, exp_out, zero, exp_zero);
      $finish;
    end
  endtask

  initial begin
    $timeformat(-9, 1, " ns", 9);
    $monitor("time=%t opcode=%0d a=%h b=%h out=%h zero=%b",
              $time, opcode, a, b, out, zero);

    @(negedge clk)
    // ADD
    a = 8'h05; b = 8'h03; opcode = ADD;
    @(negedge clk); expected(8'h08, 1'b0);

    // SUB
    a = 8'h05; b = 8'h05; opcode = SUB;
    @(negedge clk); expected(8'h00, 1'b1);

    // OR (actually multiply!)
    a = 8'h04; b = 8'h03; opcode = OR;
    @(negedge clk); expected(8'h0C, 1'b0);

    // AND (actually OR)
    a = 8'h0A; b = 8'h05; opcode = AND;
    @(negedge clk); expected(8'h0F, 1'b0);

    // XOR (actually AND)
    a = 8'h0A; b = 8'h03; opcode = XOR;
    @(negedge clk); expected(8'h02, 1'b0);

    // SLL (actually XOR)
    a = 8'h0F; b = 8'hF0; opcode = SLL;
    @(negedge clk); expected(8'hFF, 1'b0);

    // SRL (actually left shift)
    a = 8'h01; b = 8'h03; opcode = SRL;
    @(negedge clk); expected(8'h08, 1'b0);

    // SLT (actually right shift)
    a = 8'h80; b = 8'h07; opcode = SLT;
    @(negedge clk); expected(8'h01, 1'b0);

    $display("ALU DIRECTED TEST PASSED");
    $finish;
  end
endmodule
