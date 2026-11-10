# PrimeTime DRC ECO: fix the max_capacitance pins PT flags but DC reports clean.
# Both tools see the same net capacitance and library limits; DC's synthesis-time DRC check
# still passes these nets, so they are fixed here, where signoff is done.
# Run from syn/:
#   pt_shell -x "set RUN_DIR runs/lh_2.55_cg" -f pt_eco.tcl >| runs/lh_2.55_cg/pt_eco.log 2>&1
# Writes $RUN_DIR/out/eco_changes.tcl (PT format, applied by pt_power.tcl when present) and
# eco_changes_dc.tcl (DC format, to apply to the netlist in dc_shell).

# Library corner. Worst case (SS 0.75 V 125 C) per the project spec; override e.g. "set CORNER tt0p78v25c"
if {![info exists CORNER]} { set CORNER ss0p75v125c }
set LIB_DIR /usr/local/synopsys/pdk/SAED32_EDK/lib
set LIBS "$LIB_DIR/stdcell_rvt/db_nldm/saed32rvt_$CORNER.db \
          $LIB_DIR/stdcell_hvt/db_nldm/saed32hvt_$CORNER.db \
          $LIB_DIR/stdcell_lvt/db_nldm/saed32lvt_$CORNER.db"
set TOP gpu
if {![info exists RUN_DIR]} { set RUN_DIR runs/lh_2.55_cg }
# Same Vt rule as synthesis: LVT + HVT only
if {![info exists ALLOWED_VT]} { set ALLOWED_VT {HVT LVT} }

set_app_var link_path "* $LIBS"
read_verilog $RUN_DIR/out/${TOP}_netlist.v
current_design $TOP
link_design
read_sdc $RUN_DIR/out/${TOP}.sdc
update_timing -full

proc lib_cell_ok {name} {
    global ALLOWED_VT
    if {![regexp {_(LVT|RVT|HVT)$} $name -> vt] || [lsearch $ALLOWED_VT $vt] < 0} { return "" }
    set lc [get_lib_cells -quiet */$name]
    if {[sizeof_collection $lc] == 0} { return "" }
    return [get_object_name [index_collection $lc 0]]
}
# Next drive strength in the same Vt, else the same drive in a faster allowed Vt
proc stronger_cell {ref} {
    if {![regexp {^(.*)(X\d+)_(LVT|RVT|HVT)$} $ref -> base drive vt]} { return "" }
    set drives {X0 X1 X2 X4 X8 X16 X32}
    foreach d [lrange $drives [expr {[lsearch $drives $drive] + 1}] end] {
        if {[set lc [lib_cell_ok ${base}${d}_$vt]] ne ""} { return $lc }
    }
    foreach faster [lrange {HVT RVT LVT} [expr {[lsearch {HVT RVT LVT} $vt] + 1}] end] {
        if {[set lc [lib_cell_ok ${base}${drive}_$faster]] ne ""} { return $lc }
    }
    return ""
}
proc cap_violators {} {
    redirect -variable rpt {report_constraint -all_violators -nosplit -max_capacitance -significant_digits 4}
    set pins {}
    foreach line [split $rpt "\n"] {
        if {[regexp {^\s+(\S+)\s+-?[\d.]+\s+-?[\d.]+\s+-?[\d.]+\s+\(VIOLATED} $line -> pin]} {
            lappend pins $pin
        }
    }
    return [lsort -unique $pins]
}
proc timing_summary {} {
    set wns [get_attribute [get_timing_paths -delay_type max] slack]
    set whs [get_attribute [get_timing_paths -delay_type min] slack]
    return "setup_wns $wns hold_wns $whs"
}

proc wns {} { return [get_attribute [get_timing_paths -delay_type max] slack] }
proc whs {} { return [get_attribute [get_timing_paths -delay_type min] slack] }
# A change is kept only if setup and hold stay >= 0 (or no worse than before, if already negative)
proc timing_ok {wns0 whs0} {
    update_timing
    set w [wns]; set h [whs]
    return [expr {$w >= min(0.0, $wns0) && $h >= min(0.0, $whs0)}]
}
proc buffer_cell_of {loads} {
    set net [get_nets -of_objects [index_collection $loads 0]]
    return [get_cells -of_objects [get_pins -leaf -of_objects $net -filter "direction==out"]]
}

echo "ECO start: [llength [cap_violators]] max_capacitance pins, [timing_summary]"
set buf [lib_cell_ok NBUFFX4_LVT]
set skipped {}
for {set pass 0} {$pass < 6} {incr pass} {
    set bad [lsearch -all -inline -not -exact [cap_violators] {}]
    foreach s $skipped { set bad [lsearch -all -inline -not -exact $bad $s] }
    if {[llength $bad] == 0} { break }
    echo "ECO pass $pass: [llength $bad] pins"
    foreach p $bad {
        set pin [get_pins -quiet $p]
        if {[sizeof_collection $pin] == 0} { continue }
        set wns0 [wns]; set whs0 [whs]
        set cell [get_cells -of_objects $pin]
        set ref  [get_attribute $cell ref_name]
        set done 0
        # 1) upsize the driver
        set new [stronger_cell $ref]
        if {$new ne "" && ![catch {size_cell $cell $new}]} {
            if {[timing_ok $wns0 $whs0]} { set done 1 } else { size_cell $cell [lib_cell_ok $ref] ; update_timing }
        }
        # 2) keep the driver, put the loads behind a buffer
        if {!$done} {
            set net   [get_nets -of_objects $pin]
            set loads [get_pins -quiet -leaf -of_objects $net -filter "direction==in"]
            if {[sizeof_collection $loads] > 1 && ![catch {insert_buffer $loads $buf}]} {
                if {[timing_ok $wns0 $whs0]} {
                    set done 1
                } else {
                    catch {remove_buffer [buffer_cell_of $loads]}
                    update_timing
                }
            }
        }
        if {!$done} { lappend skipped $p ; echo "ECO skip $p ($ref): no timing-safe fix" }
    }
}
echo "ECO end: [llength [cap_violators]] max_capacitance pins, [timing_summary]"

redirect $RUN_DIR/out/eco_violators.rpt {report_constraint -all_violators}
write_changes -format ptsh  -output $RUN_DIR/out/eco_changes.tcl
write_changes -format dctcl -output $RUN_DIR/out/eco_changes_dc.tcl
echo "ECO changes: [exec wc -l < $RUN_DIR/out/eco_changes.tcl] lines -> $RUN_DIR/out/eco_changes.tcl"

exit
