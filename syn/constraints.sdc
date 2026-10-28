# Clock period in ns (override with: dc_shell -x "set CLK_PERIOD 5" -f dc_synth.tcl)
if {![info exists CLK_PERIOD]} { set CLK_PERIOD 10.0 }

create_clock -name clk -period $CLK_PERIOD [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition  0.1 [get_clocks clk]

# External memories / host modeled as using 20% of the cycle at the boundary
set non_clk_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay  [expr 0.2 * $CLK_PERIOD] -clock clk $non_clk_inputs
set_output_delay [expr 0.2 * $CLK_PERIOD] -clock clk [all_outputs]

set_driving_cell -lib_cell INVX1_RVT $non_clk_inputs
set_load 0.005 [all_outputs]
