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

    // Internal deserialization shift registers & counters
    logic [10:0] id_shift;
    logic        rtr_reg;
    logic [3:0]  arb_cnt;
    logic [3:0]  ctrl_cnt;
    logic [3:0]  dlc_reg;
    logic [63:0] data_shift;
    logic [5:0]  data_bit_cnt;
    logic [14:0] crc_rx_shift;
    logic [3:0]  crc_rx_cnt;

    // CRC calculator instance for RX path
    logic        crc_init;
    logic        crc_calc_en;
    logic [14:0] crc_computed;

    // Pulse crc_init on entry into SOF (1-clk strobe)
    logic        prev_sof;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) prev_sof <= 1'b0;
        else        prev_sof <= (bsp_state == ST_SOF);
    end
    wire sof_start_pulse = (bsp_state == ST_SOF) && !prev_sof;
    assign crc_init      = clear || sof_start_pulse;

    // Calculate CRC over SOF, ARBITRATION, CONTROL, and DATA fields
    assign crc_calc_en = rx_data_valid && (
        (bsp_state == ST_SOF)         ||
        (bsp_state == ST_ARBITRATION) ||
        (bsp_state == ST_CONTROL)     ||
        (bsp_state == ST_DATA)
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
            id_shift     <= 11'd0;
            rtr_reg      <= 1'b0;
            arb_cnt      <= 4'd0;
            ctrl_cnt     <= 4'd0;
            dlc_reg      <= 4'd0;
            data_shift   <= 64'd0;
            data_bit_cnt <= 6'd0;
            crc_rx_shift <= 15'd0;
            crc_rx_cnt   <= 4'd0;
        end else if (clear || (bsp_state == ST_IDLE) || (bsp_state == ST_ERROR_FRAME)) begin
            arb_cnt      <= 4'd0;
            ctrl_cnt     <= 4'd0;
            data_bit_cnt <= 6'd0;
            crc_rx_cnt   <= 4'd0;
        end else begin
            // State-specific counter resets when outside that state
            if (bsp_state != ST_ARBITRATION) arb_cnt <= 4'd0;
            if (bsp_state != ST_CONTROL)     ctrl_cnt <= 4'd0;
            if (bsp_state != ST_CRC_FIELD)   crc_rx_cnt <= 4'd0;

            if (rx_data_valid) begin
                case (bsp_state)
                    ST_ARBITRATION: begin
                        // 12 bits: 11-bit ID (bits 0..10) + 1-bit RTR (bit 11)
                        if (arb_cnt < 4'd11) begin
                            id_shift <= {id_shift[9:0], rx_data_bit};
                        end else begin
                            rtr_reg  <= rx_data_bit;
                        end
                        arb_cnt <= arb_cnt + 1'b1;
                    end

                    ST_CONTROL: begin
                        // 6 bits: IDE (bit 0), r0 (bit 1), DLC[3:0] (bits 2..5)
                        ctrl_cnt <= ctrl_cnt + 1'b1;
                        if (ctrl_cnt >= 4'd2) begin
                            dlc_reg <= {dlc_reg[2:0], rx_data_bit};
                        end
                        data_bit_cnt <= 6'd0; // reset for data field
                    end

                    ST_DATA: begin
                        // Shift in data bytes MSB first into bits [63:0]
                        data_shift   <= {data_shift[62:0], rx_data_bit};
                        data_bit_cnt <= data_bit_cnt + 1'b1;
                    end

                    ST_CRC_FIELD: begin
                        // First 15 bits are CRC sequence
                        if (crc_rx_cnt < 4'd15) begin
                            crc_rx_shift <= {crc_rx_shift[13:0], rx_data_bit};
                            crc_rx_cnt   <= crc_rx_cnt + 1'b1;
                        end
                    end

                    default: ;
                endcase
            end
        end
    end

    // CRC Comparison: Check if computed CRC matches received CRC
    // Valid during ACK and EOF states
    assign crc_ok = (crc_computed == crc_rx_shift);

    // Left-justify data payload if DLC < 8 so Byte 0 is always at [63:56]
    logic [63:0] aligned_data;
    always_comb begin
        case (dlc_reg)
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
    assign rx_dlc  = (dlc_reg > 4'd8) ? 4'd8 : dlc_reg;
    assign rx_data = aligned_data;

    // Push into RX FIFO upon successful frame completion
    assign rx_push = frame_valid && crc_ok;

endmodule
