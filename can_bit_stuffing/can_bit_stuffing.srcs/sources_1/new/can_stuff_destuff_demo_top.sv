//=============================================================================
// Module      : can_stuff_destuff_demo_top
// Description : Board-level demo: TEST VECTOR -> STUFFER -> DESTUFFER ->
//               COMPARATOR, all visible on LEDs. Two source modes:
//
//                 mode_sw = 0 (AUTO)   : loops the known 20-bit test vector
//                                        (same one from simulation) and
//                                        self-checks every recovered bit
//                                        against the expected sequence.
//                 mode_sw = 1 (MANUAL) : YOU supply the bit stream by hand
//                                        using data_sw + step_btn. Good for
//                                        poking arbitrary patterns live in
//                                        front of evaluators. No auto
//                                        pass/fail in this mode (there is no
//                                        known "expected" sequence for an
//                                        arbitrary hand-entered stream).
//
// LEDs:
//   led_heartbeat      - clk/reset alive, unrelated to CAN logic
//   led_bit_out        - STUFFER stage: current bus bit value
//   led_stuffing        - STUFFER stage: this bus bit is an INSERTED stuff bit
//   led_stuff_pending   - STUFFER stage: next tick will be a stuff bit (early warning)
//   led_recovered       - DESTUFFER stage: current recovered data bit
//   led_pass            - COMPARATOR stage (AUTO mode only): last recovered
//                          bit matched the expected bit
//   led_error           - COMPARATOR stage: STICKY. Lights and stays lit if
//                          any mismatch OR any stuff_error ever occurs.
//                          Cleared only by rst_btn.
//
// can_bit_stuffer.sv and can_bit_destuffer.sv are UNCHANGED by this file --
// this is purely a wrapper for board bring-up / understanding, not the
// final integration point. The real project will instantiate these two
// blocks from inside the BSP, not from this demo top.
//=============================================================================

