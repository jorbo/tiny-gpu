###############################################################################
# Change list, formatted for PrimeTime
#
# 
#
###############################################################################
current_instance
current_instance {cores_0__core_instance/decoder_instance}
size_cell {U11} {OR3X2_LVT}
size_cell {decoded_alu_arithmetic_mux_reg_1_} {DFFSSRX2_LVT}
size_cell {decoded_alu_output_mux_reg} {DFFSSRX2_LVT}
current_instance
current_instance {cores_0__core_instance/scheduler_instance}
size_cell {U4} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__lsu_instance}
size_cell {U19} {OR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__register_instance}
size_cell {U110} {NOR3X2_LVT}
size_cell {U113} {NOR3X2_LVT}
size_cell {U117} {NOR2X2_LVT}
size_cell {U216} {NOR3X2_LVT}
size_cell {U218} {NOR2X2_LVT}
size_cell {U220} {NOR3X2_LVT}
size_cell {U221} {AND2X2_LVT}
size_cell {U26} {AND2X2_LVT}
size_cell {U27} {NOR2X2_LVT}
size_cell {U44} {NOR2X2_LVT}
size_cell {U60} {NOR2X2_LVT}
size_cell {U96} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_1__alu_instance}
size_cell {U449} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_1__lsu_instance}
size_cell {U7} {OR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_1__register_instance}
size_cell {U109} {NOR3X2_LVT}
size_cell {U11} {AND2X2_LVT}
size_cell {U110} {NOR2X2_LVT}
size_cell {U112} {NOR3X2_LVT}
size_cell {U115} {NOR2X2_LVT}
size_cell {U116} {NOR2X2_LVT}
size_cell {U217} {NOR3X2_LVT}
size_cell {U220} {NOR2X2_LVT}
size_cell {U222} {NOR3X2_LVT}
size_cell {U230} {AND2X2_LVT}
size_cell {U69} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__alu_instance}
size_cell {U198} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__lsu_instance}
size_cell {U7} {OR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__register_instance}
size_cell {U218} {NOR3X2_LVT}
size_cell {U221} {NOR2X2_LVT}
size_cell {U224} {AND2X2_LVT}
size_cell {U230} {AND2X2_LVT}
size_cell {U8} {NOR3X2_LVT}
size_cell {U83} {NOR2X2_LVT}
size_cell {U88} {NOR2X2_LVT}
size_cell {U90} {NOR3X2_LVT}
size_cell {U94} {NOR2X2_LVT}
size_cell {rt_reg_0_} {DFFSSRX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__alu_instance}
size_cell {U710} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__lsu_instance}
size_cell {U22} {OR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__register_instance}
size_cell {U221} {NOR3X2_LVT}
size_cell {U223} {NOR2X2_LVT}
size_cell {U225} {NOR3X2_LVT}
size_cell {U226} {AND2X2_LVT}
size_cell {U28} {AND2X2_LVT}
size_cell {U29} {NOR2X2_LVT}
size_cell {U60} {NOR2X2_LVT}
size_cell {U85} {NOR2X2_LVT}
size_cell {U88} {NOR3X2_LVT}
size_cell {U91} {NOR3X2_LVT}
size_cell {U95} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__lsu_instance}
insert_buffer [get_pins {U63/A}] NBUFFX4_LVT -new_net_names {net1} -new_cell_names {U1}
current_instance
current_instance {cores_0__core_instance/threads_3__alu_instance}
insert_buffer [get_pins {U486/A3 U45/A1 U691/A U308/A1 U504/A2 U74/A1 U324/A U140/A1 U721/A U160/A2 U169/A2 U364/A2 U568/A2 U584/A2 U209/A2 U425/A2 U253/A2 U254/A1 U648/A1 U13/A2 U650/A1}] NBUFFX4_LVT -new_net_names {net2} -new_cell_names {U2}
current_instance
current_instance {cores_0__core_instance/threads_3__lsu_instance}
insert_buffer [get_pins {U84/A}] NBUFFX4_LVT -new_net_names {net3} -new_cell_names {U86}
current_instance
current_instance {cores_0__core_instance/threads_3__alu_instance}
insert_buffer [get_pins {U111/A2 U112/A1 U576/A1 U208/A1 U212/A2 U238/A U241/A2 U242/A2 U246/A U250/A1 U251/A2 U252/A2 U253/A1 U255/A U256/A U257/A U258/A1 U259/A2 U10/A2 U25/A}] NBUFFX4_LVT -new_net_names {net4} -new_cell_names {U247}
current_instance
current_instance {cores_1__core_instance/decoder_instance}
size_cell {U13} {OR3X2_LVT}
size_cell {decoded_alu_arithmetic_mux_reg_1_} {DFFSSRX2_LVT}
size_cell {decoded_alu_output_mux_reg} {DFFSSRX2_LVT}
size_cell {decoded_immediate_reg_6_} {DFFASRX2_LVT}
current_instance
current_instance {cores_1__core_instance/scheduler_instance}
size_cell {U6} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__lsu_instance}
size_cell {U7} {OR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__register_instance}
size_cell {U215} {NOR3X2_LVT}
size_cell {U218} {NOR3X2_LVT}
size_cell {U219} {AND2X2_LVT}
size_cell {U225} {NOR2X2_LVT}
size_cell {U226} {AND2X2_LVT}
size_cell {U27} {NOR2X2_LVT}
size_cell {U349} {AOI21X2_LVT}
size_cell {U6} {NOR2X2_LVT}
size_cell {U7} {NOR2X2_LVT}
size_cell {U88} {NOR3X2_LVT}
size_cell {U91} {NOR3X2_LVT}
size_cell {U95} {NOR2X2_LVT}
size_cell {U99} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__lsu_instance}
insert_buffer [get_pins {U120/A}] NBUFFX4_LVT -new_net_names {net5} -new_cell_names {U248}
current_instance
current_instance {cores_1__core_instance/threads_0__alu_instance}
insert_buffer [get_pins {U476/A2 U495/A3 U690/A2 U504/A2 U77/A2 U81/A3 U143/A1 U723/A2 U150/A1 U156/A2 U206/A2 U406/A2 U216/A1 U425/A2 U253/A2 U254/A2 U255/A1 U256/A1 U259/A1 U260/A U261/A2 U21/A2 U28/A}] NBUFFX4_LVT -new_net_names {net6} -new_cell_names {U622}
current_instance
current_instance {cores_1__core_instance/threads_1__lsu_instance}
size_cell {U23} {OR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__register_instance}
size_cell {U10} {NOR3X2_LVT}
size_cell {U11} {NOR2X2_LVT}
size_cell {U218} {NOR3X2_LVT}
size_cell {U220} {NOR2X2_LVT}
size_cell {U222} {NOR3X2_LVT}
size_cell {U223} {AND2X2_LVT}
size_cell {U230} {AND2X2_LVT}
size_cell {U27} {NOR2X2_LVT}
insert_buffer [get_pins {U153/A3 U158/A3 U167/A3 U172/A3 U180/A3 U185/A3 U87/A3 U193/A3 U198/A3 U99/A3 U206/A3 U211/A3 U128/A4 U133/A3 U140/A3 U145/A3}] NBUFFX4_LVT -new_net_names {net7} -new_cell_names {U623}
size_cell {U83} {NOR2X2_LVT}
insert_buffer [get_pins {U153/A1 U158/A1 U167/A1 U172/A1 U180/A1 U185/A1 U87/A1 U193/A1 U198/A1 U99/A1 U206/A1 U211/A1 U128/A1 U133/A1 U140/A1 U145/A1}] NBUFFX4_LVT -new_net_names {net8} -new_cell_names {U624}
size_cell {U95} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__alu_instance}
insert_buffer [get_pins {U280/A2 U281/A U282/A2 U289/A U53/A U62/A2 U65/A1 U9/A2 U521/A1 U140/A1 U717/A2 U544/A1 U547/A2 U372/A2 U223/A1 U438/A2 U633/A4 U640/A1 U270/A2 U271/A2 U272/A2 U273/A1 U274/A}] NBUFFX4_LVT -new_net_names {net9} -new_cell_names {U721}
current_instance
current_instance {cores_1__core_instance/threads_1__lsu_instance}
insert_buffer [get_pins {U78/A}] NBUFFX4_LVT -new_net_names {net10} -new_cell_names {U722}
current_instance
current_instance {cores_1__core_instance/threads_2__alu_instance}
size_cell {U337} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__lsu_instance}
size_cell {U19} {OR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__register_instance}
size_cell {U12} {NOR2X2_LVT}
size_cell {U141} {NOR2X2_LVT}
size_cell {U217} {NOR3X2_LVT}
size_cell {U221} {NOR3X2_LVT}
size_cell {U222} {AND2X2_LVT}
size_cell {U230} {AND2X2_LVT}
size_cell {U26} {OR2X2_LVT}
size_cell {U86} {NOR3X2_LVT}
size_cell {U88} {NOR2X2_LVT}
size_cell {U90} {NOR3X2_LVT}
size_cell {U94} {NOR2X2_LVT}
size_cell {U98} {NOR2X2_LVT}
size_cell {U99} {NOR2X2_LVT}
size_cell {rt_reg_1__U4} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__alu_instance}
insert_buffer [get_pins {U676/A1 U507/A2 U512/A U91/A2 U95/A2 U96/A2 U97/A1 U535/A1 U362/A2 U177/A1 U581/A1 U253/A1 U254/A2 U255/A2 U256/A1 U257/A2 U258/A2 U259/A U260/A U261/A1 U14/A2}] NBUFFX4_LVT -new_net_names {net11} -new_cell_names {U726}
current_instance
current_instance {cores_1__core_instance/threads_2__lsu_instance}
insert_buffer [get_pins {U68/A}] NBUFFX4_LVT -new_net_names {net12} -new_cell_names {U727}
current_instance
current_instance {cores_1__core_instance/threads_3__alu_instance}
size_cell {U273} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__lsu_instance}
size_cell {U23} {OR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__register_instance}
size_cell {U110} {NOR2X2_LVT}
size_cell {U112} {NOR3X2_LVT}
size_cell {U114} {NOR2X2_LVT}
size_cell {U12} {NOR3X2_LVT}
size_cell {U218} {NOR3X2_LVT}
size_cell {U221} {NOR2X2_LVT}
size_cell {U223} {NOR3X2_LVT}
size_cell {U224} {AND2X2_LVT}
size_cell {U29} {NOR2X2_LVT}
size_cell {U32} {AND2X2_LVT}
size_cell {U33} {NOR2X2_LVT}
size_cell {U37} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__lsu_instance}
insert_buffer [get_pins {U67/A}] NBUFFX4_LVT -new_net_names {net13} -new_cell_names {U728}
current_instance
current_instance {cores_1__core_instance/threads_3__alu_instance}
insert_buffer [get_pins {U662/A2 U666/A2 U485/A2 U112/A1 U312/A1 U82/A1 U532/A3 U725/A2 U575/A2 U250/A1 U267/A2 U268/A2 U14/A1 U269/A2 U18/A1 U461/A2 U270/A2 U272/A1 U273/A U276/A U277/A}] NBUFFX4_LVT -new_net_names {net14} -new_cell_names {U743}
current_instance
current_instance {data_memory_controller}
size_cell {U1845} {NOR2X2_LVT}
size_cell {U1847} {NOR2X2_LVT}
size_cell {U2026} {OR2X2_LVT}
size_cell {U2223} {OR2X2_LVT}
size_cell {U2229} {OR2X2_LVT}
size_cell {U2237} {OR2X2_LVT}
size_cell {U2791} {OR2X2_LVT}
size_cell {U447} {OR2X2_LVT}
size_cell {U805} {OR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__register_instance}
size_cell {U114} {NOR2X2_LVT}
size_cell {U118} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_1__register_instance}
size_cell {U113} {NOR2X2_LVT}
size_cell {U125} {INVX2_LVT}
size_cell {U225} {NOR2X2_LVT}
size_cell {U226} {NOR2X2_LVT}
size_cell {U238} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__alu_instance}
size_cell {U63} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__register_instance}
size_cell {U103} {INVX2_LVT}
size_cell {U225} {NOR3X2_LVT}
size_cell {U227} {NOR2X2_LVT}
size_cell {U238} {INVX2_LVT}
size_cell {U7} {NOR2X2_LVT}
size_cell {U91} {NOR2X2_LVT}
size_cell {U95} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__register_instance}
size_cell {U103} {INVX2_LVT}
size_cell {U229} {NOR2X2_LVT}
size_cell {U240} {INVX2_LVT}
size_cell {U84} {NOR2X2_LVT}
size_cell {U92} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__register_instance}
size_cell {U222} {NOR2X2_LVT}
size_cell {U26} {NOR2X2_LVT}
size_cell {U325} {NOR2X2_LVT}
size_cell {U92} {NOR2X2_LVT}
size_cell {U96} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__alu_instance}
size_cell {U74} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__register_instance}
size_cell {U104} {INVX2_LVT}
size_cell {U238} {INVX2_LVT}
size_cell {U88} {NOR2X2_LVT}
size_cell {U91} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__register_instance}
size_cell {U107} {INVX2_LVT}
size_cell {U225} {NOR2X2_LVT}
size_cell {U226} {NOR2X2_LVT}
size_cell {U238} {INVX2_LVT}
size_cell {U91} {NOR2X2_LVT}
size_cell {U95} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__register_instance}
size_cell {U126} {INVX2_LVT}
size_cell {U227} {NOR2X2_LVT}
size_cell {U228} {NOR2X2_LVT}
size_cell {U239} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__register_instance}
size_cell {U153} {INVX4_LVT}
current_instance
