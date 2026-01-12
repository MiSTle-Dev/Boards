/*
 top.sv
 
 Mixed test core for the Console60k board

 JTAG:
 - Debugger sets TDI and TMS on falling edge of TCK
 - Target sampless TDI and TMS on rising edge of TCK
 - Target sets TDO on falling edge of TCK

 -> Data is always set on falling edge and sampled 
    on rising edge
 */ 

module top(
  input		   clk,
    
  output [1:0] leds_n,

  // JTAG connection
//  input		   tck,
//  input		   tms,
//  input		   tdi,
//  output	   tdo,
		   
  // hdmi/tdms
  output	   tmds_clk_n,
  output	   tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p
);

wire clk_pixel_x5;   // 125 MHz HDMI clock
wire clk_pixel;
wire pll_lock;

Gowin_PLL pll_125m_25m(
    .clkin(clk),
    .clkout0(clk_pixel_x5),
    .clkout1(clk_pixel),
    .lock(pll_lock),
    .mdclk(clk)
);

// generate a reset signal that is still some time valid after the clocks
// are stable
reg [15:0] reset_cnt;
wire reset = (reset_cnt != 0);
   
always @(posedge clk) begin
    if(!pll_lock)
        reset_cnt <= 16'd1000;
    else begin
        if(reset_cnt != 16'd0)
            reset_cnt <= reset_cnt - 16'd1;
    end
end

// -----------------------------------------------------
// ------------------    font    -----------------------
// -----------------------------------------------------

wire [7:0] fontrom_dout;
reg [7:0] chr;

// ---------- local video counter ----------------
wire [9:0] hcnt;
wire [9:0] vcnt;

// some text that is being displayed after reset
wire [7:0] init_message [52] = "MiSTle - TC60K Test\nWaiting for JTAG user data ...\n";
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

// fifo to receive data from JTAG (to be put onto screen)
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

// jtag byte rx interface
reg [7:0] jtag_rx_byte = 8'h00;  // (non-zero) byte received via JTAG
reg jtag_rx_toggle = 1'b0;       // toggle whenever a new byte has been received
reg jtag_tx_toggle = 1'b0;       // toggle whenever a new byte has been sent

// the text is only active if it's being driven via JTAG
reg [31:0] text_active_counter;
wire text_overlay_active = text_active_counter != 0;

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

        text_active_counter <= 32'd0;
    end else begin
        logic init;
        init = init_cnt < 52;   // init message is 52 characters long

        if(text_active_counter)
            text_active_counter <= text_active_counter - 32'd1;

        // todo: clear video mem after reset. Currently it's all zero which is ok, since
        // in the font, the zero character is blank

        // bring jtag_rx_toggle into the local clock domain and act on its change
        jtag_rx_toggleD <= jtag_rx_toggle;
        jtag_rx_toggleD2 <= jtag_rx_toggleD;
        if(jtag_rx_toggleD ^ jtag_rx_toggleD2) begin
            rx_fifo[rx_wptr] <= jtag_rx_byte;
            rx_wptr <= rx_wptr + 4'd1;
            text_active_counter <= 32'd100_000_000;
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

// ---------------------- background image -------------------------

// the image comes with a colormap and rle encoded data as generated
// by image_encoder.py

reg [23:0] colormap[537];
   initial $readmemh("mistle_cmap.mem", colormap);

reg [17:0] image_data[16812];
   initial $readmemh("mistle.mem", image_data);

reg [16:0] image_rom_addr;
reg [17:0] image_rom_data;   

// overlay image with text
reg [23:0] pixel_image;

wire [23:0] pixel_image_light = { 
    3'b111, pixel_image[23:19],
    3'b111, pixel_image[15:11],
    3'b111, pixel_image[7:3] };

wire [23:0] pixel_rgb = text_overlay_active?(pixel?24'h000000:pixel_image_light):pixel_image;

always @(posedge clk_pixel) begin
    // reset rom address after active image area
    if(vcnt == 480 && hcnt == 0) begin
        image_rom_addr <= 17'd0;
        image_rom_data <= image_data[0];
    end else begin
        if(hcnt < 640 && vcnt < 480) begin
            if(image_rom_data[7:0])
                image_rom_data[7:0] <= image_rom_data[7:0] - 8'd1;
            else begin
                image_rom_addr <= image_rom_addr + 17'd1;                
                image_rom_data <= image_data[image_rom_addr + 17'd1];
            end
        end
        pixel_image <= colormap[image_rom_data[17:8]];
    end
end

wire [2:0] tmds;
wire tmds_clock;

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

wire test_logic_reset;  
wire tck_o;
wire tdi_o;
wire run_test_idle_er1;   
wire run_test_idle_er2;   
wire shift_dr_capture_dr_o;            // SHIFT_IN|CAPTURE_IN
wire update_dr_o;                      // UPDATE_IN
wire enable_er1_o;                     // SEL_IN #1
wire enable_er2_o;                     // SEL_IN #2
wire tdo_er1_i;                        // TDO_OUT #1
wire tdo_er2_i;                        // TDO_OUT #2

GW_JTAG u_gw_jtag (
//  .tck_pad_i(tck),
//	.tms_pad_i(tms),
//	.tdi_pad_i(tdi),
//	.tdo_pad_o(tdo),
				   
    .tck_o(tck_o),                    
    .tdi_o(tdi_o),                    
    .test_logic_reset_o(test_logic_reset),
    .run_test_idle_er1_o(run_test_idle_er1),   
    .run_test_idle_er2_o(run_test_idle_er2),   
    .shift_dr_capture_dr_o(shift_dr_capture_dr_o),
    .pause_dr_o(),     
    .update_dr_o(update_dr_o),
    .enable_er1_o(enable_er1_o),
    .enable_er2_o(enable_er2_o),
    .tdo_er1_i(tdo_er1_i),             // TDO_OUT for ir == 0x42
    .tdo_er2_i(tdo_er2_i)              // TDO_OUT for ir == 0x43
);

reg [8:0] bit_cnt = 9'd1;
   
// on user1, transmit byte from tx_fifo if data is available. Else transmit zero
assign tdo_er1_i = (tx_rptr != tx_wptr)?tx_fifo[tx_rptr][bit_cnt[2:0]]:1'b0;

reg [6:0]  jtag_cmd = 7'h00;    // incoming command byte on gao#2   

// command 1 sets the single leds and the rgb led
reg [31:0] jtag_cmd1_rx_data;  // payload received for cmd1

assign tdo_er2_i = 1'b0;

reg	shift_dr_capture_dr_oD, update_dr_oD;
reg enable_er1_oD, enable_er2_oD;   
always @(posedge tck_o) begin
   // delay the control signals to make sure they are still valid on the falling tck edge
   shift_dr_capture_dr_oD <= shift_dr_capture_dr_o;
   update_dr_oD <= update_dr_o;   
   enable_er1_oD <= enable_er1_o;
   enable_er2_oD <= enable_er2_o;   
end		 

always @(negedge tck_o) begin
   
   if(shift_dr_capture_dr_oD) begin   // count and wrap from 255 (0xff) to 248 (0xf8)
	  if(bit_cnt != 9'd511) bit_cnt <= bit_cnt + 9'd1;
	  else		            bit_cnt <= bit_cnt - 9'd7;
   end else if(update_dr_oD)
	 bit_cnt <= 9'd1;
   
   // use gao#1 (ir == 0x42) for text IO
   if(enable_er1_oD) begin
	  if(shift_dr_capture_dr_oD) begin
		 jtag_rx_byte <= { tdi_o, jtag_rx_byte[7:1] };          // shift serial JTAG data in
		 
		 // one complete byte received: trigger fifo write. Ignore any 0 bytes received
		 if(bit_cnt[2:0] == 3'd0 && { tdi_o, jtag_rx_byte[7:1] })
           jtag_rx_toggle <= !jtag_rx_toggle;
			
		 if(bit_cnt[2:0] == 3'd7 && (tx_rptr != tx_wptr))
		   jtag_tx_toggle <= !jtag_tx_toggle;                    
	  end		
   end
   
   // use gao#2 (ir == 0x43) for debug io to mainly test the PSRAM
   if(enable_er2_oD) begin
	  if(shift_dr_capture_dr_oD) begin
		 // we'd like to shift the 8 bit command. We only shift 7 bits (as the counter starts
		 // at 1) and ignore the MSB (being sent last) to have the command available early to
		 // decide the source for shifting data out
		 if(bit_cnt < 8)
			jtag_cmd <= { tdi_o, jtag_cmd[6:1] };    // shift first 7 bit serial JTAG data in
		 
		 // command 1: shift into 32 bit led state
		 if(jtag_cmd == 7'h01 && bit_cnt > 8 && bit_cnt <= 40)
		   jtag_cmd1_rx_data <= { tdi_o, jtag_cmd1_rx_data[31:1] };
		 
	  end
	  
	  else if(update_dr_oD) begin
		 jtag_cmd <= 7'h00;
	  end
   end
end

// --------------------------------------------------------------------------------------
// ----------------------------------   LEDs   ------------------------------------------
// --------------------------------------------------------------------------------------

reg [1:0] leds = 2'b00;   
// drive leds from counter or if activated from jtag command
assign leds_n = jtag_cmd1_rx_data[31]?(~jtag_cmd1_rx_data[25:24]):~leds;
   
reg [7:0] wsr = 8'hff;
reg [7:0] wsg = 8'h00;
reg [7:0] wsb = 8'h00;
reg [2:0] state = 3'd0;
   
reg [31:0]	led_cnt;      
reg [31:0]	rgb_cnt;      
always @(posedge clk) begin

    led_cnt <= led_cnt + 32'd1;
    if(led_cnt == 32'd50_000_000/6) begin
        led_cnt <= 32'd0;
        leds <= { leds[0], leds[1]};
    end

    // cycle through rgb
    rgb_cnt <= rgb_cnt + 32'd1;
    if(rgb_cnt == 32'd100000) begin
        rgb_cnt <= 32'd0;

        if(state == 3'd0) begin
            if(wsg != 8'hff) wsg <= wsg + 8'd1;
            else             state <= 3'd1;
        end 
        if(state == 3'd1) begin
            if(wsr != 8'h00) wsr <= wsr - 8'd1;
            else             state <= 3'd2;
        end 
        if(state == 3'd2) begin
            if(wsb != 8'hff) wsb <= wsb + 8'd1;
            else             state <= 3'd3;
        end 
        if(state == 3'd3) begin
            if(wsg != 8'h00) wsg <= wsg - 8'd1;
            else             state <= 3'd4;
        end 
        if(state == 3'd4) begin
            if(wsr != 8'hff) wsr <= wsr + 8'd1;
            else             state <= 3'd5;
        end 
        if(state == 3'd5) begin
            if(wsb != 8'h00) wsb <= wsb - 8'd1;
            else             state <= 3'd0;
        end 
    end
end   

endmodule

// To match emacs with gw_ide default
// Local Variables:
// tab-width: 4
// End:

