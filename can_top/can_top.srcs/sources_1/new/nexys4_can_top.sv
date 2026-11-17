// =============================================================================
// Module      : nexys4_can_top
// Description : Physical Board Top-Level Wrapper for CAN 2.0A Controller on
//               the Digilent Nexys 4 DDR (Artix-7 XC7A100T-1CSG324).
//
// Features    :
//   - Connects 100 MHz oscillator and debounced reset
//   - Connects CAN physical transceiver pads (Pmod JA)
//   - 1 Hz Heartbeat LED indicator
//   - On-board self-test FSM (triggered on startup or via BTNU button)
//   - Hardware switch SW[0] for internal loopback mode (Day 35 test)
//   - 16 Status LEDs displaying FSM state, Error state, IRQ, and TEC
//
// Day 33-35   : FPGA Bring-up & Hardware Demonstration
// =============================================================================

`timescale 1ns/1ps

module nexys4_can_top (
    input  logic        clk,          // 100 MHz oscillator (Pin E3)
    input  logic        rst_n,        // CPU_RESET active-low red button (Pin C12)
    input  logic        btnc,         // Center push button (Pin N17, active-high reset)
    input  logic        btn_send,     // Up push button BTNU (Pin M18, trigger send)

    // Configuration Switches
    input  logic [1:0]  sw,           // SW[0] = Internal Loopback, SW[1] = Reserved

    // CAN Transceiver Interface (Pmod Header JA)
    output logic        can_tx,       // JA Pin 1 (Pin C17) -> Transceiver TXD
    input  logic        can_rx,       // JA Pin 2 (Pin D18) <- Transceiver RXD
    output logic        can_s,        // JA Pin 3 (Pin E18) -> Transceiver Silent/Standby (0=Active)

    // 16 Status LEDs
    output logic [15:0] led
);

    // -------------------------------------------------------------------------
    // 1. Reset Synchronization & Debouncing
    // -------------------------------------------------------------------------
    logic raw_rst_n;
    assign raw_rst_n = rst_n & ~btnc;

    logic [1:0] sync_rst_n;
    always_ff @(posedge clk or negedge raw_rst_n) begin
        if (!raw_rst_n) begin
            sync_rst_n <= 2'b00;
        end else begin
            sync_rst_n <= {sync_rst_n[0], 1'b1};
        end
    end
    wire sys_rst_n = sync_rst_n[1];

    // -------------------------------------------------------------------------
    // 2. 1 Hz Heartbeat Blinker (100 MHz / 50,000,000 = 2 Hz toggle -> 1 Hz flash)
    // -------------------------------------------------------------------------
    logic [25:0] hb_cnt;
    logic        heartbeat;

    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            hb_cnt    <= 26'd0;
            heartbeat <= 1'b0;
        end else begin
            if (hb_cnt == 26'd49_999_999) begin
                hb_cnt    <= 26'd0;
                heartbeat <= ~heartbeat;
            end else begin
                hb_cnt    <= hb_cnt + 26'd1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. Debounce BTN_SEND (Edge Detector)
    // -------------------------------------------------------------------------
    logic [19:0] btn_db_cnt;
    logic        btn_stable;
    logic        btn_stable_d;
    wire         btn_pulse;

    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            btn_db_cnt   <= 20'd0;
            btn_stable   <= 1'b0;
            btn_stable_d <= 1'b0;
        end else begin
            btn_stable_d <= btn_stable;
            if (btn_send != btn_stable) begin
                btn_db_cnt <= btn_db_cnt + 20'd1;
                if (btn_db_cnt == 20'd1_000_000) begin // 10ms debounce
                    btn_stable <= btn_send;
                    btn_db_cnt <= 20'd0;
                end
            end else begin
                btn_db_cnt <= 20'd0;
            end
        end
    end
    assign btn_pulse = btn_stable & ~btn_stable_d;

    // -------------------------------------------------------------------------
    // 4. Physical / Loopback Multiplexer
    // -------------------------------------------------------------------------
    wire can_rx_internal;
    wire core_can_tx;

    // When SW[0] is ON, loopback core_can_tx directly to core_can_rx on-chip
    assign can_rx_internal = (sw[0]) ? core_can_tx : can_rx;
    assign can_tx          = core_can_tx;
    assign can_s           = 1'b0; // Normal active mode (not standby)

    // -------------------------------------------------------------------------
    // 5. Host Register Interface & On-board Self-Test Sequencer
    // -------------------------------------------------------------------------
    localparam [7:0] ADDR_MODECR    = 8'h00; // Mode & Control Register
    localparam [7:0] ADDR_CMR       = 8'h04; // Command Register (Strobes)
    localparam [7:0] ADDR_SR        = 8'h08; // Status Register (RO)
    localparam [7:0] ADDR_IR_IE     = 8'h0C; // Interrupt Status (W1C) & Enable (R/W)
    localparam [7:0] ADDR_BTR       = 8'h10; // Bit Timing Register
    localparam [7:0] ADDR_AFID      = 8'h14; // Acceptance Filter ID
    localparam [7:0] ADDR_AFMSK     = 8'h18; // Acceptance Filter Mask
    localparam [7:0] ADDR_ECR       = 8'h1C; // Error Counter Register (RO)
    localparam [7:0] ADDR_TX_HEADER = 8'h20; // TX Frame Header (ID, RTR, DLC)
    localparam [7:0] ADDR_TX_DATA_L = 8'h24; // TX Payload Bytes 0..3
    localparam [7:0] ADDR_TX_DATA_H = 8'h28; // TX Payload Bytes 4..7
    localparam [7:0] ADDR_RX_HEADER = 8'h2C; // RX Frame Header (RO)
    localparam [7:0] ADDR_RX_DATA_L = 8'h30; // RX Payload Bytes 0..3 (RO)
    localparam [7:0] ADDR_RX_DATA_H = 8'h34; // RX Payload Bytes 4..7 (RO)
    localparam [7:0] ADDR_FIFO_CNT  = 8'h38; // RX FIFO Count (RO)

    logic        reg_cs;
    logic        reg_we;
    logic [7:0]  reg_addr;
    logic [31:0] reg_wdata;
    wire  [31:0] reg_rdata;
    wire         reg_ack;
    wire         irq_out;

    wire [3:0]   debug_state;
    wire [1:0]   debug_node_st;
    wire [7:0]   debug_tec;
    wire [7:0]   debug_rec;

    typedef enum logic [3:0] {
        INIT_IDLE,      // 0
        INIT_BTR,       // 1
        INIT_AFID,      // 2
        INIT_AFMSK,     // 3
        INIT_IR_IE,     // 4
        INIT_MODECR,    // 5
        ST_READY,       // 6
        SEND_SET_MODE,  // 7
        SEND_HDR,       // 8
        SEND_DATA_L,    // 9
        SEND_TRIGGER,   // 10 (4'b1010)
        ST_WAIT_ACK     // 11 (4'b1011)
    } seq_state_t;

    seq_state_t seq_state;

    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            seq_state <= INIT_IDLE;
            reg_cs    <= 1'b0;
            reg_we    <= 1'b0;
            reg_addr  <= 8'h00;
            reg_wdata <= 32'h0;
        end else begin
            case (seq_state)
                INIT_IDLE: begin
                    // Step 1: Write BTR = 0x00008953 (500 kbps: 10 TQ/bit, 20 clocks/TQ @ 100MHz, 70% sample point, SJW=2)
                    reg_cs    <= 1'b1;
                    reg_we    <= 1'b1;
                    reg_addr  <= ADDR_BTR;
                    reg_wdata <= 32'h00008953;
                    seq_state <= INIT_BTR;
                end

                INIT_BTR: begin
                    if (reg_ack) begin
                        // Step 2: Write AFID = 0x00000000
                        reg_addr  <= ADDR_AFID;
                        reg_wdata <= 32'h00000000;
                        seq_state <= INIT_AFID;
                    end
                end

                INIT_AFID: begin
                    if (reg_ack) begin
                        // Step 3: Write AFMSK = 0x00000000 (Accept all IDs)
                        reg_addr  <= ADDR_AFMSK;
                        reg_wdata <= 32'h00000000;
                        seq_state <= INIT_AFMSK;
                    end
                end

                INIT_AFMSK: begin
                    if (reg_ack) begin
                        // Step 4: Write IR_IE = 0x00030000 (Enable TX_DONE & RX_VALID interrupts)
                        reg_addr  <= ADDR_IR_IE;
                        reg_wdata <= 32'h00030000;
                        seq_state <= INIT_IR_IE;
                    end
                end

                INIT_IR_IE: begin
                    if (reg_ack) begin
                        // Step 5: Exit reset mode: MODECR = loopback (2) or normal (0)
                        reg_addr  <= ADDR_MODECR;
                        reg_wdata <= (sw[0] || sw[1]) ? 32'h00000002 : 32'h00000000;
                        seq_state <= INIT_MODECR;
                    end
                end

                INIT_MODECR: begin
                    if (reg_ack) begin
                        reg_cs    <= 1'b0;
                        reg_we    <= 1'b0;
                        seq_state <= ST_READY;
                    end
                end

                ST_READY: begin
                    reg_cs <= 1'b0;
                    reg_we <= 1'b0;
                    if (btn_pulse) begin
                        // Update MODECR with current switch positions
                        reg_cs    <= 1'b1;
                        reg_we    <= 1'b1;
                        reg_addr  <= ADDR_MODECR;
                        reg_wdata <= (sw[0] || sw[1]) ? 32'h00000002 : 32'h00000000;
                        seq_state <= SEND_SET_MODE;
                    end
                end

                SEND_SET_MODE: begin
                    if (reg_ack) begin
                        // Stage TX Frame Header: ID = 0x155, DLC = 4 -> 0x00040155
                        reg_addr  <= ADDR_TX_HEADER;
                        reg_wdata <= 32'h00040155;
                        seq_state <= SEND_HDR;
                    end
                end

                SEND_HDR: begin
                    if (reg_ack) begin
                        // Stage TX Data: 0x11223344
                        reg_addr  <= ADDR_TX_DATA_L;
                        reg_wdata <= 32'h11223344;
                        seq_state <= SEND_DATA_L;
                    end
                end

                SEND_DATA_L: begin
                    if (reg_ack) begin
                        // Trigger transmission via CMR: Bit 0 = 1 (TX_REQ strobe)
                        reg_addr  <= ADDR_CMR;
                        reg_wdata <= 32'h00000001;
                        seq_state <= SEND_TRIGGER;
                    end
                end

                SEND_TRIGGER: begin
                    if (reg_ack) begin
                        reg_cs    <= 1'b0;
                        reg_we    <= 1'b0;
                        seq_state <= ST_WAIT_ACK;
                    end
                end

                ST_WAIT_ACK: begin
                    // Stay in ST_WAIT_ACK until irq_out asserts
                    if (irq_out) begin
                        seq_state <= ST_READY;
                    end
                end

                default: seq_state <= ST_READY;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 6. CAN Controller Top Instance
    // -------------------------------------------------------------------------
    can_controller_top u_can_controller (
        .clk          (clk),
        .rst_n        (sys_rst_n),

        // Host Register Interface
        .reg_cs       (reg_cs),
        .reg_we       (reg_we),
        .reg_addr     (reg_addr),
        .reg_wdata    (reg_wdata),
        .reg_rdata    (reg_rdata),
        .reg_ack      (reg_ack),
        .irq_out      (irq_out),

        // Transceiver Physical Lines
        .can_tx       (core_can_tx),
        .can_rx       (can_rx_internal),
        .pad_loopback (sw[1]),

        // Debug & Status
        .debug_state  (debug_state),
        .debug_node_st(debug_node_st),
        .debug_tec    (debug_tec),
        .debug_rec    (debug_rec)
    );

    // -------------------------------------------------------------------------
    // 7. Status LED Output Assignment
    // -------------------------------------------------------------------------
    assign led[3:0]   = debug_state[3:0];   // BSP FSM numeric state
    assign led[5:4]   = debug_node_st[1:0]; // 00=Active, 01=Passive, 10=Bus-Off
    assign led[6]     = irq_out;            // High when TX_DONE or RX_VALID
    assign led[7]     = heartbeat;          // Heartbeat 1 Hz flash
    assign led[11:8]  = seq_state[3:0];     // Onboard sequencer state
    assign led[15:12] = debug_tec[3:0];     // Transmit Error Counter (low nibble)

endmodule
