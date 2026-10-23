//=============================================================================
// Testbench   : tb_can_acceptance_filter
// Description : Self-checking testbench for can_acceptance_filter.
//               Covers all functionally distinct filter behaviours using only
//               11-bit standard-frame identifiers (CAN 2.0A).
//
// Tests:
//   T1  - Exact match  (mask = 11'h7FF, ID matches)              -> accept
//   T2  - Exact match  (mask = 11'h7FF, ID differs by 1)         -> reject
//   T3  - Promiscuous  (mask = 11'h000, any ID)                  -> accept
//   T4  - Don't-care on LSB (mask = 11'h7FE, IDs +-1)           -> accept
//   T5  - Don't-care on MSB (mask = 11'h3FF, MSB 0/1)           -> accept
//   T6  - Half-mask (mask = 11'h7F0, upper 7 bits match)         -> accept
//   T7  - Half-mask (mask = 11'h7F0, upper 7 bits differ)        -> reject
//   T8  - All-zero mask, extremes (0x000 and 0x7FF)              -> accept
//   T9  - Zero filter_id, zero mask                              -> accept
//   T10 - Exhaustive: all 2048 IDs vs fixed filter, count check
//
// XSim note: All local variables are declared at the top of each named
// begin/end block. XSim does not support declarations inside unnamed
// sub-blocks or inside for-loop bodies.
//=============================================================================

