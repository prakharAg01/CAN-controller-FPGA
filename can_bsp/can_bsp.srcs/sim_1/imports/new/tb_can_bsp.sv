//=============================================================================
// Testbench   : tb_can_bsp
// Description : Self-checking testbench for the can_bsp FSM.
//               Verifies state transitions, TX serialisation, bit stuffing,
//               lost arbitration, data field output, and CRC field output.
//
// Tests:
//   T1  - Reset -> IDLE
//   T2  - tx_request -> SOF -> ARBITRATION after 1 bit_tick
//   T3  - Step through ARBITRATION (12 ticks) -> CONTROL
//   T4  - Step through CONTROL (7 ticks incl. boundary stuff bit) -> DATA (DLC=2)
//   T5  - Step through DATA (16 ticks for DLC=2, alternating data) -> CRC_FIELD
//   T6  - Step through CRC_FIELD (16 ticks) -> ACK
//   T7  - Step through ACK (2 ticks) -> EOF
//   T8  - Step through EOF (7 ticks) -> IFS
//   T9  - Step through IFS (3 ticks) -> IDLE
//   T10 - DLC=0: CONTROL boundary stuffing (7 ticks) -> CRC_FIELD (skip DATA)
//   T11 - stuff_error during DATA -> ERROR_FRAME immediately
//   T12 - ERROR_FRAME: 13 ticks stay; 14th -> IFS
//   T13 - clear signal -> IDLE from any state
//   T14 - ARBITRATION & CONTROL bit-by-bit TX serialisation check
//   T15 - Lost arbitration detection (tx_en disabled on bus collision)
//   T16 - Dynamic bit stuffing in ARBITRATION (5 identical bits -> stuff bit)
//   T17 - CRC field bit-by-bit output check for a known frame
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
    logic [63:0] tx_data;
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
        .tx_data     (tx_data),
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
    // Helper: assert bit value and drive enable
    // -------------------------------------------------------------------------
    task automatic check_bit(
        input string label,
        input logic  expected_bit,
        input logic  expected_en
    );
        @(negedge clk);
        tests = tests + 1;
        if (tx_bit_out !== expected_bit || tx_en !== expected_en) begin
            $display("[FAIL] %-45s  expected bit=%b en=%b  got bit=%b en=%b",
                     label, expected_bit, expected_en, tx_bit_out, tx_en);
            errors = errors + 1;
        end else begin
            $display("[PASS] %-45s  bit=%b en=%b", label, tx_bit_out, tx_en);
        end
    endtask

    // -------------------------------------------------------------------------
    // Reference CRC-15/CAN function (mirrors can_crc polynomial 0x4599)
    // Feed one de-stuffed bit at a time. Returns updated CRC.
    // -------------------------------------------------------------------------
    function automatic logic [14:0] crc15_next(
        input logic [14:0] crc,
        input logic        b
    );
        logic fb;
        fb = b ^ crc[14];
        return ({crc[13:0], 1'b0}) ^ (fb ? 15'h4599 : 15'h0000);
    endfunction

    // -------------------------------------------------------------------------
    // Helper: full reset sequence
    // -------------------------------------------------------------------------
    task automatic do_reset;
        @(negedge clk);
        rst_n       = 1'b0;
        bit_tick    = 1'b0;
        sample_point= 1'b0;
        rx_bit      = 1'b1;   // idle bus = recessive
        tx_request  = 1'b0;
        clear       = 1'b0;
        stuff_error = 1'b0;
        crc_ok      = 1'b1;
        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        logic [14:0] ref_crc;   // software reference CRC accumulator

        // ------ default state -----
        rst_n       = 1'b1;
        bit_tick    = 1'b0;
        sample_point= 1'b0;
        rx_bit      = 1'b1;
        tx_request  = 1'b0;
        tx_id       = 11'h0;
        tx_dlc      = 4'd0;
        tx_data     = 64'h0;
        stuff_error = 1'b0;
        crc_ok      = 1'b1;
        clear       = 1'b0;

        // ==================================================================
        // T1 -- reset -> IDLE
        // ==================================================================
        do_reset();
        check_state("T1  reset -> IDLE", ST_IDLE);

        // ==================================================================
        // T2 -- tx_request rising edge -> SOF
        // tx_id = 0x2A5 (010_1010_0101), tx_dlc = 2
        // tx_data = 0xA5A5_... (alternating bits, no stuff in DATA field)
        // ==================================================================
        tx_id      = 11'h2A5;
        tx_dlc     = 4'd2;
        tx_data    = 64'hA5A5A5A5A5A5A5A5; // alternating, no consecutive-5 run
        tx_request = 1'b1;
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
        // T4 -- CONTROL with DLC = 2:
        // RTR(0), IDE(0), r0(0), DLC[3](0), DLC[2](0) = 5 consecutive zeros.
        // Bit stuffer inserts a stuff bit ('1') after DLC[2].
        // Ticks 1..5: first 4 protocol bits + 5th tick stuff bit
        // Tick 6: DLC[1]=1 (still in CONTROL)
        // Tick 7: DLC[0]=0 -> transitions to DATA
        // ==================================================================
        tick_n(5);
        check_state("T4a  5 ticks in CONTROL (4 proto + 1 stuff bit)", ST_CONTROL);

        tick();
        check_state("T4b  6th tick DLC[1]=1 (still CONTROL)", ST_CONTROL);

        tick();
        check_state("T4c  7th tick DLC[0]=0 -> DATA", ST_DATA);

        // ==================================================================
        // T5 -- DLC=2 -> 16 data bits of 0xA5A5 (alternating, no stuffing).
        // 15 ticks stay; 16th -> CRC_FIELD.
        // ==================================================================
        tick_n(15);
        check_state("T5a  15 ticks in DATA (still DATA)", ST_DATA);

        tick();
        check_state("T5b  16th tick -> CRC_FIELD", ST_CRC_FIELD);

        // ==================================================================
        // T6 -- 15 ticks stay in CRC_FIELD; 16th -> ACK
        // (CRC field: 15 CRC bits + 1 delimiter; no stuffing)
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
        // T9 -- 2 ticks stay in IFS; 3rd -> IDLE (tx_request lowered first)
        // ==================================================================
        tx_request = 1'b0;
        tick_n(2);
        check_state("T9a  2 ticks in IFS (still IFS)", ST_IFS);

        tick();
        check_state("T9b  3rd tick -> IDLE (no pending request)", ST_IDLE);

        // ==================================================================
        // T10 -- DLC = 0: CONTROL bit stuffing & transition to CRC_FIELD
        // IDE(0), r0(0), DLC[3:0](0000) -> 5 consecutive 0s triggers
        // a complementary stuff bit ('1') on tick 6. The 7th tick sends
        // DLC[0] ('0') and transitions directly to CRC_FIELD (skips DATA).
        // ==================================================================
        tx_dlc     = 4'd0;
        tx_request = 1'b1;
        @(negedge clk);                         // -> SOF
        tick();                                 // -> ARBITRATION
        tick_n(12);                             // -> CONTROL
        // In CONTROL with DLC=0: 5 ticks for the first 5 zeros
        tick_n(5);
        check_state("T10a  5 ticks CONTROL DLC=0 (still CONTROL)", ST_CONTROL);
        // 6th tick sends stuff bit ('1'), holding FSM in CONTROL
        tick();
        check_state("T10b  6th tick stuff bit (still CONTROL)", ST_CONTROL);
        // 7th tick sends DLC[0] ('0') -> transitions to CRC_FIELD
        tick();
        check_state("T10c  7th tick -> CRC_FIELD", ST_CRC_FIELD);
        // Clean up: step through to IDLE
        tick_n(16); tick_n(2); tick_n(7);
        tx_request = 1'b0;
        tick_n(3);
        check_state("T10d  returned to IDLE after DLC=0 frame", ST_IDLE);

        // ==================================================================
        // T11 -- stuff_error during DATA -> ERROR_FRAME immediately
        // ==================================================================
        tx_dlc     = 4'd8;
        tx_request = 1'b1;
        @(negedge clk);    // -> SOF
        tick();            // -> ARBITRATION
        tick_n(12);        // -> CONTROL
        tick_n(6);         // -> DATA (DLC=8, no boundary stuff for ctrl 1000)
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
        // T14 -- ARBITRATION & CONTROL TX Serialisation bit-by-bit check
        // tx_id = 11'h5A5 (101_1010_0101), tx_dlc = 4'd8 (1000)
        // DLC=8 has no boundary stuffing in CONTROL: {0,0,1,0,0,0} -> max run 3.
        // ==================================================================
        do_reset();
        tx_id      = 11'h5A5;
        tx_dlc     = 4'd8;
        tx_data    = 64'hA5A5A5A5A5A5A5A5;
        tx_request = 1'b1;
        @(negedge clk);   // -> SOF
        tick();           // SOF tick -> enters ARBITRATION, bus holds SOF (0)
        check_state("T14-init  SOF -> ARBITRATION", ST_ARBITRATION);

        // 12 ticks inside ARBITRATION:
        // 0x5A5 = 101_1010_0101
        tick(); check_bit("T14-0  ARB bit 0 ID[10]=1", 1'b1, 1'b1);
        tick(); check_bit("T14-1  ARB bit 1 ID[9]=0",  1'b0, 1'b1);
        tick(); check_bit("T14-2  ARB bit 2 ID[8]=1",  1'b1, 1'b1);
        tick(); check_bit("T14-3  ARB bit 3 ID[7]=1",  1'b1, 1'b1);
        tick(); check_bit("T14-4  ARB bit 4 ID[6]=0",  1'b0, 1'b1);
        tick(); check_bit("T14-5  ARB bit 5 ID[5]=1",  1'b1, 1'b1);
        tick(); check_bit("T14-6  ARB bit 6 ID[4]=0",  1'b0, 1'b1);
        tick(); check_bit("T14-7  ARB bit 7 ID[3]=0",  1'b0, 1'b1);
        tick(); check_bit("T14-8  ARB bit 8 ID[2]=1",  1'b1, 1'b1);
        tick(); check_bit("T14-9  ARB bit 9 ID[1]=0",  1'b0, 1'b1);
        tick(); check_bit("T14-10 ARB bit 10 ID[0]=1", 1'b1, 1'b1);
        tick(); check_bit("T14-11 ARB bit 11 RTR=0",   1'b0, 1'b1);
        check_state("T14-arb  12 ARB ticks complete -> CONTROL", ST_CONTROL);

        // 6 ticks in CONTROL: IDE=0, r0=0, DLC=4'b1000
        tick(); check_bit("T14-ctrl0 IDE=0",    1'b0, 1'b1);
        tick(); check_bit("T14-ctrl1 r0=0",     1'b0, 1'b1);
        tick(); check_bit("T14-ctrl2 DLC[3]=1", 1'b1, 1'b1);
        tick(); check_bit("T14-ctrl3 DLC[2]=0", 1'b0, 1'b1);
        tick(); check_bit("T14-ctrl4 DLC[1]=0", 1'b0, 1'b1);
        tick(); check_bit("T14-ctrl5 DLC[0]=0", 1'b0, 1'b1);
        check_state("T14-ctrl 6 CTRL ticks complete -> DATA", ST_DATA);

        // Clean up to IDLE (DLC=8 -> 64 data bits, no stuffing with 0xA5A5...)
        tick_n(64); tick_n(16); tick_n(2); tick_n(7);
        tx_request = 1'b0;
        tick_n(3);
        check_state("T14-end  returned to IDLE", ST_IDLE);

        // ==================================================================
        // T15 -- Lost Arbitration Detection
        // Node transmits tx_id = 11'h6A5 (110_1010_0101), tx_dlc = 4'd8.
        // On bit 9 (recessive 1), external node drives rx_bit = 0.
        // Node must detect arbitration loss, drop tx_en to 0, and continue
        // as receiver.
        // ==================================================================
        do_reset();
        tx_id      = 11'h6A5;
        tx_dlc     = 4'd8;
        tx_data    = 64'hA5A5A5A5A5A5A5A5;
        tx_request = 1'b1;
        @(negedge clk);
        tick(); // -> ARBITRATION
        // Bit 10: ID[10] = 1. rx_bit matches (1).
        tick();
        sample_point = 1'b1; @(negedge clk); sample_point = 1'b0;
        check_bit("T15a  ID[10]=1 driving bus", 1'b1, 1'b1);

        // Bit 9: ID[9] = 1. External bus pulls dominant (rx_bit = 0).
        tick();
        rx_bit = 1'b0;
        sample_point = 1'b1; @(negedge clk); sample_point = 1'b0;
        // Lost arbitration: tx_en must drop to 0
        check_bit("T15b  lost arb: tx_en disabled", 1'b1, 1'b0);

        // Finish remaining arbitration as receiver (10 ticks)
        rx_bit = 1'b1;
        tick_n(10);
        check_state("T15c  after ARB -> CONTROL as listener", ST_CONTROL);
        tick_n(6); tick_n(64); tick_n(16); tick_n(2); tick_n(7);
        tx_request = 1'b0;
        tick_n(3);
        check_state("T15d  listener returned to IDLE", ST_IDLE);

        // ==================================================================
        // T16 -- Dynamic Bit Stuffing in ARBITRATION
        // tx_id = 11'h7D5 (111_1101_0101), tx_dlc = 4'd8
        // ID[10..6] are five consecutive 1s. Bit stuffer must insert
        // a dominant stuff bit ('0') at tick 6 and extend ARBITRATION to 13 ticks.
        // ==================================================================
        do_reset();
        tx_id      = 11'h7D5;
        tx_dlc     = 4'd8;
        tx_data    = 64'hA5A5A5A5A5A5A5A5;
        tx_request = 1'b1;
        @(negedge clk);
        tick(); // SOF -> enters ARBITRATION
        // First 5 bits of ARBITRATION (five 1s)
        tick(); check_bit("T16-1  ID[10]=1", 1'b1, 1'b1);
        tick(); check_bit("T16-2  ID[9]=1",  1'b1, 1'b1);
        tick(); check_bit("T16-3  ID[8]=1",  1'b1, 1'b1);
        tick(); check_bit("T16-4  ID[7]=1",  1'b1, 1'b1);
        tick(); check_bit("T16-5  ID[6]=1 (5th one)", 1'b1, 1'b1);
        // Tick 6: bit stuffer inserts dominant stuff bit ('0')
        tick();
        check_bit("T16-stuff  dominant stuff bit inserted", 1'b0, 1'b1);
        check_state("T16-hold   stuff bit holds in ARBITRATION", ST_ARBITRATION);
        // Tick 7: ID[5] = 0 sent
        tick(); check_bit("T16-6  ID[5]=0", 1'b0, 1'b1);
        // Remaining 6 bits: ID[4]=1, ID[3]=0, ID[2]=1, ID[1]=0, ID[0]=1, RTR=0
        tick_n(6);
        check_state("T16-end  after 13 ticks -> CONTROL", ST_CONTROL);
        // Clean up to IDLE
        tick_n(6); tick_n(64); tick_n(16); tick_n(2); tick_n(7);
        tx_request = 1'b0;
        tick_n(3);
        check_state("T16-idle returned to IDLE", ST_IDLE);

        // ==================================================================
        // T17 -- CRC field bit-by-bit output check
        //
        // Frame: tx_id=0x1A5 (000_1101_0101), tx_dlc=1, tx_data=0xA5 (byte 0).
        // tx_id=0x1A5 chosen because it has no five-consecutive-same in ARB+CTRL
        // and no boundary stuff issues with DLC=1 (0001).
        //
        // Compute reference CRC over (de-stuffed bits):
        //   SOF(0) + ID[10:0] + RTR(0) + IDE(0) + r0(0) + DLC(0001) + DATA(0xA5)
        // Then verify the CRC_FIELD outputs those 15 bits MSB-first + delimiter.
        // ==================================================================
        do_reset();
        tx_id      = 11'h1A5;  // 000_1101_0101 -- no 5-consecutive run
        tx_dlc     = 4'd1;
        tx_data    = 64'hA500000000000000;  // byte 0 = 0xA5, rest unused
        tx_request = 1'b1;

        // Build reference CRC over the unstuffed frame bits
        ref_crc = 15'h0000;
        // SOF
        ref_crc = crc15_next(ref_crc, 1'b0);
        // ID 0x1A5 = 0_0011_0101_01 MSB first
        ref_crc = crc15_next(ref_crc, 1'b0); // ID[10]=0
        ref_crc = crc15_next(ref_crc, 1'b0); // ID[9]=0
        ref_crc = crc15_next(ref_crc, 1'b0); // ID[8]=0
        ref_crc = crc15_next(ref_crc, 1'b1); // ID[7]=1
        ref_crc = crc15_next(ref_crc, 1'b1); // ID[6]=1
        ref_crc = crc15_next(ref_crc, 1'b0); // ID[5]=0
        ref_crc = crc15_next(ref_crc, 1'b1); // ID[4]=1
        ref_crc = crc15_next(ref_crc, 1'b0); // ID[3]=0
        ref_crc = crc15_next(ref_crc, 1'b1); // ID[2]=1
        ref_crc = crc15_next(ref_crc, 1'b0); // ID[1]=0
        ref_crc = crc15_next(ref_crc, 1'b1); // ID[0]=1
        // RTR, IDE, r0
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b0);
        // DLC = 0001
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b1);
        // DATA byte 0 = 0xA5 = 1010_0101 (MSB first)
        ref_crc = crc15_next(ref_crc, 1'b1);
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b1);
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b1);
        ref_crc = crc15_next(ref_crc, 1'b0);
        ref_crc = crc15_next(ref_crc, 1'b1);

        $display("T17  reference CRC-15 = 0x%04h (%015b)", ref_crc, ref_crc);

        // Drive the frame through SOF -> ARBITRATION -> CONTROL -> DATA -> CRC_FIELD
        @(negedge clk);   // -> SOF
        tick();           // -> ARBITRATION (no stuffing: SOF=0, first ARB bits are 000...)
        tick_n(12);       // -> CONTROL (12 arb bits: 000_1101_0101 + RTR=0)
        // CONTROL for DLC=1 (0001): bits = IDE(0),r0(0),DLC(0001)
        // Runs: 00 (2) then 0001 -> max run crossing boundary from ARB:
        // Last ARB bit = RTR=0. CTRL: 0,0,0,0,0,1. Five consecutive zeros -> stuff bit!
        // Ticks 1-5: first 4 ctrl bits + stuff, tick 6: DLC[0]=1, tick 7: exits to DATA? No.
        // Wait - actually CTRL = IDE(0), r0(0), DLC[3](0), DLC[2](0), DLC[1](0), DLC[0](1)
        // Last ARB bit (RTR=0) carries into CTRL run. After the stuff tick (6th), DLC[0]=1 exits CONTROL.
        // But the transition is after DLC[0], so 7th tick takes us to DATA.
        tick_n(6);        // 5 ctrl bits (incl. stuff) + DLC[1]=0 (still in CONTROL)
        tick();           // 7th: DLC[0]=1 -> DATA (DLC=1, 8 bits)
        check_state("T17-setup  entered DATA (DLC=1)", ST_DATA);
        tick_n(7);        // 7 data bits (still in DATA)
        tick();           // 8th data bit -> CRC_FIELD
        check_state("T17-crc_entry  entered CRC_FIELD", ST_CRC_FIELD);

        // Wait one extra clock for crc_shift to be latched from crc_computed
        @(negedge clk); @(negedge clk);

        // Now verify each of the 15 CRC bits MSB-first
        begin : crc_check_loop
            logic [14:0] expected_shift;
            int i;
            expected_shift = ref_crc;
            for (i = 14; i >= 0; i = i - 1) begin
                tick();
                @(negedge clk);
                tests = tests + 1;
                if (tx_bit_out !== expected_shift[14]) begin
                    $display("[FAIL] T17-crc[%0d]  expected=%b  got=%b",
                             i, expected_shift[14], tx_bit_out);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] T17-crc[%0d]  bit=%b", i, tx_bit_out);
                end
                expected_shift = {expected_shift[13:0], 1'b0};
            end
        end

        // 16th tick = CRC delimiter (must be recessive = 1'b1)
        tick();
        @(negedge clk);
        tests = tests + 1;
        if (tx_bit_out !== 1'b1) begin
            $display("[FAIL] T17-delim  CRC delimiter expected=1  got=%b", tx_bit_out);
            errors = errors + 1;
        end else begin
            $display("[PASS] T17-delim  CRC delimiter=1");
        end
        check_state("T17-ack  after CRC_FIELD -> ACK", ST_ACK);

        // Clean up to IDLE
        tick_n(2); tick_n(7);
        tx_request = 1'b0;
        tick_n(3);
        check_state("T17-end  returned to IDLE", ST_IDLE);

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
