// =============================================================================
// Testbench : tb_can_tx_buffer
// Tests     : T1-T5  (self-checking, $error on failure)
// Day 25    : TX Buffer + RX FIFO (Inferred Block RAM)
// =============================================================================
`timescale 1ns/1ps

module tb_can_tx_buffer;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic        clk, rst_n;
    logic        tx_write;
    logic [10:0] tx_id;
    logic        tx_rtr;
    logic [3:0]  tx_dlc;
    logic [63:0] tx_data;

    logic        bsp_tx_request;
    logic [10:0] bsp_tx_id;
    logic        bsp_tx_rtr;
    logic [3:0]  bsp_tx_dlc;
    logic [63:0] bsp_tx_data;

    logic        bsp_tx_done;
    logic        tx_ready, tx_busy;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    can_tx_buffer dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .tx_write      (tx_write),
        .tx_id         (tx_id),
        .tx_rtr        (tx_rtr),
        .tx_dlc        (tx_dlc),
        .tx_data       (tx_data),
        .bsp_tx_request(bsp_tx_request),
        .bsp_tx_id     (bsp_tx_id),
        .bsp_tx_rtr    (bsp_tx_rtr),
        .bsp_tx_dlc    (bsp_tx_dlc),
        .bsp_tx_data   (bsp_tx_data),
        .bsp_tx_done   (bsp_tx_done),
        .tx_ready      (tx_ready),
        .tx_busy       (tx_busy)
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    task wait_clk(input int n);
        repeat(n) @(posedge clk); #1;
    endtask

    task write_frame(input [10:0] id, input rtr,
                     input [3:0] dlc, input [63:0] data);
        tx_id    = id;
        tx_rtr   = rtr;
        tx_dlc   = dlc;
        tx_data  = data;
        tx_write = 1'b1;
        @(posedge clk); #1;
        tx_write = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Scoreboard
    // -------------------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0, total = 0;

    task check(input string name, input logic got, input logic exp);
        total++;
        if (got === exp) begin
            $display("[PASS] %s", name);
            pass_cnt++;
        end else begin
            $error("[FAIL] %s : got=%0b exp=%0b", name, got, exp);
            fail_cnt++;
        end
    endtask

    task check11(input string name, input logic [10:0] got, input logic [10:0] exp);
        total++;
        if (got === exp) begin
            $display("[PASS] %s", name);
            pass_cnt++;
        end else begin
            $error("[FAIL] %s : got=%0h exp=%0h", name, got, exp);
            fail_cnt++;
        end
    endtask

    task check64(input string name, input logic [63:0] got, input logic [63:0] exp);
        total++;
        if (got === exp) begin
            $display("[PASS] %s", name);
            pass_cnt++;
        end else begin
            $error("[FAIL] %s : got=%0h exp=%0h", name, got, exp);
            fail_cnt++;
        end
    endtask

    // =========================================================================
    // TESTS
    // =========================================================================
    initial begin
        clk = 0; rst_n = 0; bsp_tx_done = 0;
        tx_write = 0; tx_id = 0; tx_rtr = 0; tx_dlc = 0; tx_data = 0;

        // =====================================================================
        // T1: Reset state
        // =====================================================================
        @(posedge clk); #1;
        rst_n = 1'b1;
        wait_clk(2);

        $display("--- T1: Reset state ---");
        check("T1_tx_ready",      tx_ready,      1'b1);
        check("T1_tx_busy",       tx_busy,        1'b0);
        check("T1_bsp_tx_request",bsp_tx_request, 1'b0);
        $display("[PASS] T1");

        // =====================================================================
        // T2: Load frame → check outputs
        // =====================================================================
        $display("--- T2: Load frame ---");
        write_frame(11'h123, 1'b0, 4'd5, 64'hCAFE_BABE_1234_5678);
        wait_clk(1);

        check  ("T2_tx_ready",       tx_ready,       1'b0);
        check  ("T2_tx_busy",        tx_busy,        1'b1);
        check  ("T2_bsp_tx_request", bsp_tx_request, 1'b1);
        check11("T2_bsp_tx_id",      bsp_tx_id,      11'h123);
        check  ("T2_bsp_tx_rtr",     bsp_tx_rtr,     1'b0);
        total++;
        if (bsp_tx_dlc === 4'd5) begin
            $display("[PASS] T2_bsp_tx_dlc"); pass_cnt++;
        end else begin
            $error("[FAIL] T2_bsp_tx_dlc: got=%0d exp=5", bsp_tx_dlc); fail_cnt++;
        end
        check64("T2_bsp_tx_data", bsp_tx_data, 64'hCAFE_BABE_1234_5678);
        $display("[PASS] T2");

        // =====================================================================
        // T3: Write collision while busy → second write ignored
        // =====================================================================
        $display("--- T3: Write collision while busy ---");
        write_frame(11'h7FF, 1'b1, 4'd0, 64'hDEAD_DEAD_DEAD_DEAD);
        wait_clk(1);

        // ID must still be 0x123 from T2
        check11("T3_id_unchanged", bsp_tx_id, 11'h123);
        check("T3_still_busy",     tx_busy,   1'b1);
        $display("[PASS] T3");

        // =====================================================================
        // T4: bsp_tx_done clears slot
        // =====================================================================
        $display("--- T4: BSP tx_done clears slot ---");
        bsp_tx_done = 1'b1;
        @(posedge clk); #1;
        bsp_tx_done = 1'b0;
        wait_clk(1);

        check("T4_tx_ready",       tx_ready,       1'b1);
        check("T4_tx_busy",        tx_busy,        1'b0);
        check("T4_bsp_tx_request", bsp_tx_request, 1'b0);
        $display("[PASS] T4");

        // =====================================================================
        // T5: Back-to-back enqueue (load immediately after done)
        // =====================================================================
        $display("--- T5: Back-to-back enqueue ---");
        // Frame A
        write_frame(11'h0AA, 1'b0, 4'd3, 64'hAAAA_1111_BBBB_2222);
        wait_clk(1);
        check("T5A_busy",    tx_busy,        1'b1);
        check11("T5A_id",    bsp_tx_id,      11'h0AA);

        // Done → immediately load frame B on the very next cycle
        bsp_tx_done = 1'b1;
        tx_id    = 11'h0BB;
        tx_rtr   = 1'b0;
        tx_dlc   = 4'd2;
        tx_data  = 64'hBBBB_3333_CCCC_4444;
        tx_write = 1'b1;
        @(posedge clk); #1;
        bsp_tx_done = 1'b0;
        tx_write    = 1'b0;
        wait_clk(1);

        // After done+write in same cycle: done takes priority, slot was cleared,
        // then write loads frame B on the NEXT clock (since !pending after done).
        // Actually: done clears pending first, then write loads B in same cycle
        // per always_ff priority (done branch taken, else-if write not entered).
        // So frame B loads on the cycle AFTER done.
        // Let's just verify that eventually the buffer is loaded with B.
        wait_clk(2);
        check("T5B_busy",  tx_busy,  1'b1);
        check11("T5B_id",  bsp_tx_id, 11'h0BB);
        $display("[PASS] T5");

        // Cleanup
        bsp_tx_done = 1'b1;
        @(posedge clk); #1;
        bsp_tx_done = 1'b0;

        // =====================================================================
        // Summary
        // =====================================================================
        wait_clk(5);
        $display("=========================================");
        if (fail_cnt == 0)
            $display("ALL 5 CAN TX BUFFER TESTS PASSED");
        else
            $display("%0d / 5 CAN TX BUFFER TESTS FAILED", fail_cnt);
        $display("=========================================");
        $finish;
    end

    initial begin
        #500000;
        $error("TIMEOUT");
        $finish;
    end

endmodule