`timescale 1ns/1ps

module tb_can_acceptance_filter;

    // -------------------------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------------------------
    logic [10:0] rx_id;
    logic [10:0] filter_id;
    logic [10:0] filter_mask;
    logic        accept;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    can_acceptance_filter dut (
        .rx_id      (rx_id),
        .filter_id  (filter_id),
        .filter_mask(filter_mask),
        .accept     (accept)
    );

    // -------------------------------------------------------------------------
    // Test counters (module-level so tasks can access them)
    // -------------------------------------------------------------------------
    int tests  = 0;
    int errors = 0;

    // -------------------------------------------------------------------------
    // Reference model
    // -------------------------------------------------------------------------
    function automatic logic ref_accept(
        input logic [10:0] id,
        input logic [10:0] fid,
        input logic [10:0] fmask
    );
        ref_accept = ( (id ^ fid) & fmask ) == 11'h000;
    endfunction

    // -------------------------------------------------------------------------
    // Check helper task
    // -------------------------------------------------------------------------
    task automatic check(
        input string       label,
        input logic [10:0] id,
        input logic [10:0] fid,
        input logic [10:0] fmask,
        input logic        expected
    );
        rx_id       = id;
        filter_id   = fid;
        filter_mask = fmask;
        #1;

        tests++;
        if (accept !== expected) begin
            $display("[FAIL] %-50s rx_id=0x%03h fid=0x%03h fmask=0x%03h  expected=%b got=%b",
                     label, id, fid, fmask, expected, accept);
            errors++;
        end else begin
            $display("[PASS] %-50s rx_id=0x%03h fid=0x%03h fmask=0x%03h  accept=%b",
                     label, id, fid, fmask, accept);
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin : STIMULUS

        // All locals at the top of this named block (XSim requirement).
        logic [10:0] fid_ex;
        logic [10:0] fmsk_ex;
        logic [10:0] id_i;
        int          i;
        int          pass_cnt;
        int          fail_cnt;
        int          exp_pass;

        rx_id       = 11'h000;
        filter_id   = 11'h000;
        filter_mask = 11'h000;
        #5;

        // ------------------------------------------------------------------
        // T1 -- Exact match: mask all bits, ID matches exactly
        // ------------------------------------------------------------------
        check("T1  exact match  accept",
              11'h2A5, 11'h2A5, 11'h7FF, 1'b1);

        // ------------------------------------------------------------------
        // T2 -- Exact match: mask all bits, ID differs in bit 0
        // ------------------------------------------------------------------
        check("T2  exact match  reject (bit 0 differs)",
              11'h2A4, 11'h2A5, 11'h7FF, 1'b0);

        // ------------------------------------------------------------------
        // T3 -- Promiscuous: mask = 0 -> accept any ID
        // ------------------------------------------------------------------
        check("T3  promiscuous  accept (mask=0 ID=0x000)",
              11'h000, 11'h7FF, 11'h000, 1'b1);
        check("T3  promiscuous  accept (mask=0 ID=0x7FF)",
              11'h7FF, 11'h000, 11'h000, 1'b1);
        check("T3  promiscuous  accept (mask=0 ID=0x123)",
              11'h123, 11'h456, 11'h000, 1'b1);

        // ------------------------------------------------------------------
        // T4 -- Don't-care on bit 0: IDs that differ only in LSB both pass
        // ------------------------------------------------------------------
        check("T4  don't-care LSB  accept (ID even)",
              11'h3C0, 11'h3C0, 11'h7FE, 1'b1);
        check("T4  don't-care LSB  accept (ID odd)",
              11'h3C1, 11'h3C0, 11'h7FE, 1'b1);
        check("T4  don't-care LSB  reject (upper bits differ)",
              11'h3D0, 11'h3C0, 11'h7FE, 1'b0);

        // ------------------------------------------------------------------
        // T5 -- Don't-care on MSB (bit 10): both polarities accepted
        // ------------------------------------------------------------------
        check("T5  don't-care MSB  accept (MSB=0)",
              11'h055, 11'h055, 11'h3FF, 1'b1);
        check("T5  don't-care MSB  accept (MSB=1)",
              11'h455, 11'h055, 11'h3FF, 1'b1);
        check("T5  don't-care MSB  reject (lower bits differ)",
              11'h454, 11'h055, 11'h3FF, 1'b0);

        // ------------------------------------------------------------------
        // T6/T7 -- Half-mask: upper 7 bits masked (bits 10..4), lower 4 free
        // mask = 11'h7F0 = 0b111_1111_0000
        // ------------------------------------------------------------------
        check("T6  half-mask  accept (upper match, lower differ)",
              11'h5A3, 11'h5A0, 11'h7F0, 1'b1);
        check("T6  half-mask  accept (upper match, lower differ 2)",
              11'h5AF, 11'h5A0, 11'h7F0, 1'b1);
        check("T7  half-mask  reject (upper differ by 1)",
              11'h5B0, 11'h5A0, 11'h7F0, 1'b0);
        check("T7  half-mask  reject (completely different)",
              11'h000, 11'h7FF, 11'h7F0, 1'b0);

        // ------------------------------------------------------------------
        // T8 -- All-zero mask with extreme IDs
        // ------------------------------------------------------------------
        check("T8  zero mask  accept (ID=0x000)",
              11'h000, 11'h000, 11'h000, 1'b1);
        check("T8  zero mask  accept (ID=0x7FF vs fid=0x000)",
              11'h7FF, 11'h000, 11'h000, 1'b1);
        check("T8  zero mask  accept (ID=0x000 vs fid=0x7FF)",
              11'h000, 11'h7FF, 11'h000, 1'b1);

        // ------------------------------------------------------------------
        // T9 -- Zero filter_id + zero mask
        // ------------------------------------------------------------------
        check("T9  zero filter_id+mask  accept (any ID)",
              11'h1AA, 11'h000, 11'h000, 1'b1);

        // ------------------------------------------------------------------
        // T10 -- Exhaustive: sweep all 2048 IDs through a fixed filter.
        //        filter_id   = 11'h1A3  (bits [10:4] = 7'h0D)
        //        filter_mask = 11'h7F0  (bits 10..4 must match, bits 3..0 free)
        //        Expected accepts: 2^4 = 16 IDs (lower nibble is don't-care).
        // ------------------------------------------------------------------
        fid_ex   = 11'h1A3;
        fmsk_ex  = 11'h7F0;
        pass_cnt = 0;
        fail_cnt = 0;
        exp_pass = 0;

        for (i = 0; i < 2048; i++) begin
            id_i        = i[10:0];
            rx_id       = id_i;
            filter_id   = fid_ex;
            filter_mask = fmsk_ex;
            #1;

            if (ref_accept(id_i, fid_ex, fmsk_ex)) begin
                exp_pass++;
                if (accept !== 1'b1) begin
                    errors++;
                    $display("[FAIL] T10 exhaustive: rx_id=0x%03h should ACCEPT", id_i);
                end else begin
                    pass_cnt++;
                end
            end else begin
                if (accept !== 1'b0) begin
                    errors++;
                    $display("[FAIL] T10 exhaustive: rx_id=0x%03h should REJECT", id_i);
                end else begin
                    fail_cnt++;
                end
            end
        end

        tests++;
        // 7-bit upper prefix fixed, 4-bit lower free -> 16 expected accepts.
        if (exp_pass == 16 && errors == 0)
            $display("[PASS] T10 exhaustive sweep  pass=%0d reject=%0d (expected 16 accepts)",
                     pass_cnt, fail_cnt);
        else if (errors > 0)
            $display("[FAIL] T10 exhaustive errors detected");
        else begin
            $display("[FAIL] T10 exhaustive: unexpected pass count=%0d (expected 16)", exp_pass);
            errors++;
        end

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("----------------------------------------------------");
        if (errors == 0)
            $display("ALL %0d ACCEPTANCE FILTER TESTS PASSED", tests);
        else
            $display("%0d / %0d ACCEPTANCE FILTER TESTS FAILED", errors, tests);
        $display("----------------------------------------------------");

        $finish;
    end

endmodule
