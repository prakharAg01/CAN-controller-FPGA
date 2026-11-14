//=============================================================================
// Module : can_bit_stuffer  (TX side)
//
// After 5 consecutive bits of equal polarity, inserts one complementary
// stuff bit. Active while stuff_en is high (SOF .. end of CRC field).
//
// Timing model
//   * The module only updates the bus bit on 'bit_tick' (1-clk strobe, once
//     per CAN bit time, from your bit-timing logic). Between ticks bit_out
//     is held.
//   * Handshake with the BSP (valid/ready style):
//         transfer happens on a clock edge where  data_valid && ready
//     'ready' is high only in a tick cycle in which bit_in will actually be
//     consumed. In a tick cycle where a stuff bit is sent, ready = 0 and the
//     BSP simply keeps bit_in / data_valid unchanged. 'stuff_pending' goes
//     high a full bit time BEFORE that tick, so the BSP can see it coming.
//   * The BSP must present a valid bit on every tick while a frame is being
//     sent (an underrun would repeat the previous bit on the bus).
//
// Behaviour notes
//   * A pending stuff bit is ALWAYS sent, even if stuff_en drops meanwhile.
//     This is what gives the mandatory stuff bit after a CRC that ends in
//     5 identical bits (before the CRC delimiter).
//   * With stuff_en low the module is a transparent pass-through (bit_in ->
//     bit_out on tick), so it can drive the bus for the whole frame.
//   * 'clear' aborts everything synchronously (error/overload frame, new
//     frame). Reset is asynchronous, active low.
//=============================================================================
module can_bit_stuffer (
    input  logic clk,
    input  logic rst_n,
    input  logic clear,          // sync abort / re-init
    input  logic bit_tick,       // 1-clk strobe, once per bit time
    input  logic sample_point,   // 1-clk strobe at sample point
    input  logic stuff_en,       // 1 = stuffing active
    input  logic data_valid,     // BSP has a bit on bit_in
    input  logic bit_in,         // raw protocol bit
    output logic ready,          // bit_in consumed on this clock edge if data_valid
    output logic stuff_pending,  // next tick will send a stuff bit (BSP must hold)
    output logic bit_out,        // bit to drive on the bus (held between ticks)
    output logic bit_out_valid,  // 1-clk pulse: bit_out was updated this tick
    output logic stuffing        // bit_out currently holds a stuff bit
);

    logic [2:0] same_count;      // length of current run of equal bits (0..5)
    logic       last_bit;

    assign ready = bit_tick & ~stuff_pending;

    // Consecutive run tracking at sample point
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            same_count    <= 3'd0;
            last_bit      <= 1'b1;
            stuff_pending <= 1'b0;
        end else if (clear) begin
            same_count    <= 3'd0;
            last_bit      <= 1'b1;
            stuff_pending <= 1'b0;
        end else begin
            if (!stuff_en && !stuff_pending) begin
                same_count <= 3'd0;
                last_bit   <= 1'b1;
            end

            if (sample_point && stuff_en) begin
                if (stuffing) begin
                    same_count    <= 3'd1;
                    last_bit      <= bit_in;
                    stuff_pending <= 1'b0;
                end else begin
                    last_bit <= bit_in;
                    if (bit_in == last_bit) begin
                        if (same_count == 3'd4) begin
                            stuff_pending <= 1'b1;
                            same_count    <= 3'd5;
                        end else begin
                            same_count <= same_count + 3'd1;
                        end
                    end else begin
                        same_count <= 3'd1;
                    end
                end
            end
        end
    end

    // Bus drive updates at bit_tick
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_out       <= 1'b1;
            bit_out_valid <= 1'b0;
            stuffing      <= 1'b0;
        end else if (clear) begin
            bit_out       <= 1'b0;
            bit_out_valid <= 1'b0;
            stuffing      <= 1'b0;
        end else begin
            bit_out_valid <= 1'b0;

            if (bit_tick) begin
                if (stuff_pending) begin
                    bit_out       <= ~last_bit;
                    stuffing      <= 1'b1;
                    bit_out_valid <= 1'b1;
                end else begin
                    bit_out       <= bit_in;
                    stuffing      <= 1'b0;
                    bit_out_valid <= 1'b1;
                end
            end
        end
    end

endmodule