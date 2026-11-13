// =============================================================================
// Testbench : tb_can_regs
// Tests     : T1-T6 (Self-checking, registers, commands, status, IRQ)
// Day 26    : Register Interface
// =============================================================================
`timescale 1ns/1ps

module tb_can_regs;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic        clk, rst_n;

    // Host Register Bus
    logic        reg_cs;
    logic        reg_we;
    logic [7:0]  reg_addr;
    logic [31:0] reg_wdata;
    logic [31:0] reg_rdata;
    logic        reg_ack;
    logic        irq_out;

    // Submodule Control Outputs
    logic        soft_reset, loopback_en, listen_only, abort_tx, bus_off_rec;
    logic [7:0]  btr_brp;
    logic [3:0]  btr_tseg1;
    logic [2:0]  btr_tseg2;
    logic [1:0]  btr_sjw;
    logic [10:0] filter_id, filter_mask;
    logic        tx_write;
    logic [10:0] tx_id;
    logic        tx_rtr;
    logic [3:0]  tx_dlc;
    logic [63:0] tx_data;
    logic        rx_pop, rx_clear;

    // Submodule Status Inputs
    logic        tx_ready, tx_busy, tx_done_pulse;
    logic        rx_empty, rx_full, rx_almost_full, rx_overrun;
    logic [4:0]  rx_count;
    logic [10:0] rx_out_id;
    logic        rx_out_rtr;
    logic [3:0]  rx_out_dlc;
    logic [63:0] rx_out_data;
    logic        rx_valid_pulse;
    logic [7:0]  tec, rec;
    logic [1:0]  node_state;
    logic        error_warning, bus_off;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    can_regs dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .reg_cs        (reg_cs),
        .reg_we        (reg_we),
        .reg_addr      (reg_addr),
        .reg_wdata     (reg_wdata),
        .reg_rdata     (reg_rdata),
        .reg_ack       (reg_ack),
        .irq_out       (irq_out),
        .soft_reset    (soft_reset),
        .loopback_en   (loopback_en),
        .listen_only   (listen_only),
        .abort_tx      (abort_tx),
        .bus_off_rec   (bus_off_rec),
        .btr_brp       (btr_brp),
        .btr_tseg1     (btr_tseg1),
        .btr_tseg2     (btr_tseg2),
        .btr_sjw       (btr_sjw),
        .filter_id     (filter_id),
        .filter_mask   (filter_mask),
        .tx_write      (tx_write),
        .tx_id         (tx_id),
        .tx_rtr        (tx_rtr),
        .tx_dlc        (tx_dlc),
        .tx_data       (tx_data),
        .rx_pop        (rx_pop),
        .rx_clear      (rx_clear),
        .tx_ready      (tx_ready),
        .tx_busy       (tx_busy),
        .tx_done_pulse (tx_done_pulse),
        .rx_empty      (rx_empty),
        .rx_full       (rx_full),
        .rx_almost_full(rx_almost_full),
        .rx_overrun    (rx_overrun),
        .rx_count      (rx_count),
        .rx_out_id     (rx_out_id),
        .rx_out_rtr    (rx_out_rtr),
        .rx_out_dlc    (rx_out_dlc),
        .rx_out_data   (rx_out_data),
        .rx_valid_pulse(rx_valid_pulse),
        .tec           (tec),
        .rec           (rec),
        .node_state    (node_state),
        .error_warning (error_warning),
        .bus_off       (bus_off)
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    // -------------------------------------------------------------------------
    // Bus Access Tasks
    // -------------------------------------------------------------------------
    task write_reg(input [7:0] addr, input [31:0] data);
        @(posedge clk); #1;
        reg_addr  = addr;
        reg_wdata = data;
        reg_we    = 1'b1;
        reg_cs    = 1'b1;
        @(posedge clk);
        while (!reg_ack) @(posedge clk);
        #1;
        reg_cs    = 1'b0;
        reg_we    = 1'b0;
    endtask

    task read_reg(input [7:0] addr, output [31:0] data);
        @(posedge clk); #1;
        reg_addr  = addr;
        reg_we    = 1'b0;
        reg_cs    = 1'b1;
        @(posedge clk);
        while (!reg_ack) @(posedge clk);
        #1;
        data      = reg_rdata;
        reg_cs    = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Scoreboard
    // -------------------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0;

    task check32(input string name, input [31:0] got, input [31:0] exp);
        if (got === exp) begin
            $display("[PASS] %s = 0x%08X", name, got);
            pass_cnt++;
        end else begin
            $error("[FAIL] %s : got=0x%08X exp=0x%08X", name, got, exp);
            fail_cnt++;
        end
    endtask

    task check_bit(input string name, input logic got, input logic exp);
        if (got === exp) begin
            $display("[PASS] %s = %0b", name, got);
            pass_cnt++;
        end else begin
            $error("[FAIL] %s : got=%0b exp=%0b", name, got, exp);
            fail_cnt++;
        end
    endtask

    logic [31:0] rval;

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        // Initialize inputs
        rst_n = 0;
        reg_cs = 0; reg_we = 0; reg_addr = 0; reg_wdata = 0;
        tx_ready = 1; tx_busy = 0; tx_done_pulse = 0;
        rx_empty = 1; rx_full = 0; rx_almost_full = 0; rx_overrun = 0; rx_count = 0;
        rx_out_id = 0; rx_out_rtr = 0; rx_out_dlc = 0; rx_out_data = 0; rx_valid_pulse = 0;
        tec = 0; rec = 0; node_state = 0; error_warning = 0; bus_off = 0;

        // Reset Pulse
        #20;
        @(posedge clk); #1;
        rst_n = 1;
        @(posedge clk); #1;

        // =====================================================================
        // T1: Default Reset State
        // =====================================================================
        $display("--- T1: Default Reset State ---");
        read_reg(8'h00, rval); // MODECR
        check32("T1_MODECR_default", rval, 32'h00000001); // Bit 0 (reset mode) must be 1
        check_bit("T1_soft_reset_pin", soft_reset, 1'b1);

        read_reg(8'h10, rval); // BTR default: SJW=1, TSEG2=3, TSEG1=4, BRP=1 -> 0x00013401
        check32("T1_BTR_default", rval, 32'h00013401);

        read_reg(8'h08, rval); // Status Register (tx_ready=1, rx_empty=1 -> bit 1 and bit 2 = 1) -> 0x06
        check32("T1_SR_default", rval, 32'h00000006);
        $display("[PASS] T1");

        // =====================================================================
        // T2: Read/Write Configuration Registers
        // =====================================================================
        $display("--- T2: R/W Configuration Registers ---");
        // Configure BTR: BRP=3, TSEG1=8, TSEG2=5, SJW=2 -> 0x00025803
        write_reg(8'h10, 32'h00025803);
        read_reg(8'h10, rval);
        check32("T2_BTR_readback", rval, 32'h00025803);
        check_bit("T2_btr_brp", (btr_brp === 8'd3), 1'b1);
        check_bit("T2_btr_tseg1", (btr_tseg1 === 4'd8), 1'b1);

        // Configure Acceptance Filter ID and Mask
        write_reg(8'h14, 32'h0000035A); // Filter ID = 0x35A
        write_reg(8'h18, 32'h000007FF); // Filter Mask = 0x7FF
        read_reg(8'h14, rval);
        check32("T2_AFID_readback", rval, 32'h0000035A);
        read_reg(8'h18, rval);
        check32("T2_AFMSK_readback", rval, 32'h000007FF);
        check_bit("T2_filter_id_pin", (filter_id === 11'h35A), 1'b1);
        check_bit("T2_filter_mask_pin", (filter_mask === 11'h7FF), 1'b1);

        // Switch out of reset mode: MODECR = 0 (Normal mode)
        write_reg(8'h00, 32'h00000000);
        read_reg(8'h00, rval);
        check32("T2_MODECR_normal", rval, 32'h00000000);
        check_bit("T2_soft_reset_cleared", soft_reset, 1'b0);
        $display("[PASS] T2");

        // =====================================================================
        // T3: TX Buffer Load & Transmission Trigger
        // =====================================================================
        $display("--- T3: TX Buffer Load & Strobe ---");
        // Load TX frame: ID=0x456, RTR=0, DLC=8
        // Header: [10:0]=ID, [11]=RTR, [19:16]=DLC -> (8 << 16) | 0x456 = 0x00080456
        write_reg(8'h20, 32'h00080456);
        write_reg(8'h24, 32'h11223344); // Payload Bytes 0..3
        write_reg(8'h28, 32'h55667788); // Payload Bytes 4..7

        // Verify outputs match before triggering write
        check_bit("T3_tx_id_match", (tx_id === 11'h456), 1'b1);
        check_bit("T3_tx_dlc_match", (tx_dlc === 4'd8), 1'b1);
        check_bit("T3_tx_data_match", (tx_data === 64'h11223344_55667788), 1'b1);

        // Send Command to trigger TX: CMR bit 0 = 1
        fork
            begin
                write_reg(8'h04, 32'h00000001);
            end
            begin
                // Watch for tx_write strobe
                @(posedge tx_write);
                $display("[PASS] T3_tx_write_strobe_detected");
                pass_cnt++;
            end
        join
        $display("[PASS] T3");

        // =====================================================================
        // T4: RX FIFO Read & Pop Strobe
        // =====================================================================
        $display("--- T4: RX FIFO Read & Pop Strobe ---");
        // Simulate hardware presenting a frame at FIFO head
        rx_empty    = 0;
        rx_count    = 5'd3;
        rx_out_id   = 11'h123;
        rx_out_rtr  = 1'b0;
        rx_out_dlc  = 4'd4;
        rx_out_data = 64'hA1B2C3D4_00000000;

        // Read RX registers
        read_reg(8'h2C, rval); // RX_HEADER: DLC=4 (bits 19..16), ID=0x123 -> 0x00040123
        check32("T4_RX_HEADER", rval, 32'h00040123);
        read_reg(8'h30, rval); // RX_DATA_L
        check32("T4_RX_DATA_L", rval, 32'hA1B2C3D4);
        read_reg(8'h38, rval); // FIFO_CNT
        check32("T4_FIFO_CNT", rval, 32'h00000003);

        // Issue POP strobe via CMR bit 1 = 1
        fork
            begin
                write_reg(8'h04, 32'h00000002);
            end
            begin
                @(posedge rx_pop);
                $display("[PASS] T4_rx_pop_strobe_detected");
                pass_cnt++;
            end
        join
        $display("[PASS] T4");

        // =====================================================================
        // T5: Status & Error Counter Mapping
        // =====================================================================
        $display("--- T5: Status & Error Counter Mapping ---");
        tec = 8'd45;
        rec = 8'd12;
        node_state = 2'b01; // Error-Passive
        error_warning = 1'b0;
        bus_off = 1'b0;

        read_reg(8'h1C, rval); // ECR: [15:8]=TEC=45, [7:0]=REC=12 -> 0x00002D0C
        check32("T5_ECR_check", rval, 32'h00002D0C);

        read_reg(8'h08, rval); // SR: node_state=01 at bits [7:6] -> 0x40
        check_bit("T5_SR_node_state", (rval[7:6] === 2'b01), 1'b1);
        $display("[PASS] T5");

        // =====================================================================
        // T6: Interrupt Generation & W1C Operation
        // =====================================================================
        $display("--- T6: Interrupt Generation & W1C ---");
        // Enable interrupts for TX_DONE (bit 0) and RX_VALID (bit 1)
        // IE is bits [23:16] -> write (3 << 16) = 0x00030000
        write_reg(8'h0C, 32'h00030000);
        check_bit("T6_irq_initially_low", irq_out, 1'b0);

        // Hardware pulses tx_done_pulse
        @(posedge clk); #1;
        tx_done_pulse = 1'b1;
        @(posedge clk); #1;
        tx_done_pulse = 1'b0;
        @(posedge clk); #1;

        // IRQ line should now be asserted high
        check_bit("T6_irq_asserted", irq_out, 1'b1);

        // Verify status register shows bit 0 set
        read_reg(8'h0C, rval);
        check_bit("T6_ir_status_tx_done", rval[0], 1'b1);

        // Clear bit 0 with Write-1-to-Clear (W1C): write 0x00030001
        write_reg(8'h0C, 32'h00030001);
        @(posedge clk); #1;

        // IRQ should deassert back to 0
        check_bit("T6_irq_deasserted_after_w1c", irq_out, 1'b0);
        read_reg(8'h0C, rval);
        check_bit("T6_ir_status_cleared", rval[0], 1'b0);
        $display("[PASS] T6");

        // =====================================================================
        // Summary
        // =====================================================================
        #50;
        $display("=========================================");
        if (fail_cnt == 0)
            $display("ALL 6 CAN REGS TESTS PASSED");
        else
            $display("%0d / 6 CAN REGS TESTS FAILED", fail_cnt);
        $display("=========================================");
        $finish;
    end

    // Timeout Guard
    initial begin
        #500000;
        $error("TIMEOUT");
        $finish;
    end

endmodule
