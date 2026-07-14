/*
   top.sv
 
   sdram test for MiSTle-Dev25K
 
*/ 

module top(
  input			clk,

  // 256MBit*16 SDRAM
  output		O_sdram_clk,
  output		O_sdram_cs_n, // chip select
  output		O_sdram_cas_n, // columns address select
  output		O_sdram_ras_n, // row address select
  output		O_sdram_wen_n, // write enable
  inout [15:0]	IO_sdram_dq, // 16 bit bidirectional data bus
  output [12:0]	O_sdram_addr, // 13 bit multiplexed address bus
  output [1:0]	O_sdram_ba, // two banks
  output [1:0]	O_sdram_dqm, // 16/2
    
  // hdmi/tdms
  output		tmds_clk_n,
  output		tmds_clk_p,
  output [2:0]	tmds_d_n,
  output [2:0]	tmds_d_p
);

wire clk_pixel_x5;   // 125 MHz HDMI clock
wire clk_pixel;
wire pll_lock;

wire	sdram_clk;   
  
pll_125m pll_125m (
    .clkout0(clk_pixel_x5),     // 125MHz
    .clkout1(sdram_clk),        // 125MHz
    .clkout2(O_sdram_clk),      // 125MHz, 330°
    .lock(pll_lock),
    .mdclk(clk),
    .clkin(clk)
);

clkdiv5 clkdiv5 (
    .hclkin(clk_pixel_x5), // input hclkin
    .resetn(pll_lock),     // input resetn
    .clkout(clk_pixel)     // output clkout
);

wire [9:0] cx;
wire [9:0] cy;

wire	   sdram_ready;   
wire [15:0] sdram_dout;   
reg  [15:0] vdata;   

// video is 640 x 480 with frame size being 800 x 525
// thus cx runs from 0 to 799 and cy runs from 0 to 524

// pixel/video address counter
reg [31:0] pcnt;
always @(posedge clk_pixel) begin
   if(!pll_lock) begin
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
	  if(!cx[3:0]) vdata <= sdram_dout;
   end   

end

// setup test pattern in ram once sdram becomes ready
reg [18:0] setup_cnt;
reg        setup_done;
always @(posedge clk_pixel) begin
   if(!pll_lock || !sdram_ready) begin
	  setup_cnt <= 19'd0;	  
	  setup_done <= 1'b0;	  
   end else begin
	  if(!setup_done) begin
		 setup_cnt <= setup_cnt + 19'd1;
		 if(setup_cnt == 19'd307200-1)
		   setup_done <= 1'b1;
	  end
   end
end

// calculate pixel rows and columns
wire [9:0] row = setup_cnt[18:4]/40;
wire [9:0] col = setup_cnt[18:4]%40;  

// different 16x16 patterns
wire [15:0] white = 16'h0000;
wire [15:0] black = 16'hffff;
wire [15:0] checkerbox = row[0]?16'h5555:16'haaaa;
wire [15:0] checkerbox_inv = row[0]?16'haaaa:16'h5555;   
   
wire [15:0] sdram_din =
			(!col[0] && !row[4])?white:
			(!col[0] &&  row[4])?checkerbox:
			( col[0] && !row[4])?checkerbox_inv:
			black;
   
wire [23:0] vaddr = setup_done?pcnt[27:4]:setup_cnt[18:4];

// ram access starts once the rising edge of cs is detected
reg		cs;
always @(posedge clk_pixel)
  cs <= setup_done?(pcnt[3:0] == 1):(setup_cnt[3:0] == 1);
   
sdram sdram (
	 .sd_data    ( IO_sdram_dq   ), // 16 bit bidirectional data bus
     .sd_addr    ( O_sdram_addr  ), // 13 bit multiplexed address bus
     .sd_dqm     ( O_sdram_dqm   ), // two byte masks
     .sd_ba      ( O_sdram_ba    ), // four banks
     .sd_cs      ( O_sdram_cs_n  ), // a single chip select
     .sd_we      ( O_sdram_wen_n ), // write enable
     .sd_ras     ( O_sdram_ras_n ), // row address select
     .sd_cas     ( O_sdram_cas_n ), // columns address select

     // cpu/chipset interface
     .clk        ( sdram_clk     ), // sdram is accessed at 125MHz
     .reset_n    ( pll_lock      ), // init signal after FPGA config to initialize RAM

     .ready      ( sdram_ready   ), // ram is ready and has been initialized
     .refresh    ( 1'b0          ), // refresh cycle
     .din        ( sdram_din     ), // data input from chipset/cpu
     .dout       ( sdram_dout    ),
     .addr       ( vaddr         ), // 22 bit word address
     .ds         ( 2'b00         ), // upper/lower data strobe, ignored for read
     .cs         ( cs            ), // cpu/chipset requests read/write
     .we         ( !setup_done   )  // cpu/chipset requests write
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

