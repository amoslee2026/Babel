// tb_DRAM_AXI_VIP.sv
// Testbench for DRAM AXI VIP Integration
// Demonstrates basic read/write operations

`timescale 1ns/1ps

module tb_DRAM_AXI_VIP;

    // ========================================================================
    // Clock and Reset Generation
    // ========================================================================

    logic clk;
    logic rst_n;

    // 1 GHz clock (1 ns period)
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("[%0t] Reset Released", $time);
    end

    // ========================================================================
    // AXI Interface Signals
    // ========================================================================

    // Write Address Channel
    logic                   aw_valid;
    logic                   aw_ready;
    logic [27:0]            aw_addr;   // 28-bit address for 256MB
    logic [7:0]             aw_id;
    logic [7:0]             aw_len;
    logic [2:0]             aw_size;
    logic [1:0]             aw_burst;

    // Write Data Channel
    logic                   w_valid;
    logic                   w_ready;
    logic [1023:0]          w_data;
    logic [127:0]           w_strb;
    logic                   w_last;

    // Write Response Channel
    logic                   b_valid;
    logic                   b_ready;
    logic [1:0]             b_resp;
    logic [7:0]             b_id;

    // Read Address Channel
    logic                   ar_valid;
    logic                   ar_ready;
    logic [27:0]            ar_addr;
    logic [7:0]             ar_id;
    logic [7:0]             ar_len;
    logic [2:0]             ar_size;
    logic [1:0]             ar_burst;

    // Read Data Channel
    logic                   r_valid;
    logic                   r_ready;
    logic [1023:0]          r_data;
    logic [1:0]             r_resp;
    logic                   r_last;
    logic [7:0]             r_id;

    // Status Signals
    logic                   mem_ready;
    logic [31:0]            mem_usage;

    // ========================================================================
    // VIP Instance
    // ========================================================================

    DRAM_AXI_VIP #(
        .CLK_PERIOD_NS   (1),
        .DATA_WIDTH      (1024),
        .ID_WIDTH        (8),
        .MEM_SIZE_B      (268435456),  // 256MB
        .READ_LATENCY    (50),
        .WRITE_LATENCY   (20),
        .ERROR_INJECT    (0)
    ) u_dram_vip (
        .clk             (clk),
        .rst_n           (rst_n),
        .aw_valid        (aw_valid),
        .aw_ready        (aw_ready),
        .aw_addr         (aw_addr),
        .aw_id           (aw_id),
        .aw_len          (aw_len),
        .aw_size         (aw_size),
        .aw_burst        (aw_burst),
        .w_valid         (w_valid),
        .w_ready         (w_ready),
        .w_data          (w_data),
        .w_strb          (w_strb),
        .w_last          (w_last),
        .b_valid         (b_valid),
        .b_ready         (b_ready),
        .b_resp          (b_resp),
        .b_id            (b_id),
        .ar_valid        (ar_valid),
        .ar_ready        (ar_ready),
        .ar_addr         (ar_addr),
        .ar_id           (ar_id),
        .ar_len          (ar_len),
        .ar_size         (ar_size),
        .ar_burst        (ar_burst),
        .r_valid         (r_valid),
        .r_ready         (r_ready),
        .r_data          (r_data),
        .r_resp          (r_resp),
        .r_last          (r_last),
        .r_id            (r_id),
        .mem_ready       (mem_ready),
        .mem_usage       (mem_usage)
    );

    // ========================================================================
    // Test Tasks
    // ========================================================================

    // Task: AXI Write Transaction
    task axi_write(
        input logic [27:0] addr,
        input logic [1023:0] data,
        input logic [7:0] id,
        input int burst_len
    );
        int beat_count;
        logic [1023:0] beat_data;

        $display("[%0t] Starting Write - Addr=%0h, ID=%0h, BurstLen=%0d",
                 $time, addr, id, burst_len);

        // Address phase
        aw_valid = 1;
        aw_addr = addr;
        aw_id = id;
        aw_len = burst_len - 1;
        aw_size = 5;  // 1024 bits = 128 bytes
        aw_burst = 1; // INCR

        wait(aw_ready == 1);
        @(posedge clk);
        aw_valid = 0;

        // Data phase
        w_valid = 1;
        w_strb = '1;  // All bytes valid

        for (beat_count = 0; beat_count < burst_len; beat_count++) begin
            beat_data = data + beat_count;  // Increment data pattern
            w_data = beat_data;
            w_last = (beat_count == burst_len - 1);

            wait(w_ready == 1);
            @(posedge clk);
        end

        w_valid = 0;
        w_last = 0;

        // Response phase
        b_ready = 1;
        wait(b_valid == 1);
        @(posedge clk);
        b_ready = 0;

        $display("[%0t] Write Complete - ID=%0h, Resp=%0h", $time, b_id, b_resp);
    endtask

    // Task: AXI Read Transaction
    task axi_read(
        input  logic [27:0] addr,
        input  logic [7:0] id,
        input  int burst_len,
        output logic [1023:0] read_data []
    );
        int beat_count;

        $display("[%0t] Starting Read - Addr=%0h, ID=%0h, BurstLen=%0d",
                 $time, addr, id, burst_len);

        // Address phase
        ar_valid = 1;
        ar_addr = addr;
        ar_id = id;
        ar_len = burst_len - 1;
        ar_size = 5;
        ar_burst = 1;

        wait(ar_ready == 1);
        @(posedge clk);
        ar_valid = 0;

        // Data phase
        r_ready = 1;
        read_data = new[burst_len];

        for (beat_count = 0; beat_count < burst_len; beat_count++) begin
            wait(r_valid == 1);
            read_data[beat_count] = r_data;
            $display("[%0t] Read Beat %0d - Data[0:31]=%0h, Last=%0d",
                     $time, beat_count, r_data[31:0], r_last);
            @(posedge clk);

            if (r_last) break;
        end

        r_ready = 0;
        $display("[%0t] Read Complete - ID=%0h, Resp=%0h", $time, r_id, r_resp);
    endtask

    // ========================================================================
    // Test Sequence
    // ========================================================================

    logic [1023:0] write_data;
    logic [1023:0] read_data_array [];

    initial begin
        // Wait for reset
        wait(rst_n == 1);
        @(posedge clk);

        // Initialize signals
        aw_valid = 0; aw_addr = 0; aw_id = 0; aw_len = 0; aw_size = 0; aw_burst = 0;
        w_valid = 0; w_data = 0; w_strb = 0; w_last = 0;
        b_ready = 0;
        ar_valid = 0; ar_addr = 0; ar_id = 0; ar_len = 0; ar_size = 0; ar_burst = 0;
        r_ready = 0;

        #1000;

        // Test 1: Single Beat Write
        $display("\n=== Test 1: Single Beat Write ===");
        write_data = 'hDEADBEEFCAFEBABE123456789ABCDEF0;
        axi_write('h00000000, write_data, 'h01, 1);

        #500;

        // Test 2: Single Beat Read (Same Address)
        $display("\n=== Test 2: Single Beat Read ===");
        axi_read('h00000000, 'h02, 1, read_data_array);

        // Verify data
        if (read_data_array[0] == write_data) begin
            $display("PASS: Read data matches written data");
        end else begin
            $display("FAIL: Read data mismatch! Expected %h, Got %h",
                     write_data, read_data_array[0]);
        end

        #500;

        // Test 3: Burst Write (4 beats)
        $display("\n=== Test 3: Burst Write (4 beats) ===");
        write_data = 'hA5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5;
        axi_write('h00010000, write_data, 'h03, 4);

        #500;

        // Test 4: Burst Read (4 beats)
        $display("\n=== Test 4: Burst Read (4 beats) ===");
        axi_read('h00010000, 'h04, 4, read_data_array);

        // Verify burst data
        for (int i = 0; i < 4; i++) begin
            logic [1023:0] expected_data = write_data + i;
            if (read_data_array[i] == expected_data) begin
                $display("PASS: Beat %0d matches", i);
            end else begin
                $display("FAIL: Beat %0d mismatch! Expected %h, Got %h",
                         i, expected_data, read_data_array[i]);
            end
        end

        #500;

        // Test 5: Backdoor Access
        $display("\n=== Test 5: Backdoor Access ===");
        u_dram_vip.backdoor_write('h00020000, 'h1234567890ABCDEF1234567890ABCDEF);
        u_dram_vip.backdoor_read('h00020000, read_data_array[0]);
        $display("Backdoor Read Data: %h", read_data_array[0]);

        // Test 6: Memory Statistics
        $display("\n=== Test 6: Memory Statistics ===");
        int entries, bytes;
        u_dram_vip.get_stats(entries, bytes);
        $display("Memory Usage: %0d entries, %0d bytes", entries, bytes);
        $display("mem_usage output: %0d bytes", mem_usage);

        #1000;
        $display("\n=== All Tests Complete ===");
        $finish;
    end

    // ========================================================================
    // Simulation Control
    // ========================================================================

    initial begin
        #100000;
        $display("Simulation timeout - stopping");
        $finish;
    end

endmodule