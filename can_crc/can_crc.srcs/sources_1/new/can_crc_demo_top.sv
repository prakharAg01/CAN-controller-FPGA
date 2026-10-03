//=============================================================================
// Module      : can_crc_demo_top
// Description : FPGA demonstration wrapper for CAN CRC-15.
//
// Board       : Digilent Nexys 4 DDR
//
// Controls:
//   SW0       : input data bit
//   BTNC      : initialize CRC to 0
//   BTNU      : process one data bit
//
// Outputs:
//   LED[14:0] : current CRC-15 value
//   LED[15]   : flashes/toggles when a bit is processed
//=============================================================================

module can_crc_demo_top #(
    parameter int CLK_HZ      = 100_000_000,
    parameter int DEBOUNCE_MS = 20
)(
    input  logic        clk,
    input  logic        rst_btn_raw,
    input  logic        step_btn_raw,
    input  logic        data_sw,

    output logic [14:0] led_crc,
    output logic        led_activity
);

    // ------------------------------------------------------------------------
    // Internal reset
    // ------------------------------------------------------------------------
    logic rst_n;
    assign rst_n = ~rst_btn_raw;


    // ------------------------------------------------------------------------
    // Synchronize push button
    // ------------------------------------------------------------------------
    logic step_sync0;
    logic step_sync1;
    logic step_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_sync0 <= 1'b0;
            step_sync1 <= 1'b0;
            step_prev  <= 1'b0;
        end
        else begin
            step_sync0 <= step_btn_raw;
            step_sync1 <= step_sync0;
            step_prev  <= step_sync1;
        end
    end

    wire step_edge = step_sync1 & ~step_prev;


    // ------------------------------------------------------------------------
    // Simple debounce
    // ------------------------------------------------------------------------
    localparam int DEBOUNCE_CYCLES =
        (CLK_HZ / 1000) * DEBOUNCE_MS;

    localparam int DB_W =
        $clog2(DEBOUNCE_CYCLES + 1);

    logic [DB_W-1:0] db_cnt;
    logic            db_lock;
    logic            bit_pulse;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            db_cnt    <= '0;
            db_lock   <= 1'b0;
            bit_pulse <= 1'b0;
        end
        else begin
            bit_pulse <= 1'b0;

            if (db_lock) begin
                if (db_cnt == DEBOUNCE_CYCLES-1) begin
                    db_cnt  <= '0;
                    db_lock <= 1'b0;
                end
                else begin
                    db_cnt <= db_cnt + 1'b1;
                end
            end
            else if (step_edge) begin
                bit_pulse <= 1'b1;
                db_lock   <= 1'b1;
                db_cnt    <= '0;
            end
        end
    end


    // ------------------------------------------------------------------------
    // CAN CRC module
    // ------------------------------------------------------------------------
    logic [14:0] crc_value;

    can_crc u_crc (
        .clk     (clk),
        .rst_n   (rst_n),
        .init    (1'b0),
        .calc_en (bit_pulse),
        .bit_in  (data_sw),
        .crc_out (crc_value)
    );


    // ------------------------------------------------------------------------
    // LEDs
    // ------------------------------------------------------------------------
    assign led_crc = crc_value;

    // Toggle on every processed bit so we can confirm button operation.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            led_activity <= 1'b0;
        else if (bit_pulse)
            led_activity <= ~led_activity;
    end

endmodule