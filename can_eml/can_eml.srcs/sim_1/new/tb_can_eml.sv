//=============================================================================
// Testbench   : tb_can_eml
// Description : Self-checking testbench for CAN Error Management Logic (can_eml).
//
// Tests:
//   T1  - Power-on / async reset default state
//   T2  - Transmitter: Bit Error (TEC +8)
//   T3  - Transmitter: Stuff Error (TEC +8)
//   T4  - Transmitter: Form Error (TEC +8)
//   T5  - Transmitter: ACK Error (TEC +8)
//   T6  - Receiver: Stuff Error (REC +1)
//   T7  - Receiver: Form Error (REC +1)
//   T8  - Receiver: CRC Error (REC +1)
//   T9  - Error Warning Limit threshold (TEC >= 96)
//   T10 - Error-Active -> Error-Passive transition via TEC (> 127)
//   T11 - Error-Active -> Error-Passive transition via REC (> 127)
//   T12 - Successful Transmission Decrements TEC (-1) to 0, no underflow
//   T13 - Successful Reception Decrements REC (-1) to 0, no underflow
//   T14 - Error-Passive -> Bus-Off Transition (TEC > 255)
//   T15 - Bus-Off Invariance (further errors ignored while in Bus-Off)
//   T16 - Bus-Off Recovery (bus_off_recovery -> Error-Active, TEC=0, REC=0)
//   T17 - Return from Error-Passive to Error-Active on TX Success (TEC: 128 -> 127)
//=============================================================================

