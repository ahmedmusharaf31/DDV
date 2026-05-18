module register_random_test;
timeunit 1ns;
timeprecision 100ps;

logic [7:0]   out  ;
logic [7:0]   data ;
logic         enable  ;
logic         rst_ = 1'b1;
logic         clk = 1'b1;

`define PERIOD 10

always
    #(`PERIOD/2) clk = ~clk;

// INSTANCE register 
 register r1 (.enable(enable), .clk(clk), .out(out), .data(data), .rst_(rst_));

  // Monitor Results
  initial
    begin
     $timeformat ( -9, 1, " ns", 9 );
     $monitor ( "time=%t enable=%b rst_=%b data=%h out=%h",
	        $time,   enable,   rst_,   data,   out );
     #(`PERIOD * 99)
     $display ( "REGISTER TEST TIMEOUT" );
     $finish;
    end

// Verify Results
  task expect_test (input reset, input enable, input [7:0] data) ;
    logic [7:0]      expected_out;

    // register model in testbench down here
    if(!reset)       expected_out = 8'b0;
    else if(enable)  expected_out = data;
    // else expected_out remain same

    if ( out !== expected_out)
      begin
        $display ( "out=%b, should be %b", out, expected_out );
        $display ( "REGISTER TEST FAILED" );
        $finish;
      end
  endtask

  initial
    begin

      @(negedge clk)
      repeat(50) begin
        rst_ = ~(($urandom % 8) == 7);  enable = $urandom ;  data = $urandom; @(negedge clk) expect_test (rst_, enable, data);
      end
      
      $display ( "REGISTER TEST PASSED" );
      $finish;
    end
endmodule
