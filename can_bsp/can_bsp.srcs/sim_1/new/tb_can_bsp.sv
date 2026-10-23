//=============================================================================
// Testbench   : tb_can_bsp
// Description : Self-checking testbench for the can_bsp FSM skeleton.
//               Verifies state transitions using bit_tick strobes.
//               Full-frame data correctness (CRC, stuffing, ACK) is NOT
//               tested here -- those checks belong in the integration
//               testbench once the per-field logic is filled in.
//
// Tests:
//   T1 - Reset -> IDLE
//   T2 - tx_request -> SOF -> ARBITRATION after 1 bit_tick
//   T3 - Step through ARBITRATION (12 ticks) -> CONTROL
//   T4 - Step through CONTROL (6 ticks) -> DATA (DLC = 2, non-zero)
//   T5 - Step through DATA (16 ticks for DLC=2) -> CRC_FIELD
//   T6 - Step through CRC_FIELD (16 ticks) -> ACK
//   T7 - Step through ACK (2 ticks) -> EOF
//   T8 - Step through EOF (7 ticks) -> IFS
//   T9 - Step through IFS (3 ticks) -> IDLE (no pending tx_request)
//   T10- DLC = 0 : CONTROL -> CRC_FIELD (skip DATA)
//   T11- stuff_error during DATA -> ERROR_FRAME immediately
//   T12- ERROR_FRAME steps through 14 ticks -> IFS
//   T13- clear signal -> IDLE from any state
//
// XSim note: all variables declared at module level.
//=============================================================================