`timescale 1ns/1ps

module tb_can_eml;

    // Clock and reset
    logic        clk;
    logic        rst_n;
    logic        clear;

    // Role
    logic        is_transmitter;

    // Error pulses
    logic        bit_error;
    logic        stuff_error;
    logic        crc_error;
    logic        ack_error;
    logic        form_error;

    // Success pulses
    logic        tx_success;
    logic        rx_success;

    // Recovery
    logic        bus_off_recovery;

    // Outputs
    logic [7:0]  tec;
    logic [7:0]  rec;
    logic [1:0]  node_state;
    logic        error_active;
    logic        error_passive;
    logic        bus_off;
    logic        error_warning;

    // Test counters
    int tests  = 0;
    int errors = 0;

    // Instantiate DUT
    can_eml u_eml (
        .clk              (clk),
        .rst_n            (rst_n),
        .clear            (clear),
        .is_transmitter   (is_transmitter),
        .bit_error        (bit_error),
        .stuff_error      (stuff_error),
        .crc_error        (crc_error),
        .ack_error        (ack_error),
        .form_error       (form_error),
        .tx_success       (tx_success),
        .rx_success       (rx_success),
        .bus_off_recovery (bus_off_recovery),
        .tec              (tec),
        .rec              (rec),
        .node_state       (node_state),
        .error_active     (error_active),
        .error_passive    (error_passive),
        .bus_off          (bus_off),
        .error_warning    (error_warning)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Helper tasks
    // -------------------------------------------------------------------------
    task automatic do_reset;
        @(negedge clk);
        rst_n            = 1'b0;
        clear            = 1'b0;
        is_transmitter   = 1'b1;
        bit_error        = 1'b0;
        stuff_error      = 1'b0;
        crc_error        = 1'b0;
        ack_error        = 1'b0;
        form_error       = 1'b0;
        tx_success       = 1'b0;
        rx_success       = 1'b0;
        bus_off_recovery = 1'b0;
        @(negedge clk);
        rst_n            = 1'b1;
        @(negedge clk);
    endtask

    task automatic check_state(
        input string       label,
        input logic [7:0]  exp_tec,
        input logic [7:0]  exp_rec,
        input logic [1:0]  exp_state,
        input logic        exp_act,
        input logic        exp_pas,
        input logic        exp_bo,
        input logic        exp_warn
    );
        tests = tests + 1;
        if (tec !== exp_tec || rec !== exp_rec || node_state !== exp_state ||
            error_active !== exp_act || error_passive !== exp_pas ||
            bus_off !== exp_bo || error_warning !== exp_warn) begin
            $display("[FAIL] %-48s  exp tec=%0d rec=%0d st=%0d act=%b pas=%b bo=%b warn=%b | got tec=%0d rec=%0d st=%0d act=%b pas=%b bo=%b warn=%b",
                     label, exp_tec, exp_rec, exp_state, exp_act, exp_pas, exp_bo, exp_warn,
                     tec, rec, node_state, error_active, error_passive, bus_off, error_warning);
            errors = errors + 1;
        end else begin
            $display("[PASS] %-48s  tec=%0d rec=%0d state=%0d", label, tec, rec, node_state);
        end
    endtask

    // Pulse a 1-cycle signal on posedge clk
    task automatic pulse_signal(ref logic sig);
        @(negedge clk);
        sig = 1'b1;
        @(negedge clk);
        sig = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        int i;

        $display("");
        $display("====================================================================");
        $display("   CAN ERROR MANAGEMENT LOGIC (EML) UNIT TESTBENCH (Day 22-23)");
        $display("====================================================================");

        // ---------------------------------------------------------------------
        // T1: Reset default state
        // ---------------------------------------------------------------------
        do_reset();
        check_state("T1  Reset condition", 8'd0, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T2: Transmitter Bit Error (+8)
        // ---------------------------------------------------------------------
        is_transmitter = 1'b1;
        pulse_signal(bit_error);
        check_state("T2  TX bit_error -> TEC=8", 8'd8, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T3: Transmitter Stuff Error (+8)
        // ---------------------------------------------------------------------
        pulse_signal(stuff_error);
        check_state("T3  TX stuff_error -> TEC=16", 8'd16, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T4: Transmitter Form Error (+8)
        // ---------------------------------------------------------------------
        pulse_signal(form_error);
        check_state("T4  TX form_error -> TEC=24", 8'd24, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T5: Transmitter ACK Error (+8)
        // ---------------------------------------------------------------------
        pulse_signal(ack_error);
        check_state("T5  TX ack_error -> TEC=32", 8'd32, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T6: Receiver Stuff Error (+1)
        // ---------------------------------------------------------------------
        is_transmitter = 1'b0;
        pulse_signal(stuff_error);
        check_state("T6  RX stuff_error -> REC=1", 8'd32, 8'd1, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T7: Receiver Form Error (+1)
        // ---------------------------------------------------------------------
        pulse_signal(form_error);
        check_state("T7  RX form_error -> REC=2", 8'd32, 8'd2, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T8: Receiver CRC Error (+1)
        // ---------------------------------------------------------------------
        pulse_signal(crc_error);
        check_state("T8  RX crc_error -> REC=3", 8'd32, 8'd3, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T9: Error Warning Limit (TEC >= 96)
        // Currently TEC=32. Need 8 more errors of +8: 32 + 64 = 96.
        // ---------------------------------------------------------------------
        is_transmitter = 1'b1;
        for (i = 0; i < 7; i = i + 1) begin
            pulse_signal(bit_error);
        end
        // At 88, warning is still 0
        check_state("T9a TEC=88 -> warning=0", 8'd88, 8'd3, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);
        pulse_signal(bit_error); // TEC reaches 96
        check_state("T9b TEC=96 -> warning=1", 8'd96, 8'd3, 2'b00, 1'b1, 1'b0, 1'b0, 1'b1);

        // ---------------------------------------------------------------------
        // T10: Error-Active -> Error-Passive via TEC (> 127)
        // Currently TEC=96. 4 more errors -> 96 + 32 = 128.
        // ---------------------------------------------------------------------
        for (i = 0; i < 4; i = i + 1) begin
            pulse_signal(bit_error);
        end
        check_state("T10 TEC=128 -> ERROR_PASSIVE", 8'd128, 8'd3, 2'b01, 1'b0, 1'b1, 1'b0, 1'b1);

        // ---------------------------------------------------------------------
        // T11: Error-Active -> Error-Passive via REC (> 127)
        // Reset node, then inject 128 RX errors.
        // ---------------------------------------------------------------------
        do_reset();
        is_transmitter = 1'b0;
        for (i = 0; i < 127; i = i + 1) begin
            pulse_signal(crc_error);
        end
        check_state("T11a REC=127 -> still ERROR_ACTIVE", 8'd0, 8'd127, 2'b00, 1'b1, 1'b0, 1'b0, 1'b1);
        pulse_signal(crc_error); // REC reaches 128
        check_state("T11b REC=128 -> ERROR_PASSIVE", 8'd0, 8'd128, 2'b01, 1'b0, 1'b1, 1'b0, 1'b1);

        // ---------------------------------------------------------------------
        // T12: Successful Transmission Decrements TEC (-1), no underflow below 0
        // ---------------------------------------------------------------------
        do_reset();
        is_transmitter = 1'b1;
        pulse_signal(bit_error); // TEC = 8
        check_state("T12a TEC=8 after error", 8'd8, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);
        for (i = 0; i < 8; i = i + 1) begin
            pulse_signal(tx_success);
        end
        check_state("T12b 8x tx_success -> TEC=0", 8'd0, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);
        // Extra tx_success must not underflow
        pulse_signal(tx_success);
        check_state("T12c extra tx_success -> TEC stays 0", 8'd0, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T13: Successful Reception Decrements REC (-1), no underflow below 0
        // ---------------------------------------------------------------------
        is_transmitter = 1'b0;
        for (i = 0; i < 5; i = i + 1) begin
            pulse_signal(crc_error);
        end
        check_state("T13a REC=5 after errors", 8'd0, 8'd5, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);
        for (i = 0; i < 5; i = i + 1) begin
            pulse_signal(rx_success);
        end
        check_state("T13b 5x rx_success -> REC=0", 8'd0, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);
        // Extra rx_success must not underflow
        pulse_signal(rx_success);
        check_state("T13c extra rx_success -> REC stays 0", 8'd0, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T14: Error-Passive -> Bus-Off Transition (TEC > 255)
        // 31 errors * 8 = 248. Next error -> 256 -> BUS_OFF.
        // ---------------------------------------------------------------------
        do_reset();
        is_transmitter = 1'b1;
        for (i = 0; i < 31; i = i + 1) begin
            pulse_signal(bit_error);
        end
        check_state("T14a TEC=248 -> ERROR_PASSIVE", 8'd248, 8'd0, 2'b01, 1'b0, 1'b1, 1'b0, 1'b1);
        pulse_signal(bit_error); // TEC reaches 256 -> BUS_OFF
        check_state("T14b TEC=256 -> BUS_OFF", 8'hFF, 8'd0, 2'b10, 1'b0, 1'b0, 1'b1, 1'b1);

        // ---------------------------------------------------------------------
        // T15: Invariance in Bus-Off (further errors ignored)
        // ---------------------------------------------------------------------
        pulse_signal(bit_error);
        pulse_signal(ack_error);
        check_state("T15  Errors in BUS_OFF do not wrap", 8'hFF, 8'd0, 2'b10, 1'b0, 1'b0, 1'b1, 1'b1);

        // ---------------------------------------------------------------------
        // T16: Bus-Off Recovery (bus_off_recovery -> ERROR_ACTIVE, TEC=0, REC=0)
        // ---------------------------------------------------------------------
        pulse_signal(bus_off_recovery);
        check_state("T16  bus_off_recovery -> ERROR_ACTIVE", 8'd0, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);

        // ---------------------------------------------------------------------
        // T17: Return from Error-Passive to Active on TX Success (TEC: 128 -> 127)
        // ---------------------------------------------------------------------
        for (i = 0; i < 16; i = i + 1) begin
            pulse_signal(bit_error);
        end
        check_state("T17a TEC=128 -> ERROR_PASSIVE", 8'd128, 8'd0, 2'b01, 1'b0, 1'b1, 1'b0, 1'b1);
        pulse_signal(tx_success);
        check_state("T17b tx_success -> TEC=127 -> ERROR_ACTIVE", 8'd127, 8'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b1);

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        $display("--------------------------------------------------------------------");
        if (errors == 0)
            $display("ALL %0d CAN EML TESTS PASSED", tests);
        else
            $display("%0d / %0d CAN EML TESTS FAILED", errors, tests);
        $display("--------------------------------------------------------------------");

        #100;
        $finish;
    end

endmodule
