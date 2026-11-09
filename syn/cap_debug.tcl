# Compare DC's and PrimeTime's view of net capacitance on the same netlist (max_capacitance mismatch).
# Run from syn/ in either tool:
#   dc_shell -x "set RUN_DIR runs/lh_2.55_cg" -f cap_debug.tcl >| runs/lh_2.55_cg/cap_dc.log 2>&1
#   pt_shell -x "set RUN_DIR runs/lh_2.55_cg" -f cap_debug.tcl >| runs/lh_2.55_cg/cap_pt.log 2>&1

set LIB_DIR /usr/local/synopsys/pdk/SAED32_EDK/lib
set LIBS "$LIB_DIR/stdcell_rvt/db_nldm/saed32rvt_tt0p78v25c.db \
          $LIB_DIR/stdcell_hvt/db_nldm/saed32hvt_tt0p78v25c.db \
          $LIB_DIR/stdcell_lvt/db_nldm/saed32lvt_tt0p78v25c.db"
if {![info exists RUN_DIR]} { set RUN_DIR runs/lh_2.55_cg }
# Worst register-file pin in PT (8 fF limit, 10.51 fF in PT)
if {![info exists NET]} { set NET cores_0__core_instance/threads_0__register_instance/n48 }
set PIN cores_0__core_instance/threads_0__register_instance/U11/Y
set is_pt [string match pt_shell* $synopsys_program_name]

set_app_var link_path "* $LIBS"
if {!$is_pt} { set_app_var target_library $LIBS }
read_verilog $RUN_DIR/out/gpu_netlist.v
current_design gpu
if {$is_pt} { link_design } else { link }
if {$is_pt} { read_sdc $RUN_DIR/out/gpu.sdc } else { source $RUN_DIR/out/gpu.sdc }

echo "==== TOOL: $synopsys_program_name"
echo "==== wire load mode / selection"
foreach v {auto_wire_load_selection} {
    if {![catch {get_app_var $v} val]} { echo "$v = $val" }
}
catch {echo "top wire_load_mode attr: [get_attribute [current_design] wire_load_mode]"}
if {$is_pt} { catch {report_wire_load} } else { catch {report_wire_load} }

echo "==== WLM of the enclosing register design"
set reg [get_cells cores_0__core_instance/threads_0__register_instance]
catch {echo "ref: [get_attribute $reg ref_name]"}
foreach a {wire_load_model_max wire_load_model wire_load_selection_group_max area} {
    catch {echo "$a (cell): [get_attribute $reg $a]"}
}

echo "==== net $NET"
catch {report_net -connections -verbose $NET}
foreach a {wire_capacitance_max pin_capacitance_max total_capacitance_max wire_load_model_max} {
    catch {echo "$a: [get_attribute [get_nets $NET] $a]"}
}

echo "==== pin $PIN constraint"
catch {report_constraint -max_capacitance -verbose [get_pins $PIN]}
redirect -variable rpt {report_constraint -all_violators -max_capacitance}
echo "max_capacitance violators: [regexp -all {VIOLATED} $rpt]"

exit
