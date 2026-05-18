# DDV — Digital Design Verification

SystemVerilog coursework for CE446 (Digital Design Verification): lab exercises and assignments covering RTL design, verification testbenches, and CDC-safe FIFO design.

## Contents

### `Lab1+Assignment1/`

**`Lab1/Task1/` — 8-bit Register**
- `register.sv` — Synchronous 8-bit register with active-low async reset and enable.
- `register_directed_test.sv` — Directed stimulus covering reset, hold, load behaviour.
- `register_random_test.sv` — Randomized stimulus with a reference model checker (50 iterations).

**`Lab1/Task2/` — 8-bit ALU**
- `alu.sv` — 8-operand ALU (ADD, SUB, MUL, OR, AND, XOR, SLL, SRL) with `zero` flag, declared via an `opcode_t` enum.
- `alu_directed_test.sv` — Hand-picked vectors per opcode.
- `alu_random_test.sv` — Randomized stimulus with golden-model comparison (50 iterations).

**`Assignment1/` — FIFO Designs**
- `sync_fifo.sv` + `sync_fifo_tb.sv` — Parameterized single-clock FIFO (default 8b × 16 deep) using N+1-bit pointers with a wrap-bit to disambiguate full vs. empty. The testbench exercises reset, single-write, fill-to-full, write-when-full guard, drain-and-verify, read-when-empty guard, and simultaneous read+write.
- `async_fifo.sv` + `async_fifo_tb.sv` — Dual-clock asynchronous FIFO based on Clifford Cummings' design: Gray-coded pointers with two-flop synchronizers (`sync_r2w`, `sync_w2r`) for safe CDC. The testbench runs with mismatched `wclk` (10 ns) and `rclk` (7 ns) periods to stress the synchronizers.

### `Lab2/` — Synchronous 8×32 Memory

- `mem.sv` — Memory module (8 bits wide, 32 entries). Writes commit on `posedge clk` when `write && !read`; reads use `always_ff` with `iff` event control.
- `mem_test.sv` — Testbench with `write_mem`/`read_mem` tasks; runs a clear-memory sweep and a data-equals-address sweep. Dumps `signals.vcd`.
- `top.sv` — Top-level harness wiring the testbench to the DUT using SystemVerilog's `.*` and `.name` port shorthands.

### `A2/` — RISC Controller FSM

- `typedefs.sv` — `typedefs` package defining `opcode_t` (HLT, SKZ, ADD, AND, XOR, LDA, STO, JMP) and `state_t` (INST_ADDR → STORE) enums with explicit 3-bit encodings.
- `control.sv` — Finite-state controller for a small RISC processor. Outputs `load_ac`, `mem_rd`, `mem_wr`, `inc_pc`, `load_pc`, `load_ir`, `halt` based on the current state and decoded opcode.
- `control_test.sv` — Self-checking testbench that drives stimulus from `stimulus.pat` and verifies the response bus against `response.pat`.
- `Console_Output.png`, `Waveform_1..4.png` — Captured simulation results.

## Tools

Written for and simulated with Xilinx Vivado / Cadence Xcelium. Any SystemVerilog-2012-compliant simulator should work.

## Course

CE446 — Digital Design Verification.
