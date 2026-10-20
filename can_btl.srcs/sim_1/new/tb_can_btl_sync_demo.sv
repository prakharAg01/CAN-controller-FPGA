//=============================================================================
// tb_can_btl_sync_demo  --  a SHORT scenario for looking at the waveform
//
// Config : BRP=3 (TQ = 4 clk = 40 ns), TSEG1=5 (6 TQ), TSEG2=2 (3 TQ), SJW=1 (2 TQ)
//          bit = 40 clk = 400 ns, sample point 28 clk = 280 ns after bit start
//          clock = 10 ns, so 1 clk = 10 ns
//
// Scenario (cycle numbers = clock index, 1 clk = 10 ns):
//   1) Idle, free-running. rx_in falls at cycle 100 -> HARD SYNC.
//        the synchronised edge is seen in cycle 102 (2-clock synchroniser)
//        => new bit starts in cycle 102, sample point at 102+28 = 130,
//           next bit_tick at 102+40 = 142
//   2) rx_in rises aligned (cycle 142), stays recessive for bit 1.
//   3) LATE edge: falls 16 clk after the start of bit 2 (bit 2 starts at 182)
//        => edge at cycle 198, phase error e = 16/4 = 4 TQ > SJW (2 TQ)
//        => LIMITED resync: TSEG1 lengthened by 2 TQ = 8 clk
//           sample point 182+28+8 = 218 (not 210), next bit_tick 182+40+8 = 230 (not 222)
//   4) rx_in rises again (aligned to the new grid, cycle 230), stays recessive.
//   5) EARLY edge: bit 4 starts at 270 (=230+40); edge falls 36 clk into the bit
//        => cycle 306, in TSEG2, e = -(3-2) = -1 TQ, |e| <= SJW
//        => FULL resync: bit ends at the edge: bit_tick at 307, new bit starts at 306,
//           sample point 306+28 = 334, next bit_tick 306+40 = 346
//=============================================================================
`timescale 1ns/1ps

module tb_can_btl_sync_demo;

    logic clk = 0, rst_n = 0, clear = 0;
    logic hsync_en = 0, rsync_en = 0, rx_in = 1;
    wire  tq_tick, bit_tick, sample_point, rx_bit, hard_sync, resync_full, resync_limited;
    wire  [1:0] seg_state;

    can_btl dut (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .brp(8'd3), .tseg1(4'd5), .tseg2(3'd2), .sjw(2'd1),
        .hsync_en(hsync_en), .rsync_en(rsync_en), .tx_dominant(1'b0),
        .rx_in(rx_in),
        .tq_tick(tq_tick), .bit_tick(bit_tick), .sample_point(sample_point),
        .rx_bit(rx_bit), .seg_state(seg_state),
        .hard_sync(hard_sync), .resync_full(resync_full), .resync_limited(resync_limited)
    );

    always #5 clk = ~clk;

    // ---- event log: cycle index (monitor convention) and time ----
    integer cyc = 0;
    integer errors = 0;
    integer bt_log [0:63]; integer nb = 0;
    integer sp_log [0:63]; integer ns = 0;
    always @(posedge clk) begin
        cyc = cyc + 1;
        if (bit_tick)     begin bt_log[nb] = cyc; nb = nb + 1; end
        if (sample_point) begin sp_log[ns] = cyc; ns = ns + 1; end
        if (hard_sync)      $display("  cycle %0d (%0d ns): hard_sync",       cyc, $time);
        if (resync_full)    $display("  cycle %0d (%0d ns): resync_full",     cyc, $time);
        if (resync_limited) $display("  cycle %0d (%0d ns): resync_limited",  cyc, $time);
        if (bit_tick)       $display("  cycle %0d (%0d ns): bit_tick",        cyc, $time);
        if (sample_point)   $display("  cycle %0d (%0d ns): sample_point  (rx_bit = %0b)", cyc, $time, rx_bit);
    end

    task wait_cyc(input integer target);
        begin while (cyc < target) @(negedge clk); end
    endtask
    task drive_edge(input integer E, input v);   // synchronised edge seen in cycle E
        begin wait_cyc(E - 3); rx_in = v; end
    endtask

    // record the first event of a kind after cycle X
    integer first_bt, first_sp;
    task expect_event(input [8*20-1:0] what, input integer got, input integer exp);
        begin
            if (got === exp) $display("  [OK]   %0s at cycle %0d (expected %0d)", what, got, exp);
            else begin $display("  [FAIL] %0s at cycle %0d, expected %0d", what, got, exp); errors = errors + 1; end
        end
    endtask

    function integer bt_gt(input integer X);   // first bit_tick with cycle > X
        integer i;
        begin bt_gt = -1; for (i = nb-1; i >= 0; i = i - 1) if (bt_log[i] > X) bt_gt = bt_log[i]; end
    endfunction
    function integer sp_gt(input integer X);
        integer i;
        begin sp_gt = -1; for (i = ns-1; i >= 0; i = i - 1) if (sp_log[i] > X) sp_gt = sp_log[i]; end
    endfunction

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;
        hsync_en = 1; rsync_en = 0;                 // idle: hard sync allowed
        $display("--- 1) idle, free running; rx_in falls so that the edge is seen in cycle 102 ---");
        drive_edge(102, 1'b0);
        wait_cyc(102); hsync_en = 0; rsync_en = 1;  // frame started -> resync mode
        drive_edge(142, 1'b1);                      // bit 1: recessive, aligned
        $display("--- 3) LATE edge, 16 clk into bit 2 (cycle 198) ---");
        drive_edge(198, 1'b0);
        drive_edge(230, 1'b1);                      // back to recessive, aligned to the NEW grid
        $display("--- 5) EARLY edge, 36 clk into bit 4 (cycle 306) ---");
        drive_edge(306, 1'b0);
        wait_cyc(420);

        $display("--- summary ---");
        expect_event("hard-sync sample", sp_gt(102),  130);
        expect_event("hard-sync bit   ", bt_gt(102),  142);
        expect_event("late-edge sample", sp_gt(198),  218);
        expect_event("late-edge bit   ", bt_gt(198),  230);
        expect_event("early-edge bit  ", bt_gt(306),  307);
        expect_event("early-edge sample", sp_gt(306), 334);
        if (errors == 0) $display("DEMO OK: every event is exactly where the hand calculation says");
        else             $display("DEMO MISMATCH: %0d", errors);
        $finish;
    end
endmodule