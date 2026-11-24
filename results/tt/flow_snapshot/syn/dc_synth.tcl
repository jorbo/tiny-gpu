# Design Compiler baseline synthesis for tiny-gpu (SAED32 RVT, TT 0.78V 25C)
# Run from syn/:  dc_shell -f dc_synth.tcl | tee dc.log
# Expects ../build/gpu.v from `make compile` and optionally ../build/gpu.saif

set LIB_DB /usr/local/synopsys/pdk/SAED32_EDK/lib/stdcell_rvt/db_nldm/saed32rvt_tt0p78v25c.db
set HVT_DB /usr/local/synopsys/pdk/SAED32_EDK/lib/stdcell_hvt/db_nldm/saed32hvt_tt0p78v25c.db
set LVT_DB /usr/local/synopsys/pdk/SAED32_EDK/lib/stdcell_lvt/db_nldm/saed32lvt_tt0p78v25c.db
set RTL    ../build/gpu.v
set SAIF   ../build/gpu.saif
set TOP    gpu

# Multi-Vt: dc_shell -x "set USE_HVT 1" -f dc_synth.tcl
# Adds HVT cells so DC can swap non-critical paths to low-leakage cells; results go to separate dirs
# Fastest: dc_shell -x "set USE_HVT 1; set USE_LVT 1" -f dc_synth.tcl (LVT on critical paths, HVT elsewhere)
# Frequency sweep (sweep.sh) sets RUN_DIR so each period gets its own out/ and reports/
if {![info exists USE_HVT]} { set USE_HVT 0 }
if {![info exists USE_LVT]} { set USE_LVT 0 }
# LVT+HVT only: dc_shell -x "set USE_HVT 1; set USE_LVT 1; set NO_RVT 1" -f dc_synth.tcl
# RVT stays linked (SDC driving cell, wire load models) but no RVT cell is mapped
if {![info exists NO_RVT]}  { set NO_RVT 0 }
# Automatic clock gating: set CLOCK_GATING 1. DC puts an integrated clock-gating cell in front of
# register banks that only load under an enable, so their clock pins stop toggling while idle.
if {![info exists CLOCK_GATING]} { set CLOCK_GATING 0 }
set LIBS $LIB_DB
if {$USE_HVT} { lappend LIBS $HVT_DB }
if {$USE_LVT} { lappend LIBS $LVT_DB }
if {[info exists RUN_DIR]} {
    set OUT $RUN_DIR/out
    set RPT $RUN_DIR/reports
} elseif {$USE_HVT} {
    set OUT  out_hvt
    set RPT  reports_hvt
} else {
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

# Track RTL->gate name changes so PrimeTime can annotate an RTL VCD onto the netlist
saif_map -start
check_design > $RPT/check_design.rpt

source constraints.sdc

# Overconstrain setup during optimization only: DC stops once WNS reaches ~0 and often lands
# 0.01 ns short, which made pass/fail at nearby periods look random. The margin is removed
# before reporting and write_sdc, so reports and PrimeTime see the real constraints.
if {![info exists SYN_MARGIN]} { set SYN_MARGIN 0.03 }
set_clock_uncertainty -setup [expr {0.1 + $SYN_MARGIN * $CLK_PERIOD}] [get_clocks clk]

# Tighter than the library's 1.02 ns limit so weak HVT drivers on high-fanout nets get upsized/buffered
if {$USE_HVT} {
    set_max_transition 0.9 [current_design]
}

# Ideal clock still carries 0.1 ns uncertainty on hold checks
set_fix_hold [get_clocks clk]

if {$NO_RVT} {
    set_dont_use [get_lib_cells saed32rvt_tt0p78v25c/*]
}

# First lib cell from the list that exists and isn't dont_use, as lib/cell
proc first_usable_cell {names} {
    foreach n $names {
        set lc [get_lib_cells -quiet */$n]
        if {[sizeof_collection $lc] && ![string is true -strict [get_attribute -quiet [index_collection $lc 0] dont_use]]} {
            return [get_object_name [index_collection $lc 0]]
        }
    }
    return ""
}

