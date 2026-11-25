// =============================================================================
// Module      : uart_tx
// Description : Standard 8-N-1 UART Transmitter clocked at 100 MHz.
//               Generates 115,200 baud serial stream (868 clocks per bit).
// =============================================================================

module uart_tx #(
    parameter int CLKS_PER_BIT = 868 // 100,000,000 / 115,200 = 868.05
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       tx_valid,     // 1-clk strobe: start transmitting tx_data
    input  logic [7:0] tx_data,      // Byte to transmit
    output logic       tx_ready,     // High when ready to accept next byte

    output logic       uart_txd      // Physical UART TX pin (idle high)
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_START,
        ST_DATA,
        ST_STOP
    } state_t;

    state_t state;

    logic [15:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  data_latch;
    logic        txd_reg;

    assign uart_txd = txd_reg;
    assign tx_ready = (state == ST_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            clk_cnt    <= 16'd0;
            bit_idx    <= 3'd0;
            data_latch <= 8'd0;
            txd_reg    <= 1'b1; // Idle high
        end else begin
            case (state)
                ST_IDLE: begin
                    txd_reg <= 1'b1;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_valid) begin
                        data_latch <= tx_data;
                        state      <= ST_START;
                    end
                end

                ST_START: begin
                    txd_reg <= 1'b0; // Start bit dominant (0)
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= ST_DATA;
                    end
                end

                ST_DATA: begin
                    txd_reg <= data_latch[bit_idx]; // LSB first
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            state   <= ST_STOP;
                        end
                    end
                end

                ST_STOP: begin
                    txd_reg <= 1'b1; // Stop bit recessive (1)
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
