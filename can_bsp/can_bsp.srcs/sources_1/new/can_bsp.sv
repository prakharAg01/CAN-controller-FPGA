//=============================================================================
// Module      : can_bsp   (Bus Synchronisation Protocol -- Day 18 Complete)
// Description : Frame-level FSM for a Classical CAN 2.0A controller
//               (standard frames only, 11-bit base ID).
//
// Implementation status (Days 10-18):
//   DONE : SOF, ARBITRATION, CONTROL -- TX serialisation + bit stuffing + arb
//   DONE : DATA field -- TX serialisation from data_shift, stuffing enabled
//   DONE : CRC_FIELD  -- transmits 15-bit CRC-15 sequence + 1-bit delimiter
//                        (CRC computed over SOF..DATA using can_crc module)
//                        Delimiter form error detection.
//   DONE : ACK        -- Day 17: ACK slot & delimiter handling
//                        TX: releases bus (recessive), samples rx_bit at sample_point.
//                            If recessive -> ACK error -> ERROR_FRAME after delimiter.
//                        RX: drives dominant in ACK slot if crc_ok == 1.
//                            If crc_ok == 0 -> leaves recessive -> ERROR_FRAME.
//                        Delimiter form error detection.
//   DONE : EOF        -- Day 18: 7 recessive bits with form error detection.
//                        Bits 0..5: dominant at sample_point -> form error -> ERROR_FRAME.
//                        Bit 6 (7th): transmitter dominant -> form error -> ERROR_FRAME.
//                                     receiver dominant    -> SOF (new frame).
//   DONE : IFS        -- Day 18: 3 recessive bits (intermission).
//                        Bits 0..1: dominant at sample_point -> overload/error -> ERROR_FRAME.
//                        Bit 2 (3rd): dominant at sample_point -> SOF (receiver).
//                        Normal exit: tx_request ? SOF : IDLE.
//   DONE : ERROR_FRAME -- Day 18: 6 dominant error flag (tx_en=1, tx_bit=0) +
//                        8 recessive error delimiter (tx_en=0, tx_bit=1) = 14 bits.
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
//   ERROR_FRAME - 6 dominant error flag + 8 recessive delimiter bits (14 bits)
//
// CRC coverage (per CAN 2.0A spec):
//   Calculated over: SOF, ARBITRATION, CONTROL, DATA (de-stuffed protocol bits).
//   The CRC sequence itself is transmitted without stuffing.
//   The CRC delimiter is always recessive.
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
//   ERROR_FRAME: 14  (6 dominant flag + 8 recessive delimiter)
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
//   tx_data [63:0]     - data bytes to transmit (latched at SOF, byte 0 in [63:56])
//   stuff_error        - bit-stuffing violation detected (from destuffer)
//   crc_ok             - CRC match on received frame (from CRC checker)
//
// Outputs:
//   tx_bit             - bit this node places on the bus
//   tx_en              - 1 = this node is actively driving the bus
//   frame_active       - 1 while a frame is in progress (not IDLE/IFS)
//   ack_error          - 1 = transmitter detected ACK error in ACK slot
//   form_error         - 1 = form error detected (EOF or delimiters)
//   error_out          - 1-clk error pulse
//   state_out [3:0]    - numeric state for debug
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
    input  logic [63:0] tx_data,     // data bytes (byte 0 in [63:56], MSB sent first)

    // Error inputs
    input  logic        stuff_error, // stuffing violation from destuffer
    input  logic        crc_ok,      // CRC correct (RX path)

    // Outputs
    output logic        tx_bit,      // bit to drive on bus (held between ticks)
    output logic        tx_en,       // 1 = this node drives the bus
    output logic        frame_active,// 1 = frame in progress
    output logic        ack_error,   // 1 = transmitter detected ACK error in ACK slot
    output logic        form_error,  // 1 = form error detected (EOF or delimiters)
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
    logic [6:0]  bit_cnt;      // protocol bits elapsed within the current state
    logic [10:0] id_latch;     // latched tx_id at SOF
    logic [3:0]  dlc_latch;    // DLC captured at the start of a frame
    logic [6:0]  data_bits;    // total data-field bits = dlc_latch * 8 (0..64)

    // TX shift registers & arbitration
    logic [11:0] arb_shift;    // {id_latch[10:0], RTR}, shifts MSB first
    logic [5:0]  ctrl_shift;   // {IDE, r0, dlc_latch[3:0]}, shifts MSB first
    logic [63:0] data_shift;   // tx_data bytes, shifts MSB first during DATA
    logic        raw_tx_bit;   // un-stuffed protocol bit before the stuffer
    logic        arb_lost;     // 1 = lost arbitration during ARBITRATION

    // CRC_FIELD serialization
    logic [14:0] crc_shift;    // CRC-15 sequence latch, shifts MSB first
    logic        crc_latched;  // 1 = crc_shift has been loaded for this CRC_FIELD

    // Mode & ACK tracking (Day 17)
    logic        transmitting; // 1 = transmitter (tx_request); 0 = receiver / listener
    logic        ack_received; // 1 = dominant ACK bit sampled in ACK slot
    logic        ack_err_reg;  // 1 = transmitter sampled recessive in ACK slot

    assign ack_error = ack_err_reg;

    // Form & Overload error tracking (Day 18)
    logic        form_err_reg;
    assign form_error = form_err_reg;

    // Bit stuffer interface wires
    logic        stuff_en;
    logic        stuffer_ready;
    logic        stuffer_bit_out;
    logic        stuffer_bit_out_valid;
    logic        stuff_pending;
    logic        stuffing_active;

    // CRC module wires
    logic        crc_init_p;    // synchronous init pulse to can_crc
    logic        crc_calc_en;   // feed raw_tx_bit to CRC on each protocol bit
    logic [14:0] crc_computed;  // running/final CRC-15 value from can_crc

    // =========================================================================
    // Field-length parameters (protocol bits)
    // =========================================================================
    localparam int LEN_SOF   = 1;
    localparam int LEN_ARB   = 12;   // 11-bit ID + RTR
    localparam int LEN_CTRL  = 6;    // IDE + r0 + DLC[3:0]
    localparam int LEN_CRC   = 16;   // 15 CRC bits + delimiter
    localparam int LEN_ACK   = 2;    // slot + delimiter
    localparam int LEN_EOF   = 7;    // 7 recessive bits
    localparam int LEN_IFS   = 3;    // 3 recessive intermission bits
    localparam int LEN_ERR   = 14;   // 6 dominant flag + 8 recessive delimiter

    // =========================================================================
    // Day 18 Error Detection Conditions
    // =========================================================================
    // CRC delimiter (bit 15 of CRC_FIELD) must be recessive
    wire crc_delim_err = (state == CRC_FIELD) && (bit_cnt == 7'd15) &&
                         sample_point && (rx_bit == 1'b0);

    // ACK delimiter (bit 1 of ACK) must be recessive
    wire ack_delim_err = (state == ACK) && (bit_cnt == 7'd1) &&
                         sample_point && (rx_bit == 1'b0);

    // EOF Form Error:
    // Bits 0..5 must be recessive for all nodes.
    // Bit 6 must be recessive for transmitter; receiver treats dominant as SOF.
    wire eof_form_err  = (state == EOF) && sample_point && (rx_bit == 1'b0) &&
                         ((bit_cnt < 7'd6) || transmitting);

    // Combined form error trigger
    wire form_err_detected = crc_delim_err || ack_delim_err || eof_form_err;

    // IFS Overload / Protocol Error:
    // Bits 0 and 1 of IFS intermission must be recessive.
    // A dominant bit during bits 0..1 is an overload condition -> ERROR_FRAME.
    wire ifs_overload_err = (state == IFS) && (bit_cnt < 7'd2) &&
                            sample_point && (rx_bit == 1'b0);

    // =========================================================================
    // Bit stuffer instantiation
    // Active during SOF, ARBITRATION, CONTROL, and DATA.
    // CRC_FIELD: no stuffing (per CAN 2.0A, stuffing ends after the data field).
    // =========================================================================
    assign stuff_en = (state == SOF) || (state == ARBITRATION) ||
                      (state == CONTROL) || (state == DATA);

    // Protocol tick: strobe when a real protocol bit is consumed by the stuffer.
    // When stuffing is disabled (CRC_FIELD, ACK, EOF, IFS, ERROR_FRAME), matches bit_tick.
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
    // CRC module instantiation
    // Calculates CRC-15/CAN over SOF, ARBITRATION, CONTROL, DATA fields.
    // Initialised when the FSM transitions from IDLE, IFS, or EOF to SOF.
    // =========================================================================
    assign crc_init_p  = (state == IDLE && next_state == SOF) ||
                         (state == IFS  && next_state == SOF) ||
                         (state == EOF  && next_state == SOF);

    // calc_en: assert on every protocol tick (unstuffed bit) in the CRC coverage area.
    assign crc_calc_en = proto_tick &&
                         (state == SOF         ||
                          state == ARBITRATION ||
                          state == CONTROL     ||
                          state == DATA);

    can_crc u_crc (
        .clk     (clk),
        .rst_n   (rst_n),
        .init    (crc_init_p),
        .calc_en (crc_calc_en),
        .bit_in  (raw_tx_bit),
        .crc_out (crc_computed)
    );

    // =========================================================================
    // State and shift registers
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            bit_cnt      <= 7'd0;
            id_latch     <= 11'd0;
            dlc_latch    <= 4'd0;
            data_bits    <= 7'd0;
            arb_shift    <= 12'd0;
            ctrl_shift   <= 6'd0;
            data_shift   <= 64'd0;
            crc_shift    <= 15'd0;
            crc_latched  <= 1'b0;
            arb_lost     <= 1'b0;
            transmitting <= 1'b0;
            ack_received <= 1'b0;
            ack_err_reg  <= 1'b0;
            form_err_reg <= 1'b0;
        end else if (clear) begin
            state        <= IDLE;
            bit_cnt      <= 7'd0;
            id_latch     <= 11'd0;
            dlc_latch    <= 4'd0;
            data_bits    <= 7'd0;
            arb_shift    <= 12'd0;
            ctrl_shift   <= 6'd0;
            data_shift   <= 64'd0;
            crc_shift    <= 15'd0;
            crc_latched  <= 1'b0;
            arb_lost     <= 1'b0;
            transmitting <= 1'b0;
            ack_received <= 1'b0;
            ack_err_reg  <= 1'b0;
            form_err_reg <= 1'b0;
        end else begin
            state <= next_state;

            // Bit counter: reset to 0 on state change, increment each protocol tick
            if (next_state != state)
                bit_cnt <= 7'd0;
            else if (proto_tick)
                bit_cnt <= bit_cnt + 7'd1;

            // Form error latching
            if (form_err_detected)
                form_err_reg <= 1'b1;

            // -----------------------------------------------------------------
            // Latch frame parameters and initialise shift registers at SOF entry
            // -----------------------------------------------------------------
            if ((state == IDLE && next_state == SOF) ||
                (state == IFS  && next_state == SOF) ||
                (state == EOF  && next_state == SOF)) begin
                id_latch     <= tx_id;
                dlc_latch    <= tx_dlc;
                data_bits    <= {3'b000, tx_dlc} << 3;  // dlc * 8, max 64
                arb_shift    <= {tx_id, 1'b0};           // RTR = 0 (data frame)
                ctrl_shift   <= {1'b0, 1'b0, tx_dlc};   // IDE = 0, r0 = 0
                data_shift   <= tx_data;                  // capture host data bytes
                crc_latched  <= 1'b0;
                arb_lost     <= 1'b0;
                // If entering because bus went dominant (!rx_bit), node is receiver
                transmitting <= tx_request && !(state == IDLE && !rx_bit && sample_point)
                                           && !(state == IFS  && (bit_cnt == 7'd2) && !rx_bit && sample_point)
                                           && !(state == EOF  && (bit_cnt == 7'd6) && !rx_bit && sample_point);
                ack_received <= 1'b0;
                ack_err_reg  <= 1'b0;
                form_err_reg <= 1'b0;
            end

            // -----------------------------------------------------------------
            // Advance ARBITRATION shift register on each consumed protocol bit
            // -----------------------------------------------------------------
            if (state == ARBITRATION && proto_tick) begin
                arb_shift <= {arb_shift[10:0], 1'b1};
            end

            // -----------------------------------------------------------------
            // Advance CONTROL shift register on each consumed protocol bit
            // -----------------------------------------------------------------
            if (state == CONTROL && proto_tick) begin
                ctrl_shift <= {ctrl_shift[4:0], 1'b1};
            end

            // -----------------------------------------------------------------
            // Advance DATA shift register on each consumed protocol bit
            // -----------------------------------------------------------------
            if (state == DATA && proto_tick) begin
                data_shift <= {data_shift[62:0], 1'b1};
            end

            // -----------------------------------------------------------------
            // CRC shift register
            // -----------------------------------------------------------------
            if (state == CRC_FIELD && !crc_latched) begin
                crc_shift   <= crc_computed;
                crc_latched <= 1'b1;
            end

            if (state == CRC_FIELD && bit_tick && crc_latched && bit_cnt < 7'd15) begin
                crc_shift <= {crc_shift[13:0], 1'b1};
            end

            // -----------------------------------------------------------------
            // Lost arbitration detection:
            // During ARBITRATION at sample_point, if this node drives recessive
            // (1) but the bus is sampled dominant (0), another node with higher
            // priority won. Node is demoted to a receiver for the frame remainder.
            // -----------------------------------------------------------------
            if (state == ARBITRATION && sample_point && tx_en && !arb_lost) begin
                if (tx_bit == 1'b1 && rx_bit == 1'b0) begin
                    arb_lost     <= 1'b1;
                    transmitting <= 1'b0;
                end
            end

            // -----------------------------------------------------------------
            // ACK slot sampling (transmitter):
            // At sample_point in bit 0 of ACK, check if a receiver pulled the bus
            // dominant (rx_bit == 0). If rx_bit == 1, no receiver acknowledged.
            // -----------------------------------------------------------------
            if (state == ACK && bit_cnt == 7'd0 && sample_point && transmitting) begin
                if (rx_bit == 1'b0) begin
                    ack_received <= 1'b1;
                    ack_err_reg  <= 1'b0;
                end else begin
                    ack_received <= 1'b0;
                    ack_err_reg  <= 1'b1;
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
                if (tx_request || (!rx_bit && sample_point))
                    next_state = SOF;
            end

            // ------------------------------------------------------------------
            SOF: begin
                if (proto_tick && bit_cnt >= (LEN_SOF - 1))
                    next_state = ARBITRATION;
            end

            // ------------------------------------------------------------------
            ARBITRATION: begin
                if (proto_tick && bit_cnt >= (LEN_ARB - 1))
                    next_state = CONTROL;
            end

            // ------------------------------------------------------------------
            CONTROL: begin
                if (proto_tick && bit_cnt >= (LEN_CTRL - 1))
                    next_state = (dlc_latch == 4'd0) ? CRC_FIELD : DATA;
            end

            // ------------------------------------------------------------------
            DATA: begin
                if (proto_tick && bit_cnt >= (data_bits - 7'd1))
                    next_state = CRC_FIELD;
            end

            // ------------------------------------------------------------------
            CRC_FIELD: begin
                if (crc_delim_err) begin
                    next_state = ERROR_FRAME;
                end else if (bit_tick && bit_cnt >= (LEN_CRC - 1)) begin
                    next_state = ACK;
                end
            end

            // ------------------------------------------------------------------
            ACK: begin
                if (ack_delim_err) begin
                    next_state = ERROR_FRAME;
                end else if (bit_tick && bit_cnt >= (LEN_ACK - 1)) begin
                    if (transmitting && ack_err_reg)
                        next_state = ERROR_FRAME;
                    else if (!transmitting && !crc_ok)
                        next_state = ERROR_FRAME;
                    else
                        next_state = EOF;
                end
            end

            // ------------------------------------------------------------------
            EOF: begin
                // 7 recessive bits.
                // Bits 0..5 (or bit 6 for TX): dominant bit -> form error -> ERROR_FRAME.
                // Bit 6 for RX: dominant bit treated as SOF without error.
                if (eof_form_err) begin
                    next_state = ERROR_FRAME;
                end else if (!transmitting && (bit_cnt == 7'd6) && sample_point && (rx_bit == 1'b0)) begin
                    next_state = SOF;
                end else if (bit_tick && bit_cnt >= (LEN_EOF - 1)) begin
                    next_state = IFS;
                end
            end

            // ------------------------------------------------------------------
            IFS: begin
                // 3 recessive intermission bits.
                // Bits 0..1: dominant bit is an overload/error -> ERROR_FRAME.
                // Bit 2: dominant bit treated as SOF from another node -> SOF (RX).
                // Normal exit: start next frame if tx_request, else return to IDLE.
                if (ifs_overload_err) begin
                    next_state = ERROR_FRAME;
                end else if ((bit_cnt == 7'd2) && sample_point && (rx_bit == 1'b0)) begin
                    next_state = SOF;
                end else if (bit_tick && bit_cnt >= (LEN_IFS - 1)) begin
                    next_state = tx_request ? SOF : IDLE;
                end
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
        // Error override: any immediate error triggers ERROR_FRAME
        // ----------------------------------------------------------------------
        if (stuff_error || form_err_detected || ifs_overload_err)
            next_state = ERROR_FRAME;
    end

    // =========================================================================
    // Output logic
    // =========================================================================

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
            SOF:         raw_tx_bit = 1'b0;              // dominant SOF
            ARBITRATION: raw_tx_bit = arb_shift[11];     // 11-bit ID + RTR (MSB first)
            CONTROL:     raw_tx_bit = ctrl_shift[5];     // IDE(0)+r0(0)+DLC[3:0] (MSB first)
            DATA:        raw_tx_bit = data_shift[63];    // data bytes, MSB first
            CRC_FIELD:   raw_tx_bit = (bit_cnt < 7'd15) // 15 CRC bits then delimiter
                                      ? crc_shift[14]
                                      : 1'b1;
            ACK:         raw_tx_bit = (!transmitting && (bit_cnt == 7'd0) && crc_ok)
                                      ? 1'b0             // RX drives dominant in ACK slot if CRC ok
                                      : 1'b1;            // TX and delimiter drive recessive
            EOF:         raw_tx_bit = 1'b1;              // 7 recessive bits
            ERROR_FRAME: raw_tx_bit = (bit_cnt < 7'd6)   // 6 dominant flag, 8 recessive delimiter
                                      ? 1'b0
                                      : 1'b1;
            IFS:         raw_tx_bit = 1'b1;              // 3 recessive intermission bits
            default:     raw_tx_bit = 1'b1;              // idle recessive
        endcase
    end

    // Actual bus bit driven:
    // During non-stuffed states (ACK, EOF, IFS, ERROR_FRAME), bypass stuffer register
    // to keep bus level and enable in exact cycle-accurate phase.
    // In stuffed protocol states, drive from stuffer.
    assign tx_bit = (state == ACK || state == EOF || state == IFS || state == ERROR_FRAME)
                  ? raw_tx_bit
                  : stuffer_bit_out;

    // Bus drive enable:
    // When ERROR_FRAME: actively drive dominant for first 6 bits (error flag), release during delimiter.
    // When transmitting standard frame fields: drive as long as arbitration is not lost.
    // When receiver in ACK slot with valid CRC: actively drive dominant ACK bit.
    // In EOF, IFS, and IDLE: bus is released / recessive (tx_en = 0).
    assign tx_en = (state == ERROR_FRAME) ? (bit_cnt < 7'd6) :
                   (!arb_lost && (state == SOF         ||
                                  state == ARBITRATION ||
                                  state == CONTROL     ||
                                  state == DATA        ||
                                  state == CRC_FIELD)) ||
                   (!transmitting && (state == ACK) && (bit_cnt == 7'd0) && crc_ok);

endmodule
