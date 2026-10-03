//=============================================================================
// Testbench   : tb_can_crc
// Description : Self-checking testbench for can_crc.
//
// Tests:
//   T1 - 20 zero bits
//   T2 - 12-bit alternating 101010101010 pattern
//   T3 - Classical CAN header-like sequence:
//        SOF(0) + ID 0x7FF + RTR(0) + IDE(0) + r0(0) + DLC(0000)
//   T4 - Single '1' bit
//   T5 - calc_en=0 hold behavior
//
// Reference CRC uses the direct polynomial expression:
//   next_crc = (crc << 1) ^ (feedback ? 15'h4599 : 15'h0000)
// This is intentionally written differently from the DUT's individual taps.
//=============================================================================

`timescale 1ns/1ps

module tb_can_crc;

    logic        clk;
    logic        rst_n;
    logic        init;
    logic        calc_en;
    logic        bit_in;
    logic [14:0] crc_out;

    int errors = 0;
    int tests  = 0;

    can_crc dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .init    (init),
        .calc_en (calc_en),
        .bit_in  (bit_in),
        .crc_out (crc_out)
    );

    // 100 MHz clock -> 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Independent software-style reference update.
    function automatic logic [14:0] crc15_next (
        input logic [14:0] crc,
        input logic        data_bit
    );
        logic feedback;
        logic [14:0] shifted;
        begin
            feedback = data_bit ^ crc[14];
            shifted  = {crc[13:0], 1'b0};
            crc15_next = shifted ^ (feedback ? 15'h4599 : 15'h0000);
        end
    endfunction

    task automatic reset_crc;
        begin
            @(negedge clk);
            init    = 1'b1;
            calc_en = 1'b0;
            bit_in  = 1'b0;

            @(negedge clk);
            init    = 1'b0;
        end
    endtask

    task automatic drive_bit(input logic b);
        begin
            @(negedge clk);
            calc_en = 1'b1;
            bit_in  = b;
        end
    endtask

    task automatic check_value(
        input string       name,
        input logic [14:0] expected
    );
        begin
            @(negedge clk);
            calc_en = 1'b0;
            tests++;

            if (crc_out !== expected) begin
                $display("[FAIL] %-42s expected=0x%04h got=0x%04h",
                         name, expected, crc_out);
                errors++;
            end
            else begin
                $display("[PASS] %-42s crc=0x%04h", name, crc_out);
            end
        end
    endtask

    initial begin
        logic [14:0] ref_crc;
        logic [14:0] held_crc;

        rst_n   = 1'b0;
        init    = 1'b0;
        calc_en = 1'b0;
        bit_in  = 1'b0;

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // --------------------------------------------------------------------
        // T1: 20 zero bits
        // --------------------------------------------------------------------
        reset_crc();
        repeat (20)
            drive_bit(1'b0);
        check_value("T1 all-zero 20 bits", 15'h0000);

        // --------------------------------------------------------------------
        // T2: 12-bit alternating sequence: 101010101010
        // Correct CRC-15/CAN result = 0x77BB
        // --------------------------------------------------------------------
        reset_crc();
        drive_bit(1); drive_bit(0); drive_bit(1); drive_bit(0);
        drive_bit(1); drive_bit(0); drive_bit(1); drive_bit(0);
        drive_bit(1); drive_bit(0); drive_bit(1); drive_bit(0);
        check_value("T2 alternating 12 bits", 15'h77BB);

        // --------------------------------------------------------------------
        // T3:
        // SOF(0) + ID=0x7FF (11 ones) + RTR(0) + IDE(0) + r0(0) + DLC=0000
        // Total bits processed = 19
        // Correct CRC-15/CAN result = 0x272F
        // --------------------------------------------------------------------
        reset_crc();
        drive_bit(0);                    // SOF
        repeat (11) drive_bit(1'b1);     // 11-bit identifier = 0x7FF
        drive_bit(0);                    // RTR
        drive_bit(0);                    // IDE
        drive_bit(0);                    // r0
        repeat (4) drive_bit(1'b0);      // DLC = 0000
        check_value("T3 SOF+ID7FF+RTR+IDE+r0+DLC0", 15'h272F);

        // --------------------------------------------------------------------
        // T4: single '1' bit
        // Starting from CRC=0:
        // next = 0 ^ 15'h4599 = 15'h4599
        // --------------------------------------------------------------------
        reset_crc();
        drive_bit(1'b1);
        check_value("T4 single 1 bit", 15'h4599);

        // --------------------------------------------------------------------
        // T5: verify calc_en=0 holds the current CRC unchanged
        // --------------------------------------------------------------------
        reset_crc();
        ref_crc = 15'h0000;

        drive_bit(1'b1);
        ref_crc = crc15_next(ref_crc, 1'b1);

        drive_bit(1'b0);
        ref_crc = crc15_next(ref_crc, 1'b0);

        @(negedge clk);
        calc_en = 1'b0;
        bit_in  = 1'b1;
        held_crc = crc_out;

        repeat (4) @(negedge clk);

        tests++;
        if ((crc_out !== held_crc) || (crc_out !== ref_crc)) begin
            $display("[FAIL] %-42s expected_hold=0x%04h got=0x%04h",
                     "T5 calc_en=0 holds CRC", ref_crc, crc_out);
            errors++;
        end
        else begin
            $display("[PASS] %-42s crc=0x%04h",
                     "T5 calc_en=0 holds CRC", crc_out);
        end

        $display("----------------------------------------------------");
        if (errors == 0)
            $display("ALL %0d CRC TESTS PASSED", tests);
        else
            $display("%0d / %0d CRC TESTS FAILED", errors, tests);
        $display("----------------------------------------------------");

        $finish;
    end

endmodule