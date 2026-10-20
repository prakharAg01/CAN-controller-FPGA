//=============================================================================
// Module : can_tx_shift   (TX shift register / serializer)     -- Day 5
//
// Holds one group of frame bits and hands them, MSB first, to can_bit_stuffer
// one at a time. It is the TX-side counterpart of can_rx_shift.
//
// Connection to the stuffer (same valid/ready rule the stuffer already uses):
//     stuffer.data_valid = tx.valid
//     stuffer.bit_in     = tx.bit_out
//     tx.shift_en        = stuffer.ready
//   A bit is consumed on every clock edge where  valid && shift_en  (= xfer).
//
// LOADING (MSB-aligned): the FIRST bit to send is load_data[WIDTH-1].
//   Just concatenate the fields MSB first, the rest is ignored (padding):
//     header (19 bit): {SOF, ID[10:0], RTR, IDE, r0, DLC[3:0], {(WIDTH-19){1'b0}}}, len = 19
//     data   (8*DLC) : {data0, data1, ..., {padding}},                              len = 8*DLC
//     CRC    (15 bit): {crc[14:0], {(WIDTH-15){1'b0}}},                             len = 15
//     tail   (13 bit): {WIDTH{1'b1}},  len = 13   (CRC delimiter, ACK slot,
//                                                   ACK delimiter, EOF x7, IFS x3)
//   load_len = number of valid bits, 1..WIDTH (a value > WIDTH is clamped).
//
// RULES
//   * load is accepted when the register is empty, OR in the very clock in
//     which the last bit is consumed (xfer && last). That gives a seamless,
//     bubble-free reload: the stuffer never sees valid drop between fields.
//   * load while busy (any other time) is IGNORED and load_rejected pulses.
//     load with load_len = 0 is ignored too (load_rejected pulses).
//   * clear aborts immediately (error / overload frame, new frame).
//   * The stuffer needs a valid bit at every bit_tick while a frame is being
//     sent. Between two fields the BSP has the gap between two bit times to
//     load the next field (done pulses one clock after the last bit left).
//
// Outputs
//   valid      at least one bit left to send
//   bit_out    the bit to send (only meaningful while valid = 1)
//   last       the bit on bit_out is the last bit of this load
//   xfer       valid && shift_en : the bit on bit_out is consumed this clock
//              (use it as the strobe that feeds can_crc / counts bits)
//   remaining  bits left, including the one on bit_out
//   done       1-clk pulse, the clock after the last bit was consumed
//   load_rejected  1-clk pulse, a load was ignored
//=============================================================================
module can_tx_shift #(
    parameter int WIDTH = 64,
    localparam int LW   = $clog2(WIDTH + 1)
) (
    input  logic             clk,
    input  logic             rst_n,         // async, active low
    input  logic             clear,         // sync abort

    input  logic             load,          // 1-clk request
    input  logic [WIDTH-1:0] load_data,     // MSB-aligned
    input  logic [LW-1:0]    load_len,      // 1..WIDTH

    input  logic             shift_en,      // = stuffer.ready

    output logic             valid,
    output logic             bit_out,
    output logic             last,
    output logic             xfer,
    output logic [LW-1:0]    remaining,
    output logic             done,
    output logic             load_rejected
);

    logic [WIDTH-1:0] sr;
    logic [LW-1:0]    cnt;

    assign valid     = (cnt != '0);
    assign last      = (cnt == {{(LW-1){1'b0}}, 1'b1});
    assign bit_out   = sr[WIDTH-1];
    assign xfer      = valid & shift_en;
    assign remaining = cnt;

    wire finishing  = xfer & last;
    wire can_load   = ~valid | finishing;
    wire len_ok     = (load_len != '0);
    wire [LW-1:0] len_c = (load_len > WIDTH[LW-1:0]) ? WIDTH[LW-1:0] : load_len;
    wire do_load    = load & can_load & len_ok;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sr            <= '0;
            cnt           <= '0;
            done          <= 1'b0;
            load_rejected <= 1'b0;
        end else if (clear) begin
            sr            <= '0;
            cnt           <= '0;
            done          <= 1'b0;
            load_rejected <= 1'b0;
        end else begin
            done          <= finishing;
            load_rejected <= load & ~do_load;

            if (do_load) begin
                sr  <= load_data;
                cnt <= len_c;
            end else if (xfer) begin
                sr  <= {sr[WIDTH-2:0], 1'b0};
                cnt <= cnt - {{(LW-1){1'b0}}, 1'b1};
            end
        end
    end

endmodule