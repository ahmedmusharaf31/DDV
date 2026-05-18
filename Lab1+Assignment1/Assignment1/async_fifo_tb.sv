module async_fifo_tb;
    timeunit 1ns;
    timeprecision 100ps;

    localparam int DATASIZE = 8;
    localparam int ADDRSIZE = 3;
    localparam int DEPTH    = 1 << ADDRSIZE;  // 8 words

    // Deliberately different clock speeds to stress the CDC paths.
    // If the synchronizers are working correctly, the mismatched frequencies won't matter.
    // wclk = 10 ns period, rclk = 7 ns period
    logic wclk   = 1'b0;
    logic rclk   = 1'b0;

    // Start everything inactive
    logic                 wrst_n = 1'b1;
    logic                 rrst_n = 1'b1;
    logic                 winc   = 1'b0;
    logic                 rinc   = 1'b0;
    logic [DATASIZE-1:0]  wdata  = '0;

    logic [DATASIZE-1:0]  rdata;
    logic                 wfull;
    logic                 rempty;
    logic [ADDRSIZE:0]    wptr,  rptr;
    logic [ADDRSIZE-1:0]  waddr, raddr;

    always #5   wclk = ~wclk;
    always #3.5 rclk = ~rclk;

    async_fifo #(.DATASIZE(DATASIZE), .ADDRSIZE(ADDRSIZE)) dut (.*);

    // Keeps a copy of every word we write in, so we can check reads come out in the right order
    logic [DATASIZE-1:0] ref_q[$];
    logic [DATASIZE-1:0] exp_data;

    initial begin
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, async_fifo_tb);
    end

    initial begin
        $timeformat(-9, 1, " ns", 9);

        // T1: reset both domains and confirm the FIFO starts empty
        $display("[T1] Reset...");
        wrst_n = 0; rrst_n = 0;
        repeat(4) @(posedge wclk);   // hold long enough for both domains to settle
        repeat(4) @(posedge rclk);
        wrst_n = 1; rrst_n = 1;
        repeat(2) @(posedge rclk);

        if (!rempty || wfull) begin
            $display("RESET CHECK FAILED: rempty=%b wfull=%b", rempty, wfull);
            $display("ASYNC FIFO TEST FAILED"); $finish;
        end
        $display("[T1] PASS: rempty=%b wfull=%b", rempty, wfull);

        // T2: write all DEPTH words in, one per wclk cycle
        $display("[T2] Writing %0d words...", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            @(negedge wclk);
            winc  = 1'b1;
            wdata = 8'(i + 1);
            @(posedge wclk);       // write commits here
            @(negedge wclk);
            winc  = 1'b0;
            ref_q.push_back(8'(i + 1));
            $display("[T2]   wrote 0x%h (entry %0d)", 8'(i + 1), i);
        end

        // The wptr needs a couple of cycles to ripple through the synchronizer
        // into the read domain before wfull actually asserts
        repeat(4) @(posedge wclk);
        if (!wfull) begin
            $display("WFULL NOT ASSERTED after writing %0d items", DEPTH);
            $display("ASYNC FIFO TEST FAILED"); $finish;
        end
        $display("[T2] PASS: wfull=%b after writing %0d words", wfull, DEPTH);

        // T3: wptr needs time to cross into rclk before rempty can drop
        $display("[T3] Waiting for rempty to deassert (CDC latency)...");
        repeat(8) @(posedge rclk);
        if (rempty) begin
            $display("REMPTY STILL HIGH after writes");
            $display("ASYNC FIFO TEST FAILED"); $finish;
        end
        $display("[T3] PASS: rempty=%b", rempty);

        // T4: read all words back and compare each one to our shadow queue.
        // rdata is combinational, so we check the current word BEFORE pulsing rinc,
        // then pulse rinc to move raddr on to the next slot.
        $display("[T4] Reading and verifying %0d words...", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            exp_data = ref_q.pop_front();
            if (rdata !== exp_data) begin
                $display("READ FAIL i=%0d: rdata=%h exp=%h", i, rdata, exp_data);
                $display("ASYNC FIFO TEST FAILED"); $finish;
            end
            $display("[T4]   read 0x%h == exp 0x%h OK", rdata, exp_data);
            @(negedge rclk);
            rinc = 1'b1;
            @(posedge rclk);       // raddr steps forward here
            @(negedge rclk);
            rinc = 1'b0;
        end
        $display("[T4] PASS: all words matched");

        // T5: now that we've drained everything, rempty should come back up
        $display("[T5] Waiting for rempty to reassert after drain...");
        repeat(8) @(posedge rclk);
        if (!rempty) begin
            $display("REMPTY NOT ASSERTED after draining FIFO");
            $display("ASYNC FIFO TEST FAILED"); $finish;
        end
        $display("[T5] PASS: rempty=%b", rempty);

        $display("ASYNC FIFO TEST PASSED");
        $finish;
    end

    // If we're still running after 5000 ns something is definitely stuck
    initial begin
        #5000
        $display("ASYNC FIFO TEST TIMEOUT");
        $finish;
    end

endmodule