# Design Compiler baseline synthesis for tiny-gpu (SAED32 RVT, TT 0.78V 25C)
# Run from syn/:  dc_shell -f dc_synth.tcl | tee dc.log
# Expects ../build/gpu.v from `make compile` and optionally ../build/gpu.saif

set LIB_DB /usr/local/synopsys/pdk/SAED32_EDK/lib/stdcell_rvt/db_nldm/saed32rvt_tt0p78v25c.db
set HVT_DB /usr/local/synopsys/pdk/SAED32_EDK/lib/stdcell_hvt/db_nldm/saed32hvt_tt0p78v25c.db
set RTL    ../build/gpu.v
set SAIF   ../build/gpu.saif
set TOP    gpu

# Multi-Vt: dc_shell -x "set USE_HVT 1" -f dc_synth.tcl
# Adds HVT cells so DC can swap non-critical paths to low-leakage cells; results go to separate dirs
if {![info exists USE_HVT]} { set USE_HVT 0 }
if {$USE_HVT} {
    set LIBS "$LIB_DB $HVT_DB"
    set OUT  out_hvt
    set RPT  reports_hvt
} else {
    set LIBS $LIB_DB
    set OUT  out
    set RPT  reports
}

file mkdir $OUT $RPT

set_app_var target_library $LIBS
set_app_var link_path      "* $LIBS"

# Read and elaborate (sv2v output is plain Verilog-2005)
analyze -format verilog $RTL
elaborate $TOP
current_design $TOP
link
uniquify
check_design > $RPT/check_design.rpt

source constraints.sdc

# Keep hierarchy so area/power can be broken down per module.
# If compile_ultra isn't licensed, use: compile -map_effort high
compile_ultra -no_autoungroup

# Switching activity: annotate from simulation if available, else DC default toggle rates
if {[file exists $SAIF]} {
    read_saif -input $SAIF -instance_name tb_gpu/dut
    report_saif -hier > $RPT/saif.rpt
} else {
    echo "WARNING: $SAIF not found, power uses default (vectorless) activity"
}

report_qor                       > $RPT/qor.rpt
report_area -hierarchy           > $RPT/area.rpt
report_timing -max_paths 10      > $RPT/timing.rpt
report_constraint -all_violators > $RPT/violators.rpt
report_power -hierarchy          > $RPT/power.rpt
report_power                     > $RPT/power_summary.rpt

# Vt mix: how many leaf cells landed in each threshold flavor
set vt_rpt [open $RPT/vt_mix.rpt w]
foreach vt {RVT HVT} {
    set n [sizeof_collection [get_cells -hierarchical -filter "is_hierarchical==false && ref_name=~*_$vt"]]
    puts $vt_rpt "$vt cells: $n"
}
close $vt_rpt

change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output $OUT/${TOP}_netlist.v
write_sdc $OUT/${TOP}.sdc
write_sdf $OUT/${TOP}.sdf

exit
