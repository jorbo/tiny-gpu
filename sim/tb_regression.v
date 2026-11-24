`timescale 1ns/1ps
`default_nettype none

// Shared external-interface-only testbench for converted RTL and mapped netlists.
// Compile with -g2012. No hierarchical register/state names or SDF are required.
// This file has NOT been compiled/simulated as part of the offline suite task.
`ifndef CLK_PERIOD
`define CLK_PERIOD 2.55
`endif

module tb_regression;
    reg clk = 0;
    reg reset = 1;
    reg start = 0;
    wire done;
    reg device_control_write_enable = 0;
    reg [7:0] device_control_data = 0;
    wire [0:0] program_mem_read_valid;
    wire [7:0] program_mem_read_address;
    reg [0:0] program_mem_read_ready = 0;
    reg [15:0] program_mem_read_data = 0;
    wire [3:0] data_mem_read_valid, data_mem_write_valid;
    wire [31:0] data_mem_read_address, data_mem_write_address, data_mem_write_data;
    reg [3:0] data_mem_read_ready = 0, data_mem_write_ready = 0;
    reg [31:0] data_mem_read_data = 0;

    gpu dut (
        .clk(clk), .reset(reset), .start(start), .done(done),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .program_mem_read_valid(program_mem_read_valid),
        .program_mem_read_address(program_mem_read_address),
        .program_mem_read_ready(program_mem_read_ready),
        .program_mem_read_data(program_mem_read_data),
        .data_mem_read_valid(data_mem_read_valid),
        .data_mem_read_address(data_mem_read_address),
        .data_mem_read_ready(data_mem_read_ready), .data_mem_read_data(data_mem_read_data),
        .data_mem_write_valid(data_mem_write_valid),
        .data_mem_write_address(data_mem_write_address),
        .data_mem_write_data(data_mem_write_data), .data_mem_write_ready(data_mem_write_ready)
    );

    always #(`CLK_PERIOD / 2.0) clk = ~clk;

    reg [15:0] program_memory [0:255];
    reg [7:0] data_memory [0:255], expected_memory [0:255];
    reg [31:0] expected_writes [0:255];
    integer actual_writes [0:255];
    integer program_state = 0, program_left = 0;
    reg [7:0] program_address;
    integer read_state [0:3], write_state [0:3];
    integer read_left [0:3], write_left [0:3];
    reg [7:0] read_address [0:3], write_address [0:3], write_value [0:3];
    integer program_transactions = 0, read_transactions = 0, write_transactions = 0;
    integer threads, delay_min, delay_max, reset_kind, max_cycles;
    reg [31:0] rng_state;
    reg mem_enable = 0;
    reg completion_seen = 0;
    string case_dir, testcase_name, filename, vcdfile;
    integer i, k, j, fd, cycles, errors, reset_seen = 0;

    // Deterministic testbench-only delay generator. Each channel samples its own delay.
    function integer next_delay;
        begin
            rng_state = rng_state * 32'd1664525 + 32'd1013904223;
            // Upper bits avoid the LCG's eight-request low-bit repetition.
            next_delay = delay_min + ((rng_state >> 16) % (delay_max - delay_min + 1));
        end
    endfunction

    // State 0: idle; 1: captured and waiting; 2: ACK held until valid drops.
    // Count/commit once per valid episode, NOT once per high-valid clock cycle.
    always @(posedge clk) begin
        if (reset) begin
            program_mem_read_ready <= 0;
            program_mem_read_data <= 0;
            data_mem_read_ready <= 0;
            data_mem_read_data <= 0;
            data_mem_write_ready <= 0;
            program_state = 0;
            program_transactions = 0;
            read_transactions = 0;
            write_transactions = 0;
            for (k = 0; k < 4; k = k + 1) begin
                read_state[k] = 0;
                write_state[k] = 0;
                read_left[k] = 0;
                write_left[k] = 0;
            end
            for (k = 0; k < 256; k = k + 1) actual_writes[k] = 0;
            // External memory contents deliberately survive reset.
        end else if (mem_enable) begin
            if ((^program_mem_read_valid) === 1'bx ||
                (^data_mem_read_valid) === 1'bx || (^data_mem_write_valid) === 1'bx)
                $fatal(1, "FAIL %0s unknown request-valid", testcase_name);

            if (completion_seen && program_state == 0 && program_mem_read_valid[0])
                $fatal(1, "FAIL %0s new instruction request after done", testcase_name);

            case (program_state)
                0: if (program_mem_read_valid[0]) begin
                    if ((^program_mem_read_address) === 1'bx)
                        $fatal(1, "FAIL %0s unknown instruction address", testcase_name);
                    program_address = program_mem_read_address;
                    program_left = next_delay();
                    program_state = 1;
                    program_transactions = program_transactions + 1;
                end
                1: begin
                    if (program_mem_read_valid[0] !== 1'b1 ||
                        program_mem_read_address !== program_address)
                        $fatal(1, "FAIL %0s instruction request changed before ACK", testcase_name);
                    if (program_left == 1) begin
                        program_mem_read_data <= program_memory[program_address];
                        program_mem_read_ready[0] <= 1;
                        program_state = 2;
                    end else program_left = program_left - 1;
                end
                2: begin
                    if (program_mem_read_valid[0] === 1'b0) begin
                        program_mem_read_ready[0] <= 0;
                        program_state = 0;
                    end else if (program_mem_read_address !== program_address)
                        $fatal(1, "FAIL %0s instruction address changed while valid", testcase_name);
                end
            endcase

            for (k = 0; k < 4; k = k + 1) begin
                if (completion_seen &&
                    ((read_state[k] == 0 && data_mem_read_valid[k]) ||
                     (write_state[k] == 0 && data_mem_write_valid[k])))
                    $fatal(1, "FAIL %0s new data request after done", testcase_name);
                if (data_mem_read_valid[k] && data_mem_write_valid[k])
                    $fatal(1, "FAIL %0s simultaneous read/write on channel %0d", testcase_name, k);
                case (read_state[k])
                    0: if (data_mem_read_valid[k]) begin
                        if ((^data_mem_read_address[k*8 +: 8]) === 1'bx)
                            $fatal(1, "FAIL %0s unknown data read address", testcase_name);
                        read_address[k] = data_mem_read_address[k*8 +: 8];
                        read_left[k] = next_delay();
                        read_state[k] = 1;
                        read_transactions = read_transactions + 1;
                    end
                    1: begin
                        if (data_mem_read_valid[k] !== 1'b1 ||
                            data_mem_read_address[k*8 +: 8] !== read_address[k])
                            $fatal(1, "FAIL %0s data read changed before ACK", testcase_name);
                        if (read_left[k] == 1) begin
                            data_mem_read_data[k*8 +: 8] <= data_memory[read_address[k]];
                            data_mem_read_ready[k] <= 1;
                            read_state[k] = 2;
                        end else read_left[k] = read_left[k] - 1;
                    end
                    2: begin
                        if (data_mem_read_valid[k] === 1'b0) begin
                            data_mem_read_ready[k] <= 0;
                            read_state[k] = 0;
                        end else if (data_mem_read_address[k*8 +: 8] !== read_address[k])
                            $fatal(1, "FAIL %0s data read address changed while valid", testcase_name);
                    end
                endcase

                case (write_state[k])
                    0: if (data_mem_write_valid[k]) begin
                        if ((^data_mem_write_address[k*8 +: 8]) === 1'bx ||
                            (^data_mem_write_data[k*8 +: 8]) === 1'bx)
                            $fatal(1, "FAIL %0s unknown data write payload", testcase_name);
                        write_address[k] = data_mem_write_address[k*8 +: 8];
                        write_value[k] = data_mem_write_data[k*8 +: 8];
                        write_left[k] = next_delay();
                        write_state[k] = 1;
                        write_transactions = write_transactions + 1;
                    end
                    1: begin
                        if (data_mem_write_valid[k] !== 1'b1 ||
                            data_mem_write_address[k*8 +: 8] !== write_address[k] ||
                            data_mem_write_data[k*8 +: 8] !== write_value[k])
                            $fatal(1, "FAIL %0s data write changed before ACK", testcase_name);
                        if (write_left[k] == 1) begin
                            // Generated programs have no cross-lane memory races.
                            for (j = 0; j < 4; j = j + 1) begin
                                if (j != k && write_state[j] != 0 &&
                                    write_address[j] == write_address[k])
                                    $fatal(1, "FAIL %0s overlapping channel writes", testcase_name);
                            end
                            data_memory[write_address[k]] = write_value[k];
                            actual_writes[write_address[k]] = actual_writes[write_address[k]] + 1;
                            data_mem_write_ready[k] <= 1;
                            write_state[k] = 2;
                        end else write_left[k] = write_left[k] - 1;
                    end
                    2: begin
                        if (data_mem_write_valid[k] === 1'b0) begin
                            data_mem_write_ready[k] <= 0;
                            write_state[k] = 0;
                        end else if (data_mem_write_address[k*8 +: 8] !== write_address[k] ||
                                     data_mem_write_data[k*8 +: 8] !== write_value[k])
                            $fatal(1, "FAIL %0s data write payload changed while valid", testcase_name);
                    end
                endcase
            end
        end
    end

    task launch;
        begin
            // Drive inputs only on falling edges, away from the DUT sample edge.
            reset = 1;
            start = 0;
            completion_seen = 0;
            mem_enable = 0;
            device_control_write_enable = 0;
            repeat (6) @(negedge clk);
            reset = 0;
            device_control_write_enable = 1;
            device_control_data = threads;
            @(negedge clk);
            device_control_write_enable = 0;
            start = 1;
            mem_enable = 1;
        end
    endtask

    task require_file(input string path);
        begin
            fd = $fopen(path, "r");
            if (fd == 0) $fatal(1, "FAIL cannot open %0s", path);
            $fclose(fd);
        end
    endtask

    initial begin
        if (!$value$plusargs("case_dir=%s", case_dir) || !$value$plusargs("name=%s", testcase_name) ||
            !$value$plusargs("threads=%d", threads) || !$value$plusargs("delay_min=%d", delay_min) ||
            !$value$plusargs("delay_max=%d", delay_max) || !$value$plusargs("seed=%d", rng_state) ||
            !$value$plusargs("reset_kind=%d", reset_kind) || !$value$plusargs("max_cycles=%d", max_cycles))
            $fatal(1, "FAIL missing required testcase arguments");
        if (threads < 0 || threads > 255 || delay_min < 1 || delay_max > 8 ||
            delay_min > delay_max || max_cycles < 1 || reset_kind < 0 || reset_kind > 2)
            $fatal(1, "FAIL invalid testcase configuration");
        if ($value$plusargs("vcd=%s", vcdfile)) begin
            $dumpfile(vcdfile);
            $dumpvars(0, dut);
        end
        filename = {case_dir, "/program.hex"};
        require_file(filename);
        $readmemh(filename, program_memory);
        filename = {case_dir, "/data.hex"};
        require_file(filename);
        $readmemh(filename, data_memory);
        filename = {case_dir, "/expected.hex"};
        require_file(filename);
        $readmemh(filename, expected_memory);
        filename = {case_dir, "/writes.hex"};
        require_file(filename);
        $readmemh(filename, expected_writes);
        for (i = 0; i < 256; i = i + 1) begin
            if ((^program_memory[i]) === 1'bx || (^data_memory[i]) === 1'bx ||
                (^expected_memory[i]) === 1'bx || (^expected_writes[i]) === 1'bx)
                $fatal(1, "FAIL incomplete/unknown vector image at address %0d", i);
        end

        launch;
        cycles = 0;
        // Optional reset injection: wait for a captured, unacknowledged transaction.
        if (reset_kind != 0) begin
            while (reset_seen == 0 && cycles < max_cycles) begin
                @(negedge clk);
                cycles = cycles + 1;
                for (i = 0; i < 4; i = i + 1) begin
                    if ((reset_kind == 1 && read_state[i] == 1 && !data_mem_read_ready[i]) ||
                        (reset_kind == 2 && write_state[i] == 1 && !data_mem_write_ready[i]))
                        reset_seen = 1;
                end
                if (done !== 1'b0) $fatal(1, "FAIL completed/unknown before reset injection");
            end
            if (reset_seen == 0) $fatal(1, "FAIL reset injection target not reached");
            launch;
            cycles = 0;
        end
        while (done !== 1'b1 && cycles < max_cycles) begin
            @(negedge clk);
            cycles = cycles + 1;
            if (done !== 1'b0 && done !== 1'b1) $fatal(1, "FAIL unknown done");
        end
        if (done !== 1'b1) $fatal(1, "FAIL %0s cycle timeout", testcase_name);

        // Freeze architectural request acceptance at the first observed done.
        // A valid asserted on the same edge as done may not yet be captured.
        completion_seen = 1;
        if (program_state == 1 || (program_state == 0 && program_mem_read_valid !== 0))
            $fatal(1, "FAIL %0s done before instruction ACK", testcase_name);
        for (i = 0; i < 4; i = i + 1)
            if (read_state[i] == 1 || write_state[i] == 1 ||
                (read_state[i] == 0 && data_mem_read_valid[i] !== 1'b0) ||
                (write_state[i] == 0 && data_mem_write_valid[i] !== 1'b0))
                $fatal(1, "FAIL %0s done before data ACK", testcase_name);

        // Allow only handshake teardown, never additional architectural requests.
        repeat (8) @(negedge clk);
        if (program_state != 0 || program_mem_read_valid !== 0 ||
            data_mem_read_valid !== 0 || data_mem_write_valid !== 0)
            $fatal(1, "FAIL %0s completed with requests outstanding", testcase_name);
        for (i = 0; i < 4; i = i + 1)
            if (read_state[i] != 0 || write_state[i] != 0)
                $fatal(1, "FAIL %0s unacknowledged data transaction at completion", testcase_name);
        if (threads == 0 && (read_transactions != 0 || write_transactions != 0))
            $fatal(1, "FAIL zero-thread kernel issued data transaction");

        errors = 0;
        for (i = 0; i < 256; i = i + 1) begin
            if (data_memory[i] !== expected_memory[i]) begin
                $display("FAIL %0s address=%0d expected=%0d actual=%0d", testcase_name,
                         i, expected_memory[i], data_memory[i]);
                errors = errors + 1;
            end
            if (actual_writes[i] !== expected_writes[i]) begin
                $display("FAIL %0s address=%0d expected_writes=%0d actual_writes=%0d",
                         testcase_name, i, expected_writes[i], actual_writes[i]);
                errors = errors + 1;
            end
        end
        if (errors != 0) $fatal(1, "FAIL %0s mismatches=%0d", testcase_name, errors);
        $display("PASS %0s cycles=%0d", testcase_name, cycles);
        $finish;
    end
endmodule

`default_nettype wire
