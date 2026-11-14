// =============================================================================
// Module      : can_controller_top
// Description : Top-level CAN 2.0A Protocol Controller IP Core.
//               Integrates:
//                 - can_regs               (32-bit Host Register Interface)
//                 - can_tx_buffer          (TX Message Holding Register)
//                 - can_rx_fifo            (Inferred Block RAM RX FIFO)
//                 - can_acceptance_filter  (ID & Mask Acceptance Filter)
//                 - can_rx_assembler       (RX Frame Deserializer & CRC Checker)
//                 - can_bsp                (Bit Stream Processor + EML + Stuffer)
//                 - can_btl                (Bit Timing Logic & Resynchronization)
//                 - Loopback & Transceiver Pad Interface
//
// Day 27-28   : Top-Level Integration (can_controller_top)
// =============================================================================

module can_controller_top (
    input  logic        clk,          // System clock (e.g. 100 MHz on Nexys 4 DDR)
    input  logic        rst_n,        // Active-low asynchronous reset

    // -------------------------------------------------------------------------
    // Host / MCU 32-bit Memory-Mapped Register Bus
    // -------------------------------------------------------------------------
    input  logic        reg_cs,       // Chip select (active high)
    input  logic        reg_we,       // Write enable (1 = write, 0 = read)
    input  logic [7:0]  reg_addr,     // Byte address (word aligned: [1:0] = 00)
    input  logic [31:0] reg_wdata,    // Write data from host
    output logic [31:0] reg_rdata,    // Read data to host
    output logic        reg_ack,      // Transfer acknowledge (1-cycle pulse)
    output logic        irq_out,      // Unified interrupt output line to host CPU

    // -------------------------------------------------------------------------
    // Physical CAN Transceiver Interface (Pins to TJA1050 / PMOD)
    // -------------------------------------------------------------------------
    output logic        can_tx,       // CAN Transmit (TXD) pin
    input  logic        can_rx,       // CAN Receive  (RXD) pin

    // -------------------------------------------------------------------------
    // Debug & Status Outputs
    // -------------------------------------------------------------------------
    output logic [3:0]  debug_state,  // BSP FSM numeric state
    output logic [1:0]  debug_node_st,// 00=Active, 01=Passive, 10=Bus-Off
    output logic [7:0]  debug_tec,    // Transmit Error Counter
    output logic [7:0]  debug_rec     // Receive Error Counter
);

    // =========================================================================
    // Interconnect Wires
    // =========================================================================

    // Register Interface Controls
    logic        soft_reset;
    logic        loopback_en;
    logic        listen_only;
    logic        abort_tx;
    logic        bus_off_rec;

    logic [7:0]  btr_brp;
    logic [3:0]  btr_tseg1;
    logic [2:0]  btr_tseg2;
    logic [1:0]  btr_sjw;

    logic [10:0] filter_id;
    logic [10:0] filter_mask;

    logic        reg_tx_write;
    logic [10:0] reg_tx_id;
    logic        reg_tx_rtr;
    logic [3:0]  reg_tx_dlc;
    logic [63:0] reg_tx_data;

    logic        reg_rx_pop;
    logic        reg_rx_clear;

    // TX Buffer <-> BSP Handshake
    logic        tx_ready;
    logic        tx_busy;
    logic        bsp_tx_req;
    logic [10:0] bsp_tx_id;
    logic        bsp_tx_rtr;
    logic [3:0]  bsp_tx_dlc;
    logic [63:0] bsp_tx_data;
    logic        bsp_tx_done;

    // RX FIFO Status & Head Data
    logic        rx_fifo_push;
    logic        rx_accept;
    logic [79:0] rx_fifo_in;
    logic [79:0] rx_fifo_out;
    logic [10:0] rx_out_id;
    logic        rx_out_rtr;
    logic [3:0]  rx_out_dlc;
    logic [63:0] rx_out_data;
    logic        rx_empty, rx_full, rx_almost_full, rx_overrun;
    logic [4:0]  rx_count;

    // RX Assembler
    logic [10:0] asm_rx_id;
    logic        asm_rx_rtr;
    logic [3:0]  asm_rx_dlc;
    logic [63:0] asm_rx_data;
    logic        asm_crc_ok;
    logic        asm_rx_push;

    // Bit Timing Logic (BTL) Outputs
    logic        btl_tq_tick;
    logic        btl_bit_tick;
    logic        btl_sample_point;
    logic        btl_rx_bit;
    logic [1:0]  btl_seg_state;
    logic        btl_hard_sync, btl_resync_full, btl_resync_limited;

    // Bit Stream Processor (BSP) & EML
    logic        bsp_tx_bit;
    logic        bsp_tx_en;
    logic        bsp_frame_active;
    logic        bsp_ack_error;
    logic        bsp_form_error;
    logic        bsp_rx_data_bit;
    logic        bsp_rx_data_valid;
    logic        bsp_rx_stuff_error;
    logic        bsp_error_out;
    logic [3:0]  bsp_state_out;

    logic [7:0]  eml_tec;
    logic [7:0]  eml_rec;
    logic [1:0]  eml_node_state;
    logic        eml_error_active;
    logic        eml_error_passive;
    logic        eml_bus_off;
    logic        eml_error_warning;

    // =========================================================================
    // 1. Physical Layer & Loopback Multiplexer
    // =========================================================================
    // When loopback is enabled: internal tx drives rx_in, physical pin can_tx is recessive
    // When listen_only is enabled: physical can_tx is held recessive (1)
    wire internal_tx_bit = bsp_tx_en ? bsp_tx_bit : 1'b1;

    assign can_tx = (loopback_en || listen_only) ? 1'b1 : internal_tx_bit;

    wire btl_rx_in = loopback_en ? internal_tx_bit : can_rx;

    // Synchronizer enables for BTL
    wire btl_hsync_en    = (bsp_state_out == 4'd0); // Hard sync on SOF when idle
    wire btl_rsync_en    = (bsp_state_out != 4'd0); // Resync during frame
    wire btl_tx_dominant = bsp_tx_en && !bsp_tx_bit;

    // =========================================================================
    // 2. Bit Timing Logic (`can_btl`)
    // =========================================================================
    can_btl u_btl (
        .clk            (clk),
        .rst_n          (rst_n && !soft_reset),
        .clear          (abort_tx),
        .brp            (btr_brp),
        .tseg1          (btr_tseg1),
        .tseg2          (btr_tseg2),
        .sjw            (btr_sjw),
        .hsync_en       (btl_hsync_en),
        .rsync_en       (btl_rsync_en),
        .tx_dominant    (btl_tx_dominant),
        .rx_in          (btl_rx_in),
        .tq_tick        (btl_tq_tick),
        .bit_tick       (btl_bit_tick),
        .sample_point   (btl_sample_point),
        .rx_bit         (btl_rx_bit),
        .seg_state      (btl_seg_state),
        .hard_sync      (btl_hard_sync),
        .resync_full    (btl_resync_full),
        .resync_limited (btl_resync_limited)
    );

    // =========================================================================
    // 3. Bit Stream Processor (`can_bsp`)
    // =========================================================================
    can_bsp u_bsp (
        .clk             (clk),
        .rst_n           (rst_n && !soft_reset),
        .clear           (abort_tx),
        .bit_tick        (btl_bit_tick),
        .sample_point    (btl_sample_point),
        .rx_bit          (btl_rx_bit),
        .tx_request      (bsp_tx_req),
        .tx_id           (bsp_tx_id),
        .tx_dlc          (bsp_tx_dlc),
        .tx_data         (bsp_tx_data),
        .stuff_error     (1'b0), // Destuffer is integrated inside can_bsp
        .crc_ok          (asm_crc_ok),
        .bus_off_recovery(bus_off_rec),
        .loopback        (loopback_en),
        .tx_bit          (bsp_tx_bit),
        .tx_en           (bsp_tx_en),
        .frame_active    (bsp_frame_active),
        .ack_error       (bsp_ack_error),
        .form_error      (bsp_form_error),
        .rx_data_bit     (bsp_rx_data_bit),
        .rx_data_valid   (bsp_rx_data_valid),
        .rx_stuff_error  (bsp_rx_stuff_error),
        .error_out       (bsp_error_out),
        .state_out       (bsp_state_out),
        .tx_success      (bsp_tx_done),
        .rx_success      (eml_rx_success),
        .tec             (eml_tec),
        .rec             (eml_rec),
        .node_state      (eml_node_state),
        .error_active    (eml_error_active),
        .error_passive   (eml_error_passive),
        .bus_off         (eml_bus_off),
        .error_warning   (eml_error_warning)
    );

    // In loopback mode, internal TX also acts as incoming frame to be queued into RX FIFO
    wire frame_valid_for_rx = loopback_en ? bsp_tx_done : eml_rx_success;

    // =========================================================================
    // 4. RX Frame Assembler & CRC Checker (`can_rx_assembler`)
    // =========================================================================
    can_rx_assembler u_rx_assembler (
        .clk           (clk),
        .rst_n         (rst_n && !soft_reset),
        .clear         (abort_tx),
        .bsp_state     (bsp_state_out),
        .rx_data_bit   (bsp_rx_data_bit),
        .rx_data_valid (bsp_rx_data_valid),
        .frame_valid   (frame_valid_for_rx),
        .crc_ok        (asm_crc_ok),
        .rx_push       (asm_rx_push),
        .rx_id         (asm_rx_id),
        .rx_rtr        (asm_rx_rtr),
        .rx_dlc        (asm_rx_dlc),
        .rx_data       (asm_rx_data)
    );

    // =========================================================================
    // 5. Acceptance Filter (`can_acceptance_filter`)
    // =========================================================================
    can_acceptance_filter u_filter (
        .rx_id       (asm_rx_id),
        .filter_id   (filter_id),
        .filter_mask (filter_mask),
        .accept      (rx_accept)
    );

    // =========================================================================
    // 6. Transmit Buffer (`can_tx_buffer`)
    // =========================================================================
    can_tx_buffer u_tx_buffer (
        .clk           (clk),
        .rst_n         (rst_n && !soft_reset),
        .tx_write      (reg_tx_write),
        .tx_id         (reg_tx_id),
        .tx_rtr        (reg_tx_rtr),
        .tx_dlc        (reg_tx_dlc),
        .tx_data       (reg_tx_data),
        .bsp_tx_request(bsp_tx_req),
        .bsp_tx_id     (bsp_tx_id),
        .bsp_tx_rtr    (bsp_tx_rtr),
        .bsp_tx_dlc    (bsp_tx_dlc),
        .bsp_tx_data   (bsp_tx_data),
        .bsp_tx_done   (bsp_tx_done),
        .tx_ready      (tx_ready),
        .tx_busy       (tx_busy)
    );

    // =========================================================================
    // 7. Receive FIFO (`can_rx_fifo`)
    // =========================================================================
    assign rx_fifo_in = {asm_rx_id, asm_rx_rtr, asm_rx_dlc, asm_rx_data};

    can_rx_fifo #(
        .DEPTH (16),
        .DATA_W(80)
    ) u_rx_fifo (
        .clk        (clk),
        .rst_n      (rst_n && !soft_reset),
        .clear      (reg_rx_clear),
        .push       (asm_rx_push),
        .rx_in      (rx_fifo_in),
        .accept_in  (rx_accept),
        .pop        (reg_rx_pop),
        .rx_out     (rx_fifo_out),
        .rx_out_id  (rx_out_id),
        .rx_out_rtr (rx_out_rtr),
        .rx_out_dlc (rx_out_dlc),
        .rx_out_data(rx_out_data),
        .empty      (rx_empty),
        .full       (rx_full),
        .almost_full(rx_almost_full),
        .overrun    (rx_overrun),
        .count      (rx_count)
    );

    // Pulse when a frame is successfully queued into the FIFO
    wire rx_valid_pulse = asm_rx_push && rx_accept && !rx_full;

    // =========================================================================
    // 8. Register Interface (`can_regs`)
    // =========================================================================
    can_regs u_regs (
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
        .tx_write      (reg_tx_write),
        .tx_id         (reg_tx_id),
        .tx_rtr        (reg_tx_rtr),
        .tx_dlc        (reg_tx_dlc),
        .tx_data       (reg_tx_data),
        .rx_pop        (reg_rx_pop),
        .rx_clear      (reg_rx_clear),
        .tx_ready      (tx_ready),
        .tx_busy       (tx_busy),
        .tx_done_pulse (bsp_tx_done),
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
        .tec           (eml_tec),
        .rec           (eml_rec),
        .node_state    (eml_node_state),
        .error_warning (eml_error_warning),
        .bus_off       (eml_bus_off)
    );

    // =========================================================================
    // Debug Outputs
    // =========================================================================
    assign debug_state   = bsp_state_out;
    assign debug_node_st = eml_node_state;
    assign debug_tec     = eml_tec;
    assign debug_rec     = eml_rec;

endmodule

