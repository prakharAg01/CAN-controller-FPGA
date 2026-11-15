// =============================================================================
// Testbench : tb_can_controller_two_node
// Tests     : T1-T6 (Comprehensive Dual-Node System Verification & Bus Arbitration)
//             T1: Power-up Reset & Default Register Initialisation (Nodes A & B)
//             T2: Unidirectional Transmission Node A -> Node B with Hardware ACK
//             T3: Unidirectional Transmission Node B -> Node A with Hardware ACK
//             T4: Simultaneous Transmission with Arbitration (Node A ID 0x120 wins over Node B ID 0x124)
//                 + Automatic Retransmission of Node B after IFS
//             T5: Simultaneous Transmission with Reverse Arbitration (Node B ID 0x250 wins over Node A ID 0x270)
//                 + Automatic Retransmission of Node A after IFS
//             T6: Multi-Node Acceptance Filter Discrimination & Back-to-Back Burst Transfer
//
// Day 29-30 : Two-Node System Testbench + Bus Arbitration
// =============================================================================
`timescale 1ns/1ps

module tb_can_controller_two_node;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;

    // -------------------------------------------------------------------------
    // Node A Host Register Bus
    // -------------------------------------------------------------------------
    logic        reg_cs_a;
    logic        reg_we_a;
    logic [7:0]  reg_addr_a;
    logic [31:0] reg_wdata_a;
    logic [31:0] reg_rdata_a;
    logic        reg_ack_a;
    logic        irq_out_a;

    // -------------------------------------------------------------------------
    // Node B Host Register Bus
    // -------------------------------------------------------------------------
    logic        reg_cs_b;
    logic        reg_we_b;
    logic [7:0]  reg_addr_b;
    logic [31:0] reg_wdata_b;
    logic [31:0] reg_rdata_b;
    logic        reg_ack_b;
    logic        irq_out_b;

    // -------------------------------------------------------------------------
    // Physical CAN Transceiver Signals
    // -------------------------------------------------------------------------
    logic        can_tx_a;
    logic        can_rx_a;
    logic        can_tx_b;
    logic        can_rx_b;

    // -------------------------------------------------------------------------
    // Debug & Status Ports
    // -------------------------------------------------------------------------
    logic [3:0]  debug_state_a,  debug_state_b;
    logic [1:0]  debug_node_st_a, debug_node_st_b;
    logic [7:0]  debug_tec_a,    debug_tec_b;
    logic [7:0]  debug_rec_a,    debug_rec_b;

    // -------------------------------------------------------------------------
    // Shared Physical Open-Collector Wired-AND Bus:
    // Dominant is 0, Recessive is 1. If either node pulls 0, bus resolves to 0.
    // -------------------------------------------------------------------------
    wire can_bus = can_tx_a & can_tx_b;
    assign can_rx_a = can_bus;
    assign can_rx_b = can_bus;

    // -------------------------------------------------------------------------
    // DUT Instantiations: Node A and Node B
    // -------------------------------------------------------------------------
    can_controller_top u_node_a (
        .clk          (clk),
        .rst_n        (rst_n),
        .reg_cs       (reg_cs_a),
        .reg_we       (reg_we_a),
        .reg_addr     (reg_addr_a),
        .reg_wdata    (reg_wdata_a),
        .reg_rdata    (reg_rdata_a),
        .reg_ack      (reg_ack_a),
        .irq_out      (irq_out_a),
        .can_tx       (can_tx_a),
        .can_rx       (can_rx_a),
        .debug_state  (debug_state_a),
        .debug_node_st(debug_node_st_a),
        .debug_tec    (debug_tec_a),
        .debug_rec    (debug_rec_a)
    );

    can_controller_top u_node_b (
        .clk          (clk),
        .rst_n        (rst_n),
        .reg_cs       (reg_cs_b),
        .reg_we       (reg_we_b),
        .reg_addr     (reg_addr_b),
        .reg_wdata    (reg_wdata_b),
        .reg_rdata    (reg_rdata_b),
        .reg_ack      (reg_ack_b),
        .irq_out      (irq_out_b),
        .can_tx       (can_tx_b),
        .can_rx       (can_rx_b),
        .debug_state  (debug_state_b),
        .debug_node_st(debug_node_st_b),
        .debug_tec    (debug_tec_b),
        .debug_rec    (debug_rec_b)
    );

    // -------------------------------------------------------------------------
    // Clock Generation: 100 MHz System Clock (10 ns period)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Register Map Constants
    // -------------------------------------------------------------------------
    localparam [7:0] ADDR_MODECR    = 8'h00;
    localparam [7:0] ADDR_CMR       = 8'h04;
    localparam [7:0] ADDR_SR        = 8'h08;
    localparam [7:0] ADDR_IR_IE     = 8'h0C;
    localparam [7:0] ADDR_BTR       = 8'h10;
    localparam [7:0] ADDR_AFID      = 8'h14;
    localparam [7:0] ADDR_AFMSK     = 8'h18;
    localparam [7:0] ADDR_ECR       = 8'h1C;
    localparam [7:0] ADDR_TX_HEADER = 8'h20;
    localparam [7:0] ADDR_TX_DATA_L = 8'h24;
    localparam [7:0] ADDR_TX_DATA_H = 8'h28;
    localparam [7:0] ADDR_RX_HEADER = 8'h2C;
    localparam [7:0] ADDR_RX_DATA_L = 8'h30;
    localparam [7:0] ADDR_RX_DATA_H = 8'h34;
    localparam [7:0] ADDR_FIFO_CNT  = 8'h38;

    // -------------------------------------------------------------------------
    // Host Register Access Tasks: Node A
    // -------------------------------------------------------------------------
    task write_reg_a(input [7:0] addr, input [31:0] data);
        @(posedge clk); #1;
        reg_addr_a  = addr;
        reg_wdata_a = data;
        reg_we_a    = 1'b1;
        reg_cs_a    = 1'b1;
        @(posedge clk);
        while (!reg_ack_a) @(posedge clk);
        #1;
        reg_cs_a    = 1'b0;
        reg_we_a    = 1'b0;
    endtask

    task read_reg_a(input [7:0] addr, output [31:0] data);
        @(posedge clk); #1;
        reg_addr_a  = addr;
        reg_we_a    = 1'b0;
        reg_cs_a    = 1'b1;
        @(posedge clk);
        while (!reg_ack_a) @(posedge clk);
        #1;
        data        = reg_rdata_a;
        reg_cs_a    = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Host Register Access Tasks: Node B
    // -------------------------------------------------------------------------
    task write_reg_b(input [7:0] addr, input [31:0] data);
        @(posedge clk); #1;
        reg_addr_b  = addr;
        reg_wdata_b = data;
        reg_we_b    = 1'b1;
        reg_cs_b    = 1'b1;
        @(posedge clk);
        while (!reg_ack_b) @(posedge clk);
        #1;
        reg_cs_b    = 1'b0;
        reg_we_b    = 1'b0;
    endtask

    task read_reg_b(input [7:0] addr, output [31:0] data);
        @(posedge clk); #1;
        reg_addr_b  = addr;
        reg_we_b    = 1'b0;
        reg_cs_b    = 1'b1;
        @(posedge clk);
        while (!reg_ack_b) @(posedge clk);
        #1;
        data        = reg_rdata_b;
        reg_cs_b    = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Verification Scoreboard & Assertion Helpers
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

    logic [31:0] rval_a, rval_b;

    // =========================================================================
    // Main Test Execution Flow
    // =========================================================================
    initial begin
        // Initialize control signals
        rst_n       = 0;
        reg_cs_a    = 0;
        reg_we_a    = 0;
        reg_addr_a  = 0;
        reg_wdata_a = 0;

        reg_cs_b    = 0;
        reg_we_b    = 0;
        reg_addr_b  = 0;
        reg_wdata_b = 0;

        #40;
        @(posedge clk); #1;
        rst_n = 1;
        @(posedge clk); #1;

        // =====================================================================
        // T1: Power-up Reset & Default Register Initialisation (Nodes A & B)
        // =====================================================================
        $display("\n=================================================================");
        $display("--- T1: Power-up Reset & Configuration (Node A & Node B) ---");
        $display("=================================================================");

        // Verify default power-up state on both nodes
        read_reg_a(ADDR_MODECR, rval_a);
        read_reg_b(ADDR_MODECR, rval_b);
        check32("T1_Node_A_MODECR_default", rval_a, 32'h00000001); // Soft reset active
        check32("T1_Node_B_MODECR_default", rval_b, 32'h00000001);

        read_reg_a(ADDR_SR, rval_a);
        read_reg_b(ADDR_SR, rval_b);
        check32("T1_Node_A_SR_default", rval_a, 32'h00000006); // TX ready (1) & RX empty (1)
        check32("T1_Node_B_SR_default", rval_b, 32'h00000006);

        // Configure Bit Timing on both nodes:
        // BRP=0, TSEG1=3, TSEG2=2, SJW=0 -> 8 clocks/bit (100 MHz -> 12.5 Mbps sim baud)
        // BTR = 0x00002300
        write_reg_a(ADDR_BTR, 32'h00002300);
        write_reg_b(ADDR_BTR, 32'h00002300);

        read_reg_a(ADDR_BTR, rval_a);
        read_reg_b(ADDR_BTR, rval_b);
        check32("T1_Node_A_BTR_readback", rval_a, 32'h00002300);
        check32("T1_Node_B_BTR_readback", rval_b, 32'h00002300);

        // Configure Acceptance Filters: Accept all IDs initially (Mask = 0x000)
        write_reg_a(ADDR_AFID,  32'h00000000);
        write_reg_a(ADDR_AFMSK, 32'h00000000);
        write_reg_b(ADDR_AFID,  32'h00000000);
        write_reg_b(ADDR_AFMSK, 32'h00000000);

        // Enable Interrupts: TX_DONE (bit 16) & RX_VALID (bit 17) -> 0x00030000
        write_reg_a(ADDR_IR_IE, 32'h00030000);
        write_reg_b(ADDR_IR_IE, 32'h00030000);

        // Transition both nodes into Normal Bus Operating Mode: MODECR = 0x00
        write_reg_a(ADDR_MODECR, 32'h00000000);
        write_reg_b(ADDR_MODECR, 32'h00000000);

        read_reg_a(ADDR_MODECR, rval_a);
        read_reg_b(ADDR_MODECR, rval_b);
        check32("T1_Node_A_MODECR_normal", rval_a, 32'h00000000);
        check32("T1_Node_B_MODECR_normal", rval_b, 32'h00000000);

        // Check bus line is idle recessive (1)
        check_bit("T1_can_bus_idle_recessive", can_bus, 1'b1);

        // =====================================================================
        // T2: Unidirectional Transmission Node A -> Node B with Hardware ACK
        // =====================================================================
        $display("\n=================================================================");
        $display("--- T2: Unidirectional Transfer (Node A -> Node B) ---");
        $display("=================================================================");

        // Node A stages frame: ID = 0x155, DLC = 4, Payload = 0x11223344_00000000
        // Header: (4 << 16) | 0x155 = 0x00040155
        write_reg_a(ADDR_TX_HEADER, 32'h00040155);
        write_reg_a(ADDR_TX_DATA_L, 32'h11223344);
        write_reg_a(ADDR_TX_DATA_H, 32'h00000000);

        // Trigger Node A transmission via CMR (bit 0 = 1)
        write_reg_a(ADDR_CMR, 32'h00000001);
        $display("[INFO] Time %0t ps: Node A initiated transmission of ID 0x155...", $time);

        // Wait for frame to traverse wired-AND bus and complete reception on Node B
        @(posedge irq_out_b);
        $display("[EVENT] Time %0t ps: Node B asserted RX interrupt!", $time);
        @(posedge irq_out_a);
        $display("[EVENT] Time %0t ps: Node A asserted TX interrupt!", $time);

        // Verify interrupt status flags
        read_reg_a(ADDR_IR_IE, rval_a);
        read_reg_b(ADDR_IR_IE, rval_b);
        check_bit("T2_Node_A_TX_DONE_INT", rval_a[0], 1'b1);
        check_bit("T2_Node_B_RX_VALID_INT", rval_b[1], 1'b1);

        // Verify received frame inside Node B RX FIFO
        read_reg_b(ADDR_RX_HEADER, rval_b);
        check32("T2_Node_B_RX_HEADER", rval_b, 32'h00040155);

        read_reg_b(ADDR_RX_DATA_L, rval_b);
        check32("T2_Node_B_RX_DATA_L", rval_b, 32'h11223344);

        read_reg_b(ADDR_FIFO_CNT, rval_b);
        check32("T2_Node_B_FIFO_CNT_before_pop", rval_b, 32'h00000001);

        // Pop frame from Node B FIFO (CMR bit 1 = 1)
        write_reg_b(ADDR_CMR, 32'h00000002);
        #50;
        read_reg_b(ADDR_FIFO_CNT, rval_b);
        check32("T2_Node_B_FIFO_CNT_after_pop", rval_b, 32'h00000000);

        // Verify Node A's own RX FIFO remained empty (transmitters do not queue own frames on bus)
        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T2_Node_A_FIFO_remained_empty", rval_a, 32'h00000000);

        // Clear interrupts on both nodes (W1C)
        write_reg_a(ADDR_IR_IE, 32'h00030003);
        write_reg_b(ADDR_IR_IE, 32'h00030003);
        @(posedge clk); #1;
        check_bit("T2_irq_a_cleared", irq_out_a, 1'b0);
        check_bit("T2_irq_b_cleared", irq_out_b, 1'b0);

        // =====================================================================
        // T3: Reverse Unidirectional Transmission Node B -> Node A with Hardware ACK
        // =====================================================================
        $display("\n=================================================================");
        $display("--- T3: Reverse Unidirectional Transfer (Node B -> Node A) ---");
        $display("=================================================================");

        // Node B stages frame: ID = 0x3AA, DLC = 8, Payload = 0xAABBCCDD_12345678
        // Header: (8 << 16) | 0x3AA = 0x000803AA
        write_reg_b(ADDR_TX_HEADER, 32'h000803AA);
        write_reg_b(ADDR_TX_DATA_L, 32'hAABBCCDD);
        write_reg_b(ADDR_TX_DATA_H, 32'h12345678);

        // Trigger Node B transmission
        write_reg_b(ADDR_CMR, 32'h00000001);
        $display("[INFO] Time %0t ps: Node B initiated transmission of ID 0x3AA...", $time);

        @(posedge irq_out_a);
        $display("[EVENT] Time %0t ps: Node A asserted RX interrupt!", $time);
        @(posedge irq_out_b);
        $display("[EVENT] Time %0t ps: Node B asserted TX interrupt!", $time);

        read_reg_b(ADDR_IR_IE, rval_b);
        read_reg_a(ADDR_IR_IE, rval_a);
        check_bit("T3_Node_B_TX_DONE_INT", rval_b[0], 1'b1);
        check_bit("T3_Node_A_RX_VALID_INT", rval_a[1], 1'b1);

        // Verify received frame inside Node A RX FIFO
        read_reg_a(ADDR_RX_HEADER, rval_a);
        check32("T3_Node_A_RX_HEADER", rval_a, 32'h000803AA);

        read_reg_a(ADDR_RX_DATA_L, rval_a);
        check32("T3_Node_A_RX_DATA_L", rval_a, 32'hAABBCCDD);

        read_reg_a(ADDR_RX_DATA_H, rval_a);
        check32("T3_Node_A_RX_DATA_H", rval_a, 32'h12345678);

        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T3_Node_A_FIFO_CNT_before_pop", rval_a, 32'h00000001);

        // Pop frame from Node A FIFO
        write_reg_a(ADDR_CMR, 32'h00000002);
        #50;
        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T3_Node_A_FIFO_CNT_after_pop", rval_a, 32'h00000000);

        // Clear interrupts on both nodes
        write_reg_a(ADDR_IR_IE, 32'h00030003);
        write_reg_b(ADDR_IR_IE, 32'h00030003);
        @(posedge clk); #1;
        check_bit("T3_irq_a_cleared", irq_out_a, 1'b0);
        check_bit("T3_irq_b_cleared", irq_out_b, 1'b0);

        // =====================================================================
        // T4: Simultaneous Transmission with Arbitration:
        // Node A (ID 0x120) wins over Node B (ID 0x124)
        // Automatic Retransmission of Node B after IFS
        // =====================================================================
        $display("\n=================================================================");
        $display("--- T4: Simultaneous Transmission & Arbitration (Node A Wins) ---");
        $display("=================================================================");

        // Node A stages frame: ID = 0x120, DLC = 2, Payload = 0xAAAA0000
        // Header: (2 << 16) | 0x120 = 0x00020120
        write_reg_a(ADDR_TX_HEADER, 32'h00020120);
        write_reg_a(ADDR_TX_DATA_L, 32'hAAAA0000);

        // Node B stages frame: ID = 0x124, DLC = 2, Payload = 0xBBBB0000
        // Header: (2 << 16) | 0x124 = 0x00020124
        write_reg_b(ADDR_TX_HEADER, 32'h00020124);
        write_reg_b(ADDR_TX_DATA_L, 32'hBBBB0000);

        // Trigger both nodes simultaneously at the exact same clock edge
        $display("[INFO] Time %0t ps: Simultaneously asserting TX_REQ on Node A and Node B...", $time);
        fork
            write_reg_a(ADDR_CMR, 32'h00000001);
            write_reg_b(ADDR_CMR, 32'h00000001);
        join

        // Monitor arbitration:
        // ID 0x120 = 001 0010 0000 vs ID 0x124 = 001 0010 0100
        // At bit ID[2] (9th bit of arbitration):
        // Node A drives 0 (dominant), Node B drives 1 (recessive).
        // Node B must detect arb_lost, clear transmitting, and drop tx_en!
        @(posedge u_node_b.u_bsp.arb_lost);
        $display("[EVENT] Time %0t ps: Node B detected arbitration loss at bit ID[2]! Dropping tx_en.", $time);
        check_bit("T4_Node_B_arb_lost_asserted", u_node_b.u_bsp.arb_lost, 1'b1);
        check_bit("T4_Node_A_remains_winner", u_node_a.u_bsp.arb_lost, 1'b0);

        // Node A completes frame 1 transmission & Node B completes reception
        fork
            begin
                @(posedge u_node_a.bsp_tx_done);
                $display("[EVENT] Time %0t ps: Node A (winner) completed frame transmission (ID 0x120)!", $time);
            end
            begin
                @(posedge u_node_b.rx_valid_pulse);
                $display("[EVENT] Time %0t ps: Node B successfully received winning frame into RX FIFO!", $time);
            end
        join

        // Verify Node B automatically begins retransmitting its pending frame (ID 0x124) after IFS
        fork
            begin
                @(posedge u_node_b.bsp_tx_done);
                $display("[EVENT] Time %0t ps: Node B successfully retransmitted frame (ID 0x124)!", $time);
            end
            begin
                @(posedge u_node_a.rx_valid_pulse);
                $display("[EVENT] Time %0t ps: Node A received Node B's retransmitted frame into RX FIFO!", $time);
            end
        join

        // Verify Node B received Node A's frame
        read_reg_b(ADDR_RX_HEADER, rval_b);
        check32("T4_Node_B_RX_HEADER_from_A", rval_b, 32'h00020120);
        read_reg_b(ADDR_RX_DATA_L, rval_b);
        check32("T4_Node_B_RX_DATA_from_A", rval_b, 32'hAAAA0000);
        read_reg_b(ADDR_FIFO_CNT, rval_b);
        check32("T4_Node_B_FIFO_CNT", rval_b, 32'h00000001);

        // Pop Node B FIFO
        write_reg_b(ADDR_CMR, 32'h00000002);
        #50;

        // Verify Node A received Node B's retransmitted frame
        read_reg_a(ADDR_RX_HEADER, rval_a);
        check32("T4_Node_A_RX_HEADER_from_B", rval_a, 32'h00020124);
        read_reg_a(ADDR_RX_DATA_L, rval_a);
        check32("T4_Node_A_RX_DATA_from_B", rval_a, 32'hBBBB0000);
        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T4_Node_A_FIFO_CNT", rval_a, 32'h00000001);

        // Pop Node A FIFO
        write_reg_a(ADDR_CMR, 32'h00000002);
        #50;

        // Check error counters: TEC and REC must remain 0 (arbitration loss is NOT an error!)
        read_reg_a(ADDR_ECR, rval_a);
        read_reg_b(ADDR_ECR, rval_b);
        check32("T4_Node_A_ECR_zero", rval_a, 32'h00000000);
        check32("T4_Node_B_ECR_zero", rval_b, 32'h00000000);

        // Clear interrupts on both nodes
        write_reg_a(ADDR_IR_IE, 32'h00030003);
        write_reg_b(ADDR_IR_IE, 32'h00030003);
        @(posedge clk); #1;

        // =====================================================================
        // T5: Simultaneous Transmission with Reverse Arbitration:
        // Node B (ID 0x250) wins over Node A (ID 0x270)
        // Automatic Retransmission of Node A after IFS
        // =====================================================================
        $display("\n=================================================================");
        $display("--- T5: Simultaneous Transmission & Arbitration (Node B Wins) ---");
        $display("=================================================================");

        // Node A stages frame: ID = 0x270, DLC = 1, Payload = 0x77000000
        // Header: (1 << 16) | 0x270 = 0x00010270
        write_reg_a(ADDR_TX_HEADER, 32'h00010270);
        write_reg_a(ADDR_TX_DATA_L, 32'h77000000);

        // Node B stages frame: ID = 0x250, DLC = 1, Payload = 0x55000000
        // Header: (1 << 16) | 0x250 = 0x00010250
        write_reg_b(ADDR_TX_HEADER, 32'h00010250);
        write_reg_b(ADDR_TX_DATA_L, 32'h55000000);

        // Trigger both nodes simultaneously
        $display("[INFO] Time %0t ps: Simultaneously asserting TX_REQ on Node A and Node B...", $time);
        fork
            write_reg_a(ADDR_CMR, 32'h00000001);
            write_reg_b(ADDR_CMR, 32'h00000001);
        join

        // ID 0x250 = 010 0101 0000 vs ID 0x270 = 010 0111 0000
        // At bit ID[5] (6th bit of arbitration):
        // Node B drives 0 (dominant), Node A drives 1 (recessive).
        // Node A must detect arb_lost and drop tx_en!
        @(posedge u_node_a.u_bsp.arb_lost);
        $display("[EVENT] Time %0t ps: Node A detected arbitration loss at bit ID[5]! Dropping tx_en.", $time);
        check_bit("T5_Node_A_arb_lost_asserted", u_node_a.u_bsp.arb_lost, 1'b1);
        check_bit("T5_Node_B_remains_winner", u_node_b.u_bsp.arb_lost, 1'b0);

        // Node B completes frame 1 transmission & Node A completes reception
        fork
            begin
                @(posedge u_node_b.bsp_tx_done);
                $display("[EVENT] Time %0t ps: Node B (winner) completed frame transmission (ID 0x250)!", $time);
            end
            begin
                @(posedge u_node_a.rx_valid_pulse);
                $display("[EVENT] Time %0t ps: Node A successfully received winning frame into RX FIFO!", $time);
            end
        join

        // Verify Node A automatically begins retransmitting its pending frame (ID 0x270) after IFS
        fork
            begin
                @(posedge u_node_a.bsp_tx_done);
                $display("[EVENT] Time %0t ps: Node A successfully retransmitted frame (ID 0x270)!", $time);
            end
            begin
                @(posedge u_node_b.rx_valid_pulse);
                $display("[EVENT] Time %0t ps: Node B received Node A's retransmitted frame into RX FIFO!", $time);
            end
        join

        // Verify Node A received Node B's frame
        read_reg_a(ADDR_RX_HEADER, rval_a);
        check32("T5_Node_A_RX_HEADER_from_B", rval_a, 32'h00010250);
        read_reg_a(ADDR_RX_DATA_L, rval_a);
        check32("T5_Node_A_RX_DATA_from_B", rval_a, 32'h55000000);
        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T5_Node_A_FIFO_CNT", rval_a, 32'h00000001);

        // Pop Node A FIFO
        write_reg_a(ADDR_CMR, 32'h00000002);
        #50;

        // Verify Node B received Node A's retransmitted frame
        read_reg_b(ADDR_RX_HEADER, rval_b);
        check32("T5_Node_B_RX_HEADER_from_A", rval_b, 32'h00010270);
        read_reg_b(ADDR_RX_DATA_L, rval_b);
        check32("T5_Node_B_RX_DATA_from_A", rval_b, 32'h77000000);
        read_reg_b(ADDR_FIFO_CNT, rval_b);
        check32("T5_Node_B_FIFO_CNT", rval_b, 32'h00000001);

        // Pop Node B FIFO
        write_reg_b(ADDR_CMR, 32'h00000002);
        #50;

        // Check error counters
        read_reg_a(ADDR_ECR, rval_a);
        read_reg_b(ADDR_ECR, rval_b);
        check32("T5_Node_A_ECR_zero", rval_a, 32'h00000000);
        check32("T5_Node_B_ECR_zero", rval_b, 32'h00000000);

        // Clear interrupts on both nodes
        write_reg_a(ADDR_IR_IE, 32'h00030003);
        write_reg_b(ADDR_IR_IE, 32'h00030003);
        @(posedge clk); #1;

        // =====================================================================
        // T6: Acceptance Filter Discrimination & Back-to-Back Burst Transfer
        // =====================================================================
        $display("\n=================================================================");
        $display("--- T6: Acceptance Filtering & Back-to-Back Burst Transfers ---");
        $display("=================================================================");

        // Configure Node B Acceptance Filter: Only accept ID = 0x400 (Mask = 0x7FF)
        write_reg_b(ADDR_MODECR, 32'h00000001); // Soft reset
        write_reg_b(ADDR_AFID,   32'h00000400); // Filter ID = 0x400
        write_reg_b(ADDR_AFMSK,  32'h000007FF); // Exact 11-bit match
        write_reg_b(ADDR_MODECR, 32'h00000000); // Normal mode

        // Part 1: Node A transmits non-matching frame (ID = 0x401)
        // Node B MUST provide hardware ACK at CAN physical layer, but reject from FIFO
        write_reg_a(ADDR_TX_HEADER, 32'h00020401); // ID = 0x401, DLC = 2
        write_reg_a(ADDR_TX_DATA_L, 32'hC0010000);
        write_reg_a(ADDR_CMR,       32'h00000001);

        @(posedge u_node_a.bsp_tx_done);
        $display("[EVENT] Time %0t ps: Node A completed transmission of ID 0x401 with valid bus ACK!", $time);

        read_reg_a(ADDR_IR_IE, rval_a);
        check_bit("T6_Node_A_TX_DONE", rval_a[0], 1'b1);

        read_reg_b(ADDR_IR_IE, rval_b);
        check_bit("T6_Node_B_RX_VALID_rejected", rval_b[1], 1'b0); // Filter rejected!

        read_reg_b(ADDR_FIFO_CNT, rval_b);
        check32("T6_Node_B_FIFO_remains_empty", rval_b, 32'h00000000);

        // Clear Node A TX interrupt
        write_reg_a(ADDR_IR_IE, 32'h00030001);

        // Part 2: Node A transmits matching frame (ID = 0x400)
        write_reg_a(ADDR_TX_HEADER, 32'h00020400); // ID = 0x400, DLC = 2
        write_reg_a(ADDR_TX_DATA_L, 32'hC0000000);
        write_reg_a(ADDR_CMR,       32'h00000001);

        fork
            @(posedge u_node_a.bsp_tx_done);
            @(posedge u_node_b.rx_valid_pulse);
        join
        $display("[EVENT] Time %0t ps: Node B accepted matching frame ID 0x400 into RX FIFO!", $time);

        read_reg_b(ADDR_RX_HEADER, rval_b);
        check32("T6_Node_B_RX_HEADER_matched", rval_b, 32'h00020400);

        read_reg_b(ADDR_RX_DATA_L, rval_b);
        check32("T6_Node_B_RX_DATA_matched", rval_b, 32'hC0000000);

        // Pop Node B FIFO & clear interrupts
        write_reg_b(ADDR_CMR,   32'h00000002);
        write_reg_a(ADDR_IR_IE, 32'h00030001);
        write_reg_b(ADDR_IR_IE, 32'h00030002);

        // Part 3: Back-to-Back Burst Transfer (Node B -> Node A, 3 frames)
        // Multi-frame queuing verified inside Node A's Block RAM FIFO
        $display("[INFO] Initiating 3 back-to-back burst frame transmissions from Node B to Node A...");

        // Frame 1: ID = 0x101, DLC = 4, Data = 0x11111111
        write_reg_b(ADDR_TX_HEADER, 32'h00040101);
        write_reg_b(ADDR_TX_DATA_L, 32'h11111111);
        write_reg_b(ADDR_CMR,       32'h00000001);
        @(posedge u_node_b.bsp_tx_done);
        write_reg_b(ADDR_IR_IE,     32'h00030001); // Clear TX interrupt

        // Frame 2: ID = 0x102, DLC = 4, Data = 0x22222222
        write_reg_b(ADDR_TX_HEADER, 32'h00040102);
        write_reg_b(ADDR_TX_DATA_L, 32'h22222222);
        write_reg_b(ADDR_CMR,       32'h00000001);
        @(posedge u_node_b.bsp_tx_done);
        write_reg_b(ADDR_IR_IE,     32'h00030001);

        // Frame 3: ID = 0x103, DLC = 4, Data = 0x33333333
        write_reg_b(ADDR_TX_HEADER, 32'h00040103);
        write_reg_b(ADDR_TX_DATA_L, 32'h33333333);
        write_reg_b(ADDR_CMR,       32'h00000001);
        @(posedge u_node_b.bsp_tx_done);
        write_reg_b(ADDR_IR_IE,     32'h00030001);

        // Node A Block RAM FIFO should now contain 3 queued frames
        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T6_Node_A_FIFO_burst_count_3", rval_a, 32'h00000003);

        // Pop & verify Frame 1
        read_reg_a(ADDR_RX_HEADER, rval_a);
        check32("T6_Burst_Frame_1_HEADER", rval_a, 32'h00040101);
        read_reg_a(ADDR_RX_DATA_L, rval_a);
        check32("T6_Burst_Frame_1_DATA", rval_a, 32'h11111111);
        write_reg_a(ADDR_CMR, 32'h00000002); // Pop
        #50;
        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T6_FIFO_count_after_pop_1", rval_a, 32'h00000002);

        // Pop & verify Frame 2
        read_reg_a(ADDR_RX_HEADER, rval_a);
        check32("T6_Burst_Frame_2_HEADER", rval_a, 32'h00040102);
        read_reg_a(ADDR_RX_DATA_L, rval_a);
        check32("T6_Burst_Frame_2_DATA", rval_a, 32'h22222222);
        write_reg_a(ADDR_CMR, 32'h00000002); // Pop
        #50;
        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T6_FIFO_count_after_pop_2", rval_a, 32'h00000001);

        // Pop & verify Frame 3
        read_reg_a(ADDR_RX_HEADER, rval_a);
        check32("T6_Burst_Frame_3_HEADER", rval_a, 32'h00040103);
        read_reg_a(ADDR_RX_DATA_L, rval_a);
        check32("T6_Burst_Frame_3_DATA", rval_a, 32'h33333333);
        write_reg_a(ADDR_CMR, 32'h00000002); // Pop
        #50;
        read_reg_a(ADDR_FIFO_CNT, rval_a);
        check32("T6_FIFO_count_after_pop_3", rval_a, 32'h00000000);

        // Clear remaining interrupts
        write_reg_a(ADDR_IR_IE, 32'h00030003);
        write_reg_b(ADDR_IR_IE, 32'h00030003);

        // Verify final error status on both nodes
        read_reg_a(ADDR_ECR, rval_a);
        read_reg_b(ADDR_ECR, rval_b);
        check32("T6_Final_Node_A_ECR", rval_a, 32'h00000000);
        check32("T6_Final_Node_B_ECR", rval_b, 32'h00000000);

        // =====================================================================
        // Testbench Summary
        // =====================================================================
        #100;
        $display("\n=================================================================");
        if (fail_cnt == 0) begin
            $display("ALL 6 TWO-NODE CAN CONTROLLER TESTS PASSED (%0d checks)", pass_cnt);
        end else begin
            $display("%0d TESTS FAILED (%0d passed)", fail_cnt, pass_cnt);
        end
        $display("=================================================================\n");
        $finish;
    end

    // Simulation Timeout Guard (100 us)
    initial begin
        #100000000;
        $error("TIMEOUT: Two-node simulation exceeded 100 us");
        $finish;
    end

endmodule
