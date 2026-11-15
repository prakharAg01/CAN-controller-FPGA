//=============================================================================
// Module : can_bit_stuffer  (TX side)
//
// After 5 consecutive bits of equal polarity, inserts one complementary
// stuff bit. Active while stuff_en is high (SOF .. end of CRC sequence).
//
// Timing model:
//   * Combinational passthrough when not stuffing (zero pipeline lag):
//     bit_out = stuffing ? ~last_bit : bit_in.
//   * When 5 identical bits are transmitted, inserts a complementary stuff bit
//     for one CAN bit time, while holding ready=0 so BSP shift registers pause.
//=============================================================================
module can_bit_stuffer (
    input  logic clk,
    input  logic rst_n,
    input  logic clear,          // sync abort / re-init
    input  logic bit_tick,       // 1-clk strobe, once per bit time
    input  logic stuff_en,       // 1 = stuffing active
    input  logic data_valid,     // BSP has a bit on bit_in
    input  logic bit_in,         // raw protocol bit
    output logic ready,          // bit_in consumed on this clock edge if data_valid
    output logic stuff_pending,  // next tick will send a stuff bit (BSP must hold)
    output logic bit_out,        // bit to drive on the bus
    output logic bit_out_valid,  // 1-clk pulse: bit_out was updated this tick
    output logic stuffing        // bit_out currently holds a stuff bit
);

    logic [2:0] same_count;      // length of current run of equal bits (0..5)
    logic       last_bit;
    logic       stuffing_r;

    assign stuffing      = stuffing_r;
    assign stuff_pending = stuff_en && !stuffing_r && (bit_in == last_bit) && (same_count == 3'd4);
    assign ready         = bit_tick & ~stuffing_r;
    assign bit_out       = stuffing_r ? ~last_bit : bit_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            same_count    <= 3'd0;
            last_bit      <= 1'b1;   // idle bus = recessive
            stuffing_r    <= 1'b0;
            bit_out_valid <= 1'b0;
        end else if (clear) begin
            same_count    <= 3'd0;
            last_bit      <= 1'b1;
            stuffing_r    <= 1'b0;
            bit_out_valid <= 1'b0;
        end else begin
            bit_out_valid <= bit_tick;

            if (!stuff_en && !stuffing_r) begin
                same_count <= 3'd0;
                last_bit   <= 1'b1;
            end

            if (bit_tick) begin
                if (stuffing_r) begin
                    // End of stuff bit: stuff bit had value ~last_bit
                    last_bit   <= ~last_bit;
                    same_count <= 3'd1;
                    stuffing_r <= 1'b0;
                end else if (stuff_en) begin
                    if (bit_in == last_bit) begin
                        if (same_count == 3'd4) begin
                            // This bit was the 5th identical bit: send stuff bit on next bit time
                            stuffing_r <= 1'b1;
                        end else begin
                            same_count <= same_count + 3'd1;
                        end
                    end else begin
                        last_bit   <= bit_in;
                        same_count <= 3'd1;
                    end
                end else begin
                    same_count <= 3'd0;
                    last_bit   <= 1'b1;
                end
            end
        end
    end

endmodule
