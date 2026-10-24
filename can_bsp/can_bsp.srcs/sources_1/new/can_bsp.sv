//=============================================================================
// Module      : can_bsp   (Bus Synchronisation Protocol -- FSM skeleton)
// Description : Frame-level FSM for a Classical CAN 2.0A controller
//               (standard frames only, 11-bit base ID).
//
// This is an intentional SKELETON. States and transitions are fully wired;
// the per-field bit-level logic (TX serialisation, CRC feed, stuffing hooks,
// ACK check, error classification) is left as clearly marked TODO stubs so
// that each piece can be added and tested independently.
//
// State encoding:
//   IDLE        - bus idle, waiting for SOF or tx_request
//   SOF         - start-of-frame dominant bit (1 bit)
//   ARBITRATION - 11-bit base ID + RTR bit (12 bits total)
//   CONTROL     - IDE + r0 + DLC[3:0] (6 bits)
//   DATA        - 0..8 data bytes (DLC * 8 bits, 0 when DLC = 0)
//   CRC_FIELD   - 15-bit CRC sequence + 1-bit recessive delimiter (16 bits)
//   ACK         - 1-bit ACK slot + 1-bit recessive delimiter (2 bits)
//   EOF         - 7 recessive bits
//   IFS         - interframe space: 3 recessive bits
//   ERROR_FRAME - 6 dominant error flag + up to 8 recessive delimiter bits
//
// Field-length constants (bit counts, 1-based):
//   SOF        : 1
//   ARBITRATION: 12  (11-bit ID + RTR, standard frame)
//   CONTROL    : 6   (IDE + r0 + DLC[3:0])
//   DATA       : DLC * 8  (0..64)
//   CRC_FIELD  : 16  (15 CRC bits + delimiter)
//   ACK        : 2   (slot + delimiter)
//   EOF        : 7
//   IFS        : 3
//   ERROR_FRAME: 14  (6 dominant + 8 delimiter; simplified)
//
// Inputs:
//   clk, rst_n         - system clock, async active-low reset
//   clear              - synchronous abort (error / overload from outside)
//   bit_tick           - 1-clk strobe once per CAN bit time (from BTL)
//   sample_point       - 1-clk strobe at the sample point (from BTL)
//   rx_bit             - bus value captured at the sample point (from BTL)
//   tx_request         - host requests a transmission
//   tx_id [10:0]       - identifier to transmit (latched at SOF)
//   tx_dlc [3:0]       - data length code (0..8, latched at SOF)
//   stuff_error        - bit-stuffing violation detected (from destuffer)
//   crc_ok             - CRC match on received frame (from CRC checker)
//
// Outputs:
//   tx_bit             - bit this node places on the bus
//   tx_en              - 1 = this node is actively driving the bus
//   frame_active       - 1 while a frame is in progress (not IDLE/IFS)
//   error_out          - 1-clk pulse when an error is detected
//   state_out [3:0]    - current state (numeric), for debug / integration
//=============================================================================

module can_bsp (
    input  logic        clk,
    input  logic        rst_n,       // async active-low reset
    input  logic        clear,       // synchronous abort

    // BTL interface
    input  logic        bit_tick,    // 1-clk strobe, once per CAN bit time
    input  logic        sample_point,// 1-clk strobe at sample point
    input  logic        rx_bit,      // bus bit captured at sample point

    // Host / TX buffer interface
    input  logic        tx_request,  // host has a frame ready to send
    input  logic [10:0] tx_id,       // frame identifier
    input  logic [3:0]  tx_dlc,      // data length code (0..8)

    // Error inputs
    input  logic        stuff_error, // stuffing violation from destuffer
    input  logic        crc_ok,      // CRC correct (RX path)

    // Outputs
    output logic        tx_bit,      // bit to drive on bus (held between ticks)
    output logic        tx_en,       // 1 = this node drives the bus
    output logic        frame_active,// 1 = frame in progress
    output logic        error_out,   // 1-clk error pulse
    output logic [3:0]  state_out    // numeric state for debug
);

    // =========================================================================
    // State definition
    // =========================================================================
    typedef enum logic [3:0] {
        IDLE        = 4'd0,
        SOF         = 4'd1,
        ARBITRATION = 4'd2,
        CONTROL     = 4'd3,
        DATA        = 4'd4,
        CRC_FIELD   = 4'd5,
        ACK         = 4'd6,
        EOF         = 4'd7,
        IFS         = 4'd8,
        ERROR_FRAME = 4'd9
    } bsp_state_t;

    bsp_state_t state, next_state;

    // =========================================================================
    // =========================================================================
    // Internal registers
    // =========================================================================
    logic [6:0]  bit_cnt;      // counts protocol bits elapsed within the current state
    logic [10:0] id_latch;     // latched tx_id at SOF
    logic [3:0]  dlc_latch;    // DLC captured at the start of a frame
    logic [6:0]  data_bits;    // total data-field bits = dlc_latch * 8 (0..64)

    // TX shift registers & arbitration
    logic [11:0] arb_shift;    // {id_latch[10:0], RTR}, shifts MSB first
    logic [5:0]  ctrl_shift;   // {IDE, r0, dlc_latch[3:0]}, shifts MSB first
    logic        raw_tx_bit;   // un-stuffed protocol bit before the stuffer
    logic        arb_lost;     // 1 = lost arbitration during ARBITRATION

    // Bit stuffer interface wires
    logic        stuff_en;
    logic        stuffer_ready;
    logic        stuffer_bit_out;
    logic        stuffer_bit_out_valid;
    logic        stuff_pending;
    logic        stuffing_active;

    // =========================================================================
    // Field-length parameters (protocol bits)
    // =========================================================================
    localparam int LEN_SOF   = 1;
    localparam int LEN_ARB   = 12;   // 11-bit ID + RTR
    localparam int LEN_CTRL  = 6;    // IDE + r0 + DLC[3:0]
    localparam int LEN_CRC   = 16;   // 15 CRC bits + delimiter
    localparam int LEN_ACK   = 2;    // slot + delimiter
    localparam int LEN_EOF   = 7;
    localparam int LEN_IFS   = 3;
    localparam int LEN_ERR   = 14;   // 6 dominant flag + 8 delimiter

    // =========================================================================
    // Bit stuffer instantiation
    // Active during SOF, ARBITRATION, and CONTROL (DATA and CRC will be enabled when implemented)
    // =========================================================================
    assign stuff_en = (state == SOF) || (state == ARBITRATION) || (state == CONTROL);

    // Protocol tick: strobe when a real protocol bit is consumed by stuffer.
    // When stuffing is disabled (or idle/delimiters), it matches bit_tick.
    wire proto_tick = stuff_en ? stuffer_ready : bit_tick;

    can_bit_stuffer u_stuffer (
        .clk           (clk),
        .rst_n         (rst_n),
        .clear         (clear),
        .bit_tick      (bit_tick),
        .stuff_en      (stuff_en),
        .data_valid    (1'b1),
        .bit_in        (raw_tx_bit),
        .ready         (stuffer_ready),
        .stuff_pending (stuff_pending),
        .bit_out       (stuffer_bit_out),
        .bit_out_valid (stuffer_bit_out_valid),
        .stuffing      (stuffing_active)
    );

    // =========================================================================
    // State and shift registers
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            bit_cnt    <= 7'd0;
            id_latch   <= 11'd0;
            dlc_latch  <= 4'd0;
            data_bits  <= 6'd0;
            arb_shift  <= 12'd0;
            ctrl_shift <= 6'd0;
            arb_lost   <= 1'b0;
        end else if (clear) begin
            state      <= IDLE;
            bit_cnt    <= 7'd0;
            id_latch   <= 11'd0;
            dlc_latch  <= 4'd0;
            data_bits  <= 6'd0;
            arb_shift  <= 12'd0;
            ctrl_shift <= 6'd0;
            arb_lost   <= 1'b0;
        end else begin
            state <= next_state;

            // Bit counter: reset to 0 on state change, increment each protocol tick
            if (next_state != state)
                bit_cnt <= 7'd0;
            else if (proto_tick)
                bit_cnt <= bit_cnt + 7'd1;

            // Latch frame parameters and initialize shift registers when entering SOF
            if ((state == IDLE && next_state == SOF) || (state == IFS && next_state == SOF)) begin
                id_latch   <= tx_id;
                dlc_latch  <= tx_dlc;
                data_bits  <= {3'b000, tx_dlc} << 3;   // dlc * 8, max 64
                arb_shift  <= {tx_id, 1'b0};          // RTR = 0 (data frame)
                ctrl_shift <= {1'b0, 1'b0, tx_dlc};   // IDE = 0, r0 = 0
                arb_lost   <= 1'b0;
            end

            // Advance ARBITRATION shift register on each consumed protocol bit
            if (state == ARBITRATION && proto_tick) begin
                arb_shift <= {arb_shift[10:0], 1'b1};
            end

            // Advance CONTROL shift register on each consumed protocol bit
            if (state == CONTROL && proto_tick) begin
                ctrl_shift <= {ctrl_shift[4:0], 1'b1};
            end

            // Lost arbitration detection:
            // During ARBITRATION at sample_point, if this node drives recessive (1)
            // but the bus is sampled dominant (0), another node with higher priority won.
            if (state == ARBITRATION && sample_point && tx_en && !arb_lost) begin
                if (tx_bit == 1'b1 && rx_bit == 1'b0) begin
                    arb_lost <= 1'b1;
                end
            end
        end
    end

    // =========================================================================
    // Next-state logic (combinational)
    // =========================================================================
    always_comb begin
        next_state = state;   // default: stay

        case (state)

            // ------------------------------------------------------------------
            IDLE: begin
                // Enter SOF when:
                //   TX path : host requests a frame (tx_request)
                //   RX path : a dominant SOF bit is seen on the bus
                if (tx_request || (!rx_bit && sample_point))
                    next_state = SOF;
            end

            // ------------------------------------------------------------------
            SOF: begin
                // 1 bit; move to ARBITRATION after it has been sent/sampled
                if (proto_tick && bit_cnt >= (LEN_SOF - 1))
                    next_state = ARBITRATION;
            end

            // ------------------------------------------------------------------
            ARBITRATION: begin
                // 12 protocol bits (11-bit ID + RTR)
                if (proto_tick && bit_cnt >= (LEN_ARB - 1))
                    next_state = CONTROL;
            end

            // ------------------------------------------------------------------
            CONTROL: begin
                // 6 protocol bits (IDE + r0 + DLC)
                if (proto_tick && bit_cnt >= (LEN_CTRL - 1))
                    next_state = (dlc_latch == 4'd0) ? CRC_FIELD : DATA;
            end

            // ------------------------------------------------------------------
            DATA: begin
                // dlc_latch * 8 bits (0..64); data_bits was captured at SOF
                if (proto_tick && bit_cnt >= (data_bits - 7'd1))
                    next_state = CRC_FIELD;
            end

            // ------------------------------------------------------------------
            CRC_FIELD: begin
                // 15 CRC bits + 1 delimiter = 16 bits
                if (bit_tick && bit_cnt >= (LEN_CRC - 1))
                    next_state = ACK;
            end

            // ------------------------------------------------------------------
            ACK: begin
                // 2 bits: ACK slot + ACK delimiter
                if (bit_tick && bit_cnt >= (LEN_ACK - 1))
                    next_state = EOF;
            end

            // ------------------------------------------------------------------
            EOF: begin
                // 7 recessive bits
                if (bit_tick && bit_cnt >= (LEN_EOF - 1))
                    next_state = IFS;
            end

            // ------------------------------------------------------------------
            IFS: begin
                // 3 recessive bits; return to IDLE (or SOF if pending frame)
                if (bit_tick && bit_cnt >= (LEN_IFS - 1))
                    next_state = tx_request ? SOF : IDLE;
            end

            // ------------------------------------------------------------------
            ERROR_FRAME: begin
                // 6 dominant error flag + 8 recessive delimiter = 14 bits
                if (bit_tick && bit_cnt >= (LEN_ERR - 1))
                    next_state = IFS;
            end

            default: next_state = IDLE;

        endcase

        // ----------------------------------------------------------------------
        // Error override: any error input forces ERROR_FRAME immediately.
        // Checked after the case so it takes priority over all normal transitions.
        // ----------------------------------------------------------------------
        if (stuff_error || (!crc_ok && state == CRC_FIELD && bit_tick && bit_cnt >= (LEN_CRC - 1)))
            next_state = ERROR_FRAME;
    end

    // =========================================================================
    // Output logic
    // =========================================================================

    // State output for debug / integration
    assign state_out = state;

    // Frame active while not in IDLE or IFS
    assign frame_active = (state != IDLE) && (state != IFS);

    // Error pulse: one clock wide, asserted when entering ERROR_FRAME
    assign error_out = (next_state == ERROR_FRAME) && (state != ERROR_FRAME);

    // ------------------------------------------------------------------
    // Un-stuffed protocol bit multiplexer
    // ------------------------------------------------------------------
    always_comb begin
        case (state)
            SOF:         raw_tx_bit = 1'b0;            // dominant SOF
            ARBITRATION: raw_tx_bit = arb_shift[11];   // 11-bit ID + RTR (MSB first)
            CONTROL:     raw_tx_bit = ctrl_shift[5];   // IDE(0) + r0(0) + DLC[3:0] (MSB first)
            DATA:        raw_tx_bit = 1'b1;            // TODO: shift data bytes
            CRC_FIELD:   raw_tx_bit = 1'b1;            // TODO: shift CRC sequence
            ACK:         raw_tx_bit = 1'b1;            // TX releases; RX pulls dominant
            EOF:         raw_tx_bit = 1'b1;            // 7 recessive
            ERROR_FRAME: raw_tx_bit = 1'b0;            // 6 dominant error flag
            default:     raw_tx_bit = 1'b1;            // idle / IFS recessive
        endcase
    end

    // Actual bus bit driven is the output of the bit stuffer
    assign tx_bit = stuffer_bit_out;

    // Bus drive enable:
    // When ERROR_FRAME, actively drive error flag.
    // When transmitting standard frame fields, drive as long as arbitration is not lost.
    assign tx_en = (state == ERROR_FRAME) ? 1'b1 :
                   (!arb_lost && (state == SOF || state == ARBITRATION ||
                                  state == CONTROL || state == DATA ||
                                  state == CRC_FIELD || state == EOF));

endmodule
