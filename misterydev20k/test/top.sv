/*
 top.sv
 
 Mixed test core for the dev20k board

 JTAG:
 - Debugger sets TDI and TMS on falling edge of TCK
 - Target sampless TDI and TMS on rising edge of TCK
 - Target sets TDO on falling edge of TCK

 -> Data is always set on falling edge and sampled 
    on rising edge
 */ 

module top(
  input		   clk,
    
  output	   ws2812,
  output [5:0] leds_n,

  // qspi psram
  output	   psram_csn,
  output	   psram_clk,
  inout [3:0]  psram_io,

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

// ----------------------  QSPI PSRAM ---------------------------

// This has been tested up to 100.265MHz. At much lower frequencies, the extra
// read delay may need to be set to 0

// This should be working up to 108MHz, bit does not work at 104 MHz
   
wire pll_psram_lock;
wire clk_psram;
      
pll_psram pll_psram (
    .clkin(clk),
    .lock(pll_psram_lock),
    .clkout(clk_psram),      // 100.265MHz
    .clkoutp(psram_clk)      // 337.5°/-22.5° shifted
);

// For maximum performance, we operate the PSRAM in WRAP32 mode which in
// turn means, that max 32 bytes starting at a 32 byte boundary can
// be transferred at once to never cross a 32 byte boundary as the transfer
// would wrap there (wrap32)   
localparam JTAG_PSRAM_IO_LEN = { 6'd32, 3'b000 };   // 256 bits / 32 bytes

localparam EXTRA_READ_DELAY = 1;   
   
reg [3:0] pdout;
reg pcsn;

assign psram_io = pdout;   // drive SPI data on io[0] and read on io[1]
assign psram_csn = pcsn;   // drive chip select

// 8 bit command codes
wire [7:0] cmd_wr      = 8'h02;  // write
wire [7:0] cmd_qpi     = 8'h35;  // enter qpi mode
wire [7:0] cmd_rst_en  = 8'h66;  // reset enable
wire [7:0] cmd_rst     = 8'h99;  // reset
wire [7:0] cmd_eid     = 8'h9f;  // SPI read ID
wire [7:0] cmd_wrap32  = 8'hc0;  // wrap boundary toggle
wire [7:0] cmd_quad_rd = 8'heb;  // fast read quad (109MHz max)
wire [7:0] cmd_spi     = 8'hf5;  // quad mode exit

reg  [63:0] reply_eid;   // eid reply is 64 bits in total

reg  [JTAG_PSRAM_IO_LEN-1:0] psram_data_out;
reg  [JTAG_PSRAM_IO_LEN-1:0] psram_data_in;

// PSRAM init state machine
reg [15:0] psram_init = 16'h0000;   

// external interface
reg	       psram_select = 1'b0;
reg	       psram_write  = 1'b0;

localparam LAST_INIT_STATE = 16'd512;   
   
reg [8:0]  psram_state;   // enough states for 256 bit transfers
reg [23:0] psram_addr;
wire	   psram_busy = (psram_state != 8'hff);
wire	   psram_ready = (psram_init == LAST_INIT_STATE);   
wire	   [7:0] vendor = reply_eid[63:56];
wire	   psram_ok = reply_eid[55:48] == 8'h5d;
wire	   psram_valid = (reply_eid[55:52] == 4'h5) && (reply_eid[50:48] == 3'h5);   
wire [31:0] psram_status = { psram_ready, psram_valid, psram_busy, 5'b00000, vendor,
							 2'b00, JTAG_PSRAM_IO_LEN[8:3], 8'h00 };   
reg [1:0] last_select = 2'b00;	  

always @(posedge clk_psram or negedge pll_psram_lock) begin
   if(!pll_psram_lock) begin
      pcsn <= 1'b1;          // disable chip
	  pdout <= 4'bzzzz;      // don't drive data lines
      reply_eid <= 64'd0;
	  psram_init <= 16'd0;	  
	  psram_state <= 9'h1ff;
	  last_select <= 2'b00;	  
   end else begin
      pcsn <= 1'b1;     // default chipselect is not selected (1)
	  pdout <= 4'bzzzz; // by default data lines are undriven
	  
	  // run through init state machine
      if(psram_init != LAST_INIT_STATE) begin
         psram_init <= psram_init + 16'd1;   
	  
		 // =============== return from QPI to SPI mode  ============= 

		 // The chip may be in QPI mode, so send the
		 // qpi quad mode exit command to return to SPI.
		 // This should not cause any harm when the chip
		 // already is in SPI mode		 
		 if(psram_init >= 50 && psram_init < 50+2) begin
			pcsn <= 1'b0;			
			if(psram_init == 50) pdout <= cmd_spi[7:4];
			if(psram_init == 51) pdout <= cmd_spi[3:0];
		 end

		 // =============== reset chip ============= 
		 if(psram_init >= 60 && psram_init < 60+8) begin
			pcsn <= 1'b0;                 // select chip
			pdout[0] <= cmd_rst_en[60 + 8 - psram_init - 1];
		 end
		 
		 if(psram_init >= 70 && psram_init < 70+8) begin
			pcsn <= 1'b0;                 // select chip
			pdout[0] <= cmd_rst[70 + 8 - psram_init - 1];
		 end
		 
		 // =============== identify chip ============= 
		 if(psram_init >= 256 && psram_init <= 256+32+64+EXTRA_READ_DELAY) begin
			static logic [7:0] b = psram_init - 256;
			pcsn <= !(psram_init < 256+32+64);   // select chip, except in last (read) state
		 
			// shift out command and 24 (unused) address bits
			if(b < 8) pdout[0] <= cmd_eid[7-b];
			else if(b < 32) pdout[0] <= 1'b0;			
			
			// shift data in with one bit delay and extra read delay
			else if(b > 32+EXTRA_READ_DELAY && b <= 32+64+EXTRA_READ_DELAY)
			  reply_eid <= { reply_eid[62:0], psram_io[1]};
		 end

 		 // =============== enable WRAP32 ==================
		 // Only wrap32 allows for max clock. The command actually
		 // toggles between both modes. Thus the previous reset
		 // command makes sure that wrap32 is off, so this command
		 // will switch it on
		 if(psram_init >= 350 && psram_init < 350+8) begin
			pcsn <= 1'b0;                 // select chip
			pdout[0] <= cmd_wrap32[350 + 8 - psram_init - 1];
		 end
		 
		 // ============ switch into QPI mode ==================
		 if(psram_init >= 400 && psram_init < 400+8) begin
			pcsn <= 1'b0;
			pdout[0] <= cmd_qpi[400 + 8 - psram_init - 1];
		 end

		 // init state runs up to LAST_INIT_STATE (currently 512)
		 
	  end else 

	  begin
		 // normal operation		 
		 if(psram_state == 9'h1ff) begin
			// bring select signal into local clock domain
			last_select <= { last_select[0], psram_select };			

			// start state machine on rising edge of select
			if(last_select == 2'b01) begin			   
			   psram_state <= 9'd0;
			   psram_data_out <= 0;
			end
		 end else begin
			pcsn <= 1'b0;   // select chip
			
			// IO state machine in progress
			if(!psram_write) begin			
			   // state 0..1, send fast read quad command
			   if(psram_state == 0) pdout <= cmd_quad_rd[7:4];			
			   if(psram_state == 1) pdout <= cmd_quad_rd[3:0];			
			   
			   // state 2..7, send 24 bit address
			   if((psram_state >= 2) && (psram_state < 2+6))
				 pdout <= psram_addr[23-4*(psram_state-2) -:4];
			   
			   // switch data lines to input
			   if(psram_state == 2+6)
				 pdout <= 4'bzzzz;			

			   // read 4 data bits into transmit buffer
			   if((psram_state > 2+6+6+EXTRA_READ_DELAY) && 
				  (psram_state <= 2+6+6+EXTRA_READ_DELAY+(JTAG_PSRAM_IO_LEN/4)))
				 psram_data_out <= { psram_data_out[JTAG_PSRAM_IO_LEN-4:0], psram_io};
			   
			   if(psram_state < 2+6+6+EXTRA_READ_DELAY+(JTAG_PSRAM_IO_LEN/4))
				 psram_state <= psram_state + 1;
			   else begin 
				  pcsn <= 1'b1;
				  psram_state <= 9'h1ff; 
			   end
			   
			end	else begin // if (!psram_write)
			   
			   // state 0..1, send write command
			   if(psram_state == 0) pdout <= cmd_wr[7:4];
			   if(psram_state == 1) pdout <= cmd_wr[3:0];
			   
			   // state 2..7, send 24 bit address
			   if((psram_state >= 2) && (psram_state < 2+6))
				 pdout <= psram_addr[23-4*(psram_state-2) -:4];
			   
			   // write 4 data bits from receive buffer
			   if((psram_state >= 2+6) && (psram_state < 2+6+(JTAG_PSRAM_IO_LEN/4)))
				 pdout <= psram_data_in[JTAG_PSRAM_IO_LEN-1-4*(psram_state-(2+6)) -:4];
			   
			   if(psram_state < 2+6+(JTAG_PSRAM_IO_LEN/4)) psram_state <= psram_state + 1;
			   else begin pcsn <= 1'b1; psram_state <= 9'h1ff; end
			end
		 end
	  end	  
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
//    .tck_pad_i(tck),
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

reg [23:0] psram_addr;  // payload received for cmd5
   
wire [4:0] byte_index = bit_cnt[7:3];

// The xor reverses the byte order, but nor the bit order
wire [7:0] bit_index = (bit_cnt-9'd48) ^ 9'b111111000;   

// TODO: The first bit returned is broken		   

// the psram is still busy ...
assign tdo_er2_i =
				   // cmd 2: read PSRAM status
				   (jtag_cmd == 7'h02)?(
							// return the 16 psram status seperated into bytes. The xor reverses
							// the byte order, but nor the bit order
							psram_status[(bit_cnt-9'd8) ^ 9'b111111000]
							):
				   // cmd 3: read ram
				   (jtag_cmd == 7'h03)?(
							psram_data_out[(bit_cnt-9'd40) ^ 9'b11111000]):
				   1'b0;

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
		 if(bit_cnt[2:0] == 3'd8 && { tdi_o, jtag_rx_byte[7:1] })
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
		 
		 // command 3 or 4: shift into 24 bit psram address
		 if((jtag_cmd == 7'h03 || jtag_cmd == 7'h04) && bit_cnt > 8 && bit_cnt <= 32) begin
			psram_addr  <= { tdi_o, psram_addr[23:1] };

			// trigger a command 3 read directly after the address has been received
			if(bit_cnt == 32 && jtag_cmd == 7'h03) begin
			   psram_select <= 1'b1;
			   psram_write <= 1'b0;
			end
		 end

		 // command 4: receive 32 bytes / 256 bits payload
		 if(jtag_cmd == 7'h04 && bit_cnt > 32 && bit_cnt <= 32+JTAG_PSRAM_IO_LEN) begin
			psram_data_in  <= { tdi_o, psram_data_in[JTAG_PSRAM_IO_LEN-1:1] };
			
			// trigger a command 4 write after the data has been received
			if(bit_cnt == 32+JTAG_PSRAM_IO_LEN) begin
			   psram_select <= 1'b1;
			   psram_write <= 1'b1;
			end
		 end
	  end
	  
	  else if(update_dr_oD) begin
		 jtag_cmd <= 7'h00;
		 psram_select <= 1'b0;
	  end
   end
end

// --------------------------------------------------------------------------------------
// ----------------------------------   LEDs   ------------------------------------------
// --------------------------------------------------------------------------------------

reg [5:0] leds = 6'b100000;   
// drive leds from counter or if activated from jtag command
assign leds_n = jtag_cmd1_rx_data[31]?(~jtag_cmd1_rx_data[29:24]):~leds;
   
reg [7:0] wsr = 8'hff;
reg [7:0] wsg = 8'h00;
reg [7:0] wsb = 8'h00;
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

// drive rgb led from internal rgb animation or from jtag command if set  
wire [7:0] r = jtag_cmd1_rx_data[30]?jtag_cmd1_rx_data[23:16]:wsr;
wire [7:0] g = jtag_cmd1_rx_data[30]?jtag_cmd1_rx_data[15:8]:wsg;
wire [7:0] b = jtag_cmd1_rx_data[30]?jtag_cmd1_rx_data[7:0]:wsb;
   
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

