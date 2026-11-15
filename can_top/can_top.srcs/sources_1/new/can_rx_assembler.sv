// =============================================================================
// Module      : can_rx_assembler
// Description : RX Frame Assembler & CRC Checker for CAN 2.0A frames.
//               Monitors de-stuffed protocol bits (rx_data_bit, rx_data_valid)
//               and deserializes them into the received CAN frame:
//                 - Base Identifier (11 bits)
//                 - Remote Transmission Request (1 bit)
//                 - Data Length Code (4 bits)
//                 - Data payload (up to 64 bits)
//                 - Received CRC sequence (15 bits)
//               Calculates running CRC-15 over incoming bits; compares with
//               received CRC sequence to assert 'crc_ok'.
//               When the frame completes successfully at EOF, asserts 'rx_push'
//               to queue the complete 80-bit frame into can_rx_fifo.
//
// Day 27-28   : Top-Level Integration (can_controller_top)
// =============================================================================

module can_rx_assembler (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,

    // BSP / Destuffer inputs
    input  logic [3:0]  bsp_state,       // current BSP FSM state
    input  logic        rx_data_bit,     // de-stuffed protocol bit
    input  logic        rx_data_valid,   // 1-clk strobe: rx_data_bit is valid
    input  logic        frame_valid,     // 1-clk pulse on clean frame completion (eml_rx_success or loopback tx_done)

    // Verification outputs to BSP
    output logic        crc_ok,          // 1 = received CRC matches computed CRC

    // Assembled frame output to RX FIFO
    output logic        rx_push,         // 1-clk strobe to push into RX FIFO
    output logic [10:0] rx_id,           // Assembled 11-bit ID
    output logic        rx_rtr,          // Assembled RTR bit
    output logic [3:0]  rx_dlc,          // Assembled DLC (0..8)
    output logic [63:0] rx_data          // Assembled 64-bit payload
);

    // BSP State Encodings (from can_bsp)
    localparam [3:0] ST_IDLE        = 4'd0;
    localparam [3:0] ST_SOF         = 4'd1;
    localparam [3:0] ST_ARBITRATION = 4'd2;
    localparam [3:0] ST_CONTROL     = 4'd3;
    localparam [3:0] ST_DATA        = 4'd4;
    localparam [3:0] ST_CRC_FIELD   = 4'd5;
    localparam [3:0] ST_ACK         = 4'd6;
    localparam [3:0] ST_EOF         = 4'd7;
    localparam [3:0] ST_IFS         = 4'd8;
    localparam [3:0] ST_ERROR_FRAME = 4'd9;

    // Internal deserialization shift registers & bit counter
    logic        in_frame;
    logic [6:0]  rx_bit_cnt;
    logic [10:0] id_shift;
    logic        rtr_reg;
    logic [3:0]  dlc_reg;
    logic [63:0] data_shift;
    logic [14:0] crc_rx_shift;

    // Payload bit length calculation based on latched DLC (capped at 8 bytes = 64 bits)
    wire [3:0] effective_dlc = (dlc_reg > 4'd8) ? 4'd8 : dlc_reg;
    wire [6:0] data_bit_len  = {effective_dlc, 3'b000}; // dlc * 8

    // CRC calculator instance for RX path
    logic        crc_init;
    logic        crc_calc_en;
    logic [14:0] crc_computed;

    // Initialize CRC when idle, IFS, or error
    assign crc_init = clear || (bsp_state == ST_IDLE) || (bsp_state == ST_IFS) || (bsp_state == ST_ERROR_FRAME);

    // Calculate CRC over SOF (bit 0), ID (1..11), RTR (12), IDE/r0 (13..14), DLC (15..18), and DATA
    // Total header bits = 19 bits (0..18). Total covered bits = 19 + data_bit_len.
    assign crc_calc_en = rx_data_valid && (
        (!in_frame && (rx_data_bit == 1'b0)) ||
        (in_frame && (rx_bit_cnt < (7'd19 + data_bit_len)))
    );

    can_crc u_rx_crc (
        .clk     (clk),
        .rst_n   (rst_n),
        .init    (crc_init),
        .calc_en (crc_calc_en),
        .bit_in  (rx_data_bit),
        .crc_out (crc_computed)
    );

    // Deserialization Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_frame     <= 1'b0;
            rx_bit_cnt   <= 7'd0;
            id_shift     <= 11'd0;
            rtr_reg      <= 1'b0;
            dlc_reg      <= 4'd0;
            data_shift   <= 64'd0;
            crc_rx_shift <= 15'd0;
        end else if (clear || (bsp_state == ST_IDLE) || (bsp_state == ST_IFS) || (bsp_state == ST_ERROR_FRAME) || frame_valid) begin
            in_frame     <= 1'b0;
            rx_bit_cnt   <= 7'd0;
            id_shift     <= 11'd0;
            rtr_reg      <= 1'b0;
            dlc_reg      <= 4'd0;
            data_shift   <= 64'd0;
            crc_rx_shift <= 15'd0;
        end else if (rx_data_valid) begin
            if (!in_frame) begin
                // Frame begins on the first dominant (0) bit (SOF)
                if (rx_data_bit == 1'b0) begin
                    in_frame   <= 1'b1;
                    rx_bit_cnt <= 7'd1; // Next expected bit is ID[10] (bit 1)
                end
            end else begin
                // Bits 1..11: Base Identifier ID[10..0] (11 bits)
                if (rx_bit_cnt >= 7'd1 && rx_bit_cnt <= 7'd11) begin
                    id_shift <= {id_shift[9:0], rx_data_bit};
                end
                // Bit 12: RTR bit
                else if (rx_bit_cnt == 7'd12) begin
                    rtr_reg <= rx_data_bit;
                end
                // Bits 13..14: IDE (bit 13) and r0 (bit 14)
                else if (rx_bit_cnt == 7'd13 || rx_bit_cnt == 7'd14) begin
                    // Reserved/control bits
                end
                // Bits 15..18: Data Length Code DLC[3..0] (4 bits)
                else if (rx_bit_cnt >= 7'd15 && rx_bit_cnt <= 7'd18) begin
                    dlc_reg <= {dlc_reg[2:0], rx_data_bit};
                end
                // Bits 19..(19 + data_bit_len - 1): Data Payload
                else if (rx_bit_cnt >= 7'd19 && rx_bit_cnt < (7'd19 + data_bit_len)) begin
                    data_shift <= {data_shift[62:0], rx_data_bit};
                end
                // Next 15 bits: Received CRC sequence
                else if (rx_bit_cnt >= (7'd19 + data_bit_len) && rx_bit_cnt < (7'd19 + data_bit_len + 7'd15)) begin
                    crc_rx_shift <= {crc_rx_shift[13:0], rx_data_bit};
                end

                rx_bit_cnt <= rx_bit_cnt + 1'b1;
            end
        end
    end

    // CRC Comparison: Check if computed CRC matches received CRC sequence
    assign crc_ok = (crc_computed == crc_rx_shift);

    // Left-justify data payload if DLC < 8 so Byte 0 is always at [63:56]
    logic [63:0] aligned_data;
    always_comb begin
        case (effective_dlc)
            4'd0: aligned_data = 64'd0;
            4'd1: aligned_data = {data_shift[7:0],  56'd0};
            4'd2: aligned_data = {data_shift[15:0], 48'd0};
            4'd3: aligned_data = {data_shift[23:0], 40'd0};
            4'd4: aligned_data = {data_shift[31:0], 32'd0};
            4'd5: aligned_data = {data_shift[39:0], 24'd0};
            4'd6: aligned_data = {data_shift[47:0], 16'd0};
            4'd7: aligned_data = {data_shift[55:0], 8'd0};
            default: aligned_data = data_shift; // 8 bytes
        endcase
    end

    // Outputs
    assign rx_id   = id_shift;
    assign rx_rtr  = rtr_reg;
    assign rx_dlc  = effective_dlc;
    assign rx_data = aligned_data;

    // Push into RX FIFO upon successful frame completion
    assign rx_push = frame_valid && crc_ok;

endmodule
