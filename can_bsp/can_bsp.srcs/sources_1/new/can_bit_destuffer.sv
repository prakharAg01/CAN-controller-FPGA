//=============================================================================
// Module : can_bit_destuffer  (RX side)
//
// Mirror of can_bit_stuffer. After 5 equal bits the next sampled bit is a
// stuff bit and is dropped. If that bit equals the run (6 identical bits),
// stuff_error pulses.
//
// Timing model
//   * bit_valid : 1-clk strobe, one per sampled bus bit (from sample point).
//   * data_valid, stuff_error : 1-clk pulses, one clock after bit_valid.
//     They are never held, so an error counter counts each violation once.
//
// Behaviour notes
//   * A stuff bit that is expected is ALWAYS consumed, even if destuff_en has
//     already dropped. This handles the stuff bit after the last CRC bit:
//     the RX control drops destuff_en after the final CRC bit, but the
//     trailing stuff bit still arrives before the CRC delimiter.
//   * 'stuff_expected' tells the RX control that the next bit is a stuff bit
//     (do not count it as a field bit, do not skip it).
//   * With destuff_en low the module is a pass-through (data_valid=1,
//     bit_out=bit_in), so it can sit on the bus for the whole frame.
//   * 'clear' resets state synchronously (after an error, at frame start).
//=============================================================================
module can_bit_destuffer (
    input  logic clk,
    input  logic rst_n,
    input  logic clear,          // sync abort / re-init
    input  logic destuff_en,     // 1 = de-stuffing active
    input  logic bit_valid,      // 1-clk strobe: bit_in is a fresh bus sample
    input  logic bit_in,         // sampled bus bit
    output logic bit_out,        // de-stuffed bit (valid with data_valid)
    output logic data_valid,     // 1-clk pulse: bit_out is a real data bit
    output logic stuff_error,    // 1-clk pulse: 6 identical bits in a row
    output logic stuff_expected  // next bit_valid will be a stuff bit
);

    logic [2:0] same_count;
    logic       last_bit;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            same_count     <= 3'd0;
            last_bit       <= 1'b1;
            stuff_expected <= 1'b0;
            bit_out        <= 1'b1;
            data_valid     <= 1'b0;
            stuff_error    <= 1'b0;
        end else if (clear) begin
            same_count     <= 3'd0;
            last_bit       <= 1'b1;
            stuff_expected <= 1'b0;
            bit_out        <= 1'b1;
            data_valid     <= 1'b0;
            stuff_error    <= 1'b0;
        end else begin
            // pulses by default
            data_valid  <= 1'b0;
            stuff_error <= 1'b0;

            if (!destuff_en && !stuff_expected) begin
                same_count <= 3'd0;
                last_bit   <= 1'b1;
            end

            if (bit_valid) begin
                if (stuff_expected) begin
                    // Stuff bit: consume, do not pass on.
                    if (bit_in == last_bit)
                        stuff_error <= 1'b1;      // 6th identical bit
                    last_bit       <= bit_in;
                    same_count     <= 3'd1;
                    stuff_expected <= 1'b0;
                end else begin
                    bit_out    <= bit_in;
                    data_valid <= 1'b1;
                    if (destuff_en) begin
                        last_bit <= bit_in;
                        if (bit_in == last_bit) begin
                            if (same_count == 3'd4) begin
                                stuff_expected <= 1'b1;
                                same_count     <= 3'd5;
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
    end

endmodule