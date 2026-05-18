// Just the storage — a simple dual-port RAM.
// The write side is clocked (needs a rising wclk edge to commit data).
// The read side is combinational, so rdata just follows raddr with no clock needed.
module fifo_mem #(
    parameter int DATASIZE = 8,
    parameter int ADDRSIZE = 3    // gives us 2^ADDRSIZE storage slots
) (
    output logic [DATASIZE-1:0] rdata,
    input  logic [DATASIZE-1:0] wdata,
    input  logic [ADDRSIZE-1:0] waddr,
    input  logic [ADDRSIZE-1:0] raddr,
    input  logic                wclken,  // only write when this is high — it's winc gated by !wfull
    input  logic                wclk
);

    localparam DEPTH = 1 << ADDRSIZE;

    logic [DATASIZE-1:0] mem [DEPTH];

    // rdata is always live — no clock, no enable, just wires to the array
    assign rdata = mem[raddr];

    // Writes commit on the rising edge, but only if we're allowed to
    always_ff @(posedge wclk) begin
        if (wclken) mem[waddr] <= wdata;
    end

endmodule

// Moves rptr from the read clock domain into the write clock domain.
// Two flip-flops in series is the standard trick for this — the first flop
// might go metastable if it catches a transition, but by the time it's
// sampled by the second flop it will have resolved to a clean 0 or 1.
module sync_r2w #(
    parameter int ADDRSIZE = 3
) (
    output logic [ADDRSIZE:0] wq2_rptr,  // the "safe" rptr, now in wclk's world
    input  logic [ADDRSIZE:0] rptr,      // raw rptr from the read side — don't touch directly
    input  logic              wclk,
    input  logic              wrst_n     // active-low, hold low to reset
);

    logic [ADDRSIZE:0] wq1_rptr;  // the middle flop — might be metastable briefly, that's fine

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) {wq2_rptr, wq1_rptr} <= '0;
        else         {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr};
    end

endmodule

// Same idea as sync_r2w, just going the other way — wptr from wclk into rclk.
module sync_w2r #(
    parameter int ADDRSIZE = 3
) (
    output logic [ADDRSIZE:0] rq2_wptr,  // the "safe" wptr, now in rclk's world
    input  logic [ADDRSIZE:0] wptr,      // raw wptr from the write side — don't touch directly
    input  logic              rclk,
    input  logic              rrst_n     // active-low, hold low to reset
);

    logic [ADDRSIZE:0] rq1_wptr;  // middle flop

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) {rq2_wptr, rq1_wptr} <= '0;
        else         {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr};
    end

endmodule

// Tracks where the next write goes and decides when the FIFO is full.
// Everything here is clocked by wclk — the read side never touches this.
//
// We keep an internal binary counter for the actual memory address,
// but what we export is the Gray-code version. Gray code only changes
// one bit at a time, which is the only way it's safe to hand a pointer
// to another clock domain without risking a garbage value being sampled.
module wptr_handler #(
    parameter int ADDRSIZE = 3
) (
    output logic [ADDRSIZE-1:0] waddr,     // where in memory the next write goes
    output logic [ADDRSIZE:0]   wptr,      // Gray-coded version, sent to the read domain
    output logic                wfull,
    input  logic [ADDRSIZE:0]   wq2_rptr,  // rptr after it's been synced into our clock domain
    input  logic                winc,
    input  logic                wclk,
    input  logic                wrst_n
);

    logic [ADDRSIZE:0] wbin;               // the raw binary counter we keep internally
    logic [ADDRSIZE:0] wbin_next, wgray_next;
    logic              wfull_val;

    // Only advance if we're actively writing and not already full
    assign wbin_next  = wbin + {{ADDRSIZE{1'b0}}, (winc & ~wfull)};

    // Gray encode: XOR the value with itself shifted right by 1
    assign wgray_next = wbin_next ^ (wbin_next >> 1);

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) {wbin, wptr} <= '0;
        else         {wbin, wptr} <= {wbin_next, wgray_next};
    end

    // The memory just needs the raw address, not the wrap bit
    assign waddr = wbin[ADDRSIZE-1:0];

    // Full in Gray code means: the top two bits are flipped relative to rptr,
    // and every other bit matches. This comes straight from Clifford Cummings'
    // async FIFO paper and is the correct way to detect full across domains.
    assign wfull_val = (wgray_next == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1],
                                        wq2_rptr[ADDRSIZE-2:0]});

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) wfull <= 1'b0;
        else         wfull <= wfull_val;
    end

endmodule

