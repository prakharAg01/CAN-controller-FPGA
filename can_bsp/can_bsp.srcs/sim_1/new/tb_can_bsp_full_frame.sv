//=============================================================================
// Testbench   : tb_can_bsp_full_frame
// Description : Dedicated standalone testbench for full CAN 2.0A frame
//               transmission and bit-for-bit verification in simulation waveforms.
//
// Frame Configuration:
//   Standard 11-bit ID : 0x1A5  (001_1010_0101)
//   DLC                : 1 byte
//   Data Byte 0        : 0xA5   (1010_0101)
//   Calculated CRC-15  : 0x5617 (101_0110_0001_0111)
//   Bit Stuffing       : 1 stuff bit in CONTROL after DLC[2]
//   Total Bit Times    : 56 bit-times (SOF to IFS[2]) -> IDLE
//=============================================================================

`timescale 1ns/1ps

module tb_can_bsp_full_frame;

    // DUT interface signals
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
    logic        ack_error;
    logic        form_error;
    logic        rx_data_bit;
    logic        rx_data_valid;
    logic        rx_stuff_error;
    logic        error_out;
    logic [3:0]  state_out;

    // Verification statistics
    int tests  = 0;
    int errors = 0;

    // Instantiate DUT
    can_bsp u_bsp (
        .clk           (clk),
        .rst_n         (rst_n),
        .clear         (clear),
        .bit_tick      (bit_tick),
        .sample_point  (sample_point),
        .rx_bit        (rx_bit),
        .tx_request    (tx_request),
        .tx_id         (tx_id),
        .tx_dlc        (tx_dlc),
        .tx_data       (tx_data),
        .stuff_error   (stuff_error),
        .crc_ok        (crc_ok),
        .tx_bit        (tx_bit_out),
        .tx_en         (tx_en),
        .frame_active  (frame_active),
        .ack_error     (ack_error),
        .form_error    (form_error),
        .rx_data_bit   (rx_data_bit),
        .rx_data_valid (rx_data_valid),
        .rx_stuff_error(rx_stuff_error),
        .error_out     (error_out),
        .state_out     (state_out)
    );

    // 100 MHz clock (10 ns period)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Helper: issue one bit_tick strobe (one CAN bit time)
    task automatic tick;
        @(negedge clk);
        bit_tick = 1'b1;
        @(negedge clk);
        bit_tick = 1'b0;
    endtask

    // State names helper
    function automatic string get_state_name(input logic [3:0] st);
        case (st)
            4'd0: return "IDLE";
            4'd1: return "SOF";
            4'd2: return "ARBITRATION";
            4'd3: return "CONTROL";
            4'd4: return "DATA";
            4'd5: return "CRC_FIELD";
            4'd6: return "ACK";
            4'd7: return "EOF";
            4'd8: return "IFS";
            4'd9: return "ERROR_FRAME";
            default: return "UNKNOWN";
        endcase
    endfunction

    // Field names helper
    function automatic string get_field_name(input int idx);
        case (idx)
            0:  return "SOF";
            1:  return "ID[10]";
            2:  return "ID[9]";
            3:  return "ID[8]";
            4:  return "ID[7]";
            5:  return "ID[6]";
            6:  return "ID[5]";
            7:  return "ID[4]";
            8:  return "ID[3]";
            9:  return "ID[2]";
            10: return "ID[1]";
            11: return "ID[0]";
            12: return "RTR";
            13: return "IDE";
            14: return "r0";
            15: return "DLC[3]";
            16: return "DLC[2]";
            17: return "STUFF(after DLC[2])";
            18: return "DLC[1]";
            19: return "DLC[0]";
            20: return "DATA0[7]";
            21: return "DATA0[6]";
            22: return "DATA0[5]";
            23: return "DATA0[4]";
            24: return "DATA0[3]";
            25: return "DATA0[2]";
            26: return "DATA0[1]";
            27: return "DATA0[0]";
            28: return "CRC[14]";
            29: return "CRC[13]";
            30: return "CRC[12]";
            31: return "CRC[11]";
            32: return "CRC[10]";
            33: return "CRC[9]";
            34: return "CRC[8]";
            35: return "CRC[7]";
            36: return "CRC[6]";
            37: return "CRC[5]";
            38: return "CRC[4]";
            39: return "CRC[3]";
            40: return "CRC[2]";
            41: return "CRC[1]";
            42: return "CRC[0]";
            43: return "CRC_DELIM";
            44: return "ACK_SLOT";
            45: return "ACK_DELIM";
            46: return "EOF[0]";
            47: return "EOF[1]";
            48: return "EOF[2]";
            49: return "EOF[3]";
            50: return "EOF[4]";
            51: return "EOF[5]";
            52: return "EOF[6]";
            53: return "IFS[0]";
            54: return "IFS[1]";
            55: return "IFS[2]";
            default: return "UNKNOWN";
        endcase
    endfunction

    // Main verification sequence
    initial begin
        logic [55:0] golden_tx_bit;
        logic [55:0] golden_tx_en;
        logic [55:0] golden_fa;
        logic        exp_bit;
        logic        exp_en;
        logic        exp_fa;
        bit          step_ok;
        int          step;

        golden_tx_bit = 56'h1A505A5AC2FFFF;
        golden_tx_en  = 56'hFFFFFFFFFFE000;
        golden_fa     = 56'hFFFFFFFFFFFFF0;

        // Initialize signals
        rst_n        = 1'b0;
        bit_tick     = 1'b0;
        sample_point = 1'b0;
        rx_bit       = 1'b1; // Bus recessive when idle
        tx_request   = 1'b0;
        tx_id        = 11'h1A5;
        tx_dlc       = 4'd1;
        tx_data      = 64'hA500000000000000;
        clear        = 1'b0;
        stuff_error  = 1'b0;
        crc_ok       = 1'b1;

        // Reset pulse
        #20;
        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        $display("");
        $display("==========================================================================================");
        $display("   CAN BSP FULL-FRAME STANDALONE SIMULATION TESTBENCH (Day 20-21)");
        $display("   Frame: ID=0x1A5 (11-bit), DLC=1, DATA0=0xA5, Computed CRC-15=0x5617");
        $display("==========================================================================================");
        $display("| Step | Field Name           | State        | tx_bit (exp/got) | tx_en (exp/got) | fa (exp/got) | Status |");
        $display("|------|----------------------|--------------|------------------|-----------------|--------------|--------|");

        // Request frame transmission
        tx_request = 1'b1;
        @(negedge clk); // FSM transitions IDLE -> SOF
        tx_request = 1'b0; // Single frame transmission: deassert request once initiated

        // Step through all 56 bit-times
        for (step = 0; step < 56; step = step + 1) begin
            tick();

            // At Step 43 (first tick in ACK state, after CRC_DELIM):
            // Emulate receiver placing dominant bit on bus at sample point
            if (step == 43) begin
                @(negedge clk);
                rx_bit       = 1'b0; // Dominant ACK from external node
                sample_point = 1'b1;
                @(negedge clk);
                sample_point = 1'b0;
                rx_bit       = 1'b1; // Bus returns to recessive
            end

            // Check bit output, enable, and frame active
            @(negedge clk);
            exp_bit = golden_tx_bit[55];
            exp_en  = golden_tx_en[55];
            exp_fa  = golden_fa[55];

            tests = tests + 1;
            step_ok = (tx_bit_out === exp_bit) && (tx_en === exp_en) && (frame_active === exp_fa);

            if (!step_ok) begin
                errors = errors + 1;
                $display("|  %02d  | %-20s | %-12s |      %b / %b       |      %b / %b      |    %b / %b     | [FAIL] |",
                         step, get_field_name(step), get_state_name(state_out),
                         exp_bit, tx_bit_out, exp_en, tx_en, exp_fa, frame_active);
            end else begin
                $display("|  %02d  | %-20s | %-12s |      %b / %b       |      %b / %b      |    %b / %b     | [PASS] |",
                         step, get_field_name(step), get_state_name(state_out),
                         exp_bit, tx_bit_out, exp_en, tx_en, exp_fa, frame_active);
            end

            golden_tx_bit = {golden_tx_bit[54:0], 1'b0};
            golden_tx_en  = {golden_tx_en[54:0],  1'b0};
            golden_fa     = {golden_fa[54:0],   1'b0};
        end

        $display("------------------------------------------------------------------------------------------");
        // Verify final state and clean termination
        tests = tests + 1;
        if (state_out !== 4'd0) begin // ST_IDLE
            $display("[FAIL] Final state expected IDLE (0), got %0d", state_out);
            errors = errors + 1;
        end else begin
            $display("[PASS] Final state cleanly returned to IDLE (0)");
        end

        tests = tests + 1;
        if (ack_error !== 1'b0) begin
            $display("[FAIL] ACK error flag asserted: %b", ack_error);
            errors = errors + 1;
        end else begin
            $display("[PASS] ACK received successfully without error (ack_error = 0)");
        end

        tests = tests + 1;
        if (form_error !== 1'b0) begin
            $display("[FAIL] Form error flag asserted: %b", form_error);
            errors = errors + 1;
        end else begin
            $display("[PASS] No form error detected across entire frame (form_error = 0)");
        end

        $display("==========================================================================================");
        if (errors == 0) begin
            $display("   RESULT: ALL %0d FULL-FRAME VERIFICATION CHECKS PASSED BIT-FOR-BIT!", tests);
        end else begin
            $display("   RESULT: %0d / %0d CHECKS FAILED!", errors, tests);
        end
        $display("==========================================================================================");

        #100;
        $finish;
    end

endmodule
