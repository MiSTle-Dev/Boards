/*
    top.sv

    Mixed test core for the dev20k board
*/ 

module top(
  input		   clk,
    
  output	   ws2812,
  output [5:0] leds_n,
		   
  // hdmi/tdms
  output	   tmds_clk_n,
  output	   tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p
);

wire clk_pixel_x5;   // 125 MHz HDMI clock
wire clk_pixel;
wire pll_lock;

pll_125m pll_125m (
    .clkout(clk_pixel_x5),
    .lock(pll_lock),
    .clkin(clk)
);
   
clkdiv5 clkdiv5 (
    .hclkin(clk_pixel_x5), // input hclkin
    .resetn(pll_lock),     // input resetn
    .clkout(clk_pixel)     // output clkout
);

// generate a reset signal that is still some time valid after the clocks
// are stable
reg [15:0] reset_cnt = 16'd1000;
wire reset = reset_cnt;
always @(posedge clk) begin
    if(!pll_lock)
        reset_cnt <= 16'd1000;
    else begin
        if(reset_cnt)
            reset_cnt <= reset_cnt - 16'd1;
    end
end

wire [2:0] tmds;
wire tmds_clock;

// -----------------------------------------------------
// ------------------    font    -----------------------
// -----------------------------------------------------

wire [7:0] fontrom_dout;
reg [7:0] chr;

// ---------- local video counter ----------------
wire [9:0] hcnt;
wire [9:0] vcnt;

// some text that is being displayed after reset
wire [7:0] init_message [52] = "MiSTle - Dev20k Test\nWaiting for JTAG user data ...\n";
// text to send as a reply when receiving a newline
wire [7:0] reply_message [7] = "Ready.\n";

// delay hcnt two times to match screenram and fontrom delay
reg [9:0] hcntD, hcntD2;

// 4k of video ram. 80x30 = 2400
reg [7:0] screenram [4096];

