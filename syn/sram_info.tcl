# SAED32 SRAM macro data at TT 1.05 V: area, leakage, pin caps, and the access/setup times
# measured by PrimeTime on a register-wrapped macro (sram_probe.v).
# Run from syn/:  pt_shell -f sram_info.tcl >| sram_info.log 2>&1
set PDK /usr/local/synopsys/pdk/SAED32_EDK/lib
if {![info exists SRAM_DB]} { set SRAM_DB $PDK/sram/db_nldm/saed32sram_tt1p05v25c.db }
set LVT_DB $PDK/stdcell_lvt/db_nldm/saed32lvt_tt0p78v25c.db
if {![info exists CELLS]} { set CELLS {SRAM1RW256x8 SRAM1RW64x8} }
# Probe clock: relaxed so nothing is cut off; the arcs are what we want
set PERIOD 10.0

set_app_var link_path "* $SRAM_DB $LVT_DB"
set_app_var power_enable_analysis true
read_verilog sram_probe.v
current_design sram_probe
link_design

set lib [get_object_name [index_collection [get_libs *sram*] 0]]
echo "==== library $lib"
foreach a {time_unit capacitive_load_unit leakage_power_unit voltage_unit current_unit nom_voltage nom_temperature} {
    catch {echo "$a: [get_attribute [get_libs $lib] $a]"}
}

foreach c $CELLS {
    set lc [get_lib_cells -quiet $lib/$c]
    if {[sizeof_collection $lc] == 0} { echo "==== $c not found"; continue }
    echo "==== $c"
    foreach a {area cell_leakage_power} {
        catch {echo "$a: [get_attribute $lc $a]"}
    }
    foreach_in_collection p [get_lib_pins $lib/$c/*] {
        set cap ""; catch {set cap [get_attribute $p pin_capacitance]}
        echo "pin [file tail [get_object_name $p]] dir=[get_attribute $p direction] cap=$cap"
    }
    # Library timing arcs: type and sense per pin pair
    catch {
        foreach_in_collection arc [get_lib_timing_arcs -of_objects $lc] {
            echo "arc [get_attribute $arc from_lib_pin_name] -> [get_attribute $arc to_lib_pin_name] [get_attribute $arc sense]"
        }
    }
}

create_clock -name clk -period $PERIOD [get_ports clk]
set_input_delay 0 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 0 -clock clk [all_outputs]
set_load 0.005 [all_outputs]
update_timing -full

echo "==== access time: CE -> O -> q_r (read path)"
report_timing -from [get_pins mem/CE] -to [get_cells q_reg_*] -max_paths 1 -nosplit -input_pins
echo "==== setup checks at the macro inputs"
report_timing -to [get_pins mem/A*]   -max_paths 1 -nosplit
report_timing -to [get_pins mem/CSB]  -max_paths 1 -nosplit
report_timing -to [get_pins mem/I*]   -max_paths 1 -nosplit
report_timing -to [get_pins mem/WEB]  -max_paths 1 -nosplit
echo "==== hold checks at the macro inputs"
report_timing -delay_type min -to [get_pins mem/A*] -max_paths 1 -nosplit
echo "==== macro leakage in this design"
update_power
report_power -cell_power [get_cells mem]
exit
