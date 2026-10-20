//=============================================================================
// Testbench : tb_can_btl_baud                       (Day 4)
//
// Do the sample points land where they should at REAL CAN baud rates?
// System clock = 100 MHz (10 ns), the usual Artix-7 board clock.
//
//   baud       BRP TSEG1 TSEG2 SJW   TQ      TQ/bit  bit time  sample point
//   1 Mbit/s     4   15    2    2TQ   50 ns    20     1000 ns  85 %
//   1 Mbit/s     9    6    1    1TQ  100 ns    10     1000 ns  80 %
//   500 kbit/s   9   15    2    3TQ  100 ns    20     2000 ns  85 %
//   500 kbit/s   9   14    3    4TQ  100 ns    20     2000 ns  80 %
//   500 kbit/s   9   13    4    4TQ  100 ns    20     2000 ns  75 %
//   250 kbit/s  19   15    2    3TQ  200 ns    20     4000 ns  85 %
//   125 kbit/s  39   15    2    3TQ  400 ns    20     8000 ns  85 %
//    20 kbit/s 249   15    2    3TQ 2500 ns    20    50000 ns  85 %
//   (slowest possible at 100 MHz: BRP=255, 25 TQ -> 15.6 kbit/s)
//   All settings obey: 8..25 TQ per bit, PHASE_SEG2 >= 2 TQ, SJW <= PHASE_SEG2.
//
// For every setting, four checks:
//   B1  BIT TIME   bit_tick spacing is exactly 1/baud (in ns), every bit
//   B2  SAMPLE     sample_point is exactly (TSEG1+2)*TQ after bit_tick, every bit
//   B3  RECEIVER   an ideal transmitter at that baud sends a 32-bit frame
//                  (SOF hard-syncs the BTL at a random phase). Every bit must be
//                  sampled at exactly the intended % of the bit and read correctly,
//                  and an ideal transmitter must trigger NO resync.
//   B4  TRANSMITTER the node sends 32 bits and reads its own bus through a
//                  250 ns loop delay (transceiver + wiring). Every bit must be
//                  read back correctly, with no resync on its own edges.
//                  The setup/hold margin of the sample is printed.
//   B5  BOUNDARY   proves the margin formula (margin = offset - delay - 3 clk):
//                  margin 0 must fail, margin 4 clk must pass.
//=============================================================================
`timescale 1ns/1ps

module tb_can_btl_baud;

    localparam integer CLK_NS = 10;          // 100 MHz
    localparam integer DLY    = 25;          // loop delay in clocks = 250 ns
    localparam integer NBITS  = 32;

    logic       clk = 0, rst_n = 0, clear = 0;
    logic [7:0] brp;
    logic [3:0] tseg1;
    logic [2:0] tseg2;
    logic [1:0] sjw;
    logic       hsync_en = 0, rsync_en = 0;
    logic       tx_mode = 0;                 // 0: bus driven by the testbench, 1: node's own TX
    logic       rx_drv = 1;

    // ---------------- node transmitter + bus delay model ----------------
    localparam [31:0] PATV = 32'hB2C5_9D6A;  // bit 0 (SOF) = 0, plenty of transitions and runs
    logic       tx_bit = 1;
    integer     txk = 0;
    logic [31:0] dly_sr = 32'hFFFF_FFFF;     // recessive idle

    wire tq_tick, bit_tick, sample_point, rx_bit;
    wire [1:0] seg_state;
    wire hard_sync, resync_full, resync_limited;

    wire rx_in = tx_mode ? dly_sr[DLY-1] : rx_drv;

    can_btl dut (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .brp(brp), .tseg1(tseg1), .tseg2(tseg2), .sjw(sjw),
        .hsync_en(hsync_en), .rsync_en(rsync_en),
        .tx_dominant(tx_mode & ~tx_bit),
        .rx_in(rx_in),
        .tq_tick(tq_tick), .bit_tick(bit_tick), .sample_point(sample_point),
        .rx_bit(rx_bit), .seg_state(seg_state),
        .hard_sync(hard_sync), .resync_full(resync_full), .resync_limited(resync_limited)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        dly_sr <= {dly_sr[30:0], tx_bit};
        if (tx_mode && bit_tick && txk < NBITS) begin   // stuffer-like: new bit on bit_tick
            tx_bit <= PATV[txk];
            txk    <= txk + 1;
        end
    end

    //-----------------------------------------------------------------
    // Monitor (single block: no race on 'cyc')
    //-----------------------------------------------------------------
    integer cyc = 0, clr_cyc = -1;
    integer bt_idx [0:255];
    integer sp_idx [0:255];
    reg     sp_val [0:255];
    integer n_bt = 0, n_sp = 0, n_hard = 0, n_full = 0, n_lim = 0;
    reg     prev_clear = 0;

    always @(posedge clk) begin
        cyc = cyc + 1;
        if (bit_tick && n_bt < 256) begin bt_idx[n_bt] = cyc; n_bt = n_bt + 1; end
        if (sample_point && n_sp < 256) begin
            sp_idx[n_sp] = cyc; sp_val[n_sp] = rx_bit; n_sp = n_sp + 1;
        end
        if (hard_sync)      n_hard = n_hard + 1;
        if (resync_full)    n_full = n_full + 1;
        if (resync_limited) n_lim  = n_lim  + 1;
        if (clear && !prev_clear) clr_cyc = cyc;
        prev_clear = clear;
    end

    task mon_reset;
        begin n_bt = 0; n_sp = 0; n_hard = 0; n_full = 0; n_lim = 0; end
    endtask

    // value captured by a sample_point at exactly cycle idx: 0/1, or -1 if none there
    function integer sample_at(input integer idx);
        integer i;
        begin
            sample_at = -1;
            for (i = 0; i < n_sp; i = i + 1)
                if (sp_idx[i] == idx) sample_at = sp_val[i];
        end
    endfunction

    //-----------------------------------------------------------------
    // Stimulus helpers
    //-----------------------------------------------------------------
    integer late_drive = 0;
    task wait_cyc(input integer target);
        begin while (cyc < target) @(negedge clk); end
    endtask
    task drive_edge(input integer E, input v);     // synchronised RX shows the change in cycle E
        begin
            if (cyc > E - 3) late_drive = late_drive + 1;
            wait_cyc(E - 3);
            rx_drv = v;
        end
    endtask

    task setup(input h_en, input r_en, input txm);
        begin
            @(negedge clk);
            hsync_en = h_en; rsync_en = r_en; tx_mode = txm;
            rx_drv = 1; tx_bit = 1; txk = 0; dly_sr = 32'hFFFF_FFFF;
            clear = 1;
            @(negedge clk);
            clear = 0;
            mon_reset;
        end
    endtask

    //-----------------------------------------------------------------
    // One baud-rate setting
    //-----------------------------------------------------------------
    integer total_fail = 0, n_cfg = 0;
    integer TQ, P, off, bit_ns, exp_ns, sp_pm, tqpb, ps2, sjtq;
    integer ok1, ok2, ok3, ok4, bad3, bad4, k, j, E_sof, bt_k, rxd;
    integer margin_before, margin_after;
    reg     spec_ok;

    task run_baud(input integer baud, input [7:0] b, input [3:0] t1, input [2:0] t2, input [1:0] sj);
        begin
            n_cfg = n_cfg + 1;
            brp = b; tseg1 = t1; tseg2 = t2; sjw = sj;
            TQ = b + 1; tqpb = t1 + t2 + 3; P = tqpb * TQ; off = (t1 + 2) * TQ;
            bit_ns = P * CLK_NS; exp_ns = 1000000000 / baud;
            sp_pm = (1000 * off) / P;
            ps2 = t2 + 1; sjtq = sj + 1;
            spec_ok = (tqpb >= 8) && (tqpb <= 25) && (ps2 >= 2) && (sjtq <= ps2);

            // ---------- B1 / B2 : free-running timing ----------
            setup(1'b0, 1'b0, 1'b0);
            wait_cyc(cyc + 13 * P);
            ok1 = (n_bt >= 12) && (bit_ns == exp_ns);
            for (k = 1; k < n_bt; k = k + 1)
                if (bt_idx[k] - bt_idx[k-1] != P) ok1 = 0;
            ok2 = (n_sp >= 12);
            for (j = 0; j < n_sp; j = j + 1) begin
                bt_k = -1;
                for (k = 0; k < n_bt; k = k + 1)
                    if (bt_idx[k] <= sp_idx[j]) bt_k = bt_idx[k];
                if (bt_k < 0) begin
                    if (sp_idx[j] - clr_cyc != off + 1) ok2 = 0;       // before the first tick: relative to clear
                end else if (sp_idx[j] - bt_k != off) ok2 = 0;
            end

            // ---------- B3 : receiver, ideal transmitter, hard sync at random phase ----------
            setup(1'b1, 1'b0, 1'b0);
            E_sof = cyc + 10 + ($urandom % P);
            drive_edge(E_sof, PATV[0]);
            wait_cyc(E_sof);
            hsync_en = 0; rsync_en = 1;
            for (k = 1; k < NBITS; k = k + 1)
                drive_edge(E_sof + k * P, PATV[k]);
            wait_cyc(E_sof + (NBITS + 2) * P);
            bad3 = 0;
            for (k = 0; k < NBITS; k = k + 1) begin
                rxd = sample_at(E_sof + k * P + off);
                if (rxd != PATV[k]) bad3 = bad3 + 1;
            end
            ok3 = (bad3 == 0) && (n_hard == 1) && (n_full == 0) && (n_lim == 0);

            // ---------- B4 : transmitter reads back its own bit through the loop delay ----------
            setup(1'b0, 1'b1, 1'b1);
            wait_cyc(cyc + (NBITS + 3) * P);
            bad4 = 0;
            for (k = 0; k < NBITS; k = k + 1) begin
                if (k >= n_bt) bad4 = bad4 + 1;
                else begin
                    rxd = sample_at(bt_idx[k] + off);
                    if (rxd != PATV[k]) bad4 = bad4 + 1;
                end
            end
            margin_before = off - DLY - 3;                  // clocks the new bit is stable before the sample
            margin_after  = P - margin_before;              // clocks it stays stable after the sample
            ok4 = (bad4 == 0) && (n_hard == 0) && (n_full == 0) && (n_lim == 0) && (margin_before > 0);

            // ---------- report ----------
            if (ok1 && ok2 && ok3 && ok4) begin
                $display("[PASS] %0d kbit/s  BRP=%0d TSEG1=%0d TSEG2=%0d SJW=%0dTQ | bit=%0d ns (%0d TQ x %0d ns) | sample @%0d ns = %0d.%0d %% | RX %0d/%0d | TX %0d/%0d (margin %0d ns before, %0d ns after)%0s",
                         baud / 1000, b, t1, t2, sjtq, bit_ns, tqpb, TQ * CLK_NS,
                         off * CLK_NS, sp_pm / 10, sp_pm % 10,
                         NBITS - bad3, NBITS, NBITS - bad4, NBITS,
                         margin_before * CLK_NS, margin_after * CLK_NS,
                         spec_ok ? "" : "  [NOTE: outside CAN spec limits]");
            end else begin
                $display("[FAIL] %0d kbit/s BRP=%0d TSEG1=%0d TSEG2=%0d : B1(bit time)=%0d B2(sample offset)=%0d B3(receiver)=%0d B4(transmitter)=%0d",
                         baud / 1000, b, t1, t2, ok1, ok2, ok3, ok4);
                if (!ok3) $display("       B3: %0d bad bits, hard_sync=%0d resync_full=%0d resync_limited=%0d",
                                   bad3, n_hard, n_full, n_lim);
                if (!ok4) $display("       B4: %0d bad bits, resync events=%0d, margin_before=%0d clk",
                                   bad4, n_hard + n_full + n_lim, margin_before);
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // Boundary proof for the transmitter read-back margin.
    //   new bit reaches the sampler (DLY+3) clocks after bit_tick, the sample
    //   captures one clock before bit_tick + off  ->  margin = off - DLY - 3.
    //   margin <= 0 must read the PREVIOUS bit (fail), margin >= 1 must pass.
    //-----------------------------------------------------------------
    task run_boundary(input [7:0] b, input [3:0] t1, input [2:0] t2, input expect_pass);
        integer bad, kk, rr;
        reg got_pass;
        begin
            brp = b; tseg1 = t1; tseg2 = t2; sjw = 2'd0;
            TQ = b + 1; P = (t1 + t2 + 3) * TQ; off = (t1 + 2) * TQ;
            setup(1'b0, 1'b1, 1'b1);
            wait_cyc(cyc + (NBITS + 3) * P);
            bad = 0;
            for (kk = 0; kk < NBITS; kk = kk + 1) begin
                if (kk >= n_bt) bad = bad + 1;
                else begin
                    rr = sample_at(bt_idx[kk] + off);
                    if (rr != PATV[kk]) bad = bad + 1;
                end
            end
            got_pass = (bad == 0);
            if (got_pass == expect_pass)
                $display("[PASS] boundary: sample offset %0d clk, loop delay %0d clk -> margin %0d clk -> read-back %0s as predicted (%0d bad bits)",
                         off, DLY, off - DLY - 3, got_pass ? "OK" : "FAILS", bad);
            else begin
                $display("[FAIL] boundary: offset %0d clk margin %0d clk: expected %0s, got %0s",
                         off, off - DLY - 3, expect_pass ? "pass" : "fail", got_pass ? "pass" : "fail");
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // main
    //-----------------------------------------------------------------
    initial begin
        brp = 0; tseg1 = 0; tseg2 = 0; sjw = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        $display("System clock 100 MHz. Loop delay for the transmitter test: %0d ns.", DLY * CLK_NS);

        run_baud(1000000,   4, 15, 2, 2'd1);
        run_baud(1000000,   9,  6, 1, 2'd0);
        run_baud( 500000,   9, 15, 2, 2'd2);
        run_baud( 500000,   9, 14, 3, 2'd3);
        run_baud( 500000,   9, 13, 4, 2'd3);
        run_baud( 250000,  19, 15, 2, 2'd2);
        run_baud( 125000,  39, 15, 2, 2'd2);
        run_baud(  20000, 249, 15, 2, 2'd2);

        $display("--- boundary proof of the margin formula (TQ=4 clk, delay %0d clk) ---", DLY);
        run_boundary(3, 5, 2, 1'b0);    // offset 28 clk -> margin 0: must FAIL
        run_boundary(3, 6, 2, 1'b1);    // offset 32 clk -> margin 4: must pass

        if (late_drive != 0) begin
            $display("[FAIL] testbench drove %0d edges too late (test bug)", late_drive);
            total_fail = total_fail + 1;
        end

        $display("----------------------------------------------------");
        if (total_fail == 0) $display("ALL BAUD-RATE TESTS PASSED (%0d settings)", n_cfg);
        else                 $display("%0d BAUD-RATE SETTING(S) FAILED", total_fail);
        $display("----------------------------------------------------");
        $finish;
    end

endmodule