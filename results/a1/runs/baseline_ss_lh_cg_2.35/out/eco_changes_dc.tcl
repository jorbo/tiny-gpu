###############################################################################
# Change list, formatted for dc_shell -tcl
#
# NOTE - Assumes dc_shell is already in incremental mode
#
#
# 
#
###############################################################################
current_instance
current_instance {cores_0__core_instance/threads_0__alu_instance}
size_cell {U178} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__lsu_instance}
size_cell {U16} {OR2X4_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__register_instance}
size_cell {U11} {INVX2_LVT}
size_cell {U115} {AND2X2_LVT}
size_cell {U122} {AND2X2_LVT}
size_cell {U34} {INVX4_LVT}
size_cell {U35} {AOI21X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__lsu_instance}
insert_buffer [get_pins {U21/A}] NBUFFX4_LVT -new_net_names {net1} -new_cell_names {U1}
current_instance
current_instance {cores_0__core_instance/threads_0__alu_instance}
insert_buffer [get_pins {U31/A1 U32/A2 U33/A1 U34/A1 U35/A2 U36/A2 U37/A1 U38/A2 U39/A2 U40/A1 U41/A1 U371/A U400/A2 U403/A2 U417/A1 U421/A1 U649/A2 U459/A2 U13/A2 U18/A}] NBUFFX4_LVT -new_net_names {net2} -new_cell_names {U2}
current_instance
current_instance {cores_0__core_instance/threads_1__alu_instance}
size_cell {U29} {MUX21X2_LVT}
size_cell {U341} {INVX2_LVT}
size_cell {U551} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_1__lsu_instance}
size_cell {U16} {OR2X4_LVT}
current_instance
current_instance {cores_0__core_instance/threads_1__register_instance}
size_cell {U10} {INVX2_LVT}
size_cell {U118} {AND2X2_LVT}
size_cell {U19} {AND2X2_LVT}
size_cell {U23} {AOI21X2_LVT}
size_cell {U34} {INVX4_LVT}
size_cell {U35} {AOI21X2_LVT}
size_cell {U8} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__alu_instance}
size_cell {U18} {INVX2_LVT}
size_cell {U34} {AO21X2_LVT}
size_cell {U388} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__lsu_instance}
size_cell {U11} {OR2X4_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__register_instance}
size_cell {U118} {AND2X2_LVT}
size_cell {U125} {AND2X2_LVT}
size_cell {U23} {AOI21X2_LVT}
size_cell {U33} {INVX4_LVT}
size_cell {U39} {AOI21X2_LVT}
size_cell {U8} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__alu_instance}
size_cell {U27} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__lsu_instance}
size_cell {U9} {OR2X4_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__register_instance}
size_cell {U120} {AND2X2_LVT}
size_cell {U134} {INVX2_LVT}
size_cell {U22} {AND2X2_LVT}
size_cell {U27} {AOI21X2_LVT}
size_cell {U38} {AOI21X2_LVT}
size_cell {U44} {AOI21X2_LVT}
current_instance
current_instance {cores_1__core_instance/decoder_instance}
size_cell {U18} {INVX4_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__alu_instance}
size_cell {U171} {INVX2_LVT}
size_cell {U441} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__lsu_instance}
size_cell {U20} {OR2X4_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__register_instance}
size_cell {U115} {AND2X2_LVT}
size_cell {U122} {AND2X2_LVT}
size_cell {U16} {INVX4_LVT}
size_cell {U64} {AOI21X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__alu_instance}
size_cell {U108} {INVX2_LVT}
size_cell {U304} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__lsu_instance}
size_cell {U15} {OR2X4_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__register_instance}
size_cell {U11} {INVX2_LVT}
size_cell {U118} {AND2X2_LVT}
size_cell {U125} {AND2X2_LVT}
size_cell {U21} {AOI21X2_LVT}
size_cell {U60} {AOI21X2_LVT}
size_cell {U9} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__alu_instance}
insert_buffer [get_pins {U288/A2 U105/A U113/A2 U114/A2 U306/A1 U116/A2 U117/A2 U118/A1 U85/A2 U522/A U332/A1 U340/A1 U341/A1 U348/A2 U366/A1 U382/A2 U601/A2 U412/A2 U258/A1 U279/A1}] NBUFFX4_LVT -new_net_names {net3} -new_cell_names {U688}
current_instance
current_instance {cores_1__core_instance/threads_1__lsu_instance}
insert_buffer [get_pins {U70/A}] NBUFFX4_LVT -new_net_names {net4} -new_cell_names {U689}
current_instance
current_instance {cores_1__core_instance/threads_2__lsu_instance}
size_cell {U7} {OR2X4_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__register_instance}
size_cell {U116} {AND2X2_LVT}
size_cell {U122} {AND2X2_LVT}
size_cell {U19} {INVX4_LVT}
size_cell {U21} {AOI21X2_LVT}
size_cell {U63} {AOI21X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__alu_instance}
size_cell {U182} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__lsu_instance}
size_cell {U8} {OR2X4_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__register_instance}
size_cell {U10} {INVX2_LVT}
size_cell {U119} {AND2X2_LVT}
size_cell {U126} {AND2X2_LVT}
size_cell {U19} {AOI21X2_LVT}
size_cell {U20} {AOI21X2_LVT}
size_cell {U29} {INVX4_LVT}
size_cell {U60} {AOI21X2_LVT}
current_instance
current_instance {data_memory_controller}
size_cell {U2202} {OR2X2_LVT}
size_cell {U404} {AND2X2_LVT}
size_cell {U415} {AND2X2_LVT}
size_cell {U421} {OR2X2_LVT}
size_cell {U432} {OR2X2_LVT}
size_cell {U435} {OR2X2_LVT}
size_cell {U463} {OR2X2_LVT}
current_instance
current_instance {dcr_instance}
size_cell {U5} {OR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__alu_instance}
size_cell {U312} {INVX2_LVT}
size_cell {U54} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_0__register_instance}
size_cell {U113} {NOR2X2_LVT}
size_cell {U117} {NOR2X2_LVT}
size_cell {U120} {NOR2X2_LVT}
size_cell {U13} {NOR2X2_LVT}
size_cell {U16} {NOR3X2_LVT}
size_cell {U18} {NOR3X2_LVT}
size_cell {U204} {NOR3X2_LVT}
size_cell {U207} {NOR3X2_LVT}
size_cell {U208} {NOR2X2_LVT}
size_cell {U211} {NOR2X2_LVT}
size_cell {U212} {NOR2X2_LVT}
size_cell {U214} {NOR2X2_LVT}
size_cell {U215} {NOR2X2_LVT}
size_cell {U223} {INVX2_LVT}
size_cell {U23} {NOR2X2_LVT}
size_cell {U40} {NOR2X2_LVT}
size_cell {U52} {NOR2X2_LVT}
size_cell {U56} {NOR2X2_LVT}
size_cell {U65} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_1__alu_instance}
size_cell {U121} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_1__register_instance}
size_cell {U116} {NOR2X2_LVT}
size_cell {U120} {NOR2X2_LVT}
size_cell {U123} {NOR2X2_LVT}
size_cell {U14} {NOR3X2_LVT}
size_cell {U15} {NOR2X2_LVT}
size_cell {U17} {NOR3X2_LVT}
size_cell {U20} {NOR2X2_LVT}
size_cell {U207} {NOR3X2_LVT}
size_cell {U210} {NOR3X2_LVT}
size_cell {U211} {NOR2X2_LVT}
size_cell {U214} {NOR2X2_LVT}
size_cell {U215} {NOR2X2_LVT}
size_cell {U218} {NOR2X2_LVT}
size_cell {U219} {NOR2X2_LVT}
size_cell {U45} {NOR2X2_LVT}
size_cell {U50} {NOR2X2_LVT}
size_cell {U54} {NOR2X2_LVT}
size_cell {U59} {NOR2X2_LVT}
size_cell {U68} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__alu_instance}
size_cell {U30} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_2__register_instance}
size_cell {U116} {NOR2X2_LVT}
size_cell {U120} {NOR2X2_LVT}
size_cell {U123} {NOR2X2_LVT}
size_cell {U13} {NOR2X2_LVT}
size_cell {U14} {NOR3X2_LVT}
size_cell {U15} {NOR3X2_LVT}
size_cell {U19} {NOR2X2_LVT}
size_cell {U206} {NOR3X2_LVT}
size_cell {U208} {NOR2X2_LVT}
size_cell {U210} {NOR3X2_LVT}
size_cell {U212} {NOR2X2_LVT}
size_cell {U213} {NOR2X2_LVT}
size_cell {U215} {NOR2X2_LVT}
size_cell {U216} {NOR2X2_LVT}
size_cell {U224} {INVX2_LVT}
size_cell {U43} {NOR2X2_LVT}
size_cell {U48} {NOR2X2_LVT}
size_cell {U53} {NOR2X2_LVT}
size_cell {U58} {NOR2X2_LVT}
size_cell {U63} {NOR2X2_LVT}
size_cell {U68} {NOR2X2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__alu_instance}
size_cell {U378} {INVX2_LVT}
current_instance
current_instance {cores_0__core_instance/threads_3__register_instance}
size_cell {U122} {NOR2X2_LVT}
size_cell {U125} {NOR2X2_LVT}
size_cell {U13} {NOR2X2_LVT}
size_cell {U16} {NOR2X2_LVT}
size_cell {U17} {NOR3X2_LVT}
size_cell {U18} {NOR3X2_LVT}
size_cell {U209} {NOR3X2_LVT}
size_cell {U212} {NOR3X2_LVT}
size_cell {U213} {NOR2X2_LVT}
size_cell {U215} {NOR2X2_LVT}
size_cell {U216} {NOR2X2_LVT}
size_cell {U219} {NOR2X2_LVT}
size_cell {U220} {NOR2X2_LVT}
size_cell {U228} {INVX2_LVT}
size_cell {U23} {NOR2X2_LVT}
size_cell {U56} {NOR2X2_LVT}
size_cell {U60} {NOR2X2_LVT}
size_cell {U65} {NOR2X2_LVT}
size_cell {U70} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__alu_instance}
size_cell {U308} {INVX2_LVT}
size_cell {U450} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_0__register_instance}
size_cell {U110} {NOR3X2_LVT}
size_cell {U112} {NOR2X2_LVT}
size_cell {U114} {NOR3X2_LVT}
size_cell {U117} {NOR2X2_LVT}
size_cell {U118} {NOR2X2_LVT}
size_cell {U121} {NOR2X2_LVT}
size_cell {U130} {INVX2_LVT}
size_cell {U14} {NOR2X2_LVT}
size_cell {U19} {NOR2X2_LVT}
size_cell {U205} {NOR3X2_LVT}
size_cell {U207} {NOR2X2_LVT}
size_cell {U209} {NOR3X2_LVT}
size_cell {U210} {NOR2X2_LVT}
size_cell {U212} {NOR2X2_LVT}
size_cell {U213} {NOR2X2_LVT}
size_cell {U216} {NOR2X2_LVT}
size_cell {U224} {INVX2_LVT}
size_cell {U29} {NOR2X2_LVT}
size_cell {U34} {NOR2X2_LVT}
size_cell {U39} {NOR2X2_LVT}
size_cell {U44} {NOR2X2_LVT}
size_cell {U53} {NOR2X2_LVT}
size_cell {U58} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_1__register_instance}
size_cell {U113} {NOR3X2_LVT}
size_cell {U115} {NOR2X2_LVT}
size_cell {U117} {NOR3X2_LVT}
size_cell {U120} {NOR2X2_LVT}
size_cell {U121} {NOR2X2_LVT}
size_cell {U124} {NOR2X2_LVT}
size_cell {U207} {NOR3X2_LVT}
size_cell {U209} {NOR2X2_LVT}
size_cell {U211} {NOR3X2_LVT}
size_cell {U212} {NOR2X2_LVT}
size_cell {U214} {NOR2X2_LVT}
size_cell {U215} {NOR2X2_LVT}
size_cell {U218} {NOR2X2_LVT}
size_cell {U31} {NOR2X2_LVT}
size_cell {U36} {NOR2X2_LVT}
size_cell {U41} {NOR2X2_LVT}
size_cell {U46} {NOR2X2_LVT}
size_cell {U51} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_2__register_instance}
size_cell {U111} {NOR3X2_LVT}
size_cell {U113} {NOR2X2_LVT}
size_cell {U115} {NOR3X2_LVT}
size_cell {U118} {NOR2X2_LVT}
size_cell {U121} {NOR2X2_LVT}
size_cell {U130} {INVX2_LVT}
size_cell {U204} {NOR3X2_LVT}
size_cell {U206} {NOR2X2_LVT}
size_cell {U208} {NOR3X2_LVT}
size_cell {U209} {NOR2X2_LVT}
size_cell {U212} {NOR2X2_LVT}
size_cell {U213} {NOR2X2_LVT}
size_cell {U216} {NOR2X2_LVT}
size_cell {U217} {NOR2X2_LVT}
size_cell {U225} {INVX2_LVT}
size_cell {U31} {NOR2X2_LVT}
size_cell {U36} {NOR2X2_LVT}
size_cell {U40} {NOR2X2_LVT}
size_cell {U45} {NOR2X2_LVT}
size_cell {U53} {NOR2X2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__alu_instance}
size_cell {U134} {INVX2_LVT}
size_cell {U48} {INVX2_LVT}
current_instance
current_instance {cores_1__core_instance/threads_3__register_instance}
size_cell {U114} {NOR3X2_LVT}
size_cell {U118} {NOR3X2_LVT}
size_cell {U12} {NOR2X2_LVT}
size_cell {U121} {NOR2X2_LVT}
size_cell {U122} {NOR2X2_LVT}
size_cell {U125} {NOR2X2_LVT}
size_cell {U14} {NOR2X2_LVT}
size_cell {U206} {NOR3X2_LVT}
size_cell {U208} {NOR2X2_LVT}
size_cell {U210} {NOR3X2_LVT}
size_cell {U211} {NOR2X2_LVT}
size_cell {U214} {NOR2X2_LVT}
size_cell {U215} {NOR2X2_LVT}
size_cell {U218} {NOR2X2_LVT}
size_cell {U219} {NOR2X2_LVT}
size_cell {U227} {INVX2_LVT}
size_cell {U34} {NOR2X2_LVT}
size_cell {U39} {NOR2X2_LVT}
size_cell {U44} {NOR2X2_LVT}
size_cell {U49} {NOR2X2_LVT}
current_instance
current_instance {data_memory_controller}
size_cell {U138} {NOR2X2_LVT}
size_cell {U2211} {NOR2X2_LVT}
size_cell {U2213} {NOR2X2_LVT}
size_cell {U396} {NOR2X2_LVT}
current_instance
