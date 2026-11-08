`timescale 1ns/1ps

// Plain Verilog testbench for tiny-gpu (replacement for the cocotb tests)
// > Runs against build/gpu.v (sv2v output) or a post-synthesis netlist
// > Kernel select:   +define+MATADD  (default is matmul)
// > Clock period:    +define+CLK_PERIOD=<ns> (default 10, keep equal to the SDC period for power)
// > Waveform dump:   +vcd plusarg writes build/gpu.vcd (+vcdfile=<path> to rename)
`ifndef CLK_PERIOD
`define CLK_PERIOD 10
`endif

module tb_gpu;
    localparam DATA_MEM_ADDR_BITS = 8;
    localparam DATA_MEM_DATA_BITS = 8;
    localparam DATA_MEM_NUM_CHANNELS = 4;
    localparam PROGRAM_MEM_ADDR_BITS = 8;
    localparam PROGRAM_MEM_DATA_BITS = 16;
    localparam PROGRAM_MEM_NUM_CHANNELS = 1;

    reg clk = 0;
    reg reset = 1;
    reg start = 0;
    wire done;
    reg device_control_write_enable = 0;
    reg [7:0] device_control_data = 0;

    // Ports are flattened by sv2v: channel k occupies [k*W +: W]
    wire [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid;
    wire [PROGRAM_MEM_NUM_CHANNELS*PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address;
    reg [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready = 0;
    reg [PROGRAM_MEM_NUM_CHANNELS*PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data = 0;

    wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid;
    wire [DATA_MEM_NUM_CHANNELS*DATA_MEM_ADDR_BITS-1:0] data_mem_read_address;
    reg [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready = 0;
    reg [DATA_MEM_NUM_CHANNELS*DATA_MEM_DATA_BITS-1:0] data_mem_read_data = 0;
    wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid;
    wire [DATA_MEM_NUM_CHANNELS*DATA_MEM_ADDR_BITS-1:0] data_mem_write_address;
    wire [DATA_MEM_NUM_CHANNELS*DATA_MEM_DATA_BITS-1:0] data_mem_write_data;
    reg [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready = 0;

    gpu dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done(done),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .program_mem_read_valid(program_mem_read_valid),
        .program_mem_read_address(program_mem_read_address),
        .program_mem_read_ready(program_mem_read_ready),
        .program_mem_read_data(program_mem_read_data),
        .data_mem_read_valid(data_mem_read_valid),
        .data_mem_read_address(data_mem_read_address),
        .data_mem_read_ready(data_mem_read_ready),
        .data_mem_read_data(data_mem_read_data),
        .data_mem_write_valid(data_mem_write_valid),
        .data_mem_write_address(data_mem_write_address),
        .data_mem_write_data(data_mem_write_data),
        .data_mem_write_ready(data_mem_write_ready)
    );

    always #(`CLK_PERIOD / 2.0) clk = ~clk;

    // External memories: respond to requests seen at a clock edge on the following edge,
    // matching the timing of the cocotb Memory model (test/helpers/memory.py)
    reg [PROGRAM_MEM_DATA_BITS-1:0] program_memory [0:(1<<PROGRAM_MEM_ADDR_BITS)-1];
    reg [DATA_MEM_DATA_BITS-1:0] data_memory [0:(1<<DATA_MEM_ADDR_BITS)-1];
    reg mem_enable = 0;

    integer k;
    always @(posedge clk) begin
        if (mem_enable) begin
            for (k = 0; k < PROGRAM_MEM_NUM_CHANNELS; k = k + 1) begin
                program_mem_read_ready[k] <= program_mem_read_valid[k];
                program_mem_read_data[k*PROGRAM_MEM_DATA_BITS +: PROGRAM_MEM_DATA_BITS] <= program_mem_read_valid[k] ?
                    program_memory[program_mem_read_address[k*PROGRAM_MEM_ADDR_BITS +: PROGRAM_MEM_ADDR_BITS]] : 0;
            end
            for (k = 0; k < DATA_MEM_NUM_CHANNELS; k = k + 1) begin
                data_mem_read_ready[k] <= data_mem_read_valid[k];
                data_mem_read_data[k*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS] <= data_mem_read_valid[k] ?
                    data_memory[data_mem_read_address[k*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS]] : 0;
                data_mem_write_ready[k] <= data_mem_write_valid[k];
                if (data_mem_write_valid[k])
                    data_memory[data_mem_write_address[k*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS]] <=
                        data_mem_write_data[k*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS];
            end
        end
    end

    // Kernels (same programs and data as test/test_matadd.py and test/test_matmul.py)
    integer i, threads, errors, cycles;
    reg [7:0] expected;
    reg [8*256-1:0] vcdfile;

    task load_kernel;
        begin
            for (i = 0; i < (1<<PROGRAM_MEM_ADDR_BITS); i = i + 1) program_memory[i] = 0;
            for (i = 0; i < (1<<DATA_MEM_ADDR_BITS); i = i + 1) data_memory[i] = 0;
`ifdef MATADD
            program_memory[0]  = 16'b0101000011011110; // MUL R0, %blockIdx, %blockDim
            program_memory[1]  = 16'b0011000000001111; // ADD R0, R0, %threadIdx         ; i = blockIdx * blockDim + threadIdx
            program_memory[2]  = 16'b1001000100000000; // CONST R1, #0                   ; baseA
            program_memory[3]  = 16'b1001001000001000; // CONST R2, #8                   ; baseB
            program_memory[4]  = 16'b1001001100010000; // CONST R3, #16                  ; baseC
            program_memory[5]  = 16'b0011010000010000; // ADD R4, R1, R0                 ; addr(A[i])
            program_memory[6]  = 16'b0111010001000000; // LDR R4, R4
            program_memory[7]  = 16'b0011010100100000; // ADD R5, R2, R0                 ; addr(B[i])
            program_memory[8]  = 16'b0111010101010000; // LDR R5, R5
            program_memory[9]  = 16'b0011011001000101; // ADD R6, R4, R5                 ; C[i] = A[i] + B[i]
            program_memory[10] = 16'b0011011100110000; // ADD R7, R3, R0                 ; addr(C[i])
            program_memory[11] = 16'b1000000001110110; // STR R7, R6
            program_memory[12] = 16'b1111000000000000; // RET
            for (i = 0; i < 8; i = i + 1) begin
                data_memory[i] = i;      // Matrix A (1 x 8)
                data_memory[i + 8] = i;  // Matrix B (1 x 8)
            end
            threads = 8;
`else
            program_memory[0]  = 16'b0101000011011110; // MUL R0, %blockIdx, %blockDim
            program_memory[1]  = 16'b0011000000001111; // ADD R0, R0, %threadIdx         ; i = blockIdx * blockDim + threadIdx
            program_memory[2]  = 16'b1001000100000001; // CONST R1, #1                   ; increment
            program_memory[3]  = 16'b1001001000000010; // CONST R2, #2                   ; N
            program_memory[4]  = 16'b1001001100000000; // CONST R3, #0                   ; baseA
            program_memory[5]  = 16'b1001010000000100; // CONST R4, #4                   ; baseB
            program_memory[6]  = 16'b1001010100001000; // CONST R5, #8                   ; baseC
            program_memory[7]  = 16'b0110011000000010; // DIV R6, R0, R2                 ; row = i // N
            program_memory[8]  = 16'b0101011101100010; // MUL R7, R6, R2
            program_memory[9]  = 16'b0100011100000111; // SUB R7, R0, R7                 ; col = i % N
            program_memory[10] = 16'b1001100000000000; // CONST R8, #0                   ; acc = 0
            program_memory[11] = 16'b1001100100000000; // CONST R9, #0                   ; k = 0
            program_memory[12] = 16'b0101101001100010; // LOOP: MUL R10, R6, R2
            program_memory[13] = 16'b0011101010101001; //   ADD R10, R10, R9
            program_memory[14] = 16'b0011101010100011; //   ADD R10, R10, R3             ; addr(A[i])
            program_memory[15] = 16'b0111101010100000; //   LDR R10, R10
            program_memory[16] = 16'b0101101110010010; //   MUL R11, R9, R2
            program_memory[17] = 16'b0011101110110111; //   ADD R11, R11, R7
            program_memory[18] = 16'b0011101110110100; //   ADD R11, R11, R4             ; addr(B[i])
            program_memory[19] = 16'b0111101110110000; //   LDR R11, R11
            program_memory[20] = 16'b0101110010101011; //   MUL R12, R10, R11
            program_memory[21] = 16'b0011100010001100; //   ADD R8, R8, R12              ; acc += A * B
            program_memory[22] = 16'b0011100110010001; //   ADD R9, R9, R1               ; k++
            program_memory[23] = 16'b0010000010010010; //   CMP R9, R2
            program_memory[24] = 16'b0001100000001100; //   BRn LOOP
            program_memory[25] = 16'b0011100101010000; // ADD R9, R5, R0                 ; addr(C[i])
            program_memory[26] = 16'b1000000010011000; // STR R9, R8
            program_memory[27] = 16'b1111000000000000; // RET
            for (i = 0; i < 4; i = i + 1) begin
                data_memory[i] = i + 1;      // Matrix A (2 x 2)
                data_memory[i + 4] = i + 1;  // Matrix B (2 x 2)
            end
            threads = 4;
`endif
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            if (!$value$plusargs("vcdfile=%s", vcdfile)) vcdfile = "build/gpu.vcd";
            $dumpfile(vcdfile);
            $dumpvars(0, dut);
        end

        load_kernel;

        // Reset
        @(posedge clk);
        #(`CLK_PERIOD / 4.0) reset = 0;

        // Device Control Register
        device_control_write_enable = 1;
        device_control_data = threads;
        @(posedge clk);
        #(`CLK_PERIOD / 4.0) device_control_write_enable = 0;

        // Start
        start = 1;
        mem_enable = 1;
        cycles = 0;
        while (done !== 1'b1) begin
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles > 100000) begin
                $display("FAIL: timeout after %0d cycles", cycles);
                $finish;
            end
        end
        #(`CLK_PERIOD / 4.0);

        // Check results
        errors = 0;
`ifdef MATADD
        for (i = 0; i < 8; i = i + 1) begin
            expected = data_memory[i] + data_memory[i + 8];
            if (data_memory[i + 16] !== expected) begin
                $display("Mismatch C[%0d]: expected %0d, got %0d", i, expected, data_memory[i + 16]);
                errors = errors + 1;
            end
        end
`else
        for (i = 0; i < 4; i = i + 1) begin
            expected = data_memory[(i/2)*2] * data_memory[4 + (i%2)] + data_memory[(i/2)*2 + 1] * data_memory[6 + (i%2)];
            if (data_memory[i + 8] !== expected) begin
                $display("Mismatch C[%0d]: expected %0d, got %0d", i, expected, data_memory[i + 8]);
                errors = errors + 1;
            end
        end
`endif
        $display("Completed in %0d cycles (%0.2f ns at %0.2f ns clock)", cycles, cycles * `CLK_PERIOD * 1.0, `CLK_PERIOD * 1.0);
        if (errors == 0) $display("PASS");
        else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
