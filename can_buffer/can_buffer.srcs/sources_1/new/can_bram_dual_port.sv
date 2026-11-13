// =============================================================================
// Module      : can_bram_dual_port
// Description : Reusable inferred dual-port Block RAM primitive.
//               Port A = write-only (synchronous).
//               Port B = read-only  (synchronous, 1-cycle registered latency).
//               Vivado infers RAMB18E1 / RAMB36E1 automatically from this
//               template — no IP catalog needed.
//
// Day 25      : TX Buffer + RX FIFO (Inferred Block RAM)
// Trade-off   : Registered read adds 1-cycle read latency vs. the paper's
//               async LUTRAM approach, but maps to dedicated BRAM tiles
//               (lower LUT usage, better timing on large depths).
// =============================================================================

module can_bram_dual_port #(
    parameter DATA_WIDTH = 80,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                  clk,

    // Port A — Write
    input  logic                  we_a,
    input  logic [ADDR_WIDTH-1:0] addr_a,
    input  logic [DATA_WIDTH-1:0] din_a,

    // Port B — Read (registered: data valid 1 cycle after addr_b)
    input  logic [ADDR_WIDTH-1:0] addr_b,
    output logic [DATA_WIDTH-1:0] dout_b
);

    // Memory array — Vivado infers BRAM from this pattern
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Port A : synchronous write
    always_ff @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= din_a;
    end

    // Port B : synchronous (registered) read — required for BRAM inference
    always_ff @(posedge clk) begin
        dout_b <= mem[addr_b];
    end

endmodule