`timescale 1ns/1ps

module tb_can_bsp;

    // -------------------------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    logic        clear;
    logic        bit_tick;
    logic        sample_point;
    logic        rx_bit;
    logic        tx_request;
    logic [10:0] tx_id;
    logic [3:0]  tx_dlc;
    logic        stuff_error;
    logic        crc_ok;

    logic        tx_bit_out;
    logic        tx_en;
    logic        frame_active;
    logic        error_out;
    logic [3:0]  state_out;

    // -------------------------------------------------------------------------
    // State encoding -- mirrors the DUT enum (must stay in sync)
    // -------------------------------------------------------------------------
    localparam logic [3:0] ST_IDLE        = 4'd0;
    localparam logic [3:0] ST_SOF         = 4'd1;
    localparam logic [3:0] ST_ARBITRATION = 4'd2;
    localparam logic [3:0] ST_CONTROL     = 4'd3;
    localparam logic [3:0] ST_DATA        = 4'd4;
    localparam logic [3:0] ST_CRC_FIELD   = 4'd5;
    localparam logic [3:0] ST_ACK         = 4'd6;
    localparam logic [3:0] ST_EOF         = 4'd7;
    localparam logic [3:0] ST_IFS         = 4'd8;
    localparam logic [3:0] ST_ERROR_FRAME = 4'd9;

    // -------------------------------------------------------------------------
    // Test counters (module level for XSim)
    // -------------------------------------------------------------------------
    int tests  = 0;
    int errors = 0;
    int k;          // general-purpose loop counter

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    can_bsp dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .clear       (clear),
        .bit_tick    (bit_tick),
        .sample_point(sample_point),
        .rx_bit      (rx_bit),
        .tx_request  (tx_request),
        .tx_id       (tx_id),
        .tx_dlc      (tx_dlc),
        .stuff_error (stuff_error),
        .crc_ok      (crc_ok),
        .tx_bit      (tx_bit_out),
        .tx_en       (tx_en),
        .frame_active(frame_active),
        .error_out   (error_out),
        .state_out   (state_out)
    );

    // -------------------------------------------------------------------------
    // 100 MHz clock
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Helper: issue one bit_tick strobe (one CAN bit time)
    // -------------------------------------------------------------------------
    task automatic tick;
        @(negedge clk);
        bit_tick = 1'b1;
        @(negedge clk);
        bit_tick = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Helper: issue N bit_tick strobes
    // -------------------------------------------------------------------------
    task automatic tick_n(input int n);
        int j;
        for (j = 0; j < n; j = j + 1)
            tick();
    endtask

    // -------------------------------------------------------------------------
    // Helper: assert a state check
    // -------------------------------------------------------------------------
    task automatic check_state(
        input string       label,
        input logic [3:0]  expected
    );
        @(negedge clk);
        tests = tests + 1;
        if (state_out !== expected) begin
            $display("[FAIL] %-45s  expected state=%0d  got=%0d",
                     label, expected, state_out);
            errors = errors + 1;
        end else begin
            $display("[PASS] %-45s  state=%0d", label, state_out);
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: full reset and default signal values
    // -------------------------------------------------------------------------
    task automatic do_reset;
        rst_n        = 1'b0;
        clear        = 1'b0;
        bit_tick     = 1'b0;
        sample_point = 1'b0;
        rx_bit       = 1'b1;   // recessive (bus idle)
        tx_request   = 1'b0;
        tx_id        = 11'h000;
        tx_dlc       = 4'd0;
        stuff_error  = 1'b0;
        crc_ok       = 1'b1;
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin

        do_reset();

        // ==================================================================
        // T1 -- After reset, FSM must be in IDLE
        // ==================================================================
        check_state("T1  reset -> IDLE", ST_IDLE);

        // ==================================================================
        // T2 -- tx_request -> SOF on next rising edge
        // ==================================================================
        @(negedge clk);
        tx_request = 1'b1;
        tx_id      = 11'h2A5;
        tx_dlc     = 4'd2;
        @(negedge clk);
        check_state("T2  tx_request -> SOF", ST_SOF);

        // ==================================================================
        // T3 -- 1 bit_tick in SOF -> ARBITRATION
        //        then 11 more ticks (bit_cnt 0..10) stay; tick 12 -> CONTROL
        //        LEN_ARB = 12, so we need 12 ticks total inside ARBITRATION.
        // ==================================================================
        tick();    // SOF bit -> ARBITRATION
        check_state("T3a  after SOF tick -> ARBITRATION", ST_ARBITRATION);

        tick_n(11);   // bits 0..10 inside ARBITRATION (bit_cnt reaches 11)
        check_state("T3b  11 ticks in ARBITRATION (still ARBITRATION)", ST_ARBITRATION);

        tick();    // bit_cnt was 11 >= LEN_ARB-1=11 -> CONTROL
        check_state("T3c  12th tick -> CONTROL", ST_CONTROL);

        // ==================================================================
        // T4 -- 5 ticks stay in CONTROL; 6th tick -> DATA (DLC=2, non-zero)
        // ==================================================================
        tick_n(5);
        check_state("T4a  5 ticks in CONTROL (still CONTROL)", ST_CONTROL);

        tick();
        check_state("T4b  6th tick -> DATA", ST_DATA);

        // ==================================================================
        // T5 -- DLC=2 -> 16 data bits. 15 ticks stay; 16th -> CRC_FIELD
        // ==================================================================
        tick_n(15);
        check_state("T5a  15 ticks in DATA (still DATA)", ST_DATA);

        tick();
        check_state("T5b  16th tick -> CRC_FIELD", ST_CRC_FIELD);

        // ==================================================================
        // T6 -- 15 ticks stay in CRC_FIELD; 16th -> ACK
        // ==================================================================
        tick_n(15);
        check_state("T6a  15 ticks in CRC_FIELD (still CRC_FIELD)", ST_CRC_FIELD);

        tick();
        check_state("T6b  16th tick -> ACK", ST_ACK);

        // ==================================================================
        // T7 -- 1 tick stays in ACK; 2nd -> EOF
        // ==================================================================
        tick();
        check_state("T7a  1 tick in ACK (still ACK)", ST_ACK);

        tick();
        check_state("T7b  2nd tick -> EOF", ST_EOF);

        // ==================================================================
        // T8 -- 6 ticks stay in EOF; 7th -> IFS
        // ==================================================================
        tick_n(6);
        check_state("T8a  6 ticks in EOF (still EOF)", ST_EOF);

        tick();
        check_state("T8b  7th tick -> IFS", ST_IFS);

        // ==================================================================
        // T9 -- 2 ticks stay in IFS; 3rd -> IDLE (tx_request still high,
        //        but we lower it first to test the IDLE return path)
        // ==================================================================
        tx_request = 1'b0;
        tick_n(2);
        check_state("T9a  2 ticks in IFS (still IFS)", ST_IFS);

        tick();
        check_state("T9b  3rd tick -> IDLE (no pending request)", ST_IDLE);

        // ==================================================================
        // T10 -- DLC = 0: CONTROL should skip DATA and go straight to CRC_FIELD
        // ==================================================================
        tx_dlc     = 4'd0;
        tx_request = 1'b1;
        @(negedge clk);                         // -> SOF
        tick();                                 // -> ARBITRATION
        tick_n(12);                             // -> CONTROL
        // In CONTROL with DLC=0: after 6 ticks should go to CRC_FIELD
        tick_n(5);
        check_state("T10a  5 ticks CONTROL DLC=0 (still CONTROL)", ST_CONTROL);
        tick();
        check_state("T10b  6th tick CONTROL DLC=0 -> CRC_FIELD", ST_CRC_FIELD);
        // Clean up: step through to IDLE
        tick_n(16); tick_n(2); tick_n(7);
        tx_request = 1'b0;
        tick_n(3);
        check_state("T10c  returned to IDLE after DLC=0 frame", ST_IDLE);

        // ==================================================================
        // T11 -- stuff_error during DATA -> ERROR_FRAME immediately
        // ==================================================================
        tx_dlc     = 4'd8;
        tx_request = 1'b1;
        @(negedge clk);    // -> SOF
        tick();            // -> ARBITRATION
        tick_n(12);        // -> CONTROL
        tick_n(6);         // -> DATA
        tick_n(3);         // 3 bits into DATA

        @(negedge clk);
        stuff_error = 1'b1;   // inject error
        @(negedge clk);
        stuff_error = 1'b0;
        check_state("T11  stuff_error in DATA -> ERROR_FRAME", ST_ERROR_FRAME);

        // ==================================================================
        // T12 -- ERROR_FRAME: 13 ticks stay; 14th -> IFS
        // ==================================================================
        tick_n(13);
        check_state("T12a  13 ticks in ERROR_FRAME (still ERROR_FRAME)", ST_ERROR_FRAME);

        tick();
        check_state("T12b  14th tick -> IFS", ST_IFS);

        tx_request = 1'b0;
        tick_n(3);
        check_state("T12c  IFS -> IDLE after ERROR_FRAME", ST_IDLE);

        // ==================================================================
        // T13 -- clear signal returns FSM to IDLE from any state
        // ==================================================================
        tx_dlc     = 4'd1;
        tx_request = 1'b1;
        @(negedge clk);   // -> SOF
        tick();           // -> ARBITRATION

        @(negedge clk);
        tx_request = 1'b0;  // lower before clear so IDLE does not instantly re-enter SOF
        clear      = 1'b1;
        @(negedge clk);
        clear = 1'b0;
        check_state("T13  clear in ARBITRATION -> IDLE", ST_IDLE);


        tx_request = 1'b0;

        // ==================================================================
        // Summary
        // ==================================================================
        $display("----------------------------------------------------");
        if (errors == 0)
            $display("ALL %0d BSP FSM TESTS PASSED", tests);
        else
            $display("%0d / %0d BSP FSM TESTS FAILED", errors, tests);
        $display("----------------------------------------------------");

        $finish;
    end

endmodule