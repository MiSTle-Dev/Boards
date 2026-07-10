/*
 top.sv
*/ 

module top(
  input		   clk,
    
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
    .clkout0(clk_pixel_x5),
    .lock(pll_lock),
    .mdclk(clk),
    .clkin(clk)
);
   
clkdiv5 clkdiv5 (
    .hclkin(clk_pixel_x5), // input hclkin
    .resetn(pll_lock),     // input resetn
    .clkout(clk_pixel)     // output clkout
);

wire [2:0] tmds;
wire tmds_clock;

wire [9:0] cx;
wire [9:0] cy;

wire [23:0] rgb = { cy[8:5], cx[8:5], {cx[4:0], 3'b000}, {cy[4:0], 3'b000} };
   
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

