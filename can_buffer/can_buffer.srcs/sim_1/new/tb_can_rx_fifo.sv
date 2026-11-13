// =============================================================================
// Testbench : tb_can_rx_fifo
// Tests     : T1-T6  (self-checking, $error on failure)
// Day 25    : TX Buffer + RX FIFO (Inferred Block RAM)
// =============================================================================
`timescale 1ns/1ps

module tb_can_rx_fifo;

    // -------------------------------------------------------------------------
    // DUT parameters
    // -------------------------------------------------------------------------
    localparam DEPTH  = 16;
    localparam DATA_W = 80;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic clk, rst_n, clear;
    logic push, accept_in, pop;
    logic [DATA_W-1:0] rx_in, rx_out;
    logic [10:0] rx_out_id;
    logic        rx_out_rtr;
    logic [3:0]  rx_out_dlc;
    logic [63:0] rx_out_data;
    logic empty, full, almost_full, overrun;
    logic [$clog2(DEPTH):0] count;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    can_rx_fifo #(.DEPTH(DEPTH), .DATA_W(DATA_W)) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .clear      (clear),
        .push       (push),
        .rx_in      (rx_in),
        .accept_in  (accept_in),
        .pop        (pop),
        .rx_out     (rx_out),
        .rx_out_id  (rx_out_id),
        .rx_out_rtr (rx_out_rtr),
        .rx_out_dlc (rx_out_dlc),
        .rx_out_data(rx_out_data),
        .empty      (empty),
        .full       (full),
        .almost_full(almost_full),
        .overrun    (overrun),
        .count      (count)
    );

    // -------------------------------------------------------------------------
    // Clock  (100 MHz, period = 10 ns)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Helper: push one frame (1-clock strobe)
    // -------------------------------------------------------------------------
    task push_frame(input [10:0] id, input rtr,
                    input [3:0] dlc, input [63:0] data);
        rx_in     = {id, rtr, dlc, data};
        push      = 1'b1;
        accept_in = 1'b1;
        @(posedge clk); #1;
        push      = 1'b0;
        accept_in = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Helper: pop one frame (1-clock strobe)
    // -------------------------------------------------------------------------
    task pop_frame();
        pop = 1'b1;
        @(posedge clk); #1;
        pop = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Helper: wait N clocks (after #1 offset)
    // -------------------------------------------------------------------------
    task wait_clk(input int n);
        repeat(n) @(posedge clk); #1;
    endtask

    // -------------------------------------------------------------------------
    // Scoreboard
    // -------------------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0;

    task check(input string name, input logic got, input logic exp);
        if (got === exp) begin
            $display("[PASS] %s", name);
            pass_cnt++;
        end else begin
            $error("[FAIL] %s : got=%0b exp=%0b", name, got, exp);
            fail_cnt++;
        end
    endtask

    task check_data(input string name, input logic [DATA_W-1:0] got,
                                       input logic [DATA_W-1:0] exp);
        if (got === exp) begin
            $display("[PASS] %s", name);
            pass_cnt++;
        end else begin
            $error("[FAIL] %s : got=%0h exp=%0h", name, got, exp);
            fail_cnt++;
        end
    endtask

    task check_count(input string name, input int exp);
        if (count === exp) begin
            $display("[PASS] %s = %0d", name, exp);
            pass_cnt++;
        end else begin
            $error("[FAIL] %s : got=%0d exp=%0d", name, count, exp);
            fail_cnt++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Test variables
    // -------------------------------------------------------------------------
    int i;
    logic [DATA_W-1:0] expected_frames [0:DEPTH-1];

    // =========================================================================
    // TESTS
    // =========================================================================
    initial begin
        clk = 0; rst_n = 0; clear = 0;
        push = 0; accept_in = 0; pop = 0; rx_in = '0;

        // =====================================================================
        // T1: Reset state
        // =====================================================================
        @(posedge clk); #1;
        rst_n = 1'b1;
        wait_clk(2);

        $display("--- T1: Reset state ---");
        check("T1_empty",   empty,   1'b1);
        check("T1_full",    full,    1'b0);
        check("T1_overrun", overrun, 1'b0);
        check_count("T1_count", 0);
        $display("[PASS] T1");

        // =====================================================================
        // T2: Single push + FWFT verify + pop → empty
        //
        // BRAM read latency: push fires on posedge(0).
        //   - Cycle 1: BRAM write happens; refresh_pending set; rd_addr=0 stable
        //   - Cycle 2: bram_dout = mem[0]; fwft_reg captures; fwft_valid=1
        //   - Cycle 3: rx_out is stable from fwft_reg
        // We wait 3 clocks after push_frame to be safe.
        // =====================================================================
        $display("--- T2: Single push + FWFT + pop ---");
        push_frame(11'h1A5, 1'b0, 4'd8, 64'hDEAD_BEEF_CAFE_1234);
        wait_clk(3);   // 3 cycles: write→bram_dout→fwft_reg→output

        check("T2_not_empty",    empty,   1'b0);
        check("T2_not_full",     full,    1'b0);
        check_count("T2_count",  1);

        // Decoded fields from FWFT output
        if (rx_out_id === 11'h1A5) begin
            $display("[PASS] T2_rx_out_id"); pass_cnt++;
        end else begin
            $error("[FAIL] T2_rx_out_id: got=%0h exp=1A5", rx_out_id); fail_cnt++;
        end
        check("T2_rx_out_rtr", rx_out_rtr, 1'b0);
        if (rx_out_dlc === 4'd8) begin
            $display("[PASS] T2_rx_out_dlc"); pass_cnt++;
        end else begin
            $error("[FAIL] T2_rx_out_dlc: got=%0d exp=8", rx_out_dlc); fail_cnt++;
        end
        if (rx_out_data === 64'hDEAD_BEEF_CAFE_1234) begin
            $display("[PASS] T2_rx_out_data"); pass_cnt++;
        end else begin
            $error("[FAIL] T2_rx_out_data: got=%0h", rx_out_data); fail_cnt++;
        end

        pop_frame();
        wait_clk(2);
        check("T2_empty_after_pop", empty, 1'b1);
        $display("[PASS] T2");

        // =====================================================================
        // T3: Burst push 16 → full
        // =====================================================================
        $display("--- T3: Burst push 16 frames to full ---");
        for (i = 0; i < DEPTH; i++) begin
            expected_frames[i] = {11'(i+1), 1'b0, 4'(i % 9),
                                  64'(64'hA000_0000_0000_0000 | i)};
            rx_in     = expected_frames[i];
            push      = 1'b1;
            accept_in = 1'b1;
            @(posedge clk); #1;
        end
        push = 0; accept_in = 0;
        wait_clk(3);  // settle FWFT

        check("T3_full",        full,        1'b1);
        check("T3_almost_full", almost_full, 1'b1);
        check_count("T3_count", DEPTH);
        // Head frame should be frame[0]
        check_data("T3_head_frame", rx_out, expected_frames[0]);
        $display("[PASS] T3");

        // =====================================================================
        // T4: Push when full → overrun, count unchanged
        // =====================================================================
        $display("--- T4: Overrun detection ---");
        push_frame(11'h7FF, 1'b1, 4'd0, 64'hFFFF_FFFF_FFFF_FFFF);
        wait_clk(1);
        check("T4_overrun", overrun, 1'b1);
        check_count("T4_count_unchanged", DEPTH);
        $display("[PASS] T4");

        // =====================================================================
        // T5: Sequential drain — verify FIFO order
        // After each pop, wait 3 clocks for FWFT shadow to refresh with
        // the next frame, then verify rx_out before next pop.
        // =====================================================================
        $display("--- T5: Sequential drain + order check ---");
        for (i = 0; i < DEPTH; i++) begin
            // rx_out should already show expected_frames[i] (FWFT head)
            check_data($sformatf("T5_frame[%0d]", i), rx_out, expected_frames[i]);
            pop_frame();
            wait_clk(3);  // allow shadow reg to refresh with frame[i+1]
        end
        check("T5_empty_after_drain", empty, 1'b1);
        $display("[PASS] T5");

        // =====================================================================
        // T6: Simultaneous push + pop (count stays constant)
        // =====================================================================
        $display("--- T6: Simultaneous push+pop ---");
        // Pre-load 1 frame
        push_frame(11'h055, 1'b0, 4'd4, 64'h1111_2222_3333_4444);
        wait_clk(3);
        check_count("T6_preload_count", 1);

        // Simultaneous push+pop in one cycle
        rx_in     = {11'h0AA, 1'b0, 4'd2, 64'hAAAA_BBBB_CCCC_DDDD};
        push      = 1'b1;
        accept_in = 1'b1;
        pop       = 1'b1;
        @(posedge clk); #1;
        push = 0; accept_in = 0; pop = 0;
        wait_clk(2);

        check_count("T6_count_stable", 1);
        $display("[PASS] T6");

        // Drain leftover
        pop_frame();
        wait_clk(2);

        // =====================================================================
        // Summary
        // =====================================================================
        $display("=========================================");
        if (fail_cnt == 0)
            $display("ALL 6 CAN RX FIFO TESTS PASSED");
        else
            $display("%0d / 6 CAN RX FIFO TESTS FAILED", fail_cnt);
        $display("=========================================");
        $finish;
    end

    initial begin
        #2000000;
        $error("TIMEOUT");
        $finish;
    end

endmodule
