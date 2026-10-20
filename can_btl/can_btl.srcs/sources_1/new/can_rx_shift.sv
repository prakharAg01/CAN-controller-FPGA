//=============================================================================
// Module : can_rx_shift   (RX shift register / deserializer)    -- Day 5
//
// Collects de-stuffed bits, MSB first, into one field of runtime length 'len'
// and delivers it right-aligned with a 1-clock 'done' pulse. It is the
// RX-side counterpart of can_tx_shift.
//
// Connection to the de-stuffer:
//     bit_valid = destuffer.data_valid      (1-clk pulse, one per REAL bit)
//     bit_in    = destuffer.bit_out
//
// How the BSP uses it (field lengths for a standard data frame):
//     SOF + ID          len = 12   data[11:0] = {SOF, ID[10:0]}
//     RTR, IDE, r0, DLC len = 7    data[6:0]  = {RTR, IDE, r0, DLC[3:0]}
//     each data byte    len = 8    data[7:0]  (repeat DLC times)
//     CRC sequence      len = 15   data[14:0] -> compare with can_crc.crc_out
//   With WIDTH = 16 (default) every field above fits.
//
// Behaviour
//   * 'len' is read on every bit. Set it BEFORE the first bit of a field; it
//     may be changed as soon as 'done' is seen (it is safe in the same clock).
//   * When the len-th bit of a field arrives, the complete field is stored in
//     'data' (upper bits zero) and 'done' pulses in the NEXT clock, together
//     with the new 'data'. 'data' then HOLDS its value until the next 'done',
//     so the BSP may read it at any time in between.
//   * The bit counter restarts by itself after 'done': fields can follow each
//     other directly.
//   * len = 0 : bits are ignored (use it while no field is expected, e.g.
//     after the CRC field). len > WIDTH is clamped to WIDTH.
//   * If len is lowered below the number of bits already received, the field
//     completes with the next bit (>= compare), it can never get stuck.
//   * clear aborts the current field and resets everything.
//=============================================================================
module can_rx_shift #(
    parameter int WIDTH = 16,
    localparam int LW   = $clog2(WIDTH + 1)
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             clear,

    input  logic [LW-1:0]    len,         // bits in the current field (0 = ignore bits)

    input  logic             bit_valid,   // = destuffer.data_valid
    input  logic             bit_in,      // = destuffer.bit_out

    output logic [WIDTH-1:0] data,        // last completed field, right-aligned
    output logic [LW-1:0]    count,       // bits of the current field received so far
    output logic             done         // 1-clk pulse: 'data' holds a new field
);

    logic [WIDTH-1:0] sr;

    wire [LW-1:0]    len_c   = (len > WIDTH[LW-1:0]) ? WIDTH[LW-1:0] : len;
    wire             active  = (len_c != '0);
    wire [WIDTH-1:0] sr_next = {sr[WIDTH-2:0], bit_in};
    wire [LW:0]      cnt_inc = {1'b0, count} + {{LW{1'b0}}, 1'b1};
    wire             last_bit = active & (cnt_inc >= {1'b0, len_c});

    // mask with the low len_c bits set
    wire [WIDTH-1:0] mask = (len_c >= WIDTH[LW-1:0]) ? {WIDTH{1'b1}}
                                                     : ((({{(WIDTH-1){1'b0}}, 1'b1}) << len_c) - 1'b1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sr    <= '0;
            count <= '0;
            data  <= '0;
            done  <= 1'b0;
        end else if (clear) begin
            sr    <= '0;
            count <= '0;
            data  <= '0;
            done  <= 1'b0;
        end else begin
            done <= 1'b0;
            if (bit_valid && active) begin
                sr <= sr_next;
                if (last_bit) begin
                    data  <= sr_next & mask;
                    done  <= 1'b1;
                    count <= '0;
                end else begin
                    count <= count + {{(LW-1){1'b0}}, 1'b1};
                end
            end
        end
    end

endmodule