# Keep hierarchy so area/power can be broken down per module.
# If compile_ultra isn't licensed, use: compile -map_effort high
if {$CLOCK_GATING} {
    # DC's default style: integrated latch-based gating cells, banks of 3+ flops. An explicit
    # set_clock_gating_style (with or without a named cell) made DC insert no SAED32 gating cells.
    compile_ultra -no_autoungroup -gate_clock
    # SAED32 gating cells are latch_posedge_precontrol (test-enable pin), which DC refuses when named
    # in the style without a test control point (PWR-192). Its default pick is CGLPPRX*_RVT even
    # under NO_RVT (TE tied to 0), so swap each one to the fastest allowed Vt: same pins, and the
    # enable check sits on the setup-critical path.
    foreach_in_collection g [get_cells -hierarchical -quiet -filter "ref_name=~CGLPP*_RVT"] {
        set ref [get_attribute $g ref_name]
        regsub {_RVT$} $ref {} base
        set new [first_usable_cell [list ${base}_LVT ${base}_RVT ${base}_HVT]]
        if {$new ne "" && [file tail $new] ne $ref} {
            if {[catch {size_cell $g $new} msg]} { echo "ICG swap failed: $msg" }
        }
    }
    redirect -variable icg_rpt {
        foreach vt {LVT RVT HVT} {
            echo "  $vt: [sizeof_collection [get_cells -hierarchical -quiet -filter "ref_name=~CGLPP*_$vt"]]"
        }
    }
    echo "Clock gating cells after Vt swap:\n$icg_rpt"
} else {
    compile_ultra -no_autoungroup
}

# Incremental passes until setup and DRC are clean (HVT drivers can leave max_transition violations)
# Second pass on: ban the weakest X0 HVT drivers so high-fanout nets get a real driver
proc violation_count {} {
    redirect -variable rpt { report_constraint -all_violators -max_delay -max_transition -max_capacitance -min_delay }
    return [regexp -all {VIOLATED} $rpt]
}
for {set pass 0} {$pass < 3 && [violation_count] > 0} {incr pass} {
    if {$pass == 1 && $USE_HVT} {
        set_dont_use [get_lib_cells saed32hvt_tt0p78v25c/*X0_HVT]
    }
    compile_ultra -incremental -no_autoungroup
}

# Leftover DRC misses are tiny (~0.01 ns) on high-fanout nets driven by weak cells, e.g. core_state
# flops whose QN pin has a 0.35 ns library limit. Upsize each violating net's driver one step:
# next drive strength in the same Vt (X0->X1->X2...), else the same cell in a faster Vt.
proc drc_nets {} {
    set nets {}
    foreach kind {-max_transition -max_capacitance} {
        redirect -variable rpt "report_constraint -all_violators -nosplit -significant_digits 4 $kind"
        foreach line [split $rpt "\n"] {
            # Sub-0.005 ns misses print as "0.00  (VIOLATED: increase significant digits)"
            if {[regexp {^\s+(\S+)\s+-?[\d.]+\s+-?[\d.]+\s+-?[\d.]+\s+\(VIOLATED} $line -> net]} {
                lappend nets $net
            }
        }
    }
    return [lsort -unique $nets]
}
proc stronger_cell {ref} {
    set drives {X0 X1 X2 X4 X8 X16 X32}
    if {![regexp {^(.*)(X\d+)_(LVT|RVT|HVT)$} $ref -> base drive vt]} { return "" }
    foreach d [lrange $drives [expr {[lsearch $drives $drive] + 1}] end] {
        set lc [get_lib_cells -quiet */${base}${d}_$vt]
        # dont_use reads back "" when never set
        if {[sizeof_collection $lc] && ![string is true -strict [get_attribute -quiet [index_collection $lc 0] dont_use]]} {
            return [get_object_name [index_collection $lc 0]]
        }
    }
    foreach faster [lrange {HVT RVT LVT} [expr {[lsearch {HVT RVT LVT} $vt] + 1}] end] {
        set lc [get_lib_cells -quiet */${base}${drive}_$faster]
        if {[sizeof_collection $lc] && ![string is true -strict [get_attribute -quiet [index_collection $lc 0] dont_use]]} {
            return [get_object_name [index_collection $lc 0]]
        }
    }
    return ""
}
proc fix_drc {} {
    for {set pass 0} {$pass < 4 && [llength [set bad [drc_nets]]] > 0} {incr pass} {
        foreach net $bad {
            foreach_in_collection pin [get_pins -quiet -leaf -of_objects [get_nets $net] -filter "pin_direction==out"] {
                set cell [get_cells -of_objects $pin]
                set new  [stronger_cell [get_attribute $cell ref_name]]
                if {$new ne ""} {
                    echo "DRC fix: [get_object_name $cell] [get_attribute $cell ref_name] -> $new ($net)"
                    if {[catch {size_cell $cell $new} msg]} { echo "DRC fix failed: $msg" }
                } elseif {[set buf [first_usable_cell {NBUFFX4_LVT NBUFFX4_RVT NBUFFX4_HVT}]] ne ""} {
                    # Already the strongest cell of its type (e.g. NOR4X1_LVT): buffer the loads instead
                    set loads [get_pins -quiet -leaf -of_objects [get_nets $net] -filter "pin_direction==in"]
                    echo "DRC fix: buffer [sizeof_collection $loads] loads of $net with $buf"
                    if {[catch {insert_buffer $loads $buf} msg]} { echo "DRC fix failed: $msg" }
                }
            }
        }
    }
}
fix_drc

