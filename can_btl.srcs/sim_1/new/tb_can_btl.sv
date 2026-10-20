//=============================================================================
// Testbench : tb_can_btl
//
// Expected values come from the closed-form timing equations (NOT from a copy
// of the RTL structure):
//     TQ clocks    = BRP + 1
//     bit period   = (TSEG1 + TSEG2 + 3) * (BRP + 1)
//     sample offset= (TSEG1 + 2) * (BRP + 1)   (clocks after bit_tick)
//
// T1  Timing sweep over 8 configurations (incl. min, max and 500k/1M setups):
//       - bit_tick period exact, every bit
//       - sample_point exactly 'sample offset' clocks after bit_tick
//       - tq_tick spacing exact
//       - strobes 1 clock wide, bit_tick and sample_point never coincide
//       - number of strobes in a known window
// T2  RX sampling: 32-bit pattern, with a 2-clock glitch inside TSEG1 on every
//       bit. rx_bit captured at sample_point must equal the pattern
//       (glitch rejected, value taken at the sample point).
// T3  'clear' in the middle of a bit restarts the bit exactly (timing checked
//       by the same monitor).
//=============================================================================
`timescale 1ns/1ps

module tb_can_btl;

    logic       clk = 0, rst_n = 0, clear = 0;
    logic [7:0] brp;
    logic [3:0] tseg1;
    logic [2:0] tseg2;
    logic       rx_in = 1;
    wire        tq_tick, bit_tick, sample_point, rx_bit;
    wire  [1:0] seg_state;

    can_btl dut (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .brp(brp), .tseg1(tseg1), .tseg2(tseg2), .sjw(2'd0),
        .hsync_en(1'b0), .rsync_en(1'b0), .tx_dominant(1'b0),   // sync disabled: Day 1-2 behaviour
        .rx_in(rx_in),
        .tq_tick(tq_tick), .bit_tick(bit_tick),
        .sample_point(sample_point), .rx_bit(rx_bit),
        .seg_state(seg_state),
        .hard_sync(), .resync_full(), .resync_limited()
    );

    always #5 clk = ~clk;

    //-----------------------------------------------------------------
    // Timing monitor
    //-----------------------------------------------------------------
    integer cyc = 0;
    integer last_bit = -1, last_tq = -1;
    integer clear_cyc = -1;
    integer exp_period = 0, exp_offset = 0, exp_tq = 0;
    integer n_bit = 0, n_sp = 0, mon_errors = 0;
    reg     mon_en = 0;
    reg     prev_bt = 0, prev_sp = 0, prev_tq = 0, prev_clear = 0;

    task mon_err(input [8*40-1:0] msg, input integer got, input integer exp);
        begin
            mon_errors = mon_errors + 1;
            if (mon_errors <= 10)
                $display("   [MON] cyc=%0d %0s got=%0d expected=%0d", cyc, msg, got, exp);
        end
    endtask

    always @(posedge clk) begin
        cyc = cyc + 1;

        if (mon_en) begin
            // ---- bit_tick ----
            if (bit_tick) begin
                if (prev_bt)       mon_err("bit_tick wider than 1 clk", 2, 1);
                if (sample_point)  mon_err("bit_tick & sample_point same clk", 1, 0);
                if (last_bit >= 0) begin
                    if ((cyc - last_bit) != exp_period)
                        mon_err("bit period", cyc - last_bit, exp_period);
                end else if (clear_cyc >= 0) begin
                    // first bit_tick after a clear: SYNC_SEG restarted at clear+1
                    if ((cyc - clear_cyc) != exp_period + 1)
                        mon_err("first bit_tick after clear", cyc - clear_cyc, exp_period + 1);
                end
                last_bit = cyc;
                n_bit    = n_bit + 1;
            end

            // ---- sample_point ----
            if (sample_point) begin
                if (prev_sp) mon_err("sample_point wider than 1 clk", 2, 1);
                if (last_bit >= 0 && last_bit != cyc) begin
                    if ((cyc - last_bit) != exp_offset)
                        mon_err("sample offset", cyc - last_bit, exp_offset);
                end else if (last_bit < 0 && clear_cyc >= 0) begin
                    if ((cyc - clear_cyc) != exp_offset + 1)
                        mon_err("first sample after clear", cyc - clear_cyc, exp_offset + 1);
                end
                n_sp = n_sp + 1;
            end

            // ---- tq_tick ----
            if (tq_tick) begin
                if (last_tq >= 0) begin
                    if ((cyc - last_tq) != exp_tq)
                        mon_err("tq spacing", cyc - last_tq, exp_tq);
                end else if (clear_cyc >= 0) begin
                    if ((cyc - clear_cyc) != exp_tq + 1)
                        mon_err("first tq after clear", cyc - clear_cyc, exp_tq + 1);
                end
                last_tq = cyc;
            end
        end

        // A clear is processed AFTER the strobe checks: strobes visible at the
        // clear edge itself still belong to the pre-clear bit.
        if (clear && !prev_clear) begin
            clear_cyc = cyc;
            last_bit  = -1;
            last_tq   = -1;
        end
        prev_clear = clear;

        prev_bt = bit_tick;
        prev_sp = sample_point;
        prev_tq = tq_tick;
    end

    //-----------------------------------------------------------------
    // T1 helper
    //-----------------------------------------------------------------
    integer total_fail = 0;

    task run_cfg(input [7:0] b, input [3:0] t1, input [2:0] t2, input integer nbits);
        integer err_before;
        reg     cnt_ok;
        begin
            mon_en = 0;
            @(negedge clk);
            brp = b; tseg1 = t1; tseg2 = t2; clear = 1;
            @(negedge clk);
            clear = 0;
            exp_tq     = b + 1;
            exp_period = (t1 + t2 + 3) * (b + 1);
            exp_offset = (t1 + 2) * (b + 1);
            n_bit = 0; n_sp = 0;
            err_before = mon_errors;
            mon_en = 1;
            repeat (exp_period * (nbits + 1)) @(negedge clk);
            mon_en = 0;

            cnt_ok = (n_bit == nbits) && (n_sp == nbits + 1);
            if (!cnt_ok)
                $display("   strobe count: bit_tick=%0d (exp %0d)  sample_point=%0d (exp %0d)",
                         n_bit, nbits, n_sp, nbits + 1);

            if (mon_errors == err_before && cnt_ok)
                $display("[PASS] T1 BRP=%0d TSEG1=%0d TSEG2=%0d : period=%0d clk, sample@%0d clk (%0d %%)",
                         b, t1, t2, exp_period, exp_offset, (100 * exp_offset) / exp_period);
            else begin
                $display("[FAIL] T1 BRP=%0d TSEG1=%0d TSEG2=%0d", b, t1, t2);
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // T2 helper : RX sampling
    //-----------------------------------------------------------------
    reg [31:0] pat = 32'hA5C396F1;
    reg        cap [0:63];
    integer    n_cap = 0;
    reg        cap_en = 0;

    always @(posedge clk)
        if (cap_en && sample_point && n_cap < 64) begin
            cap[n_cap] = rx_bit;
            n_cap = n_cap + 1;
        end

    task send_bit(input b);
        begin
            @(negedge clk);
            while (!bit_tick) @(negedge clk);   // aligned to start of bit
            cap_en = 1;
            repeat (2) @(negedge clk);  rx_in = b;     // bus takes the new value
            repeat (2) @(negedge clk);  rx_in = ~b;    // 2-clk glitch inside TSEG1
            repeat (2) @(negedge clk);  rx_in = b;
        end
    endtask

    task run_rx(input [7:0] b, input [3:0] t1, input [2:0] t2);
        integer i, bad;
        begin
            mon_en = 0; cap_en = 0; n_cap = 0; rx_in = 1;
            @(negedge clk);
            brp = b; tseg1 = t1; tseg2 = t2; clear = 1;
            @(negedge clk);
            clear = 0;
            for (i = 0; i < 32; i = i + 1) send_bit(pat[i]);
            repeat ((t1 + t2 + 3) * (b + 1)) @(negedge clk);   // let last sample happen
            cap_en = 0;

            bad = 0;
            if (n_cap != 32) begin
                $display("   captured %0d samples, expected 32", n_cap);
                bad = 1;
            end else
                for (i = 0; i < 32; i = i + 1)
                    if (cap[i] !== pat[i]) begin
                        if (bad < 5) $display("   bit %0d sampled %0b expected %0b", i, cap[i], pat[i]);
                        bad = bad + 1;
                    end
            if (bad == 0)
                $display("[PASS] T2 RX sampling BRP=%0d TSEG1=%0d TSEG2=%0d : 32/32 bits, glitches rejected", b, t1, t2);
            else begin
                $display("[FAIL] T2 RX sampling BRP=%0d TSEG1=%0d TSEG2=%0d", b, t1, t2);
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // T3 : clear in the middle of a bit
    //-----------------------------------------------------------------
    task run_clear_test(input [7:0] b, input [3:0] t1, input [2:0] t2, input integer wait_clks);
        integer err_before;
        integer k;
        begin
            mon_en = 0;
            @(negedge clk);
            brp = b; tseg1 = t1; tseg2 = t2; clear = 1;
            @(negedge clk);
            clear = 0;
            exp_tq     = b + 1;
            exp_period = (t1 + t2 + 3) * (b + 1);
            exp_offset = (t1 + 2) * (b + 1);
            err_before = mon_errors;
            mon_en = 1;
            for (k = 0; k < 4; k = k + 1) begin
                repeat (exp_period + wait_clks + k * 3) @(negedge clk);
                clear = 1;                         // restart in the middle of a bit
                @(negedge clk);
                clear = 0;
            end
            repeat (exp_period * 3) @(negedge clk);
            mon_en = 0;
            if (mon_errors == err_before)
                $display("[PASS] T3 clear mid-bit restarts bit exactly (BRP=%0d TSEG1=%0d TSEG2=%0d, 4 restarts)", b, t1, t2);
            else begin
                $display("[FAIL] T3 clear mid-bit");
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // main
    //-----------------------------------------------------------------
    initial begin
        brp = 0; tseg1 = 0; tseg2 = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // ---------------- T1 ----------------
        run_cfg(  3,  5, 2, 40);   // 4 clk/TQ, 10 TQ/bit
        run_cfg(  0,  0, 0, 40);   // minimum: 1 clk/TQ, 3 TQ/bit
        run_cfg(  0,  3, 1, 40);
        run_cfg(  1,  7, 3, 40);
        run_cfg(  2, 15, 7, 12);   // maximum segments: 25 TQ/bit
        run_cfg(  9, 15, 2, 10);   // 500 kbit/s @ 100 MHz
        run_cfg(  4, 15, 2, 10);   // 1 Mbit/s   @ 100 MHz
        run_cfg(255, 15, 7,  2);   // maximum prescaler

        // ---------------- T2 ----------------
        run_rx(3,  5, 2);
        run_rx(0,  9, 3);          // fastest config that still leaves sample > sync latency
        run_rx(9, 15, 2);

        // ---------------- T3 ----------------
        run_clear_test(3,  5, 2, 17);
        run_clear_test(0,  3, 1,  2);
        run_clear_test(2, 15, 7, 31);

        $display("----------------------------------------------------");
        if (total_fail == 0 && mon_errors == 0)
            $display("ALL BTL TESTS PASSED");
        else
            $display("%0d BTL TEST(S) FAILED  (monitor errors: %0d)", total_fail, mon_errors);
        $display("----------------------------------------------------");
        $finish;
    end

endmodule