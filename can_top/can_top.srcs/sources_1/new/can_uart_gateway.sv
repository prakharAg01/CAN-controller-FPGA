// =============================================================================
// Module      : can_uart_gateway
// Description : Day 38: UART Host Gateway & Protocol Bridge.
//               Connects USB-UART (115200 baud) to CAN Host Register Interface.
//               - Automatically drains RX FIFO and streams frames to PC in ASCII.
//               - Triggers CAN frame transmission on PC command or BTNU.
//               - Monitors status, error counters, and bus state.
// =============================================================================

module can_uart_gateway (
    input  logic        clk,
    input  logic        rst_n,

    // Physical UART Pins
    input  logic        uart_rxd,     // Nexys 4 DDR Pin D4 (PC -> FPGA)
    output logic        uart_txd,     // Nexys 4 DDR Pin C4 (FPGA -> PC)

    // Hardware Button & Switches
    input  logic        btn_send_pulse,
    input  logic        sw_loopback,
    input  logic        sw_pad_loopback,

    // Host Register Interface (to can_regs)
    output logic        reg_cs,
    output logic        reg_we,
    output logic [7:0]  reg_addr,
    output logic [31:0] reg_wdata,
    input  logic [31:0] reg_rdata,
    input  logic        reg_ack,
    input  logic        irq_out,
    input  logic        rx_fifo_empty,

    // Status output for board LEDs
    output logic [3:0]  gw_state_led,
    output logic [7:0]  rx_frame_count
);

    // -------------------------------------------------------------------------
    // CAN Register Memory Map
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
    // UART RX & TX Submodules
    // -------------------------------------------------------------------------
    logic       uart_tx_valid;
    logic [7:0] uart_tx_data;
    wire        uart_tx_ready;

    logic       uart_rx_valid;
    logic [7:0] uart_rx_data;

    uart_tx #(.CLKS_PER_BIT(868)) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_valid (uart_tx_valid),
        .tx_data  (uart_tx_data),
        .tx_ready (uart_tx_ready),
        .uart_txd (uart_txd)
    );

    uart_rx #(.CLKS_PER_BIT(868)) u_rx (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_rxd (uart_rxd),
        .rx_valid (uart_rx_valid),
        .rx_data  (uart_rx_data)
    );

    // -------------------------------------------------------------------------
    // ASCII Hex Conversion Helper Function
    // -------------------------------------------------------------------------
    function automatic [7:0] hex2ascii(input logic [3:0] nibble);
        return (nibble < 4'd10) ? (8'h30 + {4'd0, nibble}) : (8'h41 + {4'd0, nibble - 4'd10});
    endfunction

    // -------------------------------------------------------------------------
    // UART Output String Buffer
    // -------------------------------------------------------------------------
    logic [7:0] tx_buf [0:63];
    logic [5:0] tx_len;
    logic [5:0] tx_ptr;
    logic       tx_active;

    // Latched frame data
    logic [31:0] rx_hdr_latched;
    logic [31:0] rx_dl_latched;
    logic [31:0] rx_dh_latched;
    logic [31:0] ecr_latched;
    logic [31:0] fifo_cnt_latched;

    // -------------------------------------------------------------------------
    // Gateway Main FSM
    // -------------------------------------------------------------------------
    typedef enum logic [4:0] {
        INIT_BTR,
        INIT_AFID,
        INIT_AFMSK,
        INIT_IR_IE,
        INIT_MODECR,
        BANNER_START,
        BANNER_SEND,
        GW_IDLE,
        // RX FIFO Drain Sequence
        RX_READ_HDR,
        RX_READ_DL,
        RX_READ_DH,
        RX_POP_FIFO,
        RX_CLEAR_IRQ,
        RX_FORMAT_MSG,
        RX_SEND_MSG,
        // TX Frame Sequence
        TX_SET_MODE,
        TX_SET_HDR,
        TX_SET_DL,
        TX_TRIGGER,
        TX_FORMAT_MSG,
        TX_SEND_MSG,
        // Status Query Sequence
        STAT_READ_ECR,
        STAT_READ_FIFO,
        STAT_FORMAT_MSG,
        STAT_SEND_MSG
    } gw_fsm_t;

    gw_fsm_t state;
    assign gw_state_led = state[3:0];

    logic [7:0] total_rx_frames;
    assign rx_frame_count = total_rx_frames;

    // Internal request flags
    logic req_tx;
    logic req_stat;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= INIT_BTR;
            reg_cs           <= 1'b0;
            reg_we           <= 1'b0;
            reg_addr         <= 8'h00;
            reg_wdata        <= 32'h0;
            tx_ptr           <= 6'd0;
            tx_len           <= 6'd0;
            tx_active        <= 1'b0;
            uart_tx_valid    <= 1'b0;
            uart_tx_data     <= 8'h0;
            rx_hdr_latched   <= 32'd0;
            rx_dl_latched    <= 32'd0;
            rx_dh_latched    <= 32'd0;
            ecr_latched      <= 32'd0;
            fifo_cnt_latched <= 32'd0;
            total_rx_frames  <= 8'd0;
            req_tx           <= 1'b0;
            req_stat         <= 1'b0;
        end else begin
            uart_tx_valid <= 1'b0; // Default

            // Latch user input commands from button or UART RX
            if (btn_send_pulse) begin
                req_tx <= 1'b1;
            end else if (uart_rx_valid) begin
                if (uart_rx_data == "t" || uart_rx_data == "T" || uart_rx_data == " ") begin
                    req_tx <= 1'b1;
                end else if (uart_rx_data == "s" || uart_rx_data == "S") begin
                    req_stat <= 1'b1;
                end
            end

            case (state)
                // -------------------------------------------------------------
                // 1. Core Power-Up Configuration
                // -------------------------------------------------------------
                INIT_BTR: begin
                    // Write BTR = 0x00012513 (500 kbps @ 100 MHz, 70% sample point, SJW=2)
                    reg_cs    <= 1'b1;
                    reg_we    <= 1'b1;
                    reg_addr  <= ADDR_BTR;
                    reg_wdata <= 32'h00012513;
                    if (reg_ack) begin
                        reg_addr  <= ADDR_AFID;
                        reg_wdata <= 32'h00000000;
                        state     <= INIT_AFID;
                    end
                end

                INIT_AFID: begin
                    if (reg_ack) begin
                        reg_addr  <= ADDR_AFMSK;
                        reg_wdata <= 32'h00000000; // Accept all IDs
                        state     <= INIT_AFMSK;
                    end
                end

                INIT_AFMSK: begin
                    if (reg_ack) begin
                        reg_addr  <= ADDR_IR_IE;
                        reg_wdata <= 32'h00020000; // Enable RX_VALID interrupt ONLY (prevents false TX_DONE triggers)
                        state     <= INIT_IR_IE;
                    end
                end

                INIT_IR_IE: begin
                    if (reg_ack) begin
                        reg_addr  <= ADDR_MODECR;
                        reg_wdata <= (sw_loopback || sw_pad_loopback) ? 32'h00000002 : 32'h00000000;
                        state     <= INIT_MODECR;
                    end
                end

                INIT_MODECR: begin
                    if (reg_ack) begin
                        reg_cs <= 1'b0;
                        reg_we <= 1'b0;
                        state  <= BANNER_START;
                    end
                end

                // -------------------------------------------------------------
                // 2. Transmit Welcome Banner
                // -------------------------------------------------------------
                BANNER_START: begin
                    // "\r\n[CAN-GATEWAY READY 500k]\r\n"
                    tx_buf[0]  <= "\r"; tx_buf[1]  <= "\n";
                    tx_buf[2]  <= "[";  tx_buf[3]  <= "C";  tx_buf[4]  <= "A";  tx_buf[5]  <= "N";
                    tx_buf[6]  <= "-";  tx_buf[7]  <= "G";  tx_buf[8]  <= "A";  tx_buf[9]  <= "T";
                    tx_buf[10] <= "E";  tx_buf[11] <= "W";  tx_buf[12] <= "A";  tx_buf[13] <= "Y";
                    tx_buf[14] <= " ";  tx_buf[15] <= "R";  tx_buf[16] <= "E";  tx_buf[17] <= "A";
                    tx_buf[18] <= "D";  tx_buf[19] <= "Y";  tx_buf[20] <= " ";  tx_buf[21] <= "5";
                    tx_buf[22] <= "0";  tx_buf[23] <= "0";  tx_buf[24] <= "k";  tx_buf[25] <= "]";
                    tx_buf[26] <= "\r"; tx_buf[27] <= "\n";
                    tx_len     <= 6'd28;
                    tx_ptr     <= 6'd0;
                    state      <= BANNER_SEND;
                end

                BANNER_SEND: begin
                    if (tx_ptr < tx_len) begin
                        if (uart_tx_ready && !uart_tx_valid) begin
                            uart_tx_valid <= 1'b1;
                            uart_tx_data  <= tx_buf[tx_ptr];
                            tx_ptr        <= tx_ptr + 6'd1;
                        end
                    end else begin
                        state <= GW_IDLE;
                    end
                end

                // -------------------------------------------------------------
                // 3. Main Idle / Arbiter State
                // -------------------------------------------------------------
                GW_IDLE: begin
                    reg_cs <= 1'b0;
                    reg_we <= 1'b0;

                    // Priority 1: Service incoming CAN frames whenever FIFO has data
                    if (!rx_fifo_empty) begin
                        reg_cs   <= 1'b1;
                        reg_we   <= 1'b0;
                        reg_addr <= ADDR_RX_HEADER;
                        state    <= RX_READ_HDR;
                    end
                    // Priority 2: Service pending TX requests
                    else if (req_tx) begin
                        req_tx    <= 1'b0;
                        reg_cs    <= 1'b1;
                        reg_we    <= 1'b1;
                        reg_addr  <= ADDR_MODECR;
                        reg_wdata <= (sw_loopback || sw_pad_loopback) ? 32'h00000002 : 32'h00000000;
                        state     <= TX_SET_MODE;
                    end
                    // Priority 3: Service status query
                    else if (req_stat) begin
                        req_stat <= 1'b0;
                        reg_cs   <= 1'b1;
                        reg_we   <= 1'b0;
                        reg_addr <= ADDR_ECR;
                        state    <= STAT_READ_ECR;
                    end
                end

                // -------------------------------------------------------------
                // 4. RX Frame Drain & Display
                // -------------------------------------------------------------
                RX_READ_HDR: begin
                    if (reg_ack) begin
                        rx_hdr_latched <= reg_rdata;
                        reg_addr       <= ADDR_RX_DATA_L;
                        state          <= RX_READ_DL;
                    end
                end

                RX_READ_DL: begin
                    if (reg_ack) begin
                        rx_dl_latched <= reg_rdata;
                        reg_addr      <= ADDR_RX_DATA_H;
                        state         <= RX_READ_DH;
                    end
                end

                RX_READ_DH: begin
                    if (reg_ack) begin
                        rx_dh_latched <= reg_rdata;
                        // Strobe CMR[1] = 1 (rx_pop) to clear head of RX FIFO
                        reg_we        <= 1'b1;
                        reg_addr      <= ADDR_CMR;
                        reg_wdata     <= 32'h00000002;
                        state         <= RX_POP_FIFO;
                    end
                end

                RX_POP_FIFO: begin
                    if (reg_ack) begin
                        // Clear interrupt flag: Write 1 to IR_IE[1] (RX_VALID) while keeping enable mask active
                        reg_addr  <= ADDR_IR_IE;
                        reg_wdata <= 32'h00020002;
                        state     <= RX_CLEAR_IRQ;
                    end
                end

                RX_CLEAR_IRQ: begin
                    if (reg_ack) begin
                        reg_cs          <= 1'b0;
                        reg_we          <= 1'b0;
                        total_rx_frames <= total_rx_frames + 8'd1;
                        state           <= RX_FORMAT_MSG;
                    end
                end

                RX_FORMAT_MSG: begin
                    // Format: "[CAN_RX] ID: 0x244 | DLC: 4 | DATA: DE AD BE EF\r\n"
                    tx_buf[0]  <= "["; tx_buf[1]  <= "C"; tx_buf[2]  <= "A"; tx_buf[3]  <= "N";
                    tx_buf[4]  <= "_"; tx_buf[5]  <= "R"; tx_buf[6]  <= "X"; tx_buf[7]  <= "]";
                    tx_buf[8]  <= " "; tx_buf[9]  <= "I"; tx_buf[10] <= "D"; tx_buf[11] <= ":";
                    tx_buf[12] <= " "; tx_buf[13] <= "0"; tx_buf[14] <= "x";
                    // 3 hex digits for 11-bit ID
                    tx_buf[15] <= hex2ascii(rx_hdr_latched[10:8]);
                    tx_buf[16] <= hex2ascii(rx_hdr_latched[7:4]);
                    tx_buf[17] <= hex2ascii(rx_hdr_latched[3:0]);
                    tx_buf[18] <= " "; tx_buf[19] <= "|"; tx_buf[20] <= " ";
                    tx_buf[21] <= "D"; tx_buf[22] <= "L"; tx_buf[23] <= "C"; tx_buf[24] <= ":";
                    tx_buf[25] <= " ";
                    tx_buf[26] <= hex2ascii(rx_hdr_latched[19:16]); // DLC
                    tx_buf[27] <= " "; tx_buf[28] <= "|"; tx_buf[29] <= " ";
                    tx_buf[30] <= "D"; tx_buf[31] <= "A"; tx_buf[32] <= "T"; tx_buf[33] <= "A";
                    tx_buf[34] <= ":"; tx_buf[35] <= " ";

                    // Payload Bytes 0..3 (Left-justified from rx_dl_latched)
                    tx_buf[36] <= hex2ascii(rx_dl_latched[31:28]);
                    tx_buf[37] <= hex2ascii(rx_dl_latched[27:24]);
                    tx_buf[38] <= " ";
                    tx_buf[39] <= hex2ascii(rx_dl_latched[23:20]);
                    tx_buf[40] <= hex2ascii(rx_dl_latched[19:16]);
                    tx_buf[41] <= " ";
                    tx_buf[42] <= hex2ascii(rx_dl_latched[15:12]);
                    tx_buf[43] <= hex2ascii(rx_dl_latched[11:8]);
                    tx_buf[44] <= " ";
                    tx_buf[45] <= hex2ascii(rx_dl_latched[7:4]);
                    tx_buf[46] <= hex2ascii(rx_dl_latched[3:0]);
                    tx_buf[47] <= "\r";
                    tx_buf[48] <= "\n";

                    tx_len     <= 6'd49;
                    tx_ptr     <= 6'd0;
                    state      <= RX_SEND_MSG;
                end

                RX_SEND_MSG: begin
                    if (tx_ptr < tx_len) begin
                        if (uart_tx_ready && !uart_tx_valid) begin
                            uart_tx_valid <= 1'b1;
                            uart_tx_data  <= tx_buf[tx_ptr];
                            tx_ptr        <= tx_ptr + 6'd1;
                        end
                    end else begin
                        state <= GW_IDLE; // Immediately check if more frames in FIFO!
                    end
                end

                // -------------------------------------------------------------
                // 5. TX Frame Transmission
                // -------------------------------------------------------------
                TX_SET_MODE: begin
                    if (reg_ack) begin
                        reg_addr  <= ADDR_TX_HEADER;
                        reg_wdata <= 32'h00040155; // ID: 0x155, DLC: 4
                        state     <= TX_SET_HDR;
                    end
                end

                TX_SET_HDR: begin
                    if (reg_ack) begin
                        reg_addr  <= ADDR_TX_DATA_L;
                        reg_wdata <= 32'h11223344; // Payload: 11 22 33 44
                        state     <= TX_SET_DL;
                    end
                end

                TX_SET_DL: begin
                    if (reg_ack) begin
                        reg_addr  <= ADDR_CMR;
                        reg_wdata <= 32'h00000001; // TX_REQ strobe
                        state     <= TX_TRIGGER;
                    end
                end

                TX_TRIGGER: begin
                    if (reg_ack) begin
                        reg_cs <= 1'b0;
                        reg_we <= 1'b0;
                        state  <= TX_FORMAT_MSG;
                    end
                end

                TX_FORMAT_MSG: begin
                    // "[CAN_TX] ID: 0x155 | DLC: 4 | DATA: 11 22 33 44 [QUEUED]\r\n"
                    tx_buf[0]  <= "[";  tx_buf[1]  <= "C";  tx_buf[2]  <= "A";  tx_buf[3]  <= "N";
                    tx_buf[4]  <= "_";  tx_buf[5]  <= "T";  tx_buf[6]  <= "X";  tx_buf[7]  <= "]";
                    tx_buf[8]  <= " ";  tx_buf[9]  <= "I";  tx_buf[10] <= "D";  tx_buf[11] <= ":";
                    tx_buf[12] <= " ";  tx_buf[13] <= "0";  tx_buf[14] <= "x";  tx_buf[15] <= "1";
                    tx_buf[16] <= "5";  tx_buf[17] <= "5";  tx_buf[18] <= " ";  tx_buf[19] <= "|";
                    tx_buf[20] <= " ";  tx_buf[21] <= "D";  tx_buf[22] <= "L";  tx_buf[23] <= "C";
                    tx_buf[24] <= ":";  tx_buf[25] <= " ";  tx_buf[26] <= "4";  tx_buf[27] <= " ";
                    tx_buf[28] <= "|";  tx_buf[29] <= " ";  tx_buf[30] <= "D";  tx_buf[31] <= "A";
                    tx_buf[32] <= "T";  tx_buf[33] <= "A";  tx_buf[34] <= ":";  tx_buf[35] <= " ";
                    tx_buf[36] <= "1";  tx_buf[37] <= "1";  tx_buf[38] <= " ";  tx_buf[39] <= "2";
                    tx_buf[40] <= "2";  tx_buf[41] <= " ";  tx_buf[42] <= "3";  tx_buf[43] <= "3";
                    tx_buf[44] <= " ";  tx_buf[45] <= "4";  tx_buf[46] <= "4";  tx_buf[47] <= " ";
                    tx_buf[48] <= "[";  tx_buf[49] <= "S";  tx_buf[50] <= "E";  tx_buf[51] <= "N";
                    tx_buf[52] <= "T";  tx_buf[53] <= "]";  tx_buf[54] <= "\r"; tx_buf[55] <= "\n";

                    tx_len     <= 6'd56;
                    tx_ptr     <= 6'd0;
                    state      <= TX_SEND_MSG;
                end

                TX_SEND_MSG: begin
                    if (tx_ptr < tx_len) begin
                        if (uart_tx_ready && !uart_tx_valid) begin
                            uart_tx_valid <= 1'b1;
                            uart_tx_data  <= tx_buf[tx_ptr];
                            tx_ptr        <= tx_ptr + 6'd1;
                        end
                    end else begin
                        state <= GW_IDLE;
                    end
                end

                // -------------------------------------------------------------
                // 6. Status Query Display
                // -------------------------------------------------------------
                STAT_READ_ECR: begin
                    if (reg_ack) begin
                        ecr_latched <= reg_rdata;
                        reg_addr    <= ADDR_FIFO_CNT;
                        state       <= STAT_READ_FIFO;
                    end
                end

                STAT_READ_FIFO: begin
                    if (reg_ack) begin
                        fifo_cnt_latched <= reg_rdata;
                        reg_cs           <= 1'b0;
                        reg_we           <= 1'b0;
                        state            <= STAT_FORMAT_MSG;
                    end
                end

                STAT_FORMAT_MSG: begin
                    // "[STAT] TEC: 00 | REC: 00 | FIFO: 0\r\n"
                    tx_buf[0]  <= "["; tx_buf[1]  <= "S"; tx_buf[2]  <= "T"; tx_buf[3]  <= "A";
                    tx_buf[4]  <= "T"; tx_buf[5]  <= "]"; tx_buf[6]  <= " "; tx_buf[7]  <= "T";
                    tx_buf[8]  <= "E"; tx_buf[9]  <= "C"; tx_buf[10] <= ":"; tx_buf[11] <= " ";
                    tx_buf[12] <= hex2ascii(ecr_latched[15:12]);
                    tx_buf[13] <= hex2ascii(ecr_latched[11:8]);
                    tx_buf[14] <= " "; tx_buf[15] <= "|"; tx_buf[16] <= " ";
                    tx_buf[17] <= "R"; tx_buf[18] <= "E"; tx_buf[19] <= "C"; tx_buf[20] <= ":";
                    tx_buf[21] <= " ";
                    tx_buf[22] <= hex2ascii(ecr_latched[7:4]);
                    tx_buf[23] <= hex2ascii(ecr_latched[3:0]);
                    tx_buf[24] <= " "; tx_buf[25] <= "|"; tx_buf[26] <= " ";
                    tx_buf[27] <= "F"; tx_buf[28] <= "I"; tx_buf[29] <= "F"; tx_buf[30] <= "O";
                    tx_buf[31] <= ":"; tx_buf[32] <= " ";
                    tx_buf[33] <= hex2ascii(fifo_cnt_latched[3:0]);
                    tx_buf[34] <= "\r"; tx_buf[35] <= "\n";

                    tx_len     <= 6'd36;
                    tx_ptr     <= 6'd0;
                    state      <= STAT_SEND_MSG;
                end

                STAT_SEND_MSG: begin
                    if (tx_ptr < tx_len) begin
                        if (uart_tx_ready && !uart_tx_valid) begin
                            uart_tx_valid <= 1'b1;
                            uart_tx_data  <= tx_buf[tx_ptr];
                            tx_ptr        <= tx_ptr + 6'd1;
                        end
                    end else begin
                        state <= GW_IDLE;
                    end
                end

                default: state <= GW_IDLE;
            endcase
        end
    end

endmodule