// Tracks where the next read comes from and decides when the FIFO is empty.
// Everything here is clocked by rclk — the write side never touches this.
// Same Gray-code approach as wptr_handler, just mirrored for the read side.
module rptr_handler #(
    parameter int ADDRSIZE = 3
) (
    output logic [ADDRSIZE-1:0] raddr,     // where in memory we're reading from right now
    output logic [ADDRSIZE:0]   rptr,      // Gray-coded version, sent to the write domain
    output logic                rempty,
    input  logic [ADDRSIZE:0]   rq2_wptr,  // wptr after it's been synced into our clock domain
    input  logic                rinc,
    input  logic                rclk,
    input  logic                rrst_n
);

    logic [ADDRSIZE:0] rbin;
    logic [ADDRSIZE:0] rbin_next, rgray_next;
    logic              rempty_val;

    // Only advance if we're actively reading and there's actually something to read
    assign rbin_next  = rbin + {{ADDRSIZE{1'b0}}, (rinc & ~rempty)};

    assign rgray_next = rbin_next ^ (rbin_next >> 1);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) {rbin, rptr} <= '0;
        else         {rbin, rptr} <= {rbin_next, rgray_next};
    end

    assign raddr = rbin[ADDRSIZE-1:0];

    // Empty when our Gray pointer matches the synced write pointer — we've caught up
    assign rempty_val = (rgray_next == rq2_wptr);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) rempty <= 1'b1;   // FIFO is empty right after reset, that's correct
        else         rempty <= rempty_val;
    end

endmodule

// The top level — just connects all the pieces together.
// wclk and rclk are totally independent; they don't need to be related at all.
// Pointers cross the boundary through the two synchronizers above,
// so neither side ever reads a signal that belongs to the other clock domain directly.
module async_fifo #(
    parameter int DATASIZE = 8,
    parameter int ADDRSIZE = 3    // depth = 2^ADDRSIZE; must be a power of two
) (
    // Write side
    input  logic                 wclk,
    input  logic                 wrst_n,
    input  logic                 winc,
    input  logic [DATASIZE-1:0]  wdata,
    output logic                 wfull,
    output logic [ADDRSIZE:0]    wptr,    // crosses into the read domain via sync_r2w
    output logic [ADDRSIZE-1:0]  waddr,   // goes straight to the memory

    // Read side
    input  logic                 rclk,
    input  logic                 rrst_n,
    input  logic                 rinc,
    output logic [DATASIZE-1:0]  rdata,
    output logic                 rempty,
    output logic [ADDRSIZE:0]    rptr,    // crosses into the write domain via sync_w2r
    output logic [ADDRSIZE-1:0]  raddr    // goes straight to the memory
);

    // These carry each pointer after it's been safely moved to the other domain
    logic [ADDRSIZE:0] wq2_rptr;  // rptr, now safe to use in wclk
    logic [ADDRSIZE:0] rq2_wptr;  // wptr, now safe to use in rclk

    // Gate the memory write — don't commit anything if we're full
    logic wclken;
    assign wclken = winc & ~wfull;

    // The shared memory — both sides talk to it but through their own address ports
    fifo_mem #(.DATASIZE(DATASIZE), .ADDRSIZE(ADDRSIZE)) u_mem (
        .rdata  (rdata),
        .wdata  (wdata),
        .waddr  (waddr),
        .raddr  (raddr),
        .wclken (wclken),
        .wclk   (wclk)
    );

    // Ferry rptr over to the write side
    sync_r2w #(.ADDRSIZE(ADDRSIZE)) u_sync_r2w (
        .wq2_rptr (wq2_rptr),
        .rptr     (rptr),
        .wclk     (wclk),
        .wrst_n   (wrst_n)
    );

    // Ferry wptr over to the read side
    sync_w2r #(.ADDRSIZE(ADDRSIZE)) u_sync_w2r (
        .rq2_wptr (rq2_wptr),
        .wptr     (wptr),
        .rclk     (rclk),
        .rrst_n   (rrst_n)
    );

    // Write pointer logic lives entirely in wclk
    wptr_handler #(.ADDRSIZE(ADDRSIZE)) u_wptr (
        .waddr    (waddr),
        .wptr     (wptr),
        .wfull    (wfull),
        .wq2_rptr (wq2_rptr),
        .winc     (winc),
        .wclk     (wclk),
        .wrst_n   (wrst_n)
    );

    // Read pointer logic lives entirely in rclk
    rptr_handler #(.ADDRSIZE(ADDRSIZE)) u_rptr (
        .raddr    (raddr),
        .rptr     (rptr),
        .rempty   (rempty),
        .rq2_wptr (rq2_wptr),
        .rinc     (rinc),
        .rclk     (rclk),
        .rrst_n   (rrst_n)
    );

endmodule