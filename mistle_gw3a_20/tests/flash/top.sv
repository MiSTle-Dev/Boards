/*
   top.sv
 
   flash test for MiSTle-Dev25K

   to convert image, export from inkscape to png and use
   imagemagick to convert to raw binary:
 
   convert mistle.png MONO:mistle.raw

   wire image to flash:
 
   openFPGALoader --external-flash -o 0x100000 mistle.raw

*/ 

module top(
  input		   clk,
  output [5:0] leds_n,
		   
  // qspi flash 
  output	   mspi_cs,
  output	   mspi_clk,
  inout		   mspi_wp,
  inout		   mspi_hold,
  inout		   mspi_di,
  inout		   mspi_do,

  // hdmi/tdms
  output	   tmds_clk_n,
  output	   tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p
);

wire clk_pixel_x5;   // 125 MHz HDMI clock
wire clk_pixel;
wire clk_flash;
wire clk_flash_x;
wire pll_lock;

pll_125m pll_125m (
    .clkout0(clk_pixel_x5),     // 125MHz
    .clkout1(clk_flash),        // 83.3MHz
    .clkout2(/*mspi_clk*/),         // 83.3MHz, 220°
    .lock(pll_lock),
    .mdclk(clk),
    .clkin(clk)
);

assign mspi_clk = !clk_flash;  
  
clkdiv5 clkdiv5 (
    .hclkin(clk_pixel_x5), // input hclkin
    .resetn(pll_lock),     // input resetn
    .clkout(clk_pixel)     // output clkout
);

wire [9:0] cx;
wire [9:0] cy;

wire	    flash_ready;   
wire [15:0] flash_dout;   
reg  [15:0] vdata;   

// video is 640 x 480 with frame size being 800 x 525
// thus cx runs from 0 to 799 and cy runs from 0 to 524

// pixel/video address counter
reg [31:0] pcnt;
always @(posedge clk_pixel) begin
   if(!pll_lock && !flash_ready) begin
	  pcnt <= 32'd0;
   end else begin
	  // shift video data out
	  vdata <= { vdata[14:0], 1'b0 };

	  // run pixel counter
	  if(cx == 799-16 && cy == 524)
		pcnt <= 32'd0;
	  else if(cx < 640-16 || cx > 799-16)
		pcnt <= pcnt + 32'd1;

	  // latch data every 16 pixel
	  if(!cx[3:0]) begin
		 vdata <= {
		    flash_dout[8],  flash_dout[9], flash_dout[10], flash_dout[11],
		   flash_dout[12], flash_dout[13], flash_dout[14], flash_dout[15],
				   
		    flash_dout[0],  flash_dout[1],  flash_dout[2],  flash_dout[3],
		    flash_dout[4],  flash_dout[5],  flash_dout[6],  flash_dout[7]
	     };	  
	  end
   end   
end

// 23 bit word address for 2^23 = 8M words = 16MBytes = 128 MBits
wire [22:0] flash_addr = { 8'd16, pcnt[18:4] };

// ram access starts once the rising edge of cs is detected
reg		cs;
always @(posedge clk_pixel)
   cs <= (pcnt[3:0] == 1);

assign leds_n = 6'b010101;   

flash flash (   
	.clk(clk_flash),
	.resetn(pll_lock),
	.ready(flash_ready), 

	.address(flash_addr), // 16 bit word address
	.cs(cs), 
	.dout(flash_dout),
	
	// interface to the chip
	.mspi_cs(mspi_cs),
	.mspi_di(mspi_di), // data in into flash chip
	.mspi_hold(mspi_hold),
	.mspi_wp(mspi_wp),
	.mspi_do(mspi_do), // data out from flash chip
	
	.busy()
);
  
wire [2:0] tmds;
wire tmds_clock;

// shift pixel data out, msb first   
wire [23:0] rgb = vdata[15]?24'h000000:24'hffffff;   

hdmi hdmi(
    .clk_pixel_x5(clk_pixel_x5),
    .clk_pixel(clk_pixel),
    .clk_audio(1'b0),

    .reset( 1'b0 ),
    .rgb(rgb),
    .audio_sample_word({16'h0000, 16'h0000}),

    .cx(cx),
    .cy(cy),

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

endmodule

// To match emacs with gw_ide default
// Local Variables:
// tab-width: 4
// End:

