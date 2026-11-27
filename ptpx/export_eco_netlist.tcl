# Export the ECO-applied netlist so gate-level regression and power activity use the
# exact implementation PrimeTime signs off (pt_power.tcl applies eco_changes.tcl only
# inside its own session; the DC netlist on disk is unchanged).
#
# From repo root, after ptpx/pt_eco.tcl has written $RUN_DIR/out/eco_changes_dc.tcl:
#   dc_shell -x "set RUN_DIR build/sweeps/ss_lh_cg_a1_2.90" -f ptpx/export_eco_netlist.tcl
# Writes $RUN_DIR/out/gpu_netlist_eco.v. Simulate that file with sim.run --mode netlist
# and make gls NETLIST=...; keep gpu_netlist.v + eco_changes.tcl as the PT input.

source [file join [file dirname [info script]] .. scripts paths.tcl]

if {![info exists CORNER]} { set CORNER ss0p75v125c }
if {![info exists RUN_DIR]} { error "Set RUN_DIR explicitly (repository-relative or absolute)." }
set RUN_DIR [project_path $RUN_DIR]
set TOP gpu
set LIBDIR /usr/local/synopsys/pdk/SAED32_EDK/lib
set target_library [list \
    $LIBDIR/stdcell_lvt/db_nldm/saed32lvt_$CORNER.db \
    $LIBDIR/stdcell_hvt/db_nldm/saed32hvt_$CORNER.db \
    $LIBDIR/stdcell_rvt/db_nldm/saed32rvt_$CORNER.db]
set link_library [concat * $target_library]

set ECO $RUN_DIR/out/eco_changes_dc.tcl
if {![file exists $ECO]} { error "missing $ECO; run ptpx/pt_eco.tcl first" }

read_verilog -netlist $RUN_DIR/out/${TOP}_netlist.v
current_design $TOP
link
set before [sizeof_collection [get_cells -hierarchical -filter "is_hierarchical == false"]]
current_instance
source -echo $ECO
current_instance
current_design $TOP
set after [sizeof_collection [get_cells -hierarchical -filter "is_hierarchical == false"]]
echo "ECO export: leaf cells $before -> $after"

# Same naming rules as dc_synth.tcl's netlist write, so the testbench ports still match.
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output $RUN_DIR/out/${TOP}_netlist_eco.v
report_area > $RUN_DIR/out/eco_export_area.rpt
echo "Wrote $RUN_DIR/out/${TOP}_netlist_eco.v"
exit
