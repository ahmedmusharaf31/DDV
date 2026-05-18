module alu_random_test;
  timeunit 1ns;
  timeprecision 100ps;

  logic        clk = 1'b0;
  logic [7:0]  a, b;
  logic [7:0]  out;
  logic        zero;
  opcode_t     opcode;

  `define PERIOD 10

  always #(`PERIOD/2) clk = ~clk;

  alu dut (
    .out(out),
    .zero(zero),
    .clk(clk),
    .a(a),
    .b(b),
    .opcode(opcode)
  );

task check(input [7:0] a, input [7:0] b, input opcode_t opcode);
    logic [7:0] exp;
    case (opcode)
        ADD: exp = a + b;
        SUB: exp = a - b;
        MUL: exp = a * b;
        OR:  exp = a | b;
        AND: exp = a & b;
        XOR: exp = a ^ b;
        SLL: exp = a << b;
        SRL: exp = a >> b;
        default: exp = 8'hxx;
    endcase
    if (out !== exp || zero !== (exp == 0)) begin
        $display("FAIL: opcode=%0d a=%h b=%h out=%h (exp=%h) zero=%b (exp=%b)",
                  opcode, a, b, out, exp, zero, (exp == 0));
        $finish;
    end
endtask

  initial begin
    $timeformat(-9, 1, " ns", 9);
    $monitor("time=%t a=%h b=%h opcode=%0d out=%h zero=%b", $time, a, b, opcode, out, zero);
    
    @(negedge clk)
    repeat (50) begin
      a      = $urandom;
      b      = $urandom;
      opcode = opcode_t'($urandom % 8);

      @(negedge clk);
      check(a, b, opcode);
    end

    $display("ALU RANDOM TEST PASSED");
    $finish;
  end
endmodule
