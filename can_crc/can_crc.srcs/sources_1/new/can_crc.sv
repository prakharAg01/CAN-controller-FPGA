//=============================================================================
// Module      : can_crc
// Description : Bit-serial CRC-15 calculator for Classical CAN 2.0A/B frames.
//
// Polynomial  : x^15 + x^14 + x^10 + x^8 + x^7 + x^4 + x^3 + 1
//               Polynomial without the x^15 term = 15'h4599
// Initial CRC : 15'h0000
//
// Feed one DESTUFFED protocol bit per asserted calc_en cycle.
// The CRC is calculated over the bit sequence from SOF through the end of
// the Data Field. The generated CRC sequence is then transmitted separately.
//
// IMPORTANT:
// Bit stuffing is a separate operation. CRC calculation is performed on the
// original/de-stuffed protocol bits, not on inserted stuff bits.
//=============================================================================

module can_crc (
    input  logic        clk,
    input  logic        rst_n,      // asynchronous active-low reset
    input  logic        init,       // synchronous clear; pulse before first CRC bit
    input  logic        calc_en,    // process bit_in when high
    input  logic        bit_in,     // next destuffed protocol bit
    output logic [14:0] crc_out     // running/final CRC-15 value
);

    logic feedback;

    // MSB-first CRC update.
    assign feedback = bit_in ^ crc_out[14];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_out <= 15'h0000;
        end
        else if (init) begin
            crc_out <= 15'h0000;
        end
        else if (calc_en) begin
            // Equivalent to:
            // crc_next = (crc_out << 1) ^
            //            (feedback ? 15'h4599 : 15'h0000);
            //
            // 15'h4599 has taps at bits 14,10,8,7,4,3,0.
            crc_out[14] <= crc_out[13] ^ feedback;
            crc_out[13] <= crc_out[12];
            crc_out[12] <= crc_out[11];
            crc_out[11] <= crc_out[10];
            crc_out[10] <= crc_out[9]  ^ feedback;
            crc_out[9]  <= crc_out[8];
            crc_out[8]  <= crc_out[7]  ^ feedback;
            crc_out[7]  <= crc_out[6]  ^ feedback;
            crc_out[6]  <= crc_out[5];
            crc_out[5]  <= crc_out[4];
            crc_out[4]  <= crc_out[3]  ^ feedback;
            crc_out[3]  <= crc_out[2]  ^ feedback;
            crc_out[2]  <= crc_out[1];
            crc_out[1]  <= crc_out[0];
            crc_out[0]  <= feedback;
        end
        // else: hold the CRC value
    end

endmodule