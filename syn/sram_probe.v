// SRAM1RW256x8 between registers, so PrimeTime can report the macro's real access time
// (CE -> O) and input setup times at our operating point. Used by sram_info.tcl.
module sram_probe (
    input  wire       clk,
    input  wire [7:0] a_in,
    input  wire [7:0] d_in,
    input  wire       web_in,
    input  wire       csb_in,
    output wire [7:0] q_out
);
    reg [7:0] a_r, d_r, q_r;
    reg       web_r, csb_r;
    wire [7:0] o;

    always @(posedge clk) begin
        a_r   <= a_in;
        d_r   <= d_in;
        web_r <= web_in;
        csb_r <= csb_in;
        q_r   <= o;
    end

    SRAM1RW256x8 mem (.A(a_r), .CE(clk), .WEB(web_r), .OEB(1'b0), .CSB(csb_r), .I(d_r), .O(o));

    assign q_out = q_r;
endmodule
