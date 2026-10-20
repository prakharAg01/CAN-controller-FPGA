//=============================================================================
// Module : can_btl   (Bit Timing Logic)           -- Day 1-3 version
//
//   |<------------------------ 1 bit time ------------------------>|
//   |  SYNC_SEG |          TSEG1            |        TSEG2          |
//   |   1 TQ    | (PROP_SEG + PHASE_SEG1)   |     (PHASE_SEG2)      |
//   ^bit_tick                               ^sample_point
//
// Configuration (register-style, 0-based):
//     1 TQ     = BRP   + 1 clocks        (BRP   : 0..255)
//     TSEG1    = TSEG1 + 1 TQ            (TSEG1 : 0..15)
//     TSEG2    = TSEG2 + 1 TQ            (TSEG2 : 0..7)
//     SJW      = SJW   + 1 TQ            (SJW   : 0..3  -> 1..4 TQ)
//     bit time (clk) = (TSEG1 + TSEG2 + 3) * (BRP + 1)
//     sample offset  = (TSEG1 + 2) * (BRP + 1) clocks after bit_tick
//   Spec rule (not enforced here): SJW <= PHASE_SEG2.
//
// ---------------------------------------------------------------------------
// SYNCHRONISATION  (new in Day 3)
// ---------------------------------------------------------------------------
// All edges are measured on the synchronised RX signal (rx_sync1), i.e. the
// same time base the sampling uses. Only recessive(1) -> dominant(0) edges
// are used. An edge is accepted only if
//     (a) the value at the previous sample point (rx_bit) was recessive, and
//     (b) no synchronisation has happened yet in this bit time.
//
//   hsync_en = 1  (bus idle, node not transmitting)  -> HARD SYNC (SOF):
//       the bit is restarted at the edge: the clock in which the edge is seen
//       becomes the first clock of SYNC_SEG.
//   rsync_en = 1  (frame in progress)                -> RESYNC. Phase error e
//       (in TQ) of the edge relative to SYNC_SEG:
//         edge inside SYNC_SEG           : e = 0, nothing to do
//         edge inside TSEG1 (late edge)  : e = +(k+1), k = TQ index inside TSEG1
//                                          e <= SJW : bit restarted at the edge
//                                                     (same as hard sync)
//                                          e >  SJW : TSEG1 lengthened by SJW
//                                          not done while tx_dominant = 1
//         edge inside TSEG2 (early edge) : e = -(L2-k), k = TQ index inside TSEG2
//                                          |e| <= SJW : bit ended at the edge,
//                                                       next bit starts there
//                                                       (a bit_tick is issued)
//                                          |e| >  SJW : TSEG2 shortened by SJW
//   Both enables low : the module free-runs (Day 1-2 behaviour).
//   hsync_en wins if both are high.
//
//   tx_dominant : BSP asserts it while this node itself drives a dominant bit.
//                 The node's own delayed edge would look like a late edge; the
//                 spec forbids resynchronising on it.
//
// Outputs (1 clock wide):
//   tq_tick, bit_tick, sample_point            as before
//   hard_sync        a hard synchronisation was performed
//   resync_full      resync with |e| <= SJW (bit restarted / aligned)
//   resync_limited   resync with |e| >  SJW (segment changed by SJW)
//   rx_bit           bus value captured at the sample point (held)
//   seg_state        0 = SYNC, 1 = TSEG1, 2 = TSEG2
//
// 'clear' also marks the previous sample as recessive (idle).
// Notes: a restart does not issue tq_tick/bit_tick except the TSEG2 case
// above (the bit that ends must be followed by a bit_tick so the transmitter
// does not lose a bit). Do not change BRP/TSEG*/SJW while a frame is running.
//=============================================================================
module can_btl (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       clear,

    input  logic [7:0] brp,
    input  logic [3:0] tseg1,
    input  logic [2:0] tseg2,
    input  logic [1:0] sjw,

    input  logic       hsync_en,
    input  logic       rsync_en,
    input  logic       tx_dominant,

    input  logic       rx_in,

    output logic       tq_tick,
    output logic       bit_tick,
    output logic       sample_point,
    output logic       rx_bit,
    output logic [1:0] seg_state,

    output logic       hard_sync,
    output logic       resync_full,
    output logic       resync_limited
);

    localparam logic [1:0] SEG_SYNC  = 2'd0;
    localparam logic [1:0] SEG_TSEG1 = 2'd1;
    localparam logic [1:0] SEG_TSEG2 = 2'd2;

    //-------------------------------------------------------------------
    // RX synchroniser + previous value (for edge detection)
    //-------------------------------------------------------------------
    logic rx_sync0, rx_sync1, rx_prev;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
            rx_prev  <= 1'b1;
        end else begin
            rx_sync0 <= rx_in;
            rx_sync1 <= rx_sync0;
            rx_prev  <= rx_sync1;
        end
    end

    //-------------------------------------------------------------------
    // State
    //-------------------------------------------------------------------
    logic [7:0] presc_cnt;
    logic [4:0] tq_cnt;          // TQ elapsed in the current segment (max 15+4)
    logic       sync_done;       // one synchronisation per bit time
    logic [2:0] add1;            // TSEG1 lengthening applied in this bit (TQ)
    logic [2:0] sub2;            // TSEG2 shortening applied in this bit (TQ)

    wire [2:0] sjw_tq = {1'b0, sjw} + 3'd1;               // 1..4
    wire       tq_end = (presc_cnt >= brp);

    //-------------------------------------------------------------------
    // Edge qualification and phase error
    //-------------------------------------------------------------------
    wire edge_now = rx_prev & ~rx_sync1;                  // recessive -> dominant
    wire edge_ok  = edge_now & rx_bit & ~sync_done;

    wire in_sync  = (seg_state == SEG_SYNC);
    wire in_t1    = (seg_state == SEG_TSEG1);
    wire in_t2    = (seg_state == SEG_TSEG2);

    wire [5:0] l2     = {3'b000, tseg2} + 6'd1;           // TSEG2 length in TQ
    wire [5:0] e_pos  = {1'b0, tq_cnt} + 6'd1;            // late edge  (TSEG1)
    wire [5:0] e_neg  = ({1'b0, tq_cnt} >= l2) ? 6'd1 : (l2 - {1'b0, tq_cnt}); // early edge (TSEG2)
    wire [5:0] sjw_w  = {3'b000, sjw_tq};

    wire do_hard  = hsync_en & edge_ok;
    wire rs_cand  = rsync_en & ~hsync_en & edge_ok;

    wire rs_zero  = rs_cand & in_sync;
    wire rs_pos   = rs_cand & in_t1 & ~tx_dominant;
    wire rs_neg   = rs_cand & in_t2;

    wire pos_full = rs_pos & (e_pos <= sjw_w);
    wire pos_lim  = rs_pos & (e_pos >  sjw_w);
    wire neg_full = rs_neg & (e_neg <= sjw_w);
    wire neg_lim  = rs_neg & (e_neg >  sjw_w);

    wire do_restart = do_hard | pos_full | neg_full;

    // segment limits including an adjustment decided in THIS clock
    wire [2:0] add1_n = pos_lim ? sjw_tq : add1;
    wire [2:0] sub2_n = neg_lim ? sjw_tq : sub2;
    wire [4:0] lim1   = {1'b0, tseg1} + {2'b00, add1_n};                    // TSEG1 ends when tq_cnt >= lim1
    wire [3:0] lim2   = (tseg2 > sub2_n) ? ({1'b0, tseg2} - {1'b0, sub2_n}) : 4'd0;

    //-------------------------------------------------------------------
    // Main sequential block
    //-------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            presc_cnt      <= 8'd0;
            tq_cnt         <= 5'd0;
            seg_state      <= SEG_SYNC;
            sync_done      <= 1'b0;
            add1           <= 3'd0;
            sub2           <= 3'd0;
            tq_tick        <= 1'b0;
            bit_tick       <= 1'b0;
            sample_point   <= 1'b0;
            hard_sync      <= 1'b0;
            resync_full    <= 1'b0;
            resync_limited <= 1'b0;
            rx_bit         <= 1'b1;
        end else if (clear) begin
            presc_cnt      <= 8'd0;
            tq_cnt         <= 5'd0;
            seg_state      <= SEG_SYNC;
            sync_done      <= 1'b0;
            add1           <= 3'd0;
            sub2           <= 3'd0;
            tq_tick        <= 1'b0;
            bit_tick       <= 1'b0;
            sample_point   <= 1'b0;
            hard_sync      <= 1'b0;
            resync_full    <= 1'b0;
            resync_limited <= 1'b0;
            rx_bit         <= 1'b1;   // restart as idle: previous sample = recessive,
                                      // so the next SOF edge can hard-synchronise
        end else begin
            tq_tick        <= 1'b0;
            bit_tick       <= 1'b0;
            sample_point   <= 1'b0;
            hard_sync      <= 1'b0;
            resync_full    <= 1'b0;
            resync_limited <= 1'b0;

            if (do_restart) begin
                // the clock in which the edge is seen = first clock of SYNC_SEG
                sync_done <= 1'b1;
                add1      <= 3'd0;
                sub2      <= 3'd0;
                tq_cnt    <= 5'd0;
                if (brp == 8'd0) begin          // SYNC_SEG (1 TQ) is already over
                    presc_cnt <= 8'd0;
                    seg_state <= SEG_TSEG1;
                    tq_tick   <= 1'b1;
                end else begin
                    presc_cnt <= 8'd1;
                    seg_state <= SEG_SYNC;
                end
                if (do_hard)       hard_sync   <= 1'b1;
                else               resync_full <= 1'b1;
                if (neg_full)      bit_tick    <= 1'b1;   // the old bit ends here
            end else begin
                // bookkeeping of a limited resync / edge inside SYNC_SEG
                if (rs_zero | pos_lim | neg_lim) sync_done <= 1'b1;
                if (pos_lim) begin add1 <= sjw_tq; resync_limited <= 1'b1; end
                if (neg_lim) begin sub2 <= sjw_tq; resync_limited <= 1'b1; end

                if (!tq_end) begin
                    presc_cnt <= presc_cnt + 8'd1;
                end else begin
                    presc_cnt <= 8'd0;
                    tq_tick   <= 1'b1;

                    case (seg_state)
                        SEG_SYNC: begin
                            seg_state <= SEG_TSEG1;
                            tq_cnt    <= 5'd0;
                        end

                        SEG_TSEG1: begin
                            if (tq_cnt >= lim1) begin       // sample point
                                seg_state    <= SEG_TSEG2;
                                tq_cnt       <= 5'd0;
                                sample_point <= 1'b1;
                                rx_bit       <= rx_sync1;
                            end else begin
                                tq_cnt <= tq_cnt + 5'd1;
                            end
                        end

                        SEG_TSEG2: begin
                            if (tq_cnt >= {1'b0, lim2}) begin   // end of bit
                                seg_state <= SEG_SYNC;
                                tq_cnt    <= 5'd0;
                                bit_tick  <= 1'b1;
                                sync_done <= 1'b0;
                                add1      <= 3'd0;
                                sub2      <= 3'd0;
                            end else begin
                                tq_cnt <= tq_cnt + 5'd1;
                            end
                        end

                        default: begin
                            seg_state <= SEG_SYNC;
                            tq_cnt    <= 5'd0;
                        end
                    endcase
                end
            end
        end
    end

endmodule