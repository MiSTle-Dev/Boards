
module GW_JTAG (
	tck_pad_i,
	tms_pad_i,
	tdi_pad_i,
	tdo_pad_o,
	tck_o,                // DRCK_IN
	tdi_o,                // TDI_IN
	test_logic_reset_o,   // RESET_IN
	run_test_idle_er1_o,   
	run_test_idle_er2_o,   
	shift_dr_capture_dr_o,// SHIFT_IN | CAPTURE_IN
	pause_dr_o,     
	update_dr_o,          // UPDATE_IN
	enable_er1_o,         // SEL_IN
	enable_er2_o,         // SEL_IN
	tdo_er1_i,            // TDO_OUT
	tdo_er2_i             // TDO_OUT
)/* synthesis syn_black_box  */;

input wire tck_pad_i;
input wire tms_pad_i;
input wire tdi_pad_i;
output wire tdo_pad_o;
input wire tdo_er1_i;
input wire tdo_er2_i;
output wire tck_o;
output wire tdi_o;
output wire test_logic_reset_o;
output wire run_test_idle_er1_o;
output wire run_test_idle_er2_o;
output wire shift_dr_capture_dr_o;
output wire pause_dr_o;
output wire update_dr_o;
output wire enable_er1_o;
output wire enable_er2_o;

endmodule
