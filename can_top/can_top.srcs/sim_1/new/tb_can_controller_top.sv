// =============================================================================
// Testbench : tb_can_controller_top
// Tests     : T1-T5 (Full end-to-end CAN 2.0A Controller verification)
//             T1: Power-up Reset & Default Register Values
//             T2: Baud Rate & Filter Setup
//             T3: End-to-End Loopback Transmission & Verification
//             T4: Acceptance Filter Rejection
//             T5: Bus Error & Interrupt Handling
// Day 27-28 : Top-Level Integration (can_controller_top)
// =============================================================================
`timescale 1ns/1ps

module tb_can_controller_top;

    // Clock & Reset
    logic        clk, rst_n;

    // Host Register Bus
    logic        reg_cs;
    logic        reg_we;
    logic [7:0]  reg_addr;
    logic [31:0] reg_wdata;
    logic [31:0] reg_rdata;
    logic        reg_ack;
    logic        irq_out;

    // Physical CAN Transceiver Pins
    logic        can_tx;
    logic        can_rx;

    // Debug Ports
    logic [3:0]  debug_state;
    logic [1:0]  debug_node_st;
    logic [7:0]  debug_tec;
    logic [7:0]  debug_rec;

    // DUT
    can_controller_top dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .reg_cs       (reg_cs),
        .reg_we       (reg_we),
        .reg_addr     (reg_addr),
        .reg_wdata    (reg_wdata),
        .reg_rdata    (reg_rdata),
        .reg_ack      (reg_ack),
        .irq_out      (irq_out),
        .can_tx       (can_tx),
        .can_rx       (can_rx),
        .debug_state  (debug_state),
        .debug_node_st(debug_node_st),
        .debug_tec    (debug_tec),
        .debug_rec    (debug_rec)
    );

    // 100 MHz System Clock (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Host Register Access Tasks
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
    // Verification Scoreboard
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
    // Main Test Flow
    // =========================================================================
    initial begin
        rst_n    = 0;
        reg_cs   = 0;
        reg_we   = 0;
        reg_addr = 0;
        reg_wdata= 0;
        can_rx   = 1'b1; // Bus idle is recessive

        #40;
        @(posedge clk); #1;
        rst_n = 1;
        @(posedge clk); #1;

        // =====================================================================
        // T1: Power-up Reset & Default Register Values
        // =====================================================================
        $display("\n=======================================================");
        $display("--- T1: Power-up Reset & Default Register Values ---");
        $display("=======================================================");
        read_reg(8'h00, rval); // MODECR
        check32("T1_MODECR_default", rval, 32'h00000001); // Soft reset = 1

        read_reg(8'h08, rval); // Status Register
        // TX ready (bit 1) and RX empty (bit 2) should be 1 -> 0x06
        check32("T1_SR_default", rval, 32'h00000006);

        // =====================================================================
        // T2: Baud Rate & Filter Setup
        // =====================================================================
        $display("\n=======================================================");
        $display("--- T2: Baud Rate & Filter Setup ---");
        $display("=======================================================");
        // Configure fast BTR for simulation: BRP=0 (1 TQ = 1 clk), TSEG1=3 (4 TQ), TSEG2=2 (3 TQ), SJW=0 (1 TQ)
        // Bit time = 1 + 4 + 3 = 8 clocks
        // BTR layout: [7:0]=BRP=0, [11:8]=TSEG1=3, [14:12]=TSEG2=2, [17:16]=SJW=0 -> 0x00002300
        write_reg(8'h10, 32'h00002300);
        read_reg(8'h10, rval);
        check32("T2_BTR_readback", rval, 32'h00002300);

        // Configure Acceptance Filter: Accept everything (Mask=0x000)
        write_reg(8'h14, 32'h00000000);
        write_reg(8'h18, 32'h00000000);

        // Enable TX_DONE (bit 0) and RX_VALID (bit 1) Interrupts
        write_reg(8'h0C, 32'h00030000);

        // =====================================================================
        // T3: End-to-End Loopback Transmission & Verification
        // =====================================================================
        $display("\n=======================================================");
        $display("--- T3: End-to-End Loopback Transmission ---");
        $display("=======================================================");
        // Enable Loopback Mode & Exit Soft Reset: MODECR = 0x02 (bit 1=loopback, bit 0=0)
        write_reg(8'h00, 32'h00000002);
        read_reg(8'h00, rval);
        check32("T3_MODECR_loopback", rval, 32'h00000002);

        // Stage CAN Frame: ID = 0x25A (11-bit), RTR = 0, DLC = 8
        // Payload = 0xDEADBEEF_CAFE1234
        // Header: (8 << 16) | 0x25A = 0x0008025A
        write_reg(8'h20, 32'h0008025A); // TX_HEADER
        write_reg(8'h24, 32'hDEADBEEF); // TX_DATA_L
        write_reg(8'h28, 32'hCAFE1234); // TX_DATA_H

        // Trigger Transmission via Command Register (CMR bit 0 = 1)
        write_reg(8'h04, 32'h00000001);

        // Wait for frame to loopback through BTL, BSP, and RX FIFO
        // Wait until irq_out asserts
        $display("[INFO] Frame transmitting in loopback mode; awaiting interrupt...");
        @(posedge irq_out);
        $display("[EVENT] Time %0t ps: Interrupt asserted! Frame transaction complete.", $time);

        // Read Status & Interrupt Flags
        read_reg(8'h0C, rval); // IR / IE
        check_bit("T3_TX_DONE_INT", rval[0], 1'b1);
        check_bit("T3_RX_VALID_INT", rval[1], 1'b1);

        // Read received frame from RX FIFO
        read_reg(8'h2C, rval); // RX_HEADER
        check32("T3_RX_HEADER", rval, 32'h0008025A); // ID=0x25A, DLC=8

        read_reg(8'h30, rval); // RX_DATA_L
        check32("T3_RX_DATA_L", rval, 32'hDEADBEEF);

        read_reg(8'h34, rval); // RX_DATA_H
        check32("T3_RX_DATA_H", rval, 32'hCAFE1234);

        read_reg(8'h38, rval); // FIFO_CNT
        check32("T3_FIFO_CNT", rval, 32'h00000001);

        // Pop head frame from FIFO (CMR bit 1 = 1)
        write_reg(8'h04, 32'h00000002);
        #50;
        read_reg(8'h38, rval);
        check32("T3_FIFO_CNT_after_pop", rval, 32'h00000000);

        // Clear Interrupts (W1C bits 0 and 1)
        write_reg(8'h0C, 32'h00030003);
        @(posedge clk); #1;
        check_bit("T3_irq_deasserted", irq_out, 1'b0);

        // =====================================================================
        // T4: Acceptance Filter Rejection
        // =====================================================================
        $display("\n=======================================================");
        $display("--- T4: Acceptance Filter Rejection ---");
        $display("=======================================================");
        // Enter reset mode to change filter
        write_reg(8'h00, 32'h00000001);
        // Set Filter to only accept ID = 0x100 (Filter ID = 0x100, Mask = 0x7FF)
        write_reg(8'h14, 32'h00000100);
        write_reg(8'h18, 32'h000007FF);
        // Re-enable Loopback mode
        write_reg(8'h00, 32'h00000002);

        // Transmit frame with non-matching ID = 0x300
        write_reg(8'h20, 32'h00020300); // ID = 0x300, DLC = 2
        write_reg(8'h24, 32'hA5A50000);
        write_reg(8'h04, 32'h00000001); // TX_REQ

        fork
            begin
                #100000;
                $display("[T4_DEBUG] time=%0t state=%0d tx_req=%0b tx_busy=%0b tx_done=%0b irq=%0b tec=%0d rec=%0d",
                    $time, dut.bsp_state_out, dut.bsp_tx_req, dut.tx_busy, dut.bsp_tx_done, irq_out, dut.eml_tec, dut.eml_rec);
                #1000000;
                $display("[T4_DEBUG] time=%0t state=%0d tx_req=%0b tx_busy=%0b tx_done=%0b irq=%0b tec=%0d rec=%0d",
                    $time, dut.bsp_state_out, dut.bsp_tx_req, dut.tx_busy, dut.bsp_tx_done, irq_out, dut.eml_tec, dut.eml_rec);
            end
        join_none

        // Wait for transmission to finish
        @(posedge irq_out);
        read_reg(8'h0C, rval);
        check_bit("T4_TX_DONE_INT", rval[0], 1'b1);
        check_bit("T4_RX_VALID_REJECTED", rval[1], 1'b0); // Must NOT set RX_VALID!

        // RX FIFO must remain empty
        read_reg(8'h38, rval);
        check32("T4_FIFO_remains_empty", rval, 32'h00000000);

        // Clear TX interrupt
        write_reg(8'h0C, 32'h00030001);

        // =====================================================================
        // T5: Status & Error Confinement Inspection
        // =====================================================================
        $display("\n=======================================================");
        $display("--- T5: Status & Error Counter Inspection ---");
        $display("=======================================================");
        read_reg(8'h1C, rval); // ECR: [15:8]=TEC, [7:0]=REC
        // Since all transmissions were successful, TEC and REC should be 0
        check32("T5_ECR_zero", rval, 32'h00000000);

        read_reg(8'h08, rval); // SR
        check_bit("T5_SR_node_active", (rval[7:6] === 2'b00), 1'b1); // Error-Active
        check_bit("T5_SR_bus_off", rval[12], 1'b0);

        // =====================================================================
        // Summary
        // =====================================================================
        #100;
        $display("\n=======================================================");
        if (fail_cnt == 0)
            $display("ALL 5 CAN CONTROLLER TOP TESTS PASSED");
        else
            $display("%0d / 5 CAN CONTROLLER TOP TESTS FAILED", fail_cnt);
        $display("=======================================================\n");
        $finish;
    end

    // Simulation Timeout Guard
    initial begin
        #2000000;
        $error("TIMEOUT: Simulation exceeded 2 ms");
        $finish;
    end

endmodule

