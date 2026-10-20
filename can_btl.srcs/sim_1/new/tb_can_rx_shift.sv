//=============================================================================
// Testbench : tb_can_rx_shift
//
// Bits are sent MSB first; the expected field is simply the value that was sent
// (right-aligned, upper bits zero).
//
//  R1  every length 1..16, random value, random gaps between bits:
//      count after every bit, done exactly ONE clock after the last bit,
//      done is 1 clock wide, data correct
//  R2  field sequence as the BSP uses it (12, 7, 8, 8, 8, 15 bits); len is
//      changed in the clock where done is seen; data must stay stable
//  R3  len = 0 ignores bits and they do not pollute the next field
//  R4  clear in the middle of a field discards the partial field
//  R5  len lowered below the bits already received: completes with next bit
//  R6  len > WIDTH is clamped to WIDTH
//  R7  bits on consecutive clocks (bit_valid held high): 8 bytes in a row
//  R8  'data' holds its value while the bits of the next field arrive
//=============================================================================
`timescale 1ns/1ps

module tb_can_rx_shift;

    localparam int W  = 16;
    localparam int LW = $clog2(W + 1);

    logic          clk = 0, rst_n = 0, clear = 0;
    logic [LW-1:0] len = 0;
    logic          bit_valid = 0, bit_in = 0;
    wire  [W-1:0]  data;
    wire  [LW-1:0] count;
    wire           done;

    can_rx_shift #(.WIDTH(W)) dut (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .len(len), .bit_valid(bit_valid), .bit_in(bit_in),
        .data(data), .count(count), .done(done)
    );

    always #5 clk = ~clk;

    //-----------------------------------------------------------------
    // Monitor: done timing, width, recorded data
    //-----------------------------------------------------------------
    integer cyc = 0, lastbv = -100, n_done = 0, timing_err = 0, width_err = 0;
    reg     prev_done = 0;
    reg [W-1:0] done_data [0:255];

    always @(posedge clk) begin
        cyc = cyc + 1;
        if (done) begin
            if (cyc != lastbv + 1) timing_err = timing_err + 1;   // done exactly 1 clock after a bit
            if (prev_done)         width_err  = width_err + 1;
            if (n_done < 256) done_data[n_done] = data;
            n_done = n_done + 1;
        end
        if (bit_valid) lastbv = cyc;
        prev_done = done;
    end

    task mon_reset;
        begin n_done = 0; timing_err = 0; width_err = 0; end
    endtask

    //-----------------------------------------------------------------
    // Drivers
    //-----------------------------------------------------------------
    integer errors = 0;

    task send_bit(input b, input integer gap);
        begin
            @(negedge clk); bit_in = b; bit_valid = 1;
            @(negedge clk); bit_valid = 0;
            repeat (gap) @(negedge clk);
        end
    endtask

    task send_value(input [W-1:0] v, input integer nbits, input integer gap);
        integer i;
        begin
            for (i = nbits - 1; i >= 0; i = i - 1) send_bit(v[i], gap);
        end
    endtask

    task report(input [8*70-1:0] name, input integer bad);
        begin
            if (bad == 0) $display("[PASS] %0s", name);
            else begin $display("[FAIL] %0s  (%0d problems)", name, bad); errors = errors + 1; end
        end
    endtask

    function [W-1:0] mask_of(input integer n);
        begin mask_of = (n >= W) ? {W{1'b1}} : ((1 << n) - 1); end
    endfunction

    //-----------------------------------------------------------------
    // Tests
    //-----------------------------------------------------------------
    integer L, bad, i, j, k;
    reg [W-1:0] v, v2, held;
    reg [W-1:0] fv [0:7];
    integer     fl [0:7];
    reg [7:0]   bytes [0:7];

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        // ------------------------------------------------ R1
        bad = 0;
        for (L = 1; L <= W; L = L + 1) begin
            v = $urandom & mask_of(L);
            len = L;
            mon_reset;
            for (i = L - 1; i >= 0; i = i - 1) begin
                send_bit(v[i], $urandom % 4);
                // after bit number (L-i) the counter must show L-i (or 0 once the field is complete)
                if (i > 0) begin if (count != (L - i)) bad = bad + 1; end
                else       begin if (count != 0)       bad = bad + 1; end
            end
            repeat (3) @(negedge clk);
            if (n_done != 1)        bad = bad + 1;
            else if (done_data[0] !== v) bad = bad + 1;
            if (data !== v)         bad = bad + 1;          // data HOLDS after done
            if (timing_err != 0 || width_err != 0) bad = bad + 1;
        end
        report("R1 lengths 1..16: count, done timing/width, data, hold", bad);

        // ------------------------------------------------ R2
        bad = 0;
        for (j = 0; j < 20; j = j + 1) begin
            // BSP-style sequence: SOF+ID(12), ctrl(7), 3 data bytes(8), CRC(15)
            fl[0] = 12; fl[1] = 7; fl[2] = 8; fl[3] = 8; fl[4] = 8; fl[5] = 15;
            for (k = 0; k < 6; k = k + 1) fv[k] = $urandom & mask_of(fl[k]);
            mon_reset;
            len = fl[0];
            for (k = 0; k < 6; k = k + 1) begin
                send_value(fv[k], fl[k], 1 + ($urandom % 3));
                // wait until this field's done has been seen
                begin : waitdone
                    integer g; g = 0;
                    while (n_done < k + 1 && g < 20) begin @(negedge clk); g = g + 1; end
                end
                if (n_done != k + 1)        bad = bad + 1;
                else if (done_data[k] !== fv[k]) bad = bad + 1;
                held = data;
                if (k < 5) len = fl[k + 1];                   // change len in the clock done is visible
                @(negedge clk);
                if (data !== held) bad = bad + 1;             // data must not change when len changes
            end
            if (timing_err != 0 || width_err != 0) bad = bad + 1;
        end
        report("R2 BSP field sequence 12/7/8/8/8/15, len changed at done", bad);

        // ------------------------------------------------ R3
        bad = 0;
        mon_reset; len = 0;
        for (i = 0; i < 10; i = i + 1) send_bit($urandom, 1);       // 10 bits that must be ignored
        if (n_done != 0 || count != 0) bad = bad + 1;
        v = $urandom & mask_of(5);
        len = 5;
        send_value(v, 5, 1);
        repeat (3) @(negedge clk);
        if (n_done != 1 || data !== v) bad = bad + 1;               // not polluted by the ignored bits
        report("R3 len=0 ignores bits, next field is clean", bad);

        // ------------------------------------------------ R4
        bad = 0;
        mon_reset; len = 12;
        for (i = 0; i < 5; i = i + 1) send_bit(1'b1, 1);
        if (count != 5) bad = bad + 1;
        @(negedge clk); clear = 1;
        @(negedge clk); clear = 0;
        if (count != 0 || n_done != 0) bad = bad + 1;
        v = $urandom & mask_of(12);
        len = 12;
        send_value(v, 12, 1);
        repeat (3) @(negedge clk);
        if (n_done != 1 || data !== v) bad = bad + 1;
        report("R4 clear discards the partial field", bad);

        // ------------------------------------------------ R5
        bad = 0;
        mon_reset; len = 12;
        v = $urandom;                                               // use bits 5..0 of v as b0..b5 (b0 first)
        for (i = 5; i >= 1; i = i - 1) send_bit(v[i], 1);           // b0..b4  (5 bits)
        if (count != 5) bad = bad + 1;
        len = 4;                                                    // now fewer bits than already received
        send_bit(v[0], 1);                                          // b5 : completes the field
        repeat (3) @(negedge clk);
        if (n_done != 1) bad = bad + 1;
        else if (done_data[0] !== {12'b0, v[3], v[2], v[1], v[0]}) bad = bad + 1;   // last 4 bits sent
        if (count != 0) bad = bad + 1;
        report("R5 len lowered mid-field completes with the next bit", bad);

        // ------------------------------------------------ R6
        bad = 0;
        mon_reset; len = 20;                                        // > WIDTH: clamped to 16
        v = $urandom;
        send_value(v, 16, 1);
        repeat (3) @(negedge clk);
        if (n_done != 1 || data !== v || count != 0) bad = bad + 1;
        report("R6 len 20 is clamped to 16", bad);

        // ------------------------------------------------ R7
        bad = 0;
        mon_reset; len = 8;
        for (k = 0; k < 8; k = k + 1) bytes[k] = $urandom;
        @(negedge clk); bit_valid = 1;
        for (k = 0; k < 8; k = k + 1)
            for (i = 7; i >= 0; i = i - 1) begin
                bit_in = bytes[k][i];
                @(negedge clk);
            end
        bit_valid = 0;
        repeat (4) @(negedge clk);
        if (n_done != 8) bad = bad + 1;
        else for (k = 0; k < 8; k = k + 1) if (done_data[k] !== {8'b0, bytes[k]}) bad = bad + 1;
        if (timing_err != 0) bad = bad + 1;
        report("R7 bits on consecutive clocks: 8 bytes in a row", bad);

        // ------------------------------------------------ R8
        // 'data' must HOLD while the bits of the NEXT field arrive (the BSP may read
        // the ID / control field later, while data bytes are still coming in)
        bad = 0;
        mon_reset;
        v  = $urandom & mask_of(12);
        v2 = $urandom & mask_of(8);
        len = 12;
        send_value(v, 12, 1);
        repeat (3) @(negedge clk);
        if (n_done != 1 || data !== v) bad = bad + 1;
        len = 8;
        for (i = 7; i >= 3; i = i - 1) begin                        // 5 of the 8 bits of the next field
            send_bit(v2[i], 1);
            if (data !== v) bad = bad + 1;                          // still the OLD field
        end
        for (i = 2; i >= 0; i = i - 1) send_bit(v2[i], 1);          // finish the next field
        repeat (3) @(negedge clk);
        if (n_done != 2 || data !== v2) bad = bad + 1;              // now the new one
        report("R8 data holds while the next field is being received", bad);

        $display("----------------------------------------------------");
        if (errors == 0) $display("ALL RX SHIFT TESTS PASSED");
        else             $display("%0d RX SHIFT TEST(S) FAILED", errors);
        $display("----------------------------------------------------");
        $finish;
    end

endmodule