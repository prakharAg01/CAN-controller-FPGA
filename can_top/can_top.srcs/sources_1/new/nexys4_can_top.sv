// =============================================================================
// Module      : nexys4_can_top
// Description : Physical Board Top-Level Wrapper for CAN 2.0A Controller on
//               the Digilent Nexys 4 DDR (Artix-7 XC7A100T-1CSG324).
//
// Features    :
//   - Connects 100 MHz oscillator and debounced reset
//   - Connects CAN physical transceiver pads (Pmod JA)
//   - Connects USB-UART Bridge at 115200 baud (Pins C4 / D4)
//   - Automatic RX FIFO drain & streaming to PC terminal (Day 38)
//   - PC-controlled or Button-controlled CAN frame transmission
//   - 1 Hz Heartbeat LED indicator
//   - 16 Status LEDs displaying FSM state, Error state, IRQ, and TEC
//
// Day 38      : UART Gateway & Host Command Protocol
// =============================================================================

`timescale 1ns/1ps

module nexys4_can_top (
    input  logic        clk,          // 100 MHz oscillator (Pin E3)
    input  logic        rst_n,        // CPU_RESET active-low red button (Pin C12)
    input  logic        btnc,         // Center push button (Pin N17, active-high reset)
    input  logic        btn_send,     // Up push button BTNU (Pin M18, trigger send)

    // Configuration Switches
    input  logic [1:0]  sw,           // SW[0] = Internal Loopback, SW[1] = Pad Loopback

    // CAN Transceiver Interface (Pmod Header JA)
    output logic        can_tx,       // JA Pin 1 (Pin C17) -> Transceiver TXD
    input  logic        can_rx,       // JA Pin 2 (Pin D18) <- Transceiver RXD
    output logic        can_s,        // JA Pin 3 (Pin E18) -> Transceiver Silent/Standby (0=Active)

    // USB-UART Interface (FT2232HQ Bridge)
    input  logic        uart_rxd,     // Pin C4 (PC -> FPGA)
    output logic        uart_txd,     // Pin D4 (FPGA -> PC)

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
    // 5. Host Register Interconnect
    // -------------------------------------------------------------------------
    wire        reg_cs;
    wire        reg_we;
    wire [7:0]  reg_addr;
    wire [31:0] reg_wdata;
    wire [31:0] reg_rdata;
    wire        reg_ack;
    wire        irq_out;

    wire [3:0]  debug_state;
    wire [1:0]  debug_node_st;
    wire [7:0]  debug_tec;
    wire [7:0]  debug_rec;

    wire [3:0]  gw_state_led;
    wire [7:0]  rx_frame_count;
    wire        rx_fifo_empty;

    // -------------------------------------------------------------------------
    // 6. Day 38: UART Host Gateway
    // -------------------------------------------------------------------------
    can_uart_gateway u_gateway (
        .clk             (clk),
        .rst_n           (sys_rst_n),

        // Physical UART Pins
        .uart_rxd        (uart_rxd),
        .uart_txd        (uart_txd),

        // Controls
        .btn_send_pulse  (btn_pulse),
        .sw_loopback     (sw[0]),
        .sw_pad_loopback (sw[1]),

        // Register Bus Master
        .reg_cs          (reg_cs),
        .reg_we          (reg_we),
        .reg_addr        (reg_addr),
        .reg_wdata       (reg_wdata),
        .reg_rdata       (reg_rdata),
        .reg_ack         (reg_ack),
        .irq_out         (irq_out),
        .rx_fifo_empty   (rx_fifo_empty),

        // Diagnostics
        .gw_state_led    (gw_state_led),
        .rx_frame_count  (rx_frame_count)
    );

    // -------------------------------------------------------------------------
    // 7. CAN Controller Top Instance
    // -------------------------------------------------------------------------
    can_controller_top u_can_controller (
        .clk          (clk),
        .rst_n        (sys_rst_n),

        // Host Register Interface (Slave to UART Gateway)
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
        .debug_rec    (debug_rec),
        .rx_fifo_empty(rx_fifo_empty)
    );

    // -------------------------------------------------------------------------
    // 8. Status LED Output Assignment
    // -------------------------------------------------------------------------
    assign led[3:0]   = debug_state[3:0];   // BSP FSM numeric state
    assign led[5:4]   = debug_node_st[1:0]; // 00=Active, 01=Passive, 10=Bus-Off
    assign led[6]     = irq_out;            // High when TX_DONE or RX_VALID
    assign led[7]     = heartbeat;          // Heartbeat 1 Hz flash
    assign led[11:8]  = gw_state_led[3:0];  // Gateway FSM state
    assign led[15:12] = debug_tec[3:0];     // Transmit Error Counter (low nibble)

endmodule
