//=============================================================================
// Testbench : tb_can_tx_shift
//
// Expected stream = plain bit sequence taken from the loaded data:
//     k-th bit out = load_data[WIDTH-1-k]    for k = 0 .. len-1
//
//  T1  every length 1..64, random data, three different shift_en patterns
//      (always / 1 in 3 / 1 in 8): bit order, remaining, last, done
//  T2  seamless reload in the SAME clock as the last bit (valid never drops)
//  T3  load while busy is rejected (and does not disturb the running field)
//  T4  load_len = 0 is rejected; load_len > WIDTH is clamped to WIDTH
//  T5  clear in the middle of a field aborts at once
//  T6  shift_en while empty produces nothing (no underflow)
//=============================================================================
`timescale 1ns/1ps

module tb_can_tx_shift;

    localparam int W  = 64;
    localparam int LW = $clog2(W + 1);

    logic          clk = 0, rst_n = 0, clear = 0, load = 0, shift_en = 0;
    logic [W-1:0]  load_data = 0;
    logic [LW-1:0] load_len  = 0;
    wire           valid, bit_out, last, xfer, done, load_rejected;
    wire  [LW-1:0] remaining;

    can_tx_shift #(.WIDTH(W)) dut (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .load(load), .load_data(load_data), .load_len(load_len),
        .shift_en(shift_en),
        .valid(valid), .bit_out(bit_out), .last(last), .xfer(xfer),
        .remaining(remaining), .done(done), .load_rejected(load_rejected)
    );

    always #5 clk = ~clk;

    //-----------------------------------------------------------------
    // Monitor
    //-----------------------------------------------------------------
    integer cyc = 0, n_got = 0, n_done = 0, n_rej = 0, v_low = 0;
    reg     burst_en = 0;
    integer burst_total = 0;      // gaps are only counted until this many bits were consumed
    reg     got       [0:1023];
    integer rem_seen  [0:1023];
    reg     last_seen [0:1023];

    always @(posedge clk) begin
        cyc = cyc + 1;
        if (xfer && n_got < 1024) begin
            got[n_got] = bit_out; rem_seen[n_got] = remaining; last_seen[n_got] = last;
            n_got = n_got + 1;
        end
        if (done)           n_done = n_done + 1;
        if (load_rejected)  n_rej  = n_rej + 1;
        if (burst_en && !valid && n_got < burst_total) v_low = v_low + 1;
    end

    task mon_reset;
        begin n_got = 0; n_done = 0; n_rej = 0; v_low = 0; end
    endtask

    //-----------------------------------------------------------------
    // Helpers
    //-----------------------------------------------------------------
    integer errors = 0;

    function [W-1:0] rnd64(input integer dummy);
        begin rnd64 = {$urandom, $urandom}; end
    endfunction

    task issue_load(input [W-1:0] d, input integer len);
        begin
            @(negedge clk); load = 1; load_data = d; load_len = len;
            @(negedge clk); load = 0;
        end
    endtask

    // drive shift_en until 'target' bits have been consumed in total
    task drain_to(input integer target, input integer mode);
        integer guard;
        begin
            guard = 0;
            while (n_got < target && guard < 200000) begin
                @(negedge clk);
                case (mode)
                    0: shift_en = 1;
                    1: shift_en = (($urandom % 3) == 0);
                    default: shift_en = (($urandom % 8) == 0);
                endcase
                guard = guard + 1;
            end
            @(negedge clk); shift_en = 0;
        end
    endtask

    // consume exactly n bits (shift_en high for exactly n clocks, valid must stay high)
    task consume(input integer n);
        begin
            @(negedge clk); shift_en = 1;
            repeat (n) @(negedge clk);
            shift_en = 0;
        end
    endtask

    // compare got[base .. base+len-1] against d, check remaining/last
    integer last_bad;
    task check_stream(input [W-1:0] d, input integer len, input integer base);
        integer k;
        begin
            last_bad = 0;
            for (k = 0; k < len; k = k + 1) begin
                if (got[base + k] !== d[W - 1 - k]) last_bad = last_bad + 1;
                if (rem_seen[base + k] !== (len - k)) last_bad = last_bad + 1;
                if (last_seen[base + k] !== (k == len - 1)) last_bad = last_bad + 1;
            end
        end
    endtask

    task report(input [8*70-1:0] name, input integer bad);
        begin
            if (bad == 0) $display("[PASS] %0s", name);
            else begin $display("[FAIL] %0s  (%0d problems)", name, bad); errors = errors + 1; end
        end
    endtask

    //-----------------------------------------------------------------
    // Tests
    //-----------------------------------------------------------------
    integer len, bad, i, l1, l2, r;
    reg [W-1:0] d1, d2, d3;

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // ------------------------------------------------ T1
        bad = 0;
        for (len = 1; len <= W; len = len + 1) begin
            d1 = rnd64(0);
            mon_reset;
            issue_load(d1, len);
            drain_to(len, len % 3);
            // keep shift_en high after the field is empty: must not underflow
            @(negedge clk); shift_en = 1;
            repeat (6) @(negedge clk);
            shift_en = 0;
            repeat (2) @(negedge clk);
            check_stream(d1, len, 0);
            bad = bad + last_bad;
            if (n_got != len)  bad = bad + 1;
            if (n_done != 1)   bad = bad + 1;
            if (n_rej != 0)    bad = bad + 1;
            if (valid)         bad = bad + 1;
        end
        report("T1 lengths 1..64, 3 shift_en patterns, remaining/last/done", bad);

        // ------------------------------------------------ T2
        bad = 0;
        for (r = 0; r < 40; r = r + 1) begin
            if (r == 0)      begin l1 = 1;  l2 = 1;  end
            else if (r == 1) begin l1 = 1;  l2 = 64; end
            else if (r == 2) begin l1 = 64; l2 = 1;  end
            else             begin l1 = 1 + ($urandom % 64); l2 = 1 + ($urandom % 64); end
            d1 = rnd64(0); d2 = rnd64(0);
            mon_reset;
            issue_load(d1, l1);
            burst_total = l1 + l2;
            burst_en = 1;                                   // from here on valid must never drop
            begin : find_last
                integer guard;
                guard = 0;
                while (guard < 100000) begin
                    @(negedge clk);
                    if (valid && last) begin                // reload in the very clock the last bit leaves
                        shift_en = 1; load = 1; load_data = d2; load_len = l2;
                        @(negedge clk); load = 0;
                        disable find_last;
                    end else shift_en = (($urandom % 3) == 0);
                    guard = guard + 1;
                end
            end
            drain_to(l1 + l2, 1);
            burst_en = 0;
            repeat (3) @(negedge clk);
            check_stream(d1, l1, 0);       bad = bad + last_bad;
            // second field: remaining/last are relative to l2
            for (i = 0; i < l2; i = i + 1) begin
                if (got[l1 + i] !== d2[W - 1 - i])         bad = bad + 1;
                if (rem_seen[l1 + i] !== (l2 - i))         bad = bad + 1;
                if (last_seen[l1 + i] !== (i == l2 - 1))   bad = bad + 1;
            end
            if (n_got != l1 + l2) bad = bad + 1;
            if (n_done != 2)      bad = bad + 1;
            if (n_rej != 0)       bad = bad + 1;
            if (v_low != 0)       bad = bad + 1;
        end
        report("T2 same-clock reload: bubble-free, order, counts", bad);

        // ------------------------------------------------ T3
        bad = 0;
        d1 = rnd64(0); d3 = rnd64(0);
        mon_reset;
        issue_load(d1, 20);
        consume(5);                                         // exactly 5 bits consumed
        if (n_got != 5) bad = bad + 1;
        // attempt A: busy, no shift this clock
        @(negedge clk); load = 1; load_data = d3; load_len = 10;
        @(negedge clk); load = 0;
        // attempt B: busy, a bit (not the last) is consumed in the same clock
        @(negedge clk); shift_en = 1; load = 1; load_data = d3; load_len = 10;
        @(negedge clk); load = 0; shift_en = 0;
        drain_to(20, 0);
        repeat (3) @(negedge clk);
        check_stream(d1, 20, 0); bad = bad + last_bad;
        if (n_rej  != 2) bad = bad + 1;
        if (n_done != 1) bad = bad + 1;
        if (n_got  != 20) bad = bad + 1;
        report("T3 load while busy rejected, running field untouched", bad);

        // ------------------------------------------------ T4
        bad = 0;
        d1 = rnd64(0);
        mon_reset;
        issue_load(d1, 0);
        repeat (3) @(negedge clk);
        if (n_rej != 1 || valid) bad = bad + 1;             // len 0 rejected, still empty
        issue_load(d1, 70);                                 // > WIDTH: clamped to 64
        drain_to(64, 0);
        @(negedge clk); shift_en = 1; repeat (4) @(negedge clk); shift_en = 0;
        repeat (2) @(negedge clk);
        check_stream(d1, 64, 0); bad = bad + last_bad;
        if (n_got != 64) bad = bad + 1;
        report("T4 len 0 rejected, len 70 clamped to 64", bad);

        // ------------------------------------------------ T5
        bad = 0;
        d1 = rnd64(0); d2 = rnd64(0);
        mon_reset;
        issue_load(d1, 40);
        consume(7);
        if (n_got != 7) bad = bad + 1;
        @(negedge clk); clear = 1;
        @(negedge clk); clear = 0;
        if (valid || remaining != 0) bad = bad + 1;
        shift_en = 1; repeat (5) @(negedge clk); shift_en = 0;
        if (n_got != 7) bad = bad + 1;                      // nothing more after clear
        mon_reset;
        issue_load(d2, 12);                                 // works again afterwards
        drain_to(12, 0);
        repeat (3) @(negedge clk);
        check_stream(d2, 12, 0); bad = bad + last_bad;
        report("T5 clear aborts a running field, next load works", bad);

        // ------------------------------------------------ T6
        bad = 0;
        mon_reset;
        shift_en = 1; repeat (30) @(negedge clk); shift_en = 0;
        if (n_got != 0 || n_done != 0) bad = bad + 1;
        report("T6 shift_en while empty does nothing", bad);

        $display("----------------------------------------------------");
        if (errors == 0) $display("ALL TX SHIFT TESTS PASSED");
        else             $display("%0d TX SHIFT TEST(S) FAILED", errors);
        $display("----------------------------------------------------");
        $finish;
    end

endmodule