module can_stuff_destuff_demo_top #(
    parameter int CLK_HZ       = 100_000_000,  // board oscillator frequency
    parameter int BIT_HZ       = 2,            // AUTO mode bit rate (LED-watchable)
    parameter int DEBOUNCE_MS  = 20            // MANUAL step-button debounce window
) (
    input  logic clk,             // board oscillator
    input  logic rst_btn_raw,     // full reset button -- ASSUMED ACTIVE-HIGH
    input  logic mode_sw,         // 0 = AUTO test-vector loop, 1 = MANUAL entry
    input  logic data_sw,         // MANUAL mode: the bit value to send next
    input  logic step_btn_raw,    // MANUAL mode: press to send data_sw as the next bit
                                   // (ASSUMED ACTIVE-HIGH, debounced internally)

    output logic led_heartbeat,
    output logic led_bit_out,
    output logic led_stuffing,
    output logic led_stuff_pending,
    output logic led_recovered,
    output logic led_pass,
    output logic led_error
);

    logic rst_n;
    assign rst_n = ~rst_btn_raw;      // active-high button -> active-low reset internally

    //-------------------------------------------------------------------
    // Heartbeat LED
    //-------------------------------------------------------------------
    logic [26:0] hb_cnt;
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) hb_cnt <= 27'd0;
        else        hb_cnt <= hb_cnt + 27'd1;
    assign led_heartbeat = hb_cnt[26];

    //-------------------------------------------------------------------
    // AUTO mode: slow tick generator (one pulse every CLK_HZ/BIT_HZ cycles)
    //-------------------------------------------------------------------
    localparam int TICK_DIV = CLK_HZ / BIT_HZ;
    localparam int TICK_W   = $clog2(TICK_DIV);

    logic [TICK_W-1:0] tick_cnt;
    logic               auto_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt  <= '0;
            auto_tick <= 1'b0;
        end else if (tick_cnt == TICK_DIV-1) begin
            tick_cnt  <= '0;
            auto_tick <= 1'b1;
        end else begin
            tick_cnt  <= tick_cnt + 1'b1;
            auto_tick <= 1'b0;
        end
    end

    //-------------------------------------------------------------------
    // MANUAL mode: debounced step button -> single clean tick per press
    //-------------------------------------------------------------------
    logic step_sync0, step_sync1, step_prev;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_sync0 <= 1'b0;
            step_sync1 <= 1'b0;
            step_prev  <= 1'b0;
        end else begin
            step_sync0 <= step_btn_raw;   // 2-FF synchronizer
            step_sync1 <= step_sync0;
            step_prev  <= step_sync1;
        end
    end
    wire step_edge = step_sync1 & ~step_prev;   // rising edge, synchronized

    localparam int DEBOUNCE_CYCLES = (CLK_HZ/1000) * DEBOUNCE_MS;
    localparam int DB_W            = $clog2(DEBOUNCE_CYCLES+1);

    logic [DB_W-1:0] db_cnt;
    logic            db_lock;
    logic            manual_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            db_cnt      <= '0;
            db_lock     <= 1'b0;
            manual_tick <= 1'b0;
        end else begin
            manual_tick <= 1'b0;
            if (db_lock) begin
                if (db_cnt == DEBOUNCE_CYCLES-1) begin
                    db_cnt  <= '0;
                    db_lock <= 1'b0;
                end else begin
                    db_cnt <= db_cnt + 1'b1;
                end
            end else if (step_edge) begin
                manual_tick <= 1'b1;   // one clean tick for this press
                db_lock     <= 1'b1;   // ignore further edges for DEBOUNCE_MS
                db_cnt      <= '0;
            end
        end
    end

    wire bit_tick = mode_sw ? manual_tick : auto_tick;

    //-------------------------------------------------------------------
    // AUTO mode test-vector source (same 20-bit vector as tb_can_bit_stuffing)
    // raw = 0,0,0,0,0,1,0,1,1,1,1,1,0,1,0,0,0,0,0,1
    //-------------------------------------------------------------------
    localparam int VEC_LEN = 20;
    logic [4:0] idx;

    function automatic logic test_bit(input logic [4:0] i);
        case (i)
            5'd0, 5'd1, 5'd2, 5'd3, 5'd4:   test_bit = 1'b0;
            5'd5:                            test_bit = 1'b1;
            5'd6:                            test_bit = 1'b0;
            5'd7, 5'd8, 5'd9, 5'd10, 5'd11:  test_bit = 1'b1;
            5'd12:                           test_bit = 1'b0;
            5'd13:                           test_bit = 1'b1;
            5'd14,5'd15,5'd16,5'd17,5'd18:   test_bit = 1'b0;
            5'd19:                           test_bit = 1'b1;
            default:                         test_bit = 1'b0;
        endcase
    endfunction

    wire bit_in     = mode_sw ? data_sw : test_bit(idx);
    wire data_valid = 1'b1;
    wire stuff_en   = 1'b1;

    wire ready_w, stuff_pending_w, bit_out_w, bit_out_valid_w, stuffing_w;

    // Advance the AUTO-mode index only when the stuffer actually consumes a
    // bit (mirrors your simulation testbench's driver rule exactly).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx <= 5'd0;
        end else if (!mode_sw && bit_tick && ready_w) begin
            idx <= (idx == VEC_LEN-1) ? 5'd0 : idx + 5'd1;
        end
    end

    //-------------------------------------------------------------------
    // STAGE 1: STUFFER
    //-------------------------------------------------------------------
    can_bit_stuffer u_stuffer (
        .clk           (clk),
        .rst_n         (rst_n),
        .clear         (1'b0),
        .bit_tick      (bit_tick),
        .stuff_en      (stuff_en),
        .data_valid    (data_valid),
        .bit_in        (bit_in),
        .ready         (ready_w),
        .stuff_pending (stuff_pending_w),
        .bit_out       (bit_out_w),
        .bit_out_valid (bit_out_valid_w),
        .stuffing      (stuffing_w)
    );

    assign led_bit_out       = bit_out_w;
    assign led_stuffing      = stuffing_w;
    assign led_stuff_pending = stuff_pending_w;

    //-------------------------------------------------------------------
    // STAGE 2: DESTUFFER  (fed directly from the stuffer's own output --
    // this IS the "CAN bus" in this demo: just a wire, no transceiver yet)
    //-------------------------------------------------------------------
    wire rx_bit, rx_dv, rx_err, rx_exp;

    can_bit_destuffer u_destuffer (
        .clk            (clk),
        .rst_n          (rst_n),
        .clear          (1'b0),
        .destuff_en     (1'b1),
        .bit_valid      (bit_out_valid_w),   // every stuffer tick, real bit or stuff bit alike
        .bit_in         (bit_out_w),
        .bit_out        (rx_bit),
        .data_valid     (rx_dv),
        .stuff_error    (rx_err),
        .stuff_expected (rx_exp)
    );

    assign led_recovered = rx_bit;   // destuffer holds this between updates, safe to view directly

    //-------------------------------------------------------------------
    // STAGE 3: COMPARATOR (AUTO mode only -- MANUAL mode has no known
    // "expected" sequence, so pass/error simply hold their last state)
    //-------------------------------------------------------------------
    logic [4:0] rx_idx;
    logic       pass_r, err_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_idx <= 5'd0;
            pass_r <= 1'b0;
            err_r  <= 1'b0;
        end else begin
            if (rx_err) err_r <= 1'b1;             // sticky: protocol stuff error

            if (!mode_sw && rx_dv) begin
                if (rx_bit == test_bit(rx_idx)) begin
                    pass_r <= 1'b1;
                end else begin
                    pass_r <= 1'b0;
                    err_r  <= 1'b1;                 // sticky: mismatch
                end
                rx_idx <= (rx_idx == VEC_LEN-1) ? 5'd0 : rx_idx + 5'd1;
            end
        end
    end

    assign led_pass  = pass_r;
    assign led_error = err_r;

endmodule