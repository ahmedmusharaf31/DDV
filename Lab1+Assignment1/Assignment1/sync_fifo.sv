// Single-clock FIFO. One clock, one reset, simple as it gets.
// Reads and writes both happen on the rising edge. RST is active-high
// and asynchronous, so it takes effect the moment you pull it high.
module sync_fifo #(
    parameter int W = 8,   // bit width of each word
    parameter int D = 16   // total number of words it can hold
) (
    input  logic             CLK,
    input  logic             RST,       // pull high any time to clear everything
    input  logic [W-1:0]     DIN,
    input  logic             WEn,       // high for one cycle to push DIN in
    input  logic             REn,       // high for one cycle to pop the front word into DOUT
    output logic [W-1:0]     DOUT,
    output logic             Full,
    output logic             Empty,
    output logic [$clog2(D)-1:0] RPTR,
    output logic [$clog2(D)-1:0] WPTR
);

    localparam int N = $clog2(D);  // how many bits we need to address D slots

    logic [W-1:0] mem [D];  // the storage itself

    // Both pointers are N+1 bits wide. The extra MSB is a wrap flag — it flips
    // every time the pointer wraps around. That's what lets us distinguish
    // "full" from "empty" when both pointers land on the same address.
    logic [N:0] wptr_int, rptr_int;

    // Only expose the address bits to the outside world
    assign WPTR  = wptr_int[N-1:0];
    assign RPTR  = rptr_int[N-1:0];

    // If all N+1 bits match, read has caught up — nothing left to read
    assign Empty = (wptr_int == rptr_int);

    // If just the MSBs differ but the addresses match, write has lapped read once — no room left
    assign Full  = (wptr_int[N] != rptr_int[N]) &&
                   (wptr_int[N-1:0] == rptr_int[N-1:0]);

    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            // Wipe both pointers and the output on reset
            wptr_int <= '0;
            rptr_int <= '0;
            DOUT     <= '0;
        end else begin
            if (WEn && !Full) begin   // ignore writes if there's no space
                mem[WPTR]  <= DIN;
                wptr_int   <= wptr_int + 1'b1;
            end
            if (REn && !Empty) begin  // ignore reads if there's nothing there
                DOUT     <= mem[RPTR];
                rptr_int <= rptr_int + 1'b1;
            end
        end
    end

endmodule