# Back to the real setup uncertainty from constraints.sdc for reports, SDC and PrimeTime
set_clock_uncertainty -setup 0.1 [get_clocks clk]

# Hold fix near the end: with LVT on short paths, compile_ultra meets setup but leaves hold misses
# (it ranks setup first), and any later setup pass undoes hold buffers. Running it
# after the margin is removed gives it the real setup slack to spend. compile_ultra here has no
# -only_hold_time, so plain compile inserts the delay.
proc hold_violations {} {
    redirect -variable rpt { report_constraint -all_violators -min_delay }
    return [regexp -all {VIOLATED} $rpt]
}
proc setup_violations {} {
    redirect -variable rpt { report_constraint -all_violators -max_delay }
    return [regexp -all {VIOLATED} $rpt]
}
# The hold pass can leave new transition misses, and hold buffers / DRC upsizing can push near-critical
# paths over (seen with clock gating: -0.08 ns on data_memory_controller). Alternate setup recovery,
# hold fixing and driver upsizing until all three are clean.
for {set pass 0} {$pass < 4 && ([setup_violations] > 0 || [hold_violations] > 0 || [llength [drc_nets]] > 0)} {incr pass} {
    if {[setup_violations] > 0} {
        echo "Setup recovery pass $pass: [setup_violations] violating endpoints"
        compile_ultra -incremental -no_autoungroup
    }
    if {[hold_violations] > 0} {
        echo "Hold fix pass $pass: [hold_violations] violating endpoints"
        compile -incremental_mapping -only_hold_time
    }
    fix_drc
}

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
report_timing -delay min -max_paths 10 > $RPT/timing_hold.rpt
report_constraint -all_violators -significant_digits 4 > $RPT/violators.rpt
report_constraint -all_violators -verbose -max_transition > $RPT/violators_drivers.rpt
report_net_fanout -high_fanout   > $RPT/high_fanout.rpt
report_power -hierarchy          > $RPT/power.rpt
report_power                     > $RPT/power_summary.rpt
if {$CLOCK_GATING} {
    report_clock_gating -gating_elements > $RPT/clock_gating.rpt
}

# Vt mix: how many leaf cells landed in each threshold flavor
set vt_rpt [open $RPT/vt_mix.rpt w]
foreach vt {LVT RVT HVT} {
    set n [sizeof_collection [get_cells -hierarchical -filter "is_hierarchical==false && ref_name=~*_$vt"]]
    puts $vt_rpt "$vt cells: $n"
}
close $vt_rpt

change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output $OUT/${TOP}_netlist.v
write_sdc $OUT/${TOP}.sdc
write_sdf $OUT/${TOP}.sdf
# PrimeTime has no per-hierarchy wire load models from the SDC; hand it DC's WLM parasitics so
# both tools see the same net caps (otherwise PT reports max_capacitance misses DC never saw)
write_parasitics -output $OUT/${TOP}.spef
saif_map -type ptpx -write_map $OUT/${TOP}_name_map.tcl

exit
