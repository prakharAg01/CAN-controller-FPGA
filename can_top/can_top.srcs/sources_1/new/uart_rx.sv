// =============================================================================
// Module      : uart_rx
// Description : Standard 8-N-1 UART Receiver clocked at 100 MHz.
//               Decodes 115,200 baud serial stream with mid-bit sampling.
// =============================================================================

module uart_rx #(
    parameter int CLKS_PER_BIT = 868 // 100,000,000 / 115,200 = 868.05
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       uart_rxd,     // Physical UART RX pin

    output logic       rx_valid,     // 1-clk strobe when rx_data is valid
    output logic [7:0] rx_data       // Received byte
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_START,
        ST_DATA,
        ST_STOP
    } state_t;

    state_t state;

    // 2-stage synchronizer to prevent metastability
    logic rxd_sync1, rxd_sync2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_sync1 <= 1'b1;
            rxd_sync2 <= 1'b1;
        end else begin
            rxd_sync1 <= uart_rxd;
            rxd_sync2 <= rxd_sync1;
        end
    end

    logic [15:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  data_shift;
    logic        valid_reg;

    assign rx_valid = valid_reg;
    assign rx_data  = data_shift;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            clk_cnt    <= 16'd0;
            bit_idx    <= 3'd0;
            data_shift <= 8'd0;
            valid_reg  <= 1'b0;
        end else begin
            valid_reg <= 1'b0; // Default 1-clk strobe

            case (state)
                ST_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    // Detect falling edge of start bit
                    if (rxd_sync2 == 1'b0) begin
                        state <= ST_START;
                    end
                end

                ST_START: begin
                    // Sample at the middle of the start bit (CLKS_PER_BIT / 2)
                    if (clk_cnt == (CLKS_PER_BIT / 2)) begin
                        if (rxd_sync2 == 1'b0) begin
                            clk_cnt <= 16'd0;
                            state   <= ST_DATA;
                        end else begin
                            state   <= ST_IDLE; // False start glitch
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                ST_DATA: begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt              <= 16'd0;
                        data_shift[bit_idx]  <= rxd_sync2; // LSB first
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            state   <= ST_STOP;
                        end
                    end
                end

                ST_STOP: begin
                    // Wait for the stop bit duration
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt   <= 16'd0;
                        state     <= ST_IDLE;
                        if (rxd_sync2 == 1'b1) begin
                            valid_reg <= 1'b1; // Valid frame received
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
