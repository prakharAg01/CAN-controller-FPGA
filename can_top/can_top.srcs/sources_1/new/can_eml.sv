//=============================================================================
// Module      : can_eml
// Description : CAN Error Management Logic (EML) for Classical CAN 2.0A/B.
//               Maintains Transmit Error Counter (TEC) and Receive Error
//               Counter (REC) and transitions between:
//                 - ERROR_ACTIVE  (2'b00) : TEC <= 127 and REC <= 127
//                 - ERROR_PASSIVE (2'b01) : (TEC > 127 or REC > 127) and TEC <= 255
//                 - BUS_OFF       (2'b10) : TEC > 255
//
//               Error containment rules (CAN 2.0 / ISO 11898-1 simplified):
//                 - TX Errors (bit, stuff, form, ack)  : TEC += 8
//                 - RX Errors (stuff, form, crc)       : REC += 1
//                 - TX Success                         : TEC -= 1 (if TEC > 0)
//                 - RX Success                         : REC -= 1 (if 0 < REC <= 127),
//                                                        REC = 127 (if REC > 127)
//                 - Bus-Off Recovery                   : resets TEC=0, REC=0 -> ACTIVE
//                 - Error Warning                      : asserted when TEC >= 96 or REC >= 96
//=============================================================================

`timescale 1ns/1ps

module can_eml (
    input  logic        clk,
    input  logic        rst_n,               // Async active-low reset
    input  logic        clear,               // Synchronous abort / clear

    // Role / Mode
    input  logic        is_transmitter,      // 1 = transmitter, 0 = receiver

    // 5 Error Event Strobes (1-clk pulses from BSP / Destuffer / CRC)
    input  logic        bit_error,           // Bit error detected
    input  logic        stuff_error,         // Stuffing error detected
    input  logic        crc_error,           // CRC mismatch detected
    input  logic        ack_error,           // ACK slot missing dominant ACK
    input  logic        form_error,          // Fixed format field violation

    // Success Strobes (1-clk pulses from BSP on clean EOF)
    input  logic        tx_success,          // Frame transmitted successfully
    input  logic        rx_success,          // Frame received successfully

    // Bus-off Recovery
    input  logic        bus_off_recovery,    // Recovery strobe (128x11 recessive or host)

    // Counter Outputs
    output logic [7:0]  tec,                 // Transmit Error Counter (saturated at 255 in bus-off)
    output logic [7:0]  rec,                 // Receive Error Counter

    // State & Status Outputs
    output logic [1:0]  node_state,          // 00=Active, 01=Passive, 10=Bus-Off
    output logic        error_active,        // 1 when node is Error-Active
    output logic        error_passive,       // 1 when node is Error-Passive
    output logic        bus_off,             // 1 when node is Bus-Off
    output logic        error_warning        // 1 when TEC >= 96 or REC >= 96
);

    // State definitions
    localparam logic [1:0] STATE_ACTIVE  = 2'b00;
    localparam logic [1:0] STATE_PASSIVE = 2'b01;
    localparam logic [1:0] STATE_BUS_OFF = 2'b10;

    // Internal counters: 9 bits for TEC (holds 0..256), 8 bits for REC (holds 0..255)
    logic [8:0] tec_reg;
    logic [7:0] rec_reg;
    logic       bus_off_latched;

    // Error detection conditions
    wire tx_error = is_transmitter  && (bit_error || stuff_error || form_error || ack_error);
    wire rx_error = !is_transmitter && (stuff_error || form_error || crc_error);

    // Sequential update of counters and state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tec_reg         <= 9'd0;
            rec_reg         <= 8'd0;
            bus_off_latched <= 1'b0;
        end else if (clear) begin
            tec_reg         <= 9'd0;
            rec_reg         <= 8'd0;
            bus_off_latched <= 1'b0;
        end else if (bus_off_latched) begin
            // While in BUS-OFF, counter changes and error reports are inhibited.
            // Only a bus_off_recovery event can restore the node to ACTIVE.
            if (bus_off_recovery) begin
                tec_reg         <= 9'd0;
                rec_reg         <= 8'd0;
                bus_off_latched <= 1'b0;
            end
        end else begin
            // -----------------------------------------------------------------
            // Transmit Error Counter (TEC) Logic
            // -----------------------------------------------------------------
            if (tx_error) begin
                if (tec_reg + 9'd8 >= 9'd256) begin
                    tec_reg         <= 9'd256;
                    bus_off_latched <= 1'b1; // Enters BUS_OFF immediately
                end else begin
                    tec_reg <= tec_reg + 9'd8;
                end
            end else if (is_transmitter && tx_success) begin
                if (tec_reg > 9'd0) begin
                    tec_reg <= tec_reg - 9'd1;
                end
            end

            // -----------------------------------------------------------------
            // Receive Error Counter (REC) Logic
            // -----------------------------------------------------------------
            if (rx_error) begin
                if (rec_reg < 8'd255) begin
                    rec_reg <= rec_reg + 8'd1;
                end
            end else if (!is_transmitter && rx_success) begin
                if (rec_reg > 8'd127) begin
                    rec_reg <= 8'd127;
                end else if (rec_reg > 8'd0) begin
                    rec_reg <= rec_reg - 8'd1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Node State & Status Decoding
    // -------------------------------------------------------------------------
    always_comb begin
        if (bus_off_latched || (tec_reg >= 9'd256)) begin
            node_state = STATE_BUS_OFF;
        end else if ((tec_reg > 9'd127) || (rec_reg > 8'd127)) begin
            node_state = STATE_PASSIVE;
        end else begin
            node_state = STATE_ACTIVE;
        end
    end

    assign error_active  = (node_state == STATE_ACTIVE);
    assign error_passive = (node_state == STATE_PASSIVE);
    assign bus_off       = (node_state == STATE_BUS_OFF);
    assign error_warning = (tec_reg >= 9'd96) || (rec_reg >= 8'd96);

    // tec output saturates at 255 if in bus-off
    assign tec = (tec_reg >= 9'd255) ? 8'hFF : tec_reg[7:0];
    assign rec = rec_reg;

endmodule
