module sync_fifo_tb;
    timeunit 1ns;
    timeprecision 100ps;

    localparam int W = 8;
    localparam int D = 16;
    localparam int N = $clog2(D);

    `define PERIOD 10

    // Start everything inactive so nothing fires before we're ready
    logic             CLK  = 1'b0;
    logic             RST  = 1'b0;
    logic [W-1:0]     DIN  = '0;
    logic             WEn  = 1'b0;
    logic             REn  = 1'b0;

    logic [W-1:0]     DOUT;
    logic             Full, Empty;
    logic [N-1:0]     RPTR, WPTR;

    always #(`PERIOD/2) CLK = ~CLK;

    // Hook up the DUT — .* wires everything by matching port names
    sync_fifo #(.W(W), .D(D)) dut (.*);

    // Checks Full and Empty against what we expect — fails loudly if they're wrong
    task check_flags(input exp_full, input exp_empty);
        if (Full !== exp_full || Empty !== exp_empty) begin
            $display("FLAG FAIL: Full=%b(exp=%b) Empty=%b(exp=%b)",
                     Full, exp_full, Empty, exp_empty);
            $display("SYNC FIFO TEST FAILED");
            $finish;
        end
    endtask

    // Checks DOUT against what we expect — fails loudly if they don't match
    task check_dout(input [W-1:0] exp);
        if (DOUT !== exp) begin
            $display("DATA FAIL: DOUT=%h exp=%h", DOUT, exp);
            $display("SYNC FIFO TEST FAILED");
            $finish;
        end
    endtask

    // Keeps a copy of everything we've written so we know what should come out on reads
    logic [W-1:0] ref_q[$];
    logic [N-1:0] prev_ptr;

    initial begin
        $dumpfile("sync_fifo.vcd");
        $dumpvars(0, sync_fifo_tb);
    end

    initial begin
        $timeformat(-9, 1, " ns", 9);

        // T1: pull reset and confirm the FIFO comes up clean
        $display("[T1] Reset...");
        RST = 1;
        @(negedge CLK); @(negedge CLK);
        if (!Empty || Full || WPTR !== '0 || RPTR !== '0) begin
            $display("RESET CHECK FAILED");
            $display("SYNC FIFO TEST FAILED");
            $finish;
        end
        RST = 0;
        $display("[T1] PASS: Empty=%b Full=%b WPTR=%0d RPTR=%0d", Empty, Full, WPTR, RPTR);

        // T2: write one word and check that Empty drops and WPTR moves by 1
        $display("[T2] Single write (0xA5)...");
        @(negedge CLK);
        WEn = 1; DIN = 8'hA5;
        @(negedge CLK);
        WEn = 0;
        ref_q.push_back(8'hA5);
        check_flags(1'b0, 1'b0);
        if (WPTR !== 1) begin
            $display("WPTR FAIL after single write: got %0d exp 1", WPTR);
            $display("SYNC FIFO TEST FAILED"); $finish;
        end
        $display("[T2] PASS: Empty=%b Full=%b WPTR=%0d", Empty, Full, WPTR);

        // T3: fill all remaining slots and confirm Full asserts
        $display("[T3] Fill to full (%0d words)...", D);
        for (int i = 1; i < D; i++) begin
            @(negedge CLK);
            WEn = 1; DIN = 8'(i);
            @(negedge CLK);
            WEn = 0;
            ref_q.push_back(8'(i));
        end
        check_flags(1'b1, 1'b0);
        $display("[T3] PASS: Full=%b Empty=%b", Full, Empty);

        // T4: try sneaking in one more write — WPTR must not budge
        $display("[T4] Write-when-full guard...");
        prev_ptr = WPTR;
        @(negedge CLK);
        WEn = 1; DIN = 8'hFF;
        @(negedge CLK);
        WEn = 0;
        if (WPTR !== prev_ptr) begin
            $display("WRITE-WHEN-FULL GUARD FAILED: WPTR changed to %0d", WPTR);
            $display("SYNC FIFO TEST FAILED"); $finish;
        end
        check_flags(1'b1, 1'b0);
        $display("[T4] PASS: WPTR held at %0d", WPTR);

        // T5: read everything back and check each word matches what we wrote
        $display("[T5] Drain and verify %0d words...", D);
        REn = 1;
        for (int i = 0; i < D; i++) begin
            @(negedge CLK);    // DOUT updates on the posedge that just passed
            check_dout(ref_q.pop_front());
        end
        REn = 0;
        check_flags(1'b0, 1'b1);
        $display("[T5] PASS: all words matched, Empty=%b Full=%b", Empty, Full);

        // T6: try sneaking in a read when empty — RPTR must not budge
        $display("[T6] Read-when-empty guard...");
        prev_ptr = RPTR;
        @(negedge CLK);
        REn = 1;
        @(negedge CLK);
        REn = 0;
        if (RPTR !== prev_ptr) begin
            $display("READ-WHEN-EMPTY GUARD FAILED: RPTR changed to %0d", RPTR);
            $display("SYNC FIFO TEST FAILED"); $finish;
        end
        check_flags(1'b0, 1'b1);
        $display("[T6] PASS: RPTR held at %0d", RPTR);

        // T7: raise WEn and REn at the same time — the oldest word should pop out
        // while the new one lands in, and neither pointer should be confused
        $display("[T7] Simultaneous read+write...");
        @(negedge CLK); WEn = 1; DIN = 8'hDE; @(negedge CLK); WEn = 0;
        @(negedge CLK); WEn = 1; DIN = 8'hAD; @(negedge CLK); WEn = 0;
        @(negedge CLK);
        WEn = 1; REn = 1; DIN = 8'hBE;
        @(negedge CLK);
        WEn = 0; REn = 0;
        check_dout(8'hDE);  // 0xDE went in first, so it should come out first
        $display("[T7] PASS: DOUT=%h (expected 0xDE)", DOUT);

        $display("SYNC FIFO TEST PASSED");
        $finish;
    end

    // Kill the sim if it's still running after this — something must be stuck
    initial begin
        #(`PERIOD * 500)
        $display("SYNC FIFO TEST TIMEOUT");
        $finish;
    end

endmodule