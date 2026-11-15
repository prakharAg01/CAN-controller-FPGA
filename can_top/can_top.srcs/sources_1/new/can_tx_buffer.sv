// =============================================================================
// Module      : can_tx_buffer
// Description : Single-slot TX message buffer.
//               Host writes one CAN frame; BSP handshake signals when done.
//               Holds exactly one pending frame at a time (simple, clean).
//
//   Host interface:
//     tx_write        — 1-clk strobe: load frame if not busy
//     tx_id[10:0]     — CAN 2.0A base identifier
//     tx_rtr          — Remote Transmission Request bit
//     tx_dlc[3:0]     — Data Length Code (0–8)
//     tx_data[63:0]   — Payload bytes
//
//   BSP handshake (outputs driven continuously while pending):
//     bsp_tx_request  — held HIGH while a frame is waiting
//     bsp_tx_id       — forwarded identifier
//     bsp_tx_rtr      — forwarded RTR
//     bsp_tx_dlc      — forwarded DLC
//     bsp_tx_data     — forwarded payload
//
//   BSP completion (input, 1-clk pulse):
//     bsp_tx_done     — pulse from BSP when frame is transmitted; clears slot
//
//   Status:
//     tx_ready        — HIGH when slot is free (host may write)
//     tx_busy         — HIGH while frame pending
//
// Day 25      : TX Buffer + RX FIFO (Inferred Block RAM)
// =============================================================================

module can_tx_buffer (
    input  logic        clk,
    input  logic        rst_n,

    // Host write interface
    input  logic        tx_write,
    input  logic [10:0] tx_id,
    input  logic        tx_rtr,
    input  logic [3:0]  tx_dlc,
    input  logic [63:0] tx_data,

    // BSP handshake outputs
    output logic        bsp_tx_request,
    output logic [10:0] bsp_tx_id,
    output logic        bsp_tx_rtr,
    output logic [3:0]  bsp_tx_dlc,
    output logic [63:0] bsp_tx_data,

    // BSP completion input (1-clk pulse)
    input  logic        bsp_tx_done,

    // Status
    output logic        tx_ready,
    output logic        tx_busy
);

    // Internal storage registers
    logic        pending;
    logic [10:0] stored_id;
    logic        stored_rtr;
    logic [3:0]  stored_dlc;
    logic [63:0] stored_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending     <= 1'b0;
            stored_id   <= 11'd0;
            stored_rtr  <= 1'b0;
            stored_dlc  <= 4'd0;
            stored_data <= 64'd0;
        end else begin
            // Allow back-to-back enqueue: if bsp_tx_done arrives simultaneously with tx_write,
            // or if slot is empty (!pending) and tx_write arrives:
            if (tx_write && (!pending || bsp_tx_done)) begin
                pending     <= 1'b1;
                stored_id   <= tx_id;
                stored_rtr  <= tx_rtr;
                stored_dlc  <= tx_dlc;
                stored_data <= tx_data;
            end else if (bsp_tx_done) begin
                pending     <= 1'b0;
            end
        end
    end

    // Continuous BSP drive
    assign bsp_tx_request = pending;
    assign bsp_tx_id      = stored_id;
    assign bsp_tx_rtr     = stored_rtr;
    assign bsp_tx_dlc     = stored_dlc;
    assign bsp_tx_data    = stored_data;

    // Status
    assign tx_ready = !pending || bsp_tx_done;
    assign tx_busy  = pending && !bsp_tx_done;

endmodule