font fontrom (
    .dout(fontrom_dout),
    .clk(clk_pixel),
    .oce(1'b1),
    .ce(1'b1),
    .reset(reset),
    .ad({ chr, vcnt[3:0] })
);

// fifo to receive data from JTAG (t be put onto screen)
reg [7:0] rx_fifo [16];
reg [3:0] rx_wptr, rx_rptr;

// fifo to transmit data to JTAG
reg [7:0] tx_fifo [16];
reg [3:0] tx_wptr, tx_rptr;

// ---------------------- cursor handling -------------------------
reg [7:0] cursor_x, cursor_y;

reg [31:0] cursor_blink_counter;
always @(posedge clk_pixel)
    cursor_blink_counter <= cursor_blink_counter + 31'd1;

wire is_cursor = (vcnt[9:4] == cursor_y) && (hcntD2[9:3] == cursor_x) && cursor_blink_counter[24];

wire pixel = fontrom_dout[3'd7 - hcntD2[2:0]] ^ is_cursor;
wire [23:0] pixel_rgb = pixel?24'hffffff:24'h000000;

// jtag byte rx interface
reg [7:0] jtag_rx_byte;          // (non-zero) byte received via JTAG
reg jtag_rx_toggle;              // toggle whenever a new byte has been received
reg jtag_tx_toggle;              // toggle whenever a new byte has been sent

always @(posedge clk_pixel) begin
    reg [7:0] init_cnt;
    reg [7:0] tx_cnt;
    reg jtag_rx_toggleD, jtag_rx_toggleD2;
    reg jtag_tx_toggleD, jtag_tx_toggleD2;

    if(reset) begin
        init_cnt <= 8'd0;

        cursor_x <= 8'd0;
        cursor_y <= 8'd0;

        // reset rx fifo
        jtag_rx_toggleD <= 1'b0;
        jtag_rx_toggleD2 <= 1'b0;
        rx_wptr <= 4'd0;
        rx_rptr <= 4'd0;

        // reset tx fifo
        jtag_tx_toggleD <= 1'b0;
        jtag_tx_toggleD2 <= 1'b0;
        tx_wptr <= 4'd0;
        tx_rptr <= 4'd0;
        tx_cnt <= 8'd255;
    end else begin
        logic init;
        init = init_cnt < 52;   // init message is 52 characters long

        // todo: clear video mem after reset. Currently it's all zero which is ok, since
        // in the font, the zero character is blank

        // bring jtag_rx_toggle into the local clock domain and act on its change
        jtag_rx_toggleD <= jtag_rx_toggle;
        jtag_rx_toggleD2 <= jtag_rx_toggleD;
        if(jtag_rx_toggleD ^ jtag_rx_toggleD2) begin
            rx_fifo[rx_wptr] <= jtag_rx_byte;
            rx_wptr <= rx_wptr + 4'd1;
        end

        // bring jtag_tx_toggle into the local clock domain and act on its change
        jtag_tx_toggleD <= jtag_tx_toggle;
        jtag_tx_toggleD2 <= jtag_tx_toggleD;
        if(jtag_tx_toggleD ^ jtag_tx_toggleD2)
            tx_rptr <= tx_rptr + 4'd1;

        // write characrers in init phase or when JTAG data in fifo
        if(init || rx_wptr != rx_rptr) begin
            logic [7:0] inbyte;
            if(init) begin
                // fetch bext byte of init message
                inbyte = init_message[init_cnt];
                init_cnt <= init_cnt + 8'd1;
            end else begin
                // fetch next byte from fifo
                inbyte = rx_fifo[rx_rptr];
                rx_rptr <= rx_rptr + 4'd1;
            end

            // check for newline
            if(inbyte != "\n") begin
                screenram[cursor_x + 80*cursor_y] <= inbyte;
                cursor_x <= cursor_x + 1;
            end 

            // go to next line on newline or cursor on last column
            if(inbyte == "\n" || cursor_x == 79) begin
                cursor_x <= 8'd0;
                cursor_y <= cursor_y + 8'd1;
            end

            // start putting some bytes into tx fifo once a newline has been received via JTAG
            if(!init && inbyte == "\n")
                tx_cnt <= 8'd0;
        end

        // write next character into the tx buffer unless the buffer is full
        if(tx_cnt < 7 && ((tx_wptr+4'd1) != tx_rptr)) begin
            tx_fifo[tx_wptr] = reply_message[tx_cnt];
            tx_wptr <= tx_wptr + 4'd1;
            tx_cnt <= tx_cnt + 1;
        end

        // read screen ram for video output
        if(hcnt[2:0] == 3'b000)
            chr <= screenram[80 * vcnt[8:4] + hcnt[9:3]];

        // delayed hcnt for later processing after ram/font rom has been read
        hcntD <= hcnt;
        hcntD2 <= hcntD;
    end
end

hdmi hdmi(
    .clk_pixel_x5(clk_pixel_x5),
    .clk_pixel(clk_pixel),
    .clk_audio(1'b0),

    .reset( 1'b0 ),
    .rgb(pixel_rgb),
    .audio_sample_word({16'h0000, 16'h0000}),

    .cx(hcnt),
    .cy(vcnt),

    // tdms to be used with hdmi or dvi
    .tmds_clock ( tmds_clock ),
    .tmds       ( tmds       )
);

// differential output
ELVDS_OBUF tmds_bufds [3:0] (
        .I({tmds_clock, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
);

// --------------------------------------------------------------------------------------
// ----------------------------------   JTAG   ------------------------------------------
// --------------------------------------------------------------------------------------

wire tck_o;
wire tdi_o;
wire shift_dr_capture_dr_o;            // SHIFT_IN|CAPTURE_IN
wire update_dr_o;                      // UPDATE_IN
wire enable_er1_o;                     // SEL_IN
wire tdo_er1_i;                        // TDO_OUT

GW_JTAG u_gw_jtag (
    .tck_o(tck_o),                    
    .tdi_o(tdi_o),                    
    .test_logic_reset_o(),
    .run_test_idle_er1_o(),   
    .run_test_idle_er2_o(),   
    .shift_dr_capture_dr_o(shift_dr_capture_dr_o),
    .pause_dr_o(),     
    .update_dr_o(update_dr_o),
    .enable_er1_o(enable_er1_o),
    .enable_er2_o(), 
    .tdo_er1_i(tdo_er1_i),             // TDO_OUT for ir == 0x42
    .tdo_er2_i()                       // TDO_OUT for ir == 0x43
);

reg [7:0] bit_cnt;

// transmit byte from tx_fifo if data is available. Else transmit zero
assign tdo_er1_i = (tx_rptr != tx_wptr)?tx_fifo[tx_rptr][bit_cnt[2:0]]:1'b0;

always @(posedge tck_o or posedge reset) begin
    if(reset) begin
        bit_cnt <= 8'd0;
        jtag_rx_toggle <= 1'b0;
    end else begin
        // this demo uses user1 (ir == 0x42) only.
        // It may additionally use user2 (ir == 0x43)
        if(enable_er1_o) begin

            if(shift_dr_capture_dr_o) begin
                jtag_rx_byte <= { jtag_rx_byte[6:0], tdi_o };            // shift serial JTAG data in
                bit_cnt <= bit_cnt  + 8'd1;                            // count bits

                // one complete byte received: trigger fifo write. Ignore any 0 bytes received
                if(bit_cnt[2:0] == 3'd7 && { jtag_rx_byte[6:0], tdi_o })
                    jtag_rx_toggle <= !jtag_rx_toggle;

                if(bit_cnt[2:0] == 3'd7 && (tx_rptr != tx_wptr))
                    jtag_tx_toggle <= !jtag_tx_toggle;                    

            end 

            // the number of bits received may not have been a multiple of 8 ...
            if(update_dr_o) bit_cnt <= 8'd0;
        end
    end
    
end

// --------------------------------------------------------------------------------------
// ----------------------------------   LEDs   ------------------------------------------
// --------------------------------------------------------------------------------------

reg [5:0] leds = 6'b100000;   
assign leds_n = ~leds;   

reg [7:0] r = 8'hff;
reg [7:0] g = 8'h00;
reg [7:0] b = 8'h00;
reg [2:0] state = 3'd0;
   
reg [31:0]	led_cnt;      
reg [31:0]	rgb_cnt;      
always @(posedge clk) begin

    led_cnt <= led_cnt + 32'd1;
    if(led_cnt == 32'd27_000_000/6) begin
        led_cnt <= 32'd0;
        leds <= { leds[0], leds[5:1] };
    end

    // cycle through rgb
    rgb_cnt <= rgb_cnt + 32'd1;
    if(rgb_cnt == 32'd100000) begin
        rgb_cnt <= 32'd0;

        if(state == 3'd0) begin
            if(g != 8'hff) g <= g + 8'd1;
            else           state <= 3'd1;
        end 
        if(state == 3'd1) begin
            if(r != 8'h00) r <= r - 8'd1;
            else           state <= 3'd2;
        end 
        if(state == 3'd2) begin
            if(b != 8'hff) b <= b + 8'd1;
            else           state <= 3'd3;
        end 
        if(state == 3'd3) begin
            if(g != 8'h00) g <= g - 8'd1;
            else           state <= 3'd4;
        end 
        if(state == 3'd4) begin
            if(r != 8'hff) r <= r + 8'd1;
            else           state <= 3'd5;
        end 
        if(state == 3'd5) begin
            if(b != 8'h00) b <= b - 8'd1;
            else           state <= 3'd0;
        end 
    end
end   

ws2812 ws2812_inst (
    .clk(clk),
    .color({b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],
            r[0],r[1],r[2],r[3],r[4],r[5],r[6],r[7],
            g[0],g[1],g[2],g[3],g[4],g[5],g[6],g[7]}),
    .data(ws2812)
);

endmodule

// To match emacs with gw_ide default
// Local Variables:
// tab-width: 4
// End:

