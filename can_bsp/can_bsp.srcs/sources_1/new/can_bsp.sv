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
    // Internal registers
    // =========================================================================
    logic [6:0] bit_cnt;    // counts bits elapsed within the current state
    logic [3:0] dlc_latch;  // DLC captured at the start of a frame
    logic [5:0] data_bits;  // total data-field bits = dlc_latch * 8 (max 64)

    // =========================================================================
    // Field-length parameters
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
    // State register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            bit_cnt <= 7'd0;
        end else if (clear) begin
            state   <= IDLE;
            bit_cnt <= 7'd0;
        end else begin
            state <= next_state;

            // Bit counter: reset to 0 on state change, increment each tick
            if (next_state != state)
                bit_cnt <= 7'd0;
            else if (bit_tick)
                bit_cnt <= bit_cnt + 7'd1;
        end
    end

    // Latch DLC when entering SOF so DATA length is fixed for the frame
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dlc_latch <= 4'd0;
            data_bits <= 6'd0;
        end else if (state == IDLE && next_state == SOF) begin
            dlc_latch <= tx_dlc;
            data_bits <= {2'b00, tx_dlc} << 3;   // dlc * 8, max 64
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
                // TODO: add lost-arbitration handling once TX is implemented.
                if (tx_request || (!rx_bit && sample_point))
                    next_state = SOF;
            end

            // ------------------------------------------------------------------
            SOF: begin
                // 1 bit; move to ARBITRATION after it has been sent/sampled
                if (bit_tick && bit_cnt >= (LEN_SOF - 1))
                    next_state = ARBITRATION;
            end

            // ------------------------------------------------------------------
            ARBITRATION: begin
                // 12 bits (11-bit ID + RTR)
                // TODO: lost arbitration check -- if tx_en and rx_bit != tx_bit
                //       at sample point, switch to RX-only and stay in ARBITRATION.
                if (bit_tick && bit_cnt >= (LEN_ARB - 1))
                    next_state = CONTROL;
            end

            // ------------------------------------------------------------------
            CONTROL: begin
                // 6 bits (IDE + r0 + DLC)
                if (bit_tick && bit_cnt >= (LEN_CTRL - 1))
                    next_state = (dlc_latch == 4'd0) ? CRC_FIELD : DATA;
            end

            // ------------------------------------------------------------------
            DATA: begin
                // dlc_latch * 8 bits (0..64); data_bits was captured at SOF
                if (bit_tick && {1'b0, bit_cnt} >= (data_bits - 6'd1))
                    next_state = CRC_FIELD;
            end

            // ------------------------------------------------------------------
            CRC_FIELD: begin
                // 15 CRC bits + 1 delimiter = 16 bits
                // TODO: check crc_ok at the delimiter sample point (RX path).
                if (bit_tick && bit_cnt >= (LEN_CRC - 1))
                    next_state = ACK;
            end

            // ------------------------------------------------------------------
            ACK: begin
                // 2 bits: ACK slot + ACK delimiter
                // TODO: TX node checks that rx_bit is dominant in slot (bit 0).
                //       RX node drives dominant in slot.
                if (bit_tick && bit_cnt >= (LEN_ACK - 1))
                    next_state = EOF;
            end

            // ------------------------------------------------------------------
            EOF: begin
                // 7 recessive bits
                // TODO: form error if a dominant bit is detected here.
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
                // TODO: implement error-active vs error-passive flag lengths
                //       once the Error Management Logic (EML) is in place.
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
    // TX driver stub
    // TODO: replace with proper TX serialiser hooks once each field's
    //       bit-generation logic is implemented.
    // ------------------------------------------------------------------
    always_comb begin
        tx_bit = 1'b1;    // recessive (safe default)
        tx_en  = 1'b0;

        case (state)
            SOF:         begin tx_bit = 1'b0; tx_en = 1'b1; end  // dominant SOF
            ARBITRATION: begin tx_bit = 1'b1; tx_en = 1'b1; end  // TODO: shift tx_id
            CONTROL:     begin tx_bit = 1'b1; tx_en = 1'b1; end  // TODO: shift control field
            DATA:        begin tx_bit = 1'b1; tx_en = 1'b1; end  // TODO: shift data bytes
            CRC_FIELD:   begin tx_bit = 1'b1; tx_en = 1'b1; end  // TODO: shift CRC sequence
            ACK:         begin tx_bit = 1'b1; tx_en = 1'b0; end  // TX releases; RX pulls dominant
            EOF:         begin tx_bit = 1'b1; tx_en = 1'b1; end  // 7 recessive
            ERROR_FRAME: begin tx_bit = 1'b0; tx_en = 1'b1; end  // 6 dominant error flag
            default:     begin tx_bit = 1'b1; tx_en = 1'b0; end  // idle / IFS
        endcase
    end

endmodule
