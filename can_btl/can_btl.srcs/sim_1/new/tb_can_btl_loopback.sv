//=============================================================================
// Testbench : tb_can_btl_loopback
//
//   BSP model -> can_bit_stuffer --(bit_out)--> [bus delay] --> can_btl (rx_in)
//        ^ bit_tick from can_btl                                   |
//        +---------------------------------------------------------+
//                       can_btl.sample_point / rx_bit -> can_bit_destuffer
//
// Every frame is stuffed on TX, sampled at the sample point by the BTL and
// de-stuffed on RX. Pass criteria: recovered bits == raw bits, no stuff_error.
//
//   L1  Hand-built frames (original vector, CRC-boundary trailing stuff bit,
//       long runs of 0s / 1s) + random run-heavy frames, 3 timing configs.
//   L2  Same with a 10-clock bus/transceiver delay (needs a later sample point
//       -> shows what PROP_SEG is for).
//   L3  NEGATIVE test: delay longer than the sample offset must be DETECTED
//       (data mismatch or stuff_error). Proves the testbench has teeth.
//=============================================================================
`timescale 1ns/1ps

module tb_can_btl_loopback;

    logic clk = 0, rst_n = 0, clear = 0;
    always #5 clk = ~clk;

    // ---------------- timing configuration ----------------
    logic [7:0] brp;
    logic [3:0] tseg1;
    logic [2:0] tseg2;
    integer     P;                 // clocks per bit

    // ---------------- shared signals (declared early: used by the BTL port list) ----------------
    logic tx_run = 0;
    wire  ready, stuff_pending, bus_bit, bus_valid, stuffing;
    logic sync_mode = 0;        // 1: node transmits with resync enabled (hsync off)
    logic txdom_gate = 1;       // 1: tx_dominant rule active; 0: rule disabled (negative control)
    wire  hs_w, rf_w, rl_w;
    integer n_rs = 0;
    always @(posedge clk) if (hs_w | rf_w | rl_w) n_rs = n_rs + 1;

    // ---------------- BTL ----------------
    wire tq_tick, bit_tick, sample_point, btl_rx_bit;
    wire [1:0] seg_state;
    wire rx_in;

    can_btl u_btl (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .brp(brp), .tseg1(tseg1), .tseg2(tseg2), .sjw(2'd1),
        .hsync_en(1'b0), .rsync_en(sync_mode),
        .tx_dominant(sync_mode & txdom_gate & tx_run & ~bus_bit),
        .rx_in(rx_in),
        .tq_tick(tq_tick), .bit_tick(bit_tick),
        .sample_point(sample_point), .rx_bit(btl_rx_bit),
        .seg_state(seg_state),
        .hard_sync(hs_w), .resync_full(rf_w), .resync_limited(rl_w)
    );

    // ---------------- TX side ----------------
    logic [127:0] tx_bits = 0;
    integer       tx_len = 0, tx_slen = 0, tx_idx = 0;

    wire tx_data_valid = tx_run && (tx_idx < tx_len);
    wire tx_bit_in     = (tx_idx < 128) ? tx_bits[tx_idx] : 1'b0;
    wire tx_stuff_en   = tx_run && (tx_idx < tx_slen);
    always @(posedge clk)
        if (tx_data_valid && ready) tx_idx <= tx_idx + 1;

    can_bit_stuffer u_stuffer (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .bit_tick(bit_tick), .stuff_en(tx_stuff_en),
        .data_valid(tx_data_valid), .bit_in(tx_bit_in),
        .ready(ready), .stuff_pending(stuff_pending),
        .bit_out(bus_bit), .bit_out_valid(bus_valid), .stuffing(stuffing)
    );

    // ---------------- bus / transceiver delay model ----------------
    integer       dly = 0;                    // extra clocks of delay (0..31)
    logic [31:0]  dly_sr = 32'hFFFF_FFFF;     // recessive idle
    always @(posedge clk) dly_sr <= {dly_sr[30:0], bus_bit};
    assign rx_in = (dly == 0) ? bus_bit : dly_sr[dly-1];

    // ---------------- RX side ----------------
    logic rx_run = 0;                         // set once the first bit is on the bus
    always @(posedge clk)
        if (clear)          rx_run <= 1'b0;
        else if (bus_valid) rx_run <= 1'b1;

    integer       rx_cnt = 0, err_seen = 0;
    logic [127:0] rx_bits = 0;
    wire          rx_destuff_en = rx_run && (rx_cnt < tx_slen);
    wire          dstf_bit, dstf_dv, dstf_err, dstf_exp;

    can_bit_destuffer u_destuffer (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .destuff_en(rx_destuff_en),
        .bit_valid(sample_point & rx_run),
        .bit_in(btl_rx_bit),
        .bit_out(dstf_bit), .data_valid(dstf_dv),
        .stuff_error(dstf_err), .stuff_expected(dstf_exp)
    );

    always @(posedge clk) begin
        if (dstf_dv && rx_cnt < 128) begin
            rx_bits[rx_cnt] = dstf_bit;
            rx_cnt = rx_cnt + 1;
        end
        if (dstf_err) err_seen = err_seen + 1;
    end

    // ---------------- frame runner ----------------
    integer errors = 0, tests = 0;
    integer last_err_seen, last_mismatch;

    // runs one frame, returns result in last_mismatch / last_err_seen
    task run_frame_raw(input logic [127:0] bits, input integer n, input integer slen);
        integer i;
        begin
            @(negedge clk); clear = 1;
            @(negedge clk); clear = 0;
            tx_bits = bits; tx_len = n; tx_slen = slen; tx_idx = 0;
            rx_cnt = 0; rx_bits = 0; err_seen = 0;
            tx_run = 1;
            repeat (P * (n + n / 4 + 10)) @(negedge clk);
            tx_run = 0;
            @(negedge clk);

            last_mismatch = 0;
            if (rx_cnt < n) last_mismatch = n;     // lost bits count as mismatch
            else
                for (i = 0; i < n; i = i + 1)
                    if (rx_bits[i] !== bits[i]) last_mismatch = last_mismatch + 1;
            last_err_seen = err_seen;
        end
    endtask

    task run_frame(input string name, input logic [127:0] bits, input integer n, input integer slen);
        begin
            run_frame_raw(bits, n, slen);
            tests = tests + 1;
            if (last_mismatch == 0 && last_err_seen == 0)
                $display("[PASS] %s (%0d bits)", name, n);
            else begin
                $display("[FAIL] %s: %0d mismatching bits, %0d stuff_error", name, last_mismatch, last_err_seen);
                errors = errors + 1;
            end
        end
    endtask

    // quiet version used for random frames; returns 1 if frame OK
    task run_random_set(input integer count, input string tag);
        integer r, n, s, k, bad;
        logic prev;
        logic [127:0] v;
        begin
            bad = 0;
            for (r = 0; r < count; r = r + 1) begin
                n = 20 + ($urandom % 50);
                s = 1 + ($urandom % n);
                prev = $urandom;
                v = 0;
                for (k = 0; k < n; k = k + 1) begin
                    if (($urandom % 4) == 0) prev = ~prev;
                    v[k] = prev;
                end
                run_frame_raw(v, n, s);
                if (last_mismatch != 0 || last_err_seen != 0) begin
                    bad = bad + 1;
                    if (bad <= 3)
                        $display("   random frame #%0d failed: n=%0d slen=%0d mismatches=%0d stuff_err=%0d",
                                 r, n, s, last_mismatch, last_err_seen);
                end
            end
            tests = tests + 1;
            if (bad == 0)
                $display("[PASS] %s: %0d random run-heavy frames", tag, count);
            else begin
                $display("[FAIL] %s: %0d of %0d random frames failed", tag, bad, count);
                errors = errors + 1;
            end
        end
    endtask

    task set_cfg(input [7:0] b, input [3:0] t1, input [2:0] t2, input integer d);
        begin
            @(negedge clk);
            brp = b; tseg1 = t1; tseg2 = t2; dly = d;
            P = (t1 + t2 + 3) * (b + 1);
            $display("--- config: BRP=%0d TSEG1=%0d TSEG2=%0d  bit=%0d clk, sample@%0d clk, bus delay=%0d clk ---",
                     b, t1, t2, P, (t1 + 2) * (b + 1), d);
        end
    endtask

    task hand_frames;
        logic [127:0] v;
        begin
            v = 0;
            v[4:0] = 5'b00000; v[5] = 1; v[6] = 0;
            v[11:7] = 5'b11111; v[12] = 0; v[13] = 1;
            v[18:14] = 5'b00000; v[19] = 1;
            run_frame("original vector, stuffed throughout", v, 20, 20);

            v = 0; v[11:0] = 12'b1111_1010_1010; v[12] = 1; v[13] = 0;
            run_frame("CRC field ends on 5x1 (trailing stuff bit)", v, 14, 12);

            v = 0; v[5:0] = 6'b010101; v[6] = 1; v[11:7] = 5'b00000; v[12] = 1; v[13] = 1;
            run_frame("CRC field ends on 5x0 (trailing stuff bit)", v, 14, 12);

            v = 0;
            run_frame("40 x 0", v, 40, 40);
            v = {128{1'b1}};
            run_frame("40 x 1", v, 40, 40);
        end
    endtask

    // ---------------- main ----------------
    logic [127:0] vneg;
    integer k;
    logic prevb;

    initial begin
        brp = 3; tseg1 = 5; tseg2 = 2; P = 40;
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // ---------------- L1: no extra delay ----------------
        set_cfg(3, 5, 2, 0);
        hand_frames();
        run_random_set(40, "L1 BRP=3 TSEG1=5 TSEG2=2");

        set_cfg(0, 9, 3, 0);
        hand_frames();
        run_random_set(40, "L1 BRP=0 TSEG1=9 TSEG2=3");

        set_cfg(9, 15, 2, 0);              // 500 kbit/s @ 100 MHz
        hand_frames();
        run_random_set(6, "L1 500 kbit/s setup");

        // ---------------- L2: with bus delay ----------------
        set_cfg(3, 5, 2, 10);              // sample @28, delay 10 (+2 sync)
        hand_frames();
        run_random_set(40, "L2 delay=10, BRP=3 TSEG1=5 TSEG2=2");

        set_cfg(1, 15, 7, 20);             // sample @34, delay 20 (+2 sync)
        run_random_set(25, "L2 delay=20, BRP=1 TSEG1=15 TSEG2=7");

        // ---------------- L3: negative test ----------------
        // sample offset = 11 clk, delay = 14 clk (+2 sync) -> sampling the
        // PREVIOUS bit. The checks must notice.
        set_cfg(0, 9, 3, 14);
        vneg = 0; prevb = 0;
        for (k = 0; k < 40; k = k + 1) begin
            if (($urandom % 3) == 0) prevb = ~prevb;
            vneg[k] = prevb;
        end
        run_frame_raw(vneg, 40, 40);
        tests = tests + 1;
        if (last_mismatch != 0 || last_err_seen != 0)
            $display("[PASS] L3 sample point before the bus delay is DETECTED (%0d mismatching bits, %0d stuff_error)",
                     last_mismatch, last_err_seen);
        else begin
            $display("[FAIL] L3 testbench did not notice a sample point earlier than the bus delay");
            errors = errors + 1;
        end

        // ---------------- L4: TX with resync ENABLED ----------------
        // The node's own (delayed) edges must NOT cause resynchronisation.
        sync_mode = 1; txdom_gate = 1;
        set_cfg(3, 5, 2, 0);
        n_rs = 0;
        hand_frames();
        run_random_set(20, "L4 resync on, BRP=3 TSEG1=5 TSEG2=2");
        tests = tests + 1;
        if (n_rs == 0) $display("[PASS] L4 no resync triggered by the node's own edges (delay 0)");
        else begin $display("[FAIL] L4 %0d spurious resync events (delay 0)", n_rs); errors = errors + 1; end

        set_cfg(3, 5, 2, 10);
        n_rs = 0;
        hand_frames();
        run_random_set(20, "L4 resync on, delay=10");
        tests = tests + 1;
        if (n_rs == 0) $display("[PASS] L4 no resync triggered by the node's own delayed edges (delay 10)");
        else begin $display("[FAIL] L4 %0d spurious resync events (delay 10)", n_rs); errors = errors + 1; end

        set_cfg(0, 9, 3, 6);
        n_rs = 0;
        run_random_set(20, "L4 resync on, BRP=0 TSEG1=9 TSEG2=3 delay=6");
        tests = tests + 1;
        if (n_rs == 0) $display("[PASS] L4 no spurious resync (BRP=0, delay 6)");
        else begin $display("[FAIL] L4 %0d spurious resync events (BRP=0)", n_rs); errors = errors + 1; end

        // ---------------- L5: control, tx_dominant rule OFF ----------------
        // Without the rule, the delayed own edges ARE taken for late edges.
        txdom_gate = 0;
        set_cfg(3, 5, 2, 10);
        n_rs = 0;
        run_random_set(10, "L5 rule off (frames may still decode)");
        tests = tests + 1;
        if (n_rs > 0) $display("[PASS] L5 with the tx_dominant rule disabled the node resyncs on its own edges (%0d events) -> the rule matters", n_rs);
        else begin $display("[FAIL] L5 expected resync events with the rule disabled"); errors = errors + 1; end
        sync_mode = 0; txdom_gate = 1;

        $display("----------------------------------------------------");
        if (errors == 0) $display("ALL BTL LOOPBACK TESTS PASSED (%0d test groups)", tests);
        else             $display("%0d BTL LOOPBACK TEST(S) FAILED", errors);
        $display("----------------------------------------------------");
        $finish;
    end

endmodule