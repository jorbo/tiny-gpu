# Dump SAED32 SRAM macro data (area, leakage, timing arcs, internal power) from the compiled library.
# Run from syn/:  dc_shell -f sram_info.tcl >| sram_info.log 2>&1
if {![info exists SRAM_DB]} {
    set SRAM_DB /usr/local/synopsys/pdk/SAED32_EDK/lib/sram/db_nldm/saed32sram_tt1p05v25c.db
}
if {![info exists CELLS]} { set CELLS {SRAM1RW256x8 SRAM1RW64x8} }

read_db $SRAM_DB
set lib [get_object_name [index_collection [get_libs] end]]
echo "==== library $lib"
redirect -variable units {report_lib $lib}
foreach line [split $units "\n"] {
    if {[regexp -nocase {unit|nom_voltage|nom_temperature|Operating Conditions} $line]} { echo $line }
}

foreach c $CELLS {
    set lc [get_lib_cells -quiet $lib/$c]
    if {[sizeof_collection $lc] == 0} { echo "==== $c not found"; continue }
    echo "==== $c"
    foreach a {area cell_leakage_power dont_use} {
        catch {echo "$a: [get_attribute $lc $a]"}
    }
    foreach_in_collection p [get_lib_pins $lib/$c/*] {
        set n [get_object_name $p]
        set cap ""; catch {set cap [get_attribute $p capacitance]}
        echo "pin [file tail $n] dir=[get_attribute $p pin_direction] cap=$cap"
    }
}
# Full timing and power tables for the data-memory macro
echo "==== report_lib timing/power for [lindex $CELLS 0]"
catch {report_lib -timing_arcs -power $lib [lindex $CELLS 0]}
catch {report_lib -timing $lib [lindex $CELLS 0]}
exit
