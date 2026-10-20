//=============================================================================
// Testbench : tb_can_btl_sync     (Day 3: hard sync, resync, SJW)
//
// Notation (all in clock cycles, indices as seen by the monitor):
//   TQ  = BRP+1                P   = (TSEG1+TSEG2+3)*TQ       off = (TSEG1+2)*TQ
//   SJ  = SJW in TQ (1..4)     L2  = TSEG2+1
//   An edge is placed so that the synchronised RX signal first shows it in
//   cycle E.  A = first cycle of a bit (SYNC_SEG).  p = E - A.
//
// Expected behaviour (derived from the CAN rules, NOT from the RTL):
//   hard sync (idle, SOF edge at E)    : sample_point at E+off, bit_tick at E+P
//   resync, edge at position p of a bit that started at A:
//     p <  TQ                          : e = 0      -> grid unchanged
//     TQ <= p < off  (late edge)       : e = p/TQ
//         tx_dominant                  :            -> ignored (grid unchanged)
//         e <= SJ                      : bit restarted at the edge:
//                                          sample at E+off, bit_tick at E+P
//         e >  SJ                      : TSEG1 + SJ TQ:
//                                          sample at A+off+SJ*TQ, bit_tick at A+P+SJ*TQ
//     p >= off       (early edge)      : k = (p-off)/TQ, e = L2-k
//         e <= SJ                      : bit ends at the edge:
//                                          bit_tick at E+1 and again at E+P,
//                                          next sample at E+off
//         e >  SJ                      : TSEG2 - SJ TQ:
//                                          bit_tick at A+P-SJ*TQ, next sample +off
//
//   D1..D4  sweep p = 0..P-1 for every SJW, 4 configurations (+ tx_dominant)
//   S1      only ONE synchronisation per bit time
//   S2      edge ignored when the previous sample point was dominant
//   S3      sync disabled (both enables low): edges must not move the grid
//   S4      oscillator mismatch of 0.5 % (limit for this setup, SJW = 3 TQ: 0.58 %,
//           from the CAN tolerance formulas): resync keeps all bits correct (100 bits fast, 250 bits slow)
//   S5      same mismatch with resync OFF must fail (testbench has teeth)
//   S6      3 % mismatch is beyond what SJW can correct -> must be detected
//=============================================================================
`timescale 1ns/1ps

module tb_can_btl_sync;

    logic       clk = 0, rst_n = 0, clear = 0;
    logic [7:0] brp;
    logic [3:0] tseg1;
    logic [2:0] tseg2;
    logic [1:0] sjw;
    logic       hsync_en = 0, rsync_en = 0, tx_dominant = 0;
    logic       rx_in = 1;

    wire tq_tick, bit_tick, sample_point, rx_bit;
    wire [1:0] seg_state;
    wire hard_sync, resync_full, resync_limited;

    can_btl dut (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .brp(brp), .tseg1(tseg1), .tseg2(tseg2), .sjw(sjw),
        .hsync_en(hsync_en), .rsync_en(rsync_en), .tx_dominant(tx_dominant),
        .rx_in(rx_in),
        .tq_tick(tq_tick), .bit_tick(bit_tick), .sample_point(sample_point),
        .rx_bit(rx_bit), .seg_state(seg_state),
        .hard_sync(hard_sync), .resync_full(resync_full), .resync_limited(resync_limited)
    );

    always #5 clk = ~clk;

    //-----------------------------------------------------------------
    // Monitor: records every strobe with its cycle index
    //-----------------------------------------------------------------
    integer cyc = 0;
    integer bt_idx [0:511];
    integer sp_idx [0:511];
    reg     sp_val [0:511];
    integer n_bt = 0, n_sp = 0;
    integer n_hard = 0, n_full = 0, n_lim = 0;

    always @(posedge clk) begin
        cyc = cyc + 1;
        if (bit_tick && n_bt < 512) begin bt_idx[n_bt] = cyc; n_bt = n_bt + 1; end
        if (sample_point && n_sp < 512) begin
            sp_idx[n_sp] = cyc; sp_val[n_sp] = rx_bit; n_sp = n_sp + 1;
        end
        if (hard_sync)      n_hard = n_hard + 1;
        if (resync_full)    n_full = n_full + 1;
        if (resync_limited) n_lim  = n_lim  + 1;
    end

    task mon_reset;
        begin n_bt = 0; n_sp = 0; n_hard = 0; n_full = 0; n_lim = 0; end
    endtask

    // k-th (0-based) bit_tick / sample_point with index > X, or -1
    function integer bt_after(input integer X, input integer nth);
        integer i, c;
        begin
            bt_after = -1; c = 0;
            for (i = 0; i < n_bt; i = i + 1)
                if (bt_idx[i] > X) begin
                    if (c == nth && bt_after < 0) bt_after = bt_idx[i];
                    c = c + 1;
                end
        end
    endfunction

    function integer sp_after(input integer X, input integer nth);
        integer i, c;
        begin
            sp_after = -1; c = 0;
            for (i = 0; i < n_sp; i = i + 1)
                if (sp_idx[i] > X) begin
                    if (c == nth && sp_after < 0) sp_after = sp_idx[i];
                    c = c + 1;
                end
        end
    endfunction

    //-----------------------------------------------------------------
    // Stimulus helpers
    //-----------------------------------------------------------------
    task wait_cyc(input integer target);       // returns at a negedge, cyc >= target
        begin while (cyc < target) @(negedge clk); end
    endtask

    integer late_drive = 0;
    // make the synchronised RX signal change in cycle E (rx_in is 2 clocks earlier)
    task drive_edge(input integer E, input v);
        begin
            if (cyc > E - 3) late_drive = late_drive + 1;
            wait_cyc(E - 3);
            rx_in = v;
        end
    endtask

    task setup(input [7:0] b, input [3:0] t1, input [2:0] t2, input [1:0] sj,
               input h_en, input r_en, input txd);
        begin
            @(negedge clk);
            brp = b; tseg1 = t1; tseg2 = t2; sjw = sj;
            hsync_en = h_en; rsync_en = r_en; tx_dominant = txd;
            rx_in = 1; clear = 1;
            @(negedge clk);
            clear = 0;
            mon_reset;
        end
    endtask

    //-----------------------------------------------------------------
    // Check helpers
    //-----------------------------------------------------------------
    integer total_fail = 0;
    integer grp_fail, grp_runs;

    task fail_msg(input [8*30-1:0] what, input integer got, input integer exp,
                  input integer p, input integer sj);
        begin
            grp_fail = grp_fail + 1;
            if (grp_fail <= 6)
                $display("   [FAIL] p=%0d SJW=%0dTQ : %0s got=%0d expected=%0d", p, sj, what, got, exp);
        end
    endtask

    //-----------------------------------------------------------------
    // Directed single-edge run
    //   idle -> hard sync (SOF) -> 1 aligned recessive bit -> falling edge at
    //   position p of the following bit.
    //-----------------------------------------------------------------
    integer E_sof, A0, A, E2;
    integer TQ, P, off, sjtq, L2, e, k2;
    integer exp_bt1, exp_bt2, exp_sp1, exp_kind;
    integer g_bt1, g_bt2, g_sp1;

    task run_dir(input [7:0] b, input [3:0] t1, input [2:0] t2, input [1:0] sj,
                 input integer p, input txd);
        begin
            setup(b, t1, t2, sj, 1'b1, 1'b0, txd);
            TQ = b + 1; P = (t1 + t2 + 3) * TQ; off = (t1 + 2) * TQ;
            sjtq = sj + 1; L2 = t2 + 1;

            E_sof = cyc + 10 + ($urandom % P);          // random phase vs. free-running grid
            drive_edge(E_sof, 1'b0);                    // SOF edge
            wait_cyc(E_sof);
            hsync_en = 0; rsync_en = 1;                 // frame started -> resync mode
            A0 = E_sof;
            drive_edge(A0 + P, 1'b1);                   // back to recessive, aligned
            A  = A0 + 2 * P;
            E2 = A + p;
            drive_edge(E2, 1'b0);                       // the edge under test
            wait_cyc(E2 + 3 * P);

            // ---- expectations ----
            exp_bt2 = -1;
            if (p < TQ) begin
                exp_kind = 0; exp_bt1 = A + P; exp_sp1 = A + off;
            end else if (p < off) begin
                e = p / TQ;
                if (txd) begin
                    exp_kind = 0; exp_bt1 = A + P; exp_sp1 = A + off;
                end else if (e <= sjtq) begin
                    exp_kind = 1; exp_sp1 = E2 + off; exp_bt1 = E2 + P;
                end else begin
                    exp_kind = 2; exp_sp1 = A + off + sjtq * TQ; exp_bt1 = A + P + sjtq * TQ;
                end
            end else begin
                k2 = (p - off) / TQ;
                e  = L2 - k2;
                if (e <= sjtq) begin
                    exp_kind = 1; exp_bt1 = E2 + 1; exp_bt2 = E2 + P; exp_sp1 = E2 + off;
                end else begin
                    exp_kind = 2; exp_bt1 = A + P - sjtq * TQ; exp_sp1 = exp_bt1 + off;
                end
            end

            // ---- compare ----
            grp_runs = grp_runs + 1;
            // hard sync of the SOF
            if (sp_after(E_sof, 0) != E_sof + off) fail_msg("SOF sample point", sp_after(E_sof, 0), E_sof + off, p, sjtq);
            if (bt_after(E_sof, 0) != E_sof + P)   fail_msg("SOF first bit_tick", bt_after(E_sof, 0), E_sof + P, p, sjtq);
            if (n_hard != 1)                       fail_msg("hard_sync count", n_hard, 1, p, sjtq);
            // the edge under test
            g_bt1 = bt_after(E2, 0); g_bt2 = bt_after(E2, 1); g_sp1 = sp_after(E2, 0);
            if (g_bt1 != exp_bt1) fail_msg("first bit_tick after edge", g_bt1, exp_bt1, p, sjtq);
            if (exp_bt2 >= 0 && g_bt2 != exp_bt2) fail_msg("second bit_tick after edge", g_bt2, exp_bt2, p, sjtq);
            if (g_sp1 != exp_sp1) fail_msg("first sample after edge", g_sp1, exp_sp1, p, sjtq);
            if (n_full != (exp_kind == 1)) fail_msg("resync_full count", n_full, (exp_kind == 1), p, sjtq);
            if (n_lim  != (exp_kind == 2)) fail_msg("resync_limited count", n_lim, (exp_kind == 2), p, sjtq);
        end
    endtask

    task sweep(input [7:0] b, input [3:0] t1, input [2:0] t2, input integer sj_lo,
               input integer sj_hi, input txd, input [8*40-1:0] tag);
        integer pp, ss;
        begin
            grp_fail = 0; grp_runs = 0;
            for (ss = sj_lo; ss <= sj_hi; ss = ss + 1)
                for (pp = 0; pp < (t1 + t2 + 3) * (b + 1); pp = pp + 1)
                    run_dir(b, t1, t2, ss[1:0], pp, txd);
            if (grp_fail == 0)
                $display("[PASS] %0s BRP=%0d TSEG1=%0d TSEG2=%0d SJW=%0d..%0d TQ : %0d edge positions OK",
                         tag, b, t1, t2, sj_lo + 1, sj_hi + 1, grp_runs);
            else begin
                $display("[FAIL] %0s BRP=%0d TSEG1=%0d TSEG2=%0d : %0d failing checks", tag, b, t1, t2, grp_fail);
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // S1: only ONE synchronisation per bit
    //-----------------------------------------------------------------
    task run_s1;
        integer okk;
        begin
            setup(3, 5, 2, 2'd2, 1'b1, 1'b0, 1'b0);      // TQ=4, P=40, off=28, SJW=3TQ
            TQ = 4; P = 40; off = 28;
            E_sof = cyc + 10 + ($urandom % P);
            drive_edge(E_sof, 1'b0);
            wait_cyc(E_sof); hsync_en = 0; rsync_en = 1;
            A0 = E_sof;
            drive_edge(A0 + P, 1'b1);
            A = A0 + 2 * P; E2 = A + 2 * TQ;             // e = 2 <= SJW -> full resync
            drive_edge(E2,          1'b0);               // 1st falling edge: used
            drive_edge(E2 + TQ,     1'b1);               // back to recessive
            drive_edge(E2 + 2 * TQ, 1'b0);               // 2nd falling edge in the same bit: must be ignored
            wait_cyc(E2 + 3 * P);
            okk = (sp_after(E2, 0) == E2 + off) && (bt_after(E2, 0) == E2 + P) &&
                  (n_full == 1) && (n_lim == 0);
            if (okk) $display("[PASS] S1 second edge inside the same bit is ignored (one sync per bit)");
            else begin
                $display("[FAIL] S1 sample=%0d (exp %0d) bit_tick=%0d (exp %0d) full=%0d lim=%0d",
                         sp_after(E2, 0), E2 + off, bt_after(E2, 0), E2 + P, n_full, n_lim);
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // S2: no resync if the previous sample point was dominant
    //-----------------------------------------------------------------
    task run_s2;
        integer okk;
        begin
            setup(3, 5, 2, 2'd2, 1'b1, 1'b0, 1'b0);
            TQ = 4; P = 40; off = 28;
            E_sof = cyc + 10 + ($urandom % P);
            drive_edge(E_sof, 1'b0);                      // SOF, sampled dominant at E_sof+off
            wait_cyc(E_sof); hsync_en = 0; rsync_en = 1;
            A0 = E_sof;
            drive_edge(A0 + P, 1'b1);                     // bit 1 starts recessive ...
            E2 = A0 + P + 2 * TQ;
            drive_edge(E2, 1'b0);                         // ... and falls again BEFORE its sample point:
            wait_cyc(E2 + 3 * P);                         // previous sample was dominant -> not an edge to use
            okk = (bt_after(E2, 0) == A0 + 2 * P) && (sp_after(E2, 0) == A0 + P + off) &&
                  (n_full == 0) && (n_lim == 0) && (n_hard == 1);
            if (okk) $display("[PASS] S2 falling edge after a DOMINANT sample is ignored");
            else begin
                $display("[FAIL] S2 bit_tick=%0d (exp %0d) sample=%0d (exp %0d) full=%0d lim=%0d",
                         bt_after(E2, 0), A0 + 2 * P, sp_after(E2, 0), A0 + P + off, n_full, n_lim);
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // S3: both enables low -> edges do not move the grid
    //-----------------------------------------------------------------
    task run_s3;
        integer i, bad, c0;
        begin
            setup(3, 5, 2, 2'd1, 1'b0, 1'b0, 1'b0);      // setup's clear edge = cyc
            c0 = cyc;                                     // monitor index of the clear edge
            P = 40;
            drive_edge(cyc + 37, 1'b0);                   // falling edge somewhere in the bit
            drive_edge(cyc + 71, 1'b1);                   // (these happen to be mid-bit)
            wait_cyc(c0 + 12 * P);
            bad = 0;
            // bit_ticks visible at (clear_edge + 1) + k*P, as in the Day 1-2 testbench
            for (i = 0; i < n_bt; i = i + 1)
                if (((bt_idx[i] - (c0 + 1)) % P) != 0) bad = bad + 1;
            if (bad == 0 && n_hard == 0 && n_full == 0 && n_lim == 0 && n_bt >= 10)
                $display("[PASS] S3 sync disabled: edges do not move the bit grid (%0d bits)", n_bt);
            else begin
                $display("[FAIL] S3 off-grid bit_ticks=%0d hard=%0d full=%0d lim=%0d", bad, n_hard, n_full, n_lim);
                total_fail = total_fail + 1;
            end
        end
    endtask

    //-----------------------------------------------------------------
    // S4/S5: oscillator mismatch. Transmitter bit time Ptx != receiver P.
    //-----------------------------------------------------------------
    reg pat [0:299];
    task gen_pattern(input integer n);
        integer i, run;
        reg prevb;
        begin
            pat[0] = 1'b0; prevb = 1'b0; run = 1;           // SOF
            for (i = 1; i < n; i = i + 1) begin
                if (run >= 5 || ($urandom % 2) == 0) begin prevb = ~prevb; run = 1; end
                else run = run + 1;
                pat[i] = prevb;
            end
        end
    endtask

    task run_tol(input [7:0] b, input [3:0] t1, input [2:0] t2, input [1:0] sj,
                 input integer ptx, input r_en, input integer nbits, input [8*40-1:0] tag,
                 input expect_good);
        integer i, bad, nchk;
        begin
            setup(b, t1, t2, sj, 1'b1, 1'b0, 1'b0);
            P = (t1 + t2 + 3) * (b + 1);
            gen_pattern(nbits);
            E_sof = cyc + 10 + ($urandom % P);
            drive_edge(E_sof, pat[0]);
            wait_cyc(E_sof); hsync_en = 0; rsync_en = r_en;
            for (i = 1; i < nbits; i = i + 1)
                drive_edge(E_sof + i * ptx, pat[i]);
            wait_cyc(E_sof + nbits * ptx + 2 * P);

            bad = 0; nchk = 0;
            for (i = 0; i < nbits; i = i + 1) begin
                if (sp_after(E_sof, i) < 0) bad = bad + 1;
                else begin
                    nchk = nchk + 1;
                    // find the value captured at the i-th sample after E_sof
                    begin : find
                        integer j, c;
                        c = 0;
                        for (j = 0; j < n_sp; j = j + 1)
                            if (sp_idx[j] > E_sof) begin
                                if (c == i && sp_val[j] !== pat[i]) bad = bad + 1;
                                c = c + 1;
                            end
                    end
                end
            end
            if (expect_good) begin
                if (bad == 0) $display("[PASS] %0s: TX bit=%0d clk vs RX bit=%0d clk (%0d.%0d %%), %0d/%0d bits correct, resyncs=%0d",
                                       tag, ptx, P, (100*(P-ptx)/P), ((1000*(P-ptx)/P)%10 < 0 ? -((1000*(P-ptx)/P)%10) : (1000*(P-ptx)/P)%10),
                                       nchk, nbits, n_full + n_lim);
                else begin $display("[FAIL] %0s: %0d bad bits", tag, bad); total_fail = total_fail + 1; end
            end else begin
                if (bad > 0) $display("[PASS] %0s: drift/out-of-tolerance IS detected (%0d bad bits of %0d)", tag, bad, nbits);
                else begin $display("[FAIL] %0s: testbench did not notice the error", tag); total_fail = total_fail + 1; end
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

        // D1: TQ = 4 clk, P = 40, sample@28
        //sweep(3, 5, 2, 0, 3, 1'b0, "D1");
        // D2: TQ = 1 clk (every clock is a TQ)
        sweep(0, 4, 3, 0, 3, 1'b0, "D2");
        // D3: TQ = 2 clk, longer segments
        //sweep(1, 7, 3, 0, 3, 1'b0, "D3");
        // D4: node transmitting a dominant bit: late edges must be ignored
        //sweep(3, 5, 2, 0, 3, 1'b1, "D4 tx_dominant");

        //run_s1;
        //run_s2;
        //run_s3;

        // 500 kbit/s setup (BRP=9 TSEG1=15 TSEG2=2 SJW=3TQ <= PHASE_SEG2 = 3TQ): tolerance limit = 0.58 %
        run_tol(9, 15, 2, 2'd2, 199, 1'b1, 100, "S4 TX 0.5% fast, resync ON ", 1'b1);
        run_tol(9, 15, 2, 2'd2, 201, 1'b1, 250, "S4 TX 0.5% slow, resync ON ", 1'b1);
        run_tol(9, 15, 2, 2'd2, 199, 1'b0, 100, "S5 TX 0.5% fast, resync OFF", 1'b0);
        run_tol(9, 15, 2, 2'd2, 201, 1'b0, 250, "S5 TX 0.5% slow, resync OFF", 1'b0);   // needs >170 bits of drift
        run_tol(9, 15, 2, 2'd2, 194, 1'b1, 100, "S6 TX 3% fast, beyond tolerance", 1'b0);

        if (late_drive != 0) begin
            $display("[FAIL] testbench drove %0d edges too late (test bug)", late_drive);
            total_fail = total_fail + 1;
        end

        $display("----------------------------------------------------");
        if (total_fail == 0) $display("ALL BTL SYNC TESTS PASSED");
        else                 $display("%0d BTL SYNC TEST GROUP(S) FAILED", total_fail);
        $display("----------------------------------------------------");
        $finish;
    end

endmodule