# Patch the SAED32 cell models' mux UDPs for gate-level sim. Their tables have no row for an X
# select, so a mux whose selectable inputs agree still outputs X (real silicon outputs that value).
# With DC's netlist this kept scheduler core_state at X through reset: the state flop's next-state
# mux has select = its own X output while both data inputs are 0. Adds X-select rows only where
# every input the select could pick is equal.
/^primitive / { prim = $2 }
{ print }
$0 == "table" && prim ~ /^s_mux21/ {
    print "x    0    0    : 0;"; print "x    1    1    : 1;"
}
# s_mux41 columns: S1 S0 A4 A3 A2 A1; (S1,S0) 00->A1 01->A3 10->A2 11->A4
$0 == "table" && prim ~ /^s_mux41/ {
    for (v = 0; v <= 1; v++) {
        printf "0    x    ?    %d    ?    %d    : %d;\n", v, v, v
        printf "1    x    %d    ?    %d    ?    : %d;\n", v, v, v
        printf "x    0    ?    ?    %d    %d    : %d;\n", v, v, v
        printf "x    1    %d    %d    ?    ?    : %d;\n", v, v, v
        printf "x    x    %d    %d    %d    %d    : %d;\n", v, v, v, v, v
    }
}
