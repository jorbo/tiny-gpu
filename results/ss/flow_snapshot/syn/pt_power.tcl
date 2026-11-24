# PrimeTime timing check, area and power for a DC run (SAED32, same corner as synthesis: SS 0.75V 125C by default)
# Run from syn/:
#   pt_shell -x "set RUN_DIR runs/best_hvt; set VCD ../build/gpu_gls.vcd" -f pt_power.tcl | tee pt.log
# RUN_DIR: a sweep.sh run dir (out/gpu_netlist.v, out/gpu.sdc)
# VCD:     gate-level sim of that netlist at the same clock period (make gls), or an RTL
#          sim VCD with "set VCD_RTL 1" (PT maps registers/ports, propagates the rest)

# Library corner. Worst case (SS 0.75 V 125 C) per the project spec; override e.g. "set CORNER tt0p78v25c"
if {![info exists CORNER]} { set CORNER ss0p75v125c }
set LIB_DIR /usr/local/synopsys/pdk/SAED32_EDK/lib
set LIBS "$LIB_DIR/stdcell_rvt/db_nldm/saed32rvt_$CORNER.db \
          $LIB_DIR/stdcell_hvt/db_nldm/saed32hvt_$CORNER.db \
          $LIB_DIR/stdcell_lvt/db_nldm/saed32lvt_$CORNER.db"
set TOP gpu

if {![info exists RUN_DIR]} { set RUN_DIR runs/best_hvt }
if {![info exists VCD]}     { set VCD ../build/gpu_gls.vcd }
if {![info exists VCD_RTL]} { set VCD_RTL 0 }
# Separate report dir per workload, e.g. "set RPT_NAME pt_reports_matadd"
if {![info exists RPT_NAME]} { set RPT_NAME pt_reports }
set RPT $RUN_DIR/$RPT_NAME
file mkdir $RPT

set_app_var link_path "* $LIBS"
set_app_var power_enable_analysis true
set_app_var power_analysis_mode averaged

read_verilog $RUN_DIR/out/${TOP}_netlist.v
current_design $TOP
link_design
# Signoff DRC ECO from pt_eco.tcl (cell upsizing / buffers for max_capacitance); USE_ECO 0 skips it
if {![info exists USE_ECO]} { set USE_ECO 1 }
if {$USE_ECO && [file exists $RUN_DIR/out/eco_changes.tcl]} {
    echo "Applying ECO changes from $RUN_DIR/out/eco_changes.tcl"
    source $RUN_DIR/out/eco_changes.tcl
}

# DC's written SDC carries the clock, IO delays, driving cell and output load
read_sdc $RUN_DIR/out/${TOP}.sdc
# PT picks the same per-hierarchy wire load models as DC on its own (setup WNS matched DC at 2.55 ns).
# DC's WLM-derived SPEF re-computes wire delay as RC and came out 0.17 ns worse, so it is opt-in.
if {![info exists USE_SPEF]} { set USE_SPEF 0 }
if {$USE_SPEF && [file exists $RUN_DIR/out/${TOP}.spef]} {
    read_parasitics $RUN_DIR/out/${TOP}.spef
}
update_timing -full

# Timing signoff at this period
report_global_timing                        > $RPT/global_timing.rpt
report_timing -delay_type max -max_paths 10 > $RPT/timing_setup.rpt
report_timing -delay_type min -max_paths 10 > $RPT/timing_hold.rpt
report_constraint -all_violators            > $RPT/violators.rpt
report_clock -attributes                    > $RPT/clock.rpt

# Area: PT has no report_area, so sum library cell areas (DC area.rpt adds wire load net area)
set leaf_cells [get_cells -hierarchical -filter "is_hierarchical==false"]
set cell_area 0.0
foreach_in_collection c $leaf_cells {
    set cell_area [expr {$cell_area + [get_attribute [get_lib_cells -of_objects $c] area]}]
}
set area_rpt [open $RPT/area.rpt w]
puts $area_rpt "Leaf cells: [sizeof_collection $leaf_cells]"
puts $area_rpt "Cell area (um^2): [format %.3f $cell_area]"
close $area_rpt

# Switching activity
if {$VCD_RTL} {
    # DC's saif_map file maps RTL names (cores[0].core_instance...) to the netlist's
    if {[file exists $RUN_DIR/out/${TOP}_name_map.tcl]} {
        source $RUN_DIR/out/${TOP}_name_map.tcl
    }
    read_vcd -rtl -strip_path tb_gpu/dut $VCD
} else {
    read_vcd -strip_path tb_gpu/dut $VCD
}

update_power
report_switching_activity -list_not_annotated > $RPT/switching_activity.rpt
report_power                       > $RPT/power.rpt
report_power -hierarchy -levels 3  > $RPT/power_hier.rpt

# One-line summary
set clk_period [get_attribute [get_clocks clk] period]
set wns [get_attribute [get_timing_paths -delay_type max] slack]
set whs [get_attribute [get_timing_paths -delay_type min] slack]
set sum [open $RPT/summary.rpt w]
puts $sum "period_ns  [format %.3f $clk_period]"
puts $sum "freq_mhz   [format %.1f [expr {1000.0 / $clk_period}]]"
puts $sum "setup_wns  $wns"
puts $sum "hold_wns   $whs"
puts $sum "cell_area  [format %.3f $cell_area]"
puts $sum "total_pwr  [get_attribute [current_design] total_power]"
puts $sum "dyn_pwr    [expr {[get_attribute [current_design] internal_power] + [get_attribute [current_design] switching_power]}]"
puts $sum "leak_pwr   [get_attribute [current_design] leakage_power]"
close $sum
puts [exec cat $RPT/summary.rpt]

exit
