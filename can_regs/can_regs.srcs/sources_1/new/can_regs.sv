// =============================================================================
// Module      : can_regs
// Description : CAN 2.0A Controller 32-bit Register Interface.
//               Provides memory-mapped register space for external MCU/host
//               to configure baud rate, acceptance filter, and mode;
//               initiate frame transmissions; read received FIFO messages;
//               and monitor status, error counters, and interrupt flags.
//
// Day 26      : Register Interface
// =============================================================================

module can_regs (
    input  logic        clk,
    input  logic        rst_n,

    // -------------------------------------------------------------------------
    // Host Register Bus (Synchronous 32-bit interface)
    // -------------------------------------------------------------------------
    input  logic        reg_cs,       // Chip select (active high)
    input  logic        reg_we,       // Write enable (1 = write, 0 = read)
    input  logic [7:0]  reg_addr,     // Byte address (word aligned: bits [1:0] should be 0)
    input  logic [31:0] reg_wdata,    // Write data from host
    output logic [31:0] reg_rdata,    // Read data to host
    output logic        reg_ack,      // Transfer acknowledge (1-cycle pulse)
    output logic        irq_out,      // Unified interrupt output line

    // -------------------------------------------------------------------------
    // Control Outputs to Internal Core Submodules
    // -------------------------------------------------------------------------
    // Mode / Reset
    output logic        soft_reset,   // 1 = controller held in reset/config mode
    output logic        loopback_en,  // 1 = internal loopback mode
    output logic        listen_only,  // 1 = silent listen-only mode
    output logic        abort_tx,     // 1-clk strobe: abort pending transmission
    output logic        bus_off_rec,  // 1-clk strobe: trigger bus-off recovery

    // Bit Timing Config (to can_btl)
    output logic [7:0]  btr_brp,      // Baud Rate Prescaler
    output logic [3:0]  btr_tseg1,    // Time Segment 1
    output logic [2:0]  btr_tseg2,    // Time Segment 2
    output logic [1:0]  btr_sjw,      // Synchronization Jump Width

    // Acceptance Filter Config (to can_acceptance_filter)
    output logic [10:0] filter_id,    // Filter identifier
    output logic [10:0] filter_mask,  // Filter mask (1 = match, 0 = don't-care)

    // TX Buffer Interface (to can_tx_buffer)
    output logic        tx_write,     // 1-clk strobe to latch frame into TX buffer
    output logic [10:0] tx_id,        // Frame ID
    output logic        tx_rtr,       // Remote Transmission Request
    output logic [3:0]  tx_dlc,       // Data Length Code
    output logic [63:0] tx_data,      // Payload (64-bit)

    // RX FIFO Interface (to can_rx_fifo)
    output logic        rx_pop,       // 1-clk strobe to pop head frame from RX FIFO
    output logic        rx_clear,     // 1-clk strobe to clear RX FIFO

    // -------------------------------------------------------------------------
    // Status Inputs from Internal Core Submodules
    // -------------------------------------------------------------------------
    // TX Buffer Status
    input  logic        tx_ready,     // 1 = TX buffer free
    input  logic        tx_busy,      // 1 = TX buffer holding pending frame
    input  logic        tx_done_pulse,// 1-clk pulse on successful transmission

    // RX FIFO Status & Head Data
    input  logic        rx_empty,
    input  logic        rx_full,
    input  logic        rx_almost_full,
    input  logic        rx_overrun,
    input  logic [4:0]  rx_count,
    input  logic [10:0] rx_out_id,
    input  logic        rx_out_rtr,
    input  logic [3:0]  rx_out_dlc,
    input  logic [63:0] rx_out_data,
    input  logic        rx_valid_pulse, // 1-clk pulse when frame successfully stored

    // Error Management & BSP Status (from can_eml & can_bsp)
    input  logic [7:0]  tec,
    input  logic [7:0]  rec,
    input  logic [1:0]  node_state,   // 00=Active, 01=Passive, 10=Bus-Off
    input  logic        error_warning,// TEC >= 96 or REC >= 96
    input  logic        bus_off       // Node in bus-off
);

    // =========================================================================
    // Register Address Offsets (Word aligned)
    // =========================================================================
    localparam ADDR_MODECR    = 8'h00; // Mode & Control Register
    localparam ADDR_CMR       = 8'h04; // Command Register (Strobes)
    localparam ADDR_SR        = 8'h08; // Status Register (RO)
    localparam ADDR_IR_IE     = 8'h0C; // Interrupt Status (W1C) & Enable (R/W)
    localparam ADDR_BTR       = 8'h10; // Bit Timing Register
    localparam ADDR_AFID      = 8'h14; // Acceptance Filter ID
    localparam ADDR_AFMSK     = 8'h18; // Acceptance Filter Mask
    localparam ADDR_ECR       = 8'h1C; // Error Counter Register (RO)
    localparam ADDR_TX_HEADER = 8'h20; // TX Frame Header (ID, RTR, DLC)
    localparam ADDR_TX_DATA_L = 8'h24; // TX Payload Bytes 0..3
    localparam ADDR_TX_DATA_H = 8'h28; // TX Payload Bytes 4..7
    localparam ADDR_RX_HEADER = 8'h2C; // RX Frame Header (RO)
    localparam ADDR_RX_DATA_L = 8'h30; // RX Payload Bytes 0..3 (RO)
    localparam ADDR_RX_DATA_H = 8'h34; // RX Payload Bytes 4..7 (RO)
    localparam ADDR_FIFO_CNT  = 8'h38; // RX FIFO Count (RO)

    // =========================================================================
    // Internal Registers
    // =========================================================================
    // MODECR: [0]=reset, [1]=loopback, [2]=listen_only
    logic        reg_reset_mode;
    logic        reg_loopback;
    logic        reg_listen_only;

    // Strobes
    logic        strobe_abort_tx;
    logic        strobe_bus_off_rec;
    logic        strobe_tx_write;
    logic        strobe_rx_pop;
    logic        strobe_rx_clear;

    // BTR: [7:0]=BRP, [11:8]=TSEG1, [14:12]=TSEG2, [17:16]=SJW
    logic [7:0]  reg_btr_brp;
    logic [3:0]  reg_btr_tseg1;
    logic [2:0]  reg_btr_tseg2;
    logic [1:0]  reg_btr_sjw;

    // Acceptance Filter
    logic [10:0] reg_filter_id;
    logic [10:0] reg_filter_mask;

    // TX Storage
    logic [10:0] reg_tx_id;
    logic        reg_tx_rtr;
    logic [3:0]  reg_tx_dlc;
    logic [31:0] reg_tx_data_l;
    logic [31:0] reg_tx_data_h;

    // Interrupt Status & Enable:
    // Bits: [0]=tx_done, [1]=rx_valid, [2]=rx_overrun, [3]=err_warn, [4]=bus_off
    logic [7:0]  reg_ir_status; // W1C
    logic [7:0]  reg_ir_enable; // R/W

    // =========================================================================
    // Register Bus Read & Write Logic
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Default reset state
            reg_reset_mode     <= 1'b1; // Enters reset mode on startup
            reg_loopback       <= 1'b0;
            reg_listen_only    <= 1'b0;

            strobe_abort_tx    <= 1'b0;
            strobe_bus_off_rec <= 1'b0;
            strobe_tx_write    <= 1'b0;
            strobe_rx_pop      <= 1'b0;
            strobe_rx_clear    <= 1'b0;

            // Default timing: e.g., BRP=1, TSEG1=4, TSEG2=3, SJW=1
            reg_btr_brp        <= 8'd1;
            reg_btr_tseg1      <= 4'd4;
            reg_btr_tseg2      <= 3'd3;
            reg_btr_sjw        <= 2'd1;

            reg_filter_id      <= 11'd0;
            reg_filter_mask    <= 11'd0; // Promiscuous (accept all) by default

            reg_tx_id          <= 11'd0;
            reg_tx_rtr         <= 1'b0;
            reg_tx_dlc         <= 4'd0;
            reg_tx_data_l      <= 32'd0;
            reg_tx_data_h      <= 32'd0;

            reg_ir_status      <= 8'd0;
            reg_ir_enable      <= 8'd0;

            reg_ack            <= 1'b0;
            reg_rdata          <= 32'd0;
        end else begin
            // Default 1-clk strobes clear automatically
            strobe_abort_tx    <= 1'b0;
            strobe_bus_off_rec <= 1'b0;
            strobe_tx_write    <= 1'b0;
            strobe_rx_pop      <= 1'b0;
            strobe_rx_clear    <= 1'b0;
            reg_ack            <= 1'b0;

            // -----------------------------------------------------------------
            // Hardware Interrupt Events (Set IR bits)
            // -----------------------------------------------------------------
            if (tx_done_pulse)  reg_ir_status[0] <= 1'b1;
            if (rx_valid_pulse) reg_ir_status[1] <= 1'b1;
            if (rx_overrun)     reg_ir_status[2] <= 1'b1;
            if (error_warning)  reg_ir_status[3] <= 1'b1;
            if (bus_off)        reg_ir_status[4] <= 1'b1;

            // -----------------------------------------------------------------
            // Bus Transaction
            // -----------------------------------------------------------------
            if (reg_cs && !reg_ack) begin
                reg_ack <= 1'b1;

                if (reg_we) begin
                    // ---------------------------------------------------------
                    // WRITE Transactions
                    // ---------------------------------------------------------
                    case (reg_addr)
                        ADDR_MODECR: begin
                            reg_reset_mode     <= reg_wdata[0];
                            reg_loopback       <= reg_wdata[1];
                            reg_listen_only    <= reg_wdata[2];
                            if (reg_wdata[3]) strobe_abort_tx    <= 1'b1;
                            if (reg_wdata[4]) strobe_bus_off_rec <= 1'b1;
                        end

                        ADDR_CMR: begin
                            if (reg_wdata[0]) strobe_tx_write <= 1'b1;
                            if (reg_wdata[1]) strobe_rx_pop   <= 1'b1;
                            if (reg_wdata[2]) strobe_rx_clear <= 1'b1;
                        end

                        ADDR_IR_IE: begin
                            // Lower 8 bits: Write-1-to-Clear (W1C)
                            reg_ir_status <= reg_ir_status & ~reg_wdata[7:0];
                            // Bits [23:16]: Interrupt Enable Mask
                            reg_ir_enable <= reg_wdata[23:16];
                        end

                        ADDR_BTR: begin
                            // Can only change baud rate in Reset mode
                            if (reg_reset_mode) begin
                                reg_btr_brp   <= reg_wdata[7:0];
                                reg_btr_tseg1 <= reg_wdata[11:8];
                                reg_btr_tseg2 <= reg_wdata[14:12];
                                reg_btr_sjw   <= reg_wdata[17:16];
                            end
                        end

                        ADDR_AFID: begin
                            if (reg_reset_mode) begin
                                reg_filter_id <= reg_wdata[10:0];
                            end
                        end

                        ADDR_AFMSK: begin
                            if (reg_reset_mode) begin
                                reg_filter_mask <= reg_wdata[10:0];
                            end
                        end

                        ADDR_TX_HEADER: begin
                            reg_tx_id  <= reg_wdata[10:0];
                            reg_tx_rtr <= reg_wdata[11];
                            reg_tx_dlc <= reg_wdata[19:16];
                        end

                        ADDR_TX_DATA_L: begin
                            reg_tx_data_l <= reg_wdata;
                        end

                        ADDR_TX_DATA_H: begin
                            reg_tx_data_h <= reg_wdata;
                        end

                        default: ;
                    endcase
                end else begin
                    // ---------------------------------------------------------
                    // READ Transactions
                    // ---------------------------------------------------------
                    case (reg_addr)
                        ADDR_MODECR: begin
                            reg_rdata <= {27'd0, 2'b00, reg_listen_only, reg_loopback, reg_reset_mode};
                        end

                        ADDR_CMR: begin
                            reg_rdata <= 32'd0; // CMR write-only strobes return 0
                        end

                        ADDR_SR: begin
                            reg_rdata <= {
                                19'd0,
                                bus_off,         // Bit 12
                                3'd0,
                                error_warning,   // Bit 8
                                node_state,      // Bits [7:6]
                                rx_overrun,      // Bit 5
                                rx_almost_full,  // Bit 4
                                rx_full,         // Bit 3
                                rx_empty,        // Bit 2
                                tx_ready,        // Bit 1
                                tx_busy          // Bit 0
                            };
                        end

                        ADDR_IR_IE: begin
                            reg_rdata <= {8'd0, reg_ir_enable, 8'd0, reg_ir_status};
                        end

                        ADDR_BTR: begin
                            reg_rdata <= {14'd0, reg_btr_sjw, 1'b0, reg_btr_tseg2, reg_btr_tseg1, reg_btr_brp};
                        end

                        ADDR_AFID: begin
                            reg_rdata <= {21'd0, reg_filter_id};
                        end

                        ADDR_AFMSK: begin
                            reg_rdata <= {21'd0, reg_filter_mask};
                        end

                        ADDR_ECR: begin
                            reg_rdata <= {16'd0, tec, rec};
                        end

                        ADDR_TX_HEADER: begin
                            reg_rdata <= {12'd0, reg_tx_dlc, 4'd0, reg_tx_rtr, reg_tx_id};
                        end

                        ADDR_TX_DATA_L: begin
                            reg_rdata <= reg_tx_data_l;
                        end

                        ADDR_TX_DATA_H: begin
                            reg_rdata <= reg_tx_data_h;
                        end

                        ADDR_RX_HEADER: begin
                            reg_rdata <= {12'd0, rx_out_dlc, 4'd0, rx_out_rtr, rx_out_id};
                        end

                        ADDR_RX_DATA_L: begin
                            // Bytes 0..3 of RX head frame
                            reg_rdata <= rx_out_data[63:32];
                        end

                        ADDR_RX_DATA_H: begin
                            // Bytes 4..7 of RX head frame
                            reg_rdata <= rx_out_data[31:0];
                        end

                        ADDR_FIFO_CNT: begin
                            reg_rdata <= {27'd0, rx_count};
                        end

                        default: reg_rdata <= 32'hDEAD_BEEF;
                    endcase
                end
            end
        end
    end

    // =========================================================================
    // Output Assignments
    // =========================================================================
    assign soft_reset   = reg_reset_mode;
    assign loopback_en  = reg_loopback;
    assign listen_only  = reg_listen_only;
    assign abort_tx     = strobe_abort_tx;
    assign bus_off_rec  = strobe_bus_off_rec;

    assign btr_brp      = reg_btr_brp;
    assign btr_tseg1    = reg_btr_tseg1;
    assign btr_tseg2    = reg_btr_tseg2;
    assign btr_sjw      = reg_btr_sjw;

    assign filter_id    = reg_filter_id;
    assign filter_mask  = reg_filter_mask;

    assign tx_write     = strobe_tx_write;
    assign tx_id        = reg_tx_id;
    assign tx_rtr       = reg_tx_rtr;
    assign tx_dlc       = reg_tx_dlc;
    assign tx_data      = {reg_tx_data_l, reg_tx_data_h};

    assign rx_pop       = strobe_rx_pop;
    assign rx_clear     = strobe_rx_clear;

    // Interrupt output line is active when any enabled interrupt bit is high
    assign irq_out      = |(reg_ir_status & reg_ir_enable);

endmodule
