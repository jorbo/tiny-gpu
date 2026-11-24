// SRAM1RW256x8 between DFFX1_LVT registers (structural, so PrimeTime can read it). Lets PT report
// the macro's real access time (CE -> O) and input setup times. Used by sram_info.tcl.
module sram_probe (clk, a_in, d_in, web_in, csb_in, q_out);
    input clk, web_in, csb_in;
    input [7:0] a_in, d_in;
    output [7:0] q_out;
    wire [7:0] a_r, d_r, o;
    wire web_r, csb_r, tie0;
    TIEL_LVT tie (.Y(tie0));
    DFFX1_LVT a_reg_0 (.D(a_in[0]), .CLK(clk), .Q(a_r[0]));
    DFFX1_LVT d_reg_0 (.D(d_in[0]), .CLK(clk), .Q(d_r[0]));
    DFFX1_LVT q_reg_0 (.D(o[0]), .CLK(clk), .Q(q_out[0]));
    DFFX1_LVT a_reg_1 (.D(a_in[1]), .CLK(clk), .Q(a_r[1]));
    DFFX1_LVT d_reg_1 (.D(d_in[1]), .CLK(clk), .Q(d_r[1]));
    DFFX1_LVT q_reg_1 (.D(o[1]), .CLK(clk), .Q(q_out[1]));
    DFFX1_LVT a_reg_2 (.D(a_in[2]), .CLK(clk), .Q(a_r[2]));
    DFFX1_LVT d_reg_2 (.D(d_in[2]), .CLK(clk), .Q(d_r[2]));
    DFFX1_LVT q_reg_2 (.D(o[2]), .CLK(clk), .Q(q_out[2]));
    DFFX1_LVT a_reg_3 (.D(a_in[3]), .CLK(clk), .Q(a_r[3]));
    DFFX1_LVT d_reg_3 (.D(d_in[3]), .CLK(clk), .Q(d_r[3]));
    DFFX1_LVT q_reg_3 (.D(o[3]), .CLK(clk), .Q(q_out[3]));
    DFFX1_LVT a_reg_4 (.D(a_in[4]), .CLK(clk), .Q(a_r[4]));
    DFFX1_LVT d_reg_4 (.D(d_in[4]), .CLK(clk), .Q(d_r[4]));
    DFFX1_LVT q_reg_4 (.D(o[4]), .CLK(clk), .Q(q_out[4]));
    DFFX1_LVT a_reg_5 (.D(a_in[5]), .CLK(clk), .Q(a_r[5]));
    DFFX1_LVT d_reg_5 (.D(d_in[5]), .CLK(clk), .Q(d_r[5]));
    DFFX1_LVT q_reg_5 (.D(o[5]), .CLK(clk), .Q(q_out[5]));
    DFFX1_LVT a_reg_6 (.D(a_in[6]), .CLK(clk), .Q(a_r[6]));
    DFFX1_LVT d_reg_6 (.D(d_in[6]), .CLK(clk), .Q(d_r[6]));
    DFFX1_LVT q_reg_6 (.D(o[6]), .CLK(clk), .Q(q_out[6]));
    DFFX1_LVT a_reg_7 (.D(a_in[7]), .CLK(clk), .Q(a_r[7]));
    DFFX1_LVT d_reg_7 (.D(d_in[7]), .CLK(clk), .Q(d_r[7]));
    DFFX1_LVT q_reg_7 (.D(o[7]), .CLK(clk), .Q(q_out[7]));
    DFFX1_LVT web_reg (.D(web_in), .CLK(clk), .Q(web_r));
    DFFX1_LVT csb_reg (.D(csb_in), .CLK(clk), .Q(csb_r));
    SRAM1RW256x8 mem (.A(a_r), .CE(clk), .WEB(web_r), .OEB(tie0), .CSB(csb_r), .I(d_r), .O(o));
endmodule
