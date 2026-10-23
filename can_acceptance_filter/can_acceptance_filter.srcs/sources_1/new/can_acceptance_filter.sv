//=============================================================================
// Module      : can_acceptance_filter
// Description : Acceptance filter for Classical CAN 2.0A standard frames.
//               Implements single-filter ID + mask matching on the received
//               11-bit base identifier (standard frame format only).
//
// Operation:
//   A received frame is ACCEPTED when, for every bit position i:
//       mask[i] = 0  (don't-care)  OR  id[i] = filter_id[i]
//
//   Equivalently:
//       accept = ( (rx_id ^ filter_id) & filter_mask ) == 11'h000
//
//   filter_mask bit = 1 : the corresponding ID bit MUST match filter_id.
//   filter_mask bit = 0 : the corresponding ID bit is a don't-care.
//
// Notes:
//   - Standard frame format only (11-bit base ID, no extended 29-bit ID).
//   - Purely combinational -- no clock or reset required.
//   - The filter_id and filter_mask registers are typically loaded from a
//     configuration interface before a frame is received; for this standalone
//     module they are simple inputs.
//   - filter_mask = 11'h7FF accepts only one specific ID.
//   - filter_mask = 11'h000 accepts every ID (promiscuous mode).
//   - To reject all frames, drive filter_mask = 11'h7FF and choose a
//     filter_id value that can never appear on the bus.
//=============================================================================

module can_acceptance_filter (
    // Received frame identifier (11-bit, standard format)
    input  logic [10:0] rx_id,

    // Filter configuration (typically register-driven)
    input  logic [10:0] filter_id,      // reference identifier to match against
    input  logic [10:0] filter_mask,    // 1 = relevant bit (must match), 0 = don't-care

    // Result (combinational)
    output logic        accept          // 1 = frame passes the filter; 0 = reject
);

    // Bit-wise masked comparison:
    //   For every bit where filter_mask is 1, rx_id must equal filter_id.
    //   Bits where filter_mask is 0 are ignored.
    assign accept = ( (rx_id ^ filter_id) & filter_mask ) == 11'h000;

endmodule
