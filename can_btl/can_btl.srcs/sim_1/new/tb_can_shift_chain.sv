//=============================================================================
// Testbench : tb_can_shift_chain          (Day 5 integration)
//
//   TX BSP model --> can_tx_shift --> can_bit_stuffer --> [bus delay] --> can_btl
//        |  (+ can_crc)                                                      |
//        |                                       sample_point / rx_bit       v
//   RX BSP model <-- can_rx_shift <-- can_bit_destuffer <-----------------------
//        (+ can_crc, compared with the received CRC field)
//
// The two "BSP" blocks are SMALL BEHAVIOURAL STAND-INS for the real frame state
// machine (Day 6+); they show how the Day 5 modules are meant to be driven:
//
//   TX groups (each one load of can_tx_shift, loaded when the previous 'done'):
//     1 header {SOF,ID,RTR,IDE,r0,DLC}  19 bits   (CRC is fed from tx.xfer)
//     2 data    8*DLC bits                         (CRC is fed from tx.xfer)
//     3 CRC     15 bits    (stuffed)               (value = can_crc after group 2)
//     4 tail    13 bits    (CRC delim, ACK slot, ACK delim, EOF x7, IFS x3, NOT stuffed)
//   RX fields (can_rx_shift len set per field; changed when 'done' is seen):
//     12 (SOF+ID) -> 7 (RTR,IDE,r0,DLC) -> 8 x DLC -> 15 (CRC) -> 0 (ignore)
//
// For every frame it checks: ID, control bits, DLC, every data byte, the
// transmitted CRC, the CRC the receiver computed itself, the CRC field the
// receiver got, no stuff error, no rejected TX load.
// Reference CRC: independent shift-and-XOR function in this file.
//=============================================================================
`timescale 1ns/1ps

module tb_can_shift_chain;

    logic clk = 0, rst_n = 0, clear = 0;
    always #5 clk = ~clk;

    // ---------------- timing configuration ----------------
    logic [7:0] brp   = 3;
    logic [3:0] tseg1 = 5;
    logic [2:0] tseg2 = 2;
    integer     dly   = 0;                  // bus / transceiver delay in clocks
    integer     P     = 40;

    // ---------------- BTL ----------------
    wire tq_tick, bit_tick, sample_point, btl_rx_bit, hs_w, rf_w, rl_w;
    wire [1:0] seg_state;
    wire rx_in;

    can_btl u_btl (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .brp(brp), .tseg1(tseg1), .tseg2(tseg2), .sjw(2'd1),
        .hsync_en(1'b0), .rsync_en(1'b0), .tx_dominant(1'b0),
        .rx_in(rx_in),
        .tq_tick(tq_tick), .bit_tick(bit_tick), .sample_point(sample_point),
        .rx_bit(btl_rx_bit), .seg_state(seg_state),
        .hard_sync(hs_w), .resync_full(rf_w), .resync_limited(rl_w)
    );

    // ---------------- frame to send ----------------
    logic [10:0] f_id   = 0;
    logic [3:0]  f_dlc  = 0;
    logic [63:0] f_data = 0;
    logic        tx_start = 0;
    wire  [3:0]  dlc_b  = (f_dlc > 8) ? 4'd8 : f_dlc;      // data bytes actually sent

    // ---------------- TX side ----------------
    logic        tx_load = 0;
    logic [63:0] tx_load_data = 0;
    logic [6:0]  tx_load_len = 0;
    wire         tx_valid, tx_bit, tx_last, tx_xfer, tx_done, tx_rej;
    wire  [6:0]  tx_rem;
    wire         stf_ready, stf_pend, bus_bit, bus_valid, stf_stuffing;
    logic [2:0]  tx_grp = 0;                               // 0 idle,1 hdr,2 data,3 crc,4 tail,5 finished
    logic        tx_crc_init = 0;
    wire  [14:0] tx_crc;

    can_tx_shift #(.WIDTH(64)) u_tx (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .load(tx_load), .load_data(tx_load_data), .load_len(tx_load_len),
        .shift_en(stf_ready),
        .valid(tx_valid), .bit_out(tx_bit), .last(tx_last), .xfer(tx_xfer),
        .remaining(tx_rem), .done(tx_done), .load_rejected(tx_rej)
    );

    wire tx_stuff_en = (tx_grp >= 3'd1) && (tx_grp <= 3'd3);   // header..CRC are stuffed, tail is not

    can_bit_stuffer u_stuffer (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .bit_tick(bit_tick), .stuff_en(tx_stuff_en),
        .data_valid(tx_valid), .bit_in(tx_bit),
        .ready(stf_ready), .stuff_pending(stf_pend),
        .bit_out(bus_bit), .bit_out_valid(bus_valid), .stuffing(stf_stuffing)
    );

    can_crc u_crc_tx (
        .clk(clk), .rst_n(rst_n), .init(tx_crc_init | clear),
        .calc_en(tx_xfer & ((tx_grp == 3'd1) | (tx_grp == 3'd2))),
        .bit_in(tx_bit), .crc_out(tx_crc)
    );

    // TX BSP stand-in: load the next group in the clock after 'done'
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_grp <= 0; tx_load <= 0; tx_crc_init <= 0;
            tx_load_data <= 0; tx_load_len <= 0;
        end else if (clear) begin
            tx_grp <= 0; tx_load <= 0; tx_crc_init <= 0;
        end else begin
            tx_load <= 0; tx_crc_init <= 0;
            case (tx_grp)
                3'd0: if (tx_start) begin
                    tx_crc_init  <= 1;
                    tx_load      <= 1;
                    tx_load_data <= {1'b0, f_id, 3'b000, f_dlc, 45'b0};   // SOF, ID, RTR, IDE, r0, DLC
                    tx_load_len  <= 7'd19;
                    tx_grp       <= 3'd1;
                end
                3'd1: if (tx_done) begin
                    tx_load <= 1;
                    if (dlc_b != 0) begin
                        tx_load_data <= f_data;
                        tx_load_len  <= {dlc_b, 3'b000};                  // 8 * DLC
                        tx_grp       <= 3'd2;
                    end else begin
                        tx_load_data <= {tx_crc, 49'b0};
                        tx_load_len  <= 7'd15;
                        tx_grp       <= 3'd3;
                    end
                end
                3'd2: if (tx_done) begin
                    tx_load      <= 1;
                    tx_load_data <= {tx_crc, 49'b0};
                    tx_load_len  <= 7'd15;
                    tx_grp       <= 3'd3;
                end
                3'd3: if (tx_done) begin
                    tx_load      <= 1;
                    tx_load_data <= {64{1'b1}};
                    tx_load_len  <= 7'd13;
                    tx_grp       <= 3'd4;
                end
                3'd4: if (tx_done) tx_grp <= 3'd5;
                default: ;
            endcase
        end
    end

    // ---------------- bus / transceiver delay ----------------
    logic [31:0] dly_sr = 32'hFFFF_FFFF;
    always @(posedge clk) dly_sr <= {dly_sr[30:0], bus_bit};
    assign rx_in = (dly == 0) ? bus_bit : dly_sr[dly - 1];

    // ---------------- RX side ----------------
    logic       rx_run = 0;
    always @(posedge clk)
        if (clear)          rx_run <= 1'b0;
        else if (bus_valid) rx_run <= 1'b1;

    logic [2:0] rx_phase = 0;                              // 0 id,1 ctrl,2 data,3 crc,4 finished
    logic [4:0] rx_len   = 12;
    wire        destuff_en = rx_run && (rx_phase <= 3'd3);
    wire        dstf_bit, dstf_dv, dstf_err, dstf_exp;

    can_bit_destuffer u_destuffer (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .destuff_en(destuff_en),
        .bit_valid(sample_point & rx_run), .bit_in(btl_rx_bit),
        .bit_out(dstf_bit), .data_valid(dstf_dv),
        .stuff_error(dstf_err), .stuff_expected(dstf_exp)
    );

    wire [15:0] rx_data;
    wire [4:0]  rx_cnt;
    wire        rx_done;

    can_rx_shift #(.WIDTH(16)) u_rx (
        .clk(clk), .rst_n(rst_n), .clear(clear),
        .len(rx_len), .bit_valid(dstf_dv), .bit_in(dstf_bit),
        .data(rx_data), .count(rx_cnt), .done(rx_done)
    );

    wire [14:0] rx_crc;
    can_crc u_crc_rx (
        .clk(clk), .rst_n(rst_n), .init(clear),
        .calc_en(dstf_dv & (rx_phase <= 3'd2)),
        .bit_in(dstf_bit), .crc_out(rx_crc)
    );

    logic [11:0] r_sofid;
    logic [6:0]  r_ctrl;
    logic [7:0]  r_bytes [0:7];
    integer      r_bidx;
    logic [14:0] r_crc, r_crc_calc;
    logic        rx_complete = 0;
    wire  [3:0]  r_dlc_raw = r_ctrl[3:0];
    wire  [3:0]  r_dlc     = (r_dlc_raw > 8) ? 4'd8 : r_dlc_raw;

    // RX BSP stand-in: pick fields as they complete, set len for the next one
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_phase <= 0; rx_len <= 12; r_bidx <= 0; rx_complete <= 0;
        end else if (clear) begin
            rx_phase <= 0; rx_len <= 12; r_bidx <= 0; rx_complete <= 0;
        end else if (rx_done) begin
            case (rx_phase)
                3'd0: begin r_sofid <= rx_data[11:0]; rx_phase <= 3'd1; rx_len <= 5'd7; end
                3'd1: begin
                    r_ctrl <= rx_data[6:0]; r_bidx <= 0;
                    if (rx_data[3:0] == 4'd0) begin rx_phase <= 3'd3; rx_len <= 5'd15; end
                    else                      begin rx_phase <= 3'd2; rx_len <= 5'd8;  end
                end
                3'd2: begin
                    r_bytes[r_bidx] <= rx_data[7:0];
                    r_bidx <= r_bidx + 1;
                    if (r_bidx + 1 >= r_dlc) begin rx_phase <= 3'd3; rx_len <= 5'd15; end
                end
                3'd3: begin
                    r_crc <= rx_data[14:0];
                    r_crc_calc <= rx_crc;                    // CRC computed by the receiver itself
                    rx_phase <= 3'd4; rx_len <= 5'd0;        // ignore everything after the CRC field
                    rx_complete <= 1;
                end
                default: ;
            endcase
        end
    end

    // ---------------- independent CRC reference ----------------
    function [14:0] crc15_ref(input [10:0] id, input [3:0] dlcv, input [63:0] data);
        reg [127:0] bits;
        integer n, i, nb;
        reg [14:0] c;
        reg fb;
        begin
            n = 0;
            bits[n] = 1'b0; n = n + 1;                                     // SOF
            for (i = 10; i >= 0; i = i - 1) begin bits[n] = id[i]; n = n + 1; end
            bits[n] = 1'b0; n = n + 1;                                     // RTR
            bits[n] = 1'b0; n = n + 1;                                     // IDE
            bits[n] = 1'b0; n = n + 1;                                     // r0
            for (i = 3; i >= 0; i = i - 1) begin bits[n] = dlcv[i]; n = n + 1; end
            nb = (dlcv > 8) ? 8 : dlcv;
            for (i = 0; i < 8 * nb; i = i + 1) begin bits[n] = data[63 - i]; n = n + 1; end
            c = 15'd0;
            for (i = 0; i < n; i = i + 1) begin
                fb = bits[i] ^ c[14];
                c  = {c[13:0], 1'b0};
                if (fb) c = c ^ 15'h4599;
            end
            crc15_ref = c;
        end
    endfunction

    // ---------------- monitors ----------------
    integer n_err = 0, n_tx_rej = 0, n_stuff = 0;
    logic [14:0] crc_sent;
    always @(posedge clk) begin
        if (dstf_err)     n_err = n_err + 1;
        if (tx_rej)       n_tx_rej = n_tx_rej + 1;
        if (stf_stuffing && bus_valid) n_stuff = n_stuff + 1;
        if (tx_load && tx_load_len == 7'd15) crc_sent = tx_load_data[63:49];
    end

    // ---------------- frame runner ----------------
    integer total_frames = 0, total_fail = 0, total_stuff = 0, frames_with_trailing = 0;
    integer bad, k, guard, nb_i;
    logic [14:0] exp_crc;

    task run_frame(input [10:0] id, input [3:0] dlc, input [63:0] data);
        begin
            @(negedge clk); clear = 1;
            @(negedge clk); clear = 0;
            n_err = 0; n_tx_rej = 0; n_stuff = 0;
            f_id = id; f_dlc = dlc; f_data = data;
            exp_crc = crc15_ref(id, dlc, data);

            @(negedge clk); tx_start = 1;
            @(negedge clk); tx_start = 0;

            guard = 0;
            while (!(rx_complete && tx_grp == 3'd5) && guard < P * 400) begin
                @(negedge clk); guard = guard + 1;
            end
            repeat (4) @(negedge clk);

            bad = 0;
            nb_i = (dlc > 8) ? 8 : dlc;
            if (guard >= P * 400)                    begin bad = bad + 1; $display("   timeout"); end
            if (r_sofid !== {1'b0, id})              begin bad = bad + 1; $display("   SOF/ID got %h expected %h", r_sofid, {1'b0, id}); end
            if (r_ctrl  !== {3'b000, dlc})           begin bad = bad + 1; $display("   ctrl got %h expected %h", r_ctrl, {3'b000, dlc}); end
            for (k = 0; k < nb_i; k = k + 1)
                if (r_bytes[k] !== data[63 - 8*k -: 8]) begin
                    bad = bad + 1;
                    $display("   byte %0d got %h expected %h", k, r_bytes[k], data[63 - 8*k -: 8]);
                end
            if (crc_sent  !== exp_crc)               begin bad = bad + 1; $display("   TX CRC %h expected %h", crc_sent, exp_crc); end
            if (r_crc     !== exp_crc)               begin bad = bad + 1; $display("   RX CRC field %h expected %h", r_crc, exp_crc); end
            if (r_crc_calc !== exp_crc)              begin bad = bad + 1; $display("   RX computed CRC %h expected %h", r_crc_calc, exp_crc); end
            if (n_err != 0)                          begin bad = bad + 1; $display("   %0d stuff errors", n_err); end
            if (n_tx_rej != 0)                       begin bad = bad + 1; $display("   %0d rejected TX loads", n_tx_rej); end

            total_frames = total_frames + 1;
            total_stuff  = total_stuff + n_stuff;
            if (bad != 0) begin
                total_fail = total_fail + 1;
                $display("[FAIL] frame id=%h dlc=%0d data=%h", id, dlc, data);
            end
        end
    endtask

    task set_cfg(input [7:0] b, input [3:0] t1, input [2:0] t2, input integer d, input [8*40-1:0] tag);
        begin
            @(negedge clk);
            brp = b; tseg1 = t1; tseg2 = t2; dly = d;
            P = (t1 + t2 + 3) * (b + 1);
            $display("--- %0s: BRP=%0d TSEG1=%0d TSEG2=%0d, bit=%0d clk, sample@%0d, bus delay=%0d clk ---",
                     tag, b, t1, t2, P, (t1 + 2) * (b + 1), d);
        end
    endtask

    task frame_set(input integer n_random, input [8*40-1:0] tag);
        integer r, f0, f1;
        reg [10:0] id;
        reg [3:0]  dl;
        reg [63:0] dt;
        begin
            f0 = total_fail;
            // fixed frames: long dominant/recessive runs (lots of stuffing), edge cases
            run_frame(11'h000, 4'd8, 64'h0000000000000000);
            run_frame(11'h7FF, 4'd8, 64'hFFFFFFFFFFFFFFFF);
            run_frame(11'h555, 4'd0, 64'h0);
            run_frame(11'h2AA, 4'd1, 64'hAA00000000000000);
            run_frame(11'h123, 4'd8, 64'h0123456789ABCDEF);
            run_frame(11'h001, 4'd2, 64'h8000000000000000);
            for (r = 0; r < n_random; r = r + 1) begin
                id = $urandom;
                dl = $urandom % 9;
                dt = {$urandom, $urandom};
                if (($urandom % 4) == 0) dt = dt & {$urandom, $urandom} & {$urandom, $urandom};  // zero-heavy
                if (($urandom % 4) == 0) dt = dt | {$urandom, $urandom} | {$urandom, $urandom};  // one-heavy
                run_frame(id, dl, dt);
            end
            if (total_fail == f0) $display("[PASS] %0s: %0d frames (6 fixed + %0d random), all fields + CRC + no stuff errors",
                                           tag, 6 + n_random, n_random);
            else                  $display("[FAIL] %0s: %0d frame(s) failed", tag, total_fail - f0);
        end
    endtask

    // ---------------- main ----------------
    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        set_cfg(3, 5, 2, 0,  "C1 no delay");
        frame_set(30, "C1");

        set_cfg(3, 5, 2, 10, "C2 250 ns-class loop delay (10 clk)");
        frame_set(30, "C2");

        set_cfg(0, 9, 3, 6,  "C3 1 clk per TQ, short bit");
        frame_set(20, "C3");

        $display("----------------------------------------------------");
        $display("frames sent: %0d,  stuff bits inserted in total: %0d", total_frames, total_stuff);
        if (total_fail == 0) $display("ALL SHIFT-CHAIN TESTS PASSED (%0d frames)", total_frames);
        else                 $display("%0d FRAME(S) FAILED", total_fail);
        $display("----------------------------------------------------");
        $finish;
    end

endmodule