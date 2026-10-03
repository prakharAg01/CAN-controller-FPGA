//=============================================================================
// Testbench: tb_can_bit_stuffing  (ported to the fixed, bit-tick based modules)
//
//  T1  Your original 20-bit vector, whole vector stuffed.
//  T2  CRC-end case: stuff region ends on a run of 5 -> trailing stuff bit
//      must still be sent / consumed before the delimiter.
//  T3  Long runs of 0s and of 1s.
//  T4  300 random run-heavy frames, random stuff_en window length.
//  T5  Destuffer error: 6 identical bits -> stuff_error is exactly 1 clk wide
//      even though bit_valid is sparse.
//
// Checks per frame: bus stream == independent reference stuffed stream,
// destuffer output == original raw bits, no stuff_error.
// Loopback: stuffer.bit_out -> destuffer.bit_in, bit_valid = bit_out_valid.
// One bit time = BIT_DIV clocks (so the tests are NOT one-bit-per-clock).
//=============================================================================
`timescale 1ns/1ps

module tb_can_bit_stuffing;

    localparam int BIT_DIV = 8;

    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    // ---------------- bit tick ----------------
    int   tick_cnt;
    logic bit_tick;
    always @(posedge clk) begin
        if (!rst_n) begin tick_cnt <= 0; bit_tick <= 0; end
        else if (tick_cnt == BIT_DIV-1) begin tick_cnt <= 0; bit_tick <= 1; end
        else begin tick_cnt <= tick_cnt + 1; bit_tick <= 0; end
    end

    // ---------------- TX BSP model ----------------
    logic         clear = 0;
    logic         tx_run = 0;
    logic [127:0] tx_bits;
    int           tx_len, tx_slen, tx_idx;

    wire  tx_data_valid = tx_run && (tx_idx < tx_len);
    wire  tx_bit_in     = (tx_idx < 128) ? tx_bits[tx_idx] : 1'b0;
    wire  tx_stuff_en   = tx_run && (tx_idx < tx_slen);   // drops right after last CRC bit
    wire  ready, stuff_pending, bus_bit, bus_valid, stuffing;

    always @(posedge clk)
        if (tx_data_valid && ready) tx_idx <= tx_idx + 1;

    can_bit_stuffer u_stuffer (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .bit_tick(bit_tick), .stuff_en(tx_stuff_en),
        .data_valid(tx_data_valid), .bit_in(tx_bit_in),
        .ready(ready), .stuff_pending(stuff_pending),
        .bit_out(bus_bit), .bit_out_valid(bus_valid), .stuffing(stuffing)
    );

    // ---------------- RX side ----------------
    int           rx_cnt;
    logic [127:0] rx_bits;
    wire          rx_destuff_en = tx_run && (rx_cnt < tx_slen);
    wire          rx_bit, rx_dv, rx_err, rx_stuff_expected;

    can_bit_destuffer u_destuffer (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .destuff_en(rx_destuff_en), .bit_valid(bus_valid), .bit_in(bus_bit),
        .bit_out(rx_bit), .data_valid(rx_dv), .stuff_error(rx_err),
        .stuff_expected(rx_stuff_expected)
    );

    // ---------------- capture ----------------
    logic bus_cap [0:255];
    int   bus_n;
    int   err_seen;
    always @(posedge clk) begin
        if (bus_valid) begin bus_cap[bus_n] = bus_bit; bus_n = bus_n + 1; end
        if (rx_dv && rx_cnt < 128) begin rx_bits[rx_cnt] = rx_bit; rx_cnt = rx_cnt + 1; end
        if (rx_err) err_seen = err_seen + 1;
    end

    // ---------------- reference model ----------------
    logic exp_bits [0:255];
    int   exp_n;
    bit   exp_trailing;

    task build_ref(input logic [127:0] bits, input int n, input int slen);
        int  i, run;
        logic last;
        begin
            exp_n = 0; run = 0; last = 1'b1; exp_trailing = 0;
            for (i = 0; i < n; i = i + 1) begin
                exp_bits[exp_n] = bits[i]; exp_n = exp_n + 1;
                if (i < slen) begin
                    if (bits[i] == last) run = run + 1; else run = 1;
                    last = bits[i];
                    if (run == 5) begin
                        exp_bits[exp_n] = ~last; exp_n = exp_n + 1;
                        last = ~last; run = 1;
                        if (i == slen-1) exp_trailing = 1;
                    end
                end
            end
        end
    endtask

    int errors = 0, tests = 0, trailing_hits = 0;

    task run_frame(input string name, input logic [127:0] bits, input int n, input int slen);
        int i;
        bit bad;
        begin
            build_ref(bits, n, slen);
            @(negedge clk); clear = 1;
            @(negedge clk); clear = 0;
            tx_bits = bits; tx_len = n; tx_slen = slen; tx_idx = 0;
            bus_n = 0; rx_cnt = 0; rx_bits = 0; err_seen = 0;
            tx_run = 1;
            repeat (BIT_DIV * (n + 16)) @(negedge clk);
            tx_run = 0;
            @(negedge clk);

            bad = 0; tests++;
            if (exp_trailing) trailing_hits++;
            if (bus_n !== exp_n) begin
                $display("[FAIL] %s: bus length %0d, expected %0d", name, bus_n, exp_n); bad = 1;
            end else
                for (i = 0; i < exp_n; i++)
                    if (bus_cap[i] !== exp_bits[i]) begin
                        $display("[FAIL] %s: bus[%0d]=%0b expected %0b", name, i, bus_cap[i], exp_bits[i]); bad = 1;
                    end
            if (rx_cnt !== n) begin
                $display("[FAIL] %s: destuffer recovered %0d bits, expected %0d", name, rx_cnt, n); bad = 1;
            end else
                for (i = 0; i < n; i++)
                    if (rx_bits[i] !== bits[i]) begin
                        $display("[FAIL] %s: recovered[%0d]=%0b expected %0b", name, i, rx_bits[i], bits[i]); bad = 1;
                    end
            if (err_seen != 0) begin
                $display("[FAIL] %s: unexpected stuff_error x%0d", name, err_seen); bad = 1;
            end
            if (bad) errors++;
            else $display("[PASS] %s (%0d raw -> %0d on bus)", name, n, exp_n);
        end
    endtask

    // ---------------- T5: standalone destuffer error check ----------------
    logic e_valid = 0, e_bit = 0, e_en = 1;
    wire  e_out, e_dv, e_err, e_exp;
    int   e_cycles = 0;
    can_bit_destuffer u_err (
        .clk(clk), .rst_n(rst_n), .clear(1'b0),
        .destuff_en(e_en), .bit_valid(e_valid), .bit_in(e_bit),
        .bit_out(e_out), .data_valid(e_dv), .stuff_error(e_err), .stuff_expected(e_exp)
    );
    always @(posedge clk) if (e_err) e_cycles = e_cycles + 1;

    task send_raw(input logic b);
        begin
            @(negedge clk); e_valid = 1; e_bit = b;
            @(negedge clk); e_valid = 0;
            repeat (BIT_DIV-2) @(negedge clk);
        end
    endtask

    // ---------------- main ----------------
    logic [127:0] v;
    int r, n, s;
    logic prev;

    initial begin
        tx_bits = 0; tx_len = 0; tx_slen = 0; tx_idx = 0; bus_n = 0; rx_cnt = 0; rx_bits = 0; err_seen = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // T1: your original vector, stuff_en for the whole vector
        v = 0;
        v[4:0]   = 5'b00000;   // idx 0..4  : five 0s
        v[5]=1; v[6]=0;
        v[11:7]  = 5'b11111;   // idx 7..11 : five 1s
        v[12]=0; v[13]=1;
        v[18:14] = 5'b00000;   // idx 14..18: five 0s
        v[19]=1;
        run_frame("T1 original vector", v, 20, 20);

        // T2a: CRC ends on five 1s, then delimiter(1) + ACK slot(0) unstuffed
        v = 0;
        v[11:0] = 12'b1111_1010_1010; // idx0..: 0,1,0,1,0,1,0,1,1,1,1,1
        v[12] = 1;  v[13] = 0;
        run_frame("T2a CRC ends on 5x1", v, 14, 12);

        // T2b: CRC ends on five 0s
        v = 0;
        v[5:0] = 6'b010101;  // idx0..5 : 1,0,1,0,1,0
        v[6]=1; v[7]=0; v[8]=0; v[9]=0; v[10]=0; v[11]=0;   // five 0s at 7..11
        v[12] = 1;  v[13] = 1;
        run_frame("T2b CRC ends on 5x0", v, 14, 12);

        // T3: long runs
        v = 0;                                    run_frame("T3a 40x0", v, 40, 40);
        v = {128{1'b1}};                          run_frame("T3b 40x1", v, 40, 40);

        // T4: random run-heavy frames
        for (r = 0; r < 300; r++) begin
            n = 20 + ($urandom % 60);
            s = 1 + ($urandom % n);
            prev = $urandom;
            v = 0;
            for (int k = 0; k < n; k++) begin
                if (($urandom % 4) == 0) prev = ~prev;
                v[k] = prev;
            end
            run_frame($sformatf("T4 rand#%0d", r), v, n, s);
        end
        $display("      (%0d of %0d frames exercised the trailing-stuff-bit case)", trailing_hits, tests);
        if (trailing_hits == 0) begin $display("[FAIL] trailing case never exercised"); errors++; end

        // T5: six 1s from idle -> stuff_error must be a single 1-clk pulse
        repeat (2) send_raw(1'b1);   // bits 1,2
        repeat (3) send_raw(1'b1);   // bits 3,4,5  -> stuff expected
        if (!e_exp) begin $display("[FAIL] T5 stuff_expected not raised after 5 bits"); errors++; end
        send_raw(1'b1);              // 6th identical bit -> error
        repeat (3) @(negedge clk);
        if (e_cycles !== 1) begin $display("[FAIL] T5 stuff_error high for %0d clks, expected 1", e_cycles); errors++; end
        else $display("[PASS] T5 stuff_error is a 1-clk pulse");

        $display("----------------------------------------------------");
        if (errors == 0) $display("ALL BIT-STUFFING TESTS PASSED (%0d frame tests)", tests);
        else             $display("%0d BIT-STUFFING TEST(S) FAILED", errors);
        $display("----------------------------------------------------");
        $finish;
    end

endmodule