module mem_test (
input logic clk, 
output logic read, 
output logic write, 
output logic [4:0] addr, 
output logic [7:0] data_in,    // data TO memory
input  logic [7:0] data_out     // data FROM memory
);

timeunit 1ns;
timeprecision 1ns;

bit debug = 1;
logic [7:0] rdata;      // stores data read from memory for checking

`define PERIOD 10

// Monitor Results
  initial begin
      $timeformat ( -9, 1, " ns", 9 );
      #(`PERIOD*4000) $display ( "MEMORY TEST TIMEOUT" );
      $finish;
    end

initial
  begin: memtest
  int error_status;

    $display("Clear Memory Test");
    error_status = 0;

    for (int i = 0; i< 32; i++)
       write_mem(.waddr(i), .wdata(8'h00), .debug(debug));

    for (int i = 0; i<32; i++)
      begin 
       read_mem(.raddr(i), .rdata(rdata), .debug(debug));
       if (rdata !== 8'h00)
         begin
           $display("ERROR: addr %0d expected 00, got %0h", i, rdata);
           error_status++;
         end
      end

   printstatus(error_status);

    $display("Data = Address Test");
    error_status = 0;

    for (int i = 0; i< 32; i++)
       write_mem(.waddr(i), .wdata(i[7:0]), .debug(debug));
       
    for (int i = 0; i<32; i++)
      begin
       read_mem(.raddr(i), .rdata(rdata), .debug(debug));
       if (rdata !== i[7:0])
         begin
           $display("ERROR: addr %0d expected %0h, got %0h", i, i[7:0], rdata);
           error_status++;
         end
      end

   printstatus(error_status);

    $finish;
  end: memtest

// --- write_mem task ---
task write_mem(input logic [4:0] waddr,
               input logic [7:0] wdata,
               input bit debug = 0);
  @(negedge clk);
  addr    = waddr;
  data_in = wdata;
  write   = 1;
  read    = 0;
  @(negedge clk);
  write = 0;
  if (debug)
    $display("WRITE: addr=%0d data=%0h", waddr, wdata);
endtask

// --- read_mem task ---
task read_mem(input  logic [4:0] raddr,
              output logic [7:0] rdata,
              input  bit debug = 0);
  @(negedge clk);
  addr  = raddr;
  write = 0;
  read  = 1;
  @(negedge clk);
  read  = 0;
  rdata = data_out;   // blocking assign so caller gets the value
  if (debug)
    $display("READ:  addr=%0d data=%0h", raddr, rdata);
endtask

// --- printstatus void function ---
function void printstatus(input int status);
  if (status == 0)
    $display("TEST PASSED");
  else
    $display("TEST FAILED with %0d errors", status);
endfunction
  
initial begin
  $dumpfile("signals.vcd");
  $dumpvars(1);
end

endmodule
