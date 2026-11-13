// =============================================================================
// Module      : can_rx_fifo
// Description : RX message FIFO using inferred Block RAM with FWFT output.
//               Stores received CAN 2.0A frames; host pops from head.
//
//   CAN message word = 80 bits:
//     [79:69] id[10:0]   — 11-bit base identifier
//     [68]    rtr        — Remote Transmission Request
//     [67:64] dlc[3:0]   — Data Length Code
//     [63:0]  data[63:0] — 8-byte payload
//
//   Clean FWFT Implementation for synchronous 1-cycle BRAM:
//     - addr_b always reads rd_ptr.
//     - BRAM data output is valid one cycle later.
//     - An output skid/holding register holds the head word.
//     - When empty, first push bypasses directly into the output register.
//     - While non-empty, every pop advances rd_ptr to pre-fetch next word.
//
// Day 25      : TX Buffer + RX FIFO (Inferred Block RAM)
// =============================================================================

module can_rx_fifo #(
    parameter DEPTH  = 16,
    parameter DATA_W = 80
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              clear,

    // Push side
    input  logic              push,
    input  logic [DATA_W-1:0] rx_in,      // {id[10:0], rtr, dlc[3:0], data[63:0]}
    input  logic              accept_in,  // acceptance filter gate

    // Pop side
    input  logic              pop,
    output logic [DATA_W-1:0] rx_out,     // FWFT head element
    output logic [10:0]       rx_out_id,
    output logic              rx_out_rtr,
    output logic [3:0]        rx_out_dlc,
    output logic [63:0]       rx_out_data,

    // Status
    output logic              empty,
    output logic              full,
    output logic              almost_full,
    output logic              overrun,
    output logic [$clog2(DEPTH):0] count
);

    localparam ADDR_W = $clog2(DEPTH);

    // -----------------------------------------------------------------
    // BRAM instance
    // -----------------------------------------------------------------
    logic              we_a;
    logic [ADDR_W-1:0] addr_a, addr_b;
    logic [DATA_W-1:0] din_a, dout_b;

    can_bram_dual_port #(
        .DATA_WIDTH(DATA_W),
        .DEPTH     (DEPTH),
        .ADDR_WIDTH(ADDR_W)
    ) u_bram (
        .clk    (clk),
        .we_a   (we_a),
        .addr_a (addr_a),
        .din_a  (din_a),
        .addr_b (addr_b),
        .dout_b (dout_b)
    );

    // -----------------------------------------------------------------
    // Pointers & FIFO Count
    // -----------------------------------------------------------------
    logic [ADDR_W-1:0]      wr_ptr;
    logic [ADDR_W-1:0]      rd_ptr;
    logic [$clog2(DEPTH):0] cnt;

    wire push_en = push && accept_in && !full;
    wire pop_en  = pop && !empty;

    assign empty       = (cnt == 0);
    assign full        = (cnt == DEPTH[$clog2(DEPTH):0]);
    assign almost_full = (cnt >= (DEPTH - 2));
    assign count       = cnt;

    // Write Port
    assign we_a   = push_en;
    assign addr_a = wr_ptr;
    assign din_a  = rx_in;

    // Read Port:
    // When popping, we immediately increment the address presented to BRAM
    // so BRAM starts reading the next entry on that rising edge.
    assign addr_b = pop_en ? (rd_ptr + 1'b1) : rd_ptr;

    logic [DATA_W-1:0] head_reg;
    logic              head_valid;
    logic              pending_read;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr       <= '0;
            rd_ptr       <= '0;
            cnt          <= '0;
            overrun      <= 1'b0;
            head_reg     <= '0;
            head_valid   <= 1'b0;
            pending_read <= 1'b0;
        end else if (clear) begin
            wr_ptr       <= '0;
            rd_ptr       <= '0;
            cnt          <= '0;
            overrun      <= 1'b0;
            head_reg     <= '0;
            head_valid   <= 1'b0;
            pending_read <= 1'b0;
        end else begin
            // Overrun detection
            if (push && accept_in && full) begin
                overrun <= 1'b1;
            end

            // Write pointer
            if (push_en) begin
                wr_ptr <= wr_ptr + 1'b1;
            end

            // Read pointer
            if (pop_en) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            // Total count
            case ({push_en, pop_en})
                2'b10:   cnt <= cnt + 1'b1;
                2'b01:   cnt <= cnt - 1'b1;
                default: cnt <= cnt;
            endcase

            // FWFT data capture logic:
            // 1. If FIFO is empty and push occurs:
            if (push_en && empty) begin
                head_reg     <= rx_in;
                head_valid   <= 1'b1;
                pending_read <= 1'b0;
            end
            // 2. If a read was requested from BRAM (due to pop):
            else if (pending_read) begin
                head_reg     <= dout_b;
                head_valid   <= 1'b1;
                // If another pop happened simultaneously while waiting:
                if (pop_en) begin
                    // If more items exist, keep pending_read high
                    pending_read <= (cnt > 2) || (cnt == 2 && push_en);
                end else begin
                    pending_read <= 1'b0;
                end
            end
            // 3. When pop occurs:
            else if (pop_en) begin
                if ((cnt > 1) || (cnt == 1 && push_en)) begin
                    // Request next word from BRAM
                    pending_read <= 1'b1;
                    // head_reg will update in next cycle when dout_b is ready
                end else begin
                    head_valid   <= 1'b0;
                    pending_read <= 1'b0;
                end
            end
        end
    end

    // FWFT Output
    assign rx_out      = head_valid ? head_reg : dout_b;
    assign rx_out_id   = rx_out[79:69];
    assign rx_out_rtr  = rx_out[68];
    assign rx_out_dlc  = rx_out[67:64];
    assign rx_out_data = rx_out[63:0];

endmodule
