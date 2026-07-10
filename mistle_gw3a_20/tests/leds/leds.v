/*
    leds.v - GW5A-LV25-LQ144-C1/I0
*/ 

module top(
  input			clk, // 50 MHz in

  input			reset_n, // S2
  input			user_n, // S1

  output [5:0]	leds_n,
  output		ws2812
);

// ====================== six green leds =========================
reg [31:0]	cnt;
reg [5:0] pattern = 6'b011111;
assign leds_n = pattern;   
   
always @(posedge clk) begin
   cnt <= cnt + 32'd1;

   if(cnt[21:0] == 0) begin
	  if(user_n) pattern <= { pattern[0], pattern[5:1] };
	  else       pattern <= { pattern[4:0], pattern[5] };
   end
   
end

// ====================== ws2812 led =========================
reg [7:0] wsr = 8'hff;
reg [7:0] wsg = 8'h00;
reg [7:0] wsb = 8'h00;
reg [2:0] state = 3'd0;
   
reg [31:0]      rgb_cnt;      
always @(posedge clk) begin

    // cycle through rgb
    rgb_cnt <= rgb_cnt + 32'd1;
    if(rgb_cnt == 32'd500000) begin
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
wire [7:0] r = wsr;
wire [7:0] g = wsg;
wire [7:0] b = wsb;
   
ws2812 #(.CLK_FRE(50_000_000)) ws2812_inst (
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
