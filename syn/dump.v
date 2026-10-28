// Simulation-only: dump switching activity of the gpu for power analysis
module dump();
    initial begin
        $dumpfile("build/gpu.vcd");
        $dumpvars(0, gpu);
    end
endmodule
