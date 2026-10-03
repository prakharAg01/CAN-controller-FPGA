# File saved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0 threadsafe
# 
# non-default properties - (restore without -noprops)
property -colorscheme classic
property attrcolor #000000
property attrfontsize 8
property autobundle 1
property backgroundcolor #ffffff
property boxcolor0 #000000
property boxcolor1 #000000
property boxcolor2 #000000
property boxinstcolor #000000
property boxpincolor #000000
property buscolor #008000
property closeenough 5
property createnetattrdsp 2048
property decorate 1
property elidetext 40
property fillcolor1 #ffffcc
property fillcolor2 #dfebf8
property fillcolor3 #f0f0f0
property gatecellname 2
property instattrmax 30
property instdrag 15
property instorder 1
property marksize 12
property maxfontsize 15
property maxzoom 6.25
property netcolor #19b400
property objecthighlight0 #ff00ff
property objecthighlight1 #ffff00
property objecthighlight2 #00ff00
property objecthighlight3 #0095ff
property objecthighlight4 #8000ff
property objecthighlight5 #ffc800
property objecthighlight7 #00ffff
property objecthighlight8 #ff00ff
property objecthighlight9 #ccccff
property objecthighlight10 #0ead00
property objecthighlight11 #cefc00
property objecthighlight12 #9e2dbe
property objecthighlight13 #ba6a29
property objecthighlight14 #fc0188
property objecthighlight15 #02f990
property objecthighlight16 #f1b0fb
property objecthighlight17 #fec004
property objecthighlight18 #149bff
property objecthighlight19 #eb591b
property overlaycolor #19b400
property pbuscolor #000000
property pbusnamecolor #000000
property pinattrmax 20
property pinorder 2
property pinpermute 0
property portcolor #000000
property portnamecolor #000000
property ripindexfontsize 4
property rippercolor #000000
property rubberbandcolor #000000
property rubberbandfontsize 15
property selectattr 0
property selectionappearance 2
property selectioncolor #0000ff
property sheetheight 44
property sheetwidth 68
property showmarks 1
property shownetname 0
property showpagenumbers 1
property showripindex 1
property timelimit 1
#
module new can_stuff_destuff_demo_top work:can_stuff_destuff_demo_top:NOFILE -nosplit
load symbol RTL_ROM1 work GEN pin O output.right pinBus A input.left [25:0] fillcolor 1
load symbol RTL_REG_ASYNC__BREG_5 workCLR GEN pin C input.clk.left pin CLR input.neg.top pin D input.left pin Q output.right fillcolor 1
load symbol RTL_MUX15 work MUX pin I0 input.left pin I1 input.left pin O output.right pin S input.bot fillcolor 1
load symbol RTL_ADD3 work RTL(+) pin I1 input.left pinBus I0 input.left [20:0] pinBus O output.right [20:0] fillcolor 1
load symbol RTL_MUX80 work MUX pinBus I0 input.left [20:0] pinBus I1 input.left [20:0] pinBus O output.right [20:0] pinBus S input.bot [20:0] fillcolor 1
load symbol RTL_MUX79 work MUX pin S input.bot pinBus I0 input.left [20:0] pinBus I1 input.left [20:0] pinBus O output.right [20:0] fillcolor 1
load symbol RTL_ROM2 work GEN pin O output.right pinBus A input.left [20:0] fillcolor 1
load symbol RTL_REG_ASYNC__BREG_2 workCLR GEN pin C input.clk.left pin CE input.left pin CLR input.neg.top pin D input.left pin Q output.right fillcolor 1
load symbol RTL_ADD1 work RTL(+) pin I1 input.left pinBus I0 input.left [26:0] pinBus O output.right [26:0] fillcolor 1
load symbol RTL_MUX86 work MUX pinBus I0 input.left [4:0] pinBus I1 input.left [4:0] pinBus O output.right [4:0] pinBus S input.bot [4:0] fillcolor 1
load symbol RTL_AND0 work AND pin I0 input pin I1 input pin O output fillcolor 1
load symbol RTL_ADD5 work RTL(+) pin I1 input.left pinBus I0 input.left [4:0] pinBus O output.right [4:0] fillcolor 1
load symbol RTL_INV2 work INV pin I0 input pin O output fillcolor 1
load symbol RTL_EQ work RTL(=) pin I0 input.left pin I1 input.left pin O output.right fillcolor 1
load symbol RTL_AND0 workI1 AND pin I0 input pin I1 input.neg pin O output fillcolor 1
load symbol RTL_ROM4 work GEN pin O output.right pinBus A input.left [4:0] fillcolor 1
load symbol RTL_ADD2 work RTL(+) pin I1 input.left pinBus I0 input.left [25:0] pinBus O output.right [25:0] fillcolor 1
load symbol RTL_MUX78 work MUX pinBus I0 input.left [25:0] pinBus I1 input.left [25:0] pinBus O output.right [25:0] pinBus S input.bot [25:0] fillcolor 1
load symbol can_bit_destuffer work:can_bit_destuffer:NOFILE HIERBOX pin bit_in input.left pin bit_out output.right pin bit_valid input.left pin clear input.left pin clk input.left pin data_valid output.right pin destuff_en input.left pin rst_n input.left pin stuff_error output.right pin stuff_expected output.right boxcolor 1 fillcolor 2 minwidth 13%
load symbol can_bit_stuffer work:can_bit_stuffer:NOFILE HIERBOX pin bit_in input.left pin bit_out output.right pin bit_out_valid output.right pin bit_tick input.left pin clear input.left pin clk input.left pin data_valid input.left pin ready output.right pin rst_n input.left pin stuff_en input.left pin stuff_pending output.right pin stuffing output.right boxcolor 1 fillcolor 2 minwidth 13%
load symbol RTL_REG_ASYNC__BREG_5 workCLR[25:0]ssww GEN pin C input.clk.left pin CLR input.neg.top pinBus D input.left [25:0] pinBus Q output.right [25:0] fillcolor 1 sandwich 3 prop @bundle 26
load symbol RTL_REG_ASYNC__BREG_5 workCLR[26:0]ssww GEN pin C input.clk.left pin CLR input.neg.top pinBus D input.left [26:0] pinBus Q output.right [26:0] fillcolor 1 sandwich 3 prop @bundle 27
load symbol RTL_REG_ASYNC__BREG_2 workCLR[20:0]sssww GEN pin C input.clk.left pin CE input.left pin CLR input.neg.top pinBus D input.left [20:0] pinBus Q output.right [20:0] fillcolor 1 sandwich 3 prop @bundle 21
load symbol RTL_REG_ASYNC__BREG_2 workCLR[4:0]sssww GEN pin C input.clk.left pin CE input.left pin CLR input.neg.top pinBus D input.left [4:0] pinBus Q output.right [4:0] fillcolor 1 sandwich 3 prop @bundle 5
load port clk input -pg 1 -lvl 0 -x 0 -y 870
load port data_sw input -pg 1 -lvl 0 -x 0 -y 660
load port led_bit_out output -pg 1 -lvl 20 -x 5500 -y 470
load port led_error output -pg 1 -lvl 20 -x 5500 -y 230
load port led_heartbeat output -pg 1 -lvl 20 -x 5500 -y 20
load port led_pass output -pg 1 -lvl 20 -x 5500 -y 370
load port led_recovered output -pg 1 -lvl 20 -x 5500 -y 440
load port led_stuff_pending output -pg 1 -lvl 20 -x 5500 -y 630
load port led_stuffing output -pg 1 -lvl 20 -x 5500 -y 660
load port mode_sw input -pg 1 -lvl 0 -x 0 -y 690
load port rst_btn_raw input -pg 1 -lvl 0 -x 0 -y 910
load port step_btn_raw input -pg 1 -lvl 0 -x 0 -y 980
load inst auto_tick_i RTL_ROM1 work -attr @cell(#000000) RTL_ROM -pinBusAttr A @name A[25:0] -pg 1 -lvl 11 -x 2740 -y 610
load inst auto_tick_reg RTL_REG_ASYNC__BREG_5 workCLR -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 12 -x 3050 -y 600
load inst bit_in_i RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 18 -x 4920 -y 580
load inst bit_tick_i RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 13 -x 3510 -y 780
load inst db_cnt0_i RTL_ADD3 work -attr @cell(#000000) RTL_ADD -pinBusAttr I0 @name I0[20:0] -pinBusAttr O @name O[20:0] -pg 1 -lvl 4 -x 680 -y 780
load inst db_cnt_i RTL_MUX80 work -attr @cell(#000000) RTL_MUX -pinBusAttr I0 @name I0[20:0] -pinBusAttr I0 @attr S=21'b111101000010001111111 -pinBusAttr I1 @name I1[20:0] -pinBusAttr I1 @attr S=default -pinBusAttr O @name O[20:0] -pinBusAttr S @name S[20:0] -pg 1 -lvl 5 -x 1070 -y 770
load inst db_cnt_i__0 RTL_MUX79 work -attr @cell(#000000) RTL_MUX -pinBusAttr I0 @name I0[20:0] -pinBusAttr I0 @attr S=1'b1 -pinBusAttr I1 @name I1[20:0] -pinBusAttr I1 @attr S=default -pinBusAttr O @name O[20:0] -pg 1 -lvl 6 -x 1340 -y 950
load inst db_cnt_i__1 RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 6 -x 1340 -y 1120
load inst db_lock_i RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 9 -x 2190 -y 1070
load inst db_lock_i__0 RTL_ROM2 work -attr @cell(#000000) RTL_ROM -pinBusAttr A @name A[20:0] -pg 1 -lvl 8 -x 1780 -y 940
load inst db_lock_i__1 RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 9 -x 2190 -y 950
load inst db_lock_reg RTL_REG_ASYNC__BREG_2 workCLR -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 10 -x 2420 -y 950
load inst err_r_i RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 17 -x 4640 -y 220
load inst err_r_i__0 RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 18 -x 4920 -y 200
load inst err_r_i__1 RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 17 -x 4640 -y 340
load inst err_r_i__2 RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 18 -x 4920 -y 320
load inst err_r_reg RTL_REG_ASYNC__BREG_2 workCLR -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 19 -x 5290 -y 230
load inst hb_cnt0_i RTL_ADD1 work -attr @cell(#000000) RTL_ADD -pinBusAttr I0 @name I0[26:0] -pinBusAttr O @name O[26:0] -pg 1 -lvl 18 -x 4920 -y 100
load inst i0_i RTL_MUX86 work -attr @cell(#000000) RTL_MUX -pinBusAttr I0 @name I0[4:0] -pinBusAttr I0 @attr S=5'b10011 -pinBusAttr I1 @name I1[4:0] -pinBusAttr I1 @attr S=default -pinBusAttr O @name O[4:0] -pinBusAttr S @name S[4:0] -pg 1 -lvl 13 -x 3510 -y 450
load inst i0_i__0 RTL_AND0 work -attr @cell(#000000) RTL_AND -pg 1 -lvl 13 -x 3510 -y 690
load inst i0_i__1 RTL_MUX86 work -attr @cell(#000000) RTL_MUX -pinBusAttr I0 @name I0[4:0] -pinBusAttr I0 @attr S=5'b10011 -pinBusAttr I1 @name I1[4:0] -pinBusAttr I1 @attr S=default -pinBusAttr O @name O[4:0] -pinBusAttr S @name S[4:0] -pg 1 -lvl 15 -x 4170 -y 840
load inst i0_i__2 RTL_AND0 work -attr @cell(#000000) RTL_AND -pg 1 -lvl 15 -x 4170 -y 960
load inst i1_i RTL_ADD5 work -attr @cell(#000000) RTL_ADD -pinBusAttr I0 @name I0[4:0] -pinBusAttr O @name O[4:0] -pg 1 -lvl 12 -x 3050 -y 210
load inst i1_i__0 RTL_ADD5 work -attr @cell(#000000) RTL_ADD -pinBusAttr I0 @name I0[4:0] -pinBusAttr O @name O[4:0] -pg 1 -lvl 14 -x 3820 -y 850
load inst i1_i__1 RTL_AND0 work -attr @cell(#000000) RTL_AND -pg 1 -lvl 14 -x 3820 -y 950
load inst i2_i RTL_INV2 work -attr @cell(#000000) RTL_INV -pg 1 -lvl 12 -x 3050 -y 700
load inst manual_tick_i RTL_MUX15 work -attr @cell(#000000) RTL_MUX -pinAttr I0 @attr S=1'b1 -pinAttr I1 @attr S=default -pg 1 -lvl 11 -x 2740 -y 920
load inst manual_tick_reg RTL_REG_ASYNC__BREG_5 workCLR -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 12 -x 3050 -y 820
load inst pass_r0_i RTL_EQ work -attr @cell(#000000) RTL_EQ -pg 1 -lvl 16 -x 4360 -y 400
load inst pass_r_reg RTL_REG_ASYNC__BREG_2 workCLR -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 19 -x 5290 -y 370
load inst rst_n_i RTL_INV2 work -attr @cell(#000000) RTL_INV -pg 1 -lvl 1 -x 50 -y 910
load inst step_edge_i RTL_AND0 workI1 -attr @cell(#000000) RTL_AND -pg 1 -lvl 5 -x 1070 -y 1040
load inst step_prev_reg RTL_REG_ASYNC__BREG_5 workCLR -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 4 -x 680 -y 970
load inst step_sync0_reg RTL_REG_ASYNC__BREG_5 workCLR -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 2 -x 190 -y 970
load inst step_sync1_reg RTL_REG_ASYNC__BREG_5 workCLR -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 3 -x 420 -y 970
load inst test_bit_i RTL_ROM4 work -attr @cell(#000000) RTL_ROM -pinBusAttr A @name A[4:0] -pg 1 -lvl 15 -x 4170 -y 410
load inst test_bit_i__0 RTL_ROM4 work -attr @cell(#000000) RTL_ROM -pinBusAttr A @name A[4:0] -pg 1 -lvl 17 -x 4640 -y 790
load inst tick_cnt0_i RTL_ADD2 work -attr @cell(#000000) RTL_ADD -pinBusAttr I0 @name I0[25:0] -pinBusAttr O @name O[25:0] -pg 1 -lvl 8 -x 1780 -y 760
load inst tick_cnt_i RTL_MUX78 work -attr @cell(#000000) RTL_MUX -pinBusAttr I0 @name I0[25:0] -pinBusAttr I0 @attr S=26'b10111110101111000001111111 -pinBusAttr I1 @name I1[25:0] -pinBusAttr I1 @attr S=default -pinBusAttr O @name O[25:0] -pinBusAttr S @name S[25:0] -pg 1 -lvl 9 -x 2190 -y 750
load inst u_destuffer can_bit_destuffer work:can_bit_destuffer:NOFILE -autohide -attr @cell(#000000) can_bit_destuffer -pinAttr stuff_expected @attr n/c -pg 1 -lvl 12 -x 3050 -y 350
load inst u_stuffer can_bit_stuffer work:can_bit_stuffer:NOFILE -autohide -attr @cell(#000000) can_bit_stuffer -pg 1 -lvl 19 -x 5290 -y 550
load inst tick_cnt_reg[25:0] RTL_REG_ASYNC__BREG_5 workCLR[25:0]ssww -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 10 -x 2420 -y 790
load inst hb_cnt_reg[26:0] RTL_REG_ASYNC__BREG_5 workCLR[26:0]ssww -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 19 -x 5290 -y 90
load inst db_cnt_reg[20:0] RTL_REG_ASYNC__BREG_2 workCLR[20:0]sssww -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 7 -x 1530 -y 940
load inst rx_idx_reg[4:0] RTL_REG_ASYNC__BREG_2 workCLR[4:0]sssww -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 14 -x 3820 -y 540
load inst idx_reg[4:0] RTL_REG_ASYNC__BREG_2 workCLR[4:0]sssww -attr @cell(#000000) RTL_REG_ASYNC -pg 1 -lvl 16 -x 4360 -y 830
load net <const0> -ground -pin db_cnt_i I0[20] -pin db_cnt_i I0[19] -pin db_cnt_i I0[18] -pin db_cnt_i I0[17] -pin db_cnt_i I0[16] -pin db_cnt_i I0[15] -pin db_cnt_i I0[14] -pin db_cnt_i I0[13] -pin db_cnt_i I0[12] -pin db_cnt_i I0[11] -pin db_cnt_i I0[10] -pin db_cnt_i I0[9] -pin db_cnt_i I0[8] -pin db_cnt_i I0[7] -pin db_cnt_i I0[6] -pin db_cnt_i I0[5] -pin db_cnt_i I0[4] -pin db_cnt_i I0[3] -pin db_cnt_i I0[2] -pin db_cnt_i I0[1] -pin db_cnt_i I0[0] -pin db_cnt_i__0 I1[20] -pin db_cnt_i__0 I1[19] -pin db_cnt_i__0 I1[18] -pin db_cnt_i__0 I1[17] -pin db_cnt_i__0 I1[16] -pin db_cnt_i__0 I1[15] -pin db_cnt_i__0 I1[14] -pin db_cnt_i__0 I1[13] -pin db_cnt_i__0 I1[12] -pin db_cnt_i__0 I1[11] -pin db_cnt_i__0 I1[10] -pin db_cnt_i__0 I1[9] -pin db_cnt_i__0 I1[8] -pin db_cnt_i__0 I1[7] -pin db_cnt_i__0 I1[6] -pin db_cnt_i__0 I1[5] -pin db_cnt_i__0 I1[4] -pin db_cnt_i__0 I1[3] -pin db_cnt_i__0 I1[2] -pin db_cnt_i__0 I1[1] -pin db_cnt_i__0 I1[0] -pin db_lock_i I0 -pin i0_i I0[4] -pin i0_i I0[3] -pin i0_i I0[2] -pin i0_i I0[1] -pin i0_i I0[0] -pin i0_i__1 I0[4] -pin i0_i__1 I0[3] -pin i0_i__1 I0[2] -pin i0_i__1 I0[1] -pin i0_i__1 I0[0] -pin manual_tick_i I0 -pin tick_cnt_i I0[25] -pin tick_cnt_i I0[24] -pin tick_cnt_i I0[23] -pin tick_cnt_i I0[22] -pin tick_cnt_i I0[21] -pin tick_cnt_i I0[20] -pin tick_cnt_i I0[19] -pin tick_cnt_i I0[18] -pin tick_cnt_i I0[17] -pin tick_cnt_i I0[16] -pin tick_cnt_i I0[15] -pin tick_cnt_i I0[14] -pin tick_cnt_i I0[13] -pin tick_cnt_i I0[12] -pin tick_cnt_i I0[11] -pin tick_cnt_i I0[10] -pin tick_cnt_i I0[9] -pin tick_cnt_i I0[8] -pin tick_cnt_i I0[7] -pin tick_cnt_i I0[6] -pin tick_cnt_i I0[5] -pin tick_cnt_i I0[4] -pin tick_cnt_i I0[3] -pin tick_cnt_i I0[2] -pin tick_cnt_i I0[1] -pin tick_cnt_i I0[0] -pin u_destuffer clear -pin u_stuffer clear
load net <const1> -power -pin db_cnt0_i I1 -pin db_cnt_i__1 I0 -pin err_r_i I1 -pin err_r_i__1 I1 -pin hb_cnt0_i I1 -pin i1_i I1 -pin i1_i__0 I1 -pin tick_cnt0_i I1 -pin u_destuffer destuff_en -pin u_stuffer data_valid -pin u_stuffer stuff_en
load net auto_tick -pin auto_tick_reg Q -pin bit_tick_i I1
netloc auto_tick 1 12 1 3240 600n
load net auto_tick__0 -pin auto_tick_i O -pin auto_tick_reg D
netloc auto_tick__0 1 11 1 NJ 610
load net bit_in -pin bit_in_i O -pin u_stuffer bit_in
netloc bit_in 1 18 1 5140 560n
load net bit_out_valid_w -pin u_destuffer bit_valid -pin u_stuffer bit_out_valid
netloc bit_out_valid_w 1 11 9 2920 520 3300J 390 NJ 390 4000J 480 NJ 480 NJ 480 NJ 480 NJ 480 5460
load net bit_tick -pin bit_tick_i O -pin i1_i__1 I1 -pin u_stuffer bit_tick
netloc bit_tick 1 13 6 3670 720 NJ 720 NJ 720 NJ 720 NJ 720 5160
load net clk -pin auto_tick_reg C -port clk -pin db_cnt_reg[20:0] C -pin db_lock_reg C -pin err_r_reg C -pin hb_cnt_reg[26:0] C -pin idx_reg[4:0] C -pin manual_tick_reg C -pin pass_r_reg C -pin rx_idx_reg[4:0] C -pin step_prev_reg C -pin step_sync0_reg C -pin step_sync1_reg C -pin tick_cnt_reg[25:0] C -pin u_destuffer clk -pin u_stuffer clk
netloc clk 1 0 19 NJ 870 140 890 370 890 600 890 NJ 890 NJ 890 1480 850 NJ 850 NJ 850 2370 860 NJ 860 2860 880 NJ 880 3710 780 NJ 780 4310 660 NJ 660 NJ 660 5100
load net data_sw -pin bit_in_i I0 -port data_sw
netloc data_sw 1 0 18 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 3380J 640 NJ 640 NJ 640 NJ 640 NJ 640 4780J
load net db_cnt0[0] -attr @rip(#000000) O[0] -pin db_cnt0_i O[0] -pin db_cnt_i I1[0]
load net db_cnt0[10] -attr @rip(#000000) O[10] -pin db_cnt0_i O[10] -pin db_cnt_i I1[10]
load net db_cnt0[11] -attr @rip(#000000) O[11] -pin db_cnt0_i O[11] -pin db_cnt_i I1[11]
load net db_cnt0[12] -attr @rip(#000000) O[12] -pin db_cnt0_i O[12] -pin db_cnt_i I1[12]
load net db_cnt0[13] -attr @rip(#000000) O[13] -pin db_cnt0_i O[13] -pin db_cnt_i I1[13]
load net db_cnt0[14] -attr @rip(#000000) O[14] -pin db_cnt0_i O[14] -pin db_cnt_i I1[14]
load net db_cnt0[15] -attr @rip(#000000) O[15] -pin db_cnt0_i O[15] -pin db_cnt_i I1[15]
load net db_cnt0[16] -attr @rip(#000000) O[16] -pin db_cnt0_i O[16] -pin db_cnt_i I1[16]
load net db_cnt0[17] -attr @rip(#000000) O[17] -pin db_cnt0_i O[17] -pin db_cnt_i I1[17]
load net db_cnt0[18] -attr @rip(#000000) O[18] -pin db_cnt0_i O[18] -pin db_cnt_i I1[18]
load net db_cnt0[19] -attr @rip(#000000) O[19] -pin db_cnt0_i O[19] -pin db_cnt_i I1[19]
load net db_cnt0[1] -attr @rip(#000000) O[1] -pin db_cnt0_i O[1] -pin db_cnt_i I1[1]
load net db_cnt0[20] -attr @rip(#000000) O[20] -pin db_cnt0_i O[20] -pin db_cnt_i I1[20]
load net db_cnt0[2] -attr @rip(#000000) O[2] -pin db_cnt0_i O[2] -pin db_cnt_i I1[2]
load net db_cnt0[3] -attr @rip(#000000) O[3] -pin db_cnt0_i O[3] -pin db_cnt_i I1[3]
load net db_cnt0[4] -attr @rip(#000000) O[4] -pin db_cnt0_i O[4] -pin db_cnt_i I1[4]
load net db_cnt0[5] -attr @rip(#000000) O[5] -pin db_cnt0_i O[5] -pin db_cnt_i I1[5]
load net db_cnt0[6] -attr @rip(#000000) O[6] -pin db_cnt0_i O[6] -pin db_cnt_i I1[6]
load net db_cnt0[7] -attr @rip(#000000) O[7] -pin db_cnt0_i O[7] -pin db_cnt_i I1[7]
load net db_cnt0[8] -attr @rip(#000000) O[8] -pin db_cnt0_i O[8] -pin db_cnt_i I1[8]
load net db_cnt0[9] -attr @rip(#000000) O[9] -pin db_cnt0_i O[9] -pin db_cnt_i I1[9]
load net db_cnt0_out[0] -attr @rip(#000000) O[0] -pin db_cnt_i__0 O[0] -pin db_cnt_reg[20:0] D[0]
load net db_cnt0_out[10] -attr @rip(#000000) O[10] -pin db_cnt_i__0 O[10] -pin db_cnt_reg[20:0] D[10]
load net db_cnt0_out[11] -attr @rip(#000000) O[11] -pin db_cnt_i__0 O[11] -pin db_cnt_reg[20:0] D[11]
load net db_cnt0_out[12] -attr @rip(#000000) O[12] -pin db_cnt_i__0 O[12] -pin db_cnt_reg[20:0] D[12]
load net db_cnt0_out[13] -attr @rip(#000000) O[13] -pin db_cnt_i__0 O[13] -pin db_cnt_reg[20:0] D[13]
load net db_cnt0_out[14] -attr @rip(#000000) O[14] -pin db_cnt_i__0 O[14] -pin db_cnt_reg[20:0] D[14]
load net db_cnt0_out[15] -attr @rip(#000000) O[15] -pin db_cnt_i__0 O[15] -pin db_cnt_reg[20:0] D[15]
load net db_cnt0_out[16] -attr @rip(#000000) O[16] -pin db_cnt_i__0 O[16] -pin db_cnt_reg[20:0] D[16]
load net db_cnt0_out[17] -attr @rip(#000000) O[17] -pin db_cnt_i__0 O[17] -pin db_cnt_reg[20:0] D[17]
load net db_cnt0_out[18] -attr @rip(#000000) O[18] -pin db_cnt_i__0 O[18] -pin db_cnt_reg[20:0] D[18]
load net db_cnt0_out[19] -attr @rip(#000000) O[19] -pin db_cnt_i__0 O[19] -pin db_cnt_reg[20:0] D[19]
load net db_cnt0_out[1] -attr @rip(#000000) O[1] -pin db_cnt_i__0 O[1] -pin db_cnt_reg[20:0] D[1]
load net db_cnt0_out[20] -attr @rip(#000000) O[20] -pin db_cnt_i__0 O[20] -pin db_cnt_reg[20:0] D[20]
load net db_cnt0_out[2] -attr @rip(#000000) O[2] -pin db_cnt_i__0 O[2] -pin db_cnt_reg[20:0] D[2]
load net db_cnt0_out[3] -attr @rip(#000000) O[3] -pin db_cnt_i__0 O[3] -pin db_cnt_reg[20:0] D[3]
load net db_cnt0_out[4] -attr @rip(#000000) O[4] -pin db_cnt_i__0 O[4] -pin db_cnt_reg[20:0] D[4]
load net db_cnt0_out[5] -attr @rip(#000000) O[5] -pin db_cnt_i__0 O[5] -pin db_cnt_reg[20:0] D[5]
load net db_cnt0_out[6] -attr @rip(#000000) O[6] -pin db_cnt_i__0 O[6] -pin db_cnt_reg[20:0] D[6]
load net db_cnt0_out[7] -attr @rip(#000000) O[7] -pin db_cnt_i__0 O[7] -pin db_cnt_reg[20:0] D[7]
load net db_cnt0_out[8] -attr @rip(#000000) O[8] -pin db_cnt_i__0 O[8] -pin db_cnt_reg[20:0] D[8]
load net db_cnt0_out[9] -attr @rip(#000000) O[9] -pin db_cnt_i__0 O[9] -pin db_cnt_reg[20:0] D[9]
load net db_cnt[0] -attr @rip(#000000) 0 -pin db_cnt0_i I0[0] -pin db_cnt_i S[0] -pin db_cnt_reg[20:0] Q[0] -pin db_lock_i__0 A[0]
load net db_cnt[10] -attr @rip(#000000) 10 -pin db_cnt0_i I0[10] -pin db_cnt_i S[10] -pin db_cnt_reg[20:0] Q[10] -pin db_lock_i__0 A[10]
load net db_cnt[11] -attr @rip(#000000) 11 -pin db_cnt0_i I0[11] -pin db_cnt_i S[11] -pin db_cnt_reg[20:0] Q[11] -pin db_lock_i__0 A[11]
load net db_cnt[12] -attr @rip(#000000) 12 -pin db_cnt0_i I0[12] -pin db_cnt_i S[12] -pin db_cnt_reg[20:0] Q[12] -pin db_lock_i__0 A[12]
load net db_cnt[13] -attr @rip(#000000) 13 -pin db_cnt0_i I0[13] -pin db_cnt_i S[13] -pin db_cnt_reg[20:0] Q[13] -pin db_lock_i__0 A[13]
load net db_cnt[14] -attr @rip(#000000) 14 -pin db_cnt0_i I0[14] -pin db_cnt_i S[14] -pin db_cnt_reg[20:0] Q[14] -pin db_lock_i__0 A[14]
load net db_cnt[15] -attr @rip(#000000) 15 -pin db_cnt0_i I0[15] -pin db_cnt_i S[15] -pin db_cnt_reg[20:0] Q[15] -pin db_lock_i__0 A[15]
load net db_cnt[16] -attr @rip(#000000) 16 -pin db_cnt0_i I0[16] -pin db_cnt_i S[16] -pin db_cnt_reg[20:0] Q[16] -pin db_lock_i__0 A[16]
load net db_cnt[17] -attr @rip(#000000) 17 -pin db_cnt0_i I0[17] -pin db_cnt_i S[17] -pin db_cnt_reg[20:0] Q[17] -pin db_lock_i__0 A[17]
load net db_cnt[18] -attr @rip(#000000) 18 -pin db_cnt0_i I0[18] -pin db_cnt_i S[18] -pin db_cnt_reg[20:0] Q[18] -pin db_lock_i__0 A[18]
load net db_cnt[19] -attr @rip(#000000) 19 -pin db_cnt0_i I0[19] -pin db_cnt_i S[19] -pin db_cnt_reg[20:0] Q[19] -pin db_lock_i__0 A[19]
load net db_cnt[1] -attr @rip(#000000) 1 -pin db_cnt0_i I0[1] -pin db_cnt_i S[1] -pin db_cnt_reg[20:0] Q[1] -pin db_lock_i__0 A[1]
load net db_cnt[20] -attr @rip(#000000) 20 -pin db_cnt0_i I0[20] -pin db_cnt_i S[20] -pin db_cnt_reg[20:0] Q[20] -pin db_lock_i__0 A[20]
load net db_cnt[2] -attr @rip(#000000) 2 -pin db_cnt0_i I0[2] -pin db_cnt_i S[2] -pin db_cnt_reg[20:0] Q[2] -pin db_lock_i__0 A[2]
load net db_cnt[3] -attr @rip(#000000) 3 -pin db_cnt0_i I0[3] -pin db_cnt_i S[3] -pin db_cnt_reg[20:0] Q[3] -pin db_lock_i__0 A[3]
load net db_cnt[4] -attr @rip(#000000) 4 -pin db_cnt0_i I0[4] -pin db_cnt_i S[4] -pin db_cnt_reg[20:0] Q[4] -pin db_lock_i__0 A[4]
load net db_cnt[5] -attr @rip(#000000) 5 -pin db_cnt0_i I0[5] -pin db_cnt_i S[5] -pin db_cnt_reg[20:0] Q[5] -pin db_lock_i__0 A[5]
load net db_cnt[6] -attr @rip(#000000) 6 -pin db_cnt0_i I0[6] -pin db_cnt_i S[6] -pin db_cnt_reg[20:0] Q[6] -pin db_lock_i__0 A[6]
load net db_cnt[7] -attr @rip(#000000) 7 -pin db_cnt0_i I0[7] -pin db_cnt_i S[7] -pin db_cnt_reg[20:0] Q[7] -pin db_lock_i__0 A[7]
load net db_cnt[8] -attr @rip(#000000) 8 -pin db_cnt0_i I0[8] -pin db_cnt_i S[8] -pin db_cnt_reg[20:0] Q[8] -pin db_lock_i__0 A[8]
load net db_cnt[9] -attr @rip(#000000) 9 -pin db_cnt0_i I0[9] -pin db_cnt_i S[9] -pin db_cnt_reg[20:0] Q[9] -pin db_lock_i__0 A[9]
load net db_cnt__0[0] -attr @rip(#000000) O[0] -pin db_cnt_i O[0] -pin db_cnt_i__0 I0[0]
load net db_cnt__0[10] -attr @rip(#000000) O[10] -pin db_cnt_i O[10] -pin db_cnt_i__0 I0[10]
load net db_cnt__0[11] -attr @rip(#000000) O[11] -pin db_cnt_i O[11] -pin db_cnt_i__0 I0[11]
load net db_cnt__0[12] -attr @rip(#000000) O[12] -pin db_cnt_i O[12] -pin db_cnt_i__0 I0[12]
load net db_cnt__0[13] -attr @rip(#000000) O[13] -pin db_cnt_i O[13] -pin db_cnt_i__0 I0[13]
load net db_cnt__0[14] -attr @rip(#000000) O[14] -pin db_cnt_i O[14] -pin db_cnt_i__0 I0[14]
load net db_cnt__0[15] -attr @rip(#000000) O[15] -pin db_cnt_i O[15] -pin db_cnt_i__0 I0[15]
load net db_cnt__0[16] -attr @rip(#000000) O[16] -pin db_cnt_i O[16] -pin db_cnt_i__0 I0[16]
load net db_cnt__0[17] -attr @rip(#000000) O[17] -pin db_cnt_i O[17] -pin db_cnt_i__0 I0[17]
load net db_cnt__0[18] -attr @rip(#000000) O[18] -pin db_cnt_i O[18] -pin db_cnt_i__0 I0[18]
load net db_cnt__0[19] -attr @rip(#000000) O[19] -pin db_cnt_i O[19] -pin db_cnt_i__0 I0[19]
load net db_cnt__0[1] -attr @rip(#000000) O[1] -pin db_cnt_i O[1] -pin db_cnt_i__0 I0[1]
load net db_cnt__0[20] -attr @rip(#000000) O[20] -pin db_cnt_i O[20] -pin db_cnt_i__0 I0[20]
load net db_cnt__0[2] -attr @rip(#000000) O[2] -pin db_cnt_i O[2] -pin db_cnt_i__0 I0[2]
load net db_cnt__0[3] -attr @rip(#000000) O[3] -pin db_cnt_i O[3] -pin db_cnt_i__0 I0[3]
load net db_cnt__0[4] -attr @rip(#000000) O[4] -pin db_cnt_i O[4] -pin db_cnt_i__0 I0[4]
load net db_cnt__0[5] -attr @rip(#000000) O[5] -pin db_cnt_i O[5] -pin db_cnt_i__0 I0[5]
load net db_cnt__0[6] -attr @rip(#000000) O[6] -pin db_cnt_i O[6] -pin db_cnt_i__0 I0[6]
load net db_cnt__0[7] -attr @rip(#000000) O[7] -pin db_cnt_i O[7] -pin db_cnt_i__0 I0[7]
load net db_cnt__0[8] -attr @rip(#000000) O[8] -pin db_cnt_i O[8] -pin db_cnt_i__0 I0[8]
load net db_cnt__0[9] -attr @rip(#000000) O[9] -pin db_cnt_i O[9] -pin db_cnt_i__0 I0[9]
load net db_cnt_i__1_n_0 -pin db_cnt_i__1 O -pin db_cnt_reg[20:0] CE
netloc db_cnt_i__1_n_0 1 6 1 1480 940n
load net db_lock -pin db_cnt_i__0 S -pin db_cnt_i__1 S -pin db_lock_i S -pin db_lock_i__1 S -pin db_lock_reg Q -pin manual_tick_i S
netloc db_lock 1 6 5 1460 1060 NJ 1060 1920 1130N NJ 1130 2600
load net db_lock0_out -pin db_lock_i O -pin db_lock_reg D
netloc db_lock0_out 1 9 1 2370 970n
load net db_lock__0 -pin db_lock_i__0 O -pin db_lock_i__1 I0
netloc db_lock__0 1 8 1 N 940
load net db_lock_i__1_n_0 -pin db_lock_i__1 O -pin db_lock_reg CE
netloc db_lock_i__1_n_0 1 9 1 N 950
load net err_r -pin err_r_i__0 O -pin err_r_reg D
netloc err_r 1 18 1 5080 200n
load net err_r_i__1_n_0 -pin err_r_i__1 O -pin err_r_i__2 I0
netloc err_r_i__1_n_0 1 17 1 4780 310n
load net err_r_i__2_n_0 -pin err_r_i__2 O -pin err_r_reg CE
netloc err_r_i__2_n_0 1 18 1 5040 230n
load net err_r_i_n_0 -pin err_r_i O -pin err_r_i__0 I0
netloc err_r_i_n_0 1 17 1 4760 190n
load net hb_cnt0[0] -attr @rip(#000000) O[0] -pin hb_cnt0_i O[0] -pin hb_cnt_reg[26:0] D[0]
load net hb_cnt0[10] -attr @rip(#000000) O[10] -pin hb_cnt0_i O[10] -pin hb_cnt_reg[26:0] D[10]
load net hb_cnt0[11] -attr @rip(#000000) O[11] -pin hb_cnt0_i O[11] -pin hb_cnt_reg[26:0] D[11]
load net hb_cnt0[12] -attr @rip(#000000) O[12] -pin hb_cnt0_i O[12] -pin hb_cnt_reg[26:0] D[12]
load net hb_cnt0[13] -attr @rip(#000000) O[13] -pin hb_cnt0_i O[13] -pin hb_cnt_reg[26:0] D[13]
load net hb_cnt0[14] -attr @rip(#000000) O[14] -pin hb_cnt0_i O[14] -pin hb_cnt_reg[26:0] D[14]
load net hb_cnt0[15] -attr @rip(#000000) O[15] -pin hb_cnt0_i O[15] -pin hb_cnt_reg[26:0] D[15]
load net hb_cnt0[16] -attr @rip(#000000) O[16] -pin hb_cnt0_i O[16] -pin hb_cnt_reg[26:0] D[16]
load net hb_cnt0[17] -attr @rip(#000000) O[17] -pin hb_cnt0_i O[17] -pin hb_cnt_reg[26:0] D[17]
load net hb_cnt0[18] -attr @rip(#000000) O[18] -pin hb_cnt0_i O[18] -pin hb_cnt_reg[26:0] D[18]
load net hb_cnt0[19] -attr @rip(#000000) O[19] -pin hb_cnt0_i O[19] -pin hb_cnt_reg[26:0] D[19]
load net hb_cnt0[1] -attr @rip(#000000) O[1] -pin hb_cnt0_i O[1] -pin hb_cnt_reg[26:0] D[1]
load net hb_cnt0[20] -attr @rip(#000000) O[20] -pin hb_cnt0_i O[20] -pin hb_cnt_reg[26:0] D[20]
load net hb_cnt0[21] -attr @rip(#000000) O[21] -pin hb_cnt0_i O[21] -pin hb_cnt_reg[26:0] D[21]
load net hb_cnt0[22] -attr @rip(#000000) O[22] -pin hb_cnt0_i O[22] -pin hb_cnt_reg[26:0] D[22]
load net hb_cnt0[23] -attr @rip(#000000) O[23] -pin hb_cnt0_i O[23] -pin hb_cnt_reg[26:0] D[23]
load net hb_cnt0[24] -attr @rip(#000000) O[24] -pin hb_cnt0_i O[24] -pin hb_cnt_reg[26:0] D[24]
load net hb_cnt0[25] -attr @rip(#000000) O[25] -pin hb_cnt0_i O[25] -pin hb_cnt_reg[26:0] D[25]
load net hb_cnt0[26] -attr @rip(#000000) O[26] -pin hb_cnt0_i O[26] -pin hb_cnt_reg[26:0] D[26]
load net hb_cnt0[2] -attr @rip(#000000) O[2] -pin hb_cnt0_i O[2] -pin hb_cnt_reg[26:0] D[2]
load net hb_cnt0[3] -attr @rip(#000000) O[3] -pin hb_cnt0_i O[3] -pin hb_cnt_reg[26:0] D[3]
load net hb_cnt0[4] -attr @rip(#000000) O[4] -pin hb_cnt0_i O[4] -pin hb_cnt_reg[26:0] D[4]
load net hb_cnt0[5] -attr @rip(#000000) O[5] -pin hb_cnt0_i O[5] -pin hb_cnt_reg[26:0] D[5]
load net hb_cnt0[6] -attr @rip(#000000) O[6] -pin hb_cnt0_i O[6] -pin hb_cnt_reg[26:0] D[6]
load net hb_cnt0[7] -attr @rip(#000000) O[7] -pin hb_cnt0_i O[7] -pin hb_cnt_reg[26:0] D[7]
load net hb_cnt0[8] -attr @rip(#000000) O[8] -pin hb_cnt0_i O[8] -pin hb_cnt_reg[26:0] D[8]
load net hb_cnt0[9] -attr @rip(#000000) O[9] -pin hb_cnt0_i O[9] -pin hb_cnt_reg[26:0] D[9]
load net hb_cnt[0] -attr @rip(#000000) 0 -pin hb_cnt0_i I0[0] -pin hb_cnt_reg[26:0] Q[0]
load net hb_cnt[10] -attr @rip(#000000) 10 -pin hb_cnt0_i I0[10] -pin hb_cnt_reg[26:0] Q[10]
load net hb_cnt[11] -attr @rip(#000000) 11 -pin hb_cnt0_i I0[11] -pin hb_cnt_reg[26:0] Q[11]
load net hb_cnt[12] -attr @rip(#000000) 12 -pin hb_cnt0_i I0[12] -pin hb_cnt_reg[26:0] Q[12]
load net hb_cnt[13] -attr @rip(#000000) 13 -pin hb_cnt0_i I0[13] -pin hb_cnt_reg[26:0] Q[13]
load net hb_cnt[14] -attr @rip(#000000) 14 -pin hb_cnt0_i I0[14] -pin hb_cnt_reg[26:0] Q[14]
load net hb_cnt[15] -attr @rip(#000000) 15 -pin hb_cnt0_i I0[15] -pin hb_cnt_reg[26:0] Q[15]
load net hb_cnt[16] -attr @rip(#000000) 16 -pin hb_cnt0_i I0[16] -pin hb_cnt_reg[26:0] Q[16]
load net hb_cnt[17] -attr @rip(#000000) 17 -pin hb_cnt0_i I0[17] -pin hb_cnt_reg[26:0] Q[17]
load net hb_cnt[18] -attr @rip(#000000) 18 -pin hb_cnt0_i I0[18] -pin hb_cnt_reg[26:0] Q[18]
load net hb_cnt[19] -attr @rip(#000000) 19 -pin hb_cnt0_i I0[19] -pin hb_cnt_reg[26:0] Q[19]
load net hb_cnt[1] -attr @rip(#000000) 1 -pin hb_cnt0_i I0[1] -pin hb_cnt_reg[26:0] Q[1]
load net hb_cnt[20] -attr @rip(#000000) 20 -pin hb_cnt0_i I0[20] -pin hb_cnt_reg[26:0] Q[20]
load net hb_cnt[21] -attr @rip(#000000) 21 -pin hb_cnt0_i I0[21] -pin hb_cnt_reg[26:0] Q[21]
load net hb_cnt[22] -attr @rip(#000000) 22 -pin hb_cnt0_i I0[22] -pin hb_cnt_reg[26:0] Q[22]
load net hb_cnt[23] -attr @rip(#000000) 23 -pin hb_cnt0_i I0[23] -pin hb_cnt_reg[26:0] Q[23]
load net hb_cnt[24] -attr @rip(#000000) 24 -pin hb_cnt0_i I0[24] -pin hb_cnt_reg[26:0] Q[24]
load net hb_cnt[25] -attr @rip(#000000) 25 -pin hb_cnt0_i I0[25] -pin hb_cnt_reg[26:0] Q[25]
load net hb_cnt[2] -attr @rip(#000000) 2 -pin hb_cnt0_i I0[2] -pin hb_cnt_reg[26:0] Q[2]
load net hb_cnt[3] -attr @rip(#000000) 3 -pin hb_cnt0_i I0[3] -pin hb_cnt_reg[26:0] Q[3]
load net hb_cnt[4] -attr @rip(#000000) 4 -pin hb_cnt0_i I0[4] -pin hb_cnt_reg[26:0] Q[4]
load net hb_cnt[5] -attr @rip(#000000) 5 -pin hb_cnt0_i I0[5] -pin hb_cnt_reg[26:0] Q[5]
load net hb_cnt[6] -attr @rip(#000000) 6 -pin hb_cnt0_i I0[6] -pin hb_cnt_reg[26:0] Q[6]
load net hb_cnt[7] -attr @rip(#000000) 7 -pin hb_cnt0_i I0[7] -pin hb_cnt_reg[26:0] Q[7]
load net hb_cnt[8] -attr @rip(#000000) 8 -pin hb_cnt0_i I0[8] -pin hb_cnt_reg[26:0] Q[8]
load net hb_cnt[9] -attr @rip(#000000) 9 -pin hb_cnt0_i I0[9] -pin hb_cnt_reg[26:0] Q[9]
load net i0[0] -attr @rip(#000000) O[0] -pin i0_i__1 O[0] -pin idx_reg[4:0] D[0]
load net i0[1] -attr @rip(#000000) O[1] -pin i0_i__1 O[1] -pin idx_reg[4:0] D[1]
load net i0[2] -attr @rip(#000000) O[2] -pin i0_i__1 O[2] -pin idx_reg[4:0] D[2]
load net i0[3] -attr @rip(#000000) O[3] -pin i0_i__1 O[3] -pin idx_reg[4:0] D[3]
load net i0[4] -attr @rip(#000000) O[4] -pin i0_i__1 O[4] -pin idx_reg[4:0] D[4]
load net i0_i__0_n_0 -pin err_r_i__0 S -pin err_r_i__2 S -pin i0_i__0 O -pin pass_r_reg CE -pin rx_idx_reg[4:0] CE
netloc i0_i__0_n_0 1 13 6 3690 620 NJ 620 NJ 620 NJ 620 4760 260N 5060
load net i0_i__2_n_0 -pin i0_i__2 O -pin idx_reg[4:0] CE
netloc i0_i__2_n_0 1 15 1 4310 830n
load net i0_i_n_0 -attr @rip(#000000) O[4] -pin i0_i O[4] -pin rx_idx_reg[4:0] D[4]
load net i0_i_n_1 -attr @rip(#000000) O[3] -pin i0_i O[3] -pin rx_idx_reg[4:0] D[3]
load net i0_i_n_2 -attr @rip(#000000) O[2] -pin i0_i O[2] -pin rx_idx_reg[4:0] D[2]
load net i0_i_n_3 -attr @rip(#000000) O[1] -pin i0_i O[1] -pin rx_idx_reg[4:0] D[1]
load net i0_i_n_4 -attr @rip(#000000) O[0] -pin i0_i O[0] -pin rx_idx_reg[4:0] D[0]
load net i1 -pin i0_i__2 I0 -pin i1_i__1 O
netloc i1 1 14 1 N 950
load net i1_i__0_n_0 -attr @rip(#000000) O[4] -pin i0_i__1 I1[4] -pin i1_i__0 O[4]
load net i1_i__0_n_1 -attr @rip(#000000) O[3] -pin i0_i__1 I1[3] -pin i1_i__0 O[3]
load net i1_i__0_n_2 -attr @rip(#000000) O[2] -pin i0_i__1 I1[2] -pin i1_i__0 O[2]
load net i1_i__0_n_3 -attr @rip(#000000) O[1] -pin i0_i__1 I1[1] -pin i1_i__0 O[1]
load net i1_i__0_n_4 -attr @rip(#000000) O[0] -pin i0_i__1 I1[0] -pin i1_i__0 O[0]
load net i1_i_n_0 -attr @rip(#000000) O[4] -pin i0_i I1[4] -pin i1_i O[4]
load net i1_i_n_1 -attr @rip(#000000) O[3] -pin i0_i I1[3] -pin i1_i O[3]
load net i1_i_n_2 -attr @rip(#000000) O[2] -pin i0_i I1[2] -pin i1_i O[2]
load net i1_i_n_3 -attr @rip(#000000) O[1] -pin i0_i I1[1] -pin i1_i O[1]
load net i1_i_n_4 -attr @rip(#000000) O[0] -pin i0_i I1[0] -pin i1_i O[0]
load net i[0] -attr @rip(#000000) 0 -pin i0_i__1 S[0] -pin i1_i__0 I0[0] -pin idx_reg[4:0] Q[0] -pin test_bit_i__0 A[0]
load net i[1] -attr @rip(#000000) 1 -pin i0_i__1 S[1] -pin i1_i__0 I0[1] -pin idx_reg[4:0] Q[1] -pin test_bit_i__0 A[1]
load net i[2] -attr @rip(#000000) 2 -pin i0_i__1 S[2] -pin i1_i__0 I0[2] -pin idx_reg[4:0] Q[2] -pin test_bit_i__0 A[2]
load net i[3] -attr @rip(#000000) 3 -pin i0_i__1 S[3] -pin i1_i__0 I0[3] -pin idx_reg[4:0] Q[3] -pin test_bit_i__0 A[3]
load net i[4] -attr @rip(#000000) 4 -pin i0_i__1 S[4] -pin i1_i__0 I0[4] -pin idx_reg[4:0] Q[4] -pin test_bit_i__0 A[4]
load net led_bit_out -port led_bit_out -pin u_destuffer bit_in -pin u_stuffer bit_out
netloc led_bit_out 1 11 9 2860 280 3340J 370 NJ 370 4040J 460 NJ 460 NJ 460 NJ 460 NJ 460 5480
load net led_error -pin err_r_reg Q -port led_error
netloc led_error 1 19 1 NJ 230
load net led_heartbeat -attr @rip(#000000) 26 -pin hb_cnt0_i I0[26] -pin hb_cnt_reg[26:0] Q[26] -port led_heartbeat
load net led_pass -port led_pass -pin pass_r_reg Q
netloc led_pass 1 19 1 NJ 370
load net led_recovered -port led_recovered -pin pass_r0_i I0 -pin u_destuffer bit_out
netloc led_recovered 1 12 8 3280 350 NJ 350 NJ 350 4310 350 4500J 420 NJ 420 5040J 440 NJ
load net led_stuff_pending -port led_stuff_pending -pin u_stuffer stuff_pending
netloc led_stuff_pending 1 19 1 5480J 630n
load net led_stuffing -port led_stuffing -pin u_stuffer stuffing
netloc led_stuffing 1 19 1 NJ 660
load net manual_tick -pin bit_tick_i I0 -pin manual_tick_reg Q
netloc manual_tick 1 12 1 3380 770n
load net manual_tick__0 -pin manual_tick_i O -pin manual_tick_reg D
netloc manual_tick__0 1 11 1 2960 830n
load net mode_sw -pin bit_in_i S -pin bit_tick_i S -pin i2_i I0 -port mode_sw
netloc mode_sw 1 0 18 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 2880 740 3220 840N 3730J 700 NJ 700 NJ 700 NJ 700 4820
load net p_0_in -pin i0_i__0 I0 -pin i1_i__1 I0 -pin i2_i O
netloc p_0_in 1 12 2 3260 860 3630
load net pass_r0 -pin err_r_i S -pin err_r_i__1 S -pin pass_r0_i O -pin pass_r_reg D
netloc pass_r0 1 16 3 4520 280N 4800 400 5200J
load net ready_w -pin i0_i__2 I1 -pin u_stuffer ready
netloc ready_w 1 14 6 4000 740 NJ 740 NJ 740 NJ 740 NJ 740 5460
load net rst_btn_raw -port rst_btn_raw -pin rst_n_i I0
netloc rst_btn_raw 1 0 1 NJ 910
load net rst_n -pin auto_tick_reg CLR -pin db_cnt_reg[20:0] CLR -pin db_lock_reg CLR -pin err_r_reg CLR -pin hb_cnt_reg[26:0] CLR -pin idx_reg[4:0] CLR -pin manual_tick_reg CLR -pin pass_r_reg CLR -pin rst_n_i O -pin rx_idx_reg[4:0] CLR -pin step_prev_reg CLR -pin step_sync0_reg CLR -pin step_sync1_reg CLR -pin tick_cnt_reg[25:0] CLR -pin u_destuffer rst_n -pin u_stuffer rst_n
netloc rst_n 1 1 18 NJ 910N N 910N N 910N 840 870 NJ 870 NJ 870N NJ 870 NJ 870 2350 880N 2620 560 2900 540N N 540 3670J 470N 3980 760 NJ 760N 4500 680 NJ 680 5120
load net rx_dv -pin i0_i__0 I1 -pin u_destuffer data_valid
netloc rx_dv 1 12 1 3280 400n
load net rx_err -pin err_r_i I0 -pin err_r_i__0 I1 -pin err_r_i__1 I0 -pin err_r_i__2 I1 -pin u_destuffer stuff_error
netloc rx_err 1 12 6 3240 330 NJ 330 NJ 330 NJ 330 4500 140 4820
load net rx_idx_reg_n_0 -attr @rip(#000000) 4 -pin i0_i S[4] -pin i1_i I0[4] -pin rx_idx_reg[4:0] Q[4] -pin test_bit_i A[4]
load net rx_idx_reg_n_1 -attr @rip(#000000) 3 -pin i0_i S[3] -pin i1_i I0[3] -pin rx_idx_reg[4:0] Q[3] -pin test_bit_i A[3]
load net rx_idx_reg_n_2 -attr @rip(#000000) 2 -pin i0_i S[2] -pin i1_i I0[2] -pin rx_idx_reg[4:0] Q[2] -pin test_bit_i A[2]
load net rx_idx_reg_n_3 -attr @rip(#000000) 1 -pin i0_i S[1] -pin i1_i I0[1] -pin rx_idx_reg[4:0] Q[1] -pin test_bit_i A[1]
load net rx_idx_reg_n_4 -attr @rip(#000000) 0 -pin i0_i S[0] -pin i1_i I0[0] -pin rx_idx_reg[4:0] Q[0] -pin test_bit_i A[0]
load net step_btn_raw -port step_btn_raw -pin step_sync0_reg D
netloc step_btn_raw 1 0 2 NJ 980 NJ
load net step_edge -pin db_cnt_i__1 I1 -pin db_lock_i I1 -pin db_lock_i__1 I1 -pin manual_tick_i I1 -pin step_edge_i O
netloc step_edge 1 5 6 1190 1040 NJ 1040 NJ 1040 1900 890 2310J 1020 2620
load net step_prev -pin step_edge_i I1 -pin step_prev_reg Q
netloc step_prev 1 4 1 840 970n
load net step_sync0 -pin step_sync0_reg Q -pin step_sync1_reg D
netloc step_sync0 1 2 1 350 970n
load net step_sync1 -pin step_edge_i I0 -pin step_prev_reg D -pin step_sync1_reg Q
netloc step_sync1 1 3 2 580 1030 N
load net test_bit_i_n_0 -pin pass_r0_i I1 -pin test_bit_i O
netloc test_bit_i_n_0 1 15 1 NJ 410
load net test_bit_return -pin bit_in_i I1 -pin test_bit_i__0 O
netloc test_bit_return 1 17 1 4800 590n
load net tick_cnt0[0] -attr @rip(#000000) O[0] -pin tick_cnt0_i O[0] -pin tick_cnt_i I1[0]
load net tick_cnt0[10] -attr @rip(#000000) O[10] -pin tick_cnt0_i O[10] -pin tick_cnt_i I1[10]
load net tick_cnt0[11] -attr @rip(#000000) O[11] -pin tick_cnt0_i O[11] -pin tick_cnt_i I1[11]
load net tick_cnt0[12] -attr @rip(#000000) O[12] -pin tick_cnt0_i O[12] -pin tick_cnt_i I1[12]
load net tick_cnt0[13] -attr @rip(#000000) O[13] -pin tick_cnt0_i O[13] -pin tick_cnt_i I1[13]
load net tick_cnt0[14] -attr @rip(#000000) O[14] -pin tick_cnt0_i O[14] -pin tick_cnt_i I1[14]
load net tick_cnt0[15] -attr @rip(#000000) O[15] -pin tick_cnt0_i O[15] -pin tick_cnt_i I1[15]
load net tick_cnt0[16] -attr @rip(#000000) O[16] -pin tick_cnt0_i O[16] -pin tick_cnt_i I1[16]
load net tick_cnt0[17] -attr @rip(#000000) O[17] -pin tick_cnt0_i O[17] -pin tick_cnt_i I1[17]
load net tick_cnt0[18] -attr @rip(#000000) O[18] -pin tick_cnt0_i O[18] -pin tick_cnt_i I1[18]
load net tick_cnt0[19] -attr @rip(#000000) O[19] -pin tick_cnt0_i O[19] -pin tick_cnt_i I1[19]
load net tick_cnt0[1] -attr @rip(#000000) O[1] -pin tick_cnt0_i O[1] -pin tick_cnt_i I1[1]
load net tick_cnt0[20] -attr @rip(#000000) O[20] -pin tick_cnt0_i O[20] -pin tick_cnt_i I1[20]
load net tick_cnt0[21] -attr @rip(#000000) O[21] -pin tick_cnt0_i O[21] -pin tick_cnt_i I1[21]
load net tick_cnt0[22] -attr @rip(#000000) O[22] -pin tick_cnt0_i O[22] -pin tick_cnt_i I1[22]
load net tick_cnt0[23] -attr @rip(#000000) O[23] -pin tick_cnt0_i O[23] -pin tick_cnt_i I1[23]
load net tick_cnt0[24] -attr @rip(#000000) O[24] -pin tick_cnt0_i O[24] -pin tick_cnt_i I1[24]
load net tick_cnt0[25] -attr @rip(#000000) O[25] -pin tick_cnt0_i O[25] -pin tick_cnt_i I1[25]
load net tick_cnt0[2] -attr @rip(#000000) O[2] -pin tick_cnt0_i O[2] -pin tick_cnt_i I1[2]
load net tick_cnt0[3] -attr @rip(#000000) O[3] -pin tick_cnt0_i O[3] -pin tick_cnt_i I1[3]
load net tick_cnt0[4] -attr @rip(#000000) O[4] -pin tick_cnt0_i O[4] -pin tick_cnt_i I1[4]
load net tick_cnt0[5] -attr @rip(#000000) O[5] -pin tick_cnt0_i O[5] -pin tick_cnt_i I1[5]
load net tick_cnt0[6] -attr @rip(#000000) O[6] -pin tick_cnt0_i O[6] -pin tick_cnt_i I1[6]
load net tick_cnt0[7] -attr @rip(#000000) O[7] -pin tick_cnt0_i O[7] -pin tick_cnt_i I1[7]
load net tick_cnt0[8] -attr @rip(#000000) O[8] -pin tick_cnt0_i O[8] -pin tick_cnt_i I1[8]
load net tick_cnt0[9] -attr @rip(#000000) O[9] -pin tick_cnt0_i O[9] -pin tick_cnt_i I1[9]
load net tick_cnt0_out[0] -attr @rip(#000000) O[0] -pin tick_cnt_i O[0] -pin tick_cnt_reg[25:0] D[0]
load net tick_cnt0_out[10] -attr @rip(#000000) O[10] -pin tick_cnt_i O[10] -pin tick_cnt_reg[25:0] D[10]
load net tick_cnt0_out[11] -attr @rip(#000000) O[11] -pin tick_cnt_i O[11] -pin tick_cnt_reg[25:0] D[11]
load net tick_cnt0_out[12] -attr @rip(#000000) O[12] -pin tick_cnt_i O[12] -pin tick_cnt_reg[25:0] D[12]
load net tick_cnt0_out[13] -attr @rip(#000000) O[13] -pin tick_cnt_i O[13] -pin tick_cnt_reg[25:0] D[13]
load net tick_cnt0_out[14] -attr @rip(#000000) O[14] -pin tick_cnt_i O[14] -pin tick_cnt_reg[25:0] D[14]
load net tick_cnt0_out[15] -attr @rip(#000000) O[15] -pin tick_cnt_i O[15] -pin tick_cnt_reg[25:0] D[15]
load net tick_cnt0_out[16] -attr @rip(#000000) O[16] -pin tick_cnt_i O[16] -pin tick_cnt_reg[25:0] D[16]
load net tick_cnt0_out[17] -attr @rip(#000000) O[17] -pin tick_cnt_i O[17] -pin tick_cnt_reg[25:0] D[17]
load net tick_cnt0_out[18] -attr @rip(#000000) O[18] -pin tick_cnt_i O[18] -pin tick_cnt_reg[25:0] D[18]
load net tick_cnt0_out[19] -attr @rip(#000000) O[19] -pin tick_cnt_i O[19] -pin tick_cnt_reg[25:0] D[19]
load net tick_cnt0_out[1] -attr @rip(#000000) O[1] -pin tick_cnt_i O[1] -pin tick_cnt_reg[25:0] D[1]
load net tick_cnt0_out[20] -attr @rip(#000000) O[20] -pin tick_cnt_i O[20] -pin tick_cnt_reg[25:0] D[20]
load net tick_cnt0_out[21] -attr @rip(#000000) O[21] -pin tick_cnt_i O[21] -pin tick_cnt_reg[25:0] D[21]
load net tick_cnt0_out[22] -attr @rip(#000000) O[22] -pin tick_cnt_i O[22] -pin tick_cnt_reg[25:0] D[22]
load net tick_cnt0_out[23] -attr @rip(#000000) O[23] -pin tick_cnt_i O[23] -pin tick_cnt_reg[25:0] D[23]
load net tick_cnt0_out[24] -attr @rip(#000000) O[24] -pin tick_cnt_i O[24] -pin tick_cnt_reg[25:0] D[24]
load net tick_cnt0_out[25] -attr @rip(#000000) O[25] -pin tick_cnt_i O[25] -pin tick_cnt_reg[25:0] D[25]
load net tick_cnt0_out[2] -attr @rip(#000000) O[2] -pin tick_cnt_i O[2] -pin tick_cnt_reg[25:0] D[2]
load net tick_cnt0_out[3] -attr @rip(#000000) O[3] -pin tick_cnt_i O[3] -pin tick_cnt_reg[25:0] D[3]
load net tick_cnt0_out[4] -attr @rip(#000000) O[4] -pin tick_cnt_i O[4] -pin tick_cnt_reg[25:0] D[4]
load net tick_cnt0_out[5] -attr @rip(#000000) O[5] -pin tick_cnt_i O[5] -pin tick_cnt_reg[25:0] D[5]
load net tick_cnt0_out[6] -attr @rip(#000000) O[6] -pin tick_cnt_i O[6] -pin tick_cnt_reg[25:0] D[6]
load net tick_cnt0_out[7] -attr @rip(#000000) O[7] -pin tick_cnt_i O[7] -pin tick_cnt_reg[25:0] D[7]
load net tick_cnt0_out[8] -attr @rip(#000000) O[8] -pin tick_cnt_i O[8] -pin tick_cnt_reg[25:0] D[8]
load net tick_cnt0_out[9] -attr @rip(#000000) O[9] -pin tick_cnt_i O[9] -pin tick_cnt_reg[25:0] D[9]
load net tick_cnt[0] -attr @rip(#000000) 0 -pin auto_tick_i A[0] -pin tick_cnt0_i I0[0] -pin tick_cnt_i S[0] -pin tick_cnt_reg[25:0] Q[0]
load net tick_cnt[10] -attr @rip(#000000) 10 -pin auto_tick_i A[10] -pin tick_cnt0_i I0[10] -pin tick_cnt_i S[10] -pin tick_cnt_reg[25:0] Q[10]
load net tick_cnt[11] -attr @rip(#000000) 11 -pin auto_tick_i A[11] -pin tick_cnt0_i I0[11] -pin tick_cnt_i S[11] -pin tick_cnt_reg[25:0] Q[11]
load net tick_cnt[12] -attr @rip(#000000) 12 -pin auto_tick_i A[12] -pin tick_cnt0_i I0[12] -pin tick_cnt_i S[12] -pin tick_cnt_reg[25:0] Q[12]
load net tick_cnt[13] -attr @rip(#000000) 13 -pin auto_tick_i A[13] -pin tick_cnt0_i I0[13] -pin tick_cnt_i S[13] -pin tick_cnt_reg[25:0] Q[13]
load net tick_cnt[14] -attr @rip(#000000) 14 -pin auto_tick_i A[14] -pin tick_cnt0_i I0[14] -pin tick_cnt_i S[14] -pin tick_cnt_reg[25:0] Q[14]
load net tick_cnt[15] -attr @rip(#000000) 15 -pin auto_tick_i A[15] -pin tick_cnt0_i I0[15] -pin tick_cnt_i S[15] -pin tick_cnt_reg[25:0] Q[15]
load net tick_cnt[16] -attr @rip(#000000) 16 -pin auto_tick_i A[16] -pin tick_cnt0_i I0[16] -pin tick_cnt_i S[16] -pin tick_cnt_reg[25:0] Q[16]
load net tick_cnt[17] -attr @rip(#000000) 17 -pin auto_tick_i A[17] -pin tick_cnt0_i I0[17] -pin tick_cnt_i S[17] -pin tick_cnt_reg[25:0] Q[17]
load net tick_cnt[18] -attr @rip(#000000) 18 -pin auto_tick_i A[18] -pin tick_cnt0_i I0[18] -pin tick_cnt_i S[18] -pin tick_cnt_reg[25:0] Q[18]
load net tick_cnt[19] -attr @rip(#000000) 19 -pin auto_tick_i A[19] -pin tick_cnt0_i I0[19] -pin tick_cnt_i S[19] -pin tick_cnt_reg[25:0] Q[19]
load net tick_cnt[1] -attr @rip(#000000) 1 -pin auto_tick_i A[1] -pin tick_cnt0_i I0[1] -pin tick_cnt_i S[1] -pin tick_cnt_reg[25:0] Q[1]
load net tick_cnt[20] -attr @rip(#000000) 20 -pin auto_tick_i A[20] -pin tick_cnt0_i I0[20] -pin tick_cnt_i S[20] -pin tick_cnt_reg[25:0] Q[20]
load net tick_cnt[21] -attr @rip(#000000) 21 -pin auto_tick_i A[21] -pin tick_cnt0_i I0[21] -pin tick_cnt_i S[21] -pin tick_cnt_reg[25:0] Q[21]
load net tick_cnt[22] -attr @rip(#000000) 22 -pin auto_tick_i A[22] -pin tick_cnt0_i I0[22] -pin tick_cnt_i S[22] -pin tick_cnt_reg[25:0] Q[22]
load net tick_cnt[23] -attr @rip(#000000) 23 -pin auto_tick_i A[23] -pin tick_cnt0_i I0[23] -pin tick_cnt_i S[23] -pin tick_cnt_reg[25:0] Q[23]
load net tick_cnt[24] -attr @rip(#000000) 24 -pin auto_tick_i A[24] -pin tick_cnt0_i I0[24] -pin tick_cnt_i S[24] -pin tick_cnt_reg[25:0] Q[24]
load net tick_cnt[25] -attr @rip(#000000) 25 -pin auto_tick_i A[25] -pin tick_cnt0_i I0[25] -pin tick_cnt_i S[25] -pin tick_cnt_reg[25:0] Q[25]
load net tick_cnt[2] -attr @rip(#000000) 2 -pin auto_tick_i A[2] -pin tick_cnt0_i I0[2] -pin tick_cnt_i S[2] -pin tick_cnt_reg[25:0] Q[2]
load net tick_cnt[3] -attr @rip(#000000) 3 -pin auto_tick_i A[3] -pin tick_cnt0_i I0[3] -pin tick_cnt_i S[3] -pin tick_cnt_reg[25:0] Q[3]
load net tick_cnt[4] -attr @rip(#000000) 4 -pin auto_tick_i A[4] -pin tick_cnt0_i I0[4] -pin tick_cnt_i S[4] -pin tick_cnt_reg[25:0] Q[4]
load net tick_cnt[5] -attr @rip(#000000) 5 -pin auto_tick_i A[5] -pin tick_cnt0_i I0[5] -pin tick_cnt_i S[5] -pin tick_cnt_reg[25:0] Q[5]
load net tick_cnt[6] -attr @rip(#000000) 6 -pin auto_tick_i A[6] -pin tick_cnt0_i I0[6] -pin tick_cnt_i S[6] -pin tick_cnt_reg[25:0] Q[6]
load net tick_cnt[7] -attr @rip(#000000) 7 -pin auto_tick_i A[7] -pin tick_cnt0_i I0[7] -pin tick_cnt_i S[7] -pin tick_cnt_reg[25:0] Q[7]
load net tick_cnt[8] -attr @rip(#000000) 8 -pin auto_tick_i A[8] -pin tick_cnt0_i I0[8] -pin tick_cnt_i S[8] -pin tick_cnt_reg[25:0] Q[8]
load net tick_cnt[9] -attr @rip(#000000) 9 -pin auto_tick_i A[9] -pin tick_cnt0_i I0[9] -pin tick_cnt_i S[9] -pin tick_cnt_reg[25:0] Q[9]
load netBundle @db_cnt0 21 db_cnt0[20] db_cnt0[19] db_cnt0[18] db_cnt0[17] db_cnt0[16] db_cnt0[15] db_cnt0[14] db_cnt0[13] db_cnt0[12] db_cnt0[11] db_cnt0[10] db_cnt0[9] db_cnt0[8] db_cnt0[7] db_cnt0[6] db_cnt0[5] db_cnt0[4] db_cnt0[3] db_cnt0[2] db_cnt0[1] db_cnt0[0] -autobundled
netbloc @db_cnt0 1 4 1 NJ 780
load netBundle @db_cnt__0 21 db_cnt__0[20] db_cnt__0[19] db_cnt__0[18] db_cnt__0[17] db_cnt__0[16] db_cnt__0[15] db_cnt__0[14] db_cnt__0[13] db_cnt__0[12] db_cnt__0[11] db_cnt__0[10] db_cnt__0[9] db_cnt__0[8] db_cnt__0[7] db_cnt__0[6] db_cnt__0[5] db_cnt__0[4] db_cnt__0[3] db_cnt__0[2] db_cnt__0[1] db_cnt__0[0] -autobundled
netbloc @db_cnt__0 1 5 1 1210 770n
load netBundle @db_cnt0_out 21 db_cnt0_out[20] db_cnt0_out[19] db_cnt0_out[18] db_cnt0_out[17] db_cnt0_out[16] db_cnt0_out[15] db_cnt0_out[14] db_cnt0_out[13] db_cnt0_out[12] db_cnt0_out[11] db_cnt0_out[10] db_cnt0_out[9] db_cnt0_out[8] db_cnt0_out[7] db_cnt0_out[6] db_cnt0_out[5] db_cnt0_out[4] db_cnt0_out[3] db_cnt0_out[2] db_cnt0_out[1] db_cnt0_out[0] -autobundled
netbloc @db_cnt0_out 1 6 1 1460 950n
load netBundle @hb_cnt0 27 hb_cnt0[26] hb_cnt0[25] hb_cnt0[24] hb_cnt0[23] hb_cnt0[22] hb_cnt0[21] hb_cnt0[20] hb_cnt0[19] hb_cnt0[18] hb_cnt0[17] hb_cnt0[16] hb_cnt0[15] hb_cnt0[14] hb_cnt0[13] hb_cnt0[12] hb_cnt0[11] hb_cnt0[10] hb_cnt0[9] hb_cnt0[8] hb_cnt0[7] hb_cnt0[6] hb_cnt0[5] hb_cnt0[4] hb_cnt0[3] hb_cnt0[2] hb_cnt0[1] hb_cnt0[0] -autobundled
netbloc @hb_cnt0 1 18 1 NJ 100
load netBundle @i0_i_n_ 5 i0_i_n_0 i0_i_n_1 i0_i_n_2 i0_i_n_3 i0_i_n_4 -autobundled
netbloc @i0_i_n_ 1 13 1 3630 450n
load netBundle @i0 5 i0[4] i0[3] i0[2] i0[1] i0[0] -autobundled
netbloc @i0 1 15 1 4290 840n
load netBundle @i1_i_n_ 5 i1_i_n_0 i1_i_n_1 i1_i_n_2 i1_i_n_3 i1_i_n_4 -autobundled
netbloc @i1_i_n_ 1 12 1 3360 210n
load netBundle @i1_i__0_n_ 5 i1_i__0_n_0 i1_i__0_n_1 i1_i__0_n_2 i1_i__0_n_3 i1_i__0_n_4 -autobundled
netbloc @i1_i__0_n_ 1 14 1 N 850
load netBundle @tick_cnt0 26 tick_cnt0[25] tick_cnt0[24] tick_cnt0[23] tick_cnt0[22] tick_cnt0[21] tick_cnt0[20] tick_cnt0[19] tick_cnt0[18] tick_cnt0[17] tick_cnt0[16] tick_cnt0[15] tick_cnt0[14] tick_cnt0[13] tick_cnt0[12] tick_cnt0[11] tick_cnt0[10] tick_cnt0[9] tick_cnt0[8] tick_cnt0[7] tick_cnt0[6] tick_cnt0[5] tick_cnt0[4] tick_cnt0[3] tick_cnt0[2] tick_cnt0[1] tick_cnt0[0] -autobundled
netbloc @tick_cnt0 1 8 1 NJ 760
load netBundle @tick_cnt0_out 26 tick_cnt0_out[25] tick_cnt0_out[24] tick_cnt0_out[23] tick_cnt0_out[22] tick_cnt0_out[21] tick_cnt0_out[20] tick_cnt0_out[19] tick_cnt0_out[18] tick_cnt0_out[17] tick_cnt0_out[16] tick_cnt0_out[15] tick_cnt0_out[14] tick_cnt0_out[13] tick_cnt0_out[12] tick_cnt0_out[11] tick_cnt0_out[10] tick_cnt0_out[9] tick_cnt0_out[8] tick_cnt0_out[7] tick_cnt0_out[6] tick_cnt0_out[5] tick_cnt0_out[4] tick_cnt0_out[3] tick_cnt0_out[2] tick_cnt0_out[1] tick_cnt0_out[0] -autobundled
netbloc @tick_cnt0_out 1 9 1 2330 750n
load netBundle @tick_cnt 26 tick_cnt[25] tick_cnt[24] tick_cnt[23] tick_cnt[22] tick_cnt[21] tick_cnt[20] tick_cnt[19] tick_cnt[18] tick_cnt[17] tick_cnt[16] tick_cnt[15] tick_cnt[14] tick_cnt[13] tick_cnt[12] tick_cnt[11] tick_cnt[10] tick_cnt[9] tick_cnt[8] tick_cnt[7] tick_cnt[6] tick_cnt[5] tick_cnt[4] tick_cnt[3] tick_cnt[2] tick_cnt[1] tick_cnt[0] -autobundled
netbloc @tick_cnt 1 7 4 1700 810 NJ 810N 2310 710 2640
load netBundle @hb_cnt,led_heartbeat 27 led_heartbeat hb_cnt[25] hb_cnt[24] hb_cnt[23] hb_cnt[22] hb_cnt[21] hb_cnt[20] hb_cnt[19] hb_cnt[18] hb_cnt[17] hb_cnt[16] hb_cnt[15] hb_cnt[14] hb_cnt[13] hb_cnt[12] hb_cnt[11] hb_cnt[10] hb_cnt[9] hb_cnt[8] hb_cnt[7] hb_cnt[6] hb_cnt[5] hb_cnt[4] hb_cnt[3] hb_cnt[2] hb_cnt[1] hb_cnt[0] -autobundled
netbloc @hb_cnt,led_heartbeat 1 17 3 4760 10 NJ 10 5480
load netBundle @db_cnt 21 db_cnt[20] db_cnt[19] db_cnt[18] db_cnt[17] db_cnt[16] db_cnt[15] db_cnt[14] db_cnt[13] db_cnt[12] db_cnt[11] db_cnt[10] db_cnt[9] db_cnt[8] db_cnt[7] db_cnt[6] db_cnt[5] db_cnt[4] db_cnt[3] db_cnt[2] db_cnt[1] db_cnt[0] -autobundled
netbloc @db_cnt 1 3 5 600 830 NJ 830N NJ 830 NJ 830 1700
load netBundle @rx_idx_reg_n_ 5 rx_idx_reg_n_0 rx_idx_reg_n_1 rx_idx_reg_n_2 rx_idx_reg_n_3 rx_idx_reg_n_4 -autobundled
netbloc @rx_idx_reg_n_ 1 11 4 2940 260 3320 510N 3650J 450 4020
load netBundle @i 5 i[4] i[3] i[2] i[1] i[0] -autobundled
netbloc @i 1 13 4 3750 900 N 900N 4290J 910 4540
levelinfo -pg 1 0 50 190 420 680 1070 1340 1530 1780 2190 2420 2740 3050 3510 3820 4170 4360 4640 4920 5290 5500
pagesize -pg 1 -db -bbox -sgen -140 0 5670 1190
show
fullfit
#
# initialize ictrl to current module can_stuff_destuff_demo_top work:can_stuff_destuff_demo_top:NOFILE
ictrl init topinfo |
