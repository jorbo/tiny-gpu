###############################################################################
# Change list, formatted for PrimeTime
#
# 
#
###############################################################################
current_instance
current_instance {cores_0__core_instance}
size_cell {U5} {NBUFFX8_HVT}
size_cell {U6} {NBUFFX8_HVT}
current_instance
current_instance {cores_0__core_instance/fetcher_instance}
size_cell {U3} {INVX2_HVT}
current_instance
current_instance {cores_0__core_instance/scheduler_instance}
size_cell {U26} {INVX2_HVT}
current_instance
current_instance {cores_0__core_instance/threads_0__alu_instance}
size_cell {U120} {INVX2_LVT}
size_cell {U50} {MUX21X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__register_instance}
size_cell {U11} {AND2X2_LVT}
size_cell {U148} {AND2X2_HVT}
size_cell {U207} {AND3X2_HVT}
size_cell {U22} {AND2X2_HVT}
insert_buffer [get_pins {U258/A3 U269/A3 U273/A3 U283/A4 U287/A3 U298/A3 U5/A3 U7/A3 U9/A3 U302/A3 U212/A3 U216/A3 U316/A3 U226/A3 U230/A3 U244/A3}] NBUFFX4_LVT -new_net_names {net1} -new_cell_names {U1}
size_cell {U25} {AND2X2_HVT}
size_cell {U26} {AND2X2_HVT}
size_cell {U27} {AND2X2_HVT}
size_cell {U28} {AND2X2_HVT}
size_cell {U29} {AND2X2_HVT}
size_cell {U35} {AND3X2_LVT}
size_cell {U38} {AND3X2_HVT}
size_cell {U39} {AND3X2_HVT}
size_cell {U83} {AND3X2_LVT}
size_cell {U85} {AND3X2_LVT}
size_cell {U89} {AND3X2_HVT}
size_cell {U90} {AND3X2_HVT}
size_cell {U93} {AND3X2_LVT}
size_cell {U95} {AND3X2_HVT}
current_instance
current_instance {cores_0__core_instance/threads_1__alu_instance}
insert_buffer [get_pins {U289/A2 U103/A2 U305/A2 U351/A2 U365/B U372/A2 U406/A2 U419/A1 U228/A2 U242/A2 U436/A2}] NBUFFX4_LVT -new_net_names {net2} -new_cell_names {U2}
current_instance
current_instance {cores_0__core_instance/threads_1__register_instance}
size_cell {U17} {AND2X2_HVT}
insert_buffer [get_pins {U253/A1 U262/A1 U267/A1 U276/A1 U187/A1 U282/A1 U193/A1 U290/A1 U296/A1 U202/A1 U208/A1 U217/A1 U223/A1 U233/A2 U238/A1 U247/A1}] NBUFFX4_LVT -new_net_names {net3} -new_cell_names {U304}
size_cell {U186} {AND3X2_HVT}
size_cell {U20} {AND2X2_HVT}
size_cell {U22} {AND2X2_HVT}
size_cell {U23} {AND2X2_HVT}
size_cell {U24} {AND2X2_HVT}
size_cell {U255} {AND2X2_HVT}
size_cell {U300} {AND2X2_LVT}
size_cell {U31} {AND3X2_HVT}
insert_buffer [get_pins {U252/A1 U266/A1 U277/A1 U188/A1 U281/A1 U192/A1 U291/A1 U295/A1 U7/A1 U203/A1 U207/A1 U218/A1 U222/A1 U232/A2 U237/A1 U248/A1}] NBUFFX4_LVT -new_net_names {net4} -new_cell_names {U336}
size_cell {U325} {AND3X2_LVT}
size_cell {U329} {AND3X2_LVT}
size_cell {U33} {AND3X2_HVT}
size_cell {U333} {AND3X2_HVT}
size_cell {U67} {AND3X2_LVT}
insert_buffer [get_pins {U157/A2 U165/A2 U172/A2 U83/A2 U91/A2 U98/A2 U5/A2 U6/A2 U106/A2 U113/A2 U18/A2 U311/A2 U121/A2 U128/A2 U136/A2 U143/A2}] NBUFFX4_LVT -new_net_names {net5} -new_cell_names {U341}
size_cell {U73} {AND3X2_HVT}
size_cell {U77} {AND3X2_HVT}
size_cell {U9} {AND3X2_HVT}
current_instance
current_instance {cores_0__core_instance/threads_2__register_instance}
size_cell {U21} {AND2X2_HVT}
size_cell {U215} {AND2X2_HVT}
size_cell {U220} {AND3X2_LVT}
insert_buffer [get_pins {U250/A1 U259/A1 U264/A1 U273/A1 U279/A1 U288/A1 U4/A2 U8/A1 U308/A1 U317/A1 U323/A1 U32/A1 U236/A1 U332/A1 U338/A1 U245/A1}] NBUFFX4_LVT -new_net_names {net7} -new_cell_names {U508}
size_cell {U229} {AND3X2_HVT}
size_cell {U230} {AND3X2_HVT}
size_cell {U25} {AND2X2_HVT}
size_cell {U26} {AND2X2_HVT}
size_cell {U27} {AND2X2_HVT}
size_cell {U28} {AND2X2_HVT}
size_cell {U33} {AND3X2_HVT}
size_cell {U34} {AND3X2_HVT}
size_cell {U35} {AND3X2_HVT}
size_cell {U36} {AND3X2_HVT}
size_cell {U43} {AND3X2_LVT}
size_cell {U71} {AND3X2_LVT}
size_cell {U76} {AND3X2_HVT}
size_cell {U77} {AND3X2_HVT}
size_cell {U82} {AND3X2_HVT}
current_instance
current_instance {cores_0__core_instance/threads_3__register_instance}
insert_buffer [get_pins {U157/A4 U160/A4 U84/A4 U88/A4 U190/A4 U193/A4 U100/A4 U102/A4 U205/A4 U208/A4 U114/A4 U117/A4 U129/A4 U132/A4 U144/A4 U145/A4}] NBUFFX4_LVT -new_net_names {net8} -new_cell_names {U509}
size_cell {U170} {AND3X2_HVT}
size_cell {U183} {AND3X2_LVT}
size_cell {U20} {AND2X2_HVT}
size_cell {U222} {AND2X2_HVT}
size_cell {U228} {AND3X2_HVT}
size_cell {U237} {AND3X2_HVT}
size_cell {U239} {AND3X2_HVT}
size_cell {U27} {AND2X2_HVT}
size_cell {U28} {AND2X2_HVT}
size_cell {U30} {AND2X2_HVT}
size_cell {U36} {AND3X2_HVT}
size_cell {U37} {AND3X2_HVT}
size_cell {U38} {AND3X2_HVT}
size_cell {U77} {AND3X2_LVT}
size_cell {U80} {AND3X2_HVT}
size_cell {U85} {AND3X2_HVT}
size_cell {rt_reg_6_} {DFFX2_LVT}
current_instance
current_instance {cores_1__core_instance}
size_cell {U10} {NBUFFX8_HVT}
size_cell {U9} {NBUFFX8_HVT}
current_instance
current_instance {cores_1__core_instance/decoder_instance}
size_cell {decoded_alu_arithmetic_mux_reg_1_} {DFFARX2_HVT}
current_instance
current_instance {cores_1__core_instance/threads_0__alu_instance}
size_cell {U136} {INVX2_LVT}
size_cell {U142} {INVX2_LVT}
size_cell {U417} {INVX2_LVT}
size_cell {U482} {OR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__register_instance}
insert_buffer [get_pins {U253/A1 U259/A2 U267/A1 U273/A2 U281/A1 U287/A2 U295/A1 U204/A1 U302/A2 U216/A2 U318/A1 U224/A1 U325/A2 U230/A2 U238/A1 U245/A2}] NBUFFX4_LVT -new_net_names {net9} -new_cell_names {U510}
size_cell {U14} {AND3X2_LVT}
size_cell {U198} {AND2X2_HVT}
size_cell {U201} {AND3X2_LVT}
insert_buffer [get_pins {U255/A2 U261/A2 U269/A2 U275/A2 U283/A2 U289/A2 U297/A2 U207/A2 U304/A2 U218/A2 U226/A2 U320/A2 U327/A2 U232/A2 U240/A2 U247/A2}] NBUFFX4_LVT -new_net_names {net10} -new_cell_names {U511}
size_cell {U209} {AND3X2_LVT}
insert_buffer [get_pins {U357/A4 U260/A4 U274/A4 U288/A4 U299/A4 U5/A4 U6/A4 U7/A4 U303/A4 U10/A4 U217/A4 U322/A4 U326/A4 U231/A4 U242/A4 U246/A4}] NBUFFX4_LVT -new_net_names {net11} -new_cell_names {U512}
size_cell {U22} {AND2X2_HVT}
size_cell {U26} {AND2X2_HVT}
size_cell {U27} {AND2X2_HVT}
size_cell {U28} {AND2X2_HVT}
size_cell {U29} {AND2X2_HVT}
size_cell {U30} {AND2X2_HVT}
size_cell {U41} {AND3X2_HVT}
size_cell {U43} {AND3X2_HVT}
size_cell {U47} {AND2X2_LVT}
size_cell {U77} {AND3X2_LVT}
size_cell {U82} {AND3X2_HVT}
size_cell {U83} {AND3X2_HVT}
size_cell {U87} {AND3X2_HVT}
current_instance
current_instance {cores_1__core_instance/threads_1__alu_instance}
size_cell {U120} {MUX21X2_LVT}
size_cell {U127} {MUX21X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__register_instance}
size_cell {U196} {AND3X2_LVT}
size_cell {U198} {AND3X2_LVT}
size_cell {U201} {AND3X2_HVT}
size_cell {U202} {AND3X2_HVT}
size_cell {U205} {AND3X2_LVT}
size_cell {U207} {AND3X2_HVT}
size_cell {U26} {AND2X2_HVT}
size_cell {U27} {AND2X2_HVT}
size_cell {U28} {AND2X2_HVT}
size_cell {U29} {AND2X2_HVT}
size_cell {U31} {AND2X2_HVT}
size_cell {U323} {AND2X2_HVT}
size_cell {U37} {AND3X2_HVT}
size_cell {U38} {AND3X2_HVT}
size_cell {U71} {AND3X2_LVT}
size_cell {U77} {AND3X2_LVT}
size_cell {U79} {AND3X2_HVT}
size_cell {U80} {AND3X2_HVT}
size_cell {U82} {AND3X2_HVT}
size_cell {rt_reg_6_} {DFFX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__alu_instance}
size_cell {U250} {INVX2_LVT}
size_cell {U59} {AND2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__register_instance}
size_cell {U164} {AND2X2_LVT}
size_cell {U197} {AND3X2_LVT}
size_cell {U201} {AND3X2_HVT}
size_cell {U202} {AND3X2_HVT}
size_cell {U205} {AND3X2_LVT}
size_cell {U207} {AND3X2_HVT}
size_cell {U23} {AND2X2_LVT}
size_cell {U27} {AND2X2_LVT}
size_cell {U28} {AND2X2_LVT}
size_cell {U29} {AND2X2_LVT}
size_cell {U30} {AND2X2_LVT}
size_cell {U35} {AND3X2_LVT}
size_cell {U36} {AND3X2_LVT}
size_cell {U63} {AND3X2_LVT}
size_cell {U7} {AND3X2_HVT}
size_cell {U74} {AND3X2_LVT}
size_cell {U80} {AND3X2_LVT}
size_cell {U83} {AND3X2_LVT}
size_cell {U85} {AND3X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__lsu_instance}
insert_buffer [get_pins {U92/A2}] NBUFFX4_LVT -new_net_names {net14} -new_cell_names {U547}
current_instance
current_instance {cores_1__core_instance/threads_3__register_instance}
size_cell {U162} {AND2X2_HVT}
size_cell {U194} {AND3X2_LVT}
size_cell {U196} {AND3X2_LVT}
size_cell {U199} {AND3X2_HVT}
size_cell {U200} {AND3X2_HVT}
size_cell {U203} {AND3X2_LVT}
size_cell {U205} {AND3X2_HVT}
size_cell {U212} {AND2X2_HVT}
size_cell {U25} {AND2X2_HVT}
size_cell {U29} {AND2X2_HVT}
size_cell {U30} {AND2X2_HVT}
insert_buffer [get_pins {U155/A3 U159/A3 U173/A3 U184/A3 U99/A3 U7/A3 U8/A3 U9/A3 U109/A4 U114/A3 U125/A3 U129/A3 U27/A3 U140/A3 U144/A3 U43/A3}] NBUFFX4_LVT -new_net_names {net15} -new_cell_names {U548}
size_cell {U37} {AND3X2_HVT}
size_cell {U55} {AND3X2_HVT}
size_cell {U71} {AND3X2_HVT}
size_cell {U76} {AND3X2_LVT}
current_instance
current_instance {data_memory_controller}
size_cell {U102} {OR2X2_LVT}
size_cell {U105} {OR2X2_HVT}
size_cell {U118} {OR2X2_LVT}
size_cell {U2591} {INVX2_LVT}
size_cell {U450} {INVX2_LVT}
size_cell {U597} {OR2X2_LVT}
current_instance
current_instance {dispatch_instance}
size_cell {U40} {AND2X2_HVT}
current_instance
current_instance {cores_0__core_instance/threads_1__alu_instance}
size_cell {U96} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__alu_instance}
size_cell {U44} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__alu_instance}
size_cell {U71} {INVX2_LVT}
current_instance
current_instance {data_memory_controller}
size_cell {U549} {NOR2X2_LVT}
current_instance
